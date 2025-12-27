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

-- Configuration - use dynamic URL from global (supports localhost dev mode)
-- Uses Cloudflare R2 storage for large files support (up to 5GB vs Cloudflare R2 1MB)
local function GetAPIUrl()
	local baseUrl = _G.StarshipServerURL or _G.StarshipBaseURL or "https://starship-core.my.id"
	return baseUrl .. "/api/r2-recordings"
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
	-- DEBUG: Print URL being used
	warn("[CloudRecording] " .. method .. " request to: " .. url)

	task.spawn(function()
		local attempts = 0
		local lastError = nil

		-- Detect available HTTP function
		local httpFunc = request or http_request or (syn and syn.request) or (http and http.request)

		if not httpFunc then
			warn("[CloudRecording] No request() function found, falling back to game:HttpGet/HttpPost")
		end

		while attempts < MAX_RETRY do
			attempts = attempts + 1
			warn("[CloudRecording] Attempt " .. attempts .. "/" .. MAX_RETRY)

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

			warn(
				"[CloudRecording] pcall success: "
					.. tostring(success)
					.. ", result length: "
					.. tostring(result and #tostring(result) or 0)
			)

			if success and result then
				local decodeSuccess, decoded = pcall(function()
					return HttpService:JSONDecode(result)
				end)

				if decodeSuccess then
					warn("[CloudRecording] Decoded successfully!")
					-- DEBUG: Print response content for troubleshooting
					if decoded.success then
						warn(
							"[CloudRecording] ✅ Response SUCCESS - recordingId: "
								.. tostring(decoded.recordingId or "N/A")
						)
					else
						warn("[CloudRecording] ❌ Response ERROR: " .. tostring(decoded.error or "Unknown error"))
						if decoded.message then
							warn("[CloudRecording] Message: " .. tostring(decoded.message))
						end
						if decoded.details then
							warn("[CloudRecording] Details: " .. tostring(decoded.details))
						end
						if decoded.githubError then
							warn("[CloudRecording] GitHub Error: " .. tostring(decoded.githubError))
						end
						-- Show size info if available (for file too large errors)
						if decoded.size then
							warn(
								"[CloudRecording] Recording Size: "
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
					warn("[CloudRecording] " .. lastError)
				end
			else
				lastError = tostring(result)
				warn("[CloudRecording] HTTP Error: " .. lastError)
			end

			if attempts < MAX_RETRY then
				task.wait(RETRY_DELAY)
			end
		end

		-- All retries failed
		warn("[CloudRecording] All " .. MAX_RETRY .. " attempts failed. Last error: " .. tostring(lastError))
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

-- Helper: Upload directly to R2 using Presigned URL (for large files > 4MB)
local function UploadDirect(payload, callback)
	local gameInfo = nil
	pcall(function()
		gameInfo = GetGameInfo()
	end)

	-- Step 1: Get presigned upload URL from server
	local urlRequestBody = HttpService:JSONEncode({
		name = payload.name,
		userId = payload.userId,
		gameId = payload.gameId,
		gameName = payload.gameName,
		frameCount = payload.data.Frames and #payload.data.Frames or 0,
		duration = payload.data.Duration or 0,
		mode = payload.data.Mode,
	})

	local apiUrl = GetAPIUrl() .. "?action=get_upload_url"

	SafeRequest(apiUrl, "POST", urlRequestBody, function(urlResult)
		if not urlResult or not urlResult.success or not urlResult.uploadUrl then
			if callback then
				callback({
					success = false,
					error = "Failed to get upload URL",
					message = urlResult and urlResult.error or "Unknown error",
				})
			end
			return
		end

		-- Step 2: Prepare the full recording object (same structure as normal upload)
		local sanitizedName = SanitizeName(payload.name)
		local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")

		local recordingObject = {
			id = sanitizedName,
			name = payload.name,
			userId = payload.userId,
			gameId = payload.gameId,
			gameName = payload.gameName,
			frameCount = payload.data.Frames and #payload.data.Frames or 0,
			duration = payload.data.Duration or 0,
			mode = payload.data.Mode,
			createdAt = timestamp,
			updatedAt = timestamp,
			data = payload.data,
		}

		local fullBody = HttpService:JSONEncode(recordingObject)

		-- Step 3: Upload directly to R2 using presigned URL
		local uploadSuccess, uploadResult = pcall(function()
			return game:GetService("HttpService"):RequestAsync({
				Url = urlResult.uploadUrl,
				Method = "PUT",
				Headers = {
					["Content-Type"] = "application/json",
				},
				Body = fullBody,
			})
		end)

		if uploadSuccess and type(uploadResult) == "table" and uploadResult.Success then
			if callback then
				callback({
					success = true,
					recordingId = sanitizedName,
					message = "Large recording uploaded directly to cloud!",
				})
			end
		else
			local errorMsg = "Unknown error"
			if not uploadSuccess then
				errorMsg = tostring(uploadResult) -- uploadResult contains error message if pcall failed
			elseif type(uploadResult) == "table" then
				errorMsg = uploadResult.StatusMessage or ("HTTP " .. (uploadResult.StatusCode or "?"))
			end

			if callback then
				callback({
					success = false,
					error = "Direct upload failed",
					message = errorMsg,
				})
			end
		end
	end)
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

	-- Check size: If > 4MB, use direct upload to R2 (via presigned URL)
	if #body > 4 * 1024 * 1024 then
		UploadDirect(payload, callback)
		return
	end

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

	local url = GetAPIUrl() .. "?recordingId=" .. recordingId

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
	local url = GetAPIUrl() .. "?list=true&userId=" .. tostring(LocalPlayer.UserId)

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

	local url = GetAPIUrl() .. "?recordingId=" .. recordingId .. "&userId=" .. tostring(LocalPlayer.UserId)

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
	local url = GetAPIUrl() .. "?list=all"

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

	local payload = {
		userId = tostring(LocalPlayer.UserId),
		recordingId = recordingId,
	}

	if name then
		payload.name = name
	end

	if recordingData then
		payload.data = recordingData
	end

	local body = HttpService:JSONEncode(payload)

	SafeRequest(GetAPIUrl(), "PATCH", body, function(result)
		if result and result.success then
			-- Update cache if we have new data
			if recordingData and result.recordingId then
				LoadedCache[result.recordingId] = recordingData
			end

			if callback then
				callback({
					success = true,
					recordingId = result.recordingId,
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
