local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- ================= CONFIGURATION =================
local Config = {
    Keybind = Enum.KeyCode.J,           -- Key to toggle High Jump
    
    -- UI Settings
    ButtonColor = Color3.fromRGB(35, 35, 35),
    AccentColor = Color3.fromRGB(255, 170, 0), -- Orange for High Jump
    SuccessColor = Color3.fromRGB(0, 255, 150),
    CloseColor = Color3.fromRGB(240, 50, 50),
    
    -- Jump Settings
    DefaultJump = 50,
    HighJumpValue = 65,
    IsEnabled = false,
}
-- =================================================

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")
local character = nil
local humanoid = nil
local activeConnections = {}
local uiElements = {}

-- Update Jump Logic & UI Sync
local function updateJumpState()
    if not humanoid then return end
    
    if Config.IsEnabled then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = Config.HighJumpValue
        if uiElements.ToggleBtn then
            uiElements.ToggleBtn.Text = "JUMP: ON"
            uiElements.ToggleBtn.BackgroundColor3 = Config.SuccessColor
            uiElements.ToggleBtn.UIStroke.Color = Config.SuccessColor
        end
    else
        humanoid.JumpPower = Config.DefaultJump
        if uiElements.ToggleBtn then
            uiElements.ToggleBtn.Text = "JUMP: OFF"
            uiElements.ToggleBtn.BackgroundColor3 = Config.CloseColor
            uiElements.ToggleBtn.UIStroke.Color = Config.CloseColor
        end
    end
end

-- Cleanup Function
local function stopScript()
    Config.IsEnabled = false
    updateJumpState()
    for _, conn in pairs(activeConnections) do
        if conn then conn:Disconnect() end
    end
    activeConnections = {}
    local existingUI = pGui:FindFirstChild("HighJumpUI")
    if existingUI then existingUI:Destroy() end
    print("[High Jump] Terminated.")
end

-- UI Creation
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HighJumpUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = pGui
    
    local container = Instance.new("Frame")
    container.Name = "ControlGroup"
    container.Size = UDim2.new(0, 110, 0, 180)
    container.Position = UDim2.new(0.85, 10, 0.25, 0)
    container.BackgroundTransparency = 1
    container.Parent = screenGui
    
    local function makeSleekButton(name, size, pos, text, color, parent)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = size
        btn.Position = pos
        btn.BackgroundColor3 = color or Config.ButtonColor
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.AutoButtonColor = false
        btn.Parent = parent
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.3, 0)
        corner.Parent = btn
        
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1.5
        stroke.Color = color or Config.AccentColor
        stroke.Transparency = 0.6
        stroke.Parent = btn
        
        btn.MouseButton1Down:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(size.X.Scale, size.X.Offset-4, size.Y.Scale, size.Y.Offset-4)}):Play()
        end)
        btn.MouseButton1Up:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {Size = size}):Play()
        end)
        
        return btn
    end

    local exitBtn = makeSleekButton("ExitBtn", UDim2.new(0, 25, 0, 25), UDim2.new(1, -25, 0, -30), "X", Config.CloseColor, container)
    exitBtn.Activated:Connect(stopScript)

    local toggleBtn = makeSleekButton("ToggleBtn", UDim2.new(0, 100, 0, 40), UDim2.new(0, 0, 0, 0), "JUMP: OFF", Config.CloseColor, container)
    uiElements.ToggleBtn = toggleBtn
    
    local heightLabel = Instance.new("TextLabel")
    heightLabel.Size = UDim2.new(1, 0, 0, 20)
    heightLabel.Position = UDim2.new(0, 0, 0, 50)
    heightLabel.BackgroundTransparency = 1
    heightLabel.Text = "POWER: " .. Config.HighJumpValue
    heightLabel.TextColor3 = Config.AccentColor
    heightLabel.Font = Enum.Font.GothamBold
    heightLabel.TextSize = 14
    heightLabel.Parent = container

    local plusBtn = makeSleekButton("PlusBtn", UDim2.new(0, 40, 0, 40), UDim2.new(0.5, 5, 0, 80), "+", nil, container)
    local minusBtn = makeSleekButton("MinusBtn", UDim2.new(0, 40, 0, 40), UDim2.new(0.5, -45, 0, 80), "-", nil, container)

    toggleBtn.Activated:Connect(function()
        Config.IsEnabled = not Config.IsEnabled
        updateJumpState()
    end)

    plusBtn.Activated:Connect(function()
        Config.HighJumpValue = math.clamp(Config.HighJumpValue + 1, 0, 500)
        heightLabel.Text = "POWER: " .. Config.HighJumpValue
        if Config.IsEnabled then updateJumpState() end
    end)
    
    minusBtn.Activated:Connect(function()
        Config.HighJumpValue = math.clamp(Config.HighJumpValue - 1, 0, 500)
        heightLabel.Text = "POWER: " .. Config.HighJumpValue
        if Config.IsEnabled then updateJumpState() end
    end)
end

createUI()

local function setupCharacter(newCharacter)
    character = newCharacter
    humanoid = newCharacter:WaitForChild("Humanoid")
    updateJumpState()
end

if player.Character then setupCharacter(player.Character) end
activeConnections["CharacterAdded"] = player.CharacterAdded:Connect(setupCharacter)

activeConnections["InputBegan"] = UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.Keybind then
        Config.IsEnabled = not Config.IsEnabled
        updateJumpState()
    end
end)
