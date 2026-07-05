--[[
    NAGA-NAGA Helper
    ----------------
    Auto-zigzag jumper untuk parkour platform zigzag.
    Mimic teknik tutorial: HOLD jump button + auto-tap analog alternating.

    Cara kerja:
      - Tahan tombol Q / kotak / button UI -> auto-fire jump tiap landing
      - Tiap jump kasih impuls horizontal singkat ke arah alternating (kiri/kanan)
      - Lepas tombol -> berhenti
]]

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- ================= CONFIGURATION =================
local Config = {
    Keybind = Enum.KeyCode.Q,                -- PC keybind
    ControllerBind = Enum.KeyCode.ButtonX,   -- Gamepad: Square (PS) / X (Xbox)

    -- UI Settings
    ShowMobileButton = true,
    ButtonColor = Color3.fromRGB(35, 35, 35),
    AccentColor = Color3.fromRGB(255, 140, 0),
    CloseColor = Color3.fromRGB(255, 60, 60),
    SuccessColor = Color3.fromRGB(0, 255, 150),

    -- Jump Settings (mimic teknik D-A-SPACE: tap D lalu A di mid-air, SPACE saat landing)
    JumpPower = 63,                 -- tinggi loncatan (vy initial)
    JumpCooldown = 0.36,            -- cooldown min antar jump
    RelativeToCamera = true,        -- arah relatif kamera (true) atau karakter (false)

    -- D-A-SPACE Pattern (sesuai tutorial: D = lift sebelum jump, A = banting di udara)
    -- Delays bisa NEGATIF artinya BEFORE jump fire (initial lift), POSITIF artinya AFTER (mid-air whip)
    TapD_Delay = -0.08,             -- D ditap 0.08s SEBELUM jump fire (untuk lift kanan)
    TapD_Speed = 30,                -- kekuatan dorong tap D
    TapD_Duration = 0.10,           -- berapa lama D ditap

    TapA_Delay = 0.18,              -- A ditap 0.18s SETELAH jump (di udara, banting balik ke kiri)
    TapA_Speed = 30,                -- kekuatan dorong tap A (banting)
    TapA_Duration = 0.18,           -- A ditahan supaya momentum balik kelihatan

    -- Facing
    FaceMoveDirection = true,       -- karakter menghadap ke arah tap aktif
    SmoothTurnDuration = 0.44,      -- durasi belok smooth saat ganti arah tap

    -- Anti-bot: variasi acak (default OFF biar timing konsisten)
    JitterPercent = 0.00,           -- 0 = robotik tapi konsisten, 0.05-0.08 natural tipis
    SkipChance = 0.00,              -- chance (0-1) untuk skip salah satu tap
}
-- =================================================

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")
local character = nil
local humanoid = nil
local rootPart = nil
local activeConnections = {}
local nextDirection = nil
local activeGlideConn = nil
local activeTurnConn = nil
local isHolding = false
local holdLoopConn = nil
local alternateSign = 1  -- +1 = D-lift/A-banting, -1 = A-lift/D-banting (dibalas tiap jump)
local defaultJumpPower = nil  -- nilai asli humanoid.JumpPower (untuk restore selalu konsisten)

local function stopTurn()
    if activeTurnConn then
        pcall(function() activeTurnConn:Disconnect() end)
        activeTurnConn = nil
    end
end

-- ============== Helpers ==============
local function isGrounded()
    if not (humanoid and character) then return false end
    local state = humanoid:GetState()
    if humanoid.FloorMaterial == Enum.Material.Air or state == Enum.HumanoidStateType.Jumping then
        return false
    end
    return state ~= Enum.HumanoidStateType.Freefall
end

local function getRightVector()
    if Config.RelativeToCamera then
        local cam = workspace.CurrentCamera
        if cam then
            local r = cam.CFrame.RightVector
            local flat = Vector3.new(r.X, 0, r.Z)
            if flat.Magnitude > 0.01 then return flat.Unit end
        end
    end
    if rootPart then
        local r = rootPart.CFrame.RightVector
        local flat = Vector3.new(r.X, 0, r.Z)
        if flat.Magnitude > 0.01 then return flat.Unit end
    end
    return Vector3.new(1, 0, 0)
end

local function stopGlide()
    if activeGlideConn then
        pcall(function() activeGlideConn:Disconnect() end)
        activeGlideConn = nil
    end
end

local function stopHoldLoop()
    isHolding = false
    if holdLoopConn then
        pcall(function() holdLoopConn:Disconnect() end)
        holdLoopConn = nil
    end
end

-- ============== Cleanup ==============
local function stopScript()
    stopHoldLoop()
    stopGlide()
    for _, conn in pairs(activeConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    activeConnections = {}
    local existingUI = pGui:FindFirstChild("NagaNagaUI")
    if existingUI then existingUI:Destroy() end
    print("[Naga-Naga] Terminated.")
end

-- ============== UI ==============
local function createUI()
    if not Config.ShowMobileButton then return end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NagaNagaUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = pGui

    local container = Instance.new("Frame")
    container.Name = "ControlGroup"
    container.Size = UDim2.new(0, 110, 0, 200)
    container.Position = UDim2.new(0.85, 0, 0.3, 0)
    container.BackgroundTransparency = 1
    container.Parent = screenGui

    -- ===== Title =====
    local title = Instance.new("TextLabel", container)
    title.Size = UDim2.new(1, 0, 0, 18)
    title.Position = UDim2.new(0, 0, 0, -10)
    title.BackgroundTransparency = 1
    title.Text = "🐉 NAGA"
    title.TextColor3 = Config.AccentColor
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 14

    -- ===== Top buttons (X, Settings) =====
    local function quickBtn(name, pos, text, color, parent)
        local btn = Instance.new("TextButton", parent)
        btn.Name = name
        btn.Size = UDim2.new(0, 25, 0, 25)
        btn.Position = pos
        btn.BackgroundColor3 = color
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0.3, 0)
        return btn
    end

    local exitBtn = quickBtn("ExitBtn", UDim2.new(1, -25, 0, -30), "X", Config.CloseColor, container)
    exitBtn.Activated:Connect(stopScript)

    local gearBtn = quickBtn("GearBtn", UDim2.new(0, 0, 0, -30), "⚙", Color3.fromRGB(60, 60, 70), container)

    -- ===== Main Leap Button =====
    local mainButton = Instance.new("ImageButton", container)
    mainButton.Name = "LeapButton"
    mainButton.Size = UDim2.new(0, 75, 0, 75)
    mainButton.Position = UDim2.new(0.5, -37.5, 1, -75)
    mainButton.BackgroundColor3 = Config.AccentColor
    mainButton.BorderSizePixel = 0
    mainButton.Image = "rbxassetid://6034509993"
    mainButton.ImageColor3 = Color3.new(1, 1, 1)
    mainButton.AutoButtonColor = false
    Instance.new("UICorner", mainButton).CornerRadius = UDim.new(1, 0)
    local mainStroke = Instance.new("UIStroke", mainButton)
    mainStroke.Thickness = 3
    mainStroke.Color = Color3.new(1, 1, 1)
    mainStroke.Transparency = 0.5

    -- ===== Settings Panel =====
    local settingsPanel = Instance.new("Frame", screenGui)
    settingsPanel.Name = "SettingsPanel"
    settingsPanel.Size = UDim2.new(0, 260, 0, 360)
    settingsPanel.Position = UDim2.new(0.5, -130, 0.5, -180)
    settingsPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    settingsPanel.BorderSizePixel = 0
    settingsPanel.Visible = false
    settingsPanel.Active = true
    settingsPanel.Draggable = true
    Instance.new("UICorner", settingsPanel).CornerRadius = UDim.new(0, 8)
    local panelStroke = Instance.new("UIStroke", settingsPanel)
    panelStroke.Color = Config.AccentColor
    panelStroke.Thickness = 2
    panelStroke.Transparency = 0.3

    local panelTitle = Instance.new("TextLabel", settingsPanel)
    panelTitle.Size = UDim2.new(1, -30, 0, 28)
    panelTitle.Position = UDim2.new(0, 8, 0, 4)
    panelTitle.BackgroundTransparency = 1
    panelTitle.Text = "🐉 NAGA SETTINGS"
    panelTitle.TextColor3 = Config.AccentColor
    panelTitle.Font = Enum.Font.GothamBlack
    panelTitle.TextSize = 14
    panelTitle.TextXAlignment = Enum.TextXAlignment.Left

    local panelClose = quickBtn("PanelClose", UDim2.new(1, -28, 0, 5), "X", Config.CloseColor, settingsPanel)
    panelClose.Size = UDim2.new(0, 22, 0, 22)
    panelClose.Activated:Connect(function() settingsPanel.Visible = false end)

    -- Scrolling list of settings
    local scroll = Instance.new("ScrollingFrame", settingsPanel)
    scroll.Size = UDim2.new(1, -16, 1, -42)
    scroll.Position = UDim2.new(0, 8, 0, 36)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Config.AccentColor
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local listLayout = Instance.new("UIListLayout", scroll)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)

    -- Helper untuk bikin satu row setting (label + value + - / +)
    local function makeRow(label, configKey, step, minVal, maxVal, decimals, layoutOrder)
        local row = Instance.new("Frame", scroll)
        row.Size = UDim2.new(1, -4, 0, 30)
        row.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        row.BorderSizePixel = 0
        row.LayoutOrder = layoutOrder
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(0.55, 0, 1, 0)
        lbl.Position = UDim2.new(0, 8, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local minus = Instance.new("TextButton", row)
        minus.Size = UDim2.new(0, 22, 0, 22)
        minus.Position = UDim2.new(0.55, 0, 0.5, -11)
        minus.BackgroundColor3 = Config.ButtonColor
        minus.BorderSizePixel = 0
        minus.Text = "-"
        minus.TextColor3 = Color3.new(1, 1, 1)
        minus.Font = Enum.Font.GothamBold
        minus.TextSize = 14
        Instance.new("UICorner", minus).CornerRadius = UDim.new(0.3, 0)

        local valueLbl = Instance.new("TextLabel", row)
        valueLbl.Size = UDim2.new(0, 50, 0, 22)
        valueLbl.Position = UDim2.new(0.55, 24, 0.5, -11)
        valueLbl.BackgroundTransparency = 1
        valueLbl.TextColor3 = Config.AccentColor
        valueLbl.Font = Enum.Font.GothamBold
        valueLbl.TextSize = 12
        valueLbl.Text = string.format("%." .. decimals .. "f", Config[configKey])

        local plus = Instance.new("TextButton", row)
        plus.Size = UDim2.new(0, 22, 0, 22)
        plus.Position = UDim2.new(1, -26, 0.5, -11)
        plus.BackgroundColor3 = Config.ButtonColor
        plus.BorderSizePixel = 0
        plus.Text = "+"
        plus.TextColor3 = Color3.new(1, 1, 1)
        plus.Font = Enum.Font.GothamBold
        plus.TextSize = 14
        Instance.new("UICorner", plus).CornerRadius = UDim.new(0.3, 0)

        local function refresh()
            valueLbl.Text = string.format("%." .. decimals .. "f", Config[configKey])
        end
        plus.Activated:Connect(function()
            Config[configKey] = math.clamp(Config[configKey] + step, minVal, maxVal)
            refresh()
        end)
        minus.Activated:Connect(function()
            Config[configKey] = math.clamp(Config[configKey] - step, minVal, maxVal)
            refresh()
        end)
    end

    -- Daftar setting yang bisa diatur dari UI
    makeRow("Jump Power",       "JumpPower",          1,    0,   250, 0, 1)
    makeRow("Jump Cooldown",    "JumpCooldown",       0.02, 0.02, 1, 2, 2)
    -- Delay bisa NEGATIF: tap fire SEBELUM SPACE (initial lift sesuai tutorial)
    makeRow("Tap D Delay",      "TapD_Delay",         0.02, -0.5, 1, 2, 3)
    makeRow("Tap D Speed",      "TapD_Speed",         2,    0,  200, 0, 4)
    makeRow("Tap D Duration",   "TapD_Duration",      0.02, 0.02, 1, 2, 5)
    makeRow("Tap A Delay",      "TapA_Delay",         0.02, -0.5, 1, 2, 6)
    makeRow("Tap A Speed",      "TapA_Speed",         2,    0,  200, 0, 7)
    makeRow("Tap A Duration",   "TapA_Duration",      0.02, 0.02, 1, 2, 8)
    makeRow("Smooth Turn",      "SmoothTurnDuration", 0.02, 0.02, 1, 2, 9)
    makeRow("Jitter %",         "JitterPercent",      0.02, 0,    0.5, 2, 10)
    makeRow("Skip Chance",      "SkipChance",         0.01, 0,    0.5, 2, 11)

    gearBtn.Activated:Connect(function()
        settingsPanel.Visible = not settingsPanel.Visible
    end)

    return mainButton
end

local mobileButton = createUI()

-- ============== Core: SPACE jump + mid-air D tap, A tap ==============
-- Pola: SPACE (jump) -> di udara tap D singkat -> tap A singkat -> landing -> ulangi.
local function applyTap(dir, speed, duration)
    if not (rootPart and rootPart.Parent) then return end
    local rightVec = getRightVector()
    local push = rightVec * speed * dir

    -- Hadapkan karakter ke arah tap (smooth turn)
    if Config.FaceMoveDirection then
        local startCF = rootPart.CFrame
        local startLook = startCF.LookVector
        local targetLook = (rightVec * dir).Unit
        local startYaw = math.atan2(-startLook.X, -startLook.Z)
        local targetYaw = math.atan2(-targetLook.X, -targetLook.Z)
        local deltaYaw = targetYaw - startYaw
        if deltaYaw > math.pi then deltaYaw = deltaYaw - 2 * math.pi end
        if deltaYaw < -math.pi then deltaYaw = deltaYaw + 2 * math.pi end

        -- Disconnect turn aktif sebelumnya supaya tidak overlap (yang bikin terasa cepat)
        stopTurn()
        local turnT0 = tick()
        activeTurnConn = RunService.Heartbeat:Connect(function()
            if not (rootPart and rootPart.Parent) then
                stopTurn()
                return
            end
            local p = math.clamp((tick() - turnT0) / Config.SmoothTurnDuration, 0, 1)
            local eased = p < 0.5 and 2 * p * p or 1 - math.pow(-2 * p + 2, 2) / 2
            local yaw = startYaw + deltaYaw * eased
            local pos = rootPart.Position
            local newLook = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
            rootPart.CFrame = CFrame.lookAt(pos, pos + newLook)
            if p >= 1 then
                stopTurn()
            end
        end)
    end

    -- Apply impuls + maintain selama duration
    stopGlide()
    local v0 = rootPart.AssemblyLinearVelocity
    rootPart.AssemblyLinearVelocity = Vector3.new(push.X, v0.Y, push.Z)

    local t0 = tick()
    activeGlideConn = RunService.Heartbeat:Connect(function()
        if not rootPart or not rootPart.Parent then stopGlide(); return end
        if tick() - t0 > duration then stopGlide(); return end
        local cv = rootPart.AssemblyLinearVelocity
        rootPart.AssemblyLinearVelocity = Vector3.new(push.X, cv.Y, push.Z)
    end)
end

-- Helper: kasih variasi acak +/- (jitterPct * value)
local function jitter(value)
    local pct = Config.JitterPercent or 0
    if pct <= 0 then return value end
    local variance = value * pct
    return value + (math.random() * 2 - 1) * variance
end

local function fireOneJump()
    if not (humanoid and character and rootPart) then return end

    -- Hitung delay actual (dengan jitter) untuk D, A, dan SPACE
    local dDelay = jitter(Config.TapD_Delay)
    local aDelay = jitter(Config.TapA_Delay)
    local jumpDelay = 0

    -- Kalau ada delay negatif (tap SEBELUM jump), shift timeline supaya event paling awal = 0
    -- dan SPACE digeser ke kanan. Ini bikin "initial lift" sesuai tutorial.
    local minDelay = math.min(dDelay, aDelay, jumpDelay)
    if minDelay < 0 then
        dDelay = dDelay - minDelay
        aDelay = aDelay - minDelay
        jumpDelay = -minDelay
    end

    -- Skip chance: kadang miss D atau A supaya gak terlihat robotik
    local doD = math.random() >= (Config.SkipChance or 0)
    local doA = math.random() >= (Config.SkipChance or 0)

    -- ZIGZAG: tiap jump dibalas. alternateSign +1 = D dulu/A banting, -1 = A dulu/D banting
    local sign = alternateSign
    alternateSign = -alternateSign

    -- 1) Tap "lift" (sebelum jump) - arah = sign
    if doD then
        task.delay(math.max(0, dDelay), function()
            applyTap(sign, jitter(Config.TapD_Speed), math.max(0.02, jitter(Config.TapD_Duration)))
        end)
    end

    -- 2) Tap "banting" (setelah jump, di udara) - arah = -sign (lawan)
    if doA then
        task.delay(math.max(0, aDelay), function()
            applyTap(-sign, jitter(Config.TapA_Speed), math.max(0.02, jitter(Config.TapA_Duration)))
        end)
    end

    -- 3) SPACE (jump) - di-delay kalau D/A perlu fire duluan (initial lift)
    -- Selalu restore ke defaultJumpPower (bukan capture per-fire), supaya gak drift
    -- kalau fire berikutnya nyusul cepat.
    local h = humanoid
    task.delay(jumpDelay, function()
        if not h or not h.Parent then return end
        h.UseJumpPower = true
        h.JumpPower = math.max(1, jitter(Config.JumpPower))
        h:ChangeState(Enum.HumanoidStateType.Jumping)
        h.Jump = true
        task.delay(0.18, function()
            if h and h.Parent and defaultJumpPower then
                h.JumpPower = defaultJumpPower
            end
        end)
    end)
end

-- ============== HOLD Loop: auto-jump tiap landing (edge-trigger, no spam) ==============
local function startHoldLoop()
    if isHolding then return end
    isHolding = true

    local lastFireTime = 0
    local wasInAir = not isGrounded()  -- track transisi air -> ground

    local function tryFire(reason)
        if not isHolding then return end
        if not (humanoid and rootPart and rootPart.Parent) then return end
        local now = tick()
        if now - lastFireTime < Config.JumpCooldown then return end
        lastFireTime = now
        fireOneJump()
    end

    -- Fire pertama segera kalau lagi di tanah
    if isGrounded() then
        tryFire("initial")
        wasInAir = true  -- biar trigger berikutnya nunggu transisi
    end

    -- Trigger 1: heartbeat - transisi air -> ground (edge only, gak spam)
    local hbConn = RunService.Heartbeat:Connect(function()
        if not isHolding then return end
        local grounded = isGrounded()
        if grounded then
            if wasInAir then
                wasInAir = false
                tryFire("landing")
            end
        else
            wasInAir = true
        end
    end)

    -- Trigger 2: StateChanged backup - kadang heartbeat miss frame transisi
    -- (terutama kalau FPS drop). Gak akan double-fire karena ada cooldown.
    local stateConn
    if humanoid then
        stateConn = humanoid.StateChanged:Connect(function(_, newState)
            if not isHolding then return end
            if newState == Enum.HumanoidStateType.Landed then
                wasInAir = false
                tryFire("state-landed")
            elseif newState == Enum.HumanoidStateType.Freefall
                or newState == Enum.HumanoidStateType.Jumping then
                wasInAir = true
            end
        end)
    end

    holdLoopConn = {
        Disconnect = function()
            pcall(function() hbConn:Disconnect() end)
            pcall(function() if stateConn then stateConn:Disconnect() end end)
        end,
    }
end

local function resetDirection()
    nextDirection = Config.StartDirection
end

-- ============== Mobile Button (HOLD) ==============
-- Pakai global UIS.InputEnded juga, supaya kalau jari/cursor slide keluar
-- tombol pas dilepas, hold tetap ke-detect berhenti.
if mobileButton then
    local activeTouchId = nil

    local function beginHold(input)
        if input then
            if input.UserInputType == Enum.UserInputType.Touch then
                activeTouchId = input
            end
        end
        startHoldLoop()
    end

    local function endHold()
        activeTouchId = nil
        stopHoldLoop()
    end

    mobileButton.MouseButton1Down:Connect(function() beginHold(nil) end)
    mobileButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            beginHold(input)
        end
    end)

    -- Global release: lepas di mana saja tetap stop (fix "stuck" hold di mobile)
    UIS.InputEnded:Connect(function(input)
        if not isHolding then return end
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Kalau ada touch khusus tracked, pastikan ini touch yang sama
            if activeTouchId and input ~= activeTouchId
                and input.UserInputType == Enum.UserInputType.Touch then
                return
            end
            endHold()
        end
    end)
end

-- ============== Character Setup ==============
local function setupCharacter(newCharacter)
    character = newCharacter
    humanoid = newCharacter:WaitForChild("Humanoid")
    rootPart = newCharacter:WaitForChild("HumanoidRootPart")
    -- Simpan JumpPower asli (clone) sekali, gak ke-corrupt walau fire cepat
    defaultJumpPower = humanoid.JumpPower
    humanoid.UseJumpPower = true
    stopGlide()
    stopHoldLoop()
    resetDirection()
    alternateSign = 1
end

if player.Character then setupCharacter(player.Character) end
activeConnections["CharacterAdded"] = player.CharacterAdded:Connect(setupCharacter)

-- ============== Keyboard & Gamepad (HOLD) ==============
activeConnections["InputBegan"] = UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Config.Keybind)
        or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Config.ControllerBind) then
        startHoldLoop()
    end
end)
activeConnections["InputEnded"] = UIS.InputEnded:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Config.Keybind)
        or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Config.ControllerBind) then
        stopHoldLoop()
    end
end)

print("[Naga-Naga] Loaded. HOLD " .. Config.Keybind.Name .. " / 🐉 button untuk auto-zigzag jump.")
