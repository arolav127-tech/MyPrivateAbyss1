local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local Lighting         = game:GetService("Lighting")
local VirtualUser      = game:GetService("VirtualUser")

if not RunService:IsClient() then error("client only") end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
while not LocalPlayer.Character do task.wait(0.1) end

----------------------------------------------------------------
-- Settings
----------------------------------------------------------------
local Settings = {
    Aimbot = {
        Enabled = false, FOV = 90, Smoothing = 6, Prediction = 0.11,
        WallCheck = true, OnlyEnemies = true, RequireMouseDown = false,
        HitChance = 100, MaxFovDelta = 30, Hysteresis = true,
    },
    ESP = {
        Enabled = false, Boxes = true, HealthBar = true, Snaplines = false,
        Names = true, Distance = false, Chams = false,
        MaxDistance = 900, OnlyEnemies = true,
    },
    Speed = { Enabled = false, Value = 50, Mode = "WalkSpeed" },
    Fly   = { Enabled = false, Value = 60, Mode = "LinearVelocity", AntiKick = true },
    NoClip = false,
    InfJump = false,
    Hitbox = { Enabled = false, Size = 12 },
    Combat = { KillAura = false, AuraRange = 14, AutoClicker = false, CPS = 12 },
    Farm   = { CollectAura = false, AuraRadius = 30, AntiAFK = true, Fullbright = false },
}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function new(cls, props, parent)
    local inst = Instance.new(cls)
    if props then
        for k, v in pairs(props) do inst[k] = v end
    end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(parent, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

local function stroke(parent, color, th)
    return new("UIStroke", { Color = color or Color3.fromRGB(58, 70, 90), Thickness = th or 1 }, parent)
end

local function tween(obj, t, props)
    if not obj or not obj.Parent then return end
    TweenService:Create(obj, TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function getGuiParent()
    if type(gethui) == "function" then
        local ok, t = pcall(gethui)
        if ok and t then return t end
    end
    local ok, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 3) end)
    if ok and pg then return pg end
    return CoreGui
end

local Camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end)

local function getHumanoid(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

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

local function isVisible(pos, targetChar)
    if not Camera then return true end
    local ignore = { Camera }
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    rayParams.FilterDescendantsInstances = ignore
    local origin = Camera.CFrame.Position
    local dir = pos - origin
    if dir.Magnitude < 0.1 then return true end
    local hit = workspace:Raycast(origin, dir, rayParams)
    if not hit then return true end
    if targetChar and hit.Instance:IsDescendantOf(targetChar) then return true end
    return false
end

-- Velocity EMA (сглаженная скорость для prediction)
local velEMA = setmetatable({}, { __mode = "k" })
local velTS  = setmetatable({}, { __mode = "k" })
local function smoothedVel(part)
    local now = os.clock()
    local cur = part.AssemblyLinearVelocity
    if cur.Magnitude > 500 then cur = cur.Unit * 500 end
    local prev, pt = velEMA[part], velTS[part]
    local sm
    if prev and pt and (now - pt) < 2 then
        local a = 1 - math.exp(-(now - pt) / 0.1)
        sm = prev:Lerp(cur, a)
    else
        sm = cur
    end
    velEMA[part], velTS[part] = sm, now
    return sm
end

----------------------------------------------------------------
-- GUI
----------------------------------------------------------------
local guiParent = getGuiParent()
local oldGui = guiParent:FindFirstChild("AbyssUniversal")
if oldGui then pcall(function() oldGui:Destroy() end) end

local screenGui = new("ScreenGui", {
    Name = "AbyssUniversal",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
}, guiParent)

local main = new("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(540, 460),
    BackgroundColor3 = Color3.fromRGB(18, 22, 30),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = screenGui,
})
corner(main, 10)
stroke(main)

local topbar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = Color3.fromRGB(28, 36, 50),
    BorderSizePixel = 0,
    Parent = main,
})
corner(topbar, 10)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 10),
    Position = UDim2.new(0, 0, 1, -10),
    BackgroundColor3 = Color3.fromRGB(28, 36, 50),
    BorderSizePixel = 0,
    Parent = topbar,
})

new("TextLabel", {
    Size = UDim2.new(1, -150, 0, 18),
    Position = UDim2.fromOffset(14, 6),
    BackgroundTransparency = 1,
    Text = "Abyss Universal v3",
    Font = Enum.Font.GothamSemibold,
    TextSize = 15,
    TextColor3 = Color3.fromRGB(245, 248, 255),
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = topbar,
})
new("TextLabel", {
    Size = UDim2.new(1, -150, 0, 13),
    Position = UDim2.fromOffset(14, 25),
    BackgroundTransparency = 1,
    Text = "speed bypass + antikick + aura",
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextColor3 = Color3.fromRGB(160, 172, 190),
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = topbar,
})

local function topBtn(txt, off)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, off, 0.5, -13),
        BackgroundColor3 = Color3.fromRGB(40, 50, 68),
        BorderSizePixel = 0,
        Text = txt,
        TextColor3 = Color3.fromRGB(235, 240, 250),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = topbar,
    })
    corner(b, 6)
    return b
end
local closeBtn = topBtn("x", -34)
local minBtn   = topBtn("-", -66)

local sidebar = new("Frame", {
    Size = UDim2.new(0, 128, 1, -52),
    Position = UDim2.fromOffset(8, 48),
    BackgroundColor3 = Color3.fromRGB(23, 29, 40),
    BorderSizePixel = 0,
    Parent = main,
})
corner(sidebar, 8)

local tabList = new("ScrollingFrame", {
    Size = UDim2.new(1, -8, 1, -8),
    Position = UDim2.fromOffset(4, 4),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    CanvasSize = UDim2.new(),
    Parent = sidebar,
})
local tabLayout = new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, tabList)
tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    tabList.CanvasSize = UDim2.fromOffset(0, tabLayout.AbsoluteContentSize.Y + 4)
end)

local pages = new("Frame", {
    Size = UDim2.new(1, -142, 1, -52),
    Position = UDim2.fromOffset(140, 48),
    BackgroundTransparency = 1,
    Parent = main,
})

local tabs = {}
local selected = nil

local function selectTab(rec)
    selected = rec
    for _, r in ipairs(tabs) do
        local sel = (r == rec)
        r.page.Visible = sel
        r.btn.BackgroundColor3 = sel and Color3.fromRGB(52, 72, 104) or Color3.fromRGB(40, 50, 68)
        r.btn.TextColor3 = sel and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 214, 228)
    end
end

local function createTab(name)
    local page = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(70, 84, 106),
        Visible = false,
        CanvasSize = UDim2.new(),
        Parent = pages,
    })
    local layout = new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8),
    }, page)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 16)
    end)

    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(40, 50, 68),
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = Color3.fromRGB(205, 214, 228),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = tabList,
    })
    corner(btn, 6)
    stroke(btn, Color3.fromRGB(52, 64, 84))

    local rec = { name = name, page = page, btn = btn }
    table.insert(tabs, rec)
    btn.MouseButton1Click:Connect(function() selectTab(rec) end)
    btn.MouseEnter:Connect(function()
        if selected ~= rec then btn.BackgroundColor3 = Color3.fromRGB(50, 62, 84) end
    end)
    btn.MouseLeave:Connect(function()
        if selected ~= rec then btn.BackgroundColor3 = Color3.fromRGB(40, 50, 68) end
    end)
    if not selected then selectTab(rec) end

    local Tab = {}
    local order = 0
    local function nextOrder()
        order = order + 1
        return order
    end

    local function elemFrame(h)
        local f = new("Frame", {
            Size = UDim2.new(1, 0, 0, h),
            BackgroundColor3 = Color3.fromRGB(33, 42, 58),
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(),
            Parent = page,
        })
        corner(f, 7)
        stroke(f, Color3.fromRGB(48, 60, 80))
        return f
    end

    local function elemTitle(p, t)
        return new("TextLabel", {
            Size = UDim2.new(0.62, -12, 1, 0),
            Position = UDim2.fromOffset(10, 0),
            BackgroundTransparency = 1,
            Text = t,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Color3.fromRGB(240, 245, 255),
            Font = Enum.Font.Gotham,
            TextSize = 13,
            Parent = p,
        })
    end

    local function hoverize(f)
        f.MouseEnter:Connect(function() f.BackgroundColor3 = Color3.fromRGB(44, 55, 75) end)
        f.MouseLeave:Connect(function() f.BackgroundColor3 = Color3.fromRGB(33, 42, 58) end)
    end

    local function addClick(f, cb)
        local o = new("TextButton", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 5,
            Parent = f,
        })
        o.MouseButton1Click:Connect(function() pcall(cb) end)
        return o
    end

    function Tab:CreateSection(text)
        local l = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Text = "  " .. tostring(text),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Color3.fromRGB(148, 162, 183),
            Font = Enum.Font.GothamSemibold,
            TextSize = 12,
            LayoutOrder = nextOrder(),
            Parent = page,
        })
        return { Set = function(_, v) l.Text = "  " .. tostring(v) end }
    end

    function Tab:CreateLabel(text)
        local f = elemFrame(26)
        hoverize(f)
        local l = elemTitle(f, text)
        l.Size = UDim2.new(1, -14, 1, 0)
        return { Set = function(_, v) l.Text = tostring(v) end }
    end

    function Tab:CreateButton(opts)
        opts = opts or {}
        local f = elemFrame(30)
        hoverize(f)
        local l = elemTitle(f, opts.Name or "Button")
        l.Size = UDim2.new(1, -14, 1, 0)
        addClick(f, function()
            if type(opts.Callback) == "function" then opts.Callback() end
        end)
        return {}
    end

    function Tab:CreateToggle(opts)
        opts = opts or {}
        local state = opts.CurrentValue == true
        local f = elemFrame(30)
        hoverize(f)
        elemTitle(f, opts.Name or "Toggle")

        local sw = new("Frame", {
            Size = UDim2.fromOffset(38, 18),
            Position = UDim2.new(1, -48, 0.5, -9),
            BackgroundColor3 = Color3.fromRGB(20, 26, 36),
            BorderSizePixel = 0,
            Parent = f,
        })
        corner(sw, 9)
        stroke(sw, Color3.fromRGB(58, 70, 90))

        local ind = new("Frame", {
            Size = UDim2.fromOffset(12, 12),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = Color3.fromRGB(100, 111, 130),
            BorderSizePixel = 0,
            Parent = sw,
        })
        corner(ind, 6)

        local obj = { CurrentValue = state }
        local function apply(v, fire)
            state = (v == true)
            obj.CurrentValue = state
            if state then
                tween(ind, 0.15, { Position = UDim2.new(1, -15, 0.5, 0), BackgroundColor3 = Color3.fromRGB(114, 191, 255) })
            else
                tween(ind, 0.15, { Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = Color3.fromRGB(100, 111, 130) })
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

        local f = elemFrame(44)
        hoverize(f)
        elemTitle(f, opts.Name or "Slider")

        local info = new("TextLabel", {
            Size = UDim2.fromOffset(90, 14),
            Position = UDim2.new(1, -100, 0, 5),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(170, 180, 198),
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = f,
        })

        local track = new("Frame", {
            Size = UDim2.new(1, -20, 0, 6),
            Position = UDim2.fromOffset(10, 30),
            BackgroundColor3 = Color3.fromRGB(60, 75, 95),
            BorderSizePixel = 0,
            Parent = f,
        })
        corner(track, 3)

        local prog = new("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(114, 191, 255),
            BorderSizePixel = 0,
            Parent = track,
        })
        corner(prog, 3)

        local obj = { CurrentValue = value }
        local draggingSlider = false

        local function snap(v)
            v = math.clamp(v, min, max)
            return math.clamp(min + math.floor((v - min) / inc + 0.5) * inc, min, max)
        end

        local function apply(v, fire)
            v = snap(v)
            value = v
            obj.CurrentValue = v
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

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = true
                fromX(input.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                fromX(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = false
            end
        end)

        function obj:Set(v) apply(v, true) end
        apply(value, false)
        return obj
    end

    function Tab:CreateDropdown(opts)
        opts = opts or {}
        local options = opts.Options or {}
        local current = opts.CurrentOption or options[1]

        local f = elemFrame(32)
        hoverize(f)
        elemTitle(f, opts.Name or "Dropdown")

        local sel = new("TextLabel", {
            Size = UDim2.new(0.34, -26, 1, 0),
            Position = UDim2.new(0.66, -16, 0, 0),
            BackgroundTransparency = 1,
            Text = tostring(current or "None"),
            TextColor3 = Color3.fromRGB(170, 180, 198),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = f,
        })

        local arrow = new("TextLabel", {
            Size = UDim2.fromOffset(16, 32),
            Position = UDim2.new(1, -22, 0, 0),
            BackgroundTransparency = 1,
            Text = "v",
            TextColor3 = Color3.fromRGB(170, 180, 198),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            Parent = f,
        })

        local list = new("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(0, 0, 1, 4),
            BackgroundColor3 = Color3.fromRGB(28, 36, 50),
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Visible = false,
            ZIndex = 30,
            Parent = f,
        })
        corner(list, 7)
        stroke(list, Color3.fromRGB(58, 70, 90))
        local lLayout = new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, list)
        new("UIPadding", {
            PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
            PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5),
        }, list)

        local obj = { CurrentOption = current }
        local open = false

        for _, opt in ipairs(options) do
            local b = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = Color3.fromRGB(40, 50, 68),
                BorderSizePixel = 0,
                Text = "  " .. tostring(opt),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = Color3.fromRGB(205, 214, 228),
                Font = Enum.Font.Gotham,
                TextSize = 12,
                AutoButtonColor = false,
                ZIndex = 32,
                Parent = list,
            })
            corner(b, 5)
            b.MouseButton1Click:Connect(function()
                current = opt
                obj.CurrentOption = opt
                sel.Text = tostring(opt)
                if type(opts.Callback) == "function" then pcall(opts.Callback, opt) end
                open = false
                arrow.Text = "v"
                tween(list, 0.15, { Size = UDim2.new(1, 0, 0, 0) })
                task.delay(0.16, function() if not open then list.Visible = false end end)
            end)
        end

        addClick(f, function()
            open = not open
            arrow.Text = open and "^" or "v"
            list.Visible = true
            local h = math.clamp(lLayout.AbsoluteContentSize.Y + 10, 26, 150)
            tween(list, 0.15, { Size = UDim2.new(1, 0, 0, open and h or 0) })
            if not open then
                task.delay(0.16, function() if not open then list.Visible = false end end)
            end
        end)

        function obj:Set(v)
            current = v
            obj.CurrentOption = v
            sel.Text = tostring(v)
            if type(opts.Callback) == "function" then pcall(opts.Callback, v) end
        end
        return obj
    end

    return Tab
end

----------------------------------------------------------------
-- Drag + window controls
----------------------------------------------------------------
local dragging, dragStart, startPos = false, nil, nil

topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if input.Target:IsA("TextButton") then return end
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(0.5, startPos.X.Offset + d.X, 0.5, startPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        sidebar.Visible = false
        pages.Visible = false
        tween(main, 0.2, { Size = UDim2.fromOffset(main.Size.X.Offset, 44) })
    else
        sidebar.Visible = true
        pages.Visible = true
        tween(main, 0.2, { Size = UDim2.fromOffset(main.Size.X.Offset, 460) })
    end
end)
closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)

----------------------------------------------------------------
-- ESP module
----------------------------------------------------------------
local drawingAvailable = type(Drawing) == "table" and type(Drawing.new) == "function"
local esp = {}

local function hideEntry(e)
    if e.box then e.box.Visible = false end
    if e.hpBg then e.hpBg.Visible = false end
    if e.hpFill then e.hpFill.Visible = false end
    if e.snap then e.snap.Visible = false end
    if e.name then e.name.Visible = false end
    if e.dist then e.dist.Visible = false end
    if e.chams then e.chams.Enabled = false end
end

local function releaseEntry(e)
    for _, k in ipairs({ "box", "hpBg", "hpFill", "snap", "name", "dist" }) do
        local d = e[k]
        if d then pcall(function() d:Remove() end) e[k] = nil end
    end
    if e.chams then pcall(function() e.chams:Destroy() end) e.chams = nil end
end

Players.PlayerRemoving:Connect(function(plr)
    local e = esp[plr]
    if e then releaseEntry(e) esp[plr] = nil end
end)

local function updateESP()
    if not drawingAvailable or not Camera then return end
    if not Settings.ESP.Enabled then
        for _, e in pairs(esp) do hideEntry(e) end
        return
    end

    local camPos = Camera.CFrame.Position
    local viewport = Camera.ViewportSize

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        local e = esp[plr]
        if not e then e = {} esp[plr] = e end

        local char = plr.Character
        local hum = getHumanoid(char)
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")

        if not isAlive(char) or not root then
            hideEntry(e)
            continue
        end
        if Settings.ESP.OnlyEnemies and not isEnemy(plr) then
            hideEntry(e)
            continue
        end

        local dist = (root.Position - camPos).Magnitude
        if dist > Settings.ESP.MaxDistance then
            hideEntry(e)
            continue
        end

        local color = isEnemy(plr) and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(60, 140, 255)
        local headPos = (head and head.Position) or (root.Position + Vector3.new(0, 2.5, 0))
        local legPos = root.Position - Vector3.new(0, 2.5, 0)
        local headSp = Camera:WorldToViewportPoint(headPos)
        local legSp = Camera:WorldToViewportPoint(legPos)

        if headSp.Z < 0 and legSp.Z < 0 then
            hideEntry(e)
            continue
        end

        local height = math.abs(legSp.Y - headSp.Y)
        local width = height * 0.5
        local x = headSp.X - width * 0.5
        local y = headSp.Y

        if Settings.ESP.Boxes then
            if not e.box then
                e.box = Drawing.new("Square")
                e.box.Thickness = 1
                e.box.Filled = false
            end
            e.box.Size = Vector2.new(width, height)
            e.box.Position = Vector2.new(x, y)
            e.box.Color = color
            e.box.Visible = true
        elseif e.box then e.box.Visible = false end

        if Settings.ESP.HealthBar and hum.MaxHealth > 0 then
            if not e.hpBg then
                e.hpBg = Drawing.new("Square")
                e.hpBg.Filled = true
                e.hpBg.Color = Color3.fromRGB(0, 0, 0)
            end
            if not e.hpFill then
                e.hpFill = Drawing.new("Square")
                e.hpFill.Filled = true
            end
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local barH = height * pct
            e.hpBg.Size = Vector2.new(3, height)
            e.hpBg.Position = Vector2.new(x - 5, y)
            e.hpBg.Visible = true
            e.hpFill.Size = Vector2.new(3, barH)
            e.hpFill.Position = Vector2.new(x - 5, y + (height - barH))
            e.hpFill.Color = Color3.fromRGB(60, 220, 60):Lerp(Color3.fromRGB(220, 60, 60), 1 - pct)
            e.hpFill.Visible = true
        else
            if e.hpBg then e.hpBg.Visible = false end
            if e.hpFill then e.hpFill.Visible = false end
        end

        if Settings.ESP.Snaplines then
            if not e.snap then
                e.snap = Drawing.new("Line")
                e.snap.Thickness = 1
            end
            e.snap.From = Vector2.new(viewport.X * 0.5, viewport.Y)
            e.snap.To = Vector2.new(headSp.X, headSp.Y)
            e.snap.Color = color
            e.snap.Visible = true
        elseif e.snap then e.snap.Visible = false end

        if Settings.ESP.Names then
            if not e.name then
                e.name = Drawing.new("Text")
                e.name.Size = 13
                e.name.Center = true
                e.name.Outline = true
            end
            local nm = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
            e.name.Text = nm
            e.name.Position = Vector2.new(headSp.X, y - 16)
            e.name.Color = color
            e.name.Visible = true
        elseif e.name then e.name.Visible = false end

        if Settings.ESP.Distance then
            if not e.dist then
                e.dist = Drawing.new("Text")
                e.dist.Size = 12
                e.dist.Center = true
                e.dist.Outline = true
            end
            e.dist.Text = tostring(math.floor(dist)) .. "m"
            e.dist.Position = Vector2.new(headSp.X, y + height + 4)
            e.dist.Color = Color3.fromRGB(255, 255, 255)
            e.dist.Visible = true
        elseif e.dist then e.dist.Visible = false end

        if Settings.ESP.Chams then
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

pcall(function()
    RunService:BindToRenderStep("AbyssESP", Enum.RenderPriority.Camera.Value + 2, updateESP)
end)

----------------------------------------------------------------
-- Aimbot module (v2: EMA prediction + hysteresis + angular clamp)
----------------------------------------------------------------
local fovCircle = nil
if drawingAvailable then
    local ok, c = pcall(function() return Drawing.new("Circle") end)
    if ok and c then
        fovCircle = c
        fovCircle.Thickness = 2
        fovCircle.NumSides = 48
        fovCircle.Filled = false
        fovCircle.Color = Color3.fromRGB(0, 255, 120)
        fovCircle.Visible = false
    end
end

local prevTargetPlayer = nil

local function getTarget()
    if not Camera or not LocalPlayer.Character then return nil end
    if Settings.Aimbot.RequireMouseDown then
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return nil end
    end

    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local fov = Settings.Aimbot.FOV
    local best, bestD = nil, fov
    local prevEntry = nil

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if Settings.Aimbot.OnlyEnemies and not isEnemy(plr) then continue end

        local char = plr.Character
        if not isAlive(char) then continue end
        local part = getBestPart(char)
        if not part then continue end

        local pos = part.Position
        if Settings.Aimbot.Prediction > 0 then
            local vel = smoothedVel(part)
            local lead = vel * Settings.Aimbot.Prediction
            if lead.Magnitude > 35 then lead = lead.Unit * 35 end
            pos = pos + lead
        end

        local sp, onScreen = Camera:WorldToViewportPoint(pos)
        if not onScreen or sp.Z < 0 then continue end

        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d <= fov then
            if Settings.Aimbot.WallCheck and not isVisible(pos, char) then
                continue
            end
            local entry = { player = plr, char = char, part = part, pos = pos, dist = d }
            if plr == prevTargetPlayer then prevEntry = entry end
            if d < bestD then
                bestD = d
                best = entry
            end
        end
    end

    -- Hysteresis: не фликаем между целями
    if Settings.Aimbot.Hysteresis and prevEntry and best and prevEntry.player ~= best.player then
        if best.dist > prevEntry.dist * 0.85 then
            best = prevEntry
        end
    end

    prevTargetPlayer = best and best.player or nil
    return best
end

local function updateAim(dt)
    Camera = workspace.CurrentCamera
    if fovCircle then
        if Settings.Aimbot.Enabled and Camera then
            local vp = Camera.ViewportSize
            fovCircle.Position = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
            fovCircle.Radius = Settings.Aimbot.FOV
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end
    if not Settings.Aimbot.Enabled or not Camera then return end

    local t = getTarget()
    if not t then return end

    local cam = Camera.CFrame
    local desired = CFrame.lookAt(cam.Position, t.pos)
    local sm = math.max(Settings.Aimbot.Smoothing, 0.5)
    local alpha = 1 - math.exp(-(dt or 1/60) * (60 / sm))

    -- Per-frame angular clamp (нет визуального snap)
    local maxDeg = Settings.Aimbot.MaxFovDelta
    if maxDeg > 0 then
        local dot = math.clamp(cam.LookVector:Dot(desired.LookVector), -1, 1)
        local ang = math.acos(dot)
        local maxRad = math.rad(maxDeg)
        if ang > 0 and ang * alpha > maxRad then
            alpha = maxRad / ang
        end
    end

    -- HitChance: промах с рандомным offset
    if Settings.HitChance < 100 then
        if math.random(1, 100) > Settings.HitChance then
            local rnd = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
            if rnd.Magnitude > 0.001 then
                desired = CFrame.lookAt(cam.Position, t.pos + rnd.Unit * 4)
            end
        end
    end

    alpha = math.clamp(alpha, 0, 1)
    Camera.CFrame = cam:Lerp(desired, alpha)
end

pcall(function()
    RunService:BindToRenderStep("AbyssAim", Enum.RenderPriority.Camera.Value + 1, updateAim)
end)

----------------------------------------------------------------
-- AntiKick (блокирует client-side Kick)
----------------------------------------------------------------
local kickHooked = false
local function installKickHook()
    if kickHooked then return end
    if type(getrawmetatable) ~= "function" or type(setreadonly) ~= "function"
        or type(newcclosure) ~= "function" or type(getnamecallmethod) ~= "function" then
        return
    end
    local ok, mt = pcall(getrawmetatable, game)
    if not ok or not mt then return end
    local orig = mt.__namecall
    pcall(setreadonly, mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if (method == "Kick" or method == "kick") and self == LocalPlayer then
            if type(checkcaller) == "function" and checkcaller() then
                return orig(self, ...)
            end
            return nil
        end
        return orig(self, ...)
    end)
    pcall(setreadonly, mt, true)
    kickHooked = true
end

----------------------------------------------------------------
-- Movement module (speed modes + fly modes)
----------------------------------------------------------------
local fly = { att = nil, lv = nil, ao = nil, on = false }

local function flyDestroy()
    if fly.lv then pcall(function() fly.lv:Destroy() end) end
    if fly.ao then pcall(function() fly.ao:Destroy() end) end
    if fly.att then pcall(function() fly.att:Destroy() end) end
    fly.lv, fly.ao, fly.att = nil, nil, nil
    fly.on = false
end

local function flyCreate(root)
    flyDestroy()
    fly.att = new("Attachment", { Parent = root })
    fly.lv = new("LinearVelocity", {
        Attachment0 = fly.att,
        MaxForce = math.huge,
        VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
        VectorVelocity = Vector3.zero,
        Parent = root,
    })
    fly.ao = new("AlignOrientation", {
        Attachment0 = fly.att,
        MaxTorque = math.huge,
        Responsiveness = 200,
        Mode = Enum.OrientationAlignmentMode.OneAttachment,
        Parent = root,
    })
    fly.on = true
end

local originalWalk = nil
local lastJump = 0

local function getFlyMove()
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
    return move
end

local function onHeartbeat(dt)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = getHumanoid(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    ---------------- Speed (4 mode bypass) ----------------
    if Settings.Speed.Enabled then
        local v = Settings.Speed.Value
        local mode = Settings.Speed.Mode
        if mode == "WalkSpeed" then
            if originalWalk == nil then originalWalk = hum.WalkSpeed end
            if hum.WalkSpeed ~= v then hum.WalkSpeed = v end
        elseif mode == "Loop" then
            -- игра сбрасывает WalkSpeed каждый кадр -> мы тоже ставим каждый кадр
            if originalWalk == nil then originalWalk = hum.WalkSpeed end
            hum.WalkSpeed = v
        elseif mode == "Velocity" then
            local md = hum.MoveDirection
            if md.Magnitude > 0.1 then
                local cur = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(md.X * v, cur.Y, md.Z * v)
            end
        elseif mode == "CFrame" then
            -- не трогает WalkSpeed/Velocity -> обход speed-check
            local md = hum.MoveDirection
            if md.Magnitude > 0.1 then
                root.CFrame = root.CFrame + md * v * dt
            end
        end
    elseif originalWalk then
        if hum.WalkSpeed ~= originalWalk then hum.WalkSpeed = originalWalk end
        originalWalk = nil
    end

    ---------------- NoClip ----------------
    if Settings.NoClip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end

    ---------------- InfJump ----------------
    if Settings.InfJump and UserInputService:IsKeyDown(Enum.KeyCode.Space) and tick() - lastJump > 0.25 then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        lastJump = tick()
    end

    ---------------- Fly (2 mode + antikick) ----------------
    if Settings.Fly.Enabled then
        if Settings.Fly.AntiKick and not kickHooked then installKickHook() end

        local mode = Settings.Fly.Mode
        local move = getFlyMove()
        local speed = Settings.Fly.Value

        if mode == "LinearVelocity" then
            if not fly.on or not (fly.lv and fly.lv.Parent == root) then flyCreate(root) end
            if fly.on then
                local desired = (move.Magnitude > 0) and (move.Unit * speed) or Vector3.zero
                fly.lv.VectorVelocity = desired
                if fly.ao and Camera then fly.ao.CFrame = Camera.CFrame end
            end
        elseif mode == "CFrame" then
            -- низкая velocity-сигнатура: двигаем позицией, гасим velocity
            if fly.on then flyDestroy() end
            if move.Magnitude > 0 then
                root.CFrame = root.CFrame + move.Unit * speed * dt
            end
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    else
        if fly.on then flyDestroy() end
    end
end
RunService.Heartbeat:Connect(onHeartbeat)

LocalPlayer.CharacterAdded:Connect(function()
    flyDestroy()
    originalWalk = nil
    table.clear(velEMA)
    table.clear(velTS)
    prevTargetPlayer = nil
end)

----------------------------------------------------------------
-- Combat extras: Kill Aura + Auto Clicker
----------------------------------------------------------------
local clickAcc = 0
local auraAcc = 0

local function doClick()
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
    if type(mouse1click) == "function" then pcall(mouse1click) end
end

local function killAuraStep()
    local char = LocalPlayer.Character
    local root = getRoot()
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not root or not tool then return end

    local best, bestD = nil, Settings.Combat.AuraRange
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not isEnemy(plr) then continue end
        local oc = plr.Character
        if not isAlive(oc) then continue end
        local oroot = oc:FindFirstChild("HumanoidRootPart")
        if not oroot then continue end
        local d = (oroot.Position - root.Position).Magnitude
        if d < bestD then
            bestD = d
            best = oroot
        end
    end

    if best then
        -- развернуться к цели
        local look = (best.Position - root.Position)
        look = Vector3.new(look.X, 0, look.Z)
        if look.Magnitude > 0.1 then
            pcall(function()
                root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
            end)
        end
        pcall(function() tool:Activate() end)
    end
end

local function combatLoop(dt)
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

    if Settings.Combat.KillAura then
        auraAcc = auraAcc + dt
        if auraAcc >= 0.1 then
            auraAcc = 0
            killAuraStep()
        end
    else
        auraAcc = 0
    end
end
RunService.Heartbeat:Connect(combatLoop)

----------------------------------------------------------------
-- Farm extras: Collect Aura + Anti-AFK + Fullbright
----------------------------------------------------------------
local COLLECT_NAMES = {
    "coin", "cash", "drop", "pickup", "gem", "orb", "collect",
    "money", "chest", "apple", "cookie", "present", "loot",
}

local function isCollectable(obj)
    if not obj:IsA("BasePart") and not obj:IsA("Model") then return false end
    local n = obj.Name:lower()
    for _, pat in ipairs(COLLECT_NAMES) do
        if n:find(pat, 1, true) then return true end
    end
    return false
end

local collectAcc = 0
local function collectLoop(dt)
    if not Settings.Farm.CollectAura then
        collectAcc = 0
        return
    end
    collectAcc = collectAcc + dt
    if collectAcc < 0.5 then return end
    collectAcc = 0

    local root = getRoot()
    if not root then return end
    local r = Settings.Farm.AuraRadius

    for _, obj in ipairs(workspace:GetDescendants()) do
        if isCollectable(obj) then
            local pos = nil
            if obj:IsA("Model") then
                if obj.PrimaryPart then pos = obj.PrimaryPart.Position end
            else
                pos = obj.Position
            end
            if pos and (pos - root.Position).Magnitude <= r then
                pcall(function()
                    local target = root.CFrame + Vector3.new(0, 2, 0)
                    if obj:IsA("Model") then
                        if obj.PrimaryPart then obj.PrimaryPart.CFrame = target end
                    else
                        obj.CFrame = target
                    end
                end)
            end
        end
    end
end
RunService.Heartbeat:Connect(collectLoop)

-- Anti-AFK (против idle-kick)
LocalPlayer.Idled:Connect(function()
    if Settings.Farm.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- Fullbright
local lightOrig = nil
local function applyFullbright(on)
    if on then
        if not lightOrig then
            lightOrig = {
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                FogEnd = Lighting.FogEnd,
                GlobalShadows = Lighting.GlobalShadows,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
            }
        end
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    elseif lightOrig then
        Lighting.Brightness = lightOrig.Brightness
        Lighting.ClockTime = lightOrig.ClockTime
        Lighting.FogEnd = lightOrig.FogEnd
        Lighting.GlobalShadows = lightOrig.GlobalShadows
        Lighting.Ambient = lightOrig.Ambient
        Lighting.OutdoorAmbient = lightOrig.OutdoorAmbient
        lightOrig = nil
    end
end

----------------------------------------------------------------
-- Hitbox expander
----------------------------------------------------------------
local hitboxOriginal = setmetatable({}, { __mode = "k" })
local hitboxAcc = 0

local function hitboxLoop(dt)
    hitboxAcc = hitboxAcc + dt
    if hitboxAcc < 0.25 then return end
    hitboxAcc = 0

    local enabled = Settings.Hitbox.Enabled
    local size = Settings.Hitbox.Size

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer or not plr.Character then continue end
        for _, part in ipairs(plr.Character:GetChildren()) do
            if part:IsA("BasePart") and (part.Name == "Head" or part.Name == "UpperTorso" or part.Name == "Torso" or part.Name == "HumanoidRootPart") then
                if enabled then
                    if not hitboxOriginal[part] then
                        hitboxOriginal[part] = part.Size
                    end
                    if part.Size.X ~= size then
                        part.Size = Vector3.new(size, size, size)
                    end
                elseif hitboxOriginal[part] then
                    part.Size = hitboxOriginal[part]
                    hitboxOriginal[part] = nil
                end
            end
        end
    end
end
RunService.Heartbeat:Connect(hitboxLoop)

----------------------------------------------------------------
-- Build GUI tabs
----------------------------------------------------------------
local TabCombat = createTab("Combat")
TabCombat:CreateSection("Aimbot")
TabCombat:CreateToggle({ Name = "Aimbot", CurrentValue = Settings.Aimbot.Enabled, Callback = function(v) Settings.Aimbot.Enabled = v end })
TabCombat:CreateToggle({ Name = "Wall Check", CurrentValue = Settings.Aimbot.WallCheck, Callback = function(v) Settings.Aimbot.WallCheck = v end })
TabCombat:CreateToggle({ Name = "Only Enemies", CurrentValue = Settings.Aimbot.OnlyEnemies, Callback = function(v) Settings.Aimbot.OnlyEnemies = v end })
TabCombat:CreateToggle({ Name = "Hold Mouse (LMB)", CurrentValue = Settings.Aimbot.RequireMouseDown, Callback = function(v) Settings.Aimbot.RequireMouseDown = v end })
TabCombat:CreateToggle({ Name = "Hysteresis", CurrentValue = Settings.Aimbot.Hysteresis, Callback = function(v) Settings.Aimbot.Hysteresis = v end })
TabCombat:CreateSlider({ Name = "FOV", Range = { 10, 600 }, Increment = 10, CurrentValue = Settings.Aimbot.FOV, Callback = function(v) Settings.Aimbot.FOV = v end })
TabCombat:CreateSlider({ Name = "Smoothing", Range = { 1, 20 }, Increment = 1, CurrentValue = Settings.Aimbot.Smoothing, Callback = function(v) Settings.Aimbot.Smoothing = v end })
TabCombat:CreateSlider({ Name = "Prediction", Range = { 0, 0.5 }, Increment = 0.01, CurrentValue = Settings.Aimbot.Prediction, Callback = function(v) Settings.Aimbot.Prediction = v end })
TabCombat:CreateSlider({ Name = "Hit Chance", Range = { 10, 100 }, Increment = 5, Suffix = "%", CurrentValue = Settings.Aimbot.HitChance, Callback = function(v) Settings.Aimbot.HitChance = v end })
TabCombat:CreateSection("PvP Aura")
TabCombat:CreateToggle({ Name = "Kill Aura", CurrentValue = Settings.Combat.KillAura, Callback = function(v) Settings.Combat.KillAura = v end })
TabCombat:CreateSlider({ Name = "Aura Range", Range = { 5, 30 }, Increment = 1, CurrentValue = Settings.Combat.AuraRange, Callback = function(v) Settings.Combat.AuraRange = v end })
TabCombat:CreateToggle({ Name = "Auto Clicker", CurrentValue = Settings.Combat.AutoClicker, Callback = function(v) Settings.Combat.AutoClicker = v end })
TabCombat:CreateSlider({ Name = "CPS", Range = { 1, 30 }, Increment = 1, CurrentValue = Settings.Combat.CPS, Callback = function(v) Settings.Combat.CPS = v end })

local TabVisuals = createTab("Visuals")
TabVisuals:CreateSection("ESP")
TabVisuals:CreateToggle({ Name = "Enable ESP", CurrentValue = Settings.ESP.Enabled, Callback = function(v) Settings.ESP.Enabled = v end })
TabVisuals:CreateToggle({ Name = "Boxes", CurrentValue = Settings.ESP.Boxes, Callback = function(v) Settings.ESP.Boxes = v end })
TabVisuals:CreateToggle({ Name = "Health Bar", CurrentValue = Settings.ESP.HealthBar, Callback = function(v) Settings.ESP.HealthBar = v end })
TabVisuals:CreateToggle({ Name = "Snaplines", CurrentValue = Settings.ESP.Snaplines, Callback = function(v) Settings.ESP.Snaplines = v end })
TabVisuals:CreateToggle({ Name = "Names", CurrentValue = Settings.ESP.Names, Callback = function(v) Settings.ESP.Names = v end })
TabVisuals:CreateToggle({ Name = "Distance", CurrentValue = Settings.ESP.Distance, Callback = function(v) Settings.ESP.Distance = v end })
TabVisuals:CreateToggle({ Name = "Chams", CurrentValue = Settings.ESP.Chams, Callback = function(v) Settings.ESP.Chams = v end })
TabVisuals:CreateToggle({ Name = "Only Enemies", CurrentValue = Settings.ESP.OnlyEnemies, Callback = function(v) Settings.ESP.OnlyEnemies = v end })
TabVisuals:CreateSlider({ Name = "Max Distance", Range = { 50, 2000 }, Increment = 50, CurrentValue = Settings.ESP.MaxDistance, Callback = function(v) Settings.ESP.MaxDistance = v end })
TabVisuals:CreateSection("World")
TabVisuals:CreateToggle({ Name = "Fullbright", CurrentValue = Settings.Farm.Fullbright, Callback = function(v) Settings.Farm.Fullbright = v applyFullbright(v) end })

local TabMovement = createTab("Movement")
TabMovement:CreateSection("SpeedHack (bypass)")
TabMovement:CreateToggle({ Name = "Speed Hack", CurrentValue = Settings.Speed.Enabled, Callback = function(v) Settings.Speed.Enabled = v end })
TabMovement:CreateDropdown({ Name = "Speed Mode", Options = { "WalkSpeed", "Loop", "Velocity", "CFrame" }, CurrentOption = Settings.Speed.Mode, Callback = function(v) Settings.Speed.Mode = v end })
TabMovement:CreateSlider({ Name = "Walk Speed", Range = { 16, 200 }, Increment = 1, CurrentValue = Settings.Speed.Value, Callback = function(v) Settings.Speed.Value = v end })
TabMovement:CreateSection("Fly (antikick)")
TabMovement:CreateToggle({ Name = "Fly", CurrentValue = Settings.Fly.Enabled, Callback = function(v) Settings.Fly.Enabled = v end })
TabMovement:CreateDropdown({ Name = "Fly Mode", Options = { "LinearVelocity", "CFrame" }, CurrentOption = Settings.Fly.Mode, Callback = function(v) Settings.Fly.Mode = v end })
TabMovement:CreateToggle({ Name = "Anti-Kick", CurrentValue = Settings.Fly.AntiKick, Callback = function(v) Settings.Fly.AntiKick = v if v then installKickHook() end end })
TabMovement:CreateSlider({ Name = "Fly Speed", Range = { 20, 200 }, Increment = 5, CurrentValue = Settings.Fly.Value, Callback = function(v) Settings.Fly.Value = v end })
TabMovement:CreateSection("Other")
TabMovement:CreateToggle({ Name = "NoClip", CurrentValue = Settings.NoClip, Callback = function(v) Settings.NoClip = v end })
TabMovement:CreateToggle({ Name = "Infinite Jump", CurrentValue = Settings.InfJump, Callback = function(v) Settings.InfJump = v end })

local TabFarm = createTab("Farm")
TabFarm:CreateSection("Auto Farm")
TabFarm:CreateToggle({ Name = "Collect Aura", CurrentValue = Settings.Farm.CollectAura, Callback = function(v) Settings.Farm.CollectAura = v end })
TabFarm:CreateSlider({ Name = "Aura Radius", Range = { 10, 100 }, Increment = 5, CurrentValue = Settings.Farm.AuraRadius, Callback = function(v) Settings.Farm.AuraRadius = v end })
TabFarm:CreateToggle({ Name = "Anti-AFK", CurrentValue = Settings.Farm.AntiAFK, Callback = function(v) Settings.Farm.AntiAFK = v end })
TabFarm:CreateSection("Hitbox")
TabFarm:CreateToggle({ Name = "Hitbox Expander", CurrentValue = Settings.Hitbox.Enabled, Callback = function(v) Settings.Hitbox.Enabled = v end })
TabFarm:CreateSlider({ Name = "Hitbox Size", Range = { 3, 25 }, Increment = 1, CurrentValue = Settings.Hitbox.Size, Callback = function(v) Settings.Hitbox.Size = v end })

local TabMisc = createTab("Misc")
TabMisc:CreateSection("Info")
TabMisc:CreateLabel("RightShift - show/hide GUI")
TabMisc:CreateLabel("WASD + Space/Ctrl - fly")
TabMisc:CreateLabel("Speed CFrame = stealth mode")
TabMisc:CreateButton({ Name = "Hide GUI", Callback = function() main.Visible = false end })

print("[ABYSS] Universal v3 loaded — speed bypass, fly antikick, aimbot v2, aura, farm.")
