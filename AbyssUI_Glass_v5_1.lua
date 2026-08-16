local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")

if not RunService:IsClient() then error("Client only") end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
while not LocalPlayer.Character do task.wait(0.1) end

----------------------------------------------------------------
-- Settings (global state for all modules)
----------------------------------------------------------------
local Settings = {
    -- Aimbot
    Aimbot = {
        Enabled = false,
        FOV = 120,
        Smoothing = 5,
        Sensitivity = 1.0,
        Prediction = 0.1,
        WallCheck = true,
        OnlyEnemies = true,
    },
    
    -- ESP
    ESP = {
        Enabled = false,
        Boxes = false,
        HealthBar = false,
        Snaplines = false,
        Chams = false,
        Names = false,
        Distance = false,
        MaxDistance = 1000,
        OnlyEnemies = true,
    },
    
    -- Movement
    SpeedHack = {
        Enabled = false,
        Speed = 50,
    },
    Fly = {
        Enabled = false,
        Speed = 60,
    },
    NoClip = false,
    InfiniteJump = false,
    
    -- Misc
    HitboxExpander = {
        Enabled = false,
        Size = 10,
    },
}

----------------------------------------------------------------
-- Utility
----------------------------------------------------------------
local Camera = workspace.CurrentCamera
local function getGuiParent()
    if type(gethui) == "function" then
        local ok, t = pcall(gethui)
        if ok and t then return t end
    end
    if type(cloneref) == "function" then
        local ok, t = pcall(cloneref, CoreGui)
        if ok and t then return t end
    end
    local ok, pg = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 3) end)
    if ok and pg then return pg end
    return CoreGui
end

local function isEnemy(player)
    if not Settings.ESP.OnlyEnemies then return true end
    if player == LocalPlayer then return false end
    local mine, theirs = LocalPlayer.Team, player.Team
    if not mine or not theirs then return true end
    if LocalPlayer.Neutral or player.Neutral then return true end
    return theirs ~= mine
end

local function isAlive(char)
    if not char or not char.Parent then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function getBestHitbox(char)
    if not char then return nil end
    for _, name in ipairs({"Head", "UpperTorso", "HumanoidRootPart", "Torso"}) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then return part end
    end
    return nil
end

local function isVisible(target)
    if not Camera then return false end
    local pos = typeof(target) == "Vector3" and target or target.Position
    local origin = Camera.CFrame.Position
    local dir = pos - origin
    if dir.Magnitude < 0.1 then return true end
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    local ignore = {Camera}
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    params.FilterDescendantsInstances = ignore
    
    local hit = workspace:Raycast(origin, dir, params)
    return not hit
end

----------------------------------------------------------------
-- GUI (minimal embedded version)
----------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AbyssCheat"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = getGuiParent()

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(500, 400)
main.Position = UDim2.new(0.5, -250, 0.5, -200)
main.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
main.BorderSizePixel = 0
main.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 75, 95)
stroke.Thickness = 1
stroke.Parent = main

local topbar = Instance.new("Frame")
topbar.Size = UDim2.new(1, 0, 0, 40)
topbar.BackgroundColor3 = Color3.fromRGB(30, 40, 55)
topbar.BorderSizePixel = 0
topbar.Parent = main

Instance.new("UICorner", topbar).CornerRadius = UDim.new(0, 8)
Instance.new("Frame", {
    Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 1, -8),
    BackgroundColor3 = Color3.fromRGB(30, 40, 55), BorderSizePixel = 0, Parent = topbar
})

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -100, 1, 0)
title.Position = UDim2.fromOffset(15, 0)
title.BackgroundTransparency = 1
title.Text = "Abyss Universal"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamSemibold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topbar

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, -48)
sidebar.Position = UDim2.fromOffset(6, 44)
sidebar.BackgroundColor3 = Color3.fromRGB(25, 32, 45)
sidebar.BorderSizePixel = 0
sidebar.Parent = main

Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 6)

local tabList = Instance.new("ScrollingFrame")
tabList.Size = UDim2.new(1, -8, 1, -8)
tabList.Position = UDim2.fromOffset(4, 4)
tabList.BackgroundTransparency = 1
tabList.BorderSizePixel = 0
tabList.ScrollBarThickness = 0
tabList.Parent = sidebar

local tabLayout = Instance.new("UIListLayout")
tabLayout.Padding = UDim.new(0, 4)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabList

tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    tabList.CanvasSize = UDim2.fromOffset(0, tabLayout.AbsoluteContentSize.Y + 4)
end)

local pages = Instance.new("Frame")
pages.Size = UDim2.new(1, -142, 1, -48)
pages.Position = UDim2.fromOffset(140, 44)
pages.BackgroundTransparency = 1
pages.Parent = main

local selected = nil
local tabs = {}

local function selectTab(rec)
    selected = rec
    for _, r in ipairs(tabs) do
        r.page.Visible = (r == rec)
        r.btn.BackgroundColor3 = (r == rec) and Color3.fromRGB(50, 70, 100) or Color3.fromRGB(40, 50, 65)
    end
end

local function createTab(name)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(80, 95, 115)
    page.Visible = false
    page.Parent = pages
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    
    Instance.new("UIPadding", {
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
        Parent = page
    })
    
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 16)
    end)
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(40, 50, 65)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(220, 225, 235)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.Parent = tabList
    
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", btn).Color = Color3.fromRGB(55, 68, 85)
    
    local rec = {name = name, page = page, btn = btn}
    table.insert(tabs, rec)
    
    btn.MouseButton1Click:Connect(function() selectTab(rec) end)
    btn.MouseEnter:Connect(function()
        if selected ~= rec then btn.BackgroundColor3 = Color3.fromRGB(55, 68, 85) end
    end)
    btn.MouseLeave:Connect(function()
        if selected ~= rec then btn.BackgroundColor3 = Color3.fromRGB(40, 50, 65) end
    end)
    
    if not selected then selectTab(rec) end
    
    local Tab = {}
    local order = 0
    
    local function elemFrame(h)
        order += 1
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, h)
        f.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
        f.BorderSizePixel = 0
        f.LayoutOrder = order
        f.Parent = page
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
        Instance.new("UIStroke", f).Color = Color3.fromRGB(50, 63, 80)
        return f
    end
    
    function Tab:CreateSection(text)
        order += 1
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(180, 190, 205)
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.LayoutOrder = order
        label.Parent = page
    end
    
    function Tab:CreateToggle(opts)
        opts = opts or {}
        local state = opts.CurrentValue == true
        local f = elemFrame(32)
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -60, 1, 0)
        label.Position = UDim2.fromOffset(12, 0)
        label.BackgroundTransparency = 1
        label.Text = opts.Name or "Toggle"
        label.TextColor3 = Color3.fromRGB(240, 245, 255)
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = f
        
        local sw = Instance.new("Frame")
        sw.Size = UDim2.fromOffset(42, 20)
        sw.Position = UDim2.new(1, -52, 0.5, -10)
        sw.BackgroundColor3 = Color3.fromRGB(25, 32, 45)
        sw.BorderSizePixel = 0
        sw.Parent = f
        Instance.new("UICorner", sw).CornerRadius = UDim.new(0, 10)
        Instance.new("UIStroke", sw).Color = Color3.fromRGB(60, 75, 95)
        
        local ind = Instance.new("Frame")
        ind.Size = UDim2.fromOffset(14, 14)
        ind.AnchorPoint = Vector2.new(0, 0.5)
        ind.Position = UDim2.new(0, 3, 0.5, 0)
        ind.BackgroundColor3 = Color3.fromRGB(100, 111, 130)
        ind.BorderSizePixel = 0
        ind.Parent = sw
        Instance.new("UICorner", ind).CornerRadius = UDim.new(0, 7)
        
        local obj = {CurrentValue = state}
        
        local function apply(v, fire)
            state = v == true
            obj.CurrentValue = state
            if state then
                ind:TweenPosition(UDim2.new(1, -17, 0.5, 0), "Out", "Quad", 0.15, true)
                ind.BackgroundColor3 = Color3.fromRGB(114, 191, 255)
            else
                ind:TweenPosition(UDim2.new(0, 3, 0.5, 0), "Out", "Quad", 0.15, true)
                ind.BackgroundColor3 = Color3.fromRGB(100, 111, 130)
            end
            if fire and type(opts.Callback) == "function" then
                pcall(opts.Callback, state)
            end
        end
        
        f.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                apply(not state, true)
            end
        end)
        
        function obj:Set(v) apply(v, true) end
        apply(state, false)
        return obj
    end
    
    function Tab:CreateSlider(opts)
        opts = opts or {}
        local min = opts.Range and opts.Range[1] or 0
        local max = opts.Range and opts.Range[2] or 100
        if min > max then min, max = max, min end
        local value = tonumber(opts.CurrentValue) or min
        
        local f = elemFrame(44)
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.6, -12, 0, 16)
        label.Position = UDim2.fromOffset(12, 5)
        label.BackgroundTransparency = 1
        label.Text = opts.Name or "Slider"
        label.TextColor3 = Color3.fromRGB(240, 245, 255)
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = f
        
        local info = Instance.new("TextLabel")
        info.Size = UDim2.fromOffset(80, 16)
        info.Position = UDim2.new(1, -92, 0, 5)
        info.BackgroundTransparency = 1
        info.Text = tostring(value)
        info.TextColor3 = Color3.fromRGB(180, 190, 205)
        info.Font = Enum.Font.Gotham
        info.TextSize = 12
        info.TextXAlignment = Enum.TextXAlignment.Right
        info.Parent = f
        
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -20, 0, 7)
        track.Position = UDim2.fromOffset(10, 28)
        track.BackgroundColor3 = Color3.fromRGB(60, 75, 95)
        track.BorderSizePixel = 0
        track.Parent = f
        Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)
        
        local prog = Instance.new("Frame")
        prog.Size = UDim2.new(0, 0, 1, 0)
        prog.BackgroundColor3 = Color3.fromRGB(114, 191, 255)
        prog.BorderSizePixel = 0
        prog.Parent = track
        Instance.new("UICorner", prog).CornerRadius = UDim.new(0, 3)
        
        local obj = {CurrentValue = value}
        local dragging = false
        
        local function snap(v)
            v = math.clamp(v, min, max)
            local inc = opts.Increment or 1
            return min + math.floor((v - min) / inc + 0.5) * inc
        end
        
        local function apply(v, fire)
            v = snap(v)
            value = v
            obj.CurrentValue = v
            local ratio = (max > min) and ((v - min) / (max - min)) or 0
            prog.Size = UDim2.new(ratio, 0, 1, 0)
            info.Text = tostring(v)
            if fire and type(opts.Callback) == "function" then
                pcall(opts.Callback, v)
            end
        end
        
        local function fromX(x)
            local w = math.max(track.AbsoluteSize.X, 1)
            local r = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
            apply(min + (max - min) * r, true)
        end
        
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                fromX(input.Position.X)
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                fromX(input.Position.X)
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        
        function obj:Set(v) apply(v, true) end
        apply(value, false)
        return obj
    end
    
    function Tab:CreateButton(opts)
        opts = opts or {}
        local f = elemFrame(32)
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -16, 1, 0)
        label.Position = UDim2.fromOffset(12, 0)
        label.BackgroundTransparency = 1
        label.Text = opts.Name or "Button"
        label.TextColor3 = Color3.fromRGB(240, 245, 255)
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.Parent = f
        
        f.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if type(opts.Callback) == "function" then pcall(opts.Callback) end
            end
        end)
        
        return {}
    end
    
    return Tab
end

----------------------------------------------------------------
-- Drag
----------------------------------------------------------------
local dragging, dragStart, startPos = false, nil, nil

topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

----------------------------------------------------------------
-- Toggle GUI
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)

----------------------------------------------------------------
-- ESP Module
----------------------------------------------------------------
local ESP = {}
local drawingAvailable = type(Drawing) == "table" and type(Drawing.new) == "function"

local function createESP(player)
    if player == LocalPlayer then return end
    
    local entry = {
        box = nil,
        hpBg = nil,
        hpFill = nil,
        snapline = nil,
        nameText = nil,
        distText = nil,
        highlight = nil,
    }
    
    ESP[player] = entry
    
    local function hide()
        if entry.box then pcall(function() entry.box:Remove() end); entry.box = nil end
        if entry.hpBg then pcall(function() entry.hpBg:Remove() end); entry.hpBg = nil end
        if entry.hpFill then pcall(function() entry.hpFill:Remove() end); entry.hpFill = nil end
        if entry.snapline then pcall(function() entry.snapline:Remove() end); entry.snapline = nil end
        if entry.nameText then pcall(function() entry.nameText:Remove() end); entry.nameText = nil end
        if entry.distText then pcall(function() entry.distText:Remove() end); entry.distText = nil end
        if entry.highlight then pcall(function() entry.highlight:Destroy() end); entry.highlight = nil end
    end
    
    player.CharacterRemoving:Connect(hide)
    return hide
end

for _, player in ipairs(Players:GetPlayers()) do
    createESP(player)
end

Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(function(player)
    local entry = ESP[player]
    if entry then
        if entry.box then pcall(function() entry.box:Remove() end) end
        if entry.hpBg then pcall(function() entry.hpBg:Remove() end) end
        if entry.hpFill then pcall(function() entry.hpFill:Remove() end) end
        if entry.snapline then pcall(function() entry.snapline:Remove() end) end
        if entry.nameText then pcall(function() entry.nameText:Remove() end) end
        if entry.distText then pcall(function() entry.distText:Remove() end) end
        if entry.highlight then pcall(function() entry.highlight:Destroy() end) end
        ESP[player] = nil
    end
end)

local function updateESP()
    if not Settings.ESP.Enabled or not drawingAvailable or not Camera then
        for _, entry in pairs(ESP) do
            if entry.box then pcall(function() entry.box.Visible = false end) end
            if entry.hpBg then pcall(function() entry.hpBg.Visible = false end) end
            if entry.hpFill then pcall(function() entry.hpFill.Visible = false end) end
            if entry.snapline then pcall(function() entry.snapline.Visible = false end) end
            if entry.nameText then pcall(function() entry.nameText.Visible = false end) end
            if entry.distText then pcall(function() entry.distText.Visible = false end) end
            if entry.highlight then pcall(function() entry.highlight.Enabled = false end) end
        end
        return
    end
    
    local viewport = Camera.ViewportSize
    local camPos = Camera.CFrame.Position
    
    for player, entry in pairs(ESP) do
        if player == LocalPlayer or not player.Character then
            continue
        end
        
        local char = player.Character
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        
        if not isAlive(char, hum) or not root then
            if entry.box then entry.box.Visible = false end
            if entry.hpBg then entry.hpBg.Visible = false end
            if entry.hpFill then entry.hpFill.Visible = false end
            if entry.snapline then entry.snapline.Visible = false end
            if entry.nameText then entry.nameText.Visible = false end
            if entry.distText then entry.distText.Visible = false end
            if entry.highlight then entry.highlight.Enabled = false end
            continue
        end
        
        local enemy = isEnemy(player)
        if Settings.ESP.OnlyEnemies and not enemy then
            if entry.box then entry.box.Visible = false end
            if entry.hpBg then entry.hpBg.Visible = false end
            if entry.hpFill then entry.hpFill.Visible = false end
            if entry.snapline then entry.snapline.Visible = false end
            if entry.nameText then entry.nameText.Visible = false end
            if entry.distText then entry.distText.Visible = false end
            if entry.highlight then entry.highlight.Enabled = false end
            continue
        end
        
        local dist = (root.Position - camPos).Magnitude
        if dist > Settings.ESP.MaxDistance then
            if entry.box then entry.box.Visible = false end
            if entry.hpBg then entry.hpBg.Visible = false end
            if entry.hpFill then entry.hpFill.Visible = false end
            if entry.snapline then entry.snapline.Visible = false end
            if entry.nameText then entry.nameText.Visible = false end
            if entry.distText then entry.distText.Visible = false end
            if entry.highlight then entry.highlight.Enabled = false end
            continue
        end
        
        local color = enemy and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(60, 140, 255)
        
        if not head then head = root end
        local headPos = head.Position
        local legPos = root.Position - Vector3.new(0, 3, 0)
        
        local headSp = Camera:WorldToViewportPoint(headPos)
        local legSp = Camera:WorldToViewportPoint(legPos)
        
        if headSp.Z < 0 and legSp.Z < 0 then
            if entry.box then entry.box.Visible = false end
            if entry.hpBg then entry.hpBg.Visible = false end
            if entry.hpFill then entry.hpFill.Visible = false end
            if entry.snapline then entry.snapline.Visible = false end
            if entry.nameText then entry.nameText.Visible = false end
            if entry.distText then entry.distText.Visible = false end
            if entry.highlight then entry.highlight.Enabled = false end
            continue
        end
        
        local height = math.abs(legSp.Y - headSp.Y)
        local width = height * 0.5
        local x = headSp.X - width * 0.5
        local y = headSp.Y
        
        -- Box
        if Settings.ESP.Boxes then
            if not entry.box then
                entry.box = Drawing.new("Square")
                entry.box.Thickness = 1
                entry.box.Filled = false
            end
            entry.box.Size = Vector2.new(width, height)
            entry.box.Position = Vector2.new(x, y)
            entry.box.Color = color
            entry.box.Visible = true
        elseif entry.box then
            entry.box.Visible = false
        end
        
        -- Health Bar
        if Settings.ESP.HealthBar and hum.MaxHealth > 0 then
            if not entry.hpBg then
                entry.hpBg = Drawing.new("Square")
                entry.hpBg.Filled = true
                entry.hpBg.Color = Color3.fromRGB(0, 0, 0)
                entry.hpBg.Thickness = 1
            end
            if not entry.hpFill then
                entry.hpFill = Drawing.new("Square")
                entry.hpFill.Filled = true
                entry.hpFill.Thickness = 1
            end
            
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local barH = height * pct
            
            entry.hpBg.Size = Vector2.new(3, height)
            entry.hpBg.Position = Vector2.new(x - 5, y)
            entry.hpBg.Visible = true
            
            entry.hpFill.Size = Vector2.new(3, barH)
            entry.hpFill.Position = Vector2.new(x - 5, y + (height - barH))
            entry.hpFill.Color = Color3.fromRGB(60, 220, 60):Lerp(Color3.fromRGB(220, 60, 60), 1 - pct)
            entry.hpFill.Visible = true
        else
            if entry.hpBg then entry.hpBg.Visible = false end
            if entry.hpFill then entry.hpFill.Visible = false end
        end
        
        -- Snaplines
        if Settings.ESP.Snaplines then
            if not entry.snapline then
                entry.snapline = Drawing.new("Line")
                entry.snapline.Thickness = 1
            end
            entry.snapline.From = Vector2.new(viewport.X * 0.5, viewport.Y)
            entry.snapline.To = Vector2.new(headSp.X, headSp.Y)
            entry.snapline.Color = color
            entry.snapline.Visible = true
        elseif entry.snapline then
            entry.snapline.Visible = false
        end
        
        -- Names
        if Settings.ESP.Names then
            if not entry.nameText then
                entry.nameText = Drawing.new("Text")
                entry.nameText.Size = 13
                entry.nameText.Color = Color3.fromRGB(255, 255, 255)
                entry.nameText.Outline = true
                entry.nameText.Center = true
            end
            local name = (player.DisplayName ~= "" and player.DisplayName) or player.Name
            entry.nameText.Text = name
            entry.nameText.Position = Vector2.new(headSp.X, y - 16)
            entry.nameText.Visible = true
        elseif entry.nameText then
            entry.nameText.Visible = false
        end
        
        -- Distance
        if Settings.ESP.Distance then
            if not entry.distText then
                entry.distText = Drawing.new("Text")
                entry.distText.Size = 12
                entry.distText.Color = Color3.fromRGB(255, 255, 255)
                entry.distText.Outline = true
                entry.distText.Center = true
            end
            entry.distText.Text = tostring(math.floor(dist)) .. "m"
            entry.distText.Position = Vector2.new(headSp.X, y + height + 4)
            entry.distText.Visible = true
        elseif entry.distText then
            entry.distText.Visible = false
        end
        
        -- Chams (Highlight)
        if Settings.ESP.Chams then
            if not entry.highlight or not entry.highlight.Parent or entry.highlight.Adornee ~= char then
                if entry.highlight then pcall(function() entry.highlight:Destroy() end) end
                local h = Instance.new("Highlight")
                h.FillColor = color
                h.OutlineColor = Color3.fromRGB(255, 255, 255)
                h.FillTransparency = 0.5
                h.OutlineTransparency = 0
                pcall(function() h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
                h.Adornee = char
                h.Parent = char
                entry.highlight = h
            else
                entry.highlight.FillColor = color
                entry.highlight.Enabled = true
            end
        elseif entry.highlight then
            entry.highlight.Enabled = false
        end
    end
end

pcall(function()
    RunService:BindToRenderStep("AbyssESP", Enum.RenderPriority.Camera.Value + 2, updateESP)
end)

----------------------------------------------------------------
-- Aimbot Module
----------------------------------------------------------------
local aimbotTarget = nil
local aimbotLastUpdate = 0

local function getAimbotTarget()
    if not Settings.Aimbot.Enabled or not Camera or not LocalPlayer.Character then
        return nil
    end
    
    local now = tick()
    if now - aimbotLastUpdate < 0.1 then
        if aimbotTarget and aimbotTarget.player and aimbotTarget.player.Character then
            local char = aimbotTarget.player.Character
            if isAlive(char) and getBestHitbox(char) then
                return aimbotTarget
            end
        end
    end
    aimbotLastUpdate = now
    
    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local fov = Settings.Aimbot.FOV
    local best, bestDist = nil, fov
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        local enemy = isEnemy(player)
        if Settings.Aimbot.OnlyEnemies and not enemy then continue end
        
        local char = player.Character
        if not isAlive(char) then continue end
        
        local part = getBestHitbox(char)
        if not part then continue end
        
        local pos = part.Position
        if Settings.Aimbot.WallCheck and not isVisible(pos) then continue end
        
        local sp, onScreen = Camera:WorldToViewportPoint(pos)
        if not onScreen or sp.Z < 0 then continue end
        
        local screen2 = Vector2.new(sp.X, sp.Y)
        local d = (screen2 - center).Magnitude
        
        if d <= fov and d < bestDist then
            bestDist = d
            best = {player = player, character = char, part = part, position = pos}
        end
    end
    
    aimbotTarget = best
    return best
end

local function aimAt(position, dt)
    if not position or not Camera then return end
    local cam = Camera.CFrame
    local desired = CFrame.lookAt(cam.Position, position)
    local smooth = math.max(tonumber(Settings.Aimbot.Smoothing) or 5, 0.001)
    local sens = math.max(tonumber(Settings.Aimbot.Sensitivity) or 1, 0.01)
    local alpha = (1 - math.exp(-(dt or 1/60) * (60 / smooth))) * sens
    alpha = math.clamp(alpha, 0, 1)
    Camera.CFrame = cam:Lerp(desired, alpha)
end

local function updateAimbot(dt)
    if not Settings.Aimbot.Enabled then return end
    local target = getAimbotTarget()
    if target then
        aimAt(target.position, dt)
    end
end

pcall(function()
    RunService:BindToRenderStep("AbyssAimbot", Enum.RenderPriority.Camera.Value + 1, updateAimbot)
end)

----------------------------------------------------------------
-- Movement Module
----------------------------------------------------------------
local fly = {
    attachment = nil,
    linearVel = nil,
    align = nil,
    enabled = false,
}

local function destroyFly()
    if fly.linearVel then pcall(function() fly.linearVel:Destroy() end) end
    if fly.align then pcall(function() fly.align:Destroy() end) end
    if fly.attachment then pcall(function() fly.attachment:Destroy() end) end
    fly.linearVel, fly.align, fly.attachment = nil, nil, nil
    fly.enabled = false
end

local function createFly()
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return false end
    
    destroyFly()
    
    fly.attachment = Instance.new("Attachment")
    fly.attachment.Parent = root
    
    fly.linearVel = Instance.new("LinearVelocity")
    fly.linearVel.Attachment0 = fly.attachment
    fly.linearVel.MaxForce = math.huge
    fly.linearVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    fly.linearVel.VectorVelocity = Vector3.zero
    fly.linearVel.Parent = root
    
    fly.align = Instance.new("AlignOrientation")
    fly.align.Attachment0 = fly.attachment
    fly.align.MaxTorque = math.huge
    fly.align.Responsiveness = 200
    fly.align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    fly.align.Parent = root
    
    fly.enabled = true
    return true
end

local originalWalkSpeed = nil
local lastJumpTime = 0
local originalCanCollide = {}

local function updateMovement(dt)
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    
    -- SpeedHack
    if Settings.SpeedHack.Enabled then
        if originalWalkSpeed == nil then originalWalkSpeed = hum.WalkSpeed end
        if hum.WalkSpeed ~= Settings.SpeedHack.Speed then
            hum.WalkSpeed = Settings.SpeedHack.Speed
        end
    elseif originalWalkSpeed and hum.WalkSpeed ~= originalWalkSpeed then
        hum.WalkSpeed = originalWalkSpeed
    end
    
    -- Infinite Jump
    if Settings.InfiniteJump and UserInputService:IsKeyDown(Enum.KeyCode.Space) and tick() - lastJumpTime > 0.25 then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        lastJumpTime = tick()
    end
    
    -- NoClip
    if Settings.NoClip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if originalCanCollide[part] == nil then
                    originalCanCollide[part] = part.CanCollide
                end
                if part.CanCollide then part.CanCollide = false end
            end
        end
    else
        for part, can in pairs(originalCanCollide) do
            if part and part.Parent then
                part.CanCollide = can
            end
        end
        table.clear(originalCanCollide)
    end
    
    -- Fly
    if Settings.Fly.Enabled then
        if not fly.enabled then createFly() end
        
        if fly.enabled and fly.linearVel then
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
            
            local speed = Settings.Fly.Speed or 60
            local desired = (move.Magnitude > 0) and (move.Unit * speed) or Vector3.zero
            fly.linearVel.VectorVelocity = desired
            
            if fly.align and Camera then
                fly.align.CFrame = Camera.CFrame
            end
        end
    else
        if fly.enabled then destroyFly() end
    end
end

RunService.Heartbeat:Connect(updateMovement)

LocalPlayer.CharacterAdded:Connect(function()
    destroyFly()
    originalWalkSpeed = nil
    table.clear(originalCanCollide)
    task.wait(0.5)
end)

----------------------------------------------------------------
-- Build GUI
----------------------------------------------------------------
local TabCombat = createTab("Combat")
TabCombat:CreateSection("Aimbot")
TabCombat:CreateToggle({
    Name = "Aimbot",
    CurrentValue = Settings.Aimbot.Enabled,
    Callback = function(v) Settings.Aimbot.Enabled = v end
})
TabCombat:CreateToggle({
    Name = "Wall Check",
    CurrentValue = Settings.Aimbot.WallCheck,
    Callback = function(v) Settings.Aimbot.WallCheck = v end
})
TabCombat:CreateToggle({
    Name = "Only Enemies",
    CurrentValue = Settings.Aimbot.OnlyEnemies,
    Callback = function(v) Settings.Aimbot.OnlyEnemies = v end
})
TabCombat:CreateSlider({
    Name = "FOV",
    Range = {10, 600},
    Increment = 10,
    CurrentValue = Settings.Aimbot.FOV,
    Callback = function(v) Settings.Aimbot.FOV = v end
})
TabCombat:CreateSlider({
    Name = "Smoothing",
    Range = {1, 20},
    Increment = 1,
    CurrentValue = Settings.Aimbot.Smoothing,
    Callback = function(v) Settings.Aimbot.Smoothing = v end
})
TabCombat:CreateSlider({
    Name = "Sensitivity",
    Range = {0.1, 3},
    Increment = 0.05,
    CurrentValue = Settings.Aimbot.Sensitivity,
    Callback = function(v) Settings.Aimbot.Sensitivity = v end
})

local TabVisuals = createTab("Visuals")
TabVisuals:CreateSection("ESP")
TabVisuals:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = Settings.ESP.Enabled,
    Callback = function(v) Settings.ESP.Enabled = v end
})
TabVisuals:CreateToggle({
    Name = "Boxes",
    CurrentValue = Settings.ESP.Boxes,
    Callback = function(v) Settings.ESP.Boxes = v end
})
TabVisuals:CreateToggle({
    Name = "Health Bar",
    CurrentValue = Settings.ESP.HealthBar,
    Callback = function(v) Settings.ESP.HealthBar = v end
})
TabVisuals:CreateToggle({
    Name = "Snaplines",
    CurrentValue = Settings.ESP.Snaplines,
    Callback = function(v) Settings.ESP.Snaplines = v end
})
TabVisuals:CreateToggle({
    Name = "Chams",
    CurrentValue = Settings.ESP.Chams,
    Callback = function(v) Settings.ESP.Chams = v end
})
TabVisuals:CreateToggle({
    Name = "Names",
    CurrentValue = Settings.ESP.Names,
    Callback = function(v) Settings.ESP.Names = v end
})
TabVisuals:CreateToggle({
    Name = "Distance",
    CurrentValue = Settings.ESP.Distance,
    Callback = function(v) Settings.ESP.Distance = v end
})
TabVisuals:CreateToggle({
    Name = "Only Enemies",
    CurrentValue = Settings.ESP.OnlyEnemies,
    Callback = function(v) Settings.ESP.OnlyEnemies = v end
})
TabVisuals:CreateSlider({
    Name = "Max Distance",
    Range = {50, 2000},
    Increment = 50,
    CurrentValue = Settings.ESP.MaxDistance,
    Callback = function(v) Settings.ESP.MaxDistance = v end
})

local TabMovement = createTab("Movement")
TabMovement:CreateSection("SpeedHack")
TabMovement:CreateToggle({
    Name = "Speed Hack",
    CurrentValue = Settings.SpeedHack.Enabled,
    Callback = function(v) Settings.SpeedHack.Enabled = v end
})
TabMovement:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 150},
    Increment = 1,
    CurrentValue = Settings.SpeedHack.Speed,
    Callback = function(v) Settings.SpeedHack.Speed = v end
})
TabMovement:CreateSection("Fly")
TabMovement:CreateToggle({
    Name = "Fly",
    CurrentValue = Settings.Fly.Enabled,
    Callback = function(v) Settings.Fly.Enabled = v end
})
TabMovement:CreateSlider({
    Name = "Fly Speed",
    Range = {20, 200},
    Increment = 5,
    CurrentValue = Settings.Fly.Speed,
    Callback = function(v) Settings.Fly.Speed = v end
})
TabMovement:CreateSection("Misc")
TabMovement:CreateToggle({
    Name = "NoClip",
    CurrentValue = Settings.NoClip,
    Callback = function(v) Settings.NoClip = v end
})
TabMovement:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = Settings.InfiniteJump,
    Callback = function(v) Settings.InfiniteJump = v end
})

local TabMisc = createTab("Misc")
TabMisc:CreateSection("Info")
TabMisc:CreateButton({
    Name = "Version: 1.0 Universal",
    Callback = function() end
})
TabMisc:CreateButton({
    Name = "RightShift = Toggle GUI",
    Callback = function() end
})
TabMisc:CreateButton({
    Name = "Works on all games",
    Callback = function() end
})

print("[ABYSS] Universal cheat loaded. RightShift to toggle GUI.")
