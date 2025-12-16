local function SetupFunUI(PageFun, UI, Connections, Config, LocalPlayer, UIHandlers, RegisterTheme)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    
    -- UPDATED THEME
    local C_MAIN=Color3.fromRGB(10, 10, 14); 
    local C_SIDE=Color3.fromRGB(15, 15, 20); 
    local C_ACCENT=Color3.fromRGB(90, 110, 245); -- Midnight Blue
    local C_TEXT=Color3.fromRGB(240, 240, 250); 
    local C_TEXT_DIM=Color3.fromRGB(140, 140, 160); 
    local C_ITEM=Color3.fromRGB(20, 20, 28); 
    local C_RED=Color3.fromRGB(255, 80, 80); 
    local C_YELLOW=Color3.fromRGB(255, 220, 60); 
    local C_GREEN=Color3.fromRGB(60, 255, 160)

    for _, c in pairs(PageFun:GetChildren()) do c:Destroy() end
    local FunScroll = Instance.new("ScrollingFrame", PageFun)
    FunScroll.Size = UDim2.new(1, 0, 1, 0)
    FunScroll.BackgroundTransparency = 1
    FunScroll.BorderSizePixel = 0
    FunScroll.ScrollBarThickness = 4
    FunScroll.ScrollBarImageColor3 = C_ACCENT
    FunScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    FunScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    -- Ensure RegisterTheme exists
    if not RegisterTheme then RegisterTheme = function() end end
    RegisterTheme(FunScroll, "ScrollBarImageColor3", "Accent")

    local FunLayout = Instance.new("UIListLayout", FunScroll)
    FunLayout.Padding = UDim.new(0, 15)
    FunLayout.SortOrder = Enum.SortOrder.LayoutOrder
    FunLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local function CreateCard(t, h, o)
        local c = Instance.new("Frame", FunScroll)
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
        btn.TextSize = 10
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local s = Instance.new("UIStroke", btn); s.Color = col; s.Transparency = 0.7; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        
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
        end
    end
    
    -- 1. TOUCH FLING
    local CardFling = CreateCard("TOUCH FLING", 130, 1)
    
    local BtnFling = Instance.new("TextButton", CardFling)
    BtnFling.Text = "FLING: OFF"
    BtnFling.Size = UDim2.new(0.94, 0, 0, 35)
    BtnFling.Position = UDim2.new(0.03, 0, 0, 35)
    StyleBtn(BtnFling, C_RED)
    
    local BtnExpandHitbox = Instance.new("TextButton", CardFling)
    BtnExpandHitbox.Text = "EXPAND HITBOX: OFF"
    BtnExpandHitbox.Size = UDim2.new(0.94, 0, 0, 35)
    BtnExpandHitbox.Position = UDim2.new(0.03, 0, 0, 75)
    StyleBtn(BtnExpandHitbox, C_RED)
    
    local FlingInfo = Instance.new("TextLabel", CardFling)
    FlingInfo.Text = "Bigger hitbox = easier fling!"
    FlingInfo.Size = UDim2.new(1, 0, 0, 20)
    FlingInfo.Position = UDim2.new(0, 0, 0, 105)
    FlingInfo.BackgroundTransparency = 1
    FlingInfo.TextColor3 = C_TEXT_DIM
    FlingInfo.Font = Enum.Font.Code
    FlingInfo.TextSize = 9
    
    local isFling = false
    local flingLoop = nil
    local isHitboxExpanded = false
    local hitboxParts = {}
    
    -- Expand Hitbox Function
    local function ToggleHitbox()
        isHitboxExpanded = not isHitboxExpanded
        BtnExpandHitbox.Text = "EXPAND HITBOX: " .. (isHitboxExpanded and "ON" or "OFF")
        BtnExpandHitbox.TextColor3 = isHitboxExpanded and C_GREEN or C_RED
        
        local c = LocalPlayer.Character
        if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        if isHitboxExpanded then
            -- Create invisible expanded hitbox
            for i = 1, 4 do
                local part = Instance.new("Part")
                part.Name = "HitboxExpander"
                part.Size = Vector3.new(4, 4, 0.5)
                part.Transparency = 1
                part.CanCollide = true
                part.Massless = true
                part.Parent = c
                
                -- Weld to HumanoidRootPart
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = hrp
                weld.Part1 = part
                weld.Parent = part
                
                table.insert(hitboxParts, part)
            end
            
            -- Position parts around character (front, back, left, right)
            if hitboxParts[1] then hitboxParts[1].CFrame = hrp.CFrame * CFrame.new(0, 0, -3) end
            if hitboxParts[2] then hitboxParts[2].CFrame = hrp.CFrame * CFrame.new(0, 0, 3) end
            if hitboxParts[3] then hitboxParts[3].CFrame = hrp.CFrame * CFrame.new(-3, 0, 0) end  
            if hitboxParts[4] then hitboxParts[4].CFrame = hrp.CFrame * CFrame.new(3, 0, 0) end
        else
            -- Remove hitbox parts
            for _, part in pairs(hitboxParts) do
                if part and part.Parent then
                    part:Destroy()
                end
            end
            hitboxParts = {}
        end
    end
    
    BtnExpandHitbox.MouseButton1Click:Connect(ToggleHitbox)
    
    BtnFling.MouseButton1Click:Connect(function()
        isFling = not isFling
        BtnFling.Text = "FLING: " .. (isFling and "ON" or "OFF")
        BtnFling.TextColor3 = isFling and C_GREEN or C_RED
        
        if isFling then
            flingLoop = RunService.Heartbeat:Connect(function()
                local c = LocalPlayer.Character
                if not c then return end
                
                local hrp = c:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                
                -- Save current velocity
                local currentVel = hrp.Velocity
                
                -- Apply massive velocity burst
                hrp.Velocity = currentVel * 10000 + Vector3.new(0, 10000, 0)
                
                -- Apply to hitbox parts too if expanded
                if isHitboxExpanded then
                    for _, part in pairs(hitboxParts) do
                        if part and part.Parent then
                            part.Velocity = hrp.Velocity
                        end
                    end
                end
                
                -- Wait 1 render frame
                RunService.RenderStepped:Wait()
                
                -- Restore velocity if still exists
                if c and c.Parent and hrp and hrp.Parent then
                    hrp.Velocity = currentVel
                end
                
                -- Small oscillation for better fling effect
                RunService.Stepped:Wait()
                if c and c.Parent and hrp and hrp.Parent then
                    hrp.Velocity = currentVel + Vector3.new(0, 0.1, 0)
                end
            end)
            table.insert(Connections, flingLoop)
        else
            if flingLoop then
                flingLoop:Disconnect()
                flingLoop = nil
            end
            
            -- Reset velocity
            local c = LocalPlayer.Character
            if c then
                local hrp = c:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Velocity = Vector3.new(0, 0, 0)
                    hrp.RotVelocity = Vector3.new(0, 0, 0)
                end
            end
        end
    end)
    
    -- 3. INVISIBLE (FE Bypass)
    local CardInvis = CreateCard("INVISIBLE", 85, 3)
    
    local BtnInvis = Instance.new("TextButton", CardInvis)
    BtnInvis.Text = "INVISIBLE: OFF"
    BtnInvis.Size = UDim2.new(0.94, 0, 0, 35)
    BtnInvis.Position = UDim2.new(0.03, 0, 0, 35)
    StyleBtn(BtnInvis, C_RED)
    
    local InvisInfo = Instance.new("TextLabel", CardInvis)
    InvisInfo.Text = "Real invisible (others can't see)"
    InvisInfo.Size = UDim2.new(1, 0, 0, 15)
    InvisInfo.Position = UDim2.new(0, 0, 0, 70)
    InvisInfo.BackgroundTransparency = 1
    InvisInfo.TextColor3 = C_TEXT_DIM
    InvisInfo.Font = Enum.Font.Code
    InvisInfo.TextSize = 8
    
    local isInvis = false
    local invisLoop = nil
    
    UIHandlers.ToggleRealInvisible = function()
        isInvis = not isInvis
        BtnInvis.Text = "INVISIBLE: " .. (isInvis and "ON" or "OFF")
        BtnInvis.TextColor3 = isInvis and C_GREEN or C_RED
        BtnInvis.UIStroke.Color = isInvis and C_GREEN or C_RED
        
        if isInvis then
            -- Start FE invisible loop
            invisLoop = RunService.Heartbeat:Connect(function()
                local c = LocalPlayer.Character
                if not c then return end
                
                local r = c:FindFirstChild("HumanoidRootPart")
                local h = c:FindFirstChild("Humanoid")
                if not r or not h then return end
                
                -- Save current state
                local currentCF = r.CFrame
                local currentCamOffset = h.CameraOffset
                
                -- Teleport far down (this prevents replication to other clients)
                local hiddenCF = currentCF * CFrame.new(0, -200000, 0)
                r.CFrame = hiddenCF
                
                -- Fix camera so you don't see yourself far down
                h.CameraOffset = hiddenCF:ToObjectSpace(CFrame.new(currentCF.Position)).Position
                
                -- Wait 1 frame
                RunService.RenderStepped:Wait()
                
                -- Restore position
                r.CFrame = currentCF
                h.CameraOffset = currentCamOffset
            end)
            table.insert(Connections, invisLoop)
            
            InvisInfo.Text = "You are invisible to others!"
            InvisInfo.TextColor3 = C_GREEN
        else
            if invisLoop then
                invisLoop:Disconnect()
                invisLoop = nil
            end
            
            -- Reset camera offset just in case
            local c = LocalPlayer.Character
            if c then
                local h = c:FindFirstChild("Humanoid")
                if h then
                    h.CameraOffset = Vector3.new(0, 0, 0)
                end
            end
            
            InvisInfo.Text = "Real invisible (others can't see)"
            InvisInfo.TextColor3 = C_TEXT_DIM
        end
    end
    
    BtnInvis.MouseButton1Click:Connect(UIHandlers.ToggleRealInvisible)
    
    -- 4. TELEPORT TO PLAYER
    local CardTeleport = CreateCard("TELEPORT TO PLAYER", 150, 4)
    
    local BtnPlayerDropdown2 = Instance.new("TextButton", CardTeleport)
    BtnPlayerDropdown2.Text = "Select Player ▼"
    BtnPlayerDropdown2.Size = UDim2.new(0.94, 0, 0, 35)
    BtnPlayerDropdown2.Position = UDim2.new(0.03, 0, 0, 35)
    StyleBtn(BtnPlayerDropdown2, C_TEXT)
    
    -- Dropdown list for teleport
    local DropdownList2 = Instance.new("Frame", CardTeleport)
    DropdownList2.Size = UDim2.new(0.94, 0, 0, 0)
    DropdownList2.Position = UDim2.new(0.03, 0, 0, 75)
    DropdownList2.BackgroundColor3 = C_SIDE
    DropdownList2.Visible = false
    DropdownList2.ZIndex = 10
    DropdownList2.ClipsDescendants = false
    Instance.new("UICorner", DropdownList2).CornerRadius = UDim.new(0, 6)
    local dls2 = Instance.new("UIStroke", DropdownList2); dls2.Color = C_ACCENT; dls2.Transparency = 0.6
    
    local DropdownScroll2 = Instance.new("ScrollingFrame", DropdownList2)
    DropdownScroll2.Size = UDim2.new(1, 0, 1, 0)
    DropdownScroll2.BackgroundTransparency = 1
    DropdownScroll2.BorderSizePixel = 0
    DropdownScroll2.ScrollBarThickness = 4
    DropdownScroll2.ScrollBarImageColor3 = C_ACCENT
    DropdownScroll2.CanvasSize = UDim2.new(0, 0, 0, 0)
    DropdownScroll2.ClipsDescendants = true
    
    local DropdownLayout2 = Instance.new("UIListLayout", DropdownScroll2)
    DropdownLayout2.Padding = UDim.new(0, 2)
    
    local selectedPlayer2 = nil
    local isDropdownOpen2 = false
    
    local function UpdatePlayerList2()
        DropdownScroll2:ClearAllChildren()
        DropdownLayout2 = Instance.new("UIListLayout", DropdownScroll2)
        DropdownLayout2.Padding = UDim.new(0, 2)
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local btn = Instance.new("TextButton", DropdownScroll2)
                btn.Text = player.Name
                btn.Size = UDim2.new(1, -8, 0, 25)
                btn.BackgroundColor3 = C_ITEM
                btn.TextColor3 = C_TEXT_DIM
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 10
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.TextTruncate = Enum.TextTruncate.AtEnd
                btn.BorderSizePixel = 0
                btn.ZIndex = 11
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                
                local padding = Instance.new("UIPadding", btn)
                padding.PaddingLeft = UDim.new(0, 5)
                
                btn.MouseButton1Click:Connect(function()
                    selectedPlayer2 = player
                    BtnPlayerDropdown2.Text = player.Name
                    DropdownList2.Visible = false
                    isDropdownOpen2 = false
                end)
                
                btn.MouseEnter:Connect(function()
                    btn.BackgroundColor3 = C_ACCENT
                    btn.TextColor3 = C_TEXT
                end)
                
                btn.MouseLeave:Connect(function()
                    btn.BackgroundColor3 = C_ITEM
                    btn.TextColor3 = C_TEXT_DIM
                end)
            end
        end
        
        -- Update scroll canvas size
        local count = #Players:GetPlayers() - 1
        DropdownScroll2.CanvasSize = UDim2.new(0, 0, 0, count * 27)
    end
    
    BtnPlayerDropdown2.MouseButton1Click:Connect(function()
        isDropdownOpen2 = not isDropdownOpen2
        if isDropdownOpen2 then
            UpdatePlayerList2()
            local playerCount = #Players:GetPlayers() - 1
            local maxHeight = math.min(playerCount * 27, 100)
            DropdownList2.Size = UDim2.new(0.94, 0, 0, maxHeight)
            DropdownList2.Visible = true
        else
            DropdownList2.Visible = false
        end
    end)
    
    local BtnTeleport = Instance.new("TextButton", CardTeleport)
    BtnTeleport.Text = "TELEPORT"
    BtnTeleport.Size = UDim2.new(0.94, 0, 0, 30)
    BtnTeleport.Position = UDim2.new(0.03, 0, 0, 80)
    StyleBtn(BtnTeleport, C_ACCENT)
    
    local TeleportStatus = Instance.new("TextLabel", CardTeleport)
    TeleportStatus.Text = "Select player and click TELEPORT"
    TeleportStatus.Size = UDim2.new(1, 0, 0, 20)
    TeleportStatus.Position = UDim2.new(0, 0, 0, 115)
    TeleportStatus.BackgroundTransparency = 1
    TeleportStatus.TextColor3 = C_TEXT_DIM
    TeleportStatus.Font = Enum.Font.Code
    TeleportStatus.TextSize = 9
    
    BtnTeleport.MouseButton1Click:Connect(function()
        if not selectedPlayer2 then
            TeleportStatus.Text = "Please select a player first!"
            TeleportStatus.TextColor3 = C_RED
            return
        end
        
        -- Check if player still exists in game
        if not selectedPlayer2.Parent then
            TeleportStatus.Text = "Player left the game!"
            TeleportStatus.TextColor3 = C_RED
            selectedPlayer2 = nil
            BtnPlayerDropdown2.Text = "Select Player ▼"
            return
        end
        
        local myChar = LocalPlayer.Character
        if not myChar then
            TeleportStatus.Text = "Your character not found!"
            TeleportStatus.TextColor3 = C_RED
            return
        end
        
        TeleportStatus.Text = "Finding " .. selectedPlayer2.Name .. "..."
        TeleportStatus.TextColor3 = C_YELLOW
        
        -- Wait for target character if not loaded
        local targetChar = selectedPlayer2.Character
        if not targetChar then
            local success = false
            for i = 1, 10 do -- Try 10 times
                task.wait(0.1)
                targetChar = selectedPlayer2.Character
                if targetChar then
                    success = true
                    break
                end
            end
            
            if not success then
                TeleportStatus.Text = selectedPlayer2.Name .. "'s character not loaded!"
                TeleportStatus.TextColor3 = C_RED
                return
            end
        end
        
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        
        if not myRoot then
            TeleportStatus.Text = "Your RootPart not found!"
            TeleportStatus.TextColor3 = C_RED
            return
        end
        
        if not targetRoot then
            TeleportStatus.Text = "Target RootPart not found!"
            TeleportStatus.TextColor3 = C_RED
            return
        end
        
        -- Calculate distance
        local distance = (targetRoot.Position - myRoot.Position).Magnitude
        local targetPos = targetRoot.CFrame * CFrame.new(0, 0, 3) -- 3 studs in front
        
        -- Multi-step teleport to bypass anti-cheat
        if distance > 100 then
            TeleportStatus.Text = "Teleporting in steps..."
            TeleportStatus.TextColor3 = C_YELLOW
            
            local steps = math.ceil(distance / 100) -- 100 studs per step
            local startPos = myRoot.CFrame
            
            for i = 1, steps do
                local alpha = i / steps
                local intermediatePos = startPos:Lerp(targetPos, alpha)
                myRoot.CFrame = intermediatePos
                task.wait(0.05) -- Small delay between steps
            end
        else
            -- Direct teleport if close
            myRoot.CFrame = targetPos
        end
        
        TeleportStatus.Text = "Teleported to " .. selectedPlayer2.Name .. "!"
        TeleportStatus.TextColor3 = C_GREEN
        
        -- Reset status after 2 seconds
        task.delay(2, function()
            TeleportStatus.Text = "Select player and click TELEPORT"
            TeleportStatus.TextColor3 = C_TEXT_DIM
        end)
    end)
    
    -- 5. SPECTATE PLAYER
    local CardSpectate = CreateCard("SPECTATE PLAYER", 150, 5)
    
    local BtnPlayerDropdown3 = Instance.new("TextButton", CardSpectate)
    BtnPlayerDropdown3.Text = "Select Player ▼"
    BtnPlayerDropdown3.Size = UDim2.new(0.94, 0, 0, 35)
    BtnPlayerDropdown3.Position = UDim2.new(0.03, 0, 0, 35)
    StyleBtn(BtnPlayerDropdown3, C_TEXT)
    
    -- Dropdown list for spectate
    local DropdownList3 = Instance.new("Frame", CardSpectate)
    DropdownList3.Size = UDim2.new(0.94, 0, 0, 0)
    DropdownList3.Position = UDim2.new(0.03, 0, 0, 75)
    DropdownList3.BackgroundColor3 = C_SIDE
    DropdownList3.Visible = false
    DropdownList3.ZIndex = 10
    DropdownList3.ClipsDescendants = false
    Instance.new("UICorner", DropdownList3).CornerRadius = UDim.new(0, 6)
    local dls3 = Instance.new("UIStroke", DropdownList3); dls3.Color = C_ACCENT; dls3.Transparency = 0.6
    
    local DropdownScroll3 = Instance.new("ScrollingFrame", DropdownList3)
    DropdownScroll3.Size = UDim2.new(1, 0, 1, 0)
    DropdownScroll3.BackgroundTransparency = 1
    DropdownScroll3.BorderSizePixel = 0
    DropdownScroll3.ScrollBarThickness = 4
    DropdownScroll3.ScrollBarImageColor3 = C_ACCENT
    DropdownScroll3.CanvasSize = UDim2.new(0, 0, 0, 0)
    DropdownScroll3.ClipsDescendants = true
    
    local DropdownLayout3 = Instance.new("UIListLayout", DropdownScroll3)
    DropdownLayout3.Padding = UDim.new(0, 2)
    
    local selectedPlayer3 = nil
    local isDropdownOpen3 = false
    local isSpectating = false
    local spectateLoop = nil
    
    local function UpdatePlayerList3()
        DropdownScroll3:ClearAllChildren()
        DropdownLayout3 = Instance.new("UIListLayout", DropdownScroll3)
        DropdownLayout3.Padding = UDim.new(0, 2)
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local btn = Instance.new("TextButton", DropdownScroll3)
                btn.Text = player.Name
                btn.Size = UDim2.new(1, -8, 0, 25)
                btn.BackgroundColor3 = C_ITEM
                btn.TextColor3 = C_TEXT_DIM
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 10
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.TextTruncate = Enum.TextTruncate.AtEnd
                btn.BorderSizePixel = 0
                btn.ZIndex = 11
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                
                local padding = Instance.new("UIPadding", btn)
                padding.PaddingLeft = UDim.new(0, 5)
                
                btn.MouseButton1Click:Connect(function()
                    selectedPlayer3 = player
                    BtnPlayerDropdown3.Text = player.Name
                    DropdownList3.Visible = false
                    isDropdownOpen3 = false
                end)
                
                btn.MouseEnter:Connect(function()
                    btn.BackgroundColor3 = C_ACCENT
                    btn.TextColor3 = C_TEXT
                end)
                
                btn.MouseLeave:Connect(function()
                    btn.BackgroundColor3 = C_ITEM
                    btn.TextColor3 = C_TEXT_DIM
                end)
            end
        end
        
        local count = #Players:GetPlayers() - 1
        DropdownScroll3.CanvasSize = UDim2.new(0, 0, 0, count * 27)
    end
    
    BtnPlayerDropdown3.MouseButton1Click:Connect(function()
        isDropdownOpen3 = not isDropdownOpen3
        if isDropdownOpen3 then
            UpdatePlayerList3()
            local playerCount = #Players:GetPlayers() - 1
            local maxHeight = math.min(playerCount * 27, 100)
            DropdownList3.Size = UDim2.new(0.94, 0, 0, maxHeight)
            DropdownList3.Visible = true
        else
            DropdownList3.Visible = false
        end
    end)
    
    local BtnSpectate = Instance.new("TextButton", CardSpectate)
    BtnSpectate.Text = "START SPECTATE"
    BtnSpectate.Size = UDim2.new(0.94, 0, 0, 30)
    BtnSpectate.Position = UDim2.new(0.03, 0, 0, 80)
    StyleBtn(BtnSpectate, C_ACCENT)
    
    local SpectateStatus = Instance.new("TextLabel", CardSpectate)
    SpectateStatus.Text = "Select player and click START"
    SpectateStatus.Size = UDim2.new(1, 0, 0, 20)
    SpectateStatus.Position = UDim2.new(0, 0, 0, 115)
    SpectateStatus.BackgroundTransparency = 1
    SpectateStatus.TextColor3 = C_TEXT_DIM
    SpectateStatus.Font = Enum.Font.Code
    SpectateStatus.TextSize = 9
    
    -- Store last known position for far players
    local lastKnownPosition = nil
    
    BtnSpectate.MouseButton1Click:Connect(function()
        if not isSpectating then
            -- Start spectating
            if not selectedPlayer3 then
                SpectateStatus.Text = "Please select a player first!"
                SpectateStatus.TextColor3 = C_RED
                return
            end
            
            if not selectedPlayer3.Parent then
                SpectateStatus.Text = "Player left the game!"
                SpectateStatus.TextColor3 = C_RED
                selectedPlayer3 = nil
                BtnPlayerDropdown3.Text = "Select Player ▼"
                return
            end
            
            isSpectating = true
            BtnSpectate.Text = "STOP SPECTATE"
            BtnSpectate.BackgroundColor3 = C_RED
            SpectateStatus.Text = "Spectating " .. selectedPlayer3.Name
            SpectateStatus.TextColor3 = C_GREEN
            
            -- Try to request streaming around target player (for Streaming Enabled games)
            task.spawn(function()
                local targetChar = selectedPlayer3.Character
                if targetChar then
                    local hrp = targetChar:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        pcall(function()
                            LocalPlayer:RequestStreamAroundAsync(hrp.Position, 5)
                        end)
                    end
                end
            end)
            
            spectateLoop = RunService.RenderStepped:Connect(function()
                if not selectedPlayer3 or not selectedPlayer3.Parent then
                    -- Player left, stop spectating
                    isSpectating = false
                    BtnSpectate.Text = "START SPECTATE"
                    BtnSpectate.BackgroundColor3 = C_ACCENT
                    SpectateStatus.Text = "Player left the game!"
                    SpectateStatus.TextColor3 = C_RED
                    if spectateLoop then spectateLoop:Disconnect(); spectateLoop = nil end
                    return
                end
                
                local targetChar = selectedPlayer3.Character
                local camera = workspace.CurrentCamera
                
                if targetChar then
                    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
                    local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
                    
                    if targetHRP then
                        -- Save last known position
                        lastKnownPosition = targetHRP.Position
                        
                        -- Request streaming around target (continuous for far players)
                        pcall(function()
                            LocalPlayer:RequestStreamAroundAsync(targetHRP.Position, 5)
                        end)
                    end
                    
                    if targetHum then
                        -- Normal spectate - set camera subject
                        camera.CameraSubject = targetHum
                    elseif targetHRP then
                        -- Fallback - set camera subject to HumanoidRootPart
                        camera.CameraSubject = targetHRP
                    elseif lastKnownPosition then
                        -- Character not fully loaded - move camera to last known position
                        camera.CameraType = Enum.CameraType.Custom
                        camera.CFrame = CFrame.new(lastKnownPosition + Vector3.new(0, 10, 15), lastKnownPosition)
                    end
                else
                    -- Character not loaded at all (very far with Streaming Enabled)
                    -- Try to get position from ReplicatedStorage or other means
                    if lastKnownPosition then
                        camera.CameraType = Enum.CameraType.Custom
                        camera.CFrame = CFrame.new(lastKnownPosition + Vector3.new(0, 10, 15), lastKnownPosition)
                        SpectateStatus.Text = "⚠ Far player - limited view"
                        SpectateStatus.TextColor3 = C_YELLOW
                    else
                        SpectateStatus.Text = "⚠ Waiting for player to load..."
                        SpectateStatus.TextColor3 = C_YELLOW
                    end
                end
            end)
            table.insert(Connections, spectateLoop)
        else
            -- Stop spectating
            isSpectating = false
            BtnSpectate.Text = "START SPECTATE"
            BtnSpectate.BackgroundColor3 = C_ACCENT
            SpectateStatus.Text = "Spectate stopped"
            SpectateStatus.TextColor3 = C_TEXT_DIM
            lastKnownPosition = nil
            
            if spectateLoop then
                spectateLoop:Disconnect()
                spectateLoop = nil
            end
            
            -- Reset camera to self
            local myChar = LocalPlayer.Character
            if myChar then
                local myHum = myChar:FindFirstChildOfClass("Humanoid")
                if myHum then
                    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                    workspace.CurrentCamera.CameraSubject = myHum
                end
            end
            
            task.delay(2, function()
                if not isSpectating then
                    SpectateStatus.Text = "Select player and click START"
                end
            end)
        end
    end)

    -- 6. FRIENDS IN SERVER (Click player to see their friends)
    local CardFriends = CreateCard("👥 FRIENDS IN SERVER", 85, 6)
    
    local BtnOpenFriends = Instance.new("TextButton", CardFriends)
    BtnOpenFriends.Text = "👥 VIEW PLAYERS & FRIENDS"
    BtnOpenFriends.Size = UDim2.new(0.94, 0, 0, 35)
    BtnOpenFriends.Position = UDim2.new(0.03, 0, 0, 35)
    StyleBtn(BtnOpenFriends, C_ACCENT)
    
    local FriendsStatus = Instance.new("TextLabel", CardFriends)
    FriendsStatus.Text = "Click to see who's friends with who"
    FriendsStatus.Size = UDim2.new(1, 0, 0, 15)
    FriendsStatus.Position = UDim2.new(0, 0, 0, 72)
    FriendsStatus.BackgroundTransparency = 1
    FriendsStatus.TextColor3 = C_TEXT_DIM
    FriendsStatus.Font = Enum.Font.Code
    FriendsStatus.TextSize = 9
    
    -- Friends Window
    local FriendsWindow = nil
    
    BtnOpenFriends.MouseButton1Click:Connect(function()
        -- Destroy existing window
        if FriendsWindow then FriendsWindow:Destroy() end
        
        local Main = PageFun.Parent.Parent
        FriendsWindow = Instance.new("Frame", Main)
        FriendsWindow.Name = "FriendsWindow"
        FriendsWindow.Size = UDim2.new(0, 400, 0, 450)
        FriendsWindow.Position = UDim2.new(0.5, -200, 0.5, -225)
        FriendsWindow.BackgroundColor3 = C_MAIN
        FriendsWindow.BorderSizePixel = 0
        FriendsWindow.Visible = true
        FriendsWindow.ZIndex = 200
        Instance.new("UICorner", FriendsWindow).CornerRadius = UDim.new(0, 12)
        local fws = Instance.new("UIStroke", FriendsWindow); fws.Color = C_ACCENT; fws.Thickness = 1
        
        -- Title bar
        local TitleBar = Instance.new("Frame", FriendsWindow)
        TitleBar.Size = UDim2.new(1, 0, 0, 40)
        TitleBar.BackgroundColor3 = C_SIDE
        TitleBar.BorderSizePixel = 0
        TitleBar.ZIndex = 201
        Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)
        
        local Title = Instance.new("TextLabel", TitleBar)
        Title.Text = "👥 Players in Server (Click to see friends)"
        Title.Size = UDim2.new(1, -50, 1, 0)
        Title.Position = UDim2.new(0, 15, 0, 0)
        Title.BackgroundTransparency = 1
        Title.TextColor3 = C_TEXT
        Title.Font = Enum.Font.GothamBold
        Title.TextSize = 12
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.ZIndex = 202
        
        local CloseBtn = Instance.new("TextButton", TitleBar)
        CloseBtn.Text = "✕"
        CloseBtn.Size = UDim2.new(0, 30, 0, 30)
        CloseBtn.Position = UDim2.new(1, -35, 0, 5)
        CloseBtn.BackgroundColor3 = C_RED
        CloseBtn.TextColor3 = C_TEXT
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.TextSize = 14
        CloseBtn.ZIndex = 202
        Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
        CloseBtn.MouseButton1Click:Connect(function()
            FriendsWindow:Destroy()
            FriendsWindow = nil
        end)
        
        -- Left panel (Player list)
        local LeftPanel = Instance.new("Frame", FriendsWindow)
        LeftPanel.Size = UDim2.new(0.45, -5, 1, -50)
        LeftPanel.Position = UDim2.new(0, 5, 0, 45)
        LeftPanel.BackgroundColor3 = C_SIDE
        LeftPanel.BorderSizePixel = 0
        LeftPanel.ZIndex = 201
        Instance.new("UICorner", LeftPanel).CornerRadius = UDim.new(0, 8)
        
        local LeftTitle = Instance.new("TextLabel", LeftPanel)
        LeftTitle.Text = "📋 All Players"
        LeftTitle.Size = UDim2.new(1, 0, 0, 25)
        LeftTitle.BackgroundTransparency = 1
        LeftTitle.TextColor3 = C_TEXT_DIM
        LeftTitle.Font = Enum.Font.GothamBold
        LeftTitle.TextSize = 10
        LeftTitle.ZIndex = 202
        
        local PlayerScroll = Instance.new("ScrollingFrame", LeftPanel)
        PlayerScroll.Size = UDim2.new(1, -10, 1, -30)
        PlayerScroll.Position = UDim2.new(0, 5, 0, 27)
        PlayerScroll.BackgroundTransparency = 1
        PlayerScroll.BorderSizePixel = 0
        PlayerScroll.ScrollBarThickness = 3
        PlayerScroll.ScrollBarImageColor3 = C_ACCENT
        PlayerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        PlayerScroll.ZIndex = 202
        
        local PlayerLayout = Instance.new("UIListLayout", PlayerScroll)
        PlayerLayout.Padding = UDim.new(0, 4)
        
        -- Right panel (Friends list)
        local RightPanel = Instance.new("Frame", FriendsWindow)
        RightPanel.Size = UDim2.new(0.55, -10, 1, -50)
        RightPanel.Position = UDim2.new(0.45, 5, 0, 45)
        RightPanel.BackgroundColor3 = C_SIDE
        RightPanel.BorderSizePixel = 0
        RightPanel.ZIndex = 201
        Instance.new("UICorner", RightPanel).CornerRadius = UDim.new(0, 8)
        
        local RightTitle = Instance.new("TextLabel", RightPanel)
        RightTitle.Text = "💚 Friends in Server"
        RightTitle.Size = UDim2.new(1, 0, 0, 25)
        RightTitle.BackgroundTransparency = 1
        RightTitle.TextColor3 = C_TEXT_DIM
        RightTitle.Font = Enum.Font.GothamBold
        RightTitle.TextSize = 10
        RightTitle.ZIndex = 202
        
        local FriendScroll = Instance.new("ScrollingFrame", RightPanel)
        FriendScroll.Size = UDim2.new(1, -10, 1, -30)
        FriendScroll.Position = UDim2.new(0, 5, 0, 27)
        FriendScroll.BackgroundTransparency = 1
        FriendScroll.BorderSizePixel = 0
        FriendScroll.ScrollBarThickness = 3
        FriendScroll.ScrollBarImageColor3 = C_ACCENT
        FriendScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        FriendScroll.ZIndex = 202
        
        local FriendLayout = Instance.new("UIListLayout", FriendScroll)
        FriendLayout.Padding = UDim.new(0, 4)
        
        -- Placeholder text for right panel
        local PlaceholderText = Instance.new("TextLabel", FriendScroll)
        PlaceholderText.Name = "Placeholder"
        PlaceholderText.Text = "👈 Click a player to see\ntheir friends in this server"
        PlaceholderText.Size = UDim2.new(1, 0, 0, 60)
        PlaceholderText.BackgroundTransparency = 1
        PlaceholderText.TextColor3 = C_TEXT_DIM
        PlaceholderText.Font = Enum.Font.Gotham
        PlaceholderText.TextSize = 11
        PlaceholderText.ZIndex = 203
        
        -- Selected player indicator
        local selectedBtn = nil
        
        -- Function to show friends of a player
        local function ShowFriendsOf(player, btn)
            -- Update selection visual
            if selectedBtn then
                selectedBtn.BackgroundColor3 = C_ITEM
            end
            btn.BackgroundColor3 = C_ACCENT
            selectedBtn = btn
            
            -- Clear friend list
            for _, child in pairs(FriendScroll:GetChildren()) do
                if not child:IsA("UIListLayout") then
                    child:Destroy()
                end
            end
            
            -- Show loading
            local loadingText = Instance.new("TextLabel", FriendScroll)
            loadingText.Name = "Loading"
            loadingText.Text = "⏳ Checking friends..."
            loadingText.Size = UDim2.new(1, 0, 0, 30)
            loadingText.BackgroundTransparency = 1
            loadingText.TextColor3 = C_YELLOW
            loadingText.Font = Enum.Font.GothamBold
            loadingText.TextSize = 11
            loadingText.ZIndex = 203
            
            RightTitle.Text = "💚 " .. player.Name .. "'s Friends"
            
            task.spawn(function()
                local friends = {}
                local allPlayers = Players:GetPlayers()
                
                for _, otherPlayer in pairs(allPlayers) do
                    if otherPlayer ~= player then
                        local isFriend = false
                        pcall(function()
                            isFriend = player:IsFriendsWith(otherPlayer.UserId)
                        end)
                        
                        if isFriend then
                            table.insert(friends, otherPlayer.Name)
                        end
                        task.wait(0.05) -- Small delay to avoid rate limit
                    end
                end
                
                -- Clear loading
                if loadingText and loadingText.Parent then
                    loadingText:Destroy()
                end
                
                -- Show results
                if #friends > 0 then
                    for i, friendName in ipairs(friends) do
                        local friendCard = Instance.new("Frame", FriendScroll)
                        friendCard.Size = UDim2.new(1, -5, 0, 30)
                        friendCard.BackgroundColor3 = C_ITEM
                        friendCard.BorderSizePixel = 0
                        friendCard.LayoutOrder = i
                        friendCard.ZIndex = 203
                        Instance.new("UICorner", friendCard).CornerRadius = UDim.new(0, 6)
                        
                        local friendLabel = Instance.new("TextLabel", friendCard)
                        friendLabel.Text = "  💚 " .. friendName
                        friendLabel.Size = UDim2.new(1, 0, 1, 0)
                        friendLabel.BackgroundTransparency = 1
                        friendLabel.TextColor3 = C_GREEN
                        friendLabel.Font = Enum.Font.GothamBold
                        friendLabel.TextSize = 11
                        friendLabel.TextXAlignment = Enum.TextXAlignment.Left
                        friendLabel.ZIndex = 204
                    end
                else
                    local noFriends = Instance.new("TextLabel", FriendScroll)
                    noFriends.Text = "😢 No friends in this server"
                    noFriends.Size = UDim2.new(1, 0, 0, 40)
                    noFriends.BackgroundTransparency = 1
                    noFriends.TextColor3 = C_TEXT_DIM
                    noFriends.Font = Enum.Font.Gotham
                    noFriends.TextSize = 11
                    noFriends.ZIndex = 203
                end
            end)
        end
        
        -- Populate player list
        local allPlayers = Players:GetPlayers()
        for i, player in ipairs(allPlayers) do
            local playerBtn = Instance.new("TextButton", PlayerScroll)
            playerBtn.Size = UDim2.new(1, -5, 0, 32)
            playerBtn.BackgroundColor3 = C_ITEM
            playerBtn.BorderSizePixel = 0
            playerBtn.LayoutOrder = i
            playerBtn.ZIndex = 203
            playerBtn.Text = ""
            playerBtn.AutoButtonColor = false
            Instance.new("UICorner", playerBtn).CornerRadius = UDim.new(0, 6)
            
            -- Highlight if it's LocalPlayer
            local isMe = player == LocalPlayer
            
            local playerLabel = Instance.new("TextLabel", playerBtn)
            playerLabel.Text = (isMe and "⭐ " or "👤 ") .. player.Name .. (isMe and " (You)" or "")
            playerLabel.Size = UDim2.new(1, -10, 1, 0)
            playerLabel.Position = UDim2.new(0, 5, 0, 0)
            playerLabel.BackgroundTransparency = 1
            playerLabel.TextColor3 = isMe and C_ACCENT or C_TEXT
            playerLabel.Font = Enum.Font.GothamBold
            playerLabel.TextSize = 10
            playerLabel.TextXAlignment = Enum.TextXAlignment.Left
            playerLabel.TextTruncate = Enum.TextTruncate.AtEnd
            playerLabel.ZIndex = 204
            
            playerBtn.MouseEnter:Connect(function()
                if playerBtn ~= selectedBtn then
                    playerBtn.BackgroundColor3 = C_SIDE
                end
            end)
            
            playerBtn.MouseLeave:Connect(function()
                if playerBtn ~= selectedBtn then
                    playerBtn.BackgroundColor3 = C_ITEM
                end
            end)
            
            playerBtn.MouseButton1Click:Connect(function()
                ShowFriendsOf(player, playerBtn)
            end)
        end
        
        -- Dragging
        local dragging, dragStart, startPos = false, nil, nil
        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = FriendsWindow.Position
            end
        end)
        TitleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                FriendsWindow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        
        FriendsStatus.Text = "Window opened!"
        FriendsStatus.TextColor3 = C_GREEN
    end)
    
    -- Auto-Refresh when Tab becomes visible
    
    -- Helper: Create Window (Draggable)
    local function CreateWindow(title, height)
        local Main = PageFun.Parent.Parent -- Find Main from PageFun
        local wName = "Window_" .. title:gsub(" ", "")
        if Main:FindFirstChild(wName) then Main[wName]:Destroy() end

        local w = Instance.new("Frame", Main) -- Parent to Main for overlay
        w.Name = wName
        w.Size = UDim2.new(0, 320, 0, height)
        w.Position = UDim2.new(0.5, -160, 0.5, -height/2)
        w.BackgroundColor3 = C_SIDE
        w.BorderSizePixel = 0
        w.Visible = false
        w.ZIndex = 200
        Instance.new("UICorner", w).CornerRadius = UDim.new(0, 12)
        
        local s = Instance.new("UIStroke", w)
        s.Color = C_ACCENT
        s.Thickness = 1
        s.Transparency = 0.5
        RegisterTheme(s, "Color")

        local h = Instance.new("Frame", w)
        h.Size = UDim2.new(1, 0, 0, 35)
        h.BackgroundColor3 = C_ITEM
        h.ZIndex = 201
        Instance.new("UICorner", h).CornerRadius = UDim.new(0, 12)
        
        -- Fix corner radius for top only look (optional, but keeping simple)
        
        local l = Instance.new("TextLabel", h)
        l.Text = title
        l.Size = UDim2.new(1, -40, 1, 0)
        l.Position = UDim2.new(0, 15, 0, 0)
        l.BackgroundTransparency = 1
        l.TextColor3 = C_TEXT
        l.Font = Enum.Font.GothamBold
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = 202
        
        local close = Instance.new("TextButton", h)
        close.Size = UDim2.new(0, 35, 0, 35)
        close.Position = UDim2.new(1, -35, 0, 0)
        close.BackgroundTransparency = 1
        close.Text = "X"
        close.TextColor3 = C_RED
        close.Font = Enum.Font.GothamBold
        close.TextSize = 14
        close.ZIndex = 202
        close.MouseButton1Click:Connect(function() w.Visible = false end)
        
        -- Dragging
        local dragging, dragInput, dragStart, startPos
        h.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = w.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        h.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                w.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        
        local content = Instance.new("ScrollingFrame", w)
        content.Size = UDim2.new(1, 0, 1, -40)
        content.Position = UDim2.new(0, 0, 0, 40)
        content.BackgroundTransparency = 1
        content.BorderSizePixel = 0
        content.ScrollBarThickness = 4
        content.ScrollBarImageColor3 = C_ACCENT
        content.ZIndex = 201
        RegisterTheme(content, "ScrollBarImageColor3")
        
        local layout = Instance.new("UIListLayout", content)
        layout.Padding = UDim.new(0, 5)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        
        content.AutomaticCanvasSize = Enum.AutomaticSize.Y
        
        return w, content
    end

    -- Helper: Create Slider (Adapted for Window)
    local function CreateSlider(parent, title, min, max, default, callback)
        local f = Instance.new("Frame", parent)
        f.Size = UDim2.new(0.94, 0, 0, 40)
        f.BackgroundTransparency = 1
        f.ZIndex = 205
        
        local l = Instance.new("TextLabel", f)
        l.Text = title .. ": " .. default
        l.Size = UDim2.new(1, 0, 0, 15)
        l.BackgroundTransparency = 1
        l.TextColor3 = C_TEXT
        l.Font = Enum.Font.Gotham
        l.TextSize = 10
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = 206
        
        local s = Instance.new("TextButton", f)
        s.Text = ""
        s.Size = UDim2.new(1, 0, 0, 6)
        s.Position = UDim2.new(0, 0, 0, 20)
        s.BackgroundColor3 = C_SIDE
        s.ZIndex = 206
        Instance.new("UICorner", s).CornerRadius = UDim.new(0, 3)
        
        local fill = Instance.new("Frame", s)
        fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
        fill.BackgroundColor3 = C_ACCENT
        fill.ZIndex = 207
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)
        
        local dragging = false
        s.MouseButton1Down:Connect(function() dragging = true end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                local p = math.clamp((i.Position.X - s.AbsolutePosition.X) / s.AbsoluteSize.X, 0, 1)
                local val = min + (max - min) * p
                val = math.floor(val * 100) / 100
                fill.Size = UDim2.new(p, 0, 1, 0)
                l.Text = title .. ": " .. val
                callback(val)
            end
        end)
        return f
    end

    -- Helper: Create Toggle (Adapted for Window)
    local function CreateToggle(parent, title, default, callback)
        local b = Instance.new("TextButton", parent)
        b.Size = UDim2.new(0.94, 0, 0, 35)
        StyleBtn(b, default and C_GREEN or C_RED)
        b.Text = title .. ": " .. (default and "ON" or "OFF")
        b.ZIndex = 205
        
        local on = default
        b.MouseButton1Click:Connect(function()
            on = not on
            b.Text = title .. ": " .. (on and "ON" or "OFF")
            b.TextColor3 = on and C_GREEN or C_RED
            b.UIStroke.Color = on and C_GREEN or C_RED
            callback(on)
        end)
        return b
    end

    -- --- RING MODIFIER WINDOW ---
    local RingWindow, RingContent = CreateWindow("RING MODIFIER", 320)
    
    local ringModes = {
        "Vertical Ring", "Horizontal Ring", "Vertical & Horizontal", "Left Tilt", "Right Tilt",
        "Left & Right Tilt", "Spiral", "Figure 8", "DNA Helix", "Flower Pattern", "Galaxy Spiral",
        "Infinity", "Wave Pattern", "Atomic Orbit", "Butterfly", "Tornado", "Heart", "Vortex",
        "Pendulum", "Lemniscate 3D", "Star Pattern", "Trefoil Knot", "Double Spiral", "Mobius Strip",
        "Hypocycloid", "Sphere Spiral", "Asteroid Belt", "Rose Curve", "Lissajous", "Polygonal Orbit"
    }
    local currentModeIdx = 2
    local ringRadius = 50
    local ringSpeed = 2
    local isRingActive = false
    local ringParts = {}
    local ringConnection = nil
    
    -- Mode Selector
    local ModeFrame = Instance.new("Frame", RingContent)
    ModeFrame.Size = UDim2.new(0.94, 0, 0, 30)
    ModeFrame.BackgroundTransparency = 1
    ModeFrame.ZIndex = 205
    ModeFrame.LayoutOrder = 1
    
    local BtnPrev = Instance.new("TextButton", ModeFrame)
    BtnPrev.Size = UDim2.new(0.2, 0, 1, 0)
    BtnPrev.Text = "<"
    StyleBtn(BtnPrev, C_TEXT)
    BtnPrev.ZIndex = 206
    
    local BtnNext = Instance.new("TextButton", ModeFrame)
    BtnNext.Size = UDim2.new(0.2, 0, 1, 0)
    BtnNext.Position = UDim2.new(0.8, 0, 0, 0)
    BtnNext.Text = ">"
    StyleBtn(BtnNext, C_TEXT)
    BtnNext.ZIndex = 206
    
    local ModeLabel = Instance.new("TextLabel", ModeFrame)
    ModeLabel.Size = UDim2.new(0.6, 0, 1, 0)
    ModeLabel.Position = UDim2.new(0.2, 0, 0, 0)
    ModeLabel.BackgroundTransparency = 1
    ModeLabel.Text = ringModes[currentModeIdx]
    ModeLabel.TextColor3 = C_ACCENT
    ModeLabel.Font = Enum.Font.GothamBold
    ModeLabel.TextSize = 11
    ModeLabel.ZIndex = 206
    
    BtnPrev.MouseButton1Click:Connect(function()
        currentModeIdx = currentModeIdx - 1
        if currentModeIdx < 1 then currentModeIdx = #ringModes end
        ModeLabel.Text = ringModes[currentModeIdx]
    end)
    
    BtnNext.MouseButton1Click:Connect(function()
        currentModeIdx = currentModeIdx + 1
        if currentModeIdx > #ringModes then currentModeIdx = 1 end
        ModeLabel.Text = ringModes[currentModeIdx]
    end)

    -- Ring Functions (Same logic as before)
    local function CalculateRingPos(index, total, center)
        local angle = (index / total) * (2 * math.pi) + os.clock() * ringSpeed
        local ox, oy, oz = 0, 0, 0
        local r = ringRadius
        if currentModeIdx == 1 then ox=math.cos(angle)*r; oy=math.sin(angle)*r
        elseif currentModeIdx == 2 then ox=math.cos(angle)*r; oz=math.sin(angle)*r
        elseif currentModeIdx == 3 then local a2=angle+math.pi/2; ox=math.cos(angle)*r; oy=math.sin(a2)*r; oz=math.sin(angle)*r
        elseif currentModeIdx == 7 then ox=math.cos(angle)*r; oy=((index/total)*2-1)*r; oz=math.sin(angle)*r
        elseif currentModeIdx == 8 then ox=math.cos(angle)*r; oy=math.sin(2*angle)*r*0.5; oz=math.sin(angle)*r*1.5
        elseif currentModeIdx == 9 then ox=math.cos(angle)*r; oy=math.cos(angle*2)*r+math.sin(os.clock()*ringSpeed)*r; oz=math.sin(angle)*r
        elseif currentModeIdx == 16 then local h=2; local rr=r*(1-(index/total)); ox=math.cos(angle)*rr; oy=(index/total)*r*h; oz=math.sin(angle)*rr
        else ox=math.cos(angle)*r; oz=math.sin(angle)*r end
        return center + Vector3.new(ox, oy, oz)
    end

    -- Global table to track manipulated parts and their original states
    local ManipulatedParts = {}

    local function RestorePart(part)
        for i, data in ipairs(ManipulatedParts) do
            if data.Part == part then
                if part and part.Parent then
                    -- Kill Velocity to prevent flinging
                    part.Velocity = Vector3.new(0,0,0)
                    part.RotVelocity = Vector3.new(0,0,0)
                    part.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    part.AssemblyAngularVelocity = Vector3.new(0,0,0)
                    
                    part.Anchored = data.OriginalAnchored
                    part.CanCollide = data.OriginalCanCollide
                    part.Transparency = data.OriginalTransparency
                    part.CustomPhysicalProperties = data.OriginalCustomPhysicalProperties
                    
                    -- Remove added attachments/aligners
                    for _, c in pairs(part:GetChildren()) do
                        if c.Name == "ManipAtt" or c.Name == "ManipAlign" or c.Name == "ManipForce" then
                            c:Destroy()
                        end
                    end
                end
                table.remove(ManipulatedParts, i)
                return
            end
        end
    end

    local function ProcessPart(part)
        if part:IsA("BasePart") and not part.Anchored and not part.Parent:FindFirstChild("Humanoid") and not part:IsDescendantOf(LocalPlayer.Character) then
            -- Store original state if not already stored
            local isStored = false
            for _, data in ipairs(ManipulatedParts) do
                if data.Part == part then isStored = true; break end
            end
            
            if not isStored then
                table.insert(ManipulatedParts, {
                    Part = part,
                    OriginalAnchored = part.Anchored,
                    OriginalCanCollide = part.CanCollide,
                    OriginalTransparency = part.Transparency,
                    OriginalCustomPhysicalProperties = part.CustomPhysicalProperties
                })
            end

            -- Clean existing movers
            for _, c in pairs(part:GetChildren()) do if c:IsA("BodyMover") or c:IsA("BodyMover2") or c:IsA("Constraint") then c:Destroy() end end
            
            part.CanCollide = false
            part.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
            
            local att = Instance.new("Attachment", part); att.Name = "ManipAtt"
            local align = Instance.new("AlignPosition", part); align.Name = "ManipAlign"
            align.Attachment0 = att
            align.Mode = Enum.PositionAlignmentMode.OneAttachment
            align.Responsiveness = 200
            align.MaxForce = 9e9
            return {part=part, align=align}
        end
        return nil
    end

    local function ToggleRing(active)
        isRingActive = active
        if active then
            ringParts = {}
            for _, v in ipairs(workspace:GetDescendants()) do
                local p = ProcessPart(v)
                if p then table.insert(ringParts, p) end
            end
            ringConnection = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
                    local center = root.Position
                    for i, data in ipairs(ringParts) do
                        if data.part and data.part.Parent then
                            data.align.Position = CalculateRingPos(i, #ringParts, center)
                            data.part.Velocity = Vector3.new(0,0,0)
                        end
                    end
                end
            end)
            table.insert(Connections, ringConnection)
        else
            if ringConnection then ringConnection:Disconnect(); ringConnection = nil end
            for _, data in ipairs(ringParts) do 
                if data.align then data.align:Destroy() end 
                RestorePart(data.part)
            end
            ringParts = {}
        end
    end

    CreateToggle(RingContent, "Enable Ring", false, ToggleRing).LayoutOrder = 2
    CreateSlider(RingContent, "Radius", 5, 100, 50, function(v) ringRadius = v end).LayoutOrder = 3
    CreateSlider(RingContent, "Speed", 0.1, 10, 2, function(v) ringSpeed = v end).LayoutOrder = 4


    -- --- PART MANIPULATION WINDOW ---
    local ManipWindow, ManipContent = CreateWindow("PART MANIPULATION", 380)
    
    -- Black Hole
    local bhActive = false
    local bhFolder = nil
    local bhLoop = nil
    local function ToggleBlackHole(active)
        bhActive = active
        if active then
            bhFolder = Instance.new("Folder", workspace)
            local centerPart = Instance.new("Part", bhFolder)
            centerPart.Anchored = true; centerPart.Transparency = 1; centerPart.CanCollide = false
            local att1 = Instance.new("Attachment", centerPart)
            bhLoop = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then att1.WorldCFrame = root.CFrame; sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge) end
            end)
            table.insert(Connections, bhLoop)
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("BasePart") and not v.Anchored and not v.Parent:FindFirstChild("Humanoid") and not v:IsDescendantOf(LocalPlayer.Character) then
                    -- Store State
                    local isStored = false
                    for _, data in ipairs(ManipulatedParts) do if data.Part == v then isStored = true; break end end
                    if not isStored then
                        table.insert(ManipulatedParts, {
                            Part = v,
                            OriginalAnchored = v.Anchored,
                            OriginalCanCollide = v.CanCollide,
                            OriginalTransparency = v.Transparency,
                            OriginalCustomPhysicalProperties = v.CustomPhysicalProperties
                        })
                    end

                    v.CanCollide = false
                    local att2 = Instance.new("Attachment", v); att2.Name = "ManipAtt"
                    local align = Instance.new("AlignPosition", v); align.Name = "ManipAlign"
                    align.Attachment0 = att2
                    align.Attachment1 = att1
                    align.Responsiveness = 200
                    align.MaxForce = 9e9
                end
            end
        else
            if bhLoop then bhLoop:Disconnect() end
            if bhFolder then bhFolder:Destroy() end
            -- Restore all manipulated parts
             -- Note: Since Black Hole affects potentially ALL parts, we iterate the global list
            for i = #ManipulatedParts, 1, -1 do
                RestorePart(ManipulatedParts[i].Part)
            end
        end
    end
    CreateToggle(ManipContent, "Black Hole", false, ToggleBlackHole).LayoutOrder = 1

    -- Invert Gravity
    local gravActive = false
    local gravLoop = nil
    local gravParts = {}
    local function ToggleGrav(active)
        gravActive = active
        if active then
            gravParts = {}
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("BasePart") and not v.Anchored and not v.Parent:FindFirstChild("Humanoid") and not v:IsDescendantOf(LocalPlayer.Character) then
                    -- Store State
                    local isStored = false
                    for _, data in ipairs(ManipulatedParts) do if data.Part == v then isStored = true; break end end
                    if not isStored then
                        table.insert(ManipulatedParts, {
                            Part = v,
                            OriginalAnchored = v.Anchored,
                            OriginalCanCollide = v.CanCollide,
                            OriginalTransparency = v.Transparency,
                            OriginalCustomPhysicalProperties = v.CustomPhysicalProperties
                        })
                    end
                    
                    gravParts[v] = true
                    v.CanCollide = false
                    v.CustomPhysicalProperties = PhysicalProperties.new(0,0,0,0,0)
                end
            end
            
            gravLoop = RunService.Heartbeat:Connect(function()
                sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
                for p, _ in pairs(gravParts) do if p and p.Parent then p.Velocity = Vector3.new(0, 10, 0) end end
            end)
            table.insert(Connections, gravLoop)
        else
            if gravLoop then gravLoop:Disconnect() end
            gravParts = {}
            -- Restore
            for i = #ManipulatedParts, 1, -1 do
                RestorePart(ManipulatedParts[i].Part)
            end
        end
    end
    CreateToggle(ManipContent, "Invert Gravity", false, ToggleGrav).LayoutOrder = 2

    -- Part Destroyer
    local desActive = false
    local desLoop = nil
    local function ToggleDestroyer(active)
        desActive = active
        if active then
            desLoop = RunService.Heartbeat:Connect(function()
                sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
                local c = LocalPlayer.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if r then
                    for _, v in pairs(workspace:GetDescendants()) do
                        if v:IsA("BasePart") and not v.Anchored and not v.Parent:FindFirstChild("Humanoid") and not v:IsDescendantOf(c) then
                            if (v.Position - r.Position).Magnitude < 10 then
                                -- Store State
                                local isStored = false
                                for _, data in ipairs(ManipulatedParts) do if data.Part == v then isStored = true; break end end
                                if not isStored then
                                    table.insert(ManipulatedParts, {
                                        Part = v,
                                        OriginalAnchored = v.Anchored,
                                        OriginalCanCollide = v.CanCollide,
                                        OriginalTransparency = v.Transparency,
                                        OriginalCustomPhysicalProperties = v.CustomPhysicalProperties
                                    })
                                end
                                
                                v.CFrame = CFrame.new(0, -1000, 0)
                                v.Anchored = true
                            end
                        end
                    end
                end
            end)
            table.insert(Connections, desLoop)
        else
            if desLoop then desLoop:Disconnect() end
            -- Restore
             for i = #ManipulatedParts, 1, -1 do
                RestorePart(ManipulatedParts[i].Part)
            end
        end
    end
    CreateToggle(ManipContent, "Part Destroyer", false, ToggleDestroyer).LayoutOrder = 3

    -- Part Magnet
    local magActive = false
    local magLoop = nil
    local magRadius = 50
    local magStrength = 100
    local function ToggleMagnet(active)
        magActive = active
        if active then
            magLoop = RunService.Heartbeat:Connect(function()
                sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
                local c = LocalPlayer.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if r then
                    local parts = workspace:FindPartsInRegion3(Region3.new(r.Position - Vector3.new(magRadius,magRadius,magRadius), r.Position + Vector3.new(magRadius,magRadius,magRadius)), nil, 1000)
                    for _, v in ipairs(parts) do
                        if v:IsA("BasePart") and not v.Anchored and not v.Parent:FindFirstChild("Humanoid") and not v:IsDescendantOf(c) then
                             -- Store State
                            local isStored = false
                            for _, data in ipairs(ManipulatedParts) do if data.Part == v then isStored = true; break end end
                            if not isStored then
                                table.insert(ManipulatedParts, {
                                    Part = v,
                                    OriginalAnchored = v.Anchored,
                                    OriginalCanCollide = v.CanCollide,
                                    OriginalTransparency = v.Transparency,
                                    OriginalCustomPhysicalProperties = v.CustomPhysicalProperties
                                })
                            end
                            
                            v.CanCollide = false
                            local dir = (r.Position - v.Position).Unit
                            v.Velocity = dir * magStrength
                        end
                    end
                end
            end)
            table.insert(Connections, magLoop)
        else
            if magLoop then magLoop:Disconnect() end
            -- Restore
             for i = #ManipulatedParts, 1, -1 do
                RestorePart(ManipulatedParts[i].Part)
            end
        end
    end
    CreateToggle(ManipContent, "Part Magnet", false, ToggleMagnet).LayoutOrder = 4
    CreateSlider(ManipContent, "Magnet Radius", 10, 200, 50, function(v) magRadius = v end).LayoutOrder = 5
    CreateSlider(ManipContent, "Magnet Strength", 10, 500, 100, function(v) magStrength = v end).LayoutOrder = 6
    
    local BtnTornado = Instance.new("TextButton", ManipContent)
    BtnTornado.Size = UDim2.new(0.94, 0, 0, 35)
    StyleBtn(BtnTornado, C_TEXT)
    BtnTornado.Text = "Tornado Gui [External]"
    BtnTornado.ZIndex = 205
    BtnTornado.LayoutOrder = 7
    BtnTornado.MouseButton1Click:Connect(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/hm5650/TornadoGuiIg/refs/heads/main/Srrylolitsobfuscatednomorestealing", true))()
    end)


    -- --- MAIN FUN TAB CONTENT ---
    
    local Spacer = Instance.new("Frame", FunScroll); Spacer.Size = UDim2.new(1,0,0,10); Spacer.BackgroundTransparency=1; Spacer.LayoutOrder=6

    local BtnOpenRing = Instance.new("TextButton", FunScroll)
    BtnOpenRing.Size = UDim2.new(0.96, 0, 0, 35)
    StyleBtn(BtnOpenRing, C_TEXT)
    BtnOpenRing.Text = "OPEN RING MODIFIER"
    BtnOpenRing.LayoutOrder = 7
    BtnOpenRing.MouseButton1Click:Connect(function() RingWindow.Visible = not RingWindow.Visible end)

    local BtnOpenManip = Instance.new("TextButton", FunScroll)
    BtnOpenManip.Size = UDim2.new(0.96, 0, 0, 35)
    StyleBtn(BtnOpenManip, C_TEXT)
    BtnOpenManip.Text = "OPEN PART MANIPULATION"
    BtnOpenManip.LayoutOrder = 8
    BtnOpenManip.MouseButton1Click:Connect(function() ManipWindow.Visible = not ManipWindow.Visible end)

    local BtnAntiLag = Instance.new("TextButton", FunScroll)
    BtnAntiLag.Size = UDim2.new(0.96, 0, 0, 35)
    StyleBtn(BtnAntiLag, C_TEXT)
    BtnAntiLag.Text = "AntiLag [External]"
    BtnAntiLag.LayoutOrder = 9
    BtnAntiLag.MouseButton1Click:Connect(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/igfrx/tpmorPpoT/refs/heads/main/aL", true))()
    end)

    -- AUTO FOLLOW
    local CardFollow = CreateCard("AUTO FOLLOW", 140, 10)
    
    local followTarget = nil
    local isFollowing = false
    local followLoop = nil
    local camAssistLoop = nil
    local lastMouseMove = 0
    local activeTween = nil
    
    local function getHRP(c) return c and c:FindFirstChild("HumanoidRootPart") end
    local function getHum(c) return c and c:FindFirstChild("Humanoid") end
    
    local function smoothAlpha(speed, dt) return math.clamp(1 - math.exp(-speed * dt), 0, 1) end
    
    local function computeIdealBehind(targetHRP)
        local look = targetHRP.CFrame.LookVector
        local behindPos = targetHRP.Position - (look * 4) + Vector3.new(0, 2, 0)
        local frontPoint = behindPos + look
        return CFrame.new(behindPos, frontPoint)
    end

    local function tweenPlaceBehind(myHRP, targetHRP)
        if not (myHRP and targetHRP) then return end
        local desiredCf = computeIdealBehind(targetHRP)
        if activeTween then pcall(function() activeTween:Cancel() end); activeTween = nil end
        
        local info = TweenInfo.new(0.01, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
        local success, tween = pcall(function() return TweenService:Create(myHRP, info, {CFrame=desiredCf}) end)
        if success and tween then
            activeTween = tween
            tween:Play()
            tween.Completed:Connect(function() if activeTween == tween then activeTween = nil end end)
        end
    end

    local BtnFollow = Instance.new("TextButton", CardFollow)
    BtnFollow.Text = "START FOLLOW (G)"
    BtnFollow.Size = UDim2.new(0.9, 0, 0, 35)
    BtnFollow.Position = UDim2.new(0.05, 0, 0, 85)
    StyleBtn(BtnFollow, C_GREEN)

    local function StopFollow()
        isFollowing = false
        BtnFollow.Text = "START FOLLOW (G)"
        BtnFollow.TextColor3 = C_GREEN
        BtnFollow.UIStroke.Color = C_GREEN
        if followLoop then followLoop:Disconnect(); followLoop = nil end
        if camAssistLoop then camAssistLoop:Disconnect(); camAssistLoop = nil end
        
        local c = LocalPlayer.Character
        local h = getHum(c)
        if h then h.PlatformStand = false end
        
        local cam = workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Custom
    end

    local function StartFollow()
        if not followTarget then return end
        isFollowing = true
        BtnFollow.Text = "STOP FOLLOW (G)"
        BtnFollow.TextColor3 = C_RED
        BtnFollow.UIStroke.Color = C_RED
        
        local lastTpTick = 0
        followLoop = RunService.Heartbeat:Connect(function(dt)
            if not isFollowing or not followTarget then StopFollow(); return end
            
            local myChar = LocalPlayer.Character
            local myHRP = getHRP(myChar)
            local myHum = getHum(myChar)
            
            local tChar = followTarget.Character
            local tHRP = getHRP(tChar)
            local tHum = getHum(tChar)
            
            if not (myHRP and myHum and tHRP and tHum and tHum.Health > 0) then return end
            
            lastTpTick = lastTpTick + dt
            if lastTpTick >= 0.01 then
                lastTpTick = 0
                pcall(function()
                    myHum.PlatformStand = false -- Keep false to allow animations if wanted, or true for pure tween
                    tweenPlaceBehind(myHRP, tHRP)
                end)
            end
        end)
        
        camAssistLoop = RunService.RenderStepped:Connect(function(dt)
            if not isFollowing or not followTarget then return end
            local cam = workspace.CurrentCamera
            local tChar = followTarget.Character
            local tHRP = getHRP(tChar)
            
            if tHRP then
                local desiredHrpCf = computeIdealBehind(tHRP)
                local look = tHRP.CFrame.LookVector
                local camOffset = -(look * 2.2) + Vector3.new(0, 1.6, 0)
                local camPos = desiredHrpCf.Position + camOffset
                local lookAt = tHRP.Position + Vector3.new(0, 1.2, 0)
                local desiredCamCf = CFrame.new(camPos, lookAt)
                
                local timeSinceMouse = tick() - lastMouseMove
                local assist = (timeSinceMouse > 0.25) and 0.18 or 0.03
                local alpha = smoothAlpha(12 * assist, dt)
                
                cam.CameraType = Enum.CameraType.Custom
                cam.CFrame = cam.CFrame:Lerp(desiredCamCf, alpha)
            end
        end)
        table.insert(Connections, followLoop)
        table.insert(Connections, camAssistLoop)
    end

    BtnFollow.MouseButton1Click:Connect(function()
        if isFollowing then StopFollow() else StartFollow() end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then lastMouseMove = tick() end
    end)
    
    UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and not UserInputService:GetFocusedTextBox() and input.KeyCode == Config.Keybinds.FollowPlayer and followTarget then
             if isFollowing then StopFollow() else StartFollow() end
        end
    end)

    -- Player Dropdown for Follow
    local BtnSelP = Instance.new("TextButton", CardFollow)
    BtnSelP.Text = "Select Target..."
    BtnSelP.Size = UDim2.new(0.9, 0, 0, 35)
    BtnSelP.Position = UDim2.new(0.05, 0, 0, 40)
    StyleBtn(BtnSelP, C_TEXT)
    
    local DropP = Instance.new("ScrollingFrame", CardFollow)
    DropP.Size = UDim2.new(0.9, 0, 0, 120)
    DropP.Position = UDim2.new(0.05, 0, 0, 80) -- Overlap
    DropP.BackgroundColor3 = C_SIDE
    DropP.Visible = false
    DropP.ZIndex = 20
    Instance.new("UICorner", DropP).CornerRadius = UDim.new(0, 6)
    local dlsf = Instance.new("UIStroke", DropP); dlsf.Color = C_ACCENT; dlsf.Transparency = 0.6
    local DropLayout = Instance.new("UIListLayout", DropP); DropLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    BtnSelP.MouseButton1Click:Connect(function() 
        DropP.Visible = not DropP.Visible 
        if DropP.Visible then
            for _,c in pairs(DropP:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            for _, p in pairs(game:GetService("Players"):GetPlayers()) do
                if p ~= LocalPlayer then
                    local b = Instance.new("TextButton", DropP)
                    b.Text = p.DisplayName .. " (@" .. p.Name .. ")"
                    b.Size = UDim2.new(1, 0, 0, 25)
                    b.BackgroundColor3 = C_ITEM
                    b.TextColor3 = C_TEXT_DIM
                    b.Font = Enum.Font.Gotham
                    b.TextSize = 11
                    b.ZIndex = 21
                    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
                    
                    b.MouseButton1Click:Connect(function()
                        followTarget = p
                        BtnSelP.Text = "Target: " .. p.DisplayName
                        DropP.Visible = false
                    end)
                end
            end
            DropP.CanvasSize = UDim2.new(0,0,0, #DropP:GetChildren()*25)
        end
    end)

    -- Cleanup Hook
    local oldCleanup = UIHandlers.CleanupTools
    UIHandlers.CleanupTools = function()
        if oldCleanup then oldCleanup() end
        -- Fun Module Cleanups
        if ToggleRing then ToggleRing(false) end
        if ToggleBlackHole then ToggleBlackHole(false) end
        if ToggleGrav then ToggleGrav(false) end
        if ToggleDestroyer then ToggleDestroyer(false) end
        if ToggleMagnet then ToggleMagnet(false) end
        
        -- Restore Parts if needed
        if #ManipulatedParts > 0 then
            for _, data in ipairs(ManipulatedParts) do
                if data.Part and data.Part.Parent then
                    data.Part.Anchored = data.OriginalAnchored
                    data.Part.CanCollide = data.OriginalCanCollide
                    data.Part.Transparency = data.OriginalTransparency
                end
            end
            -- We can't easily clear ManipulatedParts local here without re-exposing, but it's local to closure.
            -- Actually, since ManipulatedParts is local to SetupFunUI, we can access it here.
            for i = #ManipulatedParts, 1, -1 do table.remove(ManipulatedParts, i) end
        end

        if RingWindow then RingWindow:Destroy() end
        if ManipWindow then ManipWindow:Destroy() end
        if followLoop then followLoop:Disconnect() end
        if camAssistLoop then camAssistLoop:Disconnect() end
    end
end

return SetupFunUI
