--[[ abyss.lua — single-file client framework ]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
if not RunService:IsClient() or not LocalPlayer then return end

----------------------------------------------------------------
-- capabilities
----------------------------------------------------------------
local CAP = {
	drawing = type(Drawing) == "table" and type(Drawing.new) == "function",
	fs = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function" and type(makefolder) == "function" and type(isfolder) == "function",
	hook = type(getrawmetatable) == "function" and type(setreadonly) == "function" and type(newcclosure) == "function" and type(getnamecallmethod) == "function",
	gethui = type(gethui) == "function",
	protectgui = type(syn) == "table" and type(syn.protect_gui) == "function",
}

----------------------------------------------------------------
-- repeated execution: unload previous instance
----------------------------------------------------------------
local ENV = (type(getgenv) == "function" and getgenv()) or _G
if type(ENV.__ABYSS) == "table" and type(ENV.__ABYSS.Unload) == "function" then
	pcall(ENV.__ABYSS.Unload)
end
ENV.__ABYSS = nil

----------------------------------------------------------------
-- error reporting (not silent)
----------------------------------------------------------------
local errCount = {}
local function protect(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		errCount[label] = (errCount[label] or 0) + 1
		if errCount[label] <= 3 then
			warn("[abyss][" .. label .. "] " .. tostring(err))
		end
	end
	return ok
end

----------------------------------------------------------------
-- scopes: ownership of connections / instances / renders / fns
----------------------------------------------------------------
local scopes = {}
local function newScope(name)
	local s = { name = name, alive = true, conns = {}, insts = {}, fns = {}, renders = {} }
	function s:Connect(sig, fn)
		if not self.alive then return nil end
		local c = sig:Connect(fn)
		self.conns[#self.conns + 1] = c
		return c
	end
	function s:Give(inst)
		if not self.alive then pcall(function() inst:Destroy() end) return inst end
		self.insts[#self.insts + 1] = inst
		return inst
	end
	function s:Add(fn)
		if not self.alive then pcall(fn) return end
		self.fns[#self.fns + 1] = fn
	end
	function s:BindRender(key, prio, fn)
		if not self.alive then return end
		local nm = "Abyss_" .. key
		self.renders[#self.renders + 1] = nm
		RunService:BindToRenderStep(nm, prio, function(dt)
			if self.alive then protect("render:" .. key, fn, dt) end
		end)
	end
	function s:Destroy()
		if not self.alive then return end
		self.alive = false
		for _, c in ipairs(self.conns) do pcall(function() c:Disconnect() end) end
		for _, nm in ipairs(self.renders) do pcall(function() RunService:UnbindFromRenderStep(nm) end) end
		for i = #self.fns, 1, -1 do pcall(self.fns[i]) end
		for _, inst in ipairs(self.insts) do pcall(function() inst:Destroy() end) end
		table.clear(self.conns); table.clear(self.insts); table.clear(self.fns); table.clear(self.renders)
	end
	scopes[#scopes + 1] = s
	return s
end
local App = newScope("app")

----------------------------------------------------------------
-- diagnostics
----------------------------------------------------------------
local Diag = {
	proj = 0, ray = 0, projRate = 0, rayRate = 0, fps = 60,
	drawings = 0, cpu = { aim = 0, esp = 0, move = 0, aa = 0 },
	cpuRate = { aim = 0, esp = 0, move = 0, aa = 0 },
}
local function timed(key, fn, ...)
	local t0 = os.clock()
	fn(...)
	Diag.cpu[key] = Diag.cpu[key] + (os.clock() - t0)
end

----------------------------------------------------------------
-- settings + schema
----------------------------------------------------------------
local SCH = {
	Aimbot = {
		Enabled = { t = "bool", d = false },
		Silent = { t = "bool", d = false },
		OnlyEnemies = { t = "bool", d = true },
		WallCheck = { t = "bool", d = true },
		ShowFOV = { t = "bool", d = true },
		FOV = { t = "num", d = 120, min = 10, max = 600 },
		Smoothing = { t = "num", d = 4, min = 0.5, max = 20 },
		Prediction = { t = "num", d = 0.12, min = 0, max = 0.5 },
	},
	ESP = {
		Enabled = { t = "bool", d = false },
		Boxes = { t = "bool", d = true },
		HealthBar = { t = "bool", d = true },
		Snaplines = { t = "bool", d = false },
		Names = { t = "bool", d = false },
		Distance = { t = "bool", d = false },
		Chams = { t = "bool", d = false },
		OnlyEnemies = { t = "bool", d = true },
		MaxDistance = { t = "num", d = 500, min = 50, max = 2000 },
	},
	Move = {
		Speed = { t = "bool", d = false },
		SpeedMode = { t = "enum", d = "Walk", enum = { Walk = true, Vel = true } },
		SpeedValue = { t = "num", d = 50, min = 16, max = 200 },
		Fly = { t = "bool", d = false },
		FlyValue = { t = "num", d = 60, min = 20, max = 200 },
		NoClip = { t = "bool", d = false },
		InfJump = { t = "bool", d = false },
		Hitbox = { t = "bool", d = false },
		HitboxSize = { t = "num", d = 12, min = 3, max = 25 },
	},
	AA = {
		Jitter = { t = "bool", d = false },
		JitterAngle = { t = "num", d = 40, min = 10, max = 180 },
		Desync = { t = "bool", d = false },
		DesyncMode = { t = "enum", d = "Spin", enum = { Spin = true, Static = true, Backwards = true } },
		HideHead = { t = "bool", d = false },
		FakeLag = { t = "bool", d = false },
		Spinbot = { t = "bool", d = false },
	},
	Misc = {
		Watermark = { t = "bool", d = true },
		AntiAFK = { t = "bool", d = true },
	},
	Keys = {
		UI = { t = "key", d = "RightShift" },
		Aimbot = { t = "key", d = "" },
		Fly = { t = "key", d = "" },
		Speed = { t = "key", d = "" },
	},
}
local S = {}
for g, keys in pairs(SCH) do
	S[g] = {}
	for k, spec in pairs(keys) do S[g][k] = spec.d end
end
if not CAP.drawing then S.ESP.Enabled = false end
if not CAP.hook then S.Aimbot.Silent = false end

local watchers = {}
local function watch(path, fn) watchers[path] = watchers[path] or {}; table.insert(watchers[path], fn) end
local saveQueued = false
local CFGDIR, CFGFILE = "AbyssFW", "AbyssFW/config.json"

local function sanitize(spec, v)
	if spec.t == "bool" then return v == true end
	if spec.t == "num" then
		local n = tonumber(v)
		if n == nil then return nil end
		return math.clamp(n, spec.min, spec.max)
	end
	if spec.t == "enum" then return spec.enum[v] and v or nil end
	if spec.t == "key" then
		if type(v) ~= "string" then return nil end
		if v ~= "" and not Enum.KeyCode[v] then return nil end
		return v
	end
	return nil
end
local function Get(path)
	local g, k = path:match("^(%w+)%.(%w+)$")
	return S[g] and S[g][k]
end
local function Set(path, value, skipSave)
	local g, k = path:match("^(%w+)%.(%w+)$")
	local spec = SCH[g] and SCH[g][k]
	if not spec then return false end
	local v = sanitize(spec, value)
	if v == nil then return false end
	S[g][k] = v
	local wl = watchers[path]
	if wl then for _, fn in ipairs(wl) do protect("watch:" .. path, fn, v) end end
	if not skipSave then queueSave() end
	return true
end
function queueSave()
	if saveQueued or not CAP.fs then return end
	saveQueued = true
	task.delay(0.6, function()
		saveQueued = false
		if not App.alive then return end
		protect("config.save", saveConfig)
	end)
end
function fsWrite(path, text)
	local ok = pcall(writefile, path, text)
	if not ok then return false end
	local ok2, back = pcall(readfile, path)
	return ok2 and back == text
end
function saveConfig()
	if not CAP.fs then return false end
	pcall(function() if not isfolder(CFGDIR) then makefolder(CFGDIR) end end)
	local ok, enc = pcall(function() return HttpService:JSONEncode(S) end)
	if not ok or type(enc) ~= "string" then return false end
	return fsWrite(CFGFILE, enc)
end
local function loadConfig()
	if not CAP.fs then return false end
	if not isfile(CFGFILE) then return false end
	local ok, txt = pcall(readfile, CFGFILE)
	if not ok or type(txt) ~= "string" then return false end
	local ok2, data = pcall(function() return HttpService:JSONDecode(txt) end)
	if not ok2 or type(data) ~= "table" then return false end
	for g, keys in pairs(SCH) do
		if type(data[g]) == "table" then
			for k, spec in pairs(keys) do
				local v = sanitize(spec, data[g][k])
				if v ~= nil then S[g][k] = v end
			end
		end
	end
	if not CAP.drawing then S.ESP.Enabled = false end
	if not CAP.hook then S.Aimbot.Silent = false end
	return true
end

----------------------------------------------------------------
-- notifications (created after UI; forward decl)
----------------------------------------------------------------
local NotifyFn = nil
local function Notify(t, c) if NotifyFn then NotifyFn(t, c) end end

----------------------------------------------------------------
-- player cache (event driven, generation safe)
----------------------------------------------------------------
local Cache = { byPlayer = {} }
local charListeners, leaveListeners = {}, {}
local function onCharacter(fn) table.insert(charListeners, fn) end
local function onLeave(fn) table.insert(leaveListeners, fn) end
local currentCamera = Workspace.CurrentCamera
App:Connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
	currentCamera = Workspace.CurrentCamera
end)
local localRec = nil
local function recomputeEnemy(rec)
	if rec.plr == LocalPlayer then rec.enemy = false; return end
	local m, t = LocalPlayer.Team, rec.plr.Team
	if not m or not t then rec.enemy = true; return end
	if LocalPlayer.Neutral or rec.plr.Neutral then rec.enemy = true; return end
	rec.enemy = (t ~= m)
end
local function recomputeAll()
	for _, rec in pairs(Cache.byPlayer) do recomputeEnemy(rec) end
end
local function fireChar(rec, char, gen)
	for _, fn in ipairs(charListeners) do protect("charListener", fn, rec, char, gen) end
end
local function fireLeave(rec, char)
	for _, fn in ipairs(leaveListeners) do protect("leaveListener", fn, rec, char) end
end
local function onCharAdded(rec, char)
	if rec.charScope then rec.charScope:Destroy() end
	rec.gen = (rec.gen or 0) + 1
	local gen = rec.gen
	rec.char = char
	rec.charScope = newScope("char:" .. rec.plr.Name .. ":" .. gen)
	rec.hum = char:FindFirstChildOfClass("Humanoid")
	rec.root = char:FindFirstChild("HumanoidRootPart")
	rec.head = char:FindFirstChild("Head")
	rec.rig = (rec.hum and rec.hum.RigType == Enum.HumanoidRigType.R15) and "R15" or "R6"
	rec.alive = rec.hum ~= nil and rec.hum.Health > 0
	if rec.hum then
		rec.charScope:Connect(rec.hum.Died, function() rec.alive = false end)
		rec.charScope:Connect(rec.hum:GetPropertyChangedSignal("Health"), function()
			rec.alive = rec.hum.Health > 0
		end)
	end
	recomputeEnemy(rec)
	fireChar(rec, char, gen)
end
local function onCharRemoving(rec, char)
	if rec.char ~= char then return end
	rec.alive = false
	rec.char = nil; rec.hum = nil; rec.root = nil; rec.head = nil
	if rec.charScope then rec.charScope:Destroy(); rec.charScope = nil end
	fireLeave(rec, char)
end
local function wirePlayer(plr)
	local rec = { plr = plr, gen = 0, charScope = nil }
	rec.pscope = newScope("player:" .. plr.Name)
	Cache.byPlayer[plr] = rec
	rec.pscope:Connect(plr.CharacterAdded, function(char) onCharAdded(rec, char) end)
	rec.pscope:Connect(plr.CharacterRemoving, function(char) onCharRemoving(rec, char) end)
	rec.pscope:Connect(plr:GetPropertyChangedSignal("Team"), recomputeAll)
	rec.pscope:Connect(plr:GetPropertyChangedSignal("Neutral"), recomputeAll)
	if plr == LocalPlayer then
		localRec = rec
		rec.pscope:Connect(plr:GetPropertyChangedSignal("Team"), recomputeAll)
	end
	if plr.Character then onCharAdded(rec, plr.Character) end
end
local function unwirePlayer(plr)
	local rec = Cache.byPlayer[plr]
	if not rec then return end
	if rec.char then fireLeave(rec, rec.char) end
	if rec.pscope then rec.pscope:Destroy() end
	if rec.charScope then rec.charScope:Destroy() end
	Cache.byPlayer[plr] = nil
end
for _, plr in ipairs(Players:GetPlayers()) do wirePlayer(plr) end
App:Connect(Players.PlayerAdded, wirePlayer)
App:Connect(Players.PlayerRemoving, unwirePlayer)
recomputeAll()

----------------------------------------------------------------
-- visibility raycast (shared params)
----------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local internalRay = false
local function isVisible(pos, targetChar)
	if not currentCamera then return true end
	local ignore = { currentCamera }
	if localRec and localRec.char then table.insert(ignore, localRec.char) end
	rayParams.FilterDescendantsInstances = ignore
	local origin = currentCamera.CFrame.Position
	local dir = pos - origin
	if dir.Magnitude < 0.05 then return true end
	Diag.ray = Diag.ray + 1
	internalRay = true
	local ok, hit = pcall(Workspace.Raycast, Workspace, origin, dir, rayParams)
	internalRay = false
	if not ok then return true end
	if not hit then return true end
	if targetChar and hit.Instance:IsDescendantOf(targetChar) then return true end
	return false
end

----------------------------------------------------------------
-- drawing pool
----------------------------------------------------------------
local Pool = { free = { Square = {}, Line = {}, Text = {} }, count = 0 }
local function acquire(kind)
	if not CAP.drawing then return nil end
	local list = Pool.free[kind]
	local o = table.remove(list)
	if not o then
		local ok, d = pcall(Drawing.new, kind)
		if not ok then return nil end
		o = d
		Pool.count = Pool.count + 1
	end
	o.Visible = false
	return o
end
local function release(o, kind)
	if not o then return end
	pcall(function() o.Visible = false end)
	table.insert(Pool.free[kind], o)
end
local function releaseRecViz(rec)
	local v = rec.viz
	if not v then return end
	release(v.box, "Square"); release(v.hpBg, "Square"); release(v.hpFill, "Square")
	release(v.snap, "Line"); release(v.name, "Text"); release(v.dist, "Text")
	if v.chams then pcall(function() v.chams:Destroy() end) end
	rec.viz = nil
end
onLeave(releaseRecViz)
onCharacter(function(rec) releaseRecViz(rec) end)
App:Add(function()
	for _, rec in pairs(Cache.byPlayer) do releaseRecViz(rec) end
	for _, list in pairs(Pool.free) do
		for _, o in ipairs(list) do pcall(function() o:Remove() end) end
	end
	Pool.count = 0
end)

----------------------------------------------------------------
-- ESP (scheduled 30Hz)
----------------------------------------------------------------
local espAcc = 0
local function espUpdate()
	local enabled = Get("ESP.Enabled")
	for _, rec in pairs(Cache.byPlayer) do
		if rec.plr ~= LocalPlayer then
			if not enabled then
				releaseRecViz(rec)
			else
				protect("esp.rec", espRecord, rec)
			end
		end
	end
end
function espRecord(rec)
	local v = rec.viz or {}
	rec.viz = v
	if not rec.alive or not rec.root then releaseRecViz(rec); return end
	if Get("ESP.OnlyEnemies") and not rec.enemy then releaseRecViz(rec); return end
	local dist = (rec.root.Position - (currentCamera and currentCamera.CFrame.Position or Vector3.zero)).Magnitude
	if dist > Get("ESP.MaxDistance") then releaseRecViz(rec); return end
	local headPos = (rec.head and rec.head.Position) or (rec.root.Position + Vector3.new(0, 2.5, 0))
	local legPos = rec.root.Position - Vector3.new(0, 2.5, 0)
	local hSp = currentCamera:WorldToViewportPoint(headPos); Diag.proj = Diag.proj + 1
	local lSp = currentCamera:WorldToViewportPoint(legPos); Diag.proj = Diag.proj + 1
	if hSp.Z < 0 and lSp.Z < 0 then releaseRecViz(rec); return end
	local height = math.abs(lSp.Y - hSp.Y)
	local width = height * 0.5
	local x = hSp.X - width * 0.5
	local y = hSp.Y
	local color = rec.enemy and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(60, 140, 255)
	if Get("ESP.Boxes") then
		v.box = v.box or acquire("Square")
		if v.box then
			v.box.Filled = false; v.box.Thickness = 1; v.box.Color = color
			v.box.Size = Vector2.new(width, height); v.box.Position = Vector2.new(x, y)
			v.box.Visible = true
		end
	else release(v.box, "Square"); v.box = nil end
	if Get("ESP.HealthBar") and rec.hum and rec.hum.MaxHealth > 0 then
		v.hpBg = v.hpBg or acquire("Square"); v.hpFill = v.hpFill or acquire("Square")
		local pct = math.clamp(rec.hum.Health / rec.hum.MaxHealth, 0, 1)
		if v.hpBg then
			v.hpBg.Filled = true; v.hpBg.Color = Color3.fromRGB(0, 0, 0)
			v.hpBg.Size = Vector2.new(3, height); v.hpBg.Position = Vector2.new(x - 5, y)
			v.hpBg.Visible = true
		end
		if v.hpFill then
			local bh = height * pct
			v.hpFill.Filled = true
			v.hpFill.Color = Color3.fromRGB(60, 220, 60):Lerp(Color3.fromRGB(220, 60, 60), 1 - pct)
			v.hpFill.Size = Vector2.new(3, bh); v.hpFill.Position = Vector2.new(x - 5, y + (height - bh))
			v.hpFill.Visible = true
		end
	else release(v.hpBg, "Square"); v.hpBg = nil; release(v.hpFill, "Square"); v.hpFill = nil end
	if Get("ESP.Snaplines") then
		v.snap = v.snap or acquire("Line")
		if v.snap then
			local vp = currentCamera.ViewportSize
			v.snap.Thickness = 1; v.snap.Color = color
			v.snap.From = Vector2.new(vp.X * 0.5, vp.Y)
			v.snap.To = Vector2.new(hSp.X, hSp.Y)
			v.snap.Visible = true
		end
	else release(v.snap, "Line"); v.snap = nil end
	if Get("ESP.Names") then
		v.name = v.name or acquire("Text")
		if v.name then
			v.name.Size = 13; v.name.Center = true; v.name.Outline = true; v.name.Color = color
			v.name.Text = (rec.plr.DisplayName ~= "" and rec.plr.DisplayName) or rec.plr.Name
			v.name.Position = Vector2.new(hSp.X, y - 16)
			v.name.Visible = true
		end
	else release(v.name, "Text"); v.name = nil end
	if Get("ESP.Distance") then
		v.dist = v.dist or acquire("Text")
		if v.dist then
			v.dist.Size = 12; v.dist.Center = true; v.dist.Outline = true
			v.dist.Color = Color3.fromRGB(255, 255, 255)
			v.dist.Text = tostring(math.floor(dist)) .. "m"
			v.dist.Position = Vector2.new(hSp.X, y + height + 4)
			v.dist.Visible = true
		end
	else release(v.dist, "Text"); v.dist = nil end
	if Get("ESP.Chams") then
		if not v.chams or v.chams.Parent ~= rec.char then
			if v.chams then pcall(function() v.chams:Destroy() end) end
			local h = Instance.new("Highlight")
			h.FillColor = color; h.OutlineColor = Color3.fromRGB(255, 255, 255)
			h.FillTransparency = 0.4; h.OutlineTransparency = 0.2
			pcall(function() h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
			h.Adornee = rec.char; h.Parent = rec.char
			v.chams = h
		else
			v.chams.FillColor = color; v.chams.Enabled = true
		end
	elseif v.chams then pcall(function() v.chams:Destroy() end); v.chams = nil end
	Diag.drawings = Pool.count
end

----------------------------------------------------------------
-- aimbot (frame synchronous) + silent hook
----------------------------------------------------------------
local lastTarget = nil
local function pickPart(rec)
	if rec.rig == "R15" then
		return rec.head or rec.char and rec.char:FindFirstChild("UpperTorso") or rec.root
	end
	return rec.head or rec.char and rec.char:FindFirstChild("Torso") or rec.root
end
local function bestTarget()
	if not currentCamera or not localRec or not localRec.alive then return nil end
	local vp = currentCamera.ViewportSize
	local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
	local fov = Get("Aimbot.FOV")
	local best, bd = nil, fov
	for _, rec in pairs(Cache.byPlayer) do
		if rec ~= localRec and rec.alive and rec.root then
			if not Get("Aimbot.OnlyEnemies") or rec.enemy then
				local part = pickPart(rec)
				if part then
					local pos = part.Position
					local pred = Get("Aimbot.Prediction")
					if pred > 0 then
						local vel = part.AssemblyLinearVelocity
						if vel.Magnitude > 500 then vel = vel.Unit * 500 end
						pos = pos + vel * pred
					end
					local sp, on = currentCamera:WorldToViewportPoint(pos)
					Diag.proj = Diag.proj + 1
					if on and sp.Z > 0 then
						local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
						if d < bd then bd = d; best = { rec = rec, part = part, pos = pos } end
					end
				end
			end
		end
	end
	if best and Get("Aimbot.WallCheck") then
		if not isVisible(best.pos, best.rec.char) then best = nil end
	end
	return best
end
local fovCircle = nil
if CAP.drawing then
	local ok, c = pcall(Drawing.new, "Circle")
	if ok then
		fovCircle = c
		fovCircle.Thickness = 2; fovCircle.NumSides = 48; fovCircle.Filled = false
		fovCircle.Color = Color3.fromRGB(0, 255, 100); fovCircle.Visible = false
	end
	App:Add(function() if fovCircle then pcall(function() fovCircle:Remove() end) end end)
end
local function aimUpdate(dt)
	if fovCircle then
		if Get("Aimbot.Enabled") and Get("Aimbot.ShowFOV") and currentCamera then
			local vp = currentCamera.ViewportSize
			fovCircle.Position = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
			fovCircle.Radius = Get("Aimbot.FOV")
			fovCircle.Visible = true
		else
			fovCircle.Visible = false
		end
	end
	local t = nil
	if Get("Aimbot.Enabled") or Get("Aimbot.Silent") then
		t = bestTarget()
	end
	lastTarget = t
	if Get("Aimbot.Enabled") and t and currentCamera then
		local cam = currentCamera.CFrame
		local desired = CFrame.lookAt(cam.Position, t.pos)
		local sm = math.max(Get("Aimbot.Smoothing"), 0.001)
		local alpha = math.clamp(1 - math.exp(-(dt or 1 / 60) * (60 / sm)), 0, 1)
		currentCamera.CFrame = cam:Lerp(desired, alpha)
	end
end
App:BindRender("aim", Enum.RenderPriority.Camera.Value - 1, function(dt)
	Diag.fps = Diag.fps + ((1 / math.max(dt, 0.0001)) - Diag.fps) * 0.05
	timed("aim", aimUpdate, dt)
end)
-- silent aim hook
local hookInstalled, origNamecall, gameMt = false, nil, nil
local function silentHookBody(self, ...)
	if internalRay or not Get("Aimbot.Silent") then return origNamecall(self, ...) end
	if self ~= Workspace then return origNamecall(self, ...) end
	local method = getnamecallmethod()
	local isRay = (method == "Raycast")
	local isLegacy = (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList")
	if not isRay and not isLegacy then return origNamecall(self, ...) end
	local origin, direction
	if isRay then
		origin, direction = select(1, ...), select(2, ...)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return origNamecall(self, ...) end
	else
		local r = select(1, ...)
		if typeof(r) ~= "Ray" then return origNamecall(self, ...) end
		origin, direction = r.Origin, r.Direction
	end
	if direction.Magnitude < 0.5 then return origNamecall(self, ...) end
	local lr = localRec and localRec.root
	if not lr or (origin - lr.Position).Magnitude > 60 then return origNamecall(self, ...) end
	local t = lastTarget
	if not t or not t.rec.alive or not t.part or not t.part.Parent then return origNamecall(self, ...) end
	local diff = t.pos - origin
	if diff.Magnitude < 0.5 then return origNamecall(self, ...) end
	local newDir = diff.Unit * direction.Magnitude
	if isRay then
		local args = { ... }
		args[2] = newDir
		return origNamecall(self, table.unpack(args))
	else
		local args = { ... }
		args[1] = Ray.new(origin, newDir)
		return origNamecall(self, table.unpack(args))
	end
end
if CAP.hook then
	local ok, mt = pcall(getrawmetatable, game)
	if ok and mt then
		gameMt = mt
		origNamecall = mt.__namecall
		pcall(setreadonly, mt, false)
		mt.__namecall = newcclosure(silentHookBody)
		pcall(setreadonly, mt, true)
		hookInstalled = true
		App:Add(function()
			if hookInstalled and gameMt and origNamecall then
				pcall(setreadonly, gameMt, false)
				gameMt.__namecall = origNamecall
				pcall(setreadonly, gameMt, true)
			end
		end)
	end
end

----------------------------------------------------------------
-- movement
----------------------------------------------------------------
local moveState = { origWalk = nil, fly = nil, noclip = {}, hitbox = {}, lastSpeed = false, lastFly = false, lastNoClip = false, lastHit = false, lastJump = 0 }
onCharacter(function(rec)
	if rec == localRec then
		moveState.origWalk = nil
		moveState.noclip = {}
		moveState.hitbox = {}
		if moveState.fly then
			pcall(function() moveState.fly.lv:Destroy() end)
			pcall(function() moveState.fly.ao:Destroy() end)
			pcall(function() moveState.fly.att:Destroy() end)
			moveState.fly = nil
		end
	end
end)
local function moveUpdate(dt)
	local rec = localRec
	if not rec or not rec.alive or not rec.hum or not rec.root then return end
	local hum, root = rec.hum, rec.root
	-- speed
	local spOn = Get("Move.Speed")
	if spOn ~= moveState.lastSpeed then
		if not spOn and moveState.origWalk then
			pcall(function() hum.WalkSpeed = moveState.origWalk end)
			moveState.origWalk = nil
		end
		moveState.lastSpeed = spOn
	end
	if spOn then
		if moveState.origWalk == nil then moveState.origWalk = hum.WalkSpeed end
		local target = Get("Move.SpeedValue")
		if Get("Move.SpeedMode") == "Walk" then
			if hum.WalkSpeed ~= target then hum.WalkSpeed = target end
		else
			local md = hum.MoveDirection
			if md.Magnitude > 0.1 then
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(md.X * target, v.Y, md.Z * target)
			end
		end
	end
	-- fly
	local flyOn = Get("Move.Fly")
	if flyOn ~= moveState.lastFly then
		if not flyOn and moveState.fly then
			pcall(function() moveState.fly.lv:Destroy() end)
			pcall(function() moveState.fly.ao:Destroy() end)
			pcall(function() moveState.fly.att:Destroy() end)
			moveState.fly = nil
		end
		moveState.lastFly = flyOn
	end
	if flyOn then
		if not moveState.fly or moveState.fly.lv.Parent ~= root then
			if moveState.fly then
				pcall(function() moveState.fly.lv:Destroy() end)
				pcall(function() moveState.fly.ao:Destroy() end)
				pcall(function() moveState.fly.att:Destroy() end)
			end
			local att = Instance.new("Attachment"); att.Parent = root
			local lv = Instance.new("LinearVelocity")
			lv.Attachment0 = att; lv.MaxForce = math.huge
			lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
			lv.VectorVelocity = Vector3.zero; lv.Parent = root
			local ao = Instance.new("AlignOrientation")
			ao.Attachment0 = att; ao.MaxTorque = math.huge; ao.Responsiveness = 200
			ao.Mode = Enum.OrientationAlignmentMode.OneAttachment; ao.Parent = root
			moveState.fly = { att = att, lv = lv, ao = ao }
		end
		local f = moveState.fly
		local move = Vector3.zero
		if currentCamera then
			local look, right = currentCamera.CFrame.LookVector, currentCamera.CFrame.RightVector
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + look end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - look end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - right end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + right end
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
		local spd = Get("Move.FlyValue")
		f.lv.VectorVelocity = (move.Magnitude > 0) and (move.Unit * spd) or Vector3.zero
		if currentCamera then f.ao.CFrame = currentCamera.CFrame end
	end
	-- noclip
	local ncOn = Get("Move.NoClip")
	if ncOn ~= moveState.lastNoClip then
		if not ncOn then
			for part, can in pairs(moveState.noclip) do
				if part and part.Parent then pcall(function() part.CanCollide = can end) end
			end
			moveState.noclip = {}
		end
		moveState.lastNoClip = ncOn
	end
	if ncOn and rec.char then
		for _, part in ipairs(rec.char:GetDescendants()) do
			if part:IsA("BasePart") then
				if moveState.noclip[part] == nil then moveState.noclip[part] = part.CanCollide end
				if part.CanCollide then part.CanCollide = false end
			end
		end
	end
	-- hitbox expander
	local hbOn = Get("Move.Hitbox")
	if hbOn ~= moveState.lastHit then
		if not hbOn then
			for part, orig in pairs(moveState.hitbox) do
				if part and part.Parent then
					pcall(function() part.Size = orig.Size; part.Transparency = orig.Transparency end)
				end
			end
			moveState.hitbox = {}
		end
		moveState.lastHit = hbOn
	end
	if hbOn then
		local size = Get("Move.HitboxSize")
		for _, other in pairs(Cache.byPlayer) do
			if other ~= rec and other.char then
				for _, name in ipairs({ "Head", "UpperTorso", "LowerTorso", "Torso" }) do
					local part = other.char:FindFirstChild(name)
					if part and part:IsA("BasePart") then
						if moveState.hitbox[part] == nil then
							moveState.hitbox[part] = { Size = part.Size, Transparency = part.Transparency }
						end
						if part.Size.X ~= size then part.Size = Vector3.new(size, size, size) end
						part.Transparency = 0.6
					end
				end
			end
		end
	end
	-- inf jump
	if Get("Move.InfJump") and UserInputService:IsKeyDown(Enum.KeyCode.Space) and os.clock() - moveState.lastJump > 0.25 then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		moveState.lastJump = os.clock()
	end
end

----------------------------------------------------------------
-- anti-aim
----------------------------------------------------------------
local aaState = { rootJoint = nil, neck = nil, origRoot = nil, origNeck = nil, lastJ = false, lastD = false, lastH = false, lagT = 0, lagPhase = false }
onCharacter(function(rec)
	if rec == localRec then
		aaState.rootJoint, aaState.neck = nil, nil
		aaState.origRoot, aaState.origNeck = nil, nil
	end
end)
local function findJoints(rec)
	if not rec.char then return end
	if not aaState.rootJoint then
		local r = rec.root
		if r then
			local j = r:FindFirstChild("RootJoint")
			if j and j:IsA("Motor6D") then aaState.rootJoint = j; aaState.origRoot = j.C0 end
		end
	end
	if not aaState.neck then
		local h = rec.head
		if h then
			local n = h:FindFirstChild("Neck")
			if n and n:IsA("Motor6D") then aaState.neck = n; aaState.origNeck = n.C0 end
		end
	end
end
local function aaUpdate(dt)
	local rec = localRec
	if not rec or not rec.alive or not rec.root then return end
	findJoints(rec)
	local anyOn = Get("AA.Jitter") or Get("AA.Desync") or Get("AA.HideHead")
	if not anyOn then
		if aaState.rootJoint and aaState.origRoot and aaState.rootJoint.C0 ~= aaState.origRoot then
			aaState.rootJoint.C0 = aaState.origRoot
		end
		if aaState.neck and aaState.origNeck and aaState.neck.C0 ~= aaState.origNeck then
			aaState.neck.C0 = aaState.origNeck
		end
	end
	local total = 0
	if Get("AA.Jitter") then
		total = total + math.sin(os.clock() * (Get("AA.JitterAngle") / 4)) * math.rad(Get("AA.JitterAngle"))
	end
	if Get("AA.Desync") and aaState.rootJoint and aaState.origRoot then
		local mode = Get("AA.DesyncMode")
		local ang = 0
		if mode == "Spin" then ang = math.rad(os.clock() * 60)
		elseif mode == "Static" then ang = math.rad(60)
		elseif mode == "Backwards" then ang = math.rad(180) end
		aaState.rootJoint.C0 = aaState.origRoot * CFrame.Angles(0, ang + total, 0)
	elseif Get("AA.Jitter") and aaState.rootJoint and aaState.origRoot then
		aaState.rootJoint.C0 = aaState.origRoot * CFrame.Angles(0, total, 0)
	end
	if Get("AA.HideHead") and aaState.neck and aaState.origNeck then
		aaState.neck.C0 = aaState.origNeck * CFrame.Angles(0, math.rad(180), 0)
	end
	if Get("AA.Spinbot") then
		rec.root.CFrame = rec.root.CFrame * CFrame.Angles(0, math.rad(25), 0)
	end
	if Get("AA.FakeLag") and not Get("Move.Fly") then
		aaState.lagT = aaState.lagT + dt
		local cycle = 0.2
		local phase = (aaState.lagT % cycle) < (cycle * 0.3)
		if phase ~= aaState.lagPhase then aaState.lagPhase = phase end
		if phase then
			pcall(function()
				rec.root.AssemblyLinearVelocity = Vector3.zero
				rec.root.AssemblyAngularVelocity = Vector3.zero
			end)
		end
	end
end
App:Connect(RunService.Heartbeat, function(dt)
	timed("move", moveUpdate, dt)
	timed("aa", aaUpdate, dt)
end)
-- anti-afk
App:Connect(LocalPlayer.Idled, function()
	if Get("Misc.AntiAFK") then
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end
end)

----------------------------------------------------------------
-- UI
----------------------------------------------------------------
local UIScope = newScope("ui")
local guiParent
do
	local ok, t = nil, nil
	if CAP.gethui then ok, t = pcall(gethui) end
	if ok and t then guiParent = t
	elseif CAP.protectgui then
		guiParent = CoreGui
	else
		guiParent = LocalPlayer:WaitForChild("PlayerGui")
	end
end
local gui = UIScope:Give(Instance.new("ScreenGui"))
gui.Name = "AbyssUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
if CAP.protectgui then pcall(function() syn.protect_gui(gui) end) end
gui.Parent = guiParent

local THEME = {
	bg = Color3.fromRGB(16, 20, 28), top = Color3.fromRGB(30, 38, 52),
	elem = Color3.fromRGB(30, 37, 50), elemH = Color3.fromRGB(40, 49, 66),
	stroke = Color3.fromRGB(60, 72, 94), text = Color3.fromRGB(235, 240, 250),
	muted = Color3.fromRGB(150, 160, 180), accent = Color3.fromRGB(112, 188, 255),
	off = Color3.fromRGB(90, 100, 120),
}
local function inst(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(p, r) inst("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p) end
local function stroke(p, c) inst("UIStroke", { Color = c or THEME.stroke, Thickness = 1 }, p) end

local main = inst("Frame", {
	Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(560, 440),
	BackgroundColor3 = THEME.bg, BorderSizePixel = 0, ClipsDescendants = true,
}, gui)
corner(main, 12); stroke(main)
local topbar = inst("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = THEME.top, BorderSizePixel = 0 }, main)
corner(topbar, 12)
inst("Frame", { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -10), BackgroundColor3 = THEME.top, BorderSizePixel = 0 }, topbar)
inst("TextLabel", {
	Size = UDim2.new(1, -120, 1, 0), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1,
	Text = "abyss", Font = Enum.Font.GothamSemibold, TextSize = 15,
	TextColor3 = THEME.text, TextXAlignment = Enum.TextXAlignment.Left,
}, topbar)
local hideBtn = inst("TextButton", {
	Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -34, 0.5, -13),
	BackgroundColor3 = THEME.elem, BorderSizePixel = 0, Text = "x",
	TextColor3 = THEME.text, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
}, topbar)
corner(hideBtn, 6)
local sidebar = inst("Frame", {
	Size = UDim2.new(0, 120, 1, -54), Position = UDim2.fromOffset(8, 50),
	BackgroundColor3 = THEME.top, BorderSizePixel = 0,
}, main)
corner(sidebar, 10)
local tabList = inst("ScrollingFrame", {
	Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
}, sidebar)
local tabLayout = inst("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, tabList)
local pages = inst("Frame", {
	Size = UDim2.new(1, -136, 1, -54), Position = UDim2.fromOffset(132, 50), BackgroundTransparency = 1,
}, main)

-- drag
do
	local dragging, dragStart, startPos = false, nil, nil
	UIScope:Connect(topbar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true; dragStart = input.Position; startPos = main.Position
		end
	end)
	UIScope:Connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(0.5, startPos.X.Offset + d.X, 0.5, startPos.Y.Offset + d.Y)
		end
	end)
	UIScope:Connect(UserInputService.InputEnded, function() dragging = false end)
end

-- notifications
local notifyHolder = inst("Frame", {
	BackgroundTransparency = 1, Position = UDim2.new(1, -300, 0, 14), Size = UDim2.new(0, 286, 1, -28),
}, gui)
inst("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom }, notifyHolder)
NotifyFn = function(title, content)
	task.spawn(function()
		local box = inst("Frame", {
			BackgroundColor3 = THEME.elem, BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		}, notifyHolder)
		corner(box, 10); stroke(box)
		inst("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, box)
		inst("UIListLayout", { Padding = UDim.new(0, 3) }, box)
		inst("TextLabel", {
			BackgroundTransparency = 1, Text = tostring(title), TextColor3 = THEME.text,
			Font = Enum.Font.GothamSemibold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 16),
		}, box)
		inst("TextLabel", {
			BackgroundTransparency = 1, Text = tostring(content), TextColor3 = THEME.muted,
			Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		}, box)
		task.wait(4)
		if box.Parent then box:Destroy() end
	end)
end

-- watermark
local wm = inst("Frame", {
	BackgroundColor3 = THEME.elem, BorderSizePixel = 0, Size = UDim2.fromOffset(240, 22),
	Position = UDim2.fromOffset(10, 10), BackgroundTransparency = 0.15,
}, gui)
corner(wm, 6); stroke(wm)
local wmText = inst("TextLabel", {
	Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1,
	TextColor3 = THEME.text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
}, wm)

-- tabs + elements
local selectedTab = nil
local tabs = {}
local capturing = nil
local function addTab(name)
	local page = inst("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
		ScrollBarThickness = 3, ScrollBarImageColor3 = THEME.stroke, Visible = false, CanvasSize = UDim2.new(),
	}, pages)
	local layout = inst("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
	inst("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6) }, page)
	UIScope:Connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 16)
	end)
	local btn = inst("TextButton", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = THEME.elem, BorderSizePixel = 0,
		Text = name, TextColor3 = THEME.muted, Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false,
	}, tabList)
	corner(btn, 8)
	local rec = { name = name, page = page, btn = btn }
	table.insert(tabs, rec)
	UIScope:Connect(btn.MouseButton1Click, function() selectTab(rec) end)
	if not selectedTab then selectTab(rec) end
	local tab = {}
	local order = 0
	local function row(h)
		order = order + 1
		local f = inst("Frame", {
			Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = THEME.elem, BorderSizePixel = 0,
			LayoutOrder = order,
		}, page)
		corner(f, 8); stroke(f)
		return f
	end
	local function title(f, text)
		return inst("TextLabel", {
			Size = UDim2.new(0.6, -12, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1,
			Text = tostring(text), TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.text, Font = Enum.Font.Gotham, TextSize = 13,
		}, f)
	end
	function tab:Section(text)
		order = order + 1
		inst("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = tostring(text),
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.muted,
			Font = Enum.Font.GothamSemibold, TextSize = 11, LayoutOrder = order,
		}, page)
	end
	function tab:Label(text)
		local f = row(26)
		local l = title(f, text)
		l.Size = UDim2.new(1, -16, 1, 0)
		return { Set = function(_, v) l.Text = tostring(v) end }
	end
	function tab:Toggle(opts)
		local f = row(32)
		title(f, opts.Name)
		local sw = inst("Frame", {
			Size = UDim2.fromOffset(38, 18), Position = UDim2.new(1, -48, 0.5, -9),
			BackgroundColor3 = THEME.bg, BorderSizePixel = 0,
		}, f)
		corner(sw, 9); stroke(sw)
		local ind = inst("Frame", {
			Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = THEME.off, BorderSizePixel = 0,
		}, sw)
		corner(ind, 6)
		local el = { disabled = opts.Disabled == true }
		local function paint(on)
			ind.BackgroundColor3 = on and THEME.accent or THEME.off
			ind.Position = on and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		end
		function el.Set(_, v, silent)
			paint(v == true)
			if not silent and not el.disabled then opts.OnChange(v == true) end
		end
		UIScope:Connect(f.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not el.disabled then
				local nv = not Get(opts.Path)
				Set(opts.Path, nv)
				el.Set(nil, nv, true)
			end
		end)
		paint(Get(opts.Path) == true)
		watch(opts.Path, function(v) el.Set(nil, v, true) end)
		if el.disabled then
			UIScope:Connect(f.InputBegan, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					Notify(opts.Name, "unsupported on this executor")
				end
			end)
		end
		return el
	end
	function tab:Slider(opts)
		local f = row(44)
		title(f, opts.Name)
		local info = inst("TextLabel", {
			Size = UDim2.fromOffset(90, 14), Position = UDim2.new(1, -100, 0, 5), BackgroundTransparency = 1,
			TextColor3 = THEME.text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right,
		}, f)
		local track = inst("Frame", {
			Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 30),
			BackgroundColor3 = THEME.off, BorderSizePixel = 0,
		}, f)
		corner(track, 3)
		local fill = inst("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = THEME.accent, BorderSizePixel = 0 }, track)
		corner(fill, 3)
		local el = {}
		local function paint(v)
			local r = (v - opts.Min) / (opts.Max - opts.Min)
			fill.Size = UDim2.new(math.clamp(r, 0, 1), 0, 1, 0)
			info.Text = tostring(math.floor(v * 100) / 100) .. (opts.Suffix or "")
		end
		function el.Set(_, v) paint(v) end
		local draggingS = false
		local function fromX(x)
			local w = math.max(track.AbsoluteSize.X, 1)
			local r = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
			local v = opts.Min + (opts.Max - opts.Min) * r
			v = math.floor(v / (opts.Step or 1) + 0.5) * (opts.Step or 1)
			Set(opts.Path, v)
		end
		UIScope:Connect(track.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingS = true; fromX(input.Position.X) end
		end)
		UIScope:Connect(UserInputService.InputChanged, function(input)
			if draggingS and input.UserInputType == Enum.UserInputType.MouseMovement then fromX(input.Position.X) end
		end)
		UIScope:Connect(UserInputService.InputEnded, function() draggingS = false end)
		watch(opts.Path, function(v) paint(v) end)
		paint(Get(opts.Path))
		return el
	end
	function tab:Dropdown(opts)
		local f = row(34)
		title(f, opts.Name)
		local sel = inst("TextLabel", {
			Size = UDim2.new(0.34, -20, 1, 0), Position = UDim2.new(0.66, -14, 0, 0), BackgroundTransparency = 1,
			Text = tostring(Get(opts.Path)), TextColor3 = THEME.muted, Font = Enum.Font.Gotham, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, f)
		local list = inst("Frame", {
			Size = UDim2.new(1, -8, 0, 0), Position = UDim2.new(0, 4, 1, 2), BackgroundColor3 = THEME.top,
			BorderSizePixel = 0, ClipsDescendants = true, Visible = false, ZIndex = 30,
		}, f)
		corner(list, 8); stroke(list)
		local ll = inst("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, list)
		local open = false
		for _, opt in ipairs(opts.Options) do
			local ob = inst("TextButton", {
				Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = THEME.elem, BorderSizePixel = 0,
				Text = "  " .. opt, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.text,
				Font = Enum.Font.Gotham, TextSize = 12, AutoButtonColor = false, ZIndex = 31,
			}, list)
			corner(ob, 6)
			UIScope:Connect(ob.MouseButton1Click, function()
				Set(opts.Path, opt)
				open = false; list.Visible = false
			end)
		end
		UIScope:Connect(f.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				open = not open
				list.Visible = open
				if open then list.Size = UDim2.new(1, -8, 0, #opts.Options * 27 + 8) end
			end
		end)
		watch(opts.Path, function(v) sel.Text = tostring(v) end)
	end
	function tab:Keybind(opts)
		local f = row(32)
		title(f, opts.Name)
		local kb = inst("TextButton", {
			Size = UDim2.fromOffset(84, 20), Position = UDim2.new(1, -94, 0.5, -10),
			BackgroundColor3 = THEME.top, BorderSizePixel = 0, Text = tostring(Get(opts.Path)),
			TextColor3 = THEME.text, Font = Enum.Font.Gotham, TextSize = 11, AutoButtonColor = false,
		}, f)
		corner(kb, 6); stroke(kb)
		UIScope:Connect(kb.MouseButton1Click, function()
			capturing = opts.Path
			kb.Text = "press key"
		end)
		watch(opts.Path, function(v) kb.Text = tostring(v) end)
	end
	function tab:Button(opts)
		local f = row(30)
		local l = title(f, opts.Name)
		l.Size = UDim2.new(1, -16, 1, 0)
		UIScope:Connect(f.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				protect("button:" .. opts.Name, opts.OnClick)
			end
		end)
	end
	return tab
end
function selectTab(rec)
	selectedTab = rec
	for _, t in ipairs(tabs) do
		t.page.Visible = (t == rec)
		t.btn.BackgroundColor3 = (t == rec) and THEME.accent or THEME.elem
		t.btn.TextColor3 = (t == rec) and Color3.fromRGB(10, 14, 20) or THEME.muted
	end
end

----------------------------------------------------------------
-- build UI content (every control maps to a real setting)
----------------------------------------------------------------
local combat = addTab("combat")
combat:Section("aimbot")
combat:Toggle({ Name = "Aimbot", Path = "Aimbot.Enabled" })
combat:Toggle({ Name = "Silent (hook)", Path = "Aimbot.Silent", Disabled = not CAP.hook })
combat:Toggle({ Name = "Only enemies", Path = "Aimbot.OnlyEnemies" })
combat:Toggle({ Name = "Wall check", Path = "Aimbot.WallCheck" })
combat:Toggle({ Name = "FOV circle", Path = "Aimbot.ShowFOV", Disabled = not CAP.drawing })
combat:Slider({ Name = "FOV", Path = "Aimbot.FOV", Min = 10, Max = 600, Step = 10 })
combat:Slider({ Name = "Smoothing", Path = "Aimbot.Smoothing", Min = 0.5, Max = 20, Step = 0.5 })
combat:Slider({ Name = "Prediction", Path = "Aimbot.Prediction", Min = 0, Max = 0.5, Step = 0.01 })
combat:Keybind({ Name = "Aimbot key", Path = "Keys.Aimbot" })

local visuals = addTab("visuals")
visuals:Section("esp")
visuals:Toggle({ Name = "ESP", Path = "ESP.Enabled", Disabled = not CAP.drawing })
visuals:Toggle({ Name = "Boxes", Path = "ESP.Boxes", Disabled = not CAP.drawing })
visuals:Toggle({ Name = "Health bar", Path = "ESP.HealthBar", Disabled = not CAP.drawing })
visuals:Toggle({ Name = "Snaplines", Path = "ESP.Snaplines", Disabled = not CAP.drawing })
visuals:Toggle({ Name = "Names", Path = "ESP.Names", Disabled = not CAP.drawing })
visuals:Toggle({ Name = "Distance", Path = "ESP.Distance", Disabled = not CAP.drawing })
visuals:Toggle({ Name = "Chams", Path = "ESP.Chams", Disabled = not CAP.drawing })
visuals:Toggle({ Name = "Only enemies", Path = "ESP.OnlyEnemies" })
visuals:Slider({ Name = "Max distance", Path = "ESP.MaxDistance", Min = 50, Max = 2000, Step = 50 })

local move = addTab("move")
move:Section("speed")
move:Toggle({ Name = "Speed", Path = "Move.Speed" })
move:Dropdown({ Name = "Mode", Path = "Move.SpeedMode", Options = { "Walk", "Vel" } })
move:Slider({ Name = "Speed", Path = "Move.SpeedValue", Min = 16, Max = 200, Step = 1 })
move:Keybind({ Name = "Speed key", Path = "Keys.Speed" })
move:Section("fly")
move:Toggle({ Name = "Fly", Path = "Move.Fly" })
move:Slider({ Name = "Fly speed", Path = "Move.FlyValue", Min = 20, Max = 200, Step = 5 })
move:Keybind({ Name = "Fly key", Path = "Keys.Fly" })
move:Section("other")
move:Toggle({ Name = "NoClip", Path = "Move.NoClip" })
move:Toggle({ Name = "Inf jump", Path = "Move.InfJump" })
move:Toggle({ Name = "Hitbox expander", Path = "Move.Hitbox" })
move:Slider({ Name = "Hitbox size", Path = "Move.HitboxSize", Min = 3, Max = 25, Step = 1 })

local aa = addTab("antiaim")
aa:Section("angles")
aa:Toggle({ Name = "Jitter", Path = "AA.Jitter" })
aa:Slider({ Name = "Jitter angle", Path = "AA.JitterAngle", Min = 10, Max = 180, Step = 5 })
aa:Toggle({ Name = "Desync", Path = "AA.Desync" })
aa:Dropdown({ Name = "Desync mode", Path = "AA.DesyncMode", Options = { "Spin", "Static", "Backwards" } })
aa:Toggle({ Name = "Hide head", Path = "AA.HideHead" })
aa:Section("misc")
aa:Toggle({ Name = "Fake lag", Path = "AA.FakeLag" })
aa:Toggle({ Name = "Spinbot", Path = "AA.Spinbot" })

local misc = addTab("misc")
misc:Section("general")
misc:Toggle({ Name = "Watermark", Path = "Misc.Watermark" })
misc:Toggle({ Name = "Anti-AFK", Path = "Misc.AntiAFK" })
misc:Keybind({ Name = "UI key", Path = "Keys.UI" })
misc:Button({ Name = "Save config", OnClick = function()
	Notify("Config", saveConfig() and "saved" or "save failed")
end })
misc:Button({ Name = "Unload", OnClick = function() Unload() end })
misc:Section("diagnostics")
local diagLabels = {}
for _, key in ipairs({ "fps", "proj", "ray", "cpu", "obj" }) do
	diagLabels[key] = misc:Label(key)
end

----------------------------------------------------------------
-- global input: UI hide + feature keys + keybind capture
----------------------------------------------------------------
UIScope:Connect(UserInputService.InputBegan, function(input, processed)
	if capturing then
		if input.KeyCode ~= Enum.KeyCode.Unknown then
			Set(capturing, input.KeyCode.Name)
		end
		capturing = nil
		return
	end
	if processed then return end
	local kc = input.KeyCode.Name
	if kc == Get("Keys.UI") then
		main.Visible = not main.Visible
		return
	end
	if kc == Get("Keys.Aimbot") and Get("Keys.Aimbot") ~= "" then Set("Aimbot.Enabled", not Get("Aimbot.Enabled")) end
	if kc == Get("Keys.Fly") and Get("Keys.Fly") ~= "" then Set("Move.Fly", not Get("Move.Fly")) end
	if kc == Get("Keys.Speed") and Get("Keys.Speed") ~= "" then Set("Move.Speed", not Get("Move.Speed")) end
end)
UIScope:Connect(hideBtn.MouseButton1Click, function() main.Visible = false end)

----------------------------------------------------------------
-- scheduled low-rate work: esp 30Hz, ui/diag 2Hz, diag rates 1Hz
----------------------------------------------------------------
App:BindRender("esp", Enum.RenderPriority.Camera.Value + 2, function(dt)
	espAcc = espAcc + dt
	if espAcc >= 1 / 30 then
		espAcc = 0
		timed("esp", espUpdate)
	end
end)
local diagAcc = 0
App:Connect(RunService.Heartbeat, function(dt)
	diagAcc = diagAcc + dt
	if diagAcc < 0.5 then return end
	diagAcc = 0
	protect("ui.tick", function()
		wm.Visible = Get("Misc.Watermark")
		if wm.Visible then
			wmText.Text = string.format("abyss | fps %d | proj %d/s | ray %d/s | drw %d",
				math.floor(Diag.fps), Diag.projRate, Diag.rayRate, Pool.count)
		end
		diagLabels.fps:Set("fps " .. math.floor(Diag.fps))
		diagLabels.proj:Set("projections " .. Diag.projRate .. "/s")
		diagLabels.ray:Set("raycasts " .. Diag.rayRate .. "/s")
		diagLabels.cpu:Set(string.format("cpu ms/s aim %.2f esp %.2f move %.2f aa %.2f",
			Diag.cpuRate.aim * 1000, Diag.cpuRate.esp * 1000, Diag.cpuRate.move * 1000, Diag.cpuRate.aa * 1000))
		diagLabels.obj:Set("drawings " .. Pool.count .. " | scopes " .. #scopes)
	end)
end)
local rateT = 0
App:Connect(RunService.Heartbeat, function(dt)
	rateT = rateT + dt
	if rateT < 1 then return end
	Diag.projRate = math.floor(Diag.proj / rateT)
	Diag.rayRate = math.floor(Diag.ray / rateT)
	for k in pairs(Diag.cpuRate) do Diag.cpuRate[k] = Diag.cpu[k] / rateT; Diag.cpu[k] = 0 end
	Diag.proj = 0; Diag.ray = 0
	rateT = 0
end)

----------------------------------------------------------------
-- init: load config after UI built so values paint correctly
----------------------------------------------------------------
if loadConfig() then
	Notify("Config", "loaded from previous session")
end

----------------------------------------------------------------
-- unload
----------------------------------------------------------------
function Unload()
	for _, s in ipairs(scopes) do s:Destroy() end
	table.clear(scopes)
	ENV.__ABYSS = nil
end
ENV.__ABYSS = { Unload = Unload }
Notify("abyss", "ready")
