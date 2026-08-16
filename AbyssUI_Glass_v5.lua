--[[
    Abyss UI Glass v5.0
    Rayfield-inspired API, redesigned glass/acrylic interface.

    Highlights:
      * Glass / acrylic-style layered UI
      * Icon sidebar + active indicator
      * Search per tab + Ctrl+K command palette
      * ColorPicker (HSV)
      * Dropdown + MultiDropdown
      * Resizable + draggable window
      * Clamped drag + resize on mouse and touch
      * Reactive theme tokens + accent updates
      * In-memory profiles + ExportProfile/ImportProfile (Studio-safe)
      * Settings + Themes built-in tabs
      * Fuzzy search + keyboard-navigable command center
      * Accessibility: reduced motion, high contrast, density, UI scale
      * Safer flags/configuration and callback warnings
      * Premium interaction states and motion budget
      * Desktop + touch friendly design
]]


--!strict-compatible design (the file remains runtime-friendly; consumers can migrate
-- individual internals to ModuleScripts without changing the public API).
-- Public profile persistence intentionally uses ExportProfile/ImportProfile instead of
-- executor-only filesystem functions.
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local RunService       = game:GetService("RunService")
local GuiService       = game:GetService("GuiService")

if not RunService:IsClient() then
    error("AbyssUI: this library must run on the client")
end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- Theme
----------------------------------------------------------------
local Theme = {
    TextColor                = Color3.fromRGB(245, 248, 255),
    MutedTextColor           = Color3.fromRGB(164, 174, 191),
    Background               = Color3.fromRGB(16, 20, 28),
    Topbar                   = Color3.fromRGB(44, 53, 70),
    Sidebar                  = Color3.fromRGB(24, 30, 41),
    TabBackground            = Color3.fromRGB(42, 51, 68),
    TabBackgroundSelected    = Color3.fromRGB(236, 243, 255),
    TabTextColor             = Color3.fromRGB(184, 195, 213),
    SelectedTabTextColor     = Color3.fromRGB(29, 36, 49),
    ElementBackground        = Color3.fromRGB(39, 48, 64),
    ElementBackgroundHover   = Color3.fromRGB(50, 62, 82),
    ElementStroke            = Color3.fromRGB(214, 225, 242),
    SliderBackground         = Color3.fromRGB(74, 88, 112),
    SliderProgress           = Color3.fromRGB(132, 194, 255),
    ToggleDisabled           = Color3.fromRGB(100, 111, 130),
    ToggleEnabled            = Color3.fromRGB(114, 191, 255),
    NotificationBackground   = Color3.fromRGB(28, 35, 48),
    SectionTextColor         = Color3.fromRGB(148, 162, 183),
    Accent                   = Color3.fromRGB(112, 188, 255),
    Accent2                  = Color3.fromRGB(191, 131, 255),
    GlassTransparency        = 0.18,
    SidebarTransparency      = 0.24,
    ElementTransparency      = 0.20,
    HoverTransparency        = 0.08,
    StrokeTransparency       = 0.50,
    StrongStrokeTransparency = 0.16,
    ShadowTransparency       = 0.58,
    MinWidth                 = 420,
    MinHeight                = 320,
    MaxWidth                 = 900,
    MaxHeight                = 760,
}

local ThemePresets = {
    Glass = {
        TextColor = Color3.fromRGB(245, 248, 255),
        MutedTextColor = Color3.fromRGB(164, 174, 191),
        Background = Color3.fromRGB(16, 20, 28),
        Topbar = Color3.fromRGB(44, 53, 70),
        Sidebar = Color3.fromRGB(24, 30, 41),
        TabBackground = Color3.fromRGB(42, 51, 68),
        TabBackgroundSelected = Color3.fromRGB(236, 243, 255),
        TabTextColor = Color3.fromRGB(184, 195, 213),
        SelectedTabTextColor = Color3.fromRGB(29, 36, 49),
        ElementBackground = Color3.fromRGB(39, 48, 64),
        ElementBackgroundHover = Color3.fromRGB(50, 62, 82),
        ElementStroke = Color3.fromRGB(214, 225, 242),
        SliderBackground = Color3.fromRGB(74, 88, 112),
        SliderProgress = Color3.fromRGB(132, 194, 255),
        ToggleDisabled = Color3.fromRGB(100, 111, 130),
        ToggleEnabled = Color3.fromRGB(114, 191, 255),
        NotificationBackground = Color3.fromRGB(28, 35, 48),
        SectionTextColor = Color3.fromRGB(148, 162, 183),
        Accent = Color3.fromRGB(112, 188, 255),
        Accent2 = Color3.fromRGB(191, 131, 255),
    },
    DarkBlue = {
        Background = Color3.fromRGB(10, 16, 28), Topbar = Color3.fromRGB(18, 30, 52), Sidebar = Color3.fromRGB(15, 24, 40),
        TabBackground = Color3.fromRGB(28, 46, 72), TabBackgroundSelected = Color3.fromRGB(118, 184, 255),
        TabTextColor = Color3.fromRGB(170, 196, 226), SelectedTabTextColor = Color3.fromRGB(9, 20, 36),
        ElementBackground = Color3.fromRGB(20, 34, 54), ElementBackgroundHover = Color3.fromRGB(30, 48, 76),
        ElementStroke = Color3.fromRGB(145, 192, 238), SliderBackground = Color3.fromRGB(47, 73, 103),
        SliderProgress = Color3.fromRGB(98, 182, 255), ToggleDisabled = Color3.fromRGB(83, 106, 130),
        ToggleEnabled = Color3.fromRGB(86, 174, 255), NotificationBackground = Color3.fromRGB(17, 29, 47),
        SectionTextColor = Color3.fromRGB(133, 164, 196), Accent = Color3.fromRGB(95, 180, 255), Accent2 = Color3.fromRGB(130, 120, 255),
        TextColor = Color3.fromRGB(240, 247, 255), MutedTextColor = Color3.fromRGB(157, 182, 208),
    },
    Ocean = {
        Background = Color3.fromRGB(8, 22, 25), Topbar = Color3.fromRGB(18, 52, 58), Sidebar = Color3.fromRGB(12, 37, 42),
        TabBackground = Color3.fromRGB(23, 61, 67), TabBackgroundSelected = Color3.fromRGB(146, 242, 231),
        TabTextColor = Color3.fromRGB(170, 211, 210), SelectedTabTextColor = Color3.fromRGB(12, 35, 39),
        ElementBackground = Color3.fromRGB(18, 48, 53), ElementBackgroundHover = Color3.fromRGB(28, 66, 70),
        ElementStroke = Color3.fromRGB(152, 226, 220), SliderBackground = Color3.fromRGB(49, 90, 92),
        SliderProgress = Color3.fromRGB(94, 227, 214), ToggleDisabled = Color3.fromRGB(82, 121, 122),
        ToggleEnabled = Color3.fromRGB(89, 220, 203), NotificationBackground = Color3.fromRGB(13, 34, 38),
        SectionTextColor = Color3.fromRGB(140, 191, 188), Accent = Color3.fromRGB(98, 224, 211), Accent2 = Color3.fromRGB(151, 160, 255),
        TextColor = Color3.fromRGB(238, 255, 253), MutedTextColor = Color3.fromRGB(163, 201, 198),
    },
}

local function applyThemePreset(name)
    local preset = ThemePresets[name]
    if not preset then
        warn("[AbyssUI] Unknown theme: " .. tostring(name))
        return false
    end
    for key, value in pairs(preset) do Theme[key] = value end
    return true
end

local function currentThemeName()
    for name, preset in pairs(ThemePresets) do
        local same = true
        for key, value in pairs(preset) do
            if Theme[key] ~= value then same = false break end
        end
        if same then return name end
    end
    return nil
end

local Library = {
    Flags = {},
    Interface = nil,
    Window = nil,
    Version = "5.0.0",
    API = "5.0",
    ThemePresets = ThemePresets,
    PreferGetHui = false,
}

local UIState = {
    ReducedMotion = false,
    HighContrast = false,
    Density = "Comfortable",
    Scale = 1,
    TouchFriendly = true,
}

local ThemeListeners = {}

local function subscribeTheme(fn)
    if type(fn) ~= "function" then return function() end end
    ThemeListeners[#ThemeListeners + 1] = fn
    local alive = true
    return function()
        if not alive then return end
        alive = false
        for i = #ThemeListeners, 1, -1 do
            if ThemeListeners[i] == fn then
                table.remove(ThemeListeners, i)
                break
            end
        end
    end
end

local function emitThemeChanged()
    for i = #ThemeListeners, 1, -1 do
        local fn = ThemeListeners[i]
        local ok = pcall(fn, Theme, UIState)
        if not ok then table.remove(ThemeListeners, i) end
    end
end

local function motionDuration(seconds)
    if UIState.ReducedMotion then return 0 end
    return seconds
end

local function adaptiveTransparency(base)
    if UIState.HighContrast then
        return math.clamp((tonumber(base) or 0) * 0.35, 0, 0.98)
    end
    return base
end

----------------------------------------------------------------
-- Connection manager (Maid-style)
----------------------------------------------------------------
local function createMaid()
    local maid = { _items = {} }

    function maid:Give(item)
        self._items[#self._items + 1] = item
        return item
    end

    function maid:Connect(signal, fn)
        local connection = signal:Connect(fn)
        return self:Give(connection)
    end

    function maid:Cleanup()
        for i = #self._items, 1, -1 do
            local item = self._items[i]
            self._items[i] = nil
            pcall(function()
                if typeof(item) == "RBXScriptConnection" then
                    if item.Connected then item:Disconnect() end
                elseif type(item) == "function" then
                    item()
                elseif typeof(item) == "Instance" then
                    item:Destroy()
                end
            end)
        end
    end

    return maid
end

local LibraryMaid = createMaid()
local WindowMaid = nil

----------------------------------------------------------------
-- Utility helpers
----------------------------------------------------------------
local function safeCall(label, fn, ...)
    if type(fn) ~= "function" then return true end
    local ok, result = pcall(fn, ...)
    if not ok then
        warn("[AbyssUI] Callback error (" .. tostring(label) .. "): " .. tostring(result))
    end
    return ok, result
end

local function new(className, props, parent)
    local inst = Instance.new(className)
    if props then
        for key, value in pairs(props) do
            inst[key] = value
        end
    end
    if inst:IsA("GuiButton") or inst:IsA("TextBox") then
        pcall(function() inst.Selectable = true end)
    end
    if parent ~= nil then
        inst.Parent = parent
    end
    return inst
end

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

local function stroke(parent, color, thickness, transparency)
    local s = new("UIStroke", {
        Color = color or Theme.ElementStroke,
        Thickness = thickness or 1,
    }, parent)
    if transparency ~= nil then
        s.Transparency = transparency
    end
    return s
end

local function tween(obj, duration, props, easingStyle)
    if not obj or obj.Parent == nil then return nil end
    local info = TweenInfo.new(
        motionDuration(duration or 0.24),
        easingStyle or Enum.EasingStyle.Exponential,
        Enum.EasingDirection.Out
    )
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
end

local function gradient(parent, rotation, c0, c1, transparency0, transparency1)
    return new("UIGradient", {
        Rotation = rotation or 90,
        Color = ColorSequence.new(c0 or Theme.Topbar, c1 or Theme.Background),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, transparency0 == nil and 0.02 or transparency0),
            NumberSequenceKeypoint.new(1, transparency1 == nil and 0.28 or transparency1),
        }),
    }, parent)
end

local function glassify(frame, opts)
    opts = opts or {}
    frame:SetAttribute("AbyssGlass", true)
    frame:SetAttribute("AbyssGlassBase", (opts.Transparency == nil and Theme.GlassTransparency or opts.Transparency))
    frame:SetAttribute("AbyssGlassOffset", (opts.Transparency == nil and Theme.GlassTransparency or opts.Transparency) - Theme.GlassTransparency)
    frame.BackgroundColor3 = opts.Color or Theme.Background
    frame.BackgroundTransparency = opts.Transparency == nil and Theme.GlassTransparency or opts.Transparency

    stroke(
        frame,
        opts.StrokeColor or Color3.fromRGB(232, 240, 253),
        opts.Thickness or 1,
        opts.StrokeTransparency == nil and Theme.StrokeTransparency or opts.StrokeTransparency
    )

    gradient(
        frame,
        opts.Rotation or 90,
        opts.GradientA or Theme.Topbar,
        opts.GradientB or Theme.Background,
        opts.GradientTransparencyA == nil and 0.02 or opts.GradientTransparencyA,
        opts.GradientTransparencyB == nil and 0.32 or opts.GradientTransparencyB
    )

    new("Frame", {
        Name = "TopHighlight",
        Size = UDim2.new(1, -18, 0, 1),
        Position = UDim2.new(0, 9, 0, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        ZIndex = frame.ZIndex + 2,
        Parent = frame,
    })
end

local function normalizeKey(key)
    if typeof(key) == "EnumItem" then
        return key.Name
    end
    if type(key) == "string" then
        return key
    end
    if key ~= nil then
        return tostring(key)
    end
    return nil
end

local function resolveKey(key)
    local name = normalizeKey(key)
    if not name then return Enum.KeyCode.RightShift, "RightShift" end
    local enumItem = Enum.KeyCode[name]
    if enumItem then return enumItem, name end
    warn("[AbyssUI] Unknown KeyCode '" .. tostring(name) .. "', using RightShift")
    return Enum.KeyCode.RightShift, "RightShift"
end

local function clampNumber(value, min, max)
    value = tonumber(value) or min
    if min > max then min, max = max, min end
    return math.clamp(value, min, max)
end

local function formatNumber(value)
    if math.abs(value - math.floor(value)) < 1e-8 then
        return tostring(math.floor(value))
    end
    return string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", "")
end

local function makeShadow(screenGui, position, size)
    local shadow = new("Frame", {
        Name = "Shadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = position,
        Size = size,
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = Theme.ShadowTransparency,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = screenGui,
    })
    corner(shadow, 18)
    return shadow
end

----------------------------------------------------------------
-- GUI root
local screenGui = nil
local notifyHolder = nil

local function ensureRootGui()
    if screenGui and screenGui.Parent then
        return screenGui
    end

    local oldGui = PlayerGui:FindFirstChild("AbyssInterface")
    if oldGui then pcall(function() oldGui:Destroy() end) end

    screenGui = new("ScreenGui", {
        Name = "AbyssInterface",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999999,
        Enabled = true,
    }, PlayerGui)

    notifyHolder = new("Frame", {
        Name = "Notifications",
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -318, 0, 14),
        Size = UDim2.new(0, 304, 1, -28),
        ZIndex = 500,
        Parent = screenGui,
    })
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom }, notifyHolder)

    Library.Interface = screenGui
    return screenGui
end

ensureRootGui()

----------------------------------------------------------------
-- Configuration / profiles (Studio-safe)
----------------------------------------------------------------
local configSettings = {
    Enabled = true,
    SavePosition = true,
    AutoLoad = true,
}

local memoryProfile = nil

local function captureConfiguration()
    local data = {
        __AbyssUI = {
            Version = Library.Version,
            Position = nil,
            Size = nil,
            RestoredHeight = nil,
            Minimized = false,
            Theme = currentThemeName(),
            Accent = Theme.Accent,
            Accent2 = Theme.Accent2,
            UIState = {
                ReducedMotion = UIState.ReducedMotion,
                HighContrast = UIState.HighContrast,
                Density = UIState.Density,
                Scale = UIState.Scale,
            },
        },
    }

    if Library.Window and not Library.Window._destroyed then
        local window = Library.Window
        local main = window._main
        if main then
            if configSettings.SavePosition then
                data.__AbyssUI.Position = { X = main.Position.X.Offset, Y = main.Position.Y.Offset }
            end
            data.__AbyssUI.Size = {
                X = main.Size.X.Offset,
                Y = window._minimized and (window._restoredHeight or main.Size.Y.Offset) or main.Size.Y.Offset,
            }
            data.__AbyssUI.RestoredHeight = window._restoredHeight
            data.__AbyssUI.Minimized = window._minimized == true
        end
    end

    for flag, entry in pairs(Library.Flags) do
        local ok, value = pcall(entry.Get)
        if ok then data[flag] = value end
    end
    return data
end

local function saveConfiguration()
    if not configSettings.Enabled then return false end
    memoryProfile = captureConfiguration()
    return true
end

function Library:ExportProfile()
    local data = captureConfiguration()
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not ok then
        warn("[AbyssUI] Failed to encode profile: " .. tostring(encoded))
        return nil
    end
    return encoded
end

function Library:ImportProfile(json, options)
    options = options or {}
    local decoded = json
    if type(json) == "string" then
        local ok, result = pcall(HttpService.JSONDecode, HttpService, json)
        if not ok then
            warn("[AbyssUI] Invalid profile JSON: " .. tostring(result))
            return false
        end
        decoded = result
    end
    if type(decoded) ~= "table" then return false end

    local meta = decoded.__AbyssUI
    if type(meta) == "table" then
        if meta.Theme and ThemePresets[meta.Theme] then self:SetTheme(meta.Theme) end
        if typeof(meta.Accent) == "Color3" then self:SetAccent(meta.Accent, meta.Accent2) end
        if type(meta.UIState) == "table" then
            UIState.ReducedMotion = meta.UIState.ReducedMotion == true
            UIState.HighContrast = meta.UIState.HighContrast == true
            UIState.Density = meta.UIState.Density == "Compact" and "Compact" or "Comfortable"
            UIState.Scale = math.clamp(tonumber(meta.UIState.Scale) or 1, 0.85, 1.25)
            emitThemeChanged()
        end
        if Library.Window and not Library.Window._destroyed then
            local main = Library.Window._main
            if main and type(meta.Size) == "table" then
                Library.Window:SetSize(meta.Size.X, meta.Size.Y, false)
            end
            if configSettings.SavePosition and type(meta.Position) == "table" and not options.SkipPosition then
                Library.Window:SetPosition(meta.Position.X, meta.Position.Y, false)
            end
            if tonumber(meta.RestoredHeight) then
                Library.Window._restoredHeight = math.clamp(tonumber(meta.RestoredHeight), Theme.MinHeight, Theme.MaxHeight)
            end
            if meta.Minimized then
                Library.Window:SetMinimized(true, false)
            end
        end
    end

    for flag, value in pairs(decoded) do
        if flag ~= "__AbyssUI" and Library.Flags[flag] then
            safeCall("profile:" .. tostring(flag), Library.Flags[flag].Apply, value)
        end
    end
    memoryProfile = decoded
    return true
end

function Library:LoadConfiguration()
    if memoryProfile == nil then return false end
    return self:ImportProfile(memoryProfile)
end

----------------------------------------------------------------
-- Notifications
----------------------------------------------------------------
function Library:Notify(data)
    if not Library.Window or Library.Window._destroyed or not notifyHolder or not notifyHolder.Parent then
        return nil
    end
    data = data or {}
    local duration = math.max(0.6, tonumber(data.Duration) or 4)
    local title = tostring(data.Title or "Notification")
    local content = tostring(data.Content or "")

    task.spawn(function()
        if not Library.Window or Library.Window._destroyed or not notifyHolder or not notifyHolder.Parent then return end
        local box = new("Frame", {
            BackgroundColor3 = Theme.NotificationBackground,
            BackgroundTransparency = 0.18,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 510,
            Parent = notifyHolder,
        })
        corner(box, 14)
        glassify(box, {
            Transparency = 0.18,
            StrokeTransparency = 0.56,
            GradientA = Color3.fromRGB(66, 80, 105),
            GradientB = Color3.fromRGB(28, 35, 47),
            GradientTransparencyA = 0.02,
            GradientTransparencyB = 0.26,
        })

        new("UIPadding", {
            PaddingTop = UDim.new(0, 11), PaddingBottom = UDim.new(0, 11),
            PaddingLeft = UDim.new(0, 13), PaddingRight = UDim.new(0, 13),
        }, box)
        new("UIListLayout", {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, box)

        local ttl = new("TextLabel", {
            BackgroundTransparency = 1,
            Text = title,
            TextColor3 = Theme.TextColor,
            Font = Enum.Font.GothamSemibold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 18),
            TextTransparency = 1,
            ZIndex = 512,
            Parent = box,
        })

        local desc = new("TextLabel", {
            BackgroundTransparency = 1,
            Text = content,
            TextColor3 = Theme.TextColor,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextTransparency = 1,
            ZIndex = 512,
            Parent = box,
        })

        local scale = new("UIScale", { Scale = 0.94 }, box)
        tween(scale, 0.28, { Scale = 1 })
        tween(box, 0.22, { BackgroundTransparency = 0.06 })
        tween(ttl, 0.22, { TextTransparency = 0 })
        tween(desc, 0.22, { TextTransparency = 0.10 })

        task.wait(duration)
        tween(scale, 0.22, { Scale = 0.96 })
        tween(box, 0.22, { BackgroundTransparency = 1 })
        tween(ttl, 0.18, { TextTransparency = 1 })
        tween(desc, 0.18, { TextTransparency = 1 })
        task.wait(0.24)
        if box.Parent then box:Destroy() end
    end)
end

----------------------------------------------------------------
-- Window
----------------------------------------------------------------
function Library:CreateWindow(settings)
    settings = settings or {}

    if Library.Window and not Library.Window._destroyed then
        Library.Window:Destroy()
    end

    ensureRootGui()
    WindowMaid = createMaid()

    if settings.ConfigurationSaving then
        configSettings.Enabled = settings.ConfigurationSaving.Enabled ~= false
        if settings.ConfigurationSaving.SavePosition ~= nil then configSettings.SavePosition = settings.ConfigurationSaving.SavePosition == true end
        if settings.ConfigurationSaving.AutoLoad ~= nil then configSettings.AutoLoad = settings.ConfigurationSaving.AutoLoad == true end
    end

    if settings.Theme then
        applyThemePreset(settings.Theme)
    end
    if settings.GlassTransparency ~= nil then
        Theme.GlassTransparency = math.clamp(tonumber(settings.GlassTransparency) or Theme.GlassTransparency, 0, 0.92)
    end

    local defaultSizeX = tonumber(settings.Size and settings.Size.X) or 620
    local defaultSizeY = tonumber(settings.Size and settings.Size.Y) or 540
    defaultSizeX = math.clamp(defaultSizeX, Theme.MinWidth, Theme.MaxWidth)
    defaultSizeY = math.clamp(defaultSizeY, Theme.MinHeight, Theme.MaxHeight)

    local centerPos = UDim2.new(0.5, 0, 0.5, 0)
    local shadow = makeShadow(
        screenGui,
        UDim2.new(0.5, 0, 0.5, 8),
        UDim2.fromOffset(defaultSizeX + 12, defaultSizeY + 12)
    )

    local main = new("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = centerPos,
        Size = UDim2.fromOffset(defaultSizeX, defaultSizeY),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = Theme.GlassTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 20,
        Parent = screenGui,
    })
    main:SetAttribute("AbyssRole", "Background")
    corner(main, 20)
    glassify(main, {
        Transparency = Theme.GlassTransparency,
        StrokeTransparency = 0.52,
        GradientA = Color3.fromRGB(48, 60, 80),
        GradientB = Color3.fromRGB(15, 19, 27),
        GradientTransparencyA = 0.02,
        GradientTransparencyB = 0.32,
    })

    local openScale = new("UIScale", { Scale = 0.96 }, main)
    local interfaceScale = new("UIScale", { Scale = UIState.Scale }, main)
    tween(openScale, 0.42, { Scale = 1 })
    local disconnectTheme = subscribeTheme(function()
        if interfaceScale and interfaceScale.Parent then interfaceScale.Scale = UIState.Scale end
        if sidebar then sidebar.BackgroundTransparency = adaptiveTransparency(Theme.SidebarTransparency) end
        if searchBox then searchBox.BackgroundTransparency = adaptiveTransparency(0.24) end
    end)
    WindowMaid:Give(disconnectTheme)

    local topbar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 66),
        BackgroundColor3 = Theme.Topbar,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        ZIndex = 30,
        Parent = main,
    })
    topbar:SetAttribute("AbyssRole", "Topbar")
    corner(topbar, 20)
    gradient(topbar, 0, Color3.fromRGB(63, 76, 100), Color3.fromRGB(29, 36, 49), 0.00, 0.22)
    new("Frame", {
        Name = "TopbarCornerRepair",
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = Theme.Topbar,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        ZIndex = 30,
        Parent = topbar,
    })

    new("TextLabel", {
        Size = UDim2.new(1, -230, 0, 22),
        Position = UDim2.fromOffset(18, 9),
        BackgroundTransparency = 1,
        Text = tostring(settings.Name or "Abyss UI"),
        Font = Enum.Font.GothamSemibold,
        TextSize = 17,
        TextColor3 = Theme.TextColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 31,
        Parent = topbar,
    })

    new("TextLabel", {
        Size = UDim2.new(1, -230, 0, 14),
        Position = UDim2.fromOffset(18, 34),
        BackgroundTransparency = 1,
        Text = tostring(settings.LoadingSubtitle or "Glass Edition"),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Theme.MutedTextColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 31,
        Parent = topbar,
    })

    local searchBox = new("TextBox", {
        Size = UDim2.fromOffset(145, 30),
        Position = UDim2.new(1, -224, 0.5, -15),
        BackgroundColor3 = Theme.ElementBackground,
        BackgroundTransparency = 0.24,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = "Search  /  Ctrl+K",
        Text = "",
        TextColor3 = Theme.TextColor,
        PlaceholderColor3 = Theme.MutedTextColor,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 32,
        Parent = topbar,
    })
    corner(searchBox, 10)
    stroke(searchBox, Color3.fromRGB(229, 238, 252), 1, 0.82)
    new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8) }, searchBox)

    local function topbarButton(text, offset)
        local btn = new("TextButton", {
            Size = UDim2.fromOffset(30, 30),
            Position = UDim2.new(1, offset, 0.5, -15),
            BackgroundColor3 = Theme.ElementBackground,
            BackgroundTransparency = 0.22,
            BorderSizePixel = 0,
            Text = text,
            TextColor3 = Theme.TextColor,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            AutoButtonColor = false,
            ZIndex = 33,
            Parent = topbar,
        })
        corner(btn, 9)
        stroke(btn, Color3.fromRGB(235, 242, 255), 1, 0.78)
        return btn
    end

    local minimizeButton = topbarButton("–", -76)
    local closeButton = topbarButton("×", -40)

    local sidebar = new("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 154, 1, -82),
        Position = UDim2.fromOffset(10, 72),
        BackgroundColor3 = Theme.Sidebar,
        BackgroundTransparency = Theme.SidebarTransparency,
        BorderSizePixel = 0,
        ZIndex = 21,
        Parent = main,
    })
    sidebar:SetAttribute("AbyssRole", "Sidebar")
    corner(sidebar, 16)
    glassify(sidebar, {
        Transparency = Theme.SidebarTransparency,
        StrokeTransparency = 0.78,
        GradientA = Color3.fromRGB(43, 53, 71),
        GradientB = Color3.fromRGB(23, 29, 39),
        GradientTransparencyA = 0.05,
        GradientTransparencyB = 0.28,
    })

    local tabList = new("ScrollingFrame", {
        Size = UDim2.new(1, -12, 1, -12),
        Position = UDim2.fromOffset(6, 6),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.ElementStroke,
        CanvasSize = UDim2.new(),
        ZIndex = 23,
        Parent = sidebar,
    })
    local tabLayout = new("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, tabList)
    local disconnectDensityTheme = subscribeTheme(function()
        tabLayout.Padding = UDim.new(0, UIState.Density == "Compact" and 4 or 7)
        for _, rec in ipairs(Window.Tabs) do
            if rec.btn and rec.btn.Parent then
                rec.btn.Size = UDim2.new(1, 0, 0, UIState.Density == "Compact" and 34 or 38)
            end
        end
    end)
    WindowMaid:Give(disconnectDensityTheme)
    new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, tabList)
    WindowMaid:Connect(tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        tabList.CanvasSize = UDim2.fromOffset(0, tabLayout.AbsoluteContentSize.Y + 8)
    end)

    local pages = new("Frame", {
        Name = "Pages",
        Size = UDim2.new(1, -180, 1, -82),
        Position = UDim2.fromOffset(170, 72),
        BackgroundTransparency = 1,
        ZIndex = 21,
        Parent = main,
    })

    local resizeHandle = new("TextButton", {
        Name = "ResizeHandle",
        Size = UDim2.fromOffset(22, 22),
        Position = UDim2.new(1, -18, 1, -18),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 40,
        Parent = main,
    })

    local commandBackdrop = new("Frame", {
        Name = "CommandBackdrop",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 120,
        Parent = screenGui,
    })

    local commandBox = new("Frame", {
        Name = "CommandBox",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 100),
        Size = UDim2.fromOffset(520, 330),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 121,
        Parent = screenGui,
    })
    corner(commandBox, 18)
    glassify(commandBox, {
        Transparency = 0.08,
        StrokeTransparency = 0.48,
        GradientA = Color3.fromRGB(62, 75, 98),
        GradientB = Color3.fromRGB(17, 21, 30),
        GradientTransparencyA = 0.00,
        GradientTransparencyB = 0.24,
    })

    local commandInput = new("TextBox", {
        Size = UDim2.new(1, -24, 0, 42),
        Position = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Theme.ElementBackground,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = "Type a command...",
        Text = "",
        TextColor3 = Theme.TextColor,
        PlaceholderColor3 = Theme.MutedTextColor,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 122,
        Parent = commandBox,
    })
    corner(commandInput, 11)
    stroke(commandInput, Theme.ElementStroke, 1, 0.80)
    new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, commandInput)

    local commandList = new("ScrollingFrame", {
        Size = UDim2.new(1, -24, 1, -66),
        Position = UDim2.fromOffset(12, 60),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.ElementStroke,
        CanvasSize = UDim2.new(),
        ZIndex = 122,
        Parent = commandBox,
    })
    local commandLayout = new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, commandList)
    WindowMaid:Connect(commandLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        commandList.CanvasSize = UDim2.fromOffset(0, commandLayout.AbsoluteContentSize.Y + 8)
    end)

    local Window = {
        Tabs = {},
        _destroyed = false,
        _main = main,
        _shadow = shadow,
        _screenGui = screenGui,
        _maid = WindowMaid,
        _minimized = false,
        _restoredHeight = defaultSizeY,
    }
    Library.Window = Window

    ----------------------------------------------------------------
    -- Internal window state
    ----------------------------------------------------------------
    local selected = nil
    local minimized = false
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local resizing = false
    local resizeStart = nil
    local resizeStartSize = nil
    local positionSaveQueued = false

    local function setShadowForMain()
        shadow.Position = UDim2.new(
            main.Position.X.Scale,
            main.Position.X.Offset,
            main.Position.Y.Scale,
            main.Position.Y.Offset + 8
        )
        shadow.Size = UDim2.fromOffset(main.Size.X.Offset + 12, main.Size.Y.Offset + 12)
    end

    local function queueConfigSave()
        if positionSaveQueued then return end
        positionSaveQueued = true
        task.delay(0.20, function()
            positionSaveQueued = false
            if not Window._destroyed then
                saveConfiguration()
            end
        end)
    end

    local function clampWindowOffsets(nx, ny)
        local viewport = screenGui.AbsoluteSize
        local halfW = main.AbsoluteSize.X > 0 and main.AbsoluteSize.X * 0.5 or main.Size.X.Offset * 0.5
        local halfH = main.AbsoluteSize.Y > 0 and main.AbsoluteSize.Y * 0.5 or main.Size.Y.Offset * 0.5
        local limitX = math.max(0, viewport.X * 0.5 - halfW - 12)
        local limitY = math.max(0, viewport.Y * 0.5 - halfH - 12)
        return math.clamp(nx, -limitX, limitX), math.clamp(ny, -limitY, limitY)
    end

    local function setWindowPosition(position, save)
        local nx, ny = clampWindowOffsets(position.X.Offset, position.Y.Offset)
        main.Position = UDim2.new(0.5, nx, 0.5, ny)
        setShadowForMain()
        if save ~= false then queueConfigSave() end
    end

    function Window:SetPosition(x, y, save)
        if Window._destroyed then return end
        local nx = tonumber(x) or main.Position.X.Offset
        local ny = tonumber(y) or main.Position.Y.Offset
        setWindowPosition(UDim2.new(0.5, nx, 0.5, ny), save ~= false)
    end

    function Window:SetSize(width, height, save)
        if Window._destroyed then return end
        local w = math.clamp(tonumber(width) or main.Size.X.Offset, Theme.MinWidth, Theme.MaxWidth)
        local h = math.clamp(tonumber(height) or main.Size.Y.Offset, Theme.MinHeight, Theme.MaxHeight)
        main.Size = UDim2.fromOffset(w, h)
        if not Window._minimized then Window._restoredHeight = h end
        setShadowForMain()
        if save ~= false then queueConfigSave() end
    end

    function Window:SetGlassTransparency(value)
        Theme.GlassTransparency = math.clamp(tonumber(value) or Theme.GlassTransparency, 0, 0.92)
        main.BackgroundTransparency = Theme.GlassTransparency
        for _, obj in ipairs(screenGui:GetDescendants()) do
            if obj:IsA("Frame") and obj:GetAttribute("AbyssGlass") then
                obj.BackgroundTransparency = math.clamp(Theme.GlassTransparency + (obj:GetAttribute("AbyssGlassOffset") or 0), 0, 0.95)
            end
        end
    end

    local function fuzzyScore(text, query)
        text, query = tostring(text or ""):lower(), tostring(query or ""):lower()
        if query == "" then return 0 end
        local exact = text:find(query, 1, true)
        if exact then return exact == 1 and 1000 or 700 - exact end
        local qi, score = 1, 0
        for i = 1, #text do
            if text:sub(i,i) == query:sub(qi,qi) then
                score += 12
                qi += 1
                if qi > #query then return score end
            end
        end
        return -1
    end

    local function elementVisibleForSearch(record, query)
        return tostring(query or "") == "" or fuzzyScore(record.searchText, query) >= 0
    end

    local function filterSelectedTab(query)
        if not selected then return end
        local q = tostring(query or "")
        for _, element in ipairs(selected.elements) do
            if element.frame and element.frame.Parent then
                element.frame.Visible = (q == "") or elementVisibleForSearch(element, q)
            end
        end
    end

    local function attachFloatingPopup(popup, anchor, onClose)
        popup:SetAttribute("AbyssPopup", true)
        local function reposition()
            if not popup.Parent or not anchor.Parent or not popup.Visible then return end
            local ap = anchor.AbsolutePosition
            local as = anchor.AbsoluteSize
            local vp = screenGui.AbsoluteSize
            local w = popup.AbsoluteSize.X > 0 and popup.AbsoluteSize.X or popup.Size.X.Offset
            local h = popup.AbsoluteSize.Y > 0 and popup.AbsoluteSize.Y or popup.Size.Y.Offset
            local x = ap.X
            local y = ap.Y + as.Y + 8
            if x + w > vp.X - 8 then x = ap.X + as.X - w end
            if y + h > vp.Y - 8 then y = ap.Y - h - 8 end
            x = math.clamp(x, 8, math.max(8, vp.X - w - 8))
            y = math.clamp(y, 8, math.max(8, vp.Y - h - 8))
            popup.Position = UDim2.fromOffset(x, y)
        end
        WindowMaid:Connect(anchor:GetPropertyChangedSignal("AbsolutePosition"), reposition)
        WindowMaid:Connect(anchor:GetPropertyChangedSignal("AbsoluteSize"), reposition)
        WindowMaid:Connect(screenGui:GetPropertyChangedSignal("AbsoluteSize"), reposition)
        WindowMaid:Connect(UserInputService.InputBegan, function(input)
            if not popup.Visible or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            local p = input.Position
            local pp, ps = popup.AbsolutePosition, popup.AbsoluteSize
            local ap, as = anchor.AbsolutePosition, anchor.AbsoluteSize
            local inPopup = p.X >= pp.X and p.X <= pp.X + ps.X and p.Y >= pp.Y and p.Y <= pp.Y + ps.Y
            local inAnchor = p.X >= ap.X and p.X <= ap.X + as.X and p.Y >= ap.Y and p.Y <= ap.Y + as.Y
            if not inPopup and not inAnchor then
                popup.Visible = false
                if onClose then onClose() end
            end
        end)
        return reposition
    end

    local function createTabRecord(name, icon)
        local page = new("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.ElementStroke,
            Visible = false,
            CanvasSize = UDim2.new(),
            ZIndex = 22,
            Parent = pages,
        })

        local pageLayout = new("UIListLayout", {
            Padding = UDim.new(0, 7),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, page)
        new("UIPadding", {
            PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10),
        }, page)
        WindowMaid:Connect(pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            page.CanvasSize = UDim2.fromOffset(0, pageLayout.AbsoluteContentSize.Y + 18)
        end)
        WindowMaid:Connect(page:GetPropertyChangedSignal("CanvasPosition"), function()
            for _, obj in ipairs(screenGui:GetChildren()) do
                if obj:IsA("GuiObject") and obj:GetAttribute("AbyssPopup") then obj.Visible = false end
            end
        end)

        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = Theme.TabBackground,
            BackgroundTransparency = 0.32,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 24,
            Parent = tabList,
        })
        btn:SetAttribute("AbyssRole", "Tab")
        corner(btn, 11)
        stroke(btn, Theme.ElementStroke, 1, 0.88)

        local activeBar = new("Frame", {
            Size = UDim2.fromOffset(3, 22),
            Position = UDim2.fromOffset(0, 8),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 27,
            Parent = btn,
        })
        activeBar:SetAttribute("AbyssRole", "Accent")
        corner(activeBar, 2)

        local iconLabel = new("TextLabel", {
            Name = "TabIcon",
            Size = UDim2.fromOffset(28, 38),
            Position = UDim2.fromOffset(10, 0),
            BackgroundTransparency = 1,
            Text = tostring(icon or "•"),
            TextColor3 = Theme.TabTextColor,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            ZIndex = 26,
            Parent = btn,
        })

        local nameLabel = new("TextLabel", {
            Name = "TabName",
            Size = UDim2.new(1, -48, 1, 0),
            Position = UDim2.fromOffset(40, 0),
            BackgroundTransparency = 1,
            Text = tostring(name),
            TextColor3 = Theme.TabTextColor,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 26,
            Parent = btn,
        })

        local record = {
            name = tostring(name),
            icon = tostring(icon or "•"),
            page = page,
            btn = btn,
            activeBar = activeBar,
            iconLabel = iconLabel,
            nameLabel = nameLabel,
            elements = {},
        }

        table.insert(Window.Tabs, record)

        return record
    end

    local function selectTab(record)
        if not record or Window._destroyed then return end
        selected = record
        searchBox.Text = ""

        for _, rec in ipairs(Window.Tabs) do
            local isSel = (rec == record)
            rec.page.Visible = isSel
            rec.activeBar.BackgroundTransparency = isSel and 0 or 1
            rec.btn:SetAttribute("AbyssRole", isSel and "TabSelected" or "Tab")
            tween(rec.btn, 0.22, {
                BackgroundColor3 = isSel and Theme.TabBackgroundSelected or Theme.TabBackground,
                BackgroundTransparency = isSel and 0.02 or 0.32,
            })
            tween(rec.nameLabel, 0.20, {
                TextColor3 = isSel and Theme.SelectedTabTextColor or Theme.TabTextColor,
            })
            tween(rec.iconLabel, 0.20, {
                TextColor3 = isSel and Theme.SelectedTabTextColor or Theme.TabTextColor,
            })
            if isSel then
                for _, element in ipairs(rec.elements) do
                    if element.frame then element.frame.Visible = true end
                end
            end
        end
    end

    function Window:CreateTab(tabNameOrOptions)
        local name, icon
        if type(tabNameOrOptions) == "table" then
            name = tabNameOrOptions.Name or tabNameOrOptions.Title or "Tab"
            icon = tabNameOrOptions.Icon or ">"
        else
            name = tostring(tabNameOrOptions or "Tab")
            icon = ">"
        end

        local record = createTabRecord(name, icon)

        WindowMaid:Connect(record.btn.MouseButton1Click, function()
            selectTab(record)
        end)
        WindowMaid:Connect(record.btn.MouseEnter, function()
            if selected ~= record then
                tween(record.btn, 0.14, { BackgroundTransparency = 0.13 })
            end
        end)
        WindowMaid:Connect(record.btn.MouseLeave, function()
            if selected ~= record then
                tween(record.btn, 0.16, { BackgroundTransparency = 0.32 })
            end
        end)

        local Tab = {}
        local order = 0

        local function nextOrder()
            order += 1
            return order
        end

        local function registerElement(frame, searchText)
            local recordElement = {
                frame = frame,
                searchText = tostring(searchText or ""),
            }
            table.insert(record.elements, recordElement)
            return recordElement
        end

        local function elementFrame(height, searchText)
            local frame = new("Frame", {
                Size = UDim2.new(1, 0, 0, height),
                BackgroundColor3 = Theme.ElementBackground,
                BackgroundTransparency = Theme.ElementTransparency,
                BorderSizePixel = 0,
                LayoutOrder = nextOrder(),
                ZIndex = 24,
                Parent = record.page,
            })
            frame:SetAttribute("AbyssRole", "Surface")
            corner(frame, 11)
            glassify(frame, {
                Transparency = Theme.ElementTransparency,
                StrokeTransparency = 0.84,
                GradientA = Color3.fromRGB(56, 68, 89),
                GradientB = Color3.fromRGB(30, 37, 49),
                GradientTransparencyA = 0.05,
                GradientTransparencyB = 0.34,
            })
            local item = registerElement(frame, searchText)
            return frame, item
        end

        local function elementTitle(parent, text)
            return new("TextLabel", {
                Size = UDim2.new(0.62, -12, 1, 0),
                Position = UDim2.fromOffset(11, 0),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = Theme.TextColor,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                ZIndex = 27,
                Parent = parent,
            })
        end

        local function hoverize(frame)
            WindowMaid:Connect(frame.MouseEnter, function()
                tween(frame, 0.15, { BackgroundTransparency = Theme.HoverTransparency })
            end)
            WindowMaid:Connect(frame.MouseLeave, function()
                tween(frame, 0.18, { BackgroundTransparency = Theme.ElementTransparency })
            end)
        end

        local function addPressEffect(button)
            local scale = new("UIScale", { Scale = 1 }, button)
            WindowMaid:Connect(button.MouseButton1Down, function()
                tween(scale, 0.08, { Scale = 0.97 })
            end)
            WindowMaid:Connect(button.MouseButton1Up, function()
                tween(scale, 0.12, { Scale = 1 })
            end)
        end

        local function addClick(frame, callback)
            local overlay = new("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 28,
                Parent = frame,
            })
            addPressEffect(overlay)
            WindowMaid:Connect(overlay.MouseButton1Click, callback)
            return overlay
        end

        local function registerFlag(flag, name, getFn, applyFn)
            local key = flag or name
            if not key or key == "" then return end
            key = tostring(key)
            if Library.Flags[key] then
                local base = key
                local i = 2
                repeat
                    key = base .. "_" .. tostring(i)
                    i += 1
                until not Library.Flags[key]
                warn("[AbyssUI] Duplicate Flag detected; using '" .. key .. "'")
            end
            Library.Flags[key] = { Get = getFn, Apply = applyFn }
        end

        ------------------------------------------------------------
        function Tab:CreateSection(text)
            local label = new("TextLabel", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = Theme.SectionTextColor,
                Font = Enum.Font.GothamSemibold,
                TextSize = 12,
                LayoutOrder = nextOrder(),
                ZIndex = 26,
                Parent = record.page,
            })
            table.insert(record.elements, { frame = label, searchText = tostring(text) })
            return {
                Set = function(_, value)
                    label.Text = tostring(value or "")
                end,
            }
        end

        function Tab:CreateDivider()
            local divider = new("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Theme.ElementStroke,
                BackgroundTransparency = 0.18,
                BorderSizePixel = 0,
                LayoutOrder = nextOrder(),
                ZIndex = 25,
                Parent = record.page,
            })
            table.insert(record.elements, { frame = divider, searchText = "divider" })
            return {
                Set = function(_, visible)
                    divider.Visible = visible ~= false
                end,
            }
        end

        function Tab:CreateLabel(text)
            local frame = elementFrame(30, text)
            local label = elementTitle(frame, text)
            label.Size = UDim2.new(1, -22, 1, 0)
            hoverize(frame)
            return {
                Set = function(_, value)
                    label.Text = tostring(value or "")
                end,
            }
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
                ZIndex = 24,
                Parent = record.page,
            })
            frame:SetAttribute("AbyssRole", "Surface")
            corner(frame, 11)
            glassify(frame, {
                Transparency = Theme.ElementTransparency,
                StrokeTransparency = 0.84,
                GradientA = Color3.fromRGB(56, 68, 89),
                GradientB = Color3.fromRGB(30, 37, 49),
                GradientTransparencyA = 0.05,
                GradientTransparencyB = 0.34,
            })
            registerElement(frame, (opts.Title or "") .. " " .. (opts.Content or ""))
            new("UIPadding", {
                PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
                PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
            }, frame)
            new("UIListLayout", { Padding = UDim.new(0, 5) }, frame)
            local title = new("TextLabel", {
                BackgroundTransparency = 1,
                Text = tostring(opts.Title or ""),
                TextColor3 = Theme.TextColor,
                Font = Enum.Font.GothamSemibold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(1, 0, 0, 18),
                ZIndex = 27,
                Parent = frame,
            })
            local content = new("TextLabel", {
                BackgroundTransparency = 1,
                Text = tostring(opts.Content or ""),
                TextColor3 = Theme.SectionTextColor,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 27,
                Parent = frame,
            })
            return {
                Set = function(_, value)
                    value = value or {}
                    title.Text = tostring(value.Title or title.Text)
                    content.Text = tostring(value.Content or content.Text)
                end,
            }
        end

        function Tab:CreateButton(opts)
            opts = opts or {}
            local frame = elementFrame(34, opts.Name)
            hoverize(frame)
            local label = elementTitle(frame, opts.Name or "Button")
            label.Size = UDim2.new(1, -22, 1, 0)
            addClick(frame, function()
                safeCall("Button:" .. tostring(opts.Name or "Button"), opts.Callback)
                saveConfiguration()
            end)
            return {
                Set = function(_, value)
                    label.Text = tostring(value or "")
                end,
            }
        end

        function Tab:CreateToggle(opts)
            opts = opts or {}
            local state = opts.CurrentValue == true
            local frame = elementFrame(34, opts.Name)
            hoverize(frame)
            elementTitle(frame, opts.Name or "Toggle")

            local switch = new("Frame", {
                Size = UDim2.fromOffset(42, 20),
                Position = UDim2.new(1, -56, 0.5, -10),
                BackgroundColor3 = Theme.Background,
                BackgroundTransparency = 0.18,
                BorderSizePixel = 0,
                ZIndex = 27,
                Parent = frame,
            })
            corner(switch, 10)
            local switchStroke = stroke(switch, Theme.ElementStroke, 1, 0.55)

            local indicator = new("Frame", {
                Size = UDim2.fromOffset(14, 14),
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 3, 0.5, 0),
                BackgroundColor3 = Theme.ToggleDisabled,
                BorderSizePixel = 0,
                ZIndex = 28,
                Parent = switch,
            })
            corner(indicator, 7)

            local object = { CurrentValue = state, Flag = opts.Flag }

            local function apply(value, fire)
                state = value == true
                object.CurrentValue = state
                if state then
                    tween(indicator, 0.18, {
                        Position = UDim2.new(1, -17, 0.5, 0),
                        BackgroundColor3 = Theme.ToggleEnabled,
                    })
                    tween(switchStroke, 0.18, { Color = Theme.Accent, Transparency = 0.20 })
                else
                    tween(indicator, 0.18, {
                        Position = UDim2.new(0, 3, 0.5, 0),
                        BackgroundColor3 = Theme.ToggleDisabled,
                    })
                    tween(switchStroke, 0.18, { Color = Theme.ElementStroke, Transparency = 0.55 })
                end
                if fire then safeCall("Toggle:" .. tostring(opts.Name or "Toggle"), opts.Callback, state) end
            end

            addClick(frame, function()
                apply(not state, true)
                saveConfiguration()
            end)

            function object:Set(value)
                apply(value, true)
                saveConfiguration()
            end

            registerFlag(opts.Flag, opts.Name,
                function() return object.CurrentValue end,
                function(value) apply(value, true) end)
            apply(state, false)
            return object
        end

        function Tab:CreateSlider(opts)
            opts = opts or {}
            local min = tonumber(opts.Range and opts.Range[1]) or 0
            local max = tonumber(opts.Range and opts.Range[2]) or 100
            if min > max then min, max = max, min end
            local increment = tonumber(opts.Increment)
            if not increment or increment <= 0 then increment = 1 end
            local value = clampNumber(opts.CurrentValue, min, max)

            local frame = elementFrame(48, opts.Name)
            hoverize(frame)
            elementTitle(frame, opts.Name or "Slider")

            local info = new("TextLabel", {
                Size = UDim2.fromOffset(110, 16),
                Position = UDim2.new(1, -120, 0, 6),
                BackgroundTransparency = 1,
                TextColor3 = Theme.TextColor,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 27,
                Parent = frame,
            })

            local track = new("Frame", {
                Size = UDim2.new(1, -20, 0, 7),
                Position = UDim2.fromOffset(10, 31),
                BackgroundColor3 = Theme.SliderBackground,
                BackgroundTransparency = 0.15,
                BorderSizePixel = 0,
                ZIndex = 27,
                Parent = frame,
            })
            corner(track, 4)
            local progress = new("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = Theme.SliderProgress,
                BorderSizePixel = 0,
                ZIndex = 28,
                Parent = track,
            })
            corner(progress, 4)
            local knob = new("Frame", {
                Size = UDim2.fromOffset(14, 14),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                BackgroundColor3 = Color3.fromRGB(246, 250, 255),
                BorderSizePixel = 0,
                ZIndex = 29,
                Parent = track,
            })
            corner(knob, 7)
            stroke(knob, Theme.Accent, 1, 0.45)

            local object = { CurrentValue = value, Flag = opts.Flag }
            local draggingSlider = false
            local lastCallbackValue = nil

            local function snap(raw)
                raw = math.clamp(raw, min, max)
                local snapped = min + math.floor(((raw - min) / increment) + 0.5) * increment
                return math.clamp(snapped, min, max)
            end

            local function apply(newValue, fire, animate)
                newValue = snap(tonumber(newValue) or min)
                newValue = math.floor(newValue * 1000000 + 0.5) / 1000000
                value = newValue
                object.CurrentValue = value

                local ratio = (max > min) and ((value - min) / (max - min)) or 0
                local size = UDim2.new(ratio, 0, 1, 0)
                local pos = UDim2.new(ratio, 0, 0.5, 0)
                if animate then
                    tween(progress, 0.12, { Size = size })
                    tween(knob, 0.12, { Position = pos })
                else
                    progress.Size = size
                    knob.Position = pos
                end

                info.Text = formatNumber(value) .. (opts.Suffix and (" " .. tostring(opts.Suffix)) or "")

                if fire and lastCallbackValue ~= value then
                    lastCallbackValue = value
                    safeCall("Slider:" .. tostring(opts.Name or "Slider"), opts.Callback, value)
                end
            end

            local function fromX(x)
                local width = math.max(track.AbsoluteSize.X, 1)
                local ratio = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
                apply(min + (max - min) * ratio, true, not draggingSlider)
            end

            WindowMaid:Connect(track.InputBegan, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingSlider = true
                    fromX(input.Position.X)
                end
            end)
            WindowMaid:Connect(UserInputService.InputChanged, function(input)
                if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
                    fromX(input.Position.X)
                end
            end)
            WindowMaid:Connect(UserInputService.InputEnded, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    if draggingSlider then saveConfiguration() end
                    draggingSlider = false
                end
            end)

            function object:Set(v)
                apply(v, true, true)
                saveConfiguration()
            end

            registerFlag(opts.Flag, opts.Name,
                function() return object.CurrentValue end,
                function(v) apply(v, true, false) end)

            apply(value, false, false)
            lastCallbackValue = object.CurrentValue
            return object
        end

        function Tab:CreateDropdown(opts)
            opts = opts or {}
            local options = opts.Options or {}
            local current = {}
            if type(opts.CurrentOption) == "string" then
                current = { opts.CurrentOption }
            elseif type(opts.CurrentOption) == "table" then
                current = { opts.CurrentOption[1] }
            end

            local frame = elementFrame(36, opts.Name)
            hoverize(frame)
            elementTitle(frame, opts.Name or "Dropdown")

            local selectedLabel = new("TextLabel", {
                Size = UDim2.new(0.36, -28, 1, 0),
                Position = UDim2.new(0.64, -18, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(current[1] or "None"),
                TextColor3 = Theme.MutedTextColor,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 27,
                Parent = frame,
            })

            local arrow = new("TextLabel", {
                Size = UDim2.fromOffset(18, 36),
                Position = UDim2.new(1, -24, 0, 0),
                BackgroundTransparency = 1,
                Text = "v",
                TextColor3 = Theme.MutedTextColor,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                ZIndex = 27,
                Parent = frame,
            })

            local list = new("ScrollingFrame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundColor3 = Theme.ElementBackground,
                BackgroundTransparency = 0.12,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Visible = false,
                LayoutOrder = nextOrder(),
                ZIndex = 80,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Theme.ElementStroke,
                CanvasSize = UDim2.new(),
                Parent = screenGui,
            })
            corner(list, 12)
            glassify(list, {
                Transparency = 0.12,
                StrokeTransparency = 0.72,
                GradientA = Color3.fromRGB(60, 72, 92),
                GradientB = Color3.fromRGB(25, 31, 41),
                GradientTransparencyA = 0.04,
                GradientTransparencyB = 0.22,
            })
            local listLayout = new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, list)
            new("UIPadding", {
                PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7),
                PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7),
            }, list)
            WindowMaid:Connect(listLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
                list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 14)
            end)

            local object = { CurrentOption = current, Options = options, Flag = opts.Flag }
            local open = false
            local setOpen
            local repositionPopup = attachFloatingPopup(list, frame, function()
                open = false
                arrow.Text = "v"
            end)
            local optionMaid = createMaid()
            WindowMaid:Give(function() optionMaid:Cleanup() end)

            local function rebuild()
                optionMaid:Cleanup()
                for _, child in ipairs(list:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                for _, opt in ipairs(options) do
                    local b = new("TextButton", {
                        Size = UDim2.new(1, 0, 0, 28),
                        BackgroundColor3 = Theme.TabBackground,
                        BackgroundTransparency = 0.22,
                        BorderSizePixel = 0,
                        Text = "  " .. tostring(opt),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextColor3 = table.find(current, opt) and Theme.SelectedTabTextColor or Theme.TabTextColor,
                        Font = Enum.Font.Gotham,
                        TextSize = 12,
                        AutoButtonColor = false,
                        ZIndex = 82,
                        Parent = list,
                    })
                    corner(b, 8)
                    addPressEffect(b)
                    optionMaid:Connect(b.MouseEnter, function()
                        tween(b, 0.12, { BackgroundTransparency = 0.06 })
                    end)
                    optionMaid:Connect(b.MouseLeave, function()
                        tween(b, 0.14, { BackgroundTransparency = 0.22 })
                    end)
                    optionMaid:Connect(b.MouseButton1Click, function()
                        current = { opt }
                        object.CurrentOption = current
                        selectedLabel.Text = tostring(opt)
                        safeCall("Dropdown:" .. tostring(opts.Name or "Dropdown"), opts.Callback, current)
                        rebuild()
                        setOpen(false)
                        saveConfiguration()
                    end)
                end
            end

            setOpen = function(state)
                open = state == true
                arrow.Text = open and "^" or "v"
                list.Visible = true
                local contentHeight = math.clamp(listLayout.AbsoluteContentSize.Y + 4, 28, 190)
                tween(list, 0.20, { Size = UDim2.new(1, 0, 0, open and contentHeight or 0) })
                if open then task.defer(repositionPopup) end
                if not open then
                    task.delay(0.22, function()
                        if not open and list.Parent then list.Visible = false end
                    end)
                end
            end

            addClick(frame, function() setOpen(not open) end)

            function object:Set(option)
                if type(option) == "string" then option = { option } end
                current = { option and option[1] }
                object.CurrentOption = current
                selectedLabel.Text = tostring(current[1] or "None")
                safeCall("Dropdown:Set:" .. tostring(opts.Name or "Dropdown"), opts.Callback, current)
                rebuild()
                saveConfiguration()
            end

            function object:Refresh(newOptions)
                options = newOptions or {}
                object.Options = options
                rebuild()
                if open then setOpen(true) end
            end

            registerFlag(opts.Flag, opts.Name,
                function() return object.CurrentOption end,
                function(v) object:Set(v) end)

            rebuild()
            return object
        end

        function Tab:CreateMultiDropdown(opts)
            opts = opts or {}
            local options = opts.Options or {}
            local selectedValues = {}
            for _, value in ipairs(opts.CurrentOptions or {}) do
                selectedValues[value] = true
            end

            local frame = elementFrame(36, opts.Name)
            hoverize(frame)
            elementTitle(frame, opts.Name or "Multi Dropdown")

            local selectedLabel = new("TextLabel", {
                Size = UDim2.new(0.42, -26, 1, 0),
                Position = UDim2.new(0.58, -18, 0, 0),
                BackgroundTransparency = 1,
                Text = "0 selected",
                TextColor3 = Theme.MutedTextColor,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 27,
                Parent = frame,
            })

            local arrow = new("TextLabel", {
                Size = UDim2.fromOffset(18, 36),
                Position = UDim2.new(1, -24, 0, 0),
                BackgroundTransparency = 1,
                Text = "v",
                TextColor3 = Theme.MutedTextColor,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                ZIndex = 27,
                Parent = frame,
            })

            local list = new("ScrollingFrame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundColor3 = Theme.ElementBackground,
                BackgroundTransparency = 0.12,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Visible = false,
                LayoutOrder = nextOrder(),
                ZIndex = 80,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Theme.ElementStroke,
                CanvasSize = UDim2.new(),
                Parent = screenGui,
            })
            corner(list, 12)
            glassify(list, { Transparency = 0.12, StrokeTransparency = 0.72 })
            local listLayout = new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, list)
            new("UIPadding", {
                PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7),
                PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7),
            }, list)
            WindowMaid:Connect(listLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
                list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 14)
            end)

            local object = { CurrentOptions = {}, Options = options, Flag = opts.Flag }
            local open = false
            local setOpen
            local repositionPopup = attachFloatingPopup(list, frame, function()
                open = false
                arrow.Text = "v"
            end)
            local optionMaid = createMaid()
            WindowMaid:Give(function() optionMaid:Cleanup() end)

            local function collect()
                local result = {}
                for _, value in ipairs(options) do
                    if selectedValues[value] then result[#result + 1] = value end
                end
                object.CurrentOptions = result
                selectedLabel.Text = tostring(#result) .. " selected"
                return result
            end

            local function rebuild()
                optionMaid:Cleanup()
                for _, child in ipairs(list:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                for _, opt in ipairs(options) do
                    local checked = selectedValues[opt] == true
                    local b = new("TextButton", {
                        Size = UDim2.new(1, 0, 0, 30),
                        BackgroundColor3 = checked and Theme.TabBackgroundSelected or Theme.TabBackground,
                        BackgroundTransparency = checked and 0.03 or 0.22,
                        BorderSizePixel = 0,
                        Text = (checked and "+  " or "    ") .. tostring(opt),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextColor3 = checked and Theme.SelectedTabTextColor or Theme.TabTextColor,
                        Font = Enum.Font.Gotham,
                        TextSize = 12,
                        AutoButtonColor = false,
                        ZIndex = 82,
                        Parent = list,
                    })
                    corner(b, 8)
                    addPressEffect(b)
                    optionMaid:Connect(b.MouseButton1Click, function()
                        selectedValues[opt] = not selectedValues[opt]
                        local result = collect()
                        safeCall("MultiDropdown:" .. tostring(opts.Name or "MultiDropdown"), opts.Callback, result)
                        rebuild()
                        saveConfiguration()
                    end)
                end
            end

            setOpen = function(state)
                open = state == true
                arrow.Text = open and "^" or "v"
                list.Visible = true
                local contentHeight = math.clamp(listLayout.AbsoluteContentSize.Y + 4, 28, 210)
                tween(list, 0.20, { Size = UDim2.new(1, 0, 0, open and contentHeight or 0) })
                if open then task.defer(repositionPopup) end
                if not open then
                    task.delay(0.22, function()
                        if not open and list.Parent then list.Visible = false end
                    end)
                end
            end

            addClick(frame, function() setOpen(not open) end)

            function object:Set(values)
                selectedValues = {}
                if type(values) == "table" then
                    for _, value in ipairs(values) do selectedValues[value] = true end
                end
                local result = collect()
                rebuild()
                safeCall("MultiDropdown:Set:" .. tostring(opts.Name or "MultiDropdown"), opts.Callback, result)
                saveConfiguration()
            end

            function object:Refresh(newOptions)
                options = newOptions or {}
                object.Options = options
                rebuild()
                collect()
                if open then setOpen(true) end
            end

            collect()
            rebuild()
            registerFlag(opts.Flag, opts.Name,
                function() return object.CurrentOptions end,
                function(v) object:Set(v) end)
            return object
        end

        function Tab:CreateKeybind(opts)
            opts = opts or {}
            local _, normalized = resolveKey(opts.CurrentKeybind or Enum.KeyCode.RightShift)
            local object = { CurrentKeybind = normalized, Flag = opts.Flag }

            local frame = elementFrame(34, opts.Name)
            hoverize(frame)
            elementTitle(frame, opts.Name or "Keybind")

            local button = new("TextButton", {
                Size = UDim2.fromOffset(84, 22),
                Position = UDim2.new(1, -96, 0.5, -11),
                BackgroundColor3 = Theme.TabBackground,
                BackgroundTransparency = 0.20,
                BorderSizePixel = 0,
                Text = normalized or "None",
                TextColor3 = Theme.TextColor,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                AutoButtonColor = false,
                ZIndex = 29,
                Parent = frame,
            })
            corner(button, 7)
            stroke(button, Theme.ElementStroke, 1, 0.78)
            addPressEffect(button)

            local capturing = false
            WindowMaid:Connect(UserInputService.InputBegan, function(input, processed)
                if capturing then
                    if input.KeyCode == Enum.KeyCode.Escape then
                        capturing = false
                        button.Text = object.CurrentKeybind or "None"
                        return
                    end
                    if input.KeyCode ~= Enum.KeyCode.Unknown then
                        local name = input.KeyCode.Name
                        object.CurrentKeybind = name
                        button.Text = name
                        capturing = false
                        safeCall("KeybindSet:" .. tostring(opts.Name or "Keybind"), opts.Callback, name)
                        saveConfiguration()
                    end
                    return
                end

                if not processed and object.CurrentKeybind then
                    local key = Enum.KeyCode[object.CurrentKeybind]
                    if key and input.KeyCode == key then
                        safeCall("Keybind:" .. tostring(opts.Name or "Keybind"), opts.Callback, object.CurrentKeybind)
                    end
                end
            end)

            WindowMaid:Connect(button.MouseButton1Click, function()
                capturing = true
                button.Text = "press key"
            end)

            function object:Set(key)
                local _, name = resolveKey(key)
                object.CurrentKeybind = name
                button.Text = name
                safeCall("Keybind:Set:" .. tostring(opts.Name or "Keybind"), opts.Callback, name)
                saveConfiguration()
            end

            registerFlag(opts.Flag, opts.Name,
                function() return object.CurrentKeybind end,
                function(v) object:Set(v) end)
            return object
        end

        function Tab:CreateInput(opts)
            opts = opts or {}
            local frame = elementFrame(36, opts.Name)
            hoverize(frame)
            elementTitle(frame, opts.Name or "Input")

            local box = new("TextBox", {
                Size = UDim2.fromOffset(160, 22),
                Position = UDim2.new(1, -172, 0.5, -11),
                BackgroundColor3 = Theme.TabBackground,
                BackgroundTransparency = 0.20,
                BorderSizePixel = 0,
                PlaceholderText = tostring(opts.PlaceholderText or ""),
                Text = tostring(opts.CurrentValue or ""),
                TextColor3 = Theme.TextColor,
                PlaceholderColor3 = Theme.MutedTextColor,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                ZIndex = 29,
                Parent = frame,
            })
            corner(box, 7)
            stroke(box, Theme.ElementStroke, 1, 0.78)
            new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, box)

            local object = { CurrentValue = box.Text, Flag = opts.Flag }

            WindowMaid:Connect(box.FocusLost, function()
                object.CurrentValue = box.Text
                safeCall("Input:" .. tostring(opts.Name or "Input"), opts.Callback, box.Text)
                saveConfiguration()
            end)

            function object:Set(text)
                local value = tostring(text or "")
                box.Text = value
                object.CurrentValue = value
                safeCall("Input:Set:" .. tostring(opts.Name or "Input"), opts.Callback, value)
                saveConfiguration()
            end

            registerFlag(opts.Flag, opts.Name,
                function() return object.CurrentValue end,
                function(v) object:Set(v) end)
            return object
        end

        function Tab:CreateColorPicker(opts)
            opts = opts or {}
            local initial = opts.Color or Color3.fromRGB(120, 180, 255)
            local h, s, v = Color3.toHSV(initial)
            local object = { Color = initial, Flag = opts.Flag }

            local frame = elementFrame(36, opts.Name)
            hoverize(frame)
            elementTitle(frame, opts.Name or "Color")

            local swatch = new("TextButton", {
                Size = UDim2.fromOffset(62, 22),
                Position = UDim2.new(1, -74, 0.5, -11),
                BackgroundColor3 = initial,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 29,
                Parent = frame,
            })
            corner(swatch, 8)
            stroke(swatch, Color3.fromRGB(255,255,255), 1, 0.50)
            addPressEffect(swatch)

            local popup = new("Frame", {
                Size = UDim2.fromOffset(230, 238),
                BackgroundColor3 = Theme.Background,
                BackgroundTransparency = 0.06,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 1000,
            }, screenGui)

            local function positionPopup()
                if not popup.Parent or not swatch.Parent then return end
                local sp = swatch.AbsolutePosition
                local ss = swatch.AbsoluteSize
                local vp = screenGui.AbsoluteSize
                local x = sp.X + ss.X - popup.AbsoluteSize.X
                local y = sp.Y + ss.Y + 8
                if y + popup.AbsoluteSize.Y > vp.Y - 8 then y = sp.Y - popup.AbsoluteSize.Y - 8 end
                x = math.clamp(x, 8, math.max(8, vp.X - popup.AbsoluteSize.X - 8))
                y = math.clamp(y, 8, math.max(8, vp.Y - popup.AbsoluteSize.Y - 8))
                popup.Position = UDim2.fromOffset(x, y)
            end
            corner(popup, 14)
            glassify(popup, { Transparency = 0.06, StrokeTransparency = 0.50 })
            WindowMaid:Connect(swatch:GetPropertyChangedSignal("AbsolutePosition"), positionPopup)
            WindowMaid:Connect(main:GetPropertyChangedSignal("AbsolutePosition"), positionPopup)
            WindowMaid:Connect(main:GetPropertyChangedSignal("AbsoluteSize"), positionPopup)

            local sv = new("Frame", {
                Size = UDim2.fromOffset(190, 170),
                Position = UDim2.fromOffset(12, 12),
                BackgroundColor3 = Color3.fromHSV(h, 1, 1),
                BorderSizePixel = 0,
                ZIndex = 121,
                Parent = popup,
            })
            corner(sv, 10)
            local svWhite = new("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                ZIndex = 122,
                Parent = sv,
            })
            corner(svWhite, 10)
            gradient(svWhite, 0, Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255), 0, 1)
            local svBlack = new("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 123,
                Parent = sv,
            })
            corner(svBlack, 10)
            local blackGradient = new("UIGradient", {
                Rotation = 90,
                Color = ColorSequence.new(Color3.new(0,0,0), Color3.new(0,0,0)),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0),
                }),
            }, svBlack)

            local svCursor = new("Frame", {
                Size = UDim2.fromOffset(10,10),
                AnchorPoint = Vector2.new(0.5,0.5),
                BackgroundColor3 = Color3.new(1,1,1),
                BorderSizePixel = 0,
                ZIndex = 125,
                Parent = sv,
            })
            corner(svCursor, 5)
            stroke(svCursor, Color3.new(0,0,0), 1, 0.15)

            local hue = new("Frame", {
                Size = UDim2.fromOffset(14, 170),
                Position = UDim2.fromOffset(204, 12),
                BorderSizePixel = 0,
                ZIndex = 121,
                Parent = popup,
            })
            corner(hue, 7)
            new("UIGradient", {
                Rotation = 90,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,0,0)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,0,255)),
                    ColorSequenceKeypoint.new(0.34, Color3.fromRGB(0,0,255)),
                    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0,255,255)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,255,0)),
                    ColorSequenceKeypoint.new(0.84, Color3.fromRGB(255,255,0)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,0,0)),
                }),
            }, hue)
            local hueCursor = new("Frame", {
                Size = UDim2.new(1, 4, 0, 4),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1,1,1),
                BorderSizePixel = 0,
                ZIndex = 125,
                Parent = hue,
            })
            corner(hueCursor, 2)

            local function applyColor(fire)
                object.Color = Color3.fromHSV(h, s, v)
                swatch.BackgroundColor3 = object.Color
                sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
                hueCursor.Position = UDim2.new(0.5, 0, h, 0)
                if fire then
                    safeCall("ColorPicker:" .. tostring(opts.Name or "ColorPicker"), opts.Callback, object.Color)
                    saveConfiguration()
                end
            end

            local function updateSV(x, y)
                local sx = math.clamp((x - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
                local sy = math.clamp((y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
                s = sx
                v = 1 - sy
                applyColor(true)
            end

            local function updateHue(y)
                h = math.clamp((y - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 1)
                applyColor(true)
            end

            local dragSV = false
            local dragHue = false
            local function beginSV(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragSV = true
                    updateSV(input.Position.X, input.Position.Y)
                end
            end
            WindowMaid:Connect(sv.InputBegan, beginSV)
            WindowMaid:Connect(svCursor.InputBegan, beginSV)
            local function beginHue(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragHue = true
                    updateHue(input.Position.Y)
                end
            end
            WindowMaid:Connect(hue.InputBegan, beginHue)
            WindowMaid:Connect(hueCursor.InputBegan, beginHue)
            WindowMaid:Connect(UserInputService.InputChanged, function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                if dragSV then updateSV(input.Position.X, input.Position.Y) end
                if dragHue then updateHue(input.Position.Y) end
            end)
            WindowMaid:Connect(UserInputService.InputEnded, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragSV = false
                    dragHue = false
                end
            end)

            WindowMaid:Connect(swatch.MouseButton1Click, function()
                popup.Visible = not popup.Visible
                if popup.Visible then positionPopup() end
            end)
            WindowMaid:Connect(UserInputService.InputBegan, function(input)
                if not popup.Visible or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                local p = input.Position
                local pos = popup.AbsolutePosition
                local size = popup.AbsoluteSize
                if p.X < pos.X or p.X > pos.X + size.X or p.Y < pos.Y or p.Y > pos.Y + size.Y then
                    popup.Visible = false
                end
            end)

            function object:Set(color)
                if typeof(color) ~= "Color3" then return end
                h, s, v = Color3.toHSV(color)
                applyColor(true)
            end

            registerFlag(opts.Flag, opts.Name,
                function()
                    return { R = object.Color.R, G = object.Color.G, B = object.Color.B }
                end,
                function(v2)
                    if type(v2) == "table" and tonumber(v2.R) and tonumber(v2.G) and tonumber(v2.B) then
                        object:Set(Color3.new(
                            math.clamp(tonumber(v2.R), 0, 1),
                            math.clamp(tonumber(v2.G), 0, 1),
                            math.clamp(tonumber(v2.B), 0, 1)
                        ))
                    elseif typeof(v2) == "Color3" then
                        object:Set(v2)
                    end
                end)

            applyColor(false)
            return object
        end

        if #Window.Tabs == 1 then
            selectTab(record)
        end

        return Tab
    end

    ----------------------------------------------------------------
    -- Search + command center
    ----------------------------------------------------------------
    WindowMaid:Connect(searchBox:GetPropertyChangedSignal("Text"), function()
        filterSelectedTab(searchBox.Text)
    end)

    local commandMaid = createMaid()
    WindowMaid:Give(function() commandMaid:Cleanup() end)
    local commandButtons = {}
    local commandIndex = 1

    local function commandEntries()
        local entries = {
            { Name = "Show window", Hint = "UI", Shortcut = "", Action = function() Window:Show() end },
            { Name = "Hide window", Hint = "UI", Action = function() Window:Hide() end },
            { Name = minimized and "Restore window" or "Minimize window", Hint = "UI", Action = function() Window:SetMinimized(not minimized) end },
            { Name = "Save profile", Hint = "Profile", Shortcut = "", Action = saveConfiguration },
            { Name = "Export profile JSON", Hint = "Profile", Action = function() return Library:ExportProfile() end },
            { Name = "Focus search", Hint = "Navigation", Shortcut = "Ctrl+K", Action = function() searchBox:CaptureFocus() end },
            { Name = "High contrast", Hint = "Accessibility", Action = function() UIState.HighContrast = not UIState.HighContrast; emitThemeChanged() end },
            { Name = "Reduced motion", Hint = "Accessibility", Action = function() UIState.ReducedMotion = not UIState.ReducedMotion; emitThemeChanged() end },
        }
        for _, tab in ipairs(Window.Tabs) do
            table.insert(entries, { Name = "Open " .. tab.name, Hint = "Tab", Action = function() selectTab(tab) end })
            for _, element in ipairs(tab.elements) do
                if element.commandName and element.commandAction then
                    table.insert(entries, { Name = element.commandName, Hint = tab.name, Action = element.commandAction })
                end
            end
        end
        return entries
    end

    local function setCommandSelection(index)
        commandIndex = math.clamp(index, 1, math.max(1, #commandButtons))
        for i, data in ipairs(commandButtons) do
            local active = i == commandIndex
            tween(data.button, 0.10, { BackgroundTransparency = active and 0.04 or 0.20 })
        end
    end

    local function runSelectedCommand()
        local entry = commandButtons[commandIndex]
        if not entry then return end
        safeCall("Command:" .. tostring(entry.data.Name), entry.data.Action)
        commandBackdrop.Visible = false
        commandBox.Visible = false
    end

    local function refreshCommandList(query)
        commandMaid:Cleanup()
        table.clear(commandButtons)
        for _, child in ipairs(commandList:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        local ranked = {}
        for _, entry in ipairs(commandEntries()) do
            local score = fuzzyScore(entry.Name .. " " .. (entry.Hint or ""), query)
            if tostring(query or "") == "" then score = 0 end
            if score >= 0 then
                ranked[#ranked + 1] = { data = entry, score = score }
            end
        end
        table.sort(ranked, function(a,b) return a.score > b.score end)
        if #ranked == 0 then
            local empty = new("TextLabel", { Size = UDim2.new(1,0,0,44), BackgroundTransparency = 1, Text = "No commands found", TextColor3 = Theme.MutedTextColor, Font = Enum.Font.Gotham, TextSize = 12, ZIndex = 123, Parent = commandList })
            table.insert(commandButtons, { button = empty, data = {Name="No commands", Action=function() end} })
            commandIndex = 1
            return
        end
        for i, rankedEntry in ipairs(ranked) do
            local entry = rankedEntry.data
            local button = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = Theme.TabBackground,
                BackgroundTransparency = 0.20, BorderSizePixel = 0,
                Text = "   " .. entry.Name .. ((entry.Hint and entry.Hint ~= "") and ("   ·   " .. entry.Hint) or ""),
                TextColor3 = Theme.TextColor, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, ZIndex = 123, Parent = commandList,
            })
            corner(button, 9)
            commandButtons[#commandButtons+1] = { button = button, data = entry }
            commandMaid:Connect(button.MouseEnter, function()
                for j, row in ipairs(commandButtons) do if row.button then tween(row.button, 0.08, { BackgroundTransparency = j == i and 0.04 or 0.20 }) end end
                commandIndex = i
            end)
            commandMaid:Connect(button.MouseButton1Click, runSelectedCommand)
        end
        setCommandSelection(1)
    end

    local function setCommandPalette(state)
        state = state == true
        if not state then
            tween(commandBackdrop, 0.12, { BackgroundTransparency = 1 })
            tween(commandBox, 0.14, { Position = UDim2.new(0.5, 0, 0, 82) })
            task.delay(motionDuration(0.14), function()
                if commandBackdrop.Parent then commandBackdrop.Visible = false; commandBox.Visible = false end
            end)
            return
        end
        commandBackdrop.Visible = true
        commandBox.Visible = true
        commandInput.Text = ""
        refreshCommandList("")
        tween(commandBackdrop, 0.12, { BackgroundTransparency = 0.78 })
        tween(commandBox, 0.16, { Position = UDim2.new(0.5, 0, 0, 92) })
        task.defer(function() commandInput:CaptureFocus() end)
    end

    WindowMaid:Connect(commandInput:GetPropertyChangedSignal("Text"), function() refreshCommandList(commandInput.Text) end)
    WindowMaid:Connect(commandBackdrop.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then setCommandPalette(false) end
    end)
    WindowMaid:Connect(commandInput.InputBegan, function(input)
        if input.KeyCode == Enum.KeyCode.Escape then
            setCommandPalette(false)
        elseif input.KeyCode == Enum.KeyCode.Down then
            setCommandSelection(commandIndex + 1)
        elseif input.KeyCode == Enum.KeyCode.Up then
            setCommandSelection(commandIndex - 1)
        elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
            runSelectedCommand()
        end
    end)

    ----------------------------------------------------------------
    -- Drag + resize (mouse + touch, clamped to viewport)
    ----------------------------------------------------------------
    local function pointInside(gui, pos)
        local p, s = gui.AbsolutePosition, gui.AbsoluteSize
        return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
    end

    local function isInteractivePoint(pos)
        local objects = GuiService:GetGuiObjectsAtPosition(pos.X, pos.Y)
        for _, obj in ipairs(objects) do
            local cur = obj
            while cur and cur ~= screenGui do
                if cur:IsA("TextBox") or cur:IsA("GuiButton") or cur.Name == "ResizeHandle" or cur:GetAttribute("AbyssPopup") then
                    return true
                end
                cur = cur.Parent
            end
        end
        return false
    end

    WindowMaid:Connect(UserInputService.InputBegan, function(input, processed)
        if processed or Window._destroyed or not main.Visible then return end
        local kind = input.UserInputType
        if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
        local pos = input.Position
        if not pointInside(main, pos) or isInteractivePoint(pos) then return end
        dragging = true
        dragStart = pos
        startPos = main.Position
    end)

    WindowMaid:Connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            setWindowPosition(UDim2.new(0.5, startPos.X.Offset + delta.X, 0.5, startPos.Y.Offset + delta.Y), true)
        end
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - resizeStart
            Window:SetSize(resizeStartSize.X + delta.X, resizeStartSize.Y + delta.Y, true)
        end
    end)

    WindowMaid:Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            resizing = false
            queueConfigSave()
        end
    end)

    WindowMaid:Connect(resizeHandle.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        resizing = true
        resizeStart = input.Position
        resizeStartSize = Vector2.new(main.Size.X.Offset, main.Size.Y.Offset)
    end)

    ----------------------------------------------------------------
    -- Minimize / restore / visibility
    ----------------------------------------------------------------
    local function setMinimized(state, save)
        minimized = state == true
        Window._minimized = minimized
        if minimized then
            Window._restoredHeight = Window._restoredHeight or math.max(main.Size.Y.Offset, 540)
            sidebar.Visible = false
            pages.Visible = false
            searchBox.Visible = false
            resizeHandle.Visible = false
            tween(main, 0.28, { Size = UDim2.fromOffset(main.Size.X.Offset, 66) })
            tween(shadow, 0.28, { Size = UDim2.fromOffset(main.Size.X.Offset + 12, 78) })
        else
            sidebar.Visible = true
            pages.Visible = true
            searchBox.Visible = true
            resizeHandle.Visible = true
            local restoreH = Window._restoredHeight or 540
            tween(main, 0.28, { Size = UDim2.fromOffset(main.Size.X.Offset, restoreH) })
            task.delay(0.30, setShadowForMain)
        end
        if save ~= false then queueConfigSave() end
    end

    function Window:SetMinimized(state, save)
        if Window._destroyed then return end
        state = state == true
        if state == minimized then return end
        if state then
            if not minimized and main.Size.Y.Offset > 66 then
                Window._restoredHeight = math.max(main.Size.Y.Offset, Theme.MinHeight)
            elseif not Window._restoredHeight then
                Window._restoredHeight = Theme.MinHeight
            end
        end
        setMinimized(state, save ~= false)
    end

    WindowMaid:Connect(minimizeButton.MouseButton1Click, function()
        Window:SetMinimized(not minimized)
    end)

    WindowMaid:Connect(closeButton.MouseButton1Click, function()
        Window:Hide()
    end)

    local toggleKey = resolveKey(settings.ToggleUIKeybind or Enum.KeyCode.RightShift)
    Window.ToggleUIKeybind = toggleKey
    function Window:SetToggleKeybind(key)
        local resolved = resolveKey(key)
        if resolved then toggleKey = resolved; Window.ToggleUIKeybind = resolved end
        return toggleKey
    end
    WindowMaid:Connect(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        if input.KeyCode == toggleKey then
            if main.Visible then Window:Hide() else Window:Show() end
        elseif input.KeyCode == Enum.KeyCode.K and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            setCommandPalette(true)
        end
    end)


    function Window:Show()
        if Window._destroyed then return end
        main.Visible = true
        shadow.Visible = true
        screenGui.Enabled = true
    end

    function Window:ClosePopups()
        if Window._destroyed then return end
        for _, obj in ipairs(screenGui:GetChildren()) do
            if obj:IsA("GuiObject") and obj:GetAttribute("AbyssPopup") then
                obj.Visible = false
            end
        end
        commandBackdrop.Visible = false
        commandBox.Visible = false
    end

    function Window:Hide()
        if Window._destroyed then return end
        Window:ClosePopups()
        main.Visible = false
        shadow.Visible = false
        commandBackdrop.Visible = false
        commandBox.Visible = false
    end

    function Window:Destroy()
        if Window._destroyed then return end
        Window._destroyed = true
        saveConfiguration()
        if WindowMaid then WindowMaid:Cleanup() end
        if commandBackdrop then commandBackdrop:Destroy() end
        if commandBox then commandBox:Destroy() end
        local windowRoot = Window._screenGui
        if windowRoot and windowRoot.Parent then pcall(function() windowRoot:Destroy() end) end
        if screenGui == windowRoot then screenGui = nil; notifyHolder = nil end
        Library.Flags = {}
        Library.Interface = nil
        if Library.Window == Window then Library.Window = nil end
        WindowMaid = nil
    end

    function Library:Destroy()
        if Library.Window and not Library.Window._destroyed then
            Library.Window:Destroy()
        else
            LibraryMaid:Cleanup()
            if screenGui and screenGui.Parent then pcall(function() screenGui:Destroy() end) end
            screenGui = nil
            notifyHolder = nil
            Library.Interface = nil
            Library.Window = nil
            Library.Flags = {}
        end
    end

    -- Reactive theme refresh
    function Library:SetAccent(color, color2)
        local oldAccent, oldAccent2 = Theme.Accent, Theme.Accent2
        if typeof(color) == "Color3" then Theme.Accent = color end
        if typeof(color2) == "Color3" then Theme.Accent2 = color2 end
        for _, obj in ipairs(screenGui:GetDescendants()) do
            if obj:IsA("GuiObject") and obj:GetAttribute("AbyssRole") == "Accent" then obj.BackgroundColor3 = Theme.Accent end
            if obj:IsA("TextLabel") and obj:GetAttribute("AbyssRole") == "AccentText" then obj.TextColor3 = Theme.Accent end
            if obj:IsA("UIStroke") and obj:GetAttribute("AbyssRole") == "Accent" then obj.Color = Theme.Accent end
        end
        emitThemeChanged()
        return oldAccent ~= Theme.Accent or oldAccent2 ~= Theme.Accent2
    end

    function Library:SetTheme(name)
        local previous = {}
        for key, value in pairs(Theme) do previous[key] = value end
        if not applyThemePreset(name) then return false end
        if screenGui then
            for _, obj in ipairs(screenGui:GetDescendants()) do
                if obj:IsA("GuiObject") then
                    local bg = obj.BackgroundColor3
                    if bg == previous.Background then obj.BackgroundColor3 = Theme.Background
                    elseif bg == previous.Topbar then obj.BackgroundColor3 = Theme.Topbar
                    elseif bg == previous.Sidebar then obj.BackgroundColor3 = Theme.Sidebar
                    elseif bg == previous.ElementBackground then obj.BackgroundColor3 = Theme.ElementBackground
                    elseif bg == previous.ElementBackgroundHover then obj.BackgroundColor3 = Theme.ElementBackgroundHover
                    elseif bg == previous.TabBackground then obj.BackgroundColor3 = Theme.TabBackground
                    elseif bg == previous.TabBackgroundSelected then obj.BackgroundColor3 = Theme.TabBackgroundSelected
                    elseif bg == previous.SliderBackground then obj.BackgroundColor3 = Theme.SliderBackground
                    elseif bg == previous.SliderProgress then obj.BackgroundColor3 = Theme.SliderProgress
                    elseif bg == previous.ToggleEnabled then obj.BackgroundColor3 = Theme.ToggleEnabled
                    elseif bg == previous.NotificationBackground then obj.BackgroundColor3 = Theme.NotificationBackground end
                    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                        local tc = obj.TextColor3
                        if tc == previous.TextColor then obj.TextColor3 = Theme.TextColor
                        elseif tc == previous.MutedTextColor then obj.TextColor3 = Theme.MutedTextColor
                        elseif tc == previous.TabTextColor then obj.TextColor3 = Theme.TabTextColor
                        elseif tc == previous.SelectedTabTextColor then obj.TextColor3 = Theme.SelectedTabTextColor
                        elseif tc == previous.SectionTextColor then obj.TextColor3 = Theme.SectionTextColor end
                    end
                elseif obj:IsA("UIStroke") then
                    if obj.Color == previous.ElementStroke then obj.Color = Theme.ElementStroke end
                end
            end
        end
        emitThemeChanged()
        if not Window or Window._destroyed then return true end
        local function refreshObject(obj)
            if obj:IsA("GuiObject") then
                local role = obj:GetAttribute("AbyssRole")
                if role == "Background" then obj.BackgroundColor3 = Theme.Background
                elseif role == "Surface" then obj.BackgroundColor3 = Theme.ElementBackground
                elseif role == "SurfaceHover" then obj.BackgroundColor3 = Theme.ElementBackgroundHover
                elseif role == "Topbar" then obj.BackgroundColor3 = Theme.Topbar
                elseif role == "Sidebar" then obj.BackgroundColor3 = Theme.Sidebar
                elseif role == "Tab" then obj.BackgroundColor3 = Theme.TabBackground
                elseif role == "TabSelected" then obj.BackgroundColor3 = Theme.TabBackgroundSelected
                elseif role == "Accent" then obj.BackgroundColor3 = Theme.Accent end
            elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                local role = obj:GetAttribute("AbyssRole")
                if role == "Text" then obj.TextColor3 = Theme.TextColor
                elseif role == "Muted" then obj.TextColor3 = Theme.MutedTextColor
                elseif role == "TabText" then obj.TextColor3 = Theme.TabTextColor
                elseif role == "AccentText" then obj.TextColor3 = Theme.Accent end
            elseif obj:IsA("UIStroke") and obj:GetAttribute("AbyssRole") == "Border" then
                obj.Color = Theme.ElementStroke
            end
        end
        for _, obj in ipairs(screenGui:GetDescendants()) do refreshObject(obj) end
        main.BackgroundTransparency = adaptiveTransparency(Theme.GlassTransparency)
        return true
    end

    function Library:SetAccessibility(options)
        options = options or {}
        if options.ReducedMotion ~= nil then UIState.ReducedMotion = options.ReducedMotion == true end
        if options.HighContrast ~= nil then UIState.HighContrast = options.HighContrast == true end
        if options.Density == "Compact" or options.Density == "Comfortable" then UIState.Density = options.Density end
        if options.Scale ~= nil then UIState.Scale = math.clamp(tonumber(options.Scale) or 1, 0.85, 1.25) end
        if screenGui then
            for _, obj in ipairs(screenGui:GetDescendants()) do
                if obj:IsA("GuiObject") then
                    if obj:GetAttribute("AbyssGlass") then
                        local base = tonumber(obj:GetAttribute("AbyssGlassBase")) or obj.BackgroundTransparency
                        if obj:GetAttribute("AbyssGlassBase") == nil then obj:SetAttribute("AbyssGlassBase", base) end
                        obj.BackgroundTransparency = adaptiveTransparency(base)
                    end
                elseif obj:IsA("UIStroke") then
                    if obj:GetAttribute("AbyssBaseTransparency") == nil then obj:SetAttribute("AbyssBaseTransparency", obj.Transparency) end
                    local base = tonumber(obj:GetAttribute("AbyssBaseTransparency")) or obj.Transparency
                    obj.Transparency = UIState.HighContrast and math.max(0, base - 0.22) or base
                end
            end
        end
        emitThemeChanged()
        return self:GetAccessibility()
    end

    function Library:GetAccessibility()
        return { ReducedMotion = UIState.ReducedMotion, HighContrast = UIState.HighContrast, Density = UIState.Density, Scale = UIState.Scale }
    end

    -- Built-in premium utility tabs
    if settings.BuiltInTabs ~= false then
        local settingsTab = Window:CreateTab({ Name = "Settings", Icon = "⚙" })
        settingsTab:CreateSection("Interface")
        settingsTab:CreateToggle({ Name = "Reduced motion", CurrentValue = UIState.ReducedMotion, Flag = "ui.reducedMotion", Callback = function(v) Library:SetAccessibility({ ReducedMotion = v }) end })
        settingsTab:CreateToggle({ Name = "High contrast", CurrentValue = UIState.HighContrast, Flag = "ui.highContrast", Callback = function(v) Library:SetAccessibility({ HighContrast = v }) end })
        settingsTab:CreateDropdown({ Name = "Density", Options = { "Comfortable", "Compact" }, CurrentOption = UIState.Density, Flag = "ui.density", Callback = function(v) Library:SetAccessibility({ Density = type(v) == "table" and v[1] or v }) end })
        settingsTab:CreateSlider({ Name = "UI scale", Min = 85, Max = 125, Increment = 1, CurrentValue = math.floor(UIState.Scale * 100), Suffix = "%", Flag = "ui.scale", Callback = function(v) Library:SetAccessibility({ Scale = v / 100 }) end })
        settingsTab:CreateSection("Window")
        settingsTab:CreateButton({ Name = "Center window", Callback = function() Window:SetPosition(0, 0) end })
        settingsTab:CreateButton({ Name = "Export profile", Callback = function() Library:ExportProfile() end })
        settingsTab:CreateButton({ Name = "Save profile", Callback = function() saveConfiguration() end })

        local themesTab = Window:CreateTab({ Name = "Themes", Icon = "✦" })
        themesTab:CreateSection("Appearance")
        themesTab:CreateDropdown({ Name = "Theme", Options = { "Glass", "DarkBlue", "Ocean" }, CurrentOption = currentThemeName() or "Glass", Callback = function(v) Library:SetTheme(type(v) == "table" and v[1] or v) end })
        themesTab:CreateColorPicker({ Name = "Accent", Color = Theme.Accent, Flag = "ui.accent", Callback = function(c) Library:SetAccent(c, Theme.Accent2) end })
        themesTab:CreateColorPicker({ Name = "Accent secondary", Color = Theme.Accent2, Flag = "ui.accent2", Callback = function(c) Library:SetAccent(Theme.Accent, c) end })
        themesTab:CreateButton({ Name = "Reset appearance", Callback = function() Library:SetTheme("Glass"); Library:SetAccent(ThemePresets.Glass.Accent, ThemePresets.Glass.Accent2) end })
    end

    -- Select first tab after API has been returned to the user.
    if configSettings.Enabled and configSettings.AutoLoad then
        task.defer(function()
            if not Window._destroyed then
                Library:LoadConfiguration()
            end
        end)
    end

    -- Default first tab is selected after creation.
    task.defer(function()
        if #Window.Tabs > 0 and not Window._destroyed then
            selectTab(Window.Tabs[1])
        end
    end)

    -- Keep shadow synced if size changes through Roblox externally.
    WindowMaid:Connect(main:GetPropertyChangedSignal("Size"), setShadowForMain)
    WindowMaid:Connect(main:GetPropertyChangedSignal("Position"), setShadowForMain)
    WindowMaid:Connect(screenGui:GetPropertyChangedSignal("AbsoluteSize"), function()
        local x, y = clampWindowOffsets(main.Position.X.Offset, main.Position.Y.Offset)
        main.Position = UDim2.new(0.5, x, 0.5, y)
        setShadowForMain()
    end)

    return Window
end

function Library:SetAutoLoadConfiguration(enabled)
    configSettings.AutoLoad = enabled == true
end

function Library:Show()
    if self.Interface then self.Interface.Enabled = true end
    if self.Window then self.Window:Show() end
end

function Library:Hide()
    if self.Window then self.Window:Hide() else if self.Interface then self.Interface.Enabled = false end end
end

function Library:GetTheme()
    local copy = {}
    for key, value in pairs(Theme) do copy[key] = value end
    return copy
end

function Library:GetThemeNames()
    local names = {}
    for name in pairs(ThemePresets) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function Library:SubscribeThemeChanged(callback)
    return subscribeTheme(callback)
end

return Library
