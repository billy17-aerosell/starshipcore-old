-- Adonis Bypass with Nuclear Silence (Aggressive 11s Window)
local SilenceActive = true
task.delay(11, function() SilenceActive = false end)

local sg = game:GetService("StarterGui")
local cg = game:GetService("CoreGui")

-- 1. Hook MetaMethod Namecall (Standard Notifications)
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

-- 2. Aggressive UI Monitoring & Polling
task.spawn(function()
    local function check(obj)
        if not SilenceActive then return end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local t = obj.Text:lower()
            if t:find("adonis") or t:find("pixeluted") or t:find("bypassed") then
                -- Tracing up to find the "Main Box" container
                local root = obj
                while root.Parent and root.Parent ~= cg and root.Parent ~= (game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")) and root.Parent ~= game do
                    root = root.Parent
                end
                -- Pastikan bukan bagian dari UI StarSpace sebelum destroy
                if root.Name ~= "XanHub" and root.Name ~= "StarSpace" then
                    pcall(function() root:Destroy() end)
                end
            end
        end
    end

    cg.DescendantAdded:Connect(check)
    task.spawn(function()
        local lp = game:GetService("Players").LocalPlayer
        while not lp do task.wait() lp = game:GetService("Players").LocalPlayer end
        lp.PlayerGui.DescendantAdded:Connect(check)
        for _, v in pairs(lp.PlayerGui:GetDescendants()) do check(v) end
    end)

    for i = 1, 110 do
        if not SilenceActive then break end
        for _, v in pairs(cg:GetDescendants()) do check(v) end
        task.wait(0.1)
    end
end)

-- 3. Load Adonis Bypass
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/Pixeluted/adoniscries/main/Source.lua'))()
    end)
    
    -- Remove any blur effects that might have been added
    task.wait(0.5)
    pcall(function()
        for _, effect in pairs(game:GetService("Lighting"):GetChildren()) do
            if effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
                effect:Destroy()
            end
        end
    end)
end)

-- Continuous blur cleaner (runs for first 10 seconds)
task.spawn(function()
    for i = 1, 20 do
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
local success, UI = pcall(function() return loadstring(readfile("StarSpace/init.lua"))() end)
if not success or typeof(UI) ~= "table" then 
    UI = {
        New = function() return { AddTab = function() return { AddToggle = function() return { Set = function() end } end, AddSection = function() end, AddButton = function() end, AddSlider = function() end, AddDropdown = function() end, AddParagraph = function() end, AddInput = function() end, AddLabel = function() end, AddRetroButton = function() end } end } end,
        Icons = {},
        Slide = function() end,
        Prompt = function() end,
        Confirm = function() end,
        Splash = function() end,
        CustomTheme = function() end,
        SetTheme = function() end,
        Watermark = function() end,
        QuickCompact = function() return {}, {} end
    }
    warn("[StarSpace] UI Library failed to load! Using dummy UI.")
end
_G.Xan = UI -- Expose for plugins

-- Global State & Cleanup
if _G.StarSpace and _G.StarSpace.Unload then
    pcall(function() _G.StarSpace.Unload() end)
end

_G.StarSpace = _G.StarSpace or {}
_G.StarSpace.Connections = _G.StarSpace.Connections or {}
_G.StarSpace.ShowNotifications = true
_G.StarSpace.Version = "1.0.6"
_G.StarSpace.HubID = os.clock()

-- Manual trigger notification toggle logic to ensure it's on
pcall(function()
    if _G.StarSpace.UpdateNotifications then
        _G.StarSpace.UpdateNotifications(true)
    end
end)

if not UI.Icons then 
    UI.Icons = setmetatable({}, {
        __index = function() return "rbxassetid://0" end
    }) 
end

warn("==========================================")
warn(">>> STARSPACE HUB LOADED - v1.0.6 <<<")
warn("==========================================")
print("[StarSpace] Initializing UI and Logic...")

-- Xan UI Extensions (Prompt & Confirm)
local TweenService = game:GetService("TweenService")
local function CreatePrompt(title, content, callback)
    local theme = UI.CurrentTheme or {
        Background = Color3.fromRGB(18, 18, 22),
        Surface = Color3.fromRGB(25, 25, 32),
        Accent = Color3.fromRGB(220, 60, 85),
        Text = Color3.fromRGB(240, 240, 245)
    }
    
    local screenGui = game:GetService("CoreGui"):FindFirstChild("StarSpace_UI")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "StarSpace_UI"
        screenGui.DisplayOrder = 10000
        screenGui.IgnoreGuiInset = true
        screenGui.Parent = game:GetService("CoreGui")
    end
    
    local overlay = Instance.new("Frame")
    overlay.Name = "PromptOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.Active = true -- Blocks clicks to background
    overlay.ZIndex = 10000
    overlay.Parent = screenGui
    
    -- Modal support for some executors
    local modalBtn = Instance.new("TextButton")
    modalBtn.Size = UDim2.new(0, 0, 0, 0)
    modalBtn.Modal = true
    modalBtn.Visible = true
    modalBtn.Parent = overlay
    
    local main = Instance.new("Frame")
    main.Name = "Dialog"
    main.Size = UDim2.new(0, 320, 0, 180)
    main.Position = UDim2.new(0.5, -160, 0.5, -90)
    main.BackgroundColor3 = theme.Background
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.ZIndex = 10001
    main.Parent = overlay
    
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", main)
    stroke.Color = theme.Accent
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    
    local titleLabel = Instance.new("TextLabel", main)
    titleLabel.Size = UDim2.new(1, 0, 0, 45)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.TextColor3 = theme.Text
    titleLabel.ZIndex = 10002
    
    local contentLabel = Instance.new("TextLabel", main)
    contentLabel.Size = UDim2.new(1, -40, 0, 40)
    contentLabel.Position = UDim2.new(0, 20, 0, 45)
    contentLabel.BackgroundTransparency = 1
    contentLabel.Text = content
    contentLabel.Font = Enum.Font.Gotham
    contentLabel.TextSize = 13
    contentLabel.TextColor3 = theme.Text
    contentLabel.TextTransparency = 0.3
    contentLabel.TextWrapped = true
    contentLabel.ZIndex = 10002
    
    local input = Instance.new("TextBox", main)
    input.Size = UDim2.new(1, -40, 0, 36)
    input.Position = UDim2.new(0, 20, 0, 85)
    input.BackgroundColor3 = theme.Surface or Color3.fromRGB(30,30,35)
    input.BorderSizePixel = 0
    input.Text = ""
    input.PlaceholderText = "Enter value..."
    input.Font = Enum.Font.Gotham
    input.TextSize = 14
    input.TextColor3 = theme.Text
    input.ZIndex = 10002
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 8)
    
    local confirm = Instance.new("TextButton", main)
    confirm.Size = UDim2.new(0.4, 0, 0, 32)
    confirm.Position = UDim2.new(0.075, 0, 1, -45)
    confirm.BackgroundColor3 = theme.Accent
    confirm.Text = "Confirm"
    confirm.Font = Enum.Font.GothamBold
    confirm.TextSize = 13
    confirm.TextColor3 = Color3.new(1, 1, 1)
    confirm.ZIndex = 10003
    Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 8)
    
    local cancel = Instance.new("TextButton", main)
    cancel.Size = UDim2.new(0.4, 0, 0, 32)
    cancel.Position = UDim2.new(0.525, 0, 1, -45)
    cancel.BackgroundColor3 = theme.Surface or Color3.fromRGB(30,30,35)
    cancel.Text = "Cancel"
    cancel.Font = Enum.Font.GothamBold
    cancel.TextSize = 13
    cancel.TextColor3 = theme.Text
    cancel.ZIndex = 10003
    Instance.new("UICorner", cancel).CornerRadius = UDim.new(0, 8)
    
    TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 0.4}):Play()
    main.Size = UDim2.new(0, 0, 0, 0)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0, 320, 0, 180), Position = UDim2.new(0.5, -160, 0.5, -90)}):Play()
    
    confirm.MouseButton1Click:Connect(function()
        overlay:Destroy()
        callback(input.Text)
    end)
    
    cancel.MouseButton1Click:Connect(function()
        overlay:Destroy()
        callback(nil)
    end)
    
    input:CaptureFocus()
end

local function CreateConfirm(title, content, callback)
    local theme = UI.CurrentTheme or {
        Background = Color3.fromRGB(18, 18, 22),
        Surface = Color3.fromRGB(25, 25, 32),
        Accent = Color3.fromRGB(220, 60, 85),
        Text = Color3.fromRGB(240, 240, 245)
    }
    
    local screenGui = game:GetService("CoreGui"):FindFirstChild("StarSpace_UI")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "StarSpace_UI"
        screenGui.DisplayOrder = 10000
        screenGui.IgnoreGuiInset = true
        screenGui.Parent = game:GetService("CoreGui")
    end
    
    local overlay = Instance.new("Frame")
    overlay.Name = "ConfirmOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.Active = true
    overlay.ZIndex = 10000
    overlay.Parent = screenGui
    
    -- Modal support
    local modalBtn = Instance.new("TextButton")
    modalBtn.Size = UDim2.new(0, 0, 0, 0)
    modalBtn.Modal = true
    modalBtn.Visible = true
    modalBtn.Parent = overlay
    
    local main = Instance.new("Frame")
    main.Name = "Dialog"
    main.Size = UDim2.new(0, 300, 0, 140)
    main.Position = UDim2.new(0.5, -150, 0.5, -70)
    main.BackgroundColor3 = theme.Background
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.ZIndex = 10001
    main.Parent = overlay
    
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", main)
    stroke.Color = theme.Accent
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    
    local titleLabel = Instance.new("TextLabel", main)
    titleLabel.Size = UDim2.new(1, 0, 0, 45)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.TextColor3 = theme.Text
    titleLabel.ZIndex = 10002
    
    local contentLabel = Instance.new("TextLabel", main)
    contentLabel.Size = UDim2.new(1, -40, 0, 40)
    contentLabel.Position = UDim2.new(0, 20, 0, 45)
    contentLabel.BackgroundTransparency = 1
    contentLabel.Text = content
    contentLabel.Font = Enum.Font.Gotham
    contentLabel.TextSize = 13
    contentLabel.TextColor3 = theme.Text
    contentLabel.TextTransparency = 0.3
    contentLabel.TextWrapped = true
    contentLabel.ZIndex = 10002
    
    local confirm = Instance.new("TextButton", main)
    confirm.Size = UDim2.new(0.4, 0, 0, 32)
    confirm.Position = UDim2.new(0.075, 0, 1, -45)
    confirm.BackgroundColor3 = theme.Accent
    confirm.Text = "Yes"
    confirm.Font = Enum.Font.GothamBold
    confirm.TextSize = 13
    confirm.TextColor3 = Color3.new(1, 1, 1)
    confirm.ZIndex = 10003
    Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 8)
    
    local cancel = Instance.new("TextButton", main)
    cancel.Size = UDim2.new(0.4, 0, 0, 32)
    cancel.Position = UDim2.new(0.525, 0, 1, -45)
    cancel.BackgroundColor3 = theme.Surface or Color3.fromRGB(30,30,35)
    cancel.Text = "No"
    cancel.Font = Enum.Font.GothamBold
    cancel.TextSize = 13
    cancel.TextColor3 = theme.Text
    cancel.ZIndex = 10003
    Instance.new("UICorner", cancel).CornerRadius = UDim.new(0, 8)
    
    TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 0.4}):Play()
    main.Size = UDim2.new(0, 0, 0, 0)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0, 300, 0, 140), Position = UDim2.new(0.5, -150, 0.5, -70)}):Play()
    
    confirm.MouseButton1Click:Connect(function()
        overlay:Destroy()
        callback()
    end)
    
    cancel.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
end

UI.Prompt = CreatePrompt
UI.Confirm = CreateConfirm

_G.StarSpace = {
    HubID = os.clock(), -- Unique ID for this hub instance
    Version = "1.0.0",
    Connections = {},
    HelperConnections = {},
    Active = true,
    Watermark = nil
}

-- Connection Wrapper
function _G.StarSpace.Connect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(_G.StarSpace.Connections, conn)
    return conn
end

-- Unload Function
function _G.StarSpace.Unload()
    print("[StarSpace] Unloading...")
    _G.StarSpace.Active = false
    
    -- 1. Stop active loops
    _G.StarSpace.isLooping = false
    if _G.StarSpace.StopPlayback then
        pcall(function() _G.StarSpace.StopPlayback(true) end)
    end
    
    -- 2. Disconnect all tracked connections
    if _G.StarSpace.Connections then
        for _, conn in pairs(_G.StarSpace.Connections) do
            pcall(function() conn:Disconnect() end)
        end
        _G.StarSpace.Connections = {}
    end
    
    -- 3. Disconnect HelperConnections (if any were local)
    if _G.StarSpace.HelperConnections then
        for _, conn in pairs(_G.StarSpace.HelperConnections) do
            pcall(function() conn:Disconnect() end)
        end
        _G.StarSpace.HelperConnections = {}
    end

    -- 3b. Disconnect FunConnections
    if _G.StarSpace.FunConnections then
        for _, conn in pairs(_G.StarSpace.FunConnections) do
            pcall(function() conn:Disconnect() end)
        end
        _G.StarSpace.FunConnections = {}
    end
    
    -- 4. Unload Plugins
    if getgenv().RecorderPlugin and getgenv().RecorderPlugin.Unload then
        pcall(function() getgenv().RecorderPlugin:Unload() end)
    end
    if getgenv().MapListPlugin and getgenv().MapListPlugin.Destroy then
        pcall(function() getgenv().MapListPlugin:Destroy() end)
    end
    if getgenv().MergerPlugin and getgenv().MergerPlugin.Unload then
        pcall(function() getgenv().MergerPlugin:Unload() end)
    end
    
    -- 5. Destroy UI
    -- Try official library unload first
    if UI and UI.Unload then pcall(function() UI.Unload() end) end
    if _G.Xan and _G.Xan.Unload then pcall(function() _G.Xan.Unload() end) end

    if _G.StarSpace.Window then
        if _G.StarSpace.Window.Unload then
            pcall(function() _G.StarSpace.Window:Unload() end)
        elseif _G.StarSpace.Window.Destroy then
            pcall(function() _G.StarSpace.Window:Destroy() end)
        end
    end
    
    -- Destroy Watermark
    if _G.StarSpace.Watermark and _G.StarSpace.Watermark.Destroy then
        pcall(function() _G.StarSpace.Watermark:Destroy() end)
    elseif _G.StarSpace.Watermark and _G.StarSpace.Watermark.Hide then
        pcall(function() _G.StarSpace.Watermark:Hide() end)
    end
    
    local coreGui = game:GetService("CoreGui")
    local uiNames = {
        "StarSpace_UI", 
        "StarSpaceSpeed", 
        "Xan_MapListPlugin", 
        "Xan_RecorderPlugin", 
        "StarSpace_Watermark",
        "StarSpace", 
        "ActiveList",
        "Keybinds"
    }
    for _, name in ipairs(uiNames) do
        local ui = coreGui:FindFirstChild(name)
        if ui then pcall(function() ui:Destroy() end) end
    end
    
    -- Aggressive Search: Find UI by Content (The "Nuclear" Option)
    for _, gui in ipairs(coreGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            -- Check 1: Known internal names
            if gui.Name == "StarSpace" or gui:FindFirstChild("ActiveList") or gui:FindFirstChild("Keybinds") then
                pcall(function() gui:Destroy() end)
                continue
            end
            
            -- Check 2: Look for the "ACTIVE" list specifically
            local descendants = gui:GetDescendants()
            for _, obj in ipairs(descendants) do
                if obj:IsA("TextLabel") and (obj.Text == "ACTIVE" or obj.Text == "Show Keybinds") then
                    print("[StarSpace] Found persistent UI: " .. gui.Name)
                    pcall(function() gui:Destroy() end)
                    break
                end
            end
        end
    end
    
    -- 6. Reset Character State
    pcall(function()
        local char = game.Players.LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = 16
                hum.JumpPower = 50
                hum.AutoRotate = true
            end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Anchored = false
            end
        end
    end)
    
    -- 7. Clear Globals
    _G.StarSpace = nil
    print("[StarSpace] Unloaded successfully.")
end

-- Custom Theme Configuration
UI.CustomTheme("StarSpace_Final", "Midnight", {
    -- Accent Colors (Nebula Purple & Cyan)
    Accent = Color3.fromHex("#A855F7"),      -- Vibrant Violet
    AccentDark = Color3.fromHex("#7E22CE"),  -- Deep Purple
    AccentLight = Color3.fromHex("#22D3EE"), -- Bright Cyan

    -- BACKGROUNDS
    Background = Color3.fromHex("#0B0B14"),
    BackgroundSecondary = Color3.fromHex("#131325"),
    Secondary = Color3.fromHex("#131325"),
    Tertiary = Color3.fromHex("#1E1E3A"),
    
    -- Transparency (Enable background image visibility)
    BackgroundTransparency = 0.5,
    SecondaryTransparency = 0.5,
    CardTransparency = 0.5,
    SidebarTransparency = 0.5,

    -- Cards & Elements
    Card = Color3.fromHex("#12121A"),
    CardHover = Color3.fromHex("#191923"),
    CardBorder = Color3.fromHex("#3B2B5E"),
    
    -- SIDEBAR
    Sidebar = Color3.fromHex("#0B0B14"),
    SidebarItem = Color3.fromHex("#131325"),
    SidebarHover = Color3.fromHex("#1E1E3A"),
    SidebarSelected = Color3.fromHex("#A855F7"),
    SidebarActive = Color3.fromHex("#1E1E3A"),
    SidebarDepth = Color3.fromHex("#0B0B14"),
    Selected = Color3.fromHex("#A855F7"),
    Hover = Color3.fromHex("#1E1E3A"),

    -- CONTROLS
    ToggleOn = Color3.fromHex("#A855F7"),
    ToggleOff = Color3.fromHex("#1E1E3A"),
    SliderFill = Color3.fromHex("#A855F7"),
    SliderTrack = Color3.fromHex("#1E1E3A"),
    
    -- INPUT FIELDS
    InputBg = Color3.fromHex("#131325"),
    InputBackground = Color3.fromHex("#131325"),
    InputBorder = Color3.fromHex("#3B2B5E"),
    InputFocus = Color3.fromHex("#22D3EE"),
    
    -- DROPDOWN
    DropdownBg = Color3.fromHex("#131325"),
    DropdownBackground = Color3.fromHex("#131325"),
    DropdownHover = Color3.fromHex("#1E1E3A"),
    
    -- Effects
    Shadow = Color3.fromHex("#000000"),
    ShadowTransparency = 0.8,

    -- Text Colors
    Text = Color3.fromHex("#F0F0FF"),
    TextSecondary = Color3.fromHex("#B4AAD2"),
    TextDim = Color3.fromHex("#8A7FB0"),

    -- BACKGROUND IMAGE
    BackgroundImage = "rbxassetid://110599822363657",
    ImageURL = "rbxassetid://110599822363657",
    ImageOpacity = 0.8,
    OverlayColor = Color3.fromHex("#0B0B14"),
    OverlayOpacity = 0.5,

    -- UserInfo Section
    UserInfo = Color3.fromHex("#131325"),
    UserInfoBackground = Color3.fromHex("#131325"),
    UserInfoBorder = Color3.fromHex("#3B2B5E"),
    Badge = Color3.fromHex("#A855F7"),
    BadgeText = Color3.fromHex("#F0F0FF"),
    StatusOnline = Color3.fromHex("#A855F7"),
    StatusOffline = Color3.fromHex("#1E1E3A")
})

-- Apply Theme Immediately
UI.SetTheme("StarSpace_Final")

-- Login System
-- Secure Key System (Node.js Backend)
-- if UI.Login then
--     local loggedIn = false
--     local SERVER_URL = "http://127.0.0.1:3000/auth"
--     local XOR_KEY = "SecretXorKey123" -- Must match server.js

--     -- XOR Decryption Function
--     local function XorDecrypt(hexStr, key)
--         local result = {}
--         local keyLen = #key
--         local keyBytes = {string.byte(key, 1, -1)}
--         local bytes = {}
--         for i = 1, #hexStr, 2 do
--             table.insert(bytes, tonumber(string.sub(hexStr, i, i+1), 16))
--         end
--         for i = 1, #bytes do
--             local byte = bytes[i]
--             local keyByte = keyBytes[((i-1) % keyLen) + 1]
--             table.insert(result, string.char(bit32.bxor(byte, keyByte)))
--         end
--         return table.concat(result)
--     end

--     -- Robust HWID Getter (works on most executors)
--     local function getHWID()
--         if gethwid then return gethwid() end
--         if get_hwid then return get_hwid() end
--         if HWID then return HWID end
--         return game:GetService("RbxAnalyticsService"):GetClientId()
--     end

--     -- Auto-Login Logic
--     local KEY_FILE = "StarSpace/license.key"
    
--     local function Authenticate(key)
--         local hwid = getHWID()
--         local player = game:GetService("Players").LocalPlayer
--         local HttpService = game:GetService("HttpService")
        
--         -- Collect User Data
--         local username = player.Name
--         local userId = player.UserId
--         local gameId = game.PlaceId
        
--         -- Encode Parameters
--         local encodedKey = HttpService:UrlEncode(key)
--         local encodedHWID = HttpService:UrlEncode(hwid)
--         local encodedUser = HttpService:UrlEncode(username)
        
--         local url = string.format(
--             "%s?key=%s&hwid=%s&roblox_user=%s&roblox_id=%d&game_id=%d",
--             SERVER_URL, encodedKey, encodedHWID, encodedUser, userId, gameId
--         )
        
--         local success, response = pcall(function()
--             return game:HttpGet(url, true)
--         end)

--         if not success then return false, "Connection Error" end
--         local decrypted = XorDecrypt(response, XOR_KEY)
        
--         if decrypted:sub(1, 5) == "Error" then
--             return false, decrypted:sub(8)
--         else
--             return true, decrypted
--         end
--     end

--     -- Try Auto-Login first
--     if isfile(KEY_FILE) then
--         local savedKey = readfile(KEY_FILE)
--         local success, _ = Authenticate(savedKey)
--         if success then
--             loggedIn = true
--         else
--             -- Key invalid or expired, delete file
--             delfile(KEY_FILE)
--         end
--     end

--     if not loggedIn then
--         UI.Login({
--             Title = "StarSpace Premium",
--             Subtitle = "Enter your License Key",
--             Logo = "rbxassetid://110599822363657",
--             ShowSignup = false,
--             ShowForgotPassword = false,
--             ShowSidebar = true,
--             KeySystem = true,
--             OnLogin = function(keyInput, _)
--                 -- 1. Client-Side Validation
--                 if not keyInput or keyInput:gsub(" ", "") == "" then 
--                     return false, "Please enter a valid License Key" 
--                 end
                
--                 -- 2. Authenticate
--                 local success, result = Authenticate(keyInput)
                
--                 if success then
--                     -- Auth Successful! Save key for next time
--                     writefile(KEY_FILE, keyInput)
--                     loggedIn = true
--                     return true
--                 else
--                     return false, result
--                 end
--             end
--         })
        
--         repeat task.wait(0.1) until loggedIn
--     end
-- end


-- Loading Screen Logic
local loadingFinished = false
UI.Splash({
    Title = "StarSpace",
    Subtitle = "Initializing System...",
    Logo = "rbxassetid://110599822363657",
    Duration = 3,
    OnComplete = function()
        loadingFinished = true
    end
})

-- Backup: If OnComplete doesn't fire, continue after duration
task.delay(3.5, function() loadingFinished = true end)

-- Wait for loading to finish before creating the UI
repeat task.wait() until loadingFinished

-- Onboarding Wizard (First Run Only)
if isfile("StarSpace/onboarding_complete.txt") then
    print("[StarSpace] Onboarding already completed. Skipping wizard.")
else
    local onboardingDone = false
    
    -- Ensure directory exists
    if not isfolder("StarSpace") then makefolder("StarSpace") end
    
    -- Custom Onboarding UI
    local function ShowCustomOnboarding()
        -- Robust theme retrieval with fallbacks
        local current = UI.CurrentTheme or {}
        local theme = {
            Background = current.Background or Color3.fromRGB(18, 18, 22),
            Surface = current.Surface or current.Secondary or Color3.fromRGB(25, 25, 32),
            Accent = current.Accent or Color3.fromRGB(168, 85, 247),
            Text = current.Text or Color3.fromRGB(240, 240, 245),
            TextSecondary = current.TextSecondary or Color3.fromRGB(180, 180, 200),
            Border = current.Border or current.CardBorder or Color3.fromRGB(60, 60, 80)
        }
        
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "StarSpace_Onboard"
        screenGui.DisplayOrder = 10005
        screenGui.IgnoreGuiInset = true
        screenGui.Parent = game:GetService("CoreGui")
        
        local overlay = Instance.new("Frame")
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundColor3 = Color3.new(0,0,0)
        overlay.BackgroundTransparency = 0.3
        overlay.Parent = screenGui
        
        -- Main Container
        local main = Instance.new("Frame")
        main.Size = UDim2.new(0, 500, 0, 350)
        main.Position = UDim2.new(0.5, -250, 0.5, -175)
        main.BackgroundColor3 = theme.Background
        main.BorderSizePixel = 0
        main.ClipsDescendants = true
        main.Parent = screenGui
        
        Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)
        local stroke = Instance.new("UIStroke", main)
        stroke.Color = theme.Accent
        stroke.Thickness = 1.5
        stroke.Transparency = 0.5
        
        -- Pages Container
        local pages = Instance.new("Frame")
        pages.Size = UDim2.new(1, 0, 1, 0)
        pages.BackgroundTransparency = 1
        pages.Parent = main
        
        local currentStep = 1
        local selectedLayout = "Commander"
        
        -- Helper: Create Page
        local function CreatePage(index)
            local page = Instance.new("Frame")
            page.Name = "Page" .. index
            page.Size = UDim2.new(1, 0, 1, 0)
            page.Position = UDim2.new(index - 1, 0, 0, 0)
            page.BackgroundTransparency = 1
            page.Parent = pages
            return page
        end
        
        -- PAGE 1: WELCOME
        local p1 = CreatePage(1)
        
        local logo = Instance.new("ImageLabel")
        logo.Size = UDim2.new(0, 80, 0, 80)
        logo.Position = UDim2.new(0.5, -40, 0.15, 0)
        logo.BackgroundTransparency = 1
        logo.Image = "rbxassetid://110599822363657"
        logo.Parent = p1
        
        local title1 = Instance.new("TextLabel")
        title1.Size = UDim2.new(1, 0, 0, 30)
        title1.Position = UDim2.new(0, 0, 0.45, 0)
        title1.BackgroundTransparency = 1
        title1.Text = "Welcome to StarSpace"
        title1.Font = Enum.Font.GothamBold
        title1.TextSize = 26
        title1.TextColor3 = theme.Text
        title1.Parent = p1
        
        local desc1 = Instance.new("TextLabel")
        desc1.Size = UDim2.new(0.8, 0, 0, 40)
        desc1.Position = UDim2.new(0.1, 0, 0.55, 0)
        desc1.BackgroundTransparency = 1
        desc1.Text = "Experience the next generation of automation.\nLet's get you set up."
        desc1.Font = Enum.Font.Gotham
        desc1.TextSize = 14
        desc1.TextColor3 = theme.TextSecondary
        desc1.TextWrapped = true
        desc1.Parent = p1
        
        local btnNext1 = Instance.new("TextButton")
        btnNext1.Size = UDim2.new(0, 140, 0, 40)
        btnNext1.Position = UDim2.new(0.5, -70, 0.8, 0)
        btnNext1.BackgroundColor3 = theme.Accent
        btnNext1.Text = "Get Started"
        btnNext1.Font = Enum.Font.GothamBold
        btnNext1.TextSize = 14
        btnNext1.TextColor3 = Color3.new(1,1,1)
        btnNext1.Parent = p1
        Instance.new("UICorner", btnNext1).CornerRadius = UDim.new(0, 8)
        
        -- PAGE 2: LAYOUT SELECTION
        local p2 = CreatePage(2)
        
        local title2 = Instance.new("TextLabel")
        title2.Size = UDim2.new(1, 0, 0, 30)
        title2.Position = UDim2.new(0, 0, 0.1, 0)
        title2.BackgroundTransparency = 1
        title2.Text = "Choose Your Interface"
        title2.Font = Enum.Font.GothamBold
        title2.TextSize = 22
        title2.TextColor3 = theme.Text
        title2.Parent = p2
        
        local layoutContainer = Instance.new("Frame")
        layoutContainer.Size = UDim2.new(0.9, 0, 0.5, 0)
        layoutContainer.Position = UDim2.new(0.05, 0, 0.25, 0)
        layoutContainer.BackgroundTransparency = 1
        layoutContainer.Parent = p2
        
        local function CreateCard(name, desc, icon, posX)
            local card = Instance.new("TextButton")
            card.Size = UDim2.new(0.48, 0, 1, 0)
            card.Position = UDim2.new(posX, 0, 0, 0)
            card.BackgroundColor3 = theme.Surface
            card.AutoButtonColor = false
            card.Text = ""
            card.Parent = layoutContainer
            
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
            local stroke = Instance.new("UIStroke", card)
            stroke.Color = theme.Border
            stroke.Thickness = 1.5
            
            local iconImg = Instance.new("ImageLabel")
            iconImg.Size = UDim2.new(0, 40, 0, 40)
            iconImg.Position = UDim2.new(0.5, -20, 0.15, 0)
            iconImg.BackgroundTransparency = 1
            iconImg.Image = icon
            iconImg.ImageColor3 = theme.Text
            iconImg.Parent = card
            
            local cardTitle = Instance.new("TextLabel")
            cardTitle.Size = UDim2.new(1, 0, 0, 20)
            cardTitle.Position = UDim2.new(0, 0, 0.45, 0)
            cardTitle.BackgroundTransparency = 1
            cardTitle.Text = name
            cardTitle.Font = Enum.Font.GothamBold
            cardTitle.TextSize = 16
            cardTitle.TextColor3 = theme.Text
            cardTitle.Parent = card
            
            local cardDesc = Instance.new("TextLabel")
            cardDesc.Size = UDim2.new(0.9, 0, 0.3, 0)
            cardDesc.Position = UDim2.new(0.05, 0, 0.6, 0)
            cardDesc.BackgroundTransparency = 1
            cardDesc.Text = desc
            cardDesc.Font = Enum.Font.Gotham
            cardDesc.TextSize = 12
            cardDesc.TextColor3 = theme.TextSecondary
            cardDesc.TextWrapped = true
            cardDesc.Parent = card
            
            return card, stroke
        end
        
        local card1, stroke1 = CreateCard("Commander", "Full experience with Dashboard, Tools, and advanced controls.", "rbxassetid://6034287513", 0) -- Dashboard icon
        local card2, stroke2 = CreateCard("Tactical", "Streamlined HUD focused on Auto-Walk and performance.", "rbxassetid://6031280882", 0.52) -- Minimal icon
        
        local function UpdateSelection()
            stroke1.Color = selectedLayout == "Commander" and theme.Accent or theme.Border
            stroke1.Thickness = selectedLayout == "Commander" and 2 or 1.5
            card1.BackgroundColor3 = selectedLayout == "Commander" and theme.Surface:Lerp(theme.Accent, 0.1) or theme.Surface
            
            stroke2.Color = selectedLayout == "Tactical" and theme.Accent or theme.Border
            stroke2.Thickness = selectedLayout == "Tactical" and 2 or 1.5
            card2.BackgroundColor3 = selectedLayout == "Tactical" and theme.Surface:Lerp(theme.Accent, 0.1) or theme.Surface
        end
        
        card1.MouseButton1Click:Connect(function() selectedLayout = "Commander"; UpdateSelection() end)
        card2.MouseButton1Click:Connect(function() selectedLayout = "Tactical"; UpdateSelection() end)
        UpdateSelection()
        
        local btnNext2 = Instance.new("TextButton")
        btnNext2.Size = UDim2.new(0, 140, 0, 40)
        btnNext2.Position = UDim2.new(0.5, -70, 0.85, 0)
        btnNext2.BackgroundColor3 = theme.Accent
        btnNext2.Text = "Continue"
        btnNext2.Font = Enum.Font.GothamBold
        btnNext2.TextSize = 14
        btnNext2.TextColor3 = Color3.new(1,1,1)
        btnNext2.Parent = p2
        Instance.new("UICorner", btnNext2).CornerRadius = UDim.new(0, 8)
        
        -- PAGE 3: FINISH
        local p3 = CreatePage(3)
        
        local icon3 = Instance.new("ImageLabel")
        icon3.Size = UDim2.new(0, 60, 0, 60)
        icon3.Position = UDim2.new(0.5, -30, 0.2, 0)
        icon3.BackgroundTransparency = 1
        icon3.Image = "rbxassetid://110599822363657"
        icon3.Parent = p3
        
        local title3 = Instance.new("TextLabel")
        title3.Size = UDim2.new(1, 0, 0, 30)
        title3.Position = UDim2.new(0, 0, 0.45, 0)
        title3.BackgroundTransparency = 1
        title3.Text = "You're All Set!"
        title3.Font = Enum.Font.GothamBold
        title3.TextSize = 24
        title3.TextColor3 = theme.Text
        title3.Parent = p3
        
        local desc3 = Instance.new("TextLabel")
        desc3.Size = UDim2.new(1, 0, 0, 30)
        desc3.Position = UDim2.new(0, 0, 0.55, 0)
        desc3.BackgroundTransparency = 1
        desc3.Text = "StarSpace is ready to launch."
        desc3.Font = Enum.Font.Gotham
        desc3.TextSize = 14
        desc3.TextColor3 = theme.TextSecondary
        desc3.Parent = p3
        
        local btnLaunch = Instance.new("TextButton")
        btnLaunch.Size = UDim2.new(0, 160, 0, 45)
        btnLaunch.Position = UDim2.new(0.5, -80, 0.75, 0)
        btnLaunch.BackgroundColor3 = theme.Accent
        btnLaunch.Text = "Launch StarSpace"
        btnLaunch.Font = Enum.Font.GothamBold
        btnLaunch.TextSize = 16
        btnLaunch.TextColor3 = Color3.new(1,1,1)
        btnLaunch.Parent = p3
        Instance.new("UICorner", btnLaunch).CornerRadius = UDim.new(0, 8)
        
        -- Navigation Logic
        local function GoToPage(pageIdx)
            TweenService:Create(pages, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(-(pageIdx-1), 0, 0, 0)}):Play()
        end
        
        btnNext1.MouseButton1Click:Connect(function() GoToPage(2) end)
        btnNext2.MouseButton1Click:Connect(function() 
            desc3.Text = "Launching in " .. selectedLayout .. " Mode..."
            GoToPage(3) 
        end)
        
        btnLaunch.MouseButton1Click:Connect(function()
            writefile("StarSpace/onboarding_complete.txt", "Layout=" .. selectedLayout)
            TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
            TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            task.wait(0.3)
            screenGui:Destroy()
            onboardingDone = true
        end)
        
        -- Intro Animation
        main.Size = UDim2.new(0, 0, 0, 0)
        main.Position = UDim2.new(0.5, 0, 0.5, 0)
        TweenService:Create(main, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Size = UDim2.new(0, 500, 0, 350), Position = UDim2.new(0.5, -250, 0.5, -175)}):Play()
    end
    
    ShowCustomOnboarding()
    
    -- Wait for onboarding to finish before showing main window
    repeat task.wait(0.1) until onboardingDone
end

-- Determine Layout Style from Onboarding
local layoutName = "Default" -- Default (Sidebar)
local windowSize = UDim2.new(0, 600, 0, 500)

if isfile("StarSpace/onboarding_complete.txt") then
    local content = readfile("StarSpace/onboarding_complete.txt")
    if content:match("Layout=Tactical") then
        layoutName = "Traditional" -- Top Tabs
        windowSize = UDim2.new(0, 550, 0, 400) -- Smaller for Tactical
    end
end

-- Main Window (Created ONLY after splash is gone)
local Window = UI.New({
    Title = "STARSPACE",
    Theme = "StarSpace_Final",
    Size = windowSize,
    Layout = layoutName, -- "Default" or "Traditional"
    ShowLogo = true,
    Logo = "rbxassetid://110599822363657",
    WindowButtonStyle = "macOS",
    ShowUserInfo = true,
    ShowActiveList = true
})
_G.StarSpace.Window = Window

-- Background Image Auto-Restore on Window Show (Event-based, no FPS drop)
pcall(function()
    local mainFrame = Window.Frame or Window.Main or Window.Container
    if mainFrame and typeof(mainFrame) == "Instance" then
        -- Listen for visibility changes
        local conn = mainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
            if mainFrame.Visible then
                -- Small delay to let UI settle, then restore theme
                task.delay(0.1, function()
                    pcall(function()
                        UI.SetTheme("StarSpace_Final")
                    end)
                end)
            end
        end)
        table.insert(_G.StarSpace.Connections, conn)
    end
end)

-- Overlays
local Watermark = UI.Watermark({ Text = "StarSpace Monitor", Position = UDim2.new(0.5, -80, 0, 5), AnchorPoint = Vector2.new(0.5, 0), ShowFPS = true, ShowPing = true, Visible = false })
_G.StarSpace.Watermark = Watermark

-- Tabs (Icons from ui.xan.bar/docs#icons)
local Dashboard = Window:AddTab("DASHBOARD", UI.Icons.Home)           -- House icon
local Hubs = Window:AddTab("HUBS", UI.Icons.Hubs)                      -- Hubs icon
local MapList = Window:AddTab("AUTO WALK", UI.Icons.Plugins)            -- Layout grid icon (for map/recording list)

local Tools = Window:AddTab("TOOLS", UI.Icons.Misc)                    -- Wrench/Box icon
local Animations = Window:AddTab("ANIMATIONS", UI.Icons.Visuals)       -- Eye icon
local Helper = Window:AddTab("HELPER", UI.Icons.Combat)             -- Shield icon
local Fun = Window:AddTab("FUN", UI.Icons.Buttons)                     -- Button grid icon
local Settings = Window:AddTab("SETTINGS", UI.Icons.Settings)          -- Gear icon
local Info = Window:AddTab("INFO", UI.Icons.Warning)                   -- Warning triangle icon

-- Dashboard Tab
local hour = tonumber(os.date("%H"))
local greeting = (hour >= 5 and hour < 12) and "Good Morning" or ((hour >= 12 and hour < 17) and "Good Afternoon" or "Good Evening")

-- Stylish Header
Dashboard:CreateHubHeader({
    Title = greeting .. ", " .. (#game.Players.LocalPlayer.DisplayName > 15 and (game.Players.LocalPlayer.DisplayName:sub(1, 12) .. "...") or game.Players.LocalPlayer.DisplayName),
    Subtitle = "Welcome back to StarSpace • " .. os.date("%A, %d %B")
})

-- Current Game Section
Dashboard:AddSection("Current Session")

local MarketplaceService = game:GetService("MarketplaceService")
local gameName = "Unknown Game"
local gameIcon = UI.Icons.Globe or "rbxassetid://0" -- Default fallback

pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info then 
        gameName = info.Name 
        -- Fix: GameIcon type requires UniverseId (game.GameId), not PlaceId
        if game.GameId and game.GameId > 0 then
            gameIcon = "rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=512&h=512"
        end
    end
end)

Dashboard:CreateGameCard({
    Name = #gameName > 30 and (gameName:sub(1, 27) .. "...") or gameName,
    Image = gameIcon,
    Description = "Place ID: " .. game.PlaceId .. " • Click to Copy",
    OnLoad = function()
        setclipboard(tostring(game.PlaceId))
        UI.Slide("System", "Place ID copied to clipboard!")
    end
})

-- System Info Section
Dashboard:AddSection("System Status")

local function GetExecutor()
    if identifyexecutor then return identifyexecutor() end
    if getexecutorname then return getexecutorname() end
    return "Unknown"
end

Dashboard:AddParagraph("Executor Info", "Executor: " .. GetExecutor() .. "\nStatus: Undetected")
Dashboard:AddParagraph("User Info", "ID: " .. game.Players.LocalPlayer.UserId .. "\nAge: " .. game.Players.LocalPlayer.AccountAge .. " days")

Dashboard:AddRetroButton({Name = "Copy HWID", Callback = function()
     local hwid = "Unknown"
     pcall(function() hwid = game:GetService("RbxAnalyticsService"):GetClientId() end)
     setclipboard(hwid)
     UI.Slide("System", "HWID copied!")
end})






-- Tools Tab
Tools:AddSection("Player")

Tools:AddRetroButton({Name = "Get Game Info", Callback = function()
    local placeId = game.PlaceId
    local universeId = game.GameId
    local gameName = game:GetService("MarketplaceService"):GetProductInfo(placeId).Name
    local iconUrl = "rbxthumb://type=GameIcon&id=" .. universeId .. "&w=512&h=512"
    
    print("--- Game Info ---")
    print("Name: " .. gameName)
    print("Place ID: " .. placeId)
    print("Universe ID: " .. universeId)
    print("Icon URL: " .. iconUrl)
    print("-----------------")
    
    setclipboard(iconUrl)
    UI.Slide("System", "Icon URL copied to clipboard! Check console (F9) for more info.")
end})

-- Speed Checker
local SpeedGui = nil
Tools:AddToggle("Speed Display", {Default = false}, function(v)
    if v then
        SpeedGui = Instance.new("ScreenGui", game.CoreGui)
        SpeedGui.Name = "StarSpaceSpeed"
        local Frame = Instance.new("Frame", SpeedGui)
        Frame.Size = UDim2.new(0, 150, 0, 50)
        Frame.Position = UDim2.new(0.5, -75, 0.85, 0)
        Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        Frame.BackgroundTransparency = 0.2
        Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)
        
        local Label = Instance.new("TextLabel", Frame)
        Label.Size = UDim2.new(1, 0, 1, 0)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextSize = 20
        Label.Font = Enum.Font.GothamBold
        Label.Text = "Speed: 0"
        
        task.spawn(function()
            while SpeedGui and SpeedGui.Parent do
                if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
                    Label.Text = "Speed: " .. math.floor(game.Players.LocalPlayer.Character.Humanoid.WalkSpeed)
                end
                task.wait(0.1)
            end
        end)
    else
        if SpeedGui then SpeedGui:Destroy() SpeedGui = nil end
    end
end)

-- Shift Lock
-- Shift Lock
local ShiftLockEnabled = false
local ShiftLockToggle = Tools:AddToggle("Shift Lock", {Default = false, Flag = "ShiftLock"}, function(v)
    ShiftLockEnabled = v
    if v then
        local conn = game:GetService("RunService").RenderStepped:Connect(function()
            game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.LockCenter
            local char = game.Players.LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local cam = workspace.CurrentCamera
                local look = cam.CFrame.LookVector
                char.HumanoidRootPart.CFrame = CFrame.lookAt(char.HumanoidRootPart.Position, char.HumanoidRootPart.Position + Vector3.new(look.X, 0, look.Z))
            end
        end)
        _G.StarSpace.Connections["ShiftLock"] = conn
    else
        if _G.StarSpace.Connections["ShiftLock"] then 
            _G.StarSpace.Connections["ShiftLock"]:Disconnect() 
            _G.StarSpace.Connections["ShiftLock"] = nil 
        end
        game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.Default
    end
    UI.Slide("Tools", "Shift Lock " .. (v and "ON" or "OFF"))
end)
Tools:AddKeybind("Shift Lock Keybind", { Default = Enum.KeyCode.Unknown, Flag = "ShiftLockKey" }, function()
    local newVal = not ShiftLockEnabled
    print("[StarSpace] Keybind -> Toggling ShiftLock to:", newVal)
    if ShiftLockToggle and ShiftLockToggle.Set then
        ShiftLockToggle:Set(newVal)
    end
end)
-- Note: Gamepad users can use Triangle/Y button to toggle Shift Lock

-- Gamepad Support: Triangle button (ButtonY) toggles Shift Lock
local gpConn = game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonY then
        local newVal = not ShiftLockEnabled
        print("[StarSpace] Gamepad Triangle -> Toggling ShiftLock to:", newVal)
        if ShiftLockToggle and typeof(ShiftLockToggle) == "table" and ShiftLockToggle.Set then
            pcall(function() ShiftLockToggle:Set(newVal) end)
        end
    end
end)
table.insert(_G.StarSpace.Connections, gpConn)

Tools:AddSection("Automation")
local AntiTabDetect = false -- Internal variable for hooks
local DisabledConns = {} -- Store connections to restore later

Tools:AddToggle("Anti-AFK", {Default = false}, function(v)
    AntiTabDetect = v -- Enable tab-out/remote blocking hooks
    
    if v then
        local vu = game:GetService("VirtualUser")
        local lp = game:GetService("Players").LocalPlayer
        local UIS = game:GetService("UserInputService")
        
        -- 1. Anti-Idle (Standard Roblox 20min bypass)
        local conn = lp.Idled:Connect(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
        _G.StarSpace.Connections["AntiAFK"] = conn
        
        -- 2. Forcefully disable existing focus-loss connections & STORE THEM
        pcall(function()
            DisabledConns = {}
            for _, c in pairs(getconnections(UIS.WindowFocusReleased)) do
                if c.Enabled then
                    c:Disable()
                    table.insert(DisabledConns, c)
                end
            end
            for _, c in pairs(getconnections(UIS.WindowFocused)) do -- Tambahkan WindowFocused juga
                if c.Enabled then
                    c:Disable()
                    table.insert(DisabledConns, c)
                end
            end
        end)
        
        -- 3. Background Protection Loop (Wiggle + Attribute Lock)
        task.spawn(function()
            while _G.StarSpace.Connections["AntiAFK"] == conn do
                pcall(function()
                    local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        hum.Jump = true
                    end
                end)
                
                for i = 1, 60 do 
                    if not _G.StarSpace.Connections["AntiAFK"] or _G.StarSpace.Connections["AntiAFK"] ~= conn then break end
                    pcall(function()
                        if lp:GetAttribute("AFK") then lp:SetAttribute("AFK", false) end
                        if lp:GetAttribute("IsAFK") then lp:SetAttribute("IsAFK", false) end
                    end)
                    task.wait(1)
                end
            end
        end)
        
        UI.Slide("Automation", "Anti-AFK + Ultra Protection Enabled")
    else
        -- 1. Restore the game's original connections
        for _, c in pairs(DisabledConns) do
            pcall(function() c:Enable() end)
        end
        DisabledConns = {}

        -- 2. Disconnect our protection
        if _G.StarSpace.Connections["AntiAFK"] then
            _G.StarSpace.Connections["AntiAFK"]:Disconnect()
            _G.StarSpace.Connections["AntiAFK"] = nil
        end
        UI.Slide("Automation", "Anti-AFK Disabled (Normal Mode)")
    end
end)

Tools:AddSection("Environment")
Tools:AddSlider("Time", {Min = 0, Max = 24, Default = 12}, function(v)
    game:GetService("Lighting").ClockTime = v
end)

Tools:AddToggle("Fullbright", {Default = false}, function(v)
    if v then
        game:GetService("Lighting").Brightness = 2
        game:GetService("Lighting").ClockTime = 14
        game:GetService("Lighting").GlobalShadows = false
        game:GetService("Lighting").OutdoorAmbient = Color3.new(1, 1, 1)
    else
        game:GetService("Lighting").Brightness = 1
        game:GetService("Lighting").GlobalShadows = true
        game:GetService("Lighting").OutdoorAmbient = Color3.fromRGB(127, 127, 127)
    end
end)

Tools:AddSection("Security")
-- Bypass Admin (auto-leave saat admin terdeteksi) — FULL detection
Tools:AddToggle("Bypass Admin", {Default = false}, function(v)
    if v then
        local lp = game.Players.LocalPlayer
        local creatorType = game.CreatorType
        local creatorId = game.CreatorId
        
        -- Fungsi cek apakah player adalah admin (FULL detection)
        local function isAdmin(plr)
            if plr == lp then return false end
            
            -- 0. Cek ModuleScan cache (shared dari MobileUI)
            if _G._ScannedAdminUserIds and _G._ScannedAdminUserIds[plr.UserId] then
                return true
            end
            
            -- 1. Game milik User → cek UserId
            if creatorType == Enum.CreatorType.User then
                if plr.UserId == creatorId then return true end
            end
            
            -- 2. Game milik Group → cek rank + role
            if creatorType == Enum.CreatorType.Group then
                local ok, rank = pcall(function()
                    return plr:GetRankInGroup(creatorId)
                end)
                if ok and rank and rank >= 100 then return true end
                
                local ok2, role = pcall(function()
                    return plr:GetRoleInGroup(creatorId)
                end)
                if ok2 and role then
                    local lower = role:lower()
                    if lower:find("admin") or lower:find("mod") or lower:find("staff") 
                       or lower:find("dev") or lower:find("owner") then
                        return true
                    end
                end
            end
            
            -- 3. Cek Player Attributes
            pcall(function()
                local adminAttrs = {"IsAdmin", "isAdmin", "Admin", "Role", "role", 
                    "Rank", "rank", "AdminLevel", "StaffLevel", "Permission", "IsDev"}
                for _, attrName in ipairs(adminAttrs) do
                    local ok3, val = pcall(function() return plr:GetAttribute(attrName) end)
                    if ok3 and val ~= nil then
                        if type(val) == "boolean" and val == true then
                            return true
                        elseif type(val) == "string" then
                            local vl = val:lower()
                            if vl:find("admin") or vl:find("owner") or vl:find("mod") or vl:find("staff") then
                                return true
                            end
                        end
                    end
                end
            end)
            
            -- 4. Cek Overhead BillboardGui
            if plr.Character then
                pcall(function()
                    local adminKws = {"admin", "owner", "moderator", "staff", "developer", "super admin"}
                    for _, desc in ipairs(plr.Character:GetDescendants()) do
                        if desc:IsA("BillboardGui") then
                            for _, child in ipairs(desc:GetDescendants()) do
                                if (child:IsA("TextLabel") or child:IsA("TextButton")) then
                                    local txt = child.Text:lower()
                                    for _, kw in ipairs(adminKws) do
                                        if txt:find(kw, 1, true) then return true end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
            
            return false
        end
        
        -- Cek pemain yang SUDAH ada di server
        for _, plr in pairs(game.Players:GetPlayers()) do
            if isAdmin(plr) then
                lp:Kick("⚠️ Admin detected in server: " .. plr.Name .. " — Auto-leave for safety")
                return
            end
        end
        
        UI.Slide("Security", "Bypass Admin enabled — monitoring...")
        
        -- Watch pemain baru yang masuk
        local conn = game.Players.PlayerAdded:Connect(function(plr)
            task.wait(0.5)
            if isAdmin(plr) then
                lp:Kick("⚠️ Admin joined: " .. plr.Name .. " — Auto-leave for safety")
            end
        end)
        _G.StarSpace.Connections["AdminBypass"] = conn
        
        -- Async HTTP check (HANYA grup game ini)
        if creatorType == Enum.CreatorType.Group then
            task.spawn(function()
                for _, plr in pairs(game.Players:GetPlayers()) do
                    if plr ~= lp then
                        pcall(function()
                            local HttpService = game:GetService("HttpService")
                            local response = game:HttpGet("https://groups.roblox.com/v1/users/" .. plr.UserId .. "/groups/roles")
                            local data = HttpService:JSONDecode(response)
                            if data and data.data then
                                for _, group in ipairs(data.data) do
                                    local gId = group.group and group.group.id
                                    local rank = group.role and group.role.rank or 0
                                    if gId == creatorId and rank >= 100 then
                                        lp:Kick("⚠️ Admin detected: " .. plr.Name .. " (Group Rank " .. rank .. ")")
                                        return
                                    end
                                end
                            end
                        end)
                    end
                end
            end)
        end
    else
        if _G.StarSpace.Connections["AdminBypass"] then
            _G.StarSpace.Connections["AdminBypass"]:Disconnect()
            _G.StarSpace.Connections["AdminBypass"] = nil
        end
        UI.Slide("Security", "Bypass Admin disabled")
    end
end)


Tools:AddSection("Privacy")

local SpoofName = ""
local DeviceSpoof = "Default"
local SpoofEnabled = false

-- ============================================
-- PERSISTENT SPOOF SETTINGS
-- Settings disimpan ke file agar hooks aktif otomatis saat rejoin.
-- Ini KUNCI agar spoofing terlihat oleh orang lain!
-- Flow: Enable spoof → Save settings → Rejoin → Hooks aktif SEBELUM server detect device
-- ============================================
local SPOOF_SETTINGS_FILE = "StarSpace/spoof_settings.json"

local function saveSpoofSettings()
    pcall(function()
        local data = game:GetService("HttpService"):JSONEncode({
            DeviceSpoof = DeviceSpoof,
            SpoofEnabled = SpoofEnabled,
            SpoofName = SpoofName
        })
        writefile(SPOOF_SETTINGS_FILE, data)
    end)
end

local function clearSpoofSettings()
    pcall(function()
        if isfile(SPOOF_SETTINGS_FILE) then
            delfile(SPOOF_SETTINGS_FILE)
        end
    end)
end

-- Load saved settings (override defaults jika ada)
pcall(function()
    if isfile(SPOOF_SETTINGS_FILE) then
        local raw = readfile(SPOOF_SETTINGS_FILE)
        local data = game:GetService("HttpService"):JSONDecode(raw)
        if data then
            if data.DeviceSpoof and data.DeviceSpoof ~= "Default" then
                DeviceSpoof = data.DeviceSpoof
            end
            if data.SpoofEnabled then
                SpoofEnabled = true
            end
            if data.SpoofName and data.SpoofName ~= "" then
                SpoofName = data.SpoofName
            end
            if SpoofEnabled then
                print("[StarSpace] Loaded spoof settings: Device=" .. DeviceSpoof)
            end
        end
    end
end)

Tools:AddInput("Spoof Name", {Placeholder = "Enter fake name..."}, function(v)
    SpoofName = v
    saveSpoofSettings()
end)

-- Device Hooking (Requires executor support)
local HooksApplied = false
local function ApplyPrivacyHooks()
    if HooksApplied or not hookmetamethod then return end
    
    local lp = game.Players.LocalPlayer
    local UIS = game:GetService("UserInputService")
    local GS = game:GetService("GuiService")
    
    -- ============================================
    -- SMART DEVICE TERM MAPPING
    -- Setiap game punya term sendiri: "Phone"/"Computer"/"Gamepad"
    -- Kita harus pakai term GAME, bukan generic "Mobile"/"PC"/"Console"
    -- ============================================
    if not _G._StarSpaceDeviceTerms then _G._StarSpaceDeviceTerms = {} end
    
    local TERM_TO_CATEGORY = {
        -- PC terms
        computer = "PC", pc = "PC", desktop = "PC", keyboard = "PC",
        windows = "PC", ["windows10"] = "PC", win64 = "PC", win32 = "PC", uwp = "PC",
        -- Mobile terms
        phone = "Mobile", mobile = "Mobile", touch = "Mobile",
        android = "Mobile", ios = "Mobile", tablet = "Mobile",
        -- Console terms
        console = "Console", gamepad = "Console", xbox = "Console",
        playstation = "Console", controller = "Console",
    }
    
    local function getDeviceCategory(val)
        if typeof(val) ~= "string" then return nil end
        return TERM_TO_CATEGORY[val:lower()]
    end
    
    local function getGameTermForTarget()
        -- Pakai term yang game sudah pernah pakai untuk kategori target
        return (_G._StarSpaceDeviceTerms[DeviceSpoof]) or DeviceSpoof
    end
    
    local function learnGameTerm(val)
        local cat = getDeviceCategory(val)
        if cat then
            _G._StarSpaceDeviceTerms[cat] = val
        end
    end

    -- Recursive Spoof Function (For Remotes & Tables)
    -- SMART: Hanya ganti value yang beda kategori, pakai term game
    local function deepSpoof(val)
        local tVal = typeof(val)
        if tVal == "string" then
            local cat = getDeviceCategory(val)
            if cat then
                learnGameTerm(val)
                if cat == DeviceSpoof then
                    return val -- Sudah kategori yang benar, biarkan!
                else
                    return getGameTermForTarget()
                end
            end
        elseif tVal == "EnumItem" then
            if DeviceSpoof == "Mobile" then
                if val == Enum.Platform.Windows or val == Enum.Platform.OSX or val == Enum.Platform.UWP then
                    return Enum.Platform.Android
                end
            elseif DeviceSpoof == "Console" then
                if val == Enum.Platform.Windows or val == Enum.Platform.Android or val == Enum.Platform.IOS then
                    return Enum.Platform.XBoxOne
                end
            elseif DeviceSpoof == "PC" then
                if val == Enum.Platform.Android or val == Enum.Platform.IOS then
                    return Enum.Platform.Windows
                end
            end
        elseif tVal == "table" then
            for k, v in pairs(val) do
                val[k] = deepSpoof(v)
            end
        end
        return val
    end

    -- Pre-cache device remote references for fast comparison in hooks
    -- (avoids pcall + string comparison on every FireServer call)
    local _cachedDeviceRemotes = {}
    local _deviceEmojiMap = {
        Mobile = "\240\159\147\177",   -- 📱
        PC = "\240\159\146\187",       -- 💻
        Console = "\240\159\142\174",  -- 🎮
    }
    task.spawn(function()
        pcall(function()
            local RS = game:GetService("ReplicatedStorage")
            -- Pattern B: DeviceUpdateEvent
            local overhead = RS:FindFirstChild("Overhead")
            if overhead then
                local de = overhead:FindFirstChild("DeviceUpdateEvent")
                if de then _cachedDeviceRemotes[de] = "DeviceUpdateEvent" end
            end
            local de2 = RS:FindFirstChild("DeviceUpdateEvent")
            if de2 then _cachedDeviceRemotes[de2] = "DeviceUpdateEvent" end
            -- Pattern C: DeviceDetected
            local dd = RS:FindFirstChild("DeviceDetected")
            if dd then _cachedDeviceRemotes[dd] = "DeviceDetected" end
        end)
    end)
    
    -- Cache WindowFocusReleased signal for Anti-Tab Detect
    local _focusReleasedSignal = nil
    pcall(function()
        local UIS = game:GetService("UserInputService")
        _focusReleasedSignal = UIS.WindowFocusReleased
    end)
    
    -- Hook __index to handle Spoofing AND Polyfills
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if not checkcaller() then
            -- POLYFILL: Fix broken game scripts that use deprecated 'FindChild'
            if key == "FindChild" then return self.FindFirstChild end
            
            if SpoofEnabled then
                -- Handle UserInputService Spoofing
                if self == UIS then
                    if DeviceSpoof == "Mobile" then
                        if key == "TouchEnabled" then return true end
                        if key == "KeyboardEnabled" then return true end   -- Tetap true agar WASD movement tetap jalan!
                        if key == "MouseEnabled" then return true end      -- Tetap true agar mouse camera tetap jalan!
                        if key == "GamepadEnabled" then return false end
                        if key == "AccelerometerEnabled" then return true end
                        if key == "GyroscopeEnabled" then return true end
                        if key == "MagnetometerEnabled" then return true end
                    elseif DeviceSpoof == "PC" then
                        if key == "TouchEnabled" or key == "KeyboardEnabled" or key == "MouseEnabled" then return true end
                    elseif DeviceSpoof == "Console" then
                        if key == "TouchEnabled" then return false end
                        if key == "GamepadEnabled" then return true end
                    end
                    -- ANTI-TAB DETECT (Polling): Always return true for focus checks
                    if AntiTabDetect and key == "IsWindowFocused" then
                        return function() return true end
                    end

                    -- ANTI-AFK: Spoof Last Input Time to current time
                    if AntiTabDetect and key == "GetLastInputTime" then
                        return function() return tick() end
                    end
                end
                
                -- Detect GetAttribute via indexing (rare but possible)
                if key == "GetAttribute" then
                    return function(inst, name)
                        local val = oldNamecall(inst, "GetAttribute", name)
                        if name == "Device" or name == "Platform" or name == "DeviceType" then
                            if DeviceSpoof == "Mobile" then return "Mobile" end
                            if DeviceSpoof == "PC" then return "PC" end
                            if DeviceSpoof == "Console" then return "Console" end
                        end
                        return val
                    end
                end

                -- Handle Camera Spoofing (ViewportSize for Mobile identification)
                if DeviceSpoof == "Mobile" and self:IsA("Camera") and key == "ViewportSize" then
                    return Vector2.new(896, 414)
                end
            end
        end
        return oldIndex(self, key)
    end)
    
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = { ... }
        local argCount = select("#", ...)
        
        if not checkcaller() then
            -- ANTI-TAB DETECT: Block game connections and RemoteEvents
            if AntiTabDetect then
                if (method == "Connect" or method == "connect") and self == _focusReleasedSignal then
                    return {
                        Connected = true,
                        Disconnect = function(s) if type(s) == "table" then s.Connected = false end end,
                        disconnect = function(s) if type(s) == "table" then s.Connected = false end end,
                    }
                end

                -- Block specific function calls that detect focus
                if method == "IsWindowFocused" then return true end
                if method == "GetLastInputTime" then return tick() end

                -- BLOCK AFK REMOTES: Prevent game from telling server we are tab-out
                if method == "FireServer" or method == "InvokeServer" then
                    local nm = ""
                    pcall(function() nm = self.Name:lower() end)
                    if nm:find("afk") or nm:find("focus") or nm:find("tab") or nm:find("idle") or nm:find("activity") or nm:find("status") then
                        return -- Do nothing, block the request!
                    end
                end

                -- BLOCK ATTRIBUTE SETTING: Prevent game from setting AFK attribute
                if method == "SetAttribute" then
                    local attr = tostring(args[1]):lower()
                    if attr:find("afk") or attr:find("focus") or attr:find("tab") or attr:find("idle") then
                        return -- Block attribute change
                    end
                end
            end
            
            -- POLYFILL: Fix broken 'FindChild'
            if method == "FindChild" then
                setnamecallmethod("FindFirstChild")
                return oldNamecall(self, ...)
            end
        
            if SpoofEnabled then
                -- 0. DEVICE REMOTE INTERCEPT (highest priority, FAST path)
                -- Uses cached reference comparison instead of pcall+string match
                if method == "FireServer" and DeviceSpoof ~= "Default" then
                    local remoteType = _cachedDeviceRemotes[self]
                    if remoteType == "DeviceUpdateEvent" then
                        local spoofVal = (DeviceSpoof == "Mobile") and "Phone" or 
                                         (DeviceSpoof == "PC") and "Computer" or DeviceSpoof
                        return oldNamecall(self, spoofVal)
                    elseif remoteType == "DeviceDetected" then
                        return oldNamecall(self, _deviceEmojiMap[DeviceSpoof] or _deviceEmojiMap.PC)
                    end
                end
                
                -- 1. REMOTE SPOOFING with correct argument preservation
                if method == "FireServer" or method == "InvokeServer" then
                    local changed = false
                    for i = 1, argCount do
                        local spoofed = deepSpoof(args[i])
                        if spoofed ~= args[i] then
                            args[i] = spoofed
                            changed = true
                        end
                    end
                    if changed then
                        return oldNamecall(self, unpack(args, 1, argCount))
                    end
                end

                -- 2. ATTRIBUTE SPOOFING (READ)
                if method == "GetAttribute" then
                    local name = args[1]
                    local nameLower = name and name:lower() or ""
                    if nameLower == "device" or nameLower == "platform" or nameLower == "devicetype" or
                       nameLower == "inputtype" or nameLower == "playerdevice" or nameLower == "playerplatform" then
                        if DeviceSpoof == "Mobile" then return "Mobile" end
                        if DeviceSpoof == "PC" then return "PC" end
                        if DeviceSpoof == "Console" then return "Console" end
                    end
                end

                -- 2b. ATTRIBUTE SPOOFING (WRITE) — intercept SetAttribute
                -- SMART: Jangan ganti value yang SUDAH cocok dengan target device!
                -- Game pakai term sendiri ("Phone" bukan "Mobile") — kita harus biarkan!
                if method == "SetAttribute" then
                    local name = args[1]
                    local nameLower = name and name:lower() or ""
                    if nameLower == "device" or nameLower == "platform" or nameLower == "devicetype" or
                       nameLower == "inputtype" or nameLower == "playerdevice" or nameLower == "playerplatform" then
                        
                        local currentVal = tostring(args[2])
                        local valueCategory = getDeviceCategory(currentVal)
                        
                        -- Learn game's terminology
                        learnGameTerm(currentVal)
                        
                        if valueCategory == DeviceSpoof then
                            -- Value sudah cocok dengan target! (misal "Phone" = Mobile)
                            -- BIARKAN LEWAT tanpa modifikasi
                            print("[StarSpace] SetAttribute '" .. name .. "' = '" .. currentVal .. "' ✅ (matches target " .. DeviceSpoof .. ")")
                            return oldNamecall(self, ...)
                        elseif valueCategory then
                            -- Value untuk device LAIN → ganti ke term game untuk target
                            local targetTerm = getGameTermForTarget()
                            args[2] = targetTerm
                            print("[StarSpace] SetAttribute '" .. name .. "': '" .. currentVal .. "' → '" .. targetTerm .. "'")
                            return oldNamecall(self, unpack(args, 1, argCount))
                        end
                        -- Jika value tidak dikenali, ganti ke DeviceSpoof langsung
                        args[2] = getGameTermForTarget()
                        return oldNamecall(self, unpack(args, 1, argCount))
                    end
                end

                -- 3. CORE SERVICE SPOOFING
                if self == GS and method == "IsTenFootInterface" then
                    return DeviceSpoof == "Console"
                elseif self == UIS then
                    if method == "GetPlatform" then
                        if DeviceSpoof == "Mobile" then return Enum.Platform.Android end
                        if DeviceSpoof == "PC" then return Enum.Platform.Windows end
                        if DeviceSpoof == "Console" then return Enum.Platform.XBoxOne end
                    elseif method == "GetLastInputType" then
                        if DeviceSpoof == "Mobile" then return Enum.UserInputType.Touch end
                        if DeviceSpoof == "PC" then 
                            local realInput = oldNamecall(self, ...)
                            if realInput == Enum.UserInputType.Touch then return realInput end
                            return Enum.UserInputType.Keyboard 
                        end
                        if DeviceSpoof == "Console" then return Enum.UserInputType.Gamepad1 end
                    elseif method == "GetConnectedGamepads" then
                        if DeviceSpoof == "Mobile" or DeviceSpoof == "PC" then return {} 
                        elseif DeviceSpoof == "Console" then return {{}} end
                    elseif method == "GetSupportedGamepadKeyCodes" then
                        if DeviceSpoof == "Console" then
                            return {Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB}
                        else return {} end
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    
    -- FAKE ENVIRONMENT: Create TouchGui if Mobile spoofing
    if DeviceSpoof == "Mobile" then
        task.spawn(function()
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
    
    -- ============================================
    -- CRITICAL: Override "GetDevice" RemoteFunction
    -- Game server memanggil GetDevice:InvokeClient() 
    -- untuk menanyakan device player.
    -- Kita override OnClientInvoke agar return sesuai spoof!
    -- ============================================
    task.spawn(function()
        local RS = game:GetService("ReplicatedStorage")
        local getDevice = RS:FindFirstChild("GetDevice")
        if not getDevice then
            getDevice = RS:WaitForChild("GetDevice", 5)
        end
        
        if getDevice and getDevice:IsA("RemoteFunction") then
            -- Override callback! Ketika server tanya "device apa?", kita jawab spoofed
            getDevice.OnClientInvoke = function()
                if SpoofEnabled and DeviceSpoof ~= "Default" then
                    if DeviceSpoof == "Mobile" then
                        print("[StarSpace] 🎯 GetDevice invoked by server → returning TRUE (Phone)")
                        return true  -- true = Phone dalam logic game
                    elseif DeviceSpoof == "PC" then
                        print("[StarSpace] 🎯 GetDevice invoked by server → returning FALSE (Computer)")
                        return false -- false = Computer dalam logic game
                    elseif DeviceSpoof == "Console" then
                        print("[StarSpace] 🎯 GetDevice invoked by server → returning FALSE (Computer/Console)")
                        return false
                    end
                end
                -- Default: return berdasarkan actual device (spoofed UIS)
                local isMobile = UIS.TouchEnabled and not UIS.GamepadEnabled
                if isMobile then
                    local cam = workspace.CurrentCamera
                    if cam then
                        local vp = cam.ViewportSize
                        if vp.X < vp.Y or vp.X < 800 then
                            return true
                        end
                    end
                    local lastInput = UIS:GetLastInputType()
                    if lastInput == Enum.UserInputType.Touch then
                        return true
                    end
                    if UIS.TouchEnabled and not (UIS.MouseEnabled or UIS.KeyboardEnabled) then
                        return true
                    end
                end
                return false
            end
            
            -- Juga set attribute langsung
            if SpoofEnabled and DeviceSpoof ~= "Default" then
                local deviceVal = (DeviceSpoof == "Mobile") and "Phone" or "Computer"
                lp:SetAttribute("Device", deviceVal)
                print("[StarSpace] 🎯 GetDevice hooked! Attribute set to:", deviceVal)
            end
        else
            print("[StarSpace] ⚠️ GetDevice RemoteFunction not found in this game")
        end
    end)

    HooksApplied = true
    if _G.StarSpace and _G.StarSpace.DebugSpoof then
        print("[StarSpace] Device Hooks Applied Successfully!")
    end
end

-- ============================================
-- PROACTIVE DEVICE SPOOF
-- Override attribute, StringValue, dan fire device remotes
-- agar data yang ter-replicate ke server = spoofed device
-- ============================================
local DEVICE_ATTR_NAMES = {
    "Device", "Platform", "DeviceType", "InputType", 
    "PlayerDevice", "PlayerPlatform", "device", "platform",
    "deviceType", "inputType", "playerDevice"
}
local DEVICE_VALUE_KEYWORDS = {"device", "platform", "inputtype", "devicetype"}
local DEVICE_REMOTE_KEYWORDS = {
    "device", "platform", "setdevice", "updatedevice", 
    "setplatform", "inputtype", "playerdevice", "setinput"
}

local function proactiveDeviceSpoof()
    if not SpoofEnabled or DeviceSpoof == "Default" then return end
    local lp = game.Players.LocalPlayer
    if not lp then return end
    
    -- Gunakan term game ("Phone"/"Computer") bukan generic ("Mobile"/"PC")
    local spoofVal = (DeviceSpoof == "Mobile") and "Phone" or 
                     (DeviceSpoof == "PC") and "Computer" or DeviceSpoof
    
    -- Collect targets
    local targets = {lp}
    if lp.Character then
        table.insert(targets, lp.Character)
        local hum = lp.Character:FindFirstChildOfClass("Humanoid")
        if hum then table.insert(targets, hum) end
        local head = lp.Character:FindFirstChild("Head")
        if head then table.insert(targets, head) end
    end
    
    -- 1. Override device attributes
    for _, target in ipairs(targets) do
        for _, attrName in ipairs(DEVICE_ATTR_NAMES) do
            pcall(function()
                local existing = target:GetAttribute(attrName)
                if existing ~= nil then
                    target:SetAttribute(attrName, spoofVal)
                end
            end)
        end
    end
    -- Always set "Device" attribute on player
    pcall(function() lp:SetAttribute("Device", spoofVal) end)
    
    -- 2. Game-specific remote overrides
    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        
        -- ==============================================
        -- PATTERN A: "GetDevice" RemoteFunction (game tanya client)
        -- Server calls GetDevice:InvokeClient() → client return true/false
        -- ==============================================
        local getDevice = RS:FindFirstChild("GetDevice")
        if getDevice and getDevice:IsA("RemoteFunction") then
            getDevice.OnClientInvoke = function()
                if DeviceSpoof == "Mobile" then return true end
                return false
            end
        end
        
        -- ==============================================
        -- PATTERN B: "DeviceUpdateEvent" RemoteEvent (client kirim ke server)
        -- Client fires DeviceUpdateEvent:FireServer("Phone"/"Computer"/"Console")
        -- Server terima dan update icon untuk semua orang!
        -- INI YANG BIKIN FE SPOOFING BISA BERHASIL!
        -- ==============================================
        local overhead = RS:FindFirstChild("Overhead")
        if overhead then
            local deviceEvent = overhead:FindFirstChild("DeviceUpdateEvent")
            if deviceEvent and deviceEvent:IsA("RemoteEvent") then
                deviceEvent:FireServer(spoofVal)
                print("[StarSpace] 🎯 DeviceUpdateEvent fired:", spoofVal, "→ SERVER UPDATED!")
            end
            
            -- Override DeviceRequestFunction juga (server request device data)
            local deviceReq = overhead:FindFirstChild("DeviceRequestFunction")
            if deviceReq and deviceReq:IsA("RemoteFunction") then
                deviceReq.OnClientInvoke = function()
                    return spoofVal
                end
            end
        end
        
        -- Fallback: scan ReplicatedStorage root untuk DeviceUpdateEvent
        local devEvent = RS:FindFirstChild("DeviceUpdateEvent")
        if devEvent and devEvent:IsA("RemoteEvent") then
            devEvent:FireServer(spoofVal)
            print("[StarSpace] 🎯 DeviceUpdateEvent (root) fired:", spoofVal)
        end
        
        -- ==============================================
        -- PATTERN C: "DeviceDetected" RemoteEvent (emoji-based)
        -- Client fires DeviceDetected:FireServer("📱"/"💻"/"🎮")
        -- ==============================================
        local deviceDetected = RS:FindFirstChild("DeviceDetected")
        if deviceDetected and deviceDetected:IsA("RemoteEvent") then
            local emojiMap = {
                Mobile = "\240\159\147\177",   -- 📱
                PC = "\240\159\146\187",       -- 💻
                Console = "\240\159\142\174",  -- 🎮
            }
            local spoofEmoji = emojiMap[DeviceSpoof] or emojiMap.PC
            deviceDetected:FireServer(spoofEmoji)
            print("[StarSpace] 🎯 DeviceDetected fired:", DeviceSpoof, "→ SERVER UPDATED!")
        end
    end)
    
    -- 3. Override StringValues with device-related names
    local function scanValues(parent)
        pcall(function()
            for _, child in pairs(parent:GetDescendants()) do
                if child:IsA("StringValue") then
                    local nameLower = child.Name:lower()
                    for _, kw in ipairs(DEVICE_VALUE_KEYWORDS) do
                        if nameLower:find(kw) then
                            pcall(function() child.Value = spoofVal end)
                            break
                        end
                    end
                end
            end
        end)
    end
    pcall(function() scanValues(lp) end)
    if lp.Character then pcall(function() scanValues(lp.Character) end) end
    
    -- 4. Watch attribute changes (prevent server reset)
    if lp.Character then
        for _, target in ipairs(targets) do
            pcall(function()
                if target:GetAttribute("Device") ~= nil then
                    local conn = target:GetAttributeChangedSignal("Device"):Connect(function()
                        if SpoofEnabled and DeviceSpoof ~= "Default" then
                            local current = target:GetAttribute("Device")
                            local TERM_MAP = {
                                computer="PC", phone="Mobile", console="Console"
                            }
                            local cat = TERM_MAP[tostring(current):lower()]
                            if cat and cat ~= DeviceSpoof then
                                pcall(function() target:SetAttribute("Device", spoofVal) end)
                            end
                        end
                    end)
                    if _G.StarSpace and _G.StarSpace.SpoofConnections then
                        table.insert(_G.StarSpace.SpoofConnections, conn)
                    end
                end
            end)
        end
    end
end

-- ============================================
-- EARLY HOOK APPLICATION
-- Hooks dipasang saat saved settings terdeteksi.
-- Ini membantu spoofing LOKAL dan beberapa game yang
-- detect device dari CLIENT (via GetDevice RemoteFunction).
-- NOTE: Game yang detect via server-side player:GetPlatform()
-- TIDAK bisa di-spoof dari client — ini limitasi Roblox.
-- ============================================
if SpoofEnabled and DeviceSpoof ~= "Default" then
    ApplyPrivacyHooks()
    task.spawn(function()
        task.wait(1)
        proactiveDeviceSpoof()
    end)
    print("[StarSpace] Hooks applied from saved settings (Device: " .. DeviceSpoof .. ")")
end

Tools:AddDropdown("Device Spoofing", {Options = {"Default", "PC", "Mobile", "Console"}, Default = DeviceSpoof}, function(v)
    local previousDevice = DeviceSpoof
    DeviceSpoof = v
    saveSpoofSettings()
    
    if SpoofEnabled then
        ApplyPrivacyHooks()
        
        -- Re-spoof confirmed device elements locally
        if _G.StarSpace and _G.StarSpace.DeviceElements then
            for obj, _ in pairs(_G.StarSpace.DeviceElements) do
                if typeof(obj) == "Instance" and obj.Parent then
                    pcall(spoof, obj)
                end
            end
        end
        
        if v ~= "Default" and v ~= previousDevice then
            -- Prompt respawn agar visual spoof ter-apply ke karakter baru
            UI.Confirm("Respawn untuk Apply?", 
                "Respawn karakter agar icon device '" .. v .. "' ter-update?\n\nSettings tersimpan otomatis.", 
                function()
                    local lp = game.Players.LocalPlayer
                    if lp and lp.Character then
                        local hum = lp.Character:FindFirstChildOfClass("Humanoid")
                        if hum then hum.Health = 0 end
                    end
                end)
        end
        
        UI.Slide("Privacy", "Device spoof updated: " .. v)
    end
end)

-- ============================================
-- REVERSE ENGINEERING: Scan & Decompile Device Scripts
-- Temukan script yang handle device detection di game ini
-- ============================================
Tools:AddRetroButton({Name = "🔍 Reverse Device Script", Callback = function()
    UI.Slide("Privacy", "Scanning game scripts...")
    
    task.spawn(function()
        local lp = game.Players.LocalPlayer
        local results = {}
        local deviceScripts = {}
        local allRemotes = {}
        
        local deviceKeywords = {"device", "platform", "overhead", "nametag", "name_tag", "billboard", "headtag", "icon", "indicator"}
        
        -- ==========================================
        -- STEP 1: Find device-related scripts
        -- ==========================================
        print("\n[REVERSE] ==========================================")
        print("[REVERSE] STEP 1: Scanning for device-related scripts")
        print("[REVERSE] ==========================================")
        
        local scriptLocations = {}
        -- Scan StarterPlayerScripts
        pcall(function()
            for _, s in pairs(game:GetService("StarterPlayer"):GetDescendants()) do
                if s:IsA("LocalScript") or s:IsA("ModuleScript") then
                    table.insert(scriptLocations, s)
                end
            end
        end)
        -- Scan StarterGui
        pcall(function()
            for _, s in pairs(game:GetService("StarterGui"):GetDescendants()) do
                if s:IsA("LocalScript") or s:IsA("ModuleScript") then
                    table.insert(scriptLocations, s)
                end
            end
        end)
        -- Scan PlayerGui (runtime)
        pcall(function()
            for _, s in pairs(lp.PlayerGui:GetDescendants()) do
                if s:IsA("LocalScript") or s:IsA("ModuleScript") then
                    table.insert(scriptLocations, s)
                end
            end
        end)
        -- Scan ReplicatedStorage
        pcall(function()
            for _, s in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
                if s:IsA("ModuleScript") then
                    table.insert(scriptLocations, s)
                end
            end
        end)
        -- Scan character (overhead scripts)
        pcall(function()
            if lp.Character then
                for _, s in pairs(lp.Character:GetDescendants()) do
                    if s:IsA("LocalScript") or s:IsA("ModuleScript") then
                        table.insert(scriptLocations, s)
                    end
                end
            end
        end)
        -- Scan ALL players' characters for overhead scripts
        pcall(function()
            for _, player in pairs(game.Players:GetPlayers()) do
                if player.Character then
                    for _, s in pairs(player.Character:GetDescendants()) do
                        if s:IsA("LocalScript") or s:IsA("ModuleScript") then
                            table.insert(scriptLocations, s)
                        end
                    end
                end
            end
        end)
        
        -- Filter scripts by name keywords
        for _, script in ipairs(scriptLocations) do
            local nameLower = script.Name:lower()
            local pathLower = script:GetFullName():lower()
            local isRelevant = false
            
            for _, kw in ipairs(deviceKeywords) do
                if nameLower:find(kw) or pathLower:find(kw) then
                    isRelevant = true
                    break
                end
            end
            
            if isRelevant then
                table.insert(deviceScripts, script)
                print("[REVERSE] 📜 Found relevant script:", script:GetFullName(), "(" .. script.ClassName .. ")")
            end
        end
        
        -- Jika tidak ada yang ditemukan via keyword, scan SEMUA scripts di character
        if #deviceScripts == 0 then
            print("[REVERSE] No keyword matches. Scanning ALL character scripts...")
            pcall(function()
                for _, player in pairs(game.Players:GetPlayers()) do
                    if player.Character then
                        for _, s in pairs(player.Character:GetDescendants()) do
                            if s:IsA("LocalScript") or s:IsA("ModuleScript") then
                                table.insert(deviceScripts, s)
                                print("[REVERSE] 📜 Character script:", s:GetFullName())
                            end
                        end
                    end
                end
            end)
        end
        
        -- ==========================================
        -- STEP 2: Decompile relevant scripts
        -- ==========================================
        print("\n[REVERSE] ==========================================")
        print("[REVERSE] STEP 2: Decompiling scripts")
        print("[REVERSE] ==========================================")
        
        local hasDecompile = typeof(decompile) == "function"
        if not hasDecompile then
            print("[REVERSE] ⚠️ decompile() not available in this executor!")
            print("[REVERSE] Try using: getscriptbytecode() or saveinstance()")
        end
        
        for i, script in ipairs(deviceScripts) do
            if i > 5 then 
                print("[REVERSE] (Showing first 5 scripts only)")
                break 
            end
            
            print("\n[REVERSE] ────────────────────────────────")
            print("[REVERSE] Script:", script:GetFullName())
            print("[REVERSE] Type:", script.ClassName)
            
            if hasDecompile then
                local ok, source = pcall(decompile, script)
                if ok and source then
                    -- Simpan ke file untuk review
                    local fileName = "StarSpace/reverse_" .. script.Name:gsub("[^%w]", "_") .. ".lua"
                    pcall(function() writefile(fileName, source) end)
                    print("[REVERSE] ✅ Decompiled! Saved to:", fileName)
                    
                    -- Cari keyword penting di source
                    local importantLines = {}
                    for line in source:gmatch("[^\n]+") do
                        local lineLower = line:lower()
                        if lineLower:find("device") or lineLower:find("platform") or 
                           lineLower:find("phone") or lineLower:find("computer") or
                           lineLower:find("mobile") or lineLower:find("setattribute") or
                           lineLower:find("fireserver") or lineLower:find("invokeserver") or
                           lineLower:find("getplatform") or lineLower:find("touchenabled") or
                           lineLower:find("remotevent") or lineLower:find("getattribute") then
                            table.insert(importantLines, line)
                        end
                    end
                    
                    if #importantLines > 0 then
                        print("[REVERSE] 🔑 IMPORTANT LINES FOUND:")
                        for j, line in ipairs(importantLines) do
                            if j > 20 then print("[REVERSE] ... (truncated)"); break end
                            print("[REVERSE]   →", line:sub(1, 200))
                        end
                    else
                        print("[REVERSE] (No device-related lines found in this script)")
                    end
                else
                    print("[REVERSE] ❌ Failed to decompile:", tostring(source))
                end
            end
        end
        
        -- ==========================================
        -- STEP 3: List ALL RemoteEvents/RemoteFunctions
        -- ==========================================
        print("\n[REVERSE] ==========================================")
        print("[REVERSE] STEP 3: All RemoteEvents in game")
        print("[REVERSE] ==========================================")
        
        local remoteCount = 0
        local searchAreas = {
            game:GetService("ReplicatedStorage"),
        }
        pcall(function() table.insert(searchAreas, game:GetService("ReplicatedFirst")) end)
        
        for _, area in ipairs(searchAreas) do
            pcall(function()
                for _, obj in pairs(area:GetDescendants()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        remoteCount = remoteCount + 1
                        local marker = ""
                        local nameLower = obj.Name:lower()
                        for _, kw in ipairs(deviceKeywords) do
                            if nameLower:find(kw) then marker = " ⭐ DEVICE RELATED!"; break end
                        end
                        print("[REVERSE] 📡", obj.ClassName .. ":", obj:GetFullName() .. marker)
                    end
                end
            end)
        end
        print("[REVERSE] Total remotes found:", remoteCount)
        
        -- ==========================================  
        -- STEP 4: Scan BillboardGui scripts in workspace
        -- ==========================================
        print("\n[REVERSE] ==========================================")
        print("[REVERSE] STEP 4: Overhead BillboardGui analysis")
        print("[REVERSE] ==========================================")
        
        pcall(function()
            if lp.Character then
                for _, obj in pairs(lp.Character:GetDescendants()) do
                    if obj:IsA("BillboardGui") then
                        print("[REVERSE] 🏷️ BillboardGui:", obj:GetFullName())
                        for _, child in pairs(obj:GetDescendants()) do
                            if child:IsA("ImageLabel") or child:IsA("ImageButton") then
                                print("[REVERSE]   Image:", child.Name, "=", child.Image, "Size:", child.Size)
                            elseif child:IsA("TextLabel") then
                                print("[REVERSE]   Text:", child.Name, "=", child.Text)
                            end
                        end
                    end
                end
            end
        end)
        
        -- Also check other players' overheads
        pcall(function()
            for _, player in pairs(game.Players:GetPlayers()) do
                if player ~= lp and player.Character then
                    for _, obj in pairs(player.Character:GetDescendants()) do
                        if obj:IsA("BillboardGui") then
                            print("[REVERSE] 🏷️ Other player (" .. player.Name .. ") BillboardGui:", obj:GetFullName())
                            for _, child in pairs(obj:GetDescendants()) do
                                if child:IsA("ImageLabel") or child:IsA("ImageButton") then
                                    print("[REVERSE]   Image:", child.Name, "=", child.Image)
                                end
                            end
                            break -- Only first BillboardGui per player
                        end
                    end
                end
            end
        end)
        
        -- ==========================================
        -- STEP 5: Player attributes comparison
        -- ==========================================
        print("\n[REVERSE] ==========================================")
        print("[REVERSE] STEP 5: Your attrs vs Other player attrs")
        print("[REVERSE] ==========================================")
        
        -- Your attributes
        print("[REVERSE] 👤 YOU (" .. lp.Name .. "):")
        pcall(function()
            for name, val in pairs(lp:GetAttributes()) do
                print("[REVERSE]   ATTR:", name, "=", tostring(val))
            end
            if lp.Character then
                for name, val in pairs(lp.Character:GetAttributes()) do
                    print("[REVERSE]   CHAR_ATTR:", name, "=", tostring(val))
                end
            end
        end)
        
        -- Other player for comparison
        pcall(function()
            for _, player in pairs(game.Players:GetPlayers()) do
                if player ~= lp then
                    print("[REVERSE] 👥", player.Name .. ":")
                    for name, val in pairs(player:GetAttributes()) do
                        print("[REVERSE]   ATTR:", name, "=", tostring(val))
                    end
                    if player.Character then
                        for name, val in pairs(player.Character:GetAttributes()) do
                            print("[REVERSE]   CHAR_ATTR:", name, "=", tostring(val))
                        end
                    end
                    break -- Only first other player
                end
            end
        end)
        
        print("\n[REVERSE] ==========================================")
        print("[REVERSE] SCAN COMPLETE!")
        print("[REVERSE] Check file explorer for decompiled scripts")
        print("[REVERSE] Copy console output (Ctrl+A) and analyze")
        print("[REVERSE] ==========================================")
        
        UI.Slide("Privacy", "Reverse scan complete! Check console (F9)")
    end)
end})

-- Hooks moved above for accessibility

-- ============================================
-- UNIVERSAL DEVICE SPOOF SYSTEM v2.0
-- Supports: Emoji, Images, Spritesheets, Frames, Attributes, Keywords
-- ============================================

local OriginalValues = {} -- Cache untuk menyimpan nilai asli

-- ============================================
-- PER-GAME ICON DATABASE
-- Tambahkan PlaceId game dan icon-nya di sini
-- ============================================
local GameIconSets = {
    -- MT Yahayukk (multiple identifiers for reliable detection)
    ["16624148448"] = {  -- PC icon (confirmed from game scan)
        Name = "MT Yahayukk",
        PC = "rbxassetid://16624148448",
        Mobile = "rbxassetid://16624149840",
        Console = "rbxassetid://16624150956",  -- Fallback ke default
    },
    -- MT Moonlight (identifier = salah satu asset ID yang dipakai game ini)
    ["94089970073947"] = {  -- <-- Phone icon
        Name = "MT Moonlight",
        PC = "rbxassetid://106290076073871",
        Mobile = "rbxassetid://94089970073947",
        Console = "rbxassetid://139663456027187",
    },
    ["106290076073871"] = {  -- <-- Computer icon (same game, extra identifier)
        Name = "MT Moonlight",
        PC = "rbxassetid://106290076073871",
        Mobile = "rbxassetid://94089970073947",
        Console = "rbxassetid://139663456027187",
    },
    ["139663456027187"] = {  -- <-- Console icon (same game, extra identifier)
        Name = "MT Moonlight",
        PC = "rbxassetid://106290076073871",
        Mobile = "rbxassetid://94089970073947",
        Console = "rbxassetid://139663456027187",
    },
     -- MT Velora (identifier = salah satu asset ID yang dipakai game ini)
    ["110487074518360"] = {  -- <-- HARUS sama dengan salah satu icon di bawah
        Name = "MT Velora",
        PC = "rbxassetid://133663694484547",
        Mobile = "rbxassetid://110487074518360",
        Console = "rbxassetid://6034509537",
    },
    -- Game dengan NameTag overhead (Humanoid.NameTag.Frame.icons.DeviceIcon)
    ["6034789893"] = {
        Name = "NameTag Game (Generic)",
        PC = "rbxassetid://6034789893",
        Mobile = "rbxassetid://6034848733",
        Console = "rbxassetid://6034509537",
    },
    -- Tambahkan game lain di sini...
    -- Game (User Requested)
    ["12684119225"] = {
        Name = "Game (User Requested)",
        PC = "rbxassetid://12684119225",
        Mobile = "rbxassetid://13021320268",
        Console = "rbxassetid://6034509537",
    },
}

-- Default icons (fallback)
local DefaultIcons = {
    PC = "rbxassetid://6034509993",
    Mobile = "rbxassetid://6034509012",
    Console = "rbxassetid://6034509537",
}

-- Auto-detect game icon set berdasarkan icon yang terlihat di game
local DetectedGameSet = nil

local function detectGameIconSet(imageId)
    -- Jangan cache terlalu awal, biarkan re-detect setiap kali
    if not imageId or imageId == "" then return nil end
    
    if _G.StarSpace and _G.StarSpace.DebugSpoof then
        print("[DeviceSpoof Debug] Checking image:", imageId)
    end
    
    -- Method 1: Cari di reverse lookup table (exact match, lebih reliable)
    local lowerImage = imageId:lower()
    if AssetToIconSet[lowerImage] then
        local found = AssetToIconSet[lowerImage]
        if not DetectedGameSet or DetectedGameSet.Name ~= found.Name then
            print("[StarSpace] Detected game icon set (exact):", found.Name)
        end
        DetectedGameSet = found
        return found
    end
    
    -- Method 2: Cari identifier di GameIconSets (partial match via string.find)
    for identifier, iconSet in pairs(GameIconSets) do
        if imageId:find(identifier, 1, true) then -- plain find, no pattern
            if not DetectedGameSet or DetectedGameSet.Name ~= iconSet.Name then
                print("[StarSpace] Detected game icon set (partial):", iconSet.Name)
            end
            DetectedGameSet = iconSet
            return iconSet
        end
    end
    
    return DetectedGameSet -- Return last detected jika tidak match
end

-- Build reverse lookup table: asset ID -> icon set
local AssetToIconSet = {}
for identifier, iconSet in pairs(GameIconSets) do
    -- Map all icons from this set
    AssetToIconSet[iconSet.PC:lower()] = iconSet
    AssetToIconSet[iconSet.Mobile:lower()] = iconSet
    AssetToIconSet[iconSet.Console:lower()] = iconSet
end

-- Improved detection: exact match via lookup table
local function getIconSetFromAsset(imageId)
    if not imageId or imageId == "" then return nil end
    return AssetToIconSet[imageId:lower()]
end

-- Device data structure (untuk emoji dan keywords)
local DeviceAssets = {
    PC = {
        Emojis = {"💻", "🖥️", "🖥", "⌨️", "🖱️"},
        Keywords = {"pc", "computer", "desktop", "windows", "keyboard"},
        TargetEmoji = "💻"
    },
    Mobile = {
        Emojis = {"📱", "📲", "🤳"},
        Keywords = {"mobile", "phone", "touch", "ios", "android", "iphone", "ipad", "tablet"},
        TargetEmoji = "📱"
    },
    Console = {
        Emojis = {"🎮", "🕹️", "🎲"},
        Keywords = {"console", "xbox", "playstation", "gamepad", "controller", "ps4", "ps5"},
        TargetEmoji = "🎮"
    }
}

-- Helper: Get target image (auto-detect atau pakai default)
local function getTargetImage(deviceType, currentImage)
    -- Method 1: Exact match via lookup table
    local gameSet = getIconSetFromAsset(currentImage)
    if gameSet and gameSet[deviceType] then
        return gameSet[deviceType]
    end
    
    -- Method 2: Partial match via pattern detection
    gameSet = detectGameIconSet(currentImage)
    if gameSet and gameSet[deviceType] then
        return gameSet[deviceType]
    end
    
    -- Method 3: Fallback ke default
    return DefaultIcons[deviceType]
end

-- All device emojis for replacement
local AllDeviceEmojis = {}
for _, data in pairs(DeviceAssets) do
    for _, emoji in ipairs(data.Emojis) do
        AllDeviceEmojis[emoji] = true
    end
end

-- Common spritesheet offsets (game-agnostic patterns)
local CommonSpritePatterns = {
    -- Pattern: {PC_Offset, Mobile_Offset, Console_Offset}
    Horizontal32 = {PC = Vector2.new(0, 0), Mobile = Vector2.new(32, 0), Console = Vector2.new(64, 0)},
    Horizontal24 = {PC = Vector2.new(0, 0), Mobile = Vector2.new(24, 0), Console = Vector2.new(48, 0)},
    Horizontal16 = {PC = Vector2.new(0, 0), Mobile = Vector2.new(16, 0), Console = Vector2.new(32, 0)},
    Vertical32 = {PC = Vector2.new(0, 0), Mobile = Vector2.new(0, 32), Console = Vector2.new(0, 64)},
}

-- Detection keywords untuk identifikasi elemen device (KETAT)
local DeviceDetectionPatterns = {
    -- Nama element yang PASTI device indicator (case-insensitive, jadi tidak perlu "ActiveIcon")
    Names = {"deviceicon", "deviceindicator", "platformicon", "activetype", "inputicon", "activeicon"},
    -- Parent yang PASTI overhead/playerlist (termasuk berbagai game structures)
    Parents = {"overhead", "_overhead", "overheadui", "billboard", "nametag", "playertag", "headtag", "toprow", "line1", "deviceframe", "logoframe"},
    -- Hanya class yang ada di atas kepala player
    Classes = {"BillboardGui", "SurfaceGui"}
}

-- Blacklist: Jangan pernah modify element dari UI ini
local UIBlacklist = {
    "starspace", "xan", "rayfield", "kavo", "orion", "ventox", "wally", "infinite", 
    "catalyst", "linoria", "sense", "vape", "lunar", "solara", "arctic"
}

-- Helper: Check if string contains any keyword
local function containsKeyword(str, keywords)
    if not str then return false end
    str = str:lower()
    for _, keyword in ipairs(keywords) do
        if str:find(keyword) then return true end
    end
    return false
end

-- Helper: Check if object is part of a blacklisted UI (StarSpace, dll)
local function isBlacklistedUI(obj)
    -- Exception: jika obj ada di dalam BillboardGui/SurfaceGui, itu bisa jadi game overhead
    -- yang di-clone ke CoreGui — jangan blacklist!
    local hasBillboard = obj:FindFirstAncestorOfClass("BillboardGui") or obj:FindFirstAncestorOfClass("SurfaceGui")
    
    local current = obj
    for i = 1, 10 do
        if not current then break end
        local name = current.Name:lower()
        for _, blacklisted in ipairs(UIBlacklist) do
            if name:find(blacklisted) then return true end
        end
        -- Also check if it's a ScreenGui (UI window, bukan game UI)
        if current:IsA("ScreenGui") then
            -- ScreenGui di CoreGui biasanya UI exploit, KECUALI yang punya BillboardGui (game overhead)
            if current.Parent and current.Parent.Name == "CoreGui" and not hasBillboard then
                return true
            end
        end
        current = current.Parent
    end
    return false
end

-- Helper: Check if object belongs to LocalPlayer (Character or PlayerGui)
local function isOwnedByLocalPlayer(obj)
    local lp = game.Players.LocalPlayer
    if not lp then return false end
    
    local myChar = lp.Character
    local myPlayerGui = lp:FindFirstChild("PlayerGui")
    
    -- Check if it's in PlayerGui
    if myPlayerGui and obj:IsDescendantOf(myPlayerGui) then
        return true
    end
    
    -- Check if it's in Character
    if myChar and (obj:IsDescendantOf(myChar) or obj == myChar) then
        return true
    end
    
    -- Check if it's adorned to Character (e.g. BillboardGui in another container)
    local rootGui = obj:FindFirstAncestorOfClass("BillboardGui") or obj:FindFirstAncestorOfClass("SurfaceGui")
    if rootGui and rootGui.Adornee and myChar and rootGui.Adornee:IsDescendantOf(myChar) then
        return true
    end
    
    return false
end

-- Helper: Check if object is TRULY a device display element
local function isDeviceRelated(obj)
    -- PERTAMA: Pastikan ini milik LocalPlayer (agar tidak mengubah icon orang lain)
    if not isOwnedByLocalPlayer(obj) then
        return false
    end
    
    -- PERTAMA: Cek blacklist - jika bagian dari UI exploit, SKIP!
    if isBlacklistedUI(obj) then
        if _G.StarSpace and _G.StarSpace.DebugSpoof then
            print("[DeviceSpoof Debug] BLACKLISTED:", obj:GetFullName())
        end
        return false
    end
    
    -- NEW: Jika image cocok dengan GameIconSets, langsung return true!
    -- Ini bypass semua check lain karena kita TAHU ini icon device
    if (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and obj.Image ~= "" then
        local imgLower = obj.Image:lower()
        if AssetToIconSet[imgLower] then
            if _G.StarSpace and _G.StarSpace.DebugSpoof then
                print("[DeviceSpoof Debug] MATCH via GameIconSets:", obj:GetFullName(), "Image:", obj.Image)
            end
            return true
        end
        -- Also check partial match against identifiers
        for identifier, _ in pairs(GameIconSets) do
            if obj.Image:find(identifier, 1, true) then
                if _G.StarSpace and _G.StarSpace.DebugSpoof then
                    print("[DeviceSpoof Debug] MATCH via identifier:", obj:GetFullName(), "ID:", identifier)
                end
                return true
            end
        end
    end
    
    -- KEDUA: Cek apakah ada di dalam BillboardGui atau SurfaceGui (overhead di atas kepala)
    local billboard = obj:FindFirstAncestorOfClass("BillboardGui")
    local surface = obj:FindFirstAncestorOfClass("SurfaceGui")
    
    -- KETIGA: Cek pattern workspace.Player.Head.XXX_Overhead (langsung di-parent ke Head)
    local headAncestor = obj:FindFirstAncestor("Head")
    if headAncestor and headAncestor:IsA("BasePart") then
        -- Ini ada di dalam Head part - kemungkinan overhead!
        -- Cek apakah ada parent dengan nama "overhead" atau device-related
        local parent = obj.Parent
        for i = 1, 5 do
            if not parent or parent == headAncestor then break end
            local pName = parent.Name:lower()
            if containsKeyword(pName, DeviceDetectionPatterns.Parents) then
                return true -- Confirmed: ada di Head dan parent adalah overhead
            end
            parent = parent.Parent
        end
    end
    
    -- EARLY CHECK: Nama element yang PASTI device icon (sangat spesifik, aman)
    if containsKeyword(obj.Name, DeviceDetectionPatterns.Names) then
        if _G.StarSpace and _G.StarSpace.DebugSpoof then
            print("[DeviceSpoof Debug] MATCH via element name:", obj:GetFullName(), "Name:", obj.Name)
        end
        return true
    end
    
    -- EARLY CHECK: Parent keywords (nametag, overhead, dll)
    -- Ini harus dijalankan SEBELUM early return, karena beberapa game
    -- taruh overhead di Humanoid.NameTag bukan di Head/BillboardGui
    local pCheck = obj.Parent
    for i = 1, 8 do
        if not pCheck then break end
        local pName = pCheck.Name:lower()
        if containsKeyword(pName, DeviceDetectionPatterns.Parents) then
            if _G.StarSpace and _G.StarSpace.DebugSpoof then
                print("[DeviceSpoof Debug] MATCH via parent keyword:", obj:GetFullName(), "Parent:", pCheck.Name)
            end
            return true
        end
        -- Juga cek playerlist/leaderboard
        if pName:find("playerlist") or pName:find("leaderboard") then
            return true
        end
        pCheck = pCheck.Parent
    end
    
    -- Cek Humanoid ancestor (beberapa game taruh NameTag di Humanoid, bukan Head)
    local humanoidAncestor = obj:FindFirstAncestorOfClass("Humanoid")
    if humanoidAncestor then
        -- Ada di dalam Humanoid — kemungkinan overhead NameTag
        if _G.StarSpace and _G.StarSpace.DebugSpoof then
            print("[DeviceSpoof Debug] Found in Humanoid ancestor, checking name...", obj:GetFullName())
        end
        -- Sudah dicek nama di atas, tapi extra safety: cek apakah parent ada kata 'icon'
        local parentName = obj.Parent and obj.Parent.Name:lower() or ""
        if parentName:find("icon") or obj.Name:lower():find("icon") or obj.Name:lower():find("device") then
            return true
        end
    end
    
    if not billboard and not surface and not headAncestor and not humanoidAncestor then
        if _G.StarSpace and _G.StarSpace.DebugSpoof then
            print("[DeviceSpoof Debug] NOT RELATED (no billboard/head/humanoid):", obj:GetFullName())
        end
        return false
    end
    
    -- Di dalam BillboardGui/SurfaceGui - pastikan ini milik character/player
    if billboard or surface then
        local ancestor = billboard or surface
        local adornee = ancestor.Adornee
        
        -- Jika BillboardGui punya Adornee yang merupakan bagian dari character, ini overhead player
        if adornee then
            local char = adornee:FindFirstAncestorOfClass("Model")
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    return true -- Ini overhead milik player character
                end
            end
        end
        
        -- NEW: Jika BillboardGui parent-nya adalah Head (tanpa Adornee), juga valid
        if ancestor.Parent and ancestor.Parent:IsA("BasePart") and ancestor.Parent.Name == "Head" then
            return true
        end
    end
    
    -- Fallback: cek nama untuk keyword device yang spesifik
    if containsKeyword(obj.Name, DeviceDetectionPatterns.Names) then return true end
    
    -- Check parent names untuk keyword yang pasti overhead
    local parent = obj.Parent
    for i = 1, 5 do
        if not parent then break end
        if containsKeyword(parent.Name, DeviceDetectionPatterns.Parents) then return true end
        parent = parent.Parent
    end
    
    if _G.StarSpace and _G.StarSpace.DebugSpoof then
        print("[DeviceSpoof Debug] NOT RELATED (fallthrough):", obj:GetFullName())
    end
    return false
end

-- Helper: Detect spritesheet pattern from ImageRectSize
local function detectSpritePattern(rectSize)
    if not rectSize then return nil end
    local size = rectSize.X
    if size == 32 then return "Horizontal32"
    elseif size == 24 then return "Horizontal24"
    elseif size == 16 then return "Horizontal16"
    end
    return nil
end

-- Main Universal Spoof Function
local function spoof(obj)
    local lp = game.Players.LocalPlayer
    if not lp then return end
    
    -- ==========================================
    -- PATTERN 1: TEXT (Emoji & Keywords)
    -- ==========================================
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        -- Backup original
        if not OriginalValues[obj] then
            OriginalValues[obj] = {
                Text = obj.Text,
                Type = "Text"
            }
        end
        
        if SpoofEnabled then
            local currentText = OriginalValues[obj].Text
            local modified = false
            
            -- 1A. Name Spoofing (existing feature)
            if SpoofName ~= "" then
                if currentText:find(lp.Name) or currentText:find(lp.DisplayName) then
                    currentText = currentText:gsub(lp.Name, SpoofName):gsub(lp.DisplayName, SpoofName)
                    modified = true
                end
            end
            
            -- 1B. Universal Emoji Replacement (HANYA untuk element yang device-related)
            if DeviceSpoof ~= "Default" and isDeviceRelated(obj) then
                local targetEmoji = DeviceAssets[DeviceSpoof].TargetEmoji
                for emoji, _ in pairs(AllDeviceEmojis) do
                    if currentText:find(emoji) then
                        currentText = currentText:gsub(emoji, targetEmoji)
                        modified = true
                    end
                end
                
                -- 1C. Keyword-based text (e.g., "[PC]", "(Mobile)", "Desktop")
                local keywords = {
                    PC = {"PC", "Computer", "Desktop", "Windows"},
                    Mobile = {"Mobile", "Phone", "Touch", "iOS", "Android"},
                    Console = {"Console", "Xbox", "PlayStation", "Gamepad"}
                }
                
                for deviceType, words in pairs(keywords) do
                    if deviceType ~= DeviceSpoof then
                        for _, word in ipairs(words) do
                            -- Case-insensitive replacement dengan preserve case
                            local pattern = "(%[?)(" .. word .. ")(%]?)"
                            if currentText:lower():find(word:lower()) then
                                local targetWord = keywords[DeviceSpoof][1] -- Use first keyword as replacement
                                currentText = currentText:gsub(word, targetWord)
                                modified = true
                            end
                        end
                    end
                end
            end
            
            if modified and obj.Text ~= currentText then
                obj.Text = currentText
            end
        else
            -- Restore original
            if OriginalValues[obj] and obj.Text ~= OriginalValues[obj].Text then
                obj.Text = OriginalValues[obj].Text
            end
        end
    end
    
    -- ==========================================
    -- PATTERN 2: IMAGES (Single Asset & Spritesheet)
    -- ==========================================
    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        -- Backup original
        if not OriginalValues[obj] then
            OriginalValues[obj] = {
                Image = obj.Image,
                ImageRectOffset = obj.ImageRectOffset,
                ImageRectSize = obj.ImageRectSize,
                Visible = obj.Visible,
                Type = "Image"
            }
        end
        
        local isRelated = isDeviceRelated(obj)
        
        if isRelated then
            if SpoofEnabled and DeviceSpoof ~= "Default" then
                -- Pass original image untuk auto-detect game icon set
                local originalImage = OriginalValues[obj] and OriginalValues[obj].Image or obj.Image
                local targetImage = getTargetImage(DeviceSpoof, originalImage)
                
                -- 2A. Direct Image Replacement
                -- isDeviceRelated sudah verify, langsung replace
                if targetImage and obj.Image ~= "" then
                    if obj.Image ~= targetImage then
                        obj.Image = targetImage
                        -- Reset spritesheet properties jika pakai single image
                        if obj.ImageRectSize ~= Vector2.new(0, 0) then
                            obj.ImageRectOffset = Vector2.new(0, 0)
                            obj.ImageRectSize = Vector2.new(0, 0)
                        end
                    end
                end
                
                -- 2B. Spritesheet Offset Replacement
                local origRectSize = OriginalValues[obj].ImageRectSize
                if origRectSize and origRectSize ~= Vector2.new(0, 0) then
                    local pattern = detectSpritePattern(origRectSize)
                    if pattern and CommonSpritePatterns[pattern] then
                        local targetOffset = CommonSpritePatterns[pattern][DeviceSpoof]
                        if targetOffset and obj.ImageRectOffset ~= targetOffset then
                            obj.ImageRectOffset = targetOffset
                        end
                    end
                end
            else
                -- Restore original
                local orig = OriginalValues[obj]
                if orig then
                    if obj.Image ~= orig.Image then obj.Image = orig.Image end
                    if obj.ImageRectOffset ~= orig.ImageRectOffset then obj.ImageRectOffset = orig.ImageRectOffset end
                    if obj.ImageRectSize ~= orig.ImageRectSize then obj.ImageRectSize = orig.ImageRectSize end
                end
            end
        end
    end
    
    -- ==========================================
    -- PATTERN 3: VISIBILITY TOGGLE (Frames & Images by Name)
    -- ==========================================
    if obj:IsA("Frame") or obj:IsA("CanvasGroup") or obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        local nameLower = obj.Name:lower()
        local isDeviceFrame = containsKeyword(nameLower, {"pc", "mobile", "console", "phone", "computer", "xbox", "touch"})
        
        if isDeviceFrame and isDeviceRelated(obj) then
            if not OriginalValues[obj] then
                OriginalValues[obj] = {
                    Visible = obj.Visible,
                    Type = "Frame"
                }
            end
            
            if SpoofEnabled and DeviceSpoof ~= "Default" then
                -- Logic: If it matches our Target Device keyword -> SHOW
                -- If it matches OTHER Device keywords -> HIDE
                
                local targetKeywords = DeviceAssets[DeviceSpoof].Keywords
                local isTarget = false
                
                for _, kw in ipairs(targetKeywords) do
                    if nameLower:find(kw) then
                        isTarget = true
                        break
                    end
                end
                
                if isTarget then
                    obj.Visible = true
                else
                    -- Check if it belongs to other devices
                    local isOther = false
                    for deviceType, data in pairs(DeviceAssets) do
                        if deviceType ~= DeviceSpoof then
                            for _, kw in ipairs(data.Keywords) do
                                if nameLower:find(kw) then
                                    isOther = true
                                    break
                                end
                            end
                        end
                        if isOther then break end
                    end
                    
                    if isOther then
                        obj.Visible = false
                    end
                end
            else
                -- Restore original visibility
                if OriginalValues[obj] then
                    obj.Visible = OriginalValues[obj].Visible
                end
            end
        end
    end
end

-- ==========================================
-- PATTERN 4: ATTRIBUTE SPOOFING (via hooks)
-- Sudah dihandle di ApplyPrivacyHooks()
-- ==========================================

local SpoofToggle = Tools:AddToggle("Enable Spoofing", {Default = SpoofEnabled}, function(v)
    SpoofEnabled = v
    saveSpoofSettings()
    local lp = game.Players.LocalPlayer
    
    if v then
        ApplyPrivacyHooks()
        
        -- Langsung jalankan proactive spoof (override attributes, values, remotes)
        task.spawn(function()
            task.wait(0.3)
            proactiveDeviceSpoof()
        end)
        
        if DeviceSpoof ~= "Default" then
            UI.Confirm("Respawn untuk Apply?", 
                "Respawn karakter agar icon device '" .. DeviceSpoof .. "' ter-update?", 
                function()
                    if lp and lp.Character then
                        local hum = lp.Character:FindFirstChildOfClass("Humanoid")
                        if hum then hum.Health = 0 end
                    end
                end)
        else
            UI.Slide("Privacy", "Spoofing aktif! Pilih device di dropdown di atas.")
        end

        -- Event-based spoofing untuk menghindari blink (lebih smooth)
        local spoofConnections = {}
        _G.StarSpace.SpoofConnections = spoofConnections
        
        -- Track confirmed device elements (hanya yang lolos isDeviceRelated)
        local deviceElements = {}
        _G.StarSpace.DeviceElements = deviceElements
        
        -- Function untuk cek dan register satu element
        local function tryRegisterElement(obj)
            -- Skip jika sudah diproses
            if spoofConnections[obj] or deviceElements[obj] == false then return end
            
            -- Cek apakah device-related (expensive, tapi hanya sekali per element)
            if not isDeviceRelated(obj) then
                deviceElements[obj] = false -- Tandai: bukan device, jangan cek lagi
                return
            end
            
            -- Confirmed device element!
            deviceElements[obj] = true
            pcall(spoof, obj)
            
            if _G.StarSpace and _G.StarSpace.DebugSpoof then
                print("[DeviceSpoof] Registered device element:", obj:GetFullName())
            end
            
            -- Setup listener untuk react ketika game coba ubah
            local conn
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                conn = obj:GetPropertyChangedSignal("Image"):Connect(function()
                    if SpoofEnabled then
                        task.defer(function() pcall(spoof, obj) end)
                    end
                end)
                table.insert(spoofConnections, conn)
                -- Also listen for Visible changes for Pattern 3
                local connVis = obj:GetPropertyChangedSignal("Visible"):Connect(function()
                    if SpoofEnabled then
                        task.defer(function() pcall(spoof, obj) end)
                    end
                end)
                table.insert(spoofConnections, connVis)
            elseif obj:IsA("TextLabel") or obj:IsA("TextButton") then
                conn = obj:GetPropertyChangedSignal("Text"):Connect(function()
                    if SpoofEnabled then
                        task.defer(function() pcall(spoof, obj) end)
                    end
                end)
                table.insert(spoofConnections, conn)
            elseif obj:IsA("Frame") or obj:IsA("CanvasGroup") then
                conn = obj:GetPropertyChangedSignal("Visible"):Connect(function()
                    if SpoofEnabled then
                        task.defer(function() pcall(spoof, obj) end)
                    end
                end)
                table.insert(spoofConnections, conn)
            end
        end
        
        -- Full scan: discover device elements (only runs on init & new characters)
        local function fullScan()
            local lp = game.Players.LocalPlayer
            
            local function scanObj(g)
                if g:IsA("GuiObject") then -- Catch-all for Frames, Images, Text, etc.
                    pcall(tryRegisterElement, g)
                end
            end
            
            -- Scan karakter SEMUA player
            for _, player in pairs(game.Players:GetPlayers()) do
                if player.Character then
                    for _, g in pairs(player.Character:GetDescendants()) do 
                        scanObj(g)
                    end
                end
            end
            
            -- Scan PlayerGui local player
            pcall(function()
                for _, g in pairs(lp.PlayerGui:GetDescendants()) do 
                    scanObj(g)
                end
            end)
            
            if _G.StarSpace and _G.StarSpace.DebugSpoof then
                local count = 0
                for _, v in pairs(deviceElements) do if v == true then count = count + 1 end end
                print("[DeviceSpoof] Full scan done. Device elements found:", count)
            end
        end
        
        -- Quick re-spoof: only update confirmed device elements (FAST, no lag)
        local function quickRespoof()
            for obj, isDevice in pairs(deviceElements) do
                if isDevice == true and typeof(obj) == "Instance" and obj.Parent then
                    pcall(spoof, obj)
                end
            end
        end
        
        -- Initial full scan
        fullScan()
        
        -- Periodic: only quick re-spoof confirmed elements (very lightweight)
        task.spawn(function()
            while SpoofEnabled and task.wait(5) do
                quickRespoof()
            end
        end)
        
        -- Listen untuk new descendants di SEMUA player characters
        local function listenToCharacter(character)
            if not character then return end
            local descConn = character.DescendantAdded:Connect(function(g)
                if SpoofEnabled and (g:IsA("ImageLabel") or g:IsA("ImageButton") or g:IsA("TextLabel") or g:IsA("TextButton") or g:IsA("Frame")) then
                    task.defer(function() tryRegisterElement(g) end)
                end
            end)
            table.insert(spoofConnections, descConn)
        end
        
        -- Setup listener untuk semua player yang ada
        for _, player in pairs(game.Players:GetPlayers()) do
            if player.Character then
                listenToCharacter(player.Character)
            end
            local charConn = player.CharacterAdded:Connect(function(char)
                task.wait(1) -- Tunggu overhead di-spawn
                listenToCharacter(char)
                fullScan() -- Re-scan untuk discover new device elements
                -- Re-run proactive spoof setiap respawn (untuk override attribute baru)
                if player == game.Players.LocalPlayer then
                    task.spawn(function()
                        task.wait(0.5)
                        proactiveDeviceSpoof()
                    end)
                end
            end)
            table.insert(spoofConnections, charConn)
        end
        
        -- Listen untuk player baru yang join
        local joinConn = game.Players.PlayerAdded:Connect(function(player)
            local charConn = player.CharacterAdded:Connect(function(char)
                task.wait(1)
                listenToCharacter(char)
                fullScan()
            end)
            table.insert(spoofConnections, charConn)
        end)
        table.insert(spoofConnections, joinConn)
        
        UI.Slide("Privacy", "Universal Device Spoof Active")
    else
        -- Disconnect semua listeners dulu
        if _G.StarSpace.SpoofConnections then
            for obj, conn in pairs(_G.StarSpace.SpoofConnections) do
                if typeof(conn) == "RBXScriptConnection" then
                    pcall(function() conn:Disconnect() end)
                end
            end
            _G.StarSpace.SpoofConnections = {}
        end
        
        -- Restore SEMUA element dari OriginalValues (paling reliable)
        for obj, orig in pairs(OriginalValues) do
            if typeof(obj) == "Instance" and obj.Parent then
                pcall(function()
                    if orig.Type == "Image" then
                        obj.Image = orig.Image
                        obj.ImageRectOffset = orig.ImageRectOffset
                        obj.ImageRectSize = orig.ImageRectSize
                    elseif orig.Type == "Text" then
                        obj.Text = orig.Text
                    elseif orig.Type == "Frame" then
                        obj.Visible = orig.Visible
                    end
                end)
            end
        end
        OriginalValues = {}
        
        -- Clear DeviceElements
        if _G.StarSpace.DeviceElements then
            _G.StarSpace.DeviceElements = {}
        end
        
        -- Restore GetDevice RemoteFunction ke deteksi asli
        pcall(function()
            local RS = game:GetService("ReplicatedStorage")
            local UIS = game:GetService("UserInputService")
            
            -- Deteksi device asli
            local realDevice = "Computer"
            if UIS.TouchEnabled and not UIS.KeyboardEnabled then
                realDevice = "Phone"
            elseif UIS.GamepadEnabled and not UIS.KeyboardEnabled then
                realDevice = "Console"
            end
            
            -- PATTERN A: GetDevice RemoteFunction
            local getDevice = RS:FindFirstChild("GetDevice")
            if getDevice and getDevice:IsA("RemoteFunction") then
                getDevice.OnClientInvoke = function()
                    return realDevice == "Phone"
                end
            end
            
            -- PATTERN B: DeviceUpdateEvent — fire real device ke server!
            local overhead = RS:FindFirstChild("Overhead")
            if overhead then
                local deviceEvent = overhead:FindFirstChild("DeviceUpdateEvent")
                if deviceEvent and deviceEvent:IsA("RemoteEvent") then
                    deviceEvent:FireServer(realDevice)
                    print("[StarSpace] DeviceUpdateEvent restored:", realDevice)
                end
                
                local deviceReq = overhead:FindFirstChild("DeviceRequestFunction")
                if deviceReq and deviceReq:IsA("RemoteFunction") then
                    deviceReq.OnClientInvoke = function()
                        return realDevice
                    end
                end
            end
            
            -- Fallback root
            local devEvent = RS:FindFirstChild("DeviceUpdateEvent")
            if devEvent and devEvent:IsA("RemoteEvent") then
                devEvent:FireServer(realDevice)
            end
            
            -- PATTERN C: DeviceDetected (emoji) restore
            local deviceDetected = RS:FindFirstChild("DeviceDetected")
            if deviceDetected and deviceDetected:IsA("RemoteEvent") then
                local realEmoji = "\240\159\146\187" -- 💻 default
                if realDevice == "Phone" then
                    realEmoji = "\240\159\147\177"   -- 📱
                elseif realDevice == "Console" then
                    realEmoji = "\240\159\142\174"   -- 🎮
                end
                deviceDetected:FireServer(realEmoji)
                print("[StarSpace] DeviceDetected restored:", realDevice)
            end
        end)
        
        -- Reset attribute "Device" ke nilai asli
        pcall(function()
            local UIS = game:GetService("UserInputService")
            local realDevice = "Computer"
            if UIS.TouchEnabled and not UIS.KeyboardEnabled then
                realDevice = "Phone"
            elseif UIS.GamepadEnabled and not UIS.KeyboardEnabled then
                realDevice = "Console"
            end
            lp:SetAttribute("Device", realDevice)
            if lp.Character then
                lp.Character:SetAttribute("Device", realDevice)
            end
        end)
        
        -- Hapus saved settings agar next session tidak auto-spoof
        clearSpoofSettings()
        
        UI.Slide("Privacy", "Spoofing disabled & icon restored")
    end
end)

-- ============================================
-- AUTO-INIT: Force-trigger toggle jika loaded dari saved settings
-- UI library biasanya TIDAK call callback untuk Default value,
-- jadi fullScan/listenToCharacter tidak pernah jalan.
-- Fix: force Set(true) setelah delay agar semua visual spoof aktif.
-- ============================================
if SpoofEnabled and DeviceSpoof ~= "Default" then
    task.spawn(function()
        task.wait(2) -- Tunggu character + overhead fully loaded
        if SpoofToggle and SpoofToggle.Set then
            -- Temporarily set ke false lalu true untuk trigger callback
            SpoofEnabled = false
            pcall(function() SpoofToggle:Set(false) end)
            task.wait(0.2)
            pcall(function() SpoofToggle:Set(true) end)
            print("[StarSpace] ✅ Auto-initialized visual spoof from saved settings")
        else
            -- Fallback: jika toggle tidak punya Set method, jalankan scan manual
            print("[StarSpace] Toggle.Set not available, running manual scan...")
            SpoofEnabled = true
            _G.StarSpace.SpoofConnections = _G.StarSpace.SpoofConnections or {}
            _G.StarSpace.DeviceElements = _G.StarSpace.DeviceElements or {}
            
            local lp = game.Players.LocalPlayer
            -- Scan semua characters
            for _, player in pairs(game.Players:GetPlayers()) do
                if player.Character then
                    for _, g in pairs(player.Character:GetDescendants()) do
                        if g:IsA("GuiObject") then
                            if isDeviceRelated(g) then
                                _G.StarSpace.DeviceElements[g] = true
                                pcall(spoof, g)
                            end
                        end
                    end
                    -- Listen for new objects
                    local dc = player.Character.DescendantAdded:Connect(function(g)
                        if SpoofEnabled and g:IsA("GuiObject") and isDeviceRelated(g) then
                            _G.StarSpace.DeviceElements[g] = true
                            task.defer(function() pcall(spoof, g) end)
                        end
                    end)
                    table.insert(_G.StarSpace.SpoofConnections, dc)
                end
            end
            -- Scan PlayerGui
            pcall(function()
                for _, g in pairs(lp.PlayerGui:GetDescendants()) do
                    if g:IsA("GuiObject") and isDeviceRelated(g) then
                        _G.StarSpace.DeviceElements[g] = true
                        pcall(spoof, g)
                    end
                end
            end)
            -- Periodic re-spoof
            task.spawn(function()
                while SpoofEnabled and task.wait(5) do
                    for obj, isDevice in pairs(_G.StarSpace.DeviceElements) do
                        if isDevice and typeof(obj) == "Instance" and obj.Parent then
                            pcall(spoof, obj)
                        end
                    end
                end
            end)
            print("[StarSpace] ✅ Manual scan complete")
        end
    end)
end

Tools:AddSection("Server")
Tools:AddRetroButton({Name = "Rejoin Server", Callback = function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, game.Players.LocalPlayer)
end})

Tools:AddSection("Visuals")
Tools:AddToggle("Hide Players", {Default = false}, function(v)
    for _, p in pairs(game.Players:GetPlayers()) do
        if p ~= game.Players.LocalPlayer and p.Character then
            for _, part in pairs(p.Character:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("Decal") then
                    part.Transparency = v and 1 or 0
                end
            end
        end
    end
end)

-- Skybox Changer
local SkyboxPresets = {
    ["Default"] = nil,
    ["Galaxy Night"] = {SkyboxBk = "rbxassetid://159454286", SkyboxDn = "rbxassetid://159454296", SkyboxFt = "rbxassetid://159454299", SkyboxLf = "rbxassetid://159454286", SkyboxRt = "rbxassetid://159454291", SkyboxUp = "rbxassetid://159454293", StarCount = 5000},
    ["Blood Red"] = {SkyboxBk = "rbxassetid://1012890", SkyboxDn = "rbxassetid://1012891", SkyboxFt = "rbxassetid://1012887", SkyboxLf = "rbxassetid://1012889", SkyboxRt = "rbxassetid://1012888", SkyboxUp = "rbxassetid://1014449", StarCount = 500, Ambient = Color3.fromRGB(80, 20, 20)},
    ["Skybox HD"] = {SkyboxBk = "rbxassetid://16553658937", SkyboxDn = "rbxassetid://16553660713", SkyboxFt = "rbxassetid://16553662144", SkyboxLf = "rbxassetid://16553664042", SkyboxRt = "rbxassetid://16553665766", SkyboxUp = "rbxassetid://16553667750", StarCount = 3000},
}
local OriginalSky = nil

Tools:AddDropdown("Skybox", {Options = {"Default", "Galaxy Night", "Blood Red", "Skybox HD"}}, function(v)
    local lighting = game:GetService("Lighting")
    if v == "Default" then
        if OriginalSky then
            local sky = lighting:FindFirstChildOfClass("Sky")
            if sky then
                sky.SkyboxBk = OriginalSky.SkyboxBk
                sky.SkyboxDn = OriginalSky.SkyboxDn
                sky.SkyboxFt = OriginalSky.SkyboxFt
                sky.SkyboxLf = OriginalSky.SkyboxLf
                sky.SkyboxRt = OriginalSky.SkyboxRt
                sky.SkyboxUp = OriginalSky.SkyboxUp
                sky.StarCount = OriginalSky.StarCount
            end
        end
    else
        local preset = SkyboxPresets[v]
        if preset then
            local sky = lighting:FindFirstChildOfClass("Sky")
            if not sky then sky = Instance.new("Sky", lighting) end
            
            if not OriginalSky then
                OriginalSky = {
                    SkyboxBk = sky.SkyboxBk, SkyboxDn = sky.SkyboxDn, SkyboxFt = sky.SkyboxFt,
                    SkyboxLf = sky.SkyboxLf, SkyboxRt = sky.SkyboxRt, SkyboxUp = sky.SkyboxUp,
                    StarCount = sky.StarCount
                }
            end
            
            sky.SkyboxBk = preset.SkyboxBk
            sky.SkyboxDn = preset.SkyboxDn
            sky.SkyboxFt = preset.SkyboxFt
            sky.SkyboxLf = preset.SkyboxLf
            sky.SkyboxRt = preset.SkyboxRt
            sky.SkyboxUp = preset.SkyboxUp
            sky.StarCount = preset.StarCount or 0
            if preset.Ambient then lighting.Ambient = preset.Ambient end
        end
    end
end)

-- HD Shader
local ShaderEffects = {}
Tools:AddDropdown("HD Shader", {Options = {"OFF", "HD Natural", "Cinematic", "Vibrant"}}, function(v)
    local lighting = game:GetService("Lighting")
    
    -- Clear existing
    for _, e in pairs(ShaderEffects) do pcall(function() e:Destroy() end) end
    ShaderEffects = {}
    
    if v == "OFF" then return end
    
    local cc = Instance.new("ColorCorrectionEffect", lighting)
    local bloom = Instance.new("BloomEffect", lighting)
    local sun = Instance.new("SunRaysEffect", lighting)
    
    table.insert(ShaderEffects, cc)
    table.insert(ShaderEffects, bloom)
    table.insert(ShaderEffects, sun)
    
    if v == "HD Natural" then
        cc.Brightness, cc.Contrast, cc.Saturation = 0.05, 0.1, 0.15
        bloom.Intensity, bloom.Size = 0.5, 24
        sun.Intensity, sun.Spread = 0.1, 0.5
    elseif v == "Cinematic" then
        cc.Brightness, cc.Contrast, cc.Saturation = -0.05, 0.2, -0.1
        bloom.Intensity, bloom.Size = 0.8, 40
        sun.Intensity, sun.Spread = 0.15, 0.6
    elseif v == "Vibrant" then
        cc.Brightness, cc.Contrast, cc.Saturation = 0.1, 0.15, 0.4
        bloom.Intensity, bloom.Size = 0.6, 30
        sun.Intensity, sun.Spread = 0.2, 0.7
    end
end)

-- Animations Tab Logic
local RawAnimDB = {
    ["Idle"] = {
        ["2016 Animation (mm2)"] = { "387947158", "387947464" },
        ["(UGC) Oh Really?"] = { "98004748982532", "98004748982532" },
        ["Astronaut"] = { "891621366", "891633237" },
        ["Adidas Community"] = { "122257458498464", "102357151005774" },
        ["Adidas Aura"] = { "99457463463495", "99457463463495" },
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
        ["(UGC) TailWag"] = { "129026910898635", "129026910898635" }
    },
    ["Walk"] = {
        ["Gojo"] = "95643163365384", ["Geto"] = "85811471336028", ["Astronaut"] = "891667138", ["(UGC) Zombie"] = "113603435314095",
        ["Adidas Community"] = "122150855457006", ["Bold"] = "16738340646", ["Bubbly"] = "910034870", ["(UGC) Smooth"] = "76630051272791",
        ["Cartoony"] = "742640026", ["Confident"] = "1070017263", ["Cowboy"] = "1014421541", ["(UGC) Retro"] = "107806791584829",
        ["(UGC) Retro Zombie"] = "140703855480494", ["Catwalk Glam"] = "109168724482748", ["Drooling Zombie"] = "3489174223", ["Elder"] = "10921111375",
        ["Ghost"] = "616013216", ["Knight"] = "10921127095", ["Levitation"] = "616013216", ["Mage"] = "707897309", ["Ninja"] = "656121766",
        ["NFL"] = "110358958299415", ["OldSchool"] = "10921244891", ["Patrol"] = "1151231493", ["Pirate"] = "750785693", ["Default Retarget"] = "115825677624788",
        ["Popstar"] = "1212980338", ["Princess"] = "941028902", ["R6"] = "12518152696", ["R15 Reanimated"] = "4211223236", ["2016 Animation (mm2)"] = "387947975",
        ["Robot"] = "616095330", ["Sneaky"] = "1132510133", ["Sports (Adidas)"] = "18537392113", ["Stylish"] = "616146177", ["Stylized Female"] = "4708193840",
        ["Superhero"] = "10921298616", ["Toy"] = "782843345", ["Udzal"] = "3303162967", ["Vampire"] = "1083473930", ["Werewolf"] = "1083178339",
        ["Wicked (Popular)"] = "92072849924640", ["No Boundaries (Walmart)"] = "18747074203", ["Zombie"] = "616168032"
    },
    ["Run"] = {
        ["2016 Animation (mm2)"] = "387947975", ["(UGC) Soccer"] = "116881956670910", ["Adidas Community"] = "82598234841035", ["Astronaut"] = "10921039308",
        ["Bold"] = "16738337225", ["Bubbly"] = "10921057244", ["Cartoony"] = "10921076136", ["(UGC) Dog"] = "130072963359721", ["Confident"] = "1070001516",
        ["(UGC) Pride"] = "116462200642360", ["(UGC) Retro"] = "107806791584829", ["(UGC) Retro Zombie"] = "140703855480494", ["Cowboy"] = "1014401683",
        ["Catwalk Glam"] = "81024476153754", ["Drooling Zombie"] = "3489173414", ["Elder"] = "10921104374", ["Ghost"] = "616013216", ["Heavy Run (Udzal / Borock)"] = "3236836670",
        ["Knight"] = "10921121197", ["Levitation"] = "616010382", ["Mage"] = "10921148209", ["MrToilet"] = "4417979645", ["Ninja"] = "656118852", ["NFL"] = "117333533048078",
        ["OldSchool"] = "10921240218", ["Patrol"] = "1150967949", ["Pirate"] = "750783738", ["Default Retarget"] = "102294264237491", ["Popstar"] = "1212980348",
        ["Princess"] = "941015281", ["R6"] = "12518152696", ["R15 Reanimated"] = "4211220381", ["Robot"] = "10921250460", ["Sneaky"] = "1132494274",
        ["Sports (Adidas)"] = "18537384940", ["Stylish"] = "10921276116", ["Stylized Female"] = "4708192705", ["Superhero"] = "10921291831", ["Toy"] = "10921306285",
        ["Vampire"] = "10921320299", ["Werewolf"] = "10921336997", ["Wicked (Popular)"] = "72301599441680", ["No Boundaries (Walmart)"] = "18747070484", ["Zombie"] = "616163682"
    },
    ["Jump"] = {
        ["Astronaut"] = "891627522", ["Adidas Community"] = "75290611992385", ["Bold"] = "16738336650", ["Bubbly"] = "910016857", ["Cartoony"] = "742637942",
        ["Catwalk Glam"] = "116936326516985", ["Confident"] = "1069984524", ["Cowboy"] = "1014394726", ["Elder"] = "10921107367", ["Ghost"] = "616008936",
        ["Knight"] = "910016857", ["Levitation"] = "616008936", ["Mage"] = "10921149743", ["Ninja"] = "656117878", ["NFL"] = "119846112151352",
        ["OldSchool"] = "10921242013", ["Patrol"] = "1148811837", ["Pirate"] = "750782230", ["(UGC) Retro"] = "139390570947836", ["Default Retarget"] = "117150377950987",
        ["Popstar"] = "1212954642", ["Princess"] = "941008832", ["Robot"] = "616090535", ["R15 Reanimated"] = "4211219390", ["R6"] = "12520880485",
        ["Sneaky"] = "1132489853", ["Sports (Adidas)"] = "18537380791", ["Stylish"] = "616139451", ["Stylized Female"] = "4708188025", ["Superhero"] = "10921294559",
        ["Toy"] = "10921308158", ["Vampire"] = "1083455352", ["Werewolf"] = "1083218792", ["Wicked (Popular)"] = "104325245285198", ["No Boundaries (Walmart)"] = "18747069148",
        ["Zombie"] = "616161997"
    },
    ["Fall"] = {
        ["Astronaut"] = "891617961", ["Adidas Community"] = "98600215928904", ["Bold"] = "16738333171", ["Bubbly"] = "910001910", ["Cartoony"] = "742637151",
        ["Catwalk Glam"] = "92294537340807", ["Confident"] = "1069973677", ["Cowboy"] = "1014384571", ["Elder"] = "10921105765", ["Knight"] = "10921122579",
        ["Levitation"] = "616005863", ["Mage"] = "707829716", ["Ninja"] = "656115606", ["NFL"] = "129773241321032", ["OldSchool"] = "10921241244",
        ["Patrol"] = "1148863382", ["Pirate"] = "750780242", ["Default Retarget"] = "110205622518029", ["Popstar"] = "1212900995", ["Princess"] = "941000007",
        ["Robot"] = "616087089", ["R15 Reanimated"] = "4211216152", ["R6"] = "12520972571", ["Sneaky"] = "1132469004", ["Sports (Adidas)"] = "18537367238",
        ["Stylish"] = "616134815", ["Stylized Female"] = "4708186162", ["Superhero"] = "10921293373", ["Toy"] = "782846423", ["Vampire"] = "1083443587",
        ["Werewolf"] = "1083189019", ["Wicked (Popular)"] = "121152442762481", ["No Boundaries (Walmart)"] = "18747062535", ["Zombie"] = "616157476"
    },
    ["SwimIdle"] = {
        ["Astronaut"] = "891663592", ["Adidas Community"] = "109346520324160", ["Bold"] = "16738339817", ["Bubbly"] = "910030921", ["Cartoony"] = "10921079380",
        ["Catwalk Glam"] = "98854111361360", ["Confident"] = "1070012133", ["CowBoy"] = "1014411816", ["Elder"] = "10921110146", ["Mage"] = "707894699",
        ["Ninja"] = "656118341", ["NFL"] = "79090109939093", ["Patrol"] = "1151221899", ["Knight"] = "10921125935", ["OldSchool"] = "10921244018",
        ["Levitation"] = "10921139478", ["Popstar"] = "1212998578", ["Princess"] = "941025398", ["Pirate"] = "750785176", ["R6"] = "12518152696",
        ["Robot"] = "10921253767", ["Sneaky"] = "1132506407", ["Sports (Adidas)"] = "18537387180", ["Stylish"] = "10921281964", ["Stylized"] = "4708190607",
        ["SuperHero"] = "10921297391", ["Toy"] = "10921310341", ["Vampire"] = "10921325443", ["Werewolf"] = "10921341319", ["Wicked (Popular)"] = "113199415118199",
        ["No Boundaries (Walmart)"] = "18747071682"
    },
    ["Swim"] = {
        ["Astronaut"] = "891663592", ["Adidas Community"] = "133308483266208", ["Bubbly"] = "910028158", ["Bold"] = "16738339158", ["Cartoony"] = "10921079380",
        ["Catwalk Glam"] = "134591743181628", ["CowBoy"] = "1014406523", ["Confident"] = "1070009914", ["Elder"] = "10921108971", ["Knight"] = "10921125160",
        ["Mage"] = "707876443", ["NFL"] = "132697394189921", ["OldSchool"] = "10921243048", ["PopStar"] = "1212998578", ["Princess"] = "941018893",
        ["Pirate"] = "750784579", ["Patrol"] = "1151204998", ["R6"] = "12518152696", ["Robot"] = "10921253142", ["Levitation"] = "10921138209",
        ["Stylish"] = "10921281000", ["SuperHero"] = "10921295495", ["Sneaky"] = "1132500520", ["Sports (Adidas)"] = "18537389531", ["Toy"] = "10921309319",
        ["Vampire"] = "10921324408", ["Werewolf"] = "10921340419", ["Wicked (Popular)"] = "99384245425157", ["No Boundaries (Walmart)"] = "18747073181",
        ["Zombie"] = "616165109"
    },
    ["Climb"] = {
        ["Astronaut"] = "10921032124", ["Adidas Community"] = "88763136693023", ["Bold"] = "16738332169", ["Cartoony"] = "742636889", ["Catwalk Glam"] = "119377220967554",
        ["Confident"] = "1069946257", ["CowBoy"] = "1014380606", ["Elder"] = "845392038", ["Ghost"] = "616003713", ["Knight"] = "10921125160",
        ["Levitation"] = "10921132092", ["Mage"] = "707826056", ["Ninja"] = "656114359", ["(UGC) Retro"] = "121075390792786", ["NFL"] = "134630013742019",
        ["OldSchool"] = "10921229866", ["Patrol"] = "1148811837", ["Popstar"] = "1213044953", ["Princess"] = "940996062", ["R6"] = "12520982150",
        ["Reanimated R15"] = "4211214992", ["Robot"] = "616086039", ["Sneaky"] = "1132461372", ["Sports (Adidas)"] = "18537363391", ["Stylish"] = "10921271391",
        ["Stylized Female"] = "4708184253", ["SuperHero"] = "10921286911", ["Toy"] = "10921300839", ["Vampire"] = "1083439238", ["WereWolf"] = "10921329322",
        ["Wicked (Popular)"] = "131326830509784", ["No Boundaries (Walmart)"] = "18747060903", ["Zombie"] = "616156119"
    }
}

-- Helper function to get sorted keys with Default option
local function getKeys(t, includeDefault)
    local keys = {}
    if includeDefault then
        table.insert(keys, "Default")
    end
    for k, _ in pairs(t) do table.insert(keys, k) end
    table.sort(keys, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a < b
    end)
    return keys
end

-- Store Original Animation IDs from character's current equipped animations
local OriginalAnimations = {}

local function CaptureOriginalAnimations()
    local char = game.Players.LocalPlayer.Character
    local animate = char and char:FindFirstChild("Animate")
    
    if animate then
        pcall(function()
            if animate:FindFirstChild("idle") then
                OriginalAnimations.Idle = {
                    animate.idle.Animation1.AnimationId,
                    animate.idle.Animation2.AnimationId
                }
            end
            if animate:FindFirstChild("walk") then
                OriginalAnimations.Walk = animate.walk.WalkAnim.AnimationId
            end
            if animate:FindFirstChild("run") then
                OriginalAnimations.Run = animate.run.RunAnim.AnimationId
            end
            if animate:FindFirstChild("jump") then
                OriginalAnimations.Jump = animate.jump.JumpAnim.AnimationId
            end
            if animate:FindFirstChild("fall") then
                OriginalAnimations.Fall = animate.fall.FallAnim.AnimationId
            end
            if animate:FindFirstChild("climb") then
                OriginalAnimations.Climb = animate.climb.ClimbAnim.AnimationId
            end
            if animate:FindFirstChild("swim") then
                OriginalAnimations.Swim = animate.swim.Swim.AnimationId
            end
        end)
    end
end

-- Capture on load
CaptureOriginalAnimations()

-- Also capture when character respawns
game.Players.LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5) -- Wait for Animate script to load
    if next(OriginalAnimations) == nil then
        CaptureOriginalAnimations()
    end
end)

-- Create Dropdowns for each category
local Categories = {"Idle", "Walk", "Run", "Jump", "Fall", "Climb", "Swim"}

for _, cat in ipairs(Categories) do
    local options = getKeys(RawAnimDB[cat] or {}, true)
    if #options > 1 then -- More than just Default
        Animations:AddDropdown(cat .. " Animation", {Options = options, Default = "Default"}, function(name)
            local char = game.Players.LocalPlayer.Character
            local animate = char and char:FindFirstChild("Animate")
            
            if not animate then
                UI.Slide("Error", "Animate script not found!")
                return
            end
            
            local id
            if name == "Default" then
                id = OriginalAnimations[cat]
            else
                id = RawAnimDB[cat][name]
            end
            
            if not id then 
                UI.Slide("Error", "Animation not found!")
                return 
            end
            
            if cat == "Idle" then
                local id1 = type(id) == "table" and id[1] or id
                local id2 = type(id) == "table" and id[2] or id
                -- For original animations, IDs already include rbxassetid://
                if name == "Default" then
                    animate.idle.Animation1.AnimationId = id1
                    animate.idle.Animation2.AnimationId = id2
                else
                    animate.idle.Animation1.AnimationId = "rbxassetid://" .. id1
                    animate.idle.Animation2.AnimationId = "rbxassetid://" .. id2
                end
            elseif cat == "Walk" then
                animate.walk.WalkAnim.AnimationId = name == "Default" and id or ("rbxassetid://" .. id)
            elseif cat == "Run" then
                animate.run.RunAnim.AnimationId = name == "Default" and id or ("rbxassetid://" .. id)
            elseif cat == "Jump" then
                animate.jump.JumpAnim.AnimationId = name == "Default" and id or ("rbxassetid://" .. id)
            elseif cat == "Fall" then
                animate.fall.FallAnim.AnimationId = name == "Default" and id or ("rbxassetid://" .. id)
            elseif cat == "Climb" and animate:FindFirstChild("climb") then
                animate.climb.ClimbAnim.AnimationId = name == "Default" and id or ("rbxassetid://" .. id)
            elseif cat == "Swim" and animate:FindFirstChild("swim") then
                animate.swim.Swim.AnimationId = name == "Default" and id or ("rbxassetid://" .. id)
            end
            
            -- Force update
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Landed)
            end
            
            if name == "Default" then
                UI.Slide("Animation", cat .. " reset to Default")
            else
                UI.Slide("Animation", cat .. " set to " .. name)
            end
        end)
    end
end

Animations:AddSection("Manual Override")
local AnimID = ""
Animations:AddInput("Animation ID", {Placeholder = "rbxassetid://..."}, function(v)
    AnimID = v
end)

Animations:AddDropdown("Apply Manual ID To", {Options = {"-- Select --", "Idle", "Walk", "Run", "Jump", "Fall"}, Default = "-- Select --"}, function(v)
    if v == "-- Select --" then return end
    if AnimID == "" then 
        UI.Slide("Error", "Please enter an Animation ID first!")
        return 
    end
    
    local char = game.Players.LocalPlayer.Character
    local animate = char and char:FindFirstChild("Animate")
    if animate then
        if v == "Idle" then
            animate.idle.Animation1.AnimationId = AnimID
            animate.idle.Animation2.AnimationId = AnimID
        elseif v == "Walk" then
            animate.walk.WalkAnim.AnimationId = AnimID
        elseif v == "Run" then
            animate.run.RunAnim.AnimationId = AnimID
        elseif v == "Jump" then
            animate.jump.JumpAnim.AnimationId = AnimID
        elseif v == "Fall" then
            animate.fall.FallAnim.AnimationId = AnimID
        end
        UI.Slide("Animation", "Applied " .. v .. " animation!")
    else
        UI.Slide("Error", "Animate script not found!")
    end
end)

Animations:AddRetroButton({Name = "Reset All", Callback = function()
    -- Simple reset by respawning or re-enabling Animate (placeholder logic)
    UI.Slide("Animation", "To reset, please respawn.")
end})

-- ================================================
-- HELPER TAB - Obby Assist Features
-- ================================================
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Helper Variables & Connections
_G.StarSpace.HelperConnections = {}
local DefaultWalkSpeed = 16
local SpeedEnabled = false
local CurrentSpeed = 16
local FlyEnabled = false
local FlySpeed = 50
local InfJumpEnabled = false
local AutoJumpEnabled = false
local AirLockEnabled = false
local AirLockBoostCooldown = false
local AirLockHasBoosted = false
local AirLockLastGroundTime = 0

-- Cleanup function for connections
local function CleanupConnection(conn)
    if conn then
        pcall(function() conn:Disconnect() end)
    end
end

-- Fly Functions
local function StopFly()
    FlyEnabled = false
    local char = game.Players.LocalPlayer.Character
    if char then
        local r = char:FindFirstChild("HumanoidRootPart")
        if r then
            for _, x in pairs(r:GetChildren()) do
                if x.Name == "StarSpaceFlyVel" or x.Name == "StarSpaceFlyGyro" then
                    x:Destroy()
                end
            end
        end
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end
    CleanupConnection(_G.StarSpace.HelperConnections.FlyLoop)
    _G.StarSpace.HelperConnections.FlyLoop = nil
end

local function StartFly()
    local char = game.Players.LocalPlayer.Character
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local r = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
    if not char or not r or not h then 
        warn("[StarSpace] Fly failed: Character parts missing")
        return 
    end
    
    StopFly() -- Ensure clean start
    FlyEnabled = true
    h.PlatformStand = true
    
    local bv = Instance.new("BodyVelocity", r)
    bv.Name = "StarSpaceFlyVel"
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(0, 0, 0)
    
    local bg = Instance.new("BodyGyro", r)
    bg.Name = "StarSpaceFlyGyro"
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 10000
    bg.D = 1000
    
    _G.StarSpace.HelperConnections.FlyLoop = RunService.RenderStepped:Connect(function()
        if not FlyEnabled or not char.Parent then
            StopFly()
            return
        end
        local cam = workspace.CurrentCamera
        local m = Vector3.new(0, 0, 0)
        local k = UserInputService:GetKeysPressed()
        for _, key in pairs(k) do
            if key.KeyCode == Enum.KeyCode.W then m = m + cam.CFrame.LookVector
            elseif key.KeyCode == Enum.KeyCode.A then m = m - cam.CFrame.RightVector
            elseif key.KeyCode == Enum.KeyCode.S then m = m - cam.CFrame.LookVector
            elseif key.KeyCode == Enum.KeyCode.D then m = m + cam.CFrame.RightVector
            end
        end
        bg.CFrame = cam.CFrame
        bv.Velocity = m * FlySpeed
    end)
end

-- Jump Assist Helpers
local function AirLockBoostToEdge(rootPart, edgePosition)
    if AirLockBoostCooldown or AirLockHasBoosted then return false end
    local direction = (edgePosition - rootPart.Position)
    local distance = direction.Magnitude
    if distance < 2 then return false end
    local currentVel = rootPart.AssemblyLinearVelocity
    if currentVel.Y < -20 then return false end
    local horizontalDir = Vector3.new(direction.X, 0, direction.Z)
    if horizontalDir.Magnitude > 0 then horizontalDir = horizontalDir.Unit end
    local heightDiff = edgePosition.Y - rootPart.Position.Y
    local upwardBoost = heightDiff > 0 and math.clamp(heightDiff * 0.5, 4, 10) or 2
    local forwardBoost = 7
    local boostVelocity = Vector3.new(horizontalDir.X * forwardBoost, upwardBoost, horizontalDir.Z * forwardBoost)
    rootPart.AssemblyLinearVelocity = currentVel + boostVelocity
    AirLockHasBoosted = true
    AirLockBoostCooldown = true
    task.delay(0.4, function() AirLockBoostCooldown = false end)
    return true
end

local function DetectEdgeForward(character, rootPart, humanoid)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local playerPos = rootPart.Position
    local playerTop = playerPos.Y + 2
    local moveDir = humanoid and humanoid.MoveDirection or Vector3.new(0, 0, 0)
    local lookDir = rootPart.CFrame.LookVector
    local primaryDir = moveDir.Magnitude > 0.1 and moveDir or lookDir
    local horizontalLook = Vector3.new(primaryDir.X, 0, primaryDir.Z)
    if horizontalLook.Magnitude > 0 then horizontalLook = horizontalLook.Unit end
    local angles = {horizontalLook, (horizontalLook + Vector3.new(0, 0.5, 0)).Unit, (horizontalLook + Vector3.new(0, 1.0, 0)).Unit}
    for _, dir in ipairs(angles) do
        local hitResult = workspace:Raycast(playerPos, dir * 12, rayParams)
        if hitResult then
            local hitPart = hitResult.Instance
            local ledgeTop = hitPart.Position.Y + (hitPart.Size.Y / 2)
            local heightDiff = ledgeTop - playerTop
            if heightDiff > 0 and heightDiff <= 8 then return hitResult.Position end
        end
    end
    return nil
end

local FeatureStates = {}
local function RunLogic(name, logic, val)
    FeatureStates[name] = val
    print("[StarSpace] Logic Triggered ->", name, "=", tostring(val))
    local success, err = pcall(function() logic(val) end)
    if not success then warn("[StarSpace] Error in " .. name .. " logic: " .. tostring(err)) end
end

-- Logic Handlers
local function FlyLogic(v)
    if v then StartFly() else StopFly() end
    UI.Slide("Movement", "Fly " .. (v and "ON" or "OFF"))
end

local function SpeedLogic(v)
    SpeedEnabled = v
    local char = game.Players.LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if v then
        if hum then DefaultWalkSpeed = hum.WalkSpeed hum.WalkSpeed = CurrentSpeed end
        CleanupConnection(_G.StarSpace.HelperConnections.Speed)
        _G.StarSpace.HelperConnections.Speed = RunService.Heartbeat:Connect(function()
            local c = game.Players.LocalPlayer.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if h and math.abs(h.WalkSpeed - CurrentSpeed) > 1 then h.WalkSpeed = CurrentSpeed end
        end)
    else
        CleanupConnection(_G.StarSpace.HelperConnections.Speed)
        _G.StarSpace.HelperConnections.Speed = nil
        if hum then 
            local h = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = DefaultWalkSpeed end
        end
    end
    UI.Slide("Movement", "Speed " .. (v and "Enabled" or "Disabled"))
end

local function InfJumpLogic(v)
    InfJumpEnabled = v
    if v then
        CleanupConnection(_G.StarSpace.HelperConnections.InfJump)
        _G.StarSpace.HelperConnections.InfJump = UserInputService.JumpRequest:Connect(function()
            local char = game.Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState("Jumping") end
        end)
    else
        CleanupConnection(_G.StarSpace.HelperConnections.InfJump)
        _G.StarSpace.HelperConnections.InfJump = nil
    end
    UI.Slide("Movement", "Infinite Jump " .. (v and "ON" or "OFF"))
end

local function AutoJumpLogic(v)
    AutoJumpEnabled = v
    if v then
        CleanupConnection(_G.StarSpace.HelperConnections.AutoJump)
        _G.StarSpace.HelperConnections.AutoJump = RunService.Heartbeat:Connect(function()
            local char = game.Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.FloorMaterial ~= Enum.Material.Air then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    else
        CleanupConnection(_G.StarSpace.HelperConnections.AutoJump)
        _G.StarSpace.HelperConnections.AutoJump = nil
    end
    UI.Slide("Jump Assist", "Auto Jump " .. (v and "ON" or "OFF"))
end

local function AirLockLogic(v)
    AirLockEnabled = v
    if v then
        CleanupConnection(_G.StarSpace.HelperConnections.AirLock)
        _G.StarSpace.HelperConnections.AirLock = RunService.RenderStepped:Connect(function()
            local char = game.Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
            if not hum or not root then return end
            local state = hum:GetState()
            local currentTime = tick()
            if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
                AirLockLastGroundTime = currentTime
                AirLockHasBoosted = false
            end
            if (state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall) and not AirLockHasBoosted then
                if currentTime - AirLockLastGroundTime < 0.1 then return end
                local edgePos = DetectEdgeForward(char, root, hum)
                if edgePos and not AirLockBoostCooldown then AirLockBoostToEdge(root, edgePos) end
            end
        end)
    else
        CleanupConnection(_G.StarSpace.HelperConnections.AirLock)
        _G.StarSpace.HelperConnections.AirLock = nil
    end
    UI.Slide("Jump Assist", "Air Lock " .. (v and "ON" or "OFF"))
end



-- === UI ELEMENTS ===
Helper:AddSection("🏃 Character & Movement")

local FlyToggle = Helper:AddToggle("Fly Mode", {Default = false, Flag = "FlyEnabled"}, function(v)
    RunLogic("Fly", FlyLogic, v)
end)
Helper:AddKeybind("Fly Keybind", { Default = Enum.KeyCode.F, Flag = "FlyKey" }, function()
    local newVal = not (FeatureStates["Fly"] or false)
    print("[StarSpace] Keybind -> Toggling Fly to:", newVal)
    if FlyToggle and FlyToggle.Set then
        FlyToggle:Set(newVal)
    end
    RunLogic("Fly", FlyLogic, newVal)
end)

Helper:AddSlider("   └ Fly Speed", {Min = 10, Max = 200, Default = 50, Flag = "FlySpd"}, function(v)
    FlySpeed = v
end)

local SpeedToggle = Helper:AddToggle("Enable Speed Modifier", {Default = false, Flag = "SpeedEnabled"}, function(v)
    RunLogic("Speed", SpeedLogic, v)
end)
Helper:AddKeybind("Speed Keybind", { Default = Enum.KeyCode.V, Flag = "SpeedKey" }, function()
    local newVal = not (FeatureStates["Speed"] or false)
    print("[StarSpace] Keybind -> Toggling Speed to:", newVal)
    if SpeedToggle and SpeedToggle.Set then
        SpeedToggle:Set(newVal)
    end
    RunLogic("Speed", SpeedLogic, newVal)
end)

Helper:AddSlider("   └ Speed Value", {Min = 0, Max = 200, Default = 16, Flag = "HelperSpeed"}, function(v)
    CurrentSpeed = v
    if SpeedEnabled then
        local char = game.Players.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end
end)

local InfJumpToggle = Helper:AddToggle("Infinite Jump", {Default = false, Flag = "InfJump"}, function(v)
    RunLogic("InfJump", InfJumpLogic, v)
end)
Helper:AddKeybind("Inf Jump Keybind", { Default = Enum.KeyCode.J, Flag = "InfJumpKey" }, function()
    local newVal = not (FeatureStates["InfJump"] or false)
    print("[StarSpace] Keybind -> Toggling InfJump to:", newVal)
    if InfJumpToggle and InfJumpToggle.Set then
        InfJumpToggle:Set(newVal)
    end
    RunLogic("InfJump", InfJumpLogic, newVal)
end)

Helper:AddSection("🦘 Jump Assist")

local AutoJumpToggle = Helper:AddToggle("Auto Jump", {Default = false, Flag = "AutoJump"}, function(v)
    RunLogic("AutoJump", AutoJumpLogic, v)
end)
Helper:AddKeybind("Auto Jump Keybind", { Default = Enum.KeyCode.U, Flag = "AutoJumpKey" }, function()
    local newVal = not (FeatureStates["AutoJump"] or false)
    print("[StarSpace] Keybind -> Toggling AutoJump to:", newVal)
    if AutoJumpToggle and AutoJumpToggle.Set then
        AutoJumpToggle:Set(newVal)
    end
    RunLogic("AutoJump", AutoJumpLogic, newVal)
end)

local AirLockToggle = Helper:AddToggle("Air Lock (Edge Assist)", {Default = true, Flag = "AirLock"}, function(v)
    RunLogic("AirLock", AirLockLogic, v)
end)
Helper:AddKeybind("Air Lock Keybind", { Default = Enum.KeyCode.L, Flag = "AirLockKey" }, function()
    local newVal = not (FeatureStates["AirLock"] or false)
    print("[StarSpace] Keybind -> Toggling AirLock to:", newVal)
    if AirLockToggle and AirLockToggle.Set then
        AirLockToggle:Set(newVal)
    end
    RunLogic("AirLock", AirLockLogic, newVal)
end)





local QuickBoostPower = 5
local QuickBoostForward = 2
local QuickBoostHasBoosted = false
local QuickBoostCount = 0
local QuickBoostLastTime = 0
local QBLastA, QBLastD, QBLastW = false, false, false
local QBLastLT, QBLastRT = false, false
local BugJumpEnabled = true

-- Auto Spin+Jump Variables
local AutoSpinJumpEnabled = false
local IsSpinning = false
local SpinJumpLastTime = 0
local SpinDegreeOptions = {45, 90, 180, 360}
local CurrentSpinIndex = 2
local SpinDuration = 0.05

-- Momentum & Safety Variables
local MomentumEnabled = false
local LockedSpeed = nil
local AntiSlipEnabled = false
local AntiSlipLastSafeY = nil
local AntiSlipSize = 3
local AntiRagdollEnabled = false
local AntiRagdollMaxVel = 100

-- ESP Variables
local RealESPEnabled = false
local ESPContainer = nil
local HighlightedParts = {}

-- === LOGIC FUNCTIONS ===

local function QuickBoostLogic(v)
    QuickBoostEnabled = v
    if v then
        CleanupConnection(_G.StarSpace.HelperConnections.QuickBoost)
        _G.StarSpace.HelperConnections.QuickBoost = RunService.Heartbeat:Connect(function()
            local char = game.Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
            if not hum or not root then return end
            local state = hum:GetState()
            local isOnGround = state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed or hum.FloorMaterial ~= Enum.Material.Air
            local isInAir = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
            if isOnGround then QuickBoostHasBoosted = false QuickBoostCount = 0 end
            local aPressed = UserInputService:IsKeyDown(Enum.KeyCode.A)
            local dPressed = UserInputService:IsKeyDown(Enum.KeyCode.D)
            local wPressed = UserInputService:IsKeyDown(Enum.KeyCode.W)
            local ltPressed, rtPressed, lsForward = false, false, false
            pcall(function()
                ltPressed = UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2)
                rtPressed = UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
                local gamepadState = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
                for _, input in ipairs(gamepadState) do
                    if input.KeyCode == Enum.KeyCode.Thumbstick1 then lsForward = input.Position.Y > 0.3 break end
                end
            end)
            local aJustPressed = aPressed and not QBLastA
            local dJustPressed = dPressed and not QBLastD
            local ltJustPressed = ltPressed and not QBLastLT
            local rtJustPressed = rtPressed and not QBLastRT
            QBLastA, QBLastD, QBLastW = aPressed, dPressed, wPressed
            QBLastLT, QBLastRT = ltPressed, rtPressed
            local justMovedLeft = aJustPressed or ltJustPressed
            local justMovedRight = dJustPressed or rtJustPressed
            local isForward = wPressed or lsForward
            local currentTime = tick()
            if isInAir and QuickBoostCount < 2 and (currentTime - QuickBoostLastTime) > 0.15 then
                local boostTriggered = false
                local boostMultiplier = 1
                if (justMovedLeft or justMovedRight) and isForward and BugJumpEnabled then boostTriggered = true boostMultiplier = 1.5
                elseif justMovedLeft or justMovedRight then boostTriggered = true boostMultiplier = 1 end
                if boostTriggered then
                    QuickBoostLastTime = currentTime
                    QuickBoostCount = QuickBoostCount + 1
                    local currentVel = root.AssemblyLinearVelocity
                    local camera = workspace.CurrentCamera
                    local forward = camera.CFrame.LookVector
                    local forwardHorizontal = Vector3.new(forward.X, 0, forward.Z).Unit
                    local upBoost = QuickBoostPower * boostMultiplier
                    local fwdBoost = QuickBoostForward * boostMultiplier
                    local boostVel = Vector3.new(forwardHorizontal.X * fwdBoost, upBoost, forwardHorizontal.Z * fwdBoost)
                    root.AssemblyLinearVelocity = currentVel + boostVel
                end
            end
        end)
    else
        CleanupConnection(_G.StarSpace.HelperConnections.QuickBoost)
        _G.StarSpace.HelperConnections.QuickBoost = nil
    end
    UI.Slide("Quick Boost", "Quick Boost " .. (v and "ON" or "OFF"))
end

local function SmoothSpin(rootPart, degrees, duration)
    if IsSpinning then return end
    if duration < 0.05 then
        local rotateRad = math.rad(degrees)
        rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, rotateRad, 0)
        return
    end
    IsSpinning = true
    local startCFrame = rootPart.CFrame
    local targetRotation = math.rad(degrees)
    local elapsed = 0
    task.spawn(function()
        pcall(function()
            while elapsed < duration and rootPart and rootPart.Parent do
                local dt = RunService.Heartbeat:Wait()
                elapsed = elapsed + dt
                local progress = math.min(elapsed / duration, 1)
                local easedProgress = 1 - (1 - progress) * (1 - progress)
                local currentRotation = targetRotation * easedProgress
                local pos = rootPart.Position
                local _, originalY, _ = startCFrame:ToEulerAnglesYXZ()
                rootPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, originalY + currentRotation, 0)
            end
        end)
        IsSpinning = false
    end)
end

local function AutoSpinLogic(v)
    AutoSpinJumpEnabled = v
    if v then
        CleanupConnection(_G.StarSpace.HelperConnections.AutoSpin)
        _G.StarSpace.HelperConnections.AutoSpin = RunService.Heartbeat:Connect(function()
            local char = game.Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
            if not hum or not root then return end
            local state = hum:GetState()
            local isOnGround = state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed or hum.FloorMaterial ~= Enum.Material.Air
            if isOnGround and not IsSpinning then
                local sPressed = UserInputService:IsKeyDown(Enum.KeyCode.S)
                local aPressed = UserInputService:IsKeyDown(Enum.KeyCode.A)
                local dPressed = UserInputService:IsKeyDown(Enum.KeyCode.D)
                local wPressed = UserInputService:IsKeyDown(Enum.KeyCode.W)
                local ltPressed, rtPressed, lsBackward, lsLeft, lsRight, lsForward = false, false, false, false, false, false
                pcall(function()
                    ltPressed = UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2)
                    rtPressed = UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
                    local gamepadState = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
                    for _, input in ipairs(gamepadState) do
                        if input.KeyCode == Enum.KeyCode.Thumbstick1 then
                            lsForward = input.Position.Y > 0.3 lsBackward = input.Position.Y < -0.3
                            lsLeft = input.Position.X < -0.3 lsRight = input.Position.X > 0.3
                            break
                        end
                    end
                end)
                local spinLeft = (sPressed and aPressed and wPressed) or ltPressed or (lsBackward and lsLeft and lsForward)
                local spinRight = (sPressed and dPressed and wPressed) or rtPressed or (lsBackward and lsRight and lsForward)
                local currentTime = tick()
                if (spinLeft or spinRight) and (currentTime - SpinJumpLastTime) > 0.1 then
                    SpinJumpLastTime = currentTime
                    local spinDirection = spinLeft and -1 or 1
                    local spinDegree = SpinDegreeOptions[CurrentSpinIndex]
                    SmoothSpin(root, spinDegree * spinDirection, SpinDuration)
                    local jumpDelay = SpinDuration > 0.05 and SpinDuration or 0
                    task.delay(jumpDelay, function()
                        if hum and hum.Parent and root and root.Parent then
                            hum:ChangeState(Enum.HumanoidStateType.Jumping)
                            task.delay(0.05, function()
                                if root and root.Parent then
                                    local currentVel = root.AssemblyLinearVelocity
                                    local camera = workspace.CurrentCamera
                                    local camLook = camera and camera.CFrame.LookVector or root.CFrame.LookVector
                                    local horizontalLook = Vector3.new(camLook.X, 0, camLook.Z)
                                    if horizontalLook.Magnitude > 0.1 then horizontalLook = horizontalLook.Unit end
                                    local boostedY = currentVel.Y + QuickBoostPower
                                    local boostedX = currentVel.X + horizontalLook.X * QuickBoostForward
                                    local boostedZ = currentVel.Z + horizontalLook.Z * QuickBoostForward
                                    root.AssemblyLinearVelocity = Vector3.new(boostedX, boostedY, boostedZ)
                                end
                            end)
                        end
                    end)
                end
            end
        end)
    else
        CleanupConnection(_G.StarSpace.HelperConnections.AutoSpin)
        _G.StarSpace.HelperConnections.AutoSpin = nil
    end
    UI.Slide("Spin Assist", "Auto Spin+Jump " .. (v and "ON" or "OFF"))
end

local function MomentumLogic(v)
    MomentumEnabled = v
    if v then
        LockedSpeed = nil
        CleanupConnection(_G.StarSpace.HelperConnections.Momentum)
        _G.StarSpace.HelperConnections.Momentum = RunService.Heartbeat:Connect(function()
            local char = game.Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
            if not hum or not root then return end
            if hum.MoveDirection.Magnitude > 0.1 then
                local vel = root.AssemblyLinearVelocity
                local horizontalSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
                if LockedSpeed == nil then LockedSpeed = horizontalSpeed end
                if horizontalSpeed < LockedSpeed then
                    local moveDir = hum.MoveDirection.Unit
                    root.AssemblyLinearVelocity = Vector3.new(moveDir.X * LockedSpeed, vel.Y, moveDir.Z * LockedSpeed)
                elseif horizontalSpeed > LockedSpeed + 1 then LockedSpeed = LockedSpeed + 1 end
            else LockedSpeed = nil end
        end)
    else
        CleanupConnection(_G.StarSpace.HelperConnections.Momentum)
        _G.StarSpace.HelperConnections.Momentum = nil
        LockedSpeed = nil
    end
    UI.Slide("Safety", "Always Momentum " .. (v and "ON" or "OFF"))
end

local function AntiSlipLogic(v)
    AntiSlipEnabled = v
    if v then
        AntiSlipLastSafeY = nil
        CleanupConnection(_G.StarSpace.HelperConnections.AntiSlip)
        _G.StarSpace.HelperConnections.AntiSlip = RunService.Heartbeat:Connect(function()
            local char = game.Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
            if not hum or not root then return end
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {char}
            params.FilterType = Enum.RaycastFilterType.Exclude
            local playerPos = root.Position
            local halfSize = AntiSlipSize / 2
            local rayPositions = {playerPos, playerPos + Vector3.new(halfSize, 0, 0), playerPos + Vector3.new(-halfSize, 0, 0), playerPos + Vector3.new(0, 0, halfSize), playerPos + Vector3.new(0, 0, -halfSize)}
            local foundGround, highestY = false, -math.huge
            for _, pos in ipairs(rayPositions) do
                local ray = workspace:Raycast(pos, Vector3.new(0, -50, 0), params)
                if ray and ray.Instance and not ray.Instance:IsA("Terrain") then
                    foundGround = true
                    if ray.Position.Y > highestY then highestY = ray.Position.Y end
                end
            end
            if foundGround then AntiSlipLastSafeY = highestY + 3 end
            if AntiSlipLastSafeY then
                local vel = root.AssemblyLinearVelocity
                local state = hum:GetState()
                local isJumping = state == Enum.HumanoidStateType.Jumping or vel.Y > 1
                if not isJumping and root.Position.Y < AntiSlipLastSafeY - 0.3 and vel.Y < 0 then
                    root.CFrame = CFrame.new(root.Position.X, AntiSlipLastSafeY, root.Position.Z) * (root.CFrame - root.CFrame.Position)
                    root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end
        end)
    else
        CleanupConnection(_G.StarSpace.HelperConnections.AntiSlip)
        _G.StarSpace.HelperConnections.AntiSlip = nil
        AntiSlipLastSafeY = nil
    end
    UI.Slide("Safety", "Anti-Slip " .. (v and "ON" or "OFF"))
end

local function AntiRagdollLogic(v)
    AntiRagdollEnabled = v
    if v then
        CleanupConnection(_G.StarSpace.HelperConnections.AntiRagdoll)
        _G.StarSpace.HelperConnections.AntiRagdoll = RunService.Heartbeat:Connect(function()
            local char = game.Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
            if hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                if root and root.AssemblyLinearVelocity.Magnitude > AntiRagdollMaxVel then
                    root.AssemblyLinearVelocity = root.AssemblyLinearVelocity.Unit * AntiRagdollMaxVel
                end
            end
        end)
    else
        CleanupConnection(_G.StarSpace.HelperConnections.AntiRagdoll)
        _G.StarSpace.HelperConnections.AntiRagdoll = nil
        local hum = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end
    end
    UI.Slide("Safety", "Anti-Ragdoll " .. (v and "ON" or "OFF"))
end

local function RealESPLogic(v)
    RealESPEnabled = v
    if v then
        if not ESPContainer then
            ESPContainer = Instance.new("Folder")
            ESPContainer.Name = "StarSpace_ESP"
            ESPContainer.Parent = game.CoreGui
        end
        
        CleanupConnection(_G.StarSpace.HelperConnections.RealESP)
        _G.StarSpace.HelperConnections.RealESP = RunService.Stepped:Connect(function()
            local char = game.Players.LocalPlayer.Character
            local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
            if not root then return end
            
            -- Clear old highlights that are too far or invalid
            for part, highlight in pairs(HighlightedParts) do
                if not part or not part.Parent or (part.Position - root.Position).Magnitude > 150 then
                    if highlight then highlight:Destroy() end
                    HighlightedParts[part] = nil
                end
            end
            
            -- Scan nearby parts
            local overlapParams = OverlapParams.new()
            overlapParams.FilterDescendantsInstances = {char, ESPContainer}
            overlapParams.FilterType = Enum.RaycastFilterType.Exclude
            
            local parts = workspace:GetPartBoundsInRadius(root.Position, 100, overlapParams)
            for _, part in ipairs(parts) do
                -- Explicitly ignore character parts (double check) and other players
                -- Check if part belongs to a Model with a Humanoid (covers accessories, tools, limbs)
                local characterModel = part:FindFirstAncestorOfClass("Model")
                if characterModel and characterModel:FindFirstChildOfClass("Humanoid") then
                    continue 
                end

                if part:IsA("BasePart") and not HighlightedParts[part] and part.Transparency < 1 then
                    local color = nil
                    if not part.CanCollide then
                        color = Color3.fromRGB(255, 0, 0) -- Red (Fake)
                    elseif part:IsA("TrussPart") or part.Name:lower():find("ladder") then
                         color = Color3.fromRGB(0, 255, 255) -- Cyan (Ladder)
                    else
                        color = Color3.fromRGB(0, 255, 0) -- Green (Safe)
                    end
                    
                    if color then
                        local h = Instance.new("BoxHandleAdornment")
                        h.Name = "ESP"
                        h.Adornee = part
                        h.AlwaysOnTop = true
                        h.ZIndex = 0
                        h.Size = part.Size
                        h.Transparency = 0.5
                        h.Color3 = color
                        h.Parent = ESPContainer
                        HighlightedParts[part] = h
                    end
                end
            end
        end)
    else
        CleanupConnection(_G.StarSpace.HelperConnections.RealESP)
        _G.StarSpace.HelperConnections.RealESP = nil
        if ESPContainer then ESPContainer:Destroy() ESPContainer = nil end
        HighlightedParts = {}
    end
    UI.Slide("Visuals", "Real Path ESP " .. (v and "ON" or "OFF"))
end

local QuickBoostToggle = Helper:AddToggle("Quick Boost (A/D or L2/R2)", {Default = true, Flag = "QuickBoost"}, function(v)
    RunLogic("QuickBoost", QuickBoostLogic, v)
end)
Helper:AddKeybind("Quick Boost Keybind", { Default = Enum.KeyCode.B, Flag = "QuickBoostKey" }, function()
    local newVal = not (FeatureStates["QuickBoost"] or false)
    print("[StarSpace] Keybind -> Toggling QuickBoost to:", newVal)
    if QuickBoostToggle and QuickBoostToggle.Set then
        QuickBoostToggle:Set(newVal)
    end
    RunLogic("QuickBoost", QuickBoostLogic, newVal)
end)

Helper:AddSlider("   └ Boost Power", {Min = 0, Max = 25, Default = 5, Flag = "BoostPower"}, function(v) QuickBoostPower = v end)
Helper:AddSlider("   └ Forward Momentum", {Min = 0, Max = 20, Default = 2, Flag = "BoostForward"}, function(v) QuickBoostForward = v end)
Helper:AddToggle("Bug Jump (A/D+W = 1.5x)", {Default = true, Flag = "BugJump"}, function(v) BugJumpEnabled = v end)
Helper:AddParagraph("   ℹ️ Boost Usage", "Press A/D or L2/R2 in mid-air for a sudden burst of speed. Combine with W or Stick Up to trigger a 1.5x Bug Jump boost.")

Helper:AddSection("🔄 Auto Spin+Jump")

local AutoSpinToggle = Helper:AddToggle("Auto Spin+Jump (L2/R2)", {Default = true, Flag = "AutoSpinJump"}, function(v)
    RunLogic("AutoSpin", AutoSpinLogic, v)
end)
Helper:AddKeybind("Auto Spin Keybind", { Default = Enum.KeyCode.K, Flag = "AutoSpinKey" }, function()
    local newVal = not (FeatureStates["AutoSpin"] or false)
    print("[StarSpace] Keybind -> Toggling AutoSpin to:", newVal)
    if AutoSpinToggle and AutoSpinToggle.Set then
        AutoSpinToggle:Set(newVal)
    end
    RunLogic("AutoSpin", AutoSpinLogic, newVal)
end)

Helper:AddDropdown("   └ Spin Degree", {Options = {"45°", "90°", "180°", "360°"}, Default = "90°"}, function(v)
    if v == "45°" then CurrentSpinIndex = 1 elseif v == "90°" then CurrentSpinIndex = 2 elseif v == "180°" then CurrentSpinIndex = 3 elseif v == "360°" then CurrentSpinIndex = 4 end
end)
Helper:AddSlider("   └ Spin Speed", {Min = 0, Max = 50, Default = 5, Suffix = "ms"}, function(v) SpinDuration = v / 100 end)
Helper:AddParagraph("   ℹ️ Spin Usage", "Hold S + A/D + W on ground (or L2/R2 on Gamepad). Your character will perform a spin and then auto-jump with a powerful boost.")

Helper:AddSection("🛡️ Momentum & Safety")

local MomentumToggle = Helper:AddToggle("Always Momentum", {Default = false, Flag = "AlwaysMomentum"}, function(v)
    RunLogic("Momentum", MomentumLogic, v)
end)
Helper:AddKeybind("Momentum Keybind", { Default = Enum.KeyCode.M, Flag = "MomentumKey" }, function()
    local newVal = not (FeatureStates["Momentum"] or false)
    print("[StarSpace] Keybind -> Toggling Momentum to:", newVal)
    if MomentumToggle and MomentumToggle.Set then
        MomentumToggle:Set(newVal)
    end
    RunLogic("Momentum", MomentumLogic, newVal)
end)

local AntiSlipToggle = Helper:AddToggle("Anti-Slip (Edge Guard)", {Default = false, Flag = "AntiSlip"}, function(v)
    RunLogic("AntiSlip", AntiSlipLogic, v)
end)
Helper:AddKeybind("Anti-Slip Keybind", { Default = Enum.KeyCode.N, Flag = "AntiSlipKey" }, function()
    local newVal = not (FeatureStates["AntiSlip"] or false)
    print("[StarSpace] Keybind -> Toggling AntiSlip to:", newVal)
    if AntiSlipToggle and AntiSlipToggle.Set then
        AntiSlipToggle:Set(newVal)
    end
    RunLogic("AntiSlip", AntiSlipLogic, newVal)
end)
Helper:AddSlider("   └ Detection Radius", {Min = 1, Max = 10, Default = 3, Flag = "SlipSize"}, function(v) AntiSlipSize = v end)

local AntiRagdollToggle = Helper:AddToggle("Anti-Ragdoll / Fling", {Default = false, Flag = "AntiRagdoll"}, function(v)
    RunLogic("AntiRagdoll", AntiRagdollLogic, v)
end)
Helper:AddKeybind("Anti-Ragdoll Keybind", { Default = Enum.KeyCode.R, Flag = "AntiRagdollKey" }, function()
    local newVal = not (FeatureStates["AntiRagdoll"] or false)
    print("[StarSpace] Keybind -> Toggling AntiRagdoll to:", newVal)
    if AntiRagdollToggle and AntiRagdollToggle.Set then
        AntiRagdollToggle:Set(newVal)
    end
    RunLogic("AntiRagdoll", AntiRagdollLogic, newVal)
end)
Helper:AddSlider("   └ Max Speed Cap", {Min = 50, Max = 200, Default = 100, Flag = "MaxVel"}, function(v) AntiRagdollMaxVel = v end)

Helper:AddSection("👁️ Real Path ESP")

local RealESPToggle = Helper:AddToggle("Real Path ESP", {Default = false, Flag = "RealPathESP"}, function(v)
    RunLogic("RealESP", RealESPLogic, v)
end)
Helper:AddKeybind("Real ESP Keybind", { Default = Enum.KeyCode.P, Flag = "RealESPKey" }, function()
    local newVal = not (FeatureStates["RealESP"] or false)
    print("[StarSpace] Keybind -> Toggling RealESP to:", newVal)
    if RealESPToggle and RealESPToggle.Set then
        RealESPToggle:Set(newVal)
    end
    RunLogic("RealESP", RealESPLogic, newVal)
end)

Helper:AddParagraph("   ℹ️ Color Guide", "🟢 Green = Safe Platform\n🔵 Cyan = Ladder (walkable)\n🟠 Orange = Ladder (climb only)\n🔴 Red = Fake/Non-collision")

-- ================================================
-- FUN TAB - Fun Features (Adapted from Fun.lua)
-- ================================================
_G.StarSpace.FunConnections = {}

-- Helper function to cleanup connections
local function CleanupFunConnection(conn)
    if conn then
        pcall(function() conn:Disconnect() end)
    end
end

-- === TOUCH FLING SECTION ===
Fun:AddSection("🎯 Touch Fling")

local isFling = false
local flingLoop = nil
local isHitboxExpanded = false
local hitboxParts = {}

Fun:AddToggle("Fling Mode", {Default = false}, function(v)
    isFling = v
    local LocalPlayer = game.Players.LocalPlayer
    
    if isFling then
        flingLoop = game:GetService("RunService").Heartbeat:Connect(function()
            local c = LocalPlayer.Character
            if not c then return end
            
            local hrp = c:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            
            -- Save current velocity
            local currentVel = hrp.Velocity
            
            -- Apply massive velocity burst
            hrp.Velocity = currentVel * 10000 + Vector3.new(0, 10000, 0)
            
            -- Apply to hitbox parts too if expanded
            if isHitboxExpanded then
                for _, part in pairs(hitboxParts) do
                    if part and part.Parent then
                        part.Velocity = hrp.Velocity
                    end
                end
            end
            
            -- Wait 1 render frame
            game:GetService("RunService").RenderStepped:Wait()
            
            -- Restore velocity if still exists
            if c and c.Parent and hrp and hrp.Parent then
                hrp.Velocity = currentVel
            end
            
            -- Small oscillation for better fling effect
            game:GetService("RunService").Stepped:Wait()
            if c and c.Parent and hrp and hrp.Parent then
                hrp.Velocity = currentVel + Vector3.new(0, 0.1, 0)
            end
        end)
        table.insert(_G.StarSpace.FunConnections, flingLoop)
        UI.Slide("Fling", "Touch Fling ENABLED - Touch players to fling them!")
    else
        if flingLoop then
            flingLoop:Disconnect()
            flingLoop = nil
        end
        
        -- Reset velocity
        local c = LocalPlayer.Character
        if c then
            local hrp = c:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Velocity = Vector3.new(0, 0, 0)
                hrp.RotVelocity = Vector3.new(0, 0, 0)
            end
        end
        UI.Slide("Fling", "Touch Fling DISABLED")
    end
end)

Fun:AddToggle("Expand Hitbox", {Default = false}, function(v)
    isHitboxExpanded = v
    local LocalPlayer = game.Players.LocalPlayer
    local c = LocalPlayer.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if isHitboxExpanded then
        -- Create invisible expanded hitbox
        for i = 1, 4 do
            local part = Instance.new("Part")
            part.Name = "HitboxExpander"
            part.Size = Vector3.new(4, 4, 0.5)
            part.Transparency = 1
            part.CanCollide = true
            part.Massless = true
            part.Parent = c
            
            -- Weld to HumanoidRootPart
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = hrp
            weld.Part1 = part
            weld.Parent = part
            
            table.insert(hitboxParts, part)
        end
        
        -- Position parts around character (front, back, left, right)
        if hitboxParts[1] then hitboxParts[1].CFrame = hrp.CFrame * CFrame.new(0, 0, -3) end
        if hitboxParts[2] then hitboxParts[2].CFrame = hrp.CFrame * CFrame.new(0, 0, 3) end
        if hitboxParts[3] then hitboxParts[3].CFrame = hrp.CFrame * CFrame.new(-3, 0, 0) end
        if hitboxParts[4] then hitboxParts[4].CFrame = hrp.CFrame * CFrame.new(3, 0, 0) end
        
        UI.Slide("Hitbox", "Hitbox Expanded!")
    else
        -- Remove hitbox parts
        for _, part in pairs(hitboxParts) do
            if part and part.Parent then
                part:Destroy()
            end
        end
        hitboxParts = {}
        UI.Slide("Hitbox", "Hitbox Reset!")
    end
end)

Fun:AddParagraph("Fling Info", "Enable Fling Mode then touch players to fling them!\nExpand Hitbox makes it easier to touch players.")

-- === INVISIBLE SECTION ===
Fun:AddSection("👻 Invisible")

local isInvis = false
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

Fun:AddToggle("Invisible", {Default = false}, function(v)
    isInvis = v
    local LocalPlayer = game.Players.LocalPlayer
    local character = LocalPlayer.Character
    if not character then 
        UI.Slide("Error", "No character found!")
        return 
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then 
        UI.Slide("Error", "Character parts not found!")
        return 
    end
    
    if isInvis then
        -- Save current position
        local savedPosition = hrp.CFrame
        
        -- Move to invisible position using MoveTo (replicates to server)
        character:MoveTo(INVIS_POSITION)
        task.wait(0.15)
        
        -- Create seat at current character position
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
        weld.Part1 = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
        weld.Parent = seat
        
        task.wait()
        
        -- Move seat (and welded character) back to saved position
        seat.CFrame = savedPosition
        
        -- Visual feedback - make semi-transparent locally
        setCharacterTransparency(character, 0.5)
        
        UI.Slide("Invisible", "You are now INVISIBLE to others!")
    else
        -- Destroy the invisible chair
        local invisChair = workspace:FindFirstChild("invischair")
        if invisChair then
            invisChair:Destroy()
        end
        
        -- Restore transparency
        if LocalPlayer.Character then
            setCharacterTransparency(LocalPlayer.Character, 0)
        end
        
        UI.Slide("Invisible", "Invisible mode DISABLED")
    end
end)

Fun:AddParagraph("Invisible Info", "Makes you invisible to other players using the seat weld method.\nYou will appear semi-transparent locally as a visual indicator.")

-- === TELEPORT TO PLAYER SECTION ===
Fun:AddSection("📍 Teleport to Player")

local TeleportTargetPlayer = nil
local AllPlayers = {}

local function GetPlayerNames()
    AllPlayers = {}
    local names = {"-- Select Player --"} -- Placeholder first
    for _, p in pairs(game.Players:GetPlayers()) do
        if p ~= game.Players.LocalPlayer then
            local displayText = p.DisplayName .. " (@" .. p.Name .. ")"
            table.insert(names, displayText)
            AllPlayers[displayText] = p
        end
    end
    return names
end

local TpDropdown = Fun:AddDropdown("Select Player", {Options = GetPlayerNames(), Default = "-- Select Player --"}, function(v)
    if v ~= "-- Select Player --" then
        TeleportTargetPlayer = AllPlayers[v]
    else
        TeleportTargetPlayer = nil
    end
end)

Fun:AddRetroButton({Name = "🔄 Refresh Player List", Callback = function()
    if TpDropdown.SetOptions then
        TpDropdown:SetOptions(GetPlayerNames())
    end
    UI.Slide("Refresh", "Player list refreshed!")
end})

Fun:AddRetroButton({Name = "📍 Teleport", Callback = function()
    if not TeleportTargetPlayer then
        UI.Slide("Error", "Please select a player first!")
        return
    end
    
    if not TeleportTargetPlayer.Parent then
        UI.Slide("Error", "Player left the game!")
        TeleportTargetPlayer = nil
        return
    end
    
    local LocalPlayer = game.Players.LocalPlayer
    local myChar = LocalPlayer.Character
    if not myChar then
        UI.Slide("Error", "Your character not found!")
        return
    end
    
    local targetChar = TeleportTargetPlayer.Character
    if not targetChar then
        UI.Slide("Error", "Target character not loaded!")
        return
    end
    
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    
    if not myRoot or not targetRoot then
        UI.Slide("Error", "Character parts not found!")
        return
    end
    
    -- Calculate distance
    local distance = (targetRoot.Position - myRoot.Position).Magnitude
    local targetPos = targetRoot.CFrame * CFrame.new(0, 0, 3) -- 3 studs in front
    
    -- Multi-step teleport to bypass anti-cheat
    if distance > 100 then
        UI.Slide("Teleport", "Teleporting in steps...")
        local steps = math.ceil(distance / 100)
        local startPos = myRoot.CFrame
        
        for i = 1, steps do
            local alpha = i / steps
            local intermediatePos = startPos:Lerp(targetPos, alpha)
            myRoot.CFrame = intermediatePos
            task.wait(0.05)
        end
    else
        myRoot.CFrame = targetPos
    end
    
    UI.Slide("Teleport", "Teleported to " .. TeleportTargetPlayer.Name .. "!")
end})

-- === SPECTATE PLAYER SECTION ===
Fun:AddSection("👁 Spectate Player")

local SpectateTargetPlayer = nil
local isSpectating = false
local spectateLoop = nil

local SpectateDropdown = Fun:AddDropdown("Select Player", {Options = GetPlayerNames(), Default = "-- Select Player --"}, function(v)
    if v ~= "-- Select Player --" then
        SpectateTargetPlayer = AllPlayers[v]
    else
        SpectateTargetPlayer = nil
    end
end)

Fun:AddRetroButton({Name = "🔄 Refresh Player List", Callback = function()
    if SpectateDropdown.SetOptions then
        SpectateDropdown:SetOptions(GetPlayerNames())
    end
    UI.Slide("Refresh", "Player list refreshed!")
end})

Fun:AddToggle("Spectate", {Default = false}, function(v)
    isSpectating = v
    local LocalPlayer = game.Players.LocalPlayer
    
    if isSpectating then
        if not SpectateTargetPlayer then
            UI.Slide("Error", "Please select a player first!")
            return
        end
        
        if not SpectateTargetPlayer.Parent then
            UI.Slide("Error", "Player left the game!")
            SpectateTargetPlayer = nil
            return
        end
        
        -- Try to request streaming around target
        task.spawn(function()
            local targetChar = SpectateTargetPlayer.Character
            if targetChar then
                local hrp = targetChar:FindFirstChild("HumanoidRootPart")
                if hrp then
                    pcall(function()
                        LocalPlayer:RequestStreamAroundAsync(hrp.Position, 5)
                    end)
                end
            end
        end)
        
        spectateLoop = game:GetService("RunService").RenderStepped:Connect(function()
            if not SpectateTargetPlayer or not SpectateTargetPlayer.Parent then
                isSpectating = false
                if spectateLoop then
                    spectateLoop:Disconnect()
                    spectateLoop = nil
                end
                UI.Slide("Spectate", "Player left!")
                return
            end
            
            local targetChar = SpectateTargetPlayer.Character
            local camera = workspace.CurrentCamera
            
            if targetChar then
                local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
                local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
                
                if targetHum then
                    camera.CameraSubject = targetHum
                elseif targetHRP then
                    camera.CameraSubject = targetHRP
                end
            end
        end)
        table.insert(_G.StarSpace.FunConnections, spectateLoop)
        UI.Slide("Spectate", "Spectating " .. SpectateTargetPlayer.Name)
    else
        if spectateLoop then
            spectateLoop:Disconnect()
            spectateLoop = nil
        end
        
        -- Reset camera to self
        local myChar = LocalPlayer.Character
        if myChar then
            local myHum = myChar:FindFirstChildOfClass("Humanoid")
            if myHum then
                workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                workspace.CurrentCamera.CameraSubject = myHum
            end
        end
        UI.Slide("Spectate", "Spectate stopped")
    end
end)

Fun:AddParagraph("Spectate Info", "Watch another player's view.\nThe camera will follow them around the map.")

-- === UTILITIES SECTION ===
Fun:AddSection("🛠 Utilities")

Fun:AddRetroButton({Name = "Respawn", Callback = function()
    local LocalPlayer = game.Players.LocalPlayer
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Health = 0
        end
    end
    UI.Slide("Respawn", "Respawning...")
end})

Fun:AddRetroButton({Name = "Reset Velocity", Callback = function()
    local LocalPlayer = game.Players.LocalPlayer
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Velocity = Vector3.new(0, 0, 0)
            hrp.RotVelocity = Vector3.new(0, 0, 0)
            if hrp.AssemblyLinearVelocity then
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end
    end
    UI.Slide("Reset", "Velocity reset!")
end})

Fun:AddRetroButton({Name = "Get Server Players", Callback = function()
    local count = #game.Players:GetPlayers()
    local names = {}
    for _, p in pairs(game.Players:GetPlayers()) do
        table.insert(names, p.Name)
    end
    UI.Slide("Players (" .. count .. ")", table.concat(names, ", "))
end})

Fun:AddToggle("No Clip", {Default = false}, function(v)
    local LocalPlayer = game.Players.LocalPlayer
    local RunService = game:GetService("RunService")
    
    if v then
        _G.StarSpace.FunConnections.NoClip = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        UI.Slide("No Clip", "No Clip ENABLED")
    else
        if _G.StarSpace.FunConnections.NoClip then
            _G.StarSpace.FunConnections.NoClip:Disconnect()
            _G.StarSpace.FunConnections.NoClip = nil
        end
        -- Restore collision
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CanCollide = true end
            local head = char:FindFirstChild("Head")
            if head then head.CanCollide = true end
        end
        UI.Slide("No Clip", "No Clip DISABLED")
    end
end)

-- === FRIENDS IN SERVER SECTION ===
Fun:AddSection("👥 Friends in Server")

-- Friend ESP System (CS:GO Style - Lines from above)
local FriendESPEnabled = false
local FriendESPLines = {}
local FriendESPLoop = nil
local FriendPairs = {} -- Stores confirmed friend pairs

-- Create overhead connection line (CS:GO style)
local function CreateFriendLine(player1, player2)
    local key = player1.UserId < player2.UserId 
        and (player1.UserId .. "_" .. player2.UserId) 
        or (player2.UserId .. "_" .. player1.UserId)
    
    if FriendESPLines[key] then return end
    
    -- Create anchor part for overhead position (invisible)
    local anchorPart = Instance.new("Part")
    anchorPart.Name = "FriendESP_Anchor_" .. key
    anchorPart.Anchored = true
    anchorPart.CanCollide = false
    anchorPart.CanQuery = false
    anchorPart.Transparency = 1
    anchorPart.Size = Vector3.new(0.1, 0.1, 0.1)
    anchorPart.Parent = workspace.Terrain
    
    local att1 = Instance.new("Attachment", anchorPart)
    att1.Name = "FriendESP_Att1"
    
    local att2 = Instance.new("Attachment", anchorPart)
    att2.Name = "FriendESP_Att2"
    
    -- Create the beam (line)
    local beam = Instance.new("Beam")
    beam.Name = "FriendESP_" .. key
    beam.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 100)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 255, 180)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 100))
    })
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.4),
        NumberSequenceKeypoint.new(1, 0.2)
    })
    beam.Width0 = 0.08
    beam.Width1 = 0.08
    beam.FaceCamera = true
    beam.LightEmission = 0.8
    beam.LightInfluence = 0
    beam.Segments = 10
    beam.Attachment0 = att1
    beam.Attachment1 = att2
    beam.Parent = anchorPart
    
    FriendESPLines[key] = {
        Anchor = anchorPart,
        Beam = beam,
        Att1 = att1,
        Att2 = att2,
        Player1 = player1,
        Player2 = player2
    }
end

local function UpdateFriendESP()
    for key, data in pairs(FriendESPLines) do
        local p1Char = data.Player1 and data.Player1.Character
        local p2Char = data.Player2 and data.Player2.Character
        local p1Head = p1Char and p1Char:FindFirstChild("Head")
        local p2Head = p2Char and p2Char:FindFirstChild("Head")
        
        if p1Head and p2Head and data.Player1.Parent and data.Player2.Parent then
            -- CS:GO style: line goes UP from player1's head, then DOWN to player2's head
            local p1Pos = p1Head.Position
            local p2Pos = p2Head.Position
            
            -- Calculate midpoint above both players
            local midX = (p1Pos.X + p2Pos.X) / 2
            local midZ = (p1Pos.Z + p2Pos.Z) / 2
            local maxY = math.max(p1Pos.Y, p2Pos.Y) + 15 -- 15 studs above the highest player
            
            -- Position anchor at midpoint
            data.Anchor.Position = Vector3.new(midX, maxY, midZ)
            
            -- Set attachment positions relative to anchor
            -- Att1 goes down to player1's head
            data.Att1.WorldPosition = p1Pos + Vector3.new(0, 2, 0)
            -- Att2 goes down to player2's head  
            data.Att2.WorldPosition = p2Pos + Vector3.new(0, 2, 0)
            
            data.Beam.Enabled = true
        else
            data.Beam.Enabled = false
        end
    end
end

local function ClearFriendESP()
    for key, data in pairs(FriendESPLines) do
        pcall(function() data.Anchor:Destroy() end) -- This destroys beam and attachments too
    end
    FriendESPLines = {}
    FriendPairs = {}
end

local function ScanFriendships()
    local Players = game:GetService("Players")
    local allPlayers = Players:GetPlayers()
    local scanned = {}
    
    for _, player1 in pairs(allPlayers) do
        for _, player2 in pairs(allPlayers) do
            if player1 ~= player2 then
                local key = player1.UserId < player2.UserId 
                    and (player1.UserId .. "_" .. player2.UserId) 
                    or (player2.UserId .. "_" .. player1.UserId)
                
                if not scanned[key] then
                    scanned[key] = true
                    local success, isFriend = pcall(function()
                        return player1:IsFriendsWith(player2.UserId)
                    end)
                    if success and isFriend then
                        FriendPairs[key] = {player1, player2}
                        CreateFriendLine(player1, player2)
                    end
                end
            end
        end
    end
end

Fun:AddToggle("🔗 Friend ESP (Lines)", {Default = false}, function(v)
    FriendESPEnabled = v
    
    if v then
        UI.Slide("Friend ESP", "⏳ Scanning friendships...")
        
        task.spawn(function()
            task.wait(0.1) -- Small delay so loading notification appears first
            ScanFriendships()
            
            local friendCount = 0
            for _ in pairs(FriendPairs) do friendCount = friendCount + 1 end
            
            if friendCount > 0 then
                UI.Slide("Friend ESP", "✅ Found " .. friendCount .. " friend connections!")
            else
                UI.Slide("Friend ESP", "⚠️ No friends found in server")
            end
            
            -- Start update loop
            if FriendESPLoop then FriendESPLoop:Disconnect() end
            FriendESPLoop = game:GetService("RunService").RenderStepped:Connect(function()
                if FriendESPEnabled then
                    UpdateFriendESP()
                end
            end)
            table.insert(_G.StarSpace.FunConnections, FriendESPLoop)
        end)
    else
        if FriendESPLoop then
            FriendESPLoop:Disconnect()
            FriendESPLoop = nil
        end
        ClearFriendESP()
        UI.Slide("Friend ESP", "Friend ESP DISABLED")
    end
end)

Fun:AddParagraph("Friends Info", "Shows which players in the server are friends with each other.\nThe ESP draws green lines between players who are friends.\nUseful for detecting teams or friend groups.")

-- === AUTO FOLLOW SECTION ===
Fun:AddSection("🚶 Auto Follow Player")

local FollowTargetPlayer = nil
local isFollowing = false
local followLoop = nil
local mirrorAnimLoop = nil
local exactCopyMode = false -- Default: Exact position mode
local followDistance = 4 -- Distance behind target when not in exact mode

-- Helper functions
local function getHRP(char) return char and char:FindFirstChild("HumanoidRootPart") end
local function getHum(char) return char and char:FindFirstChildOfClass("Humanoid") end

local function computeIdealBehind(targetHRP, distance)
    local look = targetHRP.CFrame.LookVector
    local behindPos = targetHRP.Position - (look * distance) + Vector3.new(0, 0, 0)
    local frontPoint = behindPos + look
    return CFrame.new(behindPos, frontPoint)
end

local FollowDropdown = Fun:AddDropdown("Select Player to Follow", {Options = GetPlayerNames(), Default = "-- Select Player --"}, function(v)
    if v ~= "-- Select Player --" then
        FollowTargetPlayer = AllPlayers[v]
    else
        FollowTargetPlayer = nil
    end
end)

Fun:AddRetroButton({Name = "🔄 Refresh Player List", Callback = function()
    if FollowDropdown.SetOptions then
        FollowDropdown:SetOptions(GetPlayerNames())
    end
    UI.Slide("Refresh", "Player list refreshed!")
end})

Fun:AddToggle("📍 Exact Position Mode", {Default = false}, function(v)
    exactCopyMode = v
    if v then
        UI.Slide("Follow Mode", "Exact Position: ON (Same position as target)")
    else
        UI.Slide("Follow Mode", "Exact Position: OFF (Stay behind at distance)")
    end
end)

Fun:AddSlider("   └ Follow Distance", {Min = 2, Max = 20, Default = 4}, function(v)
    followDistance = v
end)

Fun:AddToggle("🚶 Auto Follow", {Default = false}, function(v)
    isFollowing = v
    local LocalPlayer = game.Players.LocalPlayer
    local RunService = game:GetService("RunService")
    
    if isFollowing then
        if not FollowTargetPlayer then
            UI.Slide("Error", "Please select a player first!")
            return
        end
        
        if not FollowTargetPlayer.Parent then
            UI.Slide("Error", "Player left the game!")
            FollowTargetPlayer = nil
            return
        end
        
        -- Main follow loop - using RenderStepped for smoother updates
        followLoop = RunService.RenderStepped:Connect(function(dt)
            if not isFollowing or not FollowTargetPlayer then
                return
            end
            
            if not FollowTargetPlayer.Parent then
                isFollowing = false
                if followLoop then followLoop:Disconnect() followLoop = nil end
                if mirrorAnimLoop then mirrorAnimLoop:Disconnect() mirrorAnimLoop = nil end
                UI.Slide("Follow", "Player left!")
                return
            end
            
            local myChar = LocalPlayer.Character
            local myHRP = getHRP(myChar)
            local myHum = getHum(myChar)
            
            local tChar = FollowTargetPlayer.Character
            local tHRP = getHRP(tChar)
            local tHum = getHum(tChar)
            
            if not (myHRP and myHum and tHRP and tHum and tHum.Health > 0) then
                return
            end
            
            pcall(function()
                if exactCopyMode then
                    -- Exact mode - same position and rotation as target
                    myHRP.CFrame = tHRP.CFrame
                else
                    -- Behind mode - same as exact but with distance offset behind target
                    local look = tHRP.CFrame.LookVector
                    local behindOffset = -(look * followDistance)
                    myHRP.CFrame = tHRP.CFrame + behindOffset
                end
                
                -- Common for both modes
                myHum.PlatformStand = false
                myHRP.AssemblyLinearVelocity = tHRP.AssemblyLinearVelocity
            end)
        end)
        
        -- Animation mirror loop - sync movement states with target (same for both modes)
        mirrorAnimLoop = RunService.Heartbeat:Connect(function()
            if not isFollowing or not FollowTargetPlayer then
                return
            end
            
            local myChar = LocalPlayer.Character
            local tChar = FollowTargetPlayer.Character
            if not (myChar and tChar) then return end
            
            local myHum = getHum(myChar)
            local tHum = getHum(tChar)
            
            if not (myHum and tHum) then return end
            
            pcall(function()
                -- Mirror target's movement direction for proper walking animation
                local targetMoveDir = tHum.MoveDirection
                local isMoving = targetMoveDir.Magnitude > 0.1
                
                if isMoving then
                    myHum:Move(targetMoveDir, false)
                else
                    myHum:Move(Vector3.new(0, 0, 0), false)
                end
                
                -- Copy humanoid state
                local tState = tHum:GetState()
                if tState == Enum.HumanoidStateType.Jumping then
                    myHum:ChangeState(Enum.HumanoidStateType.Jumping)
                    myHum.Jump = true
                elseif tState == Enum.HumanoidStateType.Freefall then
                    myHum:ChangeState(Enum.HumanoidStateType.Freefall)
                elseif tState == Enum.HumanoidStateType.Climbing then
                    myHum:ChangeState(Enum.HumanoidStateType.Climbing)
                elseif tState == Enum.HumanoidStateType.Seated then
                    myHum.Sit = true
                elseif tState == Enum.HumanoidStateType.Swimming then
                    myHum:ChangeState(Enum.HumanoidStateType.Swimming)
                end
                
                -- Copy JumpPower for consistent jumps
                myHum.JumpPower = tHum.JumpPower
            end)
        end)
        
        table.insert(_G.StarSpace.FunConnections, followLoop)
        table.insert(_G.StarSpace.FunConnections, mirrorAnimLoop)
        UI.Slide("Follow", "Following " .. FollowTargetPlayer.DisplayName)
    else
        if followLoop then
            followLoop:Disconnect()
            followLoop = nil
        end
        if mirrorAnimLoop then
            mirrorAnimLoop:Disconnect()
            mirrorAnimLoop = nil
        end
        
        -- Stop movement and reset state
        local myChar = game.Players.LocalPlayer.Character
        if myChar then
            local myHum = myChar:FindFirstChildOfClass("Humanoid")
            if myHum then
                myHum:Move(Vector3.new(0, 0, 0))
                myHum.PlatformStand = false
                myHum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
        UI.Slide("Follow", "Follow stopped")
    end
end)

Fun:AddParagraph("Follow Info", "Follow another player in real-time.\n• Exact Position: Copies target's exact position and animation\n• Off: Stays behind the target")

-- === CLONE AVATAR SECTION ===
Fun:AddSection("🎭 Clone Avatar")

local CloneTargetPlayer = nil
local CloneUsernameTarget = ""

Fun:AddLabel("Option 1: Clone In-Game Player")
local CloneDropdown = Fun:AddDropdown("Select Player to Clone", {Options = GetPlayerNames(), Default = "-- Select Player --"}, function(v)
    if v ~= "-- Select Player --" then
        CloneTargetPlayer = AllPlayers[v]
    else
        CloneTargetPlayer = nil
    end
end)

Fun:AddRetroButton({Name = "🔄 Refresh Player List", Callback = function()
    if CloneDropdown.SetOptions then
        CloneDropdown:SetOptions(GetPlayerNames())
    end
    UI.Slide("Refresh", "Player list refreshed!")
end})

Fun:AddLabel("Option 2: Clone by Username (Anywhere)")
Fun:AddInput("Target Username to Clone", {Placeholder = "Enter Roblox Username..."}, function(v)
    CloneUsernameTarget = v
end)

Fun:AddRetroButton({Name = "🎭 Clone Avatar", Callback = function()
    local LocalPlayer = game.Players.LocalPlayer
    local Players = game:GetService("Players")
    local targetUserId = nil
    local targetDisplayName = ""

    -- Priority 1: Use Username Input (Option 2)
    if CloneUsernameTarget ~= "" then
        UI.Slide("Clone", "Fetching " .. CloneUsernameTarget .. "'s ID...")
        local success, id = pcall(function()
            return Players:GetUserIdFromNameAsync(CloneUsernameTarget)
        end)
        
        if success and id then
            targetUserId = id
            targetDisplayName = CloneUsernameTarget
        else
            UI.Slide("Error", "User '" .. CloneUsernameTarget .. "' not found!")
            return
        end
    -- Priority 2: Use Dropdown Selection (Option 1)
    elseif CloneTargetPlayer then
        if not CloneTargetPlayer.Parent then
            UI.Slide("Error", "Selected player left the game!")
            CloneTargetPlayer = nil
            return
        end
        targetUserId = CloneTargetPlayer.UserId
        targetDisplayName = CloneTargetPlayer.Name
    else
        UI.Slide("Error", "Please enter a username OR select a player!")
        return
    end
    
    UI.Slide("Clone", "Cloning " .. targetDisplayName .. " (ID: " .. targetUserId .. ")...")
    
    task.spawn(function()
        local successClone, err = pcall(function()
            local myChar = LocalPlayer.Character
            if not myChar then error("Character not found") end
            
            local myHum = myChar:FindFirstChildOfClass("Humanoid")
            if not myHum then error("Humanoid not found") end
            
            local description = Players:GetHumanoidDescriptionFromUserId(targetUserId)
            if not description then error("Failed to load avatar description") end
            
            for _, obj in ipairs(myChar:GetChildren()) do
                if obj:IsA("Accessory") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or obj:IsA("BodyColors") then
                    obj:Destroy()
                end
            end
            
            if myHum.ApplyDescriptionClientServer then
                myHum:ApplyDescriptionClientServer(description)
            else
                myHum:ApplyDescription(description)
            end
        end)
        
        if successClone then
            UI.Slide("Clone", "Successfully cloned " .. targetDisplayName .. "!")
        else
            UI.Slide("Error", "Failed to clone: " .. tostring(err))
        end
    end)
end})

Fun:AddRetroButton({Name = "🔄 Restore Original Avatar", Callback = function()
    local LocalPlayer = game.Players.LocalPlayer
    local Players = game:GetService("Players")
    
    UI.Slide("Clone", "Restoring original avatar...")
    
    task.spawn(function()
        local success, err = pcall(function()
            local myChar = LocalPlayer.Character
            if not myChar then
                error("Character not found")
            end
            
            local myHum = myChar:FindFirstChildOfClass("Humanoid")
            if not myHum then
                error("Humanoid not found")
            end
            
            -- Get original description from LocalPlayer
            local description = Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
            if not description then
                error("Failed to load original avatar")
            end
            
            -- Clear existing accessories first
            for _, obj in ipairs(myChar:GetChildren()) do
                if obj:IsA("Accessory") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or obj:IsA("BodyColors") then
                    obj:Destroy()
                end
            end
            
            -- Apply Description with fallback
            if myHum.ApplyDescriptionClientServer then
                myHum:ApplyDescriptionClientServer(description)
            else
                myHum:ApplyDescription(description)
            end
        end)
        
        if success then
            UI.Slide("Clone", "Original avatar restored!")
        else
            UI.Slide("Error", "Failed to restore: " .. tostring(err))
        end
    end)
end})

Fun:AddParagraph("Clone Info", "Copy another player's avatar appearance.\nNote: This only changes your appearance locally - others may not see the change.")

-- ================================================
-- AUTO WALK TAB - Plugins & Automation
-- ================================================
MapList:AddSection("🔌 Plugins")

MapList:AddParagraph("Map List Player", "🗺️ A floating window for playing recording files.\nUse this to load and play your recorded paths.")
MapList:AddRetroButton({Name = "🗺️ Open Map List Player", Callback = function()
    -- Check if plugin is already loaded and has valid UI
    local existingPlugin = getgenv().MapListPlugin
    if existingPlugin and existingPlugin._Loaded and existingPlugin.UI and existingPlugin.UI.MainFrame then
        -- Toggle visibility instead of reloading
        -- This calls Toggle() which handles StopPlayback when hiding
        existingPlugin:Toggle()
        return
    end
    
    -- Plugin not loaded or UI destroyed - need to load from file
    local paths = {"MapListPlugin.lua", "StarSpace/MapListPlugin.lua"}
    local foundPath = nil
    
    for _, p in ipairs(paths) do
        if isfile(p) then
            foundPath = p
            break
        end
    end
    
    if foundPath then
        -- Clean up any stale references
        if existingPlugin then
            if existingPlugin.Unload then
                pcall(function() existingPlugin:Unload() end)
            elseif existingPlugin.UI and existingPlugin.UI.ScreenGui then
                pcall(function() existingPlugin.UI.ScreenGui:Destroy() end)
            end
            getgenv().MapListPlugin = nil
        end
        
        print("[StarSpace] Loading MapListPlugin from: " .. foundPath)
        local success, result = pcall(function()
            local content = readfile(foundPath)
            local func = loadstring(content)
            if not func then return nil, "Syntax Error" end
            return func()
        end)
        
        if success and result then
            getgenv().MapListPlugin = result
            if result.CreateUI then
                result:CreateUI()
                if result.UI.MainFrame then
                    result.UI.MainFrame.Visible = true
                end
            end
            UI.Slide("Plugin", "MapListPlugin loaded!")
        else
            warn("[StarSpace] Failed to load plugin: " .. tostring(result))
            UI.Slide("Error", "Failed to load plugin code!")
        end
    else
        UI.Slide("Error", "MapListPlugin.lua not found!")
    end
end})

MapList:AddParagraph("Recorder", "🎙️ Record your movement and actions to create new paths.\nSupports Xan-based recording for better precision.")
MapList:AddRetroButton({Name = "🎙️ Open Recorder", Callback = function()
    -- Prioritize new Xan-based plugin, fallback to old plugin
    local paths = {"RecorderPluginXan.lua", "StarSpace/RecorderPluginXan.lua", "RecorderPlugin.lua", "StarSpace/RecorderPlugin.lua"}
    local foundPath = nil
    
    for _, p in ipairs(paths) do
        if isfile(p) then
            foundPath = p
            break
        end
    end
    
    if foundPath then
        if getgenv().RecorderPlugin then
            if getgenv().RecorderPlugin.Unload then
                pcall(function() getgenv().RecorderPlugin:Unload() end)
            elseif getgenv().RecorderPlugin.UI and getgenv().RecorderPlugin.UI.ScreenGui then
                pcall(function() getgenv().RecorderPlugin.UI.ScreenGui:Destroy() end)
            end
        end
        
        print("[StarSpace] Loading RecorderPlugin from: " .. foundPath)
        local success, result = pcall(function()
            local content = readfile(foundPath)
            local func = loadstring(content)
            if not func then return nil, "Syntax Error" end
            return func()
        end)
        
        if success and result then
            getgenv().RecorderPlugin = result
            if result.CreateUI then
                result:CreateUI()
            end
            local isXanPlugin = foundPath:find("Xan") ~= nil
            UI.Slide("Plugin", isXanPlugin and "Recorder (Xan) loaded!" or "Recorder loaded!")
        else
            warn("[StarSpace] Failed to load recorder plugin: " .. tostring(result))
            UI.Slide("Error", "Failed to load plugin code!")
        end
    else
        UI.Slide("Error", "RecorderPlugin not found! Place RecorderPluginXan.lua in workspace.")
    end
end})

MapList:AddParagraph("Recording Merger", "🔗 Merge multiple recordings into a single file.\nCombine your recorded paths for longer routes.")
MapList:AddRetroButton({Name = "🔗 Open Merger", Callback = function()
    local paths = {"MergerPlugin.lua", "StarSpace/MergerPlugin.lua"}
    local foundPath = nil
    
    for _, p in ipairs(paths) do
        if isfile(p) then
            foundPath = p
            break
        end
    end
    
    if foundPath then
        if getgenv().MergerPlugin then
            if getgenv().MergerPlugin.Unload then
                pcall(function() getgenv().MergerPlugin:Unload() end)
            elseif getgenv().MergerPlugin.UI and getgenv().MergerPlugin.UI.ScreenGui then
                pcall(function() getgenv().MergerPlugin.UI.ScreenGui:Destroy() end)
            end
        end
        
        print("[StarSpace] Loading MergerPlugin from: " .. foundPath)
        local success, result = pcall(function()
            local content = readfile(foundPath)
            local func, err = loadstring(content)
            if not func then 
                error("Syntax Error: " .. tostring(err)) 
            end
            return func()
        end)
        
        if success and result then
            getgenv().MergerPlugin = result
            if result.CreateUI then
                result:CreateUI()
                if result.UI.MainFrame then
                    result.UI.MainFrame.Visible = true
                end
            end
            UI.Slide("Plugin", "MergerPlugin loaded!")
        else
            warn("[StarSpace] Failed to load merger plugin: " .. tostring(result))
            UI.Slide("Error", "Failed to load plugin code!")
        end
    else
        UI.Slide("Error", "MergerPlugin.lua not found!")
    end
end})

MapList:AddParagraph("Checkpoint Manager", "📍 Manage waypoints and checkpoints.\nSave locations and teleport to them easily.")
MapList:AddRetroButton({Name = "📍 Open Checkpoint Manager", Callback = function()
    local paths = {"CheckpointPlugin.lua", "StarSpace/CheckpointPlugin.lua"}
    local foundPath = nil
    
    for _, p in ipairs(paths) do
        if isfile(p) then
            foundPath = p
            break
        end
    end
    
    if foundPath then
        if getgenv().CheckpointPlugin then
            if getgenv().CheckpointPlugin.Unload then
                pcall(function() getgenv().CheckpointPlugin:Unload() end)
            end
        end
        
        print("[StarSpace] Loading CheckpointPlugin from: " .. foundPath)
        local success, result = pcall(function()
            local content = readfile(foundPath)
            local func, err = loadstring(content)
            if not func then 
                error("Syntax Error: " .. tostring(err)) 
            end
            return func()
        end)
        
        if success and result then
            getgenv().CheckpointPlugin = result
            if result.CreateUI then
                result:CreateUI()
                if result.UI.MainFrame then
                    result.UI.MainFrame.Visible = true
                end
            end
            UI.Slide("Plugin", "CheckpointPlugin loaded!")
        else
            warn("[StarSpace] Failed to load checkpoint plugin: " .. tostring(result))
            UI.Slide("Error", "Failed to load plugin code!")
        end
    else
        UI.Slide("Error", "CheckpointPlugin.lua not found!")
    end
end})



-- Hubs Tab
-- Hubs Tab
Hubs:CreateHubHeader({
    Title = "Game Hub",
    Subtitle = "Scripts for other games",
    Icon = UI.Icons.Hubs
})

Hubs:AddSection("Featured Games")

Hubs:CreateGameCard({
    Name = "Fish-It",
    Image = "rbxthumb://type=GameIcon&id=6701277882&w=512&h=512",
    Description = "Auto fish, sell, and more.",
    Callback = function()
        UI.Slide("Hub", "Loading Fish-It script...")
        -- loadstring(game:HttpGet("URL_HERE"))()
    end
})

Hubs:CreateGameCard({
    Name = "Violence District",
    Image = "rbxthumb://type=GameIcon&id=6739698191&w=512&h=512",
    Description = "Combat features, auto farm, and ESP.",
    Callback = function()
        UI.Slide("Hub", "Loading Violence District script...")
        -- loadstring(game:HttpGet("URL_HERE"))()
    end
})

Hubs:CreateGameCard({
    Name = "The Forge",
    Image = "rbxthumb://type=GameIcon&id=7671049560&w=512&h=512",
    Description = "Hangout features and fun commands.",
    Callback = function()
        UI.Slide("Hub", "Loading The Forge script...")
        -- loadstring(game:HttpGet("URL_HERE"))()
    end
})

Hubs:CreateGameCard({
    Name = "Indo Hangout",
    Image = "rbxthumb://type=GameIcon&id=3623695803&w=512&h=512",
    Description = "Indonesian hangout script.",
    Callback = function()
        UI.Slide("Hub", "Loading Indo Hangout script...")
        -- loadstring(game:HttpGet("URL_HERE"))()
    end
})


-- Settings Tab
Settings:AddSection("Interface")
Settings:AddThemeSelector("Theme")
Settings:AddToggle("Show FPS & Ping", {Default = true, Flag = "ShowWatermark"}, function(v)
    if v then Watermark:Show() else Watermark:Hide() end
end)
Settings:AddToggle("Show Notifications", {Default = true, Flag = "ShowNotifications"}, function(v)
    _G.StarSpace.ShowNotifications = v
end)
Settings:AddRetroButton({Name = "Fix Background Image", Callback = function()
    pcall(function()
        UI.SetTheme("StarSpace_Final")
        UI.Slide("System", "Background theme re-applied!")
    end)
end})
Settings:AddToggle("Show Keybinds", { Default = true, Flag = "Keybinds" }, function(v)
    -- Logic to toggle keybinds display
end)

Settings:AddSection("Danger Zone")
Settings:AddRetroButton({Name = "Unload StarSpace", Color = Color3.fromRGB(255, 60, 60), Callback = function()
    UI.Confirm("Unload Hub", "Are you sure you want to unload StarSpace? This will stop all features and clean up the UI.", function()
        _G.StarSpace.Unload()
    end)
end})

-- Auto-enable FPS & Ping on load
pcall(function()
    Watermark:Show()
end)



Settings:AddSection("Credits")
Settings:AddRetroButton({Name = "Join Discord", Callback = function()
    setclipboard("https://discord.gg/yourinvite")
    UI.Slide("Discord", "Invite copied to clipboard!")
end})

-- Info Tab
Info:AddSection("About StarSpace")
Info:AddParagraph("Version", "1.1.0")
Info:AddParagraph("Developer", "StarSpace Team")
Info:AddParagraph("Description", "StarSpace is an advanced utility hub designed for automation, recording, and movement assistance.")

Info:AddSection("Core Features")
Info:AddLabel("• Advanced Path Recording & Playback")
Info:AddLabel("• Multi-Workspace Management")
Info:AddLabel("• Smooth Movement Interpolation")
Info:AddLabel("• Checkpoint Automation")

Info:AddSection("Default Keybinds")
Info:AddParagraph("F5", "Toggle Recorder (Start/Stop)")
Info:AddParagraph("Z", "Play/Pause Playback")
Info:AddParagraph("X", "Stop Playback")
Info:AddParagraph("Gamepad Square/X", "Toggle Recorder")

Info:AddSection("Links & Support")
Info:AddRetroButton({Name = "Copy Discord Link", Callback = function()
    setclipboard("https://discord.gg/starspace")
    UI.Slide("Discord", "Invite copied to clipboard!")
end})
Info:AddRetroButton({Name = "Visit Website", Callback = function()
    setclipboard("https://starspace.bar")
    UI.Slide("Website", "Website URL copied to clipboard!")
end})

Info:AddLabel("Thank you for using StarSpace!")
 

-- Initialize
UI.Slide("Welcome", "StarSpace Hub Loaded Successfully!")

-- Force Initialize Default Features
task.spawn(function()
    task.wait(0.5)
    print("[StarSpace] Initializing Default Features...")
    if AirLockLogic then 
        AirLockLogic(true) 
        FeatureStates["AirLock"] = true 
    end
    if QuickBoostLogic then 
        QuickBoostLogic(true) 
        FeatureStates["QuickBoost"] = true 
    end
    if AutoSpinLogic then 
        AutoSpinLogic(true) 
        FeatureStates["AutoSpin"] = true 
    end
end)

-- Load Playback Engine
print("[StarSpace] Loading Playback Engine...")
local success, err = pcall(function()
    -- Try multiple paths (Prioritize StarSpace folder as requested)
    local pathsToTry = {
        "StarSpace/StarSpacePlayback.lua", -- Primary target
    }
    
    local loaded = false
    for _, path in ipairs(pathsToTry) do
        if isfile(path) then
            print("[StarSpace] Found playback module at: " .. path)
            local playbackModule = readfile(path)
            if playbackModule then
                local func, loadErr = loadstring(playbackModule)
                if func then
                    func()
                    print("[StarSpace] Playback Engine loaded successfully!")
                    loaded = true
                    break
                else
                    warn("[StarSpace] Syntax error in playback module: " .. tostring(loadErr))
                end
            end
        end
    end
    
    if not loaded then
        warn("[StarSpace] StarSpacePlayback.lua not found in any common paths!")
        -- Fallback: Try to load from URL if local fails (optional, for now just warn)
    end
end)

if not success then
    warn("[StarSpace] Failed to load playback engine: " .. tostring(err))
end
