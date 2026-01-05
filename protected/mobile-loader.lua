--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║              STARSHIP MOBILE LOADER                           ║
    ║              Secure Whitelist Authentication                  ║
    ║              + Event Code System                              ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Configuration (SECURITY: Obscured endpoint names - v3.0)
local SECURE_API_URL = "https://starship-core.my.id"
local MOBILE_UI_API = SECURE_API_URL .. "/api/m-ui-v8x3q2?userId="
local MOBILE_AUTH_API = SECURE_API_URL .. "/api/m-auth-k5r9z7"

-- Event Code System API (SECURITY: Obscured)
local EVENT_CODE_API = SECURE_API_URL .. "/api/m-evt-j3w8p4"

-- Encryption helpers
local function xorEncrypt(text, key)
	local result = {}
	for i = 1, #text do
		local charCode = string.byte(text, i)
		local keyCode = string.byte(key, ((i - 1) % #key) + 1)
		table.insert(result, string.char(bit32.bxor(charCode, keyCode)))
	end
	return table.concat(result)
end

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64Decode(data)
	data = string.gsub(data, "[^" .. b64chars .. "=]", "")
	return (
		data:gsub(".", function(x)
			if x == "=" then
				return ""
			end
			local r, f = "", (b64chars:find(x) - 1)
			for i = 6, 1, -1 do
				r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
			end
			return r
		end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
			if #x ~= 8 then
				return ""
			end
			local c = 0
			for i = 1, 8 do
				c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
			end
			return string.char(c)
		end)
	)
end

-- ══════════════════════════════════════════════════════════════════
-- HWID DETECTION (Hardware ID for device binding)
-- ══════════════════════════════════════════════════════════════════
local function getDeviceHWID()
	local hwid = nil

	-- Method 1: Try gethwid() - Most common in PC executors
	pcall(function()
		if gethwid then
			hwid = gethwid()
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 2: Try HWID from getexecutorinfo (Delta, Fluxus, etc)
	pcall(function()
		if getexecutorinfo then
			local info = getexecutorinfo()
			if type(info) == "table" and info.HWID then
				hwid = info.HWID
			elseif type(info) == "table" and info.hwid then
				hwid = info.hwid
			end
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 3: Try identifyexecutor() + custom HWID
	pcall(function()
		if identifyexecutor then
			local execName, execVersion = identifyexecutor()
			-- Some executors store HWID in _G or getgenv()
			if getgenv and getgenv().HWID then
				hwid = getgenv().HWID
			elseif _G.HWID then
				hwid = _G.HWID
			end
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 4: Try get_hwid (alternative naming)
	pcall(function()
		if get_hwid then
			hwid = get_hwid()
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 5: Delta Executor specific
	pcall(function()
		if Delta and Delta.HWID then
			hwid = Delta.HWID
		elseif delta and delta.hwid then
			hwid = delta.hwid
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 6: Fallback - Generate pseudo-HWID from user data
	-- This is less secure but better than nothing
	pcall(function()
		local userId = tostring(LocalPlayer.UserId)
		local execName = "unknown"
		pcall(function()
			if identifyexecutor then
				execName = identifyexecutor() or "unknown"
			end
		end)
		-- Create a pseudo-HWID (not as secure, but provides some protection)
		hwid = "PSEUDO_" .. execName .. "_" .. userId
	end)

	return hwid or "unknown"
end

local function createLoadingUI()
	-- Remove existing UI if any
	local existingGui = LocalPlayer:FindFirstChild("PlayerGui")
		and LocalPlayer.PlayerGui:FindFirstChild("StarshipMobileLoader")
	if existingGui then
		existingGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StarshipMobileLoader"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true

	-- Try to parent to CoreGui, fallback to PlayerGui
	pcall(function()
		screenGui.Parent = game:GetService("CoreGui")
	end)
	if not screenGui.Parent then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	-- Background (Fullscreen dark)
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(8, 8, 15)
	background.BorderSizePixel = 0
	background.Parent = screenGui

	-- Large Logo Overlay (Background watermark)
	local logoOverlay = Instance.new("ImageLabel")
	logoOverlay.Name = "LogoOverlay"
	logoOverlay.Size = UDim2.new(0, 350, 0, 350)
	logoOverlay.Position = UDim2.new(0.5, -175, 0.4, -175)
	logoOverlay.BackgroundTransparency = 1
	logoOverlay.Image = "rbxassetid://123840945153526"
	logoOverlay.ImageTransparency = 0.88
	logoOverlay.ImageColor3 = Color3.fromRGB(255, 255, 255)
	logoOverlay.ScaleType = Enum.ScaleType.Fit
	logoOverlay.ZIndex = 1
	logoOverlay.Parent = background

	-- Floating Particles Container
	local particleContainer = Instance.new("Frame")
	particleContainer.Name = "Particles"
	particleContainer.Size = UDim2.new(1, 0, 1, 0)
	particleContainer.BackgroundTransparency = 1
	particleContainer.ClipsDescendants = true
	particleContainer.ZIndex = 2
	particleContainer.Parent = background

	-- Create floating particles
	task.spawn(function()
		for i = 1, 15 do
			if not screenGui or not screenGui.Parent then
				break
			end

			local particle = Instance.new("Frame")
			local size = math.random(3, 6)
			particle.Size = UDim2.new(0, size, 0, size)
			particle.Position = UDim2.new(math.random(), 0, math.random(), 0)
			particle.BackgroundColor3 = Color3.fromHSV(0.65 + math.random() * 0.1, 0.8, 1)
			particle.BackgroundTransparency = 0.5
			particle.BorderSizePixel = 0
			particle.ZIndex = 3
			particle.Parent = particleContainer

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = particle

			-- Animate particle
			task.spawn(function()
				local startY = particle.Position.Y.Scale
				local startX = particle.Position.X.Scale
				local floatSpeed = math.random(8, 20) / 10000

				while particle and particle.Parent do
					local newY = startY - floatSpeed
					if newY < -0.1 then
						newY = 1.1
						startY = 1.1
						startX = math.random()
					end
					startY = newY

					local sway = math.sin(os.clock() * 2 + i) * 0.02
					particle.Position = UDim2.new(startX + sway, 0, newY, 0)
					particle.BackgroundTransparency = 0.4 + math.sin(os.clock() * 2 + i) * 0.2

					task.wait(0.03)
				end
			end)
			task.wait(0.05)
		end
	end)

	-- Welcome Message (Top)
	local welcomeMsg = Instance.new("TextLabel")
	welcomeMsg.Name = "Welcome"
	welcomeMsg.Size = UDim2.new(1, 0, 0, 25)
	welcomeMsg.Position = UDim2.new(0, 0, 0.18, 0)
	welcomeMsg.BackgroundTransparency = 1
	welcomeMsg.Text = "Welcome back, " .. LocalPlayer.Name .. "!"
	welcomeMsg.TextColor3 = Color3.fromRGB(60, 255, 180)
	welcomeMsg.TextSize = 14
	welcomeMsg.Font = Enum.Font.Gotham
	welcomeMsg.ZIndex = 10
	welcomeMsg.Parent = background

	-- Logo Container (Large, centered)
	local logoContainer = Instance.new("Frame")
	logoContainer.Name = "LogoContainer"
	logoContainer.Size = UDim2.new(0, 120, 0, 120)
	logoContainer.Position = UDim2.new(0.5, -60, 0.28, 0)
	logoContainer.BackgroundTransparency = 1
	logoContainer.ZIndex = 10
	logoContainer.Parent = background

	local logo = Instance.new("ImageLabel")
	logo.Name = "Logo"
	logo.Image = "rbxassetid://123840945153526"
	logo.Size = UDim2.new(1, 0, 1, 0)
	logo.BackgroundTransparency = 1
	logo.ScaleType = Enum.ScaleType.Fit
	logo.ZIndex = 10
	logo.Parent = logoContainer

	-- Title Text
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "STARSHIP"
	title.Size = UDim2.new(1, 0, 0, 45)
	title.Position = UDim2.new(0, 0, 0.50, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(90, 110, 245)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 36
	title.ZIndex = 10
	title.Parent = background

	-- Subtitle / Status Text
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Text = "Initializing..."
	statusLabel.Size = UDim2.new(1, 0, 0, 25)
	statusLabel.Position = UDim2.new(0, 0, 0.58, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 13
	statusLabel.ZIndex = 10
	statusLabel.Parent = background

	-- Progress Bar Container
	local progressContainer = Instance.new("Frame")
	progressContainer.Name = "ProgressBg"
	progressContainer.Size = UDim2.new(0.6, 0, 0, 6)
	progressContainer.Position = UDim2.new(0.2, 0, 0.65, 0)
	progressContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	progressContainer.BorderSizePixel = 0
	progressContainer.ZIndex = 10
	progressContainer.Parent = background

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(1, 0)
	progressCorner.Parent = progressContainer

	local progressGlow = Instance.new("UIStroke")
	progressGlow.Color = Color3.fromRGB(90, 110, 245)
	progressGlow.Thickness = 1
	progressGlow.Transparency = 0.7
	progressGlow.Parent = progressContainer

	-- Progress Bar Fill
	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(90, 110, 245)
	progressFill.BorderSizePixel = 0
	progressFill.ZIndex = 11
	progressFill.Parent = progressContainer

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = progressFill

	-- Progress Percentage
	local progressText = Instance.new("TextLabel")
	progressText.Name = "ProgressText"
	progressText.Text = "0%"
	progressText.Size = UDim2.new(1, 0, 0, 20)
	progressText.Position = UDim2.new(0, 0, 0.69, 0)
	progressText.BackgroundTransparency = 1
	progressText.TextColor3 = Color3.fromRGB(120, 140, 255)
	progressText.Font = Enum.Font.GothamBold
	progressText.TextSize = 12
	progressText.ZIndex = 10
	progressText.Parent = background

	-- Version label
	local versionLabel = Instance.new("TextLabel")
	versionLabel.Name = "Version"
	versionLabel.Size = UDim2.new(1, 0, 0, 20)
	versionLabel.Position = UDim2.new(0, 0, 0.92, 0)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Text = "v1.0.0-mobile"
	versionLabel.TextColor3 = Color3.fromRGB(70, 70, 90)
	versionLabel.TextSize = 11
	versionLabel.Font = Enum.Font.Gotham
	versionLabel.ZIndex = 10
	versionLabel.Parent = background

	-- Logo Animation: Pulse + Float + Rainbow color
	task.spawn(function()
		local t = 0
		local floatOffset = 0
		local baseSize = 120
		while logo and logo.Parent do
			t = t + 0.02
			floatOffset = floatOffset + 0.06

			-- Rainbow color cycle for title and progress
			local c = Color3.fromHSV(t % 1, 0.85, 1)
			title.TextColor3 = c
			progressFill.BackgroundColor3 = c
			progressGlow.Color = c

			-- Pulse size for logo container
			local pulse = 1 + math.sin(t * 4) * 0.04
			local newSize = baseSize * pulse
			logoContainer.Size = UDim2.new(0, newSize, 0, newSize)
			logoContainer.Position = UDim2.new(0.5, -newSize / 2, 0.28, math.sin(floatOffset) * 5)

			task.wait(0.02)
		end
	end)

	-- Update function
	local function updateStatus(text, progress)
		-- Obfuscate specific module names
		if string.find(text, "Downloading:") then
			text = "Loading Module #" .. math.random(1000, 9999)
		elseif string.find(text, "Updating") then
			text = "Preparing Assets..."
		end

		statusLabel.Text = text
		TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(progress, 0, 1, 0),
		}):Play()
		progressText.Text = math.floor(progress * 100) .. "%"
	end

	return screenGui, updateStatus
end

-- Show Error UI
local function showError(message)
	-- Remove existing loader
	pcall(function()
		game:GetService("CoreGui"):FindFirstChild("StarshipMobileLoader"):Destroy()
	end)
	pcall(function()
		LocalPlayer.PlayerGui:FindFirstChild("StarshipMobileLoader"):Destroy()
	end)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StarshipMobileError"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true

	pcall(function()
		screenGui.Parent = game:GetService("CoreGui")
	end)
	if not screenGui.Parent then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	-- Background
	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromHex("#0a0a0f")
	background.BorderSizePixel = 0
	background.Parent = screenGui

	-- Container
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, 340, 0, 220)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = Color3.fromHex("#1a1a2e")
	container.BorderSizePixel = 0
	container.Parent = background

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 16)
	containerCorner.Parent = container

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = Color3.fromHex("#ef4444")
	containerStroke.Thickness = 2
	containerStroke.Transparency = 0.3
	containerStroke.Parent = container

	-- Error Icon
	local errorIcon = Instance.new("TextLabel")
	errorIcon.Size = UDim2.new(1, 0, 0, 50)
	errorIcon.Position = UDim2.new(0.5, 0, 0, 25)
	errorIcon.AnchorPoint = Vector2.new(0.5, 0)
	errorIcon.BackgroundTransparency = 1
	errorIcon.Text = "❌"
	errorIcon.TextSize = 40
	errorIcon.Font = Enum.Font.GothamBold
	errorIcon.Parent = container

	-- Error Title
	local errorTitle = Instance.new("TextLabel")
	errorTitle.Size = UDim2.new(1, -40, 0, 30)
	errorTitle.Position = UDim2.new(0.5, 0, 0, 80)
	errorTitle.AnchorPoint = Vector2.new(0.5, 0)
	errorTitle.BackgroundTransparency = 1
	errorTitle.Text = "ACCESS DENIED"
	errorTitle.TextColor3 = Color3.fromHex("#ef4444")
	errorTitle.TextSize = 20
	errorTitle.Font = Enum.Font.GothamBold
	errorTitle.Parent = container

	-- Error Message
	local errorMessage = Instance.new("TextLabel")
	errorMessage.Size = UDim2.new(1, -40, 0, 50)
	errorMessage.Position = UDim2.new(0.5, 0, 0, 115)
	errorMessage.AnchorPoint = Vector2.new(0.5, 0)
	errorMessage.BackgroundTransparency = 1
	errorMessage.Text = message
	errorMessage.TextColor3 = Color3.fromHex("#a1a1aa")
	errorMessage.TextSize = 14
	errorMessage.Font = Enum.Font.Gotham
	errorMessage.TextWrapped = true
	errorMessage.Parent = container

	-- Close Button
	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 100, 0, 35)
	closeButton.Position = UDim2.new(0.5, 0, 1, -50)
	closeButton.AnchorPoint = Vector2.new(0.5, 0)
	closeButton.BackgroundColor3 = Color3.fromHex("#2a2a3e")
	closeButton.BorderSizePixel = 0
	closeButton.Text = "Close"
	closeButton.TextColor3 = Color3.fromHex("#ffffff")
	closeButton.TextSize = 14
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = container

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		screenGui:Destroy()
	end)

	-- Auto close after 10 seconds
	task.delay(10, function()
		if screenGui and screenGui.Parent then
			screenGui:Destroy()
		end
	end)
end

-- ══════════════════════════════════════════════════════════════════
-- EVENT CODE SYSTEM UI
-- ══════════════════════════════════════════════════════════════════

local function showEventCodeUI(onSuccess, onCancel)
	-- Remove existing loader
	pcall(function()
		game:GetService("CoreGui"):FindFirstChild("StarshipMobileLoader"):Destroy()
	end)
	pcall(function()
		LocalPlayer.PlayerGui:FindFirstChild("StarshipMobileLoader"):Destroy()
	end)

	local userId = tostring(LocalPlayer.UserId)
	local username = LocalPlayer.Name

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StarshipEventCode"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true

	pcall(function()
		screenGui.Parent = game:GetService("CoreGui")
	end)
	if not screenGui.Parent then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	-- Background
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromHex("#0a0a0f")
	background.BorderSizePixel = 0
	background.Parent = screenGui

	-- Gradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#0a0a0f")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("#1a1a2e")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#0a0a0f")),
	})
	gradient.Rotation = 45
	gradient.Parent = background

	-- Main Container
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 340, 0, 320)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = Color3.fromHex("#16162a")
	container.BorderSizePixel = 0
	container.Parent = background

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 16)
	containerCorner.Parent = container

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = Color3.fromHex("#6366f1")
	containerStroke.Thickness = 2
	containerStroke.Transparency = 0.5
	containerStroke.Parent = container

	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0, 50)
	icon.Position = UDim2.new(0.5, 0, 0, 20)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "🎟️"
	icon.TextSize = 40
	icon.Font = Enum.Font.GothamBold
	icon.Parent = container

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -40, 0, 30)
	title.Position = UDim2.new(0.5, 0, 0, 70)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.BackgroundTransparency = 1
	title.Text = "EVENT CODE"
	title.TextColor3 = Color3.fromHex("#ffffff")
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.Parent = container

	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -40, 0, 20)
	subtitle.Position = UDim2.new(0.5, 0, 0, 100)
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Masukkan kode event untuk mendapatkan akses"
	subtitle.TextColor3 = Color3.fromHex("#a1a1aa")
	subtitle.TextSize = 12
	subtitle.Font = Enum.Font.Gotham
	subtitle.Parent = container

	-- Input Box Container
	local inputContainer = Instance.new("Frame")
	inputContainer.Size = UDim2.new(1, -50, 0, 45)
	inputContainer.Position = UDim2.new(0.5, 0, 0, 135)
	inputContainer.AnchorPoint = Vector2.new(0.5, 0)
	inputContainer.BackgroundColor3 = Color3.fromHex("#1e1e3a")
	inputContainer.BorderSizePixel = 0
	inputContainer.Parent = container

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 10)
	inputCorner.Parent = inputContainer

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = Color3.fromHex("#3a3a5e")
	inputStroke.Thickness = 1
	inputStroke.Parent = inputContainer

	-- Text Input
	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -20, 1, 0)
	textBox.Position = UDim2.new(0.5, 0, 0.5, 0)
	textBox.AnchorPoint = Vector2.new(0.5, 0.5)
	textBox.BackgroundTransparency = 1
	textBox.Text = ""
	textBox.PlaceholderText = "Masukkan kode..."
	textBox.PlaceholderColor3 = Color3.fromHex("#6a6a8e")
	textBox.TextColor3 = Color3.fromHex("#ffffff")
	textBox.TextSize = 16
	textBox.Font = Enum.Font.GothamBold
	textBox.ClearTextOnFocus = false
	textBox.Parent = inputContainer

	-- Status Label
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -50, 0, 20)
	statusLabel.Position = UDim2.new(0.5, 0, 0, 185)
	statusLabel.AnchorPoint = Vector2.new(0.5, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = Color3.fromHex("#a1a1aa")
	statusLabel.TextSize = 12
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Parent = container

	-- Redeem Button
	local redeemButton = Instance.new("TextButton")
	redeemButton.Size = UDim2.new(1, -50, 0, 45)
	redeemButton.Position = UDim2.new(0.5, 0, 0, 215)
	redeemButton.AnchorPoint = Vector2.new(0.5, 0)
	redeemButton.BackgroundColor3 = Color3.fromHex("#6366f1")
	redeemButton.BorderSizePixel = 0
	redeemButton.Text = "🎫 REDEEM CODE"
	redeemButton.TextColor3 = Color3.fromHex("#ffffff")
	redeemButton.TextSize = 16
	redeemButton.Font = Enum.Font.GothamBold
	redeemButton.Parent = container

	local redeemCorner = Instance.new("UICorner")
	redeemCorner.CornerRadius = UDim.new(0, 10)
	redeemCorner.Parent = redeemButton

	-- Redeem Button Gradient
	local redeemGradient = Instance.new("UIGradient")
	redeemGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#6366f1")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#8b5cf6")),
	})
	redeemGradient.Parent = redeemButton

	-- Cancel Button
	local cancelButton = Instance.new("TextButton")
	cancelButton.Size = UDim2.new(1, -50, 0, 35)
	cancelButton.Position = UDim2.new(0.5, 0, 0, 270)
	cancelButton.AnchorPoint = Vector2.new(0.5, 0)
	cancelButton.BackgroundColor3 = Color3.fromHex("#2a2a3e")
	cancelButton.BorderSizePixel = 0
	cancelButton.Text = "Tutup"
	cancelButton.TextColor3 = Color3.fromHex("#a1a1aa")
	cancelButton.TextSize = 14
	cancelButton.Font = Enum.Font.Gotham
	cancelButton.Parent = container

	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0, 8)
	cancelCorner.Parent = cancelButton

	-- Function to update status
	local function updateStatus(text, color)
		statusLabel.Text = text
		statusLabel.TextColor3 = Color3.fromHex(color or "#a1a1aa")
	end

	-- Function to set button loading state
	local function setLoading(loading)
		redeemButton.Active = not loading
		if loading then
			redeemButton.Text = "⏳ Memproses..."
			redeemButton.BackgroundColor3 = Color3.fromHex("#4a4a6e")
		else
			redeemButton.Text = "🎫 REDEEM CODE"
			redeemButton.BackgroundColor3 = Color3.fromHex("#6366f1")
		end
	end

	-- Redeem button click handler
	redeemButton.MouseButton1Click:Connect(function()
		local code = textBox.Text:gsub("%s+", ""):upper() -- Remove spaces and uppercase

		if code == "" then
			updateStatus("⚠️ Masukkan kode terlebih dahulu!", "#eab308")
			return
		end

		setLoading(true)
		updateStatus("🔍 Memeriksa kode...", "#a1a1aa")

		-- Skip if EVENT_CODE_API is nil (handled server-side now)
		if not EVENT_CODE_API then
			setLoading(false)
			updateStatus("ℹ️ Event code dihandle otomatis oleh server", "#3b82f6")
			task.wait(2)
			screenGui:Destroy()
			if onCancel then
				onCancel()
			end
			return
		end

		-- Call Google Sheets API to redeem code
		local apiUrl = EVENT_CODE_API
			.. "?action=redeem&code="
			.. code
			.. "&userId="
			.. userId
			.. "&username="
			.. username

		local success, response = pcall(function()
			return game:HttpGet(apiUrl)
		end)

		if not success then
			setLoading(false)
			updateStatus("❌ Gagal terhubung ke server!", "#ef4444")
			return
		end

		-- Parse response
		local data = nil
		pcall(function()
			data = HttpService:JSONDecode(response)
		end)

		if not data then
			setLoading(false)
			updateStatus("❌ Response tidak valid!", "#ef4444")
			return
		end

		if data.success then
			updateStatus("✅ " .. data.message, "#22c55e")
			task.wait(1)

			-- Destroy this UI
			screenGui:Destroy()

			-- Call success callback with session data
			if onSuccess then
				onSuccess({
					Role = "EVENT",
					Duration = tostring(data.duration) .. " DAYS",
					Expiry = data.expiresAt,
					RemainingDays = data.duration,
					ActivatedAt = os.date("%Y-%m-%d %H:%M:%S"),
					Platform = "mobile",
					CodeUsed = code,
					IsEventAccess = true,
				})
			end
		else
			setLoading(false)
			updateStatus("❌ " .. (data.message or "Code tidak valid!"), "#ef4444")
		end
	end)

	-- Cancel button click handler
	cancelButton.MouseButton1Click:Connect(function()
		screenGui:Destroy()
		if onCancel then
			onCancel()
		end
	end)

	-- Focus text box
	task.delay(0.5, function()
		if textBox and textBox.Parent then
			textBox:CaptureFocus()
		end
	end)

	return screenGui
end

-- ══════════════════════════════════════════════════════════════════
-- CHECK USER EVENT ACCESS STATUS
-- ══════════════════════════════════════════════════════════════════

local function checkEventAccess(userId)
	-- Skip if EVENT_CODE_API is nil (handled server-side now)
	if not EVENT_CODE_API then
		return nil, "Event code handled server-side"
	end

	local apiUrl = EVENT_CODE_API .. "?action=status&userId=" .. userId

	local success, response = pcall(function()
		return game:HttpGet(apiUrl)
	end)

	if not success then
		return nil, "Connection failed"
	end

	local data = nil
	pcall(function()
		data = HttpService:JSONDecode(response)
	end)

	if not data then
		return nil, "Invalid response"
	end

	return data, nil
end

-- ══════════════════════════════════════════════════════════════════
-- LOAD MOBILE UI FUNCTION
-- ══════════════════════════════════════════════════════════════════

local function loadMobileUI(sessionData, loaderGui, updateStatus)
	-- Store session data globally for periodic access check in MobileUI
	getgenv().StarshipSessionData = sessionData

	if updateStatus then
		updateStatus("Loading Starship Mobile...", 0.85)
	end
	task.wait(0.3)

	-- Load Mobile UI Script (from protected API)
	local userId = tostring(LocalPlayer.UserId)
	local mobileScriptSuccess, mobileScript = pcall(function()
		return game:HttpGet(MOBILE_UI_API .. userId)
	end)

	if not mobileScriptSuccess then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Failed to load Mobile UI\n\nConnection Error")
		return false
	end

	if not mobileScript or mobileScript == "" then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Failed to load Mobile UI\n\nEmpty Response")
		return false
	end

	-- Check if response is an error message
	if mobileScript:find("error%(") then
		if loaderGui then
			loaderGui:Destroy()
		end
		local errorMsg = mobileScript:match('error%("(.-)"%)')
		showError(errorMsg or "Mobile UI Access Denied")
		return false
	end

	if updateStatus then
		updateStatus("Launching...", 1.0)
	end
	task.wait(0.4)

	-- Execute Mobile Script
	local func, err = loadstring(mobileScript)
	if not func then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Execution Error:\n" .. tostring(err))
		return false
	end

	-- Smooth exit animation
	if loaderGui then
		local MainFrame = loaderGui:FindFirstChild("Background")
		if MainFrame then
			local Container = MainFrame:FindFirstChild("Container")
			if Container then
				TweenService:Create(Container, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, 0, 0.6, 0),
					BackgroundTransparency = 1,
				}):Play()
			end

			TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
		end

		task.wait(0.5)
		loaderGui:Destroy()
	end

	-- Store session data
	getgenv().StarshipSession = sessionData

	-- ══════════════════════════════════════════════════════════════════
	-- WATERMARK SYSTEM: Embed unique user identifier for leak tracing
	-- Multiple hidden locations make it difficult to remove all traces
	-- ══════════════════════════════════════════════════════════════════
	local wmUserId = tostring(LocalPlayer.UserId)
	local wmHWID = pcall(function()
		return getDeviceHWID()
	end) and getDeviceHWID() or "MOBILE"

	local function generateWatermark()
		local wm = {}
		wm.u = wmUserId -- User ID
		wm.t = os.time() -- Timestamp
		wm.h = type(wmHWID) == "string" and wmHWID:sub(1, 8) or "MOBILE" -- First 8 chars of HWID
		wm.p = "MOBILE" -- Platform
		wm.v = "1.0" -- Version
		-- Create encoded signature
		local sig = wmUserId .. "_" .. os.time() .. "_" .. wm.h
		wm.s = "" -- Signature (encoded)
		for i = 1, #sig do
			wm.s = wm.s .. string.format("%02x", bit32.bxor(string.byte(sig, i), 42))
		end
		return wm
	end

	local _WM = generateWatermark()

	-- Store watermark in multiple hidden locations
	-- Location 1: Global environment (obfuscated key)
	getgenv()["_" .. string.char(83, 87, 77)] = _WM

	-- Location 2: Hidden in game services
	pcall(function()
		local marker = Instance.new("StringValue")
		marker.Name = "_mcfg" .. math.random(1000, 9999)
		marker.Value = HttpService:JSONEncode({ _m = _WM.s, _t = _WM.t })
		marker.Parent = game:GetService("ReplicatedStorage")
		-- Auto-cleanup after 60 seconds (but watermark already in memory)
		task.delay(60, function()
			pcall(function()
				marker:Destroy()
			end)
		end)
	end)

	-- Location 3: Attach to session
	getgenv().StarshipSession._wm = _WM.s
	getgenv().StarshipSession._wt = _WM.t

	-- Location 4: Hidden table in _G with random key
	local wmKey = "_mx" .. tostring(_WM.t):sub(-4)
	_G[wmKey] = { z = _WM.u, y = _WM.h }

	-- Location 5: Store in closure (survives even if globals cleared)
	local _WATERMARK_DATA = _WM -- This persists in the script's closure

	-- Run the mobile script
	func()

	-- ══════════════════════════════════════════════════════════════════
	-- SECURITY CLEANUP: Remove sensitive data from global environment
	-- This prevents hackers from accessing modules via getgenv()/_G
	-- ══════════════════════════════════════════════════════════════════
	task.spawn(function()
		task.wait(10) -- Wait for script to fully initialize (mobile needs more time)

		-- Clear module references from global scope
		if getgenv().StarshipModules then
			getgenv().StarshipModules = nil
		end

		-- Clear AnimDB reference
		if _G.StarshipAnimDB then
			_G.StarshipAnimDB = nil
		end

		-- Clear temp variables
		if getgenv().StarshipTemp then
			getgenv().StarshipTemp = nil
		end

		-- Note: StarshipSession, StarshipWindow, StarshipWindUI kept for ban system
		-- They are needed for periodic ban check to function properly
	end)

	-- ══════════════════════════════════════════════════════════════════
	-- REAL-TIME STATUS MONITORING (MOBILE)
	-- Check status every 5 minutes and close UI if maintenance/offline
	-- ══════════════════════════════════════════════════════════════════
	task.spawn(function()
		task.wait(60) -- Wait 1 minute before first check

		while true do
			task.wait(300) -- Check every 5 minutes

			-- Check if StarshipCore is still active
			if not getgenv().StarshipSession then
				break -- Script was closed, stop monitoring
			end

			-- Check system status
			local statusCheckUrl = SECURE_API_URL .. "/api/tags?action=status"
			local success, response = pcall(function()
				return game:HttpGet(statusCheckUrl)
			end)

			if success and response then
				local statusData = nil
				pcall(function()
					statusData = HttpService:JSONDecode(response)
				end)

				if statusData and statusData.success then
					if
						statusData.status == "maintenance"
						or statusData.status == "offline"
						or statusData.status == "updating"
					then
						-- Status changed to maintenance/offline/updating - close UI
						-- (Debug print removed for production)

						-- Try to close the main UI
						pcall(function()
							if getgenv().StarshipWindow then
								getgenv().StarshipWindow:destroy()
							end
						end)
						pcall(function()
							if getgenv().StarshipWindUI then
								getgenv().StarshipWindUI:Destroy()
							end
						end)
						pcall(function()
							local CoreGui = game:GetService("CoreGui")
							local mobileUI = CoreGui:FindFirstChild("StarshipMobile")
							if mobileUI then
								mobileUI:Destroy()
							end
						end)
						pcall(function()
							local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
							if PlayerGui then
								local mobileUI = PlayerGui:FindFirstChild("StarshipMobile")
								if mobileUI then
									mobileUI:Destroy()
								end
							end
						end)

						-- Show maintenance message (reuse existing UI code from main)
						local screenGui = Instance.new("ScreenGui")
						screenGui.Name = "StarshipMaintenance"
						screenGui.ResetOnSpawn = false
						screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
						screenGui.IgnoreGuiInset = true

						pcall(function()
							screenGui.Parent = game:GetService("CoreGui")
						end)
						if not screenGui.Parent then
							screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
						end

						local background = Instance.new("Frame")
						background.Size = UDim2.new(1, 0, 1, 0)
						background.BackgroundColor3 = Color3.fromHex("#0a0a0f")
						background.BorderSizePixel = 0
						background.Parent = screenGui

						local container = Instance.new("Frame")
						container.Size = UDim2.new(0, 340, 0, 240)
						container.Position = UDim2.new(0.5, 0, 0.5, 0)
						container.AnchorPoint = Vector2.new(0.5, 0.5)
						container.BackgroundColor3 = Color3.fromHex("#1a1a2e")
						container.BorderSizePixel = 0
						container.Parent = background
						Instance.new("UICorner", container).CornerRadius = UDim.new(0, 16)

						local accentColor = Color3.fromHex("#ff9800")
						if statusData.status == "offline" then
							accentColor = Color3.fromHex("#f44336")
						elseif statusData.status == "updating" then
							accentColor = Color3.fromHex("#2196f3")
						end

						local containerStroke = Instance.new("UIStroke")
						containerStroke.Color = accentColor
						containerStroke.Thickness = 2
						containerStroke.Parent = container

						local title = Instance.new("TextLabel")
						title.Size = UDim2.new(1, 0, 0, 60)
						title.Position = UDim2.new(0.5, 0, 0, 30)
						title.AnchorPoint = Vector2.new(0.5, 0)
						title.BackgroundTransparency = 1
						title.Text = statusData.emoji .. " " .. string.upper(statusData.label)
						title.TextColor3 = accentColor
						title.TextSize = 24
						title.Font = Enum.Font.GothamBold
						title.Parent = container

						local msg = Instance.new("TextLabel")
						msg.Size = UDim2.new(1, -40, 0, 60)
						msg.Position = UDim2.new(0.5, 0, 0, 100)
						msg.AnchorPoint = Vector2.new(0.5, 0)
						msg.BackgroundTransparency = 1
						msg.Text = statusData.message .. "\n\nPlease try again later."
						msg.TextColor3 = Color3.fromHex("#a1a1aa")
						msg.TextSize = 14
						msg.Font = Enum.Font.Gotham
						msg.TextWrapped = true
						msg.Parent = container

						local closeBtn = Instance.new("TextButton")
						closeBtn.Size = UDim2.new(0, 100, 0, 35)
						closeBtn.Position = UDim2.new(0.5, 0, 1, -40)
						closeBtn.AnchorPoint = Vector2.new(0.5, 0)
						closeBtn.BackgroundColor3 = accentColor
						closeBtn.Text = "Close"
						closeBtn.TextColor3 = Color3.fromHex("#ffffff")
						closeBtn.TextSize = 14
						closeBtn.Font = Enum.Font.GothamBold
						closeBtn.BorderSizePixel = 0
						closeBtn.Parent = container
						Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

						closeBtn.MouseButton1Click:Connect(function()
							screenGui:Destroy()
						end)

						-- Clear session
						getgenv().StarshipSession = nil

						break -- Stop monitoring
					end
				end
			end
		end
	end)

	return true
end

-- ══════════════════════════════════════════════════════════════════
-- MAIN AUTHENTICATION FUNCTION
-- ══════════════════════════════════════════════════════════════════

local function main()
	-- 🔒 CHECK SYSTEM STATUS FIRST
	local statusUrl = SECURE_API_URL .. "/api/tags?action=status"
	local statusOk, statusResponse = pcall(function()
		return game:HttpGet(statusUrl)
	end)

	if statusOk and statusResponse then
		local statusData = nil
		pcall(function()
			statusData = HttpService:JSONDecode(statusResponse)
		end)

		if statusData and statusData.success then
			if
				statusData.status == "maintenance"
				or statusData.status == "offline"
				or statusData.status == "updating"
			then
				-- Show maintenance UI for mobile
				local screenGui = Instance.new("ScreenGui")
				screenGui.Name = "StarshipMaintenance"
				screenGui.ResetOnSpawn = false
				screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
				screenGui.IgnoreGuiInset = true

				pcall(function()
					screenGui.Parent = game:GetService("CoreGui")
				end)
				if not screenGui.Parent then
					screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
				end

				-- Background
				local background = Instance.new("Frame")
				background.Size = UDim2.new(1, 0, 1, 0)
				background.BackgroundColor3 = Color3.fromHex("#0a0a0f")
				background.BorderSizePixel = 0
				background.Parent = screenGui

				-- Container
				local container = Instance.new("Frame")
				container.Size = UDim2.new(0, 340, 0, 240)
				container.Position = UDim2.new(0.5, 0, 0.5, 0)
				container.AnchorPoint = Vector2.new(0.5, 0.5)
				container.BackgroundColor3 = Color3.fromHex("#1a1a2e")
				container.BorderSizePixel = 0
				container.Parent = background

				local containerCorner = Instance.new("UICorner")
				containerCorner.CornerRadius = UDim.new(0, 16)
				containerCorner.Parent = container

				-- Accent color based on status
				local accentColor = Color3.fromHex("#ff9800")
				if statusData.status == "offline" then
					accentColor = Color3.fromHex("#f44336")
				elseif statusData.status == "updating" then
					accentColor = Color3.fromHex("#2196f3")
				end

				local containerStroke = Instance.new("UIStroke")
				containerStroke.Color = accentColor
				containerStroke.Thickness = 2
				containerStroke.Transparency = 0.3
				containerStroke.Parent = container

				-- Status Icon
				local icon = Instance.new("TextLabel")
				icon.Size = UDim2.new(1, 0, 0, 60)
				icon.Position = UDim2.new(0.5, 0, 0, 20)
				icon.AnchorPoint = Vector2.new(0.5, 0)
				icon.BackgroundTransparency = 1
				icon.Text = statusData.emoji or "🔧"
				icon.TextSize = 48
				icon.Font = Enum.Font.GothamBold
				icon.Parent = container

				-- Title
				local title = Instance.new("TextLabel")
				title.Size = UDim2.new(1, -40, 0, 30)
				title.Position = UDim2.new(0.5, 0, 0, 85)
				title.AnchorPoint = Vector2.new(0.5, 0)
				title.BackgroundTransparency = 1
				title.Text = "⚠️ " .. string.upper(statusData.label or "MAINTENANCE")
				title.TextColor3 = accentColor
				title.TextSize = 20
				title.Font = Enum.Font.GothamBold
				title.Parent = container

				-- Message
				local msg = Instance.new("TextLabel")
				msg.Size = UDim2.new(1, -40, 0, 50)
				msg.Position = UDim2.new(0.5, 0, 0, 120)
				msg.AnchorPoint = Vector2.new(0.5, 0)
				msg.BackgroundTransparency = 1
				msg.Text = statusData.message or "System is under maintenance"
				msg.TextColor3 = Color3.fromHex("#a1a1aa")
				msg.TextSize = 14
				msg.Font = Enum.Font.Gotham
				msg.TextWrapped = true
				msg.Parent = container

				-- Info
				local info = Instance.new("TextLabel")
				info.Size = UDim2.new(1, -40, 0, 25)
				info.Position = UDim2.new(0.5, 0, 0, 170)
				info.AnchorPoint = Vector2.new(0.5, 0)
				info.BackgroundTransparency = 1
				info.Text = "Please try again later."
				info.TextColor3 = Color3.fromHex("#6a6a8e")
				info.TextSize = 12
				info.Font = Enum.Font.Gotham
				info.Parent = container

				-- Close button
				local closeBtn = Instance.new("TextButton")
				closeBtn.Size = UDim2.new(0, 100, 0, 35)
				closeBtn.Position = UDim2.new(0.5, 0, 1, -40)
				closeBtn.AnchorPoint = Vector2.new(0.5, 0)
				closeBtn.BackgroundColor3 = accentColor
				closeBtn.Text = "Close"
				closeBtn.TextColor3 = Color3.fromHex("#ffffff")
				closeBtn.TextSize = 14
				closeBtn.Font = Enum.Font.GothamBold
				closeBtn.BorderSizePixel = 0
				closeBtn.Parent = container

				local closeCorner = Instance.new("UICorner")
				closeCorner.CornerRadius = UDim.new(0, 8)
				closeCorner.Parent = closeBtn

				closeBtn.MouseButton1Click:Connect(function()
					screenGui:Destroy()
				end)

				return -- Stop execution
			end
		end
	end

	local loaderGui, updateStatus = createLoadingUI()

	-- Step 1: Initialize
	updateStatus("Initializing...", 0.1)
	task.wait(0.3)

	-- Step 2: Get User ID
	updateStatus("Detecting user...", 0.2)
	local userId = tostring(LocalPlayer.UserId)
	local username = LocalPlayer.Name
	task.wait(0.2)

	-- Step 3: Check if user has active event access first
	updateStatus("Checking event access...", 0.3)
	local eventData, eventError = checkEventAccess(userId)

	if eventData and eventData.success and eventData.hasAccess then
		-- User has active event access!
		updateStatus("Event access found!", 0.5)
		task.wait(0.3)

		local sessionData = {
			Role = "EVENT",
			Duration = tostring(eventData.remainingDays) .. " DAYS",
			Expiry = eventData.expiresAt,
			RemainingDays = eventData.remainingDays,
			RemainingHours = eventData.remainingHours,
			ActivatedAt = os.date("%Y-%m-%d %H:%M:%S"),
			Platform = "mobile",
			CodeUsed = eventData.codeUsed,
			IsEventAccess = true,
			Username = username,
		}

		updateStatus("Access granted! (" .. tostring(eventData.remainingDays or "N/A") .. " days left)", 0.7)
		task.wait(0.3)

		loadMobileUI(sessionData, loaderGui, updateStatus)
		return
	end

	-- Step 4: Authenticate with MOBILE-SPECIFIC Server (Separate from PC)
	updateStatus("Authenticating...", 0.4)

	-- Detect device HWID for binding
	local deviceHWID = getDeviceHWID()
	-- HWID detection complete (debug print removed for production)

	-- Call mobile-load API (separate whitelist from PC)
	local authUrl = MOBILE_AUTH_API .. "?userId=" .. userId .. "&hwid=" .. HttpService:UrlEncode(deviceHWID)
	local authSuccess, authResponse = pcall(function()
		return game:HttpGet(authUrl)
	end)

	if not authSuccess then
		if loaderGui then
			loaderGui:Destroy()
		end
		-- Show event code UI as fallback
		showEventCodeUI(function(sessionData)
			-- On success, load mobile UI
			local newLoaderGui, newUpdateStatus = createLoadingUI()
			newUpdateStatus("Access granted!", 0.7)
			task.wait(0.3)
			loadMobileUI(sessionData, newLoaderGui, newUpdateStatus)
		end, function()
			-- On cancel, show error
			showError("Connection Failed\nServer Unreachable")
		end)
		return
	end

	updateStatus("Verifying mobile license...", 0.5)
	task.wait(0.2)

	-- Parse response
	local data = nil
	pcall(function()
		data = HttpService:JSONDecode(authResponse)
	end)

	if not data then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Server Error\nInvalid Response")
		return
	end

	-- Check status
	if data.status == "denied" then
		if loaderGui then
			loaderGui:Destroy()
		end

		-- Check if event system is active (from server response)
		if data.isEventActive == false then
			-- Event system disabled -> Show error directly
			local errorMsg = data.message or "Access Denied"
			if data.hint then
				errorMsg = errorMsg .. "\n\n" .. data.hint
			end
			showError(errorMsg)
			return
		end

		-- Instead of showing error directly, show event code UI
		showEventCodeUI(function(sessionData)
			-- On success, load mobile UI
			local newLoaderGui, newUpdateStatus = createLoadingUI()
			newUpdateStatus("Access granted!", 0.7)
			task.wait(0.3)
			loadMobileUI(sessionData, newLoaderGui, newUpdateStatus)
		end, function()
			-- On cancel, show original error
			local errorMsg = data.message or "Not Whitelisted for Mobile"
			if data.hint then
				errorMsg = errorMsg .. "\n\n" .. data.hint
			end
			showError(errorMsg)
		end)
		return
	elseif data.status ~= "success" then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Error: " .. tostring(data.error or "Unknown"))
		return
	end

	updateStatus("Access granted!", 0.7)
	task.wait(0.2)

	-- Store session data for main script
	local sessionData = {
		Role = data.role or "MOBILE VIP",
		Duration = data.duration or "LIFETIME",
		Expiry = data.expiry,
		RemainingDays = data.remainingDays,
		ActivatedAt = data.activatedAt,
		Platform = "mobile",
		DeviceCount = data.deviceCount,
		MaxDevices = data.maxDevices,
		Username = data.username,
		IsEventAccess = false,
	}

	loadMobileUI(sessionData, loaderGui, updateStatus)
end

-- Execute
main()
