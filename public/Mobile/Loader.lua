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

-- ══════════════════════════════════════════════════════════════════
-- LOAD WINDUI
-- ══════════════════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ══════════════════════════════════════════════════════════════════
-- CREATE WINDOW
-- ══════════════════════════════════════════════════════════════════
local Window = WindUI:CreateWindow({
    Title = "Starship Mobile",
    Icon = "rocket",
    Author = "Starship Team",
    Folder = "StarshipMobile",
    Size = UDim2.fromOffset(420, 520),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 140,
    Topbar = {
        Height = 44,
        ButtonsType = "Default", -- "Default" or "Mac" style buttons (minimize, close)
    },
    OpenButton = {
        Title = "STARSHIP-CORE",
        CornerRadius = UDim.new(1, 0), -- Fully rounded
        StrokeThickness = 2,
        Enabled = true,
        Draggable = true, -- Bisa di-drag ke posisi yang diinginkan
        OnlyMobile = false, -- Muncul di PC dan Mobile
        Color = ColorSequence.new(
            Color3.fromHex("#6366f1"), -- Indigo
            Color3.fromHex("#8b5cf6")  -- Purple gradient
        ),
    },
})

-- ══════════════════════════════════════════════════════════════════
-- VARIABLES
-- ══════════════════════════════════════════════════════════════════
local Connections = {}
local Config = {
    WalkSpeed = 16,
    JumpPower = 50,
    Gravity = 196.2,
    FlySpeed = 50,
}

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
-- 🏠 DASHBOARD TAB
-- ══════════════════════════════════════════════════════════════════
local DashboardTab = Window:Tab({
    Title = "Dashboard",
    Icon = "home",
})

local hour = tonumber(os.date("%H"))
local greeting = hour >= 5 and hour < 12 and "Good Morning" or hour >= 12 and hour < 17 and "Good Afternoon" or "Good Evening"

-- Welcome
DashboardTab:Paragraph({
    Title = "👋 " .. greeting .. ", " .. LocalPlayer.DisplayName,
    Desc = "Starship Mobile v" .. VERSION,
})

DashboardTab:Divider()

-- Server Info
DashboardTab:Paragraph({ Title = "🖥️ Server Info", Desc = "" })
DashboardTab:Space()

DashboardTab:Button({
    Title = "🎮 Place ID: " .. tostring(game.PlaceId),
    Callback = function()
        if setclipboard then
            setclipboard(tostring(game.PlaceId))
            WindUI:Notify({ Title = "Copied!", Content = "Place ID copied!", Duration = 2 })
        end
    end,
})

DashboardTab:Button({
    Title = "🖥️ Job ID: " .. game.JobId:sub(1, 12) .. "...",
    Callback = function()
        if setclipboard then
            setclipboard(game.JobId)
            WindUI:Notify({ Title = "Copied!", Content = "Job ID copied!", Duration = 2 })
        end
    end,
})

DashboardTab:Button({
    Title = "👥 Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers,
    Callback = function() end,
})

DashboardTab:Divider()

-- Player Info
DashboardTab:Paragraph({ Title = "👤 Player Info", Desc = "" })
DashboardTab:Space()

DashboardTab:Button({
    Title = "👤 " .. LocalPlayer.Name,
    Desc = "User ID: " .. tostring(LocalPlayer.UserId),
    Callback = function()
        if setclipboard then
            setclipboard(tostring(LocalPlayer.UserId))
            WindUI:Notify({ Title = "Copied!", Content = "User ID copied!", Duration = 2 })
        end
    end,
})

DashboardTab:Button({
    Title = "📊 Account Age: " .. tostring(LocalPlayer.AccountAge) .. " days",
    Callback = function() end,
})

-- ══════════════════════════════════════════════════════════════════
-- 🛠️ TOOLS TAB
-- ══════════════════════════════════════════════════════════════════
local ToolsTab = Window:Tab({
    Title = "Tools",
    Icon = "wrench",
})

-- Character
ToolsTab:Paragraph({ Title = "🏃 Character", Desc = "" })
ToolsTab:Space()

ToolsTab:Slider({
    Title = "WalkSpeed",
    Desc = "Default: 16",
    Step = 1,
    Value = { Min = 0, Max = 500, Default = 16 },
    Callback = function(value)
        local v = tonumber(value) or 16
        Config.WalkSpeed = v
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = v end
    end,
})

ToolsTab:Slider({
    Title = "JumpPower",
    Desc = "Default: 50",
    Step = 1,
    Value = { Min = 0, Max = 500, Default = 50 },
    Callback = function(value)
        local v = tonumber(value) or 50
        Config.JumpPower = v
        local hum = GetHumanoid()
        if hum then hum.JumpPower = v end
    end,
})

ToolsTab:Slider({
    Title = "Gravity",
    Desc = "Default: 196.2",
    Step = 1,
    Value = { Min = 0, Max = 500, Default = 196 },
    Callback = function(value)
        local v = tonumber(value) or 196
        Config.Gravity = v
        workspace.Gravity = v
    end,
})

ToolsTab:Button({
    Title = "Reset Character",
    Callback = function()
        local hum = GetHumanoid()
        if hum then hum.Health = 0 end
    end,
})

ToolsTab:Divider()

-- Teleport
ToolsTab:Paragraph({ Title = "🚀 Teleport", Desc = "" })
ToolsTab:Space()

ToolsTab:Dropdown({
    Title = "Teleport to Player",
    Desc = "Select a player",
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
                WindUI:Notify({ Title = "Teleported!", Content = "Teleported to " .. selected, Duration = 2 })
            end
        end
    end,
})

ToolsTab:Button({
    Title = "Teleport to Mouse Position",
    Desc = "Click to teleport where you tap",
    Callback = function()
        local hrp = GetHRP()
        if hrp then
            local mouse = LocalPlayer:GetMouse()
            if mouse.Hit then
                hrp.CFrame = mouse.Hit + Vector3.new(0, 3, 0)
            end
        end
    end,
})

ToolsTab:Divider()

-- Fly
ToolsTab:Paragraph({ Title = "✈️ Fly", Desc = "" })
ToolsTab:Space()

local isFlying = false
local flyConnection = nil
local flySpeed = 50

ToolsTab:Slider({
    Title = "Fly Speed",
    Step = 1,
    Value = { Min = 10, Max = 200, Default = 50 },
    Callback = function(value)
        flySpeed = tonumber(value) or 50
    end,
})

ToolsTab:Toggle({
    Title = "Enable Fly",
    Desc = "Toggle flight mode",
    Default = false,
    Callback = function(state)
        isFlying = state
        local hrp = GetHRP()
        local hum = GetHumanoid()
        
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
                        
                        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                            vel = vel + cam.CFrame.LookVector * flySpeed
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                            vel = vel - cam.CFrame.LookVector * flySpeed
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                            vel = vel - cam.CFrame.RightVector * flySpeed
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                            vel = vel + cam.CFrame.RightVector * flySpeed
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                            vel = vel + Vector3.new(0, flySpeed, 0)
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                            vel = vel - Vector3.new(0, flySpeed, 0)
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
                local bv = hrp:FindFirstChild("StarshipFly")
                local bg = hrp:FindFirstChild("StarshipGyro")
                if bv then bv:Destroy() end
                if bg then bg:Destroy() end
            end
        end
    end,
})

-- ══════════════════════════════════════════════════════════════════
-- 📍 WARP TAB
-- ══════════════════════════════════════════════════════════════════
local WarpTab = Window:Tab({
    Title = "Warp",
    Icon = "map-pin",
})

WarpTab:Paragraph({ Title = "📍 Quick Warp", Desc = "Save and teleport to positions" })
WarpTab:Space()

local SavedPositions = {}

WarpTab:Button({
    Title = "💾 Save Current Position",
    Desc = "Save your current location",
    Callback = function()
        local hrp = GetHRP()
        if hrp then
            table.insert(SavedPositions, {
                Name = "Pos " .. #SavedPositions + 1,
                CFrame = hrp.CFrame,
            })
            WindUI:Notify({ 
                Title = "Saved!", 
                Content = "Position saved as 'Pos " .. #SavedPositions .. "'", 
                Duration = 2 
            })
        end
    end,
})

WarpTab:Button({
    Title = "🔙 Teleport to Last Saved",
    Desc = "Go to your last saved position",
    Callback = function()
        if #SavedPositions > 0 then
            local hrp = GetHRP()
            if hrp then
                hrp.CFrame = SavedPositions[#SavedPositions].CFrame
                WindUI:Notify({ Title = "Teleported!", Content = "Returned to saved position", Duration = 2 })
            end
        else
            WindUI:Notify({ Title = "Error", Content = "No saved positions!", Duration = 2 })
        end
    end,
})

WarpTab:Button({
    Title = "🗑️ Clear Saved Positions",
    Callback = function()
        SavedPositions = {}
        WindUI:Notify({ Title = "Cleared!", Content = "All positions cleared", Duration = 2 })
    end,
})

-- ══════════════════════════════════════════════════════════════════
-- 📁 LIST MAP TAB (Merged Recordings)
-- ══════════════════════════════════════════════════════════════════
local ListMapTab = Window:Tab({
    Title = "List Map",
    Icon = "folder-open",
})

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
    jointMap = {},
}

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
            while string.len(s) < 10 do s = "0" .. s end
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
        
        table.sort(sortable, function(a, b) return a.key < b.key end)
        
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
        return {"No files found"}
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

-- Convert table to CFrame
local function TblToCF(t)
    if not t then return CFrame.new() end
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
    if n < 2 then return 1 end
    
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
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Anchored = false
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        -- Remove playback constraints
        if hrp:FindFirstChild("PlaybackAtt") then hrp.PlaybackAtt:Destroy() end
        if hrp:FindFirstChild("PlaybackAO") then hrp.PlaybackAO:Destroy() end
        if hrp:FindFirstChild("PlaybackAP") then hrp.PlaybackAP:Destroy() end
    end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.AutoRotate = true
        hum.PlatformStand = false
        for _, track in pairs(hum:GetPlayingAnimationTracks()) do
            track:Stop()
        end
        if hrp then hum:MoveTo(hrp.Position) end
    end
    
    local animate = char:FindFirstChild("Animate")
    if animate then
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
    
    local filePath = MERGER_FOLDER .. "/" .. fileName
    if not isfile or not isfile(filePath) then
        WindUI:Notify({ Title = "Error", Content = "File not found!", Duration = 2 })
        return
    end
    
    WindUI:Notify({ Title = "Loading", Content = "Preparing " .. fileName .. "...", Duration = 1.5 })
    task.wait(0.1)
    
    local isResuming = (PlaybackState.currentFile == fileName and not force and PlaybackState.isPaused)
    
    -- Load file data if different file or forced
    if PlaybackState.currentFile ~= fileName or force or not PlaybackState.frameData then
        StopPlayback()
        
        local success, content = pcall(readfile, filePath)
        if not success then
            WindUI:Notify({ Title = "Error", Content = "Failed to read file!", Duration = 2 })
            return
        end
        
        local data = HttpService:JSONDecode(content)
        local framesToPlay = data.Frames or data
        
        PlaybackState.frameData = framesToPlay
        PlaybackState.currentFile = fileName
        PlaybackState.currentTime = 0
        PlaybackState.lastFrameIndex = 1
        
        -- Detect mode: Flexible (has vel/pos) or Standard (has r/j)
        PlaybackState.isFlexible = (data.Mode == "Flexible") or (framesToPlay[1] and framesToPlay[1].vel ~= nil)
        
        if #PlaybackState.frameData > 0 then
            PlaybackState.totalDuration = PlaybackState.frameData[#PlaybackState.frameData].t or 0
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
        WindUI:Notify({ Title = "Smart Start", Content = string.format("Starting from %.1fs (%.0f studs away)", bestT, minDist), Duration = 2 })
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
            
            WindUI:Notify({ Title = "Traveling", Content = string.format("Walking to path (%.0f studs)...", dist), Duration = 3 })
            
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
        if animate then
            animate.Disabled = true
            task.wait()
            animate.Disabled = false
        end
        -- Don't set AutoRotate here, handle it per-frame like PC
        hum.AutoRotate = false
        
        PlaybackState.connection = RunService.Stepped:Connect(function(_, dt)
            frameCounter = frameCounter + 1
            if not PlaybackState.isPlaying or PlaybackState.isPaused then return end
            
            -- Ensure speed is always a number
            local speed = tonumber(PlaybackState.speed) or 1
            PlaybackState.speed = speed -- Update back to ensure it's number
            
            PlaybackState.currentTime = PlaybackState.currentTime + (dt * speed)
            
            -- Check end
            if PlaybackState.currentTime >= PlaybackState.totalDuration then
                if PlaybackState.isLooping then
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
            local frameIdx = FindFrameIndex(PlaybackState.frameData, PlaybackState.currentTime, PlaybackState.lastFrameIndex)
            PlaybackState.lastFrameIndex = frameIdx
            local fA, fB = PlaybackState.frameData[frameIdx], PlaybackState.frameData[frameIdx + 1]
            
            if fA and fB then
                local deltaT = fB.t - fA.t
                local alpha = 0
                if deltaT > 0.0001 then
                    alpha = (PlaybackState.currentTime - fA.t) / deltaT
                end
                
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
                    local vel = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z):Lerp(
                        Vector3.new(fB.vel.x, fB.vel.y, fB.vel.z), alpha
                    )
                    vel = vel * speed
                    
                    -- FORCE climbing/swimming state FIRST (before any movement)
                    hum:ChangeState(isCurrentlyClimbing and Enum.HumanoidStateType.Climbing or Enum.HumanoidStateType.Swimming)
                    
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
                        local targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z):Lerp(
                            Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha
                        )
                        local targetYaw = fA.rot or 0
                        local currentPos = hrp.Position
                        -- Use stricter blend for climbing (0.5) vs swimming (0.3)
                        local positionBlend = isCurrentlyClimbing and 0.5 or 0.3
                        local smoothPos = currentPos:Lerp(targetPos, positionBlend)
                        hrp.CFrame = CFrame.new(smoothPos) * CFrame.Angles(0, math.rad(targetYaw), 0)
                    end
                    
                    -- FORCE maintain climbing/swimming state again at end
                    hum:ChangeState(isCurrentlyClimbing and Enum.HumanoidStateType.Climbing or Enum.HumanoidStateType.Swimming)
                    
                    -- Update hip height for swimming
                    if isCurrentlySwimming and fA.hh then
                        hum.HipHeight = fA.hh
                    end
                else
                    -- NORMAL MOVEMENT (Running, Jumping, Freefall, etc.) - Same as PC StarshipCore.lua
                    
                    -- 2. Apply Velocity / Position
                    if fA.vel and fB.vel then
                        local vel = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z):Lerp(
                            Vector3.new(fB.vel.x, fB.vel.y, fB.vel.z), alpha
                        )
                        vel = vel * speed
                        
                        -- Smooth velocity blending - increase blend factor at higher speeds
                        local currentVel = hrp.AssemblyLinearVelocity
                        local baseBlend = 0.6
                        local blendFactor = math.clamp(baseBlend * speed, 0.3, 0.95)
                        
                        -- Check if in air state - use position-based for smooth jump like recording
                        local isInAir = (stateName == "Jumping" or stateName == "Freefall")
                        
                        if isInAir and fA.pos and fB.pos then
                            -- Follow recorded position for smooth jump arc (like recording)
                            local targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z):Lerp(
                                Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha
                            )
                            
                            -- On time jump or high speed, snap directly to target position
                            if isTimeJump or speed >= 2 then
                                hrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
                                hrp.AssemblyLinearVelocity = vel
                            else
                                -- Smoothly move to target position
                                local currentPos = hrp.Position
                                local posBlend = math.clamp(0.5 * speed, 0.3, 0.9)
                                local newPos = currentPos:Lerp(targetPos, posBlend)
                                hrp.CFrame = CFrame.new(newPos) * hrp.CFrame.Rotation
                                
                                -- Use RECORDED velocity for animation (not calculated)
                                local recordedVelY = fA.vel and fA.vel.y or 0
                                local horizVel = (targetPos - currentPos) * 10 * speed
                                hrp.AssemblyLinearVelocity = Vector3.new(horizVel.X, recordedVelY * speed, horizVel.Z)
                            end
                        else
                            -- On ground: use velocity-based movement (snap on time jump or high speed)
                            if isTimeJump or speed >= 2 then
                                hrp.AssemblyLinearVelocity = vel
                                -- Also snap position to prevent drift at high speeds
                                if fA.pos then
                                    local targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z):Lerp(
                                        Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha
                                    )
                                    hrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
                                end
                            else
                                hrp.AssemblyLinearVelocity = currentVel:Lerp(vel, blendFactor)
                            end
                        end
                    end
                    
                    -- 3. Apply Move Direction & Rotation (SAME AS PC)
                    -- Check if climbing/swimming (special handling)
                    local isClimbingOrSwimming = (stateName == "Climbing" or stateName == "Swimming")
                    
                    if isClimbingOrSwimming then
                        -- Climbing/Swimming: Rotation already handled in position section
                        if cachedAO then cachedAO.Enabled = false end
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
                                local v = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z):Lerp(
                                    Vector3.new(fB.vel.x, fB.vel.y, fB.vel.z), alpha
                                )
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
                    if fA.jmp then
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
                            -- Use velocity Y to determine animation
                            local velY = fA.vel and fA.vel.y or 0
                            local targetState = velY > 0 and "jump" or "fall"
                            
                            -- SPAM JUMP DETECTION: Force state change if velocity is significant
                            local forceStateChange = math.abs(velY) > 8
                            
                            -- Change state if different OR if velocity is significant (spam jump detection)
                            if targetState ~= lastAirState or forceStateChange then
                                lastAirState = targetState
                                if targetState == "jump" then
                                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                                else
                                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
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
                                if fA.vel and math.abs(fA.vel.y) < 3 then
                                    hum:ChangeState(Enum.HumanoidStateType.Running)
                                end
                            elseif currentState ~= Enum.HumanoidStateType.Running then
                                hum:ChangeState(Enum.HumanoidStateType.Running)
                            end
                        elseif stateEnum == Enum.HumanoidStateType.Climbing and currentState ~= Enum.HumanoidStateType.Climbing then
                            -- Climbing: Force state and ensure proper velocity for animation
                            hum:ChangeState(Enum.HumanoidStateType.Climbing)
                        elseif stateEnum == Enum.HumanoidStateType.Climbing and currentState == Enum.HumanoidStateType.Climbing then
                            -- Maintain climbing: Apply full recorded velocity (not dampened)
                            if fA.vel then
                                local climbVel = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
                                if speed ~= 1.0 then
                                    climbVel = climbVel * speed
                                end
                                hrp.AssemblyLinearVelocity = climbVel
                            end
                        elseif stateEnum == Enum.HumanoidStateType.Swimming and currentState ~= Enum.HumanoidStateType.Swimming then
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
                    
                    -- 5. Drift Correction (Subtle) - Skip during climbing/swimming/air states
                    local isInAirState = (stateName == "Jumping" or stateName == "Freefall")
                    local skipDriftCorrection = (stateName == "Climbing" or stateName == "Swimming" or isInAirState)
                    
                    if not skipDriftCorrection and fA.pos and fB.pos then
                        local targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z):Lerp(
                            Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha
                        )
                        local dist = (hrp.Position - targetPos).Magnitude
                        
                        -- Check if actually moving (collision detection)
                        local actualVel = hrp.AssemblyLinearVelocity.Magnitude
                        local expectedVel = fA.vel and Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z).Magnitude or 0
                        local isStuck = (expectedVel > 3 and actualVel < 1) -- Expected to move but not moving
                        
                        if dist > 10 then
                            -- Snap only if VERY far off (increased threshold)
                            hrp.CFrame = CFrame.new(targetPos) * hrp.CFrame.Rotation
                        elseif dist > 2 and not isStuck then
                            -- Only nudge if not stuck (collision)
                            local dir = (targetPos - hrp.Position).Unit
                            local correction = dir * (dist * 1.5) -- Reduced correction strength
                            hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + correction
                        end
                        -- If stuck, don't force correction - let physics handle collision naturally
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
        
        -- Disable animate for non-native mode
        if animate and not PlaybackState.nativeAnim then
            animate.Disabled = true
        end
        
        PlaybackState.connection = RunService.Stepped:Connect(function(_, dt)
            if not PlaybackState.isPlaying or PlaybackState.isPaused then return end
            
            -- Ensure speed is always a number
            local speed = tonumber(PlaybackState.speed) or 1
            PlaybackState.speed = speed
            
            PlaybackState.currentTime = PlaybackState.currentTime + (dt * speed)
            
            -- Check end
            if PlaybackState.currentTime >= PlaybackState.totalDuration then
                if PlaybackState.isLooping then
                    PlaybackState.currentTime = 0
                else
                    StopPlayback()
                    WindUI:Notify({ Title = "Finished", Content = "Playback completed!", Duration = 2 })
                    return
                end
            end
            
            -- Find frames
            local frameIdx = FindFrameIndex(PlaybackState.frameData, PlaybackState.currentTime, PlaybackState.lastFrameIndex)
            PlaybackState.lastFrameIndex = frameIdx
            local fA, fB = PlaybackState.frameData[frameIdx], PlaybackState.frameData[frameIdx + 1]
            
            if fA and fB then
                local deltaT = fB.t - fA.t
                local alpha = 0
                if deltaT > 0.0001 then
                    alpha = (PlaybackState.currentTime - fA.t) / deltaT
                end
                
                -- Interpolate CFrame
                if fA.r and fB.r then
                    local targetCF = TblToCF(fA.r):Lerp(TblToCF(fB.r), alpha)
                    ap.Position = targetCF.Position
                    ao.CFrame = targetCF
                    
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
-- 🎬 NOW PLAYING TAB (Playback controls in separate tab)
-- ══════════════════════════════════════════════════════════════════
local selectedFile = nil
local selectedFileDisplay = nil -- Reference to paragraph element

-- Create Now Playing Tab
local NowPlayingTab = Window:Tab({
    Title = "▶ Playing",
    Icon = "play-circle",
})

-- Selected File Display
selectedFileDisplay = NowPlayingTab:Paragraph({
    Title = "📭 No file selected",
    Desc = "Select a file from List Map tab",
})

NowPlayingTab:Button({
    Title = "ℹ️ Show File Info",
    Desc = "View details of selected file",
    Callback = function()
        if selectedFile then
            WindUI:Notify({
                Title = "🎬 " .. selectedFile:gsub("%.json$", ""),
                Content = "File: " .. selectedFile .. "\nDuration: " .. string.format("%.1fs", PlaybackState.totalDuration),
                Duration = 4
            })
        else
            WindUI:Notify({
                Title = "No File Selected",
                Content = "Go to List Map and tap a recording file",
                Duration = 2
            })
        end
    end,
})

NowPlayingTab:Divider()

-- Playback Controls
NowPlayingTab:Paragraph({ Title = "🎮 Playback Controls", Desc = "" })
NowPlayingTab:Space()

NowPlayingTab:Button({
    Title = "▶️ Play / Resume",
    Desc = "Start or resume playback",
    Callback = function()
        if selectedFile then
            PlayRecording(selectedFile)
        else
            WindUI:Notify({ Title = "Error", Content = "Select a file first from List Map!", Duration = 2 })
            ListMapTab:Select()
        end
    end,
})

NowPlayingTab:Button({
    Title = "⏸️ Pause",
    Desc = "Pause current playback",
    Callback = function()
        if PlaybackState.isPlaying then
            PausePlayback()
        else
            WindUI:Notify({ Title = "Info", Content = "Nothing is playing", Duration = 1 })
        end
    end,
})

NowPlayingTab:Button({
    Title = "⏹️ Stop",
    Desc = "Stop and reset playback",
    Callback = function()
        StopPlayback()
        local char = GetCharacter()
        local animate = char and char:FindFirstChild("Animate")
        if animate then animate.Disabled = false end
        WindUI:Notify({ Title = "Stopped", Content = "Playback stopped", Duration = 1 })
    end,
})

NowPlayingTab:Divider()

-- Playback Settings
NowPlayingTab:Paragraph({ Title = "⚙️ Settings", Desc = "" })
NowPlayingTab:Space()

NowPlayingTab:Slider({
    Title = "Speed",
    Desc = "Playback speed multiplier",
    Step = 0.1,
    Value = { Min = 0.1, Max = 3, Default = 1 },
    Callback = function(value)
        PlaybackState.speed = tonumber(value) or 1
    end,
})

NowPlayingTab:Toggle({
    Title = "Loop",
    Desc = "Loop when finished",
    Default = false,
    Callback = function(state)
        PlaybackState.isLooping = state
    end,
})

NowPlayingTab:Toggle({
    Title = "Strict Retarget",
    Desc = "Strict body positioning",
    Default = false,
    Callback = function(state)
        PlaybackState.strictRetarget = state
    end,
})

NowPlayingTab:Toggle({
    Title = "Native Animation",
    Desc = "Keep default animations",
    Default = false,
    Callback = function(state)
        PlaybackState.nativeAnim = state
    end,
})

NowPlayingTab:Divider()

-- Back Button
NowPlayingTab:Button({
    Title = "📁 Back to File List",
    Desc = "Return to List Map",
    Callback = function()
        ListMapTab:Select()
    end,
})

-- Function to select file and switch to Now Playing tab
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
    
    -- Switch to Now Playing tab
    NowPlayingTab:Select()
    
    WindUI:Notify({ 
        Title = "File Selected", 
        Content = displayName, 
        Duration = 1.5 
    })
end

-- ══════════════════════════════════════════════════════════════════
-- FILE LIST UI (Static - created on load)
-- ══════════════════════════════════════════════════════════════════

-- Get files immediately
local initialFiles = RefreshFileList()

-- Info
ListMapTab:Button({
    Title = "📂 Folder: " .. MERGER_FOLDER,
    Desc = "Status: " .. folderStatus .. " | Files: " .. #initialFiles,
    Callback = function()
        local files = RefreshFileList()
        WindUI:Notify({ 
            Title = "Folder Info", 
            Content = "Path: " .. MERGER_FOLDER .. "\nStatus: " .. folderStatus .. "\nFiles: " .. #files, 
            Duration = 4 
        })
    end,
})

-- Recording Files - Direct to Tab (no collapsible section)
ListMapTab:Divider()

ListMapTab:Paragraph({
    Title = "📁 Recording Files (" .. #initialFiles .. ")",
    Desc = "Tap a file to open playback controls",
})

ListMapTab:Space()

if #initialFiles == 0 then
    ListMapTab:Button({
        Title = "📭 No recordings found",
        Desc = "Create merged recordings on PC first",
        Callback = function()
            WindUI:Notify({ 
                Title = "How to Use", 
                Content = "1. Record di PC dengan Starship\n2. Merge recordings di tab Merger\n3. File akan muncul di: " .. MERGER_FOLDER, 
                Duration = 6 
            })
        end,
    })
else
    -- Create button for each file directly on Tab (always visible)
    for i, file in ipairs(initialFiles) do
        local displayName = file:gsub("%.json$", "")
        ListMapTab:Button({
            Title = "🎬 " .. displayName,
            Desc = "Tap to select",
            Callback = function()
                SelectFile(file)
            end,
        })
    end
end

-- ══════════════════════════════════════════════════════════════════
-- 🎉 FUN TAB
-- ══════════════════════════════════════════════════════════════════
local FunTab = Window:Tab({
    Title = "Fun",
    Icon = "smile",
})

-- Visual Effects
FunTab:Paragraph({ Title = "✨ Visual Effects", Desc = "" })
FunTab:Space()

FunTab:Toggle({
    Title = "Noclip",
    Desc = "Walk through walls",
    Default = false,
    Callback = function(state)
        local conn
        if state then
            conn = RunService.Stepped:Connect(function()
                local char = GetCharacter()
                if char then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
            table.insert(Connections, conn)
        else
            for i, c in pairs(Connections) do
                if c.Connected then c:Disconnect() end
            end
        end
    end,
})

FunTab:Toggle({
    Title = "Infinite Jump",
    Desc = "Jump in mid-air",
    Default = false,
    Callback = function(state)
        local hum = GetHumanoid()
        if hum then
            if state then
                UserInputService.JumpRequest:Connect(function()
                    if GetHumanoid() then
                        GetHumanoid():ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end)
            end
        end
    end,
})

FunTab:Divider()

-- Fun Actions
FunTab:Paragraph({ Title = "🎮 Fun Actions", Desc = "" })
FunTab:Space()

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
                if bv then bv:Destroy() end
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

-- ══════════════════════════════════════════════════════════════════
-- ⚙️ SETTINGS TAB
-- ══════════════════════════════════════════════════════════════════
local SettingsTab = Window:Tab({
    Title = "Settings",
    Icon = "settings",
})

-- UI Settings
SettingsTab:Paragraph({ Title = "🎨 UI Settings", Desc = "" })
SettingsTab:Space()

SettingsTab:Toggle({
    Title = "Notifications",
    Desc = "Show notifications",
    Default = true,
    Callback = function(state)
        -- Toggle notifications
    end,
})

SettingsTab:Divider()

-- About
SettingsTab:Paragraph({ Title = "ℹ️ About", Desc = "" })
SettingsTab:Space()

SettingsTab:Button({
    Title = "📱 Version: " .. VERSION,
    Callback = function() end,
})

SettingsTab:Button({
    Title = "🚀 Starship Mobile",
    Desc = "Powered by WindUI",
    Callback = function() end,
})

SettingsTab:Button({
    Title = "💬 Join Discord",
    Desc = "Get updates and support",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/starship")
            WindUI:Notify({ Title = "Copied!", Content = "Discord link copied!", Duration = 3 })
        end
    end,
})

-- ══════════════════════════════════════════════════════════════════
-- SELECT DEFAULT TAB & WELCOME
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Select()

task.delay(1, function()
    WindUI:Notify({
        Title = "Welcome!",
        Content = "Starship Mobile loaded successfully!",
        Duration = 4,
    })
end)

print("[Starship Mobile] Loaded! v" .. VERSION)

-- ══════════════════════════════════════════════════════════════════
-- CUSTOM FLOATING TOGGLE BUTTON (Fallback if OpenButton doesn't work)
-- ══════════════════════════════════════════════════════════════════
local function CreateFloatingButton()
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Check if already exists
    if playerGui:FindFirstChild("StarshipToggleBtn") then
        playerGui.StarshipToggleBtn:Destroy()
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "StarshipToggleBtn"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = playerGui
    
    -- Container frame for dragging
    local Container = Instance.new("Frame")
    Container.Name = "Container"
    Container.Size = UDim2.new(0, 50, 0, 50)
    Container.Position = UDim2.new(0, 10, 0.5, -25)
    Container.BackgroundTransparency = 1
    Container.Active = true
    Container.Draggable = true -- Enable native dragging
    Container.Parent = ScreenGui
    
    local Button = Instance.new("TextButton")
    Button.Name = "ToggleBtn"
    Button.Size = UDim2.new(1, 0, 1, 0)
    Button.Position = UDim2.new(0, 0, 0, 0)
    Button.BackgroundColor3 = Color3.fromHex("#6366f1")
    Button.Text = "🚀"
    Button.TextSize = 24
    Button.Font = Enum.Font.GothamBold
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.AutoButtonColor = true
    Button.Parent = Container
    
    -- Rounded corners
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(1, 0)
    Corner.Parent = Button
    
    -- Stroke
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromHex("#8b5cf6")
    Stroke.Thickness = 2
    Stroke.Parent = Button
    
    -- Shadow effect
    local Shadow = Instance.new("ImageLabel")
    Shadow.Name = "Shadow"
    Shadow.Size = UDim2.new(1, 20, 1, 20)
    Shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    Shadow.BackgroundTransparency = 1
    Shadow.Image = "rbxassetid://5554236805"
    Shadow.ImageColor3 = Color3.new(0, 0, 0)
    Shadow.ImageTransparency = 0.6
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    Shadow.ZIndex = -1
    Shadow.Parent = Button
    
    -- Track drag state
    local isDragging = false
    local dragStartPos = nil
    local dragThreshold = 5 -- pixels to consider as drag vs click
    
    Container.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
            dragStartPos = input.Position
        end
    end)
    
    Container.InputChanged:Connect(function(input)
        if dragStartPos and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = (input.Position - dragStartPos).Magnitude
            if delta > dragThreshold then
                isDragging = true
            end
        end
    end)
    
    -- Toggle window on click (not drag)
    Button.MouseButton1Click:Connect(function()
        if not isDragging then
            Window:Toggle()
            -- Visual feedback
            local tween = TweenService:Create(Button, TweenInfo.new(0.1), {Size = UDim2.new(0.9, 0, 0.9, 0)})
            tween:Play()
            tween.Completed:Connect(function()
                TweenService:Create(Button, TweenInfo.new(0.1), {Size = UDim2.new(1, 0, 1, 0)}):Play()
            end)
        end
        dragStartPos = nil
    end)
    
    return ScreenGui
end

-- Create the floating button
CreateFloatingButton()
print("[Starship Mobile] Floating toggle button created! 🚀")
