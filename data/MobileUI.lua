--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║                  STARSHIP MOBILE                              ║
    ║                  Powered by WindUI                            ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local VERSION = "1.0.0-mobile"
local CLOUD_API_BASE = _G.StarshipServerURL or "https://starship-core.my.id"

-- ══════════════════════════════════════════════════════════════════
-- LOAD WINDUI
-- ══════════════════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ══════════════════════════════════════════════════════════════════
-- ══════════════════════════════════════════════════════════════════
-- CONFIGURATION MANAGEMENT
-- ══════════════════════════════════════════════════════════════════
local ConfigFile = "StarshipMobile/Settings.json"
local Settings = {
	AutoAntiAFK = false,
	RememberPosition = false,
	ShowNotifications = true,
	Theme = "Midnight",
}

local ConfigStatus = "Default"

local function LoadSettings()
	-- Check if file functions exist
	if not isfolder then
		ConfigStatus = "No File API"
		return
	end

	if not isfolder("StarshipMobile") then
		pcall(function()
			makefolder("StarshipMobile")
		end)
	end

	if not isfile then
		ConfigStatus = "No isfile"
		return
	end

	if not isfile(ConfigFile) then
		ConfigStatus = "New Config"
		return
	end

	-- File exists, try to read
	local success, err = pcall(function()
		local rawContent = readfile(ConfigFile)
		local data = game:GetService("HttpService"):JSONDecode(rawContent)
		for k, v in pairs(data) do
			Settings[k] = v
		end
	end)

	if success then
		ConfigStatus = "Loaded"
	else
		ConfigStatus = "Error"
	end
end

local function SaveSettings()
	if not writefile then
		return false
	end

	if isfolder and not isfolder("StarshipMobile") then
		pcall(function()
			makefolder("StarshipMobile")
		end)
	end

	local success = pcall(function()
		local jsonData = game:GetService("HttpService"):JSONEncode(Settings)
		writefile(ConfigFile, jsonData)
	end)

	return success
end

LoadSettings()

-- PATCH WINDUI NOTIFY TO RESPECT SETTINGS
local OriginalNotify = WindUI.Notify
WindUI.Notify = function(self, args)
	-- Suppress notifications during settings sync
	if getgenv().isSyncingSettings then
		return
	end

	-- Filter out annoying startup notifications causing FPS drop
	if type(args) == "table" then
		if args.Title == "Theme" and string.find(tostring(args.Content), "Theme changed") then
			return
		end
		if args.Title == "Position" and string.find(tostring(args.Content), "Position won't be saved") then
			return
		end
		if args.Title == "Error" and string.find(tostring(args.Content), "Recording not found in cache") then
			return
		end
	end

	if Settings.ShowNotifications then
		OriginalNotify(self, args)
	end
end

-- CREATE WINDOW
-- ══════════════════════════════════════════════════════════════════
local Window = WindUI:CreateWindow({
	Title = "STARSHIP PREMIUM",
	Author = "By StarshipCore Team",
	Size = UDim2.fromOffset(360, 520),
	Transparent = true,
	Theme = Settings.Theme,
	SideBarWidth = 170,
	User = {
		Enabled = true,
		Anonymous = true, -- Set to true to hide real username
		Callback = function()
			-- Optional: callback when profile is clicked
			WindUI:Notify({
				Title = "Profile",
				Content = "Welcome, " .. Players.LocalPlayer.DisplayName .. "!",
				Duration = 3,
			})
			WindUI:Notify({
				Title = "Config Status",
				Content = ConfigStatus,
				Duration = 4,
			})
		end,
	},
	Topbar = {
		Height = 44,
		ButtonsType = "Default", -- "Default" or "Mac" style buttons (minimize, close)
	},
	OpenButton = {
		Title = "STARSHIP-CORE",
		Icon = "rbxassetid://91946746369709",
		CornerRadius = UDim.new(1, 0), -- Fully rounded
		StrokeThickness = 2,
		Enabled = true,
		Draggable = true, -- Bisa di-drag ke posisi yang diinginkan
		OnlyMobile = false, -- Muncul di PC dan Mobile
		Color = ColorSequence.new(
			Color3.fromHex("#6366f1"), -- Indigo
			Color3.fromHex("#8b5cf6") -- Purple gradient
		),
	},
})

-- Store Window reference globally for ban system
getgenv().StarshipWindow = Window
getgenv().StarshipWindUI = WindUI

-- ══════════════════════════════════════════════════════════════════
-- FPS, PING & ROLE TAGS (Top bar display)
-- ══════════════════════════════════════════════════════════════════

-- Get session data from StarshipSession (set by main loader)
local function GetSessionData()
	local session = getgenv().StarshipSession or {}
	return {
		Role = session.Role or "VIP",
		Duration = session.Duration or "LIFETIME",
		Expiry = session.Expiry,
	}
end

local sessionData = GetSessionData()

-- Role Tag (VIP/OWNER)
local roleColor = "#a855f7" -- Purple default
if sessionData.Role == "OWNER" then
	roleColor = "#f59e0b" -- Orange/Gold for OWNER
elseif sessionData.Role == "VIP" then
	roleColor = "#a855f7" -- Purple for VIP
end

local RoleTag = Window:Tag({
	Title = '<font size="11">' .. sessionData.Role .. "</font>",
	Color = Color3.fromHex(roleColor),
})

local FPSTag = Window:Tag({
	Title = '<font size="11">FPS: 0</font>',
	Icon = "monitor",
	Color = Color3.fromHex("#22c55e"),
})

local PingTag = Window:Tag({
	Title = '<font size="11">PING: 0ms</font>',
	Icon = "wifi",
	Color = Color3.fromHex("#3b82f6"),
})

-- Live update FPS & PING
task.spawn(function()
	local frameCount = 0
	local lastTime = tick()

	RunService.Heartbeat:Connect(function()
		frameCount = frameCount + 1

		local now = tick()
		if now - lastTime >= 1 then
			-- Update FPS
			local fps = math.floor(frameCount / (now - lastTime))
			local fpsColor = "#22c55e" -- Green
			if fps < 30 then
				fpsColor = "#ef4444" -- Red
			elseif fps < 50 then
				fpsColor = "#eab308" -- Yellow
			end

			pcall(function()
				FPSTag:SetTitle('<font size="11">FPS: ' .. fps .. "</font>")
				FPSTag:SetColor(Color3.fromHex(fpsColor))
			end)

			-- Update Ping
			local ping = 0
			pcall(function()
				ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
			end)

			local pingColor = "#3b82f6" -- Blue
			if ping > 150 then
				pingColor = "#ef4444" -- Red
			elseif ping > 80 then
				pingColor = "#eab308" -- Yellow
			end

			pcall(function()
				PingTag:SetTitle('<font size="11">PING: ' .. ping .. "ms</font>")
				PingTag:SetColor(Color3.fromHex(pingColor))
			end)

			frameCount = 0
			lastTime = now
		end
	end)
end)

-- ══════════════════════════════════════════════════════════════════
-- VARIABLES
-- ══════════════════════════════════════════════════════════════════
local Connections = {}
local Config = {
	WalkSpeed = 16,
	JumpPower = 50,
	FlySpeed = 50,
}

-- ══════════════════════════════════════════════════════════════════
-- PERIODIC BAN CHECK SYSTEM (Every 5 minutes)
-- Checks both IP ban and Google Sheets ban status
-- ══════════════════════════════════════════════════════════════════
local CLOUD_API_BASE = _G.StarshipServerURL or "https://starship-core.my.id"
local BAN_CHECK_INTERVAL = 5 * 60 -- 5 minutes in seconds
local BAN_CHECK_API = (CLOUD_API_BASE or "https://starship-core.my.id") .. "/api/m-auth-k5r9z7"
local isBanCheckRunning = false

local function ShowBannedMessage(reason)
	-- FIRST: Try to destroy using local Window variable
	pcall(function()
		if Window then
			-- Try multiple methods
			if Window.Destroy then
				Window:Destroy()
			end
			if Window.Toggle then
				Window:Toggle(false)
			end
			if Window.Hide then
				Window:Hide()
			end
		end
	end)

	-- SECOND: Try global references
	pcall(function()
		if getgenv().StarshipWindow then
			local w = getgenv().StarshipWindow
			if w.Destroy then
				w:Destroy()
			end
			if w.Toggle then
				w:Toggle(false)
			end
			if w.Hide then
				w:Hide()
			end
		end
	end)

	-- THIRD: Destroy WindUI library itself
	pcall(function()
		if WindUI then
			if WindUI.Destroy then
				WindUI:Destroy()
			end
		end
		if getgenv().StarshipWindUI then
			local ui = getgenv().StarshipWindUI
			if ui.Destroy then
				ui:Destroy()
			end
		end
	end)

	-- THIRD: Force destroy all ScreenGuis in CoreGui
	pcall(function()
		for _, gui in pairs(game:GetService("CoreGui"):GetChildren()) do
			if gui:IsA("ScreenGui") then
				local name = gui.Name:lower()
				-- Only keep essential Roblox GUIs
				if
					not (
						name == "robloxpromptgui"
						or name == "chatgui"
						or name == "topbargui"
						or name == "notificationbingui"
						or name == "purchasepromptapp"
					)
				then
					pcall(function()
						gui:Destroy()
					end)
				end
			end
		end
	end)

	-- FOURTH: Destroy all in PlayerGui
	pcall(function()
		for _, gui in pairs(LocalPlayer:WaitForChild("PlayerGui"):GetChildren()) do
			if gui:IsA("ScreenGui") then
				pcall(function()
					gui:Destroy()
				end)
			end
		end
	end)

	-- Clear global references
	pcall(function()
		getgenv().StarshipSession = nil
		getgenv().StarshipModules = nil
		getgenv().StarshipModules = nil
	end)

	-- Create ban notification screen (PERSISTENT - doesn't auto-close quickly)
	local banGui = Instance.new("ScreenGui")
	banGui.Name = "StarshipBanned"
	banGui.ResetOnSpawn = false
	banGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	banGui.IgnoreGuiInset = true
	banGui.DisplayOrder = 999999 -- Make it on top of everything

	pcall(function()
		banGui.Parent = game:GetService("CoreGui")
	end)
	if not banGui.Parent then
		banGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	local bg = Instance.new("Frame", banGui)
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	bg.BackgroundTransparency = 0 -- Fully opaque to block everything
	bg.BorderSizePixel = 0

	local container = Instance.new("Frame", bg)
	container.Size = UDim2.new(0, 340, 0, 200)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	container.BorderSizePixel = 0
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 16)

	local stroke = Instance.new("UIStroke", container)
	stroke.Color = Color3.fromRGB(239, 68, 68)
	stroke.Thickness = 2

	local icon = Instance.new("TextLabel", container)
	icon.Size = UDim2.new(1, 0, 0, 50)
	icon.Position = UDim2.new(0.5, 0, 0, 25)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "🚫"
	icon.TextSize = 40
	icon.Font = Enum.Font.GothamBold

	local title = Instance.new("TextLabel", container)
	title.Size = UDim2.new(1, -40, 0, 30)
	title.Position = UDim2.new(0.5, 0, 0, 80)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.BackgroundTransparency = 1
	title.Text = "ACCESS REVOKED"
	title.TextColor3 = Color3.fromRGB(239, 68, 68)
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold

	local msg = Instance.new("TextLabel", container)
	msg.Size = UDim2.new(1, -40, 0, 60)
	msg.Position = UDim2.new(0.5, 0, 0, 115)
	msg.AnchorPoint = Vector2.new(0.5, 0)
	msg.BackgroundTransparency = 1
	msg.Text = reason or "Your access has been revoked.\n\nPlease contact administrator."
	msg.TextColor3 = Color3.fromRGB(161, 161, 170)
	msg.TextSize = 14
	msg.Font = Enum.Font.Gotham
	msg.TextWrapped = true

	-- Keep the ban screen longer (30 seconds)
	task.delay(30, function()
		if banGui and banGui.Parent then
			banGui:Destroy()
		end
	end)

	-- IMPORTANT: Return error to break the script execution
	error("[StarshipCore] Access revoked - Script terminated")
end

local function CheckBanStatus()
	if isBanCheckRunning then
		return
	end
	isBanCheckRunning = true

	local userId = tostring(LocalPlayer.UserId)
	local checkUrl = BAN_CHECK_API .. "?userId=" .. userId .. "&action=check"

	local success, response = pcall(function()
		return game:HttpGet(checkUrl)
	end)

	isBanCheckRunning = false

	if not success then
		warn("[StarshipCore] Ban check failed: Connection error")
		return
	end

	-- Try to parse JSON response
	local data = nil
	pcall(function()
		data = game:GetService("HttpService"):JSONDecode(response)
	end)

	-- Check if banned
	if data then
		if data.isBanned then
			warn("[StarshipCore] User is BANNED - Terminating script")
			ShowBannedMessage("You have been banned.\nReason: " .. (data.banReason or "Violation of terms"))
			return true -- Return banned status
		end

		if data.status == "denied" then
			warn("[StarshipCore] Access DENIED - " .. (data.message or "Unknown reason"))
			ShowBannedMessage(data.message or "Your access has been revoked.")
			return true
		end
	end

	-- Check if response contains error indicating ban
	if response:find("banned") or response:find("BANNED") then
		ShowBannedMessage("Your account has been banned.")
		return true
	end

	return false -- Not banned
end

-- Start periodic ban check loop
task.spawn(function()
	-- Wait a bit before first check (let UI load first)
	task.wait(30)

	while true do
		local isBanned = CheckBanStatus()
		if isBanned then
			-- Stop the loop if banned
			break
		end

		-- Wait 5 minutes before next check
		task.wait(BAN_CHECK_INTERVAL)
	end
end)

print("[StarshipCore] 🔒 Periodic ban check enabled (every 5 minutes)")

-- Cloud recording storage (in memory for mobile) - declared early for PlayRecording access
local CloudRecordingData = nil
local CloudRecordingName = nil
local CloudRecordingsCache = {} -- Cache: displayName -> {name, recordingId}
local CloudDropdownValues = {}

-- Chunked Loading State (for streaming large recordings)
local ChunkedState = {
	isChunked = false, -- Whether current recording uses chunked loading
	recordingId = nil, -- Current recording ID for chunk fetching
	totalChunks = 0, -- Total number of chunks
	loadedChunks = {}, -- Cached chunk data: [chunkIndex] = {frames}
	currentLoadingChunk = -1, -- Chunk currently being loaded (-1 = none)
	framesPerChunk = 3000, -- Frames per chunk (from server)
	totalFrames = 0, -- Total frame count
	isPreloading = false, -- Whether preloading is in progress
	loadProgress = 0, -- Loading progress (0-100)
}

-- ══════════════════════════════════════════════════════════════════
-- CLOUD API SECURITY - Event Code required for R2 access
-- ══════════════════════════════════════════════════════════════════
local CLOUD_API_ENDPOINTS = {
	main = "/api/cloud-store-x7k9", -- Main recordings endpoint (renamed from r2-recordings)
	chunked = "/api/cloud-chunk-m3p7", -- Chunked streaming endpoint (renamed from r2-chunked)
}
local CLOUD_EVENT_CODE = _G.StarshipEventCode or "" -- Event code set by loader or entered by user

-- Helper function to build cloud API URL with event code and userId
-- @param params: table of query parameters
-- @param useChunked: boolean - if true, use chunked endpoint instead of main
local function BuildCloudURL(params, useChunked)
	local endpoint = useChunked and CLOUD_API_ENDPOINTS.chunked or CLOUD_API_ENDPOINTS.main
	local url = CLOUD_API_BASE .. endpoint
	local queryParts = {}

	-- Add event code first (required for R2 access)
	if CLOUD_EVENT_CODE and CLOUD_EVENT_CODE ~= "" then
		table.insert(queryParts, "eventCode=" .. CLOUD_EVENT_CODE)
	end

	-- Always add userId for server-side validation and blacklist check
	table.insert(queryParts, "userId=" .. tostring(LocalPlayer.UserId))

	-- Add other params
	if params then
		for key, value in pairs(params) do
			-- Skip userId if already in params (avoid duplicate)
			if key ~= "userId" then
				table.insert(queryParts, key .. "=" .. tostring(value))
			end
		end
	end

	if #queryParts > 0 then
		url = url .. "?" .. table.concat(queryParts, "&")
	end

	return url
end

-- Forward declarations for chunked loading functions (defined later in file)
local PreloadNextChunks

-- ══════════════════════════════════════════════════════════════════
-- LOCAL CACHE SYSTEM FOR CLOUD RECORDINGS
-- ══════════════════════════════════════════════════════════════════
local CACHE_FOLDER = "StarshipCache"
local CLOUD_CACHE_FOLDER = CACHE_FOLDER .. "/CloudRecordings"

-- Initialize cache folders
local function InitCacheFolders()
	pcall(function()
		if isfolder and makefolder then
			if not isfolder(CACHE_FOLDER) then
				makefolder(CACHE_FOLDER)
			end
			if not isfolder(CLOUD_CACHE_FOLDER) then
				makefolder(CLOUD_CACHE_FOLDER)
			end
		end
	end)
end

-- Check if a recording is cached locally
local function IsRecordingCached(recordingId)
	if not isfile then
		return false
	end
	local cachePath = CLOUD_CACHE_FOLDER .. "/" .. recordingId .. ".json"
	return isfile(cachePath)
end

-- Load recording from local cache (returns data or nil)
local function LoadFromCache(recordingId)
	if not isfile or not readfile then
		return nil
	end

	local cachePath = CLOUD_CACHE_FOLDER .. "/" .. recordingId .. ".json"
	if not isfile(cachePath) then
		return nil
	end

	local success, content = pcall(readfile, cachePath)
	if not success or not content then
		return nil
	end

	local parseSuccess, data = pcall(function()
		return HttpService:JSONDecode(content)
	end)

	if parseSuccess and data then
		return data
	end
	return nil
end

-- Save recording to local cache
local function SaveToCache(recordingId, recordingData)
	if not writefile then
		return false
	end

	InitCacheFolders()

	local cachePath = CLOUD_CACHE_FOLDER .. "/" .. recordingId .. ".json"

	local success = pcall(function()
		local jsonData = HttpService:JSONEncode(recordingData)
		writefile(cachePath, jsonData)
	end)

	if success then
		print("[Cache] Saved recording to cache: " .. recordingId)
	end

	return success
end

-- Get cache size info
local function GetCacheInfo()
	if not isfolder or not listfiles then
		return { count = 0, size = 0 }
	end

	if not isfolder(CLOUD_CACHE_FOLDER) then
		return { count = 0, size = 0 }
	end

	local files = listfiles(CLOUD_CACHE_FOLDER)
	local count = 0
	local totalSize = 0

	for _, filePath in ipairs(files) do
		if string.sub(filePath, -5) == ".json" then
			count = count + 1
			-- Estimate size (can't get actual file size in most executors)
		end
	end

	return { count = count }
end

-- Clear all cached recordings
local function ClearCache()
	if not isfolder or not listfiles or not delfile then
		return false
	end

	if not isfolder(CLOUD_CACHE_FOLDER) then
		return true
	end

	local files = listfiles(CLOUD_CACHE_FOLDER)
	for _, filePath in ipairs(files) do
		pcall(delfile, filePath)
	end

	print("[Cache] Cache cleared")
	return true
end

-- Initialize cache on startup
InitCacheFolders()

-- ══════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ══════════════════════════════════════════════════════════════════
local function GetCharacter()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function GetHumanoid()
	local char = GetCharacter()
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetHRP()
	local char = GetCharacter()
	return char and char:FindFirstChild("HumanoidRootPart")
end

-- ══════════════════════════════════════════════════════════════════
-- CARRY PRESERVATION (Always ON for mobile)
-- ══════════════════════════════════════════════════════════════════
_G.StarshipForceCarryMode = true -- Always enabled for mobile
_G.StarshipCarryNotified = nil
_G.StarshipCarryNotifiedStd = nil

-- ══════════════════════════════════════════════════════════════════
-- 🏠 DASHBOARD TAB
-- ══════════════════════════════════════════════════════════════════
local DashboardTab = Window:Tab({
	Title = "Dashboard",
	Icon = "layout-dashboard",
})

local AccountTab = Window:Tab({
	Title = "Account",
	Icon = "user",
})

local ServerTab = Window:Tab({
	Title = "Server",
	Icon = "globe",
})

local CustomAnimTab = Window:Tab({
	Title = "Animations",
	Icon = "person-standing",
})

-- ══════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS FOR DASHBOARD
-- ══════════════════════════════════════════════════════════════════
local function GetGreeting()
	local hour = tonumber(os.date("%H"))
	if hour >= 5 and hour < 12 then
		return "☀️ Good Morning"
	elseif hour >= 12 and hour < 17 then
		return "🌤️ Good Afternoon"
	elseif hour >= 17 and hour < 21 then
		return "🌆 Good Evening"
	else
		return "🌙 Good Night"
	end
end

local function GetExecutorInfo()
	local name, version = "Unknown", "?"
	pcall(function()
		if identifyexecutor then
			name, version = identifyexecutor()
		elseif getexecutorname then
			name = getexecutorname()
		end
	end)
	return name or "Unknown", version or "?"
end

local function GetPing()
	local ping = 0
	pcall(function()
		ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
	end)
	return ping
end

local function GetFPS()
	return math.floor(workspace:GetRealPhysicsFPS())
end

local function GetServerAge()
	local age = workspace.DistributedGameTime
	local hours = math.floor(age / 3600)
	local mins = math.floor((age % 3600) / 60)
	return string.format("%dh %dm", hours, mins)
end

local function GetGameName()
	local name = "Unknown Game"
	pcall(function()
		local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		if info and info.Name then
			name = info.Name
		end
	end)
	return name
end

local function UpdateTool(char, toolName)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end

	local currentTool = char:FindFirstChildOfClass("Tool")

	if toolName then
		if currentTool and currentTool.Name == toolName then
			return
		end
		if currentTool then
			hum:UnequipTools()
		end

		local backpack = LocalPlayer.Backpack
		local newTool = backpack:FindFirstChild(toolName)
		if newTool then
			hum:EquipTool(newTool)
		end
	else
		if currentTool then
			hum:UnequipTools()
		end
	end
end

-- ══════════════════════════════════════════════════════════════════
-- WELCOME SECTION
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Paragraph({
	Title = GetGreeting() .. ", " .. LocalPlayer.DisplayName .. "!",
	Desc = "Welcome to Starship Mobile • Version " .. VERSION,
})

-- ══════════════════════════════════════════════════════════════════
-- VIP STATUS
-- ══════════════════════════════════════════════════════════════════
AccountTab:Section({ Title = "💎 VIP Status", TextSize = 16 })
AccountTab:Divider()

local vipStatusDesc = '<font size="16">👑 Role: '
	.. sessionData.Role
	.. "\n"
	.. "⏰ Duration: "
	.. sessionData.Duration
	.. "\n"
	.. "✅ Status: Active</font>"

AccountTab:Paragraph({
	Title = "🎫 Your Subscription",
	Desc = vipStatusDesc,
})

-- ══════════════════════════════════════════════════════════════════
-- GAME DETECTION
-- ══════════════════════════════════════════════════════════════════
ServerTab:Section({ Title = "🎮 Current Game", TextSize = 16 })
ServerTab:Divider()

local gameName = GetGameName()
ServerTab:Paragraph({
	Title = "📍 " .. gameName,
	Desc = "Place ID: " .. game.PlaceId,
})

-- ══════════════════════════════════════════════════════════════════
-- ACCOUNT INFORMATION
-- ══════════════════════════════════════════════════════════════════
AccountTab:Section({ Title = "👤 Your Account", TextSize = 16 })
AccountTab:Divider()

local accountDesc = '<font size="16">🏷️ Display Name: '
	.. LocalPlayer.DisplayName
	.. "\n"
	.. "👤 Username: "
	.. LocalPlayer.Name
	.. "\n"
	.. "🆔 User ID: "
	.. LocalPlayer.UserId
	.. "\n"
	.. "📅 Account Age: "
	.. LocalPlayer.AccountAge
	.. " days\n"
	.. "⭐ Status: Premium Member</font>"

local AccountCard = AccountTab:Paragraph({
	Title = "🎭 Profile Info",
	Desc = accountDesc,
})

-- ══════════════════════════════════════════════════════════════════
-- SERVER INFORMATION
-- ══════════════════════════════════════════════════════════════════
ServerTab:Section({ Title = "🌐 Server Details", TextSize = 16 })
ServerTab:Divider()

ServerTab:Button({
	Title = "📋 Copy Job ID",
	Desc = "Copy server Job ID to clipboard",
	Callback = function()
		if setclipboard then
			setclipboard(game.JobId)
			WindUI:Notify({ Title = "Copied!", Content = "Job ID copied to clipboard", Duration = 2 })
		else
			WindUI:Notify({ Title = "Error", Content = "Clipboard not available", Duration = 2 })
		end
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- FRIENDS IN SERVER
-- ══════════════════════════════════════════════════════════════════
AccountTab:Section({ Title = "👥 Friends in Server", TextSize = 16 })
AccountTab:Divider()

local function GetFriendsInServer()
	local friends = {}
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local success, isFriend = pcall(function()
				return LocalPlayer:IsFriendsWith(player.UserId)
			end)
			if success and isFriend then
				table.insert(friends, player.DisplayName .. " (@" .. player.Name .. ")")
			end
		end
	end
	if #friends == 0 then
		return '<font size="16">No friends in this server</font>'
	end
	return '<font size="16">' .. table.concat(friends, "\n") .. "</font>"
end

local FriendsCard = AccountTab:Paragraph({
	Title = "🤝 Friends Here",
	Desc = GetFriendsInServer(),
})

-- ══════════════════════════════════════════════════════════════════
-- QUICK ACTIONS
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Section({ Title = "⚡ Quick Actions", TextSize = 16 })

DashboardTab:Divider()

DashboardTab:Button({
	Title = "🔄 Refresh Dashboard",
	Desc = "Update all statistics",
	Callback = function()
		-- Update Live Stats
		local newExecName, newExecVersion = GetExecutorInfo()
		local newStatsDesc = "⚡ Executor: "
			.. newExecName
			.. " ("
			.. newExecVersion
			.. ")\n"
			.. "👥 Players: "
			.. #Players:GetPlayers()
			.. "/"
			.. Players.MaxPlayers
			.. "\n"
			.. "📶 Ping: "
			.. GetPing()
			.. " ms\n"
			.. "🖥️ FPS: "
			.. GetFPS()
			.. "\n"
			.. "⏱️ Server Age: "
			.. GetServerAge()
		LiveStatsCard:SetDesc(newStatsDesc)

		-- Update Server Card
		local newServerDesc = "👥 Players: "
			.. #Players:GetPlayers()
			.. " / "
			.. Players.MaxPlayers
			.. "\n"
			.. "⏱️ Uptime: "
			.. GetServerAge()
			.. "\n"
			.. "📶 Ping: "
			.. GetPing()
			.. " ms\n"
			.. "🖥️ FPS: "
			.. GetFPS()
		ServerCard:SetDesc(newServerDesc)

		-- Update Friends
		FriendsCard:SetDesc(GetFriendsInServer())

		WindUI:Notify({ Title = "✅ Refreshed", Content = "Dashboard updated!", Duration = 2 })
	end,
})

DashboardTab:Button({
	Title = "💬 Copy Discord Invite",
	Desc = "Get Starship Discord link",
	Callback = function()
		if setclipboard then
			setclipboard("https://discord.gg/BUJuXA8Z")
			WindUI:Notify({ Title = "Copied!", Content = "Discord link copied!", Duration = 2 })
		end
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- SERVER ACTIONS (Moved to ServerTab)
-- ══════════════════════════════════════════════════════════════════
ServerTab:Section({ Title = "⚡ Server Actions", TextSize = 16 })
ServerTab:Divider()
ServerTab:Button({
	Title = "🔗 Rejoin Server",
	Desc = "Rejoin the current server",
	Callback = function()
		WindUI:Notify({ Title = "Rejoining...", Content = "Teleporting to server...", Duration = 2 })
		task.delay(1, function()
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId)
		end)
	end,
})

ServerTab:Button({
	Title = "🌍 Server Hop",
	Desc = "Join a different server",
	Callback = function()
		WindUI:Notify({ Title = "Server Hop", Content = "Finding new server...", Duration = 2 })
		task.delay(1, function()
			pcall(function()
				local servers = game:GetService("HttpService"):JSONDecode(
					game:HttpGet(
						"https://games.roblox.com/v1/games/"
							.. game.PlaceId
							.. "/servers/Public?sortOrder=Asc&limit=100"
					)
				)
				for _, server in pairs(servers.data) do
					if server.id ~= game.JobId and server.playing < server.maxPlayers then
						game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, server.id)
						return
					end
				end
				WindUI:Notify({ Title = "Error", Content = "No available servers found", Duration = 2 })
			end)
		end)
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- CUSTOM ANIMATIONS
-- ══════════════════════════════════════════════════════════════════
local HttpService = game:GetService("HttpService")

-- Load AnimDB from global (set by Loader) or module, or use fallback
local AnimDB = nil

-- Try to load from _G.StarshipAnimDB (set by Loader.lua)
if _G.StarshipAnimDB then
	AnimDB = _G.StarshipAnimDB
	-- Try to load from getgenv().StarshipModules (production Loader)
elseif getgenv and getgenv().StarshipModules and getgenv().StarshipModules["Animations.lua"] then
	AnimDB = getgenv().StarshipModules["Animations.lua"]
	-- Try to load from file (dev mode)
elseif isfile and isfile("StarshipCore/Modules/Animations.lua") then
	local success, result = pcall(function()
		return loadstring(readfile("StarshipCore/Modules/Animations.lua"))()
	end)
	if success and result then
		AnimDB = result
	end
end

-- Fallback to hardcoded AnimDB if nothing loaded
if not AnimDB or not next(AnimDB) then
	AnimDB = {
		["Idle"] = {
			["2016 Animation (mm2)"] = { "387947158", "387947464" },
			["(UGC) Oh Really?"] = { "98004748982532", "98004748982532" },
			["Astronaut"] = { "891621366", "891633237" },
			["Adidas Community"] = { "122257458498464", "102357151005774" },
			["Bold"] = { "16738333868", "16738334710" },
			["(UGC) Slasher"] = { "140051337061095", "140051337061095" },
			["(UGC) Retro"] = { "80479383912838", "80479383912838" },
			["(UGC) Magician"] = { "139433213852503", "139433213852503" },
			["(UGC) John Doe"] = { "72526127498800", "72526127498800" },
			["(UGC) Noli"] = { "139360856809483", "139360856809483" },
			["(UGC) Coolkid"] = { "95203125292023", "95203125292023" },
			["(UGC) Survivor Injured"] = { "73905365652295", "73905365652295" },
			["(UGC) Retro Zombie"] = { "90806086002292", "90806086002292" },
			["(UGC) 1x1x1x1"] = { "76780522821306", "76780522821306" },
			["Borock"] = { "3293641938", "3293642554" },
			["Bubbly"] = { "910004836", "910009958" },
			["Cartoony"] = { "742637544", "742638445" },
			["Confident"] = { "1069977950", "1069987858" },
			["Catwalk Glam"] = { "133806214992291", "94970088341563" },
			["Cowboy"] = { "1014390418", "1014398616" },
			["Drooling Zombie"] = { "3489171152", "3489171152" },
			["Elder"] = { "10921101664", "10921102574" },
			["Ghost"] = { "616006778", "616008087" },
			["Knight"] = { "657595757", "657568135" },
			["Levitation"] = { "616006778", "616008087" },
			["Mage"] = { "707742142", "707855907" },
			["MrToilet"] = { "4417977954", "4417978624" },
			["Ninja"] = { "656117400", "656118341" },
			["NFL"] = { "92080889861410", "74451233229259" },
			["OldSchool"] = { "10921230744", "10921232093" },
			["Patrol"] = { "1149612882", "1150842221" },
			["Pirate"] = { "750781874", "750782770" },
			["Default Retarget"] = { "95884606664820", "95884606664820" },
			["Very Long"] = { "18307781743", "18307781743" },
			["Sway"] = { "560832030", "560833564" },
			["Popstar"] = { "1212900985", "1150842221" },
			["Princess"] = { "941003647", "941013098" },
			["R6"] = { "12521158637", "12521162526" },
			["R15 Reanimated"] = { "4211217646", "4211218409" },
			["Realistic"] = { "17172918855", "17173014241" },
			["Robot"] = { "616088211", "616089559" },
			["Sneaky"] = { "1132473842", "1132477671" },
			["Sports (Adidas)"] = { "18537376492", "18537371272" },
			["Soldier"] = { "3972151362", "3972151362" },
			["Stylish"] = { "616136790", "616138447" },
			["Stylized Female"] = { "4708191566", "4708192150" },
			["Superhero"] = { "10921288909", "10921290167" },
			["Toy"] = { "782841498", "782845736" },
			["Udzal"] = { "3303162274", "3303162549" },
			["Vampire"] = { "1083445855", "1083450166" },
			["Werewolf"] = { "1083195517", "1083214717" },
			["Wicked (Popular)"] = { "118832222982049", "76049494037641" },
			["No Boundaries (Walmart)"] = { "18747067405", "18747063918" },
			["Zombie"] = { "616158929", "616160636" },
			["(UGC) Zombie"] = { "77672872857991", "77672872857991" },
			["(UGC) TailWag"] = { "129026910898635", "129026910898635" },
		},
		["Walk"] = {
			["Gojo"] = "95643163365384",
			["Geto"] = "85811471336028",
			["Astronaut"] = "891667138",
			["(UGC) Zombie"] = "113603435314095",
			["Adidas Community"] = "122150855457006",
			["Bold"] = "16738340646",
			["Bubbly"] = "910034870",
			["(UGC) Smooth"] = "76630051272791",
			["Cartoony"] = "742640026",
			["Confident"] = "1070017263",
			["Cowboy"] = "1014421541",
			["(UGC) Retro"] = "107806791584829",
			["(UGC) Retro Zombie"] = "140703855480494",
			["Catwalk Glam"] = "109168724482748",
			["Drooling Zombie"] = "3489174223",
			["Elder"] = "10921111375",
			["Ghost"] = "616013216",
			["Knight"] = "10921127095",
			["Levitation"] = "616013216",
			["Mage"] = "707897309",
			["Ninja"] = "656121766",
			["NFL"] = "110358958299415",
			["OldSchool"] = "10921244891",
			["Patrol"] = "1151231493",
			["Pirate"] = "750785693",
			["Default Retarget"] = "115825677624788",
			["Popstar"] = "1212980338",
			["Princess"] = "941028902",
			["R6"] = "12518152696",
			["R15 Reanimated"] = "4211223236",
			["2016 Animation (mm2)"] = "387947975",
			["Robot"] = "616095330",
			["Sneaky"] = "1132510133",
			["Sports (Adidas)"] = "18537392113",
			["Stylish"] = "616146177",
			["Stylized Female"] = "4708193840",
			["Superhero"] = "10921298616",
			["Toy"] = "782843345",
			["Udzal"] = "3303162967",
			["Vampire"] = "1083473930",
			["Werewolf"] = "1083178339",
			["Wicked (Popular)"] = "92072849924640",
			["No Boundaries (Walmart)"] = "18747074203",
			["Zombie"] = "616168032",
		},
		["Run"] = {
			["2016 Animation (mm2)"] = "387947975",
			["(UGC) Soccer"] = "116881956670910",
			["Adidas Community"] = "82598234841035",
			["Astronaut"] = "10921039308",
			["Bold"] = "16738337225",
			["Bubbly"] = "10921057244",
			["Cartoony"] = "10921076136",
			["(UGC) Dog"] = "130072963359721",
			["Confident"] = "1070001516",
			["(UGC) Pride"] = "116462200642360",
			["(UGC) Retro"] = "107806791584829",
			["(UGC) Retro Zombie"] = "140703855480494",
			["Cowboy"] = "1014401683",
			["Catwalk Glam"] = "81024476153754",
			["Drooling Zombie"] = "3489173414",
			["Elder"] = "10921104374",
			["Ghost"] = "616013216",
			["Heavy Run (Udzal / Borock)"] = "3236836670",
			["Knight"] = "10921121197",
			["Levitation"] = "616010382",
			["Mage"] = "10921148209",
			["MrToilet"] = "4417979645",
			["Ninja"] = "656118852",
			["NFL"] = "117333533048078",
			["OldSchool"] = "10921240218",
			["Patrol"] = "1150967949",
			["Pirate"] = "750783738",
			["Default Retarget"] = "102294264237491",
			["Popstar"] = "1212980348",
			["Princess"] = "941015281",
			["R6"] = "12518152696",
			["R15 Reanimated"] = "4211220381",
			["Robot"] = "10921250460",
			["Sneaky"] = "1132494274",
			["Sports (Adidas)"] = "18537384940",
			["Stylish"] = "10921276116",
			["Stylized Female"] = "4708192705",
			["Superhero"] = "10921291831",
			["Toy"] = "10921306285",
			["Vampire"] = "10921320299",
			["Werewolf"] = "10921336997",
			["Wicked (Popular)"] = "72301599441680",
			["No Boundaries (Walmart)"] = "18747070484",
			["Zombie"] = "616163682",
		},
		["Jump"] = {
			["Astronaut"] = "891627522",
			["Adidas Community"] = "75290611992385",
			["Bold"] = "16738336650",
			["Bubbly"] = "910016857",
			["Cartoony"] = "742637942",
			["Catwalk Glam"] = "116936326516985",
			["Confident"] = "1069984524",
			["Cowboy"] = "1014394726",
			["Elder"] = "10921107367",
			["Ghost"] = "616008936",
			["Knight"] = "910016857",
			["Levitation"] = "616008936",
			["Mage"] = "10921149743",
			["Ninja"] = "656117878",
			["NFL"] = "119846112151352",
			["OldSchool"] = "10921242013",
			["Patrol"] = "1148811837",
			["Pirate"] = "750782230",
			["(UGC) Retro"] = "139390570947836",
			["Default Retarget"] = "117150377950987",
			["Popstar"] = "1212954642",
			["Princess"] = "941008832",
			["Robot"] = "616090535",
			["R15 Reanimated"] = "4211219390",
			["R6"] = "12520880485",
			["Sneaky"] = "1132489853",
			["Sports (Adidas)"] = "18537380791",
			["Stylish"] = "616139451",
			["Stylized Female"] = "4708188025",
			["Superhero"] = "10921294559",
			["Toy"] = "10921308158",
			["Vampire"] = "1083455352",
			["Werewolf"] = "1083218792",
			["Wicked (Popular)"] = "104325245285198",
			["No Boundaries (Walmart)"] = "18747069148",
			["Zombie"] = "616161997",
		},
		["Fall"] = {
			["Astronaut"] = "891617961",
			["Adidas Community"] = "98600215928904",
			["Bold"] = "16738333171",
			["Bubbly"] = "910001910",
			["Cartoony"] = "742637151",
			["Catwalk Glam"] = "92294537340807",
			["Confident"] = "1069973677",
			["Cowboy"] = "1014384571",
			["Elder"] = "10921105765",
			["Knight"] = "10921122579",
			["Levitation"] = "616005863",
			["Mage"] = "707829716",
			["Ninja"] = "656115606",
			["NFL"] = "129773241321032",
			["OldSchool"] = "10921241244",
			["Patrol"] = "1148863382",
			["Pirate"] = "750780242",
			["Default Retarget"] = "110205622518029",
			["Popstar"] = "1212900995",
			["Princess"] = "941000007",
			["Robot"] = "616087089",
			["R15 Reanimated"] = "4211216152",
			["R6"] = "12520972571",
			["Sneaky"] = "1132469004",
			["Sports (Adidas)"] = "18537367238",
			["Stylish"] = "616134815",
			["Stylized Female"] = "4708186162",
			["Superhero"] = "10921293373",
			["Toy"] = "782846423",
			["Vampire"] = "1083443587",
			["Werewolf"] = "1083189019",
			["Wicked (Popular)"] = "121152442762481",
			["No Boundaries (Walmart)"] = "18747062535",
			["Zombie"] = "616157476",
		},
		["SwimIdle"] = {
			["Astronaut"] = "891663592",
			["Adidas Community"] = "109346520324160",
			["Bold"] = "16738339817",
			["Bubbly"] = "910030921",
			["Cartoony"] = "10921079380",
			["Catwalk Glam"] = "98854111361360",
			["Confident"] = "1070012133",
			["CowBoy"] = "1014411816",
			["Elder"] = "10921110146",
			["Mage"] = "707894699",
			["Ninja"] = "656118341",
			["NFL"] = "79090109939093",
			["Patrol"] = "1151221899",
			["Knight"] = "10921125935",
			["OldSchool"] = "10921244018",
			["Levitation"] = "10921139478",
			["Popstar"] = "1212998578",
			["Princess"] = "941025398",
			["Pirate"] = "750785176",
			["R6"] = "12518152696",
			["Robot"] = "10921253767",
			["Sneaky"] = "1132506407",
			["Sports (Adidas)"] = "18537387180",
			["Stylish"] = "10921281964",
			["Stylized"] = "4708190607",
			["SuperHero"] = "10921297391",
			["Toy"] = "10921310341",
			["Vampire"] = "10921325443",
			["Werewolf"] = "10921341319",
			["Wicked (Popular)"] = "113199415118199",
			["No Boundaries (Walmart)"] = "18747071682",
		},
		["Swim"] = {
			["Astronaut"] = "891663592",
			["Adidas Community"] = "133308483266208",
			["Bubbly"] = "910028158",
			["Bold"] = "16738339158",
			["Cartoony"] = "10921079380",
			["Catwalk Glam"] = "134591743181628",
			["CowBoy"] = "1014406523",
			["Confident"] = "1070009914",
			["Elder"] = "10921108971",
			["Knight"] = "10921125160",
			["Mage"] = "707876443",
			["NFL"] = "132697394189921",
			["OldSchool"] = "10921243048",
			["PopStar"] = "1212998578",
			["Princess"] = "941018893",
			["Pirate"] = "750784579",
			["Patrol"] = "1151204998",
			["R6"] = "12518152696",
			["Robot"] = "10921253142",
			["Levitation"] = "10921138209",
			["Stylish"] = "10921281000",
			["SuperHero"] = "10921295495",
			["Sneaky"] = "1132500520",
			["Sports (Adidas)"] = "18537389531",
			["Toy"] = "10921309319",
			["Vampire"] = "10921324408",
			["Werewolf"] = "10921340419",
			["Wicked (Popular)"] = "99384245425157",
			["No Boundaries (Walmart)"] = "18747073181",
			["Zombie"] = "616165109",
		},
		["Climb"] = {
			["Astronaut"] = "10921032124",
			["Adidas Community"] = "88763136693023",
			["Bold"] = "16738332169",
			["Cartoony"] = "742636889",
			["Catwalk Glam"] = "119377220967554",
			["Confident"] = "1069946257",
			["CowBoy"] = "1014380606",
			["Elder"] = "845392038",
			["Ghost"] = "616003713",
			["Knight"] = "10921125160",
			["Levitation"] = "10921132092",
			["Mage"] = "707826056",
			["Ninja"] = "656114359",
			["(UGC) Retro"] = "121075390792786",
			["NFL"] = "134630013742019",
			["OldSchool"] = "10921229866",
			["Patrol"] = "1148811837",
			["Popstar"] = "1213044953",
			["Princess"] = "940996062",
			["R6"] = "12520982150",
			["Reanimated R15"] = "4211214992",
			["Robot"] = "616086039",
			["Sneaky"] = "1132461372",
			["Sports (Adidas)"] = "18537363391",
			["Stylish"] = "10921271391",
			["Stylized Female"] = "4708184253",
			["SuperHero"] = "10921286911",
			["Toy"] = "10921300839",
			["Vampire"] = "1083439238",
			["WereWolf"] = "10921329322",
			["Wicked (Popular)"] = "131326830509784",
			["No Boundaries (Walmart)"] = "18747060903",
			["Zombie"] = "616156119",
		},
	}
end -- End of fallback AnimDB

local CurrentAnimType = "Idle"
local AnimTypes = { "Idle", "Walk", "Run", "Jump", "Fall", "Swim", "SwimIdle", "Climb" }
local ANIM_FILE = "Starship_Animations.json"

-- Load saved animations
if isfile and isfile(ANIM_FILE) then
	pcall(function()
		local data = HttpService:JSONDecode(readfile(ANIM_FILE))
		for k, v in pairs(data) do
			if AnimDB[k] then
				for name, id in pairs(v) do
					AnimDB[k][name] = id
				end
			end
		end
	end)
end

local function SaveAnimDB()
	if writefile then
		writefile(ANIM_FILE, HttpService:JSONEncode(AnimDB))
	end
end

local OriginalAnims = {}
local function CaptureOriginalAnims()
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local animate = char:WaitForChild("Animate", 10)
	if not animate then
		return
	end

	local function getId(obj)
		return (obj and obj:IsA("Animation")) and obj.AnimationId or nil
	end

	if not OriginalAnims.Idle then
		OriginalAnims.Idle = {
			getId(animate:FindFirstChild("idle") and animate.idle:FindFirstChild("Animation1")),
			getId(animate:FindFirstChild("idle") and animate.idle:FindFirstChild("Animation2")),
		}
	end

	local types = {
		Walk = "WalkAnim",
		Run = "RunAnim",
		Jump = "JumpAnim",
		Fall = "FallAnim",
		Climb = "ClimbAnim",
		Swim = "Swim",
		SwimIdle = "SwimIdle",
	}

	for name, animName in pairs(types) do
		local childName = name:lower()
		if not OriginalAnims[name] then
			OriginalAnims[name] =
				getId(animate:FindFirstChild(childName) and animate[childName]:FindFirstChild(animName))
		end
	end
end
task.spawn(CaptureOriginalAnims)

local function SetAnimation(animType, animId)
	local char = LocalPlayer.Character
	local animate = char and char:FindFirstChild("Animate")
	if not animate then
		return
	end

	local function formatId(id)
		local s = tostring(id)
		if s:find("://") then
			return s
		end
		return "http://www.roblox.com/asset/?id=" .. s
	end

	local success, err = pcall(function()
		if animType == "Idle" then
			if animate:FindFirstChild("idle") then
				if type(animId) == "table" then
					animate.idle.Animation1.AnimationId = formatId(animId[1])
					animate.idle.Animation2.AnimationId = formatId(animId[2])
				else
					animate.idle.Animation1.AnimationId = formatId(animId)
					animate.idle.Animation2.AnimationId = formatId(animId)
				end
			end
		elseif animType == "Walk" and animate:FindFirstChild("walk") then
			animate.walk.WalkAnim.AnimationId = formatId(animId)
		elseif animType == "Run" and animate:FindFirstChild("run") then
			animate.run.RunAnim.AnimationId = formatId(animId)
		elseif animType == "Jump" and animate:FindFirstChild("jump") then
			animate.jump.JumpAnim.AnimationId = formatId(animId)
		elseif animType == "Fall" and animate:FindFirstChild("fall") then
			animate.fall.FallAnim.AnimationId = formatId(animId)
		elseif animType == "Climb" and animate:FindFirstChild("climb") then
			animate.climb.ClimbAnim.AnimationId = formatId(animId)
		elseif animType == "Swim" and animate:FindFirstChild("swim") then
			animate.swim.Swim.AnimationId = formatId(animId)
		elseif animType == "SwimIdle" and animate:FindFirstChild("swimidle") then
			animate.swimidle.SwimIdle.AnimationId = formatId(animId)
		end
	end)

	if success then
		local hum = char:FindFirstChild("Humanoid")
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Landed)
		end
		WindUI:Notify({ Title = "Success", Content = "Set " .. animType .. " animation", Duration = 1 })
	else
		WindUI:Notify({ Title = "Error", Content = "Failed to set animation", Duration = 2 })
	end
end

CustomAnimTab:Section({ Title = "Animation Preset", TextSize = 16 })
CustomAnimTab:Divider()

local function ApplyAnim(animType, animName)
	local id = nil
	if animName == "Original" then
		id = OriginalAnims[animType]
	elseif AnimDB[animType] then
		id = AnimDB[animType][animName]
	end

	if id then
		SetAnimation(animType, id)
	end
end

for _, animType in ipairs(AnimTypes) do
	local values = { "Original" }
	local list = {}
	for name, _ in pairs(AnimDB[animType] or {}) do
		table.insert(list, name)
	end
	table.sort(list)
	for _, name in ipairs(list) do
		table.insert(values, name)
	end

	CustomAnimTab:Dropdown({
		Title = "[◎] " .. animType .. " Animation",
		Values = values,
		Default = "Original",
		Callback = function(val)
			ApplyAnim(animType, val)
		end,
	})
end

CustomAnimTab:Section({ Title = "➕ Add New", TextSize = 16 })
CustomAnimTab:Divider()

local newAnimName = ""
local newAnimID = ""

CustomAnimTab:Dropdown({
	Title = "Animation Type",
	Values = AnimTypes,
	Default = "Idle",
	Callback = function(val)
		CurrentAnimType = val
	end,
})

CustomAnimTab:Input({
	Title = "Name",
	Placeholder = "e.g. Griddy",
	Callback = function(txt)
		newAnimName = txt
	end,
})

CustomAnimTab:Input({
	Title = "Asset ID",
	Placeholder = "Numeric ID",
	Callback = function(txt)
		newAnimID = txt
	end,
})

CustomAnimTab:Button({
	Title = "Save & Apply",
	Desc = "Save to list and apply",
	Callback = function()
		if newAnimName == "" or newAnimID == "" then
			WindUI:Notify({ Title = "Error", Content = "Missing Name or ID", Duration = 2 })
			return
		end
		local num = newAnimID:match("%d+")
		if not num then
			WindUI:Notify({ Title = "Error", Content = "Invalid ID", Duration = 2 })
			return
		end

		AnimDB[CurrentAnimType][NewAnimName] = id
		SaveAnimDB()
		SetAnimation(CurrentAnimType, id)
		WindUI:Notify({ Title = "Saved", Content = "Added custom animation", Duration = 2 })
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- AUTO-UPDATE STATS (Every 5 seconds)
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
	while task.wait(5) do
		pcall(function()
			local newExecName, newExecVersion = GetExecutorInfo()
			local newStatsDesc = "⚡ Executor: "
				.. newExecName
				.. " ("
				.. newExecVersion
				.. ")\n"
				.. "👥 Players: "
				.. #Players:GetPlayers()
				.. "/"
				.. Players.MaxPlayers
				.. "\n"
				.. "📶 Ping: "
				.. GetPing()
				.. " ms\n"
				.. "🖥️ FPS: "
				.. GetFPS()
				.. "\n"
				.. "⏱️ Server Age: "
				.. GetServerAge()
			LiveStatsCard:SetDesc(newStatsDesc)
		end)
	end
end)

-- ══════════════════════════════════════════════════════════════════
-- 🌌 SKYBOX TAB
-- ══════════════════════════════════════════════════════════════════
local SkyBoxTab = Window:Tab({
	Title = "Sky Box",
	Icon = "cloud",
})

SkyBoxTab:Section({ Title = "🌌 Skybox Changer", TextSize = 20 })
SkyBoxTab:Divider()

local originalSky = nil
local originalAtmosphere = nil
local currentSkybox = "Default"
local skyboxBypassConnection = nil
local RunService = game:GetService("RunService")

local SkyboxPresets = {
	["Default"] = nil,
	["Galaxy Night"] = {
		SkyboxBk = "rbxassetid://159454286",
		SkyboxDn = "rbxassetid://159454296",
		SkyboxFt = "rbxassetid://159454299",
		SkyboxLf = "rbxassetid://159454286",
		SkyboxRt = "rbxassetid://159454291",
		SkyboxUp = "rbxassetid://159454293",
		StarCount = 5000,
	},
	["Blood Red"] = {
		SkyboxBk = "rbxassetid://1012890",
		SkyboxDn = "rbxassetid://1012891",
		SkyboxFt = "rbxassetid://1012887",
		SkyboxLf = "rbxassetid://1012889",
		SkyboxRt = "rbxassetid://1012888",
		SkyboxUp = "rbxassetid://1014449",
		StarCount = 500,
	},
	["Scary Red"] = {
		SkyboxBk = "rbxassetid://108929045660200",
		SkyboxDn = "rbxassetid://78646480540009",
		SkyboxFt = "rbxassetid://90546017435179",
		SkyboxLf = "rbxassetid://109838453114563",
		SkyboxRt = "rbxassetid://94190734796082",
		SkyboxUp = "rbxassetid://126944775797063",
	},
	["Skybox HD"] = {
		SkyboxBk = "rbxassetid://16553658937",
		SkyboxDn = "rbxassetid://16553660713",
		SkyboxFt = "rbxassetid://16553662144",
		SkyboxLf = "rbxassetid://16553664042",
		SkyboxRt = "rbxassetid://16553665766",
		SkyboxUp = "rbxassetid://16553667750",
		StarCount = 3000,
	},
	["Night City"] = {
		SkyboxBk = "rbxassetid://163897885",
		SkyboxDn = "rbxassetid://163898013",
		SkyboxFt = "rbxassetid://163899342",
		SkyboxLf = "rbxassetid://163897886",
		SkyboxRt = "rbxassetid://163897887",
		SkyboxUp = "rbxassetid://163898013",
		StarCount = 5000,
	},
}

local function CaptureOriginalSky()
	if originalSky then
		return
	end
	local lighting = game:GetService("Lighting")
	local existingSky = lighting:FindFirstChildOfClass("Sky")
	if existingSky then
		originalSky = {
			SkyboxBk = existingSky.SkyboxBk,
			SkyboxDn = existingSky.SkyboxDn,
			SkyboxFt = existingSky.SkyboxFt,
			SkyboxLf = existingSky.SkyboxLf,
			SkyboxRt = existingSky.SkyboxRt,
			SkyboxUp = existingSky.SkyboxUp,
			StarCount = existingSky.StarCount,
		}
	end
	originalAtmosphere = lighting.Ambient
end

local function StopSkyboxBypass()
	if skyboxBypassConnection then
		skyboxBypassConnection:Disconnect()
		skyboxBypassConnection = nil
	end
end

local function ApplySkyboxWithBypass(preset)
	local lighting = game:GetService("Lighting")

	skyboxBypassConnection = RunService.Heartbeat:Connect(function()
		for _, child in pairs(lighting:GetChildren()) do
			if child:IsA("Sky") then
				child.SkyboxBk = preset.SkyboxBk
				child.SkyboxDn = preset.SkyboxDn
				child.SkyboxFt = preset.SkyboxFt
				child.SkyboxLf = preset.SkyboxLf
				child.SkyboxRt = preset.SkyboxRt
				child.SkyboxUp = preset.SkyboxUp
				child.StarCount = preset.StarCount or 0
			end
		end
	end)
end

local function ApplySkybox(presetName)
	local lighting = game:GetService("Lighting")
	CaptureOriginalSky()
	StopSkyboxBypass()

	local preset = SkyboxPresets[presetName]

	if presetName == "Default" then
		local sky = lighting:FindFirstChildOfClass("Sky")
		if sky and originalSky then
			sky.SkyboxBk = originalSky.SkyboxBk
			sky.SkyboxDn = originalSky.SkyboxDn
			sky.SkyboxFt = originalSky.SkyboxFt
			sky.SkyboxLf = originalSky.SkyboxLf
			sky.SkyboxRt = originalSky.SkyboxRt
			sky.SkyboxUp = originalSky.SkyboxUp
			sky.StarCount = originalSky.StarCount
		end
		if originalAtmosphere then
			lighting.Ambient = originalAtmosphere
		end
		currentSkybox = "Default"
		return
	end

	if not preset then
		return
	end

	local sky = lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Parent = lighting
	end

	sky.SkyboxBk = preset.SkyboxBk
	sky.SkyboxDn = preset.SkyboxDn
	sky.SkyboxFt = preset.SkyboxFt
	sky.SkyboxLf = preset.SkyboxLf
	sky.SkyboxRt = preset.SkyboxRt
	sky.SkyboxUp = preset.SkyboxUp
	sky.StarCount = preset.StarCount or 0

	ApplySkyboxWithBypass(preset)
	currentSkybox = presetName
end

local skyboxList = { "Galaxy Night", "Blood Red", "Scary Red", "Skybox HD", "Night City" }

for _, skyName in ipairs(skyboxList) do
	SkyBoxTab:Toggle({
		Title = skyName,
		Desc = "Toggle " .. skyName .. " skybox",
		Value = false,
		Callback = function(state)
			if state then
				ApplySkybox(skyName)
				WindUI:Notify({ Title = "Skybox", Content = "Applied " .. skyName, Duration = 1 })
			else
				if currentSkybox == skyName then
					ApplySkybox("Default")
					WindUI:Notify({ Title = "Skybox", Content = "Restored Default", Duration = 1 })
				end
			end
		end,
	})
end

-- ══════════════════════════════════════════════════════════════════
-- 🚶 AUTO WALK TAB (Declaration Only - Content Below)
-- ══════════════════════════════════════════════════════════════════
local ListMapTab = Window:Tab({
	Title = "Auto Walk",
	Icon = "folder-open",
})

-- ══════════════════════════════════════════════════════════════════
-- 🛠️ TOOLS TAB
-- ══════════════════════════════════════════════════════════════════
local ToolsTab = Window:Tab({
	Title = "Tools",
	Icon = "wrench",
})

-- 🏃 MOVEMENT
ToolsTab:Section({ Title = "🏃 Player Settings", TextSize = 20 })

ToolsTab:Slider({
	Title = "WalkSpeed",
	Desc = "Running speed (Default: 16)",
	Step = 1,
	Value = { Min = 16, Max = 200, Default = 16 },
	Callback = function(v)
		Config.WalkSpeed = v
		local hum = GetHumanoid()
		if hum then
			hum.WalkSpeed = v
		end
	end,
})

ToolsTab:Slider({
	Title = "JumpPower",
	Desc = "Jump height (Default: 50)",
	Step = 1,
	Value = { Min = 50, Max = 300, Default = 50 },
	Callback = function(v)
		Config.JumpPower = v
		local hum = GetHumanoid()
		if hum then
			hum.JumpPower = v
		end
	end,
})

-- Infinite Jump
local infiniteJumpConnection = nil
local isInfiniteJumpOn = false

ToolsTab:Toggle({
	Title = "Infinite Jump",
	Desc = "Jump in mid-air",
	Value = false,
	Callback = function(state)
		isInfiniteJumpOn = state

		if isInfiniteJumpOn then
			infiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
				local hum = GetHumanoid()
				if hum then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end)

			WindUI:Notify({
				Title = "Infinite Jump",
				Content = "Infinite Jump enabled!",
				Duration = 2,
			})
		else
			if infiniteJumpConnection then
				infiniteJumpConnection:Disconnect()
				infiniteJumpConnection = nil
			end

			WindUI:Notify({
				Title = "Infinite Jump",
				Content = "Infinite Jump disabled.",
				Duration = 2,
			})
		end
	end,
})

ToolsTab:Divider()

-- 🚀 TELEPORT
ToolsTab:Section({ Title = "🚀 Teleportation", TextSize = 20 })

ToolsTab:Dropdown({
	Title = "Teleport to Player",
	Desc = "Select target player",
	Values = (function()
		local list = {}
		for _, p in pairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then
				table.insert(list, p.Name)
			end
		end
		return list
	end)(),
	Callback = function(selected)
		local target = Players:FindFirstChild(selected)
		if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local hrp = GetHRP()
			if hrp then
				hrp.CFrame = target.Character.HumanoidRootPart.CFrame
				WindUI:Notify({ Title = "Teleported", Content = "To " .. selected, Duration = 2 })
			end
		end
	end,
})

ToolsTab:Button({
	Title = "Click Teleport",
	Desc = "Teleport to mouse click position",
	Callback = function()
		local mouse = LocalPlayer:GetMouse()
		if mouse.Hit then
			local hrp = GetHRP()
			if hrp then
				hrp.CFrame = mouse.Hit + Vector3.new(0, 3, 0)
			end
		end
	end,
})

ToolsTab:Divider()

-- ✈️ FLY
ToolsTab:Section({ Title = "✈️ Flight Mode", TextSize = 20 })

local isFlying = false
local flyConnection = nil
local flySpeed = 50

ToolsTab:Toggle({
	Title = "Enable Fly",
	Desc = "Toggle flight",
	Value = false,
	Callback = function(state)
		isFlying = state
		local hrp = GetHRP()

		if state then
			if hrp then
				local bodyVel = Instance.new("BodyVelocity")
				bodyVel.Name = "StarshipFly"
				bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
				bodyVel.Velocity = Vector3.new(0, 0, 0)
				bodyVel.Parent = hrp

				local bodyGyro = Instance.new("BodyGyro")
				bodyGyro.Name = "StarshipGyro"
				bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
				bodyGyro.P = 9000
				bodyGyro.Parent = hrp

				flyConnection = RunService.Heartbeat:Connect(function()
					if isFlying and hrp and hrp:FindFirstChild("StarshipFly") then
						local vel = Vector3.new(0, 0, 0)
						local cam = workspace.CurrentCamera
						local look = cam.CFrame.LookVector
						local right = cam.CFrame.RightVector

						if UserInputService:IsKeyDown(Enum.KeyCode.W) then
							vel = vel + look
						end
						if UserInputService:IsKeyDown(Enum.KeyCode.S) then
							vel = vel - look
						end
						if UserInputService:IsKeyDown(Enum.KeyCode.A) then
							vel = vel - right
						end
						if UserInputService:IsKeyDown(Enum.KeyCode.D) then
							vel = vel + right
						end
						if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
							vel = vel + Vector3.new(0, 1, 0)
						end
						if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
							vel = vel - Vector3.new(0, 1, 0)
						end

						if vel.Magnitude > 0 then
							vel = vel.Unit * flySpeed
						end

						hrp.StarshipFly.Velocity = vel
						hrp.StarshipGyro.CFrame = cam.CFrame
					end
				end)
			end
		else
			if flyConnection then
				flyConnection:Disconnect()
				flyConnection = nil
			end
			if hrp then
				for _, c in pairs(hrp:GetChildren()) do
					if c.Name == "StarshipFly" or c.Name == "StarshipGyro" then
						c:Destroy()
					end
				end
			end
		end
	end,
})

ToolsTab:Slider({
	Title = "Fly Speed",
	Desc = "Speed (Default: 50)",
	Step = 5,
	Value = { Min = 10, Max = 300, Default = 50 },
	Callback = function(v)
		flySpeed = v
	end,
})

ToolsTab:Divider()

ToolsTab:Button({
	Title = "💀 Reset Character",
	Callback = function()
		local hum = GetHumanoid()
		if hum then
			hum.Health = 0
		end
	end,
})

ToolsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 📊 SPEED CHECKER
-- ══════════════════════════════════════════════════════════════════
ToolsTab:Section({ Title = "📊 Speed Checker", TextSize = 20 })

local speedDisplayGui = nil
local speedDisplayConnection = nil
local isSpeedDisplayOn = false

local function CreateSpeedDisplayMobile()
	if speedDisplayGui then
		speedDisplayGui:Destroy()
	end

	local parent
	local success, cGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if success and cGui then
		parent = cGui
	else
		parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "StarshipSpeedDisplay"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 999998
	screen.IgnoreGuiInset = true
	screen.Parent = parent

	local frame = Instance.new("Frame")
	frame.Name = "SpeedFrame"
	frame.Size = UDim2.fromOffset(140, 70)
	frame.Position = UDim2.new(0.5, -70, 0, 50)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Draggable = true
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(99, 102, 241)
	stroke.Thickness = 2
	stroke.Parent = frame

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Text = "WALKSPEED"
	titleLbl.Size = UDim2.new(1, 0, 0, 16)
	titleLbl.Position = UDim2.new(0, 0, 0, 6)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3 = Color3.fromRGB(150, 150, 160)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 9
	titleLbl.Parent = frame

	local speedLbl = Instance.new("TextLabel")
	speedLbl.Name = "SpeedValue"
	speedLbl.Text = "0"
	speedLbl.Size = UDim2.new(1, 0, 0, 28)
	speedLbl.Position = UDim2.new(0, 0, 0, 22)
	speedLbl.BackgroundTransparency = 1
	speedLbl.TextColor3 = Color3.fromRGB(99, 102, 241)
	speedLbl.Font = Enum.Font.GothamBold
	speedLbl.TextSize = 24
	speedLbl.Parent = frame

	local unitLbl = Instance.new("TextLabel")
	unitLbl.Text = "(default: 16)"
	unitLbl.Size = UDim2.new(1, 0, 0, 12)
	unitLbl.Position = UDim2.new(0, 0, 0, 50)
	unitLbl.BackgroundTransparency = 1
	unitLbl.TextColor3 = Color3.fromRGB(120, 120, 130)
	unitLbl.Font = Enum.Font.Gotham
	unitLbl.TextSize = 9
	unitLbl.Parent = frame

	return screen, frame
end

ToolsTab:Toggle({
	Title = "Speed Display",
	Desc = "Show current walkspeed on screen",
	Value = false,
	Callback = function(state)
		isSpeedDisplayOn = state

		if isSpeedDisplayOn then
			local screen, frame = CreateSpeedDisplayMobile()
			speedDisplayGui = screen

			speedDisplayConnection = RunService.Heartbeat:Connect(function()
				local hum = GetHumanoid()
				if hum and speedDisplayGui then
					local speed = hum.WalkSpeed
					local speedLbl = speedDisplayGui:FindFirstChild("SpeedFrame")
					if speedLbl then
						speedLbl = speedLbl:FindFirstChild("SpeedValue")
					end
					if speedLbl then
						speedLbl.Text = string.format("%.0f", speed)
						if speed <= 16 then
							speedLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
						elseif speed <= 30 then
							speedLbl.TextColor3 = Color3.fromRGB(34, 197, 94)
						elseif speed <= 60 then
							speedLbl.TextColor3 = Color3.fromRGB(234, 179, 8)
						else
							speedLbl.TextColor3 = Color3.fromRGB(239, 68, 68)
						end
					end
				end
			end)

			WindUI:Notify({
				Title = "Speed Display",
				Content = "Speed display enabled!",
				Duration = 2,
			})
		else
			if speedDisplayConnection then
				speedDisplayConnection:Disconnect()
				speedDisplayConnection = nil
			end
			if speedDisplayGui then
				speedDisplayGui:Destroy()
				speedDisplayGui = nil
			end

			WindUI:Notify({
				Title = "Speed Display",
				Content = "Speed display disabled.",
				Duration = 2,
			})
		end
	end,
})

ToolsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🔒 SHIFT LOCK
-- ══════════════════════════════════════════════════════════════════
ToolsTab:Section({ Title = "🔒 Shift Lock", TextSize = 20 })

local isShiftLockOn = false
local shiftLockConnection = nil

ToolsTab:Toggle({
	Title = "Shift Lock",
	Desc = "Lock camera behind character",
	Value = false,
	Callback = function(state)
		isShiftLockOn = state

		if isShiftLockOn then
			shiftLockConnection = RunService.RenderStepped:Connect(function()
				local char = GetCharacter()
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChild("Humanoid")
				if root and hum then
					hum.AutoRotate = false
					UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

					local cam = workspace.CurrentCamera
					local look = cam.CFrame.LookVector
					root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
				end
			end)

			WindUI:Notify({
				Title = "Shift Lock",
				Content = "Shift Lock enabled!",
				Duration = 2,
			})
		else
			if shiftLockConnection then
				shiftLockConnection:Disconnect()
				shiftLockConnection = nil
			end
			local char = GetCharacter()
			local hum = char and char:FindFirstChild("Humanoid")
			if hum then
				hum.AutoRotate = true
			end
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default

			WindUI:Notify({
				Title = "Shift Lock",
				Content = "Shift Lock disabled.",
				Duration = 2,
			})
		end
	end,
})

ToolsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🎭 STREAMER MODE (Privacy)
-- ══════════════════════════════════════════════════════════════════
ToolsTab:Section({ Title = "🎭 Streamer Mode", TextSize = 20 })

local isStreamerMode = false
local streamerSpoofConnections = {}
local originalTexts = {}
local spoofedUsername = ""
local spoofedDisplayName = ""

local randomNames = {
	"Steve",
	"Alex",
	"ProGamer",
	"Noob123",
	"Player",
	"Guest",
	"Anonymous",
	"Shadow",
	"Phoenix",
	"Dragon",
	"Ninja",
	"Master",
	"Legend",
	"Hero",
	"Star",
	"Gamer",
	"Champion",
	"Warrior",
}
local randomSuffixes = { "123", "456", "789", "007", "999", "101", "XD", "_YT", "_TTV", "" }

local function SpoofAllNames()
	local fakeName = spoofedUsername ~= "" and spoofedUsername or "Player"
	local fakeDisplay = spoofedDisplayName ~= "" and spoofedDisplayName or fakeName
	local realName = LocalPlayer.Name
	local realDisplay = LocalPlayer.DisplayName

	local function SpoofGui(gui)
		if not gui then
			return
		end
		for _, obj in pairs(gui:GetDescendants()) do
			if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
				local text = obj.Text
				if text and (text:find(realName) or text:find(realDisplay)) then
					if not originalTexts[obj] then
						originalTexts[obj] = text
					end
					obj.Text = text:gsub(realName, fakeName):gsub(realDisplay, fakeDisplay)
				end
			end
		end
	end

	local function SpoofCharacter(character)
		if not character then
			return
		end
		for _, obj in pairs(character:GetDescendants()) do
			if obj:IsA("BillboardGui") then
				for _, child in pairs(obj:GetDescendants()) do
					if child:IsA("TextLabel") or child:IsA("TextButton") then
						local text = child.Text
						if text and (text:find(realName) or text:find(realDisplay)) then
							if not originalTexts[child] then
								originalTexts[child] = text
							end
							child.Text = text:gsub(realName, fakeName):gsub(realDisplay, fakeDisplay)
						end
					end
				end
			end
		end
	end

	pcall(function()
		local playerList = game:GetService("CoreGui"):FindFirstChild("PlayerList")
		if playerList then
			SpoofGui(playerList)
		end
	end)

	if LocalPlayer:FindFirstChild("PlayerGui") then
		SpoofGui(LocalPlayer.PlayerGui)
	end

	if LocalPlayer.Character then
		SpoofCharacter(LocalPlayer.Character)
	end
end

local function RestoreAllNames()
	for obj, text in pairs(originalTexts) do
		if obj and obj.Parent then
			pcall(function()
				obj.Text = text
			end)
		end
	end
	originalTexts = {}
end

ToolsTab:Input({
	Title = "Fake Username",
	Desc = "Your spoofed username",
	Placeholder = "Enter fake name...",
	Callback = function(text)
		spoofedUsername = text
		if isStreamerMode then
			SpoofAllNames()
		end
	end,
})

ToolsTab:Input({
	Title = "Fake Display Name",
	Desc = "Your spoofed display name",
	Placeholder = "Enter fake display...",
	Callback = function(text)
		spoofedDisplayName = text
		if isStreamerMode then
			SpoofAllNames()
		end
	end,
})

ToolsTab:Button({
	Title = "🎲 Random Name",
	Desc = "Generate a random fake name",
	Callback = function()
		local name = randomNames[math.random(#randomNames)] .. randomSuffixes[math.random(#randomSuffixes)]
		spoofedUsername = name
		spoofedDisplayName = name
		WindUI:Notify({
			Title = "Random Name",
			Content = "Generated: " .. name,
			Duration = 2,
		})
		if isStreamerMode then
			SpoofAllNames()
		end
	end,
})

ToolsTab:Toggle({
	Title = "Enable Streamer Mode",
	Desc = "Spoof your name (client-side only)",
	Value = false,
	Callback = function(state)
		isStreamerMode = state

		if isStreamerMode then
			SpoofAllNames()

			local lastSpoof = 0
			local spoofLoop = RunService.Heartbeat:Connect(function()
				if isStreamerMode and tick() - lastSpoof > 1 then
					lastSpoof = tick()
					SpoofAllNames()
				end
			end)
			table.insert(streamerSpoofConnections, spoofLoop)

			local charCon = LocalPlayer.CharacterAdded:Connect(function(char)
				task.wait(1)
				if isStreamerMode then
					SpoofAllNames()
				end
			end)
			table.insert(streamerSpoofConnections, charCon)

			WindUI:Notify({
				Title = "Streamer Mode",
				Content = "Name spoofing enabled!",
				Duration = 3,
			})
		else
			for _, con in pairs(streamerSpoofConnections) do
				if con then
					pcall(function()
						con:Disconnect()
					end)
				end
			end
			streamerSpoofConnections = {}
			RestoreAllNames()

			WindUI:Notify({
				Title = "Streamer Mode",
				Content = "Name spoofing disabled.",
				Duration = 2,
			})
		end
	end,
})

ToolsTab:Divider()

-- ════════════════════════����������������═════════════════════════════════════════
-- 👥 HIDE PLAYERS
-- ══════════════════════════════════════════════════════════════════
ToolsTab:Section({ Title = "👥 Hide Players", TextSize = 20 })

local isHidePlayers = false
local hiddenPlayersData = {}
local playerAddedConnection = nil

local function HidePlayer(player)
	if player == LocalPlayer then
		return
	end
	local character = player.Character
	if character then
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("Decal") then
				if not hiddenPlayersData[part] then
					hiddenPlayersData[part] = part.Transparency
				end
				part.Transparency = 1
			elseif part:IsA("BillboardGui") or part:IsA("SurfaceGui") then
				if not hiddenPlayersData[part] then
					hiddenPlayersData[part] = part.Enabled
				end
				part.Enabled = false
			end
		end
	end
end

local function ShowPlayer(player)
	if player == LocalPlayer then
		return
	end
	local character = player.Character
	if character then
		for _, part in pairs(character:GetDescendants()) do
			if hiddenPlayersData[part] ~= nil then
				if part:IsA("BasePart") or part:IsA("Decal") then
					part.Transparency = hiddenPlayersData[part]
				elseif part:IsA("BillboardGui") or part:IsA("SurfaceGui") then
					part.Enabled = hiddenPlayersData[part]
				end
				hiddenPlayersData[part] = nil
			end
		end
	end
end

ToolsTab:Toggle({
	Title = "Hide All Players",
	Desc = "Make other players invisible",
	Value = false,
	Callback = function(state)
		isHidePlayers = state

		if isHidePlayers then
			-- Hide all current players
			for _, player in pairs(Players:GetPlayers()) do
				HidePlayer(player)

				-- Also listen for character respawns
				player.CharacterAdded:Connect(function()
					if isHidePlayers then
						task.wait(0.5) -- Wait for character to fully load
						HidePlayer(player)
					end
				end)
			end

			-- Listen for new players joining
			playerAddedConnection = Players.PlayerAdded:Connect(function(player)
				player.CharacterAdded:Connect(function()
					if isHidePlayers then
						task.wait(0.5)
						HidePlayer(player)
					end
				end)
			end)
			table.insert(Connections, playerAddedConnection)

			WindUI:Notify({
				Title = "Hide Players",
				Content = "All players are now invisible",
				Duration = 2,
			})
		else
			-- Show all players
			for _, player in pairs(Players:GetPlayers()) do
				ShowPlayer(player)
			end
			hiddenPlayersData = {}

			if playerAddedConnection then
				playerAddedConnection:Disconnect()
				playerAddedConnection = nil
			end

			WindUI:Notify({
				Title = "Hide Players",
				Content = "All players are now visible",
				Duration = 2,
			})
		end
	end,
})

ToolsTab:Divider()

-- ══════════════════════════════════════════════════════════�������������═══════
-- 🚶 AUTO WALK TAB CONTENT
-- ══════════════════════════════════════════════════════════════════

-- Constants for Playback
local HttpService = game:GetService("HttpService")
local FOLDER_NAME = "StarshipCore"
local MERGER_FOLDER = FOLDER_NAME .. "/StarshipMerger"

-- Create folders if not exist (with error handling)
local folderStatus = "Unknown"
pcall(function()
	if isfolder then
		if not isfolder(FOLDER_NAME) then
			makefolder(FOLDER_NAME)
		end
		if not isfolder(MERGER_FOLDER) then
			makefolder(MERGER_FOLDER)
		end
		folderStatus = isfolder(MERGER_FOLDER) and "OK" or "Failed"
	else
		folderStatus = "No File API"
	end
end)

-- Playback State
local PlaybackState = {
	isPlaying = false,
	isPaused = false,
	currentFile = nil,
	frameData = nil,
	currentTime = 0,
	totalDuration = 0,
	speed = 1,
	strictRetarget = false,
	nativeAnim = false,
	isLooping = false,
	connection = nil,
	lastFrameIndex = 1,
	lastPlaybackTime = 0,
	isFlexible = false,
	isRespawnOnEnd = false,
	isSpinning = false,
	isMoonwalk = false,
	jointMap = {},
}

-- Spin Logic
local RunService = game:GetService("RunService")
RunService.RenderStepped:Connect(function(dt)
	if PlaybackState.isSpinning and PlaybackState.isPlaying and not PlaybackState.isPaused then
		local char = GetCharacter()
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChild("Humanoid")

		if hrp and hum then
			local state = hum:GetState()
			local isAir = (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping)

			if isAir then
				hum.AutoRotate = false
				local spinSpeed = 12
				local spinRot = CFrame.Angles(0, spinSpeed * dt, 0)
				local cam = workspace.CurrentCamera
				if cam then
					local relCam = hrp.CFrame:ToObjectSpace(cam.CFrame)
					hrp.CFrame = hrp.CFrame * spinRot
					cam.CFrame = hrp.CFrame:ToWorldSpace(relCam)
				else
					hrp.CFrame = hrp.CFrame * spinRot
				end
			end
		end
	end
end)

-- File List
local mergedFiles = {}
local currentSearchQuery = ""

-- Function to refresh file list
local function RefreshFileList()
	mergedFiles = {}
	if listfiles and isfolder(MERGER_FOLDER) then
		local allFiles = listfiles(MERGER_FOLDER)
		for _, filePath in ipairs(allFiles) do
			if string.sub(filePath, -5) == ".json" then
				local fileName = string.match(filePath, "[^/\\]+$") or filePath
				table.insert(mergedFiles, fileName)
			end
		end
		-- Natural sort (handle numbers properly)
		local function padZero(num)
			local s = tostring(num)
			while string.len(s) < 10 do
				s = "0" .. s
			end
			return s
		end

		local sortable = {}
		for i, fn in ipairs(mergedFiles) do
			local baseName = string.gsub(fn, "%.json$", "")
			local numPart = string.match(baseName, "(%d+)$")
			local sortKey
			if numPart and string.len(numPart) > 0 then
				local prefixLen = string.len(baseName) - string.len(numPart)
				local prefix = string.sub(baseName, 1, prefixLen)
				sortKey = "1" .. string.lower(prefix) .. padZero(tonumber(numPart) or 0)
			else
				sortKey = "0" .. string.lower(baseName) .. padZero(0)
			end
			table.insert(sortable, { name = fn, key = sortKey })
		end

		table.sort(sortable, function(a, b)
			return a.key < b.key
		end)

		mergedFiles = {}
		for _, v in ipairs(sortable) do
			table.insert(mergedFiles, v.name)
		end
	end
	return mergedFiles
end

-- Function to get dropdown options
local function GetFileOptions()
	RefreshFileList()
	if #mergedFiles == 0 then
		return { "No files found" }
	end
	return mergedFiles
end

-- Function to get files that match search query
local function GetMatchingFilesByQuery(query)
	-- Selalu ambil list file terbaru
	local files = RefreshFileList()
	if not files or #files == 0 then
		return {}
	end

	if not query or query == "" then
		return files
	end

	-- Trim dan lowercase query
	query = tostring(query or "")
	query = string.lower(query:match("^%s*(.-)%s*$"))
	if query == "" then
		return files
	end

	local results = {}
	for _, file in ipairs(files) do
		local name = string.lower(tostring(file))
		if string.find(name, query, 1, true) then
			table.insert(results, file)
		end
	end
	return results
end

-- ═══════════════════════════════════════════════════════════════════
-- PLAYBACK ENGINE (Based on StarshipCore.lua)
-- ═══════════════════════════════════════════════════════════════════

-- SMOOTHING SETTINGS (Default values - no UI adjustment on mobile)
local SMOOTH_SETTINGS = {
	LiveSmoothingEnabled = true, -- Auto-smooth on load
	LiveSmoothingStrength = 5, -- Default strength (1-10)
	PositionBasedEnabled = true, -- Position-based playback for smoother ground movement
}

-- ═══════════════════════════════════════════════════════════════════
-- SMOOTHING FUNCTIONS (Same as PC StarshipCore.lua)
-- ═══════════════════════════════════════════════════════════════════

-- Deep copy function
local function DeepCopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
		end
		setmetatable(copy, DeepCopy(getmetatable(orig)))
	else
		copy = orig
	end
	return copy
end

-- Catmull-Rom Spline Interpolation for ultra-smooth curves
local function CatmullRomSpline(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

-- Catmull-Rom for Vector3
local function CatmullRomVector3(v0, v1, v2, v3, t)
	return Vector3.new(
		CatmullRomSpline(v0.X, v1.X, v2.X, v3.X, t),
		CatmullRomSpline(v0.Y, v1.Y, v2.Y, v3.Y, t),
		CatmullRomSpline(v0.Z, v1.Z, v2.Z, v3.Z, t)
	)
end

-- Smooth interpolation between frames using Catmull-Rom (requires 4 frames context)
local function SmoothInterpolateFrames(frames, frameIdx, alpha)
	local n = #frames
	if n < 2 then
		return nil, nil
	end

	-- Get 4 frames for Catmull-Rom (clamp at boundaries)
	local i0 = math.max(1, frameIdx - 1)
	local i1 = frameIdx
	local i2 = math.min(n, frameIdx + 1)
	local i3 = math.min(n, frameIdx + 2)

	local f0, f1, f2, f3 = frames[i0], frames[i1], frames[i2], frames[i3]

	-- Interpolate position with Catmull-Rom
	local smoothPos = nil
	if f0.pos and f1.pos and f2.pos and f3.pos then
		local p0 = Vector3.new(f0.pos.x, f0.pos.y, f0.pos.z)
		local p1 = Vector3.new(f1.pos.x, f1.pos.y, f1.pos.z)
		local p2 = Vector3.new(f2.pos.x, f2.pos.y, f2.pos.z)
		local p3 = Vector3.new(f3.pos.x, f3.pos.y, f3.pos.z)
		smoothPos = CatmullRomVector3(p0, p1, p2, p3, alpha)
	elseif f1.pos and f2.pos then
		-- Fallback to linear lerp
		local p1 = Vector3.new(f1.pos.x, f1.pos.y, f1.pos.z)
		local p2 = Vector3.new(f2.pos.x, f2.pos.y, f2.pos.z)
		smoothPos = p1:Lerp(p2, alpha)
	end

	-- Interpolate velocity with Catmull-Rom (smoother acceleration)
	local smoothVel = nil
	if f0.vel and f1.vel and f2.vel and f3.vel then
		local v0 = Vector3.new(f0.vel.x, f0.vel.y, f0.vel.z)
		local v1 = Vector3.new(f1.vel.x, f1.vel.y, f1.vel.z)
		local v2 = Vector3.new(f2.vel.x, f2.vel.y, f2.vel.z)
		local v3 = Vector3.new(f3.vel.x, f3.vel.y, f3.vel.z)
		smoothVel = CatmullRomVector3(v0, v1, v2, v3, alpha)
	elseif f1.vel and f2.vel then
		-- Fallback to linear lerp
		local v1 = Vector3.new(f1.vel.x, f1.vel.y, f1.vel.z)
		local v2 = Vector3.new(f2.vel.x, f2.vel.y, f2.vel.z)
		smoothVel = v1:Lerp(v2, alpha)
	end

	return smoothPos, smoothVel
end

-- Gaussian weight calculation for smooth falloff
local function GaussianWeight(distance, sigma)
	return math.exp(-(distance * distance) / (2 * sigma * sigma))
end

-- Gaussian-weighted smoothing for frames (runs once on load)
local function GetSmoothedFrames(frames, strength, isFlexible)
	local processedFrames = DeepCopy(frames)
	local iterations = math.clamp(strength or 1, 1, 10)
	local kernelRadius = math.clamp(math.ceil(strength / 2), 1, 5)
	local sigma = kernelRadius / 2

	for iter = 1, iterations do
		local tempFrames = DeepCopy(processedFrames)

		for i = 2, #processedFrames - 1 do
			local curr = processedFrames[i]

			if isFlexible then
				-- Gaussian-weighted position smoothing
				if curr.pos then
					local weightSum = 0
					local posSum = Vector3.new(0, 0, 0)

					for j = math.max(1, i - kernelRadius), math.min(#tempFrames, i + kernelRadius) do
						local neighbor = tempFrames[j]
						if neighbor.pos then
							local dist = math.abs(j - i)
							local weight = GaussianWeight(dist, sigma)
							local neighborPos = Vector3.new(neighbor.pos.x, neighbor.pos.y, neighbor.pos.z)
							posSum = posSum + neighborPos * weight
							weightSum = weightSum + weight
						end
					end

					if weightSum > 0 then
						local smoothedPos = posSum / weightSum
						local currPos = Vector3.new(curr.pos.x, curr.pos.y, curr.pos.z)
						local finalPos = currPos:Lerp(smoothedPos, 0.7)
						curr.pos.x = finalPos.X
						curr.pos.y = finalPos.Y
						curr.pos.z = finalPos.Z
					end
				end

				-- Gaussian-weighted velocity smoothing
				if curr.vel then
					local weightSum = 0
					local velSum = Vector3.new(0, 0, 0)

					for j = math.max(1, i - kernelRadius), math.min(#tempFrames, i + kernelRadius) do
						local neighbor = tempFrames[j]
						if neighbor.vel then
							local dist = math.abs(j - i)
							local weight = GaussianWeight(dist, sigma)
							local neighborVel = Vector3.new(neighbor.vel.x, neighbor.vel.y, neighbor.vel.z)
							velSum = velSum + neighborVel * weight
							weightSum = weightSum + weight
						end
					end

					if weightSum > 0 then
						local smoothedVel = velSum / weightSum
						local currVel = Vector3.new(curr.vel.x, curr.vel.y, curr.vel.z)
						local finalVel = currVel:Lerp(smoothedVel, 0.8)
						curr.vel.x = finalVel.X
						curr.vel.y = finalVel.Y
						curr.vel.z = finalVel.Z
					end
				end
			end
		end
	end
	return processedFrames
end

-- ═══════════════════════════════════════════════════════════════════
-- CORE PLAYBACK FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

-- Convert table to CFrame
local function TblToCF(t)
	if not t then
		return CFrame.new()
	end
	-- Standard mode format: {p={x,y,z}, o={x,y,z}}
	if t.p and t.o then
		return CFrame.new(t.p.x, t.p.y, t.p.z) * CFrame.Angles(t.o.x, t.o.y, t.o.z)
		-- Flexible mode root: {pos={x,y,z}, rot=yaw}
	elseif t.pos then
		local yaw = t.rot or 0
		return CFrame.new(t.pos.x, t.pos.y, t.pos.z) * CFrame.Angles(0, math.rad(yaw), 0)
		-- Raw CFrame array
	elseif type(t) == "table" and #t >= 12 then
		return CFrame.new(unpack(t))
	end
	return CFrame.new()
end

-- Binary search for frame index (optimized)
local function FindFrameIndex(frames, targetTime, hint)
	local n = #frames
	if n < 2 then
		return 1
	end

	-- Use hint for nearby search first
	if hint and hint >= 1 and hint < n then
		for offset = 0, 5 do
			local idx = hint + offset
			if idx >= 1 and idx < n then
				if frames[idx].t <= targetTime and frames[idx + 1].t >= targetTime then
					return idx
				end
			end
			idx = hint - offset
			if idx >= 1 and idx < n then
				if frames[idx].t <= targetTime and frames[idx + 1].t >= targetTime then
					return idx
				end
			end
		end
	end

	-- Binary search for large jumps
	local lo, hi = 1, n - 1
	while lo <= hi do
		local mid = math.floor((lo + hi) / 2)
		if frames[mid].t <= targetTime and frames[mid + 1].t >= targetTime then
			return mid
		elseif frames[mid].t > targetTime then
			hi = mid - 1
		else
			lo = mid + 1
		end
	end
	return math.clamp(lo, 1, n - 1)
end

-- Get all Motor6D joints
local function GetJoints(char)
	local joints = {}
	for _, d in pairs(char:GetDescendants()) do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		end
	end
	return joints
end

-- Reset character state
local function ResetCharacter()
	local char = GetCharacter()
	if not char then
		return
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = false
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		-- Remove playback constraints
		if hrp:FindFirstChild("PlaybackAtt") then
			hrp.PlaybackAtt:Destroy()
		end
		if hrp:FindFirstChild("PlaybackAO") then
			hrp.PlaybackAO:Destroy()
		end
		if hrp:FindFirstChild("PlaybackAP") then
			hrp.PlaybackAP:Destroy()
		end
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
		hum.PlatformStand = false
		-- CARRY PRESERVATION: Skip stopping animations when ForceCarryMode is ON
		if not _G.StarshipForceCarryMode then
			for _, track in pairs(hum:GetPlayingAnimationTracks()) do
				track:Stop()
			end
		end
		if hrp then
			hum:MoveTo(hrp.Position)
		end
	end

	local animate = char:FindFirstChild("Animate")
	-- CARRY PRESERVATION: Skip Animate restart when ForceCarryMode is ON
	if animate and not _G.StarshipForceCarryMode then
		animate.Disabled = true
		task.wait()
		animate.Disabled = false
	end
end

-- Stop playback
local function StopPlayback()
	PlaybackState.isPlaying = false
	PlaybackState.isPaused = false
	PlaybackState.currentTime = 0
	PlaybackState.lastFrameIndex = 1

	if PlaybackState.connection then
		PlaybackState.connection:Disconnect()
		PlaybackState.connection = nil
	end

	ResetCharacter()
end

-- ═══════════════════════════════════════════════════════════════════
-- PATH VISUALIZATION (PREMIUM ENHANCED)
-- ═══════════════════════════════════════════════════════════════════
local isPathVisualsEnabled = false
local pathVisualsFolder = nil
local pathAnimationConnection = nil
local currentPositionMarker = nil

-- Premium gradient colors (Green → Cyan → Blue → Purple → Pink)
local PATH_GRADIENT_COLORS = {
	Color3.fromRGB(34, 197, 94), -- Emerald Green (Start)
	Color3.fromRGB(6, 182, 212), -- Cyan
	Color3.fromRGB(59, 130, 246), -- Blue
	Color3.fromRGB(139, 92, 246), -- Purple
	Color3.fromRGB(236, 72, 153), -- Pink (End)
}

-- Interpolate between gradient colors based on progress (0-1)
local function GetGradientColor(progress)
	local numColors = #PATH_GRADIENT_COLORS
	local scaledProgress = progress * (numColors - 1)
	local colorIndex = math.floor(scaledProgress) + 1
	local colorAlpha = scaledProgress - math.floor(scaledProgress)

	local startColor = PATH_GRADIENT_COLORS[math.clamp(colorIndex, 1, numColors)]
	local endColor = PATH_GRADIENT_COLORS[math.clamp(colorIndex + 1, 1, numColors)]

	return startColor:Lerp(endColor, colorAlpha)
end

local function ClearPath()
	if pathAnimationConnection then
		pathAnimationConnection:Disconnect()
		pathAnimationConnection = nil
	end
	if currentPositionMarker then
		currentPositionMarker:Destroy()
		currentPositionMarker = nil
	end
	if pathVisualsFolder then
		pathVisualsFolder:Destroy()
		pathVisualsFolder = nil
	end
end

local function DrawPath(frames)
	ClearPath()
	if not frames or #frames < 2 then
		return
	end

	pathVisualsFolder = Instance.new("Folder")
	pathVisualsFolder.Name = "StarshipPathVisuals"
	pathVisualsFolder.Parent = workspace

	-- Create sub-folders for organization
	local nodesFolder = Instance.new("Folder")
	nodesFolder.Name = "Nodes"
	nodesFolder.Parent = pathVisualsFolder

	local beamsFolder = Instance.new("Folder")
	beamsFolder.Name = "Beams"
	beamsFolder.Parent = pathVisualsFolder

	local markersFolder = Instance.new("Folder")
	markersFolder.Name = "Markers"
	markersFolder.Parent = pathVisualsFolder

	-- Collect all valid positions first
	local positions = {}
	for i = 1, #frames do
		local f = frames[i]
		local pos = nil
		if f.pos then
			pos = Vector3.new(f.pos.x, f.pos.y, f.pos.z)
		elseif f.r then
			pos = TblToCF(f.r).Position
		end
		if pos then
			table.insert(positions, { pos = pos, time = f.t or i, index = i })
		end
	end

	if #positions < 2 then
		return
	end

	-- Optimization: Limit to ~300 points for mobile performance
	local totalPoints = #positions
	local step = math.max(1, math.floor(totalPoints / 300))
	local filteredPositions = {}
	local lastPos = nil
	local minDistance = 1.5 -- Minimum distance between points

	for i = 1, totalPoints, step do
		local posData = positions[i]
		if not lastPos or (posData.pos - lastPos).Magnitude > minDistance then
			posData.progress = (i - 1) / math.max(1, totalPoints - 1)
			table.insert(filteredPositions, posData)
			lastPos = posData.pos
		end
	end

	-- Always include last position
	local lastPosData = positions[totalPoints]
	lastPosData.progress = 1
	if #filteredPositions > 0 and (filteredPositions[#filteredPositions].pos - lastPosData.pos).Magnitude > 0.1 then
		table.insert(filteredPositions, lastPosData)
	end

	-- Draw nodes and beams
	local nodeInstances = {}
	local prevPart = nil

	for i, posData in ipairs(filteredPositions) do
		local pos = posData.pos
		local progress = posData.progress
		local color = GetGradientColor(progress)

		-- Create node (smaller neon spheres)
		local node = Instance.new("Part")
		node.Name = "PathNode_" .. i
		node.Size = Vector3.new(0.35, 0.35, 0.35)
		node.Shape = Enum.PartType.Ball
		node.Color = color
		node.Material = Enum.Material.Neon
		node.Transparency = 0.2
		node.Anchored = true
		node.CanCollide = false
		node.CanQuery = false
		node.CastShadow = false
		node.Position = pos
		node.Parent = nodesFolder
		table.insert(nodeInstances, node)

		-- Create beam/line to previous node
		if prevPart then
			local distance = (pos - prevPart.Position).Magnitude
			if distance > 0.1 then
				local midpoint = (pos + prevPart.Position) / 2
				local direction = (pos - prevPart.Position).Unit

				local beam = Instance.new("Part")
				beam.Name = "PathBeam_" .. i
				beam.Size = Vector3.new(0.12, 0.12, distance)
				beam.Shape = Enum.PartType.Block
				beam.Color = color:Lerp(GetGradientColor(filteredPositions[i - 1].progress), 0.5)
				beam.Material = Enum.Material.Neon
				beam.Transparency = 0.4
				beam.Anchored = true
				beam.CanCollide = false
				beam.CanQuery = false
				beam.CastShadow = false
				beam.CFrame = CFrame.lookAt(midpoint, pos)
				beam.Parent = beamsFolder
			end
		end

		prevPart = node
	end

	-- ═══════════════════════════════════════════════════════════════════
	-- SPECIAL MARKERS (START & END)
	-- ═══════════════════════════════════════════════════════════════════

	-- START MARKER (Big Green Diamond)
	if #filteredPositions > 0 then
		local startPos = filteredPositions[1].pos

		local startMarker = Instance.new("Part")
		startMarker.Name = "StartMarker"
		startMarker.Size = Vector3.new(1.2, 1.2, 1.2)
		startMarker.Shape = Enum.PartType.Ball
		startMarker.Color = Color3.fromRGB(34, 197, 94) -- Emerald green
		startMarker.Material = Enum.Material.Neon
		startMarker.Transparency = 0
		startMarker.Anchored = true
		startMarker.CanCollide = false
		startMarker.CastShadow = false
		startMarker.Position = startPos + Vector3.new(0, 0.5, 0)
		startMarker.Parent = markersFolder

		-- Add "S" label using BillboardGui
		local startBillboard = Instance.new("BillboardGui")
		startBillboard.Name = "StartLabel"
		startBillboard.Size = UDim2.new(0, 60, 0, 40)
		startBillboard.StudsOffset = Vector3.new(0, 2, 0)
		startBillboard.AlwaysOnTop = true
		startBillboard.Parent = startMarker

		local startText = Instance.new("TextLabel")
		startText.Size = UDim2.new(1, 0, 1, 0)
		startText.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
		startText.BackgroundTransparency = 0.2
		startText.Text = "▶ START"
		startText.TextColor3 = Color3.new(1, 1, 1)
		startText.TextScaled = true
		startText.Font = Enum.Font.GothamBold
		startText.Parent = startBillboard

		local startCorner = Instance.new("UICorner")
		startCorner.CornerRadius = UDim.new(0.3, 0)
		startCorner.Parent = startText

		-- Glow ring effect
		local startRing = Instance.new("Part")
		startRing.Name = "StartRing"
		startRing.Size = Vector3.new(2.5, 0.15, 2.5)
		startRing.Shape = Enum.PartType.Cylinder
		startRing.Color = Color3.fromRGB(34, 197, 94)
		startRing.Material = Enum.Material.Neon
		startRing.Transparency = 0.5
		startRing.Anchored = true
		startRing.CanCollide = false
		startRing.CastShadow = false
		startRing.CFrame = CFrame.new(startPos) * CFrame.Angles(0, 0, math.rad(90))
		startRing.Parent = markersFolder
	end

	-- END MARKER (Big Pink/Red Diamond)
	if #filteredPositions > 1 then
		local endPos = filteredPositions[#filteredPositions].pos

		local endMarker = Instance.new("Part")
		endMarker.Name = "EndMarker"
		endMarker.Size = Vector3.new(1.2, 1.2, 1.2)
		endMarker.Shape = Enum.PartType.Ball
		endMarker.Color = Color3.fromRGB(239, 68, 68) -- Red
		endMarker.Material = Enum.Material.Neon
		endMarker.Transparency = 0
		endMarker.Anchored = true
		endMarker.CanCollide = false
		endMarker.CastShadow = false
		endMarker.Position = endPos + Vector3.new(0, 0.5, 0)
		endMarker.Parent = markersFolder

		-- Add "E" label using BillboardGui
		local endBillboard = Instance.new("BillboardGui")
		endBillboard.Name = "EndLabel"
		endBillboard.Size = UDim2.new(0, 60, 0, 40)
		endBillboard.StudsOffset = Vector3.new(0, 2, 0)
		endBillboard.AlwaysOnTop = true
		endBillboard.Parent = endMarker

		local endText = Instance.new("TextLabel")
		endText.Size = UDim2.new(1, 0, 1, 0)
		endText.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
		endText.BackgroundTransparency = 0.2
		endText.Text = "⏹ END"
		endText.TextColor3 = Color3.new(1, 1, 1)
		endText.TextScaled = true
		endText.Font = Enum.Font.GothamBold
		endText.Parent = endBillboard

		local endCorner = Instance.new("UICorner")
		endCorner.CornerRadius = UDim.new(0.3, 0)
		endCorner.Parent = endText

		-- Glow ring effect
		local endRing = Instance.new("Part")
		endRing.Name = "EndRing"
		endRing.Size = Vector3.new(2.5, 0.15, 2.5)
		endRing.Shape = Enum.PartType.Cylinder
		endRing.Color = Color3.fromRGB(239, 68, 68)
		endRing.Material = Enum.Material.Neon
		endRing.Transparency = 0.5
		endRing.Anchored = true
		endRing.CanCollide = false
		endRing.CastShadow = false
		endRing.CFrame = CFrame.new(endPos) * CFrame.Angles(0, 0, math.rad(90))
		endRing.Parent = markersFolder
	end

	-- ═══════════════════════════════════════════════════════════════════
	-- DIRECTION ARROWS (Every ~20 points)
	-- ═══════════════════════════════════════════════════════════════════
	local arrowStep = math.max(1, math.floor(#filteredPositions / 15))
	for i = arrowStep + 1, #filteredPositions - 1, arrowStep do
		local currPos = filteredPositions[i].pos
		local nextPos = filteredPositions[math.min(i + 1, #filteredPositions)].pos
		local direction = (nextPos - currPos)

		if direction.Magnitude > 0.5 then
			direction = direction.Unit
			local arrowColor = GetGradientColor(filteredPositions[i].progress)

			-- Arrow cone pointing in direction
			local arrow = Instance.new("Part")
			arrow.Name = "Arrow_" .. i
			arrow.Size = Vector3.new(0.5, 0.6, 0.5)
			arrow.Shape = Enum.PartType.Ball -- Using ball as cone approximation
			arrow.Color = arrowColor
			arrow.Material = Enum.Material.Neon
			arrow.Transparency = 0.1
			arrow.Anchored = true
			arrow.CanCollide = false
			arrow.CastShadow = false
			arrow.Position = currPos + Vector3.new(0, 0.3, 0)
			arrow.Parent = markersFolder

			-- Arrow pointing billboard
			local arrowBB = Instance.new("BillboardGui")
			arrowBB.Size = UDim2.new(0, 30, 0, 30)
			arrowBB.StudsOffset = Vector3.new(0, 0.8, 0)
			arrowBB.AlwaysOnTop = true
			arrowBB.Parent = arrow

			local arrowIcon = Instance.new("TextLabel")
			arrowIcon.Size = UDim2.new(1, 0, 1, 0)
			arrowIcon.BackgroundTransparency = 1
			arrowIcon.Text = "➤"
			arrowIcon.TextColor3 = arrowColor
			arrowIcon.TextScaled = true
			arrowIcon.Font = Enum.Font.GothamBold
			arrowIcon.Rotation = math.deg(math.atan2(direction.X, direction.Z))
			arrowIcon.Parent = arrowBB
		end
	end

	-- ═══════════════════════════════════════════════════════════════════
	-- ANIMATION: Pulsing glow effect on markers
	-- ═══════════════════════════════════════════════════════════════════
	local animTime = 0
	pathAnimationConnection = RunService.Heartbeat:Connect(function(dt)
		if not pathVisualsFolder or not pathVisualsFolder.Parent then
			if pathAnimationConnection then
				pathAnimationConnection:Disconnect()
				pathAnimationConnection = nil
			end
			return
		end

		animTime = animTime + dt

		-- Pulse START marker
		local startMarker = markersFolder:FindFirstChild("StartMarker")
		if startMarker then
			local pulse = 0.9 + 0.1 * math.sin(animTime * 3)
			startMarker.Size = Vector3.new(1.2 * pulse, 1.2 * pulse, 1.2 * pulse)
		end

		-- Pulse END marker
		local endMarker = markersFolder:FindFirstChild("EndMarker")
		if endMarker then
			local pulse = 0.9 + 0.1 * math.sin(animTime * 3 + math.pi)
			endMarker.Size = Vector3.new(1.2 * pulse, 1.2 * pulse, 1.2 * pulse)
		end

		-- Rotate rings
		local startRing = markersFolder:FindFirstChild("StartRing")
		if startRing then
			local pos = startRing.Position
			startRing.CFrame = CFrame.new(pos) * CFrame.Angles(0, animTime * 0.5, math.rad(90))
		end

		local endRing = markersFolder:FindFirstChild("EndRing")
		if endRing then
			local pos = endRing.Position
			endRing.CFrame = CFrame.new(pos) * CFrame.Angles(0, -animTime * 0.5, math.rad(90))
		end

		-- Update current position indicator during playback
		if PlaybackState.isPlaying and PlaybackState.frameData then
			local char = GetCharacter()
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				if not currentPositionMarker or not currentPositionMarker.Parent then
					currentPositionMarker = Instance.new("Part")
					currentPositionMarker.Name = "CurrentPosMarker"
					currentPositionMarker.Size = Vector3.new(1, 0.1, 1)
					currentPositionMarker.Shape = Enum.PartType.Cylinder
					currentPositionMarker.Color = Color3.fromRGB(250, 204, 21) -- Gold/Yellow
					currentPositionMarker.Material = Enum.Material.Neon
					currentPositionMarker.Transparency = 0.3
					currentPositionMarker.Anchored = true
					currentPositionMarker.CanCollide = false
					currentPositionMarker.CastShadow = false
					currentPositionMarker.Parent = markersFolder
				end
				local hrpPos = hrp.Position
				local ringSize = 1.5 + 0.3 * math.sin(animTime * 5)
				currentPositionMarker.Size = Vector3.new(ringSize, 0.1, ringSize)
				currentPositionMarker.CFrame = CFrame.new(hrpPos - Vector3.new(0, 2.5, 0))
					* CFrame.Angles(0, 0, math.rad(90))
			end
		elseif currentPositionMarker then
			currentPositionMarker:Destroy()
			currentPositionMarker = nil
		end
	end)

	WindUI:Notify({
		Title = "✨ Path Visuals",
		Content = string.format("Premium path generated! (%d points)", #filteredPositions),
		Duration = 2,
	})
end

-- Play recording (main function)
local function PlayRecording(fileName, force)
	if not fileName or fileName == "No files found" then
		WindUI:Notify({ Title = "Error", Content = "No file selected!", Duration = 2 })
		return
	end

	-- If already playing the same file and not paused, ignore (prevent double play)
	if PlaybackState.isPlaying and PlaybackState.currentFile == fileName and not force then
		-- Already playing, do nothing
		return
	end

	-- Check if this is a cloud recording
	local isCloudRecording = string.sub(fileName, 1, 6) == "CLOUD:"
	local data = nil

	if isCloudRecording then
		-- Load from memory (CloudRecordingData)
		if not CloudRecordingData then
			WindUI:Notify({ Title = "Error", Content = "Cloud recording not loaded!", Duration = 2 })
			return
		end
		data = CloudRecordingData

		-- Simple notification - all data is already loaded
		local frameCount = CloudRecordingData.Frames and #CloudRecordingData.Frames or 0
		WindUI:Notify({
			Title = "☁️ Playing",
			Content = string.format("Starting playback (%d frames)", frameCount),
			Duration = 1.5,
		})
	else
		-- Load from file (original behavior)
		local filePath = MERGER_FOLDER .. "/" .. fileName
		if not isfile or not isfile(filePath) then
			WindUI:Notify({ Title = "Error", Content = "File not found!", Duration = 2 })
			return
		end

		WindUI:Notify({ Title = "Loading", Content = "Preparing " .. fileName .. "...", Duration = 1.5 })
		task.wait(0.1)

		local success, content = pcall(readfile, filePath)
		if not success then
			WindUI:Notify({ Title = "Error", Content = "Failed to read file!", Duration = 2 })
			return
		end

		data = HttpService:JSONDecode(content)
	end

	task.wait(0.1)

	local isResuming = (PlaybackState.currentFile == fileName and not force and PlaybackState.isPaused)

	-- Load file data if different file or forced
	if PlaybackState.currentFile ~= fileName or force or not PlaybackState.frameData then
		StopPlayback()

		local framesToPlay = data.Frames or data

		-- Detect mode: Flexible (has vel/pos) or Standard (has r/j)
		local isFlexible = (data.Mode == "Flexible") or (framesToPlay[1] and framesToPlay[1].vel ~= nil)

		-- LIVE SMOOTHING: Apply Gaussian smoothing on load (mobile default ON)
		-- LIVE SMOOTHING: Apply Gaussian smoothing on load (mobile default ON)
		-- SKIP for large files (> 5000 frames) to prevent timeout/lag on mobile
		if SMOOTH_SETTINGS.LiveSmoothingEnabled and isFlexible and #framesToPlay > 3 and #framesToPlay <= 5000 then
			WindUI:Notify({ Title = "Smoothing", Content = "Applying auto-smooth...", Duration = 1 })
			task.wait()
			framesToPlay = GetSmoothedFrames(framesToPlay, SMOOTH_SETTINGS.LiveSmoothingStrength, isFlexible)
		end

		-- CROSS-RIG SUPPORT: Preserve metadata from recording alongside frames
		PlaybackState.frameData = framesToPlay
		PlaybackState.frameData.Mode = data.Mode
		PlaybackState.frameData.RigType = data.RigType -- Cross-rig: R6 or R15
		PlaybackState.frameData.RootHeight = data.RootHeight -- Cross-rig: ground height at recording
		PlaybackState.frameData.HipHeight = data.HipHeight -- Recorded HipHeight
		PlaybackState.frameData.FPS = data.FPS

		PlaybackState.currentFile = fileName
		PlaybackState.currentTime = 0
		PlaybackState.lastFrameIndex = 1

		-- Detect mode: Flexible (has vel/pos) or Standard (has r/j)
		PlaybackState.isFlexible = (data.Mode == "Flexible") or (framesToPlay[1] and framesToPlay[1].vel ~= nil)

		if #PlaybackState.frameData > 0 then
			PlaybackState.totalDuration = PlaybackState.frameData[#PlaybackState.frameData].t or 0
		end

		-- Draw path if enabled
		if isPathVisualsEnabled then
			DrawPath(PlaybackState.frameData)
		end
	elseif PlaybackState.currentTime >= (PlaybackState.totalDuration - 0.1) then
		-- Reset if at end (replay)
		PlaybackState.currentTime = 0
	end

	if not PlaybackState.frameData or #PlaybackState.frameData < 2 then
		WindUI:Notify({ Title = "Error", Content = "Invalid recording data!", Duration = 2 })
		return
	end

	local char = GetCharacter()
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animate = char and char:FindFirstChild("Animate")

	if not hrp or not hum then
		WindUI:Notify({ Title = "Error", Content = "Character not found!", Duration = 2 })
		return
	end

	-- NOTE: We don't return early for resume anymore
	-- Resume will also do smart start and travel phase (SAME AS PC)

	-- Cache joints for Standard mode
	PlaybackState.jointMap = GetJoints(char)

	-- SMART START / SMART RESUME: Always find nearest position (SAME AS PC)
	-- This ensures play from nearest path point after stop
	WindUI:Notify({ Title = "Finding Position", Content = "Locating nearest path point...", Duration = 1 })

	local bestT, minDist = PlaybackState.currentTime, math.huge
	local rPos = hrp.Position

	-- Optimization: Step by frames to save performance on huge files
	local step = math.max(1, math.floor(#PlaybackState.frameData / 500))

	for i = 1, #PlaybackState.frameData, step do
		local f = PlaybackState.frameData[i]
		local pos
		if f.pos then
			pos = Vector3.new(f.pos.x, f.pos.y, f.pos.z)
		elseif f.r then
			pos = TblToCF(f.r).Position
		end

		if pos then
			local dist = (rPos - pos).Magnitude
			if dist < minDist then
				minDist = dist
				bestT = f.t
			end
		end
	end

	-- Also check the last frame explicitly
	local lastF = PlaybackState.frameData[#PlaybackState.frameData]
	local lastPos
	if lastF.pos then
		lastPos = Vector3.new(lastF.pos.x, lastF.pos.y, lastF.pos.z)
	elseif lastF.r then
		lastPos = TblToCF(lastF.r).Position
	end
	if lastPos then
		local dist = (rPos - lastPos).Magnitude
		if dist < minDist then
			minDist = dist
			bestT = lastF.t
		end
	end

	-- DISTANCE VALIDATION (Prevent playing on wrong map)
	local MAP_DISTANCE_THRESHOLD = 500
	if minDist > MAP_DISTANCE_THRESHOLD then
		WindUI:Notify({
			Title = "Wrong Map Detected",
			Content = string.format("Path is too far (%.0f studs)!", minDist),
			Duration = 4,
		})
		return
	end

	-- Smart position logic (SAME AS PC)
	-- If the nearest point is within the last 2 seconds, force restart from 0
	if bestT >= (PlaybackState.totalDuration - 2.0) then
		PlaybackState.currentTime = 0
		-- Snap to Start: If nearest point is within first 1 second, start from 0
	elseif bestT < 1.0 then
		PlaybackState.currentTime = 0
		-- Otherwise, jump to nearest point if close enough to path
	elseif minDist < 500 then
		PlaybackState.currentTime = bestT
		WindUI:Notify({
			Title = "Smart Start",
			Content = string.format("Starting from %.1fs (%.0f studs away)", bestT, minDist),
			Duration = 2,
		})
	else
		PlaybackState.currentTime = 0
	end

	-- Disconnect old connection if exists (important for resume)
	if PlaybackState.connection then
		PlaybackState.connection:Disconnect()
		PlaybackState.connection = nil
	end

	-- ═══════════════════════════════════════════════════════════════════
	-- TRAVEL PHASE: Walk to target position before playback (SAME AS PC)
	-- ═══════════════════════════════════════════════════════════════════
	local startFrame = PlaybackState.frameData[1]
	local targetPos

	-- Find target position based on currentPlaybackTime
	if PlaybackState.currentTime > 0 then
		for i = 1, #PlaybackState.frameData do
			if PlaybackState.frameData[i].t >= PlaybackState.currentTime then
				local f = PlaybackState.frameData[i]
				if f.pos then
					targetPos = Vector3.new(f.pos.x, f.pos.y, f.pos.z)
				elseif f.r then
					targetPos = TblToCF(f.r).Position
				end
				break
			end
		end
	else
		-- Start from beginning
		if startFrame.pos then
			targetPos = Vector3.new(startFrame.pos.x, startFrame.pos.y, startFrame.pos.z)
		elseif startFrame.r then
			targetPos = TblToCF(startFrame.r).Position
		end
	end

	-- Travel to target if far away
	if targetPos then
		-- Use horizontal distance to prevent getting stuck due to height differences
		local flatPos = hrp.Position * Vector3.new(1, 0, 1)
		local flatTarget = targetPos * Vector3.new(1, 0, 1)
		local dist = (flatPos - flatTarget).Magnitude

		if dist > 3 then
			-- Enable animate for walking
			hrp.Anchored = false
			if animate then
				animate.Disabled = false
			end
			hum.AutoRotate = true

			WindUI:Notify({
				Title = "Traveling",
				Content = string.format("Walking to path (%.0f studs)...", dist),
				Duration = 3,
			})

			hum:MoveTo(targetPos)

			-- Timeout safety
			local moveStart = os.clock()
			local isWalking = true

			while isWalking do
				local currFlat = hrp.Position * Vector3.new(1, 0, 1)
				local d = (currFlat - flatTarget).Magnitude

				-- Close enough, start playback
				if d <= 2 then
					break
				end

				-- If stuck for 5 seconds but close (within 10 studs), just snap
				if os.clock() - moveStart > 5 and d < 10 then
					hrp.CFrame = CFrame.new(targetPos) * hrp.CFrame.Rotation
					break
				end

				-- Timeout after 10 seconds - snap anyway
				if os.clock() - moveStart > 10 then
					hrp.CFrame = CFrame.new(targetPos) * hrp.CFrame.Rotation
					WindUI:Notify({ Title = "Timeout", Content = "Teleported to path", Duration = 2 })
					break
				end

				-- Refresh MoveTo every second
				if math.floor(os.clock() - moveStart) % 1 < 0.1 then
					hum:MoveTo(targetPos)
				end

				task.wait(0.1)
			end

			-- Stop walking
			hum:MoveTo(hrp.Position)
		end
	end

	-- ═══════════════════════════════════════════════════════════════════
	-- PLAYBACK PHASE
	-- ═══════════════════════════════════════════════════════════════════
	PlaybackState.isPlaying = true
	PlaybackState.isPaused = false
	PlaybackState.lastPlaybackTime = PlaybackState.currentTime

	-- Variables for state tracking (same as PC)
	local lastAirState = nil
	local frameCounter = 0

	-- Create attachment for AlignOrientation (same as PC)
	local cachedAtt = hrp:FindFirstChild("PlaybackAtt") or Instance.new("Attachment", hrp)
	cachedAtt.Name = "PlaybackAtt"
	local cachedAO = nil

	WindUI:Notify({ Title = "Playing", Content = "Now playing: " .. fileName, Duration = 2 })

	-- Setup based on mode
	if PlaybackState.isFlexible then
		-- FLEXIBLE MODE (same as PC StarshipCore.lua)
		hrp.Anchored = false
		-- CARRY PRESERVATION: Skip Animate restart when ForceCarryMode is ON
		if animate and not _G.StarshipForceCarryMode then
			animate.Disabled = true
			task.wait()
			animate.Disabled = false
		end
		-- Don't set AutoRotate here, handle it per-frame like PC
		hum.AutoRotate = false

		-- ========================================
		-- CROSS-RIG HEIGHT OFFSET SYSTEM
		-- Handles: R6→R15, R15→R6, and same-rig playback
		-- ========================================
		local playbackIsR6 = (char:FindFirstChild("Torso") ~= nil)
		local playbackRigType = playbackIsR6 and "R6" or "R15"

		-- Auto-detect RigType from recording data (for old recordings without metadata)
		local recordedRigType = PlaybackState.frameData.RigType
		if not recordedRigType then
			-- Try to detect from joint names in Strict mode recordings
			local firstFrame = PlaybackState.frameData[1]
			if firstFrame and firstFrame.j then
				-- Check for R6-specific joints
				if firstFrame.j["Left Leg"] or firstFrame.j["Right Leg"] or firstFrame.j["Torso"] then
					recordedRigType = "R6"
					-- Check for R15-specific joints
				elseif firstFrame.j["LeftUpperLeg"] or firstFrame.j["RightUpperLeg"] or firstFrame.j["UpperTorso"] then
					recordedRigType = "R15"
				else
					recordedRigType = "R15" -- Default fallback
				end
			else
				-- Flexible mode: Try to detect from recorded HipHeight
				-- R6 HipHeight is typically 0, R15 is ~2.0
				if firstFrame and firstFrame.hh ~= nil then
					if firstFrame.hh < 0.5 then
						recordedRigType = "R6"
					else
						recordedRigType = "R15"
					end
				else
					-- Default to R15 (most common)
					recordedRigType = "R15"
				end
			end
		end
		local recordedRootHeight = PlaybackState.frameData.RootHeight or 0

		-- Calculate PLAYBACK avatar's root height
		local playbackRootHeight = 0
		if playbackIsR6 then
			local leftLeg = char:FindFirstChild("Left Leg")
			local rightLeg = char:FindFirstChild("Right Leg")
			local torso = char:FindFirstChild("Torso")
			local legLength = (leftLeg and leftLeg.Size.Y) or (rightLeg and rightLeg.Size.Y) or 2
			local torsoHalfHeight = (torso and torso.Size.Y / 2) or 1
			playbackRootHeight = legLength + torsoHalfHeight
		else
			-- R15: HipHeight + RootPart half height
			playbackRootHeight = hum.HipHeight + (hrp.Size.Y / 2)
		end

		-- Calculate Cross-Rig Height Offset based on HipHeight difference
		-- The key insight: R15 HipHeight (~2.0) creates a "floating" effect that R6 (HipHeight=0) doesn't have
		local crossRigHeightOffset = 0

		-- Get recorded HipHeight (either from metadata or from first frame)
		local recordedHipHeight = PlaybackState.frameData.HipHeight
		if not recordedHipHeight then
			-- Try to get from first frame
			local firstFrame = PlaybackState.frameData[1]
			if firstFrame and firstFrame.hh then
				recordedHipHeight = firstFrame.hh
			else
				-- Estimate based on detected rig type
				recordedHipHeight = (recordedRigType == "R15") and 2.0 or 0
			end
		end

		-- Get playback HipHeight
		local playbackHipHeight = hum.HipHeight or 0

		-- Calculate offset based on HipHeight difference
		-- If recorded with higher HipHeight and playing with lower → need to LOWER position
		-- If recorded with lower HipHeight and playing with higher → need to RAISE position
		crossRigHeightOffset = playbackHipHeight - recordedHipHeight

		-- Toast notification will be shown below, no need for print

		-- Log Cross-Rig info (once)
		if recordedRigType ~= playbackRigType then
			WindUI:Notify({
				Title = "Cross-Rig Playback",
				Content = string.format(
					"Recorded: %s → Playing: %s (Offset: %.2f)",
					recordedRigType,
					playbackRigType,
					crossRigHeightOffset
				),
				Duration = 3,
			})
		end

		PlaybackState.connection = RunService.Stepped:Connect(function(_, dt)
			frameCounter = frameCounter + 1
			if not PlaybackState.isPlaying or PlaybackState.isPaused then
				return
			end

			-- Ensure speed is always a number
			local speed = tonumber(PlaybackState.speed) or 1
			PlaybackState.speed = speed -- Update back to ensure it's number

			PlaybackState.currentTime = PlaybackState.currentTime + (dt * speed)

			-- Check end
			if PlaybackState.currentTime >= PlaybackState.totalDuration then
				if PlaybackState.isRespawnOnEnd then
					local savedFile = PlaybackState.currentFile
					local savedLoop = PlaybackState.isLooping
					StopPlayback()
					WindUI:Notify({ Title = "Respawn", Content = "Respawning in 5 seconds...", Duration = 5 })
					task.wait(5)
					local hum = GetHumanoid()
					if hum then
						hum.Health = 0
					end
					if savedLoop then
						task.spawn(function()
							LocalPlayer.CharacterAdded:Wait()
							WindUI:Notify({
								Title = "Loop",
								Content = "Restarting playback in 5 seconds...",
								Duration = 5,
							})
							task.wait(5)
							if savedFile then
								PlayRecording(savedFile, true)
							end
						end)
					end
					return
				elseif PlaybackState.isLooping then
					PlaybackState.currentTime = 0
					lastAirState = nil -- Reset on loop
				else
					StopPlayback()
					WindUI:Notify({ Title = "Finished", Content = "Playback completed!", Duration = 2 })
					return
				end
			end

			-- DETECT TIME JUMP (slider seeking) - skip blending if user jumped to different time
			local expectedDelta = dt * speed
			local actualDelta = math.abs(PlaybackState.currentTime - PlaybackState.lastPlaybackTime)
			local isTimeJump = actualDelta > (expectedDelta * 3 + 0.1)
			PlaybackState.lastPlaybackTime = PlaybackState.currentTime

			-- Find frames (optimized with binary search + caching)
			local frameIdx =
				FindFrameIndex(PlaybackState.frameData, PlaybackState.currentTime, PlaybackState.lastFrameIndex)
			PlaybackState.lastFrameIndex = frameIdx
			local fA, fB = PlaybackState.frameData[frameIdx], PlaybackState.frameData[frameIdx + 1]

			if fA and fB then
				local deltaT = fB.t - fA.t
				local alpha = 0
				if deltaT > 0.0001 then
					alpha = (PlaybackState.currentTime - fA.t) / deltaT
				end

				-- Tool Replication
				UpdateTool(GetCharacter(), fA.tool)

				-- 1. Check current state for special handling
				local isCurrentlyClimbing = false
				local isCurrentlySwimming = false
				local stateName = nil
				if fA.st then
					stateName = string.match(fA.st, "Enum%.HumanoidStateType%.(%w+)")
					isCurrentlyClimbing = (stateName == "Climbing")
					isCurrentlySwimming = (stateName == "Swimming")
				end

				if isCurrentlyClimbing or isCurrentlySwimming then
					-- CLIMBING/SWIMMING: Use recorded velocity and simulate input for natural animation
					local vel = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
						:Lerp(Vector3.new(fB.vel.x, fB.vel.y, fB.vel.z), alpha)
					vel = vel * speed

					-- FORCE climbing/swimming state FIRST (before any movement)
					hum:ChangeState(
						isCurrentlyClimbing and Enum.HumanoidStateType.Climbing or Enum.HumanoidStateType.Swimming
					)

					-- Apply movement input for animation
					if fA.md then
						local moveDir = Vector3.new(fA.md.x, fA.md.y, fA.md.z)
						hum:Move(moveDir)

						-- CRITICAL: Control climbing/swimming animation speed directly via AnimationTrack
						local animator = hum:FindFirstChildOfClass("Animator")
						if animator then
							local playingTracks = animator:GetPlayingAnimationTracks()
							for _, track in ipairs(playingTracks) do
								local animName = track.Animation and track.Animation.Name or ""
								local animNameLower = string.lower(animName)
								if animNameLower:find("climb") or animNameLower:find("swim") or track.IsPlaying then
									local baseSpeed = isCurrentlyClimbing and 12 or 8
									local targetSpeed = vel.Magnitude / baseSpeed * speed
									targetSpeed = math.max(0.5, targetSpeed)
									track:AdjustSpeed(targetSpeed)
								end
							end
						end
					elseif vel.Magnitude > 0.1 then
						-- Fallback: calculate movement direction from velocity
						local worldMoveDir = vel.Unit
						local charCF = hrp.CFrame
						local localMoveDir = charCF:VectorToObjectSpace(worldMoveDir)
						local moveScale = vel.Magnitude / 16 * speed * 25.0
						local moveVector = Vector3.new(localMoveDir.X, localMoveDir.Y, localMoveDir.Z) * moveScale
						hum:Move(moveVector)
					else
						hum:Move(Vector3.new(0, 0, 0))
					end

					-- Set actual velocity for physics movement (exact recorded velocity)
					hrp.AssemblyLinearVelocity = vel

					-- Position correction - MORE STRICT for climbing (0.5 blend) to stay on thin surfaces
					if fA.pos and fB.pos then
						local targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z)
							:Lerp(Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha)
						local targetYaw = fA.rot or 0
						local currentPos = hrp.Position
						-- Use stricter blend for climbing (0.5) vs swimming (0.3)
						local positionBlend = isCurrentlyClimbing and 0.5 or 0.3
						local smoothPos = currentPos:Lerp(targetPos, positionBlend)
						hrp.CFrame = CFrame.new(smoothPos) * CFrame.Angles(0, math.rad(targetYaw), 0)
					end

					-- FORCE maintain climbing/swimming state again at end
					hum:ChangeState(
						isCurrentlyClimbing and Enum.HumanoidStateType.Climbing or Enum.HumanoidStateType.Swimming
					)

					-- Update hip height for swimming
					if isCurrentlySwimming and fA.hh then
						hum.HipHeight = fA.hh
					end
				else
					-- NORMAL MOVEMENT (Running, Jumping, Freefall, etc.) - Same as PC StarshipCore.lua

					-- 2. Apply Velocity / Position
					if fA.vel and fB.vel then
						local vel = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
							:Lerp(Vector3.new(fB.vel.x, fB.vel.y, fB.vel.z), alpha)
						vel = vel * speed

						-- IMPROVED: Higher velocity blending for smoother transitions (same as PC)
						local currentVel = hrp.AssemblyLinearVelocity
						local baseBlend = 0.85 -- Increased from 0.6 for smoother transitions
						local blendFactor = math.clamp(baseBlend * speed, 0.5, 0.98)

						-- Check if in air state - use position-based for smooth jump like recording
						local isInAir = (stateName == "Jumping" or stateName == "Freefall")

						-- IMPROVED: Use Catmull-Rom spline for smoother interpolation
						local smoothPos, smoothVel = SmoothInterpolateFrames(PlaybackState.frameData, frameIdx, alpha)

						-- CROSS-RIG HEIGHT OFFSET CORRECTION: Apply height adjustment for cross-rig playback
						if crossRigHeightOffset ~= 0 and smoothPos then
							smoothPos = Vector3.new(smoothPos.X, smoothPos.Y + crossRigHeightOffset, smoothPos.Z)
						end

						if isInAir and smoothPos then
							-- SAME AS PC (StarshipCore.lua): Follow recorded position for smooth jump arc
							local targetPos = smoothPos

							-- On time jump or high speed, snap directly to target position
							if isTimeJump or speed >= 2 then
								hrp.CFrame = CFrame.new(smoothPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
								hrp.AssemblyLinearVelocity = vel
							else
								-- Smoothly move to target position (SAME AS PC)
								local currentPos = hrp.Position
								local posBlend = math.clamp(0.5 * speed, 0.3, 0.9)
								local newPos = currentPos:Lerp(targetPos, posBlend)
								hrp.CFrame = CFrame.new(newPos) * hrp.CFrame.Rotation

								-- Use RECORDED velocity for animation (SAME AS PC)
								local recordedVelY = fA.vel and fA.vel.y or 0
								local horizVel = (targetPos - currentPos) * 10 * speed
								hrp.AssemblyLinearVelocity = Vector3.new(horizVel.X, recordedVelY * speed, horizVel.Z)
							end
						else
							-- IMPROVED: Position-Based Playback mode (smoother ground movement)
							if SMOOTH_SETTINGS.PositionBasedEnabled and smoothPos then
								-- Position-based: Use VELOCITY for animation, with STRONG position correction
								local currentPos = hrp.Position
								local posDiff = smoothPos - currentPos
								local distance = posDiff.Magnitude

								-- Calculate target velocity that will move us toward the path
								local correctionStrength = math.clamp(distance * 8, 0, 50)
								local correctionVel = distance > 0.01 and (posDiff.Unit * correctionStrength)
									or Vector3.new(0, 0, 0)

								-- Blend with recorded velocity for smooth acceleration
								local targetVel = smoothVel or vel
								local finalVel = targetVel + correctionVel

								-- Apply velocity (allows physics and animations to work properly)
								hrp.AssemblyLinearVelocity = currentVel:Lerp(finalVel, 0.85)

								-- Only snap position if WAY off (fallback safety)
								if distance > 8 then
									local snapPos = currentPos:Lerp(smoothPos, 0.5)
									hrp.CFrame = CFrame.new(snapPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
								end

								-- CRITICAL: Trigger walk/run animation using h:Move()
								if fA.md then
									local moveDir = Vector3.new(fA.md.x, fA.md.y, fA.md.z)
									if moveDir.Magnitude > 0.01 then
										hum:Move(moveDir, false)
									else
										hum:Move(Vector3.new(0, 0, 0))
									end
								elseif finalVel.Magnitude > 0.5 then
									local flatVel = Vector3.new(finalVel.X, 0, finalVel.Z)
									if flatVel.Magnitude > 0.1 then
										hum:Move(flatVel.Unit, false)
									end
								else
									hum:Move(Vector3.new(0, 0, 0))
								end
							else
								-- Velocity-based fallback (original approach)
								if isTimeJump or speed >= 2 then
									hrp.AssemblyLinearVelocity = smoothVel or vel
									if smoothPos then
										hrp.CFrame = CFrame.new(smoothPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
									elseif fA.pos then
										local targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z)
											:Lerp(Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha)
										hrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
									end
								else
									local targetVel = smoothVel or vel
									hrp.AssemblyLinearVelocity = currentVel:Lerp(targetVel, blendFactor)

									-- Subtle position correction to prevent drift
									if smoothPos then
										local posDiff = (smoothPos - hrp.Position)
										local posCorrection = posDiff * 0.2
										hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + posCorrection
									end

									-- Trigger walk/run animation
									if fA.md then
										local moveDir = Vector3.new(fA.md.x, fA.md.y, fA.md.z)
										if moveDir.Magnitude > 0.01 then
											hum:Move(moveDir, false)
										end
									elseif targetVel.Magnitude > 0.5 then
										local flatVel = Vector3.new(targetVel.X, 0, targetVel.Z)
										if flatVel.Magnitude > 0.1 then
											hum:Move(flatVel.Unit, false)
										end
									end
								end
							end
						end
					end

					-- 3. Apply Move Direction & Rotation (SAME AS PC)
					-- Check if climbing/swimming (special handling)
					local isClimbingOrSwimming = (stateName == "Climbing" or stateName == "Swimming")

					if isClimbingOrSwimming then
						-- Climbing/Swimming: Rotation already handled in position section
						if cachedAO then
							cachedAO.Enabled = false
						end
						hum.AutoRotate = false
					else
						-- ALL OTHER STATES (including air): Use recorded rotation via AlignOrientation
						-- This ensures rotation matches recording exactly (same as PC)
						hum.AutoRotate = false -- Disable default to prevent fighting

						-- Create/reuse AlignOrientation for smooth rotation
						if not cachedAO or not cachedAO.Parent then
							cachedAO = Instance.new("AlignOrientation", hrp)
							cachedAO.Name = "PlaybackAO"
							cachedAO.Mode = Enum.OrientationAlignmentMode.OneAttachment
							cachedAO.Attachment0 = cachedAtt
							cachedAO.RigidityEnabled = false
							cachedAO.MaxTorque = 1000000 -- Same as PC
						end
						cachedAO.Enabled = true
						cachedAO.Responsiveness = 80 -- Same as PC (80 for normal playback)

						-- Determine look direction
						local lookDir = Vector3.new(0, 0, -1) -- Default

						-- Use recorded charLook if available (shiftlock direction)
						if fA.charLook and fB.charLook then
							local lookA = Vector3.new(fA.charLook.x, 0, fA.charLook.z)
							local lookB = Vector3.new(fB.charLook.x, 0, fB.charLook.z)
							if lookA.Magnitude > 0.01 and lookB.Magnitude > 0.01 then
								lookDir = lookA.Unit:Lerp(lookB.Unit, alpha)
							elseif lookA.Magnitude > 0.01 then
								lookDir = lookA.Unit
							end
						elseif fA.charLook then
							local look = Vector3.new(fA.charLook.x, 0, fA.charLook.z)
							if look.Magnitude > 0.01 then
								lookDir = look.Unit
							end
						else
							-- Fallback: Calculate look direction from velocity (movement direction)
							if fA.vel and fB.vel then
								local v = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
									:Lerp(Vector3.new(fB.vel.x, fB.vel.y, fB.vel.z), alpha)
								if v.Magnitude > 0.1 then
									lookDir = Vector3.new(v.X, 0, v.Z)
									if lookDir.Magnitude > 0.01 then
										lookDir = lookDir.Unit
									end
								end
							end
						end

						-- Ensure lookDir is valid
						if lookDir.Magnitude < 0.001 then
							lookDir = Vector3.new(0, 0, -1)
						end

						-- MOONWALK: Invert look direction so character faces opposite of movement
						if PlaybackState.isMoonwalk then
							lookDir = -lookDir
						end

						-- Apply rotation via AlignOrientation
						cachedAO.CFrame = CFrame.lookAt(Vector3.zero, lookDir)

						-- Trigger animation based on velocity
						if fA.vel then
							local velDir = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
							if velDir.Magnitude > 0.1 then
								hum:Move(velDir.Unit)
							end
						end
					end

					-- 4. Jump & State Replication (SAME AS PC)
					if fA.jmp and not hum.Jump then
						hum.Jump = true
					end

					if stateName then
						local stateEnum = Enum.HumanoidStateType[stateName]
						local currentState = hum:GetState()

						-- NORMAL PLAYBACK: Use velocity Y to determine correct air state
						local isAirState = (
							stateEnum == Enum.HumanoidStateType.Jumping
							or stateEnum == Enum.HumanoidStateType.Freefall
						)

						if isAirState then
							-- PRIORITY: Use RECORDED STATE directly, not velocity
							-- If recording says "Jumping", use Jumping. If "Freefall", use Freefall.
							-- This is more accurate than velocity-based detection
							local isJumpState = (stateEnum == Enum.HumanoidStateType.Jumping)
							local targetState = isJumpState and "jump" or "fall"

							-- FALLBACK: Use velocity only if state seems wrong (velY > 15 but state says fall)
							local velY = fA.vel and fA.vel.y or 0
							if velY > 15 and not isJumpState then
								targetState = "jump" -- Override to jump if velocity is strongly upward
							end

							-- Change state if different from last
							if targetState ~= lastAirState then
								lastAirState = targetState
								if targetState == "jump" then
									-- Trigger jump animation
									if hum:GetState() ~= Enum.HumanoidStateType.Jumping then
										hum:ChangeState(Enum.HumanoidStateType.Jumping)
									end
									-- R6 SPECIAL: Also set hum.Jump for proper animation
									if playbackIsR6 then
										hum.Jump = true
									end
								else
									-- Trigger freefall animation
									if hum:GetState() ~= Enum.HumanoidStateType.Freefall then
										hum:ChangeState(Enum.HumanoidStateType.Freefall)
									end
								end
							end
						elseif stateEnum == Enum.HumanoidStateType.Landed then
							-- Reset lastAirState to allow next jump (important for spam jumps)
							lastAirState = nil
							if currentState ~= Enum.HumanoidStateType.Landed then
								hum:ChangeState(Enum.HumanoidStateType.Landed)
							end
						elseif stateEnum == Enum.HumanoidStateType.Running then
							lastAirState = nil
							-- Running: Prevent unwanted freefall on small bumps
							if currentState == Enum.HumanoidStateType.Freefall then
								-- Check if we should be running instead
								if fA.vel and math.abs(fA.vel.y) < -999 then -- DISABLED: Let recorded state be respected
									hum:ChangeState(Enum.HumanoidStateType.Running)
								end
							elseif currentState ~= Enum.HumanoidStateType.Running then
								hum:ChangeState(Enum.HumanoidStateType.Running)
							end
						elseif
							stateEnum == Enum.HumanoidStateType.Climbing
							and currentState ~= Enum.HumanoidStateType.Climbing
						then
							-- Climbing: Force state and ensure proper velocity for animation
							hum:ChangeState(Enum.HumanoidStateType.Climbing)
						elseif
							stateEnum == Enum.HumanoidStateType.Climbing
							and currentState == Enum.HumanoidStateType.Climbing
						then
							-- Maintain climbing: Apply full recorded velocity (not dampened)
							if fA.vel then
								local climbVel = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
								if speed ~= 1.0 then
									climbVel = climbVel * speed
								end
								hrp.AssemblyLinearVelocity = climbVel
							end
						elseif
							stateEnum == Enum.HumanoidStateType.Swimming
							and currentState ~= Enum.HumanoidStateType.Swimming
						then
							-- Swimming: Force state and update hip height
							hum:ChangeState(Enum.HumanoidStateType.Swimming)
							if fA.hh then
								hum.HipHeight = fA.hh
							end
						else
							-- Other states
							pcall(function()
								hum:ChangeState(stateEnum)
							end)
						end
					end

					-- 5. Drift Correction (Subtle) - Skip during climbing/swimming/air states/carrying
					local isInAirState = (stateName == "Jumping" or stateName == "Freefall")
					local skipDriftCorrection = (stateName == "Climbing" or stateName == "Swimming" or isInAirState)

					-- CARRY PRESERVATION: Skip drift correction to reduce jitter for carried player
					if _G.StarshipForceCarryMode then
						skipDriftCorrection = true
					end

					-- IMPROVED: Smooth Drift Correction (same as PC)
					if not skipDriftCorrection then
						-- Use Catmull-Rom interpolated position for smoother target
						local smoothTargetPos, _ = SmoothInterpolateFrames(PlaybackState.frameData, frameIdx, alpha)
						local targetPos = smoothTargetPos
						if not targetPos and fA.pos and fB.pos then
							targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z)
								:Lerp(Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha)
						end

						if targetPos then
							local dist = (hrp.Position - targetPos).Magnitude

							-- Check if actually moving (collision detection)
							local actualVel = hrp.AssemblyLinearVelocity.Magnitude
							local expectedVel = fA.vel and Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z).Magnitude or 0
							local isStuck = (expectedVel > 3 and actualVel < 1)

							if dist > 10 then
								-- IMPROVED: Smooth lerp instead of instant snap
								local smoothSnapPos = hrp.Position:Lerp(targetPos, 0.4)
								hrp.CFrame = CFrame.new(smoothSnapPos) * hrp.CFrame.Rotation
							elseif dist > 3 and not isStuck then
								-- Medium drift: Stronger velocity correction
								local dir = (targetPos - hrp.Position).Unit
								local correction = dir * (dist * 1.5)
								hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + correction
							elseif dist > 0.5 and not isStuck then
								-- Small drift: Gentle nudge
								local dir = (targetPos - hrp.Position).Unit
								local correction = dir * (dist * 0.8)
								hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + correction
							end
							-- Under 0.5 studs: no correction needed
						end
					end
				end
			end
		end)
	else
		-- STANDARD MODE
		hrp.Anchored = false

		-- Create constraints for smooth movement
		local att = hrp:FindFirstChild("PlaybackAtt") or Instance.new("Attachment", hrp)
		att.Name = "PlaybackAtt"

		local ap = hrp:FindFirstChild("PlaybackAP") or Instance.new("AlignPosition", hrp)
		ap.Name = "PlaybackAP"
		ap.Mode = Enum.PositionAlignmentMode.OneAttachment
		ap.Attachment0 = att
		ap.MaxForce = math.huge
		ap.MaxVelocity = math.huge
		ap.Responsiveness = PlaybackState.nativeAnim and 80 or 200
		ap.RigidityEnabled = not PlaybackState.nativeAnim

		local ao = hrp:FindFirstChild("PlaybackAO") or Instance.new("AlignOrientation", hrp)
		ao.Name = "PlaybackAO"
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.Attachment0 = att
		ao.MaxTorque = math.huge
		ao.MaxAngularVelocity = math.huge
		ao.Responsiveness = PlaybackState.nativeAnim and 80 or 200
		ao.RigidityEnabled = not PlaybackState.nativeAnim

		-- Disable animate for non-native mode (but NOT if ForceCarryMode is ON)
		if animate and not PlaybackState.nativeAnim and not _G.StarshipForceCarryMode then
			animate.Disabled = true
		end

		PlaybackState.connection = RunService.Stepped:Connect(function(_, dt)
			if not PlaybackState.isPlaying or PlaybackState.isPaused then
				return
			end

			-- Ensure speed is always a number
			local speed = tonumber(PlaybackState.speed) or 1
			PlaybackState.speed = speed

			PlaybackState.currentTime = PlaybackState.currentTime + (dt * speed)

			-- Check end
			if PlaybackState.currentTime >= PlaybackState.totalDuration then
				if PlaybackState.isRespawnOnEnd then
					local savedFile = PlaybackState.currentFile
					local savedLoop = PlaybackState.isLooping
					StopPlayback()
					WindUI:Notify({ Title = "Respawn", Content = "Respawning in 5 seconds...", Duration = 5 })
					task.wait(5)
					local hum = GetHumanoid()
					if hum then
						hum.Health = 0
					end
					if savedLoop then
						task.spawn(function()
							LocalPlayer.CharacterAdded:Wait()
							WindUI:Notify({
								Title = "Loop",
								Content = "Restarting playback in 5 seconds...",
								Duration = 5,
							})
							task.wait(5)
							if savedFile then
								PlayRecording(savedFile, true)
							end
						end)
					end
					return
				elseif PlaybackState.isLooping then
					PlaybackState.currentTime = 0
				else
					StopPlayback()
					WindUI:Notify({ Title = "Finished", Content = "Playback completed!", Duration = 2 })
					return
				end
			end

			-- Find frames
			local frameIdx =
				FindFrameIndex(PlaybackState.frameData, PlaybackState.currentTime, PlaybackState.lastFrameIndex)
			PlaybackState.lastFrameIndex = frameIdx
			local fA, fB = PlaybackState.frameData[frameIdx], PlaybackState.frameData[frameIdx + 1]

			if fA and fB then
				local deltaT = fB.t - fA.t
				local alpha = 0
				if deltaT > 0.0001 then
					alpha = (PlaybackState.currentTime - fA.t) / deltaT
				end

				-- Tool Replication
				UpdateTool(GetCharacter(), fA.tool)

				-- Interpolate CFrame
				if fA.r and fB.r then
					local targetCF = TblToCF(fA.r):Lerp(TblToCF(fB.r), alpha)
					ap.Position = targetCF.Position

					-- MOONWALK: Rotate 180 degrees so character faces opposite direction
					if PlaybackState.isMoonwalk then
						ao.CFrame = targetCF * CFrame.Angles(0, math.pi, 0)
					else
						ao.CFrame = targetCF
					end

					-- Native anim velocity
					if PlaybackState.nativeAnim then
						local nextPos = TblToCF(fB.r).Position
						local prevPos = TblToCF(fA.r).Position
						local velocity = (nextPos - prevPos) / deltaT * speed

						local currentVel = hrp.AssemblyLinearVelocity
						local blendFactor = math.clamp(0.5 * speed, 0.3, 0.95)
						hrp.AssemblyLinearVelocity = currentVel:Lerp(velocity, blendFactor)
					end
				end

				-- Joint replication (Standard mode only)
				if not PlaybackState.nativeAnim and fA.j and fB.j then
					for jointName, dataA in pairs(fA.j) do
						local dataB = fB.j[jointName]
						if dataB then
							local motor = PlaybackState.jointMap[jointName]
							if motor then
								local target = TblToCF(dataA):Lerp(TblToCF(dataB), alpha)
								if PlaybackState.strictRetarget then
									motor.Transform = target.Rotation
								else
									motor.Transform = target
								end
							end
						end
					end
				end
			end
		end)
	end
end

-- Pause playback
local function PausePlayback()
	if PlaybackState.isPlaying then
		PlaybackState.isPaused = true
		PlaybackState.isPlaying = false

		-- Reset character when paused (SAME AS PC behavior)
		-- This allows player to move freely while paused
		ResetCharacter()

		WindUI:Notify({ Title = "Paused", Content = "Playback paused - You can move freely", Duration = 2 })
	end
end

-- ══════════════════════════════════════════════════════════════════
-- 🎬 MERGED PLAYER TAB
-- ══════════════════════════════════════════════════════════════════

-- Variables
local selectedFile = nil
local selectedFileDisplay = nil -- Reference to paragraph element

-- Function to select file (Defined early)
local function SelectFile(fileName)
	selectedFile = fileName
	local displayName = fileName:gsub("%.json$", "")

	-- Update the paragraph display
	if selectedFileDisplay then
		pcall(function()
			selectedFileDisplay:SetTitle("🎬 " .. displayName)
			selectedFileDisplay:SetDesc("Ready to play • Tap Play to start")
		end)
	end

	WindUI:Notify({
		Title = "File Selected",
		Content = displayName,
		Duration = 1.5,
	})
end

-- ══════════════════════════════════════════════════════════════════
-- CLOUD RECORDINGS (Main file source for mobile)
-- ══════════════════════════════════════════════════════════════════
ListMapTab:Space()

-- Fetch cloud recordings list BEFORE creating dropdown
do
	local apiUrl = BuildCloudURL({ list = "all" })

	local success, response = pcall(function()
		return game:HttpGet(apiUrl)
	end)

	if success and response then
		local parseSuccess, data = pcall(function()
			return HttpService:JSONDecode(response)
		end)

		if parseSuccess and data and data.success and data.recordings then
			-- Store as simple strings for dropdown (supports search)
			for _, rec in ipairs(data.recordings) do
				local displayName = rec.name
				table.insert(CloudDropdownValues, displayName)

				-- Cache full info for lookup
				CloudRecordingsCache[displayName] = {
					name = rec.name,
					recordingId = rec.recordingId,
				}
			end

			-- Sort alphabetically (A-Z)
			table.sort(CloudDropdownValues, function(a, b)
				return string.lower(a) < string.lower(b)
			end)
		end
	end

	if #CloudDropdownValues == 0 then
		table.insert(CloudDropdownValues, "No cloud recordings")
	end
end

ListMapTab:Paragraph({
	Title = "☁️ Cloud Recordings (" .. #CloudDropdownValues .. ")",
	Desc = "Recordings uploaded by Dev/Owner",
})

-- Refresh Button
ListMapTab:Button({
	Title = "🔄 Refresh Cloud List",
	Desc = "Reload recordings from cloud",
	Callback = function()
		WindUI:Notify({
			Title = "🔄 Refreshing...",
			Content = "Reloading cloud recordings...",
			Duration = 2,
		})

		-- Clear existing cache
		CloudDropdownValues = {}
		CloudRecordingsCache = {}

		local apiUrl = BuildCloudURL({ list = "all" })

		local success, response = pcall(function()
			return game:HttpGet(apiUrl)
		end)

		if success and response then
			local parseSuccess, data = pcall(function()
				return HttpService:JSONDecode(response)
			end)

			if parseSuccess and data and data.success and data.recordings then
				for _, rec in ipairs(data.recordings) do
					local displayName = "☁️ " .. rec.name
					table.insert(CloudDropdownValues, displayName)
					CloudRecordingsCache[displayName] = {
						name = rec.name,
						recordingId = rec.recordingId,
					}
				end

				-- Sort alphabetically (A-Z)
				table.sort(CloudDropdownValues, function(a, b)
					return string.lower(a) < string.lower(b)
				end)

				WindUI:Notify({
					Title = "✅ Refreshed",
					Content = #data.recordings .. " recordings found. Re-execute script to see in dropdown.",
					Duration = 4,
				})
			else
				WindUI:Notify({
					Title = "❌ Error",
					Content = "Failed to parse cloud data",
					Duration = 2,
				})
			end
		else
			WindUI:Notify({
				Title = "❌ Error",
				Content = "Failed to connect to cloud",
				Duration = 2,
			})
		end
	end,
})

-- Clear Cache Button
ListMapTab:Button({
	Title = "🗑️ Clear Cache",
	Desc = "Delete locally saved recordings",
	Callback = function()
		local cacheInfo = GetCacheInfo()
		if cacheInfo.count == 0 then
			WindUI:Notify({
				Title = "ℹ️ Cache Empty",
				Content = "No cached recordings to clear",
				Duration = 2,
			})
			return
		end

		if ClearCache() then
			WindUI:Notify({
				Title = "🗑️ Cache Cleared",
				Content = cacheInfo.count .. " recordings removed from cache",
				Duration = 3,
			})
		else
			WindUI:Notify({
				Title = "❌ Error",
				Content = "Failed to clear cache",
				Duration = 2,
			})
		end
	end,
})

ListMapTab:Space()

-- Cloud Recordings Dropdown
local selectedCloudRecording = nil
local CloudRecordingLoaded = false -- Flag to show playback controls

-- Helper function to load a single chunk
local function LoadChunk(recordingId, chunkIndex, callback)
	if ChunkedState.loadedChunks[chunkIndex] then
		-- Already loaded
		if callback then
			callback(true, ChunkedState.loadedChunks[chunkIndex])
		end
		return
	end

	if ChunkedState.currentLoadingChunk == chunkIndex then
		-- Already loading this chunk
		return
	end

	ChunkedState.currentLoadingChunk = chunkIndex

	task.spawn(function()
		local apiUrl = BuildCloudURL({ recordingId = recordingId, chunk = chunkIndex }, true) -- true = use chunked endpoint

		local success, response = pcall(function()
			return game:HttpGet(apiUrl)
		end)

		ChunkedState.currentLoadingChunk = -1

		if not success then
			warn("[Chunked] Failed to load chunk " .. chunkIndex)
			if callback then
				callback(false, nil)
			end
			return
		end

		local parseSuccess, data = pcall(function()
			return HttpService:JSONDecode(response)
		end)

		if parseSuccess and data and data.success and data.frames then
			-- Cache the chunk
			ChunkedState.loadedChunks[chunkIndex] = {
				frames = data.frames,
				startFrame = data.startFrame,
				endFrame = data.endFrame,
			}

			-- Update metadata from first chunk if available
			if chunkIndex == 0 and data.totalFrames then
				ChunkedState.totalFrames = data.totalFrames
				ChunkedState.framesPerChunk = data.framesPerChunk or 3000
				ChunkedState.totalChunks = data.totalChunks or 1
			end

			-- Calculate progress
			local loadedCount = 0
			for _ in pairs(ChunkedState.loadedChunks) do
				loadedCount = loadedCount + 1
			end
			ChunkedState.loadProgress = math.floor((loadedCount / ChunkedState.totalChunks) * 100)

			if callback then
				callback(true, ChunkedState.loadedChunks[chunkIndex])
			end
		else
			-- More detailed error for debugging
			local errMsg = "[Chunked] Failed to parse chunk " .. chunkIndex
			if not parseSuccess then
				errMsg = errMsg .. " (JSON parse error)"
			elseif not data then
				errMsg = errMsg .. " (nil data)"
			elseif not data.success then
				errMsg = errMsg .. " (API error: " .. tostring(data.error or "unknown") .. ")"
			elseif not data.frames then
				errMsg = errMsg .. " (no frames in response)"
			end
			warn(errMsg)

			-- Try again after a delay (single retry)
			if not ChunkedState.loadedChunks[chunkIndex] then
				task.delay(2, function()
					LoadChunk(recordingId, chunkIndex, callback)
				end)
			else
				if callback then
					callback(false, nil)
				end
			end
		end
	end)
end

-- Helper function to preload next chunks in background
PreloadNextChunks = function(recordingId, currentChunkIndex, numToPreload)
	if ChunkedState.isPreloading then
		return
	end
	ChunkedState.isPreloading = true

	task.spawn(function()
		for i = 1, numToPreload do
			local nextChunk = currentChunkIndex + i
			if nextChunk < ChunkedState.totalChunks and not ChunkedState.loadedChunks[nextChunk] then
				-- Load next chunk
				LoadChunk(recordingId, nextChunk, function(success)
					if success then
						-- Update CloudRecordingData with new frames
						if CloudRecordingData and CloudRecordingData._isChunked then
							local newChunk = ChunkedState.loadedChunks[nextChunk]
							if newChunk and newChunk.frames then
								-- Append new frames to existing data
								for _, frame in ipairs(newChunk.frames) do
									table.insert(CloudRecordingData.Frames, frame)
								end

								-- Also update PlaybackState.frameData if it's the same recording
								if PlaybackState.frameData and PlaybackState.currentFile then
									local isCurrentRecording = string.find(PlaybackState.currentFile, recordingId)
									if isCurrentRecording then
										for _, frame in ipairs(newChunk.frames) do
											table.insert(PlaybackState.frameData, frame)
										end
										-- Update total duration
										if #PlaybackState.frameData > 0 then
											PlaybackState.totalDuration = PlaybackState.frameData[#PlaybackState.frameData].t
												or 0
										end
									end
								end

								-- Count loaded chunks
								local loadedCount = 0
								for _ in pairs(ChunkedState.loadedChunks) do
									loadedCount = loadedCount + 1
								end

								-- Progress tracked silently (no notification to avoid FPS drop)
							end
						end
					end
				end)
				task.wait(1.0) -- Delay between preloads to avoid network congestion
			end
		end
		ChunkedState.isPreloading = false
	end)
end

-- Helper function to assemble all loaded chunks into frame data
local function AssembleFrameData()
	local allFrames = {}

	-- Assemble chunks in order
	for chunkIdx = 0, ChunkedState.totalChunks - 1 do
		local chunkData = ChunkedState.loadedChunks[chunkIdx]
		if chunkData and chunkData.frames then
			for _, frame in ipairs(chunkData.frames) do
				table.insert(allFrames, frame)
			end
		end
	end

	return allFrames
end

-- Forward declaration for direct loading function (used as fallback)
local LoadCloudRecordingDirect

-- Helper function to load a cloud recording (with local cache support)
local function LoadCloudRecording(recInfo)
	if not recInfo or not recInfo.recordingId then
		WindUI:Notify({
			Title = "Error",
			Content = "Invalid recording info",
			Duration = 2,
		})
		return
	end

	selectedCloudRecording = recInfo
	CloudRecordingLoaded = false -- Reset until loaded

	-- ═══════════════════════════════════════════════════════════════
	-- STEP 0: CHECK LOCAL CACHE FIRST (INSTANT if cached!)
	-- ═══════════════════════════════════════════════════════════════
	if IsRecordingCached(recInfo.recordingId) then
		WindUI:Notify({
			Title = "📂 Loading from cache...",
			Content = recInfo.name,
			Duration = 1.5,
		})

		local cachedData = LoadFromCache(recInfo.recordingId)
		if cachedData then
			-- Loaded from cache! INSTANT!
			CloudRecordingData = cachedData
			CloudRecordingName = cachedData.name or recInfo.name
			CloudRecordingLoaded = true

			-- Update selected file display
			selectedFile = "CLOUD:" .. recInfo.recordingId
			if selectedFileDisplay then
				pcall(function()
					selectedFileDisplay:SetTitle("☁️ " .. CloudRecordingName)
					local frameCount = cachedData.Frames and #cachedData.Frames or 0
					selectedFileDisplay:SetDesc(string.format("Ready! • %d frames (cached)", frameCount))
				end)
			end

			local frameCount = cachedData.Frames and #cachedData.Frames or 0
			WindUI:Notify({
				Title = "✅ Ready! (Cached)",
				Content = string.format("%s loaded instantly - Press Play!", CloudRecordingName),
				Duration = 2,
			})

			-- Show Playback Controls & Enable Mini Player
			CreatePlaybackControls()

			return -- Done! No network needed
		end
	end

	-- ═══════════════════════════════════════════════════════════════
	-- Not cached - Download directly from cloud
	-- With 4-digit precision optimization on server, files are smaller!
	-- ═══════════════════════════════════════════════════════════════

	WindUI:Notify({
		Title = "☁️ Downloading...",
		Content = "Fetching " .. recInfo.name .. " from cloud...",
		Duration = 3,
	})

	-- Update display
	if selectedFileDisplay then
		pcall(function()
			selectedFileDisplay:SetTitle("☁️ " .. recInfo.name)
			selectedFileDisplay:SetDesc("⏳ Downloading... Please wait")
		end)
	end

	-- Use direct download (no chunking needed with optimized files)
	LoadCloudRecordingDirect(recInfo)
end

-- Fallback: Direct load for small files or when chunked API fails
LoadCloudRecordingDirect = function(recInfo)
	task.spawn(function()
		local apiUrl = BuildCloudURL({ recordingId = recInfo.recordingId })

		local success, response = pcall(function()
			return game:HttpGet(apiUrl)
		end)

		if not success then
			WindUI:Notify({
				Title = "Error",
				Content = "Failed to connect to cloud",
				Duration = 3,
			})
			return
		end

		-- Update UI: Processing
		if selectedFileDisplay then
			pcall(function()
				selectedFileDisplay:SetDesc("⚙️ Processing data...")
			end)
		end

		local parseSuccess, data = pcall(function()
			return HttpService:JSONDecode(response)
		end)

		if not parseSuccess or not data then
			WindUI:Notify({
				Title = "Error",
				Content = "Invalid response from server",
				Duration = 3,
			})
			return
		end

		if data.error then
			WindUI:Notify({
				Title = "Error",
				Content = data.error or "Recording not found",
				Duration = 3,
			})
			return
		end

		-- Handle Large File Download (Presigned URL)
		if data.downloadUrl then
			if selectedFileDisplay then
				pcall(function()
					selectedFileDisplay:SetDesc("📥 Downloading large file...")
				end)
			end

			local dlSuccess, dlResponse = pcall(function()
				return game:HttpGet(data.downloadUrl)
			end)

			if not dlSuccess then
				WindUI:Notify({
					Title = "Error",
					Content = "Failed to download large file",
					Duration = 3,
				})
				return
			end

			local fileData = HttpService:JSONDecode(dlResponse)

			-- Normalize data structure
			if fileData.data then
				CloudRecordingData = fileData.data
			else
				CloudRecordingData = fileData
			end

			CloudRecordingName = data.name or fileData.name or recInfo.name
			CloudRecordingLoaded = true
			ChunkedState.isChunked = false

			-- Update selected file display
			selectedFile = "CLOUD:" .. recInfo.recordingId
			if selectedFileDisplay then
				pcall(function()
					selectedFileDisplay:SetTitle("☁️ " .. CloudRecordingName)
					selectedFileDisplay:SetDesc("Cloud Recording • Ready to play")
				end)
			end

			WindUI:Notify({
				Title = "☁️ Ready!",
				Content = CloudRecordingName .. " loaded - tap Play to start",
				Duration = 3,
			})

			-- Show Playback Controls & Enable Mini Player
			CreatePlaybackControls()
			return
		end

		if data.success and data.recording then
			-- Store in memory
			CloudRecordingData = data.recording
			CloudRecordingName = data.name or recInfo.name
			CloudRecordingLoaded = true -- Mark as loaded!
			ChunkedState.isChunked = false

			-- Update selected file display
			selectedFile = "CLOUD:" .. recInfo.recordingId
			if selectedFileDisplay then
				pcall(function()
					selectedFileDisplay:SetTitle("☁️ " .. CloudRecordingName)
					selectedFileDisplay:SetDesc("Cloud Recording • Ready to play")
				end)
			end

			WindUI:Notify({
				Title = "☁️ Ready!",
				Content = CloudRecordingName .. " loaded - tap Play to start",
				Duration = 3,
			})

			-- Show Playback Controls & Enable Mini Player
			CreatePlaybackControls()

			-- Save to local cache for instant load next time
			task.spawn(function()
				local cacheData = {
					Frames = data.recording.Frames or data.recording,
					Mode = data.recording.Mode or "Flexible",
					name = CloudRecordingName,
				}
				SaveToCache(recInfo.recordingId, cacheData)
			end)
		else
			WindUI:Notify({
				Title = "Error",
				Content = "Recording data not found",
				Duration = 3,
			})
		end
	end)
end

-- Simple Dropdown with Search (supports SearchBarEnabled)
ListMapTab:Dropdown({
	Title = "Select Cloud Recording",
	Desc = "Sorted A-Z • Use search to find",
	Values = CloudDropdownValues,
	SearchBarEnabled = true,
	Callback = function(selected)
		if selected == "No cloud recordings" then
			return
		end

		local recInfo = CloudRecordingsCache[selected]
		if not recInfo then
			WindUI:Notify({
				Title = "Error",
				Content = "Recording not found in cache",
				Duration = 2,
			})
			return
		end

		LoadCloudRecording(recInfo)
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- 2. PLAYBACK CONTROLS (Bottom)
-- ══════════════════════════════════════════════════════════════════

-- Mini Player Logic (Raw GUI) - Compact Modern Design with 3 Buttons
local MiniPlayerGui = nil
local MiniPlayerAnimations = {}
local MiniPlayerToggle = nil

local function ToggleMiniPlayer(state)
	if state then
		if MiniPlayerGui then
			return
		end

		-- Try CoreGui, fallback to PlayerGui
		local parent
		local success, cGui = pcall(function()
			return game:GetService("CoreGui")
		end)
		if success and cGui then
			parent = cGui
		else
			parent = LocalPlayer:WaitForChild("PlayerGui")
		end

		local TweenService = game:GetService("TweenService")
		local RunService = game:GetService("RunService")

		local screen = Instance.new("ScreenGui")
		screen.Name = "StarshipMiniCompact"
		screen.ResetOnSpawn = false
		screen.DisplayOrder = 999999
		screen.IgnoreGuiInset = true
		screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screen.Parent = parent

		-- ═══════════════════════════════════════════════════════════
		-- MAIN CONTAINER - Compact Design
		-- ═══════════════════════════════════════════════════════════
		local mainFrame = Instance.new("Frame")
		mainFrame.Name = "MiniPlayerMain"
		mainFrame.Size = UDim2.new(0, 150, 0, 60)
		mainFrame.Position = UDim2.new(0.5, -75, 0, 50)
		mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		mainFrame.BackgroundTransparency = 0.08
		mainFrame.BorderSizePixel = 0
		mainFrame.Active = true
		mainFrame.Draggable = true
		mainFrame.Parent = screen

		-- Entrance animation
		mainFrame.Size = UDim2.new(0, 0, 0, 0)
		mainFrame.Position = UDim2.new(0.5, 0, 0, 50)
		local entranceTween =
			TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 150, 0, 60),
				Position = UDim2.new(0.5, -75, 0, 50),
			})
		entranceTween:Play()

		-- Rounded corners
		local mainCorner = Instance.new("UICorner")
		mainCorner.CornerRadius = UDim.new(0, 14)
		mainCorner.Parent = mainFrame

		-- Gradient border
		local glowStroke = Instance.new("UIStroke")
		glowStroke.Color = Color3.fromRGB(138, 43, 226)
		glowStroke.Thickness = 1.5
		glowStroke.Transparency = 0.3
		glowStroke.Parent = mainFrame

		-- Animated gradient for stroke
		local strokeGradient = Instance.new("UIGradient")
		strokeGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(138, 43, 226)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(59, 130, 246)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(236, 72, 153)),
		})
		strokeGradient.Rotation = 0
		strokeGradient.Parent = glowStroke

		-- Animate gradient rotation
		local gradientRotation = 0
		table.insert(
			MiniPlayerAnimations,
			RunService.Heartbeat:Connect(function(dt)
				gradientRotation = (gradientRotation + dt * 45) % 360
				strokeGradient.Rotation = gradientRotation
			end)
		)

		-- Background gradient
		local bgGradient = Instance.new("UIGradient")
		bgGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 45)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 28)),
		})
		bgGradient.Rotation = 45
		bgGradient.Parent = mainFrame

		-- ═══════════════════════════════════════════════════════════
		-- HEADER - Drag indicator + Close button
		-- ═══════════════════════════════════════════════════════════
		local header = Instance.new("Frame")
		header.Name = "Header"
		header.Size = UDim2.new(1, 0, 0, 18)
		header.Position = UDim2.new(0, 0, 0, 0)
		header.BackgroundTransparency = 1
		header.ZIndex = 5
		header.Parent = mainFrame

		-- Drag indicator
		local dragHandle = Instance.new("Frame")
		dragHandle.Size = UDim2.new(0, 30, 0, 3)
		dragHandle.Position = UDim2.new(0.5, -15, 0, 5)
		dragHandle.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
		dragHandle.BackgroundTransparency = 0.4
		dragHandle.BorderSizePixel = 0
		dragHandle.ZIndex = 6
		dragHandle.Parent = header
		Instance.new("UICorner", dragHandle).CornerRadius = UDim.new(1, 0)

		-- Close button
		local closeBtn = Instance.new("TextButton")
		closeBtn.Size = UDim2.new(0, 16, 0, 16)
		closeBtn.Position = UDim2.new(1, -20, 0, 1)
		closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		closeBtn.BackgroundTransparency = 0.5
		closeBtn.Text = "×"
		closeBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.TextSize = 12
		closeBtn.AutoButtonColor = false
		closeBtn.ZIndex = 6
		closeBtn.Parent = header
		Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

		closeBtn.MouseEnter:Connect(function()
			TweenService:Create(closeBtn, TweenInfo.new(0.15), {
				BackgroundColor3 = Color3.fromRGB(200, 60, 70),
				BackgroundTransparency = 0.2,
			}):Play()
		end)
		closeBtn.MouseLeave:Connect(function()
			TweenService:Create(closeBtn, TweenInfo.new(0.15), {
				BackgroundColor3 = Color3.fromRGB(60, 60, 80),
				BackgroundTransparency = 0.5,
			}):Play()
		end)
		closeBtn.MouseButton1Click:Connect(function()
			StopPlayback()
			if MiniPlayerToggle then
				MiniPlayerToggle:Set(false)
			else
				ToggleMiniPlayer(false)
			end
		end)

		-- ═══��═════���═════════════════════════════════════════════════
		-- BUTTONS CONTAINER - 3 Buttons: Play, Moonwalk, Loop
		-- ═══════════════════════════════════════════════════════════
		local buttonsFrame = Instance.new("Frame")
		buttonsFrame.Name = "Buttons"
		buttonsFrame.Size = UDim2.new(1, -16, 0, 32)
		buttonsFrame.Position = UDim2.new(0, 8, 0, 22)
		buttonsFrame.BackgroundTransparency = 1
		buttonsFrame.ZIndex = 5
		buttonsFrame.Parent = mainFrame

		-- State tracking for toggles
		local isPlaying = false
		local isMoonwalk = PlaybackState.isMoonwalk or false
		local isLooping = PlaybackState.isLooping or false

		-- Button creator function
		local function createButton(icon, color, posX, tooltip)
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 40, 0, 32)
			btn.Position = UDim2.new(0, posX, 0, 0)
			btn.BackgroundColor3 = color
			btn.BackgroundTransparency = 0.15
			btn.Text = icon
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 16
			btn.AutoButtonColor = false
			btn.ZIndex = 6
			btn.Parent = buttonsFrame
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

			local btnStroke = Instance.new("UIStroke")
			btnStroke.Color = color
			btnStroke.Thickness = 1
			btnStroke.Transparency = 0.6
			btnStroke.Parent = btn

			-- Hover effect
			btn.MouseEnter:Connect(function()
				TweenService:Create(btn, TweenInfo.new(0.15), {
					BackgroundTransparency = 0,
					Size = UDim2.new(0, 42, 0, 34),
				}):Play()
			end)
			btn.MouseLeave:Connect(function()
				TweenService:Create(btn, TweenInfo.new(0.15), {
					BackgroundTransparency = 0.15,
					Size = UDim2.new(0, 40, 0, 32),
				}):Play()
			end)

			return btn, btnStroke
		end

		-- 1. PLAY/PAUSE Button (Green)
		local playBtn, playStroke = createButton("▶", Color3.fromRGB(34, 197, 94), 0, "Play/Pause")
		playBtn.MouseButton1Click:Connect(function()
			if not selectedFile then
				WindUI:Notify({ Title = "⚠️", Content = "Select file first!", Duration = 1.5 })
				return
			end

			if PlaybackState.isPlaying and not PlaybackState.isPaused then
				-- Pause
				PausePlayback()
				playBtn.Text = "▶"
				isPlaying = false
			else
				-- Play
				PlayRecording(selectedFile)
				playBtn.Text = "⏸"
				isPlaying = true
			end
		end)

		-- 2. MOONWALK Button (Purple) - Walk backward while facing forward
		local moonwalkBtn, moonwalkStroke = createButton("🌙", Color3.fromRGB(138, 43, 226), 46, "Moonwalk")

		-- Set initial state from PlaybackState
		if PlaybackState.isMoonwalk then
			moonwalkBtn.BackgroundColor3 = Color3.fromRGB(236, 72, 153)
			moonwalkStroke.Color = Color3.fromRGB(236, 72, 153)
		end

		moonwalkBtn.MouseButton1Click:Connect(function()
			isMoonwalk = not isMoonwalk
			PlaybackState.isMoonwalk = isMoonwalk

			if isMoonwalk then
				moonwalkBtn.BackgroundColor3 = Color3.fromRGB(236, 72, 153)
				moonwalkStroke.Color = Color3.fromRGB(236, 72, 153)
				WindUI:Notify({ Title = "🌙 Moonwalk", Content = "ON - Walking backward", Duration = 1.5 })
			else
				moonwalkBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
				moonwalkStroke.Color = Color3.fromRGB(138, 43, 226)
				WindUI:Notify({ Title = "🌙 Moonwalk", Content = "OFF", Duration = 1 })
			end
		end)

		-- 3. LOOP Button (Blue)
		local loopBtn, loopStroke = createButton("🔁", Color3.fromRGB(59, 130, 246), 92, "Loop")

		-- Set initial state
		if isLooping then
			loopBtn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
			loopStroke.Color = Color3.fromRGB(34, 197, 94)
		end

		loopBtn.MouseButton1Click:Connect(function()
			isLooping = not isLooping
			PlaybackState.isLooping = isLooping

			if isLooping then
				loopBtn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
				loopStroke.Color = Color3.fromRGB(34, 197, 94)
				WindUI:Notify({ Title = "🔁 Loop", Content = "Loop ON", Duration = 1 })
			else
				loopBtn.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
				loopStroke.Color = Color3.fromRGB(59, 130, 246)
				WindUI:Notify({ Title = "🔁 Loop", Content = "Loop OFF", Duration = 1 })
			end
		end)

		-- Update play button state when playback changes
		table.insert(
			MiniPlayerAnimations,
			RunService.Heartbeat:Connect(function()
				if PlaybackState.isPlaying and not PlaybackState.isPaused then
					if playBtn.Text ~= "⏸" then
						playBtn.Text = "⏸"
					end
				else
					if playBtn.Text ~= "▶" then
						playBtn.Text = "▶"
					end
				end
			end)
		)

		MiniPlayerGui = screen
		WindUI:Notify({ Title = "🎮 Mini Player", Content = "Drag to move", Duration = 1.5 })
	else
		-- Cleanup animations
		for _, conn in ipairs(MiniPlayerAnimations) do
			if conn then
				conn:Disconnect()
			end
		end
		MiniPlayerAnimations = {}

		if MiniPlayerGui then
			local TweenService = game:GetService("TweenService")
			local mainFrame = MiniPlayerGui:FindFirstChild("MiniPlayerMain")
			if mainFrame then
				local exitTween = TweenService:Create(
					mainFrame,
					TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In),
					{
						Size = UDim2.new(0, 0, 0, 0),
						Position = UDim2.new(0.5, 0, 0, 50),
					}
				)
				exitTween:Play()
				exitTween.Completed:Connect(function()
					if MiniPlayerGui then
						MiniPlayerGui:Destroy()
						MiniPlayerGui = nil
					end
				end)
			else
				MiniPlayerGui:Destroy()
				MiniPlayerGui = nil
			end
		end
	end
end

ListMapTab:Divider()
ListMapTab:Space()

-- Selected File Display
selectedFileDisplay = ListMapTab:Paragraph({
	Title = "📭 No file selected",
	Desc = "Select a file above to play",
})

local PlaybackControlsCreated = false

function CreatePlaybackControls()
	if PlaybackControlsCreated then
		if MiniPlayerToggle then
			MiniPlayerToggle:SetValue(true)
		end
		return
	end
	PlaybackControlsCreated = true

	local PlaybackSection = ListMapTab:Section({
		Title = "🎮 Playback Controls",
		Opened = true,
	})

	MiniPlayerToggle = PlaybackSection:Toggle({
		Title = "Show Mini Player",
		Desc = "Floating play/stop widget",
		Value = false,
		Callback = ToggleMiniPlayer,
	})

	PlaybackSection:Toggle({
		Title = "✨ Path Visualization",
		Desc = "Premium gradient path with animated markers",
		Value = false,
		Callback = function(state)
			isPathVisualsEnabled = state
			if state then
				if PlaybackState.frameData then
					DrawPath(PlaybackState.frameData)
				end
			else
				ClearPath()
			end
		end,
	})

	PlaybackSection:Slider({
		Title = "Playback Speed",
		Desc = "Speed multiplier (Default: 1)",
		Value = { Min = 0.1, Max = 3, Default = 1 },
		Step = 0.1,
		Callback = function(val)
			PlaybackState.speed = val
		end,
	})

	PlaybackSection:Toggle({
		Title = "Respawn on End",
		Desc = "Respawn character when recording ends",
		Value = false,
		Callback = function(state)
			PlaybackState.respawnOnEnd = state
			WindUI:Notify({
				Title = "Respawn",
				Content = state and "Will respawn on end" or "Will NOT respawn",
				Duration = 1,
			})
		end,
	})

	-- Anti-AFK Feature
	local antiAfkConnection = nil
	local isAntiAfkOn = Settings.AutoAntiAFK

	local function setAfkState(state)
		isAntiAfkOn = state
		Settings.AutoAntiAFK = state
		SaveSettings()

		if isAntiAfkOn then
			if not antiAfkConnection then
				antiAfkConnection = LocalPlayer.Idled:Connect(function() end)
			end
		else
			if antiAfkConnection then
				antiAfkConnection:Disconnect()
				antiAfkConnection = nil
			end
		end
	end

	if isAntiAfkOn then
		setAfkState(true)
	end

	PlaybackSection:Toggle({
		Title = "Anti-AFK",
		Desc = "Prevent being kicked for inactivity",
		Value = Settings.AutoAntiAFK,
		Callback = function(state)
			setAfkState(state)
			WindUI:Notify({
				Title = "Anti-AFK",
				Content = state and "Anti-AFK enabled!" or "Anti-AFK disabled.",
				Duration = 2,
			})
		end,
	})

	-- Bypass Admin Feature
	local isBypassAdminOn = false
	local bypassAdminConnection = nil

	local function CheckForAdmin(player)
		if player == LocalPlayer or not player.Parent then
			return
		end

		local isAdmin = false
		if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
			isAdmin = true
		elseif game.CreatorType == Enum.CreatorType.Group then
			local s, rank = pcall(function()
				return player:GetRankInGroup(game.CreatorId)
			end)
			if s and rank and rank >= 100 then
				isAdmin = true
			end

			local s2, role = pcall(function()
				return player:GetRoleInGroup(game.CreatorId)
			end)
			if s2 and role then
				local lower = role:lower()
				if
					lower:find("admin")
					or lower:find("mod")
					or lower:find("staff")
					or lower:find("dev")
					or lower:find("owner")
				then
					isAdmin = true
				end
			end
		end

		if isAdmin then
			LocalPlayer:Kick("⚠️ Safety Triggered: Admin (" .. player.Name .. ") detected.")
		end
	end

	PlaybackSection:Toggle({
		Title = "Bypass Admin",
		Desc = "Auto-kick when admin/mod joins the server",
		Value = false,
		Callback = function(state)
			isBypassAdminOn = state
			if isBypassAdminOn then
				for _, p in ipairs(Players:GetPlayers()) do
					CheckForAdmin(p)
				end
				bypassAdminConnection = Players.PlayerAdded:Connect(CheckForAdmin)
				WindUI:Notify({ Title = "Bypass Admin", Content = "Admin detection enabled!", Duration = 2 })
			else
				if bypassAdminConnection then
					bypassAdminConnection:Disconnect()
					bypassAdminConnection = nil
				end
				WindUI:Notify({ Title = "Bypass Admin", Content = "Admin detection disabled.", Duration = 2 })
			end
		end,
	})
	-- Auto-enable Mini Player (delayed to ensure UI is ready)
	task.delay(0.2, function()
		if MiniPlayerToggle then
			local s = pcall(function()
				MiniPlayerToggle:Set(true)
			end)
			if not s then
				s = pcall(function()
					MiniPlayerToggle:SetValue(true)
				end)
			end
			if not s then
				-- Fallback: Manual callback + property set
				pcall(function()
					MiniPlayerToggle.Value = true
				end)
				ToggleMiniPlayer(true)
			end
		end
	end)
end

-- ══════════════════════════════════════════════════════════════════
-- 🎉 FUN TAB
-- ══════════════════════════════════════════════════════════════════
local FunTab = Window:Tab({
	Title = "Fun",
	Icon = "smile",
})

FunTab:Divider()

-- Fun Actions
FunTab:Section({ Title = "🎮 Fun Actions", TextSize = 20 })

FunTab:Button({
	Title = "🔄 Spin Character",
	Desc = "Make your character spin",
	Callback = function()
		local hrp = GetHRP()
		if hrp then
			for i = 1, 360, 10 do
				hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(10), 0)
				task.wait(0.01)
			end
		end
	end,
})

FunTab:Button({
	Title = "⬆️ Launch Up",
	Desc = "Launch yourself into the sky",
	Callback = function()
		local hrp = GetHRP()
		if hrp then
			local bv = Instance.new("BodyVelocity")
			bv.MaxForce = Vector3.new(0, math.huge, 0)
			bv.Velocity = Vector3.new(0, 200, 0)
			bv.Parent = hrp
			task.delay(0.5, function()
				if bv then
					bv:Destroy()
				end
			end)
		end
	end,
})

FunTab:Button({
	Title = "💀 Ragdoll",
	Desc = "Make yourself ragdoll",
	Callback = function()
		local char = GetCharacter()
		local hum = GetHumanoid()
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Physics)
			task.delay(3, function()
				if hum then
					hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
			end)
		end
	end,
})

FunTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 💥 TOUCH FLING
-- ══════════════════════════════════════════════════════════════════
FunTab:Section({ Title = "💥 Touch Fling", TextSize = 20 })

local isFlingOn = false
local flingLoop = nil
local isHitboxExpanded = false
local hitboxParts = {}

FunTab:Toggle({
	Title = "Expand Hitbox",
	Desc = "Bigger hitbox = easier fling",
	Value = false,
	Callback = function(state)
		isHitboxExpanded = state

		local char = GetCharacter()
		if not char then
			return
		end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end

		if isHitboxExpanded then
			for i = 1, 4 do
				local part = Instance.new("Part")
				part.Name = "HitboxExpander"
				part.Size = Vector3.new(4, 4, 0.5)
				part.Transparency = 1
				part.CanCollide = true
				part.Massless = true
				part.Parent = char

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hrp
				weld.Part1 = part
				weld.Parent = part

				table.insert(hitboxParts, part)
			end

			if hitboxParts[1] then
				hitboxParts[1].CFrame = hrp.CFrame * CFrame.new(0, 0, -3)
			end
			if hitboxParts[2] then
				hitboxParts[2].CFrame = hrp.CFrame * CFrame.new(0, 0, 3)
			end
			if hitboxParts[3] then
				hitboxParts[3].CFrame = hrp.CFrame * CFrame.new(-3, 0, 0)
			end
			if hitboxParts[4] then
				hitboxParts[4].CFrame = hrp.CFrame * CFrame.new(3, 0, 0)
			end

			WindUI:Notify({ Title = "Hitbox", Content = "Hitbox expanded!", Duration = 2 })
		else
			for _, part in pairs(hitboxParts) do
				if part and part.Parent then
					part:Destroy()
				end
			end
			hitboxParts = {}
			WindUI:Notify({ Title = "Hitbox", Content = "Hitbox reset.", Duration = 2 })
		end
	end,
})

FunTab:Toggle({
	Title = "Touch Fling",
	Desc = "Fling players on touch",
	Value = false,
	Callback = function(state)
		isFlingOn = state

		if isFlingOn then
			flingLoop = RunService.Heartbeat:Connect(function()
				local char = GetCharacter()
				if not char then
					return
				end
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if not hrp then
					return
				end

				local currentVel = hrp.Velocity
				hrp.Velocity = currentVel * 10000 + Vector3.new(0, 10000, 0)

				if isHitboxExpanded then
					for _, part in pairs(hitboxParts) do
						if part and part.Parent then
							part.Velocity = hrp.Velocity
						end
					end
				end

				RunService.RenderStepped:Wait()

				if char and char.Parent and hrp and hrp.Parent then
					hrp.Velocity = currentVel
				end

				RunService.Stepped:Wait()
				if char and char.Parent and hrp and hrp.Parent then
					hrp.Velocity = currentVel + Vector3.new(0, 0.1, 0)
				end
			end)

			WindUI:Notify({ Title = "Touch Fling", Content = "Fling enabled!", Duration = 2 })
		else
			if flingLoop then
				flingLoop:Disconnect()
				flingLoop = nil
			end

			local char = GetCharacter()
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.Velocity = Vector3.new(0, 0, 0)
					hrp.RotVelocity = Vector3.new(0, 0, 0)
				end
			end

			WindUI:Notify({ Title = "Touch Fling", Content = "Fling disabled.", Duration = 2 })
		end
	end,
})

FunTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 👻 INVISIBLE
-- ══════════════════════════════════════════════════════════════════
FunTab:Section({ Title = "👻 Invisible", TextSize = 20 })

local isInvisibleOn = false
local invisibleLoop = nil

FunTab:Toggle({
	Title = "Invisible",
	Desc = "Real invisible (others can't see you)",
	Value = false,
	Callback = function(state)
		isInvisibleOn = state

		if isInvisibleOn then
			local offset = Vector3.new(0, -500, 0)

			invisibleLoop = RunService.Heartbeat:Connect(function()
				if not isInvisibleOn then
					return
				end

				local char = GetCharacter()
				if not char then
					return
				end

				local root = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChild("Humanoid")
				if not root or not hum then
					return
				end

				-- Save current position
				local currentCF = root.CFrame

				-- Teleport down (this is what server/other players see)
				root.CFrame = currentCF * CFrame.new(offset)

				-- Adjust camera offset so you see yourself at original position
				hum.CameraOffset = Vector3.new(0, 500, 0)

				-- Wait one render frame
				RunService.RenderStepped:Wait()

				-- Teleport back (only you see this)
				root.CFrame = currentCF
				hum.CameraOffset = Vector3.new(0, 0, 0)
			end)

			WindUI:Notify({ Title = "Invisible", Content = "You are now invisible to others!", Duration = 3 })
		else
			if invisibleLoop then
				invisibleLoop:Disconnect()
				invisibleLoop = nil
			end

			local char = GetCharacter()
			if char then
				local hum = char:FindFirstChild("Humanoid")
				if hum then
					hum.CameraOffset = Vector3.new(0, 0, 0)
				end
			end

			WindUI:Notify({ Title = "Invisible", Content = "Invisible disabled.", Duration = 2 })
		end
	end,
})

FunTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 👁️ SPECTATE PLAYER
-- ══════════════════════════════════════════════════════════════════
FunTab:Section({ Title = "👁️ Spectate Player", TextSize = 20 })

local spectateTarget = nil
local isSpectating = false
local spectateLoop = nil
local lastKnownPosition = nil

local function GetPlayerList()
	local list = {}
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			table.insert(list, p.Name)
		end
	end
	return list
end

FunTab:Dropdown({
	Title = "Select Player",
	Desc = "Choose player to spectate",
	Values = GetPlayerList(),
	Callback = function(selected)
		spectateTarget = Players:FindFirstChild(selected)
		WindUI:Notify({ Title = "Spectate", Content = "Selected: " .. selected, Duration = 2 })
	end,
})

FunTab:Button({
	Title = "🔄 Refresh Player List",
	Callback = function()
		WindUI:Notify({ Title = "Spectate", Content = "Re-open dropdown to see updated list", Duration = 2 })
	end,
})

FunTab:Toggle({
	Title = "Spectate",
	Desc = "Watch selected player",
	Value = false,
	Callback = function(state)
		isSpectating = state

		if isSpectating then
			if not spectateTarget then
				WindUI:Notify({ Title = "Error", Content = "Please select a player first!", Duration = 2 })
				return
			end

			if not spectateTarget.Parent then
				WindUI:Notify({ Title = "Error", Content = "Player left the game!", Duration = 2 })
				spectateTarget = nil
				return
			end

			spectateLoop = RunService.RenderStepped:Connect(function()
				if not spectateTarget or not spectateTarget.Parent then
					isSpectating = false
					if spectateLoop then
						spectateLoop:Disconnect()
						spectateLoop = nil
					end
					WindUI:Notify({ Title = "Spectate", Content = "Player left!", Duration = 2 })
					return
				end

				local targetChar = spectateTarget.Character
				local camera = workspace.CurrentCamera

				if targetChar then
					local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
					local targetHum = targetChar:FindFirstChildOfClass("Humanoid")

					if targetHRP then
						lastKnownPosition = targetHRP.Position
						pcall(function()
							LocalPlayer:RequestStreamAroundAsync(targetHRP.Position, 5)
						end)
					end

					if targetHum then
						camera.CameraSubject = targetHum
					elseif targetHRP then
						camera.CameraSubject = targetHRP
					elseif lastKnownPosition then
						camera.CameraType = Enum.CameraType.Custom
						camera.CFrame = CFrame.new(lastKnownPosition + Vector3.new(0, 10, 15), lastKnownPosition)
					end
				elseif lastKnownPosition then
					camera.CameraType = Enum.CameraType.Custom
					camera.CFrame = CFrame.new(lastKnownPosition + Vector3.new(0, 10, 15), lastKnownPosition)
				end
			end)

			WindUI:Notify({ Title = "Spectate", Content = "Spectating " .. spectateTarget.Name, Duration = 3 })
		else
			if spectateLoop then
				spectateLoop:Disconnect()
				spectateLoop = nil
			end
			lastKnownPosition = nil

			local myChar = GetCharacter()
			if myChar then
				local myHum = myChar:FindFirstChildOfClass("Humanoid")
				if myHum then
					workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
					workspace.CurrentCamera.CameraSubject = myHum
				end
			end

			WindUI:Notify({ Title = "Spectate", Content = "Spectate stopped.", Duration = 2 })
		end
	end,
})

FunTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🚶 AUTO FOLLOW
-- ══════════════════════════════════════════════════════════════════
FunTab:Section({ Title = "🚶 Auto Follow", TextSize = 20 })

local followTarget = nil
local isFollowing = false
local followLoop = nil

FunTab:Dropdown({
	Title = "Select Target",
	Desc = "Choose player to follow",
	Values = GetPlayerList(),
	Callback = function(selected)
		followTarget = Players:FindFirstChild(selected)
		WindUI:Notify({ Title = "Follow", Content = "Target: " .. selected, Duration = 2 })
	end,
})

FunTab:Toggle({
	Title = "Auto Follow",
	Desc = "Follow selected player automatically",
	Value = false,
	Callback = function(state)
		isFollowing = state

		if isFollowing then
			if not followTarget then
				WindUI:Notify({ Title = "Error", Content = "Please select a target first!", Duration = 2 })
				return
			end

			if not followTarget.Parent then
				WindUI:Notify({ Title = "Error", Content = "Player left the game!", Duration = 2 })
				followTarget = nil
				return
			end

			followLoop = RunService.Heartbeat:Connect(function()
				if not isFollowing or not followTarget then
					isFollowing = false
					if followLoop then
						followLoop:Disconnect()
						followLoop = nil
					end
					return
				end

				if not followTarget.Parent then
					isFollowing = false
					if followLoop then
						followLoop:Disconnect()
						followLoop = nil
					end
					WindUI:Notify({ Title = "Follow", Content = "Target left the game!", Duration = 2 })
					return
				end

				local myChar = GetCharacter()
				local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
				local myHum = myChar and myChar:FindFirstChild("Humanoid")

				local tChar = followTarget.Character
				local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
				local tHum = tChar and tChar:FindFirstChild("Humanoid")

				if not (myHRP and myHum and tHRP and tHum and tHum.Health > 0) then
					return
				end

				local look = tHRP.CFrame.LookVector
				local behindPos = tHRP.Position - (look * 4) + Vector3.new(0, 0, 0)
				local frontPoint = behindPos + look

				myHRP.CFrame = CFrame.new(behindPos, frontPoint)
			end)

			WindUI:Notify({ Title = "Follow", Content = "Following " .. followTarget.Name, Duration = 3 })
		else
			if followLoop then
				followLoop:Disconnect()
				followLoop = nil
			end

			WindUI:Notify({ Title = "Follow", Content = "Follow stopped.", Duration = 2 })
		end
	end,
})

FunTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🔗 SOCIAL TAB
-- ══════════════════════════════════════════════════════════════════
local SocialTab = Window:Tab({
	Title = "Social",
	Icon = "share-2",
})

SocialTab:Section({ Title = "🔗 Links & Social", TextSize = 16 })

SocialTab:Button({
	Title = "💬 Join Discord",
	Desc = "Get updates, support & community",
	Callback = function()
		if setclipboard then
			setclipboard("https://discord.gg/BUJuXA8Z")
			WindUI:Notify({ Title = "✅ Copied!", Content = "Discord invite link copied to clipboard!", Duration = 3 })
		else
			WindUI:Notify({ Title = "Discord", Content = "https://discord.gg/BUJuXA8Z", Duration = 5 })
		end
	end,
})

SocialTab:Button({
	Title = "⭐ Rate Us",
	Desc = "Leave a review if you enjoy Starship",
	Callback = function()
		WindUI:Notify({ Title = "Thank You!", Content = "We appreciate your support! 💜", Duration = 3 })
	end,
})

SocialTab:Button({
	Title = "📋 Copy Script",
	Desc = "Copy loadstring to clipboard",
	Callback = function()
		if setclipboard then
			setclipboard('loadstring(game:HttpGet("https://starship-core.my.id/api/mobile-bootstrap"))()')
			WindUI:Notify({ Title = "✅ Copied!", Content = "Loadstring copied to clipboard!", Duration = 3 })
		end
	end,
})

SocialTab:Divider()

SocialTab:Section({ Title = "📢 About", TextSize = 16 })

SocialTab:Paragraph({
	Title = "Starship Mobile",
	Desc = "Version 1.0 • Made with 💜\n\nThank you for using Starship Mobile!\nJoin our Discord for updates and support.",
})

-- ══════════════════════════════════════════════════════════════════
-- ⚙️ SETTINGS TAB
-- ══════════════════════════════════════════════════════════════════
local SettingsTab = Window:Tab({
	Title = "Settings",
	Icon = "settings",
})

-- ══════════════════════════════════════════════════════════════════
-- 🎨 APPEARANCE SETTINGS
-- ══════════════════════════════════════════════════════════════════
SettingsTab:Section({ Title = "🎨 Appearance", TextSize = 16 })

local ShowNotificationsToggle = SettingsTab:Toggle({
	Title = "Show Notifications",
	Desc = "Display popup notifications",
	Value = Settings.ShowNotifications,
	Callback = function(state)
		Settings.ShowNotifications = state
		SaveSettings()
	end,
})

local ThemeDropdown = SettingsTab:Dropdown({
	Title = "Theme",
	Desc = "Choose UI color theme",
	Values = { "Dark", "Light", "Midnight", "Aqua" },
	Value = Settings.Theme,
	Callback = function(selected)
		Settings.Theme = selected
		SaveSettings()
		pcall(function()
			WindUI:SetTheme(selected)
		end)
		WindUI:Notify({ Title = "Theme", Content = "Theme changed to " .. selected, Duration = 2 })
	end,
})

SettingsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🔧 GENERAL SETTINGS
-- ══════════════════════════════════════════════════════════════════
SettingsTab:Section({ Title = "🔧 General", TextSize = 16 })

local AutoAntiAFKToggle = SettingsTab:Toggle({
	Title = "Auto Anti-AFK",
	Desc = "Automatically enable Anti-AFK on start",
	Value = Settings.AutoAntiAFK,
	Callback = function(state)
		Settings.AutoAntiAFK = state
		SaveSettings()
		if state then
			WindUI:Notify({ Title = "Auto Anti-AFK", Content = "Will be enabled on next load", Duration = 2 })
		end
	end,
})

local RememberPositionToggle = SettingsTab:Toggle({
	Title = "Remember Position",
	Desc = "Save UI position between sessions",
	Value = Settings.RememberPosition,
	Callback = function(state)
		Settings.RememberPosition = state
		SaveSettings()
		WindUI:Notify({
			Title = "Position",
			Content = state and "Position will be saved" or "Position won't be saved",
			Duration = 2,
		})
	end,
})

-- SYNC TOGGLES WITH LOADED SETTINGS
-- WindUI might not respect Default parameter, so we force-set the values
task.defer(function()
	if ConfigStatus == "Loaded" then
		getgenv().isSyncingSettings = true -- Suppress notifications

		-- Helper to safely set value
		local function safeSet(obj, value)
			if not obj then
				return
			end
			-- Try SetValue first (most common in modern UI libs)
			local s = pcall(function()
				obj:SetValue(value)
			end)
			if not s then
				s = pcall(function()
					obj:Set(value)
				end)
			end
			if not s then
				pcall(function()
					obj.Value = value
				end)
			end
		end

		-- Sync all settings toggles
		safeSet(ShowNotificationsToggle, Settings.ShowNotifications)
		safeSet(AutoAntiAFKToggle, Settings.AutoAntiAFK)
		safeSet(RememberPositionToggle, Settings.RememberPosition)
		safeSet(PlaybackAntiAFKToggle, Settings.AutoAntiAFK)
		safeSet(ThemeDropdown, Settings.Theme)

		task.wait(0.5) -- Wait for any delayed callbacks
		getgenv().isSyncingSettings = false -- Re-enable notifications
	end
end)

SettingsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- ⚠️ DANGER ZONE
-- ══════════════════════════════════════════════════════════════════
SettingsTab:Section({ Title = "⚠️ Danger Zone", TextSize = 16 })

SettingsTab:Button({
	Title = "🔄 Reset All Settings",
	Desc = "Reset all settings to default",
	Callback = function()
		Settings = {
			AutoAntiAFK = false,
			RememberPosition = false,
			ShowNotifications = true,
			Theme = "Midnight",
		}
		SaveSettings()
		WindUI:Notify({
			Title = "Reset",
			Content = "Settings have been reset! Re-execute script to apply.",
			Duration = 3,
		})
	end,
})

SettingsTab:Button({
	Title = "����️ Clear Cache",
	Desc = "Clear saved data and cache",
	Callback = function()
		pcall(function()
			if delfolder then
				delfolder("StarshipMobile")
				WindUI:Notify({ Title = "✅ Cleared", Content = "Cache has been cleared!", Duration = 2 })
			else
				WindUI:Notify({ Title = "Info", Content = "No cache to clear", Duration = 2 })
			end
		end)
	end,
})

SettingsTab:Space()

SettingsTab:Button({
	Title = "❌ Close Starship",
	Desc = "Close UI and Mini Player completely",
	Callback = function()
		-- Cleanup Mini Player
		if MiniPlayerGui then
			MiniPlayerGui:Destroy()
			MiniPlayerGui = nil
		end
		-- Stop playback
		StopPlayback()
		-- Destroy WindUI Window
		Window:Destroy()
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- SELECT DEFAULT TAB & WELCOME
-- ═════════════════════��════════════════════════════════════════════
DashboardTab:Select()

-- Track window state untuk cleanup
local isWindowDestroyed = false

-- Fungsi cleanup untuk destroy semua
local function CleanupAll()
	if isWindowDestroyed then
		return
	end
	isWindowDestroyed = true

	StopPlayback()
	if MiniPlayerGui then
		MiniPlayerGui:Destroy()
		MiniPlayerGui = nil
	end
end

-- Handle Window Close/Destroy
Window:OnClose(function()
	-- OnClose dipanggil saat minimize - Mini Player TETAP ada
	-- Tidak melakukan cleanup di sini
end)

-- Method 1: OnDestroy callback (jika WindUI support)
pcall(function()
	if Window.OnDestroy then
		Window:OnDestroy(CleanupAll)
	end
end)

-- Method 2: Detect ScreenGui destroy dengan multiple name patterns
task.spawn(function()
	task.wait(0.5) -- Tunggu WindUI selesai setup

	local function findWindUIScreen()
		-- Cari di CoreGui
		local success, coreGui = pcall(function()
			return game:GetService("CoreGui")
		end)
		if success and coreGui then
			for _, gui in ipairs(coreGui:GetChildren()) do
				if gui:IsA("ScreenGui") then
					local name = gui.Name:lower()
					if name:find("windui") or name:find("starship") or name:find("ftgs") then
						return gui
					end
				end
			end
		end

		-- Cari di PlayerGui
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if playerGui then
			for _, gui in ipairs(playerGui:GetChildren()) do
				if gui:IsA("ScreenGui") then
					local name = gui.Name:lower()
					if name:find("windui") or name:find("starship") or name:find("ftgs") then
						return gui
					end
				end
			end
		end

		return nil
	end

	local windUIScreen = findWindUIScreen()

	if windUIScreen then
		-- Connect ke Destroying event
		windUIScreen.Destroying:Connect(CleanupAll)

		-- Juga connect ke AncestryChanged sebagai backup
		windUIScreen.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				CleanupAll()
			end
		end)
	end

	-- Method 3: Polling backup - check setiap 2 detik apakah window masih ada
	task.spawn(function()
		while not isWindowDestroyed do
			task.wait(2)

			-- Check apakah WindUI screen masih exist
			local screen = findWindUIScreen()
			if not screen or not screen.Parent then
				CleanupAll()
				break
			end
		end
	end)
end)

task.delay(1, function()
	-- Single clean welcome notification
	local statusIcon = "✅"
	local statusText = "Ready"

	if ConfigStatus == "Loaded" then
		statusIcon = "✅"
		statusText = "Settings loaded"
	elseif ConfigStatus == "New Config" then
		statusIcon = "🆕"
		statusText = "First run - settings will auto-save"
	elseif ConfigStatus:find("Error") or ConfigStatus:find("No") then
		statusIcon = "⚠️"
		statusText = "Config unavailable"
	end

	OriginalNotify(WindUI, {
		Title = "🚀 Starship Mobile",
		Content = statusIcon .. " " .. statusText,
		Duration = 4,
	})
end)
