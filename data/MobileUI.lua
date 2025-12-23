--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║                  STARSHIP MOBILE                              ║
    ║                  Powered by WindUI                            ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local VERSION = "1.0.0-mobile"

-- ══════════════════════════════════════════════════════════════════
-- LOAD WINDUI
-- ══════════════════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ══════════════════════════════════════════════════════════════════
-- CREATE WINDOW
-- ══════════════════════════════════════════════════════════════════
local Window = WindUI:CreateWindow({
	Title = "STARSHIP PREMIUM",
	Folder = "StarshipMobile",
	Author = "By StarshipCore Team",
	Size = UDim2.fromOffset(420, 520),
	Transparent = true,
	Theme = "Dark",
	SideBarWidth = 140,
	User = {
		Enabled = true,
		Anonymous = true, -- Set to true to hide real username
		Callback = function()
			-- Optional: callback when profile is clicked
			WindUI:Notify({
				Title = "Profile",
				Content = "Welcome, " .. Players.LocalPlayer.DisplayName .. "!",
				Duration = 3,
			})
		end,
	},
	Topbar = {
		Height = 44,
		ButtonsType = "Default", -- "Default" or "Mac" style buttons (minimize, close)
	},
	OpenButton = {
		Title = "STARSHIP-CORE",
		Icon = "rbxassetid://91946746369709",
		CornerRadius = UDim.new(1, 0), -- Fully rounded
		StrokeThickness = 2,
		Enabled = true,
		Draggable = true, -- Bisa di-drag ke posisi yang diinginkan
		OnlyMobile = false, -- Muncul di PC dan Mobile
		Color = ColorSequence.new(
			Color3.fromHex("#6366f1"), -- Indigo
			Color3.fromHex("#8b5cf6") -- Purple gradient
		),
	},
})

-- ══════════════════════════════════════════════════════════════════
-- FPS, PING & ROLE TAGS (Top bar display)
-- ══════════════════════════════════════════════════════════════════

-- Get session data from StarshipSession (set by main loader)
local function GetSessionData()
	local session = getgenv().StarshipSession or {}
	return {
		Role = session.Role or "VIP",
		Duration = session.Duration or "LIFETIME",
		Expiry = session.Expiry,
	}
end

local sessionData = GetSessionData()

-- Role Tag (VIP/OWNER)
local roleColor = "#a855f7" -- Purple default
if sessionData.Role == "OWNER" then
	roleColor = "#f59e0b" -- Orange/Gold for OWNER
elseif sessionData.Role == "VIP" then
	roleColor = "#a855f7" -- Purple for VIP
end

local RoleTag = Window:Tag({
	Title = sessionData.Role,
	Color = Color3.fromHex(roleColor),
})

local FPSTag = Window:Tag({
	Title = "FPS: 0",
	Icon = "monitor",
	Color = Color3.fromHex("#22c55e"),
})

local PingTag = Window:Tag({
	Title = "PING: 0ms",
	Icon = "wifi",
	Color = Color3.fromHex("#3b82f6"),
})

-- Live update FPS & PING
task.spawn(function()
	local frameCount = 0
	local lastTime = tick()

	RunService.Heartbeat:Connect(function()
		frameCount = frameCount + 1

		local now = tick()
		if now - lastTime >= 1 then
			-- Update FPS
			local fps = math.floor(frameCount / (now - lastTime))
			local fpsColor = "#22c55e" -- Green
			if fps < 30 then
				fpsColor = "#ef4444" -- Red
			elseif fps < 50 then
				fpsColor = "#eab308" -- Yellow
			end

			pcall(function()
				FPSTag:SetTitle("FPS: " .. fps)
				FPSTag:SetColor(Color3.fromHex(fpsColor))
			end)

			-- Update Ping
			local ping = 0
			pcall(function()
				ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
			end)

			local pingColor = "#3b82f6" -- Blue
			if ping > 150 then
				pingColor = "#ef4444" -- Red
			elseif ping > 80 then
				pingColor = "#eab308" -- Yellow
			end

			pcall(function()
				PingTag:SetTitle("PING: " .. ping .. "ms")
				PingTag:SetColor(Color3.fromHex(pingColor))
			end)

			frameCount = 0
			lastTime = now
		end
	end)
end)

-- ══════════════════════════════════════════════════════════════════
-- VARIABLES
-- ══════════════════════════════════════════════════════════════════
local Connections = {}
local Config = {
	WalkSpeed = 16,
	JumpPower = 50,
	FlySpeed = 50,
}

-- ══════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ══════════════════════════════════════════════════════════════════
local function GetCharacter()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function GetHumanoid()
	local char = GetCharacter()
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetHRP()
	local char = GetCharacter()
	return char and char:FindFirstChild("HumanoidRootPart")
end

-- ══════════════════════════════════════════════════════════════════
-- 🏠 DASHBOARD TAB
-- ══════════════════════════════════════════════════════════════════
local DashboardTab = Window:Tab({
	Title = "Dashboard",
	Icon = "layout-dashboard",
})

-- ══════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS FOR DASHBOARD
-- ══════════════════════════════════════════════════════════════════
local function GetGreeting()
	local hour = tonumber(os.date("%H"))
	if hour >= 5 and hour < 12 then
		return "☀️ Good Morning"
	elseif hour >= 12 and hour < 17 then
		return "🌤️ Good Afternoon"
	elseif hour >= 17 and hour < 21 then
		return "🌆 Good Evening"
	else
		return "🌙 Good Night"
	end
end

local function GetExecutorInfo()
	local name, version = "Unknown", "?"
	pcall(function()
		if identifyexecutor then
			name, version = identifyexecutor()
		elseif getexecutorname then
			name = getexecutorname()
		end
	end)
	return name or "Unknown", version or "?"
end

local function GetPing()
	local ping = 0
	pcall(function()
		ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
	end)
	return ping
end

local function GetFPS()
	return math.floor(workspace:GetRealPhysicsFPS())
end

local function GetServerAge()
	local age = workspace.DistributedGameTime
	local hours = math.floor(age / 3600)
	local mins = math.floor((age % 3600) / 60)
	return string.format("%dh %dm", hours, mins)
end

local function GetGameName()
	local name = "Unknown Game"
	pcall(function()
		local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		if info and info.Name then
			name = info.Name
		end
	end)
	return name
end

local function UpdateTool(char, toolName)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end

	local currentTool = char:FindFirstChildOfClass("Tool")

	if toolName then
		if currentTool and currentTool.Name == toolName then
			return
		end
		if currentTool then
			hum:UnequipTools()
		end

		local backpack = LocalPlayer.Backpack
		local newTool = backpack:FindFirstChild(toolName)
		if newTool then
			hum:EquipTool(newTool)
		end
	else
		if currentTool then
			hum:UnequipTools()
		end
	end
end

-- ══════════════════════════════════════════════════════════════════
-- WELCOME SECTION
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Paragraph({
	Title = GetGreeting() .. ", " .. LocalPlayer.DisplayName .. "!",
	Desc = "Welcome to Starship Mobile • Version " .. VERSION,
})

DashboardTab:Space()

-- ══════════════════════════════════════════════════════════════════
-- VIP STATUS
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Section({ Title = "💎 VIP Status", TextSize = 16 })

local vipStatusDesc = "👑 Role: "
	.. sessionData.Role
	.. "\n"
	.. "⏰ Duration: "
	.. sessionData.Duration
	.. "\n"
	.. "✅ Status: Active"

DashboardTab:Paragraph({
	Title = "🎫 Your Subscription",
	Desc = vipStatusDesc,
})

DashboardTab:Space()

-- ══════════════════════════════════════════════════════════════════
-- GAME DETECTION
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Section({ Title = "🎮 Current Game", TextSize = 16 })

local gameName = GetGameName()
DashboardTab:Paragraph({
	Title = "📍 " .. gameName,
	Desc = "Place ID: " .. game.PlaceId,
})

DashboardTab:Space()

-- ══════════════════════════════════════════════════════════════════
-- ACCOUNT INFORMATION
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Section({ Title = "👤 Your Account", TextSize = 16 })

local accountDesc = "🏷️ Display Name: "
	.. LocalPlayer.DisplayName
	.. "\n"
	.. "👤 Username: "
	.. LocalPlayer.Name
	.. "\n"
	.. "🆔 User ID: "
	.. LocalPlayer.UserId
	.. "\n"
	.. "📅 Account Age: "
	.. LocalPlayer.AccountAge
	.. " days\n"
	.. "⭐ Status: Premium Member"

local AccountCard = DashboardTab:Paragraph({
	Title = "🎭 Profile Info",
	Desc = accountDesc,
})

DashboardTab:Space()

-- ══════════════════════════════════════════════════════════════════
-- SERVER INFORMATION
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Section({ Title = "🌐 Server Details", TextSize = 16 })

local serverDesc = "🔢 Place ID: "
	.. game.PlaceId
	.. "\n"
	.. "🔑 Job ID: "
	.. string.sub(game.JobId, 1, 20)
	.. "...\n"
	.. "👥 Players: "
	.. #Players:GetPlayers()
	.. "/"
	.. Players.MaxPlayers

local ServerCard = DashboardTab:Paragraph({
	Title = "🖥️ Server Info",
	Desc = serverDesc,
})

DashboardTab:Button({
	Title = "📋 Copy Job ID",
	Desc = "Copy server Job ID to clipboard",
	Callback = function()
		if setclipboard then
			setclipboard(game.JobId)
			WindUI:Notify({ Title = "Copied!", Content = "Job ID copied to clipboard", Duration = 2 })
		else
			WindUI:Notify({ Title = "Error", Content = "Clipboard not available", Duration = 2 })
		end
	end,
})

DashboardTab:Space()

-- ══════════════════════════════════════════════════════════════════
-- FRIENDS IN SERVER
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Section({ Title = "👥 Friends in Server", TextSize = 16 })

local function GetFriendsInServer()
	local friends = {}
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local success, isFriend = pcall(function()
				return LocalPlayer:IsFriendsWith(player.UserId)
			end)
			if success and isFriend then
				table.insert(friends, player.DisplayName .. " (@" .. player.Name .. ")")
			end
		end
	end
	if #friends == 0 then
		return "No friends in this server"
	end
	return table.concat(friends, "\n")
end

local FriendsCard = DashboardTab:Paragraph({
	Title = "🤝 Friends Here",
	Desc = GetFriendsInServer(),
})

DashboardTab:Space()

-- ══════════════════════════════════════════════════════════════════
-- QUICK ACTIONS
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Section({ Title = "⚡ Quick Actions", TextSize = 16 })

DashboardTab:Button({
	Title = "🔄 Refresh Dashboard",
	Desc = "Update all statistics",
	Callback = function()
		-- Update Live Stats
		local newExecName, newExecVersion = GetExecutorInfo()
		local newStatsDesc = "⚡ Executor: "
			.. newExecName
			.. " ("
			.. newExecVersion
			.. ")\n"
			.. "👥 Players: "
			.. #Players:GetPlayers()
			.. "/"
			.. Players.MaxPlayers
			.. "\n"
			.. "📶 Ping: "
			.. GetPing()
			.. " ms\n"
			.. "🖥️ FPS: "
			.. GetFPS()
			.. "\n"
			.. "⏱️ Server Age: "
			.. GetServerAge()
		LiveStatsCard:SetDesc(newStatsDesc)

		-- Update Server Card
		local newServerDesc = "🔢 Place ID: "
			.. game.PlaceId
			.. "\n"
			.. "🔑 Job ID: "
			.. string.sub(game.JobId, 1, 20)
			.. "...\n"
			.. "👥 Players: "
			.. #Players:GetPlayers()
			.. "/"
			.. Players.MaxPlayers
		ServerCard:SetDesc(newServerDesc)

		-- Update Friends
		FriendsCard:SetDesc(GetFriendsInServer())

		WindUI:Notify({ Title = "✅ Refreshed", Content = "Dashboard updated!", Duration = 2 })
	end,
})

DashboardTab:Button({
	Title = "💬 Copy Discord Invite",
	Desc = "Get Starship Discord link",
	Callback = function()
		if setclipboard then
			setclipboard("https://discord.gg/starship")
			WindUI:Notify({ Title = "Copied!", Content = "Discord link copied!", Duration = 2 })
		end
	end,
})

DashboardTab:Button({
	Title = "🔗 Rejoin Server",
	Desc = "Rejoin the current server",
	Callback = function()
		WindUI:Notify({ Title = "Rejoining...", Content = "Teleporting to server...", Duration = 2 })
		task.delay(1, function()
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId)
		end)
	end,
})

DashboardTab:Button({
	Title = "🌍 Server Hop",
	Desc = "Join a different server",
	Callback = function()
		WindUI:Notify({ Title = "Server Hop", Content = "Finding new server...", Duration = 2 })
		task.delay(1, function()
			pcall(function()
				local servers = game:GetService("HttpService"):JSONDecode(
					game:HttpGet(
						"https://games.roblox.com/v1/games/"
							.. game.PlaceId
							.. "/servers/Public?sortOrder=Asc&limit=100"
					)
				)
				for _, server in pairs(servers.data) do
					if server.id ~= game.JobId and server.playing < server.maxPlayers then
						game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, server.id)
						return
					end
				end
				WindUI:Notify({ Title = "Error", Content = "No available servers found", Duration = 2 })
			end)
		end)
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- AUTO-UPDATE STATS (Every 5 seconds)
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
	while task.wait(5) do
		pcall(function()
			local newExecName, newExecVersion = GetExecutorInfo()
			local newStatsDesc = "⚡ Executor: "
				.. newExecName
				.. " ("
				.. newExecVersion
				.. ")\n"
				.. "👥 Players: "
				.. #Players:GetPlayers()
				.. "/"
				.. Players.MaxPlayers
				.. "\n"
				.. "📶 Ping: "
				.. GetPing()
				.. " ms\n"
				.. "🖥️ FPS: "
				.. GetFPS()
				.. "\n"
				.. "⏱️ Server Age: "
				.. GetServerAge()
			LiveStatsCard:SetDesc(newStatsDesc)
		end)
	end
end)

-- ══════════════════════════════════════════════════════════════════
-- 🛠️ TOOLS TAB
-- ══════════════════════════════════════════════════════════════════
local ToolsTab = Window:Tab({
	Title = "Tools",
	Icon = "wrench",
})

-- 🏃 MOVEMENT
ToolsTab:Section({ Title = "🏃 Player Settings", TextSize = 20 })

ToolsTab:Slider({
	Title = "WalkSpeed",
	Desc = "Running speed (Default: 16)",
	Step = 1,
	Value = { Min = 16, Max = 200, Default = 16 },
	Callback = function(v)
		Config.WalkSpeed = v
		local hum = GetHumanoid()
		if hum then
			hum.WalkSpeed = v
		end
	end,
})

ToolsTab:Slider({
	Title = "JumpPower",
	Desc = "Jump height (Default: 50)",
	Step = 1,
	Value = { Min = 50, Max = 300, Default = 50 },
	Callback = function(v)
		Config.JumpPower = v
		local hum = GetHumanoid()
		if hum then
			hum.JumpPower = v
		end
	end,
})

-- Infinite Jump
local infiniteJumpConnection = nil
local isInfiniteJumpOn = false

ToolsTab:Toggle({
	Title = "Infinite Jump",
	Desc = "Jump in mid-air",
	Default = false,
	Callback = function(state)
		isInfiniteJumpOn = state

		if isInfiniteJumpOn then
			infiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
				local hum = GetHumanoid()
				if hum then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end)

			WindUI:Notify({
				Title = "Infinite Jump",
				Content = "Infinite Jump enabled!",
				Duration = 2,
			})
		else
			if infiniteJumpConnection then
				infiniteJumpConnection:Disconnect()
				infiniteJumpConnection = nil
			end

			WindUI:Notify({
				Title = "Infinite Jump",
				Content = "Infinite Jump disabled.",
				Duration = 2,
			})
		end
	end,
})

ToolsTab:Divider()

-- 🚀 TELEPORT
ToolsTab:Section({ Title = "🚀 Teleportation", TextSize = 20 })

ToolsTab:Dropdown({
	Title = "Teleport to Player",
	Desc = "Select target player",
	Values = (function()
		local list = {}
		for _, p in pairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then
				table.insert(list, p.Name)
			end
		end
		return list
	end)(),
	Callback = function(selected)
		local target = Players:FindFirstChild(selected)
		if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local hrp = GetHRP()
			if hrp then
				hrp.CFrame = target.Character.HumanoidRootPart.CFrame
				WindUI:Notify({ Title = "Teleported", Content = "To " .. selected, Duration = 2 })
			end
		end
	end,
})

ToolsTab:Button({
	Title = "Click Teleport",
	Desc = "Teleport to mouse click position",
	Callback = function()
		local mouse = LocalPlayer:GetMouse()
		if mouse.Hit then
			local hrp = GetHRP()
			if hrp then
				hrp.CFrame = mouse.Hit + Vector3.new(0, 3, 0)
			end
		end
	end,
})

ToolsTab:Divider()

-- ✈️ FLY
ToolsTab:Section({ Title = "✈️ Flight Mode", TextSize = 20 })

local isFlying = false
local flyConnection = nil
local flySpeed = 50

ToolsTab:Toggle({
	Title = "Enable Fly",
	Desc = "Toggle flight",
	Default = false,
	Callback = function(state)
		isFlying = state
		local hrp = GetHRP()

		if state then
			if hrp then
				local bodyVel = Instance.new("BodyVelocity")
				bodyVel.Name = "StarshipFly"
				bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
				bodyVel.Velocity = Vector3.new(0, 0, 0)
				bodyVel.Parent = hrp

				local bodyGyro = Instance.new("BodyGyro")
				bodyGyro.Name = "StarshipGyro"
				bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
				bodyGyro.P = 9000
				bodyGyro.Parent = hrp

				flyConnection = RunService.Heartbeat:Connect(function()
					if isFlying and hrp and hrp:FindFirstChild("StarshipFly") then
						local vel = Vector3.new(0, 0, 0)
						local cam = workspace.CurrentCamera
						local look = cam.CFrame.LookVector
						local right = cam.CFrame.RightVector

						if UserInputService:IsKeyDown(Enum.KeyCode.W) then
							vel = vel + look
						end
						if UserInputService:IsKeyDown(Enum.KeyCode.S) then
							vel = vel - look
						end
						if UserInputService:IsKeyDown(Enum.KeyCode.A) then
							vel = vel - right
						end
						if UserInputService:IsKeyDown(Enum.KeyCode.D) then
							vel = vel + right
						end
						if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
							vel = vel + Vector3.new(0, 1, 0)
						end
						if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
							vel = vel - Vector3.new(0, 1, 0)
						end

						if vel.Magnitude > 0 then
							vel = vel.Unit * flySpeed
						end

						hrp.StarshipFly.Velocity = vel
						hrp.StarshipGyro.CFrame = cam.CFrame
					end
				end)
			end
		else
			if flyConnection then
				flyConnection:Disconnect()
				flyConnection = nil
			end
			if hrp then
				for _, c in pairs(hrp:GetChildren()) do
					if c.Name == "StarshipFly" or c.Name == "StarshipGyro" then
						c:Destroy()
					end
				end
			end
		end
	end,
})

ToolsTab:Slider({
	Title = "Fly Speed",
	Desc = "Speed (Default: 50)",
	Step = 5,
	Value = { Min = 10, Max = 300, Default = 50 },
	Callback = function(v)
		flySpeed = v
	end,
})

ToolsTab:Divider()

ToolsTab:Button({
	Title = "💀 Reset Character",
	Callback = function()
		local hum = GetHumanoid()
		if hum then
			hum.Health = 0
		end
	end,
})

ToolsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 📊 SPEED CHECKER
-- ══════════════════════════════════════════════════════════════════
ToolsTab:Section({ Title = "📊 Speed Checker", TextSize = 20 })

local speedDisplayGui = nil
local speedDisplayConnection = nil
local isSpeedDisplayOn = false

local function CreateSpeedDisplayMobile()
	if speedDisplayGui then
		speedDisplayGui:Destroy()
	end

	local parent
	local success, cGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if success and cGui then
		parent = cGui
	else
		parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "StarshipSpeedDisplay"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 999998
	screen.IgnoreGuiInset = true
	screen.Parent = parent

	local frame = Instance.new("Frame")
	frame.Name = "SpeedFrame"
	frame.Size = UDim2.fromOffset(140, 70)
	frame.Position = UDim2.new(0.5, -70, 0, 50)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Draggable = true
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(99, 102, 241)
	stroke.Thickness = 2
	stroke.Parent = frame

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Text = "WALKSPEED"
	titleLbl.Size = UDim2.new(1, 0, 0, 16)
	titleLbl.Position = UDim2.new(0, 0, 0, 6)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3 = Color3.fromRGB(150, 150, 160)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 9
	titleLbl.Parent = frame

	local speedLbl = Instance.new("TextLabel")
	speedLbl.Name = "SpeedValue"
	speedLbl.Text = "0"
	speedLbl.Size = UDim2.new(1, 0, 0, 28)
	speedLbl.Position = UDim2.new(0, 0, 0, 22)
	speedLbl.BackgroundTransparency = 1
	speedLbl.TextColor3 = Color3.fromRGB(99, 102, 241)
	speedLbl.Font = Enum.Font.GothamBold
	speedLbl.TextSize = 24
	speedLbl.Parent = frame

	local unitLbl = Instance.new("TextLabel")
	unitLbl.Text = "(default: 16)"
	unitLbl.Size = UDim2.new(1, 0, 0, 12)
	unitLbl.Position = UDim2.new(0, 0, 0, 50)
	unitLbl.BackgroundTransparency = 1
	unitLbl.TextColor3 = Color3.fromRGB(120, 120, 130)
	unitLbl.Font = Enum.Font.Gotham
	unitLbl.TextSize = 9
	unitLbl.Parent = frame

	return screen, frame
end

ToolsTab:Toggle({
	Title = "Speed Display",
	Desc = "Show current walkspeed on screen",
	Default = false,
	Callback = function(state)
		isSpeedDisplayOn = state

		if isSpeedDisplayOn then
			local screen, frame = CreateSpeedDisplayMobile()
			speedDisplayGui = screen

			speedDisplayConnection = RunService.Heartbeat:Connect(function()
				local hum = GetHumanoid()
				if hum and speedDisplayGui then
					local speed = hum.WalkSpeed
					local speedLbl = speedDisplayGui:FindFirstChild("SpeedFrame")
					if speedLbl then
						speedLbl = speedLbl:FindFirstChild("SpeedValue")
					end
					if speedLbl then
						speedLbl.Text = string.format("%.0f", speed)
						if speed <= 16 then
							speedLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
						elseif speed <= 30 then
							speedLbl.TextColor3 = Color3.fromRGB(34, 197, 94)
						elseif speed <= 60 then
							speedLbl.TextColor3 = Color3.fromRGB(234, 179, 8)
						else
							speedLbl.TextColor3 = Color3.fromRGB(239, 68, 68)
						end
					end
				end
			end)

			WindUI:Notify({
				Title = "Speed Display",
				Content = "Speed display enabled!",
				Duration = 2,
			})
		else
			if speedDisplayConnection then
				speedDisplayConnection:Disconnect()
				speedDisplayConnection = nil
			end
			if speedDisplayGui then
				speedDisplayGui:Destroy()
				speedDisplayGui = nil
			end

			WindUI:Notify({
				Title = "Speed Display",
				Content = "Speed display disabled.",
				Duration = 2,
			})
		end
	end,
})

ToolsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🔒 SHIFT LOCK
-- ══════════════════════════════════════════════════════════════════
ToolsTab:Section({ Title = "🔒 Shift Lock", TextSize = 20 })

local isShiftLockOn = false
local shiftLockConnection = nil

ToolsTab:Toggle({
	Title = "Shift Lock",
	Desc = "Lock camera behind character",
	Default = false,
	Callback = function(state)
		isShiftLockOn = state

		if isShiftLockOn then
			shiftLockConnection = RunService.RenderStepped:Connect(function()
				local char = GetCharacter()
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChild("Humanoid")
				if root and hum then
					hum.AutoRotate = false
					UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

					local cam = workspace.CurrentCamera
					local look = cam.CFrame.LookVector
					root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
				end
			end)

			WindUI:Notify({
				Title = "Shift Lock",
				Content = "Shift Lock enabled!",
				Duration = 2,
			})
		else
			if shiftLockConnection then
				shiftLockConnection:Disconnect()
				shiftLockConnection = nil
			end
			local char = GetCharacter()
			local hum = char and char:FindFirstChild("Humanoid")
			if hum then
				hum.AutoRotate = true
			end
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default

			WindUI:Notify({
				Title = "Shift Lock",
				Content = "Shift Lock disabled.",
				Duration = 2,
			})
		end
	end,
})

ToolsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🎭 STREAMER MODE (Privacy)
-- ══════════════════════════════════════════════════════════════════
ToolsTab:Section({ Title = "🎭 Streamer Mode", TextSize = 20 })

local isStreamerMode = false
local streamerSpoofConnections = {}
local originalTexts = {}
local spoofedUsername = ""
local spoofedDisplayName = ""

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
	"Gamer",
	"Champion",
	"Warrior",
}
local randomSuffixes = { "123", "456", "789", "007", "999", "101", "XD", "_YT", "_TTV", "" }

local function SpoofAllNames()
	local fakeName = spoofedUsername ~= "" and spoofedUsername or "Player"
	local fakeDisplay = spoofedDisplayName ~= "" and spoofedDisplayName or fakeName
	local realName = LocalPlayer.Name
	local realDisplay = LocalPlayer.DisplayName

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

	pcall(function()
		local playerList = game:GetService("CoreGui"):FindFirstChild("PlayerList")
		if playerList then
			SpoofGui(playerList)
		end
	end)

	if LocalPlayer:FindFirstChild("PlayerGui") then
		SpoofGui(LocalPlayer.PlayerGui)
	end

	if LocalPlayer.Character then
		SpoofCharacter(LocalPlayer.Character)
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
end

ToolsTab:Input({
	Title = "Fake Username",
	Desc = "Your spoofed username",
	Placeholder = "Enter fake name...",
	Callback = function(text)
		spoofedUsername = text
		if isStreamerMode then
			SpoofAllNames()
		end
	end,
})

ToolsTab:Input({
	Title = "Fake Display Name",
	Desc = "Your spoofed display name",
	Placeholder = "Enter fake display...",
	Callback = function(text)
		spoofedDisplayName = text
		if isStreamerMode then
			SpoofAllNames()
		end
	end,
})

ToolsTab:Button({
	Title = "🎲 Random Name",
	Desc = "Generate a random fake name",
	Callback = function()
		local name = randomNames[math.random(#randomNames)] .. randomSuffixes[math.random(#randomSuffixes)]
		spoofedUsername = name
		spoofedDisplayName = name
		WindUI:Notify({
			Title = "Random Name",
			Content = "Generated: " .. name,
			Duration = 2,
		})
		if isStreamerMode then
			SpoofAllNames()
		end
	end,
})

ToolsTab:Toggle({
	Title = "Enable Streamer Mode",
	Desc = "Spoof your name (client-side only)",
	Default = false,
	Callback = function(state)
		isStreamerMode = state

		if isStreamerMode then
			SpoofAllNames()

			local lastSpoof = 0
			local spoofLoop = RunService.Heartbeat:Connect(function()
				if isStreamerMode and tick() - lastSpoof > 1 then
					lastSpoof = tick()
					SpoofAllNames()
				end
			end)
			table.insert(streamerSpoofConnections, spoofLoop)

			local charCon = LocalPlayer.CharacterAdded:Connect(function(char)
				task.wait(1)
				if isStreamerMode then
					SpoofAllNames()
				end
			end)
			table.insert(streamerSpoofConnections, charCon)

			WindUI:Notify({
				Title = "Streamer Mode",
				Content = "Name spoofing enabled!",
				Duration = 3,
			})
		else
			for _, con in pairs(streamerSpoofConnections) do
				if con then
					pcall(function()
						con:Disconnect()
					end)
				end
			end
			streamerSpoofConnections = {}
			RestoreAllNames()

			WindUI:Notify({
				Title = "Streamer Mode",
				Content = "Name spoofing disabled.",
				Duration = 2,
			})
		end
	end,
})

ToolsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🌌 SKYBOX CHANGER
-- ══════════════════════════════════════════════════════════════════
ToolsTab:Section({ Title = "🌌 Skybox Changer", TextSize = 20 })

local originalSky = nil
local originalAtmosphere = nil
local currentSkybox = "Default"
local skyboxBypassConnection = nil

local SkyboxPresets = {
	["Default"] = nil,
	["Galaxy Night"] = {
		SkyboxBk = "rbxassetid://159454286",
		SkyboxDn = "rbxassetid://159454296",
		SkyboxFt = "rbxassetid://159454299",
		SkyboxLf = "rbxassetid://159454286",
		SkyboxRt = "rbxassetid://159454291",
		SkyboxUp = "rbxassetid://159454293",
		StarCount = 5000,
	},
	["Blood Red"] = {
		SkyboxBk = "rbxassetid://1012890",
		SkyboxDn = "rbxassetid://1012891",
		SkyboxFt = "rbxassetid://1012887",
		SkyboxLf = "rbxassetid://1012889",
		SkyboxRt = "rbxassetid://1012888",
		SkyboxUp = "rbxassetid://1014449",
		StarCount = 500,
	},
	["Scary Red"] = {
		SkyboxBk = "rbxassetid://108929045660200",
		SkyboxDn = "rbxassetid://78646480540009",
		SkyboxFt = "rbxassetid://90546017435179",
		SkyboxLf = "rbxassetid://109838453114563",
		SkyboxRt = "rbxassetid://94190734796082",
		SkyboxUp = "rbxassetid://126944775797063",
	},
	["Skybox HD"] = {
		SkyboxBk = "rbxassetid://16553658937",
		SkyboxDn = "rbxassetid://16553660713",
		SkyboxFt = "rbxassetid://16553662144",
		SkyboxLf = "rbxassetid://16553664042",
		SkyboxRt = "rbxassetid://16553665766",
		SkyboxUp = "rbxassetid://16553667750",
		StarCount = 3000,
	},
	["Night City"] = {
		SkyboxBk = "rbxassetid://163897885",
		SkyboxDn = "rbxassetid://163898013",
		SkyboxFt = "rbxassetid://163899342",
		SkyboxLf = "rbxassetid://163897886",
		SkyboxRt = "rbxassetid://163897887",
		SkyboxUp = "rbxassetid://163898013",
		StarCount = 5000,
	},
}

local function CaptureOriginalSky()
	if originalSky then
		return
	end
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
		}
	end
	originalAtmosphere = lighting.Ambient
end

local function StopSkyboxBypass()
	if skyboxBypassConnection then
		skyboxBypassConnection:Disconnect()
		skyboxBypassConnection = nil
	end
end

local function ApplySkyboxWithBypass(preset)
	local lighting = game:GetService("Lighting")

	skyboxBypassConnection = RunService.Heartbeat:Connect(function()
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
	end)
end

local function ApplySkybox(presetName)
	local lighting = game:GetService("Lighting")
	CaptureOriginalSky()
	StopSkyboxBypass()

	local preset = SkyboxPresets[presetName]

	if presetName == "Default" then
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

	if not preset then
		return
	end

	local sky = lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Parent = lighting
	end

	sky.SkyboxBk = preset.SkyboxBk
	sky.SkyboxDn = preset.SkyboxDn
	sky.SkyboxFt = preset.SkyboxFt
	sky.SkyboxLf = preset.SkyboxLf
	sky.SkyboxRt = preset.SkyboxRt
	sky.SkyboxUp = preset.SkyboxUp
	sky.StarCount = preset.StarCount or 0

	ApplySkyboxWithBypass(preset)
	currentSkybox = presetName
end

local skyboxOptions = { "Default", "Galaxy Night", "Blood Red", "Scary Red", "Skybox HD", "Night City" }

ToolsTab:Dropdown({
	Title = "Select Skybox",
	Desc = "Change the sky appearance",
	Values = skyboxOptions,
	Callback = function(selected)
		ApplySkybox(selected)
		WindUI:Notify({
			Title = "Skybox Changed",
			Content = "Applied: " .. selected,
			Duration = 2,
		})
	end,
})

ToolsTab:Button({
	Title = "🔄 Reset Skybox",
	Desc = "Restore original skybox",
	Callback = function()
		ApplySkybox("Default")
		WindUI:Notify({
			Title = "Skybox Reset",
			Content = "Restored to original skybox.",
			Duration = 2,
		})
	end,
})

local ListMapTab = Window:Tab({
	Title = "Auto Walk",
	Icon = "folder-open",
})

-- Constants for Playback
local HttpService = game:GetService("HttpService")
local FOLDER_NAME = "StarshipCore"
local MERGER_FOLDER = FOLDER_NAME .. "/StarshipMerger"

-- Create folders if not exist (with error handling)
local folderStatus = "Unknown"
pcall(function()
	if isfolder then
		if not isfolder(FOLDER_NAME) then
			makefolder(FOLDER_NAME)
		end
		if not isfolder(MERGER_FOLDER) then
			makefolder(MERGER_FOLDER)
		end
		folderStatus = isfolder(MERGER_FOLDER) and "OK" or "Failed"
	else
		folderStatus = "No File API"
	end
end)

-- Playback State
local PlaybackState = {
	isPlaying = false,
	isPaused = false,
	currentFile = nil,
	frameData = nil,
	currentTime = 0,
	totalDuration = 0,
	speed = 1,
	strictRetarget = false,
	nativeAnim = false,
	isLooping = false,
	connection = nil,
	lastFrameIndex = 1,
	lastPlaybackTime = 0,
	isFlexible = false,
	isRespawnOnEnd = false,
	isSpinning = false,
	jointMap = {},
}

-- Spin Logic
local RunService = game:GetService("RunService")
RunService.RenderStepped:Connect(function(dt)
	if PlaybackState.isSpinning and PlaybackState.isPlaying and not PlaybackState.isPaused then
		local char = GetCharacter()
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChild("Humanoid")

		if hrp and hum then
			local state = hum:GetState()
			local isAir = (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping)

			if isAir then
				hum.AutoRotate = false
				local spinSpeed = 12
				local spinRot = CFrame.Angles(0, spinSpeed * dt, 0)
				local cam = workspace.CurrentCamera
				if cam then
					local relCam = hrp.CFrame:ToObjectSpace(cam.CFrame)
					hrp.CFrame = hrp.CFrame * spinRot
					cam.CFrame = hrp.CFrame:ToWorldSpace(relCam)
				else
					hrp.CFrame = hrp.CFrame * spinRot
				end
			end
		end
	end
end)

-- File List
local mergedFiles = {}
local currentSearchQuery = ""

-- Function to refresh file list
local function RefreshFileList()
	mergedFiles = {}
	if listfiles and isfolder(MERGER_FOLDER) then
		local allFiles = listfiles(MERGER_FOLDER)
		for _, filePath in ipairs(allFiles) do
			if string.sub(filePath, -5) == ".json" then
				local fileName = string.match(filePath, "[^/\\]+$") or filePath
				table.insert(mergedFiles, fileName)
			end
		end
		-- Natural sort (handle numbers properly)
		local function padZero(num)
			local s = tostring(num)
			while string.len(s) < 10 do
				s = "0" .. s
			end
			return s
		end

		local sortable = {}
		for i, fn in ipairs(mergedFiles) do
			local baseName = string.gsub(fn, "%.json$", "")
			local numPart = string.match(baseName, "(%d+)$")
			local sortKey
			if numPart and string.len(numPart) > 0 then
				local prefixLen = string.len(baseName) - string.len(numPart)
				local prefix = string.sub(baseName, 1, prefixLen)
				sortKey = "1" .. string.lower(prefix) .. padZero(tonumber(numPart) or 0)
			else
				sortKey = "0" .. string.lower(baseName) .. padZero(0)
			end
			table.insert(sortable, { name = fn, key = sortKey })
		end

		table.sort(sortable, function(a, b)
			return a.key < b.key
		end)

		mergedFiles = {}
		for _, v in ipairs(sortable) do
			table.insert(mergedFiles, v.name)
		end
	end
	return mergedFiles
end

-- Function to get dropdown options
local function GetFileOptions()
	RefreshFileList()
	if #mergedFiles == 0 then
		return { "No files found" }
	end
	return mergedFiles
end

-- Function to get files that match search query
local function GetMatchingFilesByQuery(query)
	-- Selalu ambil list file terbaru
	local files = RefreshFileList()
	if not files or #files == 0 then
		return {}
	end

	if not query or query == "" then
		return files
	end

	-- Trim dan lowercase query
	query = tostring(query or "")
	query = string.lower(query:match("^%s*(.-)%s*$"))
	if query == "" then
		return files
	end

	local results = {}
	for _, file in ipairs(files) do
		local name = string.lower(tostring(file))
		if string.find(name, query, 1, true) then
			table.insert(results, file)
		end
	end
	return results
end

-- ═══════════════════════════════════════════════════════════════════
-- PLAYBACK ENGINE (Based on StarshipCore.lua)
-- ═══════════════════════════════════════════════════════════════════

-- SMOOTHING SETTINGS (Default values - no UI adjustment on mobile)
local SMOOTH_SETTINGS = {
	LiveSmoothingEnabled = true, -- Auto-smooth on load
	LiveSmoothingStrength = 5, -- Default strength (1-10)
	PositionBasedEnabled = true, -- Position-based playback for smoother ground movement
}

-- ═══════════════════════════════════════════════════════════════════
-- SMOOTHING FUNCTIONS (Same as PC StarshipCore.lua)
-- ═══════════════════════════════════════════════════════════════════

-- Deep copy function
local function DeepCopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
		end
		setmetatable(copy, DeepCopy(getmetatable(orig)))
	else
		copy = orig
	end
	return copy
end

-- Catmull-Rom Spline Interpolation for ultra-smooth curves
local function CatmullRomSpline(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

-- Catmull-Rom for Vector3
local function CatmullRomVector3(v0, v1, v2, v3, t)
	return Vector3.new(
		CatmullRomSpline(v0.X, v1.X, v2.X, v3.X, t),
		CatmullRomSpline(v0.Y, v1.Y, v2.Y, v3.Y, t),
		CatmullRomSpline(v0.Z, v1.Z, v2.Z, v3.Z, t)
	)
end

-- Smooth interpolation between frames using Catmull-Rom (requires 4 frames context)
local function SmoothInterpolateFrames(frames, frameIdx, alpha)
	local n = #frames
	if n < 2 then
		return nil, nil
	end

	-- Get 4 frames for Catmull-Rom (clamp at boundaries)
	local i0 = math.max(1, frameIdx - 1)
	local i1 = frameIdx
	local i2 = math.min(n, frameIdx + 1)
	local i3 = math.min(n, frameIdx + 2)

	local f0, f1, f2, f3 = frames[i0], frames[i1], frames[i2], frames[i3]

	-- Interpolate position with Catmull-Rom
	local smoothPos = nil
	if f0.pos and f1.pos and f2.pos and f3.pos then
		local p0 = Vector3.new(f0.pos.x, f0.pos.y, f0.pos.z)
		local p1 = Vector3.new(f1.pos.x, f1.pos.y, f1.pos.z)
		local p2 = Vector3.new(f2.pos.x, f2.pos.y, f2.pos.z)
		local p3 = Vector3.new(f3.pos.x, f3.pos.y, f3.pos.z)
		smoothPos = CatmullRomVector3(p0, p1, p2, p3, alpha)
	elseif f1.pos and f2.pos then
		-- Fallback to linear lerp
		local p1 = Vector3.new(f1.pos.x, f1.pos.y, f1.pos.z)
		local p2 = Vector3.new(f2.pos.x, f2.pos.y, f2.pos.z)
		smoothPos = p1:Lerp(p2, alpha)
	end

	-- Interpolate velocity with Catmull-Rom (smoother acceleration)
	local smoothVel = nil
	if f0.vel and f1.vel and f2.vel and f3.vel then
		local v0 = Vector3.new(f0.vel.x, f0.vel.y, f0.vel.z)
		local v1 = Vector3.new(f1.vel.x, f1.vel.y, f1.vel.z)
		local v2 = Vector3.new(f2.vel.x, f2.vel.y, f2.vel.z)
		local v3 = Vector3.new(f3.vel.x, f3.vel.y, f3.vel.z)
		smoothVel = CatmullRomVector3(v0, v1, v2, v3, alpha)
	elseif f1.vel and f2.vel then
		-- Fallback to linear lerp
		local v1 = Vector3.new(f1.vel.x, f1.vel.y, f1.vel.z)
		local v2 = Vector3.new(f2.vel.x, f2.vel.y, f2.vel.z)
		smoothVel = v1:Lerp(v2, alpha)
	end

	return smoothPos, smoothVel
end

-- Gaussian weight calculation for smooth falloff
local function GaussianWeight(distance, sigma)
	return math.exp(-(distance * distance) / (2 * sigma * sigma))
end

-- Gaussian-weighted smoothing for frames (runs once on load)
local function GetSmoothedFrames(frames, strength, isFlexible)
	local processedFrames = DeepCopy(frames)
	local iterations = math.clamp(strength or 1, 1, 10)
	local kernelRadius = math.clamp(math.ceil(strength / 2), 1, 5)
	local sigma = kernelRadius / 2

	for iter = 1, iterations do
		local tempFrames = DeepCopy(processedFrames)

		for i = 2, #processedFrames - 1 do
			local curr = processedFrames[i]

			if isFlexible then
				-- Gaussian-weighted position smoothing
				if curr.pos then
					local weightSum = 0
					local posSum = Vector3.new(0, 0, 0)

					for j = math.max(1, i - kernelRadius), math.min(#tempFrames, i + kernelRadius) do
						local neighbor = tempFrames[j]
						if neighbor.pos then
							local dist = math.abs(j - i)
							local weight = GaussianWeight(dist, sigma)
							local neighborPos = Vector3.new(neighbor.pos.x, neighbor.pos.y, neighbor.pos.z)
							posSum = posSum + neighborPos * weight
							weightSum = weightSum + weight
						end
					end

					if weightSum > 0 then
						local smoothedPos = posSum / weightSum
						local currPos = Vector3.new(curr.pos.x, curr.pos.y, curr.pos.z)
						local finalPos = currPos:Lerp(smoothedPos, 0.7)
						curr.pos.x = finalPos.X
						curr.pos.y = finalPos.Y
						curr.pos.z = finalPos.Z
					end
				end

				-- Gaussian-weighted velocity smoothing
				if curr.vel then
					local weightSum = 0
					local velSum = Vector3.new(0, 0, 0)

					for j = math.max(1, i - kernelRadius), math.min(#tempFrames, i + kernelRadius) do
						local neighbor = tempFrames[j]
						if neighbor.vel then
							local dist = math.abs(j - i)
							local weight = GaussianWeight(dist, sigma)
							local neighborVel = Vector3.new(neighbor.vel.x, neighbor.vel.y, neighbor.vel.z)
							velSum = velSum + neighborVel * weight
							weightSum = weightSum + weight
						end
					end

					if weightSum > 0 then
						local smoothedVel = velSum / weightSum
						local currVel = Vector3.new(curr.vel.x, curr.vel.y, curr.vel.z)
						local finalVel = currVel:Lerp(smoothedVel, 0.8)
						curr.vel.x = finalVel.X
						curr.vel.y = finalVel.Y
						curr.vel.z = finalVel.Z
					end
				end
			end
		end
	end
	return processedFrames
end

-- ═══════════════════════════════════════════════════════════════════
-- CORE PLAYBACK FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

-- Convert table to CFrame
local function TblToCF(t)
	if not t then
		return CFrame.new()
	end
	-- Standard mode format: {p={x,y,z}, o={x,y,z}}
	if t.p and t.o then
		return CFrame.new(t.p.x, t.p.y, t.p.z) * CFrame.Angles(t.o.x, t.o.y, t.o.z)
		-- Flexible mode root: {pos={x,y,z}, rot=yaw}
	elseif t.pos then
		local yaw = t.rot or 0
		return CFrame.new(t.pos.x, t.pos.y, t.pos.z) * CFrame.Angles(0, math.rad(yaw), 0)
		-- Raw CFrame array
	elseif type(t) == "table" and #t >= 12 then
		return CFrame.new(unpack(t))
	end
	return CFrame.new()
end

-- Binary search for frame index (optimized)
local function FindFrameIndex(frames, targetTime, hint)
	local n = #frames
	if n < 2 then
		return 1
	end

	-- Use hint for nearby search first
	if hint and hint >= 1 and hint < n then
		for offset = 0, 5 do
			local idx = hint + offset
			if idx >= 1 and idx < n then
				if frames[idx].t <= targetTime and frames[idx + 1].t >= targetTime then
					return idx
				end
			end
			idx = hint - offset
			if idx >= 1 and idx < n then
				if frames[idx].t <= targetTime and frames[idx + 1].t >= targetTime then
					return idx
				end
			end
		end
	end

	-- Binary search for large jumps
	local lo, hi = 1, n - 1
	while lo <= hi do
		local mid = math.floor((lo + hi) / 2)
		if frames[mid].t <= targetTime and frames[mid + 1].t >= targetTime then
			return mid
		elseif frames[mid].t > targetTime then
			hi = mid - 1
		else
			lo = mid + 1
		end
	end
	return math.clamp(lo, 1, n - 1)
end

-- Get all Motor6D joints
local function GetJoints(char)
	local joints = {}
	for _, d in pairs(char:GetDescendants()) do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		end
	end
	return joints
end

-- Reset character state
local function ResetCharacter()
	local char = GetCharacter()
	if not char then
		return
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = false
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		-- Remove playback constraints
		if hrp:FindFirstChild("PlaybackAtt") then
			hrp.PlaybackAtt:Destroy()
		end
		if hrp:FindFirstChild("PlaybackAO") then
			hrp.PlaybackAO:Destroy()
		end
		if hrp:FindFirstChild("PlaybackAP") then
			hrp.PlaybackAP:Destroy()
		end
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
		hum.PlatformStand = false
		for _, track in pairs(hum:GetPlayingAnimationTracks()) do
			track:Stop()
		end
		if hrp then
			hum:MoveTo(hrp.Position)
		end
	end

	local animate = char:FindFirstChild("Animate")
	if animate then
		animate.Disabled = true
		task.wait()
		animate.Disabled = false
	end
end

-- Stop playback
local function StopPlayback()
	PlaybackState.isPlaying = false
	PlaybackState.isPaused = false
	PlaybackState.currentTime = 0
	PlaybackState.lastFrameIndex = 1

	if PlaybackState.connection then
		PlaybackState.connection:Disconnect()
		PlaybackState.connection = nil
	end

	ResetCharacter()
end

-- Play recording (main function)
local function PlayRecording(fileName, force)
	if not fileName or fileName == "No files found" then
		WindUI:Notify({ Title = "Error", Content = "No file selected!", Duration = 2 })
		return
	end

	-- If already playing the same file and not paused, ignore (prevent double play)
	if PlaybackState.isPlaying and PlaybackState.currentFile == fileName and not force then
		-- Already playing, do nothing
		return
	end

	-- Check if this is a cloud recording
	local isCloudRecording = string.sub(fileName, 1, 6) == "CLOUD:"
	local data = nil

	if isCloudRecording then
		-- Load from memory (CloudRecordingData)
		if not CloudRecordingData then
			WindUI:Notify({ Title = "Error", Content = "Cloud recording not loaded!", Duration = 2 })
			return
		end
		data = CloudRecordingData
		WindUI:Notify({ Title = "Loading", Content = "Preparing cloud recording...", Duration = 1.5 })
	else
		-- Load from file (original behavior)
		local filePath = MERGER_FOLDER .. "/" .. fileName
		if not isfile or not isfile(filePath) then
			WindUI:Notify({ Title = "Error", Content = "File not found!", Duration = 2 })
			return
		end

		WindUI:Notify({ Title = "Loading", Content = "Preparing " .. fileName .. "...", Duration = 1.5 })
		task.wait(0.1)

		local success, content = pcall(readfile, filePath)
		if not success then
			WindUI:Notify({ Title = "Error", Content = "Failed to read file!", Duration = 2 })
			return
		end

		data = HttpService:JSONDecode(content)
	end

	task.wait(0.1)

	local isResuming = (PlaybackState.currentFile == fileName and not force and PlaybackState.isPaused)

	-- Load file data if different file or forced
	if PlaybackState.currentFile ~= fileName or force or not PlaybackState.frameData then
		StopPlayback()

		local framesToPlay = data.Frames or data

		-- Detect mode: Flexible (has vel/pos) or Standard (has r/j)
		local isFlexible = (data.Mode == "Flexible") or (framesToPlay[1] and framesToPlay[1].vel ~= nil)

		-- LIVE SMOOTHING: Apply Gaussian smoothing on load (mobile default ON)
		if SMOOTH_SETTINGS.LiveSmoothingEnabled and isFlexible and #framesToPlay > 3 then
			WindUI:Notify({ Title = "Smoothing", Content = "Applying auto-smooth...", Duration = 1 })
			task.wait()
			framesToPlay = GetSmoothedFrames(framesToPlay, SMOOTH_SETTINGS.LiveSmoothingStrength, isFlexible)
		end

		PlaybackState.frameData = framesToPlay
		PlaybackState.currentFile = fileName
		PlaybackState.currentTime = 0
		PlaybackState.lastFrameIndex = 1

		-- Detect mode: Flexible (has vel/pos) or Standard (has r/j)
		PlaybackState.isFlexible = (data.Mode == "Flexible") or (framesToPlay[1] and framesToPlay[1].vel ~= nil)

		if #PlaybackState.frameData > 0 then
			PlaybackState.totalDuration = PlaybackState.frameData[#PlaybackState.frameData].t or 0
		end
	elseif PlaybackState.currentTime >= (PlaybackState.totalDuration - 0.1) then
		-- Reset if at end (replay)
		PlaybackState.currentTime = 0
	end

	if not PlaybackState.frameData or #PlaybackState.frameData < 2 then
		WindUI:Notify({ Title = "Error", Content = "Invalid recording data!", Duration = 2 })
		return
	end

	local char = GetCharacter()
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animate = char and char:FindFirstChild("Animate")

	if not hrp or not hum then
		WindUI:Notify({ Title = "Error", Content = "Character not found!", Duration = 2 })
		return
	end

	-- NOTE: We don't return early for resume anymore
	-- Resume will also do smart start and travel phase (SAME AS PC)

	-- Cache joints for Standard mode
	PlaybackState.jointMap = GetJoints(char)

	-- SMART START / SMART RESUME: Always find nearest position (SAME AS PC)
	-- This ensures play from nearest path point after stop
	WindUI:Notify({ Title = "Finding Position", Content = "Locating nearest path point...", Duration = 1 })

	local bestT, minDist = PlaybackState.currentTime, math.huge
	local rPos = hrp.Position

	-- Optimization: Step by frames to save performance on huge files
	local step = math.max(1, math.floor(#PlaybackState.frameData / 500))

	for i = 1, #PlaybackState.frameData, step do
		local f = PlaybackState.frameData[i]
		local pos
		if f.pos then
			pos = Vector3.new(f.pos.x, f.pos.y, f.pos.z)
		elseif f.r then
			pos = TblToCF(f.r).Position
		end

		if pos then
			local dist = (rPos - pos).Magnitude
			if dist < minDist then
				minDist = dist
				bestT = f.t
			end
		end
	end

	-- Also check the last frame explicitly
	local lastF = PlaybackState.frameData[#PlaybackState.frameData]
	local lastPos
	if lastF.pos then
		lastPos = Vector3.new(lastF.pos.x, lastF.pos.y, lastF.pos.z)
	elseif lastF.r then
		lastPos = TblToCF(lastF.r).Position
	end
	if lastPos then
		local dist = (rPos - lastPos).Magnitude
		if dist < minDist then
			minDist = dist
			bestT = lastF.t
		end
	end

	-- Smart position logic (SAME AS PC)
	-- If the nearest point is within the last 2 seconds, force restart from 0
	if bestT >= (PlaybackState.totalDuration - 2.0) then
		PlaybackState.currentTime = 0
		-- Snap to Start: If nearest point is within first 1 second, start from 0
	elseif bestT < 1.0 then
		PlaybackState.currentTime = 0
		-- Otherwise, jump to nearest point if close enough to path
	elseif minDist < 500 then
		PlaybackState.currentTime = bestT
		WindUI:Notify({
			Title = "Smart Start",
			Content = string.format("Starting from %.1fs (%.0f studs away)", bestT, minDist),
			Duration = 2,
		})
	else
		PlaybackState.currentTime = 0
	end

	-- Disconnect old connection if exists (important for resume)
	if PlaybackState.connection then
		PlaybackState.connection:Disconnect()
		PlaybackState.connection = nil
	end

	-- ═══════════════════════════════════════════════════════════════════
	-- TRAVEL PHASE: Walk to target position before playback (SAME AS PC)
	-- ═══════════════════════════════════════════════════════════════════
	local startFrame = PlaybackState.frameData[1]
	local targetPos

	-- Find target position based on currentPlaybackTime
	if PlaybackState.currentTime > 0 then
		for i = 1, #PlaybackState.frameData do
			if PlaybackState.frameData[i].t >= PlaybackState.currentTime then
				local f = PlaybackState.frameData[i]
				if f.pos then
					targetPos = Vector3.new(f.pos.x, f.pos.y, f.pos.z)
				elseif f.r then
					targetPos = TblToCF(f.r).Position
				end
				break
			end
		end
	else
		-- Start from beginning
		if startFrame.pos then
			targetPos = Vector3.new(startFrame.pos.x, startFrame.pos.y, startFrame.pos.z)
		elseif startFrame.r then
			targetPos = TblToCF(startFrame.r).Position
		end
	end

	-- Travel to target if far away
	if targetPos then
		-- Use horizontal distance to prevent getting stuck due to height differences
		local flatPos = hrp.Position * Vector3.new(1, 0, 1)
		local flatTarget = targetPos * Vector3.new(1, 0, 1)
		local dist = (flatPos - flatTarget).Magnitude

		if dist > 3 then
			-- Enable animate for walking
			hrp.Anchored = false
			if animate then
				animate.Disabled = false
			end
			hum.AutoRotate = true

			WindUI:Notify({
				Title = "Traveling",
				Content = string.format("Walking to path (%.0f studs)...", dist),
				Duration = 3,
			})

			hum:MoveTo(targetPos)

			-- Timeout safety
			local moveStart = os.clock()
			local isWalking = true

			while isWalking do
				local currFlat = hrp.Position * Vector3.new(1, 0, 1)
				local d = (currFlat - flatTarget).Magnitude

				-- Close enough, start playback
				if d <= 2 then
					break
				end

				-- If stuck for 5 seconds but close (within 10 studs), just snap
				if os.clock() - moveStart > 5 and d < 10 then
					hrp.CFrame = CFrame.new(targetPos) * hrp.CFrame.Rotation
					break
				end

				-- Timeout after 10 seconds - snap anyway
				if os.clock() - moveStart > 10 then
					hrp.CFrame = CFrame.new(targetPos) * hrp.CFrame.Rotation
					WindUI:Notify({ Title = "Timeout", Content = "Teleported to path", Duration = 2 })
					break
				end

				-- Refresh MoveTo every second
				if math.floor(os.clock() - moveStart) % 1 < 0.1 then
					hum:MoveTo(targetPos)
				end

				task.wait(0.1)
			end

			-- Stop walking
			hum:MoveTo(hrp.Position)
		end
	end

	-- ═══════════════════════════════════════════════════════════════════
	-- PLAYBACK PHASE
	-- ═══════════════════════════════════════════════════════════════════
	PlaybackState.isPlaying = true
	PlaybackState.isPaused = false
	PlaybackState.lastPlaybackTime = PlaybackState.currentTime

	-- Variables for state tracking (same as PC)
	local lastAirState = nil
	local frameCounter = 0

	-- Create attachment for AlignOrientation (same as PC)
	local cachedAtt = hrp:FindFirstChild("PlaybackAtt") or Instance.new("Attachment", hrp)
	cachedAtt.Name = "PlaybackAtt"
	local cachedAO = nil

	WindUI:Notify({ Title = "Playing", Content = "Now playing: " .. fileName, Duration = 2 })

	-- Setup based on mode
	if PlaybackState.isFlexible then
		-- FLEXIBLE MODE (same as PC StarshipCore.lua)
		hrp.Anchored = false
		if animate then
			animate.Disabled = true
			task.wait()
			animate.Disabled = false
		end
		-- Don't set AutoRotate here, handle it per-frame like PC
		hum.AutoRotate = false

		PlaybackState.connection = RunService.Stepped:Connect(function(_, dt)
			frameCounter = frameCounter + 1
			if not PlaybackState.isPlaying or PlaybackState.isPaused then
				return
			end

			-- Ensure speed is always a number
			local speed = tonumber(PlaybackState.speed) or 1
			PlaybackState.speed = speed -- Update back to ensure it's number

			PlaybackState.currentTime = PlaybackState.currentTime + (dt * speed)

			-- Check end
			if PlaybackState.currentTime >= PlaybackState.totalDuration then
				if PlaybackState.isRespawnOnEnd then
					local savedFile = PlaybackState.currentFile
					local savedLoop = PlaybackState.isLooping
					StopPlayback()
					WindUI:Notify({ Title = "Respawn", Content = "Respawning in 5 seconds...", Duration = 5 })
					task.wait(5)
					local hum = GetHumanoid()
					if hum then
						hum.Health = 0
					end
					if savedLoop then
						task.spawn(function()
							LocalPlayer.CharacterAdded:Wait()
							WindUI:Notify({
								Title = "Loop",
								Content = "Restarting playback in 5 seconds...",
								Duration = 5,
							})
							task.wait(5)
							if savedFile then
								PlayRecording(savedFile, true)
							end
						end)
					end
					return
				elseif PlaybackState.isLooping then
					PlaybackState.currentTime = 0
					lastAirState = nil -- Reset on loop
				else
					StopPlayback()
					WindUI:Notify({ Title = "Finished", Content = "Playback completed!", Duration = 2 })
					return
				end
			end

			-- DETECT TIME JUMP (slider seeking) - skip blending if user jumped to different time
			local expectedDelta = dt * speed
			local actualDelta = math.abs(PlaybackState.currentTime - PlaybackState.lastPlaybackTime)
			local isTimeJump = actualDelta > (expectedDelta * 3 + 0.1)
			PlaybackState.lastPlaybackTime = PlaybackState.currentTime

			-- Find frames (optimized with binary search + caching)
			local frameIdx =
				FindFrameIndex(PlaybackState.frameData, PlaybackState.currentTime, PlaybackState.lastFrameIndex)
			PlaybackState.lastFrameIndex = frameIdx
			local fA, fB = PlaybackState.frameData[frameIdx], PlaybackState.frameData[frameIdx + 1]

			if fA and fB then
				local deltaT = fB.t - fA.t
				local alpha = 0
				if deltaT > 0.0001 then
					alpha = (PlaybackState.currentTime - fA.t) / deltaT
				end

				-- Tool Replication
				UpdateTool(GetCharacter(), fA.tool)

				-- 1. Check current state for special handling
				local isCurrentlyClimbing = false
				local isCurrentlySwimming = false
				local stateName = nil
				if fA.st then
					stateName = string.match(fA.st, "Enum%.HumanoidStateType%.(%w+)")
					isCurrentlyClimbing = (stateName == "Climbing")
					isCurrentlySwimming = (stateName == "Swimming")
				end

				if isCurrentlyClimbing or isCurrentlySwimming then
					-- CLIMBING/SWIMMING: Use recorded velocity and simulate input for natural animation
					local vel = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
						:Lerp(Vector3.new(fB.vel.x, fB.vel.y, fB.vel.z), alpha)
					vel = vel * speed

					-- FORCE climbing/swimming state FIRST (before any movement)
					hum:ChangeState(
						isCurrentlyClimbing and Enum.HumanoidStateType.Climbing or Enum.HumanoidStateType.Swimming
					)

					-- Apply movement input for animation
					if fA.md then
						local moveDir = Vector3.new(fA.md.x, fA.md.y, fA.md.z)
						hum:Move(moveDir)

						-- CRITICAL: Control climbing/swimming animation speed directly via AnimationTrack
						local animator = hum:FindFirstChildOfClass("Animator")
						if animator then
							local playingTracks = animator:GetPlayingAnimationTracks()
							for _, track in ipairs(playingTracks) do
								local animName = track.Animation and track.Animation.Name or ""
								local animNameLower = string.lower(animName)
								if animNameLower:find("climb") or animNameLower:find("swim") or track.IsPlaying then
									local baseSpeed = isCurrentlyClimbing and 12 or 8
									local targetSpeed = vel.Magnitude / baseSpeed * speed
									targetSpeed = math.max(0.5, targetSpeed)
									track:AdjustSpeed(targetSpeed)
								end
							end
						end
					elseif vel.Magnitude > 0.1 then
						-- Fallback: calculate movement direction from velocity
						local worldMoveDir = vel.Unit
						local charCF = hrp.CFrame
						local localMoveDir = charCF:VectorToObjectSpace(worldMoveDir)
						local moveScale = vel.Magnitude / 16 * speed * 25.0
						local moveVector = Vector3.new(localMoveDir.X, localMoveDir.Y, localMoveDir.Z) * moveScale
						hum:Move(moveVector)
					else
						hum:Move(Vector3.new(0, 0, 0))
					end

					-- Set actual velocity for physics movement (exact recorded velocity)
					hrp.AssemblyLinearVelocity = vel

					-- Position correction - MORE STRICT for climbing (0.5 blend) to stay on thin surfaces
					if fA.pos and fB.pos then
						local targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z)
							:Lerp(Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha)
						local targetYaw = fA.rot or 0
						local currentPos = hrp.Position
						-- Use stricter blend for climbing (0.5) vs swimming (0.3)
						local positionBlend = isCurrentlyClimbing and 0.5 or 0.3
						local smoothPos = currentPos:Lerp(targetPos, positionBlend)
						hrp.CFrame = CFrame.new(smoothPos) * CFrame.Angles(0, math.rad(targetYaw), 0)
					end

					-- FORCE maintain climbing/swimming state again at end
					hum:ChangeState(
						isCurrentlyClimbing and Enum.HumanoidStateType.Climbing or Enum.HumanoidStateType.Swimming
					)

					-- Update hip height for swimming
					if isCurrentlySwimming and fA.hh then
						hum.HipHeight = fA.hh
					end
				else
					-- NORMAL MOVEMENT (Running, Jumping, Freefall, etc.) - Same as PC StarshipCore.lua

					-- 2. Apply Velocity / Position
					if fA.vel and fB.vel then
						local vel = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
							:Lerp(Vector3.new(fB.vel.x, fB.vel.y, fB.vel.z), alpha)
						vel = vel * speed

						-- IMPROVED: Higher velocity blending for smoother transitions (same as PC)
						local currentVel = hrp.AssemblyLinearVelocity
						local baseBlend = 0.85 -- Increased from 0.6 for smoother transitions
						local blendFactor = math.clamp(baseBlend * speed, 0.5, 0.98)

						-- Check if in air state - use position-based for smooth jump like recording
						local isInAir = (stateName == "Jumping" or stateName == "Freefall")

						-- IMPROVED: Use Catmull-Rom spline for smoother interpolation
						local smoothPos, smoothVel = SmoothInterpolateFrames(PlaybackState.frameData, frameIdx, alpha)

						if isInAir and smoothPos then
							-- Follow recorded position for smooth jump arc (like recording)
							local targetPos = smoothPos -- Use Catmull-Rom interpolated position

							-- On time jump or high speed, snap directly to target position
							if isTimeJump or speed >= 2 then
								hrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
								hrp.AssemblyLinearVelocity = vel
							else
								-- Smoothly move to target position
								local currentPos = hrp.Position
								local posBlend = math.clamp(0.5 * speed, 0.3, 0.9)
								local newPos = currentPos:Lerp(targetPos, posBlend)
								hrp.CFrame = CFrame.new(newPos) * hrp.CFrame.Rotation

								-- Use RECORDED velocity for animation (not calculated)
								local recordedVelY = fA.vel and fA.vel.y or 0
								local horizVel = (targetPos - currentPos) * 10 * speed
								hrp.AssemblyLinearVelocity = Vector3.new(horizVel.X, recordedVelY * speed, horizVel.Z)
							end
						else
							-- IMPROVED: Position-Based Playback mode (smoother ground movement)
							if SMOOTH_SETTINGS.PositionBasedEnabled and smoothPos then
								-- Position-based: Use VELOCITY for animation, with STRONG position correction
								local currentPos = hrp.Position
								local posDiff = smoothPos - currentPos
								local distance = posDiff.Magnitude

								-- Calculate target velocity that will move us toward the path
								local correctionStrength = math.clamp(distance * 8, 0, 50)
								local correctionVel = distance > 0.01 and (posDiff.Unit * correctionStrength)
									or Vector3.new(0, 0, 0)

								-- Blend with recorded velocity for smooth acceleration
								local targetVel = smoothVel or vel
								local finalVel = targetVel + correctionVel

								-- Apply velocity (allows physics and animations to work properly)
								hrp.AssemblyLinearVelocity = currentVel:Lerp(finalVel, 0.85)

								-- Only snap position if WAY off (fallback safety)
								if distance > 8 then
									local snapPos = currentPos:Lerp(smoothPos, 0.5)
									hrp.CFrame = CFrame.new(snapPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
								end

								-- CRITICAL: Trigger walk/run animation using h:Move()
								if fA.md then
									local moveDir = Vector3.new(fA.md.x, fA.md.y, fA.md.z)
									if moveDir.Magnitude > 0.01 then
										hum:Move(moveDir, false)
									else
										hum:Move(Vector3.new(0, 0, 0))
									end
								elseif finalVel.Magnitude > 0.5 then
									local flatVel = Vector3.new(finalVel.X, 0, finalVel.Z)
									if flatVel.Magnitude > 0.1 then
										hum:Move(flatVel.Unit, false)
									end
								else
									hum:Move(Vector3.new(0, 0, 0))
								end
							else
								-- Velocity-based fallback (original approach)
								if isTimeJump or speed >= 2 then
									hrp.AssemblyLinearVelocity = smoothVel or vel
									if smoothPos then
										hrp.CFrame = CFrame.new(smoothPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
									elseif fA.pos then
										local targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z)
											:Lerp(Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha)
										hrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(fA.rot or 0), 0)
									end
								else
									local targetVel = smoothVel or vel
									hrp.AssemblyLinearVelocity = currentVel:Lerp(targetVel, blendFactor)

									-- Subtle position correction to prevent drift
									if smoothPos then
										local posDiff = (smoothPos - hrp.Position)
										local posCorrection = posDiff * 0.2
										hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + posCorrection
									end

									-- Trigger walk/run animation
									if fA.md then
										local moveDir = Vector3.new(fA.md.x, fA.md.y, fA.md.z)
										if moveDir.Magnitude > 0.01 then
											hum:Move(moveDir, false)
										end
									elseif targetVel.Magnitude > 0.5 then
										local flatVel = Vector3.new(targetVel.X, 0, targetVel.Z)
										if flatVel.Magnitude > 0.1 then
											hum:Move(flatVel.Unit, false)
										end
									end
								end
							end
						end
					end

					-- 3. Apply Move Direction & Rotation (SAME AS PC)
					-- Check if climbing/swimming (special handling)
					local isClimbingOrSwimming = (stateName == "Climbing" or stateName == "Swimming")

					if isClimbingOrSwimming then
						-- Climbing/Swimming: Rotation already handled in position section
						if cachedAO then
							cachedAO.Enabled = false
						end
						hum.AutoRotate = false
					else
						-- ALL OTHER STATES (including air): Use recorded rotation via AlignOrientation
						-- This ensures rotation matches recording exactly (same as PC)
						hum.AutoRotate = false -- Disable default to prevent fighting

						-- Create/reuse AlignOrientation for smooth rotation
						if not cachedAO or not cachedAO.Parent then
							cachedAO = Instance.new("AlignOrientation", hrp)
							cachedAO.Name = "PlaybackAO"
							cachedAO.Mode = Enum.OrientationAlignmentMode.OneAttachment
							cachedAO.Attachment0 = cachedAtt
							cachedAO.RigidityEnabled = false
							cachedAO.MaxTorque = 1000000 -- Same as PC
						end
						cachedAO.Enabled = true
						cachedAO.Responsiveness = 80 -- Same as PC (80 for normal playback)

						-- Determine look direction
						local lookDir = Vector3.new(0, 0, -1) -- Default

						-- Use recorded charLook if available (shiftlock direction)
						if fA.charLook and fB.charLook then
							local lookA = Vector3.new(fA.charLook.x, 0, fA.charLook.z)
							local lookB = Vector3.new(fB.charLook.x, 0, fB.charLook.z)
							if lookA.Magnitude > 0.01 and lookB.Magnitude > 0.01 then
								lookDir = lookA.Unit:Lerp(lookB.Unit, alpha)
							elseif lookA.Magnitude > 0.01 then
								lookDir = lookA.Unit
							end
						elseif fA.charLook then
							local look = Vector3.new(fA.charLook.x, 0, fA.charLook.z)
							if look.Magnitude > 0.01 then
								lookDir = look.Unit
							end
						else
							-- Fallback: Calculate look direction from velocity (movement direction)
							if fA.vel and fB.vel then
								local v = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
									:Lerp(Vector3.new(fB.vel.x, fB.vel.y, fB.vel.z), alpha)
								if v.Magnitude > 0.1 then
									lookDir = Vector3.new(v.X, 0, v.Z)
									if lookDir.Magnitude > 0.01 then
										lookDir = lookDir.Unit
									end
								end
							end
						end

						-- Ensure lookDir is valid
						if lookDir.Magnitude < 0.001 then
							lookDir = Vector3.new(0, 0, -1)
						end

						-- Apply rotation via AlignOrientation
						cachedAO.CFrame = CFrame.lookAt(Vector3.zero, lookDir)

						-- Trigger animation based on velocity
						if fA.vel then
							local velDir = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
							if velDir.Magnitude > 0.1 then
								hum:Move(velDir.Unit)
							end
						end
					end

					-- 4. Jump & State Replication (SAME AS PC)
					if fA.jmp then
						hum.Jump = true
					end

					if stateName then
						local stateEnum = Enum.HumanoidStateType[stateName]
						local currentState = hum:GetState()

						-- NORMAL PLAYBACK: Use velocity Y to determine correct air state
						local isAirState = (
							stateEnum == Enum.HumanoidStateType.Jumping
							or stateEnum == Enum.HumanoidStateType.Freefall
						)

						if isAirState then
							-- Use velocity Y to determine animation
							local velY = fA.vel and fA.vel.y or 0
							local targetState = velY > 0 and "jump" or "fall"

							-- SPAM JUMP DETECTION: Force state change if velocity is significant
							local forceStateChange = math.abs(velY) > 8

							-- Change state if different OR if velocity is significant (spam jump detection)
							if targetState ~= lastAirState or forceStateChange then
								lastAirState = targetState
								if targetState == "jump" then
									hum:ChangeState(Enum.HumanoidStateType.Jumping)
								else
									hum:ChangeState(Enum.HumanoidStateType.Freefall)
								end
							end
						elseif stateEnum == Enum.HumanoidStateType.Landed then
							-- Reset lastAirState to allow next jump (important for spam jumps)
							lastAirState = nil
							if currentState ~= Enum.HumanoidStateType.Landed then
								hum:ChangeState(Enum.HumanoidStateType.Landed)
							end
						elseif stateEnum == Enum.HumanoidStateType.Running then
							lastAirState = nil
							-- Running: Prevent unwanted freefall on small bumps
							if currentState == Enum.HumanoidStateType.Freefall then
								-- Check if we should be running instead
								if fA.vel and math.abs(fA.vel.y) < 3 then
									hum:ChangeState(Enum.HumanoidStateType.Running)
								end
							elseif currentState ~= Enum.HumanoidStateType.Running then
								hum:ChangeState(Enum.HumanoidStateType.Running)
							end
						elseif
							stateEnum == Enum.HumanoidStateType.Climbing
							and currentState ~= Enum.HumanoidStateType.Climbing
						then
							-- Climbing: Force state and ensure proper velocity for animation
							hum:ChangeState(Enum.HumanoidStateType.Climbing)
						elseif
							stateEnum == Enum.HumanoidStateType.Climbing
							and currentState == Enum.HumanoidStateType.Climbing
						then
							-- Maintain climbing: Apply full recorded velocity (not dampened)
							if fA.vel then
								local climbVel = Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z)
								if speed ~= 1.0 then
									climbVel = climbVel * speed
								end
								hrp.AssemblyLinearVelocity = climbVel
							end
						elseif
							stateEnum == Enum.HumanoidStateType.Swimming
							and currentState ~= Enum.HumanoidStateType.Swimming
						then
							-- Swimming: Force state and update hip height
							hum:ChangeState(Enum.HumanoidStateType.Swimming)
							if fA.hh then
								hum.HipHeight = fA.hh
							end
						else
							-- Other states
							pcall(function()
								hum:ChangeState(stateEnum)
							end)
						end
					end

					-- 5. Drift Correction (Subtle) - Skip during climbing/swimming/air states
					local isInAirState = (stateName == "Jumping" or stateName == "Freefall")
					local skipDriftCorrection = (stateName == "Climbing" or stateName == "Swimming" or isInAirState)

					-- IMPROVED: Smooth Drift Correction (same as PC)
					if not skipDriftCorrection then
						-- Use Catmull-Rom interpolated position for smoother target
						local smoothTargetPos, _ = SmoothInterpolateFrames(PlaybackState.frameData, frameIdx, alpha)
						local targetPos = smoothTargetPos
						if not targetPos and fA.pos and fB.pos then
							targetPos = Vector3.new(fA.pos.x, fA.pos.y, fA.pos.z)
								:Lerp(Vector3.new(fB.pos.x, fB.pos.y, fB.pos.z), alpha)
						end

						if targetPos then
							local dist = (hrp.Position - targetPos).Magnitude

							-- Check if actually moving (collision detection)
							local actualVel = hrp.AssemblyLinearVelocity.Magnitude
							local expectedVel = fA.vel and Vector3.new(fA.vel.x, fA.vel.y, fA.vel.z).Magnitude or 0
							local isStuck = (expectedVel > 3 and actualVel < 1)

							if dist > 10 then
								-- IMPROVED: Smooth lerp instead of instant snap
								local smoothSnapPos = hrp.Position:Lerp(targetPos, 0.4)
								hrp.CFrame = CFrame.new(smoothSnapPos) * hrp.CFrame.Rotation
							elseif dist > 3 and not isStuck then
								-- Medium drift: Stronger velocity correction
								local dir = (targetPos - hrp.Position).Unit
								local correction = dir * (dist * 1.5)
								hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + correction
							elseif dist > 0.5 and not isStuck then
								-- Small drift: Gentle nudge
								local dir = (targetPos - hrp.Position).Unit
								local correction = dir * (dist * 0.8)
								hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + correction
							end
							-- Under 0.5 studs: no correction needed
						end
					end
				end
			end
		end)
	else
		-- STANDARD MODE
		hrp.Anchored = false

		-- Create constraints for smooth movement
		local att = hrp:FindFirstChild("PlaybackAtt") or Instance.new("Attachment", hrp)
		att.Name = "PlaybackAtt"

		local ap = hrp:FindFirstChild("PlaybackAP") or Instance.new("AlignPosition", hrp)
		ap.Name = "PlaybackAP"
		ap.Mode = Enum.PositionAlignmentMode.OneAttachment
		ap.Attachment0 = att
		ap.MaxForce = math.huge
		ap.MaxVelocity = math.huge
		ap.Responsiveness = PlaybackState.nativeAnim and 80 or 200
		ap.RigidityEnabled = not PlaybackState.nativeAnim

		local ao = hrp:FindFirstChild("PlaybackAO") or Instance.new("AlignOrientation", hrp)
		ao.Name = "PlaybackAO"
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.Attachment0 = att
		ao.MaxTorque = math.huge
		ao.MaxAngularVelocity = math.huge
		ao.Responsiveness = PlaybackState.nativeAnim and 80 or 200
		ao.RigidityEnabled = not PlaybackState.nativeAnim

		-- Disable animate for non-native mode
		if animate and not PlaybackState.nativeAnim then
			animate.Disabled = true
		end

		PlaybackState.connection = RunService.Stepped:Connect(function(_, dt)
			if not PlaybackState.isPlaying or PlaybackState.isPaused then
				return
			end

			-- Ensure speed is always a number
			local speed = tonumber(PlaybackState.speed) or 1
			PlaybackState.speed = speed

			PlaybackState.currentTime = PlaybackState.currentTime + (dt * speed)

			-- Check end
			if PlaybackState.currentTime >= PlaybackState.totalDuration then
				if PlaybackState.isRespawnOnEnd then
					local savedFile = PlaybackState.currentFile
					local savedLoop = PlaybackState.isLooping
					StopPlayback()
					WindUI:Notify({ Title = "Respawn", Content = "Respawning in 5 seconds...", Duration = 5 })
					task.wait(5)
					local hum = GetHumanoid()
					if hum then
						hum.Health = 0
					end
					if savedLoop then
						task.spawn(function()
							LocalPlayer.CharacterAdded:Wait()
							WindUI:Notify({
								Title = "Loop",
								Content = "Restarting playback in 5 seconds...",
								Duration = 5,
							})
							task.wait(5)
							if savedFile then
								PlayRecording(savedFile, true)
							end
						end)
					end
					return
				elseif PlaybackState.isLooping then
					PlaybackState.currentTime = 0
				else
					StopPlayback()
					WindUI:Notify({ Title = "Finished", Content = "Playback completed!", Duration = 2 })
					return
				end
			end

			-- Find frames
			local frameIdx =
				FindFrameIndex(PlaybackState.frameData, PlaybackState.currentTime, PlaybackState.lastFrameIndex)
			PlaybackState.lastFrameIndex = frameIdx
			local fA, fB = PlaybackState.frameData[frameIdx], PlaybackState.frameData[frameIdx + 1]

			if fA and fB then
				local deltaT = fB.t - fA.t
				local alpha = 0
				if deltaT > 0.0001 then
					alpha = (PlaybackState.currentTime - fA.t) / deltaT
				end

				-- Tool Replication
				UpdateTool(GetCharacter(), fA.tool)

				-- Interpolate CFrame
				if fA.r and fB.r then
					local targetCF = TblToCF(fA.r):Lerp(TblToCF(fB.r), alpha)
					ap.Position = targetCF.Position
					ao.CFrame = targetCF

					-- Native anim velocity
					if PlaybackState.nativeAnim then
						local nextPos = TblToCF(fB.r).Position
						local prevPos = TblToCF(fA.r).Position
						local velocity = (nextPos - prevPos) / deltaT * speed

						local currentVel = hrp.AssemblyLinearVelocity
						local blendFactor = math.clamp(0.5 * speed, 0.3, 0.95)
						hrp.AssemblyLinearVelocity = currentVel:Lerp(velocity, blendFactor)
					end
				end

				-- Joint replication (Standard mode only)
				if not PlaybackState.nativeAnim and fA.j and fB.j then
					for jointName, dataA in pairs(fA.j) do
						local dataB = fB.j[jointName]
						if dataB then
							local motor = PlaybackState.jointMap[jointName]
							if motor then
								local target = TblToCF(dataA):Lerp(TblToCF(dataB), alpha)
								if PlaybackState.strictRetarget then
									motor.Transform = target.Rotation
								else
									motor.Transform = target
								end
							end
						end
					end
				end
			end
		end)
	end
end

-- Pause playback
local function PausePlayback()
	if PlaybackState.isPlaying then
		PlaybackState.isPaused = true
		PlaybackState.isPlaying = false

		-- Reset character when paused (SAME AS PC behavior)
		-- This allows player to move freely while paused
		ResetCharacter()

		WindUI:Notify({ Title = "Paused", Content = "Playback paused - You can move freely", Duration = 2 })
	end
end

-- ══════════════════════════════════════════════════════════════════
-- 🎬 MERGED PLAYER TAB
-- ══════════════════════════════════════════════════════════════════

-- Variables
local selectedFile = nil
local selectedFileDisplay = nil -- Reference to paragraph element

-- Function to select file (Defined early)
local function SelectFile(fileName)
	selectedFile = fileName
	local displayName = fileName:gsub("%.json$", "")

	-- Update the paragraph display
	if selectedFileDisplay then
		pcall(function()
			selectedFileDisplay:SetTitle("🎬 " .. displayName)
			selectedFileDisplay:SetDesc("Ready to play • Tap Play to start")
		end)
	end

	WindUI:Notify({
		Title = "File Selected",
		Content = displayName,
		Duration = 1.5,
	})
end

-- ══════════════════════════════════════════════════════════════════
-- CLOUD RECORDINGS (Main file source for mobile)
-- ══════════════════════════════════════════════════════════════════
ListMapTab:Space()

-- Cloud recording storage (in memory for mobile)
local CloudRecordingData = nil
local CloudRecordingName = nil
local CloudRecordingsCache = {} -- Cache: displayName -> {name, shareCode, gistId}
local CloudDropdownValues = {}

-- Fetch cloud recordings list BEFORE creating dropdown
do
	local apiUrl = "https://starship-core.my.id/api/recordings?list=all"

	local success, response = pcall(function()
		return game:HttpGet(apiUrl)
	end)

	if success and response then
		local parseSuccess, data = pcall(function()
			return HttpService:JSONDecode(response)
		end)

		if parseSuccess and data and data.success and data.recordings then
			for _, rec in ipairs(data.recordings) do
				local displayName = "☁️ " .. rec.name
				table.insert(CloudDropdownValues, displayName)
				CloudRecordingsCache[displayName] = {
					name = rec.name,
					shareCode = rec.shareCode,
					gistId = rec.gistId,
				}
			end
		end
	end

	if #CloudDropdownValues == 0 then
		table.insert(CloudDropdownValues, "No cloud recordings")
	end
end

ListMapTab:Paragraph({
	Title = "☁️ Cloud Recordings (" .. #CloudDropdownValues .. ")",
	Desc = "Recordings uploaded by PC users",
})

-- Cloud Recordings Dropdown
local selectedCloudRecording = nil

ListMapTab:Dropdown({
	Title = "Select Cloud Recording",
	Desc = "Choose a recording from cloud",
	Values = CloudDropdownValues,
	Callback = function(selected)
		if selected == "☁️ Loading cloud recordings..." or selected == "No cloud recordings available" then
			return
		end

		local recInfo = CloudRecordingsCache[selected]
		if not recInfo then
			WindUI:Notify({
				Title = "Error",
				Content = "Recording info not found",
				Duration = 2,
			})
			return
		end

		selectedCloudRecording = recInfo

		WindUI:Notify({
			Title = "☁️ Loading...",
			Content = "Fetching " .. recInfo.name .. "...",
			Duration = 2,
		})

		-- Fetch the actual recording data
		task.spawn(function()
			local apiUrl = "https://starship-core.my.id/api/recordings?shareCode=" .. recInfo.shareCode

			local success, response = pcall(function()
				return game:HttpGet(apiUrl)
			end)

			if not success then
				WindUI:Notify({
					Title = "Error",
					Content = "Failed to connect to cloud",
					Duration = 3,
				})
				return
			end

			local parseSuccess, data = pcall(function()
				return HttpService:JSONDecode(response)
			end)

			if not parseSuccess or not data then
				WindUI:Notify({
					Title = "Error",
					Content = "Invalid response from server",
					Duration = 3,
				})
				return
			end

			if data.error then
				WindUI:Notify({
					Title = "Error",
					Content = data.error or "Recording not found",
					Duration = 3,
				})
				return
			end

			if data.success and data.recording then
				-- Store in memory
				CloudRecordingData = data.recording
				CloudRecordingName = data.name or recInfo.name

				-- Update selected file display
				selectedFile = "CLOUD:" .. recInfo.shareCode
				if selectedFileDisplay then
					pcall(function()
						selectedFileDisplay:SetTitle("☁️ " .. CloudRecordingName)
						selectedFileDisplay:SetDesc("Cloud Recording • Ready to play")
					end)
				end

				WindUI:Notify({
					Title = "☁️ Ready!",
					Content = CloudRecordingName .. " loaded - tap Play to start",
					Duration = 3,
				})
			else
				WindUI:Notify({
					Title = "Error",
					Content = "Recording data not found",
					Duration = 3,
				})
			end
		end)
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- 2. PLAYBACK CONTROLS (Bottom)
-- ══════════════════════════════════════════════════════════════════

-- Mini Player Logic (Raw GUI) - Modern Compact Design
local MiniPlayerGui = nil
local function ToggleMiniPlayer(state)
	if state then
		if MiniPlayerGui then
			return
		end

		-- Try CoreGui, fallback to PlayerGui
		local parent
		local success, cGui = pcall(function()
			return game:GetService("CoreGui")
		end)
		if success and cGui then
			parent = cGui
		else
			parent = LocalPlayer:WaitForChild("PlayerGui")
		end

		local screen = Instance.new("ScreenGui")
		screen.Name = "StarshipMini"
		screen.ResetOnSpawn = false
		screen.DisplayOrder = 999999
		screen.IgnoreGuiInset = true
		screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screen.Parent = parent

		-- Modern Compact Container - Responsive sizing (even smaller without toggles)
		local frame = Instance.new("Frame")
		frame.Name = "Main"
		frame.Size = UDim2.new(0, 160, 0, 70) -- Ultra compact size for mobile
		frame.Position = UDim2.new(0.5, -80, 0, 45) -- Centered top
		frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
		frame.BackgroundTransparency = 0.05
		frame.BorderSizePixel = 0
		frame.Active = true
		frame.Draggable = true
		frame.Parent = screen

		-- Rounded corners
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = frame

		-- Gradient border effect
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(99, 102, 241)
		stroke.Thickness = 1.5
		stroke.Transparency = 0.2
		stroke.Parent = frame

		-- Inner shadow/glow effect
		local innerGlow = Instance.new("Frame")
		innerGlow.Size = UDim2.new(1, -4, 1, -4)
		innerGlow.Position = UDim2.new(0, 2, 0, 2)
		innerGlow.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		innerGlow.BackgroundTransparency = 0.5
		innerGlow.BorderSizePixel = 0
		innerGlow.ZIndex = 0
		innerGlow.Parent = frame
		Instance.new("UICorner", innerGlow).CornerRadius = UDim.new(0, 12)

		-- Header with title and close button
		local header = Instance.new("Frame")
		header.Size = UDim2.new(1, 0, 0, 22)
		header.Position = UDim2.new(0, 0, 0, 0)
		header.BackgroundTransparency = 1
		header.ZIndex = 2
		header.Parent = frame

		-- Drag indicator (3 dots)
		local dragIndicator = Instance.new("Frame")
		dragIndicator.Size = UDim2.new(0, 30, 0, 3)
		dragIndicator.Position = UDim2.new(0.5, -15, 0, 4)
		dragIndicator.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
		dragIndicator.BackgroundTransparency = 0.5
		dragIndicator.BorderSizePixel = 0
		dragIndicator.ZIndex = 3
		dragIndicator.Parent = header
		Instance.new("UICorner", dragIndicator).CornerRadius = UDim.new(1, 0)

		-- Title
		local title = Instance.new("TextLabel")
		title.Text = "🚀 Starship"
		title.Size = UDim2.new(0.7, 0, 1, 0)
		title.Position = UDim2.new(0, 8, 0, 0)
		title.BackgroundTransparency = 1
		title.TextColor3 = Color3.fromRGB(180, 180, 200)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 9
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.ZIndex = 3
		title.Parent = header

		-- Close button (minimal X)
		local closeBtn = Instance.new("TextButton")
		closeBtn.Size = UDim2.new(0, 18, 0, 18)
		closeBtn.Position = UDim2.new(1, -22, 0, 2)
		closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		closeBtn.BackgroundTransparency = 0.3
		closeBtn.Text = "×"
		closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
		closeBtn.TextSize = 14
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.AutoButtonColor = true
		closeBtn.ZIndex = 3
		closeBtn.Parent = header
		Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

		closeBtn.MouseEnter:Connect(function()
			closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
		end)
		closeBtn.MouseLeave:Connect(function()
			closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		end)
		closeBtn.MouseButton1Click:Connect(function()
			if MiniPlayerGui then
				MiniPlayerGui:Destroy()
				MiniPlayerGui = nil
			end
		end)

		-- Content container (smaller height without toggles)
		local content = Instance.new("Frame")
		content.Size = UDim2.new(1, -12, 1, -26)
		content.Position = UDim2.new(0, 6, 0, 22)
		content.BackgroundTransparency = 1
		content.ZIndex = 2
		content.Parent = frame

		-- Helper for compact buttons
		local function createCompactBtn(text, color, size, pos, parent, callback)
			local btn = Instance.new("TextButton")
			btn.Size = size
			btn.Position = pos
			btn.BackgroundColor3 = color
			btn.Text = text
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.TextSize = 11
			btn.Font = Enum.Font.GothamBold
			btn.AutoButtonColor = true
			btn.ZIndex = 3
			btn.Parent = parent
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

			-- Hover effect
			btn.MouseEnter:Connect(function()
				btn.BackgroundTransparency = 0.1
			end)
			btn.MouseLeave:Connect(function()
				btn.BackgroundTransparency = 0
			end)

			btn.MouseButton1Click:Connect(callback)
			return btn
		end

		-- Play/Stop buttons (row 1) - slightly smaller
		local btnPlay = createCompactBtn(
			"▶",
			Color3.fromRGB(34, 197, 94),
			UDim2.new(0.48, 0, 0, 24),
			UDim2.new(0, 0, 0, 0),
			content,
			function()
				if selectedFile then
					PlayRecording(selectedFile)
				else
					WindUI:Notify({ Title = "Error", Content = "Select file first", Duration = 1 })
				end
			end
		)

		local btnStop = createCompactBtn(
			"⏹",
			Color3.fromRGB(220, 60, 60),
			UDim2.new(0.48, 0, 0, 24),
			UDim2.new(0.52, 0, 0, 0),
			content,
			function()
				StopPlayback()
			end
		)

		-- Speed control (row 2) - adjusted position
		local speedRow = Instance.new("Frame")
		speedRow.Size = UDim2.new(1, 0, 0, 20)
		speedRow.Position = UDim2.new(0, 0, 0, 27)
		speedRow.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		speedRow.ZIndex = 2
		speedRow.Parent = content
		Instance.new("UICorner", speedRow).CornerRadius = UDim.new(0, 6)

		local speedLabel = Instance.new("TextLabel")
		speedLabel.Text = (PlaybackState.speed or 1) .. "x"
		speedLabel.Size = UDim2.new(0.4, 0, 1, 0)
		speedLabel.Position = UDim2.new(0.3, 0, 0, 0)
		speedLabel.BackgroundTransparency = 1
		speedLabel.TextColor3 = Color3.fromRGB(99, 102, 241)
		speedLabel.Font = Enum.Font.GothamBold
		speedLabel.TextSize = 11
		speedLabel.ZIndex = 3
		speedLabel.Parent = speedRow

		local function updateSpeed(val)
			PlaybackState.speed = val
			speedLabel.Text = val .. "x"
		end

		local btnSlow = createCompactBtn(
			"−",
			Color3.fromRGB(50, 50, 65),
			UDim2.new(0.28, 0, 1, -4),
			UDim2.new(0, 2, 0, 2),
			speedRow,
			function()
				local s = tonumber(PlaybackState.speed) or 1
				s = math.max(0.1, s - 0.1)
				updateSpeed(math.floor(s * 10) / 10)
			end
		)
		btnSlow.TextSize = 14

		local btnFast = createCompactBtn(
			"+",
			Color3.fromRGB(50, 50, 65),
			UDim2.new(0.28, 0, 1, -4),
			UDim2.new(0.72, -2, 0, 2),
			speedRow,
			function()
				local s = tonumber(PlaybackState.speed) or 1
				s = math.min(5, s + 0.1)
				updateSpeed(math.floor(s * 10) / 10)
			end
		)
		btnFast.TextSize = 12

		MiniPlayerGui = screen
		WindUI:Notify({ Title = "🎮 Mini Player", Content = "Drag to move", Duration = 1.5 })
	else
		if MiniPlayerGui then
			MiniPlayerGui:Destroy()
			MiniPlayerGui = nil
		end
	end
end

ListMapTab:Divider()
ListMapTab:Space()

-- Selected File Display
selectedFileDisplay = ListMapTab:Paragraph({
	Title = "📭 No file selected",
	Desc = "Select a file above to play",
})

ListMapTab:Space()
local PlaybackSection = ListMapTab:Section({
	Title = "🎮 Playback Controls",
	Opened = true,
})

PlaybackSection:Toggle({
	Title = "Show Mini Player",
	Desc = "Floating play/stop widget",
	Default = false,
	Callback = ToggleMiniPlayer,
})

PlaybackSection:Toggle({
	Title = "Loop Playback",
	Desc = "Restart recording when finished",
	Default = false,
	Callback = function(state)
		PlaybackState.isLooping = state
		WindUI:Notify({
			Title = "Loop",
			Content = state and "Loop enabled" or "Loop disabled",
			Duration = 1.5,
		})
	end,
})

PlaybackSection:Toggle({
	Title = "Respawn on End",
	Desc = "Respawn character when recording ends",
	Default = false,
	Callback = function(state)
		PlaybackState.isRespawnOnEnd = state
		WindUI:Notify({
			Title = "Respawn",
			Content = state and "Respawn on end enabled" or "Respawn on end disabled",
			Duration = 1.5,
		})
	end,
})

-- Anti-AFK Feature
local antiAfkConnection = nil
local isAntiAfkOn = false

PlaybackSection:Toggle({
	Title = "Anti-AFK",
	Desc = "Prevent being kicked for inactivity",
	Default = false,
	Callback = function(state)
		isAntiAfkOn = state

		if isAntiAfkOn then
			-- Connect to Idled event
			antiAfkConnection = LocalPlayer.Idled:Connect(function()
				local VirtualUser = game:GetService("VirtualUser")
				VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
				task.wait(1)
				VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
			end)

			WindUI:Notify({
				Title = "Anti-AFK",
				Content = "Anti-AFK enabled! You won't be kicked for inactivity.",
				Duration = 3,
			})
		else
			-- Disconnect
			if antiAfkConnection then
				antiAfkConnection:Disconnect()
				antiAfkConnection = nil
			end

			WindUI:Notify({
				Title = "Anti-AFK",
				Content = "Anti-AFK disabled.",
				Duration = 2,
			})
		end
	end,
})

-- Bypass Admin Feature
local isBypassAdminOn = false
local bypassAdminConnection = nil

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

PlaybackSection:Toggle({
	Title = "Bypass Admin",
	Desc = "Auto-kick when admin/mod joins the server",
	Default = false,
	Callback = function(state)
		isBypassAdminOn = state

		if isBypassAdminOn then
			-- Check existing players
			for _, p in ipairs(Players:GetPlayers()) do
				CheckForAdmin(p)
			end

			-- Connect to PlayerAdded event
			bypassAdminConnection = Players.PlayerAdded:Connect(CheckForAdmin)

			WindUI:Notify({
				Title = "Bypass Admin",
				Content = "Admin detection enabled! You will be kicked if admin joins.",
				Duration = 3,
			})
		else
			-- Disconnect
			if bypassAdminConnection then
				bypassAdminConnection:Disconnect()
				bypassAdminConnection = nil
			end

			WindUI:Notify({
				Title = "Bypass Admin",
				Content = "Admin detection disabled.",
				Duration = 2,
			})
		end
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- 🎉 FUN TAB
-- ══════════════════════════════════════════════════════════════════
local FunTab = Window:Tab({
	Title = "Fun",
	Icon = "smile",
})

FunTab:Divider()

-- Fun Actions
FunTab:Section({ Title = "🎮 Fun Actions", TextSize = 20 })

FunTab:Button({
	Title = "🔄 Spin Character",
	Desc = "Make your character spin",
	Callback = function()
		local hrp = GetHRP()
		if hrp then
			for i = 1, 360, 10 do
				hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(10), 0)
				task.wait(0.01)
			end
		end
	end,
})

FunTab:Button({
	Title = "⬆️ Launch Up",
	Desc = "Launch yourself into the sky",
	Callback = function()
		local hrp = GetHRP()
		if hrp then
			local bv = Instance.new("BodyVelocity")
			bv.MaxForce = Vector3.new(0, math.huge, 0)
			bv.Velocity = Vector3.new(0, 200, 0)
			bv.Parent = hrp
			task.delay(0.5, function()
				if bv then
					bv:Destroy()
				end
			end)
		end
	end,
})

FunTab:Button({
	Title = "💀 Ragdoll",
	Desc = "Make yourself ragdoll",
	Callback = function()
		local char = GetCharacter()
		local hum = GetHumanoid()
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Physics)
			task.delay(3, function()
				if hum then
					hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
			end)
		end
	end,
})

FunTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 💥 TOUCH FLING
-- ══════════════════════════════════════════════════════════════════
FunTab:Section({ Title = "💥 Touch Fling", TextSize = 20 })

local isFlingOn = false
local flingLoop = nil
local isHitboxExpanded = false
local hitboxParts = {}

FunTab:Toggle({
	Title = "Expand Hitbox",
	Desc = "Bigger hitbox = easier fling",
	Default = false,
	Callback = function(state)
		isHitboxExpanded = state

		local char = GetCharacter()
		if not char then
			return
		end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end

		if isHitboxExpanded then
			for i = 1, 4 do
				local part = Instance.new("Part")
				part.Name = "HitboxExpander"
				part.Size = Vector3.new(4, 4, 0.5)
				part.Transparency = 1
				part.CanCollide = true
				part.Massless = true
				part.Parent = char

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hrp
				weld.Part1 = part
				weld.Parent = part

				table.insert(hitboxParts, part)
			end

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

			WindUI:Notify({ Title = "Hitbox", Content = "Hitbox expanded!", Duration = 2 })
		else
			for _, part in pairs(hitboxParts) do
				if part and part.Parent then
					part:Destroy()
				end
			end
			hitboxParts = {}
			WindUI:Notify({ Title = "Hitbox", Content = "Hitbox reset.", Duration = 2 })
		end
	end,
})

FunTab:Toggle({
	Title = "Touch Fling",
	Desc = "Fling players on touch",
	Default = false,
	Callback = function(state)
		isFlingOn = state

		if isFlingOn then
			flingLoop = RunService.Heartbeat:Connect(function()
				local char = GetCharacter()
				if not char then
					return
				end
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if not hrp then
					return
				end

				local currentVel = hrp.Velocity
				hrp.Velocity = currentVel * 10000 + Vector3.new(0, 10000, 0)

				if isHitboxExpanded then
					for _, part in pairs(hitboxParts) do
						if part and part.Parent then
							part.Velocity = hrp.Velocity
						end
					end
				end

				RunService.RenderStepped:Wait()

				if char and char.Parent and hrp and hrp.Parent then
					hrp.Velocity = currentVel
				end

				RunService.Stepped:Wait()
				if char and char.Parent and hrp and hrp.Parent then
					hrp.Velocity = currentVel + Vector3.new(0, 0.1, 0)
				end
			end)

			WindUI:Notify({ Title = "Touch Fling", Content = "Fling enabled!", Duration = 2 })
		else
			if flingLoop then
				flingLoop:Disconnect()
				flingLoop = nil
			end

			local char = GetCharacter()
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.Velocity = Vector3.new(0, 0, 0)
					hrp.RotVelocity = Vector3.new(0, 0, 0)
				end
			end

			WindUI:Notify({ Title = "Touch Fling", Content = "Fling disabled.", Duration = 2 })
		end
	end,
})

FunTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 👻 INVISIBLE
-- ══════════════════════════════════════════════════════════════════
FunTab:Section({ Title = "👻 Invisible", TextSize = 20 })

local isInvisibleOn = false
local invisibleLoop = nil

FunTab:Toggle({
	Title = "Invisible",
	Desc = "Real invisible (others can't see you)",
	Default = false,
	Callback = function(state)
		isInvisibleOn = state

		if isInvisibleOn then
			invisibleLoop = RunService.Heartbeat:Connect(function()
				local char = GetCharacter()
				if not char then
					return
				end

				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChild("Humanoid")
				if not hrp or not hum then
					return
				end

				local currentCF = hrp.CFrame
				local currentCamOffset = hum.CameraOffset

				local hiddenCF = currentCF * CFrame.new(0, -200000, 0)
				hrp.CFrame = hiddenCF

				hum.CameraOffset = hiddenCF:ToObjectSpace(CFrame.new(currentCF.Position)).Position

				RunService.RenderStepped:Wait()

				hrp.CFrame = currentCF
				hum.CameraOffset = currentCamOffset
			end)

			WindUI:Notify({ Title = "Invisible", Content = "You are now invisible to others!", Duration = 3 })
		else
			if invisibleLoop then
				invisibleLoop:Disconnect()
				invisibleLoop = nil
			end

			local char = GetCharacter()
			if char then
				local hum = char:FindFirstChild("Humanoid")
				if hum then
					hum.CameraOffset = Vector3.new(0, 0, 0)
				end
			end

			WindUI:Notify({ Title = "Invisible", Content = "Invisible disabled.", Duration = 2 })
		end
	end,
})

FunTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 👁️ SPECTATE PLAYER
-- ══════════════════════════════════════════════════════════════════
FunTab:Section({ Title = "👁️ Spectate Player", TextSize = 20 })

local spectateTarget = nil
local isSpectating = false
local spectateLoop = nil
local lastKnownPosition = nil

local function GetPlayerList()
	local list = {}
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			table.insert(list, p.Name)
		end
	end
	return list
end

FunTab:Dropdown({
	Title = "Select Player",
	Desc = "Choose player to spectate",
	Values = GetPlayerList(),
	Callback = function(selected)
		spectateTarget = Players:FindFirstChild(selected)
		WindUI:Notify({ Title = "Spectate", Content = "Selected: " .. selected, Duration = 2 })
	end,
})

FunTab:Button({
	Title = "🔄 Refresh Player List",
	Callback = function()
		WindUI:Notify({ Title = "Spectate", Content = "Re-open dropdown to see updated list", Duration = 2 })
	end,
})

FunTab:Toggle({
	Title = "Spectate",
	Desc = "Watch selected player",
	Default = false,
	Callback = function(state)
		isSpectating = state

		if isSpectating then
			if not spectateTarget then
				WindUI:Notify({ Title = "Error", Content = "Please select a player first!", Duration = 2 })
				return
			end

			if not spectateTarget.Parent then
				WindUI:Notify({ Title = "Error", Content = "Player left the game!", Duration = 2 })
				spectateTarget = nil
				return
			end

			spectateLoop = RunService.RenderStepped:Connect(function()
				if not spectateTarget or not spectateTarget.Parent then
					isSpectating = false
					if spectateLoop then
						spectateLoop:Disconnect()
						spectateLoop = nil
					end
					WindUI:Notify({ Title = "Spectate", Content = "Player left!", Duration = 2 })
					return
				end

				local targetChar = spectateTarget.Character
				local camera = workspace.CurrentCamera

				if targetChar then
					local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
					local targetHum = targetChar:FindFirstChildOfClass("Humanoid")

					if targetHRP then
						lastKnownPosition = targetHRP.Position
						pcall(function()
							LocalPlayer:RequestStreamAroundAsync(targetHRP.Position, 5)
						end)
					end

					if targetHum then
						camera.CameraSubject = targetHum
					elseif targetHRP then
						camera.CameraSubject = targetHRP
					elseif lastKnownPosition then
						camera.CameraType = Enum.CameraType.Custom
						camera.CFrame = CFrame.new(lastKnownPosition + Vector3.new(0, 10, 15), lastKnownPosition)
					end
				elseif lastKnownPosition then
					camera.CameraType = Enum.CameraType.Custom
					camera.CFrame = CFrame.new(lastKnownPosition + Vector3.new(0, 10, 15), lastKnownPosition)
				end
			end)

			WindUI:Notify({ Title = "Spectate", Content = "Spectating " .. spectateTarget.Name, Duration = 3 })
		else
			if spectateLoop then
				spectateLoop:Disconnect()
				spectateLoop = nil
			end
			lastKnownPosition = nil

			local myChar = GetCharacter()
			if myChar then
				local myHum = myChar:FindFirstChildOfClass("Humanoid")
				if myHum then
					workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
					workspace.CurrentCamera.CameraSubject = myHum
				end
			end

			WindUI:Notify({ Title = "Spectate", Content = "Spectate stopped.", Duration = 2 })
		end
	end,
})

FunTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🚶 AUTO FOLLOW
-- ══════════════════════════════════════════════════════════════════
FunTab:Section({ Title = "🚶 Auto Follow", TextSize = 20 })

local followTarget = nil
local isFollowing = false
local followLoop = nil

FunTab:Dropdown({
	Title = "Select Target",
	Desc = "Choose player to follow",
	Values = GetPlayerList(),
	Callback = function(selected)
		followTarget = Players:FindFirstChild(selected)
		WindUI:Notify({ Title = "Follow", Content = "Target: " .. selected, Duration = 2 })
	end,
})

FunTab:Toggle({
	Title = "Auto Follow",
	Desc = "Follow selected player automatically",
	Default = false,
	Callback = function(state)
		isFollowing = state

		if isFollowing then
			if not followTarget then
				WindUI:Notify({ Title = "Error", Content = "Please select a target first!", Duration = 2 })
				return
			end

			if not followTarget.Parent then
				WindUI:Notify({ Title = "Error", Content = "Player left the game!", Duration = 2 })
				followTarget = nil
				return
			end

			followLoop = RunService.Heartbeat:Connect(function()
				if not isFollowing or not followTarget then
					isFollowing = false
					if followLoop then
						followLoop:Disconnect()
						followLoop = nil
					end
					return
				end

				if not followTarget.Parent then
					isFollowing = false
					if followLoop then
						followLoop:Disconnect()
						followLoop = nil
					end
					WindUI:Notify({ Title = "Follow", Content = "Target left the game!", Duration = 2 })
					return
				end

				local myChar = GetCharacter()
				local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
				local myHum = myChar and myChar:FindFirstChild("Humanoid")

				local tChar = followTarget.Character
				local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
				local tHum = tChar and tChar:FindFirstChild("Humanoid")

				if not (myHRP and myHum and tHRP and tHum and tHum.Health > 0) then
					return
				end

				local look = tHRP.CFrame.LookVector
				local behindPos = tHRP.Position - (look * 4) + Vector3.new(0, 0, 0)
				local frontPoint = behindPos + look

				myHRP.CFrame = CFrame.new(behindPos, frontPoint)
			end)

			WindUI:Notify({ Title = "Follow", Content = "Following " .. followTarget.Name, Duration = 3 })
		else
			if followLoop then
				followLoop:Disconnect()
				followLoop = nil
			end

			WindUI:Notify({ Title = "Follow", Content = "Follow stopped.", Duration = 2 })
		end
	end,
})

FunTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- ⚙️ SETTINGS TAB
-- ══════════════════════════════════════════════════════════════════
local SettingsTab = Window:Tab({
	Title = "Settings",
	Icon = "settings",
})

-- ══════════════════════════════════════════════════════════════════
-- 🎨 APPEARANCE SETTINGS
-- ══════════════════════════════════════════════════════════════════
SettingsTab:Section({ Title = "🎨 Appearance", TextSize = 16 })

SettingsTab:Toggle({
	Title = "Show Notifications",
	Desc = "Display popup notifications",
	Default = true,
	Callback = function(state)
		-- Toggle notifications
		WindUI:Notify({
			Title = "Notifications",
			Content = state and "Notifications enabled" or "Notifications disabled",
			Duration = 2,
		})
	end,
})

SettingsTab:Dropdown({
	Title = "Theme",
	Desc = "Choose UI color theme",
	Values = { "Dark", "Light", "Midnight", "Aqua" },
	Callback = function(selected)
		pcall(function()
			WindUI:SetTheme(selected)
		end)
		WindUI:Notify({ Title = "Theme", Content = "Theme changed to " .. selected, Duration = 2 })
	end,
})

SettingsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🔧 GENERAL SETTINGS
-- ══════════════════════════════════════════════════════════════════
SettingsTab:Section({ Title = "🔧 General", TextSize = 16 })

SettingsTab:Toggle({
	Title = "Auto Anti-AFK",
	Desc = "Automatically enable Anti-AFK on start",
	Default = false,
	Callback = function(state)
		if state then
			WindUI:Notify({ Title = "Auto Anti-AFK", Content = "Will be enabled on next load", Duration = 2 })
		end
	end,
})

SettingsTab:Toggle({
	Title = "Remember Position",
	Desc = "Save UI position between sessions",
	Default = true,
	Callback = function(state)
		WindUI:Notify({
			Title = "Position",
			Content = state and "Position will be saved" or "Position won't be saved",
			Duration = 2,
		})
	end,
})

SettingsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- ℹ️ ABOUT & INFO
-- ══════════════════════════════════════════════════════════════════
SettingsTab:Section({ Title = "ℹ️ About Starship", TextSize = 16 })

SettingsTab:Paragraph({
	Title = "🚀 Starship Mobile",
	Desc = "Version: "
		.. VERSION
		.. "\n"
		.. "Framework: WindUI\n"
		.. "Platform: Mobile Optimized\n"
		.. "Status: ✅ Active",
})

SettingsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 🔗 LINKS & SOCIAL
-- ══════════════════════════════════════════════════════════════════
SettingsTab:Section({ Title = "🔗 Links & Social", TextSize = 16 })

SettingsTab:Button({
	Title = "💬 Join Discord",
	Desc = "Get updates, support & community",
	Callback = function()
		if setclipboard then
			setclipboard("https://discord.gg/starship")
			WindUI:Notify({ Title = "✅ Copied!", Content = "Discord invite link copied to clipboard!", Duration = 3 })
		else
			WindUI:Notify({ Title = "Discord", Content = "https://discord.gg/qbPcSMg8", Duration = 5 })
		end
	end,
})

SettingsTab:Button({
	Title = "⭐ Rate Us",
	Desc = "Leave a review if you enjoy Starship",
	Callback = function()
		WindUI:Notify({ Title = "Thank You!", Content = "We appreciate your support! 💜", Duration = 3 })
	end,
})

SettingsTab:Button({
	Title = "📋 Copy Script",
	Desc = "Copy loadstring to clipboard",
	Callback = function()
		if setclipboard then
			setclipboard('loadstring(game:HttpGet("https://your-url.com/Mobile/Loader.lua"))()')
			WindUI:Notify({ Title = "✅ Copied!", Content = "Loadstring copied to clipboard!", Duration = 3 })
		end
	end,
})

SettingsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- 👨‍💻 CREDITS
-- ══════════════════════════════════════════════════════════════════
SettingsTab:Section({ Title = "👨‍💻 Credits", TextSize = 16 })

SettingsTab:Paragraph({
	Title = "Development Team",
	Desc = "🎨 UI/UX: Starship Team\n"
		.. "💻 Backend: Starship Team\n"
		.. "🛠️ Framework: WindUI by Footagesus\n"
		.. "❤️ Special Thanks: Our Community",
})

SettingsTab:Divider()

-- ══════════════════════════════════════════════════════════════════
-- ⚠️ DANGER ZONE
-- ══════════════════════════════════════════════════════════════════
SettingsTab:Section({ Title = "⚠️ Danger Zone", TextSize = 16 })

SettingsTab:Button({
	Title = "🔄 Reset All Settings",
	Desc = "Reset all settings to default",
	Callback = function()
		WindUI:Notify({ Title = "Reset", Content = "Settings have been reset!", Duration = 2 })
	end,
})

SettingsTab:Button({
	Title = "🗑️ Clear Cache",
	Desc = "Clear saved data and cache",
	Callback = function()
		pcall(function()
			if delfolder then
				delfolder("StarshipMobile")
				WindUI:Notify({ Title = "✅ Cleared", Content = "Cache has been cleared!", Duration = 2 })
			else
				WindUI:Notify({ Title = "Info", Content = "No cache to clear", Duration = 2 })
			end
		end)
	end,
})

SettingsTab:Space()

SettingsTab:Button({
	Title = "❌ Close Starship",
	Desc = "Close UI and Mini Player completely",
	Callback = function()
		-- Cleanup Mini Player
		if MiniPlayerGui then
			MiniPlayerGui:Destroy()
			MiniPlayerGui = nil
		end
		-- Stop playback
		StopPlayback()
		-- Destroy WindUI Window
		Window:Destroy()
	end,
})

-- ══════════════════════════════════════════════════════════════════
-- SELECT DEFAULT TAB & WELCOME
-- ══════════════════════════════════════════════════════════════════
DashboardTab:Select()

-- Track window state untuk cleanup
local isWindowDestroyed = false

-- Fungsi cleanup untuk destroy semua
local function CleanupAll()
	if isWindowDestroyed then
		return
	end
	isWindowDestroyed = true

	StopPlayback()
	if MiniPlayerGui then
		MiniPlayerGui:Destroy()
		MiniPlayerGui = nil
	end
end

-- Handle Window Close/Destroy
Window:OnClose(function()
	-- OnClose dipanggil saat minimize - Mini Player TETAP ada
	-- Tidak melakukan cleanup di sini
end)

-- Method 1: OnDestroy callback (jika WindUI support)
pcall(function()
	if Window.OnDestroy then
		Window:OnDestroy(CleanupAll)
	end
end)

-- Method 2: Detect ScreenGui destroy dengan multiple name patterns
task.spawn(function()
	task.wait(0.5) -- Tunggu WindUI selesai setup

	local function findWindUIScreen()
		-- Cari di CoreGui
		local success, coreGui = pcall(function()
			return game:GetService("CoreGui")
		end)
		if success and coreGui then
			for _, gui in ipairs(coreGui:GetChildren()) do
				if gui:IsA("ScreenGui") then
					local name = gui.Name:lower()
					if name:find("windui") or name:find("starship") or name:find("ftgs") then
						return gui
					end
				end
			end
		end

		-- Cari di PlayerGui
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if playerGui then
			for _, gui in ipairs(playerGui:GetChildren()) do
				if gui:IsA("ScreenGui") then
					local name = gui.Name:lower()
					if name:find("windui") or name:find("starship") or name:find("ftgs") then
						return gui
					end
				end
			end
		end

		return nil
	end

	local windUIScreen = findWindUIScreen()

	if windUIScreen then
		-- Connect ke Destroying event
		windUIScreen.Destroying:Connect(CleanupAll)

		-- Juga connect ke AncestryChanged sebagai backup
		windUIScreen.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				CleanupAll()
			end
		end)
	end

	-- Method 3: Polling backup - check setiap 2 detik apakah window masih ada
	task.spawn(function()
		while not isWindowDestroyed do
			task.wait(2)

			-- Check apakah WindUI screen masih exist
			local screen = findWindUIScreen()
			if not screen or not screen.Parent then
				CleanupAll()
				break
			end
		end
	end)
end)

task.delay(1, function()
	WindUI:Notify({
		Title = "Welcome!",
		Content = "Starship Mobile loaded successfully!",
		Duration = 4,
	})
end)
