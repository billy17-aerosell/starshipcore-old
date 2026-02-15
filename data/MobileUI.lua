--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║                  STARSHIP MOBILE                              ║
    ║                  Powered by WindUI                            ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════════
-- ADONIS BYPASS (Must load FIRST before any hookmetamethod calls)
-- Prevents "namecallInstance detector detected" kicks
-- ══════════════════════════════════════════════════════════════════
local SilenceActive = true
task.delay(11, function() SilenceActive = false end)

local sg = game:GetService("StarterGui")
local cg = game:GetService("CoreGui")

local function checkBypassUI(obj)
    if not SilenceActive then return end
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        local t = tostring(obj.Text):lower()
        if t:find("adonis") or t:find("pixeluted") or t:find("bypassed") then
            local root = obj
            local lp = game:GetService("Players").LocalPlayer
            local pg = lp and lp:FindFirstChild("PlayerGui")
            
            while root.Parent and root.Parent ~= cg and root.Parent ~= pg and root.Parent ~= game do
                root = root.Parent
            end
            
            local name = root.Name:lower()
            if not name:find("starship") and not name:find("windui") and not name:find("wind_") then
                pcall(function() root:Destroy() end)
            end
        end
    end
end

-- Hook into CoreGui and wait for PlayerGui
cg.DescendantAdded:Connect(checkBypassUI)
task.spawn(function()
    local lp = game:GetService("Players").LocalPlayer
    while not lp do task.wait() lp = game:GetService("Players").LocalPlayer end
    local pg = lp:WaitForChild("PlayerGui")
    pg.DescendantAdded:Connect(checkBypassUI)
    for _, v in pairs(pg:GetDescendants()) do checkBypassUI(v) end
end)

-- Polling: much less frequent (every 1s instead of 0.1s) to save FPS
task.spawn(function()
    for i = 1, 15 do
        if not SilenceActive then break end
        for _, v in pairs(cg:GetChildren()) do -- Scan top-level objects first (faster)
            if v:IsA("ScreenGui") then
                for _, desc in pairs(v:GetDescendants()) do
                    checkBypassUI(desc)
                end
            end
        end
        task.wait(1.0) 
    end
end)

local old; old = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if SilenceActive and self == sg and method == "SetCore" and args[1] == "SendNotification" then
        local data = args[2]
        if data and (tostring(data.Title):find("Adonis") or tostring(data.Text):find("pixeluted") or tostring(data.Text):find("bypassed")) then
            return
        end
    end
    return old(self, ...)
end)

pcall(function()
	loadstring(game:HttpGet('https://raw.githubusercontent.com/Pixeluted/adoniscries/main/Source.lua'))()
end)

-- Remove any blur effects added by bypass
task.spawn(function()
    for i = 1, 20 do
        if not SilenceActive then break end
        pcall(function()
            for _, effect in pairs(game:GetService("Lighting"):GetChildren()) do
                if effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
                    effect:Destroy()
                end
            end
        end)
        task.wait(0.5)
    end
end)


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local LocalPlayer = Players.LocalPlayer
local VERSION = "1.2.6"
local CLOUD_API_BASE = _G.StarshipServerURL or "https://starship-core.my.id"

-- ══════════════════════════════════════════════════════════════════
-- STARSHIP UNIQUE IDENTIFIER SYSTEM
-- ══════════════════════════════════════════════════════════════════
local STARSHIP_ID = "STARSHIP_MOBILE_GUI_" .. tostring(math.random(100000, 999999))

-- Simple function to destroy all Starship GUIs
local function DestroyAllStarshipGUIs()
    local destroyed = 0
    local containers = {game:GetService("CoreGui")}
    pcall(function() table.insert(containers, game.Players.LocalPlayer.PlayerGui) end)
    pcall(function() if gethui then table.insert(containers, gethui()) end end)
    
    for _, container in pairs(containers) do
        if not container then continue end
        for _, gui in pairs(container:GetChildren()) do
            if gui:IsA("ScreenGui") then
                -- Check for our unique attribute or name
                local guiID = gui:GetAttribute("StarshipID")
                if (guiID and tostring(guiID):find("STARSHIP_MOBILE_GUI_")) or gui.Name == "StarshipMiniApple" then
                    if DEV_MODE then warn("[STARSHIP] 🗑️ Destroying old GUI: " .. gui.Name) end
                    pcall(function() gui:Destroy() end)
                    destroyed = destroyed + 1
                end
            end
        end
    end
    return destroyed
end

-- Cleanup any existing Starship GUIs from previous executions (deferred)
task.defer(function()
	local oldDestroyed = DestroyAllStarshipGUIs()
	if oldDestroyed > 0 then
		if DEV_MODE then warn("[STARSHIP] ♻️ Cleaned up " .. oldDestroyed .. " previous GUI(s)") end
	end
end)

-- Clear old globals IMMEDIATELY to prevent old code from interfering
_G.StarshipCleanup = nil -- CRITICAL: Remove old cleanup function that causes premature termination
_G.STARSHIP_MOBILE_ACTIVE = nil
_G.StarshipWindow = nil
_G.StarshipWindUI = nil
pcall(function() getgenv().StarshipWindow = nil end)
pcall(function() getgenv().StarshipWindUI = nil end)
pcall(function() getgenv().STARSHIP_MOBILE_ACTIVE = nil end)



-- DEV_MODE detection (same as StarshipCore)
local DEV_MODE = _G.StarshipDevMode or false

-- ══════════════════════════════════════════════════════════════════
-- ANTI-MULTI-SCRIPT PROTECTION SYSTEM (STRUCTURE-BASED DETECTION)
-- Detects script hubs by their UI structure (key system, authentication, etc)
-- NOT by name to avoid false positives
-- ══════════════════════════════════════════════════════════════════
local AntiMultiScript = {}
AntiMultiScript.Enabled = true
AntiMultiScript.CheckInterval = 5.0 -- Increased from 0.5 to 5.0 for better mobile performance
AntiMultiScript.UniqueToken = "STARSHIP_MOBILE_" .. tostring(os.clock()) .. "_" .. tostring(math.random(100000, 999999))
AntiMultiScript.Connections = {}
AntiMultiScript.Running = true
AntiMultiScript.Terminated = false

-- BLACKLIST: Script hub indicators (case insensitive, searched in VISIBLE TEXT only)
-- Must be VERY SPECIFIC to avoid false positives
AntiMultiScript.ScriptHubIndicators = {
	-- RullzsyHUB specific patterns (MOST RELIABLE)
	"rullzsy", "rullzsyhub", "dsc.gg/rullzsyhub", "@rullzsy_",
	-- Key System UI text patterns (with spaces - more specific)
	"| key system", "key system |",  -- Title format like "RullzsyHUB | Key System"
	"[•] input key", "[•] verify key", -- Button format
	"get your key", "enter your key", "paste your key",
	-- Authentication UI patterns
	"authentication required", "whitelist check", "hwid check",
	"your key is invalid", "key expired",
	-- Script hub discord patterns
	"linkvertise.com", "fluxteam",
	-- Other known script hubs
	"scripthub v", "script hub v", -- Versioned hubs
}

-- WHITELIST: ONLY our own GUIs by specific name (NOT 'windui' - other scripts use it too!)
AntiMultiScript.WhitelistedGUIs = {
	"starship", "starshipmobile", "starshipcore", "starshipchangelog",
}

-- Direct reference to OUR GUI (set when created)
AntiMultiScript.OurGUI = nil

-- NOTE: Do NOT set _G.StarshipCleanup here - it causes premature termination
-- Cleanup is handled by DestroyAllStarshipGUIs() at script start

local function PerformDetectionScan()
	local detected = false
	local detectedGUI = ""
	local detectedIndicator = ""
	
	pcall(function()
		local containers = GetAllGUIContainers()
		
		for _, container in ipairs(containers) do
			if not container then continue end
			
			for _, gui in pairs(container:GetChildren()) do
				-- ONLY scan ScreenGuis that are NOT whitelisted
				if gui:IsA("ScreenGui") and not IsWhitelistedGUI(gui.Name, gui) then
					-- Scan this specific GUI for the indicators the user specified
					local hasIndicators, indicator = HasScriptHubIndicators(gui)
					if hasIndicators then
						detected = true
						detectedGUI = gui:GetFullName()
						detectedIndicator = indicator
						return
					end
				end
			end
		end
	end)
	
	return detected, detectedGUI, detectedIndicator
end

-- ══════════════════════════════════════════════════════════════════
-- INITIAL PRE-EXECUTION SCAN (at the very top)
-- ══════════════════════════════════════════════════════════════════
do
	local isPresent, loc, ind = PerformDetectionScan()
	if not isPresent then 
		task.wait(1.5) -- Delay to let other scripts fully load
		isPresent, loc, ind = PerformDetectionScan()
	end
	
	if isPresent then
		if DEV_MODE then
			warn("═══════════════════════════════════════════════════════════")
			warn("[STARSHIP] 🛡️ BLOCKED: unauthorized script active!")
			warn("[STARSHIP] Reason: " .. tostring(ind))
			warn("═══════════════════════════════════════════════════════════")
		end
		error("[STARSHIP] Execution blocked - unauthorized script detected") -- Force complete halt
	end
end

-- Cleanup function
local function TerminateScript(reason)
	if AntiMultiScript.Terminated then return end
	AntiMultiScript.Terminated = true
	AntiMultiScript.Running = false
	
	if DEV_MODE then warn("[STARSHIP] ⚠️ Terminating script: " .. tostring(reason)) end
	
	-- Disconnect all connections
	for _, conn in pairs(AntiMultiScript.Connections) do
		pcall(function() conn:Disconnect() end)
	end
	
	-- AGGRESSIVE GUI DESTRUCTION (Using Attribute-based detection)
	if DEV_MODE then warn("[STARSHIP] 🗑️ Finding and destroying Starship UI...") end
	
	-- Use our reliable attribute-based destruction
	local destroyed = DestroyAllStarshipGUIs()
	
	-- Clear global references
	_G.STARSHIP_MOBILE_ACTIVE = nil
	_G.StarshipWindow = nil
	_G.StarshipWindUI = nil
	_G.StarshipSession = nil
	_G.StarshipCleanup = nil
	pcall(function() getgenv().STARSHIP_MOBILE_ACTIVE = nil end)
	pcall(function() getgenv().StarshipWindow = nil end)
	pcall(function() getgenv().StarshipWindUI = nil end)
	
	if DEV_MODE then warn("[STARSHIP] ⚠️ Script terminated! Destroyed " .. destroyed .. " GUI(s)") end
end

-- Check if GUI is whitelisted (our own GUIs)
local function IsWhitelistedGUI(guiName, guiInstance)
	if not guiName then return false end
	
	-- Check if this is OUR specific GUI instance (most reliable)
	if guiInstance and AntiMultiScript.OurGUI and guiInstance == AntiMultiScript.OurGUI then
		return true
	end
	
	local lowerName = guiName:lower()
	
	-- Check our own GUIs by specific name pattern
	for _, pattern in ipairs(AntiMultiScript.WhitelistedGUIs) do
		if lowerName:find(pattern, 1, true) then
			return true
		end
	end
	
	return false
end

-- Check if GUI has script hub indicators in its VISIBLE TEXT (not element names)
local function HasScriptHubIndicators(gui)
	local found = false
	local foundIndicator = ""
	
	pcall(function()
		local descendants = gui:GetDescendants()
		local checkCount = 0
		local MAX_CHECKS = 200 -- Limit to prevent lag on complex UIs
		
		for _, desc in pairs(descendants) do
			if checkCount >= MAX_CHECKS then break end
			
			-- ONLY check VISIBLE TEXT content (not element names - they cause false positives)
			if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
				checkCount = checkCount + 1
				local text = (desc.Text or ""):lower()
				
				-- Skip empty or very short text
				if #text < 3 then continue end
				
				for _, indicator in ipairs(AntiMultiScript.ScriptHubIndicators) do
					if text:find(indicator, 1, true) then
						found = true
						foundIndicator = indicator .. " (visible text: '" .. string.sub(desc.Text or "", 1, 40) .. "')"
						return
					end
				end
			end
		end
	end)
	
	return found, foundIndicator
end

-- Get all GUI containers to scan
local function GetAllGUIContainers()
	local containers = {}
	
	pcall(function()
		table.insert(containers, game:GetService("CoreGui"))
	end)
	
	pcall(function()
		local pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
		if pg then table.insert(containers, pg) end
	end)
	
	pcall(function()
		if gethui then
			local hui = gethui()
			if hui then table.insert(containers, hui) end
		end
	end)
	
	return containers
end

-- MAIN SCAN FUNCTION - ONLY detect based on specific text indicators
local function ScanForScriptHubs()
	if not AntiMultiScript.Running then return false end
	
	local DEBUG = DEV_MODE -- Set to true to see all GUIs being scanned
	
	for _, container in pairs(GetAllGUIContainers()) do
		pcall(function()
			for _, gui in pairs(container:GetChildren()) do
				if gui:IsA("ScreenGui") then
					local guiName = gui.Name or "Unknown"
					
					-- Skip whitelisted GUIs (our own + Roblox system + game admins)
					if IsWhitelistedGUI(guiName, gui) then 
						continue 
					end
					
					-- Log non-whitelisted GUIs for debugging
					local descendantCount = #gui:GetDescendants()
					if DEBUG and descendantCount > 10 then
						warn("[STARSHIP DEBUG] Scanning: '" .. guiName .. "' (" .. descendantCount .. " descendants)")
					end
					
					-- Check for script hub indicators ONLY (text-based detection)
					local hasIndicators, indicator = HasScriptHubIndicators(gui)
					if hasIndicators then
						if DEV_MODE then
							warn("[STARSHIP] ⚠️ DETECTED SCRIPT HUB: " .. guiName)
							warn("[STARSHIP] ⚠️ Found indicator: " .. indicator)
						end
						TerminateScript("Script hub: " .. guiName .. " (" .. indicator .. ")")
						return true
					end
				end
			end
		end)
	end
	
	return false
end

-- Monitor for new GUIs
local function SetupGUIMonitors()
	for _, container in pairs(GetAllGUIContainers()) do
		pcall(function()
			local conn = container.ChildAdded:Connect(function(child)
				if not AntiMultiScript.Running then return end
				
				-- Wait for GUI to fully load
				task.wait(1.5) -- Wait for script hub UI to fully populate
				
				if not child:IsA("ScreenGui") then return end
				
				local guiName = child.Name or "Unknown"
				if IsWhitelistedGUI(guiName, child) then return end
				
				local descendantCount = #child:GetDescendants()
				if descendantCount > 10 and DEV_MODE then
					warn("[STARSHIP DEBUG] New GUI: '" .. guiName .. "' (" .. descendantCount .. " descendants)")
				end
				
				-- Check for script hub indicators ONLY
				local hasIndicators, indicator = HasScriptHubIndicators(child)
				if hasIndicators then
					if DEV_MODE then
						warn("[STARSHIP] ⚠️ NEW SCRIPT HUB DETECTED: " .. guiName)
						warn("[STARSHIP] ⚠️ Found indicator: " .. indicator)
					end
					TerminateScript("New script hub: " .. guiName .. " (" .. indicator .. ")")
				end
			end)
			
			table.insert(AntiMultiScript.Connections, conn)
		end)
	end
end

-- Monitor getgenv() changes for script libraries
local function MonitorGlobalEnv()
	local startupKeys = {}
	
	-- Record existing keys
	pcall(function()
		local genv = getgenv()
		for k, _ in pairs(genv) do
			startupKeys[k] = true
		end
	end)
	
	-- Periodic check for new libraries
	task.spawn(function()
		while AntiMultiScript.Running do
			task.wait(AntiMultiScript.CheckInterval)
			
			-- Check token integrity
			if _G.STARSHIP_MOBILE_ACTIVE ~= AntiMultiScript.UniqueToken then
				TerminateScript("Token modified by another script")
				break
			end
			
			-- Check for new UI libraries
			local suspiciousLibs = {
				"OrionLib", "RayfieldLib", "KavoUI", "VenyxLib",
				"LinoriaLib", "Fluent", "Rayfield", "Orion", "Kavo"
			}
			
			pcall(function()
				local genv = getgenv()
				for _, libName in ipairs(suspiciousLibs) do
					if not startupKeys[libName] and genv[libName] ~= nil then
						if type(genv[libName]) == "table" then
							local lib = genv[libName]
							if lib.CreateWindow or lib.MakeWindow or lib.CreateTab or lib.new then
								if DEV_MODE then warn("[STARSHIP] ⚠️ Detected script library: " .. libName) end
								TerminateScript("Library: " .. libName)
								return
							end
						end
					end
				end
			end)
			
			-- Also check _G
			for _, libName in ipairs(suspiciousLibs) do
				if not startupKeys[libName] and _G[libName] ~= nil then
					if type(_G[libName]) == "table" then
						local lib = _G[libName]
						if lib.CreateWindow or lib.MakeWindow or lib.CreateTab or lib.new then
							if DEV_MODE then warn("[STARSHIP] ⚠️ Detected _G library: " .. libName) end
							TerminateScript("_G Library: " .. libName)
							return
						end
					end
				end
			end
			
			-- Periodic full scan for script hubs
			ScanForScriptHubs()
		end
	end)
end

-- INITIALIZE PROTECTION (Deferred to reduce startup lag)
task.defer(function()
	task.wait(2) -- Wait for UI to fully render first
	
	if AntiMultiScript.Enabled then
		-- Initial scan - check for existing script hubs
		local foundExisting = ScanForScriptHubs()
		
		if not foundExisting and AntiMultiScript.Running then
			-- Setup monitors
			SetupGUIMonitors()
			MonitorGlobalEnv()
			
			if DEV_MODE then warn("[STARSHIP] 🛡️ Anti-Multi-Script protection ACTIVE (Structure-Based)") end
		end
	end
end)

-- Export
getgenv().StarshipAntiMultiScript = AntiMultiScript

-- ══════════════════════════════════════════════════════════════════
-- LOAD WINDUI
-- ══════════════════════════════════════════════════════════════════
local WindUI = nil
local function LoadWindUI()
    local urls = {
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/Source.lua"
    }
    for _, url in ipairs(urls) do
        local success, content = pcall(game.HttpGet, game, url)
        if success and content and #content > 500 then
            local func, err = loadstring(content)
            if func then
                local execSuccess, result = pcall(func)
                if execSuccess and result then return result end
            end
        end
    end
    return nil
end

 WindUI = LoadWindUI()

-- ══════════════════════════════════════════════════════════════════
-- LOAD STARSPACE PLAYBACK ENGINE
-- ══════════════════════════════════════════════════════════════════
-- Set UI reference for StarSpacePlayback to use
_G.Xan = {
    Slide = function(title, content)
        if WindUI and WindUI.Notify then
            WindUI:Notify({ Title = title, Content = content, Duration = 2 })
        end
    end
}

-- Load StarSpacePlayback module
local StarSpacePlaybackLoaded = false
task.spawn(function()
    local baseUrl = _G.StarshipServerURL or "https://starship-core.my.id"
    local PLAYBACK_URL = baseUrl .. "/api/get-module?name=StarSpacePlayback.lua"
    
    -- Add user ID for production whitelist check (if available)
    local userId = tostring(game.Players.LocalPlayer.UserId)
    if userId and not baseUrl:find("localhost") then
        PLAYBACK_URL = PLAYBACK_URL .. "&user=" .. userId
    end

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

        -- Handle JSON response (Production Mode)
        if content:sub(1, 1) == "{" then
            local jsonSuccess, jsonData = pcall(function()
                return game:GetService("HttpService"):JSONDecode(content)
            end)

            if jsonSuccess and jsonData.status == "success" and jsonData.blob and jsonData.key then
                -- Helper functions for decryption
                local function base64Decode(data)
                    local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
                    data = string.gsub(data, "[^" .. b .. "=]", "")
                    return (data:gsub(".", function(x)
                        if x == "=" then return "" end
                        local r, f = "", (b:find(x) - 1)
                        for i = 6, 1, -1 do
                            r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
                        end
                        return r
                    end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
                        if #x ~= 8 then return "" end
                        local c = 0
                        for i = 1, 8 do
                            c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
                        end
                        return string.char(c)
                    end))
                end

                local function xorDecrypt(data, key)
                    local result = {}
                    for i = 1, #data do
                        local keyChar = key:byte(((i - 1) % #key) + 1)
                        result[i] = string.char(bit32.bxor(data:byte(i), keyChar))
                    end
                    return table.concat(result)
                end

                -- Decrypt the module
                local decoded = base64Decode(jsonData.blob)
                content = xorDecrypt(decoded, jsonData.key)
            else
                error("Invalid JSON response from server: " .. tostring(jsonData and jsonData.error or "Unknown"))
            end
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
	Theme = "Indigo",
	AutoLeaveAdmin = false,
	AdminESP = false,
	AdminESPBox = true,
	AdminESPChams = true,
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
	Title = "✨ STARSHIP┃dsc.gg-starshipcore",
	Icon = "rbxassetid://123840945153526", -- Logo next to title
	IconSize = 36, -- Larger icon for premium look

	Author = "Premium Edition • StarshipCore",
	Size = UDim2.fromOffset(770, 500),
	SideBarWidth = 180,
	Transparent = true,
	BackgroundImageTransparency = 0.92,
	Background = "rbxassetid://123840945153526",
	Theme = Settings.Theme or "Indigo",
	NewElements = true, -- WindUI V2 feature
	User = {
		Enabled = true,
		Anonymous = true,
		Callback = function()
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
	Topbar = {
		Height = 65,
		ButtonsType = "Default",
	},

	-- ═══ FLOATING OPEN BUTTON (PREMIUM GRADIENT) ═══
	OpenButton = {
		Title = "STARSHIP ✨",
		Icon = "rbxassetid://123840945153526",
		Size = UDim2.fromOffset(140, 52), -- Ukuran diperbesar (140x52) agar lebih nyaman di mobile
		CornerRadius = UDim.new(1, 0),
		StrokeThickness = 2.5,
		Enabled = true,
		Draggable = true,
		OnlyMobile = false,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#667eea")),
			ColorSequenceKeypoint.new(0.5, Color3.fromHex("#764ba2")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("#f093fb")),
		}),
	},


})

-- Global token
_G.STARSHIP_MOBILE_ACTIVE = AntiMultiScript.UniqueToken
pcall(function() getgenv().STARSHIP_MOBILE_ACTIVE = AntiMultiScript.UniqueToken end)


-- Store Window reference globally for ban system
getgenv().StarshipWindow = Window
getgenv().StarshipWindUI = WindUI

-- CRITICAL: Tag our GUI with unique identifier IMMEDIATELY
if Window.Internal and Window.Internal.ScreenGui then
	AntiMultiScript.OurGUI = Window.Internal.ScreenGui
	-- TAG WITH UNIQUE ID FOR RELIABLE DESTRUCTION
	AntiMultiScript.OurGUI:SetAttribute("StarshipID", STARSHIP_ID)
	if DEV_MODE then warn("[STARSHIP] 🛡️ GUI tagged with ID: " .. STARSHIP_ID) end
else
	-- Fallback: scan and tag
	local containers = {game:GetService("CoreGui")}
	pcall(function() table.insert(containers, game.Players.LocalPlayer.PlayerGui) end)
	pcall(function() if gethui then table.insert(containers, gethui()) end end)
	
	for _, container in pairs(containers) do
		if not container then continue end
		for _, gui in pairs(container:GetChildren()) do
			if gui:IsA("ScreenGui") and gui.Name:lower():find("windui") then
				-- Check if it has STARSHIP content and NOT tagged yet
				local hasStarship = false
				local hasExistingTag = gui:GetAttribute("StarshipID") ~= nil
				
				if not hasExistingTag then
					for _, desc in pairs(gui:GetDescendants()) do
						if desc:IsA("TextLabel") and desc.Text:find("STARSHIP") then
							hasStarship = true
							break
						end
					end
					
					if hasStarship then
						AntiMultiScript.OurGUI = gui
						gui:SetAttribute("StarshipID", STARSHIP_ID)
						if DEV_MODE then warn("[STARSHIP] 🛡️ GUI tagged via scan: " .. gui.Name) end
						break
					end
				end
			end
		end
		if AntiMultiScript.OurGUI then break end
	end
end

if not AntiMultiScript.OurGUI then
	if DEV_MODE then warn("[STARSHIP] ⚠️ WARNING: Could not tag GUI!") end
end

-- ══════════════════════════════════════════════════════════════════
-- CONTINUOUS PROTECTION LOOP (Background Monitoring)
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
	task.wait(3) -- Wait for GUI to be fully created and tagged
	
	-- Reset terminated flag in case old code set it
	AntiMultiScript.Terminated = false
	if DEV_MODE then warn("[STARSHIP] 🛡️ Background protection active...") end
	
	local loopTerminated = false -- LOCAL flag to prevent interference from old code
	local scanCount = 0
	while not loopTerminated do
		task.wait(5.0) -- Increased from 1.5 to 5.0 for performance
		scanCount = scanCount + 1
		
		local detected, detectedGUI, detectedIndicator = PerformDetectionScan()
		
		if detected then
			if DEV_MODE then
				warn("═══════════════════════════════════════════════════════════")
				warn("[STARSHIP] ⚠️ SCRIPT HUB DETECTED! Closing Starship...")
				warn("[STARSHIP] Evidence: " .. detectedIndicator)
				warn("═══════════════════════════════════════════════════════════")
			end
			
		-- DIRECT GUI DESTRUCTION (bypass TerminateScript)
			loopTerminated = true
			
			-- Method 1: Destroy saved reference
			if AntiMultiScript.OurGUI then
				if DEV_MODE then warn("[STARSHIP] 🗑️ Destroying OurGUI: " .. AntiMultiScript.OurGUI.Name) end
				pcall(function() 
					AntiMultiScript.OurGUI.Enabled = false
					AntiMultiScript.OurGUI:Destroy() 
				end)
			end
			
			-- Method 2: Destroy by attribute
			local destroyed = DestroyAllStarshipGUIs()
			if DEV_MODE then warn("[STARSHIP] 🗑️ DestroyAllStarshipGUIs() removed: " .. destroyed) end
			
			-- Method 3: Brute force - destroy ALL WindUI with STARSHIP content
			pcall(function()
				local containers = {game:GetService("CoreGui")}
				pcall(function() table.insert(containers, game.Players.LocalPlayer.PlayerGui) end)
				pcall(function() if gethui then table.insert(containers, gethui()) end end)
				
				for _, container in pairs(containers) do
					if not container then continue end
					for _, gui in pairs(container:GetChildren()) do
						if gui:IsA("ScreenGui") then
							local guiName = gui.Name:lower()
							if guiName:find("windui") or guiName:find("starship") then
								-- Check content
								for _, desc in pairs(gui:GetDescendants()) do
									if desc:IsA("TextLabel") then
										local text = desc.Text or ""
										if (text:find("STARSHIP") or text:find("dsc.gg")) and not text:lower():find("rullzsy") then
											if DEV_MODE then warn("[STARSHIP] 🗑️ Force destroying: " .. gui.Name) end
											gui.Enabled = false
											gui:Destroy()
											break
										end
									end
								end
							end
						end
					end
				end
			end)
			
			-- Clear globals
			_G.STARSHIP_MOBILE_ACTIVE = nil
			pcall(function() getgenv().StarshipWindow = nil end)
			
			if DEV_MODE then warn("[STARSHIP] ⚠️ Protection complete - Starship closed") end
			break
		end
		
		if scanCount <= 2 then
			if DEV_MODE then warn("[STARSHIP] Scan #" .. scanCount .. " complete - no threats") end
		end
	end
end)

task.wait(0.1)

-- ══════════════════════════════════════════════════════════════════
-- LOGO OVERLAY (Using WindUI's built-in Background Image Settings)
-- ══════════════════════════════════════════════════════════════════
Window:SetBackgroundImage("rbxassetid://91946746369709")
Window:SetBackgroundImageTransparency(0.85)

-- ══════════════════════════════════════════════════════════════════
-- TOPBAR THEME SWITCH BUTTON
-- ══════════════════════════════════════════════════════════════════
-- getgenv().Theme = Settings.Theme or "Indigo"
-- Window:CreateTopbarButton(
-- 	"SwitchTheme",
-- 	"eye",
-- 	function()
-- 		getgenv().Theme = getgenv().Theme == "Indigo" and "Dark" or "Indigo"
-- 		WindUI:SetTheme(getgenv().Theme)
-- 		Settings.Theme = getgenv().Theme
-- 		SaveSettings()
-- 	end,
-- 	990
-- )

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

-- Live update FPS & PING (Optimized for mobile - no per-frame callback)
task.spawn(function()
	local frameCount = 0
	local lastTime = tick()
	
	-- Use a separate connection just for counting frames
	local countConn = RunService.Heartbeat:Connect(function()
		frameCount = frameCount + 1
	end)
	
	-- Update UI every 2 seconds (less frequent = better performance)
	while true do
		task.wait(2)
		
		local now = tick()
		local elapsed = now - lastTime
		if elapsed > 0 then
			local fps = math.floor(frameCount / elapsed)
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
	end
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
-- ══════════════════════════════════════════════════════════════════
-- 🏠 TABS SETUP
-- ══════════════════════════════════════════════════════════════════
local DashboardTab = Window:Tab({
	Title = "Dashboard",
	Icon = "solar:home-bold",
})
RunService.Heartbeat:Wait()

local AccountTab = Window:Tab({
	Title = "Account",
	Icon = "solar:user-bold",
})
RunService.Heartbeat:Wait()

local CustomAnimTab = Window:Tab({
	Title = "Animations",
	Icon = "solar:accessibility-bold",
})
RunService.Heartbeat:Wait()

local AvatarTab = Window:Tab({
	Title = "Avatar",
	Icon = "solar:user-plus-bold",
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
-- ══════════════════════════════════════════════════════════════════
-- 🏠 DASHBOARD CONTENT
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Section({
	Title = GetGreeting() .. ", " .. LocalPlayer.DisplayName .. "!",
	Desc = "Welcome to Starship Mobile • Version " .. VERSION,
})
DashboardTab:Space({ Columns = 0.5 })

DashboardTab:Space({ Columns = 1 })

local StatsGroup = DashboardTab:Group()
StatsGroup:Section({ Title = "Performance Stats", Desc = "Current system metrics" })
DashboardTab:Space({ Columns = 0.5 })

-- Placeholder for live stats if needed, or just grouped buttons/info
-- For now let's just use the space for layout
DashboardTab:Space({ Columns = 2 })

-- ══════════════════════════════════════════════════════════════════
-- SESSION DATA & HELPERS
-- ══════════════════════════════════════════════════════════════════
-- Try to find session data from multiple sources
local sessionData = _G.sessionData
if not sessionData and getgenv and getgenv().StarshipSession then
	sessionData = getgenv().StarshipSession
end

-- Mock session data for development/testing (will be overridden by real data in production)
if not sessionData then
	-- DEV MODE: Use mock data since no global session found
	-- IMPORTANT: In production, ensure _G.sessionData or StarshipSession is set!
	sessionData = {
		Role = "VIP Mobile",
		Duration = "30 days", -- Change this to test: "7 days", "24 hours", "Lifetime"
		UserId = LocalPlayer.UserId,
		Username = LocalPlayer.Name,
	}
end

-- Helper function to format role names
local function FormatRole(role)
	if not role then return "Free" end
	
	local roleColors = {
		["VIP Mobile"] = '<font color="#FFD700">VIP Mobile</font>',
		["PC VIP"] = '<font color="#00BFFF">PC VIP</font>',
		["Bundle"] = '<font color="#FF1493">Bundle</font>',
		["Lifetime"] = '<font color="#9370DB">Lifetime</font>',
	}
	
	return roleColors[role] or '<font color="#FFFFFF">' .. role .. '</font>'
end

-- ══════════════════════════════════════════════════════════════════
-- VIP STATUS
-- ══════════════════════════════════════════════════════════════════
AccountTab:Section({ Title = "VIP Status", Desc = "Manage your subscription details" })
AccountTab:Space({ Columns = 0.5 })

-- Parse VIP expiry time from sessionData
local vipExpiryTime = nil
local vipParagraph = nil

-- Function to parse duration string and calculate expiry timestamp
local function ParseVIPExpiry(durationStr)
	if not durationStr or durationStr == "Lifetime" or durationStr == "lifetime" then
		return nil -- Lifetime VIP
	end
	
	-- Try to parse duration like "30 days", "7 days", etc
	local days = tonumber(durationStr:match("(%d+)%s*day"))
	local hours = tonumber(durationStr:match("(%d+)%s*hour"))
	
	if days then
		return os.time() + (days * 24 * 60 * 60)
	elseif hours then
		return os.time() + (hours * 60 * 60)
	end
	
	return nil
end

-- Function to format time remaining
local function FormatTimeRemaining(seconds)
	if seconds <= 0 then
		return "Expired"
	end
	
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)
	
	if days > 0 then
		return string.format("%dd %dh %dm %ds", days, hours, mins, secs)
	elseif hours > 0 then
		return string.format("%dh %dm %ds", hours, mins, secs)
	elseif mins > 0 then
		return string.format("%dm %ds", mins, secs)
	else
		return string.format("%ds", secs)
	end
end

-- Calculate VIP expiry time
-- Calculate VIP expiry time
-- Fix: Prioritize absolute 'Expiry' timestamp from loader over relative 'Duration' string
if sessionData.Expiry and type(sessionData.Expiry) == "number" then
	vipExpiryTime = sessionData.Expiry
elseif sessionData.Expiry and type(sessionData.Expiry) == "string" and tonumber(sessionData.Expiry) then
    -- Handle string timestamp if passed as string
	vipExpiryTime = tonumber(sessionData.Expiry)
else
	-- Fallback: Calculate from duration string (Warning: This resets timer every session if used!)
	vipExpiryTime = ParseVIPExpiry(sessionData.Duration)
end

-- Initial VIP status description
local function GetVIPStatusDesc()
	local timeRemaining = "Lifetime"
	
	if vipExpiryTime then
		local remaining = vipExpiryTime - os.time()
		timeRemaining = FormatTimeRemaining(remaining)
	end
	
	return '<font size="16">Role: '
		.. FormatRole(sessionData.Role)
		.. "\n"
		.. "Time Remaining: "
		.. timeRemaining
		.. "\n"
		.. "Status: Active</font>"
end

vipParagraph = AccountTab:Paragraph({
	Title = "Subscription",
	Desc = GetVIPStatusDesc(),
})

-- Update VIP timer every second
if vipExpiryTime then
	task.spawn(function()
		while true do
			task.wait(1)
			
			local remaining = vipExpiryTime - os.time()
			
			if remaining <= 0 then
				-- VIP expired
				pcall(function()
					if vipParagraph and vipParagraph.SetDesc then
						vipParagraph:SetDesc('<font size="16">Role: '
							.. FormatRole(sessionData.Role)
							.. "\n"
							.. "Time Remaining: Expired\n"
							.. "Status: Inactive</font>")
					end
				end)
				break
			else
				-- Update countdown
				pcall(function()
					if vipParagraph and vipParagraph.SetDesc then
						vipParagraph:SetDesc(GetVIPStatusDesc())
					end
				end)
			end
		end
	end)
end

-- ══════════════════════════════════════════════════════════════════
-- GAME DETECTION
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Section({ Title = "Current Game", Desc = "Information about the activity you are playing" })
DashboardTab:Space({ Columns = 0.5 })

local gameName = GetGameName()
DashboardTab:Paragraph({
	Title = gameName,
	Desc = "Place ID: " .. game.PlaceId,
})

-- ══════════════════════════════════════════════════════════════════
-- ACCOUNT INFORMATION
-- ══════════════════════════════════════════════════════════════════
AccountTab:Section({ Title = "Account Info", Desc = "Detailed information about your Roblox account" })
AccountTab:Space({ Columns = 0.5 })

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
DashboardTab:Section({ Title = "Server Details", Desc = "Technical details about the current instance" })
DashboardTab:Space({ Columns = 0.5 })

DashboardTab:Button({
	Title = "Copy Job ID",
	Desc = "Copy server Job ID to clipboard",
	Icon = "solar:copy-bold",
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
AccountTab:Section({ Title = "Friends in Server", Desc = "Friends currently playing with you" })
AccountTab:Space({ Columns = 0.5 })

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
DashboardTab:Space({ Columns = 0.5 })

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
DashboardTab:Section({ Title = "Server Actions", Desc = "Quick commands for server management" })
DashboardTab:Space({ Columns = 0.5 })

local ServerActions = DashboardTab:Group()

ServerActions:Button({
	Title = "Rejoin",
	Justify = "Center",
	Icon = "solar:refresh-bold",
	Callback = function()
		WindUI:Notify({ Title = "Rejoining...", Content = "Teleporting to server...", Duration = 2 })
		task.delay(1, function()
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId)
		end)
	end,
})

ServerActions:Button({
	Title = "Server Hop",
	Justify = "Center",
	Icon = "solar:map-arrow-square-bold",
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
AvatarTab:Section({ Title = "🎭 Morph Avatar", Desc = "Change your appearance to look like other players" })
AvatarTab:Space({ Columns = 0.5 })

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

-- ══════════════════════════════════════════════════════════════════
-- 📋 COPY AVATAR BY USERNAME
-- ══════════════════════════════════════════════════════════════════
AvatarTab:Section({ Title = "📋 Clone by Username", Desc = "Enter any Roblox username to clone their avatar" })
AvatarTab:Space({ Columns = 0.5 })

-- Store username input
local avatarUsernameInput = ""

AvatarTab:Input({
	Title = "Roblox Username",
	Desc = "Enter any Roblox username to clone their avatar",
	Placeholder = "Enter username...",
	Callback = function(text)
		avatarUsernameInput = text
	end,
})

AvatarTab:Button({
	Title = "🎭 Clone Username Avatar",
	Desc = "Clone the avatar of the entered username",
	Callback = function()
		if avatarUsernameInput == "" then
			WindUI:Notify({ Title = "Error", Content = "Please enter a username first!", Duration = 2 })
			return
		end

		-- Fetch User ID from username
		WindUI:Notify({ Title = "Fetching", Content = "Looking up " .. avatarUsernameInput .. "...", Duration = 1 })
		
		task.spawn(function()
			local success, userId = pcall(function()
				return Players:GetUserIdFromNameAsync(avatarUsernameInput)
			end)

			if not success or not userId then
				WindUI:Notify({ Title = "Error", Content = "User '" .. avatarUsernameInput .. "' not found!", Duration = 3 })
				return
			end

			-- Get the character and humanoid
			local character = LocalPlayer.Character
			local humanoid = character and character:FindFirstChild("Humanoid")
			if not humanoid then
				WindUI:Notify({ Title = "Error", Content = "No character found!", Duration = 2 })
				return
			end

			-- Load Description from user ID
			local descSuccess, desc = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(userId)
			end)

			if not descSuccess or not desc then
				WindUI:Notify({ Title = "Error", Content = "Failed to load avatar for " .. avatarUsernameInput, Duration = 3 })
				return
			end

			-- Clear existing accessories for clean morph
			for _, obj in ipairs(character:GetChildren()) do
				if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or obj:IsA("Accessory") or obj:IsA("BodyColors") then
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

			-- Apply the description
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
					Title = "✅ Avatar Cloned!", 
					Content = "Successfully cloned " .. avatarUsernameInput .. "'s avatar!", 
					Duration = 3 
				})
			else
				WindUI:Notify({ Title = "Error", Content = "Failed to apply avatar", Duration = 2 })
			end
		end)
	end,
})

AvatarTab:Divider()


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
	Icon = "solar:cloud-bold",
})
task.wait(0.1)

SkyBoxTab:Section({ Title = "🌌 Skybox Changer", Desc = "Modify the atmosphere and environment visuals" })
SkyBoxTab:Space({ Columns = 0.5 })

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

SkyBoxTab:Button({
	Title = "Reset Skybox",
	Desc = "Restore original game atmosphere",
	Icon = "solar:refresh-bold",
	Callback = function()
		ApplySkybox("Default")
		WindUI:Notify({ Title = "Skybox", Content = "Restored Default", Duration = 2 })
	end,
})

SkyBoxTab:Divider()

for _, skyName in ipairs(skyboxList) do
	SkyBoxTab:Toggle({
		Title = skyName,
		Desc = "Enable " .. skyName .. " atmosphere",
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
	Icon = "solar:folder-open-bold",
})
task.wait(0.1)

-- ══════════════════════════════════════════════════════════════════
-- 👤 PLAYER TAB
-- ══════════════════════════════════════════════════════════════════
local ToolsTab = Window:Tab({
	Title = "Player",
	Icon = "solar:bolt-bold",
})
task.wait(0.1)

-- 🏃 MOVEMENT
ToolsTab:Section({ Title = "🏃 Player Settings", Desc = "Modify your character's physical properties" })
ToolsTab:Space({ Columns = 0.5 })

ToolsTab:Slider({
	Title = "WalkSpeed",
	Desc = "Running speed (Default: 16)",
	IsTooltip = true,
	Step = 1,
	Value = { Min = 16, Max = 200, Default = 16 },
	Icons = {
		From = "solar:walking-bold",
		To = "solar:running-bold",
	},
	Callback = function(v)
		Config.WalkSpeed = v
		local hum = GetHumanoid()
		if hum then
			hum.WalkSpeed = v
		end
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- 🎯 ADMIN ESP SYSTEM (File-level scope for toggle callbacks)
-- Includes: Box ESP, Chams, Health Bar
-- ══════════════════════════════════════════════════════════════════
local AdminESPDrawings = {}
local AdminESPTrackedPlayers = {}
local AdminESPRenderConnection = nil
local AdminESPToggle = nil
local ESPGeneration = 0 -- Increments each toggle, async callbacks check this to avoid stale updates
local ESPHandlerConnections = {} -- Store PlayerAdded/CharacterAdded connections for cleanup
local AdminChatConnections = {} -- Store chat monitoring connections for cleanup

-- Check if Drawing API exists
local HasDrawingAPI = pcall(function()
	local test = Drawing.new("Line")
	pcall(function() test:Remove() end)
	pcall(function() test.Visible = false end)
end)
if not HasDrawingAPI then
	warn("[ESP] ⚠️ Drawing API not available — Box ESP will be disabled, only Chams/Highlight will work")
end

local espOk, espErr = pcall(function()

local function CreateDrawing(drawType, props)
	if not HasDrawingAPI then return nil end
	local ok, drawing = pcall(function()
		local d = Drawing.new(drawType)
		for k, v in pairs(props) do
			d[k] = v
		end
		return d
	end)
	return ok and drawing or nil
end

local function CleanupPlayerDrawings(player)
	local data = AdminESPDrawings[player]
	if data then
		for _, obj in pairs(data) do
			if typeof(obj) ~= "Color3" and typeof(obj) ~= "string" and type(obj) ~= "string" then
				pcall(function() obj:Remove() end)
			end
		end
		AdminESPDrawings[player] = nil
	end
end

local function CleanupAllDrawings()
	for player, _ in pairs(AdminESPDrawings) do
		CleanupPlayerDrawings(player)
	end
	AdminESPDrawings = {}
	AdminESPTrackedPlayers = {}
end

local function CreateESPDrawingsForPlayer(player, color)
	CleanupPlayerDrawings(player)

	local data = {}
	-- Transparency: 0 = fully visible, 1 = invisible

	-- 1. Box ESP (outline)
	data.boxOutline = CreateDrawing("Square", {
		Visible = false,
		Color = color,
		Thickness = 2,
		Filled = false,
		Transparency = 0,
	})

	-- 3. Box ESP (fill - semi transparan)
	data.boxFill = CreateDrawing("Square", {
		Visible = false,
		Color = color,
		Thickness = 1,
		Filled = true,
		Transparency = 0.8,
	})

	-- 4. Name Label (Drawing text di atas box)
	data.nameLabel = CreateDrawing("Text", {
		Visible = false,
		Color = color,
		Size = 14,
		Center = true,
		Outline = true,
		OutlineColor = Color3.fromRGB(0, 0, 0),
		Font = 2,
		Text = "",
		Transparency = 0,
	})

	-- 5. Health Bar Background
	data.healthBarBg = CreateDrawing("Square", {
		Visible = false,
		Color = Color3.fromRGB(40, 40, 40),
		Thickness = 1,
		Filled = true,
		Transparency = 0.3,
	})

	-- 7. Health Bar
	data.healthBar = CreateDrawing("Square", {
		Visible = false,
		Color = Color3.fromRGB(0, 255, 0),
		Thickness = 1,
		Filled = true,
		Transparency = 0,
	})

	data.color = color
	AdminESPDrawings[player] = data
end

local function UpdateESPDrawings()
	local Camera = workspace.CurrentCamera
	if not Camera then return end

	for player, data in pairs(AdminESPDrawings) do
		local char = player.Character
		local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
		local head = char and char:FindFirstChild("Head")
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")

		if not char or not root or not head or not humanoid or humanoid.Health <= 0 then
			-- Hide all drawings
			for k, obj in pairs(data) do
				if typeof(obj) ~= "Color3" and typeof(obj) ~= "string" and type(obj) ~= "string" then
					pcall(function() obj.Visible = false end)
				end
			end
			continue
		end

		-- Calculate screen positions
		local rootPos, rootOnScreen = Camera:WorldToViewportPoint(root.Position)
		local headPos = Camera:WorldToViewportPoint((head.CFrame * CFrame.new(0, 1.5, 0)).Position)
		local footPos = Camera:WorldToViewportPoint((root.CFrame * CFrame.new(0, -3, 0)).Position)

		if not rootOnScreen or rootPos.Z < 0 then
			for k, obj in pairs(data) do
				if typeof(obj) ~= "Color3" and typeof(obj) ~= "string" and type(obj) ~= "string" then
					pcall(function() obj.Visible = false end)
				end
			end
			continue
		end

		-- Calculate 2D box dimensions
		local boxHeight = math.abs(headPos.Y - footPos.Y)
		local boxWidth = boxHeight * 0.6
		local boxX = rootPos.X - boxWidth / 2
		local boxY = headPos.Y

		local espColor = data.color or Color3.fromRGB(255, 0, 0)

		-- 1. Box ESP Outline
		if data.boxOutline then
			pcall(function()
				data.boxOutline.Visible = Settings.AdminESP and Settings.AdminESPBox
				data.boxOutline.Position = Vector2.new(boxX, boxY)
				data.boxOutline.Size = Vector2.new(boxWidth, boxHeight)
				data.boxOutline.Color = espColor
			end)
		end

		-- 3. Box ESP Fill
		if data.boxFill then
			pcall(function()
				data.boxFill.Visible = Settings.AdminESP and Settings.AdminESPBox
				data.boxFill.Position = Vector2.new(boxX, boxY)
				data.boxFill.Size = Vector2.new(boxWidth, boxHeight)
				data.boxFill.Color = espColor
			end)
		end

		-- 4. Name Label
		if data.nameLabel then
			pcall(function()
				local reason = AdminESPTrackedPlayers[player] or "Admin"
				data.nameLabel.Visible = Settings.AdminESP
				data.nameLabel.Position = Vector2.new(rootPos.X, boxY - 16)
				data.nameLabel.Text = "🛡️ " .. player.DisplayName .. " [" .. reason .. "]"
				data.nameLabel.Color = espColor
			end)
		end

		-- 5. Health Bar BG
		if data.healthBarBg then
			pcall(function()
				local barWidth = 3
				data.healthBarBg.Visible = Settings.AdminESP and Settings.AdminESPBox
				data.healthBarBg.Position = Vector2.new(boxX - barWidth - 2, boxY)
				data.healthBarBg.Size = Vector2.new(barWidth, boxHeight)
			end)
		end

		-- 7. Health Bar
		if data.healthBar then
			pcall(function()
				local barWidth = 3
				local healthPct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
				local barHeight = boxHeight * healthPct
				local barY = boxY + (boxHeight - barHeight)
				data.healthBar.Visible = Settings.AdminESP and Settings.AdminESPBox
				data.healthBar.Position = Vector2.new(boxX - barWidth - 2, barY)
				data.healthBar.Size = Vector2.new(barWidth, barHeight)
				-- Color: green -> yellow -> red
				if healthPct > 0.5 then
					data.healthBar.Color = Color3.fromRGB(
						math.floor(255 * (1 - healthPct) * 2),
						255,
						0
					)
				else
					data.healthBar.Color = Color3.fromRGB(
						255,
						math.floor(255 * healthPct * 2),
						0
					)
				end
			end)
		end
	end
end

local function HideAllDrawings()
	for player, data in pairs(AdminESPDrawings) do
		for k, obj in pairs(data) do
			if typeof(obj) ~= "Color3" and typeof(obj) ~= "string" and type(obj) ~= "string" then
				pcall(function() obj.Visible = false end)
			end
		end
	end
end

local function StartESPRenderLoop()
	if AdminESPRenderConnection then return end
	AdminESPRenderConnection = RunService.RenderStepped:Connect(function()
		if Settings.AdminESP then
			UpdateESPDrawings()
		else
			-- Sembunyikan semua drawing saat AdminESP OFF
			HideAllDrawings()
		end
	end)
end

local function StopESPRenderLoop()
	if AdminESPRenderConnection then
		AdminESPRenderConnection:Disconnect()
		AdminESPRenderConnection = nil
	end
end

-- Admin detection function (synchronous — basic checks)
local function isPlayerAdmin(player)
	if player == LocalPlayer or not player.Parent then return false, "" end
	
	-- 1. Check Game Owner
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true, "Owner"
	end
	
	-- 2. Check Group Rank/Role (game creator group)
	if game.CreatorType == Enum.CreatorType.Group then
		local s, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		if s and rank and rank >= 100 then
			return true, (rank >= 255 and "Owner" or rank >= 200 and "High Admin ("..rank..")" or "Admin ("..rank..")")
		end
		
		local s2, role = pcall(function() return player:GetRoleInGroup(game.CreatorId) end)
		if s2 and role then
			local lr = role:lower()
			if lr:find("admin") or lr:find("mod") or lr:find("staff") or lr:find("owner") or lr:find("dev") or lr:find("manager") or lr:find("founder") then
				return true, "Staff ("..role..")"
			end
		end
	end
	
	-- 3. Check Backpack Tools
	local bp = player:FindFirstChild("Backpack")
	if bp then
		for _, t in pairs(bp:GetChildren()) do
			if t:IsA("Tool") then
				local tn = t.Name:lower()
				if tn:find("admin") or tn:find("ban") or tn:find("kick") or tn:find("mod") or tn:find("jail") or tn:find("mute") then
					return true, "Admin Tool ("..t.Name..")"
				end
			end
		end
	end
	
	-- 4. Check Character equipped tools
	local char = player.Character
	if char then
		for _, t in pairs(char:GetChildren()) do
			if t:IsA("Tool") then
				local tn = t.Name:lower()
				if tn:find("admin") or tn:find("ban") or tn:find("kick") or tn:find("mod") then
					return true, "Admin Tool ("..t.Name..")"
				end
			end
		end
	end
	
	return false, ""
end

-- ══════════════════════════════════════════════════════════════════
-- 🔍 AUTO-SCAN: Scan game ModuleScripts for admin UserID lists
-- Runs ONCE, results cached. Works across any game.
-- ══════════════════════════════════════════════════════════════════
local ScannedAdminUserIds = {} -- {[userId] = "reason"}
_G._ScannedAdminUserIds = ScannedAdminUserIds -- Share with Tools.lua & other modules
local ModuleScanCompleted = false

local function scanTableForAdminData(tbl, depth, source)
	if depth > 4 or not tbl or type(tbl) ~= "table" then return end
	
	-- Pattern 1: { [userId] = "RoleName" } (seperti AdminUserIds)
	for k, v in pairs(tbl) do
		if type(k) == "number" and k > 1000000 and type(v) == "string" then
			local vl = v:lower()
			if vl:find("owner") or vl:find("admin") or vl:find("mod") or vl:find("staff") or vl:find("dev") or vl:find("super") then
				ScannedAdminUserIds[k] = "ModuleScan: " .. v .. " (" .. source .. ")"
			end
		end
	end
	
	-- Pattern 2: Roles array { { name="Admin", userIds={123,456} }, ... }
	if type(tbl) == "table" then
		local name = tbl.name or tbl.Name or tbl.role or tbl.Role
		local uids = tbl.userIds or tbl.UserIds or tbl.userId or tbl.UserId or tbl.users or tbl.Users or tbl.ids or tbl.Ids
		
		if type(name) == "string" and type(uids) == "table" then
			local nl = name:lower()
			if nl:find("owner") or nl:find("admin") or nl:find("mod") or nl:find("staff") or nl:find("dev") or nl:find("super") then
				local exclude = nl:find("guest") or nl:find("player") or nl:find("member") or nl:find("default")
				if not exclude then
					for _, uid in pairs(uids) do
						if type(uid) == "number" and uid > 1000000 then
							ScannedAdminUserIds[uid] = "ModuleScan: " .. name .. " (" .. source .. ")"
						end
					end
				end
			end
		end
	end
	
	-- Pattern 3: { AdminUserIds = {...}, AdminUsernames = {...} }
	for key, val in pairs(tbl) do
		if type(key) == "string" then
			local kl = key:lower()
			if (kl:find("admin") or kl:find("owner") or kl:find("staff") or kl:find("mod")) and 
			   (kl:find("user") or kl:find("id") or kl:find("list") or kl:find("white")) then
				if type(val) == "table" then
					scanTableForAdminData(val, depth + 1, source .. "/" .. key)
				end
			end
			-- Scan Roles/Ranks tables recursively
			if kl == "roles" or kl == "ranks" or kl == "admins" or kl == "staff" or kl == "permissions" then
				if type(val) == "table" then
					for _, item in pairs(val) do
						if type(item) == "table" then
							scanTableForAdminData(item, depth + 1, source .. "/" .. key)
						end
					end
				end
			end
		end
	end
end

-- STRICT module name filter to prevent side effects from requiring game modules
local function isModuleNameSafe(name)
	local nl = name:lower()
	
	-- BLOCK known dangerous/system modules (UI, controllers, handlers, etc.)
	local blocklist = {
		"mainmodule", "client", "server", "handler", "controller", "manager",
		"service", "system", "engine", "page", "screen", "gui", "ui",
		"utility", "util", "animate", "camera", "input", "movement",
		"player", "character", "chat", "sound", "effect", "particle",
		"weapon", "tool", "vehicle", "shop", "store", "menu", "hud",
		"loading", "lobby", "game", "match", "round", "spawn", "teleport",
		"leaderstats", "leaderboard", "inventory", "quest", "mission",
		"notification", "popup", "dialog", "prompt", "button", "frame",
		"tween", "spring", "signal", "event", "remote", "network",
		"physics", "ray", "hitbox", "combat", "damage", "health",
		"fullscreen", "search", "render", "display", "layout", "theme",
		"home", "history", "profile", "account", "friend", "party",
	}
	for _, blocked in ipairs(blocklist) do
		if nl:find(blocked, 1, true) then
			return false
		end
	end
	
	-- ALLOW only modules containing specific admin-related keywords
	local allowlist = {"admin", "owner", "staff", "role", "rank", "overhead", 
					   "nametag", "whitelist", "permission"}
	for _, allowed in ipairs(allowlist) do
		if nl:find(allowed, 1, true) then
			return true
		end
	end
	
	-- Allow generic "Config"/"Settings" ONLY if that's basically the whole name
	if nl == "config" or nl == "settings" or nl == "configuration" or 
	   nl == "constants" or nl == "defines" then
		return true
	end
	
	return false
end

local function scanReplicatedModules()
	if ModuleScanCompleted then return end
	ModuleScanCompleted = true
	
	warn("[ESP] 🔍 Scanning game modules for admin data...")
	local scannedCount = 0
	local skippedCount = 0
	local foundCount = 0
	
	-- Locations accessible from client
	local scanLocations = {}
	pcall(function() table.insert(scanLocations, {game:GetService("ReplicatedStorage"), "ReplicatedStorage"}) end)
	pcall(function() table.insert(scanLocations, {game:GetService("ReplicatedFirst"), "ReplicatedFirst"}) end)
	pcall(function() table.insert(scanLocations, {game:GetService("StarterGui"), "StarterGui"}) end)
	pcall(function() table.insert(scanLocations, {game:GetService("StarterPack"), "StarterPack"}) end)
	pcall(function() table.insert(scanLocations, {game:GetService("StarterPlayer"), "StarterPlayer"}) end)
	
	for _, loc in ipairs(scanLocations) do
		local container, containerName = loc[1], loc[2]
		if not container then continue end
		
		-- Find all ModuleScripts (max 2 levels deep to keep it fast)
		local modules = {}
		pcall(function()
			for _, child in pairs(container:GetChildren()) do
				if child:IsA("ModuleScript") then
					table.insert(modules, {child, containerName .. "/" .. child.Name})
				end
				pcall(function()
					for _, subChild in pairs(child:GetChildren()) do
						if subChild:IsA("ModuleScript") then
							table.insert(modules, {subChild, containerName .. "/" .. child.Name .. "/" .. subChild.Name})
						end
						pcall(function()
							for _, sub2 in pairs(subChild:GetChildren()) do
								if sub2:IsA("ModuleScript") then
									table.insert(modules, {sub2, containerName .. "/" .. child.Name .. "/" .. subChild.Name .. "/" .. sub2.Name})
								end
							end
						end)
					end
				end)
			end
		end)
		
		-- Only require modules with safe/relevant names
		for _, modInfo in ipairs(modules) do
			local moduleScript, path = modInfo[1], modInfo[2]
			
			-- SAFETY CHECK: Only require modules whose name suggests config/admin data
			if not isModuleNameSafe(moduleScript.Name) then
				skippedCount = skippedCount + 1
				continue
			end
			
			scannedCount = scannedCount + 1
			
			local ok, result = pcall(function()
				return require(moduleScript)
			end)
			
			if ok and type(result) == "table" then
				local prevCount = 0
				for _ in pairs(ScannedAdminUserIds) do prevCount = prevCount + 1 end
				
				pcall(function()
					scanTableForAdminData(result, 0, path)
				end)
				
				local newCount = 0
				for _ in pairs(ScannedAdminUserIds) do newCount = newCount + 1 end
				
				if newCount > prevCount then
					warn("[ESP] ✅ Found admin data in: " .. path .. " (+" .. (newCount - prevCount) .. " UserIDs)")
				end
			end
		end
	end
	
	for _ in pairs(ScannedAdminUserIds) do foundCount = foundCount + 1 end
	-- Remove self from scan results
	ScannedAdminUserIds[LocalPlayer.UserId] = nil
	
	warn("[ESP] 📊 Module scan: " .. scannedCount .. " scanned, " .. skippedCount .. " skipped (unsafe), " .. foundCount .. " admin UserIDs found")
end

-- ══════════════════════════════════════════════════════════════════
-- 🏷️ OVERHEAD SCAN: Check existing BillboardGuis/nametags for admin labels
-- ══════════════════════════════════════════════════════════════════
local function scanPlayerOverhead(player)
	local char = player.Character
	if not char then return false, "" end
	
	local adminKeywords = {"admin", "owner", "mod", "staff", "dev", "super admin", "developer", "manager", "founder", "operator"}
	
	-- Scan all BillboardGuis on the character
	for _, obj in pairs(char:GetDescendants()) do
		local ok, result = pcall(function()
			if obj:IsA("TextLabel") or obj:IsA("TextButton") then
				local txt = obj.Text:lower()
				for _, keyword in ipairs(adminKeywords) do
					if txt:find(keyword, 1, true) then
						-- Make sure it's in a BillboardGui (overhead tag)
						local parent = obj.Parent
						while parent and parent ~= char do
							if parent:IsA("BillboardGui") then
								return true, "Overhead: " .. obj.Text:sub(1, 40)
							end
							parent = parent.Parent
						end
					end
				end
			end
			return false, ""
		end)
		if ok and result then return true, result end
	end
	
	-- Also check Head for direct BillboardGui
	local head = char:FindFirstChild("Head")
	if head then
		for _, bb in pairs(head:GetChildren()) do
			if bb:IsA("BillboardGui") then
				for _, label in pairs(bb:GetDescendants()) do
					local ok2, res2 = pcall(function()
						if label:IsA("TextLabel") or label:IsA("TextButton") then
							local txt = label.Text:lower()
							for _, keyword in ipairs(adminKeywords) do
								if txt:find(keyword, 1, true) then
									return true, "Overhead: " .. label.Text:sub(1, 40)
								end
							end
						end
						return false, ""
					end)
					if ok2 and res2 then return true, res2 end
				end
			end
		end
	end
	
	return false, ""
end

-- ══════════════════════════════════════════════════════════════════
-- 🏷️ ATTRIBUTE SCAN: Check player Attributes for admin flags
-- ══════════════════════════════════════════════════════════════════
local function scanPlayerAttributes(player)
	-- Check common admin-related attributes
	local adminAttrs = {"IsAdmin", "isAdmin", "Admin", "admin", "IsOwner", "isOwner", "IsMod", "isMod", 
						"IsStaff", "isStaff", "Role", "role", "Rank", "rank", "AdminLevel", "adminLevel",
						"Permission", "permission", "IsDev", "isDev"}
	
	for _, attrName in ipairs(adminAttrs) do
		local ok, val = pcall(function() return player:GetAttribute(attrName) end)
		if ok and val ~= nil then
			if type(val) == "boolean" and val == true then
				return true, "Attribute: " .. attrName .. " = true"
			elseif type(val) == "string" then
				local vl = val:lower()
				if vl:find("admin") or vl:find("owner") or vl:find("mod") or vl:find("staff") or vl:find("dev") then
					return true, "Attribute: " .. attrName .. " = " .. val
				end
			elseif type(val) == "number" and val >= 1 then
				local al = attrName:lower()
				if al:find("admin") or al:find("level") or al:find("rank") or al:find("permission") then
					return true, "Attribute: " .. attrName .. " = " .. tostring(val)
				end
			end
		end
	end
	
	return false, ""
end

-- ══════════════════════════════════════════════════════════════════
-- 🌐 HTTP API: Check player's groups — ONLY game's creator group
-- Only checks the game's group, NOT random/personal groups
-- ══════════════════════════════════════════════════════════════════
local function asyncCheckPlayerAdmin(player, callback)
	task.spawn(function()
		-- Only useful if game is owned by a Group
		local gameGroupId = nil
		if game.CreatorType == Enum.CreatorType.Group then
			gameGroupId = game.CreatorId
		end
		
		if not gameGroupId then
			-- User-owned game: owner already detected by isPlayerAdmin
			callback(false, "")
			return
		end
		
		local success, data = pcall(function()
			local HttpService = game:GetService("HttpService")
			local response = game:HttpGet("https://groups.roblox.com/v1/users/" .. player.UserId .. "/groups/roles")
			return HttpService:JSONDecode(response)
		end)
		
		if success and data and data.data then
			for _, group in ipairs(data.data) do
				local gId = group.group and group.group.id
				local rank = group.role and group.role.rank or 0
				local roleName = group.role and group.role.name or ""
				
				-- ONLY check the game's creator group
				if gId == gameGroupId and rank >= 100 then
					local reason = group.group.name .. " (Rank " .. rank .. ": " .. roleName .. ")"
					callback(true, reason)
					return
				end
			end
		end
		callback(false, "")
	end)
end

-- ══════════════════════════════════════════════════════════════════
-- 🎯 FULL ADMIN SCAN: Combines ALL detection methods
-- Order: ModuleScan → Sync checks → Attributes → Overhead → HTTP API
-- ══════════════════════════════════════════════════════════════════
local function fullAdminScan(player, onDetected)
	if player == LocalPlayer or not player.Parent then return end
	
	-- 0. Run module scan once (cached after first run)
	pcall(scanReplicatedModules)
	
	-- 1. Check ModuleScan results (instant, cached)
	if ScannedAdminUserIds[player.UserId] then
		onDetected(ScannedAdminUserIds[player.UserId])
		return
	end
	
	-- 2. Quick sync checks (Owner, Group, Tools)
	local isA, reason = isPlayerAdmin(player)
	if isA then
		onDetected(reason)
		return
	end
	
	-- 3. Check Attributes (instant)
	local attrFound, attrReason = scanPlayerAttributes(player)
	if attrFound then
		onDetected(attrReason)
		return
	end
	
	-- 4. Check Overhead/BillboardGui tags (instant, needs character)
	if player.Character then
		local ohFound, ohReason = scanPlayerOverhead(player)
		if ohFound then
			onDetected(ohReason)
			return
		end
	end
	
	-- 5. Async HTTP API check (slowest, runs last)
	asyncCheckPlayerAdmin(player, function(found, httpReason)
		if found and player.Parent then
			onDetected(httpReason)
		end
	end)
end

-- UpdateESP: Apply full ESP (Chams + Billboard + Drawing) to admin player
local function UpdateESP(player, show, reason)
	if not player then warn("[ESP] UpdateESP: player is nil") return end
	
	warn("[ESP] UpdateESP called: " .. player.Name .. " | show=" .. tostring(show) .. " | reason=" .. tostring(reason))
	
	-- Clean old ESP (in-world) — pcall for safety, only if character exists
	local char = player.Character
	if char then
		pcall(function()
			local oldESP = char:FindFirstChild("AdminESP")
			if oldESP then oldESP:Destroy() end
			local oldHighlight = char:FindFirstChild("AdminHighlight")
			if oldHighlight then oldHighlight:Destroy() end
		end)
	end
	
	-- If turning OFF, just cleanup everything and return immediately (NO waiting)
	if not show then
		CleanupPlayerDrawings(player)
		AdminESPTrackedPlayers[player] = nil
		return
	end
	
	-- Only wait for character when SHOWING ESP
	if not char then
		warn("[ESP] " .. player.Name .. " has no character, waiting...")
		char = player.CharacterAdded:Wait()
		task.wait(0.5)
		char = player.Character
		if not char then warn("[ESP] " .. player.Name .. " still no character, aborting") return end
	end
	
	-- Color based on reason
	local color = Color3.fromRGB(255, 0, 0) -- Red default
	local reasonLower = reason:lower()
	if reasonLower:find("owner") then color = Color3.fromRGB(255, 215, 0)
	elseif reasonLower:find("staff") then color = Color3.fromRGB(255, 100, 50)
	elseif reasonLower:find("mod") then color = Color3.fromRGB(255, 50, 150)
	end
	
	-- 1. Chams / Highlight (through walls) — wrapped in pcall
	if Settings.AdminESPChams then
		local ok, err = pcall(function()
			local highlight = Instance.new("Highlight")
			highlight.Name = "AdminHighlight"
			highlight.FillColor = color
			highlight.FillTransparency = 0.4
			highlight.OutlineColor = Color3.new(1, 1, 1)
			highlight.OutlineTransparency = 0
			-- DepthMode may not exist in all executors
			pcall(function()
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			end)
			highlight.Parent = char
			warn("[ESP] ✅ Highlight applied to " .. player.Name)
		end)
		if not ok then warn("[ESP] ❌ Highlight error: " .. tostring(err)) end
	end
	
	-- 2. Billboard tag (name + role above head) — wrapped in pcall
	local ok2, err2 = pcall(function()
		local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char
		local bb = Instance.new("BillboardGui")
		bb.Name = "AdminESP"
		bb.AlwaysOnTop = true
		bb.Size = UDim2.new(0, 250, 0, 50)
		bb.StudsOffset = Vector3.new(0, 4, 0)
		bb.Parent = head
		
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "🛡️ " .. player.DisplayName .. "\n" .. reason
		label.TextColor3 = color
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextScaled = false
		label.Parent = bb
		warn("[ESP] ✅ Billboard applied to " .. player.Name)
	end)
	if not ok2 then warn("[ESP] ❌ Billboard error: " .. tostring(err2)) end

	-- 3. Create Drawing-based ESP (Tracer Line + Box + Distance)
	AdminESPTrackedPlayers[player] = reason
	
	local ok3, err3 = pcall(function()
		CreateESPDrawingsForPlayer(player, color)
		StartESPRenderLoop()
		warn("[ESP] ✅ Drawing ESP created for " .. player.Name)
	end)
	if not ok3 then warn("[ESP] ❌ Drawing ESP error: " .. tostring(err3)) end
	
	warn("[ESP] ✅ Full ESP applied to " .. player.Name .. " (" .. reason .. ")")
end

-- Monitor chat for admin commands (defined AFTER UpdateESP to fix Lua scope)
-- AdminChatConnections declared earlier (before DisconnectESPHandlers) for proper scope
local function monitorPlayerChat(player)
	if player == LocalPlayer then return end
	
	local chatGen = ESPGeneration -- Capture generation at time of connection
	local conn = player.Chatted:Connect(function(msg)
		if ESPGeneration ~= chatGen then return end -- Stale connection
		if not Settings.AdminESP then return end
		local lowMsg = msg:lower()
		local adminCmds = {";kick", ";ban", ";jail", ";mute", ";warn", ";fly", ";god",
						   ":kick", ":ban", ":jail", ":mute", ":warn", ":fly", ":god",
						   "!kick", "!ban", "!jail", "!mute", "!warn"}
		
		for _, cmd in ipairs(adminCmds) do
			if lowMsg:find(cmd, 1, true) then
				if not AdminESPTrackedPlayers[player] then
					warn("[ESP] 💬 Admin command detected from " .. player.Name .. ": " .. msg)
					UpdateESP(player, true, "Chat Cmd: " .. msg:sub(1, 25))
				end
				break
			end
		end
	end)
	table.insert(AdminChatConnections, conn)
end

-- Disconnect all ESP handler connections (for cleanup when ESP is turned off)
local function DisconnectESPHandlers()
	for _, conn in ipairs(ESPHandlerConnections) do
		pcall(function() conn:Disconnect() end)
	end
	ESPHandlerConnections = {}
	
	-- Also disconnect chat monitoring connections
	if AdminChatConnections then
		for _, conn in ipairs(AdminChatConnections) do
			pcall(function() conn:Disconnect() end)
		end
		AdminChatConnections = {}
	end
end

-- Start the ESP handler (scan players & connect events)
local function StartESPHandler()
	DisconnectESPHandlers() -- Clean old connections first
	local myGen = ESPGeneration -- Capture current generation
	
	local function scanAndApplyESP(p)
		if ESPGeneration ~= myGen then return end -- Stale, ESP was toggled
		if not Settings.AdminESP then return end
		if AdminESPTrackedPlayers[p] then return end -- Already tracked
		
		warn("[ESP] 🔍 Scanning: " .. p.Name)
		
		fullAdminScan(p, function(reason)
			-- CRITICAL: Check generation AGAIN — async callback might fire after ESP was turned off
			if ESPGeneration ~= myGen then return end
			if not Settings.AdminESP then return end
			if not p.Parent then return end
			
			warn("[ESP] 🎯 Admin found: " .. p.Name .. " → " .. reason)
			if p.Character then
				UpdateESP(p, true, reason)
			else
				-- Wait for character but with generation check
				task.spawn(function()
					local c = p.CharacterAdded:Wait()
					task.wait(0.5)
					if ESPGeneration ~= myGen then return end
					if not Settings.AdminESP then return end
					if p.Character then
						UpdateESP(p, true, reason)
					end
				end)
			end
		end)
	end
	
	local function onPlayerAdded(p)
		if p == LocalPlayer then return end
		if ESPGeneration ~= myGen then return end
		
		-- Scan when character loads
		local charConn = p.CharacterAdded:Connect(function(c)
			task.wait(1.5)
			if ESPGeneration ~= myGen then return end
			if not Settings.AdminESP then return end
			-- Re-apply ESP on respawn for already-tracked admins
			if AdminESPTrackedPlayers[p] then
				UpdateESP(p, true, AdminESPTrackedPlayers[p])
			else
				scanAndApplyESP(p)
			end
		end)
		table.insert(ESPHandlerConnections, charConn)
		
		-- Monitor chat for admin commands
		monitorPlayerChat(p)
		
		-- Initial scan if character already exists
		if p.Character then
			task.spawn(function()
				task.wait(0.5)
				if ESPGeneration ~= myGen then return end
				scanAndApplyESP(p)
			end)
		end
	end
	
	local addedConn = Players.PlayerAdded:Connect(function(p)
		if ESPGeneration ~= myGen then return end
		onPlayerAdded(p)
	end)
	table.insert(ESPHandlerConnections, addedConn)
	
	local removingConn = Players.PlayerRemoving:Connect(function(p)
		CleanupPlayerDrawings(p)
		AdminESPTrackedPlayers[p] = nil
	end)
	table.insert(ESPHandlerConnections, removingConn)
	
	-- Scan existing players
	for _, p in pairs(Players:GetPlayers()) do
		if ESPGeneration ~= myGen then break end
		onPlayerAdded(p)
	end
end

-- 👁️ VISUALS
ToolsTab:Section({ Title = "👁️ Visuals", Desc = "Visual assistance and player highlighting" })
AdminESPToggle = ToolsTab:Toggle({
	Title = "Admin ESP",
	Desc = "Deteksi & highlight Admin/Mod/Staff (HTTP + Group + Tools + Chat)",
	Value = Settings.AdminESP,
	Callback = function(state)
		Settings.AdminESP = state
		SaveSettings()
		
		-- ALWAYS increment generation to invalidate all pending async callbacks
		ESPGeneration = ESPGeneration + 1
		
		if state then
			warn("[ESP] 🟢 Admin ESP ENABLED — scanning " .. (#Players:GetPlayers() - 1) .. " players...")
			StartESPHandler()
		else
			warn("[ESP] 🔴 Admin ESP DISABLED — cleaning up")
			
			-- 1. Disconnect ALL handler connections (PlayerAdded, CharacterAdded, etc.)
			DisconnectESPHandlers()
			
			-- 2. Sembunyikan semua Drawing dulu (instant)
			HideAllDrawings()
			
			-- 3. Hapus in-world ESP (Highlight + BillboardGui) dari SEMUA player
			for _, p in pairs(Players:GetPlayers()) do
				pcall(function()
					local c = p.Character
					if c then
						local oldESP = c:FindFirstChild("AdminESP")
						if oldESP then oldESP:Destroy() end
						local oldHL = c:FindFirstChild("AdminHighlight")
						if oldHL then oldHL:Destroy() end
					end
				end)
			end
			
			-- 4. Hapus semua Drawing objects & clear tracked players
			CleanupAllDrawings()
			
			-- 5. Stop render loop
			StopESPRenderLoop()
			
			warn("[ESP] ✅ Cleanup selesai — generation: " .. ESPGeneration)
		end
	end,
})

ToolsTab:Toggle({
	Title = "┗ Box ESP",
	Desc = "Kotak 2D di sekitar admin (+ Health Bar)",
	Value = Settings.AdminESPBox,
	Callback = function(state)
		Settings.AdminESPBox = state
		SaveSettings()
		-- Langsung sembunyikan box/health jika OFF
		if not state then
			for _, data in pairs(AdminESPDrawings) do
				if data.boxOutline then pcall(function() data.boxOutline.Visible = false end) end
				if data.boxFill then pcall(function() data.boxFill.Visible = false end) end
				if data.healthBarBg then pcall(function() data.healthBarBg.Visible = false end) end
				if data.healthBar then pcall(function() data.healthBar.Visible = false end) end
			end
		end
	end,
})

ToolsTab:Toggle({
	Title = "┗ Chams (Highlight)",
	Desc = "Warna transparan tembus dinding pada admin",
	Value = Settings.AdminESPChams,
	Callback = function(state)
		Settings.AdminESPChams = state
		SaveSettings()
		if not state then
			-- Langsung hapus semua Highlight saat dimatikan
			for p, _ in pairs(AdminESPTrackedPlayers) do
				pcall(function()
					local c = p.Character
					if c then
						local hl = c:FindFirstChild("AdminHighlight")
						if hl then hl:Destroy() end
					end
				end)
			end
		else
			-- Buat ulang Highlight untuk semua tracked admin
			if Settings.AdminESP then
				for p, reason in pairs(AdminESPTrackedPlayers) do
					if p and p.Parent and p.Character then
						pcall(function()
							-- Hapus highlight lama dulu
							local oldHL = p.Character:FindFirstChild("AdminHighlight")
							if oldHL then oldHL:Destroy() end
							
							-- Buat highlight baru
							local color = Color3.fromRGB(255, 0, 0)
							local rl = reason:lower()
							if rl:find("owner") then color = Color3.fromRGB(255, 215, 0)
							elseif rl:find("staff") then color = Color3.fromRGB(255, 100, 50)
							elseif rl:find("mod") then color = Color3.fromRGB(255, 50, 150) end
							
							local highlight = Instance.new("Highlight")
							highlight.Name = "AdminHighlight"
							highlight.FillColor = color
							highlight.FillTransparency = 0.4
							highlight.OutlineColor = Color3.new(1, 1, 1)
							highlight.OutlineTransparency = 0
							pcall(function() highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
							highlight.Parent = p.Character
						end)
					end
				end
			end
		end
	end,
})

end) -- End of ESP pcall block
if not espOk then
	warn("[ESP] ❌ ADMIN ESP SYSTEM ERROR: " .. tostring(espErr))
	warn("[ESP] ❌ ESP system disabled, but script continues normally")
	-- Buat toggle dummy supaya safeSet tidak error
	if not AdminESPToggle then
		pcall(function()
			ToolsTab:Section({ Title = "👁️ Visuals", Desc = "Visual assistance and player highlighting" })
			AdminESPToggle = ToolsTab:Toggle({
				Title = "Admin ESP (ERROR)",
				Desc = "ESP crashed: " .. tostring(espErr):sub(1, 50),
				Value = false,
				Callback = function() end,
			})
		end)
	end
end

ToolsTab:Divider()

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

ToolsTab:Divider()

-- 🚀 TELEPORT
ToolsTab:Section({ Title = "🚀 Teleportation", Desc = "Quickly travel across the map" })
ToolsTab:Space({ Columns = 0.5 })

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
ToolsTab:Section({ Title = "✈️ Flight Mode", Desc = "Take to the skies with advanced flight controls" })
ToolsTab:Space({ Columns = 0.5 })

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
	IsTooltip = true,
	Step = 5,
	Value = { Min = 10, Max = 300, Default = 50 },
	Icons = {
		From = "solar:wind-bold",
		To = "solar:rocket-bold",
	},
	Callback = function(v)
		FlyState.speed = v
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

	-- ═══════════════════════════════════════════════════════════════
	-- FULL PRECISION MODE: Draw ALL points for accurate path
	-- Uses progressive loading for very long recordings
	-- ═══════════════════════════════════════════════════════════════
	local totalPoints = #positions
	local filteredPositions = {}
	local lastPos = nil
	local minDistance = 0.3 -- REDUCED: Much more precise (was 1.5)
	
	-- No limit on points - include all positions with minimum distance filter
	for i = 1, totalPoints do
		local posData = positions[i]
		-- Include point if it's far enough from last point (prevents overlapping)
		if not lastPos or (posData.pos - lastPos).Magnitude > minDistance then
			posData.progress = (i - 1) / math.max(1, totalPoints - 1)
			table.insert(filteredPositions, posData)
			lastPos = posData.pos
		end
	end

	-- Always include last position for complete path
	local lastPosData = positions[totalPoints]
	lastPosData.progress = 1
	if #filteredPositions > 0 and (filteredPositions[#filteredPositions].pos - lastPosData.pos).Magnitude > 0.1 then
		table.insert(filteredPositions, lastPosData)
	end
	
	-- Log stats (dev mode only)
	if DEV_MODE then
		warn(string.format("[PathViz] Total frames: %d, Drawn points: %d (%.1f%% coverage)", 
			totalPoints, #filteredPositions, (#filteredPositions / totalPoints) * 100))
	end

	-- Draw nodes and beams using PROGRESSIVE RENDERING
	-- Renders in chunks to prevent lag on long recordings
	local nodeInstances = {}
	local prevPart = nil
	local CHUNK_SIZE = 50 -- Render 50 nodes per frame to prevent lag
	local totalFiltered = #filteredPositions
	
	-- Use task.spawn for progressive rendering on long paths
	task.spawn(function()
		for i, posData in ipairs(filteredPositions) do
			-- Check if path was cleared mid-render
			if not pathVisualsFolder or not pathVisualsFolder.Parent then
				return
			end
			
			local pos = posData.pos
			local progress = posData.progress
			local color = GetGradientColor(progress)

			-- Create node (smaller neon spheres for precision)
			local node = Instance.new("Part")
			node.Name = "PathNode_" .. i
			node.Size = Vector3.new(0.25, 0.25, 0.25) -- Smaller for precision
			node.Shape = Enum.PartType.Ball
			node.Color = color
			node.Material = Enum.Material.Neon
			node.Transparency = 0.15
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

					local beam = Instance.new("Part")
					beam.Name = "PathBeam_" .. i
					beam.Size = Vector3.new(0.08, 0.08, distance) -- Thinner for precision
					beam.Shape = Enum.PartType.Block
					beam.Color = color:Lerp(GetGradientColor(filteredPositions[i - 1].progress), 0.5)
					beam.Material = Enum.Material.Neon
					beam.Transparency = 0.3
					beam.Anchored = true
					beam.CanCollide = false
					beam.CanQuery = false
					beam.CastShadow = false
					beam.CFrame = CFrame.lookAt(midpoint, pos)
					beam.Parent = beamsFolder
				end
			end

			prevPart = node
			
			-- Yield every CHUNK_SIZE nodes to prevent lag
			if i % CHUNK_SIZE == 0 then
				task.wait()
			end
		end
		
		-- Render complete notification (dev mode)
		if DEV_MODE then
			warn("[PathViz] Rendering complete: " .. totalFiltered .. " nodes drawn")
		end
	end)

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

local CloudParagraph = nil
local function UpdateCloudUI()
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

	if CloudParagraph then
		local count = #_G.StarshipCloud.DropdownValues
		if count == 1 and _G.StarshipCloud.DropdownValues[1] == "No cloud recordings" then
			count = 0
		end
		pcall(function()
			CloudParagraph:SetTitle("☁️ Cloud Recordings (" .. count .. ")")
		end)
	end
end

CloudParagraph = ListMapTab:Paragraph({
	Title = "☁️ Cloud Recordings (Loading...)",
	Desc = "Recordings uploaded by Dev/Owner",
})

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
	
	-- Update UI (Dropdown and Paragraph Title)
	UpdateCloudUI()
end)

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

				-- Update UI dynamically
				UpdateCloudUI()

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
			if DEV_MODE then warn(errMsg) end

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
					if DEV_MODE then warn("[Chunked] Max retries reached for chunk " .. chunkIndex .. " - giving up") end
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
	-- STOP CURRENT PLAYBACK: If switching to different recording
	-- This ensures old recording stops before new one loads
	-- ═══════════════════════════════════════════════════════════════
	local wasPlayingBefore = PlaybackState.isPlaying
	if wasPlayingBefore then
		if StarSpacePlaybackLoaded and _G.StarSpace and _G.StarSpace.StopPlayback then
			_G.StarSpace.StopPlayback()
		elseif StopPlayback then
			StopPlayback()
		end
		-- Reset playback state
		PlaybackState.isPlaying = false
		PlaybackState.isPaused = false
		PlaybackState.currentFrame = 0
	end
	
	-- Track if we're switching recordings (for notification later) - use _G so LoadCloudRecordingDirect can access
	_G.StarshipCloud.IsSwitchingRecording = wasPlayingBefore or (MiniPlayerGui ~= nil)

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
			
			-- Show "Recording Switched" notification if switching from another recording
			if _G.StarshipCloud.IsSwitchingRecording then
				WindUI:Notify({ Title = "📂 Recording Switched", Content = _G.StarshipCloud.RecordingName .. " ready - Press Play!", Duration = 2 })
			end

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
			
			-- Show "Recording Switched" notification if switching from another recording
			if _G.StarshipCloud.IsSwitchingRecording then
				WindUI:Notify({ Title = "📂 Recording Switched", Content = _G.StarshipCloud.RecordingName .. " ready - Press Play!", Duration = 2 })
			end
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
			
			-- Show "Recording Switched" notification if switching from another recording
			if _G.StarshipCloud.IsSwitchingRecording then
				WindUI:Notify({ Title = "📂 Recording Switched", Content = _G.StarshipCloud.RecordingName .. " ready - Press Play!", Duration = 2 })
			end

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
local PathVisToggle, RespawnEndToggle -- Global references for sync

-- Pre-load Icons to prevent delay/pop-in
local MiniPlayerIcons = {
	Play = "rbxthumb://type=Asset&id=12099513436&w=150&h=150",
	Pause = "rbxthumb://type=Asset&id=14219414401&w=150&h=150",
	Loop = "rbxthumb://type=Asset&id=106505959193975&w=150&h=150",
	Moonlight = "rbxthumb://type=Asset&id=101922194979644&w=150&h=150",
	Path = "rbxthumb://type=Asset&id=485491709&w=150&h=150",
	Respawn = "rbxthumb://type=Asset&id=11318174695&w=150&h=150",
	Close = "rbxthumb://type=Asset&id=81869729496131&w=150&h=150",
	Plus = "rbxthumb://type=Asset&id=77458026579005&w=150&h=150",
	Minus = "rbxthumb://type=Asset&id=136825236896355&w=150&h=150",
}
task.spawn(function()
	local toLoad = {}
	for _, url in pairs(MiniPlayerIcons) do table.insert(toLoad, url) end
	pcall(function() ContentProvider:PreloadAsync(toLoad) end)
end)

local function ToggleMiniPlayer(state)
	if state then
		if MiniPlayerGui then return end
		local success, cGui = pcall(function() return game:GetService("CoreGui") end)
		local parent = (success and cGui) or LocalPlayer:WaitForChild("PlayerGui")
		local screen = Instance.new("ScreenGui")
		screen.Name, screen.ResetOnSpawn, screen.IgnoreGuiInset = "StarshipMiniApple", false, true
		screen.Parent = parent
		
		-- Smaller, more compact size (Reduceed further as requested)
		local mainFrame = Instance.new("Frame")
		mainFrame.Name, mainFrame.Size, mainFrame.Position = "MiniPlayerMain", UDim2.fromOffset(280, 90), UDim2.new(0.5, -140, 0.78, 0)
		mainFrame.BackgroundColor3, mainFrame.BorderSizePixel, mainFrame.Active, mainFrame.Draggable = Color3.fromRGB(0, 0, 0), 0, true, true
		mainFrame.ClipsDescendants = true
		mainFrame.Parent = screen
		Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 14)
		
		-- Game Image Background - FIXED (Most Compatible Method)
		local bgImage = Instance.new("ImageLabel")
		bgImage.Name = "BackgroundImage"
		bgImage.Size = UDim2.new(1.2, 0, 1.2, 0) -- Slightly larger to allow for better cropping
		bgImage.Position = UDim2.fromScale(0.5, 0.5)
		bgImage.AnchorPoint = Vector2.new(0.5, 0.5)
		-- Using Asset type with PlaceId (Standard across all Roblox games & executors)
		bgImage.Image = "rbxthumb://type=Asset&id=" .. game.PlaceId .. "&w=150&h=150"
		bgImage.ImageTransparency = 0.45 -- Balanced for a background look
		bgImage.BackgroundTransparency = 1
		bgImage.ScaleType = Enum.ScaleType.Crop -- Fills the window naturally
		bgImage.ZIndex = 1
		bgImage.Parent = mainFrame
		
		-- Dark overlay for readability
		local overlay = Instance.new("Frame")
		overlay.Name = "Overlay"
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		overlay.BackgroundTransparency = 0.4 -- Balanced darkness
		overlay.BorderSizePixel = 0
		overlay.ZIndex = 2
		overlay.Parent = mainFrame
		
		-- Animation
		mainFrame.Size = UDim2.fromOffset(0, 0)
		mainFrame.Position = UDim2.new(0.5, 0, 0.78, 0)
		TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(280, 90),
			Position = UDim2.new(0.5, -140, 0.78, 0),
		}):Play()

		-- Title with stroke for clarity
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size, title.Position = UDim2.new(1, -50, 0, 22), UDim2.fromOffset(12, 8)
		title.BackgroundTransparency = 1
		title.Text = _G.StarshipCloud.RecordingName or "No Recording"
		title.TextColor3 = Color3.new(1, 1, 1)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.ZIndex = 3
		title.Parent = mainFrame
		
		local titleStroke = Instance.new("UIStroke", title)
		titleStroke.Color = Color3.fromRGB(0, 0, 0)
		titleStroke.Thickness = 1
		titleStroke.Transparency = 0.3
		
		-- Subtitle with Speed Display
		local artist = Instance.new("TextLabel")
		artist.Name = "Subtitle"
		artist.Size, artist.Position = UDim2.new(1, -50, 0, 14), UDim2.fromOffset(12, 28)
		artist.BackgroundTransparency = 1
		artist.Text = "STARSHIP CORE (1.0x)"
		artist.TextColor3 = Color3.fromRGB(180, 180, 180)
		artist.Font = Enum.Font.Gotham
		artist.TextSize = 10
		artist.TextXAlignment = Enum.TextXAlignment.Left
		artist.ZIndex = 3
		artist.Parent = mainFrame
		
		-- Buttons Area Adjusted for Compact Look
		local btnCenterY = 65 -- Relative to 90 Height
		
		local function createBtn(iconId, sz, xPos, cb, isIcon, textLabel)
			local b = Instance.new("TextButton")
			b.Size, b.Position, b.AnchorPoint = UDim2.fromOffset(sz, sz), UDim2.new(xPos, 0, 0, btnCenterY), Vector2.new(0.5, 0.5)
			b.BackgroundTransparency = isIcon and 0.2 or 0
			b.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
			b.Text = textLabel or ""
			b.TextColor3 = Color3.new(1,1,1)
			b.Font = Enum.Font.GothamBold
			b.TextSize = 14
			b.ZIndex = 4 -- Above overlay
			b.Parent = mainFrame
			
			if isIcon then 
				Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
			else
				Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0) -- Circular for Play/Speed
				if not textLabel then b.BackgroundColor3 = Color3.fromRGB(255, 255, 255) end
			end
			
			if iconId and iconId ~= "" then
				local img = Instance.new("ImageLabel")
				img.Name = "Icon"
				img.Size = UDim2.fromScale(0.6, 0.6)
				img.Position = UDim2.fromScale(0.5, 0.5)
				img.AnchorPoint = Vector2.new(0.5, 0.5)
				img.BackgroundTransparency = 1
				img.Image = iconId
				img.ImageColor3 = isIcon and Color3.new(1, 1, 1) or Color3.fromRGB(20, 20, 22)
				img.ZIndex = 5
				img.Parent = b
			end
			
			b.MouseButton1Click:Connect(cb)
			return b
		end
		
		local play = createBtn(MiniPlayerIcons.Play, 42, 0.5, function()
			if not selectedFile then return end
			if PlaybackState.isPlaying and not PlaybackState.isPaused then
				if _G.StarSpace and _G.StarSpace.PausePlayback then _G.StarSpace.PausePlayback() else PausePlayback() end
			else
				if _G.StarSpace and _G.StarSpace.LoadRecording then
					if PlaybackState.isPlaying and PlaybackState.isPaused then
						if _G.StarSpace.ResumePlayback then _G.StarSpace.ResumePlayback() else _G.StarSpace.TogglePlayback() end
					else _G.StarSpace.LoadRecording(selectedFile) end
				else PlayRecording(selectedFile) end
			end
		end)
		
		-- Function to update speed globally and sync UI
		local function ChangeSpeed(delta)
			local current = PlaybackState.speed or 1
			local newVal = math.clamp(math.floor((current + delta) * 10 + 0.5) / 10, 0.1, 3)
			PlaybackState.speed = newVal
			if _G.StarSpace and _G.StarSpace.SetSpeed then _G.StarSpace.SetSpeed(newVal) end
			
			WindUI:Notify({ Title = "Speed", Content = "Speed: " .. tostring(newVal) .. "x", Duration = 0.5 })
		end
		
		local speedDown = createBtn(MiniPlayerIcons.Minus, 28, 0.35, function() ChangeSpeed(-0.1) end, true)
		local speedUp = createBtn(MiniPlayerIcons.Plus, 28, 0.65, function() ChangeSpeed(0.1) end, true)
		
		local pathBtn = createBtn(MiniPlayerIcons.Path, 30, 0.09, function()
			local newState = not (isPathVisualsEnabled or false)
			isPathVisualsEnabled = newState
			if _G.StarSpace and _G.StarSpace.SetShowPath then _G.StarSpace.SetShowPath(newState) end
			if newState then if PlaybackState.frameData then DrawPath(PlaybackState.frameData) end else ClearPath() end
			if PathVisToggle then
				pcall(function()
					if PathVisToggle.SetValue then PathVisToggle:SetValue(newState) end
					if PathVisToggle.Set then PathVisToggle:Set(newState) end
				end)
			end
		end, true)

		local moonBtn = createBtn(MiniPlayerIcons.Moonlight, 30, 0.22, function()
			local newState = not (PlaybackState.isMoonwalk or false)
			PlaybackState.isMoonwalk = newState
			if _G.StarSpace and _G.StarSpace.SetMoonwalk then _G.StarSpace.SetMoonwalk(newState) end
		end, true)
		
		local loopBtn = createBtn(MiniPlayerIcons.Loop, 30, 0.78, function()
			local newState = not (PlaybackState.isLooping or false)
			PlaybackState.isLooping = newState
			if _G.StarSpace and _G.StarSpace.SetLooping then _G.StarSpace.SetLooping(newState) end
		end, true)

		local respawnBtn = createBtn(MiniPlayerIcons.Respawn, 30, 0.91, function()
			local newState = not (PlaybackState.respawnOnEnd or false)
			PlaybackState.respawnOnEnd = newState
			if _G.StarSpace and _G.StarSpace.SetRespawnOnEnd then _G.StarSpace.SetRespawnOnEnd(newState) end
			if RespawnEndToggle then
				pcall(function()
					if RespawnEndToggle.SetValue then RespawnEndToggle:SetValue(newState) end
					if RespawnEndToggle.Set then RespawnEndToggle:Set(newState) end
				end)
			end
		end, true)

		local closeX = Instance.new("ImageButton")
		closeX.Name, closeX.Size, closeX.Position = "CloseBtn", UDim2.fromOffset(20, 20), UDim2.new(1, -28, 0, 8)
		closeX.BackgroundTransparency, closeX.Image = 1, MiniPlayerIcons.Close
		closeX.ImageColor3 = Color3.fromRGB(255, 80, 80)
		closeX.ZIndex = 5
		closeX.Parent = mainFrame
		closeX.MouseButton1Click:Connect(function()
			if MiniPlayerToggle then MiniPlayerToggle:Set(false) else ToggleMiniPlayer(false) end
		end)
		closeX.MouseEnter:Connect(function() closeX.ImageColor3 = Color3.new(1, 1, 1) end)
		closeX.MouseLeave:Connect(function() closeX.ImageColor3 = Color3.fromRGB(150, 150, 150) end)

		local function fmt(s) return string.format("%d:%02d", math.floor(s/60), math.floor(s%60)) end
		
		-- Cache icon references to avoid FindFirstChild every frame
		local playIcon = play and play:FindFirstChild("Icon")
		local pathIcon = pathBtn and pathBtn:FindFirstChild("Icon")
		local moonIcon = moonBtn and moonBtn:FindFirstChild("Icon")
		local loopIcon = loopBtn and loopBtn:FindFirstChild("Icon")
		local respawnIcon = respawnBtn and respawnBtn:FindFirstChild("Icon")
		
		-- Throttled update loop - only update every 5 frames for better mobile performance
		local frameCounter = 0
		table.insert(MiniPlayerAnimations, RunService.Heartbeat:Connect(function()
			if not mainFrame or not mainFrame.Parent then return end
			
			frameCounter = frameCounter + 1
			if frameCounter < 10 then return end -- Skip 9 out of 10 frames (even less frequent now)
			frameCounter = 0
			
			pcall(function()
				local isPlaying = (PlaybackState.isPlaying and not PlaybackState.isPaused)
				if playIcon then
					playIcon.Image = isPlaying and MiniPlayerIcons.Pause or MiniPlayerIcons.Play
				end
				
				-- Dynamic Color Sync - Unique colors for each feature
				local inactiveImg = Color3.fromRGB(200, 200, 200)
				local inactiveBg = Color3.fromRGB(45, 45, 50)
				
				-- Path: Yellow
				if pathIcon then
					pathIcon.ImageColor3 = isPathVisualsEnabled and Color3.fromRGB(255, 200, 0) or inactiveImg
					pathBtn.BackgroundColor3 = isPathVisualsEnabled and Color3.fromRGB(150, 120, 0) or inactiveBg
				end
				
				-- Moonwalk: Purple
				if moonIcon then
					moonIcon.ImageColor3 = PlaybackState.isMoonwalk and Color3.fromRGB(180, 100, 255) or inactiveImg
					moonBtn.BackgroundColor3 = PlaybackState.isMoonwalk and Color3.fromRGB(100, 50, 150) or inactiveBg
				end
				
				-- Loop: Green
				if loopIcon then
					loopIcon.ImageColor3 = PlaybackState.isLooping and Color3.fromRGB(0, 255, 120) or inactiveImg
					loopBtn.BackgroundColor3 = PlaybackState.isLooping and Color3.fromRGB(0, 120, 60) or inactiveBg
				end
				
				-- Respawn: Red
				if respawnIcon then
					respawnIcon.ImageColor3 = PlaybackState.respawnOnEnd and Color3.fromRGB(255, 80, 80) or inactiveImg
					respawnBtn.BackgroundColor3 = PlaybackState.respawnOnEnd and Color3.fromRGB(150, 40, 40) or inactiveBg
				end

				if _G.StarshipCloud.RecordingName and title then title.Text = _G.StarshipCloud.RecordingName end
				
				-- Update Speed Display in Subtitle
				if artist then
					local s = PlaybackState.speed or 1.0
					artist.Text = string.format("STARSHIP CORE (%.1fx)", s)
				end
				
				-- Timeline update removed for performance
			end)
		end))
		
		MiniPlayerGui = screen
		-- Tag with StarshipID for proper cleanup on re-execution
		pcall(function() screen:SetAttribute("StarshipID", STARSHIP_ID) end)
	else
		-- Reset all features when closing Mini Player
		isPathVisualsEnabled = false
		PlaybackState.isMoonwalk = false
		PlaybackState.isLooping = false
		PlaybackState.respawnOnEnd = false
		
		-- Sync with Playback Engine
		if _G.StarSpace then
			if _G.StarSpace.SetShowPath then _G.StarSpace.SetShowPath(false) end
			if _G.StarSpace.SetMoonwalk then _G.StarSpace.SetMoonwalk(false) end
			if _G.StarSpace.SetLooping then _G.StarSpace.SetLooping(false) end
			if _G.StarSpace.SetRespawnOnEnd then _G.StarSpace.SetRespawnOnEnd(false) end
		end
		
		-- Clear Path Visuals
		ClearPath()
		
		-- Sync Main UI Toggles if they exist
		pcall(function()
			if PathVisToggle then
				if PathVisToggle.SetValue then PathVisToggle:SetValue(false)
				elseif PathVisToggle.Set then PathVisToggle:Set(false) end
			end
			if RespawnEndToggle then
				if RespawnEndToggle.SetValue then RespawnEndToggle:SetValue(false)
				elseif RespawnEndToggle.Set then RespawnEndToggle:Set(false) end
			end
			-- Add other toggles if needed (Moonwalk, Loop usually in main UI too)
			if MoonwalkToggle then
				if MoonwalkToggle.SetValue then MoonwalkToggle:SetValue(false)
				elseif MoonwalkToggle.Set then MoonwalkToggle:Set(false) end
			end
			if LoopToggle then
				if LoopToggle.SetValue then LoopToggle:SetValue(false)
				elseif LoopToggle.Set then LoopToggle:Set(false) end
			end
		end)

		for _, c in ipairs(MiniPlayerAnimations) do if c then pcall(function() c:Disconnect() end) end end
		MiniPlayerAnimations = {}
		if MiniPlayerGui then
			local mf = MiniPlayerGui:FindFirstChild("MiniPlayerMain")
			if mf and mf.Parent then
				local out = TweenService:Create(mf, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
					Size = UDim2.fromOffset(0, 0),
					Position = UDim2.new(0.5, 0, 0.75, 0),
					BackgroundTransparency = 1
				})
				out:Play()
				out.Completed:Connect(function() if MiniPlayerGui then pcall(function() MiniPlayerGui:Destroy() end); MiniPlayerGui = nil end end)
			else pcall(function() MiniPlayerGui:Destroy() end); MiniPlayerGui = nil end
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
		-- Return true if mini player was already active (for auto-play feature)
		return MiniPlayerGui ~= nil
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

	-- Path Visualization and Respawn On End are in Mini Player buttons

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

	-- Anti-AFK Feature (Always ON)
	local antiAfkConnection = nil
	local isAntiAfkOn = true -- Force to true
	local AFK_DisabledConns = {}
	_G.StarshipAntiTabDetect = true -- Force to true

	local function setAfkState(state)
		-- We ignore the state and always keep it true
		isAntiAfkOn = true 
		_G.StarshipAntiTabDetect = true
		
		-- Logic to enable protection
		pcall(function()
			if DS_ApplyPrivacyHooks then DS_ApplyPrivacyHooks() end
		end)
		
		if not antiAfkConnection then
			local vu = game:GetService("VirtualUser")
			antiAfkConnection = LocalPlayer.Idled:Connect(function()
				vu:CaptureController()
				vu:ClickButton2(Vector2.new())
			end)
		end

		-- Forcefully disable existing focus-loss connections & STORE THEM
		pcall(function()
			AFK_DisabledConns = {}
			if getconnections then
				for _, c in pairs(getconnections(UserInputService.WindowFocusReleased)) do
					if c.Enabled then
						c:Disable()
						table.insert(AFK_DisabledConns, c)
					end
				end
				for _, c in pairs(getconnections(UserInputService.WindowFocused)) do
					if c.Enabled then
						c:Disable()
						table.insert(AFK_DisabledConns, c)
					end
				end
			end
		end)

		-- Background Protection Loop (Wiggle + Attribute Lock)
		task.spawn(function()
			while isAntiAfkOn and antiAfkConnection do
				pcall(function()
					local char = LocalPlayer.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						hum.Jump = true
					end
				end)

				for i = 1, 60 do
					if not isAntiAfkOn or not antiAfkConnection then
						break
					end
					pcall(function()
						if LocalPlayer:GetAttribute("AFK") then
							LocalPlayer:SetAttribute("AFK", false)
						end
						if LocalPlayer:GetAttribute("IsAFK") then
							LocalPlayer:SetAttribute("IsAFK", false)
						end
					end)
					task.wait(1)
				end
			end
		end)
	end

	-- Always start Anti-AFK
	task.defer(function() setAfkState(true) end)

	PlaybackSection:Toggle({
		Title = "Anti-AFK (Fixed ON)",
		Desc = "Permanently enabled for maximum protection",
		Value = true,
		Callback = function(state)
			-- Force it back to true if they try to turn it off
			if not state then
				task.wait(0.1)
				setAfkState(true)
				WindUI:Notify({ Title = "Anti-AFK", Content = "Anti-AFK is permanently active!", Duration = 2 })
			end
		end,
	})

	-- ══════════════════════════════════════════════════════════════════
	-- 🛡️ BYPASS ADMIN FEATURE (Enhanced)
	-- ══════════════════════════════════════════════════════════════════
	local isBypassAdminOn = false
	local bypassAdminConnections = {}
	local AdminAlertGui = nil
	local AdminESPConnections = {}

	-- Action function (Handles Alert vs Kick)
	local function HandleAdminDetection(player, reason)
		if Settings.AutoLeaveAdmin then
			-- Immediate kick for safety (StarSpace style)
			LocalPlayer:Kick("🛡️ Admin Detected: " .. player.Name .. "\nReason: " .. reason .. "\n\n(Auto-Leave for Safety)")
		else
			-- Show custom alert (MobileUI style)
			ShowAdminAlert(player.Name, reason)
		end
	end

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

	-- Fungsi utama pengecekan admin (FULL detection — sama dengan ESP system)
	local function CheckForAdmin(player)
		if player == LocalPlayer or not player.Parent then
			return
		end

		local isAdmin = false
		local reason = ""

		-- 0. Run ModuleScan once (cached) — scan AdminConfig, OverheadConfig, etc.
		pcall(scanReplicatedModules)

		-- 1. Cek ModuleScan results (instant, cached)
		if ScannedAdminUserIds and ScannedAdminUserIds[player.UserId] then
			isAdmin = true
			reason = "ModuleScan: " .. tostring(ScannedAdminUserIds[player.UserId])
		end

		-- 2. Cek Game Creator
		if not isAdmin and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
			isAdmin = true
			reason = "Game Owner"
		end

		-- 3. Cek Group Rank (untuk game grup)
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

		-- 4. Cek Player Attributes (IsAdmin, Role, Rank, etc.)
		if not isAdmin then
			local attrOk, attrFound, attrReason = pcall(scanPlayerAttributes, player)
			if attrOk and attrFound then
				isAdmin = true
				reason = attrReason
			end
		end

		-- 5. Cek Overhead BillboardGui tags
		if not isAdmin and player.Character then
			local ohOk, ohFound, ohReason = pcall(scanPlayerOverhead, player)
			if ohOk and ohFound then
				isAdmin = true
				reason = ohReason
			end
		end

		-- 6. Cek Admin Tools di Backpack
		if not isAdmin then
			task.spawn(function()
				task.wait(1)
				if not player.Parent then return end
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
								HandleAdminDetection(player, "Admin Tool: " .. tool.Name)
								return
							end
						end
					end
				end
			end)
		end

		-- 7. Async HTTP API (HANYA grup game ini, bukan semua grup)
		if not isAdmin then
			task.spawn(function()
				local gameGroupId = nil
				if game.CreatorType == Enum.CreatorType.Group then
					gameGroupId = game.CreatorId
				end
				
				if not gameGroupId then return end
				if not player.Parent then return end
				
				local success, roles = pcall(function()
					local HttpService = game:GetService("HttpService")
					local response =
						game:HttpGet("https://groups.roblox.com/v1/users/" .. player.UserId .. "/groups/roles")
					return HttpService:JSONDecode(response)
				end)

				if success and roles and roles.data then
					for _, group in ipairs(roles.data) do
						local gId = group.group and group.group.id
						local rank = group.role and group.role.rank or 0
						if gId == gameGroupId and rank >= 100 then
							HandleAdminDetection(
								player,
								"Group API: " .. group.group.name .. " (Rank " .. rank .. ": " .. (group.role.name or "") .. ")"
							)
							return
						end
					end
				end
			end)
		end

		-- 8. Monitor Chat untuk Command Admin
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
				HandleAdminDetection(player, "Admin Command: " .. msg:sub(1, 50))
			end
		end)
		table.insert(bypassAdminConnections, chatConnection)

		-- Jika sudah terdeteksi admin dari awal
		if isAdmin then
			HandleAdminDetection(player, reason)
		end
	end

	PlaybackSection:Toggle({
		Title = "🚪 Auto Leave (Admin)",
		Desc = "Automatically leave the server if an admin is detected",
		Value = Settings.AutoLeaveAdmin,
		Callback = function(state)
			Settings.AutoLeaveAdmin = state
			SaveSettings()
		end,
	})

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
-- 📱 DEVICE SPOOF TAB
-- Ported from StarSpace.lua — Full device spoofing system
-- ══════════════════════════════════════════════════════════════════
local DeviceSpoofTab = Window:Tab({
	Title = "Device Spoof",
	Icon = "solar:smartphone-bold",
})
RunService.Heartbeat:Wait()

-- Load Device Spoof content asynchronously to avoid blocking
task.spawn(function()
task.wait(0.5) -- Let UI settle first
local dsOk, dsErr = pcall(function()

DeviceSpoofTab:Section({ Title = "📱 Device Spoof System", Desc = "Spoof your device type to appear as PC, Mobile, or Console" })
DeviceSpoofTab:Space({ Columns = 0.5 })

DeviceSpoofTab:Paragraph({
	Title = "💡 Tips",
	Desc = "• Pilih 'PC' untuk menampilkan ikon 💻 di atas kepala\\n"
		.. "• Pilih 'Mobile' untuk menampilkan ikon 📱 (terlihat sebagai pemain HP)\\n"
		.. "• Pilih 'Console' untuk menampilkan ikon 🎮 (terlihat sebagai pemain Xbox/PS)\\n"
		.. "• Respawn setelah mengaktifkan untuk hasil terbaik\\n"
		.. "• Pengaturan tersimpan otomatis & diterapkan saat rejoin\\n"
		.. "• Berfungsi di sebagian besar game yang menggunakan ikon device overhead",
})
DeviceSpoofTab:Space({ Columns = 0.5 })

-- ═══ Device Spoof State ═══
local DS_SpoofName = ""
local DS_DeviceSpoof = "Default"
local DS_SpoofEnabled = false
local DS_HooksApplied = false
local DS_OriginalValues = {}
local DS_SpoofToggleRef = nil

-- Persistent settings
local DS_SETTINGS_FILE = "StarshipMobile/spoof_settings.json"

local function DS_SaveSettings()
	pcall(function()
		if not writefile then return end
		if isfolder and not isfolder("StarshipMobile") then makefolder("StarshipMobile") end
		writefile(DS_SETTINGS_FILE, game:GetService("HttpService"):JSONEncode({
			DeviceSpoof = DS_DeviceSpoof,
			SpoofEnabled = DS_SpoofEnabled,
			SpoofName = DS_SpoofName,
		}))
	end)
end

local function DS_ClearSettings()
	pcall(function()
		if isfile and isfile(DS_SETTINGS_FILE) then delfile(DS_SETTINGS_FILE) end
	end)
end

-- Load saved settings
pcall(function()
	if isfile and isfile(DS_SETTINGS_FILE) then
		local raw = readfile(DS_SETTINGS_FILE)
		local data = game:GetService("HttpService"):JSONDecode(raw)
		if data then
			if data.DeviceSpoof and data.DeviceSpoof ~= "Default" then DS_DeviceSpoof = data.DeviceSpoof end
			if data.SpoofEnabled then DS_SpoofEnabled = true end
			if data.SpoofName and data.SpoofName ~= "" then DS_SpoofName = data.SpoofName end
		end
	end
end)

-- ═══ Per-Game Icon Database ═══
local DS_GameIconSets = {
	["16624148448"] = { Name = "MT Yahayukk", PC = "rbxassetid://16624148448", Mobile = "rbxassetid://16624149840", Console = "rbxassetid://16624150956" },
	["94089970073947"] = { Name = "MT Moonlight", PC = "rbxassetid://106290076073871", Mobile = "rbxassetid://94089970073947", Console = "rbxassetid://139663456027187" },
	["106290076073871"] = { Name = "MT Moonlight", PC = "rbxassetid://106290076073871", Mobile = "rbxassetid://94089970073947", Console = "rbxassetid://139663456027187" },
	["139663456027187"] = { Name = "MT Moonlight", PC = "rbxassetid://106290076073871", Mobile = "rbxassetid://94089970073947", Console = "rbxassetid://139663456027187" },
	["110487074518360"] = { Name = "MT Velora", PC = "rbxassetid://133663694484547", Mobile = "rbxassetid://110487074518360", Console = "rbxassetid://6034509537" },
	["6034789893"] = { Name = "NameTag Game", PC = "rbxassetid://6034789893", Mobile = "rbxassetid://6034848733", Console = "rbxassetid://6034509537" },
	["12684119225"] = { Name = "User Requested", PC = "rbxassetid://12684119225", Mobile = "rbxassetid://13021320268", Console = "rbxassetid://6034509537" },
}

local DS_DefaultIcons = { PC = "rbxassetid://6034509993", Mobile = "rbxassetid://6034509012", Console = "rbxassetid://6034509537" }

-- Reverse lookup: asset -> icon set
local DS_AssetToIconSet = {}
for _, iconSet in pairs(DS_GameIconSets) do
	DS_AssetToIconSet[iconSet.PC:lower()] = iconSet
	DS_AssetToIconSet[iconSet.Mobile:lower()] = iconSet
	DS_AssetToIconSet[iconSet.Console:lower()] = iconSet
end

local DS_DeviceAssets = {
	PC = { Emojis = {"💻","🖥️","🖥","⌨️","🖱️"}, Keywords = {"pc","computer","desktop","windows","keyboard"}, TargetEmoji = "💻" },
	Mobile = { Emojis = {"📱","📲","🤳"}, Keywords = {"mobile","phone","touch","ios","android","iphone","ipad","tablet"}, TargetEmoji = "📱" },
	Console = { Emojis = {"🎮","🕹️","🎲"}, Keywords = {"console","xbox","playstation","gamepad","controller","ps4","ps5"}, TargetEmoji = "🎮" },
}

local DS_AllDeviceEmojis = {}
for _, data in pairs(DS_DeviceAssets) do
	for _, emoji in ipairs(data.Emojis) do DS_AllDeviceEmojis[emoji] = true end
end

local DS_DeviceDetectionPatterns = {
	Names = {"deviceicon","deviceindicator","platformicon","activetype","inputicon","activeicon"},
	Parents = {"overhead","_overhead","overheadui","billboard","nametag","playertag","headtag","toprow","line1","deviceframe","logoframe"},
}
local DS_UIBlacklist = {"starspace","xan","rayfield","kavo","orion","ventox","wally","infinite","catalyst","linoria","sense","vape","lunar","solara","arctic","starship","windui"}

local function DS_containsKeyword(str, keywords)
	if not str then return false end
	str = str:lower()
	for _, kw in ipairs(keywords) do if str:find(kw) then return true end end
	return false
end

local function DS_isBlacklistedUI(obj)
	local current = obj
	for i = 1, 10 do
		if not current then break end
		local name = current.Name:lower()
		for _, bl in ipairs(DS_UIBlacklist) do if name:find(bl) then return true end end
		if current:IsA("ScreenGui") and current.Parent and current.Parent.Name == "CoreGui" then
			if not (obj:FindFirstAncestorOfClass("BillboardGui") or obj:FindFirstAncestorOfClass("SurfaceGui")) then return true end
		end
		current = current.Parent
	end
	return false
end

local function DS_isOwnedByLocalPlayer(obj)
	local lp = LocalPlayer
	if not lp then return false end
	local myChar, myPG = lp.Character, lp:FindFirstChild("PlayerGui")
	if myPG and obj:IsDescendantOf(myPG) then return true end
	if myChar and (obj:IsDescendantOf(myChar) or obj == myChar) then return true end
	local rootGui = obj:FindFirstAncestorOfClass("BillboardGui") or obj:FindFirstAncestorOfClass("SurfaceGui")
	if rootGui and rootGui.Adornee and myChar and rootGui.Adornee:IsDescendantOf(myChar) then return true end
	return false
end

local function DS_isDeviceRelated(obj)
	if not DS_isOwnedByLocalPlayer(obj) then return false end
	if DS_isBlacklistedUI(obj) then return false end
	if (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and obj.Image ~= "" then
		if DS_AssetToIconSet[obj.Image:lower()] then return true end
		for id, _ in pairs(DS_GameIconSets) do if obj.Image:find(id, 1, true) then return true end end
	end
	if DS_containsKeyword(obj.Name, DS_DeviceDetectionPatterns.Names) then return true end
	local pCheck = obj.Parent
	for i = 1, 8 do
		if not pCheck then break end
		local pName = pCheck.Name:lower()
		if DS_containsKeyword(pName, DS_DeviceDetectionPatterns.Parents) then return true end
		if pName:find("playerlist") or pName:find("leaderboard") then return true end
		pCheck = pCheck.Parent
	end
	local headAnc = obj:FindFirstAncestor("Head")
	if headAnc and headAnc:IsA("BasePart") then
		local parent = obj.Parent
		for i = 1, 5 do
			if not parent or parent == headAnc then break end
			if DS_containsKeyword(parent.Name:lower(), DS_DeviceDetectionPatterns.Parents) then return true end
			parent = parent.Parent
		end
	end
	local humAnc = obj:FindFirstAncestorOfClass("Humanoid")
	if humAnc then
		local pn = obj.Parent and obj.Parent.Name:lower() or ""
		if pn:find("icon") or obj.Name:lower():find("icon") or obj.Name:lower():find("device") then return true end
	end
	local bb = obj:FindFirstAncestorOfClass("BillboardGui") or obj:FindFirstAncestorOfClass("SurfaceGui")
	if not bb and not headAnc and not humAnc then return false end
	if bb then
		local adornee = bb.Adornee
		if adornee then
			local char = adornee:FindFirstAncestorOfClass("Model")
			if char and char:FindFirstChildOfClass("Humanoid") then return true end
		end
	end
	return false
end

local function DS_getTargetImage(deviceType, currentImage)
	if currentImage and currentImage ~= "" then
		local set = DS_AssetToIconSet[currentImage:lower()]
		if set and set[deviceType] then return set[deviceType] end
		for id, iconSet in pairs(DS_GameIconSets) do
			if currentImage:find(id, 1, true) then return iconSet[deviceType] end
		end
	end
	return DS_DefaultIcons[deviceType]
end

-- ═══ Spoof Function (Visual: text, images, visibility) ═══
local function DS_spoof(obj)
	if not obj or not obj.Parent then return end
	local lp = LocalPlayer
	
	-- TEXT SPOOFING
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		if not DS_OriginalValues[obj] then 
			DS_OriginalValues[obj] = { Text = obj.Text, Type = "Text" }
			-- Instant lock for text
			obj:GetPropertyChangedSignal("Text"):Connect(function()
				if DS_SpoofEnabled and DS_DeviceSpoof ~= "Default" and not _G.StarshipInternalChange then
					_G.StarshipInternalChange = true
					DS_spoof(obj)
					_G.StarshipInternalChange = false
				end
			end)
		end
		
		if DS_SpoofEnabled then
			local currentText = DS_OriginalValues[obj].Text
			local modified = false
			if DS_SpoofName ~= "" and lp then
				if currentText:find(lp.Name) or currentText:find(lp.DisplayName) then
					currentText = currentText:gsub(lp.Name, DS_SpoofName):gsub(lp.DisplayName, DS_SpoofName)
					modified = true
				end
			end
			if DS_DeviceSpoof ~= "Default" and DS_isDeviceRelated(obj) then
				local targetEmoji = DS_DeviceAssets[DS_DeviceSpoof].TargetEmoji
				for emoji, _ in pairs(DS_AllDeviceEmojis) do
					if currentText:find(emoji) then currentText = currentText:gsub(emoji, targetEmoji); modified = true end
				end
				-- Keyword matching omitted for performance/simplicity in flicker fix
			end
			if modified and obj.Text ~= currentText then obj.Text = currentText end
		else
			if DS_OriginalValues[obj] then obj.Text = DS_OriginalValues[obj].Text end
		end
	end
	
	-- IMAGE SPOOFING (The main cause of glitching)
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		if not DS_OriginalValues[obj] then
			DS_OriginalValues[obj] = { 
				Image = obj.Image, 
				ImageRectOffset = obj.ImageRectOffset, 
				ImageRectSize = obj.ImageRectSize, 
				Visible = obj.Visible, 
				Type = "Image" 
			}
			
			-- INSTANT RE-APPLY: This kills the flickering
			obj:GetPropertyChangedSignal("Image"):Connect(function()
				if DS_SpoofEnabled and DS_DeviceSpoof ~= "Default" and not _G.StarshipInternalChange then
					if DS_isDeviceRelated(obj) then
						local target = DS_getTargetImage(DS_DeviceSpoof, obj.Image)
						if obj.Image ~= target then
							_G.StarshipInternalChange = true
							obj.Image = target
							_G.StarshipInternalChange = false
						end
					end
				end
			end)
		end
		
		if DS_isDeviceRelated(obj) then
			if DS_SpoofEnabled and DS_DeviceSpoof ~= "Default" then
				local origImg = DS_OriginalValues[obj] and DS_OriginalValues[obj].Image or obj.Image
				local targetImg = DS_getTargetImage(DS_DeviceSpoof, origImg)
				if targetImg and obj.Image ~= targetImg then
					_G.StarshipInternalChange = true
					obj.Image = targetImg
					if obj.ImageRectSize ~= Vector2.new(0, 0) then
						obj.ImageRectOffset = Vector2.new(0, 0)
						obj.ImageRectSize = Vector2.new(0, 0)
					end
					_G.StarshipInternalChange = false
				end
			else
				local orig = DS_OriginalValues[obj]
				if orig and obj.Image ~= orig.Image then 
					obj.Image = orig.Image 
					obj.ImageRectOffset = orig.ImageRectOffset
					obj.ImageRectSize = orig.ImageRectSize
				end
			end
		end
	end
	
	-- VISIBILITY TOGGLE (For games with multiple frames)
	if obj:IsA("Frame") or obj:IsA("CanvasGroup") or obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		local nameLower = obj.Name:lower()
		local isDeviceFrame = DS_containsKeyword(nameLower, {"pc","mobile","console","phone","computer","xbox","touch"})
		if isDeviceFrame and DS_isDeviceRelated(obj) then
			if not DS_OriginalValues[obj] then 
				DS_OriginalValues[obj] = { Visible = obj.Visible, Type = "Frame" }
				obj:GetPropertyChangedSignal("Visible"):Connect(function()
					if DS_SpoofEnabled and DS_DeviceSpoof ~= "Default" and not _G.StarshipInternalChange then
						_G.StarshipInternalChange = true
						DS_spoof(obj)
						_G.StarshipInternalChange = false
					end
				end)
			end
			
			if DS_SpoofEnabled and DS_DeviceSpoof ~= "Default" then
				local targetKws = DS_DeviceAssets[DS_DeviceSpoof].Keywords
				local isTarget = false
				for _, kw in ipairs(targetKws) do if nameLower:find(kw) then isTarget = true; break end end
				
				if isTarget then 
					if not obj.Visible then obj.Visible = true end
				else
					local isOther = false
					for dt, data in pairs(DS_DeviceAssets) do
						if dt ~= DS_DeviceSpoof then
							for _, kw in ipairs(data.Keywords) do if nameLower:find(kw) then isOther = true; break end end
						end
						if isOther then break end
					end
					if isOther and obj.Visible then obj.Visible = false end
				end
			else
				if DS_OriginalValues[obj] then obj.Visible = DS_OriginalValues[obj].Visible end
			end
		end
	end
end

-- ═══ SMART DEVICE TERM MAPPING ═══
-- Games use their own terms: "Phone"/"Computer"/"Gamepad"
-- We must use the GAME's terms, not generic "Mobile"/"PC"/"Console"
if not _G._StarshipDeviceTerms then _G._StarshipDeviceTerms = {} end

local DS_TERM_TO_CATEGORY = {
	computer = "PC", pc = "PC", desktop = "PC", keyboard = "PC",
	windows = "PC", ["windows10"] = "PC", win64 = "PC", win32 = "PC", uwp = "PC",
	phone = "Mobile", mobile = "Mobile", touch = "Mobile", tablet = "Mobile",
	android = "Mobile", ios = "Mobile", iphone = "Mobile", ipad = "Mobile",
	console = "Console", gamepad = "Console", xbox = "Console",
	playstation = "Console", controller = "Console",
}

-- Initialize with common defaults based on category
if not _G._StarshipDeviceTerms then 
	_G._StarshipDeviceTerms = {
		PC = "Computer",
		Mobile = "Phone",
		Console = "Console"
	} 
end

local function DS_getDeviceCategory(val)
	if typeof(val) ~= "string" then return nil end
	return DS_TERM_TO_CATEGORY[val:lower()]
end

local function DS_getGameTermForTarget()
	return (_G._StarshipDeviceTerms[DS_DeviceSpoof]) or DS_DeviceSpoof
end

local function DS_learnGameTerm(val)
	local cat = DS_getDeviceCategory(val)
	if cat then _G._StarshipDeviceTerms[cat] = val end
end

-- Recursive Spoof: only replace values that are a DIFFERENT device category
local function DS_deepSpoof(val)
	local tVal = typeof(val)
	if tVal == "string" then
		local cat = DS_getDeviceCategory(val)
		if cat then
			DS_learnGameTerm(val)
			if cat == DS_DeviceSpoof then return val end
			return DS_getGameTermForTarget()
		end
	elseif tVal == "EnumItem" then
		if DS_DeviceSpoof == "Mobile" then
			if val == Enum.Platform.Windows or val == Enum.Platform.OSX or val == Enum.Platform.UWP then return Enum.Platform.Android end
		elseif DS_DeviceSpoof == "Console" then
			if val == Enum.Platform.Windows or val == Enum.Platform.Android or val == Enum.Platform.IOS then return Enum.Platform.XBoxOne end
		elseif DS_DeviceSpoof == "PC" then
			if val == Enum.Platform.Android or val == Enum.Platform.IOS then return Enum.Platform.Windows end
		end
	elseif tVal == "table" then
		for k, v in pairs(val) do val[k] = DS_deepSpoof(v) end
	end
	return val
end

-- ═══ DEVICE ATTRIBUTE & REMOTE CONSTANTS ═══
local DS_DEVICE_ATTR_NAMES = {
	"Device", "Platform", "DeviceType", "InputType",
	"PlayerDevice", "PlayerPlatform", "device", "platform",
	"deviceType", "inputType", "playerDevice"
}
local DS_DEVICE_VALUE_KEYWORDS = {"device", "platform", "inputtype", "devicetype"}

-- ═══ Proactive Device Spoof (Full - matches StarSpace.lua) ═══
local function DS_proactiveDeviceSpoof()
	if not DS_SpoofEnabled or DS_DeviceSpoof == "Default" then return end
	local lp = LocalPlayer
	if not lp then return end
	local spoofVal = (DS_DeviceSpoof == "Mobile") and "Phone" or (DS_DeviceSpoof == "PC") and "Computer" or DS_DeviceSpoof

	-- 1. Override device attributes on all targets
	local targets = {lp}
	if lp.Character then
		table.insert(targets, lp.Character)
		local hum = lp.Character:FindFirstChildOfClass("Humanoid")
		if hum then table.insert(targets, hum) end
		local head = lp.Character:FindFirstChild("Head")
		if head then table.insert(targets, head) end
	end
	for _, target in ipairs(targets) do
		for _, attrName in ipairs(DS_DEVICE_ATTR_NAMES) do
			pcall(function()
				local existing = target:GetAttribute(attrName)
				if existing ~= nil then target:SetAttribute(attrName, spoofVal) end
			end)
		end
	end
	pcall(function() lp:SetAttribute("Device", spoofVal) end)

	-- 2. Game-specific remote overrides
	pcall(function()
		local RS = game:GetService("ReplicatedStorage")
		-- PATTERN A: GetDevice RemoteFunction (Generalized)
		for _, v in pairs(RS:GetChildren()) do
			if v:IsA("RemoteFunction") and (v.Name:find("Device") or v.Name:find("Platform")) then
				if not DS_OriginalValues[v] then 
					DS_OriginalValues[v] = { OnClientInvoke = v.OnClientInvoke, Type = "Remote" }
				end
				v.OnClientInvoke = function()
					if DS_SpoofEnabled and DS_DeviceSpoof ~= "Default" then
						if DS_DeviceSpoof == "Mobile" then return "Phone" end
						if DS_DeviceSpoof == "PC" then return "Computer" end
						if DS_DeviceSpoof == "Console" then return "Console" end
					end
				end
			end
		end

		-- PATTERN B: DeviceUpdateEvent & Common Remotes
		local overhead = RS:FindFirstChild("Overhead") or RS:FindFirstChild("Nametags")
		if overhead then
			local de = overhead:FindFirstChild("DeviceUpdateEvent") or overhead:FindFirstChild("UpdateDevice")
			if de and de:IsA("RemoteEvent") then de:FireServer(spoofVal) end
			
			local dr = overhead:FindFirstChild("DeviceRequestFunction") or overhead:FindFirstChild("GetDevice")
			if dr and dr:IsA("RemoteFunction") then 
				if not DS_OriginalValues[dr] then 
					DS_OriginalValues[dr] = { OnClientInvoke = dr.OnClientInvoke, Type = "Remote" }
				end
				dr.OnClientInvoke = function() return spoofVal end 
			end
		end

		-- Direct Remote Search & Fire
		local function scanAndFire()
			for _, v in pairs(RS:GetDescendants()) do
				if v:IsA("RemoteEvent") then
					local vn = v.Name
					if vn == "DeviceUpdateEvent" or vn == "UpdateDevice" or vn == "DeviceDetected" or vn == "DeviceRemote" then
						if vn == "DeviceDetected" then
							local emojiMap = { Mobile = "\240\159\147\177", PC = "\240\159\146\187", Console = "\240\159\142\174" }
							v:FireServer(emojiMap[DS_DeviceSpoof] or emojiMap.PC)
						elseif vn == "DeviceRemote" then
							local termVal = (DS_DeviceSpoof == "Mobile") and "Mobile" or (DS_DeviceSpoof == "PC") and "Desktop" or DS_DeviceSpoof
							v:FireServer(termVal)
						else
							v:FireServer(spoofVal)
						end
					end
				end
			end
		end
		
		scanAndFire()
		-- Late loading support (like Pattern D in StarSpace.lua)
		task.spawn(function()
			for i = 1, 5 do
				task.wait(3)
				scanAndFire()
			end
		end)
	end)

	-- 3. Override StringValues with device-related names
	pcall(function()
		local function scanValues(parent)
			for _, child in pairs(parent:GetDescendants()) do
				if child:IsA("StringValue") then
					local nameLower = child.Name:lower()
					for _, kw in ipairs(DS_DEVICE_VALUE_KEYWORDS) do
						if nameLower:find(kw) then pcall(function() child.Value = spoofVal end); break end
					end
				end
			end
		end
		pcall(function() scanValues(lp) end)
		if lp.Character then pcall(function() scanValues(lp.Character) end) end
	end)

	-- 4. Watch attribute changes (prevent server reset)
	if lp.Character then
		for _, target in ipairs(targets) do
			pcall(function()
				if target:GetAttribute("Device") ~= nil then
					local conn = target:GetAttributeChangedSignal("Device"):Connect(function()
						if DS_SpoofEnabled and DS_DeviceSpoof ~= "Default" then
							local current = target:GetAttribute("Device")
							local cat = DS_getDeviceCategory(tostring(current))
							if cat and cat ~= DS_DeviceSpoof then
								pcall(function() target:SetAttribute("Device", spoofVal) end)
							end
						end
					end)
					_G.StarshipSpoofConnections = _G.StarshipSpoofConnections or {}
					table.insert(_G.StarshipSpoofConnections, conn)
				end
			end)
		end
	end
end

-- ═══ Privacy Hooks (FULL - hookmetamethod __index + __namecall) ═══
local DS_oldIndex = (getrawmetatable and getrawmetatable(game).__index) or nil
local DS_oldNamecall = (getrawmetatable and getrawmetatable(game).__namecall) or nil
local function DS_ApplyPrivacyHooks()
	if DS_HooksApplied then return end

	-- Check all required functions exist
	if not hookmetamethod or not checkcaller or not getnamecallmethod then
		warn("[STARSHIP] ⚠️ hookmetamethod/checkcaller/getnamecallmethod not available — visual spoof only")
		DS_HooksApplied = true
		return
	end

	local lp = LocalPlayer
	local UIS = game:GetService("UserInputService")
	local GS = game:GetService("GuiService")

	-- Pre-cache device remote references for fast comparison
	local _cachedDeviceRemotes = {}
	local _deviceEmojiMap = {
		Mobile = "\240\159\147\177", PC = "\240\159\146\187", Console = "\240\159\142\174",
	}
	task.spawn(function()
		pcall(function()
			local RS = game:GetService("ReplicatedStorage")
			local overhead = RS:FindFirstChild("Overhead")
			if overhead then
				local de = overhead:FindFirstChild("DeviceUpdateEvent")
				if de then _cachedDeviceRemotes[de] = "DeviceUpdateEvent" end
			end
			local de2 = RS:FindFirstChild("DeviceUpdateEvent")
			if de2 then _cachedDeviceRemotes[de2] = "DeviceUpdateEvent" end
			local dd = RS:FindFirstChild("DeviceDetected")
			if dd then _cachedDeviceRemotes[dd] = "DeviceDetected" end
		end)
	end)

	-- Hook __index
	local hookOk1, hookErr1 = pcall(function()
		local oldIndex
		oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
			if not checkcaller() then
				-- Anti-AFK hooks (Always block if AntiTabDetect is on)
				if _G.StarshipAntiTabDetect then
					if self == UIS then
						if key == "IsWindowFocused" then return function() return true end end
						if key == "GetLastInputTime" then return function() return tick() end end
					end
				end

				if DS_SpoofEnabled and DS_DeviceSpoof ~= "Default" then
					-- Optimization: Check common services first
					if self == UIS then
						if DS_DeviceSpoof == "Mobile" then
							if key == "TouchEnabled" or key == "KeyboardEnabled" or key == "MouseEnabled" or key == "AccelerometerEnabled" or key == "GyroscopeEnabled" then return true end
							if key == "GamepadEnabled" then return false end
						elseif DS_DeviceSpoof == "PC" then
							if key == "TouchEnabled" then return false end
							if key == "KeyboardEnabled" or key == "MouseEnabled" then return true end
						elseif DS_DeviceSpoof == "Console" then
							if key == "TouchEnabled" then return false end
							if key == "GamepadEnabled" then return true end
						end
					elseif self == GS then
						if key == "IsTenFootInterface" then return DS_DeviceSpoof == "Console" end
					elseif DS_DeviceSpoof == "Mobile" and key == "ViewportSize" and self:IsA("Camera") then
						return Vector2.new(896, 414)
					end
				end
			end
			return (oldIndex or DS_oldIndex)(self, key)
		end))
		if oldIndex then DS_oldIndex = oldIndex end
	end)
	if not hookOk1 or not DS_oldIndex then
		warn("[STARSHIP] __index hook failed:", hookErr1 or "hookmetamethod returned nil")
		DS_oldIndex = nil
	end

	-- Hook __namecall
	-- Hook __namecall
	local hookOk2, hookErr2 = pcall(function()
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local method = getnamecallmethod()

			if not checkcaller() then
				if _G.StarshipAntiTabDetect then
					-- 1. Block focus signals
					if (method == "Connect" or method == "connect") and self == UIS.WindowFocusReleased then
						return {
							Connected = true,
							Disconnect = function(s) if type(s) == "table" then s.Connected = false end end,
							disconnect = function(s) if type(s) == "table" then s.Connected = false end end,
						}
					end
					-- 2. Block focus checks
					if method == "IsWindowFocused" then return true end
					if method == "GetLastInputTime" then return tick() end
					-- 3. Block AFK remotes
					if method == "FireServer" or method == "InvokeServer" then
						local nm = tostring(self.Name):lower()
						if nm:find("afk") or nm:find("focus") or nm:find("tab") or nm:find("idle") or nm:find("activity") then
							return
						end
					end
					-- 4. Block AFK attributes
					if method == "SetAttribute" then
						local attr = tostring(...):lower()
						if attr:find("afk") or attr:find("focus") or attr:find("tab") or attr:find("idle") then
							return
						end
					end
				end

				if DS_SpoofEnabled and DS_DeviceSpoof ~= "Default" then
					-- 0. DEVICE REMOTE INTERCEPT (fast path)
					if method == "FireServer" or method == "InvokeServer" then
						local isDeviceRemote = _cachedDeviceRemotes[self] ~= nil
						local remoteName = not isDeviceRemote and tostring(self.Name):lower() or ""
						
						-- ONLY process if it's a known device remote or name contains keywords
						if isDeviceRemote or remoteName:find("device") or remoteName:find("platform") or remoteName:find("input") then
							if _cachedDeviceRemotes[self] == "DeviceUpdateEvent" then
								local spoofVal2 = (DS_DeviceSpoof == "Mobile") and "Phone" or
									(DS_DeviceSpoof == "PC") and "Computer" or DS_DeviceSpoof
								return (oldNamecall or DS_oldNamecall)(self, spoofVal2)
							elseif _cachedDeviceRemotes[self] == "DeviceDetected" then
								return (oldNamecall or DS_oldNamecall)(self, _deviceEmojiMap[DS_DeviceSpoof] or _deviceEmojiMap.PC)
							end

							-- Deep spoof only when potentially relevant
							local args = {...}
							local argCount = select("#", ...)
							local changed = false
							for i = 1, argCount do
								local spoofed = DS_deepSpoof(args[i])
								if spoofed ~= args[i] then args[i] = spoofed; changed = true end
							end
							if changed then return (oldNamecall or DS_oldNamecall)(self, unpack(args, 1, argCount)) end
						end
					end

					-- 2. ATTRIBUTE SPOOFING (READ)
					if method == "GetAttribute" then
						local name = ...
						local nameLower = name and tostring(name):lower() or ""
						if nameLower == "device" or nameLower == "platform" or nameLower == "devicetype" or
						   nameLower == "inputtype" or nameLower == "playerdevice" or nameLower == "playerplatform" then
							if DS_DeviceSpoof == "Mobile" then return "Mobile" end
							if DS_DeviceSpoof == "PC" then return "PC" end
							if DS_DeviceSpoof == "Console" then return "Console" end
						end
					end

					-- 2b. ATTRIBUTE SPOOFING (WRITE)
					if method == "SetAttribute" then
						local args = {...}
						local name = args[1]
						local nameLower = name and tostring(name):lower() or ""
						if nameLower == "device" or nameLower == "platform" or nameLower == "devicetype" or
						   nameLower == "inputtype" or nameLower == "playerdevice" or nameLower == "playerplatform" then
							local currentVal = tostring(args[2])
							DS_learnGameTerm(currentVal)
							args[2] = DS_getGameTermForTarget()
							return (oldNamecall or DS_oldNamecall)(self, unpack(args, 1, select("#", ...)))
						end
					end

					-- 3. CORE SERVICE SPOOFING
					if self == GS and method == "IsTenFootInterface" then
						return DS_DeviceSpoof == "Console"
					elseif self == UIS then
						if method == "GetPlatform" then
							if DS_DeviceSpoof == "Mobile" then return Enum.Platform.Android end
							if DS_DeviceSpoof == "PC" then return Enum.Platform.Windows end
							if DS_DeviceSpoof == "Console" then return Enum.Platform.XBoxOne end
						elseif method == "GetLastInputType" then
							if DS_DeviceSpoof == "Mobile" then return Enum.UserInputType.Touch end
							if DS_DeviceSpoof == "PC" then return Enum.UserInputType.Keyboard end
							if DS_DeviceSpoof == "Console" then return Enum.UserInputType.Gamepad1 end
						elseif method == "GetConnectedGamepads" then
							if DS_DeviceSpoof == "Mobile" or DS_DeviceSpoof == "PC" then return {} end
							if DS_DeviceSpoof == "Console" then return {{}} end
						elseif method == "GetSupportedGamepadKeyCodes" then
							if DS_DeviceSpoof == "Console" then
								return {Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB}
							else return {} end
						end
					end
				end
			end
			return (oldNamecall or DS_oldNamecall)(self, ...)
		end))
		if oldNamecall then DS_oldNamecall = oldNamecall end
	end)
	if not hookOk2 or not DS_oldNamecall then
		warn("[STARSHIP] __namecall hook failed:", hookErr2 or "hookmetamethod returned nil")
		DS_oldNamecall = nil
	end

	-- Create TouchGui for Mobile spoofing
	if DS_DeviceSpoof == "Mobile" then
		pcall(function()
			local pg = lp:FindFirstChild("PlayerGui")
			if pg and not pg:FindFirstChild("TouchGui") then
				local tg = Instance.new("ScreenGui")
				tg.Name = "TouchGui"
				tg.ResetOnSpawn = false
				tg.Parent = pg
				local f = Instance.new("Frame", tg)
				f.Name = "TouchControlFrame"
				f.Visible = false
			end
		end)
	end

	DS_HooksApplied = true
end

-- ═══ Apply hooks early if saved settings exist ═══
if DS_SpoofEnabled and DS_DeviceSpoof ~= "Default" then
	pcall(DS_ApplyPrivacyHooks)
	task.spawn(function()
		task.wait(2)
		pcall(DS_proactiveDeviceSpoof)
	end)
end

-- ═══ Full Scan & Listen Functions ═══
local function DS_fullScan()
	local lp = LocalPlayer
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character then
			for _, g in pairs(player.Character:GetDescendants()) do
				if g:IsA("GuiObject") and DS_isDeviceRelated(g) then
					_G.StarshipDeviceElements = _G.StarshipDeviceElements or {}
					_G.StarshipDeviceElements[g] = true
					pcall(DS_spoof, g)
				end
			end
		end
	end
	pcall(function()
		for _, g in pairs(lp.PlayerGui:GetDescendants()) do
			if g:IsA("GuiObject") and DS_isDeviceRelated(g) then
				_G.StarshipDeviceElements = _G.StarshipDeviceElements or {}
				_G.StarshipDeviceElements[g] = true
				pcall(DS_spoof, g)
			end
		end
	end)
end

local function DS_listenToCharacter(char)
	if not char then return end
	local conn = char.DescendantAdded:Connect(function(g)
		if DS_SpoofEnabled and g:IsA("GuiObject") and DS_isDeviceRelated(g) then
			_G.StarshipDeviceElements = _G.StarshipDeviceElements or {}
			_G.StarshipDeviceElements[g] = true
			task.defer(function() pcall(DS_spoof, g) end)
		end
	end)
	_G.StarshipSpoofConnections = _G.StarshipSpoofConnections or {}
	table.insert(_G.StarshipSpoofConnections, conn)
end

-- ═══ UI ELEMENTS ═══
DeviceSpoofTab:Paragraph({
	Title = "⚙️ Configuration",
	Desc = "Select your target device and enable spoofing below.",
})

DeviceSpoofTab:Dropdown({
	Title = "🎯 Device Type",
	Desc = "Choose which device to appear as",
	Values = {"Default", "PC", "Mobile", "Console"},
	Value = DS_DeviceSpoof,
	Callback = function(v)
		local prev = DS_DeviceSpoof
		DS_DeviceSpoof = v
		DS_SaveSettings()
		if DS_SpoofEnabled then
			DS_ApplyPrivacyHooks()
			-- Re-spoof confirmed elements
			if _G.StarshipDeviceElements then
				for obj, _ in pairs(_G.StarshipDeviceElements) do
					if typeof(obj) == "Instance" and obj.Parent then pcall(DS_spoof, obj) end
				end
			end
			task.spawn(function() task.wait(0.3); DS_proactiveDeviceSpoof() end)
			if v ~= "Default" and v ~= prev then
				WindUI:Notify({ Title = "📱 Device Spoof", Content = "Updated to: " .. v .. "\nRespawn for full effect!", Duration = 4 })
			end
		end
		WindUI:Notify({ Title = "📱 Device Spoof", Content = "Device set to: " .. v, Duration = 2 })
	end,
})

DS_SpoofToggleRef = DeviceSpoofTab:Toggle({
	Title = "🔄 Enable Spoofing",
	Desc = "Activate device spoofing hooks",
	Value = DS_SpoofEnabled,
	Callback = function(v)
		DS_SpoofEnabled = v
		DS_SaveSettings()
		if v then
			DS_ApplyPrivacyHooks()
			task.spawn(function() task.wait(0.3); DS_proactiveDeviceSpoof() end)
			if DS_DeviceSpoof ~= "Default" then
				_G.StarshipSpoofConnections = {}
				_G.StarshipDeviceElements = {}
				DS_fullScan()
				-- Listen to all characters
				for _, player in pairs(Players:GetPlayers()) do
					if player.Character then DS_listenToCharacter(player.Character) end
					local cc = player.CharacterAdded:Connect(function(char)
						task.wait(1); DS_listenToCharacter(char); DS_fullScan()
						task.spawn(function() task.wait(0.5); DS_proactiveDeviceSpoof() end)
					end)
					table.insert(_G.StarshipSpoofConnections, cc)
				end
				local jc = Players.PlayerAdded:Connect(function(player)
					local cc = player.CharacterAdded:Connect(function(char) task.wait(1); DS_listenToCharacter(char); DS_fullScan() end)
					table.insert(_G.StarshipSpoofConnections, cc)
				end)
				table.insert(_G.StarshipSpoofConnections, jc)
				-- Periodic re-spoof
				task.spawn(function()
					while DS_SpoofEnabled and task.wait(5) do
						if _G.StarshipDeviceElements then
							for obj, isD in pairs(_G.StarshipDeviceElements) do
								if isD and typeof(obj) == "Instance" and obj.Parent then pcall(DS_spoof, obj) end
							end
						end
					end
				end)
				WindUI:Notify({ Title = "📱 Device Spoof", Content = "Spoofing ACTIVE → " .. DS_DeviceSpoof, Duration = 3 })
			else
				WindUI:Notify({ Title = "📱 Device Spoof", Content = "Spoofing enabled. Select a device type above!", Duration = 3 })
			end
		else
			-- Disconnect all
			if _G.StarshipSpoofConnections then
				for _, conn in pairs(_G.StarshipSpoofConnections) do pcall(function() conn:Disconnect() end) end
				_G.StarshipSpoofConnections = {}
			end
			-- Restore originals
			for obj, orig in pairs(DS_OriginalValues) do
				if typeof(obj) == "Instance" and obj.Parent then
					pcall(function()
						if orig.Type == "Image" then
							obj.Image = orig.Image; obj.ImageRectOffset = orig.ImageRectOffset; obj.ImageRectSize = orig.ImageRectSize
						elseif orig.Type == "Text" then obj.Text = orig.Text
						elseif orig.Type == "Frame" then obj.Visible = orig.Visible 
						elseif orig.Type == "Remote" then obj.OnClientInvoke = orig.OnClientInvoke end
					end)
				end
			end
			DS_OriginalValues = {}
			_G.StarshipDeviceElements = {}
			
			-- Restore device attributes & remotes with accurate detection
			pcall(function()
				local RS = game:GetService("ReplicatedStorage")
				local UIS2 = game:GetService("UserInputService")
				
				-- Detect Real Device
				local realDevice = "Computer"
				if UIS2.TouchEnabled and not (UIS2.MouseEnabled or UIS2.KeyboardEnabled) then 
					realDevice = "Phone"
				elseif UIS2.GamepadEnabled and not (UIS2.MouseEnabled or UIS2.KeyboardEnabled) then 
					realDevice = "Console" 
				end
				
				LocalPlayer:SetAttribute("Device", realDevice)
				if LocalPlayer.Character then LocalPlayer.Character:SetAttribute("Device", realDevice) end
				
				-- Notify server of back-to-normal state
				local overhead = RS:FindFirstChild("Overhead") or RS:FindFirstChild("Nametags")
				if overhead then
					local de = overhead:FindFirstChild("DeviceUpdateEvent") or overhead:FindFirstChild("UpdateDevice")
					if de and de:IsA("RemoteEvent") then de:FireServer(realDevice) end
				end
				local deRoot = RS:FindFirstChild("DeviceUpdateEvent") or RS:FindFirstChild("UpdateDevice")
				if deRoot and deRoot:IsA("RemoteEvent") then deRoot:FireServer(realDevice) end
			end)
			DS_SaveSettings()
			WindUI:Notify({ Title = "📱 Device Spoof", Content = "Spoofing DISABLED & restored to normal", Duration = 3 })
		end
	end,
})

DeviceSpoofTab:Divider()

DeviceSpoofTab:Button({
	Title = "🔄 Force Respawn",
	Desc = "Respawn character to apply spoofing",
	Callback = function()
		local lp = LocalPlayer
		if lp and lp.Character then
			local hum = lp.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = 0 end
			WindUI:Notify({ Title = "📱 Device Spoof", Content = "Respawning to apply spoof...", Duration = 2 })
		end
	end,
})



-- Auto-init if loaded from saved settings
if DS_SpoofEnabled and DS_DeviceSpoof ~= "Default" then
	task.spawn(function()
		task.wait(2)
		if DS_SpoofToggleRef then
			pcall(function()
				DS_SpoofEnabled = false
				if DS_SpoofToggleRef.SetValue then DS_SpoofToggleRef:SetValue(false)
				elseif DS_SpoofToggleRef.Set then DS_SpoofToggleRef:Set(false) end
				task.wait(0.2)
				if DS_SpoofToggleRef.SetValue then DS_SpoofToggleRef:SetValue(true)
				elseif DS_SpoofToggleRef.Set then DS_SpoofToggleRef:Set(true) end
			end)
		else
			DS_SpoofEnabled = true
			_G.StarshipSpoofConnections = {}
			_G.StarshipDeviceElements = {}
			DS_fullScan()
			task.spawn(function()
				while DS_SpoofEnabled and task.wait(5) do
					if _G.StarshipDeviceElements then
						for obj, isD in pairs(_G.StarshipDeviceElements) do
							if isD and typeof(obj) == "Instance" and obj.Parent then pcall(DS_spoof, obj) end
						end
					end
				end
			end)
		end
	end)
end

end) -- end pcall
if not dsOk then
	warn("[STARSHIP] ⚠️ Device Spoof tab error:", tostring(dsErr))
	pcall(function()
		DeviceSpoofTab:Paragraph({ Title = "❌ Error", Desc = "Device Spoof failed to load: " .. tostring(dsErr) })
	end)
end
end) -- end task.spawn for Device Spoof Tab

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
		safeSet(RememberPositionToggle, Settings.RememberPosition)
		safeSet(ThemeDropdown, Settings.Theme)
		safeSet(AdminESPToggle, Settings.AdminESP)

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
	-- When main UI is closed, we don't hide the Mini Player anymore 
	-- as per user request to keep it visible when minimized.
	-- ToggleMiniPlayer(false)
end)

-- Method 1: OnDestroy callback/Destroying signal
pcall(function()
	if Window.Internal and Window.Internal.ScreenGui then
		Window.Internal.ScreenGui.Destroying:Connect(CleanupAll)
	elseif Window.OnDestroy then
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
		while not _G.StarshipWindowState.isDestroyed do
			task.wait(10) -- Increased from 2s to 10s for performance

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

	-- Notifications removed for performance
end)

-- Update check removed for performance
