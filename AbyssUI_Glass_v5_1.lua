-- =====================================================================
-- abyss.lua  //  unknown build — single distributable file
-- =====================================================================
local RS   = game:GetService("RunService")
local Players = game:GetService("Players")
local UIS  = game:GetService("UserInputService")
local HS   = game:GetService("HttpService")
local WS   = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
if not RS:IsClient() then return end
local LP = Players.LocalPlayer or Players.PlayerAdded:Wait()

local CAP = {
    drawing = type(Drawing) == "table" and type(Drawing.new) == "function",
    fs      = type(writefile)=="function" and type(readfile)=="function"
              and type(isfile)=="function" and type(makefolder)=="function"
              and type(isfolder)=="function",
    hook    = type(getrawmetatable)=="function" and type(setreadonly)=="function"
              and type(newcclosure)=="function" and type(getnamecallmethod)=="function",
    gethui  = type(gethui)=="function",
}

----------------------------------------------------------------
-- unload previous instance (safe inject prerequisite)
----------------------------------------------------------------
local ENV = (type(getgenv)=="function" and getgenv()) or _G
if type(ENV.__ABYSS)=="table" and type(ENV.__ABYSS.Unload)=="function" then
    pcall(ENV.__ABYSS.Unload)
end
ENV.__ABYSS = nil

----------------------------------------------------------------
-- scope system
----------------------------------------------------------------
local scopes = {}
local function newScope(name)
    local s = { name=name, alive=true, conns={}, insts={}, fns={}, renders={} }
    function s:Connect(sig, fn)
        if not self.alive then return nil end
        local c = sig:Connect(fn)
        self.conns[#self.conns+1] = c
        return c
    end
    function s:Give(i)
        if not self.alive then pcall(function() i:Destroy() end) return i end
        self.insts[#self.insts+1] = i
        return i
    end
    function s:Add(fn)
        if not self.alive then pcall(fn) return end
        self.fns[#self.fns+1] = fn
    end
    function s:BindRender(key, prio, fn)
        if not self.alive then return end
        local nm = "ABYSS_" .. key
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
-- diagnostics
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
-- settings schema + STRICT config
----------------------------------------------------------------
local SCH = {
    Aimbot = {
        Enabled     = {t="b", d=false, f=true},
        Silent      = {t="b", d=false, f=true},
        OnlyEnemies = {t="b", d=true},
        WallCheck   = {t="b", d=true},
        ShowFOV     = {t="b", d=true},
        TargetLock  = {t="b", d=true},
        FOV         = {t="n", d=150, min=20,  max=800},
        Smoothing   = {t="n", d=0.12, min=0.01, max=1.0},
        Prediction  = {t="n", d=0.10, min=0,    max=0.5},
    },
    Trigger = {
        Enabled     = {t="b", d=false, f=true},
        OnlyEnemies = {t="b", d=true},
        WallCheck   = {t="b", d=true},
        Delay       = {t="n", d=0.07, min=0, max=0.5},
    },
    ESP = {
        Enabled     = {t="b", d=false, f=true},
        Boxes       = {t="b", d=true},
        HealthBar   = {t="b", d=true},
        Snaplines   = {t="b", d=false},
        Names       = {t="b", d=true},
        Distance    = {t="b", d=true},
        Chams       = {t="b", d=false, f=true},
        OnlyEnemies = {t="b", d=true},
        MaxDistance  = {t="n", d=500, min=50, max=2000},
    },
    Move = {
        Speed       = {t="b", d=false, f=true},
        SpeedValue  = {t="n", d=50,  min=16, max=200},
        SpeedMode   = {t="e", d="Walk", enum={Walk=true, Vel=true}},
        Fly         = {t="b", d=false, f=true},
        FlyValue    = {t="n", d=60,  min=20, max=200},
        NoClip      = {t="b", d=false, f=true},
        InfJump     = {t="b", d=false, f=true},
        Hitbox      = {t="b", d=false, f=true},
        HitboxSize  = {t="n", d=12,  min=3,  max=25},
    },
    AA = {
        Jitter      = {t="b", d=false, f=true},
        JitterAngle = {t="n", d=40, min=10, max=180},
        Desync      = {t="b", d=false, f=true},
        DesyncMode  = {t="e", d="Spin", enum={Spin=true, Static=true, Backwards=true}},
        HideHead    = {t="b", d=false, f=true},
        FakeLag     = {t="b", d=false, f=true},
        Spinbot     = {t="b", d=false, f=true},
    },
    Misc = {
        Watermark    = {t="b", d=true},
        AntiAFK      = {t="b", d=true},
        KeybindDisplay = {t="b", d=true},
    },
    Keys = {
        UI     = {t="k", d="RightShift"},
        Aimbot = {t="k", d="X"},
        Silent = {t="k", d="B"},
        Fly    = {t="k", d="F"},
        Speed  = {t="k", d="V"},
        Trigger= {t="k", d="C"},
        Lock   = {t="k", d="Q"},
        AA     = {t="k", d="Z"},
        ESP    = {t="k", d="E"},
    },
}

local S = {}
for g, keys in pairs(SCH) do
    S[g] = {}
    for k, spec in pairs(keys) do S[g][k] = spec.d end
end
-- capability fail-closed
if not CAP.drawing then S.ESP.Enabled = false end
if not CAP.hook    then S.Aimbot.Silent = false end

local WATCH, UIREFS = {}, {}
local function watch(p, fn) WATCH[p] = WATCH[p] or {}; WATCH[p][#WATCH[p]+1] = fn end
local function uiref(p, fn) UIREFS[p] = UIREFS[p] or {}; UIREFS[p][#UIREFS[p]+1] = fn end

local function sanitize(spec, v)
    if spec.t=="b" then return v==true end
    if spec.t=="n" then local n=tonumber(v) if n==nil then return nil end return math.clamp(n,spec.min,spec.max) end
    if spec.t=="e" then return spec.enum[v] and v or nil end
    if spec.t=="k" then
        if type(v)~="string" then return nil end
        if v~="" and not Enum.KeyCode[v] then return nil end
        return v
    end
    return nil
end

local saveQueued = false
local CFGPATH = "AbyssFW/unknown.json"
local function saveConfig()
    if not CAP.fs then return false end
    local ok, enc = pcall(function() return HS:JSONEncode(S) end)
    if not ok then return false end
    local wrote = false
    pcall(function()
        if not isfolder("AbyssFW") then makefolder("AbyssFW") end
        writefile(CFGPATH, enc)
        wrote = true
    end)
    return wrote
end
local function queueSave()
    if saveQueued then return end
    saveQueued = true
    task.delay(0.5, function() saveQueued = false if App.alive then saveConfig() end end)
end
local function loadConfig()
    if not CAP.fs or not isfile(CFGPATH) then return false end
    local ok, txt = pcall(readfile, CFGPATH)
    if not ok or type(txt)~="string" then return false end
    local ok2, data = pcall(function() return HS:JSONDecode(txt) end)
    if not ok2 or type(data)~="table" then return false end
    for g, keys in pairs(SCH) do
        if type(data[g])=="table" then
            for k, spec in pairs(keys) do
                local v = sanitize(spec, data[g][k])
                if v ~= nil then S[g][k] = v end
            end
        end
    end
    return true
end

local function Get(path) local g,k = path:match("^(%w+)%.(%w+)$") return S[g] and S[g][k] end
local function Set(path, value, skipSave)
    local g, k = path:match("^(%w+)%.(%w+)$")
    local spec = SCH[g] and SCH[g][k]
    if not spec then return false end
    local v = sanitize(spec, value)
    if v == nil then return false end
    S[g][k] = v
    for _, fn in ipairs(WATCH[path] or {}) do pcall(fn, v) end
    for _, fn in ipairs(UIREFS[path] or {}) do pcall(fn, v) end
    if not skipSave then queueSave() end
    return true
end

loadConfig()
-- SAFE INJECT: every feature flag forced off at load
for g, keys in pairs(SCH) do
    for k, spec in pairs(keys) do
        if spec.f then S[g][k] = false end
    end
end

----------------------------------------------------------------
-- player cache (event-driven, generation-safe)
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
    local gen = rec.gen
    rec.char = char
    rec.cscope = newScope("char:" .. rec.plr.Name .. ":" .. gen)
    rec.hum  = char:FindFirstChildOfClass("Humanoid")
    rec.root = char:FindFirstChild("HumanoidRootPart")
    rec.head = char:FindFirstChild("Head")
    rec.rig  = (rec.hum and rec.hum.RigType == Enum.HumanoidRigType.R15) and "R15" or "R6"
    rec.alive = (rec.hum ~= nil and rec.hum.Health > 0)
    if rec.hum then
        rec.cscope:Connect(rec.hum.Died, function() rec.alive = false end)
        rec.cscope:Connect(rec.hum:GetPropertyChangedSignal("Health"), function()
            rec.alive = rec.hum.Health > 0
        end)
    end
    recomputeEnemy(rec)
    for _, fn in ipairs(charL) do pcall(fn, rec, char, gen) end
end

local function onCharRemoving(rec, char)
    if rec.char ~= char then return end
    rec.alive = false
    rec.char = nil; rec.hum = nil; rec.root = nil; rec.head = nil
    if rec.cscope then rec.cscope:Destroy(); rec.cscope = nil end
    for _, fn in ipairs(leaveL) do pcall(fn, rec, char) end
end

local function wire(plr)
    local rec = { plr = plr, gen = 0 }
    rec.pscope = newScope("plr:" .. plr.Name)
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
-- shared raycast (aimbot + triggerbot + visible check)
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
    Diag.ray = Diag.ray + 1
    internalRay = true
    local ok, hit = pcall(WS.Raycast, WS, origin, dir, rayParams)
    internalRay = false
    if not ok then return true end
    if not hit then return true end
    if targetChar and hit.Instance:IsDescendantOf(targetChar) then return true end
    return false
end

----------------------------------------------------------------
-- visuals (ESP, pooled, 30Hz)
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
    o.Visible = false
    return o
end
local function release(o, kind)
    if not o then return end
    pcall(function() o.Visible = false end)
    Pool.free[kind][#Pool.free[kind]+1] = o
end
local function releaseViz(rec)
    local v = rec.viz
    if not v then return end
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
    local hSp = cam:WorldToViewportPoint(headPos); Diag.proj = Diag.proj + 1
    local lSp = cam:WorldToViewportPoint(legPos);  Diag.proj = Diag.proj + 1
    if hSp.Z < 0 and lSp.Z < 0 then releaseViz(rec); return end
    local height = math.abs(lSp.Y - hSp.Y)
    local width  = height * 0.5
    local x = hSp.X - width*0.5
    local y = hSp.Y
    local color = rec.enemy and Color3.fromRGB(255,60,60) or Color3.fromRGB(90,140,255)

    if S.ESP.Boxes then
        v.box = v.box or acquire("Square")
        if v.box then
            v.box.Filled=false; v.box.Thickness=1; v.box.Color=color
            v.box.Size=Vector2.new(width, height); v.box.Position=Vector2.new(x, y)
            v.box.Visible = true
        end
    else release(v.box, "Square"); v.box = nil end

    if S.ESP.HealthBar and rec.hum and rec.hum.MaxHealth > 0 then
        v.hpBg   = v.hpBg   or acquire("Square")
        v.hpFill = v.hpFill or acquire("Square")
        local pct = math.clamp(rec.hum.Health / rec.hum.MaxHealth, 0, 1)
        if v.hpBg then
            v.hpBg.Filled=true; v.hpBg.Color=Color3.fromRGB(0,0,0)
            v.hpBg.Size=Vector2.new(3, height); v.hpBg.Position=Vector2.new(x-5, y)
            v.hpBg.Visible = true
        end
        if v.hpFill then
            local bh = height * pct
            v.hpFill.Filled = true
            v.hpFill.Size = Vector2.new(3, bh)
            v.hpFill.Position = Vector2.new(x-5, y + (height - bh))
            v.hpFill.Color = Color3.fromRGB(60,220,60):Lerp(Color3.fromRGB(220,60,60), 1-pct)
            v.hpFill.Visible = true
        end
    else release(v.hpBg,"Square"); v.hpBg=nil; release(v.hpFill,"Square"); v.hpFill=nil end

    if S.ESP.Snaplines then
        v.snap = v.snap or acquire("Line")
        if v.snap then
            local vp = cam.ViewportSize
            v.snap.Thickness=1; v.snap.Color=color
            v.snap.From = Vector2.new(vp.X*0.5, vp.Y)
            v.snap.To   = Vector2.new(hSp.X, hSp.Y)
            v.snap.Visible = true
        end
    else release(v.snap, "Line"); v.snap = nil end

    if S.ESP.Names then
        v.name = v.name or acquire("Text")
        if v.name then
            v.name.Size=13; v.name.Center=true; v.name.Outline=true; v.name.Color=color
            v.name.Text = (rec.plr.DisplayName~="" and rec.plr.DisplayName) or rec.plr.Name
            v.name.Position = Vector2.new(hSp.X, y - 16)
            v.name.Visible = true
        end
    else release(v.name, "Text"); v.name = nil end

    if S.ESP.Distance then
        v.dist = v.dist or acquire("Text")
        if v.dist then
            v.dist.Size=12; v.dist.Center=true; v.dist.Outline=true
            v.dist.Color = Color3.fromRGB(255,255,255)
            v.dist.Text = tostring(math.floor(dist)) .. "m"
            v.dist.Position = Vector2.new(hSp.X, y + height + 4)
            v.dist.Visible = true
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
-- aimbot + silent hook + FOV circle + triggerbot
----------------------------------------------------------------
local AIM = { current = nil, locked = false, triggerAcc = 0 }
local fovCircle = nil
if CAP.drawing then
    local ok, c = pcall(function() return Drawing.new("Circle") end)
    if ok and c then
        fovCircle = c
        fovCircle.Thickness = 2
        fovCircle.NumSides  = 64
        fovCircle.Filled    = false
        fovCircle.Color     = Color3.fromRGB(255, 60, 60)
        fovCircle.Visible   = false
        App:Add(function() pcall(function() fovCircle:Remove() end) end)
    end
end

local HIT_PRIORITY = {
    R15 = {"Head","UpperTorso","LowerTorso","HumanoidRootPart"},
    R6  = {"Head","Torso","HumanoidRootPart"},
}
local function pickPart(rec)
    if not rec or not rec.char then return nil end
    local list = HIT_PRIORITY[rec.rig] or HIT_PRIORITY.R6
    for _, n in ipairs(list) do
        local p = rec.char:FindFirstChild(n)
        if p and p:IsA("BasePart") then return p end
    end
    return nil
end
local LEAD_CAP = 35
local function predict(part, dt)
    if not part or not part.Parent then return nil end
    local pos = part.Position
    local vel = part.AssemblyLinearVelocity
    if typeof(vel) ~= "Vector3" then return pos end
    if vel.Magnitude > 500 then vel = vel.Unit * 500 end
    local lead = vel * (dt or S.Aimbot.Prediction)
    if lead.Magnitude > LEAD_CAP then lead = lead.Unit * LEAD_CAP end
    return pos + lead
end

local function GetBestTarget()
    if not cam then return nil end
    local lc = localRec()
    if not lc or not lc.alive then return nil end

    if AIM.locked and AIM.current then
        local rec = AIM.current.rec
        if rec and rec.alive and rec.char and rec.char.Parent then
            local part = pickPart(rec)
            if part then
                local pos = predict(part)
                local sp, on = cam:WorldToViewportPoint(pos)
                if on and sp.Z > 0 then
                    local vp = cam.ViewportSize
                    local center = Vector2.new(vp.X*0.5, vp.Y*0.5)
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d <= S.Aimbot.FOV * 1.5 then
                        if not S.Aimbot.WallCheck or isVisible(pos, rec.char) then
                            return { rec=rec, part=part, pos=pos, screen=sp }
                        end
                    end
                end
            end
        end
        AIM.locked = false
        AIM.current = nil
    end

    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X*0.5, vp.Y*0.5)
    local bestEntry, bestScore = nil, math.huge
    for plr, rec in pairs(Cache.byPlayer) do
        if plr ~= LP and rec.alive and rec.char then
            if not S.Aimbot.OnlyEnemies or rec.enemy then
                local part = pickPart(rec)
                if part then
                    local pos = predict(part)
                    local sp, on = cam:WorldToViewportPoint(pos)
                    if on and sp.Z > 0 then
                        local dx = sp.X - center.X
                        local dy = sp.Y - center.Y
                        local d = math.sqrt(dx*dx + dy*dy)
                        if d <= S.Aimbot.FOV then
                            if not S.Aimbot.WallCheck or isVisible(pos, rec.char) then
                                local hp = (rec.hum and rec.hum.Health>0 and rec.hum.MaxHealth>0)
                                    and (rec.hum.Health / rec.hum.MaxHealth) or 0
                                local sc = d + 100 * (1 - hp)
                                if sc < bestScore then
                                    bestScore = sc
                                    bestEntry = { rec=rec, part=part, pos=pos, screen=sp }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestEntry
end

local function aimUpdate(dt)
    if fovCircle then
        if (S.Aimbot.Enabled or S.Aimbot.Silent) and S.Aimbot.ShowFOV and cam then
            local vp = cam.ViewportSize
            fovCircle.Position = Vector2.new(vp.X*0.5, vp.Y*0.5)
            fovCircle.Radius = S.Aimbot.FOV
            fovCircle.Color = S.Aimbot.Silent
                and Color3.fromRGB(255,80,80)
                or  Color3.fromRGB(255,60,60)
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end
    local t = nil
    if S.Aimbot.Enabled or S.Aimbot.Silent then t = GetBestTarget() end
    AIM.current = t
    if S.Aimbot.Enabled and t and cam then
        local c = cam.CFrame
        local desired = CFrame.lookAt(c.Position, t.pos)
        local sm = math.max(S.Aimbot.Smoothing, 0.01)
        local alpha = 1 - math.exp(-(dt or 1/60) * (60 / sm))
        cam.CFrame = c:Lerp(desired, math.clamp(alpha, 0, 1))
    end
end
App:BindRender("aim", Enum.RenderPriority.Camera.Value - 1, aimUpdate)

-- silent aim hook (covers Raycast + legacy FindPartOnRay*)
local hookOn, origNC, gameMt = false, nil, nil
local function hookBody(self, ...)
    if internalRay or not S.Aimbot.Silent then return origNC(self, ...) end
    if self ~= WS then return origNC(self, ...) end
    local m = getnamecallmethod()
    local isRay = (m == "Raycast")
    local isLegacy = (m == "FindPartOnRay"
                   or m == "FindPartOnRayWithIgnoreList"
                   or m == "FindPartOnRayWithWhitelist")
    if not isRay and not isLegacy then return origNC(self, ...) end
    local origin, dir
    if isRay then
        origin, dir = select(1, ...), select(2, ...)
        if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" then
            return origNC(self, ...)
        end
    else
        local r = select(1, ...)
        if typeof(r) ~= "Ray" then return origNC(self, ...) end
        origin, dir = r.Origin, r.Direction
    end
    if dir.Magnitude < 0.5 then return origNC(self, ...) end
    local lc = localRec()
    local lr = lc and lc.root
    if not lr or (origin - lr.Position).Magnitude > 60 then
        return origNC(self, ...)
    end
    local t = AIM.current
    if not t or not t.rec.alive or not t.part or not t.part.Parent then
        return origNC(self, ...)
    end
    local diff = t.pos - origin
    if diff.Magnitude < 0.5 then return origNC(self, ...) end
    local nd = diff.Unit * dir.Magnitude
    if isRay then
        local a = { ... }; a[2] = nd
        return origNC(self, table.unpack(a))
    else
        local a = { ... }; a[1] = Ray.new(origin, nd)
        return origNC(self, table.unpack(a))
    end
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

-- triggerbot: camera-center raycast
local function triggerUpdate(dt)
    if not S.Trigger.Enabled or not cam then return end
    AIM.triggerAcc = (AIM.triggerAcc or 0) + dt
    if AIM.triggerAcc < S.Trigger.Delay then return end
    local lc = localRec()
    if not lc or not lc.alive then return end
    local origin = cam.CFrame.Position
    local dir = cam.CFrame.LookVector * 1000
    local ignore = { cam }
    if lc.char then ignore[#ignore+1] = lc.char end
    rayParams.FilterDescendantsInstances = ignore
    internalRay = true
    local ok, hit = pcall(WS.Raycast, WS, origin, dir, rayParams)
    internalRay = false
    if not ok or not hit then return end
    local inst = hit.Instance
    while inst and not inst:IsA("Model") do inst = inst.Parent end
    if not inst then return end
    local owner = Players:GetPlayerFromCharacter(inst)
    if not owner or owner == LP then return end
    local rec = Cache.byPlayer[owner]
    if not rec or not rec.alive then return end
    if S.Trigger.OnlyEnemies and not rec.enemy then return end
    if S.Trigger.WallCheck and not hit.Instance:IsDescendantOf(rec.char) then return end
    AIM.triggerAcc = 0
    pcall(function() mouse1click() end)
end
App:Connect(RS.Heartbeat, triggerUpdate)

----------------------------------------------------------------
-- movement
----------------------------------------------------------------
local MV = { origWalk = nil, fly = nil, nc = {}, hx = {}, ncOn = false }
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
onChar(function(rec)
    if rec == localRec() then
        MV.origWalk = nil; MV.nc = {}; MV.hx = {}; MV.ncOn = false
        destroyFly()
    end
end)
App:Connect(RS.Heartbeat, function(dt)
    local rec = localRec()
    if not rec or not rec.alive or not rec.hum or not rec.root then return end
    local hum, root = rec.hum, rec.root
    if S.Move.Speed then
        if MV.origWalk == nil then MV.origWalk = hum.WalkSpeed end
        if S.Move.SpeedMode == "Walk" then
            if hum.WalkSpeed ~= S.Move.SpeedValue then hum.WalkSpeed = S.Move.SpeedValue end
        else
            local md = hum.MoveDirection
            if md.Magnitude > 0.1 then
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(md.X * S.Move.SpeedValue, v.Y, md.Z * S.Move.SpeedValue)
            end
        end
    elseif MV.origWalk then
        if hum.WalkSpeed ~= MV.origWalk then hum.WalkSpeed = MV.origWalk end
        MV.origWalk = nil
    end
    if S.Move.NoClip then
        if not MV.ncOn then
            MV.nc = {}
            for _, part in ipairs(rec.char:GetDescendants()) do
                if part:IsA("BasePart") then MV.nc[part] = part.CanCollide end
            end
            MV.ncOn = true
        end
        for part in pairs(MV.nc) do
            if part.Parent and part.CanCollide then part.CanCollide = false end
        end
    elseif MV.ncOn then
        for part, can in pairs(MV.nc) do
            if part.Parent then pcall(function() part.CanCollide = can end) end
        end
        MV.nc = {}; MV.ncOn = false
    end
    if S.Move.Hitbox then
        for _, other in pairs(Cache.byPlayer) do
            if other ~= rec and other.char then
                for _, name in ipairs({"Head","UpperTorso","LowerTorso","Torso"}) do
                    local part = other.char:FindFirstChild(name)
                    if part and part:IsA("BasePart") then
                        if MV.hx[part] == nil then
                            MV.hx[part] = { Size = part.Size, Transparency = part.Transparency }
                        end
                        if part.Size.X ~= S.Move.HitboxSize then
                            part.Size = Vector3.new(S.Move.HitboxSize, S.Move.HitboxSize, S.Move.HitboxSize)
                        end
                        part.Transparency = 0.6
                    end
                end
            end
        end
    else
        for part, orig in pairs(MV.hx) do
            if part.Parent then
                pcall(function() part.Size = orig.Size; part.Transparency = orig.Transparency end)
            end
        end
        MV.hx = {}
    end
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
App:Connect(UIS.JumpRequest, function()
    if S.Move.InfJump then
        local rec = localRec()
        if rec and rec.hum then rec.hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)
App:Add(function()
    destroyFly()
    local rec = localRec()
    if rec and rec.hum and MV.origWalk then pcall(function() rec.hum.WalkSpeed = MV.origWalk end) end
    for part, can in pairs(MV.nc) do
        if part.Parent then pcall(function() part.CanCollide = can end) end
    end
    for part, orig in pairs(MV.hx) do
        if part.Parent then pcall(function() part.Size = orig.Size; part.Transparency = orig.Transparency end) end
    end
    MV.nc = {}; MV.hx = {}; MV.ncOn = false; MV.origWalk = nil
end)

----------------------------------------------------------------
-- anti-aim
----------------------------------------------------------------
local AA = { rootJ=nil, neck=nil, origRoot=nil, origNeck=nil }
onChar(function(rec)
    if rec == localRec() then AA.rootJ, AA.neck, AA.origRoot, AA.origNeck = nil, nil, nil, nil end
end)
App:Connect(RS.Heartbeat, function(dt)
    local rec = localRec()
    if not rec or not rec.root then return end
    local root = rec.root
    if not AA.rootJ then
        AA.rootJ = root:FindFirstChild("RootJoint")
        if AA.rootJ then AA.origRoot = AA.rootJ.C0 end
    end
    if not AA.neck and rec.head then
        AA.neck = rec.head:FindFirstChild("Neck")
        if AA.neck then AA.origNeck = AA.neck.C0 end
    end
    local anyAA = S.AA.Jitter or S.AA.Desync or S.AA.HideHead
    if not anyAA then
        if AA.rootJ and AA.origRoot and AA.rootJ.C0 ~= AA.origRoot then AA.rootJ.C0 = AA.origRoot end
        if AA.neck and AA.origNeck and AA.neck.C0 ~= AA.origNeck then AA.neck.C0 = AA.origNeck end
        return
    end
    local total = 0
    if S.AA.Jitter then total = math.sin(tick() * 12) * math.rad(S.AA.JitterAngle) end
    local des = 0
    if S.AA.Desync then
        if S.AA.DesyncMode == "Spin"      then des = math.rad(tick() * 60)
        elseif S.AA.DesyncMode == "Static" then des = math.rad(60)
        else des = math.rad(180) end
    end
    if AA.rootJ and AA.origRoot then AA.rootJ.C0 = AA.origRoot * CFrame.Angles(0, total + des, 0) end
    if S.AA.HideHead and AA.neck and AA.origNeck then
        AA.neck.C0 = AA.origNeck * CFrame.Angles(0, math.rad(180), 0)
    elseif AA.neck and AA.origNeck and AA.neck.C0 ~= AA.origNeck then
        AA.neck.C0 = AA.origNeck
    end
    if S.AA.Spinbot then root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(25), 0) end
    if S.AA.FakeLag and not S.Move.Fly then
        if (tick() % 0.2) < 0.06 then
            pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
        end
    end
end)
App:Add(function()
    if AA.rootJ and AA.origRoot then pcall(function() AA.rootJ.C0 = AA.origRoot end) end
    if AA.neck and AA.origNeck then pcall(function() AA.neck.C0 = AA.origNeck end) end
end)
App:Connect(LP.Idled, function()
    if S.Misc.AntiAFK then
        pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
    end
end)

----------------------------------------------------------------
-- keybind display + watermark
----------------------------------------------------------------
local kdText, wmText = nil, nil
if CAP.drawing then
    local ok1, t1 = pcall(function() return Drawing.new("Text") end)
    if ok1 and t1 then
        kdText = t1; t1.Size=13; t1.Outline=true; t1.Visible=false
        App:Add(function() pcall(function() t1:Remove() end) end)
    end
    local ok2, t2 = pcall(function() return Drawing.new("Text") end)
    if ok2 and t2 then
        wmText = t2; t2.Size=13; t2.Outline=true; t2.Visible=false
        App:Add(function() pcall(function() t2:Remove() end) end)
    end
end

local function stateOf(path)
    return Get(path) and "[ON]" or "[OFF]"
end
local kdAcc = 0
App:Connect(RS.Heartbeat, function(dt)
    kdAcc += dt
    if kdAcc < 0.2 then return end
    kdAcc = 0
    if kdText and cam then
        kdText.Visible = S.Misc.KeybindDisplay
        if S.Misc.KeybindDisplay then
            local vp = cam.ViewportSize
            kdText.Position = Vector2.new(10, vp.Y * 0.5 - 100)
            kdText.Color = Color3.fromRGB(235, 235, 240)
            kdText.Text = string.format(
                "== KEYBINDS ==\n[%s] Aimbot   %s\n[%s] Silent   %s\n[%s] Trigger  %s\n[%s] AntiAim  %s\n[%s] ESP      %s",
                Get("Keys.Aimbot")  or "?", stateOf("Aimbot.Enabled"),
                Get("Keys.Silent")  or "?", stateOf("Aimbot.Silent"),
                Get("Keys.Trigger") or "?", stateOf("Trigger.Enabled"),
                Get("Keys.AA")      or "?", stateOf("AA.Jitter"),
                Get("Keys.ESP")     or "?", stateOf("ESP.Enabled")
            )
        end
    end
    if wmText then
        wmText.Visible = S.Misc.Watermark
        if S.Misc.Watermark then
            wmText.Text = string.format("unknown // fps %d // proj %d/s // ray %d/s",
                math.floor(Diag.fps), Diag.projRate, Diag.rayRate)
            wmText.Position = Vector2.new(10, 10)
            wmText.Color = Color3.fromRGB(235, 235, 240)
        end
    end
end)

----------------------------------------------------------------
-- UI: unknown (black, minimal)
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
gui.Name = "unk" .. math.random(100, 999)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
gui.Parent = guiParent

local function inst(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function corner(p, r) inst("UICorner", {CornerRadius = UDim.new(0, r or 8)}, p) end
local function stroke(p, c) inst("UIStroke", {Color = c or COL.stroke, Thickness = 1}, p) end

local main = inst("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(540, 440),
    BackgroundColor3 = COL.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
corner(main, 10); stroke(main)

local topbar = inst("Frame", {Size = UDim2.new(1,0,0,44), BackgroundColor3 = COL.panel, BorderSizePixel = 0}, main)
corner(topbar, 10)
inst("Frame", {Size = UDim2.new(1,0,0,10), Position = UDim2.new(0,0,1,-10), BackgroundColor3 = COL.panel, BorderSizePixel = 0}, topbar)
inst("Frame", {Size = UDim2.fromOffset(3, 14), Position = UDim2.fromOffset(12, 15), BackgroundColor3 = COL.accent, BorderSizePixel = 0}, topbar)
local title = inst("TextLabel", {
    Size = UDim2.fromOffset(160, 20), Position = UDim2.fromOffset(22, 12), BackgroundTransparency = 1,
    Text = "unknown", Font = Enum.Font.Code, TextSize = 16, TextColor3 = COL.text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, topbar)
inst("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(140,140,150))}, title)
inst("TextLabel", {
    Size = UDim2.fromOffset(140, 14), Position = UDim2.new(1, -150, 0.5, -7), BackgroundTransparency = 1,
    Text = "private // 2027", Font = Enum.Font.Code, TextSize = 10, TextColor3 = COL.muted,
    TextXAlignment = Enum.TextXAlignment.Right,
}, topbar)
local hideBtn = inst("TextButton", {
    Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -32, 0.5, -12),
    BackgroundColor3 = COL.elem, BorderSizePixel = 0, Text = "x",
    TextColor3 = COL.text, Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false,
}, topbar); corner(hideBtn, 6)
local minBtn = inst("TextButton", {
    Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -60, 0.5, -12),
    BackgroundColor3 = COL.elem, BorderSizePixel = 0, Text = "-",
    TextColor3 = COL.text, Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false,
}, topbar); corner(minBtn, 6)

local sidebar = inst("Frame", {
    Size = UDim2.new(0, 110, 1, -52), Position = UDim2.fromOffset(8, 48),
    BackgroundColor3 = COL.panel, BorderSizePixel = 0,
}, main); corner(sidebar, 8)
local tabList = inst("ScrollingFrame", {
    Size = UDim2.new(1,-8,1,-8), Position = UDim2.fromOffset(4,4),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
}, sidebar)
local tabLayout = inst("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, tabList)
tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    tabList.CanvasSize = UDim2.fromOffset(0, tabLayout.AbsoluteContentSize.Y + 4)
end)
local pages = inst("Frame", {
    Size = UDim2.new(1, -124, 1, -52), Position = UDim2.fromOffset(122, 48), BackgroundTransparency = 1,
}, main)

-- drag
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
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1,0,1,0),
        ScrollBarThickness = 3, ScrollBarImageColor3 = COL.stroke, Visible = false, CanvasSize = UDim2.new(),
    }, pages)
    local layout = inst("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, page)
    inst("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6)}, page)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 16)
    end)
    local btn = inst("TextButton", {
        Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = COL.panel, BorderSizePixel = 0,
        Text = name, TextColor3 = COL.muted, Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false,
    }, tabList); corner(btn, 6)
    local rec = { name = name, page = page, btn = btn }
    table.insert(tabs, rec)
    btn.MouseButton1Click:Connect(function() selectTab(rec) end)
    if not selectedTab then selectTab(rec) end
    local tab = {}
    local order = 0
    local function row(h)
        order = order + 1
        local f = inst("Frame", {
            Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = COL.elem, BorderSizePixel = 0, LayoutOrder = order,
        }, page); corner(f, 7); stroke(f)
        return f
    end
    local function rtitle(f, t)
        return inst("TextLabel", {
            Size = UDim2.new(0.6, -12, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1,
            Text = t, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.text, Font = Enum.Font.Gotham, TextSize = 13,
        }, f)
    end
    local function click(f, cb)
        local o = inst("TextButton", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5,
        }, f)
        o.MouseButton1Click:Connect(function() pcall(cb) end)
        return o
    end
    function tab:Section(t)
        order = order + 1
        inst("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = t,
            TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.muted,
            Font = Enum.Font.GothamSemibold, TextSize = 11, LayoutOrder = order,
        }, page)
    end
    function tab:Toggle(name, path)
        local f = row(28)
        rtitle(f, name)
        local sw = inst("Frame", {
            Size = UDim2.fromOffset(34, 16), Position = UDim2.new(1, -42, 0.5, -8),
            BackgroundColor3 = COL.bg, BorderSizePixel = 0,
        }, f); corner(sw, 8); stroke(sw)
        local ind = inst("Frame", {
            Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = COL.off, BorderSizePixel = 0,
        }, sw); corner(ind, 5)
        local function paint(v)
            ind.BackgroundColor3 = v and COL.accent or COL.off
            ind.Position = UDim2.new(v and 1 or 0, v and -13 or 3, 0.5, 0)
        end
        uiref(path, paint); paint(Get(path))
        click(f, function() Set(path, not Get(path)) end)
    end
    function tab:Slider(name, path, min, max, step, suffix)
        local f = row(40); rtitle(f, name)
        local info = inst("TextLabel", {
            Size = UDim2.fromOffset(80, 14), Position = UDim2.new(1, -90, 0, 4),
            BackgroundTransparency = 1, TextColor3 = COL.text, Font = Enum.Font.Gotham,
            TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right,
        }, f)
        local track = inst("Frame", {
            Size = UDim2.new(1, -20, 0, 4), Position = UDim2.fromOffset(10, 28),
            BackgroundColor3 = COL.off, BorderSizePixel = 0,
        }, f); corner(track, 2)
        local fill = inst("Frame", {
            Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = COL.accent, BorderSizePixel = 0,
        }, track); corner(fill, 2)
        local function paint(v)
            local r = (max > min) and ((v - min) / (max - min)) or 0
            fill.Size = UDim2.new(math.clamp(r, 0, 1), 0, 1, 0)
            info.Text = tostring(v) .. (suffix or "")
        end
        uiref(path, paint); paint(Get(path))
        local drag = false
        local function fromX(x)
            local w = math.max(track.AbsoluteSize.X, 1)
            local r = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
            local v = min + (max - min) * r
            v = math.floor(v / step + 0.5) * step
            Set(path, v)
        end
        track.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; fromX(i.Position.X) end end)
        UIS.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then fromX(i.Position.X) end end)
        UIS.InputEnded:Connect(function() drag = false end)
    end
    function tab:Dropdown(name, path, options)
        local f = row(30); rtitle(f, name)
        local sel = inst("TextLabel", {
            Size = UDim2.new(0.34, -20, 1, 0), Position = UDim2.new(0.66, -14, 0, 0),
            BackgroundTransparency = 1, Text = tostring(Get(path)), TextColor3 = COL.muted,
            Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
        }, f)
        local list = inst("Frame", {
            Size = UDim2.new(1, -8, 0, 0), Position = UDim2.new(0, 4, 1, 2),
            BackgroundColor3 = COL.panel, BorderSizePixel = 0, ClipsDescendants = true,
            Visible = false, ZIndex = 30,
        }, f); corner(list, 7); stroke(list)
        inst("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, list)
        local open = false
        for _, opt in ipairs(options) do
            local ob = inst("TextButton", {
                Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = COL.elem, BorderSizePixel = 0,
                Text = "  " .. opt, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.text,
                Font = Enum.Font.Gotham, TextSize = 12, AutoButtonColor = false, ZIndex = 31,
            }, list); corner(ob, 5)
            ob.MouseButton1Click:Connect(function()
                Set(path, opt); sel.Text = opt; open = false; list.Visible = false
            end)
        end
        uiref(path, function(v) sel.Text = tostring(v) end)
        click(f, function()
            open = not open; list.Visible = open
            if open then list.Size = UDim2.new(1, -8, 0, #options * 27 + 8) end
        end)
    end
    function tab:Keybind(name, path)
        local f = row(28); rtitle(f, name)
        local kb = inst("TextButton", {
            Size = UDim2.fromOffset(76, 20), Position = UDim2.new(1, -84, 0.5, -10),
            BackgroundColor3 = COL.panel, BorderSizePixel = 0, Text = tostring(Get(path)),
            TextColor3 = COL.text, Font = Enum.Font.Gotham, TextSize = 11, AutoButtonColor = false,
        }, f); corner(kb, 5); stroke(kb)
        kb.MouseButton1Click:Connect(function() capturing = path; kb.Text = "press" end)
        uiref(path, function(v) kb.Text = tostring(v) end)
    end
    function tab:Button(name, cb)
        local f = row(28); rtitle(f, name)
        click(f, cb)
    end
    function tab:Label(t)
        local f = row(24)
        local l = rtitle(f, t); l.Size = UDim2.new(1, -14, 1, 0); l.TextColor3 = COL.muted
        return { Set = function(_, v) l.Text = tostring(v) end }
    end
    return tab
end

-- tabs content
local tCombat = addTab("combat")
tCombat:Section("aimbot")
tCombat:Toggle("Aimbot",        "Aimbot.Enabled")
tCombat:Toggle("Silent aim",    "Aimbot.Silent")
tCombat:Toggle("Target lock",   "Aimbot.TargetLock")
tCombat:Toggle("Wall check",    "Aimbot.WallCheck")
tCombat:Toggle("Only enemies",  "Aimbot.OnlyEnemies")
tCombat:Toggle("FOV circle",    "Aimbot.ShowFOV")
tCombat:Slider("FOV",           "Aimbot.FOV", 20, 800, 10)
tCombat:Slider("Smoothing",     "Aimbot.Smoothing", 0.01, 1.0, 0.01)
tCombat:Slider("Prediction",    "Aimbot.Prediction", 0, 0.5, 0.01)
tCombat:Keybind("Aimbot key",   "Keys.Aimbot")
tCombat:Keybind("Silent key",   "Keys.Silent")
tCombat:Keybind("Lock target",  "Keys.Lock")
tCombat:Section("triggerbot")
tCombat:Toggle("TriggerBot",    "Trigger.Enabled")
tCombat:Toggle("Only enemies",  "Trigger.OnlyEnemies")
tCombat:Toggle("Wall check",    "Trigger.WallCheck")
tCombat:Slider("Delay (s)",     "Trigger.Delay", 0, 0.5, 0.01)
tCombat:Keybind("Trigger key",  "Keys.Trigger")

local tVis = addTab("visuals")
tVis:Section("esp")
tVis:Toggle("ESP",        "ESP.Enabled")
tVis:Toggle("Boxes",      "ESP.Boxes")
tVis:Toggle("Health bar", "ESP.HealthBar")
tVis:Toggle("Snaplines",  "ESP.Snaplines")
tVis:Toggle("Names",      "ESP.Names")
tVis:Toggle("Distance",   "ESP.Distance")
tVis:Toggle("Chams",      "ESP.Chams")
tVis:Toggle("Only enemies","ESP.OnlyEnemies")
tVis:Slider("Max distance","ESP.MaxDistance", 50, 2000, 50)
tVis:Keybind("ESP key",   "Keys.ESP")

local tMove = addTab("move")
tMove:Section("speed")
tMove:Toggle("Speed",   "Move.Speed")
tMove:Dropdown("Mode",  "Move.SpeedMode", {"Walk", "Vel"})
tMove:Slider("Value",   "Move.SpeedValue", 16, 200, 1)
tMove:Keybind("Speed key","Keys.Speed")
tMove:Section("fly")
tMove:Toggle("Fly",     "Move.Fly")
tMove:Slider("Fly speed","Move.FlyValue", 20, 200, 5)
tMove:Keybind("Fly key","Keys.Fly")
tMove:Section("other")
tMove:Toggle("NoClip",    "Move.NoClip")
tMove:Toggle("Inf jump",  "Move.InfJump")
tMove:Toggle("Hitbox",    "Move.Hitbox")
tMove:Slider("Hitbox size","Move.HitboxSize", 3, 25, 1)

local tAA = addTab("antiaim")
tAA:Section("angles")
tAA:Toggle("Jitter",      "AA.Jitter")
tAA:Slider("Jitter angle","AA.JitterAngle", 10, 180, 5)
tAA:Toggle("Desync",      "AA.Desync")
tAA:Dropdown("Desync mode","AA.DesyncMode", {"Spin", "Static", "Backwards"})
tAA:Toggle("Hide head",   "AA.HideHead")
tAA:Section("misc")
tAA:Toggle("Fake lag",    "AA.FakeLag")
tAA:Toggle("Spinbot",     "AA.Spinbot")
tAA:Keybind("AA key",     "Keys.AA")

local tMisc = addTab("misc")
tMisc:Section("general")
tMisc:Toggle("Watermark",         "Misc.Watermark")
tMisc:Toggle("Keybind display",   "Misc.KeybindDisplay")
tMisc:Toggle("Anti-AFK",          "Misc.AntiAFK")
tMisc:Keybind("UI key",           "Keys.UI")
tMisc:Button("save config",       function() saveConfig() end)
tMisc:Button("unload",            function() Unload() end)

-- minimize
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    sidebar.Visible = not minimized
    pages.Visible = not minimized
    main.Size = minimized and UDim2.fromOffset(540, 44) or UDim2.fromOffset(540, 440)
end)
hideBtn.MouseButton1Click:Connect(function() main.Visible = false end)

----------------------------------------------------------------
-- global input: UI + feature toggles + lock
----------------------------------------------------------------
App:Connect(UIS.InputBegan, function(input, processed)
    if capturing then
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            Set(capturing, input.KeyCode.Name)
        end
        capturing = nil
        return
    end
    if processed then return end
    local kc = input.KeyCode.Name
    if kc == Get("Keys.UI")      then main.Visible = not main.Visible; return end
    if kc == Get("Keys.Aimbot") and Get("Keys.Aimbot") ~= "" then Set("Aimbot.Enabled",  not Get("Aimbot.Enabled")) end
    if kc == Get("Keys.Silent") and Get("Keys.Silent") ~= "" then Set("Aimbot.Silent",   not Get("Aimbot.Silent")) end
    if kc == Get("Keys.Fly")    and Get("Keys.Fly")    ~= "" then Set("Move.Fly",        not Get("Move.Fly")) end
    if kc == Get("Keys.Speed")  and Get("Keys.Speed")  ~= "" then Set("Move.Speed",      not Get("Move.Speed")) end
    if kc == Get("Keys.Trigger")and Get("Keys.Trigger")~= "" then Set("Trigger.Enabled", not Get("Trigger.Enabled")) end
    if kc == Get("Keys.ESP")    and Get("Keys.ESP")    ~= "" then Set("ESP.Enabled",     not Get("ESP.Enabled")) end
    if kc == Get("Keys.AA")     and Get("Keys.AA")     ~= "" then
        -- AA has multiple flags; toggle the bundle
        local newState = not Get("AA.Jitter")
        Set("AA.Jitter", newState)
        Set("AA.Desync", newState)
    end
    if kc == Get("Keys.Lock")   and Get("Keys.Lock")   ~= "" then
        AIM.locked = not AIM.locked
        if not AIM.locked then AIM.current = nil end
    end
end)

-- lock state watcher: clear current when aimbot off
watch("Aimbot.Enabled", function(v)
    if not v then AIM.current = nil; AIM.locked = false end
end)
watch("Aimbot.TargetLock", function(v)
    if not v then AIM.locked = false end
end)

----------------------------------------------------------------
-- unload
----------------------------------------------------------------
function Unload()
    for _, s in ipairs(scopes) do s:Destroy() end
    table.clear(scopes)
    ENV.__ABYSS = nil
end
ENV.__ABYSS = { Unload = Unload }
print("[unknown] ready // safe inject: all features OFF")
