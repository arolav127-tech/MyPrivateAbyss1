local RS=game:GetService("RunService")
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local TWS=game:GetService("TweenService")
local HS=game:GetService("HttpService")
local GuiService=game:GetService("GuiService")
local CoreGui=game:GetService("CoreGui")
if not RS:IsClient() then return end
local LP=Players.LocalPlayer or Players.PlayerAdded:Wait()

local CAP={
	drawing=type(Drawing)=="table" and type(Drawing.new)=="function",
	fs=type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function" and type(makefolder)=="function" and type(isfolder)=="function",
	hook=type(getrawmetatable)=="function" and type(setreadonly)=="function" and type(newcclosure)=="function" and type(getnamecallmethod)=="function",
	gethui=type(gethui)=="function",
	mouse1=type(mouse1click)=="function",
}
local ENV=(type(getgenv)=="function" and getgenv()) or _G
if type(ENV.__ABYSS)=="table" and type(ENV.__ABYSS.Unload)=="function" then pcall(ENV.__ABYSS.Unload) end
ENV.__ABYSS=nil

-- Scope
local scopes={}
local function newScope(name)
	local s={name=name,alive=true,conns={},insts={},fns={},renders={}}
	function s:Connect(sig,fn) if not self.alive then return nil end local c=sig:Connect(fn) self.conns[#self.conns+1]=c return c end
	function s:Give(i) if not self.alive then pcall(function() i:Destroy() end) return i end self.insts[#self.insts+1]=i return i end
	function s:Add(fn) if not self.alive then pcall(fn) return end self.fns[#self.fns+1]=fn end
	function s:BindRender(key,prio,fn) if not self.alive then return end local nm="ABYSS_"..key self.renders[#self.renders+1]=nm RS:BindToRenderStep(nm,prio,function(dt) if self.alive then pcall(fn,dt) end end) end
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

-- Settings
local S={
	Aimbot={Enabled=false,Silent=false,FOV=120,Smoothing=5,Prediction=0.12,WallCheck=true,OnlyEnemies=true,
		RequireMouseDown=false,MaxSilentPerSec=0,MinShotDelay=0,DirDotMin=0.2,Humanizer=0.4,HitChance=100},
	Trigger={Enabled=false,OnlyEnemies=true,WallCheck=true,Cooldown=0.15},
	ESP={Enabled=false,Boxes=true,HealthBar=true,Snaplines=false,Names=true,Distance=false,Chams=false,OnlyEnemies=true,MaxDistance=500},
	Move={Speed=false,SpeedMode="Walk",SpeedValue=16,Fly=false,FlyValue=50,NoClip=false,InfJump=false,Bhop=false},
	AA={Jitter=false,JitterAngle=40,Desync=false,DesyncMode="Spin",HideHead=false,FakeLag=false},
	Rage={Enabled=false,MassFling=false,FlingTarget="Nearest",VoidTP=false,Spinbot=false,SpinSpeed=25,LagMachine=false,LagCount=20},
	Misc={Watermark=true,KeybindDisplay=true,AntiAFK=true,PanicKey="End"},
	Keys={UI="RightShift",Aimbot="X",Silent="B",Fly="F",Speed="V"},
}
local WATCH,UIREFS={},{}
local function watch(p,fn) WATCH[p]=WATCH[p] or {} WATCH[p][#WATCH[p]+1]=fn end
local function uiref(p,fn) UIREFS[p]=UIREFS[p] or {} UIREFS[p][#UIREFS[p]+1]=fn end
local function G(p) local g,k=p:match("^(%w+)%.(%w+)$") return S[g] and S[g][k] end
local function setPath(p,v) local g,k=p:match("^(%w+)%.(%w+)$") if S[g] then S[g][k]=v end end

local saveQueued=false
local CFGPATH="AbyssFW/unknown_v10.json"
local function fsOk() return CAP.fs end
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
	for g,keys in pairs(S) do
		if type(data[g])=="table" then
			for k in pairs(keys) do
				local v=data[g][k]
				if type(v)==type(keys[k]) then S[g][k]=v end
			end
		end
	end
end
loadConfig()

-- Helpers
local cam=WS.CurrentCamera
App:Connect(WS:GetPropertyChangedSignal("CurrentCamera"),function() cam=WS.CurrentCamera end)
local function localRec() return Cache and Cache.byPlayer[LP] end
local rayParams=RaycastParams.new()
rayParams.FilterType=Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater=true
local internalRay=false
local function isVisible(pos,targetChar)
	if not cam then return true end
	local ignore={cam}
	local lc=localRec() if lc and lc.char then ignore[#ignore+1]=lc.char end
	rayParams.FilterDescendantsInstances=ignore
	local origin=cam.CFrame.Position
	local dir=pos-origin
	if dir.Magnitude<0.05 then return true end
	internalRay=true
	local ok,hit=pcall(WS.Raycast,WS,origin,dir,rayParams)
	internalRay=false
	if not ok then return true end
	if not hit then return true end
	if targetChar and hit.Instance and hit.Instance:IsDescendantOf(targetChar) then return true end
	return false
end

-- GUI (IgnoreGuiInset=false — фикс ввода/отображения)
local COL={bg=Color3.fromRGB(12,12,14),panel=Color3.fromRGB(18,18,21),elem=Color3.fromRGB(24,24,28),stroke=Color3.fromRGB(38,38,44),text=Color3.fromRGB(235,235,240),muted=Color3.fromRGB(120,120,130),accent=Color3.fromRGB(255,60,60),off=Color3.fromRGB(70,70,78)}
local guiParent
do
	local ok,t=nil,nil
	if CAP.gethui then ok,t=pcall(gethui) end
	if ok and t then guiParent=t else
		ok,t=pcall(function() return LP:WaitForChild("PlayerGui",3) end)
		guiParent=(ok and t) or CoreGui
	end
end
local gui=App:Give(Instance.new("ScreenGui"))
gui.Name="unk_v10_"..math.random(100,999)
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false -- ВАЖНО: false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.DisplayOrder=100
gui.Parent=guiParent

local function inst(c,props,parent) local o=Instance.new(c) if props then for k,v in pairs(props) do o[k]=v end end if parent then o.Parent=parent end return o end
local function corner(p,r) inst("UICorner",{CornerRadius=UDim.new(0,r or 8)},p) end
local function stroke(p,c,t) inst("UIStroke",{Color=c or COL.stroke,Thickness=t or 1},p) end

-- Tooltip
local tip=inst("Frame",{Size=UDim2.fromOffset(220,40),BackgroundColor3=COL.bg,BackgroundTransparency=0.08,BorderSizePixel=0,Visible=false,ZIndex=300},gui)
corner(tip,8) stroke(tip,COL.accent,1)
local tipText=inst("TextLabel",{Size=UDim2.new(1,-12,1,-8),Position=UDim2.fromOffset(6,4),BackgroundTransparency=1,Text="",TextColor3=COL.text,Font=Enum.Font.Gotham,TextSize=11,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top},tip)
local tipVisible=false
local function showTip(text) tipText.Text=text tip.Visible=true tipVisible=true
	local b=tipText.TextBounds tip.Size=UDim2.fromOffset(math.clamp(b.X+16,120,260),b.Y+10) end
local function hideTip() tip.Visible=false tipVisible=false end
App:Connect(UIS.InputChanged,function(input)
	if tipVisible and input.UserInputType==Enum.UserInputType.MouseMovement then
		local vp=gui.AbsoluteSize
		local m=UIS:GetMouseLocation()
		local inset=GuiService:GetGuiInset()
		local x=math.clamp(m.X+14,4,math.max(4,vp.X-tip.AbsoluteSize.X-4))
		local y=math.clamp(m.Y-inset.Y+16,4,math.max(4,vp.Y-tip.AbsoluteSize.Y-4))
		tip.Position=UDim2.fromOffset(x,y)
	end
end)
local function hookTip(frame,desc) if not desc or desc=="" then return end
	App:Connect(frame.MouseEnter,function() showTip(desc) end)
	App:Connect(frame.MouseLeave,function() hideTip() end)
end

local main=inst("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.fromOffset(640,480),BackgroundColor3=COL.bg,BorderSizePixel=0,ClipsDescendants=true},gui)
corner(main,10) stroke(main)
local topbar=inst("Frame",{Size=UDim2.new(1,0,0,44),BackgroundColor3=COL.panel,BorderSizePixel=0},main)
corner(topbar,10)
inst("Frame",{Size=UDim2.new(1,0,0,10),Position=UDim2.new(0,0,1,-10),BackgroundColor3=COL.panel,BorderSizePixel=0},topbar)
inst("TextLabel",{Size=UDim2.new(1,-150,0,20),Position=UDim2.fromOffset(22,12),BackgroundTransparency=1,Text="unknown",Font=Enum.Font.Code,TextSize=16,TextColor3=COL.text,TextXAlignment=Enum.TextXAlignment.Left},topbar)
inst("TextLabel",{Size=UDim2.fromOffset(140,14),Position=UDim2.new(1,-150,0.5,-7),BackgroundTransparency=1,Text="v10 // stable",Font=Enum.Font.Code,TextSize=10,TextColor3=COL.muted,TextXAlignment=Enum.TextXAlignment.Right},topbar)
local hideBtn=inst("TextButton",{Size=UDim2.fromOffset(24,24),Position=UDim2.new(1,-32,0.5,-12),BackgroundColor3=COL.elem,BorderSizePixel=0,Text="x",TextColor3=COL.text,Font=Enum.Font.GothamBold,TextSize=11,AutoButtonColor=false},topbar) corner(hideBtn,6)
local sidebar=inst("Frame",{Size=UDim2.new(0,120,1,-52),Position=UDim2.fromOffset(8,48),BackgroundColor3=COL.panel,BorderSizePixel=0},main) corner(sidebar,8)
local tabList=inst("ScrollingFrame",{Size=UDim2.new(1,-8,1,-8),Position=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,CanvasSize=UDim2.new()},sidebar)
local tabLayout=inst("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},tabList)
App:Connect(tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"),function() tabList.CanvasSize=UDim2.fromOffset(0,tabLayout.AbsoluteContentSize.Y+4) end)
local pages=inst("Frame",{Size=UDim2.new(1,-132,1,-52),Position=UDim2.fromOffset(128,48),BackgroundTransparency=1},main)

local tabs,selectedTab={},nil
local function selectTab(rec) selectedTab=rec hideTip()
	for _,t in ipairs(tabs) do local sel=(t==rec) t.page.Visible=sel t.btn.BackgroundColor3=sel and COL.elem or COL.panel t.btn.TextColor3=sel and COL.text or COL.muted end end
local function addTab(name)
	local page=inst("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ScrollBarThickness=3,ScrollBarImageColor3=COL.stroke,Visible=false,CanvasSize=UDim2.new()},pages)
	local layout=inst("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},page)
	inst("UIPadding",{PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,6)},page)
	App:Connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"),function() page.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+16) end)
	local btn=inst("TextButton",{Size=UDim2.new(1,0,0,30),BackgroundColor3=COL.panel,BorderSizePixel=0,Text=name,TextColor3=COL.muted,Font=Enum.Font.GothamMedium,TextSize=12,AutoButtonColor=false},tabList) corner(btn,6)
	local rec={name=name,page=page,btn=btn} table.insert(tabs,rec)
	App:Connect(btn.MouseButton1Click,function() selectTab(rec) end)
	if not selectedTab then selectTab(rec) end
	local Tab={} local order=0
	local function row(h) order=order+1 local f=inst("Frame",{Size=UDim2.new(1,0,0,h),BackgroundColor3=COL.elem,BorderSizePixel=0,LayoutOrder=order},page) corner(f,7) stroke(f) return f end
	local function rtitle(f,t) return inst("TextLabel",{Size=UDim2.new(0.62,-12,1,0),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Text=t,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=COL.text,Font=Enum.Font.Gotham,TextSize=13},f) end
	local function click(f,cb) local o=inst("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=5},f) App:Connect(o.MouseButton1Click,function() pcall(cb) end) return o end
	function Tab:Section(t) order=order+1 inst("TextLabel",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text=t,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=COL.muted,Font=Enum.Font.GothamSemibold,TextSize=11,LayoutOrder=order},page) end
	function Tab:Label(t,desc) local f=row(26) local l=rtitle(f,t) l.Size=UDim2.new(1,-14,1,0) l.TextColor3=COL.muted hookTip(f,desc) return {Set=function(_,v) l.Text=tostring(v) end} end
	function Tab:Button(o) o=o or{} local f=row(30) local l=rtitle(f,o.Name or "Button") l.Size=UDim2.new(1,-14,1,0) click(f,o.Callback) hookTip(f,o.Desc) end
	function Tab:Toggle(o) o=o or{} local state=G(o.Path)==true
		local f=row(28) rtitle(f,o.Name)
		local sw=inst("Frame",{Size=UDim2.fromOffset(34,16),Position=UDim2.new(1,-42,0.5,-8),BackgroundColor3=COL.bg,BorderSizePixel=0},f) corner(sw,8) stroke(sw)
		local ind=inst("Frame",{Size=UDim2.fromOffset(10,10),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=COL.off,BorderSizePixel=0},sw) corner(ind,5)
		local function paint(v) ind.BackgroundColor3=v and COL.accent or COL.off ind.Position=v and UDim2.new(1,-13,0.5,0) or UDim2.new(0,3,0.5,0) end
		uiref(o.Path,paint) paint(state)
		click(f,function() local nv=not G(o.Path) setPath(o.Path,nv) paint(nv) if o.OnChange then pcall(o.OnChange,nv) end queueSave() end)
		hookTip(f,o.Desc)
	end
	function Tab:Slider(o) o=o or{} local min,max=o.Min or 0,o.Max or 100 local step=o.Step or 1
		local val=math.clamp(tonumber(G(o.Path)) or o.Default or min,min,max)
		local f=row(42) rtitle(f,o.Name)
		local info=inst("TextLabel",{Size=UDim2.fromOffset(80,14),Position=UDim2.new(1,-90,0,4),BackgroundTransparency=1,TextColor3=COL.text,Font=Enum.Font.Gotham,TextSize=11,TextXAlignment=Enum.TextXAlignment.Right},f)
		local track=inst("Frame",{Size=UDim2.new(1,-20,0,4),Position=UDim2.fromOffset(10,30),BackgroundColor3=COL.off,BorderSizePixel=0},f) corner(track,2)
		local fill=inst("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=COL.accent,BorderSizePixel=0},track) corner(fill,2)
		local function paint(v) local r=(max>min) and ((v-min)/(max-min)) or 0 fill.Size=UDim2.new(math.clamp(r,0,1),0,1,0) info.Text=tostring(v)..(o.Suffix or "") end
		uiref(o.Path,paint) paint(val)
		local drag=false
		local function fromX(x) local w=math.max(track.AbsoluteSize.X,1) local r=math.clamp((x-track.AbsolutePosition.X)/w,0,1) local v=min+(max-min)*r v=math.floor(v/step+0.5)*step setPath(o.Path,v) paint(v) if o.OnChange then pcall(o.OnChange,v) end end
		App:Connect(track.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true fromX(i.Position.X) end end)
		App:Connect(UIS.InputChanged,function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then fromX(i.Position.X) end end)
		App:Connect(UIS.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false queueSave() end end)
		hookTip(f,o.Desc)
	end
	function Tab:Dropdown(o) o=o or{} local options=o.Options or {} local current=G(o.Path) or options[1]
		local f=row(30) rtitle(f,o.Name)
		local sel=inst("TextLabel",{Size=UDim2.new(0.34,-20,1,0),Position=UDim2.new(0.66,-14,0,0),BackgroundTransparency=1,Text=tostring(current),TextColor3=COL.muted,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Right},f)
		local list=inst("Frame",{Size=UDim2.new(1,-8,0,0),Position=UDim2.new(0,4,1,2),BackgroundColor3=COL.panel,BorderSizePixel=0,ClipsDescendants=true,Visible=false,ZIndex=30},f) corner(list,7) stroke(list)
		local ll=inst("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},list)
		local open=false
		for _,opt in ipairs(options) do
			local b=inst("TextButton",{Size=UDim2.new(1,0,0,24),BackgroundColor3=COL.elem,BorderSizePixel=0,Text="  "..opt,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=COL.text,Font=Enum.Font.Gotham,TextSize=12,AutoButtonColor=false,ZIndex=31},list) corner(b,5)
			App:Connect(b.MouseButton1Click,function() current=opt setPath(o.Path,opt) sel.Text=tostring(opt) if o.OnChange then pcall(o.OnChange,opt) end open=false list.Visible=false queueSave() end)
		end
		App:Connect(ll:GetPropertyChangedSignal("AbsoluteContentSize"),function() list.CanvasSize=UDim2.fromOffset(0,ll.AbsoluteContentSize.Y+6) end)
		click(f,function() open=not open list.Visible=open if open then list.Size=UDim2.new(1,-8,0,math.clamp(#options*27+8,28,190)) end end)
		hookTip(f,o.Desc)
	end
	function Tab:Keybind(o) o=o or{} local current=G(o.Path) or "None"
		local f=row(28) rtitle(f,o.Name)
		local kb=inst("TextButton",{Size=UDim2.fromOffset(76,20),Position=UDim2.new(1,-84,0.5,-10),BackgroundColor3=COL.panel,BorderSizePixel=0,Text=tostring(current),TextColor3=COL.text,Font=Enum.Font.Gotham,TextSize=11,AutoButtonColor=false},f) corner(kb,5) stroke(kb)
		local capturing=false
		App:Connect(UIS.InputBegan,function(input) if capturing then if input.KeyCode~=Enum.KeyCode.Unknown then setPath(o.Path,input.KeyCode.Name) kb.Text=input.KeyCode.Name capturing=false queueSave() end end end)
		App:Connect(kb.MouseButton1Click,function() capturing=true kb.Text="press" end)
		hookTip(f,o.Desc)
	end
	return Tab
end

-- Player cache
Cache={byPlayer={}}
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

-- AIM target
local HIT_PRIORITY={"Head","UpperTorso","HumanoidRootPart","Torso"}
local function getBestHitbox(char) if not char then return nil end for _,n in ipairs(HIT_PRIORITY) do local p=char:FindFirstChild(n) if p and p:IsA("BasePart") then return p end end return nil end
local function predictPosition(part)
	if not part or not part.Parent then return part and part.Position or nil end
	local pred=S.Aimbot.Prediction or 0
	if pred<=0 then return part.Position end
	local vel=part.AssemblyLinearVelocity
	if typeof(vel)~="Vector3" then vel=Vector3.zero end
	if vel.Magnitude>500 then vel=vel.Unit*500 end
	local lead=vel*pred
	if lead.Magnitude>35 then lead=lead.Unit*35 end
	return part.Position+lead
end
local cachedTarget=nil
local function getBestTarget()
	if not cam or not localRec() or not localRec().alive then return nil end
	local vp=cam.ViewportSize
	local center=Vector2.new(vp.X*0.5,vp.Y*0.5)
	local fov=S.Aimbot.FOV or 120
	local best,bd=nil,fov
	for plr,rec in pairs(Cache.byPlayer) do
		if plr~=LP and rec.alive and rec.char then
			if not S.Aimbot.OnlyEnemies or rec.enemy then
				local part=getBestHitbox(rec.char)
				if part then
					local pos=predictPosition(part)
					local sp,on=cam:WorldToViewportPoint(pos)
					if on and sp.Z>0 then
						local d=(Vector2.new(sp.X,sp.Y)-center).Magnitude
						if d<=fov then
							if not S.Aimbot.WallCheck or isVisible(pos,rec.char) then
								if d<bd then bd=d best={rec=rec,part=part,pos=pos} end
							end
						end
					end
				end
			end
		end
	end
	return best
end

-- SILENT hook (Raycast + FindPartOnRay* + Spherecast + Blockcast) с guards
local hookOn,origNC,gameMt=false,nil,nil
local silentTS={}
local lastSilentShot=0
local function rateLimitOk()
	local cap=tonumber(S.Aimbot.MaxSilentPerSec) or 0
	if cap<=0 then return true end
	local now=os.clock()
	while #silentTS>0 and (now-silentTS[1])>1 do table.remove(silentTS,1) end
	if #silentTS>=cap then return false end
	silentTS[#silentTS+1]=now return true
end
local function shotDelayOk()
	local d=tonumber(S.Aimbot.MinShotDelay) or 0
	if d<=0 then return true end
	local now=os.clock()
	if now-lastSilentShot<d then return false end
	lastSilentShot=now return true
end
local function isMouseDown()
	if not S.Aimbot.RequireMouseDown then return true end
	local ok,down=pcall(function() return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end)
	return ok and down or false
end
local function isPlayerOrigin(origin)
	if typeof(origin)~="Vector3" then return false end
	local lc=localRec() if not lc or not lc.root then return false end
	return (origin-lc.root.Position).Magnitude<60
end
local function hookBody(self,...)
	if internalRay or not S.Aimbot.Silent then return origNC(self,...) end
	if self~=WS then return origNC(self,...) end
	local m=getnamecallmethod()
	local isRay=(m=="Raycast")
	local isLegacy=(m=="FindPartOnRay" or m=="FindPartOnRayWithIgnoreList" or m=="FindPartOnRayWithWhitelist")
	local isSphere=(m=="Spherecast")
	local isBlock=(m=="Blockcast")
	if not isRay and not isLegacy and not isSphere and not isBlock then return origNC(self,...) end
	if not isMouseDown() then return origNC(self,...) end
	local origin,dir
	if isRay then origin,dir=select(1,...),select(2,...)
		if typeof(origin)~="Vector3" or typeof(dir)~="Vector3" then return origNC(self,...) end
	elseif isLegacy then local r=select(1,...) if typeof(r)~="Ray" then return origNC(self,...) end origin,dir=r.Origin,r.Direction
	elseif isSphere then origin,dir=select(1,...),select(3,...)
		if typeof(origin)~="Vector3" or typeof(dir)~="Vector3" then return origNC(self,...) end
	elseif isBlock then origin,dir=(select(1,...)).Position,select(3,...)
		if typeof(dir)~="Vector3" then return origNC(self,...) end
	end
	if not dir or dir.Magnitude<0.5 then return origNC(self,...) end
	if not isPlayerOrigin(origin) then return origNC(self,...) end
	local t=cachedTarget
	if not t or not t.rec.alive or not t.part or not t.part.Parent then return origNC(self,...) end
	local diff=t.pos-origin
	if diff.Magnitude<0.5 then return origNC(self,...) end
	if dir.Unit:Dot(diff.Unit)<(S.Aimbot.DirDotMin or 0) then return origNC(self,...) end
	if not rateLimitOk() then return origNC(self,...) end
	if not shotDelayOk() then return origNC(self,...) end
	local aimPos=t.pos
	if (S.Aimbot.HitChance or 100)<100 and math.random(1,100)>S.Aimbot.HitChance then
		local rnd=Vector3.new(math.random()-0.5,math.random()-0.5,math.random()-0.5)
		if rnd.Magnitude<0.001 then rnd=Vector3.new(1,0,0) end
		aimPos=aimPos+rnd.Unit*(S.Aimbot.Humanizer or 0.4)*8
	end
	local nd=(aimPos-origin).Unit*dir.Magnitude
	local args={...}
	if isRay then args[2]=nd
	elseif isLegacy then args[1]=Ray.new(origin,nd)
	elseif isSphere then args[3]=nd
	elseif isBlock then args[3]=nd end
	return origNC(self,table.unpack(args))
end
local function installHook()
	if hookOn or not CAP.hook then return end
	local ok,mt=pcall(getrawmetatable,game)
	if not ok or not mt then return end
	gameMt=mt origNC=mt.__namecall
	pcall(setreadonly,mt,false)
	mt.__namecall=newcclosure(hookBody)
	pcall(setreadonly,mt,true)
	hookOn=true
end
local function uninstallHook()
	if not hookOn or not gameMt or not origNC then return end
	pcall(setreadonly,gameMt,false) gameMt.__namecall=origNC pcall(setreadonly,gameMt,true)
	hookOn=false
end
installHook()

-- Aim step
local fovCircle=nil
if CAP.drawing then
	local ok,c=pcall(function() return Drawing.new("Circle") end)
	if ok and c then fovCircle=c c.Thickness=2 c.NumSides=64 c.Filled=false c.Color=Color3.fromRGB(0,255,100) c.Visible=false
		App:Add(function() pcall(function() c:Remove() end) end) end
end
App:BindRender("aim",Enum.RenderPriority.Camera.Value-1,function(dt)
	cam=WS.CurrentCamera
	if fovCircle then
		if (S.Aimbot.Enabled or S.Aimbot.Silent) and cam then
			local vp=cam.ViewportSize
			fovCircle.Position=Vector2.new(vp.X*0.5,vp.Y*0.5)
			fovCircle.Radius=S.Aimbot.FOV
			fovCircle.Color=S.Aimbot.Silent and Color3.fromRGB(255,80,80) or Color3.fromRGB(0,255,100)
			fovCircle.Visible=true
		else fovCircle.Visible=false end
	end
	if not localRec() then cachedTarget=nil return end
	if S.Aimbot.Enabled or S.Aimbot.Silent then
		cachedTarget=getBestTarget()
		if S.Aimbot.Enabled and cachedTarget and cam then
			local c=cam.CFrame
			local desired=CFrame.lookAt(c.Position,cachedTarget.pos)
			local sm=math.max(S.Aimbot.Smoothing or 5,0.01)
			local alpha=math.clamp(1-math.exp(-(dt or 1/60)*(60/sm)),0,1)
			cam.CFrame=c:Lerp(desired,alpha)
		end
	else cachedTarget=nil end
end)

-- TRIGGERBOT (wallcheck + cooldown + fallback)
local lastTrigger=0
App:Connect(RS.Heartbeat,function()
	if not S.Trigger.Enabled or not cam then return end
	local now=os.clock()
	if now-lastTrigger<(S.Trigger.Cooldown or 0.15) then return end
	local lc=localRec() if not lc or not lc.alive then return end
	local origin=cam.CFrame.Position
	local dir=cam.CFrame.LookVector*1000
	local ignore={cam} if lc.char then ignore[#ignore+1]=lc.char end
	rayParams.FilterDescendantsInstances=ignore
	internalRay=true
	local ok,hit=pcall(WS.Raycast,WS,origin,dir,rayParams)
	internalRay=false
	if not ok or not hit then return end
	local inst=hit.Instance
	while inst and not inst:IsA("Model") do inst=inst.Parent end
	if not inst then return end
	local owner=Players:GetPlayerFromCharacter(inst)
	if not owner or owner==LP then return end
	local rec=Cache.byPlayer[owner]
	if not rec or not rec.alive then return end
	if S.Trigger.OnlyEnemies and not rec.enemy then return end
	if S.Trigger.WallCheck and not hit.Instance:IsDescendantOf(rec.char) then return end
	lastTrigger=now
	if CAP.mouse1 then pcall(mouse1click) else
		local tool=lc.char and lc.char:FindFirstChildOfClass("Tool")
		if tool then pcall(function() tool:Activate() end) end
	end
end)

-- ESP (pooled)
local Pool={free={Square={},Line={},Text={}}}
local function acquire(k) if not CAP.drawing then return nil end local list=Pool.free[k] local o=table.remove(list) if not o then local ok,d=pcall(Drawing.new,k) if not ok then return nil end o=d end o.Visible=false return o end
local function release(o,k) if not o then return end pcall(function() o.Visible=false end) Pool.free[k][#Pool.free[k]+1]=o end
local function nukePool() for _,list in pairs(Pool.free) do for _,o in ipairs(list) do pcall(function() o:Remove() end) end table.clear(list) end end
local ESPS={}
local function releaseViz(rec) local v=ESPS[rec] if not v then return end
	if v.box then release(v.box,"Square") end if v.hpBg then release(v.hpBg,"Square") end if v.hpFill then release(v.hpFill,"Square") end
	if v.snap then release(v.snap,"Line") end if v.name then release(v.name,"Text") end if v.dist then release(v.dist,"Text") end
	if v.chams then pcall(function() v.chams:Destroy() end) end ESPS[rec]=nil end
App:Connect(Players.PlayerRemoving,function(plr) local rec=Cache.byPlayer[plr] if rec then releaseViz(rec) end end)
local espAcc=0
App:BindRender("esp",Enum.RenderPriority.Camera.Value+2,function(dt)
	espAcc=espAcc+dt if espAcc<1/30 then return end espAcc=0
	if not S.ESP.Enabled or not CAP.drawing or not cam then for _,rec in pairs(Cache.byPlayer) do releaseViz(rec) end return end
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
						local hSp=cam:WorldToViewportPoint(headPos)
						local lSp=cam:WorldToViewportPoint(legPos)
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

-- MOVEMENT
local MV={origWalk=nil,fly=nil}
local noclipParts={} local noclipConns={}
local function noclipAdd(part) if not part:IsA("BasePart") then return end if noclipParts[part]==nil then noclipParts[part]=part.CanCollide end part.CanCollide=false end
local function noclipRestore()
	for part,can in pairs(noclipParts) do if part and part.Parent then pcall(function() part.CanCollide=can end) end end
	table.clear(noclipParts)
	for _,c in ipairs(noclipConns) do if c.Connected then pcall(function() c:Disconnect() end) end end
	table.clear(noclipConns)
end
local function noclipEnable()
	local lc=localRec() if not lc or not lc.char then return end
	noclipRestore()
	for _,part in ipairs(lc.char:GetDescendants()) do noclipAdd(part) end
	noclipConns[#noclipConns+1]=lc.char.DescendantAdded:Connect(function(p) if S.Move.NoClip then noclipAdd(p) end end)
end
local function destroyFly() if MV.fly then pcall(function() MV.fly.lv:Destroy() end) pcall(function() MV.fly.ao:Destroy() end) pcall(function() MV.fly.att:Destroy() end) MV.fly=nil end
local function createFly(root)
	destroyFly()
	local att=Instance.new("Attachment") att.Parent=root
	local lv=Instance.new("LinearVelocity") lv.Attachment0=att lv.MaxForce=math.huge lv.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector lv.VectorVelocity=Vector3.zero lv.Parent=root
	local ao=Instance.new("AlignOrientation") ao.Attachment0=att ao.MaxTorque=math.huge ao.Responsiveness=200 ao.Mode=Enum.OrientationAlignmentMode.OneAttachment ao.Parent=root
	MV.fly={att=att,lv=lv,ao=ao}
end
App:Connect(LP.CharacterAdded,function(char)
	MV.origWalk=nil destroyFly() noclipRestore()
	if S.Move.NoClip then task.wait(0.1) noclipEnable() end
	char:WaitForChild("HumanoidRootPart",5)
end)
local lastJump=0
App:Connect(RS.Heartbeat,function(dt)
	local lc=localRec() if not lc or not lc.alive or not lc.hum or not lc.root then return end
	local hum,root=lc.hum,lc.root
	if S.Move.Speed then
		if MV.origWalk==nil then MV.origWalk=hum.WalkSpeed end
		if S.Move.SpeedMode=="Walk" then if hum.WalkSpeed~=S.Move.SpeedValue then hum.WalkSpeed=S.Move.SpeedValue end
		else local md=hum.MoveDirection if md.Magnitude>0.1 then local v=root.AssemblyLinearVelocity root.AssemblyLinearVelocity=Vector3.new(md.X*S.Move.SpeedValue,v.Y,md.Z*S.Move.SpeedValue) end end
	elseif MV.origWalk then if hum.WalkSpeed~=MV.origWalk then hum.WalkSpeed=MV.origWalk end MV.origWalk=nil end
	if S.Move.NoClip~=MV.ncOn then if S.Move.NoClip then noclipEnable() else noclipRestore() end MV.ncOn=S.Move.NoClip end
	if S.Move.InfJump and UIS:IsKeyDown(Enum.KeyCode.Space) and tick()-lastJump>0.22 then hum:ChangeState(Enum.HumanoidStateType.Jumping) lastJump=tick() end
	if S.Move.Bhop and UIS:IsKeyDown(Enum.KeyCode.Space) then local s=hum:GetState() if s==Enum.HumanoidStateType.Landed or s==Enum.HumanoidStateType.Running then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end
	if S.Move.Fly then
		if not MV.fly or not (MV.fly.lv and MV.fly.lv.Parent==root) then createFly(root) end
		local move=Vector3.zero
		if cam then local look,right=cam.CFrame.LookVector,cam.CFrame.RightVector
			if UIS:IsKeyDown(Enum.KeyCode.W) then move=move+look end if UIS:IsKeyDown(Enum.KeyCode.S) then move=move-look end
			if UIS:IsKeyDown(Enum.KeyCode.A) then move=move-right end if UIS:IsKeyDown(Enum.KeyCode.D) then move=move+right end end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then move=move+Vector3.new(0,1,0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move=move-Vector3.new(0,1,0) end
		MV.fly.lv.VectorVelocity=(move.Magnitude>0) and (move.Unit*S.Move.FlyValue) or Vector3.zero
		if cam then MV.fly.ao.CFrame=cam.CFrame end
	else destroyFly() end
end)

-- ANTI-AIM (minimal, honest)
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
	if S.AA.Jitter then jit=math.sin(tick()*12)*math.rad(S.AA.JitterAngle or 40) end
	local des=0
	if S.AA.Desync then if S.AA.DesyncMode=="Spin" then des=math.rad(tick()*30) else des=math.rad(60) end end
	if AA.rootJ and AA.origRoot then AA.rootJ.C0=AA.origRoot*CFrame.Angles(0,jit+des,0) end
	if S.AA.HideHead and AA.neck and AA.origNeck then AA.neck.C0=AA.origNeck*CFrame.Angles(0,math.rad(180),0)
	elseif AA.neck and AA.origNeck and AA.neck.C0~=AA.origNeck then AA.neck.C0=AA.origNeck end
end)

-- RAGE (master + controlled, honest)
local rageInstances={}
local function destroyRage() for _,i in ipairs(rageInstances) do pcall(function() i:Destroy() end) end table.clear(rageInstances) end
local lastRage=0
App:Connect(RS.Heartbeat,function(dt)
	if not S.Rage.Enabled then return end
	local now=tick()
	if now-lastRage<0.5 then return end
	lastRage=now
	local lc=localRec() if not lc or not lc.root or not lc.alive then return end
	if S.Rage.Spinbot then
		local rad=math.rad(S.Rage.SpinSpeed or 25)
		lc.root.CFrame=lc.root.CFrame*CFrame.Angles(0,rad,0)
	end
	if S.Rage.MassFling then
		for plr,rec in pairs(Cache.byPlayer) do
			if plr~=LP and rec.alive and rec.root and rec.enemy then
				if S.Rage.FlingTarget=="All" or (S.Rage.FlingTarget=="Nearest" and (lc.root.Position-rec.root.Position).Magnitude<20) then
					pcall(function()
						local bv=Instance.new("BodyVelocity") bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge)
						bv.Velocity=Vector3.new((math.random()-0.5)*500,300,(math.random()-0.5)*500) bv.Parent=rec.root
						rageInstances[#rageInstances+1]=bv
						task.delay(0.5,function() pcall(function() bv:Destroy() end) end)
					end)
				end
			end
		end
	end
	if S.Rage.VoidTP then
		for plr,rec in pairs(Cache.byPlayer) do
			if plr~=LP and rec.alive and rec.root and rec.enemy and (lc.root.Position-rec.root.Position).Magnitude<20 then
				pcall(function() rec.root.CFrame=CFrame.new(0,-500,0) end)
			end
		end
	end
	if S.Rage.LagMachine then
		if #rageInstances< (S.Rage.LagCount or 20) then
			pcall(function()
				local p=Instance.new("Part") p.Size=Vector3.new(1,1,1) p.Anchored=false p.CanCollide=false p.Transparency=1
				p.CFrame=lc.root.CFrame*CFrame.new((math.random()-0.5)*20,(math.random()-0.5)*20,(math.random()-0.5)*20)
				local av=Instance.new("AngularVelocity") av.AngularVelocity=Vector3.new((math.random()-0.5)*100,(math.random()-0.5)*100,(math.random()-0.5)*100) av.MaxTorque=math.huge
				local att=Instance.new("Attachment") att.Parent=p av.Attachment0=att av.Parent=p
				p.Parent=WS rageInstances[#rageInstances+1]=p
			end)
		end
	else
		-- clean lag parts when off
		for i=#rageInstances,1,-1 do local o=rageInstances[i] if o and o:IsA("Part") then pcall(function() o:Destroy() end) table.remove(rageInstances,i) end end
	end
end)

-- WATERMARK + KEYBIND DISPLAY
local wmText,kdText=nil,nil
if CAP.drawing then
	local ok1,t1=pcall(function() return Drawing.new("Text") end) if ok1 and t1 then wmText=t1 t1.Size=13 t1.Outline=true t1.Visible=false App:Add(function() pcall(function() t1:Remove() end) end) end
	local ok2,t2=pcall(function() return Drawing.new("Text") end) if ok2 and t2 then kdText=t2 t2.Size=13 t2.Outline=true t2.Visible=false App:Add(function() pcall(function() t2:Remove() end) end) end
end
local diagAcc=0
App:Connect(RS.Heartbeat,function(dt)
	diagAcc=diagAcc+dt if diagAcc<0.25 then return end diagAcc=0
	if wmText then wmText.Visible=S.Misc.Watermark if S.Misc.Watermark then wmText.Text="unknown v10 // stable" wmText.Position=Vector2.new(10,10) wmText.Color=Color3.fromRGB(235,235,240) end end
	if kdText then kdText.Visible=S.Misc.KeybindDisplay if S.Misc.KeybindDisplay and cam then local vp=cam.ViewportSize kdText.Position=Vector2.new(10,vp.Y*0.5-110) kdText.Text=string.format("[%s] Aim %s\n[%s] Silent %s\n[%s] Fly %s\n[%s] Speed %s",S.Keys.Aimbot,S.Aimbot.Enabled and "[ON]" or "[off]",S.Keys.Silent,S.Aimbot.Silent and "[ON]" or "[off]",S.Keys.Fly,S.Move.Fly and "[ON]" or "[off]",S.Keys.Speed,S.Move.Speed and "[ON]" or "[off]") kdText.Color=Color3.fromRGB(235,235,240) end end
end)

-- PANIC
local function Panic()
	pcall(function()
		S.Aimbot.Enabled=false S.Aimbot.Silent=false S.Trigger.Enabled=false
		S.ESP.Enabled=false S.ESP.Chams=false
		S.Move.Speed=false S.Move.Fly=false S.Move.NoClip=false S.Move.InfJump=false S.Move.Bhop=false
		S.AA.Jitter=false S.AA.Desync=false S.AA.HideHead=false
		S.Rage.Enabled=false S.Rage.MassFling=false S.Rage.VoidTP=false S.Rage.Spinbot=false S.Rage.LagMachine=false
	end)
	pcall(destroyFly) pcall(destroyRage) pcall(noclipRestore)
	MV.ncOn=false
	pcall(function() for _,rec in pairs(Cache.byPlayer) do releaseViz(rec) end end)
	for _,p in ipairs({"Aimbot.Enabled","Aimbot.Silent","Trigger.Enabled","ESP.Enabled","ESP.Chams","Move.Speed","Move.Fly","Move.NoClip","Move.InfJump","Move.Bhop","AA.Jitter","AA.Desync","AA.HideHead","Rage.Enabled","Rage.MassFling","Rage.VoidTP","Rage.Spinbot","Rage.LagMachine"}) do
		for _,fn in ipairs(UIREFS[p] or {}) do pcall(fn,false) end
	end
end

-- UI WIRING
local tCombat=addTab("combat")
tCombat:Section("aimbot")
tCombat:Toggle({Name="Aimbot",Path="Aimbot.Enabled",Desc="Плавно наводит камеру на цель в FOV."})
tCombat:Toggle({Name="Silent Aim",Path="Aimbot.Silent",Desc="Подменяет направление выстрела (Raycast/FindPartOnRay/Spherecast/Blockcast). Только client-raycast hitscan игры."})
tCombat:Toggle({Name="Require Mouse",Path="Aimbot.RequireMouseDown",Desc="Silent работает только при зажатой ЛКМ."})
tCombat:Toggle({Name="Wall Check",Path="Aimbot.WallCheck",Desc="Не целится сквозь стены."})
tCombat:Toggle({Name="Only Enemies",Path="Aimbot.OnlyEnemies",Desc="Игнорирует союзников."})
tCombat:Slider({Name="FOV",Path="Aimbot.FOV",Min=20,Max=600,Step=10,Desc="Радиус захвата цели."})
tCombat:Slider({Name="Smoothing",Path="Aimbot.Smoothing",Min=1,Max=20,Step=1,Desc="Сила сглаживания."})
tCombat:Slider({Name="Prediction",Path="Aimbot.Prediction",Min=0,Max=0.5,Step=0.01,Desc="Упреждение по скорости."})
tCombat:Slider({Name="Hit Chance",Path="Aimbot.HitChance",Min=0,Max=100,Step=5,Desc="Шанс попадания silent (humanizer)."})
tCombat:Section("triggerbot")
tCombat:Toggle({Name="TriggerBot",Path="Trigger.Enabled",Desc="Авто-выстрел когда прицел на враге."})
tCombat:Toggle({Name="Wall Check",Path="Trigger.WallCheck",Desc="Не стреляет сквозь стены."})
tCombat:Slider({Name="Cooldown",Path="Trigger.Cooldown",Min=0.05,Max=0.5,Step=0.05,Desc="Задержка между выстрелами."})

local tVis=addTab("visuals")
tVis:Section("esp")
tVis:Toggle({Name="ESP",Path="ESP.Enabled",Desc="Подсветка игроков."})
tVis:Toggle({Name="Boxes",Path="ESP.Boxes",Desc="Рамки."})
tVis:Toggle({Name="Health Bar",Path="ESP.HealthBar",Desc="Полоска HP."})
tVis:Toggle({Name="Snaplines",Path="ESP.Snaplines",Desc="Линии к целям."})
tVis:Toggle({Name="Names",Path="ESP.Names",Desc="Имена."})
tVis:Toggle({Name="Distance",Path="ESP.Distance",Desc="Дистанция."})
tVis:Toggle({Name="Chams",Path="ESP.Chams",Desc="Highlight сквозь стены. Может палиться продвинутыми AC."})
tVis:Toggle({Name="Only Enemies",Path="ESP.OnlyEnemies",Desc="Только враги."})
tVis:Slider({Name="Max Distance",Path="ESP.MaxDistance",Min=50,Max=2000,Step=50,Desc="Отсечка по дистанции."})

local tMove=addTab("move")
tMove:Section("speed")
tMove:Toggle({Name="Speed",Path="Move.Speed",Desc="Ускорение. Walk=WalkSpeed, Vel=velocity."})
tMove:Dropdown({Name="Mode",Path="Move.SpeedMode",Options={"Walk","Vel"},Desc="Режим скорости."})
tMove:Slider({Name="Speed",Path="Move.SpeedValue",Min=16,Max=200,Step=1,Desc="Значение скорости."})
tMove:Section("fly")
tMove:Toggle({Name="Fly",Path="Move.Fly",Desc="Полёт на LinearVelocity."})
tMove:Slider({Name="Fly Speed",Path="Move.FlyValue",Min=20,Max=200,Step=5,Desc="Скорость полёта."})
tMove:Section("other")
tMove:Toggle({Name="NoClip",Path="Move.NoClip",Desc="Проход сквозь стены (чистый restore)."})
tMove:Toggle({Name="Inf Jump",Path="Move.InfJump",Desc="Бесконечный прыжок."})
tMove:Toggle({Name="Bhop",Path="Move.Bhop",Desc="Авто-прыжок."})

local tAA=addTab("antiaim")
tAA:Section("angles")
tAA:Toggle({Name="Jitter",Path="AA.Jitter",Desc="Дёргает угол. Визуально для врагов."})
tAA:Slider({Name="Jitter Angle",Path="AA.JitterAngle",Min=10,Max=180,Step=5,Desc="Амплитуда."})
tAA:Toggle({Name="Desync",Path="AA.Desync",Desc="Рассинхрон угла. Не во всех играх."})
tAA:Dropdown({Name="Desync Mode",Path="AA.DesyncMode",Options={"Spin","Static"},Desc="Режим."})
tAA:Toggle({Name="Hide Head",Path="AA.HideHead",Desc="Прячет голову. Может ломать анимации."})

local tRage=addTab("rage")
tRage:Section("master")
tRage:Toggle({Name="Rage Master",Path="Rage.Enabled",Desc="Глобальный выключатель rage. Без него rage не работает."})
tRage:Label("Rage работает ТОЛЬКО в слабых/FE-играх.","Честно: в современных FE эти функции почти ничего не делают, но сильно палят.")
tRage:Section("functions")
tRage:Toggle({Name="Mass Fling",Path="Rage.MassFling",Desc="Раскрутить врагов BodyVelocity. Только при network ownership."})
tRage:Dropdown({Name="Fling Target",Path="Rage.FlingTarget",Options={"Nearest","All"},Desc="Цель флинга."})
tRage:Toggle({Name="Void TP",Path="Rage.VoidTP",Desc="Телепорт врага в void. Только client-authoritative."})
tRage:Toggle({Name="Spinbot",Path="Rage.Spinbot",Desc="Крутит персонажа."})
tRage:Toggle({Name="Lag Machine",Path="Rage.LagMachine",Desc="FE lag machine. Только слабые FE игры."})
tRage:Slider({Name="Lag Count",Path="Rage.LagCount",Min=5,Max=50,Step=5,Desc="Кол-во частей."})

local tMisc=addTab("misc")
tMisc:Section("safety")
tMisc:Keybind({Name="Panic Key",Path="Misc.PanicKey",Desc="Мгновенно выключает всё опасное."})
tMisc:Button({Name="PANIC NOW",Desc="Вызвать panic.",Callback=Panic})
tMisc:Toggle({Name="Anti-AFK",Path="Misc.AntiAFK",Desc="Не даёт кикнуть за AFK."})
tMisc:Section("display")
tMisc:Toggle({Name="Watermark",Path="Misc.Watermark",Desc="Надпись."})
tMisc:Toggle({Name="Keybind Display",Path="Misc.KeybindDisplay",Desc="Список биндов."})
tMisc:Keybind({Name="UI Key",Path="Keys.UI",Desc="Показать/скрыть UI."})
tMisc:Button({Name="Unload",Desc="Полная выгрузка.",Callback=function() if ENV.__ABYSS then ENV.__ABYSS.Unload() end end})

-- Global keys
App:Connect(UIS.InputBegan,function(input,processed)
	if processed then return end
	local kc=input.KeyCode.Name
	if kc==S.Misc.PanicKey then Panic() return end
	if kc==S.Keys.UI then main.Visible=not main.Visible return end
	if kc==S.Keys.Aimbot and S.Keys.Aimbot~="" then S.Aimbot.Enabled=not S.Aimbot.Enabled for _,fn in ipairs(UIREFS["Aimbot.Enabled"] or {}) do pcall(fn,S.Aimbot.Enabled) end end
	if kc==S.Keys.Silent and S.Keys.Silent~="" then S.Aimbot.Silent=not S.Aimbot.Silent for _,fn in ipairs(UIREFS["Aimbot.Silent"] or {}) do pcall(fn,S.Aimbot.Silent) end end
	if kc==S.Keys.Fly and S.Keys.Fly~="" then S.Move.Fly=not S.Move.Fly for _,fn in ipairs(UIREFS["Move.Fly"] or {}) do pcall(fn,S.Move.Fly) end end
	if kc==S.Keys.Speed and S.Keys.Speed~="" then S.Move.Speed=not S.Move.Speed for _,fn in ipairs(UIREFS["Move.Speed"] or {}) do pcall(fn,S.Move.Speed) end end
end)
App:Connect(hideBtn.MouseButton1Click,function() main.Visible=false end)
-- drag
do
	local dragging,dragStart,startPos=false,nil,nil
	App:Connect(topbar.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true dragStart=i.Position startPos=main.Position end end)
	App:Connect(UIS.InputChanged,function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-dragStart main.Position=UDim2.new(0.5,startPos.X.Offset+d.X,0.5,startPos.Y.Offset+d.Y) end end)
	App:Connect(UIS.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
end

-- SAFE INJECT: опасные OFF после конфига
for _,p in ipairs({"Aimbot.Enabled","Aimbot.Silent","Trigger.Enabled","ESP.Enabled","ESP.Chams","Move.Speed","Move.Fly","Move.NoClip","Move.InfJump","Move.Bhop","AA.Jitter","AA.Desync","AA.HideHead","Rage.Enabled","Rage.MassFling","Rage.VoidTP","Rage.Spinbot","Rage.LagMachine"}) do
	setPath(p,false)
	for _,fn in ipairs(UIREFS[p] or {}) do pcall(fn,false) end
end

-- UNLOAD
local function Unload()
	pcall(Panic)
	pcall(uninstallHook)
	for _,s in ipairs(scopes) do s:Destroy() end
	table.clear(scopes)
	pcall(nukePool)
	pcall(destroyRage)
	pcall(noclipRestore)
	pcall(destroyFly)
	local lc=localRec()
	if lc and lc.hum and MV.origWalk then pcall(function() lc.hum.WalkSpeed=MV.origWalk end) end
	ENV.__ABYSS=nil
end
ENV.__ABYSS={Unload=Unload}
print("[unknown v10] ready // safe inject // panic = "..S.Misc.PanicKey)
