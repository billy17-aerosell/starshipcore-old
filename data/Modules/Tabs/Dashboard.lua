local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Helper function to get localized text
local function L(key, ...)
	if _G.StarshipLocale and _G.StarshipLocale.Get then
		return _G.StarshipLocale.Get(key, ...)
	end
	return key
end

-- Use global StarshipColors for theme consistency (fallback if not set)
local Colors = _G.StarshipColors
	or {
		MAIN = Color3.fromRGB(10, 10, 14),
		ITEM = Color3.fromRGB(20, 20, 28),
		ACCENT = Color3.fromRGB(90, 110, 245),
		TEXT = Color3.fromRGB(240, 240, 250),
		TEXT_DIM = Color3.fromRGB(140, 140, 160),
		GREEN = Color3.fromRGB(60, 255, 160),
		YELLOW = Color3.fromRGB(255, 220, 60),
		RED = Color3.fromRGB(255, 80, 80),
	}
local DISCORD_LINK = "https://discord.gg/ftmA7BheTc"

return function(Page, UI, Connections, Config, LocalPlayer, UIHandlers, RegisterTheme)
	Page:ClearAllChildren()

	local MainContainer = Instance.new("ScrollingFrame", Page)
	MainContainer.Size = UDim2.new(1, 0, 1, 0)
	MainContainer.BackgroundTransparency = 1
	MainContainer.BorderSizePixel = 0
	MainContainer.ScrollBarThickness = 4
	MainContainer.ScrollBarImageColor3 = Colors.ACCENT
	MainContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	MainContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	MainContainer.ScrollingDirection = Enum.ScrollingDirection.Y

	local mainPadding = Instance.new("UIPadding", MainContainer)
	mainPadding.PaddingLeft = UDim.new(0, 8)
	mainPadding.PaddingRight = UDim.new(0, 8)
	mainPadding.PaddingTop = UDim.new(0, 8)
	mainPadding.PaddingBottom = UDim.new(0, 8)

	local mainLayout = Instance.new("UIListLayout", MainContainer)
	mainLayout.Padding = UDim.new(0, 10)
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mainLayout.FillDirection = Enum.FillDirection.Vertical

	-- === WELCOME GREETING SECTION ===
	local WelcomeCard = Instance.new("Frame", MainContainer)
	WelcomeCard.Size = UDim2.new(1, 0, 0, 70)
	WelcomeCard.BackgroundColor3 = Colors.ITEM
	WelcomeCard.LayoutOrder = 0
	Instance.new("UICorner", WelcomeCard).CornerRadius = UDim.new(0, 10)
	RegisterTheme(WelcomeCard, "BackgroundColor3", "Item")

	-- Profile Avatar
	local Avatar = Instance.new("ImageLabel", WelcomeCard)
	Avatar.Size = UDim2.new(0, 50, 0, 50)
	Avatar.Position = UDim2.new(0, 12, 0.5, -25)
	Avatar.BackgroundColor3 = Colors.MAIN
	Instance.new("UICorner", Avatar).CornerRadius = UDim.new(1, 0)
	RegisterTheme(Avatar, "BackgroundColor3", "Main")

	task.spawn(function()
		local userId = LocalPlayer.UserId
		-- Try rbxthumb first (more reliable in exploits)
		local thumbUrl = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
		Avatar.Image = thumbUrl

		-- Fallback to GetUserThumbnailAsync if rbxthumb doesn't work
		task.delay(0.5, function()
			if Avatar and Avatar.Parent and (Avatar.Image == "" or Avatar.Image == thumbUrl) then
				local success, content = pcall(function()
					return Players:GetUserThumbnailAsync(
						userId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size420x420
					)
				end)
				if success and content and content ~= "" then
					Avatar.Image = content
				end
			end
		end)
	end)

	-- Greeting Text
	local hour = tonumber(os.date("%H"))
	local greetingKey = "good_evening"
	if hour >= 5 and hour < 12 then
		greetingKey = "good_morning"
	elseif hour >= 12 and hour < 17 then
		greetingKey = "good_afternoon"
	end
	local greeting = L(greetingKey)

	local GreetingLabel = Instance.new("TextLabel", WelcomeCard)
	GreetingLabel.Text = greeting .. ","
	GreetingLabel.Size = UDim2.new(1, -80, 0, 22)
	GreetingLabel.Position = UDim2.new(0, 72, 0, 14)
	GreetingLabel.BackgroundTransparency = 1
	GreetingLabel.TextColor3 = Colors.TEXT_DIM
	GreetingLabel.Font = Enum.Font.Gotham
	GreetingLabel.TextSize = 13
	GreetingLabel.TextXAlignment = Enum.TextXAlignment.Left
	RegisterTheme(GreetingLabel, "TextColor3", "TextDim")

	local NameLabel = Instance.new("TextLabel", WelcomeCard)
	NameLabel.Text = LocalPlayer.DisplayName
	NameLabel.Size = UDim2.new(1, -80, 0, 26)
	NameLabel.Position = UDim2.new(0, 72, 0, 34)
	NameLabel.BackgroundTransparency = 1
	NameLabel.TextColor3 = Colors.TEXT
	NameLabel.Font = Enum.Font.GothamBold
	NameLabel.TextSize = 18
	NameLabel.TextXAlignment = Enum.TextXAlignment.Left
	RegisterTheme(NameLabel, "TextColor3", "Text")

	-- Store reference for spoof name updates
	UIHandlers.DashboardNameLabel = NameLabel

	-- Premium Badge (if applicable)
	local PremiumBadge = Instance.new("TextLabel", WelcomeCard)
	PremiumBadge.Text = L("premium")
	PremiumBadge.Size = UDim2.new(0, 70, 0, 22)
	PremiumBadge.Position = UDim2.new(1, -82, 0.5, -11)
	PremiumBadge.BackgroundColor3 = Colors.ACCENT
	PremiumBadge.TextColor3 = Color3.new(1, 1, 1)
	PremiumBadge.Font = Enum.Font.GothamBold
	PremiumBadge.TextSize = 10
	Instance.new("UICorner", PremiumBadge).CornerRadius = UDim.new(0, 6)
	RegisterTheme(PremiumBadge, "BackgroundColor3", "Accent")

	-- === GAME DETECTION STATUS (Below Welcome Card) ===
	local GameDetectionCard = Instance.new("Frame", MainContainer)
	GameDetectionCard.Size = UDim2.new(1, 0, 0, 0)
	GameDetectionCard.AutomaticSize = Enum.AutomaticSize.Y
	GameDetectionCard.BackgroundColor3 = Colors.ITEM
	GameDetectionCard.LayoutOrder = 1
	Instance.new("UICorner", GameDetectionCard).CornerRadius = UDim.new(0, 10)
	RegisterTheme(GameDetectionCard, "BackgroundColor3", "Item")

	local gameDetectionPadding = Instance.new("UIPadding", GameDetectionCard)
	gameDetectionPadding.PaddingLeft = UDim.new(0, 10)
	gameDetectionPadding.PaddingRight = UDim.new(0, 10)
	gameDetectionPadding.PaddingTop = UDim.new(0, 10)
	gameDetectionPadding.PaddingBottom = UDim.new(0, 10)

	local gameDetectionLayout = Instance.new("UIListLayout", GameDetectionCard)
	gameDetectionLayout.Padding = UDim.new(0, 8)
	gameDetectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gameDetectionLayout.FillDirection = Enum.FillDirection.Vertical

	-- Title
	local gameDetectionTitle = Instance.new("TextLabel", GameDetectionCard)
	gameDetectionTitle.Text = "🎮  " .. L("game_detection")
	gameDetectionTitle.Size = UDim2.new(1, 0, 0, 20)
	gameDetectionTitle.BackgroundTransparency = 1
	gameDetectionTitle.TextColor3 = Colors.TEXT_DIM
	gameDetectionTitle.Font = Enum.Font.GothamBold
	gameDetectionTitle.TextSize = 11
	gameDetectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	gameDetectionTitle.LayoutOrder = 1
	RegisterTheme(gameDetectionTitle, "TextColor3", "TextDim")

	-- Get game name from MarketplaceService
	local currentPlaceId = game.PlaceId
	local gameName = "Unknown Game"

	pcall(function()
		local MarketplaceService = game:GetService("MarketplaceService")
		local info = MarketplaceService:GetProductInfo(currentPlaceId)
		if info and info.Name then
			gameName = info.Name
		end
	end)

	-- Game Name Row
	local gameNameRow = Instance.new("Frame", GameDetectionCard)
	gameNameRow.Size = UDim2.new(1, 0, 0, 36)
	gameNameRow.BackgroundColor3 = Colors.MAIN
	gameNameRow.LayoutOrder = 2
	Instance.new("UICorner", gameNameRow).CornerRadius = UDim.new(0, 8)
	RegisterTheme(gameNameRow, "BackgroundColor3", "Main")

	local gameNameLabel = Instance.new("TextLabel", gameNameRow)
	gameNameLabel.Text = gameName
	gameNameLabel.Size = UDim2.new(1, -20, 1, 0)
	gameNameLabel.Position = UDim2.new(0, 10, 0, 0)
	gameNameLabel.BackgroundTransparency = 1
	gameNameLabel.TextColor3 = Colors.TEXT
	gameNameLabel.Font = Enum.Font.GothamBold
	gameNameLabel.TextSize = 13
	gameNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	gameNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	RegisterTheme(gameNameLabel, "TextColor3", "Text")

	-- === COLUMNS CONTAINER ===
	local Container = Instance.new("Frame", MainContainer)
	Container.Size = UDim2.new(1, 0, 0, 0)
	Container.AutomaticSize = Enum.AutomaticSize.Y
	Container.BackgroundTransparency = 1
	Container.BorderSizePixel = 0
	Container.LayoutOrder = 2

	-- Left Column
	local LeftCol = Instance.new("Frame", Container)
	LeftCol.Size = UDim2.new(0.5, -6, 0, 0)
	LeftCol.AutomaticSize = Enum.AutomaticSize.Y
	LeftCol.Position = UDim2.new(0, 0, 0, 0)
	LeftCol.BackgroundTransparency = 1

	local leftLayout = Instance.new("UIListLayout", LeftCol)
	leftLayout.Padding = UDim.new(0, 10)
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.FillDirection = Enum.FillDirection.Vertical

	-- Right Column
	local RightCol = Instance.new("Frame", Container)
	RightCol.Size = UDim2.new(0.5, -6, 0, 0)
	RightCol.AutomaticSize = Enum.AutomaticSize.Y
	RightCol.Position = UDim2.new(0.5, 6, 0, 0)
	RightCol.BackgroundTransparency = 1

	local rightLayout = Instance.new("UIListLayout", RightCol)
	rightLayout.Padding = UDim.new(0, 10)
	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightLayout.FillDirection = Enum.FillDirection.Vertical

	local function CreateCard(parent, title, height, order)
		local card = Instance.new("Frame", parent)
		card.Size = UDim2.new(1, 0, 0, height)
		card.BackgroundColor3 = Colors.ITEM
		card.LayoutOrder = order or 0
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
		RegisterTheme(card, "BackgroundColor3", "Item")
		local lbl = Instance.new("TextLabel", card)
		lbl.Text = "  " .. title
		lbl.Size = UDim2.new(1, 0, 0, 28)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = Colors.TEXT_DIM
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 12
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(lbl, "TextColor3", "TextDim")
		return card
	end

	local function CreateInfoRow(parent, label, value, yPos)
		local row = Instance.new("Frame", parent)
		row.Size = UDim2.new(1, -16, 0, 24)
		row.Position = UDim2.new(0, 8, 0, yPos)
		row.BackgroundTransparency = 1
		local lbl = Instance.new("TextLabel", row)
		lbl.Text = label
		lbl.Size = UDim2.new(0.45, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = Colors.TEXT_DIM
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 12
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		RegisterTheme(lbl, "TextColor3", "TextDim")
		local val = Instance.new("TextLabel", row)
		val.Name = "Value"
		val.Text = value or "..."
		val.Size = UDim2.new(0.55, 0, 1, 0)
		val.Position = UDim2.new(0.45, 0, 0, 0)
		val.BackgroundTransparency = 1
		val.TextColor3 = Colors.TEXT
		val.Font = Enum.Font.GothamBold
		val.TextSize = 12
		val.TextXAlignment = Enum.TextXAlignment.Right
		val.TextTruncate = Enum.TextTruncate.AtEnd
		RegisterTheme(val, "TextColor3", "Text")
		return val
	end

	-- === 1. SERVER INFORMATION (Left Column) ===
	local ServerCard = CreateCard(LeftCol, L("server_info"), 160, 1)

	local placeIdVal = CreateInfoRow(ServerCard, L("place_id"), tostring(game.PlaceId), 28)
	local jobIdVal = CreateInfoRow(ServerCard, L("job_id"), string.sub(game.JobId, 1, 14) .. "..", 50)
	local playerCountVal = CreateInfoRow(ServerCard, L("players"), "0/0", 72)
	local serverAgeVal = CreateInfoRow(ServerCard, L("server_age"), "...", 94)
	local pingVal = CreateInfoRow(ServerCard, L("ping"), "0ms", 116)
	local fpsVal = CreateInfoRow(ServerCard, L("fps"), "0", 138)

	-- Copy Job ID button
	local copyJobBtn = Instance.new("TextButton", ServerCard)
	copyJobBtn.Text = L("copy")
	copyJobBtn.Size = UDim2.new(0, 50, 0, 18)
	copyJobBtn.Position = UDim2.new(1, -58, 0, 52)
	copyJobBtn.BackgroundColor3 = Colors.MAIN
	copyJobBtn.TextColor3 = Colors.ACCENT
	copyJobBtn.Font = Enum.Font.GothamBold
	copyJobBtn.TextSize = 10
	copyJobBtn.ZIndex = 2
	Instance.new("UICorner", copyJobBtn).CornerRadius = UDim.new(0, 4)
	RegisterTheme(copyJobBtn, "BackgroundColor3", "Main")
	RegisterTheme(copyJobBtn, "TextColor3", "Accent")

	copyJobBtn.MouseButton1Click:Connect(function()
		if setclipboard then
			setclipboard(game.JobId)
			copyJobBtn.Text = L("ok")
			task.wait(1)
			copyJobBtn.Text = L("copy")
		end
	end)

	-- === 2. EXECUTOR INFORMATION (Left Column) ===
	local ExecCard = CreateCard(LeftCol, L("executor_info"), 100, 2)

	local function GetExecutorName()
		if identifyexecutor then
			local name, version = identifyexecutor()
			return name or "Unknown", version or "?"
		elseif getexecutorname then
			return getexecutorname(), "?"
		elseif syn then
			return "Synapse X", "?"
		elseif KRNL_LOADED then
			return "KRNL", "?"
		elseif fluxus then
			return "Fluxus", "?"
		elseif Sentinel then
			return "Sentinel", "?"
		end
		return "Unknown", "?"
	end

	local execName, execVersion = GetExecutorName()
	CreateInfoRow(ExecCard, L("executor"), execName, 28)
	CreateInfoRow(ExecCard, L("version"), execVersion, 50)

	local hwid = "N/A"
	pcall(function()
		hwid = string.sub(game:GetService("RbxAnalyticsService"):GetClientId(), 1, 12) .. ".."
	end)
	local hwidVal = CreateInfoRow(ExecCard, L("hwid"), hwid, 72)

	local copyHwidBtn = Instance.new("TextButton", ExecCard)
	copyHwidBtn.Text = L("copy")
	copyHwidBtn.Size = UDim2.new(0, 50, 0, 18)
	copyHwidBtn.Position = UDim2.new(1, -58, 0, 74)
	copyHwidBtn.BackgroundColor3 = Colors.MAIN
	copyHwidBtn.TextColor3 = Colors.ACCENT
	copyHwidBtn.Font = Enum.Font.GothamBold
	copyHwidBtn.TextSize = 10
	copyHwidBtn.ZIndex = 2
	Instance.new("UICorner", copyHwidBtn).CornerRadius = UDim.new(0, 4)
	RegisterTheme(copyHwidBtn, "BackgroundColor3", "Main")
	RegisterTheme(copyHwidBtn, "TextColor3", "Accent")

	copyHwidBtn.MouseButton1Click:Connect(function()
		pcall(function()
			if setclipboard then
				setclipboard(game:GetService("RbxAnalyticsService"):GetClientId())
				copyHwidBtn.Text = L("ok")
				task.wait(1)
				copyHwidBtn.Text = L("copy")
			end
		end)
	end)

	-- === 3. FRIENDS IN SERVER (Right Column) ===
	local FriendsCard = CreateCard(RightCol, L("friends_in_game"), 120, 1)

	local FriendsScroll = Instance.new("ScrollingFrame", FriendsCard)
	FriendsScroll.Size = UDim2.new(1, -16, 1, -35)
	FriendsScroll.Position = UDim2.new(0, 8, 0, 30)
	FriendsScroll.BackgroundTransparency = 1
	FriendsScroll.BorderSizePixel = 0
	FriendsScroll.ScrollBarThickness = 3
	FriendsScroll.ScrollBarImageColor3 = Colors.ACCENT
	FriendsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Instance.new("UIListLayout", FriendsScroll).Padding = UDim.new(0, 5)
	RegisterTheme(FriendsScroll, "ScrollBarImageColor3", "Accent")

	local function RefreshFriends()
		for _, c in pairs(FriendsScroll:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end

		local friendCount = 0
		for _, player in pairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local isFriend = false
				pcall(function()
					isFriend = LocalPlayer:IsFriendsWith(player.UserId)
				end)

				if isFriend then
					friendCount = friendCount + 1
					local row = Instance.new("Frame", FriendsScroll)
					row.Size = UDim2.new(1, 0, 0, 30)
					row.BackgroundColor3 = Colors.MAIN
					Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
					RegisterTheme(row, "BackgroundColor3", "Main")

					local avatar = Instance.new("ImageLabel", row)
					avatar.Size = UDim2.new(0, 24, 0, 24)
					avatar.Position = UDim2.new(0, 4, 0.5, -12)
					avatar.BackgroundColor3 = Colors.ITEM
					Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

					pcall(function()
						local thumb = Players:GetUserThumbnailAsync(
							player.UserId,
							Enum.ThumbnailType.HeadShot,
							Enum.ThumbnailSize.Size48x48
						)
						avatar.Image = thumb
					end)

					local name = Instance.new("TextLabel", row)
					name.Text = player.DisplayName
					name.Size = UDim2.new(1, -75, 1, 0)
					name.Position = UDim2.new(0, 34, 0, 0)
					name.BackgroundTransparency = 1
					name.TextColor3 = Colors.TEXT
					name.Font = Enum.Font.GothamBold
					name.TextSize = 11
					name.TextXAlignment = Enum.TextXAlignment.Left
					name.TextTruncate = Enum.TextTruncate.AtEnd
					RegisterTheme(name, "TextColor3", "Text")

					local tpBtn = Instance.new("TextButton", row)
					tpBtn.Text = L("tp")
					tpBtn.Size = UDim2.new(0, 32, 0, 22)
					tpBtn.Position = UDim2.new(1, -38, 0.5, -11)
					tpBtn.BackgroundColor3 = Colors.ACCENT
					tpBtn.TextColor3 = Color3.new(0, 0, 0)
					tpBtn.Font = Enum.Font.GothamBold
					tpBtn.TextSize = 10
					Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 5)
					RegisterTheme(tpBtn, "BackgroundColor3", "Accent")

					tpBtn.MouseButton1Click:Connect(function()
						if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
							local myChar = LocalPlayer.Character
							if myChar and myChar:FindFirstChild("HumanoidRootPart") then
								myChar.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
							end
						end
					end)
				end
			end
		end

		if friendCount == 0 then
			local noFriends = Instance.new("TextLabel", FriendsScroll)
			noFriends.Text = L("no_friends")
			noFriends.Size = UDim2.new(1, 0, 0, 30)
			noFriends.BackgroundTransparency = 1
			noFriends.TextColor3 = Colors.TEXT_DIM
			noFriends.Font = Enum.Font.Gotham
			noFriends.TextSize = 12
			RegisterTheme(noFriends, "TextColor3", "TextDim")
		end
	end

	RefreshFriends()

	Players.PlayerAdded:Connect(RefreshFriends)
	Players.PlayerRemoving:Connect(RefreshFriends)

	-- === 4. DISCORD (Right Column) ===
	local DiscordCard = CreateCard(RightCol, L("discord"), 60, 2)

	local discordBtn = Instance.new("TextButton", DiscordCard)
	discordBtn.Text = L("copy_discord")
	discordBtn.Size = UDim2.new(0.92, 0, 0, 28)
	discordBtn.Position = UDim2.new(0.04, 0, 0, 32)
	discordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	discordBtn.TextColor3 = Color3.new(1, 1, 1)
	discordBtn.Font = Enum.Font.GothamBold
	discordBtn.TextSize = 12
	Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0, 6)

	discordBtn.MouseButton1Click:Connect(function()
		if setclipboard then
			setclipboard(DISCORD_LINK)
			discordBtn.Text = L("copied")
			task.wait(1)
			discordBtn.Text = L("copy_discord")
		end
	end)

	-- === 5. PLAYER INFO (Right Column) ===
	local PlayerCard = CreateCard(RightCol, L("your_account"), 100, 3)
	local UsernameValue = CreateInfoRow(PlayerCard, L("username"), LocalPlayer.Name, 28)
	local DisplayNameValue = CreateInfoRow(PlayerCard, L("display_name"), LocalPlayer.DisplayName, 50)

	-- Store references for spoof name updates
	UIHandlers.DashboardUsernameLabel = UsernameValue
	UIHandlers.DashboardDisplayNameLabel = DisplayNameValue

	-- === SYNC COLUMN HEIGHTS ===
	-- Wait for layout to calculate, then sync heights
	task.defer(function()
		task.wait(0.1) -- Allow AutomaticSize to calculate

		local leftHeight = leftLayout.AbsoluteContentSize.Y
		local rightHeight = rightLayout.AbsoluteContentSize.Y
		local maxHeight = math.max(leftHeight, rightHeight)

		-- Set both columns to the max height
		LeftCol.AutomaticSize = Enum.AutomaticSize.None
		RightCol.AutomaticSize = Enum.AutomaticSize.None
		LeftCol.Size = UDim2.new(0.5, -6, 0, maxHeight)
		RightCol.Size = UDim2.new(0.5, -6, 0, maxHeight)

		-- Update container height
		Container.AutomaticSize = Enum.AutomaticSize.None
		Container.Size = UDim2.new(1, 0, 0, maxHeight)
	end)

	-- === LIVE UPDATE LOOP ===
	local serverStartTime = workspace.DistributedGameTime
	local frameCount = 0
	local lastFpsUpdate = tick()

	local updateConn = RunService.Heartbeat:Connect(function()
		frameCount = frameCount + 1

		-- Update every 0.5 seconds
		if tick() - lastFpsUpdate >= 0.5 then
			-- FPS
			local fps = math.floor(frameCount / (tick() - lastFpsUpdate))
			fpsVal.Text = tostring(fps)
			fpsVal.TextColor3 = fps < 30 and Colors.RED or (fps < 50 and Colors.YELLOW or Colors.GREEN)

			frameCount = 0
			lastFpsUpdate = tick()

			-- Player count
			local maxPlayers = Players.MaxPlayers
			local currentPlayers = #Players:GetPlayers()
			playerCountVal.Text = currentPlayers .. "/" .. maxPlayers

			-- Server age
			local age = workspace.DistributedGameTime
			local hours = math.floor(age / 3600)
			local mins = math.floor((age % 3600) / 60)
			serverAgeVal.Text = string.format("%dh %dm", hours, mins)

			-- Ping
			local ping = 0
			pcall(function()
				ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
			end)
			pingVal.Text = ping .. "ms"
			pingVal.TextColor3 = ping > 200 and Colors.RED or (ping > 100 and Colors.YELLOW or Colors.GREEN)
		end
	end)

	table.insert(Connections, updateConn)
end
