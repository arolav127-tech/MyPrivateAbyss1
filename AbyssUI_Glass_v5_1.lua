local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local Lighting         = game:GetService("Lighting")
local Stats            = game:GetService("Stats")
local VirtualInput     = game:GetService("VirtualInputManager")

if not RunService:IsClient() then error("client only") end
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
while not LocalPlayer.Character do task.wait(0.1) end

local Camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() Camera = workspace.CurrentCamera end)

local RAND = math.random
local STEP_AIM  = "ui_" .. RAND(100000, 999999)
local STEP_ESP  = "ui_" .. RAND(100000, 999999)
local STEP_RAD  = "ui_" .. RAND(100000, 999999)
local GUI_TAG   = "AbyssCheat"
local startClock = os.clock()

----------------------------------------------------------------
-- Settings
----------------------------------------------------------------
local Settings = {
    Aimbot = { Enabled=false, Silent=false, Ballistic=false, BulletSpeed=1000, FOV=90, Smoothing=6, Prediction=0.11, WallCheck=true, ShowFOVCircle=true },
    ESP    = { Enabled=false, Boxes=true, HealthBar=true, Tracers=false, Names=false, Distance=false, Chams=false, OnlyEnemies=true, MaxDistance=900 },
    Radar  = { Enabled=false, Size=150, Range=250, Enemies=true, Team=false },
    Speed  = { Enabled=false, Mode="WalkSpeed", Value=50 },
    Fly    = { Enabled=false, Mode="LinearVelocity", AntiKick=true, Value=60 },
    Move   = { NoClip=false, InfJump=false },
    Combat = { KillAura=false, AuraRange=14, AutoClicker=false, CPS=12, Triggerbot=false, TriggerFOV=8 },
    Hitbox = { Enabled=false, Radius=4 },
    Misc   = { AntiAFK=true, Fullbright=false, LowGraphics=false, Watermark=true, PlayerList=false, InputLock=false, RemoteConfigURL="" },
    Keys   = { Aimbot="Q", ESP="X", Fly="V", Speed="C" },
}

local CONFIG_PATH = "AbyssUniversal/Config.json"
local function fsOk() return type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function" and type(makefolder)=="function" and type(isfolder)=="function" end
local function mergeConfig(dst, src) for k,v in pairs(src) do if type(v)=="table" and type(dst[k])=="table" then mergeConfig(dst[k],v) else dst[k]=v end end end
if fsOk() and isfile(CONFIG_PATH) then
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_PATH)) end)
    if ok and type(data)=="table" then mergeConfig(Settings, data) end
end
local saveQueued = false
local function queueSave()
    if saveQueued or not fsOk() then return end
    saveQueued = true
    task.delay(0.3, function()
        saveQueued = false
        pcall(function()
            if not isfolder("AbyssUniversal") then makefolder("AbyssUniversal") end
            writefile(CONFIG_PATH, HttpService:JSONEncode(Settings))
        end)
    end)
end

----------------------------------------------------------------
-- Утилиты
----------------------------------------------------------------
local function new(cls, props, parent) local i = Instance.new(cls) if props then for k,v in pairs(props) do i[k]=v end end if parent then i.Parent = parent end return i end
local function corner(p,r) return new("UICorner",{CornerRadius=UDim.new(0,r or 7)},p) end
local function stroke(p,c,t) return new("UIStroke",{Color=c or Color3.fromRGB(38,38,44),Thickness=t or 1},p) end
local function tween(o,t,pr) if not o or not o.Parent then return end TweenService:Create(o,TweenInfo.new(t or 0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),pr):Play() end

local connections = {}
local renderSteps = {}
local function connect(sig, fn) local c = sig:Connect(fn) connections[#connections+1] = c return c end
local function bindRender(name, prio, fn) renderSteps[#renderSteps+1] = name pcall(function() RunService:BindToRenderStep(name, prio, fn) end) end

local function getHumanoid(c) return c and c:FindFirstChildOfClass("Humanoid") end
local function isAlive(c) if not c or not c.Parent then return false end local h=getHumanoid(c) return h~=nil and h.Health>0 end
local function isEnemy(p) if p==LocalPlayer then return false end local m,t=LocalPlayer.Team,p.Team if not m or not t then return true end if LocalPlayer.Neutral or p.Neutral then return true end return t~=m end
local function getBestPart(c) if not c then return nil end for _,n in ipairs({"Head","UpperTorso","HumanoidRootPart","Torso"}) do local p=c:FindFirstChild(n) if p and p:IsA("BasePart") then return p end end return nil end
local function getRoot() local c=LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local internalRay = false
local function isVisible(pos, targetChar)
    if not Camera then return true end
    local ignore = { Camera }
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    rayParams.FilterDescendantsInstances = ignore
    local origin = Camera.CFrame.Position
    local dir = pos - origin
    if dir.Magnitude < 0.1 then return true end
    internalRay = true
    local ok, hit = pcall(workspace.Raycast, workspace, origin, dir, rayParams)
    internalRay = false
    if not ok then return true end
    if not hit then return true end
    if targetChar and hit.Instance:IsDescendantOf(targetChar) then return true end
    return false
end

----------------------------------------------------------------
-- Drawing pool
----------------------------------------------------------------
local drawingAvailable = type(Drawing)=="table" and type(Drawing.new)=="function"
local Pool = { Square={}, Line={}, Text={}, Circle={} }
local Free = setmetatable({}, {__mode="k"})
local function Acquire(cls) if not drawingAvailable then return nil end local pool=Pool[cls] for i=1,#pool do local o=pool[i] if Free[o] then Free[o]=false return o end end local ok,d=pcall(Drawing.new,cls) if not ok or not d then return nil end table.insert(pool,d) Free[d]=false return d end
local function Release(o) if not o then return end pcall(function() o.Visible=false end) Free[o]=true end
local function NukePool() for _,pool in pairs(Pool) do for i=1,#pool do pcall(function() pool[i]:Remove() end) end table.clear(pool) end end
local extraDrawings = {}

----------------------------------------------------------------
-- GUI root (stealth: случайное имя, cleanup по атрибуту)
----------------------------------------------------------------
local function pickGuiParent()
    if type(gethui)=="function" then local ok,t=pcall(gethui) if ok and t then return t end end
    local ok,pg=pcall(function() return LocalPlayer:WaitForChild("PlayerGui",3) end)
    if ok and pg then return pg end
    return game:GetService("CoreGui")
end
local guiParent = pickGuiParent()
for _, ch in ipairs(guiParent:GetChildren()) do
    if ch:GetAttribute(GUI_TAG) then pcall(function() ch:Destroy() end) end
end
local screenGui = new("ScreenGui", {
    Name = "ui" .. RAND(10000, 99999),
    ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
}, guiParent)
screenGui:SetAttribute(GUI_TAG, true)

local C = {
    bg=Color3.fromRGB(8,8,10), topbar=Color3.fromRGB(13,13,16), sidebar=Color3.fromRGB(11,11,14),
    element=Color3.fromRGB(19,19,23), hover=Color3.fromRGB(27,27,32), strokeC=Color3.fromRGB(38,38,44),
    text=Color3.fromRGB(238,238,242), muted=Color3.fromRGB(118,118,128),
    accent=Color3.fromRGB(255,62,62), accent2=Color3.fromRGB(255,122,122), off=Color3.fromRGB(58,58,66),
}

local main = new("Frame", { Name="Main", AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.fromOffset(560,470), BackgroundColor3=C.bg, BorderSizePixel=0, ClipsDescendants=true, Parent=screenGui })
corner(main,10); stroke(main,C.strokeC)
local topbar = new("Frame", { Size=UDim2.new(1,0,0,46), BackgroundColor3=C.topbar, BorderSizePixel=0, Parent=main })
corner(topbar,10)
new("Frame",{Size=UDim2.new(1,0,0,10),Position=UDim2.new(0,0,1,-10),BackgroundColor3=C.topbar,BorderSizePixel=0,Parent=topbar})
new("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.accent,BackgroundTransparency=0.25,BorderSizePixel=0,Parent=topbar})
new("Frame",{Size=UDim2.fromOffset(3,16),Position=UDim2.fromOffset(14,15),BackgroundColor3=C.accent,BorderSizePixel=0,Parent=topbar})
local titleLabel = new("TextLabel",{Size=UDim2.fromOffset(220,20),Position=UDim2.fromOffset(24,13),BackgroundTransparency=1,Text="unknown",Font=Enum.Font.Michroma,TextSize=15,TextColor3=Color3.fromRGB(248,248,250),TextXAlignment=Enum.TextXAlignment.Left,Parent=topbar})
new("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(130,130,140))},titleLabel)
new("TextLabel",{Size=UDim2.fromOffset(140,14),Position=UDim2.new(1,-150,0.5,-7),BackgroundTransparency=1,Text="private // 2027",Font=Enum.Font.Code,TextSize=10,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Right,Parent=topbar})

local function topBtn(txt,off) local b=new("TextButton",{Size=UDim2.fromOffset(26,26),Position=UDim2.new(1,off,0.5,-13),BackgroundColor3=C.element,BorderSizePixel=0,Text=txt,TextColor3=C.text,Font=Enum.Font.GothamBold,TextSize=12,AutoButtonColor=false,Parent=topbar}) corner(b,6) return b end
local closeBtn = topBtn("x",-34)
local minBtn   = topBtn("-",66-132)

local sidebar = new("Frame",{Size=UDim2.new(0,128,1,-54),Position=UDim2.fromOffset(8,52),BackgroundColor3=C.sidebar,BorderSizePixel=0,Parent=main}) corner(sidebar,8)
local tabList = new("ScrollingFrame",{Size=UDim2.new(1,-8,1,-8),Position=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,CanvasSize=UDim2.new(),Parent=sidebar})
local tabLayout = new("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},tabList)
connect(tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function() tabList.CanvasSize=UDim2.fromOffset(0,tabLayout.AbsoluteContentSize.Y+4) end)
local pages = new("Frame",{Size=UDim2.new(1,-142,1,-54),Position=UDim2.fromOffset(140,52),BackgroundTransparency=1,Parent=main})

-- input lock overlay (глотает клики вне GUI)
local inputLock = new("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=6,Parent=screenGui,Visible=false})

----------------------------------------------------------------
-- Cursor manager
----------------------------------------------------------------
local curIcon, curBehavior = nil, nil
local function setCursor(on)
    if on then
        if curIcon == nil then curIcon = UserInputService.MouseIconEnabled end
        if curBehavior == nil then curBehavior = UserInputService.MouseBehavior end
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    else
        if curIcon ~= nil then UserInputService.MouseIconEnabled = curIcon end
        if curBehavior ~= nil then UserInputService.MouseBehavior = curBehavior end
        curIcon, curBehavior = nil, nil
    end
end
local function syncWindowChrome()
    inputLock.Visible = (Settings.Misc.InputLock == true) and main.Visible
    setCursor(main.Visible)
end

----------------------------------------------------------------
-- GUI factory
----------------------------------------------------------------
local tabs, selected = {}, nil
local ui = {} -- ссылки на toggle-объекты для синхронизации биндов

local function selectTab(rec)
    selected = rec
    for _, r in ipairs(tabs) do
        local sel = (r==rec)
        r.page.Visible = sel
        r.btn.BackgroundColor3 = sel and C.hover or C.element
        r.btn.TextColor3 = sel and C.text or C.muted
        r.bar.Visible = sel
    end
end

local function createTab(name)
    local page = new("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.strokeC,Visible=false,CanvasSize=UDim2.new(),Parent=pages})
    local layout = new("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},page)
    new("UIPadding",{PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,8)},page)
    connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function() page.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+16) end)
    local btn = new("TextButton",{Size=UDim2.new(1,0,0,30),BackgroundColor3=C.element,BorderSizePixel=0,Text=name,TextColor3=C.muted,Font=Enum.Font.GothamMedium,TextSize=12,AutoButtonColor=false,Parent=tabList})
    corner(btn,6)
    local bar = new("Frame",{Size=UDim2.fromOffset(2,16),Position=UDim2.fromOffset(0,7),BackgroundColor3=C.accent,BorderSizePixel=0,Visible=false,Parent=btn})
    local rec = {name=name,page=page,btn=btn,bar=bar}
    table.insert(tabs,rec)
    connect(btn.MouseButton1Click, function() selectTab(rec) end)
    connect(btn.MouseEnter, function() if selected~=rec then btn.BackgroundColor3=C.hover end end)
    connect(btn.MouseLeave, function() if selected~=rec then btn.BackgroundColor3=C.element end end)
    if not selected then selectTab(rec) end

    local Tab = {}
    local order = 0
    local function nextOrder() order=order+1 return order end
    local function elemFrame(h) local f=new("Frame",{Size=UDim2.new(1,0,0,h),BackgroundColor3=C.element,BorderSizePixel=0,LayoutOrder=nextOrder(),Parent=page}) corner(f,7) stroke(f,C.strokeC) return f end
    local function elemTitle(p,t) return new("TextLabel",{Size=UDim2.new(0.62,-12,1,0),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Text=t,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=13,Parent=p}) end
    local function hoverize(f) connect(f.MouseEnter,function() f.BackgroundColor3=C.hover end) connect(f.MouseLeave,function() f.BackgroundColor3=C.element end) end
    local function addClick(f,cb) local o=new("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=5,Parent=f}) connect(o.MouseButton1Click,function() pcall(cb) end) return o end

    function Tab:CreateSection(t) new("TextLabel",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text="  "..tostring(t):upper(),TextXAlignment=Enum.TextXAlignment.Left,TextColor3=C.muted,Font=Enum.Font.GothamSemibold,TextSize=11,LayoutOrder=nextOrder(),Parent=page}) end
    function Tab:CreateLabel(t) local f=elemFrame(24) hoverize(f) local l=elemTitle(f,t) l.Size=UDim2.new(1,-14,1,0) l.TextColor3=C.muted l.TextSize=12 return {Set=function(_,v) l.Text=tostring(v) end} end
    function Tab:CreateButton(o) o=o or{} local f=elemFrame(30) hoverize(f) local l=elemTitle(f,o.Name or "Button") l.Size=UDim2.new(1,-14,1,0) addClick(f,function() if type(o.Callback)=="function" then o.Callback() end end) return {Set=function(_,v) l.Text=tostring(v) end} end

    function Tab:CreateToggle(o)
        o=o or{} local state=o.CurrentValue==true
        local f=elemFrame(30) hoverize(f) elemTitle(f,o.Name or "Toggle")
        local sw=new("Frame",{Size=UDim2.fromOffset(38,18),Position=UDim2.new(1,-48,0.5,-9),BackgroundColor3=C.bg,BorderSizePixel=0,Parent=f}) corner(sw,9) stroke(sw,C.strokeC)
        local ind=new("Frame",{Size=UDim2.fromOffset(12,12),AnchorPoint=Vector2.new(0,0.5),Position=state and UDim2.new(1,-15,0.5,0) or UDim2.new(0,3,0.5,0),BackgroundColor3=state and C.accent or C.off,BorderSizePixel=0,Parent=sw}) corner(ind,6)
        local obj={CurrentValue=state}
        local function apply(v,fire) state=(v==true) obj.CurrentValue=state
            if state then tween(ind,0.15,{Position=UDim2.new(1,-15,0.5,0),BackgroundColor3=C.accent}) else tween(ind,0.15,{Position=UDim2.new(0,3,0.5,0),BackgroundColor3=C.off}) end
            if fire and type(o.Callback)=="function" then pcall(o.Callback,state) end
        end
        addClick(f,function() apply(not state,true) queueSave() end)
        function obj:Set(v) apply(v,true) end
        apply(state,false)
        return obj
    end

    function Tab:CreateSlider(o)
        o=o or{} local min=o.Range and o.Range[1] or 0 local max=o.Range and o.Range[2] or 100
        if min>max then min,max=max,min end
        local inc=tonumber(o.Increment) or 1 if inc<=0 then inc=1 end
        local value=math.clamp(tonumber(o.CurrentValue) or min,min,max)
        local f=elemFrame(44) hoverize(f) elemTitle(f,o.Name or "Slider")
        local info=new("TextLabel",{Size=UDim2.fromOffset(90,14),Position=UDim2.new(1,-100,0,5),BackgroundTransparency=1,TextColor3=C.muted,Font=Enum.Font.Gotham,TextSize=11,TextXAlignment=Enum.TextXAlignment.Right,Parent=f})
        local track=new("Frame",{Size=UDim2.new(1,-20,0,6),Position=UDim2.fromOffset(10,30),BackgroundColor3=C.off,BorderSizePixel=0,Parent=f}) corner(track,3)
        local prog=new("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=C.accent,BorderSizePixel=0,Parent=track}) corner(prog,3)
        local obj={CurrentValue=value} local drag=false
        local function apply(v,fire) v=math.clamp(v,min,max) v=math.clamp(min+math.floor((v-min)/inc+0.5)*inc,min,max) value=v obj.CurrentValue=v
            local r=(max>min) and ((v-min)/(max-min)) or 0 prog.Size=UDim2.new(r,0,1,0)
            info.Text=tostring(v)..(o.Suffix and (" "..o.Suffix) or "")
            if fire and type(o.Callback)=="function" then pcall(o.Callback,v) end
        end
        local function fromX(x) local w=math.max(track.AbsoluteSize.X,1) local r=math.clamp((x-track.AbsolutePosition.X)/w,0,1) apply(min+(max-min)*r,true) end
        connect(track.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true fromX(i.Position.X) end end)
        connect(UserInputService.InputChanged,function(i) if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then fromX(i.Position.X) end end)
        connect(UserInputService.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then if drag then queueSave() end drag=false end end)
        function obj:Set(v) apply(v,true) end
        apply(value,false)
        return obj
    end

    function Tab:CreateDropdown(o)
        o=o or{} local options=o.Options or {} local current=o.CurrentOption or options[1]
        local f=elemFrame(32) hoverize(f) elemTitle(f,o.Name or "Dropdown")
        local sel=new("TextLabel",{Size=UDim2.new(0.34,-26,1,0),Position=UDim2.new(0.66,-16,0,0),BackgroundTransparency=1,Text=tostring(current or "None"),TextColor3=C.muted,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Right,Parent=f})
        local arrow=new("TextLabel",{Size=UDim2.fromOffset(16,32),Position=UDim2.new(1,-22,0,0),BackgroundTransparency=1,Text="v",TextColor3=C.muted,Font=Enum.Font.GothamBold,TextSize=12,Parent=f})
        local list=new("Frame",{BackgroundColor3=C.topbar,BorderSizePixel=0,ClipsDescendants=true,Visible=false,ZIndex=200,Parent=screenGui}) corner(list,7) stroke(list,C.strokeC)
        new("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},list)
        new("UIPadding",{PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,5),PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,5)},list)
        local obj={CurrentOption=current} local open=false
        local function paint() for _,b in ipairs(list:GetChildren()) do if b:IsA("TextButton") then local cur=(b:GetAttribute("opt")==tostring(current)) b.BackgroundColor3=cur and C.hover or C.element b.TextColor3=cur and C.accent2 or C.text end end end
        for _,opt in ipairs(options) do
            local b=new("TextButton",{Size=UDim2.new(1,0,0,24),BackgroundColor3=C.element,BorderSizePixel=0,Text="  "..tostring(opt),TextXAlignment=Enum.TextXAlignment.Left,TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=12,AutoButtonColor=false,ZIndex=202,Parent=list})
            b:SetAttribute("opt",tostring(opt)) corner(b,5)
            connect(b.MouseButton1Click,function() current=opt obj.CurrentOption=opt sel.Text=tostring(opt) if type(o.Callback)=="function" then pcall(o.Callback,opt) end paint() open=false arrow.Text="v" list.Visible=false queueSave() end)
        end
        local function setOpen(s) open=s arrow.Text=open and "^" or "v"
            if open then list.Size=UDim2.fromOffset(math.max(f.AbsoluteSize.X,160), math.clamp(#options*27+10,26,190)) local ap=f.AbsolutePosition local as=f.AbsoluteSize list.Position=UDim2.fromOffset(ap.X, ap.Y+as.Y+4) list.Visible=true paint()
            else list.Visible=false end
        end
        addClick(f,function() setOpen(not open) end)
        connect(UserInputService.InputBegan,function(i) if open and i.UserInputType==Enum.UserInputType.MouseButton1 then local p=i.Position local lp,ls=list.AbsolutePosition,list.AbsoluteSize local ap,as=f.AbsolutePosition,f.AbsoluteSize local inL=p.X>=lp.X and p.X<=lp.X+ls.X and p.Y>=lp.Y and p.Y<=lp.Y+ls.Y local inA=p.X>=ap.X and p.X<=ap.X+as.X and p.Y>=ap.Y and p.Y<=ap.Y+as.Y if not inL and not inA then setOpen(false) end end end)
        function obj:Set(v) current=v obj.CurrentOption=v sel.Text=tostring(v) if type(o.Callback)=="function" then pcall(o.Callback,v) end paint() end
        return obj
    end

    function Tab:CreateKeybind(o)
        o=o or{} local f=elemFrame(30) hoverize(f) elemTitle(f,o.Name or "Keybind")
        local b=new("TextButton",{Size=UDim2.fromOffset(76,20),Position=UDim2.new(1,-86,0.5,-10),BackgroundColor3=C.element,BorderSizePixel=0,Text=tostring(o.CurrentValue or "None"),TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=11,AutoButtonColor=false,Parent=f}) corner(b,5) stroke(b,C.strokeC)
        local capturing=false
        connect(b.MouseButton1Click,function() capturing=true b.Text="press" end)
        connect(UserInputService.InputBegan,function(input) if capturing then if input.KeyCode==Enum.KeyCode.Escape then capturing=false b.Text=tostring(o.CurrentValue or "None") return end if input.KeyCode~=Enum.KeyCode.Unknown then capturing=false local n=input.KeyCode.Name b.Text=n if type(o.Callback)=="function" then pcall(o.Callback,n) end queueSave() end end end)
        return {Set=function(_,v) b.Text=tostring(v) end}
    end

    return Tab
end

----------------------------------------------------------------
-- Баллистика: квадратное уравнение упреждения
----------------------------------------------------------------
local function predictBallistic(origin, pos, vel)
    local s = math.max(Settings.Aimbot.BulletSpeed or 1000, 50)
    local g = workspace.Gravity
    local p = pos - origin
    local a = vel:Dot(vel) - s*s
    local b = 2 * p:Dot(vel)
    local c = p:Dot(p)
    local t = nil
    if math.abs(a) < 1e-6 then
        if math.abs(b) > 1e-6 then t = -c / b end
    else
        local d = b*b - 4*a*c
        if d >= 0 then
            local sq = math.sqrt(d)
            local t1 = (-b - sq) / (2*a)
            local t2 = (-b + sq) / (2*a)
            if t1 > 0 and t2 > 0 then t = math.min(t1, t2) elseif t1 > 0 then t = t1 elseif t2 > 0 then t = t2 end
        end
    end
    if not t or t < 0 or t > 4 then return nil end
    return pos + vel * t + Vector3.new(0, -0.5 * g * t * t, 0)
end

----------------------------------------------------------------
-- Aimbot: scan + silent target
----------------------------------------------------------------
local silentTarget = nil
local fovCircle = nil
if drawingAvailable then
    local ok, c = pcall(function() return Drawing.new("Circle") end)
    if ok and c then fovCircle = c c.Thickness=2 c.NumSides=48 c.Filled=false c.Color=C.accent c.Visible=false table.insert(extraDrawings, c) end
end

local function scanBest(fovOverride)
    if not Camera or not LocalPlayer.Character then return nil end
    local S = Settings.Aimbot
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X*0.5, vp.Y*0.5)
    local fov = fovOverride or S.FOV
    local best, bestD = nil, fov
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and (not S.WallCheck or true) then
            if not (S.WallCheck and false) then end
        end
        if plr ~= LocalPlayer then
            local char = plr.Character
            if isAlive(char) then
                local part = getBestPart(char)
                if part then
                    local vel = part.AssemblyLinearVelocity
                    if vel.Magnitude > 500 then vel = vel.Unit * 500 end
                    local pos = part.Position
                    if S.Ballistic then
                        pos = predictBallistic(Camera.CFrame.Position, part.Position, vel) or pos
                    elseif S.Prediction > 0 then
                        local lead = vel * S.Prediction
                        if lead.Magnitude > 35 then lead = lead.Unit * 35 end
                        pos = pos + lead
                    end
                    local sp, on = Camera:WorldToViewportPoint(pos)
                    if on and sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= bestD then
                            if not S.WallCheck or isVisible(pos, char) then
                                bestD = d
                                best = { player=plr, char=char, part=part, pos=pos, vel=vel, dist=d }
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function updateAim(dt)
    Camera = workspace.CurrentCamera
    local S = Settings.Aimbot
    if fovCircle then
        if S.Enabled and S.ShowFOVCircle and Camera then
            local vp = Camera.ViewportSize
            fovCircle.Position = Vector2.new(vp.X*0.5, vp.Y*0.5)
            fovCircle.Radius = S.FOV
            fovCircle.Visible = true
        else fovCircle.Visible = false end
    end
    local t = (S.Enabled or S.Silent) and scanBest() or nil
    if t and S.Silent then
        local aim = S.Ballistic and (predictBallistic(Camera.CFrame.Position, t.part.Position, t.vel) or t.pos) or t.pos
        silentTarget = { pos = aim, char = t.char }
    else
        silentTarget = nil
    end
    if S.Enabled and t and Camera then
        local cam = Camera.CFrame
        local desired = CFrame.lookAt(cam.Position, t.pos)
        local sm = math.max(S.Smoothing, 0.5)
        local alpha = math.clamp(1 - math.exp(-(dt or 1/60) * (60 / sm)), 0, 1)
        Camera.CFrame = cam:Lerp(desired, alpha)
    end
end
bindRender(STEP_AIM, Enum.RenderPriority.Camera.Value + 1, updateAim)

----------------------------------------------------------------
-- Stealth hook: kick-block + silent aim + hitbox radius
----------------------------------------------------------------
local hookInstalled, origNamecall, gameMt = false, nil, nil
local function isLocalOrigin(origin)
    local root = getRoot()
    if root and (origin - root.Position).Magnitude < 20 then return true end
    if Camera and (origin - Camera.CFrame.Position).Magnitude < 6 then return true end
    return false
end
local function rayDistance(origin, dir, point)
    local len = dir.Magnitude if len < 0.001 then return math.huge end
    local u = dir / len
    local t = math.clamp((point - origin):Dot(u), 0, len)
    return (origin + u * t - point).Magnitude
end
local function findEnemyPartNearRay(origin, dir, radius)
    local bestPart, bestPos, bestD = nil, nil, radius
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isEnemy(plr) then
            local char = plr.Character
            if isAlive(char) then
                for _, pn in ipairs({"Head","UpperTorso","HumanoidRootPart"}) do
                    local part = char:FindFirstChild(pn)
                    if part and part:IsA("BasePart") then
                        local d = rayDistance(origin, dir, part.Position)
                        local allow = radius + part.Size.X * 0.5
                        if d <= allow and d < bestD then bestD=d bestPart=part bestPos=part.Position end
                    end
                end
            end
        end
    end
    return bestPart, bestPos
end
local function HookBody(self, ...)
    local method = getnamecallmethod()
    if (method=="Kick" or method=="kick") and self==LocalPlayer then
        if not (type(checkcaller)=="function" and checkcaller()) then return nil end
        return origNamecall(self, ...)
    end
    if not internalRay and self==workspace and (method=="Raycast" or method=="FindPartOnRay" or method=="FindPartOnRayWithIgnoreList") then
        local origin, direction
        if method=="Raycast" then
            origin, direction = select(1,...), select(2,...)
            if typeof(origin)~="Vector3" or typeof(direction)~="Vector3" then return origNamecall(self,...) end
        else
            local ray = select(1,...)
            if typeof(ray)~="Ray" then return origNamecall(self,...) end
            origin, direction = ray.Origin, ray.Direction
        end
        if direction.Magnitude > 0.5 and isLocalOrigin(origin) then
            local newDir = nil
            if Settings.Aimbot.Silent and silentTarget and silentTarget.char and silentTarget.char.Parent then
                local diff = silentTarget.pos - origin
                if diff.Magnitude > 0.5 then newDir = diff.Unit * direction.Magnitude end
            elseif Settings.Hitbox.Enabled then
                local part, pos = findEnemyPartNearRay(origin, direction, Settings.Hitbox.Radius)
                if part then
                    local diff = pos - origin
                    if diff.Magnitude > 0.01 then newDir = diff.Unit * direction.Magnitude end
                end
            end
            if newDir then
                if method=="Raycast" then
                    local args = {...} args[2] = newDir
                    return origNamecall(self, table.unpack(args))
                else
                    local args = {...} args[1] = Ray.new(origin, newDir)
                    return origNamecall(self, table.unpack(args))
                end
            end
        end
    end
    return origNamecall(self, ...)
end
local function installHook()
    if hookInstalled then return end
    if type(getrawmetatable)~="function" or type(setreadonly)~="function" or type(newcclosure)~="function" or type(getnamecallmethod)~="function" then return end
    local ok, mt = pcall(getrawmetatable, game)
    if not ok or not mt then return end
    gameMt = mt; origNamecall = mt.__namecall
    pcall(setreadonly, mt, false)
    mt.__namecall = newcclosure(HookBody)
    pcall(setreadonly, mt, true)
    hookInstalled = true
end
local function uninstallHook()
    if not hookInstalled or not gameMt or not origNamecall then return end
    pcall(setreadonly, gameMt, false) gameMt.__namecall = origNamecall pcall(setreadonly, gameMt, true)
    hookInstalled = false
end
installHook()

----------------------------------------------------------------
-- ESP (pool)
----------------------------------------------------------------
local espEntries = {}
local function releaseEntry(e)
    if e.box then Release(e.box) e.box=nil end
    if e.hpBg then Release(e.hpBg) e.hpBg=nil end
    if e.hpFill then Release(e.hpFill) e.hpFill=nil end
    if e.tracer then Release(e.tracer) e.tracer=nil end
    if e.name then Release(e.name) e.name=nil end
    if e.dist then Release(e.dist) e.dist=nil end
end
connect(Players.PlayerRemoving, function(plr) local e=espEntries[plr] if e then releaseEntry(e) if e.chams then pcall(function() e.chams:Destroy() end) end espEntries[plr]=nil end end)

local function updateESP()
    if not drawingAvailable or not Camera then return end
    local V = Settings.Visuals and Settings.ESP or Settings.ESP
    if not Settings.ESP.Enabled then
        for _, e in pairs(espEntries) do releaseEntry(e) if e.chams then e.chams.Enabled=false end end
        return
    end
    local camPos = Camera.CFrame.Position
    local viewport = Camera.ViewportSize
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local e = espEntries[plr] if not e then e={} espEntries[plr]=e end
        local char = plr.Character
        local hum = getHumanoid(char)
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        if not isAlive(char) or not root then releaseEntry(e) if e.chams then e.chams.Enabled=false end continue end
        if Settings.ESP.OnlyEnemies and not isEnemy(plr) then releaseEntry(e) if e.chams then e.chams.Enabled=false end continue end
        local dist = (root.Position - camPos).Magnitude
        if dist > Settings.ESP.MaxDistance then releaseEntry(e) if e.chams then e.chams.Enabled=false end continue end
        local color = isEnemy(plr) and Color3.fromRGB(255,62,62) or Color3.fromRGB(90,140,255)
        local headPos = (head and head.Position) or (root.Position + Vector3.new(0,2.5,0))
        local legPos = root.Position - Vector3.new(0,2.5,0)
        local headSp = Camera:WorldToViewportPoint(headPos)
        local legSp = Camera:WorldToViewportPoint(legPos)
        if headSp.Z < 0 and legSp.Z < 0 then releaseEntry(e) continue end
        local height = math.abs(legSp.Y - headSp.Y)
        local width = height * 0.5
        local x = headSp.X - width*0.5
        local y = headSp.Y
        if Settings.ESP.Boxes then
            e.box = e.box or Acquire("Square")
            if e.box then e.box.Filled=false e.box.Thickness=1 e.box.Size=Vector2.new(width,height) e.box.Position=Vector2.new(x,y) e.box.Color=color e.box.Visible=true end
        elseif e.box then Release(e.box) e.box=nil end
        if Settings.ESP.HealthBar and hum.MaxHealth > 0 then
            e.hpBg = e.hpBg or Acquire("Square")
            e.hpFill = e.hpFill or Acquire("Square")
            local pct = math.clamp(hum.Health/hum.MaxHealth,0,1)
            if e.hpBg then e.hpBg.Filled=true e.hpBg.Color=Color3.fromRGB(0,0,0) e.hpBg.Size=Vector2.new(3,height) e.hpBg.Position=Vector2.new(x-5,y) e.hpBg.Visible=true end
            if e.hpFill then local barH=height*pct e.hpFill.Filled=true e.hpFill.Size=Vector2.new(3,barH) e.hpFill.Position=Vector2.new(x-5,y+(height-barH)) e.hpFill.Color=Color3.fromRGB(60,220,60):Lerp(Color3.fromRGB(220,60,60),1-pct) e.hpFill.Visible=true end
        else
            if e.hpBg then Release(e.hpBg) e.hpBg=nil end
            if e.hpFill then Release(e.hpFill) e.hpFill=nil end
        end
        if Settings.ESP.Tracers then
            e.tracer = e.tracer or Acquire("Line")
            if e.tracer then e.tracer.Thickness=1 e.tracer.From=Vector2.new(viewport.X*0.5,viewport.Y) e.tracer.To=Vector2.new(headSp.X,headSp.Y) e.tracer.Color=color e.tracer.Visible=true end
        elseif e.tracer then Release(e.tracer) e.tracer=nil end
        if Settings.ESP.Names then
            e.name = e.name or Acquire("Text")
            if e.name then local nm=(plr.DisplayName~="" and plr.DisplayName) or plr.Name e.name.Text=nm e.name.Size=13 e.name.Center=true e.name.Outline=true e.name.Position=Vector2.new(headSp.X,y-16) e.name.Color=color e.name.Visible=true end
        elseif e.name then Release(e.name) e.name=nil end
        if Settings.ESP.Distance then
            e.dist = e.dist or Acquire("Text")
            if e.dist then e.dist.Text=tostring(math.floor(dist)).."m" e.dist.Size=12 e.dist.Center=true e.dist.Outline=true e.dist.Position=Vector2.new(headSp.X,y+height+4) e.dist.Color=Color3.fromRGB(255,255,255) e.dist.Visible=true end
        elseif e.dist then Release(e.dist) e.dist=nil end
        if Settings.ESP.Chams then
            if not e.chams or e.chams.Parent ~= char then
                if e.chams then pcall(function() e.chams:Destroy() end) end
                local h = Instance.new("Highlight")
                h.FillColor = color; h.OutlineColor = Color3.fromRGB(255,255,255); h.FillTransparency = 0.5
                pcall(function() h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
                h.Adornee = char; h.Parent = char
                e.chams = h
            else e.chams.FillColor = color; e.chams.Enabled = true end
        elseif e.chams then e.chams.Enabled = false end
    end
end
bindRender(STEP_ESP, Enum.RenderPriority.Camera.Value + 2, updateESP)

----------------------------------------------------------------
-- Radar (Drawing minimap)
----------------------------------------------------------------
local radar = { bg = nil, border = nil, dots = {} }
if drawingAvailable then
    radar.bg = Drawing.new("Square"); radar.bg.Filled = true; radar.bg.Color = Color3.fromRGB(0,0,0); radar.bg.Transparency = 0.45; radar.bg.Visible = false
    radar.border = Drawing.new("Square"); radar.border.Filled = false; radar.border.Color = C.accent; radar.border.Thickness = 1; radar.border.Visible = false
    table.insert(extraDrawings, radar.bg); table.insert(extraDrawings, radar.border)
end
local function radarDot()
    for i = 1, #radar.dots do
        local d = radar.dots[i]
        if not d.Visible then return d end
    end
    if not drawingAvailable then return nil end
    local ok, d = pcall(function() return Drawing.new("Square") end)
    if not ok or not d then return nil end
    d.Filled = true; d.Size = Vector2.new(5,5)
    table.insert(radar.dots, d); table.insert(extraDrawings, d)
    return d
end
local function updateRadar()
    local R = Settings.Radar
    if not drawingAvailable or not radar.bg then return end
    if not R.Enabled or not Camera then
        radar.bg.Visible = false; radar.border.Visible = false
        for _, d in ipairs(radar.dots) do d.Visible = false end
        return
    end
    local size = R.Size or 150
    local vp = Camera.ViewportSize
    local cx = vp.X - size - 14
    local cy = 70 + size * 0.5
    radar.bg.Size = Vector2.new(size, size)
    radar.bg.Position = Vector2.new(cx, cy - size*0.5)
    radar.bg.Visible = true
    radar.border.Size = Vector2.new(size, size)
    radar.border.Position = Vector2.new(cx, cy - size*0.5)
    radar.border.Visible = true
    local root = getRoot()
    local scale = (size * 0.5) / math.max(R.Range or 250, 10)
    local maxR = size * 0.5 - 5
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local enemy = isEnemy(plr)
        if enemy and not R.Enemies then continue end
        if not enemy and not R.Team then continue end
        local char = plr.Character
        local oroot = char and char:FindFirstChild("HumanoidRootPart")
        local dot = radarDot()
        if not dot then continue end
        if not root or not oroot or not isAlive(char) then dot.Visible = false continue end
        local rel = Camera.CFrame:PointToObjectSpace(oroot.Position - Camera.CFrame.Position)
        local fx, fy = rel.X, -rel.Z
        local px, py = fx * scale, -fy * scale
        local len = math.sqrt(px*px + py*py)
        if len > maxR then px, py = px/len*maxR, py/len*maxR end
        dot.Position = Vector2.new(cx + size*0.5 + px - 2.5, cy + py - 2.5)
        dot.Color = enemy and Color3.fromRGB(255,62,62) or Color3.fromRGB(90,140,255)
        dot.Visible = true
    end
end
bindRender(STEP_RAD, Enum.RenderPriority.Camera.Value + 3, updateRadar)

----------------------------------------------------------------
-- Watermark (fps / ping / uptime)
----------------------------------------------------------------
local wmText = nil
if drawingAvailable then
    local ok, t = pcall(function() return Drawing.new("Text") end)
    if ok and t then wmText = t t.Size = 13 t.Outline = true t.Center = false t.Color = C.accent2 t.Visible = false table.insert(extraDrawings, t) end
end
local fpsFrames, fpsLast, fpsValue = 0, os.clock(), 0
local wmLast = 0
local function updateWatermark(now)
    fpsFrames = fpsFrames + 1
    if now - fpsLast >= 0.5 then
        fpsValue = math.floor(fpsFrames / (now - fpsLast))
        fpsFrames = 0; fpsLast = now
    end
    if now - wmLast < 0.5 then return end
    wmLast = now
    if not wmText then return end
    if not Settings.Misc.Watermark then wmText.Visible = false return end
    local ping = 0
    pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
    local up = math.floor(os.clock() - startClock)
    local mm, ss = math.floor(up / 60), up % 60
    wmText.Text = string.format("unknown • %dfps • %dms • %02d:%02d • %d", fpsValue, ping, mm, ss, game.PlaceId)
    wmText.Position = Vector2.new(12, 12)
    wmText.Visible = true
end

----------------------------------------------------------------
-- Player list overlay (GUI)
----------------------------------------------------------------
local plFrame = new("Frame",{Name="PlayerList",Size=UDim2.fromOffset(250,330),Position=UDim2.new(1,-262,0.5,-165),BackgroundColor3=C.bg,BackgroundTransparency=0.15,BorderSizePixel=0,Visible=false,ZIndex=150,Parent=screenGui})
corner(plFrame,10) stroke(plFrame,C.strokeC)
new("TextLabel",{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1,Text="  players",TextColor3=C.text,Font=Enum.Font.GothamSemibold,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,Parent=plFrame})
local plHolder = new("Frame",{Size=UDim2.new(1,-10,1,-32),Position=UDim2.fromOffset(5,28),BackgroundTransparency=1,Parent=plFrame})
local plLayout = new("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},plHolder)
local plRows = {}
local function makeRow()
    local f = new("Frame",{Size=UDim2.new(1,0,0,20),BackgroundColor3=C.element,BorderSizePixel=0,Parent=plHolder})
    corner(f,5)
    local nm = new("TextLabel",{Size=UDim2.new(0.5,-8,1,0),Position=UDim2.fromOffset(6,0),BackgroundTransparency=1,TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
    local info = new("TextLabel",{Size=UDim2.new(0.5,0,1,0),Position=UDim2.new(0.5,0,0,0),BackgroundTransparency=1,TextColor3=C.muted,Font=Enum.Font.Gotham,TextSize=11,TextXAlignment=Enum.TextXAlignment.Right,Parent=f})
    return {f=f,nm=nm,info=info}
end
local plLast = 0
local function updatePlayerList(now)
    plFrame.Visible = Settings.Misc.PlayerList == true
    if not plFrame.Visible then return end
    if now - plLast < 0.5 then return end
    plLast = now
    local root = getRoot()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        local hum = getHumanoid(char)
        local oroot = char and char:FindFirstChild("HumanoidRootPart")
        local dist = (root and oroot) and math.floor((oroot.Position - root.Position).Magnitude) or -1
        local hp = (hum and hum.Health > 0) and math.floor(hum.Health) or 0
        local tool = char and char:FindFirstChildOfClass("Tool")
        list[#list+1] = { plr=plr, hp=hp, dist=dist, tool=tool and tool.Name or "-", enemy=isEnemy(plr), alive=isAlive(char) }
    end
    table.sort(list, function(a,b) return (a.dist < 0 and 999999 or a.dist) < (b.dist < 0 and 999999 or b.dist) end)
    for i = 1, 12 do
        local row = plRows[i] or makeRow(); plRows[i] = row
        local d = list[i]
        if d then
            row.f.Visible = true
            row.nm.Text = d.plr.Name
            row.nm.TextColor3 = d.enemy and Color3.fromRGB(255,120,120) or Color3.fromRGB(140,170,255)
            row.info.Text = string.format("%s | %dhp | %dm", d.tool, d.hp, d.dist < 0 and -1 or d.dist)
        else
            row.f.Visible = false
        end
    end
end

----------------------------------------------------------------
-- Movement + combat + misc loops
----------------------------------------------------------------
local fly = { att=nil, lv=nil, ao=nil, on=false }
local function destroyFly() if fly.lv then pcall(function() fly.lv:Destroy() end) end if fly.ao then pcall(function() fly.ao:Destroy() end) end if fly.att then pcall(function() fly.att:Destroy() end) end fly.lv,fly.ao,fly.att=nil,nil,nil fly.on=false end
local function createFly(root)
    destroyFly()
    fly.att = new("Attachment",{Parent=root})
    fly.lv = new("LinearVelocity",{Attachment0=fly.att,MaxForce=math.huge,VelocityConstraintMode=Enum.VelocityConstraintMode.Vector,VectorVelocity=Vector3.zero,Parent=root})
    fly.ao = new("AlignOrientation",{Attachment0=fly.att,MaxTorque=math.huge,Responsiveness=200,Mode=Enum.OrientationAlignmentMode.OneAttachment,Parent=root})
    fly.on = true
end
local originalWalk = nil
local lastJump = 0
local auraNext, clickAcc, trigNext = 0, 0, 0
local afkNext = 0
local AFK_KEYS = {"Space","Left","Right","Up","Down"}

local function doClick()
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
    if type(mouse1click)=="function" then pcall(mouse1click) end
end

local lightOrig = nil
local function applyFullbright(on)
    if on then
        if not lightOrig then lightOrig = { B=Lighting.Brightness, T=Lighting.ClockTime, F=Lighting.FogEnd, G=Lighting.GlobalShadows } end
        Lighting.Brightness=2 Lighting.ClockTime=14 Lighting.FogEnd=100000 Lighting.GlobalShadows=false
    elseif lightOrig then
        Lighting.Brightness=lightOrig.B Lighting.ClockTime=lightOrig.T Lighting.FogEnd=lightOrig.F Lighting.GlobalShadows=lightOrig.G lightOrig=nil
    end
end
local function applyLowGraphics(on)
    pcall(function()
        local Rendering = settings and settings():FindFirstChild("Rendering")
        if Rendering and type(sethiddenproperty)=="function" then
            sethiddenproperty(Rendering, "QualityLevel", on and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic)
        end
    end)
end

connect(RunService.Heartbeat, function(dt)
    local now = os.clock()
    updateWatermark(now)
    updatePlayerList(now)

    local char = LocalPlayer.Character
    local hum = getHumanoid(char)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or not root then if fly.on then destroyFly() end return end

    -- Speed
    if Settings.Speed.Enabled then
        if originalWalk == nil then originalWalk = hum.WalkSpeed end
        local v = Settings.Speed.Value
        local mode = Settings.Speed.Mode
        if mode=="WalkSpeed" or mode=="Loop" then
            if hum.WalkSpeed ~= v then hum.WalkSpeed = v end
        elseif mode=="Velocity" then
            local md = hum.MoveDirection
            if md.Magnitude > 0.1 then local cur=root.AssemblyLinearVelocity root.AssemblyLinearVelocity=Vector3.new(md.X*v,cur.Y,md.Z*v) end
        elseif mode=="CFrame" then
            local md = hum.MoveDirection
            if md.Magnitude > 0.1 then root.CFrame = root.CFrame + md * v * dt end
        end
    elseif originalWalk then
        if hum.WalkSpeed ~= originalWalk then hum.WalkSpeed = originalWalk end
        originalWalk = nil
    end

    -- NoClip / InfJump
    if Settings.Move.NoClip then
        for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide then part.CanCollide=false end end
    end
    if Settings.Move.InfJump and UserInputService:IsKeyDown(Enum.KeyCode.Space) and now - lastJump > 0.25 then
        hum:ChangeState(Enum.HumanoidStateType.Jumping) lastJump = now
    end

    -- Fly
    if Settings.Fly.Enabled then
        if Settings.Fly.AntiKick and not hookInstalled then installHook() end
        local move = Vector3.zero
        if Camera then
            local look, right = Camera.CFrame.LookVector, Camera.CFrame.RightVector
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - look end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + right end
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0,1,0) end
        local speed = Settings.Fly.Value
        if Settings.Fly.Mode == "LinearVelocity" then
            if not fly.on or not (fly.lv and fly.lv.Parent == root) then createFly(root) end
            if fly.on then
                fly.lv.VectorVelocity = (move.Magnitude > 0) and (move.Unit * speed) or Vector3.zero
                if fly.ao and Camera then fly.ao.CFrame = Camera.CFrame end
            end
        else
            if fly.on then destroyFly() end
            if move.Magnitude > 0 then root.CFrame = root.CFrame + move.Unit * speed * dt end
            root.AssemblyLinearVelocity = Vector3.new(0,0,0)
        end
    elseif fly.on then destroyFly() end

    -- Kill Aura
    if Settings.Combat.KillAura and now >= auraNext then
        local tool = char:FindFirstChildOfClass("Tool")
        local best, bestD = nil, Settings.Combat.AuraRange
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and isEnemy(plr) then
                local oc = plr.Character
                if isAlive(oc) then
                    local oroot = oc:FindFirstChild("HumanoidRootPart")
                    if oroot then
                        local d = (oroot.Position - root.Position).Magnitude
                        if d < bestD then bestD = d best = oroot end
                    end
                end
            end
        end
        if best and isVisible(best.Position, best.Parent) then
            local look = best.Position - root.Position look = Vector3.new(look.X,0,look.Z)
            if look.Magnitude > 0.1 then pcall(function() root.CFrame = CFrame.lookAt(root.Position, root.Position + look) end) end
            if tool then pcall(function() tool:Activate() end) end
            auraNext = now + 0.25 + math.random() * 0.35
        else auraNext = now + 0.1 end
    end

    -- Auto Clicker
    if Settings.Combat.AutoClicker then
        clickAcc = clickAcc + dt
        local interval = 1 / math.max(Settings.Combat.CPS, 1)
        while clickAcc >= interval do clickAcc = clickAcc - interval doClick() end
    else clickAcc = 0 end

    -- Triggerbot
    if Settings.Combat.Triggerbot and now >= trigNext then
        local t = scanBest(Settings.Combat.TriggerFOV)
        if t and isVisible(t.pos, t.char) then
            doClick()
            trigNext = now + 0.06 + math.random() * 0.06
        end
    end

    -- Anti-AFK
    if Settings.Misc.AntiAFK and now >= afkNext then
        local k = AFK_KEYS[math.random(1,#AFK_KEYS)]
        pcall(function()
            VirtualInput:SendKeyEvent(true, k, false, game)
            task.delay(0.15, function() pcall(function() VirtualInput:SendKeyEvent(false, k, false, game) end) end)
        end)
        afkNext = now + 60 + math.random() * 60
    end
end)

connect(LocalPlayer.CharacterAdded, function() destroyFly() originalWalk = nil silentTarget = nil end)

----------------------------------------------------------------
-- Tabs wiring
----------------------------------------------------------------
local TabCombat = createTab("combat")
TabCombat:CreateSection("aimbot")
ui.Aimbot = TabCombat:CreateToggle({Name="Aimbot",CurrentValue=Settings.Aimbot.Enabled,Callback=function(v) Settings.Aimbot.Enabled=v end})
TabCombat:CreateToggle({Name="Silent Aim",CurrentValue=Settings.Aimbot.Silent,Callback=function(v) Settings.Aimbot.Silent=v end})
TabCombat:CreateToggle({Name="Ballistic (gravity)",CurrentValue=Settings.Aimbot.Ballistic,Callback=function(v) Settings.Aimbot.Ballistic=v end})
TabCombat:CreateSlider({Name="Bullet Speed",Range={100,3000},Increment=50,CurrentValue=Settings.Aimbot.BulletSpeed,Callback=function(v) Settings.Aimbot.BulletSpeed=v end})
TabCombat:CreateToggle({Name="Show FOV Circle",CurrentValue=Settings.Aimbot.ShowFOVCircle,Callback=function(v) Settings.Aimbot.ShowFOVCircle=v end})
TabCombat:CreateToggle({Name="Wall Check",CurrentValue=Settings.Aimbot.WallCheck,Callback=function(v) Settings.Aimbot.WallCheck=v end})
TabCombat:CreateSlider({Name="FOV",Range={10,600},Increment=10,CurrentValue=Settings.Aimbot.FOV,Callback=function(v) Settings.Aimbot.FOV=v end})
TabCombat:CreateSlider({Name="Smoothing",Range={1,20},Increment=1,CurrentValue=Settings.Aimbot.Smoothing,Callback=function(v) Settings.Aimbot.Smoothing=v end})
TabCombat:CreateSection("hitbox (stealth)")
TabCombat:CreateToggle({Name="Hitbox (ray hook)",CurrentValue=Settings.Hitbox.Enabled,Callback=function(v) Settings.Hitbox.Enabled=v end})
TabCombat:CreateSlider({Name="Radius",Range={1,15},Increment=1,CurrentValue=Settings.Hitbox.Radius,Callback=function(v) Settings.Hitbox.Radius=v end})
TabCombat:CreateSection("pvp")
TabCombat:CreateToggle({Name="Kill Aura",CurrentValue=Settings.Combat.KillAura,Callback=function(v) Settings.Combat.KillAura=v end})
TabCombat:CreateSlider({Name="Aura Range",Range={5,30},Increment=1,CurrentValue=Settings.Combat.AuraRange,Callback=function(v) Settings.Combat.AuraRange=v end})
TabCombat:CreateToggle({Name="Triggerbot",CurrentValue=Settings.Combat.Triggerbot,Callback=function(v) Settings.Combat.Triggerbot=v end})
TabCombat:CreateSlider({Name="Trigger FOV",Range={2,20},Increment=1,CurrentValue=Settings.Combat.TriggerFOV,Callback=function(v) Settings.Combat.TriggerFOV=v end})
TabCombat:CreateToggle({Name="Auto Clicker",CurrentValue=Settings.Combat.AutoClicker,Callback=function(v) Settings.Combat.AutoClicker=v end})
TabCombat:CreateSlider({Name="CPS",Range={1,30},Increment=1,CurrentValue=Settings.Combat.CPS,Callback=function(v) Settings.Combat.CPS=v end})

local TabVisuals = createTab("visuals")
TabVisuals:CreateSection("esp")
ui.ESP = TabVisuals:CreateToggle({Name="Enable ESP",CurrentValue=Settings.ESP.Enabled,Callback=function(v) Settings.ESP.Enabled=v end})
TabVisuals:CreateToggle({Name="Boxes",CurrentValue=Settings.ESP.Boxes,Callback=function(v) Settings.ESP.Boxes=v end})
TabVisuals:CreateToggle({Name="Health Bar",CurrentValue=Settings.ESP.HealthBar,Callback=function(v) Settings.ESP.HealthBar=v end})
TabVisuals:CreateToggle({Name="Tracers",CurrentValue=Settings.ESP.Tracers,Callback=function(v) Settings.ESP.Tracers=v end})
TabVisuals:CreateToggle({Name="Names",CurrentValue=Settings.ESP.Names,Callback=function(v) Settings.ESP.Names=v end})
TabVisuals:CreateToggle({Name="Distance",CurrentValue=Settings.ESP.Distance,Callback=function(v) Settings.ESP.Distance=v end})
TabVisuals:CreateToggle({Name="Chams",CurrentValue=Settings.ESP.Chams,Callback=function(v) Settings.ESP.Chams=v end})
TabVisuals:CreateToggle({Name="Only Enemies",CurrentValue=Settings.ESP.OnlyEnemies,Callback=function(v) Settings.ESP.OnlyEnemies=v end})
TabVisuals:CreateSlider({Name="Max Distance",Range={50,2000},Increment=50,CurrentValue=Settings.ESP.MaxDistance,Callback=function(v) Settings.ESP.MaxDistance=v end})
TabVisuals:CreateSection("radar")
TabVisuals:CreateToggle({Name="Radar",CurrentValue=Settings.Radar.Enabled,Callback=function(v) Settings.Radar.Enabled=v end})
TabVisuals:CreateSlider({Name="Radar Range",Range={50,800},Increment=25,CurrentValue=Settings.Radar.Range,Callback=function(v) Settings.Radar.Range=v end})
TabVisuals:CreateToggle({Name="Radar: Enemies",CurrentValue=Settings.Radar.Enemies,Callback=function(v) Settings.Radar.Enemies=v end})
TabVisuals:CreateToggle({Name="Radar: Team",CurrentValue=Settings.Radar.Team,Callback=function(v) Settings.Radar.Team=v end})
TabVisuals:CreateSection("overlay")
TabVisuals:CreateToggle({Name="Watermark",CurrentValue=Settings.Misc.Watermark,Callback=function(v) Settings.Misc.Watermark=v end})
TabVisuals:CreateToggle({Name="Player List",CurrentValue=Settings.Misc.PlayerList,Callback=function(v) Settings.Misc.PlayerList=v end})

local TabMove = createTab("movement")
TabMove:CreateSection("speedhack")
ui.Speed = TabMove:CreateToggle({Name="Speed Hack",CurrentValue=Settings.Speed.Enabled,Callback=function(v) Settings.Speed.Enabled=v end})
TabMove:CreateDropdown({Name="Bypass Mode",Options={"WalkSpeed","Loop","Velocity","CFrame"},CurrentValue=Settings.Speed.Mode,Callback=function(v) Settings.Speed.Mode=v end})
TabMove:CreateSlider({Name="Walk Speed",Range={16,200},Increment=1,CurrentValue=Settings.Speed.Value,Callback=function(v) Settings.Speed.Value=v end})
TabMove:CreateSection("fly")
ui.Fly = TabMove:CreateToggle({Name="Fly",CurrentValue=Settings.Fly.Enabled,Callback=function(v) Settings.Fly.Enabled=v end})
TabMove:CreateDropdown({Name="Fly Mode",Options={"LinearVelocity","CFrame"},CurrentValue=Settings.Fly.Mode,Callback=function(v) Settings.Fly.Mode=v end})
TabMove:CreateToggle({Name="Anti-Kick",CurrentValue=Settings.Fly.AntiKick,Callback=function(v) Settings.Fly.AntiKick=v if v then installHook() end end})
TabMove:CreateSlider({Name="Fly Speed",Range={20,200},Increment=5,CurrentValue=Settings.Fly.Value,Callback=function(v) Settings.Fly.Value=v end})
TabMove:CreateSection("other")
TabMove:CreateToggle({Name="NoClip",CurrentValue=Settings.Move.NoClip,Callback=function(v) Settings.Move.NoClip=v end})
TabMove:CreateToggle({Name="Infinite Jump",CurrentValue=Settings.Move.InfJump,Callback=function(v) Settings.Move.InfJump=v end})

local TabMisc = createTab("misc")
TabMisc:CreateSection("hotkeys")
TabMisc:CreateKeybind({Name="Aimbot Key",CurrentValue=Settings.Keys.Aimbot,Callback=function(n) Settings.Keys.Aimbot=n end})
TabMisc:CreateKeybind({Name="ESP Key",CurrentValue=Settings.Keys.ESP,Callback=function(n) Settings.Keys.ESP=n end})
TabMisc:CreateKeybind({Name="Fly Key",CurrentValue=Settings.Keys.Fly,Callback=function(n) Settings.Keys.Fly=n end})
TabMisc:CreateKeybind({Name="Speed Key",CurrentValue=Settings.Keys.Speed,Callback=function(n) Settings.Keys.Speed=n end})
TabMisc:CreateSection("interface")
TabMisc:CreateToggle({Name="Input Lock (GUI open)",CurrentValue=Settings.Misc.InputLock,Callback=function(v) Settings.Misc.InputLock=v syncWindowChrome() end})
TabMisc:CreateToggle({Name="Anti-AFK",CurrentValue=Settings.Misc.AntiAFK,Callback=function(v) Settings.Misc.AntiAFK=v end})
TabMisc:CreateToggle({Name="Fullbright",CurrentValue=Settings.Misc.Fullbright,Callback=function(v) Settings.Misc.Fullbright=v applyFullbright(v) end})
TabMisc:CreateToggle({Name="Low Graphics",CurrentValue=Settings.Misc.LowGraphics,Callback=function(v) Settings.Misc.LowGraphics=v applyLowGraphics(v) end})
TabMisc:CreateSection("recon")
local scanLabel = TabMisc:CreateLabel("remotes: -")
TabMisc:CreateButton({Name="Scan Remotes (getgc)",Callback=function()
    if type(getgc)~="function" then scanLabel:Set("remotes: getgc unavailable") return end
    local names, count = {}, 0
    for _, obj in ipairs(getgc(false)) do
        count = count + 1
        if count > 20000 then break end
        if typeof(obj)=="Instance" and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
            names[#names+1] = obj.Name
            if #names >= 10 then break end
        end
    end
    scanLabel:Set("remotes: " .. (#names > 0 and table.concat(names, ", ") or "none"))
end})
local cfgUrl = TabMisc:CreateLabel("remote config: -")
TabMisc:CreateButton({Name="Pull Remote Config",Callback=function()
    local url = Settings.Misc.RemoteConfigURL
    if url == "" then cfgUrl:Set("remote config: url empty") return end
    local req = syn and syn.request or http_request or request
    local body = nil
    if type(req)=="function" then
        local ok, res = pcall(req, {Url=url, Method="GET"})
        if ok and type(res)=="table" and type(res.Body)=="string" then body = res.Body end
    end
    if not body then local ok, r = pcall(function() return game:HttpGet(url, true) end) if ok and type(r)=="string" then body = r end end
    if body then
        local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
        if ok and type(data)=="table" then mergeConfig(Settings, data) cfgUrl:Set("remote config: merged") queueSave() return end
    end
    cfgUrl:Set("remote config: failed")
end})
TabMisc:CreateButton({Name="Hide GUI",Callback=function() main.Visible=false syncWindowChrome() end})

-- самоуничтожение (в конце списка)
local selfDestructArmed = false
local destroyBtn = TabMisc:CreateButton({Name="ПОЛНОЕ САМОУНИЧТОЖЕНИЕ",Callback=function()
    if selfDestructArmed then return end
    selfDestructArmed = true
    task.spawn(function()
        for i = 5, 1, -1 do
            destroyBtn.Set(nil, "САМОУНИЧТОЖЕНИЕ: " .. i)
            task.wait(1)
        end
        FullUnload()
    end)
end})

----------------------------------------------------------------
-- Window controls + binds
----------------------------------------------------------------
local dragging, dragStart, startPos = false, nil, nil
connect(topbar.InputBegan, function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        if input.Target:IsA("TextButton") then return end
        dragging=true dragStart=input.Position startPos=main.Position
    end
end)
connect(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(0.5, startPos.X.Offset + d.X, 0.5, startPos.Y.Offset + d.Y)
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)

local minimized = false
connect(minBtn.MouseButton1Click, function()
    minimized = not minimized
    if minimized then
        sidebar.Visible=false pages.Visible=false
        tween(main,0.2,{Size=UDim2.fromOffset(main.Size.X.Offset,46)})
    else
        sidebar.Visible=true pages.Visible=true
        tween(main,0.2,{Size=UDim2.fromOffset(main.Size.X.Offset,470)})
    end
end)
connect(closeBtn.MouseButton1Click, function() main.Visible=false syncWindowChrome() end)

-- глобальные бинды: RightShift + фиче-клавиши
connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
        syncWindowChrome()
        return
    end
    local k = input.KeyCode.Name
    local K = Settings.Keys
    local function flip(setting, path, obj)
        Settings[path] = not Settings[path]
        if obj then obj:Set(Settings[path]) end
        queueSave()
    end
    if k == K.Aimbot then flip(nil,"Aimbot",ui.Aimbot)
    elseif k == K.ESP then flip(nil,"ESP",ui.ESP) and nil
    elseif k == K.Fly then flip(nil,"Fly",ui.Fly)
    elseif k == K.Speed then flip(nil,"Speed",ui.Speed) end
end)

-- фикс: ESP хранится в Settings.ESP, flip выше использует плоские ключи только для Aimbot/Fly/Speed
-- (ESP обрабатывается отдельно)
connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode.Name == Settings.Keys.ESP then
        Settings.ESP.Enabled = not Settings.ESP.Enabled
        if ui.ESP then ui.ESP:Set(Settings.ESP.Enabled) end
        queueSave()
    end
end)

syncWindowChrome()
applyFullbright(Settings.Misc.Fullbright)
applyLowGraphics(Settings.Misc.LowGraphics)
queueSave()

----------------------------------------------------------------
-- Full unload
----------------------------------------------------------------
function FullUnload()
    pcall(function() RunService:UnbindFromRenderStep(STEP_AIM) end)
    pcall(function() RunService:UnbindFromRenderStep(STEP_ESP) end)
    pcall(function() RunService:UnbindFromRenderStep(STEP_RAD) end)
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    pcall(uninstallHook)
    pcall(destroyFly)
    pcall(function() applyFullbright(false) end)
    local char = LocalPlayer.Character
    if char then pcall(function() for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end end) end
    local hum = getHumanoid(char)
    if hum and originalWalk then pcall(function() hum.WalkSpeed = originalWalk end) end
    for _, e in pairs(espEntries) do releaseEntry(e) if e.chams then pcall(function() e.chams:Destroy() end) end end
    for _, d in ipairs(extraDrawings) do pcall(function() d:Remove() end) end
    NukePool()
    setCursor(false)
    if screenGui then pcall(function() screenGui:Destroy() end) end
end

print("[unknown] v2 loaded — silent+ballistic, radar, triggerbot, playerlist, watermark, binds")
