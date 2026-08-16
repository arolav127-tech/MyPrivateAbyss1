local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local LP = Players.LocalPlayer
if not LP then
    LP = Players.PlayerAdded:Wait()
end

local ENV = (type(getgenv) == "function" and getgenv()) or _G
if type(ENV.__ABYSS_FINAL) == "table" and type(ENV.__ABYSS_FINAL.Unload) == "function" then
    pcall(ENV.__ABYSS_FINAL.Unload)
end
ENV.__ABYSS_FINAL = nil

local unloadStarted = false
local unloadDone = false
local Runtime = {unloading = false, dead = false}

local function safeWait(seconds)
    if type(task) == "table" and type(task.wait) == "function" then
        task.wait(seconds)
        return
    end
    if type(wait) == "function" then
        wait(seconds)
    end
end

local function safeSpawn(fn)
    if type(task) == "table" and type(task.spawn) == "function" then
        task.spawn(fn)
        return
    end
    if type(spawn) == "function" then
        spawn(fn)
        return
    end
    fn()
end

local function clearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local Scopes = {}
local Scope = {}
Scope.__index = Scope

function Scope.new(name)
    local self = setmetatable({}, Scope)
    self.name = name or "scope"
    self.alive = true
    self.conns = {}
    self.insts = {}
    self.fns = {}
    self.renders = {}
    self.timers = {}
    self.timerId = 0
    self.renderId = 0
    Scopes[#Scopes + 1] = self
    return self
end

function Scope:Destroy()
    if not self.alive then return end
    self.alive = false

    for id in pairs(self.timers) do
        self.timers[id] = false
    end

    for i = #self.conns, 1, -1 do
        local c = self.conns[i]
        if c then
            pcall(function()
                if c.Connected then
                    c:Disconnect()
                end
            end)
        end
        self.conns[i] = nil
    end

    for i = #self.renders, 1, -1 do
        local nm = self.renders[i]
        if nm then
            pcall(RunService.UnbindFromRenderStep, RunService, nm)
        end
        self.renders[i] = nil
    end

    for i = #self.fns, 1, -1 do
        pcall(self.fns[i])
        self.fns[i] = nil
    end

    for i = #self.insts, 1, -1 do
        local inst = self.insts[i]
        if inst then
            pcall(function()
                inst:Destroy()
            end)
        end
        self.insts[i] = nil
    end

    for i = #Scopes, 1, -1 do
        if Scopes[i] == self then
            table.remove(Scopes, i)
            break
        end
    end
end

function Scope:Connect(sig, fn)
    if not self.alive or unloadStarted then return nil end
    local c = sig:Connect(fn)
    self.conns[#self.conns + 1] = c
    return c
end

function Scope:Give(inst)
    if not self.alive or unloadStarted then
        pcall(function()
            inst:Destroy()
        end)
        return inst
    end
    self.insts[#self.insts + 1] = inst
    return inst
end

function Scope:Add(fn)
    if not self.alive or unloadStarted then
        pcall(fn)
        return
    end
    self.fns[#self.fns + 1] = fn
end

function Scope:BindRender(key, prio, fn)
    if not self.alive or unloadStarted then return end

    self.renderId = self.renderId + 1
    local fullName = string.format("ABYSSFINAL_%s_%d", key, self.renderId)

    local ok = pcall(function()
        RunService:BindToRenderStep(fullName, prio, function(dt)
            if not self.alive or unloadStarted or unloadDone then
                return
            end
            pcall(fn, dt)
        end)
    end)

    if ok then
        self.renders[#self.renders + 1] = fullName
    end
end

function Scope:Schedule(seconds, fn)
    if not self.alive or unloadStarted then return end

    self.timerId = self.timerId + 1
    local id = self.timerId
    self.timers[id] = true

    local function cb()
        if not self.alive or unloadStarted or unloadDone then
            return
        end
        if self.timers[id] ~= true then
            return
        end
        self.timers[id] = nil
        pcall(fn)
    end

    if type(task) == "table" and type(task.delay) == "function" then
        task.delay(seconds, cb)
    elseif type(delay) == "function" then
        delay(seconds, cb)
    else
        safeSpawn(function()
            safeWait(seconds)
            cb()
        end)
    end
end

local App = Scope.new("app")

local S = {
    Aimbot = {
        Enabled = false,
        Silent = false,
        FOV = 120,
        Smoothing = 5,
        Prediction = 0.12,
        WallCheck = true,
        OnlyEnemies = true,
        ShowFOV = true,
        HitChance = 100,
        Humanizer = 0.15,
        TargetPart = "Head",
    },
    Trigger = {
        Enabled = false,
        OnlyEnemies = true,
        WallCheck = true,
        Cooldown = 0.15,
    },
    ESP = {
        Enabled = false,
        Boxes = true,
        HealthBar = true,
        Snaplines = false,
        Names = true,
        Distance = false,
        Chams = false,
        OnlyEnemies = true,
        MaxDistance = 500,
    },
    Move = {
        Speed = false,
        SpeedMode = "Walk",
        SpeedValue = 50,
        Fly = false,
        FlyValue = 60,
        NoClip = false,
        InfJump = false,
        Bhop = false,
    },
    AA = {
        Jitter = false,
        JitterAngle = 40,
        Desync = false,
        DesyncMode = "Spin",
        DesyncSpeed = 30,
        HideHead = false,
    },
    Rage = {
        Enabled = false,
        MassFling = false,
        FlingTarget = "Near",
        VoidTP = false,
        Spinbot = false,
        SpinSpeed = 25,
    },
    Misc = {
        Watermark = true,
        AntiAFK = true,
        PanicKey = "End",
    },
    Keys = {
        UI = "RightShift",
        Aimbot = "X",
        Silent = "B",
        Fly = "F",
        Speed = "V",
    },
}

local UIRefs = {}
local saveQueued = false
local CFGPATH = "AbyssFW/abyss_final.json"

local function fsOk()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
        and type(makefolder) == "function"
        and type(isfolder) == "function"
end

local function saveConfig()
    if not fsOk() then return end
    pcall(function()
        if not isfolder("AbyssFW") then
            makefolder("AbyssFW")
        end
        writefile(CFGPATH, HttpService:JSONEncode(S))
    end)
end

local function queueSave()
    if saveQueued or unloadStarted or unloadDone or not App.alive or not fsOk() then
        return
    end

    saveQueued = true
    App:Schedule(0.35, function()
        saveQueued = false
        if not unloadStarted and not unloadDone then
            saveConfig()
        end
    end)
end

local function G(path)
    local g, k = path:match("^([%w_]+)%.([%w_]+)$")
    local group = S[g]
    if group then
        return group[k]
    end
    return nil
end

local function Set(path, value, skipSave)
    if unloadStarted or unloadDone or not App.alive then
        return
    end

    local g, k = path:match("^([%w_]+)%.([%w_]+)$")
    local group = S[g]
    if group then
        group[k] = value
    end

    for _, fn in ipairs(UIRefs[path] or {}) do
        pcall(fn, value)
    end

    if not skipSave then
        queueSave()
    end
end

local function loadConfig()
    if not fsOk() or not isfile(CFGPATH) then return end

    local ok, txt = pcall(readfile, CFGPATH)
    if not ok or type(txt) ~= "string" then return end

    local ok2, data = pcall(function()
        return HttpService:JSONDecode(txt)
    end)
    if not ok2 or type(data) ~= "table" then return end

    for groupName, groupData in pairs(S) do
        if type(data[groupName]) == "table" then
            for key, defaultValue in pairs(groupData) do
                local incoming = data[groupName][key]
                if incoming ~= nil and type(incoming) == type(defaultValue) then
                    groupData[key] = incoming
                end
            end
        end
    end
end

loadConfig()

local destroyFly, destroyRage, restoreNoClip, restoreAA, panic, Unload, BuildGUI, paintAllUI

local cam = Workspace.CurrentCamera
App:Connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    cam = Workspace.CurrentCamera
end)

local Cache = {byPlayer = {}}

local function localRec()
    return Cache.byPlayer[LP]
end

local function recomputeEnemy(rec)
    if rec.plr == LP then
        rec.enemy = false
        return
    end

    local myTeam = LP.Team
    local theirTeam = rec.plr.Team

    if not myTeam or not theirTeam then
        rec.enemy = true
        return
    end

    if LP.Neutral or rec.plr.Neutral then
        rec.enemy = true
        return
    end

    rec.enemy = (theirTeam ~= myTeam)
end

local function recomputeAllEnemies()
    for _, rec in pairs(Cache.byPlayer) do
        recomputeEnemy(rec)
    end
end

local function clearChar(rec)
    if rec.charScope then
        rec.charScope:Destroy()
        rec.charScope = nil
    end

    rec.char = nil
    rec.hum = nil
    rec.root = nil
    rec.head = nil
    rec.alive = false
    rec.visTime = 0
    rec.visPos = nil
    rec.visVisible = false
end

local function onCharAdded(rec, char)
    if not char or not char.Parent then return end
    clearChar(rec)

    rec.char = char
    rec.charScope = Scope.new("char:" .. rec.plr.Name)
    rec.hum = char:FindFirstChildOfClass("Humanoid")
    rec.root = char:FindFirstChild("HumanoidRootPart")
    rec.head = char:FindFirstChild("Head")
    rec.alive = (rec.hum ~= nil and rec.hum.Health > 0)

    if rec.hum then
        rec.charScope:Connect(rec.hum.Died, function()
            rec.alive = false
        end)

        rec.charScope:Connect(rec.hum:GetPropertyChangedSignal("Health"), function()
            rec.alive = rec.hum.Health > 0
        end)
    end

    recomputeEnemy(rec)
end

local function wire(plr)
    if not plr or not plr.Parent then return end

    local scope = Scope.new("plr:" .. plr.Name)

    local rec = {
        plr = plr,
        scope = scope,
        charScope = nil,
        char = nil,
        hum = nil,
        root = nil,
        head = nil,
        alive = false,
        enemy = true,
        visTime = 0,
        visPos = nil,
        visVisible = false,
    }

    Cache.byPlayer[plr] = rec

    scope:Connect(plr.CharacterAdded, function(c)
        onCharAdded(rec, c)
    end)

    scope:Connect(plr.CharacterRemoving, function()
        clearChar(rec)
    end)

    scope:Connect(plr:GetPropertyChangedSignal("Team"), function()
        recomputeAllEnemies()
    end)

    if plr.Character then
        onCharAdded(rec, plr.Character)
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    wire(p)
end

App:Connect(Players.PlayerAdded, wire)

App:Connect(Players.PlayerRemoving, function(plr)
    local rec = Cache.byPlayer[plr]
    if not rec then return end

    clearChar(rec)

    if rec.scope then
        rec.scope:Destroy()
    end

    Cache.byPlayer[plr] = nil
end)

App:Connect(LP:GetPropertyChangedSignal("Team"), function()
    recomputeAllEnemies()
end)

local drawingAvailable = false
do
    local ok = pcall(function()
        if type(Drawing) == "table" and type(Drawing.new) == "function" then
            local test = Drawing.new("Text")
            test.Visible = false
            test:Remove()
            drawingAvailable = true
        end
    end)
    if not ok then
        drawingAvailable = false
    end
end

local Pool = {free = {Square = {}, Line = {}, Text = {}}}

local function acquire(kind)
    if not drawingAvailable then return nil end

    local list = Pool.free[kind]
    local o = table.remove(list)

    if not o then
        local ok, d = pcall(Drawing.new, kind)
        if not ok then return nil end
        o = d
    end

    pcall(function()
        o.Visible = false
    end)

    return o
end

local function release(o, kind)
    if not o then return end
    pcall(function()
        o.Visible = false
    end)
    Pool.free[kind][#Pool.free[kind] + 1] = o
end

local function nukePool()
    for _, list in pairs(Pool.free) do
        for i = #list, 1, -1 do
            local o = list[i]
            if o then
                pcall(function()
                    o:Remove()
                end)
            end
            list[i] = nil
        end
    end
end

if drawingAvailable then
    for _ = 1, 32 do
        local ok, d = pcall(Drawing.new, "Square")
        if ok then
            d.Visible = false
            Pool.free.Square[#Pool.free.Square + 1] = d
        end
    end

    for _ = 1, 24 do
        local ok, d = pcall(Drawing.new, "Line")
        if ok then
            d.Visible = false
            Pool.free.Line[#Pool.free.Line + 1] = d
        end
    end

    for _ = 1, 48 do
        local ok, d = pcall(Drawing.new, "Text")
        if ok then
            d.Visible = false
            Pool.free.Text[#Pool.free.Text + 1] = d
        end
    end
end

local GUI_NAME = "abyss_final_ui"
local guiEnabled = false
local gui = nil
local main = nil
local GUIScope = nil

local COL = {
    bg = Color3.fromRGB(10, 10, 12),
    panel = Color3.fromRGB(17, 17, 20),
    elem = Color3.fromRGB(24, 24, 28),
    stroke = Color3.fromRGB(42, 42, 50),
    text = Color3.fromRGB(235, 235, 240),
    muted = Color3.fromRGB(120, 120, 130),
    accent = Color3.fromRGB(255, 60, 60),
    off = Color3.fromRGB(70, 70, 78),
}

local function new(cls, props, parent)
    local o = Instance.new(cls)
    if props then
        for k, v in pairs(props) do
            o[k] = v
        end
    end
    if parent then
        o.Parent = parent
    end
    return o
end

local function corner(p, r)
    return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, p)
end

local function stroke(p, c, t)
    return new("UIStroke", {Color = c or COL.stroke, Thickness = t or 1}, p)
end

local function cleanupCoreGui()
    pcall(function()
        local existing = CoreGui:FindFirstChild(GUI_NAME)
        if existing then
            existing:Destroy()
        end

        for _, child in ipairs(CoreGui:GetChildren()) do
            if child:IsA("ScreenGui") then
                local marked = false
                pcall(function()
                    marked = child:GetAttribute("AbyssUI")
                end)

                if marked or child.Name == GUI_NAME or child.Name == "abyss_fixed_ui" or child.Name == "abyss_fixed_ui_v2" or child.Name == "abyss_fixed_ui_v3" then
                    child:Destroy()
                end
            end
        end
    end)
end

paintAllUI = function()
    for path, list in pairs(UIRefs) do
        local value = G(path)
        for _, fn in ipairs(list) do
            pcall(fn, value)
        end
    end
end

BuildGUI = function()
    if unloadStarted or unloadDone or not App.alive then return end

    if GUIScope then
        GUIScope:Destroy()
        GUIScope = nil
    end

    cleanupCoreGui()

    for k in pairs(UIRefs) do
        UIRefs[k] = nil
    end

    GUIScope = Scope.new("gui")

    gui = GUIScope:Give(Instance.new("ScreenGui"))
    gui.Name = GUI_NAME
    gui.ResetOnSpawn = true
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 9999
    gui.Enabled = true
    pcall(function()
        gui:SetAttribute("AbyssUI", true)
    end)

    local parentOk = pcall(function()
        gui.Parent = CoreGui
    end)

    if not parentOk then
        GUIScope:Destroy()
        GUIScope = nil
        gui = nil
        main = nil
        guiEnabled = false
        return
    end

    guiEnabled = true

    main = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(560, 460),
        BackgroundColor3 = COL.bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = true,
    }, gui)
    corner(main, 10)
    stroke(main)

    local topbar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = COL.panel,
        BorderSizePixel = 0,
    }, main)
    corner(topbar, 10)
    stroke(topbar)

    new("Frame", {
        Size = UDim2.fromOffset(3, 14),
        Position = UDim2.fromOffset(12, 15),
        BackgroundColor3 = COL.accent,
        BorderSizePixel = 0,
    }, topbar)

    new("TextLabel", {
        Size = UDim2.fromOffset(180, 20),
        Position = UDim2.fromOffset(22, 12),
        BackgroundTransparency = 1,
        Text = "abyss_final",
        Font = Enum.Font.Code,
        TextSize = 16,
        TextColor3 = COL.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, topbar)

    local hideBtn = new("TextButton", {
        Size = UDim2.fromOffset(24, 24),
        Position = UDim2.new(1, -32, 0.5, -12),
        BackgroundColor3 = COL.elem,
        BorderSizePixel = 0,
        Text = "x",
        TextColor3 = COL.text,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false,
    }, topbar)
    corner(hideBtn, 6)

    local sidebar = new("Frame", {
        Size = UDim2.new(0, 120, 1, -52),
        Position = UDim2.fromOffset(8, 48),
        BackgroundColor3 = COL.panel,
        BorderSizePixel = 0,
    }, main)
    corner(sidebar, 8)

    local tabList = new("ScrollingFrame", {
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.fromOffset(4, 4),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(),
    }, sidebar)

    local tabLayout = new("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, tabList)

    GUIScope:Connect(tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        if not tabList.Parent then return end
        tabList.CanvasSize = UDim2.fromOffset(0, tabLayout.AbsoluteContentSize.Y + 4)
    end)

    local pages = new("Frame", {
        Size = UDim2.new(1, -132, 1, -52),
        Position = UDim2.fromOffset(128, 48),
        BackgroundTransparency = 1,
    }, main)

    local tabs = {}
    local selectedTab = nil
    local order = 0

    local function nextOrder()
        order = order + 1
        return order
    end

    local function selectTab(rec)
        selectedTab = rec
        for _, t in ipairs(tabs) do
            local selected = (t == rec)
            t.page.Visible = selected
            t.btn.BackgroundColor3 = selected and COL.elem or COL.panel
            t.btn.TextColor3 = selected and COL.text or COL.muted
        end
    end

    local function addTab(name)
        local page = new("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = COL.stroke,
            Visible = false,
            CanvasSize = UDim2.new(),
        }, pages)

        local layout = new("UIListLayout", {
            Padding = UDim.new(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, page)

        new("UIPadding", {
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 6),
        }, page)

        GUIScope:Connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            if not page.Parent then return end
            page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 16)
        end)

        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = COL.panel,
            BorderSizePixel = 0,
            Text = name,
            TextColor3 = COL.muted,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            AutoButtonColor = false,
            LayoutOrder = nextOrder(),
        }, tabList)
        corner(btn, 6)

        local rec = {name = name, page = page, btn = btn}
        table.insert(tabs, rec)

        GUIScope:Connect(btn.MouseButton1Click, function()
            selectTab(rec)
        end)

        if not selectedTab then
            selectTab(rec)
        end

        local Tab = {}

        local function row(h)
            local f = new("Frame", {
                Size = UDim2.new(1, 0, 0, h),
                BackgroundColor3 = COL.elem,
                BorderSizePixel = 0,
                LayoutOrder = nextOrder(),
            }, page)
            corner(f, 7)
            stroke(f)
            return f
        end

        local function rtitle(f, t)
            return new("TextLabel", {
                Size = UDim2.new(0.62, -12, 1, 0),
                Position = UDim2.fromOffset(10, 0),
                BackgroundTransparency = 1,
                Text = t,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = COL.text,
                Font = Enum.Font.Gotham,
                TextSize = 13,
            }, f)
        end

        local function addClick(f, cb)
            local o = new("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 5,
            }, f)
            GUIScope:Connect(o.MouseButton1Click, function()
                pcall(cb)
            end)
            return o
        end

        function Tab:Section(t)
            order = order + 1
            new("TextLabel", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Text = t,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = COL.muted,
                Font = Enum.Font.GothamSemibold,
                TextSize = 11,
                LayoutOrder = order,
            }, page)
        end

        function Tab:Label(t)
            local f = row(26)
            local l = rtitle(f, t)
            l.Size = UDim2.new(1, -14, 1, 0)
            l.TextColor3 = COL.muted
            return {
                Set = function(_, v)
                    if l.Parent then
                        l.Text = tostring(v)
                    end
                end,
            }
        end

        function Tab:Button(o)
            o = o or {}
            local f = row(30)
            local l = rtitle(f, o.Name or "Button")
            l.Size = UDim2.new(1, -14, 1, 0)
            addClick(f, o.Callback or function() end)
            return {
                Set = function(_, v)
                    if l.Parent then
                        l.Text = tostring(v)
                    end
                end,
            }
        end

        function Tab:Toggle(o)
            o = o or {}
            local stateValue = G(o.Path) == true
            local f = row(30)
            rtitle(f, o.Name)

            local sw = new("Frame", {
                Size = UDim2.fromOffset(34, 16),
                Position = UDim2.new(1, -42, 0.5, -8),
                BackgroundColor3 = COL.bg,
                BorderSizePixel = 0,
            }, f)
            corner(sw, 8)
            stroke(sw)

            local ind = new("Frame", {
                Size = UDim2.fromOffset(10, 10),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = stateValue and COL.accent or COL.off,
                BorderSizePixel = 0,
            }, sw)
            corner(ind, 6)

            local function paint(v)
                if not ind.Parent then return end
                v = v == true
                ind.BackgroundColor3 = v and COL.accent or COL.off
                ind.Position = v and UDim2.new(1, -13, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
            end

            UIRefs[o.Path] = UIRefs[o.Path] or {}
            table.insert(UIRefs[o.Path], paint)
            paint(stateValue)

            addClick(f, function()
                Set(o.Path, not G(o.Path))
            end)

            return {Set = function(_, v) paint(v) end}
        end

        function Tab:Slider(o)
            o = o or {}
            local min = o.Min or 0
            local max = o.Max or 100
            local step = o.Step or 1
            local val = math.clamp(tonumber(G(o.Path)) or min, min, max)

            local f = row(42)
            rtitle(f, o.Name)

            local info = new("TextLabel", {
                Size = UDim2.fromOffset(80, 14),
                Position = UDim2.new(1, -90, 0, 4),
                BackgroundTransparency = 1,
                TextColor3 = COL.text,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Right,
            }, f)

            local track = new("Frame", {
                Size = UDim2.new(1, -20, 0, 4),
                Position = UDim2.fromOffset(10, 30),
                BackgroundColor3 = COL.off,
                BorderSizePixel = 0,
            }, f)
            corner(track, 2)

            local fill = new("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = COL.accent,
                BorderSizePixel = 0,
            }, track)
            corner(fill, 2)

            local function paint(v)
                if not fill.Parent or not info.Parent then return end
                v = tonumber(v) or min
                local r = (max > min) and ((v - min) / (max - min)) or 0
                fill.Size = UDim2.new(math.clamp(r, 0, 1), 0, 1, 0)
                info.Text = tostring(v) .. (o.Suffix or "")
            end

            UIRefs[o.Path] = UIRefs[o.Path] or {}
            table.insert(UIRefs[o.Path], paint)
            paint(val)

            local dragging = false

            local function fromX(x)
                if not track.Parent then return end
                local w = math.max(track.AbsoluteSize.X, 1)
                local r = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
                local v = min + (max - min) * r
                v = math.floor(v / step + 0.5) * step
                Set(o.Path, v)
            end

            GUIScope:Connect(track.InputBegan, function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    fromX(i.Position.X)
                end
            end)

            GUIScope:Connect(UIS.InputChanged, function(i)
                if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                    fromX(i.Position.X)
                end
            end)

            GUIScope:Connect(UIS.InputEnded, function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end)

            return {Set = function(_, v) paint(v) end}
        end

        function Tab:Dropdown(o)
            o = o or {}
            local options = o.Options or {}
            local current = G(o.Path) or options[1]

            local f = row(30)
            rtitle(f, o.Name)

            local sel = new("TextLabel", {
                Size = UDim2.new(0.34, -20, 1, 0),
                Position = UDim2.new(0.66, -14, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(current),
                TextColor3 = COL.muted,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
            }, f)

            local list = new("Frame", {
                Size = UDim2.new(1, -8, 0, 0),
                Position = UDim2.new(0, 4, 1, 2),
                BackgroundColor3 = COL.panel,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Visible = false,
                ZIndex = 30,
            }, f)
            corner(list, 7)
            stroke(list)

            new("UIListLayout", {
                Padding = UDim.new(0, 3),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, list)

            local open = false

            for _, opt in ipairs(options) do
                local b = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 24),
                    BackgroundColor3 = COL.elem,
                    BorderSizePixel = 0,
                    Text = "  " .. opt,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextColor3 = COL.text,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    AutoButtonColor = false,
                    ZIndex = 31,
                }, list)
                corner(b, 5)

                GUIScope:Connect(b.MouseButton1Click, function()
                    if not sel.Parent then return end
                    current = opt
                    sel.Text = tostring(opt)
                    Set(o.Path, opt)
                    open = false
                    list.Visible = false
                    list.Size = UDim2.new(1, -8, 0, 0)
                end)
            end

            addClick(f, function()
                if not list.Parent then return end
                open = not open
                list.Visible = open
                if open then
                    list.Size = UDim2.new(1, -8, 0, math.clamp(#options * 27 + 8, 28, 190))
                else
                    list.Size = UDim2.new(1, -8, 0, 0)
                end
            end)

            return {
                Set = function(_, v)
                    if sel.Parent then
                        sel.Text = tostring(v)
                    end
                end,
            }
        end

        function Tab:Keybind(o)
            o = o or {}
            local current = G(o.Path) or "None"

            local f = row(28)
            rtitle(f, o.Name)

            local kb = new("TextButton", {
                Size = UDim2.fromOffset(76, 20),
                Position = UDim2.new(1, -84, 0.5, -10),
                BackgroundColor3 = COL.panel,
                BorderSizePixel = 0,
                Text = tostring(current),
                TextColor3 = COL.text,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                AutoButtonColor = false,
            }, f)
            corner(kb, 5)
            stroke(kb)

            local capturing = false

            GUIScope:Connect(kb.MouseButton1Click, function()
                capturing = true
                kb.Text = "press"
            end)

            GUIScope:Connect(UIS.InputBegan, function(input)
                if not kb.Parent then return end
                if capturing and input.KeyCode ~= Enum.KeyCode.Unknown then
                    capturing = false
                    local n = input.KeyCode.Name
                    kb.Text = n
                    Set(o.Path, n)
                end
            end)

            return {
                Set = function(_, v)
                    if kb.Parent then
                        kb.Text = tostring(v)
                    end
                end,
            }
        end

        return Tab
    end

    local tCombat = addTab("combat")
    tCombat:Section("aimbot")
    tCombat:Toggle({Name = "Aimbot", Path = "Aimbot.Enabled"})
    tCombat:Toggle({Name = "Silent Aim", Path = "Aimbot.Silent"})
    tCombat:Toggle({Name = "Wall Check", Path = "Aimbot.WallCheck"})
    tCombat:Toggle({Name = "Only Enemies", Path = "Aimbot.OnlyEnemies"})
    tCombat:Toggle({Name = "FOV Circle", Path = "Aimbot.ShowFOV"})
    tCombat:Dropdown({Name = "Target Part", Path = "Aimbot.TargetPart", Options = {"Head", "UpperTorso", "HumanoidRootPart", "Torso"}})
    tCombat:Slider({Name = "FOV", Path = "Aimbot.FOV", Min = 20, Max = 600, Step = 10})
    tCombat:Slider({Name = "Smoothing", Path = "Aimbot.Smoothing", Min = 1, Max = 20, Step = 1})
    tCombat:Slider({Name = "Prediction", Path = "Aimbot.Prediction", Min = 0, Max = 0.5, Step = 0.01})
    tCombat:Slider({Name = "Hit Chance", Path = "Aimbot.HitChance", Min = 0, Max = 100, Step = 1, Suffix = "%"})
    tCombat:Slider({Name = "Humanizer", Path = "Aimbot.Humanizer", Min = 0, Max = 2, Step = 0.05})
    tCombat:Section("triggerbot")
    tCombat:Toggle({Name = "TriggerBot", Path = "Trigger.Enabled"})
    tCombat:Toggle({Name = "Trigger Wall Check", Path = "Trigger.WallCheck"})
    tCombat:Toggle({Name = "Trigger Only Enemies", Path = "Trigger.OnlyEnemies"})
    tCombat:Slider({Name = "Cooldown", Path = "Trigger.Cooldown", Min = 0, Max = 0.5, Step = 0.01})

    local tVis = addTab("visuals")
    tVis:Section("esp")
    tVis:Toggle({Name = "ESP", Path = "ESP.Enabled"})
    tVis:Toggle({Name = "Boxes", Path = "ESP.Boxes"})
    tVis:Toggle({Name = "Health Bar", Path = "ESP.HealthBar"})
    tVis:Toggle({Name = "Snaplines", Path = "ESP.Snaplines"})
    tVis:Toggle({Name = "Names", Path = "ESP.Names"})
    tVis:Toggle({Name = "Distance", Path = "ESP.Distance"})
    tVis:Toggle({Name = "Chams", Path = "ESP.Chams"})
    tVis:Toggle({Name = "Only Enemies", Path = "ESP.OnlyEnemies"})
    tVis:Slider({Name = "Max Distance", Path = "ESP.MaxDistance", Min = 50, Max = 2000, Step = 50})

    local tMove = addTab("move")
    tMove:Section("speed")
    tMove:Toggle({Name = "Speed", Path = "Move.Speed"})
    tMove:Dropdown({Name = "Mode", Path = "Move.SpeedMode", Options = {"Walk", "Vel"}})
    tMove:Slider({Name = "Speed", Path = "Move.SpeedValue", Min = 16, Max = 200, Step = 1})
    tMove:Section("fly")
    tMove:Toggle({Name = "Fly", Path = "Move.Fly"})
    tMove:Slider({Name = "Fly Speed", Path = "Move.FlyValue", Min = 20, Max = 200, Step = 5})
    tMove:Section("other")
    tMove:Toggle({Name = "NoClip", Path = "Move.NoClip"})
    tMove:Toggle({Name = "Inf Jump", Path = "Move.InfJump"})
    tMove:Toggle({Name = "Bhop", Path = "Move.Bhop"})

    local tAA = addTab("antiaim")
    tAA:Section("angles")
    tAA:Toggle({Name = "Jitter", Path = "AA.Jitter"})
    tAA:Slider({Name = "Jitter Angle", Path = "AA.JitterAngle", Min = 10, Max = 180, Step = 5})
    tAA:Toggle({Name = "Desync", Path = "AA.Desync"})
    tAA:Dropdown({Name = "Desync Mode", Path = "AA.DesyncMode", Options = {"Spin", "Static", "Backwards"}})
    tAA:Toggle({Name = "Hide Head", Path = "AA.HideHead"})

    local tRage = addTab("rage")
    tRage:Section("master")
    tRage:Toggle({Name = "Rage Master", Path = "Rage.Enabled"})
    tRage:Toggle({Name = "Mass Fling", Path = "Rage.MassFling"})
    tRage:Dropdown({Name = "Fling Target", Path = "Rage.FlingTarget", Options = {"Near", "All"}})
    tRage:Toggle({Name = "Void TP", Path = "Rage.VoidTP"})
    tRage:Toggle({Name = "Spinbot", Path = "Rage.Spinbot"})
    tRage:Slider({Name = "Spin Speed", Path = "Rage.SpinSpeed", Min = 5, Max = 120, Step = 1})

    local tMisc = addTab("misc")
    tMisc:Section("safety")
    tMisc:Button({
        Name = "PANIC NOW",
        Callback = function()
            if panic then
                panic()
            end
        end,
    })
    tMisc:Toggle({Name = "Watermark", Path = "Misc.Watermark"})
    tMisc:Toggle({Name = "Anti-AFK", Path = "Misc.AntiAFK"})
    tMisc:Keybind({Name = "UI Key", Path = "Keys.UI"})
    tMisc:Button({
        Name = "Unload",
        Callback = function()
            if Unload then
                Unload()
            end
        end,
    })

    do
        local dragging = false
        local dragStart = nil
        local startPos = nil

        GUIScope:Connect(topbar.InputBegan, function(i)
            if main and main.Parent and main.Visible and i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = i.Position
                startPos = main.Position
            end
        end)

        GUIScope:Connect(UIS.InputChanged, function(i)
            if dragging and main and main.Parent and main.Visible and i.UserInputType == Enum.UserInputType.MouseMovement then
                local d = i.Position - dragStart
                main.Position = UDim2.new(0.5, startPos.X.Offset + d.X, 0.5, startPos.Y.Offset + d.Y)
            end
        end)

        GUIScope:Connect(UIS.InputEnded, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    end

    GUIScope:Connect(hideBtn.MouseButton1Click, function()
        if main and main.Parent then
            main.Visible = false
        end
    end)

    paintAllUI()
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function isVisible(pos, targetChar)
    if not cam then return true end

    local lc = localRec()
    local ignore = {cam}
    if lc and lc.char then
        ignore[#ignore + 1] = lc.char
    end

    rayParams.FilterDescendantsInstances = ignore

    local origin = cam.CFrame.Position
    local dir = pos - origin
    if dir.Magnitude < 0.1 then return true end

    local ok, hit = pcall(function()
        return Workspace:Raycast(origin, dir, rayParams)
    end)

    if not ok or not hit then return true end

    if targetChar and hit.Instance and hit.Instance:IsDescendantOf(targetChar) then
        return true
    end

    return false
end

local function visibilityFor(rec, pos, maxAge)
    maxAge = maxAge or 0.02
    local now = os.clock()

    if rec.visTime and now - rec.visTime < maxAge and rec.visPos and (rec.visPos - pos).Magnitude < 1.5 then
        return rec.visVisible
    end

    local visible = isVisible(pos, rec.char)
    rec.visTime = now
    rec.visPos = pos
    rec.visVisible = visible
    return visible
end

local function targetValid(t)
    return t
        and t.rec
        and t.rec.alive
        and t.rec.hum
        and t.rec.hum.Parent
        and t.rec.hum.Health > 0
        and t.rec.char
        and t.rec.char.Parent
        and t.part
        and t.part.Parent
end

local function hashNoise(x, y, z)
    local n = math.sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453
    return n - math.floor(n)
end

local function humanizeOffset(rec, part, pos)
    local h = tonumber(S.Aimbot.Humanizer) or 0
    if h <= 0 then return pos end

    if part.Name ~= S.Aimbot.TargetPart then
        return pos
    end

    local t = math.floor(os.clock() * 8)
    local uid = rec.plr.UserId

    local rx = hashNoise(uid, t, 1) - 0.5
    local ry = hashNoise(uid, t, 2) - 0.5
    local rz = hashNoise(uid, t, 3) - 0.5

    return pos + Vector3.new(rx * h * 0.10, ry * h * 0.05, rz * h * 0.10)
end

local function getBestHitbox(char)
    if not char then return nil end

    local preferred = S.Aimbot.TargetPart or "Head"
    local p = char:FindFirstChild(preferred)
    if p and p:IsA("BasePart") then
        return p
    end

    for _, n in ipairs({"Head", "UpperTorso", "HumanoidRootPart", "Torso"}) do
        local part = char:FindFirstChild(n)
        if part and part:IsA("BasePart") then
            return part
        end
    end

    return nil
end

local shotAllowed = true
local hitAcc = 0

local function hitChanceOk()
    local chance = tonumber(S.Aimbot.HitChance) or 100

    if chance >= 100 then
        return true
    end

    if chance <= 0 then
        return false
    end

    return shotAllowed
end

App:Connect(RunService.Heartbeat, function(dt)
    if unloadStarted or unloadDone then return end

    hitAcc = hitAcc + (dt or 0)
    if hitAcc < 0.1 then return end
    hitAcc = 0

    local chance = tonumber(S.Aimbot.HitChance) or 100
    if chance >= 100 then
        shotAllowed = true
    elseif chance <= 0 then
        shotAllowed = false
    else
        shotAllowed = (math.random() * 100 <= chance)
    end
end)

local cachedTarget = nil

local function getBestTarget()
    if not cam then return nil end

    local lc = localRec()
    if not lc or not lc.alive then return nil end

    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local fov = S.Aimbot.FOV
    local best = nil
    local bestDistance = fov

    for plr, rec in pairs(Cache.byPlayer) do
        if plr ~= LP and rec.alive and rec.char then
            if not S.Aimbot.OnlyEnemies or rec.enemy then
                local part = getBestHitbox(rec.char)
                if part and part.Parent then
                    local pos = part.Position

                    if S.Aimbot.Prediction > 0 then
                        local vel = part.AssemblyLinearVelocity
                        if typeof(vel) == "Vector3" then
                            if vel.Magnitude > 400 then
                                vel = vel.Unit * 400
                            end
                            local lead = vel * S.Aimbot.Prediction
                            if lead.Magnitude > 30 then
                                lead = lead.Unit * 30
                            end
                            pos = pos + lead
                        end
                    end

                    pos = humanizeOffset(rec, part, pos)

                    local sp, onScreen = cam:WorldToViewportPoint(pos)
                    if onScreen and sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= bestDistance then
                            if not S.Aimbot.WallCheck or visibilityFor(rec, pos, 0.02) then
                                bestDistance = d
                                best = {rec = rec, part = part, pos = pos}
                            end
                        end
                    end
                end
            end
        end
    end

    if not targetValid(best) then
        return nil
    end

    return best
end

local fovCircle = nil
if drawingAvailable then
    local ok, c = pcall(Drawing.new, "Circle")
    if ok and c then
        fovCircle = c
        c.Thickness = 2
        c.NumSides = 64
        c.Filled = false
        c.Visible = false
        App:Add(function()
            if fovCircle then
                pcall(function()
                    fovCircle:Remove()
                end)
                fovCircle = nil
            end
        end)
    end
end

App:BindRender("aim", Enum.RenderPriority.Camera.Value - 1, function(dt)
    cam = Workspace.CurrentCamera

    if fovCircle then
        if (S.Aimbot.Enabled or S.Aimbot.Silent) and S.Aimbot.ShowFOV and cam then
            local vp = cam.ViewportSize
            fovCircle.Position = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
            fovCircle.Radius = S.Aimbot.FOV
            fovCircle.Color = S.Aimbot.Silent and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(0, 255, 100)
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end

    local target = nil
    if S.Aimbot.Enabled or S.Aimbot.Silent then
        target = getBestTarget()
    end

    if targetValid(target) then
        cachedTarget = target
    else
        cachedTarget = nil
    end

    if S.Aimbot.Enabled and cachedTarget and cam then
        local current = cam.CFrame
        local desired = CFrame.lookAt(current.Position, cachedTarget.pos)
        local smoothing = math.max(tonumber(S.Aimbot.Smoothing) or 5, 0.01)
        local alpha = math.clamp(1 - math.exp(-(dt or 1 / 60) * (60 / smoothing)), 0, 1)
        cam.CFrame = current:Lerp(desired, alpha)
    end
end)

local originalNamecall = nil
local hookMode = nil
local metaRef = nil
local unpackFn = table.unpack or unpack
local getnamecallmethodFn = type(getnamecallmethod) == "function" and getnamecallmethod or nil
local newcclosureFn = type(newcclosure) == "function" and newcclosure or nil
local setreadonlyFn = type(setreadonly) == "function" and setreadonly or nil
local rayNew = Ray and Ray.new or nil

local function namecallEntry(self, ...)
    if not originalNamecall then
        return
    end

    if unloadStarted or unloadDone or not S.Aimbot.Silent or self ~= Workspace then
        return originalNamecall(self, ...)
    end

    local method = getnamecallmethodFn and getnamecallmethodFn() or ""
    local isRay = (method == "Raycast")
    local isLegacy = (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist")

    if not isRay and not isLegacy then
        return originalNamecall(self, ...)
    end

    local args = {...}
    local n = select("#", ...)

    local origin, dir

    if isRay then
        origin = args[1]
        dir = args[2]
        if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" then
            return originalNamecall(self, ...)
        end
    else
        local ray = args[1]
        if typeof(ray) ~= "Ray" then
            return originalNamecall(self, ...)
        end
        origin = ray.Origin
        dir = ray.Direction
    end

    if dir.Magnitude < 0.5 then
        return originalNamecall(self, ...)
    end

    local lc = localRec()
    local root = lc and lc.root
    if not root or (origin - root.Position).Magnitude > 80 then
        return originalNamecall(self, ...)
    end

    local target = cachedTarget
    if not targetValid(target) then
        return originalNamecall(self, ...)
    end

    if not hitChanceOk() then
        return originalNamecall(self, ...)
    end

    local diff = target.pos - origin
    if diff.Magnitude < 0.5 then
        return originalNamecall(self, ...)
    end

    local newDir = diff.Unit * dir.Magnitude

    if isRay then
        args[2] = newDir
        return originalNamecall(self, unpackFn(args, 1, n))
    else
        if rayNew then
            args[1] = rayNew(origin, newDir)
            return originalNamecall(self, unpackFn(args, 1, n))
        end
        return originalNamecall(self, ...)
    end
end

local function installHook()
    if hookMode or unloadStarted or unloadDone then return end

    if type(hookmetamethod) == "function" and getnamecallmethodFn then
        local cb = namecallEntry
        if newcclosureFn then
            cb = newcclosureFn(cb)
        end
        originalNamecall = hookmetamethod(game, cb)
        hookMode = "hookmetamethod"
        return
    end

    if type(getrawmetatable) == "function" and setreadonlyFn and newcclosureFn and getnamecallmethodFn then
        local mt = getrawmetatable(game)
        if mt then
            metaRef = mt
            originalNamecall = mt.__namecall

            setreadonlyFn(mt, false)
            mt.__namecall = newcclosureFn(namecallEntry)
            setreadonlyFn(mt, true)

            hookMode = "rawmetatable"
        end
    end
end

local function uninstallHook()
    if not hookMode then return end

    if hookMode == "hookmetamethod" and type(hookmetamethod) == "function" and type(originalNamecall) == "function" then
        hookmetamethod(game, originalNamecall)
    elseif hookMode == "rawmetatable" and metaRef then
        if setreadonlyFn then
            setreadonlyFn(metaRef, false)
        end
        metaRef.__namecall = originalNamecall
        if setreadonlyFn then
            setreadonlyFn(metaRef, true)
        end
    end

    hookMode = nil
    originalNamecall = nil
    metaRef = nil
end

local lastTrigger = 0
App:Connect(RunService.Heartbeat, function()
    if unloadStarted or unloadDone then return end
    if not S.Trigger.Enabled or not cam then return end
    if GuiService.MenuIsOpen then return end
    if UIS:GetFocusedTextBox() then return end
    if UIS.MouseIconEnabled then return end
    if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end

    local now = os.clock()
    if now - lastTrigger < S.Trigger.Cooldown then return end

    local target = cachedTarget
    if not targetValid(target) then return end
    if S.Trigger.OnlyEnemies and not target.rec.enemy then return end
    if S.Trigger.WallCheck and not visibilityFor(target.rec, target.pos, 0.02) then return end
    if not hitChanceOk() then return end

    lastTrigger = now
    if type(mouse1click) == "function" then
        pcall(mouse1click)
    end
end)

local ESPS = {}
local espReleased = true

local function releaseViz(rec)
    local v = ESPS[rec]
    if not v then return end

    if v.box then release(v.box, "Square") end
    if v.hpBg then release(v.hpBg, "Square") end
    if v.hpFill then release(v.hpFill, "Square") end
    if v.snap then release(v.snap, "Line") end
    if v.name then release(v.name, "Text") end
    if v.dist then release(v.dist, "Text") end

    if v.chams then
        pcall(function()
            v.chams:Destroy()
        end)
    end

    ESPS[rec] = nil
end

local function releaseAllESP()
    for rec in pairs(ESPS) do
        releaseViz(rec)
    end
end

App:Add(releaseAllESP)

App:BindRender("esp", Enum.RenderPriority.Camera.Value + 2, function()
    cam = Workspace.CurrentCamera

    local shouldRun = S.ESP.Enabled and drawingAvailable and cam ~= nil

    if not shouldRun then
        if not espReleased then
            releaseAllESP()
            espReleased = true
        end
        return
    end

    espReleased = false
    local camPos = cam.CFrame.Position

    for _, rec in pairs(Cache.byPlayer) do
        if rec.plr ~= LP then
            local valid = rec.alive and rec.root and rec.root.Parent
            local allowed = valid and (not S.ESP.OnlyEnemies or rec.enemy)

            if not allowed then
                releaseViz(rec)
            else
                local dist = (rec.root.Position - camPos).Magnitude
                if dist > S.ESP.MaxDistance then
                    releaseViz(rec)
                else
                    local v = ESPS[rec] or {}
                    ESPS[rec] = v

                    local headPos
                    if rec.head and rec.head.Parent then
                        headPos = rec.head.Position
                    else
                        headPos = rec.root.Position + Vector3.new(0, 2.5, 0)
                    end

                    local legPos = rec.root.Position - Vector3.new(0, 2.5, 0)
                    local hSp = cam:WorldToViewportPoint(headPos)
                    local lSp = cam:WorldToViewportPoint(legPos)

                    if hSp.Z < 0 and lSp.Z < 0 then
                        releaseViz(rec)
                    else
                        local height = math.abs(lSp.Y - hSp.Y)
                        local width = height * 0.5
                        local x = hSp.X - width * 0.5
                        local y = hSp.Y
                        local color = rec.enemy and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(90, 140, 255)

                        if S.ESP.Boxes then
                            v.box = v.box or acquire("Square")
                            if v.box then
                                v.box.Filled = false
                                v.box.Thickness = 1
                                v.box.Color = color
                                v.box.Size = Vector2.new(width, height)
                                v.box.Position = Vector2.new(x, y)
                                v.box.Visible = true
                            end
                        elseif v.box then
                            release(v.box, "Square")
                            v.box = nil
                        end

                        if S.ESP.HealthBar and rec.hum and rec.hum.Parent and rec.hum.MaxHealth > 0 then
                            v.hpBg = v.hpBg or acquire("Square")
                            v.hpFill = v.hpFill or acquire("Square")

                            local pct = math.clamp(rec.hum.Health / rec.hum.MaxHealth, 0, 1)

                            if v.hpBg then
                                v.hpBg.Filled = true
                                v.hpBg.Color = Color3.fromRGB(0, 0, 0)
                                v.hpBg.Size = Vector2.new(3, height)
                                v.hpBg.Position = Vector2.new(x - 5, y)
                                v.hpBg.Visible = true
                            end

                            if v.hpFill then
                                local bh = height * pct
                                v.hpFill.Filled = true
                                v.hpFill.Size = Vector2.new(3, bh)
                                v.hpFill.Position = Vector2.new(x - 5, y + (height - bh))
                                v.hpFill.Color = Color3.fromRGB(60, 220, 60):Lerp(Color3.fromRGB(220, 60, 60), 1 - pct)
                                v.hpFill.Visible = true
                            end
                        else
                            if v.hpBg then release(v.hpBg, "Square") v.hpBg = nil end
                            if v.hpFill then release(v.hpFill, "Square") v.hpFill = nil end
                        end

                        if S.ESP.Snaplines then
                            v.snap = v.snap or acquire("Line")
                            if v.snap then
                                local vp = cam.ViewportSize
                                v.snap.Thickness = 1
                                v.snap.Color = color
                                v.snap.From = Vector2.new(vp.X * 0.5, vp.Y)
                                v.snap.To = Vector2.new(hSp.X, hSp.Y)
                                v.snap.Visible = true
                            end
                        elseif v.snap then
                            release(v.snap, "Line")
                            v.snap = nil
                        end

                        if S.ESP.Names then
                            v.name = v.name or acquire("Text")
                            if v.name then
                                v.name.Size = 13
                                v.name.Center = true
                                v.name.Outline = true
                                v.name.Color = color
                                v.name.Text = (rec.plr.DisplayName ~= "" and rec.plr.DisplayName) or rec.plr.Name
                                v.name.Position = Vector2.new(hSp.X, y - 16)
                                v.name.Visible = true
                            end
                        elseif v.name then
                            release(v.name, "Text")
                            v.name = nil
                        end

                        if S.ESP.Distance then
                            v.dist = v.dist or acquire("Text")
                            if v.dist then
                                v.dist.Size = 12
                                v.dist.Center = true
                                v.dist.Outline = true
                                v.dist.Color = Color3.fromRGB(255, 255, 255)
                                v.dist.Text = math.floor(dist) .. "m"
                                v.dist.Position = Vector2.new(hSp.X, y + height + 4)
                                v.dist.Visible = true
                            end
                        elseif v.dist then
                            release(v.dist, "Text")
                            v.dist = nil
                        end

                        if S.ESP.Chams then
                            if not v.chams or v.chams.Parent ~= rec.char then
                                if v.chams then
                                    pcall(function()
                                        v.chams:Destroy()
                                    end)
                                end

                                local ok, h = pcall(Instance.new, "Highlight")
                                if ok and h then
                                    h.FillColor = color
                                    h.OutlineColor = Color3.fromRGB(255, 255, 255)
                                    h.FillTransparency = 0.4
                                    pcall(function()
                                        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                    end)
                                    h.Adornee = rec.char
                                    h.Parent = rec.char
                                    v.chams = h
                                end
                            else
                                v.chams.FillColor = color
                                v.chams.Enabled = true
                            end
                        elseif v.chams then
                            pcall(function()
                                v.chams:Destroy()
                            end)
                            v.chams = nil
                        end
                    end
                end
            end
        end
    end
end)

local MV = {
    origWalk = nil,
    fly = nil,
    ncOn = false,
    lastJump = 0,
    ncAcc = 0,
}

destroyFly = function()
    if not MV.fly then return end

    if MV.fly.lv then
        pcall(function()
            MV.fly.lv:Destroy()
        end)
    end

    if MV.fly.ao then
        pcall(function()
            MV.fly.ao:Destroy()
        end)
    end

    if MV.fly.att then
        pcall(function()
            MV.fly.att:Destroy()
        end)
    end

    MV.fly = nil
end

local function createFly(root)
    destroyFly()

    local ok = pcall(function()
        local att = Instance.new("Attachment")
        att.Parent = root

        local lv = Instance.new("LinearVelocity")
        lv.Attachment0 = att
        lv.MaxForce = math.huge
        lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        lv.VectorVelocity = Vector3.zero
        lv.Parent = root

        local ao = Instance.new("AlignOrientation")
        ao.Attachment0 = att
        ao.MaxTorque = math.huge
        ao.Responsiveness = 200
        ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ao.Parent = root

        MV.fly = {att = att, lv = lv, ao = ao}
    end)

    if not ok then
        destroyFly()
    end
end

local function getLocalChar()
    local lc = localRec()
    if lc and lc.char and lc.char.Parent then
        return lc.char
    end
    return LP.Character
end

local function applyNoClip(enabled)
    local char = getLocalChar()
    if not char then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and not part:IsA("Seat") and not part:IsA("VehicleSeat") then
            if enabled and part.CanCollide then
                part.CanCollide = false
            elseif not enabled and not part.CanCollide then
                part.CanCollide = true
            end
        end
    end
end

restoreNoClip = function()
    applyNoClip(false)
    MV.ncOn = false
    MV.ncAcc = 0
end

local flyAcc = 0
App:BindRender("flyOrient", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not S.Move.Fly then return end

    flyAcc = flyAcc + (dt or 1 / 60)
    if flyAcc < 1 / 30 then return end
    flyAcc = 0

    if MV.fly and MV.fly.ao and cam then
        MV.fly.ao.CFrame = cam.CFrame
    end
end)

App:Connect(LP.CharacterAdded, function()
    MV.origWalk = nil
    MV.ncOn = false
    MV.ncAcc = 0
    MV.lastJump = 0
    destroyFly()
end)

App:Connect(RunService.Heartbeat, function(dt)
    if unloadStarted or unloadDone then return end

    local lc = localRec()
    if not lc or not lc.alive or not lc.hum or not lc.hum.Parent or not lc.root or not lc.root.Parent then
        return
    end

    local hum = lc.hum
    local root = lc.root
    dt = dt or 1 / 60

    if S.Move.Speed then
        if MV.origWalk == nil then
            MV.origWalk = hum.WalkSpeed
        end

        if S.Move.SpeedMode == "Walk" then
            if hum.WalkSpeed ~= S.Move.SpeedValue then
                hum.WalkSpeed = S.Move.SpeedValue
            end
        else
            local md = hum.MoveDirection
            if md.Magnitude > 0.1 then
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(md.X * S.Move.SpeedValue, v.Y, md.Z * S.Move.SpeedValue)
            end
        end
    elseif MV.origWalk then
        if hum.WalkSpeed ~= MV.origWalk then
            hum.WalkSpeed = MV.origWalk
        end
        MV.origWalk = nil
    end

    if S.Move.NoClip ~= MV.ncOn then
        MV.ncOn = S.Move.NoClip
        applyNoClip(S.Move.NoClip)
    end

    if S.Move.NoClip then
        MV.ncAcc = MV.ncAcc + dt
        if MV.ncAcc >= 0.2 then
            MV.ncAcc = 0
            applyNoClip(true)
        end
    end

    if S.Move.InfJump then
        local state = hum:GetState()
        if UIS:IsKeyDown(Enum.KeyCode.Space)
            and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.RunningNoPhysics)
            and os.clock() - MV.lastJump > 0.22 then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            MV.lastJump = os.clock()
        end
    end

    if S.Move.Bhop then
        local state = hum:GetState()
        if UIS:IsKeyDown(Enum.KeyCode.Space)
            and (state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics) then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end

    if S.Move.Fly then
        if not MV.fly or not MV.fly.lv or MV.fly.lv.Parent ~= root then
            createFly(root)
        end

        local move = Vector3.zero
        if cam then
            local look = cam.CFrame.LookVector
            local right = cam.CFrame.RightVector

            if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + look end
            if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - look end
            if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - right end
            if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + right end
        end

        if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end

        if MV.fly and MV.fly.lv then
            MV.fly.lv.VectorVelocity = (move.Magnitude > 0) and (move.Unit * S.Move.FlyValue) or Vector3.zero
        end
    else
        destroyFly()
    end
end)

local AA = {
    rootJ = nil,
    neck = nil,
    origRoot = nil,
    origNeck = nil,
    acc = 0,
}

App:Connect(LP.CharacterAdded, function()
    AA.rootJ = nil
    AA.neck = nil
    AA.origRoot = nil
    AA.origNeck = nil
    AA.acc = 0
end)

restoreAA = function()
    if AA.rootJ and AA.origRoot then
        pcall(function()
            AA.rootJ.C0 = AA.origRoot
        end)
    end

    if AA.neck and AA.origNeck then
        pcall(function()
            AA.neck.C0 = AA.origNeck
        end)
    end

    AA.rootJ = nil
    AA.neck = nil
    AA.origRoot = nil
    AA.origNeck = nil
    AA.acc = 0
end

App:BindRender("aa", Enum.RenderPriority.Camera.Value + 5, function(dt)
    AA.acc = AA.acc + (dt or 1 / 60)
    if AA.acc < 1 / 30 then
        return
    end
    AA.acc = 0

    local lc = localRec()
    if not lc or not lc.root or not lc.root.Parent then return end

    local root = lc.root

    if not AA.rootJ then
        local j = root:FindFirstChild("RootJoint")
        if j and j:IsA("Motor6D") then
            AA.rootJ = j
            AA.origRoot = j.C0
        end
    end

    if not AA.neck and lc.head and lc.head.Parent then
        local n = lc.head:FindFirstChild("Neck")
        if n and n:IsA("Motor6D") then
            AA.neck = n
            AA.origNeck = n.C0
        end
    end

    local anyAA = S.AA.Jitter or S.AA.Desync or S.AA.HideHead

    if not anyAA then
        if AA.rootJ and AA.origRoot and AA.rootJ.C0 ~= AA.origRoot then
            AA.rootJ.C0 = AA.origRoot
        end
        if AA.neck and AA.origNeck and AA.neck.C0 ~= AA.origNeck then
            AA.neck.C0 = AA.origNeck
        end
        return
    end

    local now = os.clock()
    local jitter = 0

    if S.AA.Jitter then
        jitter = math.sin(now * 12) * math.rad(S.AA.JitterAngle)
    end

    local desync = 0
    if S.AA.Desync then
        if S.AA.DesyncMode == "Spin" then
            desync = math.rad(now * S.AA.DesyncSpeed)
        elseif S.AA.DesyncMode == "Static" then
            desync = math.rad(60)
        else
            desync = math.rad(180)
        end
    end

    if AA.rootJ and AA.origRoot then
        AA.rootJ.C0 = AA.origRoot * CFrame.Angles(0, jitter + desync, 0)
    end

    if S.AA.HideHead and AA.neck and AA.origNeck then
        AA.neck.C0 = AA.origNeck * CFrame.Angles(0, math.rad(180), 0)
    elseif AA.neck and AA.origNeck and AA.neck.C0 ~= AA.origNeck then
        AA.neck.C0 = AA.origNeck
    end
end)

local rageInstances = {}
local rageReleased = true
local lastRage = 0

destroyRage = function()
    for i = #rageInstances, 1, -1 do
        local inst = rageInstances[i]
        if inst then
            pcall(function()
                inst:Destroy()
            end)
        end
        rageInstances[i] = nil
    end
    rageReleased = true
end

local function flingRoot(root, dir)
    safeSpawn(function()
        if unloadStarted or unloadDone or not App.alive then return end
        if not root or not root.Parent or root.Position.Y < -400 then return end

        local ok, angular = pcall(Instance.new, "BodyAngularVelocity")
        if not ok or not angular then return end

        angular.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        angular.AngularVelocity = Vector3.new(dir.Z * 80, 120, -dir.X * 80)
        angular.Parent = root
        rageInstances[#rageInstances + 1] = angular

        pcall(function()
            root.AssemblyLinearVelocity = dir * 160 + Vector3.new(0, 90, 0)
        end)

        App:Schedule(0.25, function()
            if angular and angular.Parent then
                pcall(function()
                    angular:Destroy()
                end)
            end
        end)
    end)
end

App:Connect(RunService.Heartbeat, function(dt)
    if unloadStarted or unloadDone then return end

    if not S.Rage.Enabled then
        if not rageReleased then
            destroyRage()
        end
        return
    end

    rageReleased = false

    local now = os.clock()
    local lc = localRec()
    if not lc or not lc.alive or not lc.root or not lc.root.Parent then return end

    if S.Rage.Spinbot then
        local angle = math.rad(S.Rage.SpinSpeed) * (dt or 1 / 60)
        lc.root.CFrame = lc.root.CFrame * CFrame.Angles(0, angle, 0)
    end

    if now - lastRage < 0.5 then return end
    lastRage = now

    if S.Rage.MassFling then
        for plr, rec in pairs(Cache.byPlayer) do
            if plr ~= LP and rec.alive and rec.hum and rec.hum.Health > 0 and rec.root and rec.root.Parent and rec.enemy then
                local distance = (lc.root.Position - rec.root.Position).Magnitude
                local allowed = (S.Rage.FlingTarget == "All") or (distance < 50)

                if allowed and rec.root.Position.Y > -400 then
                    local dir = rec.root.Position - lc.root.Position
                    if dir.Magnitude < 0.1 then
                        dir = Vector3.new(1, 0, 0)
                    else
                        dir = dir.Unit
                    end

                    flingRoot(rec.root, dir)
                end
            end
        end
    end

    if S.Rage.VoidTP then
        for plr, rec in pairs(Cache.byPlayer) do
            if plr ~= LP and rec.alive and rec.hum and rec.hum.Health > 0 and rec.root and rec.root.Parent and rec.enemy then
                local distance = (lc.root.Position - rec.root.Position).Magnitude
                if distance < 30 and rec.root.Position.Y > -450 then
                    rec.root.CFrame = CFrame.new(0, -500, 0)
                end
            end
        end
    end
end)

panic = function()
    if unloadStarted or unloadDone or not App.alive then return end

    for _, path in ipairs({
        "Aimbot.Enabled",
        "Aimbot.Silent",
        "Trigger.Enabled",
        "ESP.Enabled",
        "ESP.Chams",
        "Move.Speed",
        "Move.Fly",
        "Move.NoClip",
        "Move.InfJump",
        "Move.Bhop",
        "AA.Jitter",
        "AA.Desync",
        "AA.HideHead",
        "Rage.Enabled",
        "Rage.MassFling",
        "Rage.VoidTP",
        "Rage.Spinbot",
    }) do
        Set(path, false, true)
    end

    queueSave()
    destroyFly()
    destroyRage()
    restoreNoClip()
end

local wmText = nil
if drawingAvailable then
    local ok, t = pcall(Drawing.new, "Text")
    if ok and t then
        wmText = t
        t.Size = 13
        t.Outline = true
        t.Visible = false
        App:Add(function()
            if wmText then
                pcall(function()
                    wmText:Remove()
                end)
                wmText = nil
            end
        end)
    end
end

local watermarkAcc = 0
App:Connect(RunService.Heartbeat, function(dt)
    if unloadStarted or unloadDone then return end

    watermarkAcc = watermarkAcc + (dt or 0)
    if watermarkAcc < 0.25 then return end
    watermarkAcc = 0

    if wmText then
        wmText.Visible = S.Misc.Watermark
        if S.Misc.Watermark then
            wmText.Text = "abyss_final"
            wmText.Position = Vector2.new(10, 10)
            wmText.Color = Color3.fromRGB(235, 235, 240)
        end
    end
end)

if LP.Idled then
    App:Connect(LP.Idled, function()
        if unloadStarted or unloadDone then return end
        if S.Misc.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end)
end

App:Connect(UIS.InputBegan, function(input, processed)
    if unloadStarted or unloadDone then return end
    if processed then return end
    if GuiService.MenuIsOpen then return end

    local key = input.KeyCode.Name

    if key == S.Keys.UI and main and main.Parent then
        main.Visible = not main.Visible
        return
    end

    if key == S.Misc.PanicKey then
        panic()
        return
    end

    if key == S.Keys.Aimbot then
        Set("Aimbot.Enabled", not G("Aimbot.Enabled"))
    end

    if key == S.Keys.Silent then
        Set("Aimbot.Silent", not G("Aimbot.Silent"))
    end

    if key == S.Keys.Fly then
        Set("Move.Fly", not G("Move.Fly"))
    end

    if key == S.Keys.Speed then
        Set("Move.Speed", not G("Move.Speed"))
    end
end)

Unload = function()
    if unloadStarted or unloadDone then return end
    unloadStarted = true

    safeWait(0.3)

    for i = #Scopes, 1, -1 do
        local s = Scopes[i]
        if s then
            pcall(s.Destroy, s)
        end
    end

    safeWait(0.3)

    pcall(uninstallHook)
    pcall(destroyFly)
    pcall(destroyRage)
    pcall(restoreNoClip)
    pcall(restoreAA)

    local char = getLocalChar()
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and MV.origWalk then
            pcall(function()
                hum.WalkSpeed = MV.origWalk
            end)
        end
    end

    pcall(nukePool)

    cachedTarget = nil
    shotAllowed = true
    hitAcc = 0
    espReleased = true
    rageReleased = true
    lastTrigger = 0
    lastRage = 0
    saveQueued = false
    MV.origWalk = nil
    MV.ncOn = false
    MV.ncAcc = 0
    MV.lastJump = 0
    guiEnabled = false
    gui = nil
    main = nil
    GUIScope = nil

    ENV.__ABYSS_FINAL = nil

    Runtime.unloading = true
    Runtime.dead = true
    unloadDone = true
end

BuildGUI()

local guiWatchAcc = 0
App:Connect(RunService.Heartbeat, function(dt)
    if unloadStarted or unloadDone then return end

    guiWatchAcc = guiWatchAcc + (dt or 0)
    if guiWatchAcc < 1 then return end
    guiWatchAcc = 0

    if guiEnabled and (not gui or not gui.Parent) then
        BuildGUI()
    end
end)

ENV.__ABYSS_FINAL = {Unload = Unload}

safeWait(0.1)
if not unloadStarted and not unloadDone then
    installHook()
end

print("[abyss_final] ready // CoreGui-only // RightShift=UI // End=panic")
