local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Dev-only logging helper (only shows in dev mode)
local function DevLog(...)
	if _G.StarshipDebug or (getgenv and getgenv().StarshipSession and getgenv().StarshipSession.DevMode) then
		print("[StarshipCore]", ...)
	end
end

-- UPDATED THEME
local C_MAIN = Color3.fromRGB(10, 10, 14)
local C_SIDE = Color3.fromRGB(15, 15, 20)
local C_ACCENT = Color3.fromRGB(90, 110, 245) -- Midnight Blue
local C_TEXT = Color3.fromRGB(240, 240, 250)
local C_TEXT_DIM = Color3.fromRGB(140, 140, 160)
local C_ITEM = Color3.fromRGB(20, 20, 28)
local C_RED = Color3.fromRGB(255, 80, 80)
local C_YELLOW = Color3.fromRGB(255, 220, 60)
local C_GREEN = Color3.fromRGB(60, 255, 160)

local STARSHIP_ROOT = "StarshipCore"
local CONFIG_FOLDER = STARSHIP_ROOT .. "/StarshipConfigs"
local PROFILE_FOLDER = STARSHIP_ROOT .. "/StarshipProfiles"

-- Ensure parent folder exists first (some executors require this)
if not isfolder(STARSHIP_ROOT) then
	pcall(function()
		makefolder(STARSHIP_ROOT)
	end)
end
if not isfolder(CONFIG_FOLDER) then
	pcall(function()
		makefolder(CONFIG_FOLDER)
	end)
end
if not isfolder(PROFILE_FOLDER) then
	pcall(function()
		makefolder(PROFILE_FOLDER)
	end)
end

-- Multi-Executor Autoexec Support
-- Get Windows username for absolute paths
local function GetWindowsUsername()
	-- Try to get username from environment or common paths
	local username = nil

	-- Method 1: Try reading from a known file path pattern
	local testPaths = {
		"C:/Users/Administrator/AppData/Local",
		"C:/Users/Default/AppData/Local",
	}

	-- Method 2: Check if seliware-autoexec folder exists in common locations
	local commonUsernames = { "Administrator", "User", "Default", os.getenv and os.getenv("USERNAME") or nil }

	for _, uname in ipairs(commonUsernames) do
		if uname then
			local testPath = "C:/Users/" .. uname .. "/AppData/Local/seliware-autoexec"
			if isfolder and pcall(function()
				return isfolder(testPath)
			end) then
				local exists = isfolder(testPath)
				if exists then
					return uname
				end
			end
		end
	end

	-- Fallback to Administrator (most common for Roblox exploits)
	return "Administrator"
end

local WINDOWS_USERNAME = GetWindowsUsername()
local SELIWARE_AUTOEXEC_PATH = "C:/Users/" .. WINDOWS_USERNAME .. "/AppData/Local/seliware-autoexec"

local EXECUTOR_AUTOEXEC_PATHS = {
	-- Format: ["ExecutorName"] = "autoexec_folder_path"
	-- Seliware uses absolute path in AppData
	["Seliware"] = SELIWARE_AUTOEXEC_PATH,
	["Synapse X"] = "autoexec",
	["Synapse Z"] = "autoexec",
	["Script-Ware"] = "autoexec",
	["ScriptWare"] = "autoexec",
	["Fluxus"] = "autoexec",
	["KRNL"] = "autoexec",
	["Krnl"] = "autoexec",
	["Solara"] = "autoexec",
	["Delta"] = "autoexec",
	["Hydrogen"] = "autoexec",
	["Wave"] = "autoexec",
	["Codex"] = "autoexec",
	["Electron"] = "autoexec",
	["Comet"] = "autoexec",
	["Nihon"] = "autoexec",
	["Celery"] = "autoexec",
	["Trigon"] = "autoexec",
	["Vegax"] = "autoexec",
	["Evon"] = "autoexec",
	["JJSploit"] = "autoexec",
	["Oxygen U"] = "autoexec",
	["Temple"] = "autoexec",
	["Arceus X"] = "autoexec", -- Mobile
	["Codex Mobile"] = "autoexec", -- Mobile
	["Fluxus Mobile"] = "autoexec", -- Mobile
	["Delta Mobile"] = "autoexec", -- Mobile
	["Unknown"] = "autoexec", -- Fallback
}

-- Executor name list for dropdown
local EXECUTOR_LIST = {
	"Auto-Detect",
	"Seliware",
	"Synapse X",
	"Synapse Z",
	"Script-Ware",
	"Fluxus",
	"KRNL",
	"Solara",
	"Delta",
	"Hydrogen",
	"Wave",
	"Codex",
	"Electron",
	"Comet",
	"Nihon",
	"Celery",
	"Trigon",
	"Vegax",
	"Evon",
	"JJSploit",
	"Oxygen U",
	"Temple",
	"Arceus X",
	"Codex Mobile",
	"Fluxus Mobile",
	"Delta Mobile",
}

-- Detect current executor
local function DetectExecutor()
	local executorName = "Unknown"

	-- Try identifyexecutor() first (most common)
	if identifyexecutor then
		local success, name, version = pcall(identifyexecutor)
		if success and name then
			executorName = tostring(name)
		end
		-- Try getexecutorname() as fallback
	elseif getexecutorname then
		local success, name = pcall(getexecutorname)
		if success and name then
			executorName = tostring(name)
		end
		-- Try checking for executor-specific globals
	elseif syn then
		executorName = "Synapse X"
	elseif fluxus then
		executorName = "Fluxus"
	elseif KRNL_LOADED then
		executorName = "KRNL"
	elseif Hydrogen then
		executorName = "Hydrogen"
	elseif getgenv().Solara then
		executorName = "Solara"
	end

	return executorName
end

-- Get autoexec folder for executor
local function GetAutoExecFolder(executorName)
	-- If executor is in our mapping, use it
	for name, path in pairs(EXECUTOR_AUTOEXEC_PATHS) do
		if executorName:lower():find(name:lower()) then
			return path
		end
	end
	-- Fallback to default
	return "autoexec"
end

local DetectedExecutor = DetectExecutor()
local AUTOEXEC_FOLDER = GetAutoExecFolder(DetectedExecutor)

-- Check if path is absolute (Windows)
local function IsAbsolutePath(path)
	return path:match("^%a:") ~= nil or path:match("^/") ~= nil
end

-- Ensure autoexec folder exists (handle both relative and absolute paths)
local function EnsureAutoExecFolder(folderPath)
	if not folderPath then
		return false
	end

	-- For absolute paths, we just try to use them (can't create with makefolder)
	if IsAbsolutePath(folderPath) then
		-- Try to check if folder exists, if not, inform user
		if isfolder then
			local success, exists = pcall(function()
				return isfolder(folderPath)
			end)
			if success and exists then
				return true
			end
		end
		-- For Seliware, the folder should already exist if executor is installed
		return true -- Assume it exists, writefile will fail if not
	else
		-- Relative path - create if needed
		if not isfolder(folderPath) then
			pcall(function()
				makefolder(folderPath)
			end)
		end
		return true
	end
end

EnsureAutoExecFolder(AUTOEXEC_FOLDER)

-- Auto Execute Settings
local AUTO_EXEC_FILE = CONFIG_FOLDER .. "/AutoExecSettings.json"
local AutoExecSettings = {
	Enabled = false,
	AutoLoadProfile = "", -- Profile name to auto-load
	DelaySeconds = 1, -- Delay before auto-executing features
	SelectedExecutor = "Auto-Detect", -- User's executor choice
	CustomPath = "", -- Custom autoexec path (for advanced users)
}

-- Load Auto Exec Settings on startup
local function LoadAutoExecSettings()
	-- Dev-only logging
	DevLog("LoadAutoExecSettings called, file:", AUTO_EXEC_FILE)

	if isfile and isfile(AUTO_EXEC_FILE) then
		DevLog("AutoExecSettings.json found, loading...")
		local success, result = pcall(function()
			return HttpService:JSONDecode(readfile(AUTO_EXEC_FILE))
		end)
		if success and result then
			if result.Enabled ~= nil then
				AutoExecSettings.Enabled = result.Enabled
			end
			if result.AutoLoadProfile then
				AutoExecSettings.AutoLoadProfile = result.AutoLoadProfile
			end
			if result.DelaySeconds then
				AutoExecSettings.DelaySeconds = result.DelaySeconds
			end
			if result.SelectedExecutor then
				AutoExecSettings.SelectedExecutor = result.SelectedExecutor
			end
			if result.CustomPath then
				AutoExecSettings.CustomPath = result.CustomPath
			end

			DevLog(
				"AutoExecSettings loaded - Enabled:",
				AutoExecSettings.Enabled,
				"| Profile:",
				AutoExecSettings.AutoLoadProfile,
				"| Delay:",
				AutoExecSettings.DelaySeconds
			)
		else
			warn("[StarshipCore] Failed to parse AutoExecSettings.json")
		end
	else
		DevLog("AutoExecSettings.json NOT FOUND, using defaults")
	end

	-- Update AUTOEXEC_FOLDER based on settings
	-- Priority: Custom Path > Selected Executor > Auto-Detect
	if AutoExecSettings.CustomPath and AutoExecSettings.CustomPath ~= "" then
		AUTOEXEC_FOLDER = AutoExecSettings.CustomPath
	elseif AutoExecSettings.SelectedExecutor and AutoExecSettings.SelectedExecutor ~= "Auto-Detect" then
		AUTOEXEC_FOLDER = GetAutoExecFolder(AutoExecSettings.SelectedExecutor)
	else
		AUTOEXEC_FOLDER = GetAutoExecFolder(DetectedExecutor)
	end

	-- Ensure autoexec folder exists
	EnsureAutoExecFolder(AUTOEXEC_FOLDER)

	return AutoExecSettings
end

-- Get current executor name (detected or selected)
local function GetCurrentExecutorName()
	if AutoExecSettings.SelectedExecutor and AutoExecSettings.SelectedExecutor ~= "Auto-Detect" then
		return AutoExecSettings.SelectedExecutor
	end
	return DetectedExecutor
end

-- Update autoexec folder when executor changes
local function UpdateAutoExecFolder(executorName, customPath)
	-- Priority: Custom Path > Selected Executor > Auto-Detect
	if customPath and customPath ~= "" then
		AUTOEXEC_FOLDER = customPath
	elseif executorName == "Auto-Detect" then
		AUTOEXEC_FOLDER = GetAutoExecFolder(DetectedExecutor)
	else
		AUTOEXEC_FOLDER = GetAutoExecFolder(executorName)
	end

	-- Ensure folder exists
	EnsureAutoExecFolder(AUTOEXEC_FOLDER)
end

local function SaveAutoExecSettings()
	if writefile then
		-- Ensure folder exists before saving
		if not isfolder(CONFIG_FOLDER) then
			pcall(function()
				makefolder(CONFIG_FOLDER)
			end)
		end
		local success, err = pcall(function()
			writefile(AUTO_EXEC_FILE, HttpService:JSONEncode(AutoExecSettings))
		end)
		if not success then
			warn("[StarshipCore] Failed to save AutoExecSettings:", err)
		end
		return success
	end
	return false
end

-- Create autoexec script file for executor
local function CreateAutoExecScript()
	local currentExecutor = GetCurrentExecutorName()
	local delayTime = AutoExecSettings.DelaySeconds or 2

	DevLog("CreateAutoExecScript - Executor:", currentExecutor, "Folder:", AUTOEXEC_FOLDER)

	local scriptContent = string.format(
		[[
-- StarshipCore Auto Execute Script
-- This file is auto-generated. Do not edit manually.
-- Executor: %s
-- Autoexec Folder: %s
-- Generated for: StarshipCore

task.spawn(function()
    task.wait(%d) -- Wait for game to load
    loadstring(game:HttpGet("https://starship-core.my.id/api/bootstrap"))()
end)
]],
		currentExecutor,
		AUTOEXEC_FOLDER,
		delayTime
	)

	if writefile then
		-- Ensure folder exists
		EnsureAutoExecFolder(AUTOEXEC_FOLDER)

		-- Use correct path separator based on path type
		local separator = IsAbsolutePath(AUTOEXEC_FOLDER) and "/" or "/"
		local filePath = AUTOEXEC_FOLDER .. separator .. "StarshipCore_AutoExec.lua"

		local success, err = pcall(function()
			writefile(filePath, scriptContent)
		end)

		if not success then
			-- Try alternative path format for Windows
			filePath = AUTOEXEC_FOLDER:gsub("/", "\\") .. "\\StarshipCore_AutoExec.lua"
			success, err = pcall(function()
				writefile(filePath, scriptContent)
			end)
		end

		if success then
			DevLog("AutoExec script created at:", filePath)
		else
			DevLog("Failed to create AutoExec script:", err)
		end

		return success, filePath
	end
	return false, nil
end

local function RemoveAutoExecScript()
	local path = AUTOEXEC_FOLDER .. "/StarshipCore_AutoExec.lua"
	local removed = false

	-- Try forward slash path first
	if isfile and isfile(path) then
		pcall(function()
			delfile(path)
		end)
		removed = true
	end

	-- Also try Windows backslash path
	local windowsPath = AUTOEXEC_FOLDER:gsub("/", "\\") .. "\\StarshipCore_AutoExec.lua"
	if isfile and isfile(windowsPath) then
		pcall(function()
			delfile(windowsPath)
		end)
		removed = true
	end

	DevLog("RemoveAutoExecScript - Removed:", removed)

	return removed
end

-- Check if autoexec script exists
local function AutoExecScriptExists()
	local path = AUTOEXEC_FOLDER .. "/StarshipCore_AutoExec.lua"
	if isfile then
		if isfile(path) then
			return true
		end
		-- Also check Windows backslash path
		local windowsPath = AUTOEXEC_FOLDER:gsub("/", "\\") .. "\\StarshipCore_AutoExec.lua"
		if isfile(windowsPath) then
			return true
		end
	end
	return false
end

-- Get autoexec status info
local function GetAutoExecStatus()
	local status = {
		Executor = GetCurrentExecutorName(),
		DetectedExecutor = DetectedExecutor,
		AutoExecFolder = AUTOEXEC_FOLDER,
		ScriptExists = AutoExecScriptExists(),
		Enabled = AutoExecSettings.Enabled,
	}
	return status
end

LoadAutoExecSettings()

-- Local flag to track if auto-load has run this session (not using getgenv)
-- This variable is created fresh each time the module loads
local AutoLoadProfileCompleted = false
DevLog("Module loaded, AutoLoadProfileCompleted = false")

-- Feature State Tracking
local FeatureStates = {}
local AutoEnableList = {}

-- Forward declaration for RunAutoEnable
local RunAutoEnable

local function SaveConfig(name, Config, UI)
	if writefile then
		local kbData = {}
		if Config.Keybinds then
			for k, v in pairs(Config.Keybinds) do
				kbData[k] = v.Name
			end
		end

		local data = HttpService:JSONEncode({
			Theme = Config.Theme,
			AccentColor = Config.AccentColor,
			Keybinds = kbData,
		})

		local fileName = name or "Default"
		if not fileName:match("%.json$") then
			fileName = fileName .. ".json"
		end
		writefile(CONFIG_FOLDER .. "/" .. fileName, data)
		if UI and UI.ShowToast then
			UI.ShowToast("Configuration Saved", "Saved config to " .. fileName, "success", 2)
		end
	end
end

local function SaveProfile(name, Config, UI, UIHandlers)
	if writefile then
		local kbData = {}
		if Config.Keybinds then
			for k, v in pairs(Config.Keybinds) do
				kbData[k] = v.Name
			end
		end

		-- Get spoof name from UIHandlers if available
		local spoofName = ""
		local spoofDisplayName = ""
		if UIHandlers and UIHandlers.GetSpoofName then
			spoofName, spoofDisplayName = UIHandlers.GetSpoofName()
		end

		local data = HttpService:JSONEncode({
			Theme = Config.Theme,
			Language = Config.Language or "en",
			AccentColor = Config.AccentColor,
			Keybinds = kbData,
			AutoEnable = AutoEnableList,
			IsAutoLoadProfile = (AutoExecSettings.AutoLoadProfile == name),
			SpoofName = spoofName,
			SpoofDisplayName = spoofDisplayName,
		})

		local fileName = name or "Default"
		if not fileName:match("%.json$") then
			fileName = fileName .. ".json"
		end
		writefile(PROFILE_FOLDER .. "/" .. fileName, data)
		if UI and UI.ShowToast then
			UI.ShowToast("Profile Saved", "Saved to " .. fileName, "success", 2)
		end
	end
end

local function LoadProfile(name, Config, Themes, UI, UIHandlers, suppressToast)
	local fileName = name or "Default"
	if not fileName:match("%.json$") then
		fileName = fileName .. ".json"
	end
	local path = PROFILE_FOLDER .. "/" .. fileName

	if isfile and isfile(path) then
		local success, result = pcall(function()
			return HttpService:JSONDecode(readfile(path))
		end)
		if success and result then
			if result.Theme and Themes[result.Theme] then
				Config.Theme = result.Theme
			end
			if result.Language then
				Config.Language = result.Language
				-- Update Locale module
				if _G.StarshipLocale and _G.StarshipLocale.SetLanguage then
					_G.StarshipLocale.SetLanguage(result.Language)
				end
			end
			if result.AccentColor then
				Config.AccentColor = result.AccentColor
			end

			-- Load Spoof Name settings
			if UIHandlers and UIHandlers.SetSpoofName then
				local spoofName = result.SpoofName or ""
				local spoofDisplayName = result.SpoofDisplayName or ""
				UIHandlers.SetSpoofName(spoofName, spoofDisplayName)
			end

			if result.Keybinds then
				if not Config.Keybinds then
					Config.Keybinds = {}
				end
				for k, v in pairs(result.Keybinds) do
					if Enum.KeyCode[v] then
						Config.Keybinds[k] = Enum.KeyCode[v]
					end
				end
			end

			-- Load Auto-Enable List
			local hasAutoEnable = false
			if result.AutoEnable and #result.AutoEnable > 0 then
				-- Clear existing AutoEnableList while keeping the same table reference
				for i = #AutoEnableList, 1, -1 do
					table.remove(AutoEnableList, i)
				end
				-- Populate with new values
				for _, id in ipairs(result.AutoEnable) do
					table.insert(AutoEnableList, id)
				end
				hasAutoEnable = true

				-- Update UIHandlers reference to ensure it's synced
				if UIHandlers then
					UIHandlers.AutoEnableList = AutoEnableList
				end

				-- Immediately run auto-enable features
				if RunAutoEnable and UIHandlers then
					task.spawn(function()
						task.wait(0.3) -- Small delay to ensure UI is ready
						RunAutoEnable(UIHandlers)
					end)
				end
			end

			if UI and UI.ShowToast and not suppressToast then
				local msg = hasAutoEnable
						and "Loaded: " .. fileName .. "\nAuto-enabling " .. #AutoEnableList .. " feature(s)..."
					or "Loaded: " .. fileName
				UI.ShowToast("Profile Loaded", msg, "success", 3)
			end

			-- Refresh keybind UI after loading
			if UI and UI.RefreshKeybindUI then
				UI.RefreshKeybindUI()
			end

			return true, result
		end
	end
	return false, nil
end

local function LoadConfig(name, Config, Themes)
	local fileName = name or "Default"
	if not fileName:match("%.json$") then
		fileName = fileName .. ".json"
	end
	local path = CONFIG_FOLDER .. "/" .. fileName

	if isfile and isfile(path) then
		local success, result = pcall(function()
			return HttpService:JSONDecode(readfile(path))
		end)
		if success and result then
			if result.Theme and Themes[result.Theme] then
				Config.Theme = result.Theme
			end
			if result.AccentColor then
				Config.AccentColor = result.AccentColor
			end
			if result.Keybinds then
				if not Config.Keybinds then
					Config.Keybinds = {}
				end
				for k, v in pairs(result.Keybinds) do
					if Enum.KeyCode[v] then
						Config.Keybinds[k] = Enum.KeyCode[v]
					end
				end
			end
		end
	end

	if not Config.Keybinds then
		Config.Keybinds = {
			StartRecording = Enum.KeyCode.F5,
			PauseRecording = Enum.KeyCode.F6,
			TogglePath = Enum.KeyCode.F8,
			PlayPlayback = Enum.KeyCode.Z,
			StopPlayback = Enum.KeyCode.X,
			FollowPlayer = Enum.KeyCode.G,
			ToggleMinimize = Enum.KeyCode.RightControl,
			ToggleShiftLock = Enum.KeyCode.LeftShift,
		}
	end
end

-- Preload spoof name BEFORE main UI shows (called from StarshipCore before StartLoader)
local function PreloadSpoofName(UIHandlers, Config, Themes, UI)
	-- Check if auto-exec is enabled and has a profile to load
	if not AutoExecSettings.Enabled or AutoExecSettings.AutoLoadProfile == "" then
		if getgenv then
			getgenv().StarshipSpoofReady = true
			getgenv().StarshipSpoofInProgress = false
		end
		return false
	end

	-- Load the profile data to check if it has SpoofName in auto-enable
	local fileName = AutoExecSettings.AutoLoadProfile
	if not fileName:match("%.json$") then
		fileName = fileName .. ".json"
	end
	local path = PROFILE_FOLDER .. "/" .. fileName

	if not isfile or not isfile(path) then
		if getgenv then
			getgenv().StarshipSpoofReady = true
			getgenv().StarshipSpoofInProgress = false
		end
		return false
	end

	local success, result = pcall(function()
		local content = readfile(path)
		return HttpService:JSONDecode(content)
	end)

	if not success or not result then
		if getgenv then
			getgenv().StarshipSpoofReady = true
			getgenv().StarshipSpoofInProgress = false
		end
		return false
	end

	-- Check if SpoofName is in the auto-enable list
	local hasSpoofName = false
	if result.AutoEnable then
		for _, id in ipairs(result.AutoEnable) do
			if id == "SpoofName" then
				hasSpoofName = true
				break
			end
		end
	end

	if not hasSpoofName then
		if getgenv then
			getgenv().StarshipSpoofReady = true
			getgenv().StarshipSpoofInProgress = false
		end
		return false
	end

	-- Has SpoofName - set flag and apply it
	if getgenv then
		getgenv().StarshipSpoofInProgress = true
		getgenv().StarshipSpoofReady = false
	end

	-- Set the spoof name values first
	if result.SpoofName and UIHandlers and UIHandlers.SetSpoofName then
		local spoofName = result.SpoofName or ""
		local spoofDisplayName = result.SpoofDisplayName or ""
		UIHandlers.SetSpoofName(spoofName, spoofDisplayName)
	end

	-- Load AutoEnableList from profile
	if result.AutoEnable then
		-- Clear and reload AutoEnableList
		for i = #AutoEnableList, 1, -1 do
			table.remove(AutoEnableList, i)
		end
		for _, id in ipairs(result.AutoEnable) do
			table.insert(AutoEnableList, id)
		end
	end

	-- Enable spoof name
	if UIHandlers and UIHandlers.ToggleSpoofName then
		UIHandlers.ToggleSpoofName(true)
	end

	-- Wait for spoof to apply
	task.wait(0.5)

	-- Mark as ready
	if getgenv then
		getgenv().StarshipSpoofInProgress = false
		getgenv().StarshipSpoofReady = true
	end

	-- Store that we preloaded so we don't reload again
	if getgenv then
		getgenv().StarshipProfilePreloaded = true
		getgenv().StarshipPreloadedProfile = AutoExecSettings.AutoLoadProfile
	end

	return true
end

RunAutoEnable = function(UIHandlers)
	-- Check if SpoofName is in the auto-enable list
	local hasSpoofName = false
	for _, id in ipairs(AutoEnableList) do
		if id == "SpoofName" then
			hasSpoofName = true
			break
		end
	end

	-- If SpoofName is enabled, run it FIRST and wait for it to complete
	if hasSpoofName and UIHandlers and UIHandlers.ToggleSpoofName then
		-- Set flag to indicate spoof is in progress
		if getgenv then
			getgenv().StarshipSpoofInProgress = true
			getgenv().StarshipSpoofReady = false
		end

		-- Enable spoof name first
		UIHandlers.ToggleSpoofName(true)

		-- Wait for spoof to apply to all elements
		task.wait(0.5)

		-- Set flag to indicate spoof is ready
		if getgenv then
			getgenv().StarshipSpoofInProgress = false
			getgenv().StarshipSpoofReady = true
		end
	else
		-- No spoof name, mark as ready immediately
		if getgenv then
			getgenv().StarshipSpoofReady = true
		end
	end

	-- Run other auto-enable features (excluding SpoofName since it's already done)
	for _, id in ipairs(AutoEnableList) do
		if id ~= "SpoofName" then
			local handlerName = "Toggle" .. id
			if UIHandlers and UIHandlers[handlerName] then
				task.spawn(function()
					task.wait(0.3)
					UIHandlers[handlerName](true)
				end)
			end
		end
	end
end

local function SetFeatureState(id, enabled)
	FeatureStates[id] = enabled
end

local function GetFeatureState(id)
	return FeatureStates[id] or false
end

local function SetupConfigUI(PageConfig, UI, Connections, Config, LocalPlayer, UIHandlers, Themes, ThemeObjects, Main)
	-- Helper function to get localized text
	local function L(key, ...)
		if _G.StarshipLocale and _G.StarshipLocale.Get then
			return _G.StarshipLocale.Get(key, ...)
		end
		return key
	end

	local function RegisterTheme(obj, prop, type)
		table.insert(ThemeObjects, { Object = obj, Property = prop, Type = type })
	end

	PageConfig:ClearAllChildren()
	local ConfigScroll = Instance.new("ScrollingFrame", PageConfig)
	ConfigScroll.Size = UDim2.new(1, 0, 1, 0)
	ConfigScroll.BackgroundTransparency = 1
	ConfigScroll.BorderSizePixel = 0
	ConfigScroll.ScrollBarThickness = 4
	ConfigScroll.ScrollBarImageColor3 = C_ACCENT
	ConfigScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	ConfigScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	RegisterTheme(ConfigScroll, "ScrollBarImageColor3")

	local ConfigLayout = Instance.new("UIListLayout", ConfigScroll)
	ConfigLayout.Padding = UDim.new(0, 15)
	ConfigLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ConfigLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function CreateCard(t, h, o)
		local c = Instance.new("Frame", ConfigScroll)
		c.Size = UDim2.new(0.96, 0, 0, h)
		c.BackgroundColor3 = C_ITEM
		c.LayoutOrder = o
		Instance.new("UICorner", c).CornerRadius = UDim.new(0, 12)
		local s = Instance.new("UIStroke", c)
		s.Color = C_ACCENT
		s.Transparency = 0.8
		s.Thickness = 1
		local l = Instance.new("TextLabel", c)
		l.Text = t
		l.Size = UDim2.new(1, -20, 0, 30)
		l.Position = UDim2.new(0, 15, 0, 0)
		l.BackgroundTransparency = 1
		l.TextColor3 = C_TEXT_DIM
		l.Font = Enum.Font.GothamBold
		l.TextSize = 11
		l.TextXAlignment = Enum.TextXAlignment.Left

		RegisterTheme(c, "BackgroundColor3", "Item")
		RegisterTheme(s, "Color", "Accent")
		RegisterTheme(l, "TextColor3", "TextDim")
		return c
	end

	local function StyleBtn(btn, col)
		btn.BackgroundColor3 = C_SIDE
		btn.TextColor3 = col
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 10
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		local s = Instance.new("UIStroke", btn)
		s.Color = col
		s.Transparency = 0.7
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		RegisterTheme(btn, "BackgroundColor3", "Side")
		-- Note: TextColor3 and Stroke Color here are variable (col), so we can't easily register them to a single theme type unless we know 'col' is always one of the theme colors.
		-- For ConfigTab, they are usually C_TEXT or C_ACCENT.
		if col == C_ACCENT then
			RegisterTheme(btn, "TextColor3", "Accent")
			RegisterTheme(s, "Color", "Accent")
		elseif col == C_TEXT then
			RegisterTheme(btn, "TextColor3", "Text")
			RegisterTheme(s, "Color", "Text")
		end
	end

	-- KEYBIND SETTINGS CARD
	local KBCard = CreateCard(L("keybinds"), 0, 1)
	KBCard.AutomaticSize = Enum.AutomaticSize.Y

	local KBList = Instance.new("Frame", KBCard)
	KBList.Size = UDim2.new(1, 0, 0, 0)
	KBList.Position = UDim2.new(0, 0, 0, 45)
	KBList.BackgroundTransparency = 1
	KBList.AutomaticSize = Enum.AutomaticSize.Y

	local KBLayout = Instance.new("UIListLayout", KBList)
	KBLayout.Padding = UDim.new(0, 5)
	KBLayout.SortOrder = Enum.SortOrder.LayoutOrder
	KBLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local isBinding = false

	-- Use _G for global binding state so all modules can check
	_G.StarshipIsBindingKeybind = false

	-- Expose isBinding state to UI so other modules can check
	if UI then
		UI.IsBindingKeybind = function()
			return isBinding or _G.StarshipIsBindingKeybind
		end
	end

	-- Store keybind buttons for refreshing after profile load
	local keybindButtons = {}

	local function RefreshKeybindUI()
		for keyKey, btn in pairs(keybindButtons) do
			if Config.Keybinds and Config.Keybinds[keyKey] then
				btn.Text = Config.Keybinds[keyKey].Name
			else
				btn.Text = "None"
			end
		end
	end

	local function CreateBindRow(keyKey, labelText)
		local row = Instance.new("Frame", KBList)
		row.Size = UDim2.new(0.95, 0, 0, 30)
		row.BackgroundColor3 = C_SIDE
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		RegisterTheme(row, "BackgroundColor3", "Side")

		local lbl = Instance.new("TextLabel", row)
		lbl.Text = labelText
		lbl.Size = UDim2.new(0.6, 0, 1, 0)
		lbl.Position = UDim2.new(0.05, 0, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = C_TEXT
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 10
		RegisterTheme(lbl, "TextColor3", "Text")

		local btn = Instance.new("TextButton", row)
		local keyName = "None"
		if Config.Keybinds and Config.Keybinds[keyKey] then
			keyName = Config.Keybinds[keyKey].Name
		end
		btn.Text = keyName

		-- Store button reference for refresh
		keybindButtons[keyKey] = btn
		btn.Size = UDim2.new(0.35, 0, 1, 0)
		btn.Position = UDim2.new(0.65, 0, 0, 0)
		btn.BackgroundColor3 = C_ITEM
		btn.TextColor3 = C_ACCENT
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		RegisterTheme(btn, "BackgroundColor3", "Item")
		RegisterTheme(btn, "TextColor3", "Accent")

		btn.MouseButton1Click:Connect(function()
			if isBinding then
				return
			end
			isBinding = true
			_G.StarshipIsBindingKeybind = true
			btn.Text = "..."
			btn.TextColor3 = C_YELLOW

			-- Small delay to ensure global state is set before listening
			local bindingReady = false
			task.delay(0.1, function()
				bindingReady = true
			end)

			local con
			con = UserInputService.InputBegan:Connect(function(input)
				-- Ignore inputs until binding is ready
				if not bindingReady then
					return
				end
				if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType.Name:find("Gamepad") then
					if input.KeyCode ~= Enum.KeyCode.Unknown then
						-- Check for duplicate keybind
						local duplicateKey = nil
						for otherKey, otherKeyCode in pairs(Config.Keybinds) do
							if otherKey ~= keyKey and otherKeyCode == input.KeyCode then
								duplicateKey = otherKey
								break
							end
						end

						if duplicateKey then
							-- Show warning and reject duplicate
							btn.Text = Config.Keybinds[keyKey] and Config.Keybinds[keyKey].Name or "None"
							btn.TextColor3 = C_ACCENT
							con:Disconnect()
							-- Keep binding state true a bit longer to prevent triggering
							task.delay(0.2, function()
								isBinding = false
								_G.StarshipIsBindingKeybind = false
							end)
							if UI and UI.ShowToast then
								UI.ShowToast(
									"Duplicate Keybind",
									"'" .. input.KeyCode.Name .. "' is already used by another action!",
									"error",
									3
								)
							end
						else
							-- Valid keybind, apply it (no auto save - user must save profile manually)
							Config.Keybinds[keyKey] = input.KeyCode
							btn.Text = input.KeyCode.Name
							btn.TextColor3 = C_ACCENT
							con:Disconnect()
							-- Keep binding state true a bit longer to prevent triggering
							task.delay(0.2, function()
								isBinding = false
								_G.StarshipIsBindingKeybind = false
							end)
						end
					end
				end
			end)
		end)
	end

	CreateBindRow("StartRecording", L("start_recording"))
	CreateBindRow("PauseRecording", L("pause_recording"))
	CreateBindRow("TogglePath", L("toggle_path"))
	CreateBindRow("PlayPlayback", L("play_playback"))
	CreateBindRow("StopPlayback", L("stop_playback"))
	CreateBindRow("FollowPlayer", L("follow_player"))
	CreateBindRow("ToggleShiftLock", L("toggle_shift_lock"))
	CreateBindRow("ToggleAntiSlip", L("toggle_anti_slip"))
	CreateBindRow("ToggleAutoJump", L("toggle_auto_jump"))
	CreateBindRow("ToggleQuickBoost", L("toggle_quick_boost"))
	CreateBindRow("ToggleRealESP", L("toggle_real_esp"))
	CreateBindRow("ToggleAntiDelay", L("toggle_anti_delay"))
	CreateBindRow("ToggleHabeg", "Toggle Habeg (Jump Bug)")
	CreateBindRow("ToggleHabegAction", "Habeg Action Key")
	CreateBindRow("ToggleMinimize", L("minimize_ui"))

	-- Expose RefreshKeybindUI to UI for profile loading
	if UI then
		UI.RefreshKeybindUI = RefreshKeybindUI
	end

	-- THEME CARD
	local ThemeCard = CreateCard(L("themes"), 0, 2)
	ThemeCard.AutomaticSize = Enum.AutomaticSize.Y

	local ThemeContainer = Instance.new("Frame", ThemeCard)
	ThemeContainer.Size = UDim2.new(0.9, 0, 0, 0)
	ThemeContainer.Position = UDim2.new(0.05, 0, 0, 35)
	ThemeContainer.BackgroundTransparency = 1
	ThemeContainer.AutomaticSize = Enum.AutomaticSize.Y

	local ThemeLayout = Instance.new("UIGridLayout", ThemeContainer)
	ThemeLayout.CellSize = UDim2.new(0.48, 0, 0, 35)
	ThemeLayout.CellPadding = UDim2.new(0.02, 0, 0, 5)
	ThemeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ThemeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function ApplyTheme(name)
		if not Themes[name] then
			return
		end
		Config.Theme = name
		local t = Themes[name]

		-- Update Global Colors (Locals in this scope)
		C_MAIN = t.Main
		C_SIDE = t.Side
		C_ACCENT = t.Accent
		C_ITEM = t.Item
		C_TEXT = t.Text
		C_TEXT_DIM = t.TextDim or Color3.fromRGB(140, 140, 160)

		if Config.AccentColor then
			C_ACCENT = Color3.fromRGB(Config.AccentColor.R, Config.AccentColor.G, Config.AccentColor.B)
		end

		-- Update global StarshipColors for dynamic access
		if _G.StarshipColors then
			_G.StarshipColors.MAIN = C_MAIN
			_G.StarshipColors.SIDE = C_SIDE
			_G.StarshipColors.ACCENT = C_ACCENT
			_G.StarshipColors.ITEM = C_ITEM
			_G.StarshipColors.TEXT = C_TEXT
			_G.StarshipColors.TEXT_DIM = C_TEXT_DIM
		end

		-- Update Registered Objects
		for _, item in ipairs(ThemeObjects) do
			local obj, prop, type = item.Object, item.Property, item.Type
			if obj and obj.Parent then
				if prop == "BackgroundColor3" then
					if type == "Main" then
						obj.BackgroundColor3 = C_MAIN
					elseif type == "Side" then
						obj.BackgroundColor3 = C_SIDE
					elseif type == "Item" then
						obj.BackgroundColor3 = C_ITEM
					elseif type == "Accent" then
						obj.BackgroundColor3 = C_ACCENT
						-- Legacy/Fallback Logic
					elseif obj == Main then
						obj.BackgroundColor3 = C_MAIN
					elseif obj.Name == "Sidebar" then
						obj.BackgroundColor3 = C_SIDE
					else
						obj.BackgroundColor3 = C_ACCENT
					end
				elseif prop == "TextColor3" then
					if type == "Text" then
						obj.TextColor3 = C_TEXT
					elseif type == "TextDim" then
						obj.TextColor3 = C_TEXT_DIM
					elseif type == "Accent" then
						obj.TextColor3 = C_ACCENT
					else
						obj.TextColor3 = C_TEXT
					end
				elseif prop == "ScrollBarImageColor3" then
					obj.ScrollBarImageColor3 = C_ACCENT
				elseif prop == "ImageColor3" then
					obj.ImageColor3 = C_ACCENT
				elseif prop == "Color" then -- For UIStroke
					if type == "Accent" then
						obj.Color = C_ACCENT
					elseif type == "Text" then
						obj.Color = C_TEXT
					elseif type == "TextDim" then
						obj.Color = C_TEXT_DIM
					else
						obj.Color = C_ACCENT
					end
				end
			end
		end
	end

	for name, themeData in pairs(Themes) do
		local btn = Instance.new("TextButton", ThemeContainer)
		btn.Text = name
		btn.BackgroundColor3 = C_SIDE
		btn.TextColor3 = themeData.Accent
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 10
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", btn)
		stroke.Color = themeData.Accent
		stroke.Transparency = 0.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		btn.MouseButton1Click:Connect(function()
			local t = Themes[name]
			Config.AccentColor = {
				R = math.floor(t.Accent.R * 255),
				G = math.floor(t.Accent.G * 255),
				B = math.floor(t.Accent.B * 255),
			}
			ApplyTheme(name)
			-- Refresh Merger List to apply new theme colors
			if UIHandlers and UIHandlers.RefreshMergerList then
				UIHandlers.RefreshMergerList()
			end
			btn.Text = "APPLIED!"
			task.wait(0.5)
			btn.Text = name
		end)
	end

	-- LANGUAGE SELECTOR CARD
	local LanguageCard = CreateCard(L("language"), 90, 3)

	local LangLabel = Instance.new("TextLabel", LanguageCard)
	LangLabel.Text = L("select_language") .. ":"
	LangLabel.Size = UDim2.new(0.4, 0, 0, 30)
	LangLabel.Position = UDim2.new(0.05, 0, 0, 35)
	LangLabel.BackgroundTransparency = 1
	LangLabel.TextColor3 = C_TEXT
	LangLabel.Font = Enum.Font.Gotham
	LangLabel.TextSize = 11
	LangLabel.TextXAlignment = Enum.TextXAlignment.Left
	RegisterTheme(LangLabel, "TextColor3", "Text")

	local LangContainer = Instance.new("Frame", LanguageCard)
	LangContainer.Size = UDim2.new(0.5, 0, 0, 35)
	LangContainer.Position = UDim2.new(0.45, 0, 0, 35)
	LangContainer.BackgroundTransparency = 1

	local LangLayout = Instance.new("UIListLayout", LangContainer)
	LangLayout.FillDirection = Enum.FillDirection.Horizontal
	LangLayout.Padding = UDim.new(0, 8)
	LangLayout.SortOrder = Enum.SortOrder.LayoutOrder
	LangLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	-- Language buttons
	local languages = {
		{ code = "en", name = "English", flag = "🇺🇸" },
		{ code = "id", name = "Indonesia", flag = "🇮🇩" },
	}

	-- Load saved language preference
	local currentLang = Config.Language or "en"
	pcall(function()
		if isfile(CONFIG_FOLDER .. "/Language.json") then
			local langData = HttpService:JSONDecode(readfile(CONFIG_FOLDER .. "/Language.json"))
			if langData and langData.Language then
				currentLang = langData.Language
				Config.Language = currentLang
				-- Also update Locale module
				if _G.StarshipLocale and _G.StarshipLocale.SetLanguage then
					_G.StarshipLocale.SetLanguage(currentLang)
				end
			end
		end
	end)

	local langButtons = {}
	for i, lang in ipairs(languages) do
		local langBtn = Instance.new("TextButton", LangContainer)
		langBtn.Text = lang.flag .. " " .. lang.name
		langBtn.Size = UDim2.new(0, 90, 0, 30)
		langBtn.BackgroundColor3 = (currentLang == lang.code) and C_ACCENT or C_SIDE
		langBtn.TextColor3 = C_TEXT
		langBtn.Font = Enum.Font.GothamBold
		langBtn.TextSize = 10
		langBtn.LayoutOrder = i
		Instance.new("UICorner", langBtn).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", langBtn)
		stroke.Color = C_ACCENT
		stroke.Transparency = (currentLang == lang.code) and 0 or 0.7
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		RegisterTheme(langBtn, "TextColor3", "Text")
		RegisterTheme(stroke, "Color", "Accent")

		langButtons[lang.code] = { btn = langBtn, stroke = stroke }

		langBtn.MouseButton1Click:Connect(function()
			-- Update config
			Config.Language = lang.code

			-- Update Locale module if available
			if _G.StarshipLocale and _G.StarshipLocale.SetLanguage then
				_G.StarshipLocale.SetLanguage(lang.code)
			end

			-- Save language preference to file immediately
			local langConfig = { Language = lang.code }
			pcall(function()
				writefile(CONFIG_FOLDER .. "/Language.json", HttpService:JSONEncode(langConfig))
			end)

			-- Update button visuals
			for code, data in pairs(langButtons) do
				if code == lang.code then
					data.btn.BackgroundColor3 = C_ACCENT
					data.stroke.Transparency = 0
				else
					data.btn.BackgroundColor3 = C_SIDE
					data.stroke.Transparency = 0.7
				end
			end

			-- Show toast with success notice (no restart needed - reactive refresh)
			if UI and UI.ShowToast then
				UI.ShowToast(L("language"), L("language_changed"), "success", 2)
			end
		end)
	end

	-- PROFILE SYSTEM CARD
	local ProfileCard = CreateCard(L("profile") .. " SYSTEM", 250, 4)

	local ProfileInfo = Instance.new("TextLabel", ProfileCard)
	ProfileInfo.Text = "Profiles save ALL settings + enabled features"
	ProfileInfo.Size = UDim2.new(0.9, 0, 0, 15)
	ProfileInfo.Position = UDim2.new(0.05, 0, 0, 30)
	ProfileInfo.BackgroundTransparency = 1
	ProfileInfo.TextColor3 = C_TEXT_DIM
	ProfileInfo.Font = Enum.Font.Gotham
	ProfileInfo.TextSize = 9
	ProfileInfo.TextXAlignment = Enum.TextXAlignment.Left

	local ProfileInput = Instance.new("TextBox", ProfileCard)
	ProfileInput.PlaceholderText = "Profile Name"
	ProfileInput.Size = UDim2.new(0.65, 0, 0, 35)
	ProfileInput.Position = UDim2.new(0.05, 0, 0, 50)
	ProfileInput.BackgroundColor3 = C_SIDE
	ProfileInput.TextColor3 = C_TEXT
	ProfileInput.PlaceholderColor3 = C_TEXT_DIM
	ProfileInput.Font = Enum.Font.Gotham
	ProfileInput.TextSize = 11
	Instance.new("UICorner", ProfileInput).CornerRadius = UDim.new(0, 6)
	RegisterTheme(ProfileInput, "BackgroundColor3", "Side")
	RegisterTheme(ProfileInput, "TextColor3", "Text")

	local BtnRefreshProfile = Instance.new("TextButton", ProfileCard)
	BtnRefreshProfile.Text = "REFRESH"
	BtnRefreshProfile.Size = UDim2.new(0.25, 0, 0, 35)
	BtnRefreshProfile.Position = UDim2.new(0.72, 0, 0, 50)
	StyleBtn(BtnRefreshProfile, C_TEXT)

	local ProfileList = Instance.new("ScrollingFrame", ProfileCard)
	ProfileList.Size = UDim2.new(0.9, 0, 0, 80)
	ProfileList.Position = UDim2.new(0.05, 0, 0, 90)
	ProfileList.BackgroundColor3 = C_SIDE
	ProfileList.BorderSizePixel = 0
	ProfileList.ScrollBarThickness = 4
	ProfileList.ScrollBarImageColor3 = C_ACCENT
	Instance.new("UICorner", ProfileList).CornerRadius = UDim.new(0, 6)
	RegisterTheme(ProfileList, "BackgroundColor3", "Side")
	RegisterTheme(ProfileList, "ScrollBarImageColor3", "Accent")

	local ProfileLayout = Instance.new("UIListLayout", ProfileList)
	ProfileLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ProfileLayout.Padding = UDim.new(0, 2)

	local function RefreshProfiles()
		for _, c in pairs(ProfileList:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		if isfolder(PROFILE_FOLDER) then
			for _, file in pairs(listfiles(PROFILE_FOLDER)) do
				if file:match("%.json$") then
					local name = file:match("([^/\\]+)%.json$")
					local btn = Instance.new("TextButton", ProfileList)
					btn.Text = name
					btn.Size = UDim2.new(1, -5, 0, 25)
					btn.BackgroundColor3 = C_SIDE
					btn.TextColor3 = C_TEXT_DIM
					btn.Font = Enum.Font.Gotham
					btn.TextSize = 10
					btn.TextXAlignment = Enum.TextXAlignment.Left
					Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
					RegisterTheme(btn, "BackgroundColor3", "Side")
					RegisterTheme(btn, "TextColor3", "TextDim")

					btn.MouseButton1Click:Connect(function()
						ProfileInput.Text = name
					end)
				end
			end
			ProfileList.CanvasSize = UDim2.new(0, 0, 0, #ProfileList:GetChildren() * 27)
		end
	end

	BtnRefreshProfile.MouseButton1Click:Connect(RefreshProfiles)
	RefreshProfiles()

	local BtnSaveProfile = Instance.new("TextButton", ProfileCard)
	BtnSaveProfile.Text = "SAVE PROFILE"
	BtnSaveProfile.Size = UDim2.new(0.4, 0, 0, 35)
	BtnSaveProfile.Position = UDim2.new(0.05, 0, 0, 175)
	StyleBtn(BtnSaveProfile, C_GREEN)

	local BtnLoadProfile = Instance.new("TextButton", ProfileCard)
	BtnLoadProfile.Text = "LOAD PROFILE"
	BtnLoadProfile.Size = UDim2.new(0.4, 0, 0, 35)
	BtnLoadProfile.Position = UDim2.new(0.55, 0, 0, 175)
	StyleBtn(BtnLoadProfile, C_ACCENT)

	BtnSaveProfile.MouseButton1Click:Connect(function()
		local name = ProfileInput.Text
		if name == "" then
			name = "Default"
		end
		SaveProfile(name, Config, UI, UIHandlers)
		BtnSaveProfile.Text = "SAVED!"
		RefreshProfiles()
		task.wait(1)
		BtnSaveProfile.Text = "SAVE PROFILE"
	end)

	BtnLoadProfile.MouseButton1Click:Connect(function()
		local name = ProfileInput.Text
		if name == "" then
			name = "Default"
		end
		local success = LoadProfile(name, Config, Themes, UI, UIHandlers)
		if success then
			-- Re-setup entire UI to refresh keybinds
			SetupConfigUI(PageConfig, UI, Connections, Config, LocalPlayer, UIHandlers, Themes, ThemeObjects, Main)
		end
	end)

	-- AUTO-ENABLE CARD
	local AutoCard = CreateCard("AUTO-ENABLE ON STARTUP", 0, 5)
	AutoCard.AutomaticSize = Enum.AutomaticSize.Y

	-- AUTO EXECUTE CARD (NEW!)
	local AutoExecCard = CreateCard("⚡ AUTO EXECUTE", 0, 3)
	AutoExecCard.AutomaticSize = Enum.AutomaticSize.Y

	local AutoExecInfo = Instance.new("TextLabel", AutoExecCard)
	AutoExecInfo.Text = "Auto-run StarshipCore when game starts (no manual execute needed)"
	AutoExecInfo.Size = UDim2.new(0.9, 0, 0, 15)
	AutoExecInfo.Position = UDim2.new(0.05, 0, 0, 30)
	AutoExecInfo.BackgroundTransparency = 1
	AutoExecInfo.TextColor3 = C_TEXT_DIM
	AutoExecInfo.Font = Enum.Font.Gotham
	AutoExecInfo.TextSize = 9
	AutoExecInfo.TextXAlignment = Enum.TextXAlignment.Left

	local AutoExecContainer = Instance.new("Frame", AutoExecCard)
	AutoExecContainer.Size = UDim2.new(0.9, 0, 0, 0)
	AutoExecContainer.Position = UDim2.new(0.05, 0, 0, 50)
	AutoExecContainer.BackgroundTransparency = 1
	AutoExecContainer.AutomaticSize = Enum.AutomaticSize.Y

	local AutoExecLayout = Instance.new("UIListLayout", AutoExecContainer)
	AutoExecLayout.Padding = UDim.new(0, 8)
	AutoExecLayout.SortOrder = Enum.SortOrder.LayoutOrder

	-- Enable Auto Execute Toggle Row
	local EnableRow = Instance.new("Frame", AutoExecContainer)
	EnableRow.Size = UDim2.new(1, 0, 0, 35)
	EnableRow.BackgroundColor3 = C_SIDE
	EnableRow.LayoutOrder = 1
	Instance.new("UICorner", EnableRow).CornerRadius = UDim.new(0, 6)
	RegisterTheme(EnableRow, "BackgroundColor3", "Side")

	local EnableLabel = Instance.new("TextLabel", EnableRow)
	EnableLabel.Text = "Enable Auto Execute"
	EnableLabel.Size = UDim2.new(0.65, 0, 1, 0)
	EnableLabel.Position = UDim2.new(0.05, 0, 0, 0)
	EnableLabel.BackgroundTransparency = 1
	EnableLabel.TextColor3 = C_TEXT
	EnableLabel.Font = Enum.Font.GothamBold
	EnableLabel.TextSize = 11
	EnableLabel.TextXAlignment = Enum.TextXAlignment.Left
	RegisterTheme(EnableLabel, "TextColor3", "Text")

	local EnableToggle = Instance.new("TextButton", EnableRow)
	EnableToggle.Size = UDim2.new(0, 60, 0, 25)
	EnableToggle.Position = UDim2.new(0.75, 0, 0.5, -12)
	EnableToggle.BackgroundColor3 = AutoExecSettings.Enabled and C_GREEN or C_ITEM
	EnableToggle.Text = AutoExecSettings.Enabled and "ON" or "OFF"
	EnableToggle.TextColor3 = C_TEXT
	EnableToggle.Font = Enum.Font.GothamBold
	EnableToggle.TextSize = 10
	Instance.new("UICorner", EnableToggle).CornerRadius = UDim.new(0, 4)
	RegisterTheme(EnableToggle, "TextColor3", "Text")

	-- Auto Load Profile Row
	local ProfileRow = Instance.new("Frame", AutoExecContainer)
	ProfileRow.Size = UDim2.new(1, 0, 0, 35)
	ProfileRow.BackgroundColor3 = C_SIDE
	ProfileRow.LayoutOrder = 2
	Instance.new("UICorner", ProfileRow).CornerRadius = UDim.new(0, 6)
	RegisterTheme(ProfileRow, "BackgroundColor3", "Side")

	local ProfileLabel = Instance.new("TextLabel", ProfileRow)
	ProfileLabel.Text = "Auto-Load Profile:"
	ProfileLabel.Size = UDim2.new(0.4, 0, 1, 0)
	ProfileLabel.Position = UDim2.new(0.05, 0, 0, 0)
	ProfileLabel.BackgroundTransparency = 1
	ProfileLabel.TextColor3 = C_TEXT
	ProfileLabel.Font = Enum.Font.Gotham
	ProfileLabel.TextSize = 10
	ProfileLabel.TextXAlignment = Enum.TextXAlignment.Left
	RegisterTheme(ProfileLabel, "TextColor3", "Text")

	local ProfileDropdown = Instance.new("TextButton", ProfileRow)
	ProfileDropdown.Size = UDim2.new(0.5, 0, 0, 25)
	ProfileDropdown.Position = UDim2.new(0.45, 0, 0.5, -12)
	ProfileDropdown.BackgroundColor3 = C_ITEM
	ProfileDropdown.Text = AutoExecSettings.AutoLoadProfile ~= "" and AutoExecSettings.AutoLoadProfile or "None"
	ProfileDropdown.TextColor3 = C_ACCENT
	ProfileDropdown.Font = Enum.Font.GothamBold
	ProfileDropdown.TextSize = 10
	ProfileDropdown.TextTruncate = Enum.TextTruncate.AtEnd
	Instance.new("UICorner", ProfileDropdown).CornerRadius = UDim.new(0, 4)
	RegisterTheme(ProfileDropdown, "BackgroundColor3", "Item")
	RegisterTheme(ProfileDropdown, "TextColor3", "Accent")

	-- Dropdown menu for profile selection
	local DropdownOpen = false
	local DropdownMenu = Instance.new("Frame", ProfileRow)
	DropdownMenu.Size = UDim2.new(0.5, 0, 0, 0)
	DropdownMenu.Position = UDim2.new(0.45, 0, 1, 5)
	DropdownMenu.BackgroundColor3 = C_ITEM
	DropdownMenu.Visible = false
	DropdownMenu.ZIndex = 10
	DropdownMenu.AutomaticSize = Enum.AutomaticSize.Y
	Instance.new("UICorner", DropdownMenu).CornerRadius = UDim.new(0, 6)
	RegisterTheme(DropdownMenu, "BackgroundColor3", "Item")

	local DropdownLayout = Instance.new("UIListLayout", DropdownMenu)
	DropdownLayout.Padding = UDim.new(0, 2)
	DropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local function RefreshDropdown()
		for _, c in pairs(DropdownMenu:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end

		-- Add "None" option
		local noneBtn = Instance.new("TextButton", DropdownMenu)
		noneBtn.Text = "None"
		noneBtn.Size = UDim2.new(1, 0, 0, 25)
		noneBtn.BackgroundTransparency = 1
		noneBtn.TextColor3 = C_TEXT_DIM
		noneBtn.Font = Enum.Font.Gotham
		noneBtn.TextSize = 10
		noneBtn.ZIndex = 11
		noneBtn.MouseButton1Click:Connect(function()
			AutoExecSettings.AutoLoadProfile = ""
			ProfileDropdown.Text = "None"
			DropdownMenu.Visible = false
			DropdownOpen = false
		end)

		-- Add profiles
		if isfolder(PROFILE_FOLDER) then
			for _, file in pairs(listfiles(PROFILE_FOLDER)) do
				if file:match("%.json$") then
					local name = file:match("([^/\\]+)%.json$")
					local btn = Instance.new("TextButton", DropdownMenu)
					btn.Text = name
					btn.Size = UDim2.new(1, 0, 0, 25)
					btn.BackgroundTransparency = 1
					btn.TextColor3 = C_TEXT
					btn.Font = Enum.Font.Gotham
					btn.TextSize = 10
					btn.ZIndex = 11
					btn.TextTruncate = Enum.TextTruncate.AtEnd
					RegisterTheme(btn, "TextColor3", "Text")

					btn.MouseButton1Click:Connect(function()
						AutoExecSettings.AutoLoadProfile = name
						ProfileDropdown.Text = name
						DropdownMenu.Visible = false
						DropdownOpen = false
					end)
				end
			end
		end
	end

	ProfileDropdown.MouseButton1Click:Connect(function()
		DropdownOpen = not DropdownOpen
		if DropdownOpen then
			RefreshDropdown()
		end
		DropdownMenu.Visible = DropdownOpen
	end)

	-- Executor Selection Row
	local ExecutorRow = Instance.new("Frame", AutoExecContainer)
	ExecutorRow.Size = UDim2.new(1, 0, 0, 35)
	ExecutorRow.BackgroundColor3 = C_SIDE
	ExecutorRow.LayoutOrder = 3
	Instance.new("UICorner", ExecutorRow).CornerRadius = UDim.new(0, 6)
	RegisterTheme(ExecutorRow, "BackgroundColor3", "Side")

	local ExecutorLabel = Instance.new("TextLabel", ExecutorRow)
	ExecutorLabel.Text = "Executor:"
	ExecutorLabel.Size = UDim2.new(0.35, 0, 1, 0)
	ExecutorLabel.Position = UDim2.new(0.05, 0, 0, 0)
	ExecutorLabel.BackgroundTransparency = 1
	ExecutorLabel.TextColor3 = C_TEXT
	ExecutorLabel.Font = Enum.Font.Gotham
	ExecutorLabel.TextSize = 10
	ExecutorLabel.TextXAlignment = Enum.TextXAlignment.Left
	RegisterTheme(ExecutorLabel, "TextColor3", "Text")

	local ExecutorDropdown = Instance.new("TextButton", ExecutorRow)
	ExecutorDropdown.Size = UDim2.new(0.55, 0, 0, 25)
	ExecutorDropdown.Position = UDim2.new(0.4, 0, 0.5, -12)
	ExecutorDropdown.BackgroundColor3 = C_ITEM
	local displayExecutor = AutoExecSettings.SelectedExecutor or "Auto-Detect"
	if displayExecutor == "Auto-Detect" then
		displayExecutor = "Auto-Detect (" .. DetectedExecutor .. ")"
	end
	ExecutorDropdown.Text = displayExecutor
	ExecutorDropdown.TextColor3 = C_ACCENT
	ExecutorDropdown.Font = Enum.Font.GothamBold
	ExecutorDropdown.TextSize = 9
	ExecutorDropdown.TextTruncate = Enum.TextTruncate.AtEnd
	Instance.new("UICorner", ExecutorDropdown).CornerRadius = UDim.new(0, 4)
	RegisterTheme(ExecutorDropdown, "BackgroundColor3", "Item")
	RegisterTheme(ExecutorDropdown, "TextColor3", "Accent")

	-- Executor Dropdown Menu
	local ExecDropdownOpen = false
	local ExecDropdownMenu = Instance.new("ScrollingFrame", ExecutorRow)
	ExecDropdownMenu.Size = UDim2.new(0.55, 0, 0, 150)
	ExecDropdownMenu.Position = UDim2.new(0.4, 0, 1, 5)
	ExecDropdownMenu.BackgroundColor3 = C_ITEM
	ExecDropdownMenu.Visible = false
	ExecDropdownMenu.ZIndex = 15
	ExecDropdownMenu.ScrollBarThickness = 4
	ExecDropdownMenu.CanvasSize = UDim2.new(0, 0, 0, 0)
	ExecDropdownMenu.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Instance.new("UICorner", ExecDropdownMenu).CornerRadius = UDim.new(0, 6)
	RegisterTheme(ExecDropdownMenu, "BackgroundColor3", "Item")

	local ExecDropdownLayout = Instance.new("UIListLayout", ExecDropdownMenu)
	ExecDropdownLayout.Padding = UDim.new(0, 2)
	ExecDropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder

	-- Populate executor dropdown
	for i, execName in ipairs(EXECUTOR_LIST) do
		local execBtn = Instance.new("TextButton", ExecDropdownMenu)
		execBtn.Text = execName
		if execName == "Auto-Detect" then
			execBtn.Text = "Auto-Detect (" .. DetectedExecutor .. ")"
		end
		execBtn.Size = UDim2.new(1, -8, 0, 22)
		execBtn.Position = UDim2.new(0, 4, 0, 0)
		execBtn.BackgroundTransparency = 1
		execBtn.TextColor3 = C_TEXT
		execBtn.Font = Enum.Font.Gotham
		execBtn.TextSize = 9
		execBtn.ZIndex = 16
		execBtn.LayoutOrder = i
		RegisterTheme(execBtn, "TextColor3", "Text")

		execBtn.MouseButton1Click:Connect(function()
			AutoExecSettings.SelectedExecutor = execName
			UpdateAutoExecFolder(execName)

			local newDisplay = execName
			if execName == "Auto-Detect" then
				newDisplay = "Auto-Detect (" .. DetectedExecutor .. ")"
			end
			ExecutorDropdown.Text = newDisplay
			ExecDropdownMenu.Visible = false
			ExecDropdownOpen = false
		end)
	end

	ExecutorDropdown.MouseButton1Click:Connect(function()
		ExecDropdownOpen = not ExecDropdownOpen
		ExecDropdownMenu.Visible = ExecDropdownOpen
		-- Close profile dropdown if open
		if ExecDropdownOpen then
			DropdownMenu.Visible = false
			DropdownOpen = false
		end
	end)

	-- Custom Path Row (for advanced users)
	local CustomPathRow = Instance.new("Frame", AutoExecContainer)
	CustomPathRow.Size = UDim2.new(1, 0, 0, 55)
	CustomPathRow.BackgroundColor3 = C_SIDE
	CustomPathRow.LayoutOrder = 4
	Instance.new("UICorner", CustomPathRow).CornerRadius = UDim.new(0, 6)
	RegisterTheme(CustomPathRow, "BackgroundColor3", "Side")

	local CustomPathLabel = Instance.new("TextLabel", CustomPathRow)
	CustomPathLabel.Text = "Custom Path (optional):"
	CustomPathLabel.Size = UDim2.new(0.9, 0, 0, 18)
	CustomPathLabel.Position = UDim2.new(0.05, 0, 0, 5)
	CustomPathLabel.BackgroundTransparency = 1
	CustomPathLabel.TextColor3 = C_TEXT
	CustomPathLabel.Font = Enum.Font.Gotham
	CustomPathLabel.TextSize = 9
	CustomPathLabel.TextXAlignment = Enum.TextXAlignment.Left
	RegisterTheme(CustomPathLabel, "TextColor3", "Text")

	local CustomPathInput = Instance.new("TextBox", CustomPathRow)
	CustomPathInput.Size = UDim2.new(0.9, 0, 0, 25)
	CustomPathInput.Position = UDim2.new(0.05, 0, 0, 25)
	CustomPathInput.BackgroundColor3 = C_ITEM
	CustomPathInput.Text = AutoExecSettings.CustomPath or ""
	CustomPathInput.PlaceholderText =
		"Leave empty to use default (e.g. C:/Users/YourName/AppData/Local/seliware-autoexec)"
	CustomPathInput.TextColor3 = C_TEXT
	CustomPathInput.PlaceholderColor3 = C_TEXT_DIM
	CustomPathInput.Font = Enum.Font.Gotham
	CustomPathInput.TextSize = 9
	CustomPathInput.TextXAlignment = Enum.TextXAlignment.Left
	CustomPathInput.ClearTextOnFocus = false
	Instance.new("UICorner", CustomPathInput).CornerRadius = UDim.new(0, 4)
	Instance.new("UIPadding", CustomPathInput).PaddingLeft = UDim.new(0, 8)
	RegisterTheme(CustomPathInput, "BackgroundColor3", "Item")
	RegisterTheme(CustomPathInput, "TextColor3", "Text")

	CustomPathInput.FocusLost:Connect(function()
		AutoExecSettings.CustomPath = CustomPathInput.Text
		if CustomPathInput.Text ~= "" then
			UpdateAutoExecFolder(AutoExecSettings.SelectedExecutor, CustomPathInput.Text)
		else
			UpdateAutoExecFolder(AutoExecSettings.SelectedExecutor, nil)
		end
	end)

	-- Delay Row
	local DelayRow = Instance.new("Frame", AutoExecContainer)
	DelayRow.Size = UDim2.new(1, 0, 0, 35)
	DelayRow.BackgroundColor3 = C_SIDE
	DelayRow.LayoutOrder = 5
	Instance.new("UICorner", DelayRow).CornerRadius = UDim.new(0, 6)
	RegisterTheme(DelayRow, "BackgroundColor3", "Side")

	local DelayLabel = Instance.new("TextLabel", DelayRow)
	DelayLabel.Text = "Delay (seconds):"
	DelayLabel.Size = UDim2.new(0.5, 0, 1, 0)
	DelayLabel.Position = UDim2.new(0.05, 0, 0, 0)
	DelayLabel.BackgroundTransparency = 1
	DelayLabel.TextColor3 = C_TEXT
	DelayLabel.Font = Enum.Font.Gotham
	DelayLabel.TextSize = 10
	DelayLabel.TextXAlignment = Enum.TextXAlignment.Left
	RegisterTheme(DelayLabel, "TextColor3", "Text")

	local DelayInput = Instance.new("TextBox", DelayRow)
	DelayInput.Size = UDim2.new(0.3, 0, 0, 25)
	DelayInput.Position = UDim2.new(0.6, 0, 0.5, -12)
	DelayInput.BackgroundColor3 = C_ITEM
	DelayInput.Text = tostring(AutoExecSettings.DelaySeconds)
	DelayInput.TextColor3 = C_TEXT
	DelayInput.PlaceholderText = "1"
	DelayInput.Font = Enum.Font.GothamBold
	DelayInput.TextSize = 11
	Instance.new("UICorner", DelayInput).CornerRadius = UDim.new(0, 4)
	RegisterTheme(DelayInput, "BackgroundColor3", "Item")
	RegisterTheme(DelayInput, "TextColor3", "Text")

	DelayInput.FocusLost:Connect(function()
		local num = tonumber(DelayInput.Text)
		if num and num >= 0 and num <= 30 then
			AutoExecSettings.DelaySeconds = num
		else
			DelayInput.Text = tostring(AutoExecSettings.DelaySeconds)
		end
	end)

	-- Save Button
	local SaveAutoExecBtn = Instance.new("TextButton", AutoExecContainer)
	SaveAutoExecBtn.Text = "💾 SAVE AUTO EXECUTE SETTINGS"
	SaveAutoExecBtn.Size = UDim2.new(1, 0, 0, 35)
	SaveAutoExecBtn.LayoutOrder = 6
	SaveAutoExecBtn.BackgroundColor3 = C_ACCENT
	SaveAutoExecBtn.TextColor3 = C_TEXT
	SaveAutoExecBtn.Font = Enum.Font.GothamBold
	SaveAutoExecBtn.TextSize = 11
	Instance.new("UICorner", SaveAutoExecBtn).CornerRadius = UDim.new(0, 6)
	RegisterTheme(SaveAutoExecBtn, "BackgroundColor3", "Accent")
	RegisterTheme(SaveAutoExecBtn, "TextColor3", "Text")

	-- Status Label
	local StatusLabel = Instance.new("TextLabel", AutoExecContainer)
	StatusLabel.Text = ""
	StatusLabel.Size = UDim2.new(1, 0, 0, 20)
	StatusLabel.LayoutOrder = 7
	StatusLabel.BackgroundTransparency = 1
	StatusLabel.TextColor3 = C_GREEN
	StatusLabel.Font = Enum.Font.Gotham
	StatusLabel.TextSize = 9
	StatusLabel.Visible = false

	EnableToggle.MouseButton1Click:Connect(function()
		AutoExecSettings.Enabled = not AutoExecSettings.Enabled
		EnableToggle.BackgroundColor3 = AutoExecSettings.Enabled and C_GREEN or C_ITEM
		EnableToggle.Text = AutoExecSettings.Enabled and "ON" or "OFF"
	end)

	SaveAutoExecBtn.MouseButton1Click:Connect(function()
		SaveAutoExecSettings()

		if AutoExecSettings.Enabled then
			local success, filePath = CreateAutoExecScript()
			if success then
				local execName = GetCurrentExecutorName()
				StatusLabel.Text = "✅ Script created: " .. AUTOEXEC_FOLDER .. "/StarshipCore_AutoExec.lua"
				StatusLabel.TextColor3 = C_GREEN
			else
				StatusLabel.Text = "⚠️ Could not create auto-exec script (check folder permissions)"
				StatusLabel.TextColor3 = C_YELLOW
			end
		else
			RemoveAutoExecScript()
			StatusLabel.Text = "🔴 Auto-exec disabled"
			StatusLabel.TextColor3 = C_TEXT_DIM
		end

		StatusLabel.Visible = true

		if UI and UI.ShowToast then
			local msg = AutoExecSettings.Enabled and L("auto_execute_enabled") or L("auto_execute_disabled")
			UI.ShowToast(L("auto_execute"), msg, "success", 3)
		end

		SaveAutoExecBtn.Text = "✅ SAVED!"
		task.wait(1.5)
		SaveAutoExecBtn.Text = "💾 SAVE AUTO EXECUTE SETTINGS"
	end)

	-- Detected Executor Info
	local DetectedLabel = Instance.new("TextLabel", AutoExecContainer)
	DetectedLabel.Text = L("detected") .. ": " .. DetectedExecutor .. " | " .. L("path") .. ": " .. AUTOEXEC_FOLDER
	DetectedLabel.Size = UDim2.new(1, 0, 0, 18)
	DetectedLabel.LayoutOrder = 8
	DetectedLabel.BackgroundTransparency = 1
	DetectedLabel.TextColor3 = C_ACCENT
	DetectedLabel.Font = Enum.Font.Gotham
	DetectedLabel.TextSize = 8
	DetectedLabel.TextWrapped = true
	DetectedLabel.TextXAlignment = Enum.TextXAlignment.Left
	RegisterTheme(DetectedLabel, "TextColor3", "Accent")

	-- Instructions
	local InstructionsLabel = Instance.new("TextLabel", AutoExecContainer)
	InstructionsLabel.Text = L("seliware_instructions")
	InstructionsLabel.Size = UDim2.new(1, 0, 0, 35)
	InstructionsLabel.LayoutOrder = 9
	InstructionsLabel.BackgroundTransparency = 1
	InstructionsLabel.TextColor3 = C_TEXT_DIM
	InstructionsLabel.Font = Enum.Font.Gotham
	InstructionsLabel.TextSize = 8
	InstructionsLabel.TextWrapped = true
	InstructionsLabel.TextXAlignment = Enum.TextXAlignment.Left
	RegisterTheme(InstructionsLabel, "TextColor3", "TextDim")

	local AutoInfo = Instance.new("TextLabel", AutoCard)
	AutoInfo.Text = L("select_features")
	AutoInfo.Size = UDim2.new(0.9, 0, 0, 15)
	AutoInfo.Position = UDim2.new(0.05, 0, 0, 30)
	AutoInfo.BackgroundTransparency = 1
	AutoInfo.TextColor3 = C_TEXT_DIM
	AutoInfo.Font = Enum.Font.Gotham
	AutoInfo.TextSize = 9
	AutoInfo.TextXAlignment = Enum.TextXAlignment.Left

	local AutoList = Instance.new("Frame", AutoCard)
	AutoList.Size = UDim2.new(1, 0, 0, 0)
	AutoList.Position = UDim2.new(0, 0, 0, 50)
	AutoList.BackgroundTransparency = 1
	AutoList.AutomaticSize = Enum.AutomaticSize.Y

	local AutoLayout = Instance.new("UIListLayout", AutoList)
	AutoLayout.Padding = UDim.new(0, 3)
	AutoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	AutoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- List of features for auto-enable
	local autoFeatures = {
		{ id = "AntiAFK", name = "Anti-AFK" },
		{ id = "ShiftLock", name = "Shift Lock" },
		{ id = "Momentum", name = "Always Momentum" },
		{ id = "QuickBoost", name = "Quick Boost" },
		{ id = "AirLock", name = "Air Lock" },
		{ id = "RealESP", name = "Real Path ESP" },
		{ id = "Fullbright", name = "Fullbright" },
		{ id = "BypassAdmin", name = "Bypass Admin" },
	}

	local function IsInAutoEnable(id)
		for _, v in ipairs(AutoEnableList) do
			if v == id then
				return true
			end
		end
		return false
	end

	local function ToggleAutoEnable(id)
		if IsInAutoEnable(id) then
			for i, v in ipairs(AutoEnableList) do
				if v == id then
					table.remove(AutoEnableList, i)
					break
				end
			end
		else
			table.insert(AutoEnableList, id)
		end
	end

	for _, feat in ipairs(autoFeatures) do
		local row = Instance.new("Frame", AutoList)
		row.Size = UDim2.new(0.95, 0, 0, 28)
		row.BackgroundColor3 = C_SIDE
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		RegisterTheme(row, "BackgroundColor3", "Side")

		local lbl = Instance.new("TextLabel", row)
		lbl.Text = feat.name
		lbl.Size = UDim2.new(0.7, 0, 1, 0)
		lbl.Position = UDim2.new(0.05, 0, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = C_TEXT
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(lbl, "TextColor3", "Text")

		local toggle = Instance.new("TextButton", row)
		toggle.Size = UDim2.new(0, 50, 0, 20)
		toggle.Position = UDim2.new(0.78, 0, 0.5, -10)
		toggle.BackgroundColor3 = IsInAutoEnable(feat.id) and C_GREEN or C_ITEM
		toggle.Text = IsInAutoEnable(feat.id) and "ON" or "OFF"
		toggle.TextColor3 = C_TEXT
		toggle.Font = Enum.Font.GothamBold
		toggle.TextSize = 9
		Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)
		RegisterTheme(toggle, "TextColor3", "Text")
		-- Note: BackgroundColor3 is dynamic (green/item based on state), can't directly register

		toggle.MouseButton1Click:Connect(function()
			ToggleAutoEnable(feat.id)
			local isOn = IsInAutoEnable(feat.id)
			toggle.BackgroundColor3 = isOn and C_GREEN or C_ITEM
			toggle.Text = isOn and "ON" or "OFF"
		end)
	end

	local BtnSaveAuto = Instance.new("TextButton", AutoCard)
	BtnSaveAuto.Text = "SAVE AUTO-ENABLE SETTINGS"
	BtnSaveAuto.Size = UDim2.new(0.9, 0, 0, 30)
	BtnSaveAuto.Position = UDim2.new(0.05, 0, 0, 50 + (#autoFeatures * 31) + 10)
	StyleBtn(BtnSaveAuto, C_ACCENT)

	BtnSaveAuto.MouseButton1Click:Connect(function()
		-- Save to a special auto-enable file
		writefile(CONFIG_FOLDER .. "/AutoEnable.json", HttpService:JSONEncode(AutoEnableList))
		if UI and UI.ShowToast then
			UI.ShowToast(L("auto_enable_saved"), L("auto_enable_desc"), "success", 2)
		end
		BtnSaveAuto.Text = "SAVED!"
		task.wait(1)
		BtnSaveAuto.Text = "SAVE AUTO-ENABLE SETTINGS"
	end)

	-- Load existing auto-enable on UI setup
	if isfile(CONFIG_FOLDER .. "/AutoEnable.json") then
		local s, r = pcall(function()
			return HttpService:JSONDecode(readfile(CONFIG_FOLDER .. "/AutoEnable.json"))
		end)
		if s and r then
			-- Clear existing AutoEnableList while keeping the same table reference
			for i = #AutoEnableList, 1, -1 do
				table.remove(AutoEnableList, i)
			end
			-- Populate with loaded values
			for _, id in ipairs(r) do
				table.insert(AutoEnableList, id)
			end
			-- Refresh toggle states
			for _, child in pairs(AutoList:GetChildren()) do
				if child:IsA("Frame") then
					local toggle = child:FindFirstChildOfClass("TextButton")
					local lbl = child:FindFirstChildOfClass("TextLabel")
					if toggle and lbl then
						for _, feat in ipairs(autoFeatures) do
							if feat.name == lbl.Text then
								local isOn = IsInAutoEnable(feat.id)
								toggle.BackgroundColor3 = isOn and C_GREEN or C_ITEM
								toggle.Text = isOn and "ON" or "OFF"
								break
							end
						end
					end
				end
			end
		end
	end

	UIHandlers.SaveConfig = SaveConfig
	UIHandlers.LoadConfig = LoadConfig
	UIHandlers.SaveProfile = function(name)
		SaveProfile(name, Config, UI, UIHandlers)
	end
	UIHandlers.LoadProfile = function(name)
		LoadProfile(name, Config, Themes, UI, UIHandlers)
	end
	UIHandlers.SetFeatureState = SetFeatureState
	UIHandlers.GetFeatureState = GetFeatureState
	UIHandlers.FeatureStates = FeatureStates
	UIHandlers.AutoEnableList = AutoEnableList
	UIHandlers.RunAutoEnable = function()
		RunAutoEnable(UIHandlers)
	end
	UIHandlers.AutoExecSettings = AutoExecSettings
	UIHandlers.SaveAutoExecSettings = SaveAutoExecSettings

	-- Initial Theme Application
	if Config.Theme then
		ApplyTheme(Config.Theme)
	end

	-- Auto-load profile if enabled (skip spoof since it was preloaded, but load rest of profile)
	-- Using local module variable to track - fresh for each script execution

	-- Always print for debugging
	DevLog("=== AUTO-LOAD PROFILE CHECK ===")
	DevLog("Enabled:", AutoExecSettings.Enabled)
	DevLog("Profile:", AutoExecSettings.AutoLoadProfile)
	DevLog("AutoLoadProfileCompleted:", AutoLoadProfileCompleted)
	DevLog("Profile empty?:", AutoExecSettings.AutoLoadProfile == "")

	if AutoExecSettings.Enabled and AutoExecSettings.AutoLoadProfile ~= "" and not AutoLoadProfileCompleted then
		DevLog(">>> WILL AUTO-LOAD PROFILE:", AutoExecSettings.AutoLoadProfile)
	else
		DevLog(">>> SKIPPING auto-load (conditions not met)")
	end

	if AutoExecSettings.Enabled and AutoExecSettings.AutoLoadProfile ~= "" and not AutoLoadProfileCompleted then
		-- Mark as completed immediately using local variable
		AutoLoadProfileCompleted = true
		DevLog("Set AutoLoadProfileCompleted = true")

		task.spawn(function()
			-- Wait for Welcome toast to appear first (1.5s base), then add user-configured delay
			local delayTime = 1.5 + (AutoExecSettings.DelaySeconds or 0)
			DevLog("Auto-loading profile after delay:", delayTime, "seconds")
			task.wait(delayTime)

			-- Check if profile file exists
			local profilePath = PROFILE_FOLDER .. "/" .. AutoExecSettings.AutoLoadProfile
			if not profilePath:match("%.json$") then
				profilePath = profilePath .. ".json"
			end
			DevLog("Looking for profile at:", profilePath)
			if isfile and isfile(profilePath) then
				DevLog("Profile file EXISTS")
			else
				DevLog("Profile file NOT FOUND!")
			end

			-- Check if profile was already preloaded for spoof
			local wasPreloaded = getgenv
				and getgenv().StarshipProfilePreloaded
				and getgenv().StarshipPreloadedProfile == AutoExecSettings.AutoLoadProfile

			-- Pass true for suppressToast to avoid duplicate, show combined toast instead
			DevLog("Calling LoadProfile with name:", AutoExecSettings.AutoLoadProfile)
			local success, result = LoadProfile(AutoExecSettings.AutoLoadProfile, Config, Themes, UI, UIHandlers, true)

			DevLog("LoadProfile result - Success:", success)
			if result then
				DevLog("Profile has keybinds:", result.Keybinds ~= nil)
				DevLog("Profile has AutoEnable:", result.AutoEnable ~= nil)
			end

			if success and UI and UI.ShowToast then
				local featureCount = UIHandlers.AutoEnableList and #UIHandlers.AutoEnableList or 0
				local msg = featureCount > 0
						and L("profile") .. ": " .. AutoExecSettings.AutoLoadProfile .. "\n" .. L(
							"auto_enabling",
							featureCount
						)
					or L("profile") .. ": " .. AutoExecSettings.AutoLoadProfile
				UI.ShowToast(L("auto_loaded"), msg, "success", 3)
			elseif not success and UI and UI.ShowToast then
				UI.ShowToast(
					"Auto-Load Failed",
					"Could not load profile: " .. AutoExecSettings.AutoLoadProfile,
					"error",
					3
				)
			end
		end)
	end

	-- Expose PreloadSpoofName for StarshipCore to call before StartLoader
	UIHandlers.PreloadSpoofName = function()
		return PreloadSpoofName(UIHandlers, Config, Themes, UI)
	end
end

return {
	SetupUI = SetupConfigUI,
	SaveConfig = SaveConfig,
	LoadConfig = LoadConfig,
	SaveProfile = SaveProfile,
	LoadProfile = LoadProfile,
	SetFeatureState = SetFeatureState,
	GetFeatureState = GetFeatureState,
	FeatureStates = FeatureStates,
	RunAutoEnable = RunAutoEnable,
	PreloadSpoofName = PreloadSpoofName,
	AutoExecSettings = AutoExecSettings,
	SaveAutoExecSettings = SaveAutoExecSettings,
	LoadAutoExecSettings = LoadAutoExecSettings,
	CreateAutoExecScript = CreateAutoExecScript,
	RemoveAutoExecScript = RemoveAutoExecScript,
}
