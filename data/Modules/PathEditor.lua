--[[
    PathEditor Module v1.0

    Provides keypoint detection and editing functionality for recordings.
    Allows users to visualize and modify path points in recordings.
]]

local PathEditor = {}

-- Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Constants
local KEYPOINT_DETECTION = {
    MIN_DIRECTION_CHANGE = 30, -- Degrees - detect turns
    MIN_HEIGHT_CHANGE = 3, -- Studs - detect jumps/falls
    MIN_TIME_INTERVAL = 2, -- Seconds - minimum time between auto keypoints
    MAX_KEYPOINTS = 100, -- Maximum keypoints to prevent performance issues
}

-- State
local EditorState = {
    isActive = false,
    currentFile = nil,
    frameData = nil,
    keypoints = {},
    selectedKeypoint = nil,
    handles = {}, -- 3D visual handles in workspace
    connections = {},
}

-- Container for visual handles
local HandleContainer = nil

--[[
    Utility Functions
]]

local function Vector3FromTable(t)
    if not t then return nil end
    return Vector3.new(t.x or 0, t.y or 0, t.z or 0)
end

local function TableFromVector3(v)
    if not v then return nil end
    return {x = v.X, y = v.Y, z = v.Z}
end

local function GetAngleBetweenVectors(v1, v2)
    if v1.Magnitude < 0.01 or v2.Magnitude < 0.01 then
        return 0
    end
    local dot = v1.Unit:Dot(v2.Unit)
    dot = math.clamp(dot, -1, 1)
    return math.deg(math.acos(dot))
end

local function LerpVector3(a, b, t)
    return a + (b - a) * t
end

--[[
    Keypoint Detection

    Automatically detects important points in a recording:
    - Direction changes (turns)
    - Height changes (jumps/landings)
    - Time intervals (regular checkpoints)
]]

function PathEditor.DetectKeypoints(frames, options)
    options = options or {}
    local minDirChange = options.minDirectionChange or KEYPOINT_DETECTION.MIN_DIRECTION_CHANGE
    local minHeightChange = options.minHeightChange or KEYPOINT_DETECTION.MIN_HEIGHT_CHANGE
    local minTimeInterval = options.minTimeInterval or KEYPOINT_DETECTION.MIN_TIME_INTERVAL
    local maxKeypoints = options.maxKeypoints or KEYPOINT_DETECTION.MAX_KEYPOINTS

    if not frames or #frames < 2 then
        return {}
    end

    local keypoints = {}

    -- Always include first frame
    table.insert(keypoints, {
        frameIndex = 1,
        time = frames[1].t or 0,
        position = Vector3FromTable(frames[1].pos) or Vector3.new(0, 0, 0),
        rotation = frames[1].rot or 0,
        type = "start",
        label = "Start",
    })

    local lastKeypointTime = frames[1].t or 0
    local lastDirection = nil
    local lastHeight = nil

    -- Get initial values
    if frames[1].pos then
        lastHeight = frames[1].pos.y
    end

    -- Scan through frames
    for i = 2, #frames - 1 do
        local frame = frames[i]
        local prevFrame = frames[i - 1]
        local nextFrame = frames[i + 1]

        if not frame.pos or not prevFrame.pos or not nextFrame.pos then
            continue
        end

        local currentPos = Vector3FromTable(frame.pos)
        local prevPos = Vector3FromTable(prevFrame.pos)
        local nextPos = Vector3FromTable(nextFrame.pos)
        local currentTime = frame.t or 0

        local shouldAddKeypoint = false
        local keypointType = "checkpoint"
        local keypointLabel = "Checkpoint"

        -- Check 1: Direction change (horizontal only)
        local dirToPrev = Vector3.new(currentPos.X - prevPos.X, 0, currentPos.Z - prevPos.Z)
        local dirToNext = Vector3.new(nextPos.X - currentPos.X, 0, nextPos.Z - currentPos.Z)

        if dirToPrev.Magnitude > 0.1 and dirToNext.Magnitude > 0.1 then
            local angle = GetAngleBetweenVectors(dirToPrev, dirToNext)
            if angle >= minDirChange then
                shouldAddKeypoint = true
                keypointType = "turn"
                keypointLabel = string.format("Turn (%.0f°)", angle)
            end
        end

        -- Check 2: Height change (jump/fall detection)
        if lastHeight then
            local heightDiff = currentPos.Y - lastHeight

            -- Detect jump apex (going from up to down)
            if frame.vel and prevFrame.vel then
                local prevVelY = prevFrame.vel.y or 0
                local currVelY = frame.vel.y or 0

                -- Jump apex: velocity changes from positive to negative
                if prevVelY > 2 and currVelY < 2 then
                    shouldAddKeypoint = true
                    keypointType = "jump_apex"
                    keypointLabel = "Jump Apex"
                end

                -- Landing: velocity was negative, now near zero (and height stable)
                if prevVelY < -5 and math.abs(currVelY) < 2 then
                    shouldAddKeypoint = true
                    keypointType = "landing"
                    keypointLabel = "Landing"
                end
            end

            -- Significant height change
            if math.abs(heightDiff) >= minHeightChange then
                if not shouldAddKeypoint then
                    shouldAddKeypoint = true
                    keypointType = heightDiff > 0 and "climb" or "drop"
                    keypointLabel = heightDiff > 0 and "Climb" or "Drop"
                end
                lastHeight = currentPos.Y
            end
        end

        -- Check 3: Time interval (ensure regular checkpoints)
        if not shouldAddKeypoint and (currentTime - lastKeypointTime) >= minTimeInterval then
            shouldAddKeypoint = true
            keypointType = "interval"
            keypointLabel = string.format("%.1fs", currentTime)
        end

        -- Add keypoint if detected
        if shouldAddKeypoint and #keypoints < maxKeypoints - 1 then
            table.insert(keypoints, {
                frameIndex = i,
                time = currentTime,
                position = currentPos,
                rotation = frame.rot or 0,
                type = keypointType,
                label = keypointLabel,
            })
            lastKeypointTime = currentTime
        end
    end

    -- Always include last frame
    local lastFrame = frames[#frames]
    table.insert(keypoints, {
        frameIndex = #frames,
        time = lastFrame.t or 0,
        position = Vector3FromTable(lastFrame.pos) or Vector3.new(0, 0, 0),
        rotation = lastFrame.rot or 0,
        type = "end",
        label = "End",
    })

    return keypoints
end

--[[
    Keypoint Editing

    Modify a keypoint's position and recalculate affected frames.
]]

function PathEditor.UpdateKeypointPosition(keypoints, frames, keypointIndex, newPosition)
    if not keypoints or not frames or not keypointIndex then
        return false, "Invalid parameters"
    end

    local keypoint = keypoints[keypointIndex]
    if not keypoint then
        return false, "Keypoint not found"
    end

    local frameIndex = keypoint.frameIndex
    if not frames[frameIndex] then
        return false, "Frame not found"
    end

    -- Calculate offset from original position
    local originalPos = keypoint.position
    local offset = newPosition - originalPos

    -- Update keypoint
    keypoint.position = newPosition

    -- Update the frame directly
    frames[frameIndex].pos = TableFromVector3(newPosition)

    -- Find previous and next keypoints
    local prevKeypoint = keypoints[keypointIndex - 1]
    local nextKeypoint = keypoints[keypointIndex + 1]

    -- Interpolate frames between previous keypoint and this one
    if prevKeypoint then
        local startFrame = prevKeypoint.frameIndex
        local endFrame = frameIndex
        local startPos = prevKeypoint.position
        local endPos = newPosition

        for i = startFrame + 1, endFrame - 1 do
            local t = (i - startFrame) / (endFrame - startFrame)
            local interpolatedPos = LerpVector3(startPos, endPos, t)

            if frames[i] and frames[i].pos then
                frames[i].pos = TableFromVector3(interpolatedPos)
            end
        end
    end

    -- Interpolate frames between this keypoint and next one
    if nextKeypoint then
        local startFrame = frameIndex
        local endFrame = nextKeypoint.frameIndex
        local startPos = newPosition
        local endPos = nextKeypoint.position

        for i = startFrame + 1, endFrame - 1 do
            local t = (i - startFrame) / (endFrame - startFrame)
            local interpolatedPos = LerpVector3(startPos, endPos, t)

            if frames[i] and frames[i].pos then
                frames[i].pos = TableFromVector3(interpolatedPos)
            end
        end
    end

    -- Recalculate velocities for affected frames
    PathEditor.RecalculateVelocities(frames, prevKeypoint and prevKeypoint.frameIndex or 1, nextKeypoint and nextKeypoint.frameIndex or #frames)

    return true, "Keypoint updated"
end

--[[
    Recalculate Velocities

    After position changes, velocities need to be recalculated for smooth playback.
]]

function PathEditor.RecalculateVelocities(frames, startIndex, endIndex)
    startIndex = math.max(1, startIndex or 1)
    endIndex = math.min(#frames, endIndex or #frames)

    for i = startIndex, endIndex - 1 do
        local frame = frames[i]
        local nextFrame = frames[i + 1]

        if frame.pos and nextFrame.pos and frame.t and nextFrame.t then
            local deltaT = nextFrame.t - frame.t
            if deltaT > 0 then
                local currentPos = Vector3FromTable(frame.pos)
                local nextPos = Vector3FromTable(nextFrame.pos)
                local velocity = (nextPos - currentPos) / deltaT

                frame.vel = {
                    x = velocity.X,
                    y = velocity.Y,
                    z = velocity.Z
                }
            end
        end
    end
end

--[[
    Visual Handles

    Create 3D visual handles at keypoint positions for editing.
]]

function PathEditor.CreateHandles(keypoints)
    PathEditor.ClearHandles()

    if not keypoints or #keypoints == 0 then
        return
    end

    -- Create container
    HandleContainer = Instance.new("Folder")
    HandleContainer.Name = "PathEditorHandles"
    HandleContainer.Parent = workspace

    local handles = {}

    for i, keypoint in ipairs(keypoints) do
        local handle = Instance.new("Part")
        handle.Name = "Keypoint_" .. i
        handle.Size = Vector3.new(2, 2, 2)
        handle.Position = keypoint.position
        handle.Anchored = true
        handle.CanCollide = false
        handle.Transparency = 0.3
        handle.Material = Enum.Material.Neon

        -- Color based on type
        if keypoint.type == "start" then
            handle.Color = Color3.fromRGB(60, 255, 160) -- Green
        elseif keypoint.type == "end" then
            handle.Color = Color3.fromRGB(255, 80, 80) -- Red
        elseif keypoint.type == "jump_apex" or keypoint.type == "landing" then
            handle.Color = Color3.fromRGB(255, 220, 60) -- Yellow
        elseif keypoint.type == "turn" then
            handle.Color = Color3.fromRGB(90, 110, 245) -- Blue
        else
            handle.Color = Color3.fromRGB(200, 200, 200) -- Gray
        end

        -- Add billboard for label
        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 100, 0, 30)
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = handle

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 0.3
        label.BackgroundColor3 = Color3.new(0, 0, 0)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.Text = string.format("#%d: %s", i, keypoint.label)
        label.Parent = billboard

        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 4)

        handle.Parent = HandleContainer
        handles[i] = handle
    end

    EditorState.handles = handles
    return handles
end

function PathEditor.ClearHandles()
    if HandleContainer then
        HandleContainer:Destroy()
        HandleContainer = nil
    end
    EditorState.handles = {}
end

function PathEditor.HighlightHandle(index, highlight)
    local handle = EditorState.handles[index]
    if handle then
        if highlight then
            handle.Size = Vector3.new(3, 3, 3)
            handle.Transparency = 0
        else
            handle.Size = Vector3.new(2, 2, 2)
            handle.Transparency = 0.3
        end
    end
end

--[[
    Path Lines

    Draw lines between keypoints to visualize the path.
]]

function PathEditor.DrawPathLines(keypoints)
    if not HandleContainer then
        return
    end

    for i = 1, #keypoints - 1 do
        local startPos = keypoints[i].position
        local endPos = keypoints[i + 1].position

        local distance = (endPos - startPos).Magnitude
        local midPoint = (startPos + endPos) / 2

        local line = Instance.new("Part")
        line.Name = "PathLine_" .. i
        line.Size = Vector3.new(0.2, 0.2, distance)
        line.CFrame = CFrame.lookAt(midPoint, endPos)
        line.Anchored = true
        line.CanCollide = false
        line.Transparency = 0.5
        line.Material = Enum.Material.Neon
        line.Color = Color3.fromRGB(90, 110, 245)
        line.Parent = HandleContainer
    end
end

--[[
    Editor Session Management
]]

function PathEditor.StartEditing(filePath, frameData)
    if EditorState.isActive then
        PathEditor.StopEditing()
    end

    EditorState.isActive = true
    EditorState.currentFile = filePath
    EditorState.frameData = frameData

    -- Detect keypoints
    EditorState.keypoints = PathEditor.DetectKeypoints(frameData)

    -- Create visual handles
    PathEditor.CreateHandles(EditorState.keypoints)
    PathEditor.DrawPathLines(EditorState.keypoints)

    return EditorState.keypoints
end

function PathEditor.StopEditing()
    PathEditor.ClearHandles()

    -- Disconnect all connections
    for _, conn in pairs(EditorState.connections) do
        if conn and conn.Disconnect then
            conn:Disconnect()
        end
    end

    EditorState = {
        isActive = false,
        currentFile = nil,
        frameData = nil,
        keypoints = {},
        selectedKeypoint = nil,
        handles = {},
        connections = {},
    }
end

function PathEditor.GetKeypoints()
    return EditorState.keypoints
end

function PathEditor.GetFrameData()
    return EditorState.frameData
end

function PathEditor.IsActive()
    return EditorState.isActive
end

function PathEditor.SelectKeypoint(index)
    -- Unhighlight previous
    if EditorState.selectedKeypoint then
        PathEditor.HighlightHandle(EditorState.selectedKeypoint, false)
    end

    EditorState.selectedKeypoint = index

    -- Highlight new
    if index then
        PathEditor.HighlightHandle(index, true)
    end

    return EditorState.keypoints[index]
end

function PathEditor.GetSelectedKeypoint()
    if EditorState.selectedKeypoint then
        return EditorState.keypoints[EditorState.selectedKeypoint], EditorState.selectedKeypoint
    end
    return nil, nil
end

--[[
    Export Modified Recording
]]

function PathEditor.ExportModifiedFrames()
    if not EditorState.frameData then
        return nil, "No frame data loaded"
    end

    return EditorState.frameData
end

function PathEditor.GetKeypointSummary()
    local summary = {
        total = #EditorState.keypoints,
        byType = {},
    }

    for _, kp in ipairs(EditorState.keypoints) do
        summary.byType[kp.type] = (summary.byType[kp.type] or 0) + 1
    end

    return summary
end

return PathEditor
