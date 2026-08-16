-- abyss // unknown v8 (single-file complete build)
-- жёсткий, стабильный, без декоративных функций

local RS   = game:GetService("RunService")
local Players = game:GetService("Players")
local UIS  = game:GetService("UserInputService")
local HS   = game:GetService("HttpService")
local WS   = game:GetService("Workspace")
local TWS  = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RS:IsClient() then return end
local LP = Players.LocalPlayer or Players.PlayerAdded:Wait()

----------------------------------------------------------------
-- CAPS + ENV
----------------------------------------------------------------
local CAP = {
    drawing = type(Drawing)=="table" and type(Drawing.new)=="function",
    fs      = type(writefile)=="function" and type(readfile)=="function"
              and type(isfile)=="function" and type(makefolder)=="function"
              and type(isfolder)=="function",
    hook    = type(getrawmetatable)=="function" and type(setreadonly)=="function"
              and type(newcclosure)=="function" and type(getnamecallmethod)=="function",
    gethui  = type(gethui)=="function",
    mouse1  = type(mouse1click)=="function",
}

local ENV = (type(getgenv)=="function" and getgenv()) or _G
if type(ENV.__ABYSS)=="table" and type(ENV.__ABYSS.Unload)=="function" then
    pcall(ENV.__ABYSS.Unload)
end
ENV.__ABYSS = nil

----------------------------------------------------------------
-- SCOPE SYSTEM (Maid-style cleanup)
----------------------------------------------------------------
local scopes = {}
local function newScope(name)
    local s = { name=name, alive=true, conns={}, insts={}, fns={}, renders={} }
    function s:Connect(sig, fn)
        if not self.alive then return nil end
        local c = sig:Connect(fn); self.conns[#self.conns+1] = c; return c
    end
    function s:Give(i)
        if not self.alive then pcall(function() i:Destroy() end); return i end
        self.insts[#self.insts+1] = i; return i
    end
    function s:Add(fn)
        if not self.alive then pcall(fn); return end
        self.fns[#self.fns+1] = fn
    end
    function s:BindRender(key, prio, fn)
        if not self.alive then return end
        local nm = "ABYSS_"..key
        self.renders[#self.renders+1] = nm
        RS:BindToRenderStep(nm, prio, function(dt)
            if self.alive then pcall(fn, dt) end
        end)
    end
    function s:Destroy()
        if not self.alive then return end
        self.alive = false
        for _, c in ipairs(self.conns) do pcall(function() c:Disconnect() end) end
        for _, nm in ipairs(self.renders) do pcall(function() RS:UnbindFromRenderStep(nm) end) end
        for i = #self.fns, 1, -1 do pcall(self.fns[i]) end
        for _, i in ipairs(self.insts) do pcall(function() i:Destroy() end) end
    end
    scopes[#scopes+1] = s
    return s
end
local App = newScope("app")

----------------------------------------------------------------
-- SETTINGS (defensive defaults, SAFE INJECT = все OFF)
----------------------------------------------------------------
local S = {
    Aimbot = {
        Enabled=false, Silent=false, TargetLock=false,
        FOV=150, Smoothing=0.12, Sensitivity=1.0,
        Prediction=0.12, PredictGravity=false,
        WallCheck=true, OnlyEnemies=true,
        Bone="Head", -- Head / Torso / Nearest
        HitChance=100, HumanizerStrength=0.4,
        Hysteresis=true, HysteresisMult=1.3,
        Backtrack=false, BacktrackTime=0.2,
    },
    Trigger = {
        Enabled=false, OnlyEnemies=true, WallCheck=true,
        Delay=0.07, Cooldown=0.15,
    },
    ESP = {
        Enabled=false, Boxes=true, HealthBar=true, Snaplines=false,
        Names=true, Distance=true, Chams=false, OnlyEnemies=true,
        MaxDistance=500, ShowFOVCircle=true, ShowTargetIndicator=true,
    },
    Move = {
        Speed=false, SpeedMode="Walk", SpeedValue=16, VelCap=200,
        Fly=false, FlyValue=60,
        NoClip=false, InfJump=false, InfJumpCooldown=0.22, InfJumpBoost=0,
        Bhop=false,
    },
    AA = {
        Jitter=false, JitterMode="Sine", JitterAngle=40, JitterSpeed=12,
        Desync=false, DesyncMode="Spin", DesyncSpeed=30, DesyncStrength=1.0,
        HideHead=false, HideHeadMode="Back",
        FakeLag=false, FakeLagMode="Static", FakeLagIntensity=5, FakeLagFrequency=1,
    },
    Rage = {
        -- ВСЁ OFF по умолчанию. Работает только в FE-weak играх.
        MassFling=false, FlingTarget="Nearest", -- Nearest / All
        VoidTP=false, VoidTPInterval=0.5,
        RemoteSpam=false, RemoteSpamInterval=0.1,
        LagMachine=false, LagMachineCount=20,
        Unanchor=false,
    },
    Misc = {
        Watermark=true, KeybindDisplay=true, AntiAFK=true,
        PanicKey="End",
    },
    Keys = {
        UI="RightShift", Aimbot="X", Silent="B", Trigger="C",
        Fly="F", Speed="V", AA="Z", Lock="Q", ESP="E",
        Panic="End",
    },
}

local WATCH, UIREFS = {}, {}
local function watch(p, fn) WATCH[p]=WATCH[p] or {}; WATCH[p][#WATCH[p]+1]=fn end
local function uiref(p, fn) UIREFS[p]=UIREFS[p] or {}; UIREFS[p][#UIREFS[p]+1]=fn end

local function G(path)
    local g, k = path:match("^(%w+)%.(%w+)$")
    return S[g] and S[g][k]
end

local saveQueued = false
local CFGPATH = "AbyssFW/unknown_v8.json"

local function saveConfig()
    if not CAP.fs then return false end
    local ok, enc = pcall(function() return HS:JSONEncode(S) end)
    if not ok then return false end
    local wrote = false
    pcall(function()
        if not isfolder("AbyssFW") then makefolder("AbyssFW") end
        writefile(CFGPATH, enc)
        local ok2, back = pcall(readfile, CFGPATH)
        if ok2 and back == enc then wrote = true end
    end)
    return wrote
end

local function queueSave()
    if saveQueued then return end
    saveQueued = true
    task.delay(0.6, function() saveQueued = false if App.alive then saveConfig() end end)
end

local function P(path, value, skipSave)
    local g, k = path:match("^(%w+)%.(%w+)$")
    if not S[g] or S[g][k] == nil then return false end
    local expected = type(S[g][k])
    local got = type(value)
    if expected ~= got then
        if expected == "number" and got == "string" then
            local n = tonumber(value)
            if n then value = n else return false end
        else
            return false
        end
    end
    S[g][k] = value
    for _, fn in ipairs(WATCH[path] or {}) do pcall(fn, value) end
    for _, fn in ipairs(UIREFS[path] or {}) do pcall(fn, value) end
    if not skipSave then queueSave() end
    return true
end

local function loadConfig()
    if not CAP.fs or not isfile(CFGPATH) then return false end
    local ok, txt = pcall(readfile, CFGPATH)
    if not ok or type(txt)~="string" then return false end
    local ok2, data = pcall(function() return HS:JSONDecode(txt) end)
    if not ok2 or type(data)~="table" then return false end
    -- STRICT: только известные ключи, только правильные типы
    for g, keys in pairs(S) do
        if type(data[g]) == "table" then
            for k in pairs(keys) do
                if data[g][k] ~= nil then
                    local expected = type(keys[k])
                    local got = type(data[g][k])
                    if expected == got then
                        S[g][k] = data[g][k]
                    elseif expected == "number" and got == "string" then
                        local n = tonumber(data[g][k])
                        if n then S[g][k] = n end
                    end
                end
            end
        end
    end
    return true
end

----------------------------------------------------------------
-- PLAYER CACHE (event-driven, generation-safe)
----------------------------------------------------------------
local Cache = { byPlayer = {} }
local charL, leaveL = {}, {}
local function onChar(fn) charL[#charL+1] = fn end
local function onLeave(fn) leaveL[#leaveL+1] = fn end

local cam = WS.CurrentCamera
App:Connect(WS:GetPropertyChangedSignal("CurrentCamera"), function() cam = WS.CurrentCamera end)
local function localRec() return Cache.byPlayer[LP] end

local function recomputeEnemy(rec)
    if rec.plr == LP then rec.enemy = false; return end
    local m, t = LP.Team, rec.plr.Team
    if not m or not t then rec.enemy = true; return end
    if LP.Neutral or rec.plr.Neutral then rec.enemy = true; return end
    rec.enemy = (t ~= m)
end
local function recomputeAll()
    for _, r in pairs(Cache.byPlayer) do recomputeEnemy(r) end
end

local function onCharAdded(rec, char)
    if rec.cscope then rec.cscope:Destroy() end
    rec.gen = (rec.gen or 0) + 1
    rec.char = char
    rec.cscope = newScope("char:"..rec.plr.Name..":"..rec.gen)
    rec.hum  = char:FindFirstChildOfClass("Humanoid")
    rec.root = char:FindFirstChild("HumanoidRootPart")
    rec.head = char:FindFirstChild("Head")
    rec.torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    rec.rig  = (rec.hum and rec.hum.RigType == Enum.HumanoidRigType.R15) and "R15" or "R6"
    rec.alive = (rec.hum ~= nil and rec.hum.Health > 0)
    if rec.hum then
        rec.cscope:Connect(rec.hum.Died, function() rec.alive = false end)
        rec.cscope:Connect(rec.hum:GetPropertyChangedSignal("Health"), function()
            rec.alive = rec.hum.Health > 0
        end)
    end
    recomputeEnemy(rec)
    for _, fn in ipairs(charL) do pcall(fn, rec, char, rec.gen) end
end

local function onCharRemoving(rec, char)
    if rec.char ~= char then return end
    rec.alive = false
    rec.char = nil; rec.hum = nil; rec.root = nil; rec.head = nil; rec.torso = nil
    if rec.cscope then rec.cscope:Destroy(); rec.cscope = nil end
    for _, fn in ipairs(leaveL) do pcall(fn, rec, char) end
end

local function wire(plr)
    local rec = { plr = plr, gen = 0 }
    rec.pscope = newScope("plr:"..plr.Name)
    Cache.byPlayer[plr] = rec
    rec.pscope:Connect(plr.CharacterAdded, function(c) onCharAdded(rec, c) end)
    rec.pscope:Connect(plr.CharacterRemoving, function(c) onCharRemoving(rec, c) end)
    rec.pscope:Connect(plr:GetPropertyChangedSignal("Team"), recomputeAll)
    rec.pscope:Connect(plr:GetPropertyChangedSignal("Neutral"), recomputeAll)
    if plr.Character then onCharAdded(rec, plr.Character) end
end
local function unwire(plr)
    local rec = Cache.byPlayer[plr]
    if not rec then return end
    if rec.char then for _, fn in ipairs(leaveL) do pcall(fn, rec, rec.char) end end
    if rec.pscope then rec.pscope:Destroy() end
    if rec.cscope then rec.cscope:Destroy() end
    Cache.byPlayer[plr] = nil
end
for _, p in ipairs(Players:GetPlayers()) do wire(p) end
App:Connect(Players.PlayerAdded, wire)
App:Connect(Players.PlayerRemoving, unwire)
App:Connect(LP:GetPropertyChangedSignal("Team"), recomputeAll)
App:Connect(LP:GetPropertyChangedSignal("Neutral"), recomputeAll)
recomputeAll()

----------------------------------------------------------------
-- SHARED RAYCAST + VISIBILITY
----------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local internalRay = false

local function isVisible(pos, targetChar)
    if not cam then return true end
    local ignore = { cam }
    local lc = localRec()
    if lc and lc.char then ignore[#ignore+1] = lc.char end
    rayParams.FilterDescendantsInstances = ignore
    local origin = cam.CFrame.Position
    local dir = pos - origin
    if dir.Magnitude < 0.05 then return true end
    internalRay = true
    local ok, hit = pcall(WS.Raycast, WS, origin, dir, rayParams)
    internalRay = false
    if not ok then return true end
    if not hit then return true end
    if targetChar and hit.Instance:IsDescendantOf(targetChar) then return true end
    return false
end

----------------------------------------------------------------
-- DIAGNOSTICS
----------------------------------------------------------------
local Diag = { fps=60, proj=0, ray=0, projRate=0, rayRate=0 }
local rateAcc = 0
App:Connect(RS.Heartbeat, function(dt)
    rateAcc += dt
    if rateAcc >= 1 then
        Diag.projRate = math.floor(Diag.proj / rateAcc)
        Diag.rayRate  = math.floor(Diag.ray  / rateAcc)
        Diag.proj = 0; Diag.ray = 0; rateAcc = 0
    end
    if dt > 0 then Diag.fps = Diag.fps + (1/dt - Diag.fps) * 0.05 end
end)

----------------------------------------------------------------
-- UI (inline, unknown theme, DisplayOrder=100, IgnoreGuiInset=false)
----------------------------------------------------------------
local COL = {
    bg     = Color3.fromRGB(12, 12, 14),
    panel  = Color3.fromRGB(18, 18, 21),
    elem   = Color3.fromRGB(24, 24, 28),
    stroke = Color3.fromRGB(38, 38, 44),
    text   = Color3.fromRGB(235, 235, 240),
    muted  = Color3.fromRGB(120, 120, 130),
    accent = Color3.fromRGB(255, 60, 60),
    off    = Color3.fromRGB(70, 70, 78),
}
local guiParent
do
    local ok, t = nil, nil
    if CAP.gethui then ok, t = pcall(gethui) end
    if ok and t then guiParent = t
    else
        ok, t = pcall(function() return LP:WaitForChild("PlayerGui", 3) end)
        guiParent = (ok and t) or CoreGui
    end
end
local gui = App:Give(Instance.new("ScreenGui"))
gui.Name = "unk_v8_"..math.random(100, 999)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false -- ВАЖНО: не игнорим inset, чтобы не конфликтовать с topbar
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 100 -- достаточно высокий, но не конфликтует с Roblox CoreGui (1000+)
gui.Parent = guiParent

local function inst(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function corner(p, r) inst("UICorner", {CornerRadius=UDim.new(0, r or 8)}, p) end
local function stroke(p, c, t) inst("UIStroke", {Color=c or COL.stroke, Thickness=t or 1}, p) end

local main = inst("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(640, 480),
    BackgroundColor3 = COL.bg, BorderSizePixel = 0, ClipsDescendants = true,
}, gui)
corner(main, 10); stroke(main)

local topbar = inst("Frame", {Size=UDim2.new(1,0,0,44), BackgroundColor3=COL.panel, BorderSizePixel=0}, main)
corner(topbar, 10)
inst("Frame", {Size=UDim2.new(1,0,0,10), Position=UDim2.new(0,0,1,-10), BackgroundColor3=COL.panel, BorderSizePixel=0}, topbar)
inst("Frame", {Size=UDim2.fromOffset(3,14), Position=UDim2.fromOffset(12,15), BackgroundColor3=COL.accent, BorderSizePixel=0}, topbar)
inst("TextLabel", {
    Size=UDim2.fromOffset(160,20), Position=UDim2.fromOffset(22,12), BackgroundTransparency=1,
    Text="unknown", Font=Enum.Font.Code, TextSize=16, TextColor3=COL.text,
    TextXAlignment=Enum.TextXAlignment.Left,
}, topbar)
inst("TextLabel", {
    Size=UDim2.fromOffset(140,14), Position=UDim2.new(1,-150,0.5,-7), BackgroundTransparency=1,
    Text="v8 // 2026", Font=Enum.Font.Code, TextSize=10, TextColor3=COL.muted,
    TextXAlignment=Enum.TextXAlignment.Right,
}, topbar)
local hideBtn = inst("TextButton", {
    Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-32,0.5,-12),
    BackgroundColor3=COL.elem, BorderSizePixel=0, Text="x",
    TextColor3=COL.text, Font=Enum.Font.GothamBold, TextSize=11, AutoButtonColor=false,
}, topbar); corner(hideBtn, 6)
local minBtn = inst("TextButton", {
    Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-60,0.5,-12),
    BackgroundColor3=COL.elem, BorderSizePixel=0, Text="-",
    TextColor3=COL.text, Font=Enum.Font.GothamBold, TextSize=11, AutoButtonColor=false,
}, topbar); corner(minBtn, 6)

local sidebar = inst("Frame", {
    Size=UDim2.new(0, 120, 1, -52), Position=UDim2.fromOffset(8, 48),
    BackgroundColor3=COL.panel, BorderSizePixel=0,
}, main); corner(sidebar, 8)
local tabList = inst("ScrollingFrame", {
    Size=UDim2.new(1,-8,1,-8), Position=UDim2.fromOffset(4,4),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=0, CanvasSize=UDim2.new(),
}, sidebar)
local tabLayout = inst("UIListLayout", {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder}, tabList)
tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    tabList.CanvasSize = UDim2.fromOffset(0, tabLayout.AbsoluteContentSize.Y + 4)
end)

local pages = inst("Frame", {
    Size=UDim2.new(1, -132, 1, -52), Position=UDim2.fromOffset(132, 48), BackgroundTransparency=1,
}, main)

-- DRAG
do
    local dragging, dragStart, startPos = false, nil, nil
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = main.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            main.Position = UDim2.new(0.5, startPos.X.Offset + d.X, 0.5, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function() dragging = false end)
end

-- TAB FACTORY
local tabs, selectedTab = {}, nil
local capturing = nil
local function selectTab(rec)
    selectedTab = rec
    for _, t in ipairs(tabs) do
        local sel = (t == rec)
        t.page.Visible = sel
        t.btn.BackgroundColor3 = sel and COL.elem or COL.panel
        t.btn.TextColor3 = sel and COL.text or COL.muted
    end
end
local function addTab(name)
    local page = inst("ScrollingFrame", {
        BackgroundTransparency=1, BorderSizePixel=0, Size=UDim2.new(1,0,1,0),
        ScrollBarThickness=3, ScrollBarImageColor3=COL.stroke, Visible=false, CanvasSize=UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, pages)
    local layout = inst("UIListLayout", {Padding=UDim.new(0,5), SortOrder=Enum.SortOrder.LayoutOrder}, page)
    inst("UIPadding", {PaddingTop=UDim.new(0,4), PaddingBottom=UDim.new(0,8), PaddingLeft=UDim.new(0,4), PaddingRight=UDim.new(0,6)}, page)
    local btn = inst("TextButton", {
        Size=UDim2.new(1,0,0,30), BackgroundColor3=COL.panel, BorderSizePixel=0,
        Text=name, TextColor3=COL.muted, Font=Enum.Font.GothamMedium, TextSize=12, AutoButtonColor=false,
    }, tabList); corner(btn, 6)
    local rec = { name=name, page=page, btn=btn, elements={} }
    table.insert(tabs, rec)
    btn.MouseButton1Click:Connect(function() selectTab(rec) end)
    if not selectedTab then selectTab(rec) end
    local tab = {}
    local order = 0
    local function row(h)
        order = order + 1
        local f = inst("Frame", {
            Size=UDim2.new(1,0,0,h), BackgroundColor3=COL.elem, BorderSizePixel=0, LayoutOrder=order,
        }, page); corner(f, 7); stroke(f)
        return f
    end
    local function rtitle(f, t)
        return inst("TextLabel", {
            Size=UDim2.new(0.62,-12,1,0), Position=UDim2.fromOffset(10,0), BackgroundTransparency=1,
            Text=t, TextXAlignment=Enum.TextXAlignment.Left, TextColor3=COL.text,
            Font=Enum.Font.Gotham, TextSize=13,
        }, f)
    end
    local function click(f, cb)
        local o = inst("TextButton", {
            Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Text="", AutoButtonColor=false, ZIndex=5,
        }, f)
        o.MouseButton1Click:Connect(function() pcall(cb) end)
        return o
    end
    function tab:Section(t)
        order = order + 1
        inst("TextLabel", {
            Size=UDim2.new(1,0,0,18), BackgroundTransparency=1, Text=t,
            TextXAlignment=Enum.TextXAlignment.Left, TextColor3=COL.muted,
            Font=Enum.Font.GothamSemibold, TextSize=11, LayoutOrder=order,
        }, page)
    end
    function tab:Label(t)
        local f = row(26)
        local l = rtitle(f, t); l.Size=UDim2.new(1,-14,1,0); l.TextColor3=COL.muted
        return { Set=function(_, v) l.Text=tostring(v) end }
    end
    function tab:Button(name, cb)
        local f = row(30)
        local l = rtitle(f, name); l.Size=UDim2.new(1,-14,1,0); l.TextColor3=COL.text
        click(f, cb)
    end
    function tab:Toggle(name, path)
        local f = row(28)
        rtitle(f, name)
        local sw = inst("Frame", {
            Size=UDim2.fromOffset(34,16), Position=UDim2.new(1,-42,0.5,-8),
            BackgroundColor3=COL.bg, BorderSizePixel=0,
        }, f); corner(sw, 8); stroke(sw)
        local ind = inst("Frame", {
            Size=UDim2.fromOffset(10,10), AnchorPoint=Vector2.new(0,0.5),
            BackgroundColor3=COL.off, BorderSizePixel=0,
        }, sw); corner(ind, 5)
        local function paint(v)
            ind.BackgroundColor3 = v and COL.accent or COL.off
            ind.Position = UDim2.new(v and 1 or 0, v and -13 or 3, 0.5, 0)
        end
        uiref(path, paint); paint(G(path))
        click(f, function() P(path, not G(path)) end)
    end
    function tab:Slider(name, path, min, max, step, suffix)
        local f = row(42); rtitle(f, name)
        local info = inst("TextLabel", {
            Size=UDim2.fromOffset(80,14), Position=UDim2.new(1,-90,0,4),
            BackgroundTransparency=1, TextColor3=COL.text, Font=Enum.Font.Gotham,
            TextSize=11, TextXAlignment=Enum.TextXAlignment.Right,
        }, f)
        local track = inst("Frame", {
            Size=UDim2.new(1,-20,0,4), Position=UDim2.fromOffset(10,30),
            BackgroundColor3=COL.off, BorderSizePixel=0,
        }, f); corner(track, 2)
        local fill = inst("Frame", {
            Size=UDim2.new(0,0,1,0), BackgroundColor3=COL.accent, BorderSizePixel=0,
        }, track); corner(fill, 2)
        local function paint(v)
            local r = (max > min) and ((v - min) / (max - min)) or 0
            fill.Size = UDim2.new(math.clamp(r, 0, 1), 0, 1, 0)
            local txt = tostring(v)
            if math.abs(v - math.floor(v)) > 0.001 then txt = string.format("%.2f", v) end
            info.Text = txt .. (suffix or "")
        end
        uiref(path, paint); paint(G(path))
        local drag = false
        local function fromX(x)
            local w = math.max(track.AbsoluteSize.X, 1)
            local r = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
            local v = min + (max - min) * r
            v = math.floor(v / step + 0.5) * step
            P(path, v)
        end
        track.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; fromX(i.Position.X) end end)
        UIS.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then fromX(i.Position.X) end end)
        UIS.InputEnded:Connect(function() drag = false end)
    end
    function tab:Dropdown(name, path, options)
        local f = row(30); rtitle(f, name)
        local sel = inst("TextLabel", {
            Size=UDim2.new(0.34,-20,1,0), Position=UDim2.new(0.66,-14,0,0),
            BackgroundTransparency=1, Text=tostring(G(path)), TextColor3=COL.muted,
            Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Right,
        }, f)
        local list = inst("Frame", {
            Size=UDim2.new(1,-8,0,0), Position=UDim2.new(0,4,1,2),
            BackgroundColor3=COL.panel, BorderSizePixel=0, ClipsDescendants=true,
            Visible=false, ZIndex=30,
        }, f); corner(list, 7); stroke(list)
        local ll = inst("UIListLayout", {Padding=UDim.new(0,3), SortOrder=Enum.SortOrder.LayoutOrder}, list)
        local open = false
        for _, opt in ipairs(options) do
            local ob = inst("TextButton", {
                Size=UDim2.new(1,0,0,24), BackgroundColor3=COL.elem, BorderSizePixel=0,
                Text="  "..opt, TextXAlignment=Enum.TextXAlignment.Left, TextColor3=COL.text,
                Font=Enum.Font.Gotham, TextSize=12, AutoButtonColor=false, ZIndex=31,
            }, list); corner(ob, 5)
            ob.MouseButton1Click:Connect(function()
                P(path, opt); sel.Text = opt; open = false; list.Visible = false
            end)
        end
        ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            list.CanvasSize = UDim2.fromOffset(0, ll.AbsoluteContentSize.Y + 6)
        end)
        uiref(path, function(v) sel.Text = tostring(v) end)
        click(f, function()
            open = not open; list.Visible = open
            if open then list.Size = UDim2.new(1,-8,0, #options * 27 + 8) end
        end)
    end
    function tab:Keybind(name, path)
        local f = row(28); rtitle(f, name)
        local kb = inst("TextButton", {
            Size=UDim2.fromOffset(84,20), Position=UDim2.new(1,-92,0.5,-10),
            BackgroundColor3=COL.panel, BorderSizePixel=0, Text=tostring(G(path)),
            TextColor3=COL.text, Font=Enum.Font.Gotham, TextSize=11, AutoButtonColor=false,
        }, f); corner(kb, 5); stroke(kb)
        kb.MouseButton1Click:Connect(function() capturing = path; kb.Text = "press" end)
        uiref(path, function(v) kb.Text = tostring(v) end)
    end
    return tab
end

----------------------------------------------------------------
-- AIMBOT MODULE (multipoint + prediction + backtrack + single lock state)
----------------------------------------------------------------
local HIT_PRIORITY = {
    Head    = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"},
    Torso   = {"UpperTorso", "LowerTorso", "HumanoidRootPart", "Head"},
    Nearest = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "Torso"},
}
local LEAD_CAP = 35
local VEL_EMA_TC = 0.10
local VEL_CAP = 500
local VEL_STALE = 2.0
local GRAVITY_Y = WS.Gravity or 196.2
local BACKTRACK_MAX = 16

local velEMA    = setmetatable({}, {__mode="k"})
local velTS     = setmetatable({}, {__mode="k"})
local btHistory = setmetatable({}, {__mode="k"})

local function pickPart(rec)
    if not rec or not rec.char then return nil end
    local bone = S.Aimbot.Bone
    local list = HIT_PRIORITY[bone] or HIT_PRIORITY.Head
    for _, n in ipairs(list) do
        local p = rec.char:FindFirstChild(n)
        if p and p:IsA("BasePart") then
            -- если bone = Head и голова в стене, фолбэк на торс
            if bone == "Head" and n == "Head" and S.Aimbot.WallCheck then
                local sp, on = cam:WorldToViewportPoint(p.Position)
                if on and sp.Z > 0 and isVisible(p.Position, rec.char) then return p end
            else
                return p
            end
        end
    end
    return nil
end

local function computePredicted(part, smoothed, dist)
    local t = S.Aimbot.Prediction * (1 + dist / 300)
    local lead = smoothed * t
    if lead.Magnitude > LEAD_CAP then lead = lead.Unit * LEAD_CAP end
    local pos = part.Position + lead
    if S.Aimbot.PredictGravity and t > 0 then
        pos = pos + Vector3.new(0, -0.5 * GRAVITY_Y * t * t, 0)
    end
    return pos
end

local function predictPosition(part)
    if not part or not part.Parent then return part and part.Position or nil end
    local now = os.clock()
    local curVel = part.AssemblyLinearVelocity
    if typeof(curVel) ~= "Vector3" then curVel = Vector3.zero end
    if curVel.Magnitude > VEL_CAP then curVel = curVel.Unit * VEL_CAP end
    local prev, prevT = velEMA[part], velTS[part]
    local smoothed
    if prev and prevT and (now - prevT) < VEL_STALE then
        local dt = now - prevT
        local alpha = 1 - math.exp(-dt / VEL_EMA_TC)
        alpha = math.clamp(alpha, 0, 1)
        smoothed = prev:Lerp(curVel, alpha)
    else
        smoothed = curVel
    end
    velEMA[part] = smoothed; velTS[part] = now
    local origin = cam and cam.CFrame.Position or Vector3.zero
    local d1 = (part.Position - origin).Magnitude
    local pos1 = computePredicted(part, smoothed, d1)
    local d2 = (pos1 - origin).Magnitude
    return computePredicted(part, smoothed, d2)
end

local function storeBacktrack(part)
    if not S.Aimbot.Backtrack then return end
    local hist = btHistory[part]
    if not hist then hist = {}; btHistory[part] = hist end
    hist[#hist+1] = { pos = part.Position, t = os.clock() }
    while #hist > BACKTRACK_MAX do table.remove(hist, 1) end
end

local function getBacktrackPos(part)
    if not S.Aimbot.Backtrack then return part.Position end
    local hist = btHistory[part]
    if not hist or #hist == 0 then return part.Position end
    local now = os.clock()
    local maxAge = S.Aimbot.BacktrackTime
    for i = #hist, 1, -1 do
        local entry = hist[i]
        if now - entry.t > maxAge then break end
        if isVisible(entry.pos, part.Parent) then return entry.pos end
    end
    return part.Position
end

-- AIM state (single source of truth)
local AIM = {
    current = nil,        -- {rec, part, pos, screen, plr}
    prevPlayer = nil,
    triggerAcc = 0,
    lastShot = 0,
}

-- Target Lock: watch Aimbot.TargetLock directly (Q-toggle пишет сюда же)
watch("Aimbot.TargetLock", function(v)
    if not v then AIM.current = nil; AIM.prevPlayer = nil end
end)
watch("Aimbot.Enabled", function(v)
    if not v then AIM.current = nil; AIM.prevPlayer = nil end
end)

local function getBestTarget()
    if not cam then return nil end
    local lc = localRec()
    if not lc or not lc.alive then return nil end
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local fov = S.Aimbot.FOV
    local hystFOV = fov * S.Aimbot.HysteresisMult

    -- TARGET LOCK RETENTION (единственный источник правды: S.Aimbot.TargetLock)
    if S.Aimbot.TargetLock and AIM.current then
        local rec = AIM.current.rec
        if rec and rec.alive and rec.char and rec.char.Parent then
            local part = pickPart(rec)
            if part then
                local pos = predictPosition(part)
                if pos then
                    local sp, on = cam:WorldToViewportPoint(pos)
                    if on and sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= fov * 1.5 then
                            if not S.Aimbot.WallCheck or isVisible(pos, rec.char) then
                                return { rec=rec, part=part, pos=pos, screen=sp, plr=rec.plr }
                            end
                        end
                    end
                end
            end
        end
        -- цель потеряна — сбрасываем lock
        P("Aimbot.TargetLock", false, true)
        AIM.current = nil; AIM.prevPlayer = nil
    end

    local bestEntry, bestDist = nil, fov
    local prevEntry = nil
    for plr, rec in pairs(Cache.byPlayer) do
        if plr ~= LP and rec.alive and rec.char then
            if not S.Aimbot.OnlyEnemies or rec.enemy then
                local part = pickPart(rec)
                if part then
                    storeBacktrack(part)
                    local pos = predictPosition(part)
                    if pos then
                        local sp, on = cam:WorldToViewportPoint(pos)
                        if on and sp.Z > 0 then
                            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            local visible = (not S.Aimbot.WallCheck) or isVisible(pos, rec.char)
                            if not visible and S.Aimbot.Backtrack then
                                local bp = getBacktrackPos(part)
                                if bp ~= part.Position then
                                    pos = bp
                                    local sp2 = cam:WorldToViewportPoint(pos)
                                    d = (Vector2.new(sp2.X, sp2.Y) - center).Magnitude
                                    visible = true
                                end
                            end
                            if visible and d <= fov then
                                -- Scoring: dist + weight*(1-hp)
                                local hp = (rec.hum and rec.hum.Health>0 and rec.hum.MaxHealth>0)
                                    and (rec.hum.Health / rec.hum.MaxHealth) or 0
                                local score = d + 100 * (1 - hp)
                                if plr == AIM.prevPlayer and d <= hystFOV then
                                    prevEntry = { rec=rec, part=part, pos=pos, screen=sp, d=d, score=score, plr=plr }
                                end
                                if d < bestDist then
                                    bestDist = d
                                    bestEntry = { rec=rec, part=part, pos=pos, screen=sp, d=d, score=score, plr=plr }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    -- Hysteresis: keep prev if new is not much closer
    local final
    if S.Aimbot.Hysteresis and prevEntry and bestEntry and prevEntry.plr ~= bestEntry.plr then
        final = (bestEntry.score < prevEntry.score * 0.85) and bestEntry or prevEntry
    else
        final = bestEntry or prevEntry
    end
    AIM.prevPlayer = final and final.plr or nil
    return final
end

-- FOV Circle
local fovCircle = nil
if CAP.drawing then
    local ok, c = pcall(function() return Drawing.new("Circle") end)
    if ok and c then
        fovCircle = c; c.Thickness = 2; c.NumSides = 64; c.Filled = false
        c.Color = Color3.fromRGB(255, 60, 60); c.Visible = false
        App:Add(function() pcall(function() c:Remove() end) end)
    end
end

-- Target indicator
local tgtCircle = nil
if CAP.drawing then
    local ok, c = pcall(function() return Drawing.new("Circle") end)
    if ok and c then
        tgtCircle = c; c.Thickness = 2; c.NumSides = 24; c.Filled = false
        c.Color = Color3.fromRGB(255, 200, 60); c.Visible = false
        App:Add(function() pcall(function() c:Remove() end) end)
    end
end

local function aimUpdate(dt)
    if fovCircle then
        if (S.Aimbot.Enabled or S.Aimbot.Silent) and S.ESP.ShowFOVCircle and cam then
            local vp = cam.ViewportSize
            fovCircle.Position = Vector2.new(vp.X*0.5, vp.Y*0.5)
            fovCircle.Radius = S.Aimbot.FOV
            fovCircle.Color = S.Aimbot.Silent
                and Color3.fromRGB(255, 80, 80)
                or  Color3.fromRGB(255, 60, 60)
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end
    local t = nil
    if S.Aimbot.Enabled or S.Aimbot.Silent then t = getBestTarget() end
    AIM.current = t
    if tgtCircle then
        if t and S.ESP.ShowTargetIndicator and cam and t.rec.head then
            local sp, on = cam:WorldToViewportPoint(t.rec.head.Position + Vector3.new(0, 0.5, 0))
            if on and sp.Z > 0 then
                tgtCircle.Position = Vector2.new(sp.X, sp.Y)
                tgtCircle.Radius = 10
                tgtCircle.Visible = true
            else tgtCircle.Visible = false end
        else tgtCircle.Visible = false end
    end
    if S.Aimbot.Enabled and t and cam then
        local c = cam.CFrame
        local desired = CFrame.lookAt(c.Position, t.pos)
        local sm = math.max(S.Aimbot.Smoothing, 0.01)
        local sens = math.max(S.Aimbot.Sensitivity, 0.01)
        local alpha = (1 - math.exp(-(dt or 1/60) * (60 / sm))) * sens
        cam.CFrame = c:Lerp(desired, math.clamp(alpha, 0, 1))
    end
end
App:BindRender("aim", Enum.RenderPriority.Camera.Value - 1, aimUpdate)

----------------------------------------------------------------
-- SILENT AIM HOOK (AGGRESSIVE: covers all modern + legacy APIs)
-- Raycast, FindPartOnRay*, Spherecast, Blockcast, GetPartBoundsInBox, GetPartsInPart
----------------------------------------------------------------
local hookOn, origNC, gameMt = false, nil, nil
local lastShotTime = 0
local silentTS = {} -- sliding 1-sec rate limiter

local function rateLimitOk()
    local cap = 60 -- max 60 silent redirects per second
    local now = os.clock()
    while #silentTS > 0 and (now - silentTS[1]) > 1 do
        table.remove(silentTS, 1)
    end
    if #silentTS >= cap then return false end
    table.insert(silentTS, now)
    return true
end

local function shotDelayOk()
    local now = os.clock()
    if now - lastShotTime < 0.05 then return false end
    lastShotTime = now
    return true
end

local function humanize(part, pos)
    if not part or not part:IsA("BasePart") then return pos end
    local s = math.clamp(S.Aimbot.HumanizerStrength, 0, 1)
    if s <= 0 then return pos end
    local sz = part.Size
    return pos + Vector3.new(
        (math.random() - 0.5) * sz.X * 0.4 * s,
        (math.random() - 0.5) * sz.Y * 0.3 * s,
        (math.random() - 0.5) * sz.Z * 0.4 * s
    )
end

local function isPlayerOriginRay(origin)
    if typeof(origin) ~= "Vector3" then return false end
    local lc = localRec()
    if not lc or not lc.char then return false end
    local hrp = lc.root or lc.char:FindFirstChild("HumanoidRootPart") or lc.char:FindFirstChild("Torso")
    if not hrp then return false end
    return (origin - hrp.Position).Magnitude < 60
end

local function getValidTarget()
    local t = AIM.current
    if not t then return nil end
    if not t.rec or not t.rec.alive then return nil end
    if not t.part or not t.part.Parent then return nil end
    if cam then
        local sp, on = cam:WorldToViewportPoint(t.pos)
        if not on or sp.Z < 0 then return nil end
    end
    return t
end

local function hookBody(self, ...)
    if internalRay or not S.Aimbot.Silent then return origNC(self, ...) end
    if self ~= WS then return origNC(self, ...) end
    local m = getnamecallmethod()
    local isRay = (m == "Raycast")
    local isLegacy = (m == "FindPartOnRay" or m == "FindPartOnRayWithIgnoreList" or m == "FindPartOnRayWithWhitelist")
    local isSphere = (m == "Spherecast")
    local isBlock = (m == "Blockcast")
    local isBounds = (m == "GetPartBoundsInBox" or m == "GetPartsInPart")
    if not isRay and not isLegacy and not isSphere and not isBlock and not isBounds then
        return origNC(self, ...)
    end
    local origin, dir
    if isRay or isSphere or isBlock then
        origin = select(1, ...)
        if typeof(origin) ~= "Vector3" then return origNC(self, ...) end
        local darg = select(2, ...)
        if isRay or isSphere then
            if typeof(darg) ~= "Vector3" then return origNC(self, ...) end
            dir = darg
        elseif isBlock then
            if typeof(darg) ~= "CFrame" then return origNC(self, ...) end
            dir = darg.LookVector * 100
        end
    elseif isLegacy then
        local r = select(1, ...)
        if typeof(r) ~= "Ray" then return origNC(self, ...) end
        origin, dir = r.Origin, r.Direction
    elseif isBounds then
        local cf = select(1, ...)
        if typeof(cf) ~= "CFrame" then return origNC(self, ...) end
        origin = cf.Position
        dir = cf.LookVector * 50
    end
    if not dir or dir.Magnitude < 0.5 then return origNC(self, ...) end
    if not isPlayerOriginRay(origin) then return origNC(self, ...) end
    if not rateLimitOk() then return origNC(self, ...) end
    if not shotDelayOk() then return origNC(self, ...) end
    local t = getValidTarget()
    if not t then return origNC(self, ...) end
    -- hit chance
    if S.Aimbot.HitChance < 100 and math.random(1, 100) > S.Aimbot.HitChance then
        return origNC(self, ...)
    end
    local diff = t.pos - origin
    if diff.Magnitude < 0.5 then return origNC(self, ...) end
    local aimPos = humanize(t.part, t.pos)
    local diff2 = aimPos - origin
    if diff2.Magnitude < 0.5 then return origNC(self, ...) end
    local nd = diff2.Unit * dir.Magnitude
    if isRay then
        local a = { ... }; a[2] = nd
        return origNC(self, table.unpack(a))
    elseif isSphere then
        local a = { ... }; a[2] = nd
        return origNC(self, table.unpack(a))
    elseif isBlock then
        local cf = select(1, ...)
        local newCf = CFrame.new(cf.Position, aimPos)
        local a = { ... }; a[1] = newCf; a[2] = (aimPos - cf.Position)
        return origNC(self, table.unpack(a))
    elseif isLegacy then
        local a = { ... }; a[1] = Ray.new(origin, nd)
        return origNC(self, table.unpack(a))
    elseif isBounds then
        local newCf = CFrame.new(cf.Position, aimPos)
        local a = { ... }; a[1] = newCf
        return origNC(self, table.unpack(a))
    end
    return origNC(self, ...)
end

local function installHook()
    if hookOn or not CAP.hook then return end
    local ok, mt = pcall(getrawmetatable, game)
    if not ok or not mt then return end
    gameMt = mt; origNC = mt.__namecall
    pcall(setreadonly, mt, false)
    mt.__namecall = newcclosure(hookBody)
    pcall(setreadonly, mt, true)
    hookOn = true
end
local function uninstallHook()
    if not hookOn or not gameMt or not origNC then return end
    pcall(setreadonly, gameMt, false)
    gameMt.__namecall = origNC
    pcall(setreadonly, gameMt, true)
    hookOn = false
end
installHook()
App:Add(uninstallHook)
watch("Aimbot.Silent", function(v) if v then installHook() end end)

----------------------------------------------------------------
-- TRIGGERBOT (camera-center raycast, proper wallcheck, cooldown)
----------------------------------------------------------------
local function triggerUpdate(dt)
    if not S.Trigger.Enabled or not cam or not CAP.mouse1 then return end
    AIM.triggerAcc = (AIM.triggerAcc or 0) + dt
    if AIM.triggerAcc < S.Trigger.Delay then return end
    local lc = localRec()
    if not lc or not lc.alive then return end
    local now = os.clock()
    if now - AIM.lastShot < S.Trigger.Cooldown then return end
    local origin = cam.CFrame.Position
    local dir = cam.CFrame.LookVector * 1000
    local ignore = { cam }
    if lc.char then ignore[#ignore+1] = lc.char end
    rayParams.FilterDescendantsInstances = ignore
    internalRay = true
    local ok, hit = pcall(WS.Raycast, WS, origin, dir, rayParams)
    internalRay = false
    if not ok or not hit then return end
    -- найти владельца хита
    local inst = hit.Instance
    while inst and not inst:IsA("Model") do inst = inst.Parent end
    if not inst then return end
    local owner = Players:GetPlayerFromCharacter(inst)
    if not owner or owner == LP then return end
    local rec = Cache.byPlayer[owner]
    if not rec or not rec.alive then return end
    if S.Trigger.OnlyEnemies and not rec.enemy then return end
    -- wallcheck: хит должен быть ВНУТРИ char (не стена перед ним)
    if S.Trigger.WallCheck and not hit.Instance:IsDescendantOf(rec.char) then return end
    -- min distance (5 studs)
    if (hit.Position - origin).Magnitude < 5 then return end
    AIM.triggerAcc = 0
    AIM.lastShot = now
    pcall(function() mouse1click() end)
end
App:Connect(RS.Heartbeat, triggerUpdate)

----------------------------------------------------------------
-- ESP MODULE (pooled, stable cleanup)
----------------------------------------------------------------
local Pool = { free = {Square={}, Line={}, Text={}}, count = 0 }
local function acquire(kind)
    if not CAP.drawing then return nil end
    local list = Pool.free[kind]
    local o = table.remove(list)
    if not o then
        local ok, d = pcall(Drawing.new, kind)
        if not ok then return nil end
        o = d; Pool.count = Pool.count + 1
    end
    o.Visible = false; return o
end
local function release(o, kind)
    if not o then return end
    pcall(function() o.Visible = false end)
    Pool.free[kind][#Pool.free[kind]+1] = o
end
local function releaseViz(rec)
    local v = rec.viz; if not v then return end
    release(v.box,  "Square"); release(v.hpBg,  "Square"); release(v.hpFill, "Square")
    release(v.snap, "Line");   release(v.name,  "Text");   release(v.dist,   "Text")
    if v.chams then pcall(function() v.chams:Destroy() end) end
    rec.viz = nil
end
onLeave(function(rec) releaseViz(rec) end)
onChar(function(rec) releaseViz(rec) end)
App:Add(function()
    for _, rec in pairs(Cache.byPlayer) do releaseViz(rec) end
    for _, list in pairs(Pool.free) do
        for _, o in ipairs(list) do pcall(function() o:Remove() end) end
    end
    Pool.count = 0
end)

local function espRecord(rec)
    local v = rec.viz or {}; rec.viz = v
    if not rec.alive or not rec.root then releaseViz(rec); return end
    if S.ESP.OnlyEnemies and not rec.enemy then releaseViz(rec); return end
    local camPos = cam.CFrame.Position
    local dist = (rec.root.Position - camPos).Magnitude
    if dist > S.ESP.MaxDistance then releaseViz(rec); return end
    local headPos = (rec.head and rec.head.Position) or (rec.root.Position + Vector3.new(0, 2.5, 0))
    local legPos  = rec.root.Position - Vector3.new(0, 2.5, 0)
    local hSp = cam:WorldToViewportPoint(headPos)
    local lSp = cam:WorldToViewportPoint(legPos)
    if hSp.Z < 0 and lSp.Z < 0 then releaseViz(rec); return end
    local height = math.abs(lSp.Y - hSp.Y)
    local width  = height * 0.5
    local x = hSp.X - width * 0.5
    local y = hSp.Y
    local color = rec.enemy and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(90, 140, 255)

    if S.ESP.Boxes then
        v.box = v.box or acquire("Square")
        if v.box then
            v.box.Filled=false; v.box.Thickness=1; v.box.Color=color
            v.box.Size=Vector2.new(width, height); v.box.Position=Vector2.new(x, y); v.box.Visible=true
        end
    else release(v.box, "Square"); v.box = nil end

    if S.ESP.HealthBar and rec.hum and rec.hum.MaxHealth > 0 then
        v.hpBg   = v.hpBg   or acquire("Square")
        v.hpFill = v.hpFill or acquire("Square")
        local pct = math.clamp(rec.hum.Health / rec.hum.MaxHealth, 0, 1)
        if v.hpBg then
            v.hpBg.Filled=true; v.hpBg.Color=Color3.fromRGB(0,0,0)
            v.hpBg.Size=Vector2.new(3, height); v.hpBg.Position=Vector2.new(x-5, y); v.hpBg.Visible=true
        end
        if v.hpFill then
            local bh = height * pct
            v.hpFill.Filled=true; v.hpFill.Size=Vector2.new(3, bh)
            v.hpFill.Position=Vector2.new(x-5, y + (height - bh))
            v.hpFill.Color=Color3.fromRGB(60,220,60):Lerp(Color3.fromRGB(220,60,60), 1-pct)
            v.hpFill.Visible=true
        end
    else release(v.hpBg,"Square"); v.hpBg=nil; release(v.hpFill,"Square"); v.hpFill=nil end

    if S.ESP.Snaplines then
        v.snap = v.snap or acquire("Line")
        if v.snap then
            local vp = cam.ViewportSize
            v.snap.Thickness=1; v.snap.Color=color
            v.snap.From=Vector2.new(vp.X*0.5, vp.Y); v.snap.To=Vector2.new(hSp.X, hSp.Y)
            v.snap.Visible=true
        end
    else release(v.snap, "Line"); v.snap = nil end

    if S.ESP.Names then
        v.name = v.name or acquire("Text")
        if v.name then
            v.name.Size=13; v.name.Center=true; v.name.Outline=true; v.name.Color=color
            v.name.Text=(rec.plr.DisplayName~="" and rec.plr.DisplayName) or rec.plr.Name
            v.name.Position=Vector2.new(hSp.X, y-16); v.name.Visible=true
        end
    else release(v.name, "Text"); v.name = nil end

    if S.ESP.Distance then
        v.dist = v.dist or acquire("Text")
        if v.dist then
            v.dist.Size=12; v.dist.Center=true; v.dist.Outline=true
            v.dist.Color=Color3.fromRGB(255,255,255)
            v.dist.Text=tostring(math.floor(dist)).."m"
            v.dist.Position=Vector2.new(hSp.X, y+height+4); v.dist.Visible=true
        end
    else release(v.dist, "Text"); v.dist = nil end

    if S.ESP.Chams then
        if not v.chams or v.chams.Parent ~= rec.char then
            if v.chams then pcall(function() v.chams:Destroy() end) end
            local h = Instance.new("Highlight")
            h.FillColor = color
            h.OutlineColor = Color3.fromRGB(255,255,255)
            h.FillTransparency = 0.4
            pcall(function() h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
            h.Adornee = rec.char; h.Parent = rec.char
            v.chams = h
        else
            v.chams.FillColor = color
            v.chams.Enabled = true
        end
    elseif v.chams then
        pcall(function() v.chams:Destroy() end)
        v.chams = nil
    end
end

local espAcc = 0
App:BindRender("esp", Enum.RenderPriority.Camera.Value + 2, function(dt)
    espAcc += dt
    if espAcc < 1/30 then return end
    espAcc = 0
    local enabled = S.ESP.Enabled and CAP.drawing
    for _, rec in pairs(Cache.byPlayer) do
        if rec.plr ~= LP then
            if enabled then espRecord(rec) else releaseViz(rec) end
        end
    end
end)

----------------------------------------------------------------
-- MOVEMENT MODULE (Speed / Fly / Noclip / InfJump / Bhop)
----------------------------------------------------------------
local MV = {
    origWalk = nil,
    fly = nil,
    ncOn = false, origCanCollide = setmetatable({}, {__mode="k"}),
    lastJumpTime = 0,
    lastBhopJump = 0,
}

local function destroyFly()
    if MV.fly then
        pcall(function() MV.fly.lv:Destroy() end)
        pcall(function() MV.fly.ao:Destroy() end)
        pcall(function() MV.fly.att:Destroy() end)
        MV.fly = nil
    end
end

local function ensureFly(root)
    if MV.fly and MV.fly.lv and MV.fly.lv.Parent == root then return end
    destroyFly()
    local att = Instance.new("Attachment"); att.Parent = root
    local lv = Instance.new("LinearVelocity")
    lv.Attachment0 = att; lv.MaxForce = math.huge
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.VectorVelocity = Vector3.zero; lv.Parent = root
    local ao = Instance.new("AlignOrientation")
    ao.Attachment0 = att; ao.MaxTorque = math.huge; ao.Responsiveness = 200
    ao.Mode = Enum.OrientationAlignmentMode.OneAttachment; ao.Parent = root
    MV.fly = { att=att, lv=lv, ao=ao }
end

local function applyNoClip(enable)
    local rec = localRec()
    if not rec or not rec.char then return end
    for _, part in ipairs(rec.char:GetDescendants()) do
        if part:IsA("BasePart") then
            if enable then
                if MV.origCanCollide[part] == nil then
                    MV.origCanCollide[part] = part.CanCollide
                end
                part.CanCollide = false
            else
                if MV.origCanCollide[part] ~= nil then
                    part.CanCollide = MV.origCanCollide[part]
                    MV.origCanCollide[part] = nil
                end
            end
        end
    end
end

onChar(function(rec)
    if rec == localRec() then
        MV.origWalk = nil
        MV.ncOn = false
        table.clear(MV.origCanCollide)
        destroyFly()
    end
end)

App:Connect(RS.Heartbeat, function(dt)
    local rec = localRec()
    if not rec or not rec.alive or not rec.hum or not rec.root then return end
    local hum, root = rec.hum, rec.root
    -- Speed
    if S.Move.Speed then
        if MV.origWalk == nil then MV.origWalk = hum.WalkSpeed end
        if S.Move.SpeedMode == "Walk" then
            if hum.WalkSpeed ~= S.Move.SpeedValue then hum.WalkSpeed = S.Move.SpeedValue end
        else
            local md = hum.MoveDirection
            if md.Magnitude > 0.1 then
                local v = root.AssemblyLinearVelocity
                local target = md * S.Move.SpeedValue
                local cap = S.Move.VelCap
                if target.Magnitude > cap then target = target.Unit * cap end
                root.AssemblyLinearVelocity = Vector3.new(target.X, v.Y, target.Z)
            end
        end
    elseif MV.origWalk then
        if hum.WalkSpeed ~= MV.origWalk then hum.WalkSpeed = MV.origWalk end
        MV.origWalk = nil
    end
    -- NoClip
    if S.Move.NoClip ~= MV.ncOn then
        applyNoClip(S.Move.NoClip)
        MV.ncOn = S.Move.NoClip
    end
    -- Fly
    if S.Move.Fly then
        ensureFly(root)
        local move = Vector3.zero
        if cam then
            local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
            if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + look end
            if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - look end
            if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - right end
            if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + right end
        end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0,1,0) end
        MV.fly.lv.VectorVelocity = (move.Magnitude > 0) and (move.Unit * S.Move.FlyValue) or Vector3.zero
        if cam then MV.fly.ao.CFrame = cam.CFrame end
    else
        destroyFly()
    end
end)

-- InfJump (with cooldown)
App:Connect(UIS.JumpRequest, function()
    local now = tick()
    if S.Move.InfJump and now - MV.lastJumpTime > S.Move.InfJumpCooldown then
        local rec = localRec()
        if rec and rec.hum then
            rec.hum:ChangeState(Enum.HumanoidStateType.Jumping)
            if S.Move.InfJumpBoost > 0 and rec.root then
                local v = rec.root.AssemblyLinearVelocity
                rec.root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y + S.Move.InfJumpBoost, v.Z)
            end
            MV.lastJumpTime = now
        end
    end
end)

-- Bhop (auto-jump on landing when Space held)
App:Connect(RS.Heartbeat, function()
    if not S.Move.Bhop then return end
    if not UIS:IsKeyDown(Enum.KeyCode.Space) then return end
    local now = tick()
    if now - MV.lastBhopJump < 0.1 then return end
    local rec = localRec()
    if not rec or not rec.hum then return end
    local s = rec.hum:GetState()
    if s == Enum.HumanoidStateType.Landed
    or s == Enum.HumanoidStateType.Running
    or s == Enum.HumanoidStateType.RunningNoPhysics then
        rec.hum:ChangeState(Enum.HumanoidStateType.Jumping)
        MV.lastBhopJump = now
    end
end)

----------------------------------------------------------------
-- ANTI-AIM MODULE (RenderStepped priority Camera+5 to beat animations)
----------------------------------------------------------------
local AA = {
    rootJ=nil, neck=nil, lowerJ=nil,
    origRoot=nil, origNeck=nil, origLower=nil,
    jitterWalk=0, patternIdx=1, patternTime=0,
    switchSide=1, lastSwitchT=0,
    fl={phase="release", accumulator=0, bufferedCF=nil, pulseCount=0},
}

onChar(function(rec)
    if rec == localRec() then
        AA.rootJ=nil; AA.neck=nil; AA.lowerJ=nil
        AA.origRoot=nil; AA.origNeck=nil; AA.origLower=nil
        AA.fl.phase="release"; AA.fl.accumulator=0; AA.fl.bufferedCF=nil
    end
end)

local function getJoints()
    local rec = localRec()
    if not rec or not rec.char or not rec.root then return end
    if not AA.rootJ then
        local j = rec.root:FindFirstChild("RootJoint")
        if j and j:IsA("Motor6D") then AA.rootJ = j; AA.origRoot = j.C0 end
    end
    if not AA.neck and rec.head then
        local n = rec.head:FindFirstChild("Neck")
        if n and n:IsA("Motor6D") then AA.neck = n; AA.origNeck = n.C0 end
    end
    if not AA.lowerJ then
        local lt = rec.char:FindFirstChild("LowerTorso")
        if lt then
            local w = lt:FindFirstChild("Waist")
            if w and w:IsA("Motor6D") then AA.lowerJ = w; AA.origLower = w.C0 end
        end
    end
end

local function computeJitter()
    if not S.AA.Jitter then return 0 end
    local max = math.rad(S.AA.JitterAngle)
    local mode = S.AA.JitterMode
    local speed = S.AA.JitterSpeed
    if mode == "Sine" then
        return math.sin(tick() * speed) * max
    elseif mode == "Static" then
        return max
    elseif mode == "Flick" then
        local phase = math.floor(tick() * speed) % 2
        return (phase == 0) and max or -max
    elseif mode == "RandomWalk" then
        AA.jitterWalk = AA.jitterWalk + (math.random() - 0.5) * 0.15
        if AA.jitterWalk > 1 then AA.jitterWalk = 1 elseif AA.jitterWalk < -1 then AA.jitterWalk = -1 end
        return AA.jitterWalk * max
    elseif mode == "CustomPattern" then
        local pat = {1, -1, 0.5, -0.5}
        if tick() - AA.patternTime > 0.15 then
            AA.patternIdx = (AA.patternIdx % #pat) + 1
            AA.patternTime = tick()
        end
        return (pat[AA.patternIdx] or 0) * max
    end
    return 0
end

local function computeDesync()
    if not S.AA.Desync then return 0 end
    local str = math.clamp(S.AA.DesyncStrength, 0, 1)
    local mode = S.AA.DesyncMode
    if mode == "Static" then
        return math.rad(60) * str
    elseif mode == "Spin" then
        return math.rad(tick() * S.AA.DesyncSpeed) * str
    elseif mode == "Random" then
        return (math.random() * 2 - 1) * math.rad(120) * str
    elseif mode == "Switch" then
        local interval = 1 / math.max(S.AA.DesyncSpeed / 10, 0.5)
        if tick() - AA.lastSwitchT > interval then
            AA.switchSide = -AA.switchSide; AA.lastSwitchT = tick()
        end
        return math.rad(60) * str * AA.switchSide
    elseif mode == "Backwards" then
        return math.rad(180) * str
    end
    return 0
end

local function applyFakeLag(dt, root, hum)
    if not S.AA.FakeLag then
        if AA.fl.phase == "lag" then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            AA.fl.bufferedCF = nil; AA.fl.phase = "release"
        end
        AA.fl.accumulator = 0
        return
    end
    local fl = AA.fl
    fl.accumulator = fl.accumulator + dt
    local intensity, frequency
    local mode = S.AA.FakeLagMode
    if mode == "Static" then
        intensity = S.AA.FakeLagIntensity / 60
        frequency = S.AA.FakeLagFrequency
    elseif mode == "Random" then
        intensity = math.random(2, math.max(S.AA.FakeLagIntensity, 3)) / 60
        frequency = math.random() * 2 + 0.5
    elseif mode == "Adaptive" then
        local v = root.AssemblyLinearVelocity.Magnitude
        local scale = math.clamp(v / 30, 0.3, 1)
        intensity = (S.AA.FakeLagIntensity / 60) * scale
        frequency = S.AA.FakeLagFrequency
    else
        intensity = S.AA.FakeLagIntensity / 60
        frequency = S.AA.FakeLagFrequency
    end
    local cycle = 1 / math.max(frequency, 0.1)
    local lagPhase = math.min(intensity, cycle * 0.7)
    local releasePhT = cycle - lagPhase
    if fl.phase == "release" then
        if fl.accumulator >= releasePhT then
            fl.bufferedCF = root.CFrame
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                hum:ChangeState(Enum.HumanoidStateType.Physics)
            end)
            fl.phase = "lag"; fl.accumulator = 0; fl.pulseCount = fl.pulseCount + 1
        end
    else
        if fl.accumulator >= lagPhase then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            fl.bufferedCF = nil; fl.phase = "release"; fl.accumulator = 0
        else
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end

-- RenderStepped priority Camera+5 — ПЕРЕБИВАЕТ серверные апдейты анимаций
App:BindRender("aa", Enum.RenderPriority.Camera.Value + 5, function(dt)
    local rec = localRec()
    if not rec or not rec.root then return end
    local root = rec.root
    getJoints()
    local anyAA = S.AA.Jitter or S.AA.Desync or S.AA.HideHead
    if not anyAA then
        if AA.rootJ and AA.origRoot and AA.rootJ.C0 ~= AA.origRoot then AA.rootJ.C0 = AA.origRoot end
        if AA.neck and AA.origNeck and AA.neck.C0 ~= AA.origNeck then AA.neck.C0 = AA.origNeck end
        if AA.lowerJ and AA.origLower and AA.lowerJ.C0 ~= AA.origLower then AA.lowerJ.C0 = AA.origLower end
    else
        local jit = computeJitter()
        local des = computeDesync()
        local total = jit + des
        if AA.rootJ and AA.origRoot then AA.rootJ.C0 = AA.origRoot * CFrame.Angles(0, total, 0) end
        if S.AA.Desync and AA.lowerJ and AA.origLower then
            AA.lowerJ.C0 = AA.origLower * CFrame.Angles(0, des * 0.5, 0)
        elseif AA.lowerJ and AA.origLower and AA.lowerJ.C0 ~= AA.origLower then
            AA.lowerJ.C0 = AA.origLower
        end
        if S.AA.HideHead and AA.neck and AA.origNeck then
            local mode = S.AA.HideHeadMode
            if mode == "Down" then
                AA.neck.C0 = AA.origNeck * CFrame.Angles(math.rad(-90), 0, 0)
            elseif mode == "Offset" then
                AA.neck.C0 = AA.origNeck * CFrame.new(0, -1.5, 0) * CFrame.Angles(0, math.rad(180), 0)
            elseif mode == "Spin" then
                AA.neck.C0 = AA.origNeck * CFrame.Angles(0, tick() * 6, 0)
            else -- Back
                AA.neck.C0 = AA.origNeck * CFrame.Angles(0, math.rad(180), 0)
            end
        elseif AA.neck and AA.origNeck and AA.neck.C0 ~= AA.origNeck then
            AA.neck.C0 = AA.origNeck
        end
    end
    if rec.hum then applyFakeLag(dt, root, rec.hum) end
end)

App:Add(function()
    if AA.rootJ and AA.origRoot then pcall(function() AA.rootJ.C0 = AA.origRoot end) end
    if AA.neck and AA.origNeck then pcall(function() AA.neck.C0 = AA.origNeck end) end
    if AA.lowerJ and AA.origLower then pcall(function() AA.lowerJ.C0 = AA.origLower end) end
end)

App:Connect(LP.Idled, function()
    if S.Misc.AntiAFK then
        pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
    end
end)

----------------------------------------------------------------
-- RAGE MODULE (FE-weak only, separate tab, all OFF by default)
-- Честный disclaimer: в современных FE играх большинство этих функций не работают.
----------------------------------------------------------------
local RAGE = {
    lagParts = {},
    flingTargets = {},
    remoteTargets = {},
    lastVoidTP = 0,
    lastRemoteSpam = 0,
}

-- MASS FLING: пытается создать VehicleSeat + BodyVelocity на чужих игроках
-- Работает ТОЛЬКО если клиент имеет network ownership над их character (FE-weak игры)
local function tryFling(rec)
    if not rec or not rec.root or not rec.alive then return end
    pcall(function()
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(
            (math.random() - 0.5) * 500,
            300,
            (math.random() - 0.5) * 500
        )
        bv.Parent = rec.root
        task.delay(0.5, function() pcall(function() bv:Destroy() end) end)
    end)
end

-- VOID TP: телепорт в void (0, -500, 0)
-- Работает только если client-authoritative
local function tryVoidTP(rec)
    if not rec or not rec.root then return end
    pcall(function()
        rec.root.CFrame = CFrame.new(0, -500, 0)
    end)
end

-- REMOTE SPAM: сканер RemoteEvent в ReplicatedStorage
local function scanRemotes()
    RAGE.remoteTargets = {}
    local function scan(inst, depth)
        if depth > 5 then return end
        for _, child in ipairs(inst:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                table.insert(RAGE.remoteTargets, child)
            end
            if child:IsA("Folder") or child:IsA("Model") then
                scan(child, depth + 1)
            end
        end
    end
    pcall(function() scan(ReplicatedStorage, 0) end)
end

local function spamRemotes()
    if #RAGE.remoteTargets == 0 then scanRemotes() end
    for i = 1, math.min(10, #RAGE.remoteTargets) do
        local r = RAGE.remoteTargets[i]
        if r and r.Parent then
            pcall(function()
                if r:IsA("RemoteEvent") then
                    r:FireServer("spam", math.random(1, 1000))
                elseif r:IsA("RemoteFunction") then
                    r:InvokeServer("spam", math.random(1, 1000))
                end
            end)
        end
    end
end

-- LAG MACHINE: создание нагружающих частей в Workspace
-- Работает ТОЛЬКО если клиент может создавать объекты в Workspace (FE-weak)
local function createLagMachine()
    if #RAGE.lagParts > 0 then return end
    local rec = localRec()
    if not rec or not rec.root then return end
    local count = math.clamp(S.Rage.LagMachineCount, 5, 50)
    for i = 1, count do
        pcall(function()
            local p = Instance.new("Part")
            p.Size = Vector3.new(1, 1, 1)
            p.Anchored = false
            p.CanCollide = false
            p.Transparency = 1
            p.CFrame = rec.root.CFrame * CFrame.new(
                (math.random() - 0.5) * 20,
                (math.random() - 0.5) * 20,
                (math.random() - 0.5) * 20
            )
            -- AngularVelocity для нагрузки физики
            local av = Instance.new("AngularVelocity")
            av.AngularVelocity = Vector3.new(
                (math.random() - 0.5) * 100,
                (math.random() - 0.5) * 100,
                (math.random() - 0.5) * 100
            )
            av.MaxTorque = math.huge
            local att = Instance.new("Attachment")
            att.Parent = p
            av.Attachment0 = att
            av.Parent = p
            p.Parent = WS
            table.insert(RAGE.lagParts, p)
        end)
    end
end

local function destroyLagMachine()
    for _, p in ipairs(RAGE.lagParts) do
        pcall(function() p:Destroy() end)
    end
    table.clear(RAGE.lagParts)
end

-- UNANCHOR: попытка SetNetworkOwner на unanchored parts в Workspace
local function tryUnanchor()
    pcall(function()
        local rec = localRec()
        if not rec or not rec.root then return end
        for _, part in ipairs(WS:GetDescendants()) do
            if part:IsA("BasePart") and not part.Anchored and part.Parent ~= rec.char then
                pcall(function() part:SetNetworkOwner(LP) end)
            end
        end
    end)
end

-- Rage Heartbeat loop
App:Connect(RS.Heartbeat, function(dt)
    local now = tick()
    -- Mass Fling
    if S.Rage.MassFling then
        if S.Rage.FlingTarget == "Nearest" then
            local lc = localRec()
            if lc and lc.root then
                local best, bestDist = nil, math.huge
                for plr, rec in pairs(Cache.byPlayer) do
                    if plr ~= LP and rec.alive and rec.root and rec.enemy then
                        local d = (rec.root.Position - lc.root.Position).Magnitude
                        if d < bestDist then bestDist = d; best = rec end
                    end
                end
                if best and bestDist < 50 then tryFling(best) end
            end
        elseif S.Rage.FlingTarget == "All" then
            for plr, rec in pairs(Cache.byPlayer) do
                if plr ~= LP and rec.alive and rec.root and rec.enemy then
                    tryFling(rec)
                end
            end
        end
    end
    -- Void TP
    if S.Rage.VoidTP and now - RAGE.lastVoidTP > S.Rage.VoidTPInterval then
        RAGE.lastVoidTP = now
        local lc = localRec()
        if lc and lc.root then
            local best, bestDist = nil, math.huge
            for plr, rec in pairs(Cache.byPlayer) do
                if plr ~= LP and rec.alive and rec.root and rec.enemy then
                    local d = (rec.root.Position - lc.root.Position).Magnitude
                    if d < bestDist then bestDist = d; best = rec end
                end
            end
            if best and bestDist < 50 then tryVoidTP(best) end
        end
    end
    -- Remote Spam
    if S.Rage.RemoteSpam and now - RAGE.lastRemoteSpam > S.Rage.RemoteSpamInterval then
        RAGE.lastRemoteSpam = now
        spamRemotes()
    end
    -- Lag Machine
    if S.Rage.LagMachine then
        createLagMachine()
    elseif #RAGE.lagParts > 0 then
        destroyLagMachine()
    end
    -- Unanchor
    if S.Rage.Unanchor then
        tryUnanchor()
    end
end)

-- Cleanup rage on unload
App:Add(function()
    destroyLagMachine()
    table.clear(RAGE.flingTargets)
    table.clear(RAGE.remoteTargets)
end)

----------------------------------------------------------------
-- WATERMARK + KEYBIND DISPLAY
----------------------------------------------------------------
local wmText, kdText = nil, nil
if CAP.drawing then
    local ok1, t1 = pcall(function() return Drawing.new("Text") end)
    if ok1 and t1 then wmText = t1; t1.Size=13; t1.Outline=true; t1.Visible=false
        App:Add(function() pcall(function() t1:Remove() end) end)
    end
    local ok2, t2 = pcall(function() return Drawing.new("Text") end)
    if ok2 and t2 then kdText = t2; t2.Size=13; t2.Outline=true; t2.Visible=false
        App:Add(function() pcall(function() t2:Remove() end) end)
    end
end

local stateOf = function(p) return G(p) and "[ON]" or "[OFF]" end
local diagAcc = 0
App:Connect(RS.Heartbeat, function(dt)
    diagAcc += dt
    if diagAcc < 0.25 then return end
    diagAcc = 0
    if wmText then
        wmText.Visible = S.Misc.Watermark
        if S.Misc.Watermark then
            wmText.Text = string.format("unknown v8 // fps %d // proj %d/s // ray %d/s",
                math.floor(Diag.fps), Diag.projRate, Diag.rayRate)
            wmText.Position = Vector2.new(10, 10)
            wmText.Color = Color3.fromRGB(235,235,240)
        end
    end
    if kdText and cam then
        kdText.Visible = S.Misc.KeybindDisplay
        if S.Misc.KeybindDisplay then
            local vp = cam.ViewportSize
            kdText.Position = Vector2.new(10, vp.Y * 0.5 - 120)
            kdText.Color = Color3.fromRGB(235,235,240)
            kdText.Text = string.format(
                "== KEYBINDS ==\n[%s] Aimbot    %s\n[%s] Silent    %s\n[%s] Trigger   %s\n[%s] AntiAim   %s\n[%s] ESP       %s\n[%s] TargetLock %s\n[%s] PANIC     %s",
                G("Keys.Aimbot")  or "?", stateOf("Aimbot.Enabled"),
                G("Keys.Silent")  or "?", stateOf("Aimbot.Silent"),
                G("Keys.Trigger") or "?", stateOf("Trigger.Enabled"),
                G("Keys.AA")      or "?", stateOf("AA.Jitter"),
                G("Keys.ESP")     or "?", stateOf("ESP.Enabled"),
                G("Keys.Lock")    or "?", G("Aimbot.TargetLock") and "[LOCK]" or "[off]",
                G("Keys.Panic")   or "?", "[END]"
            )
        end
    end
end)

----------------------------------------------------------------
-- UI WIRING (Combat / Visuals / Move / AntiAim / Rage / Misc)
----------------------------------------------------------------
-- COMBAT
local tCombat = addTab("combat")
tCombat:Section("aimbot")
tCombat:Toggle("Aimbot (visible)", "Aimbot.Enabled")
tCombat:Toggle("Silent aim",       "Aimbot.Silent")
tCombat:Toggle("Target lock (Q)",  "Aimbot.TargetLock")
tCombat:Toggle("Target hysteresis","Aimbot.Hysteresis")
tCombat:Slider("Hysteresis mult",  "Aimbot.HysteresisMult", 1.0, 2.0, 0.05, "x")
tCombat:Toggle("Wall check",       "Aimbot.WallCheck")
tCombat:Toggle("Only enemies",     "Aimbot.OnlyEnemies")
tCombat:Section("aim tuning")
tCombat:Slider("FOV",              "Aimbot.FOV", 20, 800, 10)
tCombat:Slider("Smoothing",        "Aimbot.Smoothing", 0.01, 1.0, 0.01)
tCombat:Slider("Sensitivity",      "Aimbot.Sensitivity", 0.1, 3.0, 0.05, "x")
tCombat:Slider("Prediction",       "Aimbot.Prediction", 0, 0.5, 0.01, "s")
tCombat:Toggle("Predict gravity",  "Aimbot.PredictGravity")
tCombat:Slider("Hit chance",       "Aimbot.HitChance", 0, 100, 5, "%")
tCombat:Slider("Humanizer",        "Aimbot.HumanizerStrength", 0, 1, 0.05)
tCombat:Dropdown("Bone priority",  "Aimbot.Bone", {"Head", "Torso", "Nearest"})
tCombat:Section("backtrack")
tCombat:Toggle("Backtrack",        "Aimbot.Backtrack")
tCombat:Slider("Backtrack time",   "Aimbot.BacktrackTime", 0.05, 0.5, 0.05, "s")
tCombat:Section("triggerbot")
tCombat:Toggle("TriggerBot",       "Trigger.Enabled")
tCombat:Toggle("Trigger enemies only","Trigger.OnlyEnemies")
tCombat:Toggle("Trigger wall check","Trigger.WallCheck")
tCombat:Slider("Trigger delay",    "Trigger.Delay", 0, 0.5, 0.01, "s")
tCombat:Slider("Trigger cooldown", "Trigger.Cooldown", 0, 0.5, 0.01, "s")
tCombat:Section("keybinds")
tCombat:Keybind("Aimbot key",      "Keys.Aimbot")
tCombat:Keybind("Silent key",      "Keys.Silent")
tCombat:Keybind("Trigger key",     "Keys.Trigger")
tCombat:Keybind("Lock target key", "Keys.Lock")

-- VISUALS
local tVis = addTab("visuals")
tVis:Section("esp")
tVis:Toggle("ESP",            "ESP.Enabled")
tVis:Toggle("Boxes",          "ESP.Boxes")
tVis:Toggle("Health bar",     "ESP.HealthBar")
tVis:Toggle("Snaplines",      "ESP.Snaplines")
tVis:Toggle("Names",          "ESP.Names")
tVis:Toggle("Distance",       "ESP.Distance")
tVis:Toggle("Chams",          "ESP.Chams")
tVis:Toggle("Only enemies",   "ESP.OnlyEnemies")
tVis:Slider("Max distance",   "ESP.MaxDistance", 50, 2000, 50)
tVis:Section("aim visuals")
tVis:Toggle("FOV circle",     "ESP.ShowFOVCircle")
tVis:Toggle("Target indicator","ESP.ShowTargetIndicator")
tVis:Keybind("ESP key",       "Keys.ESP")

-- MOVEMENT
local tMove = addTab("move")
tMove:Section("speed hack")
tMove:Toggle("Speed",           "Move.Speed")
tMove:Dropdown("Mode",          "Move.SpeedMode", {"Walk", "Vel"})
tMove:Slider("Speed value",     "Move.SpeedValue", 16, 200, 1)
tMove:Slider("Velocity cap",    "Move.VelCap", 50, 500, 10)
tMove:Keybind("Speed key",     "Keys.Speed")
tMove:Section("fly")
tMove:Toggle("Fly",             "Move.Fly")
tMove:Slider("Fly speed",       "Move.FlyValue", 20, 200, 5)
tMove:Keybind("Fly key",        "Keys.Fly")
tMove:Section("noclip")
tMove:Toggle("NoClip",          "Move.NoClip")
tMove:Section("jump")
tMove:Toggle("Infinite Jump",   "Move.InfJump")
tMove:Slider("Jump boost",      "Move.InfJumpBoost", 0, 100, 5)
tMove:Slider("Jump cooldown",   "Move.InfJumpCooldown", 0.1, 0.5, 0.02, "s")
tMove:Toggle("Bhop",            "Move.Bhop")

-- ANTIAIM
local tAA = addTab("antiaim")
tAA:Section("jitter")
tAA:Toggle("Jitter",          "AA.Jitter")
tAA:Dropdown("Mode",          "AA.JitterMode", {"Sine","RandomWalk","Flick","Static","CustomPattern"})
tAA:Slider("Jitter angle",    "AA.JitterAngle", 10, 180, 5)
tAA:Slider("Jitter speed",    "AA.JitterSpeed", 1, 30, 1)
tAA:Section("desync")
tAA:Toggle("Desync",          "AA.Desync")
tAA:Dropdown("Mode",          "AA.DesyncMode", {"Static","Spin","Random","Switch","Backwards"})
tAA:Slider("Desync speed",    "AA.DesyncSpeed", 10, 200, 5)
tAA:Slider("Desync strength", "AA.DesyncStrength", 0, 1, 0.05)
tAA:Section("hide head")
tAA:Toggle("Hide head",       "AA.HideHead")
tAA:Dropdown("Mode",          "AA.HideHeadMode", {"Back","Down","Offset","Spin"})
tAA:Section("fake lag")
tAA:Toggle("Fake lag",        "AA.FakeLag")
tAA:Dropdown("Mode",          "AA.FakeLagMode", {"Static","Random","Adaptive"})
tAA:Slider("Intensity",       "AA.FakeLagIntensity", 1, 15, 0.5)
tAA:Slider("Frequency",       "AA.FakeLagFrequency", 1, 5, 0.5, "Hz")
tAA:Keybind("AA key",         "Keys.AA")

-- RAGE (FE-weak only, all OFF by default)
local tRage = addTab("rage")
tRage:Section("⚠ WARNING: FE-weak games only ⚠")
tRage:Label("Most rage features do NOT work in modern FE games.")
tRage:Label("They work only in old/weak games with client-authoritative physics.")
tRage:Label("Use at your own risk — may get you kicked.")
tRage:Section("mass fling")
tRage:Toggle("Mass Fling",       "Rage.MassFling")
tRage:Dropdown("Target",         "Rage.FlingTarget", {"Nearest", "All"})
tRage:Section("void teleport")
tRage:Toggle("Void TP loop",     "Rage.VoidTP")
tRage:Slider("TP interval",      "Rage.VoidTPInterval", 0.1, 2, 0.1, "s")
tRage:Section("remote spam")
tRage:Toggle("Remote spam",      "Rage.RemoteSpam")
tRage:Slider("Spam interval",    "Rage.RemoteSpamInterval", 0.05, 1, 0.05, "s")
tRage:Section("lag machine")
tRage:Toggle("FE Lag Machine",   "Rage.LagMachine")
tRage:Slider("Parts count",      "Rage.LagMachineCount", 5, 50, 5)
tRage:Section("network")
tRage:Toggle("Unanchor parts",   "Rage.Unanchor")

-- MISC
local tMisc = addTab("misc")
tMisc:Section("display")
tMisc:Toggle("Watermark",        "Misc.Watermark")
tMisc:Toggle("Keybind display",  "Misc.KeybindDisplay")
tMisc:Toggle("Anti-AFK",         "Misc.AntiAFK")
tMisc:Keybind("UI key",          "Keys.UI")
tMisc:Section("panic")
tMisc:Keybind("Panic key",       "Keys.Panic")
tMisc:Label("Panic instantly disables: Aimbot, Silent, Trigger, ESP, all Rage")
tMisc:Section("config")
tMisc:Button("save config",      function()
    local ok = saveConfig()
    print("[unknown v8] save:", ok and "ok" or "fail")
end)
tMisc:Button("reload config",    function() loadConfig() end)
tMisc:Button("unload",           function() Unload() end)
tMisc:Label("safe inject: all features start OFF")

----------------------------------------------------------------
-- MINIMIZE + HIDE
----------------------------------------------------------------
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    sidebar.Visible = not minimized
    pages.Visible = not minimized
    main.Size = minimized and UDim2.fromOffset(640, 44) or UDim2.fromOffset(640, 480)
end)
hideBtn.MouseButton1Click:Connect(function() main.Visible = false end)

----------------------------------------------------------------
-- GLOBAL INPUT (UI + feature toggles + PANIC)
----------------------------------------------------------------
App:Connect(UIS.InputBegan, function(input, processed)
    if processed then return end
    -- capturing keybind
    if capturing then
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            P(capturing, input.KeyCode.Name)
        end
        capturing = nil
        return
    end
    local kc = input.KeyCode.Name
    -- PANIC KEY: мгновенное выключение всего опасного
    if kc == G("Keys.Panic") then
        P("Aimbot.Enabled", false, true)
        P("Aimbot.Silent", false, true)
        P("Aimbot.TargetLock", false, true)
        P("Trigger.Enabled", false, true)
        P("ESP.Enabled", false, true)
        P("ESP.Chams", false, true)
        P("Rage.MassFling", false, true)
        P("Rage.VoidTP", false, true)
        P("Rage.RemoteSpam", false, true)
        P("Rage.LagMachine", false, true)
        P("Rage.Unanchor", false, true)
        AIM.current = nil; AIM.prevPlayer = nil; AIM.lockEnabled = false
        print("[unknown v8] PANIC — all features disabled")
        return
    end
    if kc == G("Keys.UI")      then main.Visible = not main.Visible; return end
    if kc == G("Keys.Aimbot")  and G("Keys.Aimbot")  ~= "" then P("Aimbot.Enabled", not G("Aimbot.Enabled")) end
    if kc == G("Keys.Silent")  and G("Keys.Silent")  ~= "" then P("Aimbot.Silent",  not G("Aimbot.Silent")) end
    if kc == G("Keys.Trigger") and G("Keys.Trigger") ~= "" then P("Trigger.Enabled", not G("Trigger.Enabled")) end
    if kc == G("Keys.Fly")     and G("Keys.Fly")     ~= "" then P("Move.Fly",       not G("Move.Fly")) end
    if kc == G("Keys.Speed")   and G("Keys.Speed")   ~= "" then P("Move.Speed",     not G("Move.Speed")) end
    if kc == G("Keys.ESP")     and G("Keys.ESP")     ~= "" then P("ESP.Enabled",    not G("ESP.Enabled")) end
    if kc == G("Keys.AA")      and G("Keys.AA")      ~= "" then
        local newState = not G("AA.Jitter")
        P("AA.Jitter", newState); P("AA.Desync", newState)
    end
    if kc == G("Keys.Lock")    and G("Keys.Lock")    ~= "" then
        -- Q-toggle пишет напрямую в Aimbot.TargetLock (единый источник правды)
        if AIM.current then
            P("Aimbot.TargetLock", not G("Aimbot.TargetLock"))
        end
    end
end)

----------------------------------------------------------------
-- CHARACTER ADDED — full reset всех модулей
----------------------------------------------------------------
App:Connect(LP.CharacterAdded, function()
    AIM.current = nil; AIM.prevPlayer = nil
    table.clear(velEMA); table.clear(velTS); table.clear(btHistory)
    destroyLagMachine()
    destroyFly()
    for part, can in pairs(MV.origCanCollide) do
        if part.Parent then pcall(function() part.CanCollide = can end) end
    end
    table.clear(MV.origCanCollide)
    MV.origWalk = nil; MV.ncOn = false
    AA.rootJ=nil; AA.neck=nil; AA.lowerJ=nil
    AA.origRoot=nil; AA.origNeck=nil; AA.origLower=nil
    AA.fl.phase="release"; AA.fl.accumulator=0; AA.fl.bufferedCF=nil
end)

----------------------------------------------------------------
-- LOAD + SAFE INJECT + STARTUP
----------------------------------------------------------------
loadConfig()
-- SAFE INJECT: все опасные функции OFF при загрузке (UI показывает состояние)
for _, path in ipairs({
    "Aimbot.Enabled","Aimbot.Silent","Aimbot.TargetLock","Aimbot.Backtrack",
    "Trigger.Enabled",
    "ESP.Enabled","ESP.Chams",
    "Move.Speed","Move.Fly","Move.NoClip","Move.InfJump","Move.Bhop",
    "AA.Jitter","AA.Desync","AA.HideHead","AA.FakeLag",
    "Rage.MassFling","Rage.VoidTP","Rage.RemoteSpam","Rage.LagMachine","Rage.Unanchor",
}) do
    P(path, false, true)
end
-- refresh UI после safe inject
for path, list in pairs(UIREFS) do
    for _, fn in ipairs(list) do pcall(fn, G(path)) end
end

----------------------------------------------------------------
-- UNLOAD (full cleanup, no garbage left)
----------------------------------------------------------------
function Unload()
    -- 1. destroy all scopes (connections, instances, render binds)
    for _, s in ipairs(scopes) do s:Destroy() end
    table.clear(scopes)
    -- 2. restore movement state
    local rec = localRec()
    if rec and rec.hum and MV.origWalk then pcall(function() rec.hum.WalkSpeed = MV.origWalk end) end
    for part, can in pairs(MV.origCanCollide) do
        if part.Parent then pcall(function() part.CanCollide = can end) end
    end
    -- 3. destroy fly bodymovers
    destroyFly()
    -- 4. destroy rage parts
    destroyLagMachine()
    -- 5. release all ESP drawings
    for _, r in pairs(Cache.byPlayer) do releaseViz(r) end
    for _, list in pairs(Pool.free) do
        for _, o in ipairs(list) do pcall(function() o:Remove() end) end
    end
    Pool.count = 0
    -- 6. remove watermark + keybind display
    if wmText then pcall(function() wmText:Remove() end) end
    if kdText then pcall(function() kdText:Remove() end) end
    if fovCircle then pcall(function() fovCircle:Remove() end) end
    if tgtCircle then pcall(function() tgtCircle:Remove() end) end
    -- 7. clear caches
    table.clear(velEMA); table.clear(velTS); table.clear(btHistory)
    table.clear(MV.origCanCollide); table.clear(RAGE.lagParts)
    table.clear(RAGE.flingTargets); table.clear(RAGE.remoteTargets)
    -- 8. clear env handle
    ENV.__ABYSS = nil
    print("[unknown v8] UNLOADED — all cleanup done")
end
ENV.__ABYSS = { Unload = Unload }
print("[unknown v8] ready — safe inject: all features OFF, panic key = End")
