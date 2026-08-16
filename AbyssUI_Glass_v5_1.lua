local RS=game:GetService("RunService")
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local TWS=game:GetService("TweenService")
local HS=game:GetService("HttpService")
local WS=game:GetService("Workspace")
local Lighting=game:GetService("Lighting")
local VirtualUser=game:GetService("VirtualUser")
local CoreGui=game:GetService("CoreGui")
if not RS:IsClient() then return end
local LP=Players.LocalPlayer or Players.PlayerAdded:Wait()

local ENV=(type(getgenv)=="function" and getgenv()) or _G
if type(ENV.__ABYSS)=="table" and type(ENV.__ABYSS.Unload)=="function" then pcall(ENV.__ABYSS.Unload) end
ENV.__ABYSS=nil

-- scope
local scopes={}
local function newScope(name)
	local s={name=name,alive=true,conns={},insts={},fns={},renders={}}
	function s:Connect(sig,fn) if not self.alive then return nil end local c=sig:Connect(fn) self.conns[#self.conns+1]=c return c end
	function s:Give(i) if not self.alive then pcall(function() i:Destroy() end) return i end self.insts[#self.insts+1]=i return i end
	function s:Add(fn) if not self.alive then pcall(fn) return end self.fns[#self.fns+1]=fn end
	function s:BindRender(key,prio,fn) if not self.alive then return end local nm="ABYSS_"..key self.renders[#self.renders+1]=nm
		pcall(function() RS:BindToRenderStep(nm,prio,function(dt) if self.alive then pcall(fn,dt) end end) end) end
	function s:Destroy()
		if not self.alive then return end self.alive=false
		for _,c in ipairs(self.conns) do pcall(function() if c.Connected then c:Disconnect() end end) end
		for _,nm in ipairs(self.renders) do pcall(function() RS:UnbindFromRenderStep(nm) end) end
		for i=#self.fns,1,-1 do pcall(self.fns[i]) end
		for _,i in ipairs(self.insts) do pcall(function() i:Destroy() end) end
	end
	scopes[#scopes+1]=s return s
end
local App=newScope("app")

-- settings
local S={
	Aimbot={Enabled=false,Silent=false,FOV=120,Smoothing=5,Prediction=0.12,WallCheck=true,OnlyEnemies=true,ShowFOV=true,HitChance=100,Humanizer=0.4},
	Trigger={Enabled=false,OnlyEnemies=true,WallCheck=true,Cooldown=0.15},
	ESP={Enabled=false,Boxes=true,HealthBar=true,Snaplines=false,Names=true,Distance=false,Chams=false,OnlyEnemies=true,MaxDistance=500},
	Move={Speed=false,SpeedMode="Walk",SpeedValue=50,Fly=false,FlyValue=60,NoClip=false,InfJump=false,Bhop=false},
	AA={Jitter=false,JitterAngle=40,Desync=false,DesyncMode="Spin",DesyncSpeed=30,HideHead=false,HideHeadMode="Back",FakeLag=false,FakeLagIntensity=5,FakeLagFrequency=1},
	Rage={Enabled=false,MassFling=false,FlingTarget="Nearest",VoidTP=false,LagMachine=false,Unanchor=false},
	Misc={Watermark=true,KeybindDisplay=true,AntiAFK=true,PanicKey="End"},
	Keys={UI="RightShift",Aimbot="X",Silent="B",Fly="F",Speed="V",ESP="E"},
}
local DANGEROUS={"Aimbot.Enabled","Aimbot.Silent","Trigger.Enabled","ESP.Enabled","ESP.Chams","Move.Speed","Move.Fly","Move.NoClip","Move.InfJump","Move.Bhop","AA.Jitter","AA.Desync","AA.HideHead","AA.FakeLag","Rage.Enabled","Rage.MassFling","Rage.VoidTP","Rage.LagMachine","Rage.Unanchor"}
local UIRefs={}

-- fs + config
local function fsOk() return type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function" and type(makefolder)=="function" and type(isfolder)=="function" end
local CFGPATH="AbyssFW/unknown_v12.json"
local saveQueued=false
local function saveConfig()
	if not fsOk() then return end
	pcall(function()
		if not isfolder("AbyssFW") then makefolder("AbyssFW") end
		writefile(CFGPATH,HS:JSONEncode(S))
	end)
end
local function queueSave()
	if saveQueued then return end saveQueued=true
	task.delay(0.5,function() saveQueued=false if App.alive then saveConfig() end end)
end
local function loadConfig()
	if not fsOk() or not isfile(CFGPATH) then return end
	local ok,data=pcall(function() return HS:JSONDecode(readfile(CFGPATH)) end)
	if not ok or type(data)~="table" then return end
	for g,t in pairs(S) do
		if type(data[g])=="table" then for k in pairs(t) do if data[g][k]~=nil then t[k]=data[g][k] end end end
	end
end
local function G(path) local g,k=path:match("^(%w+)%.(%w+)$") local t=S[g] if t then return t[k] end return nil end
local function Set(path,v)
	local g,k=path:match("^(%w+)%.(%w+)$") local t=S[g] if t then t[k]=v end
	for _,fn in ipairs(UIRefs[path] or {}) do pcall(fn,v) end
	queueSave()
end

-- player cache
local Cache={byPlayer={}}
local function recomputeEnemy(rec)
	if rec.plr==LP then rec.enemy=false return end
	local m,t=LP.Team,rec.plr.Team
	if not m or not t then rec.enemy=true return end
	if LP.Neutral or rec.plr.Neutral then rec.enemy=true return end
	rec.enemy=(t~=m)
end
local function onCharAdded(rec,char)
	if rec.cscope then rec.cscope:Destroy() end
	rec.char=char
	rec.cscope=newScope("char:"..rec.plr.Name)
	rec.hum=char:FindFirstChildOfClass("Humanoid")
	rec.root=char:FindFirstChild("HumanoidRootPart")
	rec.head=char:FindFirstChild("Head")
	rec.alive=(rec.hum~=nil and rec.hum.Health>0)
	if rec.hum then
		rec.cscope:Connect(rec.hum.Died,function() rec.alive=false end)
		rec.cscope:Connect(rec.hum:GetPropertyChangedSignal("Health"),function() rec.alive=rec.hum.Health>0 end)
	end
	recomputeEnemy(rec)
end
local function wire(plr)
	local rec={plr=plr}
	rec.pscope=newScope("plr:"..plr.Name)
	Cache.byPlayer[plr]=rec
	rec.pscope:Connect(plr.CharacterAdded,function(c) onCharAdded(rec,c) end)
	rec.pscope:Connect(plr.CharacterRemoving,function() rec.alive=false rec.char=nil rec.hum=nil rec.root=nil rec.head=nil if rec.cscope then rec.cscope:Destroy() rec.cscope=nil end end)
	rec.pscope:Connect(plr:GetPropertyChangedSignal("Team"),function() for _,r in pairs(Cache.byPlayer) do recomputeEnemy(r) end end)
	if plr.Character then onCharAdded(rec,plr.Character) end
end
for _,p in ipairs(Players:GetPlayers()) do wire(p) end
App:Connect(Players.PlayerAdded,wire)
App:Connect(Players.PlayerRemoving,function(plr) local rec=Cache.byPlayer[plr] if rec then if rec.pscope then rec.pscope:Destroy() end Cache.byPlayer[plr]=nil end end)
App:Connect(LP:GetPropertyChangedSignal("Team"),function() for _,r in pairs(Cache.byPlayer) do recomputeEnemy(r) end end)
local function localRec() return Cache.byPlayer[LP] end

-- drawing pool
local drawingAvailable=type(Drawing)=="table" and type(Drawing.new)=="function"
local Pool={free={Square={},Line={},Text={}}}
local function acquire(k) if not drawingAvailable then return nil end local list=Pool.free[k] local o=table.remove(list) if not o then local ok,d=pcall(Drawing.new,k) if not ok then return nil end o=d end o.Visible=false return o end
local function release(o,k) if not o then return end pcall(function() o.Visible=false end) Pool.free[k][#Pool.free[k]+1]=o end
local function nukePool() for _,list in pairs(Pool.free) do for _,o in ipairs(list) do pcall(function() o:Remove() end) end table.clear(list) end end

-- GUI root (PlayerGui first)
local guiParent
do
	local ok,pg=pcall(function() return LP:WaitForChild("PlayerGui",5) end)
	if ok and pg then guiParent=pg
	elseif type(gethui)=="function" then local ok2,h=pcall(gethui) guiParent=(ok2 and h) or CoreGui
	else guiParent=CoreGui end
end
pcall(function() for _,g in ipairs(guiParent:GetChildren()) do if g:GetAttribute("AbyssUI") then g:Destroy() end end end)
local gui=App:Give(Instance.new("ScreenGui"))
gui.Name="unknown_ui"
pcall(function() gui:SetAttribute("AbyssUI",true) end)
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.DisplayOrder=64
gui.Enabled=true
pcall(function() gui.Parent=guiParent end)

local COL={bg=Color3.fromRGB(12,12,14),panel=Color3.fromRGB(18,18,21),elem=Color3.fromRGB(24,24,28),stroke=Color3.fromRGB(38,38,44),text=Color3.fromRGB(235,235,240),muted=Color3.fromRGB(120,120,130),accent=Color3.fromRGB(255,60,60),off=Color3.fromRGB(70,70,78)}
local function new(cls,props,parent) local o=Instance.new(cls) if props then for k,v in pairs(props) do pcall(function() o[k]=v end) end end if parent then pcall(function() o.Parent=parent end) end return o end
local function corner(p,r) return new("UICorner",{CornerRadius=UDim.new(0,r or 8)},p) end
local function stroke(p,c,t) return new("UIStroke",{Color=c or COL.stroke,Thickness=t or 1},p) end
local function tween(o,t,pr) if not o or not o.Parent then return end pcall(function() TWS:Create(o,TweenInfo.new(t or 0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),pr):Play() end) end

local main=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.fromOffset(560,480),BackgroundColor3=COL.bg,BorderSizePixel=0,ClipsDescendants=true,Visible=true},gui)
corner(main,10) stroke(main)
local topbar=new("Frame",{Size=UDim2.new(1,0,0,44),BackgroundColor3=COL.panel,BorderSizePixel=0},main)
corner(topbar,10)
new("Frame",{Size=UDim2.new(1,0,0,10),Position=UDim2.new(0,0,1,-10),BackgroundColor3=COL.panel,BorderSizePixel=0},topbar)
new("TextLabel",{Size=UDim2.new(1,-150,0,20),Position=UDim2.fromOffset(22,12),BackgroundTransparency=1,Text="unknown",Font=Enum.Font.Code,TextSize=16,TextColor3=COL.text,TextXAlignment=Enum.TextXAlignment.Left},topbar)
local hideBtn=new("TextButton",{Size=UDim2.fromOffset(24,24),Position=UDim2.new(1,-32,0.5,-12),BackgroundColor3=COL.elem,BorderSizePixel=0,Text="x",TextColor3=COL.text,Font=Enum.Font.GothamBold,TextSize=11,AutoButtonColor=false},topbar) corner(hideBtn,6)
local sidebar=new("Frame",{Size=UDim2.new(0,120,1,-52),Position=UDim2.fromOffset(8,48),BackgroundColor3=COL.panel,BorderSizePixel=0},main) corner(sidebar,8)
local tabList=new("ScrollingFrame",{Size=UDim2.new(1,-8,1,-8),Position=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,CanvasSize=UDim2.new()},sidebar)
local tabLayout=new("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},tabList)
App:Connect(tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"),function() tabList.CanvasSize=UDim2.fromOffset(0,tabLayout.AbsoluteContentSize.Y+4) end)
local pages=new("Frame",{Size=UDim2.new(1,-132,1,-52),Position=UDim2.fromOffset(128,48),BackgroundTransparency=1},main)

local openPopups={}
local function closePopups() for i=#openPopups,1,-1 do pcall(function() openPopups[i].Visible=false end) end openPopups={} end
local tabs,selectedTab={},nil
local function selectTab(rec) selectedTab=rec closePopups()
	for _,t in ipairs(tabs) do local sel=(t==rec) t.page.Visible=sel t.btn.BackgroundColor3=sel and COL.elem or COL.panel t.btn.TextColor3=sel and COL.text or COL.muted end end

local function addTab(name)
	local page=new("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ScrollBarThickness=3,ScrollBarImageColor3=COL.stroke,Visible=false,CanvasSize=UDim2.new()},pages)
	local layout=new("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},page)
	new("UIPadding",{PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,6)},page)
	App:Connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"),function() page.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+16) closePopups() end)
	local btn=new("TextButton",{Size=UDim2.new(1,0,0,30),BackgroundColor3=COL.panel,BorderSizePixel=0,Text=name,TextColor3=COL.muted,Font=Enum.Font.GothamMedium,TextSize=12,AutoButtonColor=false},tabList) corner(btn,6)
	local rec={name=name,page=page,btn=btn} table.insert(tabs,rec)
	App:Connect(btn.MouseButton1Click,function() selectTab(rec) end)
	if not selectedTab then selectTab(rec) end
	local Tab={} local order=0
	local function nextOrder() order=order+1 return order end
	local function row(h) local f=new("Frame",{Size=UDim2.new(1,0,0,h),BackgroundColor3=COL.elem,BorderSizePixel=0,LayoutOrder=nextOrder()},page) corner(f,7) stroke(f) return f end
	local function rtitle(f,t) return new("TextLabel",{Size=UDim2.new(0.62,-12,1,0),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Text=t,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=COL.text,Font=Enum.Font.Gotham,TextSize=13},f) end
	local function hoverize(f) App:Connect(f.MouseEnter,function() f.BackgroundColor3=Color3.fromRGB(30,30,35) end) App:Connect(f.MouseLeave,function() f.BackgroundColor3=COL.elem end) end
	local function addClick(f,cb) local o=new("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=5},f) App:Connect(o.MouseButton1Click,function() pcall(cb) end) return o end
	function Tab:Section(t) order=order+1 new("TextLabel",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text=t,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=COL.muted,Font=Enum.Font.GothamSemibold,TextSize=11,LayoutOrder=order},page) end
	function Tab:Label(t) local f=row(26) local l=rtitle(f,t) l.Size=UDim2.new(1,-14,1,0) l.TextColor3=COL.muted hoverize(f) return {Set=function(_,v) l.Text=tostring(v) end} end
	function Tab:Button(o) o=o or{} local f=row(30) local l=rtitle(f,o.Name or "Button") l.Size=UDim2.new(1,-14,1,0) hoverize(f) addClick(f,o.Callback) return {Set=function(_,v) l.Text=tostring(v) end} end
	function Tab:Toggle(o) o=o or{} local state=G(o.Path)==true local f=row(30) hoverize(f) rtitle(f,o.Name)
		local sw=new("Frame",{Size=UDim2.fromOffset(34,16),Position=UDim2.new(1,-42,0.5,-8),BackgroundColor3=COL.bg,BorderSizePixel=0},f) corner(sw,8) stroke(sw)
		local ind=new("Frame",{Size=UDim2.fromOffset(10,10),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=state and COL.accent or COL.off,BorderSizePixel=0},sw) corner(ind,6)
		local function paint(v) ind.BackgroundColor3=v and COL.accent or COL.off ind.Position=v and UDim2.new(1,-13,0.5,0) or UDim2.new(0,3,0.5,0) end
		UIRefs[o.Path]=UIRefs[o.Path] or {} table.insert(UIRefs[o.Path],paint) paint(state)
		addClick(f,function() Set(o.Path,not G(o.Path)) end)
		return {Set=function(_,v) paint(v) end}
	end
	function Tab:Slider(o) o=o or{} local min,max=o.Min or 0,o.Max or 100 local step=o.Step or 1 local val=math.clamp(tonumber(G(o.Path)) or min,min,max)
		local f=row(42) hoverize(f) rtitle(f,o.Name)
		local info=new("TextLabel",{Size=UDim2.fromOffset(80,14),Position=UDim2.new(1,-90,0,4),BackgroundTransparency=1,TextColor3=COL.text,Font=Enum.Font.Gotham,TextSize=11,TextXAlignment=Enum.TextXAlignment.Right},f)
		local track=new("Frame",{Size=UDim2.new(1,-20,0,4),Position=UDim2.fromOffset(10,30),BackgroundColor3=COL.off,BorderSizePixel=0},f) corner(track,2)
		local fill=new("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=COL.accent,BorderSizePixel=0},track) corner(fill,2)
		local function paint(v) local r=(max>min) and ((v-min)/(max-min)) or 0 fill.Size=UDim2.new(math.clamp(r,0,1),0,1,0) info.Text=tostring(v)..(o.Suffix or "") end
		UIRefs[o.Path]=UIRefs[o.Path] or {} table.insert(UIRefs[o.Path],paint) paint(val)
		local drag=false
		local function fromX(x) local w=math.max(track.AbsoluteSize.X,1) local r=math.clamp((x-track.AbsolutePosition.X)/w,0,1) local v=min+(max-min)*r v=math.floor(v/step+0.5)*step Set(o.Path,v) end
		App:Connect(track.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true fromX(i.Position.X) end end)
		App:Connect(UIS.InputChanged,function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then fromX(i.Position.X) end end)
		App:Connect(UIS.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
		return {Set=function(_,v) paint(v) end}
	end
	function Tab:Dropdown(o) o=o or{} local options=o.Options or {} local current=G(o.Path) or options[1]
		local f=row(30) hoverize(f) rtitle(f,o.Name)
		local sel=new("TextLabel",{Size=UDim2.new(0.34,-20,1,0),Position=UDim2.new(0.66,-14,0,0),BackgroundTransparency=1,Text=tostring(current),TextColor3=COL.muted,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Right},f)
		local list=new("ScrollingFrame",{BackgroundColor3=COL.panel,BorderSizePixel=0,Visible=false,ZIndex=120,ScrollBarThickness=2,Parent=gui}) corner(list,7) stroke(list)
		local ll=new("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},list)
		table.insert(openPopups,list)
		local function reposition() if not list.Visible or not f.Parent then return end local ap,as=f.AbsolutePosition,f.AbsoluteSize list.Size=UDim2.fromOffset(math.max(160,as.X),math.clamp(#options*27+8,28,190)) list.Position=UDim2.fromOffset(ap.X,ap.Y+as.Y+4) end
		for _,opt in ipairs(options) do
			local b=new("TextButton",{Size=UDim2.new(1,0,0,24),BackgroundColor3=COL.elem,BorderSizePixel=0,Text="  "..opt,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=COL.text,Font=Enum.Font.Gotham,TextSize=12,AutoButtonColor=false,ZIndex=122},list) corner(b,5)
			App:Connect(b.MouseButton1Click,function() current=opt sel.Text=tostring(opt) Set(o.Path,opt) list.Visible=false end)
		end
		addClick(f,function() list.Visible=not list.Visible if list.Visible then reposition() end end)
		return {Set=function(_,v) sel.Text=tostring(v) end}
	end
	function Tab:Keybind(o) o=o or{} local current=G(o.Path) or "None"
		local f=row(28) hoverize(f) rtitle(f,o.Name)
		local kb=new("TextButton",{Size=UDim2.fromOffset(76,20),Position=UDim2.new(1,-84,0.5,-10),BackgroundColor3=COL.panel,BorderSizePixel=0,Text=tostring(current),TextColor3=COL.text,Font=Enum.Font.Gotham,TextSize=11,AutoButtonColor=false},f) corner(kb,5) stroke(kb)
		local capturing=false
		App:Connect(kb.MouseButton1Click,function() capturing=true kb.Text="press" end)
		App:Connect(UIS.InputBegan,function(input) if capturing and input.KeyCode~=Enum.KeyCode.Unknown then capturing=false local n=input.KeyCode.Name kb.Text=n Set(o.Path,n) end end)
		return {Set=function(_,v) kb.Text=tostring(v) end}
	end
	return Tab
end

-- drag (close popups on drag)
do
	local dragging,dragStart,startPos=false,nil,nil
	App:Connect(topbar.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true dragStart=i.Position startPos=main.Position closePopups() end end)
	App:Connect(UIS.InputChanged,function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-dragStart main.Position=UDim2.new(0.5,startPos.X.Offset+d.X,0.5,startPos.Y.Offset+d.Y) end end)
	App:Connect(UIS.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
end
App:Connect(hideBtn.MouseButton1Click,function() main.Visible=false end)

-- modules state
local cam=WS.CurrentCamera
App:Connect(WS:GetPropertyChangedSignal("CurrentCamera"),function() cam=WS.CurrentCamera end)
local rayParams=RaycastParams.new() rayParams.FilterType=Enum.RaycastFilterType.Exclude rayParams.IgnoreWater=true
local internalRay=false
local function isVisible(pos,targetChar)
	if not cam then return true end
	local ignore={cam} local lc=localRec() if lc and lc.char then ignore[#ignore+1]=lc.char end
	rayParams.FilterDescendantsInstances=ignore
	local origin=cam.CFrame.Position local dir=pos-origin
	if dir.Magnitude<0.05 then return true end
	internalRay=true local ok,hit=pcall(WS.Raycast,WS,origin,dir,rayParams) internalRay=false
	if not ok then return true end if not hit then return true end
	if targetChar and hit.Instance and hit.Instance:IsDescendantOf(targetChar) then return true end
	return false
end
local function getBestHitbox(char) if not char then return nil end for _,n in ipairs({"Head","UpperTorso","HumanoidRootPart","Torso"}) do local p=char:FindFirstChild(n) if p and p:IsA("BasePart") then return p end end return nil end

-- aimbot
local cachedTarget=nil
local function getBestTarget()
	if not cam or not localRec() or not localRec().alive then return nil end
	local vp=cam.ViewportSize local center=Vector2.new(vp.X*0.5,vp.Y*0.5)
	local fov=S.Aimbot.FOV or 120 local best,bd=nil,fov
	for plr,rec in pairs(Cache.byPlayer) do
		if plr~=LP and rec.alive and rec.char then
			if not S.Aimbot.OnlyEnemies or rec.enemy then
				local part=getBestHitbox(rec.char)
				if part then
					local pos=part.Position
					if S.Aimbot.Prediction>0 then local vel=part.AssemblyLinearVelocity if typeof(vel)=="Vector3" then if vel.Magnitude>500 then vel=vel.Unit*500 end local lead=vel*S.Aimbot.Prediction if lead.Magnitude>35 then lead=lead.Unit*35 end pos=pos+lead end end
					local sp,on=cam:WorldToViewportPoint(pos)
					if on and sp.Z>0 then
						local d=(Vector2.new(sp.X,sp.Y)-center).Magnitude
						if d<=bd then
							if not S.Aimbot.WallCheck or isVisible(pos,rec.char) then bd=d best={rec=rec,part=part,pos=pos} end
						end
					end
				end
			end
		end
	end
	return best
end
local fovCircle=nil
if drawingAvailable then local ok,c=pcall(function() return Drawing.new("Circle") end) if ok and c then fovCircle=c c.Thickness=2 c.NumSides=64 c.Filled=false c.Visible=false App:Add(function() pcall(function() c:Remove() end) end) end end
App:BindRender("aim",Enum.RenderPriority.Camera.Value-1,function(dt)
	cam=WS.CurrentCamera
	if fovCircle then
		if (S.Aimbot.Enabled or S.Aimbot.Silent) and S.Aimbot.ShowFOV and cam then
			local vp=cam.ViewportSize fovCircle.Position=Vector2.new(vp.X*0.5,vp.Y*0.5) fovCircle.Radius=S.Aimbot.FOV fovCircle.Color=S.Aimbot.Silent and Color3.fromRGB(255,80,80) or Color3.fromRGB(0,255,100) fovCircle.Visible=true
		else fovCircle.Visible=false end
	end
	if not localRec() then cachedTarget=nil return end
	if S.Aimbot.Enabled or S.Aimbot.Silent then cachedTarget=getBestTarget() else cachedTarget=nil end
	if S.Aimbot.Enabled and cachedTarget and cam then
		local c=cam.CFrame local desired=CFrame.lookAt(c.Position,cachedTarget.pos)
		local sm=math.max(S.Aimbot.Smoothing,0.01)
		local alpha=math.clamp(1-math.exp(-(dt or 1/60)*(60/sm)),0,1)
		cam.CFrame=c:Lerp(desired,alpha)
	end
end)

-- silent hook
local hookOn,origNC,mt=false,nil,nil
local function hookBody(self,...)
	if internalRay or not S.Aimbot.Silent then return origNC(self,...) end
	if self~=WS then return origNC(self,...) end
	local m=getnamecallmethod()
	local isRay=(m=="Raycast") local isLegacy=(m=="FindPartOnRay" or m=="FindPartOnRayWithIgnoreList" or m=="FindPartOnRayWithWhitelist")
	if not isRay and not isLegacy then return origNC(self,...) end
	local origin,dir
	if isRay then origin,dir=select(1,...),select(2,...) if typeof(origin)~="Vector3" or typeof(dir)~="Vector3" then return origNC(self,...) end
	else local r=select(1,...) if typeof(r)~="Ray" then return origNC(self,...) end origin,dir=r.Origin,r.Direction end
	if dir.Magnitude<0.5 then return origNC(self,...) end
	local lc=localRec() local hrp=lc and lc.root
	if not hrp or (origin-hrp.Position).Magnitude>60 then return origNC(self,...) end
	local t=cachedTarget
	if not t or not t.rec.alive or not t.part or not t.part.Parent then return origNC(self,...) end
	local diff=t.pos-origin if diff.Magnitude<0.5 then return origNC(self,...) end
	local nd=diff.Unit*dir.Magnitude
	if isRay then local a={...} a[2]=nd return origNC(self,table.unpack(a)) else local a={...} a[1]=Ray.new(origin,nd) return origNC(self,table.unpack(a)) end
end
local function installHook()
	if hookOn or not (type(getrawmetatable)=="function" and type(setreadonly)=="function" and type(newcclosure)=="function" and type(getnamecallmethod)=="function") then return end
	local ok,gmt=pcall(getrawmetatable,game) if not ok or not gmt then return end
	mt=gmt origNC=mt.__namecall
	pcall(setreadonly,mt,false) pcall(function() mt.__namecall=newcclosure(hookBody) end) pcall(setreadonly,mt,true)
	hookOn=true
end
local function uninstallHook() if not hookOn or not mt or not origNC then return end pcall(setreadonly,mt,false) pcall(function() mt.__namecall=origNC end) pcall(setreadonly,mt,true) hookOn=false end
installHook()

-- triggerbot
local lastTrigger=0
App:Connect(RS.Heartbeat,function()
	if not S.Trigger.Enabled or not cam then return end
	local now=os.clock() if now-lastTrigger<S.Trigger.Cooldown then return end
	local t=cachedTarget
	if t and t.rec.alive then
		if not S.Trigger.OnlyEnemies or t.rec.enemy then
			if not S.Trigger.WallCheck or isVisible(t.pos,t.rec.char) then
				lastTrigger=now
				if type(mouse1click)=="function" then pcall(mouse1click) else local lc=localRec() local tool=lc and lc.char and lc.char:FindFirstChildOfClass("Tool") if tool then pcall(function() tool:Activate() end) end end
			end
		end
	end
end)

-- ESP
local ESPS={}
local function releaseViz(rec) local v=ESPS[rec] if not v then return end if v.box then release(v.box,"Square") end if v.hpBg then release(v.hpBg,"Square") end if v.hpFill then release(v.hpFill,"Square") end if v.snap then release(v.snap,"Line") end if v.name then release(v.name,"Text") end if v.dist then release(v.dist,"Text") end if v.chams then pcall(function() v.chams:Destroy() end) end ESPS[rec]=nil end
App:BindRender("esp",Enum.RenderPriority.Camera.Value+2,function()
	cam=WS.CurrentCamera
	if not S.ESP.Enabled or not drawingAvailable or not cam then for _,rec in pairs(Cache.byPlayer) do releaseViz(rec) end return end
	local camPos=cam.CFrame.Position
	for _,rec in pairs(Cache.byPlayer) do
		if rec.plr~=LP then
			if not rec.alive or not rec.root then releaseViz(rec) else
				if S.ESP.OnlyEnemies and not rec.enemy then releaseViz(rec) else
					local dist=(rec.root.Position-camPos).Magnitude
					if dist>S.ESP.MaxDistance then releaseViz(rec) else
						local v=ESPS[rec] or {} ESPS[rec]=v
						local headPos=(rec.head and rec.head.Position) or (rec.root.Position+Vector3.new(0,2.5,0))
						local legPos=rec.root.Position-Vector3.new(0,2.5,0)
						local hSp=cam:WorldToViewportPoint(headPos) local lSp=cam:WorldToViewportPoint(legPos)
						if hSp.Z<0 and lSp.Z<0 then releaseViz(rec) else
							local height=math.abs(lSp.Y-hSp.Y) local width=height*0.5 local x=hSp.X-width*0.5 local y=hSp.Y
							local color=rec.enemy and Color3.fromRGB(255,60,60) or Color3.fromRGB(90,140,255)
							if S.ESP.Boxes then v.box=v.box or acquire("Square") if v.box then v.box.Filled=false v.box.Thickness=1 v.box.Color=color v.box.Size=Vector2.new(width,height) v.box.Position=Vector2.new(x,y) v.box.Visible=true end elseif v.box then release(v.box,"Square") v.box=nil end
							if S.ESP.HealthBar and rec.hum and rec.hum.MaxHealth>0 then
								v.hpBg=v.hpBg or acquire("Square") v.hpFill=v.hpFill or acquire("Square")
								local pct=math.clamp(rec.hum.Health/rec.hum.MaxHealth,0,1)
								if v.hpBg then v.hpBg.Filled=true v.hpBg.Color=Color3.fromRGB(0,0,0) v.hpBg.Size=Vector2.new(3,height) v.hpBg.Position=Vector2.new(x-5,y) v.hpBg.Visible=true end
								if v.hpFill then local bh=height*pct v.hpFill.Filled=true v.hpFill.Size=Vector2.new(3,bh) v.hpFill.Position=Vector2.new(x-5,y+(height-bh)) v.hpFill.Color=Color3.fromRGB(60,220,60):Lerp(Color3.fromRGB(220,60,60),1-pct) v.hpFill.Visible=true end
							else if v.hpBg then release(v.hpBg,"Square") v.hpBg=nil end if v.hpFill then release(v.hpFill,"Square") v.hpFill=nil end end
							if S.ESP.Snaplines then v.snap=v.snap or acquire("Line") if v.snap then local vp=cam.ViewportSize v.snap.Thickness=1 v.snap.Color=color v.snap.From=Vector2.new(vp.X*0.5,vp.Y) v.snap.To=Vector2.new(hSp.X,hSp.Y) v.snap.Visible=true end elseif v.snap then release(v.snap,"Line") v.snap=nil end
							if S.ESP.Names then v.name=v.name or acquire("Text") if v.name then v.name.Size=13 v.name.Center=true v.name.Outline=true v.name.Color=color v.name.Text=(rec.plr.DisplayName~="" and rec.plr.DisplayName) or rec.plr.Name v.name.Position=Vector2.new(hSp.X,y-16) v.name.Visible=true end elseif v.name then release(v.name,"Text") v.name=nil end
							if S.ESP.Distance then v.dist=v.dist or acquire("Text") if v.dist then v.dist.Size=12 v.dist.Center=true v.dist.Outline=true v.dist.Color=Color3.fromRGB(255,255,255) v.dist.Text=math.floor(dist).."m" v.dist.Position=Vector2.new(hSp.X,y+height+4) v.dist.Visible=true end elseif v.dist then release(v.dist,"Text") v.dist=nil end
							if S.ESP.Chams then
								if not v.chams or v.chams.Parent~=rec.char then if v.chams then pcall(function() v.chams:Destroy() end) end local h=Instance.new("Highlight") h.FillColor=color h.OutlineColor=Color3.fromRGB(255,255,255) h.FillTransparency=0.4 pcall(function() h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop end) h.Adornee=rec.char h.Parent=rec.char v.chams=h else v.chams.FillColor=color v.chams.Enabled=true end
							elseif v.chams then pcall(function() v.chams:Destroy() end) v.chams=nil end
						end
					end
				end
			end
		end
	end
end)

-- movement
local MV={origWalk=nil,fly=nil,ncOn=false,lastJump=0,lastBhop=0}
local function destroyFly() if MV.fly then pcall(function() MV.fly.lv:Destroy() end) pcall(function() MV.fly.ao:Destroy() end) pcall(function() MV.fly.att:Destroy() end) MV.fly=nil end
local function createFly(root)
	destroyFly()
	local att=Instance.new("Attachment") att.Parent=root
	local lv=Instance.new("LinearVelocity") lv.Attachment0=att lv.MaxForce=math.huge lv.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector lv.VectorVelocity=Vector3.zero lv.Parent=root
	local ao=Instance.new("AlignOrientation") ao.Attachment0=att ao.MaxTorque=math.huge ao.Responsiveness=200 ao.Mode=Enum.OrientationAlignmentMode.OneAttachment ao.Parent=root
	MV.fly={att=att,lv=lv,ao=ao}
end
App:Connect(LP.CharacterAdded,function(char)
	MV.origWalk=nil destroyFly() MV.ncOn=false
	char:WaitForChild("HumanoidRootPart",5)
end)
App:Connect(RS.Heartbeat,function(dt)
	local lc=localRec() if not lc or not lc.alive or not lc.hum or not lc.root then return end
	local hum,root=lc.hum,lc.root
	if S.Move.Speed then
		if MV.origWalk==nil then MV.origWalk=hum.WalkSpeed end
		if S.Move.SpeedMode=="Walk" then if hum.WalkSpeed~=S.Move.SpeedValue then hum.WalkSpeed=S.Move.SpeedValue end
		else local md=hum.MoveDirection if md.Magnitude>0.1 then local v=root.AssemblyLinearVelocity root.AssemblyLinearVelocity=Vector3.new(md.X*S.Move.SpeedValue,v.Y,md.Z*S.Move.SpeedValue) end end
	elseif MV.origWalk then if hum.WalkSpeed~=MV.origWalk then hum.WalkSpeed=MV.origWalk end MV.origWalk=nil end
	if S.Move.NoClip~=MV.ncOn then
		if lc.char then for _,part in ipairs(lc.char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide=not S.Move.NoClip end end end
		MV.ncOn=S.Move.NoClip
	end
	if S.Move.InfJump and UIS:IsKeyDown(Enum.KeyCode.Space) and tick()-MV.lastJump>0.22 then hum:ChangeState(Enum.HumanoidStateType.Jumping) MV.lastJump=tick() end
	if S.Move.Bhop and UIS:IsKeyDown(Enum.KeyCode.Space) then local s=hum:GetState() if s==Enum.HumanoidStateType.Landed or s==Enum.HumanoidStateType.Running then if tick()-MV.lastBhop>0.1 then hum:ChangeState(Enum.HumanoidStateType.Jumping) MV.lastBhop=tick() end end end
	if S.Move.Fly then
		if not MV.fly or not (MV.fly.lv and MV.fly.lv.Parent==root) then createFly(root) end
		local move=Vector3.zero
		if cam then local look,right=cam.CFrame.LookVector,cam.CFrame.RightVector
			if UIS:IsKeyDown(Enum.KeyCode.W) then move=move+look end if UIS:IsKeyDown(Enum.KeyCode.S) then move=move-look end
			if UIS:IsKeyDown(Enum.KeyCode.A) then move=move-right end if UIS:IsKeyDown(Enum.KeyCode.D) then move=move+right end end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then move=move+Vector3.new(0,1,0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move=move-Vector3.new(0,1,0) end
		if MV.fly then MV.fly.lv.VectorVelocity=(move.Magnitude>0) and (move.Unit*S.Move.FlyValue) or Vector3.zero if cam then MV.fly.ao.CFrame=cam.CFrame end end
	else destroyFly() end
end)

-- antiaim
local AA={rootJ=nil,neck=nil,origRoot=nil,origNeck=nil}
App:Connect(LP.CharacterAdded,function() AA.rootJ,AA.neck,AA.origRoot,AA.origNeck=nil,nil,nil,nil end)
App:BindRender("aa",Enum.RenderPriority.Camera.Value+5,function(dt)
	local lc=localRec() if not lc or not lc.root then return end
	local root=lc.root
	if not AA.rootJ then local j=root:FindFirstChild("RootJoint") if j and j:IsA("Motor6D") then AA.rootJ=j AA.origRoot=j.C0 end end
	if not AA.neck and lc.head then local n=lc.head:FindFirstChild("Neck") if n and n:IsA("Motor6D") then AA.neck=n AA.origNeck=n.C0 end end
	local anyAA=S.AA.Jitter or S.AA.Desync or S.AA.HideHead
	if not anyAA then
		if AA.rootJ and AA.origRoot and AA.rootJ.C0~=AA.origRoot then AA.rootJ.C0=AA.origRoot end
		if AA.neck and AA.origNeck and AA.neck.C0~=AA.origNeck then AA.neck.C0=AA.origNeck end
		return
	end
	local jit=0
	if S.AA.Jitter then jit=math.sin(tick()*12)*math.rad(S.AA.JitterAngle) end
	local des=0
	if S.AA.Desync then
		if S.AA.DesyncMode=="Spin" then des=math.rad(tick()*S.AA.DesyncSpeed) elseif S.AA.DesyncMode=="Static" then des=math.rad(60) else des=math.rad(180) end
	end
	if AA.rootJ and AA.origRoot then AA.rootJ.C0=AA.origRoot*CFrame.Angles(0,jit+des,0) end
	if S.AA.HideHead and AA.neck and AA.origNeck then AA.neck.C0=AA.origNeck*CFrame.Angles(0,math.rad(180),0)
	elseif AA.neck and AA.origNeck and AA.neck.C0~=AA.origNeck then AA.neck.C0=AA.origNeck end
end)

-- rage
local rageInstances={}
local function destroyRage() for _,i in ipairs(rageInstances) do pcall(function() i:Destroy() end) end table.clear(rageInstances) end
local lastRage=0
App:Connect(RS.Heartbeat,function()
	if not S.Rage.Enabled then return end
	local now=tick() if now-lastRage<0.5 then return end lastRage=now
	local lc=localRec() if not lc or not lc.root or not lc.alive then return end
	if S.Rage.MassFling then
		for plr,rec in pairs(Cache.byPlayer) do
			if plr~=LP and rec.alive and rec.root and rec.enemy then
				if S.Rage.FlingTarget=="All" or (lc.root.Position-rec.root.Position).Magnitude<20 then
					pcall(function() local bv=Instance.new("BodyVelocity") bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge) bv.Velocity=Vector3.new((math.random()-0.5)*500,300,(math.random()-0.5)*500) bv.Parent=rec.root rageInstances[#rageInstances+1]=bv task.delay(0.5,function() pcall(function() bv:Destroy() end) end) end)
				end
			end
		end
	end
	if S.Rage.VoidTP then
		for plr,rec in pairs(Cache.byPlayer) do if plr~=LP and rec.alive and rec.root and rec.enemy and (lc.root.Position-rec.root.Position).Magnitude<20 then pcall(function() rec.root.CFrame=CFrame.new(0,-500,0) end) end end
	end
	if S.Rage.LagMachine then
		if #rageInstances<(S.Rage.LagMachine and 20 or 0) then
			pcall(function() local p=Instance.new("Part") p.Size=Vector3.new(1,1,1) p.Anchored=false p.CanCollide=false p.Transparency=1 p.CFrame=lc.root.CFrame*CFrame.new((math.random()-0.5)*20,(math.random()-0.5)*20,(math.random()-0.5)*20)
				local av=Instance.new("AngularVelocity") av.AngularVelocity=Vector3.new((math.random()-0.5)*100,(math.random()-0.5)*100,(math.random()-0.5)*100) av.MaxTorque=math.huge local att=Instance.new("Attachment") att.Parent=p av.Attachment0=att av.Parent=p p.Parent=WS rageInstances[#rageInstances+1]=p end)
		end
	else
		for i=#rageInstances,1,-1 do local o=rageInstances[i] if o and o:IsA("Part") then pcall(function() o:Destroy() end) table.remove(rageInstances,i) end end
	end
end)

-- misc: watermark + keybind display + antiafk
local wmText,kdText=nil,nil
if drawingAvailable then
	local ok1,t1=pcall(function() return Drawing.new("Text") end) if ok1 and t1 then wmText=t1 t1.Size=13 t1.Outline=true t1.Visible=false App:Add(function() pcall(function() t1:Remove() end) end) end
	local ok2,t2=pcall(function() return Drawing.new("Text") end) if ok2 and t2 then kdText=t2 t2.Size=13 t2.Outline=true t2.Visible=false App:Add(function() pcall(function() t2:Remove() end) end) end
end
local diagAcc=0
App:Connect(RS.Heartbeat,function(dt)
	diagAcc=diagAcc+dt if diagAcc<0.25 then return end diagAcc=0
	if wmText then wmText.Visible=S.Misc.Watermark if S.Misc.Watermark then wmText.Text="unknown v12" wmText.Position=Vector2.new(10,10) wmText.Color=Color3.fromRGB(235,235,240) end end
	if kdText then kdText.Visible=S.Misc.KeybindDisplay if S.Misc.KeybindDisplay then kdText.Text=string.format("[%s] Aim [%s] Silent [%s] Fly [%s] Speed",S.Keys.Aimbot,S.Keys.Silent,S.Keys.Fly,S.Keys.Speed) kdText.Position=Vector2.new(10,30) kdText.Color=Color3.fromRGB(235,235,240) end end
end)
App:Connect(LP.Idled,function() if S.Misc.AntiAFK then pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end) end end)

-- panic + hotkeys
local function panic()
	for _,p in ipairs(DANGEROUS) do Set(p,false) end
	destroyFly() destroyRage()
	cachedTarget=nil
end
App:Connect(UIS.InputBegan,function(input,processed)
	if processed then return end
	local kc=input.KeyCode.Name
	if kc==S.Misc.PanicKey then panic() return end
	if kc==S.Keys.UI then main.Visible=not main.Visible return end
	if kc==S.Keys.Aimbot then Set("Aimbot.Enabled",not G("Aimbot.Enabled")) end
	if kc==S.Keys.Silent then Set("Aimbot.Silent",not G("Aimbot.Silent")) end
	if kc==S.Keys.Fly then Set("Move.Fly",not G("Move.Fly")) end
	if kc==S.Keys.Speed then Set("Move.Speed",not G("Move.Speed")) end
	if kc==S.Keys.ESP then Set("ESP.Enabled",not G("ESP.Enabled")) end
end)

-- UI wiring
local tCombat=addTab("combat")
tCombat:Section("aimbot")
tCombat:Toggle({Name="Aimbot",Path="Aimbot.Enabled"})
tCombat:Toggle({Name="Silent Aim",Path="Aimbot.Silent"})
tCombat:Toggle({Name="Wall Check",Path="Aimbot.WallCheck"})
tCombat:Toggle({Name="Only Enemies",Path="Aimbot.OnlyEnemies"})
tCombat:Toggle({Name="FOV Circle",Path="Aimbot.ShowFOV"})
tCombat:Slider({Name="FOV",Path="Aimbot.FOV",Min=20,Max=600,Step=10})
tCombat:Slider({Name="Smoothing",Path="Aimbot.Smoothing",Min=1,Max=20,Step=1})
tCombat:Slider({Name="Prediction",Path="Aimbot.Prediction",Min=0,Max=0.5,Step=0.01})
tCombat:Section("triggerbot")
tCombat:Toggle({Name="TriggerBot",Path="Trigger.Enabled"})
tCombat:Toggle({Name="Trigger WallCheck",Path="Trigger.WallCheck"})
local tVis=addTab("visuals")
tVis:Section("esp")
tVis:Toggle({Name="ESP",Path="ESP.Enabled"})
tVis:Toggle({Name="Boxes",Path="ESP.Boxes"})
tVis:Toggle({Name="Health Bar",Path="ESP.HealthBar"})
tVis:Toggle({Name="Snaplines",Path="ESP.Snaplines"})
tVis:Toggle({Name="Names",Path="ESP.Names"})
tVis:Toggle({Name="Distance",Path="ESP.Distance"})
tVis:Toggle({Name="Chams",Path="ESP.Chams"})
tVis:Slider({Name="Max Distance",Path="ESP.MaxDistance",Min=50,Max=2000,Step=50})
local tMove=addTab("move")
tMove:Section("speed")
tMove:Toggle({Name="Speed",Path="Move.Speed"})
tMove:Dropdown({Name="Mode",Path="Move.SpeedMode",Options={"Walk","Vel"}})
tMove:Slider({Name="Speed",Path="Move.SpeedValue",Min=16,Max=200,Step=1})
tMove:Section("fly")
tMove:Toggle({Name="Fly",Path="Move.Fly"})
tMove:Slider({Name="Fly Speed",Path="Move.FlyValue",Min=20,Max=200,Step=5})
tMove:Section("other")
tMove:Toggle({Name="NoClip",Path="Move.NoClip"})
tMove:Toggle({Name="Inf Jump",Path="Move.InfJump"})
tMove:Toggle({Name="Bhop",Path="Move.Bhop"})
local tAA=addTab("antiaim")
tAA:Section("angles")
tAA:Toggle({Name="Jitter",Path="AA.Jitter"})
tAA:Slider({Name="Jitter Angle",Path="AA.JitterAngle",Min=10,Max=180,Step=5})
tAA:Toggle({Name="Desync",Path="AA.Desync"})
tAA:Dropdown({Name="Desync Mode",Path="AA.DesyncMode",Options={"Spin","Static","Backwards"}})
tAA:Toggle({Name="Hide Head",Path="AA.HideHead"})
local tRage=addTab("rage")
tRage:Section("master")
tRage:Toggle({Name="Rage Master",Path="Rage.Enabled"})
tRage:Toggle({Name="Mass Fling",Path="Rage.MassFling"})
tRage:Dropdown({Name="Fling Target",Path="Rage.FlingTarget",Options={"Nearest","All"}})
tRage:Toggle({Name="Void TP",Path="Rage.VoidTP"})
local tMisc=addTab("misc")
tMisc:Section("safety")
tMisc:Button({Name="PANIC NOW",Callback=panic})
tMisc:Toggle({Name="Watermark",Path="Misc.Watermark"})
tMisc:Toggle({Name="Keybind Display",Path="Misc.KeybindDisplay"})
tMisc:Toggle({Name="Anti-AFK",Path="Misc.AntiAFK"})
tMisc:Section("keybinds")
tMisc:Keybind({Name="UI Key",Path="Keys.UI"})
tMisc:Keybind({Name="Aimbot Key",Path="Keys.Aimbot"})
tMisc:Keybind({Name="Silent Key",Path="Keys.Silent"})
tMisc:Keybind({Name="Fly Key",Path="Keys.Fly"})
tMisc:Keybind({Name="Speed Key",Path="Keys.Speed"})

-- load config then force safe inject
loadConfig()
for _,p in ipairs(DANGEROUS) do local g,k=p:match("^(%w+)%.(%w+)$") if S[g] then S[g][k]=false end end
for p,list in pairs(UIRefs) do for _,fn in ipairs(list) do pcall(fn,G(p)) end end

-- unload
local function Unload()
	pcall(panic)
	pcall(uninstallHook)
	for _,s in ipairs(scopes) do s:Destroy() end
	table.clear(scopes)
	pcall(nukePool)
	pcall(destroyFly) pcall(destroyRage)
	local lc=localRec()
	if lc and lc.hum and MV.origWalk then pcall(function() lc.hum.WalkSpeed=MV.origWalk end) end
	if wmText then pcall(function() wmText:Remove() end) end
	if kdText then pcall(function() kdText:Remove() end) end
	if fovCircle then pcall(function() fovCircle:Remove() end) end
	if gui then pcall(function() gui:Destroy() end) end
	ENV.__ABYSS=nil
end
ENV.__ABYSS={Unload=Unload}

-- ensure visible
main.Visible=true
gui.Enabled=true
print("[unknown v12] ready // RightShift = UI // End = panic")
