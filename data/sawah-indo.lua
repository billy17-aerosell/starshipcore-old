--[[
    SAWAH INDO MASTER - v31.0 (SAFE TURBO MERCHANT)
    Optimization: Reduced main loop delay to 2 seconds.
    Safety: Added micro-delays (0.1s) between individual sales to prevent kicks.
    Features: Batch-10 Buying, Mass Sell All, Footprint Plant, Scrubber.
    Status: OPTIMIZED SPEED & SAFETY.
]]

print("------------------------------------------")
print("⚡ [EUGENEWU HUB] v31.0 -- [ANTI-REJOIN / WINDUI BOREAL]")
local scriptId = tick()
local isRunning = true
local connections = {}

-- [[ AGGRESSIVE FORCE CLEANUP (KILL OLD SCRIPTS) ]]
do
    if _G.SawahIndoRunning then
        _G.SawahIndoStop = true -- Kirim perintah mati ke script lama
        task.wait(0.2)
    end

    -- Sapu bersih semua ESP dan UI lama
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v.Name == "GrowNotif" then v:Destroy() end
        end
        for _, v in ipairs(Players.LocalPlayer:WaitForChild("PlayerGui"):GetChildren()) do
            if v:IsA("ScreenGui") and (v.Name:find("WindUI") or v:GetAttribute("SawahId")) then
                v:Destroy()
            end
        end
    end)

    _G.SawahIndoStop = false
    _G.SawahIndoRunning = scriptId
end

local function safeConnect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(connections, conn)
    return conn
end

local Window -- Global to this script

local function CleanupEverything()
    if not isRunning then return end
    isRunning = false
    _G.SawahIndoRunning = nil

    warn("🛑 [CLEANUP] STOPPING SCRIPT & CLEARING RESOURCES...")

    -- Disconnect all
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)

    -- Destroy ESP
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v.Name == "GrowNotif" then v:Destroy() end
        end
    end)

    -- Destroy UI
    if Window then
        local target = Window
        Window = nil
        pcall(function() target:Destroy() end)
    end

    print("✅ [CLEANUP] DISCONNECTED & CLEARED.")
end

-- Monitor for force stop signal from new execution
task.spawn(function()
    while isRunning do
        if _G.SawahIndoStop or _G.SawahIndoRunning ~= scriptId then
            CleanupEverything()
            break
        end
        task.wait(0.5)
    end
end)

print(">>> SAWAH INDO SCRIPT LOADING (ID: " .. scriptId .. ") <<<")
print("------------------------------------------")

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/orialdev/WindUI-Boreal/main/WindUI%20Boreal"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- [CONFIG]
local Config = {
    AutoPlant = false, AutoHarvest = false,    AutoSell = false,
    SelectiveSell = {
        Padi = false, Jagung = false, Tomat = false, Wortel = false,
        Cabai = false, Terong = false, Sawit = false, Durian = false
    },
    AutoBuySeeds = false, ShowGrowthESP = true,
    SelectedCrop = "Padi",
    -- [NEW FEATURES]
    AntiPetir = true, AutoChicken = false,
    ChickenFeed = true, ChickenCollect = true, ChickenSell = true,
    AutoBlockNotif = true,
    -- [AI SMART HUB]
    AISmartPlant = false, AISmartHarvest = false, AISmartSell = false,
    AIMasterAFK = false, AutoTeleport = true,
    PlantingPattern = "Single",
    isPlanting = false,
    Remotes = {}
}

-- [PLANTING PATTERNS]
local PlantingPatterns = {
    ["Single"] = {Vector3.new(0,0,0)},
    ["Grid 2x2"] = {
        Vector3.new(-2.2, 0, -2.2), Vector3.new(2.2, 0, -2.2),
        Vector3.new(-2.2, 0, 2.2),  Vector3.new(2.2, 0, 2.2)
    },
    ["Grid 3x3"] = {
        Vector3.new(-4.5, 0, -4.5), Vector3.new(0, 0, -4.5), Vector3.new(4.5, 0, -4.5),
        Vector3.new(-4.5, 0, 0),    Vector3.new(0, 0, 0),    Vector3.new(4.5, 0, 0),
        Vector3.new(-4.5, 0, 4.5), Vector3.new(0, 0, 4.5), Vector3.new(4.5, 0, 4.5)
    },
    ["Grid 4x4"] = {
        Vector3.new(-6, 0, -6), Vector3.new(-2, 0, -6), Vector3.new(2, 0, -6), Vector3.new(6, 0, -6),
        Vector3.new(-6, 0, -2), Vector3.new(-2, 0, -2), Vector3.new(2, 0, -2), Vector3.new(6, 0, -2),
        Vector3.new(-6, 0, 2),  Vector3.new(-2, 0, 2),  Vector3.new(2, 0, 2),  Vector3.new(6, 0, 2),
        Vector3.new(-6, 0, 6),  Vector3.new(-2, 0, 6),  Vector3.new(2, 0, 6),  Vector3.new(6, 0, 6)
    }
}

-- [SINKRONISASI]
-- [SINKRONISASI]
-- [SINKRONISASI & HELPERS]
local function SyncEverything()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local tut = remotes and remotes:FindFirstChild("TutorialRemotes")
    if not tut and remotes then tut = remotes:FindFirstChildWhichIsA("Folder", true) or remotes end
    if tut then
        Config.Remotes.Plant = tut:FindFirstChild("PlantCrop")
        Config.Remotes.PlantLahan = tut:FindFirstChild("PlantLahanCrop")
        Config.Remotes.Harvest = tut:FindFirstChild("HarvestCrop")
        Config.Remotes.Shop = tut:FindFirstChild("RequestShop")
        Config.Remotes.ToolShop = tut:FindFirstChild("RequestToolShop")
        Config.Remotes.Sell = tut:FindFirstChild("RequestSell")
        Config.Remotes.SellGUI = tut:FindFirstChild("SellCrop")
        Config.Remotes.Notification = tut:FindFirstChild("Notification")
    end
end

local function GetDetailedStats()
    if _G.SawahIndoRunning ~= scriptId then return nil end
    local stats = {
        Normal = {ready = 0, growing = 0, totalPct = 0, pctCount = 0},
        Sawit = {ready = 0, growing = 0, totalPct = 0, pctCount = 0, readyPos = nil}
    }
    local userId = tostring(LocalPlayer.UserId)
    local activeCrops = workspace:FindFirstChild("ActiveCrops")
    if not activeCrops then return stats end
    local currentTime = workspace:GetServerTimeNow()

    for _, crop in ipairs(activeCrops:GetChildren()) do
        -- Strict ownership check
        local ownerId = crop:GetAttribute("OwnerId")
        if tostring(ownerId) == userId or crop.Name:find(userId) then
            local plantedAt = crop:GetAttribute("PlantedAt")
            local growthTime = crop:GetAttribute("GrowthTime")

            -- IGNORE GHOST OBJECTS (Must have growth data to be a real crop)
            if not (plantedAt and growthTime) then continue end

            local isReadyAttr = crop:GetAttribute("IsReady")
            local prompt = crop:FindFirstChildWhichIsA("ProximityPrompt", true)
            local sType = (crop:GetAttribute("SeedType") or ""):lower()
            local isS = sType:find("sawit") or sType:find("durian")
            local target = isS and stats.Sawit or stats.Normal

            if isReadyAttr == true or (prompt and prompt.Enabled) then
                target.ready = target.ready + 1
                if isS and not target.readyPos then
                    target.readyPos = crop:GetModelCFrame().Position
                end
            else
                target.growing = target.growing + 1
                local elapsed = currentTime - plantedAt
                local p = math.floor(math.clamp((elapsed / growthTime) * 100, 0, 99))
                target.totalPct = target.totalPct + p
                target.pctCount = target.pctCount + 1
            end
        end
    end
    return stats
end

-- Initial initialization
SyncEverything()


-- [LOOP 1: MERCHANT ENGINE (TURBO & SAFE)]
-- [HELPER FUNCTIONS FOR MERCHANT ENGINE]
local function GetStock(name)
    local s = 0
    local items = LocalPlayer.Backpack:GetChildren()
    if LocalPlayer.Character then
        for _, v in ipairs(LocalPlayer.Character:GetChildren()) do
            if v:IsA("Tool") then table.insert(items, v) end
        end
    end
    for _, t in ipairs(items) do
        if t:IsA("Tool") and t.Name:lower():find(name:lower()) then
            local n = t.Name:match("x(%d+)")
            s = s + (tonumber(n) or 1)
        end
    end
    return s
end

local lastTP = 0
local onSawitTime = 0
local homeNormalPlot = nil
local lahanCache = {Normal = {}, Sawit = {}}
local lastCacheUpdate = 0

local function GetLahanList(targetSawit)
    if tick() - lastCacheUpdate > 60 or #lahanCache.Normal == 0 then
        lahanCache = {Normal = {}, Sawit = {}}
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                local n = v.Name:lower()
                local pn = (v.Parent and v.Parent.Name or ""):lower()

                -- [1] AVOID LABELS/SIGNS: Never teleport to UI or signs
                if n:find("label") or n:find("sign") or n:find("board") or n:find("text") or n:find("papan") then continue end

                -- [2] IDENTIFY PLOTS: Strict name filtering
                if n:find("areatanam") or n:find("lahan") or n:find("plot") or n:find("farm") or n:find("tanam") then
                    local isS = n:find("besar") or n:find("sawit") or n:find("big") or pn:find("sawit") or pn:find("big")
                    if isS then
                        table.insert(lahanCache.Sawit, v)
                    else
                        table.insert(lahanCache.Normal, v)
                    end
                end
            end
        end
        lastCacheUpdate = tick()
    end
    return targetSawit and lahanCache.Sawit or lahanCache.Normal
end

-- Initialize Cache immediately
GetLahanList()


local function IsPlotOwned(plotPart, isSawit)
    if not isSawit then return true end

    local userIdStr = tostring(LocalPlayer.UserId)
    local userName = LocalPlayer.Name:lower()
    local display = LocalPlayer.DisplayName:lower()

    -- [1] Get the Plot Model (Avoid scanning the whole workspace)
    local model = plotPart:FindFirstAncestorOfClass("Model") or plotPart.Parent or plotPart
    if model == workspace then model = plotPart end -- Safety

    -- [2] Check Attributes of the Model/Part
    local targets = {model, plotPart}
    for _, obj in ipairs(targets) do
        local own = obj:GetAttribute("OwnerId") or obj:GetAttribute("Owner") or obj:GetAttribute("UserId") or obj:GetAttribute("ClaimedBy")
        if own and (tostring(own) == userIdStr or tostring(own):lower() == userName) then return true end
    end

    -- [3] Check Labels specifically within THIS Plot Model
    for _, v in ipairs(model:GetDescendants()) do
        if v:IsA("TextLabel") or v:IsA("TextBox") then
            local t = v.Text:lower()
            if t:find(userName) or t:find(display) or t:find(userIdStr) or t:find("refin") then
                return true
            end
        end
    end

    return false
end

local function IsPlotEmpty(plotPart, isSawit)
    if not IsPlotOwned(plotPart, isSawit) then return false end

    local ac = workspace:FindFirstChild("ActiveCrops")
    if not ac then return true end

    local threshold = isSawit and 12 or 7 -- 12 is ultra precise for Sawit
    local userId = LocalPlayer.UserId

    for _, crop in ipairs(ac:GetChildren()) do
        local root = crop:FindFirstChild("Root") or (crop:IsA("BasePart") and crop) or crop:FindFirstChildWhichIsA("BasePart", true)

        if root and (root.Position - plotPart.Position).Magnitude < threshold then
            local owner = crop:GetAttribute("OwnerId") or 0
            if owner ~= 0 and owner ~= userId then continue end
            return false
        end
    end
    return true
end

local function TeleportToLand(targetSawit, specificPos)
    if tick() - lastTP < 1.5 then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if specificPos then
        print("[TP] Teleporting to Harvest Pos...")
        root.AssemblyLinearVelocity = Vector3.zero
        char:PivotTo(CFrame.new(specificPos + Vector3.new(0, 5, 0)))
        lastTP = tick()
        return
    end

    -- [STABILITY] Home Plot System for Normal Land
    if not targetSawit and homeNormalPlot and homeNormalPlot:IsDescendantOf(workspace) then
        print("[TP] Returning to Home Plot (Normal)")
        root.AssemblyLinearVelocity = Vector3.zero
        char:PivotTo(homeNormalPlot.CFrame + Vector3.new(0, 5, 0))
        lastTP = tick()
        return
    end

    local list = GetLahanList(targetSawit)
    local bestPart = nil
    local fallbackPart = nil
    local bDist = math.huge

    for _, v in ipairs(list) do
        local owned = IsPlotOwned(v, targetSawit)
        if owned then
            if not fallbackPart then fallbackPart = v end
            if IsPlotEmpty(v, targetSawit) then
                local d = (root.Position - v.Position).Magnitude
                if d < bDist then bDist = d; bestPart = v end
            end
        end
    end

    local target = bestPart or fallbackPart
    if target then
        -- Simpan sebagai Home Plot jika ini lahan biasa
        if not targetSawit then
            homeNormalPlot = target
            print("[TP] Home Plot Assigned:", target.Name)
        end

        print("[TP] Teleporting to:", target.Name, targetSawit and "(Sawit)" or "(Normal)")
        root.AssemblyLinearVelocity = Vector3.zero
        char:PivotTo(target.CFrame + Vector3.new(0, 5, 0))
        lastTP = tick()
    else
        print("[TP] No owned lahan found for:", targetSawit and "Sawit" or "Normal")
    end
end

local MasterCropList = {
    {id = "Padi", keywords = {"padi", "rice"}},
    {id = "Jagung", keywords = {"jagung", "corn"}},
    {id = "Tomat", keywords = {"tomat", "tomato"}},
    {id = "Wortel", keywords = {"wortel", "carrot"}},
    {id = "Cabai", keywords = {"cabai", "cabe", "chili"}},
    {id = "Terong", keywords = {"terong", "eggplant"}},
    {id = "Strawberry", keywords = {"strawberry", "stroberi", "strob", "strawb"}},
    {name = "Sawit", keywords = {"sawit", "palm"}},
    {name = "Durian", keywords = {"durian"}}
}

local function UpdateAIPhase()
    local currentStats = GetDetailedStats()
    if not Config.AIMasterAFK then
        Config.AIFarmingActive = false
        return nil, nil, nil, currentStats
    end

    local char = LocalPlayer.Character
    local isOnSawit = false
    local currentPlotEmpty = false

    if char and char.PrimaryPart then
        local p = RaycastParams.new()
        p.FilterType = Enum.RaycastFilterType.Include
        local filter = {}
        for _, v in ipairs(lahanCache.Normal) do table.insert(filter, v) end
        for _, v in ipairs(lahanCache.Sawit) do table.insert(filter, v) end
        if #filter == 0 then filter = {workspace} end
        p.FilterDescendantsInstances = filter

        local res = workspace:Raycast(char.PrimaryPart.Position, Vector3.new(0,-25,0), p)
        if res and res.Instance then
            local n = (res.Instance.Name .. (res.Instance.Parent and res.Instance.Parent.Name or "")):lower()
            isOnSawit = (n:find("besar") or n:find("sawit")) ~= nil
            currentPlotEmpty = IsPlotEmpty(res.Instance, isOnSawit)
        else
            -- FALLBACK: Proximity Check
            for _, v in ipairs(lahanCache.Sawit) do
                if (char.PrimaryPart.Position - v.Position).Magnitude < 40 then
                    isOnSawit = true; break
                end
            end
        end
    end

    local stocks = {Normal = 0, Sawit = 0}
    for _, crop in ipairs(MasterCropList) do
        local stock = GetStock(crop.id or crop.name)
        local isS = (crop.id or crop.name):lower():find("sawit") or (crop.id or crop.name):lower():find("durian")
        if isS then stocks.Sawit = stocks.Sawit + stock
        else stocks.Normal = stocks.Normal + stock end
    end

    local emptySawit = 0
    if lahanCache and lahanCache.Sawit then
        for _, v in ipairs(lahanCache.Sawit) do
            if IsPlotOwned(v, true) and IsPlotEmpty(v, true) then emptySawit = emptySawit + 1 end
        end
    end

    -- [SINGLE PLOT RULE] If logic sees a growing/ready Sawit, it MUST be occupied
    if currentStats and (currentStats.Sawit.growing > 0 or currentStats.Sawit.ready > 0) then
        emptySawit = 0
    end

    local emptyNormal = 0
    if lahanCache and lahanCache.Normal then
        for _, v in ipairs(lahanCache.Normal) do
            if IsPlotOwned(v, false) and IsPlotEmpty(v, false) then emptyNormal = emptyNormal + 1 end
        end
    end

    local hasNormalSeeds = (stocks.Normal > 0)
    local hasSawitWork = (stocks.Sawit > 0 and emptySawit > 0) or (currentStats and currentStats.Sawit.ready > 0)

    if not hasNormalSeeds and not hasSawitWork then
        Config.AIFarmingActive = false
        Config.AIMessage = "🛒 Shopping Phase: Stok bibit habis (Restocking...)"
    else
        Config.AIFarmingActive = true
        local landName = isOnSawit and "Lahan Sawit" or "Lahan Biasa"
        local stockCount = isOnSawit and stocks.Sawit or stocks.Normal
        Config.AIMessage = string.format("✨ Aura: %s (%d bibit) | [Plot: N:%d S:%d]", landName, stockCount, emptyNormal, emptySawit)
    end

    return isOnSawit, currentPlotEmpty, stocks, currentStats
end




-- [LOOP: MAIN ENGINE]
task.spawn(function()
    while isRunning and task.wait(0.5) do
        if _G.SawahIndoRunning ~= scriptId then break end
        local success, err = pcall(function()
            -- [1] HARVEST LOGIC
            if Config.AISmartHarvest or Config.AIMasterAFK or Config.AutoHarvest then
                local activeCrops = workspace:FindFirstChild("ActiveCrops")
                if activeCrops then
                    for _, crop in ipairs(activeCrops:GetChildren()) do
                        -- Hanya panen milik sendiri
                        if crop.Name:find(tostring(LocalPlayer.UserId)) or crop:GetAttribute("OwnerId") == LocalPlayer.UserId then
                            for _, v in ipairs(crop:GetDescendants()) do
                                if v:IsA("ProximityPrompt") and v.Enabled then
                                    local pt = (v.ObjectText .. v.ActionText):lower()
                                    -- Lebih agresif mendeteksi kata kunci panen
                                    if pt:find("panen") or pt:find("ambil") or pt:find("petik") or pt:find("harvest") or pt:find("padi") or v.ActionText == "" then
                                        v.HoldDuration = 0
                                        if fireproximityprompt then fireproximityprompt(v) end
                                    end
                                end
                            end
                        end
                    end
                end

                -- Fallback scan (untuk objek yg mungkin di luar ActiveCrops folder)
                for _, v in ipairs(workspace:GetDescendants()) do
                    if v:IsA("ProximityPrompt") and v.Enabled then
                        local pt = (v.ObjectText .. v.ActionText):lower()
                        if pt:find("panen") or pt:find("ambil") or pt:find("petik") or pt:find("harvest") then
                            v.HoldDuration = 0
                            if fireproximityprompt then fireproximityprompt(v) end
                        end
                    end
                end
            end

            -- [2] PLANT LOGIC
            if Config.AISmartPlant or Config.AIMasterAFK then
                -- Validasi AFK: Jangan menanam kalau belanja belum selesai
                if Config.AIMasterAFK and not Config.AIFarmingActive then
                    -- Sedang dalam fase belanja, jangan menanam dulu
                    return
                end

                -- [SMART MODE REFACTORED]
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not (char and hum) then return end

                -- 1. DETEKSI LAHAN (Raycast Dulu)
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Include

                -- [ROBUST DETECTION] Cari semua yang namanya AreaTanam / AreaSawit / Lahan
                local filter = {}
                for _, v in ipairs(workspace:GetDescendants()) do
                    if v:IsA("BasePart") and (v.Name:find("AreaTanam") or v.Name:find("AreaSawit") or v.Name:find("Lahan")) then
                        table.insert(filter, v)
                    end
                end
                if #filter == 0 then filter = {workspace} end
                params.FilterDescendantsInstances = filter

                local res = workspace:Raycast(char.PrimaryPart.Position, Vector3.new(0,-15,0), params)
                local isSawitLahan = false
                if res and res.Instance then
                    local n = (res.Instance.Name .. (res.Instance.Parent and res.Instance.Parent.Name or "")):lower()
                    -- [CLARIFICATION] AreaTanamBesar (atau Lahan Besar) = Lahan Sawit/Durian
                    isSawitLahan = n:find("besar") or n:find("sawit")
                end

                -- 2. PILIH ALAT YANG COCOK
                local tool = char:FindFirstChildWhichIsA("Tool")
                if tool and not (tool.Name:lower():find("bibit") or tool.Name:lower():find("seed")) then tool = nil end

                local preferred = Config.SelectedCrop and Config.SelectedCrop:lower() or ""
                local isHoldingSawit = tool and tool.Name:lower():find("sawit")
                local matches = false
                if tool then
                    if isSawitLahan then matches = isHoldingSawit
                    else matches = not isHoldingSawit end
                end

                -- Jika alat tidak cocok atau tidak ada alat, cari di backpack
                if not matches then
                    local found = nil
                    if isSawitLahan then
                        -- Cari bibit sawit
                        for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
                            if t.Name:lower():find("sawit") then hum:EquipTool(t); found = t; break end
                        end
                    else
                        -- Cari bibit biasa (Preferred dulu)
                        if preferred ~= "" and not preferred:find("sawit") then
                            for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
                                if t.Name:lower():find(preferred) and not t.Name:lower():find("sawit") then
                                    hum:EquipTool(t); found = t; break
                                end
                            end
                        end
                        -- Kalau ga ada preferred, cari sembarang bibit non-sawit
                        if not found then
                            for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
                                if (t.Name:lower():find("bibit") or t.Name:lower():find("seed")) and not t.Name:lower():find("sawit") then
                                    hum:EquipTool(t); found = t; break
                                end
                            end
                        end
                    end

                    -- Jika masih salah alat dan ga nemu pengganti, simpan alatnya (Unequip)
                    if tool and not found then
                        hum:UnequipTools()
                        tool = nil
                    else
                        tool = found
                    end
                end

                -- 3. EKSEKUSI TANAM
                if tool and res and res.Instance and not Config.isPlanting then
                    Config.isPlanting = true
                    local pattern = PlantingPatterns[Config.PlantingPattern] or PlantingPatterns["Single"]
                    if isSawitLahan then pattern = PlantingPatterns["Single"] end

                    local charCF = char.PrimaryPart.CFrame
                    local originPos = res.Position

                    for _, offset in ipairs(pattern) do
                        if _G.SawahIndoRunning ~= scriptId or not (Config.AISmartPlant or Config.AIMasterAFK) then break end
                        -- Use direct world offset for a stable grid (not rotated by character)
                        local pos = originPos + offset

                        tool:Activate()
                        local remote = isSawitLahan and (Config.Remotes.PlantLahan or Config.Remotes.Plant) or Config.Remotes.Plant
                        if remote then remote:FireServer(pos) end

                        -- Dynamic delay based on grid size for stability
                        local waitTime = (#pattern > 9) and 0.18 or 0.12
                        if #pattern > 1 then task.wait(waitTime) end
                    end
                    Config.isPlanting = false
                end
            elseif Config.AutoPlant and LocalPlayer.Character and Config.SelectedCrop then
                -- MANUAL MODE: Plant ONLY Selected
                local crop = Config.SelectedCrop:lower()
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local tool = char:FindFirstChildWhichIsA("Tool")

                if tool and not (tool.Name:lower():find(crop) and (tool.Name:lower():find("bibit") or tool.Name:lower():find("seed"))) then
                    tool = nil
                end

                if not tool and hum then
                    for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
                        if t.Name:lower():find(crop) and (t.Name:lower():find("bibit") or t.Name:lower():find("seed")) then
                            hum:EquipTool(t); tool = t; break
                        end
                    end
                end

                if tool then
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Include

                    local filter = {}
                    for _, v in ipairs(workspace:GetDescendants()) do
                        if v:IsA("BasePart") and (v.Name:find("AreaTanam") or v.Name:find("AreaSawit") or v.Name:find("Lahan")) then
                            table.insert(filter, v)
                        end
                    end
                    if #filter == 0 then filter = {workspace} end
                    params.FilterDescendantsInstances = filter

                    local res = workspace:Raycast(char.PrimaryPart.Position, Vector3.new(0,-15,0), params)
                    if res and res.Instance and not Config.isPlanting then
                        Config.isPlanting = true
                        local n = (res.Instance.Name .. (res.Instance.Parent and res.Instance.Parent.Name or "")):lower()
                        local isSawitLahan = n:find("besar") or n:find("sawit")

                        if not (isSawitLahan and not crop:find("sawit")) then
                            local pattern = PlantingPatterns[Config.PlantingPattern] or PlantingPatterns["Single"]
                            if isSawitLahan then pattern = PlantingPatterns["Single"] end

                            local charCF = char.PrimaryPart.CFrame
                            local originPos = res.Position

                            for _, offset in ipairs(pattern) do
                                if _G.SawahIndoRunning ~= scriptId or not Config.AutoPlant then break end
                                -- Use direct world offset for a stable grid (not rotated by character)
                                local pos = originPos + offset

                                if tool and tool.Parent == char then
                                    tool:Activate()
                                end
                                local remote = isSawitLahan and (Config.Remotes.PlantLahan or Config.Remotes.Plant) or Config.Remotes.Plant
                                if remote then remote:FireServer(pos) end

                                -- Dynamic delay based on grid size for stability
                                local waitTime = (#pattern > 9) and 0.18 or 0.12
                                if #pattern > 1 then task.wait(waitTime) end
                            end
                        end
                        Config.isPlanting = false
                    end
                end
            end
            -- [NEW] CHICKEN SYSTEM
            if Config.AutoChicken then
                for _, v in ipairs(workspace:GetDescendants()) do
                    if v:IsA("ProximityPrompt") and v.Enabled then
                        local text = (v.ObjectText .. v.ActionText):lower()
                        local isChicken = v.Parent and v.Parent.Name:find("Coop")

                        if isChicken then
                            if Config.ChickenFeed and text:find("beri makan") then
                                v.HoldDuration = 0
                                if fireproximityprompt then fireproximityprompt(v) end
                            elseif Config.ChickenCollect and text:find("ambil telur") then
                                v.HoldDuration = 0
                                if fireproximityprompt then fireproximityprompt(v) end
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- [ANTI-PETIR (IMPROVED - FIX STUCK SIT)]
safeConnect(RunService.Heartbeat, function()
    if not isRunning or _G.SawahIndoRunning ~= scriptId then return end
    if Config.AntiPetir then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            -- Disable states that make the character fall/knocked down
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)

            -- Force recovery if knocked down (sitting but NOT on a proper seat)
            if hum.Sit and not hum.SeatPart then
                hum.Sit = false
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end

            -- Safety: Reset PlatformStanding if it was forced by game logic
            pcall(function()
                if hum.PlatformStanding then
                    hum.PlatformStanding = false
                end
            end)
        end
    end
end)

-- [UI SHIELD & NOTIF BLOCKER (FPS FRIENDLY & SMART)]
task.spawn(function()
    while isRunning and task.wait(0.5) do
        if _G.SawahIndoRunning ~= scriptId then break end
        if Config.AutoBlockNotif then
            pcall(function()
                -- [NEW] DISCONNECT NOTIFICATION REMOTE (DIRECT)
                if Config.Remotes.Notification and getconnections then
                    for _, conn in ipairs(getconnections(Config.Remotes.Notification.OnClientEvent)) do
                        if conn.Enabled then conn:Disable() end
                    end
                end

                for _, v in ipairs(PlayerGui:GetChildren()) do
                    local name = v.Name:lower()
                    -- Whitelist: Jangan sentuh UI utama, HUD, Inventory, Shop, Quest, dll
                    if name:find("windui") or name:find("main") or name:find("hud") or name:find("inventory") or name:find("shop") or name:find("quest") or name:find("dialog") or name:find("confirm") then
                        continue
                    end

                    -- HANYA BLOKIR jika nama GUI memang ada indikasi Notifikasi/Alert
                    local isNotifGui = name:find("notif") or name:find("alert") or name:find("msg") or name:find("pesan")

                    if isNotifGui then
                        for _, child in ipairs(v:GetDescendants()) do
                            if child:IsA("TextLabel") and child.Visible and child.Text ~= "" then
                                local txt = child.Text:lower()

                                -- LIST KATA KUNCI PEMBLOKIRAN (Hanya notifikasi kecil)
                                local blockKeywords = {"maksimal", "tunggu", "level", "penuh", "tidak bisa"}
                                local shouldBlock = false
                                for _, kw in ipairs(blockKeywords) do
                                    if txt:find(kw) then shouldBlock = true; break end
                                end

                                if shouldBlock then
                                    -- JANGAN BLOKIR jika ini adalah dialog pembelian/konfirmasi penting
                                    if txt:find("beli") or txt:find("claim") or txt:find("coins") or txt:find("rp") or txt:find("yakin") or txt:find("konfirmasi") or txt:find("quest") then
                                        continue
                                    end

                                    -- Matikan ScreenGui secara total jika itu memang Gui Notif
                                    v.Enabled = false
                                    break
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)


-- [[ ACCOUNT STATUS HELPERS (PORTED FROM MOBILEUI) ]]
local function FormatRole(role)
    if not role then return "FREE" end
    return tostring(role):gsub("_", " "):upper()
end

local function ParseVIPExpiry(durationStr)
    if not durationStr or durationStr == "Lifetime" or durationStr == "lifetime" then return nil end
    local days = tonumber(durationStr:match("(%d+)%s*day"))
    local hours = tonumber(durationStr:match("(%d+)%s*hour"))
    if days then return os.time() + (days * 24 * 60 * 60)
    elseif hours then return os.time() + (hours * 60 * 60) end
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

if not _G.sessionData then
    _G.sessionData = (getgenv and getgenv().StarshipSession) or {
        Role = "VIP Mobile",
        Duration = "30 days",
        UserId = LocalPlayer.UserId,
        Username = LocalPlayer.Name,
    }
end
local sessionData = _G.sessionData

local vipExpiryTime = nil
if sessionData.Expiry and type(sessionData.Expiry) == "number" then
    vipExpiryTime = sessionData.Expiry
elseif sessionData.Expiry and type(sessionData.Expiry) == "string" and tonumber(sessionData.Expiry) then
    vipExpiryTime = tonumber(sessionData.Expiry)
else
    vipExpiryTime = ParseVIPExpiry(sessionData.Duration)
    sessionData.Expiry = vipExpiryTime -- SAVE FOR SYNC
end

local function GetVIPStatusDesc()
    local timeRemaining = "Lifetime"
    if vipExpiryTime then
        local remaining = vipExpiryTime - os.time()
        timeRemaining = FormatTimeRemaining(remaining)
    end
    return '<font size="16">Role: ' .. FormatRole(sessionData.Role) .. "\nTime Remaining: " .. timeRemaining .. "\nStatus: Active</font>"
end

-- [UI BUILDER - WINDUI BOREAL]
Window = WindUI:CreateWindow({
    Title = "STARSHIP┃dsc.gg-starshipcore",
    Icon = "rbxassetid://85930777472774",
    IconSize = 45,
    Author = "Premium Edition | StarshipCore",
    Size = UDim2.fromOffset(750, 450),
    Transparent = true,
    BackgroundImageTransparency = 0.92,
    Background = "rbxassetid://132820581372516",
    Theme = "Crimson",
    ModernLayout = true,
    BottomDragBarEnabled = true,
    User = {
		Enabled = true,
		Anonymous = true,
		Callback = function()
			WindUI:Notify({
				Title = "👤 Welcome, " .. Players.LocalPlayer.DisplayName .. "!",
				Content = "Config: " .. ConfigStatus .. " • Version " .. VERSION,
				Duration = 5,
			})
		end,
	},
    OpenButton = {
        Title = "STARSHIP ✨",
        Icon = "rbxassetid://85930777472774",
        IconSize = 22,
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
            ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 38, 38)),
        }),
    },
})

-- [CLEANUP TRIGGER: WINDOW CLOSED (WINDUI NATIVE)]
if Window then
    pcall(function()
        -- Set attribute on the core GUI for the force-cleanup search
        local coreGui = Window.Instance or (Window.Main and Window.Main.Parent)
        if coreGui then coreGui:SetAttribute("SawahId", true) end

        -- Native OnClose: Triggered when user clicks X
        Window:OnClose(function()
            if isRunning then
                print("🪟 [WindUI] Window closed by user.")
                CleanupEverything()
            end
        end)

        -- Native OnDestroy: Triggered when window is destroyed
        Window:OnDestroy(function()
            if isRunning then
                print("📦 [WindUI] Window destroyed.")
                CleanupEverything()
            end
        end)
    end)
end

-- [ANTI-AFK SYSTEM]
safeConnect(LocalPlayer.Idled, function()
    if not isRunning then return end
    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

-- === MANUAL LOGO FIX (FORCED FROM MOBILEUI) ===
task.spawn(function()
    task.wait(1.5)
    pcall(function()
        local openBtn = Window.OpenButtonMain
        if openBtn and openBtn.Button then
            for _, icon in ipairs(openBtn.Button:GetDescendants()) do
                if icon:IsA("ImageLabel") and (icon.Image:find("85930777472774") or icon.Image:find("132820581372516")) then
                    icon.AnchorPoint = Vector2.new(0.5, 0.5)
                    icon.Position = UDim2.new(0.5, 5, 0.5, 0)
                    icon.Size = UDim2.new(0, 32, 0, 32)
                    icon.ImageColor3 = Color3.new(1, 1, 1)
                    icon.ImageTransparency = 0

                    if icon.Parent:IsA("Frame") then
                        icon.Parent.Size = UDim2.new(0, 32, 0, 32)
                    end
                end
            end
        end
    end)
end)

Window:Watermark({
    Text = "STARSHIP PREMIUM┃SAWAH INDO",
    Position = "bottom-right",
    Opacity = 0.45,
    Size = 12,
})

-- === ROLE TAG (VIP MOBILE) ===
local roleColor = Color3.fromRGB(168, 85, 247)
if sessionData.Role == "OWNER" then
    roleColor = Color3.fromRGB(245, 158, 11)
elseif sessionData.Role == "VIP" or sessionData.Role == "MOBILE_VIP" or sessionData.Role == "MOBILE VIP" then
    roleColor = Color3.fromRGB(168, 85, 247)
end

local RoleTag = Window:Tag({
    Title = '<font size="11">' .. FormatRole(sessionData.Role) .. "</font>",
    Color = roleColor,
})

-- === PERFORMANCE TAGS ===
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

    RunService.Heartbeat:Connect(function() frameCount = frameCount + 1 end)

    while isRunning do
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
end)

Window:SetToggleKey(Enum.KeyCode.LeftControl)

local HomeTab = Window:Tab({ Title = "Dashboard", Icon = "house" })
local SmartTab = Window:Tab({ Title = "Aura Farming", Icon = "sparkles" })
local MarketTab = Window:Tab({ Title = "Market", Icon = "shopping-basket" })
local FarmTab = Window:Tab({ Title = "Farming", Icon = "shovel" })
local AyamTab = Window:Tab({ Title = "Chicken", Icon = "bird" })
local ProtTab = Window:Tab({ Title = "Protection", Icon = "shield-check" })
local VisTab = Window:Tab({ Title = "Visuals", Icon = "view" })
local StatsTab = Window:Tab({ Title = "Analytics", Icon = "database" })

-- [HOME TAB - MULTI SECTION]
local MultiHome = HomeTab:MultiSection({
    Title = "Welcome to Starship",
    Desc = "Overview and script status",
    Icon = "layout",
    Opened = true
})

local SecHome = MultiHome:Tab({ Title = "Information", Icon = "info", Selected = true })
SecHome:Paragraph({
    Title = "Welcome, " .. LocalPlayer.DisplayName .. "! ✨",
    Desc = "Script: Sawah Indo Master [Premium]\nVersion: v31.0.4\nStatus: Secure & Verified",
    Icon = "user"
})

SecHome:Paragraph({
    Title = "Quick Help ⌨️",
    Desc = "Press 'Left Control' to toggle UI visibility.\nUse the Analytics tab for real-time garden data.",
    Icon = "help-circle"
})

local SecAccount = MultiHome:Tab({ Title = "Account", Icon = "user-check" })

local vipParagraph = SecAccount:Paragraph({
    Title = "Subscription Status",
    Desc = GetVIPStatusDesc(),
    Icon = "star"
})

-- Update VIP timer every second
if vipExpiryTime then
    task.spawn(function()
        while isRunning and task.wait(1) do
            if _G.SawahIndoRunning ~= scriptId then break end
            local remaining = vipExpiryTime - os.time()
            if remaining <= 0 then
                pcall(function()
                    if vipParagraph then
                        vipParagraph:SetDesc('<font size="16">Role: '
                            .. FormatRole(sessionData.Role)
                            .. "\n"
                            .. "Time Remaining: Expired\n"
                            .. "Status: Inactive</font>")
                    end
                end)
                break
            else
                pcall(function()
                    if vipParagraph then
                        vipParagraph:SetDesc(GetVIPStatusDesc())
                    end
                end)
            end
        end
    end)
end

SecAccount:Paragraph({
    Title = "Profile Info",
    Desc = '<font size="16">Display Name: ' .. LocalPlayer.DisplayName .. "\n" ..
           "Username: @" .. LocalPlayer.Name .. "\n" ..
           "User ID: " .. LocalPlayer.UserId .. "\n" ..
           "Account Age: " .. LocalPlayer.AccountAge .. " days</font>",
    Icon = "user"
})

-- [AI SMART HUB - MULTI SECTION]
local MultiAI = SmartTab:MultiSection({
    Title = "Aura Systems",
    Desc = "Full automation systems",
    Icon = "sparkles",
    Opened = true
})

local SecMaster = MultiAI:Tab({ Title = "Master Bot", Icon = "zap", Selected = true })
Config.StatusParagraph = SecMaster:Paragraph({ Title = "System Status", Desc = "Waiting for Master..." })


-- Status update now handled inside the main merchant loop for better sync

SecMaster:Toggle({
    Title = "MASTER AFK MODE",
    Desc = "All-in-one automation (Tanam, Panen, Jual, Ayam, Safety)",
    Value = Config.AIMasterAFK,
    Callback = function(s)
        Config.AIMasterAFK = s
        Config.AISmartPlant = s
        Config.AISmartHarvest = s
        Config.AISmartSell = s
        Config.AutoChicken = s
        if Config.StatusParagraph then
            if s then
                Config.StatusParagraph:SetDesc("Aura Systems Initializing...")
                -- [IMMEDIATE TELEPORT TO NEAREST LAND]
                task.spawn(function()
                    task.wait(0.1) -- Small buffer for UI state
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if not root then return end

                    local bestPart = nil
                    local bDist = math.huge
                    local isS = false

                    -- Check both Normal and Sawit lahan to find the absolute nearest
                    for _, typeS in ipairs({false, true}) do
                        local list = GetLahanList(typeS)
                        for _, v in ipairs(list) do
                            if IsPlotOwned(v, typeS) then
                                local d = (root.Position - v.Position).Magnitude
                                if d < bDist then
                                    bDist = d
                                    bestPart = v
                                    isS = typeS
                                end
                            end
                        end
                    end

                    if bestPart then
                        print("[Aura] Immediate TP to nearest owned land: " .. bestPart.Name)
                        TeleportToLand(isS)
                    end
                end)
            else
                Config.StatusParagraph:SetDesc("Master AFK is currently OFF")
            end
        end
    end
})

SecMaster:Toggle({
    Title = "Auto Teleport Land",
    Desc = "Pindah lahan otomatis sesuai bibit (Normal vs Sawit)",
    Value = Config.AutoTeleport,
    Callback = function(s) Config.AutoTeleport = s end
})

local SecAISettings = MultiAI:Tab({ Title = "Specifics", Icon = "settings" })
SecAISettings:Toggle({
    Title = "Aura Plant",
    Desc = "Tanam bibit apapun secara otomatis",
    Value = Config.AISmartPlant,
    Callback = function(s) Config.AISmartPlant = s end
})
SecAISettings:Toggle({
    Title = "Aura Harvest",
    Desc = "Panen semua tanaman secara otomatis",
    Value = Config.AISmartHarvest,
    Callback = function(s) Config.AISmartHarvest = s end
})
SecAISettings:Toggle({
    Title = "Aura Sell",
    Desc = "Jual hasil panen secara cerdas",
    Value = Config.AISmartSell,
    Callback = function(s) Config.AISmartSell = s end
})

SecAISettings:Dropdown({
    Title = "Planting Pattern",
    Desc = "Pilih pola sebaran saat menanam otomatis",
    Values = {"Single", "Grid 2x2", "Grid 3x3", "Grid 4x4"},
    Default = Config.PlantingPattern,
    Callback = function(v) Config.PlantingPattern = v end
})

-- [MARKET TAB - MULTI SECTION]
local MultiMarket = MarketTab:MultiSection({
    Title = "Global Market",
    Desc = "Manage your sales and inventory",
    Icon = "shopping-cart",
    Opened = true
})

local SecScrub = MultiMarket:Tab({ Title = "Automation", Icon = "cpu", Selected = true })
SecScrub:Toggle({
    Title = "Auto Sell All",
    Desc = "Automatically sell EVERYTHING in inventory",
    Value = Config.AutoSell,
    Callback = function(s) Config.AutoSell = s end
})

SecScrub:Paragraph({ Title = "Selective Sell", Desc = "Pilih tanaman yang ingin dijual otomatis saja:" })

local selCrops = {"Padi", "Jagung", "Tomat", "Wortel", "Cabai", "Terong", "Sawit", "Durian"}
for _, name in ipairs(selCrops) do
    SecScrub:Toggle({
        Title = "Auto Sell " .. name,
        Desc = "Hanya jual " .. name .. " secara otomatis",
        Value = Config.SelectiveSell[name],
        Callback = function(s) Config.SelectiveSell[name] = s end
    })
end

local SecRemote = MultiMarket:Tab({ Title = "Remote Shop", Icon = "unfold-more" })

-- [REMOTE SHOP LOGIC - BYPASS JARAK VERSION]
local function GetMerchantPos()
    -- Cari Merchant di workspace
    local m = workspace:FindFirstChild("Merchant", true) or workspace:FindFirstChild("Toko", true)
    if m then
        if m:IsA("BasePart") then return m.Position end
        local hrp = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true)
        if hrp then return hrp.Position end
    end
    return Vector3.new(245, 4, -45) -- Koordinat default area toko jika tidak ketemu
end

local function OpenGameGUI(mode)
    local fs = getgenv().firesignal or firesignal or (oh and oh.firesignal) or (fluxus and fluxus.firesignal) or _G.firesignal
    local RequestSell = Config.Remotes.Sell
    local SellCrop = Config.Remotes.SellGUI

    if not SellCrop then return end

    task.spawn(function()
        -- [1] Ambil data stok (GET_LIST)
        if RequestSell then pcall(function() RequestSell:InvokeServer("GET_LIST") end) end

        -- [2] Trigger GUI (POLA BARU: nil, mode)
        if fs then
            print("[DEBUG] Sending Corrected Signal: nil, " .. tostring(mode))
            pcall(function() fs(SellCrop.OnClientEvent, nil, mode) end)
        end
    end)
end



SecRemote:Button({
    Title = "Open Sell GUI",
    Desc = "Force open the main sell menu",
    Callback = function() OpenGameGUI("OPEN_SELL_GUI") end
})

SecRemote:Button({
    Title = "Open Fruit GUI",
    Desc = "Open special fruit menu",
    Callback = function() OpenGameGUI("OPEN_FRUIT_GUI") end
})



local StockSawit = SecRemote:Paragraph({ Title = "🌴 Sawit Stock", Desc = "Loading..." })
local StockDurian = SecRemote:Paragraph({ Title = "🍈 Durian Stock", Desc = "Loading..." })

-- Auto Update Stock Labels (Using GET_LIST and FRUIT_LIST)
task.spawn(function()
    while isRunning and task.wait(3) do
        if _G.SawahIndoRunning ~= scriptId then break end
        SyncEverything()

        if Config.Remotes.Sell then
            -- Ambil data Buah-buahan
            local sSuccess, sData = pcall(function() return Config.Remotes.Sell:InvokeServer("GET_FRUIT_LIST", "Sawit") end)
            local dSuccess, dData = pcall(function() return Config.Remotes.Sell:InvokeServer("GET_FRUIT_LIST", "Durian") end)

            pcall(function()
                if sSuccess and sData then
                    StockSawit:SetDesc(tostring(sData.Count or sData.Amount or 0))
                else
                    StockSawit:SetDesc("0")
                end

                if dSuccess and dData then
                    StockDurian:SetDesc(tostring(dData.Count or dData.Amount or 0))
                else
                    StockDurian:SetDesc("0")
                end
            end)

            -- Optional: Sync status via GET_LIST
            pcall(function()
                Config.Remotes.Sell:InvokeServer("GET_LIST")
            end)
        end
    end
end)

local SecPrices = MultiMarket:Tab({ Title = "Price List", Icon = "tag" })
local cropsList = {
    {n = "Padi", p = 300}, {n = "Jagung", p = 450}, {n = "Tomat", p = 600},
    {n = "Wortel", p = 800}, {n = "Cabai", p = 1000}, {n = "Terong", p = 1200},
    {n = "Sawit", p = "5.000+"}, {n = "Durian", p = "10.000+"}
}
for _, c in ipairs(cropsList) do
    SecPrices:Paragraph({ Title = "💰 " .. c.n, Desc = "Harga: Rp " .. tostring(c.p) })
end

local SecBuy = MultiMarket:Tab({ Title = "Selection", Icon = "shopping-cart" })
SecBuy:Dropdown({
    Title = "Select Seed to Buy",
    Desc = "Choose which seed to automatically restock",
    Values = {"Padi", "Jagung", "Tomat", "Terong", "Strawberry", "Sawit", "Durian"},
    Default = Config.SelectedCrop,
    Callback = function(v) Config.SelectedCrop = v end
})
SecBuy:Toggle({
    Title = "Auto-Buy Seeds",
    Desc = "Keeps seed stock at 150 (Batch 10)",
    Value = Config.AutoBuy,
    Callback = function(s) Config.AutoBuy = s end
})

-- [FARMING TAB - MULTI SECTION]
local MultiFarm = FarmTab:MultiSection({
    Title = "Automation Hub",
    Desc = "Control your farm bots",
    Icon = "sprout",
    Opened = true
})

local SecSet = MultiFarm:Tab({ Title = "Selection", Icon = "box", Selected = true })
local CropDropdown = SecSet:Dropdown({
    Title = "Select Crop",
    Values = {"Padi", "Jagung", "Tomat", "Terong", "Strawberry", "Sawit", "Durian"},
    Default = Config.SelectedCrop,
    Callback = function(v) Config.SelectedCrop = v end
})

SecSet:Dropdown({
    Title = "Planting Pattern",
    Values = {"Single", "Grid 2x2", "Grid 3x3", "Grid 4x4"},
    Default = Config.PlantingPattern,
    Callback = function(v) Config.PlantingPattern = v end
})

local SecAuto = MultiFarm:Tab({ Title = "Robotics", Icon = "cpu" })
SecAuto:Toggle({
    Title = "Auto Plant (Selected)",
    Desc = "Plant ONLY your selected crop",
    Value = Config.AutoPlant,
    Callback = function(s) Config.AutoPlant = s end
})
SecAuto:Toggle({
    Title = "Auto Harvest (Selected)",
    Desc = "Harvest ONLY your selected crop",
    Value = Config.AutoHarvest,
    Callback = function(s) Config.AutoHarvest = s end
})

-- [CHICKEN TAB - MULTI SECTION]
local MultiAyam = AyamTab:MultiSection({
    Title = "Poultry Farm",
    Desc = "Automated chicken management",
    Icon = "egg",
    Opened = true
})

local SecAyam = MultiAyam:Tab({ Title = "Automation", Icon = "cpu", Selected = true })
SecAyam:Toggle({
    Title = "Full Auto Chicken",
    Desc = "Enable global chicken farm loop",
    Value = Config.AutoChicken,
    Callback = function(s) Config.AutoChicken = s end
})
SecAyam:Toggle({
    Title = "Auto Feed",
    Value = Config.ChickenFeed,
    Callback = function(s) Config.ChickenFeed = s end
})
SecAyam:Toggle({
    Title = "Auto Collect Eggs",
    Value = Config.ChickenCollect,
    Callback = function(s) Config.ChickenCollect = s end
})
SecAyam:Toggle({
    Title = "Auto Sell Eggs",
    Value = Config.ChickenSell,
    Callback = function(s) Config.ChickenSell = s end
})

-- [PROTECTION TAB - MULTI SECTION]
local MultiProt = ProtTab:MultiSection({
    Title = "Safety Systems",
    Desc = "Bypass game hazards",
    Icon = "shield",
    Opened = true
})

local SecProt = MultiProt:Tab({ Title = "Anti-Petir", Icon = "zap-off", Selected = true })
SecProt:Toggle({
    Title = "Enable Anti-Petir",
    Desc = "Immunity to lightning stun, flash, and ragdoll",
    Value = Config.AntiPetir,
    Callback = function(s) Config.AntiPetir = s end
})
SecProt:Toggle({
    Title = "Auto Block Notification",
    Desc = "Hides annoying system messages and warnings",
    Value = Config.AutoBlockNotif,
    Callback = function(s) Config.AutoBlockNotif = s end
})

-- [VISUALS TAB - MULTI SECTION]
local MultiVis = VisTab:MultiSection({
    Title = "Intelligence",
    Desc = "Enhanced vision settings",
    Icon = "scan",
    Opened = true
})

local SecESP = MultiVis:Tab({ Title = "World ESP", Icon = "map", Selected = true })
SecESP:Toggle({
    Title = "Show Growth Progress Bar",
    Desc = "Display countdown above each crop",
    Value = Config.ShowGrowthESP,
    Callback = function(s)
        Config.ShowGrowthESP = s
        if not s then
            local ac = workspace:FindFirstChild("ActiveCrops")
            if ac then
                for _, v in ipairs(ac:GetDescendants()) do
                    if v.Name == "GrowNotif" then v:Destroy() end
                end
            end
        end
    end
})

-- [DATA TAB - MULTI SECTION]
local MultiStats = StatsTab:MultiSection({
    Title = "Server Data",
    Desc = "Real-time farm information",
    Icon = "bar-chart-2",
    Opened = true
})

local SecLive = MultiStats:Tab({ Title = "Live Tracker", Icon = "activity", Selected = true })
local StatParagraph = SecLive:Paragraph({
    Title = "Harvest Progress",
    Desc = "⏳ Initializing analytics...",
    Icon = "sprout"
})

local SecInv = MultiStats:Tab({ Title = "Stock Inventory", Icon = "box" })
local InvParagraph = SecInv:Paragraph({
    Title = "Inventory Items",
    Desc = "⏳ Fetching stocks...",
    Icon = "package"
})

HomeTab:Select()

-- Stats update now handled by the global helper defined at the top


task.spawn(function()
    while isRunning and task.wait(3) do
        if _G.SawahIndoRunning ~= scriptId then break end
        local success, err = pcall(function()
            local s = GetDetailedStats()
            local inventoryStr = ""

            if s then
                local normalAvg = (s.Normal.pctCount > 0) and math.floor(s.Normal.totalPct / s.Normal.pctCount) or 0
                local sawitAvg = (s.Sawit.pctCount > 0) and math.floor(s.Sawit.totalPct / s.Sawit.pctCount) or 0

                local progressStr = string.format(
                    "🏡 **[ LAHAN BIASA ]**\n" ..
                    "🌱 Sedang Tumbuh: %d\n" ..
                    "🌾 Siap Panen: %d\n" ..
                    "📈 Progres Rata-Rata: %d%%\n\n" ..
                    " **[ LAHAN SAWIT & DURIAN ]**\n" ..
                    "🌱 Sedang Tumbuh: %d\n" ..
                    "🌾 Siap Panen: %d\n" ..
                    "📈 Progres Rata-Rata: %d%%",
                    s.Normal.growing, s.Normal.ready, normalAvg,
                    s.Sawit.growing, s.Sawit.ready, sawitAvg
                )
                StatParagraph:SetDesc(progressStr)
            end

            -- [2] Data Stok (Tab Terpisah)
            if Config.Remotes.Sell then
                local inventoryStr = ""
                local stocks = {}

                -- A. Ambil Data Dasar (Crops)
                local data = Config.Remotes.Sell:InvokeServer("GET_LIST")
                if data and data.Success and data.Items then
                    for _, item in ipairs(data.Items) do
                        stocks[item.Name] = item.Owned or item.Count or item.Amount or 0
                    end
                end

                -- B. Ambil Data Buah-Buahan (Fruits)
                local sawitData = Config.Remotes.Sell:InvokeServer("GET_FRUIT_LIST", "Sawit")
                local durianData = Config.Remotes.Sell:InvokeServer("GET_FRUIT_LIST", "Durian")

                local sCount = (sawitData and (sawitData.Count or sawitData.Amount or sawitData.Owned)) or stocks["Sawit"] or 0
                local dCount = (durianData and (durianData.Count or durianData.Amount or durianData.Owned)) or stocks["Durian"] or 0

                -- C. Sinkronisasi Manual (Scan Backpack sebagai Fallback)
                local function ScanBackpack(name)
                    local total = 0
                    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                        if tool.Name:lower():find(name:lower()) then
                            local n = tool.Name:match("x(%d+)")
                            total = total + (tonumber(n) or 1)
                        end
                    end
                    if LocalPlayer.Character then
                        for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do
                            if tool:IsA("Tool") and tool.Name:lower():find(name:lower()) then
                                local n = tool.Name:match("x(%d+)")
                                total = total + (tonumber(n) or 1)
                            end
                        end
                    end
                    return total
                end

                local cropNames = {"Padi", "Jagung", "Tomat", "Wortel", "Cabai", "Terong", "Strawberry"}
                for _, name in ipairs(cropNames) do
                    local serverVal = stocks[name] or 0
                    -- Jika server lapor 0, coba scan tas (mungkin dlm bentuk tool/item)
                    if serverVal == 0 then serverVal = ScanBackpack(name) end
                    inventoryStr = inventoryStr .. string.format("\n📦 %s: %d", name, serverVal)
                end

                -- Khusus Buah
                inventoryStr = inventoryStr .. string.format("\n🌴 Sawit: %d", sCount)
                inventoryStr = inventoryStr .. string.format("\n🍈 Durian: %d", dCount)

                InvParagraph:SetDesc(inventoryStr)
            end
        end)
        if not success then warn("[CRIT] Analytics UI Loop Error:", err) end
    end
end)

-- [ESP PROGRESS SYSTEM]
local function CreateGrowNotif(parent, text, pct)
    -- Tempel ke part "Root" sesuai struktur Dex Explorer
    local targetPart = parent:FindFirstChild("Root") or (parent:IsA("BasePart") and parent) or parent:FindFirstChildWhichIsA("BasePart", true)
    if not targetPart then return end

    -- Hapus label lama yg tidak punya struktur Bar
    local old = targetPart:FindFirstChild("GrowNotif")
    if old and not old:FindFirstChild("Main") then
        old:Destroy()
        old = nil
    end

    local bb = targetPart:FindFirstChild("GrowNotif")
    if not bb then
        bb = Instance.new("BillboardGui")
        bb.Name = "GrowNotif"
        bb.Size = UDim2.new(0, 120, 0, 60)
        bb.Adornee = targetPart
        bb.AlwaysOnTop = true
        bb.MaxDistance = 100
        bb.StudsOffset = Vector3.new(0, 4, 0)

        local container = Instance.new("Frame", bb)
        container.Name = "Main"
        container.Size = UDim2.new(1, 0, 1, 0)
        container.BackgroundTransparency = 1

        local lbl = Instance.new("TextLabel", container)
        lbl.Name = "Info"
        lbl.Size = UDim2.new(1, 0, 0.6, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextStrokeTransparency = 0.2
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13

        local barBg = Instance.new("Frame", container)
        barBg.Name = "BarBg"
        barBg.Size = UDim2.new(0.8, 0, 0.15, 0)
        barBg.Position = UDim2.new(0.1, 0, 0.65, 0)
        barBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        barBg.BackgroundTransparency = 0.5
        barBg.BorderSizePixel = 0

        local barFill = Instance.new("Frame", barBg)
        barFill.Name = "BarFill"
        barFill.Size = UDim2.new(0, 0, 1, 0)
        barFill.BackgroundColor3 = Color3.fromRGB(0, 255, 127)
        barFill.BorderSizePixel = 0

        local corner = Instance.new("UICorner", barBg)
        local corner2 = Instance.new("UICorner", barFill)

        bb.Parent = targetPart
    end

    local main = bb.Main
    main.Info.Text = text

    local cleanPct = math.clamp(pct or 0, 0, 100)
    main.BarBg.BarFill:TweenSize(UDim2.new(cleanPct/100, 0, 1, 0), "Out", "Quad", 0.5, true)
    main.BarBg.Visible = (cleanPct < 100)
end

-- [LOOP UPDATE ESP]
task.spawn(function()
    local lastDump = 0
    while isRunning and task.wait(1) do
        if _G.SawahIndoRunning ~= scriptId then break end
        pcall(function()
            local userId = tostring(LocalPlayer.UserId)
            local activeCrops = workspace:FindFirstChild("ActiveCrops")
            if not activeCrops then return end

            -- Jika Toggle MATI, hapus TOTAL semua ESP lalu skip
            if not Config.ShowGrowthESP then
                for _, v in ipairs(activeCrops:GetDescendants()) do
                    if v.Name == "GrowNotif" then v:Destroy() end
                end
                return
            end

            local currentTime = workspace:GetServerTimeNow()
            for _, crop in ipairs(activeCrops:GetChildren()) do
                if crop.Name:find(userId) or crop:GetAttribute("OwnerId") == tonumber(userId) then
                    local prompt = crop:FindFirstChildWhichIsA("ProximityPrompt", true) or crop:FindFirstChild("ProximityPrompt", true)
                    local isReady = crop:GetAttribute("IsReady")

                    if isReady == true or (prompt and prompt.Enabled) then
                        CreateGrowNotif(crop, "✅ SIAP PANEN!", 100)
                    else
                        local p, found = 10, false
                        local plantedAt = crop:GetAttribute("PlantedAt")
                        local growthTime = crop:GetAttribute("GrowthTime")

                        if plantedAt and growthTime then
                            local elapsed = currentTime - plantedAt
                            p = math.floor(math.clamp((elapsed / growthTime) * 100, 0, 99))
                            found = true
                        end

                        -- ESP Text Info
                        local seedType = crop:GetAttribute("SeedType") or Config.SelectedCrop
                        local timeRemaining = ""
                        if plantedAt and growthTime then
                            local rem = math.max(0, growthTime - (currentTime - plantedAt))
                            timeRemaining = string.format("\n⏳ %ds Lagi", math.floor(rem))
                        end

                        CreateGrowNotif(crop, seedType .. timeRemaining, p)
                    end
                end
            end

            -- Analytics logic removed from console to keep it clean
        end)
    end
end)

-- [FINAL MERCHANT ENGINE LOOP]
task.spawn(function()
    while isRunning and task.wait(2) do
        if _G.SawahIndoRunning ~= scriptId then break end
        local success, err = pcall(function()
            SyncEverything()

            -- [1] SELL LOGIC
            if Config.Remotes.Sell then
                if Config.AutoSell or Config.AISmartSell or Config.AIMasterAFK then
                    local data = Config.Remotes.Sell:InvokeServer("GET_LIST")
                    if data and data.Success and data.Items then
                        for _, item in ipairs(data.Items) do
                            if (item.Owned or 0) > 0 then
                                Config.Remotes.Sell:InvokeServer("SELL", item.Name, item.Owned); task.wait(0.05)
                            end
                        end
                    end
                    Config.Remotes.Sell:InvokeServer("SELL_ALL_FRUIT", "Sawit")
                    Config.Remotes.Sell:InvokeServer("SELL_ALL_FRUIT", "Durian")
                    Config.Remotes.Sell:InvokeServer("SELL_ALL_FRUIT", "Egg")
                end
            end

            -- [2] UPDATE AI & TELEPORT
            local isOnSawit, currentPlotEmpty, stocks, currentStats = UpdateAIPhase()
            if isOnSawit and onSawitTime == 0 then onSawitTime = tick() elseif not isOnSawit then onSawitTime = 0 end

            if Config.AIMasterAFK and Config.AIFarmingActive and Config.AutoTeleport and currentStats then
                local emptySawit = 0
                for _, v in ipairs(lahanCache.Sawit) do if IsPlotOwned(v, true) and IsPlotEmpty(v, true) then emptySawit = emptySawit + 1 end end
                local emptyNormal = 0
                for _, v in ipairs(lahanCache.Normal) do if IsPlotEmpty(v, false) then emptyNormal = emptyNormal + 1 end end

                print(string.format("[Aura] Heartbeat v31.9 | Area: %s | N-Empty: %d | S-Empty: %d | S-Grow: %d", (isOnSawit and "SAWIT" or "NORMAL"), emptyNormal, emptySawit, currentStats.Sawit.growing))

                if currentStats.Sawit.ready > 0 then
                    -- Priority 1: Harvest Ready Sawit
                    if not isOnSawit then
                        Config.AIMessage = "🚨 Sawit MATANG! Teleport Panen..."
                        TeleportToLand(true, currentStats.Sawit.readyPos)
                    end
                elseif isOnSawit then
                    -- Priority 2: Handle Sawit State (Plant -> Wait -> Exit)
                    local elapsed = tick() - onSawitTime
                    if elapsed < 5 then
                        Config.AIMessage = "⏳ Menunggu proses tanam... ("..math.floor(5-elapsed).."s)"
                    elseif currentStats.Sawit.growing > 0 or emptySawit == 0 then
                        Config.AIMessage = "✅ Sawit Terurus. Kembali ke Lahan Biasa..."
                        TeleportToLand(false)
                    else
                        Config.AIMessage = "✨ Silakan tanam bibit sawit..."
                    end
                elseif (stocks.Sawit > 0 and emptySawit > 0) then
                    -- Priority 3: Go to Sawit land only if we need to plant and aren't there
                    Config.AIMessage = "💰 Menuju Lahan Sawit (Tanam)..."
                    TeleportToLand(true)
                elseif not isOnSawit and (stocks.Normal == 0 or emptyNormal == 0) and (currentStats.Sawit.ready > 0 or (stocks.Sawit > 0 and emptySawit > 0)) then
                    -- Priority 4: Fallback to Sawit if Normal is full/done
                    Config.AIMessage = "🚀 Kembali ke Lahan Besar..."
                    TeleportToLand(true)
                end
            end

            -- [UI STATUS UPDATE - AT THE END]
            if Config.StatusParagraph then
                if Config.AIMasterAFK then Config.StatusParagraph:SetDesc(Config.AIMessage or "Processing...")
                else Config.StatusParagraph:SetDesc("Master AFK is currently OFF") end
            end

            -- [3] SHOPPING LOOP (VERBOSE BATCH MODE)
            if Config.Remotes.Shop then
                local shouldDoFullBuy = Config.AIMasterAFK and not Config.AIFarmingActive
                local shouldDoSelectiveBuy = Config.AutoBuy and not Config.AIMasterAFK

                if shouldDoFullBuy or shouldDoSelectiveBuy then
                    local shopData = Config.Remotes.Shop:InvokeServer("GET_LIST")
                    if shopData and shopData.Success and shopData.Seeds then

                        -- Generate temporary list based on mode
                        local buyList = {}
                        if shouldDoFullBuy then
                            buyList = MasterCropList
                            Config.AIMessage = "🛒 Shopping: Full Restock..."
                        else
                            -- Find only the selected crop
                            for _, crop in ipairs(MasterCropList) do
                                if (crop.id or crop.name) == Config.SelectedCrop then
                                    table.insert(buyList, crop)
                                    break
                                end
                            end
                            Config.AIMessage = "🛒 Shopping: Restocking " .. Config.SelectedCrop .. "..."
                        end

                        for _, crop in ipairs(buyList) do
                            local cropName = crop.id or crop.name
                            local currentStock = GetStock(cropName)
                            local targetStock = shouldDoFullBuy and 25 or 150 -- AFK uses 25, Selection uses 150

                            if currentStock < targetStock then
                                for _, seed in ipairs(shopData.Seeds) do
                                    local isMatch = false
                                    for _, kw in ipairs(crop.keywords) do
                                        if seed.Name:lower():find(kw:lower()) then isMatch = true; break end
                                    end

                                    if isMatch and not seed.Locked then
                                        local need = targetStock - currentStock
                                        local batchCount = math.ceil(need / 15)
                                        print(string.format("[SHOP] Restocking %s | Mode: %s | Batches: %d", seed.Name, (shouldDoFullBuy and "AFK" or "Selection"), batchCount))

                                        for i = 1, batchCount do
                                            if _G.SawahIndoRunning ~= scriptId then break end
                                            Config.Remotes.Shop:InvokeServer("BUY", seed.Name, 15)
                                            task.wait(0.8)
                                        end
                                        break
                                    end
                                end
                            end
                        end
                        if not Config.AIMasterAFK then Config.AIMessage = "✨ Selection Restock Complete." end
                    end
                end
            end

            if Config.AutoChicken and Config.ChickenSell then
                pcall(function() Config.Remotes.Sell:InvokeServer("SELL_ALL_FRUIT", "Egg") end)
            end
        end)
        if not success then warn("[CRIT] Merchant Engine Error:", err) end
    end
end)

print("✅ [v32.2.3] Turbo Merchant Core Online.")
