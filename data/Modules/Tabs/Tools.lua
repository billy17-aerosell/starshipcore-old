local function SetupToolsUI(PageTools, UI, Connections, Config, LocalPlayer, UIHandlers, RegisterTheme)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")

    -- UPDATED THEME
    local C_MAIN = Color3.fromRGB(10, 10, 14)
    local C_SIDE = Color3.fromRGB(15, 15, 20)
    local C_ACCENT = Color3.fromRGB(90, 110, 245) -- Midnight Blue
    local C_TEXT = Color3.fromRGB(240, 240, 250)
    local C_TEXT_DIM = Color3.fromRGB(140, 140, 160)
    local C_ITEM = Color3.fromRGB(20, 20, 28)
    local C_RED = Color3.fromRGB(255, 80, 80)
    local C_YELLOW = Color3.fromRGB(255, 220, 60)
    local C_GREEN = Color3.fromRGB(60, 255, 160)

    -- Ensure RegisterTheme exists
    if not RegisterTheme then
        RegisterTheme = function() end
    end

    PageTools:ClearAllChildren()
    local ToolsScroll = Instance.new("ScrollingFrame", PageTools)
    ToolsScroll.Size = UDim2.new(1, 0, 1, 0)
    ToolsScroll.BackgroundTransparency = 1
    ToolsScroll.BorderSizePixel = 0
    ToolsScroll.ScrollBarThickness = 4
    ToolsScroll.ScrollBarImageColor3 = C_ACCENT
    ToolsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ToolsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    RegisterTheme(ToolsScroll, "ScrollBarImageColor3", "Accent")
    local ToolsLayout = Instance.new("UIListLayout", ToolsScroll)
    ToolsLayout.Padding = UDim.new(0, 15)
    ToolsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ToolsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local function CreateCard(t, h, o)
        local c = Instance.new("Frame", ToolsScroll)
        c.Size = UDim2.new(0.96, 0, 0, h)
        c.BackgroundColor3 = C_ITEM
        c.LayoutOrder = o
        Instance.new("UICorner", c).CornerRadius = UDim.new(0, 12)
        local s = Instance.new("UIStroke", c)
        s.Color = C_ACCENT
        s.Transparency = 0.8
        s.Thickness = 1
        local l = Instance.new("TextLabel", c)
        l.Text = t
        l.Size = UDim2.new(1, -20, 0, 30)
        l.Position = UDim2.new(0, 15, 0, 0)
        l.BackgroundTransparency = 1
        l.TextColor3 = C_TEXT_DIM
        l.Font = Enum.Font.GothamBold
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left

        RegisterTheme(c, "BackgroundColor3", "Item")
        RegisterTheme(s, "Color", "Accent")
        RegisterTheme(l, "TextColor3", "TextDim")
        return c
    end

    local function StyleBtn(btn, col)
        btn.BackgroundColor3 = C_SIDE
        btn.TextColor3 = col
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local s = Instance.new("UIStroke", btn)
        s.Color = col
        s.Transparency = 0.7
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        RegisterTheme(btn, "BackgroundColor3", "Side")
        if col == C_ACCENT then
            RegisterTheme(btn, "TextColor3", "Accent")
            RegisterTheme(s, "Color", "Accent")
        elseif col == C_TEXT then
            RegisterTheme(btn, "TextColor3", "Text")
            RegisterTheme(s, "Color", "Text")
        elseif col == C_TEXT_DIM then
            RegisterTheme(btn, "TextColor3", "TextDim")
            RegisterTheme(s, "Color", "TextDim")
        elseif col == C_GREEN then
            -- Static color, don't theme
        elseif col == C_RED then
            -- Static color, don't theme
        end
    end

    -- 1. SPEED CHECKER
    local CardSpeed = CreateCard("SPEED CHECKER", 85, 1)

    local BtnSpeedCheck = Instance.new("TextButton", CardSpeed)
    BtnSpeedCheck.Text = "SPEED DISPLAY: OFF"
    BtnSpeedCheck.Size = UDim2.new(0.94, 0, 0, 35)
    BtnSpeedCheck.Position = UDim2.new(0.03, 0, 0, 35)
    StyleBtn(BtnSpeedCheck, C_RED)

    local isSpeedCheck = false
    local speedCon = nil
    local speedGui = nil

    local speedScreenGui = nil

    local function CreateSpeedDisplay()
        if speedScreenGui then
            speedScreenGui:Destroy()
        end

        -- Create separate ScreenGui for independent dragging
        local CoreGui = game:GetService("CoreGui")
        speedScreenGui = Instance.new("ScreenGui")
        speedScreenGui.Name = "StarshipSpeedDisplay"
        speedScreenGui.ResetOnSpawn = false
        speedScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        speedScreenGui.DisplayOrder = 999

        -- Try to parent to CoreGui, fallback to PlayerGui
        local success = pcall(function()
            speedScreenGui.Parent = CoreGui
        end)
        if not success then
            speedScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end

        speedGui = Instance.new("Frame", speedScreenGui)
        speedGui.Name = "SpeedFrame"
        speedGui.Size = UDim2.new(0, 160, 0, 80)
        speedGui.Position = UDim2.new(0.5, -80, 0, 15)
        speedGui.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        speedGui.BackgroundTransparency = 0.15
        speedGui.BorderSizePixel = 0
        Instance.new("UICorner", speedGui).CornerRadius = UDim.new(0, 12)

        local stroke = Instance.new("UIStroke", speedGui)
        stroke.Color = C_ACCENT
        stroke.Thickness = 1.5
        stroke.Transparency = 0.3

        -- Gradient background
        local gradient = Instance.new("UIGradient", speedGui)
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 28)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 14)),
        })
        gradient.Rotation = 90

        -- Icon/Title row
        local titleLbl = Instance.new("TextLabel", speedGui)
        titleLbl.Text = "WALKSPEED"
        titleLbl.Size = UDim2.new(1, 0, 0, 18)
        titleLbl.Position = UDim2.new(0, 0, 0, 8)
        titleLbl.BackgroundTransparency = 1
        titleLbl.TextColor3 = C_TEXT_DIM
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 9

        -- Main speed value
        local speedLbl = Instance.new("TextLabel", speedGui)
        speedLbl.Name = "SpeedValue"
        speedLbl.Text = "0.0"
        speedLbl.Size = UDim2.new(1, 0, 0, 32)
        speedLbl.Position = UDim2.new(0, 0, 0, 24)
        speedLbl.BackgroundTransparency = 1
        speedLbl.TextColor3 = C_ACCENT
        speedLbl.Font = Enum.Font.GothamBold
        speedLbl.TextSize = 28

        -- Unit label
        local unitLbl = Instance.new("TextLabel", speedGui)
        unitLbl.Text = "(default: 16)"
        unitLbl.Size = UDim2.new(1, 0, 0, 14)
        unitLbl.Position = UDim2.new(0, 0, 0, 56)
        unitLbl.BackgroundTransparency = 1
        unitLbl.TextColor3 = C_TEXT_DIM
        unitLbl.Font = Enum.Font.Gotham
        unitLbl.TextSize = 9

        -- Drag handle indicator (subtle line at top)
        local dragHandle = Instance.new("Frame", speedGui)
        dragHandle.Size = UDim2.new(0, 40, 0, 3)
        dragHandle.Position = UDim2.new(0.5, -20, 0, 3)
        dragHandle.BackgroundColor3 = C_TEXT_DIM
        dragHandle.BackgroundTransparency = 0.7
        dragHandle.BorderSizePixel = 0
        Instance.new("UICorner", dragHandle).CornerRadius = UDim.new(1, 0)

        -- Make draggable
        local dragging, dragInput, dragStart, startPos
        speedGui.InputBegan:Connect(function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging = true
                dragStart = input.Position
                startPos = speedGui.Position
            end
        end)
        speedGui.InputChanged:Connect(function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                speedGui.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging = false
            end
        end)

        return speedGui
    end

    local function ToggleSpeedCheck()
        isSpeedCheck = not isSpeedCheck
        BtnSpeedCheck.Text = isSpeedCheck and "SPEED DISPLAY: ON" or "SPEED DISPLAY: OFF"
        BtnSpeedCheck.TextColor3 = isSpeedCheck and C_GREEN or C_RED
        BtnSpeedCheck.UIStroke.Color = isSpeedCheck and C_GREEN or C_RED

        if isSpeedCheck then
            speedGui = CreateSpeedDisplay()

            speedCon = RunService.Heartbeat:Connect(function()
                local c = LocalPlayer.Character
                local hum = c and c:FindFirstChild("Humanoid")
                if hum and speedGui then
                    local speed = hum.WalkSpeed

                    local speedLbl = speedGui:FindFirstChild("SpeedValue")
                    if speedLbl then
                        speedLbl.Text = string.format("%.0f", speed)
                        -- Color based on speed
                        if speed <= 16 then
                            speedLbl.TextColor3 = C_TEXT   -- Default/Walking
                        elseif speed <= 30 then
                            speedLbl.TextColor3 = C_GREEN  -- Normal boosted
                        elseif speed <= 60 then
                            speedLbl.TextColor3 = C_YELLOW -- Fast
                        else
                            speedLbl.TextColor3 = C_RED    -- Very fast
                        end
                    end
                end
            end)
            table.insert(Connections, speedCon)
        else
            if speedCon then
                speedCon:Disconnect()
                speedCon = nil
            end
            if speedScreenGui then
                speedScreenGui:Destroy()
                speedScreenGui = nil
                speedGui = nil
            end
        end
    end

    BtnSpeedCheck.MouseButton1Click:Connect(ToggleSpeedCheck)

    -- Expose cleanup function for when main UI closes
    UIHandlers.CleanupSpeedDisplay = function()
        if speedCon then
            speedCon:Disconnect()
            speedCon = nil
        end
        if speedScreenGui then
            speedScreenGui:Destroy()
            speedScreenGui = nil
            speedGui = nil
        end
        isSpeedCheck = false
    end

    -- 2. AUTOMATION
    local CardAuto = CreateCard("AUTOMATION", 120, 2)
    local BtnAfk = Instance.new("TextButton", CardAuto)
    BtnAfk.Text = "Anti-AFK: OFF"
    BtnAfk.Size = UDim2.new(0.45, 0, 0, 35)
    BtnAfk.Position = UDim2.new(0.03, 0, 0, 35)
    StyleBtn(BtnAfk, C_TEXT_DIM)

    local afkCon = nil
    local isAfkOn = false

    local function ToggleAntiAFK(forceEnable)
        if forceEnable ~= nil then
            if forceEnable == isAfkOn then
                return
            end
        end

        isAfkOn = not isAfkOn

        if isAfkOn then
            BtnAfk.Text = "Anti-AFK: ON"
            BtnAfk.TextColor3 = C_GREEN
            BtnAfk.UIStroke.Color = C_GREEN
            afkCon = LocalPlayer.Idled:Connect(function()
                game:GetService("VirtualUser"):Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                wait(1)
                game:GetService("VirtualUser"):Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
            table.insert(Connections, afkCon)
        else
            if afkCon then
                afkCon:Disconnect()
                afkCon = nil
            end
            BtnAfk.Text = "Anti-AFK: OFF"
            BtnAfk.TextColor3 = C_TEXT_DIM
            BtnAfk.UIStroke.Color = C_TEXT_DIM
        end
    end

    BtnAfk.MouseButton1Click:Connect(function()
        ToggleAntiAFK()
    end)
    UIHandlers.ToggleAntiAFK = ToggleAntiAFK

    local BtnEmotes = Instance.new("TextButton", CardAuto)
    BtnEmotes.Text = "EMOTES MENU"
    BtnEmotes.Size = UDim2.new(0.45, 0, 0, 35)
    BtnEmotes.Position = UDim2.new(0.52, 0, 0, 35)
    StyleBtn(BtnEmotes, C_TEXT)

    BtnEmotes.MouseButton1Click:Connect(function()
        if UIHandlers.ToggleEmoteWindow then
            UIHandlers.ToggleEmoteWindow()
        end
    end)

    -- SHIFTLOCK
    local BtnSL = Instance.new("TextButton", CardAuto)
    BtnSL.Text = "SHIFT LOCK: OFF"
    BtnSL.Size = UDim2.new(0.94, 0, 0, 35)
    BtnSL.Position = UDim2.new(0.03, 0, 0, 75)
    StyleBtn(BtnSL, C_RED)

    local isSL = false
    local slLoop = nil

    local function ToggleSL(forceEnable)
        if forceEnable ~= nil then
            if forceEnable == isSL then
                return
            end
        end

        isSL = not isSL
        BtnSL.Text = isSL and "SHIFT LOCK: ON" or "SHIFT LOCK: OFF"
        BtnSL.TextColor3 = isSL and C_GREEN or C_RED
        BtnSL.UIStroke.Color = isSL and C_GREEN or C_RED

        if isSL then
            slLoop = RunService.RenderStepped:Connect(function()
                local c = LocalPlayer.Character
                local root = c and c:FindFirstChild("HumanoidRootPart")
                local hum = c and c:FindFirstChild("Humanoid")
                if root and hum then
                    hum.AutoRotate = false
                    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

                    local cam = workspace.CurrentCamera
                    local look = cam.CFrame.LookVector
                    root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
                end
            end)
            table.insert(Connections, slLoop)
        else
            if slLoop then
                slLoop:Disconnect()
                slLoop = nil
            end
            local c = LocalPlayer.Character
            local hum = c and c:FindFirstChild("Humanoid")
            if hum then
                hum.AutoRotate = true
            end
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end

    BtnSL.MouseButton1Click:Connect(function()
        ToggleSL()
    end)
    UIHandlers.ToggleShiftLock = ToggleSL

    local slKeyConnection = UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and Config.Keybinds.ToggleShiftLock and input.KeyCode == Config.Keybinds.ToggleShiftLock then
            ToggleSL()
        end
    end)

    -- Add to Connections to clean up later
    table.insert(Connections, slKeyConnection)

    -- SECURITY (Admin Detection)
    local CardSec = CreateCard("SECURITY", 85, 3)

    local BtnAntiAdmin = Instance.new("TextButton", CardSec)
    BtnAntiAdmin.Text = "BYPASS ADMIN: OFF"
    BtnAntiAdmin.Size = UDim2.new(0.9, 0, 0, 35)
    BtnAntiAdmin.Position = UDim2.new(0.05, 0, 0, 35)
    StyleBtn(BtnAntiAdmin, C_RED)

    local isAntiAdmin = false
    local adminCon = nil

    local function CheckForAdmin(player)
        if player == LocalPlayer then
            return
        end
        if not player.Parent then
            return
        end

        local isAdmin = false

        -- 1. Check Game Owner
        if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
            isAdmin = true
        elseif game.CreatorType == Enum.CreatorType.Group then
            local s, rank = pcall(function()
                if not player.Parent then
                    return 0
                end
                return player:GetRankInGroup(game.CreatorId)
            end)
            if s and rank and rank >= 100 then -- Assume Rank 100+ is staff/admin
                isAdmin = true
            end

            local s2, role = pcall(function()
                if not player.Parent then
                    return ""
                end
                return player:GetRoleInGroup(game.CreatorId)
            end)
            if s2 and role then
                local lowerRole = role:lower()
                if
                    lowerRole:find("admin")
                    or lowerRole:find("mod")
                    or lowerRole:find("staff")
                    or lowerRole:find("dev")
                    or lowerRole:find("owner")
                then
                    isAdmin = true
                end
            end
        end

        if isAdmin then
            LocalPlayer:Kick(
                "⚠️ Safety Triggered: Admin (" .. player.Name .. ") detected. Exiting to protect your account."
            )
        end
    end

    local function ToggleBypassAdmin(forceEnable)
        if forceEnable ~= nil then
            if forceEnable == isAntiAdmin then
                return
            end
        end

        isAntiAdmin = not isAntiAdmin
        BtnAntiAdmin.Text = "BYPASS ADMIN: " .. (isAntiAdmin and "ON" or "OFF")
        BtnAntiAdmin.TextColor3 = isAntiAdmin and C_GREEN or C_RED
        BtnAntiAdmin.UIStroke.Color = isAntiAdmin and C_GREEN or C_RED

        if isAntiAdmin then
            for _, p in ipairs(Players:GetPlayers()) do
                CheckForAdmin(p)
            end
            adminCon = Players.PlayerAdded:Connect(CheckForAdmin)
            table.insert(Connections, adminCon)
        else
            if adminCon then
                adminCon:Disconnect()
                adminCon = nil
            end
        end
    end

    BtnAntiAdmin.MouseButton1Click:Connect(function()
        ToggleBypassAdmin()
    end)
    UIHandlers.ToggleBypassAdmin = ToggleBypassAdmin

    -- 3. ENVIRONMENT
    local CardEnv = CreateCard("ENVIRONMENT", 110, 4)

    -- Time Slider
    local TimeVal = Instance.new("TextLabel", CardEnv)
    TimeVal.Text = "12:00"
    TimeVal.Size = UDim2.new(0, 40, 0, 20)
    TimeVal.Position = UDim2.new(0.85, 0, 0, 35)
    TimeVal.BackgroundTransparency = 1
    TimeVal.TextColor3 = C_TEXT
    TimeVal.Font = Enum.Font.GothamBold
    TimeVal.TextSize = 11

    local SldTime = Instance.new("TextButton", CardEnv)
    SldTime.Text = ""
    SldTime.Size = UDim2.new(0.75, 0, 0, 6)
    SldTime.Position = UDim2.new(0.05, 0, 0, 42)
    SldTime.BackgroundColor3 = C_SIDE
    SldTime.AutoButtonColor = false
    Instance.new("UICorner", SldTime)

    local FillTime = Instance.new("Frame", SldTime)
    FillTime.Size = UDim2.new(0.5, 0, 1, 0)
    FillTime.BackgroundColor3 = C_ACCENT
    Instance.new("UICorner", FillTime)

    local dragTime = false
    SldTime.MouseButton1Down:Connect(function()
        dragTime = true
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragTime = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragTime and i.UserInputType == Enum.UserInputType.MouseMovement then
            local sc = math.clamp((i.Position.X - SldTime.AbsolutePosition.X) / SldTime.AbsoluteSize.X, 0, 1)
            FillTime.Size = UDim2.new(sc, 0, 1, 0)
            local time = sc * 24
            local h = math.floor(time)
            local m = math.floor((time - h) * 60)
            TimeVal.Text = string.format("%02d:%02d", h, m)
            game:GetService("Lighting").ClockTime = time
        end
    end)

    -- Fullbright Toggle
    local BtnFb = Instance.new("TextButton", CardEnv)
    BtnFb.Text = "FULLBRIGHT: OFF"
    BtnFb.Size = UDim2.new(0.9, 0, 0, 35)
    BtnFb.Position = UDim2.new(0.05, 0, 0, 65)
    StyleBtn(BtnFb, C_RED)

    local isFb = false

    local function ToggleFullbright(forceEnable)
        if forceEnable ~= nil then
            if forceEnable == isFb then
                return
            end
        end

        isFb = not isFb
        BtnFb.Text = isFb and "FULLBRIGHT: ON" or "FULLBRIGHT: OFF"
        BtnFb.TextColor3 = isFb and C_GREEN or C_RED
        BtnFb.UIStroke.Color = isFb and C_GREEN or C_RED
        if isFb then
            game:GetService("Lighting").Brightness = 2
            game:GetService("Lighting").ClockTime = 14
            game:GetService("Lighting").GlobalShadows = false
            game:GetService("Lighting").OutdoorAmbient = Color3.new(1, 1, 1)
        else
            game:GetService("Lighting").Brightness = 1
            game:GetService("Lighting").GlobalShadows = true
            game:GetService("Lighting").OutdoorAmbient = Color3.fromRGB(127, 127, 127)
        end
    end

    BtnFb.MouseButton1Click:Connect(function()
        ToggleFullbright()
    end)
    UIHandlers.ToggleFullbright = ToggleFullbright

    -- 4. CUSTOM ANIMATIONS
    -- Note: Loading the AnimDB from Module here or passing it would be cleaner,
    -- but for now we will rely on the file existing or pass it in Config if needed.
    -- For this refactor, I'll load the module locally to ensure access.

    local FOLDER_NAME = "StarshipCore" -- Need this for module path
    local ModulesPath = FOLDER_NAME .. "/Modules"
    local AnimDB = {}
    if isfile(ModulesPath .. "/Animations.lua") then
        AnimDB = loadstring(readfile(ModulesPath .. "/Animations.lua"))()
    end

    local CardAnim = CreateCard("CUSTOM ANIMATIONS", 400, 4)

    local AnimStatus = Instance.new("TextLabel", CardAnim)
    AnimStatus.Text = "Status: Ready"
    AnimStatus.Size = UDim2.new(1, -20, 0, 20)
    AnimStatus.Position = UDim2.new(0, 10, 1, -25)
    AnimStatus.BackgroundTransparency = 1
    AnimStatus.TextColor3 = C_TEXT_DIM
    AnimStatus.Font = Enum.Font.Gotham
    AnimStatus.TextSize = 10
    AnimStatus.TextXAlignment = Enum.TextXAlignment.Left

    local function NotifyAnim(text)
        AnimStatus.Text = "Status: " .. text
        if UI and UI.ShowToast then
            UI.ShowToast("Animation System", text, "info", 2)
        end
    end

    local AnimScroll = Instance.new("ScrollingFrame", CardAnim)
    AnimScroll.Size = UDim2.new(1, -20, 0, 180)
    AnimScroll.Position = UDim2.new(0, 10, 0, 70)
    AnimScroll.BackgroundColor3 = C_SIDE
    AnimScroll.BorderSizePixel = 0
    AnimScroll.ScrollBarThickness = 4
    Instance.new("UICorner", AnimScroll).CornerRadius = UDim.new(0, 6)
    local AnimLayout = Instance.new("UIListLayout", AnimScroll)
    AnimLayout.Padding = UDim.new(0, 2)

    local CurrentAnimType = "Idle"
    local AnimTypes = { "Idle", "Walk", "Run", "Jump", "Fall", "Swim", "SwimIdle", "Climb" }

    local ANIM_FILE = "Starship_Animations.json"
    if isfile(ANIM_FILE) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(ANIM_FILE))
        end)
        if success and result then
            for k, v in pairs(result) do
                if AnimDB[k] then
                    for name, id in pairs(v) do
                        AnimDB[k][name] = id
                    end
                else
                    AnimDB[k] = v
                end
            end
        end
    end

    local function SaveAnimDB()
        writefile(ANIM_FILE, HttpService:JSONEncode(AnimDB))
    end

    local function GetReal(id)
        local ok, obj = pcall(function()
            return game:GetObjects("rbxassetid://" .. tostring(id))
        end)
        if ok and obj and #obj > 0 then
            local anim = obj[1]
            if anim:IsA("Animation") and anim.AnimationId ~= "" then
                return tonumber(anim.AnimationId:match("%d+")) or id
            end
        end
        return id
    end

    local OriginalAnims = {}
    local function CaptureOriginalAnims()
        local player = LocalPlayer
        local Char = player.Character or player.CharacterAdded:Wait()
        local Animate = Char:WaitForChild("Animate", 5)
        if not Animate then
            return
        end

        local function getId(obj)
            return (obj and obj:IsA("Animation")) and obj.AnimationId or nil
        end

        if not OriginalAnims.Idle then
            OriginalAnims.Idle = {
                getId(Animate:FindFirstChild("idle") and Animate.idle:FindFirstChild("Animation1")),
                getId(Animate:FindFirstChild("idle") and Animate.idle:FindFirstChild("Animation2")),
            }
        end
        if not OriginalAnims.Walk then
            OriginalAnims.Walk = getId(Animate:FindFirstChild("walk") and Animate.walk:FindFirstChild("WalkAnim"))
        end
        if not OriginalAnims.Run then
            OriginalAnims.Run = getId(Animate:FindFirstChild("run") and Animate.run:FindFirstChild("RunAnim"))
        end
        if not OriginalAnims.Jump then
            OriginalAnims.Jump = getId(Animate:FindFirstChild("jump") and Animate.jump:FindFirstChild("JumpAnim"))
        end
        if not OriginalAnims.Fall then
            OriginalAnims.Fall = getId(Animate:FindFirstChild("fall") and Animate.fall:FindFirstChild("FallAnim"))
        end
        if not OriginalAnims.Climb then
            OriginalAnims.Climb = getId(Animate:FindFirstChild("climb") and Animate.climb:FindFirstChild("ClimbAnim"))
        end
        if not OriginalAnims.Swim then
            OriginalAnims.Swim = getId(Animate:FindFirstChild("swim") and Animate.swim:FindFirstChild("Swim"))
        end
        if not OriginalAnims.SwimIdle then
            OriginalAnims.SwimIdle =
                getId(Animate:FindFirstChild("swimidle") and Animate.swimidle:FindFirstChild("SwimIdle"))
        end
    end
    task.spawn(CaptureOriginalAnims)

    local function SetAnimation(animType, animId)
        local player = LocalPlayer
        if not player.Character then
            return
        end
        local Char = player.Character
        local Animate = Char:FindFirstChild("Animate")
        if not Animate then
            return
        end

        local function freeze()
            local h = Char:FindFirstChild("Humanoid")
            if h then
                h.PlatformStand = true
            end
            for _, p in pairs(Char:GetDescendants()) do
                if p:IsA("BasePart") and not p.Anchored then
                    p.Anchored = true
                end
            end
        end
        local function unfreeze()
            local h = Char:FindFirstChild("Humanoid")
            if h then
                h.PlatformStand = false
            end
            for _, p in pairs(Char:GetDescendants()) do
                if p:IsA("BasePart") and p.Anchored then
                    p.Anchored = false
                end
            end
        end

        freeze()
        task.wait(0.1)

        local success, err = pcall(function()
            local function formatId(id)
                local s = tostring(id)
                if s:find("://") then
                    return s
                end
                return "http://www.roblox.com/asset/?id=" .. s
            end

            if animType == "Idle" then
                if type(animId) == "table" then
                    Animate.idle.Animation1.AnimationId = formatId(animId[1])
                    Animate.idle.Animation2.AnimationId = formatId(animId[2])
                else
                    Animate.idle.Animation1.AnimationId = formatId(animId)
                    Animate.idle.Animation2.AnimationId = formatId(animId)
                end
            elseif animType == "Walk" then
                Animate.walk.WalkAnim.AnimationId = formatId(animId)
            elseif animType == "Run" then
                Animate.run.RunAnim.AnimationId = formatId(animId)
            elseif animType == "Jump" then
                Animate.jump.JumpAnim.AnimationId = formatId(animId)
            elseif animType == "Fall" then
                Animate.fall.FallAnim.AnimationId = formatId(animId)
            elseif animType == "Swim" and Animate:FindFirstChild("swim") then
                Animate.swim.Swim.AnimationId = formatId(animId)
            elseif animType == "SwimIdle" and Animate:FindFirstChild("swimidle") then
                Animate.swimidle.SwimIdle.AnimationId = formatId(animId)
            elseif animType == "Climb" then
                Animate.climb.ClimbAnim.AnimationId = formatId(animId)
            end
        end)

        if not success then
            NotifyAnim("Error: " .. tostring(err))
            warn("Animation Set Error: " .. tostring(err))
        end

        local h = Char:FindFirstChild("Humanoid")
        if h then
            h:ChangeState(Enum.HumanoidStateType.Landed)
        end -- Force refresh
        task.wait(0.1)
        unfreeze()
        NotifyAnim("Set " .. animType)
    end

    local BtnType = Instance.new("TextButton", CardAnim)
    BtnType.Text = "TYPE: Idle"
    BtnType.Size = UDim2.new(0.4, 0, 0, 30)
    BtnType.Position = UDim2.new(0.03, 0, 0, 30)
    StyleBtn(BtnType, C_ACCENT)

    local InpSearch = Instance.new("TextBox", CardAnim)
    InpSearch.PlaceholderText = "Search..."
    InpSearch.Text = ""
    InpSearch.Size = UDim2.new(0.5, 0, 0, 30)
    InpSearch.Position = UDim2.new(0.46, 0, 0, 30)
    InpSearch.BackgroundColor3 = C_SIDE
    InpSearch.TextColor3 = C_TEXT
    InpSearch.Font = Enum.Font.Gotham
    InpSearch.TextSize = 12
    Instance.new("UICorner", InpSearch).CornerRadius = UDim.new(0, 4)

    local function RefreshAnimList()
        for _, c in pairs(AnimScroll:GetChildren()) do
            if c:IsA("Frame") then
                c:Destroy()
            end
        end
        local filter = InpSearch.Text:lower()
        local list = AnimDB[CurrentAnimType] or {}
        local sorted = {}
        for name, id in pairs(list) do
            table.insert(sorted, { Name = name, Id = id })
        end
        table.sort(sorted, function(a, b)
            return a.Name < b.Name
        end)

        for _, item in ipairs(sorted) do
            if filter == "" or item.Name:lower():find(filter) then
                local row = Instance.new("Frame", AnimScroll)
                row.Size = UDim2.new(1, 0, 0, 25)
                row.BackgroundTransparency = 1

                local b = Instance.new("TextButton", row)
                b.Text = "  " .. item.Name
                b.Size = UDim2.new(0.85, 0, 1, 0)
                b.BackgroundColor3 = C_ITEM
                b.TextColor3 = C_TEXT
                b.Font = Enum.Font.GothamSemibold
                b.TextSize = 11
                b.TextXAlignment = Enum.TextXAlignment.Left
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
                b.MouseButton1Click:Connect(function()
                    SetAnimation(CurrentAnimType, item.Id)
                end)

                RegisterTheme(b, "BackgroundColor3", "Item")
                RegisterTheme(b, "TextColor3", "Text")

                local del = Instance.new("TextButton", row)
                del.Text = "X"
                del.Size = UDim2.new(0.12, 0, 1, 0)
                del.Position = UDim2.new(0.88, 0, 0, 0)
                del.BackgroundColor3 = C_ITEM
                del.TextColor3 = C_RED
                del.Font = Enum.Font.GothamBold
                del.TextSize = 11
                Instance.new("UICorner", del).CornerRadius = UDim.new(0, 4)

                RegisterTheme(del, "BackgroundColor3", "Item")

                del.MouseButton1Click:Connect(function()
                    AnimDB[CurrentAnimType][item.Name] = nil
                    SaveAnimDB()
                    RefreshAnimList()
                    NotifyAnim("Deleted: " .. item.Name)
                end)
            end
        end
        AnimScroll.CanvasSize = UDim2.new(0, 0, 0, #AnimScroll:GetChildren() * 27)
    end

    BtnType.MouseButton1Click:Connect(function()
        local idx = table.find(AnimTypes, CurrentAnimType) or 1
        idx = (idx % #AnimTypes) + 1
        CurrentAnimType = AnimTypes[idx]
        BtnType.Text = "TYPE: " .. CurrentAnimType
        RefreshAnimList()
    end)

    InpSearch:GetPropertyChangedSignal("Text"):Connect(RefreshAnimList)
    RefreshAnimList()

    -- Add Custom Animation UI
    local InpName = Instance.new("TextBox", CardAnim)
    InpName.PlaceholderText = "Anim Name..."
    InpName.Text = ""
    InpName.Size = UDim2.new(0.45, 0, 0, 30)
    InpName.Position = UDim2.new(0.03, 0, 0, 260)
    InpName.BackgroundColor3 = C_SIDE
    InpName.TextColor3 = C_TEXT
    InpName.Font = Enum.Font.Gotham
    InpName.TextSize = 11
    Instance.new("UICorner", InpName).CornerRadius = UDim.new(0, 4)

    local InpID = Instance.new("TextBox", CardAnim)
    InpID.PlaceholderText = "Asset ID / URL..."
    InpID.Text = ""
    InpID.Size = UDim2.new(0.45, 0, 0, 30)
    InpID.Position = UDim2.new(0.50, 0, 0, 260)
    InpID.BackgroundColor3 = C_SIDE
    InpID.TextColor3 = C_TEXT
    InpID.Font = Enum.Font.Gotham
    InpID.TextSize = 11
    Instance.new("UICorner", InpID).CornerRadius = UDim.new(0, 4)

    local BtnAddAnim = Instance.new("TextButton", CardAnim)
    BtnAddAnim.Text = "ADD / APPLY ANIMATION"
    BtnAddAnim.Size = UDim2.new(0.92, 0, 0, 30)
    BtnAddAnim.Position = UDim2.new(0.03, 0, 0, 300)
    StyleBtn(BtnAddAnim, C_GREEN)

    local function ExtractId(str)
        if str:find("rbxassetid://") then
            return str
        end
        local num = str:match("(%d+)")
        if str:find("roblox.com") then
            num = str:match("library/(%d+)") or str:match("catalog/(%d+)") or str:match("id=(%d+)") or num
        end
        return num
    end

    BtnAddAnim.MouseButton1Click:Connect(function()
        local rawID = InpID.Text
        local name = InpName.Text

        if rawID == "" then
            NotifyAnim("ID Required!")
            return
        end

        local finalID = nil
        if rawID:find(",") then
            local ids = {}
            for part in string.gmatch(rawID, "([^,]+)") do
                local clean = ExtractId(part)
                if clean then
                    local real = GetReal(clean)
                    table.insert(ids, real)
                end
            end
            if #ids > 0 then
                finalID = ids
            end
        else
            local clean = ExtractId(rawID)
            if clean then
                finalID = GetReal(clean)
            end
        end

        if not finalID then
            NotifyAnim("Invalid ID Format")
            return
        end

        if name == "" then
            name = "Custom_" .. (type(finalID) == "table" and finalID[1] or finalID)
        end

        SetAnimation(CurrentAnimType, finalID)

        if not AnimDB[CurrentAnimType] then
            AnimDB[CurrentAnimType] = {}
        end
        AnimDB[CurrentAnimType][name] = finalID
        SaveAnimDB()

        RefreshAnimList()
        NotifyAnim("Added: " .. name)
        InpName.Text = ""
        InpID.Text = ""
    end)

    local BtnReset = Instance.new("TextButton", CardAnim)
    BtnReset.Text = "RESET TO ORIGINAL"
    BtnReset.Size = UDim2.new(0.92, 0, 0, 30)
    BtnReset.Position = UDim2.new(0.03, 0, 0, 340)
    StyleBtn(BtnReset, C_RED)

    BtnReset.MouseButton1Click:Connect(function()
        local orig = OriginalAnims[CurrentAnimType]
        if orig then
            SetAnimation(CurrentAnimType, orig)
            NotifyAnim("Reset to Original")
        else
            NotifyAnim("Original Not Found")
        end
    end)

    -- 5. SERVER
    local CardSrv = CreateCard("SERVER", 75, 5)
    local BtnBrowser = Instance.new("TextButton", CardSrv)
    BtnBrowser.Text = "BROWSER"
    BtnBrowser.Size = UDim2.new(0.45, 0, 0, 35)
    BtnBrowser.Position = UDim2.new(0.03, 0, 0, 35)
    StyleBtn(BtnBrowser, C_ACCENT)

    local BtnRejoin = Instance.new("TextButton", CardSrv)
    BtnRejoin.Text = "REJOIN"
    BtnRejoin.Size = UDim2.new(0.45, 0, 0, 35)
    BtnRejoin.Position = UDim2.new(0.52, 0, 0, 35)
    StyleBtn(BtnRejoin, C_RED)

    -- SBrowser logic
    local ScreenGui = PageTools.Parent.Parent

    local SBrowser = Instance.new("Frame", ScreenGui)
    SBrowser.Name = "SBrowser"
    SBrowser.Size = UDim2.new(0, 500, 0, 350)
    SBrowser.Position = UDim2.new(0.5, -250, 0.5, -175)
    SBrowser.BackgroundColor3 = C_SIDE
    SBrowser.Visible = false
    SBrowser.ZIndex = 100
    Instance.new("UICorner", SBrowser).CornerRadius = UDim.new(0, 12)
    local SBS = Instance.new("UIStroke", SBrowser)
    SBS.Color = C_ACCENT
    SBS.Thickness = 1
    RegisterTheme(SBrowser, "BackgroundColor3", "Side")
    RegisterTheme(SBS, "Color", "Accent")

    local SBTitle = Instance.new("TextLabel", SBrowser)
    SBTitle.Text = "SERVER LIST"
    SBTitle.Size = UDim2.new(1, 0, 0, 40)
    SBTitle.Position = UDim2.new(0, 20, 0, 0)
    SBTitle.BackgroundTransparency = 1
    SBTitle.TextColor3 = C_TEXT
    SBTitle.Font = Enum.Font.GothamBold
    SBTitle.TextSize = 18
    SBTitle.TextXAlignment = Enum.TextXAlignment.Left
    SBTitle.ZIndex = 101
    SBTitle.Active = true
    RegisterTheme(SBTitle, "TextColor3", "Text")

    local SBClose = Instance.new("TextButton", SBrowser)
    SBClose.Text = "×"
    SBClose.Size = UDim2.new(0, 40, 0, 40)
    SBClose.Position = UDim2.new(1, -40, 0, 0)
    SBClose.BackgroundTransparency = 1
    SBClose.TextColor3 = C_RED
    SBClose.TextSize = 24
    SBClose.ZIndex = 101
    SBClose.MouseButton1Click:Connect(function()
        SBrowser.Visible = false
    end)

    local SBList = Instance.new("ScrollingFrame", SBrowser)
    SBList.Size = UDim2.new(1, -20, 1, -60)
    SBList.Position = UDim2.new(0, 10, 0, 50)
    SBList.BackgroundColor3 = C_MAIN
    SBList.BackgroundTransparency = 0.5
    SBList.BorderSizePixel = 0
    SBList.ScrollBarThickness = 4
    SBList.ZIndex = 101
    Instance.new("UICorner", SBList).CornerRadius = UDim.new(0, 6)
    local SBLay = Instance.new("UIListLayout", SBList)
    SBLay.Padding = UDim.new(0, 5)
    RegisterTheme(SBList, "BackgroundColor3", "Main")

    local SBStat = Instance.new("TextLabel", SBrowser)
    SBStat.Text = "Fetching..."
    SBStat.Size = UDim2.new(1, 0, 1, 0)
    SBStat.BackgroundTransparency = 1
    SBStat.TextColor3 = C_TEXT_DIM
    SBStat.Visible = false
    SBStat.ZIndex = 102
    RegisterTheme(SBStat, "TextColor3", "TextDim")
    local dragging, dragInput, dragStart, startPos
    SBTitle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = SBrowser.Position
        end
    end)
    SBTitle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            SBrowser.Position =
                UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    local function RefreshServers()
        for _, c in pairs(SBList:GetChildren()) do
            if c:IsA("Frame") then
                c:Destroy()
            end
        end
        SBStat.Visible = true
        SBStat.Text = "Fetching Servers..."
        SBList.Visible = false
        task.spawn(function()
            local url = "https://games.roblox.com/v1/games/"
                .. game.PlaceId
                .. "/servers/Public?limit=100&sortOrder=Desc"
            local s, r = pcall(function()
                return game:HttpGet(url)
            end)
            if s then
                local d = HttpService:JSONDecode(r)
                if d and d.data then
                    if #d.data == 0 then
                        SBStat.Text = "No servers found."
                        SBStat.Visible = true
                        return
                    end
                    for i, sv in ipairs(d.data) do
                        if sv.playing < sv.maxPlayers and sv.id ~= game.JobId then
                            local f = Instance.new("Frame", SBList)
                            f.Size = UDim2.new(1, -6, 0, 40)
                            f.BackgroundColor3 = C_ITEM
                            f.ZIndex = 101
                            Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
                            RegisterTheme(f, "BackgroundColor3", "Item")

                            local inf = Instance.new("TextLabel", f)
                            inf.Text = string.format(
                                "%d/%d Players | %d FPS | %d Ping",
                                sv.playing,
                                sv.maxPlayers,
                                sv.fps or 60,
                                sv.ping or 0
                            )
                            inf.Size = UDim2.new(0.7, 0, 1, 0)
                            inf.Position = UDim2.new(0, 10, 0, 0)
                            inf.BackgroundTransparency = 1
                            inf.TextColor3 = C_TEXT
                            inf.TextXAlignment = Enum.TextXAlignment.Left
                            inf.Font = Enum.Font.GothamSemibold
                            inf.TextSize = 12
                            inf.ZIndex = 101
                            RegisterTheme(inf, "TextColor3", "Text")

                            local bj = Instance.new("TextButton", f)
                            bj.Text = "JOIN"
                            bj.Size = UDim2.new(0.25, 0, 0.8, 0)
                            bj.Position = UDim2.new(0.72, 0, 0.1, 0)
                            bj.BackgroundColor3 = C_GREEN
                            bj.TextColor3 = Color3.new(1, 1, 1)
                            bj.Font = Enum.Font.GothamBold
                            bj.TextSize = 11
                            bj.ZIndex = 101
                            Instance.new("UICorner", bj).CornerRadius = UDim.new(0, 4)
                            bj.MouseButton1Click:Connect(function()
                                game:GetService("TeleportService")
                                    :TeleportToPlaceInstance(game.PlaceId, sv.id, LocalPlayer)
                            end)
                        end
                    end
                    SBList.CanvasSize = UDim2.new(0, 0, 0, #SBList:GetChildren() * 45)
                    SBStat.Visible = false
                    SBList.Visible = true
                else
                    SBStat.Text = "Invalid Data."
                    SBStat.Visible = true
                end
            else
                SBStat.Text = "Error: " .. tostring(r)
                SBStat.Visible = true
            end
        end)
    end

    BtnBrowser.MouseButton1Click:Connect(function()
        SBrowser.Visible = true
        RefreshServers()
    end)
    BtnRejoin.MouseButton1Click:Connect(function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end)

    -- 6. RECORDING TOOLS (New Feature)
    local CardRecTools = CreateCard("RECORDING TOOLS", 180, 6) -- Increased height for new option

    -- Description
    local LblSmooth = Instance.new("TextLabel", CardRecTools)
    LblSmooth.Text = "LIVE SMOOTHING (AUTO)"
    LblSmooth.Size = UDim2.new(1, -20, 0, 20)
    LblSmooth.Position = UDim2.new(0, 15, 0, 35)
    LblSmooth.BackgroundTransparency = 1
    LblSmooth.TextColor3 = C_TEXT
    LblSmooth.Font = Enum.Font.GothamBold
    LblSmooth.TextSize = 11
    LblSmooth.TextXAlignment = Enum.TextXAlignment.Left

    -- Strength Slider
    local LblStr = Instance.new("TextLabel", CardRecTools)
    LblStr.Text = "STRENGTH: 4"
    LblStr.Size = UDim2.new(0, 80, 0, 20)
    LblStr.Position = UDim2.new(0.75, 0, 0, 35)
    LblStr.BackgroundTransparency = 1
    LblStr.TextColor3 = C_TEXT_DIM
    LblStr.Font = Enum.Font.Gotham
    LblStr.TextSize = 10
    LblStr.TextXAlignment = Enum.TextXAlignment.Right

    local SldStrBg = Instance.new("TextButton", CardRecTools)
    SldStrBg.Text = ""
    SldStrBg.Size = UDim2.new(0.9, 0, 0, 6)
    SldStrBg.Position = UDim2.new(0.05, 0, 0, 60)
    SldStrBg.BackgroundColor3 = C_SIDE
    SldStrBg.AutoButtonColor = false
    Instance.new("UICorner", SldStrBg).CornerRadius = UDim.new(0, 3)

    local SldStrFill = Instance.new("Frame", SldStrBg)
    SldStrFill.Size = UDim2.new(0.4, 0, 1, 0) -- Default 4/10
    SldStrFill.BackgroundColor3 = C_ACCENT
    Instance.new("UICorner", SldStrFill).CornerRadius = UDim.new(0, 3)

    local smoothStrength = 4
    local isLiveSmooth = false
    local draggingStr = false

    local function UpdateSmoothHandler()
        if UIHandlers.SetLiveSmoothing then
            UIHandlers.SetLiveSmoothing(isLiveSmooth, smoothStrength)
        end
    end

    SldStrBg.MouseButton1Down:Connect(function()
        draggingStr = true
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingStr = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if draggingStr and i.UserInputType == Enum.UserInputType.MouseMovement then
            local rx = i.Position.X - SldStrBg.AbsolutePosition.X
            local sc = math.clamp(rx / SldStrBg.AbsoluteSize.X, 0, 1)
            smoothStrength = math.max(1, math.floor(sc * 10))
            SldStrFill.Size = UDim2.new(sc, 0, 1, 0)
            LblStr.Text = "STRENGTH: " .. smoothStrength
            UpdateSmoothHandler()
        end
    end)

    local BtnToggleSmooth = Instance.new("TextButton", CardRecTools)
    BtnToggleSmooth.Text = "LIVE SMOOTH: OFF"
    BtnToggleSmooth.Size = UDim2.new(0.43, 0, 0, 30)
    BtnToggleSmooth.Position = UDim2.new(0.05, 0, 0, 80)
    StyleBtn(BtnToggleSmooth, C_RED)

    BtnToggleSmooth.MouseButton1Click:Connect(function()
        isLiveSmooth = not isLiveSmooth
        BtnToggleSmooth.Text = "LIVE SMOOTH: " .. (isLiveSmooth and "ON" or "OFF")
        BtnToggleSmooth.TextColor3 = isLiveSmooth and C_GREEN or C_RED
        BtnToggleSmooth.UIStroke.Color = isLiveSmooth and C_GREEN or C_RED
        UpdateSmoothHandler()
    end)

    -- Position-Based Playback Toggle (smoother ground movement)
    local isPosBased = UIHandlers.GetPositionBasedPlayback and UIHandlers.GetPositionBasedPlayback() or true
    local BtnPosBased = Instance.new("TextButton", CardRecTools)
    BtnPosBased.Text = "POS-BASED: " .. (isPosBased and "ON" or "OFF")
    BtnPosBased.Size = UDim2.new(0.43, 0, 0, 30)
    BtnPosBased.Position = UDim2.new(0.52, 0, 0, 80)
    StyleBtn(BtnPosBased, isPosBased and C_GREEN or C_RED)

    BtnPosBased.MouseButton1Click:Connect(function()
        isPosBased = not isPosBased
        BtnPosBased.Text = "POS-BASED: " .. (isPosBased and "ON" or "OFF")
        BtnPosBased.TextColor3 = isPosBased and C_GREEN or C_RED
        BtnPosBased.UIStroke.Color = isPosBased and C_GREEN or C_RED
        if UIHandlers.SetPositionBasedPlayback then
            UIHandlers.SetPositionBasedPlayback(isPosBased)
        end
    end)

    -- Description for Position-Based
    local LblPosBasedDesc = Instance.new("TextLabel", CardRecTools)
    LblPosBasedDesc.Text = "POS-BASED: Smoother ground movement (follows path directly)"
    LblPosBasedDesc.Size = UDim2.new(1, -20, 0, 15)
    LblPosBasedDesc.Position = UDim2.new(0, 10, 0, 115)
    LblPosBasedDesc.BackgroundTransparency = 1
    LblPosBasedDesc.TextColor3 = C_TEXT_DIM
    LblPosBasedDesc.Font = Enum.Font.Gotham
    LblPosBasedDesc.TextSize = 9
    LblPosBasedDesc.TextXAlignment = Enum.TextXAlignment.Left

    -- Manual Apply Button (Small, under toggle)
    local BtnManual = Instance.new("TextButton", CardRecTools)
    BtnManual.Text = "Manual Apply (Permanent)"
    BtnManual.Size = UDim2.new(0.9, 0, 0, 25)
    BtnManual.Position = UDim2.new(0.05, 0, 0, 140)
    BtnManual.BackgroundTransparency = 1
    BtnManual.TextColor3 = C_TEXT_DIM
    BtnManual.Font = Enum.Font.Gotham
    BtnManual.TextSize = 10

    BtnManual.MouseButton1Click:Connect(function()
        if UIHandlers.SmoothRecording then
            UIHandlers.SmoothRecording(smoothStrength)
        end
    end)

    -- 7. PRIVACY / STREAMER MODE
    local CardPrivacy = CreateCard("PRIVACY (STREAMER MODE)", 180, 7)

    local LblPrivacy = Instance.new("TextLabel", CardPrivacy)
    LblPrivacy.Text = "Spoof your name for streaming/screenshots (CLIENT-SIDE ONLY - only you see the fake name)"
    LblPrivacy.Size = UDim2.new(1, -20, 0, 20)
    LblPrivacy.Position = UDim2.new(0, 10, 0, 28)
    LblPrivacy.BackgroundTransparency = 1
    LblPrivacy.TextColor3 = C_TEXT_DIM
    LblPrivacy.Font = Enum.Font.Gotham
    LblPrivacy.TextSize = 9
    LblPrivacy.TextXAlignment = Enum.TextXAlignment.Left

    local InpSpoofName = Instance.new("TextBox", CardPrivacy)
    InpSpoofName.PlaceholderText = "Fake Username..."
    InpSpoofName.Text = ""
    InpSpoofName.Size = UDim2.new(0.45, 0, 0, 30)
    InpSpoofName.Position = UDim2.new(0.03, 0, 0, 50)
    InpSpoofName.BackgroundColor3 = C_SIDE
    InpSpoofName.TextColor3 = C_TEXT
    InpSpoofName.Font = Enum.Font.Gotham
    InpSpoofName.TextSize = 11
    Instance.new("UICorner", InpSpoofName).CornerRadius = UDim.new(0, 6)

    local InpSpoofDisplay = Instance.new("TextBox", CardPrivacy)
    InpSpoofDisplay.PlaceholderText = "Fake Display Name..."
    InpSpoofDisplay.Text = ""
    InpSpoofDisplay.Size = UDim2.new(0.45, 0, 0, 30)
    InpSpoofDisplay.Position = UDim2.new(0.52, 0, 0, 50)
    InpSpoofDisplay.BackgroundColor3 = C_SIDE
    InpSpoofDisplay.TextColor3 = C_TEXT
    InpSpoofDisplay.Font = Enum.Font.Gotham
    InpSpoofDisplay.TextSize = 11
    Instance.new("UICorner", InpSpoofDisplay).CornerRadius = UDim.new(0, 6)

    local BtnSpoof = Instance.new("TextButton", CardPrivacy)
    BtnSpoof.Text = "SPOOF: OFF"
    BtnSpoof.Size = UDim2.new(0.94, 0, 0, 35)
    BtnSpoof.Position = UDim2.new(0.03, 0, 0, 90)
    StyleBtn(BtnSpoof, C_RED)

    local isSpoofing = false
    local spoofConnections = {}
    local originalTexts = {}

    local function SpoofAllNames()
        local fakeName = InpSpoofName.Text ~= "" and InpSpoofName.Text or "Player"
        local fakeDisplay = InpSpoofDisplay.Text ~= "" and InpSpoofDisplay.Text or fakeName
        local realName = LocalPlayer.Name
        local realDisplay = LocalPlayer.DisplayName

        -- Update StarshipCore Main UI Dashboard and Profile
        if UIHandlers.UpdateSpoofedName then
            UIHandlers.UpdateSpoofedName(fakeName, fakeDisplay)
        end

        -- Spoof PlayerGui elements
        local function SpoofGui(gui)
            if not gui then
                return
            end
            for _, obj in pairs(gui:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    local text = obj.Text
                    if text and (text:find(realName) or text:find(realDisplay)) then
                        if not originalTexts[obj] then
                            originalTexts[obj] = text
                        end
                        obj.Text = text:gsub(realName, fakeName):gsub(realDisplay, fakeDisplay)
                    end
                end
            end
        end

        -- Spoof BillboardGuis (nametags above heads)
        local function SpoofCharacter(character)
            if not character then
                return
            end
            for _, obj in pairs(character:GetDescendants()) do
                if obj:IsA("BillboardGui") then
                    for _, child in pairs(obj:GetDescendants()) do
                        if child:IsA("TextLabel") or child:IsA("TextButton") then
                            local text = child.Text
                            if text and (text:find(realName) or text:find(realDisplay)) then
                                if not originalTexts[child] then
                                    originalTexts[child] = text
                                end
                                child.Text = text:gsub(realName, fakeName):gsub(realDisplay, fakeDisplay)
                            end
                        end
                    end
                end
            end
        end

        -- Spoof CoreGui if accessible
        pcall(function()
            local playerList = game:GetService("CoreGui"):FindFirstChild("PlayerList")
            if playerList then
                SpoofGui(playerList)
            end
        end)

        -- Spoof PlayerGui
        if LocalPlayer:FindFirstChild("PlayerGui") then
            SpoofGui(LocalPlayer.PlayerGui)
        end

        -- Spoof character nametags
        if LocalPlayer.Character then
            SpoofCharacter(LocalPlayer.Character)
        end

        -- Spoof all workspace BillboardGuis that might show our name
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BillboardGui") then
                for _, child in pairs(obj:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("TextButton") then
                        local text = child.Text
                        if text and (text:find(realName) or text:find(realDisplay)) then
                            if not originalTexts[child] then
                                originalTexts[child] = text
                            end
                            child.Text = text:gsub(realName, fakeName):gsub(realDisplay, fakeDisplay)
                        end
                    end
                end
            end
        end
    end

    local function RestoreAllNames()
        for obj, text in pairs(originalTexts) do
            if obj and obj.Parent then
                pcall(function()
                    obj.Text = text
                end)
            end
        end
        originalTexts = {}

        -- Restore StarshipCore Main UI to real name
        if UIHandlers.UpdateSpoofedName then
            UIHandlers.UpdateSpoofedName(LocalPlayer.Name, LocalPlayer.DisplayName)
        end
    end

    local function ToggleSpoof()
        isSpoofing = not isSpoofing
        BtnSpoof.Text = "SPOOF: " .. (isSpoofing and "ON" or "OFF")
        BtnSpoof.TextColor3 = isSpoofing and C_GREEN or C_RED
        BtnSpoof.UIStroke.Color = isSpoofing and C_GREEN or C_RED

        if isSpoofing then
            -- Initial spoof
            SpoofAllNames()

            -- Keep spoofing on changes (Optimized: every 1 second)
            local lastSpoof = 0
            local spoofLoop = RunService.Heartbeat:Connect(function()
                if isSpoofing and tick() - lastSpoof > 1 then
                    lastSpoof = tick()
                    SpoofAllNames()
                end
            end)
            table.insert(spoofConnections, spoofLoop)
            table.insert(Connections, spoofLoop)

            -- Spoof on character added
            local charCon = LocalPlayer.CharacterAdded:Connect(function(char)
                task.wait(1)
                if isSpoofing then
                    SpoofAllNames()
                end
            end)
            table.insert(spoofConnections, charCon)
            table.insert(Connections, charCon)
        else
            -- Disconnect all spoof connections
            for _, con in pairs(spoofConnections) do
                if con then
                    pcall(function()
                        con:Disconnect()
                    end)
                end
            end
            spoofConnections = {}

            -- Restore original names
            RestoreAllNames()
        end
    end

    BtnSpoof.MouseButton1Click:Connect(ToggleSpoof)

    -- Expose spoof state and data to UIHandlers
    UIHandlers.GetSpoofedName = function()
        if isSpoofing then
            local fakeName = InpSpoofName.Text ~= "" and InpSpoofName.Text or "Player"
            local fakeDisplay = InpSpoofDisplay.Text ~= "" and InpSpoofDisplay.Text or fakeName
            return fakeName, fakeDisplay, true
        else
            return LocalPlayer.Name, LocalPlayer.DisplayName, false
        end
    end

    -- Quick presets
    local BtnRandom = Instance.new("TextButton", CardPrivacy)
    BtnRandom.Text = "RANDOM NAME"
    BtnRandom.Size = UDim2.new(0.45, 0, 0, 30)
    BtnRandom.Position = UDim2.new(0.03, 0, 0, 135)
    StyleBtn(BtnRandom, C_ACCENT)

    local randomNames = {
        "Steve",
        "Alex",
        "ProGamer",
        "Noob123",
        "Player",
        "Guest",
        "Anonymous",
        "Shadow",
        "Phoenix",
        "Dragon",
        "Ninja",
        "Master",
        "Legend",
        "Hero",
        "Star",
    }
    local randomNumbers = { "123", "456", "789", "007", "999", "101", "XD", "_YT", "_TTV", "" }

    BtnRandom.MouseButton1Click:Connect(function()
        local name = randomNames[math.random(#randomNames)] .. randomNumbers[math.random(#randomNumbers)]
        InpSpoofName.Text = name
        InpSpoofDisplay.Text = name
        if isSpoofing then
            SpoofAllNames()
        end
    end)

    local BtnClear = Instance.new("TextButton", CardPrivacy)
    BtnClear.Text = "CLEAR"
    BtnClear.Size = UDim2.new(0.45, 0, 0, 30)
    BtnClear.Position = UDim2.new(0.52, 0, 0, 135)
    StyleBtn(BtnClear, C_TEXT_DIM)

    BtnClear.MouseButton1Click:Connect(function()
        InpSpoofName.Text = ""
        InpSpoofDisplay.Text = ""
        if isSpoofing then
            ToggleSpoof() -- Turn off spoofing
        end
    end)

    -- 8. PLAYERS (Hide Players Feature)
    local CardPlayers = CreateCard("PLAYERS", 85, 8)

    local BtnHidePlayers = Instance.new("TextButton", CardPlayers)
    BtnHidePlayers.Text = "HIDE ALL PLAYERS: OFF"
    BtnHidePlayers.Size = UDim2.new(0.94, 0, 0, 35)
    BtnHidePlayers.Position = UDim2.new(0.03, 0, 0, 35)
    StyleBtn(BtnHidePlayers, C_RED)

    local isHidePlayers = false
    local hiddenPlayers = {}
    local playerAddedCon = nil

    local function HidePlayer(player)
        if player == LocalPlayer then
            return
        end
        local character = player.Character
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("Decal") then
                    if not hiddenPlayers[part] then
                        hiddenPlayers[part] = part.Transparency
                    end
                    part.Transparency = 1
                elseif part:IsA("BillboardGui") or part:IsA("SurfaceGui") then
                    if not hiddenPlayers[part] then
                        hiddenPlayers[part] = part.Enabled
                    end
                    part.Enabled = false
                end
            end
        end
    end

    local function ShowPlayer(player)
        if player == LocalPlayer then
            return
        end
        local character = player.Character
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if hiddenPlayers[part] ~= nil then
                    if part:IsA("BasePart") or part:IsA("Decal") then
                        part.Transparency = hiddenPlayers[part]
                    elseif part:IsA("BillboardGui") or part:IsA("SurfaceGui") then
                        part.Enabled = hiddenPlayers[part]
                    end
                    hiddenPlayers[part] = nil
                end
            end
        end
    end

    local function ToggleHidePlayers()
        isHidePlayers = not isHidePlayers
        BtnHidePlayers.Text = "HIDE ALL PLAYERS: " .. (isHidePlayers and "ON" or "OFF")
        BtnHidePlayers.TextColor3 = isHidePlayers and C_GREEN or C_RED
        BtnHidePlayers.UIStroke.Color = isHidePlayers and C_GREEN or C_RED

        if isHidePlayers then
            -- Hide all current players
            for _, player in pairs(Players:GetPlayers()) do
                HidePlayer(player)

                -- Also listen for character respawns
                player.CharacterAdded:Connect(function()
                    if isHidePlayers then
                        task.wait(0.5) -- Wait for character to fully load
                        HidePlayer(player)
                    end
                end)
            end

            -- Listen for new players joining
            playerAddedCon = Players.PlayerAdded:Connect(function(player)
                player.CharacterAdded:Connect(function()
                    if isHidePlayers then
                        task.wait(0.5)
                        HidePlayer(player)
                    end
                end)
            end)
            table.insert(Connections, playerAddedCon)
        else
            -- Show all players
            for _, player in pairs(Players:GetPlayers()) do
                ShowPlayer(player)
            end
            hiddenPlayers = {}

            if playerAddedCon then
                playerAddedCon:Disconnect()
                playerAddedCon = nil
            end
        end
    end

    BtnHidePlayers.MouseButton1Click:Connect(ToggleHidePlayers)

    -- 9. SKYBOX CHANGER
    local CardSkybox = CreateCard("🌌 SKYBOX CHANGER", 140, 9)

    local originalSky = nil
    local originalAtmosphere = nil
    local currentSkybox = "Default"
    local skyboxConnection = nil -- For bypass protection loop

    -- Skybox Presets (VERIFIED WORKING)
    local SkyboxPresets = {
        ["Default"] = nil, -- Will restore original

        ["Galaxy Night"] = {
            -- Verified working
            SkyboxBk = "rbxassetid://159454286",
            SkyboxDn = "rbxassetid://159454296",
            SkyboxFt = "rbxassetid://159454299",
            SkyboxLf = "rbxassetid://159454286",
            SkyboxRt = "rbxassetid://159454291",
            SkyboxUp = "rbxassetid://159454293",
            StarCount = 5000,
        },
        ["Blood Red"] = {
            -- Verified working
            SkyboxBk = "rbxassetid://1012890",
            SkyboxDn = "rbxassetid://1012891",
            SkyboxFt = "rbxassetid://1012887",
            SkyboxLf = "rbxassetid://1012889",
            SkyboxRt = "rbxassetid://1012888",
            SkyboxUp = "rbxassetid://1014449",
            StarCount = 500,
            Ambient = Color3.fromRGB(80, 20, 20),
        },
        ["Scary Red"] = {
            -- Verified working
            SkyboxBk = "rbxassetid://108929045660200",
            SkyboxDn = "rbxassetid://78646480540009",
            SkyboxFt = "rbxassetid://90546017435179",
            SkyboxLf = "rbxassetid://109838453114563",
            SkyboxRt = "rbxassetid://94190734796082",
            SkyboxUp = "rbxassetid://126944775797063",
        },
        ["Skybox HD"] = {
            -- Verified working - HD quality skybox
            SkyboxBk = "rbxassetid://16553658937",
            SkyboxDn = "rbxassetid://16553660713",
            SkyboxFt = "rbxassetid://16553662144",
            SkyboxLf = "rbxassetid://16553664042",
            SkyboxRt = "rbxassetid://16553665766",
            SkyboxUp = "rbxassetid://16553667750",
            StarCount = 3000,
        },
        ["Night City"] = {
            -- Verified working - City night skybox
            SkyboxBk = "rbxassetid://163897885",
            SkyboxDn = "rbxassetid://163898013",
            SkyboxFt = "rbxassetid://163899342",
            SkyboxLf = "rbxassetid://163897886",
            SkyboxRt = "rbxassetid://163897887",
            SkyboxUp = "rbxassetid://163898013",
            StarCount = 5000,
        },
    }

    local presetOrder = { "Default", "Galaxy Night", "Blood Red", "Scary Red", "Skybox HD", "Night City" }

    -- Capture original sky on first load
    local function CaptureOriginalSky()
        if originalSky then return end
        local lighting = game:GetService("Lighting")
        local existingSky = lighting:FindFirstChildOfClass("Sky")
        if existingSky then
            originalSky = {
                SkyboxBk = existingSky.SkyboxBk,
                SkyboxDn = existingSky.SkyboxDn,
                SkyboxFt = existingSky.SkyboxFt,
                SkyboxLf = existingSky.SkyboxLf,
                SkyboxRt = existingSky.SkyboxRt,
                SkyboxUp = existingSky.SkyboxUp,
                StarCount = existingSky.StarCount,
                SunAngularSize = existingSky.SunAngularSize,
                MoonAngularSize = existingSky.MoonAngularSize,
            }
        end
        originalAtmosphere = lighting.Ambient
    end

    -- Stop any existing skybox bypass loop
    local function StopSkyboxBypass()
        if skyboxConnection then
            skyboxConnection:Disconnect()
            skyboxConnection = nil
        end
    end

    -- Apply skybox with bypass protection (Heartbeat loop)
    local function ApplySkyboxWithBypass(preset)
        local lighting = game:GetService("Lighting")

        skyboxConnection = RunService.Heartbeat:Connect(function()
            for _, child in pairs(lighting:GetChildren()) do
                if child:IsA("Sky") then
                    child.SkyboxBk = preset.SkyboxBk
                    child.SkyboxDn = preset.SkyboxDn
                    child.SkyboxFt = preset.SkyboxFt
                    child.SkyboxLf = preset.SkyboxLf
                    child.SkyboxRt = preset.SkyboxRt
                    child.SkyboxUp = preset.SkyboxUp
                    child.StarCount = preset.StarCount or 0
                end
            end
            if preset.Ambient then
                lighting.Ambient = preset.Ambient
            end
        end)
    end

    local function ApplySkybox(presetName)
        local lighting = game:GetService("Lighting")
        CaptureOriginalSky()
        StopSkyboxBypass() -- Stop previous bypass loop

        local preset = SkyboxPresets[presetName]

        if presetName == "Default" then
            -- Restore original
            local sky = lighting:FindFirstChildOfClass("Sky")
            if sky and originalSky then
                sky.SkyboxBk = originalSky.SkyboxBk
                sky.SkyboxDn = originalSky.SkyboxDn
                sky.SkyboxFt = originalSky.SkyboxFt
                sky.SkyboxLf = originalSky.SkyboxLf
                sky.SkyboxRt = originalSky.SkyboxRt
                sky.SkyboxUp = originalSky.SkyboxUp
                sky.StarCount = originalSky.StarCount
            end
            if originalAtmosphere then
                lighting.Ambient = originalAtmosphere
            end
            currentSkybox = "Default"
            return
        end

        if not preset then return end

        -- Find or create Sky object
        local sky = lighting:FindFirstChildOfClass("Sky")
        if not sky then
            sky = Instance.new("Sky", lighting)
        end

        -- Apply preset once first
        sky.SkyboxBk = preset.SkyboxBk
        sky.SkyboxDn = preset.SkyboxDn
        sky.SkyboxFt = preset.SkyboxFt
        sky.SkyboxLf = preset.SkyboxLf
        sky.SkyboxRt = preset.SkyboxRt
        sky.SkyboxUp = preset.SkyboxUp
        sky.StarCount = preset.StarCount or 0

        if preset.Ambient then
            lighting.Ambient = preset.Ambient
        end

        -- Start bypass protection loop
        ApplySkyboxWithBypass(preset)

        currentSkybox = presetName
    end

    -- Status Label
    local SkyboxStatus = Instance.new("TextLabel", CardSkybox)
    SkyboxStatus.Text = "Current: Default"
    SkyboxStatus.Size = UDim2.new(0.94, 0, 0, 20)
    SkyboxStatus.Position = UDim2.new(0.03, 0, 0, 30)
    SkyboxStatus.BackgroundTransparency = 1
    SkyboxStatus.TextColor3 = C_TEXT_DIM
    SkyboxStatus.Font = Enum.Font.Gotham
    SkyboxStatus.TextSize = 11
    SkyboxStatus.TextXAlignment = Enum.TextXAlignment.Left
    RegisterTheme(SkyboxStatus, "TextColor3", "TextDim")

    -- Dropdown Button
    local BtnSkyboxDropdown = Instance.new("TextButton", CardSkybox)
    BtnSkyboxDropdown.Text = "🌌 Select Skybox ▼"
    BtnSkyboxDropdown.Size = UDim2.new(0.94, 0, 0, 35)
    BtnSkyboxDropdown.Position = UDim2.new(0.03, 0, 0, 55)
    StyleBtn(BtnSkyboxDropdown, C_ACCENT)

    -- Dropdown List (using Frame, not ScrollingFrame)
    local SkyboxDropdown = Instance.new("Frame", CardSkybox)
    SkyboxDropdown.Size = UDim2.new(0.94, 0, 0, 0)
    SkyboxDropdown.Position = UDim2.new(0.03, 0, 0, 92)
    SkyboxDropdown.BackgroundColor3 = C_SIDE
    SkyboxDropdown.BorderSizePixel = 0
    SkyboxDropdown.Visible = false
    SkyboxDropdown.ZIndex = 10
    SkyboxDropdown.AutomaticSize = Enum.AutomaticSize.Y
    SkyboxDropdown.ClipsDescendants = true
    Instance.new("UICorner", SkyboxDropdown).CornerRadius = UDim.new(0, 6)
    RegisterTheme(SkyboxDropdown, "BackgroundColor3", "Side")

    local SkyboxDropLayout = Instance.new("UIListLayout", SkyboxDropdown)
    SkyboxDropLayout.Padding = UDim.new(0, 2)

    local skyboxDropdownOpen = false

    local function PopulateSkyboxDropdown()
        for _, child in pairs(SkyboxDropdown:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for _, name in ipairs(presetOrder) do
            local opt = Instance.new("TextButton", SkyboxDropdown)
            opt.Text = (name == currentSkybox and "✓ " or "  ") .. name
            opt.Size = UDim2.new(1, 0, 0, 28)
            opt.BackgroundColor3 = C_ITEM
            opt.TextColor3 = (name == currentSkybox) and C_GREEN or C_TEXT
            opt.Font = Enum.Font.Gotham
            opt.TextSize = 11
            opt.ZIndex = 11
            Instance.new("UICorner", opt).CornerRadius = UDim.new(0, 4)
            RegisterTheme(opt, "BackgroundColor3", "Item")

            opt.MouseButton1Click:Connect(function()
                ApplySkybox(name)
                BtnSkyboxDropdown.Text = "🌌 " .. name .. " ▼"
                SkyboxStatus.Text = "Current: " .. name
                SkyboxStatus.TextColor3 = (name == "Default") and C_TEXT_DIM or C_GREEN
                SkyboxDropdown.Visible = false
                skyboxDropdownOpen = false
            end)
        end
    end

    BtnSkyboxDropdown.MouseButton1Click:Connect(function()
        skyboxDropdownOpen = not skyboxDropdownOpen
        if skyboxDropdownOpen then
            PopulateSkyboxDropdown()
            -- AutomaticSize.Y will handle height automatically
            SkyboxDropdown.Visible = true
        else
            SkyboxDropdown.Visible = false
        end
    end)

    -- Reset Button
    local BtnSkyboxReset = Instance.new("TextButton", CardSkybox)
    BtnSkyboxReset.Text = "🔄 RESET TO ORIGINAL"
    BtnSkyboxReset.Size = UDim2.new(0.94, 0, 0, 30)
    BtnSkyboxReset.Position = UDim2.new(0.03, 0, 0, 100)
    StyleBtn(BtnSkyboxReset, C_RED)

    BtnSkyboxReset.MouseButton1Click:Connect(function()
        ApplySkybox("Default")
        BtnSkyboxDropdown.Text = "🌌 Select Skybox ▼"
        SkyboxStatus.Text = "Current: Default"
        SkyboxStatus.TextColor3 = C_TEXT_DIM
        SkyboxDropdown.Visible = false
        skyboxDropdownOpen = false
    end)

    -- HD SHADER / GRAPHICS ENHANCER
    local CardShader = CreateCard("✨ HD SHADER", 180, 99)

    local shaderEnabled = false
    local shaderEffects = {}
    local currentPreset = "OFF"

    -- Shader presets
    local ShaderPresets = {
        ["OFF"] = {
            ColorCorrection = nil,
            Bloom = nil,
            DepthOfField = nil,
            SunRays = nil,
        },
        ["HD Natural"] = {
            ColorCorrection = { Brightness = 0.05, Contrast = 0.1, Saturation = 0.15, TintColor = Color3.new(1, 1, 1) },
            Bloom = { Intensity = 0.5, Size = 24, Threshold = 0.9 },
            DepthOfField = nil,
            SunRays = { Intensity = 0.1, Spread = 0.5 },
        },
        ["Cinematic"] = {
            ColorCorrection = {
                Brightness = -0.05,
                Contrast = 0.2,
                Saturation = -0.1,
                TintColor = Color3.fromRGB(255, 250, 240),
            },
            Bloom = { Intensity = 0.8, Size = 40, Threshold = 0.8 },
            DepthOfField = { FarIntensity = 0.2, FocusDistance = 50, InFocusRadius = 30, NearIntensity = 0 },
            SunRays = { Intensity = 0.15, Spread = 0.6 },
        },
        ["Vibrant"] = {
            ColorCorrection = { Brightness = 0.1, Contrast = 0.15, Saturation = 0.4, TintColor = Color3.new(1, 1, 1) },
            Bloom = { Intensity = 0.6, Size = 30, Threshold = 0.85 },
            DepthOfField = nil,
            SunRays = { Intensity = 0.2, Spread = 0.7 },
        },
        ["Warm"] = {
            ColorCorrection = {
                Brightness = 0.05,
                Contrast = 0.1,
                Saturation = 0.2,
                TintColor = Color3.fromRGB(255, 245, 230),
            },
            Bloom = { Intensity = 0.7, Size = 35, Threshold = 0.85 },
            DepthOfField = nil,
            SunRays = { Intensity = 0.25, Spread = 0.8 },
        },
        ["Cool"] = {
            ColorCorrection = {
                Brightness = 0,
                Contrast = 0.15,
                Saturation = 0.1,
                TintColor = Color3.fromRGB(240, 248, 255),
            },
            Bloom = { Intensity = 0.5, Size = 25, Threshold = 0.9 },
            DepthOfField = nil,
            SunRays = { Intensity = 0.1, Spread = 0.4 },
        },
        ["Night Vision"] = {
            ColorCorrection = {
                Brightness = 0.3,
                Contrast = 0.3,
                Saturation = -0.8,
                TintColor = Color3.fromRGB(150, 255, 150),
            },
            Bloom = { Intensity = 1, Size = 50, Threshold = 0.7 },
            DepthOfField = nil,
            SunRays = nil,
        },
        ["Retro"] = {
            ColorCorrection = {
                Brightness = 0.05,
                Contrast = 0.25,
                Saturation = 0.3,
                TintColor = Color3.fromRGB(255, 250, 220),
            },
            Bloom = { Intensity = 0.4, Size = 20, Threshold = 0.95 },
            DepthOfField = { FarIntensity = 0.1, FocusDistance = 100, InFocusRadius = 50, NearIntensity = 0 },
            SunRays = nil,
        },
    }

    local presetOrder = { "OFF", "HD Natural", "Cinematic", "Vibrant", "Warm", "Cool", "Night Vision", "Retro" }

    local function ClearShaderEffects()
        local lighting = game:GetService("Lighting")
        for name, effect in pairs(shaderEffects) do
            if effect and effect.Parent then
                effect:Destroy()
            end
        end
        shaderEffects = {}
    end

    local function ApplyShaderPreset(presetName)
        ClearShaderEffects()

        local lighting = game:GetService("Lighting")
        local preset = ShaderPresets[presetName]

        if not preset or presetName == "OFF" then
            currentPreset = "OFF"
            shaderEnabled = false
            return
        end

        currentPreset = presetName
        shaderEnabled = true

        -- Apply ColorCorrection
        if preset.ColorCorrection then
            local cc = Instance.new("ColorCorrectionEffect")
            cc.Name = "StarshipShader_CC"
            cc.Brightness = preset.ColorCorrection.Brightness
            cc.Contrast = preset.ColorCorrection.Contrast
            cc.Saturation = preset.ColorCorrection.Saturation
            cc.TintColor = preset.ColorCorrection.TintColor
            cc.Parent = lighting
            shaderEffects.ColorCorrection = cc
        end

        -- Apply Bloom
        if preset.Bloom then
            local bloom = Instance.new("BloomEffect")
            bloom.Name = "StarshipShader_Bloom"
            bloom.Intensity = preset.Bloom.Intensity
            bloom.Size = preset.Bloom.Size
            bloom.Threshold = preset.Bloom.Threshold
            bloom.Parent = lighting
            shaderEffects.Bloom = bloom
        end

        -- Apply DepthOfField
        if preset.DepthOfField then
            local dof = Instance.new("DepthOfFieldEffect")
            dof.Name = "StarshipShader_DOF"
            dof.FarIntensity = preset.DepthOfField.FarIntensity
            dof.FocusDistance = preset.DepthOfField.FocusDistance
            dof.InFocusRadius = preset.DepthOfField.InFocusRadius
            dof.NearIntensity = preset.DepthOfField.NearIntensity
            dof.Parent = lighting
            shaderEffects.DepthOfField = dof
        end

        -- Apply SunRays
        if preset.SunRays then
            local rays = Instance.new("SunRaysEffect")
            rays.Name = "StarshipShader_Rays"
            rays.Intensity = preset.SunRays.Intensity
            rays.Spread = preset.SunRays.Spread
            rays.Parent = lighting
            shaderEffects.SunRays = rays
        end
    end

    -- Preset dropdown
    local BtnPresetDropdown = Instance.new("TextButton", CardShader)
    BtnPresetDropdown.Text = "🎨 Preset: OFF ▼"
    BtnPresetDropdown.Size = UDim2.new(0.94, 0, 0, 35)
    BtnPresetDropdown.Position = UDim2.new(0.03, 0, 0, 35)
    StyleBtn(BtnPresetDropdown, C_TEXT)

    local PresetDropdown = Instance.new("Frame", CardShader)
    PresetDropdown.Size = UDim2.new(0.94, 0, 0, 0)
    PresetDropdown.Position = UDim2.new(0.03, 0, 0, 72)
    PresetDropdown.BackgroundColor3 = C_SIDE
    PresetDropdown.Visible = false
    PresetDropdown.ZIndex = 15
    PresetDropdown.ClipsDescendants = true
    Instance.new("UICorner", PresetDropdown).CornerRadius = UDim.new(0, 6)
    local pds = Instance.new("UIStroke", PresetDropdown)
    pds.Color = C_ACCENT
    pds.Transparency = 0.6

    local PresetScroll = Instance.new("ScrollingFrame", PresetDropdown)
    PresetScroll.Size = UDim2.new(1, 0, 1, 0)
    PresetScroll.BackgroundTransparency = 1
    PresetScroll.BorderSizePixel = 0
    PresetScroll.ScrollBarThickness = 3
    PresetScroll.ScrollBarImageColor3 = C_ACCENT
    PresetScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    PresetScroll.ZIndex = 16

    local PresetLayout = Instance.new("UIListLayout", PresetScroll)
    PresetLayout.Padding = UDim.new(0, 2)

    local presetDropdownOpen = false

    -- Status label (defined before PopulatePresetDropdown)
    local ShaderStatus = Instance.new("TextLabel", CardShader)
    ShaderStatus.Text = "Select a preset to enhance graphics"
    ShaderStatus.Size = UDim2.new(1, 0, 0, 15)
    ShaderStatus.Position = UDim2.new(0, 0, 0, 145)
    ShaderStatus.BackgroundTransparency = 1
    ShaderStatus.TextColor3 = C_TEXT_DIM
    ShaderStatus.Font = Enum.Font.Code
    ShaderStatus.TextSize = 9

    local function PopulatePresetDropdown()
        for _, child in pairs(PresetScroll:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for i, presetName in ipairs(presetOrder) do
            local btn = Instance.new("TextButton", PresetScroll)
            btn.Text = (presetName == "OFF" and "❌ " or "✨ ") .. presetName
            btn.Size = UDim2.new(1, -4, 0, 28)
            btn.BackgroundColor3 = currentPreset == presetName and C_ACCENT or C_ITEM
            btn.TextColor3 = currentPreset == presetName and C_TEXT or C_TEXT_DIM
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 10
            btn.ZIndex = 17
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

            btn.MouseEnter:Connect(function()
                if currentPreset ~= presetName then
                    btn.BackgroundColor3 = C_SIDE
                end
            end)

            btn.MouseLeave:Connect(function()
                if currentPreset ~= presetName then
                    btn.BackgroundColor3 = C_ITEM
                end
            end)

            btn.MouseButton1Click:Connect(function()
                ApplyShaderPreset(presetName)
                BtnPresetDropdown.Text = "🎨 Preset: " .. presetName .. " ▼"
                PresetDropdown.Visible = false
                presetDropdownOpen = false
                PopulatePresetDropdown()

                if presetName == "OFF" then
                    ShaderStatus.Text = "Shader disabled"
                    ShaderStatus.TextColor3 = C_TEXT_DIM
                else
                    ShaderStatus.Text = "✓ " .. presetName .. " shader active!"
                    ShaderStatus.TextColor3 = C_GREEN
                end
            end)
        end
    end

    BtnPresetDropdown.MouseButton1Click:Connect(function()
        presetDropdownOpen = not presetDropdownOpen
        if presetDropdownOpen then
            PopulatePresetDropdown()
            PresetDropdown.Size = UDim2.new(0.94, 0, 0, math.min(#presetOrder * 30, 150))
            PresetDropdown.Visible = true
        else
            PresetDropdown.Visible = false
        end
    end)

    -- Quick toggle buttons
    local BtnQuickHD = Instance.new("TextButton", CardShader)
    BtnQuickHD.Text = "🎬 HD Natural"
    BtnQuickHD.Size = UDim2.new(0.46, 0, 0, 30)
    BtnQuickHD.Position = UDim2.new(0.03, 0, 0, 75)
    StyleBtn(BtnQuickHD, C_GREEN)

    local BtnQuickCine = Instance.new("TextButton", CardShader)
    BtnQuickCine.Text = "🎥 Cinematic"
    BtnQuickCine.Size = UDim2.new(0.46, 0, 0, 30)
    BtnQuickCine.Position = UDim2.new(0.51, 0, 0, 75)
    StyleBtn(BtnQuickCine, C_ACCENT)

    local BtnToggleOff = Instance.new("TextButton", CardShader)
    BtnToggleOff.Text = "❌ TURN OFF"
    BtnToggleOff.Size = UDim2.new(0.94, 0, 0, 30)
    BtnToggleOff.Position = UDim2.new(0.03, 0, 0, 110)
    StyleBtn(BtnToggleOff, C_RED)

    BtnQuickHD.MouseButton1Click:Connect(function()
        ApplyShaderPreset("HD Natural")
        BtnPresetDropdown.Text = "🎨 Preset: HD Natural ▼"
        ShaderStatus.Text = "✓ HD Natural shader active!"
        ShaderStatus.TextColor3 = C_GREEN
    end)

    BtnQuickCine.MouseButton1Click:Connect(function()
        ApplyShaderPreset("Cinematic")
        BtnPresetDropdown.Text = "🎨 Preset: Cinematic ▼"
        ShaderStatus.Text = "✓ Cinematic shader active!"
        ShaderStatus.TextColor3 = C_GREEN
    end)

    BtnToggleOff.MouseButton1Click:Connect(function()
        ApplyShaderPreset("OFF")
        BtnPresetDropdown.Text = "🎨 Preset: OFF ▼"
        ShaderStatus.Text = "Shader disabled"
        ShaderStatus.TextColor3 = C_TEXT_DIM
    end)
end

return SetupToolsUI
