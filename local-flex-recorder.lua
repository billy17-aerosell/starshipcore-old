--[[
	Local Flex Recorder + Playback (Single File)
	Executor: Wave/Solara/Swift/Fluxus

	Format frame & metadata kompatibel dengan StarshipCore.lua (Flexible Mode).
	Playback engine ngambil logic dari StarspacePlayback (Catmull-Rom smoothing,
	cross-rig height offset, velocity blending, anti-drift snap, dll).

	Single-file, no UI library, executor-friendly.
]]

local CONFIG = {
	DEBUG            = true,
	FPS              = 60,
	FOLDER           = "StarshipCore/LocalFlexRecorder",
	WORKSPACE_DEFAULT= "Default",  -- default workspace name
	AUTO_COPY_STOP   = true,
	SMOOTH           = true,    -- post-process Gaussian smoothing on stop
	SMOOTH_STRENGTH  = 3,
	AUTO_CHECKPOINT  = false,   -- monitor leaderstats (Checkpoint/Summit) and auto-save segment
	AUTO_STOP_ON_CP  = true,    -- stop recording on checkpoint/summit (default ON)
	CP_BASE_NAME     = "",      -- empty = derive from game name
	-- Refall: tekan R / ButtonY (Segitiga) -> pause + buka slider rewind
	REFALL           = false,
	REFALL_KEY       = Enum.KeyCode.R,
	REFALL_GAMEPAD   = Enum.KeyCode.ButtonY,    -- Triangle (Segitiga) di PS
	-- Toggle REC via gamepad: ButtonX (Square / KOTAK)
	REC_GAMEPAD      = Enum.KeyCode.ButtonX,
}

----------------------------------------------------------------
-- Leaderstat names (Checkpoint priority > Summit) - same as StarshipCore
----------------------------------------------------------------
local LEADERSTAT_NAMES = {
	-- CHECKPOINT / SPAWN (highest priority)
	"CheckpointHard","Checkpoint","Checkpointhard","Checkpoints","checkpoint","CHECKPOINT",
	"CheckPoint","CheckPointHard","CP","cp","Chkpt","chkpt","CHKPT",
	"Posisi","Position","Stage","stage","STAGE",
	"Level","level","LEVEL","Lv","lv","LV",
	"Floor","floor","FLOOR","Round","round","ROUND",
	"Wave","wave","WAVE","Phase","phase","PHASE",
	"Area","area","AREA","Zone","zone","ZONE",
	"Room","room","ROOM","Sector","sector","SECTOR",
	"Section","section","SECTION","Part","part","PART",
	"Lap","lap","LAP","Progress","progress","PROGRESS",
	"Wins","wins","WINS","position","POSITION","Pos","pos","POS",
	-- SUMMIT / GOAL (lowest priority)
	"Summit","SummitHard","Summithard","Summits","summit","SUMMIT",
}

----------------------------------------------------------------
-- Services
----------------------------------------------------------------
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")
local LP               = Players.LocalPlayer

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local state = {
	-- recording
	recording   = false,
	paused      = false,
	startTime   = 0,
	lastSample  = 0,
	frames      = {},

	-- playback
	playing     = false,
	playStart   = 0,
	playData    = nil,
	playFrames  = nil,
	playConn    = nil,
	playSpeed   = 1.0,
	curTime     = 0,
	lastTime    = 0,
	lastFrameIdx= 1,
	wasInAir    = false,
	lastAirState= nil,
	lastState   = nil,
	lastShift   = nil,
	oldMouseBeh = nil,
	oldWalkSpd  = nil,
	yOffset     = 0,
	pbIsR6      = false,

	-- recording connections
	conns       = {},

	-- auto-checkpoint
	cpEnabled    = CONFIG.AUTO_CHECKPOINT,
	cpAutoStop   = CONFIG.AUTO_STOP_ON_CP,
	cpBaseName   = CONFIG.CP_BASE_NAME,
	cpStartFrame = 1,
	cpSaveCount  = 0,
	cpLastValues = {},
	cpDetected   = nil,    -- name of detected leaderstat (display)
	cpConns      = {},

	-- workspace
	currentWorkspace = CONFIG.WORKSPACE_DEFAULT,

	-- refall
	refallEnabled  = CONFIG.REFALL,
	refallCount    = 0,
	rewindOpen     = false,    -- slider UI open
	rewindSelectT  = 0,        -- selected time on slider
}

----------------------------------------------------------------
-- Utilities
----------------------------------------------------------------
local function log(...)
	if CONFIG.DEBUG then
		print("[LocalFlex]", ...)
	end
end

local function safeCall(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[LocalFlex]", err)
	end
	return ok
end

local function v3(v) return { x = v.X, y = v.Y, z = v.Z } end
local function c3(c) return { r = c.R, g = c.G, b = c.B } end

local function tblToV3(t)
	if not t then return Vector3.zero end
	return Vector3.new(t.x or 0, t.y or 0, t.z or 0)
end

local function safeName(name)
	name = tostring(name or "Recording")
	name = name:gsub("[^%w_%-]", "_")
	if name == "" then name = "Recording" end
	return name
end

local function ensureFolder(path)
	if not isfolder then return false end
	local cur = ""
	for part in string.gmatch(path, "[^/\\]+") do
		cur = (cur == "") and part or (cur .. "/" .. part)
		if not isfolder(cur) then
			pcall(makefolder, cur)
		end
	end
	return isfolder(path)
end

----------------------------------------------------------------
-- Character helpers
----------------------------------------------------------------
local function getCharacter()
	local char = LP.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return char, hum, root
end

local function isR6(char)
	if not char then return false end
	local torso      = char:FindFirstChild("Torso")
	local lowerTorso = char:FindFirstChild("LowerTorso")
	return (torso ~= nil) and (lowerTorso == nil)
end

local function getCharRootHeight(char)
	if not char then return 3.0 end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return 3.0 end
	if isR6(char) then
		local leg = char:FindFirstChild("Left Leg") or char:FindFirstChild("Right Leg")
		local torso = char:FindFirstChild("Torso")
		local legLen = (leg and leg.Size.Y) or 2.0
		local torsoHalf = (torso and torso.Size.Y / 2) or 1.0
		return legLen + torsoHalf
	else
		return (hum.HipHeight or 0) + (root.Size.Y / 2)
	end
end

----------------------------------------------------------------
-- Tool helpers (matching StarshipCore record format)
----------------------------------------------------------------
local function recordToolFingerprint(frame, char)
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not tool then return end
	pcall(function()
		frame.tool = tool.Name
		frame.toolTip = tool.ToolTip or ""
		local handle = tool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			frame.toolColor = c3(handle.Color)
			pcall(function()
				if handle:IsA("MeshPart") and handle.TextureID and handle.TextureID ~= "" then
					frame.toolTexture = handle.TextureID
				end
			end)
		end
		local config = tool:FindFirstChild("Configuration") or tool:FindFirstChild("Config")
		if config then
			for _, child in ipairs(config:GetChildren()) do
				if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("BoolValue") or child:IsA("StringValue") then
					frame.toolConfig = frame.toolConfig or {}
					frame.toolConfig[child.Name] = child.Value
				end
			end
		end
	end)
end

local function colorMatches(tool, target)
	if not target then return true end
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return true end
	if type(target) == "table" and target.r then
		local tol = 0.05
		return math.abs(handle.Color.R - target.r) < tol
			and math.abs(handle.Color.G - target.g) < tol
			and math.abs(handle.Color.B - target.b) < tol
	end
	return true
end

local function configMatches(tool, target)
	if not target then return true end
	local config = tool:FindFirstChild("Configuration") or tool:FindFirstChild("Config")
	if not config then return false end
	for k, v in pairs(target) do
		local child = config:FindFirstChild(k)
		if not child or child.Value ~= v then return false end
	end
	return true
end

local toolThrottle = { lastEquip = 0, last = nil }
local TOOL_THROTTLE = 0.1

local function updateToolEquip(char, name, tip, color, conf)
	if not char then return end
	local now = os.clock()
	if now - toolThrottle.lastEquip < TOOL_THROTTLE then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local current = char:FindFirstChildOfClass("Tool")
	local curName = current and current.Name or nil

	-- Unequip if recording has no tool
	if not name or name == "" then
		if current then
			toolThrottle.lastEquip = now
			toolThrottle.last = nil
			pcall(function() hum:UnequipTools() end)
		end
		return
	end

	-- Same tool already equipped
	if current and curName == name then
		toolThrottle.last = current
		return
	end

	toolThrottle.lastEquip = now
	local backpack = LP:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	local target = nil
	-- Priority: name + tip + color + config
	if tip or color or conf then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") and t.Name == name then
				local ok = (not tip or t.ToolTip == tip)
					and colorMatches(t, color)
					and configMatches(t, conf)
				if ok then target = t break end
			end
		end
	end
	-- Priority: name + tip
	if not target and tip then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") and t.Name == name and t.ToolTip == tip then
				target = t break
			end
		end
	end
	-- Priority: name only
	if not target then
		target = backpack:FindFirstChild(name)
	end
	-- Fuzzy
	if not target then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") and t.Name:lower() == name:lower() then
				target = t break
			end
		end
	end

	if target and target ~= current then
		toolThrottle.last = target
		pcall(function() hum:EquipTool(target) end)
	end
end

----------------------------------------------------------------
-- Frame helpers (StarspacePlayback approach)
----------------------------------------------------------------
local function gaussianWeight(d, sigma)
	return math.exp(-(d * d) / (2 * sigma * sigma))
end

local function catmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * (
		(2 * p1)
		+ (-p0 + p2) * t
		+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
		+ (-p0 + 3 * p1 - 3 * p2 + p3) * t3
	)
end

local function catmullRomV3(v0, v1, v2, v3, t)
	return Vector3.new(
		catmullRom(v0.X, v1.X, v2.X, v3.X, t),
		catmullRom(v0.Y, v1.Y, v2.Y, v3.Y, t),
		catmullRom(v0.Z, v1.Z, v2.Z, v3.Z, t)
	)
end

local function preprocessFrames(frames)
	if not frames or #frames == 0 then return frames end
	if frames._preprocessed then return frames end
	for i = 1, #frames do
		local f = frames[i]
		if f.pos and not f.posVector then
			f.posVector = Vector3.new(f.pos.x, f.pos.y, f.pos.z)
		end
		if f.vel and not f.velVector then
			f.velVector = Vector3.new(f.vel.x, f.vel.y, f.vel.z)
		end
		if f.md and not f.mdVector then
			f.mdVector = Vector3.new(f.md.x, f.md.y, f.md.z)
		end
		if f.charLook and not f.charLookVector then
			f.charLookVector = Vector3.new(f.charLook.x, f.charLook.y or 0, f.charLook.z)
		end
		if f.camLook and not f.camLookVector then
			f.camLookVector = Vector3.new(f.camLook.x, f.camLook.y, f.camLook.z)
		end
		if f.st and not f.stEnum then
			local n = string.match(f.st, "Enum%.HumanoidStateType%.(%w+)")
			if n then f.stEnum = n end
		end
		if i % 5000 == 0 then task.wait() end
	end
	frames._preprocessed = true
	return frames
end

local function smoothFrames(frames, strength)
	if not frames or #frames == 0 then return frames end
	local processed = {}
	for i, f in ipairs(frames) do
		local copy = {}
		for k, v in pairs(f) do copy[k] = v end
		if f.pos then copy.pos = { x = f.pos.x, y = f.pos.y, z = f.pos.z } end
		processed[i] = copy
	end
	local iters       = math.clamp(strength or 1, 1, 5)
	local kernelRad   = math.clamp(math.ceil((strength or 1) / 2), 1, 3)
	local sigma       = kernelRad / 2
	local weights     = {}
	for d = 0, kernelRad do weights[d] = gaussianWeight(d, sigma) end
	for _ = 1, iters do
		local temp = {}
		for i = 2, #processed - 1 do
			local cur = processed[i]
			if cur.pos then
				local sum = Vector3.zero
				local wSum = 0
				for j = math.max(1, i - kernelRad), math.min(#processed, i + kernelRad) do
					local nb = processed[j]
					if nb.pos then
						local d  = math.abs(j - i)
						local w  = weights[d]
						sum  = sum + Vector3.new(nb.pos.x, nb.pos.y, nb.pos.z) * w
						wSum = wSum + w
					end
				end
				if wSum > 0 then
					local sm  = sum / wSum
					local cv  = Vector3.new(cur.pos.x, cur.pos.y, cur.pos.z)
					local fnl = cv:Lerp(sm, 0.7)
					temp[i] = { x = fnl.X, y = fnl.Y, z = fnl.Z }
				end
			end
			if i % 5000 == 0 then task.wait() end
		end
		for i, p in pairs(temp) do
			processed[i].pos = p
		end
	end
	return processed
end

local function findFrameIndex(frames, t, hint)
	local lo, hi = 1, #frames
	if hint and hint > 0 and hint < #frames then
		if frames[hint].t <= t and frames[hint + 1] and frames[hint + 1].t > t then
			return hint
		end
	end
	while lo <= hi do
		local mid = math.floor((lo + hi) / 2)
		if frames[mid].t <= t then
			if not frames[mid + 1] or frames[mid + 1].t > t then
				return mid
			end
			lo = mid + 1
		else
			hi = mid - 1
		end
	end
	return math.max(1, lo - 1)
end

local function smoothInterp(frames, idx, alpha)
	local n = #frames
	if n < 2 then return nil, nil, nil end
	local f1, f2 = frames[idx], frames[idx + 1]
	if not f1 or not f2 then return nil, nil, nil end
	alpha = math.clamp(alpha, 0, 1)

	local i0 = math.max(1, idx - 1)
	local i3 = math.min(n, idx + 2)
	local f0, f3 = frames[i0], frames[i3]

	local sPos, sVel, sLook

	-- Position: Catmull-Rom
	if f0.posVector and f1.posVector and f2.posVector and f3.posVector then
		sPos = catmullRomV3(f0.posVector, f1.posVector, f2.posVector, f3.posVector, alpha)
	elseif f1.posVector and f2.posVector then
		sPos = f1.posVector:Lerp(f2.posVector, alpha)
	end

	-- Velocity: Catmull-Rom + magnitude clamp
	if f0.velVector and f1.velVector and f2.velVector and f3.velVector then
		sVel = catmullRomV3(f0.velVector, f1.velVector, f2.velVector, f3.velVector, alpha)
		local maxMag = math.max(f1.velVector.Magnitude, f2.velVector.Magnitude)
		if sVel.Magnitude > maxMag and maxMag > 0 then
			sVel = sVel.Unit * maxMag
		end
	elseif f1.velVector and f2.velVector then
		sVel = f1.velVector:Lerp(f2.velVector, alpha)
	end

	-- Look direction
	if f0.charLookVector and f1.charLookVector and f2.charLookVector and f3.charLookVector then
		sLook = catmullRomV3(f0.charLookVector, f1.charLookVector, f2.charLookVector, f3.charLookVector, alpha)
		if sLook.Magnitude > 0.01 then sLook = sLook.Unit end
	elseif f1.charLookVector and f2.charLookVector then
		sLook = f1.charLookVector:Lerp(f2.charLookVector, alpha)
		if sLook.Magnitude > 0.01 then sLook = sLook.Unit end
	end

	return sPos, sVel, sLook
end

----------------------------------------------------------------
-- File I/O
----------------------------------------------------------------
local function buildData()
	local char, hum, root = getCharacter()
	local rigType = isR6(char) and "R6" or "R15"
	local rootH   = getCharRootHeight(char)
	return {
		Version    = 2,
		Mode       = "Flexible",
		FPS        = CONFIG.FPS,
		PlaceId    = game.PlaceId,
		JobId      = game.JobId,
		UserId     = LP.UserId,
		Username   = LP.Name,
		RigType    = rigType,
		HipHeight  = (hum and hum.HipHeight) or 0,
		RootHeight = rootH,
		Duration   = state.frames[#state.frames] and state.frames[#state.frames].t or 0,
		FrameCount = #state.frames,
		Frames     = state.frames,
	}
end

local function encodeJSON()
	local data = buildData()
	local ok, json = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	return ok and json or nil
end

local function getWorkspacePath(ws)
	ws = safeName(ws or state.currentWorkspace or CONFIG.WORKSPACE_DEFAULT)
	return CONFIG.FOLDER .. "/" .. ws
end

local function listWorkspaces()
	if not isfolder then return { CONFIG.WORKSPACE_DEFAULT } end
	if not ensureFolder(CONFIG.FOLDER) then return { CONFIG.WORKSPACE_DEFAULT } end
	local list, seen = {}, {}
	if listfiles then
		local ok, items = pcall(listfiles, CONFIG.FOLDER)
		if ok and items then
			for _, p in ipairs(items) do
				if isfolder(p) then
					-- p is a full path; extract leaf name
					local leaf = p:match("[/\\]([^/\\]+)$") or p
					if leaf ~= "" and not seen[leaf] then
						seen[leaf] = true
						table.insert(list, leaf)
					end
				end
			end
		end
	end
	-- Always ensure default workspace is present
	if not seen[CONFIG.WORKSPACE_DEFAULT] then
		table.insert(list, 1, CONFIG.WORKSPACE_DEFAULT)
	end
	table.sort(list)
	return list
end

local function listRecordings(ws)
	local out, seen = {}, {}
	if not isfolder or not listfiles then return out end
	local wsPath = getWorkspacePath(ws)
	if not isfolder(wsPath) then
		ensureFolder(wsPath)
	else
		local ok, items = pcall(listfiles, wsPath)
		if ok and items then
			for _, p in ipairs(items) do
				if isfile and isfile(p) then
					local leaf = p:match("[/\\]([^/\\]+)$") or p
					if leaf:lower():sub(-5) == ".json" then
						local nm = leaf:sub(1, -6)
						if not seen[nm] then
							seen[nm] = true
							table.insert(out, nm)
						end
					end
				end
			end
		end
	end
	-- Backward-compat: include legacy files at root for Default workspace
	if ws == CONFIG.WORKSPACE_DEFAULT and isfolder(CONFIG.FOLDER) then
		local rOk, rItems = pcall(listfiles, CONFIG.FOLDER)
		if rOk and rItems then
			for _, p in ipairs(rItems) do
				if isfile and isfile(p) then
					local leaf = p:match("[/\\]([^/\\]+)$") or p
					if leaf:lower():sub(-5) == ".json" then
						local nm = leaf:sub(1, -6)
						if not seen[nm] then
							seen[nm] = true
							table.insert(out, nm)
						end
					end
				end
			end
		end
	end
	table.sort(out)
	return out
end

local function createWorkspace(name)
	name = safeName(name or "")
	if name == "" then return false, "name empty" end
	local path = CONFIG.FOLDER .. "/" .. name
	if isfolder and isfolder(path) then return false, "exists" end
	if not ensureFolder(path) then return false, "create failed" end
	return true, name
end

local function deleteRecording(ws, name)
	if not delfile then return false, "delfile not supported" end
	name = safeName(name or "")
	if name == "" then return false, "name empty" end
	local path = getWorkspacePath(ws) .. "/" .. name .. ".json"
	if isfile and not isfile(path) then return false, "not found" end
	local ok, err = pcall(delfile, path)
	if not ok then return false, tostring(err) end
	return true
end

local function deleteWorkspace(name)
	name = safeName(name or "")
	if name == "" or name == CONFIG.WORKSPACE_DEFAULT then
		return false, "cannot delete default"
	end
	local path = CONFIG.FOLDER .. "/" .. name
	if not isfolder or not isfolder(path) then return false, "not found" end
	-- Delete all files inside first
	if listfiles and delfile then
		local items = listfiles(path)
		for _, f in ipairs(items or {}) do
			if isfile and isfile(f) then
				pcall(delfile, f)
			end
		end
	end
	if delfolder then
		local ok = pcall(delfolder, path)
		if not ok then return false, "delfolder failed" end
	end
	return true
end

local function saveToFile(name, ws)
	local json = encodeJSON()
	if not json then return false, "encode failed" end
	if not writefile then return false, "writefile not supported" end
	ws = ws or state.currentWorkspace or CONFIG.WORKSPACE_DEFAULT
	local wsPath = getWorkspacePath(ws)
	if not ensureFolder(wsPath) then return false, "folder failed" end
	name = safeName(name or ("LocalRec_" .. os.date("%H%M%S")))
	local path = wsPath .. "/" .. name .. ".json"
	local ok, err = pcall(writefile, path, json)
	if not ok then return false, tostring(err) end
	return true, path
end

local function copyToClipboard()
	local json = encodeJSON()
	if not json or not setclipboard then return false end
	return pcall(setclipboard, json)
end

local function loadFromFile(name)
	if not readfile then return false, "readfile not supported" end
	name = safeName(name or "")
	if name == "" then return false, "name empty" end
	local ws = state.currentWorkspace or CONFIG.WORKSPACE_DEFAULT
	local commonPaths = {
		getWorkspacePath(ws) .. "/" .. name .. ".json",
		CONFIG.FOLDER .. "/" .. CONFIG.WORKSPACE_DEFAULT .. "/" .. name .. ".json",
		CONFIG.FOLDER .. "/" .. name .. ".json",
		"StarSpace/StarSpace-Recording/" .. name .. ".json",
		"StarSpace/StarshipMerger/" .. name .. ".json",
		"StarSpace/" .. name .. ".json",
		name,
		name .. ".json",
	}
	local content
	for _, p in ipairs(commonPaths) do
		if isfile and isfile(p) then
			local ok, c = pcall(readfile, p)
			if ok and c then content = c break end
		end
	end
	if not content then
		return false, "file not found"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if not ok or not data then return false, "decode failed" end
	return true, data
end

----------------------------------------------------------------
-- Merge + Optimize all recordings in a workspace into one file
----------------------------------------------------------------
-- Optimizations:
--   1. Quantize pos to 2 decimals, rot to 1 decimal, vel to 1 decimal
--   2. Drop vel entirely jika magnitude < 0.5 (hampir diam)
--   3. Drop tool/anim jika sama dengan frame sebelumnya (delta-compress)
--   4. Skip frame kalau pos hampir identik dengan sebelumnya (< 0.05 stud)
--   5. Time digabung dengan offset akumulatif (seamless timeline)
local function quantize(v, decimals)
	local m = 10 ^ decimals
	return math.floor(v * m + 0.5) / m
end

local function sortedRecordingFiles(ws)
	local files = listRecordings(ws)
	table.sort(files, function(a, b)
		-- Sort numeric suffix jika ada (Stage1 < Stage2 < Stage10)
		local na = tonumber(a:match("(%d+)$"))
		local nb = tonumber(b:match("(%d+)$"))
		if na and nb then return na < nb end
		return a < b
	end)
	return files
end

local function mergeWorkspace(ws, outName)
	ws = ws or state.currentWorkspace or CONFIG.WORKSPACE_DEFAULT
	local files = sortedRecordingFiles(ws)
	if #files == 0 then return false, "no files in workspace" end

	-- Temporarily switch context so loadFromFile reads correct workspace
	local prevWs = state.currentWorkspace
	state.currentWorkspace = ws

	local mergedFrames = {}
	local timeOffset = 0
	local sourceList = {}
	local totalRaw   = 0
	local rigType, fps, placeId, jobId, hipHeight, rootHeight

	for _, fname in ipairs(files) do
		-- Skip hasil merge sebelumnya biar gak rekursif dobel
		if fname:match("_MERGED$") then
			-- skip
		else
			local ok, data = loadFromFile(fname)
			if ok and data then
				local frames = data.Frames or data.frames or {}
				if #frames > 0 then
					totalRaw = totalRaw + #frames
					sourceList[#sourceList + 1] = fname
					rigType    = rigType    or data.RigType   or data.rigType
					fps        = fps        or data.FPS       or data.fps
					placeId    = placeId    or data.PlaceId
					jobId      = jobId      or data.JobId
					hipHeight  = hipHeight  or data.HipHeight
					rootHeight = rootHeight or data.RootHeight
					local baseT = frames[1].t or 0
					-- Keep SEMUA frame apa adanya (raw), cuma retime biar timeline nyambung.
					-- Tidak ada quantize / dedup / smoothing — playback jadi identik
					-- dengan play recording asli.
					for _, f in ipairs(frames) do
						local nf = {}
						for k, v in pairs(f) do nf[k] = v end
						nf.t = (f.t or 0) - baseT + timeOffset
						mergedFrames[#mergedFrames + 1] = nf
					end
					-- Update timeOffset: pakai interval rata-rata asli dari segmen ini
					-- supaya boundary antar segmen seamless ala recording asli.
					local lastT = frames[#frames].t or baseT
					local avgInterval = 1 / (fps or 60)
					if #frames >= 2 then
						avgInterval = (lastT - baseT) / math.max(1, #frames - 1)
					end
					timeOffset = timeOffset + (lastT - baseT) + avgInterval
				end
			end
		end
	end

	state.currentWorkspace = prevWs

	if #mergedFrames == 0 then
		return false, "no frames after merge"
	end

	-- Build file name (inline game name extraction karena extractGameName belum ada di scope)
	local gameName = "Game"
	pcall(function()
		local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		if info and info.Name then
			gameName = info.Name:match("^([%w_%-]+)") or info.Name
		end
	end)
	local baseName = (outName and outName ~= "") and outName or (safeName(gameName) .. "_MERGED")
	baseName = safeName(baseName)

	-- Build optimized output data (preserve metadata yang dipakai playback)
	local mergedData = {
		Version   = 2,
		Mode      = "Flexible",
		Merged    = true,
		FPS       = fps or CONFIG.FPS,
		PlaceId   = placeId or game.PlaceId,
		JobId     = jobId or game.JobId,
		RigType   = rigType or "R15",
		HipHeight = hipHeight,
		RootHeight = rootHeight,
		Sources   = sourceList,
		FrameCount    = #mergedFrames,
		RawFrameCount = totalRaw,
		Duration  = mergedFrames[#mergedFrames].t or 0,
		Frames    = mergedFrames,
	}

	local json = HttpService:JSONEncode(mergedData)
	if not writefile then return false, "writefile not supported" end
	local wsPath = getWorkspacePath(ws)
	if not ensureFolder(wsPath) then return false, "folder failed" end
	local path = wsPath .. "/" .. baseName .. ".json"
	local ok, err = pcall(writefile, path, json)
	if not ok then return false, tostring(err) end
	return true, {
		path       = path,
		name       = baseName,
		sources    = #sourceList,
		rawFrames  = totalRaw,
		finalFrames = #mergedFrames,
		reduction  = totalRaw > 0 and (1 - #mergedFrames/totalRaw) or 0,
		duration   = mergedFrames[#mergedFrames].t or 0,
		bytes      = #json,
	}
end

----------------------------------------------------------------
-- Forward declarations (resolved later)
----------------------------------------------------------------
local stopRecording

----------------------------------------------------------------
-- Auto-Checkpoint System (StarshipCore-style)
----------------------------------------------------------------
local cleanupCheckpointMonitor, setupCheckpointMonitor, saveCheckpointSegment

local function getLeaderstatsFolder()
	if not LP then return nil end
	return LP:FindFirstChild("leaderstats")
end

local function detectLeaderstatsList()
	local folder = getLeaderstatsFolder()
	if not folder then return {} end
	local results, seen = {}, {}
	for _, name in ipairs(LEADERSTAT_NAMES) do
		local stat = folder:FindFirstChild(name)
		if not stat then
			for _, child in ipairs(folder:GetChildren()) do
				if child.Name:lower() == name:lower() then
					stat = child break
				end
			end
		end
		if stat and not seen[stat] then
			table.insert(results, { Stat = stat, Name = stat.Name })
			seen[stat] = true
		end
	end
	return results
end

local function detectLeaderstat()
	local list = detectLeaderstatsList()
	if #list > 0 then return list[1].Stat, list[1].Name end
	return nil, nil
end

local function extractStageNumber(val)
	if val == nil then return 0 end
	local n = tonumber(val)
	if n then return n end
	local s = tostring(val):lower()
	if s == "" or s == "-" or s == "--" or s == "n/a" or s == "none" or s == "null" then return 0 end
	if s == "start" or s == "spawn" or s == "lobby" or s == "base" or s == "begin" then return 0 end
	if s == "summit" or s == "finish" or s == "end" or s == "goal" or s == "complete" then return 99999 end
	local m = tostring(val):match("(%d+)")
	if m then return tonumber(m) or 0 end
	return 0
end

local function extractGameName()
	local ok, info = pcall(function()
		return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
	end)
	local full = (ok and info and info.Name) or "Game"
	-- Extract first 1-2 words for short name
	local short = full:match("^([%w_%-]+)") or full
	return safeName(short)
end

saveCheckpointSegment = function(stageValue, isIncrease, statName)
	local total = #state.frames
	local startF = state.cpStartFrame or 1
	local segCount = total - startF + 1
	if segCount < 10 then
		log("[Checkpoint] Skipped (too few frames):", segCount)
		return false
	end

	local baseName = state.cpBaseName
	if baseName == "" or not baseName then
		baseName = extractGameName()
	end
	local sName = statName or "Stage"
	local stageSuffix
	if tonumber(stageValue) == 0 then
		stageSuffix = "_" .. sName .. "_Start"
	else
		stageSuffix = "_" .. sName .. tostring(stageValue)
	end
	local filename = baseName .. stageSuffix

	-- Build segment data
	local segFrames = {}
	local startTime = state.frames[startF] and state.frames[startF].t or 0
	for i = startF, total do
		local f = state.frames[i]
		if f then
			local nf = {}
			for k, v in pairs(f) do nf[k] = v end
			nf.t = f.t - startTime
			table.insert(segFrames, nf)
		end
	end

	local char, hum = getCharacter()
	local rigType = isR6(char) and "R6" or "R15"
	local rootH   = getCharRootHeight(char)
	local segData = {
		Version    = 2,
		Mode       = "Flexible",
		FPS        = CONFIG.FPS,
		PlaceId    = game.PlaceId,
		JobId      = game.JobId,
		UserId     = LP.UserId,
		Username   = LP.Name,
		RigType    = rigType,
		HipHeight  = (hum and hum.HipHeight) or 0,
		RootHeight = rootH,
		Duration   = segFrames[#segFrames] and segFrames[#segFrames].t or 0,
		FrameCount = #segFrames,
		CheckpointStage     = stageValue,
		CheckpointStatName  = sName,
		IsCheckpointSave    = true,
		SavedAt             = os.time(),
		Frames     = segFrames,
	}

	local ok, json = pcall(function() return HttpService:JSONEncode(segData) end)
	if not ok or not json then
		log("[Checkpoint] Encode failed")
		return false
	end
	local wsPath = getWorkspacePath(state.currentWorkspace)
	if not writefile or not ensureFolder(wsPath) then
		log("[Checkpoint] writefile not available")
		return false
	end
	local path = wsPath .. "/" .. filename .. ".json"
	local wOk, wErr = pcall(writefile, path, json)
	if not wOk then
		log("[Checkpoint] Write failed:", wErr)
		return false
	end

	state.cpSaveCount  = state.cpSaveCount + 1
	state.cpStartFrame = total + 1

	log(string.format("[Checkpoint] Saved %s (frames %d-%d, %.2fs)",
		filename, startF, total, segData.Duration))

	-- Refresh UI file list if available (UI sets state.onFileChange after init)
	if state.onFileChange then
		pcall(state.onFileChange)
	end

	-- Auto-stop logic: summit (stage=0 from non-zero) ALWAYS stops, normal CP respects flag
	local isSummit = (tonumber(stageValue) == 0 and not isIncrease)
		or (statName and statName:lower():find("summit"))
	local willAutoStop = isSummit or (state.cpAutoStop and isIncrease)

	return true, path, willAutoStop, isSummit, filename
end

setupCheckpointMonitor = function()
	cleanupCheckpointMonitor()
	if not state.cpEnabled then return end

	local list = detectLeaderstatsList()
	if #list == 0 then
		log("[Checkpoint] No leaderstat found")
		state.cpDetected = nil
		return
	end

	state.cpDetected = list[1].Name
	state.cpLastValues = {}
	log("[Checkpoint] Monitoring", #list, "leaderstats; primary:", list[1].Name)

	for _, item in ipairs(list) do
		local stat, name = item.Stat, item.Name
		state.cpLastValues[name] = stat.Value
		local conn = stat.Changed:Connect(function(newValue)
			if not state.recording or state.paused then return end
			local oldValue = state.cpLastValues[name]
			if oldValue == newValue then return end

			local numNew = extractStageNumber(newValue)
			local numOld = extractStageNumber(oldValue)
			state.cpLastValues[name] = newValue

			local isIncrease = numNew > numOld
			local isLoopBack = numNew == 0 and numOld > 0

			log(string.format("[Checkpoint] %s: %s -> %s (%d -> %d)",
				name, tostring(oldValue), tostring(newValue), numOld, numNew))

			if isIncrease or (numNew == numOld and newValue ~= oldValue) then
				local ok, path, autoStop, isSummit, fname = saveCheckpointSegment(newValue, true, name)
				if ok and autoStop then
					log("[Checkpoint] Auto-stop triggered:", fname, isSummit and "(SUMMIT)" or "")
					-- delay to next frame so save fully flushes
					task.spawn(function()
						task.wait()
						stopRecording()
					end)
				end
			elseif isLoopBack then
				-- Treat loop-back as summit: save & autostop
				local ok, path, autoStop, isSummit, fname = saveCheckpointSegment(newValue, false, name)
				if ok then
					log("[Checkpoint] Loop-back / summit:", fname)
					task.spawn(function()
						task.wait()
						stopRecording()
					end)
				end
			else
				-- Decrease (e.g. fall back) — save without autostop
				saveCheckpointSegment(newValue, false, name)
			end
		end)
		table.insert(state.cpConns, conn)
	end
end

cleanupCheckpointMonitor = function()
	for _, c in ipairs(state.cpConns) do
		pcall(function() c:Disconnect() end)
	end
	state.cpConns = {}
	state.cpLastValues = {}
end

----------------------------------------------------------------
-- Recording (StarshipCore Flexible Mode)
----------------------------------------------------------------
local function disconnectAll()
	for _, c in ipairs(state.conns) do
		pcall(function() c:Disconnect() end)
	end
	state.conns = {}
end

local function startRecording()
	if state.recording then return end
	local char, hum, root = getCharacter()
	if not char or not hum or not root then
		warn("[LocalFlex] Character belum siap")
		return
	end
	state.recording  = true
	state.paused     = false
	state.startTime  = os.clock()
	state.lastSample = 0
	state.frames     = {}

	local interval = 1 / math.max(1, CONFIG.FPS)

	table.insert(state.conns, RunService.Heartbeat:Connect(function()
		if not state.recording or state.paused then return end
		local now = os.clock()
		if now - state.lastSample < interval then return end
		state.lastSample = now

		local c, h, r = getCharacter()
		if not c or not h or not r then return end

		local cam = workspace.CurrentCamera
		local fd = { t = now - state.startTime }

		-- Core physics & input (StarshipCore flexible format)
		fd.pos = v3(r.Position)
		fd.rot = r.Orientation.Y
		fd.vel = v3(r.AssemblyLinearVelocity)
		fd.md  = v3(h.MoveDirection)
		fd.st  = tostring(h:GetState())
		fd.jmp = h.Jump
		fd.hh  = h.HipHeight
		fd.ws  = h.WalkSpeed

		-- Camera & shiftlock
		if cam then
			fd.camLook = v3(cam.CFrame.LookVector)
		end
		fd.charLook  = v3(r.CFrame.LookVector)
		fd.shiftlock = (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)
			or (math.abs(h.CameraOffset.X) > 0.5)

		-- Tool fingerprint
		recordToolFingerprint(fd, c)

		table.insert(state.frames, fd)

	end))

	-- Reset checkpoint segment tracker + start monitor if enabled
	state.cpStartFrame = 1
	state.cpSaveCount  = 0
	if state.cpEnabled then
		setupCheckpointMonitor()
	end

	-- Reset refall tracking
	state.lastSafePos   = root.Position
	state.lastSafeRot   = root.Orientation.Y
	state.lastSafeFrame = 0
	state.fallStartTime = nil
	state.refallCount   = 0

	log("Recording started")
end

stopRecording = function()
	if not state.recording then return end
	state.recording = false
	state.paused    = false
	cleanupCheckpointMonitor()
	disconnectAll()

	-- Optional smoothing
	if CONFIG.SMOOTH and #state.frames > 10 then
		state.frames = smoothFrames(state.frames, CONFIG.SMOOTH_STRENGTH)
	end

	log("Recording stopped:", #state.frames, "frames")
	if CONFIG.AUTO_COPY_STOP then
		copyToClipboard()
	end
	-- Tutup rewind panel kalau lagi kebuka
	state.rewindOpen = false
	if state.onRewindClose then pcall(state.onRewindClose) end
end

local function pauseRecording()
	if not state.recording then return end
	state.paused = not state.paused
end

-- Cek apakah posisi punya part solid yang bisa diinjak di bawahnya.
-- Pakai raycast pendek (5 stud) ke bawah dari pos+1 untuk verifikasi.
local function hasWalkableGroundBelow(pos)
	if not pos then return false end
	local char = LP.Character
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = char and { char } or {}
	rayParams.IgnoreWater = false
	local origin = pos + Vector3.new(0, 1, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -8, 0), rayParams)
	if not result then return false end
	-- Pastikan part-nya solid (CanCollide) dan bukan air-only material
	local part = result.Instance
	if not part or not part.CanCollide then return false end
	-- Skip non-walkable: water, slippery edge cases ditangani game-side
	return true
end

-- Cari "before fall" time dari rekaman (algoritma StarshipCore + walkable check).
-- Return: time (detik) atau nil + alasan
local REFALL_MARGIN = 0.5
local function findBeforeFallTime()
	if #state.frames < 2 then return nil, "no history" end
	local cutAt = 0
	local wasInAir = false
	for i = #state.frames, 1, -1 do
		local f = state.frames[i]
		local stName = (f.st and f.st:match("%.([%w_]+)$")) or ""
		local isInAir  = (stName == "Jumping" or stName == "Freefall")
		local isGround = (stName == "Running" or stName == "Landed" or stName == "RunningNoPhysics")
		if isInAir then
			wasInAir = true
		elseif wasInAir and isGround and f.pos then
			if hasWalkableGroundBelow(tblToV3(f.pos)) then
				cutAt = i
				break
			end
		end
	end
	if cutAt == 0 then
		return nil, (wasInAir and "no valid ground before fall" or "no fall found")
	end
	local takeoffTime = state.frames[cutAt].t
	return math.max(0, takeoffTime - REFALL_MARGIN)
end

-- Cari frame index untuk waktu tertentu (binary-ish search)
local function frameIndexAtTime(t)
	if #state.frames == 0 then return 0 end
	if t >= state.frames[#state.frames].t then return #state.frames end
	if t <= 0 then return 1 end
	for i = #state.frames, 1, -1 do
		if state.frames[i].t <= t then
			return i
		end
	end
	return 1
end

-- Preview: teleport karakter langsung ke posisi frame target.
-- Karakter di-anchor (di openRewindPanel) supaya tidak gerak akibat physics.
local function previewAtTime(t)
	local idx = frameIndexAtTime(t)
	local f = state.frames[idx]
	if not f or not f.pos then return end
	local _, _, root = getCharacter()
	if not root then return end
	pcall(function()
		root.CFrame = CFrame.new(tblToV3(f.pos))
			* CFrame.Angles(0, math.rad(f.rot or 0), 0)
		root.AssemblyLinearVelocity  = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
end

local function destroyPreviewMarker() end  -- no-op (kompat)

-- Apply: potong frame setelah cutTime, restore karakter, lanjut recording.
-- (Bagian ini hanya dipanggil dari slider RESUME button)
local function applyRewindCut(cutTime)
	if #state.frames == 0 then return false, "no frames" end
	cutTime = math.max(0, math.min(cutTime, state.frames[#state.frames].t))
	local cutAt = frameIndexAtTime(cutTime)
	local target = state.frames[cutAt]
	if not target then return false, "invalid cut" end

	-- Kalau char mati saat panel kebuka, tunggu respawn (max 8 detik)
	local _, hum, root = getCharacter()
	if not root or not hum then
		local t0 = os.clock()
		while os.clock() - t0 < 8 do
			task.wait(0.1)
			_, hum, root = getCharacter()
			if root and hum and hum.Health > 0 then break end
		end
		if not root or not hum then return false, "char tidak respawn dalam 8s" end
		-- Brief delay biar character fully loaded
		task.wait(0.1)
	end

	-- Teleport ke posisi target + restore momentum dari rekaman
	pcall(function()
		root.CFrame = CFrame.new(tblToV3(target.pos))
			* CFrame.Angles(0, math.rad(target.rot or 0), 0)
		root.AssemblyLinearVelocity = target.vel and tblToV3(target.vel) or Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = false
		hum:ChangeState(Enum.HumanoidStateType.Landed)
		local animate = hum.Parent and hum.Parent:FindFirstChild("Animate")
		if animate then animate.Disabled = false end
	end)

	-- Potong frame setelah cutAt
	local cutCount = 0
	for i = #state.frames, cutAt + 1, -1 do
		state.frames[i] = nil
		cutCount = cutCount + 1
	end
	if state.cpStartFrame > cutAt + 1 then
		state.cpStartFrame = cutAt + 1
	end
	-- Continuous timeline: next sample t ≈ target.t + interval
	state.startTime  = os.clock() - target.t
	state.lastSample = 0
	state.paused     = false
	state.refallCount = state.refallCount + 1
	log(string.format("[Rewind] cut @%.2fs (frame %d), potong %d frame", target.t, cutAt, cutCount))
	return true, cutAt, cutCount
end

----------------------------------------------------------------
-- Playback (StarspacePlayback approach, simplified)
----------------------------------------------------------------
local stopPlayback

local function applyHumanoidState(hum, stateName, velY)
	if not hum or not stateName then return end
	local target
	if stateName == "Jumping" then
		target = Enum.HumanoidStateType.Jumping
	elseif stateName == "Freefall" then
		target = Enum.HumanoidStateType.Freefall
	elseif stateName == "Landed" then
		target = Enum.HumanoidStateType.Landed
	elseif stateName == "Running" or stateName == "RunningNoPhysics" then
		target = Enum.HumanoidStateType.Running
	elseif stateName == "Climbing" then
		target = Enum.HumanoidStateType.Climbing
	elseif stateName == "Swimming" then
		target = Enum.HumanoidStateType.Swimming
	elseif stateName == "Seated" then
		target = Enum.HumanoidStateType.Seated
	end
	if not target then return end
	if state.lastState ~= target then
		state.lastState = target
		pcall(function() hum:ChangeState(target) end)
		if target == Enum.HumanoidStateType.Jumping then
			pcall(function() hum.Jump = true end)
		end
	end
end

local function applyShiftLock(hum, frame)
	if frame.shiftlock == nil then return end
	if frame.shiftlock and state.lastShift ~= true then
		state.lastShift = true
		pcall(function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end)
		pcall(function()
			hum.CameraOffset = Vector3.new(1.75, 0, 0)
		end)
	elseif not frame.shiftlock and state.lastShift ~= false then
		state.lastShift = false
		pcall(function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end)
		pcall(function() hum.CameraOffset = Vector3.zero end)
	end
end

stopPlayback = function()
	if state.playConn then
		pcall(function() state.playConn:Disconnect() end)
	end
	state.playing      = false
	state.playConn     = nil
	state.lastState    = nil
	state.lastShift    = nil
	state.wasInAir     = false
	state.lastAirState = nil

	local char, hum, root = getCharacter()
	if root then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	if hum then
		hum.AutoRotate = true
		if state.oldWalkSpd then
			hum.WalkSpeed = state.oldWalkSpd
			state.oldWalkSpd = nil
		end
		pcall(function() hum.CameraOffset = Vector3.zero end)
		pcall(function() hum:Move(Vector3.zero, false) end)
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
				pcall(function() t:Stop(0.1) end)
			end
		end
	end
	if state.oldMouseBeh then
		pcall(function()
			UserInputService.MouseBehavior = state.oldMouseBeh
		end)
		state.oldMouseBeh = nil
	end
	log("Playback stopped")
end

local function startPlayback(fileName)
	if state.recording then stopRecording() end
	if state.playing then stopPlayback() end

	-- Load data: from file or in-memory
	local data
	if fileName and fileName ~= "" then
		local ok, d = loadFromFile(fileName)
		if ok then
			data = d
		elseif state.frames and #state.frames > 0 then
			data = buildData()
		else
			return false, d or "no data"
		end
	elseif state.frames and #state.frames > 0 then
		data = buildData()
	else
		return false, "no data"
	end

	local frames = data.Frames or data.frames or data
	if not frames or #frames == 0 then
		return false, "no frames"
	end

	frames = preprocessFrames(frames)
	state.playFrames = frames
	state.playData   = data
	state.playStart  = os.clock()
	state.curTime    = 0
	state.lastTime   = 0
	state.lastFrameIdx = 1
	state.lastState  = nil
	state.lastShift  = nil
	state.wasInAir   = false
	state.lastAirState = nil

	-- Cross-rig setup
	local char, hum, root = getCharacter()
	if not char or not hum or not root then
		return false, "no character"
	end

	state.pbIsR6 = isR6(char)
	local playRootH = getCharRootHeight(char)

	local recRig = data.RigType
	if not recRig then
		local f1 = frames[1]
		recRig = (f1 and f1.hh and f1.hh < 0.5) and "R6" or "R15"
	end

	local recHipH = data.HipHeight
	if not recHipH then
		local f1 = frames[1]
		recHipH = (f1 and f1.hh) or ((recRig == "R15") and 2.0 or 0)
	end

	local recRootH = tonumber(data.RootHeight)
	if not recRootH or recRootH == 0 then
		if recRig == "R6" then
			recRootH = 3.0
		else
			recRootH = recHipH + 1.0
		end
	end

	if recRig ~= (state.pbIsR6 and "R6" or "R15") then
		state.yOffset = playRootH - recRootH
	else
		state.yOffset = (hum.HipHeight or 0) - recHipH
	end
	log("Playback start | Rec:", recRig, "Play:", state.pbIsR6 and "R6" or "R15",
		"| Y offset:", string.format("%.2f", state.yOffset))

	-- Save mouse behavior to restore later
	state.oldMouseBeh = UserInputService.MouseBehavior
	state.oldWalkSpd  = hum.WalkSpeed

	-- R6 needs HipHeight = 0
	if state.pbIsR6 and hum.HipHeight ~= 0 then
		hum.HipHeight = 0
	end

	-- Restart Animate to ensure proper anim setup
	local animate = char:FindFirstChild("Animate")
	if animate then
		animate.Disabled = true
		task.wait(0.05)
		animate.Disabled = false
		if state.pbIsR6 then
			task.spawn(function()
				task.wait(0.1)
				pcall(function() hum:Move(Vector3.zero) end)
			end)
		end
	end

	hum.AutoRotate = true
	state.playing  = true

	-- ===== Main playback loop (Heartbeat = physics-synced, anti-vibration) =====
	state.playConn = RunService.Heartbeat:Connect(function(dt)
		if not state.playing then return end
		local ok, err = pcall(function()
			local c, h, r = getCharacter()
			if not c or not h or not r then return end

			-- Time advance
			local updateDt = dt * (state.playSpeed or 1)
			state.curTime  = state.curTime + updateDt

			local total = frames[#frames].t or 0
			if state.curTime >= total then
				stopPlayback()
				return
			end

			-- Detect time jump (for slider seeking, here unused but safe)
			local expected = updateDt
			local actual   = math.abs(state.curTime - state.lastTime)
			local isJump   = actual > (expected * 3 + 0.1)
			state.lastTime = state.curTime

			-- Find frames
			local idx = findFrameIndex(frames, state.curTime, state.lastFrameIdx)
			state.lastFrameIdx = idx
			local fA, fB = frames[idx], frames[idx + 1]
			if not fA or not fB then return end

			local deltaT = fB.t - fA.t
			local alpha  = (deltaT > 0.0001) and ((state.curTime - fA.t) / deltaT) or 0

			-- Teleport detection (large position jump in short time)
			local isTeleport = false
			if deltaT > 0.3 and fA.posVector and fB.posVector then
				if (fB.posVector - fA.posVector).Magnitude > 30 then
					isTeleport = true
				end
			end

			-- Smooth interpolation
			local sPos, sVel, sLook
			if isTeleport then
				if alpha > 0.5 then
					sPos  = fB.posVector
					sVel  = fB.velVector
					sLook = fB.charLookVector
				else
					sPos  = fA.posVector
					sVel  = fA.velVector
					sLook = fA.charLookVector
				end
			else
				sPos, sVel, sLook = smoothInterp(frames, idx, alpha)
			end

			-- Cross-rig height offset
			if state.yOffset ~= 0 and sPos then
				sPos = Vector3.new(sPos.X, sPos.Y + state.yOffset, sPos.Z)
			end

			local stateName = fA.stEnum or "Running"
			local isAir = (stateName == "Jumping" or stateName == "Freefall")
			local isClimbing = (stateName == "Climbing")
			local isSwimming = (stateName == "Swimming")

			-- Detect landing
			local justLanded = state.wasInAir and not isAir
			if state.wasInAir and not justLanded and stateName == "Freefall" then
				local velY = (fA.velVector and fA.velVector.Y) or 0
				if h.FloorMaterial ~= Enum.Material.Air and velY < 5 then
					justLanded = true
					isAir = false
				end
			end
			state.wasInAir = isAir

			-- ===== State handling & physics ownership =====
			if isAir then
				-- DO NOT anchor — let physics handle the arc naturally.
				-- We guide via velocity blending + spring correction below.
				r.Anchored = false
				-- VELOCITY is the source of truth for jump-vs-fall.
				-- This filters out spam-jump artifacts where state cycles rapidly
				-- between Jumping and Freefall, which would trigger fall animation flicker.
				local velY = (fA.velVector and fA.velVector.Y) or 0
				local target
				if velY > 0.5 or stateName == "Jumping" then
					target = "jump"
				else
					target = "fall"
				end
				-- Look ahead: peek next frame's velY to predict landing/falling sooner
				if target == "fall" and fB.velVector and fB.velVector.Y > 5 then
					target = "jump"  -- next frame still going up = treat as jump
				end
				if state.lastAirState ~= target then
					state.lastAirState = target
					if target == "jump" then
						pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
						if state.pbIsR6 then h.Jump = true end
					else
						pcall(function() h:ChangeState(Enum.HumanoidStateType.Freefall) end)
						if state.pbIsR6 then h.Jump = false end
					end
				end
			elseif justLanded then
				r.Anchored = false
				if state.pbIsR6 then h.Jump = false end
				pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end)
				state.lastAirState = nil
			elseif isClimbing or isSwimming then
				r.Anchored = false
				pcall(function() h:ChangeState(Enum.HumanoidStateType[stateName]) end)
			elseif stateName == "Seated" then
				r.Anchored = false
				state.lastAirState = nil
				-- Don't force Running, keep seated state
				if h:GetState() ~= Enum.HumanoidStateType.Seated then
					pcall(function() h:ChangeState(Enum.HumanoidStateType.Seated) end)
				end
			else
				r.Anchored = false
				state.lastAirState = nil
				if h:GetState() == Enum.HumanoidStateType.Freefall or h:GetState() == Enum.HumanoidStateType.Jumping then
					pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end)
				end
			end

			-- ===== Movement & Position =====
			local finalRot = fA.rot or 0
			if fB.rot then
				local rotA = fA.rot or 0
				local rotB = fB.rot or 0
				local diff = (rotB - rotA + 180) % 360 - 180
				finalRot = rotA + diff * alpha
			end

			if isAir and sPos then
				-- AIR: physics-natural arc using velocity blending (StarSpace approach).
				-- No CFrame.Lerp force — just guide via spring correction + velocity blend.
				if isJump or isTeleport then
					-- Time jump / teleport: snap directly
					r.CFrame = CFrame.new(sPos) * CFrame.Angles(0, math.rad(finalRot), 0)
					if sVel then r.AssemblyLinearVelocity = sVel end
				else
					local curPos  = r.Position
					local posDiff = sPos - curPos
					local dist    = posDiff.Magnitude
					-- Spring force: weaker than ground (4x vs 6x) so jump arc stays natural
					local correctStr = math.clamp(dist * 4, 0, 40)
					local correctVel = (dist > 0.01) and (posDiff.Unit * correctStr) or Vector3.zero
					local targetVel  = (sVel or Vector3.zero) * (state.playSpeed or 1)
					local finalVel   = targetVel + correctVel
					if finalVel.Magnitude > 350 then
						finalVel = finalVel.Unit * 350
					end
					-- Lerp velocity (0.6) — smooth, not snappy
					r.AssemblyLinearVelocity = r.AssemblyLinearVelocity:Lerp(finalVel, 0.6)
					-- Soft rotation only
					local curRot = r.Orientation.Y
					local diff   = (finalRot - curRot + 180) % 360 - 180
					r.CFrame = CFrame.new(r.Position) * CFrame.Angles(0, math.rad(curRot + diff * 0.5), 0)
					-- Snap CFrame only when really off (>10 studs drift in air)
					if dist > 10 then
						r.CFrame = CFrame.new(sPos) * CFrame.Angles(0, math.rad(finalRot), 0)
					end
				end
			elseif isClimbing or isSwimming then
				-- CLIMBING / SWIMMING: apply full velocity (incl Y) + light pos blend
				-- Force state every frame to keep Animate playing climb/swim animation
				pcall(function()
					h:ChangeState(isClimbing and Enum.HumanoidStateType.Climbing or Enum.HumanoidStateType.Swimming)
				end)
				local vel = (sVel or Vector3.zero) * (state.playSpeed or 1)
				r.AssemblyLinearVelocity = vel
				-- Light position blend (50%) so character follows path but physics still runs
				if sPos then
					local newPos = r.Position:Lerp(sPos, 0.5)
					r.CFrame = CFrame.new(newPos) * CFrame.Angles(0, math.rad(finalRot), 0)
				end
				-- Move direction drives climb/swim animation
				local moveDir = fA.mdVector
				if moveDir and moveDir.Magnitude > 0.01 then
					pcall(function() h:Move(moveDir, false) end)
				elseif vel.Magnitude > 0.1 then
					pcall(function() h:Move(vel.Unit, false) end)
				else
					pcall(function() h:Move(Vector3.zero, false) end)
				end
			else
				-- GROUND (Running/Landed/Standing): position-via-velocity correction
				if sPos then
					local curPos  = r.Position
					local posDiff = sPos - curPos
					local dist    = posDiff.Magnitude

					-- Walk speed sync
					local rawSpeed = fA.ws or (sVel and sVel.Magnitude) or 16
					h.WalkSpeed = math.clamp(rawSpeed * (state.playSpeed or 1), 0.1, 350)

					-- Big drift: snap to prevent runaway
					if dist > 15 or isJump or isTeleport then
						r.CFrame = CFrame.new(sPos) * CFrame.Angles(0, math.rad(finalRot), 0)
					else
						-- Position correction injected as velocity
						local correctionStr = math.clamp(dist * 6, 0, 50)
						local correctVel = (dist > 0.01) and (posDiff.Unit * correctionStr) or Vector3.zero
						local targetVel  = (sVel or Vector3.zero) * (state.playSpeed or 1)
						local finalVel   = targetVel + correctVel
						local curVel     = r.AssemblyLinearVelocity
						r.AssemblyLinearVelocity = curVel:Lerp(finalVel, 0.6)
					end
				end

				-- Trigger walk/run animation via Move
				local moveDir = fA.mdVector
				if moveDir and moveDir.Magnitude > 0.01 then
					pcall(function() h:Move(moveDir, false) end)
				elseif sVel and sVel.Magnitude > 0.5 then
					local flat = Vector3.new(sVel.X, 0, sVel.Z)
					if flat.Magnitude > 0.1 then
						pcall(function() h:Move(flat.Unit, false) end)
					end
				else
					pcall(function() h:Move(Vector3.zero, false) end)
				end
			end

			-- Soft rotation (when not climbing/swimming)
			if not isClimbing and not isSwimming and not isAir then
				h.AutoRotate = false
				local curRot = r.Orientation.Y
				local diff   = (finalRot - curRot + 180) % 360 - 180
				local lerp   = state.pbIsR6 and 0.6 or 0.45
				local newRot = curRot + diff * lerp
				r.CFrame = CFrame.new(r.Position) * CFrame.Angles(0, math.rad(newRot), 0)
			else
				h.AutoRotate = true
			end

			-- Jump trigger (recorded jmp flag)
			if fA.jmp and state.lastAirState ~= "jump" then
				h.Jump = true
			end

			-- Apply state (skip for air since air block already handles it)
			if not isAir then
				applyHumanoidState(h, stateName, (fA.velVector and fA.velVector.Y) or 0)
			end
			applyShiftLock(h, fA)
			updateToolEquip(c, fA.tool, fA.toolTip, fA.toolColor, fA.toolConfig)
		end)
		if not ok then
			warn("[LocalFlex playback]", err)
		end
	end)

	log("Playback started:", #frames, "frames,", string.format("%.2fs", frames[#frames].t or 0))
	return true, "playing"
end

----------------------------------------------------------------
-- UI (Simple, native Roblox)
----------------------------------------------------------------
local oldGui = CoreGui:FindFirstChild("LocalFlexRecorderGui")
	or (LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("LocalFlexRecorderGui"))
if oldGui then pcall(function() oldGui:Destroy() end) end

local gui = Instance.new("ScreenGui")
gui.Name             = "LocalFlexRecorderGui"
gui.ResetOnSpawn     = false
gui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder     = 9999
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then
	gui.Parent = LP:WaitForChild("PlayerGui", 10)
end

local window = Instance.new("Frame")
window.Size            = UDim2.new(0, 340, 0, 580)
window.Position        = UDim2.new(0, 24, 0.5, -290)
window.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
window.BorderSizePixel = 0
window.Parent          = gui
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke", window)
stroke.Color        = Color3.fromRGB(90, 110, 245)
stroke.Transparency = 0.25

local title = Instance.new("TextLabel")
title.Size                 = UDim2.new(1, -44, 0, 34)
title.Position             = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text                 = "Local Flex Recorder"
title.TextColor3           = Color3.fromRGB(245, 245, 255)
title.Font                 = Enum.Font.GothamBold
title.TextSize             = 14
title.TextXAlignment       = Enum.TextXAlignment.Left
title.Parent               = window

local close = Instance.new("TextButton")
close.Size                 = UDim2.new(0, 34, 0, 34)
close.Position             = UDim2.new(1, -38, 0, 0)
close.BackgroundTransparency = 1
close.Text                 = "X"
close.TextColor3           = Color3.fromRGB(255, 85, 85)
close.Font                 = Enum.Font.GothamBold
close.TextSize             = 22
close.Parent               = window

local status = Instance.new("TextLabel")
status.Size              = UDim2.new(1, -24, 0, 44)
status.Position          = UDim2.new(0, 12, 0, 38)
status.BackgroundColor3  = Color3.fromRGB(22, 22, 31)
status.TextColor3        = Color3.fromRGB(190, 190, 210)
status.Font              = Enum.Font.Gotham
status.TextSize          = 12
status.Text              = "Ready | 0 frames | 0.0s"
status.TextWrapped       = true
status.Parent            = window
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 8)

local fileBox = Instance.new("TextBox")
fileBox.Size              = UDim2.new(1, -24, 0, 32)
fileBox.Position          = UDim2.new(0, 12, 0, 90)
fileBox.BackgroundColor3  = Color3.fromRGB(22, 22, 31)
fileBox.TextColor3        = Color3.fromRGB(245, 245, 255)
fileBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 140)
fileBox.PlaceholderText   = "Nama file / nama workspace baru"
fileBox.Text              = "LocalRec_" .. os.date("%H%M%S")
fileBox.Font              = Enum.Font.Gotham
fileBox.TextSize          = 12
fileBox.ClearTextOnFocus  = false
fileBox.Parent            = window
Instance.new("UICorner", fileBox).CornerRadius = UDim.new(0, 8)

local function makeBtn(text, x, y, w, color, parent)
	local b = Instance.new("TextButton")
	b.Size            = UDim2.new(0, w, 0, 32)
	b.Position        = UDim2.new(0, x, 0, y)
	b.BackgroundColor3 = color
	b.TextColor3      = Color3.fromRGB(255, 255, 255)
	b.Font            = Enum.Font.GothamBold
	b.TextSize        = 12
	b.Text            = text
	b.Parent          = parent or window
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

local function colorToggle(on, onCol, offCol)
	return on and onCol or offCol
end

-- Workspace row (y=130)
local wsLabel = Instance.new("TextLabel")
wsLabel.Size               = UDim2.new(0, 36, 0, 32)
wsLabel.Position           = UDim2.new(0, 12, 0, 130)
wsLabel.BackgroundTransparency = 1
wsLabel.TextColor3         = Color3.fromRGB(150, 150, 180)
wsLabel.Font               = Enum.Font.Gotham
wsLabel.TextSize           = 11
wsLabel.Text               = "WS:"
wsLabel.TextXAlignment     = Enum.TextXAlignment.Left
wsLabel.Parent             = window

local wsBtn      = makeBtn(state.currentWorkspace, 50, 130, 120, Color3.fromRGB(70, 110, 200))
local wsNewBtn   = makeBtn("+ NEW",                174, 130, 44,  Color3.fromRGB(55, 190, 120))
local wsDelBtn   = makeBtn("DEL",                  222, 130, 44,  Color3.fromRGB(180, 75, 75))
local wsMergeBtn = makeBtn("MERGE",                270, 130, 56,  Color3.fromRGB(200, 140, 50))

-- Main button rows
local recBtn      = makeBtn("REC",       12,  170, 76,  Color3.fromRGB(235, 70, 70))
local pauseBtn    = makeBtn("PAUSE",     94,  170, 76,  Color3.fromRGB(235, 180, 55))
local saveBtn     = makeBtn("SAVE",      176, 170, 76,  Color3.fromRGB(55, 190, 120))
local copyBtn     = makeBtn("COPY",      258, 170, 68,  Color3.fromRGB(90, 110, 245))
local playBtn     = makeBtn("PLAY",      12,  208, 156, Color3.fromRGB(65, 160, 255))
local stopPlayBtn = makeBtn("STOP PLAY", 174, 208, 152, Color3.fromRGB(180, 75, 75))

-- Auto-Checkpoint row
local cpBtn       = makeBtn(
	state.cpEnabled and "AUTO CP: ON" or "AUTO CP: OFF",
	12, 246, 156,
	colorToggle(state.cpEnabled, Color3.fromRGB(55, 190, 120), Color3.fromRGB(70, 70, 90)))
local cpStopBtn   = makeBtn(
	state.cpAutoStop and "AUTO STOP: ON" or "AUTO STOP: OFF",
	174, 246, 152,
	colorToggle(state.cpAutoStop, Color3.fromRGB(55, 190, 120), Color3.fromRGB(70, 70, 90)))

local cpStatus = Instance.new("TextLabel")
cpStatus.Size              = UDim2.new(1, -24, 0, 24)
cpStatus.Position          = UDim2.new(0, 12, 0, 284)
cpStatus.BackgroundColor3  = Color3.fromRGB(22, 22, 31)
cpStatus.TextColor3        = Color3.fromRGB(180, 180, 200)
cpStatus.Font              = Enum.Font.Gotham
cpStatus.TextSize          = 11
cpStatus.Text              = "CP: idle"
cpStatus.TextWrapped       = true
cpStatus.TextXAlignment    = Enum.TextXAlignment.Left
cpStatus.Parent            = window
local cpStatusPad = Instance.new("UIPadding", cpStatus)
cpStatusPad.PaddingLeft    = UDim.new(0, 8)
cpStatusPad.PaddingRight   = UDim.new(0, 8)
Instance.new("UICorner", cpStatus).CornerRadius = UDim.new(0, 8)

-- Refall toggle (y=314)
local refallBtn = makeBtn(
	state.refallEnabled and "REFALL: ON" or "REFALL: OFF",
	12, 314, 314,
	colorToggle(state.refallEnabled, Color3.fromRGB(255, 130, 50), Color3.fromRGB(70, 70, 90)))

local refallStatus = Instance.new("TextLabel")
refallStatus.Size              = UDim2.new(1, -24, 0, 22)
refallStatus.Position          = UDim2.new(0, 12, 0, 352)
refallStatus.BackgroundTransparency = 1
refallStatus.TextColor3        = Color3.fromRGB(150, 150, 170)
refallStatus.Font              = Enum.Font.Gotham
refallStatus.TextSize          = 10
refallStatus.Text              = "Refall: idle"
refallStatus.TextXAlignment    = Enum.TextXAlignment.Left
refallStatus.Parent            = window

-- File list header (y=380)
local listLabel = Instance.new("TextLabel")
listLabel.Size              = UDim2.new(1, -110, 0, 24)
listLabel.Position          = UDim2.new(0, 12, 0, 380)
listLabel.BackgroundTransparency = 1
listLabel.TextColor3        = Color3.fromRGB(170, 170, 195)
listLabel.Font              = Enum.Font.GothamBold
listLabel.TextSize          = 11
listLabel.Text              = "Files (0)"
listLabel.TextXAlignment    = Enum.TextXAlignment.Left
listLabel.Parent            = window
local refreshBtn = makeBtn("REFRESH", 244, 378, 82, Color3.fromRGB(90, 110, 245))
refreshBtn.TextSize = 11

-- File list scroll
local listFrame = Instance.new("ScrollingFrame")
listFrame.Size                  = UDim2.new(1, -24, 0, 168)
listFrame.Position              = UDim2.new(0, 12, 0, 408)
listFrame.BackgroundColor3      = Color3.fromRGB(18, 18, 26)
listFrame.BorderSizePixel       = 0
listFrame.ScrollBarThickness    = 5
listFrame.ScrollBarImageColor3  = Color3.fromRGB(90, 110, 245)
listFrame.CanvasSize            = UDim2.new(0, 0, 0, 0)
listFrame.AutomaticCanvasSize   = Enum.AutomaticSize.Y
listFrame.Parent                = window
Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 8)
local listLayout = Instance.new("UIListLayout", listFrame)
listLayout.SortOrder    = Enum.SortOrder.Name
listLayout.Padding      = UDim.new(0, 4)
local listPad = Instance.new("UIPadding", listFrame)
listPad.PaddingTop      = UDim.new(0, 6)
listPad.PaddingBottom   = UDim.new(0, 6)
listPad.PaddingLeft     = UDim.new(0, 6)
listPad.PaddingRight    = UDim.new(0, 6)

-- Refresh function (must be visible in handlers below)
local refreshFileList

----------------------------------------------------------------
-- Rewind Slider Panel (overlay, hidden by default)
----------------------------------------------------------------
local rewindPanel = Instance.new("Frame")
rewindPanel.Size              = UDim2.new(0, 320, 0, 130)
rewindPanel.Position          = UDim2.new(0.5, -160, 0.5, -65)
rewindPanel.BackgroundColor3  = Color3.fromRGB(20, 20, 30)
rewindPanel.BorderSizePixel   = 0
rewindPanel.Visible           = false
rewindPanel.ZIndex            = 100
rewindPanel.Parent            = gui
Instance.new("UICorner", rewindPanel).CornerRadius = UDim.new(0, 12)
local rwStroke = Instance.new("UIStroke", rewindPanel)
rwStroke.Color        = Color3.fromRGB(255, 130, 50)
rwStroke.Thickness    = 2
rwStroke.Transparency = 0.1

local rwTitle = Instance.new("TextLabel", rewindPanel)
rwTitle.Size                 = UDim2.new(1, -16, 0, 22)
rwTitle.Position             = UDim2.new(0, 8, 0, 6)
rwTitle.BackgroundTransparency = 1
rwTitle.Text                 = "REWIND — geser slider, lalu RESUME"
rwTitle.TextColor3           = Color3.fromRGB(255, 180, 80)
rwTitle.Font                 = Enum.Font.GothamBold
rwTitle.TextSize             = 12
rwTitle.TextXAlignment       = Enum.TextXAlignment.Left
rwTitle.ZIndex               = 101

local rwTime = Instance.new("TextLabel", rewindPanel)
rwTime.Size                  = UDim2.new(1, -16, 0, 18)
rwTime.Position              = UDim2.new(0, 8, 0, 28)
rwTime.BackgroundTransparency = 1
rwTime.Text                  = "0.0s / 0.0s"
rwTime.TextColor3            = Color3.fromRGB(220, 220, 240)
rwTime.Font                  = Enum.Font.Gotham
rwTime.TextSize              = 11
rwTime.TextXAlignment        = Enum.TextXAlignment.Right
rwTime.ZIndex                = 101

-- Slider
local rwSliderBg = Instance.new("TextButton", rewindPanel)
rwSliderBg.Text               = ""
rwSliderBg.Size               = UDim2.new(1, -32, 0, 8)
rwSliderBg.Position           = UDim2.new(0, 16, 0, 56)
rwSliderBg.BackgroundColor3   = Color3.fromRGB(40, 40, 55)
rwSliderBg.AutoButtonColor    = false
rwSliderBg.ZIndex             = 101
Instance.new("UICorner", rwSliderBg).CornerRadius = UDim.new(0, 4)
local rwSliderFill = Instance.new("Frame", rwSliderBg)
rwSliderFill.Size             = UDim2.new(0.5, 0, 1, 0)
rwSliderFill.BackgroundColor3 = Color3.fromRGB(255, 130, 50)
rwSliderFill.BorderSizePixel  = 0
rwSliderFill.ZIndex           = 102
Instance.new("UICorner", rwSliderFill).CornerRadius = UDim.new(0, 4)
local rwSliderKnob = Instance.new("Frame", rwSliderBg)
rwSliderKnob.Size              = UDim2.new(0, 14, 0, 14)
rwSliderKnob.Position          = UDim2.new(0.5, -7, 0.5, -7)
rwSliderKnob.BackgroundColor3  = Color3.fromRGB(255, 200, 130)
rwSliderKnob.BorderSizePixel   = 0
rwSliderKnob.ZIndex            = 103
Instance.new("UICorner", rwSliderKnob).CornerRadius = UDim.new(1, 0)

-- Buttons row
local rwBeforeFall = Instance.new("TextButton", rewindPanel)
rwBeforeFall.Size             = UDim2.new(0, 96, 0, 28)
rwBeforeFall.Position         = UDim2.new(0, 8, 1, -38)
rwBeforeFall.BackgroundColor3 = Color3.fromRGB(255, 130, 50)
rwBeforeFall.TextColor3       = Color3.fromRGB(255, 255, 255)
rwBeforeFall.Font             = Enum.Font.GothamBold
rwBeforeFall.TextSize         = 11
rwBeforeFall.Text             = "BEFORE FALL"
rwBeforeFall.ZIndex           = 101
Instance.new("UICorner", rwBeforeFall).CornerRadius = UDim.new(0, 6)

local rwResume = Instance.new("TextButton", rewindPanel)
rwResume.Size             = UDim2.new(0, 100, 0, 28)
rwResume.Position         = UDim2.new(0, 112, 1, -38)
rwResume.BackgroundColor3 = Color3.fromRGB(55, 190, 120)
rwResume.TextColor3       = Color3.fromRGB(255, 255, 255)
rwResume.Font             = Enum.Font.GothamBold
rwResume.TextSize         = 12
rwResume.Text             = "RESUME"
rwResume.ZIndex           = 101
Instance.new("UICorner", rwResume).CornerRadius = UDim.new(0, 6)

local rwCancel = Instance.new("TextButton", rewindPanel)
rwCancel.Size             = UDim2.new(0, 92, 0, 28)
rwCancel.Position         = UDim2.new(0, 220, 1, -38)
rwCancel.BackgroundColor3 = Color3.fromRGB(120, 120, 140)
rwCancel.TextColor3       = Color3.fromRGB(255, 255, 255)
rwCancel.Font             = Enum.Font.GothamBold
rwCancel.TextSize         = 12
rwCancel.Text             = "CANCEL"
rwCancel.ZIndex           = 101
Instance.new("UICorner", rwCancel).CornerRadius = UDim.new(0, 6)

local function getMaxRewindTime()
	if #state.frames == 0 then return 0 end
	return state.frames[#state.frames].t or 0
end

local function updateRewindUI()
	local maxT = getMaxRewindTime()
	local sel  = state.rewindSelectT or 0
	local pct  = (maxT > 0) and (sel / maxT) or 0
	pct = math.clamp(pct, 0, 1)
	rwSliderFill.Size = UDim2.new(pct, 0, 1, 0)
	rwSliderKnob.Position = UDim2.new(pct, -7, 0.5, -7)
	rwTime.Text = string.format("%.2fs / %.2fs", sel, maxT)
end

local function setRewindTime(t)
	local maxT = getMaxRewindTime()
	t = math.clamp(t, 0, maxT)
	state.rewindSelectT = t
	updateRewindUI()
	previewAtTime(t)
end

local function openRewindPanel()
	if not state.recording then
		status.Text = "Rewind hanya bisa saat recording"
		return
	end
	if #state.frames < 2 then
		status.Text = "Belum ada history"
		return
	end
	state.rewindOpen = true
	state.paused    = true
	pauseBtn.Text   = "(rewind)"
	-- Anchor karakter supaya tidak jatuh akibat physics saat user atur slider
	local _, _, root = getCharacter()
	if root then root.Anchored = true end
	-- Restore saved panel position (kalau user pernah drag sebelumnya)
	if state.rewindPanelPos then
		rewindPanel.Position = state.rewindPanelPos
	end
	-- Default slider ke "before fall" kalau ada, kalau tidak ke akhir rekaman
	local bft = findBeforeFallTime()
	state.rewindSelectT = bft or getMaxRewindTime()
	updateRewindUI()
	previewAtTime(state.rewindSelectT)
	rewindPanel.Visible = true
end

local function closeRewindPanel()
	rewindPanel.Visible = false
	state.rewindOpen    = false
	-- Unanchor karakter
	local _, _, root = getCharacter()
	if root then root.Anchored = false end
end

-- Expose close to non-UI module (stopRecording calls this if panel open)
state.onRewindClose = function()
	if rewindPanel.Visible then
		closeRewindPanel()
	end
end

-- Drag handler: pakai title bar sebagai handle (biar slider/button tetap responsif)
-- Convert title to interactive (TextButton dengan AutoButtonColor false)
rwTitle:Destroy()
local rwDragHandle = Instance.new("TextButton", rewindPanel)
rwDragHandle.Name              = "DragHandle"
rwDragHandle.Size              = UDim2.new(1, -16, 0, 22)
rwDragHandle.Position          = UDim2.new(0, 8, 0, 6)
rwDragHandle.BackgroundTransparency = 1
rwDragHandle.Text              = "REWIND — drag header untuk pindah panel"
rwDragHandle.TextColor3        = Color3.fromRGB(255, 180, 80)
rwDragHandle.Font              = Enum.Font.GothamBold
rwDragHandle.TextSize          = 12
rwDragHandle.TextXAlignment    = Enum.TextXAlignment.Left
rwDragHandle.AutoButtonColor   = false
rwDragHandle.ZIndex            = 101

local rwDrag = { active = false, input = nil, start = nil, pos = nil }
rwDragHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		rwDrag.active = true
		rwDrag.start  = input.Position
		rwDrag.pos    = rewindPanel.Position
	end
end)
rwDragHandle.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		rwDrag.input = input
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input == rwDrag.input and rwDrag.active then
		local d = input.Position - rwDrag.start
		local newPos = UDim2.new(
			rwDrag.pos.X.Scale, rwDrag.pos.X.Offset + d.X,
			rwDrag.pos.Y.Scale, rwDrag.pos.Y.Offset + d.Y
		)
		rewindPanel.Position = newPos
		state.rewindPanelPos = newPos  -- remember for next open
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		rwDrag.active = false
	end
end)

-- Slider drag
local rwDragging = false
local function rwHandleInput(input)
	local rx = input.Position.X - rwSliderBg.AbsolutePosition.X
	local pct = math.clamp(rx / rwSliderBg.AbsoluteSize.X, 0, 1)
	setRewindTime(pct * getMaxRewindTime())
end
rwSliderBg.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		rwDragging = true
		rwHandleInput(input)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not rwDragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		rwHandleInput(input)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		rwDragging = false
	end
end)

rwBeforeFall.MouseButton1Click:Connect(function()
	local bft, err = findBeforeFallTime()
	if bft then
		setRewindTime(bft)
		rwBeforeFall.BackgroundColor3 = Color3.fromRGB(55, 190, 120)
		task.delay(0.3, function()
			rwBeforeFall.BackgroundColor3 = Color3.fromRGB(255, 130, 50)
		end)
	else
		status.Text = "Before-fall: " .. tostring(err)
	end
end)

-- Countdown overlay (3..2..1..GO) — clean & big
local countdownLbl = Instance.new("TextLabel", gui)
countdownLbl.Size              = UDim2.new(0, 400, 0, 200)
countdownLbl.Position          = UDim2.new(0.5, -200, 0.5, -100)
countdownLbl.AnchorPoint       = Vector2.new(0, 0)
countdownLbl.BackgroundTransparency = 1
countdownLbl.TextColor3        = Color3.fromRGB(255, 200, 100)
countdownLbl.Font              = Enum.Font.GothamBlack
countdownLbl.TextSize          = 140
countdownLbl.TextStrokeTransparency = 0.3
countdownLbl.TextStrokeColor3  = Color3.fromRGB(15, 10, 5)
countdownLbl.Text              = "3"
countdownLbl.Visible           = false
countdownLbl.ZIndex            = 200

local function setRewindButtonsActive(active)
	rwResume.AutoButtonColor    = active
	rwResume.Active             = active
	rwBeforeFall.AutoButtonColor = active
	rwBeforeFall.Active         = active
	rwCancel.AutoButtonColor    = active
	rwCancel.Active             = active
end

rwResume.MouseButton1Click:Connect(function()
	if not rwResume.Active then return end
	setRewindButtonsActive(false)
	-- Countdown 3..2..1..GO
	task.spawn(function()
		countdownLbl.Visible = true
		for i = 3, 1, -1 do
			countdownLbl.Text = tostring(i)
			countdownLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
			task.wait(1)
		end
		countdownLbl.Text       = "GO!"
		countdownLbl.TextColor3 = Color3.fromRGB(120, 240, 160)
		task.wait(0.4)
		countdownLbl.Visible    = false
		-- Apply
		local ok, cutAt, cutCount = applyRewindCut(state.rewindSelectT)
		if ok then
			status.Text = string.format("Rewind applied | cut@frame %d, potong %d", cutAt, cutCount)
			pauseBtn.Text = "PAUSE"
		else
			status.Text = "Rewind failed: " .. tostring(cutAt)
		end
		closeRewindPanel()
		setRewindButtonsActive(true)
	end)
end)

rwCancel.MouseButton1Click:Connect(function()
	if not rwCancel.Active then return end
	-- Tidak ada teleport ke last frame: orang lain udah lihat kita fall
	-- jadi karakter dibiarkan apa adanya. Kalau mati, biarkan respawn natural.
	local last = state.frames[#state.frames]
	if last then
		state.startTime  = os.clock() - last.t
		state.lastSample = 0
	end
	state.paused  = false
	pauseBtn.Text = "PAUSE"
	closeRewindPanel()
	status.Text   = "Rewind cancelled"
end)

-- Drag
local drag = { active = false, input = nil, start = nil, pos = nil }
window.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		drag.active = true
		drag.start  = input.Position
		drag.pos    = window.Position
	end
end)
window.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		drag.input = input
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input == drag.input and drag.active then
		local d = input.Position - drag.start
		window.Position = UDim2.new(
			drag.pos.X.Scale, drag.pos.X.Offset + d.X,
			drag.pos.Y.Scale, drag.pos.Y.Offset + d.Y
		)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		drag.active = false
	end
end)

-- ===== Workspace + File List handlers =====

-- Path visualization (client-only via Camera parent)
local pathFolder
local function clearPath()
	if pathFolder then
		pcall(function() pathFolder:Destroy() end)
		pathFolder = nil
	end
end

local function drawPath(frames)
	clearPath()
	if not frames or #frames < 2 then return end
	pathFolder = Instance.new("Folder")
	pathFolder.Name   = "LocalFlexPathPreview"
	pathFolder.Parent = workspace.CurrentCamera  -- client-only
	-- Sample max 500 points
	local step = math.max(1, math.floor(#frames / 500))
	local prev = nil
	for i = 1, #frames, step do
		local f = frames[i]
		if f.pos then
			local pos = (type(f.pos) == "table") and Vector3.new(f.pos.x, f.pos.y, f.pos.z) or f.pos
			-- Dot at point
			local dot = Instance.new("Part")
			dot.Size = Vector3.new(0.4, 0.4, 0.4)
			dot.Shape = Enum.PartType.Ball
			dot.Color = Color3.fromRGB(80, 200, 255)
			dot.Material = Enum.Material.Neon
			dot.Anchored = true
			dot.CanCollide = false
			dot.CanQuery = false
			dot.CastShadow = false
			dot.Transparency = 0.3
			dot.Position = pos
			dot.Parent = pathFolder
			-- Line connector to previous
			if prev then
				local mid = (pos + prev) / 2
				local len = (pos - prev).Magnitude
				if len > 0.05 and len < 80 then
					local line = Instance.new("Part")
					line.Size = Vector3.new(0.12, 0.12, len)
					line.Color = Color3.fromRGB(80, 200, 255)
					line.Material = Enum.Material.Neon
					line.Anchored = true
					line.CanCollide = false
					line.CanQuery = false
					line.CastShadow = false
					line.Transparency = 0.55
					line.CFrame = CFrame.lookAt(mid, pos)
					line.Parent = pathFolder
				end
			end
			prev = pos
		end
	end
	-- Highlight start (green) & end (red)
	local first = frames[1]
	local last  = frames[#frames]
	if first and first.pos then
		local startPart = pathFolder:FindFirstChild("StartMarker") or Instance.new("Part")
		startPart.Name = "StartMarker"
		startPart.Size = Vector3.new(1.5, 1.5, 1.5)
		startPart.Shape = Enum.PartType.Ball
		startPart.Color = Color3.fromRGB(80, 230, 120)
		startPart.Material = Enum.Material.Neon
		startPart.Anchored = true
		startPart.CanCollide = false
		startPart.CanQuery = false
		startPart.CastShadow = false
		startPart.Transparency = 0.2
		startPart.Position = (type(first.pos) == "table")
			and Vector3.new(first.pos.x, first.pos.y, first.pos.z) or first.pos
		startPart.Parent = pathFolder
	end
	if last and last.pos then
		local endPart = Instance.new("Part")
		endPart.Name = "EndMarker"
		endPart.Size = Vector3.new(1.5, 1.5, 1.5)
		endPart.Shape = Enum.PartType.Ball
		endPart.Color = Color3.fromRGB(255, 90, 90)
		endPart.Material = Enum.Material.Neon
		endPart.Anchored = true
		endPart.CanCollide = false
		endPart.CanQuery = false
		endPart.CastShadow = false
		endPart.Transparency = 0.2
		endPart.Position = (type(last.pos) == "table")
			and Vector3.new(last.pos.x, last.pos.y, last.pos.z) or last.pos
		endPart.Parent = pathFolder
	end
end

-- Load file from disk and draw its path (for click-preview)
local function showPathForFile(fileName)
	local ok, data = loadFromFile(fileName)
	if not ok or not data then
		status.Text = "Path preview gagal: " .. tostring(data)
		clearPath()
		return false
	end
	local frames = data.Frames or data.frames or data
	if not frames or #frames < 2 then
		clearPath()
		return false
	end
	drawPath(frames)
	return true, #frames, (frames[#frames].t or 0)
end

-- Build a single row in the file list
local function buildFileRow(name)
	local row = Instance.new("Frame")
	row.Size            = UDim2.new(1, -8, 0, 28)
	row.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
	row.BorderSizePixel = 0
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

	local nameBtn = Instance.new("TextButton")
	nameBtn.Size               = UDim2.new(1, -64, 1, 0)
	nameBtn.Position           = UDim2.new(0, 0, 0, 0)
	nameBtn.BackgroundTransparency = 1
	nameBtn.TextColor3         = Color3.fromRGB(220, 220, 245)
	nameBtn.Font               = Enum.Font.Gotham
	nameBtn.TextSize           = 11
	nameBtn.TextXAlignment     = Enum.TextXAlignment.Left
	nameBtn.Text               = "  " .. name
	nameBtn.Parent             = row

	local playMini = Instance.new("TextButton")
	playMini.Size              = UDim2.new(0, 28, 0, 22)
	playMini.Position          = UDim2.new(1, -60, 0.5, -11)
	playMini.BackgroundColor3  = Color3.fromRGB(65, 160, 255)
	playMini.TextColor3        = Color3.fromRGB(255, 255, 255)
	playMini.Font              = Enum.Font.GothamBold
	playMini.TextSize          = 10
	playMini.Text              = "PLAY"
	playMini.Parent            = row
	Instance.new("UICorner", playMini).CornerRadius = UDim.new(0, 5)

	local delMini = Instance.new("TextButton")
	delMini.Size               = UDim2.new(0, 26, 0, 22)
	delMini.Position           = UDim2.new(1, -28, 0.5, -11)
	delMini.BackgroundColor3   = Color3.fromRGB(180, 75, 75)
	delMini.TextColor3         = Color3.fromRGB(255, 255, 255)
	delMini.Font               = Enum.Font.GothamBold
	delMini.TextSize           = 12
	delMini.Text               = "X"
	delMini.Parent             = row
	Instance.new("UICorner", delMini).CornerRadius = UDim.new(0, 5)

	-- Click name = load to fileBox + show path visualization
	nameBtn.MouseButton1Click:Connect(function()
		fileBox.Text = name
		local ok, count, dur = showPathForFile(name)
		if ok then
			status.Text = string.format("Selected: %s | path: %d pts, %.1fs", name, count, dur)
		else
			status.Text = "Selected: " .. name
		end
	end)

	-- Click PLAY mini = load + play
	playMini.MouseButton1Click:Connect(function()
		fileBox.Text = name
		local ok, res = startPlayback(name)
		if ok then
			status.Text   = "Playing: " .. name
			playBtn.Text  = "PLAYING"
		else
			status.Text   = "Play failed: " .. tostring(res)
		end
	end)

	-- Click X = delete
	delMini.MouseButton1Click:Connect(function()
		local ok, err = deleteRecording(state.currentWorkspace, name)
		if ok then
			status.Text = "Deleted: " .. name
			clearPath()
			refreshFileList()
		else
			status.Text = "Delete failed: " .. tostring(err)
		end
	end)

	return row
end

refreshFileList = function()
	-- Clear existing rows
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local files = listRecordings(state.currentWorkspace)
	listLabel.Text = string.format("Files (%d) — %s", #files, state.currentWorkspace)
	if #files == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size               = UDim2.new(1, -8, 0, 28)
		empty.BackgroundTransparency = 1
		empty.TextColor3         = Color3.fromRGB(120, 120, 140)
		empty.Font               = Enum.Font.Gotham
		empty.TextSize           = 11
		empty.Text               = "  (workspace kosong)"
		empty.TextXAlignment     = Enum.TextXAlignment.Left
		empty.Parent             = listFrame
		return
	end
	for _, name in ipairs(files) do
		local row = buildFileRow(name)
		row.Parent = listFrame
	end
end

-- Cycle workspace on click
wsBtn.MouseButton1Click:Connect(function()
	local list = listWorkspaces()
	if #list == 0 then list = { CONFIG.WORKSPACE_DEFAULT } end
	local idx = 1
	for i, n in ipairs(list) do
		if n == state.currentWorkspace then idx = i break end
	end
	idx = (idx % #list) + 1
	state.currentWorkspace = list[idx]
	wsBtn.Text = state.currentWorkspace
	status.Text = "Workspace: " .. state.currentWorkspace
	clearPath()
	refreshFileList()
end)

-- Create new workspace from filename input
wsNewBtn.MouseButton1Click:Connect(function()
	local name = safeName(fileBox.Text or "")
	if name == "" then
		status.Text = "Type workspace name in the box first"
		return
	end
	local ok, res = createWorkspace(name)
	if ok then
		state.currentWorkspace = name
		wsBtn.Text = name
		status.Text = "Created workspace: " .. name
		refreshFileList()
	else
		status.Text = "Create workspace failed: " .. tostring(res)
	end
end)

-- Merge all recordings in current workspace into one optimized file
wsMergeBtn.MouseButton1Click:Connect(function()
	if state.recording or state.playing then
		status.Text = "Stop recording/playback dulu sebelum merge"
		return
	end
	local outName = fileBox.Text
	if outName == "" then outName = nil end
	wsMergeBtn.Text = "MERGING..."
	wsMergeBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 140)
	task.spawn(function()
		local ok, res = mergeWorkspace(state.currentWorkspace, outName)
		if ok then
			local kb = res.bytes / 1024
			status.Text = string.format(
				"Merged %d files | %d frames | %.1fs | %.1f KB | %s",
				res.sources, res.finalFrames, res.duration, kb, res.name)
			log(string.format("[Merge] %d sources, %d frames, %.1f KB, saved to %s",
				res.sources, res.finalFrames, kb, res.path))
			refreshFileList()
		else
			status.Text = "Merge failed: " .. tostring(res)
		end
		wsMergeBtn.Text = "MERGE"
		wsMergeBtn.BackgroundColor3 = Color3.fromRGB(200, 140, 50)
	end)
end)

-- Delete current workspace (cannot delete Default)
wsDelBtn.MouseButton1Click:Connect(function()
	if state.currentWorkspace == CONFIG.WORKSPACE_DEFAULT then
		status.Text = "Cannot delete Default workspace"
		return
	end
	local target = state.currentWorkspace
	local ok, err = deleteWorkspace(target)
	if ok then
		state.currentWorkspace = CONFIG.WORKSPACE_DEFAULT
		wsBtn.Text = state.currentWorkspace
		status.Text = "Deleted workspace: " .. target
		refreshFileList()
	else
		status.Text = "Delete workspace failed: " .. tostring(err)
	end
end)

refreshBtn.MouseButton1Click:Connect(function()
	refreshFileList()
	status.Text = "List refreshed"
end)

-- Expose refresh to non-UI modules (auto-checkpoint saves)
state.onFileChange = refreshFileList

-- Initial populate
refreshFileList()

-- ===== Button handlers =====
recBtn.MouseButton1Click:Connect(function()
	if state.recording then
		stopRecording()
		recBtn.Text             = "REC"
		recBtn.BackgroundColor3 = Color3.fromRGB(235, 70, 70)
		status.Text             = string.format("Saved %d frames | %.2fs", #state.frames,
			state.frames[#state.frames] and state.frames[#state.frames].t or 0)
		refreshFileList()
	else
		startRecording()
		recBtn.Text             = "STOP"
		recBtn.BackgroundColor3 = Color3.fromRGB(180, 55, 55)
	end
end)

pauseBtn.MouseButton1Click:Connect(function()
	if not state.recording then return end
	pauseRecording()
	pauseBtn.Text = state.paused and "RESUME" or "PAUSE"
end)

saveBtn.MouseButton1Click:Connect(function()
	local ok, res = saveToFile(fileBox.Text, state.currentWorkspace)
	status.Text = ok and ("Saved: " .. tostring(res)) or ("Save failed: " .. tostring(res))
	if ok then refreshFileList() end
end)

copyBtn.MouseButton1Click:Connect(function()
	if copyToClipboard() then
		status.Text = "Copied JSON to clipboard | " .. #state.frames .. " frames"
	else
		status.Text = "Copy failed (setclipboard unsupported)"
	end
end)

playBtn.MouseButton1Click:Connect(function()
	local ok, res = startPlayback(fileBox.Text)
	if ok then
		status.Text   = "Playing: " .. fileBox.Text
		playBtn.Text  = "PLAYING"
	else
		status.Text   = "Play failed: " .. tostring(res)
	end
end)

stopPlayBtn.MouseButton1Click:Connect(function()
	stopPlayback()
	clearPath()
	playBtn.Text = "PLAY"
	status.Text  = "Playback stopped"
end)

cpBtn.MouseButton1Click:Connect(function()
	state.cpEnabled = not state.cpEnabled
	cpBtn.Text = state.cpEnabled and "AUTO CP: ON" or "AUTO CP: OFF"
	cpBtn.BackgroundColor3 = state.cpEnabled
		and Color3.fromRGB(55, 190, 120)
		or Color3.fromRGB(70, 70, 90)
	if state.cpEnabled then
		-- Try detect now to give immediate feedback
		local _, name = detectLeaderstat()
		if name then
			state.cpDetected = name
			status.Text = "Auto-CP enabled | detected: " .. name
		else
			state.cpDetected = nil
			status.Text = "Auto-CP enabled | no leaderstat found"
		end
		-- If currently recording, hot-attach monitor
		if state.recording then
			setupCheckpointMonitor()
		end
	else
		cleanupCheckpointMonitor()
		state.cpDetected = nil
		status.Text = "Auto-CP disabled"
	end
end)

cpStopBtn.MouseButton1Click:Connect(function()
	state.cpAutoStop = not state.cpAutoStop
	cpStopBtn.Text = state.cpAutoStop and "AUTO STOP: ON" or "AUTO STOP: OFF"
	cpStopBtn.BackgroundColor3 = state.cpAutoStop
		and Color3.fromRGB(55, 190, 120)
		or Color3.fromRGB(70, 70, 90)
end)

refallBtn.MouseButton1Click:Connect(function()
	state.refallEnabled = not state.refallEnabled
	refallBtn.Text = state.refallEnabled and "REFALL: ON" or "REFALL: OFF"
	refallBtn.BackgroundColor3 = state.refallEnabled
		and Color3.fromRGB(255, 130, 50)
		or Color3.fromRGB(70, 70, 90)
	status.Text = state.refallEnabled
		and "Refall enabled — tekan R/Segitiga saat jatuh untuk buka rewind slider"
		or "Refall disabled"
end)


-- Shared: toggle recording (used by recBtn + gamepad ButtonX)
local function toggleRecord()
	if state.recording then
		stopRecording()
		recBtn.Text             = "REC"
		recBtn.BackgroundColor3 = Color3.fromRGB(235, 70, 70)
		status.Text             = string.format("Saved %d frames | %.2fs", #state.frames,
			state.frames[#state.frames] and state.frames[#state.frames].t or 0)
		refreshFileList()
	else
		startRecording()
		recBtn.Text             = "STOP"
		recBtn.BackgroundColor3 = Color3.fromRGB(180, 55, 55)
	end
end

-- Shared: open rewind slider panel (R / Segitiga)
local function doRefall()
	if not state.refallEnabled or not state.recording then return end
	if state.rewindOpen then return end  -- panel udah kebuka
	openRewindPanel()
end

-- Keyboard + Gamepad bindings
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local key = input.KeyCode
	-- Refall: R (keyboard) | ButtonY (Segitiga / Triangle) -> buka rewind slider
	if key == CONFIG.REFALL_KEY or key == CONFIG.REFALL_GAMEPAD then
		doRefall()
		return
	end
	-- Toggle REC: ButtonX (KOTAK / Square)
	if key == CONFIG.REC_GAMEPAD then
		toggleRecord()
		return
	end
end)

close.MouseButton1Click:Connect(function()
	if state.recording then stopRecording() end
	if state.playing then stopPlayback() end
	cleanupCheckpointMonitor()
	clearPath()
	disconnectAll()
	gui:Destroy()
end)

-- Status updater
RunService.RenderStepped:Connect(function()
	local mode = state.playing and "Playing"
		or (state.recording and (state.paused and "Paused" or "Recording") or "Ready")
	local dur
	if state.playing then
		dur = state.curTime
	elseif state.recording then
		dur = os.clock() - state.startTime
	else
		dur = state.frames[#state.frames] and state.frames[#state.frames].t or 0
	end
	if not state.playing and playBtn.Text == "PLAYING" then
		playBtn.Text = "PLAY"
	end
	status.Text = string.format("%s | %d frames | %.1fs", mode, #state.frames, dur)

	-- CP status line
	if state.cpEnabled then
		local detected = state.cpDetected or "(detecting...)"
		local lastVal = state.cpLastValues[state.cpDetected or ""]
		local segFrames = math.max(0, #state.frames - (state.cpStartFrame or 1) + 1)
		cpStatus.Text = string.format("CP: %s=%s | saved=%d | seg=%d",
			detected, tostring(lastVal or "?"), state.cpSaveCount, segFrames)
	else
		cpStatus.Text = "CP: disabled"
	end

	-- Refall status line
	if state.refallEnabled then
		if state.rewindOpen then
			refallStatus.Text = "Rewind panel terbuka — geser slider, lalu RESUME / CANCEL"
		else
			refallStatus.Text = string.format(
				"Refall: tekan [%s] / Segitiga saat jatuh | REC: KOTAK | rescues=%d",
				CONFIG.REFALL_KEY.Name, state.refallCount)
		end
	else
		refallStatus.Text = "Refall: disabled (REC gamepad: KOTAK aktif)"
	end
end)

log("Loaded. Output:", CONFIG.FOLDER)
