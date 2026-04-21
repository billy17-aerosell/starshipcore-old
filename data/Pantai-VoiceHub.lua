--[[
    Ultimate Fishing Exploit - Pantai Voice (WINDUI VERSION)
    by Antigravity
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JualRemote = ReplicatedStorage:WaitForChild("JualIkanRemote")
local FishingEvents = ReplicatedStorage:WaitForChild("FishingSystem"):WaitForChild("Events")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- [[ ACCOUNT STATUS HELPERS (PORTED FROM MOBILEUI) ]]
local function FormatRole(role)
    if not role then return "USER" end
    return string.upper(role:gsub("_", " "))
end

local function ParseVIPExpiry(durationStr)
    if not durationStr or durationStr == "Lifetime" or durationStr == "lifetime" then
        return nil
    end
    local days = tonumber(durationStr:match("(%d+)%s*day"))
    local hours = tonumber(durationStr:match("(%d+)%s*hour"))
    if days then
        return os.time() + (days * 24 * 60 * 60)
    elseif hours then
        return os.time() + (hours * 60 * 60)
    end
    return nil
end

local function FormatTimeRemaining(seconds)
    if seconds <= 0 then return "Expired" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    if days > 0 then return string.format("%dd %dh %dm %ds", days, hours, mins, secs)
    elseif hours > 0 then return string.format("%dh %dm %ds", hours, mins, secs)
    elseif mins > 0 then return string.format("%dm %ds", mins, secs)
    else return string.format("%ds", secs) end
end

-- === SESSION & AUTHENTICATION ===
local sessionData = (getgenv and getgenv().StarshipSession) or _G.sessionData or { 
    Role = "VIP Mobile", 
    Duration = "Lifetime",
    UserId = game.Players.LocalPlayer.UserId,
    Username = game.Players.LocalPlayer.Name
}
_G.sessionData = sessionData

-- ESPSystem Logic
local ESPSystem = {
    Enabled = false,
    Boxes = false,
    Names = false,
    Chams = false,
    TeamCheck = false,
    Players = {}
}

local function isFriendly(player)
    if not ESPSystem.TeamCheck then return false end
    return player.Team == game.Players.LocalPlayer.Team
end

local function createESP(player)
    if player == game.Players.LocalPlayer then return end
    local esp = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Highlight = Instance.new("Highlight")
    }
    
    esp.Box.Thickness = 1
    esp.Box.Filled = false
    esp.Box.Color = Color3.fromRGB(255, 255, 255)
    esp.Box.Visible = false
    
    esp.Name.Size = 14
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Color = Color3.fromRGB(255, 255, 255)
    esp.Name.Visible = false
    
    esp.Highlight.FillTransparency = 0.5
    esp.Highlight.OutlineTransparency = 0
    esp.Highlight.Enabled = false
    
    ESPSystem.Players[player] = esp
end

local function removeESP(player)
    local esp = ESPSystem.Players[player]
    if esp then
        esp.Box:Remove()
        esp.Name:Remove()
        if esp.Highlight then esp.Highlight:Destroy() end
        ESPSystem.Players[player] = nil
    end
end

RunService.RenderStepped:Connect(function()
    if not ESPSystem.Enabled then
        for _, esp in pairs(ESPSystem.Players) do
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Highlight.Enabled = false
        end
        return
    end

    for player, esp in pairs(ESPSystem.Players) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if hrp and hum and hum.Health > 0 and not isFriendly(player) then
            local pos, onScreen = game.workspace.CurrentCamera:WorldToViewportPoint(hrp.Position)
            
            if onScreen then
                local size = (game.workspace.CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.5, 0)).Y - game.workspace.CurrentCamera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 4.5, 0)).Y)
                local boxSize = Vector2.new(math.abs(size / 1.5), math.abs(size))
                local boxPos = Vector2.new(pos.X - boxSize.X / 2, pos.Y - boxSize.Y / 2)
                
                if ESPSystem.Boxes then
                    esp.Box.Size = boxSize
                    esp.Box.Position = boxPos
                    esp.Box.Visible = true
                else
                    esp.Box.Visible = false
                end
                
                if ESPSystem.Names then
                    esp.Name.Text = player.DisplayName or player.Name
                    esp.Name.Position = Vector2.new(pos.X, pos.Y - boxSize.Y / 2 - 15)
                    esp.Name.Visible = true
                else
                    esp.Name.Visible = false
                end
                
                if ESPSystem.Chams then
                    esp.Highlight.Adornee = char
                    esp.Highlight.Parent = char
                    esp.Highlight.Enabled = true
                    esp.Highlight.FillColor = player.TeamColor and player.TeamColor.Color or Color3.fromRGB(255, 255, 255)
                else
                    esp.Highlight.Enabled = false
                end
            else
                esp.Box.Visible = false
                esp.Name.Visible = false
                esp.Highlight.Enabled = false
            end
        else
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Highlight.Enabled = false
        end
    end
end)

game.Players.PlayerAdded:Connect(createESP)
game.Players.PlayerRemoving:Connect(removeESP)
for _, p in ipairs(game.Players:GetPlayers()) do createESP(p) end

-- Load UI Library
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/billy17-netizen/windUIBoreal/refs/heads/main/WindUI_Boreal.lua"))()

if not WindUI then
    warn("[Fisher] Failed to load WindUI Library. Check your connection.")
    return
end

-- Single Instance Lock (Kill old script instances)
if _G.PantaiFisher_Connections then
    _G.PantaiFisher_Terminated = true
    for _, v in pairs(_G.PantaiFisher_Connections) do
        if v then v:Disconnect() end
    end
    table.clear(_G.PantaiFisher_Connections)
    task.wait(0.3)
end

_G.PantaiFisher_Terminated = false
_G.PantaiFisher_Connections = {}

-- UI Cleanup
local function CleanupUI()
    local path = game:GetService("CoreGui"):FindFirstChild("WindUI") or game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("WindUI")
    if path then path:Destroy() end
end
CleanupUI()

-- Variables & State Tracking
local Running = true
local Connections = _G.PantaiFisher_Connections

_G.BlatantMode = false
_G.LegitMode = false
_G.AutoFish = false
_G.PerfectCatch = false
_G.AutoSell = false
_G.SellMode = "All"
_G.StealthSell = true
_G.AdminDetector = false
_G.FastHook = false
_G.InstantLand = false
_G.NoDelay = false

local SavedPosition = nil
local IsCasting = false
local InMinigame = false
local LastAction = 0
local LastCastTime = 0
local SellTriggers = {"Periodic (5s)", "At 50 Items", "At 100 Items", "At 150 Items", "At 200 Items", "At 1000 Items"}
local SellModes = {"All", "Under 50Kg", "Rare+", "Legendary+"}

-- Follower State
_G.FollowActive = false
_G.FollowTarget = nil
_G.FollowMode = "Behind"
_G.FollowDistance = 5
_G.MimicAnimations = false
_G.Scale_Width = 1
_G.Scale_Height = 1
_G.Scale_Depth = 1
_G.Scale_Head = 1
local activeTracks = {}

-- Helper: Fast Hook Patch
local function ApplyFastHookPatch(reset)
    local configModule = ReplicatedStorage:FindFirstChild("FishingSystem", true) and ReplicatedStorage:FindFirstChild("FishingSystem", true):FindFirstChild("FishNRodPriceConfig", true)
    if configModule and configModule:IsA("ModuleScript") then
        local s, m = pcall(require, configModule)
        if s and type(m) == "table" then
            if m.Gameplay then
                m.Gameplay.HookDelay = reset and 3 or 1e-7
                m.Gameplay.PostCatchGiveDelay = reset and 2.5 or 1e-7
            end
            if m.Rods then
                for _, rod in pairs(m.Rods) do
                    if rod.Stats then
                        rod.Stats.MAX_holdTime = reset and (rod.Stats.MAX_holdTime or 2) or 1e-7
                    end
                end
            end
        end
    end
end

-- Helper: Stop Rod Animations
local function StopRodAnimations()
    local char = game.Players.LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            if track.Name == "PowerHold" or track.Name == "PowerRelease" or track.Name == "WaitRod" or track.Name == "ReelRod" then
                track:Stop()
            end
        end
    end
end

-- Cleanup Function
local function Unload()
    if not Running then return end
    Running = false
    _G.AutoFish = false
    _G.AutoSell = false
    _G.BlatantMode = false
    _G.LegitMode = false
    
    -- Revert Game Configs
    ApplyFastHookPatch(true)
    
-- Stop all mimic animations
    for id, track in pairs(activeTracks) do
        if track then track:Stop() end
    end
    table.clear(activeTracks)

    for i, v in pairs(Connections) do
        if v then v:Disconnect() end
    end
    table.clear(Connections)
    
    task.wait(0.1)
    CleanupUI()
    print("Fisher Hub Unloaded Successfully.")
end

-- Helper: Find Water Position
local function FindWaterPosition()
    local char = game.Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}

    -- Rapid detection of water surface
    local targetDistances = {12, 18, 25}
    for _, dist in ipairs(targetDistances) do
        local origin = root.Position + root.CFrame.LookVector * dist + Vector3.new(0, 15, 0)
        local result = workspace:Raycast(origin, Vector3.new(0, -100, 0), params)
        if result and (result.Material == Enum.Material.Water or result.Instance:IsA("Terrain")) then
            return result.Position
        end
    end
    -- Ultimate Rage Fallback: Directly below in front
    return root.Position + root.CFrame.LookVector * 15 - Vector3.new(0, 8, 0)
end

-- Helper: Get Current Rod
local function GetRod()
    local char = game.Players.LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Tool")
end

-- Helper: Legit Solver for Mini-game (Smoothed & Human-like Version)
local function PlayLegitMiniGame()
    task.spawn(function()
        local Player = game.Players.LocalPlayer
        local PlayerGui = Player:WaitForChild("PlayerGui")
        local VirtualUser = game:GetService("VirtualUser")
        local VIM = game:GetService("VirtualInputManager")
        
        local isHoldingDown = false -- Track state to prevent jittering/spam

        while InMinigame and _G.LegitMode and Running do
            local gui = PlayerGui:FindFirstChild("MiniGameGUI")
            if gui then
                -- Detect slider and target zone
                local detec = gui:FindFirstChild("Detec", true) or gui:FindFirstChild("Progress", true)
                local attc = gui:FindFirstChild("Attc", true) or gui:FindFirstChild("Fish", true)
                
                if detec and attc then
                    -- Get center positions
                    local sPos = detec.AbsolutePosition.X + (detec.AbsoluteSize.X / 2)
                    local tPos = attc.AbsolutePosition.X + (attc.AbsoluteSize.X / 2)
                    
                    -- Tolerance (deadzone) to prevent constant vibrating/jittering
                    local tolerance = 12 
                    
                    if sPos < (tPos - tolerance) then
                        -- Move Right (Hold)
                        if not isHoldingDown then
                            isHoldingDown = true
                            VirtualUser:Button1Down(Vector2.new(0, 0))
                            pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0) end)
                        end
                    elseif sPos > (tPos + tolerance) then
                        -- Move Left (Release)
                        if isHoldingDown then
                            isHoldingDown = false
                            VirtualUser:Button1Up(Vector2.new(0, 0))
                            pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
                        end
                    end
                end
            end
            task.wait(0.015) -- Balanced frequency for smooth movement
        end
        -- Ensure released at the end
        isHoldingDown = false
        VirtualUser:Button1Up(Vector2.new(0,0))
        pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
    end)
end

-- Remote Hooking
local function HookRemote(tool)
    if tool:FindFirstChild("MiniGame") then
        local conn = tool.MiniGame.OnClientEvent:Connect(function(method)
            if method == "Start" then
                InMinigame = true
                IsCasting = false
                if _G.PerfectCatch then
                    if _G.BlatantMode then
                        -- Instant Catch
                        tool.MiniGame:FireServer("Complete")
                        FishingEvents.MiniGameComplete:FireServer("Complete")
                    elseif _G.LegitMode then
                        -- Legit Solver (Plays the UI like a human)
                        PlayLegitMiniGame()
                    end
                end
            elseif method == "Complete" or method == "End" then
                InMinigame = false
                IsCasting = false
                LastAction = tick()
                -- Ensure both remotes are handled if using AutoFish
                if method == "Complete" and _G.AutoFish and _G.PerfectCatch then
                    FishingEvents.MiniGameComplete:FireServer("Complete")
                end
            end
        end)
        table.insert(Connections, conn)
    end
end

-- Initial Hook System
local function InitHooks()
    local char = game.Players.LocalPlayer.Character
    if char then
        for _, v in pairs(char:GetChildren()) do if v:IsA("Tool") then HookRemote(v) end end
        table.insert(Connections, char.ChildAdded:Connect(function(child) if child:IsA("Tool") then HookRemote(child) end end))
    end
    for _, v in pairs(game.Players.LocalPlayer.Backpack:GetChildren()) do if v:IsA("Tool") then HookRemote(v) end end
end

-- Initialize UI
local Window = WindUI:CreateWindow({
    Title = "STARSHIP┃dsc.gg-starshipcore",
    Icon = "rbxassetid://85930777472774", 
    IconSize = 45,
    Author = "Premium Edition | StarshipCore",
    Size = UDim2.fromOffset(630, 350),
    SideBarWidth = 180,
    Transparent = true,
    BackgroundImageTransparency = 0.92,
    Background = "rbxassetid://132820581372516",
    ToggleKey = Enum.KeyCode.RightControl,
    Theme = "Crimson",
    ModernLayout = true,
     User = {
        Enabled = true,
        Anonymous = true,
        Callback = function()
            WindUI:Notify({
                Title = "👤 Starship User",
                Content = "Welcome to Starship Premium Edition!",
                Duration = 5,
            })
        end,
    },
     OpenButton = {
        Title = "STARSHIP ✨",
        Icon = "rbxassetid://85930777472774",
        IconSize = 22, -- Base size (will be overridden by manual fix below)
        IconThemed = false,
        Size = UDim2.fromOffset(155, 48), 
        CornerRadius = UDim.new(0.5, 0),
        StrokeThickness = 1.5,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 15)),
            ColorSequenceKeypoint.new(0.6, Color3.fromRGB(45, 10, 10)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 38, 38)), -- Crimson Red
        }),
    },
})

-- Fix Background Image Scaling (Sourced from Starship Documentation)
pcall(function()
    local bgFrame = Window.Internal.Background
    local img = bgFrame:FindFirstChildOfClass("ImageLabel")
    if img then
        img.ScaleType = Enum.ScaleType.Fit
    end
end)

-- Native WindUI Destruction Trigger
Window:OnDestroy(Unload)

-- Reset All Farming Flags
local function ResetFarmingFlags()
    _G.AutoFish = false
    _G.PerfectCatch = false
    _G.FastHook = false
    _G.InstantLand = false
    _G.NoDelay = false
    ApplyFastHookPatch(true)
end

-- Tabs
local HomeTab = Window:Tab({ Title = "Home", Icon = "house" })
local FarmTab = Window:Tab({ Title = "Farming", Icon = "crosshair" })
local ShopTab = Window:Tab({ Title = "Market", Icon = "shopping-cart" })
local WorldTab = Window:Tab({ Title = "World", Icon = "map" })
local MiscTab = Window:Tab({ Title = "Misc", Icon = "sparkles" })
local VisionSafetyTab = Window:Tab({ Title = "Vision & Safety", Icon = "shield" })

-- === PREMIUM UI COMPONENTS (Like SambungKata) ===
Window:Watermark({
    Text = "PANTAI VOICE CHAT┃PREMIUM EDITION",
    Position = "bottom-right",
    Opacity = 0.45,
    Size = 12,
})

local FPSTag = Window:Tag({
    Title = "⚡ FPS: --",
    Color = Color3.fromRGB(68, 216, 114),
})

local PingTag = Window:Tag({
    Title = "📶 PING: --ms",
    Color = Color3.fromRGB(75, 155, 255),
})

task.spawn(function()
    local RunService = game:GetService("RunService")
    local frameCount = 0
    local lastUpdate = tick()
    
    local hc = RunService.Heartbeat:Connect(function() frameCount = frameCount + 1 end)
    table.insert(Connections, hc)
    
    while Running do
        task.wait(1)
        local now = tick()
        local elapsed = now - lastUpdate
        local fps = math.floor(frameCount / elapsed)
        local stat = game:GetService("Stats"):FindFirstChild("Network")
        local ping = 0
        if stat and stat:FindFirstChild("ServerStatsItem") and stat.ServerStatsItem:FindFirstChild("Data Ping") then
            ping = math.floor(stat.ServerStatsItem["Data Ping"]:GetValue())
        end
        
        pcall(function()
            FPSTag:SetTitle("⚡ FPS: " .. fps)
            PingTag:SetTitle("📶 PING: " .. ping .. "ms")
        end)
        
        frameCount = 0
        lastUpdate = now
    end
end)

-- Home (Dashboard) Tab Content
local HomeMulti = HomeTab:MultiSection({
    Title = "Dashboard Overview",
    Icon = "layout-dashboard",
    Box = true,
    BoxBorder = true,
    Opened = true
})

local infoSubTab = HomeMulti:Tab({ Title = "Information", Icon = "info" })
local accSubTab = HomeMulti:Tab({ Title = "Account", Icon = "user" })

-- Info SubTab
local WelcomeParagraph = infoSubTab:Paragraph({
    Title = "Pantai Voice Chat",
    Desc = "Status: Activated ✅\nVersion: 2.0 (Premium)\n\nUptime: 0s\nFishing: OFF",
    Image = "rbxassetid://7733965118",
})

task.spawn(function()
    local uptime = 0
    while Running and not _G.PantaiFisher_Terminated do
        task.wait(1)
        uptime = uptime + 1
        local fishStatus = _G.AutoFish and "ACTIVE 🎣" or "IDLE 💤"
        local modeStr = _G.BlatantMode and "BLATANT" or (_G.LegitMode and "NORMAL" or "NONE")
        
        pcall(function()
            WelcomeParagraph:SetDesc(string.format(
                "Status: Activated ✅\nVersion: 2.0 (Premium)\n\nUptime: %ds\nFishing: %s\nMode: %s\n\nThank you for choosing Starship Core.",
                uptime, fishStatus, modeStr
            ))
        end)
    end
end)

infoSubTab:Button({
    Title = "Copy Discord Invite",
    Desc = "Join Pantai Voice Community",
    Callback = function()
        if setclipboard then setclipboard("https://discord.gg/yourlink") end
        WindUI:Notify({ Title = "Success", Content = "Discord link copied!", Duration = 3, Icon = "check" })
    end
})

infoSubTab:Button({
    Title = "Unload Script",
    Desc = "Clean up and remove the GUI completely",
    Callback = Unload
})

-- Account SubTab
local ply = game.Players.LocalPlayer

-- VIP STATUS SECTION
do
    local VIPSection = accSubTab:Section({ Title = "VIP Status", Icon = "star" })
    
    local vipExpiryTime = nil
    if sessionData.Expiry then
        vipExpiryTime = tonumber(sessionData.Expiry)
    else
        vipExpiryTime = ParseVIPExpiry(sessionData.Duration)
        sessionData.Expiry = vipExpiryTime -- Persist it globally!
    end

    local function GetVIPStatusDesc()
        local timeRemaining = "Lifetime"
        if vipExpiryTime then
            local remaining = vipExpiryTime - os.time()
            timeRemaining = FormatTimeRemaining(remaining)
        end
        return "Role: " .. FormatRole(sessionData.Role) .. "\n" ..
               "Time Remaining: " .. timeRemaining .. "\n" ..
               "Status: Active"
    end

    local vipPara = VIPSection:Paragraph({
        Title = "Subscription Information",
        Desc = GetVIPStatusDesc()
    })

    if vipExpiryTime then
        task.spawn(function()
            while Running and not _G.PantaiFisher_Terminated do
                task.wait(1)
                pcall(function()
                    if vipPara then
                        local desc = GetVIPStatusDesc()
                        if vipPara.SetDesc then vipPara:SetDesc(desc)
                        elseif vipPara.SetContent then vipPara:SetContent(desc)
                        elseif vipPara.SetDescription then vipPara:SetDescription(desc)
                        end
                    end
                end)
                if (vipExpiryTime - os.time()) <= 0 then break end
            end
        end)
    end
end

local accDesc = string.format("Username: @%s\nDisplay Name: %s\nUser ID: %s\nAccount Age: %d days", 
    (ply and ply.Name) or "Unknown", 
    (ply and ply.DisplayName) or "Unknown", 
    (ply and tostring(ply.UserId)) or "Unknown", 
    (ply and ply.AccountAge) or 0
)

accSubTab:Paragraph({
    Title = "Player Information",
    Desc = accDesc,
})

-- Select Default Tab
HomeTab:Select()
infoSubTab:Select()

-- Farming Tab Content
local FarmMulti = FarmTab:MultiSection({
    Title = "Farming Operations",
    Icon = "crosshair",
    Box = true,
    BoxBorder = true,
    Opened = true
})

local playstyleSubTab = FarmMulti:Tab({ Title = "Playstyle", Icon = "mouse-pointer" })
local smartSubTab = FarmMulti:Tab({ Title = "Smart Catch", Icon = "brain" })
local lootSubTab = FarmMulti:Tab({ Title = "Auto Loot", Icon = "shopping-bag" })

local GodSection = playstyleSubTab:Section({ Title = "SELECT PLAYSTYLE" })

playstyleSubTab:Toggle({
    Title = "MODE NORMAL (Safe)",
    Desc = "Visual UI Interaction - Human-like solving, Maximum safety",
    Value = _G.LegitMode,
    Callback = function(v)
        _G.LegitMode = v
        if v then
            _G.BlatantMode = false
            _G.AutoFish = true
            _G.PerfectCatch = true
            _G.FastHook = false
            _G.InstantLand = false
            _G.NoDelay = false
            ApplyFastHookPatch(true)
            WindUI:Notify({ Title = "MODE", Content = "NORMAL: SOLVER ACTIVE", Duration = 3, Icon = "shield-check" })
        else
            ResetFarmingFlags()
            WindUI:Notify({ Title = "MODE", Content = "ALL FARMING: OFF", Duration = 3, Icon = "power" })
        end
    end
})

playstyleSubTab:Toggle({
    Title = "MODE BLATANT (Extreme)",
    Desc = "Instant everything - Maximum speed, High risk",
    Value = _G.BlatantMode,
    Callback = function(v)
        _G.BlatantMode = v
        if v then
            _G.LegitMode = false
            _G.AutoFish = true
            _G.PerfectCatch = true
            _G.FastHook = true
            _G.InstantLand = true
            _G.NoDelay = true
            ApplyFastHookPatch(false)
            WindUI:Notify({ Title = "MODE", Content = "BLATANT: ACTIVATED", Duration = 3, Icon = "zap" })
        else
            ResetFarmingFlags()
            WindUI:Notify({ Title = "MODE", Content = "ALL FARMING: OFF", Duration = 3, Icon = "power" })
        end
    end
})

local SmartSection = smartSubTab:Section({ Title = "SMART CATCH (Advanced)" })

smartSubTab:Dropdown({
    Title = "Protect Rarities",
    Desc = "Multi-select categories to favor",
    Multi = true,
    Values = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical"},
    Value = _G.FavRarities or {"Legendary", "Mythical"},
    Callback = function(v)
        _G.FavRarities = v
    end
})

local LootSection = lootSubTab:Section({ Title = "AUTO COLLECT LOOT" })

_G.AutoCollectLoot = false
_G.TeleportCollect = false
_G.TargetLootNames = "DroppedMoney,money,drop"

lootSubTab:Toggle({
    Title = "Auto Collect Money",
    Desc = "Collects money automatically using stealth method.",
    Value = false,
    Callback = function(v)
        _G.AutoCollectLoot = v
    end
})

lootSubTab:Toggle({
    Title = "Use Teleport Fallback",
    Desc = "Enable this only if money isn't collecting automatically.",
    Value = false,
    Callback = function(v)
        _G.TeleportCollect = v
    end
})


-- Market Tab Content
local MarketMulti = ShopTab:MultiSection({
    Title = "Marketplace Hub",
    Icon = "shopping-cart",
    Box = true,
    BoxBorder = true,
    Opened = true
})

local sellSubTab = MarketMulti:Tab({ Title = "Auto Sell", Icon = "dollar-sign" })
local rodSubTab = MarketMulti:Tab({ Title = "Rod Shop", Icon = "shopping-bag" })

local SellSection = sellSubTab:Section({ Title = "Selling Options" })

sellSubTab:Toggle({
    Title = "Auto Sell Periodically",
    Desc = "Sells fish every 3 seconds based on filter",
    Value = _G.AutoSell,
    Callback = function(v)
        _G.AutoSell = v
    end
})

sellSubTab:Toggle({
    Title = "Stealth Sell (Hide UI)",
    Desc = "Prevents the selling menu from popping up",
    Value = _G.StealthSell,
    Callback = function(v)
        _G.StealthSell = v
    end
})

sellSubTab:Dropdown({
    Title = "Weight Filter",
    Desc = "Target category to sell",
    Values = SellModes,
    Value = _G.SellMode or "All",
    Callback = function(v)
        _G.SellMode = v
    end
})

sellSubTab:Dropdown({
    Title = "Sell Trigger",
    Desc = "When should the sale occur?",
    Values = SellTriggers,
    Value = _G.SellTrigger or "Periodic (5s)",
    Callback = function(v)
        _G.SellTrigger = v
    end
})

local ShopSection = rodSubTab:Section({ Title = "ROD SHOP" })

rodSubTab:Toggle({
    Title = "Auto Buy Next Rod",
    Desc = "Automatically buys the best rod you can afford",
    Value = _G.AutoBuyRod,
    Callback = function(v)
        _G.AutoBuyRod = v
    end
})

rodSubTab:Button({
    Title = "Buy Best Possible Rod",
    Desc = "Instantly buys the most expensive rod you can afford",
    Callback = function()
        BuyNextRod(true)
    end
})

-- Advanced Avatar Spoofing & Scale Logic
local function buildAllowedAssets(userId)
    local ok, model = pcall(function() return game.Players:GetCharacterAppearanceAsync(userId) end)
    if not ok or not model then return nil end
    local allowed = { Accessories = {}, Shirt = nil, Pants = nil }
    for _, inst in ipairs(model:GetChildren()) do
        if inst:IsA("Accessory") then allowed.Accessories[inst.Name] = true
        elseif inst:IsA("Shirt") then allowed.Shirt = inst.ShirtTemplate
        elseif inst:IsA("Pants") then allowed.Pants = inst.PantsTemplate end
    end
    model:Destroy()
    return allowed
end

local function selectiveCleanup(char, allowed)
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") and not allowed.Accessories[v.Name] then v:Destroy()
        elseif v:IsA("Shirt") and v.ShirtTemplate ~= allowed.Shirt then v:Destroy()
        elseif v:IsA("Pants") and v.PantsTemplate ~= allowed.Pants then v:Destroy() end
    end
end



local function SpoofAvatar(targetUsername)
    local char = game.Players.LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local successId, targetId = pcall(function() return game.Players:GetUserIdFromNameAsync(targetUsername) end)
    if not (successId and targetId) then WindUI:Notify({Title="Error", Content="Target not found!"}) return end

    WindUI:Notify({ Title="Avatar", Content="Synching: "..targetUsername.."...", Duration = 3 })

    local successDesc, targetDesc = pcall(function() return game.Players:GetHumanoidDescriptionFromUserIdAsync(targetId) end)

    if successDesc and targetDesc then
        task.spawn(function()
            -- 1. SAVE: Cek alat apa yang sedang dipegang
            local activeTool = char:FindFirstChildOfClass("Tool")
            local oldRodName = activeTool and activeTool.Name
            
            -- Amankan ke Tas agar tidak otomatis terhapus saat Rig direset
            if activeTool then hum:UnequipTools() end
            task.wait(0.2)
            
            -- WIPE: Hapus muka, rambut, & mesh kepala asli secara paksa agar tidak berbayang / nyangkut!
            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") or v:IsA("CharacterMesh") then
                    v:Destroy()
                end
            end
            
            local head = char:FindFirstChild("Head")
            if head then
                for _, sub in ipairs(head:GetChildren()) do
                    if sub:IsA("SpecialMesh") or sub:IsA("Decal") or sub:IsA("FaceControls") then
                        sub:Destroy()
                    end
                end
            end
    
            -- 2. APPLY DESCRIPTION VIA EXECUTOR METHOD (Cara Paling Akurat)
            pcall(function()
                if hum.ApplyDescriptionClientServer then
                     hum:ApplyDescriptionClientServer(targetDesc)
                else
                     hum:ApplyDescription(targetDesc)
                end
            end)
            
            -- 3. TUNGGU SINKRONISASI
            task.wait(1.5)
    
            -- 4. KEMBALIKAN ALAT SECARA CERDAS (Hanya via fallback tanpa server-refresh utuh)
            if oldRodName then
                local backpack = game.Players.LocalPlayer:FindFirstChild("Backpack")
                local savedTool = (backpack and backpack:FindFirstChild(oldRodName)) or char:FindFirstChild(oldRodName)
                local freshHum = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                
                if savedTool and freshHum then
                    freshHum:EquipTool(savedTool)
                else
                    -- JIKA GAME MENGHAPUS BACKPACK
                    local buyRemote = game:GetService("ReplicatedStorage"):FindFirstChild("PromptBuyRod", true)
                    if buyRemote then pcall(function() buyRemote:FireServer(oldRodName) end) end
                    task.wait(0.5)
                    local newBackpack = game.Players.LocalPlayer:WaitForChild("Backpack", 3)
                    local freshTool = newBackpack and newBackpack:FindFirstChild(oldRodName)
                    local veryFreshHum = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if freshTool and veryFreshHum then
                        veryFreshHum:EquipTool(freshTool)
                    end
                end
            end
            
            WindUI:Notify({ Title="Success", Content="Avatar Copied Perfectly 😈", Duration = 2 })
        end)
    else
        WindUI:Notify({ Title="Error", Content="Failed to fetch description.", Duration = 3 })
    end
end

-- Misc Tab Content (Follower & Mimic)
local function getPlayerList()
    local names = {}
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p ~= game.Players.LocalPlayer then table.insert(names, p.Name) end
    end
    if #names == 0 then table.insert(names, "No players found") end
    return names
end

local function refreshDropdown(dropdown, vals)
    if not dropdown then return end
    pcall(function()
        local obj = dropdown[1] or dropdown
        if obj.SetValues then obj:SetValues(vals)
        elseif obj.Refresh then obj:Refresh(vals, true) end
    end)
end

local function getChoice(input)
    if type(input) == "table" then return input[1] end
    return input
end

local MiscMulti = MiscTab:MultiSection({
    Title = "Miscellaneous Tools",
    Icon = "sparkles",
    Box = true,
    BoxBorder = true,
    Opened = true
})

local playerSubTab = MiscMulti:Tab({ Title = "Player Utility", Icon = "users" })
local avatarSubTab = MiscMulti:Tab({ Title = "Avatar Spoof", Icon = "user" })

local MiscPlayerSection = playerSubTab:Section({ Title = "TARGET & MIMIC" })

local mTargetDrop = playerSubTab:Dropdown({
    Title = "Choose Target",
    Desc = "Select a player to interact with",
    Values = getPlayerList(),
    Callback = function(val)
        _G.FollowTarget = getChoice(val)
        WindUI:Notify({ Title = "Linked", Content = "Target set to: " .. tostring(_G.FollowTarget), Duration = 2 })
    end
})

playerSubTab:Button({
    Title = "Refresh Player List",
    Callback = function()
        refreshDropdown(mTargetDrop, getPlayerList())
    end
})

playerSubTab:Divider()

playerSubTab:Dropdown({
    Title = "Follow Position",
    Values = {"Behind", "Front", "Right", "Left", "Above"},
    Value = "Behind",
    Callback = function(val) _G.FollowMode = getChoice(val) end
})

playerSubTab:Slider({
    Title = "Follow Distance",
    Value = {["Min"] = 0, ["Max"] = 50, ["Default"] = 5, ["Step"] = 0.5},
    Callback = function(v) _G.FollowDistance = v end
})

playerSubTab:Divider()

playerSubTab:Toggle({
    Title = "Force Follow & Mimic",
    Desc = "Locked position + Mimic walking/idle",
    Callback = function(s) 
        _G.FollowActive = s 
        _G.MimicAnimations = s
    end
})

playerSubTab:Button({
    Title = "Teleport to Target",
    Callback = function()
        local target = game.Players:FindFirstChild(_G.FollowTarget or "")
        local root = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and root then
            root.CFrame = target.Character.HumanoidRootPart.CFrame
        end
    end
})

avatarSubTab:Section({ Title = "AVATAR REPLICATION" })

_G.SpoofTarget = "No players found"

local spoofDrop = avatarSubTab:Dropdown({
    Title = "Select Avatar Target",
    Desc = "Choose a player to steal their look",
    Values = getPlayerList(),
    Value = "No players found",
    Callback = function(val)
        _G.SpoofTarget = getChoice(val)
    end
})

avatarSubTab:Button({
    Title = "Refresh Player List",
    Callback = function()
        refreshDropdown(spoofDrop, getPlayerList())
    end
})

avatarSubTab:Button({
    Title = "Copy Avatar",
    Desc = "Transform into the selected player",
    Callback = function()
        if not _G.SpoofTarget or _G.SpoofTarget == "No players found" then
            WindUI:Notify({ Title = "Error", Content = "Pick a target first!", Duration = 3 })
            return
        end
        SpoofAvatar(_G.SpoofTarget)
    end
})

avatarSubTab:Button({
    Title = "Tuff Hacker Avatar",
    Desc = "Become a legendary hacker legend 😈",
    Callback = function()
        SpoofAvatar("67hacker88890")
    end
})

avatarSubTab:Button({
    Title = "Restore My Avatar",
    Desc = "Reload your original look (Server Native)",
    Callback = function()
        pcall(function()
            local refreshEvent = game:GetService("ReplicatedStorage"):FindFirstChild("RefreshPlayerEvent", true)
            if refreshEvent then
                refreshEvent:FireServer()
                WindUI:Notify({ Title = "Avatar", Content = "Refreshed via Server! ♻️", Duration = 3 })
            else
                SpoofAvatar(game.Players.LocalPlayer.Name)
            end
        end)
    end
})



-- Vision & Safety Tab Content
local VisionSafetyMulti = VisionSafetyTab:MultiSection({
    Title = "Utility & Protection",
    Icon = "shield-check",
    Box = true,
    BoxBorder = true,
    Opened = true
})

local espSubTab = VisionSafetyMulti:Tab({ Title = "ESP Engine", Icon = "eye" })
local detectorSubTab = VisionSafetyMulti:Tab({ Title = "Admin Detector", Icon = "shield-alert" })

espSubTab:Section({ Title = "WALLHACK SETTINGS" })

espSubTab:Toggle({
    Title = "Master Switch",
    Desc = "Turn on all ESP features",
    Value = ESPSystem.Enabled,
    Callback = function(v) ESPSystem.Enabled = v end
})

espSubTab:Divider()

espSubTab:Toggle({
    Title = "Player Boxes",
    Desc = "Draw squares around players",
    Value = ESPSystem.Boxes,
    Callback = function(v) ESPSystem.Boxes = v end
})

espSubTab:Toggle({
    Title = "Display Names",
    Desc = "Show names above players",
    Value = ESPSystem.Names,
    Callback = function(v) ESPSystem.Names = v end
})

espSubTab:Toggle({
    Title = "Chams (Highlights)",
    Desc = "Color players through walls",
    Value = ESPSystem.Chams,
    Callback = function(v) ESPSystem.Chams = v end
})

espSubTab:Toggle({
    Title = "Team Check",
    Desc = "Hide friendlies",
    Value = ESPSystem.TeamCheck,
    Callback = function(v) ESPSystem.TeamCheck = v end
})

detectorSubTab:Section({ Title = "SAFETY PROTOCOLS" })

detectorSubTab:Toggle({
    Title = "Admin Detector",
    Desc = "Automatically notifies/leaves if admin joins",
    Value = _G.AdminDetector,
    Callback = function(v)
        _G.AdminDetector = v
        WindUI:Notify({ Title = "Safety", Content = "Admin Detector: " .. (v and "ON" or "OFF"), Duration = 2, Icon = "shield" })
    end
})

detectorSubTab:Button({
    Title = "Check Current Players",
    Desc = "Scans for potential staff members",
    Callback = function()
        local staffFound = false
        for _, p in pairs(game.Players:GetPlayers()) do
            if p:GetRankInGroup(0) > 100 or p.Name:lower():find("admin") or p.Name:lower():find("staff") then
                WindUI:Notify({ Title = "Warning", Content = "Potential Admin: " .. p.Name, Duration = 5, Icon = "alert-triangle" })
                staffFound = true
            end
        end
        if not staffFound then
            WindUI:Notify({ Title = "Safe", Content = "No admins detected.", Duration = 3, Icon = "check" })
        end
    end
})

-- World Tab Content
local WorldMulti = WorldTab:MultiSection({
    Title = "World Control Hub",
    Icon = "globe", -- you can use other icons
    Box = true,
    BoxBorder = true,
    Opened = true
})

local movementSubTab = WorldMulti:Tab({ Title = "Movement", Icon = "fast-forward" })
local tpSubTab = WorldMulti:Tab({ Title = "Teleport", Icon = "map-pin" })
local specSubTab = WorldMulti:Tab({ Title = "Spectate", Icon = "eye" })

local MovementSection = movementSubTab:Section({ Title = "Sprint Settings" })

movementSubTab:Toggle({
    Title = "Enable Sprint",
    Desc = "Press Shift (PC) or use the button (Mobile) to sprint.",
    Value = false,
    Callback = function(v)
        _G.PantaiSprintEnabled = v
        if not v then
            -- Kembalikan ke kecepatan normal game (jika sedang sprint ngebut)
            local char = game:GetService("Players").LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if hum and hum.WalkSpeed == (_G.SprintSpeed or 25) then
                hum.WalkSpeed = 25 -- Kecepatan sprint default bawaan game
            end
        end
    end
})

-- Hijacker Native Sprint Seamless
task.spawn(function()
    local RunService = game:GetService("RunService")
    while Running and not _G.PantaiFisher_Terminated do
        RunService.Heartbeat:Wait()
        if _G.PantaiSprintEnabled then
            local char = game.Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                -- Game bawaan men-set ke 25 saat sprint. Jika kita deteksi >= 24 atau sama dengan custom speed kita
                if hum.WalkSpeed >= 24 or hum.WalkSpeed == _G.SprintSpeed then
                    hum.WalkSpeed = _G.SprintSpeed or 25
                end
            end
        end
    end
end)

_G.SprintSpeed = 25

movementSubTab:Slider({
    Title = "Sprint Speed",
    Desc = "Adjust how fast you run when sprinting",
    Step = 1,
    Min = 17,
    Max = 150,
    Default = 25,
    Callback = function(v)
        _G.SprintSpeed = v
        if _G.SprintActive then
            local char = game:GetService("Players").LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if hum then
                hum.WalkSpeed = v
            end
        end
    end
})

local TpSection = tpSubTab:Section({ Title = "Teleportation Targets" })

local CustomSpots = {
    ["ROD SHOP"] = CFrame.new(1351.58, 105.16, -605.20),
    ["SPOT 1"] = CFrame.new(1740.93, 82.74, -540.36),
    ["SPOT 2"] = CFrame.new(1644.43, 78.75, -820.56),
    ["SPOT 3"] = CFrame.new(1625.82, 82.07, -1160.79),
    ["SPOT 4"] = CFrame.new(1789.58, 73.28, -1276.36),
    ["SPOT 5"] = CFrame.new(1699.70, 76.50, -1002.44),
    ["SPOT 6"] = CFrame.new(1956.53, 101.55, -992.87),
    ["SPOT 7"] = CFrame.new(1300.25, 135.02, -1184.40),
    ["SPOT 8"] = CFrame.new(1035.71, 116.32, -784.90),
}

local spotNames = {"ROD SHOP", "SPOT 1", "SPOT 2", "SPOT 3", "SPOT 4", "SPOT 5", "SPOT 6", "SPOT 7", "SPOT 8"}

_G.SelectedTeleportSpot = "ROD SHOP"

tpSubTab:Dropdown({
    Title = "Select Teleport Spot",
    Desc = "Choose a location from the list",
    Values = spotNames,
    Value = "ROD SHOP",
    Callback = function(v)
        _G.SelectedTeleportSpot = v
    end
})

tpSubTab:Button({
    Title = "Teleport to Selected Spot",
    Desc = "Click to teleport to the selected location",
    Callback = function()
        local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local spotName = _G.SelectedTeleportSpot
        if hrp and CustomSpots[spotName] then
            hrp.CFrame = CustomSpots[spotName]
            WindUI:Notify({ Title = "Teleport", Content = "Teleported to " .. spotName, Duration = 2, Icon = "map-pin" })
        else
            WindUI:Notify({ Title = "Error", Content = "Invalid spot or character not found.", Duration = 3, Icon = "x" })
        end
    end
})

tpSubTab:Divider()

_G.SelectedTpPlayer = "No players found"

local tpPlayerDrop = tpSubTab:Dropdown({
    Title = "Select Player to Teleport",
    Desc = "Choose a player from the server",
    Values = getPlayerList(),
    Value = "No players found",
    Callback = function(val)
        _G.SelectedTpPlayer = getChoice(val)
    end
})

tpSubTab:Button({
    Title = "Refresh Player List",
    Desc = "Refresh the dropdown if someone joined/left",
    Callback = function()
        refreshDropdown(tpPlayerDrop, getPlayerList())
    end
})

tpSubTab:Button({
    Title = "Teleport to Player",
    Desc = "Instantly teleport to the selected player",
    Callback = function()
        if not _G.SelectedTpPlayer or _G.SelectedTpPlayer == "No players found" then
            WindUI:Notify({ Title = "Error", Content = "Please select a valid player first!", Duration = 3, Icon = "x" })
            return
        end
        local targetPlayer = game.Players:FindFirstChild(_G.SelectedTpPlayer)
        local targetHRP = targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if targetHRP and myHRP then
            myHRP.CFrame = targetHRP.CFrame
            WindUI:Notify({ Title = "Teleport", Content = "Teleported to " .. targetPlayer.Name, Duration = 2, Icon = "user" })
        else
            WindUI:Notify({ Title = "Error", Content = "Target player or their character not found in world.", Duration = 3, Icon = "x" })
        end
    end
})

local SpecSection = specSubTab:Section({ Title = "Player Camera Control" })

_G.SelectedSpectatePlayer = "No players found"

local specPlayerDrop = specSubTab:Dropdown({
    Title = "Select Target to Spectate",
    Desc = "Choose a player to spy on",
    Values = getPlayerList(),
    Value = "No players found",
    Callback = function(val)
        _G.SelectedSpectatePlayer = getChoice(val)
        
        -- Auto Switch jika Spectate sedang ON
        if _G.SpectatingActive then
            local cam = workspace.CurrentCamera
            local targetPlayer = game.Players:FindFirstChild(_G.SelectedSpectatePlayer)
            local targetHum = targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid")
            if targetHum then
                cam.CameraSubject = targetHum
                WindUI:Notify({ Title = "Spectate Switched", Content = "Now watching " .. targetPlayer.Name, Duration = 2, Icon = "eye" })
            end
        end
    end
})

specSubTab:Button({
    Title = "Refresh Spectator List",
    Desc = "Update the player list",
    Callback = function()
        refreshDropdown(specPlayerDrop, getPlayerList())
    end
})

specSubTab:Toggle({
    Title = "Spectate Player",
    Desc = "View from the target's perspective",
    Value = false,
    Callback = function(state)
        _G.SpectatingActive = state
        local cam = workspace.CurrentCamera
        local localHum = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
        
        if state then
            if not _G.SelectedSpectatePlayer or _G.SelectedSpectatePlayer == "No players found" then
                WindUI:Notify({ Title = "Error", Content = "Select a player first!", Duration = 3, Icon = "x" })
                if localHum then cam.CameraSubject = localHum end
                return
            end
            
            local targetPlayer = game.Players:FindFirstChild(_G.SelectedSpectatePlayer)
            local targetHum = targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid")
            
            if targetHum then
                cam.CameraSubject = targetHum
                WindUI:Notify({ Title = "Spectate", Content = "Watching " .. targetPlayer.Name, Duration = 2, Icon = "eye" })
            else
                WindUI:Notify({ Title = "Error", Content = "Character not found.", Duration = 3, Icon = "x" })
                if localHum then cam.CameraSubject = localHum end
            end
        else
            if localHum then
                cam.CameraSubject = localHum
                WindUI:Notify({ Title = "Spectate", Content = "Camera returned to you.", Duration = 2, Icon = "eye-off" })
            end
        end
    end
})

-- Smart Catch Backend
local function SetupSmartCatch()
    local player = game.Players.LocalPlayer
    _G.FavRarities = _G.FavRarities or {"Legendary", "Mythical"}
    
    local normMap = {["UnCommon"] = "Uncommon"}
    local favRemote = ReplicatedStorage:FindFirstChild("FishingSystem") 
        and ReplicatedStorage.FishingSystem:FindFirstChild("FishingSystemEvents") 
        and ReplicatedStorage.FishingSystem.FishingSystemEvents:FindFirstChild("Inventory_ToggleFavorite")

    local function HandleNewFish(fish)
        if not fish:IsA("Tool") or fish.Name:lower():find("rod") then return end
        
        -- Wait for attributes to load (Server-side sync)
        local retry = 0
        while not fish:GetAttribute("FishId") and retry < 5 do
            task.wait(0.5)
            retry = retry + 1
        end
        
        local fishId = fish:GetAttribute("FishId")
        if not fishId then return end -- Not a fish

        local rawRarity = fish:GetAttribute("Rarity") or "Common"
        local rarity = normMap[rawRarity] or rawRarity
        local isFav = fish:GetAttribute("isFavorited")
        
        local shouldProtect = table.find(_G.FavRarities or {}, rarity) ~= nil
        
        -- 1. Auto Favorite Protection
        if shouldProtect and favRemote then
            if not isFav then
                favRemote:InvokeServer(fishId)
                WindUI:Notify({ Title = "PROTECTION", Content = "Favorited " .. rawRarity .. "!", Duration = 3, Icon = "star" })
            end
        end
    end

    -- Watch Backpack & Character for new catches
    table.insert(Connections, player.Backpack.ChildAdded:Connect(HandleNewFish))
    if player.Character then
        table.insert(Connections, player.Character.ChildAdded:Connect(HandleNewFish))
    end
    table.insert(Connections, player.CharacterAdded:Connect(function(char)
        table.insert(Connections, char.ChildAdded:Connect(HandleNewFish))
    end))
end

task.spawn(function()
    InitHooks()
    SetupSmartCatch()
    table.insert(Connections, game.Players.LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(1)
        InitHooks()
    end))
    table.insert(Connections, game.Players.PlayerAdded:Connect(function(player)
        if _G.AdminDetector then
            if player:GetRankInGroup(0) > 100 or player.Name:lower():find("admin") or player.Name:lower():find("staff") then
                WindUI:Notify({ Title = "ADMIN DETECTED", Content = player.Name .. " has joined the server!", Duration = 10, Icon = "shield-alert" })
            end
        end
    end))
    local VirtualUser = game:GetService('VirtualUser')
    table.insert(Connections, game.Players.LocalPlayer.Idled:Connect(function() 
        if Running then
            VirtualUser:CaptureController() 
            VirtualUser:ClickButton2(Vector2.new()) 
        end
    end))
end)

-- Stealth Sell Management
local function SetupStealthSell(gui)
    if not gui:IsA("ScreenGui") then return end
    local Frame = gui:FindFirstChild("Frame")
    if Frame and (Frame:FindFirstChild("All") or Frame:FindFirstChild("SellUnder50Kg")) then
        local conn = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if _G.StealthSell and gui.Enabled then
                gui.Enabled = false
            end
        end)
        table.insert(Connections, conn)
        if _G.StealthSell then gui.Enabled = false end
    end
end

task.spawn(function()
    local pg = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    for _, v in pairs(pg:GetChildren()) do SetupStealthSell(v) end
    table.insert(Connections, pg.ChildAdded:Connect(SetupStealthSell))
    
    while Running and not _G.PantaiFisher_Terminated and task.wait(0.1) do
        -- Double Check Loop for extra safety
        if _G.FastHook or _G.InstantLand then
            StopRodAnimations()
        end
    end
end)

-- Market Logic
local function GetFishCount()
    local player = game.Players.LocalPlayer
    local count = 0
    for _, item in pairs(player.Backpack:GetChildren()) do
        if item:GetAttribute("FishId") then count = count + 1 end
    end
    if player.Character then
        for _, item in pairs(player.Character:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("FishId") then count = count + 1 end
        end
    end
    return count
end

task.spawn(function()
    while Running and not _G.PantaiFisher_Terminated and task.wait(5) do
        if _G.AutoSell then 
            local mode = _G.SellMode or "All"
            local trigger = _G.SellTrigger or "Periodic (5s)"
            local threshold = tonumber(trigger:match("%d+"))
            
            local shouldSell = false
            if trigger:find("Items") and threshold then
                local currentCount = GetFishCount()
                if currentCount >= threshold then
                    shouldSell = true
                    WindUI:Notify({
                        Title = "CAPACITY TRIGGER",
                        Content = "Inventory reached " .. currentCount .. " items!",
                        Duration = 3,
                        Icon = "bag"
                    })
                end
            else
                -- Periodic is always true every 5s loop
                shouldSell = true
            end

            if shouldSell then
                JualRemote:FireServer(mode)
            end
        end
    end
end)

-- Shop Backend
local function OwnsRod(name)
    local player = game.Players.LocalPlayer
    local searchName = name:lower():gsub("rod", ""):gsub("%s+", "")
    local function check(container)
        for _, item in pairs(container:GetChildren()) do
            local itemName = item.Name:lower():gsub("rod", ""):gsub("%s+", "")
            if itemName:find(searchName) or searchName:find(itemName) then return true end
        end
        return false
    end
    return check(player.Backpack) or check(player.StarterGear) or (player.Character and check(player.Character))
end

local function BuyNextRod(best)
    local configModule = ReplicatedStorage:FindFirstChild("FishingSystem", true) and ReplicatedStorage:FindFirstChild("FishingSystem", true):FindFirstChild("FishNRodPriceConfig", true)
    if not configModule then return end
    
    local s, m = pcall(require, configModule)
    if not (s and type(m) == "table" and m.Rods) then return end
    
    local player = game.Players.LocalPlayer
    local leaderstats = player:FindFirstChild("leaderstats")
    local money = leaderstats and (leaderstats:FindFirstChild("Money") or leaderstats:FindFirstChild("Rupiah") or leaderstats:FindFirstChild("Cash"))
    if not money then return end
    
    local currentMoney = money.Value
    local sortedRods = {}
    
    for name, data in pairs(m.Rods) do
        if data.Price and data.Price > 0 and not data.IsVIP and not data.GamepassRods then
            table.insert(sortedRods, {Name = name, Price = data.Price})
        end
    end
    
    table.sort(sortedRods, function(a, b) return a.Price < b.Price end)
    
    local buyRemote = ReplicatedStorage:FindFirstChild("PromptBuyRod")
    if not buyRemote then return end

    if best then
        for i = #sortedRods, 1, -1 do
            if currentMoney >= sortedRods[i].Price and not OwnsRod(sortedRods[i].Name) then
                buyRemote:FireServer(sortedRods[i].Name)
                WindUI:Notify({ Title = "SHOP", Content = "Buying Best: " .. sortedRods[i].Name, Duration = 3, Icon = "shopping-cart" })
                break
            end
        end
    else
        for _, rod in ipairs(sortedRods) do
            if currentMoney >= rod.Price and not OwnsRod(rod.Name) then
                buyRemote:FireServer(rod.Name)
                WindUI:Notify({ Title = "SHOP", Content = "Auto Buy: " .. rod.Name, Duration = 3, Icon = "shopping-cart" })
                break
            end
        end
    end
end

task.spawn(function()
    while Running and not _G.PantaiFisher_Terminated and task.wait(10) do
        if _G.AutoBuyRod then
            BuyNextRod(false)
        end
    end
end)


-- Auto Collect Loot Loop
task.spawn(function()
    while Running and not _G.PantaiFisher_Terminated and task.wait(0.5) do
        if _G.AutoCollectLoot then
            local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local rawNames = string.split(_G.TargetLootNames:lower(), ",")
                local names = {}
                for _, n in ipairs(rawNames) do
                    local str = n:match("^%s*(.-)%s*$")
                    if str ~= "" then table.insert(names, str) end
                end
                
                for _, obj in pairs(workspace:GetChildren()) do
                    if obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Tool") then
                        local objName = obj.Name:lower()
                        local isTarget = false
                        for _, n in ipairs(names) do
                            if objName:find(n) then
                                isTarget = true
                                break
                            end
                        end
                        
                        if isTarget then
                            -- Perbaikan: Cek sentuhan jarak jauh (Stealth)
                            local canTouch = obj:IsA("BasePart") or (obj:IsA("Model") and obj.PrimaryPart)
                            
                            if canTouch and firetouchinterest then
                                -- Mencoba menyentuh tanpa teleport (Invisible Magnet)
                                local targetPart = obj:IsA("Model") and obj.PrimaryPart or obj
                                pcall(function()
                                    firetouchinterest(hrp, targetPart, 0)
                                    task.wait()
                                    firetouchinterest(hrp, targetPart, 1)
                                end)
                            end

                            -- Jika firetouchinterest tidak cukup atau ingin tetap Teleport (Fallback)
                            if _G.TeleportCollect then
                                local pos = obj:IsA("Model") and obj:GetPivot().Position or (obj:IsA("BasePart") and obj.Position) or (obj:IsA("Tool") and obj.Handle and obj.Handle.Position)
                                if pos then
                                    local originalCFrame = hrp.CFrame
                                    hrp.CFrame = CFrame.new(pos)
                                    
                                    local prompt = obj:FindFirstChildOfClass("ProximityPrompt")
                                    if not prompt and obj.Parent then
                                        prompt = obj.Parent:FindFirstChildOfClass("ProximityPrompt")
                                    end
                                    if prompt and fireproximityprompt then
                                        pcall(function() fireproximityprompt(prompt) end)
                                    end
                                    
                                    task.wait(0.1)
                                    hrp.CFrame = originalCFrame
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Optimized Fast-Loop for God Speed
task.spawn(function()
    local RunService = game:GetService("RunService")
    while Running and not _G.PantaiFisher_Terminated do
        if _G.BlatantMode then
            RunService.Heartbeat:Wait()
        else
            task.wait(0.01)
        end
        
        if _G.AutoFish then
            local Rod = GetRod()
            local cooldown = 0.8
            if _G.BlatantMode then cooldown = 0 end
            if _G.LegitMode then cooldown = 1.6 end
            
            if IsCasting and tick() - LastCastTime > 10 then IsCasting = false end

            if Rod and not IsCasting and not InMinigame and (tick() - LastAction > cooldown) then
                IsCasting = true
                LastCastTime = tick()
                
                if _G.LegitMode then
                    Rod:Activate()
                else
                    if Rod:FindFirstChild("CastToPosition") then
                        local target = (_G.BlatantMode and _G.InstantLand) and FindWaterPosition() or nil
                        Rod.CastToPosition:FireServer(target)
                    end
                end
            end
        end
    end
end)

print("Fisher WindUI Loaded!")

-- Force Follow & Mimic Logic
task.spawn(function()
    local RunService = game:GetService("RunService")
    local lastChar = nil

    while Running and not _G.PantaiFisher_Terminated do
        pcall(function()
            if _G.FollowActive and _G.FollowTarget and _G.FollowTarget ~= "No players found" then
                local target = game.Players:FindFirstChild(_G.FollowTarget)
                local tChar = target and target.Character
                local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
                local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
                
                local lChar = game.Players.LocalPlayer.Character
                local lHRP = lChar and lChar:FindFirstChild("HumanoidRootPart")
                local lHum = lChar and lChar:FindFirstChildOfClass("Humanoid")

                -- Respawn detection
                if lChar ~= lastChar then
                    for _, track in pairs(activeTracks) do track:Stop() end
                    table.clear(activeTracks)
                    lastChar = lChar
                end

                if tHRP and lHRP then
                    -- Physics suppression
                    lHRP.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    lHRP.AssemblyAngularVelocity = Vector3.new(0,0,0)
                    
                    -- Offset Calculation
                    local offset = Vector3.new(0,0,0)
                    local d = _G.FollowDistance
                    if _G.FollowMode == "Behind" then offset = tHRP.CFrame.LookVector * -d
                    elseif _G.FollowMode == "Front" then offset = tHRP.CFrame.LookVector * d
                    elseif _G.FollowMode == "Right" then offset = tHRP.CFrame.RightVector * d
                    elseif _G.FollowMode == "Left" then offset = tHRP.CFrame.RightVector * -d
                    elseif _G.FollowMode == "Above" then offset = Vector3.new(0, d, 0) end
                    
                    lChar:PivotTo(tHRP.CFrame + offset)

                    -- Animation Mimicry
                    if _G.MimicAnimations and tHum and lHum then
                        local tAnimator = tHum:FindFirstChildOfClass("Animator")
                        local lAnimator = lHum:FindFirstChildOfClass("Animator")
                        if tAnimator and lAnimator then
                            local seen = {}
                            for _, tTrack in pairs(tAnimator:GetPlayingAnimationTracks()) do
                                local id = tTrack.Animation.AnimationId
                                seen[id] = true
                                if not activeTracks[id] then
                                    local s, nTrack = pcall(function() return lAnimator:LoadAnimation(tTrack.Animation) end)
                                    if s then
                                        nTrack:Play()
                                        activeTracks[id] = nTrack
                                    end
                                end
                                if activeTracks[id] then
                                    activeTracks[id]:AdjustSpeed(tTrack.Speed)
                                    activeTracks[id].TimePosition = tTrack.TimePosition
                                    activeTracks[id]:AdjustWeight(tTrack.WeightTarget, 0.1)
                                end
                            end
                            for id, track in pairs(activeTracks) do
                                if not seen[id] then
                                    track:Stop()
                                    activeTracks[id] = nil
                                end
                            end
                        end
                    end
                end
            else
                -- Stop animations if not following
                if next(activeTracks) ~= nil then
                    for _, track in pairs(activeTracks) do track:Stop() end
                    table.clear(activeTracks)
                end
            end
        end)
        RunService.Heartbeat:Wait()
    end
end)
