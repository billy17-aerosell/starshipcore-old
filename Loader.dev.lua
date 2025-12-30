local HttpService = game:GetService("HttpService")
-- [DEV MODE] Menggunakan Localhost
local VERCEL_URL = "http://localhost:3000"
local ENCRYPTION_KEY = "Starship_X7k9P2mQ_2025"
local FOLDER_NAME = "StarshipCore"
local MODULES_FOLDER = FOLDER_NAME .. "/Modules"
local TABS_FOLDER = MODULES_FOLDER .. "/Tabs"
local MODULES = { "Config.lua", "UI.lua", "Intro.lua", "Animations.lua", "Locale.lua", "CloudRecording.lua" }
local TABS = { "Dashboard.lua", "Tools.lua", "Warp.lua", "Helper.lua", "Fun.lua", "Emotes.lua", "ConfigTab.lua" }

-- [DEV MODE] Set global URLs untuk CloudRecording dan modules lainnya
_G.StarshipServerURL = VERCEL_URL
_G.StarshipBaseURL = VERCEL_URL
_G.StarshipServerMode = true
_G.StarshipEventCode = "DEV" -- Default event code for dev mode

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

local function decrypt(encryptedBase64)
	local encrypted = base64Decode(encryptedBase64)
	return xorEncrypt(encrypted, ENCRYPTION_KEY)
end

local function setupFolders()
	if not isfolder(FOLDER_NAME) then
		makefolder(FOLDER_NAME)
	end
	if not isfolder(MODULES_FOLDER) then
		makefolder(MODULES_FOLDER)
	end
	if not isfolder(TABS_FOLDER) then
		makefolder(TABS_FOLDER)
	end
end

-- [DEV MODE] Download module via API (returns plain text in dev mode)
local function downloadModule(moduleName, savePath)
	local url = VERCEL_URL .. "/api/get-module?name=" .. moduleName
	local success, content = pcall(function()
		return game:HttpGet(url)
	end)

	if success and content and content ~= "" and not content:find("<!DOCTYPE") and not content:find('"error"') then
		writefile(savePath, content)
		return true
	else
		warn("[DEV] Failed to download module: " .. moduleName)
		if content then
			warn("[DEV] Response: " .. string.sub(content, 1, 200))
		end
		return false
	end
end

local function downloadModules(statusCallback)
	local totalFiles = #MODULES + #TABS
	local downloaded = 0

	-- Download main modules via API
	for _, moduleName in ipairs(MODULES) do
		local savePath = MODULES_FOLDER .. "/" .. moduleName
		if downloadModule(moduleName, savePath) then
			downloaded = downloaded + 1
			if statusCallback then
				statusCallback("Downloading: " .. moduleName, downloaded / totalFiles)
			end
		end
	end

	-- Download tab modules via API
	for _, tabName in ipairs(TABS) do
		local savePath = TABS_FOLDER .. "/" .. tabName
		-- API expects "Tabs/Dashboard.lua" format
		if downloadModule("Tabs/" .. tabName, savePath) then
			downloaded = downloaded + 1
			if statusCallback then
				statusCallback("Downloading: Tabs/" .. tabName, downloaded / totalFiles)
			end
		end
	end

	-- Store AnimDB in _G for easier access by Tools.lua and other modules
	local animPath = MODULES_FOLDER .. "/Animations.lua"
	if isfile(animPath) then
		local success, result = pcall(function()
			return loadstring(readfile(animPath))()
		end)
		if success and result then
			_G.StarshipAnimDB = result
		end
	end

	return downloaded == totalFiles
end

local function createLoadingUI()
	local CoreGui = game:GetService("CoreGui")
	local TweenService = game:GetService("TweenService")
	local LoaderGui = Instance.new("ScreenGui")
	LoaderGui.Name = "StarshipIntro"
	LoaderGui.Parent = CoreGui
	LoaderGui.IgnoreGuiInset = true
	LoaderGui.DisplayOrder = 10000

	local MainFrame = Instance.new("Frame", LoaderGui)
	MainFrame.Size = UDim2.new(1, 0, 1, 0)
	MainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	MainFrame.BackgroundTransparency = 0.2

	-- Floating Particles Container
	local ParticleContainer = Instance.new("Frame", MainFrame)
	ParticleContainer.Size = UDim2.new(1, 0, 1, 0)
	ParticleContainer.BackgroundTransparency = 1
	ParticleContainer.ClipsDescendants = true

	-- Create Floating Particles
	task.spawn(function()
		for i = 1, 40 do
			if not LoaderGui or not LoaderGui.Parent then
				break
			end

			local particleType = math.random(1, 3)
			local particle = Instance.new("Frame", ParticleContainer)

			local baseSize = math.random(3, 8)
			particle.Size = UDim2.new(0, baseSize, 0, baseSize)
			particle.Position = UDim2.new(math.random(), 0, math.random(), 0)
			particle.BackgroundColor3 = Color3.fromRGB(90, 110, 245)
			particle.BackgroundTransparency = math.random() * 0.4 + 0.3
			particle.BorderSizePixel = 0

			local corner = Instance.new("UICorner", particle)
			if particleType == 1 then
				corner.CornerRadius = UDim.new(1, 0)
			elseif particleType == 2 then
				corner.CornerRadius = UDim.new(0, 2)
			else
				corner.CornerRadius = UDim.new(0, 1)
				particle.Rotation = 45
			end

			local glow = Instance.new("UIStroke", particle)
			glow.Color = Color3.fromRGB(90, 110, 245)
			glow.Thickness = 1
			glow.Transparency = 0.7

			task.spawn(function()
				local startY = particle.Position.Y.Scale
				local startX = particle.Position.X.Scale
				local swayOffset = math.random() * math.pi * 2
				local swaySpeed = math.random(20, 40) / 10
				local floatSpeed = math.random(15, 30) / 10000

				while particle and particle.Parent do
					local newY = startY - floatSpeed
					if newY < -0.15 then
						newY = 1.15
						startY = 1.15
						startX = math.random()
					end
					startY = newY

					local sway = math.sin(os.clock() * swaySpeed + swayOffset) * 0.02
					particle.Position = UDim2.new(startX + sway, 0, newY, 0)

					particle.BackgroundTransparency = 0.3 + math.sin(os.clock() * 2 + i) * 0.25
					if glow then
						glow.Transparency = 0.5 + math.sin(os.clock() * 3 + i) * 0.3
					end

					task.wait(0.02)
				end
			end)
			task.wait(0.03)
		end
	end)

	-- Logo Icon
	local LogoContainer = Instance.new("Frame", MainFrame)
	LogoContainer.Size = UDim2.new(0, 100, 0, 100)
	LogoContainer.Position = UDim2.new(0.5, -50, 0.35, 0)
	LogoContainer.BackgroundTransparency = 1

	local Logo = Instance.new("TextLabel", LogoContainer)
	Logo.Text = "S"
	Logo.Size = UDim2.new(1, 0, 1, 0)
	Logo.BackgroundTransparency = 1
	Logo.TextColor3 = Color3.fromRGB(90, 110, 245)
	Logo.Font = Enum.Font.GothamBlack
	Logo.TextSize = 72
	Logo.TextTransparency = 0

	local LogoGlow = Instance.new("UIStroke", Logo)
	LogoGlow.Color = Color3.fromRGB(90, 110, 245)
	LogoGlow.Thickness = 3
	LogoGlow.Transparency = 0.5

	-- Title Text
	local Title = Instance.new("TextLabel", MainFrame)
	Title.Text = "STARSHIP"
	Title.Size = UDim2.new(1, 0, 0, 50)
	Title.Position = UDim2.new(0, 0, 0.48, 0)
	Title.BackgroundTransparency = 1
	Title.TextColor3 = Color3.fromRGB(90, 110, 245)
	Title.Font = Enum.Font.GothamBlack
	Title.TextSize = 42
	Title.TextTransparency = 0
	Title.RichText = true

	-- Subtitle / Status Text
	local Sub = Instance.new("TextLabel", MainFrame)
	Sub.Text = "[DEV MODE] INITIALIZING..."
	Sub.Size = UDim2.new(1, 0, 0, 25)
	Sub.Position = UDim2.new(0, 0, 0.55, 0)
	Sub.BackgroundTransparency = 1
	Sub.TextColor3 = Color3.fromRGB(255, 220, 60)
	Sub.Font = Enum.Font.GothamMedium
	Sub.TextSize = 14
	Sub.TextTransparency = 0

	-- Progress Bar Container
	local ProgressContainer = Instance.new("Frame", MainFrame)
	ProgressContainer.Size = UDim2.new(0.3, 0, 0, 4)
	ProgressContainer.Position = UDim2.new(0.35, 0, 0.6, 0)
	ProgressContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	ProgressContainer.BackgroundTransparency = 0
	Instance.new("UICorner", ProgressContainer).CornerRadius = UDim.new(1, 0)

	local ProgressFill = Instance.new("Frame", ProgressContainer)
	ProgressFill.Size = UDim2.new(0, 0, 1, 0)
	ProgressFill.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
	Instance.new("UICorner", ProgressFill).CornerRadius = UDim.new(1, 0)

	-- Progress Percentage
	local ProgressText = Instance.new("TextLabel", MainFrame)
	ProgressText.Text = "0%"
	ProgressText.Size = UDim2.new(1, 0, 0, 20)
	ProgressText.Position = UDim2.new(0, 0, 0.63, 0)
	ProgressText.BackgroundTransparency = 1
	ProgressText.TextColor3 = Color3.fromRGB(255, 220, 60)
	ProgressText.Font = Enum.Font.GothamBold
	ProgressText.TextSize = 12
	ProgressText.TextTransparency = 0

	-- Welcome Message
	local WelcomeMsg = Instance.new("TextLabel", MainFrame)
	WelcomeMsg.Text = "[DEV] " .. game:GetService("Players").LocalPlayer.Name
	WelcomeMsg.Size = UDim2.new(1, 0, 0, 20)
	WelcomeMsg.Position = UDim2.new(0, 0, 0.28, 0)
	WelcomeMsg.BackgroundTransparency = 1
	WelcomeMsg.TextColor3 = Color3.fromRGB(150, 150, 160)
	WelcomeMsg.Font = Enum.Font.Gotham
	WelcomeMsg.TextSize = 14
	WelcomeMsg.TextTransparency = 0

	-- Logo Rainbow Animation
	task.spawn(function()
		local t = 0
		while Logo and Logo.Parent do
			t = t + 0.02
			local c = Color3.fromHSV(t % 1, 0.9, 1)
			Logo.TextColor3 = c
			LogoGlow.Color = c
			local pulse = 1 + math.sin(t * 5) * 0.05
			Logo.TextSize = 72 * pulse
			task.wait(0.02)
		end
	end)

	return LoaderGui,
		function(text, progress)
			Sub.Text = "[DEV] " .. text
			TweenService:Create(ProgressFill, TweenInfo.new(0.3), { Size = UDim2.new(progress, 0, 1, 0) }):Play()
			ProgressText.Text = math.floor(progress * 100) .. "%"
		end
end

local function showError(message)
	local CoreGui = game:GetService("CoreGui")
	local Players = game:GetService("Players")
	local ErrorGui = Instance.new("ScreenGui")
	ErrorGui.Name = "StarshipError"
	ErrorGui.Parent = CoreGui
	local Frame = Instance.new("Frame", ErrorGui)
	Frame.Size = UDim2.new(0, 320, 0, 110)
	Frame.Position = UDim2.new(0.5, -160, 0.5, -55)
	Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)
	local Title = Instance.new("TextLabel", Frame)
	Title.Text = "[DEV] STARSHIP - ERROR"
	Title.Size = UDim2.new(1, 0, 0, 30)
	Title.Position = UDim2.new(0, 0, 0, 5)
	Title.BackgroundTransparency = 1
	Title.TextColor3 = Color3.fromRGB(255, 220, 60)
	Title.Font = Enum.Font.GothamBold
	Title.TextSize = 16
	local Msg = Instance.new("TextLabel", Frame)
	Msg.Text = message .. "\n\nUser ID: " .. tostring(Players.LocalPlayer.UserId)
	Msg.Size = UDim2.new(1, -20, 0, 60)
	Msg.Position = UDim2.new(0, 10, 0, 35)
	Msg.BackgroundTransparency = 1
	Msg.TextColor3 = Color3.fromRGB(200, 200, 200)
	Msg.Font = Enum.Font.Gotham
	Msg.TextSize = 12
	Msg.TextWrapped = true
	task.wait(5)
	ErrorGui:Destroy()
end

-- [DEV MODE] API URL
local SECURE_API_URL = "http://localhost:3000"

local function main()
	-- [DEV MODE] Option to skip intro for faster testing
	local DEV_SKIP_INTRO = true

	local loaderGui, updateStatus

	if not DEV_SKIP_INTRO then
		loaderGui, updateStatus = createLoadingUI()
		updateStatus("Setting up environment...", 0.1)
		setupFolders()
		task.wait(0.2)

		updateStatus("Downloading modules via API...", 0.2)
		downloadModules(function(text, progress)
			updateStatus(text, 0.2 + (progress * 0.3))
		end)

		updateStatus("Authenticating...", 0.6)
		task.wait(0.5)
	else
		-- Quick setup without UI
		setupFolders()
		print("[DEV] Setting up folders...")
		print("[DEV] Downloading modules via secure API...")
		downloadModules(function(text, progress)
			print("[DEV] " .. text .. " (" .. math.floor(progress * 100) .. "%)")
		end)
		print("[DEV] Modules downloaded!")
		-- Dummy function to prevent nil errors
		updateStatus = function() end
	end

	local userId = tostring(game:GetService("Players").LocalPlayer.UserId)
	local targetUrl = SECURE_API_URL .. "/api/load?user=" .. userId

	print("[DEV] Fetching main script from: " .. targetUrl)

	local success, response = pcall(function()
		return game:HttpGet(targetUrl)
	end)

	if not success then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Connection Failed: Server Unreachable\n" .. tostring(response))
		return
	end

	local data = nil
	pcall(function()
		data = HttpService:JSONDecode(response)
	end)

	if not data then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Server Error: Invalid Response")
		return
	end

	if data.status == "denied" then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("ACCESS DENIED\n" .. (data.message or "Not Whitelisted"))
		return
	elseif data.status ~= "success" then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Server Error: " .. tostring(data.error or "Unknown"))
		return
	end

	if not DEV_SKIP_INTRO then
		updateStatus("Decrypting Secure Payload...", 0.8)
	else
		print("[DEV] Decrypting main script...")
	end

	local dynamicKey = data.key
	local encryptedBlob = data.blob

	if not dynamicKey or not encryptedBlob then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Security Error: Missing Key/Blob")
		return
	end

	local encryptedString = base64Decode(encryptedBlob)
	local decryptedCode = xorEncrypt(encryptedString, dynamicKey)

	-- Remove BOM if present
	if string.byte(decryptedCode, 1, 3) == "\239\187\191" then
		decryptedCode = string.sub(decryptedCode, 4)
	end

	-- Pass Session Data to Main Script
	getgenv().StarshipSession = {
		Role = "OWNER", -- Force OWNER in DEV mode for all features
		Duration = data.duration or "LIFETIME",
		Expiry = data.expiry,
		DevMode = true,
	}

	if not DEV_SKIP_INTRO and updateStatus then
		updateStatus("Launching Starship...", 1.0)
		task.wait(0.3)
	else
		print("[DEV] Launching Starship...")
	end

	local func, err = loadstring(decryptedCode)
	if not func then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Execution Error: " .. tostring(err))
		return
	end

	-- Smooth Exit Animation (Skip in dev mode)
	if loaderGui and not DEV_SKIP_INTRO then
		local TweenService = game:GetService("TweenService")

		for _, element in pairs(loaderGui:GetDescendants()) do
			if element:IsA("TextLabel") or element:IsA("TextButton") then
				TweenService:Create(element, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 1,
				}):Play()
			elseif element:IsA("Frame") and element.Name ~= "Frame" then
				TweenService:Create(element, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 1,
				}):Play()
			elseif element:IsA("UIStroke") then
				TweenService:Create(element, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 1,
				}):Play()
			elseif element:IsA("ImageLabel") then
				TweenService:Create(element, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					ImageTransparency = 1,
				}):Play()
			end
		end

		task.wait(0.5)
		getgenv().StarshipIntroComplete = true
		loaderGui:Destroy()
	end

	print("[DEV] ✅ Starship loaded successfully!")
	local success, err = pcall(func)
	if not success then
		warn("[DEV] ❌ Script execution error: " .. tostring(err))
	end
end

main()
