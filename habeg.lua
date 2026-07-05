local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- ================= CONFIGURATION =================
local Config = {
    Keybind = Enum.KeyCode.E,           
    ControllerBind = Enum.KeyCode.ButtonX, 
    
    -- UI Settings
    ShowMobileButton = true,           
    ButtonColor = Color3.fromRGB(35, 35, 35),
    AccentColor = Color3.fromRGB(0, 200, 255),
    CloseColor = Color3.fromRGB(255, 60, 60),
    SuccessColor = Color3.fromRGB(0, 255, 150), -- Green for ON
    
    -- Action Settings
    BACKFLIP_COOLDOWN = 0.4,
    MOVEMENT_DURATION = 0.045,   -- durasi back-pull (kalau PULL OFF, ini juga jadi pre-jump delay)
    PULL_PRE_JUMP_DELAY = 0.012, -- delay singkat sebelum jump saat PULL ON (back-pull tetap jalan paralel)
    LANDED_BUFFER = 0.03,
    BackPullEnabled = true, -- Toggle for backward push
    
    -- Default Jump Power
    JumpPower = 50,
}
-- =================================================

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")
local character = nil
local humanoid = nil
local isQueued = false
local queueExpireTime = 0
local activeConnections = {}
local isHolding = false -- TRUE selama tombol/key/gamepad ditahan (auto-repeat)

-- Cleanup Function
local function stopScript()
    for _, conn in pairs(activeConnections) do
        if conn then conn:Disconnect() end
    end
    activeConnections = {}
    local existingUI = pGui:FindFirstChild("BackflipUI")
    if existingUI then existingUI:Destroy() end
    print("[Backflip Script] Terminated.")
end

-- UI Creation
local function createUI()
    if not Config.ShowMobileButton then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BackflipUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = pGui
    
    local container = Instance.new("Frame")
    container.Name = "ControlGroup"
    container.Size = UDim2.new(0, 110, 0, 250)
    container.Position = UDim2.new(0.85, 0, 0.5, 0)
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
        btn.TextSize = (text == "X") and 14 or 16
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

    -- Main Flip Button
    local mainButton = Instance.new("ImageButton")
    mainButton.Name = "FlipButton"
    mainButton.Size = UDim2.new(0, 75, 0, 75)
    mainButton.Position = UDim2.new(0.5, -37.5, 1, -75)
    mainButton.BackgroundColor3 = Config.AccentColor
    mainButton.BorderSizePixel = 0
    mainButton.Image = "rbxassetid://6031094678"
    mainButton.ImageColor3 = Color3.new(1, 1, 1)
    mainButton.AutoButtonColor = false
    mainButton.Parent = container
    Instance.new("UICorner", mainButton).CornerRadius = UDim.new(1, 0)
    local mainStroke = Instance.new("UIStroke", mainButton)
    mainStroke.Thickness = 3
    mainStroke.Color = Color3.new(1, 1, 1)
    mainStroke.Transparency = 0.5

    -- Height Label
    local heightLabel = Instance.new("TextLabel")
    heightLabel.Size = UDim2.new(1, 0, 0, 20)
    heightLabel.Position = UDim2.new(0, 0, 0, 45)
    heightLabel.BackgroundTransparency = 1
    heightLabel.Text = "HEIGHT: " .. Config.JumpPower
    heightLabel.TextColor3 = Config.AccentColor
    heightLabel.Font = Enum.Font.GothamBold
    heightLabel.TextSize = 14
    heightLabel.Parent = container

    -- Height Controls
    local plusBtn = makeSleekButton("PlusBtn", UDim2.new(0, 40, 0, 40), UDim2.new(0.5, 5, 0, 0), "+", nil, container)
    local minusBtn = makeSleekButton("MinusBtn", UDim2.new(0, 40, 0, 40), UDim2.new(0.5, -45, 0, 0), "-", nil, container)

    plusBtn.Activated:Connect(function()
        Config.JumpPower = math.clamp(Config.JumpPower + 5, 0, 200)
        heightLabel.Text = "HEIGHT: " .. Config.JumpPower
    end)
    minusBtn.Activated:Connect(function()
        Config.JumpPower = math.clamp(Config.JumpPower - 5, 0, 200)
        heightLabel.Text = "HEIGHT: " .. Config.JumpPower
    end)

    -- Back-Pull Toggle Button
    local togglePullBtn = makeSleekButton("TogglePullBtn", UDim2.new(0, 90, 0, 30), UDim2.new(0.5, -45, 0, 80), "PULL: ON", Config.SuccessColor, container)
    togglePullBtn.TextSize = 12

    togglePullBtn.Activated:Connect(function()
        Config.BackPullEnabled = not Config.BackPullEnabled
        if Config.BackPullEnabled then
            togglePullBtn.Text = "PULL: ON"
            togglePullBtn.BackgroundColor3 = Config.SuccessColor
            togglePullBtn.UIStroke.Color = Config.SuccessColor
        else
            togglePullBtn.Text = "PULL: OFF"
            togglePullBtn.BackgroundColor3 = Config.CloseColor
            togglePullBtn.UIStroke.Color = Config.CloseColor
        end
    end)

    return mainButton
end

local mobileButton = createUI()

-- Helper: Check if character is on ground
local function isGrounded()
    if not (humanoid and character) then return false end
    local state = humanoid:GetState()
    if humanoid.FloorMaterial == Enum.Material.Air or state == Enum.HumanoidStateType.Jumping then
        return false
    end
    return state ~= Enum.HumanoidStateType.Freefall
end

-- Main Action: Perform Backflip
local function doBackflip()
    if not (humanoid and character) then return end

    if isGrounded() then
        isQueued = false
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            humanoid.UseJumpPower = true
            local originalPower = humanoid.JumpPower
            humanoid.JumpPower = Config.JumpPower
            
            rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.pi, 0)
            task.wait(0.02)
            
            -- Apply Back Pull if enabled (jalan PARALEL, tidak blok jump)
            if Config.BackPullEnabled then
                local startTime = tick()
                task.spawn(function()
                    local connection
                    connection = RunService.RenderStepped:Connect(function()
                        if tick() - startTime > Config.MOVEMENT_DURATION then
                            connection:Disconnect()
                        else
                            if humanoid then
                                humanoid:Move(Vector3.new(0, 0, 1), true)
                            end
                        end
                    end)
                end)
                -- Delay singkat saja supaya pull sempat kerasa, tapi jump tidak nunggu full duration
                task.wait(Config.PULL_PRE_JUMP_DELAY)
            else
                -- PULL OFF: tetap pakai timing original
                task.wait(Config.MOVEMENT_DURATION)
            end

            humanoid:ChangeState(Enum.HumanoidStateType.Running)
            humanoid.Jump = true
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            -- Cancel paksa Move setelah jump fire supaya tidak menahan momentum vertikal
            -- (RenderStepped tetap auto-disconnect saat MOVEMENT_DURATION habis)
            
            task.delay(0.1, function()
                if humanoid then humanoid.JumpPower = originalPower end
            end)
        end
    else
        isQueued = true
        queueExpireTime = tick() + Config.BACKFLIP_COOLDOWN
    end
end

-- Connect Mobile Button (hold to auto-repeat)
if mobileButton then
    mobileButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isHolding = true
            doBackflip()
        end
    end)
    mobileButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            isHolding = false
            isQueued = false
        end
    end)
end

-- Character Setup Logic
local function setupCharacter(newCharacter)
    character = newCharacter
    humanoid = newCharacter:WaitForChild("Humanoid")
    isQueued = false
    
    activeConnections["StateChanged"] = humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Landed then
            if isQueued and tick() < queueExpireTime then
                isQueued = false
                task.wait(Config.LANDED_BUFFER)
                doBackflip()
            end
            isQueued = false
        end
        -- Auto-repeat: kalau tombol/key masih ditahan dan karakter sudah stabil di tanah, flip lagi.
        if newState == Enum.HumanoidStateType.Running and isHolding and isGrounded() then
            doBackflip()
        end
    end)
end

-- Initialize Character
if player.Character then setupCharacter(player.Character) end
activeConnections["CharacterAdded"] = player.CharacterAdded:Connect(setupCharacter)

-- Input Handling (Keyboard & Gamepad) - hold to auto-repeat
activeConnections["InputBegan"] = UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Config.Keybind) or
       (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Config.ControllerBind) then
        isHolding = true
        doBackflip()
    end
end)

activeConnections["InputEnded"] = UIS.InputEnded:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Config.Keybind) or
       (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Config.ControllerBind) then
        isHolding = false
        isQueued = false
    end
end)