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
local VERSION = "1.2.2"
local CLOUD_API_BASE = _G.StarshipServerURL or "https://starship-core.my.id"

-- DEV_MODE detection (same as StarshipCore)
local DEV_MODE = _G.StarshipDevMode or false

-- ══════════════════════════════════════════════════════════════════
-- LOAD WINDUI
-- ══════════════════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ══════════════════════════════════════════════════════════════════
-- LOAD STARSPACE PLAYBACK ENGINE
-- ══════════════════════════════════════════════════════════════════
-- Set UI reference for StarSpacePlayback to use
_G.Xan = {
    Slide = function(title, content)
        WindUI:Notify({ Title = title, Content = content, Duration = 2 })
    end
}

-- Load StarSpacePlayback module
local StarSpacePlaybackLoaded = false
task.spawn(function()
    local baseUrl = _G.StarshipServerURL or "https://starship-core.my.id"
    local PLAYBACK_URL = baseUrl .. "/api/get-module?name=StarSpacePlayback.lua"
    
    -- Add dev secret if in dev mode but not on localhost
    if DEV_MODE and not baseUrl:find("localhost") then
        PLAYBACK_URL = PLAYBACK_URL .. "&dev=starship-dev-2025"
    end

    local success, err = pcall(function()
        local content = game:HttpGet(PLAYBACK_URL)
        
        -- Basic check to see if we got HTML instead of Lua (common on 404/403)
        if content:find("<!DOCTYPE") or content:find("<html>") then
            error("Server returned HTML instead of Lua. Check if module is whitelisted or URL is correct.")
        end

        local func, syntaxErr = loadstring(content)
        if func then
            func()
        else
            error("Syntax Error: " .. tostring(syntaxErr))
        end
    end)
    if success then
        StarSpacePlaybackLoaded = true
        if DEV_MODE then
            warn("[MobileUI] StarSpacePlayback module loaded successfully!")
        end
    else
        warn("[MobileUI] Failed to load StarSpacePlayback: " .. tostring(err))
    end
end)

-- Wait for module to load (max 5 seconds)
local waitStart = os.clock()
while not StarSpacePlaybackLoaded and (os.clock() - waitStart) < 5 do
    task.wait(0.1)
end

if not StarSpacePlaybackLoaded then
    warn("[MobileUI] StarSpacePlayback module not loaded, using fallback playback...")
end




-- ══════════════════════════════════════════════════════════════════
-- CONFIGURATION MANAGEMENT
-- ══════════════════════════════════════════════════════════════════
local ConfigFile = "StarshipMobile/Settings.json"
local Settings = {
	AutoAntiAFK = false,
	RememberPosition = false,
	ShowNotifications = true,
	Theme = "Indigo", -- Default theme
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

-- Valid themes list (must match WindUI supported themes)
local ValidThemes = {
	"Dark",
	"Light",
	"Midnight",
	"Rose",
	"Emerald",
	"Plant",
	"Red",
	"Indigo",
	"Sky",
	"Violet",
	"Amber",
	"Crimson",
	"Monokai Pro",
	"Cotton Candy",
	"Rainbow",
}

-- Validate theme - fallback to Dark if invalid
local function IsValidTheme(themeName)
	for _, v in ipairs(ValidThemes) do
		if v == themeName then
			return true
		end
	end
	return false
end

if not IsValidTheme(Settings.Theme) then
	Settings.Theme = "Dark" -- Safe fallback
	SaveSettings()
end

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

-- ══════════════════════════════════════════════════════════════════
-- CHANGELOG POPUP (Mobile-specific, blocking before UI loads)
-- Uses /changelog-mobile.json for mobile-specific updates
-- ══════════════════════════════════════════════════════════════════
local function ShowMobileChangelog()
	local HttpService = game:GetService("HttpService")
	local CoreGui = game:GetService("CoreGui")
	
	local MOBILE_VERSION_FILE = "StarshipMobile/changelog_version.txt"
	local MOBILE_CHANGELOG_URL = CLOUD_API_BASE .. "/changelog-mobile.json?t=" .. os.time()
	
	-- ═══════════════════════════════════════════════════════════════
	-- THEME COLOR MAPPING (Match WindUI themes)
	-- ═══════════════════════════════════════════════════════════════
	local ThemeColors = {
		Dark = { Accent = Color3.fromRGB(90, 110, 245), Background = Color3.fromRGB(20, 20, 30), Card = Color3.fromRGB(30, 30, 45) },
		Light = { Accent = Color3.fromRGB(59, 130, 246), Background = Color3.fromRGB(245, 245, 250), Card = Color3.fromRGB(255, 255, 255) },
		Midnight = { Accent = Color3.fromRGB(99, 102, 241), Background = Color3.fromRGB(15, 15, 25), Card = Color3.fromRGB(25, 25, 40) },
		Rose = { Accent = Color3.fromRGB(244, 63, 94), Background = Color3.fromRGB(25, 15, 20), Card = Color3.fromRGB(40, 25, 30) },
		Emerald = { Accent = Color3.fromRGB(16, 185, 129), Background = Color3.fromRGB(15, 25, 20), Card = Color3.fromRGB(25, 40, 30) },
		Plant = { Accent = Color3.fromRGB(34, 197, 94), Background = Color3.fromRGB(15, 25, 15), Card = Color3.fromRGB(25, 40, 25) },
		Red = { Accent = Color3.fromRGB(239, 68, 68), Background = Color3.fromRGB(25, 15, 15), Card = Color3.fromRGB(40, 25, 25) },
		Indigo = { Accent = Color3.fromRGB(102, 126, 234), Background = Color3.fromRGB(20, 20, 35), Card = Color3.fromRGB(30, 30, 50) },
		Sky = { Accent = Color3.fromRGB(14, 165, 233), Background = Color3.fromRGB(15, 25, 30), Card = Color3.fromRGB(25, 40, 50) },
		Violet = { Accent = Color3.fromRGB(139, 92, 246), Background = Color3.fromRGB(25, 15, 35), Card = Color3.fromRGB(40, 25, 55) },
		Amber = { Accent = Color3.fromRGB(245, 158, 11), Background = Color3.fromRGB(25, 20, 15), Card = Color3.fromRGB(40, 35, 25) },
		Crimson = { Accent = Color3.fromRGB(220, 38, 38), Background = Color3.fromRGB(25, 15, 15), Card = Color3.fromRGB(45, 25, 25) },
		["Monokai Pro"] = { Accent = Color3.fromRGB(169, 220, 118), Background = Color3.fromRGB(30, 30, 30), Card = Color3.fromRGB(45, 45, 45) },
		["Cotton Candy"] = { Accent = Color3.fromRGB(240, 147, 251), Background = Color3.fromRGB(30, 20, 35), Card = Color3.fromRGB(45, 35, 55) },
		Rainbow = { Accent = Color3.fromRGB(168, 85, 247), Background = Color3.fromRGB(20, 20, 30), Card = Color3.fromRGB(30, 30, 45) },
	}
	
	-- Get colors based on current theme
	local currentTheme = Settings.Theme or "Indigo"
	local colors = ThemeColors[currentTheme] or ThemeColors.Indigo
	local AccentColor = colors.Accent
	local BackgroundColor = colors.Background
	local CardColor = colors.Card
	local TextColor = Color3.fromRGB(220, 220, 230)
	local TextDimColor = Color3.fromRGB(140, 140, 160)
	local SuccessColor = Color3.fromRGB(80, 200, 120)
	
	-- Adjust text colors for light themes
	if currentTheme == "Light" then
		TextColor = Color3.fromRGB(30, 30, 40)
		TextDimColor = Color3.fromRGB(100, 100, 120)
	end
	
	-- Get last seen version
	local function getLastSeenVersion()
		if not isfile then return "0.0.0" end
		local success, content = pcall(function()
			if isfile(MOBILE_VERSION_FILE) then
				return readfile(MOBILE_VERSION_FILE)
			end
			return nil
		end)
		return (success and content) or "0.0.0"
	end
	
	-- Save last seen version
	local function saveLastSeenVersion(version)
		if not writefile then return end
		pcall(function()
			if isfolder and not isfolder("StarshipMobile") then
				makefolder("StarshipMobile")
			end
			writefile(MOBILE_VERSION_FILE, version)
		end)
	end
	
	-- Compare versions
	local function isNewerVersion(v1, v2)
		local function parseVersion(v)
			local major, minor, patch = v:match("(%d+)%.(%d+)%.(%d+)")
			return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
		end
		local m1, n1, p1 = parseVersion(v1)
		local m2, n2, p2 = parseVersion(v2)
		if m1 ~= m2 then return m1 > m2 end
		if n1 ~= n2 then return n1 > n2 end
		return p1 > p2
	end
	
	-- Fetch mobile changelog from server
	local changelogData = nil
	local fetchSuccess = pcall(function()
		local response = game:HttpGet(MOBILE_CHANGELOG_URL)
		changelogData = HttpService:JSONDecode(response)
	end)
	
	if not fetchSuccess or not changelogData then
		if DEV_MODE then warn("[MobileUI] Failed to fetch mobile changelog, skipping popup") end
		return
	end
	
	-- Cache for reuse
	_G.StarshipChangelogData = changelogData
	
	local lastSeen = getLastSeenVersion()
	local serverVersion = changelogData.currentVersion or "1.0.0"
	
	if DEV_MODE then
		warn("[MobileUI] Changelog last seen: " .. lastSeen .. ", Server: " .. serverVersion)
	end
	
	-- Only show if new version
	if not isNewerVersion(serverVersion, lastSeen) then
		if DEV_MODE then warn("[MobileUI] No new mobile changelog, skipping popup") end
		return
	end
	
	-- ═══════════════════════════════════════════════════════════════
	-- CREATE BLOCKING CHANGELOG MODAL (THEME-AWARE)
	-- ═══════════════════════════════════════════════════════════════
	local dismissed = false
	
	local existing = CoreGui:FindFirstChild("StarshipMobileChangelog")
	if existing then existing:Destroy() end
	
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "StarshipMobileChangelog"
	ScreenGui.Parent = CoreGui
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.DisplayOrder = 99999
	ScreenGui.IgnoreGuiInset = true
	
	-- Overlay
	local Overlay = Instance.new("Frame", ScreenGui)
	Overlay.Size = UDim2.new(1, 0, 1, 0)
	Overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	Overlay.BackgroundTransparency = 1
	Overlay.BorderSizePixel = 0
	
	-- Modal (THEME-AWARE)
	local Modal = Instance.new("Frame", ScreenGui)
	Modal.Size = UDim2.new(0, 320, 0, 380)
	Modal.Position = UDim2.new(0.5, 0, 1.5, 0)
	Modal.AnchorPoint = Vector2.new(0.5, 0.5)
	Modal.BackgroundColor3 = BackgroundColor
	Modal.BorderSizePixel = 0
	Instance.new("UICorner", Modal).CornerRadius = UDim.new(0, 14)
	
	local ModalStroke = Instance.new("UIStroke", Modal)
	ModalStroke.Thickness = 1.5
	ModalStroke.Color = AccentColor
	
	-- Accent bar (THEME-AWARE)
	local AccentBar = Instance.new("Frame", Modal)
	AccentBar.Size = UDim2.new(1, 0, 0, 3)
	AccentBar.BackgroundColor3 = AccentColor
	AccentBar.BorderSizePixel = 0
	Instance.new("UICorner", AccentBar).CornerRadius = UDim.new(0, 14)
	
	-- Header (THEME-AWARE)
	local Title = Instance.new("TextLabel", Modal)
	Title.Text = "🎉 What's New in v" .. serverVersion
	Title.Size = UDim2.new(1, -20, 0, 35)
	Title.Position = UDim2.new(0, 10, 0, 15)
	Title.BackgroundTransparency = 1
	Title.TextColor3 = AccentColor
	Title.Font = Enum.Font.SourceSansBold
	Title.TextSize = 16
	Title.TextXAlignment = Enum.TextXAlignment.Left
	
	local Subtitle = Instance.new("TextLabel", Modal)
	Subtitle.Text = "📱 STARSHIP MOBILE"
	Subtitle.Size = UDim2.new(1, -20, 0, 18)
	Subtitle.Position = UDim2.new(0, 10, 0, 45)
	Subtitle.BackgroundTransparency = 1
	Subtitle.TextColor3 = TextDimColor
	Subtitle.Font = Enum.Font.SourceSans
	Subtitle.TextSize = 11
	Subtitle.TextXAlignment = Enum.TextXAlignment.Left
	
	-- Content scroll (THEME-AWARE)
	local Content = Instance.new("ScrollingFrame", Modal)
	Content.Size = UDim2.new(1, -20, 1, -130)
	Content.Position = UDim2.new(0, 10, 0, 70)
	Content.BackgroundTransparency = 1
	Content.BorderSizePixel = 0
	Content.ScrollBarThickness = 3
	Content.ScrollBarImageColor3 = AccentColor
	Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Content.CanvasSize = UDim2.new(0, 0, 0, 0)
	
	local ContentLayout = Instance.new("UIListLayout", Content)
	ContentLayout.Padding = UDim.new(0, 8)
	ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	
	-- Add updates (THEME-AWARE)
	if changelogData.updates then
		for i, update in ipairs(changelogData.updates) do
			if i > 3 then break end
			
			local UpdateFrame = Instance.new("Frame", Content)
			UpdateFrame.Size = UDim2.new(1, -5, 0, 0)
			UpdateFrame.BackgroundColor3 = CardColor
			UpdateFrame.BorderSizePixel = 0
			UpdateFrame.AutomaticSize = Enum.AutomaticSize.Y
			UpdateFrame.LayoutOrder = i
			Instance.new("UICorner", UpdateFrame).CornerRadius = UDim.new(0, 8)
			
			local Pad = Instance.new("UIPadding", UpdateFrame)
			Pad.PaddingTop = UDim.new(0, 8)
			Pad.PaddingBottom = UDim.new(0, 8)
			Pad.PaddingLeft = UDim.new(0, 10)
			Pad.PaddingRight = UDim.new(0, 10)
			
			local ULayout = Instance.new("UIListLayout", UpdateFrame)
			ULayout.Padding = UDim.new(0, 4)
			
			-- Version (THEME-AWARE)
			local Ver = Instance.new("TextLabel", UpdateFrame)
			Ver.Text = "📦 v" .. (update.version or "?") .. " - " .. (update.date or "")
			Ver.Size = UDim2.new(1, 0, 0, 18)
			Ver.BackgroundTransparency = 1
			Ver.TextColor3 = i == 1 and SuccessColor or TextDimColor
			Ver.Font = Enum.Font.SourceSansBold
			Ver.TextSize = 12
			Ver.TextXAlignment = Enum.TextXAlignment.Left
			Ver.LayoutOrder = 1
			
			if update.title then
				local T = Instance.new("TextLabel", UpdateFrame)
				T.Text = update.title
				T.Size = UDim2.new(1, 0, 0, 16)
				T.BackgroundTransparency = 1
				T.TextColor3 = TextColor
				T.Font = Enum.Font.SourceSansSemibold
				T.TextSize = 11
				T.TextXAlignment = Enum.TextXAlignment.Left
				T.LayoutOrder = 2
			end
			
			if update.changes then
				for j, change in ipairs(update.changes) do
					local C = Instance.new("TextLabel", UpdateFrame)
					C.Text = "• " .. change
					C.Size = UDim2.new(1, 0, 0, 14)
					C.BackgroundTransparency = 1
					C.TextColor3 = TextDimColor
					C.Font = Enum.Font.SourceSans
					C.TextSize = 10
					C.TextXAlignment = Enum.TextXAlignment.Left
					C.TextWrapped = true
					C.AutomaticSize = Enum.AutomaticSize.Y
					C.LayoutOrder = 10 + j
				end
			end
		end
	end
	
	-- Got it button (THEME-AWARE)
	local GotItBtn = Instance.new("TextButton", Modal)
	GotItBtn.Size = UDim2.new(1, -30, 0, 40)
	GotItBtn.Position = UDim2.new(0.5, 0, 1, -55)
	GotItBtn.AnchorPoint = Vector2.new(0.5, 0)
	GotItBtn.BackgroundColor3 = AccentColor
	GotItBtn.Text = "✓ Got it!"
	GotItBtn.TextColor3 = Color3.new(1, 1, 1)
	GotItBtn.Font = Enum.Font.SourceSansBold
	GotItBtn.TextSize = 14
	GotItBtn.BorderSizePixel = 0
	Instance.new("UICorner", GotItBtn).CornerRadius = UDim.new(0, 8)

	
	-- Animate in
	TweenService:Create(Overlay, TweenInfo.new(0.25), { BackgroundTransparency = 0.5 }):Play()
	TweenService:Create(Modal, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
	
	-- Close handler
	local function closeModal()
		saveLastSeenVersion(serverVersion)
		dismissed = true
		
		TweenService:Create(Overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(Modal, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 1.5, 0),
		}):Play()
		
		task.delay(0.3, function()
			if ScreenGui then ScreenGui:Destroy() end
		end)
	end
	
	GotItBtn.MouseButton1Click:Connect(closeModal)
	GotItBtn.TouchTap:Connect(closeModal)
	
	-- NON-BLOCKING: Let the UI continue loading in the background
	return true
end

-- Set custom font (Michroma - futuristic/space theme)
task.spawn(function()
	pcall(function()
		WindUI:SetFont("rbxasset://fonts/families/RobotoMono.json")
	end)
end)

-- Show mobile changelog (NON-BLOCKING)
task.spawn(ShowMobileChangelog)
task.wait(0.1)


-- CREATE WINDOW
-- ══════════════════════════════════════════════════════════════════
task.wait(0.2)
local Window = WindUI:CreateWindow({
	-- ═══ PREMIUM BRANDING ═══
	Title = "✨ STARSHIP ┃ dsc.gg-starshipcore",
	Icon = "rbxassetid://123840945153526", -- Logo next to title
	IconSize = 36, -- Larger icon for premium look
	Author = "Premium Edition • StarshipCore",

	-- ═══ WINDOW SIZING ═══
	Size = UDim2.fromOffset(830, 600),
	SideBarWidth = 180, -- Slightly wider sidebar

	-- ═══ PREMIUM TRANSPARENCY & GLASSMORPHISM ═══
	Transparent = true,
	BackgroundImageTransparency = 0.92, -- More subtle watermark
	Background = "rbxassetid://123840945153526", -- Starship Logo as background

	-- ═══ THEME ═══
	Theme = Settings.Theme or "Indigo",

	-- ═══ USER PROFILE ═══
	User = {
		Enabled = true,
		Anonymous = true, -- Set to true to hide real username
		Callback = function()
			-- Premium profile notification
			WindUI:Notify({
				Title = "👤 Profile",
				Content = "Welcome back, " .. Players.LocalPlayer.DisplayName .. "!",
				Duration = 3,
			})
			WindUI:Notify({
				Title = "⚙️ Config Status",
				Content = ConfigStatus,
				Duration = 4,
			})
		end,
	},

	-- ═══ TOPBAR STYLING ═══
	Topbar = {
		Height = 65, -- Taller for premium feel
		ButtonsType = "Default",
	},

	-- ═══ FLOATING OPEN BUTTON (PREMIUM GRADIENT) ═══
	OpenButton = {
		Title = "STARSHIP ✨",
		Icon = "rbxassetid://123840945153526",
		CornerRadius = UDim.new(1, 0), -- Fully rounded (pill shape)
		StrokeThickness = 2,
		Enabled = true,
		Draggable = true, -- Can be dragged to preferred position
		OnlyMobile = false, -- Show on both PC and Mobile
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#667eea")), -- Blue-purple start
			ColorSequenceKeypoint.new(0.5, Color3.fromHex("#764ba2")), -- Purple mid
			ColorSequenceKeypoint.new(1, Color3.fromHex("#f093fb")), -- Pink end
		}),
	},
})

-- Store Window reference globally for ban system
getgenv().StarshipWindow = Window
getgenv().StarshipWindUI = WindUI
task.wait(0.1)

-- ══════════════════════════════════════════════════════════════════
-- LOGO OVERLAY (Using WindUI's built-in Background Image Settings)
-- ══════════════════════════════════════════════════════════════════
Window:SetBackgroundImage("rbxassetid://91946746369709")
Window:SetBackgroundImageTransparency(0.85)

-- ══════════════════════════════════════════════════════════════════
-- TOPBAR THEME SWITCH BUTTON
-- ══════════════════════════════════════════════════════════════════
getgenv().Theme = Settings.Theme or "Indigo"
Window:CreateTopbarButton(
	"SwitchTheme",
	"eye",
	function()
		getgenv().Theme = getgenv().Theme == "Indigo" and "Dark" or "Indigo"
		WindUI:SetTheme(getgenv().Theme)
		Settings.Theme = getgenv().Theme
		SaveSettings()
	end,
	990
)

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

-- Format role name (replace underscore with space)
local function FormatRole(role)
	if role then
		return role:gsub("_", " ")
	end
	return role or "VIP"
end

-- Role Tag (VIP/OWNER)
local roleColor = "#a855f7" -- Purple default
if sessionData.Role == "OWNER" then
	roleColor = "#f59e0b" -- Orange/Gold for OWNER
elseif sessionData.Role == "VIP" or sessionData.Role == "MOBILE_VIP" then
	roleColor = "#a855f7" -- Purple for VIP
end

local RoleTag = Window:Tag({
	Title = '<font size="11">' .. FormatRole(sessionData.Role) .. "</font>",
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
-- DEVICE PERFORMANCE (MOBILE-OPTIMIZED)
-- Force linear interpolation for better FPS on all mobile devices
-- ══════════════════════════════════════════════════════════════════
_G.StarshipDevicePerformance = _G.StarshipDevicePerformance or {
	zoomPunch = {
		currentState = "normal",
		lastChangeTime = 0,
		cooldown = 0.15,
		pendingState = nil,
	},
	interpolationMode = "catmullrom", -- SWITCHED TO CATMULLROM (Smoother movement)
	isMobile = true, -- This is the mobile script
	isLowEnd = false,
	averageFPS = 60,
}

-- Ensure catmullrom mode is set
_G.StarshipDevicePerformance.interpolationMode = "catmullrom"
_G.StarshipDevicePerformance.isMobile = true

if DEV_MODE then
	warn("[MobileUI] Using CATMULL-ROM interpolation mode for smoother movement")
end

-- ══════════════════════════════════════════════════════════════════
-- PERIODIC BAN CHECK SYSTEM (Every 5 minutes)
-- Checks both IP ban and Google Sheets ban status
-- ══════════════════════════════════════════════════════════════════
-- Ban check state stored in _G to reduce local count
_G.StarshipBanCheck = _G.StarshipBanCheck or {
	API_BASE = _G.StarshipServerURL or "https://starship-core.my.id",
	INTERVAL = 5 * 60,
	isRunning = false
}
_G.StarshipBanCheck.API_URL = _G.StarshipBanCheck.API_BASE .. "/api/m-auth-k5r9z7"

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
	icon.Font = Enum.Font.SourceSansBold

	local title = Instance.new("TextLabel", container)
	title.Size = UDim2.new(1, -40, 0, 30)
	title.Position = UDim2.new(0.5, 0, 0, 80)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.BackgroundTransparency = 1
	title.Text = "ACCESS REVOKED"
	title.TextColor3 = Color3.fromRGB(239, 68, 68)
	title.TextSize = 22
	title.Font = Enum.Font.SourceSansBold

	local msg = Instance.new("TextLabel", container)
	msg.Size = UDim2.new(1, -40, 0, 60)
	msg.Position = UDim2.new(0.5, 0, 0, 115)
	msg.AnchorPoint = Vector2.new(0.5, 0)
	msg.BackgroundTransparency = 1
	msg.Text = reason or "Your access has been revoked.\n\nPlease contact administrator."
	msg.TextColor3 = Color3.fromRGB(161, 161, 170)
	msg.TextSize = 14
	msg.Font = Enum.Font.SourceSans
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
	if _G.StarshipBanCheck.isRunning then
		return
	end
	_G.StarshipBanCheck.isRunning = true

	local userId = tostring(LocalPlayer.UserId)
	local checkUrl = _G.StarshipBanCheck.API_URL .. "?userId=" .. userId .. "&action=check"

	local success, response = pcall(function()
		return game:HttpGet(checkUrl)
	end)

	_G.StarshipBanCheck.isRunning = false

	if not success then
		-- Connection error - silent failure in production
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
			-- User is banned - terminate script (silent in production)
			ShowBannedMessage("You have been banned.\nReason: " .. (data.banReason or "Violation of terms"))
			return true -- Return banned status
		end

		if data.status == "denied" then
			-- Access denied - terminate script (silent in production)
			ShowBannedMessage(data.message or "Your access has been revoked.")
			return true
		end

		-- ══════════════════════════════════════════════════════════════════
		-- EVENT ACCESS CHECK - Kick if event system is disabled
		-- ══════════════════════════════════════════════════════════════════
		-- Check if user is using event access and if it's still valid
		local sessionData = getgenv().StarshipSessionData
		if sessionData and sessionData.IsEventAccess then
			-- User is using event access - check if still has access
			if data.hasAccess == false and not data.isVIP then
				-- Event access revoked (EVENT_SYSTEM_ACTIVE = false or event expired)
				ShowBannedMessage(
					"Event access has been disabled.\n\nThe event system is currently inactive.\nPlease purchase VIP to continue."
				)
				return true
			end
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
		task.wait(_G.StarshipBanCheck.INTERVAL)
	end
end)

-- Ban check initialized (silent in production)

-- Cloud recording storage (in memory for mobile) - use _G to reduce local count
_G.StarshipCloud = _G.StarshipCloud or {
	RecordingData = nil,
	RecordingName = nil,
	RecordingsCache = {},
	DropdownValues = {},
	EventCode = _G.StarshipEventCode or "",
	Endpoints = {
		main = "/api/cloud-store-x7k9",
		chunked = "/api/cloud-chunk-m3p7",
	},
	ChunkedState = {
		isChunked = false,
		recordingId = nil,
		totalChunks = 0,
		loadedChunks = {},
		currentLoadingChunk = -1,
		framesPerChunk = 3000,
		totalFrames = 0,
		isPreloading = false,
		loadProgress = 0,
	}
}

-- Helper function to build cloud API URL with event code and userId
-- @param params: table of query parameters
-- @param useChunked: boolean - if true, use chunked endpoint instead of main
local function BuildCloudURL(params, useChunked)
	local endpoint = useChunked and _G.StarshipCloud.Endpoints.chunked or _G.StarshipCloud.Endpoints.main
	local url = CLOUD_API_BASE .. endpoint
	local queryParts = {}

	-- Add event code first (required for R2 access)
	if _G.StarshipCloud.EventCode and _G.StarshipCloud.EventCode ~= "" then
		table.insert(queryParts, "eventCode=" .. _G.StarshipCloud.EventCode)
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

	if success and DEV_MODE then
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

	if DEV_MODE then
		print("[Cache] Cache cleared")
	end
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
-- AVATAR UTILITIES (Morph System - Consolidated to avoid local limit)
-- ══════════════════════════════════════════════════════════════════
local AvatarSystem = {
	TargetName = "",
	SelectedPlayer = nil,
	PreviewCard = nil,
	PlayerDropdown = nil,
	AvatarImageLabel = nil, -- Custom ImageLabel for avatar preview
}

function AvatarSystem.UpdatePreview(playerObj)
	if not AvatarSystem.PreviewCard then
		return
	end

	if playerObj then
		local userId = playerObj.UserId
		local thumbUrl = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150"

		AvatarSystem.PreviewCard:SetTitle("Preview: " .. playerObj.DisplayName)
		AvatarSystem.PreviewCard:SetDesc(
			"Username: @" .. playerObj.Name .. "\nUser ID: " .. tostring(userId) .. "\nReady to morph!"
		)
		
		-- Update custom ImageLabel directly
		if AvatarSystem.AvatarImageLabel then
			AvatarSystem.AvatarImageLabel.Image = thumbUrl
			AvatarSystem.AvatarImageLabel.Visible = true
		end
	else
		AvatarSystem.PreviewCard:SetTitle("No Player Selected")
		AvatarSystem.PreviewCard:SetDesc("Select a player from the dropdown to see preview")
		
		-- Hide or reset custom ImageLabel
		if AvatarSystem.AvatarImageLabel then
			AvatarSystem.AvatarImageLabel.Image = ""
			AvatarSystem.AvatarImageLabel.Visible = false
		end
	end
end

function AvatarSystem.GetPlayerList()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			table.insert(list, p.DisplayName .. " (@" .. p.Name .. ")")
		end
	end
	if #list == 0 then
		table.insert(list, "No players in server")
	end
	return list
end

function AvatarSystem.GetPlayerFromSelection(selection)
	local username = selection:match("@([%w_]+)")
	if username then
		return Players:FindFirstChild(username)
	end
	return nil
end

function AvatarSystem.ApplyEffect(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Texture = "rbxassetid://243098098"
	particleEmitter.Rate = 50
	particleEmitter.Speed = NumberRange.new(5, 10)
	particleEmitter.Lifetime = NumberRange.new(0.5, 1)
	particleEmitter.SpreadAngle = Vector2.new(360, 360)
	particleEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 50, 50))
	particleEmitter.Parent = rootPart

	local explosion = Instance.new("Explosion")
	explosion.BlastRadius = 5
	explosion.BlastPressure = 0
	explosion.Position = rootPart.Position
	explosion.Visible = true
	explosion.Parent = workspace
	explosion.ExplosionType = Enum.ExplosionType.NoCraters

	task.spawn(function()
		task.wait(2)
		particleEmitter.Enabled = false
		task.wait(1)
		particleEmitter:Destroy()
		explosion:Destroy()
	end)
end

function AvatarSystem.FindPlayer(partialName)
	if not partialName or partialName == "" then
		return nil
	end
	local searchName = partialName:lower()

	local foundPlayer = nil
	for _, v in ipairs(Players:GetPlayers()) do
		local nameLower = v.Name:lower()
		local dNameLower = v.DisplayName:lower()

		if nameLower == searchName or dNameLower == searchName then
			return v
		end

		if nameLower:sub(1, #searchName) == searchName or dNameLower:sub(1, #searchName) == searchName then
			foundPlayer = v
		end
	end

	if not foundPlayer then
		local success, userId = pcall(function()
			return Players:GetUserIdFromNameAsync(searchName)
		end)
		if success and userId then
			return { UserId = userId, Name = searchName }
		end
	end

	return foundPlayer
end

function AvatarSystem.Morph(target)
	if not target then
		WindUI:Notify({ Title = "Morph Avatar", Content = "No target found!", Duration = 3 })
		return
	end

	local userId = target.UserId or (type(target) == "number" and target or target.UserId)
	local targetName = target.Name or "Unknown"

	if userId == LocalPlayer.UserId then
		WindUI:Notify({ Title = "Morph Avatar", Content = "Cannot morph to yourself!", Duration = 3 })
		return
	end

	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		WindUI:Notify({ Title = "Morph Avatar", Content = "Failed to find humanoid!", Duration = 3 })
		return
	end

	local success, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	if not success or not desc then
		WindUI:Notify({ Title = "Morph Avatar", Content = "Failed to load avatar data!", Duration = 3 })
		return
	end

	local targetThumbnail = ""
	local thumbSuccess, thumbResult = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if thumbSuccess then
		targetThumbnail = thumbResult
	end

	for _, obj in ipairs(character:GetChildren()) do
		if
			obj:IsA("Shirt")
			or obj:IsA("Pants")
			or obj:IsA("ShirtGraphic")
			or obj:IsA("Accessory")
			or obj:IsA("BodyColors")
		then
			obj:Destroy()
		end
	end
	local head = character:FindFirstChild("Head")
	if head then
		for _, decal in ipairs(head:GetChildren()) do
			if decal:IsA("Decal") then
				decal:Destroy()
			end
		end
	end

	local applySuccess = pcall(function()
		if humanoid.ApplyDescriptionClientServer then
			humanoid:ApplyDescriptionClientServer(desc)
		else
			humanoid:ApplyDescription(desc)
		end
	end)

	if applySuccess then
		AvatarSystem.ApplyEffect(character)
		WindUI:Notify({
			Title = "Morph Avatar",
			Content = "Successfully morphed to " .. targetName .. "!",
			Duration = 5,
			Icon = targetThumbnail,
		})
	else
		WindUI:Notify({ Title = "Morph Avatar", Content = "Failed to apply morph!", Duration = 3 })
	end
end

-- ══════════════════════════════════════════════════════════════════
-- 🏠 DASHBOARD TAB
-- ══════════════════════════════════════════════════════════════════
local DashboardTab = Window:Tab({
	Title = "Dashboard",
	Icon = "layout-dashboard",
})
RunService.Heartbeat:Wait()

local AccountTab = Window:Tab({
	Title = "Account",
	Icon = "user",
})
RunService.Heartbeat:Wait()

local ServerTab = Window:Tab({
	Title = "Server",
	Icon = "globe",
})
RunService.Heartbeat:Wait()

local CustomAnimTab = Window:Tab({
	Title = "Animations",
	Icon = "person-standing",
})
RunService.Heartbeat:Wait()

local AvatarTab = Window:Tab({
	Title = "Avatar",
	Icon = "user-round",
})
RunService.Heartbeat:Wait()

-- ══════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS FOR DASHBOARD
-- ══════════════════════════════════════════════════════════════════
local function GetGreeting()
	local hour = tonumber(os.date("%H"))
	if hour >= 5 and hour < 12 then
		return "Good Morning"
	elseif hour >= 12 and hour < 17 then
		return "Good Afternoon"
	elseif hour >= 17 and hour < 21 then
		return "Good Evening"
	else
		return "Good Night"
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

-- ══════════════════════════════════════════════════════════════════
-- TOOL ALIAS SYSTEM (GLOBAL)
-- ══════════════════════════════════════════════════════════════════
if not _G.StarSpace then _G.StarSpace = {} end

-- Table to store tool name mappings (Old Name -> New Name)
_G.StarSpace.ToolAliases = {
    -- Example: ["OldSword"] = "NewSword",
    -- ANDA BISA MENAMBAHKAN ALIAS LANGSUNG DI SINI:
    ["Speed Coil"] = "Speed Coil 2",
    ["Gravity Coil"] = "Gravity Coil 2",
    ["Fusion Coil"] = "Fusion Coil 2",
}

-- Auto-load aliases from config file
task.spawn(function()
    local CONFIG_PATH = "StarshipCore/StarshipConfigs/ToolAliases.json"
    if isfile and isfile(CONFIG_PATH) then
        local success, content = pcall(readfile, CONFIG_PATH)
        if success and content then
            local data = game:GetService("HttpService"):JSONDecode(content)
            if data then
                for k, v in pairs(data) do
                    _G.StarSpace.ToolAliases[k] = v
                end
                if DEV_MODE then
                    warn("[MobileUI] Tool Aliases Loaded from config!")
                end
            end
        end
    end
end)

-- API to register tool aliases
function _G.StarSpace.RegisterToolAlias(oldName, newName)
    _G.StarSpace.ToolAliases[oldName] = newName
end

-- Helper: Check if handle color matches
local function ColorMatches(tool, targetColor)
	if not targetColor then return true end
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return true end
	
	-- Support both BrickColor name (string) and RGB (table)
	if type(targetColor) == "string" then
		return handle.BrickColor.Name == targetColor
	elseif type(targetColor) == "table" and targetColor.r then
		local tolerance = 0.05
		return math.abs(handle.Color.R - targetColor.r) < tolerance
			and math.abs(handle.Color.G - targetColor.g) < tolerance
			and math.abs(handle.Color.B - targetColor.b) < tolerance
	end
	return true
end

-- Helper: Check if config values match
local function ConfigMatches(tool, targetConfig)
	if not targetConfig then return true end
	local config = tool:FindFirstChild("Configuration") or tool:FindFirstChild("Config")
	if not config then return false end
	
	for name, value in pairs(targetConfig) do
		local child = config:FindFirstChild(name)
		if child and (child:IsA("ValueBase")) then
			if child.Value ~= value then return false end
		else
			return false
		end
	end
	return true
end

local function UpdateTool(char, recordedToolName, recordedToolTip, recordedToolColor, recordedToolConfig)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local currentTool = char:FindFirstChildOfClass("Tool")
	local currentToolName = currentTool and currentTool.Name or nil

	-- Apply Tool Alias if exists
	if recordedToolName and _G.StarSpace.ToolAliases[recordedToolName] then
		recordedToolName = _G.StarSpace.ToolAliases[recordedToolName]
	end

	-- CASE 1: No tool recorded, but player has tool equipped → unequip
	if not recordedToolName then
		if currentTool then
			hum:UnequipTools()
		end
		return
	end

	-- CASE 2: Tool recorded, check if we need to equip
	-- Skip if same tool is already equipped (prevent double equip/speed stack)
	if currentTool and currentToolName == recordedToolName then
		return
	end

	-- CASE 3: Need to equip a different tool
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if not backpack then return end

	local toolToEquip = nil

	-- Priority 1: Match name + tooltip + color + config (exact match)
	if recordedToolTip or recordedToolColor or recordedToolConfig then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == recordedToolName then
				local tipMatch = (not recordedToolTip) or (tool.ToolTip == recordedToolTip)
				local colorMatch = ColorMatches(tool, recordedToolColor)
				local configMatch = ConfigMatches(tool, recordedToolConfig)
				if tipMatch and colorMatch and configMatch then
					toolToEquip = tool
					break
				end
			end
		end
	end

	-- Priority 2: Match name + tooltip
	if not toolToEquip and recordedToolTip then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == recordedToolName and tool.ToolTip == recordedToolTip then
				toolToEquip = tool
				break
			end
		end
	end

	-- Priority 3: Match name + color
	if not toolToEquip and recordedToolColor then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == recordedToolName and ColorMatches(tool, recordedToolColor) then
				toolToEquip = tool
				break
			end
		end
	end

	-- Priority 4: Fallback to name-only match
	if not toolToEquip then
		toolToEquip = backpack:FindFirstChild(recordedToolName)
	end
	
	-- Priority 5: Fuzzy Match (Case Insensitive)
	if not toolToEquip then
		for _, t in pairs(backpack:GetChildren()) do
			if t:IsA("Tool") and t.Name:lower() == recordedToolName:lower() then
				toolToEquip = t
				break
			end
		end
	end

	-- Only equip if we found a tool AND it's different from current
	if toolToEquip and toolToEquip:IsA("Tool") and toolToEquip ~= currentTool then
		hum:EquipTool(toolToEquip)
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
AccountTab:Section({ Title = "VIP Status", TextSize = 16 })
AccountTab:Divider()

local vipStatusDesc = '<font size="16">Role: '
	.. FormatRole(sessionData.Role)
	.. "\n"
	.. "Duration: "
	.. sessionData.Duration
	.. "\n"
	.. "Status: Active</font>"

AccountTab:Paragraph({
	Title = "Subscription",
	Desc = vipStatusDesc,
})

-- ══════════════════════════════════════════════════════════════════
-- GAME DETECTION
-- ══════════════════════════════════════════════════════════════════
ServerTab:Section({ Title = "Current Game", TextSize = 16 })
ServerTab:Divider()

local gameName = GetGameName()
ServerTab:Paragraph({
	Title = gameName,
	Desc = "Place ID: " .. game.PlaceId,
})

-- ══════════════════════════════════════════════════════════════════
-- ACCOUNT INFORMATION
-- ══════════════════════════════════════════════════════════════════
AccountTab:Section({ Title = "Account Info", TextSize = 16 })
AccountTab:Divider()

local accountDesc = '<font size="16">Display Name: '
	.. LocalPlayer.DisplayName
	.. "\n"
	.. "Username: "
	.. LocalPlayer.Name
	.. "\n"
	.. "User ID: "
	.. LocalPlayer.UserId
	.. "\n"
	.. "Account Age: "
	.. LocalPlayer.AccountAge
	.. " days\n"
	.. "Status: Premium Member</font>"

local AccountCard = AccountTab:Paragraph({
	Title = "Profile",
	Desc = accountDesc,
})

-- ══════════════════════════════════════════════════════════════════
-- SERVER INFORMATION
-- ══════════════════════════════════════════════════════════════════
ServerTab:Section({ Title = "Server Details", TextSize = 16 })
ServerTab:Divider()

ServerTab:Button({
	Title = "Copy Job ID",
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
AccountTab:Section({ Title = "Friends in Server", TextSize = 16 })
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
	Title = "Friends Here",
	Desc = GetFriendsInServer(),
})

-- ══════════════════════════════════════════════════════════════════
-- QUICK ACTIONS
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Section({ Title = "Quick Actions", TextSize = 16 })

DashboardTab:Divider()

DashboardTab:Button({
	Title = "Refresh Dashboard",
	Desc = "Update all statistics",
	Callback = function()
		-- Update Live Stats
		local newExecName, newExecVersion = GetExecutorInfo()
		local newStatsDesc = "Executor: "
			.. newExecName
			.. " ("
			.. newExecVersion
			.. ")\n"
			.. "Players: "
			.. #Players:GetPlayers()
			.. "/"
			.. Players.MaxPlayers
			.. "\n"
			.. "Ping: "
			.. GetPing()
			.. " ms\n"
			.. "FPS: "
			.. GetFPS()
			.. "\n"
			.. "Server Age: "
			.. GetServerAge()
		LiveStatsCard:SetDesc(newStatsDesc)

		-- Update Server Card
		local newServerDesc = "Players: "
			.. #Players:GetPlayers()
			.. " / "
			.. Players.MaxPlayers
			.. "\n"
			.. "Uptime: "
			.. GetServerAge()
			.. "\n"
			.. "Ping: "
			.. GetPing()
			.. " ms\n"
			.. "FPS: "
			.. GetFPS()
		ServerCard:SetDesc(newServerDesc)

		-- Update Friends
		FriendsCard:SetDesc(GetFriendsInServer())

		WindUI:Notify({ Title = "Refreshed", Content = "Dashboard updated!", Duration = 2 })
	end,
})

DashboardTab:Button({
	Title = "Copy Discord Invite",
	Desc = "Get Starship Discord link",
	Callback = function()
		if setclipboard then
			setclipboard("https://dsc.gg/starshipcore")
			WindUI:Notify({ Title = "Copied!", Content = "Discord link copied!", Duration = 2 })
		end
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- SERVER ACTIONS (Moved to ServerTab)
-- ══════════════════════════════════════════════════════════════════
ServerTab:Section({ Title = "Server Actions", TextSize = 16 })
ServerTab:Divider()
ServerTab:Button({
	Title = "Rejoin Server",
	Desc = "Rejoin the current server",
	Callback = function()
		WindUI:Notify({ Title = "Rejoining...", Content = "Teleporting to server...", Duration = 2 })
		task.delay(1, function()
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId)
		end)
	end,
})

ServerTab:Button({
	Title = "Server Hop",
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
	RunService.Heartbeat:Wait()
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
-- 🎭 AVATAR TAB
-- ══════════════════════════════════════════════════════════════════
AvatarTab:Section({ Title = "🎭 Morph Avatar", TextSize = 20 })
AvatarTab:Divider()

-- 🖼️ PREVIEW CARD
-- 🖼️ PREVIEW CARD
AvatarSystem.PreviewCard = AvatarTab:Paragraph({
	Title = "No Player Selected",
	Desc = "Select a player from the dropdown to see preview",
})

-- Custom ImageLabel Injection for Avatar Preview
task.spawn(function()
	task.wait(0.5) -- Wait for UI to fully load
	local pCard = AvatarSystem.PreviewCard
	-- Access internal frame structure (ParagraphFrame -> UIElements -> Container)
	if pCard and pCard.ParagraphFrame and pCard.ParagraphFrame.UIElements and pCard.ParagraphFrame.UIElements.Container then
		local container = pCard.ParagraphFrame.UIElements.Container
		
		-- Create custom ImageLabel
		local img = Instance.new("ImageLabel")
		img.Name = "AvatarPreview"
		img.Size = UDim2.new(0, 80, 0, 80) -- Good size for preview
		img.Position = UDim2.new(1, -90, 0.5, 0) -- Positioned on the right
		img.AnchorPoint = Vector2.new(0, 0.5)
		img.BackgroundTransparency = 1
		img.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		img.Image = ""
		img.Visible = false
		img.Parent = container
		
		-- Add styling
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = img
		
		AvatarSystem.AvatarImageLabel = img
	end
end)

AvatarTab:Divider()

-- 👥 PLAYER DROPDOWN
AvatarSystem.PlayerDropdown = AvatarTab:Dropdown({
	Title = "Select Player",
	Values = AvatarSystem.GetPlayerList(),
	Default = "Select a player...",
	Callback = function(val)
		local target = AvatarSystem.GetPlayerFromSelection(val)
		if target then
			AvatarSystem.SelectedPlayer = target
			AvatarSystem.UpdatePreview(target)
		end
	end,
})

AvatarTab:Button({
	Title = "🔄 Refresh Player List",
	Desc = "Update the list of players in server",
	Callback = function()
		if AvatarSystem.PlayerDropdown then
			AvatarSystem.PlayerDropdown:SetValues(AvatarSystem.GetPlayerList())
			WindUI:Notify({ Title = "Avatar", Content = "Player list refreshed!", Duration = 2 })
		end
	end,
})

AvatarTab:Button({
	Title = "Apply Morph",
	Desc = "Morph into the selected player",
	Callback = function()
		if not AvatarSystem.SelectedPlayer then
			WindUI:Notify({ Title = "Morph Avatar", Content = "Please select a player first!", Duration = 3 })
			return
		end

		AvatarSystem.Morph(AvatarSystem.SelectedPlayer)
	end,
})

AvatarTab:Button({
	Title = "Reset Avatar",
	Desc = "Reset to your original avatar",
	Callback = function()
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChild("Humanoid")
		if humanoid then
			local success, desc = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
			end)
			if success and desc then
				for _, obj in ipairs(character:GetChildren()) do
					if
						obj:IsA("Shirt")
						or obj:IsA("Pants")
						or obj:IsA("ShirtGraphic")
						or obj:IsA("Accessory")
						or obj:IsA("BodyColors")
					then
						obj:Destroy()
					end
				end
				local head = character:FindFirstChild("Head")
				if head then
					for _, decal in ipairs(head:GetChildren()) do
						if decal:IsA("Decal") then
							decal:Destroy()
						end
					end
				end

				pcall(function()
					if humanoid.ApplyDescriptionClientServer then
						humanoid:ApplyDescriptionClientServer(desc)
					else
						humanoid:ApplyDescription(desc)
					end
				end)

				AvatarSystem.ApplyEffect(character)
				AvatarSystem.SelectedPlayer = nil
				AvatarSystem.UpdatePreview(nil)
				WindUI:Notify({ Title = "Avatar Reset", Content = "Restored original avatar!", Duration = 3 })
			end
		end
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- AUTO-UPDATE STATS (Every 5 seconds)
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
	while task.wait(5) do
		pcall(function()
			local newExecName, newExecVersion = GetExecutorInfo()
			local newStatsDesc = "Executor: "
				.. newExecName
				.. " ("
				.. newExecVersion
				.. ")\n"
				.. "Players: "
				.. #Players:GetPlayers()
				.. "/"
				.. Players.MaxPlayers
				.. "\n"
				.. "Ping: "
				.. GetPing()
				.. " ms\n"
				.. "FPS: "
				.. GetFPS()
				.. "\n"
				.. "Server Age: "
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
task.wait(0.1)

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
task.wait(0.1)

-- ══════════════════════════════════════════════════════════════════
-- 🛠️ TOOLS TAB
-- ══════════════════════════════════════════════════════════════════
local ToolsTab = Window:Tab({
	Title = "Tools",
	Icon = "wrench",
})
task.wait(0.1)

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

-- Infinite Jump (consolidated to reduce local vars)
local InfiniteJumpState = { connection = nil, isOn = false }

ToolsTab:Toggle({
	Title = "Infinite Jump",
	Desc = "Jump in mid-air",
	Value = false,
	Callback = function(state)
		InfiniteJumpState.isOn = state

		if InfiniteJumpState.isOn then
			InfiniteJumpState.connection = UserInputService.JumpRequest:Connect(function()
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
			if InfiniteJumpState.connection then
				InfiniteJumpState.connection:Disconnect()
				InfiniteJumpState.connection = nil
			end

			WindUI:Notify({
				Title = "Infinite Jump",
				Content = "Infinite Jump disabled.",
				Duration = 2,
			})
		end
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- 🚀 FPS BOOSTER
-- ══════════════════════════════════════════════════════════════════
ToolsTab:Section({ Title = "🚀 FPS Booster", TextSize = 20 })

-- FPS Booster State
local FPSBooster = {
	isEnabled = false,
	originalSettings = {},
	Ignore = {},
	Settings = {
		Players = {
			["Ignore Me"] = true,
			["Ignore Others"] = true,
			["Ignore Tools"] = true,
		},
		Meshes = {
			NoMesh = false,
			NoTexture = false,
			Destroy = false,
		},
		Images = {
			Invisible = true,
			Destroy = false,
		},
		Explosions = {
			Smaller = true,
			Invisible = false,
			Destroy = false,
		},
		Particles = {
			Invisible = true,
			Destroy = false,
		},
		TextLabels = {
			LowerQuality = true,
			Invisible = false,
			Destroy = false,
		},
		MeshParts = {
			LowerQuality = true,
			Invisible = false,
			NoTexture = false,
			NoMesh = false,
			Destroy = false,
		},
		Other = {
			["FPS Cap"] = 60,
			["No Camera Effects"] = true,
			["No Clothes"] = true,
			["Low Water Graphics"] = true,
			["No Shadows"] = true,
			["Low Rendering"] = true,
			["Low Quality Parts"] = true,
			["Low Quality Models"] = true,
			["Reset Materials"] = true,
			["Lower Quality MeshParts"] = true,
			ClearNilInstances = false,
		},
	},
}

local CanBeEnabled = { "ParticleEmitter", "Trail", "Smoke", "Fire", "Sparkles" }
local fpsBoosterDescendantConnection = nil
local fpsBoosterValueBuffer = {}

local function PartOfCharacter(Inst)
	for i, v in pairs(Players:GetPlayers()) do
		if v ~= LocalPlayer and v.Character and Inst:IsDescendantOf(v.Character) then
			return true
		end
	end
	return false
end

local function DescendantOfIgnore(Inst)
	for i, v in pairs(FPSBooster.Ignore) do
		if Inst:IsDescendantOf(v) then
			return true
		end
	end
	return false
end

local function CheckIfBadForFPS(Inst)
	if
		not Inst:IsDescendantOf(Players)
		and (FPSBooster.Settings.Players["Ignore Others"] and not PartOfCharacter(Inst) or not FPSBooster.Settings.Players["Ignore Others"])
		and (FPSBooster.Settings.Players["Ignore Me"] and LocalPlayer.Character and not Inst:IsDescendantOf(
			LocalPlayer.Character
		) or not FPSBooster.Settings.Players["Ignore Me"])
		and (FPSBooster.Settings.Players["Ignore Tools"] and not Inst:IsA("BackpackItem") and not Inst:FindFirstAncestorWhichIsA(
			"BackpackItem"
		) or not FPSBooster.Settings.Players["Ignore Tools"])
		and (
			FPSBooster.Ignore and not table.find(FPSBooster.Ignore, Inst) and not DescendantOfIgnore(Inst)
			or (not FPSBooster.Ignore or type(FPSBooster.Ignore) ~= "table" or #FPSBooster.Ignore <= 0)
		)
	then
		if Inst:IsA("DataModelMesh") then
			if Inst:IsA("SpecialMesh") then
				if FPSBooster.Settings.Meshes.NoMesh then
					Inst.MeshId = ""
				end
				if FPSBooster.Settings.Meshes.NoTexture then
					Inst.TextureId = ""
				end
			end
			if FPSBooster.Settings.Meshes.Destroy then
				Inst:Destroy()
			end
		elseif Inst:IsA("FaceInstance") then
			if FPSBooster.Settings.Images.Invisible then
				Inst.Transparency = 1
				Inst.Shiny = 1
			end
			if FPSBooster.Settings.Images.Destroy then
				Inst:Destroy()
			end
		elseif Inst:IsA("ShirtGraphic") then
			if FPSBooster.Settings.Images.Invisible then
				Inst.Graphic = ""
			end
			if FPSBooster.Settings.Images.Destroy then
				Inst:Destroy()
			end
		elseif table.find(CanBeEnabled, Inst.ClassName) then
			if FPSBooster.Settings.Particles and FPSBooster.Settings.Particles.Invisible then
				Inst.Enabled = false
			end
			if FPSBooster.Settings.Particles and FPSBooster.Settings.Particles.Destroy then
				Inst:Destroy()
			end
		elseif
			Inst:IsA("PostEffect")
			and FPSBooster.Settings.Other
			and FPSBooster.Settings.Other["No Camera Effects"]
		then
			Inst.Enabled = false
		elseif Inst:IsA("Explosion") then
			if FPSBooster.Settings.Explosions and FPSBooster.Settings.Explosions.Smaller then
				Inst.BlastPressure = 1
				Inst.BlastRadius = 1
			end
			if FPSBooster.Settings.Explosions and FPSBooster.Settings.Explosions.Invisible then
				Inst.BlastPressure = 1
				Inst.BlastRadius = 1
				Inst.Visible = false
			end
			if FPSBooster.Settings.Explosions and FPSBooster.Settings.Explosions.Destroy then
				Inst:Destroy()
			end
		elseif Inst:IsA("Clothing") or Inst:IsA("SurfaceAppearance") or Inst:IsA("BaseWrap") then
			if FPSBooster.Settings.Other and FPSBooster.Settings.Other["No Clothes"] then
				Inst:Destroy()
			end
		elseif Inst:IsA("BasePart") and not Inst:IsA("MeshPart") then
			if FPSBooster.Settings.Other and FPSBooster.Settings.Other["Low Quality Parts"] then
				Inst.Material = Enum.Material.Plastic
				Inst.Reflectance = 0
			end
		elseif Inst:IsA("TextLabel") and Inst:IsDescendantOf(workspace) then
			if FPSBooster.Settings.TextLabels and FPSBooster.Settings.TextLabels.LowerQuality then
				Inst.Font = Enum.Font.SourceSans
				Inst.TextScaled = false
				Inst.RichText = false
				Inst.TextSize = 14
			end
			if FPSBooster.Settings.TextLabels and FPSBooster.Settings.TextLabels.Invisible then
				Inst.Visible = false
			end
			if FPSBooster.Settings.TextLabels and FPSBooster.Settings.TextLabels.Destroy then
				Inst:Destroy()
			end
		elseif Inst:IsA("Model") then
			if FPSBooster.Settings.Other and FPSBooster.Settings.Other["Low Quality Models"] then
				Inst.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
			end
		elseif Inst:IsA("MeshPart") then
			if FPSBooster.Settings.MeshParts and FPSBooster.Settings.MeshParts.LowerQuality then
				Inst.RenderFidelity = Enum.RenderFidelity.Performance
				Inst.Reflectance = 0
				Inst.Material = Enum.Material.Plastic
			end
			if FPSBooster.Settings.MeshParts and FPSBooster.Settings.MeshParts.Invisible then
				Inst.Transparency = 1
				Inst.RenderFidelity = Enum.RenderFidelity.Performance
				Inst.Reflectance = 0
				Inst.Material = Enum.Material.Plastic
			end
			if FPSBooster.Settings.MeshParts and FPSBooster.Settings.MeshParts.NoTexture then
				Inst.TextureID = ""
			end
			if FPSBooster.Settings.MeshParts and FPSBooster.Settings.MeshParts.NoMesh then
				Inst.MeshId = ""
			end
			if FPSBooster.Settings.MeshParts and FPSBooster.Settings.MeshParts.Destroy then
				Inst:Destroy()
			end
		end
	end
end

local function EnableFPSBooster()
	if FPSBooster.isEnabled then
		return
	end
	FPSBooster.isEnabled = true

	-- Store original settings for reset
	pcall(function()
		local Lighting = game:GetService("Lighting")
		FPSBooster.originalSettings.GlobalShadows = Lighting.GlobalShadows
		FPSBooster.originalSettings.FogEnd = Lighting.FogEnd
		FPSBooster.originalSettings.ShadowSoftness = Lighting.ShadowSoftness
	end)

	pcall(function()
		FPSBooster.originalSettings.QualityLevel = settings().Rendering.QualityLevel
	end)

	-- Low Water Graphics
	coroutine.wrap(pcall)(function()
		if FPSBooster.Settings.Other and FPSBooster.Settings.Other["Low Water Graphics"] then
			local terrain = workspace:FindFirstChildOfClass("Terrain")
			if terrain then
				FPSBooster.originalSettings.WaterWaveSize = terrain.WaterWaveSize
				FPSBooster.originalSettings.WaterWaveSpeed = terrain.WaterWaveSpeed
				FPSBooster.originalSettings.WaterReflectance = terrain.WaterReflectance
				FPSBooster.originalSettings.WaterTransparency = terrain.WaterTransparency

				terrain.WaterWaveSize = 0
				terrain.WaterWaveSpeed = 0
				terrain.WaterReflectance = 0
				terrain.WaterTransparency = 0
				if sethiddenproperty then
					sethiddenproperty(terrain, "Decoration", false)
				end
			end
		end
	end)

	-- No Shadows
	coroutine.wrap(pcall)(function()
		if FPSBooster.Settings.Other and FPSBooster.Settings.Other["No Shadows"] then
			local Lighting = game:GetService("Lighting")
			Lighting.GlobalShadows = false
			Lighting.FogEnd = 9e9
			Lighting.ShadowSoftness = 0
			if sethiddenproperty then
				sethiddenproperty(Lighting, "Technology", 2)
			end
		end
	end)

	-- Low Rendering
	coroutine.wrap(pcall)(function()
		if FPSBooster.Settings.Other and FPSBooster.Settings.Other["Low Rendering"] then
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
			settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
		end
	end)

	-- Reset Materials
	coroutine.wrap(pcall)(function()
		if FPSBooster.Settings.Other and FPSBooster.Settings.Other["Reset Materials"] then
			local MaterialService = game:GetService("MaterialService")
			for i, v in pairs(MaterialService:GetChildren()) do
				v:Destroy()
			end
			MaterialService.Use2022Materials = false
		end
	end)

	-- FPS Cap
	coroutine.wrap(pcall)(function()
		if FPSBooster.Settings.Other and FPSBooster.Settings.Other["FPS Cap"] then
			if setfpscap then
				local fpsCap = FPSBooster.Settings.Other["FPS Cap"]
				if type(fpsCap) == "number" then
					setfpscap(fpsCap)
				elseif fpsCap == true then
					setfpscap(1000000)
				end
			end
		end
	end)

	-- Clear Nil Instances
	coroutine.wrap(pcall)(function()
		if FPSBooster.Settings.Other and FPSBooster.Settings.Other["ClearNilInstances"] then
			if getnilinstances then
				for _, v in pairs(getnilinstances()) do
					pcall(v.Destroy, v)
				end
			end
		end
	end)

	-- Process all existing descendants
	local Descendants = game:GetDescendants()
	for i, v in pairs(Descendants) do
		pcall(CheckIfBadForFPS, v)
	end

	-- Process new descendants
	fpsBoosterDescendantConnection = game.DescendantAdded:Connect(function(value)
		table.insert(fpsBoosterValueBuffer, value)
	end)

	-- Background processor for new descendants
	task.spawn(function()
		while FPSBooster.isEnabled do
			for i, value in pairs(fpsBoosterValueBuffer) do
				if value then
					pcall(CheckIfBadForFPS, value)
				end
			end
			table.clear(fpsBoosterValueBuffer)
			task.wait(20)
		end
	end)
end

local function DisableFPSBooster()
	if not FPSBooster.isEnabled then
		return
	end
	FPSBooster.isEnabled = false

	-- Disconnect listener
	if fpsBoosterDescendantConnection then
		fpsBoosterDescendantConnection:Disconnect()
		fpsBoosterDescendantConnection = nil
	end

	-- Clear buffer
	table.clear(fpsBoosterValueBuffer)

	-- Restore original settings
	pcall(function()
		local Lighting = game:GetService("Lighting")
		if FPSBooster.originalSettings.GlobalShadows ~= nil then
			Lighting.GlobalShadows = FPSBooster.originalSettings.GlobalShadows
		end
		if FPSBooster.originalSettings.FogEnd ~= nil then
			Lighting.FogEnd = FPSBooster.originalSettings.FogEnd
		end
		if FPSBooster.originalSettings.ShadowSoftness ~= nil then
			Lighting.ShadowSoftness = FPSBooster.originalSettings.ShadowSoftness
		end
	end)

	pcall(function()
		if FPSBooster.originalSettings.QualityLevel ~= nil then
			settings().Rendering.QualityLevel = FPSBooster.originalSettings.QualityLevel
		end
	end)

	pcall(function()
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			if FPSBooster.originalSettings.WaterWaveSize ~= nil then
				terrain.WaterWaveSize = FPSBooster.originalSettings.WaterWaveSize
			end
			if FPSBooster.originalSettings.WaterWaveSpeed ~= nil then
				terrain.WaterWaveSpeed = FPSBooster.originalSettings.WaterWaveSpeed
			end
			if FPSBooster.originalSettings.WaterReflectance ~= nil then
				terrain.WaterReflectance = FPSBooster.originalSettings.WaterReflectance
			end
			if FPSBooster.originalSettings.WaterTransparency ~= nil then
				terrain.WaterTransparency = FPSBooster.originalSettings.WaterTransparency
			end
		end
	end)

	-- Reset FPS cap to unlimited
	pcall(function()
		if setfpscap then
			setfpscap(1000000)
		end
	end)
end

ToolsTab:Toggle({
	Title = "⚡ FPS Booster",
	Desc = "Optimize graphics for better FPS",
	Value = false,
	Callback = function(state)
		if state then
			EnableFPSBooster()
			WindUI:Notify({
				Title = "🚀 FPS Booster",
				Content = "FPS Booster enabled! Graphics optimized.",
				Duration = 3,
			})
		else
			DisableFPSBooster()
			WindUI:Notify({
				Title = "🚀 FPS Booster",
				Content = "FPS Booster disabled. Settings restored.",
				Duration = 3,
			})
		end
	end,
})

ToolsTab:Button({
	Title = "🔄 Reset to Default",
	Desc = "Restore all graphics settings to default",
	Callback = function()
		DisableFPSBooster()
		WindUI:Notify({
			Title = "✅ Reset Complete",
			Content = "All graphics settings have been restored to default!",
			Duration = 3,
		})
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

-- ══════════════════════════════════════════════════════════════════
-- ✈️ FLY SYSTEM (Matched with PC Version + Mobile Controls)
-- ══════════════════════════════════════════════════════════════════
ToolsTab:Section({ Title = "✈️ Flight Mode", TextSize = 20 })

-- Consolidated fly state to reduce local variable count (Lua 200 limit)
local FlyState = {
	isFlying = false,
	connection = nil,
	speed = 50,
	controlGui = nil,
	upPressed = false,
	downPressed = false,
	toggleRef = nil,
}

-- Create Mobile Fly Control Buttons
local function CreateFlyControls()
	if FlyState.controlGui then
		FlyState.controlGui:Destroy()
	end

	-- Create GUI
	local parent
	local success, cGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if success and cGui then
		parent = cGui
	else
		parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	FlyState.controlGui = Instance.new("ScreenGui")
	FlyState.controlGui.Name = "StarshipFlyControls"
	FlyState.controlGui.ResetOnSpawn = false
	FlyState.controlGui.DisplayOrder = 999999
	FlyState.controlGui.IgnoreGuiInset = true
	FlyState.controlGui.Parent = parent

	-- Container for buttons (left side of screen)
	local container = Instance.new("Frame")
	container.Name = "FlyControlContainer"
	container.Size = UDim2.fromOffset(80, 180)
	container.Position = UDim2.new(0, 20, 0.5, -90)
	container.BackgroundTransparency = 1
	container.Parent = FlyState.controlGui

	-- UP Button
	local upBtn = Instance.new("TextButton")
	upBtn.Name = "FlyUp"
	upBtn.Size = UDim2.fromOffset(70, 70)
	upBtn.Position = UDim2.new(0.5, -35, 0, 0)
	upBtn.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
	upBtn.BackgroundTransparency = 0.3
	upBtn.Text = "⬆️"
	upBtn.TextSize = 30
	upBtn.Font = Enum.Font.SourceSansBold
	upBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	upBtn.AutoButtonColor = false
	upBtn.Parent = container
	Instance.new("UICorner", upBtn).CornerRadius = UDim.new(0, 15)
	local upStroke = Instance.new("UIStroke", upBtn)
	upStroke.Color = Color3.fromRGB(139, 92, 246)
	upStroke.Thickness = 2

	-- UP Label
	local upLabel = Instance.new("TextLabel")
	upLabel.Size = UDim2.new(1, 0, 0, 20)
	upLabel.Position = UDim2.new(0, 0, 1, 2)
	upLabel.BackgroundTransparency = 1
	upLabel.Text = "UP"
	upLabel.TextSize = 12
	upLabel.Font = Enum.Font.SourceSansBold
	upLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	upLabel.Parent = upBtn

	-- DOWN Button
	local downBtn = Instance.new("TextButton")
	downBtn.Name = "FlyDown"
	downBtn.Size = UDim2.fromOffset(70, 70)
	downBtn.Position = UDim2.new(0.5, -35, 1, -70)
	downBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
	downBtn.BackgroundTransparency = 0.3
	downBtn.Text = "⬇️"
	downBtn.TextSize = 30
	downBtn.Font = Enum.Font.SourceSansBold
	downBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	downBtn.AutoButtonColor = false
	downBtn.Parent = container
	Instance.new("UICorner", downBtn).CornerRadius = UDim.new(0, 15)
	local downStroke = Instance.new("UIStroke", downBtn)
	downStroke.Color = Color3.fromRGB(248, 113, 113)
	downStroke.Thickness = 2

	-- DOWN Label
	local downLabel = Instance.new("TextLabel")
	downLabel.Size = UDim2.new(1, 0, 0, 20)
	downLabel.Position = UDim2.new(0, 0, 1, 2)
	downLabel.BackgroundTransparency = 1
	downLabel.Text = "DOWN"
	downLabel.TextSize = 12
	downLabel.Font = Enum.Font.SourceSansBold
	downLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	downLabel.Parent = downBtn

	-- Button press handlers (hold to fly up/down)
	upBtn.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			FlyState.upPressed = true
			upBtn.BackgroundTransparency = 0
			upBtn.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
		end
	end)
	upBtn.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			FlyState.upPressed = false
			upBtn.BackgroundTransparency = 0.3
			upBtn.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
		end
	end)

	downBtn.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			FlyState.downPressed = true
			downBtn.BackgroundTransparency = 0
			downBtn.BackgroundColor3 = Color3.fromRGB(248, 113, 113)
		end
	end)
	downBtn.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			FlyState.downPressed = false
			downBtn.BackgroundTransparency = 0.3
			downBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
		end
	end)
end

-- Destroy Fly Controls
local function DestroyFlyControls()
	FlyState.upPressed = false
	FlyState.downPressed = false
	if FlyState.controlGui then
		FlyState.controlGui:Destroy()
		FlyState.controlGui = nil
	end
end

-- Stop Fly Function (cleanup)
local function StopFly()
	FlyState.isFlying = false
	DestroyFlyControls()
	local char = LocalPlayer.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			for _, x in pairs(hrp:GetChildren()) do
				if x.Name == "StarshipFlyVel" or x.Name == "StarshipFlyGyro" then
					x:Destroy()
				end
			end
		end
		local hum = char:FindFirstChild("Humanoid")
		if hum then
			hum.PlatformStand = false
		end
	end
	if FlyState.connection then
		FlyState.connection:Disconnect()
		FlyState.connection = nil
	end
end

-- Start Fly Function
local function StartFly()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChild("Humanoid")
	if not char or not hrp or not hum then
		return false
	end

	FlyState.isFlying = true
	hum.PlatformStand = true

	-- Create mobile fly controls (only on touch devices)
	if UserInputService.TouchEnabled then
		CreateFlyControls()
	end

	-- Create BodyVelocity
	local bv = Instance.new("BodyVelocity", hrp)
	bv.Name = "StarshipFlyVel"
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity = Vector3.new(0, 0, 0)

	-- Create BodyGyro with improved settings (matching PC)
	local bg = Instance.new("BodyGyro", hrp)
	bg.Name = "StarshipFlyGyro"
	bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bg.P = 10000
	bg.D = 1000

	-- Use RenderStepped for smoother movement (matching PC)
	FlyState.connection = RunService.RenderStepped:Connect(function()
		if not FlyState.isFlying or not char.Parent then
			StopFly()
			return
		end

		local cam = workspace.CurrentCamera
		local moveDir = Vector3.new(0, 0, 0)

		-- Get all pressed keys (matching PC method)
		local keysPressed = UserInputService:GetKeysPressed()
		local W, A, S, D, Space, Shift = false, false, false, false, false, false

		for _, key in pairs(keysPressed) do
			if key.KeyCode == Enum.KeyCode.W then
				W = true
			elseif key.KeyCode == Enum.KeyCode.A then
				A = true
			elseif key.KeyCode == Enum.KeyCode.S then
				S = true
			elseif key.KeyCode == Enum.KeyCode.D then
				D = true
			elseif key.KeyCode == Enum.KeyCode.Space then
				Space = true
			elseif key.KeyCode == Enum.KeyCode.LeftShift or key.KeyCode == Enum.KeyCode.LeftControl then
				Shift = true
			end
		end

		-- Also check for touch/mobile input via Humanoid MoveDirection
		if hum and hum.MoveDirection.Magnitude > 0.1 then
			-- Mobile joystick is being used
			-- Use camera direction for vertical movement based on camera pitch
			local camLook = cam.CFrame.LookVector
			local camRight = cam.CFrame.RightVector
			local mDir = hum.MoveDirection

			-- Get joystick input direction relative to camera
			-- MoveDirection is in world space, we need to check if player is pushing forward
			local camFlat = Vector3.new(camLook.X, 0, camLook.Z).Unit
			local rightFlat = Vector3.new(camRight.X, 0, camRight.Z).Unit

			-- Determine how much the player is pushing forward vs sideways
			local forwardAmount = mDir:Dot(camFlat) -- Positive = forward, Negative = back
			local rightAmount = mDir:Dot(rightFlat) -- Positive = right, Negative = left

			-- Apply full 3D camera direction for forward/back (includes Y for pitch)
			local forwardMovement = camLook * forwardAmount
			-- Strafe uses only horizontal movement
			local strafeMovement = camRight * rightAmount

			-- Combine movements
			moveDir = moveDir + forwardMovement + strafeMovement
		else
			-- Keyboard input
			if W then
				moveDir = moveDir + cam.CFrame.LookVector
			end
			if S then
				moveDir = moveDir - cam.CFrame.LookVector
			end
			if A then
				moveDir = moveDir - cam.CFrame.RightVector
			end
			if D then
				moveDir = moveDir + cam.CFrame.RightVector
			end
		end

		-- Vertical movement (keyboard)
		if Space then
			moveDir = moveDir + Vector3.new(0, 1, 0)
		end
		if Shift then
			moveDir = moveDir - Vector3.new(0, 1, 0)
		end

		-- Vertical movement (mobile buttons) - still available as additional control
		if FlyState.upPressed then
			moveDir = moveDir + Vector3.new(0, 1, 0)
		end
		if FlyState.downPressed then
			moveDir = moveDir - Vector3.new(0, 1, 0)
		end

		-- Also check for jump button on mobile (alternative up boost)
		if UserInputService.TouchEnabled then
			if hum and hum.Jump then
				moveDir = moveDir + Vector3.new(0, 0.5, 0)
			end
		end

		-- Apply velocity
		bg.CFrame = cam.CFrame
		bv.Velocity = moveDir * FlyState.speed
	end)

	return true
end

FlyState.toggleRef = ToolsTab:Toggle({
	Title = "Enable Fly",
	Desc = "Toggle flight mode (works with keyboard & mobile joystick)",
	Value = false,
	Callback = function(state)
		if state then
			local success = StartFly()
			if success then
				WindUI:Notify({
					Title = "✈️ Fly Mode",
					Content = UserInputService.TouchEnabled and "Fly enabled! Look up/down + move to fly vertically"
						or "Fly enabled! Use WASD to move, Space/Shift for up/down",
					Duration = 3,
				})
			else
				WindUI:Notify({
					Title = "❌ Error",
					Content = "Failed to enable fly. Make sure your character is loaded.",
					Duration = 2,
				})
				-- Reset toggle if failed
				if FlyState.toggleRef and FlyState.toggleRef.SetValue then
					pcall(function()
						FlyState.toggleRef:SetValue(false)
					end)
				end
			end
		else
			StopFly()
			WindUI:Notify({
				Title = "✈️ Fly Mode",
				Content = "Fly disabled.",
				Duration = 2,
			})
		end
	end,
})

-- Auto-stop fly on character death/respawn
LocalPlayer.CharacterAdded:Connect(function()
	if FlyState.isFlying then
		StopFly()
		if FlyState.toggleRef and FlyState.toggleRef.SetValue then
			pcall(function()
				FlyState.toggleRef:SetValue(false)
			end)
		end
	end
end)

ToolsTab:Slider({
	Title = "Fly Speed",
	Desc = "Adjust flight speed (Default: 50)",
	Step = 5,
	Value = { Min = 10, Max = 300, Default = 50 },
	Callback = function(v)
		FlyState.speed = v
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

-- Consolidated speed display state (Lua 200 local var limit)
local SpeedDisplayState = {
	gui = nil,
	connection = nil,
	isOn = false,
}

local function CreateSpeedDisplayMobile()
	if SpeedDisplayState.gui then
		SpeedDisplayState.gui:Destroy()
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
	titleLbl.Font = Enum.Font.SourceSansBold
	titleLbl.TextSize = 9
	titleLbl.Parent = frame

	local speedLbl = Instance.new("TextLabel")
	speedLbl.Name = "SpeedValue"
	speedLbl.Text = "0"
	speedLbl.Size = UDim2.new(1, 0, 0, 28)
	speedLbl.Position = UDim2.new(0, 0, 0, 22)
	speedLbl.BackgroundTransparency = 1
	speedLbl.TextColor3 = Color3.fromRGB(99, 102, 241)
	speedLbl.Font = Enum.Font.SourceSansBold
	speedLbl.TextSize = 24
	speedLbl.Parent = frame

	local unitLbl = Instance.new("TextLabel")
	unitLbl.Text = "(default: 16)"
	unitLbl.Size = UDim2.new(1, 0, 0, 12)
	unitLbl.Position = UDim2.new(0, 0, 0, 50)
	unitLbl.BackgroundTransparency = 1
	unitLbl.TextColor3 = Color3.fromRGB(120, 120, 130)
	unitLbl.Font = Enum.Font.SourceSans
	unitLbl.TextSize = 9
	unitLbl.Parent = frame

	return screen, frame
end

ToolsTab:Toggle({
	Title = "Speed Display",
	Desc = "Show current walkspeed on screen",
	Value = false,
	Callback = function(state)
		SpeedDisplayState.isOn = state

		if SpeedDisplayState.isOn then
			local screen, frame = CreateSpeedDisplayMobile()
			SpeedDisplayState.gui = screen

			SpeedDisplayState.connection = RunService.Heartbeat:Connect(function()
				local hum = GetHumanoid()
				if hum and SpeedDisplayState.gui then
					local speed = hum.WalkSpeed
					local speedLbl = SpeedDisplayState.gui:FindFirstChild("SpeedFrame")
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
			if SpeedDisplayState.connection then
				SpeedDisplayState.connection:Disconnect()
				SpeedDisplayState.connection = nil
			end
			if SpeedDisplayState.gui then
				SpeedDisplayState.gui:Destroy()
				SpeedDisplayState.gui = nil
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
	isReversing = false,
	currentFile = nil,
	frameData = nil,
	currentPlaybackMetadata = nil,
	currentTime = 0,
	speed = 1.0,
	connection = nil,
	lastFrameIndex = 1,
	lastPlaybackTime = 0,
	lastAirState = nil,
	wasInAirLastFrame = false,
	
	-- Extended State
	isLooping = false,
	isMoonwalk = false,
	isGodMode = false,
	isSpinning = false,
	isRespawnOnEnd = false,
	skipSnapFrames = 0,
	totalDuration = 0,
	isPositionBasedPlayback = true,
	
	-- Tool State
	lastToolEquipTime = 0,
	lastEquippedTool = nil,
	TOOL_THROTTLE_INTERVAL = 0.1,
}

-- Sync PlaybackState with StarSpace module
task.spawn(function()
    while true do
        if StarSpacePlaybackLoaded and _G.StarSpace and _G.StarSpace.GetPlaybackState then
            local state = _G.StarSpace.GetPlaybackState()
            PlaybackState.isPlaying = state.isPlaying
            PlaybackState.isPaused = state.isPaused
            PlaybackState.currentTime = state.currentTime
            PlaybackState.totalDuration = state.totalDuration
        end
        task.wait(0.1)
    end
end)

-- Smoothing Settings
local SMOOTH_SETTINGS = {
	LiveSmoothingEnabled = true,
	LiveSmoothingStrength = 2,
}

-- ═══════════════════════════════════════════════════════════════════
-- HELPERS (From StarSpacePlayback.lua)
-- ═══════════════════════════════════════════════════════════════════

local function GaussianWeight(distance, sigma)
	return math.exp(-(distance * distance) / (2 * sigma * sigma))
end

local function CFToTbl(cf)
	return { cf:GetComponents() }
end

local function TblToCF(t)
	return CFrame.new(unpack(t))
end

local function CatmullRomSpline(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local function CatmullRomVector3(v0, v1, v2, v3, t)
	return Vector3.new(
		CatmullRomSpline(v0.X, v1.X, v2.X, v3.X, t),
		CatmullRomSpline(v0.Y, v1.Y, v2.Y, v3.Y, t),
		CatmullRomSpline(v0.Z, v1.Z, v2.Z, v3.Z, t)
	)
end

-- Helper to convert external JSON formats to internal format
local function NormalizeFrames(frames)
	if not frames or #frames == 0 then return frames end
	local f1 = frames[1]
	if not f1.pos and f1.position then
		for _, f in ipairs(frames) do
			if f.position then f.pos = {x = f.position.x, y = f.position.y, z = f.position.z} end
			if f.velocity then f.vel = {x = f.velocity.x, y = f.velocity.y, z = f.velocity.z} end
			if f.rotation then f.rot = math.deg(f.rotation) end
			if f.moveDirection then f.md = {x = f.moveDirection.x, y = f.moveDirection.y, z = f.moveDirection.z} end
			if f.state then f.st = "Enum.HumanoidStateType." .. f.state end
			if f.hipHeight then f.hh = f.hipHeight end
			if f.time then f.t = f.time end
		end
	end
	return frames
end

local function PreprocessFrames(frames)
	if not frames or #frames == 0 then return frames end
	if frames[1].posVector ~= nil or frames._preprocessed then return frames end
	
	for i = 1, #frames do
		local f = frames[i]
		if f.pos and not f.posVector then f.posVector = Vector3.new(f.pos.x, f.pos.y, f.pos.z) end
		if f.vel and not f.velVector then f.velVector = Vector3.new(f.vel.x, f.vel.y, f.vel.z) end
		if f.md and not f.mdVector then f.mdVector = Vector3.new(f.md.x, f.md.y, f.md.z) end
		if f.charLook and not f.charLookVector then f.charLookVector = Vector3.new(f.charLook.x, f.charLook.y or 0, f.charLook.z) end
		if f.camLook and not f.camLookVector then f.camLookVector = Vector3.new(f.camLook.x, f.camLook.y, f.camLook.z) end
		
		if f.st and not f.stEnum then
			local stateName = string.match(f.st, "Enum%.HumanoidStateType%.(%w+)")
			if stateName then f.stEnum = stateName end
		end
		
		if i % 1000 == 0 then task.wait() end
	end
	frames._preprocessed = true
	return frames
end

local function SmoothInterpolateFrames(frames, frameIdx, alpha)
	local n = #frames
	if n < 2 then return nil, nil, nil end

	local f1, f2 = frames[frameIdx], frames[frameIdx + 1]
	if not f1 or not f2 then return nil, nil, nil end
	
	alpha = math.clamp(alpha, 0, 1)

	local i0 = math.max(1, frameIdx - 1)
	local i3 = math.min(n, frameIdx + 2)
	local f0, f3 = frames[i0], frames[i3]

	local smoothPos, smoothVel, smoothLook

	-- Position Catmull-Rom
	if f0.posVector and f1.posVector and f2.posVector and f3.posVector then
		smoothPos = CatmullRomVector3(f0.posVector, f1.posVector, f2.posVector, f3.posVector, alpha)
	elseif f1.posVector and f2.posVector then
		smoothPos = f1.posVector:Lerp(f2.posVector, alpha)
	end

	-- Velocity Catmull-Rom
	if f0.velVector and f1.velVector and f2.velVector and f3.velVector then
		smoothVel = CatmullRomVector3(f0.velVector, f1.velVector, f2.velVector, f3.velVector, alpha)
	elseif f1.velVector and f2.velVector then
		smoothVel = f1.velVector:Lerp(f2.velVector, alpha)
	end

	-- Look Direction Catmull-Rom
	if f0.charLookVector and f1.charLookVector and f2.charLookVector and f3.charLookVector then
		smoothLook = CatmullRomVector3(f0.charLookVector, f1.charLookVector, f2.charLookVector, f3.charLookVector, alpha)
		if smoothLook.Magnitude > 0.01 then smoothLook = smoothLook.Unit end
	elseif f1.charLookVector and f2.charLookVector then
		smoothLook = f1.charLookVector:Lerp(f2.charLookVector, alpha)
		if smoothLook.Magnitude > 0.01 then smoothLook = smoothLook.Unit end
	end

	return smoothPos, smoothVel, smoothLook
end

local function GetSmoothedFrames(frames, strength, isFlexible)
	local processedFrames = {}
	for i, frame in ipairs(frames) do
		processedFrames[i] = {}
		for k, v in pairs(frame) do processedFrames[i][k] = v end
		if frame.pos then processedFrames[i].pos = {x=frame.pos.x, y=frame.pos.y, z=frame.pos.z} end
		if frame.vel then processedFrames[i].vel = {x=frame.vel.x, y=frame.vel.y, z=frame.vel.z} end
	end
	
	local iterations = math.clamp(strength or 1, 1, 5)
	local kernelRadius = math.clamp(math.ceil(strength / 2), 1, 3)
	local sigma = kernelRadius / 2
	
	local gaussianWeights = {}
	for d = 0, kernelRadius do gaussianWeights[d] = GaussianWeight(d, sigma) end

	for iter = 1, iterations do
		local tempPos = {}
		for i = 2, #processedFrames - 1 do
			local curr = processedFrames[i]
			if curr.pos then
				local weightSum, posSum = 0, Vector3.new(0,0,0)
				for j = math.max(1, i - kernelRadius), math.min(#processedFrames, i + kernelRadius) do
					local neighbor = processedFrames[j]
					if neighbor.pos then
						local dist = math.abs(j - i)
						local weight = gaussianWeights[dist]
						posSum = posSum + Vector3.new(neighbor.pos.x, neighbor.pos.y, neighbor.pos.z) * weight
						weightSum = weightSum + weight
					end
				end
				if weightSum > 0 then
					local smoothed = posSum / weightSum
					local currVec = Vector3.new(curr.pos.x, curr.pos.y, curr.pos.z)
					local final = currVec:Lerp(smoothed, 0.7)
					tempPos[i] = {x=final.X, y=final.Y, z=final.Z}
				end
			end
			if i % 1000 == 0 then task.wait() end
		end
		for i, pos in pairs(tempPos) do processedFrames[i].pos = pos end
	end
	return processedFrames
end

local function FindFrameIndex(frames, time, hint)
	local low, high = 1, #frames
	if hint and hint > 0 and hint < #frames then
		if frames[hint].t <= time and frames[hint+1] and frames[hint+1].t > time then
			return hint
		end
	end
	while low <= high do
		local mid = math.floor((low + high) / 2)
		if frames[mid].t <= time then
			if not frames[mid+1] or frames[mid+1].t > time then
				return mid
			end
			low = mid + 1
		else
			high = mid - 1
		end
	end
	return math.max(1, low - 1)
end

local function FindNearestFrame(frames, rPos)
	local minDst = math.huge
	local bestT = 0
	local bestFrameIdx = 1
	local minGroundDst = math.huge
	local bestGroundT = 0
	local bestGroundIdx = 1
	
	local step = math.max(1, math.floor(#frames / 100))
	for i = 1, #frames, step do
		local f = frames[i]
		local pos = f.posVector or (f.pos and Vector3.new(f.pos.x, f.pos.y, f.pos.z))
		if pos then
			local dst = (rPos - pos).Magnitude
			if dst < minDst then
				minDst = dst
				bestT = f.t
				bestFrameIdx = i
			end
			local stateName = f.stEnum or (f.st and string.match(f.st, "Enum%.HumanoidStateType%.(%w+)"))
			local isGroundFrame = (stateName == nil) or (stateName == "Running") or (stateName == "Landed") or (stateName == "Climbing")
			if isGroundFrame and dst < minGroundDst then
				minGroundDst = dst
				bestGroundT = f.t
				bestGroundIdx = i
			end
		end
	end
	
	local searchRadius = step * 2
	local fineStart = math.max(1, bestFrameIdx - searchRadius)
	local fineEnd = math.min(#frames, bestFrameIdx + searchRadius)
	for i = fineStart, fineEnd do
		local f = frames[i]
		local pos = f.posVector or (f.pos and Vector3.new(f.pos.x, f.pos.y, f.pos.z))
		if pos then
			local dst = (rPos - pos).Magnitude
			if dst < minDst then
				minDst = dst
				bestT = f.t
				bestFrameIdx = i
			end
			local stateName = f.stEnum or (f.st and string.match(f.st, "Enum%.HumanoidStateType%.(%w+)"))
			local isGroundFrame = (stateName == nil) or (stateName == "Running") or (stateName == "Landed") or (stateName == "Climbing")
			if isGroundFrame and dst < minGroundDst then
				minGroundDst = dst
				bestGroundT = f.t
				bestGroundIdx = i
			end
		end
	end
	
	if minGroundDst < minDst + 20 then
		return bestGroundT, minGroundDst, bestGroundIdx
	end
	return bestT, minDst, bestFrameIdx
end

-- Gaussian Weight for smoothing
local function GaussianWeight(distance, sigma)
	return math.exp(-(distance * distance) / (2 * sigma * sigma))
end

-- Catmull-Rom Spline for smooth interpolation
local function CatmullRomSpline(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local function CatmullRomVector3(v0, v1, v2, v3, t)
	return Vector3.new(
		CatmullRomSpline(v0.X, v1.X, v2.X, v3.X, t),
		CatmullRomSpline(v0.Y, v1.Y, v2.Y, v3.Y, t),
		CatmullRomSpline(v0.Z, v1.Z, v2.Z, v3.Z, t)
	)
end

-- Normalize frames from external formats
local function NormalizeFrames(frames)
	if not frames or #frames == 0 then return frames end
	local f1 = frames[1]
	if not f1.pos and f1.position then
		for _, f in ipairs(frames) do
			if f.position then f.pos = {x = f.position.x, y = f.position.y, z = f.position.z} end
			if f.velocity then f.vel = {x = f.velocity.x, y = f.velocity.y, z = f.velocity.z} end
			if f.rotation then f.rot = math.deg(f.rotation) end
			if f.moveDirection then f.md = {x = f.moveDirection.x, y = f.moveDirection.y, z = f.moveDirection.z} end
			if f.state then f.st = "Enum.HumanoidStateType." .. f.state end
			if f.hipHeight then f.hh = f.hipHeight end
			if f.time then f.t = f.time end
		end
	end
	return frames
end

-- Pre-calculate Vector3 values for performance
local function PreprocessFrames(frames)
	if not frames or #frames == 0 then return frames end
	if frames[1].posVector ~= nil or frames._preprocessed then return frames end
	for i = 1, #frames do
		local f = frames[i]
		if f.pos and not f.posVector then f.posVector = Vector3.new(f.pos.x, f.pos.y, f.pos.z) end
		if f.vel and not f.velVector then f.velVector = Vector3.new(f.vel.x, f.vel.y, f.vel.z) end
		if f.md and not f.mdVector then f.mdVector = Vector3.new(f.md.x, f.md.y, f.md.z) end
		if f.charLook and not f.charLookVector then f.charLookVector = Vector3.new(f.charLook.x, f.charLook.y or 0, f.charLook.z) end
		if f.st and not f.stEnum then
			local stateName = string.match(f.st, "Enum%.HumanoidStateType%.(%w+)")
			if stateName then f.stEnum = stateName end
		end
		if i % 10000 == 0 then task.wait() end
	end
	frames._preprocessed = true
	return frames
end

-- Smooth interpolation between frames
local function SmoothInterpolateFrames(frames, frameIdx, alpha)
	local n = #frames
	if n < 2 then return nil, nil, nil end
	local f1, f2 = frames[frameIdx], frames[frameIdx + 1]
	if not f1 or not f2 then return nil, nil, nil end
	alpha = math.clamp(alpha, 0, 1)
	local i0 = math.max(1, frameIdx - 1)
	local i3 = math.min(n, frameIdx + 2)
	local f0, f3 = frames[i0], frames[i3]
	local smoothPos, smoothVel, smoothLook
	if f0.posVector and f1.posVector and f2.posVector and f3.posVector then
		smoothPos = CatmullRomVector3(f0.posVector, f1.posVector, f2.posVector, f3.posVector, alpha)
	elseif f1.posVector and f2.posVector then
		smoothPos = f1.posVector:Lerp(f2.posVector, alpha)
	end
	if f0.velVector and f1.velVector and f2.velVector and f3.velVector then
		smoothVel = CatmullRomVector3(f0.velVector, f1.velVector, f2.velVector, f3.velVector, alpha)
	elseif f1.velVector and f2.velVector then
		smoothVel = f1.velVector:Lerp(f2.velVector, alpha)
	end
	if f0.charLookVector and f1.charLookVector and f2.charLookVector and f3.charLookVector then
		smoothLook = CatmullRomVector3(f0.charLookVector, f1.charLookVector, f2.charLookVector, f3.charLookVector, alpha)
		if smoothLook.Magnitude > 0.01 then smoothLook = smoothLook.Unit end
	elseif f1.charLookVector and f2.charLookVector then
		smoothLook = f1.charLookVector:Lerp(f2.charLookVector, alpha)
		if smoothLook.Magnitude > 0.01 then smoothLook = smoothLook.Unit end
	end
	return smoothPos, smoothVel, smoothLook
end

-- Apply Gaussian smoothing to recording data
local function GetSmoothedFrames(frames, strength)
	local processedFrames = {}
	for i, frame in ipairs(frames) do
		processedFrames[i] = {}
		for k, v in pairs(frame) do processedFrames[i][k] = v end
		if frame.pos then processedFrames[i].pos = {x=frame.pos.x, y=frame.pos.y, z=frame.pos.z} end
		if frame.vel then processedFrames[i].vel = {x=frame.vel.x, y=frame.vel.y, z=frame.vel.z} end
	end
	local iterations = math.clamp(strength or 1, 1, 5)
	local kernelRadius = math.clamp(math.ceil(strength / 2), 1, 3)
	local sigma = kernelRadius / 2
	local gaussianWeights = {}
	for d = 0, kernelRadius do gaussianWeights[d] = GaussianWeight(d, sigma) end
	for iter = 1, iterations do
		for i = 2, #processedFrames - 1 do
			local curr = processedFrames[i]
			if curr.pos then
				local weightSum, posSum = 0, Vector3.new(0,0,0)
				for j = math.max(1, i - kernelRadius), math.min(#processedFrames, i + kernelRadius) do
					local neighbor = processedFrames[j]
					if neighbor.pos then
						local w = gaussianWeights[math.abs(i - j)]
						posSum = posSum + Vector3.new(neighbor.pos.x, neighbor.pos.y, neighbor.pos.z) * w
						weightSum = weightSum + w
					end
				end
				local res = posSum / weightSum
				processedFrames[i].pos = {x=res.X, y=res.Y, z=res.Z}
			end
		end
	end
	return processedFrames
end

-- Tool Handling
local function ToolColorMatches(tool, recordedColor)
	if not recordedColor then return true end
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		local currentColor = handle.BrickColor.Name
		return currentColor == recordedColor
	end
	return true
end

local function ToolConfigMatches(tool, recordedConfig)
	if not recordedConfig then return true end
	local config = tool:FindFirstChild("Configuration") or tool:FindFirstChild("Config")
	if config then
		for key, expectedValue in pairs(recordedConfig) do
			local valObj = config:FindFirstChild(key)
			if valObj and valObj:IsA("ValueBase") then
				if valObj.Value ~= expectedValue then return false end
			end
		end
	end
	return true
end

local function UpdateToolEquip(char, recordedToolName, recordedToolTip, recordedToolColor, recordedToolConfig)
	if not char then return end
	local now = os.clock()
	if now - PlaybackState.lastToolEquipTime < PlaybackState.TOOL_THROTTLE_INTERVAL then return end
	
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	
	local currentTool = char:FindFirstChildOfClass("Tool")
	local currentToolName = currentTool and currentTool.Name or nil
	
	if not recordedToolName then
		if currentTool then
			PlaybackState.lastToolEquipTime = now
			PlaybackState.lastEquippedTool = nil
			hum:UnequipTools()
		end
		return
	end
	
	if currentTool and currentToolName == recordedToolName then
		PlaybackState.lastEquippedTool = currentTool
		return
	end
	
	PlaybackState.lastToolEquipTime = now
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if not backpack then return end
	
	local toolToEquip = nil
	if recordedToolTip or recordedToolColor or recordedToolConfig then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == recordedToolName then
				local tipMatch = (not recordedToolTip) or (tool.ToolTip == recordedToolTip)
				local colorMatch = ToolColorMatches(tool, recordedToolColor)
				local configMatch = ToolConfigMatches(tool, recordedToolConfig)
				if tipMatch and colorMatch and configMatch then
					toolToEquip = tool
					break
				end
			end
		end
	end
	
	if not toolToEquip and recordedToolTip then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == recordedToolName and tool.ToolTip == recordedToolTip then
				toolToEquip = tool
				break
			end
		end
	end
	
	if not toolToEquip then
		toolToEquip = backpack:FindFirstChild(recordedToolName)
	end
	
	if toolToEquip and toolToEquip:IsA("Tool") and toolToEquip ~= currentTool then
		PlaybackState.lastEquippedTool = toolToEquip
		hum:EquipTool(toolToEquip)
	end
end

-- Reset character state
local function ResetCharacter()
	local char = GetCharacter()
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = false
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		if hrp:FindFirstChild("PlaybackAtt") then hrp.PlaybackAtt:Destroy() end
		if hrp:FindFirstChild("PlaybackAO") then hrp.PlaybackAO:Destroy() end
		if hrp:FindFirstChild("PlaybackAP") then hrp.PlaybackAP:Destroy() end
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
		hum.PlatformStand = false
		if not _G.StarshipForceCarryMode then
			for _, track in pairs(hum:GetPlayingAnimationTracks()) do track:Stop() end
		end
		if hrp then hum:MoveTo(hrp.Position) end
	end

	local animate = char:FindFirstChild("Animate")
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
		startText.Font = Enum.Font.SourceSansBold
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
		endText.Font = Enum.Font.SourceSansBold
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
			arrowIcon.Font = Enum.Font.SourceSansBold
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
local function PlayRecording(fileName, force, skipDistanceCheck, forceFromStart)
	if not fileName or fileName == "No files found" then
		WindUI:Notify({ Title = "Error", Content = "No file selected!", Duration = 2 })
		return
	end

	if PlaybackState.isPlaying and PlaybackState.currentFile == fileName and not force then
		return
	end

	local isCloudRecording = string.sub(fileName, 1, 6) == "CLOUD:"
	local data = nil

	if isCloudRecording then
		if not _G.StarshipCloud.RecordingData then
			WindUI:Notify({ Title = "Error", Content = "Cloud recording not loaded!", Duration = 2 })
			return
		end
		data = _G.StarshipCloud.RecordingData
		WindUI:Notify({
			Title = "☁️ Playing",
			Content = string.format("Starting cloud playback (%d frames)", #data.Frames),
			Duration = 1.5,
		})
	else
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

	if PlaybackState.currentFile ~= fileName or force or not PlaybackState.frameData then
		StopPlayback()
		
		local frames = data.Frames or data
		frames = NormalizeFrames(frames)
		
		if SMOOTH_SETTINGS.LiveSmoothingEnabled and #frames > 3 and #frames <= 3000 then
			WindUI:Notify({ Title = "Smoothing", Content = "Applying auto-smooth...", Duration = 1 })
			task.wait()
			frames = GetSmoothedFrames(frames, SMOOTH_SETTINGS.LiveSmoothingStrength)
		end
		
		frames = PreprocessFrames(frames)
		
		PlaybackState.frameData = frames
		PlaybackState.currentPlaybackMetadata = data
		PlaybackState.currentFile = fileName
		PlaybackState.currentTime = 0
		PlaybackState.lastFrameIndex = 1
		PlaybackState.totalDuration = (#frames > 0 and frames[#frames].t) or 0
		
		if isPathVisualsEnabled then DrawPath(frames) end
	elseif PlaybackState.currentTime >= (PlaybackState.totalDuration - 0.1) then
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

	-- SMART RESUME / SMART START (Synced with StarshipCore)
	local needTravelPhase = false
	local useNearestPoint = false
	
	if isResuming then
		-- RESUME: Check if player moved too far from the paused position
		local resumeFrame = nil
		local resumeFrameIdx = 1
		for i = 1, #PlaybackState.frameData do
			if PlaybackState.frameData[i].t >= PlaybackState.currentTime then
				resumeFrame = PlaybackState.frameData[i]
				resumeFrameIdx = i
				break
			end
		end
		
		if resumeFrame then
			-- Check if resume frame is in air (Freefall/Jumping)
			local stateName = resumeFrame.stEnum
			local isAirFrame = (stateName == "Jumping" or stateName == "Freefall")
			
			-- If paused in air, find nearest ground frame instead
			if isAirFrame then
				local searchRange = 120 -- ~2 seconds at 60fps
				local bestGroundIdx = nil
				
				for offset = 1, searchRange do
					local fwdIdx = resumeFrameIdx + offset
					if fwdIdx <= #PlaybackState.frameData then
						local f = PlaybackState.frameData[fwdIdx]
						if f.stEnum == nil or f.stEnum == "Running" or f.stEnum == "Landed" or f.stEnum == "Climbing" then
							bestGroundIdx = fwdIdx
							break
						end
					end
					
					local bwdIdx = resumeFrameIdx - offset
					if bwdIdx >= 1 and not bestGroundIdx then
						local f = PlaybackState.frameData[bwdIdx]
						if f.stEnum == nil or f.stEnum == "Running" or f.stEnum == "Landed" or f.stEnum == "Climbing" then
							bestGroundIdx = bwdIdx
							break
						end
					end
				end
				
				if bestGroundIdx then
					resumeFrame = PlaybackState.frameData[bestGroundIdx]
					PlaybackState.currentTime = resumeFrame.t
					WindUI:Notify({ Title = "Resuming", Content = string.format("Resuming from ground at %.1fs", PlaybackState.currentTime), Duration = 2 })
				end
			end
			
			local resumePos = resumeFrame.posVector
			if resumePos then
				local flatPlayer = hrp.Position * Vector3.new(1, 0, 1)
				local flatResume = resumePos * Vector3.new(1, 0, 1)
				local distFromPath = (flatPlayer - flatResume).Magnitude
				
				if distFromPath <= 10 then
					-- Close enough, just continue
					PlaybackState.skipSnapFrames = 60 -- Add smooth sync even on resume
					isResuming = true
				elseif distFromPath <= 300 then
					-- Medium distance: walk back to paused position
					WindUI:Notify({ Title = "Resuming", Content = string.format("Returning to path (%.0f studs)...", distFromPath), Duration = 2 })
					needTravelPhase = true
					isResuming = false -- Force travel phase
				else
					-- Too far from paused position: find nearest point on path instead
					WindUI:Notify({ Title = "Resuming", Content = "Searching for nearest path point...", Duration = 2 })
					useNearestPoint = true
					isResuming = false
				end
			end
		end
	end

	if not isResuming or useNearestPoint then
		-- FRESH START: Search for nearest point
		local rPos = hrp.Position
		local bestT, minDst, bestFrameIdx = FindNearestFrame(PlaybackState.frameData, rPos)
		
		-- Smart position logic
		if forceFromStart then
			PlaybackState.currentTime = 0
			PlaybackState.lastFrameIndex = 1
			PlaybackState.skipSnapFrames = 0
		elseif bestT >= (PlaybackState.totalDuration - 2.0) then
			PlaybackState.currentTime = 0
			PlaybackState.lastFrameIndex = 1
			if minDst < 10 then
				isResuming = true
				PlaybackState.skipSnapFrames = 60
				WindUI:Notify({ Title = "Smart Start", Content = "Restarting from beginning (near end)", Duration = 2 })
			else
				isResuming = false
				needTravelPhase = true
				WindUI:Notify({ Title = "Smart Start", Content = "Walking to start (near end)", Duration = 2 })
			end
		elseif bestT < 1.0 then
			PlaybackState.currentTime = 0
			PlaybackState.lastFrameIndex = 1
			if minDst < 10 then
				isResuming = true
				PlaybackState.skipSnapFrames = 60
				WindUI:Notify({ Title = "Smart Start", Content = "Starting from beginning", Duration = 2 })
			else
				isResuming = false
				needTravelPhase = true
				WindUI:Notify({ Title = "Smart Start", Content = "Walking to start", Duration = 2 })
			end
		elseif minDst < 300 then
			PlaybackState.currentTime = bestT
			PlaybackState.lastFrameIndex = bestFrameIdx
			if minDst < 10 then 
				isResuming = true
				PlaybackState.skipSnapFrames = 60
				WindUI:Notify({ Title = "Smart Start", Content = string.format("Starting from %.1fs (Smooth Sync)", bestT), Duration = 2 })
			else
				isResuming = false
				needTravelPhase = true
				WindUI:Notify({ Title = "Smart Start", Content = string.format("Walking to path at %.1fs (%.0f studs)", bestT, minDst), Duration = 2 })
			end
		else
			-- Too far from any point
			StopPlayback()
			WindUI:Notify({ Title = "Too Far", Content = "You are too far from any point on the path!", Duration = 3 })
			return
		end
	end

	if PlaybackState.connection then
		PlaybackState.connection:Disconnect()
		PlaybackState.connection = nil
	end

	-- TRAVEL PHASE (Synced with StarshipCore)
	local targetFrame = PlaybackState.frameData[PlaybackState.lastFrameIndex] or PlaybackState.frameData[1]
	local targetPos = targetFrame.posVector or (targetFrame.pos and Vector3.new(targetFrame.pos.x, targetFrame.pos.y, targetFrame.pos.z))

	if targetPos and (not isResuming or needTravelPhase or useNearestPoint) then
		-- Use horizontal distance to prevent getting stuck due to height differences
		local flatPos = hrp.Position * Vector3.new(1, 0, 1)
		local flatTarget = targetPos * Vector3.new(1, 0, 1)
		local dist = (flatPos - flatTarget).Magnitude

		-- SMART START: Walk to nearest path point naturally (not snap/teleport)
		if dist < 300 and dist > 5 then
			-- Player is within range but not on path - walk to it naturally
			hrp.Anchored = false
			if animate then animate.Disabled = false end
			hum.AutoRotate = true

			WindUI:Notify({ Title = "Smart Start", Content = string.format("Walking to path (%.0f studs)...", dist), Duration = 2 })

			-- Use normal walk speed
			local walkSpeed = hum.WalkSpeed
			if walkSpeed < 16 then walkSpeed = 16 end
			
			-- Calculate speed from recorded data + playback multiplier
			local recSpeed = 16
			if targetFrame.velVector then
				recSpeed = Vector3.new(targetFrame.velVector.X, 0, targetFrame.velVector.Z).Magnitude
			elseif targetFrame.vel then
				recSpeed = Vector3.new(targetFrame.vel.x, 0, targetFrame.vel.z).Magnitude
			end
			
			local finalSpeed = math.max(walkSpeed, recSpeed * (tonumber(PlaybackState.speed) or 1.0))
			hum.WalkSpeed = finalSpeed
			hum:MoveTo(targetPos)

			-- Wait until close enough or timeout
			local moveStart = os.clock()
			local maxWalkTime = math.min(dist / 10, 15) -- Max 15 seconds, ~10 studs/sec

			while PlaybackState.isPlaying or (not isResuming and not PlaybackState.isPaused) do
				local currFlat = hrp.Position * Vector3.new(1, 0, 1)
				local d = (currFlat - flatTarget).Magnitude

				-- Close enough
				if d <= 3 then break end

				-- Timeout - just start from current position
				if os.clock() - moveStart > maxWalkTime then
					WindUI:Notify({ Title = "Smart Start", Content = "Starting from current position", Duration = 2 })
					break
				end

				-- Keep walking
				hum:MoveTo(targetPos)
				task.wait(0.1)
			end

			-- Stop walking
			hum:MoveTo(hrp.Position)
			
		elseif dist <= 5 then
			-- Already very close, just start
		elseif dist >= 300 then
			-- Too far - Don't teleport, just stop (User request: 'tidak bergerak')
			StopPlayback()
			WindUI:Notify({ Title = "Too Far", Content = "You are too far from the path! Playback cancelled.", Duration = 3 })
			return
		end
	end
			

	-- PLAYBACK LOOP
	PlaybackState.isPlaying = true
	PlaybackState.isPaused = false
	PlaybackState.lastPlaybackTime = PlaybackState.currentTime
	PlaybackState.lastAirState = nil
	PlaybackState.wasInAirLastFrame = false
	
	local playbackIsR6 = (char:FindFirstChild("Torso") ~= nil)
	local crossRigHeightOffset = 0
	local recordedHipHeight = PlaybackState.currentPlaybackMetadata and PlaybackState.currentPlaybackMetadata.HipHeight or (PlaybackState.frameData[1].hh or 0)
	crossRigHeightOffset = hum.HipHeight - recordedHipHeight

	-- ═══════════════════════════════════════════════════════════════════
	-- PLAYBACK PHASE
	-- ═══════════════════════════════════════════════════════════════════
	PlaybackState.isPlaying = true
	PlaybackState.isPaused = false
	PlaybackState.connection = RunService.Heartbeat:Connect(function(dt)
		if not PlaybackState.isPlaying or PlaybackState.isPaused then return end
		
		if PlaybackState.skipSnapFrames > 0 then
			PlaybackState.skipSnapFrames = PlaybackState.skipSnapFrames - 1
		end
		
		local speed = tonumber(PlaybackState.speed) or 1.0
		if PlaybackState.isReversing then
			PlaybackState.currentTime = PlaybackState.currentTime - (dt * speed)
			if PlaybackState.currentTime <= 0 then
				if PlaybackState.isLooping then 
					PlaybackState.currentTime = PlaybackState.totalDuration 
					PlaybackState.lastFrameIndex = #PlaybackState.frameData 
				else 
					StopPlayback() 
					WindUI:Notify({ Title = "Finished", Content = "Playback completed!", Duration = 2 })
				end
				return
			end
		else
			PlaybackState.currentTime = PlaybackState.currentTime + (dt * speed)
			if PlaybackState.currentTime >= PlaybackState.totalDuration then
				if PlaybackState.isLooping then 
					PlaybackState.currentTime = 0 
					PlaybackState.lastFrameIndex = 1 
				else 
					StopPlayback() 
					WindUI:Notify({ Title = "Finished", Content = "Playback completed!", Duration = 2 })
					if PlaybackState.isRespawnOnEnd then hum.Health = 0 end
				end
				return
			end
		end
		
		local actualDelta = math.abs(PlaybackState.currentTime - PlaybackState.lastPlaybackTime)
		local isTimeJump = actualDelta > (dt * speed * 3 + 0.1)
		PlaybackState.lastPlaybackTime = PlaybackState.currentTime
		
		local frameIdx = FindFrameIndex(PlaybackState.frameData, PlaybackState.currentTime, PlaybackState.lastFrameIndex)
		PlaybackState.lastFrameIndex = frameIdx
		local fA, fB = PlaybackState.frameData[frameIdx], PlaybackState.frameData[frameIdx + 1]

		if fA and fB then
			local deltaT = fB.t - fA.t
			local alpha = deltaT > 0.0001 and (PlaybackState.currentTime - fA.t) / deltaT or 0
			
			local isTeleportFrame = deltaT > 0.3 and (fB.posVector and fA.posVector and (fB.posVector - fA.posVector).Magnitude > 30)
			local smoothPos, smoothVel, smoothLook
			
			if isTeleportFrame then
				local f = alpha > 0.5 and fB or fA
				smoothPos = f.posVector
				smoothVel = f.velVector
				smoothLook = f.charLookVector
			else
				smoothPos, smoothVel, smoothLook = SmoothInterpolateFrames(PlaybackState.frameData, frameIdx, alpha)
			end

			if crossRigHeightOffset ~= 0 and smoothPos then
				smoothPos = Vector3.new(smoothPos.X, smoothPos.Y + crossRigHeightOffset, smoothPos.Z)
			end
			
			-- GROUND SNAP: Prevent floating on slopes (only when not in air)
			local stateName = fA.stEnum
			local isInAirState = (stateName == "Jumping" or stateName == "Freefall")
			
			if smoothPos and not isInAirState and not isTeleportFrame then
				-- Raycast down from smoothPos to find actual ground
				local rayParams = RaycastParams.new()
				rayParams.FilterDescendantsInstances = {char}
				rayParams.FilterType = Enum.RaycastFilterType.Exclude
				
				local rayStart = Vector3.new(smoothPos.X, smoothPos.Y + 5, smoothPos.Z) -- Start 5 studs above
				local rayResult = workspace:Raycast(rayStart, Vector3.new(0, -15, 0), rayParams)
				
				if rayResult then
					-- Calculate expected Y based on HipHeight
					local groundY = rayResult.Position.Y
					local expectedY = groundY + hum.HipHeight + (hrp.Size.Y / 2)
					
					-- Only snap if the difference is significant (prevents jitter)
					local yDiff = math.abs(smoothPos.Y - expectedY)
					if yDiff > 0.3 and yDiff < 5 then
						-- Smooth interpolation to ground
						local snappedY = smoothPos.Y + (expectedY - smoothPos.Y) * 0.6
						smoothPos = Vector3.new(smoothPos.X, snappedY, smoothPos.Z)
					end
				end
			end

			if PlaybackState.isGodMode then hum.Health = hum.MaxHealth end

			local stateName = fA.stEnum
			if stateName then
				local stateEnum = Enum.HumanoidStateType[stateName]
				local currentState = hum:GetState()
				local isAirState = (stateEnum == Enum.HumanoidStateType.Jumping or stateEnum == Enum.HumanoidStateType.Freefall)
				
				if isAirState then
					local isJumpState = (stateEnum == Enum.HumanoidStateType.Jumping)
					local targetState = (isJumpState or (fA.velVector and fA.velVector.Y > 15)) and "jump" or "fall"
					
					if targetState ~= PlaybackState.lastAirState then
						PlaybackState.lastAirState = targetState
						hum:ChangeState(targetState == "jump" and Enum.HumanoidStateType.Jumping or Enum.HumanoidStateType.Freefall)
						if targetState == "jump" and playbackIsR6 then hum.Jump = true end
					end
				elseif stateEnum == Enum.HumanoidStateType.Landed then
					PlaybackState.lastAirState = nil
					if currentState ~= Enum.HumanoidStateType.Landed then hum:ChangeState(Enum.HumanoidStateType.Landed) end
				elseif stateEnum == Enum.HumanoidStateType.Running then
					PlaybackState.lastAirState = nil
					if currentState == Enum.HumanoidStateType.Freefall and math.abs(fA.velVector and fA.velVector.Y or 0) < 3 then
						hum:ChangeState(Enum.HumanoidStateType.Running)
					end
				elseif stateEnum == Enum.HumanoidStateType.Climbing or stateEnum == Enum.HumanoidStateType.Swimming then
					if currentState ~= stateEnum then hum:ChangeState(stateEnum) end
					if stateEnum == Enum.HumanoidStateType.Swimming and fA.hh then hum.HipHeight = fA.hh end
				end
			end
			
			if fA.jmp and not PlaybackState.isReversing then hum.Jump = true end

			local isInAir = (stateName == "Jumping" or stateName == "Freefall")
			local justLanded = PlaybackState.wasInAirLastFrame and not isInAir
			PlaybackState.wasInAirLastFrame = isInAir

			if stateName == "Climbing" or stateName == "Swimming" then
				local vel = smoothVel or Vector3.zero
				vel = vel * speed
				if PlaybackState.isReversing then vel = -vel end
				
				if fA.mdVector then
					hum:Move(PlaybackState.isReversing and -fA.mdVector or fA.mdVector)
				elseif vel.Magnitude > 0.1 then
					local localMoveDir = hrp.CFrame:VectorToObjectSpace(vel.Unit)
					hum:Move(Vector3.new(localMoveDir.X, localMoveDir.Y, localMoveDir.Z) * (vel.Magnitude / 16 * speed * 25))
				else
					hum:Move(Vector3.zero)
				end
				hrp.AssemblyLinearVelocity = vel
				if smoothPos then
					hrp.CFrame = CFrame.new(hrp.Position:Lerp(smoothPos, 0.5)) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
				end
				hum:ChangeState(stateName == "Climbing" and Enum.HumanoidStateType.Climbing or Enum.HumanoidStateType.Swimming)
			elseif isInAir and smoothPos then
				local targetVel = (smoothVel or Vector3.zero) * speed
				local posDiff = smoothPos - hrp.Position
				local finalVel = targetVel + posDiff * 5
				hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(finalVel, 0.5)
				if posDiff.Magnitude > 2 and PlaybackState.skipSnapFrames <= 0 and not isTimeJump then
					hrp.CFrame = CFrame.new(hrp.Position:Lerp(smoothPos, 0.2)) * hrp.CFrame.Rotation
				end
				if PlaybackState.isSpinning then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, dt * 10, 0) end
			elseif justLanded and smoothPos then
				local targetRot = (fA.rot or 0) + (PlaybackState.isMoonwalk and 180 or 0)
				hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(hrp.Position:Lerp(smoothPos, 0.5)) * CFrame.Angles(0, math.rad(targetRot), 0), 0.4)
				local dampedVel = (smoothVel or Vector3.zero) * speed
				local targetVel = Vector3.new(dampedVel.X * 0.5, math.min(dampedVel.Y, 0), dampedVel.Z * 0.5)
				hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(targetVel, 0.6)
				hum:Move(fA.mdVector or Vector3.zero, false)
			else
				-- 5. SMOOTH DRIFT CORRECTION (Synced with StarshipCore)
				local targetVel = (smoothVel or Vector3.zero) * speed
				local dist = (hrp.Position - smoothPos).Magnitude
				local correctionVel = Vector3.zero
				
				-- Handle skipSnapFrames (Smooth Sync)
				if PlaybackState.skipSnapFrames > 0 then
					PlaybackState.skipSnapFrames = PlaybackState.skipSnapFrames - 1
					-- During skip frames, we only use recorded velocity (no correction)
					-- This allows the character to naturally blend into the path
				elseif isTimeJump or dist > 20 then
					-- LARGE DRIFT / TIME JUMP
					if not isTimeJump and dist > 50 then
						-- Too far drift - stop playback instead of teleporting
						StopPlayback()
						WindUI:Notify({ Title = "Drift Error", Content = "Character drifted too far from path! Playback stopped.", Duration = 3 })
						return
					end
					
					-- Smoothly lerp position for smaller drifts or time jumps
					local lerpAlpha = isTimeJump and 1.0 or 0.2
					local smoothSnapPos = hrp.Position:Lerp(smoothPos, lerpAlpha)
					hrp.CFrame = CFrame.new(smoothSnapPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
					PlaybackState.skipSnapFrames = 5
				elseif dist > 3 then
					-- MEDIUM DRIFT: Stronger correction
					correctionVel = (smoothPos - hrp.Position).Unit * (dist * 1.5)
				elseif dist > 0.5 then
					-- SMALL DRIFT: Gentle nudge
					correctionVel = (smoothPos - hrp.Position).Unit * (dist * 0.8)
				end

				-- Apply combined velocity with smoothing
				local finalVel = targetVel + correctionVel
				hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(finalVel, 0.7)

				-- Trigger movement animation
				if fA.mdVector then
					hum:Move(fA.mdVector, false)
				elseif hrp.AssemblyLinearVelocity.Magnitude > 0.5 then
					local flatVel = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
					if flatVel.Magnitude > 0.1 then hum:Move(flatVel.Unit, false) end
				else
					hum:Move(Vector3.zero)
				end
			end
			
			-- Rotation
			local isUserMoving = false
			for _, k in pairs(UserInputService:GetKeysPressed()) do
				if k.KeyCode == Enum.KeyCode.W or k.KeyCode == Enum.KeyCode.A or k.KeyCode == Enum.KeyCode.S or k.KeyCode == Enum.KeyCode.D then
					isUserMoving = true; break
				end
			end
			
			if isUserMoving then
				hum.AutoRotate = true
			elseif stateName == "Climbing" or stateName == "Swimming" or (PlaybackState.isSpinning and isInAir) then
				hum.AutoRotate = false
			else
				hum.AutoRotate = false
				local targetRot = fA.rot or 0
				if fB.rot then
					local diff = (fB.rot - targetRot + 180) % 360 - 180
					targetRot = targetRot + diff * alpha
				end
				if PlaybackState.isMoonwalk and not PlaybackState.isReversing then targetRot = targetRot + 180 end
				
				local isStrafing = false
				if smoothVel and smoothVel.Magnitude > 2 then
					local lookDir = (CFrame.Angles(0, math.rad(targetRot), 0) * Vector3.new(0, 0, -1)).Unit
					if Vector3.new(smoothVel.X, 0, smoothVel.Z).Unit:Dot(lookDir) < 0.8 then isStrafing = true end
				end
				
				hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(targetRot), 0), isStrafing and 0.8 or 0.3)
			end
			
			UpdateTool(char, fA.tool, fA.toolTip, fA.toolColor, fA.toolConfig)
		end
	end)
	
	WindUI:Notify({ Title = "Playback", Content = "Started: " .. fileName, Duration = 2 })
end

-- Pause playback
local function PausePlayback()
	if PlaybackState.isPlaying then
		PlaybackState.isPaused = true
		PlaybackState.isPlaying = false
		ResetCharacter()
		WindUI:Notify({ Title = "Paused", Content = "Playback paused", Duration = 2 })
	end
end

local function TogglePlayback(fileName)
	if PlaybackState.isPlaying then
		PausePlayback()
	else
		PlayRecording(fileName)
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

local CloudRecordingDropdown = nil

local function UpdateCloudDropdown()
	if not CloudRecordingDropdown then return end
	
	local values = _G.StarshipCloud.DropdownValues
	if #values == 0 then values = {"No cloud recordings"} end
	
	pcall(function()
		if CloudRecordingDropdown.SetValues then
			CloudRecordingDropdown:SetValues(values)
		elseif CloudRecordingDropdown.Refresh then
			CloudRecordingDropdown:Refresh(values)
		elseif CloudRecordingDropdown.UpdateValues then
			CloudRecordingDropdown:UpdateValues(values)
		end
	end)
end

-- Fetch cloud recordings list in background to prevent lag
task.spawn(function()
	-- Clear existing data first (prevent duplicates on re-execute)
	for k in pairs(_G.StarshipCloud.DropdownValues) do _G.StarshipCloud.DropdownValues[k] = nil end
	_G.StarshipCloud.RecordingsCache = {}
	
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
				local displayName = "☁️ " .. rec.name
				table.insert(_G.StarshipCloud.DropdownValues, displayName)

				-- Cache full info for lookup
				_G.StarshipCloud.RecordingsCache[displayName] = {
					name = rec.name,
					recordingId = rec.recordingId,
				}
			end

			-- Sort alphabetically (A-Z)
			table.sort(_G.StarshipCloud.DropdownValues, function(a, b)
				return string.lower(a) < string.lower(b)
			end)
		end
	end

	if #_G.StarshipCloud.DropdownValues == 0 then
		table.insert(_G.StarshipCloud.DropdownValues, "No cloud recordings")
	end
	
	-- Update dropdown if it exists
	UpdateCloudDropdown()
end)

ListMapTab:Paragraph({
	Title = "☁️ Cloud Recordings (" .. #_G.StarshipCloud.DropdownValues .. ")",
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

	-- Clear existing data first (prevent duplicates on re-execute)
	for k in pairs(_G.StarshipCloud.DropdownValues) do _G.StarshipCloud.DropdownValues[k] = nil end
		_G.StarshipCloud.RecordingsCache = {}

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
					table.insert(_G.StarshipCloud.DropdownValues, displayName)
					_G.StarshipCloud.RecordingsCache[displayName] = {
						name = rec.name,
						recordingId = rec.recordingId,
					}
				end

				-- Sort alphabetically (A-Z)
				table.sort(_G.StarshipCloud.DropdownValues, function(a, b)
					return string.lower(a) < string.lower(b)
				end)

				-- Update dropdown dynamically
				UpdateCloudDropdown()

				WindUI:Notify({
					Title = "✅ Refreshed",
					Content = #data.recordings .. " recordings found.",
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

-- ══════════════════════════════════════════════════════════════════
-- CHUNKED LOADING - DISABLED (Mobile uses direct loading now)
-- Keeping code for potential future use
-- ══════════════════════════════════════════════════════════════════
local CHUNKED_LOADING_ENABLED = false -- Set to true to re-enable chunked loading

-- Track retry attempts per chunk to prevent infinite loops
local ChunkRetryCount = {}
local MAX_CHUNK_RETRIES = 2 -- Maximum retry attempts per chunk

-- Helper function to load a single chunk (DISABLED)
local function LoadChunk(recordingId, chunkIndex, callback)
	-- DISABLED: Chunked loading not used in mobile anymore
	if not CHUNKED_LOADING_ENABLED then
		if callback then
			callback(false, nil)
		end
		return
	end

	if _G.StarshipCloud.ChunkedState.loadedChunks[chunkIndex] then
		-- Already loaded
		if callback then
			callback(true, _G.StarshipCloud.ChunkedState.loadedChunks[chunkIndex])
		end
		return
	end

	if _G.StarshipCloud.ChunkedState.currentLoadingChunk == chunkIndex then
		-- Already loading this chunk
		return
	end

	_G.StarshipCloud.ChunkedState.currentLoadingChunk = chunkIndex

	task.spawn(function()
		local apiUrl = BuildCloudURL({ recordingId = recordingId, chunk = chunkIndex }, true) -- true = use chunked endpoint

		local success, response = pcall(function()
			return game:HttpGet(apiUrl)
		end)

		_G.StarshipCloud.ChunkedState.currentLoadingChunk = -1

		if not success then
			if DEV_MODE then
				warn("[Chunked] Failed to load chunk " .. chunkIndex)
			end
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
			_G.StarshipCloud.ChunkedState.loadedChunks[chunkIndex] = {
				frames = data.frames,
				startFrame = data.startFrame,
				endFrame = data.endFrame,
			}

			-- Update metadata from first chunk if available
			if chunkIndex == 0 and data.totalFrames then
				_G.StarshipCloud.ChunkedState.totalFrames = data.totalFrames
				_G.StarshipCloud.ChunkedState.framesPerChunk = data.framesPerChunk or 3000
				_G.StarshipCloud.ChunkedState.totalChunks = data.totalChunks or 1
			end

			-- Calculate progress
			local loadedCount = 0
			for _ in pairs(_G.StarshipCloud.ChunkedState.loadedChunks) do
				loadedCount = loadedCount + 1
			end
			_G.StarshipCloud.ChunkedState.loadProgress = math.floor((loadedCount / _G.StarshipCloud.ChunkedState.totalChunks) * 100)

			-- Reset retry count on success
			ChunkRetryCount[chunkIndex] = nil

			if callback then
				callback(true, _G.StarshipCloud.ChunkedState.loadedChunks[chunkIndex])
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

			-- Initialize retry counter if not exists
			ChunkRetryCount[chunkIndex] = (ChunkRetryCount[chunkIndex] or 0) + 1

			-- Only retry if under limit and chunk not already loaded
			if ChunkRetryCount[chunkIndex] <= MAX_CHUNK_RETRIES and not _G.StarshipCloud.ChunkedState.loadedChunks[chunkIndex] then
				if DEV_MODE then
					warn("[Chunked] Retrying chunk " .. chunkIndex .. " (attempt " .. ChunkRetryCount[chunkIndex] .. "/" .. MAX_CHUNK_RETRIES .. ")")
				end
				task.delay(3, function()
					LoadChunk(recordingId, chunkIndex, callback)
				end)
			else
				-- Max retries reached or chunk loaded elsewhere - stop retrying
				if ChunkRetryCount[chunkIndex] > MAX_CHUNK_RETRIES then
					warn("[Chunked] Max retries reached for chunk " .. chunkIndex .. " - giving up")
				end
				ChunkRetryCount[chunkIndex] = nil -- Clean up
				if callback then
					callback(false, nil)
				end
			end
		end
	end)
end

-- Helper function to preload next chunks in background (DISABLED)
PreloadNextChunks = function(recordingId, currentChunkIndex, numToPreload)
	-- DISABLED: Chunked loading not used in mobile anymore
	if not CHUNKED_LOADING_ENABLED then
		return
	end

	if _G.StarshipCloud.ChunkedState.isPreloading then
		return
	end
	_G.StarshipCloud.ChunkedState.isPreloading = true

	task.spawn(function()
		for i = 1, numToPreload do
			local nextChunk = currentChunkIndex + i
			if nextChunk < _G.StarshipCloud.ChunkedState.totalChunks and not _G.StarshipCloud.ChunkedState.loadedChunks[nextChunk] then
				-- Load next chunk
				LoadChunk(recordingId, nextChunk, function(success)
					if success then
						-- Update _G.StarshipCloud.RecordingData with new frames
						if _G.StarshipCloud.RecordingData and _G.StarshipCloud.RecordingData._isChunked then
							local newChunk = _G.StarshipCloud.ChunkedState.loadedChunks[nextChunk]
							if newChunk and newChunk.frames then
								-- Append new frames to existing data
								for _, frame in ipairs(newChunk.frames) do
									table.insert(_G.StarshipCloud.RecordingData.Frames, frame)
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
								for _ in pairs(_G.StarshipCloud.ChunkedState.loadedChunks) do
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
		_G.StarshipCloud.ChunkedState.isPreloading = false
	end)
end

-- Helper function to assemble all loaded chunks into frame data
local function AssembleFrameData()
	local allFrames = {}

	-- Assemble chunks in order
	for chunkIdx = 0, _G.StarshipCloud.ChunkedState.totalChunks - 1 do
		local chunkData = _G.StarshipCloud.ChunkedState.loadedChunks[chunkIdx]
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

	-- ═══════════════════════════════════════════════════════════════
	-- MEMORY CLEANUP: Clear old data before loading new recording
	-- Prevents memory buildup on low-end mobile devices
	-- ═══════════════════════════════════════════════════════════════
	if _G.StarshipCloud.RecordingData then
		_G.StarshipCloud.RecordingData = nil
	end
	if PlaybackState.frameData then
		PlaybackState.frameData = nil
	end
	-- Force garbage collection to free memory
	pcall(function()
		collectgarbage("collect")
	end)
	task.wait() -- Give GC time to run

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
			_G.StarshipCloud.RecordingData = cachedData
			_G.StarshipCloud.RecordingName = cachedData.name or recInfo.name
			CloudRecordingLoaded = true

			-- Update selected file display
			selectedFile = "CLOUD:" .. recInfo.recordingId
			if selectedFileDisplay then
				pcall(function()
					selectedFileDisplay:SetTitle("☁️ " .. _G.StarshipCloud.RecordingName)
					local frameCount = cachedData.Frames and #cachedData.Frames or 0
					selectedFileDisplay:SetDesc(string.format("Ready! • %d frames (cached)", frameCount))
				end)
			end

			local frameCount = cachedData.Frames and #cachedData.Frames or 0
			WindUI:Notify({
				Title = "✅ Ready! (Cached)",
				Content = string.format("%s loaded instantly - Press Play!", _G.StarshipCloud.RecordingName),
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
				_G.StarshipCloud.RecordingData = fileData.data
			else
				_G.StarshipCloud.RecordingData = fileData
			end

			_G.StarshipCloud.RecordingName = data.name or fileData.name or recInfo.name
			CloudRecordingLoaded = true
			_G.StarshipCloud.ChunkedState.isChunked = false

			-- Update selected file display
			selectedFile = "CLOUD:" .. recInfo.recordingId
			if selectedFileDisplay then
				pcall(function()
					selectedFileDisplay:SetTitle("☁️ " .. _G.StarshipCloud.RecordingName)
					selectedFileDisplay:SetDesc("Cloud Recording • Ready to play")
				end)
			end

			WindUI:Notify({
				Title = "☁️ Ready!",
				Content = _G.StarshipCloud.RecordingName .. " loaded - tap Play to start",
				Duration = 3,
			})

			-- Show Playback Controls & Enable Mini Player
			CreatePlaybackControls()
			return
		end

		if data.success and data.recording then
			-- Store in memory
			_G.StarshipCloud.RecordingData = data.recording
			_G.StarshipCloud.RecordingName = data.name or recInfo.name
			CloudRecordingLoaded = true -- Mark as loaded!
			_G.StarshipCloud.ChunkedState.isChunked = false

			-- Update selected file display
			selectedFile = "CLOUD:" .. recInfo.recordingId
			if selectedFileDisplay then
				pcall(function()
					selectedFileDisplay:SetTitle("☁️ " .. _G.StarshipCloud.RecordingName)
					selectedFileDisplay:SetDesc("Cloud Recording • Ready to play")
				end)
			end

			WindUI:Notify({
				Title = "☁️ Ready!",
				Content = _G.StarshipCloud.RecordingName .. " loaded - tap Play to start",
				Duration = 3,
			})

			-- Show Playback Controls & Enable Mini Player
			CreatePlaybackControls()

			-- Save to local cache for instant load next time
			task.spawn(function()
				local cacheData = {
					Frames = data.recording.Frames or data.recording,
					Mode = data.recording.Mode or "Flexible",
					name = _G.StarshipCloud.RecordingName,
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
CloudRecordingDropdown = ListMapTab:Dropdown({
	Title = "Select Cloud Recording",
	Desc = "Sorted A-Z • Use search to find",
	Values = _G.StarshipCloud.DropdownValues,
	SearchBarEnabled = true,
	Callback = function(selected)
		if selected == "No cloud recordings" then
			return
		end

		local recInfo = _G.StarshipCloud.RecordingsCache[selected]
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

		-- ════════════════════════════════����════���══════════════���══════
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

		-- ════════��══════════════���═════════════════════════════���═════
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
		closeBtn.Font = Enum.Font.SourceSansBold
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
			-- Use StarSpacePlayback module if available
			if StarSpacePlaybackLoaded and _G.StarSpace and _G.StarSpace.StopPlayback then
				_G.StarSpace.StopPlayback()
			else
				StopPlayback()
			end
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
			btn.Font = Enum.Font.SourceSansBold
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
		local playDebounce = false -- Prevent double-click
		playBtn.MouseButton1Click:Connect(function()
			-- Debounce to prevent double-click causing fast playback
			if playDebounce then
				return
			end
			playDebounce = true
			task.delay(0.3, function()
				playDebounce = false
			end)

			if not selectedFile then
				WindUI:Notify({ Title = "⚠️", Content = "Select file first!", Duration = 1.5 })
				return
			end

			if PlaybackState.isPlaying and not PlaybackState.isPaused then
				-- Pause
				if StarSpacePlaybackLoaded and _G.StarSpace and _G.StarSpace.PausePlayback then
					_G.StarSpace.PausePlayback()
				else
					PausePlayback()
				end
				playBtn.Text = "▶"
				isPlaying = false
			else
				-- Play - Use StarSpacePlayback module if available
				if StarSpacePlaybackLoaded and _G.StarSpace and _G.StarSpace.LoadRecording then
					-- Use the new playback engine
					if PlaybackState.isPlaying and PlaybackState.isPaused then
						-- Resume if already playing but paused
						if _G.StarSpace.ResumePlayback then
							_G.StarSpace.ResumePlayback()
						else
							_G.StarSpace.TogglePlayback()
						end
					else
						-- Start fresh
						_G.StarSpace.LoadRecording(selectedFile)
					end
				else
					-- Fallback to local PlayRecording
					PlayRecording(selectedFile)
				end
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
			
			-- Sync with StarSpacePlayback module
			if _G.StarSpace and _G.StarSpace.SetMoonwalk then
				_G.StarSpace.SetMoonwalk(isMoonwalk)
			end

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
			
			-- Sync with StarSpacePlayback module
			if _G.StarSpace and _G.StarSpace.SetLooping then
				_G.StarSpace.SetLooping(isLooping)
			end

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
			
			-- Sync with StarSpacePlayback module
			if _G.StarSpace and _G.StarSpace.SetShowPath then
				_G.StarSpace.SetShowPath(state)
			end

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
			
			-- Sync with StarSpacePlayback module
			if _G.StarSpace and _G.StarSpace.SetSpeed then
				_G.StarSpace.SetSpeed(val)
			end
		end,
	})

	PlaybackSection:Toggle({
		Title = "Respawn on End",
		Desc = "Respawn character when recording ends",
		Value = false,
		Callback = function(state)
			PlaybackState.respawnOnEnd = state
			
			-- Sync with StarSpacePlayback module
			if _G.StarSpace and _G.StarSpace.SetRespawnOnEnd then
				_G.StarSpace.SetRespawnOnEnd(state)
			end

			WindUI:Notify({
				Title = "Respawn",
				Content = state and "Will respawn on end" or "Will NOT respawn",
				Duration = 1,
			})
		end,
	})

	PlaybackSection:Divider()

	PlaybackSection:Toggle({
		Title = "Auto Smoothing",
		Desc = "Smooth jittery recordings on load",
		Value = SMOOTH_SETTINGS.LiveSmoothingEnabled,
		Callback = function(state)
			SMOOTH_SETTINGS.LiveSmoothingEnabled = state
		end,
	})

	PlaybackSection:Slider({
		Title = "Smoothing Strength",
		Desc = "Higher = smoother but less accurate",
		Value = { Min = 1, Max = 5, Default = SMOOTH_SETTINGS.LiveSmoothingStrength },
		Step = 1,
		Callback = function(val)
			SMOOTH_SETTINGS.LiveSmoothingStrength = val
		end,
	})

	-- ══════════════════════════════════════════════════════════════════
	-- ⚡ GOD MODE FEATURE (Same as PC version)
	-- ══════════════════════════════════════════════════════════════════
	local isGodMode = false
	local godModeLoop = nil

	PlaybackSection:Toggle({
		Title = "⚡ God Mode",
		Desc = "Infinite health - Cannot die",
		Value = false,
		Callback = function(state)
			isGodMode = state
			
			-- Sync with StarSpacePlayback module
			if _G.StarSpace and _G.StarSpace.SetGodMode then
				_G.StarSpace.SetGodMode(state)
			end
			
			if state then
				-- Start god mode loop
				godModeLoop = RunService.Heartbeat:Connect(function()
					local char = LocalPlayer.Character
					local hum = char and char:FindFirstChild("Humanoid")
					if hum then
						hum.MaxHealth = math.huge
						hum.Health = math.huge
					end
				end)
				
				WindUI:Notify({
					Title = "⚡ God Mode",
					Content = "ENABLED - You are now immortal!",
					Duration = 2,
				})
			else
				-- Stop god mode loop
				if godModeLoop then
					godModeLoop:Disconnect()
					godModeLoop = nil
				end
				
				-- Reset health to normal
				local char = LocalPlayer.Character
				local hum = char and char:FindFirstChild("Humanoid")
				if hum then
					hum.MaxHealth = 100
					hum.Health = 100
				end
				
				WindUI:Notify({
					Title = "⚡ God Mode",
					Content = "DISABLED - Normal health restored",
					Duration = 2,
				})
			end
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

	-- ══════════════════════════════════════════════════════════════════
	-- 🛡️ BYPASS ADMIN FEATURE (Enhanced)
	-- ══════════════════════════════════════════════════════════════════
	local isBypassAdminOn = false
	local bypassAdminConnections = {}
	local AdminAlertGui = nil

	-- Fungsi untuk menampilkan notifikasi admin
	local function ShowAdminNotification(titleText, messageText)
		WindUI:Notify({
			Title = "🛡️ " .. titleText,
			Content = messageText,
			Duration = 5,
		})
	end

	-- Fungsi untuk menampilkan layar peringatan utama (Rejoin/Exit)
	local function ShowAdminAlert(adminName, reason)
		-- Hapus alert yang sudah ada
		if AdminAlertGui then
			pcall(function()
				AdminAlertGui:Destroy()
			end)
		end

		local CoreGui = game:GetService("CoreGui")
		AdminAlertGui = Instance.new("ScreenGui")
		AdminAlertGui.Name = "AdminAlertGui"
		AdminAlertGui.Parent = CoreGui
		AdminAlertGui.ResetOnSpawn = false
		AdminAlertGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

		-- Background Overlay (blur effect)
		local Overlay = Instance.new("Frame")
		Overlay.Name = "Overlay"
		Overlay.Parent = AdminAlertGui
		Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		Overlay.BackgroundTransparency = 0.4
		Overlay.Size = UDim2.new(1, 0, 1, 0)
		Overlay.ZIndex = 10000

		-- Main Card (WindUI style - glassmorphism)
		local MainFrame = Instance.new("Frame")
		MainFrame.Name = "AdminAlertCard"
		MainFrame.Parent = AdminAlertGui
		MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45) -- Darker blue-gray
		MainFrame.BackgroundTransparency = 0.15
		MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		MainFrame.Size = UDim2.new(0, 340, 0, 260)
		MainFrame.ZIndex = 10001

		local UICorner = Instance.new("UICorner", MainFrame)
		UICorner.CornerRadius = UDim.new(0, 12)

		-- Subtle gradient stroke (purple accent like WindUI)
		local UIStroke = Instance.new("UIStroke", MainFrame)
		UIStroke.Color = Color3.fromRGB(139, 92, 246) -- Purple accent
		UIStroke.Thickness = 1.5
		UIStroke.Transparency = 0.3

		-- Header Area with gradient
		local Header = Instance.new("Frame", MainFrame)
		Header.Name = "Header"
		Header.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
		Header.BackgroundTransparency = 0.7
		Header.Size = UDim2.new(1, 0, 0, 60)
		Header.ZIndex = 10002
		Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

		-- Fix corner for header bottom
		local HeaderFix = Instance.new("Frame", Header)
		HeaderFix.BackgroundColor3 = Header.BackgroundColor3
		HeaderFix.BackgroundTransparency = Header.BackgroundTransparency
		HeaderFix.Position = UDim2.new(0, 0, 0.5, 0)
		HeaderFix.Size = UDim2.new(1, 0, 0.5, 0)
		HeaderFix.ZIndex = 10002
		HeaderFix.BorderSizePixel = 0

		-- Warning Icon
		local Icon = Instance.new("TextLabel", Header)
		Icon.BackgroundTransparency = 1
		Icon.Position = UDim2.new(0, 15, 0, 0)
		Icon.Size = UDim2.new(0, 40, 1, 0)
		Icon.Font = Enum.Font.SourceSansBold
		Icon.Text = "⚠️"
		Icon.TextSize = 28
		Icon.TextColor3 = Color3.fromRGB(251, 191, 36) -- Amber
		Icon.ZIndex = 10003

		-- Title
		local Title = Instance.new("TextLabel", Header)
		Title.BackgroundTransparency = 1
		Title.Position = UDim2.new(0, 55, 0, 0)
		Title.Size = UDim2.new(1, -70, 1, 0)
		Title.Font = Enum.Font.SourceSansBold
		Title.Text = "Admin Detected!"
		Title.TextColor3 = Color3.fromRGB(255, 255, 255)
		Title.TextSize = 18
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.ZIndex = 10003

		-- Content Area
		local Content = Instance.new("Frame", MainFrame)
		Content.Name = "Content"
		Content.BackgroundTransparency = 1
		Content.Position = UDim2.new(0, 0, 0, 70)
		Content.Size = UDim2.new(1, 0, 0, 80)
		Content.ZIndex = 10002

		-- Admin Name
		local AdminLabel = Instance.new("TextLabel", Content)
		AdminLabel.BackgroundTransparency = 1
		AdminLabel.Position = UDim2.new(0, 20, 0, 5)
		AdminLabel.Size = UDim2.new(1, -40, 0, 25)
		AdminLabel.Font = Enum.Font.SourceSansSemibold
		AdminLabel.Text = "👤 " .. adminName
		AdminLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		AdminLabel.TextSize = 15
		AdminLabel.TextXAlignment = Enum.TextXAlignment.Left
		AdminLabel.ZIndex = 10003

		-- Reason
		local ReasonLabel = Instance.new("TextLabel", Content)
		ReasonLabel.BackgroundTransparency = 1
		ReasonLabel.Position = UDim2.new(0, 20, 0, 32)
		ReasonLabel.Size = UDim2.new(1, -40, 0, 40)
		ReasonLabel.Font = Enum.Font.SourceSans
		ReasonLabel.Text = "📋 " .. reason
		ReasonLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
		ReasonLabel.TextSize = 13
		ReasonLabel.TextXAlignment = Enum.TextXAlignment.Left
		ReasonLabel.TextWrapped = true
		ReasonLabel.TextYAlignment = Enum.TextYAlignment.Top
		ReasonLabel.ZIndex = 10003

		-- Buttons Container
		local ButtonsFrame = Instance.new("Frame", MainFrame)
		ButtonsFrame.Name = "Buttons"
		ButtonsFrame.BackgroundTransparency = 1
		ButtonsFrame.Position = UDim2.new(0, 20, 0, 160)
		ButtonsFrame.Size = UDim2.new(1, -40, 0, 50)
		ButtonsFrame.ZIndex = 10002

		-- Rejoin Button (Green/Teal style)
		local RejoinBtn = Instance.new("TextButton", ButtonsFrame)
		RejoinBtn.Name = "RejoinBtn"
		RejoinBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129) -- Emerald
		RejoinBtn.BackgroundTransparency = 0.1
		RejoinBtn.Position = UDim2.new(0, 0, 0, 0)
		RejoinBtn.Size = UDim2.new(0.48, 0, 1, 0)
		RejoinBtn.Font = Enum.Font.SourceSansBold
		RejoinBtn.Text = "🔄 Rejoin"
		RejoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		RejoinBtn.TextSize = 14
		RejoinBtn.ZIndex = 10003
		RejoinBtn.AutoButtonColor = false
		Instance.new("UICorner", RejoinBtn).CornerRadius = UDim.new(0, 8)
		local RejoinStroke = Instance.new("UIStroke", RejoinBtn)
		RejoinStroke.Color = Color3.fromRGB(16, 185, 129)
		RejoinStroke.Transparency = 0.5

		-- Exit Button (Red style)
		local ExitBtn = Instance.new("TextButton", ButtonsFrame)
		ExitBtn.Name = "ExitBtn"
		ExitBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68) -- Red
		ExitBtn.BackgroundTransparency = 0.1
		ExitBtn.Position = UDim2.new(0.52, 0, 0, 0)
		ExitBtn.Size = UDim2.new(0.48, 0, 1, 0)
		ExitBtn.Font = Enum.Font.SourceSansBold
		ExitBtn.Text = "🚪 Leave"
		ExitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		ExitBtn.TextSize = 14
		ExitBtn.ZIndex = 10003
		ExitBtn.AutoButtonColor = false
		Instance.new("UICorner", ExitBtn).CornerRadius = UDim.new(0, 8)
		local ExitStroke = Instance.new("UIStroke", ExitBtn)
		ExitStroke.Color = Color3.fromRGB(239, 68, 68)
		ExitStroke.Transparency = 0.5

		-- Footer/Watermark
		local Footer = Instance.new("TextLabel", MainFrame)
		Footer.BackgroundTransparency = 1
		Footer.Position = UDim2.new(0, 0, 1, -30)
		Footer.Size = UDim2.new(1, 0, 0, 25)
		Footer.Font = Enum.Font.SourceSans
		Footer.Text = "⚡ Starship Protection"
		Footer.TextColor3 = Color3.fromRGB(100, 100, 120)
		Footer.TextSize = 11
		Footer.ZIndex = 10003

		-- Hover Effects (WindUI style - subtle scale + color)
		RejoinBtn.MouseEnter:Connect(function()
			TweenService:Create(RejoinBtn, TweenInfo.new(0.15), {
				BackgroundTransparency = 0,
				Size = UDim2.new(0.49, 0, 1.05, 0),
			}):Play()
		end)
		RejoinBtn.MouseLeave:Connect(function()
			TweenService:Create(RejoinBtn, TweenInfo.new(0.15), {
				BackgroundTransparency = 0.1,
				Size = UDim2.new(0.48, 0, 1, 0),
			}):Play()
		end)
		ExitBtn.MouseEnter:Connect(function()
			TweenService:Create(ExitBtn, TweenInfo.new(0.15), {
				BackgroundTransparency = 0,
				Size = UDim2.new(0.49, 0, 1.05, 0),
			}):Play()
		end)
		ExitBtn.MouseLeave:Connect(function()
			TweenService:Create(ExitBtn, TweenInfo.new(0.15), {
				BackgroundTransparency = 0.1,
				Size = UDim2.new(0.48, 0, 1, 0),
			}):Play()
		end)

		-- Button Click Logic
		RejoinBtn.MouseButton1Click:Connect(function()
			RejoinBtn.Text = "⏳ Rejoining..."
			RejoinBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			ExitBtn.Visible = false
			task.wait(0.5)
			local TeleportService = game:GetService("TeleportService")
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		end)

		ExitBtn.MouseButton1Click:Connect(function()
			ExitBtn.Text = "👋 Leaving..."
			ExitBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
			RejoinBtn.Visible = false
			task.wait(0.3)
			LocalPlayer:Kick("You chose to leave.\n\n- Stay safe! -")
		end)

		-- Entrance Animation (slide up + fade in)
		Overlay.BackgroundTransparency = 1
		MainFrame.Position = UDim2.new(0.5, 0, 0.6, 0)
		MainFrame.BackgroundTransparency = 1

		TweenService:Create(Overlay, TweenInfo.new(0.3), {
			BackgroundTransparency = 0.4,
		}):Play()

		TweenService:Create(MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundTransparency = 0.15,
		}):Play()
	end

	-- Fungsi utama pengecekan admin
	local function CheckForAdmin(player)
		if player == LocalPlayer or not player.Parent then
			return
		end

		local isAdmin = false
		local reason = ""

		-- 1. Cek Game Creator
		if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
			isAdmin = true
			reason = "Game Owner"
		end

		-- 2. Cek Group Rank (untuk game grup)
		if not isAdmin and game.CreatorType == Enum.CreatorType.Group then
			local s, rank = pcall(function()
				return player:GetRankInGroup(game.CreatorId)
			end)
			if s and rank and rank >= 100 then
				isAdmin = true
				reason = "Group Rank: " .. tostring(rank)
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
					reason = "Group Role: " .. role
				end
			end
		end

		-- 3. Cek via HTTP API (untuk semua grup player)
		if not isAdmin then
			task.spawn(function()
				local success, roles = pcall(function()
					local HttpService = game:GetService("HttpService")
					local response =
						game:HttpGet("https://groups.roblox.com/v1/users/" .. player.UserId .. "/groups/roles")
					return HttpService:JSONDecode(response)
				end)

				if success and roles and roles.data then
					for _, group in ipairs(roles.data) do
						if group.role.rank >= 200 then -- Rank 200+ biasanya owner/admin
							ShowAdminAlert(
								player.Name,
								"High Rank in Group: " .. group.group.name .. " (Rank " .. group.role.rank .. ")"
							)
							return
						end
					end
				end
			end)
		end

		-- 4. Cek Admin Tools di Backpack
		if not isAdmin then
			task.spawn(function()
				task.wait(1) -- Tunggu character load
				local backpack = player:FindFirstChild("Backpack")
				if backpack then
					for _, tool in ipairs(backpack:GetChildren()) do
						if tool:IsA("Tool") then
							local toolName = tool.Name:lower()
							if
								toolName:find("admin")
								or toolName:find("ban")
								or toolName:find("kick")
								or toolName:find("mod")
							then
								ShowAdminAlert(player.Name, "Admin Tool: " .. tool.Name)
								return
							end
						end
					end
				end
			end)
		end

		-- 5. Monitor Chat untuk Command Admin
		local chatConnection = player.Chatted:Connect(function(msg)
			if not isBypassAdminOn then
				return
			end
			local lowMsg = msg:lower()
			if
				lowMsg:find(";jail")
				or lowMsg:find(";kick")
				or lowMsg:find(";ban")
				or lowMsg:find(":kick")
				or lowMsg:find(":ban")
				or lowMsg:find("/e :")
			then
				ShowAdminNotification("ADMIN COMMAND", player.Name .. " used: " .. msg:sub(1, 30))
				ShowAdminAlert(player.Name, "Admin Command: " .. msg:sub(1, 50))
			end
		end)
		table.insert(bypassAdminConnections, chatConnection)

		-- Jika sudah terdeteksi admin dari awal
		if isAdmin then
			ShowAdminAlert(player.Name, reason)
		end
	end

	PlaybackSection:Toggle({
		Title = "🛡️ Bypass Admin",
		Desc = "Deteksi admin via rank, role, tools & chat commands",
		Value = false,
		Callback = function(state)
			isBypassAdminOn = state
			if isBypassAdminOn then
				-- Cek semua player yang sudah ada
				for _, p in ipairs(Players:GetPlayers()) do
					CheckForAdmin(p)
				end
				-- Cek player baru yang masuk
				local newPlayerConn = Players.PlayerAdded:Connect(function(p)
					if isBypassAdminOn then
						CheckForAdmin(p)
					end
				end)
				table.insert(bypassAdminConnections, newPlayerConn)
				WindUI:Notify({ Title = "🛡️ Bypass Admin", Content = "Admin detection ACTIVE!", Duration = 3 })
			else
				-- Disconnect semua connection
				for _, conn in ipairs(bypassAdminConnections) do
					if conn then
						pcall(function()
							conn:Disconnect()
						end)
					end
				end
				bypassAdminConnections = {}
				-- Hapus alert jika ada
				if AdminAlertGui then
					pcall(function()
						AdminAlertGui:Destroy()
					end)
					AdminAlertGui = nil
				end
				WindUI:Notify({ Title = "🛡️ Bypass Admin", Content = "Admin detection disabled.", Duration = 2 })
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

-- Touch Fling State
local TouchFlingState = {
	isEnabled = false,
	movel = 0.1,
	hitboxExpanded = false,
	hitboxParts = {},
}

-- Create detection marker in ReplicatedStorage (for anti-detection compatibility)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("juisdfj0i32i0eidsuf0iok") then
	local detection = Instance.new("Decal")
	detection.Name = "juisdfj0i32i0eidsuf0iok"
	detection.Parent = ReplicatedStorage
end

-- Function to create/destroy hitbox expanders
local function UpdateHitboxExpander(expand)
	local char = GetCharacter()
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	-- Clean existing hitbox parts
	for _, part in pairs(TouchFlingState.hitboxParts) do
		if part and part.Parent then
			part:Destroy()
		end
	end
	TouchFlingState.hitboxParts = {}

	if expand then
		-- Create 6 invisible collidable parts around character (box formation)
		local offsets = {
			CFrame.new(0, 0, -4), -- Front
			CFrame.new(0, 0, 4), -- Back
			CFrame.new(-4, 0, 0), -- Left
			CFrame.new(4, 0, 0), -- Right
			CFrame.new(0, 3, 0), -- Top
			CFrame.new(0, -2, 0), -- Bottom
		}

		for i, offset in ipairs(offsets) do
			local part = Instance.new("Part")
			part.Name = "FlingHitbox_" .. i
			part.Size = Vector3.new(5, 5, 0.5)
			part.Transparency = 1
			part.CanCollide = true
			part.Massless = true
			part.Anchored = false
			part.Parent = char

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hrp
			weld.Part1 = part
			weld.Parent = part

			part.CFrame = hrp.CFrame * offset

			table.insert(TouchFlingState.hitboxParts, part)
		end
	end
end

-- Touch Fling Loop (runs in background)
task.spawn(function()
	local hrp, c, vel = nil, nil, nil
	local lp = LocalPlayer

	while true do
		RunService.Heartbeat:Wait()
		if TouchFlingState.isEnabled then
			-- Wait for valid character and HumanoidRootPart
			while TouchFlingState.isEnabled and not (c and c.Parent and hrp and hrp.Parent) do
				RunService.Heartbeat:Wait()
				c = lp.Character
				hrp = c and c:FindFirstChild("HumanoidRootPart")
			end

			if TouchFlingState.isEnabled then
				vel = hrp.Velocity
				hrp.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)

				-- Also apply velocity to hitbox parts for better fling
				if TouchFlingState.hitboxExpanded then
					for _, part in pairs(TouchFlingState.hitboxParts) do
						if part and part.Parent then
							pcall(function()
								part.Velocity = hrp.Velocity
							end)
						end
					end
				end

				RunService.RenderStepped:Wait()
				if c and c.Parent and hrp and hrp.Parent then
					hrp.Velocity = vel
				end
				RunService.Stepped:Wait()
				if c and c.Parent and hrp and hrp.Parent then
					hrp.Velocity = vel + Vector3.new(0, TouchFlingState.movel, 0)
					TouchFlingState.movel = TouchFlingState.movel * -1
				end
			end
		end
	end
end)

-- Hitbox Expander Toggle (for games where bodies pass through)
FunTab:Toggle({
	Title = "🔲 Expand Hitbox",
	Desc = "Enable if bodies pass through (no collision)",
	Value = false,
	Callback = function(state)
		TouchFlingState.hitboxExpanded = state
		UpdateHitboxExpander(state)

		if state then
			WindUI:Notify({
				Title = "Hitbox",
				Content = "Hitbox expanded! Better collision for fling.",
				Duration = 2,
			})
		else
			WindUI:Notify({ Title = "Hitbox", Content = "Hitbox reset to normal.", Duration = 2 })
		end
	end,
})

FunTab:Toggle({
	Title = "💥 Touch Fling",
	Desc = "Fling players on touch (new method)",
	Value = false,
	Callback = function(state)
		TouchFlingState.isEnabled = state

		if state then
			local tip = TouchFlingState.hitboxExpanded and "Walk into players to fling them!"
				or "Walk into players. Enable Hitbox if not working."
			WindUI:Notify({
				Title = "Touch Fling",
				Content = "Fling enabled! " .. tip,
				Duration = 3,
			})
		else
			-- Reset velocity when disabled
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

-- ═══════════════════════���════════��═════════════════════════════════
-- 👻 INVISIBLE
-- ══════════════════════════════════════════════════════════════════
FunTab:Section({ Title = "👻 Invisible", TextSize = 20 })

local isInvisibleOn = false
local INVIS_POSITION = Vector3.new(9999, 9999, 9999)

local function setCharacterTransparency(char, alpha)
	for _, part in pairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.LocalTransparencyModifier = alpha
		elseif part:IsA("Decal") or part:IsA("Texture") then
			part.Transparency = alpha
		end
	end
end

FunTab:Toggle({
	Title = "Invisible",
	Desc = "Makes you invisible to other players",
	Value = false,
	Callback = function(state)
		local char = GetCharacter()
		if not char then return end

		local humanoid = char:FindFirstChild("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not humanoid or not hrp then return end

		isInvisibleOn = state

		if isInvisibleOn then
			-- Save current position
			local savedPosition = hrp.CFrame

			-- Move to invisible position using MoveTo (replicates to server)
			char:MoveTo(INVIS_POSITION)
			task.wait(0.15)

			-- Create seat at current character position (which is now at INVIS_POSITION)
			local seat = Instance.new("Seat")
			seat.Name = "invischair"
			seat.Anchored = false
			seat.CanCollide = false
			seat.Transparency = 1
			seat.Position = INVIS_POSITION
			seat.Parent = workspace

			-- Weld to torso
			local weld = Instance.new("Weld")
			weld.Part0 = seat
			weld.Part1 = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
			weld.Parent = seat

			task.wait()

			-- Move seat (and welded character) back to saved position
			seat.CFrame = savedPosition

			-- Visual feedback - make semi-transparent
			setCharacterTransparency(char, 0.5)

			WindUI:Notify({ Title = "Invisible", Content = "You are now invisible to others!", Duration = 3 })
		else
			-- Destroy the invisible chair
			local invisChair = workspace:FindFirstChild("invischair")
			if invisChair then
				invisChair:Destroy()
			end

			-- Restore transparency
			local char = GetCharacter()
			if char then
				setCharacterTransparency(char, 0)
			end

			WindUI:Notify({ Title = "Invisible", Content = "Invisible disabled.", Duration = 2 })
		end
	end,
})

FunTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 👁️ SPECTATE PLAYER
-- ═════════════════════════════════════════════════════════════���════
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

-- 🚶 AUTO FOLLOW (with Animation Support)
-- ══════════════════════════════════════════════════════════════════
FunTab:Section({ Title = "🚶 Auto Follow", TextSize = 20 })

-- Consolidated into single table to reduce local variable count
local FunFollow = {
	target = nil,
	isFollowing = false,
	followLoop = nil,
	animLoop = nil,
	exactMode = true,
	animEnabled = true,
	getHRP = function(_, char)
		return char and char:FindFirstChild("HumanoidRootPart")
	end,
	getHum = function(_, char)
		return char and char:FindFirstChild("Humanoid")
	end,
}

FunTab:Dropdown({
	Title = "Select Target",
	Desc = "Choose player to follow",
	Values = GetPlayerList(),
	Callback = function(selected)
		FunFollow.target = Players:FindFirstChild(selected)
		WindUI:Notify({ Title = "Follow", Content = "Target: " .. selected, Duration = 2 })
	end,
})

FunTab:Toggle({
	Title = "📍 Exact Position Mode",
	Desc = "ON: Same position as target | OFF: Stay behind",
	Value = true,
	Callback = function(state)
		FunFollow.exactMode = state
	end,
})

FunTab:Toggle({
	Title = "🎭 Animation Mirroring",
	Desc = "Mirror target's walking animations",
	Value = true,
	Callback = function(state)
		FunFollow.animEnabled = state
	end,
})
FunTab:Toggle({
	Title = "🚶 Enable Auto Follow",
	Desc = "Follow selected player",
	Value = false,
	Callback = function(state)
		FunFollow.isFollowing = state

		if FunFollow.isFollowing then
			if not FunFollow.target then
				WindUI:Notify({ Title = "Error", Content = "Please select a target first!", Duration = 2 })
				return
			end

			if not FunFollow.target.Parent then
				WindUI:Notify({ Title = "Error", Content = "Player left the game!", Duration = 2 })
				FunFollow.target = nil
				return
			end

			-- Main follow loop (RenderStepped for smooth position)
			FunFollow.followLoop = RunService.RenderStepped:Connect(function()
				if not FunFollow.isFollowing or not FunFollow.target then
					FunFollow.isFollowing = false
					if FunFollow.followLoop then
						FunFollow.followLoop:Disconnect()
						FunFollow.followLoop = nil
					end
					if FunFollow.animLoop then
						FunFollow.animLoop:Disconnect()
						FunFollow.animLoop = nil
					end
					return
				end

				if not FunFollow.target.Parent then
					FunFollow.isFollowing = false
					if FunFollow.followLoop then
						FunFollow.followLoop:Disconnect()
						FunFollow.followLoop = nil
					end
					if FunFollow.animLoop then
						FunFollow.animLoop:Disconnect()
						FunFollow.animLoop = nil
					end
					WindUI:Notify({ Title = "Follow", Content = "Target left!", Duration = 2 })
					return
				end

				local myChar = GetCharacter()
				local myHRP = FunFollow:getHRP(myChar)
				local myHum = FunFollow:getHum(myChar)

				local tChar = FunFollow.target.Character
				local tHRP = FunFollow:getHRP(tChar)
				local tHum = FunFollow:getHum(tChar)

				if not (myHRP and myHum and tHRP and tHum and tHum.Health > 0) then
					return
				end

				pcall(function()
					if FunFollow.exactMode then
						myHRP.CFrame = tHRP.CFrame
						myHum.PlatformStand = false
						myHRP.Velocity = tHRP.Velocity
					else
						local look = tHRP.CFrame.LookVector
						local behindPos = tHRP.Position - (look * 4)
						local frontPoint = behindPos + look
						myHRP.CFrame = myHRP.CFrame:Lerp(CFrame.new(behindPos, frontPoint), 0.5)
						myHum.PlatformStand = false
					end
				end)
			end)

			-- Animation loop (Heartbeat - same as PC)
			FunFollow.animLoop = RunService.Heartbeat:Connect(function()
				if not FunFollow.isFollowing or not FunFollow.target or not FunFollow.animEnabled then
					return
				end

				local myChar = GetCharacter()
				local tChar = FunFollow.target.Character
				if not (myChar and tChar) then
					return
				end

				local myHum = FunFollow:getHum(myChar)
				local tHum = FunFollow:getHum(tChar)
				local tHRP = FunFollow:getHRP(tChar)

				if myHum and tHum and tHRP then
					pcall(function()
						local targetMoveDir = tHum.MoveDirection
						local isMoving = targetMoveDir.Magnitude > 0.1

						if isMoving then
							myHum:Move(targetMoveDir, false)
						else
							myHum:Move(Vector3.new(0, 0, 0), false)
						end

						-- Copy humanoid states
						local tState = tHum:GetState()
						if tState == Enum.HumanoidStateType.Jumping then
							myHum.Jump = true
						elseif tState == Enum.HumanoidStateType.Freefall then
							myHum:ChangeState(Enum.HumanoidStateType.Freefall)
						elseif tState == Enum.HumanoidStateType.Seated then
							myHum.Sit = true
						end
					end)
				end
			end)

			WindUI:Notify({ Title = "Follow", Content = "Following " .. FunFollow.target.Name, Duration = 3 })
		else
			if FunFollow.followLoop then
				FunFollow.followLoop:Disconnect()
				FunFollow.followLoop = nil
			end
			if FunFollow.animLoop then
				FunFollow.animLoop:Disconnect()
				FunFollow.animLoop = nil
			end
			WindUI:Notify({ Title = "Follow", Content = "Follow stopped.", Duration = 2 })
		end
	end,
})

FunTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🚀 WARP TAB (Advanced Teleportation - PC-like features)
-- ══════════════════════════════════════════════════════════════════
local WarpTab = Window:Tab({
	Title = "Warp",
	Icon = "map-pin",
})

-- All warp state consolidated into single table to reduce local variables
WarpSystem = {
	FOLDER = "StarshipMobile/Warps",
	points = {},
	isLooping = false,
	loopDelay = 1,
	currentConfig = nil,
	savedConfigs = {},
	selectedPointIndex = 1,
	selectedConfigToLoad = nil,
	configNameInput = "",
	warpTargetPlayer = nil,
	warpCoordX = 0,
	warpCoordY = 0,
	warpCoordZ = 0,
	pointsInfoParagraph = nil,
	loopStatusParagraph = nil,
}

-- Initialize folder
pcall(function()
	if isfolder and not isfolder("StarshipMobile") then makefolder("StarshipMobile") end
	if isfolder and not isfolder(WarpSystem.FOLDER) then makefolder(WarpSystem.FOLDER) end
end)

-- CFrame conversion functions inside WarpSystem
WarpSystem.CFToTable = function(cf) return {cf:GetComponents()} end
WarpSystem.TableToCF = function(t)
	if t and #t >= 12 then return CFrame.new(unpack(t)) end
	return CFrame.new(0, 0, 0)
end

WarpSystem.FormatTime = function(s)
	s = math.floor(s + 0.5)
	if s < 60 then return s .. "s"
	elseif s < 3600 then return string.format("%dm %ds", math.floor(s / 60), s % 60)
	else return string.format("%dh %dm", math.floor(s / 3600), math.floor((s % 3600) / 60)) end
end

WarpSystem.GetTotalTime = function()
	return math.max(1, #WarpSystem.points - 1) * WarpSystem.loopDelay
end

WarpSystem.RefreshConfigList = function()
	WarpSystem.savedConfigs = {}
	
	-- Ensure folder exists first
	pcall(function()
		if isfolder and makefolder then
			if not isfolder("StarshipMobile") then makefolder("StarshipMobile") end
			if not isfolder(WarpSystem.FOLDER) then makefolder(WarpSystem.FOLDER) end
		end
	end)
	
	-- List files in folder
	local success, err = pcall(function()
		if listfiles then
			local files = listfiles(WarpSystem.FOLDER)
			if files and type(files) == "table" then
				for _, f in ipairs(files) do
					-- Extract filename without path and extension
					local fileName = f
					if string.find(f, "/") or string.find(f, "\\") then
						fileName = string.match(f, "[^/\\]+$") or f
					end
					fileName = fileName:gsub("%.json$", "")
					if fileName and fileName ~= "" then
						table.insert(WarpSystem.savedConfigs, fileName)
					end
				end
			end
		end
	end)
	
	-- Sort configs
	if #WarpSystem.savedConfigs > 0 then
		table.sort(WarpSystem.savedConfigs, function(a, b)
			local numA = tonumber(string.match(a, "%d+")) or 0
			local numB = tonumber(string.match(b, "%d+")) or 0
			if numA ~= 0 and numB ~= 0 then return numA < numB end
			return a < b
		end)
	end
end


WarpSystem.SaveConfig = function(name)
	if not writefile or #WarpSystem.points == 0 then return false end
	local data = { Delay = WarpSystem.loopDelay, Points = {} }
	for _, wp in ipairs(WarpSystem.points) do
		table.insert(data.Points, { Name = wp.Name, CF = wp.CF })
	end
	pcall(function()
		writefile(WarpSystem.FOLDER .. "/" .. name .. ".json", game:GetService("HttpService"):JSONEncode(data))
	end)
	WarpSystem.currentConfig = name
	WarpSystem.RefreshConfigList()
	return true
end

WarpSystem.LoadConfig = function(name)
	if not readfile then return false end
	local success = pcall(function()
		local data = game:GetService("HttpService"):JSONDecode(readfile(WarpSystem.FOLDER .. "/" .. name .. ".json"))
		WarpSystem.points = {}
		WarpSystem.loopDelay = data.Delay or 1
		for _, p in ipairs(data.Points or {}) do
			table.insert(WarpSystem.points, { Name = p.Name, CF = p.CF })
		end
		WarpSystem.currentConfig = name
	end)
	return success
end

WarpSystem.DeleteConfig = function(name)
	pcall(function() if delfile then delfile(WarpSystem.FOLDER .. "/" .. name .. ".json") end end)
	if WarpSystem.currentConfig == name then WarpSystem.currentConfig = nil end
	WarpSystem.RefreshConfigList()
end

WarpSystem.UpdatePointsInfo = function()
	pcall(function()
		if WarpSystem.pointsInfoParagraph then
			WarpSystem.pointsInfoParagraph:SetDesc(string.format("Points: %d | Delay: %.1fs | Est. Time: %s | Config: %s",
				#WarpSystem.points, WarpSystem.loopDelay, WarpSystem.FormatTime(WarpSystem.GetTotalTime()), WarpSystem.currentConfig or "Unsaved"))
		end
	end)
end

WarpSystem.RefreshConfigList()

-- ══════════════════════════════════════════════════════════════════
-- 📍 WARP POINTS SECTION
-- ══════════════════════════════════════════════════════════════════
WarpTab:Section({ Title = "📍 Warp Points", TextSize = 16 })

WarpTab:Paragraph({
	Title = "Warp Loop System",
	Desc = "Create teleport routes and loop through them automatically.",
})

WarpSystem.pointsInfoParagraph = WarpTab:Paragraph({
	Title = "📊 Current Route",
	Desc = "Points: 0 | Est. Time: 0s",
})

WarpTab:Button({
	Title = "➕ Add Current Position",
	Desc = "Save your current location as a warp point",
	Callback = function()
		local char = GetCharacter()
		if not char then WindUI:Notify({ Title = "Error", Content = "Character not found!", Duration = 2 }) return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then WindUI:Notify({ Title = "Error", Content = "HumanoidRootPart not found!", Duration = 2 }) return end
		local pointName = "Point " .. (#WarpSystem.points + 1)
		table.insert(WarpSystem.points, { Name = pointName, CF = WarpSystem.CFToTable(hrp.CFrame) })
		WarpSystem.UpdatePointsInfo()
		WindUI:Notify({ Title = "✅ Added!", Content = pointName .. " saved", Duration = 2 })
	end,
})

WarpTab:Button({
	Title = "🗑️ Clear All Points",
	Desc = "Remove all warp points from current route",
	Callback = function()
		if #WarpSystem.points == 0 then WindUI:Notify({ Title = "Info", Content = "No points to clear", Duration = 2 }) return end
		local count = #WarpSystem.points
		WarpSystem.points = {}
		WarpSystem.currentConfig = nil
		WarpSystem.UpdatePointsInfo()
		WindUI:Notify({ Title = "🗑️ Cleared!", Content = count .. " points removed", Duration = 2 })
	end,
})

WarpTab:Input({
	Title = "📍 Select Point Number",
	Placeholder = "Enter point number (1-20)",
	Callback = function(text)
		local num = tonumber(text)
		if num and num >= 1 and num <= 20 then
			WarpSystem.selectedPointIndex = math.floor(num)
		end
	end,
})

WarpTab:Button({
	Title = "🎯 Teleport to Selected Point",
	Desc = "Warp to the selected point in your route",
	Callback = function()
		if #WarpSystem.points == 0 then WindUI:Notify({ Title = "Error", Content = "No points saved!", Duration = 2 }) return end
		local idx = math.min(WarpSystem.selectedPointIndex, #WarpSystem.points)
		local point = WarpSystem.points[idx]
		if not point then WindUI:Notify({ Title = "Error", Content = "Point not found!", Duration = 2 }) return end
		local char = GetCharacter()
		if char then char:PivotTo(WarpSystem.TableToCF(point.CF)) WindUI:Notify({ Title = "🚀 Warped!", Content = "Teleported to " .. point.Name, Duration = 2 }) end
	end,
})

WarpTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🔄 WARP LOOP SECTION
-- ══════════════════════════════════════════════════════════════════
WarpTab:Section({ Title = "🔄 Warp Loop", TextSize = 16 })

WarpSystem.delayInput = WarpTab:Input({
	Title = "⏱️ Loop Delay (seconds)",
	Placeholder = "Enter delay in seconds (0.5-30)",
	Callback = function(text)
		local num = tonumber(text)
		if num and num >= 0.5 and num <= 30 then
			WarpSystem.loopDelay = num
			WarpSystem.UpdatePointsInfo()
		end
	end,
})

WarpSystem.totalTimeInput = WarpTab:Input({
	Title = "⏰ Set Total Time (seconds)",
	Placeholder = "Enter desired total time",
	Callback = function(text)
		local total = tonumber(text)
		if total and total > 0 and #WarpSystem.points > 1 then
			WarpSystem.loopDelay = math.floor((total / (#WarpSystem.points - 1)) * 10) / 10
			WarpSystem.UpdatePointsInfo()
			WindUI:Notify({ Title = "⏱️ Delay Set", Content = string.format("Delay: %.1fs per point", WarpSystem.loopDelay), Duration = 2 })
		end
	end,
})

WarpSystem.loopStatusParagraph = WarpTab:Paragraph({
	Title = "🔄 Loop Status",
	Desc = "Status: Stopped",
})

WarpTab:Toggle({
	Title = "▶️ Start Warp Loop",
	Desc = "Automatically teleport through all points",
	Value = false,
	Callback = function(state)
		WarpSystem.isLooping = state
		if state then
			if #WarpSystem.points < 2 then WarpSystem.isLooping = false WindUI:Notify({ Title = "Error", Content = "Need at least 2 points!", Duration = 2 }) return end
			WindUI:Notify({ Title = "▶️ Loop Started", Content = "Cycling through " .. #WarpSystem.points .. " points", Duration = 2 })
			task.spawn(function()
				while WarpSystem.isLooping and #WarpSystem.points > 0 do
					for i, point in ipairs(WarpSystem.points) do
						if not WarpSystem.isLooping then break end
						local char = GetCharacter()
						if char then char:PivotTo(WarpSystem.TableToCF(point.CF)) end
						pcall(function() WarpSystem.loopStatusParagraph:SetDesc(string.format("Status: Running | Point %d/%d: %s", i, #WarpSystem.points, point.Name)) end)
						local startTime = os.clock()
						while os.clock() - startTime < WarpSystem.loopDelay do if not WarpSystem.isLooping then break end task.wait(0.1) end
					end
				end
				pcall(function() WarpSystem.loopStatusParagraph:SetDesc("Status: Stopped") end)
			end)
		else
			WindUI:Notify({ Title = "⏹️ Loop Stopped", Content = "Warp loop stopped", Duration = 2 })
			pcall(function() WarpSystem.loopStatusParagraph:SetDesc("Status: Stopped") end)
		end
	end,
})

WarpTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 💾 CONFIG MANAGEMENT SECTION
-- ══════════════════════════════════════════════════════════════════
WarpTab:Section({ Title = "💾 Save & Load Configs", TextSize = 16 })

WarpTab:Input({
	Title = "📝 Config Name",
	Placeholder = "Enter config name to save",
	Callback = function(text) WarpSystem.configNameInput = text end,
})

-- Store dropdown reference for refresh
WarpSystem.configDropdown = nil

-- Function to get current config list
WarpSystem.GetConfigValues = function()
	WarpSystem.RefreshConfigList()
	if #WarpSystem.savedConfigs > 0 then
		return WarpSystem.savedConfigs
	end
	return {"No configs saved"}
end

-- Function to refresh dropdown (try different methods)
WarpSystem.RefreshDropdown = function()
	WarpSystem.RefreshConfigList()
	if WarpSystem.configDropdown then
		pcall(function()
			-- Try different refresh methods that WindUI might support
			if WarpSystem.configDropdown.Refresh then
				WarpSystem.configDropdown:Refresh(WarpSystem.GetConfigValues())
			elseif WarpSystem.configDropdown.SetValues then
				WarpSystem.configDropdown:SetValues(WarpSystem.GetConfigValues())
			elseif WarpSystem.configDropdown.UpdateValues then
				WarpSystem.configDropdown:UpdateValues(WarpSystem.GetConfigValues())
			end
		end)
	end
end

WarpTab:Button({
	Title = "💾 Save Current Config",
	Desc = "Save current warp points to file",
	Callback = function()
		if WarpSystem.configNameInput == "" then WindUI:Notify({ Title = "Error", Content = "Enter a config name!", Duration = 2 }) return end
		if #WarpSystem.points == 0 then WindUI:Notify({ Title = "Error", Content = "No points to save!", Duration = 2 }) return end
		if WarpSystem.SaveConfig(WarpSystem.configNameInput) then
			WindUI:Notify({ Title = "✅ Saved!", Content = "Config '" .. WarpSystem.configNameInput .. "' saved. Re-execute script to see in dropdown.", Duration = 4 })
			WarpSystem.UpdatePointsInfo()
			WarpSystem.RefreshDropdown() -- Try to refresh dropdown
		else WindUI:Notify({ Title = "Error", Content = "Failed to save config!", Duration = 2 }) end
	end,
})

-- Store dropdown reference for refresh (destroy & recreate approach)
WarpSystem.configDropdown = nil
WarpSystem.dropdownSection = nil

-- Function to create/recreate dropdown
WarpSystem.CreateConfigDropdown = function()
	WarpSystem.RefreshConfigList()
	local values = #WarpSystem.savedConfigs > 0 and WarpSystem.savedConfigs or {"No configs saved"}
	
	-- Try to destroy existing dropdown if exists
	if WarpSystem.configDropdown then
		pcall(function()
			if WarpSystem.configDropdown.Destroy then
				WarpSystem.configDropdown:Destroy()
			elseif WarpSystem.configDropdown.Remove then
				WarpSystem.configDropdown:Remove()
			end
		end)
	end
	
	-- Create new dropdown
	WarpSystem.configDropdown = WarpTab:Dropdown({
		Title = "📂 Select Config (" .. #WarpSystem.savedConfigs .. " saved)",
		Desc = "Choose a config to load or delete",
		Values = values,
		Callback = function(selected) 
			if selected ~= "No configs saved" then 
				WarpSystem.selectedConfigToLoad = selected 
				WindUI:Notify({ Title = "✅ Selected", Content = "Config: " .. selected, Duration = 2 })
			end 
		end,
	})
end

-- Create initial dropdown
WarpSystem.CreateConfigDropdown()

WarpTab:Button({
	Title = "🔄 Refresh Dropdown",
	Desc = "Update dropdown with latest saved configs",
	Callback = function()
		WarpSystem.RefreshConfigList()
		local count = #WarpSystem.savedConfigs
		
		-- Try different methods to update dropdown
		local updated = false
		if WarpSystem.configDropdown then
			pcall(function()
				-- Method 1: Try SetValues
				if WarpSystem.configDropdown.SetValues then
					local values = count > 0 and WarpSystem.savedConfigs or {"No configs saved"}
					WarpSystem.configDropdown:SetValues(values)
					updated = true
				end
			end)
			pcall(function()
				-- Method 2: Try Refresh
				if not updated and WarpSystem.configDropdown.Refresh then
					local values = count > 0 and WarpSystem.savedConfigs or {"No configs saved"}
					WarpSystem.configDropdown:Refresh(values)
					updated = true
				end
			end)
		end
		
		if updated then
			WindUI:Notify({ Title = "✅ Dropdown Updated", Content = count .. " configs available", Duration = 2 })
		else
			-- Fallback: Show list in notification since dropdown can't be updated
			if count == 0 then
				WindUI:Notify({ Title = "📂 No Configs", Content = "No configs saved yet!", Duration = 2 })
			else
				local list = table.concat(WarpSystem.savedConfigs, ", ")
				WindUI:Notify({ Title = "📂 " .. count .. " Configs", Content = list .. "\n\n⚠️ Re-execute script to update dropdown", Duration = 5 })
			end
		end
	end,
})

WarpTab:Button({
	Title = "📥 Load Selected Config",
	Desc = "Load warp points from selected config",
	Callback = function()
		if not WarpSystem.selectedConfigToLoad or WarpSystem.selectedConfigToLoad == "" or WarpSystem.selectedConfigToLoad == "No configs saved" then 
			WindUI:Notify({ Title = "Error", Content = "Select a config first!", Duration = 2 }) 
			return 
		end
		
		if WarpSystem.LoadConfig(WarpSystem.selectedConfigToLoad) then
			WindUI:Notify({ Title = "✅ Loaded!", Content = string.format("Config '%s' loaded with %d points (Delay: %.1fs)", WarpSystem.selectedConfigToLoad, #WarpSystem.points, WarpSystem.loopDelay), Duration = 3 })
			WarpSystem.UpdatePointsInfo()
		else 
			WindUI:Notify({ Title = "Error", Content = "Failed to load config!", Duration = 2 }) 
		end
	end,
})

WarpTab:Button({
	Title = "🗑️ Delete Selected Config",
	Desc = "Delete the selected config",
	Callback = function()
		if not WarpSystem.selectedConfigToLoad or WarpSystem.selectedConfigToLoad == "" or WarpSystem.selectedConfigToLoad == "No configs saved" then 
			WindUI:Notify({ Title = "Error", Content = "Select a config first!", Duration = 2 }) 
			return 
		end
		WarpSystem.DeleteConfig(WarpSystem.selectedConfigToLoad)
		WindUI:Notify({ Title = "🗑️ Deleted!", Content = "Config '" .. WarpSystem.selectedConfigToLoad .. "' deleted. Tap Refresh to update dropdown.", Duration = 3 })
		WarpSystem.selectedConfigToLoad = ""
	end,
})

WarpTab:Divider()





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
			setclipboard("https://dsc.gg/starshipcore")
			WindUI:Notify({ Title = "✅ Copied!", Content = "Discord invite link copied to clipboard!", Duration = 3 })
		else
			WindUI:Notify({ Title = "Discord", Content = "https://dsc.gg/starshipcore", Duration = 5 })
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
	Desc = "Version 1.1 • Made with 💜\n\nThank you for using Starship Mobile!\nJoin our Discord for updates and support.",
})

-- ═══════���════════════════════════════════════��═════════════════════
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

-- Get available themes from WindUI
local availableThemes = {}
pcall(function()
	local themes = WindUI:GetThemes() or {}
	for themeName, _ in pairs(themes) do
		table.insert(availableThemes, themeName)
	end
	table.sort(availableThemes) -- Sort alphabetically
end)
if #availableThemes == 0 then
	availableThemes = { "Dark", "Light" } -- Fallback
end

local ThemeDropdown = SettingsTab:Dropdown({
	Title = "🎨 Theme",
	Desc = "Choose UI color theme (" .. #availableThemes .. " themes)",
	Values = availableThemes,
	Value = Settings.Theme or "Indigo",
	Callback = function(selected)
		Settings.Theme = selected
		SaveSettings()
		pcall(function()
			WindUI:SetTheme(selected)
		end)
		WindUI:Notify({
			Title = "🎨 Theme",
			Content = "Theme changed to " .. selected,
			Duration = 2,
		})
	end,
})

-- UI Transparency Slider (Background Image)
SettingsTab:Slider({
	Title = "🔍 Background Transparency",
	Desc = "Adjust background image transparency (0 = visible, 1 = hidden)",
	Step = 0.05,
	Value = {
		Min = 0,
		Max = 1,
		Default = 0.85,
	},
	Callback = function(value)
		pcall(function()
			Window:SetBackgroundImageTransparency(value)
		end)
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
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Select()

-- Track window state untuk cleanup (use _G to reduce local count)
_G.StarshipWindowState = _G.StarshipWindowState or { isDestroyed = false }

-- Fungsi cleanup untuk destroy semua
local function CleanupAll()
	if _G.StarshipWindowState.isDestroyed then
		return
	end
	_G.StarshipWindowState.isDestroyed = true

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

-- Check for updates using cached data
task.spawn(function()
	task.wait(5) -- Wait for UI to settle
	local data = _G.StarshipChangelogData
	
	if data and data.currentVersion and data.currentVersion ~= VERSION then
		WindUI:Notify({
			Title = "Update Available",
			Content = "New version " .. data.currentVersion .. " is available!\nRe-execute script to update.",
			Duration = 8,
			Icon = "download"
		})
	end
end)
