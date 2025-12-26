--[[
    PathEditorUI Module v1.0

    Provides the user interface for the Path Editor.
    Allows users to view, select, and edit keypoints in recordings.
]]

local PathEditorUI = {}

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- Theme Colors (will be overwritten by main script)
local Theme = {
    Main = Color3.fromRGB(10, 10, 14),
    Side = Color3.fromRGB(15, 15, 20),
    Accent = Color3.fromRGB(90, 110, 245),
    Text = Color3.fromRGB(240, 240, 250),
    TextDim = Color3.fromRGB(140, 140, 160),
    Item = Color3.fromRGB(20, 20, 28),
    Red = Color3.fromRGB(255, 80, 80),
    Yellow = Color3.fromRGB(255, 220, 60),
    Green = Color3.fromRGB(60, 255, 160),
}

-- State
local UIState = {
    isOpen = false,
    screenGui = nil,
    mainFrame = nil,
    keypointList = nil,
    detailPanel = nil,
    currentKeypoints = {},
    selectedIndex = nil,
    onSaveCallback = nil,
    onCloseCallback = nil,
    PathEditor = nil, -- Reference to PathEditor module
}

-- UI References
local Refs = {}

--[[
    Utility Functions
]]

local function CreateCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

local function CreateStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Theme.Accent
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.5
    stroke.Parent = parent
    return stroke
end

local function FormatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%d:%05.2f", mins, secs)
end

local function FormatPosition(pos)
    if not pos then return "N/A" end
    return string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
end

--[[
    UI Creation
]]

function PathEditorUI.SetTheme(themeTable)
    Theme = themeTable
end

function PathEditorUI.SetPathEditor(pathEditorModule)
    UIState.PathEditor = pathEditorModule
end

function PathEditorUI.Create(parent)
    if UIState.screenGui then
        UIState.screenGui:Destroy()
    end

    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PathEditorUI"
    screenGui.DisplayOrder = 10010
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.Parent = parent
    UIState.screenGui = screenGui

    -- Backdrop (semi-transparent overlay)
    local backdrop = Instance.new("Frame")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    backdrop.BackgroundTransparency = 0.5
    backdrop.ZIndex = 1
    backdrop.Parent = screenGui
    Refs.Backdrop = backdrop

    backdrop.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Close on backdrop click
            PathEditorUI.Close()
        end
    end)

    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 500, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
    mainFrame.BackgroundColor3 = Theme.Main
    mainFrame.ZIndex = 2
    mainFrame.Parent = screenGui
    CreateCorner(mainFrame, 12)
    CreateStroke(mainFrame, Theme.Accent, 2, 0.3)
    UIState.mainFrame = mainFrame
    Refs.MainFrame = mainFrame

    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 45)
    header.BackgroundColor3 = Theme.Side
    header.ZIndex = 3
    header.Parent = mainFrame
    CreateCorner(header, 12)

    -- Fix corner rounding at bottom
    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 15)
    headerFix.Position = UDim2.new(0, 0, 1, -15)
    headerFix.BackgroundColor3 = Theme.Side
    headerFix.BorderSizePixel = 0
    headerFix.ZIndex = 3
    headerFix.Parent = header

    local titleIcon = Instance.new("TextLabel")
    titleIcon.Text = "✏️"
    titleIcon.Size = UDim2.new(0, 40, 1, 0)
    titleIcon.Position = UDim2.new(0, 10, 0, 0)
    titleIcon.BackgroundTransparency = 1
    titleIcon.TextColor3 = Theme.Accent
    titleIcon.TextSize = 20
    titleIcon.Font = Enum.Font.GothamBold
    titleIcon.ZIndex = 4
    titleIcon.Parent = header

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Text = "Path Editor"
    titleLabel.Size = UDim2.new(1, -120, 1, 0)
    titleLabel.Position = UDim2.new(0, 50, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Theme.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.ZIndex = 4
    titleLabel.Parent = header
    Refs.TitleLabel = titleLabel

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Text = "✕"
    closeBtn.Size = UDim2.new(0, 35, 0, 35)
    closeBtn.Position = UDim2.new(1, -40, 0, 5)
    closeBtn.BackgroundColor3 = Theme.Item
    closeBtn.TextColor3 = Theme.Red
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 4
    closeBtn.Parent = header
    CreateCorner(closeBtn, 6)

    closeBtn.MouseButton1Click:Connect(function()
        PathEditorUI.Close()
    end)

    -- Content Area (split into list and detail)
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -20, 1, -100)
    content.Position = UDim2.new(0, 10, 0, 50)
    content.BackgroundTransparency = 1
    content.ZIndex = 3
    content.Parent = mainFrame
    Refs.Content = content

    -- Keypoint List (left side)
    local listFrame = Instance.new("Frame")
    listFrame.Name = "ListFrame"
    listFrame.Size = UDim2.new(0.5, -5, 1, 0)
    listFrame.BackgroundColor3 = Theme.Item
    listFrame.ZIndex = 4
    listFrame.Parent = content
    CreateCorner(listFrame, 8)
    Refs.ListFrame = listFrame

    local listHeader = Instance.new("TextLabel")
    listHeader.Text = "📍 Keypoints"
    listHeader.Size = UDim2.new(1, 0, 0, 30)
    listHeader.BackgroundTransparency = 1
    listHeader.TextColor3 = Theme.TextDim
    listHeader.TextSize = 12
    listHeader.Font = Enum.Font.GothamBold
    listHeader.ZIndex = 5
    listHeader.Parent = listFrame

    local listScroll = Instance.new("ScrollingFrame")
    listScroll.Name = "ListScroll"
    listScroll.Size = UDim2.new(1, -10, 1, -35)
    listScroll.Position = UDim2.new(0, 5, 0, 30)
    listScroll.BackgroundTransparency = 1
    listScroll.ScrollBarThickness = 4
    listScroll.ScrollBarImageColor3 = Theme.Accent
    listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    listScroll.ZIndex = 5
    listScroll.Parent = listFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = listScroll

    UIState.keypointList = listScroll
    Refs.ListScroll = listScroll

    -- Detail Panel (right side)
    local detailFrame = Instance.new("Frame")
    detailFrame.Name = "DetailFrame"
    detailFrame.Size = UDim2.new(0.5, -5, 1, 0)
    detailFrame.Position = UDim2.new(0.5, 5, 0, 0)
    detailFrame.BackgroundColor3 = Theme.Item
    detailFrame.ZIndex = 4
    detailFrame.Parent = content
    CreateCorner(detailFrame, 8)
    Refs.DetailFrame = detailFrame

    local detailHeader = Instance.new("TextLabel")
    detailHeader.Text = "🔧 Edit Keypoint"
    detailHeader.Size = UDim2.new(1, 0, 0, 30)
    detailHeader.BackgroundTransparency = 1
    detailHeader.TextColor3 = Theme.TextDim
    detailHeader.TextSize = 12
    detailHeader.Font = Enum.Font.GothamBold
    detailHeader.ZIndex = 5
    detailHeader.Parent = detailFrame

    local detailContent = Instance.new("Frame")
    detailContent.Name = "DetailContent"
    detailContent.Size = UDim2.new(1, -10, 1, -35)
    detailContent.Position = UDim2.new(0, 5, 0, 30)
    detailContent.BackgroundTransparency = 1
    detailContent.ZIndex = 5
    detailContent.Parent = detailFrame
    UIState.detailPanel = detailContent
    Refs.DetailContent = detailContent

    -- Create detail panel fields
    PathEditorUI.CreateDetailFields(detailContent)

    -- Footer with buttons
    local footer = Instance.new("Frame")
    footer.Name = "Footer"
    footer.Size = UDim2.new(1, -20, 0, 40)
    footer.Position = UDim2.new(0, 10, 1, -50)
    footer.BackgroundTransparency = 1
    footer.ZIndex = 3
    footer.Parent = mainFrame
    Refs.Footer = footer

    local saveBtn = Instance.new("TextButton")
    saveBtn.Name = "SaveBtn"
    saveBtn.Text = "💾 Save Changes"
    saveBtn.Size = UDim2.new(0.48, 0, 1, 0)
    saveBtn.BackgroundColor3 = Theme.Green
    saveBtn.TextColor3 = Color3.new(1, 1, 1)
    saveBtn.TextSize = 14
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.ZIndex = 4
    saveBtn.Parent = footer
    CreateCorner(saveBtn, 8)
    Refs.SaveBtn = saveBtn

    saveBtn.MouseButton1Click:Connect(function()
        PathEditorUI.Save()
    end)

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Name = "CancelBtn"
    cancelBtn.Text = "↩ Cancel"
    cancelBtn.Size = UDim2.new(0.48, 0, 1, 0)
    cancelBtn.Position = UDim2.new(0.52, 0, 0, 0)
    cancelBtn.BackgroundColor3 = Theme.Item
    cancelBtn.TextColor3 = Theme.Text
    cancelBtn.TextSize = 14
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.ZIndex = 4
    cancelBtn.Parent = footer
    CreateCorner(cancelBtn, 8)
    CreateStroke(cancelBtn, Theme.TextDim, 1, 0.5)
    Refs.CancelBtn = cancelBtn

    cancelBtn.MouseButton1Click:Connect(function()
        PathEditorUI.Close()
    end)

    -- Hide initially
    screenGui.Enabled = false

    return screenGui
end

function PathEditorUI.CreateDetailFields(parent)
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = parent

    -- Keypoint Info Label
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Text = "Select a keypoint to edit"
    infoLabel.Size = UDim2.new(1, 0, 0, 25)
    infoLabel.BackgroundTransparency = 1
    infoLabel.TextColor3 = Theme.TextDim
    infoLabel.TextSize = 11
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextWrapped = true
    infoLabel.ZIndex = 6
    infoLabel.Parent = parent
    Refs.InfoLabel = infoLabel

    -- Type Badge
    local typeBadge = Instance.new("TextLabel")
    typeBadge.Name = "TypeBadge"
    typeBadge.Text = ""
    typeBadge.Size = UDim2.new(1, 0, 0, 25)
    typeBadge.BackgroundColor3 = Theme.Accent
    typeBadge.BackgroundTransparency = 0.7
    typeBadge.TextColor3 = Theme.Text
    typeBadge.TextSize = 11
    typeBadge.Font = Enum.Font.GothamBold
    typeBadge.ZIndex = 6
    typeBadge.Visible = false
    typeBadge.Parent = parent
    CreateCorner(typeBadge, 4)
    Refs.TypeBadge = typeBadge

    -- Position X
    local function CreateAxisInput(axis, color)
        local row = Instance.new("Frame")
        row.Name = axis .. "Row"
        row.Size = UDim2.new(1, 0, 0, 30)
        row.BackgroundTransparency = 1
        row.ZIndex = 6
        row.Parent = parent

        local label = Instance.new("TextLabel")
        label.Text = axis .. ":"
        label.Size = UDim2.new(0, 25, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = color
        label.TextSize = 14
        label.Font = Enum.Font.GothamBold
        label.ZIndex = 7
        label.Parent = row

        local input = Instance.new("TextBox")
        input.Name = axis .. "Input"
        input.Text = "0"
        input.Size = UDim2.new(1, -70, 1, 0)
        input.Position = UDim2.new(0, 30, 0, 0)
        input.BackgroundColor3 = Theme.Main
        input.TextColor3 = Theme.Text
        input.TextSize = 12
        input.Font = Enum.Font.Gotham
        input.ClearTextOnFocus = false
        input.ZIndex = 7
        input.Parent = row
        CreateCorner(input, 4)

        local adjustBtn = Instance.new("TextButton")
        adjustBtn.Name = axis .. "Adjust"
        adjustBtn.Text = "±1"
        adjustBtn.Size = UDim2.new(0, 35, 1, 0)
        adjustBtn.Position = UDim2.new(1, -35, 0, 0)
        adjustBtn.BackgroundColor3 = Theme.Accent
        adjustBtn.TextColor3 = Theme.Text
        adjustBtn.TextSize = 10
        adjustBtn.Font = Enum.Font.GothamBold
        adjustBtn.ZIndex = 7
        adjustBtn.Parent = row
        CreateCorner(adjustBtn, 4)

        Refs[axis .. "Input"] = input
        Refs[axis .. "Adjust"] = adjustBtn

        return row, input, adjustBtn
    end

    CreateAxisInput("X", Color3.fromRGB(255, 100, 100))
    CreateAxisInput("Y", Color3.fromRGB(100, 255, 100))
    CreateAxisInput("Z", Color3.fromRGB(100, 100, 255))

    -- Time display
    local timeRow = Instance.new("Frame")
    timeRow.Name = "TimeRow"
    timeRow.Size = UDim2.new(1, 0, 0, 25)
    timeRow.BackgroundTransparency = 1
    timeRow.ZIndex = 6
    timeRow.Parent = parent

    local timeLabel = Instance.new("TextLabel")
    timeLabel.Name = "TimeLabel"
    timeLabel.Text = "⏱ Time: --:--"
    timeLabel.Size = UDim2.new(1, 0, 1, 0)
    timeLabel.BackgroundTransparency = 1
    timeLabel.TextColor3 = Theme.TextDim
    timeLabel.TextSize = 11
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextXAlignment = Enum.TextXAlignment.Left
    timeLabel.ZIndex = 7
    timeLabel.Parent = timeRow
    Refs.TimeLabel = timeLabel

    -- Apply button
    local applyBtn = Instance.new("TextButton")
    applyBtn.Name = "ApplyBtn"
    applyBtn.Text = "Apply Position"
    applyBtn.Size = UDim2.new(1, 0, 0, 30)
    applyBtn.BackgroundColor3 = Theme.Accent
    applyBtn.TextColor3 = Theme.Text
    applyBtn.TextSize = 12
    applyBtn.Font = Enum.Font.GothamBold
    applyBtn.ZIndex = 6
    applyBtn.Visible = false
    applyBtn.Parent = parent
    CreateCorner(applyBtn, 6)
    Refs.ApplyBtn = applyBtn

    applyBtn.MouseButton1Click:Connect(function()
        PathEditorUI.ApplyPositionChange()
    end)

    -- Navigation buttons
    local navRow = Instance.new("Frame")
    navRow.Name = "NavRow"
    navRow.Size = UDim2.new(1, 0, 0, 30)
    navRow.BackgroundTransparency = 1
    navRow.ZIndex = 6
    navRow.Parent = parent

    local prevBtn = Instance.new("TextButton")
    prevBtn.Name = "PrevBtn"
    prevBtn.Text = "◀ Prev"
    prevBtn.Size = UDim2.new(0.48, 0, 1, 0)
    prevBtn.BackgroundColor3 = Theme.Item
    prevBtn.TextColor3 = Theme.Text
    prevBtn.TextSize = 11
    prevBtn.Font = Enum.Font.GothamBold
    prevBtn.ZIndex = 7
    prevBtn.Parent = navRow
    CreateCorner(prevBtn, 4)
    CreateStroke(prevBtn, Theme.TextDim, 1, 0.7)
    Refs.PrevBtn = prevBtn

    prevBtn.MouseButton1Click:Connect(function()
        PathEditorUI.SelectPrevious()
    end)

    local nextBtn = Instance.new("TextButton")
    nextBtn.Name = "NextBtn"
    nextBtn.Text = "Next ▶"
    nextBtn.Size = UDim2.new(0.48, 0, 1, 0)
    nextBtn.Position = UDim2.new(0.52, 0, 0, 0)
    nextBtn.BackgroundColor3 = Theme.Item
    nextBtn.TextColor3 = Theme.Text
    nextBtn.TextSize = 11
    nextBtn.Font = Enum.Font.GothamBold
    nextBtn.ZIndex = 7
    nextBtn.Parent = navRow
    CreateCorner(nextBtn, 4)
    CreateStroke(nextBtn, Theme.TextDim, 1, 0.7)
    Refs.NextBtn = nextBtn

    nextBtn.MouseButton1Click:Connect(function()
        PathEditorUI.SelectNext()
    end)
end

--[[
    Keypoint List Management
]]

function PathEditorUI.PopulateKeypointList(keypoints)
    -- Clear existing
    for _, child in pairs(UIState.keypointList:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    UIState.currentKeypoints = keypoints

    for i, kp in ipairs(keypoints) do
        local item = Instance.new("Frame")
        item.Name = "Keypoint_" .. i
        item.Size = UDim2.new(1, -5, 0, 35)
        item.BackgroundColor3 = Theme.Main
        item.ZIndex = 6
        item.Parent = UIState.keypointList
        CreateCorner(item, 6)

        local itemStroke = CreateStroke(item, Theme.TextDim, 1, 0.8)

        -- Icon based on type
        local icon = "📍"
        local iconColor = Theme.TextDim
        if kp.type == "start" then
            icon = "🚀"
            iconColor = Theme.Green
        elseif kp.type == "end" then
            icon = "🏁"
            iconColor = Theme.Red
        elseif kp.type == "jump_apex" then
            icon = "⬆️"
            iconColor = Theme.Yellow
        elseif kp.type == "landing" then
            icon = "⬇️"
            iconColor = Theme.Yellow
        elseif kp.type == "turn" then
            icon = "↪️"
            iconColor = Theme.Accent
        end

        local iconLabel = Instance.new("TextLabel")
        iconLabel.Text = icon
        iconLabel.Size = UDim2.new(0, 25, 1, 0)
        iconLabel.BackgroundTransparency = 1
        iconLabel.TextSize = 14
        iconLabel.ZIndex = 7
        iconLabel.Parent = item

        local indexLabel = Instance.new("TextLabel")
        indexLabel.Text = "#" .. i
        indexLabel.Size = UDim2.new(0, 25, 0, 15)
        indexLabel.Position = UDim2.new(0, 25, 0, 2)
        indexLabel.BackgroundTransparency = 1
        indexLabel.TextColor3 = iconColor
        indexLabel.TextSize = 10
        indexLabel.Font = Enum.Font.GothamBold
        indexLabel.TextXAlignment = Enum.TextXAlignment.Left
        indexLabel.ZIndex = 7
        indexLabel.Parent = item

        local labelText = Instance.new("TextLabel")
        labelText.Text = kp.label
        labelText.Size = UDim2.new(1, -55, 0, 15)
        labelText.Position = UDim2.new(0, 50, 0, 2)
        labelText.BackgroundTransparency = 1
        labelText.TextColor3 = Theme.Text
        labelText.TextSize = 11
        labelText.Font = Enum.Font.GothamBold
        labelText.TextXAlignment = Enum.TextXAlignment.Left
        labelText.TextTruncate = Enum.TextTruncate.AtEnd
        labelText.ZIndex = 7
        labelText.Parent = item

        local timeText = Instance.new("TextLabel")
        timeText.Text = FormatTime(kp.time)
        timeText.Size = UDim2.new(1, -30, 0, 12)
        timeText.Position = UDim2.new(0, 25, 0, 18)
        timeText.BackgroundTransparency = 1
        timeText.TextColor3 = Theme.TextDim
        timeText.TextSize = 9
        timeText.Font = Enum.Font.Gotham
        timeText.TextXAlignment = Enum.TextXAlignment.Left
        timeText.ZIndex = 7
        timeText.Parent = item

        -- Click handler
        local clickBtn = Instance.new("TextButton")
        clickBtn.Text = ""
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.ZIndex = 8
        clickBtn.Parent = item

        clickBtn.MouseButton1Click:Connect(function()
            PathEditorUI.SelectKeypoint(i)
        end)

        -- Store reference for highlighting
        item:SetAttribute("Index", i)
    end
end

function PathEditorUI.SelectKeypoint(index)
    -- Unhighlight previous
    if UIState.selectedIndex then
        for _, child in pairs(UIState.keypointList:GetChildren()) do
            if child:IsA("Frame") and child:GetAttribute("Index") == UIState.selectedIndex then
                child.BackgroundColor3 = Theme.Main
                local stroke = child:FindFirstChildOfClass("UIStroke")
                if stroke then
                    stroke.Color = Theme.TextDim
                    stroke.Transparency = 0.8
                end
            end
        end
    end

    UIState.selectedIndex = index

    -- Highlight new
    for _, child in pairs(UIState.keypointList:GetChildren()) do
        if child:IsA("Frame") and child:GetAttribute("Index") == index then
            child.BackgroundColor3 = Theme.Accent
            local stroke = child:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Color = Theme.Accent
                stroke.Transparency = 0
            end
        end
    end

    -- Update detail panel
    local keypoint = UIState.currentKeypoints[index]
    if keypoint then
        PathEditorUI.UpdateDetailPanel(keypoint, index)

        -- Notify PathEditor
        if UIState.PathEditor and UIState.PathEditor.SelectKeypoint then
            UIState.PathEditor.SelectKeypoint(index)
        end
    end
end

function PathEditorUI.UpdateDetailPanel(keypoint, index)
    if not keypoint then
        Refs.InfoLabel.Text = "Select a keypoint to edit"
        Refs.TypeBadge.Visible = false
        Refs.ApplyBtn.Visible = false
        return
    end

    Refs.InfoLabel.Text = string.format("Keypoint #%d of %d", index, #UIState.currentKeypoints)

    -- Type badge
    Refs.TypeBadge.Text = "  " .. keypoint.type:upper() .. ": " .. keypoint.label .. "  "
    Refs.TypeBadge.Visible = true

    -- Color badge based on type
    if keypoint.type == "start" then
        Refs.TypeBadge.BackgroundColor3 = Theme.Green
    elseif keypoint.type == "end" then
        Refs.TypeBadge.BackgroundColor3 = Theme.Red
    elseif keypoint.type == "jump_apex" or keypoint.type == "landing" then
        Refs.TypeBadge.BackgroundColor3 = Theme.Yellow
    else
        Refs.TypeBadge.BackgroundColor3 = Theme.Accent
    end

    -- Position inputs
    if keypoint.position then
        Refs.XInput.Text = string.format("%.2f", keypoint.position.X)
        Refs.YInput.Text = string.format("%.2f", keypoint.position.Y)
        Refs.ZInput.Text = string.format("%.2f", keypoint.position.Z)
    end

    -- Time
    Refs.TimeLabel.Text = "⏱ Time: " .. FormatTime(keypoint.time)

    -- Show apply button
    Refs.ApplyBtn.Visible = true
end

function PathEditorUI.SelectPrevious()
    if not UIState.selectedIndex then
        PathEditorUI.SelectKeypoint(1)
    elseif UIState.selectedIndex > 1 then
        PathEditorUI.SelectKeypoint(UIState.selectedIndex - 1)
    end
end

function PathEditorUI.SelectNext()
    if not UIState.selectedIndex then
        PathEditorUI.SelectKeypoint(1)
    elseif UIState.selectedIndex < #UIState.currentKeypoints then
        PathEditorUI.SelectKeypoint(UIState.selectedIndex + 1)
    end
end

function PathEditorUI.ApplyPositionChange()
    if not UIState.selectedIndex or not UIState.PathEditor then
        return
    end

    local x = tonumber(Refs.XInput.Text) or 0
    local y = tonumber(Refs.YInput.Text) or 0
    local z = tonumber(Refs.ZInput.Text) or 0
    local newPosition = Vector3.new(x, y, z)

    local success, message = UIState.PathEditor.UpdateKeypointPosition(
        UIState.currentKeypoints,
        UIState.PathEditor.GetFrameData(),
        UIState.selectedIndex,
        newPosition
    )

    if success then
        -- Update local keypoint data
        UIState.currentKeypoints[UIState.selectedIndex].position = newPosition

        -- Refresh 3D handles
        UIState.PathEditor.ClearHandles()
        UIState.PathEditor.CreateHandles(UIState.currentKeypoints)
        UIState.PathEditor.DrawPathLines(UIState.currentKeypoints)

        -- Flash button green
        Refs.ApplyBtn.BackgroundColor3 = Theme.Green
        Refs.ApplyBtn.Text = "✓ Applied!"
        task.delay(1, function()
            if Refs.ApplyBtn then
                Refs.ApplyBtn.BackgroundColor3 = Theme.Accent
                Refs.ApplyBtn.Text = "Apply Position"
            end
        end)
    else
        -- Flash button red
        Refs.ApplyBtn.BackgroundColor3 = Theme.Red
        Refs.ApplyBtn.Text = "✗ Failed"
        task.delay(1, function()
            if Refs.ApplyBtn then
                Refs.ApplyBtn.BackgroundColor3 = Theme.Accent
                Refs.ApplyBtn.Text = "Apply Position"
            end
        end)
    end
end

--[[
    Open/Close/Save
]]

function PathEditorUI.Open(fileName, frameData, onSave, onClose)
    if not UIState.screenGui then
        return false, "UI not created"
    end

    UIState.onSaveCallback = onSave
    UIState.onCloseCallback = onClose
    UIState.selectedIndex = nil

    -- Set title
    if Refs.TitleLabel then
        Refs.TitleLabel.Text = "Path Editor - " .. (fileName or "Unknown")
    end

    -- Start editing with PathEditor
    local keypoints = {}
    if UIState.PathEditor then
        keypoints = UIState.PathEditor.StartEditing(fileName, frameData)
    end

    -- Populate list
    PathEditorUI.PopulateKeypointList(keypoints)

    -- Reset detail panel
    PathEditorUI.UpdateDetailPanel(nil, nil)

    -- Show UI with animation
    UIState.screenGui.Enabled = true
    UIState.isOpen = true

    -- Animate in
    Refs.MainFrame.Position = UDim2.new(0.5, -250, 0.6, 0)
    Refs.MainFrame.BackgroundTransparency = 0.5
    Refs.Backdrop.BackgroundTransparency = 1

    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    TweenService:Create(Refs.MainFrame, tweenInfo, {
        Position = UDim2.new(0.5, -250, 0.5, -200),
        BackgroundTransparency = 0
    }):Play()
    TweenService:Create(Refs.Backdrop, tweenInfo, {
        BackgroundTransparency = 0.5
    }):Play()

    return true
end

function PathEditorUI.Close()
    if not UIState.isOpen then
        return
    end

    -- Stop editing
    if UIState.PathEditor then
        UIState.PathEditor.StopEditing()
    end

    -- Animate out
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    TweenService:Create(Refs.MainFrame, tweenInfo, {
        Position = UDim2.new(0.5, -250, 0.6, 0),
        BackgroundTransparency = 0.5
    }):Play()
    TweenService:Create(Refs.Backdrop, tweenInfo, {
        BackgroundTransparency = 1
    }):Play()

    task.delay(0.2, function()
        if UIState.screenGui then
            UIState.screenGui.Enabled = false
        end
    end)

    UIState.isOpen = false

    -- Callback
    if UIState.onCloseCallback then
        UIState.onCloseCallback()
    end
end

function PathEditorUI.Save()
    if not UIState.PathEditor then
        return false, "PathEditor not set"
    end

    local modifiedFrames = UIState.PathEditor.ExportModifiedFrames()
    if not modifiedFrames then
        return false, "No frame data"
    end

    -- Callback with modified data
    if UIState.onSaveCallback then
        UIState.onSaveCallback(modifiedFrames, UIState.currentKeypoints)
    end

    -- Close after save
    PathEditorUI.Close()

    return true
end

function PathEditorUI.IsOpen()
    return UIState.isOpen
end

function PathEditorUI.Destroy()
    PathEditorUI.Close()
    if UIState.screenGui then
        UIState.screenGui:Destroy()
        UIState.screenGui = nil
    end
    UIState = {
        isOpen = false,
        screenGui = nil,
        mainFrame = nil,
        keypointList = nil,
        detailPanel = nil,
        currentKeypoints = {},
        selectedIndex = nil,
        onSaveCallback = nil,
        onCloseCallback = nil,
        PathEditor = nil,
    }
    Refs = {}
end

return PathEditorUI
