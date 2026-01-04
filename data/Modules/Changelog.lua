-- Changelog System for StarshipCore
-- Fetches changelog from server and shows popup if there's a new version

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local Changelog = {}

-- Configuration
local SERVER_URL = _G.StarshipServerURL or "https://starship-core.my.id"
local CONFIG_FILE = "StarshipCore/config.json"
local CURRENT_VERSION = "1.4.0" -- Update this when releasing new versions

-- Colors
local COLORS = {
	Background = Color3.fromRGB(20, 20, 30),
	Header = Color3.fromRGB(90, 110, 245),
	Text = Color3.fromRGB(220, 220, 230),
	TextDim = Color3.fromRGB(140, 140, 160),
	Accent = Color3.fromRGB(90, 110, 245),
	Green = Color3.fromRGB(80, 200, 120),
	Close = Color3.fromRGB(255, 80, 80),
}

-- Helper: Safe file operations
local function safeReadFile(path)
	local success, result = pcall(function()
		if isfile and isfile(path) then
			return readfile(path)
		end
		return nil
	end)
	return success and result or nil
end

local function safeWriteFile(path, content)
	pcall(function()
		if writefile then
			writefile(path, content)
		end
	end)
end

-- Get last seen version from config
function Changelog.GetLastSeenVersion()
	local content = safeReadFile(CONFIG_FILE)
	if content then
		local success, data = pcall(function()
			return HttpService:JSONDecode(content)
		end)
		if success and data and data.lastSeenVersion then
			return data.lastSeenVersion
		end
	end
	return "0.0.0" -- First time user
end

-- Save last seen version
function Changelog.SaveLastSeenVersion(version)
	local content = safeReadFile(CONFIG_FILE)
	local data = {}

	if content then
		local success, parsed = pcall(function()
			return HttpService:JSONDecode(content)
		end)
		if success and parsed then
			data = parsed
		end
	end

	data.lastSeenVersion = version

	local success, json = pcall(function()
		return HttpService:JSONEncode(data)
	end)

	if success then
		safeWriteFile(CONFIG_FILE, json)
	end
end

-- Fetch changelog from server
function Changelog.FetchChangelog()
	local url = SERVER_URL .. "/changelog.json?t=" .. os.time() -- Cache bust

	warn("[Changelog] Fetching from: " .. url)

	local success, response = pcall(function()
		return game:HttpGet(url)
	end)

	if not success or not response then
		warn("[Changelog] Fetch failed:", response or "no response")
		return nil
	end

	warn("[Changelog] Response received, length: " .. #response)

	local parseSuccess, data = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if not parseSuccess or not data then
		warn("[Changelog] Parse failed")
		return nil
	end

	warn("[Changelog] Parsed successfully, version: " .. tostring(data.currentVersion))

	return data
end

-- Compare versions (returns true if v1 > v2)
function Changelog.IsNewerVersion(v1, v2)
	local function parseVersion(v)
		local major, minor, patch = v:match("(%d+)%.(%d+)%.(%d+)")
		return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
	end

	local m1, n1, p1 = parseVersion(v1)
	local m2, n2, p2 = parseVersion(v2)

	if m1 ~= m2 then
		return m1 > m2
	end
	if n1 ~= n2 then
		return n1 > n2
	end
	return p1 > p2
end

-- Create changelog modal UI
-- If waitForDismiss is true, function will wait until user closes modal
function Changelog.ShowModal(changelogData, waitForDismiss)
	local dismissed = false
	-- Remove existing modal if any
	local existing = CoreGui:FindFirstChild("StarshipChangelog")
	if existing then
		existing:Destroy()
	end

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "StarshipChangelog"
	ScreenGui.Parent = CoreGui
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.DisplayOrder = 9999

	-- Background overlay
	local Overlay = Instance.new("Frame", ScreenGui)
	Overlay.Size = UDim2.new(1, 0, 1, 0)
	Overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	Overlay.BackgroundTransparency = 0.5
	Overlay.BorderSizePixel = 0

	-- Main modal
	local Modal = Instance.new("Frame", ScreenGui)
	Modal.Size = UDim2.new(0, 400, 0, 450)
	Modal.Position = UDim2.new(0.5, -200, 0.5, -225)
	Modal.BackgroundColor3 = COLORS.Background
	Modal.BorderSizePixel = 0
	Instance.new("UICorner", Modal).CornerRadius = UDim.new(0, 12)

	-- Accent bar
	local AccentBar = Instance.new("Frame", Modal)
	AccentBar.Size = UDim2.new(1, 0, 0, 4)
	AccentBar.BackgroundColor3 = COLORS.Header
	AccentBar.BorderSizePixel = 0
	Instance.new("UICorner", AccentBar).CornerRadius = UDim.new(0, 12)

	-- Header
	local Header = Instance.new("Frame", Modal)
	Header.Size = UDim2.new(1, 0, 0, 50)
	Header.Position = UDim2.new(0, 0, 0, 4)
	Header.BackgroundTransparency = 1

	local TitleIcon = Instance.new("TextLabel", Header)
	TitleIcon.Text = "🎉"
	TitleIcon.Size = UDim2.new(0, 40, 1, 0)
	TitleIcon.Position = UDim2.new(0, 10, 0, 0)
	TitleIcon.BackgroundTransparency = 1
	TitleIcon.TextSize = 24

	local Title = Instance.new("TextLabel", Header)
	Title.Text = "What's New in v" .. (changelogData.currentVersion or CURRENT_VERSION)
	Title.Size = UDim2.new(1, -100, 1, 0)
	Title.Position = UDim2.new(0, 50, 0, 0)
	Title.BackgroundTransparency = 1
	Title.TextColor3 = COLORS.Header
	Title.Font = Enum.Font.GothamBold
	Title.TextSize = 18
	Title.TextXAlignment = Enum.TextXAlignment.Left

	-- Close button
	local CloseBtn = Instance.new("TextButton", Header)
	CloseBtn.Size = UDim2.new(0, 35, 0, 35)
	CloseBtn.Position = UDim2.new(1, -45, 0.5, -17)
	CloseBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	CloseBtn.Text = "✕"
	CloseBtn.TextColor3 = COLORS.Close
	CloseBtn.Font = Enum.Font.GothamBold
	CloseBtn.TextSize = 16
	CloseBtn.BorderSizePixel = 0
	Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

	-- Content scroll - calculate proper height
	local Content = Instance.new("ScrollingFrame", Modal)
	Content.Size = UDim2.new(1, -20, 1, -130) -- More space for button
	Content.Position = UDim2.new(0, 10, 0, 60)
	Content.BackgroundTransparency = 1
	Content.BorderSizePixel = 0
	Content.ScrollBarThickness = 5
	Content.ScrollBarImageColor3 = COLORS.Accent
	Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Content.CanvasSize = UDim2.new(0, 0, 0, 0)

	local ContentLayout = Instance.new("UIListLayout", Content)
	ContentLayout.Padding = UDim.new(0, 12)
	ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder

	-- Add padding to content
	local contentPadding = Instance.new("UIPadding", Content)
	contentPadding.PaddingBottom = UDim.new(0, 10)

	-- Add updates
	if changelogData.updates then
		for i, update in ipairs(changelogData.updates) do
			if i > 3 then
				break
			end -- Only show last 3 versions

			local UpdateFrame = Instance.new("Frame", Content)
			UpdateFrame.Size = UDim2.new(1, 0, 0, 0)
			UpdateFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
			UpdateFrame.BorderSizePixel = 0
			UpdateFrame.AutomaticSize = Enum.AutomaticSize.Y
			UpdateFrame.LayoutOrder = i
			Instance.new("UICorner", UpdateFrame).CornerRadius = UDim.new(0, 8)

			-- FIX: Create single UIPadding with all properties
			local padding = Instance.new("UIPadding", UpdateFrame)
			padding.PaddingTop = UDim.new(0, 10)
			padding.PaddingBottom = UDim.new(0, 10)
			padding.PaddingLeft = UDim.new(0, 12)
			padding.PaddingRight = UDim.new(0, 12)

			local UpdateLayout = Instance.new("UIListLayout", UpdateFrame)
			UpdateLayout.Padding = UDim.new(0, 6)

			-- Version header
			local VersionHeader = Instance.new("TextLabel", UpdateFrame)
			VersionHeader.Text = "v" .. (update.version or "?") .. " - " .. (update.date or "")
			VersionHeader.Size = UDim2.new(1, 0, 0, 20)
			VersionHeader.BackgroundTransparency = 1
			VersionHeader.TextColor3 = i == 1 and COLORS.Green or COLORS.TextDim
			VersionHeader.Font = Enum.Font.GothamBold
			VersionHeader.TextSize = 14
			VersionHeader.TextXAlignment = Enum.TextXAlignment.Left
			VersionHeader.LayoutOrder = 1

			-- Title if exists
			if update.title then
				local UpdateTitle = Instance.new("TextLabel", UpdateFrame)
				UpdateTitle.Text = update.title
				UpdateTitle.Size = UDim2.new(1, 0, 0, 20)
				UpdateTitle.BackgroundTransparency = 1
				UpdateTitle.TextColor3 = COLORS.Text
				UpdateTitle.Font = Enum.Font.GothamBold
				UpdateTitle.TextSize = 13
				UpdateTitle.TextXAlignment = Enum.TextXAlignment.Left
				UpdateTitle.LayoutOrder = 2
			end

			-- Changes list
			if update.changes then
				for j, change in ipairs(update.changes) do
					local ChangeLine = Instance.new("TextLabel", UpdateFrame)
					ChangeLine.Text = "  " .. change
					ChangeLine.Size = UDim2.new(1, 0, 0, 18)
					ChangeLine.BackgroundTransparency = 1
					ChangeLine.TextColor3 = COLORS.TextDim
					ChangeLine.Font = Enum.Font.Gotham
					ChangeLine.TextSize = 12
					ChangeLine.TextXAlignment = Enum.TextXAlignment.Left
					ChangeLine.TextWrapped = true
					ChangeLine.AutomaticSize = Enum.AutomaticSize.Y
					ChangeLine.LayoutOrder = 10 + j
				end
			end
		end
	end

	-- Got it button
	local GotItBtn = Instance.new("TextButton", Modal)
	GotItBtn.Size = UDim2.new(1, -40, 0, 40)
	GotItBtn.Position = UDim2.new(0, 20, 1, -55)
	GotItBtn.BackgroundColor3 = COLORS.Accent
	GotItBtn.Text = "Got it!"
	GotItBtn.TextColor3 = Color3.new(1, 1, 1)
	GotItBtn.Font = Enum.Font.GothamBold
	GotItBtn.TextSize = 16
	GotItBtn.BorderSizePixel = 0
	Instance.new("UICorner", GotItBtn).CornerRadius = UDim.new(0, 8)

	-- Animations
	Modal.Position = UDim2.new(0.5, -200, 1.5, 0)
	Overlay.BackgroundTransparency = 1

	TweenService:Create(Overlay, TweenInfo.new(0.3), { BackgroundTransparency = 0.5 }):Play()
	TweenService:Create(Modal, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -200, 0.5, -225),
	}):Play()

	-- Close handlers
	local function closeModal()
		Changelog.SaveLastSeenVersion(changelogData.currentVersion or CURRENT_VERSION)
		dismissed = true

		TweenService:Create(Overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(Modal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -200, 1.5, 0),
		}):Play()

		task.delay(0.3, function()
			ScreenGui:Destroy()
		end)
	end

	CloseBtn.MouseButton1Click:Connect(closeModal)
	GotItBtn.MouseButton1Click:Connect(closeModal)
	Overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			closeModal()
		end
	end)

	-- If blocking mode, wait until dismissed
	if waitForDismiss then
		while not dismissed do
			task.wait(0.1)
		end
		task.wait(0.3) -- Wait for animation
	end

	return ScreenGui
end

-- Check and show changelog if new version
function Changelog.CheckAndShow()
	task.spawn(function()
		-- Wait a bit for UI to settle
		task.wait(2)

		warn("[Changelog] Starting check...")

		local changelogData = Changelog.FetchChangelog()
		if not changelogData then
			warn("[Changelog] Failed to fetch data, skipping")
			return
		end

		local lastSeen = Changelog.GetLastSeenVersion()
		local serverVersion = changelogData.currentVersion or CURRENT_VERSION

		warn("[Changelog] Last seen: " .. lastSeen .. ", Server: " .. serverVersion)

		if Changelog.IsNewerVersion(serverVersion, lastSeen) then
			warn("[Changelog] New version detected! Showing modal...")
			Changelog.ShowModal(changelogData)
		else
			warn("[Changelog] No new version, skipping modal")
		end
	end)
end

-- Manual show (for settings menu)
function Changelog.Show()
	task.spawn(function()
		local changelogData = Changelog.FetchChangelog()
		if changelogData then
			Changelog.ShowModal(changelogData)
		end
	end)
end

return Changelog
