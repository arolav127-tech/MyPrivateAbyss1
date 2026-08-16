local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.05)
    LocalPlayer = Players.LocalPlayer
end

----------------------------------------------------------------
-- Theme
----------------------------------------------------------------
local Theme = {
    TextColor               = Color3.fromRGB(245, 248, 255),
    MutedTextColor          = Color3.fromRGB(165, 174, 190),
    Background              = Color3.fromRGB(18, 22, 30),
    Topbar                  = Color3.fromRGB(34, 41, 54),
    Sidebar                 = Color3.fromRGB(25, 31, 42),
    TabBackground           = Color3.fromRGB(34, 42, 56),
    TabBackgroundSelected   = Color3.fromRGB(230, 238, 255),
    TabTextColor            = Color3.fromRGB(190, 200, 216),
    SelectedTabTextColor    = Color3.fromRGB(28, 36, 50),
    ElementBackground       = Color3.fromRGB(34, 41, 54),
    ElementBackgroundHover  = Color3.fromRGB(46, 56, 72),
    ElementStroke           = Color3.fromRGB(105, 120, 145),
    SliderBackground        = Color3.fromRGB(72, 84, 104),
    SliderProgress          = Color3.fromRGB(130, 190, 255),
    ToggleDisabled          = Color3.fromRGB(92, 103, 122),
    ToggleEnabled           = Color3.fromRGB(105, 181, 255),
    NotificationBackground  = Color3.fromRGB(28, 35, 47),
    SectionTextColor        = Color3.fromRGB(153, 165, 184),
    Accent                  = Color3.fromRGB(112, 187, 255),
    Accent2                 = Color3.fromRGB(190, 125, 255),
    GlassTransparency       = 0.18,
    SidebarTransparency     = 0.28,
    ElementTransparency     = 0.20,
    HoverTransparency       = 0.08,
    StrokeTransparency      = 0.45,
    StrongStrokeTransparency= 0.18,
    ShadowTransparency      = 0.55,
}
local Library = { Flags = {}, Interface = nil, Version = "2.1" }

function Library:Show()
    if self.Interface then
        self.Interface.Enabled = true
    end
end

function Library:Hide()
    if self.Interface then
        self.Interface.Enabled = false
    end
end

local Connections = {}

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Connections, c)
    return c
end

local function disconnectAll()
    for i = #Connections, 1, -1 do
        local c = Connections[i]
        if c and c.Connected then pcall(function() c:Disconnect() end) end
        Connections[i] = nil
    end
end

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function new(cls, props, parent)
    local inst = Instance.new(cls)
    if props then
        for key, value in pairs(props) do
            inst[key] = value
        end
    end

    -- Many elements pass Parent inside props. Only override it when an
    -- explicit third argument was supplied. This prevents us from
    -- accidentally detaching every GUI object by assigning Parent = nil.
    if parent ~= nil then
        inst.Parent = parent
    end

    return inst
end

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function stroke(parent, color, thickness)
    return new("UIStroke", { Color = color or Theme.ElementStroke, Thickness = thickness or 1 }, parent)
end

local function tween(obj, duration, props)
    local info = TweenInfo.new(duration or 0.28, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
end

local function gradient(parent, rotation, c0, c1, transparency0, transparency1)
    local g = new("UIGradient", {
        Rotation = rotation or 90,
        Color = ColorSequence.new(c0 or Theme.Topbar, c1 or Theme.Background),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, transparency0 == nil and 0.02 or transparency0),
            NumberSequenceKeypoint.new(1, transparency1 == nil and 0.18 or transparency1),
        }),
    }, parent)
    return g
end

local function glassify(frame, opts)
    opts = opts or {}
    frame.BackgroundColor3 = opts.Color or Theme.Background
    frame.BackgroundTransparency = opts.Transparency == nil and Theme.GlassTransparency or opts.Transparency

    local s = stroke(frame, opts.StrokeColor or Theme.TextColor, opts.Thickness or 1)
    s.Transparency = opts.StrokeTransparency == nil and Theme.StrokeTransparency or opts.StrokeTransparency

    gradient(
        frame,
        opts.Rotation or 90,
        opts.GradientA or Theme.Topbar,
        opts.GradientB or Theme.Background,
        opts.GradientTransparencyA == nil and 0.02 or opts.GradientTransparencyA,
        opts.GradientTransparencyB == nil and 0.30 or opts.GradientTransparencyB
    )

    local shine = new("Frame", {
        Name = "TopHighlight",
        Size = UDim2.new(1, -18, 0, 1),
        Position = UDim2.new(0, 9, 0, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        ZIndex = (frame.ZIndex or 1) + 1,
        Parent = frame,
    })
    corner(shine, 1)
    return s
end

local function guiParent()
    local ok, pg = pcall(function()
        return LocalPlayer:WaitForChild("PlayerGui", 10)
    end)
    if ok and pg then
        return pg
    end

    if type(gethui) == "function" then
        local ok2, target = pcall(gethui)
        if ok2 and target then
            return target
        end
    end

    error("AbyssUI: PlayerGui is unavailable")
end

----------------------------------------------------------------
-- Root gui + notifications holder
----------------------------------------------------------------
local parentGui = guiParent()

local oldGui = parentGui:FindFirstChild("AbyssInterface")
if oldGui then
    pcall(function() oldGui:Destroy() end)
end

local screenGui = new("ScreenGui", {
    Name = "AbyssInterface",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999999,
    Enabled = true,
})
screenGui.Parent = parentGui
Library.Interface = screenGui

local notifyHolder = new("Frame", {
    Name = "Notifications",
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -296, 0, 10),
    Size = UDim2.new(0, 286, 1, -20),
    Parent = screenGui,
})
local notifyLayout = new("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
}, notifyHolder)

----------------------------------------------------------------
-- Config persistence
----------------------------------------------------------------
local configSettings = { Enabled = false, FolderName = "AbyssUI", FileName = "Config" }

local function fsAvailable()
    return type(writefile) == "function" and type(readfile) == "function"
        and type(isfile) == "function" and type(makefolder) == "function"
        and type(isfolder) == "function"
end

local function saveConfiguration()
    if not configSettings.Enabled or not fsAvailable() then return end
    local data = {}
    for flag, entry in pairs(Library.Flags) do
        data[flag] = entry.Get()
    end
    pcall(function()
        if not isfolder(configSettings.FolderName) then
            makefolder(configSettings.FolderName)
        end
        local path = configSettings.FolderName .. "/" .. configSettings.FileName .. ".json"
        writefile(path, HttpService:JSONEncode(data))
    end)
end

function Library:LoadConfiguration()
    if not configSettings.Enabled or not fsAvailable() then return false end
    local path = configSettings.FolderName .. "/" .. configSettings.FileName .. ".json"
    if not isfile(path) then return false end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(decoded) ~= "table" then return false end
    for flag, value in pairs(decoded) do
        local entry = Library.Flags[flag]
        if entry then
            pcall(entry.Apply, value)
        end
    end
    return true
end

----------------------------------------------------------------
-- Notify
----------------------------------------------------------------
function Library:Notify(data)
    task.spawn(function()
        data = data or {}
        local duration = data.Duration or 4

        local box = new("Frame", {
            BackgroundColor3 = Theme.NotificationBackground,
            BackgroundTransparency = 0.22,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Parent = notifyHolder,
        })
        corner(box, 14)
        gradient(box, 90, Color3.fromRGB(60, 72, 94), Color3.fromRGB(27, 33, 44), 0.02, 0.28)
        local line = stroke(box, Color3.fromRGB(235, 242, 255), 1)
        line.Transparency = 1

        new("UIPadding", {
            PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
        }, box)
        new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, box)

        local ttl = new("TextLabel", {
            BackgroundTransparency = 1,
            Text = data.Title or "Notification",
            TextColor3 = Theme.TextColor,
            Font = Enum.Font.GothamSemibold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 18),
            TextTransparency = 1,
            Parent = box,
        })

        local desc = new("TextLabel", {
            BackgroundTransparency = 1,
            Text = data.Content or "",
            TextColor3 = Theme.TextColor,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextTransparency = 1,
            Parent = box,
        })

        tween(box, 0.25, { BackgroundTransparency = 0 })
        tween(line, 0.25, { Transparency = 0 })
        tween(ttl, 0.25, { TextTransparency = 0 })
        tween(desc, 0.25, { TextTransparency = 0.15 })

        task.wait(duration)

        tween(box, 0.3, { BackgroundTransparency = 1 })
        tween(line, 0.3, { Transparency = 1 })
        tween(ttl, 0.3, { TextTransparency = 1 })
        tween(desc, 0.3, { TextTransparency = 1 })
        task.wait(0.32)
        box:Destroy()
    end)
end

----------------------------------------------------------------
-- Window
----------------------------------------------------------------
function Library:CreateWindow(settings)
    settings = settings or {}
    if settings.ConfigurationSaving then
        configSettings.Enabled = settings.ConfigurationSaving.Enabled or false
        configSettings.FolderName = settings.ConfigurationSaving.FolderName or configSettings.FolderName
        configSettings.FileName = settings.ConfigurationSaving.FileName or configSettings.FileName
    end

    if settings.Glass ~= false then
        Theme.GlassTransparency = settings.GlassTransparency or Theme.GlassTransparency
    end

    local shadow = new("Frame", {
        Name = "Shadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 8),
        Size = UDim2.new(0, 512, 0, 487),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = Theme.ShadowTransparency,
        BorderSizePixel = 0,
        Parent = screenGui,
    })
    corner(shadow, 18)

    local main = new("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 500, 0, 475),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = Theme.GlassTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 20,
        Parent = screenGui,
    })
    corner(main, 18)
    glassify(main, {
        Transparency = Theme.GlassTransparency,
        StrokeColor = Color3.fromRGB(235, 242, 255),
        StrokeTransparency = 0.58,
        GradientA = Color3.fromRGB(45, 56, 74),
        GradientB = Color3.fromRGB(16, 20, 28),
        GradientTransparencyA = 0.04,
        GradientTransparencyB = 0.35,
    })

    local scale = new("UIScale", { Scale = 0.96 }, main)
    task.defer(function()
        tween(scale, 0.5, { Scale = 1 })
        tween(shadow, 0.5, { Position = UDim2.new(0.5, 0, 0.5, 6), BackgroundTransparency = 0.62 })
    end)

    local topbar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = Theme.Topbar,
        BackgroundTransparency = 0.30,
        BorderSizePixel = 0,
        ZIndex = 25,
        Parent = main,
    })
    corner(topbar, 18)
    gradient(topbar, 0, Color3.fromRGB(48, 58, 78), Color3.fromRGB(28, 34, 46), 0.00, 0.20)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = Theme.Topbar,
        BackgroundTransparency = 0.30,
        BorderSizePixel = 0,
        Parent = topbar,
    })

    new("TextLabel", {
        Size = UDim2.new(1, -160, 0, 20),
        Position = UDim2.new(0, 18, 0, 7),
        BackgroundTransparency = 1,
        Text = settings.Name or "Abyss UI",
        Font = Enum.Font.GothamSemibold,
        TextSize = 16,
        TextColor3 = Theme.TextColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = topbar,
    })
    new("TextLabel", {
        Size = UDim2.new(1, -160, 0, 14),
        Position = UDim2.new(0, 18, 0, 30),
        BackgroundTransparency = 1,
        Text = settings.LoadingSubtitle or "",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Theme.MutedTextColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = topbar,
    })

    local function topbarButton(text, offset)
        local btn = new("TextButton", {
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(1, offset, 0.5, -15),
            BackgroundColor3 = Theme.ElementBackground,
            BackgroundTransparency = 0.24,
            BorderSizePixel = 0,
            ZIndex = 30,
            Text = text,
            TextColor3 = Theme.TextColor,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            AutoButtonColor = false,
            Parent = topbar,
        })
        corner(btn, 9)
        stroke(btn, Color3.fromRGB(235, 242, 255), 1).Transparency = 0.78
        return btn
    end
    local hideBtn = topbarButton("×", -38)
    local minBtn  = topbarButton("–", -74)

    local sidebar = new("Frame", {
        Size = UDim2.new(0, 132, 1, -72),
        Position = UDim2.new(0, 10, 0, 64),
        BackgroundColor3 = Theme.Sidebar,
        BackgroundTransparency = Theme.SidebarTransparency,
        BorderSizePixel = 0,
        ZIndex = 21,
        Parent = main,
    })
    corner(sidebar, 14)
    gradient(sidebar, 90, Color3.fromRGB(46, 55, 72), Color3.fromRGB(25, 31, 42), 0.02, 0.28)
    stroke(sidebar, Color3.fromRGB(220, 230, 245), 1).Transparency = 0.82

    local tabList = new("Frame", {
        Size = UDim2.new(1, -12, 1, -12),
        Position = UDim2.fromOffset(6, 6),
        BackgroundTransparency = 1,
        ZIndex = 22,
        Parent = sidebar,
    })
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabList)

    local pages = new("Frame", {
        Size = UDim2.new(1, -164, 1, -72),
        Position = UDim2.new(0, 154, 0, 64),
        BackgroundTransparency = 1,
        ZIndex = 21,
        Parent = main,
    })

    local Window = { Tabs = {} }
    local selected = nil

    local function selectTab(record)
        selected = record
        for _, rec in ipairs(Window.Tabs) do
            local isSel = (rec == record)
            rec.page.Visible = isSel
            tween(rec.btn, 0.2, {
                BackgroundColor3 = isSel and Theme.TabBackgroundSelected or Theme.TabBackground,
                BackgroundTransparency = isSel and 0.02 or 0.34,
            })
            tween(rec.btn, 0.2, { TextColor3 = isSel and Theme.SelectedTabTextColor or Theme.TabTextColor })
        end
    end

    ----------------------------------------------------------------
    -- Tab
    ----------------------------------------------------------------
    function Window:CreateTab(name)
        local page = new("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.ElementStroke,
            Visible = false,
            Parent = pages,
        })
        local pageLayout = new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
        new("UIPadding", {
            PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8),
        }, page)
        connect(pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            page.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 16)
        end)

        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = Theme.TabBackground,
            BackgroundTransparency = 0.34,
            BorderSizePixel = 0,
            Text = "   " .. tostring(name),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.TabTextColor,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            AutoButtonColor = false,
            ZIndex = 23,
            Parent = tabList,
        })
        corner(btn, 10)
        stroke(btn, Color3.fromRGB(220, 230, 245), 1).Transparency = 0.88

        local record = { name = name, page = page, btn = btn }
        table.insert(Window.Tabs, record)

        connect(btn.MouseButton1Click, function() selectTab(record) end)
        connect(btn.MouseEnter, function()
            if selected ~= record then tween(btn, 0.15, { BackgroundTransparency = 0.15 }) end
        end)
        connect(btn.MouseLeave, function()
            if selected ~= record then tween(btn, 0.15, { BackgroundTransparency = 0.4 }) end
        end)

        if not selected then selectTab(record) end

        local Tab = {}
        local order = 0
        local function nextOrder()
            order = order + 1
            return order
        end

        local function elementFrame(height)
            local frame = new("Frame", {
                Size = UDim2.new(1, 0, 0, height),
                BackgroundColor3 = Theme.ElementBackground,
                BackgroundTransparency = Theme.ElementTransparency,
                BorderSizePixel = 0,
                LayoutOrder = nextOrder(),
                ZIndex = 24,
                Parent = page,
            })
            corner(frame, 10)
            glassify(frame, {
                Transparency = Theme.ElementTransparency,
                StrokeColor = Color3.fromRGB(230, 238, 250),
                StrokeTransparency = 0.86,
                GradientA = Color3.fromRGB(55, 65, 84),
                GradientB = Color3.fromRGB(31, 38, 50),
                GradientTransparencyA = 0.06,
                GradientTransparencyB = 0.36,
            })
            return frame
        end

        local function elementTitle(parent, text)
            return new("TextLabel", {
                Size = UDim2.new(0.6, -12, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = Theme.TextColor,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                Parent = parent,
            })
        end

        local function hoverize(frame)
            connect(frame.MouseEnter, function() tween(frame, 0.15, { BackgroundColor3 = Theme.ElementBackgroundHover }) end)
            connect(frame.MouseLeave, function() tween(frame, 0.15, { BackgroundColor3 = Theme.ElementBackground }) end)
        end

        local function addClick(frame, fn)
            local overlay = new("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 5,
                Parent = frame,
            })
            connect(overlay.MouseButton1Click, fn)
            return overlay
        end

        local function registerFlag(flag, name, getFn, applyFn)
            local key = flag or name
            if key then
                Library.Flags[key] = { Get = getFn, Apply = applyFn }
            end
        end

        ------------------------------------------------------------
        function Tab:CreateSection(text)
            local label = new("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text = text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = Theme.SectionTextColor,
                Font = Enum.Font.GothamSemibold,
                TextSize = 12,
                LayoutOrder = nextOrder(),
                Parent = page,
            })
            return { Set = function(_, t2) label.Text = t2 end }
        end

        function Tab:CreateDivider()
            local divider = new("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Theme.ElementStroke,
                BorderSizePixel = 0,
                LayoutOrder = nextOrder(),
                Parent = page,
            })
            divider.BackgroundTransparency = 0.15
            return { Set = function(_, visible) divider.Visible = visible ~= false end }
        end

        function Tab:CreateLabel(text)
            local frame = elementFrame(26)
            local label = elementTitle(frame, text)
            label.Size = UDim2.new(1, -16, 1, 0)
            return { Set = function(_, t2) label.Text = t2 end }
        end

        function Tab:CreateParagraph(opts)
            opts = opts or {}
            local frame = new("Frame", {
                BackgroundColor3 = Theme.ElementBackground,
                BackgroundTransparency = Theme.ElementTransparency,
                BorderSizePixel = 0,
                LayoutOrder = nextOrder(),
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
                Parent = page,
            })
            corner(frame, 6)
            stroke(frame, Theme.ElementStroke)
            new("UIPadding", {
                PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
                PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
            }, frame)
            new("UIListLayout", { Padding = UDim.new(0, 4) }, frame)
            local t = new("TextLabel", {
                BackgroundTransparency = 1,
                Text = opts.Title or "",
                TextColor3 = Theme.TextColor,
                Font = Enum.Font.GothamSemibold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(1, 0, 0, 16),
                Parent = frame,
            })
            local c = new("TextLabel", {
                BackgroundTransparency = 1,
                Text = opts.Content or "",
                TextColor3 = Theme.SectionTextColor,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = frame,
            })
            return { Set = function(_, o2) t.Text = o2.Title or t.Text; c.Text = o2.Content or c.Text end }
        end

        function Tab:CreateButton(opts)
            opts = opts or {}
            local frame = elementFrame(30)
            hoverize(frame)
            local label = elementTitle(frame, opts.Name or "Button")
            label.Size = UDim2.new(1, -16, 1, 0)
            addClick(frame, function()
                if type(opts.Callback) == "function" then pcall(opts.Callback) end
                saveConfiguration()
            end)
            return { Set = function(_, t2) label.Text = t2 end }
        end

        function Tab:CreateToggle(opts)
            opts = opts or {}
            local state = opts.CurrentValue == true
            local frame = elementFrame(30)
            hoverize(frame)
            elementTitle(frame, opts.Name or "Toggle")

            local switch = new("Frame", {
                Size = UDim2.new(0, 40, 0, 18),
                Position = UDim2.new(1, -50, 0.5, -9),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = frame,
            })
            corner(switch, 9)
            local switchStroke = stroke(switch, Theme.ElementStroke)

            local indicator = new("Frame", {
                Size = UDim2.new(0, 12, 0, 12),
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 3, 0.5, 0),
                BackgroundColor3 = Theme.ToggleDisabled,
                BorderSizePixel = 0,
                Parent = switch,
            })
            corner(indicator, 6)

            local settingsObj = { CurrentValue = state, Flag = opts.Flag }

            local function apply(value, fireCallback)
                state = (value == true)
                settingsObj.CurrentValue = state
                if state then
                    tween(indicator, 0.2, { Position = UDim2.new(1, -15, 0.5, 0), BackgroundColor3 = Theme.ToggleEnabled })
                    tween(switchStroke, 0.2, { Color = Theme.Accent })
                else
                    tween(indicator, 0.2, { Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = Theme.ToggleDisabled })
                    tween(switchStroke, 0.2, { Color = Theme.ElementStroke })
                end
                if fireCallback and type(opts.Callback) == "function" then
                    pcall(opts.Callback, state)
                end
            end

            addClick(frame, function()
                apply(not state, true)
                saveConfiguration()
            end)

            function settingsObj:Set(value)
                apply(value, true)
                saveConfiguration()
            end

            registerFlag(opts.Flag, opts.Name,
                function() return settingsObj.CurrentValue end,
                function(value) apply(value, true) end)

            apply(state, false)
            return settingsObj
        end

        function Tab:CreateSlider(opts)
            opts = opts or {}
            local min = opts.Range and opts.Range[1] or 0
            local max = opts.Range and opts.Range[2] or 100
            local increment = opts.Increment or 1
            local value = tonumber(opts.CurrentValue) or min

            local frame = elementFrame(40)
            hoverize(frame)
            elementTitle(frame, opts.Name or "Slider")

            local info = new("TextLabel", {
                Size = UDim2.new(0, 90, 0, 16),
                Position = UDim2.new(1, -100, 0, 6),
                BackgroundTransparency = 1,
                TextColor3 = Theme.TextColor,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame,
            })

            local track = new("Frame", {
                Size = UDim2.new(1, -20, 0, 6),
                Position = UDim2.new(0, 10, 0, 26),
                BackgroundColor3 = Theme.SliderBackground,
                BorderSizePixel = 0,
                Parent = frame,
            })
            corner(track, 3)

            local progress = new("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = Theme.SliderProgress,
                BorderSizePixel = 0,
                Parent = track,
            })
            corner(progress, 3)

            local settingsObj = { CurrentValue = value, Flag = opts.Flag }

            local function apply(newValue, fireCallback)
                newValue = math.clamp(newValue, min, max)
                newValue = math.floor(newValue / increment + 0.5) * increment
                newValue = math.clamp(newValue, min, max)
                newValue = math.floor(newValue * 1000000 + 0.5) / 1000000
                value = newValue
                settingsObj.CurrentValue = value
                local ratio = 0
                if max > min then ratio = (value - min) / (max - min) end
                tween(progress, 0.15, { Size = UDim2.new(ratio, 0, 1, 0) })
                if opts.Suffix then
                    info.Text = tostring(value) .. " " .. opts.Suffix
                else
                    info.Text = tostring(value)
                end
                if fireCallback and type(opts.Callback) == "function" then
                    pcall(opts.Callback, value)
                end
            end

            local dragging = false
            local function fromX(x)
                local ratio = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
                apply(min + (max - min) * ratio, true)
            end

            connect(track.InputBegan, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    fromX(input.Position.X)
                end
            end)
            connect(UserInputService.InputChanged, function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    fromX(input.Position.X)
                end
            end)
            connect(UserInputService.InputEnded, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    if dragging then saveConfiguration() end
                    dragging = false
                end
            end)

            function settingsObj:Set(v)
                apply(v, true)
                saveConfiguration()
            end

            registerFlag(opts.Flag, opts.Name,
                function() return settingsObj.CurrentValue end,
                function(v) apply(v, true) end)

            apply(value, false)
            return settingsObj
        end

        function Tab:CreateDropdown(opts)
            opts = opts or {}
            local options = opts.Options or {}
            local current = {}
            if opts.CurrentOption then
                if type(opts.CurrentOption) == "string" then
                    current = { opts.CurrentOption }
                elseif type(opts.CurrentOption) == "table" then
                    current = { opts.CurrentOption[1] }
                end
            end

            local open = false
            local header = elementFrame(32)
            hoverize(header)
            elementTitle(header, opts.Name or "Dropdown")

            local selectedLabel = new("TextLabel", {
                Size = UDim2.new(0.35, -30, 1, 0),
                Position = UDim2.new(0.65, -16, 0, 0),
                BackgroundTransparency = 1,
                Text = current[1] or "None",
                TextColor3 = Theme.SectionTextColor,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = header,
            })

            local arrow = new("TextLabel", {
                Size = UDim2.new(0, 16, 1, 0),
                Position = UDim2.new(1, -22, 0, 0),
                BackgroundTransparency = 1,
                Text = "+",
                TextColor3 = Theme.SectionTextColor,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                Parent = header,
            })

            local list = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundColor3 = Theme.ElementBackground,
                BackgroundTransparency = Theme.ElementTransparency,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Visible = false,
                LayoutOrder = nextOrder(),
                Parent = page,
            })
            corner(list, 6)
            stroke(list, Theme.ElementStroke)
            local listLayout = new("UIListLayout", { Padding = UDim.new(0, 4) }, list)
            new("UIPadding", {
                PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
                PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
            }, list)

            local settingsObj = { CurrentOption = current, Options = options, Flag = opts.Flag }

            local setOpen

            local function rebuild()
                for _, child in ipairs(list:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                for _, opt in ipairs(options) do
                    local optBtn = new("TextButton", {
                        Size = UDim2.new(1, 0, 0, 24),
                        BackgroundColor3 = Theme.TabBackground,
                        BorderSizePixel = 0,
                        Text = "  " .. opt,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextColor3 = table.find(current, opt) and Theme.SelectedTabTextColor or Theme.TabTextColor,
                        Font = Enum.Font.Gotham,
                        TextSize = 12,
                        AutoButtonColor = false,
                        Parent = list,
                    })
                    corner(optBtn, 4)
                    connect(optBtn.MouseButton1Click, function()
                        current = { opt }
                        settingsObj.CurrentOption = current
                        selectedLabel.Text = opt
                        if type(opts.Callback) == "function" then pcall(opts.Callback, current) end
                        rebuild()
                        setOpen(false)
                        saveConfiguration()
                    end)
                end
            end

            setOpen = function(state)
                open = state
                arrow.Text = open and "-" or "+"
                list.Visible = true
                local targetH = open and math.min(#options * 28 + 12, 150) or 0
                tween(list, 0.2, { Size = UDim2.new(1, 0, 0, targetH) })
                if not open then
                    task.delay(0.22, function()
                        if not open then list.Visible = false end
                    end)
                end
            end

            addClick(header, function() setOpen(not open) end)

            function settingsObj:Set(opt)
                if type(opt) == "string" then opt = { opt } end
                current = { opt[1] }
                settingsObj.CurrentOption = current
                selectedLabel.Text = current[1] or "None"
                if type(opts.Callback) == "function" then pcall(opts.Callback, current) end
                rebuild()
                saveConfiguration()
            end

            function settingsObj:Refresh(newOptions)
                options = newOptions or {}
                settingsObj.Options = options
                rebuild()
                if open then setOpen(true) end
            end

            registerFlag(opts.Flag, opts.Name,
                function() return settingsObj.CurrentOption end,
                function(v) settingsObj:Set(v) end)

            rebuild()
            return settingsObj
        end

        function Tab:CreateKeybind(opts)
            opts = opts or {}
            local currentKey = opts.CurrentKeybind or nil
            local frame = elementFrame(30)
            hoverize(frame)
            elementTitle(frame, opts.Name or "Keybind")

            local keyBtn = new("TextButton", {
                Size = UDim2.new(0, 70, 0, 20),
                Position = UDim2.new(1, -80, 0.5, -10),
                BackgroundColor3 = Theme.TabBackground,
                BorderSizePixel = 0,
                Text = currentKey and tostring(currentKey) or "None",
                TextColor3 = Theme.TextColor,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                AutoButtonColor = false,
                Parent = frame,
            })
            corner(keyBtn, 5)

            local capturing = false
            local settingsObj = { CurrentKeybind = currentKey, Flag = opts.Flag }

            connect(UserInputService.InputBegan, function(input, processed)
                if capturing and input.KeyCode ~= Enum.KeyCode.Unknown then
                    capturing = false
                    local keyName = input.KeyCode.Name
                    settingsObj.CurrentKeybind = keyName
                    keyBtn.Text = keyName
                    if type(opts.Callback) == "function" then pcall(opts.Callback, keyName) end
                    saveConfiguration()
                elseif not processed and settingsObj.CurrentKeybind and Enum.KeyCode[settingsObj.CurrentKeybind] and input.KeyCode == Enum.KeyCode[settingsObj.CurrentKeybind] then
                    if type(opts.Callback) == "function" then pcall(opts.Callback, settingsObj.CurrentKeybind) end
                end
            end)

            connect(keyBtn.MouseButton1Click, function()
                capturing = true
                keyBtn.Text = "press"
            end)

            function settingsObj:Set(keyName)
                settingsObj.CurrentKeybind = keyName
                keyBtn.Text = tostring(keyName or "None")
                saveConfiguration()
            end

            registerFlag(opts.Flag, opts.Name,
                function() return settingsObj.CurrentKeybind end,
                function(v) settingsObj:Set(v) end)

            return settingsObj
        end

        function Tab:CreateInput(opts)
            opts = opts or {}
            local frame = elementFrame(32)
            hoverize(frame)
            elementTitle(frame, opts.Name or "Input")

            local box = new("TextBox", {
                Size = UDim2.new(0, 140, 0, 20),
                Position = UDim2.new(1, -150, 0.5, -10),
                BackgroundColor3 = Theme.TabBackground,
                BorderSizePixel = 0,
                PlaceholderText = opts.PlaceholderText or "",
                Text = opts.CurrentValue or "",
                TextColor3 = Theme.TextColor,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                Parent = frame,
            })
            corner(box, 5)

            local settingsObj = { CurrentValue = box.Text, Flag = opts.Flag }

            connect(box.FocusLost, function()
                settingsObj.CurrentValue = box.Text
                if type(opts.Callback) == "function" then pcall(opts.Callback, box.Text) end
                saveConfiguration()
            end)

            function settingsObj:Set(text)
                text = tostring(text or "")
                box.Text = text
                settingsObj.CurrentValue = text
                if type(opts.Callback) == "function" then pcall(opts.Callback, text) end
                saveConfiguration()
            end

            registerFlag(opts.Flag, opts.Name,
                function() return settingsObj.CurrentValue end,
                function(v) settingsObj:Set(v) end)

            return settingsObj
        end

        return Tab
    end

    ----------------------------------------------------------------
    -- Window controls
    ----------------------------------------------------------------
    local dragging, dragStart, startPos = false, nil, nil
    connect(topbar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(0.5, startPos.X.Offset + delta.X, 0.5, startPos.Y.Offset + delta.Y)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local minimized = false
    connect(minBtn.MouseButton1Click, function()
        minimized = not minimized
        if minimized then
            tabList.Visible = false
            pages.Visible = false
            tween(main, 0.30, { Size = UDim2.new(0, 500, 0, 58) })
            tween(shadow, 0.30, { Size = UDim2.new(0, 512, 0, 70) })
        else
            tabList.Visible = true
            pages.Visible = true
            tween(main, 0.30, { Size = UDim2.new(0, 500, 0, 475) })
            tween(shadow, 0.30, { Size = UDim2.new(0, 512, 0, 487) })
        end
    end)

    connect(hideBtn.MouseButton1Click, function()
        main.Visible = false
        shadow.Visible = false
    end)

    local toggleKey = settings.ToggleUIKeybind or Enum.KeyCode.RightShift
    if type(toggleKey) == "string" then
        toggleKey = Enum.KeyCode[toggleKey] or Enum.KeyCode.RightShift
    end
    connect(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        if input.KeyCode == toggleKey then
            main.Visible = not main.Visible
            shadow.Visible = main.Visible
        end
    end)

    function Window:Destroy()
        if Window._destroyed then return end
        Window._destroyed = true
        disconnectAll()
        Library.Flags = {}
        if main and main.Parent then main:Destroy() end
        if shadow and shadow.Parent then shadow:Destroy() end
        if screenGui and #screenGui:GetChildren() == 0 then
            pcall(function() screenGui:Destroy() end)
        end
        Library.Interface = nil
    end

    function Window:Show()
        if not Window._destroyed then
            main.Visible = true
            shadow.Visible = true
        end
    end

    function Window:Hide()
        if not Window._destroyed then
            main.Visible = false
            shadow.Visible = false
        end
    end

    function Window:Minimize()
        if not minimized then minBtn:Activate() end
    end

    function Window:Restore()
        if minimized then minBtn:Activate() end
    end

    function Window:SetGlassTransparency(value)
        value = math.clamp(tonumber(value) or Theme.GlassTransparency, 0, 1)
        Theme.GlassTransparency = value
        main.BackgroundTransparency = value
    end

    if configSettings.Enabled then
        task.defer(function() Library:LoadConfiguration() end)
    end

    return Window
end

function Library:Destroy()
    disconnectAll()
    if screenGui and screenGui.Parent then screenGui:Destroy() end
    Library.Interface = nil
    Library.Flags = {}
end

return Library