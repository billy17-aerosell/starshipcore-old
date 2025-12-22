--[[
    Starship Core v0.9 Beta

    Change:
    - Travel Phase sekarang menggunakan 'Humanoid:MoveTo'.
    - Hasil: Animasi jalan saat menuju titik awal akan 100% sesuai
      dengan Animation Pack karakter Anda (Ninja/Zombie/dll).
]]

warn("[Starship] Script Initialization Started...") -- DEBUG START

-- SERVER-BASED LOADING MODE
-- Automatically detects environment and loads modules from appropriate server
-- No manual configuration needed!

-- Auto-detect: Check if URL was injected by bootstrap/dev-script
if _G.StarshipServerMode == nil then
    _G.StarshipServerMode = true -- Always use server-based loading (easier updates)
end

-- Auto-detect server URL based on how script was loaded
if _G.StarshipServerURL == nil then
    -- Default to production if not set by dev-pc-script
    _G.StarshipServerURL = "https://starship-core.my.id"
end

-- Store the base URL for reference
_G.StarshipBaseURL = _G.StarshipServerURL

-- FORCE CLEAR CACHE (Add this to ensure fresh load)
_G.StarshipModulePrefix = nil
if getgenv then
    getgenv().StarshipRunning = false
end -- Reset running state for debug

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ControllerService = game:GetService("ControllerService")

local LocalPlayer = Players.LocalPlayer
local FOLDER_NAME = "StarshipCore"
local ModulesPath = "Modules"
if not isfolder(FOLDER_NAME) then
    makefolder(FOLDER_NAME)
end

local WARP_FOLDER = FOLDER_NAME .. "/StarshipWarps"
local MERGER_FOLDER = FOLDER_NAME .. "/StarshipMerger"
if not isfolder(WARP_FOLDER) then
    makefolder(WARP_FOLDER)
end
if not isfolder(MERGER_FOLDER) then
    makefolder(MERGER_FOLDER)
end

-- --- VARIABLES (Colors consolidated into table to reduce local register usage) ---
-- CurrentColors stores the active theme colors and is updated when theme changes
local CurrentColors = {
    MAIN = Color3.fromRGB(10, 10, 14),
    SIDE = Color3.fromRGB(15, 15, 20),
    ACCENT = Color3.fromRGB(90, 110, 245),
    TEXT = Color3.fromRGB(240, 240, 250),
    TEXT_DIM = Color3.fromRGB(140, 140, 160),
    ITEM = Color3.fromRGB(20, 20, 28),
    RED = Color3.fromRGB(255, 80, 80),
    YELLOW = Color3.fromRGB(255, 220, 60),
    GREEN = Color3.fromRGB(60, 255, 160),
}
-- Aliases for backward compatibility (initial values)
local C_MAIN, C_SIDE, C_ACCENT, C_TEXT, C_TEXT_DIM, C_ITEM, C_RED, C_YELLOW, C_GREEN =
    CurrentColors.MAIN,
    CurrentColors.SIDE,
    CurrentColors.ACCENT,
    CurrentColors.TEXT,
    CurrentColors.TEXT_DIM,
    CurrentColors.ITEM,
    CurrentColors.RED,
    CurrentColors.YELLOW,
    CurrentColors.GREEN
-- Make CurrentColors accessible globally for theme updates
_G.StarshipColors = CurrentColors

-- Mobile Detection & Responsive System (consolidated to reduce local count)

local TAGS_API_URL = "https://starship-core.my.id/api/tags"
_G.StarshipTags = {} -- Store tags here: { [UserId] = {role="VIP", tag="VIP"} }

local function FetchServerTags()
    task.spawn(function()
        local players = Players:GetPlayers()
        local ids = {}
        for _, p in ipairs(players) do
            table.insert(ids, p.UserId)
        end

        if #ids == 0 then
            return
        end

        local success, response = pcall(function()
            return request({
                Url = TAGS_API_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ userIds = ids }),
            })
        end)

        if success and response.Success then
            local data = HttpService:JSONDecode(response.Body)
            if data.status == "success" and data.tags then
                for uid, info in pairs(data.tags) do
                    _G.StarshipTags[tonumber(uid)] = info
                end
                -- Trigger update event if you have one, or just let UI loop handle it
            end
        end
    end)
end

-- Auto-fetch tags when players join or every 60s
Players.PlayerAdded:Connect(function()
    task.wait(2)
    FetchServerTags()
end)
task.spawn(function()
    while true do
        FetchServerTags()
        task.wait(60)
    end
end)

local function LoadModule(name)
    -- 0. FIRST: Try loading from memory (modules pre-loaded by Loader.lua)
    if getgenv and getgenv().StarshipModules then
        local memModules = getgenv().StarshipModules
        -- Try exact match first
        if memModules[name .. ".lua"] then
            return memModules[name .. ".lua"]
        end
        -- Try with Tabs/ prefix
        if memModules["Tabs/" .. name .. ".lua"] then
            return memModules["Tabs/" .. name .. ".lua"]
        end
        -- Try without .lua extension
        if memModules[name] then
            return memModules[name]
        end
    end

    -- 1. Try HTTP Server Loading (Auto-detect: works for both dev and production)
    if _G.StarshipServerMode then
        local serverUrl = _G.StarshipServerURL or "https://starship-core.my.id"
        local moduleUrl = serverUrl .. "/api/get-module?name=" .. name:gsub("/", "%%2F") .. ".lua"

        -- Add user ID for production whitelist check (if available)
        local userId = tostring(game.Players.LocalPlayer.UserId)
        if userId and not serverUrl:find("localhost") then
            moduleUrl = moduleUrl .. "&user=" .. userId
        end

        -- Only show debug in development
        local isDev = serverUrl:find("localhost") ~= nil
        if isDev then
            warn("[Starship] HTTP Loading: " .. name .. " from " .. serverUrl)
        end

        local success, result = pcall(function()
            return game:HttpGet(moduleUrl)
        end)

        if success and result then
            -- Check if response is an error message
            if result:match("^error%(") then
                if isDev then
                    warn("[Starship] HTTP Error for " .. name .. ": " .. result)
                end
                -- Check if response is JSON (encrypted module from production)
            elseif result:sub(1, 1) == "{" then
                -- Production mode: decrypt the module
                local jsonSuccess, jsonData = pcall(function()
                    return game:GetService("HttpService"):JSONDecode(result)
                end)

                if jsonSuccess and jsonData.status == "success" and jsonData.blob and jsonData.key then
                    -- Decrypt XOR encrypted module
                    local function base64Decode(data)
                        local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
                        data = string.gsub(data, '[^' .. b .. '=]', '')
                        return (data:gsub('.', function(x)
                            if x == '=' then return '' end
                            local r, f = '', (b:find(x) - 1)
                            for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
                            return r
                        end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
                            if #x ~= 8 then return '' end
                            local c = 0
                            for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
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

                    local decoded = base64Decode(jsonData.blob)
                    local decrypted = xorDecrypt(decoded, jsonData.key)

                    local func, err = loadstring(decrypted)
                    if func then
                        return func()
                    else
                        warn("[Starship] Syntax Error in " .. name .. " (decrypted): " .. tostring(err))
                    end
                else
                    if isDev then
                        warn("[Starship] JSON parse failed or invalid response for " .. name)
                    end
                end
            else
                -- Plain text response (development mode)
                local func, err = loadstring(result)
                if func then
                    if isDev then
                        warn("[Starship] ✅ HTTP Loaded: " .. name)
                    end
                    return func()
                else
                    warn("[Starship] Syntax Error in " .. name .. " (HTTP): " .. tostring(err))
                end
            end
        else
            if isDev then
                warn("[Starship] HTTP Failed for " .. name .. ": " .. tostring(result))
            end
        end

        -- If HTTP fails, fall through to local file loading
        if isDev then
            warn("[Starship] Falling back to local file loading for: " .. name)
        end
    end

    -- 1. Try Cached Prefix (Local File Mode)
    if _G.StarshipModulePrefix then
        local p = _G.StarshipModulePrefix .. name .. ".lua"
        local func, err = loadstring(readfile(p))
        if not func then
            warn("[Starship] Syntax Error in " .. name .. ": " .. tostring(err))
            return nil
        end
        return func()
    end

    -- 2. Exhaustive Search Paths (Local File Mode)
    local paths = {
        "StarshipCore/Modules/" .. name .. ".lua",
        "StarshipCore\\Modules\\" .. name:gsub("/", "\\") .. ".lua",
        "Modules/" .. name .. ".lua",
        "Starship/Modules/" .. name .. ".lua",
        -- Backslash variants for Windows
        "Modules\\"
        .. name:gsub("/", "\\")
        .. ".lua",
        -- Direct path (if name includes full path)
        name .. ".lua",
    }

    for _, p in ipairs(paths) do
        if isfile(p) then
            -- Cache the valid prefix
            -- e.g. "Modules/Tabs/Tools.lua" - "Tabs/Tools.lua" = "Modules/"
            local cleanName = name:gsub("/", "\\") -- handle potential mix
            local prefix = p:sub(1, #p - #name - 4)
            _G.StarshipModulePrefix = prefix

            -- warn("[Starship] Loaded: " .. name .. " from " .. p)
            local content = readfile(p)
            local func, err = loadstring(content)
            if not func then
                warn("[Starship] Syntax Error in " .. name .. ": " .. tostring(err))
                return nil
            end
            return func()
        end
    end

    -- 3. Deep Search (Last Resort)
    if name == "Config" or not _G.StarshipModulePrefix then
        warn("[Starship] Searching for module: " .. name)
        warn("[Starship] Current Directory Listing:") -- Added Debug

        local function scan(dir)
            local s, files = pcall(listfiles, dir)
            if not s then
                warn(" - listfiles failed for: " .. tostring(dir))
                return nil
            end

            if not files then
                return nil
            end

            for _, file in ipairs(files) do
                -- DEBUG PRINT (Only print top level to avoid spam)
                if dir == "" then
                    warn(" - " .. file)
                end

                -- Check file match (ignoring case/path separators)
                -- Handle full paths returned by some executors
                local fileName = file:match("[^/\\]+$") or file
                if fileName:lower() == name:lower() .. ".lua" then
                    return file
                end

                -- Recurse (assuming no extension = folder)
                -- Some executors return folders with extensions, so be careful.
                -- Better check: if it doesn't end in .lua or .txt or .json
                if
                    not file:lower():match("%.lua$")
                    and not file:lower():match("%.json$")
                    and not file:lower():match("%.txt$")
                then
                    local res = scan(file)
                    if res then
                        return res
                    end
                end
            end
            return nil
        end

        local foundPath = scan("")
        if foundPath then
            warn("[Starship] Deep Search found: " .. foundPath)
            -- Calculate prefix from found path
            -- foundPath usually includes the filename.
            -- foundPath: "StarshipCore/Modules/Config.lua" -> prefix: "StarshipCore/Modules/"
            -- name: "Config"
            -- This logic assumes name is simple like "Config"

            -- We need to handle "Tabs/Tools" case too.
            -- If name is "Tabs/Tools", foundPath is ".../Tabs/Tools.lua"

            local nameLen = #name + 4 -- ".lua"
            local prefix = foundPath:sub(1, #foundPath - nameLen)

            _G.StarshipModulePrefix = prefix
            warn("[Starship] Set Prefix: " .. prefix)
            local content = readfile(foundPath)
            local func, err = loadstring(content)
            if not func then
                warn("[Starship] Syntax Error in " .. name .. " (Deep Search): " .. tostring(err))
                return nil
            end
            return func()
        end
    end

    warn("[Starship] FAILED to load module: " .. name)
    return nil
end

local ConfigData = LoadModule("Config")
if not ConfigData then
    ConfigData = {}
end

local LocaleModule = LoadModule("Locale")
if not LocaleModule then
    LocaleModule = { Get = function(k) return k end, SetLanguage = function() end, GetLanguage = function() return "en" end }
end
-- Make Locale globally accessible
_G.StarshipLocale = LocaleModule

local UIModule = LoadModule("UI")
if not UIModule then
    UIModule = {}
end

local IntroModule = LoadModule("Intro")
if not IntroModule then
    IntroModule = {}
end

local Themes = ConfigData.Themes or {}
local Config = ConfigData.DefaultConfig
    or {
        Theme = "Default",
        Language = "en",
        AccentColor = { R = 90, G = 110, B = 245 },
        Keybinds = {},
    }

-- Load saved language preference from file
local CONFIG_FOLDER = "StarshipCore/StarshipConfigs"
pcall(function()
    if isfile and isfile(CONFIG_FOLDER .. "/Language.json") then
        local langData = HttpService:JSONDecode(readfile(CONFIG_FOLDER .. "/Language.json"))
        if langData and langData.Language then
            Config.Language = langData.Language
        end
    end
end)

-- Initialize Locale with saved language
if Config.Language and LocaleModule.SetLanguage then
    LocaleModule.SetLanguage(Config.Language)
end

-- Helper function to get localized text
local function L(key, ...)
    if LocaleModule and LocaleModule.Get then
        return LocaleModule.Get(key, ...)
    end
    return key
end

-- Helper function to register UI element for auto-refresh when language changes
-- Usage: LR(TextLabel, "key") or LR(TextLabel, "key", function() return {arg1, arg2} end)
local function LR(element, key, formatArgs)
    if LocaleModule and LocaleModule.RegisterElement then
        LocaleModule.RegisterElement(element, key, formatArgs)
    else
        -- Fallback if RegisterElement not available
        if formatArgs then
            local args = formatArgs()
            if args then
                element.Text = L(key, unpack(args))
            else
                element.Text = L(key)
            end
        else
            element.Text = L(key)
        end
    end
end

-- Helper function to register UI element with custom update function
-- Usage: LC(element, function(el, L) el.Text = L("key") .. ": " .. someValue end)
local function LC(element, updateFunc)
    if LocaleModule and LocaleModule.RegisterCustom then
        LocaleModule.RegisterCustom(element, updateFunc)
    else
        -- Fallback
        pcall(updateFunc, element, L)
    end
end

-- Table to store UI elements that need refresh when language changes
local LocalizedUI = {
    -- Static text elements (simple key mapping)
    Static = {},
    -- Dynamic text elements (with custom update functions)
    Dynamic = {},
}

-- Register a static UI element for language refresh
local function RegisterLocalizedUI(element, key, prefix, suffix)
    prefix = prefix or ""
    suffix = suffix or ""
    table.insert(LocalizedUI.Static, {
        Element = element,
        Key = key,
        Prefix = prefix,
        Suffix = suffix
    })
    element.Text = prefix .. L(key) .. suffix
end

-- Register a dynamic UI element with custom update function
local function RegisterDynamicUI(element, updateFunc)
    table.insert(LocalizedUI.Dynamic, {
        Element = element,
        UpdateFunc = updateFunc
    })
    pcall(updateFunc, element)
end

-- Refresh all localized UI elements
local function RefreshAllLocalizedUI()
    -- Refresh static elements
    for _, item in ipairs(LocalizedUI.Static) do
        if item.Element and item.Element.Parent then
            item.Element.Text = (item.Prefix or "") .. L(item.Key) .. (item.Suffix or "")
        end
    end
    -- Refresh dynamic elements
    for _, item in ipairs(LocalizedUI.Dynamic) do
        if item.Element and item.Element.Parent then
            pcall(item.UpdateFunc, item.Element)
        end
    end
end

-- Tab modules storage for reactive refresh
local TabModules = {
    Tools = nil,
    Fun = nil,
    Warp = nil,
    Helper = nil,
    Dashboard = nil,
    Config = nil,
}
local TabPages = {
    Tools = nil,
    Fun = nil,
    Warp = nil,
    Helper = nil,
    Dashboard = nil,
    Config = nil,
}
local TabParams = {} -- Will be set after UI is created

-- Rebuild all localized tabs when language changes
local function RebuildLocalizedTabs()
    -- Rebuild Tools Tab
    if TabModules.Tools and TabPages.Tools then
        pcall(function()
            TabModules.Tools(TabPages.Tools, TabParams.UIModule, TabParams.Connections, TabParams.Config,
                TabParams.LocalPlayer, TabParams.UIHandlers, TabParams.RegisterTheme)
        end)
    end
    -- Rebuild Fun Tab
    if TabModules.Fun and TabPages.Fun then
        pcall(function()
            TabModules.Fun(TabPages.Fun, TabParams.UIModule, TabParams.Connections, TabParams.Config,
                TabParams.LocalPlayer, TabParams.UIHandlers, TabParams.RegisterTheme)
        end)
    end
    -- Rebuild Warp Tab
    if TabModules.Warp and TabPages.Warp then
        pcall(function()
            TabModules.Warp(TabPages.Warp, TabParams.UIModule, TabParams.Connections, TabParams.Config,
                TabParams.LocalPlayer, TabParams.UIHandlers, TabParams.ShowConfirm, TabParams.RegisterTheme)
        end)
    end
    -- Rebuild Helper Tab
    if TabModules.Helper and TabPages.Helper then
        pcall(function()
            TabModules.Helper(TabPages.Helper, TabParams.UIModule, TabParams.Connections, TabParams.Config,
                TabParams.LocalPlayer, TabParams.UIHandlers, TabParams.ShowConfirm, TabParams.RegisterTheme)
        end)
    end
    -- Rebuild Dashboard Tab
    if TabModules.Dashboard and TabPages.Dashboard then
        pcall(function()
            TabModules.Dashboard(TabPages.Dashboard, TabParams.UIModule, TabParams.Connections, TabParams.Config,
                TabParams.LocalPlayer, TabParams.UIHandlers, TabParams.RegisterTheme)
        end)
    end
    -- Rebuild Config Tab
    if TabModules.Config and TabPages.Config then
        pcall(function()
            if type(TabModules.Config) == "table" and TabModules.Config.SetupUI then
                TabModules.Config.SetupUI(
                    TabPages.Config,
                    TabParams.UIModule,
                    TabParams.Connections,
                    TabParams.Config,
                    TabParams.LocalPlayer,
                    TabParams.UIHandlers,
                    TabParams.Themes,
                    TabParams.ThemeObjects,
                    TabParams.Main
                )
                -- Re-apply current theme after rebuild
                if TabModules.Config.ApplyTheme then
                    TabModules.Config.ApplyTheme(TabParams.Config.Theme or "Default")
                end
            end
        end)
    end
end

-- Register language change callback
if LocaleModule and LocaleModule.OnLanguageChange then
    LocaleModule.OnLanguageChange(function(newLang, oldLang)
        RefreshAllLocalizedUI()
        -- Rebuild tabs with localized text (deferred to allow current handler to complete)
        task.defer(function()
            RebuildLocalizedTabs()
        end)
    end)
end

-- Restore missing global variables (consolidated into tables to reduce local register usage)
local WarpPoints = {}
-- State variables consolidated into single table to reduce local register count
local S = {
    isRecording = false,
    isPaused = false,
    isPlaying = false,
    isPlayPaused = false,
    isLooping = false,
    isGodMode = false,
    playbackSpeed = 1.0,
    isMoonwalk = false,
    isFlexibleRecording = false,
    isStrictRetarget = false,
    isNativeAnim = false,
    isWarpLoop = false,
    isReversing = false,
    isZoomPunch = false,
    lastAirState = nil,
    isRespawnOnEnd = false,
    isLiveSmoothing = false,
    liveSmoothingStrength = 4,
    isPositionBasedPlayback = true, -- New: smoother position-following mode (default ON)
    isBinding = false,
    currentWorkspace = "Default",
    currentMergerWorkspace = "Default",
    GlobalKeyDuration = "N/A",
    TargetMainHeight = 380,
    startTime = 0,
}
-- Alias frequently used state vars for backward compatibility
local isRecording, isPaused, isPlaying, isPlayPaused = S.isRecording, S.isPaused, S.isPlaying, S.isPlayPaused
local isLooping, isGodMode, playbackSpeed, isMoonwalk = S.isLooping, S.isGodMode, S.playbackSpeed, S.isMoonwalk
local isReversing, isZoomPunch, lastAirState, isRespawnOnEnd =
    S.isReversing, S.isZoomPunch, S.lastAirState, S.isRespawnOnEnd
local isFlexibleRecording, isStrictRetarget, isNativeAnim, isWarpLoop =
    S.isFlexibleRecording, S.isStrictRetarget, S.isNativeAnim, S.isWarpLoop
local recordedData = { FPS = 60, Frames = {} }
local startTime = S.startTime
local RefreshPlayerList, ShowConfirm, MainTitle
local TabBtns, ThemeObjects, UIHandlers = {}, {}, {}
-- Pages and UI consolidated
local Pages = {} -- Will hold Dashboard, Record, Play, Merge, ListMap, Tools, Warp, Helper, Fun, Config
local PageDashboard, PageRecord, PagePlay, PageMerge, PageListMap, PageTools, PageWarp, PageHelper, PageFun, PageConfig
local ScreenGui, Main
local TargetMainHeight = S.TargetMainHeight
-- Playback state consolidated
local Playback = { file = nil, time = 0, totalDuration = 0, frameData = {}, lastTime = 0, lastFrameIdx = 1 }
local currentPlaybackFile, currentPlaybackTime, currentTotalDuration, currentFrameData =
    Playback.file, Playback.time, Playback.totalDuration, Playback.frameData
local lastPlaybackTime = Playback.lastTime
local lastFrameIndex = Playback.lastFrameIdx

-- Binary search for frame index (O(log n) instead of O(n))
local function FindFrameIndex(frames, targetTime, hint)
    local n = #frames
    if n < 2 then
        return 1
    end

    -- Use hint (cached index) for nearby search first
    if hint and hint >= 1 and hint < n then
        -- Check if hint is still valid or very close
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
local currentWorkspace, currentMergerWorkspace = S.currentWorkspace, S.currentMergerWorkspace
local GlobalKeyDuration, isBinding = S.GlobalKeyDuration, S.isBinding
local isLiveSmoothing, liveSmoothingStrength = S.isLiveSmoothing, S.liveSmoothingStrength
local isPositionBasedPlayback = S.isPositionBasedPlayback

-- --- HELPER: DEEP COPY & SMOOTH ---
local function DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Catmull-Rom Spline Interpolation for ultra-smooth curves
local function CatmullRomSpline(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    return 0.5 * (
        (2 * p1) +
        (-p0 + p2) * t +
        (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
        (-p0 + 3 * p1 - 3 * p2 + p3) * t3
    )
end

-- Catmull-Rom for Vector3
local function CatmullRomVector3(v0, v1, v2, v3, t)
    return Vector3.new(
        CatmullRomSpline(v0.X, v1.X, v2.X, v3.X, t),
        CatmullRomSpline(v0.Y, v1.Y, v2.Y, v3.Y, t),
        CatmullRomSpline(v0.Z, v1.Z, v2.Z, v3.Z, t)
    )
end

-- Smooth interpolation between two frames using Catmull-Rom (requires 4 frames context)
local function SmoothInterpolateFrames(frames, frameIdx, alpha)
    local n = #frames
    if n < 2 then return nil, nil end

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

local function GetSmoothedFrames(frames, strength, isFlexible)
    local processedFrames = DeepCopy(frames) -- Work on a copy, never touch raw data
    local iterations = math.clamp(strength or 1, 1, 10)

    -- Gaussian kernel radius scales with strength (1-5 neighbors on each side)
    local kernelRadius = math.clamp(math.ceil(strength / 2), 1, 5)
    local sigma = kernelRadius / 2 -- Standard deviation for Gaussian

    for iter = 1, iterations do
        -- Create temporary copy for this iteration to avoid reading modified values
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
                        -- Blend between original and smoothed (preserves sharp corners when needed)
                        local currPos = Vector3.new(curr.pos.x, curr.pos.y, curr.pos.z)
                        local finalPos = currPos:Lerp(smoothedPos, 0.7) -- 70% smooth, 30% original
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
                        -- More aggressive velocity smoothing (reduces jitter)
                        local currVel = Vector3.new(curr.vel.x, curr.vel.y, curr.vel.z)
                        local finalVel = currVel:Lerp(smoothedVel, 0.8) -- 80% smooth
                        curr.vel.x = finalVel.X
                        curr.vel.y = finalVel.Y
                        curr.vel.z = finalVel.Z
                    end
                end

                -- Also smooth rotation for more natural turning
                if curr.rot and type(curr.rot) == "number" then
                    local weightSum = 0
                    local rotSum = 0
                    local baseRot = curr.rot

                    for j = math.max(1, i - kernelRadius), math.min(#tempFrames, i + kernelRadius) do
                        local neighbor = tempFrames[j]
                        if neighbor.rot and type(neighbor.rot) == "number" then
                            local dist = math.abs(j - i)
                            local weight = GaussianWeight(dist, sigma)
                            -- Handle angle wrapping (-180 to 180)
                            local angleDiff = neighbor.rot - baseRot
                            if angleDiff > 180 then angleDiff = angleDiff - 360 end
                            if angleDiff < -180 then angleDiff = angleDiff + 360 end
                            rotSum = rotSum + (baseRot + angleDiff) * weight
                            weightSum = weightSum + weight
                        end
                    end

                    if weightSum > 0 then
                        local smoothedRot = rotSum / weightSum
                        -- Normalize to -180 to 180
                        while smoothedRot > 180 do smoothedRot = smoothedRot - 360 end
                        while smoothedRot < -180 do smoothedRot = smoothedRot + 360 end
                        curr.rot = curr.rot + (smoothedRot - curr.rot) * 0.6 -- 60% blend
                    end
                end
            else
                -- Strict mode: Gaussian-weighted CFrame smoothing
                if curr.r then
                    local weightSum = 0
                    local posSum = Vector3.new(0, 0, 0)
                    local baseCF = TblToCF(curr.r)

                    for j = math.max(1, i - kernelRadius), math.min(#tempFrames, i + kernelRadius) do
                        local neighbor = tempFrames[j]
                        if neighbor.r then
                            local dist = math.abs(j - i)
                            local weight = GaussianWeight(dist, sigma)
                            local neighborCF = TblToCF(neighbor.r)
                            posSum = posSum + neighborCF.Position * weight
                            weightSum = weightSum + weight
                        end
                    end

                    if weightSum > 0 then
                        local smoothedPos = posSum / weightSum
                        local finalPos = baseCF.Position:Lerp(smoothedPos, 0.7)
                        -- For rotation, use neighbors for lerp target
                        local prevIdx = math.max(1, i - 1)
                        local nextIdx = math.min(#tempFrames, i + 1)
                        local prevCF = TblToCF(tempFrames[prevIdx].r)
                        local nextCF = TblToCF(tempFrames[nextIdx].r)
                        local rotAvg = prevCF:Lerp(nextCF, 0.5)
                        local newRot = baseCF:Lerp(rotAvg, 0.5)
                        curr.r = CFToTbl(CFrame.new(finalPos) * newRot.Rotation)
                    end
                end
            end
        end
    end
    return processedFrames
end

-- --- UI HANDLERS ---
function UIHandlers.SetLiveSmoothing(enabled, strength)
    isLiveSmoothing = enabled
    if strength then
        liveSmoothingStrength = strength
    end
end

function UIHandlers.SetPositionBasedPlayback(enabled)
    isPositionBasedPlayback = enabled
end

function UIHandlers.GetPositionBasedPlayback()
    return isPositionBasedPlayback
end

function UIHandlers.SmoothRecording(strength)
    -- Legacy Manual Apply (Keep for editing)
    if not recordedData or not recordedData.Frames or #recordedData.Frames < 3 then
        ShowToast(L("smoothing_failed"), L("not_enough_frames"), "error", 2)
        return
    end
    ShowLoadingModal(true, L("permanent_smoothing"), 0)
    task.wait()
    local isFlexible = (recordedData.Mode == "Flexible") or (recordedData.Frames[1].md ~= nil)
    recordedData.Frames = GetSmoothedFrames(recordedData.Frames, strength, isFlexible)
    ShowLoadingModal(false)
    ShowToast(L("success"), L("path_smoothed"), "success", 2)
    if isPathEnabled then
        GeneratePlaybackPath(recordedData.Frames)
    end
end

-- Callback for spoof name system - updates all UI elements with spoofed name
function UIHandlers.UpdateSpoofedName(fakeName, fakeDisplay)
    -- Update nametag above player's head (if exists)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Head") then
        local tag = char.Head:FindFirstChild("StarshipTag")
        if tag then
            -- Find BillboardGui container
            local container = tag:FindFirstChildWhichIsA("BillboardGui")
            if container then
                -- Find and update the name label in nametag
                for _, child in pairs(container:GetDescendants()) do
                    if child:IsA("TextLabel") and child.Name == "Name" then
                        child.Text = fakeDisplay or fakeName
                        break
                    end
                end
            end
        end
    end

    -- Update Dashboard UI labels
    -- 1. Greeting section name ("Good Evening, DisplayName")
    if UIHandlers.DashboardNameLabel and UIHandlers.DashboardNameLabel.Parent then
        UIHandlers.DashboardNameLabel.Text = fakeDisplay or fakeName
    end

    -- 2. Account info section - Username
    if UIHandlers.DashboardUsernameLabel and UIHandlers.DashboardUsernameLabel.Parent then
        UIHandlers.DashboardUsernameLabel.Text = fakeName
    end

    -- 3. Account info section - Display Name
    if UIHandlers.DashboardDisplayNameLabel and UIHandlers.DashboardDisplayNameLabel.Parent then
        UIHandlers.DashboardDisplayNameLabel.Text = fakeDisplay or fakeName
    end

    -- 4. Sidebar profile name (bottom-left corner) - uses uppercase
    if UIHandlers.SidebarProfileName and UIHandlers.SidebarProfileName.Parent then
        UIHandlers.SidebarProfileName.Text = string.upper(fakeName)
    end

    -- Update any other UI elements that show player name (legacy support)
    if UIHandlers.LocalPlayerNameLabel and UIHandlers.LocalPlayerNameLabel.Parent then
        UIHandlers.LocalPlayerNameLabel.Text = fakeDisplay or fakeName
    end
end

-- --- NOTIFICATION SYSTEM (TOASTS) ---
local function ShowToast(title, message, type, duration)
    if UIModule and UIModule.ShowToast then
        UIModule.ShowToast(title, message, type, duration)
    end
end

local CONFIG_FOLDER = "StarshipCore/StarshipConfigs"
if not isfolder(CONFIG_FOLDER) then
    makefolder(CONFIG_FOLDER)
end

local RECORDER_FOLDER = FOLDER_NAME .. "/Starship_Recorder"
if not isfolder(RECORDER_FOLDER) then
    makefolder(RECORDER_FOLDER)
end

-- Helper Function: Natural Sort untuk files
local function GetWorkspacePath()
    local path = RECORDER_FOLDER .. "/" .. currentWorkspace
    if not isfolder(path) then
        makefolder(path)
    end
    return path
end

local function GetMergerWorkspacePath()
    local path = RECORDER_FOLDER .. "/" .. currentMergerWorkspace
    if not isfolder(path) then
        makefolder(path)
    end
    return path
end

local Connections = {}
local function CleanupConnections()
    for _, c in pairs(Connections) do
        if c then
            c:Disconnect()
        end
    end
    Connections = {}
    if UIHandlers and UIHandlers.CleanupTools then
        pcall(function()
            UIHandlers.CleanupTools()
        end)
    end
end

-- INPUT SINK: Prevent Roblox keybinds (backpack 1-9, etc) when typing in TextBox
local StarterGui = game:GetService("StarterGui")

-- Global variable to track TextBox focus and tool state
local isAnyTextBoxFocused = false
local savedToolBeforeFocus = nil
local toolMonitorConnection = nil

-- Monitor and immediately unequip any new tools while typing
local function StartToolMonitor()
    if toolMonitorConnection then
        return
    end
    toolMonitorConnection = RunService.Heartbeat:Connect(function()
        if not isAnyTextBoxFocused then
            return
        end

        local character = LocalPlayer.Character
        if not character then
            return
        end

        local currentTool = character:FindFirstChildOfClass("Tool")
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        -- If a tool is equipped that wasn't there before, unequip it immediately
        if currentTool and currentTool ~= savedToolBeforeFocus and humanoid then
            humanoid:UnequipTools()
            -- Re-equip original tool if there was one
            if savedToolBeforeFocus and savedToolBeforeFocus.Parent then
                task.defer(function()
                    if humanoid and savedToolBeforeFocus and savedToolBeforeFocus.Parent then
                        humanoid:EquipTool(savedToolBeforeFocus)
                    end
                end)
            end
        end
    end)
end

local function StopToolMonitor()
    if toolMonitorConnection then
        toolMonitorConnection:Disconnect()
        toolMonitorConnection = nil
    end
end

local function SetupTextBoxInputSink(textBox)
    textBox.Focused:Connect(function()
        -- Save current tool state
        local character = LocalPlayer.Character
        savedToolBeforeFocus = character and character:FindFirstChildOfClass("Tool")
        isAnyTextBoxFocused = true

        -- Start monitoring for accidental tool equips
        StartToolMonitor()

        -- Also try disabling backpack GUI
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
        end)
    end)

    textBox.FocusLost:Connect(function()
        isAnyTextBoxFocused = false
        savedToolBeforeFocus = nil
        StopToolMonitor()

        -- Re-enable backpack
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
        end)
    end)
end

local function RegisterTheme(obj, prop, type)
    table.insert(ThemeObjects, { Object = obj, Property = prop, Type = type })
end

local LoadingNotification = nil
local LoadingLabel = nil
local LoadingBar = nil

local function ShowLoadingModal(visible, text, progress)
    if not visible then
        if LoadingNotification then
            LoadingNotification:Destroy()
            LoadingNotification = nil
            LoadingLabel = nil
            LoadingBar = nil
        end
        return
    end

    if not LoadingNotification then
        LoadingNotification = Instance.new("ScreenGui")
        LoadingNotification.Name = "StarshipNotification"
        LoadingNotification.Parent = CoreGui
        LoadingNotification.IgnoreGuiInset = true
        LoadingNotification.DisplayOrder = 10001

        local card = Instance.new("Frame", LoadingNotification)
        card.Size = UDim2.new(0, 220, 0, 50)
        card.Position = UDim2.new(1, 0, 1, -60) -- Start off-screen
        card.BackgroundColor3 = C_MAIN
        card.BackgroundTransparency = 0.1
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", card).Color = C_ACCENT

        LoadingLabel = Instance.new("TextLabel", card)
        LoadingLabel.Text = text or "LOADING..."
        LoadingLabel.Size = UDim2.new(1, -40, 0.6, 0)
        LoadingLabel.Position = UDim2.new(0, 40, 0, 0)
        LoadingLabel.BackgroundTransparency = 1
        LoadingLabel.TextColor3 = C_TEXT
        LoadingLabel.Font = Enum.Font.GothamBold
        LoadingLabel.TextSize = 12
        LoadingLabel.TextXAlignment = Enum.TextXAlignment.Left

        -- Progress Bar Background
        local barBg = Instance.new("Frame", card)
        barBg.Size = UDim2.new(0.8, 0, 0, 4)
        barBg.Position = UDim2.new(0, 40, 0.7, 0)
        barBg.BackgroundColor3 = C_ITEM
        Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

        -- Progress Bar Fill
        LoadingBar = Instance.new("Frame", barBg)
        LoadingBar.Size = UDim2.new(0, 0, 1, 0)
        LoadingBar.BackgroundColor3 = C_ACCENT
        Instance.new("UICorner", LoadingBar).CornerRadius = UDim.new(1, 0)

        local spinner = Instance.new("ImageLabel", card)
        spinner.Size = UDim2.new(0, 20, 0, 20)
        spinner.Position = UDim2.new(0, 10, 0.5, -10)
        spinner.BackgroundTransparency = 1
        spinner.Image = "rbxassetid://3570695787"
        spinner.ImageColor3 = C_ACCENT

        local ts = game:GetService("TweenService")
        ts
            :Create(
                spinner,
                TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
                { Rotation = 360 }
            )
            :Play()
        ts:Create(
            card,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Position = UDim2.new(1, -230, 1, -60) }
        ):Play()
    end

    if LoadingLabel then
        LoadingLabel.Text = text or "LOADING..."
    end
    if LoadingBar then
        local p = math.clamp(progress or 0, 0, 1)
        LoadingBar.Size = UDim2.new(p, 0, 1, 0)
    end
end

-- WHITELIST SYSTEM UI (Firebase - UserId based)

-- --- HELPER FUNCTIONS ---
local function CFToTbl(cf)
    return { cf:GetComponents() }
end
local function TblToCF(t)
    return CFrame.new(unpack(t))
end

-- --- PATH VARIABLES ---
local PathContainer = nil
local lastPathPoint = nil
local isPathEnabled = false -- DEFAULT OFF untuk prevent FPS drop pada merged files

local function GetJoints(char)
    local j = {}
    for _, d in pairs(char:GetDescendants()) do
        if d:IsA("Motor6D") then
            table.insert(j, d)
        end
    end
    return j
end
local function ResetChar()
    local c = LocalPlayer.Character
    if not c then
        return
    end
    local r = c:FindFirstChild("HumanoidRootPart")
    if r then
        r.Anchored = false
        r.AssemblyLinearVelocity = Vector3.new(0, 0, 0) -- Stop momentum
        r.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        if r:FindFirstChild("PlaybackAtt") then
            r.PlaybackAtt:Destroy()
        end
        if r:FindFirstChild("PlaybackAO") then
            r.PlaybackAO:Destroy()
        end
        if r:FindFirstChild("PlaybackAP") then
            r.PlaybackAP:Destroy()
        end
    end

    local h = c:FindFirstChild("Humanoid")
    if h then
        h.AutoRotate = true
        h.PlatformStand = false -- Ensure not stuck in platform stand
        for _, t in pairs(h:GetPlayingAnimationTracks()) do
            t:Stop()
        end
        h:MoveTo(r.Position) -- Cancel any movement
    end

    local a = c:FindFirstChild("Animate")
    if a then
        a.Disabled = true
        task.wait() -- Yield to ensure script stops
        a.Disabled = false
    end
end

-- --- PATH VISUALIZER ---
local function InitPathFolder()
    if not PathContainer or not PathContainer.Parent then
        PathContainer = Instance.new("Folder", workspace)
        PathContainer.Name = "WalkGemPath"
    end
end
local function ClearPath()
    if PathContainer then
        PathContainer:ClearAllChildren()
    end
    lastPathPoint = nil
end
local function DrawLine(p1, p2, color)
    InitPathFolder()
    local dist = (p1 - p2).Magnitude
    if dist < 0.1 then
        return
    end
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = color or Color3.fromRGB(255, 50, 50)
    part.Size = Vector3.new(0.1, 0.1, dist)
    part.CFrame = CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -dist / 2)
    part.Parent = PathContainer
    return part
end

local function UpdatePathColor(newColor)
    if PathContainer then
        for _, part in pairs(PathContainer:GetChildren()) do
            if part:IsA("Part") and part.Name ~= "StartBaseplate" then
                part.Color = newColor
            end
        end
    end
end

local function CreateStartBaseplate(pos)
    InitPathFolder()
    local p = Instance.new("Part")
    p.Name = "StartBaseplate"
    p.Anchored = true
    p.CanCollide = false
    p.Size = Vector3.new(4, 0.2, 4)
    p.Color = Color3.fromRGB(0, 255, 0)
    p.Material = Enum.Material.Neon
    p.Transparency = 0.5
    p.CFrame = CFrame.new(pos - Vector3.new(0, 2.8, 0))
    p.Parent = PathContainer
end

local function GeneratePlaybackPath(frames)
    ClearPath()
    if not isPathEnabled or not frames or #frames < 2 then
        return
    end
    task.spawn(function()
        local totalFrames = #frames
        local MAX_PATH_POINTS = 500 -- Limit untuk prevent lag

        -- Calculate adaptive step size based on file size
        local step = math.max(1, math.floor(totalFrames / MAX_PATH_POINTS))

        local startFrame = frames[1]
        local prevPos = (startFrame.pos and Vector3.new(startFrame.pos.x, startFrame.pos.y, startFrame.pos.z))
            or (startFrame.r and TblToCF(startFrame.r).Position)
        if not prevPos then
            return
        end

        local pointsCreated = 0
        local MIN_DISTANCE = step > 5 and 3.0 or 1.0 -- Larger min distance for big files

        for i = step, totalFrames, step do
            if not isPlaying and not isPlayPaused then
                break
            end
            local f = frames[i]
            local pos = (f.pos and Vector3.new(f.pos.x, f.pos.y, f.pos.z)) or (f.r and TblToCF(f.r).Position)

            if pos and (pos - prevPos).Magnitude > MIN_DISTANCE then
                DrawLine(prevPos, pos, currentPathColor)
                prevPos = pos
                pointsCreated = pointsCreated + 1

                -- Yield every 50 points to prevent freeze
                if pointsCreated % 50 == 0 then
                    RunService.Heartbeat:Wait()
                end
            end
        end

        -- Always include last frame for accuracy
        local lastFrame = frames[totalFrames]
        local lastPos = (lastFrame.pos and Vector3.new(lastFrame.pos.x, lastFrame.pos.y, lastFrame.pos.z))
            or (lastFrame.r and TblToCF(lastFrame.r).Position)
        if lastPos and prevPos and (lastPos - prevPos).Magnitude > MIN_DISTANCE then
            DrawLine(prevPos, lastPos, currentPathColor)
        end
    end)
end

-- --- RECORDER ---
local function StopRecording()
    isRecording = false
    isPaused = false
    if Connections.Record then
        Connections.Record:Disconnect()
    end
    if Connections.Preview then
        Connections.Preview:Disconnect()
    end
    ResetChar()
end
local function StartRecording()
    if isRecording or isPlaying then
        return
    end
    local c = LocalPlayer.Character
    if not c then
        return
    end

    -- CLEANUP PREVIOUS PATHS
    ClearPath()
    if PathContainer then
        PathContainer:ClearAllChildren()
    end

    isRecording = true
    isPaused = false
    recordedData = { FPS = 60, Frames = {} }
    startTime = os.clock()
    local joints = GetJoints(c)
    CreateStartBaseplate(c.HumanoidRootPart.Position)
    lastPathPoint = c.HumanoidRootPart.Position

    Connections.Record = RunService.Heartbeat:Connect(function()
        if isPaused then
            return
        end
        if not c.Parent then
            StopRecording()
            return
        end
        local r = c:FindFirstChild("HumanoidRootPart")
        local h = c:FindFirstChild("Humanoid")
        if not r or not h then
            return
        end

        local fd = { t = os.clock() - startTime }

        if isFlexibleRecording then
            -- FLEXIBLE MODE: Record Physics & Inputs
            fd.pos = { x = r.Position.X, y = r.Position.Y, z = r.Position.Z }
            fd.rot = r.Orientation.Y -- Only Y rotation needed for movement
            fd.vel = { x = r.AssemblyLinearVelocity.X, y = r.AssemblyLinearVelocity.Y, z = r.AssemblyLinearVelocity.Z }
            fd.md = { x = h.MoveDirection.X, y = h.MoveDirection.Y, z = h.MoveDirection.Z }
            fd.st = tostring(h:GetState())
            fd.jmp = h.Jump
            fd.hh = h.HipHeight

            -- SHIFTLOCK / CAMERA DIRECTION RECORDING
            local cam = workspace.CurrentCamera
            if cam then
                local camLook = cam.CFrame.LookVector
                fd.camLook = { x = camLook.X, y = camLook.Y, z = camLook.Z }
            end
            -- Check if shiftlock is active (character faces camera direction)
            local isShiftlock = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
            fd.shiftlock = isShiftlock
            -- Record character's actual facing direction (for accurate rotation)
            local charLook = r.CFrame.LookVector
            fd.charLook = { x = charLook.X, y = charLook.Y, z = charLook.Z }

            -- TOOL RECORDING: Record equipped tool name
            local equippedTool = c:FindFirstChildOfClass("Tool")
            if equippedTool then
                fd.tool = equippedTool.Name
            end
        else
            -- STRICT MODE: Record Full Pose (Existing Logic)
            fd.r = CFToTbl(r.CFrame)
            fd.j = {}
            for _, m in ipairs(joints) do
                fd.j[m.Name] = CFToTbl(m.Transform)
            end

            -- TOOL RECORDING: Record equipped tool name (Strict Mode)
            local equippedTool = c:FindFirstChildOfClass("Tool")
            if equippedTool then
                fd.tool = equippedTool.Name
            end
        end

        table.insert(recordedData.Frames, fd)
        if isPathEnabled then
            local cp = r.Position
            if (cp - lastPathPoint).Magnitude > 0.5 then
                DrawLine(lastPathPoint, cp, currentPathColor)
                lastPathPoint = cp
            end
        end
    end)
end
local function CutAndResume(cutTime)
    if Connections.Preview then
        Connections.Preview:Disconnect()
    end
    if not recordedData.Frames or #recordedData.Frames == 0 then
        return
    end
    local nf = {}
    for _, f in ipairs(recordedData.Frames) do
        if f.t <= cutTime then
            table.insert(nf, f)
        end
    end
    recordedData.Frames = nf
    ClearPath()

    if isPathEnabled then
        local pp = nil
        for _, f in ipairs(nf) do
            local pos = (f.pos and Vector3.new(f.pos.x, f.pos.y, f.pos.z)) or (f.r and TblToCF(f.r).Position)
            if pos then
                if pp and (pos - pp).Magnitude > 0.5 then
                    DrawLine(pp, pos, Color3.fromRGB(255, 50, 50))
                    pp = pos
                elseif not pp then
                    pp = pos
                end
            end
        end
        if pp then
            lastPathPoint = pp
        end
    end

    local lf = nf[#nf]
    if lf then
        local c = LocalPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if r then
            r.Anchored = false
            local a = c:FindFirstChild("Animate")
            if a then
                a.Disabled = false
            end

            if lf.r then
                -- Strict mode: restore CFrame and joints
                r.CFrame = TblToCF(lf.r)
                local j = GetJoints(c)
                if lf.j then
                    for _, m in ipairs(j) do
                        if lf.j[m.Name] then
                            m.Transform = TblToCF(lf.j[m.Name])
                        end
                    end
                end
            elseif lf.pos then
                -- Flexible mode: restore position and velocity
                r.CFrame = CFrame.new(lf.pos.x, lf.pos.y, lf.pos.z) * CFrame.Angles(0, math.rad(lf.rot or 0), 0)
                if lf.vel then
                    r.AssemblyLinearVelocity = Vector3.new(lf.vel.x, lf.vel.y, lf.vel.z)
                end
            end
        end
        startTime = os.clock() - lf.t
    else
        startTime = os.clock()
    end
    isPaused = false
end

local function SaveRecording(fn)
    if not recordedData.Frames or #recordedData.Frames == 0 then
        return
    end
    recordedData.Mode = isFlexibleRecording and "Flexible" or "Strict"
    writefile(GetWorkspacePath() .. "/" .. fn .. ".json", HttpService:JSONEncode(recordedData))
    ClearPath()
    ShowToast(L("recording_saved"), L("frames_saved", #recordedData.Frames, fn), "success", 2)
    if RefreshPlayerList then
        RefreshPlayerList()
    end -- Auto Refresh UI
    if UIHandlers.RefreshMergerList then
        UIHandlers.RefreshMergerList()
    end -- Auto Refresh Merge UI
end
-- ZOOM PUNCH EFFECT FUNCTION
local defaultFOV = 70
local currentZoomTween = nil
local function SetZoomState(state)
    if not isZoomPunch then
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then
        return
    end

    -- Cancel previous tween
    if currentZoomTween then
        currentZoomTween:Cancel()
    end

    local targetFOV = defaultFOV
    if state == "jump" then
        targetFOV = defaultFOV + 15 -- Zoom OUT saat loncat
    elseif state == "fall" then
        targetFOV = defaultFOV - 10 -- Zoom IN saat jatuh
    else
        targetFOV = defaultFOV      -- Normal
    end

    currentZoomTween = TweenService:Create(
        cam,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { FieldOfView = targetFOV }
    )
    currentZoomTween:Play()
end

local function StopPlayback()
    isPlaying = false
    isPlayPaused = false
    isReversing = false
    lastAirState = nil
    SetZoomState("normal")
    if Connections.Playback then
        Connections.Playback:Disconnect()
    end
    currentPlaybackTime = 0
    lastPlaybackTime = 0
    -- Do NOT clear currentPlaybackFile here, as it breaks replayability from the UI
    ResetChar()
    ClearPath()

    -- Reset WalkSpeed to default when stopping
    local c = LocalPlayer.Character
    local hum = c and c:FindFirstChild("Humanoid")
    if hum then
        hum.WalkSpeed = 16
        -- Stop any movement input
        hum:Move(Vector3.new(0, 0, 0))
    end

    -- Keep playback speed setting (don't reset to 1x)

    -- Update UI if Merger Source
    if currentPlaybackSource == "Merger" and PBtnPlay then
        PBtnPlay.Text = L("play")
        PBtnPlay.TextColor3 = C_GREEN
        PSliderFill.Size = UDim2.new(0, 0, 1, 0)
        if currentTotalDuration then
            PTimeLbl.Text = string.format("0.0s / %.1fs", currentTotalDuration)
        end
    end
end

local function PausePlayback()
    if isPlaying then
        isPlayPaused = true
        isPlaying = false
        if Connections.Playback then
            Connections.Playback:Disconnect()
        end
        local c = LocalPlayer.Character
        if c then
            local r = c:FindFirstChild("HumanoidRootPart")
            if r then
                r.Anchored = false
                -- Cleanup Physics Constraints
                local ao = r:FindFirstChild("PlaybackAO")
                if ao then
                    ao:Destroy()
                end
                local ap = r:FindFirstChild("PlaybackAP")
                if ap then
                    ap:Destroy()
                end
                local att = r:FindFirstChild("PlaybackAtt")
                if att then
                    att:Destroy()
                end
            end
            local a = c:FindFirstChild("Animate")
            if a then
                a.Disabled = false
            end
            local h = c:FindFirstChild("Humanoid")
            if h then
                h.AutoRotate = true
            end
        end
    end
end

local MAP_DISTANCE_THRESHOLD = 500 -- Jarak maksimal sebelum warning (dalam studs)

-- Cek jarak ke titik TERDEKAT di path (bukan hanya titik awal)
local function GetDistanceToNearestPathPoint(frames, playerPos)
    if not frames or #frames == 0 or not playerPos then
        return math.huge
    end

    local minDist = math.huge
    local sampleInterval = math.max(1, math.floor(#frames / 20)) -- Sample setiap ~5% frames untuk performa

    for i = 1, #frames, sampleInterval do
        local frame = frames[i]
        local framePos = nil

        if frame.pos then
            framePos = Vector3.new(frame.pos.x, frame.pos.y, frame.pos.z)
        elseif frame.r then
            framePos = TblToCF(frame.r).Position
        end

        if framePos then
            local dist = (playerPos - framePos).Magnitude
            if dist < minDist then
                minDist = dist
            end
            -- Early exit jika sudah cukup dekat
            if minDist < MAP_DISTANCE_THRESHOLD then
                return minDist
            end
        end
    end

    return minDist
end

-- PERFORMANCE OPTIMIZATION: Pre-calculate expensive operations
local function PreprocessFrames(frames)
    if not frames or #frames == 0 then
        return frames
    end

    for i, frame in ipairs(frames) do
        -- Pre-calculate Vector3 for positions
        if frame.pos then
            frame.posVector = Vector3.new(frame.pos.x, frame.pos.y, frame.pos.z)
        end

        -- Pre-calculate Vector3 for velocities
        if frame.vel then
            frame.velVector = Vector3.new(frame.vel.x, frame.vel.y, frame.vel.z)
        end

        -- Pre-calculate Vector3 for move direction
        if frame.md then
            frame.mdVector = Vector3.new(frame.md.x, frame.md.y, frame.md.z)
        end

        -- Pre-parse state enum (expensive string.match)
        if frame.st then
            frame.stEnum = string.match(frame.st, "Enum%.HumanoidStateType%.(%w+)")
        end

        -- Pre-calculate camera look vector
        if frame.camLook then
            frame.camLookVector = Vector3.new(frame.camLook.x, frame.camLook.y, frame.camLook.z)
        end

        -- Pre-calculate character look vector
        if frame.charLook then
            frame.charLookVector = Vector3.new(frame.charLook.x, frame.charLook.y, frame.charLook.z)
        end

        -- Yield every 1000 frames to prevent freeze on large files
        if i % 1000 == 0 then
            task.wait()
        end
    end

    return frames
end

local function PlayRecording(fn, force, skipDistanceCheck)
    ShowToast(L("loading_playback"), L("preparing", fn), "info", 1.5)
    task.wait(0.1) -- Allow UI to render

    local p = GetWorkspacePath() .. "/" .. fn
    if not isfile(p) then
        -- Try checking Merger folder if not found in main folder
        p = MERGER_FOLDER .. "/" .. fn
        if not isfile(p) then
            ShowToast(L("error"), L("file_not_found") .. ": " .. fn, "error", 3)
            return
        end
    end

    if isRecording then
        StopRecording()
    end

    local isResuming = (currentPlaybackFile == fn and not force and isPlayPaused)

    if currentPlaybackFile ~= fn or force or not currentFrameData then
        StopPlayback()
        local s, j = pcall(readfile, p)
        if not s then
            ShowLoadingModal(false)
            return
        end
        local d = HttpService:JSONDecode(j)

        -- LIVE SMOOTHING INJECTION
        local framesToPlay = d.Frames or d

        -- PERFORMANCE: Pre-process frames BEFORE smoothing
        ShowLoadingModal(true, L("optimizing_frames"), 0.3)
        framesToPlay = PreprocessFrames(framesToPlay)

        if isLiveSmoothing and #framesToPlay > 3 then
            local isFlex = (d.Mode == "Flexible") or (framesToPlay[1].md ~= nil)
            ShowLoadingModal(true, L("auto_smoothing"), 0.5)
            task.wait() -- Allow UI update
            framesToPlay = GetSmoothedFrames(framesToPlay, liveSmoothingStrength, isFlex)
            -- Re-process after smoothing (smoothing may change values)
            framesToPlay = PreprocessFrames(framesToPlay)
            ShowToast(L("live_smoothing"), L("applied_smoothing", liveSmoothingStrength), "info", 2)
        end

        currentFrameData = framesToPlay
        currentPlaybackFile = fn
        currentPlaybackTime = 0

        -- MAP/GAME DISTANCE VALIDATION (Check distance to nearest path point)
        if not skipDistanceCheck then
            local c = LocalPlayer.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if r and #currentFrameData > 0 then
                local dist = GetDistanceToNearestPathPoint(currentFrameData, r.Position)

                if dist > MAP_DISTANCE_THRESHOLD then
                    -- Show warning toast immediately
                    ShowToast(
                        L("warning_different_map"),
                        L("nearest_path_warning", dist),
                        "warning",
                        5
                    )

                    -- Also show confirmation dialog if ShowConfirm is available
                    if ShowConfirm then
                        ShowConfirm(
                            L("different_map_detected"),
                            L("nearest_path_warning", dist) .. "\n\n" .. L("continue_anyway"),
                            function()
                                -- User confirmed, play with skip flag
                                PlayRecording(fn, true, true)
                            end
                        )
                        return -- Stop current execution, wait for user confirmation
                    end
                end
            end
        end
    elseif currentPlaybackTime >= (currentFrameData[#currentFrameData].t - 0.1) then
        -- Reset to 0 if we are at the end (Replay)
        currentPlaybackTime = 0
    end

    if not currentFrameData or #currentFrameData < 2 then
        ShowLoadingModal(false)
        return
    end
    currentTotalDuration = currentFrameData[#currentFrameData].t
    local c = LocalPlayer.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if not r then
        ShowLoadingModal(false)
        return
    end
    local h = c:FindFirstChild("Humanoid")
    local a = c:FindFirstChild("Animate")

    -- SMART RESUME / SMART START
    -- Always check for nearest point if resuming OR if starting fresh (to support mid-path start)
    if true then
        ShowLoadingModal(true, L("finding_position"))
        task.wait()

        local bestT, minDst = currentPlaybackTime, math.huge
        local rPos = r.Position

        -- Check frames to find closest point
        -- Optimization: Step by 5 to save performance on huge files
        local step = math.max(1, math.floor(#currentFrameData / 500))

        for i = 1, #currentFrameData, step do
            if i % 50 == 0 then
                task.wait()
            end -- Yield to prevent freeze

            local f = currentFrameData[i]
            local pos = (f.pos and Vector3.new(f.pos.x, f.pos.y, f.pos.z)) or (f.r and TblToCF(f.r).Position)
            if pos then
                local dst = (rPos - pos).Magnitude
                if dst < minDst then
                    minDst = dst
                    bestT = f.t
                end
            end
        end

        -- Explicitly check the last frame to ensure we don't miss the end due to stepping
        local lastF = currentFrameData[#currentFrameData]
        local lastPos = (lastF.pos and Vector3.new(lastF.pos.x, lastF.pos.y, lastF.pos.z))
            or (lastF.r and TblToCF(lastF.r).Position)
        if lastPos then
            local dst = (rPos - lastPos).Magnitude
            if dst < minDst then
                minDst = dst
                bestT = lastF.t
            end
        end

        -- If we are starting from 0 (not resuming), only jump if we are close enough to the path
        if not isResuming then
            -- If the nearest point is within the last 2 seconds, force restart from 0
            if bestT >= (currentTotalDuration - 2.0) then
                currentPlaybackTime = 0
                -- Snap to Start: If nearest point is within first 1 second, start from 0
            elseif bestT < 1.0 then
                currentPlaybackTime = 0
            elseif minDst < 500 then -- Increased threshold for Smart Start
                currentPlaybackTime = bestT
            end
        else
            -- If resuming from pause, always jump to closest (existing logic)
            currentPlaybackTime = bestT
        end
    end

    isPlaying = true
    isPlayPaused = false
    lastPlaybackTime = currentPlaybackTime

    -- 1. PATH VISUAL
    if isPathEnabled then
        ShowLoadingModal(true, L("generating_path"))
        task.wait()
        GeneratePlaybackPath(currentFrameData)
    else
        ClearPath()
    end

    -- 2. TRAVEL PHASE
    local startFrame = currentFrameData[1]
    local targetPos = (startFrame.pos and Vector3.new(startFrame.pos.x, startFrame.pos.y, startFrame.pos.z))
        or (startFrame.r and TblToCF(startFrame.r).Position)

    if currentPlaybackTime > 0 then
        for i = 1, #currentFrameData do
            if currentFrameData[i].t >= currentPlaybackTime then
                local f = currentFrameData[i]
                targetPos = (f.pos and Vector3.new(f.pos.x, f.pos.y, f.pos.z)) or (f.r and TblToCF(f.r).Position)
                break
            end
        end
    end

    ShowLoadingModal(false)

    if targetPos then
        if startFrame.r then
            CreateStartBaseplate(targetPos)
        end -- Only create baseplate if we have a position

        -- Use horizontal distance to prevent getting stuck due to height differences
        local flatPos = r.Position * Vector3.new(1, 0, 1)
        local flatTarget = targetPos * Vector3.new(1, 0, 1)
        local dist = (flatPos - flatTarget).Magnitude

        if dist > 3 then
            r.Anchored = false
            if a then
                a.Disabled = false
            end
            h:MoveTo(targetPos)

            -- Timeout safety
            local moveStart = os.clock()

            while isPlaying do
                local currFlat = r.Position * Vector3.new(1, 0, 1)
                local d = (currFlat - flatTarget).Magnitude

                if d <= 2 then
                    break
                end

                -- If stuck for 5 seconds but close (within 10 studs), just snap
                if os.clock() - moveStart > 5 and d < 10 then
                    r.CFrame = CFrame.new(targetPos) * r.CFrame.Rotation
                    break
                end

                if not isPlaying then
                    h:MoveTo(r.Position)
                    return
                end

                -- Refresh MoveTo every second
                if (os.clock() - moveStart) % 1 < 0.1 then
                    h:MoveTo(targetPos)
                end

                task.wait(0.1)
            end
            h:MoveTo(r.Position)
        end
    end

    if not isPlaying then
        return
    end

    -- 3. PLAYBACK PHASE
    local isFlexible = (currentFrameData.Mode == "Flexible") or (currentFrameData[1].md ~= nil) -- Auto-detect

    if isFlexible then
        -- FLEXIBLE MODE: Physics & Input Replay
        r.Anchored = false

        -- Restart Animate script to ensure it picks up
        if a then
            a.Disabled = true
            task.wait() -- Small yield to ensure reset
            a.Disabled = false
        end

        h.AutoRotate = true -- Enable auto-rotate so character looks in movement direction naturally or can be controlled

        -- PERFORMANCE: Cache instances ONCE before playback loop
        local cachedAtt = r:FindFirstChild("PlaybackAtt") or Instance.new("Attachment", r)
        cachedAtt.Name = "PlaybackAtt"
        local cachedAO = nil        -- Will be created when needed
        local frameCounter = 0      -- For throttling expensive operations
        local cachedLastState = nil -- Cache last humanoid state to avoid redundant changes
        local cachedUserInputService = game:GetService("UserInputService")

        -- PERFORMANCE: Cached key state for throttled checking
        local cachedKeys = {}
        local lastKeyCheck = 0
        local KEY_CHECK_INTERVAL = 0.1 -- Check keys every 0.1s instead of every 2 frames

        -- Use Stepped for Physics Manipulation (smoother for velocity)
        Connections.Playback = RunService.Stepped:Connect(function(_, dt)
            frameCounter = frameCounter + 1
            if not isPlaying or isPlayPaused then
                return
            end

            -- REVERSE PLAYBACK SUPPORT
            if isReversing then
                currentPlaybackTime = currentPlaybackTime - (dt * playbackSpeed)
                if currentPlaybackTime <= 0 then
                    if isRespawnOnEnd then
                        local savedFile = currentPlaybackFile
                        local savedLoop = isLooping
                        StopPlayback()
                        ShowToast(L("respawn"), L("respawning_in"), "info", 5)
                        task.wait(5)
                        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
                        if h then
                            h.Health = 0
                        end
                        if savedLoop then
                            task.spawn(function()
                                LocalPlayer.CharacterAdded:Wait()
                                ShowToast(L("loop"), L("restarting_playback"), "info", 5)
                                task.wait(5)
                                if savedFile and UIHandlers.PlayMergerRecording then
                                    UIHandlers.PlayMergerRecording(savedFile, true)
                                end
                            end)
                        end
                        return
                    elseif isLooping then
                        currentPlaybackTime = currentTotalDuration
                    else
                        StopPlayback()
                        return
                    end
                end
            else
                currentPlaybackTime = currentPlaybackTime + (dt * playbackSpeed)
                if currentPlaybackTime >= currentTotalDuration then
                    if isRespawnOnEnd then
                        local savedFile = currentPlaybackFile
                        local savedLoop = isLooping
                        StopPlayback()
                        ShowToast(L("respawn"), L("respawning_in"), "info", 5)
                        task.wait(5)
                        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
                        if h then
                            h.Health = 0
                        end
                        if savedLoop then
                            task.spawn(function()
                                LocalPlayer.CharacterAdded:Wait()
                                ShowToast(L("loop"), L("restarting_playback"), "info", 5)
                                task.wait(5)
                                if savedFile and UIHandlers.PlayMergerRecording then
                                    UIHandlers.PlayMergerRecording(savedFile, true)
                                end
                            end)
                        end
                        return
                    elseif isLooping then
                        currentPlaybackTime = 0
                    else
                        StopPlayback()
                        return
                    end
                end
            end

            -- DETECT TIME JUMP (slider seeking) - skip blending if user jumped to different time
            local expectedDelta = dt * playbackSpeed
            local actualDelta = math.abs(currentPlaybackTime - lastPlaybackTime)
            local isTimeJump = actualDelta > (expectedDelta * 3 + 0.1) -- Threshold: 3x expected + 0.1s buffer
            lastPlaybackTime = currentPlaybackTime

            -- Find Frames (optimized with binary search + caching)
            local frameIdx = FindFrameIndex(currentFrameData, currentPlaybackTime, lastFrameIndex)
            lastFrameIndex = frameIdx
            local fA, fB = currentFrameData[frameIdx], currentFrameData[frameIdx + 1]

            if fA and fB then
                local deltaT = fB.t - fA.t
                local alpha = 0
                if deltaT > 0.0001 then
                    alpha = (currentPlaybackTime - fA.t) / deltaT
                end

                -- 1. Apply Velocity / Position
                -- Check current state
                local isCurrentlyClimbing = false
                local isCurrentlySwimming = false
                if fA.st then
                    local stName = string.match(fA.st, "Enum%.HumanoidStateType%.(%w+)")
                    isCurrentlyClimbing = (stName == "Climbing")
                    isCurrentlySwimming = (stName == "Swimming")
                end

                if isCurrentlyClimbing or isCurrentlySwimming then
                    -- Climbing/Swimming: Use recorded velocity and simulate input for natural animation
                    local vel = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
                        :Lerp(Vector3.new(fB.vel.x, fB.vel.y, fB.vel.z), alpha)

                    -- Scale velocity by playback speed for proper animation timing
                    vel = vel * playbackSpeed
                    if isReversing then
                        vel = -vel
                    end

                    -- CRITICAL FIX: Control climbing animation speed directly via AnimationTrack
                    if fA.md then
                        local moveDir = Vector3.new(fA.md.x, fA.md.y, fA.md.z)
                        if isReversing then
                            moveDir = -moveDir
                        end

                        -- Apply movement input
                        h:Move(moveDir)
                        h:ChangeState(Enum.HumanoidStateType.Climbing)

                        -- DIRECT ANIMATION SPEED CONTROL: Find and adjust climbing animation speed
                        local animator = h:FindFirstChildOfClass("Animator")
                        if animator then
                            local playingTracks = animator:GetPlayingAnimationTracks()
                            for _, track in ipairs(playingTracks) do
                                local animName = track.Animation and track.Animation.Name or ""
                                -- Check if this is a climbing animation
                                if string.lower(animName):find("climb") or track.IsPlaying then
                                    -- Adjust animation speed based on recorded velocity
                                    local targetSpeed = vel.Magnitude / 12 * playbackSpeed -- 12 is default climb speed
                                    targetSpeed = math.max(0.5, targetSpeed)               -- Minimum speed
                                    track:AdjustSpeed(targetSpeed)
                                end
                            end
                        end
                    elseif vel.Magnitude > 0.1 then
                        -- Fallback: calculate movement direction from velocity if MoveDirection not recorded
                        local worldMoveDir = vel.Unit
                        local charCF = r.CFrame
                        local localMoveDir = charCF:VectorToObjectSpace(worldMoveDir)
                        local moveScale = vel.Magnitude / 16 * playbackSpeed * 25.0 -- Maximum extreme scaling
                        local moveVector = Vector3.new(localMoveDir.X, localMoveDir.Y, localMoveDir.Z) * moveScale
                        h:Move(moveVector)
                    else
                        h:Move(Vector3.new(0, 0, 0))
                    end

                    -- Set actual velocity for physics movement
                    r.AssemblyLinearVelocity = vel

                    -- Position correction with smooth blending
                    local targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z)
                        :Lerp(Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha)
                    local targetYaw = fA.rot

                    -- Light position correction to stay on path while allowing natural movement
                    local currentPos = r.Position
                    local positionBlend = 0.3 -- More natural movement, less strict positioning
                    local smoothPos = currentPos:Lerp(targetPos, positionBlend)

                    if type(targetYaw) == "number" then
                        r.CFrame = CFrame.new(smoothPos) * CFrame.Angles(0, math.rad(targetYaw), 0)
                    else
                        r.CFrame = CFrame.new(smoothPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
                    end

                    -- Ensure climbing state
                    h:ChangeState(Enum.HumanoidStateType.Climbing)
                elseif fA.vel and fB.vel then
                    -- Normal: Interpolate velocity and scale by playback speed
                    local vel = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
                        :Lerp(Vector3.new(fB.vel.x, fB.vel.y, fB.vel.z), alpha)
                    vel = vel * playbackSpeed -- Scale velocity by playback speed
                    -- Invert velocity when reversing for smooth backward motion
                    if isReversing then
                        vel = -vel
                    end

                    -- IMPROVED: Higher velocity blending for smoother transitions
                    local currentVel = r.AssemblyLinearVelocity
                    local baseBlend = isReversing and 0.7 or 0.85                        -- Increased from 0.4/0.6
                    local blendFactor = math.clamp(baseBlend * playbackSpeed, 0.5, 0.98) -- Higher minimum and cap

                    -- Check if in air state - use position-based for smooth jump like recording
                    local stName = fA.st and string.match(fA.st, "Enum%.HumanoidStateType%.(%w+)")
                    local isInAir = (stName == "Jumping" or stName == "Freefall")

                    -- IMPROVED: Use Catmull-Rom spline for ALL states (not just air)
                    local smoothPos, smoothVel = SmoothInterpolateFrames(currentFrameData, frameIdx, alpha)

                    if isInAir and smoothPos then
                        -- Follow recorded position for smooth jump arc (like recording)
                        local targetPos = smoothPos -- Use Catmull-Rom interpolated position
                        -- On time jump or high speed, snap directly to target position
                        if isTimeJump or playbackSpeed >= 2 then
                            r.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
                            r.AssemblyLinearVelocity = vel
                        else
                            -- Smoothly move to target position
                            local currentPos = r.Position
                            local posBlend = math.clamp(0.5 * playbackSpeed, 0.3, 0.9)
                            local newPos = currentPos:Lerp(targetPos, posBlend)
                            r.CFrame = CFrame.new(newPos) * r.CFrame.Rotation

                            -- Use RECORDED velocity for animation (not calculated)
                            local recordedVelY = fA.vel and fA.vel.y or 0
                            local horizVel = (targetPos - currentPos) * 10 * playbackSpeed
                            r.AssemblyLinearVelocity = Vector3.new(horizVel.X, recordedVelY * playbackSpeed, horizVel.Z)
                        end
                    else
                        -- IMPROVED: Position-based playback option for ground too (smoother)
                        if isTimeJump or playbackSpeed >= 2 then
                            -- Use smooth velocity from Catmull-Rom if available
                            r.AssemblyLinearVelocity = smoothVel or vel
                            -- Also snap position to prevent drift at high speeds
                            if smoothPos then
                                r.CFrame = CFrame.new(smoothPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
                            elseif fA.pos then
                                local targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z)
                                    :Lerp(Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha)
                                r.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
                            end
                        else
                            -- IMPROVED: Position-Based Playback mode (smoother ground movement)
                            if isPositionBasedPlayback and smoothPos then
                                -- Position-based: Use VELOCITY for animation, but with STRONG position correction
                                -- This keeps animations working while following path accurately
                                local currentPos = r.Position
                                local posDiff = smoothPos - currentPos
                                local distance = posDiff.Magnitude

                                -- Calculate target velocity that will move us toward the path
                                -- Use stronger multiplier for tighter path following
                                local correctionStrength = math.clamp(distance * 8, 0, 50) -- Stronger correction
                                local correctionVel = distance > 0.01 and (posDiff.Unit * correctionStrength) or
                                    Vector3.new(0, 0, 0)

                                -- Blend with recorded velocity for smooth acceleration
                                local targetVel = smoothVel or vel
                                local finalVel = targetVel + correctionVel

                                -- Apply velocity (this allows physics and animations to work properly)
                                r.AssemblyLinearVelocity = currentVel:Lerp(finalVel, 0.85)

                                -- Only snap position if WAY off (fallback safety)
                                if distance > 8 then
                                    local snapPos = currentPos:Lerp(smoothPos, 0.5)
                                    r.CFrame = CFrame.new(snapPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
                                end

                                -- CRITICAL: Trigger walk/run animation using h:Move()
                                -- Use recorded MoveDirection for accurate animation
                                if fA.md then
                                    local moveDir = Vector3.new(fA.md.x, fA.md.y, fA.md.z)
                                    if moveDir.Magnitude > 0.01 then
                                        h:Move(moveDir, false) -- false = relative to world, not camera
                                    else
                                        h:Move(Vector3.new(0, 0, 0))
                                    end
                                elseif finalVel.Magnitude > 0.5 then
                                    -- Calculate move direction from velocity
                                    local flatVel = Vector3.new(finalVel.X, 0, finalVel.Z)
                                    if flatVel.Magnitude > 0.1 then
                                        h:Move(flatVel.Unit, false)
                                    end
                                else
                                    h:Move(Vector3.new(0, 0, 0))
                                end
                            else
                                -- Velocity-based fallback (original hybrid approach)
                                local targetVel = smoothVel or vel
                                r.AssemblyLinearVelocity = currentVel:Lerp(targetVel, blendFactor)

                                -- Subtle position correction to prevent drift
                                if smoothPos then
                                    local posDiff = (smoothPos - r.Position)
                                    local posCorrection = posDiff * 0.2 -- Increased from 0.15 for better tracking
                                    r.AssemblyLinearVelocity = r.AssemblyLinearVelocity + posCorrection
                                end

                                -- CRITICAL FIX: Trigger walk/run animation using h:Move()
                                if fA.md then
                                    local moveDir = Vector3.new(fA.md.x, fA.md.y, fA.md.z)
                                    if moveDir.Magnitude > 0.01 then
                                        h:Move(moveDir, false)
                                    else
                                        h:Move(Vector3.new(0, 0, 0))
                                    end
                                elseif targetVel.Magnitude > 0.5 then
                                    local flatVel = Vector3.new(targetVel.X, 0, targetVel.Z)
                                    if flatVel.Magnitude > 0.1 then
                                        h:Move(flatVel.Unit, false)
                                    end
                                else
                                    h:Move(Vector3.new(0, 0, 0))
                                end
                            end
                        end
                    end
                end

                -- 2. Apply Rotation - DISABLED to allow user control
                -- We remove the forced AlignOrientation so the user can look around or let AutoRotate handle it
                -- PERFORMANCE: Use cached AO reference instead of FindFirstChild every frame
                if cachedAO then
                    cachedAO.Enabled = false
                end

                -- 3. Apply Move Direction (Smart Rotation)
                -- PERFORMANCE: Throttled key check (tick-based instead of frame-based)
                local isUserMoving = false
                local now = tick()
                if now - lastKeyCheck > KEY_CHECK_INTERVAL then
                    cachedKeys = cachedUserInputService:GetKeysPressed()
                    lastKeyCheck = now
                end

                for _, k in pairs(cachedKeys) do
                    if
                        k.KeyCode == Enum.KeyCode.W
                        or k.KeyCode == Enum.KeyCode.A
                        or k.KeyCode == Enum.KeyCode.S
                        or k.KeyCode == Enum.KeyCode.D
                    then
                        isUserMoving = true
                        break
                    end
                end

                -- Check if currently climbing/swimming from recorded state
                local isClimbingOrSwimming = false
                if fA.st then
                    local stateName = string.match(fA.st, "Enum%.HumanoidStateType%.(%w+)")
                    if stateName == "Climbing" or stateName == "Swimming" then
                        isClimbingOrSwimming = true
                    end
                end

                -- PERFORMANCE: Use cached att instead of FindFirstChild every frame

                if isUserMoving then
                    -- User Input: Free Control
                    if cachedAO then
                        cachedAO.Enabled = false
                    end
                    h.AutoRotate = true
                elseif isClimbingOrSwimming then
                    -- Climbing/Swimming: Rotation already handled in position section
                    if cachedAO then
                        cachedAO.Enabled = false
                    end
                    h.AutoRotate = false
                else
                    -- Idle/Playback: Use recorded rotation
                    h.AutoRotate = false -- Disable default to prevent fighting

                    -- PERFORMANCE: Reuse cached AO instead of creating new one
                    if not cachedAO or not cachedAO.Parent then
                        cachedAO = Instance.new("AlignOrientation", r)
                        cachedAO.Name = "PlaybackAO"
                        cachedAO.Mode = Enum.OrientationAlignmentMode.OneAttachment
                        cachedAO.Attachment0 = cachedAtt
                        cachedAO.RigidityEnabled = false
                        cachedAO.MaxTorque = 1000000
                    end
                    cachedAO.Enabled = true
                    cachedAO.Responsiveness = isReversing and 50 or 80 -- Smoother for reverse

                    -- Determine look direction based on shiftlock or recorded charLook
                    local lookDir = Vector3.new(0, 0, -1) -- Default

                    -- SHIFTLOCK / CHARACTER LOOK DIRECTION PLAYBACK
                    if fA.charLook and fB.charLook then
                        -- Use recorded character facing direction (interpolated)
                        local lookA = Vector3.new(fA.charLook.x, 0, fA.charLook.z)
                        local lookB = Vector3.new(fB.charLook.x, 0, fB.charLook.z)
                        if lookA.Magnitude > 0.01 and lookB.Magnitude > 0.01 then
                            lookDir = lookA.Unit:Lerp(lookB.Unit, alpha)
                        elseif lookA.Magnitude > 0.01 then
                            lookDir = lookA.Unit
                        end
                    elseif fA.charLook then
                        -- Single frame charLook
                        local look = Vector3.new(fA.charLook.x, 0, fA.charLook.z)
                        if look.Magnitude > 0.01 then
                            lookDir = look.Unit
                        end
                    else
                        -- Fallback: Calculate Look Direction from Velocity
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

                    -- Handle look direction based on mode
                    -- Moonwalk inverts look, Reverse keeps original. If both, they cancel out.
                    if isMoonwalk and not isReversing then
                        lookDir = -lookDir -- Invert direction for Moonwalk only
                    elseif isReversing and not isMoonwalk then
                        -- Reverse only: Keep original look direction (walks backward)
                        -- lookDir stays as is
                    end
                    -- If both moonwalk and reverse: they cancel out, keep original direction
                    cachedAO.CFrame = CFrame.lookAt(Vector3.zero, lookDir)

                    -- Trigger Animation based on velocity (inverted for reverse = backward walking)
                    local velDir = Vector3.new(0, 0, 0)
                    if fA.vel then
                        velDir = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
                    end
                    if velDir.Magnitude > 0.1 then
                        -- For reverse: move direction opposite to look = backward walk animation
                        if isReversing then
                            h:Move(-velDir.Unit)
                        else
                            h:Move(velDir.Unit)
                        end
                    end
                end

                -- 4. Jump & State Replication
                -- Don't trigger jump when reversing (handled by state swap above)
                if fA.jmp and not isReversing then
                    h.Jump = true
                end

                if fA.st then
                    -- Extract state name from string "Enum.HumanoidStateType.Running" -> "Running"
                    local stateName = string.match(fA.st, "Enum%.HumanoidStateType%.(%w+)")

                    -- ZOOM EFFECT: Zoom out saat loncat, zoom in saat jatuh
                    if isZoomPunch and stateName then
                        if stateName == "Jumping" then
                            SetZoomState("jump")   -- Zoom OUT
                        elseif stateName == "Freefall" then
                            SetZoomState("fall")   -- Zoom IN
                        elseif stateName == "Running" or stateName == "Landed" then
                            SetZoomState("normal") -- Reset
                        end
                    end
                    if stateName then
                        local stateEnum = Enum.HumanoidStateType[stateName]
                        local currentState = h:GetState()

                        -- REVERSE PLAYBACK: Swap animation states for rewind effect
                        -- Use simplified state handling to prevent jittery animations
                        if isReversing then
                            -- REVERSE PLAYBACK: Use velocity Y to determine correct air state (inverted)
                            -- When rewinding: recorded jump (velY > 0) = now falling, recorded fall (velY < 0) = now jumping
                            local isInAir = (
                                stateEnum == Enum.HumanoidStateType.Jumping
                                or stateEnum == Enum.HumanoidStateType.Freefall
                            )

                            if isInAir then
                                -- Use velocity Y to determine animation (INVERTED for reverse)
                                local velY = fA.vel and fA.vel.y or 0
                                -- Invert logic: positive velY in recording = freefall in reverse, negative = jump
                                local targetState = velY > 0 and "fall" or "jump"

                                -- For spam jumps: Force state change if velocity is significant (bypass lastAirState check)
                                local forceStateChange = math.abs(velY) > 8

                                -- Change state if different OR if velocity is significant (spam jump detection)
                                if targetState ~= lastAirState or forceStateChange then
                                    lastAirState = targetState
                                    if targetState == "jump" then
                                        h:ChangeState(Enum.HumanoidStateType.Jumping)
                                    else
                                        h:ChangeState(Enum.HumanoidStateType.Freefall)
                                    end
                                end
                            elseif stateEnum == Enum.HumanoidStateType.Landed then
                                -- Was landing, now taking off - trigger jump (ALWAYS trigger for spam jumps)
                                lastAirState = nil -- Reset to allow next jump
                                h:ChangeState(Enum.HumanoidStateType.Jumping)
                            elseif stateEnum == Enum.HumanoidStateType.Running then
                                lastAirState = nil
                                if currentState ~= Enum.HumanoidStateType.Running then
                                    h:ChangeState(Enum.HumanoidStateType.Running)
                                end
                            elseif stateEnum == Enum.HumanoidStateType.Climbing then
                                if currentState ~= Enum.HumanoidStateType.Climbing then
                                    h:ChangeState(Enum.HumanoidStateType.Climbing)
                                end
                                if fA.vel then
                                    -- Invert climbing velocity for reverse, only scale if playback speed changed
                                    local climbVel = Vector3.new(-fA.vel.x, -fA.vel.y, -fA.vel.z)
                                    if playbackSpeed ~= 1.0 then
                                        climbVel = climbVel * playbackSpeed
                                    end
                                    r.AssemblyLinearVelocity = climbVel
                                end
                            elseif stateEnum == Enum.HumanoidStateType.Swimming then
                                if currentState ~= Enum.HumanoidStateType.Swimming then
                                    h:ChangeState(Enum.HumanoidStateType.Swimming)
                                end
                                if fA.hh then
                                    h.HipHeight = fA.hh
                                end
                            end
                        else
                            -- NORMAL PLAYBACK: Use velocity Y to determine correct air state
                            local isAirState = (
                                stateEnum == Enum.HumanoidStateType.Jumping
                                or stateEnum == Enum.HumanoidStateType.Freefall
                            )

                            if isAirState then
                                -- Use velocity Y to determine animation
                                local velY = fA.vel and fA.vel.y or 0
                                local targetState = velY > 0 and "jump" or "fall"

                                -- Only change state if it's different from last air state (prevent stuttering)
                                if targetState ~= lastAirState then
                                    lastAirState = targetState
                                    if targetState == "jump" then
                                        h:ChangeState(Enum.HumanoidStateType.Jumping)
                                    else
                                        h:ChangeState(Enum.HumanoidStateType.Freefall)
                                    end
                                end
                            elseif stateEnum == Enum.HumanoidStateType.Landed then
                                lastAirState = nil
                                if currentState ~= Enum.HumanoidStateType.Landed then
                                    h:ChangeState(Enum.HumanoidStateType.Landed)
                                end
                            elseif stateEnum == Enum.HumanoidStateType.Running then
                                lastAirState = nil
                                -- Running: Prevent unwanted freefall on small bumps
                                if currentState == Enum.HumanoidStateType.Freefall then
                                    -- Check if we should be running instead
                                    if fA.vel and math.abs(fA.vel.y) < 3 then
                                        h:ChangeState(Enum.HumanoidStateType.Running)
                                    end
                                end
                            elseif
                                stateEnum == Enum.HumanoidStateType.Climbing
                                and currentState ~= Enum.HumanoidStateType.Climbing
                            then
                                -- Climbing: Force state and ensure proper velocity for animation
                                h:ChangeState(Enum.HumanoidStateType.Climbing)
                            elseif
                                stateEnum == Enum.HumanoidStateType.Climbing
                                and currentState == Enum.HumanoidStateType.Climbing
                            then
                                -- Maintain climbing: Apply full recorded velocity (not dampened)
                                if fA.vel then
                                    -- Use exact recorded velocity for accurate climbing, only scale if playback speed changed
                                    local climbVel = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
                                    if playbackSpeed ~= 1.0 then
                                        climbVel = climbVel * playbackSpeed
                                    end
                                    r.AssemblyLinearVelocity = climbVel
                                end
                            elseif
                                stateEnum == Enum.HumanoidStateType.Swimming
                                and currentState ~= Enum.HumanoidStateType.Swimming
                            then
                                -- Swimming: Force state and update hip height
                                h:ChangeState(Enum.HumanoidStateType.Swimming)
                                if fA.hh then
                                    h.HipHeight = fA.hh
                                end
                            end
                        end
                    end
                end

                -- 5. IMPROVED Drift Correction (Smooth) - Skip during climbing/swimming
                local skipDriftCorrection = false
                if fA.st then
                    local stName = string.match(fA.st, "Enum%.HumanoidStateType%.(%w+)")
                    skipDriftCorrection = (stName == "Climbing" or stName == "Swimming")
                end

                if not skipDriftCorrection then
                    -- Use Catmull-Rom interpolated position for smoother target
                    local smoothTargetPos, _ = SmoothInterpolateFrames(currentFrameData, frameIdx, alpha)
                    local targetPos = smoothTargetPos
                    if not targetPos and fA.pos and fB.pos then
                        targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z)
                            :Lerp(Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha)
                    end

                    if targetPos then
                        local dist = (r.Position - targetPos).Magnitude

                        if dist > 10 then
                            -- IMPROVED: Smooth lerp instead of instant snap (over 3-5 frames)
                            local smoothSnapPos = r.Position:Lerp(targetPos, 0.4) -- 40% per frame = smooth snap
                            r.CFrame = CFrame.new(smoothSnapPos) * r.CFrame.Rotation
                        elseif dist > 3 then
                            -- Medium drift: Stronger velocity correction
                            local dir = (targetPos - r.Position).Unit
                            local correction = dir * (dist * 1.5) -- Proportional correction
                            r.AssemblyLinearVelocity = r.AssemblyLinearVelocity + correction
                        elseif dist > 0.5 then
                            -- Small drift: Gentle nudge
                            local dir = (targetPos - r.Position).Unit
                            local correction = dir * (dist * 0.8) -- Softer correction
                            r.AssemblyLinearVelocity = r.AssemblyLinearVelocity + correction
                        end
                        -- Under 0.5 studs: no correction needed (natural movement)
                    end
                end

                -- 6. TOOL HANDLING: Equip/Unequip tools based on recorded data
                if frameCounter % 10 == 0 then -- PERFORMANCE: Throttle to every 10 frames (was 3)
                    local recordedTool = fA.tool
                    local currentTool = c:FindFirstChildOfClass("Tool")
                    local currentToolName = currentTool and currentTool.Name or nil

                    if recordedTool ~= currentToolName then
                        if recordedTool then
                            -- Need to equip a tool
                            local backpack = LocalPlayer:FindFirstChild("Backpack")
                            if backpack then
                                local toolToEquip = backpack:FindFirstChild(recordedTool)
                                if toolToEquip and toolToEquip:IsA("Tool") then
                                    h:EquipTool(toolToEquip)
                                end
                            end
                        else
                            -- Need to unequip current tool
                            if currentTool then
                                h:UnequipTools()
                            end
                        end
                    end
                end
            end
        end)
    else
        -- STRICT MODE: Rigid Physics Constraints (Supports Touch)
        r.Anchored = false -- Must be unanchored for Touch

        -- Ensure Animate script is running for Native Anim
        if a then
            a.Disabled = not isNativeAnim
            if isNativeAnim and a.Disabled then
                a.Disabled = false
            end
        end

        -- Setup Constraints
        local att = r:FindFirstChild("PlaybackAtt") or Instance.new("Attachment", r)
        att.Name = "PlaybackAtt"

        local ap = r:FindFirstChild("PlaybackAP") or Instance.new("AlignPosition", r)
        ap.Name = "PlaybackAP"
        ap.Mode = Enum.PositionAlignmentMode.OneAttachment
        ap.Attachment0 = att
        ap.RigidityEnabled = true -- Infinite force to match Strict behavior

        local ao = r:FindFirstChild("PlaybackAO") or Instance.new("AlignOrientation", r)
        ao.Name = "PlaybackAO"
        ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ao.Attachment0 = att
        ao.RigidityEnabled = true -- Infinite torque

        local jm = {}
        for _, d in pairs(c:GetDescendants()) do
            if d:IsA("Motor6D") then
                jm[d.Name] = d
            end
        end

        -- Ground snap offset - calculated once at start
        local groundSnapOffset = 0
        local groundSnapCalculated = false

        -- PERFORMANCE: Pre-cache variables for playback loop
        local strictFrameCounter = 0
        local cachedRayParams = RaycastParams.new()
        cachedRayParams.FilterType = Enum.RaycastFilterType.Exclude
        local filterList = { c }
        if PathContainer then
            table.insert(filterList, PathContainer)
        end
        cachedRayParams.FilterDescendantsInstances = filterList
        cachedRayParams.IgnoreWater = true
        local cachedGroundY = nil         -- Cache ground Y position
        local cachedLastStrictState = nil -- Cache humanoid state

        Connections.Playback = RunService.Stepped:Connect(function(_, dt)
            strictFrameCounter = strictFrameCounter + 1
            if not isPlaying or isPlayPaused then
                return
            end

            -- REVERSE PLAYBACK SUPPORT
            if isReversing then
                currentPlaybackTime = currentPlaybackTime - (dt * playbackSpeed)
                if currentPlaybackTime <= 0 then
                    if isRespawnOnEnd then
                        local savedFile = currentPlaybackFile
                        local savedLoop = isLooping
                        StopPlayback()
                        ShowToast(L("respawn"), L("respawning_in"), "info", 5)
                        task.wait(5)
                        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
                        if h then
                            h.Health = 0
                        end
                        if savedLoop then
                            task.spawn(function()
                                LocalPlayer.CharacterAdded:Wait()
                                ShowToast("Loop", "Restarting playback in 5 seconds...", "info", 5)
                                task.wait(5)
                                if savedFile and UIHandlers.PlayMergerRecording then
                                    UIHandlers.PlayMergerRecording(savedFile, true)
                                end
                            end)
                        end
                        return
                    elseif isLooping then
                        currentPlaybackTime = currentTotalDuration
                    else
                        StopPlayback()
                        return
                    end
                end
            else
                currentPlaybackTime = currentPlaybackTime + (dt * playbackSpeed)
                if currentPlaybackTime >= currentTotalDuration then
                    if isRespawnOnEnd then
                        local savedFile = currentPlaybackFile
                        local savedLoop = isLooping
                        StopPlayback()
                        ShowToast("Respawn", "Respawning in 5 seconds...", "info", 5)
                        task.wait(5)
                        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
                        if h then
                            h.Health = 0
                        end
                        if savedLoop then
                            task.spawn(function()
                                LocalPlayer.CharacterAdded:Wait()
                                ShowToast("Loop", "Restarting playback in 5 seconds...", "info", 5)
                                task.wait(5)
                                if savedFile and UIHandlers.PlayMergerRecording then
                                    UIHandlers.PlayMergerRecording(savedFile, true)
                                end
                            end)
                        end
                        return
                    elseif isLooping then
                        currentPlaybackTime = 0
                    else
                        StopPlayback()
                        return
                    end
                end
            end

            -- DETECT TIME JUMP (slider seeking) - skip blending if user jumped to different time
            local expectedDelta = dt * playbackSpeed
            local actualDelta = math.abs(currentPlaybackTime - lastPlaybackTime)
            local isTimeJump = actualDelta > (expectedDelta * 3 + 0.1)
            lastPlaybackTime = currentPlaybackTime

            -- Find Frames (optimized with binary search + caching)
            local frameIdx = FindFrameIndex(currentFrameData, currentPlaybackTime, lastFrameIndex)
            lastFrameIndex = frameIdx
            local fA, fB = currentFrameData[frameIdx], currentFrameData[frameIdx + 1]

            if fA and fB then
                local deltaT = fB.t - fA.t
                local alpha = 0
                if deltaT > 0.0001 then
                    alpha = (currentPlaybackTime - fA.t) / deltaT
                end
                local targetCF = TblToCF(fA.r):Lerp(TblToCF(fB.r), alpha)

                -- Drive Physics Constraints
                if isNativeAnim then
                    -- Use Non-Rigid for Native Anim to allow Velocity calculation
                    ap.RigidityEnabled = false
                    ap.MaxForce = math.huge

                    -- Adaptive Responsiveness
                    -- Lower responsiveness allows smoother interpolation, reducing the "floating/stuttering" look
                    local isMovingVertically = math.abs(TblToCF(fB.r).Y - TblToCF(fA.r).Y) > 0.1
                    if isMovingVertically then
                        ap.Responsiveness = 40 -- Very smooth for jumps/slopes
                    else
                        ap.Responsiveness = 80 -- Snappier for flat ground
                    end

                    ao.RigidityEnabled = false
                    ao.MaxTorque = math.huge
                    ao.Responsiveness = isReversing and 50 or 80 -- Smoother for reverse
                else
                    ap.RigidityEnabled = true
                    ao.RigidityEnabled = true
                end

                -- AUTO-HEIGHT CORRECTION (Ground Snap)
                -- Ensures feet touch the ground visually in Native Anim mode OR Strict Retarget mode
                local finalPosition = targetCF.Position

                if isNativeAnim or isStrictRetarget then
                    -- For Strict Retarget: Skip raycast if offset already calculated
                    if isStrictRetarget and groundSnapCalculated then
                        -- Just apply the cached offset
                        finalPosition =
                            Vector3.new(finalPosition.X, finalPosition.Y + groundSnapOffset, finalPosition.Z)
                    else
                        -- PERFORMANCE: Use cached RayParams and throttle raycast to every 5 frames
                        local groundY = cachedGroundY
                        if strictFrameCounter % 5 == 0 or not cachedGroundY then
                            local rayStart = r.Position + Vector3.new(0, 3, 0)
                            local footRay = workspace:Raycast(rayStart, Vector3.new(0, -20, 0), cachedRayParams)
                            if footRay then
                                cachedGroundY = footRay.Position.Y
                                groundY = cachedGroundY
                            end
                        end

                        -- PERFORMANCE: Only process ground snap if we have valid groundY
                        if groundY then
                            local hipHeight = h.HipHeight
                            local rootSizeY = r.Size.Y / 2

                            -- Detect R6 vs R15
                            local isR6 = (c:FindFirstChild("Torso") ~= nil)
                            local expectedY

                            if isR6 then
                                -- R6: HipHeight is usually 0, calculate from leg length
                                local leftLeg = c:FindFirstChild("Left Leg")
                                local rightLeg = c:FindFirstChild("Right Leg")
                                local legLength = 2 -- Default R6 leg length

                                if leftLeg then
                                    legLength = leftLeg.Size.Y
                                elseif rightLeg then
                                    legLength = rightLeg.Size.Y
                                end

                                -- R6 root is at torso center, so add half torso + leg length
                                local torso = c:FindFirstChild("Torso")
                                local torsoHalfHeight = torso and (torso.Size.Y / 2) or 1
                                expectedY = groundY + legLength + torsoHalfHeight
                            else
                                -- R15: Use HipHeight
                                expectedY = groundY + hipHeight + rootSizeY
                            end

                            -- For Strict Retarget: Calculate offset ONCE, apply ALWAYS
                            if isStrictRetarget then
                                if not groundSnapCalculated then
                                    -- Calculate offset once at start
                                    groundSnapOffset = expectedY - finalPosition.Y
                                    groundSnapCalculated = true
                                end
                                -- ALWAYS apply offset (including during jump/fall)
                                finalPosition =
                                    Vector3.new(finalPosition.X, finalPosition.Y + groundSnapOffset, finalPosition.Z)
                            elseif isNativeAnim then
                                -- For Native Anim: Check velocity before snapping
                                local prevY = TblToCF(fA.r).Y
                                local nextY = TblToCF(fB.r).Y
                                local fVelocityY = (nextY - prevY) / deltaT

                                if math.abs(fVelocityY) < 10.0 then
                                    local snapAlpha = 0.3
                                    local snappedY = finalPosition.Y + (expectedY - finalPosition.Y) * snapAlpha
                                    finalPosition = Vector3.new(finalPosition.X, snappedY, finalPosition.Z)
                                end
                            end
                        end
                    end
                end

                -- Apply position and rotation (keep original rotation for reverse - walks backward)
                ap.Position = finalPosition
                -- Moonwalk inverts rotation, Reverse keeps original. If both, they cancel out.
                if isMoonwalk and not isReversing then
                    ao.CFrame = targetCF * CFrame.Angles(0, math.pi, 0)
                else
                    ao.CFrame = targetCF
                end

                -- Native Anim Movement Logic
                if isNativeAnim then
                    local nextPos = TblToCF(fB.r).Position
                    local prevPos = TblToCF(fA.r).Position
                    local velocity = (nextPos - prevPos) / deltaT
                    velocity = velocity * playbackSpeed -- Scale velocity by playback speed

                    -- Invert velocity for reverse playback
                    if isReversing then
                        velocity = -velocity
                    end

                    -- Smoother Velocity Application (skip blending on time jump or high speed)
                    if isTimeJump or playbackSpeed >= 2 then
                        -- Snap directly to target velocity on slider seek or high speed
                        r.AssemblyLinearVelocity = velocity
                    else
                        -- Blend current velocity with target velocity to prevent snapping
                        local currentVel = r.AssemblyLinearVelocity
                        local baseBlend = isReversing and 0.35 or 0.5
                        local blendFactor = math.clamp(baseBlend * playbackSpeed, 0.3, 0.95)

                        -- If jumping/falling (high vertical velocity), trust the recording more but keep it smooth
                        if math.abs(velocity.Y) > 5 then
                            blendFactor = math.clamp((isReversing and 0.5 or 0.7) * playbackSpeed, 0.4, 0.95)
                        end

                        r.AssemblyLinearVelocity = currentVel:Lerp(velocity, blendFactor)
                    end

                    -- GROUND CHECK (Raycast)
                    -- Crucial for distinguishing Slopes vs Jumps
                    -- PERFORMANCE: Throttle ground check to every 3 frames, use cached result otherwise
                    local isNearGround = false

                    if strictFrameCounter % 3 == 0 then
                        -- Increased length to 12 studs to account for steep slopes/micro-floating
                        local rayResult = workspace:Raycast(r.Position, Vector3.new(0, -12, 0), cachedRayParams)

                        if rayResult then
                            local distToGround = (r.Position - rayResult.Position).Magnitude
                            -- Relaxed threshold: If ground is within 8 studs, consider it walkable/slope
                            if distToGround < 8.0 then
                                isNearGround = true
                            end
                        end
                    end

                    local flatVel = velocity * Vector3.new(1, 0, 1)
                    local horizSpeed = flatVel.Magnitude

                    if horizSpeed > 0.5 then
                        -- For reverse: invert move direction = backward walk animation
                        if isReversing then
                            h:Move(-flatVel.Unit)
                        else
                            h:Move(flatVel.Unit)
                        end

                        -- Force Running state if on ground/slope
                        -- This OVERRIDES any Jump detection if we are close to the floor
                        if isNearGround then
                            h:ChangeState(Enum.HumanoidStateType.Running)
                            h.Jump = false
                        end
                    else
                        h:Move(Vector3.zero)
                    end

                    local isClimbing = false
                    -- Climb Detection (Vertical movement near parts)
                    -- Check climbing first to prevent false jumps
                    -- For reverse: check absolute velocity since direction is inverted
                    local climbVelY = isReversing and -velocity.Y or velocity.Y
                    if climbVelY > 3.0 then
                        local hitResult = workspace:Raycast(r.Position, r.CFrame.LookVector * 2, cachedRayParams)
                        if hitResult and hitResult.Instance.CanCollide then
                            -- Stricter climb detection: High angle or Truss
                            if hitResult.Instance:IsA("TrussPart") or (climbVelY > horizSpeed * 2.0) then
                                h:ChangeState(Enum.HumanoidStateType.Climbing)
                                isClimbing = true
                            end
                        end
                    end

                    if not isClimbing then
                        -- ADVANCED JUMP & FREEFALL DETECTION
                        -- For reverse playback: swap jump/freefall states

                        -- Dynamic Threshold: Slopes generate vertical velocity, so we raise the bar.
                        local jumpThreshold = math.max(10, 8.0 + (horizSpeed * 0.5))

                        -- PERFORMANCE: Cache state once instead of calling GetState multiple times
                        local currentState = h:GetState()
                        local currentStateName = currentState.Name

                        -- ZOOM EFFECT for Strict mode
                        if isZoomPunch then
                            if currentStateName == "Jumping" then
                                SetZoomState("jump")   -- Zoom OUT
                            elseif currentStateName == "Freefall" then
                                SetZoomState("fall")   -- Zoom IN
                            elseif currentStateName == "Running" or currentStateName == "Landed" then
                                SetZoomState("normal") -- Reset
                            end
                        end

                        if isReversing then
                            -- REVERSE: Use inverted velocity for proper animation
                            -- velocity.Y is already inverted, so positive = going up (jump), negative = going down (fall)
                            if not isNearGround then
                                -- Lower threshold (3) for better spam jump detection
                                if velocity.Y > 3 then
                                    -- Going up visually = Jumping (ALWAYS change state for spam jumps)
                                    h:ChangeState(Enum.HumanoidStateType.Jumping)
                                elseif velocity.Y < -3 then
                                    -- Going down visually = Freefall
                                    h:ChangeState(Enum.HumanoidStateType.Freefall)
                                else
                                    -- Near apex, maintain jump state
                                    if
                                        currentState ~= Enum.HumanoidStateType.Freefall
                                        and currentState ~= Enum.HumanoidStateType.Jumping
                                    then
                                        h:ChangeState(Enum.HumanoidStateType.Jumping)
                                    end
                                end
                            else
                                -- On ground during reverse - reset to running
                                if
                                    currentState == Enum.HumanoidStateType.Jumping
                                    or currentState == Enum.HumanoidStateType.Freefall
                                then
                                    h:ChangeState(Enum.HumanoidStateType.Running)
                                end
                            end
                        else
                            -- NORMAL: Original logic
                            -- 1. Jump Start
                            -- ONLY trigger jump if we are NOT near the ground
                            if not isNearGround and velocity.Y > jumpThreshold then
                                h:ChangeState(Enum.HumanoidStateType.Jumping)

                                -- 2. Jump Apex (The "Floaty" Part)
                                -- If we are in the air (confirmed by !isNearGround) and velocity is small
                            elseif not isNearGround and math.abs(velocity.Y) <= 5 then
                                if currentState == Enum.HumanoidStateType.Freefall then
                                    -- Do nothing
                                else
                                    h:ChangeState(Enum.HumanoidStateType.Jumping)
                                end

                                -- 3. Freefall (Falling Down)
                            elseif not isNearGround and velocity.Y < -18 then
                                h:ChangeState(Enum.HumanoidStateType.Freefall)
                            end
                        end
                    end

                    -- Swim Detection (Check water)
                    local min, max = r.Position - (0.5 * r.Size), r.Position + (0.5 * r.Size)
                    local region = Region3.new(min, max)
                    region = region:ExpandToGrid(4)
                    if region then
                        local material = workspace.Terrain:ReadVoxels(region, 4)[1][1][1]
                        if material == Enum.Material.Water then
                            h:ChangeState(Enum.HumanoidStateType.Swimming)
                        end
                    end
                end

                -- Replicate Joints (Visuals)
                if not isNativeAnim and fA.j and fB.j then
                    for n, dA in pairs(fA.j) do
                        local dB = fB.j[n]
                        if dB then
                            local m = jm[n]
                            if m then
                                local target = TblToCF(dA):Lerp(TblToCF(dB), alpha)
                                if isStrictRetarget then
                                    m.Transform = target.Rotation
                                else
                                    m.Transform = target
                                end
                            end
                        end
                    end
                end

                -- TOOL HANDLING: Equip/Unequip tools based on recorded data (Strict Mode)
                if strictFrameCounter % 3 == 0 then -- Throttle to every 3 frames for performance
                    local recordedTool = fA.tool
                    local currentTool = c:FindFirstChildOfClass("Tool")
                    local currentToolName = currentTool and currentTool.Name or nil

                    if recordedTool ~= currentToolName then
                        if recordedTool then
                            -- Need to equip a tool
                            local backpack = LocalPlayer:FindFirstChild("Backpack")
                            if backpack then
                                local toolToEquip = backpack:FindFirstChild(recordedTool)
                                if toolToEquip and toolToEquip:IsA("Tool") then
                                    h:EquipTool(toolToEquip)
                                end
                            end
                        else
                            -- Need to unequip current tool
                            if currentTool then
                                h:UnequipTools()
                            end
                        end
                    end
                end
            end
        end)
    end
end

UIHandlers.PlayMergerRecording = PlayRecording

UIHandlers.RenameMergerFile = function(oldName, newName, callback)
    if not newName or newName == "" then
        return
    end
    if not string.match(newName, "%.json$") then
        newName = newName .. ".json"
    end

    local oldPath = MERGER_FOLDER .. "/" .. oldName
    local newPath = MERGER_FOLDER .. "/" .. newName

    if isfile(oldPath) then
        writefile(newPath, readfile(oldPath))
        delfile(oldPath)
        if callback then
            callback()
        end
    end
end
UIHandlers.DeleteMergerFile = function(fileName, callback)
    local path = MERGER_FOLDER .. "/" .. fileName
    if isfile(path) then
        -- 1. Try to delete associated icon (Protected)
        pcall(function()
            local content = readfile(path)
            local data = HttpService:JSONDecode(content)
            if data and data.Icon then
                local iconPath = data.Icon
                if type(iconPath) == "string" and string.find(iconPath, MERGER_FOLDER, 1, true) then
                    if isfile(iconPath) then
                        delfile(iconPath)
                    end
                end
            end
        end)

        -- 2. Delete main file
        delfile(path)
        ShowToast("File Deleted", "Deleted " .. fileName, "success", 2)
        if callback then
            callback()
        end
    end
end

local function SelectRecording(fn)
    local p = GetWorkspacePath() .. "/" .. fn
    if not isfile(p) then
        p = MERGER_FOLDER .. "/" .. fn
        if not isfile(p) then
            return
        end
    end

    if isRecording then
        StopRecording()
    end
    StopPlayback() -- Reset state but keep selection logic below

    local s, j = pcall(readfile, p)
    if not s then
        return
    end
    local d = HttpService:JSONDecode(j)
    currentFrameData = d.Frames or d
    currentPlaybackFile = fn
    currentPlaybackTime = 0
    if not currentFrameData or #currentFrameData < 2 then
        return
    end
    currentTotalDuration = currentFrameData[#currentFrameData].t

    currentPlaybackSource = "Recorder" -- Set source flag

    if isPathEnabled then
        GeneratePlaybackPath(currentFrameData)
    else
        ClearPath()
    end

    local startFrame = currentFrameData[1]
    local targetPos = (startFrame.pos and Vector3.new(startFrame.pos.x, startFrame.pos.y, startFrame.pos.z))
        or (startFrame.r and TblToCF(startFrame.r).Position)
    if targetPos then
        CreateStartBaseplate(targetPos)
    end

    -- DISTANCE WARNING ON SELECT (informational only - check nearest path point)
    local c = LocalPlayer.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if r and #currentFrameData > 0 then
        local dist = GetDistanceToNearestPathPoint(currentFrameData, r.Position)
        if dist > MAP_DISTANCE_THRESHOLD then
            ShowToast(
                "Different Map Warning",
                string.format("Nearest path point is %.0f studs away! This may be from a different game/map.", dist),
                "warning",
                4
            )
        end
    end
end

local function RenameFile(o, n)
    if not n or n == "" then
        return
    end
    if not string.find(n, ".json") then
        n = n .. ".json"
    end
    local op, np = GetWorkspacePath() .. "/" .. o, GetWorkspacePath() .. "/" .. n
    if isfile(op) then
        writefile(np, readfile(op))
        delfile(op)
    end
end
local function DeleteFile(f)
    ShowConfirm("DELETE FILE", "Delete file '" .. f .. "' permanently?", function()
        local p = GetWorkspacePath() .. "/" .. f
        if isfile(p) then
            delfile(p)
        end
        if RefreshPlayerList then
            RefreshPlayerList()
        end
    end)
end

-- THEME LOGIC
local function SetTheme(c)
    C_ACCENT = c
    -- AppTitle color is now handled by Rainbow Gradient

    for _, b in pairs(TabBtns) do
        if b.BackgroundTransparency == 0 then
            b.BackgroundColor3 = c
            b.TextColor3 = Color3.new(0, 0, 0)
        end
    end

    if SliderFill then
        SliderFill.BackgroundColor3 = c
    end
    if PSliderFill then
        PSliderFill.BackgroundColor3 = c
    end
    if CountLbl then
        CountLbl.TextColor3 = c
    end
    if RewindTimeLbl then
        RewindTimeLbl.TextColor3 = c
    end
    if BtnSave then
        BtnSave.BackgroundColor3 = c
    end
    if ConfirmTitle then
        ConfirmTitle.TextColor3 = c
    end
    if BtnYes then
        BtnYes.BackgroundColor3 = c
    end

    for _, item in ipairs(ThemeObjects) do
        if item.Object and item.Object.Parent then
            if item.Type == "Accent" or item.Type == nil then
                item.Object[item.Property] = c
            end
        end
    end
end

local GUI_NAME = "StarshipCore"
if CoreGui:FindFirstChild(GUI_NAME) then
    CoreGui[GUI_NAME]:Destroy()
end
ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.Parent = CoreGui
ScreenGui.IgnoreGuiInset = true

-- AUTO INPUT SINK: Automatically setup input sink for ALL TextBoxes added to ScreenGui
ScreenGui.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("TextBox") then
        SetupTextBoxInputSink(descendant)
    end
end)
-- Also setup for existing TextBoxes (in case some were created before this)
for _, descendant in pairs(ScreenGui:GetDescendants()) do
    if descendant:IsA("TextBox") then
        SetupTextBoxInputSink(descendant)
    end
end

Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 550, 0, 520)
Main.Position = UDim2.new(0.5, -275, 0.5, -260)
Main.BackgroundTransparency = 1
Main.Active = true
Main.Visible = false

-- Background Frame (Holds Color & Corner)
local MainBg = Instance.new("Frame", Main)
MainBg.Name = "MainBackground"
MainBg.Size = UDim2.new(1, 0, 1, 0)
MainBg.BackgroundColor3 = C_MAIN     -- Force Initial Color
MainBg.BackgroundTransparency = 0.05 -- More Opaque (Darker)
MainBg.ZIndex = 0
local MainCorner = Instance.new("UICorner", MainBg)
MainCorner.CornerRadius = UDim.new(0, 12)
RegisterTheme(MainBg, "BackgroundColor3", "Main")

-- Blur Glow Effect (Behind Background)
local MainBlur = Instance.new("ImageLabel", Main)
MainBlur.Name = "BlurGlow"
MainBlur.BackgroundTransparency = 1
MainBlur.Position = UDim2.new(0, -20, 0, -20)
MainBlur.Size = UDim2.new(1, 40, 1, 40)
MainBlur.Image = "rbxassetid://5028857472"
MainBlur.ImageColor3 = C_ACCENT  -- Tinted Glow
MainBlur.ImageTransparency = 0.9 -- More subtle ambient glow
MainBlur.ScaleType = Enum.ScaleType.Slice
MainBlur.SliceCenter = Rect.new(24, 24, 276, 276)
MainBlur.ZIndex = -1
RegisterTheme(MainBlur, "ImageColor3", "Accent")

local MainStroke = Instance.new("UIStroke", MainBg)
MainStroke.Color = Color3.fromRGB(255, 255, 255)
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0

local StrokeGradient = Instance.new("UIGradient", MainStroke)
StrokeGradient.Rotation = 45
StrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, C_ACCENT),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 60, 80)), -- Dark middle
    ColorSequenceKeypoint.new(1, C_ACCENT),
})

-- Entrance Animation (will be updated with dynamic size later)

-- Resize Handle
local ResizeHandle = Instance.new("ImageButton", Main)
ResizeHandle.Name = "ResizeHandle"
ResizeHandle.Size = UDim2.new(0, 30, 0, 30) -- Increased size for easier clicking
ResizeHandle.Position = UDim2.new(1, -30, 1, -30)
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.Image = "rbxassetid://9608716447" -- Resize Icon
ResizeHandle.ImageColor3 = C_TEXT_DIM
ResizeHandle.ZIndex = 200                      -- Ensure it's on top of everything

local isResizing = false
local resizeCon = nil
local resizeEndCon = nil

ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = true
        local startSize = Main.AbsoluteSize
        local startMouse = UserInputService:GetMouseLocation()

        -- Clean up previous connections if any
        if resizeCon then
            resizeCon:Disconnect()
            resizeCon = nil
        end
        if resizeEndCon then
            resizeEndCon:Disconnect()
            resizeEndCon = nil
        end

        resizeCon = RunService.RenderStepped:Connect(function()
            if not isResizing then
                if resizeCon then
                    resizeCon:Disconnect()
                    resizeCon = nil
                end
                return
            end

            local currentMouse = UserInputService:GetMouseLocation()
            local delta = currentMouse - startMouse

            -- Minimum sizes (to ensure all sidebar tabs including CONFIG remain visible)
            local minWidth = 500
            local minHeight = 520
            -- Maximum sizes (to prevent UI from going off-screen)
            local maxWidth = 900
            local maxHeight = 700

            -- Calculate raw new size from startSize + delta
            local rawWidth = startSize.X + delta.X
            local rawHeight = startSize.Y + delta.Y

            -- Clamp to min/max - this enforces the limits
            local newWidth = math.max(minWidth, math.min(rawWidth, maxWidth))
            local newHeight = math.max(minHeight, math.min(rawHeight, maxHeight))

            Main.Size = UDim2.new(0, newWidth, 0, newHeight)
        end)

        resizeEndCon = UserInputService.InputEnded:Connect(function(endInput)
            if
                endInput.UserInputType == Enum.UserInputType.MouseButton1
                or endInput.UserInputType == Enum.UserInputType.Touch
            then
                isResizing = false
                if resizeCon then
                    resizeCon:Disconnect()
                    resizeCon = nil
                end
                if resizeEndCon then
                    resizeEndCon:Disconnect()
                    resizeEndCon = nil
                end
            end
        end)
    end
end)

-- Minimized Icon
local MinIcon = Instance.new("TextButton", ScreenGui)
MinIcon.Name = "MinIcon"
MinIcon.Size = UDim2.new(0, 55, 0, 55)
MinIcon.Position = UDim2.new(0.5, -27, 0, 20)
MinIcon.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
MinIcon.BackgroundTransparency = 0
MinIcon.Text = ""
MinIcon.Visible = false
MinIcon.ZIndex = 100
Instance.new("UICorner", MinIcon).CornerRadius = UDim.new(0, 12)

-- MinIcon styling - Wrapped to release locals
do
    local MinStroke = Instance.new("UIStroke", MinIcon)
    MinStroke.Color = C_ACCENT
    MinStroke.Thickness = 2

    local MinLogo = Instance.new("ImageLabel", MinIcon)
    MinLogo.Name = "Logo"
    MinLogo.Size = UDim2.new(1, -8, 1, -8)
    MinLogo.Position = UDim2.new(0, 4, 0, 4)
    MinLogo.BackgroundTransparency = 1
    MinLogo.Image = "https://www.roblox.com/asset/?id=91946746369709"
    MinLogo.ScaleType = Enum.ScaleType.Fit
    MinLogo.ZIndex = 101

    local MinText = Instance.new("TextLabel", MinIcon)
    MinText.Name = "FallbackText"
    MinText.Size = UDim2.new(1, 0, 1, 0)
    MinText.BackgroundTransparency = 1
    MinText.Text = "S"
    MinText.TextColor3 = C_ACCENT
    MinText.Font = Enum.Font.GothamBlack
    MinText.TextSize = 28
    MinText.ZIndex = 100
end

-- Draggable MinIcon
UIHandlers.DragMin = { dragging = false, dragInput = nil, dragStart = nil, startPos = nil, hasDragged = false }
MinIcon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        UIHandlers.DragMin.dragging = true
        UIHandlers.DragMin.dragStart = input.Position
        UIHandlers.DragMin.startPos = MinIcon.Position
        UIHandlers.DragMin.hasDragged = false
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                UIHandlers.DragMin.dragging = false
            end
        end)
    end
end)
MinIcon.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        UIHandlers.DragMin.dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == UIHandlers.DragMin.dragInput and UIHandlers.DragMin.dragging then
        local delta = input.Position - UIHandlers.DragMin.dragStart
        if delta.Magnitude > 5 then
            UIHandlers.DragMin.hasDragged = true
        end
        MinIcon.Position = UDim2.new(
            UIHandlers.DragMin.startPos.X.Scale,
            UIHandlers.DragMin.startPos.X.Offset + delta.X,
            UIHandlers.DragMin.startPos.Y.Scale,
            UIHandlers.DragMin.startPos.Y.Offset + delta.Y
        )
    end
end)

-- TOP BAR (Title + Controls)
local TopBar = Instance.new("Frame", Main)
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundTransparency = 1
local AppTitle = Instance.new("TextLabel", TopBar)
AppTitle.Size = UDim2.new(0, 200, 1, 0)
AppTitle.Position = UDim2.new(0, 15, 0, 0)
AppTitle.BackgroundTransparency = 1
AppTitle.TextSize = 16
AppTitle.Font = Enum.Font.GothamBold
AppTitle.TextXAlignment = Enum.TextXAlignment.Left
AppTitle.RichText = true

-- Rainbow Animation for "STARSHIP" only
task.spawn(function()
    local t = 0
    while AppTitle and AppTitle.Parent do
        t = t + 0.01
        local c = Color3.fromHSV(t % 1, 0.7, 1) -- Softer saturation
        local r, g, b = math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)
        AppTitle.Text = string.format(
            '<font color="rgb(%d,%d,%d)">STARSHIP</font> <font color="rgb(180,180,190)" size="11">PREMIUM</font>',
            r,
            g,
            b
        )
        task.wait(0.03)
    end
end)

local function ToggleMin()
    if Main.Visible then
        -- Minimize
        Main.Visible = false
        MinIcon.Visible = true
        -- Effect
        TweenService:Create(
            MinIcon,
            TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Size = UDim2.new(0, 50, 0, 50) }
        ):Play()
    else
        -- Restore
        Main.Visible = true
        MinIcon.Visible = false
    end
end

local ToggleMinConnection
local topBtnSize = 40
local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Text = "×"
CloseBtn.Size = UDim2.new(0, topBtnSize, 1, 0)
CloseBtn.Position = UDim2.new(1, -topBtnSize, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.TextColor3 = C_RED
CloseBtn.TextSize = 22
CloseBtn.Font = Enum.Font.GothamMedium
CloseBtn.MouseButton1Click:Connect(function()
    ShowConfirm(L("exit_starship"), L("exit_confirm"), function()
        -- Disable all active features before closing
        local toggleFunctions = {
            "ToggleAntiAFK",
            "ToggleShiftLock",
            "ToggleSpeed",
            "ToggleJump",
            "ToggleInfJump",
            "ToggleFly",
            "ToggleMomentum",
            "ToggleAntiSlip",
            "ToggleAntiRagdoll",
            "ToggleAutoJump",

            "ToggleAirLock",
            "ToggleRealESP",
            "ToggleFullbright",
            "ToggleBypassAdmin",
        }

        for _, funcName in ipairs(toggleFunctions) do
            if UIHandlers[funcName] then
                pcall(function()
                    UIHandlers[funcName](false) -- Force disable
                end)
            end
        end

        if getgenv().ToggleNametags then
            getgenv().ToggleNametags(false)
        end
        if ToggleMinConnection then
            ToggleMinConnection:Disconnect()
        end
        if UIHandlers.CleanupSpeedDisplay then
            UIHandlers.CleanupSpeedDisplay()
        end
        if UIHandlers.CleanupTools then
            UIHandlers.CleanupTools()
        end
        ScreenGui:Destroy()
    end)
end)

local MiniBtn = Instance.new("TextButton", TopBar)
MiniBtn.Text = "—"
MiniBtn.Size = UDim2.new(0, topBtnSize, 1, 0)
MiniBtn.Position = UDim2.new(1, -topBtnSize * 2, 0, 0)
MiniBtn.BackgroundTransparency = 1
MiniBtn.TextColor3 = C_TEXT_DIM
MiniBtn.TextSize = 18
MiniBtn.Font = Enum.Font.GothamMedium
MiniBtn.MouseButton1Click:Connect(ToggleMin)

-- TOPBAR STATS (Hidden on mobile for space)
local StatsContainer = Instance.new("Frame", TopBar)
StatsContainer.Size = UDim2.new(0, 300, 1, 0)
StatsContainer.Position = UDim2.new(1, -380, 0, 0) -- Left of buttons
StatsContainer.BackgroundTransparency = 1
StatsContainer.Visible = true

local UIListStats = Instance.new("UIListLayout", StatsContainer)
UIListStats.FillDirection = Enum.FillDirection.Horizontal
UIListStats.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListStats.VerticalAlignment = Enum.VerticalAlignment.Center
UIListStats.Padding = UDim.new(0, 15)

local function CreateTopStat(name, icon)
    local l = Instance.new("TextLabel", StatsContainer)
    l.Text = icon .. " ..."
    l.AutomaticSize = Enum.AutomaticSize.X
    l.Size = UDim2.new(0, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.TextColor3 = C_TEXT_DIM
    l.Font = Enum.Font.GothamMedium -- Cleaner font
    l.TextSize = 10
    return l
end

UIHandlers.TopStats = {
    FpsLbl = CreateTopStat("FPS", "⚡"),
    PingLbl = CreateTopStat("Ping", "📶"),
    KeyLbl = CreateTopStat("Key", "🔑"),
    frameCount = 0,
    lastFpsTime = os.clock(),
}

Connections.FpsCounter = RunService.Heartbeat:Connect(function()
    UIHandlers.TopStats.frameCount = UIHandlers.TopStats.frameCount + 1
end)

task.spawn(function()
    local TS = UIHandlers.TopStats
    while TopBar and TopBar.Parent do
        local now = os.clock()
        local elapsed = now - TS.lastFpsTime
        local fps = math.floor(TS.frameCount / elapsed)
        TS.frameCount = 0
        TS.lastFpsTime = now
        TS.FpsLbl.Text = string.format("⚡ %d FPS", fps)
        TS.FpsLbl.TextColor3 = (fps < 30) and C_RED or C_GREEN
        local ping = 0
        pcall(function()
            ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        TS.PingLbl.Text = string.format("📶 %dms", ping)
        TS.PingLbl.TextColor3 = (ping > 200) and C_RED or C_GREEN

        -- Update Key Duration from Global Session Data
        local durationText = "N/A"
        if getgenv().StarshipSession then
            local sess = getgenv().StarshipSession
            if sess.Expiry and type(sess.Expiry) == "number" then
                local remaining = sess.Expiry - os.time()
                if remaining > 0 then
                    local days = math.floor(remaining / 86400)
                    local hours = math.floor((remaining % 86400) / 3600)
                    local mins = math.floor((remaining % 3600) / 60)
                    local secs = remaining % 60

                    if days > 0 then
                        durationText = string.format("%dd %02dh %02dm", days, hours, mins)
                    else
                        durationText = string.format("%02dh %02dm %02ds", hours, mins, secs)
                    end
                else
                    durationText = "EXPIRED"
                end
            else
                durationText = sess.Duration or "LIFETIME"
            end
        end

        TS.KeyLbl.Text = "🔑 " .. durationText
        TS.KeyLbl.TextColor3 = C_ACCENT
        task.wait(1)
    end
    if Connections.FpsCounter then
        Connections.FpsCounter:Disconnect()
    end
end)

-- DRAG LOGIC
UIHandlers.Drag = { dragging = false, dragStart = nil, startPos = nil, dragInput = nil }
TopBar.Active = true

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        UIHandlers.Drag.dragging = true
        UIHandlers.Drag.dragStart = input.Position
        UIHandlers.Drag.startPos = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                UIHandlers.Drag.dragging = false
            end
        end)
    end
end)
TopBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        UIHandlers.Drag.dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if UIHandlers.Drag.dragging and input == UIHandlers.Drag.dragInput then
        local delta = input.Position - UIHandlers.Drag.dragStart
        Main.Position = UDim2.new(
            UIHandlers.Drag.startPos.X.Scale,
            UIHandlers.Drag.startPos.X.Offset + delta.X,
            UIHandlers.Drag.startPos.Y.Scale,
            UIHandlers.Drag.startPos.Y.Offset + delta.Y
        )
    end
end)

-- SIDEBAR
local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0, 130, 1, -40)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = C_SIDE
Sidebar.BorderSizePixel = 0
local SidebarCorner = Instance.new("UICorner", Sidebar)
SidebarCorner.CornerRadius = UDim.new(0, 0) -- Flat left side
RegisterTheme(Sidebar, "BackgroundColor3", "Side")

-- Sidebar Toggle Button for Mobile - Wrapped to release locals

-- Separator Line (Gradient Fade) - Wrapped
do
    local SidebarStroke = Instance.new("Frame", Sidebar)
    SidebarStroke.Size = UDim2.new(0, 1, 1, 0)
    SidebarStroke.Position = UDim2.new(1, 0, 0, 0)
    SidebarStroke.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SidebarStroke.BorderSizePixel = 0
    SidebarStroke.ZIndex = 2

    local SidebarGradient = Instance.new("UIGradient", SidebarStroke)
    SidebarGradient.Rotation = 90
    SidebarGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C_MAIN),
        ColorSequenceKeypoint.new(0.5, C_ACCENT),
        ColorSequenceKeypoint.new(1, C_MAIN),
    })
    SidebarGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
end

-- TABS (Vertical in Sidebar)
local TabContainer = Instance.new("Frame", Sidebar)
TabContainer.Size = UDim2.new(1, 0, 1, -100)
TabContainer.Position = UDim2.new(0, 0, 0, 10)
TabContainer.BackgroundTransparency = 1
local UIListTabs = Instance.new("UIListLayout", TabContainer)
UIListTabs.FillDirection = Enum.FillDirection.Vertical
UIListTabs.SortOrder = Enum.SortOrder.LayoutOrder
UIListTabs.Padding = UDim.new(0, 8)
UIListTabs.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- PROFILE SECTION (Restored & Polished) - Wrapped to release locals
do
    local ProfileFrame = Instance.new("Frame", Sidebar)
    ProfileFrame.Size = UDim2.new(1, 0, 0, 55)
    ProfileFrame.Position = UDim2.new(0, 0, 1, -55)
    ProfileFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    ProfileFrame.BorderSizePixel = 0
    RegisterTheme(ProfileFrame, "BackgroundColor3", "Side")

    local ProfileImg = Instance.new("ImageLabel", ProfileFrame)
    ProfileImg.Size = UDim2.new(0, 32, 0, 32)
    ProfileImg.Position = UDim2.new(0, 10, 0.5, -16)
    ProfileImg.BackgroundColor3 = C_ITEM
    Instance.new("UICorner", ProfileImg).CornerRadius = UDim.new(1, 0)
    RegisterTheme(ProfileImg, "BackgroundColor3", "Item")

    task.spawn(function()
        local p = game:GetService("Players")
        local u = LocalPlayer.UserId
        local content = p:GetUserThumbnailAsync(u, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
        if content then
            ProfileImg.Image = content
        else
            local content2 = p:GetUserThumbnailAsync(u, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420)
            if content2 then
                ProfileImg.Image = content2
            end
        end
    end)

    local ProfileName = Instance.new("TextLabel", ProfileFrame)
    ProfileName.Text = string.upper(LocalPlayer.Name)
    ProfileName.Size = UDim2.new(1, -55, 0, 16)
    ProfileName.Position = UDim2.new(0, 50, 0.5, -10)
    ProfileName.BackgroundTransparency = 1
    ProfileName.TextColor3 = C_TEXT
    ProfileName.Font = Enum.Font.GothamBold
    ProfileName.TextSize = 11
    ProfileName.TextXAlignment = Enum.TextXAlignment.Left
    ProfileName.TextTruncate = Enum.TextTruncate.AtEnd
    ProfileName.Visible = true
    RegisterTheme(ProfileName, "TextColor3", "Text")

    -- Store reference for spoof name updates
    UIHandlers.SidebarProfileName = ProfileName

    local ProfileRank = Instance.new("TextLabel", ProfileFrame)
    ProfileRank.Size = UDim2.new(1, -55, 0, 14)
    ProfileRank.Position = UDim2.new(0, 50, 0.5, 6)
    ProfileRank.BackgroundTransparency = 1
    ProfileRank.Font = Enum.Font.GothamMedium
    ProfileRank.TextSize = 9
    ProfileRank.TextXAlignment = Enum.TextXAlignment.Left
    ProfileRank.Visible = true

    -- Fetch rank from Pastebin (same as nametag system)
    ProfileRank.Text = L("loading")
    ProfileRank.TextColor3 = C_TEXT_DIM

    task.spawn(function()
        local isOwner = false
        local rankText = "VIP USER"

        -- Check from Pastebin
        pcall(function()
            local response = game:HttpGet("https://pastebin.com/raw/yWZRVAt3")
            local data = game:GetService("HttpService"):JSONDecode(response)
            local userIdStr = tostring(LocalPlayer.UserId)

            if data[userIdStr] then
                local userType = data[userIdStr].Type or data[userIdStr].type
                if userType and (userType:lower() == "owner" or userType:lower() == "developer") then
                    isOwner = true
                    rankText = data[userIdStr].Rank or data[userIdStr].rank or "OWNER"
                else
                    rankText = data[userIdStr].Rank or data[userIdStr].rank or "VIP USER"
                end
            end
        end)

        -- Fallback: check local key or hardcoded owner ID
        if not isOwner then
            local savedKey = isfile("Starship_License.txt") and readfile("Starship_License.txt"):gsub("%s+", "") or ""
            isOwner = savedKey == "STARSHIP-DEV" or LocalPlayer.UserId == 9268011358
            if isOwner then
                rankText = "OWNER"
            end
        end

        ProfileRank.Text = rankText
        if isOwner then
            local t = 0
            while ProfileRank and ProfileRank.Parent do
                t = t + 0.01
                ProfileRank.TextColor3 = Color3.fromHSV(t % 1, 0.6, 1)
                task.wait(0.03)
            end
        else
            ProfileRank.TextColor3 = C_YELLOW
        end
    end)

    -- Nametag Toggle (Mini Button above profile)
    local TagToggleMini = Instance.new("TextButton", Sidebar)
    TagToggleMini.Size = UDim2.new(0.85, 0, 0, 20)
    TagToggleMini.Position = UDim2.new(0.075, 0, 1, -85)
    TagToggleMini.BackgroundColor3 = C_ITEM
    TagToggleMini.Text = L("tags") .. ": " .. L("on")
    TagToggleMini.TextColor3 = C_GREEN
    TagToggleMini.Font = Enum.Font.GothamBold
    TagToggleMini.TextSize = 10
    Instance.new("UICorner", TagToggleMini).CornerRadius = UDim.new(0, 4)

    local miniTagsOn = true
    TagToggleMini.MouseButton1Click:Connect(function()
        miniTagsOn = not miniTagsOn
        TagToggleMini.Text = L("tags") .. ": " .. (miniTagsOn and L("on") or L("off"))
        TagToggleMini.TextColor3 = miniTagsOn and C_GREEN or C_RED
        if getgenv().ToggleNametags then
            getgenv().ToggleNametags(miniTagsOn)
        end
    end)
end

-- Adjust Tab Container Height (To account for Profile + Button)
TabContainer.Size = UDim2.new(1, 0, 1, -95)

-- CONTENT AREA (Adjusted for Padding/Gap)
local ContentArea = Instance.new("Frame", Main)
local contentOffset = 130 + 10
ContentArea.Size = UDim2.new(1, -(contentOffset + 10), 1, -55) -- Sidebar + Gap
ContentArea.Position = UDim2.new(0, contentOffset, 0, 45)      -- Starts after sidebar with gap
ContentArea.BackgroundTransparency = 1

-- CONFIRMATION MODAL (Re-styled) - Wrapped to save registers
do
    local ConfirmOverlay = Instance.new("Frame", ScreenGui)
    ConfirmOverlay.Name = "ConfirmOverlay"
    ConfirmOverlay.Size = UDim2.new(1, 0, 1, 0)
    ConfirmOverlay.Position = UDim2.new(0, 0, 0, 0)
    ConfirmOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
    ConfirmOverlay.BackgroundTransparency = 0.4
    ConfirmOverlay.Visible = false
    ConfirmOverlay.ZIndex = 9999

    local ConfirmBox = Instance.new("Frame", ConfirmOverlay)
    ConfirmBox.Size = UDim2.new(0, 320, 0, 180)
    ConfirmBox.Position = UDim2.new(0.5, -160, 0.5, -90)
    ConfirmBox.BackgroundColor3 = C_MAIN
    ConfirmBox.ZIndex = 10000
    Instance.new("UICorner", ConfirmBox).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", ConfirmBox)
    stroke.Color = C_ACCENT
    stroke.Thickness = 2
    RegisterTheme(ConfirmBox, "BackgroundColor3", "Main")
    RegisterTheme(stroke, "Color", "Accent")

    local title = Instance.new("TextLabel", ConfirmBox)
    title.Text = L("system_alert")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.TextColor3 = C_ACCENT
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 16
    title.ZIndex = 10001
    RegisterTheme(title, "TextColor3", "Accent")

    local msg = Instance.new("TextLabel", ConfirmBox)
    msg.Text = L("confirm_action")
    msg.Size = UDim2.new(0.9, 0, 0, 40)
    msg.Position = UDim2.new(0.05, 0, 0, 45)
    msg.BackgroundTransparency = 1
    msg.TextColor3 = C_TEXT
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 14
    msg.TextWrapped = true
    msg.ZIndex = 10001
    RegisterTheme(msg, "TextColor3", "Text")

    local btnYes = Instance.new("TextButton", ConfirmBox)
    btnYes.Text = L("confirm")
    btnYes.Size = UDim2.new(0.4, 0, 0, 35)
    btnYes.Position = UDim2.new(0.07, 0, 0, 130)
    btnYes.BackgroundColor3 = C_ACCENT
    btnYes.TextColor3 = Color3.new(0, 0, 0)
    btnYes.Font = Enum.Font.GothamBold
    btnYes.TextSize = 12
    btnYes.ZIndex = 10001
    Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 6)
    RegisterTheme(btnYes, "BackgroundColor3", "Accent")
    -- Register for localized UI refresh
    RegisterLocalizedUI(btnYes, "confirm")

    local btnNo = Instance.new("TextButton", ConfirmBox)
    btnNo.Text = L("cancel")
    btnNo.Size = UDim2.new(0.4, 0, 0, 35)
    btnNo.Position = UDim2.new(0.53, 0, 0, 130)
    btnNo.BackgroundColor3 = C_ITEM
    btnNo.TextColor3 = C_TEXT
    btnNo.Font = Enum.Font.GothamBold
    btnNo.TextSize = 12
    btnNo.ZIndex = 10001
    Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 6)
    RegisterTheme(btnNo, "BackgroundColor3", "Item")
    RegisterTheme(btnNo, "TextColor3", "Text")
    -- Register for localized UI refresh
    RegisterLocalizedUI(btnNo, "cancel")

    ShowConfirm = function(t, m, callback, isInput)
        title.Text = (t and t ~= "") and t or L("system_alert")
        msg.Text = m
        ConfirmOverlay.Visible = true

        local inputBox = nil
        if isInput then
            inputBox = Instance.new("TextBox", ConfirmBox)
            inputBox.Size = UDim2.new(0.86, 0, 0, 30)
            inputBox.Position = UDim2.new(0.07, 0, 0, 95)
            inputBox.BackgroundColor3 = C_ITEM
            inputBox.TextColor3 = C_TEXT
            inputBox.PlaceholderColor3 = Color3.fromRGB(180, 180, 180)
            inputBox.Font = Enum.Font.Gotham
            inputBox.TextSize = 11
            inputBox.PlaceholderText = L("enter_here")
            inputBox.Text = ""
            inputBox.ZIndex = 10001
            Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 4)
            RegisterTheme(inputBox, "BackgroundColor3", "Item")
            RegisterTheme(inputBox, "TextColor3", "Text")
        end

        local c1, c2
        c1 = btnYes.MouseButton1Click:Connect(function()
            ConfirmOverlay.Visible = false
            if c1 then
                c1:Disconnect()
            end
            if c2 then
                c2:Disconnect()
            end
            if isInput and inputBox then
                local text = inputBox.Text
                inputBox:Destroy()
                callback(text)
            else
                if inputBox then
                    inputBox:Destroy()
                end
                callback()
            end
        end)
        c2 = btnNo.MouseButton1Click:Connect(function()
            ConfirmOverlay.Visible = false
            if c1 then
                c1:Disconnect()
            end
            if c2 then
                c2:Disconnect()
            end
            if inputBox then
                inputBox:Destroy()
            end
        end)
    end
end

-- SAVE MERGE MODAL
UIHandlers.ShowSaveMergeModal = function(callback)
    local Overlay = Instance.new("Frame", ScreenGui)
    Overlay.Size = UDim2.new(1, 0, 1, 0)
    Overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    Overlay.BackgroundTransparency = 0.5
    Overlay.ZIndex = 2000

    local Box = Instance.new("Frame", Overlay)
    Box.Size = UDim2.new(0, 350, 0, 160)
    Box.Position = UDim2.new(0.5, -175, 0.5, -80)
    Box.BackgroundColor3 = C_MAIN
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", Box)
    stroke.Color = C_ACCENT
    RegisterTheme(Box, "BackgroundColor3", "Main")
    RegisterTheme(stroke, "Color", "Accent")

    local Title = Instance.new("TextLabel", Box)
    Title.Text = L("save_merged_file")
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Position = UDim2.new(0, 0, 0, 10)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = C_ACCENT
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 16
    RegisterTheme(Title, "TextColor3", "Accent")

    local InpName = Instance.new("TextBox", Box)
    InpName.PlaceholderText = L("filename")
    InpName.Text = ""
    InpName.Size = UDim2.new(0.86, 0, 0, 35)
    InpName.Position = UDim2.new(0.07, 0, 0, 50)
    InpName.BackgroundColor3 = C_ITEM
    InpName.TextColor3 = C_TEXT
    InpName.Font = Enum.Font.Gotham
    InpName.TextSize = 12
    Instance.new("UICorner", InpName).CornerRadius = UDim.new(0, 6)
    RegisterTheme(InpName, "BackgroundColor3", "Item")
    RegisterTheme(InpName, "TextColor3", "Text")

    local BtnSave = Instance.new("TextButton", Box)
    BtnSave.Text = L("save")
    BtnSave.Size = UDim2.new(0.4, 0, 0, 35)
    BtnSave.Position = UDim2.new(0.07, 0, 0, 100)
    BtnSave.BackgroundColor3 = C_ACCENT
    BtnSave.TextColor3 = Color3.new(0, 0, 0)
    BtnSave.Font = Enum.Font.GothamBold
    BtnSave.TextSize = 12
    Instance.new("UICorner", BtnSave).CornerRadius = UDim.new(0, 6)
    RegisterTheme(BtnSave, "BackgroundColor3", "Accent")

    local BtnCancel = Instance.new("TextButton", Box)
    BtnCancel.Text = L("cancel")
    BtnCancel.Size = UDim2.new(0.4, 0, 0, 35)
    BtnCancel.Position = UDim2.new(0.53, 0, 0, 100)
    BtnCancel.BackgroundColor3 = C_ITEM
    BtnCancel.TextColor3 = C_TEXT
    BtnCancel.Font = Enum.Font.GothamBold
    BtnCancel.TextSize = 12
    Instance.new("UICorner", BtnCancel).CornerRadius = UDim.new(0, 6)
    RegisterTheme(BtnCancel, "BackgroundColor3", "Item")
    RegisterTheme(BtnCancel, "TextColor3", "Text")

    BtnSave.MouseButton1Click:Connect(function()
        if InpName.Text == "" then
            InpName.PlaceholderText = L("name_required")
            return
        end
        Overlay:Destroy()
        callback(InpName.Text)
    end)

    BtnCancel.MouseButton1Click:Connect(function()
        Overlay:Destroy()
    end)
end

-- RESIZE HANDLE
UIHandlers.ResizeHandle = Instance.new("TextButton", Main)
UIHandlers.ResizeHandle.Text = "◢"
UIHandlers.ResizeHandle.Size = UDim2.new(0, 20, 0, 20)
UIHandlers.ResizeHandle.Position = UDim2.new(1, -20, 1, -20)
UIHandlers.ResizeHandle.BackgroundTransparency = 1
UIHandlers.ResizeHandle.TextColor3 = C_TEXT_DIM
UIHandlers.ResizeHandle.TextSize = 14
UIHandlers.ResizeHandle.ZIndex = 100
UIHandlers.Resize = { resizing = false, dragStart = nil, startSize = nil }
MinIcon.MouseButton1Click:Connect(function()
    if not UIHandlers.DragMin.hasDragged then
        ToggleMin()
    end
end)
ToggleMinConnection = UserInputService.InputBegan:Connect(function(input)
    if
        not isBinding
        and not _G.StarshipIsBindingKeybind
        and not UserInputService:GetFocusedTextBox()
        and input.KeyCode == Config.Keybinds.ToggleMinimize
    then
        ToggleMin()
    end
end)

local currentTab = nil
local function SwitchTab(name)
    currentTab = name
    if PageDashboard then
        PageDashboard.Visible = (name == "Dashboard")
    end
    if PageRecord then
        PageRecord.Visible = (name == "Recorder")
    end
    if PagePlay then
        PagePlay.Visible = (name == "List Recorder")
    end
    if PageMerge then
        PageMerge.Visible = (name == "Merger")
        if name == "Merger" and UIHandlers.RefreshMergerList then
            UIHandlers.RefreshMergerList()
        end
    end
    if PageListMap then
        PageListMap.Visible = (name == "List Map")
    end
    if PageTools then
        PageTools.Visible = (name == "Tools")
    end
    if PageWarp then
        PageWarp.Visible = (name == "Warp")
    end
    if PageHelper then
        PageHelper.Visible = (name == "Helper")
    end
    if PageFun then
        PageFun.Visible = (name == "Fun")
    end
    if PageConfig then
        PageConfig.Visible = (name == "Config")
    end

    for _, btn in pairs(TabBtns) do
        local isSel = (btn.Name == name)
        local lbl = btn:FindFirstChild("Title")
        local ind = btn:FindFirstChild("Indicator")
        local grad = btn:FindFirstChildOfClass("UIGradient")

        local targetTrans = isSel and 0 or 1
        local targetColor = isSel and C_TEXT or C_TEXT_DIM

        -- Animate Background
        TweenService:Create(
            btn,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = targetTrans }
        ):Play()

        -- Animate Text
        if lbl then
            TweenService:Create(lbl, TweenInfo.new(0.3), { TextColor3 = targetColor }):Play()
        end

        -- Animate Indicator
        if ind then
            local targetIndTrans = isSel and 0 or 1
            TweenService:Create(ind, TweenInfo.new(0.3), { BackgroundTransparency = targetIndTrans }):Play()
            local glow = ind:FindFirstChild("ImageLabel")
            if glow then
                TweenService:Create(glow, TweenInfo.new(0.3), { ImageTransparency = (isSel and 0.5 or 1) }):Play()
            end
        end

        -- Gradient Logic (Optional: Rotate or Shift)
        if grad then
            grad.Enabled = isSel
        end
    end
end

local function CreateTab(name, icon, page)
    local btn = Instance.new("TextButton", TabContainer)
    btn.Name = name
    btn.Text = "" -- Using label for better control

    local btnHeight = 35
    btn.Size = UDim2.new(0.85, 0, 0, btnHeight)
    btn.BackgroundColor3 = C_ACCENT
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel", btn)
    lbl.Name = "Title"
    lbl.Text = string.upper(name)
    lbl.Size = UDim2.new(1, -20, 1, 0)
    lbl.Position = UDim2.new(0, 15, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = C_TEXT_DIM
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Visible = true

    -- Gradient for Active State
    local grad = Instance.new("UIGradient", btn)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)), -- Darker end
    })
    grad.Rotation = 0

    -- Active Indicator (Glowing Dot)
    local ind = Instance.new("Frame", btn)
    ind.Name = "Indicator"
    ind.Size = UDim2.new(0, 4, 0, 4)
    ind.Position = UDim2.new(0, 5, 0.5, -2)
    ind.BackgroundColor3 = C_ACCENT
    ind.BorderSizePixel = 0
    ind.BackgroundTransparency = 1 -- Hidden by default
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)

    -- Glow
    local indGlow = Instance.new("ImageLabel", ind)
    indGlow.Size = UDim2.new(3, 0, 3, 0)
    indGlow.Position = UDim2.new(-1, 0, -1, 0)
    indGlow.BackgroundTransparency = 1
    indGlow.Image = "rbxassetid://5028857472"
    indGlow.ImageColor3 = C_ACCENT
    indGlow.ImageTransparency = 0.5

    btn.MouseButton1Click:Connect(function()
        SwitchTab(name)
    end)

    -- Interactive Hover Effect
    btn.MouseEnter:Connect(function()
        if currentTab ~= name then
            if lbl.Visible then
                TweenService:Create(lbl, TweenInfo.new(0.2), { TextColor3 = C_TEXT }):Play()
            end

            TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundTransparency = 0.9 }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if currentTab ~= name then
            if lbl.Visible then
                TweenService:Create(lbl, TweenInfo.new(0.2), { TextColor3 = C_TEXT_DIM }):Play()
            end

            TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        end
    end)

    table.insert(TabBtns, btn)
end

PageRecord = Instance.new("Frame", ContentArea)
PageRecord.Size = UDim2.new(1, 0, 1, 0)
PageRecord.Position = UDim2.new(0, 0, 0, 0)
PageRecord.BackgroundTransparency = 1
PageRecord.Visible = true
PageMerge = Instance.new("Frame", ContentArea)
PageMerge.Size = UDim2.new(1, 0, 1, 0)
PageMerge.Position = UDim2.new(0, 0, 0, 0)
PageMerge.BackgroundTransparency = 1
PageMerge.Visible = false
PageListMap = Instance.new("Frame", ContentArea)
PageListMap.Size = UDim2.new(1, 0, 1, 0)
PageListMap.Position = UDim2.new(0, 0, 0, 0)
PageListMap.BackgroundTransparency = 1
PageListMap.Visible = false
PageTools = Instance.new("Frame", ContentArea)
PageTools.Size = UDim2.new(1, 0, 1, 0)
PageTools.Position = UDim2.new(0, 0, 0, 0)
PageTools.BackgroundTransparency = 1
PageTools.Visible = false
PageWarp = Instance.new("Frame", ContentArea)
PageWarp.Size = UDim2.new(1, 0, 1, 0)
PageWarp.Position = UDim2.new(0, 0, 0, 0)
PageWarp.BackgroundTransparency = 1
PageWarp.Visible = false
PageHelper = Instance.new("Frame", ContentArea)
PageHelper.Size = UDim2.new(1, 0, 1, 0)
PageHelper.Position = UDim2.new(0, 0, 0, 0)
PageHelper.BackgroundTransparency = 1
PageHelper.Visible = false
PageFun = Instance.new("Frame", ContentArea)
PageFun.Size = UDim2.new(1, 0, 1, 0)
PageFun.Position = UDim2.new(0, 0, 0, 0)
PageFun.BackgroundTransparency = 1
PageFun.Visible = false
PageConfig = Instance.new("Frame", ContentArea)
PageConfig.Size = UDim2.new(1, 0, 1, 0)
PageConfig.Position = UDim2.new(0, 0, 0, 0)
PageConfig.BackgroundTransparency = 1
PageConfig.Visible = false
PageDashboard = Instance.new("Frame", ContentArea)
PageDashboard.Size = UDim2.new(1, 0, 1, 0)
PageDashboard.Position = UDim2.new(0, 0, 0, 0)
PageDashboard.BackgroundTransparency = 1
PageDashboard.Visible = false

-- === INIT TAB MODULES ===
-- Store common parameters for tab rebuilding on language change
TabParams = {
    UIModule = UIModule,
    Connections = Connections,
    Config = Config,
    LocalPlayer = LocalPlayer,
    UIHandlers = UIHandlers,
    ShowConfirm = ShowConfirm,
    RegisterTheme = RegisterTheme,
    Themes = Themes,
    ThemeObjects = ThemeObjects,
    Main = Main,
}

-- Load and execute the modular tabs here
local WarpTab = LoadModule("Tabs/Warp")
if WarpTab then
    WarpTab(PageWarp, UIModule, Connections, Config, LocalPlayer, UIHandlers, ShowConfirm, RegisterTheme)
    -- Store for reactive refresh
    TabModules.Warp = WarpTab
    TabPages.Warp = PageWarp
end

local FunTab = LoadModule("Tabs/Fun")
if FunTab then
    FunTab(PageFun, UIModule, Connections, Config, LocalPlayer, UIHandlers, RegisterTheme)
    -- Store for reactive refresh
    TabModules.Fun = FunTab
    TabPages.Fun = PageFun
end

local ToolsTab = LoadModule("Tabs/Tools")
if ToolsTab then
    ToolsTab(PageTools, UIModule, Connections, Config, LocalPlayer, UIHandlers, RegisterTheme)
    -- Store for reactive refresh
    TabModules.Tools = ToolsTab
    TabPages.Tools = PageTools
end

local HelperTab = LoadModule("Tabs/Helper")
if HelperTab then
    HelperTab(PageHelper, UIModule, Connections, Config, LocalPlayer, UIHandlers, ShowConfirm, RegisterTheme)
    -- Store for reactive refresh
    TabModules.Helper = HelperTab
    TabPages.Helper = PageHelper
end

local EmotesTab = LoadModule("Tabs/Emotes")
if EmotesTab then
    EmotesTab(ScreenGui, UIModule, Connections, Config, LocalPlayer, UIHandlers, RegisterTheme)
end

local ConfigTabModule = LoadModule("Tabs/ConfigTab")
if ConfigTabModule then
    -- ConfigTab returns a table, not just a function
    if type(ConfigTabModule) == "table" and ConfigTabModule.SetupUI then
        ConfigTabModule.SetupUI(
            PageConfig,
            UIModule,
            Connections,
            Config,
            LocalPlayer,
            UIHandlers,
            Themes,
            ThemeObjects,
            Main
        )
        -- Force Apply Default Theme immediately to catch any missed elements
        if ConfigTabModule.ApplyTheme then
            ConfigTabModule.ApplyTheme(Config.Theme or "Default")
        end
        -- Store for reactive refresh
        TabModules.Config = ConfigTabModule
        TabPages.Config = PageConfig
    end
end

local DashboardTab = LoadModule("Tabs/Dashboard")
if DashboardTab then
    -- Store for reactive refresh (will be called below)
    TabModules.Dashboard = DashboardTab
    TabPages.Dashboard = PageDashboard
end
if DashboardTab then
    DashboardTab(PageDashboard, UIModule, Connections, Config, LocalPlayer, UIHandlers, RegisterTheme)
end

-- ========================

-- Calculate Dynamic UI Height based on Tab Count (wrapped to release locals)
local TAB_HEIGHT = 45
local TAB_MARGIN_TOP = 10
local TAB_MARGIN_BOTTOM = 60
local TOPBAR_HEIGHT = 35
local MIN_UI_HEIGHT = 500
local MAX_UI_HEIGHT = 700

local tabList = {
    { "Dashboard", "",                         PageDashboard },
    { "Recorder",  "rbxassetid://10709782497", PageRecord },
    { "Merger",    "rbxassetid://10709782823", PageMerge },
    { "List Map",  "",                         PageListMap },
    { "Warp",      "",                         PageWarp },
    { "Tools",     "",                         PageTools },
    { "Helper",    "",                         PageHelper },
    { "Fun",       "",                         PageFun },
    { "Config",    "",                         PageConfig },
}

local tabCount = #tabList
local requiredHeight = TOPBAR_HEIGHT + TAB_MARGIN_TOP + (tabCount * TAB_HEIGHT) + TAB_MARGIN_BOTTOM
requiredHeight = math.clamp(requiredHeight, MIN_UI_HEIGHT, MAX_UI_HEIGHT)
TargetMainHeight = requiredHeight

-- Update Main UI Size
Main.Size = UDim2.new(0, 550, 0, requiredHeight)
Main.Position = UDim2.new(0.5, -275, 0.5, -requiredHeight / 2)

for _, tabData in ipairs(tabList) do
    CreateTab(tabData[1], tabData[2], tabData[3])
end

SwitchTab("Dashboard")
local CountGui = Instance.new("ScreenGui", CoreGui)
CountGui.Name = "WalkGemCount"
CountGui.Enabled = false
local CountLbl = Instance.new("TextLabel", CountGui)
CountLbl.Size = UDim2.new(1, 0, 1, 0)
CountLbl.BackgroundTransparency = 1
CountLbl.TextColor3 = C_ACCENT
CountLbl.Font = Enum.Font.GothamBold
CountLbl.TextSize = 100
CountLbl.TextStrokeTransparency = 0.5

UIHandlers.StartCountdown = function(callback)
    ClearPath()
    if PathContainer then
        PathContainer:ClearAllChildren()
    end

    -- Show Countdown UI
    CountGui.Enabled = true
    local c = LocalPlayer.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")

    -- Freeze player during countdown so they don't move prematurely
    if r then
        r.Anchored = true
    end

    -- 3.. 2.. 1..
    for i = 3, 1, -1 do
        CountLbl.Text = tostring(i)
        task.wait(1)
    end

    CountLbl.Text = L("go")

    -- Unfreeze immediately BEFORE starting recording
    if r then
        r.Anchored = false
    end

    -- Start Recording NOW (This ensures the idle time during countdown is NOT recorded)
    if callback then
        callback()
    end

    task.wait(0.5)
    CountGui.Enabled = false
end

-- RECORDER UI
-- RECORDER UI (Unified Control Center)
local UIListRecord = Instance.new("UIListLayout", PageRecord)
UIListRecord.SortOrder = Enum.SortOrder.LayoutOrder
UIListRecord.Padding = UDim.new(0, 8)

-- 1. Status Card
local StatusIcon
local RStatus
do
    local StatusCard = Instance.new("Frame", PageRecord)
    StatusCard.Size = UDim2.new(1, 0, 0, 50)
    StatusCard.BackgroundColor3 = C_ITEM
    StatusCard.LayoutOrder = 1
    Instance.new("UICorner", StatusCard).CornerRadius = UDim.new(0, 8)
    RegisterTheme(StatusCard, "BackgroundColor3", "Item")

    StatusIcon = Instance.new("TextLabel", StatusCard)
    StatusIcon.Text = "⏺"
    StatusIcon.Size = UDim2.new(0, 40, 1, 0)
    StatusIcon.BackgroundTransparency = 1
    StatusIcon.TextColor3 = C_TEXT_DIM
    StatusIcon.TextSize = 24
    RegisterTheme(StatusIcon, "TextColor3", "TextDim")

    RStatus = Instance.new("TextLabel", StatusCard)
    RStatus.Text = L("ready_to_record")
    RStatus.Size = UDim2.new(1, -50, 0, 20)
    RStatus.Position = UDim2.new(0, 40, 0, 8)
    RStatus.BackgroundTransparency = 1
    RStatus.TextColor3 = C_TEXT
    RStatus.Font = Enum.Font.GothamBold
    RStatus.TextSize = 14
    RStatus.TextXAlignment = Enum.TextXAlignment.Left
    RegisterTheme(RStatus, "TextColor3", "Text")

    local RSubStatus = Instance.new("TextLabel", StatusCard)
    RSubStatus.Text = L("press_start")
    RSubStatus.Size = UDim2.new(1, -50, 0, 15)
    RSubStatus.Position = UDim2.new(0, 40, 0, 28)
    RSubStatus.BackgroundTransparency = 1
    RSubStatus.TextColor3 = C_TEXT_DIM
    RSubStatus.Font = Enum.Font.Gotham
    RSubStatus.TextSize = 11
    RSubStatus.TextXAlignment = Enum.TextXAlignment.Left
    RegisterTheme(RSubStatus, "TextColor3", "TextDim")

    RunService.Heartbeat:Connect(function()
        if isRecording and not isPaused then
            local t = tick() % 1
            StatusIcon.TextColor3 = (t < 0.5 and C_RED or C_TEXT_DIM)
            RStatus.Text = L("recording_in_progress")
            RStatus.TextColor3 = C_RED
            RSubStatus.Text = L("duration") .. ": " .. string.format("%.2fs", os.clock() - startTime)
        elseif isPaused then
            StatusIcon.TextColor3 = C_YELLOW
            RStatus.Text = L("recording_paused")
            RStatus.TextColor3 = C_YELLOW
            RSubStatus.Text = L("rewind_mode_active")
        else
            StatusIcon.TextColor3 = C_TEXT_DIM
            RStatus.Text = L("ready_to_record")
            RStatus.TextColor3 = C_TEXT
            RSubStatus.Text = L("press_start")
        end
    end)
end

-- 2. Control Grid
do
    local ControlGrid = Instance.new("Frame", PageRecord)
    ControlGrid.Size = UDim2.new(1, 0, 0, 80)
    ControlGrid.BackgroundTransparency = 1
    ControlGrid.LayoutOrder = 2
    local GridLay = Instance.new("UIGridLayout", ControlGrid)
    GridLay.CellSize = UDim2.new(0.31, 0, 0, 35)
    GridLay.CellPadding = UDim2.new(0, 8, 0, 8)

    local function CreateCtrlBtn(text, col, icon)
        local b = Instance.new("TextButton", ControlGrid)
        b.Text = icon .. "  " .. text
        b.BackgroundColor3 = C_ITEM
        b.TextColor3 = col
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        RegisterTheme(b, "BackgroundColor3", "Item")
        -- Text color is dynamic (Green/Yellow/Red), usually not themed directly or needs custom handling
        return b
    end

    local BtnStart = CreateCtrlBtn(L("start"), C_GREEN, "▶")
    local BtnPause = CreateCtrlBtn(L("pause"), C_YELLOW, "⏸")
    local BtnStop = CreateCtrlBtn(L("stop"), C_RED, "⏹")

    -- Register for language refresh
    RegisterDynamicUI(BtnStart, function(el) el.Text = "▶  " .. L("start") end)
    RegisterDynamicUI(BtnPause, function(el) el.Text = "⏸  " .. L("pause") end)
    RegisterDynamicUI(BtnStop, function(el) el.Text = "⏹  " .. L("stop") end)

    BtnStart.MouseButton1Click:Connect(function()
        UIHandlers.StartCountdown(StartRecording)
    end)
    BtnPause.MouseButton1Click:Connect(function()
        if UIHandlers.OnPauseClick then
            UIHandlers.OnPauseClick()
        end
    end)
    BtnStop.MouseButton1Click:Connect(function()
        if UIHandlers.OnStopClick then
            UIHandlers.OnStopClick()
        end
    end)
end

-- 3. Settings Panel
local BtnTogglePath
do
    local SettingsPanel = Instance.new("Frame", PageRecord)
    SettingsPanel.Size = UDim2.new(1, 0, 0, 40) -- Reduced height, only Mode and Path
    SettingsPanel.BackgroundColor3 = C_ITEM
    SettingsPanel.LayoutOrder = 3
    Instance.new("UICorner", SettingsPanel).CornerRadius = UDim.new(0, 8)
    RegisterTheme(SettingsPanel, "BackgroundColor3", "Item")

    local BtnToggleMode = Instance.new("TextButton", SettingsPanel)
    BtnToggleMode.Text = L("mode_strict")
    -- Register for language refresh (dynamic based on isFlexibleRecording state)
    RegisterDynamicUI(BtnToggleMode, function(el)
        el.Text = isFlexibleRecording and L("mode_flexible") or L("mode_strict")
    end)
    BtnToggleMode.Size = UDim2.new(0.5, -10, 0, 30)
    BtnToggleMode.Position = UDim2.new(0, 5, 0, 5)
    BtnToggleMode.BackgroundColor3 = C_MAIN
    BtnToggleMode.TextColor3 = C_TEXT
    BtnToggleMode.Font = Enum.Font.GothamBold
    BtnToggleMode.TextSize = 10
    Instance.new("UICorner", BtnToggleMode).CornerRadius = UDim.new(0, 6)
    RegisterTheme(BtnToggleMode, "BackgroundColor3", "Main")
    RegisterTheme(BtnToggleMode, "TextColor3", "Text")

    BtnTogglePath = Instance.new("TextButton", SettingsPanel)
    BtnTogglePath.Text = L("path_on")
    -- Register for language refresh (dynamic based on isPathEnabled state)
    RegisterDynamicUI(BtnTogglePath, function(el)
        el.Text = isPathEnabled and L("path_on") or L("path_off")
    end)
    BtnTogglePath.Size = UDim2.new(0.35, -5, 0, 30)
    BtnTogglePath.Position = UDim2.new(0.5, 5, 0, 5)
    BtnTogglePath.BackgroundColor3 = C_MAIN
    BtnTogglePath.TextColor3 = C_GREEN
    BtnTogglePath.Font = Enum.Font.GothamBold
    BtnTogglePath.TextSize = 10
    Instance.new("UICorner", BtnTogglePath).CornerRadius = UDim.new(0, 6)
    RegisterTheme(BtnTogglePath, "BackgroundColor3", "Main")

    local PathColors = {
        Color3.fromRGB(255, 50, 50),   -- Red
        Color3.fromRGB(50, 255, 50),   -- Green
        Color3.fromRGB(50, 50, 255),   -- Blue
        Color3.fromRGB(255, 255, 50),  -- Yellow
        Color3.fromRGB(50, 255, 255),  -- Cyan
        Color3.fromRGB(255, 50, 255),  -- Magenta
        Color3.fromRGB(255, 255, 255), -- White
    }
    local currentPathColorIndex = 1
    local currentPathColor = PathColors[1]

    local BtnPathColor = Instance.new("TextButton", SettingsPanel)
    BtnPathColor.Text = ""
    BtnPathColor.Size = UDim2.new(0.15, -5, 0, 30)
    BtnPathColor.Position = UDim2.new(0.85, 5, 0, 5)
    BtnPathColor.BackgroundColor3 = currentPathColor
    Instance.new("UICorner", BtnPathColor).CornerRadius = UDim.new(0, 6)

    BtnPathColor.MouseButton1Click:Connect(function()
        currentPathColorIndex = (currentPathColorIndex % #PathColors) + 1
        currentPathColor = PathColors[currentPathColorIndex]
        BtnPathColor.BackgroundColor3 = currentPathColor

        -- Live Update
        if isPathEnabled then
            UpdatePathColor(currentPathColor)
        end
    end)

    BtnToggleMode.MouseButton1Click:Connect(function()
        isFlexibleRecording = not isFlexibleRecording
        BtnToggleMode.Text = isFlexibleRecording and L("mode_flexible") or L("mode_strict")
        BtnToggleMode.TextColor3 = isFlexibleRecording and C_ACCENT or C_TEXT
    end)

    BtnTogglePath.MouseButton1Click:Connect(function()
        if UIHandlers.OnTogglePathClick then
            UIHandlers.OnTogglePathClick()
        end
    end)
end

-- 4. Rewind UI (Hidden by default) - Wrapped in do...end to save registers
local RewindFrame = Instance.new("Frame", PageRecord)
RewindFrame.Size = UDim2.new(1, 0, 0, 70)
RewindFrame.BackgroundColor3 = C_ITEM
RewindFrame.Visible = false
RewindFrame.LayoutOrder = 4
Instance.new("UICorner", RewindFrame).CornerRadius = UDim.new(0, 8)
RegisterTheme(RewindFrame, "BackgroundColor3", "Item")

-- Rewind UI elements (outside do block for accessibility)
local RewindTimeLbl = Instance.new("TextLabel", RewindFrame)
RewindTimeLbl.Text = "0.0s"
RewindTimeLbl.Size = UDim2.new(1, 0, 0, 20)
RewindTimeLbl.Position = UDim2.new(0, -10, 0, 5)
RewindTimeLbl.BackgroundTransparency = 1
RewindTimeLbl.TextColor3 = C_ACCENT
RewindTimeLbl.Font = Enum.Font.GothamBold
RewindTimeLbl.TextSize = 12
RewindTimeLbl.TextXAlignment = Enum.TextXAlignment.Right
RegisterTheme(RewindTimeLbl, "TextColor3", "Accent")

local RewindSliderBg = Instance.new("TextButton", RewindFrame)
RewindSliderBg.Text = ""
RewindSliderBg.Size = UDim2.new(0.9, 0, 0, 6)
RewindSliderBg.Position = UDim2.new(0.05, 0, 0.45, 0)
RewindSliderBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
RewindSliderBg.AutoButtonColor = false
Instance.new("UICorner", RewindSliderBg)

local RewindSliderFill = Instance.new("Frame", RewindSliderBg)
RewindSliderFill.Size = UDim2.new(0.5, 0, 1, 0)
RewindSliderFill.BackgroundColor3 = C_ACCENT
Instance.new("UICorner", RewindSliderFill)
RegisterTheme(RewindSliderFill, "BackgroundColor3", "Accent")

local RewindSelectedTime = 0
local function RewindUpdateSlider(input)
    local rx = input.Position.X - RewindSliderBg.AbsolutePosition.X
    local sc = math.clamp(rx / RewindSliderBg.AbsoluteSize.X, 0, 1)
    if #recordedData.Frames > 0 then
        local mt = recordedData.Frames[#recordedData.Frames].t
        RewindSelectedTime = mt * sc
        RewindSliderFill.Size = UDim2.new(sc, 0, 1, 0)
        RewindTimeLbl.Text = string.format("%.2fs / %.2fs", RewindSelectedTime, mt)
    end
end

do
    local hdr = Instance.new("TextLabel", RewindFrame)
    hdr.Text = L("rewind_control")
    hdr.Size = UDim2.new(1, 0, 0, 20)
    hdr.BackgroundTransparency = 1
    hdr.TextColor3 = C_TEXT_DIM
    hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = 10
    hdr.Position = UDim2.new(0, 0, 0, 5)
    RegisterTheme(hdr, "TextColor3", "TextDim")
    RegisterLocalizedUI(hdr, "rewind_control")

    local dragging = false
    RewindSliderBg.MouseButton1Down:Connect(function()
        dragging = true
    end)
    game:GetService("UserInputService").InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement and (isRecording and isPaused) then
            RewindUpdateSlider(i)
        end
    end)

    local btnResume = Instance.new("TextButton", RewindFrame)
    btnResume.Text = L("resume_recording")
    RegisterLocalizedUI(btnResume, "resume_recording")
    btnResume.Size = UDim2.new(0.9, 0, 0, 25)
    btnResume.Position = UDim2.new(0.05, 0, 0.65, 0)
    btnResume.BackgroundColor3 = C_GREEN
    btnResume.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", btnResume)
    btnResume.MouseButton1Click:Connect(function()
        UIHandlers.StartCountdown(function()
            CutAndResume(RewindSelectedTime)
            RewindFrame.Visible = false
        end)
    end)
end
-- 5. File List (Unified) - Defined earlier to be accessible
local ShowSaveRecordingModal -- Forward Declaration
(function()
    local FileListCard = Instance.new("Frame", PageRecord)
    FileListCard.Size = UDim2.new(1, 0, 1, -200) -- Fill remaining space
    FileListCard.BackgroundColor3 = C_ITEM
    FileListCard.LayoutOrder = 5
    Instance.new("UICorner", FileListCard).CornerRadius = UDim.new(0, 8)
    RegisterTheme(FileListCard, "BackgroundColor3", "Item")

    RewindFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        if RewindFrame.Visible then
            FileListCard.Size = UDim2.new(1, 0, 1, -270) -- Shrink to make room for RewindFrame (200 + 70)
        else
            FileListCard.Size = UDim2.new(1, 0, 1, -200) -- Restore size
        end
    end)

    -- Header with Workspace Selector
    local FileHeader = Instance.new("Frame", FileListCard)
    FileHeader.Size = UDim2.new(1, 0, 0, 35)
    FileHeader.BackgroundTransparency = 1

    local FileTitle = Instance.new("TextLabel", FileHeader)
    FileTitle.Text = "  " .. L("recordings")
    FileTitle.Size = UDim2.new(0.3, 0, 1, 0)
    FileTitle.BackgroundTransparency = 1
    FileTitle.TextColor3 = C_TEXT_DIM
    FileTitle.Font = Enum.Font.GothamBold
    FileTitle.TextSize = 10
    FileTitle.TextXAlignment = Enum.TextXAlignment.Left
    RegisterTheme(FileTitle, "TextColor3", "TextDim")
    RegisterLocalizedUI(FileTitle, "recordings", "  ")

    local PInpWorkspace = Instance.new("TextButton", FileHeader)
    PInpWorkspace.Name = "WorkspaceInput"
    PInpWorkspace.Text = currentWorkspace
    PInpWorkspace.Size = UDim2.new(0.4, 0, 0, 20)
    PInpWorkspace.Position = UDim2.new(0.3, 0, 0, 7)
    PInpWorkspace.BackgroundColor3 = C_MAIN
    PInpWorkspace.TextColor3 = C_ACCENT
    PInpWorkspace.Font = Enum.Font.Gotham
    PInpWorkspace.TextSize = 10
    Instance.new("UICorner", PInpWorkspace).CornerRadius = UDim.new(0, 4)
    RegisterTheme(PInpWorkspace, "BackgroundColor3", "Main")
    RegisterTheme(PInpWorkspace, "TextColor3", "Accent")

    local PRefresh = Instance.new("TextButton", FileHeader)
    PRefresh.Text = L("refresh")
    PRefresh.Size = UDim2.new(0, 60, 0, 20)
    PRefresh.Position = UDim2.new(1, -65, 0, 7)
    PRefresh.BackgroundColor3 = C_MAIN
    PRefresh.TextColor3 = C_TEXT
    PRefresh.Font = Enum.Font.GothamBold
    PRefresh.TextSize = 9
    Instance.new("UICorner", PRefresh).CornerRadius = UDim.new(0, 4)
    RegisterTheme(PRefresh, "BackgroundColor3", "Main")
    RegisterTheme(PRefresh, "TextColor3", "Text")
    RegisterLocalizedUI(PRefresh, "refresh")

    local PScroll = Instance.new("ScrollingFrame", FileListCard)
    PScroll.Size = UDim2.new(1, -10, 1, -35)
    PScroll.Position = UDim2.new(0, 5, 0, 35)
    PScroll.BackgroundTransparency = 1
    PScroll.BorderSizePixel = 0
    PScroll.ScrollBarThickness = 4
    Instance.new("UIListLayout", PScroll).Padding = UDim.new(0, 4)
    PScroll.ScrollBarImageColor3 = C_ACCENT
    RegisterTheme(PScroll, "ScrollBarImageColor3", "Accent")

    -- Workspace Dropdown Logic (Unified)
    local PWSList = Instance.new("Frame", FileListCard)
    PWSList.Name = "PWSList"
    PWSList.Size = UDim2.new(0.4, 0, 0, 100)
    PWSList.Position = UDim2.new(0.3, 0, 0, 30)
    PWSList.BackgroundColor3 = C_ITEM
    PWSList.BorderSizePixel = 0
    PWSList.Visible = false
    PWSList.ZIndex = 20
    Instance.new("UICorner", PWSList).CornerRadius = UDim.new(0, 6)
    RegisterTheme(PWSList, "BackgroundColor3", "Item")

    local PWSScroll = Instance.new("ScrollingFrame", PWSList)
    PWSScroll.Size = UDim2.new(1, 0, 1, 0)
    PWSScroll.BackgroundTransparency = 1
    PWSScroll.BorderSizePixel = 0
    PWSScroll.ScrollBarThickness = 4
    PWSScroll.ScrollBarImageColor3 = C_ACCENT
    PWSScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    PWSScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    PWSScroll.ZIndex = 25
    Instance.new("UIListLayout", PWSScroll).Padding = UDim.new(0, 2)
    RegisterTheme(PWSScroll, "ScrollBarImageColor3", "Accent")

    local isPWSOpen = false

    RefreshPlayerList = function()
        for _, c in pairs(PScroll:GetChildren()) do
            if c:IsA("Frame") then
                c:Destroy()
            end
        end
        local path = RECORDER_FOLDER .. "/" .. currentWorkspace
        if isfolder(path) then
            -- Get files
            local files = listfiles(path)
            local jsonFiles = {}
            for i = 1, #files do
                local f = files[i]
                if string.sub(f, -5) == ".json" then
                    table.insert(jsonFiles, f)
                end
            end

            -- ========== INLINE NATURAL SORT ==========
            local function padZero(num)
                local s = tostring(num)
                while string.len(s) < 10 do
                    s = "0" .. s
                end
                return s
            end

            local sortable = {}
            for i = 1, #jsonFiles do
                local fullPath = jsonFiles[i]
                local fileName = string.match(fullPath, "[^/\\]+$") or fullPath
                local baseName = string.gsub(fileName, "%.json$", "")
                local numPart = string.match(baseName, "(%d+)$")
                local sortKey

                if numPart and string.len(numPart) > 0 then
                    local prefixLen = string.len(baseName) - string.len(numPart)
                    local prefix = string.sub(baseName, 1, prefixLen)
                    sortKey = "1" .. string.lower(prefix) .. padZero(tonumber(numPart) or 0)
                else
                    sortKey = "0" .. string.lower(baseName) .. padZero(0)
                end

                table.insert(sortable, { path = fullPath, key = sortKey })
            end

            table.sort(sortable, function(a, b)
                return a.key < b.key
            end)

            jsonFiles = {}
            for i = 1, #sortable do
                jsonFiles[i] = sortable[i].path
            end
            -- ========== END SORT ==========

            for i = 1, #jsonFiles do
                local f = jsonFiles[i]
                if string.match(f, "%.json$") then
                    local n = string.match(f, "[^/\\]+$")
                    local item = Instance.new("Frame", PScroll)
                    item.Size = UDim2.new(1, -5, 0, 30)
                    item.BackgroundColor3 = C_MAIN
                    Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)
                    RegisterTheme(item, "BackgroundColor3", "Main")

                    local lbl = Instance.new("TextLabel", item)
                    lbl.Text = n
                    lbl.Size = UDim2.new(0.7, 0, 1, 0)
                    lbl.Position = UDim2.new(0, 10, 0, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.TextColor3 = C_TEXT
                    lbl.Font = Enum.Font.Gotham
                    lbl.TextSize = 11
                    lbl.TextXAlignment = Enum.TextXAlignment.Left
                    RegisterTheme(lbl, "TextColor3", "Text")

                    local btnPlay = Instance.new("TextButton", item)
                    btnPlay.Text = "▶"
                    btnPlay.Size = UDim2.new(0, 25, 0, 25)
                    btnPlay.Position = UDim2.new(1, -90, 0, 2.5) -- Shifted left
                    btnPlay.BackgroundColor3 = C_ITEM
                    btnPlay.TextColor3 = C_GREEN
                    Instance.new("UICorner", btnPlay).CornerRadius = UDim.new(0, 4)
                    RegisterTheme(btnPlay, "BackgroundColor3", "Item")

                    local btnStop = Instance.new("TextButton", item)
                    btnStop.Text = "⏹"
                    btnStop.Size = UDim2.new(0, 25, 0, 25)
                    btnStop.Position = UDim2.new(1, -60, 0, 2.5)
                    btnStop.BackgroundColor3 = C_ITEM
                    btnStop.TextColor3 = C_RED
                    Instance.new("UICorner", btnStop).CornerRadius = UDim.new(0, 4)
                    RegisterTheme(btnStop, "BackgroundColor3", "Item")

                    local btnDel = Instance.new("TextButton", item)
                    btnDel.Text = "🗑"
                    btnDel.Size = UDim2.new(0, 25, 0, 25)
                    btnDel.Position = UDim2.new(1, -30, 0, 2.5)
                    btnDel.BackgroundColor3 = C_ITEM
                    btnDel.TextColor3 = C_RED
                    Instance.new("UICorner", btnDel).CornerRadius = UDim.new(0, 4)
                    RegisterTheme(btnDel, "BackgroundColor3", "Item")

                    -- Update Play Button State & Selection (uses dynamic colors)
                    RunService.RenderStepped:Connect(function()
                        local colors = _G.StarshipColors or CurrentColors
                        local isSelected = (currentPlaybackFile == n)

                        -- Highlight Selection
                        item.BackgroundColor3 = isSelected and Color3.fromRGB(50, 50, 60) or colors.MAIN

                        if isSelected and isPlaying then
                            btnPlay.Text = "⏸"
                            btnPlay.TextColor3 = colors.YELLOW
                        elseif isSelected and isPlayPaused then
                            btnPlay.Text = "▶"
                            btnPlay.TextColor3 = colors.GREEN
                        else
                            btnPlay.Text = "▶"
                            btnPlay.TextColor3 = colors.GREEN
                        end
                    end)

                    btnPlay.MouseButton1Click:Connect(function()
                        if currentPlaybackFile == n and isPlaying then
                            PausePlayback()
                        elseif currentPlaybackFile == n and isPlayPaused then
                            PlayRecording(n, false) -- Resume
                        else
                            PlayRecording(n, true)  -- Force Play
                        end
                    end)

                    btnStop.MouseButton1Click:Connect(function()
                        if currentPlaybackFile == n then
                            StopPlayback()
                        end
                    end)

                    btnDel.MouseButton1Click:Connect(function()
                        ShowConfirm(L("delete_file"), L("delete") .. " " .. n .. "?", function()
                            delfile(f)
                            ShowToast(L("file_deleted"), L("deleted", n), "success", 2)

                            if UIHandlers.RefreshMergerList then
                                UIHandlers.RefreshMergerList()
                            end
                            item:Destroy() -- Optimistic UI update
                            -- Recalculate CanvasSize
                            PScroll.CanvasSize = UDim2.new(0, 0, 0, #PScroll:GetChildren() * 34)
                        end)
                    end)
                end
            end
            PScroll.CanvasSize = UDim2.new(0, 0, 0, #PScroll:GetChildren() * 34)
        end
    end

    local function UpdatePWSList()
        for _, c in pairs(PWSScroll:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextBox") then
                c:Destroy()
            end
        end

        -- 1. Input Field for New Workspace
        local NewWSInput = Instance.new("TextBox", PWSScroll)
        NewWSInput.PlaceholderText = "+ New..."
        NewWSInput.Text = ""
        NewWSInput.Size = UDim2.new(1, -8, 0, 25)
        NewWSInput.BackgroundColor3 = C_MAIN
        NewWSInput.TextColor3 = C_GREEN
        NewWSInput.Font = Enum.Font.Gotham
        NewWSInput.TextSize = 10
        NewWSInput.ZIndex = 25
        Instance.new("UICorner", NewWSInput).CornerRadius = UDim.new(0, 4)
        RegisterTheme(NewWSInput, "BackgroundColor3", "Main")

        NewWSInput.FocusLost:Connect(function(enter)
            if enter and NewWSInput.Text ~= "" then
                local newPath = RECORDER_FOLDER .. "/" .. NewWSInput.Text
                if not isfolder(newPath) then
                    makefolder(newPath)
                end
                currentWorkspace = NewWSInput.Text
                PInpWorkspace.Text = currentWorkspace
                PWSList.Visible = false
                isPWSOpen = false
                RefreshPlayerList()
            end
        end)

        -- 2. List Existing Folders
        if isfolder(RECORDER_FOLDER) then
            local folders = listfiles(RECORDER_FOLDER)
            for _, f in ipairs(folders) do
                if isfolder(f) then
                    local n = string.match(f, "[^/\\]+$") or f
                    local btn = Instance.new("TextButton", PWSScroll)
                    btn.Text = n
                    btn.Size = UDim2.new(1, -8, 0, 25)
                    btn.BackgroundColor3 = C_MAIN
                    btn.TextColor3 = C_TEXT
                    btn.Font = Enum.Font.Gotham
                    btn.TextSize = 10
                    btn.ZIndex = 25
                    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                    RegisterTheme(btn, "BackgroundColor3", "Main")
                    RegisterTheme(btn, "TextColor3", "Text")

                    btn.MouseButton1Click:Connect(function()
                        currentWorkspace = n
                        PInpWorkspace.Text = currentWorkspace
                        PWSList.Visible = false
                        isPWSOpen = false
                        RefreshPlayerList()
                    end)
                end
            end
            PWSScroll.CanvasSize = UDim2.new(0, 0, 0, 0) -- Let AutomaticCanvasSize handle it
        end
    end

    PInpWorkspace.MouseButton1Click:Connect(function()
        isPWSOpen = not isPWSOpen
        PWSList.Visible = isPWSOpen
        if isPWSOpen then
            UpdatePWSList()
        end
    end)

    PRefresh.MouseButton1Click:Connect(RefreshPlayerList)
    RefreshPlayerList() -- Initial Load

    -- SAVE MODAL LOGIC
    ShowSaveRecordingModal = function()
        local Modal = Instance.new("Frame", ScreenGui)
        Modal.Size = UDim2.new(1, 0, 1, 0)
        Modal.BackgroundColor3 = Color3.new(0, 0, 0)
        Modal.BackgroundTransparency = 0.5
        Modal.ZIndex = 1000

        local Card = Instance.new("Frame", Modal)
        Card.Size = UDim2.new(0, 300, 0, 240) -- Increased height
        Card.Position = UDim2.new(0.5, -150, 0.5, -120)
        Card.BackgroundColor3 = C_ITEM
        Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 12)
        Instance.new("UIStroke", Card).Color = C_ACCENT

        local Title = Instance.new("TextLabel", Card)
        Title.Text = L("save_recording")
        Title.Size = UDim2.new(1, 0, 0, 40)
        Title.BackgroundTransparency = 1
        Title.TextColor3 = C_TEXT
        Title.Font = Enum.Font.GothamBold
        Title.TextSize = 14

        local InpName = Instance.new("TextBox", Card)
        InpName.PlaceholderText = L("enter_filename")
        InpName.Text = "Rec_" .. os.date("%H%M%S")
        InpName.Size = UDim2.new(0.8, 0, 0, 35)
        InpName.Position = UDim2.new(0.1, 0, 0, 50)
        InpName.BackgroundColor3 = C_MAIN
        InpName.TextColor3 = C_TEXT
        InpName.Font = Enum.Font.Gotham
        Instance.new("UICorner", InpName).CornerRadius = UDim.new(0, 6)

        -- MANUAL INPUT SINK for this TextBox
        InpName.Focused:Connect(function()
            local character = LocalPlayer.Character
            savedToolBeforeFocus = character and character:FindFirstChildOfClass("Tool")
            isAnyTextBoxFocused = true
            StartToolMonitor()
            pcall(function()
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
            end)
        end)
        InpName.FocusLost:Connect(function()
            isAnyTextBoxFocused = false
            savedToolBeforeFocus = nil
            StopToolMonitor()
            pcall(function()
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
            end)
        end)

        -- Workspace Selection
        local LblWS = Instance.new("TextLabel", Card)
        LblWS.Text = L("workspace") .. ":"
        LblWS.Size = UDim2.new(0.3, 0, 0, 30)
        LblWS.Position = UDim2.new(0.1, 0, 0, 95)
        LblWS.BackgroundTransparency = 1
        LblWS.TextColor3 = C_TEXT_DIM
        LblWS.Font = Enum.Font.Gotham
        LblWS.TextSize = 11
        LblWS.TextXAlignment = Enum.TextXAlignment.Left

        local BtnWS = Instance.new("TextButton", Card)
        BtnWS.Text = currentWorkspace
        BtnWS.Size = UDim2.new(0.45, 0, 0, 30)
        BtnWS.Position = UDim2.new(0.45, 0, 0, 95)
        BtnWS.BackgroundColor3 = C_MAIN
        BtnWS.TextColor3 = C_ACCENT
        BtnWS.Font = Enum.Font.GothamBold
        BtnWS.TextSize = 11
        Instance.new("UICorner", BtnWS).CornerRadius = UDim.new(0, 6)

        local WSList = Instance.new("ScrollingFrame", Card)
        WSList.Size = UDim2.new(0.45, 0, 0, 80)
        WSList.Position = UDim2.new(0.45, 0, 0, 130)
        WSList.BackgroundColor3 = C_MAIN
        WSList.Visible = false
        WSList.ZIndex = 1005
        WSList.ScrollBarThickness = 2
        Instance.new("UICorner", WSList).CornerRadius = UDim.new(0, 6)
        local WSLayout = Instance.new("UIListLayout", WSList)
        WSLayout.Padding = UDim.new(0, 2)

        local isWSListOpen = false
        BtnWS.MouseButton1Click:Connect(function()
            isWSListOpen = not isWSListOpen
            WSList.Visible = isWSListOpen

            if isWSListOpen then
                for _, c in pairs(WSList:GetChildren()) do
                    if c:IsA("TextButton") or c:IsA("TextBox") then
                        c:Destroy()
                    end
                end

                -- New Workspace Input
                local NewWSInput = Instance.new("TextBox", WSList)
                NewWSInput.PlaceholderText = "+ " .. L("new_workspace") .. "..."
                NewWSInput.Text = ""
                NewWSInput.Size = UDim2.new(1, -4, 0, 25)
                NewWSInput.BackgroundColor3 = C_MAIN
                NewWSInput.TextColor3 = C_GREEN
                NewWSInput.Font = Enum.Font.Gotham
                NewWSInput.TextSize = 10
                NewWSInput.ZIndex = 1006
                Instance.new("UICorner", NewWSInput).CornerRadius = UDim.new(0, 4)

                NewWSInput.FocusLost:Connect(function(enter)
                    if enter and NewWSInput.Text ~= "" then
                        local newPath = RECORDER_FOLDER .. "/" .. NewWSInput.Text
                        if not isfolder(newPath) then
                            makefolder(newPath)
                        end
                        currentWorkspace = NewWSInput.Text
                        BtnWS.Text = currentWorkspace
                        WSList.Visible = false
                        isWSListOpen = false
                        -- Sync other UI elements
                        if BtnWorkspaceDropdown then
                            BtnWorkspaceDropdown.Text = currentWorkspace
                        end
                        if PInpWorkspace then
                            PInpWorkspace.Text = currentWorkspace
                        end
                        RefreshPlayerList()
                    end
                end)

                if isfolder(RECORDER_FOLDER) then
                    for _, f in ipairs(listfiles(RECORDER_FOLDER)) do
                        if isfolder(f) then
                            local n = string.match(f, "[^/\\]+$") or f
                            local b = Instance.new("TextButton", WSList)
                            b.Text = n
                            b.Size = UDim2.new(1, -4, 0, 25)
                            b.BackgroundColor3 = C_ITEM
                            b.TextColor3 = C_TEXT
                            b.Font = Enum.Font.Gotham
                            b.TextSize = 10
                            b.ZIndex = 1006
                            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
                            b.MouseButton1Click:Connect(function()
                                currentWorkspace = n
                                BtnWS.Text = currentWorkspace
                                WSList.Visible = false
                                isWSListOpen = false
                                -- Sync other UI elements
                                if BtnWorkspaceDropdown then
                                    BtnWorkspaceDropdown.Text = currentWorkspace
                                end
                                if PInpWorkspace then
                                    PInpWorkspace.Text = currentWorkspace
                                end
                                RefreshPlayerList()
                            end)
                        end
                    end
                    WSList.CanvasSize = UDim2.new(0, 0, 0, 0) -- Let AutomaticCanvasSize handle it
                    WSList.AutomaticCanvasSize = Enum.AutomaticSize.Y
                end
            end
        end)

        local BtnSave = Instance.new("TextButton", Card)
        BtnSave.Text = L("save")
        BtnSave.Size = UDim2.new(0.35, 0, 0, 35)
        BtnSave.Position = UDim2.new(0.1, 0, 0, 180) -- Moved down
        BtnSave.BackgroundColor3 = C_GREEN
        BtnSave.TextColor3 = Color3.new(1, 1, 1)
        BtnSave.Font = Enum.Font.GothamBold
        Instance.new("UICorner", BtnSave).CornerRadius = UDim.new(0, 6)

        local BtnDiscard = Instance.new("TextButton", Card)
        BtnDiscard.Text = L("discard")
        BtnDiscard.Size = UDim2.new(0.35, 0, 0, 35)
        BtnDiscard.Position = UDim2.new(0.55, 0, 0, 180) -- Moved down
        BtnDiscard.BackgroundColor3 = C_RED
        BtnDiscard.TextColor3 = Color3.new(1, 1, 1)
        BtnDiscard.Font = Enum.Font.GothamBold
        Instance.new("UICorner", BtnDiscard).CornerRadius = UDim.new(0, 6)

        BtnSave.MouseButton1Click:Connect(function()
            if InpName.Text ~= "" then
                SaveRecording(InpName.Text)
                RefreshPlayerList()
                if UIHandlers.RefreshMergerList then
                    UIHandlers.RefreshMergerList()
                end
                Modal:Destroy()
            end
        end)

        BtnDiscard.MouseButton1Click:Connect(function()
            recordedData.Frames = {}
            ClearPath() -- Clear the path visualizer
            Modal:Destroy()
        end)
    end
end)()

-- BtnStart connection moved

UIHandlers.OnPauseClick = function()
    if isRecording and not isPaused then
        isPaused = true
        RewindFrame.Visible = true
        local c = LocalPlayer.Character
        if c then
            local r = c:FindFirstChild("HumanoidRootPart")
            if r then
                r.Anchored = true
            end
            local a = c:FindFirstChild("Animate")
            if a then
                a.Disabled = true
            end
        end
        -- Initialize slider to end position
        if #recordedData.Frames > 0 then
            local mt = recordedData.Frames[#recordedData.Frames].t
            RewindSelectedTime = mt
            RewindSliderFill.Size = UDim2.new(1, 0, 1, 0)
            RewindTimeLbl.Text = string.format("%.2fs / %.2fs", mt, mt)
        end
        if Connections.Preview then
            Connections.Preview:Disconnect()
        end
        Connections.Preview = game:GetService("RunService").RenderStepped:Connect(function()
            local c = LocalPlayer.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if not r then
                return
            end
            if #recordedData.Frames == 0 then
                return
            end

            -- Find frame pair for interpolation
            local fA, fB
            for i = 1, #recordedData.Frames - 1 do
                if
                    recordedData.Frames[i].t <= RewindSelectedTime
                    and recordedData.Frames[i + 1].t >= RewindSelectedTime
                then
                    fA = recordedData.Frames[i]
                    fB = recordedData.Frames[i + 1]
                    break
                end
            end

            -- Handle edge cases: if at the very start or end
            if not fA then
                if RewindSelectedTime <= recordedData.Frames[1].t then
                    fA = recordedData.Frames[1]
                else
                    fA = recordedData.Frames[#recordedData.Frames]
                end
            end

            if fA and fB then
                local deltaT = fB.t - fA.t
                local a = deltaT > 0 and ((RewindSelectedTime - fA.t) / deltaT) or 0

                -- Support both Strict and Flexible modes
                if fA.r and fB.r then
                    -- Strict mode: CFrame data
                    r.CFrame = TblToCF(fA.r):Lerp(TblToCF(fB.r), a)
                    local j = GetJoints(c)
                    for _, m in ipairs(j) do
                        if fA.j and fA.j[m.Name] and fB.j and fB.j[m.Name] then
                            local t = TblToCF(fA.j[m.Name]):Lerp(TblToCF(fB.j[m.Name]), a)
                            m.Transform = isStrictRetarget and t.Rotation or t
                        end
                    end
                elseif fA.pos and fB.pos then
                    -- Flexible mode: Position data
                    local pos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z)
                        :Lerp(Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), a)
                    local rot = (fA.rot or 0) + ((fB.rot or 0) - (fA.rot or 0)) * a
                    r.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rot), 0)
                end
            elseif fA then
                -- Single frame (at start or end)
                if fA.r then
                    r.CFrame = TblToCF(fA.r)
                    local j = GetJoints(c)
                    for _, m in ipairs(j) do
                        if fA.j and fA.j[m.Name] then
                            local t = TblToCF(fA.j[m.Name])
                            m.Transform = isStrictRetarget and t.Rotation or t
                        end
                    end
                elseif fA.pos then
                    r.CFrame = CFrame.new(fA.pos.x, fA.pos.y, fA.pos.z) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
                end
            end
        end)
    end
end
UIHandlers.OnStopClick = function()
    if isRecording or isPaused then
        StopRecording()
        RewindFrame.Visible = false
        RStatus.Text = L("status_idle")
        RStatus.TextColor3 = C_TEXT_DIM
        ShowSaveRecordingModal()
    end
end
UIHandlers.ToggleRecording = function()
    if isRecording or isPaused then
        UIHandlers.OnStopClick()
    else
        UIHandlers.StartCountdown(StartRecording)
    end
end

UIHandlers.OnTogglePathClick = function()
    isPathEnabled = not isPathEnabled
    BtnTogglePath.Text = L("path_visualizer") .. ": " .. (isPathEnabled and L("on") or L("off"))
    BtnTogglePath.TextColor3 = isPathEnabled and C_GREEN or C_TEXT_DIM

    if isPathEnabled then
        if isPlaying or isPlayPaused then
            GeneratePlaybackPath(currentFrameData)
        elseif isRecording then
            -- Draw existing path from recordedData
            if recordedData.Frames and #recordedData.Frames > 1 then
                local lastPos = nil
                for _, f in ipairs(recordedData.Frames) do
                    local pos = (f.pos and Vector3.new(f.pos.x, f.pos.y, f.pos.z)) or (f.r and TblToCF(f.r).Position)
                    if pos then
                        if lastPos and (pos - lastPos).Magnitude > 0.5 then
                            DrawLine(lastPos, pos, currentPathColor)
                        end
                        lastPos = pos
                    end
                end
                -- Update lastPathPoint for the live loop to continue correctly
                if lastPos then
                    lastPathPoint = lastPos
                end
            end
        end
    else
        ClearPath()
    end
end

-- Connections moved

-- CLEANUP ON CLOSE
ScreenGui.AncestryChanged:Connect(function()
    if not ScreenGui.Parent then
        CleanupConnections()
    end
end)

-- Merger UI References
local MergerRefs = {
    mergeList = {},
    MScroll = nil,
    MWSScroll = nil,
    MInpWorkspace = nil,
    MWSList = nil,
    currentMergerWorkspace = "Default", -- Default workspace name
}

-- GetMergerWorkspacePath removed (Redundant/Limit Fix)

UIHandlers.UpdateMWSList = function()
    if not MergerRefs.MWSScroll then
        return
    end
    for _, c in pairs(MergerRefs.MWSScroll:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("TextBox") then
            c:Destroy()
        end
    end

    -- 1. Input Field for New Workspace
    local NewWSInput = Instance.new("TextBox", MergerRefs.MWSScroll)
    NewWSInput.PlaceholderText = "+ New..."
    NewWSInput.Text = ""
    NewWSInput.Size = UDim2.new(1, -8, 0, 25)
    NewWSInput.BackgroundColor3 = C_MAIN
    NewWSInput.TextColor3 = C_GREEN
    NewWSInput.Font = Enum.Font.Gotham
    NewWSInput.TextSize = 10
    NewWSInput.ZIndex = 25
    Instance.new("UICorner", NewWSInput).CornerRadius = UDim.new(0, 4)

    NewWSInput.FocusLost:Connect(function(enter)
        if enter and NewWSInput.Text ~= "" then
            MergerRefs.currentMergerWorkspace = NewWSInput.Text
            if MergerRefs.MInpWorkspace then
                MergerRefs.MInpWorkspace.Text = MergerRefs.currentMergerWorkspace
            end
            if MergerRefs.MWSList then
                MergerRefs.MWSList.Visible = false
            end
            if UIHandlers.RefreshMergerList then
                UIHandlers.RefreshMergerList()
            end
        end
    end)

    -- 2. List Existing Folders
    if isfolder(RECORDER_FOLDER) then
        local folders = listfiles(RECORDER_FOLDER)
        for _, f in ipairs(folders) do
            if isfolder(f) then
                local n = string.match(f, "[^/\\]+$") or f
                local btn = Instance.new("TextButton", MergerRefs.MWSScroll)
                btn.Text = n
                btn.Size = UDim2.new(1, -8, 0, 25)
                btn.BackgroundColor3 = C_MAIN
                btn.TextColor3 = C_TEXT
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 10
                btn.ZIndex = 25
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

                btn.MouseButton1Click:Connect(function()
                    MergerRefs.currentMergerWorkspace = n
                    if MergerRefs.MInpWorkspace then
                        MergerRefs.MInpWorkspace.Text = MergerRefs.currentMergerWorkspace
                    end
                    if MergerRefs.MWSList then
                        MergerRefs.MWSList.Visible = false
                    end
                    if UIHandlers.RefreshMergerList then
                        UIHandlers.RefreshMergerList()
                    end
                end)
            end
        end
        MergerRefs.MWSScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    end
end

UIHandlers.RefreshMergerList = function()
    if not MergerRefs.MScroll then
        return
    end
    for _, c in pairs(MergerRefs.MScroll:GetChildren()) do
        if c:IsA("Frame") then
            c:Destroy()
        end
    end

    local wsPath = RECORDER_FOLDER .. "/" .. MergerRefs.currentMergerWorkspace
    local colors = _G.StarshipColors or CurrentColors

    if isfolder(wsPath) then
        local files = listfiles(wsPath) or {}
        local jsonFiles = {}
        for i = 1, #files do
            local f = files[i]
            if string.sub(f, -5) == ".json" then
                table.insert(jsonFiles, f)
            end
        end

        -- ========== INLINE NATURAL SORT ==========
        -- Helper: Pad number dengan zeros
        local function padZero(num)
            local s = tostring(num)
            while string.len(s) < 10 do
                s = "0" .. s
            end
            return s
        end

        -- Buat array dengan sort info
        local sortableFiles = {}
        for i = 1, #jsonFiles do
            local fullPath = jsonFiles[i]
            local fileName = string.match(fullPath, "[^/\\]+$") or fullPath
            local baseName = string.gsub(fileName, "%.json$", "")

            -- Extract angka di akhir
            local numPart = string.match(baseName, "(%d+)$")
            local sortKey

            if numPart and string.len(numPart) > 0 then
                -- Ada angka di akhir
                local prefixLen = string.len(baseName) - string.len(numPart)
                local prefix = string.sub(baseName, 1, prefixLen)
                local number = tonumber(numPart) or 0
                -- Sort key: "1" (priority) + prefix lowercase + padded number
                sortKey = "1" .. string.lower(prefix) .. padZero(number)
            else
                -- Tidak ada angka
                sortKey = "0" .. string.lower(baseName) .. padZero(0)
            end

            table.insert(sortableFiles, {
                path = fullPath,
                sortKey = sortKey,
            })
        end

        -- Sort berdasarkan sortKey
        table.sort(sortableFiles, function(a, b)
            return a.sortKey < b.sortKey
        end)

        -- Rebuild jsonFiles dari sorted array
        jsonFiles = {}
        for i = 1, #sortableFiles do
            jsonFiles[i] = sortableFiles[i].path
        end
        -- ========== END INLINE SORT ==========

        -- Clean up mergeList
        local validMergeList = {}
        for _, m in ipairs(MergerRefs.mergeList) do
            local exists = false
            for _, f in ipairs(jsonFiles) do
                if f == m.p then
                    exists = true
                    break
                end
            end
            if exists then
                table.insert(validMergeList, m)
            end
        end
        MergerRefs.mergeList = validMergeList

        -- Update counter label
        if MergerRefs.CounterLabel then
            MergerRefs.CounterLabel.Text = L("selected") ..
                ": " .. #MergerRefs.mergeList .. " / " .. #jsonFiles .. " " .. L("total_files")
        end

        local displayIdx = 0
        for idx, f in ipairs(jsonFiles) do
            local n = string.match(f, "[^/\\]+$") or f
            local displayName = n:gsub("%.json$", "")

            -- Apply search filter
            local searchFilter = MergerRefs.SearchFilter or ""
            local shouldShow = searchFilter == "" or displayName:lower():find(searchFilter, 1, true)

            if shouldShow then
                displayIdx = displayIdx + 1
                local isSelected = false
                local selectionOrder = 0
                for i, m in ipairs(MergerRefs.mergeList) do
                    if m.n == n then
                        isSelected = true
                        selectionOrder = i
                        break
                    end
                end

                -- Main row container
                local row = Instance.new("Frame", MergerRefs.MScroll)
                row.Name = "Row_" .. displayIdx
                row.LayoutOrder = displayIdx -- PENTING: Untuk sorting UIListLayout
                row.Size = UDim2.new(1, -10, 0, 30)
                row.BackgroundColor3 = isSelected and colors.ACCENT or colors.ITEM
                row.BorderSizePixel = 0
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
                if not isSelected then
                    RegisterTheme(row, "BackgroundColor3", "Item")
                end

                -- Checkbox
                local checkbox = Instance.new("Frame", row)
                checkbox.Size = UDim2.new(0, 20, 0, 20)
                checkbox.Position = UDim2.new(0, 8, 0.5, -10)
                checkbox.BackgroundColor3 = isSelected and colors.ACCENT or colors.MAIN
                checkbox.BorderSizePixel = 0
                Instance.new("UICorner", checkbox).CornerRadius = UDim.new(0, 4)
                local checkStroke = Instance.new("UIStroke", checkbox)
                checkStroke.Color = isSelected and Color3.new(1, 1, 1) or colors.ACCENT
                checkStroke.Thickness = 1.5
                if not isSelected then
                    RegisterTheme(checkbox, "BackgroundColor3", "Main")
                end
                if not isSelected then
                    RegisterTheme(checkStroke, "Color", "Accent")
                end

                -- Checkmark
                local checkmark = Instance.new("TextLabel", checkbox)
                checkmark.Text = isSelected and "✓" or ""
                checkmark.Size = UDim2.new(1, 0, 1, 0)
                checkmark.BackgroundTransparency = 1
                checkmark.TextColor3 = isSelected and Color3.new(0, 0, 0) or colors.TEXT
                checkmark.Font = Enum.Font.GothamBold
                checkmark.TextSize = 14

                -- Selection order badge (shows merge order)
                if isSelected and selectionOrder > 0 then
                    local orderBadge = Instance.new("TextLabel", row)
                    orderBadge.Size = UDim2.new(0, 18, 0, 18)
                    orderBadge.Position = UDim2.new(0, 5, 0, 2)
                    orderBadge.BackgroundColor3 = Color3.new(0, 0, 0)
                    orderBadge.BackgroundTransparency = 0.5
                    orderBadge.Text = tostring(selectionOrder)
                    orderBadge.TextColor3 = Color3.new(1, 1, 1)
                    orderBadge.Font = Enum.Font.GothamBold
                    orderBadge.TextSize = 10
                    Instance.new("UICorner", orderBadge).CornerRadius = UDim.new(1, 0)
                end

                -- File name
                local nameLabel = Instance.new("TextLabel", row)
                nameLabel.Text = displayName
                nameLabel.Size = UDim2.new(1, -45, 0, 18)
                nameLabel.Position = UDim2.new(0, 35, 0.5, -9)
                nameLabel.BackgroundTransparency = 1
                nameLabel.TextColor3 = isSelected and Color3.new(0, 0, 0) or colors.TEXT
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextSize = 11
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                if not isSelected then
                    RegisterTheme(nameLabel, "TextColor3", "Text")
                end

                -- Click handler (invisible button overlay)
                local clickBtn = Instance.new("TextButton", row)
                clickBtn.Text = ""
                clickBtn.Size = UDim2.new(1, 0, 1, 0)
                clickBtn.BackgroundTransparency = 1
                clickBtn.ZIndex = 2

                clickBtn.MouseButton1Click:Connect(function()
                    local found = false
                    for i, m in ipairs(MergerRefs.mergeList) do
                        if m.n == n then
                            table.remove(MergerRefs.mergeList, i)
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(MergerRefs.mergeList, { n = n, p = f })
                    end
                    UIHandlers.RefreshMergerList()
                end)
            end -- end if shouldShow
        end

        -- Update canvas size based on displayed items
        MergerRefs.MScroll.CanvasSize = UDim2.new(0, 0, 0, displayIdx * 35)
    end
end

function UIHandlers.InitMergerUI()
    MergerRefs.mergeList = {}
    MergerRefs.SearchFilter = ""
    -- MERGER UI (Control Center Layout)
    local UIListMerge = Instance.new("UIListLayout", PageMerge)
    UIListMerge.SortOrder = Enum.SortOrder.LayoutOrder
    UIListMerge.Padding = UDim.new(0, 8)

    -- 0. Search Bar Card
    local SearchCard = Instance.new("Frame", PageMerge)
    SearchCard.Size = UDim2.new(1, 0, 0, 35)
    SearchCard.BackgroundColor3 = C_ITEM
    SearchCard.LayoutOrder = 0
    Instance.new("UICorner", SearchCard).CornerRadius = UDim.new(0, 8)
    RegisterTheme(SearchCard, "BackgroundColor3", "Item")

    local SearchIcon = Instance.new("TextLabel", SearchCard)
    SearchIcon.Text = "🔍"
    SearchIcon.Size = UDim2.new(0, 30, 1, 0)
    SearchIcon.Position = UDim2.new(0, 5, 0, 0)
    SearchIcon.BackgroundTransparency = 1
    SearchIcon.TextColor3 = C_TEXT_DIM
    SearchIcon.Font = Enum.Font.Gotham
    SearchIcon.TextSize = 14

    MergerRefs.SearchBox = Instance.new("TextBox", SearchCard)
    MergerRefs.SearchBox.PlaceholderText = L("search_files")
    -- Register placeholder for language refresh (need custom handling for PlaceholderText)
    RegisterDynamicUI(MergerRefs.SearchBox, function(el) el.PlaceholderText = L("search_files") end)
    MergerRefs.SearchBox.Text = ""
    MergerRefs.SearchBox.Size = UDim2.new(0.5, -40, 0, 25)
    MergerRefs.SearchBox.Position = UDim2.new(0, 35, 0.5, -12)
    MergerRefs.SearchBox.BackgroundColor3 = C_MAIN
    MergerRefs.SearchBox.TextColor3 = C_TEXT
    MergerRefs.SearchBox.PlaceholderColor3 = C_TEXT_DIM
    MergerRefs.SearchBox.Font = Enum.Font.Gotham
    MergerRefs.SearchBox.TextSize = 11
    MergerRefs.SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    MergerRefs.SearchBox.ClearTextOnFocus = false
    Instance.new("UICorner", MergerRefs.SearchBox).CornerRadius = UDim.new(0, 6)
    Instance.new("UIPadding", MergerRefs.SearchBox).PaddingLeft = UDim.new(0, 8)
    RegisterTheme(MergerRefs.SearchBox, "BackgroundColor3", "Main")
    RegisterTheme(MergerRefs.SearchBox, "TextColor3", "Text")
    RegisterTheme(MergerRefs.SearchBox, "PlaceholderColor3", "TextDim")

    -- Counter Label
    MergerRefs.CounterLabel = Instance.new("TextLabel", SearchCard)
    MergerRefs.CounterLabel.Text = L("selected") .. ": 0 / 0 " .. L("total_files")
    -- CounterLabel is updated dynamically in RefreshMergerList, no need to register here
    MergerRefs.CounterLabel.Size = UDim2.new(0.45, -10, 1, 0)
    MergerRefs.CounterLabel.Position = UDim2.new(0.55, 0, 0, 0)
    MergerRefs.CounterLabel.BackgroundTransparency = 1
    MergerRefs.CounterLabel.TextColor3 = C_ACCENT
    MergerRefs.CounterLabel.Font = Enum.Font.GothamBold
    MergerRefs.CounterLabel.TextSize = 11
    MergerRefs.CounterLabel.TextXAlignment = Enum.TextXAlignment.Right
    RegisterTheme(MergerRefs.CounterLabel, "TextColor3", "Accent")

    -- Search functionality
    MergerRefs.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        MergerRefs.SearchFilter = MergerRefs.SearchBox.Text:lower()
        UIHandlers.RefreshMergerList()
    end)

    -- 1. Selection Browser
    local MergeCard = Instance.new("Frame", PageMerge)
    MergeCard.Size = UDim2.new(1, 0, 1, -115)
    MergeCard.BackgroundColor3 = C_ITEM
    MergeCard.LayoutOrder = 1
    Instance.new("UICorner", MergeCard).CornerRadius = UDim.new(0, 8)
    RegisterTheme(MergeCard, "BackgroundColor3", "Item")

    local MergeHeader = Instance.new("Frame", MergeCard)
    MergeHeader.Size = UDim2.new(1, 0, 0, 32) -- Diperbesar dari 30 ke 32
    MergeHeader.BackgroundTransparency = 1
    local MergeTitle = Instance.new("TextLabel", MergeHeader)
    MergeTitle.Text = "  " .. L("select_files_to_merge")
    RegisterLocalizedUI(MergeTitle, "select_files_to_merge", "  ")
    MergeTitle.Size = UDim2.new(0.4, 0, 1, 0) -- Dikurangi dari 0.5 ke 0.4
    MergeTitle.BackgroundTransparency = 1
    MergeTitle.TextColor3 = C_TEXT_DIM
    MergeTitle.Font = Enum.Font.GothamBold
    MergeTitle.TextSize = 11 -- Diperbesar dari 10 ke 11
    MergeTitle.TextXAlignment = Enum.TextXAlignment.Left
    RegisterTheme(MergeTitle, "TextColor3", "TextDim")

    local MRefresh = Instance.new("TextButton", MergeHeader)
    MRefresh.Text = "↻"
    MRefresh.Size = UDim2.new(0, 28, 0, 24) -- Diperbesar dari 25x20 ke 28x24
    MRefresh.Position = UDim2.new(1, -33, 0, 3)
    MRefresh.BackgroundColor3 = C_MAIN
    MRefresh.TextColor3 = C_TEXT
    MRefresh.Font = Enum.Font.GothamBold
    MRefresh.TextSize = 16 -- Diperbesar dari 14 ke 16
    Instance.new("UICorner", MRefresh).CornerRadius = UDim.new(0, 6)
    RegisterTheme(MRefresh, "BackgroundColor3", "Main")
    RegisterTheme(MRefresh, "TextColor3", "Text")

    MergerRefs.MInpWorkspace = Instance.new("TextButton", MergeHeader) -- Global for sync
    MergerRefs.MInpWorkspace.Text = MergerRefs.currentMergerWorkspace
    MergerRefs.MInpWorkspace.Size = UDim2.new(0.35, 0, 0, 24)
    MergerRefs.MInpWorkspace.Position = UDim2.new(0.42, 0, 0, 3)
    MergerRefs.MInpWorkspace.BackgroundColor3 = C_MAIN
    MergerRefs.MInpWorkspace.TextColor3 = C_ACCENT
    MergerRefs.MInpWorkspace.Font = Enum.Font.GothamBold
    MergerRefs.MInpWorkspace.TextSize = 10                          -- Sedikit lebih kecil agar muat
    MergerRefs.MInpWorkspace.TextTruncate = Enum.TextTruncate.AtEnd -- Truncate text yang terlalu panjang
    MergerRefs.MInpWorkspace.ClipsDescendants = true                -- Pastikan tidak keluar
    Instance.new("UICorner", MergerRefs.MInpWorkspace).CornerRadius = UDim.new(0, 6)
    local MInpPadding = Instance.new("UIPadding", MergerRefs.MInpWorkspace)
    MInpPadding.PaddingLeft = UDim.new(0, 8)
    MInpPadding.PaddingRight = UDim.new(0, 8)
    RegisterTheme(MergerRefs.MInpWorkspace, "BackgroundColor3", "Main")
    RegisterTheme(MergerRefs.MInpWorkspace, "TextColor3", "Accent")

    MergerRefs.MWSList = Instance.new("Frame", MergeCard)   -- Global for sync
    MergerRefs.MWSList.Name = "MWSList"
    MergerRefs.MWSList.Size = UDim2.new(0.35, 0, 0, 150)    -- Diperbesar dari 0.3/100 ke 0.35/150
    MergerRefs.MWSList.Position = UDim2.new(0.42, 0, 0, 30) -- Posisi tepat di bawah dropdown button
    MergerRefs.MWSList.BackgroundColor3 = C_SIDE            -- Diubah ke C_SIDE untuk kontras lebih baik
    MergerRefs.MWSList.BorderSizePixel = 0
    MergerRefs.MWSList.Visible = false
    MergerRefs.MWSList.ZIndex = 50 -- Diperbesar dari 20 ke 50 agar selalu di atas
    MergerRefs.MWSList.ClipsDescendants = true
    Instance.new("UICorner", MergerRefs.MWSList).CornerRadius = UDim.new(0, 8)
    local MWSStroke = Instance.new("UIStroke", MergerRefs.MWSList)
    MWSStroke.Color = C_ACCENT
    MWSStroke.Thickness = 1
    MWSStroke.Transparency = 0.5
    RegisterTheme(MergerRefs.MWSList, "BackgroundColor3", "Side")
    RegisterTheme(MWSStroke, "Color", "Accent")

    MergerRefs.MWSScroll = Instance.new("ScrollingFrame", MergerRefs.MWSList) -- Global for sync
    MergerRefs.MWSScroll.Size = UDim2.new(1, -4, 1, -4)                       -- Padding dalam
    MergerRefs.MWSScroll.Position = UDim2.new(0, 2, 0, 2)
    MergerRefs.MWSScroll.BackgroundTransparency = 1
    MergerRefs.MWSScroll.BorderSizePixel = 0
    MergerRefs.MWSScroll.ScrollBarThickness = 4
    MergerRefs.MWSScroll.ScrollBarImageColor3 = C_ACCENT
    MergerRefs.MWSScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    MergerRefs.MWSScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    MergerRefs.MWSScroll.ZIndex = 51
    local MWSLayout = Instance.new("UIListLayout", MergerRefs.MWSScroll)
    MWSLayout.Padding = UDim.new(0, 4) -- Diperbesar dari 2 ke 4
    RegisterTheme(MergerRefs.MWSScroll, "ScrollBarImageColor3", "Accent")

    local _ignored_UpdateMWSList = function()
        for _, c in pairs(MergerRefs.MWSScroll:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextBox") then
                c:Destroy()
            end
        end

        -- 1. Input Field for New Workspace
        local NewWSInput = Instance.new("TextBox", MergerRefs.MWSScroll)
        NewWSInput.PlaceholderText = "+ New..."
        NewWSInput.Text = ""
        NewWSInput.Size = UDim2.new(1, -4, 0, 32)
        NewWSInput.BackgroundColor3 = C_ITEM
        NewWSInput.TextColor3 = C_GREEN
        NewWSInput.PlaceholderColor3 = C_GREEN
        NewWSInput.Font = Enum.Font.GothamBold
        NewWSInput.TextSize = 10
        NewWSInput.TextTruncate = Enum.TextTruncate.AtEnd
        NewWSInput.ClipsDescendants = true
        NewWSInput.ClearTextOnFocus = false
        NewWSInput.ZIndex = 52
        Instance.new("UICorner", NewWSInput).CornerRadius = UDim.new(0, 5)
        local newPad = Instance.new("UIPadding", NewWSInput)
        newPad.PaddingLeft = UDim.new(0, 10)
        newPad.PaddingRight = UDim.new(0, 6)
        RegisterTheme(NewWSInput, "BackgroundColor3", "Item")

        NewWSInput.FocusLost:Connect(function(enter)
            if enter and NewWSInput.Text ~= "" then
                MergerRefs.currentMergerWorkspace = NewWSInput.Text
                MergerRefs.MInpWorkspace.Text = MergerRefs.currentMergerWorkspace
                MergerRefs.MWSList.Visible = false
                if UIHandlers.RefreshMergerList then
                    UIHandlers.RefreshMergerList()
                end
            end
        end)

        -- 2. List Existing Folders
        if isfolder(RECORDER_FOLDER) then
            local folders = listfiles(RECORDER_FOLDER)
            for _, f in ipairs(folders) do
                if isfolder(f) then
                    local n = string.match(f, "[^/\\]+$") or f
                    local btn = Instance.new("TextButton", MergerRefs.MWSScroll)
                    btn.Text = n
                    btn.Size = UDim2.new(1, -4, 0, 32)
                    btn.BackgroundColor3 = C_ITEM
                    btn.TextColor3 = C_TEXT
                    btn.Font = Enum.Font.Gotham
                    btn.TextSize = 10
                    btn.TextXAlignment = Enum.TextXAlignment.Left
                    btn.TextTruncate = Enum.TextTruncate.AtEnd -- Truncate text panjang
                    btn.ClipsDescendants = true
                    btn.AutoButtonColor = true
                    btn.ZIndex = 52
                    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
                    local btnPad = Instance.new("UIPadding", btn)
                    btnPad.PaddingLeft = UDim.new(0, 10)
                    btnPad.PaddingRight = UDim.new(0, 6)
                    RegisterTheme(btn, "BackgroundColor3", "Item")
                    RegisterTheme(btn, "TextColor3", "Text")

                    btn.MouseButton1Click:Connect(function()
                        MergerRefs.currentMergerWorkspace = n
                        MergerRefs.MInpWorkspace.Text = MergerRefs.currentMergerWorkspace
                        MergerRefs.MWSList.Visible = false
                        if UIHandlers.RefreshMergerList then
                            UIHandlers.RefreshMergerList()
                        end
                    end)
                end
            end
            MergerRefs.MWSScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        end
    end
    -- Hook the update function
    UIHandlers.UpdateMWSList = _ignored_UpdateMWSList

    MergerRefs.MInpWorkspace.MouseButton1Click:Connect(function()
        MergerRefs.MWSList.Visible = not MergerRefs.MWSList.Visible
        if MergerRefs.MWSList.Visible then
            UIHandlers.UpdateMWSList()
        end
    end)

    local BtnPlusMerge = Instance.new("TextButton", MergeHeader)
    BtnPlusMerge.Text = "+"
    BtnPlusMerge.Size = UDim2.new(0, 24, 0, 24)      -- Diperbesar dari 20 ke 24
    BtnPlusMerge.Position = UDim2.new(0.78, 0, 0, 3) -- Digeser ke kanan
    BtnPlusMerge.BackgroundColor3 = C_MAIN
    BtnPlusMerge.TextColor3 = C_GREEN
    BtnPlusMerge.Font = Enum.Font.GothamBold
    BtnPlusMerge.TextSize = 16 -- Diperbesar dari 14 ke 16
    Instance.new("UICorner", BtnPlusMerge).CornerRadius = UDim.new(0, 6)
    RegisterTheme(BtnPlusMerge, "BackgroundColor3", "Main")

    BtnPlusMerge.MouseButton1Click:Connect(function()
        if ShowConfirm then
            ShowConfirm(L("new_workspace"), L("workspace_name"), function(name)
                if name and name ~= "" then
                    local newPath = RECORDER_FOLDER .. "/" .. name
                    if not isfolder(newPath) then
                        makefolder(newPath)
                        currentWorkspace = name
                        if UIHandlers.RefreshMergerList then
                            UIHandlers.RefreshMergerList()
                        end
                    else
                        ShowConfirm(L("error"), L("workspace_exists"), function() end)
                    end
                end
            end, true)
        end
    end)

    MergerRefs.MScroll = Instance.new("ScrollingFrame", MergeCard)
    MergerRefs.MScroll.Size = UDim2.new(1, -10, 1, -38)  -- Diubah dari -35 ke -38
    MergerRefs.MScroll.Position = UDim2.new(0, 5, 0, 34) -- Diubah dari 30 ke 34
    MergerRefs.MScroll.BackgroundTransparency = 1
    MergerRefs.MScroll.BorderSizePixel = 0
    MergerRefs.MScroll.ScrollBarThickness = 4
    local MScrollLayout = Instance.new("UIListLayout", MergerRefs.MScroll)
    MScrollLayout.Padding = UDim.new(0, 4)
    MScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder -- PENTING: Gunakan LayoutOrder!
    MergerRefs.MScroll.ScrollBarImageColor3 = C_ACCENT
    RegisterTheme(MergerRefs.MScroll, "ScrollBarImageColor3", "Accent")

    -- 2. Merge Actions
    local ActionCard = Instance.new("Frame", PageMerge)
    ActionCard.Size = UDim2.new(1, 0, 0, 60) -- Reduced height
    ActionCard.BackgroundColor3 = C_ITEM
    ActionCard.LayoutOrder = 2
    Instance.new("UICorner", ActionCard).CornerRadius = UDim.new(0, 8)
    RegisterTheme(ActionCard, "BackgroundColor3", "Item")

    MMergeBtn = Instance.new("TextButton", ActionCard)
    MMergeBtn.Text = L("merge_selected")
    MMergeBtn.Size = UDim2.new(0.9, 0, 0, 40)
    MMergeBtn.Position = UDim2.new(0.05, 0, 0, 10)
    MMergeBtn.BackgroundColor3 = C_ACCENT
    MMergeBtn.TextColor3 = Color3.new(1, 1, 1)
    MMergeBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", MMergeBtn).CornerRadius = UDim.new(0, 6)
    RegisterTheme(MMergeBtn, "BackgroundColor3", "Accent")

    MMergeBtn.MouseButton1Click:Connect(function()
        if #MergerRefs.mergeList < 2 then
            MMergeBtn.Text = L("select_at_least_two")
            MMergeBtn.BackgroundColor3 = C_RED
            task.wait(1)
            MMergeBtn.Text = L("merge_selected")
            MMergeBtn.BackgroundColor3 = C_ACCENT
            return
        end

        UIHandlers.ShowSaveMergeModal(function(name)
            task.spawn(function()
                ShowLoadingModal(true, L("preparing", "Merge"), 0)
                task.wait(0.1) -- Allow UI to update

                local finalFrames = {}
                local timeOffset = 0
                local totalFiles = #MergerRefs.mergeList

                for i, item in ipairs(MergerRefs.mergeList) do
                    -- Update Progress (0% to 80% allocated for processing)
                    local progress = ((i - 1) / totalFiles) * 0.8
                    ShowLoadingModal(true, L("merge") .. " " .. i .. "/" .. totalFiles, progress)
                    task.wait() -- Yield per file to keep UI responsive

                    local s, content = pcall(readfile, item.p)
                    if s then
                        local data = HttpService:JSONDecode(content)
                        local frames = data.Frames or data
                        if frames and #frames > 0 then
                            -- 1. TRIM END of Previous File
                            if #finalFrames > 0 then
                                local lastKeepIndex = #finalFrames
                                for k = #finalFrames, 1, -1 do
                                    if k % 100 == 0 then
                                        task.wait()
                                    end -- More frequent yielding

                                    local f = finalFrames[k]
                                    local isMoving = false
                                    if f.vel and (math.abs(f.vel.x) > 1.0 or math.abs(f.vel.z) > 1.0) then
                                        isMoving = true
                                    end

                                    if not isMoving and k > 1 then
                                        local prev = finalFrames[k - 1]
                                        local p1 = (f.pos and Vector3.new(f.pos.x, 0, f.pos.z))
                                            or (f.r and Vector3.new(f.r[1], 0, f.r[3]))
                                        local p2 = (prev.pos and Vector3.new(prev.pos.x, 0, prev.pos.z))
                                            or (prev.r and Vector3.new(prev.r[1], 0, prev.r[3]))
                                        if p1 and p2 and (p1 - p2).Magnitude > 0.05 then
                                            isMoving = true
                                        end
                                    end

                                    if isMoving then
                                        lastKeepIndex = k
                                        break
                                    end
                                end

                                -- Optimized: rebuild array instead of table.remove (faster)
                                if lastKeepIndex < #finalFrames then
                                    local trimmedFrames = {}
                                    for k = 1, lastKeepIndex do
                                        trimmedFrames[k] = finalFrames[k]
                                        if k % 100 == 0 then
                                            task.wait()
                                        end
                                    end
                                    finalFrames = trimmedFrames
                                    timeOffset = finalFrames[#finalFrames].t
                                end
                            end

                            -- 2. TRIM START of Current File
                            local trimTime = 0
                            if true then
                                local startPos = (
                                    frames[1].pos and Vector3.new(frames[1].pos.x, frames[1].pos.y, frames[1].pos.z)
                                ) or (frames[1].r and TblToCF(frames[1].r).Position)
                                for j, f in ipairs(frames) do
                                    if j % 100 == 0 then
                                        task.wait()
                                    end -- More frequent yielding

                                    local currPos = (f.pos and Vector3.new(f.pos.x, f.pos.y, f.pos.z))
                                        or (f.r and TblToCF(f.r).Position)
                                    if startPos and currPos and (currPos - startPos).Magnitude > 0.5 then
                                        trimTime = f.t
                                        break
                                    end
                                end
                                if trimTime >= frames[#frames].t then
                                    trimTime = 0
                                end
                            end

                            local fileDuration = 0
                            for j, f in ipairs(frames) do
                                if j % 100 == 0 then
                                    task.wait()
                                end -- More frequent yielding

                                if f.t >= trimTime then
                                    local newFrame = {
                                        t = (f.t - trimTime) + timeOffset,
                                        r = f.r,
                                        j = f.j,
                                        pos = f.pos,
                                        rot = f.rot,
                                        vel = f.vel,
                                        md = f.md,
                                        st = f.st,
                                        jmp = f.jmp,
                                        hh = f.hh,
                                        -- Shiftlock / Camera data
                                        camLook = f.camLook,
                                        shiftlock = f.shiftlock,
                                        charLook = f.charLook,
                                        -- Tool state (equipped tool name)
                                        tool = f.tool,
                                    }
                                    table.insert(finalFrames, newFrame)
                                    fileDuration = newFrame.t
                                end
                            end
                            timeOffset = fileDuration
                        end
                    end
                end

                -- Prepare final data
                local finalData = { FPS = 60, Frames = finalFrames }

                -- Saving (90% to 100%)
                ShowLoadingModal(true, L("saving_file"), 0.95)
                task.wait(0.1)

                writefile(MERGER_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(finalData))

                ShowLoadingModal(false)
                ShowToast(L("merge_complete"), L("merged_files", totalFiles, name), "success", 3)

                MergerRefs.mergeList = {}
                if UIHandlers.RefreshMergerList then
                    UIHandlers.RefreshMergerList()
                end

                if SwitchTab then
                    SwitchTab("List Map")
                end
            end)
        end)
    end)

    MRefresh.MouseButton1Click:Connect(function()
        MergerRefs.mergeList = {}
        UIHandlers.RefreshMergerList()
    end)
    UIHandlers.RefreshMergerList()
end

UIHandlers.InitMergerUI()

-- --- FUN UI ---
function UIHandlers.SetupListMapUI()
    local MapContainer = Instance.new("Frame", PageListMap)
    MapContainer.Size = UDim2.new(1, 0, 1, 0)
    MapContainer.BackgroundTransparency = 1
    MapContainer.ClipsDescendants = true -- PENTING: Mencegah konten keluar dari container

    -- Header Area (Fixed height container for header elements)
    local HeaderArea = Instance.new("Frame", MapContainer)
    HeaderArea.Size = UDim2.new(1, 0, 0, 125) -- Total: 40 + 30 + 35 + 20 (padding)
    HeaderArea.Position = UDim2.new(0, 0, 0, 0)
    HeaderArea.BackgroundTransparency = 1

    local MapLayout = Instance.new("UIListLayout", HeaderArea)
    MapLayout.Padding = UDim.new(0, 10)
    MapLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MapLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    -- Header Card
    local HeaderCard = Instance.new("Frame", HeaderArea)
    HeaderCard.Size = UDim2.new(0.96, 0, 0, 40) -- Reduced Height
    HeaderCard.BackgroundColor3 = C_ITEM
    HeaderCard.LayoutOrder = 0
    Instance.new("UICorner", HeaderCard).CornerRadius = UDim.new(0, 8)
    RegisterTheme(HeaderCard, "BackgroundColor3", "Item")

    local HeaderTitle = Instance.new("TextLabel", HeaderCard)
    HeaderTitle.Text = L("map_recordings")
    RegisterLocalizedUI(HeaderTitle, "map_recordings")
    HeaderTitle.Size = UDim2.new(1, -80, 1, 0) -- Full height, minus button space
    HeaderTitle.Position = UDim2.new(0, 15, 0, 0)
    HeaderTitle.BackgroundTransparency = 1
    HeaderTitle.TextColor3 = C_TEXT
    HeaderTitle.Font = Enum.Font.GothamBold
    HeaderTitle.TextSize = 12
    HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
    RegisterTheme(HeaderTitle, "TextColor3", "Text")

    local BtnRefresh = Instance.new("TextButton", HeaderCard)
    BtnRefresh.Text = L("refresh")
    RegisterLocalizedUI(BtnRefresh, "refresh")
    BtnRefresh.Size = UDim2.new(0, 60, 0, 24)
    BtnRefresh.AnchorPoint = Vector2.new(1, 0.5)
    BtnRefresh.Position = UDim2.new(1, -10, 0.5, 0) -- Centered Vertically
    BtnRefresh.BackgroundColor3 = C_MAIN
    BtnRefresh.TextColor3 = C_TEXT
    BtnRefresh.Font = Enum.Font.GothamBold
    BtnRefresh.TextSize = 9
    Instance.new("UICorner", BtnRefresh).CornerRadius = UDim.new(0, 4)
    RegisterTheme(BtnRefresh, "BackgroundColor3", "Main")
    RegisterTheme(BtnRefresh, "TextColor3", "Text")

    -- Search Bar
    local SearchFrame = Instance.new("Frame", HeaderArea)
    SearchFrame.Size = UDim2.new(0.96, 0, 0, 30)
    SearchFrame.BackgroundColor3 = C_ITEM
    SearchFrame.LayoutOrder = 1
    Instance.new("UICorner", SearchFrame).CornerRadius = UDim.new(0, 6)
    RegisterTheme(SearchFrame, "BackgroundColor3", "Item")

    -- Settings Row (Native Anim & Strict Retarget)
    local SettingsRow = Instance.new("Frame", HeaderArea)
    SettingsRow.Size = UDim2.new(0.96, 0, 0, 35)
    SettingsRow.BackgroundTransparency = 1
    SettingsRow.LayoutOrder = 2

    local BtnStrictRetarget = Instance.new("TextButton", SettingsRow)
    BtnStrictRetarget.Text = L("strict_retarget") .. ": " .. L("off")
    -- Register for language refresh (dynamic based on isStrictRetarget state)
    RegisterDynamicUI(BtnStrictRetarget, function(el)
        el.Text = L("strict_retarget") .. ": " .. (isStrictRetarget and L("on") or L("off"))
    end)
    BtnStrictRetarget.Size = UDim2.new(0.48, -5, 1, 0)
    BtnStrictRetarget.Position = UDim2.new(0, 0, 0, 0)
    BtnStrictRetarget.BackgroundColor3 = C_ITEM
    BtnStrictRetarget.TextColor3 = C_TEXT_DIM
    BtnStrictRetarget.Font = Enum.Font.GothamBold
    BtnStrictRetarget.TextSize = 9
    Instance.new("UICorner", BtnStrictRetarget).CornerRadius = UDim.new(0, 6)
    RegisterTheme(BtnStrictRetarget, "BackgroundColor3", "Item")

    local BtnNativeAnim = Instance.new("TextButton", SettingsRow)
    BtnNativeAnim.Text = L("native_anim") .. ": " .. L("off")
    -- Register for language refresh (dynamic based on isNativeAnim state)
    RegisterDynamicUI(BtnNativeAnim, function(el)
        el.Text = L("native_anim") .. ": " .. (isNativeAnim and L("on") or L("off"))
    end)
    BtnNativeAnim.Size = UDim2.new(0.48, -5, 1, 0)
    BtnNativeAnim.Position = UDim2.new(0.52, 0, 0, 0)
    BtnNativeAnim.BackgroundColor3 = C_ITEM
    BtnNativeAnim.TextColor3 = C_TEXT_DIM
    BtnNativeAnim.Font = Enum.Font.GothamBold
    BtnNativeAnim.TextSize = 9
    Instance.new("UICorner", BtnNativeAnim).CornerRadius = UDim.new(0, 6)
    RegisterTheme(BtnNativeAnim, "BackgroundColor3", "Item")

    -- Logic for Buttons
    BtnStrictRetarget.MouseButton1Click:Connect(function()
        isStrictRetarget = not isStrictRetarget
        BtnStrictRetarget.Text = L("strict_retarget") .. ": " .. (isStrictRetarget and L("on") or L("off"))
        BtnStrictRetarget.TextColor3 = isStrictRetarget and C_GREEN or C_TEXT_DIM
    end)

    BtnNativeAnim.MouseButton1Click:Connect(function()
        isNativeAnim = not isNativeAnim
        BtnNativeAnim.Text = L("native_anim") .. ": " .. (isNativeAnim and L("on") or L("off"))
        BtnNativeAnim.TextColor3 = isNativeAnim and C_GREEN or C_TEXT_DIM
    end)

    local SearchIcon = Instance.new("ImageLabel", SearchFrame)
    SearchIcon.Size = UDim2.new(0, 16, 0, 16)
    SearchIcon.Position = UDim2.new(0, 10, 0.5, -8)
    SearchIcon.BackgroundTransparency = 1
    SearchIcon.Image = "rbxassetid://6031154871" -- Search Icon
    SearchIcon.ImageColor3 = C_TEXT_DIM
    RegisterTheme(SearchIcon, "ImageColor3", "TextDim")

    local SearchBar = Instance.new("TextBox", SearchFrame)
    SearchBar.Size = UDim2.new(1, -40, 1, 0)
    SearchBar.Position = UDim2.new(0, 35, 0, 0)
    SearchBar.BackgroundTransparency = 1
    SearchBar.TextColor3 = C_TEXT
    SearchBar.PlaceholderText = L("search_files")
    -- Register placeholder for language refresh
    RegisterDynamicUI(SearchBar, function(el) el.PlaceholderText = L("search_files") end)
    SearchBar.PlaceholderColor3 = C_TEXT_DIM
    SearchBar.Font = Enum.Font.Gotham
    SearchBar.TextSize = 11
    SearchBar.TextXAlignment = Enum.TextXAlignment.Left
    SearchBar.ClearTextOnFocus = false
    RegisterTheme(SearchBar, "TextColor3", "Text")
    RegisterTheme(SearchBar, "PlaceholderColor3", "TextDim")

    -- PLAYBACK POPUP WINDOW (Redesigned - Modern Compact Style)
    local MapPlayerPopup = Instance.new("Frame", ScreenGui)
    MapPlayerPopup.Name = "MapPlayerPopup"
    MapPlayerPopup.Size = UDim2.new(0, 300, 0, 260)
    MapPlayerPopup.Position = UDim2.new(0.5, -150, 0.5, -130)
    MapPlayerPopup.BackgroundColor3 = C_MAIN
    MapPlayerPopup.BackgroundTransparency = 0
    MapPlayerPopup.Visible = false
    MapPlayerPopup.ZIndex = 300
    Instance.new("UICorner", MapPlayerPopup).CornerRadius = UDim.new(0, 12)
    RegisterTheme(MapPlayerPopup, "BackgroundColor3", "Main")

    local PopupStroke = Instance.new("UIStroke", MapPlayerPopup)
    PopupStroke.Color = C_ACCENT
    PopupStroke.Thickness = 1.5
    PopupStroke.Transparency = 0
    RegisterTheme(PopupStroke, "Color", "Accent")

    -- Dragging Logic for Popup
    local dragging, dragInput, dragStart, startPos
    MapPlayerPopup.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MapPlayerPopup.Position
        end
    end)
    MapPlayerPopup.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MapPlayerPopup.Position =
                UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    -- Header Section (Title Bar)
    local PopupHeader = Instance.new("Frame", MapPlayerPopup)
    PopupHeader.Size = UDim2.new(1, 0, 0, 40)
    PopupHeader.BackgroundColor3 = C_SIDE
    PopupHeader.BackgroundTransparency = 0
    PopupHeader.ZIndex = 301
    local HeaderCorner = Instance.new("UICorner", PopupHeader)
    HeaderCorner.CornerRadius = UDim.new(0, 12)
    RegisterTheme(PopupHeader, "BackgroundColor3", "Side")

    -- Mask bottom corners of header
    local HeaderMask = Instance.new("Frame", PopupHeader)
    HeaderMask.Size = UDim2.new(1, 0, 0.5, 0)
    HeaderMask.Position = UDim2.new(0, 0, 0.5, 0)
    HeaderMask.BackgroundColor3 = C_SIDE
    HeaderMask.BackgroundTransparency = 0
    HeaderMask.BorderSizePixel = 0
    HeaderMask.ZIndex = 301
    RegisterTheme(HeaderMask, "BackgroundColor3", "Side")

    -- Speed Control (Left side of header)
    local BtnSpeed = Instance.new("TextButton", PopupHeader)
    UIHandlers.BtnSpeed = BtnSpeed -- Store reference for reset
    BtnSpeed.Text = "1x"
    BtnSpeed.Size = UDim2.new(0, 36, 0, 22)
    BtnSpeed.Position = UDim2.new(0, 8, 0.5, -11)
    BtnSpeed.BackgroundColor3 = C_ITEM
    BtnSpeed.TextColor3 = C_ACCENT
    BtnSpeed.Font = Enum.Font.GothamBold
    BtnSpeed.TextSize = 10
    BtnSpeed.ZIndex = 302
    Instance.new("UICorner", BtnSpeed).CornerRadius = UDim.new(0, 6)
    RegisterTheme(BtnSpeed, "BackgroundColor3", "Item")
    RegisterTheme(BtnSpeed, "TextColor3", "Accent")

    local PFileLbl = Instance.new("TextLabel", PopupHeader)
    PFileLbl.Text = L("no_file_selected")
    PFileLbl.Size = UDim2.new(1, -110, 1, 0)
    PFileLbl.Position = UDim2.new(0, 52, 0, 0)
    PFileLbl.BackgroundTransparency = 1
    PFileLbl.TextColor3 = C_TEXT
    PFileLbl.Font = Enum.Font.GothamBold
    PFileLbl.TextSize = 12
    PFileLbl.TextXAlignment = Enum.TextXAlignment.Center
    PFileLbl.TextTruncate = Enum.TextTruncate.AtEnd
    PFileLbl.ZIndex = 302
    RegisterTheme(PFileLbl, "TextColor3", "Text")

    -- Close Button (Right side of header)
    local PopupClose = Instance.new("TextButton", PopupHeader)
    PopupClose.Text = "X"
    PopupClose.Size = UDim2.new(0, 26, 0, 26)
    PopupClose.Position = UDim2.new(1, -32, 0.5, -13)
    PopupClose.BackgroundColor3 = C_RED
    PopupClose.BackgroundTransparency = 0.85
    PopupClose.TextColor3 = C_RED
    PopupClose.Font = Enum.Font.GothamBold
    PopupClose.TextSize = 14
    PopupClose.ZIndex = 302
    Instance.new("UICorner", PopupClose).CornerRadius = UDim.new(0, 6)

    -- File List Scroll (Positioned below HeaderArea, fills remaining space)
    local MapListScroll = Instance.new("ScrollingFrame", MapContainer)
    MapListScroll.Size = UDim2.new(1, 0, 1, -130)    -- Full height minus HeaderArea (125px + 5px gap)
    MapListScroll.Position = UDim2.new(0, 0, 0, 130) -- Position below HeaderArea
    MapListScroll.BackgroundTransparency = 1
    MapListScroll.BorderSizePixel = 0
    MapListScroll.ScrollBarThickness = 4
    MapListScroll.ScrollBarImageColor3 = C_ACCENT
    MapListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    MapListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    MapListScroll.ClipsDescendants = true -- Pastikan konten tidak keluar
    RegisterTheme(MapListScroll, "ScrollBarImageColor3", "Accent")

    local FileListContainer = Instance.new("Frame", MapListScroll)
    FileListContainer.Size = UDim2.new(0.96, 0, 0, 0)
    FileListContainer.Position = UDim2.new(0.02, 0, 0, 0)
    FileListContainer.BackgroundTransparency = 1

    local FileListLayout = Instance.new("UIListLayout", FileListContainer)
    FileListLayout.Padding = UDim.new(0, 4) -- Sedikit lebih besar untuk visual yang lebih baik
    FileListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Helper to update selection visuals (uses dynamic colors from theme)
    local function UpdateSelectionVisuals(skipImageLoad)
        local colors = _G.StarshipColors or CurrentColors
        for _, child in pairs(FileListContainer:GetChildren()) do
            if child:IsA("TextButton") then
                local fName = child:GetAttribute("FileName")
                local isEven = child:GetAttribute("IsEven")

                if fName == currentPlaybackFile then
                    -- Selected state
                    child.BackgroundColor3 = colors.ACCENT
                    child.TextColor3 = Color3.new(0, 0, 0)
                else
                    -- Non-selected: alternating colors
                    local baseColor = isEven and colors.ITEM or colors.MAIN
                    child.BackgroundColor3 = baseColor
                    child.TextColor3 = colors.TEXT
                end
            end
        end

        if currentPlaybackFile then
            PFileLbl.Text = string.gsub(currentPlaybackFile, ".json", "")
        end
    end

    PopupClose.MouseButton1Click:Connect(function()
        MapPlayerPopup.Visible = false
        StopPlayback()
        currentPlaybackFile = nil

        -- Reset semua toggle via UIHandlers (didefinisikan setelah toggle dibuat)
        if UIHandlers.ResetPlaybackToggles then
            UIHandlers.ResetPlaybackToggles()
        end

        UpdateSelectionVisuals()
    end)

    -- Speed Dropdown
    local SpeedDropdown = Instance.new("Frame", MapPlayerPopup)
    UIHandlers.SpeedDropdown = SpeedDropdown -- Store reference for reset
    SpeedDropdown.Name = "SpeedDropdown"
    SpeedDropdown.Size = UDim2.new(0, 50, 0, 130)
    SpeedDropdown.Position = UDim2.new(0, 8, 0, 40)
    SpeedDropdown.BackgroundColor3 = C_SIDE
    SpeedDropdown.Visible = false
    SpeedDropdown.ZIndex = 320
    Instance.new("UICorner", SpeedDropdown).CornerRadius = UDim.new(0, 8)
    local SpeedDropStroke = Instance.new("UIStroke", SpeedDropdown)
    SpeedDropStroke.Color = C_ACCENT
    SpeedDropStroke.Transparency = 0.7
    RegisterTheme(SpeedDropdown, "BackgroundColor3", "Side")
    RegisterTheme(SpeedDropStroke, "Color", "Accent")

    local SpeedList = Instance.new("UIListLayout", SpeedDropdown)
    SpeedList.SortOrder = Enum.SortOrder.LayoutOrder
    SpeedList.Padding = UDim.new(0, 2)
    Instance.new("UIPadding", SpeedDropdown).PaddingTop = UDim.new(0, 4)

    local speeds = { 0.25, 0.5, 1, 1.5, 2, 4 }
    for i, s in ipairs(speeds) do
        local b = Instance.new("TextButton", SpeedDropdown)
        b.Text = s .. "x"
        b.Size = UDim2.new(1, -8, 0, 18)
        b.BackgroundColor3 = C_ITEM
        b.BackgroundTransparency = 0.3
        b.TextColor3 = (s == 1) and C_ACCENT or C_TEXT
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.BorderSizePixel = 0
        b.LayoutOrder = i
        b.ZIndex = 321
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        RegisterTheme(b, "BackgroundColor3", "Item")

        b.MouseButton1Click:Connect(function()
            playbackSpeed = s
            BtnSpeed.Text = s .. "x"
            SpeedDropdown.Visible = false
            for _, btn in pairs(SpeedDropdown:GetChildren()) do
                if btn:IsA("TextButton") then
                    btn.TextColor3 = (btn.Text == s .. "x") and C_ACCENT or C_TEXT
                end
            end

            -- Set WalkSpeed based on playback speed
            local c = LocalPlayer.Character
            local hum = c and c:FindFirstChild("Humanoid")
            if hum then
                if s == 1.5 then
                    hum.WalkSpeed = 66
                elseif s == 2 then
                    hum.WalkSpeed = 91
                else
                    hum.WalkSpeed = 16 -- Default speed for other options
                end
            end
        end)
    end

    BtnSpeed.MouseButton1Click:Connect(function()
        SpeedDropdown.Visible = not SpeedDropdown.Visible
    end)

    -- Progress Section (Slider + Time)
    local ProgressSection = Instance.new("Frame", MapPlayerPopup)
    ProgressSection.Size = UDim2.new(1, -24, 0, 32)
    ProgressSection.Position = UDim2.new(0, 12, 0, 44)
    ProgressSection.BackgroundTransparency = 1
    ProgressSection.ZIndex = 301

    local PTimeLbl = Instance.new("TextLabel", ProgressSection)
    PTimeLbl.Text = "0.0s / 0.0s"
    PTimeLbl.Size = UDim2.new(1, 0, 0, 16)
    PTimeLbl.Position = UDim2.new(0, 0, 0, 0)
    PTimeLbl.BackgroundTransparency = 1
    PTimeLbl.TextColor3 = C_TEXT_DIM
    PTimeLbl.Font = Enum.Font.Code
    PTimeLbl.TextSize = 11
    PTimeLbl.TextXAlignment = Enum.TextXAlignment.Center
    PTimeLbl.ZIndex = 302
    RegisterTheme(PTimeLbl, "TextColor3", "TextDim")

    local PSliderBg = Instance.new("TextButton", ProgressSection)
    PSliderBg.Text = ""
    PSliderBg.Size = UDim2.new(1, 0, 0, 10)
    PSliderBg.Position = UDim2.new(0, 0, 0, 20)
    PSliderBg.BackgroundColor3 = C_ITEM
    PSliderBg.AutoButtonColor = false
    PSliderBg.ZIndex = 302
    Instance.new("UICorner", PSliderBg).CornerRadius = UDim.new(1, 0)
    RegisterTheme(PSliderBg, "BackgroundColor3", "Item")

    local PSliderFill = Instance.new("Frame", PSliderBg)
    PSliderFill.Size = UDim2.new(0, 0, 1, 0)
    PSliderFill.BackgroundColor3 = C_ACCENT
    PSliderFill.ZIndex = 303
    Instance.new("UICorner", PSliderFill).CornerRadius = UDim.new(1, 0)
    RegisterTheme(PSliderFill, "BackgroundColor3", "Accent")

    -- Slider Knob
    local PSliderKnob = Instance.new("Frame", PSliderBg)
    PSliderKnob.Size = UDim2.new(0, 16, 0, 16)
    PSliderKnob.Position = UDim2.new(0, -8, 0.5, -8)
    PSliderKnob.BackgroundColor3 = C_ACCENT
    PSliderKnob.ZIndex = 304
    Instance.new("UICorner", PSliderKnob).CornerRadius = UDim.new(1, 0)
    local KnobStroke = Instance.new("UIStroke", PSliderKnob)
    KnobStroke.Color = C_MAIN
    KnobStroke.Thickness = 2
    RegisterTheme(PSliderKnob, "BackgroundColor3", "Accent")
    RegisterTheme(KnobStroke, "Color", "Main")

    -- Main Controls Row (Play/Stop - Large Buttons)
    local ControlsRow = Instance.new("Frame", MapPlayerPopup)
    ControlsRow.Size = UDim2.new(1, -24, 0, 44)
    ControlsRow.Position = UDim2.new(0, 12, 0, 84)
    ControlsRow.BackgroundTransparency = 1
    ControlsRow.ZIndex = 301

    -- Play Button (Large, Primary - Solid Green Background)
    local PBtnPlay = Instance.new("TextButton", ControlsRow)
    PBtnPlay.Text = "▶  PLAY"
    PBtnPlay.Size = UDim2.new(0.56, 0, 1, 0)
    PBtnPlay.Position = UDim2.new(0, 0, 0, 0)
    PBtnPlay.BackgroundColor3 = C_GREEN
    PBtnPlay.BackgroundTransparency = 0
    PBtnPlay.TextColor3 = Color3.fromRGB(0, 0, 0)
    PBtnPlay.Font = Enum.Font.GothamBlack
    PBtnPlay.TextSize = 15
    PBtnPlay.ZIndex = 302
    Instance.new("UICorner", PBtnPlay).CornerRadius = UDim.new(0, 10)
    local PlayStroke = Instance.new("UIStroke", PBtnPlay)
    PlayStroke.Color = C_GREEN
    PlayStroke.Transparency = 0.2
    PlayStroke.Thickness = 2

    -- Stop Button (Secondary - Outlined Style)
    local PBtnStop = Instance.new("TextButton", ControlsRow)
    PBtnStop.Text = "■  STOP"
    PBtnStop.Size = UDim2.new(0.40, 0, 1, 0)
    PBtnStop.Position = UDim2.new(0.60, 0, 0, 0)
    PBtnStop.BackgroundColor3 = C_ITEM
    PBtnStop.BackgroundTransparency = 0
    PBtnStop.TextColor3 = C_RED
    PBtnStop.Font = Enum.Font.GothamBold
    PBtnStop.TextSize = 12
    PBtnStop.ZIndex = 302
    Instance.new("UICorner", PBtnStop).CornerRadius = UDim.new(0, 10)
    local StopStroke = Instance.new("UIStroke", PBtnStop)
    StopStroke.Color = C_RED
    StopStroke.Transparency = 0.4
    StopStroke.Thickness = 1.5
    RegisterTheme(PBtnStop, "BackgroundColor3", "Item")

    -- Store references for theme updates
    local PlayBtnRefs = { btn = PBtnPlay, stroke = PlayStroke }
    local StopBtnRefs = { btn = PBtnStop, stroke = StopStroke }

    -- Toggles Row (Compact Pills - 2 rows of 3)
    local ToggleButtons = {}

    -- Declare these variables early so ResetPlaybackToggles can access them
    local godLoop = nil
    local isFreestyle = false
    local freestyleLoop = nil
    local function UpdateToggleVisual(id, active, isEffect)
        local toggle = ToggleButtons[id]
        if toggle then
            toggle.active = active
            local activeColor = isEffect and C_YELLOW or C_ACCENT
            toggle.btn.TextColor3 = active and activeColor or C_TEXT_DIM
            toggle.stroke.Color = active and activeColor or C_TEXT_DIM
            toggle.stroke.Transparency = active and 0.5 or 0.8
        end
    end

    do
        -- Row 1: LOOP, REV, MOON
        local Row1 = Instance.new("Frame", MapPlayerPopup)
        Row1.Size = UDim2.new(1, -24, 0, 28)
        Row1.Position = UDim2.new(0, 12, 0, 138)
        Row1.BackgroundTransparency = 1
        Row1.ZIndex = 301

        local Grid1 = Instance.new("UIGridLayout", Row1)
        Grid1.CellSize = UDim2.new(0.32, 0, 1, 0)
        Grid1.CellPadding = UDim2.new(0.02, 0, 0, 0)
        Grid1.HorizontalAlignment = Enum.HorizontalAlignment.Center

        -- Row 2: GOD, SPIN, ZOOM
        local Row2 = Instance.new("Frame", MapPlayerPopup)
        Row2.Size = UDim2.new(1, -24, 0, 28)
        Row2.Position = UDim2.new(0, 12, 0, 172)
        Row2.BackgroundTransparency = 1
        Row2.ZIndex = 301

        local Grid2 = Instance.new("UIGridLayout", Row2)
        Grid2.CellSize = UDim2.new(0.32, 0, 1, 0)
        Grid2.CellPadding = UDim2.new(0.02, 0, 0, 0)
        Grid2.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local function CreateToggle(parent, text, icon, id)
            local b = Instance.new("TextButton", parent)
            b.Text = icon .. " " .. text
            b.BackgroundColor3 = C_ITEM
            b.BackgroundTransparency = 0.2
            b.TextColor3 = C_TEXT_DIM
            b.Font = Enum.Font.GothamBold
            b.TextSize = 10
            b.ZIndex = 302
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
            local s = Instance.new("UIStroke", b)
            s.Color = C_TEXT_DIM
            s.Transparency = 0.7
            s.Thickness = 1
            RegisterTheme(b, "BackgroundColor3", "Item")
            ToggleButtons[id] = { btn = b, stroke = s, active = false }
            return b
        end

        -- Row 1 buttons
        BtnLoop = CreateToggle(Row1, "LOOP", "🔁", "loop")
        BtnReverse = CreateToggle(Row1, "REV", "⏪", "reverse")
        BtnMoonwalk = CreateToggle(Row1, "MOON", "🌙", "moonwalk")

        -- Row 2 buttons
        BtnGod = CreateToggle(Row2, "GOD", "⚡", "god")
        local BtnPath = CreateToggle(Row2, "PATH", "📍", "path") -- Path visualization toggle
        local BtnZoom = CreateToggle(Row2, "ZOOM", "🎯", "zoom")

        -- Path toggle click handler
        BtnPath.MouseButton1Click:Connect(function()
            isPathEnabled = not isPathEnabled
            UpdateToggleVisual("path", isPathEnabled, false)
            if isPathEnabled then
                if isPlaying and currentFrameData then
                    GeneratePlaybackPath(currentFrameData)
                end
                ShowToast("Path Visualization", "Path enabled", "success", 2)
            else
                ClearPath()
                ShowToast("Path Visualization", "Path disabled", "info", 2)
            end
        end)

        -- Zoom Punch click handler
        BtnZoom.MouseButton1Click:Connect(function()
            isZoomPunch = not isZoomPunch
            UpdateToggleVisual("zoom", isZoomPunch, true)
            if isZoomPunch then
                ShowToast("Zoom Punch", "FOV punch on jumps/landings", "info", 2)
            end
        end)

        -- Row 3: RESPAWN (single toggle, centered)
        local Row3 = Instance.new("Frame", MapPlayerPopup)
        Row3.Size = UDim2.new(1, -24, 0, 28)
        Row3.Position = UDim2.new(0, 12, 0, 206)
        Row3.BackgroundTransparency = 1
        Row3.ZIndex = 301

        local Grid3 = Instance.new("UIGridLayout", Row3)
        Grid3.CellSize = UDim2.new(0.32, 0, 1, 0) -- 3 buttons per row
        Grid3.CellPadding = UDim2.new(0.02, 0, 0, 0)
        Grid3.HorizontalAlignment = Enum.HorizontalAlignment.Center

        BtnSpinbot = CreateToggle(Row3, "SPIN", "💫", "spin") -- SPIN restored
        BtnRespawn = CreateToggle(Row3, "RESPAWN", "💀", "respawn")

        -- Respawn click handler
        BtnRespawn.MouseButton1Click:Connect(function()
            isRespawnOnEnd = not isRespawnOnEnd
            UpdateToggleVisual("respawn", isRespawnOnEnd)
            if isRespawnOnEnd then
                ShowToast("Respawn On End", "Character will respawn when playback ends", "info", 2)
            end
        end)
    end

    -- Status Indicator Row
    local StatusRow = Instance.new("Frame", MapPlayerPopup)
    StatusRow.Size = UDim2.new(1, -24, 0, 18)
    StatusRow.Position = UDim2.new(0, 12, 0, 238)
    StatusRow.BackgroundTransparency = 1
    StatusRow.ZIndex = 301

    local StatusLbl = Instance.new("TextLabel", StatusRow)
    StatusLbl.Text = L("ready")
    RegisterLocalizedUI(StatusLbl, "ready")
    StatusLbl.Size = UDim2.new(1, 0, 1, 0)
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.TextColor3 = C_TEXT_DIM
    StatusLbl.Font = Enum.Font.Gotham
    StatusLbl.TextSize = 10
    StatusLbl.TextXAlignment = Enum.TextXAlignment.Center
    StatusLbl.ZIndex = 302
    RegisterTheme(StatusLbl, "TextColor3", "TextDim")

    -- Toggle Logic
    BtnMoonwalk.MouseButton1Click:Connect(function()
        isMoonwalk = not isMoonwalk
        UpdateToggleVisual("moonwalk", isMoonwalk)
    end)

    BtnLoop.MouseButton1Click:Connect(function()
        isLooping = not isLooping
        UpdateToggleVisual("loop", isLooping)
    end)

    BtnReverse.MouseButton1Click:Connect(function()
        isReversing = not isReversing
        UpdateToggleVisual("reverse", isReversing)
        StatusLbl.Text = isReversing and "⏪ Reverse Mode" or "Ready"
        StatusLbl.TextColor3 = isReversing and C_YELLOW or C_TEXT_DIM
    end)

    BtnGod.MouseButton1Click:Connect(function()
        isGodMode = not isGodMode
        UpdateToggleVisual("god", isGodMode)
        if isGodMode then
            godLoop = RunService.Heartbeat:Connect(function()
                local c = LocalPlayer.Character
                local h = c and c:FindFirstChild("Humanoid")
                if h then
                    h.MaxHealth = math.huge
                    h.Health = math.huge
                end
            end)
            table.insert(Connections, godLoop)
        else
            if godLoop then
                godLoop:Disconnect()
                godLoop = nil
            end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("Humanoid")
            if h then
                h.MaxHealth = 100
                h.Health = 100
            end
        end
    end)

    -- Freestyle Logic (Smart Spin) - RESTORED
    BtnSpinbot.MouseButton1Click:Connect(function()
        isFreestyle = not isFreestyle
        UpdateToggleVisual("spin", isFreestyle)

        if isFreestyle then
            freestyleLoop = RunService.RenderStepped:Connect(function(dt)
                if not isPlaying then
                    return
                end -- Only spin when playing

                local c = LocalPlayer.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                local h = c and c:FindFirstChild("Humanoid")

                if r and h then
                    local state = h:GetState()
                    local isAir = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping

                    -- 1. Jump Spin (The "Velora" Style)
                    if isAir then
                        h.AutoRotate = false -- Disable default rotation to prevent fighting

                        -- Constant Speed Spin
                        local spinSpeed = 12 -- Rad/s (Faster: ~2 revs/sec)
                        local deltaSpin = dt * spinSpeed
                        local spinRot = CFrame.Angles(0, deltaSpin, 0)

                        -- Camera Sync: Orbit Logic
                        local cam = workspace.CurrentCamera
                        if cam then
                            -- Capture relation before spin
                            local relCam = r.CFrame:ToObjectSpace(cam.CFrame)

                            -- Apply Spin to Character
                            r.CFrame = r.CFrame * spinRot

                            -- Apply Spin to Camera (Maintain relative position)
                            cam.CFrame = r.CFrame:ToWorldSpace(relCam)

                            -- Cinematic Effects
                            -- 1. Dynamic FOV
                            local targetFOV = 85
                            cam.FieldOfView = cam.FieldOfView + (targetFOV - cam.FieldOfView) * 0.1

                            -- 2. Subtle Roll
                            local rollAmount = math.rad(math.sin(os.clock() * 4) * 3) -- Slightly more active roll
                            cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, rollAmount)
                        else
                            -- Just spin character if no camera
                            r.CFrame = r.CFrame * spinRot
                        end
                    else
                        h.AutoRotate = true -- Re-enable rotation

                        -- Reset Camera Effect when on ground
                        local cam = workspace.CurrentCamera
                        if cam then
                            cam.FieldOfView = cam.FieldOfView + (70 - cam.FieldOfView) * 0.1
                        end
                    end
                end
            end)
            table.insert(Connections, freestyleLoop)
        else
            if freestyleLoop then
                freestyleLoop:Disconnect()
                freestyleLoop = nil
            end
            -- Ensure AutoRotate is reset if toggled off
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("Humanoid")
            if h then
                h.AutoRotate = true
            end
        end
    end)

    -- Fungsi Reset Semua Toggle (dipanggil saat popup ditutup)
    UIHandlers.ResetPlaybackToggles = function()
        -- Reset state variables
        isLooping = false
        isReversing = false
        isMoonwalk = false
        isRespawnOnEnd = false
        isZoomPunch = false
        isPathEnabled = false
        ClearPath()

        -- Reset toggle visuals
        UpdateToggleVisual("loop", false)
        UpdateToggleVisual("reverse", false)
        UpdateToggleVisual("moonwalk", false)
        UpdateToggleVisual("respawn", false)
        UpdateToggleVisual("zoom", false)
        UpdateToggleVisual("path", false)
        UpdateToggleVisual("spin", false)
        UpdateToggleVisual("god", false)

        -- Reset God Mode
        if isGodMode then
            isGodMode = false
            if godLoop then
                godLoop:Disconnect()
                godLoop = nil
            end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("Humanoid")
            if h then
                h.MaxHealth = 100
                h.Health = 100
            end
        end

        -- Reset Freestyle/Spin
        if isFreestyle then
            isFreestyle = false
            if freestyleLoop then
                freestyleLoop:Disconnect()
                freestyleLoop = nil
            end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("Humanoid")
            if h then
                h.AutoRotate = true
            end
        end

        -- Reset speed ke 1x
        playbackSpeed = 1
        if UIHandlers.BtnSpeed then
            UIHandlers.BtnSpeed.Text = "1x"
        end
    end

    -- File List Scroll (Full Height now)

    local function CreateFileCard(fileName, index)
        local colors = _G.StarshipColors or CurrentColors

        -- Alternating row colors (ganjil/genap)
        local isEven = (index % 2 == 0)
        local baseColor = isEven and colors.ITEM or colors.MAIN
        local hoverColor = colors.ACCENT

        local FileCard = Instance.new("TextButton", FileListContainer)
        FileCard.Text = "  📄 " .. string.gsub(fileName, ".json", "")
        FileCard.Size = UDim2.new(1, 0, 0, 32) -- Sedikit lebih tinggi
        FileCard.BackgroundColor3 = baseColor
        FileCard.TextColor3 = colors.TEXT
        FileCard.Font = Enum.Font.GothamMedium
        FileCard.TextSize = 11
        FileCard.TextXAlignment = Enum.TextXAlignment.Left
        FileCard.LayoutOrder = index
        FileCard.AutoButtonColor = false -- Disable default, kita handle sendiri
        FileCard:SetAttribute("FileName", fileName)
        FileCard:SetAttribute("IsEven", isEven)
        Instance.new("UICorner", FileCard).CornerRadius = UDim.new(0, 6)

        -- Hover effect
        FileCard.MouseEnter:Connect(function()
            if currentPlaybackFile ~= fileName then
                FileCard.BackgroundColor3 = Color3.new(
                    math.min(baseColor.R + 0.08, 1),
                    math.min(baseColor.G + 0.08, 1),
                    math.min(baseColor.B + 0.08, 1)
                )
            end
        end)

        FileCard.MouseLeave:Connect(function()
            if currentPlaybackFile ~= fileName then
                FileCard.BackgroundColor3 = baseColor
            end
        end)

        -- Theme registration untuk non-selected state
        if currentPlaybackFile ~= fileName then
            RegisterTheme(FileCard, "TextColor3", "Text")
        end

        -- Rename Button
        local BtnRename = Instance.new("TextButton", FileCard)
        BtnRename.Text = "✏️"
        BtnRename.Size = UDim2.new(0, 24, 0, 24)
        BtnRename.Position = UDim2.new(1, -52, 0.5, -12)
        BtnRename.BackgroundColor3 = colors.MAIN
        BtnRename.TextColor3 = colors.YELLOW or Color3.fromRGB(255, 200, 0)
        BtnRename.Font = Enum.Font.GothamBold
        BtnRename.TextSize = 12
        BtnRename.AutoButtonColor = true
        Instance.new("UICorner", BtnRename).CornerRadius = UDim.new(0, 6)
        RegisterTheme(BtnRename, "BackgroundColor3", "Main")

        BtnRename.MouseButton1Click:Connect(function()
            if ShowConfirm then
                ShowConfirm("RENAME FILE", "Enter new name for: " .. fileName:gsub(".json", ""), function(newName)
                    UIHandlers.RenameMergerFile(fileName, newName, function()
                        local newFileName = newName .. ".json"

                        -- Update Global State
                        if currentPlaybackFile == fileName then
                            currentPlaybackFile = newFileName
                            PFileLbl.Text = currentPlaybackFile:gsub(".json", "")
                        end

                        -- Optimistic UI Update
                        FileCard.Text = "  " .. newName
                        FileCard:SetAttribute("FileName", newFileName)
                        fileName = newFileName -- Update upvalue for future clicks
                    end)
                end, true)
            end
        end)

        -- Delete Button
        local BtnDelete = Instance.new("TextButton", FileCard)
        BtnDelete.Text = "🗑️"
        BtnDelete.Size = UDim2.new(0, 24, 0, 24)
        BtnDelete.Position = UDim2.new(1, -26, 0.5, -12)
        BtnDelete.BackgroundColor3 = colors.MAIN
        BtnDelete.TextColor3 = colors.RED or Color3.fromRGB(255, 80, 80)
        BtnDelete.Font = Enum.Font.GothamBold
        BtnDelete.TextSize = 12
        BtnDelete.AutoButtonColor = true
        Instance.new("UICorner", BtnDelete).CornerRadius = UDim.new(0, 6)
        RegisterTheme(BtnDelete, "BackgroundColor3", "Main")

        BtnDelete.MouseButton1Click:Connect(function()
            if ShowConfirm then
                ShowConfirm(
                    "DELETE FILE",
                    "Are you sure you want to delete: " .. fileName:gsub(".json", "") .. "?",
                    function()
                        UIHandlers.DeleteMergerFile(fileName, function()
                            if currentPlaybackFile == fileName then
                                StopPlayback()
                                currentPlaybackFile = nil
                                MapPlayerPopup.Visible = false
                            end
                            -- Optimistic UI Update
                            FileCard:Destroy()

                            -- Update count label if possible (optional, but good for polish)
                            local count = 0
                            for _, c in pairs(FileListContainer:GetChildren()) do
                                if c:IsA("TextButton") then
                                    count = count + 1
                                end
                            end
                            HeaderTitle.Text = string.format("LIST MAP (%d)", count)
                        end)
                    end
                )
            end
        end)

        FileCard.MouseButton1Click:Connect(function()
            if currentPlaybackFile == fileName then
                -- Deselect Logic
                currentPlaybackFile = nil
                StopPlayback()
                MapPlayerPopup.Visible = false
                UpdateSelectionVisuals()
            else
                -- Select Logic - Immediate Visual Feedback
                local originalText = FileCard.Text
                local originalColor = FileCard.BackgroundColor3
                FileCard.Text = "  ⏳ LOADING..."
                FileCard.BackgroundColor3 = C_ACCENT

                ShowLoadingModal(true, "LOADING DATA...")

                -- Offload heavy work to a separate thread
                task.spawn(function()
                    -- Yield BEFORE heavy operation to let UI update
                    task.wait()

                    local success, data = pcall(function()
                        return HttpService:JSONDecode(readfile(MERGER_FOLDER .. "/" .. fileName))
                    end)

                    -- Yield AFTER decode to prevent stutter
                    task.wait()

                    if success and data then
                        ShowLoadingModal(false)
                        task.wait() -- Ensure loading modal is fully hidden before showing popup

                        -- DISTANCE VALIDATION CHECK (to nearest path point)
                        local frames = data.Frames or data
                        local needsConfirmation = false
                        local distanceToNearest = 0

                        if frames and #frames > 0 then
                            local c = LocalPlayer.Character
                            local r = c and c:FindFirstChild("HumanoidRootPart")
                            if r then
                                distanceToNearest = GetDistanceToNearestPathPoint(frames, r.Position)
                                if distanceToNearest > MAP_DISTANCE_THRESHOLD then
                                    needsConfirmation = true
                                end
                            end
                        end

                        -- Function to proceed with selection
                        local function proceedWithSelection()
                            currentPlaybackFile = fileName
                            currentPlaybackSource = "Merger"

                            -- Restore card text before updating visuals
                            FileCard.Text = originalText

                            UpdateSelectionVisuals(true) -- Skip image load (will set selected color)

                            MapPlayerPopup.Visible = true
                            PBtnPlay.Text = L("play")
                            PBtnPlay.TextColor3 = C_GREEN

                            -- Preload Data for Playback
                            if frames and #frames > 0 then
                                currentTotalDuration = frames[#frames].t
                                PTimeLbl.Text = string.format("0.0s / %.1fs", currentTotalDuration)

                                -- Pre-set currentFrameData so PlayRecording doesn't need to reload
                                currentFrameData = frames
                            else
                                PTimeLbl.Text = "0.0s / 0.0s"
                                currentFrameData = nil
                            end
                        end

                        -- Show confirmation if distance is too far
                        if needsConfirmation and ShowConfirm then
                            -- Restore card appearance while waiting for confirmation
                            FileCard.Text = originalText
                            FileCard.BackgroundColor3 = originalColor

                            ShowConfirm(
                                "DIFFERENT LOCATION DETECTED",
                                string.format(
                                    "Nearest path point is %.0f studs away!\n\nThis recording might be from a different location/map.\n\nContinue anyway?",
                                    distanceToNearest
                                ),
                                function()
                                    -- User confirmed, proceed with selection
                                    proceedWithSelection()
                                end
                            )
                        else
                            -- No confirmation needed, proceed directly
                            proceedWithSelection()
                        end
                    else
                        -- Restore card appearance on error
                        FileCard.Text = originalText
                        FileCard.BackgroundColor3 = originalColor
                        ShowLoadingModal(false)
                    end
                end)
            end
        end)
        return FileCard
    end

    local function RefreshMapList()
        for _, child in pairs(FileListContainer:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end

        if not isfolder(MERGER_FOLDER) then
            makefolder(MERGER_FOLDER)
        end

        -- Get files dan filter hanya .json
        local allFiles = listfiles(MERGER_FOLDER)
        local jsonFiles = {}
        for i = 1, #allFiles do
            local f = allFiles[i]
            if string.sub(f, -5) == ".json" then
                table.insert(jsonFiles, f)
            end
        end

        -- ========== INLINE NATURAL SORT ==========
        local function padZero(num)
            local s = tostring(num)
            while string.len(s) < 10 do
                s = "0" .. s
            end
            return s
        end

        local sortable = {}
        for i = 1, #jsonFiles do
            local fullPath = jsonFiles[i]
            local fileName = string.match(fullPath, "[^/\\]+$") or fullPath
            local baseName = string.gsub(fileName, "%.json$", "")
            local numPart = string.match(baseName, "(%d+)$")
            local sortKey

            if numPart and string.len(numPart) > 0 then
                local prefixLen = string.len(baseName) - string.len(numPart)
                local prefix = string.sub(baseName, 1, prefixLen)
                sortKey = "1" .. string.lower(prefix) .. padZero(tonumber(numPart) or 0)
            else
                sortKey = "0" .. string.lower(baseName) .. padZero(0)
            end

            table.insert(sortable, { path = fullPath, key = sortKey })
        end

        table.sort(sortable, function(a, b)
            return a.key < b.key
        end)

        local files = {}
        for i = 1, #sortable do
            files[i] = sortable[i].path
        end
        -- ========== END SORT ==========

        local mapCount = 0
        local filter = string.lower(SearchBar.Text)
        filter = string.gsub(filter, "^%s*(.-)%s*$", "%1") -- Trim whitespace

        if #files == 0 then
            -- Better Empty State
            local EmptyContainer = Instance.new("Frame", FileListContainer)
            EmptyContainer.Size = UDim2.new(1, 0, 0, 120)
            EmptyContainer.BackgroundTransparency = 1

            local EmptyIcon = Instance.new("TextLabel", EmptyContainer)
            EmptyIcon.Text = "📂"
            EmptyIcon.Size = UDim2.new(1, 0, 0, 40)
            EmptyIcon.Position = UDim2.new(0, 0, 0, 10)
            EmptyIcon.BackgroundTransparency = 1
            EmptyIcon.TextColor3 = C_TEXT_DIM
            EmptyIcon.Font = Enum.Font.SourceSans
            EmptyIcon.TextSize = 36

            local EmptyTitle = Instance.new("TextLabel", EmptyContainer)
            EmptyTitle.Text = "No Maps Found"
            EmptyTitle.Size = UDim2.new(1, 0, 0, 20)
            EmptyTitle.Position = UDim2.new(0, 0, 0, 50)
            EmptyTitle.BackgroundTransparency = 1
            EmptyTitle.TextColor3 = C_TEXT
            EmptyTitle.Font = Enum.Font.GothamBold
            EmptyTitle.TextSize = 14
            RegisterTheme(EmptyTitle, "TextColor3", "Text")

            local EmptyHint = Instance.new("TextLabel", EmptyContainer)
            EmptyHint.Text = "Merge recordings in Merger tab\nor check your folder"
            EmptyHint.Size = UDim2.new(1, 0, 0, 35)
            EmptyHint.Position = UDim2.new(0, 0, 0, 72)
            EmptyHint.BackgroundTransparency = 1
            EmptyHint.TextColor3 = C_TEXT_DIM
            EmptyHint.Font = Enum.Font.Gotham
            EmptyHint.TextSize = 11
            EmptyHint.TextWrapped = true
            RegisterTheme(EmptyHint, "TextColor3", "TextDim")

            return
        end

        for index = 1, #files do
            local filePath = files[index]
            local fileName = string.match(filePath, "[^/\\]+$")

            -- Validasi file
            local isValid = true
            if not fileName or not string.match(fileName, "%.json$") then
                isValid = false
            elseif not isfile(filePath) then
                isValid = false
            elseif filter ~= "" and not string.find(string.lower(fileName), filter, 1, true) then
                isValid = false
            end

            if isValid then
                mapCount = mapCount + 1
                CreateFileCard(fileName, index)

                if mapCount % 5 == 0 then
                    task.wait()
                end -- Yield every 5 items to prevent lag
            end
        end

        HeaderTitle.Text = string.format("LIST MAP (%d)", mapCount)
        UpdateSelectionVisuals()
    end

    SearchBar:GetPropertyChangedSignal("Text"):Connect(RefreshMapList)

    SearchBar.Text = ""
    task.defer(RefreshMapList)

    -- Update Loop for Popup
    game:GetService("RunService").RenderStepped:Connect(function()
        if (isPlaying or isPlayPaused) and currentPlaybackSource == "Merger" then
            local pct = math.clamp(currentPlaybackTime / currentTotalDuration, 0, 1)
            PSliderFill.Size = UDim2.new(pct, 0, 1, 0)
            PSliderKnob.Position = UDim2.new(pct, -7, 0.5, -7)
            PTimeLbl.Text = string.format("%.1fs / %.1fs", currentPlaybackTime, currentTotalDuration)

            if isPlayPaused then
                PBtnPlay.Text = "▶  RESUME"
                PBtnPlay.BackgroundColor3 = C_GREEN
                PBtnPlay.BackgroundTransparency = 0
                PBtnPlay.TextColor3 = Color3.fromRGB(0, 0, 0)
                PlayStroke.Color = C_GREEN
                StatusLbl.Text = "⏸ Paused"
                StatusLbl.TextColor3 = C_YELLOW
            else
                PBtnPlay.Text = "⏸  PAUSE"
                PBtnPlay.BackgroundColor3 = C_YELLOW
                PBtnPlay.BackgroundTransparency = 0
                PBtnPlay.TextColor3 = Color3.fromRGB(0, 0, 0)
                PlayStroke.Color = C_YELLOW
                StatusLbl.Text = "▶ Playing..."
                StatusLbl.TextColor3 = C_GREEN
            end
        else
            PSliderFill.Size = UDim2.new(0, 0, 1, 0)
            PSliderKnob.Position = UDim2.new(0, -7, 0.5, -7)
            PBtnPlay.Text = "▶  PLAY"
            PBtnPlay.BackgroundColor3 = C_GREEN
            PBtnPlay.BackgroundTransparency = 0
            PBtnPlay.TextColor3 = Color3.fromRGB(0, 0, 0)
            PlayStroke.Color = C_GREEN
            StatusLbl.Text = "Ready"
            StatusLbl.TextColor3 = C_TEXT_DIM
        end
    end)

    -- Button Actions (Popup)
    PBtnPlay.MouseButton1Click:Connect(function()
        if isPlaying and currentPlaybackSource == "Merger" then
            PausePlayback()
        elseif currentPlaybackFile then
            -- DISTANCE VALIDATION BEFORE PLAY (check nearest path point)
            if currentFrameData and #currentFrameData > 0 then
                local c = LocalPlayer.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if r then
                    local dist = GetDistanceToNearestPathPoint(currentFrameData, r.Position)
                    if dist > MAP_DISTANCE_THRESHOLD then
                        -- Show confirmation before playing
                        if ShowConfirm then
                            ShowConfirm(
                                "DIFFERENT MAP DETECTED",
                                string.format(
                                    "Nearest path point is %.0f studs away!\n\nThis may be from a different game/map.\n\nContinue anyway?",
                                    dist
                                ),
                                function()
                                    -- User confirmed, play now
                                    if isfile(MERGER_FOLDER .. "/" .. currentPlaybackFile) then
                                        UIHandlers.PlayMergerRecording(currentPlaybackFile, false, true) -- skipDistanceCheck = true
                                    end
                                end
                            )
                            return -- Stop here, wait for user confirmation
                        end
                    end
                end
            end

            -- Only force reload if we are NOT paused (i.e. stopped) AND we don't have data
            -- If we have data (preloaded), we should NOT force reload even if stopped
            local shouldForce = false
            if not isPlayPaused and not currentFrameData then
                shouldForce = true
            end

            if isfile(MERGER_FOLDER .. "/" .. currentPlaybackFile) then
                UIHandlers.PlayMergerRecording(currentPlaybackFile, shouldForce)
            end
        end
    end)

    PBtnStop.MouseButton1Click:Connect(function()
        if currentPlaybackSource == "Merger" then
            -- Custom Stop Logic: Stop playback but KEEP file selected
            isPlaying = false
            isPlayPaused = false
            if Connections.Playback then
                Connections.Playback:Disconnect()
            end
            currentPlaybackTime = 0

            -- Reset Character and Path
            if ResetChar then
                ResetChar()
            end
            if ClearPath then
                ClearPath()
            end

            -- Force UI Update (Visuals)
            PBtnPlay.Text = L("play")
            PBtnPlay.TextColor3 = C_GREEN
            PSliderFill.Size = UDim2.new(0, 0, 1, 0)
            if currentTotalDuration then
                PTimeLbl.Text = string.format("0.0s / %.1fs", currentTotalDuration)
            end
        end
    end)

    -- Slider Dragging
    local draggingP = false
    PSliderBg.MouseButton1Down:Connect(function()
        draggingP = true
    end)
    game:GetService("UserInputService").InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingP = false
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(i)
        if
            draggingP
            and i.UserInputType == Enum.UserInputType.MouseMovement
            and (isPlaying or isPlayPaused)
            and currentPlaybackSource == "Merger"
        then
            local rx = i.Position.X - PSliderBg.AbsolutePosition.X
            local sc = math.clamp(rx / PSliderBg.AbsoluteSize.X, 0, 1)
            currentPlaybackTime = currentTotalDuration * sc
            if isPlayPaused then
                if isfile(MERGER_FOLDER .. "/" .. currentPlaybackFile) then
                    UIHandlers.PlayMergerRecording(currentPlaybackFile, false)
                end
                PausePlayback()
            end
        end
    end)

    RefreshMapList()
    BtnRefresh.MouseButton1Click:Connect(RefreshMapList)

    -- Auto-Refresh when Tab becomes visible
    PageListMap:GetPropertyChangedSignal("Visible"):Connect(function()
        if PageListMap.Visible then
            task.defer(RefreshMapList) -- Defer to ensure UI is ready
        end
    end)

    -- Monitor Modal State to Hide Selection
    local wasModalActive = false
    game:GetService("RunService").RenderStepped:Connect(function()
        if not PageListMap.Visible then
            return
        end

        local isModalActive = (ScreenGui:FindFirstChild("ConfirmationModal") ~= nil)
        if isModalActive ~= wasModalActive then
            wasModalActive = isModalActive
            UpdateSelectionVisuals()
        end
    end)
end

UIHandlers.SetupListMapUI()

-- --- EMOTES UI (Standalone Window) ---
function UIHandlers.SetupNametags()
    -- Configuration: Fetch VIP List from Pastebin
    -- Format JSON di Pastebin harus seperti ini:
    -- {
    --    "12345678": {"Rank": "STAR VIP", "Type": "VIP"},
    --    "87654321": {"Rank": "STAR OWNER", "Type": "Owner"}
    -- }

    local SpecialUsers = {
        [LocalPlayer.UserId] = { Rank = "STAR OWNER", Type = "Owner" }, -- Default Self
    }

    local PASTEBIN_URL = "https://pastebin.com/raw/yWZRVAt3" -- GANTI INI DENGAN LINK RAW PASTEBIN ANDA

    task.spawn(function()
        pcall(function()
            local response = game:HttpGet(PASTEBIN_URL)
            local data = game:GetService("HttpService"):JSONDecode(response)

            for userId, info in pairs(data) do
                SpecialUsers[tonumber(userId)] = info
            end
            -- VIP list loaded, tags will be applied when ToggleNametags(true) is called
            -- (after key system verification and main UI load)
        end)
    end)

    local function AddTag(char, data, player)
        if not char then
            return
        end
        local head = char:WaitForChild("Head", 10)
        if not head then
            return
        end

        if head:FindFirstChild("StarshipTag") then
            head.StarshipTag:Destroy()
        end

        -- BillboardGui (Elegant Size)
        local bg = Instance.new("BillboardGui", head)
        bg.Name = "StarshipTag"
        bg.Adornee = head
        bg.Size = UDim2.new(0, 115, 0, 32)
        bg.StudsOffset = Vector3.new(0, 2.3, 0)
        bg.AlwaysOnTop = true

        -- Main Container (Glassmorphism)
        local container = Instance.new("Frame", bg)
        container.Size = UDim2.new(1, 0, 1, 0)
        container.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
        container.BackgroundTransparency = 0.2
        container.BorderSizePixel = 0
        container.ClipsDescendants = true -- Clip snow
        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)

        -- Snow Effect
        task.spawn(function()
            while bg and bg.Parent do
                if math.random() > 0.6 then -- Spawn rate
                    local flake = Instance.new("Frame", container)
                    flake.BackgroundColor3 = Color3.new(1, 1, 1)
                    flake.BorderSizePixel = 0
                    flake.Size = UDim2.new(0, math.random(2, 4), 0, math.random(2, 4))
                    flake.Position = UDim2.new(math.random(), 0, -0.2, 0)
                    flake.BackgroundTransparency = math.random(0.4, 0.8)
                    flake.ZIndex = 1
                    Instance.new("UICorner", flake).CornerRadius = UDim.new(1, 0)

                    local duration = math.random(20, 40) / 10
                    local sway = (math.random(-20, 20) / 100)
                    local targetPos = UDim2.new(flake.Position.X.Scale + sway, 0, 1.2, 0)

                    local t = TweenService:Create(
                        flake,
                        TweenInfo.new(duration, Enum.EasingStyle.Linear),
                        { Position = targetPos }
                    )
                    t:Play()
                    t.Completed:Connect(function()
                        flake:Destroy()
                    end)
                end
                task.wait(0.1)
            end
        end)

        -- Rainbow Border (Soft Glow)
        local stroke = Instance.new("UIStroke", container)
        stroke.Thickness = 2.5
        stroke.Transparency = 0
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = Color3.new(1, 1, 1) -- Default white base

        local strokeGrad = Instance.new("UIGradient", stroke)
        strokeGrad.Rotation = 0
        -- Initial Color (Will be animated)
        strokeGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
        })

        -- Custom 'S' Icon Container
        local iconFrame = Instance.new("Frame", container)
        iconFrame.Size = UDim2.new(0, 22, 0, 22)
        iconFrame.Position = UDim2.new(0, 5, 0.5, -11)
        iconFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        iconFrame.BorderSizePixel = 0
        iconFrame.ZIndex = 2
        Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(0, 6)

        local iconImage = Instance.new("ImageLabel", iconFrame)
        iconImage.Name = "Icon"
        iconImage.Size = UDim2.new(1, -4, 1, -4)
        iconImage.Position = UDim2.new(0, 2, 0, 2)
        iconImage.BackgroundTransparency = 1
        iconImage.Image = "https://www.roblox.com/asset/?id=91946746369709"
        iconImage.ScaleType = Enum.ScaleType.Fit
        iconImage.ZIndex = 3

        local iconStroke = Instance.new("UIStroke", iconFrame)
        iconStroke.Thickness = 1
        iconStroke.Color = Color3.fromRGB(60, 60, 80)

        -- Rank Text
        local rank = Instance.new("TextLabel", container)
        rank.Name = "Rank"
        rank.Text = data.Rank
        rank.Size = UDim2.new(1, -35, 0.5, 0)
        rank.Position = UDim2.new(0, 33, 0, 2)
        rank.BackgroundTransparency = 1
        rank.TextColor3 = Color3.new(1, 1, 1)
        rank.Font = Enum.Font.GothamBlack
        rank.TextSize = 10
        rank.TextXAlignment = Enum.TextXAlignment.Left
        rank.ZIndex = 2

        -- Username Text (Nickname)
        local name = Instance.new("TextLabel", container)
        name.Name = "Name"
        name.Text = player.DisplayName
        name.Size = UDim2.new(1, -35, 0.4, 0)
        name.Position = UDim2.new(0, 33, 0.5, 0)
        name.BackgroundTransparency = 1
        name.TextColor3 = Color3.fromRGB(180, 180, 180)
        name.Font = Enum.Font.GothamMedium
        name.TextSize = 9
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.ZIndex = 2

        -- Store reference for spoof name update (only for local player)
        if player == LocalPlayer then
            UIHandlers.LocalPlayerNameLabel = name
        end

        -- Animation Loop
        task.spawn(function()
            local t = 0
            while bg and bg.Parent do
                t = t + 0.02
                local hue = (t * 0.1) % 1

                local color1, color2
                if data.Type == "Owner" then
                    -- Full Rainbow
                    color1 = Color3.fromHSV(hue, 0.8, 1)
                    color2 = Color3.fromHSV((hue + 0.5) % 1, 0.8, 1)
                    rank.TextColor3 = Color3.fromHSV(hue, 0.7, 1)
                elseif data.Type == "VIP" then
                    -- Gold-Red Gradient
                    local wave = (math.sin(t * 2) + 1) / 2                                     -- 0 to 1
                    color1 = Color3.fromRGB(255, 215, 0):Lerp(Color3.fromRGB(255, 0, 0), wave) -- Gold to Red
                    color2 = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(255, 215, 0), wave) -- Red to Gold
                    rank.TextColor3 = color1
                end

                -- Animate Border Rotation & Color
                strokeGrad.Rotation = t * 45

                -- Distance Check
                local cam = workspace.CurrentCamera
                if cam and head then
                    local dist = (cam.CFrame.Position - head.Position).Magnitude
                    bg.Enabled = dist < 50
                end
                strokeGrad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, color1),
                    ColorSequenceKeypoint.new(1, color2),
                })
                task.wait(0.03)
            end
        end)

        -- Typing Animation Thread
        task.spawn(function()
            local originalText = data.Rank
            while bg and bg.Parent do
                for i = 1, #originalText do
                    rank.Text = string.sub(originalText, 1, i) .. "|"
                    task.wait(0.1)
                end
                rank.Text = originalText
                task.wait(3)
                for k = 1, 3 do
                    rank.Text = originalText .. "|"
                    task.wait(0.5)
                    rank.Text = originalText
                    task.wait(0.5)
                end
                for i = #originalText, 1, -1 do
                    rank.Text = string.sub(originalText, 1, i) .. "|"
                    task.wait(0.05)
                end
                task.wait(0.5)
            end
        end)
    end

    -- Toggle System
    local NametagsEnabled = false -- Default OFF until Key Access Granted

    local function ClearTags()
        for _, p in pairs(game:GetService("Players"):GetPlayers()) do
            if p.Character and p.Character:FindFirstChild("Head") then
                local tag = p.Character.Head:FindFirstChild("StarshipTag")
                if tag then
                    tag:Destroy()
                end
            end
        end
    end

    -- ========== FIREBASE ACTIVE USER SYSTEM ==========
    local FIREBASE_URL = "https://starship-nametags-default-rtdb.asia-southeast1.firebasedatabase.app"
    local ActiveScriptUsers = {}
    local HEARTBEAT_INTERVAL = 30
    local TIMEOUT_DURATION = 60
    local heartbeatLoop = nil
    local checkLoop = nil

    local function ClearTagForPlayer(player)
        if player.Character and player.Character:FindFirstChild("Head") then
            local tag = player.Character.Head:FindFirstChild("StarshipTag")
            if tag then
                tag:Destroy()
            end
        end
    end

    local function ApplyTagForPlayer(player)
        if not NametagsEnabled then
            return
        end
        if not ActiveScriptUsers[player.UserId] then
            return
        end
        if not SpecialUsers[player.UserId] then
            return
        end
        if player.Character then
            AddTag(player.Character, SpecialUsers[player.UserId], player)
        end
    end

    -- Announce self as active to Firebase
    local function AnnounceActive()
        pcall(function()
            local url = FIREBASE_URL .. "/active_users/" .. LocalPlayer.UserId .. ".json"
            local data = HttpService:JSONEncode({
                timestamp = os.time(),
                gameId = game.PlaceId,
                jobId = game.JobId,
            })
            request({
                Url = url,
                Method = "PUT",
                Headers = { ["Content-Type"] = "application/json" },
                Body = data,
            })
        end)
    end

    -- Remove self from Firebase when script closes
    local function RemoveSelf()
        pcall(function()
            local url = FIREBASE_URL .. "/active_users/" .. LocalPlayer.UserId .. ".json"
            request({
                Url = url,
                Method = "DELETE",
            })
        end)
    end

    -- Fetch active users from Firebase
    local function FetchActiveUsers()
        local result = {}
        pcall(function()
            local url = FIREBASE_URL .. "/active_users.json"
            local response = game:HttpGet(url)
            if response and response ~= "null" then
                local data = HttpService:JSONDecode(response)
                local now = os.time()
                for odUserId, info in pairs(data) do
                    local userId = tonumber(odUserId)
                    if info.timestamp and (now - info.timestamp) < TIMEOUT_DURATION then
                        result[userId] = true
                    end
                end
            end
        end)
        return result
    end

    -- Check and update nametags based on Firebase data
    local function RefreshNametags()
        if not NametagsEnabled then
            return
        end

        ActiveScriptUsers = FetchActiveUsers()
        ActiveScriptUsers[LocalPlayer.UserId] = true -- Always include self

        for _, player in pairs(game:GetService("Players"):GetPlayers()) do
            if SpecialUsers[player.UserId] then
                if ActiveScriptUsers[player.UserId] then
                    ApplyTagForPlayer(player)
                else
                    ClearTagForPlayer(player)
                end
            end
        end
    end

    -- Start heartbeat loop
    local function StartHeartbeat()
        if heartbeatLoop then
            return
        end
        heartbeatLoop = task.spawn(function()
            while NametagsEnabled do
                AnnounceActive()
                task.wait(HEARTBEAT_INTERVAL)
            end
        end)
    end

    -- Start check loop
    local function StartCheckLoop()
        if checkLoop then
            return
        end
        checkLoop = task.spawn(function()
            while NametagsEnabled do
                RefreshNametags()
                task.wait(10) -- Check every 10 seconds
            end
        end)
    end

    -- Setup character listeners
    for _, player in pairs(game:GetService("Players"):GetPlayers()) do
        player.CharacterAdded:Connect(function()
            task.wait(1)
            if NametagsEnabled and ActiveScriptUsers[player.UserId] and SpecialUsers[player.UserId] then
                ApplyTagForPlayer(player)
            end
        end)
    end
    game:GetService("Players").PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            task.wait(1)
            if NametagsEnabled and ActiveScriptUsers[player.UserId] and SpecialUsers[player.UserId] then
                ApplyTagForPlayer(player)
            end
        end)
    end)

    -- Apply self tag (always show for self if in VIP list)
    local function ApplySelfTag()
        if NametagsEnabled and SpecialUsers[LocalPlayer.UserId] and LocalPlayer.Character then
            AddTag(LocalPlayer.Character, SpecialUsers[LocalPlayer.UserId], LocalPlayer)
        end
    end
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        ApplySelfTag()
    end)

    -- Global Toggle Function (Firebase Version)
    getgenv().ToggleNametags = function(state)
        if not Main or not Main.Parent then
            NametagsEnabled = false
            ClearTags()
            RemoveSelf()
            return
        end

        NametagsEnabled = state

        if state then
            AnnounceActive()
            StartHeartbeat()
            StartCheckLoop()
            ApplySelfTag()
            RefreshNametags()
        else
            ClearTags()
            RemoveSelf()
            ActiveScriptUsers = {}
        end
    end
end

UIHandlers.SetupNametags() -- Firebase-integrated nametag system (shows tags only for active script users)
-- UIHandlers.SetupToolsUI() -- Removed call to nil value

-- === CINEMA MODE / HIDE UI SYSTEM ===
UIHandlers.CinemaMode = {
    isMainUIHidden = false,
    isPlaybackWindowHidden = false,
    showIndicator = true,
    lastF9Press = 0,
}

UIHandlers.ToggleMainUI = function()
    UIHandlers.CinemaMode.isMainUIHidden = not UIHandlers.CinemaMode.isMainUIHidden
    local popup = ScreenGui:FindFirstChild("MapPlayerPopup")

    if UIHandlers.CinemaMode.isMainUIHidden then
        Main.Visible = false
        MinIcon.Visible = false
        if popup then
            popup.Visible = false
        end

        if UIHandlers.CinemaMode.showIndicator then
            if not ScreenGui:FindFirstChild("HiddenIndicator") then
                local ind = Instance.new("TextLabel", ScreenGui)
                ind.Name = "HiddenIndicator"
                ind.Size = UDim2.new(0, 100, 0, 20)
                ind.Position = UDim2.new(1, -110, 0, 5)
                ind.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                ind.BackgroundTransparency = 0.5
                ind.TextColor3 = Color3.fromRGB(100, 100, 100)
                ind.Text = "F2: Show"
                ind.Font = Enum.Font.Gotham
                ind.TextSize = 9
                ind.ZIndex = 9999
                Instance.new("UICorner", ind).CornerRadius = UDim.new(0, 4)
            end
            ScreenGui.HiddenIndicator.Visible = true
        end
        ShowToast("Cinema Mode", "F2 to restore", "info", 2)
    else
        Main.Visible = true
        if popup and currentPlaybackFile and not UIHandlers.CinemaMode.isPlaybackWindowHidden then
            popup.Visible = true
        end
        if ScreenGui:FindFirstChild("HiddenIndicator") then
            ScreenGui.HiddenIndicator.Visible = false
        end
        ShowToast("UI Restored", "", "success", 1)
    end
end

UIHandlers.TogglePlaybackWindow = function()
    local popup = ScreenGui:FindFirstChild("MapPlayerPopup")
    if not popup then
        return
    end
    if UIHandlers.CinemaMode.isMainUIHidden then
        ShowToast("UI Hidden", "Press F2 first", "warning", 1)
        return
    end
    UIHandlers.CinemaMode.isPlaybackWindowHidden = not UIHandlers.CinemaMode.isPlaybackWindowHidden
    if UIHandlers.CinemaMode.isPlaybackWindowHidden then
        popup.Visible = false
        ShowToast("Playback Hidden", "F10 to show", "info", 1)
    else
        if currentPlaybackFile then
            popup.Visible = true
            ShowToast("Playback Visible", "F10 to hide", "info", 1)
        else
            UIHandlers.CinemaMode.isPlaybackWindowHidden = false
            ShowToast("No File Selected", "", "warning", 2)
        end
    end
end

UIHandlers.ToggleIndicator = function()
    local now = tick()
    if now - UIHandlers.CinemaMode.lastF9Press < 0.5 then
        UIHandlers.CinemaMode.showIndicator = not UIHandlers.CinemaMode.showIndicator
        if ScreenGui:FindFirstChild("HiddenIndicator") then
            ScreenGui.HiddenIndicator.Visible = UIHandlers.CinemaMode.showIndicator
                and UIHandlers.CinemaMode.isMainUIHidden
        end
        if not UIHandlers.CinemaMode.showIndicator then
            ShowToast("Clean Mode", "Indicator off", "info", 1)
        end
        return true
    end
    UIHandlers.CinemaMode.lastF9Press = now
    return false
end

-- GLOBAL KEYBIND LISTENER (Recording & Playback)
Connections.MainKeybind = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    -- Block keybinds when typing in any TextBox
    local focusedTextBox = UserInputService:GetFocusedTextBox()
    if focusedTextBox then
        return
    end

    if not gameProcessed and not isBinding and not _G.StarshipIsBindingKeybind then
        if input.KeyCode == Enum.KeyCode.F2 then
            if not UIHandlers.ToggleIndicator() then
                UIHandlers.ToggleMainUI()
            end
            return
        end
        if input.KeyCode == Enum.KeyCode.F10 then
            UIHandlers.TogglePlaybackWindow()
            return
        end

        if Config.Keybinds.StartRecording and input.KeyCode == Config.Keybinds.StartRecording then
            if UIHandlers.ToggleRecording then
                UIHandlers.ToggleRecording()
            end
        end
        if Config.Keybinds.PauseRecording and input.KeyCode == Config.Keybinds.PauseRecording then
            if UIHandlers.OnPauseClick then
                UIHandlers.OnPauseClick()
            end
        end
        if Config.Keybinds.TogglePath and input.KeyCode == Config.Keybinds.TogglePath then
            if UIHandlers.OnTogglePathClick then
                UIHandlers.OnTogglePathClick()
            end
        end
        if Config.Keybinds.PlayPlayback and input.KeyCode == Config.Keybinds.PlayPlayback then
            if PageListMap and PageListMap.Visible and currentPlaybackFile then
                if isPlaying and currentPlaybackSource == "Merger" then
                    if PausePlayback then
                        PausePlayback()
                    end
                elseif currentPlaybackFile then
                    if isfile(MERGER_FOLDER .. "/" .. currentPlaybackFile) then
                        if UIHandlers.PlayMergerRecording then
                            UIHandlers.PlayMergerRecording(currentPlaybackFile, not isPlayPaused)
                        end
                    end
                end
            end
        end
        if Config.Keybinds.StopPlayback and input.KeyCode == Config.Keybinds.StopPlayback then
            if PageListMap and PageListMap.Visible and currentPlaybackSource == "Merger" then
                isPlaying = false
                isPlayPaused = false
                if Connections.Playback then
                    Connections.Playback:Disconnect()
                end
                currentPlaybackTime = 0
                if ResetChar then
                    ResetChar()
                end
                if ClearPath then
                    ClearPath()
                end
            elseif StopPlayback then
                StopPlayback()
            end
        end
    end
end)

SetTheme(C_ACCENT)

-- Start Key System & Loader
local function StartLoader()
    -- Wait for spoof name to be ready if it's being auto-enabled
    if getgenv and getgenv().StarshipSpoofInProgress then
        local waitStart = tick()
        while getgenv().StarshipSpoofInProgress and tick() - waitStart < 3 do
            task.wait(0.1)
        end
    end

    -- Smooth Entrance Animation for Main UI
    if Main then
        -- Ensure MainBackground has correct transparency from start
        local bg = Main:FindFirstChild("MainBackground")
        if bg then
            bg.BackgroundTransparency = 0.05
        end

        -- Start with collapsed size for unfold animation
        Main.Visible = true
        Main.ClipsDescendants = true
        Main.Size = UDim2.new(0, 550, 0, 0)          -- Start as a horizontal line
        Main.Position = UDim2.new(0.5, -275, 0.5, 0) -- Center position

        -- Small delay to ensure intro is fully gone
        task.wait(0.1)

        -- === SMOOTH UNFOLD ANIMATION ===
        local targetHeight = TargetMainHeight
        local targetPosition = UDim2.new(0.5, -275, 0.5, -targetHeight / 2)

        -- Expand Main UI with smooth Back easing (bouncy feel)
        local expandTween =
            TweenService:Create(Main, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 550, 0, targetHeight),
                Position = targetPosition,
            })
        expandTween:Play()

        -- Wait for animation to complete
        task.wait(0.9)
        Main.ClipsDescendants = false
    end

    -- Cleanup any leftover blur from Loader.lua if it wasn't destroyed
    if game:GetService("Lighting"):FindFirstChild("BlurEffect") then
        game:GetService("Lighting").BlurEffect:Destroy()
    end

    -- Enable Nametags
    if getgenv().ToggleNametags then
        getgenv().ToggleNametags(true)
    end

    -- Show ready toast immediately after UI animation completes
    if UIModule and UIModule.ShowToast then
        UIModule.ShowToast("Welcome", "Starship Core Ready", "success", 3)
    end
end

-- Preload spoof name BEFORE showing main UI
-- This ensures spoof is applied before the UI animation starts
task.spawn(function()
    -- Call PreloadSpoofName if available (from ConfigTab)
    if UIHandlers and UIHandlers.PreloadSpoofName then
        UIHandlers.PreloadSpoofName()
    end

    -- Now start the loader (UI animation)
    StartLoader()
end)
