local function SetupFunUI(PageFun, UI, Connections, Config, LocalPlayer, UIHandlers, RegisterTheme)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")

	-- Helper function to get localized text
	local function L(key, ...)
		if _G.StarshipLocale and _G.StarshipLocale.Get then
			return _G.StarshipLocale.Get(key, ...)
		end
		return key
	end

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

	for _, c in pairs(PageFun:GetChildren()) do
		c:Destroy()
	end
	local FunScroll = Instance.new("ScrollingFrame", PageFun)
	FunScroll.Size = UDim2.new(1, 0, 1, 0)
	FunScroll.BackgroundTransparency = 1
	FunScroll.BorderSizePixel = 0
	FunScroll.ScrollBarThickness = 4
	FunScroll.ScrollBarImageColor3 = C_ACCENT
	FunScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	FunScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

	-- Ensure RegisterTheme exists
	if not RegisterTheme then
		RegisterTheme = function() end
	end
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
		end
	end

	local function CreateWindow(title, height)
		local Main = PageFun.Parent.Parent -- Find Main from PageFun
		local wName = "Window_" .. title:gsub(" ", "")
		if Main:FindFirstChild(wName) then
			Main[wName]:Destroy()
		end

		local w = Instance.new("Frame", Main) -- Parent to Main for overlay
		w.Name = wName
		w.Size = UDim2.new(0, 320, 0, height)
		w.Position = UDim2.new(0.5, -160, 0.5, -height / 2)
		w.BackgroundColor3 = C_SIDE
		w.BackgroundTransparency = 0
		w.BorderSizePixel = 0
		w.Visible = false
		w.ZIndex = 200
		Instance.new("UICorner", w).CornerRadius = UDim.new(0, 12)

		local s = Instance.new("UIStroke", w)
		s.Color = C_ACCENT
		s.Thickness = 1
		s.Transparency = 0
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
		close.MouseButton1Click:Connect(function()
			w.Visible = false
		end)

		-- Dragging
		local dragging, dragInput, dragStart, startPos
		h.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				dragStart = input.Position
				startPos = w.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		h.InputChanged:Connect(function(input)
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
				w.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
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
		fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
		fill.BackgroundColor3 = C_ACCENT
		fill.ZIndex = 207
		Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

		local dragging = false
		s.MouseButton1Down:Connect(function()
			dragging = true
		end)
		UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)
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

	-- 1. TOUCH FLING
	local CardFling = CreateCard(L("touch_fling"), 130, 1)

	local BtnFling = Instance.new("TextButton", CardFling)
	BtnFling.Text = L("fling") .. ": " .. L("off")
	BtnFling.Size = UDim2.new(0.94, 0, 0, 35)
	BtnFling.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnFling, C_RED)

	local BtnExpandHitbox = Instance.new("TextButton", CardFling)
	BtnExpandHitbox.Text = L("expand_hitbox") .. ": " .. L("off")
	BtnExpandHitbox.Size = UDim2.new(0.94, 0, 0, 35)
	BtnExpandHitbox.Position = UDim2.new(0.03, 0, 0, 75)
	StyleBtn(BtnExpandHitbox, C_RED)

	local FlingInfo = Instance.new("TextLabel", CardFling)
	FlingInfo.Text = L("bigger_hitbox")
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
		BtnExpandHitbox.Text = L("expand_hitbox") .. ": " .. (isHitboxExpanded and L("on") or L("off"))
		BtnExpandHitbox.TextColor3 = isHitboxExpanded and C_GREEN or C_RED

		local c = LocalPlayer.Character
		if not c then
			return
		end
		local hrp = c:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end

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
			if hitboxParts[1] then
				hitboxParts[1].CFrame = hrp.CFrame * CFrame.new(0, 0, -3)
			end
			if hitboxParts[2] then
				hitboxParts[2].CFrame = hrp.CFrame * CFrame.new(0, 0, 3)
			end
			if hitboxParts[3] then
				hitboxParts[3].CFrame = hrp.CFrame * CFrame.new(-3, 0, 0)
			end
			if hitboxParts[4] then
				hitboxParts[4].CFrame = hrp.CFrame * CFrame.new(3, 0, 0)
			end
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
		BtnFling.Text = L("fling") .. ": " .. (isFling and L("on") or L("off"))
		BtnFling.TextColor3 = isFling and C_GREEN or C_RED

		if isFling then
			flingLoop = RunService.Heartbeat:Connect(function()
				local c = LocalPlayer.Character
				if not c then
					return
				end

				local hrp = c:FindFirstChild("HumanoidRootPart")
				if not hrp then
					return
				end

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

	-- ══════════════════════════════════════════════════════════════════
	-- 🧪 R2 CDN SYNC TEST - Remove after confirming auto-sync works!
	-- ══════════════════════════════════════════════════════════════════
	local CardTest = CreateCard("🧪 R2 CDN SYNC TEST", 70, 2)
	
	local BtnTest = Instance.new("TextButton", CardTest)
	BtnTest.Text = "TEST: OFF"
	BtnTest.Size = UDim2.new(0.94, 0, 0, 35)
	BtnTest.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnTest, C_RED)
	
	local isTestOn = false
	BtnTest.MouseButton1Click:Connect(function()
		isTestOn = not isTestOn
		BtnTest.Text = "TEST: " .. (isTestOn and "ON ✅" or "OFF")
		BtnTest.TextColor3 = isTestOn and C_GREEN or C_RED
		BtnTest.UIStroke.Color = isTestOn and C_GREEN or C_RED
		
		if isTestOn then
			-- Show notification
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "R2 CDN Sync Works!",
				Text = "File ini berhasil di-sync dari GitHub ke R2! 🎉",
				Duration = 5
			})
		end
	end)
	-- ══════════════════════════════════════════════════════════════════

	-- 3. INVISIBLE (Seat Weld Method)
	local CardInvis = CreateCard(L("invisible"), 85, 3)

	local BtnInvis = Instance.new("TextButton", CardInvis)
	BtnInvis.Text = "INVISIBLE: OFF"
	BtnInvis.Size = UDim2.new(0.94, 0, 0, 35)
	BtnInvis.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnInvis, C_RED)

	local InvisInfo = Instance.new("TextLabel", CardInvis)
	InvisInfo.Text = "Makes you invisible to others"
	InvisInfo.Size = UDim2.new(1, 0, 0, 15)
	InvisInfo.Position = UDim2.new(0, 0, 0, 70)
	InvisInfo.BackgroundTransparency = 1
	InvisInfo.TextColor3 = C_TEXT_DIM
	InvisInfo.Font = Enum.Font.Code
	InvisInfo.TextSize = 8

	local isInvis = false
	local INVIS_POSITION = Vector3.new(9999, 9999, 9999)

	local function setCharacterTransparency(char, alpha)
		for _, part in pairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.LocalTransparencyModifier = alpha
			elseif part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = alpha
			end
		end
	end

	UIHandlers.ToggleRealInvisible = function()
		local character = LocalPlayer.Character
		if not character then return end

		local humanoid = character:FindFirstChild("Humanoid")
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not hrp then return end

		isInvis = not isInvis
		BtnInvis.Text = "INVISIBLE: " .. (isInvis and "ON" or "OFF")
		BtnInvis.TextColor3 = isInvis and C_GREEN or C_RED
		BtnInvis.UIStroke.Color = isInvis and C_GREEN or C_RED

		if isInvis then
			-- Save current position
			local savedPosition = hrp.CFrame

			-- Move to invisible position using MoveTo (replicates to server)
			character:MoveTo(INVIS_POSITION)
			task.wait(0.15)

			-- Create seat at current character position (which is now at INVIS_POSITION)
			local seat = Instance.new("Seat")
			seat.Name = "invischair"
			seat.Anchored = false
			seat.CanCollide = false
			seat.Transparency = 1
			seat.Position = INVIS_POSITION
			seat.Parent = workspace

			-- Weld to torso
			local weld = Instance.new("Weld")
			weld.Part0 = seat
			weld.Part1 = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
			weld.Parent = seat

			task.wait()

			-- Move seat (and welded character) back to saved position
			seat.CFrame = savedPosition

			-- Visual feedback - make semi-transparent
			setCharacterTransparency(character, 0.5)

			InvisInfo.Text = "You are invisible to others!"
			InvisInfo.TextColor3 = C_GREEN
		else
			-- Destroy the invisible chair
			local invisChair = workspace:FindFirstChild("invischair")
			if invisChair then
				invisChair:Destroy()
			end

			-- Restore transparency
			if LocalPlayer.Character then
				setCharacterTransparency(LocalPlayer.Character, 0)
			end

			InvisInfo.Text = "Makes you invisible to others"
			InvisInfo.TextColor3 = C_TEXT_DIM
		end
	end

	BtnInvis.MouseButton1Click:Connect(UIHandlers.ToggleRealInvisible)

	-- 4. TELEPORT TO PLAYER - Window Based
	local CardTeleport = CreateCard(L("teleport_to_player"), 70, 4)

	local BtnOpenTeleport = Instance.new("TextButton", CardTeleport)
	BtnOpenTeleport.Text = "📍 OPEN TELEPORT"
	BtnOpenTeleport.Size = UDim2.new(0.94, 0, 0, 35)
	BtnOpenTeleport.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnOpenTeleport, C_ACCENT)

	-- Create Teleport Window
	local TeleportWindow, TeleportContent = CreateWindow("TELEPORT TO PLAYER", 290)
	TeleportContent.ScrollBarThickness = 0
	TeleportContent.ScrollingEnabled = false

	local selectedPlayer2 = nil

	-- Target Selection Label
	local TpTargetLabel = Instance.new("TextLabel", TeleportContent)
	TpTargetLabel.Text = "SELECT TARGET"
	TpTargetLabel.Size = UDim2.new(0.94, 0, 0, 20)
	TpTargetLabel.BackgroundTransparency = 1
	TpTargetLabel.TextColor3 = C_TEXT
	TpTargetLabel.Font = Enum.Font.GothamBold
	TpTargetLabel.TextSize = 11
	TpTargetLabel.ZIndex = 205

	-- Player List Frame
	local TpPlayerListFrame = Instance.new("Frame", TeleportContent)
	TpPlayerListFrame.Size = UDim2.new(0.94, 0, 0, 120)
	TpPlayerListFrame.BackgroundColor3 = C_ITEM
	TpPlayerListFrame.BorderSizePixel = 0
	TpPlayerListFrame.ZIndex = 205
	Instance.new("UICorner", TpPlayerListFrame).CornerRadius = UDim.new(0, 6)

	local TpPlayerListScroll = Instance.new("ScrollingFrame", TpPlayerListFrame)
	TpPlayerListScroll.Size = UDim2.new(1, -4, 1, -4)
	TpPlayerListScroll.Position = UDim2.new(0, 2, 0, 2)
	TpPlayerListScroll.BackgroundTransparency = 1
	TpPlayerListScroll.BorderSizePixel = 0
	TpPlayerListScroll.ScrollBarThickness = 4
	TpPlayerListScroll.ScrollBarImageColor3 = C_ACCENT
	TpPlayerListScroll.ZIndex = 206
	TpPlayerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	TpPlayerListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local TpPlayerListLayout = Instance.new("UIListLayout", TpPlayerListScroll)
	TpPlayerListLayout.Padding = UDim.new(0, 3)
	TpPlayerListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Selected Target Display
	local TpSelectedDisplay = Instance.new("TextLabel", TeleportContent)
	TpSelectedDisplay.Text = "Target: None"
	TpSelectedDisplay.Size = UDim2.new(0.94, 0, 0, 25)
	TpSelectedDisplay.BackgroundColor3 = C_SIDE
	TpSelectedDisplay.TextColor3 = C_TEXT_DIM
	TpSelectedDisplay.Font = Enum.Font.GothamBold
	TpSelectedDisplay.TextSize = 11
	TpSelectedDisplay.ZIndex = 205
	Instance.new("UICorner", TpSelectedDisplay).CornerRadius = UDim.new(0, 6)

	-- Function to update player list
	local function UpdatePlayerList2()
		for _, child in pairs(TpPlayerListScroll:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for _, player in pairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local btn = Instance.new("TextButton", TpPlayerListScroll)
				btn.Text = player.Name
				btn.Size = UDim2.new(1, -8, 0, 28)
				btn.BackgroundColor3 = (selectedPlayer2 == player) and C_ACCENT or C_SIDE
				btn.TextColor3 = (selectedPlayer2 == player) and C_TEXT or C_TEXT_DIM
				btn.Font = Enum.Font.Gotham
				btn.TextSize = 11
				btn.BorderSizePixel = 0
				btn.ZIndex = 207
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

				btn.MouseButton1Click:Connect(function()
					selectedPlayer2 = player
					TpSelectedDisplay.Text = "Target: " .. player.Name
					TpSelectedDisplay.TextColor3 = C_GREEN
					UpdatePlayerList2()
				end)

				btn.MouseEnter:Connect(function()
					if selectedPlayer2 ~= player then
						btn.BackgroundColor3 = C_ACCENT
						btn.TextColor3 = C_TEXT
					end
				end)

				btn.MouseLeave:Connect(function()
					if selectedPlayer2 ~= player then
						btn.BackgroundColor3 = C_SIDE
						btn.TextColor3 = C_TEXT_DIM
					end
				end)
			end
		end
	end

	-- Teleport Button
	local BtnTeleport = Instance.new("TextButton", TeleportContent)
	BtnTeleport.Text = L("teleport")
	BtnTeleport.Size = UDim2.new(0.94, 0, 0, 35)
	BtnTeleport.BackgroundColor3 = C_ACCENT
	BtnTeleport.TextColor3 = C_TEXT
	BtnTeleport.Font = Enum.Font.GothamBold
	BtnTeleport.TextSize = 12
	BtnTeleport.BorderSizePixel = 0
	BtnTeleport.ZIndex = 205
	Instance.new("UICorner", BtnTeleport).CornerRadius = UDim.new(0, 6)
	local tpStroke = Instance.new("UIStroke", BtnTeleport)
	tpStroke.Color = C_ACCENT
	tpStroke.Thickness = 1
	RegisterTheme(tpStroke, "Color")

	-- Status Label
	local TeleportStatus = Instance.new("TextLabel", TeleportContent)
	TeleportStatus.Text = "Select player and click TELEPORT"
	TeleportStatus.Size = UDim2.new(0.94, 0, 0, 20)
	TeleportStatus.BackgroundTransparency = 1
	TeleportStatus.TextColor3 = C_TEXT_DIM
	TeleportStatus.Font = Enum.Font.Code
	TeleportStatus.TextSize = 10
	TeleportStatus.ZIndex = 205

	-- Open Window Button Click
	BtnOpenTeleport.MouseButton1Click:Connect(function()
		UpdatePlayerList2()
		TeleportWindow.Visible = true
	end)

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
			TpSelectedDisplay.Text = "Target: None"
			TpSelectedDisplay.TextColor3 = C_TEXT_DIM
			UpdatePlayerList2()
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
			TeleportStatus.Text = L("teleporting_steps")
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

		TeleportStatus.Text = L("teleported_to") .. " " .. selectedPlayer2.Name .. "!"
		TeleportStatus.TextColor3 = C_GREEN

		-- Reset status after 2 seconds
		task.delay(2, function()
			TeleportStatus.Text = "Select player and click TELEPORT"
			TeleportStatus.TextColor3 = C_TEXT_DIM
		end)
	end)

	-- 5. SPECTATE PLAYER - Window Based
	local CardSpectate = CreateCard(L("spectate_player"), 70, 5)

	local BtnOpenSpectate = Instance.new("TextButton", CardSpectate)
	BtnOpenSpectate.Text = "👁 OPEN SPECTATE"
	BtnOpenSpectate.Size = UDim2.new(0.94, 0, 0, 35)
	BtnOpenSpectate.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnOpenSpectate, C_ACCENT)

	-- Create Spectate Window
	local SpectateWindow, SpectateContent = CreateWindow("SPECTATE PLAYER", 290)
	SpectateContent.ScrollBarThickness = 0
	SpectateContent.ScrollingEnabled = false

	local selectedPlayer3 = nil
	local isSpectating = false
	local spectateLoop = nil
	local lastKnownPosition = nil

	-- Target Selection Label
	local SpTargetLabel = Instance.new("TextLabel", SpectateContent)
	SpTargetLabel.Text = "SELECT TARGET"
	SpTargetLabel.Size = UDim2.new(0.94, 0, 0, 20)
	SpTargetLabel.BackgroundTransparency = 1
	SpTargetLabel.TextColor3 = C_TEXT
	SpTargetLabel.Font = Enum.Font.GothamBold
	SpTargetLabel.TextSize = 11
	SpTargetLabel.ZIndex = 205

	-- Player List Frame
	local SpPlayerListFrame = Instance.new("Frame", SpectateContent)
	SpPlayerListFrame.Size = UDim2.new(0.94, 0, 0, 120)
	SpPlayerListFrame.BackgroundColor3 = C_ITEM
	SpPlayerListFrame.BorderSizePixel = 0
	SpPlayerListFrame.ZIndex = 205
	Instance.new("UICorner", SpPlayerListFrame).CornerRadius = UDim.new(0, 6)

	local SpPlayerListScroll = Instance.new("ScrollingFrame", SpPlayerListFrame)
	SpPlayerListScroll.Size = UDim2.new(1, -4, 1, -4)
	SpPlayerListScroll.Position = UDim2.new(0, 2, 0, 2)
	SpPlayerListScroll.BackgroundTransparency = 1
	SpPlayerListScroll.BorderSizePixel = 0
	SpPlayerListScroll.ScrollBarThickness = 4
	SpPlayerListScroll.ScrollBarImageColor3 = C_ACCENT
	SpPlayerListScroll.ZIndex = 206
	SpPlayerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	SpPlayerListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local SpPlayerListLayout = Instance.new("UIListLayout", SpPlayerListScroll)
	SpPlayerListLayout.Padding = UDim.new(0, 3)
	SpPlayerListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Selected Target Display
	local SpSelectedDisplay = Instance.new("TextLabel", SpectateContent)
	SpSelectedDisplay.Text = "Target: None"
	SpSelectedDisplay.Size = UDim2.new(0.94, 0, 0, 25)
	SpSelectedDisplay.BackgroundColor3 = C_SIDE
	SpSelectedDisplay.TextColor3 = C_TEXT_DIM
	SpSelectedDisplay.Font = Enum.Font.GothamBold
	SpSelectedDisplay.TextSize = 11
	SpSelectedDisplay.ZIndex = 205
	Instance.new("UICorner", SpSelectedDisplay).CornerRadius = UDim.new(0, 6)

	-- Function to update player list
	local function UpdatePlayerList3()
		for _, child in pairs(SpPlayerListScroll:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for _, player in pairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local btn = Instance.new("TextButton", SpPlayerListScroll)
				btn.Text = player.Name
				btn.Size = UDim2.new(1, -8, 0, 28)
				btn.BackgroundColor3 = (selectedPlayer3 == player) and C_ACCENT or C_SIDE
				btn.TextColor3 = (selectedPlayer3 == player) and C_TEXT or C_TEXT_DIM
				btn.Font = Enum.Font.Gotham
				btn.TextSize = 11
				btn.BorderSizePixel = 0
				btn.ZIndex = 207
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

				btn.MouseButton1Click:Connect(function()
					selectedPlayer3 = player
					SpSelectedDisplay.Text = "Target: " .. player.Name
					SpSelectedDisplay.TextColor3 = C_GREEN
					UpdatePlayerList3()
				end)

				btn.MouseEnter:Connect(function()
					if selectedPlayer3 ~= player then
						btn.BackgroundColor3 = C_ACCENT
						btn.TextColor3 = C_TEXT
					end
				end)

				btn.MouseLeave:Connect(function()
					if selectedPlayer3 ~= player then
						btn.BackgroundColor3 = C_SIDE
						btn.TextColor3 = C_TEXT_DIM
					end
				end)
			end
		end
	end

	-- Spectate Button
	local BtnSpectate = Instance.new("TextButton", SpectateContent)
	BtnSpectate.Text = "START SPECTATE"
	BtnSpectate.Size = UDim2.new(0.94, 0, 0, 35)
	BtnSpectate.BackgroundColor3 = C_ACCENT
	BtnSpectate.TextColor3 = C_TEXT
	BtnSpectate.Font = Enum.Font.GothamBold
	BtnSpectate.TextSize = 12
	BtnSpectate.BorderSizePixel = 0
	BtnSpectate.ZIndex = 205
	Instance.new("UICorner", BtnSpectate).CornerRadius = UDim.new(0, 6)
	local spStroke = Instance.new("UIStroke", BtnSpectate)
	spStroke.Color = C_ACCENT
	spStroke.Thickness = 1
	RegisterTheme(spStroke, "Color")

	-- Status Label
	local SpectateStatus = Instance.new("TextLabel", SpectateContent)
	SpectateStatus.Text = "Select player and click START"
	SpectateStatus.Size = UDim2.new(0.94, 0, 0, 20)
	SpectateStatus.BackgroundTransparency = 1
	SpectateStatus.TextColor3 = C_TEXT_DIM
	SpectateStatus.Font = Enum.Font.Code
	SpectateStatus.TextSize = 10
	SpectateStatus.ZIndex = 205

	-- Open Window Button Click
	BtnOpenSpectate.MouseButton1Click:Connect(function()
		UpdatePlayerList3()
		SpectateWindow.Visible = true
	end)

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
				SpSelectedDisplay.Text = "Target: None"
				SpSelectedDisplay.TextColor3 = C_TEXT_DIM
				UpdatePlayerList3()
				return
			end

			isSpectating = true
			BtnSpectate.Text = "STOP SPECTATE"
			BtnSpectate.BackgroundColor3 = C_RED
			spStroke.Color = C_RED
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
					spStroke.Color = C_ACCENT
					SpectateStatus.Text = "Player left the game!"
					SpectateStatus.TextColor3 = C_RED
					if spectateLoop then
						spectateLoop:Disconnect()
						spectateLoop = nil
					end
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
			spStroke.Color = C_ACCENT
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
	local CardFriends = CreateCard("👥 " .. L("friends_in_server"), 85, 6)

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
		if FriendsWindow then
			FriendsWindow:Destroy()
		end

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
		local fws = Instance.new("UIStroke", FriendsWindow)
		fws.Color = C_ACCENT
		fws.Thickness = 1

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
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				dragStart = input.Position
				startPos = FriendsWindow.Position
			end
		end)
		TitleBar.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				local delta = input.Position - dragStart
				FriendsWindow.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end
		end)

		FriendsStatus.Text = "Window opened!"
		FriendsStatus.TextColor3 = C_GREEN
	end)

	-- 7. OBJECT AURA (Trash Thrower) - TEMPORARILY DISABLED
	-- Causing issues with PhysicsService on some executors
	-- Will be re-enabled once fixed
	--[[
	local CardAura = CreateCard(L("object_aura"), 70, 7)
	if CardAura:FindFirstChild("UIStroke") then
		CardAura.UIStroke.Transparency = 0
	end

	local BtnOpenAura = Instance.new("TextButton", CardAura)
	BtnOpenAura.Text = "🎯 OPEN OBJECT AURA"
	BtnOpenAura.Size = UDim2.new(0.94, 0, 0, 35)
	BtnOpenAura.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnOpenAura, C_ACCENT)

	-- Create Object Aura Window
	local AuraWindow, AuraContent = CreateWindow("OBJECT AURA", 410)
	AuraContent.ScrollBarThickness = 0
	AuraContent.ScrollingEnabled = false

	-- State variables
	local selectedPlayer4 = nil
	local auraCollectionRange = 100
	local auraLaunchPower = 1000
	local auraInstantTeleport = true
	local isAuraActive = false
	local auraLoop = nil
	local collectedParts = {}
	local auraTargetPart = nil -- Invisible part at target position for AlignPosition

	-- Setup Collision Groups (so projectiles don't hit local player)
	local PhysicsService = nil
	local auraCollisionGroup = "AuraProjectiles"
	local playerCollisionGroup = "AuraPlayer"
	local useCollisionGroups = false

	-- Safely try to get PhysicsService
	pcall(function()
		PhysicsService = game:GetService("PhysicsService")
		if PhysicsService then
			PhysicsService:RegisterCollisionGroup(auraCollisionGroup)
			PhysicsService:RegisterCollisionGroup(playerCollisionGroup)
			PhysicsService:CollisionGroupSetCollidable(auraCollisionGroup, playerCollisionGroup, false)
			useCollisionGroups = true
		end
	end)

	-- Function to set player character to player collision group
	local function SetPlayerCollisionGroup()
		if not useCollisionGroups or not PhysicsService then
			return
		end
		local char = LocalPlayer.Character
		if char then
			for _, part in pairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					pcall(function()
						part.CollisionGroup = playerCollisionGroup
					end)
				end
			end
		end
	end

	-- Set collision group on spawn (only if supported)
	if useCollisionGroups then
		LocalPlayer.CharacterAdded:Connect(function(char)
			task.wait(0.1)
			SetPlayerCollisionGroup()
		end)
		if LocalPlayer.Character then
			SetPlayerCollisionGroup()
		end
	end

	-- Target Selection Label
	local TargetLabel = Instance.new("TextLabel", AuraContent)
	TargetLabel.Text = "SELECT TARGET"
	TargetLabel.Size = UDim2.new(0.94, 0, 0, 20)
	TargetLabel.BackgroundTransparency = 1
	TargetLabel.TextColor3 = C_TEXT
	TargetLabel.Font = Enum.Font.GothamBold
	TargetLabel.TextSize = 11
	TargetLabel.ZIndex = 205

	-- Player List Frame
	local PlayerListFrame = Instance.new("Frame", AuraContent)
	PlayerListFrame.Size = UDim2.new(0.94, 0, 0, 120)
	PlayerListFrame.BackgroundColor3 = C_ITEM
	PlayerListFrame.BorderSizePixel = 0
	PlayerListFrame.ZIndex = 205
	Instance.new("UICorner", PlayerListFrame).CornerRadius = UDim.new(0, 6)

	local PlayerListScroll = Instance.new("ScrollingFrame", PlayerListFrame)
	PlayerListScroll.Size = UDim2.new(1, -4, 1, -4)
	PlayerListScroll.Position = UDim2.new(0, 2, 0, 2)
	PlayerListScroll.BackgroundTransparency = 1
	PlayerListScroll.BorderSizePixel = 0
	PlayerListScroll.ScrollBarThickness = 4
	PlayerListScroll.ScrollBarImageColor3 = C_ACCENT
	PlayerListScroll.ZIndex = 206
	PlayerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	PlayerListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local PlayerListLayout = Instance.new("UIListLayout", PlayerListScroll)
	PlayerListLayout.Padding = UDim.new(0, 3)
	PlayerListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Selected Target Display
	local SelectedDisplay = Instance.new("TextLabel", AuraContent)
	SelectedDisplay.Text = "Target: None"
	SelectedDisplay.Size = UDim2.new(0.94, 0, 0, 25)
	SelectedDisplay.BackgroundColor3 = C_SIDE
	SelectedDisplay.TextColor3 = C_TEXT_DIM
	SelectedDisplay.Font = Enum.Font.GothamBold
	SelectedDisplay.TextSize = 11
	SelectedDisplay.ZIndex = 205
	Instance.new("UICorner", SelectedDisplay).CornerRadius = UDim.new(0, 6)

	-- Function to update player list
	local function UpdatePlayerList4()
		for _, child in pairs(PlayerListScroll:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for _, player in pairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local btn = Instance.new("TextButton", PlayerListScroll)
				btn.Text = player.Name
				btn.Size = UDim2.new(1, -8, 0, 28)
				btn.BackgroundColor3 = (selectedPlayer4 == player) and C_ACCENT or C_SIDE
				btn.TextColor3 = (selectedPlayer4 == player) and C_TEXT or C_TEXT_DIM
				btn.Font = Enum.Font.Gotham
				btn.TextSize = 11
				btn.BorderSizePixel = 0
				btn.ZIndex = 207
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

				btn.MouseButton1Click:Connect(function()
					selectedPlayer4 = player
					SelectedDisplay.Text = "Target: " .. player.Name
					SelectedDisplay.TextColor3 = C_GREEN
					UpdatePlayerList4()
				end)

				btn.MouseEnter:Connect(function()
					if selectedPlayer4 ~= player then
						btn.BackgroundColor3 = C_ACCENT
						btn.TextColor3 = C_TEXT
					end
				end)

				btn.MouseLeave:Connect(function()
					if selectedPlayer4 ~= player then
						btn.BackgroundColor3 = C_SIDE
						btn.TextColor3 = C_TEXT_DIM
					end
				end)
			end
		end
	end

	-- Sliders in window
	local SliderCollection = CreateSlider(AuraContent, "Scan Range", 20, 200, 100, function(val)
		auraCollectionRange = val
	end)

	local SliderPower = CreateSlider(AuraContent, "Launch Power", 200, 3000, 1000, function(val)
		auraLaunchPower = val
	end)

	-- Mode Toggle Button
	local BtnInstantMode = Instance.new("TextButton", AuraContent)
	BtnInstantMode.Text = "MODE: INSTANT TP ✓"
	BtnInstantMode.Size = UDim2.new(0.94, 0, 0, 30)
	BtnInstantMode.BackgroundColor3 = C_ITEM
	BtnInstantMode.TextColor3 = C_GREEN
	BtnInstantMode.Font = Enum.Font.GothamBold
	BtnInstantMode.TextSize = 11
	BtnInstantMode.BorderSizePixel = 0
	BtnInstantMode.ZIndex = 205
	Instance.new("UICorner", BtnInstantMode).CornerRadius = UDim.new(0, 6)
	local modeStroke = Instance.new("UIStroke", BtnInstantMode)
	modeStroke.Color = C_GREEN
	modeStroke.Thickness = 1

	BtnInstantMode.MouseButton1Click:Connect(function()
		auraInstantTeleport = not auraInstantTeleport
		if auraInstantTeleport then
			BtnInstantMode.Text = "MODE: INSTANT TP ✓"
			BtnInstantMode.TextColor3 = C_GREEN
			modeStroke.Color = C_GREEN
		else
			BtnInstantMode.Text = "MODE: LAUNCH 🚀"
			BtnInstantMode.TextColor3 = C_YELLOW
			modeStroke.Color = C_YELLOW
		end
	end)

	-- Start/Stop Button
	local BtnAura = Instance.new("TextButton", AuraContent)
	BtnAura.Text = L("start_fling")
	BtnAura.Size = UDim2.new(0.94, 0, 0, 35)
	BtnAura.BackgroundColor3 = C_ACCENT
	BtnAura.TextColor3 = C_TEXT
	BtnAura.Font = Enum.Font.GothamBold
	BtnAura.TextSize = 12
	BtnAura.BorderSizePixel = 0
	BtnAura.ZIndex = 205
	Instance.new("UICorner", BtnAura).CornerRadius = UDim.new(0, 6)
	local auraStroke = Instance.new("UIStroke", BtnAura)
	auraStroke.Color = C_ACCENT
	auraStroke.Thickness = 1
	RegisterTheme(auraStroke, "Color")

	-- Status Label
	local AuraStatus = Instance.new("TextLabel", AuraContent)
	AuraStatus.Text = "Select player and click START"
	AuraStatus.Size = UDim2.new(0.94, 0, 0, 20)
	AuraStatus.BackgroundTransparency = 1
	AuraStatus.TextColor3 = C_TEXT_DIM
	AuraStatus.Font = Enum.Font.Code
	AuraStatus.TextSize = 10
	AuraStatus.ZIndex = 205

	-- Open Window Button Click
	BtnOpenAura.MouseButton1Click:Connect(function()
		UpdatePlayerList4()
		AuraWindow.Visible = true
	end)

	BtnAura.MouseButton1Click:Connect(function()
		if isAuraActive then
			-- Stop Aura
			isAuraActive = false
			BtnAura.Text = L("start_fling")
			BtnAura.BackgroundColor3 = C_ACCENT
			AuraStatus.Text = L("fling_stopped")
			AuraStatus.TextColor3 = C_TEXT_DIM

			if auraLoop then
				auraLoop:Disconnect()
				auraLoop = nil
			end

			-- Reset all parts - remove AlignPosition constraints
			for _, data in pairs(collectedParts) do
				if data.part and data.part.Parent then
					pcall(function()
						-- Remove AlignPosition and Attachment we added
						local align = data.part:FindFirstChild("AuraAlign")
						if align then
							align:Destroy()
						end
						local att = data.part:FindFirstChild("AuraAtt")
						if att then
							att:Destroy()
						end
						local bv = data.part:FindFirstChild("FlingVelocity")
						if bv then
							bv:Destroy()
						end

						-- Kill velocity
						data.part.Velocity = Vector3.zero
						data.part.RotVelocity = Vector3.zero
						data.part.AssemblyLinearVelocity = Vector3.zero
						data.part.AssemblyAngularVelocity = Vector3.zero

						data.part.CanCollide = data.originalCanCollide or true
						data.part.CustomPhysicalProperties = data.originalPhysics
						-- Reset collision group to default
						data.part.CollisionGroup = "Default"
					end)
				end
			end
			collectedParts = {}

			-- Destroy target anchor part
			if auraTargetPart and auraTargetPart.Parent then
				auraTargetPart:Destroy()
				auraTargetPart = nil
			end
			return
		end

		if not selectedPlayer4 then
			AuraStatus.Text = "Please select a player first!"
			AuraStatus.TextColor3 = C_RED
			return
		end

		if not selectedPlayer4.Parent then
			AuraStatus.Text = "Player left the game!"
			AuraStatus.TextColor3 = C_RED
			selectedPlayer4 = nil
			SelectedDisplay.Text = "Target: None"
			SelectedDisplay.TextColor3 = C_TEXT_DIM
			UpdatePlayerList4()
			return
		end

		-- Start Fling Attack
		isAuraActive = true
		BtnAura.Text = "STOP FLING"
		BtnAura.BackgroundColor3 = C_RED
		AuraStatus.Text = "Collecting objects..."
		AuraStatus.TextColor3 = C_YELLOW

		warn("[Fling] Starting CONSTRAINT-BASED FLING attack on: " .. selectedPlayer4.Name)

		collectedParts = {}

		-- Set SimulationRadius to max
		pcall(function()
			sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
			sethiddenproperty(LocalPlayer, "MaximumSimulationRadius", math.huge)
		end)

		local myChar = LocalPlayer.Character
		local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

		if not myRoot then
			AuraStatus.Text = "Your character not found!"
			AuraStatus.TextColor3 = C_RED
			isAuraActive = false
			BtnAura.Text = "START FLING"
			BtnAura.BackgroundColor3 = C_ACCENT
			return
		end

		local targetChar = selectedPlayer4.Character
		local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

		if not targetRoot then
			AuraStatus.Text = "Target character not found!"
			AuraStatus.TextColor3 = C_RED
			isAuraActive = false
			BtnAura.Text = "START FLING"
			BtnAura.BackgroundColor3 = C_ACCENT
			return
		end

		-- Request streaming around both player and target
		pcall(function()
			LocalPlayer:RequestStreamAroundAsync(myRoot.Position, 10)
			LocalPlayer:RequestStreamAroundAsync(targetRoot.Position, 10)
		end)

		-- Ensure player collision group is set
		SetPlayerCollisionGroup()

		-- Create invisible anchor part for target position (like Black Hole uses)
		if auraTargetPart and auraTargetPart.Parent then
			auraTargetPart:Destroy()
		end
		auraTargetPart = Instance.new("Part")
		auraTargetPart.Name = "AuraTargetAnchor"
		auraTargetPart.Anchored = true
		auraTargetPart.Transparency = 1
		auraTargetPart.CanCollide = false
		auraTargetPart.Size = Vector3.new(1, 1, 1)
		auraTargetPart.CFrame = targetRoot.CFrame
		auraTargetPart.Parent = workspace

		-- Create attachment on target anchor
		local targetAttachment = Instance.new("Attachment", auraTargetPart)
		targetAttachment.Name = "AuraTargetAtt"

		-- Function to collect a part using AlignPosition (like Part Manipulation)
		local function CollectPart(part)
			if collectedParts[part] then
				return false
			end

			-- Store original state
			local origCFrame = part.CFrame
			local origCanCollide = part.CanCollide
			local origPhysics = part.CustomPhysicalProperties

			local success = pcall(function()
				-- Set to aura collision group (won't collide with player!)
				part.CollisionGroup = auraCollisionGroup

				-- ENABLE collision to hit target!
				part.CanCollide = true

				-- HEAVY physics for maximum impact/fling effect
				part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 1, 100, 100)

				-- Kill existing velocity initially
				part.Velocity = Vector3.zero
				part.RotVelocity = Vector3.zero
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero

				-- Remove any existing movers
				for _, c in pairs(part:GetChildren()) do
					if
						c:IsA("BodyMover")
						or c.Name == "AuraAlign"
						or c.Name == "AuraAtt"
						or c.Name == "FlingVelocity"
					then
						c:Destroy()
					end
				end

				-- Create Attachment on the part
				local att = Instance.new("Attachment", part)
				att.Name = "AuraAtt"

				-- Create AlignPosition constraint for server-visible movement
				local align = Instance.new("AlignPosition", part)
				align.Name = "AuraAlign"
				align.Attachment0 = att
				align.Attachment1 = targetAttachment
				align.Mode = Enum.PositionAlignmentMode.TwoAttachment
				align.Responsiveness = 200
				align.MaxForce = 9e9
				align.MaxVelocity = math.huge

				-- Add BodyVelocity for continuous push towards target (for fling effect)
				local bv = Instance.new("BodyVelocity", part)
				bv.Name = "FlingVelocity"
				bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
				bv.P = 5000
				bv.Velocity = Vector3.zero -- Will be updated in main loop
			end)

			if not success then
				return false
			end

			-- Calculate unique orbit parameters
			local partCount = 0
			for _ in pairs(collectedParts) do
				partCount = partCount + 1
			end

			collectedParts[part] = {
				part = part,
				originalCFrame = origCFrame,
				originalCanCollide = origCanCollide,
				originalPhysics = origPhysics,
				state = "attacking",
				collectTime = tick(),
			}

			return true
		end

		-- Initial scan - collect objects near PLAYER first (easier ownership)
		local initialFound = 0
		for _, part in pairs(workspace:GetDescendants()) do
			if
				part:IsA("BasePart")
				and not part.Anchored
				and not part.Parent:FindFirstChild("Humanoid")
				and not part:IsDescendantOf(myChar)
				and not (selectedPlayer4.Character and part:IsDescendantOf(selectedPlayer4.Character))
			then
				local distToMe = (part.Position - myRoot.Position).Magnitude
				if distToMe < auraCollectionRange then
					if CollectPart(part) then
						initialFound = initialFound + 1
					end
				end
			end
		end

		warn("[Fling] Collected " .. initialFound .. " objects near player")

		-- Also scan near target
		pcall(function()
			LocalPlayer:RequestStreamAroundAsync(targetRoot.Position, 10)
		end)

		task.wait(0.3)

		local targetFound = 0
		for _, part in pairs(workspace:GetDescendants()) do
			if
				part:IsA("BasePart")
				and not part.Anchored
				and not part.Parent:FindFirstChild("Humanoid")
				and not part:IsDescendantOf(myChar)
				and not (selectedPlayer4.Character and part:IsDescendantOf(selectedPlayer4.Character))
				and not collectedParts[part]
			then
				local distToTarget = (part.Position - targetRoot.Position).Magnitude
				if distToTarget < auraCollectionRange then
					if CollectPart(part) then
						targetFound = targetFound + 1
					end
				end
			end
		end

		warn("[Fling] Collected " .. targetFound .. " objects near target")

		local totalCollected = initialFound + targetFound
		if totalCollected > 0 then
			AuraStatus.Text = "🎯 " .. totalCollected .. " objects collected!"
			AuraStatus.TextColor3 = C_GREEN
		else
			AuraStatus.Text = "No objects found to throw!"
			AuraStatus.TextColor3 = C_YELLOW
		end

		-- Main loop - update target position and orbit parts using AlignPosition
		local lastScanTime = tick()

		auraLoop = RunService.Heartbeat:Connect(function()
			if not isAuraActive then
				return
			end

			local targetChar2 = selectedPlayer4 and selectedPlayer4.Character
			local targetRoot2 = targetChar2 and targetChar2:FindFirstChild("HumanoidRootPart")
			local myRoot2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

			if not targetRoot2 or not myRoot2 then
				AuraStatus.Text = "Target or player lost!"
				AuraStatus.TextColor3 = C_RED
				return
			end

			-- Keep SimulationRadius maxed
			pcall(function()
				sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
				sethiddenproperty(LocalPlayer, "MaximumSimulationRadius", math.huge)
			end)

			-- Keep player collision group updated
			SetPlayerCollisionGroup()

			local targetPos = targetRoot2.Position

			-- Update target anchor part position (AlignPosition will pull parts here)
			if auraTargetPart and auraTargetPart.Parent then
				-- Position anchor directly at target (slight orbit for chaos)
				local t = tick()
				local orbitOffset = Vector3.new(math.cos(t * 5) * 0.5, math.sin(t * 7) * 0.3, math.sin(t * 5) * 0.5)
				auraTargetPart.CFrame = CFrame.new(targetPos + orbitOffset)
			end

			-- Update individual parts - apply velocity towards target for FLING effect
			local orbitingCount = 0
			for part, data in pairs(collectedParts) do
				if part and part.Parent then
					orbitingCount = orbitingCount + 1

					pcall(function()
						-- Keep collision group set (won't hit us)
						part.CollisionGroup = auraCollisionGroup

						-- ENABLE collision to hit target!
						part.CanCollide = true

						-- Calculate direction to target
						local dirToTarget = (targetPos - part.Position)
						local distance = dirToTarget.Magnitude

						if distance > 0.1 then
							dirToTarget = dirToTarget.Unit
						else
							dirToTarget = Vector3.new(0, 1, 0)
						end

						-- Update BodyVelocity to continuously push towards target
						local bv = part:FindFirstChild("FlingVelocity")
						if bv then
							-- High velocity towards target for fling impact
							local speed = auraLaunchPower
							bv.Velocity = dirToTarget * speed

							-- Add some spin for chaos
							part.AssemblyAngularVelocity =
								Vector3.new(math.random(-50, 50), math.random(-50, 50), math.random(-50, 50))
						end

						-- Also set direct velocity for extra impact
						if distance < 5 then
							-- Very close to target - maximum impact!
							part.AssemblyLinearVelocity = dirToTarget * (auraLaunchPower * 1.5)
						end
					end)
				else
					-- Part was destroyed, remove from table
					collectedParts[part] = nil
				end
			end

			-- Update status
			AuraStatus.Text = "🌀 " .. orbitingCount .. " parts attacking target"
			AuraStatus.TextColor3 = C_GREEN

			-- Continuous scan for new objects every 3 seconds
			if tick() - lastScanTime > 3 then
				lastScanTime = tick()

				pcall(function()
					LocalPlayer:RequestStreamAroundAsync(targetPos, 10)
				end)

				local newFound = 0
				for _, part in pairs(workspace:GetDescendants()) do
					if
						part:IsA("BasePart")
						and not part.Anchored
						and not part.Parent:FindFirstChild("Humanoid")
						and not part:IsDescendantOf(LocalPlayer.Character or workspace)
						and not (selectedPlayer4.Character and part:IsDescendantOf(selectedPlayer4.Character))
						and not collectedParts[part]
					then
						local distToMe = (part.Position - myRoot2.Position).Magnitude
						local distToTarget = (part.Position - targetPos).Magnitude

						if distToMe < auraCollectionRange or distToTarget < auraCollectionRange then
							if CollectPart(part) then
								newFound = newFound + 1
							end
						end
					end
				end

				if newFound > 0 then
					warn("[Fling] Found " .. newFound .. " new objects")
				end
			end
		end)
	end)
	--]]
	-- End of Object Aura (TEMPORARILY DISABLED)

	-- --- RING MODIFIER WINDOW ---
	local RingWindow, RingContent = CreateWindow("RING MODIFIER", 320)

	local ringModes = {
		"Vertical Ring",
		"Horizontal Ring",
		"Vertical & Horizontal",
		"Left Tilt",
		"Right Tilt",
		"Left & Right Tilt",
		"Spiral",
		"Figure 8",
		"DNA Helix",
		"Flower Pattern",
		"Galaxy Spiral",
		"Infinity",
		"Wave Pattern",
		"Atomic Orbit",
		"Butterfly",
		"Tornado",
		"Heart",
		"Vortex",
		"Pendulum",
		"Lemniscate 3D",
		"Star Pattern",
		"Trefoil Knot",
		"Double Spiral",
		"Mobius Strip",
		"Hypocycloid",
		"Sphere Spiral",
		"Asteroid Belt",
		"Rose Curve",
		"Lissajous",
		"Polygonal Orbit",
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
		if currentModeIdx < 1 then
			currentModeIdx = #ringModes
		end
		ModeLabel.Text = ringModes[currentModeIdx]
	end)

	BtnNext.MouseButton1Click:Connect(function()
		currentModeIdx = currentModeIdx + 1
		if currentModeIdx > #ringModes then
			currentModeIdx = 1
		end
		ModeLabel.Text = ringModes[currentModeIdx]
	end)

	-- Ring Functions (Same logic as before)
	local function CalculateRingPos(index, total, center)
		local angle = (index / total) * (2 * math.pi) + os.clock() * ringSpeed
		local ox, oy, oz = 0, 0, 0
		local r = ringRadius
		if currentModeIdx == 1 then
			ox = math.cos(angle) * r
			oy = math.sin(angle) * r
		elseif currentModeIdx == 2 then
			ox = math.cos(angle) * r
			oz = math.sin(angle) * r
		elseif currentModeIdx == 3 then
			local a2 = angle + math.pi / 2
			ox = math.cos(angle) * r
			oy = math.sin(a2) * r
			oz = math.sin(angle) * r
		elseif currentModeIdx == 7 then
			ox = math.cos(angle) * r
			oy = ((index / total) * 2 - 1) * r
			oz = math.sin(angle) * r
		elseif currentModeIdx == 8 then
			ox = math.cos(angle) * r
			oy = math.sin(2 * angle) * r * 0.5
			oz = math.sin(angle) * r * 1.5
		elseif currentModeIdx == 9 then
			ox = math.cos(angle) * r
			oy = math.cos(angle * 2) * r + math.sin(os.clock() * ringSpeed) * r
			oz = math.sin(angle) * r
		elseif currentModeIdx == 16 then
			local h = 2
			local rr = r * (1 - (index / total))
			ox = math.cos(angle) * rr
			oy = (index / total) * r * h
			oz = math.sin(angle) * rr
		else
			ox = math.cos(angle) * r
			oz = math.sin(angle) * r
		end
		return center + Vector3.new(ox, oy, oz)
	end

	-- Global table to track manipulated parts and their original states
	local ManipulatedParts = {}

	local function RestorePart(part)
		for i, data in ipairs(ManipulatedParts) do
			if data.Part == part then
				if part and part.Parent then
					-- Kill Velocity to prevent flinging
					part.Velocity = Vector3.new(0, 0, 0)
					part.RotVelocity = Vector3.new(0, 0, 0)
					part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

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
		if
			part:IsA("BasePart")
			and not part.Anchored
			and not part.Parent:FindFirstChild("Humanoid")
			and not part:IsDescendantOf(LocalPlayer.Character)
		then
			-- Store original state if not already stored
			local isStored = false
			for _, data in ipairs(ManipulatedParts) do
				if data.Part == part then
					isStored = true
					break
				end
			end

			if not isStored then
				table.insert(ManipulatedParts, {
					Part = part,
					OriginalAnchored = part.Anchored,
					OriginalCanCollide = part.CanCollide,
					OriginalTransparency = part.Transparency,
					OriginalCustomPhysicalProperties = part.CustomPhysicalProperties,
				})
			end

			-- Clean existing movers
			for _, c in pairs(part:GetChildren()) do
				if c:IsA("BodyMover") or c:IsA("BodyMover2") or c:IsA("Constraint") then
					c:Destroy()
				end
			end

			part.CanCollide = false
			part.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)

			local att = Instance.new("Attachment", part)
			att.Name = "ManipAtt"
			local align = Instance.new("AlignPosition", part)
			align.Name = "ManipAlign"
			align.Attachment0 = att
			align.Mode = Enum.PositionAlignmentMode.OneAttachment
			align.Responsiveness = 200
			align.MaxForce = 9e9
			return { part = part, align = align }
		end
		return nil
	end

	local function ToggleRing(active)
		isRingActive = active
		if active then
			ringParts = {}
			for _, v in ipairs(workspace:GetDescendants()) do
				local p = ProcessPart(v)
				if p then
					table.insert(ringParts, p)
				end
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
							data.part.Velocity = Vector3.new(0, 0, 0)
						end
					end
				end
			end)
			table.insert(Connections, ringConnection)
		else
			if ringConnection then
				ringConnection:Disconnect()
				ringConnection = nil
			end
			for _, data in ipairs(ringParts) do
				if data.align then
					data.align:Destroy()
				end
				RestorePart(data.part)
			end
			ringParts = {}
		end
	end

	CreateToggle(RingContent, "Enable Ring", false, ToggleRing).LayoutOrder = 2
	CreateSlider(RingContent, "Radius", 5, 100, 50, function(v)
		ringRadius = v
	end).LayoutOrder = 3
	CreateSlider(RingContent, "Speed", 0.1, 10, 2, function(v)
		ringSpeed = v
	end).LayoutOrder = 4

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
			centerPart.Anchored = true
			centerPart.Transparency = 1
			centerPart.CanCollide = false
			local att1 = Instance.new("Attachment", centerPart)
			bhLoop = RunService.Heartbeat:Connect(function()
				local char = LocalPlayer.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					att1.WorldCFrame = root.CFrame
					sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
				end
			end)
			table.insert(Connections, bhLoop)
			for _, v in pairs(workspace:GetDescendants()) do
				if
					v:IsA("BasePart")
					and not v.Anchored
					and not v.Parent:FindFirstChild("Humanoid")
					and not v:IsDescendantOf(LocalPlayer.Character)
				then
					-- Store State
					local isStored = false
					for _, data in ipairs(ManipulatedParts) do
						if data.Part == v then
							isStored = true
							break
						end
					end
					if not isStored then
						table.insert(ManipulatedParts, {
							Part = v,
							OriginalAnchored = v.Anchored,
							OriginalCanCollide = v.CanCollide,
							OriginalTransparency = v.Transparency,
							OriginalCustomPhysicalProperties = v.CustomPhysicalProperties,
						})
					end

					v.CanCollide = false
					local att2 = Instance.new("Attachment", v)
					att2.Name = "ManipAtt"
					local align = Instance.new("AlignPosition", v)
					align.Name = "ManipAlign"
					align.Attachment0 = att2
					align.Attachment1 = att1
					align.Responsiveness = 200
					align.MaxForce = 9e9
				end
			end
		else
			if bhLoop then
				bhLoop:Disconnect()
			end
			if bhFolder then
				bhFolder:Destroy()
			end
			-- Restore all manipulated parts
			-- Note: Since Black Hole affects potentially ALL parts, we iterate the global list
			for i = #ManipulatedParts, 1, -1 do
				RestorePart(ManipulatedParts[i].Part)
			end
		end
	end
	CreateToggle(ManipContent, L("black_hole"), false, ToggleBlackHole).LayoutOrder = 1

	-- Invert Gravity
	local gravActive = false
	local gravLoop = nil
	local gravParts = {}
	local function ToggleGrav(active)
		gravActive = active
		if active then
			gravParts = {}
			for _, v in pairs(workspace:GetDescendants()) do
				if
					v:IsA("BasePart")
					and not v.Anchored
					and not v.Parent:FindFirstChild("Humanoid")
					and not v:IsDescendantOf(LocalPlayer.Character)
				then
					-- Store State
					local isStored = false
					for _, data in ipairs(ManipulatedParts) do
						if data.Part == v then
							isStored = true
							break
						end
					end
					if not isStored then
						table.insert(ManipulatedParts, {
							Part = v,
							OriginalAnchored = v.Anchored,
							OriginalCanCollide = v.CanCollide,
							OriginalTransparency = v.Transparency,
							OriginalCustomPhysicalProperties = v.CustomPhysicalProperties,
						})
					end

					gravParts[v] = true
					v.CanCollide = false
					v.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
				end
			end

			gravLoop = RunService.Heartbeat:Connect(function()
				sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
				for p, _ in pairs(gravParts) do
					if p and p.Parent then
						p.Velocity = Vector3.new(0, 10, 0)
					end
				end
			end)
			table.insert(Connections, gravLoop)
		else
			if gravLoop then
				gravLoop:Disconnect()
			end
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
						if
							v:IsA("BasePart")
							and not v.Anchored
							and not v.Parent:FindFirstChild("Humanoid")
							and not v:IsDescendantOf(c)
						then
							if (v.Position - r.Position).Magnitude < 10 then
								-- Store State
								local isStored = false
								for _, data in ipairs(ManipulatedParts) do
									if data.Part == v then
										isStored = true
										break
									end
								end
								if not isStored then
									table.insert(ManipulatedParts, {
										Part = v,
										OriginalAnchored = v.Anchored,
										OriginalCanCollide = v.CanCollide,
										OriginalTransparency = v.Transparency,
										OriginalCustomPhysicalProperties = v.CustomPhysicalProperties,
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
			if desLoop then
				desLoop:Disconnect()
			end
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
					local parts = workspace:FindPartsInRegion3(
						Region3.new(
							r.Position - Vector3.new(magRadius, magRadius, magRadius),
							r.Position + Vector3.new(magRadius, magRadius, magRadius)
						),
						nil,
						1000
					)
					for _, v in ipairs(parts) do
						if
							v:IsA("BasePart")
							and not v.Anchored
							and not v.Parent:FindFirstChild("Humanoid")
							and not v:IsDescendantOf(c)
						then
							-- Store State
							local isStored = false
							for _, data in ipairs(ManipulatedParts) do
								if data.Part == v then
									isStored = true
									break
								end
							end
							if not isStored then
								table.insert(ManipulatedParts, {
									Part = v,
									OriginalAnchored = v.Anchored,
									OriginalCanCollide = v.CanCollide,
									OriginalTransparency = v.Transparency,
									OriginalCustomPhysicalProperties = v.CustomPhysicalProperties,
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
			if magLoop then
				magLoop:Disconnect()
			end
			-- Restore
			for i = #ManipulatedParts, 1, -1 do
				RestorePart(ManipulatedParts[i].Part)
			end
		end
	end
	CreateToggle(ManipContent, L("part_magnet"), false, ToggleMagnet).LayoutOrder = 4
	CreateSlider(ManipContent, L("magnet_radius"), 10, 200, 50, function(v)
		magRadius = v
	end).LayoutOrder = 5
	CreateSlider(ManipContent, L("magnet_strength"), 10, 500, 100, function(v)
		magStrength = v
	end).LayoutOrder = 6

	local BtnTornado = Instance.new("TextButton", ManipContent)
	BtnTornado.Size = UDim2.new(0.94, 0, 0, 35)
	StyleBtn(BtnTornado, C_TEXT)
	BtnTornado.Text = "Tornado Gui [External]"
	BtnTornado.ZIndex = 205
	BtnTornado.LayoutOrder = 7
	BtnTornado.MouseButton1Click:Connect(function()
		loadstring(
			game:HttpGet(
				"https://raw.githubusercontent.com/hm5650/TornadoGuiIg/refs/heads/main/Srrylolitsobfuscatednomorestealing",
				true
			)
		)()
	end)

	-- --- MAIN FUN TAB CONTENT ---

	local Spacer = Instance.new("Frame", FunScroll)
	Spacer.Size = UDim2.new(1, 0, 0, 10)
	Spacer.BackgroundTransparency = 1
	Spacer.LayoutOrder = 6

	local BtnOpenRing = Instance.new("TextButton", FunScroll)
	BtnOpenRing.Size = UDim2.new(0.96, 0, 0, 35)
	StyleBtn(BtnOpenRing, C_TEXT)
	BtnOpenRing.Text = "OPEN RING MODIFIER"
	BtnOpenRing.LayoutOrder = 7
	BtnOpenRing.MouseButton1Click:Connect(function()
		RingWindow.Visible = not RingWindow.Visible
	end)

	local BtnOpenManip = Instance.new("TextButton", FunScroll)
	BtnOpenManip.Size = UDim2.new(0.96, 0, 0, 35)
	StyleBtn(BtnOpenManip, C_TEXT)
	BtnOpenManip.Text = "OPEN PART MANIPULATION"
	BtnOpenManip.LayoutOrder = 8
	BtnOpenManip.MouseButton1Click:Connect(function()
		ManipWindow.Visible = not ManipWindow.Visible
	end)

	local BtnAntiLag = Instance.new("TextButton", FunScroll)
	BtnAntiLag.Size = UDim2.new(0.96, 0, 0, 35)
	StyleBtn(BtnAntiLag, C_TEXT)
	BtnAntiLag.Text = "AntiLag [External]"
	BtnAntiLag.LayoutOrder = 9
	BtnAntiLag.MouseButton1Click:Connect(function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/igfrx/tpmorPpoT/refs/heads/main/aL", true))()
	end)

	-- AUTO FOLLOW - Window Based
	local CardFollow = CreateCard(L("auto_follow"), 70, 10)

	local BtnOpenFollow = Instance.new("TextButton", CardFollow)
	BtnOpenFollow.Text = "🚶 OPEN AUTO FOLLOW"
	BtnOpenFollow.Size = UDim2.new(0.94, 0, 0, 35)
	BtnOpenFollow.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnOpenFollow, C_ACCENT)

	-- Create Auto Follow Window
	local FollowWindow, FollowContent = CreateWindow("AUTO FOLLOW", 350)
	FollowContent.ScrollBarThickness = 0
	FollowContent.ScrollingEnabled = false

	local followTarget = nil
	local isFollowing = false
	local followLoop = nil
	local camAssistLoop = nil
	local lastMouseMove = 0
	local activeTween = nil

	local function getHRP(c)
		return c and c:FindFirstChild("HumanoidRootPart")
	end
	local function getHum(c)
		return c and c:FindFirstChild("Humanoid")
	end
	local function getAnimator(c)
		local hum = getHum(c)
		return hum and hum:FindFirstChildOfClass("Animator")
	end

	-- Animation Mirror Variables
	local mirrorAnimEnabled = true
	local mirrorAnimLoop = nil
	local myPlayingTracks = {} -- Track animation tracks we're playing
	local lastTargetAnimIds = {} -- Track what animations target is playing

	-- Function to get current playing animations from target
	local function getTargetAnimations(targetChar)
		local anims = {}
		local animator = getAnimator(targetChar)
		if animator then
			for _, track in pairs(animator:GetPlayingAnimationTracks()) do
				if track.Animation then
					table.insert(anims, {
						id = track.Animation.AnimationId,
						speed = track.Speed,
						weight = track.WeightCurrent,
						priority = track.Priority,
						looped = track.Looped,
						timePos = track.TimePosition,
						length = track.Length,
					})
				end
			end
		end
		return anims
	end

	-- Function to play animation on our character
	local function playAnimOnSelf(animId, speed, weight, priority, timePos)
		local myChar = LocalPlayer.Character
		local animator = getAnimator(myChar)
		if not animator then
			return nil
		end

		-- Check if we already have this animation playing
		if myPlayingTracks[animId] then
			local track = myPlayingTracks[animId]
			if track.IsPlaying then
				-- Adjust speed if different
				if math.abs(track.Speed - speed) > 0.1 then
					track:AdjustSpeed(speed)
				end
				-- Sync time position for more accurate mirroring (with small tolerance)
				if timePos and track.Length > 0 then
					local timeDiff = math.abs(track.TimePosition - timePos)
					if timeDiff > 0.1 then -- Only sync if difference is significant
						track.TimePosition = timePos
					end
				end
				return track
			end
		end

		-- Create and play new animation
		local anim = Instance.new("Animation")
		anim.AnimationId = animId

		local success, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)

		if success and track then
			track.Priority = priority or Enum.AnimationPriority.Action
			track:Play()
			track:AdjustSpeed(speed or 1)
			track:AdjustWeight(weight or 1)
			-- Sync to target's time position
			if timePos and track.Length > 0 then
				track.TimePosition = timePos
			end
			myPlayingTracks[animId] = track

			-- Clean up when animation stops
			track.Stopped:Connect(function()
				myPlayingTracks[animId] = nil
				anim:Destroy()
			end)

			return track
		end

		anim:Destroy()
		return nil
	end

	-- Function to stop animation on self
	local function stopAnimOnSelf(animId)
		if myPlayingTracks[animId] then
			pcall(function()
				myPlayingTracks[animId]:Stop()
			end)
			myPlayingTracks[animId] = nil
		end
	end

	-- Function to stop all mirrored animations
	local function stopAllMirroredAnims()
		for animId, track in pairs(myPlayingTracks) do
			pcall(function()
				track:Stop()
			end)
		end
		myPlayingTracks = {}
		lastTargetAnimIds = {}
	end

	-- NEW APPROACH: Direct Joint/Motor6D Transform Copying
	-- This bypasses animation permission issues by copying joint transforms directly

	local function getMotor6Ds(character)
		local motors = {}
		for _, descendant in pairs(character:GetDescendants()) do
			if descendant:IsA("Motor6D") then
				motors[descendant.Name] = descendant
			end
		end
		return motors
	end

	local function copyJointTransforms(targetChar, myChar)
		local targetMotors = getMotor6Ds(targetChar)
		local myMotors = getMotor6Ds(myChar)

		for motorName, targetMotor in pairs(targetMotors) do
			local myMotor = myMotors[motorName]
			if myMotor then
				-- Copy the transform (C0 and C1 define the joint positions)
				-- Transform is the animated offset from the base pose
				pcall(function()
					myMotor.Transform = targetMotor.Transform
				end)
			end
		end
	end

	-- Alternative: Copy individual part CFrames relative to HRP
	local function copyPartPoses(targetChar, myChar)
		local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
		local myHRP = myChar:FindFirstChild("HumanoidRootPart")
		if not (targetHRP and myHRP) then
			return
		end

		local partsToMirror = {
			"Head",
			"UpperTorso",
			"LowerTorso",
			"LeftUpperArm",
			"LeftLowerArm",
			"LeftHand",
			"RightUpperArm",
			"RightLowerArm",
			"RightHand",
			"LeftUpperLeg",
			"LeftLowerLeg",
			"LeftFoot",
			"RightUpperLeg",
			"RightLowerLeg",
			"RightFoot",
			-- R6 parts
			"Torso",
			"Left Arm",
			"Right Arm",
			"Left Leg",
			"Right Leg",
		}

		for _, partName in ipairs(partsToMirror) do
			local targetPart = targetChar:FindFirstChild(partName)
			local myPart = myChar:FindFirstChild(partName)
			if targetPart and myPart then
				pcall(function()
					-- Get the relative CFrame from target's HRP
					local relativeCF = targetHRP.CFrame:ToObjectSpace(targetPart.CFrame)
					-- Apply to our part
					myPart.CFrame = myHRP.CFrame:ToWorldSpace(relativeCF)
				end)
			end
		end
	end

	-- Function to mirror pose from target (using Motor6D transforms)
	local function mirrorPoseFromTarget()
		if not followTarget or not mirrorAnimEnabled then
			return
		end

		local targetChar = followTarget.Character
		local myChar = LocalPlayer.Character
		if not (targetChar and myChar) then
			return
		end

		local targetHum = getHum(targetChar)
		local myHum = getHum(myChar)

		-- Copy humanoid state (sitting, jumping, falling, etc)
		if targetHum and myHum then
			local targetState = targetHum:GetState()
			-- Some states we shouldn't copy
			if targetState ~= Enum.HumanoidStateType.Dead then
				pcall(function()
					myHum:ChangeState(targetState)
				end)
			end
		end

		-- Primary method: Copy Motor6D transforms (works for both R6 and R15)
		copyJointTransforms(targetChar, myChar)

		-- Also copy face/head orientation if exists
		local targetHead = targetChar:FindFirstChild("Head")
		local myHead = myChar:FindFirstChild("Head")
		if targetHead and myHead then
			local targetNeck = targetHead:FindFirstChild("Neck") or targetChar:FindFirstChild("Neck", true)
			local myNeck = myHead:FindFirstChild("Neck") or myChar:FindFirstChild("Neck", true)
			if targetNeck and myNeck and targetNeck:IsA("Motor6D") and myNeck:IsA("Motor6D") then
				pcall(function()
					myNeck.Transform = targetNeck.Transform
				end)
			end
		end
	end

	-- Keep the old function name for compatibility but use new implementation
	local function mirrorAnimationsFromTarget()
		mirrorPoseFromTarget()
	end

	local function smoothAlpha(speed, dt)
		return math.clamp(1 - math.exp(-speed * dt), 0, 1)
	end

	local function computeIdealBehind(targetHRP)
		local look = targetHRP.CFrame.LookVector
		local behindPos = targetHRP.Position - (look * 4) + Vector3.new(0, 2, 0)
		local frontPoint = behindPos + look
		return CFrame.new(behindPos, frontPoint)
	end

	-- New: Exact position copy (for true mirroring)
	local function computeExactPosition(targetHRP)
		return targetHRP.CFrame
	end

	-- Mode: true = exact copy, false = behind
	local exactCopyMode = true

	-- Function to stop/disable default animations on our character
	local defaultAnimScript = nil
	local function disableDefaultAnims()
		local myChar = LocalPlayer.Character
		if not myChar then
			return
		end

		-- Find and disable Animate script
		local animate = myChar:FindFirstChild("Animate")
		if animate and animate:IsA("LocalScript") then
			defaultAnimScript = animate
			animate.Disabled = true
		end

		-- Stop all current playing animations on our character
		local animator = getAnimator(myChar)
		if animator then
			for _, track in pairs(animator:GetPlayingAnimationTracks()) do
				-- Only stop if it's not one we're mirroring
				if not myPlayingTracks[track.Animation and track.Animation.AnimationId] then
					pcall(function()
						track:Stop(0)
					end)
				end
			end
		end
	end

	local function enableDefaultAnims()
		if defaultAnimScript then
			defaultAnimScript.Disabled = false
			defaultAnimScript = nil
		end
	end

	local function tweenPlaceBehind(myHRP, targetHRP)
		if not (myHRP and targetHRP) then
			return
		end
		local desiredCf = computeIdealBehind(targetHRP)
		if activeTween then
			pcall(function()
				activeTween:Cancel()
			end)
			activeTween = nil
		end

		local info = TweenInfo.new(0.01, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local success, tween = pcall(function()
			return TweenService:Create(myHRP, info, { CFrame = desiredCf })
		end)
		if success and tween then
			activeTween = tween
			tween:Play()
			tween.Completed:Connect(function()
				if activeTween == tween then
					activeTween = nil
				end
			end)
		end
	end

	-- Target Selection Label
	local FwTargetLabel = Instance.new("TextLabel", FollowContent)
	FwTargetLabel.Text = "SELECT TARGET"
	FwTargetLabel.Size = UDim2.new(0.94, 0, 0, 20)
	FwTargetLabel.BackgroundTransparency = 1
	FwTargetLabel.TextColor3 = C_TEXT
	FwTargetLabel.Font = Enum.Font.GothamBold
	FwTargetLabel.TextSize = 11
	FwTargetLabel.ZIndex = 205

	-- Player List Frame
	local FwPlayerListFrame = Instance.new("Frame", FollowContent)
	FwPlayerListFrame.Size = UDim2.new(0.94, 0, 0, 120)
	FwPlayerListFrame.BackgroundColor3 = C_ITEM
	FwPlayerListFrame.BorderSizePixel = 0
	FwPlayerListFrame.ZIndex = 205
	Instance.new("UICorner", FwPlayerListFrame).CornerRadius = UDim.new(0, 6)

	local FwPlayerListScroll = Instance.new("ScrollingFrame", FwPlayerListFrame)
	FwPlayerListScroll.Size = UDim2.new(1, -4, 1, -4)
	FwPlayerListScroll.Position = UDim2.new(0, 2, 0, 2)
	FwPlayerListScroll.BackgroundTransparency = 1
	FwPlayerListScroll.BorderSizePixel = 0
	FwPlayerListScroll.ScrollBarThickness = 4
	FwPlayerListScroll.ScrollBarImageColor3 = C_ACCENT
	FwPlayerListScroll.ZIndex = 206
	FwPlayerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	FwPlayerListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local FwPlayerListLayout = Instance.new("UIListLayout", FwPlayerListScroll)
	FwPlayerListLayout.Padding = UDim.new(0, 3)
	FwPlayerListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Selected Target Display
	local FwSelectedDisplay = Instance.new("TextLabel", FollowContent)
	FwSelectedDisplay.Text = "Target: None"
	FwSelectedDisplay.Size = UDim2.new(0.94, 0, 0, 25)
	FwSelectedDisplay.BackgroundColor3 = C_SIDE
	FwSelectedDisplay.TextColor3 = C_TEXT_DIM
	FwSelectedDisplay.Font = Enum.Font.GothamBold
	FwSelectedDisplay.TextSize = 11
	FwSelectedDisplay.ZIndex = 205
	Instance.new("UICorner", FwSelectedDisplay).CornerRadius = UDim.new(0, 6)

	-- Function to update player list
	local function UpdateFollowPlayerList()
		for _, child in pairs(FwPlayerListScroll:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for _, player in pairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local btn = Instance.new("TextButton", FwPlayerListScroll)
				btn.Text = player.DisplayName .. " (@" .. player.Name .. ")"
				btn.Size = UDim2.new(1, -8, 0, 28)
				btn.BackgroundColor3 = (followTarget == player) and C_ACCENT or C_SIDE
				btn.TextColor3 = (followTarget == player) and C_TEXT or C_TEXT_DIM
				btn.Font = Enum.Font.Gotham
				btn.TextSize = 11
				btn.BorderSizePixel = 0
				btn.ZIndex = 207
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

				btn.MouseButton1Click:Connect(function()
					followTarget = player
					FwSelectedDisplay.Text = "Target: " .. player.DisplayName
					FwSelectedDisplay.TextColor3 = C_GREEN
					UpdateFollowPlayerList()
				end)

				btn.MouseEnter:Connect(function()
					if followTarget ~= player then
						btn.BackgroundColor3 = C_ACCENT
						btn.TextColor3 = C_TEXT
					end
				end)

				btn.MouseLeave:Connect(function()
					if followTarget ~= player then
						btn.BackgroundColor3 = C_SIDE
						btn.TextColor3 = C_TEXT_DIM
					end
				end)
			end
		end
	end

	-- Follow Button
	local BtnFollow = Instance.new("TextButton", FollowContent)
	BtnFollow.Text = "START FOLLOW (G)"
	BtnFollow.Size = UDim2.new(0.94, 0, 0, 35)
	BtnFollow.BackgroundColor3 = C_GREEN
	BtnFollow.TextColor3 = C_TEXT
	BtnFollow.Font = Enum.Font.GothamBold
	BtnFollow.TextSize = 12
	BtnFollow.BorderSizePixel = 0
	BtnFollow.ZIndex = 205
	Instance.new("UICorner", BtnFollow).CornerRadius = UDim.new(0, 6)
	local fwStroke = Instance.new("UIStroke", BtnFollow)
	fwStroke.Color = C_GREEN
	fwStroke.Thickness = 1

	-- Status Label
	local FollowStatus = Instance.new("TextLabel", FollowContent)
	FollowStatus.Text = "Select player and click START"
	FollowStatus.Size = UDim2.new(0.94, 0, 0, 20)
	FollowStatus.BackgroundTransparency = 1
	FollowStatus.TextColor3 = C_TEXT_DIM
	FollowStatus.Font = Enum.Font.Code
	FollowStatus.TextSize = 10
	FollowStatus.ZIndex = 205

	-- Exact Copy Mode Toggle (position same as target vs behind)
	local BtnExactCopy = Instance.new("TextButton", FollowContent)
	BtnExactCopy.Text = "📍 Exact Position: ON"
	BtnExactCopy.Size = UDim2.new(0.94, 0, 0, 30)
	BtnExactCopy.BackgroundColor3 = C_GREEN
	BtnExactCopy.TextColor3 = C_TEXT
	BtnExactCopy.Font = Enum.Font.GothamBold
	BtnExactCopy.TextSize = 11
	BtnExactCopy.BorderSizePixel = 0
	BtnExactCopy.ZIndex = 205
	Instance.new("UICorner", BtnExactCopy).CornerRadius = UDim.new(0, 6)
	local exactStroke = Instance.new("UIStroke", BtnExactCopy)
	exactStroke.Color = C_GREEN
	exactStroke.Thickness = 1

	BtnExactCopy.MouseButton1Click:Connect(function()
		exactCopyMode = not exactCopyMode
		if exactCopyMode then
			BtnExactCopy.Text = "📍 Exact Position: ON"
			BtnExactCopy.BackgroundColor3 = C_GREEN
			exactStroke.Color = C_GREEN
		else
			BtnExactCopy.Text = "📍 Exact Position: OFF (Behind)"
			BtnExactCopy.BackgroundColor3 = C_ACCENT
			exactStroke.Color = C_ACCENT
		end
	end)

	-- Open Window Button Click
	BtnOpenFollow.MouseButton1Click:Connect(function()
		UpdateFollowPlayerList()
		FollowWindow.Visible = true
	end)

	local function StopFollow()
		isFollowing = false
		BtnFollow.Text = "START FOLLOW (G)"
		BtnFollow.BackgroundColor3 = C_GREEN
		fwStroke.Color = C_GREEN
		FollowStatus.Text = "Follow stopped"
		FollowStatus.TextColor3 = C_TEXT_DIM
		if followLoop then
			followLoop:Disconnect()
			followLoop = nil
		end
		if camAssistLoop then
			camAssistLoop:Disconnect()
			camAssistLoop = nil
		end

		local c = LocalPlayer.Character
		local h = getHum(c)
		if h then
			h.PlatformStand = false
			h:ChangeState(Enum.HumanoidStateType.GettingUp)
		end

		-- Stop all mirrored animations and re-enable default anims
		stopAllMirroredAnims()
		enableDefaultAnims()
		if mirrorAnimLoop then
			mirrorAnimLoop:Disconnect()
			mirrorAnimLoop = nil
		end

		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Custom
	end

	local function StartFollow()
		if not followTarget then
			FollowStatus.Text = "Please select a player first!"
			FollowStatus.TextColor3 = C_RED
			return
		end

		if not followTarget.Parent then
			FollowStatus.Text = "Player left the game!"
			FollowStatus.TextColor3 = C_RED
			followTarget = nil
			FwSelectedDisplay.Text = "Target: None"
			FwSelectedDisplay.TextColor3 = C_TEXT_DIM
			UpdateFollowPlayerList()
			return
		end

		isFollowing = true
		BtnFollow.Text = "STOP FOLLOW (G)"
		BtnFollow.BackgroundColor3 = C_RED
		fwStroke.Color = C_RED
		FollowStatus.Text = "Following " .. followTarget.DisplayName
		FollowStatus.TextColor3 = C_GREEN

		-- Main follow loop - using RenderStepped for smoother updates
		followLoop = RunService.RenderStepped:Connect(function(dt)
			if not isFollowing or not followTarget then
				StopFollow()
				return
			end

			local myChar = LocalPlayer.Character
			local myHRP = getHRP(myChar)
			local myHum = getHum(myChar)

			local tChar = followTarget.Character
			local tHRP = getHRP(tChar)
			local tHum = getHum(tChar)

			if not (myHRP and myHum and tHRP and tHum and tHum.Health > 0) then
				return
			end

			pcall(function()
				if exactCopyMode then
					-- Exact copy mode - same position and rotation as target
					-- Copy CFrame (position + rotation)
					myHRP.CFrame = tHRP.CFrame

					-- Let Humanoid handle movement naturally for proper walking animation
					myHum.PlatformStand = false

					-- Copy velocity for smooth movement
					myHRP.Velocity = tHRP.Velocity
				else
					-- Behind mode - stay behind target with lerp
					local desiredCf = computeIdealBehind(tHRP)
					myHRP.CFrame = myHRP.CFrame:Lerp(desiredCf, 0.5)
					myHum.PlatformStand = false
				end
			end)
		end)

		-- Animation trigger loop - make our character's default animations play based on target movement
		mirrorAnimLoop = RunService.Heartbeat:Connect(function()
			if not isFollowing or not followTarget then
				return
			end

			local myChar = LocalPlayer.Character
			local tChar = followTarget.Character
			if not (myChar and tChar) then
				return
			end

			local myHum = getHum(myChar)
			local tHum = getHum(tChar)
			local tHRP = getHRP(tChar)

			if myHum and tHum and tHRP then
				pcall(function()
					-- Check if target is moving
					local targetMoveDir = tHum.MoveDirection
					local isMoving = targetMoveDir.Magnitude > 0.1

					if isMoving then
						-- Tell our humanoid to "move" in the target's direction
						-- This triggers the walking animation
						myHum:Move(targetMoveDir, false)
					else
						-- Not moving - stop movement to trigger idle animation
						myHum:Move(Vector3.new(0, 0, 0), false)
					end

					-- Copy jump if target is jumping
					local tState = tHum:GetState()
					if tState == Enum.HumanoidStateType.Jumping then
						myHum.Jump = true
					elseif tState == Enum.HumanoidStateType.Freefall then
						myHum:ChangeState(Enum.HumanoidStateType.Freefall)
					elseif tState == Enum.HumanoidStateType.Seated then
						-- If target is sitting, try to sit
						myHum.Sit = true
					end
				end)
			end
		end)

		camAssistLoop = RunService.RenderStepped:Connect(function(dt)
			if not isFollowing or not followTarget then
				return
			end

			-- Skip camera assist in exact copy mode - use default camera
			if exactCopyMode then
				return
			end

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
		if isFollowing then
			StopFollow()
		else
			StartFollow()
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			lastMouseMove = tick()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if
			not gp
			and not UserInputService:GetFocusedTextBox()
			and input.KeyCode == Config.Keybinds.FollowPlayer
			and followTarget
		then
			if isFollowing then
				StopFollow()
			else
				StartFollow()
			end
		end
	end)

	-- ==================== CLONE PLAYER APPEARANCE ====================
	local CardClone = CreateCard("Clone Player", 70, 11)

	local BtnOpenClone = Instance.new("TextButton", CardClone)
	BtnOpenClone.Text = "🎭 OPEN CLONE PLAYER"
	BtnOpenClone.Size = UDim2.new(0.94, 0, 0, 35)
	BtnOpenClone.Position = UDim2.new(0.03, 0, 0, 35)
	StyleBtn(BtnOpenClone, C_ACCENT)

	-- Create Clone Player Window
	local CloneWindow, CloneContent = CreateWindow("CLONE PLAYER", 460)
	CloneContent.ScrollBarThickness = 2
	CloneContent.ScrollingEnabled = true
	CloneContent.CanvasSize = UDim2.new(0, 0, 0, 0) -- Reset to allow auto-sizing
	CloneContent.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local cloneTarget = nil
	local originalAppearance = nil -- Store original appearance for restore

	-- Clone Target Selection Label
	local CloneTargetLabel = Instance.new("TextLabel", CloneContent)
	CloneTargetLabel.Text = "SELECT PLAYER TO CLONE"
	CloneTargetLabel.Size = UDim2.new(0.94, 0, 0, 20)
	CloneTargetLabel.BackgroundTransparency = 1
	CloneTargetLabel.TextColor3 = C_TEXT
	CloneTargetLabel.Font = Enum.Font.GothamBold
	CloneTargetLabel.TextSize = 11
	CloneTargetLabel.ZIndex = 205

	-- Player List Frame
	local ClonePlayerListFrame = Instance.new("Frame", CloneContent)
	ClonePlayerListFrame.Size = UDim2.new(0.94, 0, 0, 100)
	ClonePlayerListFrame.BackgroundColor3 = C_ITEM
	ClonePlayerListFrame.BorderSizePixel = 0
	ClonePlayerListFrame.ZIndex = 205
	Instance.new("UICorner", ClonePlayerListFrame).CornerRadius = UDim.new(0, 6)

	local ClonePlayerListScroll = Instance.new("ScrollingFrame", ClonePlayerListFrame)
	ClonePlayerListScroll.Size = UDim2.new(1, -4, 1, -4)
	ClonePlayerListScroll.Position = UDim2.new(0, 2, 0, 2)
	ClonePlayerListScroll.BackgroundTransparency = 1
	ClonePlayerListScroll.BorderSizePixel = 0
	ClonePlayerListScroll.ScrollBarThickness = 4
	ClonePlayerListScroll.ScrollBarImageColor3 = C_ACCENT
	ClonePlayerListScroll.ZIndex = 206
	ClonePlayerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	ClonePlayerListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local ClonePlayerListLayout = Instance.new("UIListLayout", ClonePlayerListScroll)
	ClonePlayerListLayout.Padding = UDim.new(0, 3)
	ClonePlayerListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Selected Target Display
	local CloneSelectedDisplay = Instance.new("TextLabel", CloneContent)
	CloneSelectedDisplay.Text = "Target: None"
	CloneSelectedDisplay.Size = UDim2.new(0.94, 0, 0, 25)
	CloneSelectedDisplay.BackgroundColor3 = C_SIDE
	CloneSelectedDisplay.TextColor3 = C_TEXT_DIM
	CloneSelectedDisplay.Font = Enum.Font.GothamBold
	CloneSelectedDisplay.TextSize = 11
	CloneSelectedDisplay.ZIndex = 205
	Instance.new("UICorner", CloneSelectedDisplay).CornerRadius = UDim.new(0, 6)

	-- Avatar Preview Image
	local ClonePreviewImage = Instance.new("ImageLabel", CloneContent)
	ClonePreviewImage.Size = UDim2.new(0, 100, 0, 100)
	ClonePreviewImage.Position = UDim2.new(0.5, -50, 0, 0) -- Will be positioned by Layout
	ClonePreviewImage.BackgroundTransparency = 1
	ClonePreviewImage.Image = "rbxassetid://10734950309" -- Default placeholder
	ClonePreviewImage.ZIndex = 205
	Instance.new("UICorner", ClonePreviewImage).CornerRadius = UDim.new(0, 12)

	-- Function to update player list
	local function UpdateClonePlayerList()
		for _, child in pairs(ClonePlayerListScroll:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for _, player in pairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local btn = Instance.new("TextButton", ClonePlayerListScroll)
				btn.Text = player.DisplayName .. " (@" .. player.Name .. ")"
				btn.Size = UDim2.new(1, -8, 0, 28)
				btn.BackgroundColor3 = (cloneTarget == player) and C_ACCENT or C_SIDE
				btn.TextColor3 = (cloneTarget == player) and C_TEXT or C_TEXT_DIM
				btn.Font = Enum.Font.Gotham
				btn.TextSize = 11
				btn.BorderSizePixel = 0
				btn.ZIndex = 207
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

				btn.MouseButton1Click:Connect(function()
					cloneTarget = player
					CloneSelectedDisplay.Text = "Target: " .. player.DisplayName
					CloneSelectedDisplay.TextColor3 = C_GREEN
					
					-- Update Preview
					local userId = player.UserId
					local thumbUrl = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150"
					ClonePreviewImage.Image = thumbUrl
					
					UpdateClonePlayerList()
				end)

				btn.MouseEnter:Connect(function()
					if cloneTarget ~= player then
						btn.BackgroundColor3 = C_ACCENT
						btn.TextColor3 = C_TEXT
					end
				end)

				btn.MouseLeave:Connect(function()
					if cloneTarget ~= player then
						btn.BackgroundColor3 = C_SIDE
						btn.TextColor3 = C_TEXT_DIM
					end
				end)
			end
		end
	end

	-- Function to clone player appearance using HumanoidDescription
	local function ClonePlayerAppearance()
		if not cloneTarget then
			return false, "No target selected"
		end

		local myChar = LocalPlayer.Character
		local myHum = myChar and myChar:FindFirstChild("Humanoid")
		if not myHum then
			return false, "No humanoid"
		end

		-- Load Description
		local success, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(cloneTarget.UserId)
		end)

		if not success or not desc then
			return false, "Failed to load avatar"
		end

		-- Clear existing accessories first for clean morph
		for _, obj in ipairs(myChar:GetChildren()) do
			if obj:IsA("Accessory") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or obj:IsA("BodyColors") then
				obj:Destroy()
			end
		end
		
		-- Apply Description
		local applySuccess = pcall(function()
			if myHum.ApplyDescriptionClientServer then
				myHum:ApplyDescriptionClientServer(desc)
			else
				myHum:ApplyDescription(desc)
			end
		end)

		if applySuccess then
			return true, "Cloned!"
		else
			return false, "Apply failed"
		end
	end
	


	-- Clone Button
	local BtnClone = Instance.new("TextButton", CloneContent)
	BtnClone.Text = "🎭 CLONE APPEARANCE"
	BtnClone.Size = UDim2.new(0.94, 0, 0, 35)
	BtnClone.BackgroundColor3 = C_GREEN
	BtnClone.TextColor3 = C_TEXT
	BtnClone.Font = Enum.Font.GothamBold
	BtnClone.TextSize = 12
	BtnClone.BorderSizePixel = 0
	BtnClone.ZIndex = 205
	Instance.new("UICorner", BtnClone).CornerRadius = UDim.new(0, 6)
	local cloneStroke = Instance.new("UIStroke", BtnClone)
	cloneStroke.Color = C_GREEN
	cloneStroke.Thickness = 1

	-- Reset Button
	local BtnReset = Instance.new("TextButton", CloneContent)
	BtnReset.Text = "↺ RESET AVATAR"
	BtnReset.Size = UDim2.new(0.94, 0, 0, 35)
	BtnReset.BackgroundColor3 = C_RED
	BtnReset.TextColor3 = C_TEXT
	BtnReset.Font = Enum.Font.GothamBold
	BtnReset.TextSize = 12
	BtnReset.BorderSizePixel = 0
	BtnReset.ZIndex = 205
	Instance.new("UICorner", BtnReset).CornerRadius = UDim.new(0, 6)
	local resetStroke = Instance.new("UIStroke", BtnReset)
	resetStroke.Color = C_RED
	resetStroke.Thickness = 1
	
	BtnReset.MouseButton1Click:Connect(function()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChild("Humanoid")
		if hum then
			-- Load own description
			local success, desc = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
			end)
			
			if success and desc then
				-- Clear existing accessories
				for _, obj in ipairs(char:GetChildren()) do
					if obj:IsA("Accessory") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or obj:IsA("BodyColors") then
						obj:Destroy()
					end
				end
				
				-- Apply own description
				pcall(function()
					if hum.ApplyDescriptionClientServer then
						hum:ApplyDescriptionClientServer(desc)
					else
						hum:ApplyDescription(desc)
					end
				end)
				
				CloneStatus.Text = "Avatar Reset!"
				CloneStatus.TextColor3 = C_GREEN
			else
				CloneStatus.Text = "Failed to load original avatar"
				CloneStatus.TextColor3 = C_RED
			end
		end
	end)

	-- Status Label
	local CloneStatus = Instance.new("TextLabel", CloneContent)
	CloneStatus.Text = "Select a player and click Clone"
	CloneStatus.Size = UDim2.new(0.94, 0, 0, 20)
	CloneStatus.BackgroundTransparency = 1
	CloneStatus.TextColor3 = C_TEXT_DIM
	CloneStatus.Font = Enum.Font.Code
	CloneStatus.TextSize = 10
	CloneStatus.ZIndex = 205

	-- Info Label
	local CloneInfo = Instance.new("TextLabel", CloneContent)
	CloneInfo.Text = "⚠️ Client-side only (only you see it)"
	CloneInfo.Size = UDim2.new(0.94, 0, 0, 18)
	CloneInfo.BackgroundTransparency = 1
	CloneInfo.TextColor3 = C_TEXT_DIM
	CloneInfo.Font = Enum.Font.Code
	CloneInfo.TextSize = 9
	CloneInfo.ZIndex = 205

	BtnOpenClone.MouseButton1Click:Connect(function()
		UpdateClonePlayerList()
		CloneWindow.Visible = true
	end)

	BtnClone.MouseButton1Click:Connect(function()
		if not cloneTarget then
			CloneStatus.Text = "Please select a player first!"
			CloneStatus.TextColor3 = C_RED
			return
		end

		if not cloneTarget.Parent then
			CloneStatus.Text = "Player left the game!"
			CloneStatus.TextColor3 = C_RED
			cloneTarget = nil
			CloneSelectedDisplay.Text = "Target: None"
			CloneSelectedDisplay.TextColor3 = C_TEXT_DIM
			UpdateClonePlayerList()
			return
		end

		local success, msg = ClonePlayerAppearance()
		if success then
			CloneStatus.Text = "✅ " .. msg
			CloneStatus.TextColor3 = C_GREEN
		else
			CloneStatus.Text = "❌ Failed: " .. (msg or "Unknown error")
			CloneStatus.TextColor3 = C_RED
		end
	end)

	-- Cleanup Hook
	local oldCleanup = UIHandlers.CleanupTools
	UIHandlers.CleanupTools = function()
		if oldCleanup then
			oldCleanup()
		end
		-- Fun Module Cleanups
		if ToggleRing then
			ToggleRing(false)
		end
		if ToggleBlackHole then
			ToggleBlackHole(false)
		end
		if ToggleGrav then
			ToggleGrav(false)
		end
		if ToggleDestroyer then
			ToggleDestroyer(false)
		end
		if ToggleMagnet then
			ToggleMagnet(false)
		end

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
			for i = #ManipulatedParts, 1, -1 do
				table.remove(ManipulatedParts, i)
			end
		end

		if RingWindow then
			RingWindow:Destroy()
		end
		if ManipWindow then
			ManipWindow:Destroy()
		end
		if FollowWindow then
			FollowWindow:Destroy()
		end
		if CloneWindow then
			CloneWindow:Destroy()
		end
		if followLoop then
			followLoop:Disconnect()
		end
		if camAssistLoop then
			camAssistLoop:Disconnect()
		end
		if mirrorAnimLoop then
			mirrorAnimLoop:Disconnect()
			mirrorAnimLoop = nil
		end
		stopAllMirroredAnims()
		if auraLoop then
			auraLoop:Disconnect()
			auraLoop = nil
		end
		isAuraActive = false
	end
end

return SetupFunUI
