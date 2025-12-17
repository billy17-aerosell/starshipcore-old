local function SetupHelperUI(PageHelper, UI, Connections, Config, LocalPlayer, UIHandlers, ShowConfirm, RegisterTheme)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")
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

	local FOLDER_NAME = "StarshipCore"

	local function CFToTbl(cf)
		return { cf:GetComponents() }
	end
	local function TblToCF(t)
		return CFrame.new(unpack(t))
	end

	-- Ensure RegisterTheme exists
	if not RegisterTheme then
		RegisterTheme = function() end
	end

	local HelperScroll = Instance.new("ScrollingFrame", PageHelper)
	HelperScroll.Size = UDim2.new(1, 0, 1, 0)
	HelperScroll.BackgroundTransparency = 1
	HelperScroll.BorderSizePixel = 0
	HelperScroll.ScrollBarThickness = 6
	HelperScroll.ScrollBarImageColor3 = C_ACCENT
	HelperScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	HelperScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	RegisterTheme(HelperScroll, "ScrollBarImageColor3", "Accent")

	local HelperLayout = Instance.new("UIListLayout", HelperScroll)
	HelperLayout.Padding = UDim.new(0, 15)
	HelperLayout.SortOrder = Enum.SortOrder.LayoutOrder
	HelperLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function CreateCard(t, h, o)
		local c = Instance.new("Frame", HelperScroll)
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

		-- Only register static colors
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

	-- 0. CHARACTER & FLY
	local CardChar = CreateCard("CHARACTER & FLY", 185, 0)

	-- Speed
	local WSVal = Instance.new("TextBox", CardChar)
	WSVal.Text = ""
	WSVal.PlaceholderText = "16"
	WSVal.Size = UDim2.new(0.15, 0, 0, 35)
	WSVal.Position = UDim2.new(0.82, 0, 0, 35)
	WSVal.BackgroundColor3 = C_SIDE
	WSVal.TextColor3 = C_TEXT
	WSVal.Font = Enum.Font.Gotham
	Instance.new("UICorner", WSVal).CornerRadius = UDim.new(0, 6)
	local SldWS = Instance.new("TextButton", CardChar)
	SldWS.Text = ""
	SldWS.Size = UDim2.new(0.55, 0, 0, 6)
	SldWS.Position = UDim2.new(0.25, 0, 0, 50)
	SldWS.BackgroundColor3 = C_SIDE
	SldWS.AutoButtonColor = false
	Instance.new("UICorner", SldWS)
	local FillWS = Instance.new("Frame", SldWS)
	FillWS.Size = UDim2.new(0, 0, 1, 0)
	FillWS.BackgroundColor3 = C_ACCENT
	Instance.new("UICorner", FillWS)
	local BtnTogWS = Instance.new("TextButton", CardChar)
	BtnTogWS.Text = "SPEED: OFF"
	BtnTogWS.Size = UDim2.new(0.2, 0, 0, 35)
	BtnTogWS.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnTogWS, C_RED)

	local isWSEnabled, wsCon, defWS, tgtWS = false, nil, 16, 16
	local function UpdateWSVisual(v)
		v = math.clamp(v, 0, 300)
		local p = v / 300
		FillWS.Size = UDim2.new(p, 0, 1, 0)
		WSVal.Text = tostring(math.floor(v))
	end
	local function ApplySpeed(v)
		local c = LocalPlayer.Character
		local h = c and c:FindFirstChild("Humanoid")
		if h then
			if math.abs(h.WalkSpeed - v) > 5 then
				TweenService:Create(h, TweenInfo.new(0.5), { WalkSpeed = v }):Play()
			else
				h.WalkSpeed = v
			end
		end
	end
	local function SetWS(v, up)
		tgtWS = v
		UpdateWSVisual(v)
		if up and isWSEnabled then
			ApplySpeed(v)
		end
	end
	local function ToggleSpeed(forceEnable)
		if forceEnable ~= nil then
			if forceEnable == isWSEnabled then
				return
			end
		end

		local c = LocalPlayer.Character
		local h = c and c:FindFirstChild("Humanoid")
		if not isWSEnabled then
			isWSEnabled = true
			BtnTogWS.Text = "SPEED: ON"
			BtnTogWS.TextColor3 = C_GREEN
			BtnTogWS.UIStroke.Color = C_GREEN
			if h then
				defWS = h.WalkSpeed
			end
			SetWS(tgtWS, true)
			if wsCon then
				wsCon:Disconnect()
			end
			wsCon = RunService.Heartbeat:Connect(function()
				local c = LocalPlayer.Character
				local h = c and c:FindFirstChild("Humanoid")
				if h and math.abs(h.WalkSpeed - tgtWS) > 1 then
					h.WalkSpeed = tgtWS
				end
			end)
			table.insert(Connections, wsCon)
		else
			isWSEnabled = false
			BtnTogWS.Text = "SPEED: OFF"
			BtnTogWS.TextColor3 = C_RED
			BtnTogWS.UIStroke.Color = C_RED
			if wsCon then
				wsCon:Disconnect()
				wsCon = nil
			end
			ApplySpeed(defWS)
			UpdateWSVisual(tgtWS)
		end
	end
	BtnTogWS.MouseButton1Click:Connect(function()
		ToggleSpeed()
	end)
	UIHandlers.ToggleSpeed = ToggleSpeed
	local dragWS = false
	SldWS.MouseButton1Down:Connect(function()
		dragWS = true
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragWS = false
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragWS and i.UserInputType == Enum.UserInputType.MouseMovement then
			local sc = math.clamp((i.Position.X - SldWS.AbsolutePosition.X) / SldWS.AbsoluteSize.X, 0, 1)
			local n = math.floor(sc * 300)
			if isWSEnabled then
				SetWS(n, true)
			else
				UpdateWSVisual(n)
			end
		end
	end)
	WSVal.FocusLost:Connect(function()
		local v = tonumber(WSVal.Text)
		if v then
			if isWSEnabled then
				SetWS(v, true)
			else
				UpdateWSVisual(v)
			end
		else
			WSVal.Text = "16"
		end
	end)

	-- Jump
	local JPVal = Instance.new("TextBox", CardChar)
	JPVal.Text = ""
	JPVal.PlaceholderText = "50"
	JPVal.Size = UDim2.new(0.15, 0, 0, 35)
	JPVal.Position = UDim2.new(0.82, 0, 0, 75)
	JPVal.BackgroundColor3 = C_SIDE
	JPVal.TextColor3 = C_TEXT
	JPVal.Font = Enum.Font.Gotham
	Instance.new("UICorner", JPVal).CornerRadius = UDim.new(0, 6)
	local SldJP = Instance.new("TextButton", CardChar)
	SldJP.Text = ""
	SldJP.Size = UDim2.new(0.55, 0, 0, 6)
	SldJP.Position = UDim2.new(0.25, 0, 0, 90)
	SldJP.BackgroundColor3 = C_SIDE
	SldJP.AutoButtonColor = false
	Instance.new("UICorner", SldJP)
	local FillJP = Instance.new("Frame", SldJP)
	FillJP.Size = UDim2.new(0, 0, 1, 0)
	FillJP.BackgroundColor3 = C_ACCENT
	Instance.new("UICorner", FillJP)
	local BtnTogJP = Instance.new("TextButton", CardChar)
	BtnTogJP.Text = "JUMP: OFF"
	BtnTogJP.Size = UDim2.new(0.2, 0, 0, 35)
	BtnTogJP.Position = UDim2.new(0.03, 0, 0, 75)
	StyleBtn(BtnTogJP, C_RED)
	local isJPEnabled, jpCon, defJP, tgtJP = false, nil, 50, 50
	local function UpdateJPVisual(v)
		v = math.clamp(v, 0, 500)
		local p = v / 500
		FillJP.Size = UDim2.new(p, 0, 1, 0)
		JPVal.Text = tostring(math.floor(v))
	end
	local function ApplyJump(v)
		local c = LocalPlayer.Character
		local h = c and c:FindFirstChild("Humanoid")
		if h then
			h.UseJumpPower = true
			h.JumpPower = v
		end
	end
	local function SetJP(v, up)
		tgtJP = v
		UpdateJPVisual(v)
		if up and isJPEnabled then
			ApplyJump(v)
		end
	end
	local function ToggleJump(forceEnable)
		if forceEnable ~= nil then
			if forceEnable == isJPEnabled then
				return
			end
		end

		local c = LocalPlayer.Character
		local h = c and c:FindFirstChild("Humanoid")
		if not isJPEnabled then
			isJPEnabled = true
			BtnTogJP.Text = "JUMP: ON"
			BtnTogJP.TextColor3 = C_GREEN
			BtnTogJP.UIStroke.Color = C_GREEN
			if h then
				h.UseJumpPower = true
				defJP = h.JumpPower
			end
			SetJP(tgtJP, true)
			if jpCon then
				jpCon:Disconnect()
			end
			jpCon = RunService.Heartbeat:Connect(function()
				local c = LocalPlayer.Character
				local h = c and c:FindFirstChild("Humanoid")
				if h and math.abs(h.JumpPower - tgtJP) > 1 then
					h.UseJumpPower = true
					h.JumpPower = tgtJP
				end
			end)
			table.insert(Connections, jpCon)
		else
			isJPEnabled = false
			BtnTogJP.Text = "JUMP: OFF"
			BtnTogJP.TextColor3 = C_RED
			BtnTogJP.UIStroke.Color = C_RED
			if jpCon then
				jpCon:Disconnect()
				jpCon = nil
			end
			ApplyJump(defJP)
			UpdateJPVisual(tgtJP)
		end
	end
	BtnTogJP.MouseButton1Click:Connect(function()
		ToggleJump()
	end)
	UIHandlers.ToggleJump = ToggleJump
	local dragJP = false
	SldJP.MouseButton1Down:Connect(function()
		dragJP = true
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragJP = false
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragJP and i.UserInputType == Enum.UserInputType.MouseMovement then
			local sc = math.clamp((i.Position.X - SldJP.AbsolutePosition.X) / SldJP.AbsoluteSize.X, 0, 1)
			local n = math.floor(sc * 500)
			if isJPEnabled then
				SetJP(n, true)
			else
				UpdateJPVisual(n)
				tgtJP = n
			end
		end
	end)
	JPVal.FocusLost:Connect(function()
		local v = tonumber(JPVal.Text)
		if v then
			if isJPEnabled then
				SetJP(v, true)
			else
				UpdateJPVisual(v)
				tgtJP = v
			end
		else
			JPVal.Text = "50"
		end
	end)

	-- Inf Jump
	local BtnInfJump = Instance.new("TextButton", CardChar)
	BtnInfJump.Text = "INFINITE JUMP: OFF"
	BtnInfJump.Size = UDim2.new(0.94, 0, 0, 30)
	BtnInfJump.Position = UDim2.new(0.03, 0, 0, 115)
	StyleBtn(BtnInfJump, C_TEXT_DIM)
	local isInfJump, infJumpCon = false, nil
	local function ToggleInfJump(forceEnable)
		if forceEnable ~= nil then
			if forceEnable == isInfJump then
				return
			end
		end

		isInfJump = not isInfJump
		BtnInfJump.Text = "INFINITE JUMP: " .. (isInfJump and "ON" or "OFF")
		BtnInfJump.TextColor3 = isInfJump and C_GREEN or C_TEXT_DIM
		BtnInfJump.UIStroke.Color = isInfJump and C_GREEN or C_TEXT_DIM
		if isInfJump then
			infJumpCon = UserInputService.JumpRequest:Connect(function()
				local c = LocalPlayer.Character
				if c then
					local h = c:FindFirstChildOfClass("Humanoid")
					if h then
						h:ChangeState("Jumping")
					end
				end
			end)
			table.insert(Connections, infJumpCon)
		else
			if infJumpCon then
				infJumpCon:Disconnect()
				infJumpCon = nil
			end
		end
	end
	BtnInfJump.MouseButton1Click:Connect(function()
		ToggleInfJump()
	end)
	UIHandlers.ToggleInfJump = ToggleInfJump

	-- Fly
	local BtnFly = Instance.new("TextButton", CardChar)
	BtnFly.Text = "Fly: OFF"
	BtnFly.Size = UDim2.new(0.45, 0, 0, 35)
	BtnFly.Position = UDim2.new(0.03, 0, 0, 150)
	StyleBtn(BtnFly, C_TEXT_DIM)
	local InpFlySpd = Instance.new("TextBox", CardChar)
	InpFlySpd.PlaceholderText = "Spd"
	InpFlySpd.Text = "50"
	InpFlySpd.Size = UDim2.new(0.45, 0, 0, 35)
	InpFlySpd.Position = UDim2.new(0.52, 0, 0, 150)
	InpFlySpd.BackgroundColor3 = C_SIDE
	InpFlySpd.TextColor3 = C_TEXT
	InpFlySpd.Font = Enum.Font.Gotham
	Instance.new("UICorner", InpFlySpd).CornerRadius = UDim.new(0, 6)
	local FlySpeed, isFlying = 50, false
	InpFlySpd.FocusLost:Connect(function()
		FlySpeed = tonumber(InpFlySpd.Text) or 50
	end)

	local function StopFly()
		isFlying = false
		BtnFly.Text = "Fly: OFF"
		BtnFly.TextColor3 = C_TEXT_DIM
		BtnFly.UIStroke.Color = C_TEXT_DIM
		local c = LocalPlayer.Character
		if c then
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				for _, x in pairs(r:GetChildren()) do
					if x.Name == "AmethystFlyVel" or x.Name == "AmethystFlyGyro" then
						x:Destroy()
					end
				end
			end
			local h = c:FindFirstChild("Humanoid")
			if h then
				h.PlatformStand = false
			end
		end
		if Connections.FlyLoop then
			Connections.FlyLoop:Disconnect()
		end
	end

	local function StartFly()
		local c = LocalPlayer.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChild("Humanoid")
		if not c or not r or not h then
			return
		end
		isFlying = true
		BtnFly.Text = "Fly: ON"
		BtnFly.TextColor3 = C_GREEN
		BtnFly.UIStroke.Color = C_GREEN
		h.PlatformStand = true
		local bv = Instance.new("BodyVelocity", r)
		bv.Name = "AmethystFlyVel"
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.Velocity = Vector3.new(0, 0, 0)
		local bg = Instance.new("BodyGyro", r)
		bg.Name = "AmethystFlyGyro"
		bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		bg.P = 10000
		bg.D = 1000

		local flyLoop = game:GetService("RunService").RenderStepped:Connect(function()
			if not isFlying or not c.Parent then
				StopFly()
				return
			end
			local cam = workspace.CurrentCamera
			local m = Vector3.new(0, 0, 0)
			local k = UserInputService:GetKeysPressed()
			local W, A, S, D = false, false, false, false
			for _, key in pairs(k) do
				if key.KeyCode == Enum.KeyCode.W then
					W = true
				elseif key.KeyCode == Enum.KeyCode.A then
					A = true
				elseif key.KeyCode == Enum.KeyCode.S then
					S = true
				elseif key.KeyCode == Enum.KeyCode.D then
					D = true
				end
			end
			if W then
				m = m + cam.CFrame.LookVector
			end
			if S then
				m = m - cam.CFrame.LookVector
			end
			if A then
				m = m - cam.CFrame.RightVector
			end
			if D then
				m = m + cam.CFrame.RightVector
			end
			bg.CFrame = cam.CFrame
			bv.Velocity = m * FlySpeed
		end)

		Connections.FlyLoop = flyLoop
	end

	local function ToggleFly(forceEnable)
		if forceEnable ~= nil then
			if forceEnable == isFlying then
				return
			end
		end

		if isFlying then
			StopFly()
		else
			StartFly()
		end
	end
	BtnFly.MouseButton1Click:Connect(function()
		ToggleFly()
	end)
	UIHandlers.ToggleFly = ToggleFly

	-- 4. JUMP ASSIST
	do
		local CardJump = CreateCard("JUMP ASSIST", 170, 4)

		-- Auto Jump
		local BtnAutoJump = Instance.new("TextButton", CardJump)
		BtnAutoJump.Text = "AUTO JUMP: OFF"
		BtnAutoJump.Size = UDim2.new(0.45, 0, 0, 35)
		BtnAutoJump.Position = UDim2.new(0.03, 0, 0, 35)
		StyleBtn(BtnAutoJump, C_TEXT_DIM)

		local isAutoJump, autoJumpLoop = false, nil

		local function ToggleAutoJump(forceEnable)
			-- Support forceEnable parameter for auto-enable
			if forceEnable ~= nil then
				if forceEnable == isAutoJump then
					return
				end
			end

			isAutoJump = not isAutoJump
			BtnAutoJump.Text = "AUTO JUMP: " .. (isAutoJump and "ON" or "OFF")
			BtnAutoJump.TextColor3 = isAutoJump and C_GREEN or C_TEXT_DIM
			BtnAutoJump.UIStroke.Color = isAutoJump and C_GREEN or C_TEXT_DIM

			if isAutoJump then
				autoJumpLoop = RunService.Heartbeat:Connect(function()
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChild("Humanoid")
					if h and h.FloorMaterial ~= Enum.Material.Air then
						h:ChangeState(Enum.HumanoidStateType.Jumping)
					end
				end)
				table.insert(Connections, autoJumpLoop)
			else
				if autoJumpLoop then
					autoJumpLoop:Disconnect()
					autoJumpLoop = nil
				end
			end
		end

		BtnAutoJump.MouseButton1Click:Connect(function()
			ToggleAutoJump()
		end)
		UIHandlers.ToggleAutoJump = ToggleAutoJump

		-- Long Jump
		local BtnLongJump = Instance.new("TextButton", CardJump)
		BtnLongJump.Text = "LONG JUMP: OFF"
		BtnLongJump.Size = UDim2.new(0.45, 0, 0, 35)
		BtnLongJump.Position = UDim2.new(0.52, 0, 0, 35)
		StyleBtn(BtnLongJump, C_TEXT_DIM)

		-- Power Slider
		local LblPower = Instance.new("TextLabel", CardJump)
		LblPower.Text = "POWER: " .. (Config.LongJumpPower or 50)
		LblPower.Size = UDim2.new(1, -20, 0, 20)
		LblPower.Position = UDim2.new(0, 15, 0, 80)
		LblPower.BackgroundTransparency = 1
		LblPower.TextColor3 = C_TEXT_DIM
		LblPower.Font = Enum.Font.GothamBold
		LblPower.TextSize = 10
		LblPower.TextXAlignment = Enum.TextXAlignment.Left

		local SldPowerBg = Instance.new("TextButton", CardJump)
		SldPowerBg.Text = ""
		SldPowerBg.Size = UDim2.new(0.9, 0, 0, 6)
		SldPowerBg.Position = UDim2.new(0.05, 0, 0, 100)
		SldPowerBg.BackgroundColor3 = C_SIDE
		SldPowerBg.AutoButtonColor = false
		Instance.new("UICorner", SldPowerBg).CornerRadius = UDim.new(0, 3)

		local SldPowerFill = Instance.new("Frame", SldPowerBg)
		SldPowerFill.Size = UDim2.new((Config.LongJumpPower or 50) / 200, 0, 1, 0)
		SldPowerFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldPowerFill).CornerRadius = UDim.new(0, 3)

		local function UpdatePowerSlider(input)
			local rx = input.Position.X - SldPowerBg.AbsolutePosition.X
			local sc = math.clamp(rx / SldPowerBg.AbsoluteSize.X, 0, 1)
			Config.LongJumpPower = math.floor(sc * 200) -- 0 to 200
			SldPowerFill.Size = UDim2.new(sc, 0, 1, 0)
			LblPower.Text = "POWER: " .. Config.LongJumpPower
		end

		local draggingPower = false
		SldPowerBg.MouseButton1Down:Connect(function()
			draggingPower = true
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingPower = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if draggingPower and input.UserInputType == Enum.UserInputType.MouseMovement then
				UpdatePowerSlider(input)
			end
		end)

		local isLongJump, longJumpLoop = false, nil
		local function ToggleLongJump(forceEnable)
			if forceEnable ~= nil then
				if forceEnable == isLongJump then
					return
				end
			end

			isLongJump = not isLongJump
			BtnLongJump.Text = "LONG JUMP: " .. (isLongJump and "ON" or "OFF")
			BtnLongJump.TextColor3 = isLongJump and C_GREEN or C_TEXT_DIM
			BtnLongJump.UIStroke.Color = isLongJump and C_GREEN or C_TEXT_DIM

			if isLongJump then
				local lastState = Enum.HumanoidStateType.None
				longJumpLoop = RunService.Heartbeat:Connect(function()
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChild("Humanoid")
					local r = c and c:FindFirstChild("HumanoidRootPart")

					if h and r then
						local state = h:GetState()
						if state == Enum.HumanoidStateType.Jumping and lastState ~= Enum.HumanoidStateType.Jumping then
							local dir = r.CFrame.LookVector
							if h.MoveDirection.Magnitude > 0 then
								dir = h.MoveDirection
							end
							r.AssemblyLinearVelocity = Vector3.new(
								dir.X * (Config.LongJumpPower or 50),
								r.AssemblyLinearVelocity.Y,
								dir.Z * (Config.LongJumpPower or 50)
							)
						end
						lastState = state
					end
				end)
				table.insert(Connections, longJumpLoop)
			else
				if longJumpLoop then
					longJumpLoop:Disconnect()
					longJumpLoop = nil
				end
			end
		end

		BtnLongJump.MouseButton1Click:Connect(function()
			ToggleLongJump()
		end)
		UIHandlers.ToggleLongJump = ToggleLongJump

		-- Air Lock Rotation
		local BtnAirLock = Instance.new("TextButton", CardJump)
		BtnAirLock.Text = "AIR LOCK: OFF"
		BtnAirLock.Size = UDim2.new(0.94, 0, 0, 35)
		BtnAirLock.Position = UDim2.new(0.03, 0, 0, 120)
		StyleBtn(BtnAirLock, C_TEXT_DIM)

		local isAirLock, airLockLoop = false, nil
		local function ToggleAirLock(forceEnable)
			if forceEnable ~= nil then
				if forceEnable == isAirLock then
					return
				end
			end

			isAirLock = not isAirLock
			BtnAirLock.Text = "AIR LOCK: " .. (isAirLock and "ON" or "OFF")
			BtnAirLock.TextColor3 = isAirLock and C_GREEN or C_TEXT_DIM
			BtnAirLock.UIStroke.Color = isAirLock and C_GREEN or C_TEXT_DIM

			if isAirLock then
				airLockLoop = RunService.RenderStepped:Connect(function()
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChild("Humanoid")
					local r = c and c:FindFirstChild("HumanoidRootPart")

					if h and r then
						local state = h:GetState()
						if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
							h.AutoRotate = false
							local camCF = workspace.CurrentCamera.CFrame
							local look = camCF.LookVector
							local targetCF = CFrame.lookAt(r.Position, r.Position + Vector3.new(look.X, 0, look.Z))
							r.CFrame = r.CFrame:Lerp(targetCF, 0.5)
						else
							h.AutoRotate = true
						end
					end
				end)
				table.insert(Connections, airLockLoop)
			else
				if airLockLoop then
					airLockLoop:Disconnect()
					airLockLoop = nil
				end
				local c = LocalPlayer.Character
				local h = c and c:FindFirstChild("Humanoid")
				if h then
					h.AutoRotate = true
				end
			end
		end
		BtnAirLock.MouseButton1Click:Connect(function()
			ToggleAirLock()
		end)
		UIHandlers.ToggleAirLock = ToggleAirLock
	end

	-- 1. ALWAYS MOMENTUM
	local CardMomentum = CreateCard("ALWAYS MOMENTUM", 80, 1)

	local BtnMomentum = Instance.new("TextButton", CardMomentum)
	BtnMomentum.Text = "ALWAYS MOMENTUM: OFF"
	BtnMomentum.Size = UDim2.new(0.94, 0, 0, 35)
	BtnMomentum.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnMomentum, C_TEXT_DIM)

	local isMomentum, momentumLoop = false, nil
	local lockedSpeed = nil
	local momentumHUD = nil

	local function CreateMomentumHUD()
		if momentumHUD then
			return
		end
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "MomentumHUD"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

		local frame = Instance.new("Frame", screenGui)
		frame.Name = "HUDFrame"
		frame.Size = UDim2.new(0, 160, 0, 55)
		frame.Position = UDim2.new(0.5, -80, 1, -70)
		frame.AnchorPoint = Vector2.new(0.5, 1)
		frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
		frame.BackgroundTransparency = 0.3
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
		local stroke = Instance.new("UIStroke", frame)
		stroke.Color = C_ACCENT
		stroke.Transparency = 0.5

		local title = Instance.new("TextLabel", frame)
		title.Name = "Title"
		title.Text = "MOMENTUM"
		title.Size = UDim2.new(1, 0, 0, 18)
		title.Position = UDim2.new(0, 0, 0, 3)
		title.BackgroundTransparency = 1
		title.TextColor3 = C_ACCENT
		title.Font = Enum.Font.GothamBold
		title.TextSize = 10

		local speedLabel = Instance.new("TextLabel", frame)
		speedLabel.Name = "Speed"
		speedLabel.Text = "0"
		speedLabel.Size = UDim2.new(1, 0, 0, 22)
		speedLabel.Position = UDim2.new(0, 0, 0, 20)
		speedLabel.BackgroundTransparency = 1
		speedLabel.TextColor3 = C_GREEN
		speedLabel.Font = Enum.Font.GothamBlack
		speedLabel.TextSize = 20

		local lockLabel = Instance.new("TextLabel", frame)
		lockLabel.Name = "Lock"
		lockLabel.Text = "LOCKED: --"
		lockLabel.Size = UDim2.new(1, 0, 0, 12)
		lockLabel.Position = UDim2.new(0, 0, 0, 42)
		lockLabel.BackgroundTransparency = 1
		lockLabel.TextColor3 = C_TEXT_DIM
		lockLabel.Font = Enum.Font.Gotham
		lockLabel.TextSize = 9

		momentumHUD = screenGui
	end

	local function DestroyMomentumHUD()
		if momentumHUD then
			momentumHUD:Destroy()
			momentumHUD = nil
		end
	end

	local function UpdateMomentumHUD(currentSpeed, locked)
		if not momentumHUD then
			return
		end
		local frame = momentumHUD:FindFirstChild("HUDFrame")
		if not frame then
			return
		end

		local speedLbl = frame:FindFirstChild("Speed")
		local lockLbl = frame:FindFirstChild("Lock")

		if speedLbl then
			speedLbl.Text = string.format("%.1f", currentSpeed or 0)
		end

		if lockLbl then
			if locked then
				lockLbl.Text = string.format("LOCKED: %.1f", locked)
			else
				lockLbl.Text = "LOCKED: --"
			end
		end
	end

	local function ToggleMomentum(forceEnable)
		if forceEnable ~= nil then
			if forceEnable == isMomentum then
				return
			end
		end

		isMomentum = not isMomentum
		BtnMomentum.Text = "ALWAYS MOMENTUM: " .. (isMomentum and "ON" or "OFF")
		BtnMomentum.TextColor3 = isMomentum and C_GREEN or C_TEXT_DIM
		BtnMomentum.UIStroke.Color = isMomentum and C_GREEN or C_TEXT_DIM

		if isMomentum then
			lockedSpeed = nil
			CreateMomentumHUD()
			momentumLoop = RunService.Heartbeat:Connect(function()
				local c = LocalPlayer.Character
				local h = c and c:FindFirstChild("Humanoid")
				local r = c and c:FindFirstChild("HumanoidRootPart")

				if h and r and h.MoveDirection.Magnitude > 0.1 then
					local vel = r.AssemblyLinearVelocity
					local horizontalSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude

					if lockedSpeed == nil then
						lockedSpeed = horizontalSpeed
					end

					if horizontalSpeed < lockedSpeed then
						local moveDir = h.MoveDirection.Unit
						r.AssemblyLinearVelocity = Vector3.new(moveDir.X * lockedSpeed, vel.Y, moveDir.Z * lockedSpeed)
					elseif horizontalSpeed > lockedSpeed + 1 then
						lockedSpeed = lockedSpeed + 1
					end

					UpdateMomentumHUD(horizontalSpeed, lockedSpeed)
				else
					lockedSpeed = nil
					UpdateMomentumHUD(0, nil)
				end
			end)
			table.insert(Connections, momentumLoop)
		else
			if momentumLoop then
				momentumLoop:Disconnect()
				momentumLoop = nil
			end
			lockedSpeed = nil
			DestroyMomentumHUD()
		end
	end

	BtnMomentum.MouseButton1Click:Connect(function()
		ToggleMomentum()
	end)
	UIHandlers.ToggleMomentum = ToggleMomentum

	-- 2. ANTI-SLIP
	local CardSlip = CreateCard("ANTI-SLIP", 135, 2)

	local BtnSlip = Instance.new("TextButton", CardSlip)
	BtnSlip.Text = "ANTI-SLIP: OFF"
	BtnSlip.Size = UDim2.new(0.94, 0, 0, 35)
	BtnSlip.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnSlip, C_RED)

	-- Size Slider
	local LblSize = Instance.new("TextLabel", CardSlip)
	LblSize.Text = "SIZE: 0.5"
	LblSize.Size = UDim2.new(1, -20, 0, 20)
	LblSize.Position = UDim2.new(0, 15, 0, 80)
	LblSize.BackgroundTransparency = 1
	LblSize.TextColor3 = C_TEXT_DIM
	LblSize.Font = Enum.Font.GothamBold
	LblSize.TextSize = 10
	LblSize.TextXAlignment = Enum.TextXAlignment.Left

	local SldBg = Instance.new("TextButton", CardSlip)
	SldBg.Text = ""
	SldBg.Size = UDim2.new(0.9, 0, 0, 6)
	SldBg.Position = UDim2.new(0.05, 0, 0, 100)
	SldBg.BackgroundColor3 = C_SIDE
	SldBg.AutoButtonColor = false
	Instance.new("UICorner", SldBg).CornerRadius = UDim.new(0, 3)

	local SldFill = Instance.new("Frame", SldBg)
	SldFill.Size = UDim2.new(0.3, 0, 1, 0) -- Default 30% = size 3
	SldFill.BackgroundColor3 = C_ACCENT
	Instance.new("UICorner", SldFill).CornerRadius = UDim.new(0, 3)

	local targetSize = 3 -- Default size 3 studs
	local isSlipOn = false
	local slipLoop = nil
	local modifiedParts = {}

	LblSize.Text = "SIZE: 3.0" -- Update default label

	local function UpdateSlider(input)
		local rx = input.Position.X - SldBg.AbsolutePosition.X
		local sc = math.clamp(rx / SldBg.AbsoluteSize.X, 0, 1)
		targetSize = 1 + (sc * 9) -- Range 1-10 studs
		SldFill.Size = UDim2.new(sc, 0, 1, 0)
		LblSize.Text = string.format("SIZE: %.1f", targetSize)
	end

	local dragging = false
	SldBg.MouseButton1Down:Connect(function()
		dragging = true
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			UpdateSlider(i)
		end
	end)

	local lastSafeY = nil
	local lastGroundPart = nil
	local visualPart = nil

	local function ToggleAntiSlip(forceEnable)
		if forceEnable ~= nil then
			if forceEnable == isSlipOn then
				return
			end
		end

		isSlipOn = not isSlipOn
		BtnSlip.Text = "ANTI-SLIP: " .. (isSlipOn and "ON" or "OFF")
		BtnSlip.TextColor3 = isSlipOn and C_GREEN or C_RED
		BtnSlip.UIStroke.Color = isSlipOn and C_GREEN or C_RED

		if isSlipOn then
			lastSafeY = nil
			lastGroundPart = nil

			-- Create visual indicator
			visualPart = Instance.new("Part")
			visualPart.Name = "StarshipAntiSlipVisual"
			visualPart.Anchored = true
			visualPart.CanCollide = false
			visualPart.CanQuery = false
			visualPart.CanTouch = false
			visualPart.Transparency = 0.5
			visualPart.Color = Color3.fromRGB(0, 255, 100)
			visualPart.Material = Enum.Material.Neon
			visualPart.Size = Vector3.new(targetSize, 0.1, targetSize)
			visualPart.CastShadow = false
			visualPart.Parent = workspace

			slipLoop = RunService.Heartbeat:Connect(function()
				local c = LocalPlayer.Character
				if not c then
					return
				end

				local r = c:FindFirstChild("HumanoidRootPart")
				local h = c:FindFirstChild("Humanoid")
				if not r or not h then
					return
				end

				local params = RaycastParams.new()
				params.FilterDescendantsInstances = { c, visualPart }
				params.FilterType = Enum.RaycastFilterType.Exclude

				local playerPos = r.Position
				local halfSize = targetSize / 2

				-- Multi-raycast untuk mencari ground dalam radius
				local rayPositions = {
					playerPos,
					playerPos + Vector3.new(halfSize, 0, 0),
					playerPos + Vector3.new(-halfSize, 0, 0),
					playerPos + Vector3.new(0, 0, halfSize),
					playerPos + Vector3.new(0, 0, -halfSize),
					playerPos + Vector3.new(halfSize, 0, halfSize),
					playerPos + Vector3.new(-halfSize, 0, halfSize),
					playerPos + Vector3.new(halfSize, 0, -halfSize),
					playerPos + Vector3.new(-halfSize, 0, -halfSize),
				}

				local foundGround = false
				local highestY = -math.huge

				for _, pos in ipairs(rayPositions) do
					local ray = workspace:Raycast(pos, Vector3.new(0, -50, 0), params)
					if ray and ray.Instance and not ray.Instance:IsA("Terrain") then
						foundGround = true
						if ray.Position.Y > highestY then
							highestY = ray.Position.Y
							lastGroundPart = ray.Instance
						end
					end
				end

				if foundGround then
					lastSafeY = highestY + 3

					-- Update visual
					if visualPart then
						visualPart.Size = Vector3.new(targetSize, 0.1, targetSize)
						visualPart.CFrame = CFrame.new(playerPos.X, highestY + 0.05, playerPos.Z)
					end
				else
					if visualPart then
						visualPart.Position = Vector3.new(0, -9999, 0)
					end
				end

				-- Keep player from falling - but allow jumping
				if lastSafeY then
					local vel = r.AssemblyLinearVelocity
					local state = h:GetState()
					local isJumping = state == Enum.HumanoidStateType.Jumping or vel.Y > 1

					if not isJumping and r.Position.Y < lastSafeY - 0.3 and vel.Y < 0 then
						r.CFrame = CFrame.new(r.Position.X, lastSafeY, r.Position.Z) * (r.CFrame - r.CFrame.Position)
						r.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
						h:ChangeState(Enum.HumanoidStateType.Running)
					end
				end
			end)
			table.insert(Connections, slipLoop)
		else
			if slipLoop then
				slipLoop:Disconnect()
				slipLoop = nil
			end
			lastSafeY = nil
			lastGroundPart = nil

			-- Remove visual part
			if visualPart then
				visualPart:Destroy()
				visualPart = nil
			end

			modifiedParts = {}
		end
	end
	BtnSlip.MouseButton1Click:Connect(function()
		ToggleAntiSlip()
	end)
	UIHandlers.ToggleAntiSlip = ToggleAntiSlip

	-- 3. ANTI-RAGDOLL
	local CardRagdoll = CreateCard("ANTI-RAGDOLL", 135, 3)

	local BtnRagdoll = Instance.new("TextButton", CardRagdoll)
	BtnRagdoll.Text = "ANTI-RAGDOLL: OFF"
	BtnRagdoll.Size = UDim2.new(0.94, 0, 0, 35)
	BtnRagdoll.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnRagdoll, C_RED)

	-- Max Velocity Slider
	local LblMaxVel = Instance.new("TextLabel", CardRagdoll)
	LblMaxVel.Text = "MAX VELOCITY: 100"
	LblMaxVel.Size = UDim2.new(1, -20, 0, 20)
	LblMaxVel.Position = UDim2.new(0, 15, 0, 80)
	LblMaxVel.BackgroundTransparency = 1
	LblMaxVel.TextColor3 = C_TEXT_DIM
	LblMaxVel.Font = Enum.Font.GothamBold
	LblMaxVel.TextSize = 10
	LblMaxVel.TextXAlignment = Enum.TextXAlignment.Left

	local SldVelBg = Instance.new("TextButton", CardRagdoll)
	SldVelBg.Text = ""
	SldVelBg.Size = UDim2.new(0.9, 0, 0, 6)
	SldVelBg.Position = UDim2.new(0.05, 0, 0, 100)
	SldVelBg.BackgroundColor3 = C_SIDE
	SldVelBg.AutoButtonColor = false
	Instance.new("UICorner", SldVelBg).CornerRadius = UDim.new(0, 3)

	local SldVelFill = Instance.new("Frame", SldVelBg)
	SldVelFill.Size = UDim2.new(0.5, 0, 1, 0) -- Default 50% = 100
	SldVelFill.BackgroundColor3 = C_ACCENT
	Instance.new("UICorner", SldVelFill).CornerRadius = UDim.new(0, 3)

	local maxVelocity = 100 -- Default max velocity
	local isRagdollOn = false
	local ragdollLoop = nil
	local stateConnection = nil

	local function UpdateVelSlider(input)
		local rx = input.Position.X - SldVelBg.AbsolutePosition.X
		local sc = math.clamp(rx / SldVelBg.AbsoluteSize.X, 0, 1)
		maxVelocity = math.floor(50 + (sc * 150)) -- Range 50-200
		SldVelFill.Size = UDim2.new(sc, 0, 1, 0)
		LblMaxVel.Text = "MAX VELOCITY: " .. maxVelocity
	end

	local draggingVel = false
	SldVelBg.MouseButton1Down:Connect(function()
		draggingVel = true
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingVel = false
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if draggingVel and i.UserInputType == Enum.UserInputType.MouseMovement then
			UpdateVelSlider(i)
		end
	end)

	local function ToggleAntiRagdoll(forceEnable)
		if forceEnable ~= nil then
			if forceEnable == isRagdollOn then
				return
			end
		end

		isRagdollOn = not isRagdollOn
		BtnRagdoll.Text = "ANTI-RAGDOLL: " .. (isRagdollOn and "ON" or "OFF")
		BtnRagdoll.TextColor3 = isRagdollOn and C_GREEN or C_RED
		BtnRagdoll.UIStroke.Color = isRagdollOn and C_GREEN or C_RED

		if isRagdollOn then
			local c = LocalPlayer.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")

			if h then
				-- Disable ragdoll states
				h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
				h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

				-- Listen for state changes to force recovery
				stateConnection = h.StateChanged:Connect(function(oldState, newState)
					if newState == Enum.HumanoidStateType.Ragdoll or newState == Enum.HumanoidStateType.FallingDown then
						h:ChangeState(Enum.HumanoidStateType.GettingUp)
						task.wait(0.1)
						h:ChangeState(Enum.HumanoidStateType.Running)
					end
				end)
				table.insert(Connections, stateConnection)
			end

			-- Velocity clamp loop
			ragdollLoop = RunService.Heartbeat:Connect(function()
				local c = LocalPlayer.Character
				if not c then
					return
				end

				local r = c:FindFirstChild("HumanoidRootPart")
				local h = c:FindFirstChildOfClass("Humanoid")
				if not r or not h then
					return
				end

				-- Ensure states stay disabled
				if h:GetStateEnabled(Enum.HumanoidStateType.Ragdoll) then
					h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
				end
				if h:GetStateEnabled(Enum.HumanoidStateType.FallingDown) then
					h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				end

				-- Clamp velocity to prevent fling
				local vel = r.AssemblyLinearVelocity
				local horizontalVel = Vector3.new(vel.X, 0, vel.Z)
				local horizontalSpeed = horizontalVel.Magnitude

				if horizontalSpeed > maxVelocity then
					local clampedHorizontal = horizontalVel.Unit * maxVelocity
					r.AssemblyLinearVelocity = Vector3.new(clampedHorizontal.X, vel.Y, clampedHorizontal.Z)
				end

				-- Clamp vertical velocity (prevent super fling up)
				if vel.Y > maxVelocity then
					r.AssemblyLinearVelocity = Vector3.new(vel.X, maxVelocity, vel.Z)
				end

				-- Force recovery if somehow in ragdoll
				local state = h:GetState()
				if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
					h:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
			end)
			table.insert(Connections, ragdollLoop)

			-- Handle respawn
			LocalPlayer.CharacterAdded:Connect(function(newChar)
				if not isRagdollOn then
					return
				end
				task.wait(0.5)
				local newHum = newChar:FindFirstChildOfClass("Humanoid")
				if newHum then
					newHum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
					newHum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				end
			end)
		else
			-- Disable
			if ragdollLoop then
				ragdollLoop:Disconnect()
				ragdollLoop = nil
			end
			if stateConnection then
				stateConnection:Disconnect()
				stateConnection = nil
			end

			-- Re-enable states
			local c = LocalPlayer.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if h then
				h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
				h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			end
		end
	end

	BtnRagdoll.MouseButton1Click:Connect(function()
		ToggleAntiRagdoll()
	end)
	UIHandlers.ToggleAntiRagdoll = ToggleAntiRagdoll

	-- 5. REAL PATH ESP
	local CardESP = CreateCard("REAL PATH ESP", 160, 5)

	local BtnRealESP = Instance.new("TextButton", CardESP)
	BtnRealESP.Text = "REAL PATH ESP: OFF"
	BtnRealESP.Size = UDim2.new(0.94, 0, 0, 35)
	BtnRealESP.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnRealESP, C_RED)

	-- Color Legend
	local LblLegend = Instance.new("TextLabel", CardESP)
	LblLegend.Text = "COLOR INFO (Range: 75 studs):"
	LblLegend.Size = UDim2.new(0.94, 0, 0, 18)
	LblLegend.Position = UDim2.new(0.03, 0, 0, 75)
	LblLegend.BackgroundTransparency = 1
	LblLegend.TextColor3 = C_TEXT_DIM
	LblLegend.TextSize = 12
	LblLegend.Font = Enum.Font.GothamBold
	LblLegend.TextXAlignment = Enum.TextXAlignment.Left

	local LblGreen = Instance.new("TextLabel", CardESP)
	LblGreen.Text = "● GREEN = SAFE (CanCollide ON)"
	LblGreen.Size = UDim2.new(0.94, 0, 0, 14)
	LblGreen.Position = UDim2.new(0.03, 0, 0, 91)
	LblGreen.BackgroundTransparency = 1
	LblGreen.TextColor3 = Color3.new(0, 1, 0)
	LblGreen.TextSize = 10
	LblGreen.Font = Enum.Font.Gotham
	LblGreen.TextXAlignment = Enum.TextXAlignment.Left

	local LblCyan = Instance.new("TextLabel", CardESP)
	LblCyan.Text = "● CYAN = Ladder WALKABLE (CanCollide ON)"
	LblCyan.Size = UDim2.new(0.94, 0, 0, 14)
	LblCyan.Position = UDim2.new(0.03, 0, 0, 105)
	LblCyan.BackgroundTransparency = 1
	LblCyan.TextColor3 = Color3.fromRGB(0, 255, 255)
	LblCyan.TextSize = 10
	LblCyan.Font = Enum.Font.Gotham
	LblCyan.TextXAlignment = Enum.TextXAlignment.Left

	local LblOrange = Instance.new("TextLabel", CardESP)
	LblOrange.Text = "● ORANGE = Ladder NOT WALKABLE (CanCollide OFF)"
	LblOrange.Size = UDim2.new(0.94, 0, 0, 14)
	LblOrange.Position = UDim2.new(0.03, 0, 0, 119)
	LblOrange.BackgroundTransparency = 1
	LblOrange.TextColor3 = Color3.fromRGB(255, 165, 0)
	LblOrange.TextSize = 10
	LblOrange.Font = Enum.Font.Gotham
	LblOrange.TextXAlignment = Enum.TextXAlignment.Left

	local LblRed = Instance.new("TextLabel", CardESP)
	LblRed.Text = "● RED = FAKE (CanCollide OFF - Will Fall!)"
	LblRed.Size = UDim2.new(0.94, 0, 0, 14)
	LblRed.Position = UDim2.new(0.03, 0, 0, 133)
	LblRed.BackgroundTransparency = 1
	LblRed.TextColor3 = Color3.new(1, 0, 0)
	LblRed.TextSize = 10
	LblRed.Font = Enum.Font.Gotham
	LblRed.TextXAlignment = Enum.TextXAlignment.Left

	local isRealESP, espLoop = false, nil
	local espContainer = Instance.new("Folder", workspace)
	espContainer.Name = "StarshipESP"
	local highlightedParts = {} -- Track highlighted parts by reference

	-- Check if part has decal/texture (invisible but has sticker) - GLOBAL
	local function HasDecalOrTexture(part)
		for _, child in pairs(part:GetChildren()) do
			if child:IsA("Decal") or child:IsA("Texture") or child:IsA("SurfaceGui") then
				return true
			end
		end
		return false
	end

	-- Simple check: CanCollide = walkable
	local function IsPlatformWalkable(part)
		return part.CanCollide == true
	end

	local function CreateHighlight(part, color)
		if highlightedParts[part] then
			return
		end
		highlightedParts[part] = true

		local h = Instance.new("BoxHandleAdornment")
		h.Name = "ESP_" .. tostring(part:GetDebugId())
		h.Adornee = part
		h.Size = part.Size + Vector3.new(0.1, 0.1, 0.1)
		h.Color3 = color
		h.Transparency = 0.5
		h.ZIndex = 0
		h.AlwaysOnTop = true
		h.Parent = espContainer
		part.AncestryChanged:Connect(function()
			if not part:IsDescendantOf(game) then
				h:Destroy()
				highlightedParts[part] = nil
			end
		end)
	end

	local function ToggleRealESP(forceEnable)
		if forceEnable ~= nil then
			if forceEnable == isRealESP then
				return
			end
		end

		isRealESP = not isRealESP
		BtnRealESP.Text = "REAL PATH ESP: " .. (isRealESP and "ON" or "OFF")
		BtnRealESP.TextColor3 = isRealESP and C_GREEN or C_RED
		BtnRealESP.UIStroke.Color = isRealESP and C_GREEN or C_RED

		if isRealESP then
			-- Scan and test each platform with raycast
			local function ScanAllParts(charPos, range)
				for _, p in pairs(workspace:GetDescendants()) do
					if p:IsA("BasePart") then
						-- Include: visible parts OR invisible parts with decal/texture OR any CanCollide part
						local shouldInclude = p.Transparency < 0.95 or HasDecalOrTexture(p) or p.CanCollide

						if shouldInclude then
							-- Skip character parts and ESP container
							local isCharPart = p:FindFirstAncestorOfClass("Model")
								and p:FindFirstAncestorOfClass("Model"):FindFirstChild("Humanoid")
							if not isCharPart and not p:IsDescendantOf(espContainer) then
								local dist = (p.Position - charPos).Magnitude
								if dist <= range then
									local color
									local isLadder = p:IsA("TrussPart")
										or p.Name:lower():find("ladder")
										or p.Name:lower():find("truss")
										or p.Name:lower():find("climb")

									if isLadder then
										if p.CanCollide then
											color = Color3.fromRGB(0, 255, 255) -- CYAN = Ladder WALKABLE
										else
											color = Color3.fromRGB(255, 165, 0) -- ORANGE = Ladder NOT WALKABLE
										end
									elseif IsPlatformWalkable(p) then
										color = Color3.new(0, 1, 0) -- Green = SAFE
									else
										color = Color3.new(1, 0, 0) -- Red = NOT SAFE
									end
									CreateHighlight(p, color)
								end
							end
						end
					end
				end
			end

			local c = LocalPlayer.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if r then
				ScanAllParts(r.Position, 75)
			end

			-- Periodic rescan for new parts entering range (every 0.5 sec)
			local lastScan = 0
			espLoop = RunService.Heartbeat:Connect(function()
				local now = tick()
				if now - lastScan < 0.5 then
					return
				end -- Only scan every 0.5 seconds
				lastScan = now

				local c = LocalPlayer.Character
				local r = c and c:FindFirstChild("HumanoidRootPart")
				if r then
					local range = 75
					local params = OverlapParams.new()
					params.FilterDescendantsInstances = { c, espContainer }
					params.FilterType = Enum.RaycastFilterType.Exclude
					local parts = workspace:GetPartBoundsInBox(r.CFrame, Vector3.new(range, range, range), params)
					for _, p in pairs(parts) do
						if p:IsA("BasePart") then
							local shouldInclude = p.Transparency < 0.95 or HasDecalOrTexture(p) or p.CanCollide
							if shouldInclude then
								local isCharPart = p:FindFirstAncestorOfClass("Model")
									and p:FindFirstAncestorOfClass("Model"):FindFirstChild("Humanoid")
								if not isCharPart then
									local color
									local isLadder = p:IsA("TrussPart")
										or p.Name:lower():find("ladder")
										or p.Name:lower():find("truss")
										or p.Name:lower():find("climb")

									if isLadder then
										if p.CanCollide then
											color = Color3.fromRGB(0, 255, 255) -- CYAN = Ladder WALKABLE
										else
											color = Color3.fromRGB(255, 165, 0) -- ORANGE = Ladder NOT WALKABLE
										end
									elseif IsPlatformWalkable(p) then
										color = Color3.new(0, 1, 0)
									else
										color = Color3.new(1, 0, 0)
									end
									CreateHighlight(p, color)
								end
							end
						end
					end
				end
			end)
			table.insert(Connections, espLoop)
		else
			if espLoop then
				espLoop:Disconnect()
				espLoop = nil
			end
			espContainer:ClearAllChildren()
			highlightedParts = {} -- Reset tracking table
		end
	end
	BtnRealESP.MouseButton1Click:Connect(function()
		ToggleRealESP()
	end)
	UIHandlers.ToggleRealESP = ToggleRealESP

	-- 6. GHOST REPLAY
	local CardReplay = CreateCard("GHOST REPLAY", 370, 6)
	local currentWorkspace = "Default"

	local function GetGhostPath()
		local ghostRoot = "StarshipCore/StarshipGhosts"
		if not isfolder(ghostRoot) then
			makefolder(ghostRoot)
		end
		local path = ghostRoot .. "/" .. currentWorkspace
		if not isfolder(path) then
			makefolder(path)
		end
		return path
	end

	local GhostData = {}
	local isGhostRecording = false
	local isGhostPlaying = false
	local ghostRecLoop = nil
	local ghostPlayLoop = nil
	local GhostModel = nil

	-- WORKSPACE SELECTOR
	local LblGWorkspace = Instance.new("TextLabel", CardReplay)
	LblGWorkspace.Text = "WS:"
	LblGWorkspace.Size = UDim2.new(0.15, 0, 0, 25)
	LblGWorkspace.Position = UDim2.new(0.03, 0, 0, 35)
	LblGWorkspace.BackgroundTransparency = 1
	LblGWorkspace.TextColor3 = C_TEXT_DIM
	LblGWorkspace.Font = Enum.Font.GothamBold
	LblGWorkspace.TextSize = 10
	LblGWorkspace.TextXAlignment = Enum.TextXAlignment.Left

	local BtnGWorkspace = Instance.new("TextButton", CardReplay)
	BtnGWorkspace.Text = currentWorkspace
	BtnGWorkspace.Size = UDim2.new(0.75, 0, 0, 25)
	BtnGWorkspace.Position = UDim2.new(0.22, 0, 0, 35)
	BtnGWorkspace.BackgroundColor3 = C_SIDE
	BtnGWorkspace.TextColor3 = C_ACCENT
	BtnGWorkspace.Font = Enum.Font.Gotham
	BtnGWorkspace.TextSize = 11
	Instance.new("UICorner", BtnGWorkspace).CornerRadius = UDim.new(0, 4)
	local sws = Instance.new("UIStroke", BtnGWorkspace)
	sws.Color = C_ACCENT
	sws.Transparency = 0.6
	sws.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local GWSList = Instance.new("Frame", CardReplay)
	GWSList.Size = UDim2.new(0.75, 0, 0, 100)
	GWSList.Position = UDim2.new(0.22, 0, 0, 65)
	GWSList.BackgroundColor3 = C_SIDE
	GWSList.Visible = false
	GWSList.ZIndex = 50
	Instance.new("UICorner", GWSList).CornerRadius = UDim.new(0, 6)
	local sl = Instance.new("UIStroke", GWSList)
	sl.Color = C_ACCENT
	sl.Transparency = 0.6

	local GWSScroll = Instance.new("ScrollingFrame", GWSList)
	GWSScroll.Size = UDim2.new(1, 0, 1, 0)
	GWSScroll.BackgroundTransparency = 1
	GWSScroll.BorderSizePixel = 0
	GWSScroll.ScrollBarThickness = 4
	GWSScroll.ZIndex = 55
	Instance.new("UIListLayout", GWSScroll).Padding = UDim.new(0, 2)

	local function RefreshGhostList() end -- Forward declaration

	local function UpdateGWSList()
		for _, c in pairs(GWSScroll:GetChildren()) do
			if c:IsA("TextButton") or c:IsA("TextBox") then
				c:Destroy()
			end
		end

		-- Path yang benar: StarshipCore/StarshipGhosts
		local ghostRoot = "StarshipCore/StarshipGhosts"
		if not isfolder(ghostRoot) then
			makefolder(ghostRoot)
		end

		-- Input untuk workspace baru
		local NewWSInput = Instance.new("TextBox", GWSScroll)
		NewWSInput.PlaceholderText = "+ New..."
		NewWSInput.Text = ""
		NewWSInput.Size = UDim2.new(1, -5, 0, 25)
		NewWSInput.BackgroundColor3 = C_ITEM
		NewWSInput.TextColor3 = C_TEXT
		NewWSInput.PlaceholderColor3 = C_GREEN
		NewWSInput.Font = Enum.Font.Gotham
		NewWSInput.TextSize = 10
		NewWSInput.ZIndex = 55
		Instance.new("UICorner", NewWSInput).CornerRadius = UDim.new(0, 4)

		NewWSInput.FocusLost:Connect(function(enterPressed)
			if enterPressed and NewWSInput.Text ~= "" then
				local newName = NewWSInput.Text
				local newPath = ghostRoot .. "/" .. newName
				if not isfolder(newPath) then
					makefolder(newPath)
				end
				currentWorkspace = newName
				BtnGWorkspace.Text = currentWorkspace
				GWSList.Visible = false
				RefreshGhostList()
			end
		end)

		if isfolder(ghostRoot) then
			local folders = listfiles(ghostRoot)
			GWSScroll.CanvasSize = UDim2.new(0, 0, 0, (#folders + 1) * 27)
			for _, f in ipairs(folders) do
				if isfolder(f) then
					local n = string.match(f, "[^/\\]+$") or f
					local b = Instance.new("TextButton", GWSScroll)
					b.Text = n
					b.Size = UDim2.new(1, -5, 0, 25)
					b.BackgroundColor3 = C_SIDE
					b.TextColor3 = C_TEXT
					b.Font = Enum.Font.Gotham
					b.TextSize = 10
					b.ZIndex = 55
					Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
					b.MouseButton1Click:Connect(function()
						currentWorkspace = n
						BtnGWorkspace.Text = currentWorkspace
						GWSList.Visible = false
						RefreshGhostList()
					end)
				end
			end
		end
	end

	BtnGWorkspace.MouseButton1Click:Connect(function()
		GWSList.Visible = not GWSList.Visible
		if GWSList.Visible then
			UpdateGWSList()
		end
	end)

	local function StartCountdown(callback)
		local count = 3
		local cdLabel = Instance.new("TextLabel", UI and UI.ScreenGui or PageHelper.Parent.Parent)
		cdLabel.Size = UDim2.new(1, 0, 0, 100)
		cdLabel.Position = UDim2.new(0, 0, 0.4, 0)
		cdLabel.BackgroundTransparency = 1
		cdLabel.TextColor3 = C_ACCENT
		cdLabel.Font = Enum.Font.GothamBlack
		cdLabel.TextSize = 72
		cdLabel.TextStrokeTransparency = 0
		cdLabel.Text = tostring(count)

		local c = LocalPlayer.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = true
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end

		task.spawn(function()
			while count > 0 do
				cdLabel.Text = tostring(count)
				task.wait(1)
				count = count - 1
			end
			if root then
				root.Anchored = false
			end
			cdLabel.Text = "GO!"
			cdLabel.TextColor3 = C_GREEN
			if callback then
				callback()
			end
			task.wait(0.5)
			cdLabel:Destroy()
		end)
	end

	local BtnRecordGhost = Instance.new("TextButton", CardReplay)
	BtnRecordGhost.Text = "RECORD NEW"
	BtnRecordGhost.Size = UDim2.new(0.45, 0, 0, 30)
	BtnRecordGhost.Position = UDim2.new(0.03, 0, 0, 75)
	StyleBtn(BtnRecordGhost, C_TEXT)

	local BtnPlayGhost = Instance.new("TextButton", CardReplay)
	BtnPlayGhost.Text = "PLAY GHOST"
	BtnPlayGhost.Size = UDim2.new(0.45, 0, 0, 30)
	BtnPlayGhost.Position = UDim2.new(0.52, 0, 0, 75)
	StyleBtn(BtnPlayGhost, C_TEXT_DIM)

	local LblGhostStatus = Instance.new("TextLabel", CardReplay)
	LblGhostStatus.Text = "STATUS: IDLE"
	LblGhostStatus.Size = UDim2.new(0.94, 0, 0, 20)
	LblGhostStatus.Position = UDim2.new(0.03, 0, 0, 110)
	LblGhostStatus.BackgroundTransparency = 1
	LblGhostStatus.TextColor3 = C_TEXT_DIM
	LblGhostStatus.Font = Enum.Font.Code

	local InpGhostName = Instance.new("TextBox", CardReplay)
	InpGhostName.PlaceholderText = "Ghost Name..."
	InpGhostName.Size = UDim2.new(0.6, 0, 0, 30)
	InpGhostName.Position = UDim2.new(0.03, 0, 0, 135)
	InpGhostName.BackgroundColor3 = C_SIDE
	InpGhostName.TextColor3 = C_TEXT
	InpGhostName.Font = Enum.Font.Gotham
	InpGhostName.TextSize = 11
	Instance.new("UICorner", InpGhostName).CornerRadius = UDim.new(0, 6)

	local BtnSaveGhost = Instance.new("TextButton", CardReplay)
	BtnSaveGhost.Text = "SAVE"
	BtnSaveGhost.Size = UDim2.new(0.3, 0, 0, 30)
	BtnSaveGhost.Position = UDim2.new(0.67, 0, 0, 135)
	StyleBtn(BtnSaveGhost, C_ACCENT)

	local GhostListScroll = Instance.new("ScrollingFrame", CardReplay)
	GhostListScroll.Size = UDim2.new(0.94, 0, 0, 110)
	GhostListScroll.Position = UDim2.new(0.03, 0, 0, 175)
	GhostListScroll.BackgroundColor3 = C_SIDE
	GhostListScroll.BorderSizePixel = 0
	GhostListScroll.ScrollBarThickness = 4
	Instance.new("UICorner", GhostListScroll).CornerRadius = UDim.new(0, 6)
	Instance.new("UIListLayout", GhostListScroll).Padding = UDim.new(0, 2)

	local BtnRefreshGhost = Instance.new("TextButton", CardReplay)
	BtnRefreshGhost.Text = "REFRESH LIST"
	BtnRefreshGhost.Size = UDim2.new(0.94, 0, 0, 25)
	BtnRefreshGhost.Position = UDim2.new(0.03, 0, 0, 295)
	StyleBtn(BtnRefreshGhost, C_TEXT)

	local BtnClearGhost = Instance.new("TextButton", CardReplay)
	BtnClearGhost.Text = "CLEAR GHOST"
	BtnClearGhost.Size = UDim2.new(0.94, 0, 0, 25)
	BtnClearGhost.Position = UDim2.new(0.03, 0, 0, 325)
	StyleBtn(BtnClearGhost, C_RED)

	RefreshGhostList = function()
		for _, c in pairs(GhostListScroll:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		local path = GetGhostPath()
		if isfolder(path) then
			local files = listfiles(path)
			GhostListScroll.CanvasSize = UDim2.new(0, 0, 0, #files * 22)
			for _, f in ipairs(files) do
				local n = string.match(f, "[^/\\]+$"):gsub(".json", "")
				local b = Instance.new("TextButton", GhostListScroll)
				b.Text = "  " .. n
				b.Size = UDim2.new(1, 0, 0, 20)
				b.BackgroundColor3 = C_SIDE
				b.TextColor3 = C_TEXT_DIM
				b.TextXAlignment = Enum.TextXAlignment.Left
				b.Font = Enum.Font.Gotham
				b.TextSize = 10
				Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)

				b.MouseButton1Click:Connect(function()
					local s, j = pcall(readfile, f)
					if s then
						local d = HttpService:JSONDecode(j)
						if d.Frames then
							GhostData = {}
							for _, fr in ipairs(d.Frames) do
								local frame = { Time = fr.Time, RootCF = TblToCF(fr.RootCF), Limbs = {} }
								for ln, lcf in pairs(fr.Limbs) do
									frame.Limbs[ln] = TblToCF(lcf)
								end
								table.insert(GhostData, frame)
							end
							LblGhostStatus.Text = "LOADED: " .. n .. " (" .. #GhostData .. " Frames)"
							BtnPlayGhost.TextColor3 = C_TEXT
							BtnPlayGhost.UIStroke.Color = C_TEXT
						end
					end
				end)
			end
		end
	end

	BtnRefreshGhost.MouseButton1Click:Connect(RefreshGhostList)

	BtnSaveGhost.MouseButton1Click:Connect(function()
		local name = InpGhostName.Text
		if name == "" or #GhostData == 0 then
			return
		end
		local saveData = { Frames = {} }
		for _, frame in ipairs(GhostData) do
			local saveFrame = { Time = frame.Time, RootCF = CFToTbl(frame.RootCF), Limbs = {} }
			for limbName, limbCF in pairs(frame.Limbs) do
				saveFrame.Limbs[limbName] = CFToTbl(limbCF)
			end
			table.insert(saveData.Frames, saveFrame)
		end
		writefile(GetGhostPath() .. "/" .. name .. ".json", HttpService:JSONEncode(saveData))
		RefreshGhostList()
		LblGhostStatus.Text = "SAVED: " .. name
	end)

	local function StopGhost()
		if ghostRecLoop then
			ghostRecLoop:Disconnect()
			ghostRecLoop = nil
		end
		if ghostPlayLoop then
			ghostPlayLoop:Disconnect()
			ghostPlayLoop = nil
		end
		isGhostRecording = false
		isGhostPlaying = false
		BtnRecordGhost.Text = "RECORD NEW"
		BtnRecordGhost.TextColor3 = C_TEXT
		BtnRecordGhost.UIStroke.Color = C_TEXT
		BtnPlayGhost.Text = "PLAY GHOST"
		BtnPlayGhost.TextColor3 = (#GhostData > 0) and C_TEXT or C_TEXT_DIM
		BtnPlayGhost.UIStroke.Color = (#GhostData > 0) and C_TEXT or C_TEXT_DIM
		LblGhostStatus.Text = "STATUS: IDLE (" .. #GhostData .. " Frames)"
		if GhostModel then
			GhostModel:Destroy()
			GhostModel = nil
		end
	end

	BtnRecordGhost.MouseButton1Click:Connect(function()
		if isGhostRecording then
			StopGhost()
		else
			StopGhost()
			StartCountdown(function()
				GhostData = {}
				isGhostRecording = true
				BtnRecordGhost.Text = "STOP RECORD"
				BtnRecordGhost.TextColor3 = C_RED
				BtnRecordGhost.UIStroke.Color = C_RED
				LblGhostStatus.Text = "STATUS: RECORDING..."
				local c = LocalPlayer.Character
				local partsToRecord = {}
				if c then
					for _, p in pairs(c:GetDescendants()) do
						if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
							table.insert(partsToRecord, p)
						end
					end
				end
				local startTime = os.clock()
				ghostRecLoop = RunService.Heartbeat:Connect(function()
					local char = LocalPlayer.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root then
						local frameData = { Time = os.clock() - startTime, RootCF = root.CFrame, Limbs = {} }
						for _, p in pairs(partsToRecord) do
							if p and p.Parent then
								frameData.Limbs[p.Name] = p.CFrame
							end
						end
						table.insert(GhostData, frameData)
						LblGhostStatus.Text = "REC: " .. string.format("%.1fs", os.clock() - startTime)
					end
				end)
				table.insert(Connections, ghostRecLoop)
			end)
		end
	end)

	BtnPlayGhost.MouseButton1Click:Connect(function()
		if isGhostPlaying then
			StopGhost()
		elseif #GhostData > 0 then
			StopGhost()
			StartCountdown(function()
				isGhostPlaying = true
				BtnPlayGhost.Text = "STOP GHOST"
				BtnPlayGhost.TextColor3 = C_RED
				BtnPlayGhost.UIStroke.Color = C_RED
				LblGhostStatus.Text = "STATUS: PLAYING..."
				local c = LocalPlayer.Character
				c.Archivable = true
				GhostModel = c:Clone()
				c.Archivable = false
				GhostModel.Name = "StarshipGhost"
				GhostModel.Parent = workspace
				for _, p in pairs(GhostModel:GetDescendants()) do
					if p:IsA("BasePart") then
						p.Anchored = true
						p.CanCollide = false
						p.Transparency = 0.6
						p.Color = C_ACCENT
						p.Material = Enum.Material.ForceField
					elseif p:IsA("Script") or p:IsA("LocalScript") or p:IsA("Sound") then
						p:Destroy()
					elseif p:IsA("Humanoid") then
						p.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					end
				end
				local playStart = os.clock()
				local index = 1
				ghostPlayLoop = RunService.Heartbeat:Connect(function()
					if not GhostModel or not GhostModel.Parent then
						StopGhost()
						return
					end
					local timeElapsed = os.clock() - playStart
					while index < #GhostData and GhostData[index + 1].Time <= timeElapsed do
						index = index + 1
					end
					local frame = GhostData[index]
					if frame then
						if GhostModel.PrimaryPart then
							GhostModel:SetPrimaryPartCFrame(frame.RootCF)
						elseif GhostModel:FindFirstChild("HumanoidRootPart") then
							GhostModel.HumanoidRootPart.CFrame = frame.RootCF
						end
						for name, cf in pairs(frame.Limbs) do
							local p = GhostModel:FindFirstChild(name, true)
							if p and p:IsA("BasePart") then
								p.CFrame = cf
							end
						end
					end
					if index >= #GhostData then
						playStart = os.clock()
						index = 1
					end
				end)
				table.insert(Connections, ghostPlayLoop)
			end)
		end
	end)

	BtnClearGhost.MouseButton1Click:Connect(function()
		StopGhost()
		GhostData = {}
		LblGhostStatus.Text = "STATUS: CLEARED"
		BtnPlayGhost.TextColor3 = C_TEXT_DIM
		BtnPlayGhost.UIStroke.Color = C_TEXT_DIM
	end)

	RefreshGhostList()

	local function RestorePlatforms() end -- Placeholder if needed, or implement if logic exists

	-- Cleanup Hook
	local oldCleanup = UIHandlers.CleanupTools
	UIHandlers.CleanupTools = function()
		if oldCleanup then
			oldCleanup()
		end
		if slopeLoop then
			slopeLoop:Disconnect()
			slopeLoop = nil
		end
		if slopeHUD then
			slopeHUD:Destroy()
			slopeHUD = nil
		end
		if slipLoop then
			slipLoop:Disconnect()
			slipLoop = nil
		end
		if fastClimbLoop then
			fastClimbLoop:Disconnect()
			fastClimbLoop = nil
		end
		if magnetLoop then
			magnetLoop:Disconnect()
			magnetLoop = nil
		end
		if stickLoop then
			stickLoop:Disconnect()
			stickLoop = nil
		end
		if espLoop then
			espLoop:Disconnect()
			espLoop = nil
		end
		if ghostRecLoop then
			ghostRecLoop:Disconnect()
			ghostRecLoop = nil
		end
		if ghostPlayLoop then
			ghostPlayLoop:Disconnect()
			ghostPlayLoop = nil
		end
		if GhostModel then
			GhostModel:Destroy()
			GhostModel = nil
		end
		if espContainer then
			espContainer:ClearAllChildren()
		end
		RestorePlatforms()
	end
end

return SetupHelperUI
