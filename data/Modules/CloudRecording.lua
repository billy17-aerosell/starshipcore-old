--[[
    CloudRecording Module
    ======================
    Modul untuk menyimpan dan memuat recording dari cloud (GitHub Gist)
    Gratis dan unlimited! Works on PC and Mobile.
    
    Usage:
        local CloudRecording = LoadModule("Modules/CloudRecording")
        
        -- Save to cloud
        CloudRecording.Save(recordingData, "MyRecording", function(result)
            if result.success then
                print("Share Code:", result.shareCode)
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
local function GetAPIUrl()
	local baseUrl = _G.StarshipServerURL or _G.StarshipBaseURL or "https://starship-core.my.id"
	return baseUrl .. "/api/recordings"
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
            shareCode = "ABC12345",
            gistId = "full-gist-id",
            url = "https://gist.github.com/..."
        }
]]
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

	local gameInfo = nil
	pcall(function()
		gameInfo = GetGameInfo()
	end)

	local payload = {
		userId = tostring(LocalPlayer.UserId),
		name = name or ("Rec_" .. os.date("%H%M%S")),
		gameId = gameInfo and gameInfo.gameId or game.PlaceId,
		gameName = gameInfo and gameInfo.gameName or "Unknown",
		data = recordingData,
	}

	local body = HttpService:JSONEncode(payload)

	SafeRequest(GetAPIUrl(), "POST", body, function(result)
		if result and result.success then
			-- Cache the recording locally too
			LoadedCache[result.shareCode] = recordingData

			if callback then
				callback({
					success = true,
					shareCode = result.shareCode,
					gistId = result.gistId,
					url = result.url,
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
    Memuat recording dari cloud menggunakan share code atau gist ID
    
    Parameters:
        - shareCode: string (8 karakter) atau full gist ID
        - callback: function(result)
    
    Returns (via callback):
        {
            success = true,
            recording = { Frames = {...}, FPS = 60, Mode = "Flexible" },
            shareCode = "ABC12345"
        }
]]
function CloudRecording.Load(shareCode, callback)
	if not shareCode or shareCode == "" then
		if callback then
			callback({
				success = false,
				error = "Share code required",
			})
		end
		return
	end

	-- Check cache first
	if LoadedCache[shareCode] then
		if callback then
			callback({
				success = true,
				recording = LoadedCache[shareCode],
				fromCache = true,
			})
		end
		return
	end

	local url = GetAPIUrl() .. "?shareCode=" .. shareCode

	SafeRequest(url, "GET", nil, function(result)
		if result and result.success then
			-- Cache the recording
			LoadedCache[shareCode] = result.recording

			if callback then
				callback({
					success = true,
					recording = result.recording,
					name = result.name,
					shareCode = result.shareCode,
				})
			end
		else
			if callback then
				callback({
					success = false,
					error = result and result.error or "Recording not found",
					shareCode = shareCode,
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
            recordings = { {name, shareCode, frameCount, ...}, ... },
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
        - gistId: string full gist ID
        - callback: function(result) - optional
]]
function CloudRecording.Delete(gistId, callback)
	if not gistId then
		if callback then
			callback({ success = false, error = "Gist ID required" })
		end
		return
	end

	local url = GetAPIUrl() .. "?gistId=" .. gistId .. "&userId=" .. tostring(LocalPlayer.UserId)

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
    Fallback: Copy share code to clipboard
]]
function CloudRecording.CopyToClipboard(shareCode)
	if setclipboard then
		setclipboard(shareCode)
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

return CloudRecording
