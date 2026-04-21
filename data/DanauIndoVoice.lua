--[[
    DANAU INDO VOICE - ULTIMATE HUB (V56 - PREMIUM FEEDBACK)
    Features:
    - Smart Notification Mirror: Mirroring game text to Hub status bar.
    - Non-Destructive Stealth: Hiding buttons but keeping logs alive.
    - No-Flicker Protection.
    - All standard stable features (Fish 65%, Mine, 100 Min Sell).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

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
    UserId = LocalPlayer.UserId,
    Username = LocalPlayer.Name
}
_G.sessionData = sessionData

-- Global Stopper
_G.StopDanauHub = true; task.wait(0.5); _G.StopDanauHub = false

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CastEvent = Remotes:WaitForChild("CastEvent")
local MiniGameRemote = Remotes:WaitForChild("MiniGame")
local MineEvent = ReplicatedStorage:WaitForChild("MineEvent")
local JualIkanRemote = ReplicatedStorage:WaitForChild("JualIkanRemote")
local JualBatuRemote = ReplicatedStorage:WaitForChild("JualBatuRemote", 5)
local SellAllEvent = ReplicatedStorage:WaitForChild("SellAllEvent", 5)
local SellOneEvent = ReplicatedStorage:WaitForChild("SellOneEvent", 5)
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 5)
local OpenShopRemote = RemoteEvents and RemoteEvents:WaitForChild("OpenFishingShopEvent", 5)
local OpenMineShopRemote = RemoteEvents and RemoteEvents:WaitForChild("OpenPickaxeShopEvent", 5)
local FavoriteRemote = ReplicatedStorage:FindFirstChild("FavoriteEvent", true) or ReplicatedStorage:FindFirstChild("ToggleFavorite", true) or Remotes:FindFirstChild("Favorite")
local NotifyClient = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NotifyClient")

-- [ UTILITY FUNCTIONS ] --
local function ServerHop()
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    
    if statusLabel then statusLabel.Text = "MISC: Searching for new server..." end
    local success, result = pcall(function()
        return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
    end)
    
    if success then
        local Servers = HttpService:JSONDecode(result)
        for _, v in ipairs(Servers.data) do
            if v.playing < v.maxPlayers and v.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, LocalPlayer)
                return
            end
        end
        if notify then notify("No suitable servers found!") end
    else
        if notify then notify("Failed to fetch server list.") end
    end
end

local function RejoinServer()
    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end

-- State
local config = {
    mine = false, fish = false, fishBlatant = false,
    autoSell = false,
    sellAllBase = false,
    sellRare = false, sellMythic = false, sellSecret = false,
    sellOre = false,
    autoDelivery = false, adminDetect = true
}

local statusLabel -- Global reference for notification

-- [[ ANTI-CRASH BOOTSTRAP SYSTEM ]] --
-- Mengamankan semua hook agar tidak bertumpuk saat re-execute
_G.DanauIndo_State = _G.DanauIndo_State or {
    config = config,
    currentTarget = nil,
    Mouse = LocalPlayer:GetMouse(),
    Remotes = {}
}
-- Selalu update config terbaru ke state global
_G.DanauIndo_State.config = config

if not _G.DanauIndo_SystemHooked then
    -- === FUNGSI INTI REBRANDING (CATCH ALL) ===
    local function applyRebrand(name, data)
        if name == "SendNotification" and type(data) == "table" then
            local title = tostring(data.Title or "")
            local text = tostring(data.Text or "")
            local targetTitle = title:lower()
            local targetText = text:lower()
            
            if targetTitle:find("anti") or targetTitle:find("adonis") or targetText:find("anti") or targetText:find("pixel") or targetText:find("detect") then
                data.Title = "STARSHIP SYSTEM"
                data.Text = "Anti-Cheat Bypassed Successfully!"
                data.Icon = "rbxassetid://85930777472774"
                data.Duration = 5
                return true
            end
        end
        return false
    end

    -- 0. Hook SetCore (StarterGui)
    local oldSetCore
    oldSetCore = hookfunction(StarterGui.SetCore, function(self, name, data)
        applyRebrand(name, data)
        return oldSetCore(self, name, data)
    end)

    -- 1. [ INDEX HOOK ] (Mouse Spoofer)
    local oldIndex; oldIndex = hookmetamethod(game, "__index", function(self, key)
        local state = _G.DanauIndo_State
        if not checkcaller() and state.config.mine and state.currentTarget and self == state.Mouse then
            if key == "Target" then return state.currentTarget
            elseif key == "Hit" then 
                local s, r = pcall(function() return state.currentTarget.CFrame end)
                return s and r or oldIndex(self, key)
            end
        end
        return oldIndex(self, key)
    end)

    -- 2. [ NAMECALL HOOK ] (Anti-AFK & Log Stealth)
    local oldNamecall; oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        local state = _G.DanauIndo_State
        
        -- A. Rebrand logic (SETCORE)
        if (method == "SetCore" or method == "setCore") and self == StarterGui then
            if applyRebrand(args[1], args[2]) then
                return oldNamecall(self, unpack(args))
            end
        end

        -- Anti-AFK Protect
        if state.config.antiAfk and method == "FireServer" and self.Name == "AFK" and args[1] == true then
            return nil
        end
        
        return oldNamecall(self, ...)
    end)

    -- 3. [ NEWINDEX HOOK ] (Log Stealth Override)
    local oldNewIndex; oldNewIndex = hookmetamethod(game, "__newindex", function(self, key, value)
        if _G.DanauIndo_State.config.logStealth and key == "OnClientInvoke" and self.Name == "getClientLogs" then
            return oldNewIndex(self, key, function() return {} end)
        end
        return oldNewIndex(self, key, value)
    end)

    _G.DanauIndo_SystemHooked = true
    
    -- Load External Bypass (LOAD AFTER HOOKS TO ENSURE REBRAND)
    pcall(function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/Pixeluted/adoniscries/main/Source.lua'))()
    end)
    
    print("--- DANAU INDO: HOOKS SECURED (Anti-Crash Active) ---")
end

-- [ LOG STEALTH ENGINE - FORCE SET ] --
task.spawn(function()
    local bloxRemotes = ReplicatedStorage:WaitForChild("BloxbizRemotes", 5)
    local getLogs = bloxRemotes and bloxRemotes:WaitForChild("getClientLogs", 5)
    if getLogs and config.logStealth then
        getLogs.OnClientInvoke = function() return {} end
    end
end)

-- [ ANTI-AFK ENGINE - FORCE SET ] --
local afkEvent = ReplicatedStorage:WaitForChild("AFK", 5)
if afkEvent then
    local oldFire; oldFire = hookfunction(afkEvent.FireServer, function(self, ...)
        if config.antiAfk and rawequal(self, afkEvent) and select(1, ...) == true then
            return nil
        end
        return oldFire(self, ...)
    end)
end

-- [ ON-CLIENT-EVENT INTERCEPTOR V2 (HYBRID TECH) ] --
local function manageRemoteSignals()
    local targetRemotes = { JualIkanRemote, JualBatuRemote }
    
    -- A. Hijack Existing Connections (Internal Logic)
    for _, r in ipairs(targetRemotes) do
        if r and r:FindFirstChild("OnClientEvent") then
            for _, conn in ipairs(getconnections(r.OnClientEvent)) do
                local oldFunc = conn.Function
                conn:Disable()
                r.OnClientEvent:Connect(function(...)
                    if not config.autoSell then return oldFunc(...) end
                end)
            end
        end
    end

    -- B. [ ANTI-BLINK KERNEL HOOK ] --
    -- Mencegat perubahan properti .Enabled di tingkat mesin Roblox
    local oldNewIndex; oldNewIndex = hookmetamethod(game, "__newindex", function(self, key, value)
        if not checkcaller() and config.autoSell then
            if (self.Name == "JualGui" or self.Name == "SellMenuGui") and key == "Enabled" and value == true then
                -- Buang pesanan '.Enabled = true' dari script game agar tidak berkedip
                return 
            end
        end
        return oldNewIndex(self, key, value)
    end)
end

-- Jalankan Interceptor
pcall(manageRemoteSignals)

-- [[ UI CONSTRUCTION WITH WINDUI BOREAL ]] --

-- [[ UI CONSTRUCTION WITH WINDUI BOREAL ]] --
-- [ UI CONSTRUCTION WITH WINDUI BOREAL ] --
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/billy17-netizen/windUIBoreal/refs/heads/main/WindUI_Boreal.lua"))()

local Window = WindUI:CreateWindow({
    Title = "STARSHIP┃dsc.gg-starshipcore",
    Icon = "rbxassetid://85930777472774",
    IconSize = 45,
    Author = "Premium Edition | StarshipCore",
    Size = UDim2.fromOffset(680, 400),
    SideBarWidth = 180,
    Transparent = true,
    Theme = "Crimson",
    Background = "rbxassetid://132820581372516",
    BackgroundImageTransparency = 0.92,
    OpenButton = {
        Title = "STARSHIP ✨",
        Icon = "rbxassetid://85930777472774",
        IconSize = 22, -- Base size (will be overridden by manual fix below)
        IconThemed = false,
        Size = UDim2.fromOffset(155, 48), 
        SideBarWidth = 180,
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
})

-- Notification Wrapper
local function notify(text)
    WindUI:Notify({
        Title = "DANAU INDO",
        Content = text,
        Duration = 5
    })
end

-- [ CLEANUP SYSTEM ] --
local function cleanupHub()
    if _G.StopDanauHub then return end
    _G.StopDanauHub = true
    print("🛑 DANAU INDO: Cleaning up resources...")
end

-- === PREMIUM OVERLAYS & FIXES ===
-- 1. Watermark
Window:Watermark({
    Text = "STARSHIP PREMIUM┃DANAU INDO VOICE",
    Position = "bottom-right",
    Opacity = 0.45,
    Size = 12,
})

-- 2. Logo Scale Fix
pcall(function()
    local bgFrame = Window.Internal.Background
    local img = bgFrame:FindFirstChildOfClass("ImageLabel")
    if img then
        img.ScaleType = Enum.ScaleType.Fit
    end
end)

-- 3. Shortcut Key
Window:SetToggleKey(Enum.KeyCode.LeftControl)
notify("Tekan 'Left Control' untuk buka/tutup GUI")

-- 4. Cleanup Hook (Sync with SambungKata)
pcall(function()
    Window:OnDestroy(function()
        cleanupHub()
    end)
    
    if Window.Instance then
        Window.Instance.AncestryChanged:Connect(function()
            if not Window.Instance or not Window.Instance:IsDescendantOf(game) then
                cleanupHub()
            end
        end)
    end
end)

-- [[ PERFORMANCE TAGS ]] --
local FPSTag = Window:Tag({
    Title = "⚡ FPS: --",
    Color = Color3.fromRGB(68, 216, 114),
})

local PingTag = Window:Tag({
    Title = "📶 PING: --ms",
    Color = Color3.fromRGB(75, 155, 255),
})

-- Live Stats Loop
task.spawn(function()
    local frameCount = 0
    local lastUpdate = tick()
    
    local conn = RunService.Heartbeat:Connect(function() 
        frameCount = frameCount + 1 
    end)
    
    while not _G.StopDanauHub do
        task.wait(1)
        local now = tick()
        local elapsed = now - lastUpdate
        local fps = math.floor(frameCount / elapsed)
        local ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        
        pcall(function()
            FPSTag:SetTitle("⚡ FPS: " .. fps)
            PingTag:SetTitle("📶 PING: " .. ping .. "ms")
        end)
        
        frameCount = 0
        lastUpdate = now
    end
    conn:Disconnect()
end)

-- Notification Wrapper
-- (Moved up to fix nil error)

-- [ CLEANUP SYSTEM ] --
-- (Moved up to fix nil error)

-- Update statusLabel reference for backward compatibility
statusLabel = { Text = "" }
setmetatable(statusLabel, {
    __newindex = function(t, k, v)
        if k == "Text" then
            rawset(t, k, v)
            if v ~= "" and not v:find("READY") then
                notify(v)
            end
        end
    end
})

local Tabs = {
    Home = Window:Tab({ Title = "Home", Icon = "layout-grid" }),
    Fish = Window:Tab({ Title = "Fishing", Icon = "fish" }),
    Mine = Window:Tab({ Title = "Mining", Icon = "pickaxe" }),
    Shop = Window:Tab({ Title = "Shop", Icon = "shopping-cart" }),
    Misc = Window:Tab({ Title = "Misc", Icon = "asterisk" }),
    Settings = Window:Tab({ Title = "System", Icon = "settings" })
}
Tabs.Home:Select()

-- [[ HOME TAB ]] --
local HomeMulti = Tabs.Home:MultiSection({
    Title = "Dashboard Overview",
    Icon = "layout-grid",
    Box = true,
    BoxBorder = true,
    Opened = true
})

local overviewSubTab = HomeMulti:Tab({ Title = "Overview", Icon = "info" })
local accountSubTab = HomeMulti:Tab({ Title = "Account", Icon = "user" })

-- Overview Content
overviewSubTab:Section({ Title = "Main Dashboard" })

overviewSubTab:Paragraph({ 
    Title = "👤 Welcome back, " .. (LocalPlayer.DisplayName or LocalPlayer.Name) .. "!",
    Desc = "Starship Premium is fully active. All security protocols bypassed."
})

overviewSubTab:Button({
    Title = "Join Community (Discord)",
    Icon = "message-circle",
    Callback = function()
        setclipboard("https://discord.gg/ftmA7BheTc")
        notify("Discord link copied to clipboard!")
    end
})

overviewSubTab:Divider()

local InfoSection = overviewSubTab:Section({ Title = "Script Information", Opened = true })
InfoSection:Paragraph({
    Title = "DANAU INDO ULTIMATE",
    Desc = "Version: V56 PREMIUM\nStatus: UNDETECTED\nGame: Danau Indo Voice"
})

InfoSection:Paragraph({
    Title = "Credits",
    Desc = "Developed by: STARSHIP-CORE\nUI: WindUI"
})

-- Account Content (VIP Status)
do
    local VIPSection = accountSubTab:Section({ Title = "VIP Status", Icon = "star" })
    
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
            while not _G.StopDanauHub do
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

    local ply = LocalPlayer
    local accDesc = string.format("Username: @%s\nDisplay Name: %s\nUser ID: %s\nAccount Age: %d days", 
        (ply and ply.Name) or "Unknown", 
        (ply and ply.DisplayName) or "Unknown", 
        (ply and tostring(ply.UserId)) or "Unknown", 
        (ply and ply.AccountAge) or 0
    )

    accountSubTab:Section({ Title = "Player Information", Icon = "user-round" })
    accountSubTab:Paragraph({
        Title = "User Profile",
        Desc = accDesc,
    })
end

overviewSubTab:Select()

-- [[ FISHING TAB ]] --
local FishMulti = Tabs.Fish:MultiSection({ 
    Title = "Fishing Operations",
    Icon = "fish",
    Opened = true
})

local FishFarm = FishMulti:Tab({ Title = "Farm Fish", Icon = "shrub" })
FishFarm:Toggle({
    Title = "Auto Fish",
    Desc = "Otomatis memancing ikan saat memegang pancingan.",
    Value = config.fish,
    Callback = function(v) config.fish = v end
})
FishFarm:Toggle({
    Title = "Blatant (Insta Catch)",
    Desc = "Menangkap ikan secara instan tanpa minigame (Agresif).",
    Value = config.fishBlatant,
    Callback = function(v) config.fishBlatant = v end
})

local FishSell = FishMulti:Tab({ Title = "Sell Fish", Icon = "shopping-cart" })
FishSell:Toggle({
    Title = "Auto Sell Manager",
    Desc = "Otomatis menjual ikan jika inventori mencapai batas tertentu.",
    Value = config.autoSell,
    Callback = function(v) config.autoSell = v end
})
FishSell:Slider({
    Title = "Min Items to Sell",
    Value = {
        Min = 1,
        Max = 250,
        Default = config.minFish
    },
    Callback = function(v) config.minFish = v end
})
FishSell:Divider()
FishSell:Toggle({
    Title = "Bulk Sell (Comm/Unc)",
    Desc = "Menjual Common & Uncommon (Mythic/Rare/Secret AMAN).",
    Value = config.sellAllBase,
    Callback = function(v) config.sellAllBase = v end
})
FishSell:Toggle({
    Title = "Sell RARE",
    Desc = "Otomatis menjual kategori RARE.",
    Value = config.sellRare,
    Callback = function(v) config.sellRare = v end
})
FishSell:Toggle({
    Title = "Sell MYTHIC",
    Desc = "Otomatis menjual kategori MYTHIC.",
    Value = config.sellMythic,
    Callback = function(v) config.sellMythic = v end
})
FishSell:Toggle({
    Title = "Sell SECRET",
    Desc = "Otomatis menjual kategori SECRET.",
    Value = config.sellSecret,
    Callback = function(v) config.sellSecret = v end
})

-- [[ MINING TAB ]] --
local MineMulti = Tabs.Mine:MultiSection({ 
    Title = "Mining Operations",
    Icon = "pickaxe",
    Opened = true
})

local MineFarm = MineMulti:Tab({ Title = "Farm Ore", Icon = "shrub" })
MineFarm:Toggle({
    Title = "Auto Mine (Turbo Safe)",
    Desc = "Otomatis menambang dengan kecepatan maksimal (Anti-Kick).",
    Value = config.mine,
    Callback = function(v) 
        config.mine = v
        if config.mine then _G.DanauIndo_State.currentTarget = nil end
    end
})
MineFarm:Toggle({
    Title = "Auto TP Block",
    Desc = "Teleport otomatis ke lokasi tambang terdekat (AFK Mine).",
    Value = config.tp, -- matched to config.tp in state
    Callback = function(v) 
        config.tp = v
        if config.tp then _G.DanauIndo_State.currentTarget = nil end
    end
})

local MineSell = MineMulti:Tab({ Title = "Sell Ore", Icon = "shopping-cart" })
MineSell:Toggle({
    Title = "Sell ALL ORE",
    Desc = "Otomatis mencari NPC dan menjual semua hasil tambang.",
    Value = config.sellOre,
    Callback = function(v) config.sellOre = v end
})

-- [[ SHOP TAB ]] --
local ShopSection = Tabs.Shop:Section({ Title = "World Shops", Opened = true })
ShopSection:Button({
    Title = "Open Fishing Shop",
    Icon = "fish",
    Callback = function()
        if OpenShopRemote then
            if firesignal then
                firesignal(OpenShopRemote.OnClientEvent)
            else
                OpenShopRemote:FireServer()
            end
        else
            pcall(function()
                local gui = LocalPlayer.PlayerGui:FindFirstChild("FishingStore") or LocalPlayer.PlayerGui:FindFirstChild("FishingShop")
                if gui then
                    gui.Enabled = true
                end
            end)
        end
    end
})
ShopSection:Button({
    Title = "Open Pickaxe Shop",
    Icon = "pickaxe",
    Callback = function()
        if OpenMineShopRemote then
            if firesignal then
                firesignal(OpenMineShopRemote.OnClientEvent)
            else
                OpenMineShopRemote:FireServer()
            end
        else
            pcall(function()
                local gui = LocalPlayer.PlayerGui:FindFirstChild("MiningShop") or LocalPlayer.PlayerGui:FindFirstChild("PickaxeShop")
                if gui then
                    gui.Enabled = true
                end
            end)
        end
    end
})

ShopSection:Button({
    Title = "Open Fish Sell Menu",
    Icon = "dollar-sign",
    Desc = "Membuka menu jual ikan (JualGui Smart Search).",
    Callback = function()
        -- 1. Pemicu Sinyal (Agar data masuk)
        if JualIkanRemote and firesignal then
            firesignal(JualIkanRemote.OnClientEvent, "Jualan")
        end
        
        -- 2. Pencarian GUI secara Agresif
        local pg = LocalPlayer.PlayerGui
        local target = pg:FindFirstChild("JualGui")
        
        -- Jika JualGui tidak ditemukan, cari GUI yang berisi tombol 'Mythic'
        if not target then
            for _, gui in ipairs(pg:GetChildren()) do
                if gui:IsA("ScreenGui") and (gui:FindFirstChild("Mythic", true) or gui:FindFirstChild("Rare", true)) then
                    target = gui
                    break
                end
            end
        end
        
        -- 3. Memaksa Muncul secara Agresif
        if target then
            target.Enabled = true
            target.DisplayOrder = 9999 -- Pastikan di atas segalanya
            
            for _, f in ipairs(target:GetDescendants()) do
                if f:IsA("Frame") or f:IsA("ScrollingFrame") or f:IsA("CanvasGroup") then
                    f.Visible = true
                    -- Jika ada transparansi yang menghalangi
                    if f:IsA("CanvasGroup") then f.GroupTransparency = 0 end
                elseif f:IsA("TextLabel") or f:IsA("TextButton") then
                    f.BackgroundTransparency = (f.BackgroundTransparency == 1 and 1 or 0)
                    f.TextTransparency = 0
                end
            end
            
            -- Refresh GUI (Matikan lalu nyalakan lagi)
            target.Enabled = false
            task.wait(0.05)
            target.Enabled = true
            
            statusLabel.Text = "SHOP: Fish Menu Forced!"
        else
            statusLabel.Text = "ERROR: Fish Menu Not Found!"
            notify("❌ Gagal menemukan menu jual ikan.")
        end
    end
})

ShopSection:Button({
    Title = "Open Mining Menu",
    Icon = "pickaxe",
    Desc = "Membuka menu jual hasil tambang (JualBatuRemote).",
    Callback = function()
        -- Memicu remote Jual Batu
        if JualBatuRemote then
            if firesignal then
                firesignal(JualBatuRemote.OnClientEvent, "Jualan")
            end
        end
        -- Memaksa UI SellMenuGui (Jual Batu) terbuka
        local gui = LocalPlayer.PlayerGui:FindFirstChild("SellMenuGui")
        if gui then
            gui.Enabled = true
            local frame = gui:FindFirstChildWhichIsA("Frame")
            if frame then frame.Visible = true end
        end
    end
})

-- All controls consolidated into categorical tabs.

-- [[ MISC TAB ]] --
local MiscSection = Tabs.Misc:Section({ Title = "Additional Tools", Opened = true })

MiscSection:Toggle({
    Title = "Anti-AFK Protect",
    Desc = "Mencegah kick oleh sistem Roblox karena tidak bergerak.",
    Value = config.antiAfk,
    Callback = function(v) config.antiAfk = v end
})

MiscSection:Toggle({
    Title = "Auto Delivery",
    Desc = "Teleport otomatis untuk menyelesaikan misi kurir/antar barang.",
    Value = config.autoDelivery,
    Callback = function(v) config.autoDelivery = v end
})

MiscSection:Toggle({
    Title = "Detect Admin",
    Desc = "Notifikasi waspada jika ada staf/admin masuk ke server.",
    Value = config.adminDetect,
    Callback = function(v) config.adminDetect = v end
})

MiscSection:Divider()

MiscSection:Button({
    Title = "Server Hop",
    Icon = "refresh-cw",
    Callback = function() ServerHop() end
})

MiscSection:Button({
    Title = "Rejoin Server",
    Icon = "log-out",
    Callback = function() RejoinServer() end
})

-- [[ SYSTEM TAB ]] --
local SysSection = Tabs.Settings:Section({ Title = "Global Controls", Opened = true })
SysSection:Toggle({
    Title = "Log Stealth",
    Desc = "Menghapus log eksekusi agar tidak terdeteksi oleh admin game.",
    Value = config.logStealth,
    Callback = function(v) config.logStealth = v end
})
SysSection:Button({
    Title = "🛑 Stop Hub",
    Callback = function() 
        cleanupHub()
        Window:Destroy()
    end
})

-- [ INVENTORY SCANNER ] --
local function getFishCount()
    local c = 0
    local function scan(cont) for _, it in ipairs(cont:GetChildren()) do if it:IsA("Tool") and not it.Name:lower():find("rod") and not it.Name:lower():find("pick") and not it.Name:lower():find("pancing") then c=c+1 end end end
    scan(LocalPlayer.Backpack); scan(LocalPlayer.Character); return c
end

-- [ AUTO SELL LOGIC ] --
task.spawn(function()
    while not _G.StopDanauHub do
        task.wait(5)
        if config.autoSell then
            local total = getFishCount()
            if total >= config.minFish then
                if config.sellAllBase then JualIkanRemote:FireServer("All"); task.wait(0.5) end
                if config.sellRare then JualIkanRemote:FireServer("Rare"); task.wait(0.5) end
                if config.sellMythic then JualIkanRemote:FireServer("Mythic"); task.wait(0.5) end
                if config.sellSecret then JualIkanRemote:FireServer("Secret"); task.wait(0.5) end
            end
        end
    end
end)

-- [ SECONDARY SELL ENGINE - SPECIFIC FOR ORE ] --
task.spawn(function()
    while not _G.StopDanauHub do
        task.wait(5) -- Cooldown checking
        if config.sellOre and SellAllEvent then
            if getFishCount() > 0 then
                statusLabel.Text = "ORE: Selling All Ores..."
                SellAllEvent:FireServer()
                task.wait(3.2) -- Matches script cooldown (3s)
                statusLabel.Text = "READY - Waiting for fish..."
            end
        end
    end
end)

-- [ ENGINE CORE ] --
local function getTool(kws)
    local char = LocalPlayer.Character; if not char then return end
    for _, v in ipairs(char:GetChildren()) do if v:IsA("Tool") then local n=v.Name:lower(); for _, kw in ipairs(kws) do if n:find(kw) then return v end end end end
    for _, v in ipairs(LocalPlayer.Backpack:GetChildren()) do if v:IsA("Tool") then local n=v.Name:lower(); for _, kw in ipairs(kws) do if n:find(kw) then v.Parent=char; task.wait(0.3); return v end end end end
end

task.spawn(function()
    while not _G.StopDanauHub do
        task.wait(1); if not config.fish then continue end
        local r = getTool({"rod", "pancing"})
        if r then
            local s = r:FindFirstChild("Status", true)
            if s and not s:GetAttribute("Casted") and not s:GetAttribute("MiniGame") then
                if config.fishBlatant then CastEvent:FireServer(true); task.wait(0.01); CastEvent:FireServer(false, 65)
                else r:Activate(); task.wait(0.8); r:Deactivate() end
            end
        end
    end
end)

MiniGameRemote.OnClientEvent:Connect(function(m) 
    if config.fish and m == "Start" then 
        -- Jeda instan untuk mode blatant, ~2.3s untuk normal
        local waitTime = config.fishBlatant and 0.01 or (2.3 + math.random() * 0.4)
        task.wait(waitTime)
        
        -- Beritahu server minigame selesai dan kita menang
        MiniGameRemote:FireServer("End", true) 
        
        -- Sinyal 'Tarik' (Penting agar ikan naik ke darat)
        task.wait(0.1)
        CastEvent:FireServer(false, 75)

        -- Jeda Cooldown 1 detik (Sesuai v_u_17 di script alat pancing asli)
        -- Ini mencegah pancingan macet tidak mau melempar lagi
        task.wait(1.2)
    end 
end)

task.spawn(function()
    while not _G.StopDanauHub do
        task.wait(0.5)
        if not config.mine or config.autoDelivery then 
            _G.DanauIndo_State.currentTarget = nil 
            continue 
        end
        
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        if not root or not hum then continue end
        
        local p = getTool({"pick", "beliung"})
        if not p then continue end
        
        -- Pilih Target
        local currentTarget = _G.DanauIndo_State.currentTarget
        if not currentTarget or not currentTarget.Parent or (not config.tp and (root.Position - currentTarget.Position).Magnitude > 25) then
            local t, d = nil, 9999
            local area = workspace:FindFirstChild("MiningArea") or workspace
            for _, v in ipairs(area:GetDescendants()) do 
                if v:IsA("BasePart") and v.Name == "Block" then 
                    local dist = (root.Position - v.Position).Magnitude
                    if dist < d then d = dist; t = v end 
                end 
            end
            _G.DanauIndo_State.currentTarget = t
        end

        local t = _G.DanauIndo_State.currentTarget
        if t and t.Parent then
            local d = (root.Position - t.Position).Magnitude
            
            -- [ POSITIONING ]
            if config.tp and d > 10 then
                statusLabel.Text = "MINE: Positioning..."
                root.Velocity = Vector3.new(0, 0, 0)
                root.CFrame = CFrame.new(315.985382, 21.9712238, 10.7636881, -0.368397593, -4.32496456e-08, 0.929668307, 5.59505295e-08, 1, 6.86929766e-08, -0.929668307, 7.7321765e-08, -0.368397593)
                task.wait(0.3)
                _G.DanauIndo_State.currentTarget = t
            end

            -- [ MINING CYCLE - PRECISION SYNC ]
            if (root.Position - t.Position).Magnitude <= 10 then
                statusLabel.Text = "MINE: Harvesting Block..."
                local VU = game:GetService("VirtualUser")
                
                if hum then
                    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                        if track.Name:lower():find("idle") or track.Name:lower():find("run") or track.Name:lower():find("walk") then
                            track:Stop(0.1)
                        end
                    end
                end

                -- Hadapkan karakter ke batu SEKALI SAJA agar tidak bergetar (Jitter Fix)
                local targetPos = Vector3.new(t.Position.X, root.Position.Y, t.Position.Z)
                root.CFrame = CFrame.lookAt(root.Position, targetPos)

                -- Hit Loop (8 hits per block per decompile)
                for i = 1, 8 do
                    if not t.Parent or not config.mine or not char:FindFirstChild(p.Name) then break end
                    
                    statusLabel.Text = "MINE: Hitting Block (" .. i .. "/8)"
                    
                    p:Activate()
                    VU:CaptureController()
                    VU:ClickButton1(Vector2.new(800, 400)) 
                    
                    -- [ EXTREME SPEED ]
                    task.wait(0.05) 
                end
                
                statusLabel.Text = "MINE: Block Finished"
                task.wait(0.1)
                _G.DanauIndo_State.currentTarget = nil
            end
        else
            _G.DanauIndo_State.currentTarget = nil
        end
    end
end)

-- [ AUTO DELIVERY LOGIC - MEGA TURBO ] --
task.spawn(function()
    local deliverySystem = workspace:FindFirstChild("DeliverySystem", true)
    local getJobPart = deliverySystem and deliverySystem:FindFirstChild("GetJobPart", true)
    local prompt = getJobPart and getJobPart:FindFirstChild("ProximityPrompt")
    -- Path updated according to decompiled source: ReplicatedStorage.Events.BackAttachEvent
    local backAttachRemote = ReplicatedStorage:WaitForChild("Events", 5) and ReplicatedStorage.Events:FindFirstChild("BackAttachEvent")
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    while not _G.StopDanauHub do
        task.wait(0.5) 
        if config.autoDelivery then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then continue end

            -- [ ANTI NOTIFICATION ]
            local jobGui = playerGui:FindFirstChild("youalreadyhaveajobgui")
            if jobGui then jobGui:Destroy() end 

            local beam = root:FindFirstChild("JobBeam") or char:FindFirstChild("JobBeam", true)
            local isJobActive = beam and beam:IsA("Beam") and beam.Enabled and beam.Attachment1 ~= nil

            if isJobActive then
                -- [ PROSES ANTAR ]
                local targetPos = beam.Attachment1.WorldPosition
                if targetPos then
                    statusLabel.Text = "DELIVERY: Turbo Delivering..."
                    root.Anchored = true
                    root.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.5, 0))
                    
                    local timeout = 0
                    repeat
                        task.wait(0.05)
                        beam = root:FindFirstChild("JobBeam") or char:FindFirstChild("JobBeam", true)
                        timeout = timeout + 1
                        -- Force interaction at destination
                        for _, v in ipairs(workspace:GetPartBoundsInRadius(targetPos, 15)) do
                            local p = v.Parent and v.Parent:FindFirstChildWhichIsA("ProximityPrompt")
                            if p then fireproximityprompt(p) end
                        end
                    until not (beam and beam.Enabled and beam.Attachment1) or timeout > 40 or not config.autoDelivery
                    
                    task.wait(0.2)
                    root.Anchored = false
                    statusLabel.Text = "DELIVERY: Success! Next job..."
                end
            else
                -- [ PROSES AMBIL KERJA - NO DELAY ]
                if prompt and getJobPart then
                    statusLabel.Text = "DELIVERY: Bypassing Cooldown..."
                    root.Anchored = true
                    root.CFrame = getJobPart.CFrame * CFrame.new(0, 3, 0)
                    
                    if prompt:IsA("ProximityPrompt") then prompt.HoldDuration = 0 end
                    
                    local takeTimeout = 0
                    repeat
                        fireproximityprompt(prompt)
                        task.wait(0.1)
                        beam = root:FindFirstChild("JobBeam") or char:FindFirstChild("JobBeam", true)
                        takeTimeout = takeTimeout + 1
                    until (beam and beam.Enabled and beam.Attachment1) or takeTimeout > 40 or not config.autoDelivery
                    
                    root.Anchored = false
                end
            end
        end
    end
end)

-- [ GLOBAL NOTIFICATION SLAYER ]
task.spawn(function()
    while not _G.StopDanauHub do
        task.wait(0.5)
        local jobGui = LocalPlayer.PlayerGui:FindFirstChild("youalreadyhaveajobgui")
        if jobGui then jobGui:Destroy() end
    end
end)

-- [ ANTI-AFK SYSTEM ]
task.spawn(function()
    local VU = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        if config.antiAfk then
            VU:CaptureController()
            VU:ClickButton2(Vector2.new()) -- Simulasi interaksi agar tidak kick
        end
    end)
end)

-- [ ADMIN DETECTOR LOOP ] --
task.spawn(function()
    while not _G.StopDanauHub do
        task.wait(5)
        if config.adminDetect then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local name = player.Name:lower()
                    local disp = player.DisplayName:lower()
                    if name:find("admin") or name:find("mod") or name:find("staff") or name:find("owner") or
                       disp:find("admin") or disp:find("mod") or disp:find("staff") or disp:find("owner") then
                        notify("⚠️ ADMIN DETECTED: " .. player.Name)
                        if statusLabel then statusLabel.Text = "ALERT: Admin " .. player.Name .. " in server!" end
                    end
                end
            end
        end
    end
end)

print("--- DANAU INDO ULTIMATE HUB V56 LOADED ---")
