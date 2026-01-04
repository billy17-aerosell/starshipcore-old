--[[
    CloudRecording Module
    ======================
    Modul untuk menyimpan dan memuat recording dari cloud (Cloudflare R2)
    Gratis dan unlimited! Works on PC and Mobile.

    Usage:
        local CloudRecording = LoadModule("Modules/CloudRecording")

        -- Save to cloud
        CloudRecording.Save(recordingData, "MyRecording", function(result)
            if result.success then
                print("Recording ID:", result.recordingId)
            end
        end)

        -- Load from cloud
        CloudRecording.Load("ABC12345", function(result)
            if result.success then
                local frames = result.recording.Frames
            end
        end)
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local CloudRecording = {}

-- DEV_MODE detection (same as StarshipCore)
local DEV_MODE = _G.StarshipDevMode or false

-- Dev-only logging helper (only shows in dev mode)
local function DevLog(...)
	if DEV_MODE then
		warn("[CloudRecording]", ...)
	end
end

-- Configuration - use dynamic URL from global (supports localhost dev mode)
-- Uses Cloudflare R2 storage for large files support (up to 5GB)
local function GetEventCode()
	return _G.StarshipEventCode or ""
end

-- Get base API URL (without auth params)
local function GetAPIBaseUrl()
	local baseUrl = _G.StarshipServerURL or _G.StarshipBaseURL or "https://starship-core.my.id"
	return baseUrl .. "/api/cloud-store-x7k9"
end

-- Get auth params string (eventCode + userId)
local function GetAuthParams()
	local eventCode = GetEventCode()
	local userId = tostring(LocalPlayer.UserId)
	return "eventCode=" .. eventCode .. "&userId=" .. userId
end

-- Full API URL with auth params (for simple requests)
local function GetAPIUrl()
	return GetAPIBaseUrl() .. "?" .. GetAuthParams()
end

-- Local Upload Server URL (for unlimited uploads from PC)
-- Automatically uses localhost:4000 when in dev mode (localhost:3000)
local function GetLocalServerUrl()
	-- If explicitly set, use that
	if _G.StarshipLocalServer then
		return _G.StarshipLocalServer
	end

	-- Auto-detect: if running from localhost:3000, use localhost:4000 for uploads
	local baseUrl = _G.StarshipServerURL or ""
	if baseUrl:find("localhost:3000") then
		return "http://localhost:4000"
	end
	return nil
end

local MAX_RETRY = 3
local RETRY_DELAY = 1

-- Cache for loaded recordings
local LoadedCache = {}

-- Helper: Get current game info
local function GetGameInfo()
	return {
		gameId = game.PlaceId,
		gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name or "Unknown",
	}
end

-- ═══════════════════════════════════════════════════════════════════
-- MOBILE OPTIMIZATION - Compress recording for faster mobile download
-- ═══════════════════════════════════════════════════════════════════

-- Round number to specified decimal places
local function RoundNum(num, decimals)
	if type(num) ~= "number" then
		return num
	end
	local mult = 10 ^ (decimals or 2)
	return math.floor(num * mult + 0.5) / mult
end

-- Optimize a single frame for mobile
local function OptimizeFrame(frame)
	local optimized = {}

	-- Keep timestamp with 2 decimal precision
	optimized.t = RoundNum(frame.t, 2)

	-- Position: reduce to 1 decimal (studs precision is enough)
	if frame.pos then
		optimized.pos = {
			x = RoundNum(frame.pos.x, 1),
			y = RoundNum(frame.pos.y, 1),
			z = RoundNum(frame.pos.z, 1),
		}
	end

	-- Rotation: reduce to 1 decimal
	if frame.rot then
		optimized.rot = RoundNum(frame.rot, 1)
	end

	-- Velocity: reduce to 1 decimal
	if frame.vel then
		optimized.vel = {
			x = RoundNum(frame.vel.x, 1),
			y = RoundNum(frame.vel.y, 1),
			z = RoundNum(frame.vel.z, 1),
		}
	end

	-- State: keep as-is (already short)
	if frame.s then
		optimized.s = frame.s
	elseif frame.state then
		optimized.s = frame.state
	end

	-- Air state (boolean)
	if frame.air ~= nil then
		optimized.air = frame.air
	end

	-- HipHeight: reduce precision
	if frame.hh then
		optimized.hh = RoundNum(frame.hh, 1)
	end

	-- MoveDirection: reduce precision
	if frame.md then
		optimized.md = {
			x = RoundNum(frame.md.x, 2),
			y = RoundNum(frame.md.y, 2),
			z = RoundNum(frame.md.z, 2),
		}
	end

	-- Standard mode (r and j) - keep essential only
	if frame.r then
		optimized.r = frame.r -- CFrame data, keep as-is
	end

	-- Skip joint data for mobile (biggest size saver)
	-- if frame.j then optimized.j = frame.j end -- SKIP THIS

	return optimized
end

-- Optimize entire recording for mobile
local function OptimizeForMobile(recordingData)
	if not recordingData or not recordingData.Frames or #recordingData.Frames == 0 then
		return recordingData
	end

	local originalFrameCount = #recordingData.Frames
	local optimizedFrames = {}

	-- Skip every other frame (60fps -> 30fps)
	for i = 1, originalFrameCount, 2 do
		local frame = recordingData.Frames[i]
		local optimized = OptimizeFrame(frame)
		table.insert(optimizedFrames, optimized)
	end

	local result = {
		Frames = optimizedFrames,
		Mode = recordingData.Mode,
		FPS = 30, -- Now 30fps
		RigType = recordingData.RigType,
		-- Skip other metadata that's not essential
	}

	print(
		string.format(
			"[CloudRecording] Optimized: %d -> %d frames (%.1f%% reduction)",
			originalFrameCount,
			#optimizedFrames,
			(1 - #optimizedFrames / originalFrameCount) * 100
		)
	)

	return result
end

-- Helper: Safe HTTP request with retry (compatible with most executors)
local function SafeRequest(url, method, body, callback)
	-- DEBUG: Print URL being used (only in dev mode)
	DevLog(method .. " request to: " .. url)

	task.spawn(function()
		local attempts = 0
		local lastError = nil

		-- Detect available HTTP function
		local httpFunc = request or http_request or (syn and syn.request) or (http and http.request)

		if not httpFunc then
			DevLog("No request() function found, falling back to game:HttpGet/HttpPost")
		end

		while attempts < MAX_RETRY do
			attempts = attempts + 1
			DevLog("Attempt " .. attempts .. "/" .. MAX_RETRY)

			local success, result = pcall(function()
				if httpFunc then
					-- Use request() function (most executors support this)
					local response = httpFunc({
						Url = url,
						Method = method,
						Headers = {
							["Content-Type"] = "application/json",
						},
						Body = body,
					})
					return response.Body
				else
					-- Fallback to game methods (may not work in all executors)
					if method == "GET" then
						return game:HttpGet(url)
					elseif method == "POST" then
						error("No POST method available - request() function not found")
					elseif method == "DELETE" then
						return game:HttpGet(url .. "&_method=DELETE")
					end
				end
			end)

			DevLog(
				"pcall success: "
					.. tostring(success)
					.. ", result length: "
					.. tostring(result and #tostring(result) or 0)
			)

			if success and result then
				local decodeSuccess, decoded = pcall(function()
					return HttpService:JSONDecode(result)
				end)

				if decodeSuccess then
					DevLog("Decoded successfully!")
					-- DEBUG: Print response content for troubleshooting
					if decoded.success then
						DevLog("✅ Response SUCCESS - recordingId: " .. tostring(decoded.recordingId or "N/A"))
					else
						DevLog("❌ Response ERROR: " .. tostring(decoded.error or "Unknown error"))
						if decoded.message then
							DevLog("Message: " .. tostring(decoded.message))
						end
						if decoded.details then
							DevLog("Details: " .. tostring(decoded.details))
						end
						if decoded.githubError then
							DevLog("GitHub Error: " .. tostring(decoded.githubError))
						end
						-- Show size info if available (for file too large errors)
						if decoded.size then
							DevLog(
								"Recording Size: "
									.. tostring(decoded.size)
									.. "KB (Max: "
									.. tostring(decoded.maxSize or 1024)
									.. "KB)"
							)
						end
					end
					if callback then
						callback(decoded)
					end
					return
				else
					lastError = "JSON decode failed: " .. tostring(result):sub(1, 100)
					DevLog(lastError)
				end
			else
				lastError = tostring(result)
				DevLog("HTTP Error: " .. lastError)
			end

			if attempts < MAX_RETRY then
				task.wait(RETRY_DELAY)
			end
		end

		-- All retries failed
		DevLog("All " .. MAX_RETRY .. " attempts failed. Last error: " .. tostring(lastError))
		if callback then
			callback({
				success = false,
				error = "Request failed after " .. MAX_RETRY .. " attempts",
				details = lastError,
			})
		end
	end)
end

--[[
    CloudRecording.Save()
    =====================
    Menyimpan recording ke cloud

    Parameters:
        - recordingData: table dengan Frames, FPS, Mode
        - name: string nama recording
        - callback: function(result) - optional

    Returns (via callback):
        {
            success = true,
            recordingId = "ABC12345",
            recordingId = "XXXXX-XXXXX",
            size = 1234 -- size in KB
        }
]]

-- Helper: Sanitize name for use as filename (same as server)
local function SanitizeName(name)
	return name
		:gsub("[^%w%s%-_]", "") -- Remove special characters
		:gsub("%s+", "_") -- Replace spaces with underscore
		:sub(1, 100) -- Limit length
end

-- Helper: Get chunked API URL
local function GetChunkedAPIUrl()
	local baseUrl = _G.StarshipServerURL or _G.StarshipBaseURL or "https://starship-core.my.id"
	return baseUrl .. "/api/cloud-chunk-m3p7"
end

-- Helper: Upload Chunked (for large files > 4MB)
-- Uploads frames in chunks, then saves metadata (no server merge to avoid timeout)
local function UploadChunked(payload, callback)
	local frames = payload.data.Frames
	local totalFrames = #frames
	local FRAMES_PER_CHUNK = 3000
	local totalChunks = math.ceil(totalFrames / FRAMES_PER_CHUNK)

	-- Use sanitized name as recordingId
	local recordingId = SanitizeName(payload.name)

	local completedChunks = 0
	local failed = false

	local function UploadNextChunk(chunkIndex)
		if failed then
			return
		end

		if chunkIndex >= totalChunks then
			-- All chunks done, save metadata (NO MERGE - just metadata)
			local metadata = {
				recordingId = recordingId,
				name = payload.name,
				userId = payload.userId,
				gameId = payload.gameId,
				gameName = payload.gameName,
				totalChunks = totalChunks,
				totalFrames = totalFrames,
				framesPerChunk = FRAMES_PER_CHUNK,
				duration = payload.data.Duration or 0,
				mode = payload.data.Mode,
				createdAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
				isChunked = true, -- Flag to indicate this is chunked storage
			}

			local metaBody = HttpService:JSONEncode({
				recordingId = recordingId,
				metadata = metadata,
			})

			-- Use save_meta action (no merge, just save metadata)
			SafeRequest(GetChunkedAPIUrl() .. "?action=save_meta", "POST", metaBody, function(res)
				if res and res.success then
					if callback then
						callback({
							success = true,
							recordingId = recordingId,
							message = "Large recording uploaded! (" .. totalChunks .. " chunks)",
						})
					end
				else
					if callback then
						callback({
							success = false,
							error = "Failed to save metadata",
							message = res and res.message or "Unknown error",
						})
					end
				end
			end)
			return
		end

		-- Prepare chunk
		local startIdx = (chunkIndex * FRAMES_PER_CHUNK) + 1
		local endIdx = math.min(startIdx + FRAMES_PER_CHUNK - 1, totalFrames)
		local chunkFrames = {}

		for i = startIdx, endIdx do
			table.insert(chunkFrames, frames[i])
		end

		local chunkData = {
			recordingId = recordingId,
			chunkIndex = chunkIndex,
			chunkData = {
				frames = chunkFrames,
				chunkIndex = chunkIndex,
				startFrame = startIdx,
				endFrame = endIdx,
			},
		}

		local chunkBody = HttpService:JSONEncode(chunkData)

		SafeRequest(GetChunkedAPIUrl() .. "?action=upload_chunk", "POST", chunkBody, function(res)
			if res and res.success then
				completedChunks = completedChunks + 1
				UploadNextChunk(chunkIndex + 1)
			else
				failed = true
				if callback then
					callback({
						success = false,
						error = "Failed to upload chunk " .. chunkIndex,
						message = res and res.details or "Unknown error",
					})
				end
			end
		end)
	end

	-- Start upload
	UploadNextChunk(0)
end

function CloudRecording.Save(recordingData, name, callback)
	if not recordingData or not recordingData.Frames or #recordingData.Frames == 0 then
		if callback then
			callback({
				success = false,
				error = "Invalid recording data",
			})
		end
		return
	end

	-- Upload original data (no compression - keeps 100% accuracy)
	local gameInfo = nil
	pcall(function()
		gameInfo = GetGameInfo()
	end)

	local payload = {
		userId = tostring(LocalPlayer.UserId),
		name = name or ("Rec_" .. os.date("%H%M%S")),
		gameId = gameInfo and gameInfo.gameId or game.PlaceId,
		gameName = gameInfo and gameInfo.gameName or "Unknown",
		data = recordingData, -- Original data, no compression
	}

	local body = HttpService:JSONEncode(payload)

	-- Priority 1: Use Local Upload Server if available (UNLIMITED SIZE!)
	local localServer = GetLocalServerUrl()
	if localServer then
		SafeRequest(localServer .. "/upload", "POST", body, function(result)
			if result and result.success then
				LoadedCache[result.recordingId] = recordingData
				if callback then
					callback({
						success = true,
						recordingId = result.recordingId,
						size = result.size,
						message = "Recording uploaded via Local Server!",
					})
				end
			else
				if callback then
					callback({
						success = false,
						error = result and result.error or "Local server upload failed",
						message = "Make sure local-upload-server.js is running",
					})
				end
			end
		end)
		return
	end

	-- Priority 2: If > 4MB and no local server, use chunked upload (Vercel limit workaround)
	if #body > 4 * 1024 * 1024 then
		UploadChunked(payload, callback)
		return
	end

	-- Priority 3: Normal upload for small files (< 4MB)
	SafeRequest(GetAPIUrl(), "POST", body, function(result)
		if result and result.success then
			-- Cache the recording locally too
			LoadedCache[result.recordingId] = recordingData

			if callback then
				callback({
					success = true,
					recordingId = result.recordingId,
					recordingId = result.recordingId,
					size = result.size,
					message = "Recording saved to cloud!",
				})
			end
		else
			if callback then
				callback({
					success = false,
					error = result and result.error or "Unknown error",
					message = result and result.message or "Failed to save",
				})
			end
		end
	end)
end

--[[
    CloudRecording.Load()
    =====================
    Memuat recording dari cloud menggunakan recording ID atau recording ID

    Parameters:
        - recordingId: string (8 karakter) atau full recording ID
        - callback: function(result)

    Returns (via callback):
        {
            success = true,
            recording = { Frames = {...}, FPS = 60, Mode = "Flexible" },
            recordingId = "ABC12345"
        }
]]
function CloudRecording.Load(recordingId, callback)
	if not recordingId or recordingId == "" then
		if callback then
			callback({
				success = false,
				error = "Recording ID required",
			})
		end
		return
	end

	-- Check cache first
	if LoadedCache[recordingId] then
		if callback then
			callback({
				success = true,
				recording = LoadedCache[recordingId],
				fromCache = true,
			})
		end
		return
	end

	local url = GetAPIUrl() .. "&recordingId=" .. recordingId

	SafeRequest(url, "GET", nil, function(result)
		if result and result.success then
			-- Cache the recording
			LoadedCache[recordingId] = result.recording

			if callback then
				callback({
					success = true,
					recording = result.recording,
					name = result.name,
					recordingId = result.recordingId,
				})
			end
		else
			if callback then
				callback({
					success = false,
					error = result and result.error or "Recording not found",
					recordingId = recordingId,
				})
			end
		end
	end)
end

--[[
    CloudRecording.List()
    =====================
    Mendapatkan daftar recording user dari cloud

    Parameters:
        - callback: function(result)

    Returns (via callback):
        {
            success = true,
            recordings = { {name, recordingId, frameCount, ...}, ... },
            count = 5
        }
]]
function CloudRecording.List(callback)
	local url = GetAPIUrl() .. "&list=true"

	SafeRequest(url, "GET", nil, function(result)
		if result and result.success then
			if callback then
				callback({
					success = true,
					recordings = result.recordings or {},
					count = result.count or 0,
				})
			end
		else
			if callback then
				callback({
					success = false,
					error = result and result.error or "Failed to get list",
					recordings = {},
				})
			end
		end
	end)
end

--[[
    CloudRecording.Delete()
    =======================
    Menghapus recording dari cloud

    Parameters:
        - recordingId: string full recording ID
        - callback: function(result) - optional
]]
function CloudRecording.Delete(recordingId, callback)
	if not recordingId then
		if callback then
			callback({ success = false, error = "Recording ID required" })
		end
		return
	end

	local url = GetAPIUrl() .. "&recordingId=" .. recordingId

	SafeRequest(url, "DELETE", nil, function(result)
		if result and result.success then
			if callback then
				callback({ success = true, message = "Recording deleted" })
			end
		else
			if callback then
				callback({
					success = false,
					error = result and result.error or "Failed to delete",
				})
			end
		end
	end)
end

--[[
    CloudRecording.CopyToClipboard()
    ================================
    Fallback: Copy recording ID to clipboard
]]
function CloudRecording.CopyToClipboard(recordingId)
	if setclipboard then
		setclipboard(recordingId)
		return true
	end
	return false
end

--[[
    CloudRecording.IsAvailable()
    ============================
    Check if cloud recording is available (has internet)
]]
function CloudRecording.IsAvailable()
	local baseUrl = _G.StarshipServerURL or _G.StarshipBaseURL or "https://starship-core.my.id"
	local success = pcall(function()
		game:HttpGet(baseUrl .. "/api/health")
	end)
	return success
end

--[[
    CloudRecording.GetCacheSize()
    =============================
    Get number of cached recordings
]]
function CloudRecording.GetCacheSize()
	local count = 0
	for _ in pairs(LoadedCache) do
		count = count + 1
	end
	return count
end

--[[
    CloudRecording.ClearCache()
    ===========================
    Clear local cache
]]
function CloudRecording.ClearCache()
	LoadedCache = {}
end

--[[
    CloudRecording.ListAll()
    ========================
    Mendapatkan SEMUA recording dari cloud (untuk check duplicate)

    Parameters:
        - callback: function(result)

    Returns (via callback):
        {
            success = true,
            recordings = { {name, recordingId, recordingId, createdAt, updatedAt}, ... },
            count = 10
        }
]]
function CloudRecording.ListAll(callback)
	local url = GetAPIUrl() .. "&list=all"

	SafeRequest(url, "GET", nil, function(result)
		if result and result.success then
			if callback then
				callback({
					success = true,
					recordings = result.recordings or {},
					count = result.count or 0,
				})
			end
		else
			if callback then
				callback({
					success = false,
					error = result and result.error or "Failed to get all recordings",
					recordings = {},
				})
			end
		end
	end)
end

--[[
    CloudRecording.CheckDuplicate()
    ================================
    Cek apakah nama recording sudah ada di cloud

    Parameters:
        - name: string nama recording yang mau dicek
        - callback: function(result)

    Returns (via callback):
        {
            exists = true/false,
            recording = { recordingId, recordingId, name, ... } -- jika exists=true
        }
]]
function CloudRecording.CheckDuplicate(name, callback)
	if not name or name == "" then
		if callback then
			callback({ exists = false, error = "Name required" })
		end
		return
	end

	CloudRecording.ListAll(function(result)
		if result.success then
			local normalizedName = string.lower(name:gsub("%.json$", ""):gsub("^%s*(.-)%s*$", "%1"))

			for _, rec in ipairs(result.recordings) do
				-- Extract just the recording name from description format
				-- Format: "[StarshipCore] RecordingName - User xxx - xxx frames"
				local recName = rec.name or ""
				-- Remove the suffix " - User xxx - xxx frames" if present
				recName = recName:match("^(.-)%s*%-%s*User") or recName
				local normalizedRecName = string.lower(recName:gsub("^%s*(.-)%s*$", "%1"))

				if normalizedRecName == normalizedName then
					if callback then
						callback({
							exists = true,
							recording = rec,
						})
					end
					return
				end
			end

			-- No match found
			if callback then
				callback({ exists = false })
			end
		else
			-- Failed to check, assume no duplicate
			if callback then
				callback({ exists = false, error = result.error })
			end
		end
	end)
end

--[[
    CloudRecording.Update()
    =======================
    Update recording yang sudah ada di cloud

    Parameters:
        - recordingId: string ID recording yang mau di-update
        - recordingData: table dengan Frames, FPS, Mode (optional, jika mau update data)
        - name: string nama baru (optional, jika mau rename)
        - callback: function(result) - optional

    Returns (via callback):
        {
            success = true,
            recordingId = "xxx",
            recordingId = "ABC12345",
            message = "Recording updated!"
        }
]]
function CloudRecording.Update(recordingId, recordingData, name, callback)
	if not recordingId then
		if callback then
			callback({
				success = false,
				error = "Recording ID required",
			})
		end
		return
	end

	if not recordingData and not name then
		if callback then
			callback({
				success = false,
				error = "Nothing to update - provide data or name",
			})
		end
		return
	end

	-- Validate data if provided
	if recordingData and (not recordingData.Frames or #recordingData.Frames == 0) then
		if callback then
			callback({
				success = false,
				error = "Invalid recording data - must have frames",
			})
		end
		return
	end

	-- Get game info
	local gameInfo = nil
	pcall(function()
		gameInfo = GetGameInfo()
	end)

	local payload = {
		userId = tostring(LocalPlayer.UserId),
		name = name or recordingId, -- Use recordingId as name if not provided
		gameId = gameInfo and gameInfo.gameId or game.PlaceId,
		gameName = gameInfo and gameInfo.gameName or "Unknown",
	}

	if recordingData then
		payload.data = recordingData
	end

	local body = HttpService:JSONEncode(payload)

	-- Priority 1: Use Local Upload Server if available (UNLIMITED SIZE!)
	local localServer = GetLocalServerUrl()
	if localServer and recordingData then
		SafeRequest(localServer .. "/upload", "POST", body, function(result)
			if result and result.success then
				LoadedCache[result.recordingId] = recordingData
				if callback then
					callback({
						success = true,
						recordingId = result.recordingId,
						size = result.compressedSize or result.size,
						updatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
						message = "Recording updated via Local Server!",
					})
				end
			else
				if callback then
					callback({
						success = false,
						error = result and result.error or "Local server update failed",
						message = "Make sure local-upload-server.js is running",
					})
				end
			end
		end)
		return
	end

	-- Priority 2: If > 4MB, use Save (which handles large files)
	if recordingData and #body > 4 * 1024 * 1024 then
		-- For large updates, use Save (which handles chunking)
		CloudRecording.Save(recordingData, name or recordingId, callback)
		return
	end

	-- Priority 3: Normal PATCH for small updates
	local patchPayload = {
		userId = tostring(LocalPlayer.UserId),
		recordingId = recordingId,
	}
	if name then
		patchPayload.name = name
	end
	if recordingData then
		patchPayload.data = recordingData
	end
	local patchBody = HttpService:JSONEncode(patchPayload)

	SafeRequest(GetAPIUrl(), "PATCH", patchBody, function(result)
		if result and result.success then
			-- Update cache if we have new data
			if recordingData and result.recordingId then
				LoadedCache[result.recordingId] = recordingData
			end

			if callback then
				callback({
					success = true,
					recordingId = result.recordingId,
					size = result.size,
					updatedAt = result.updatedAt,
					message = "Recording updated successfully!",
				})
			end
		else
			if callback then
				callback({
					success = false,
					error = result and result.error or "Failed to update",
					message = result and result.message or "Update failed",
				})
			end
		end
	end)
end

--[[
    CloudRecording.SaveOrUpdate()
    =============================
    Smart save - otomatis check duplicate dan tanya user mau update atau buat baru

    Parameters:
        - recordingData: table dengan Frames, FPS, Mode
        - name: string nama recording
        - callbacks: table dengan:
            - onDuplicate: function(existingRec, saveNew, updateExisting)
                           dipanggil jika nama sudah ada
            - onSuccess: function(result) - dipanggil jika berhasil
            - onError: function(error) - dipanggil jika gagal

    Flow:
        1. Check apakah nama sudah ada di cloud
        2. Jika ada, panggil onDuplicate dengan pilihan
        3. User pilih: saveNew() atau updateExisting()
        4. Eksekusi sesuai pilihan user
]]
function CloudRecording.SaveOrUpdate(recordingData, name, callbacks)
	callbacks = callbacks or {}

	if not recordingData or not recordingData.Frames or #recordingData.Frames == 0 then
		if callbacks.onError then
			callbacks.onError("Invalid recording data")
		end
		return
	end

	-- Check for duplicate
	CloudRecording.CheckDuplicate(name, function(checkResult)
		if checkResult.exists and checkResult.recording then
			-- Duplicate found! Ask user what to do
			local existingRec = checkResult.recording

			-- Create action functions
			local function saveNew()
				CloudRecording.Save(recordingData, name, function(result)
					if result.success then
						if callbacks.onSuccess then
							callbacks.onSuccess({
								action = "created",
								recordingId = result.recordingId,
								recordingId = result.recordingId,
								message = "New recording created!",
							})
						end
					else
						if callbacks.onError then
							callbacks.onError(result.error or "Failed to save")
						end
					end
				end)
			end

			local function updateExisting()
				CloudRecording.Update(
					existingRec.recordingId or existingRec.recordingId,
					recordingData,
					name,
					function(result)
						if result.success then
							if callbacks.onSuccess then
								callbacks.onSuccess({
									action = "updated",
									recordingId = result.recordingId,
									recordingId = result.recordingId,
									message = "Recording updated!",
								})
							end
						else
							if callbacks.onError then
								callbacks.onError(result.error or "Failed to update")
							end
						end
					end
				)
			end

			-- Call onDuplicate with options
			if callbacks.onDuplicate then
				callbacks.onDuplicate(existingRec, saveNew, updateExisting)
			else
				-- No duplicate handler, default to save new
				saveNew()
			end
		else
			-- No duplicate, save as new
			CloudRecording.Save(recordingData, name, function(result)
				if result.success then
					if callbacks.onSuccess then
						callbacks.onSuccess({
							action = "created",
							recordingId = result.recordingId,
							recordingId = result.recordingId,
							message = "Recording saved to cloud!",
						})
					end
				else
					if callbacks.onError then
						callbacks.onError(result.error or "Failed to save")
					end
				end
			end)
		end
	end)
end

return CloudRecording
