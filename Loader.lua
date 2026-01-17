local HttpService = game:GetService("HttpService")
local SERVER_URL = "https://starship-core.my.id"
local FOLDER_NAME = "StarshipCore"
local MODULES_FOLDER = FOLDER_NAME .. "/Modules"
local TABS_FOLDER = MODULES_FOLDER .. "/Tabs"
local MODULES = {
	"Config.lua",
	"UI.lua",
	"Intro.lua",
	"Animations.lua",
	"Locale.lua",
	"CloudRecording.lua",
	"UIComponents.lua",
	"ConnectionManager.lua",
	"Changelog.lua",
}
local TABS = { "Dashboard.lua", "Tools.lua", "Warp.lua", "Helper.lua", "Fun.lua", "Emotes.lua", "ConfigTab.lua" }

-- Dev mode detection (for debug logging)
local DEV_MODE = false

-- In-memory module storage (no files saved to disk for security!)
local LoadedModules = {}

local function xorEncrypt(text, key)
	local result = {}
	for i = 1, #text do
		local charCode = string.byte(text, i)
		local keyCode = string.byte(key, ((i - 1) % #key) + 1)
		table.insert(result, string.char(bit32.bxor(charCode, keyCode)))
	end
	return table.concat(result)
end

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64Decode(data)
	data = string.gsub(data, "[^" .. b64chars .. "=]", "")
	return (
		data:gsub(".", function(x)
			if x == "=" then
				return ""
			end
			local r, f = "", (b64chars:find(x) - 1)
			for i = 6, 1, -1 do
				r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
			end
			return r
		end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
			if #x ~= 8 then
				return ""
			end
			local c = 0
			for i = 1, 8 do
				c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
			end
			return string.char(c)
		end)
	)
end

-- ══════════════════════════════════════════════════════════════════
-- SECURITY v3.0: SERVER-SIDE Token Verification
-- NO SECRET KEYS STORED ON CLIENT - Server validates tokens!
-- XOR Encryption for maximum executor compatibility
-- ══════════════════════════════════════════════════════════════════

-- SERVER-SIDE Token Verification
-- Client sends token to server for validation - NO SECRET NEEDED!
local function verifyTokenWithServer(userId, timestamp, nonce, token)
	local verifyUrl = SERVER_URL
		.. "/api/load?action=verify&userId="
		.. userId
		.. "&timestamp="
		.. tostring(timestamp)
		.. "&nonce="
		.. HttpService:UrlEncode(nonce)
		.. "&token="
		.. HttpService:UrlEncode(token)

	local success, response = pcall(function()
		return game:HttpGet(verifyUrl)
	end)

	if not success then
		return { valid = false, error = "VERIFY_CONNECTION_FAILED" }
	end

	local data = nil
	pcall(function()
		data = HttpService:JSONDecode(response)
	end)

	if data and data.valid then
		return { valid = true, error = nil }
	else
		return { valid = false, error = data and data.error or "UNKNOWN_ERROR" }
	end
end

-- Verify secure payload using SERVER-SIDE validation
local function verifySecurePayload(signedData, userId)
	-- Check if this is a v3 secure payload
	if not signedData or signedData._v ~= 3 then
		-- Legacy payload (v2 or earlier) - accept as-is for backward compatibility
		return { valid = true, data = signedData, error = nil, legacy = true }
	end

	local payload = signedData.p
	local verifyToken = signedData.vt

	if not payload then
		return { valid = false, data = nil, error = "MISSING_PAYLOAD" }
	end

	-- Check timestamp locally first (quick check)
	local now = os.time() * 1000 -- Convert to milliseconds
	if payload.t and payload.t > now + 5000 then
		return { valid = false, data = nil, error = "FUTURE_TIMESTAMP" }
	end
	if payload.e and now > payload.e then
		return { valid = false, data = nil, error = "EXPIRED" }
	end

	-- Verify token with SERVER (NO SECRET NEEDED ON CLIENT!)
	if verifyToken and userId then
		local verification = verifyTokenWithServer(userId, payload.t, payload.n, verifyToken)
		if not verification.valid then
			return { valid = false, data = nil, error = verification.error or "INVALID_TOKEN" }
		end
	end

	return { valid = true, data = payload.d, error = nil, legacy = false }
end

-- Extract data from secure payload (with server-side verification)
local function extractSecureData(response, userId)
	local success, data = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if not success then
		return nil, "JSON_PARSE_ERROR"
	end

	-- Check for honeypot trap (someone is trying to bypass)
	for key, _ in pairs(data) do
		if key:find("__debug_") or key:find("__trap_") then
			-- This is a trap field - it should be ignored, not used
			-- If someone tries to use these keys, they're attempting bypass
		end
	end

	-- Verify the payload with SERVER (no secrets on client!)
	local verification = verifySecurePayload(data, userId)

	if not verification.valid then
		return nil, verification.error
	end

	return verification.data, nil
end

-- ══════════════════════════════════════════════════════════════════
-- HWID DETECTION (Hardware ID for device binding)
-- ══════════════════════════════════════════════════════════════════
local function getDeviceHWID()
	local hwid = nil

	-- Method 1: Try gethwid() - Most common in PC executors (Xeno, Synapse, etc)
	pcall(function()
		if gethwid then
			hwid = gethwid()
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 2: Try HWID from getexecutorinfo
	pcall(function()
		if getexecutorinfo then
			local info = getexecutorinfo()
			if type(info) == "table" and info.HWID then
				hwid = info.HWID
			elseif type(info) == "table" and info.hwid then
				hwid = info.hwid
			end
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 3: Try identifyexecutor() + custom HWID storage
	pcall(function()
		if identifyexecutor then
			-- Some executors store HWID in _G or getgenv()
			if getgenv and getgenv().HWID then
				hwid = getgenv().HWID
			elseif _G.HWID then
				hwid = _G.HWID
			end
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 4: Try get_hwid (alternative naming)
	pcall(function()
		if get_hwid then
			hwid = get_hwid()
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 5: Xeno executor specific
	pcall(function()
		if Xeno and Xeno.HWID then
			hwid = Xeno.HWID
		elseif xeno and xeno.hwid then
			hwid = xeno.hwid
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 6: Synapse specific
	pcall(function()
		if syn and syn.hwid then
			hwid = syn.hwid()
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 7: Script-Ware specific
	pcall(function()
		if gethwidstring then
			hwid = gethwidstring()
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 8: Wave executor specific
	pcall(function()
		-- Wave may use different HWID functions
		if getuniqueidentifier then
			hwid = getuniqueidentifier()
		elseif gethid then
			hwid = gethid()
		elseif getdeviceid then
			hwid = getdeviceid()
		elseif getmachineguid then
			hwid = getmachineguid()
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end
	
	-- Method 9: Try RbxAnalyticsService ClientId (works on most executors)
	pcall(function()
		local analyticsService = game:GetService("RbxAnalyticsService")
		if analyticsService and analyticsService.GetClientId then
			hwid = analyticsService:GetClientId()
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end
	
	-- Method 10: Try HttpService GenerateGUID (persistent per machine in some executors)
	pcall(function()
		if getgenv and getgenv().StarshipHWID then
			hwid = getgenv().StarshipHWID
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 8: Fallback - Generate pseudo-HWID from user data
	pcall(function()
		local userId = tostring(game:GetService("Players").LocalPlayer.UserId)
		local execName = "unknown"
		pcall(function()
			if identifyexecutor then
				execName = identifyexecutor() or "unknown"
			end
		end)
		-- Create a pseudo-HWID (not as secure, but provides some protection)
		hwid = "PSEUDO_PC_" .. execName .. "_" .. userId
	end)

	return hwid or "unknown"
end

-- Setup folder only for user data (recordings, configs) - NOT for modules
local function setupFolders()
	if not isfolder(FOLDER_NAME) then
		makefolder(FOLDER_NAME)
	end
end

-- Download and load module directly to memory (no file saved!)
local function downloadModule(moduleName, userId)
	-- ══════════════════════════════════════════════════════════════════
	-- CDN LOADING (Cloudflare) - Injected by loader for PC
	-- Reduces Vercel bandwidth by loading from Cloudflare CDN
	-- ══════════════════════════════════════════════════════════════════
	if _G.StarshipCDN and _G.StarshipCDN.enabled then
		local cdnUrl = _G.StarshipCDN.url
		local cdnToken = _G.StarshipCDN.token
		
		if cdnUrl and cdnToken then
			-- Build CDN URL for module
			-- moduleName is like "Config.lua" or "Tabs/Dashboard.lua"
			local modulePath = "Modules/" .. moduleName
			local fullUrl = cdnUrl .. "/" .. modulePath .. "?token=" .. cdnToken
			
			if DEV_MODE then
				warn("[Starship] CDN Loading: " .. moduleName .. " from Cloudflare")
			end
			
			local success, response = pcall(function()
				return game:HttpGet(fullUrl)
			end)
			
			if success and response then
				-- Check if response is an error from CDN
				if response:match("^-- ERROR:") or response:match("^error%(") then
					if DEV_MODE then
						warn("[Starship] CDN Error for " .. moduleName .. ": " .. response:sub(1, 100))
					end
					-- Fall through to Vercel loading
				else
					-- Successfully got module from CDN - load to memory
					local func, err = loadstring(response)
					if func then
						local execSuccess, result = pcall(func)
						if execSuccess then
							LoadedModules[moduleName] = result
							if DEV_MODE then
								warn("[Starship] ✅ CDN Loaded: " .. moduleName)
							end
							return true
						else
							if DEV_MODE then
								warn("[Starship] CDN Execute error for " .. moduleName .. ": " .. tostring(result))
							end
						end
					else
						if DEV_MODE then
							warn("[Starship] CDN Loadstring error for " .. moduleName .. ": " .. tostring(err))
						end
					end
				end
			else
				if DEV_MODE then
					warn("[Starship] CDN Failed for " .. moduleName .. ", falling back to Vercel")
				end
			end
		end
	end
	
	-- ══════════════════════════════════════════════════════════════════
	-- VERCEL LOADING (Fallback) - Original method
	-- ══════════════════════════════════════════════════════════════════
	local url = SERVER_URL .. "/api/get-module?name=" .. moduleName .. "&user=" .. userId

	local success, response = pcall(function()
		return game:HttpGet(url)
	end)

	if not success or not response or response == "" then
		if DEV_MODE then
			warn("[Starship] Failed to download module: " .. moduleName)
		end
		if DEV_MODE and response then
			warn("[Starship] Response: " .. tostring(response):sub(1, 200))
		end
		return false
	end

	-- Check if response is JSON error
	if response:find('"error"') then
		if DEV_MODE then
			warn("[Starship] Module error: " .. moduleName .. " - " .. response)
		end
		return false
	end

	-- Try to parse as JSON (encrypted module)
	local data = nil
	local parseSuccess, parseError = pcall(function()
		data = HttpService:JSONDecode(response)
	end)

	if not parseSuccess then
		if DEV_MODE then
			warn("[Starship] JSON parse failed for " .. moduleName .. ": " .. tostring(parseError))
			warn("[Starship] Raw response: " .. response:sub(1, 300))
		end

		-- Check if it's actually a Lua script (starts with comment or local/return)
		local trimmed = response:match("^%s*(.-)%s*$") or response
		if trimmed:match("^%-%-") or trimmed:match("^local%s") or trimmed:match("^return%s") then
			-- Load directly to memory
			local func, err = loadstring(response)
			if func then
				local success, result = pcall(func)
				if success then
					LoadedModules[moduleName] = result
					return true
				else
					if DEV_MODE then
						warn("[Starship] Execute error for " .. moduleName .. ": " .. tostring(result))
					end
					return false
				end
			else
				if DEV_MODE then
					warn("[Starship] Loadstring error for " .. moduleName .. ": " .. tostring(err))
				end
				return false
			end
		end

		return false
	end

	if data and data.status == "success" and data.key and data.blob then
		-- Decrypt the module
		local encryptedString = base64Decode(data.blob)
		local decryptedContent = xorEncrypt(encryptedString, data.key)

		-- Remove BOM if present
		if
			#decryptedContent >= 3
			and string.byte(decryptedContent, 1) == 239
			and string.byte(decryptedContent, 2) == 187
			and string.byte(decryptedContent, 3) == 191
		then
			decryptedContent = string.sub(decryptedContent, 4)
		end

		-- Validate decrypted content looks like Lua
		local trimmed = decryptedContent:match("^%s*(.-)%s*$") or decryptedContent
		if
			not (
				trimmed:match("^%-%-")
				or trimmed:match("^local%s")
				or trimmed:match("^return%s")
				or trimmed:match("^function%s")
			)
		then
			if DEV_MODE then
				warn("[Starship] Decrypted content doesn't look like Lua for " .. moduleName)
				warn("[Starship] First 200 chars: " .. decryptedContent:sub(1, 200))
			end
			return false
		end

		-- Load directly to memory (NO FILE SAVED!)
		local func, err = loadstring(decryptedContent)
		if func then
			local success, result = pcall(func)
			if success then
				LoadedModules[moduleName] = result
				return true
			else
				if DEV_MODE then
					warn("[Starship] Execute error for " .. moduleName .. ": " .. tostring(result))
				end
				return false
			end
		else
			if DEV_MODE then
				warn("[Starship] Loadstring error for " .. moduleName .. ": " .. tostring(err))
			end
			return false
		end
	elseif data and data.status == "denied" then
		if DEV_MODE then
			warn("[Starship] Access denied for module: " .. moduleName)
		end
		return false
	elseif data and data.error then
		if DEV_MODE then
			warn("[Starship] API error for " .. moduleName .. ": " .. tostring(data.error))
		end
		return false
	else
		if DEV_MODE then
			warn("[Starship] Unknown response format for " .. moduleName)
			warn("[Starship] Data: " .. tostring(data and HttpService:JSONEncode(data) or "nil"))
		end
		return false
	end
end

local function downloadModules(statusCallback)
	local userId = tostring(game:GetService("Players").LocalPlayer.UserId)
	local totalFiles = #MODULES + #TABS
	local downloaded = 0
	local pending = totalFiles
	
	-- ══════════════════════════════════════════════════════════════════
	-- PARALLEL LOADING - Download all modules simultaneously
	-- Much faster than sequential loading!
	-- ══════════════════════════════════════════════════════════════════
	
	local function onModuleComplete(moduleName, success)
		pending = pending - 1
		if success then
			downloaded = downloaded + 1
		end
		if statusCallback then
			statusCallback("Loading: " .. moduleName, (totalFiles - pending) / totalFiles)
		end
	end
	
	-- Spawn parallel downloads for main modules
	for _, moduleName in ipairs(MODULES) do
		task.spawn(function()
			local success = downloadModule(moduleName, userId)
			onModuleComplete(moduleName, success)
		end)
	end
	
	-- Spawn parallel downloads for tab modules
	for _, tabName in ipairs(TABS) do
		task.spawn(function()
			local fullName = "Tabs/" .. tabName
			local success = downloadModule(fullName, userId)
			onModuleComplete(fullName, success)
		end)
	end
	
	-- Wait for all downloads to complete (with timeout)
	local startTime = tick()
	local timeout = 30 -- 30 second timeout
	
	while pending > 0 and (tick() - startTime) < timeout do
		if statusCallback then
			statusCallback("Loading modules... (" .. (totalFiles - pending) .. "/" .. totalFiles .. ")", (totalFiles - pending) / totalFiles)
		end
		task.wait(0.05)
	end
	
	-- Final status update
	if statusCallback then
		if pending > 0 then
			statusCallback("⚠️ Some modules failed to load", 1)
		else
			statusCallback("✅ All modules loaded!", 1)
		end
	end

	-- Store loaded modules in global for main script to access
	getgenv().StarshipModules = LoadedModules

	-- Store AnimDB in _G for easier access by Tools.lua and other modules
	if LoadedModules["Animations.lua"] then
		_G.StarshipAnimDB = LoadedModules["Animations.lua"]
	end

	return downloaded == totalFiles
end

-- ══════════════════════════════════════════════════════════════════
-- LANGUAGE PICKER: Simple modal for first-time users to select language
-- ══════════════════════════════════════════════════════════════════
local CONFIG_FILE = FOLDER_NAME .. "/config.json"

local function getSavedLanguage()
	local success, result = pcall(function()
		-- First check config.json (Language Picker style)
		if isfile and isfile(CONFIG_FILE) then
			local content = readfile(CONFIG_FILE)
			local data = HttpService:JSONDecode(content)
			if data.language then
				return data.language
			end
		end
		-- Fallback: check Language.json (ConfigTab style)
		local LANG_FILE = FOLDER_NAME .. "/StarshipConfigs/Language.json"
		if isfile and isfile(LANG_FILE) then
			local content = readfile(LANG_FILE)
			local data = HttpService:JSONDecode(content)
			if data.Language then
				return data.Language
			end
		end
		return nil
	end)
	return success and result or nil
end

local function saveLanguage(lang)
	pcall(function()
		local data = {}
		-- Load existing config
		if isfile and isfile(CONFIG_FILE) then
			local content = readfile(CONFIG_FILE)
			local parsed = HttpService:JSONDecode(content)
			if parsed then
				data = parsed
			end
		end
		data.language = lang
		if writefile then
			writefile(CONFIG_FILE, HttpService:JSONEncode(data))
		end

		-- ALSO save to Language.json for consistency with ConfigTab
		local LANG_FOLDER = FOLDER_NAME .. "/StarshipConfigs"
		local LANG_FILE = LANG_FOLDER .. "/Language.json"
		if not isfolder(LANG_FOLDER) then
			makefolder(LANG_FOLDER)
		end
		writefile(LANG_FILE, HttpService:JSONEncode({ Language = lang }))
	end)
end

local function showLanguagePicker()
	local CoreGui = game:GetService("CoreGui")
	local TweenService = game:GetService("TweenService")

	local selectedLang = nil

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "StarshipLanguage"
	ScreenGui.Parent = CoreGui
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.DisplayOrder = 10001
	ScreenGui.IgnoreGuiInset = true

	-- Background
	local Overlay = Instance.new("Frame", ScreenGui)
	Overlay.Size = UDim2.new(1, 0, 1, 0)
	Overlay.BackgroundColor3 = Color3.fromRGB(8, 8, 15)
	Overlay.BackgroundTransparency = 0
	Overlay.BorderSizePixel = 0

	-- Modal
	local Modal = Instance.new("Frame", ScreenGui)
	Modal.Size = UDim2.new(0, 350, 0, 200)
	Modal.Position = UDim2.new(0.5, -175, 0.5, -100)
	Modal.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	Modal.BorderSizePixel = 0
	Instance.new("UICorner", Modal).CornerRadius = UDim.new(0, 16)

	-- Accent bar
	local Accent = Instance.new("Frame", Modal)
	Accent.Size = UDim2.new(1, 0, 0, 4)
	Accent.BackgroundColor3 = Color3.fromRGB(90, 110, 245)
	Accent.BorderSizePixel = 0
	Instance.new("UICorner", Accent).CornerRadius = UDim.new(0, 16)

	-- Title
	local Title = Instance.new("TextLabel", Modal)
	Title.Text = "🌍 Select Language"
	Title.Size = UDim2.new(1, 0, 0, 40)
	Title.Position = UDim2.new(0, 0, 0, 20)
	Title.BackgroundTransparency = 1
	Title.TextColor3 = Color3.fromRGB(220, 220, 230)
	Title.Font = Enum.Font.GothamBold
	Title.TextSize = 20

	-- Subtitle
	local Subtitle = Instance.new("TextLabel", Modal)
	Subtitle.Text = "Choose your preferred language"
	Subtitle.Size = UDim2.new(1, 0, 0, 20)
	Subtitle.Position = UDim2.new(0, 0, 0, 55)
	Subtitle.BackgroundTransparency = 1
	Subtitle.TextColor3 = Color3.fromRGB(140, 140, 160)
	Subtitle.Font = Enum.Font.Gotham
	Subtitle.TextSize = 13

	-- Button container
	local BtnContainer = Instance.new("Frame", Modal)
	BtnContainer.Size = UDim2.new(1, -40, 0, 60)
	BtnContainer.Position = UDim2.new(0, 20, 0, 100)
	BtnContainer.BackgroundTransparency = 1

	local BtnLayout = Instance.new("UIListLayout", BtnContainer)
	BtnLayout.FillDirection = Enum.FillDirection.Horizontal
	BtnLayout.Padding = UDim.new(0, 15)
	BtnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Indonesia button
	local BtnID = Instance.new("TextButton", BtnContainer)
	BtnID.Size = UDim2.new(0, 140, 0, 50)
	BtnID.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	BtnID.Text = "🇮🇩  Indonesia"
	BtnID.TextColor3 = Color3.new(1, 1, 1)
	BtnID.Font = Enum.Font.GothamBold
	BtnID.TextSize = 15
	BtnID.BorderSizePixel = 0
	Instance.new("UICorner", BtnID).CornerRadius = UDim.new(0, 10)

	local BtnIDStroke = Instance.new("UIStroke", BtnID)
	BtnIDStroke.Color = Color3.fromRGB(90, 110, 245)
	BtnIDStroke.Thickness = 0

	-- English button
	local BtnEN = Instance.new("TextButton", BtnContainer)
	BtnEN.Size = UDim2.new(0, 140, 0, 50)
	BtnEN.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	BtnEN.Text = "🇺🇸  English"
	BtnEN.TextColor3 = Color3.new(1, 1, 1)
	BtnEN.Font = Enum.Font.GothamBold
	BtnEN.TextSize = 15
	BtnEN.BorderSizePixel = 0
	Instance.new("UICorner", BtnEN).CornerRadius = UDim.new(0, 10)

	local BtnENStroke = Instance.new("UIStroke", BtnEN)
	BtnENStroke.Color = Color3.fromRGB(90, 110, 245)
	BtnENStroke.Thickness = 0

	-- Hover effects
	BtnID.MouseEnter:Connect(function()
		TweenService:Create(BtnID, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(60, 60, 80) }):Play()
		TweenService:Create(BtnIDStroke, TweenInfo.new(0.2), { Thickness = 2 }):Play()
	end)
	BtnID.MouseLeave:Connect(function()
		TweenService:Create(BtnID, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(40, 40, 55) }):Play()
		TweenService:Create(BtnIDStroke, TweenInfo.new(0.2), { Thickness = 0 }):Play()
	end)
	BtnEN.MouseEnter:Connect(function()
		TweenService:Create(BtnEN, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(60, 60, 80) }):Play()
		TweenService:Create(BtnENStroke, TweenInfo.new(0.2), { Thickness = 2 }):Play()
	end)
	BtnEN.MouseLeave:Connect(function()
		TweenService:Create(BtnEN, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(40, 40, 55) }):Play()
		TweenService:Create(BtnENStroke, TweenInfo.new(0.2), { Thickness = 0 }):Play()
	end)

	-- Click handlers
	BtnID.MouseButton1Click:Connect(function()
		selectedLang = "id"
		TweenService:Create(BtnID, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(90, 110, 245) }):Play()
	end)
	BtnEN.MouseButton1Click:Connect(function()
		selectedLang = "en"
		TweenService:Create(BtnEN, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(90, 110, 245) }):Play()
	end)

	-- Entrance animation
	Modal.Position = UDim2.new(0.5, -175, 1.5, 0)
	Overlay.BackgroundTransparency = 1
	TweenService:Create(Overlay, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(Modal, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -175, 0.5, -100),
	}):Play()

	-- Wait for selection
	while selectedLang == nil do
		task.wait(0.1)
	end

	-- Save and set global
	saveLanguage(selectedLang)
	_G.StarshipLanguage = selectedLang

	-- Exit animation
	TweenService:Create(Overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(Modal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, -175, 1.5, 0),
	}):Play()

	task.wait(0.3)
	ScreenGui:Destroy()

	return selectedLang
end

-- Legacy Firebase authentication removed
-- Now using secure API endpoint /api/load for all authentication

local function createLoadingUI()
	local CoreGui = game:GetService("CoreGui")
	local TweenService = game:GetService("TweenService")
	local LoaderGui = Instance.new("ScreenGui")
	LoaderGui.Name = "StarshipIntro"
	LoaderGui.Parent = CoreGui
	LoaderGui.IgnoreGuiInset = true
	LoaderGui.DisplayOrder = 10000

	local MainFrame = Instance.new("Frame", LoaderGui)
	MainFrame.Size = UDim2.new(1, 0, 1, 0)
	MainFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 15)
	MainFrame.BackgroundTransparency = 0

	-- Background is now uniform (removed gradient overlays that caused visible line)

	-- Large Logo Overlay in center (replaces circle glow)
	local CenterLogo = Instance.new("ImageLabel", MainFrame)
	CenterLogo.Name = "CenterLogoOverlay"
	CenterLogo.Size = UDim2.new(0, 450, 0, 450)
	CenterLogo.Position = UDim2.new(0.5, -225, 0.4, -225)
	CenterLogo.BackgroundTransparency = 1
	CenterLogo.Image = "rbxassetid://123840945153526" -- Starship Logo
	CenterLogo.ImageTransparency = 0.85 -- Subtle watermark effect
	CenterLogo.ImageColor3 = Color3.fromRGB(255, 255, 255)
	CenterLogo.ScaleType = Enum.ScaleType.Fit
	CenterLogo.ZIndex = 1

	-- Floating Particles Container
	local ParticleContainer = Instance.new("Frame", MainFrame)
	ParticleContainer.Size = UDim2.new(1, 0, 1, 0)
	ParticleContainer.BackgroundTransparency = 1
	ParticleContainer.ClipsDescendants = true
	ParticleContainer.ZIndex = 2

	-- OPTIMIZED: Reduced particle count 40 → 25 for better performance
	task.spawn(function()
		for i = 1, 25 do
			if not LoaderGui or not LoaderGui.Parent then
				break
			end

			local particleType = math.random(1, 3)
			local particle = Instance.new("Frame", ParticleContainer)

			local baseSize = math.random(2, 6)
			particle.Size = UDim2.new(0, baseSize, 0, baseSize)
			particle.Position = UDim2.new(math.random(), 0, math.random(), 0)
			particle.BackgroundColor3 = Color3.fromHSV(0.65 + math.random() * 0.1, 0.8, 1)
			particle.BackgroundTransparency = math.random() * 0.3 + 0.4
			particle.BorderSizePixel = 0
			particle.ZIndex = 3

			local corner = Instance.new("UICorner", particle)
			if particleType == 1 then
				corner.CornerRadius = UDim.new(1, 0)
			elseif particleType == 2 then
				corner.CornerRadius = UDim.new(0, 2)
			else
				corner.CornerRadius = UDim.new(0, 1)
				particle.Rotation = 45
			end

			local glow = Instance.new("UIStroke", particle)
			glow.Color = particle.BackgroundColor3
			glow.Thickness = 1
			glow.Transparency = 0.6

			task.spawn(function()
				local startY = particle.Position.Y.Scale
				local startX = particle.Position.X.Scale
				local swayOffset = math.random() * math.pi * 2
				local swaySpeed = math.random(15, 35) / 10
				local floatSpeed = math.random(12, 25) / 10000

				while particle and particle.Parent do
					local newY = startY - floatSpeed
					if newY < -0.15 then
						newY = 1.15
						startY = 1.15
						startX = math.random()
					end
					startY = newY

					local sway = math.sin(os.clock() * swaySpeed + swayOffset) * 0.025
					particle.Position = UDim2.new(startX + sway, 0, newY, 0)
					particle.BackgroundTransparency = 0.4 + math.sin(os.clock() * 2 + i) * 0.2
					if glow then
						glow.Transparency = 0.5 + math.sin(os.clock() * 2.5 + i) * 0.25
					end

					task.wait(0.025)
				end
			end)
			task.wait(0.04)
		end
	end)

	-- Logo Icon with FLOATING effect (Image version)
	local LogoContainer = Instance.new("Frame", MainFrame)
	LogoContainer.Size = UDim2.new(0, 140, 0, 140)
	LogoContainer.Position = UDim2.new(0.5, -70, 0.26, 0)
	LogoContainer.BackgroundTransparency = 1
	LogoContainer.ZIndex = 10

	local Logo = Instance.new("ImageLabel", LogoContainer)
	Logo.Image = "rbxassetid://123840945153526"
	Logo.Size = UDim2.new(1, 0, 1, 0)
	Logo.BackgroundTransparency = 1
	Logo.ScaleType = Enum.ScaleType.Fit
	Logo.ZIndex = 10

	-- Title Text
	local Title = Instance.new("TextLabel", MainFrame)
	Title.Text = "STARSHIP"
	Title.Size = UDim2.new(1, 0, 0, 50)
	Title.Position = UDim2.new(0, 0, 0.46, 0)
	Title.BackgroundTransparency = 1
	Title.TextColor3 = Color3.fromRGB(90, 110, 245)
	Title.Font = Enum.Font.GothamBlack
	Title.TextSize = 42
	Title.TextTransparency = 0
	Title.RichText = true
	Title.ZIndex = 10

	-- Subtitle / Status Text
	local Sub = Instance.new("TextLabel", MainFrame)
	Sub.Text = "INITIALIZING..."
	Sub.Size = UDim2.new(1, 0, 0, 25)
	Sub.Position = UDim2.new(0, 0, 0.53, 0)
	Sub.BackgroundTransparency = 1
	Sub.TextColor3 = Color3.fromRGB(180, 180, 190)
	Sub.Font = Enum.Font.GothamMedium
	Sub.TextSize = 14
	Sub.TextTransparency = 0
	Sub.ZIndex = 10

	-- Progress Bar Container with GLOW
	local ProgressContainer = Instance.new("Frame", MainFrame)
	ProgressContainer.Size = UDim2.new(0.3, 0, 0, 6)
	ProgressContainer.Position = UDim2.new(0.35, 0, 0.58, 0)
	ProgressContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	ProgressContainer.BackgroundTransparency = 0
	ProgressContainer.ZIndex = 10
	Instance.new("UICorner", ProgressContainer).CornerRadius = UDim.new(1, 0)

	local ProgressGlow = Instance.new("UIStroke", ProgressContainer)
	ProgressGlow.Color = Color3.fromRGB(90, 110, 245)
	ProgressGlow.Thickness = 1
	ProgressGlow.Transparency = 0.7

	local ProgressFill = Instance.new("Frame", ProgressContainer)
	ProgressFill.Size = UDim2.new(0, 0, 1, 0)
	ProgressFill.BackgroundColor3 = Color3.fromRGB(90, 110, 245)
	ProgressFill.ZIndex = 11
	Instance.new("UICorner", ProgressFill).CornerRadius = UDim.new(1, 0)

	-- Add gradient to progress fill
	local ProgressGradient = Instance.new("UIGradient", ProgressFill)
	ProgressGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 90, 200)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(130, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 110, 245)),
	})

	-- Progress Percentage
	local ProgressText = Instance.new("TextLabel", MainFrame)
	ProgressText.Text = "0%"
	ProgressText.Size = UDim2.new(1, 0, 0, 20)
	ProgressText.Position = UDim2.new(0, 0, 0.61, 0)
	ProgressText.BackgroundTransparency = 1
	ProgressText.TextColor3 = Color3.fromRGB(120, 140, 255)
	ProgressText.Font = Enum.Font.GothamBold
	ProgressText.TextSize = 12
	ProgressText.TextTransparency = 0
	ProgressText.ZIndex = 10

	-- Welcome Message
	local WelcomeMsg = Instance.new("TextLabel", MainFrame)
	WelcomeMsg.Text = "Welcome back, " .. game:GetService("Players").LocalPlayer.Name .. "!"
	WelcomeMsg.Size = UDim2.new(1, 0, 0, 20)
	WelcomeMsg.Position = UDim2.new(0, 0, 0.20, 0)
	WelcomeMsg.BackgroundTransparency = 1
	WelcomeMsg.TextColor3 = Color3.fromRGB(140, 140, 160)
	WelcomeMsg.Font = Enum.Font.Gotham
	WelcomeMsg.TextSize = 14
	WelcomeMsg.TextTransparency = 0
	WelcomeMsg.ZIndex = 10

	-- Logo Animation: Pulse + FLOATING
	task.spawn(function()
		local t = 0
		local floatOffset = 0
		local baseSize = 140
		while Logo and Logo.Parent do
			t = t + 0.025
			floatOffset = floatOffset + 0.08

			-- Rainbow color cycle (faster)
			local c = Color3.fromHSV(t % 1, 0.85, 1)
			Title.TextColor3 = c
			ProgressFill.BackgroundColor3 = c
			ProgressGlow.Color = c

			-- Pulse size for container
			local pulse = 1 + math.sin(t * 4) * 0.05
			local newSize = baseSize * pulse
			LogoContainer.Size = UDim2.new(0, newSize, 0, newSize)
			LogoContainer.Position = UDim2.new(0.5, -newSize / 2, 0.31, math.sin(floatOffset) * 5)

			task.wait(0.02)
		end
	end)

	return LoaderGui,
		function(text, progress)
			-- Obfuscate specific module names
			if string.find(text, "Downloading:") then
				text = "Loading Module #" .. math.random(1000, 9999)
			elseif string.find(text, "Updating modules") then
				text = "Preparing Assets..."
			end

			Sub.Text = text
			TweenService:Create(
				ProgressFill,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(progress, 0, 1, 0) }
			):Play()
			ProgressText.Text = math.floor(progress * 100) .. "%"
		end
end

local function showError(message)
	local CoreGui = game:GetService("CoreGui")
	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")

	-- Detect error type from message
	local errorType = "denied" -- default
	local titleText = "🚫 ACCESS DENIED"
	local titleColor = Color3.fromRGB(255, 80, 80)
	local frameColor = Color3.fromRGB(30, 30, 35)
	local accentColor = Color3.fromRGB(255, 80, 80)

	if message:lower():find("not whitelisted") or message:lower():find("authentication required") then
		errorType = "auth_required"
		titleText = "🔒 AUTHENTICATION REQUIRED"
		titleColor = Color3.fromRGB(255, 165, 0) -- Orange
		accentColor = Color3.fromRGB(255, 165, 0)
		message = "⚠️ Your account is not authorized to use Starship.\n\n💎 To get VIP access, contact the administrator.\n\n📌 Your User ID: "
			.. tostring(Players.LocalPlayer.UserId)
	elseif message:lower():find("suspended") or message:lower():find("banned") then
		errorType = "banned"
		titleText = "🚫 ACCOUNT SUSPENDED"
		titleColor = Color3.fromRGB(200, 0, 0) -- Dark Red
		accentColor = Color3.fromRGB(200, 0, 0)
		message = "❌ Your VIP access has been suspended.\n\n📧 Contact administrator for more information.\n\n📌 Your User ID: "
			.. tostring(Players.LocalPlayer.UserId)
	elseif message:lower():find("expired") then
		errorType = "expired"
		titleText = "⏰ VIP ACCESS EXPIRED"
		titleColor = Color3.fromRGB(255, 200, 0) -- Yellow
		accentColor = Color3.fromRGB(255, 200, 0)
		message = "⌛ Your VIP subscription has expired.\n\n🔄 Renew your access to continue using Starship.\n\n📌 Your User ID: "
			.. tostring(Players.LocalPlayer.UserId)
	elseif message:lower():find("connection") or message:lower():find("unreachable") then
		errorType = "connection"
		titleText = "📡 CONNECTION ERROR"
		titleColor = Color3.fromRGB(100, 100, 255) -- Blue
		accentColor = Color3.fromRGB(100, 100, 255)
		message = "🌐 Cannot connect to Starship server.\n\n🔄 Please check your internet connection and try again."
	end

	-- Create enhanced error UI
	local ErrorGui = Instance.new("ScreenGui")
	ErrorGui.Name = "StarshipError"
	ErrorGui.Parent = CoreGui
	ErrorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Background blur effect
	local BlurFrame = Instance.new("Frame", ErrorGui)
	BlurFrame.Size = UDim2.new(1, 0, 1, 0)
	BlurFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	BlurFrame.BackgroundTransparency = 0.5
	BlurFrame.BorderSizePixel = 0

	-- Main Frame
	local Frame = Instance.new("Frame", ErrorGui)
	Frame.Size = UDim2.new(0, 380, 0, 180)
	Frame.Position = UDim2.new(0.5, -190, 0.5, -90)
	Frame.BackgroundColor3 = frameColor
	Frame.BorderSizePixel = 0

	local Corner = Instance.new("UICorner", Frame)
	Corner.CornerRadius = UDim.new(0, 12)

	-- Accent bar at top
	local AccentBar = Instance.new("Frame", Frame)
	AccentBar.Size = UDim2.new(1, 0, 0, 4)
	AccentBar.BackgroundColor3 = accentColor
	AccentBar.BorderSizePixel = 0
	local AccentCorner = Instance.new("UICorner", AccentBar)
	AccentCorner.CornerRadius = UDim.new(0, 12)

	-- Shadow effect
	local Shadow = Instance.new("Frame", Frame)
	Shadow.Size = UDim2.new(1, 20, 1, 20)
	Shadow.Position = UDim2.new(0, -10, 0, -10)
	Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Shadow.BackgroundTransparency = 0.7
	Shadow.ZIndex = 0
	local ShadowCorner = Instance.new("UICorner", Shadow)
	ShadowCorner.CornerRadius = UDim.new(0, 12)

	-- Title
	local Title = Instance.new("TextLabel", Frame)
	Title.Text = titleText
	Title.Size = UDim2.new(1, -20, 0, 35)
	Title.Position = UDim2.new(0, 10, 0, 15)
	Title.BackgroundTransparency = 1
	Title.TextColor3 = titleColor
	Title.Font = Enum.Font.GothamBold
	Title.TextSize = 18
	Title.TextXAlignment = Enum.TextXAlignment.Left

	-- Message
	local Msg = Instance.new("TextLabel", Frame)
	Msg.Text = message
	Msg.Size = UDim2.new(1, -30, 0, 100)
	Msg.Position = UDim2.new(0, 15, 0, 55)
	Msg.BackgroundTransparency = 1
	Msg.TextColor3 = Color3.fromRGB(220, 220, 220)
	Msg.Font = Enum.Font.Gotham
	Msg.TextSize = 13
	Msg.TextWrapped = true
	Msg.TextYAlignment = Enum.TextYAlignment.Top
	Msg.TextXAlignment = Enum.TextXAlignment.Left

	-- Close button
	local CloseButton = Instance.new("TextButton", Frame)
	CloseButton.Size = UDim2.new(0, 100, 0, 30)
	CloseButton.Position = UDim2.new(0.5, -50, 1, -40)
	CloseButton.BackgroundColor3 = accentColor
	CloseButton.Text = "Close"
	CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	CloseButton.Font = Enum.Font.GothamBold
	CloseButton.TextSize = 14
	CloseButton.BorderSizePixel = 0
	local ButtonCorner = Instance.new("UICorner", CloseButton)
	ButtonCorner.CornerRadius = UDim.new(0, 6)

	-- Entrance animation
	Frame.Position = UDim2.new(0.5, -190, -0.5, -90)
	TweenService:Create(Frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -190, 0.5, -90),
	}):Play()

	-- Close button functionality
	CloseButton.MouseButton1Click:Connect(function()
		TweenService:Create(Frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -190, 1.5, -90),
		}):Play()
		TweenService:Create(BlurFrame, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {
			BackgroundTransparency = 1,
		}):Play()
		task.wait(0.3)
		ErrorGui:Destroy()
	end)

	-- Auto-close after 10 seconds
	task.spawn(function()
		task.wait(10)
		if ErrorGui and ErrorGui.Parent then
			TweenService:Create(Frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, -190, 1.5, -90),
			}):Play()
			TweenService:Create(BlurFrame, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {
				BackgroundTransparency = 1,
			}):Play()
			task.wait(0.3)
			ErrorGui:Destroy()
		end
	end)
end

-- Configuration (Production) - Uses SERVER_URL defined at top

-- Check system status before loading
local function checkSystemStatus()
	local statusUrl = SERVER_URL .. "/api/tags?action=status"
	local success, response = pcall(function()
		return game:HttpGet(statusUrl)
	end)

	if not success then
		return true, nil -- If can't check, assume online
	end

	local data = nil
	pcall(function()
		data = HttpService:JSONDecode(response)
	end)

	if data and data.success then
		-- Block if maintenance, offline, or updating
		if data.status == "maintenance" or data.status == "offline" or data.status == "updating" then
			return false, data
		end
	end

	return true, data
end

-- Show maintenance/offline UI
local function showMaintenanceUI(statusData)
	local CoreGui = game:GetService("CoreGui")
	local TweenService = game:GetService("TweenService")

	local statusEmoji = statusData.emoji or "🔧"
	local statusLabel = statusData.label or "Maintenance"
	local statusMessage = statusData.message or "System is under maintenance"

	-- Colors based on status
	local bgColor = Color3.fromRGB(255, 152, 0) -- Orange default
	local textColor = Color3.fromRGB(255, 255, 255)

	if statusData.status == "offline" then
		bgColor = Color3.fromRGB(244, 67, 54) -- Red
	elseif statusData.status == "updating" then
		bgColor = Color3.fromRGB(33, 150, 243) -- Blue
	end

	local MaintenanceGui = Instance.new("ScreenGui")
	MaintenanceGui.Name = "StarshipMaintenance"
	MaintenanceGui.Parent = CoreGui
	MaintenanceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Background
	local BlurFrame = Instance.new("Frame", MaintenanceGui)
	BlurFrame.Size = UDim2.new(1, 0, 1, 0)
	BlurFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	BlurFrame.BackgroundTransparency = 0.3

	-- Main Frame
	local Frame = Instance.new("Frame", MaintenanceGui)
	Frame.Size = UDim2.new(0, 400, 0, 220)
	Frame.Position = UDim2.new(0.5, -200, 0.5, -110)
	Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	Frame.BorderSizePixel = 0
	Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 12)

	-- Accent bar at top
	local AccentBar = Instance.new("Frame", Frame)
	AccentBar.Size = UDim2.new(1, 0, 0, 6)
	AccentBar.BackgroundColor3 = bgColor
	AccentBar.BorderSizePixel = 0
	Instance.new("UICorner", AccentBar).CornerRadius = UDim.new(0, 12)

	-- Status Icon
	local Icon = Instance.new("TextLabel", Frame)
	Icon.Text = statusEmoji
	Icon.Size = UDim2.new(1, 0, 0, 60)
	Icon.Position = UDim2.new(0, 0, 0, 20)
	Icon.BackgroundTransparency = 1
	Icon.TextSize = 48

	-- Title
	local Title = Instance.new("TextLabel", Frame)
	Title.Text = "⚠️ " .. string.upper(statusLabel)
	Title.Size = UDim2.new(1, -20, 0, 30)
	Title.Position = UDim2.new(0, 10, 0, 85)
	Title.BackgroundTransparency = 1
	Title.TextColor3 = bgColor
	Title.Font = Enum.Font.GothamBold
	Title.TextSize = 20

	-- Message
	local Msg = Instance.new("TextLabel", Frame)
	Msg.Text = statusMessage
	Msg.Size = UDim2.new(1, -30, 0, 40)
	Msg.Position = UDim2.new(0, 15, 0, 120)
	Msg.BackgroundTransparency = 1
	Msg.TextColor3 = Color3.fromRGB(200, 200, 200)
	Msg.Font = Enum.Font.Gotham
	Msg.TextSize = 14
	Msg.TextWrapped = true

	-- Info text
	local Info = Instance.new("TextLabel", Frame)
	Info.Text = "Please try again later. Check Discord for updates."
	Info.Size = UDim2.new(1, -30, 0, 25)
	Info.Position = UDim2.new(0, 15, 0, 165)
	Info.BackgroundTransparency = 1
	Info.TextColor3 = Color3.fromRGB(130, 130, 130)
	Info.Font = Enum.Font.Gotham
	Info.TextSize = 12

	-- Close button
	local CloseBtn = Instance.new("TextButton", Frame)
	CloseBtn.Size = UDim2.new(0, 100, 0, 32)
	CloseBtn.Position = UDim2.new(0.5, -50, 1, -45)
	CloseBtn.BackgroundColor3 = bgColor
	CloseBtn.Text = "Close"
	CloseBtn.TextColor3 = textColor
	CloseBtn.Font = Enum.Font.GothamBold
	CloseBtn.TextSize = 14
	CloseBtn.BorderSizePixel = 0
	Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

	-- Entrance animation
	Frame.Position = UDim2.new(0.5, -200, -0.5, -110)
	TweenService:Create(Frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -200, 0.5, -110),
	}):Play()

	CloseBtn.MouseButton1Click:Connect(function()
		MaintenanceGui:Destroy()
	end)

	-- Also animate the icon
	task.spawn(function()
		while Icon and Icon.Parent do
			TweenService:Create(Icon, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.new(0, 0, 0, 15),
			}):Play()
			task.wait(1)
			TweenService:Create(Icon, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.new(0, 0, 0, 25),
			}):Play()
			task.wait(1)
		end
	end)
end

-- ══════════════════════════════════════════════════════════════════
-- COMPENSATION TOAST NOTIFICATION (PC)
-- Shows after maintenance when VIP duration is extended
-- ══════════════════════════════════════════════════════════════════
local function showCompensationToast(announcement)
	if not announcement then
		return
	end

	local CoreGui = game:GetService("CoreGui")
	local TweenService = game:GetService("TweenService")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StarshipCompensationToast"
	screenGui.Parent = CoreGui
	screenGui.DisplayOrder = 10002
	screenGui.IgnoreGuiInset = true

	-- Toast Container
	local container = Instance.new("Frame")
	container.Name = "ToastContainer"
	container.Size = UDim2.new(0, 350, 0, 160)
	container.Position = UDim2.new(0.5, -175, 0, -200) -- Start off screen
	container.AnchorPoint = Vector2.new(0, 0)
	container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	container.BorderSizePixel = 0
	container.Parent = screenGui

	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 16)

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = Color3.fromRGB(34, 197, 94) -- Green for success
	containerStroke.Thickness = 2
	containerStroke.Parent = container

	-- Shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 20, 1, 20)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.7
	shadow.ZIndex = -1
	shadow.Parent = container
	Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 20)

	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0, 40)
	icon.Position = UDim2.new(0.5, 0, 0, 15)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "🎁"
	icon.TextSize = 32
	icon.Font = Enum.Font.GothamBold
	icon.Parent = container

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -30, 0, 25)
	title.Position = UDim2.new(0.5, 0, 0, 55)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.BackgroundTransparency = 1
	title.Text = announcement.title or "🎁 Kompensasi Maintenance"
	title.TextColor3 = Color3.fromRGB(34, 197, 94)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.Parent = container

	-- Message
	local message = Instance.new("TextLabel")
	message.Size = UDim2.new(1, -30, 0, 40)
	message.Position = UDim2.new(0.5, 0, 0, 85)
	message.AnchorPoint = Vector2.new(0.5, 0)
	message.BackgroundTransparency = 1
	message.Text = announcement.message or "VIP Anda telah diperpanjang!"
	message.TextColor3 = Color3.fromRGB(255, 255, 255)
	message.TextSize = 14
	message.Font = Enum.Font.Gotham
	message.TextWrapped = true
	message.Parent = container

	-- Thanks message
	local thanks = Instance.new("TextLabel")
	thanks.Size = UDim2.new(1, -30, 0, 20)
	thanks.Position = UDim2.new(0.5, 0, 1, -25)
	thanks.AnchorPoint = Vector2.new(0.5, 0)
	thanks.BackgroundTransparency = 1
	thanks.Text = "Terima kasih atas kesabarannya! 💜"
	thanks.TextColor3 = Color3.fromRGB(161, 161, 170)
	thanks.TextSize = 11
	thanks.Font = Enum.Font.Gotham
	thanks.Parent = container

	-- Animate in (slide down)
	TweenService:Create(container, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -175, 0, 80),
	}):Play()

	-- Auto close after 8 seconds
	task.delay(8, function()
		if screenGui and screenGui.Parent then
			-- Animate out (slide up)
			TweenService:Create(container, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, -175, 0, -200),
			}):Play()

			task.wait(0.5)
			if screenGui and screenGui.Parent then
				screenGui:Destroy()
			end
		end
	end)
end

-- Function to check and show pending announcement from API
local function checkAndShowAnnouncement(userId)
	task.spawn(function()
		task.wait(3) -- Wait for UI to initialize

		local url = SERVER_URL .. "/api/load?userId=" .. userId .. "&platform=pc&action=check_announcement"
		local success, response = pcall(function()
			return game:HttpGet(url)
		end)

		if success and response then
			local data = nil
			pcall(function()
				data = HttpService:JSONDecode(response)
			end)

			if data and data.announcement and data.announcement.type == "compensation" then
				showCompensationToast(data.announcement)
			end
		end
	end)
end

local function main()
	-- 🔒 CHECK SYSTEM STATUS FIRST
	local isOnline, statusData = checkSystemStatus()
	if not isOnline and statusData then
		showMaintenanceUI(statusData)
		return -- Stop execution if maintenance/offline
	end

	local loaderGui, updateStatus = createLoadingUI()

	-- 1. Setup Environment
	updateStatus("Setting up environment...", 0.1)
	setupFolders()
	task.wait(0.2)

	-- 2. Download Modules (Tetap dari host lama atau bisa dipindah nanti)
	updateStatus("Updating modules...", 0.2)
	downloadModules(function(text, progress)
		updateStatus(text, 0.2 + (progress * 0.3))
	end)

	-- 3. Secure Login & Download Script
	-- 🔒 Auto-detect User ID (cannot be hardcoded by users!)
	updateStatus("Authenticating with Secure Server...", 0.6)
	task.wait(0.5)

	-- Auto-detect userId from current logged-in player
	local userId = tostring(game:GetService("Players").LocalPlayer.UserId)

	-- Detect device HWID for binding
	local deviceHWID = getDeviceHWID()

	-- SKIP second API call if CDN is enabled (already authenticated via initial loadstring)
	local authResponse = nil
	local authSuccess = true
	
	if _G.StarshipCDN and _G.StarshipCDN.enabled then
		-- CDN mode: Authentication was already done, skip redundant API call
		authResponse = "-- CDN mode: Already authenticated"
	else
		-- Standard mode: Call secure loader for authentication & webhook notification
		-- SECURITY: Using obscured endpoint name with HWID
		local authUrl = SERVER_URL .. "/api/pc-ld-q8r4?userId=" .. userId .. "&hwid=" .. HttpService:UrlEncode(deviceHWID)
		authSuccess, authResponse = pcall(function()
			return game:HttpGet(authUrl)
		end)
		
		if not authSuccess then
			if loaderGui then
				loaderGui:Destroy()
			end
			showError("Connection Failed: Server Unreachable")
			return
		end

		-- Check if authentication was successful (should return loader.lua script or error)
		if authResponse:find("error%(") or authResponse:find("ERROR:") then
			if loaderGui then
				loaderGui:Destroy()
			end
			-- Extract error message from Lua error string
			local errorMsg = authResponse:match('error%("(.-)"%)')
			showError(errorMsg or "Authentication Failed")
			return
		end
	end -- Close CDN check if-else

	-- STEP 2: Now call /api/load to get the encrypted script (with HWID)
	local targetUrl = SERVER_URL .. "/api/load?user=" .. userId .. "&hwid=" .. HttpService:UrlEncode(deviceHWID)

	local success, response = pcall(function()
		return game:HttpGet(targetUrl)
	end)

	if not success then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Connection Failed: Server Unreachable")
		return
	end

	-- 4. Handle Response with Secure Payload Verification
	-- ═══════════════════════════════════════════════════════════════════
	-- SECURITY v3.0: Verify token with SERVER (no secrets on client!)
	-- ═══════════════════════════════════════════════════════════════════
	local data, verifyError = extractSecureData(response, userId)

	if not data then
		if loaderGui then
			loaderGui:Destroy()
		end
		-- Check if it's a security error
		if verifyError == "INVALID_SIGNATURE" then
			showError("Security Error: Data tampering detected")
		elseif verifyError == "EXPIRED" then
			showError("Security Error: Session expired. Please restart.")
		else
			showError("Server Error: " .. tostring(verifyError or "Invalid Response"))
		end
		return
	end

	if data.status == "denied" then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("ACCESS DENIED\n" .. (data.message or "Not Whitelisted"))
		return
	elseif data.status ~= "success" then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Server Error: " .. tostring(data.error or "Unknown"))
		return
	end

	-- 5. Decrypt Dynamic Payload
	updateStatus("Decrypting Secure Payload...", 0.8)

	local encryptedBlob = data.blob
	local dynamicKey = data.key
	local decryptedCode = nil

	if not dynamicKey or not encryptedBlob then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Security Error: Missing Key/Blob")
		return
	end

	-- Decrypt using XOR (simple, compatible with all executors)
	local success, result = pcall(function()
		local encryptedString = base64Decode(encryptedBlob)
		return xorEncrypt(encryptedString, dynamicKey)
	end)

	if not success or not result then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Decryption Error: " .. tostring(result or "Failed"))
		return
	end

	decryptedCode = result

	-- Hapus BOM character jika ada (U+feff) agar loadstring tidak error
	if string.byte(decryptedCode, 1, 3) == "\239\187\191" then
		decryptedCode = string.sub(decryptedCode, 4)
	end

	-- Pass Session Data to Main Script
	getgenv().StarshipSession = {
		Role = data.role or "VIP",
		Duration = data.duration or "LIFETIME",
		Expiry = data.expiry, -- Timestamp expiry (bisa nil jika LIFETIME)
	}

	-- ══════════════════════════════════════════════════════════════════
	-- WATERMARK SYSTEM: Embed unique user identifier for leak tracing
	-- Multiple hidden locations make it difficult to remove all traces
	-- ══════════════════════════════════════════════════════════════════
	local function generateWatermark()
		local wm = {}
		wm.u = userId -- User ID
		wm.t = os.time() -- Timestamp
		wm.h = deviceHWID:sub(1, 8) -- First 8 chars of HWID
		wm.p = "PC" -- Platform
		wm.v = "1.0" -- Version
		-- Create encoded signature
		local sig = userId .. "_" .. os.time() .. "_" .. wm.h
		wm.s = "" -- Signature (encoded)
		for i = 1, #sig do
			wm.s = wm.s .. string.format("%02x", bit32.bxor(string.byte(sig, i), 42))
		end
		return wm
	end

	local _WM = generateWatermark()

	-- Store watermark in multiple hidden locations
	-- Location 1: Global environment (obfuscated key)
	getgenv()["_" .. string.char(83, 87, 77)] = _WM

	-- Location 2: Hidden in game services
	pcall(function()
		local marker = Instance.new("StringValue")
		marker.Name = "_cfg" .. math.random(1000, 9999)
		marker.Value = HttpService:JSONEncode({ _m = _WM.s, _t = _WM.t })
		marker.Parent = game:GetService("ReplicatedStorage")
		-- Auto-cleanup after 60 seconds (but watermark already in memory)
		task.delay(60, function()
			pcall(function()
				marker:Destroy()
			end)
		end)
	end)

	-- Location 3: Attach to session
	getgenv().StarshipSession._wm = _WM.s
	getgenv().StarshipSession._wt = _WM.t

	-- Location 4: Hidden table in _G with random key
	local wmKey = "_x" .. tostring(_WM.t):sub(-4)
	_G[wmKey] = { z = _WM.u, y = _WM.h }

	-- Location 5: Store in closure (survives even if globals cleared)
	local _WATERMARK_DATA = _WM -- This persists in the script's closure

	-- 6. Execute with Smooth Transition
	updateStatus("Launching Starship...", 1.0)
	task.wait(0.3)

	local func, err = loadstring(decryptedCode)
	if not func then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Execution Error: " .. tostring(err))
		return
	end

	-- Smooth Exit Animation
	if loaderGui then
		local TweenService = game:GetService("TweenService")
		local MainFrame = loaderGui:FindFirstChild("Frame")

		-- Fade out all elements smoothly
		for _, element in pairs(loaderGui:GetDescendants()) do
			if element:IsA("TextLabel") or element:IsA("TextButton") then
				TweenService:Create(element, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 1,
				}):Play()
			elseif element:IsA("Frame") and element.Name ~= "Frame" then
				TweenService:Create(element, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 1,
				}):Play()
			elseif element:IsA("UIStroke") then
				TweenService:Create(element, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 1,
				}):Play()
			elseif element:IsA("ImageLabel") then
				TweenService:Create(element, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					ImageTransparency = 1,
				}):Play()
			end
		end

		-- Main frame fade to black then transparent
		if MainFrame then
			TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
		end

		task.wait(0.5)

		-- Signal to main script that intro is done (for smooth Main UI entrance)
		getgenv().StarshipIntroComplete = true

		loaderGui:Destroy()
	end

	-- ══════════════════════════════════════════════════════════════════
	-- LANGUAGE PICKER: Show for first-time users before anything else
	-- ══════════════════════════════════════════════════════════════════
	local savedLang = getSavedLanguage()
	if savedLang then
		-- Use saved language
		_G.StarshipLanguage = savedLang
		if DEV_MODE then
			warn("[Language] Loaded saved language: " .. savedLang)
		end
	else
		-- First-time user, show picker
		if DEV_MODE then
			warn("[Language] No saved language, showing picker...")
		end
		showLanguagePicker()
		if DEV_MODE then
			warn("[Language] Selected: " .. tostring(_G.StarshipLanguage))
		end
	end

	-- ══════════════════════════════════════════════════════════════════
	-- CHANGELOG CHECK: Show update modal BEFORE main UI loads
	-- User must dismiss changelog before main script runs
	-- ══════════════════════════════════════════════════════════════════
	if LoadedModules["Changelog.lua"] then
		local changelogModule = LoadedModules["Changelog.lua"]

		-- Fetch changelog data
		local changelogData = changelogModule.FetchChangelog()
		if changelogData then
			local lastSeen = changelogModule.GetLastSeenVersion()
			local serverVersion = changelogData.currentVersion or "0.0.0"

			-- Check if there's a new version
			if changelogModule.IsNewerVersion(serverVersion, lastSeen) then
				if DEV_MODE then
					warn("[Changelog] New version detected! Showing modal before main UI...")
				end
				-- Show modal in BLOCKING mode - waits until user dismisses
				changelogModule.ShowModal(changelogData, true)
				if DEV_MODE then
					warn("[Changelog] User dismissed changelog, loading main UI...")
				end
			end
		end
	end

	-- Now load the main script
	func()

	-- ══════════════════════════════════════════════════════════════════
	-- CHECK FOR PENDING ANNOUNCEMENTS (Compensation after maintenance)
	-- ══════════════════════════════════════════════════════════════════
	local userId = tostring(game:GetService("Players").LocalPlayer.UserId)
	checkAndShowAnnouncement(userId)

	-- ══════════════════════════════════════════════════════════════════
	-- SECURITY CLEANUP: Remove sensitive data from global environment
	-- This prevents hackers from accessing modules via getgenv()/G
	-- ══════════════════════════════════════════════════════════════════
	task.spawn(function()
		task.wait(5) -- Wait for script to fully initialize

		-- Clear module references from global scope
		if getgenv().StarshipModules then
			-- Modules are already referenced internally, safe to clear global
			getgenv().StarshipModules = nil
		end

		-- Clear AnimDB reference
		if _G.StarshipAnimDB then
			_G.StarshipAnimDB = nil
		end

		-- Note: StarshipSession is kept for legitimate auth checks
		-- Note: StarshipIntroComplete is just a boolean, low risk

		-- Additional cleanup: Clear any temp variables
		if getgenv().StarshipTemp then
			getgenv().StarshipTemp = nil
		end
	end)

	-- ══════════════════════════════════════════════════════════════════
	-- REAL-TIME STATUS MONITORING
	-- Check status every 5 minutes and close UI if maintenance/offline
	-- ══════════════════════════════════════════════════════════════════
	task.spawn(function()
		task.wait(60) -- Wait 1 minute before first check

		while true do
			task.wait(300) -- Check every 5 minutes

			-- Check if StarshipCore is still active
			if not getgenv().StarshipSession then
				break -- Script was closed, stop monitoring
			end

			-- Check system status
			local statusUrl = SERVER_URL .. "/api/tags?action=status"
			local success, response = pcall(function()
				return game:HttpGet(statusUrl)
			end)

			if success and response then
				local data = nil
				pcall(function()
					data = HttpService:JSONDecode(response)
				end)

				if data and data.success then
					if data.status == "maintenance" or data.status == "offline" or data.status == "updating" then
						-- Status changed to maintenance/offline/updating - close UI

						-- Try to close the main UI
						pcall(function()
							if getgenv().StarshipWindow then
								getgenv().StarshipWindow:destroy()
							end
						end)
						pcall(function()
							if getgenv().StarshipWindUI then
								getgenv().StarshipWindUI:Destroy()
							end
						end)
						pcall(function()
							local CoreGui = game:GetService("CoreGui")
							local ui = CoreGui:FindFirstChild("Starship")
							if ui then
								ui:Destroy()
							end
						end)

						-- Show maintenance message
						showMaintenanceUI(data)

						-- Clear session
						getgenv().StarshipSession = nil

						break -- Stop monitoring
					end
				end
			end
		end
	end)
end

main()
