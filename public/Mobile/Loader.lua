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
local function GetAccountInfo()
    local name = LocalPlayer.DisplayName
    local user = LocalPlayer.Name
    local age = LocalPlayer.AccountAge
    local date = os.date("%d %B %Y")
    local info = ""
    info = info .. "[O] Display Name: " .. name .. string.char(10)
    info = info .. "[O] Username: " .. user .. string.char(10)
    info = info .. "[O] Role: Premium Member" .. string.char(10)
    info = info .. "[O] Token: **********" .. string.char(10)
    info = info .. "[O] Member Since: " .. date .. string.char(10)
    info = info .. "[O] Account Age: " .. age .. " Days" .. string.char(10)
    info = info .. "[O] Status: Active"
    return info
end
local function GetServerInfo()
    local ping = "0"
    pcall(function() ping = tostring(math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())) end)
    local fps = tostring(math.floor(workspace:GetRealPhysicsFPS()))
    local players = #game:GetService("Players"):GetPlayers()
    local maxPlayers = game:GetService("Players").MaxPlayers
    local executor = (identifyexecutor and identifyexecutor()) or "Unknown"
    local info = ""
    info = info .. "[O] Executor: " .. executor .. string.char(10)
    info = info .. "[O] Place ID: " .. game.PlaceId .. string.char(10)
    info = info .. "[O] Job ID: " .. string.sub(game.JobId, 1, 15) .. "..." .. string.char(10)
    info = info .. "[O] Players: " .. players .. "/" .. maxPlayers .. string.char(10)
    info = info .. "[O] Ping: " .. ping .. " ms" .. string.char(10)
    info = info .. "[O] FPS: " .. fps
    return info
end

local function UpdateTool(char, toolName)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local currentTool = char:FindFirstChildOfClass("Tool")

    -- If frame has tool data
    if toolName then
        -- If already equipped, do nothing
        if currentTool and currentTool.Name == toolName then return end

        -- Unequip wrong tool
        if currentTool then hum:UnequipTools() end

        -- Equip correct tool from Backpack
        local backpack = LocalPlayer.Backpack
        local newTool = backpack:FindFirstChild(toolName)
        if newTool then
            hum:EquipTool(newTool)
        end
    else
        -- If frame has NO tool data, but we are holding one, unequip
        if currentTool then hum:UnequipTools() end
    end
end

local AccountCard = DashboardTab:Paragraph({
    Title = "-| Information Account |-",
    Desc = GetAccountInfo(),
    Height = 150
})
DashboardTab:Space()
local ServerCard = DashboardTab:Paragraph({
    Title = "-| Information Server |-",
    Desc = GetServerInfo(),
    Height = 140
})
DashboardTab:Space()
DashboardTab:Button({
    Title = "[O] Refresh Info",
    Callback = function()
        AccountCard:SetDesc(GetAccountInfo())
        ServerCard:SetDesc(GetServerInfo())
        WindUI:Notify({ Title = "Refreshed", Content = "Dashboard updated", Duration = 1 })
    end,
})



-- ══════════════════════════════════════════════════════════════════
-- 🛠️ TOOLS TAB
-- ══════════════════════════════════════════════════════════════════
local ToolsTab = Window:Tab({
    Title = "Tools",
    Icon = "wrench",
})

-- 🏃 MOVEMENT
ToolsTab:Section({ Title = "🏃 Movement Settings", TextSize = 20 })

ToolsTab:Slider({
    Title = "WalkSpeed",
    Desc = "Running speed (Default: 16)",
    Step = 1,
    Value = { Min = 16, Max = 200, Default = 16 },
    Callback = function(v)
        Config.WalkSpeed = v
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = v end
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
        if hum then hum.JumpPower = v end
    end,
})

ToolsTab:Slider({
    Title = "Gravity",
    Desc = "World gravity (Default: 196)",
    Step = 1,
    Value = { Min = 0, Max = 196, Default = 196 },
    Callback = function(v)
        workspace.Gravity = v
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
            if p ~= LocalPlayer then table.insert(list, p.Name) end
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
            if hrp then hrp.CFrame = mouse.Hit + Vector3.new(0, 3, 0) end
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
    Default = false,
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

                        if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel = vel + look end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel = vel - look end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel = vel - right end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel = vel + right end
                        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0, 1, 0) end
                        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0, 1, 0) end

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
    Callback = function(v) flySpeed = v end,
})


ToolsTab:Divider()

ToolsTab:Button({
    Title = "💀 Reset Character",
    Callback = function()
        local hum = GetHumanoid()
        if hum then hum.Health = 0 end
    end,
})

local ListMapTab = Window:Tab({
    Title = "Auto Walk",
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
    isRespawnOnEnd = false,
    isSpinning = false,
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
                if PlaybackState.isRespawnOnEnd then
                    local savedFile = PlaybackState.currentFile
                    local savedLoop = PlaybackState.isLooping
                    StopPlayback()
                    WindUI:Notify({ Title = "Respawn", Content = "Respawning in 5 seconds...", Duration = 5 })
                    task.wait(5)
                    local hum = GetHumanoid()
                    if hum then hum.Health = 0 end
                    if savedLoop then
                        task.spawn(function()
                            LocalPlayer.CharacterAdded:Wait()
                            WindUI:Notify({ Title = "Loop", Content = "Restarting playback in 5 seconds...", Duration = 5 })
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
            local frameIdx = FindFrameIndex(PlaybackState.frameData, PlaybackState.currentTime, PlaybackState.lastFrameIndex)
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
                if PlaybackState.isRespawnOnEnd then
                    local savedFile = PlaybackState.currentFile
                    local savedLoop = PlaybackState.isLooping
                    StopPlayback()
                    WindUI:Notify({ Title = "Respawn", Content = "Respawning in 5 seconds...", Duration = 5 })
                    task.wait(5)
                    local hum = GetHumanoid()
                    if hum then hum.Health = 0 end
                    if savedLoop then
                        task.spawn(function()
                            LocalPlayer.CharacterAdded:Wait()
                            WindUI:Notify({ Title = "Loop", Content = "Restarting playback in 5 seconds...", Duration = 5 })
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
            local frameIdx = FindFrameIndex(PlaybackState.frameData, PlaybackState.currentTime, PlaybackState.lastFrameIndex)
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
        Duration = 1.5
    })
end

-- ══════════════════════════════════════════════════════════════════
-- 1. FILE LIST (Top)
-- ══════════════════════════════════════════════════════════════════

-- Get files immediately
local initialFiles = RefreshFileList()

-- Info
ListMapTab:Paragraph({
    Title = "Auto Walk: " .. #initialFiles .. " Files"
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
    -- Prepare dropdown values (remove extension for display)
    local dropdownValues = {}
    for _, file in ipairs(initialFiles) do
        table.insert(dropdownValues, (file:gsub("%.json$", "")))
    end

    ListMapTab:Dropdown({
        Title = "Select File",
        Desc = "Choose a recording to load",
        Values = dropdownValues,
        Callback = function(selected)
            SelectFile(selected .. ".json")
        end,
    })
end

-- ══════════════════════════════════════════════════════════════════
-- 2. PLAYBACK CONTROLS (Bottom)
-- ══════════════════════════════════════════════════════════════════

-- Mini Player Logic (Raw GUI)
local MiniPlayerGui = nil
local function ToggleMiniPlayer(state)
    if state then
        if MiniPlayerGui then return end

        -- Try CoreGui, fallback to PlayerGui
        local parent
        local success, cGui = pcall(function() return game:GetService("CoreGui") end)
        if success and cGui then
            parent = cGui
        else
            parent = LocalPlayer:WaitForChild("PlayerGui")
        end

        local screen = Instance.new("ScreenGui")
        screen.Name = "StarshipMini"
        screen.Parent = parent
        screen.ResetOnSpawn = false

        -- Main Container
        local frame = Instance.new("Frame")
        frame.Name = "Main"
        frame.Size = UDim2.fromOffset(220, 120) -- Reduced height
        frame.Position = UDim2.new(0.5, -110, 0.1, 0)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Draggable = true
        frame.Parent = screen

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(99, 102, 241) -- Indigo accent
        stroke.Thickness = 2
        stroke.Parent = frame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = frame

        local mainLayout = Instance.new("UIListLayout")
        mainLayout.FillDirection = Enum.FillDirection.Vertical
        mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
        mainLayout.Padding = UDim.new(0, 8)
        mainLayout.Parent = frame

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 10)
        padding.PaddingBottom = UDim.new(0, 10)
        padding.PaddingLeft = UDim.new(0, 10)
        padding.PaddingRight = UDim.new(0, 10)
        padding.Parent = frame

        -- Helper to create rounded button
        local function createBtn(text, color, parent, callback)
            local btn = Instance.new("TextButton")
            btn.BackgroundColor3 = color
            btn.Text = text
            btn.TextColor3 = Color3.new(1,1,1)
            btn.TextSize = 14
            btn.Font = Enum.Font.GothamBold
            btn.AutoButtonColor = true
            btn.Parent = parent

            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 6)
            c.Parent = btn

            btn.MouseButton1Click:Connect(callback)
            return btn
        end

        -- 1. Playback Controls Row
        local row1 = Instance.new("Frame")
        row1.Size = UDim2.new(1, 0, 0, 30)
        row1.BackgroundTransparency = 1
        row1.LayoutOrder = 1
        row1.Parent = frame

        local layout1 = Instance.new("UIListLayout")
        layout1.FillDirection = Enum.FillDirection.Horizontal
        layout1.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout1.Padding = UDim.new(0, 5)
        layout1.Parent = row1

        local btnPlay = createBtn("▶ Play", Color3.fromRGB(34, 197, 94), row1, function()
            if selectedFile then PlayRecording(selectedFile) else WindUI:Notify({Title="No File", Content="Select file first", Duration=1}) end
        end)
        btnPlay.Size = UDim2.new(0.45, 0, 1, 0)

        local btnStop = createBtn("⏹ Stop", Color3.fromRGB(239, 68, 68), row1, function()
            StopPlayback()
        end)
        btnStop.Size = UDim2.new(0.45, 0, 1, 0)

        -- 2. Speed Control Row
        local row2 = Instance.new("Frame")
        row2.Size = UDim2.new(1, 0, 0, 25)
        row2.BackgroundTransparency = 1
        row2.LayoutOrder = 2
        row2.Parent = frame

        local layout2 = Instance.new("UIListLayout")
        layout2.FillDirection = Enum.FillDirection.Horizontal
        layout2.VerticalAlignment = Enum.VerticalAlignment.Center
        layout2.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout2.Padding = UDim.new(0, 5)
        layout2.Parent = row2

        local speedLabel = Instance.new("TextLabel")
        speedLabel.Text = "Spd: " .. (PlaybackState.speed or 1) .. "x"
        speedLabel.TextColor3 = Color3.new(0.9,0.9,0.9)
        speedLabel.BackgroundTransparency = 1
        speedLabel.Size = UDim2.new(0.4, 0, 1, 0)
        speedLabel.Font = Enum.Font.Gotham
        speedLabel.TextSize = 12
        speedLabel.Parent = row2

        local function updateSpeed(val)
            PlaybackState.speed = val
            speedLabel.Text = "Spd: " .. val .. "x"
        end

        local btnSlow = createBtn("-", Color3.fromRGB(60,60,60), row2, function()
            local s = tonumber(PlaybackState.speed) or 1
            s = math.max(0.1, s - 0.1)
            updateSpeed(math.floor(s*10)/10)
        end)
        btnSlow.Size = UDim2.new(0.2, 0, 1, 0)

        local btnFast = createBtn("+", Color3.fromRGB(60,60,60), row2, function()
            local s = tonumber(PlaybackState.speed) or 1
            s = math.min(5, s + 0.1)
            updateSpeed(math.floor(s*10)/10)
        end)
        btnFast.Size = UDim2.new(0.2, 0, 1, 0)

        -- 3. Toggles Row (Loop, Strict, Native)
        local row3 = Instance.new("Frame")
        row3.Size = UDim2.new(1, 0, 0, 25)
        row3.BackgroundTransparency = 1
        row3.LayoutOrder = 3
        row3.Parent = frame

        local layout3 = Instance.new("UIListLayout")
        layout3.FillDirection = Enum.FillDirection.Horizontal
        layout3.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout3.Padding = UDim.new(0, 5)
        layout3.Parent = row3

        local function createToggle(text, prop)
            local isActive = PlaybackState[prop]
            local color = isActive and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(60,60,60)
            local tBtn = createBtn(text, color, row3, function() end)
            tBtn.Size = UDim2.new(0.3, 0, 1, 0)
            tBtn.TextSize = 10

            tBtn.MouseButton1Click:Connect(function()
                PlaybackState[prop] = not PlaybackState[prop]
                tBtn.BackgroundColor3 = PlaybackState[prop] and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(60,60,60)
            end)
            return tBtn
        end

        createToggle("Loop", "isLooping")
        createToggle("Respawn", "isRespawnOnEnd")
        createToggle("Spin", "isSpinning")

        MiniPlayerGui = screen
        WindUI:Notify({ Title = "Mini Player", Content = "Controls Active", Duration = 1.5 })
    else
        if MiniPlayerGui then
            MiniPlayerGui:Destroy()
            MiniPlayerGui = nil
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

ListMapTab:Space()
local PlaybackSection = ListMapTab:Section({
    Title = "🎮 Playback Controls",
    Opened = true,
})

PlaybackSection:Toggle({
    Title = "Show Mini Player",
    Desc = "Floating play/stop widget",
    Default = false,
    Callback = ToggleMiniPlayer
})





-- ══════════════════════════════════════════════════════════════════
-- 🎉 FUN TAB
-- ══════════════════════════════════════════════════════════════════
local FunTab = Window:Tab({
    Title = "Fun",
    Icon = "smile",
})

-- Visual Effects
FunTab:Section({ Title = "✨ Visual Effects", TextSize = 20 })

--[[
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
]]

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

-- Handle Window Close
Window:OnClose(function()
    StopPlayback()
    if MiniPlayerGui then
        MiniPlayerGui:Destroy()
        MiniPlayerGui = nil
    end
end)

task.delay(1, function()
    WindUI:Notify({
        Title = "Welcome!",
        Content = "Starship Mobile loaded successfully!",
        Duration = 4,
    })
end)
