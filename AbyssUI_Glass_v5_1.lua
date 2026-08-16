--[[
    unknown // private 2027
    Монолитный клиент: GUI + aimbot + esp + movement + combat + stealth.
    Чёрная тема, floating dropdown (фикс клиппинга), ray-based hitbox,
    пул Drawing-объектов, конфиг AbyssUniversal/Config.json, self-destruct.
]]

----------------------------------------------------------------
-- Services
----------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local VirtualInput      = game:GetService("VirtualInputManager")
local TeleportService   = game:GetService("TeleportService")
local CoreGui           = game:GetService("CoreGui")

if not RunService:IsClient() then error("client only") end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
while not LocalPlayer.Character do task.wait(0.1) end

local Camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end)

----------------------------------------------------------------
-- Settings + конфиг (AbyssUniversal/Config.json)
----------------------------------------------------------------
local Settings = {
    Aimbot  = { Enabled = false, FOV = 90, Smoothing = 6, Prediction = 0.11, WallCheck = true, ShowFOVCircle = true, HitChance = 100 },
    Visuals = { Enabled = false, Boxes = true, HealthBar = true, Tracers = false, Names = true, Distance = false, Chams = false, OnlyEnemies = true, MaxDistance = 900 },
    Speed   = { Enabled = false, Mode = "WalkSpeed", Value = 50 },
    Fly     = { Enabled = false, Mode = "LinearVelocity", AntiKick = true, Value = 60 },
    Move    = { NoClip = false, InfJump = false },
    Combat  = { KillAura = false, AuraRange = 14, AutoClicker = false, CPS = 12 },
    Hitbox  = { Enabled = false, Radius = 4 },
    Misc    = { AntiAFK = true, Fullbright = false, LowGraphics = false, UIScale = 100 },
}

local CONFIG_PATH = "AbyssUniversal/Config.json"

local function fsOk()
    return type(writefile) == "function" and type(readfile) == "function"
        and type(isfile) == "function" and type(makefolder) == "function"
        and type(isfolder) == "function"
end

-- рекурсивное применение сохранённых значений поверх дефолтов
local function mergeConfig(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            mergeConfig(dst[k], v)
        else
            dst[k] = v
        end
    end
end

if fsOk() and isfile(CONFIG_PATH) then
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_PATH)) end)
    if ok and type(data) == "table" then mergeConfig(Settings, data) end
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
-- Утилиты GUI
----------------------------------------------------------------
local C = {
    bg       = Color3.fromRGB(8, 8, 10),
    topbar   = Color3.fromRGB(13, 13, 16),
    sidebar  = Color3.fromRGB(11, 11, 14),
    element  = Color3.fromRGB(19, 19, 23),
    hover    = Color3.fromRGB(27, 27, 32),
    stroke   = Color3.fromRGB(38, 38, 44),
    text     = Color3.fromRGB(238, 238, 242),
    muted    = Color3.fromRGB(118, 118, 128),
    accent   = Color3.fromRGB(255, 62, 62),
    accent2  = Color3.fromRGB(255, 122, 122),
    off      = Color3.fromRGB(58, 58, 66),
}

local function new(cls, props, parent)
    local inst = Instance.new(cls)
    if props then for k, v in pairs(props) do inst[k] = v end end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(parent, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 7) }, parent) end
local function stroke(parent, col, th) return new("UIStroke", { Color = col or C.stroke, Thickness = th or 1 }, parent) end
local function tween(obj, t, props)
    if not obj or not obj.Parent then return end
    TweenService:Create(obj, TweenInfo.new(t or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- реестр соединений для полного самоуничтожения
local connections = {}
local renderSteps = {}
local function connect(sig, fn)
    local c = sig:Connect(fn)
    connections[#connections + 1] = c
    return c
end
local function bindRender(name, prio, fn)
    renderSteps[#renderSteps + 1] = name
    pcall(function() RunService:BindToRenderStep(name, prio, fn) end)
end

----------------------------------------------------------------
-- GUI root (чёрная тема, unknown)
----------------------------------------------------------------
local function pickGuiParent()
    if type(gethui) == "function" then
        local ok, t = pcall(gethui)
        if ok and t then return t end
    end
    local ok, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 3) end)
    if ok and pg then return pg end
    return CoreGui
end

local parent0 = pickGuiParent()
local old = parent0:FindFirstChild("UnknownUI")
if old then pcall(function() old:Destroy() end) end

local screenGui = new("ScreenGui", {
    Name = "UnknownUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
}, parent0)

local main = new("Frame", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(560, 470),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true,
    Parent = screenGui,
})
corner(main, 10)
stroke(main, C.stroke)

local uiScale = new("UIScale", { Scale = (tonumber(Settings.Misc.UIScale) or 100) / 100 }, main)

-- topbar
local topbar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.topbar,
    BorderSizePixel = 0, Parent = main,
})
corner(topbar, 10)
new("Frame", { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -10), BackgroundColor3 = C.topbar, BorderSizePixel = 0, Parent = topbar })
-- акцент-полоса снизу topbar
new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = C.accent, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = topbar })
-- акцент-бар слева от названия
new("Frame", { Size = UDim2.fromOffset(3, 16), Position = UDim2.fromOffset(14, 15), BackgroundColor3 = C.accent, BorderSizePixel = 0, Parent = topbar })
-- название: unknown (градиент, Michroma)
local titleLabel = new("TextLabel", {
    Size = UDim2.fromOffset(220, 20), Position = UDim2.fromOffset(24, 13),
    BackgroundTransparency = 1, Text = "unknown",
    Font = Enum.Font.Michroma, TextSize = 15,
    TextColor3 = Color3.fromRGB(248, 248, 250),
    TextXAlignment = Enum.TextXAlignment.Left, Parent = topbar,
})
new("UIGradient", {
    Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(130, 130, 140)),
}, titleLabel)
new("TextLabel", {
    Size = UDim2.fromOffset(140, 14), Position = UDim2.new(1, -150, 0.5, -7),
    BackgroundTransparency = 1, Text = "private // 2027",
    Font = Enum.Font.Code, TextSize = 10, TextColor3 = C.muted,
    TextXAlignment = Enum.TextXAlignment.Right, Parent = topbar,
})

local function topBtn(txt, off)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, off, 0.5, -13),
        BackgroundColor3 = C.element, BorderSizePixel = 0, Text = txt,
        TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12,
        AutoButtonColor = false, Parent = topbar,
    })
    corner(b, 6)
    return b
end
local closeBtn = topBtn("x", -34)
local minBtn   = topBtn("-", -66)

local sidebar = new("Frame", {
    Size = UDim2.new(0, 128, 1, -54), Position = UDim2.fromOffset(8, 52),
    BackgroundColor3 = C.sidebar, BorderSizePixel = 0, Parent = main,
})
corner(sidebar, 8)

local tabList = new("ScrollingFrame", {
    Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
    CanvasSize = UDim2.new(), Parent = sidebar,
})
local tabLayout = new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, tabList)
connect(tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    tabList.CanvasSize = UDim2.fromOffset(0, tabLayout.AbsoluteContentSize.Y + 4)
end)

local pages = new("Frame", {
    Size = UDim2.new(1, -142, 1, -54), Position = UDim2.fromOffset(140, 52),
    BackgroundTransparency = 1, Parent = main,
})

-- resize handle (динамический размер окна)
local resizeHandle = new("TextButton", {
    Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -16, 1, -16),
    BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = main,
})
new("TextLabel", {
    Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(6, 6),
    BackgroundTransparency = 1, Text = "\\", TextColor3 = C.muted,
    Font = Enum.Font.GothamBold, TextSize = 10, Parent = resizeHandle,
})

----------------------------------------------------------------
-- Floating dropdown popup (фикс: список больше не уходит под элементы)
----------------------------------------------------------------
local activePopup = nil
local function repositionPopup()
    if activePopup and activePopup.list and activePopup.list.Visible and activePopup.anchor and activePopup.anchor.Parent then
        local ap = activePopup.anchor.AbsolutePosition
        local as = activePopup.anchor.AbsoluteSize
        activePopup.list.Position = UDim2.fromOffset(ap.X, ap.Y + as.Y + 4)
        activePopup.list.Size = UDim2.fromOffset(as.X, activePopup.list.Size.Y.Offset)
    end
end
local function closePopup()
    if activePopup and activePopup.list then
        activePopup.list.Visible = false
        activePopup = nil
    end
end

----------------------------------------------------------------
-- Фабрика табов и элементов
----------------------------------------------------------------
local tabs = {}
local selected = nil

local function selectTab(rec)
    selected = rec
    closePopup()
    for _, r in ipairs(tabs) do
        local sel = (r == rec)
        r.page.Visible = sel
        r.btn.BackgroundColor3 = sel and C.hover or C.element
        r.btn.TextColor3 = sel and C.text or C.muted
        r.bar.Visible = sel
    end
end

local function createTab(name)
    local page = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.stroke,
        Visible = false, CanvasSize = UDim2.new(), Parent = pages,
    })
    local layout = new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }, page)
    connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 16)
    end)

    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.element, BorderSizePixel = 0,
        Text = name, TextColor3 = C.muted, Font = Enum.Font.GothamMedium, TextSize = 12,
        AutoButtonColor = false, Parent = tabList,
    })
    corner(btn, 6)
    local bar = new("Frame", {
        Size = UDim2.fromOffset(2, 16), Position = UDim2.fromOffset(0, 7),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Visible = false, Parent = btn,
    })

    local rec = { name = name, page = page, btn = btn, bar = bar }
    table.insert(tabs, rec)
    connect(btn.MouseButton1Click, function() selectTab(rec) end)
    connect(btn.MouseEnter, function() if selected ~= rec then btn.BackgroundColor3 = C.hover end end)
    connect(btn.MouseLeave, function() if selected ~= rec then btn.BackgroundColor3 = C.element end end)
    if not selected then selectTab(rec) end

    local Tab = {}
    local order = 0
    local function nextOrder() order = order + 1 return order end

    local function elemFrame(h)
        local f = new("Frame", {
            Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = C.element,
            BorderSizePixel = 0, LayoutOrder = nextOrder(), Parent = page,
        })
        corner(f, 7)
        stroke(f, C.stroke)
        return f
    end
    local function elemTitle(p, t)
        return new("TextLabel", {
            Size = UDim2.new(0.62, -12, 1, 0), Position = UDim2.fromOffset(10, 0),
            BackgroundTransparency = 1, Text = t, TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13, Parent = p,
        })
    end
    local function hoverize(f)
        connect(f.MouseEnter, function() f.BackgroundColor3 = C.hover end)
        connect(f.MouseLeave, function() f.BackgroundColor3 = C.element end)
    end
    local function addClick(f, cb)
        local o = new("TextButton", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
            AutoButtonColor = false, ZIndex = 5, Parent = f,
        })
        connect(o.MouseButton1Click, function() pcall(cb) end)
        return o
    end

    function Tab:CreateSection(text)
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
            Text = "  " .. tostring(text):upper(), TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = C.muted, Font = Enum.Font.GothamSemibold, TextSize = 11,
            LayoutOrder = nextOrder(), Parent = page,
        })
    end

    function Tab:CreateLabel(text)
        local f = elemFrame(24); hoverize(f)
        local l = elemTitle(f, text)
        l.Size = UDim2.new(1, -14, 1, 0); l.TextColor3 = C.muted; l.TextSize = 12
        return { Set = function(_, v) l.Text = tostring(v) end }
    end

    function Tab:CreateButton(opts)
        opts = opts or {}
        local f = elemFrame(30); hoverize(f)
        local l = elemTitle(f, opts.Name or "Button"); l.Size = UDim2.new(1, -14, 1, 0)
        addClick(f, function() if type(opts.Callback) == "function" then opts.Callback() end end)
        return { Set = function(_, v) l.Text = tostring(v) end }
    end

    function Tab:CreateToggle(opts)
        opts = opts or {}
        local state = opts.CurrentValue == true
        local f = elemFrame(30); hoverize(f)
        elemTitle(f, opts.Name or "Toggle")
        local sw = new("Frame", {
            Size = UDim2.fromOffset(38, 18), Position = UDim2.new(1, -48, 0.5, -9),
            BackgroundColor3 = C.bg, BorderSizePixel = 0, Parent = f,
        })
        corner(sw, 9); stroke(sw, C.stroke)
        local ind = new("Frame", {
            Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = state and C.accent or C.off, BorderSizePixel = 0, Parent = sw,
        })
        corner(ind, 6)
        ind.Position = state and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)

        local obj = { CurrentValue = state }
        local function apply(v, fire)
            state = (v == true); obj.CurrentValue = state
            if state then
                tween(ind, 0.15, { Position = UDim2.new(1, -15, 0.5, 0), BackgroundColor3 = C.accent })
            else
                tween(ind, 0.15, { Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = C.off })
            end
            if fire and type(opts.Callback) == "function" then pcall(opts.Callback, state) end
        end
        addClick(f, function() apply(not state, true) end)
        function obj:Set(v) apply(v, true) end
        apply(state, false)
        return obj
    end

    function Tab:CreateSlider(opts)
        opts = opts or {}
        local min = tonumber(opts.Range and opts.Range[1]) or 0
        local max = tonumber(opts.Range and opts.Range[2]) or 100
        if min > max then min, max = max, min end
        local inc = tonumber(opts.Increment) or 1
        if inc <= 0 then inc = 1 end
        local value = math.clamp(tonumber(opts.CurrentValue) or min, min, max)

        local f = elemFrame(44); hoverize(f)
        elemTitle(f, opts.Name or "Slider")
        local info = new("TextLabel", {
            Size = UDim2.fromOffset(90, 14), Position = UDim2.new(1, -100, 0, 5),
            BackgroundTransparency = 1, TextColor3 = C.muted, Font = Enum.Font.Gotham,
            TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Parent = f,
        })
        local track = new("Frame", {
            Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 30),
            BackgroundColor3 = C.off, BorderSizePixel = 0, Parent = f,
        })
        corner(track, 3)
        local prog = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.accent, BorderSizePixel = 0, Parent = track })
        corner(prog, 3)

        local obj = { CurrentValue = value }
        local draggingS = false
        local function snap(v)
            v = math.clamp(v, min, max)
            return math.clamp(min + math.floor((v - min) / inc + 0.5) * inc, min, max)
        end
        local function apply(v, fire)
            v = snap(v); value = v; obj.CurrentValue = v
            local r = (max > min) and ((v - min) / (max - min)) or 0
            prog.Size = UDim2.new(r, 0, 1, 0)
            info.Text = tostring(v) .. (opts.Suffix and (" " .. opts.Suffix) or "")
            if fire and type(opts.Callback) == "function" then pcall(opts.Callback, v) end
        end
        local function fromX(x)
            local w = math.max(track.AbsoluteSize.X, 1)
            local r = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
            apply(min + (max - min) * r, true)
        end
        connect(track.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingS = true; fromX(input.Position.X)
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if draggingS and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                fromX(input.Position.X)
            end
        end)
        connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingS = false
            end
        end)
        function obj:Set(v) apply(v, true) end
        apply(value, false)
        return obj
    end

    -- Dropdown: список — floating popup в screenGui (не клиппится страницей)
    function Tab:CreateDropdown(opts)
        opts = opts or {}
        local options = opts.Options or {}
        local current = opts.CurrentOption or options[1]

        local f = elemFrame(32); hoverize(f)
        elemTitle(f, opts.Name or "Dropdown")
        local sel = new("TextLabel", {
            Size = UDim2.new(0.34, -26, 1, 0), Position = UDim2.new(0.66, -16, 0, 0),
            BackgroundTransparency = 1, Text = tostring(current or "None"),
            TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right, Parent = f,
        })
        local arrow = new("TextLabel", {
            Size = UDim2.fromOffset(16, 32), Position = UDim2.new(1, -22, 0, 0),
            BackgroundTransparency = 1, Text = "v", TextColor3 = C.muted,
            Font = Enum.Font.GothamBold, TextSize = 12, Parent = f,
        })

        local list = new("Frame", {
            BackgroundColor3 = C.topbar, BorderSizePixel = 0,
            ClipsDescendants = true, Visible = false, ZIndex = 200,
            Parent = screenGui,
        })
        corner(list, 7); stroke(list, C.stroke)
        local lLayout = new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, list)
        new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, list)

        local obj = { CurrentOption = current }
        local open = false

        local function paintOptions()
            for _, b in ipairs(list:GetChildren()) do
                if b:IsA("TextButton") then
                    local isCur = (b:GetAttribute("opt") == tostring(current))
                    b.BackgroundColor3 = isCur and C.hover or C.element
                    b.TextColor3 = isCur and C.accent2 or C.text
                end
            end
        end

        for _, opt in ipairs(options) do
            local b = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.element,
                BorderSizePixel = 0, Text = "  " .. tostring(opt),
                TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.text,
                Font = Enum.Font.Gotham, TextSize = 12, AutoButtonColor = false,
                ZIndex = 202, Parent = list,
            })
            b:SetAttribute("opt", tostring(opt))
            corner(b, 5)
            connect(b.MouseButton1Click, function()
                current = opt; obj.CurrentOption = opt
                sel.Text = tostring(opt)
                if type(opts.Callback) == "function" then pcall(opts.Callback, opt) end
                paintOptions()
                open = false; arrow.Text = "v"
                closePopup()
                queueSave()
            end)
        end

        local function setOpen(state)
            open = state
            arrow.Text = open and "^" or "v"
            if open then
                closePopup()
                local h = math.clamp(#options * 27 + 10, 26, 190)
                list.Size = UDim2.fromOffset(f.AbsoluteSize.X, h)
                list.Visible = true
                activePopup = { list = list, anchor = f }
                repositionPopup()
                paintOptions()
            else
                list.Visible = false
                if activePopup and activePopup.list == list then activePopup = nil end
            end
        end

        addClick(f, function() setOpen(not open) end)
        function obj:Set(v)
            current = v; obj.CurrentOption = v
            sel.Text = tostring(v)
            if type(opts.Callback) == "function" then pcall(opts.Callback, v) end
            paintOptions()
        end
        return obj
    end

    return Tab
end

----------------------------------------------------------------
-- Общие игровые хелперы
----------------------------------------------------------------
local function getHumanoid(char) return char and char:FindFirstChildOfClass("Humanoid") end
local function isAlive(char)
    if not char or not char.Parent then return false end
    local hum = getHumanoid(char)
    return hum ~= nil and hum.Health > 0
end
local function isEnemy(player)
    if player == LocalPlayer then return false end
    local mine, theirs = LocalPlayer.Team, player.Team
    if not mine or not theirs then return true end
    if LocalPlayer.Neutral or player.Neutral then return true end
    return theirs ~= mine
end
local function getBestPart(char)
    if not char then return nil end
    for _, n in ipairs({ "Head", "UpperTorso", "HumanoidRootPart", "Torso" }) do
        local p = char:FindFirstChild(n)
        if p and p:IsA("BasePart") then return p end
    end
    return nil
end
local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

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
-- Stealth: единый __namecall hook
--  1) блокирует client-side Kick (анти-кик для fly)
--  2) hitbox expander БЕЗ part.Size: перехват лучей и математическое
--     расширение радиуса попадания (если луч прошёл в радиусе R от части
--     врага — перенаправляем луч, чтобы оригинальный Raycast вернул hit)
----------------------------------------------------------------
local hookInstalled, origNamecall, gameMt = false, nil, nil

local function isLocalOrigin(origin)
    local root = getRoot()
    if root and (origin - root.Position).Magnitude < 20 then return true end
    if Camera and (origin - Camera.CFrame.Position).Magnitude < 6 then return true end
    return false
end

-- расстояние от точки до отрезка луча
local function rayDistance(origin, dir, point)
    local len = dir.Magnitude
    if len < 0.001 then return math.huge end
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
                for _, pn in ipairs({ "Head", "UpperTorso", "HumanoidRootPart" }) do
                    local part = char:FindFirstChild(pn)
                    if part and part:IsA("BasePart") then
                        local d = rayDistance(origin, dir, part.Position)
                        local allow = radius + part.Size.X * 0.5
                        if d <= allow and d < bestD then
                            bestD = d; bestPart = part; bestPos = part.Position
                        end
                    end
                end
            end
        end
    end
    return bestPart, bestPos
end

local function HookBody(self, ...)
    -- анти-кик: блокируем client Kick
    local method = getnamecallmethod()
    if (method == "Kick" or method == "kick") and self == LocalPlayer then
        if not (type(checkcaller) == "function" and checkcaller()) then
            return nil
        end
        return origNamecall(self, ...)
    end
    -- hitbox: перехват лучей
    if not internalRay and Settings.Hitbox.Enabled and self == workspace then
        if method == "Raycast" then
            local origin, direction = select(1, ...), select(2, ...)
            if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" and isLocalOrigin(origin) then
                local part, pos = findEnemyPartNearRay(origin, direction, Settings.Hitbox.Radius)
                if part then
                    local args = { ... }
                    local newDir = pos - origin
                    if newDir.Magnitude > 0.01 then
                        args[2] = newDir.Unit * direction.Magnitude
                    end
                    return origNamecall(self, table.unpack(args))
                end
            end
            return origNamecall(self, ...)
        elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" then
            local ray = select(1, ...)
            if typeof(ray) == "Ray" and isLocalOrigin(ray.Origin) then
                local part, pos = findEnemyPartNearRay(ray.Origin, ray.Direction, Settings.Hitbox.Radius)
                if part then
                    local args = { ... }
                    local newDir = pos - ray.Origin
                    if newDir.Magnitude > 0.01 then
                        args[1] = Ray.new(ray.Origin, newDir.Unit * ray.Direction.Magnitude)
                    end
                    return origNamecall(self, table.unpack(args))
                end
            end
            return origNamecall(self, ...)
        end
    end
    return origNamecall(self, ...)
end

local function installHook()
    if hookInstalled then return end
    if type(getrawmetatable) ~= "function" or type(setreadonly) ~= "function"
        or type(newcclosure) ~= "function" or type(getnamecallmethod) ~= "function" then
        return
    end
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
    pcall(setreadonly, gameMt, false)
    gameMt.__namecall = origNamecall
    pcall(setreadonly, gameMt, true)
    hookInstalled = false
end

installHook()

----------------------------------------------------------------
-- ESP: пул Drawing-объектов (Acquire/Release; Remove только при выходе)
----------------------------------------------------------------
local drawingAvailable = type(Drawing) == "table" and type(Drawing.new) == "function"
local Pool = { Square = {}, Line = {}, Text = {} }
local Free = setmetatable({}, { __mode = "k" })

local function Acquire(cls)
    if not drawingAvailable then return nil end
    local pool = Pool[cls]
    for i = 1, #pool do
        local obj = pool[i]
        if Free[obj] then Free[obj] = false; return obj end
    end
    local ok, d = pcall(Drawing.new, cls)
    if not ok or not d then return nil end
    table.insert(pool, d)
    Free[d] = false
    return d
end

local function Release(obj)
    if not obj then return end
    pcall(function() obj.Visible = false end)
    Free[obj] = true
end

local function NukePool()
    for _, pool in pairs(Pool) do
        for i = 1, #pool do pcall(function() pool[i]:Remove() end) end
        table.clear(pool)
    end
end

local espEntries = {}

local function releaseEntry(e)
    if e.box then Release(e.box); e.box = nil end
    if e.hpBg then Release(e.hpBg); e.hpBg = nil end
    if e.hpFill then Release(e.hpFill); e.hpFill = nil end
    if e.tracer then Release(e.tracer); e.tracer = nil end
    if e.name then Release(e.name); e.name = nil end
    if e.dist then Release(e.dist); e.dist = nil end
end

local function destroyEntry(plr)
    local e = espEntries[plr]
    if not e then return end
    releaseEntry(e)
    if e.chams then pcall(function() e.chams:Destroy() end) e.chams = nil end
    espEntries[plr] = nil
end

connect(Players.PlayerRemoving, destroyEntry)

local function updateESP()
    if not drawingAvailable or not Camera then return end
    if not Settings.Visuals.Enabled then
        for _, e in pairs(espEntries) do releaseEntry(e) if e.chams then e.chams.Enabled = false end end
        return
    end
    local camPos = Camera.CFrame.Position
    local viewport = Camera.ViewportSize

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local e = espEntries[plr]
        if not e then e = {}; espEntries[plr] = e end

        local char = plr.Character
        local hum = getHumanoid(char)
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")

        if not isAlive(char) or not root then
            releaseEntry(e)
            if e.chams then e.chams.Enabled = false end
            continue
        end
        if Settings.Visuals.OnlyEnemies and not isEnemy(plr) then
            releaseEntry(e)
            if e.chams then e.chams.Enabled = false end
            continue
        end
        local dist = (root.Position - camPos).Magnitude
        if dist > Settings.Visuals.MaxDistance then
            releaseEntry(e)
            if e.chams then e.chams.Enabled = false end
            continue
        end

        local color = isEnemy(plr) and Color3.fromRGB(255, 62, 62) or Color3.fromRGB(90, 140, 255)
        local headPos = (head and head.Position) or (root.Position + Vector3.new(0, 2.5, 0))
        local legPos = root.Position - Vector3.new(0, 2.5, 0)
        local headSp = Camera:WorldToViewportPoint(headPos)
        local legSp = Camera:WorldToViewportPoint(legPos)

        if headSp.Z < 0 and legSp.Z < 0 then
            releaseEntry(e)
            continue
        end

        local height = math.abs(legSp.Y - headSp.Y)
        local width = height * 0.5
        local x = headSp.X - width * 0.5
        local y = headSp.Y

        if Settings.Visuals.Boxes then
            e.box = e.box or Acquire("Square")
            if e.box then
                e.box.Filled = false; e.box.Thickness = 1
                e.box.Size = Vector2.new(width, height)
                e.box.Position = Vector2.new(x, y)
                e.box.Color = color
                e.box.Visible = true
            end
        elseif e.box then Release(e.box); e.box = nil end

        if Settings.Visuals.HealthBar and hum.MaxHealth > 0 then
            e.hpBg = e.hpBg or Acquire("Square")
            e.hpFill = e.hpFill or Acquire("Square")
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            if e.hpBg then
                e.hpBg.Filled = true; e.hpBg.Color = Color3.fromRGB(0, 0, 0)
                e.hpBg.Size = Vector2.new(3, height)
                e.hpBg.Position = Vector2.new(x - 5, y)
                e.hpBg.Visible = true
            end
            if e.hpFill then
                local barH = height * pct
                e.hpFill.Filled = true
                e.hpFill.Size = Vector2.new(3, barH)
                e.hpFill.Position = Vector2.new(x - 5, y + (height - barH))
                e.hpFill.Color = Color3.fromRGB(60, 220, 60):Lerp(Color3.fromRGB(220, 60, 60), 1 - pct)
                e.hpFill.Visible = true
            end
        else
            if e.hpBg then Release(e.hpBg); e.hpBg = nil end
            if e.hpFill then Release(e.hpFill); e.hpFill = nil end
        end

        if Settings.Visuals.Tracers then
            e.tracer = e.tracer or Acquire("Line")
            if e.tracer then
                e.tracer.Thickness = 1
                e.tracer.From = Vector2.new(viewport.X * 0.5, viewport.Y)
                e.tracer.To = Vector2.new(headSp.X, headSp.Y)
                e.tracer.Color = color
                e.tracer.Visible = true
            end
        elseif e.tracer then Release(e.tracer); e.tracer = nil end

        if Settings.Visuals.Names then
            e.name = e.name or Acquire("Text")
            if e.name then
                local nm = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
                e.name.Text = nm; e.name.Size = 13; e.name.Center = true; e.name.Outline = true
                e.name.Position = Vector2.new(headSp.X, y - 16)
                e.name.Color = color
                e.name.Visible = true
            end
        elseif e.name then Release(e.name); e.name = nil end

        if Settings.Visuals.Distance then
            e.dist = e.dist or Acquire("Text")
            if e.dist then
                e.dist.Text = tostring(math.floor(dist)) .. "m"
                e.dist.Size = 12; e.dist.Center = true; e.dist.Outline = true
                e.dist.Position = Vector2.new(headSp.X, y + height + 4)
                e.dist.Color = Color3.fromRGB(255, 255, 255)
                e.dist.Visible = true
            end
        elseif e.dist then Release(e.dist); e.dist = nil end

        if Settings.Visuals.Chams then
            if not e.chams or e.chams.Parent ~= char then
                if e.chams then pcall(function() e.chams:Destroy() end) end
                local h = Instance.new("Highlight")
                h.FillColor = color
                h.OutlineColor = Color3.fromRGB(255, 255, 255)
                h.FillTransparency = 0.5
                pcall(function() h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
                h.Adornee = char
                h.Parent = char
                e.chams = h
            else
                e.chams.FillColor = color
                e.chams.Enabled = true
            end
        elseif e.chams then e.chams.Enabled = false end
    end
end

bindRender("UnknownESP", Enum.RenderPriority.Camera.Value + 2, updateESP)

----------------------------------------------------------------
-- Aimbot: гистерезис цели (hold 0.2s) + FOV circle
----------------------------------------------------------------
local fovCircle = nil
if drawingAvailable then
    local ok, c = pcall(function() return Drawing.new("Circle") end)
    if ok and c then
        fovCircle = c
        fovCircle.Thickness = 2; fovCircle.NumSides = 48
        fovCircle.Filled = false; fovCircle.Color = C.accent
        fovCircle.Visible = false
    end
end

local lockedTarget = nil
local lockedLastSeen = 0
local HOLD_TIME = 0.2

local function scanBest()
    if not Camera or not LocalPlayer.Character then return nil end
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local best, bestD = nil, Settings.Aimbot.FOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if Settings.Aimbot.WallCheck and Settings.Aimbot.OnlyEnemies and not isEnemy(plr) then continue end
        if not isEnemy(plr) and Settings.Aimbot.OnlyEnemies then continue end
        local char = plr.Character
        if not isAlive(char) then continue end
        local part = getBestPart(char)
        if not part then continue end
        local pos = part.Position
        if Settings.Aimbot.Prediction > 0 then
            local vel = part.AssemblyLinearVelocity
            if vel.Magnitude < 500 then
                local lead = vel * Settings.Aimbot.Prediction
                if lead.Magnitude > 35 then lead = lead.Unit * 35 end
                pos = pos + lead
            end
        end
        local sp, on = Camera:WorldToViewportPoint(pos)
        if not on or sp.Z < 0 then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d <= bestD then
            if not Settings.Aimbot.WallCheck or isVisible(pos, char) then
                bestD = d
                best = { player = plr, char = char, part = part, pos = pos, dist = d }
            end
        end
    end
    return best
end

local function pickTarget()
    local now = os.clock()
    local best = scanBest()

    if lockedTarget and lockedTarget.char and lockedTarget.char.Parent and isAlive(lockedTarget.char)
        and lockedTarget.part and lockedTarget.part.Parent then
        local sp, on = Camera:WorldToViewportPoint(lockedTarget.part.Position)
        if on and sp.Z > 0 then lockedLastSeen = now end
        local fresh = (now - lockedLastSeen) <= HOLD_TIME
        if fresh then
            -- переключаемся только если новая цель заметно ближе
            if best and best.player ~= lockedTarget.player and best.dist < (lockedTarget.dist or 9999) * 0.7 then
                lockedTarget = best; lockedLastSeen = now
                return best
            end
            return lockedTarget
        end
    end

    lockedTarget = best
    lockedLastSeen = now
    return best
end

local function updateAim(dt)
    Camera = workspace.CurrentCamera
    if fovCircle then
        if Settings.Aimbot.Enabled and Settings.Aimbot.ShowFOVCircle and Camera then
            local vp = Camera.ViewportSize
            fovCircle.Position = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
            fovCircle.Radius = Settings.Aimbot.FOV
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end
    if not Settings.Aimbot.Enabled or not Camera then return end
    local t = pickTarget()
    if t then
        local cam = Camera.CFrame
        local desired = CFrame.lookAt(cam.Position, t.pos)
        local sm = math.max(Settings.Aimbot.Smoothing, 0.5)
        local alpha = math.clamp(1 - math.exp(-(dt or 1/60) * (60 / sm)), 0, 1)
        if Settings.Aimbot.HitChance < 100 and math.random(1, 100) > Settings.Aimbot.HitChance then
            local rnd = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
            if rnd.Magnitude > 0.001 then desired = CFrame.lookAt(cam.Position, t.pos + rnd.Unit * 4) end
        end
        Camera.CFrame = cam:Lerp(desired, alpha)
    end
end

bindRender("UnknownAim", Enum.RenderPriority.Camera.Value + 1, updateAim)

----------------------------------------------------------------
-- Movement: speed (4 режима) + fly (LinearVelocity / CFrame) + misc
----------------------------------------------------------------
local fly = { att = nil, lv = nil, ao = nil, on = false }

local function destroyFly()
    if fly.lv then pcall(function() fly.lv:Destroy() end) end
    if fly.ao then pcall(function() fly.ao:Destroy() end) end
    if fly.att then pcall(function() fly.att:Destroy() end) end
    fly.lv, fly.ao, fly.att = nil, nil, nil
    fly.on = false
end

local function createFly(root)
    destroyFly()
    fly.att = new("Attachment", { Parent = root })
    fly.lv = new("LinearVelocity", {
        Attachment0 = fly.att, MaxForce = math.huge,
        VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
        VectorVelocity = Vector3.zero, Parent = root,
    })
    fly.ao = new("AlignOrientation", {
        Attachment0 = fly.att, MaxTorque = math.huge,
        Responsiveness = 200, Mode = Enum.OrientationAlignmentMode.OneAttachment,
        Parent = root,
    })
    fly.on = true
end

local originalWalk = nil
local lastJump = 0

local function restoreSpeed(hum)
    if originalWalk and hum then
        if hum.WalkSpeed ~= originalWalk then hum.WalkSpeed = originalWalk end
    end
end

----------------------------------------------------------------
-- Combat: kill aura (wallcheck + human rhythm) + auto clicker
----------------------------------------------------------------
local auraNext = 0
local clickAcc = 0

local function killAuraStep(now)
    if now < auraNext then return end
    local root = getRoot()
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not root or not tool then auraNext = now + 0.2; return end

    local best, bestD = nil, Settings.Combat.AuraRange
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer or not isEnemy(plr) then continue end
        local oc = plr.Character
        if not isAlive(oc) then continue end
        local oroot = oc:FindFirstChild("HumanoidRootPart")
        if not oroot then continue end
        local d = (oroot.Position - root.Position).Magnitude
        if d < bestD then bestD = d; best = oroot end
    end

    if best and isVisible(best.Position, best.Parent) then
        local look = best.Position - root.Position
        look = Vector3.new(look.X, 0, look.Z)
        if look.Magnitude > 0.1 then
            pcall(function() root.CFrame = CFrame.lookAt(root.Position, root.Position + look) end)
        end
        pcall(function() tool:Activate() end)
        -- человеческий ритм: микрорандомизация задержки
        auraNext = now + 0.25 + math.random() * 0.35
    else
        auraNext = now + 0.1
    end
end

local function doClick()
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
    if type(mouse1click) == "function" then pcall(mouse1click) end
end

----------------------------------------------------------------
-- Misc: anti-afk (VIM эмуляция), fullbright, low graphics
----------------------------------------------------------------
local afkNext = 0
local AFK_KEYS = { "Space", "Left", "Right", "Up", "Down" }

local function afkStep(now)
    if now < afkNext then return end
    local k = AFK_KEYS[math.random(1, #AFK_KEYS)]
    pcall(function()
        VirtualInput:SendKeyEvent(true, k, false, game)
        task.delay(0.15, function()
            pcall(function() VirtualInput:SendKeyEvent(false, k, false, game) end)
        end)
    end)
    afkNext = now + 60 + math.random() * 60
end

local lightOrig = nil
local function applyFullbright(on)
    if on then
        if not lightOrig then
            lightOrig = {
                Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
                FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
            }
        end
        Lighting.Brightness = 2; Lighting.ClockTime = 14
        Lighting.FogEnd = 100000; Lighting.GlobalShadows = false
    elseif lightOrig then
        Lighting.Brightness = lightOrig.Brightness
        Lighting.ClockTime = lightOrig.ClockTime
        Lighting.FogEnd = lightOrig.FogEnd
        Lighting.GlobalShadows = lightOrig.GlobalShadows
        lightOrig = nil
    end
end

local function applyLowGraphics(on)
    pcall(function()
        local Rendering = settings and settings():FindFirstChild("Rendering")
        if not Rendering then return end
        if on then
            if type(sethiddenproperty) == "function" then
                sethiddenproperty(Rendering, "QualityLevel", Enum.QualityLevel.Level01)
            end
        else
            if type(sethiddenproperty) == "function" then
                sethiddenproperty(Rendering, "QualityLevel", Enum.QualityLevel.Automatic)
            end
        end
    end)
end

----------------------------------------------------------------
-- Heartbeat (единый цикл, без while task.wait)
----------------------------------------------------------------
connect(RunService.Heartbeat, function(dt)
    local char = LocalPlayer.Character
    local hum = getHumanoid(char)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local now = os.clock()

    if not char or not hum or not root then
        if fly.on then destroyFly() end
        return
    end

    -- Speed: 4 режима обхода
    if Settings.Speed.Enabled then
        local v = Settings.Speed.Value
        local mode = Settings.Speed.Mode
        if mode == "WalkSpeed" or mode == "Loop" then
            if originalWalk == nil then originalWalk = hum.WalkSpeed end
            if hum.WalkSpeed ~= v then hum.WalkSpeed = v end
        elseif mode == "Velocity" then
            local md = hum.MoveDirection
            if md.Magnitude > 0.1 then
                local cur = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(md.X * v, cur.Y, md.Z * v)
            end
        elseif mode == "CFrame" then
            local md = hum.MoveDirection
            if md.Magnitude > 0.1 then
                root.CFrame = root.CFrame + md * v * dt
            end
        end
    elseif originalWalk then
        restoreSpeed(hum)
        originalWalk = nil
    end

    -- NoClip
    if Settings.Move.NoClip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end

    -- Infinite Jump
    if Settings.Move.InfJump and UserInputService:IsKeyDown(Enum.KeyCode.Space) and now - lastJump > 0.25 then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        lastJump = now
    end

    -- Fly: LinearVelocity или CFrame (низкая velocity-сигнатура)
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
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
        local speed = Settings.Fly.Value

        if Settings.Fly.Mode == "LinearVelocity" then
            if not fly.on or not (fly.lv and fly.lv.Parent == root) then createFly(root) end
            if fly.on then
                fly.lv.VectorVelocity = (move.Magnitude > 0) and (move.Unit * speed) or Vector3.zero
                if fly.ao and Camera then fly.ao.CFrame = Camera.CFrame end
            end
        else -- CFrame
            if fly.on then destroyFly() end
            if move.Magnitude > 0 then
                root.CFrame = root.CFrame + move.Unit * speed * dt
            end
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    elseif fly.on then
        destroyFly()
    end

    -- Combat
    if Settings.Combat.KillAura then killAuraStep(now) else auraNext = 0 end
    if Settings.Combat.AutoClicker then
        clickAcc = clickAcc + dt
        local interval = 1 / math.max(Settings.Combat.CPS, 1)
        while clickAcc >= interval do
            clickAcc = clickAcc - interval
            doClick()
        end
    else
        clickAcc = 0
    end

    -- Misc anti-afk
    if Settings.Misc.AntiAFK then afkStep(now) else afkNext = 0 end
end)

connect(LocalPlayer.CharacterAdded, function()
    destroyFly()
    originalWalk = nil
    lockedTarget = nil
end)

----------------------------------------------------------------
-- Сборка GUI (значения берутся из Settings — конфиг уже применён)
----------------------------------------------------------------
local TabCombat = createTab("combat")
TabCombat:CreateSection("aimbot")
TabCombat:CreateToggle({ Name = "Aimbot", CurrentValue = Settings.Aimbot.Enabled, Callback = function(v) Settings.Aimbot.Enabled = v queueSave() end })
TabCombat:CreateToggle({ Name = "Показать круг FOV", CurrentValue = Settings.Aimbot.ShowFOVCircle, Callback = function(v) Settings.Aimbot.ShowFOVCircle = v queueSave() end })
TabCombat:CreateToggle({ Name = "Wall Check", CurrentValue = Settings.Aimbot.WallCheck, Callback = function(v) Settings.Aimbot.WallCheck = v queueSave() end })
TabCombat:CreateToggle({ Name = "Only Enemies", CurrentValue = Settings.Aimbot.OnlyEnemies, Callback = function(v) Settings.Aimbot.OnlyEnemies = v queueSave() end })
TabCombat:CreateSlider({ Name = "FOV", Range = { 10, 600 }, Increment = 10, CurrentValue = Settings.Aimbot.FOV, Callback = function(v) Settings.Aimbot.FOV = v queueSave() end })
TabCombat:CreateSlider({ Name = "Smoothing", Range = { 1, 20 }, Increment = 1, CurrentValue = Settings.Aimbot.Smoothing, Callback = function(v) Settings.Aimbot.Smoothing = v queueSave() end })
TabCombat:CreateSlider({ Name = "Prediction", Range = { 0, 0.5 }, Increment = 0.01, CurrentValue = Settings.Aimbot.Prediction, Callback = function(v) Settings.Aimbot.Prediction = v queueSave() end })
TabCombat:CreateSlider({ Name = "Hit Chance", Range = { 10, 100 }, Increment = 5, Suffix = "%", CurrentValue = Settings.Aimbot.HitChance, Callback = function(v) Settings.Aimbot.HitChance = v queueSave() end })
TabCombat:CreateSection("hitbox (stealth)")
TabCombat:CreateToggle({ Name = "Hitbox (ray hook)", CurrentValue = Settings.Hitbox.Enabled, Callback = function(v) Settings.Hitbox.Enabled = v queueSave() end })
TabCombat:CreateSlider({ Name = "Радиус попадания", Range = { 1, 15 }, Increment = 1, CurrentValue = Settings.Hitbox.Radius, Callback = function(v) Settings.Hitbox.Radius = v queueSave() end })
TabCombat:CreateSection("pvp")
TabCombat:CreateToggle({ Name = "Kill Aura", CurrentValue = Settings.Combat.KillAura, Callback = function(v) Settings.Combat.KillAura = v queueSave() end })
TabCombat:CreateSlider({ Name = "Aura Range", Range = { 5, 30 }, Increment = 1, CurrentValue = Settings.Combat.AuraRange, Callback = function(v) Settings.Combat.AuraRange = v queueSave() end })
TabCombat:CreateToggle({ Name = "Auto Clicker", CurrentValue = Settings.Combat.AutoClicker, Callback = function(v) Settings.Combat.AutoClicker = v queueSave() end })
TabCombat:CreateSlider({ Name = "CPS", Range = { 1, 30 }, Increment = 1, CurrentValue = Settings.Combat.CPS, Callback = function(v) Settings.Combat.CPS = v queueSave() end })

local TabVisuals = createTab("visuals")
TabVisuals:CreateSection("esp")
TabVisuals:CreateToggle({ Name = "Enable ESP", CurrentValue = Settings.Visuals.Enabled, Callback = function(v) Settings.Visuals.Enabled = v queueSave() end })
TabVisuals:CreateToggle({ Name = "Boxes", CurrentValue = Settings.Visuals.Boxes, Callback = function(v) Settings.Visuals.Boxes = v queueSave() end })
TabVisuals:CreateToggle({ Name = "Health Bar", CurrentValue = Settings.Visuals.HealthBar, Callback = function(v) Settings.Visuals.HealthBar = v queueSave() end })
TabVisuals:CreateToggle({ Name = "Show Tracers", CurrentValue = Settings.Visuals.Tracers, Callback = function(v) Settings.Visuals.Tracers = v queueSave() end })
TabVisuals:CreateToggle({ Name = "Names", CurrentValue = Settings.Visuals.Names, Callback = function(v) Settings.Visuals.Names = v queueSave() end })
TabVisuals:CreateToggle({ Name = "Distance", CurrentValue = Settings.Visuals.Distance, Callback = function(v) Settings.Visuals.Distance = v queueSave() end })
TabVisuals:CreateToggle({ Name = "Chams", CurrentValue = Settings.Visuals.Chams, Callback = function(v) Settings.Visuals.Chams = v queueSave() end })
TabVisuals:CreateToggle({ Name = "Only Enemies", CurrentValue = Settings.Visuals.OnlyEnemies, Callback = function(v) Settings.Visuals.OnlyEnemies = v queueSave() end })
TabVisuals:CreateSlider({ Name = "Max Distance", Range = { 50, 2000 }, Increment = 50, CurrentValue = Settings.Visuals.MaxDistance, Callback = function(v) Settings.Visuals.MaxDistance = v queueSave() end })

local TabMove = createTab("movement")
TabMove:CreateSection("speedhack")
TabMove:CreateToggle({ Name = "Speed Hack", CurrentValue = Settings.Speed.Enabled, Callback = function(v) Settings.Speed.Enabled = v queueSave() end })
TabMove:CreateDropdown({ Name = "Режим обхода", Options = { "WalkSpeed", "Loop", "Velocity", "CFrame" }, CurrentOption = Settings.Speed.Mode, Callback = function(v) Settings.Speed.Mode = v queueSave() end })
TabMove:CreateSlider({ Name = "Walk Speed", Range = { 16, 200 }, Increment = 1, CurrentValue = Settings.Speed.Value, Callback = function(v) Settings.Speed.Value = v queueSave() end })
TabMove:CreateSection("fly")
TabMove:CreateToggle({ Name = "Fly", CurrentValue = Settings.Fly.Enabled, Callback = function(v) Settings.Fly.Enabled = v queueSave() end })
TabMove:CreateDropdown({ Name = "Fly Mode", Options = { "LinearVelocity", "CFrame" }, CurrentOption = Settings.Fly.Mode, Callback = function(v) Settings.Fly.Mode = v queueSave() end })
TabMove:CreateToggle({ Name = "Anti-Kick", CurrentValue = Settings.Fly.AntiKick, Callback = function(v) Settings.Fly.AntiKick = v if v then installHook() end queueSave() end })
TabMove:CreateSlider({ Name = "Fly Speed", Range = { 20, 200 }, Increment = 5, CurrentValue = Settings.Fly.Value, Callback = function(v) Settings.Fly.Value = v queueSave() end })
TabMove:CreateSection("other")
TabMove:CreateToggle({ Name = "NoClip", CurrentValue = Settings.Move.NoClip, Callback = function(v) Settings.Move.NoClip = v queueSave() end })
TabMove:CreateToggle({ Name = "Infinite Jump", CurrentValue = Settings.Move.InfJump, Callback = function(v) Settings.Move.InfJump = v queueSave() end })

local TabMisc = createTab("misc")
TabMisc:CreateSection("справка")
TabMisc:CreateLabel("aimbot — плавно ведёт камеру к цели (fov, smoothing, prediction)")
TabMisc:CreateLabel("esp — рамки, хп, имена, трекеры и chams игроков")
TabMisc:CreateLabel("speed — 4 обхода: walkspeed / loop / velocity / cframe")
TabMisc:CreateLabel("fly — полёт на linearvelocity или cframe + анти-кик")
TabMisc:CreateLabel("hitbox — перехват лучей: попадания в радиусе без изменения моделей")
TabMisc:CreateLabel("kill aura — авто-удары с проверкой стен и человеческим ритмом")
TabMisc:CreateLabel("noclip / inf jump — сквозь стены и бесконечный прыжок")
TabMisc:CreateSection("приколюхи")
TabMisc:CreateToggle({ Name = "Anti-AFK (эмуляция ввода)", CurrentValue = Settings.Misc.AntiAFK, Callback = function(v) Settings.Misc.AntiAFK = v queueSave() end })
TabMisc:CreateToggle({ Name = "Fullbright", CurrentValue = Settings.Misc.Fullbright, Callback = function(v) Settings.Misc.Fullbright = v applyFullbright(v) queueSave() end })
TabMisc:CreateToggle({ Name = "Low Graphics (fps boost)", CurrentValue = Settings.Misc.LowGraphics, Callback = function(v) Settings.Misc.LowGraphics = v applyLowGraphics(v) queueSave() end })
TabMisc:CreateSlider({ Name = "UI Scale", Range = { 80, 120 }, Increment = 5, Suffix = "%", CurrentValue = Settings.Misc.UIScale, Callback = function(v) Settings.Misc.UIScale = v uiScale.Scale = v / 100 repositionPopup() queueSave() end })
TabMisc:CreateButton({ Name = "Server Hop", Callback = function()
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end })
TabMisc:CreateButton({ Name = "Rejoin", Callback = function()
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end })
TabMisc:CreateButton({ Name = "Copy My Position", Callback = function()
    local root = getRoot()
    if root and type(setclipboard) == "function" then
        local p = root.Position
        setclipboard(string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z))
    end
end })
TabMisc:CreateButton({ Name = "Hide GUI", Callback = function() main.Visible = false end })

-- самоуничтожение (в самом конце списка)
local destroyBtn = TabMisc:CreateButton({ Name = "ПОЛНОЕ САМОУНИЧТОЖЕНИЕ", Callback = function() end })

----------------------------------------------------------------
-- Окно: drag / resize / minimize / hide + popup reposition
----------------------------------------------------------------
local dragging, dragStart, startPos = false, nil, nil
local resizing, resizeStart, resizeStartSize = false, nil, nil

connect(topbar.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if input.Target:IsA("TextButton") then return end
        dragging = true; dragStart = input.Position; startPos = main.Position
    end
end)
connect(resizeHandle.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true; resizeStart = input.Position
        resizeStartSize = Vector2.new(main.Size.X.Offset, main.Size.Y.Offset)
    end
end)
connect(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(0.5, startPos.X.Offset + d.X, 0.5, startPos.Y.Offset + d.Y)
        repositionPopup()
    end
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - resizeStart
        local w = math.clamp(resizeStartSize.X + d.X, 460, 820)
        local h = math.clamp(resizeStartSize.Y + d.Y, 380, 700)
        main.Size = UDim2.fromOffset(w, h)
        repositionPopup()
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false; resizing = false
    end
end)

local minimized = false
connect(minBtn.MouseButton1Click, function()
    minimized = not minimized
    if minimized then
        sidebar.Visible = false; pages.Visible = false; resizeHandle.Visible = false
        tween(main, 0.2, { Size = UDim2.fromOffset(main.Size.X.Offset, 46) })
    else
        sidebar.Visible = true; pages.Visible = true; resizeHandle.Visible = true
        tween(main, 0.2, { Size = UDim2.fromOffset(main.Size.X.Offset, 470) })
    end
    closePopup()
end)
connect(closeBtn.MouseButton1Click, function() main.Visible = false end)
connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)

-- закрытие dropdown по клику вне
connect(UserInputService.InputBegan, function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if not activePopup or not activePopup.list.Visible then return end
    local p = input.Position
    local lp, ls = activePopup.list.AbsolutePosition, activePopup.list.AbsoluteSize
    local ap, as = activePopup.anchor.AbsolutePosition, activePopup.anchor.AbsoluteSize
    local inList = p.X >= lp.X and p.X <= lp.X + ls.X and p.Y >= lp.Y and p.Y <= lp.Y + ls.Y
    local inAnchor = p.X >= ap.X and p.X <= ap.X + as.X and p.Y >= ap.Y and p.Y <= ap.Y + as.Y
    if not inList and not inAnchor then closePopup() end
end)

----------------------------------------------------------------
-- Полное самоуничтожение: чита как будто не было
----------------------------------------------------------------
local unloaded = false

local function FullUnload()
    if unloaded then return end
    unloaded = true
    -- восстановление мира
    local char = LocalPlayer.Character
    local hum = getHumanoid(char)
    pcall(function() restoreSpeed(hum) end)
    pcall(destroyFly)
    pcall(function() applyFullbright(false) end)
    if char then
        pcall(function()
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end)
    end
    -- снятие хуков
    pcall(uninstallHook)
    -- unbind render steps
    for _, name in ipairs(renderSteps) do
        pcall(function() RunService:UnbindFromRenderStep(name) end)
    end
    -- все соединения
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end) end
    table.clear(connections)
    -- drawing pool + chams
    for plr in pairs(espEntries) do destroyEntry(plr) end
    NukePool()
    if fovCircle then pcall(function() fovCircle:Remove() end) fovCircle = nil end
    -- gui
    if screenGui then pcall(function() screenGui:Destroy() end) end
end

-- кнопка с обратным отсчётом 5 секунд
local selfDestructArmed = false
destroyBtn.Set(nil and nil or nil, "ПОЛНОЕ САМОУНИЧТОЖЕНИЕ") -- no-op guard (API совместимость)
-- переподключаем callback кнопки через overlay: используем прямой клик
-- (кнопка создавалась без callback — вешаем обработчик здесь)
-- NOTE: CreateButton уже создал overlay; чтобы не дублировать, countdown
-- запускается через отдельный перехват: пересоздаём поведение через Label.
-- Проще: кнопка Hide GUI выше, а самоуничтожение делаем отдельной кнопкой
-- с callback через замыкание — см. ниже (перезапись через метатаблицу не нужна,
-- т.к. callback передаётся при создании). Поэтому создаём кнопку заново:

-- (предыдущая destroyBtn создана без callback — заменяем её текст и вешаем
--  логику через UserInputService на её overlay невозможно; создаём финальную
--  кнопку корректно:)
-- [финальная версия кнопки самоуничтожения]
local finalBtn = TabMisc:CreateButton({
    Name = "УНИЧТОЖИТЬ ЧИТ (5s)",
    Callback = function()
        if selfDestructArmed then return end
        selfDestructArmed = true
        task.spawn(function()
            for i = 5, 1, -1 do
                finalBtn.Set(nil, "САМОУНИЧТОЖЕНИЕ: " .. i)
                task.wait(1)
            end
            FullUnload()
        end)
    end,
})
-- убираем дублирующую пустую кнопку (первую) — скрываем её frame невозможно
-- без ссылки; вместо этого первая кнопка переименовывается в разделитель:
destroyBtn.Set(nil, " ")

-- пост-инициализация из конфига
applyFullbright(Settings.Misc.Fullbright)
applyLowGraphics(Settings.Misc.LowGraphics)
uiScale.Scale = (tonumber(Settings.Misc.UIScale) or 100) / 100
queueSave()

print("[unknown] private 2027 loaded // RightShift = hide // конфиг: " .. CONFIG_PATH)
