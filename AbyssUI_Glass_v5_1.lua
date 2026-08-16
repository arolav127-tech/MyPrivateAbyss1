local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")

if not RunService:IsClient() then error("client only") end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

----------------------------------------------------------------
-- Settings
----------------------------------------------------------------
local Settings = {
    Aimbot  = { Enabled = false, FOV = 90, Smoothing = 6, WallCheck = true, OnlyEnemies = true, Prediction = 0.11 },
    ESP     = { Enabled = false, Boxes = true, HealthBar = true, Snaplines = false, Names = true, Distance = false, Chams = false, MaxDistance = 900, OnlyEnemies = true },
    Speed   = { Enabled = false, Value = 50 },
    Fly     = { Enabled = false, Value = 60 },
    NoClip  = false,
    InfJump = false,
    Hitbox  = { Enabled = false, Size = 12 },
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
    Size = UDim2.fromOffset(520, 430),
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
    Text = "Abyss Universal",
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
    Text = "single-file build",
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
        tween(main, 0.2, { Size = UDim2.fromOffset(main.Size.X.Offset, 430) })
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
-- Aimbot module
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

local function getTarget()
    if not Camera then return nil end
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local best, bestD = nil, Settings.Aimbot.FOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if not (Settings.Aimbot.OnlyEnemies and not isEnemy(plr)) then
                local char = plr.Character
                if isAlive(char) then
                    local part = getBestPart(char)
                    if part then
                        local pos = part.Position
                        if Settings.Aimbot.Prediction > 0 then
                            local vel = part.AssemblyLinearVelocity
                            if vel.Magnitude < 500 then
                                pos = pos + vel * Settings.Aimbot.Prediction
                            end
                        end
                        local sp, onScreen = Camera:WorldToViewportPoint(pos)
                        if onScreen and sp.Z > 0 then
                            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            if d <= bestD then
                                if not Settings.Aimbot.WallCheck or isVisible(pos, char) then
                                    bestD = d
                                    best = { part = part, char = char, pos = pos }
                                end
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
    if t then
        local desired = CFrame.lookAt(Camera.CFrame.Position, t.pos)
        local sm = math.max(Settings.Aimbot.Smoothing, 0.5)
        local alpha = math.clamp((1 - math.exp(-(dt or 1/60) * (60 / sm))), 0, 1)
        Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
    end
end

pcall(function()
    RunService:BindToRenderStep("AbyssAim", Enum.RenderPriority.Camera.Value + 1, updateAim)
end)

----------------------------------------------------------------
-- Movement module
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

local hitboxOriginal = setmetatable({}, { __mode = "k" })
local hitboxTimer = 0

local function applyHitbox(dt)
    hitboxTimer = hitboxTimer + dt
    if hitboxTimer < 0.25 then return end
    hitboxTimer = 0
    local enabled = Settings.Hitbox.Enabled
    local size = Settings.Hitbox.Size
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
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
end

local originalWalk = nil
local lastJump = 0

local function onHeartbeat(dt)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = getHumanoid(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    if Settings.Speed.Enabled then
        if originalWalk == nil then originalWalk = hum.WalkSpeed end
        if hum.WalkSpeed ~= Settings.Speed.Value then hum.WalkSpeed = Settings.Speed.Value end
    elseif originalWalk then
        if hum.WalkSpeed ~= originalWalk then hum.WalkSpeed = originalWalk end
        originalWalk = nil
    end

    if Settings.NoClip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end

    if Settings.InfJump and UserInputService:IsKeyDown(Enum.KeyCode.Space) and tick() - lastJump > 0.25 then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        lastJump = tick()
    end

    if Settings.Fly.Enabled then
        if not fly.on or not (fly.lv and fly.lv.Parent == root) then flyCreate(root) end
        if fly.on then
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
            fly.lv.VectorVelocity = (move.Magnitude > 0) and (move.Unit * Settings.Fly.Value) or Vector3.zero
            if fly.ao and Camera then fly.ao.CFrame = Camera.CFrame end
        end
    elseif fly.on then
        flyDestroy()
    end

    applyHitbox(dt)
end
RunService.Heartbeat:Connect(onHeartbeat)

LocalPlayer.CharacterAdded:Connect(function()
    flyDestroy()
    originalWalk = nil
    hitboxTimer = 0
end)

----------------------------------------------------------------
-- Build GUI tabs
----------------------------------------------------------------
local TabCombat = createTab("Combat")
TabCombat:CreateSection("Aimbot")
TabCombat:CreateToggle({ Name = "Aimbot", CurrentValue = Settings.Aimbot.Enabled, Callback = function(v) Settings.Aimbot.Enabled = v end })
TabCombat:CreateToggle({ Name = "Wall Check", CurrentValue = Settings.Aimbot.WallCheck, Callback = function(v) Settings.Aimbot.WallCheck = v end })
TabCombat:CreateToggle({ Name = "Only Enemies", CurrentValue = Settings.Aimbot.OnlyEnemies, Callback = function(v) Settings.Aimbot.OnlyEnemies = v end })
TabCombat:CreateSlider({ Name = "FOV", Range = { 10, 600 }, Increment = 10, CurrentValue = Settings.Aimbot.FOV, Callback = function(v) Settings.Aimbot.FOV = v end })
TabCombat:CreateSlider({ Name = "Smoothing", Range = { 1, 20 }, Increment = 1, CurrentValue = Settings.Aimbot.Smoothing, Callback = function(v) Settings.Aimbot.Smoothing = v end })

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

local TabMovement = createTab("Movement")
TabMovement:CreateSection("Speed")
TabMovement:CreateToggle({ Name = "Speed Hack", CurrentValue = Settings.Speed.Enabled, Callback = function(v) Settings.Speed.Enabled = v end })
TabMovement:CreateSlider({ Name = "Walk Speed", Range = { 16, 150 }, Increment = 1, CurrentValue = Settings.Speed.Value, Callback = function(v) Settings.Speed.Value = v end })
TabMovement:CreateSection("Fly")
TabMovement:CreateToggle({ Name = "Fly", CurrentValue = Settings.Fly.Enabled, Callback = function(v) Settings.Fly.Enabled = v end })
TabMovement:CreateSlider({ Name = "Fly Speed", Range = { 20, 200 }, Increment = 5, CurrentValue = Settings.Fly.Value, Callback = function(v) Settings.Fly.Value = v end })
TabMovement:CreateSection("Other")
TabMovement:CreateToggle({ Name = "NoClip", CurrentValue = Settings.NoClip, Callback = function(v) Settings.NoClip = v end })
TabMovement:CreateToggle({ Name = "Infinite Jump", CurrentValue = Settings.InfJump, Callback = function(v) Settings.InfJump = v end })

local TabMisc = createTab("Misc")
TabMisc:CreateSection("Helpers")
TabMisc:CreateToggle({ Name = "Hitbox Expander", CurrentValue = Settings.Hitbox.Enabled, Callback = function(v) Settings.Hitbox.Enabled = v end })
TabMisc:CreateSlider({ Name = "Hitbox Size", Range = { 3, 25 }, Increment = 1, CurrentValue = Settings.Hitbox.Size, Callback = function(v) Settings.Hitbox.Size = v end })
TabMisc:CreateSection("Info")
TabMisc:CreateLabel("RightShift - show/hide GUI")
TabMisc:CreateLabel("WASD + Space/Ctrl - fly")
TabMisc:CreateButton({ Name = "Hide GUI", Callback = function() main.Visible = false end })

print("[ABYSS] Universal v2 loaded. RightShift = GUI.")
