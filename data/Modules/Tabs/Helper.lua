local function SetupHelperUI(PageHelper, UI, Connections, Config, LocalPlayer, UIHandlers, ShowConfirm, RegisterTheme)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")
	local HttpService = game:GetService("HttpService")

	-- Use global StarshipColors for theme consistency
	local Colors = _G.StarshipColors
		or {
			MAIN = Color3.fromRGB(10, 10, 14),
			SIDE = Color3.fromRGB(15, 15, 20),
			ACCENT = Color3.fromRGB(90, 110, 245),
			TEXT = Color3.fromRGB(240, 240, 250),
			TEXT_DIM = Color3.fromRGB(140, 140, 160),
			ITEM = Color3.fromRGB(20, 20, 28),
			RED = Color3.fromRGB(255, 80, 80),
			YELLOW = Color3.fromRGB(255, 220, 60),
			GREEN = Color3.fromRGB(60, 255, 160),
		}
	local C_MAIN = Colors.MAIN
	local C_SIDE = Colors.SIDE
	local C_ACCENT = Colors.ACCENT
	local C_TEXT = Colors.TEXT
	local C_TEXT_DIM = Colors.TEXT_DIM
	local C_ITEM = Colors.ITEM
	local C_RED = Colors.RED
	local C_YELLOW = Colors.YELLOW
	local C_GREEN = Colors.GREEN

	-- Helper function to get localized text
	local function L(key, ...)
		if _G.StarshipLocale and _G.StarshipLocale.Get then
			return _G.StarshipLocale.Get(key, ...)
		end
		return key
	end

	-- Helper function to show toast when feature is toggled
	local function ShowFeatureToast(featureName, isEnabled)
		if UI and UI.ShowToast then
			local status = isEnabled and L("enabled") or L("disabled")
			local toastType = isEnabled and "success" or "info"
			UI.ShowToast(featureName, status, toastType, 2)
		end
	end

	local FOLDER_NAME = "StarshipCore"

	-- ============================================================
	-- GAMEPAD TRIGGER RESERVATION (block game's L2/R2 shiftlock bind)
	-- ============================================================
	-- Beberapa game bind ButtonL2/ButtonR2 ke shiftlock toggle via CAS
	-- di priority Default. Kita reserve di priority High + Sink biar
	-- handler game gak ke-trigger. Raw input lewat UserInputService
	-- (IsGamepadButtonDown / GetGamepadState) TETEP kebaca, jadi
	-- fitur Climb Hop / Quick Boost / etc yang pake R2/L2 tetep jalan.
	local ContextActionService = game:GetService("ContextActionService")
	local STARSHIP_TRIGGER_GUARD = "StarshipGamepadTriggerGuard"

	-- Cleanup binding lama kalau script di-reload
	pcall(function()
		ContextActionService:UnbindAction(STARSHIP_TRIGGER_GUARD)
	end)

	local function _triggerGuardCallback(_actionName, _inputState, _inputObject)
		-- Sink semua trigger event biar game's shiftlock bind di bawah kita
		-- gak ke-fire. Raw state masih bisa dibaca lewat UIS.
		return Enum.ContextActionResult.Sink
	end

	pcall(function()
		ContextActionService:BindActionAtPriority(
			STARSHIP_TRIGGER_GUARD,
			_triggerGuardCallback,
			false, -- gak butuh touch button
			Enum.ContextActionPriority.High.Value + 1000, -- di atas game default (2000) & High (3000)
			Enum.KeyCode.ButtonL2,
			Enum.KeyCode.ButtonR2
		)
	end)

	-- Pastiin di-cleanup waktu Connections di-disconnect (script unload)
	table.insert(Connections, {
		Disconnect = function()
			pcall(function()
				ContextActionService:UnbindAction(STARSHIP_TRIGGER_GUARD)
			end)
		end,
	})
	-- ============================================================

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

	-- Clear existing children for reactive refresh support
	PageHelper:ClearAllChildren()

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

	-- Helper function to create feature button with subtitle description
	local function CreateFeatureButton(parent, text, subtitle, size, position, color)
		local container = Instance.new("Frame", parent)
		container.Size = size
		container.Position = position
		container.BackgroundTransparency = 1

		local btn = Instance.new("TextButton", container)
		btn.Text = text
		btn.Size = UDim2.new(1, 0, 0, 35)
		btn.Position = UDim2.new(0, 0, 0, 0)
		StyleBtn(btn, color)

		local desc = Instance.new("TextLabel", container)
		desc.Text = subtitle
		desc.Size = UDim2.new(1, 0, 0, 14)
		desc.Position = UDim2.new(0, 0, 0, 37)
		desc.BackgroundTransparency = 1
		desc.TextColor3 = C_TEXT_DIM
		desc.Font = Enum.Font.Gotham
		desc.TextSize = 9
		desc.TextXAlignment = Enum.TextXAlignment.Center
		desc.TextWrapped = true
		RegisterTheme(desc, "TextColor3", "TextDim")

		return btn, container
	end

	-- 0. CHARACTER & FLY
	local CardChar = CreateCard(L("character_fly"), 145, 0)

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

	-- Inf Jump
	local BtnInfJump = Instance.new("TextButton", CardChar)
	BtnInfJump.Text = "INFINITE JUMP: OFF"
	BtnInfJump.Size = UDim2.new(0.94, 0, 0, 30)
	BtnInfJump.Position = UDim2.new(0.03, 0, 0, 75)
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
	BtnFly.Position = UDim2.new(0.03, 0, 0, 110)
	StyleBtn(BtnFly, C_TEXT_DIM)
	local InpFlySpd = Instance.new("TextBox", CardChar)
	InpFlySpd.PlaceholderText = "Spd"
	InpFlySpd.Text = "50"
	InpFlySpd.Size = UDim2.new(0.45, 0, 0, 35)
	InpFlySpd.Position = UDim2.new(0.52, 0, 0, 110)
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
		local CardJump = CreateCard(L("jump_assist"), 280, 4)

		-- Auto Jump
		local BtnAutoJump, AutoJumpContainer = CreateFeatureButton(
			CardJump,
			L("auto_jump") .. ": " .. L("off"),
			L("auto_jump_desc"),
			UDim2.new(0.45, 0, 0, 55),
			UDim2.new(0.03, 0, 0, 35),
			C_TEXT_DIM
		)

		local isAutoJump, autoJumpLoop = false, nil

		local function ToggleAutoJump(forceEnable)
			-- Support forceEnable parameter for auto-enable
			if forceEnable ~= nil then
				if forceEnable == isAutoJump then
					return
				end
			end

			isAutoJump = not isAutoJump
			BtnAutoJump.Text = L("auto_jump") .. ": " .. (isAutoJump and L("on") or L("off"))
			BtnAutoJump.TextColor3 = isAutoJump and C_GREEN or C_TEXT_DIM
			BtnAutoJump.UIStroke.Color = isAutoJump and C_GREEN or C_TEXT_DIM
			ShowFeatureToast("Auto Jump", isAutoJump)

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

		-- Anti Delay
		local BtnAntiDelay, AntiDelayContainer = CreateFeatureButton(
			CardJump,
			L("anti_delay") .. ": " .. L("off"),
			L("anti_delay_desc"),
			UDim2.new(0.94, 0, 0, 55),
			UDim2.new(0.03, 0, 0, 95),
			C_TEXT_DIM
		)

		-- Jump Gravity Slider
		local LblJumpGrav = Instance.new("TextLabel", CardJump)
		LblJumpGrav.Text = L("jump_gravity") .. ": -0.2"
		LblJumpGrav.Size = UDim2.new(0.35, 0, 0, 20)
		LblJumpGrav.Position = UDim2.new(0.03, 0, 0, 160)
		LblJumpGrav.BackgroundTransparency = 1
		LblJumpGrav.TextColor3 = C_TEXT_DIM
		LblJumpGrav.Font = Enum.Font.GothamBold
		LblJumpGrav.TextSize = 10
		LblJumpGrav.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(LblJumpGrav, "TextColor3", "TextDim")

		local SldJumpGravBg = Instance.new("TextButton", CardJump)
		SldJumpGravBg.Text = ""
		SldJumpGravBg.Size = UDim2.new(0.55, 0, 0, 8)
		SldJumpGravBg.Position = UDim2.new(0.42, 0, 0, 166)
		SldJumpGravBg.BackgroundColor3 = C_SIDE
		SldJumpGravBg.AutoButtonColor = false
		Instance.new("UICorner", SldJumpGravBg).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldJumpGravBg, "BackgroundColor3", "Side")

		local jumpGravVal = -0.2
		local SldJumpGravFill = Instance.new("Frame", SldJumpGravBg)
		SldJumpGravFill.Size = UDim2.new(math.clamp((jumpGravVal + 5) / 5, 0, 1), 0, 1, 0)
		SldJumpGravFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldJumpGravFill).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldJumpGravFill, "BackgroundColor3", "Accent")

		-- Fall Gravity Slider
		local LblFallGrav = Instance.new("TextLabel", CardJump)
		LblFallGrav.Text = L("fall_gravity") .. ": -2.0"
		LblFallGrav.Size = UDim2.new(0.35, 0, 0, 20)
		LblFallGrav.Position = UDim2.new(0.03, 0, 0, 185)
		LblFallGrav.BackgroundTransparency = 1
		LblFallGrav.TextColor3 = C_TEXT_DIM
		LblFallGrav.Font = Enum.Font.GothamBold
		LblFallGrav.TextSize = 10
		LblFallGrav.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(LblFallGrav, "TextColor3", "TextDim")

		local SldFallGravBg = Instance.new("TextButton", CardJump)
		SldFallGravBg.Text = ""
		SldFallGravBg.Size = UDim2.new(0.55, 0, 0, 8)
		SldFallGravBg.Position = UDim2.new(0.42, 0, 0, 191)
		SldFallGravBg.BackgroundColor3 = C_SIDE
		SldFallGravBg.AutoButtonColor = false
		Instance.new("UICorner", SldFallGravBg).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldFallGravBg, "BackgroundColor3", "Side")

		local fallGravVal = -2.0
		local SldFallGravFill = Instance.new("Frame", SldFallGravBg)
		SldFallGravFill.Size = UDim2.new(math.clamp((fallGravVal + 10) / 10, 0, 1), 0, 1, 0)
		SldFallGravFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldFallGravFill).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldFallGravFill, "BackgroundColor3", "Accent")

		-- Slider Drag Logic
		local dragJump, dragFall = false, false
		SldJumpGravBg.MouseButton1Down:Connect(function() dragJump = true end)
		SldFallGravBg.MouseButton1Down:Connect(function() dragFall = true end)
		UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then
				dragJump, dragFall = false, false
			end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				if dragJump then
					local sc = math.clamp((i.Position.X - SldJumpGravBg.AbsolutePosition.X) / SldJumpGravBg.AbsoluteSize.X, 0, 1)
					jumpGravVal = -5 + (sc * 5)
					jumpGravVal = math.floor(jumpGravVal * 10) / 10
					SldJumpGravFill.Size = UDim2.new(sc, 0, 1, 0)
					LblJumpGrav.Text = L("jump_gravity") .. ": " .. string.format("%.1f", jumpGravVal)
				elseif dragFall then
					local sc = math.clamp((i.Position.X - SldFallGravBg.AbsolutePosition.X) / SldFallGravBg.AbsoluteSize.X, 0, 1)
					fallGravVal = -10 + (sc * 10)
					fallGravVal = math.floor(fallGravVal * 10) / 10
					SldFallGravFill.Size = UDim2.new(sc, 0, 1, 0)
					LblFallGrav.Text = L("fall_gravity") .. ": " .. string.format("%.1f", fallGravVal)
				end
			end
		end)

		local isAntiDelay, antiDelayLoop = false, nil
		local originalProps = {}

		local function ToggleAntiDelay(forceEnable)
			if forceEnable ~= nil then
				if forceEnable == isAntiDelay then
					return
				end
			end

			isAntiDelay = not isAntiDelay
			BtnAntiDelay.Text = L("anti_delay") .. ": " .. (isAntiDelay and L("on") or L("off"))
			BtnAntiDelay.TextColor3 = isAntiDelay and C_GREEN or C_TEXT_DIM
			BtnAntiDelay.UIStroke.Color = isAntiDelay and C_GREEN or C_TEXT_DIM
			ShowFeatureToast("Anti Delay", isAntiDelay)

			if isAntiDelay then
				-- Connect to JumpRequest for INSTANT firing
				Connections.AntiDelayJump = UserInputService.JumpRequest:Connect(function()
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChild("Humanoid")
					if h and h.FloorMaterial ~= Enum.Material.Air then
						h:ChangeState(Enum.HumanoidStateType.Jumping)
					end
				end)

				antiDelayLoop = RunService.Heartbeat:Connect(function()
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChild("Humanoid")
					local r = c and c:FindFirstChild("HumanoidRootPart")
					if not h or not r then return end

					-- 1. PHYSICAL PROPERTIES (Zero Friction to prevent sticking)
					for _, p in ipairs(c:GetChildren()) do
						if p:IsA("BasePart") then
							if not originalProps[p] then
								originalProps[p] = p.CustomPhysicalProperties or "Default"
							end
							p.CustomPhysicalProperties = PhysicalProperties.new(
								p.CurrentPhysicalProperties.Density,
								0, -- Friction: 0
								0, -- Elasticity
								100, -- FrictionWeight: Max
								1 -- ElasticityWeight
							)
						end
					end

					-- 2. SNAPPY AIR CONTROL & OPTIMIZED FALL
					if h.FloorMaterial == Enum.Material.Air then
						local vel = r.AssemblyLinearVelocity
						
						-- Apply Gravity Compensation/Boost from Sliders
						if vel.Y > 0 then
							-- Upward: Jump Gravity
							r.AssemblyLinearVelocity = vel + Vector3.new(0, jumpGravVal, 0)
						else
							-- Downward: Fall Gravity
							r.AssemblyLinearVelocity = vel + Vector3.new(0, fallGravVal, 0)
						end

						-- Snappy Air Control
						if h.MoveDirection.Magnitude > 0.1 then
							local horizontalVel = Vector3.new(vel.X, 0, vel.Z)
							local speed = math.max(horizontalVel.Magnitude, h.WalkSpeed)
							local targetVel = h.MoveDirection * speed
							
							-- Apply horizontal correction without flattening Vertical Velocity
							r.AssemblyLinearVelocity = Vector3.new(targetVel.X, r.AssemblyLinearVelocity.Y, targetVel.Z)
						end
					end
				end)
				table.insert(Connections, antiDelayLoop)
			else
				if Connections.AntiDelayJump then
					Connections.AntiDelayJump:Disconnect()
					Connections.AntiDelayJump = nil
				end
				if antiDelayLoop then
					antiDelayLoop:Disconnect()
					antiDelayLoop = nil
				end
				-- Restore Physical Properties
				for p, prop in pairs(originalProps) do
					if p and p.Parent then
						p.CustomPhysicalProperties = (prop == "Default") and nil or prop
					end
				end
				originalProps = {}
			end
		end

		BtnAntiDelay.MouseButton1Click:Connect(function()
			ToggleAntiDelay()
		end)
		UIHandlers.ToggleAntiDelay = ToggleAntiDelay

		-- Air Lock (Edge Assist + Velocity Boost for Obby)
		local BtnAirLock, AirLockContainer = CreateFeatureButton(
			CardJump,
			L("air_lock") .. ": " .. L("off"),
			L("air_lock_desc"),
			UDim2.new(0.45, 0, 0, 55),
			UDim2.new(0.52, 0, 0, 35),
			C_TEXT_DIM
		)

		local isAirLock, airLockLoop = false, nil
		local edgeBoostCooldown = false
		local detectedEdgePosition = nil
		local preDetectedEdge = nil -- Pre-detect while on ground
		local preDetectedPart = nil -- Pre-detected part
		local lastGroundTime = 0 -- Track when we left ground

		-- Edge Detection Settings (BALANCED)
		local EDGE_DETECT_DISTANCE = 12 -- Raycast distance to detect ledge
		local EDGE_HEIGHT_TOLERANCE = 8 -- How much "almost there" we allow
		local BOOST_POWER_UP = 10 -- Upward boost strength (increased)
		local BOOST_POWER_FORWARD = 10 -- Forward boost strength
		local BOOST_COOLDOWN = 0.4 -- Cooldown between boosts
		local UPWARD_DETECT_DISTANCE = 10 -- Raycast distance upward for ladders above head

		-- Ladder Grab Assist Settings
		local LADDER_BOOST_MULTIPLIER = 1.0 -- Boost multiplier for ladder (reduced - no extra boost)
		local PRE_DETECT_ENABLED = true -- Enable ground pre-detection
		local INSTANT_BOOST_WINDOW = 0.15 -- Seconds after jump to use pre-detected target
		local detectedLadderPart = nil -- Track detected ladder
		local hasBostedThisJump = false -- Prevent multiple boosts per jump

		-- Check if part is a VERTICAL ladder/truss (not diagonal/horizontal)
		local function IsLadder(part)
			if not part then
				return false
			end

			-- Check if it's a TrussPart or has ladder-like name
			local isLadderType = part:IsA("TrussPart")
			if not isLadderType then
				local name = part.Name:lower()
				isLadderType = name:find("ladder")
					or name:find("truss")
					or name:find("climb")
					or name:find("vine")
					or name:find("rope")
			end

			if not isLadderType then
				return false
			end

			-- Check orientation - only treat as ladder if mostly VERTICAL
			-- Diagonal/horizontal ladders should be treated as platforms
			local size = part.Size
			local upVector = part.CFrame.UpVector

			-- If the part's up vector is mostly vertical (Y > 0.7), it's a climbable ladder
			-- If it's more horizontal/diagonal, treat as platform
			local isVertical = math.abs(upVector.Y) > 0.7

			-- Also check if height > width (tall ladder vs flat bridge)
			local isTall = size.Y > math.max(size.X, size.Z) * 0.8

			-- Only return true for VERTICAL ladders
			return isVertical or isTall
		end

		-- Detect edge/ladder in front of player with MULTI-ANGLE detection for diagonal ladders
		-- Returns: hitPosition, hitPart (to check if ladder)
		-- Now uses MoveDirection for Shift Lock compatibility
		local function DetectEdgeForward(character, rootPart, humanoid)
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = { character }
			rayParams.FilterType = Enum.RaycastFilterType.Exclude

			local playerPos = rootPart.Position
			local playerTop = playerPos.Y + 2

			-- Use MoveDirection if available (for Shift Lock compatibility)
			-- Fall back to LookVector if not moving
			local moveDir = humanoid and humanoid.MoveDirection or Vector3.new(0, 0, 0)
			local lookDir = rootPart.CFrame.LookVector

			-- If moving, use move direction; otherwise use look direction
			local primaryDir
			if moveDir.Magnitude > 0.1 then
				primaryDir = moveDir
			else
				primaryDir = lookDir
			end

			local rightDir = rootPart.CFrame.RightVector
			local horizontalLook = Vector3.new(primaryDir.X, 0, primaryDir.Z)
			if horizontalLook.Magnitude > 0 then
				horizontalLook = horizontalLook.Unit
			else
				horizontalLook = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
			end

			-- Store best ladder hit (prioritize ladders!)
			local bestLadderHit = nil
			local bestLadderPart = nil
			local bestLadderDist = math.huge

			-- Store best edge hit
			local bestEdgeHit = nil
			local bestEdgePart = nil

			-- Helper function to check hit and return if valid
			local function CheckHit(hitResult, checkHeightDiff)
				if not hitResult then
					return nil, nil
				end

				local hitPart = hitResult.Instance
				local hitPosition = hitResult.Position

				-- For ladders, we don't need strict height check
				if IsLadder(hitPart) then
					local dist = (hitPosition - playerPos).Magnitude
					if dist < bestLadderDist then
						bestLadderDist = dist
						bestLadderHit = hitPart.Position -- Use ladder center for better targeting
						bestLadderPart = hitPart
					end
					return hitPosition, hitPart
				end

				-- For regular edges, check height difference
				if checkHeightDiff then
					local ledgeTop = hitPart.Position.Y + (hitPart.Size.Y / 2)
					local heightDiff = ledgeTop - playerTop
					if heightDiff > 0 and heightDiff <= EDGE_HEIGHT_TOLERANCE then
						if not bestEdgeHit then
							bestEdgeHit = hitPosition
							bestEdgePart = hitPart
						end
						return hitPosition, hitPart
					end
				end

				return nil, nil
			end

			-- MULTI-ANGLE RAYCAST for diagonal ladder detection
			local angles = {
				-- Forward directions
				horizontalLook,
				-- Diagonal up-forward (various angles for diagonal ladders)
				(horizontalLook + Vector3.new(0, 0.3, 0)).Unit,
				(horizontalLook + Vector3.new(0, 0.5, 0)).Unit,
				(horizontalLook + Vector3.new(0, 0.8, 0)).Unit,
				(horizontalLook + Vector3.new(0, 1.0, 0)).Unit,
				(horizontalLook + Vector3.new(0, 1.5, 0)).Unit,
				(horizontalLook + Vector3.new(0, 2.0, 0)).Unit,
				-- Steep upward (for ladders above)
				(horizontalLook * 0.5 + Vector3.new(0, 1, 0)).Unit,
				(horizontalLook * 0.3 + Vector3.new(0, 1, 0)).Unit,
				-- Slight left/right diagonal (for offset ladders)
				(horizontalLook + rightDir * 0.3 + Vector3.new(0, 0.5, 0)).Unit,
				(horizontalLook - rightDir * 0.3 + Vector3.new(0, 0.5, 0)).Unit,
				(horizontalLook + rightDir * 0.3 + Vector3.new(0, 1.0, 0)).Unit,
				(horizontalLook - rightDir * 0.3 + Vector3.new(0, 1.0, 0)).Unit,
			}

			-- Cast rays in all directions
			for _, dir in ipairs(angles) do
				local hitResult = workspace:Raycast(playerPos, dir * EDGE_DETECT_DISTANCE, rayParams)
				CheckHit(hitResult, true)
			end

			-- Also raycast straight up
			local upHit = workspace:Raycast(playerPos, Vector3.new(0, 1, 0) * UPWARD_DETECT_DISTANCE, rayParams)
			if upHit then
				CheckHit(upHit, false)
				if IsLadder(upHit.Instance) then
					local dist = (upHit.Position - playerPos).Magnitude
					if dist < bestLadderDist then
						bestLadderDist = dist
						bestLadderHit = upHit.Instance.Position
						bestLadderPart = upHit.Instance
					end
				end
			end

			-- Prioritize ladder hits over regular edges!
			if bestLadderHit then
				return bestLadderHit, bestLadderPart
			end

			if bestEdgeHit then
				return bestEdgeHit, bestEdgePart
			end

			return nil, nil
		end

		-- Check if there's an obstacle above player's head
		local function CheckOverhead(character, rootPart, checkDistance)
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = { character }
			rayParams.FilterType = Enum.RaycastFilterType.Exclude

			-- Raycast from head position upward
			local headPos = rootPart.Position + Vector3.new(0, 2, 0)
			local hitResult = workspace:Raycast(headPos, Vector3.new(0, checkDistance, 0), rayParams)

			if hitResult then
				return true, hitResult.Position.Y - headPos.Y -- obstacle found, return distance
			end
			return false, checkDistance -- no obstacle
		end

		-- Boost toward the edge (SAFE VERSION - simple ADD, no replace)
		local function BoostTowardEdge(rootPart, edgePosition, isLadderTarget)
			if edgeBoostCooldown or hasBostedThisJump then
				return false
			end

			local directionToEdge = (edgePosition - rootPart.Position)
			local distance = directionToEdge.Magnitude

			-- Don't boost if too close (already there)
			if distance < 2 then
				return false
			end

			local currentVel = rootPart.AssemblyLinearVelocity

			-- Only boost if actually moving upward or forward (not falling fast)
			if currentVel.Y < -20 then
				return false
			end

			-- Check for overhead obstacles (increased check distance)
			local character = rootPart.Parent
			local hasOverhead, overheadDist = CheckOverhead(character, rootPart, 8)

			local boostVelocity

			if isLadderTarget and distance > 0 then
				-- Ladder: boost toward it with VERY MINIMAL force
				local directDir = directionToEdge.Unit
				local boostStrength = BOOST_POWER_FORWARD * LADDER_BOOST_MULTIPLIER * 0.6 -- Reduced

				-- Almost no upward boost for ladders to prevent head bump
				local upwardBoost = 0
				if not hasOverhead and overheadDist > 5 then
					upwardBoost = 1 -- Only tiny upward if no obstacle
				end

				boostVelocity = Vector3.new(directDir.X * boostStrength, upwardBoost, directDir.Z * boostStrength)
			else
				-- Platform: horizontal + upward
				-- Use direction to edge, or MoveDirection for Shift Lock compatibility
				local horizontalDir = Vector3.new(directionToEdge.X, 0, directionToEdge.Z)
				if horizontalDir.Magnitude > 0 then
					horizontalDir = horizontalDir.Unit
				else
					-- Fall back to humanoid MoveDirection if available
					local hum = rootPart.Parent and rootPart.Parent:FindFirstChildOfClass("Humanoid")
					if hum and hum.MoveDirection.Magnitude > 0.1 then
						horizontalDir = hum.MoveDirection
					else
						horizontalDir = rootPart.CFrame.LookVector
					end
				end

				-- Simple upward based on if target is above
				local heightDiff = edgePosition.Y - rootPart.Position.Y
				local upwardBoost = heightDiff > 0 and math.clamp(heightDiff * 0.5, 4, BOOST_POWER_UP) or 2

				-- Reduce upward boost if overhead obstacle detected (but keep more power)
				if hasOverhead then
					upwardBoost = math.min(upwardBoost, overheadDist * 0.6)
				end

				-- Use reduced forward boost
				local forwardBoost = BOOST_POWER_FORWARD * 0.7

				boostVelocity = Vector3.new(horizontalDir.X * forwardBoost, upwardBoost, horizontalDir.Z * forwardBoost)
			end

			-- SIMPLE ADD - don't mess with current velocity, just add boost
			rootPart.AssemblyLinearVelocity = currentVel + boostVelocity

			-- Mark as boosted this jump & set cooldown
			hasBostedThisJump = true
			edgeBoostCooldown = true
			task.delay(BOOST_COOLDOWN, function()
				edgeBoostCooldown = false
			end)

			return true
		end

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
			ShowFeatureToast("Air Lock", isAirLock)

			if isAirLock then
				airLockLoop = RunService.RenderStepped:Connect(function()
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChild("Humanoid")
					local r = c and c:FindFirstChild("HumanoidRootPart")

					if h and r then
						local state = h:GetState()
						local velocity = r.AssemblyLinearVelocity
						local currentTime = tick()

						-- GROUND STATE: Reset boost flag & pre-detect
						if
							state == Enum.HumanoidStateType.Running
							or state == Enum.HumanoidStateType.RunningNoPhysics
							or state == Enum.HumanoidStateType.Landed
						then
							lastGroundTime = currentTime
							hasBostedThisJump = false -- Reset boost flag when on ground

							-- Pre-detect while moving on ground
							if h.MoveDirection.Magnitude > 0.1 then
								local hitPos, hitPart = DetectEdgeForward(c, r, h)
								preDetectedEdge = hitPos
								preDetectedPart = hitPart
							end
							-- Reset air detection
							detectedEdgePosition = nil
							detectedLadderPart = nil
						end

						-- AIR STATE: Only boost when jumping/falling AND not already boosted
						if
							(state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall)
							and not hasBostedThisJump
						then
							local timeSinceGround = currentTime - lastGroundTime

							-- Wait a tiny bit after jump to let normal jump physics work
							if timeSinceGround < 0.1 then
								return -- Let normal jump happen first
							end

							-- Use pre-detected target if available
							if
								not detectedEdgePosition
								and preDetectedEdge
								and timeSinceGround < INSTANT_BOOST_WINDOW
							then
								detectedEdgePosition = preDetectedEdge
								detectedLadderPart = preDetectedPart
							end

							-- Detect in air if no target yet
							if not detectedEdgePosition then
								local hitPos, hitPart = DetectEdgeForward(c, r, h)
								detectedEdgePosition = hitPos
								detectedLadderPart = hitPart
							end

							-- Boost toward edge (only once per jump)
							if detectedEdgePosition and not edgeBoostCooldown and not hasBostedThisJump then
								local isLadderTarget = IsLadder(detectedLadderPart)
								BoostTowardEdge(r, detectedEdgePosition, isLadderTarget)
								-- Clear pre-detected after use
								preDetectedEdge = nil
								preDetectedPart = nil
							end
						end
					end
				end)
				table.insert(Connections, airLockLoop)
			else
				if airLockLoop then
					airLockLoop:Disconnect()
					airLockLoop = nil
				end
			end
		end
		BtnAirLock.MouseButton1Click:Connect(function()
			ToggleAirLock()
		end)
		UIHandlers.ToggleAirLock = ToggleAirLock

		-- High Jump (toggle + custom power input)
		local BtnHighJump = Instance.new("TextButton", CardJump)
		BtnHighJump.Text = "HIGH JUMP: OFF"
		BtnHighJump.Size = UDim2.new(0.6, 0, 0, 35)
		BtnHighJump.Position = UDim2.new(0.03, 0, 0, 215)
		StyleBtn(BtnHighJump, C_TEXT_DIM)

		local InpHighJumpPower = Instance.new("TextBox", CardJump)
		InpHighJumpPower.PlaceholderText = "Power"
		InpHighJumpPower.Text = "150"
		InpHighJumpPower.Size = UDim2.new(0.3, 0, 0, 35)
		InpHighJumpPower.Position = UDim2.new(0.66, 0, 0, 215)
		InpHighJumpPower.BackgroundColor3 = C_SIDE
		InpHighJumpPower.TextColor3 = C_TEXT
		InpHighJumpPower.Font = Enum.Font.Gotham
		InpHighJumpPower.TextSize = 12
		Instance.new("UICorner", InpHighJumpPower).CornerRadius = UDim.new(0, 6)
		RegisterTheme(InpHighJumpPower, "BackgroundColor3", "Side")
		RegisterTheme(InpHighJumpPower, "TextColor3", "Text")

		local LblHighJumpHint = Instance.new("TextLabel", CardJump)
		LblHighJumpHint.Text = "Custom JumpPower (default 50)"
		LblHighJumpHint.Size = UDim2.new(0.94, 0, 0, 14)
		LblHighJumpHint.Position = UDim2.new(0.03, 0, 0, 252)
		LblHighJumpHint.BackgroundTransparency = 1
		LblHighJumpHint.TextColor3 = C_TEXT_DIM
		LblHighJumpHint.Font = Enum.Font.Gotham
		LblHighJumpHint.TextSize = 9
		LblHighJumpHint.TextXAlignment = Enum.TextXAlignment.Center
		RegisterTheme(LblHighJumpHint, "TextColor3", "TextDim")

		local isHighJump = false
		local highJumpPower = 150
		local highJumpLoop = nil
		local originalHumanoidState = setmetatable({}, { __mode = "k" })

		local function GetHighJumpHumanoid()
			local c = LocalPlayer.Character
			return c and c:FindFirstChildOfClass("Humanoid")
		end

		local function UpdateHighJumpButton()
			BtnHighJump.Text = "HIGH JUMP: " .. (isHighJump and "ON" or "OFF")
			BtnHighJump.TextColor3 = isHighJump and C_GREEN or C_TEXT_DIM
			BtnHighJump.UIStroke.Color = isHighJump and C_GREEN or C_TEXT_DIM
		end

		local function RememberHighJumpState(h)
			if not h or originalHumanoidState[h] then return end

			local ok, useJumpPower, jumpPower = pcall(function()
				return h.UseJumpPower, h.JumpPower
			end)
			if ok then
				originalHumanoidState[h] = {
					UseJumpPower = useJumpPower,
					JumpPower = jumpPower,
				}
			end
		end

		local function ApplyHighJump(h)
			if not h or not h.Parent then return end
			RememberHighJumpState(h)

			-- Mengikuti metode JumpPower dari jump.lua: game bisa menimpa
			-- properti ini, jadi nilainya selalu dikoreksi kembali oleh Heartbeat.
			pcall(function()
				h.UseJumpPower = true
				if h.JumpPower ~= highJumpPower then
					h.JumpPower = highJumpPower
				end
			end)
		end

		local function RestoreHighJumpState()
			for h, state in pairs(originalHumanoidState) do
				if h and h.Parent then
					pcall(function()
						h.UseJumpPower = state.UseJumpPower
						h.JumpPower = state.JumpPower
					end)
				end
			end
			table.clear(originalHumanoidState)
		end

		local function StopHighJumpLoop()
			if highJumpLoop then
				highJumpLoop:Disconnect()
				highJumpLoop = nil
			end
		end

		local function StartHighJumpLoop()
			StopHighJumpLoop()
			ApplyHighJump(GetHighJumpHumanoid())

			highJumpLoop = RunService.Heartbeat:Connect(function()
				if not isHighJump then return end

				local h = GetHighJumpHumanoid()
				if h and h.Health > 0 then
					ApplyHighJump(h)
				end
			end)
			table.insert(Connections, highJumpLoop)
		end

		local function ToggleHighJump(forceEnable)
			local nextState = forceEnable
			if nextState == nil then
				nextState = not isHighJump
			end
			if nextState == isHighJump then return end

			isHighJump = nextState
			if isHighJump then
				StartHighJumpLoop()
			else
				StopHighJumpLoop()
				RestoreHighJumpState()
			end

			UpdateHighJumpButton()
			ShowFeatureToast("High Jump", isHighJump)
		end

		BtnHighJump.MouseButton1Click:Connect(function()
			ToggleHighJump()
		end)

		InpHighJumpPower.FocusLost:Connect(function()
			local value = tonumber(InpHighJumpPower.Text)
			if value and value > 0 then
				highJumpPower = math.clamp(value, 1, 1000)
			end

			InpHighJumpPower.Text = tostring(highJumpPower)
			if isHighJump then
				ApplyHighJump(GetHighJumpHumanoid())
			end
		end)

		-- Cleanup juga memulihkan nilai asli yang direkam sebelum fitur aktif.
		table.insert(Connections, {
			Disconnect = function()
				isHighJump = false
				StopHighJumpLoop()
				RestoreHighJumpState()
			end,
		})

		UIHandlers.ToggleHighJump = ToggleHighJump
	end

	-- 4.35 HABEG (JUMP BUG)
	-- Automates the "Habeg" technique: release shiftlock, face opposite direction, then jump + move
	do
		local CardHabeg = CreateCard("HABEG (JUMP BUG)", 210, 4.35)

		-- Toggle Button
		local BtnHabeg, HabegContainer = CreateFeatureButton(
			CardHabeg,
			"HABEG: " .. L("off"),
			"Auto Jump Bug — face away then jump forward",
			UDim2.new(0.45, 0, 0, 55),
			UDim2.new(0.03, 0, 0, 35),
			C_TEXT_DIM
		)

		-- Mode: "hold" or "toggle"
		local BtnHabegMode = Instance.new("TextButton", CardHabeg)
		BtnHabegMode.Text = "MODE: TOGGLE"
		BtnHabegMode.Size = UDim2.new(0.45, 0, 0, 35)
		BtnHabegMode.Position = UDim2.new(0.52, 0, 0, 35)
		StyleBtn(BtnHabegMode, C_ACCENT)

		local habegModeHold = false -- true = hold mode, false = toggle per-press

		BtnHabegMode.MouseButton1Click:Connect(function()
			habegModeHold = not habegModeHold
			BtnHabegMode.Text = "MODE: " .. (habegModeHold and "HOLD" or "TOGGLE")
		end)

		-- Angle Offset Slider (how many degrees the body faces away from movement)
		local LblHabegAngle = Instance.new("TextLabel", CardHabeg)
		LblHabegAngle.Text = "ANGLE: 90°"
		LblHabegAngle.Size = UDim2.new(0.35, 0, 0, 20)
		LblHabegAngle.Position = UDim2.new(0.03, 0, 0, 100)
		LblHabegAngle.BackgroundTransparency = 1
		LblHabegAngle.TextColor3 = C_TEXT_DIM
		LblHabegAngle.Font = Enum.Font.GothamBold
		LblHabegAngle.TextSize = 10
		LblHabegAngle.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(LblHabegAngle, "TextColor3", "TextDim")

		local SldHabegAngleBg = Instance.new("TextButton", CardHabeg)
		SldHabegAngleBg.Text = ""
		SldHabegAngleBg.Size = UDim2.new(0.55, 0, 0, 8)
		SldHabegAngleBg.Position = UDim2.new(0.42, 0, 0, 106)
		SldHabegAngleBg.BackgroundColor3 = C_SIDE
		SldHabegAngleBg.AutoButtonColor = false
		Instance.new("UICorner", SldHabegAngleBg).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldHabegAngleBg, "BackgroundColor3", "Side")

		local habegAngle = 90 -- Default: 90 degrees offset
		local SldHabegAngleFill = Instance.new("Frame", SldHabegAngleBg)
		SldHabegAngleFill.Size = UDim2.new(math.clamp((habegAngle - 90) / 90, 0, 1), 0, 1, 0) -- Range 90-180
		SldHabegAngleFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldHabegAngleFill).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldHabegAngleFill, "BackgroundColor3", "Accent")

		-- Jump Boost Slider (upward velocity boost, 0 = natural)
		local LblHabegPower = Instance.new("TextLabel", CardHabeg)
		LblHabegPower.Text = "JUMP BOOST: 15"
		LblHabegPower.Size = UDim2.new(0.35, 0, 0, 20)
		LblHabegPower.Position = UDim2.new(0.03, 0, 0, 125)
		LblHabegPower.BackgroundTransparency = 1
		LblHabegPower.TextColor3 = C_TEXT_DIM
		LblHabegPower.Font = Enum.Font.GothamBold
		LblHabegPower.TextSize = 10
		LblHabegPower.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(LblHabegPower, "TextColor3", "TextDim")

		local SldHabegPowerBg = Instance.new("TextButton", CardHabeg)
		SldHabegPowerBg.Text = ""
		SldHabegPowerBg.Size = UDim2.new(0.55, 0, 0, 8)
		SldHabegPowerBg.Position = UDim2.new(0.42, 0, 0, 131)
		SldHabegPowerBg.BackgroundColor3 = C_SIDE
		SldHabegPowerBg.AutoButtonColor = false
		Instance.new("UICorner", SldHabegPowerBg).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldHabegPowerBg, "BackgroundColor3", "Side")

		local habegPower = 15 -- Default: 15 boost
		local SldHabegPowerFill = Instance.new("Frame", SldHabegPowerBg)
		SldHabegPowerFill.Size = UDim2.new(habegPower / 100, 0, 1, 0)
		SldHabegPowerFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldHabegPowerFill).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldHabegPowerFill, "BackgroundColor3", "Accent")

		-- Status Indicator
		local LblHabegStatus = Instance.new("TextLabel", CardHabeg)
		LblHabegStatus.Text = "⏸ Ready — Press keybind or click to activate"
		LblHabegStatus.Size = UDim2.new(0.94, 0, 0, 20)
		LblHabegStatus.Position = UDim2.new(0.03, 0, 0, 155)
		LblHabegStatus.BackgroundTransparency = 1
		LblHabegStatus.TextColor3 = C_TEXT_DIM
		LblHabegStatus.Font = Enum.Font.Gotham
		LblHabegStatus.TextSize = 10
		LblHabegStatus.TextXAlignment = Enum.TextXAlignment.Left
		LblHabegStatus.TextWrapped = true
		RegisterTheme(LblHabegStatus, "TextColor3", "TextDim")

		-- Keybind display (dynamically shows configured key)
		local LblHabegKey = Instance.new("TextLabel", CardHabeg)
		local function UpdateHabegKeyLabel()
			local actionKey = (Config.Keybinds and Config.Keybinds.ToggleHabegAction)
			local toggleKey = (Config.Keybinds and Config.Keybinds.ToggleHabeg)
			local actionName = actionKey and actionKey.Name or "H"
			local toggleName = toggleKey and toggleKey.Name or "(set in Config)"
			LblHabegKey.Text = "ACTION: " .. actionName .. "  |  TOGGLE: " .. toggleName .. " (set in Config tab)"
		end
		UpdateHabegKeyLabel()
		LblHabegKey.Size = UDim2.new(0.94, 0, 0, 18)
		LblHabegKey.Position = UDim2.new(0.03, 0, 0, 178)
		LblHabegKey.BackgroundTransparency = 1
		LblHabegKey.TextColor3 = C_TEXT_DIM
		LblHabegKey.Font = Enum.Font.Gotham
		LblHabegKey.TextSize = 9
		LblHabegKey.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(LblHabegKey, "TextColor3", "TextDim")

		-- Slider Drag Logic
		local draggingHabegAngle, draggingHabegPower = false, false

		SldHabegAngleBg.MouseButton1Down:Connect(function() draggingHabegAngle = true end)
		SldHabegPowerBg.MouseButton1Down:Connect(function() draggingHabegPower = true end)

		UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingHabegAngle, draggingHabegPower = false, false
			end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				if draggingHabegAngle then
					local sc = math.clamp((i.Position.X - SldHabegAngleBg.AbsolutePosition.X) / SldHabegAngleBg.AbsoluteSize.X, 0, 1)
					habegAngle = math.floor(90 + sc * 90) -- Range 90°-180°
					SldHabegAngleFill.Size = UDim2.new(sc, 0, 1, 0)
					LblHabegAngle.Text = "ANGLE: " .. habegAngle .. "°"
				elseif draggingHabegPower then
					local sc = math.clamp((i.Position.X - SldHabegPowerBg.AbsolutePosition.X) / SldHabegPowerBg.AbsoluteSize.X, 0, 1)
					habegPower = math.floor(sc * 100) -- Range 0-100
					SldHabegPowerFill.Size = UDim2.new(sc, 0, 1, 0)
					LblHabegPower.Text = "JUMP BOOST: " .. habegPower
				end
			end
		end)

		-- Core Habeg State
		local isHabegEnabled = false
		local habegLoop = nil
		local habegCooldown = false

		-- Perform the Habeg action INSTANTLY — no ground check, no queue
		local function PerformHabeg()
			if habegCooldown then return end
			habegCooldown = true

			-- task.spawn so each press runs independently and doesn't block
			task.spawn(function()
				local c = LocalPlayer.Character
				local h = c and c:FindFirstChild("Humanoid")
				local r = c and c:FindFirstChild("HumanoidRootPart")
				if not h or not r then
					habegCooldown = false
					return
				end

				LblHabegStatus.Text = "⚡ HABEG!"
				LblHabegStatus.TextColor3 = C_YELLOW

				-- Step 1: Disable ShiftLock from tools (if active)
				local wasShiftLockOn = (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)
				if wasShiftLockOn and UIHandlers.ToggleShiftLock then
					UIHandlers.ToggleShiftLock(false, true) -- Turn OFF silently
				end

				-- Step 2: Get movement direction
				local moveDir = h.MoveDirection
				if moveDir.Magnitude < 0.1 then
					local cam = workspace.CurrentCamera
					if cam then
						moveDir = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
						if moveDir.Magnitude > 0 then
							moveDir = moveDir.Unit
						else
							moveDir = r.CFrame.LookVector
						end
					else
						moveDir = r.CFrame.LookVector
					end
				end

				-- Step 3: Rotate body OPPOSITE from movement direction
				local angleRad = math.rad(habegAngle)
				local cosA = math.cos(angleRad)
				local sinA = math.sin(angleRad)
				local offsetX = moveDir.X * cosA - moveDir.Z * sinA
				local offsetZ = moveDir.X * sinA + moveDir.Z * cosA
				local offsetDir = Vector3.new(offsetX, 0, offsetZ)
				if offsetDir.Magnitude > 0 then
					offsetDir = offsetDir.Unit
				end

				-- Face away from movement direction
				local targetPos = r.Position + offsetDir * 10
				local lookCF = CFrame.lookAt(r.Position, targetPos)
				r.CFrame = CFrame.new(r.Position) * lookCF.Rotation

				-- Step 4: Jump immediately
				task.wait(0.03)
				h:ChangeState(Enum.HumanoidStateType.Jumping)

				-- Step 5: Apply upward boost if slider > 0
				if habegPower > 0 and r and r.Parent then
					task.wait(0.03)
					local vel = r.AssemblyLinearVelocity
					-- Only add UPWARD velocity, don't touch horizontal
					r.AssemblyLinearVelocity = Vector3.new(vel.X, vel.Y + habegPower, vel.Z)
					LblHabegStatus.Text = "🚀 Boost +" .. habegPower .. " up!"
				else
					LblHabegStatus.Text = "🚀 Jumped!"
				end
				LblHabegStatus.TextColor3 = C_GREEN

				-- Step 6: Restore ShiftLock from tools (if was on before)
				if wasShiftLockOn and UIHandlers.ToggleShiftLock then
					task.delay(0.1, function()
						UIHandlers.ToggleShiftLock(true, true) -- Turn ON silently
					end)
				end

				-- Reset cooldown quickly so next press works fast
				task.wait(0.1)
				habegCooldown = false
				if isHabegEnabled then
					LblHabegStatus.Text = "⏸ Ready"
					LblHabegStatus.TextColor3 = C_TEXT_DIM
				end
			end)
		end

		-- Toggle Habeg Feature
		local function ToggleHabeg(forceEnable)
			if forceEnable ~= nil then
				if forceEnable == isHabegEnabled then return end
			end

			isHabegEnabled = not isHabegEnabled
			BtnHabeg.Text = "HABEG: " .. (isHabegEnabled and L("on") or L("off"))
			BtnHabeg.TextColor3 = isHabegEnabled and C_GREEN or C_TEXT_DIM
			BtnHabeg.UIStroke.Color = isHabegEnabled and C_GREEN or C_TEXT_DIM
			ShowFeatureToast("Habeg (Jump Bug)", isHabegEnabled)

			if isHabegEnabled then
				UpdateHabegKeyLabel()
				local actionKey = (Config.Keybinds and Config.Keybinds.ToggleHabegAction) or Enum.KeyCode.H
				LblHabegStatus.Text = "⏸ Ready — Press " .. actionKey.Name .. " to habeg"
				LblHabegStatus.TextColor3 = C_TEXT_DIM

				-- In hold mode, heartbeat loop for continuous habeg while holding key
				if habegModeHold then
					habegLoop = RunService.Heartbeat:Connect(function()
						if not isHabegEnabled then return end
						local habegActionKey = (Config.Keybinds and Config.Keybinds.ToggleHabegAction) or Enum.KeyCode.H
						local hHeld = UserInputService:IsKeyDown(habegActionKey)
						if hHeld and not habegCooldown then
							PerformHabeg()
						end
					end)
					table.insert(Connections, habegLoop)
				end
			else
				habegCooldown = false
				LblHabegStatus.Text = "⏸ Ready — Press keybind or click to activate"
				LblHabegStatus.TextColor3 = C_TEXT_DIM
				if habegLoop then
					habegLoop:Disconnect()
					habegLoop = nil
				end
			end
		end

		BtnHabeg.MouseButton1Click:Connect(function()
			ToggleHabeg()
		end)
		UIHandlers.ToggleHabeg = ToggleHabeg

		-- Habeg keybind input handler (every press = instant habeg)
		local habegInputCon = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if not isHabegEnabled then return end
			if _G.StarshipIsBindingKeybind then return end

			local habegKey = (Config.Keybinds and Config.Keybinds.ToggleHabegAction) or Enum.KeyCode.H
			if input.KeyCode == habegKey then
				if not habegModeHold then
					PerformHabeg()
				end
			end
		end)
		table.insert(Connections, habegInputCon)

		-- Enable by default
		task.spawn(function()
			task.wait(0.5)
			ToggleHabeg(true)
		end)
	end

	-- 4.5 CLIMB STRAFE
	-- Move horizontally while climbing on TrussParts/Ladders
	do
		local CardClimbStrafe = CreateCard("CLIMB STRAFE", 130, 4.5)

		local BtnClimbStrafe, ClimbStrafeContainer = CreateFeatureButton(
			CardClimbStrafe,
			"CLIMB STRAFE: " .. L("off"),
			"Press A/D to move sideways while climbing",
			UDim2.new(0.94, 0, 0, 55),
			UDim2.new(0.03, 0, 0, 35),
			C_TEXT_DIM
		)

		-- Strafe Speed Slider
		local LblStrafeSpeed = Instance.new("TextLabel", CardClimbStrafe)
		LblStrafeSpeed.Text = "SPEED: 12"
		LblStrafeSpeed.Size = UDim2.new(0.35, 0, 0, 20)
		LblStrafeSpeed.Position = UDim2.new(0.03, 0, 0, 95)
		LblStrafeSpeed.BackgroundTransparency = 1
		LblStrafeSpeed.TextColor3 = C_TEXT_DIM
		LblStrafeSpeed.Font = Enum.Font.GothamBold
		LblStrafeSpeed.TextSize = 10
		LblStrafeSpeed.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(LblStrafeSpeed, "TextColor3", "TextDim")

		local SldStrafeSpeedBg = Instance.new("TextButton", CardClimbStrafe)
		SldStrafeSpeedBg.Text = ""
		SldStrafeSpeedBg.Size = UDim2.new(0.55, 0, 0, 8)
		SldStrafeSpeedBg.Position = UDim2.new(0.42, 0, 0, 101)
		SldStrafeSpeedBg.BackgroundColor3 = C_SIDE
		SldStrafeSpeedBg.AutoButtonColor = false
		Instance.new("UICorner", SldStrafeSpeedBg).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldStrafeSpeedBg, "BackgroundColor3", "Side")

		local strafeSpeed = 12 -- Default speed
		local SldStrafeSpeedFill = Instance.new("Frame", SldStrafeSpeedBg)
		SldStrafeSpeedFill.Size = UDim2.new((strafeSpeed - 5) / 25, 0, 1, 0) -- Range 5-30
		SldStrafeSpeedFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldStrafeSpeedFill).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldStrafeSpeedFill, "BackgroundColor3", "Accent")

		-- Slider drag handler
		local draggingStrafeSpeed = false

		SldStrafeSpeedBg.MouseButton1Down:Connect(function()
			draggingStrafeSpeed = true
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingStrafeSpeed = false
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				if draggingStrafeSpeed then
					local rx = input.Position.X - SldStrafeSpeedBg.AbsolutePosition.X
					local sc = math.clamp(rx / SldStrafeSpeedBg.AbsoluteSize.X, 0, 1)
					strafeSpeed = math.floor(5 + sc * 25) -- Range 5-30
					SldStrafeSpeedFill.Size = UDim2.new(sc, 0, 1, 0)
					LblStrafeSpeed.Text = "SPEED: " .. strafeSpeed
				end
			end
		end)

		local isClimbStrafe = false
		local climbStrafeLoop = nil

		local function ToggleClimbStrafe(forceEnable)
			if forceEnable ~= nil then
				if forceEnable == isClimbStrafe then return end
			end

			isClimbStrafe = not isClimbStrafe
			BtnClimbStrafe.Text = "CLIMB STRAFE: " .. (isClimbStrafe and L("on") or L("off"))
			BtnClimbStrafe.TextColor3 = isClimbStrafe and C_GREEN or C_TEXT_DIM
			BtnClimbStrafe.UIStroke.Color = isClimbStrafe and C_GREEN or C_TEXT_DIM
			ShowFeatureToast("Climb Strafe", isClimbStrafe)

			if isClimbStrafe then
				climbStrafeLoop = RunService.Heartbeat:Connect(function()
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChild("Humanoid")
					local r = c and c:FindFirstChild("HumanoidRootPart")

					if not h or not r then return end

					local state = h:GetState()
					local isClimbing = state == Enum.HumanoidStateType.Climbing

					-- Only apply strafe when climbing
					if isClimbing then
						-- Keyboard input
						local aPressed = UserInputService:IsKeyDown(Enum.KeyCode.A)
						local dPressed = UserInputService:IsKeyDown(Enum.KeyCode.D)

						-- Gamepad input (Thumbstick1 left/right)
						local gamepadLeftX = 0
						local success, gamepadState = pcall(function()
							return UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
						end)
						if success and gamepadState then
							for _, input in ipairs(gamepadState) do
								if input.KeyCode == Enum.KeyCode.Thumbstick1 then
									gamepadLeftX = input.Position.X
									break
								end
							end
						end

						-- Combine keyboard and gamepad
						local strafeInput = 0
						if aPressed then
							strafeInput = -1
						elseif dPressed then
							strafeInput = 1
						elseif math.abs(gamepadLeftX) > 0.3 then
							strafeInput = gamepadLeftX -- -1 to 1 from joystick
						end

						if strafeInput ~= 0 then
							local currentVel = r.AssemblyLinearVelocity
							
							-- Get camera's right vector for strafe direction
							local camera = workspace.CurrentCamera
							local camRight = camera.CFrame.RightVector
							local horizontalRight = Vector3.new(camRight.X, 0, camRight.Z).Unit

							-- Calculate strafe velocity (use strafeInput for direction and intensity)
							local strafeDir = horizontalRight * strafeInput

							-- Apply strafe velocity (keep vertical velocity for climbing)
							local newVelX = strafeDir.X * strafeSpeed
							local newVelZ = strafeDir.Z * strafeSpeed

							r.AssemblyLinearVelocity = Vector3.new(newVelX, currentVel.Y, newVelZ)
						end
					end
				end)
				table.insert(Connections, climbStrafeLoop)
			else
				if climbStrafeLoop then
					climbStrafeLoop:Disconnect()
					climbStrafeLoop = nil
				end
			end
		end

		BtnClimbStrafe.MouseButton1Click:Connect(function()
			ToggleClimbStrafe()
		end)
		UIHandlers.ToggleClimbStrafe = ToggleClimbStrafe
	end

	-- 4.6 CLIMB HOP
	-- Jump sideways while climbing to reach adjacent trusses
	do
		local CardClimbHop = CreateCard("CLIMB HOP", 155, 4.6)

		local BtnClimbHop, ClimbHopContainer = CreateFeatureButton(
			CardClimbHop,
			"CLIMB HOP: " .. L("off"),
			"A/D=sideways | W+A/D=up | S+A/D=down",
			UDim2.new(0.94, 0, 0, 55),
			UDim2.new(0.03, 0, 0, 35),
			C_TEXT_DIM
		)

		-- Hop Power Slider (Horizontal)
		local LblHopPower = Instance.new("TextLabel", CardClimbHop)
		LblHopPower.Text = "HOP POWER: 20"
		LblHopPower.Size = UDim2.new(0.35, 0, 0, 20)
		LblHopPower.Position = UDim2.new(0.03, 0, 0, 95)
		LblHopPower.BackgroundTransparency = 1
		LblHopPower.TextColor3 = C_TEXT_DIM
		LblHopPower.Font = Enum.Font.GothamBold
		LblHopPower.TextSize = 10
		LblHopPower.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(LblHopPower, "TextColor3", "TextDim")

		local SldHopPowerBg = Instance.new("TextButton", CardClimbHop)
		SldHopPowerBg.Text = ""
		SldHopPowerBg.Size = UDim2.new(0.55, 0, 0, 8)
		SldHopPowerBg.Position = UDim2.new(0.42, 0, 0, 101)
		SldHopPowerBg.BackgroundColor3 = C_SIDE
		SldHopPowerBg.AutoButtonColor = false
		Instance.new("UICorner", SldHopPowerBg).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldHopPowerBg, "BackgroundColor3", "Side")

		local hopPower = 20 -- Default horizontal hop power
		local SldHopPowerFill = Instance.new("Frame", SldHopPowerBg)
		SldHopPowerFill.Size = UDim2.new((hopPower - 10) / 30, 0, 1, 0) -- Range 10-40
		SldHopPowerFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldHopPowerFill).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldHopPowerFill, "BackgroundColor3", "Accent")

		-- Hop Height Slider (Vertical)
		local LblHopHeight = Instance.new("TextLabel", CardClimbHop)
		LblHopHeight.Text = "HOP HEIGHT: 10"
		LblHopHeight.Size = UDim2.new(0.35, 0, 0, 20)
		LblHopHeight.Position = UDim2.new(0.03, 0, 0, 120)
		LblHopHeight.BackgroundTransparency = 1
		LblHopHeight.TextColor3 = C_TEXT_DIM
		LblHopHeight.Font = Enum.Font.GothamBold
		LblHopHeight.TextSize = 10
		LblHopHeight.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(LblHopHeight, "TextColor3", "TextDim")

		local SldHopHeightBg = Instance.new("TextButton", CardClimbHop)
		SldHopHeightBg.Text = ""
		SldHopHeightBg.Size = UDim2.new(0.55, 0, 0, 8)
		SldHopHeightBg.Position = UDim2.new(0.42, 0, 0, 126)
		SldHopHeightBg.BackgroundColor3 = C_SIDE
		SldHopHeightBg.AutoButtonColor = false
		Instance.new("UICorner", SldHopHeightBg).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldHopHeightBg, "BackgroundColor3", "Side")

		local hopHeight = 10 -- Default vertical hop power
		local SldHopHeightFill = Instance.new("Frame", SldHopHeightBg)
		SldHopHeightFill.Size = UDim2.new((hopHeight - 0) / 25, 0, 1, 0) -- Range 0-25
		SldHopHeightFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldHopHeightFill).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldHopHeightFill, "BackgroundColor3", "Accent")

		-- Slider drag handlers
		local draggingHopPower = false
		local draggingHopHeight = false

		SldHopPowerBg.MouseButton1Down:Connect(function()
			draggingHopPower = true
		end)
		SldHopHeightBg.MouseButton1Down:Connect(function()
			draggingHopHeight = true
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingHopPower = false
				draggingHopHeight = false
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				if draggingHopPower then
					local rx = input.Position.X - SldHopPowerBg.AbsolutePosition.X
					local sc = math.clamp(rx / SldHopPowerBg.AbsoluteSize.X, 0, 1)
					hopPower = math.floor(10 + sc * 30) -- Range 10-40
					SldHopPowerFill.Size = UDim2.new(sc, 0, 1, 0)
					LblHopPower.Text = "HOP POWER: " .. hopPower
				elseif draggingHopHeight then
					local rx = input.Position.X - SldHopHeightBg.AbsolutePosition.X
					local sc = math.clamp(rx / SldHopHeightBg.AbsoluteSize.X, 0, 1)
					hopHeight = math.floor(sc * 25) -- Range 0-25
					SldHopHeightFill.Size = UDim2.new(sc, 0, 1, 0)
					LblHopHeight.Text = "HOP HEIGHT: " .. hopHeight
				end
			end
		end)

		local isClimbHop = false
		local climbHopConnection = nil
		local lastHopTime = 0
		local HOP_COOLDOWN = 0.3 -- Cooldown between hops

		local function ToggleClimbHop(forceEnable)
			if forceEnable ~= nil then
				if forceEnable == isClimbHop then return end
			end

			isClimbHop = not isClimbHop
			BtnClimbHop.Text = "CLIMB HOP: " .. (isClimbHop and L("on") or L("off"))
			BtnClimbHop.TextColor3 = isClimbHop and C_GREEN or C_TEXT_DIM
			BtnClimbHop.UIStroke.Color = isClimbHop and C_GREEN or C_TEXT_DIM
			ShowFeatureToast("Climb Hop", isClimbHop)

			if isClimbHop then
				-- Track previous key states for edge detection
				local prevA, prevD, prevLT, prevRT = false, false, false, false

				climbHopConnection = RunService.Heartbeat:Connect(function()
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChild("Humanoid")
					local r = c and c:FindFirstChild("HumanoidRootPart")
					if not h or not r then return end

					local state = h:GetState()
					local isClimbing = state == Enum.HumanoidStateType.Climbing

					if not isClimbing then 
						prevA, prevD, prevLT, prevRT = false, false, false, false
						return 
					end

					-- Check cooldown
					local currentTime = tick()
					if currentTime - lastHopTime < HOP_COOLDOWN then return end

					-- Current key states
					local aPressed = UserInputService:IsKeyDown(Enum.KeyCode.A)
					local dPressed = UserInputService:IsKeyDown(Enum.KeyCode.D)

					-- Gamepad LT/RT
					local ltPressed = false
					local rtPressed = false
					pcall(function()
						ltPressed = UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2)
						rtPressed = UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
					end)

					-- Detect key press (edge detection - just pressed)
					local aJustPressed = aPressed and not prevA
					local dJustPressed = dPressed and not prevD
					local ltJustPressed = ltPressed and not prevLT
					local rtJustPressed = rtPressed and not prevRT

					-- Update previous states
					prevA, prevD, prevLT, prevRT = aPressed, dPressed, ltPressed, rtPressed

					local hopDirection = 0

					-- Keyboard hop (single button, on press)
					if aJustPressed then
						hopDirection = -1 -- Hop left
					elseif dJustPressed then
						hopDirection = 1 -- Hop right
					end

					-- Gamepad hop (LT/RT, on press)
					if ltJustPressed then
						hopDirection = -1 -- Hop left
					elseif rtJustPressed then
						hopDirection = 1 -- Hop right
					end

					-- Execute hop
					if hopDirection ~= 0 then
						lastHopTime = currentTime

						-- Check if W or S is held for vertical direction
						local wPressed = UserInputService:IsKeyDown(Enum.KeyCode.W)
						local sPressed = UserInputService:IsKeyDown(Enum.KeyCode.S)

						-- Get camera's right vector for hop direction
						local camera = workspace.CurrentCamera
						local camRight = camera.CFrame.RightVector
						local horizontalRight = Vector3.new(camRight.X, 0, camRight.Z).Unit

						-- Calculate vertical component based on W/S
						local verticalPower = 0
						if sPressed then
							-- S held = hop DOWN (negative height)
							verticalPower = -hopHeight
						elseif wPressed then
							-- W held = hop UP (extra height)
							verticalPower = hopHeight * 1.5
						else
							-- No W/S = normal hop height
							verticalPower = hopHeight
						end

						-- Calculate hop velocity
						local hopVelocity = horizontalRight * hopDirection * hopPower
						hopVelocity = hopVelocity + Vector3.new(0, verticalPower, 0)

						-- IMPORTANT: First change state to let go of truss, THEN apply velocity
						-- Roblox overrides velocity while in Climbing state
						h:ChangeState(Enum.HumanoidStateType.Jumping)
						
						-- Small delay to ensure state change takes effect
						task.defer(function()
							if r and r.Parent then
								r.AssemblyLinearVelocity = hopVelocity
							end
						end)
					end
				end)
				table.insert(Connections, climbHopConnection)
			else
				if climbHopConnection then
					climbHopConnection:Disconnect()
					climbHopConnection = nil
				end
			end
		end

		BtnClimbHop.MouseButton1Click:Connect(function()
			ToggleClimbHop()
		end)
		UIHandlers.ToggleClimbHop = ToggleClimbHop
	end

	-- 4.7 CLIMB ASSIST
	-- Auto-detect nearest truss and boost toward it when leaving climb state
	do
		local CardClimbAssist = CreateCard("CLIMB ASSIST", 130, 4.7)

		local BtnClimbAssist, ClimbAssistContainer = CreateFeatureButton(
			CardClimbAssist,
			"CLIMB ASSIST: " .. L("off"),
			"Auto boost to nearest truss when you let go (just press Space!)",
			UDim2.new(0.94, 0, 0, 55),
			UDim2.new(0.03, 0, 0, 35),
			C_TEXT_DIM
		)

		-- Boost Power Slider
		local LblAssistPower = Instance.new("TextLabel", CardClimbAssist)
		LblAssistPower.Text = "BOOST POWER: 25"
		LblAssistPower.Size = UDim2.new(0.35, 0, 0, 20)
		LblAssistPower.Position = UDim2.new(0.03, 0, 0, 95)
		LblAssistPower.BackgroundTransparency = 1
		LblAssistPower.TextColor3 = C_TEXT_DIM
		LblAssistPower.Font = Enum.Font.GothamBold
		LblAssistPower.TextSize = 10
		LblAssistPower.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(LblAssistPower, "TextColor3", "TextDim")

		local SldAssistPowerBg = Instance.new("TextButton", CardClimbAssist)
		SldAssistPowerBg.Text = ""
		SldAssistPowerBg.Size = UDim2.new(0.55, 0, 0, 8)
		SldAssistPowerBg.Position = UDim2.new(0.42, 0, 0, 101)
		SldAssistPowerBg.BackgroundColor3 = C_SIDE
		SldAssistPowerBg.AutoButtonColor = false
		Instance.new("UICorner", SldAssistPowerBg).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldAssistPowerBg, "BackgroundColor3", "Side")

		local assistPower = 25
		local SldAssistPowerFill = Instance.new("Frame", SldAssistPowerBg)
		SldAssistPowerFill.Size = UDim2.new((assistPower - 10) / 40, 0, 1, 0) -- Range 10-50
		SldAssistPowerFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldAssistPowerFill).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldAssistPowerFill, "BackgroundColor3", "Accent")

		-- Slider drag handler
		local draggingAssistPower = false

		SldAssistPowerBg.MouseButton1Down:Connect(function()
			draggingAssistPower = true
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingAssistPower = false
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				if draggingAssistPower then
					local rx = input.Position.X - SldAssistPowerBg.AbsolutePosition.X
					local sc = math.clamp(rx / SldAssistPowerBg.AbsoluteSize.X, 0, 1)
					assistPower = math.floor(10 + sc * 40) -- Range 10-50
					SldAssistPowerFill.Size = UDim2.new(sc, 0, 1, 0)
					LblAssistPower.Text = "BOOST POWER: " .. assistPower
				end
			end
		end)

		local isClimbAssist = false
		local climbAssistConnection = nil
		local wasClimbing = false
		local lastAssistTime = 0
		local ASSIST_COOLDOWN = 0.2
		local lastClimbedTruss = nil -- Track the truss we just left
		local lastClimbPosition = nil -- Track position when climbing

		-- Find nearest TrussPart in all directions (with direction priority)
		local function FindNearestTruss(character, rootPart, priorityDir)
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = { character }
			rayParams.FilterType = Enum.RaycastFilterType.Exclude

			local playerPos = rootPart.Position
			local SEARCH_DISTANCE = 25

			local bestTruss = nil
			local bestScore = math.huge -- Lower is better
			local bestPosition = nil

			-- Get camera vectors for relative directions
			local camera = workspace.CurrentCamera
			local camRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z).Unit
			local camForward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit

			-- Search in multiple directions
			local directions = {
				{dir = camRight, name = "right"},
				{dir = -camRight, name = "left"},
				{dir = Vector3.new(0, 1, 0), name = "up"},
				{dir = Vector3.new(0, -1, 0), name = "down"},
				{dir = camForward, name = "forward"},
				{dir = -camForward, name = "back"},
				-- Diagonals horizontal
				{dir = (camRight + camForward).Unit, name = "right"},
				{dir = (-camRight + camForward).Unit, name = "left"},
				{dir = (camRight - camForward).Unit, name = "right"},
				{dir = (-camRight - camForward).Unit, name = "left"},
				-- Diagonals with up
				{dir = (camRight + Vector3.new(0, 0.5, 0)).Unit, name = "right"},
				{dir = (-camRight + Vector3.new(0, 0.5, 0)).Unit, name = "left"},
				{dir = (camRight + Vector3.new(0, 1, 0)).Unit, name = "right"},
				{dir = (-camRight + Vector3.new(0, 1, 0)).Unit, name = "left"},
				-- Diagonals with down
				{dir = (camRight + Vector3.new(0, -0.5, 0)).Unit, name = "right"},
				{dir = (-camRight + Vector3.new(0, -0.5, 0)).Unit, name = "left"},
				{dir = (camRight + Vector3.new(0, -1, 0)).Unit, name = "right"},
				{dir = (-camRight + Vector3.new(0, -1, 0)).Unit, name = "left"},
			}

			for _, data in ipairs(directions) do
				local hitResult = workspace:Raycast(playerPos, data.dir * SEARCH_DISTANCE, rayParams)
				if hitResult then
					local hitPart = hitResult.Instance
					
					-- Skip if this is the truss we just left
					if hitPart == lastClimbedTruss then
						continue
					end
					
					-- Check if it's a TrussPart or climbable
					local isTruss = hitPart:IsA("TrussPart")
					if not isTruss then
						local name = hitPart.Name:lower()
						isTruss = name:find("ladder") or name:find("truss") or name:find("climb")
					end

					if isTruss then
						local dist = (hitResult.Position - playerPos).Magnitude
						
						-- Must be at least 2 studs away
						if dist > 2 then
							local score = dist
							
							-- Apply priority bonus if direction matches
							if priorityDir then
								if priorityDir == "left" and data.name == "left" then
									score = score * 0.2
								elseif priorityDir == "right" and data.name == "right" then
									score = score * 0.2
								elseif priorityDir == "up" and data.name == "up" then
									score = score * 0.2
								elseif priorityDir == "down" and data.name == "down" then
									score = score * 0.2
								end
							end
							
							if score < bestScore then
								bestScore = score
								bestTruss = hitPart
								bestPosition = hitResult.Position
							end
						end
					end
				end
			end

			return bestTruss, bestPosition
		end

		-- Detect which truss player is currently on
		local function GetCurrentTruss(character, rootPart)
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = { character }
			rayParams.FilterType = Enum.RaycastFilterType.Exclude

			local directions = {
				Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
				Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
				Vector3.new(0, 1, 0), Vector3.new(0, -1, 0),
			}

			for _, dir in ipairs(directions) do
				local hit = workspace:Raycast(rootPart.Position, dir * 3, rayParams)
				if hit and (hit.Instance:IsA("TrussPart") or hit.Instance.Name:lower():find("truss")) then
					return hit.Instance
				end
			end
			return nil
		end

		local function ToggleClimbAssist(forceEnable)
			if forceEnable ~= nil then
				if forceEnable == isClimbAssist then return end
			end

			isClimbAssist = not isClimbAssist
			BtnClimbAssist.Text = "CLIMB ASSIST: " .. (isClimbAssist and L("on") or L("off"))
			BtnClimbAssist.TextColor3 = isClimbAssist and C_GREEN or C_TEXT_DIM
			BtnClimbAssist.UIStroke.Color = isClimbAssist and C_GREEN or C_TEXT_DIM
			ShowFeatureToast("Climb Assist", isClimbAssist)

			if isClimbAssist then
				climbAssistConnection = RunService.Heartbeat:Connect(function()
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChild("Humanoid")
					local r = c and c:FindFirstChild("HumanoidRootPart")
					if not h or not r then return end

					local state = h:GetState()
					local isClimbing = state == Enum.HumanoidStateType.Climbing

					-- While climbing, track current truss and position
					if isClimbing then
						lastClimbedTruss = GetCurrentTruss(c, r)
						lastClimbPosition = r.Position
					end

					-- Detect transition: was climbing -> now jumping/falling
					if wasClimbing and not isClimbing then
						local currentTime = tick()
						if currentTime - lastAssistTime > ASSIST_COOLDOWN then
							-- Check direction keys for priority
							local priorityDir = nil
							if UserInputService:IsKeyDown(Enum.KeyCode.A) then
								priorityDir = "left"
							elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
								priorityDir = "right"
							elseif UserInputService:IsKeyDown(Enum.KeyCode.W) then
								priorityDir = "up"
							elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
								priorityDir = "down"
							end

							-- Find nearest truss
							local nearestTruss, targetPos = FindNearestTruss(c, r, priorityDir)
							
							if nearestTruss and targetPos then
								lastAssistTime = currentTime
								
								-- Calculate direction to target
								local direction = (targetPos - r.Position).Unit
								local distance = (targetPos - r.Position).Magnitude
								
								-- Calculate boost power based on distance
								local power = math.clamp(assistPower + distance * 0.5, assistPower, assistPower * 1.5)
								
								-- Boost toward the truss
								local boostVelocity = direction * power
								
								-- Always add some upward to prevent falling
								boostVelocity = boostVelocity + Vector3.new(0, 12, 0)
								
								-- Apply immediately
								r.AssemblyLinearVelocity = boostVelocity
							else
								-- No truss found, just give upward boost to prevent fall
								r.AssemblyLinearVelocity = r.AssemblyLinearVelocity + Vector3.new(0, 15, 0)
							end
						end
					end

					wasClimbing = isClimbing
				end)
				table.insert(Connections, climbAssistConnection)
			else
				if climbAssistConnection then
					climbAssistConnection:Disconnect()
					climbAssistConnection = nil
				end
				wasClimbing = false
			end
		end

		BtnClimbAssist.MouseButton1Click:Connect(function()
			ToggleClimbAssist()
		end)
		UIHandlers.ToggleClimbAssist = ToggleClimbAssist
	end

	-- 4.8 ANTI-WIND (SPEED-AWARE MODE)
	-- Block wind effect with speed-adaptive control
	-- High speed (coil) = more responsive, less momentum
	-- Normal speed = natural momentum preserved
	do
		local CardAntiWind = CreateCard("ANTI-WIND", 100, 4.8)

		local BtnAntiWind, AntiWindContainer = CreateFeatureButton(
			CardAntiWind,
			"ANTI-WIND: " .. L("off"),
			"Speed-aware wind block (coil-friendly!)",
			UDim2.new(0.94, 0, 0, 55),
			UDim2.new(0.03, 0, 0, 35),
			C_TEXT_DIM
		)

		local isAntiWind = false
		local antiWindLoop = nil
		
		-- Track velocity when leaving ground to preserve jump momentum
		local jumpStartVelocity = Vector3.new(0, 0, 0)
		local wasOnGround = true
		local lastGroundVelocity = Vector3.new(0, 0, 0)

		-- Speed thresholds
		local NORMAL_SPEED = 16 -- Default walkspeed
		local HIGH_SPEED = 50 -- Coil territory

		-- Cleanup function
		local function CleanupWindObjects(rootPart)
			if rootPart then
				for _, child in pairs(rootPart:GetChildren()) do
					if child.Name == "StarshipWindLock" or child.Name == "StarshipWindBlocker" or child.Name == "StarshipWindCounter" then
						child:Destroy()
					end
				end
			end
		end

		local function ToggleAntiWind(forceEnable)
			if forceEnable ~= nil then
				if forceEnable == isAntiWind then return end
			end

			isAntiWind = not isAntiWind
			BtnAntiWind.Text = "ANTI-WIND: " .. (isAntiWind and L("on") or L("off"))
			BtnAntiWind.TextColor3 = isAntiWind and C_GREEN or C_TEXT_DIM
			BtnAntiWind.UIStroke.Color = isAntiWind and C_GREEN or C_TEXT_DIM
			ShowFeatureToast("Anti-Wind", isAntiWind)

			if isAntiWind then
				antiWindLoop = RunService.Heartbeat:Connect(function(dt)
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChild("Humanoid")
					local r = c and c:FindFirstChild("HumanoidRootPart")
					
					if not c or not h or not r then return end
					
					local state = h:GetState()
					local isOnGround = state == Enum.HumanoidStateType.Running 
						or state == Enum.HumanoidStateType.RunningNoPhysics
						or state == Enum.HumanoidStateType.Landed
					local isInAir = state == Enum.HumanoidStateType.Jumping 
						or state == Enum.HumanoidStateType.Freefall
					
					local currentVel = r.AssemblyLinearVelocity
					local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)
					local walkSpeed = h.WalkSpeed
					
					-- Calculate speed factor (0 = normal speed, 1 = very high speed)
					local speedFactor = math.clamp((walkSpeed - NORMAL_SPEED) / (HIGH_SPEED - NORMAL_SPEED), 0, 1)
					
					-- Track ground velocity for momentum preservation
					if isOnGround then
						lastGroundVelocity = horizontalVel
						wasOnGround = true
					end
					
					-- Detect jump start - save momentum
					if wasOnGround and isInAir then
						jumpStartVelocity = lastGroundVelocity
						wasOnGround = false
					end
					
					-- ONLY apply wind correction when IN AIR
					if isInAir then
						-- Get player's current input direction
						local moveDir = h.MoveDirection
						local inputVel = moveDir * walkSpeed
						
						-- SPEED-ADAPTIVE SETTINGS
						-- At high speed: more responsive, less momentum
						-- At normal speed: more momentum, natural feel
						
						-- Momentum weight: 30% at normal speed → 5% at high speed
						local momentumWeight = 0.30 - (speedFactor * 0.25)
						-- Input weight: 70% at normal speed → 95% at high speed
						local inputWeight = 0.70 + (speedFactor * 0.25)
						-- Correction speed: 15% at normal speed → 50% at high speed
						local correctionSpeed = 0.15 + (speedFactor * 0.35)
						-- Momentum decay when not pressing: 95% at normal → 60% at high speed
						local momentumDecay = 0.95 - (speedFactor * 0.35)
						
						local targetHorizontalVel
						
						if moveDir.Magnitude > 0.1 then
							-- Player is actively controlling
							targetHorizontalVel = (jumpStartVelocity * momentumWeight) + (inputVel * inputWeight)
						else
							-- Player not pressing anything
							-- At high speed, stop faster (less momentum carry)
							targetHorizontalVel = jumpStartVelocity * momentumDecay
							
							-- At high speed, also decay the stored momentum faster
							if speedFactor > 0.5 then
								jumpStartVelocity = jumpStartVelocity * 0.9
							end
						end
						
						-- Apply correction with speed-adaptive smoothing
						local correctedVel = horizontalVel:Lerp(targetHorizontalVel, correctionSpeed)
						
						-- Apply corrected velocity (keep vertical unchanged)
						r.AssemblyLinearVelocity = Vector3.new(
							correctedVel.X,
							currentVel.Y,
							correctedVel.Z
						)
					end
					-- When on ground, don't interfere - let normal physics work
				end)
				table.insert(Connections, antiWindLoop)
			else
				if antiWindLoop then
					antiWindLoop:Disconnect()
					antiWindLoop = nil
				end
				-- Cleanup
				local c = LocalPlayer.Character
				if c then
					local r = c:FindFirstChild("HumanoidRootPart")
					if r then
						CleanupWindObjects(r)
					end
				end
			end
		end

		BtnAntiWind.MouseButton1Click:Connect(function()
			ToggleAntiWind()
		end)
		UIHandlers.ToggleAntiWind = ToggleAntiWind
	end

	-- 4.9 LADDER MAGNET
	-- Auto-detect nearby ladders/trusses and guide character towards them
	-- Slows down when approaching for precise landing
	do
		local CardLadderMagnet = CreateCard("LADDER MAGNET", 130, 4.9)

		local BtnLadderMagnet, LadderMagnetContainer = CreateFeatureButton(
			CardLadderMagnet,
			"LADDER MAGNET: " .. L("off"),
			"Auto-guide to nearby ladders (great for coil!)",
			UDim2.new(0.94, 0, 0, 55),
			UDim2.new(0.03, 0, 0, 35),
			C_TEXT_DIM
		)

		-- Magnet Strength Slider
		local LblMagnetStrength = Instance.new("TextLabel", CardLadderMagnet)
		LblMagnetStrength.Text = "STRENGTH: 50%"
		LblMagnetStrength.Size = UDim2.new(0.35, 0, 0, 20)
		LblMagnetStrength.Position = UDim2.new(0.03, 0, 0, 95)
		LblMagnetStrength.BackgroundTransparency = 1
		LblMagnetStrength.TextColor3 = C_TEXT_DIM
		LblMagnetStrength.Font = Enum.Font.GothamBold
		LblMagnetStrength.TextSize = 10
		LblMagnetStrength.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(LblMagnetStrength, "TextColor3", "TextDim")

		local SldMagnetStrengthBg = Instance.new("TextButton", CardLadderMagnet)
		SldMagnetStrengthBg.Text = ""
		SldMagnetStrengthBg.Size = UDim2.new(0.55, 0, 0, 8)
		SldMagnetStrengthBg.Position = UDim2.new(0.42, 0, 0, 101)
		SldMagnetStrengthBg.BackgroundColor3 = C_SIDE
		SldMagnetStrengthBg.AutoButtonColor = false
		Instance.new("UICorner", SldMagnetStrengthBg).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldMagnetStrengthBg, "BackgroundColor3", "Side")

		local magnetStrength = 50 -- Default 50%
		local SldMagnetStrengthFill = Instance.new("Frame", SldMagnetStrengthBg)
		SldMagnetStrengthFill.Size = UDim2.new(magnetStrength / 100, 0, 1, 0)
		SldMagnetStrengthFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldMagnetStrengthFill).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldMagnetStrengthFill, "BackgroundColor3", "Accent")

		-- Slider drag handler
		local draggingMagnetStrength = false

		SldMagnetStrengthBg.MouseButton1Down:Connect(function()
			draggingMagnetStrength = true
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingMagnetStrength = false
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				if draggingMagnetStrength then
					local rx = input.Position.X - SldMagnetStrengthBg.AbsolutePosition.X
					local sc = math.clamp(rx / SldMagnetStrengthBg.AbsoluteSize.X, 0, 1)
					magnetStrength = math.floor(sc * 100)
					SldMagnetStrengthFill.Size = UDim2.new(sc, 0, 1, 0)
					LblMagnetStrength.Text = "STRENGTH: " .. magnetStrength .. "%"
				end
			end
		end)

		local isLadderMagnet = false
		local ladderMagnetLoop = nil

		-- Detection settings
		local DETECT_RADIUS = 15 -- Studs to search for ladders
		local MAGNET_RANGE = 8 -- Start magnetizing at this distance
		local SLOW_DOWN_RANGE = 5 -- Start slowing down at this distance

		-- Check if part is a ladder/truss
		local function IsLadderPart(part)
			if not part then return false end
			if part:IsA("TrussPart") then return true end
			local name = part.Name:lower()
			return name:find("ladder") or name:find("truss") or name:find("climb") or name:find("vine") or name:find("rope")
		end

		-- Find nearest ladder
		local function FindNearestLadder(character, rootPart)
			local playerPos = rootPart.Position
			local nearestLadder = nil
			local nearestDist = math.huge
			local nearestPos = nil

			-- Search in workspace for nearby trusses
			local parts = workspace:GetPartBoundsInRadius(playerPos, DETECT_RADIUS)
			
			for _, part in pairs(parts) do
				if IsLadderPart(part) and not part:IsDescendantOf(character) then
					local dist = (part.Position - playerPos).Magnitude
					if dist < nearestDist then
						nearestDist = dist
						nearestLadder = part
						nearestPos = part.Position
					end
				end
			end

			return nearestLadder, nearestPos, nearestDist
		end

		local function ToggleLadderMagnet(forceEnable)
			if forceEnable ~= nil then
				if forceEnable == isLadderMagnet then return end
			end

			isLadderMagnet = not isLadderMagnet
			BtnLadderMagnet.Text = "LADDER MAGNET: " .. (isLadderMagnet and L("on") or L("off"))
			BtnLadderMagnet.TextColor3 = isLadderMagnet and C_GREEN or C_TEXT_DIM
			BtnLadderMagnet.UIStroke.Color = isLadderMagnet and C_GREEN or C_TEXT_DIM
			ShowFeatureToast("Ladder Magnet", isLadderMagnet)

			if isLadderMagnet then
				ladderMagnetLoop = RunService.Heartbeat:Connect(function(dt)
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChild("Humanoid")
					local r = c and c:FindFirstChild("HumanoidRootPart")
					
					if not c or not h or not r then return end
					
					local state = h:GetState()
					local isInAir = state == Enum.HumanoidStateType.Jumping 
						or state == Enum.HumanoidStateType.Freefall
					
					-- Only activate when in air
					if not isInAir then return end
					
					-- Find nearest ladder
					local ladder, ladderPos, distance = FindNearestLadder(c, r)
					
					if not ladder or distance > MAGNET_RANGE then return end
					
					-- Calculate magnet effect based on distance
					-- Closer = stronger effect
					local distanceFactor = 1 - (distance / MAGNET_RANGE)
					local strength = (magnetStrength / 100) * distanceFactor
					
					local currentVel = r.AssemblyLinearVelocity
					local currentSpeed = Vector3.new(currentVel.X, 0, currentVel.Z).Magnitude
					
					-- Calculate direction to ladder
					local dirToLadder = (ladderPos - r.Position)
					local horizontalDir = Vector3.new(dirToLadder.X, 0, dirToLadder.Z)
					if horizontalDir.Magnitude > 0.1 then
						horizontalDir = horizontalDir.Unit
					else
						return -- Already at ladder
					end
					
					-- MAGNET EFFECT: Guide velocity toward ladder
					local targetVel = horizontalDir * math.min(currentSpeed, h.WalkSpeed * 0.7)
					
					-- SLOW DOWN EFFECT: Reduce speed when very close
					local slowFactor = 1
					if distance < SLOW_DOWN_RANGE then
						-- Closer = slower (scale from 1.0 to 0.3)
						slowFactor = 0.3 + (0.7 * (distance / SLOW_DOWN_RANGE))
						targetVel = targetVel * slowFactor
					end
					
					-- Blend current velocity with target velocity
					local blendedVel = Vector3.new(currentVel.X, 0, currentVel.Z):Lerp(targetVel, strength * 0.3)
					
					-- Apply new velocity (keep vertical unchanged)
					r.AssemblyLinearVelocity = Vector3.new(
						blendedVel.X,
						currentVel.Y,
						blendedVel.Z
					)
				end)
				table.insert(Connections, ladderMagnetLoop)
			else
				if ladderMagnetLoop then
					ladderMagnetLoop:Disconnect()
					ladderMagnetLoop = nil
				end
			end
		end

		BtnLadderMagnet.MouseButton1Click:Connect(function()
			ToggleLadderMagnet()
		end)
		UIHandlers.ToggleLadderMagnet = ToggleLadderMagnet
	end

	-- 5. QUICK BOOST (L2/R2 or A/D Control) + BUG JUMP SIMULATION
	-- Technique: Press L2/R2 or A/D in air to get vertical boost
	-- BUG JUMP: Press A/D + W together for 1.5x boost (works with Shift Lock ON/OFF)
	do
		local CardBoost = CreateCard("QUICK BOOST", 295, 5)

		local BtnQuickBoost, QuickBoostContainer = CreateFeatureButton(
			CardBoost,
			L("quick_boost") .. ": " .. L("off"),
			L("quick_boost_desc"),
			UDim2.new(0.94, 0, 0, 35),
			UDim2.new(0.03, 0, 0, 35),
			C_TEXT_DIM
		)

		-- Bug Jump Toggle (A/D + W for extra boost)
		local BtnBugJump = Instance.new("TextButton", CardBoost)
		BtnBugJump.Text = "🚀 BUG JUMP: ON"
		BtnBugJump.Size = UDim2.new(0.45, 0, 0, 30)
		BtnBugJump.Position = UDim2.new(0.03, 0, 0, 75)
		BtnBugJump.BackgroundColor3 = C_SIDE
		BtnBugJump.TextColor3 = C_GREEN
		BtnBugJump.Font = Enum.Font.GothamBlack
		BtnBugJump.TextSize = 12
		Instance.new("UICorner", BtnBugJump).CornerRadius = UDim.new(0, 6)

		RegisterTheme(BtnBugJump, "BackgroundColor3", "Sidebar")

		-- Bug Jump enabled by default
		local bugJumpEnabled = true

		BtnBugJump.MouseButton1Click:Connect(function()
			bugJumpEnabled = not bugJumpEnabled
			BtnBugJump.Text = "🚀 BUG JUMP: " .. (bugJumpEnabled and "ON" or "OFF")
			BtnBugJump.TextColor3 = bugJumpEnabled and C_GREEN or C_TEXT_DIM
		end)

		-- Bug Jump Info Label - Using theme colors
		local LblBugJumpInfo = Instance.new("TextLabel", CardBoost)
		LblBugJumpInfo.Text = "⚡ A/D+W = 1.5x"
		LblBugJumpInfo.Size = UDim2.new(0.45, 0, 0, 30)
		LblBugJumpInfo.Position = UDim2.new(0.52, 0, 0, 75)
		LblBugJumpInfo.BackgroundColor3 = C_SIDE
		LblBugJumpInfo.TextColor3 = C_YELLOW
		LblBugJumpInfo.Font = Enum.Font.GothamBlack
		LblBugJumpInfo.TextSize = 12
		Instance.new("UICorner", LblBugJumpInfo).CornerRadius = UDim.new(0, 6)

		RegisterTheme(LblBugJumpInfo, "BackgroundColor3", "Sidebar")

		-- Boost Power Slider Row (below the button)
		local SliderRow = Instance.new("Frame", CardBoost)
		SliderRow.Size = UDim2.new(0.94, 0, 0, 30)
		SliderRow.Position = UDim2.new(0.03, 0, 0, 110)
		SliderRow.BackgroundTransparency = 1

		-- Migrate old defaults to new ones
		if Config.QuickBoostPower == 10 or Config.QuickBoostPower == 12 then
			Config.QuickBoostPower = 3
		end
		if Config.BugJumpForward == 8 then
			Config.BugJumpForward = 1
		end

		-- Clamp existing config value to new max of 25 (Default: 3)
		Config.QuickBoostPower = math.clamp(Config.QuickBoostPower or 3, 0, 25)
		local LblBoostPower = Instance.new("TextLabel", SliderRow)
		LblBoostPower.Text = "BOOST POWER: " .. Config.QuickBoostPower
		LblBoostPower.Size = UDim2.new(0.35, 0, 0, 20)
		LblBoostPower.Position = UDim2.new(0, 0, 0.5, -10)
		LblBoostPower.BackgroundTransparency = 1
		LblBoostPower.TextColor3 = C_TEXT_DIM
		LblBoostPower.Font = Enum.Font.GothamBold
		LblBoostPower.TextSize = 10
		LblBoostPower.TextXAlignment = Enum.TextXAlignment.Left

		local SldBoostBg = Instance.new("TextButton", SliderRow)
		SldBoostBg.Text = ""
		SldBoostBg.Size = UDim2.new(0.6, 0, 0, 8)
		SldBoostBg.Position = UDim2.new(0.38, 0, 0.5, -4)
		SldBoostBg.BackgroundColor3 = C_SIDE
		SldBoostBg.AutoButtonColor = false
		Instance.new("UICorner", SldBoostBg).CornerRadius = UDim.new(0, 4)

		local SldBoostFill = Instance.new("Frame", SldBoostBg)
		SldBoostFill.Size = UDim2.new(Config.QuickBoostPower / 25, 0, 1, 0)
		SldBoostFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldBoostFill).CornerRadius = UDim.new(0, 4)

		-- Forward Momentum Slider
		local SliderRow2 = Instance.new("Frame", CardBoost)
		SliderRow2.Size = UDim2.new(0.94, 0, 0, 30)
		SliderRow2.Position = UDim2.new(0.03, 0, 0, 145)
		SliderRow2.BackgroundTransparency = 1

		Config.BugJumpForward = Config.BugJumpForward or 1
		local LblForward = Instance.new("TextLabel", SliderRow2)
		LblForward.Text = "FORWARD: " .. Config.BugJumpForward
		LblForward.Size = UDim2.new(0.35, 0, 0, 20)
		LblForward.Position = UDim2.new(0, 0, 0.5, -10)
		LblForward.BackgroundTransparency = 1
		LblForward.TextColor3 = C_TEXT_DIM
		LblForward.Font = Enum.Font.GothamBold
		LblForward.TextSize = 10
		LblForward.TextXAlignment = Enum.TextXAlignment.Left

		local SldFwdBg = Instance.new("TextButton", SliderRow2)
		SldFwdBg.Text = ""
		SldFwdBg.Size = UDim2.new(0.6, 0, 0, 8)
		SldFwdBg.Position = UDim2.new(0.38, 0, 0.5, -4)
		SldFwdBg.BackgroundColor3 = C_SIDE
		SldFwdBg.AutoButtonColor = false
		Instance.new("UICorner", SldFwdBg).CornerRadius = UDim.new(0, 4)

		local SldFwdFill = Instance.new("Frame", SldFwdBg)
		SldFwdFill.Size = UDim2.new(Config.BugJumpForward / 20, 0, 1, 0)
		SldFwdFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldFwdFill).CornerRadius = UDim.new(0, 4)

		local function UpdateBoostSlider(input)
			local rx = input.Position.X - SldBoostBg.AbsolutePosition.X
			local sc = math.clamp(rx / SldBoostBg.AbsoluteSize.X, 0, 1)
			Config.QuickBoostPower = math.floor(sc * 25) -- 0 to 25
			SldBoostFill.Size = UDim2.new(sc, 0, 1, 0)
			LblBoostPower.Text = "BOOST POWER: " .. Config.QuickBoostPower
		end

		local function UpdateForwardSlider(input)
			local rx = input.Position.X - SldFwdBg.AbsolutePosition.X
			local sc = math.clamp(rx / SldFwdBg.AbsoluteSize.X, 0, 1)
			Config.BugJumpForward = math.floor(sc * 20) -- 0 to 20
			SldFwdFill.Size = UDim2.new(sc, 0, 1, 0)
			LblForward.Text = "FORWARD: " .. Config.BugJumpForward
		end

		local draggingBoost = false
		local draggingFwd = false

		SldBoostBg.MouseButton1Down:Connect(function()
			draggingBoost = true
		end)
		SldFwdBg.MouseButton1Down:Connect(function()
			draggingFwd = true
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingBoost = false
				draggingFwd = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				if draggingBoost then
					UpdateBoostSlider(input)
				elseif draggingFwd then
					UpdateForwardSlider(input)
				end
			end
		end)

		-- Auto Rotate + Jump Toggle (Combined feature when Quick Boost is ON)
		local BtnAutoRotateJump = Instance.new("TextButton", CardBoost)
		BtnAutoRotateJump.Text = "🔄 AUTO SPIN+JUMP: ON"
		BtnAutoRotateJump.Size = UDim2.new(0.55, 0, 0, 30)
		BtnAutoRotateJump.Position = UDim2.new(0.03, 0, 0, 180)
		BtnAutoRotateJump.BackgroundColor3 = C_SIDE
		BtnAutoRotateJump.TextColor3 = C_YELLOW
		BtnAutoRotateJump.Font = Enum.Font.GothamBold
		BtnAutoRotateJump.TextSize = 11
		Instance.new("UICorner", BtnAutoRotateJump).CornerRadius = UDim.new(0, 6)
		local autoRotateJumpStroke = Instance.new("UIStroke", BtnAutoRotateJump)
		autoRotateJumpStroke.Color = C_YELLOW
		autoRotateJumpStroke.Transparency = 0.7

		RegisterTheme(BtnAutoRotateJump, "BackgroundColor3", "Side")

		-- Spin Degree Selector
		local SPIN_OPTIONS = {45, 90, 180, 360}
		local currentSpinIndex = 2 -- Default 90°
		local ROTATE_AMOUNT = SPIN_OPTIONS[currentSpinIndex]
		local SPIN_DURATION = 0.05 -- Default spin duration (smooth)
		_G.StarshipIsSpinning = false -- Global state for cross-module override

		local BtnSpinDegree = Instance.new("TextButton", CardBoost)
		BtnSpinDegree.Text = "🎯 " .. ROTATE_AMOUNT .. "°"
		BtnSpinDegree.Size = UDim2.new(0.35, 0, 0, 30)
		BtnSpinDegree.Position = UDim2.new(0.62, 0, 0, 180)
		BtnSpinDegree.BackgroundColor3 = C_SIDE
		BtnSpinDegree.TextColor3 = C_ACCENT
		BtnSpinDegree.Font = Enum.Font.GothamBlack
		BtnSpinDegree.TextSize = 12
		Instance.new("UICorner", BtnSpinDegree).CornerRadius = UDim.new(0, 6)
		local spinDegreeStroke = Instance.new("UIStroke", BtnSpinDegree)
		spinDegreeStroke.Color = C_ACCENT
		spinDegreeStroke.Transparency = 0.6

		RegisterTheme(BtnSpinDegree, "BackgroundColor3", "Side")
		RegisterTheme(BtnSpinDegree, "TextColor3", "Accent")
		RegisterTheme(spinDegreeStroke, "Color", "Accent")

		-- Cycle through spin degrees on click
		BtnSpinDegree.MouseButton1Click:Connect(function()
			currentSpinIndex = currentSpinIndex + 1
			if currentSpinIndex > #SPIN_OPTIONS then
				currentSpinIndex = 1
			end
			ROTATE_AMOUNT = SPIN_OPTIONS[currentSpinIndex]
			BtnSpinDegree.Text = "🎯 " .. ROTATE_AMOUNT .. "°"
			
			-- Flash effect
			local originalColor = BtnSpinDegree.TextColor3
			BtnSpinDegree.TextColor3 = C_GREEN
			task.delay(0.15, function()
				if BtnSpinDegree then
					BtnSpinDegree.TextColor3 = C_ACCENT
				end
			end)
		end)

		-- Spin Speed Slider Row
		local SliderRowSpin = Instance.new("Frame", CardBoost)
		SliderRowSpin.Size = UDim2.new(0.94, 0, 0, 25)
		SliderRowSpin.Position = UDim2.new(0.03, 0, 0, 215)
		SliderRowSpin.BackgroundTransparency = 1

		local LblSpinSpeed = Instance.new("TextLabel", SliderRowSpin)
		LblSpinSpeed.Text = "🌀 SPIN: " .. string.format("%.2fs", SPIN_DURATION)
		LblSpinSpeed.Size = UDim2.new(0.35, 0, 0, 20)
		LblSpinSpeed.Position = UDim2.new(0, 0, 0.5, -10)
		LblSpinSpeed.BackgroundTransparency = 1
		LblSpinSpeed.TextColor3 = C_TEXT_DIM
		LblSpinSpeed.Font = Enum.Font.GothamBold
		LblSpinSpeed.TextSize = 9
		LblSpinSpeed.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(LblSpinSpeed, "TextColor3", "TextDim")

		-- NEW: SL POWER OVERRIDE Toggle
		Config.SmartSLOverride = Config.SmartSLOverride or false
		local BtnSLOverride = Instance.new("TextButton", CardBoost)
		BtnSLOverride.Text = "🚀 SL POWER OVERRIDE: " .. (Config.SmartSLOverride and "ON" or "OFF")
		BtnSLOverride.Size = UDim2.new(0.94, 0, 0, 30)
		BtnSLOverride.Position = UDim2.new(0.03, 0, 0, 245)
		StyleBtn(BtnSLOverride, Config.SmartSLOverride and C_GREEN or C_RED)

		BtnSLOverride.MouseButton1Click:Connect(function()
			Config.SmartSLOverride = not Config.SmartSLOverride
			BtnSLOverride.Text = "🚀 SL POWER OVERRIDE: " .. (Config.SmartSLOverride and "ON" or "OFF")
			BtnSLOverride.TextColor3 = Config.SmartSLOverride and C_GREEN or C_RED
			BtnSLOverride.UIStroke.Color = Config.SmartSLOverride and C_GREEN or C_RED
			ShowFeatureToast("SL Override", Config.SmartSLOverride)
		end)

		local SldSpinBg = Instance.new("TextButton", SliderRowSpin)
		SldSpinBg.Text = ""
		SldSpinBg.Size = UDim2.new(0.6, 0, 0, 8)
		SldSpinBg.Position = UDim2.new(0.38, 0, 0.5, -4)
		SldSpinBg.BackgroundColor3 = C_SIDE
		SldSpinBg.AutoButtonColor = false
		Instance.new("UICorner", SldSpinBg).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldSpinBg, "BackgroundColor3", "Side")

		local SldSpinFill = Instance.new("Frame", SldSpinBg)
		SldSpinFill.Size = UDim2.new(SPIN_DURATION / 5.0, 0, 1, 0) -- 0.0s to 5.0s range
		SldSpinFill.BackgroundColor3 = C_ACCENT
		Instance.new("UICorner", SldSpinFill).CornerRadius = UDim.new(0, 4)
		RegisterTheme(SldSpinFill, "BackgroundColor3", "Accent")

		local draggingSpin = false

		local function UpdateSpinSlider(input)
			local rx = input.Position.X - SldSpinBg.AbsolutePosition.X
			local sc = math.clamp(rx / SldSpinBg.AbsoluteSize.X, 0, 1)
			SPIN_DURATION = sc * 5.0 -- Range 0.0s (instant) to 5.0s (slow)
			SldSpinFill.Size = UDim2.new(sc, 0, 1, 0)
			if SPIN_DURATION < 0.03 then
				LblSpinSpeed.Text = "🌀 SPIN: INSTANT"
			else
				LblSpinSpeed.Text = "🌀 SPIN: " .. string.format("%.2fs", SPIN_DURATION)
			end
		end

		SldSpinBg.MouseButton1Down:Connect(function()
			draggingSpin = true
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingSpin = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				if draggingSpin then
					UpdateSpinSlider(input)
				end
			end
		end)

		-- Smooth Spin Function (PHASE 8: MOTOR6D VISUAL SPIN)
		-- Smooth Spin Function (PHASE 17: ADAPTIVE DURATION)
		-- Automatically adds 0.3s extra duration if Shiftlock is ON for a more 'legit' feel
		local function SmoothSpin(rootPart, degrees, duration, onComplete)
			if _G.StarshipIsSpinning then return end
			local character = rootPart.Parent
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local camera = workspace.CurrentCamera
			if not humanoid or not rootPart or not camera then return end
			
			-- Adaptive Logic: Add +0.03s if Shiftlock is active
			local isShiftLock = (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)
			
			-- NEW: Force Revert Logic
			local wasOriginallySL = false
			if Config.SmartSLOverride and isShiftLock and UIHandlers.ToggleShiftLock then
				wasOriginallySL = true
				UIHandlers.ToggleShiftLock(false, true) -- Turn OFF Shift-Lock (Muted notification)
				isShiftLock = false -- Force Normal Duration
			end

			local actualDuration = isShiftLock and (duration + 0.03) or duration
			
			_G.StarshipIsSpinning = true
			
			-- Preparation
			local oldAutoRotate = humanoid.AutoRotate
			humanoid.AutoRotate = false
			
			local startTime = tick()
			local targetRotation = math.rad(degrees)
			
			-- Capture starting orientation but isolate it from position (Liquid Smooth Phase 9)
			local _, startY, _ = rootPart.CFrame:ToEulerAnglesYXZ()
			
			-- Sound FX (Updated to a stable ID)
			local s = Instance.new("Sound", rootPart)
			s.SoundId = "rbxassetid://77878671889615"
			s.Volume = 0.1
			s:Play()
			task.delay(1, function() s:Destroy() end)

			local spinBindName = "StarshipAdaptiveSpin_" .. tostring(math.random(1000, 9999))
			
			local function UpdateSpin()
				local now = tick()
				local elapsed = now - startTime
				local progress = math.min(elapsed / actualDuration, 1)
				
				if not rootPart.Parent or progress >= 1 then
					RunService:UnbindFromRenderStep(spinBindName)
					
					-- Final Snap with Current Position
					rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, startY + targetRotation, 0)
					
					-- Restore AutoRotate
					if humanoid.Parent then humanoid.AutoRotate = oldAutoRotate end
					
					-- Execute jump/boost callback FIRST
					if onComplete then onComplete() end
					
					-- Restore Shift-Lock with a tiny delay so it doesn't "snap" the jump
					if wasOriginallySL and UIHandlers.ToggleShiftLock then
						task.delay(0.1, function()
							UIHandlers.ToggleShiftLock(true, true) -- Turn ON Shift-Lock (Muted notification)
						end)
					end
					
					-- Final small delay before allowing another spin
					task.delay(0.05, function() _G.StarshipIsSpinning = false end)
					return
				end
				
				-- Ensure AutoRotate stays off
				humanoid.AutoRotate = false
				
				-- CLASSIC EASING: Ease Out Quad (Snappy & Smooth)
				local easedProgress = 1 - (1 - progress) * (1 - progress)
				local currentRot = targetRotation * easedProgress
				
				-- LIQUID MOTION: Only override Rotation, leave Position to the physics engine
				-- This prevents the "stuck/laggy" feeling
				rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, startY + currentRot, 0)
			end
			
			RunService:BindToRenderStep(spinBindName, 200000, UpdateSpin)
		end

		-- Auto Rotate + Jump State (activated on R2/L2 or A/D press like Quick Boost)
		local isAutoRotateJump = true

		local function ToggleAutoRotateJump()
			isAutoRotateJump = not isAutoRotateJump
			BtnAutoRotateJump.Text = "🔄 AUTO SPIN+JUMP: " .. (isAutoRotateJump and "ON" or "OFF")
			BtnAutoRotateJump.TextColor3 = isAutoRotateJump and C_YELLOW or C_TEXT_DIM
			autoRotateJumpStroke.Color = isAutoRotateJump and C_YELLOW or C_TEXT_DIM
			ShowFeatureToast("Auto Spin+Jump", isAutoRotateJump)
		end

		BtnAutoRotateJump.MouseButton1Click:Connect(function()
			ToggleAutoRotateJump()
		end)
		UIHandlers.ToggleAutoRotateJump = ToggleAutoRotateJump

		-- Quick Boost State - L2/R2 or A/D control + Bug Jump
		local isQuickBoost, quickBoostLoop = false, nil
		local hasBoostedThisJump = false -- Track if already boosted this jump
		local boostCount = 0 -- Track boost count for multi-boost
		local MAX_BOOSTS_PER_JUMP = 2 -- Allow 2 boosts per jump (normal + bug jump style)
		local lastBoostTime = 0
		local BOOST_COOLDOWN = 0.15 -- Cooldown between boosts

		local wasOnGround = true
		local lastAPressed = false
		local lastDPressed = false
		local lastWPressed = false
		local lastSPressed = false

		-- Gamepad Button State
		local lastLTPressed = false
		local lastRTPressed = false
		local lastLSUp = false -- Left stick up

		local function ToggleQuickBoost(forceEnable)
			if forceEnable ~= nil then
				if forceEnable == isQuickBoost then
					return
				end
			end

			isQuickBoost = not isQuickBoost
			BtnQuickBoost.Text = L("quick_boost") .. ": " .. (isQuickBoost and L("on") or L("off"))
			BtnQuickBoost.TextColor3 = isQuickBoost and C_GREEN or C_TEXT_DIM
			BtnQuickBoost.UIStroke.Color = isQuickBoost and C_GREEN or C_TEXT_DIM
			ShowFeatureToast("Quick Boost", isQuickBoost)

			if isQuickBoost then
				quickBoostLoop = RunService.Heartbeat:Connect(function(dt)
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChild("Humanoid")
					local r = c and c:FindFirstChild("HumanoidRootPart")

					if h and r then
						local state = h:GetState()
						local isOnGround = (
							state == Enum.HumanoidStateType.Running
							or state == Enum.HumanoidStateType.Landed
							or h.FloorMaterial ~= Enum.Material.Air
						)
						local isInAir = (
							state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
						)

						-- Reset when landing
						if isOnGround then
							hasBoostedThisJump = false
							boostCount = 0
						end

						-- Check keyboard keys
						local aPressed = UserInputService:IsKeyDown(Enum.KeyCode.A)
						local dPressed = UserInputService:IsKeyDown(Enum.KeyCode.D)
						local wPressed = UserInputService:IsKeyDown(Enum.KeyCode.W)
						local sPressed = UserInputService:IsKeyDown(Enum.KeyCode.S)

						-- Detect key press transitions
						local aJustPressed = aPressed and not lastAPressed
						local dJustPressed = dPressed and not lastDPressed
						local wJustPressed = wPressed and not lastWPressed

						lastAPressed = aPressed
						lastDPressed = dPressed
						lastWPressed = wPressed
						lastSPressed = sPressed

						-- Gamepad Trigger & Bumper Detection (All Gamepads)
						local ltPressed = false
						local rtPressed = false
						local l1Pressed = false
						local r1Pressed = false
						
						-- Check all possible gamepads
						for g = 1, 8 do
							local gType = Enum.UserInputType["Gamepad" .. g]
							if UserInputService:GetGamepadState(gType) then
								local gState = UserInputService:GetGamepadState(gType)
								for _, input in ipairs(gState) do
									if input.KeyCode == Enum.KeyCode.ButtonL2 then
										ltPressed = ltPressed or input.Position.Z > 0.1
									elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
										rtPressed = rtPressed or input.Position.Z > 0.1
									elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
										l1Pressed = l1Pressed or input.UserInputState == Enum.UserInputState.Begin or input.UserInputState == Enum.UserInputState.Change
									elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
										r1Pressed = r1Pressed or input.UserInputState == Enum.UserInputState.Begin or input.UserInputState == Enum.UserInputState.Change
									end
								end
							end
						end
						
						local lsForward = false
						local lsBackward = false
						local lsLeft = false
						local lsRight = false
						
						for g = 1, 8 do
							local gType = Enum.UserInputType["Gamepad" .. g]
							local success, gState = pcall(function() return UserInputService:GetGamepadState(gType) end)
							if success and gState then
								for _, input in ipairs(gState) do
									if input.KeyCode == Enum.KeyCode.Thumbstick1 then
										lsForward = lsForward or input.Position.Y > 0.3
										lsBackward = lsBackward or input.Position.Y < -0.3
										lsLeft = lsLeft or input.Position.X < -0.3
										lsRight = lsRight or input.Position.X > 0.3
										break
									end
								end
							end
						end

						-- Detect button press transitions (Triggers or Bumpers)
						local ltJustPressed = (ltPressed and not lastLTPressed) or (l1Pressed and not lastL1Pressed)
						local rtJustPressed = (rtPressed and not lastRTPressed) or (r1Pressed and not lastR1Pressed)
						local lsUpJustPressed = lsForward and not lastLSUp

						lastLTPressed = ltPressed
						lastRTPressed = rtPressed
						lastL1Pressed = l1Pressed
						lastR1Pressed = r1Pressed
						lastLSUp = lsForward

						-- Combine keyboard and gamepad triggers
						local justMovedLeft = aJustPressed or ltJustPressed
						local justMovedRight = dJustPressed or rtJustPressed
						local justMovedForward = wJustPressed or lsUpJustPressed

						-- Current time for cooldown check
						local currentTime = tick()

						-- AUTO SPIN+JUMP: Technique S + A/D + W = Spin + Jump (HOLD TO REPEAT)
						-- Keyboard: S-A+W = Spin left, S-D+W = Spin right
						-- Gamepad Option 1: L2 = Spin left + jump, R2 = Spin right + jump
						-- Gamepad Option 2: Analog down+left+up or down+right+up
						-- HOLD the button to keep spin+jumping!
						if isAutoRotateJump and isOnGround and not _G.StarshipIsSpinning then
							-- KEYBOARD: Detect spin combo S + (A or D) + W HELD together
							local spinComboLeftKB = sPressed and aPressed and wPressed  -- S+A+W = spin left
							local spinComboRightKB = sPressed and dPressed and wPressed -- S+D+W = spin right
							
							-- GAMEPAD Option 1: L2/R2 HELD (simpler)
							local spinComboLeftGP = ltPressed  -- L2 = spin left
							local spinComboRightGP = rtPressed -- R2 = spin right
							
							-- GAMEPAD Option 2: Analog stick combo HELD (like keyboard)
							local spinComboLeftAnalog = lsBackward and lsLeft and lsForward   -- Down+Left+Up
							local spinComboRightAnalog = lsBackward and lsRight and lsForward -- Down+Right+Up
							
							-- Combine all methods (HOLD detection, not just press)
							local spinLeft = spinComboLeftKB or spinComboLeftGP or spinComboLeftAnalog
							local spinRight = spinComboRightKB or spinComboRightGP or spinComboRightAnalog
							
							-- Spin+Jump cooldown (separate from quick boost, longer for comfortable repeat)
							local SPIN_JUMP_COOLDOWN = 0.1 -- Can repeat every 0.1s when held
							
							if (spinLeft or spinRight) and (currentTime - lastBoostTime) > SPIN_JUMP_COOLDOWN then
								-- Determine spin direction
								-- Left = negative rotation (counter-clockwise)
								-- Right = positive rotation (clockwise)
								local spinDirection = 1
								if spinLeft then
									spinDirection = -1 -- Spin to left (counter-clockwise)
								else
									spinDirection = 1  -- Spin to right (clockwise)
								end
								
								-- Spin first on ground, then jump in callback
								SmoothSpin(r, ROTATE_AMOUNT * spinDirection, SPIN_DURATION, function()
									if h and h.Parent and r and r.Parent then
										-- 1. JUMP
										h:ChangeState(Enum.HumanoidStateType.Jumping)
										
										-- 2. BOOST AFTER MICRO DELAY
										task.delay(0.05, function()
											if r and r.Parent then
												local currentVel = r.AssemblyLinearVelocity
												local baseBoost = Config.QuickBoostPower or 12
												local forwardBoost = Config.BugJumpForward or 8
												
												local boostedYVel = math.min(currentVel.Y + baseBoost, 55 + baseBoost)
												
												local camera = workspace.CurrentCamera
												local camLook = camera and camera.CFrame.LookVector or r.CFrame.LookVector
												local horizontalLook = Vector3.new(camLook.X, 0, camLook.Z)
												if horizontalLook.Magnitude > 0.1 then
													horizontalLook = horizontalLook.Unit
												else
													horizontalLook = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z).Unit
												end
												
												r.AssemblyLinearVelocity = Vector3.new(
													currentVel.X + horizontalLook.X * forwardBoost,
													boostedYVel,
													currentVel.Z + horizontalLook.Z * forwardBoost
												)
											end
										end)
									end
								end)
								
								lastBoostTime = currentTime
							end
						end

						-- Apply boost when in air (Quick Boost only, no spin here)
						if
							isInAir
							and boostCount < MAX_BOOSTS_PER_JUMP
							and (currentTime - lastBoostTime) > BOOST_COOLDOWN
						then
							local shouldBoost = justMovedLeft or justMovedRight

							if shouldBoost then
								local currentVel = r.AssemblyLinearVelocity
								local baseBoost = Config.QuickBoostPower or 12
								local forwardBoost = Config.BugJumpForward or 8

								-- BUG JUMP DETECTION: A/D + W pressed together
								local isBugJump = bugJumpEnabled and (aPressed or dPressed) and wPressed

								-- Calculate boost multiplier
								local boostMultiplier = 1.0
								if isBugJump then
									boostMultiplier = 1.5 -- 50% more boost for Bug Jump
								end

								local finalBoost = baseBoost * boostMultiplier
								local maxYVel = 55 + finalBoost

								-- Calculate new Y velocity
								local newYVel = currentVel.Y + finalBoost

								-- Cap velocity
								if newYVel > maxYVel then
									newYVel = maxYVel
								end

								-- Only boost if not already going up too fast
								if currentVel.Y < maxYVel then
									-- Get movement direction for forward momentum
									local moveDir = h.MoveDirection
									local lookDir = r.CFrame.LookVector

									-- For Bug Jump, also add forward momentum
									local forwardVelX = currentVel.X
									local forwardVelZ = currentVel.Z

									if isBugJump and forwardBoost > 0 then
										-- Use camera direction for Shift Lock compatibility
										local camera = workspace.CurrentCamera
										local camLook = camera and camera.CFrame.LookVector or lookDir
										local horizontalLook = Vector3.new(camLook.X, 0, camLook.Z)
										if horizontalLook.Magnitude > 0.1 then
											horizontalLook = horizontalLook.Unit
										else
											horizontalLook = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
										end

										-- Add forward momentum
										forwardVelX = currentVel.X + horizontalLook.X * forwardBoost
										forwardVelZ = currentVel.Z + horizontalLook.Z * forwardBoost
									end

									r.AssemblyLinearVelocity = Vector3.new(forwardVelX, newYVel, forwardVelZ)

									-- SHIFTLOCK SPIN INTEGRATION: Apply spin in air if enabled
									if isAutoRotateJump then
										local spinDir = 0
										
										-- Detect standard Shiftlocked inputs or Controller
										local isShiftLocking = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)

										-- Prioritize triggers L2/R2 and bumpers L1/R1
										if ltPressed or l1Pressed then 
											spinDir = -1
										elseif rtPressed or r1Pressed then 
											spinDir = 1 
										elseif aJustPressed then
											spinDir = -1
										elseif dJustPressed then
											spinDir = 1
										end
										
										if spinDir ~= 0 then
											-- Use the duration from the UI slider
											SmoothSpin(r, ROTATE_AMOUNT * spinDir, SPIN_DURATION)
										end
									end

									boostCount = boostCount + 1
									lastBoostTime = currentTime

									-- Mark as boosted if we've used all boosts
									if boostCount >= MAX_BOOSTS_PER_JUMP then
										hasBoostedThisJump = true
									end
								end
							end
						end

						wasOnGround = isOnGround
					end
				end)
				table.insert(Connections, quickBoostLoop)
			else
				if quickBoostLoop then
					quickBoostLoop:Disconnect()
					quickBoostLoop = nil
				end
				hasBoostedThisJump = false
				boostCount = 0
				lastLTPressed = false
				lastRTPressed = false
			end
		end

		BtnQuickBoost.MouseButton1Click:Connect(function()
			ToggleQuickBoost()
		end)
		UIHandlers.ToggleQuickBoost = ToggleQuickBoost
	end

	-- 1. ALWAYS MOMENTUM
	local CardMomentum = CreateCard(L("always_momentum"), 100, 1)

	local BtnMomentum, MomentumContainer = CreateFeatureButton(
		CardMomentum,
		L("always_momentum") .. ": " .. L("off"),
		L("always_momentum_desc"),
		UDim2.new(0.94, 0, 0, 55),
		UDim2.new(0.03, 0, 0, 35),
		C_TEXT_DIM
	)

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
		BtnMomentum.Text = L("always_momentum") .. ": " .. (isMomentum and L("on") or L("off"))
		BtnMomentum.TextColor3 = isMomentum and C_GREEN or C_TEXT_DIM
		BtnMomentum.UIStroke.Color = isMomentum and C_GREEN or C_TEXT_DIM
		ShowFeatureToast("Always Momentum", isMomentum)

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
	local CardSlip = CreateCard(L("anti_slip"), 155, 2)

	local BtnSlip, SlipContainer = CreateFeatureButton(
		CardSlip,
		L("anti_slip") .. ": " .. L("off"),
		L("anti_slip_desc"),
		UDim2.new(0.94, 0, 0, 55),
		UDim2.new(0.03, 0, 0, 35),
		C_RED
	)

	-- Size Slider
	local LblSize = Instance.new("TextLabel", CardSlip)
	LblSize.Text = L("size") .. ": 0.5"
	LblSize.Size = UDim2.new(1, -20, 0, 20)
	LblSize.Position = UDim2.new(0, 15, 0, 95)
	LblSize.BackgroundTransparency = 1
	LblSize.TextColor3 = C_TEXT_DIM
	LblSize.Font = Enum.Font.GothamBold
	LblSize.TextSize = 10
	LblSize.TextXAlignment = Enum.TextXAlignment.Left

	local SldBg = Instance.new("TextButton", CardSlip)
	SldBg.Text = ""
	SldBg.Size = UDim2.new(0.9, 0, 0, 6)
	SldBg.Position = UDim2.new(0.05, 0, 0, 115)
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

	LblSize.Text = L("size") .. ": 3.0" -- Update default label

	local function UpdateSlider(input)
		local rx = input.Position.X - SldBg.AbsolutePosition.X
		local sc = math.clamp(rx / SldBg.AbsoluteSize.X, 0, 1)
		targetSize = 1 + (sc * 9) -- Range 1-10 studs
		SldFill.Size = UDim2.new(sc, 0, 1, 0)
		LblSize.Text = L("size") .. ": " .. string.format("%.1f", targetSize)
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
		BtnSlip.Text = L("anti_slip") .. ": " .. (isSlipOn and L("on") or L("off"))
		BtnSlip.TextColor3 = isSlipOn and C_GREEN or C_RED
		BtnSlip.UIStroke.Color = isSlipOn and C_GREEN or C_RED
		ShowFeatureToast("Anti-Slip", isSlipOn)

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
	local CardRagdoll = CreateCard(L("anti_ragdoll"), 140, 3)

	local BtnRagdoll, RagdollContainer = CreateFeatureButton(
		CardRagdoll,
		L("anti_ragdoll") .. ": " .. L("off"),
		L("anti_ragdoll_desc"),
		UDim2.new(0.94, 0, 0, 55),
		UDim2.new(0.03, 0, 0, 35),
		C_RED
	)

	-- Max Velocity Slider
	local LblMaxVel = Instance.new("TextLabel", CardRagdoll)
	LblMaxVel.Text = L("max_velocity") .. ": 50"
	LblMaxVel.Size = UDim2.new(1, -20, 0, 20)
	LblMaxVel.Position = UDim2.new(0, 15, 0, 95)
	LblMaxVel.BackgroundTransparency = 1
	LblMaxVel.TextColor3 = C_TEXT_DIM
	LblMaxVel.Font = Enum.Font.GothamBold
	LblMaxVel.TextSize = 10
	LblMaxVel.TextXAlignment = Enum.TextXAlignment.Left

	local SldVelBg = Instance.new("TextButton", CardRagdoll)
	SldVelBg.Text = ""
	SldVelBg.Size = UDim2.new(0.9, 0, 0, 6)
	SldVelBg.Position = UDim2.new(0.05, 0, 0, 115)
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
		LblMaxVel.Text = L("max_velocity") .. ": " .. maxVelocity
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
		ShowFeatureToast("Anti-Ragdoll", isRagdollOn)

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
	local CardESP = CreateCard(L("real_path_esp"), 175, 5)

	local BtnRealESP, RealESPContainer = CreateFeatureButton(
		CardESP,
		L("real_path_esp") .. ": " .. L("off"),
		L("real_path_esp_desc"),
		UDim2.new(0.94, 0, 0, 55),
		UDim2.new(0.03, 0, 0, 35),
		C_RED
	)

	-- Color Legend
	local LblColorInfo = Instance.new("TextLabel", CardESP)
	LblColorInfo.Text = L("color_info")
	LblColorInfo.Size = UDim2.new(0.94, 0, 0, 18)
	LblColorInfo.Position = UDim2.new(0.03, 0, 0, 95)
	LblColorInfo.BackgroundTransparency = 1
	LblColorInfo.TextColor3 = C_TEXT_DIM
	LblColorInfo.TextSize = 12
	LblColorInfo.Font = Enum.Font.GothamBold
	LblColorInfo.TextXAlignment = Enum.TextXAlignment.Left

	local LblGreen = Instance.new("TextLabel", CardESP)
	LblGreen.Text = L("green_safe")
	LblGreen.Size = UDim2.new(0.94, 0, 0, 14)
	LblGreen.Position = UDim2.new(0.03, 0, 0, 111)
	LblGreen.BackgroundTransparency = 1
	LblGreen.TextColor3 = Color3.new(0, 1, 0)
	LblGreen.TextSize = 10
	LblGreen.Font = Enum.Font.Gotham
	LblGreen.TextXAlignment = Enum.TextXAlignment.Left

	local LblCyan = Instance.new("TextLabel", CardESP)
	LblCyan.Text = L("cyan_ladder")
	LblCyan.Size = UDim2.new(0.94, 0, 0, 14)
	LblCyan.Position = UDim2.new(0.03, 0, 0, 125)
	LblCyan.BackgroundTransparency = 1
	LblCyan.TextColor3 = Color3.fromRGB(0, 255, 255)
	LblCyan.TextSize = 10
	LblCyan.Font = Enum.Font.Gotham
	LblCyan.TextXAlignment = Enum.TextXAlignment.Left

	local LblOrange = Instance.new("TextLabel", CardESP)
	LblOrange.Text = L("orange_ladder")
	LblOrange.Size = UDim2.new(0.94, 0, 0, 14)
	LblOrange.Position = UDim2.new(0.03, 0, 0, 139)
	LblOrange.BackgroundTransparency = 1
	LblOrange.TextColor3 = Color3.fromRGB(255, 165, 0)
	LblOrange.TextSize = 10
	LblOrange.Font = Enum.Font.Gotham
	LblOrange.TextXAlignment = Enum.TextXAlignment.Left

	local LblRed = Instance.new("TextLabel", CardESP)
	LblRed.Text = L("red_fake")
	LblRed.Size = UDim2.new(0.94, 0, 0, 14)
	LblRed.Position = UDim2.new(0.03, 0, 0, 153)
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
		BtnRealESP.Text = L("real_path_esp") .. ": " .. (isRealESP and L("on") or L("off"))
		BtnRealESP.TextColor3 = isRealESP and C_GREEN or C_RED
		BtnRealESP.UIStroke.Color = isRealESP and C_GREEN or C_RED
		ShowFeatureToast("Real Path ESP", isRealESP)

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

	-- Keybind Handler for Helper Features
	local helperKeybindConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if not input.KeyCode then
			return
		end

		-- Skip if currently binding a keybind in ConfigTab (check global state)
		if _G.StarshipIsBindingKeybind then
			return
		end

		-- ToggleAutoJump
		if Config.Keybinds and Config.Keybinds.ToggleAutoJump and input.KeyCode == Config.Keybinds.ToggleAutoJump then
			if UIHandlers.ToggleAutoJump then
				UIHandlers.ToggleAutoJump()
			end
		end

		-- ToggleHighJump
		if Config.Keybinds and Config.Keybinds.ToggleHighJump and input.KeyCode == Config.Keybinds.ToggleHighJump then
			if UIHandlers.ToggleHighJump then
				UIHandlers.ToggleHighJump()
			end
		end

		-- ToggleQuickBoost
		if
			Config.Keybinds
			and Config.Keybinds.ToggleQuickBoost
			and input.KeyCode == Config.Keybinds.ToggleQuickBoost
		then
			if UIHandlers.ToggleQuickBoost then
				UIHandlers.ToggleQuickBoost()
			end
		end

		-- ToggleAntiSlip
		if Config.Keybinds and Config.Keybinds.ToggleAntiSlip and input.KeyCode == Config.Keybinds.ToggleAntiSlip then
			if UIHandlers.ToggleAntiSlip then
				UIHandlers.ToggleAntiSlip()
			end
		end

		-- ToggleRealESP
		if Config.Keybinds and Config.Keybinds.ToggleRealESP and input.KeyCode == Config.Keybinds.ToggleRealESP then
			if UIHandlers.ToggleRealESP then
				UIHandlers.ToggleRealESP()
			end
		end

		-- ToggleAntiDelay
		if Config.Keybinds and Config.Keybinds.ToggleAntiDelay and input.KeyCode == Config.Keybinds.ToggleAntiDelay then
			if UIHandlers.ToggleAntiDelay then
				UIHandlers.ToggleAntiDelay()
			end
		end

		-- ToggleHabeg
		if Config.Keybinds and Config.Keybinds.ToggleHabeg and input.KeyCode == Config.Keybinds.ToggleHabeg then
			if UIHandlers.ToggleHabeg then
				UIHandlers.ToggleHabeg()
			end
		end
	end)
	table.insert(Connections, helperKeybindConnection)
end

return SetupHelperUI
