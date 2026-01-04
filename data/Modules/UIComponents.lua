--[[
    UIComponents.lua - Shared UI Component Library
    ================================================
    Centralized UI components and helpers for all Tab modules.
    Eliminates code duplication across Helper.lua, Fun.lua, Tools.lua, etc.
    
    Usage:
        local UIComponents = LoadModule("Modules/UIComponents")
        local CreateCard = UIComponents.CreateCard
        local StyleBtn = UIComponents.StyleBtn
        local GetColors = UIComponents.GetColors
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIComponents = {}

-- ═══════════════════════════════════════════════════════════════════
-- COLOR SYSTEM - Single Source of Truth
-- ═══════════════════════════════════════════════════════════════════

-- Get current theme colors from global _G.StarshipColors
function UIComponents.GetColors()
	return _G.StarshipColors
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
end

-- Quick color accessors
function UIComponents.C_MAIN()
	return UIComponents.GetColors().MAIN
end
function UIComponents.C_SIDE()
	return UIComponents.GetColors().SIDE
end
function UIComponents.C_ACCENT()
	return UIComponents.GetColors().ACCENT
end
function UIComponents.C_TEXT()
	return UIComponents.GetColors().TEXT
end
function UIComponents.C_TEXT_DIM()
	return UIComponents.GetColors().TEXT_DIM
end
function UIComponents.C_ITEM()
	return UIComponents.GetColors().ITEM
end
function UIComponents.C_RED()
	return UIComponents.GetColors().RED
end
function UIComponents.C_YELLOW()
	return UIComponents.GetColors().YELLOW
end
function UIComponents.C_GREEN()
	return UIComponents.GetColors().GREEN
end

-- ═══════════════════════════════════════════════════════════════════
-- CORE COMPONENTS
-- ═══════════════════════════════════════════════════════════════════

--[[
    CreateCard - Create a card container with title
    
    @param parent: Parent frame (usually ScrollingFrame)
    @param title: Card title text
    @param height: Card height in pixels
    @param order: LayoutOrder value
    @param registerTheme: Optional theme registration function
    @return card: The card Frame
]]
function UIComponents.CreateCard(parent, title, height, order, registerTheme)
	local Colors = UIComponents.GetColors()

	local card = Instance.new("Frame", parent)
	card.Size = UDim2.new(0.96, 0, 0, height)
	card.BackgroundColor3 = Colors.ITEM
	card.LayoutOrder = order or 0
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke", card)
	stroke.Color = Colors.ACCENT
	stroke.Transparency = 0.8
	stroke.Thickness = 1

	local label = Instance.new("TextLabel", card)
	label.Text = title
	label.Size = UDim2.new(1, -20, 0, 30)
	label.Position = UDim2.new(0, 15, 0, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Colors.TEXT_DIM
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left

	-- Register for theme updates if function provided
	if registerTheme then
		registerTheme(card, "BackgroundColor3", "Item")
		registerTheme(stroke, "Color", "Accent")
		registerTheme(label, "TextColor3", "TextDim")
	end

	return card
end

--[[
    StyleBtn - Apply standard button styling
    
    @param btn: TextButton to style
    @param color: Color for text and stroke
    @param registerTheme: Optional theme registration function
]]
function UIComponents.StyleBtn(btn, color, registerTheme)
	local Colors = UIComponents.GetColors()

	btn.BackgroundColor3 = Colors.SIDE
	btn.TextColor3 = color
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = color
	stroke.Transparency = 0.7
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	-- Register for theme updates
	if registerTheme then
		registerTheme(btn, "BackgroundColor3", "Side")

		-- Map colors to theme keys
		if color == Colors.ACCENT then
			registerTheme(btn, "TextColor3", "Accent")
			registerTheme(stroke, "Color", "Accent")
		elseif color == Colors.TEXT then
			registerTheme(btn, "TextColor3", "Text")
			registerTheme(stroke, "Color", "Text")
		elseif color == Colors.TEXT_DIM then
			registerTheme(btn, "TextColor3", "TextDim")
			registerTheme(stroke, "Color", "TextDim")
		end
	end
end

--[[
    CreateSlider - Create a slider component
    
    @param parent: Parent frame
    @param title: Slider label text
    @param min: Minimum value
    @param max: Maximum value
    @param default: Default value
    @param callback: Function called with new value
    @param registerTheme: Optional theme registration function
    @return sliderFrame: The slider container
]]
function UIComponents.CreateSlider(parent, title, min, max, default, callback, registerTheme)
	local Colors = UIComponents.GetColors()

	local frame = Instance.new("Frame", parent)
	frame.Size = UDim2.new(0.94, 0, 0, 40)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 205

	local label = Instance.new("TextLabel", frame)
	label.Text = title .. ": " .. default
	label.Size = UDim2.new(1, 0, 0, 15)
	label.BackgroundTransparency = 1
	label.TextColor3 = Colors.TEXT
	label.Font = Enum.Font.Gotham
	label.TextSize = 10
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 206

	local sliderBg = Instance.new("TextButton", frame)
	sliderBg.Text = ""
	sliderBg.Size = UDim2.new(1, 0, 0, 6)
	sliderBg.Position = UDim2.new(0, 0, 0, 20)
	sliderBg.BackgroundColor3 = Colors.SIDE
	sliderBg.ZIndex = 206
	sliderBg.AutoButtonColor = false
	Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0, 3)

	local fill = Instance.new("Frame", sliderBg)
	fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
	fill.BackgroundColor3 = Colors.ACCENT
	fill.ZIndex = 207
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

	-- Dragging logic
	local dragging = false

	sliderBg.MouseButton1Down:Connect(function()
		dragging = true
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local percent = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
			local value = min + (max - min) * percent
			value = math.floor(value * 100) / 100 -- Round to 2 decimals
			fill.Size = UDim2.new(percent, 0, 1, 0)
			label.Text = title .. ": " .. value
			if callback then
				callback(value)
			end
		end
	end)

	-- Theme registration
	if registerTheme then
		registerTheme(label, "TextColor3", "Text")
		registerTheme(sliderBg, "BackgroundColor3", "Side")
		registerTheme(fill, "BackgroundColor3", "Accent")
	end

	return frame
end

--[[
    CreateToggle - Create a toggle button
    
    @param parent: Parent frame
    @param title: Toggle label text
    @param default: Default state (true/false)
    @param callback: Function called with new state
    @param registerTheme: Optional theme registration function
    @return toggleBtn: The toggle TextButton
]]
function UIComponents.CreateToggle(parent, title, default, callback, registerTheme)
	local Colors = UIComponents.GetColors()

	local btn = Instance.new("TextButton", parent)
	btn.Size = UDim2.new(0.94, 0, 0, 35)
	btn.ZIndex = 205

	local state = default
	UIComponents.StyleBtn(btn, state and Colors.GREEN or Colors.RED, registerTheme)
	btn.Text = title .. ": " .. (state and "ON" or "OFF")

	btn.MouseButton1Click:Connect(function()
		state = not state
		btn.Text = title .. ": " .. (state and "ON" or "OFF")
		btn.TextColor3 = state and Colors.GREEN or Colors.RED
		if btn:FindFirstChild("UIStroke") then
			btn.UIStroke.Color = state and Colors.GREEN or Colors.RED
		end
		if callback then
			callback(state)
		end
	end)

	return btn
end

--[[
    CreateFeatureButton - Create a button with subtitle description
    
    @param parent: Parent frame
    @param text: Button text
    @param subtitle: Subtitle/description text
    @param size: UDim2 size
    @param position: UDim2 position
    @param color: Button color
    @param registerTheme: Optional theme registration function
    @return btn, container: The button and its container frame
]]
function UIComponents.CreateFeatureButton(parent, text, subtitle, size, position, color, registerTheme)
	local Colors = UIComponents.GetColors()

	local container = Instance.new("Frame", parent)
	container.Size = size
	container.Position = position
	container.BackgroundTransparency = 1

	local btn = Instance.new("TextButton", container)
	btn.Text = text
	btn.Size = UDim2.new(1, 0, 0, 35)
	btn.Position = UDim2.new(0, 0, 0, 0)
	UIComponents.StyleBtn(btn, color, registerTheme)

	local desc = Instance.new("TextLabel", container)
	desc.Text = subtitle
	desc.Size = UDim2.new(1, 0, 0, 14)
	desc.Position = UDim2.new(0, 0, 0, 37)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = Colors.TEXT_DIM
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 9
	desc.TextXAlignment = Enum.TextXAlignment.Center
	desc.TextWrapped = true

	if registerTheme then
		registerTheme(desc, "TextColor3", "TextDim")
	end

	return btn, container
end

--[[
    CreateWindow - Create a draggable popup window
    
    @param parent: Parent frame (usually Main)
    @param title: Window title
    @param height: Window height
    @param registerTheme: Optional theme registration function
    @return window, content: The window frame and content ScrollingFrame
]]
function UIComponents.CreateWindow(parent, title, height, registerTheme)
	local Colors = UIComponents.GetColors()

	local windowName = "Window_" .. title:gsub(" ", "")

	-- Remove existing window with same name
	if parent:FindFirstChild(windowName) then
		parent[windowName]:Destroy()
	end

	local window = Instance.new("Frame", parent)
	window.Name = windowName
	window.Size = UDim2.new(0, 320, 0, height)
	window.Position = UDim2.new(0.5, -160, 0.5, -height / 2)
	window.BackgroundColor3 = Colors.SIDE
	window.BackgroundTransparency = 0
	window.BorderSizePixel = 0
	window.Visible = false
	window.ZIndex = 200
	Instance.new("UICorner", window).CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke", window)
	stroke.Color = Colors.ACCENT
	stroke.Thickness = 1
	stroke.Transparency = 0

	if registerTheme then
		registerTheme(stroke, "Color", "Accent")
		registerTheme(window, "BackgroundColor3", "Side")
	end

	-- Header
	local header = Instance.new("Frame", window)
	header.Size = UDim2.new(1, 0, 0, 35)
	header.BackgroundColor3 = Colors.ITEM
	header.ZIndex = 201
	Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

	if registerTheme then
		registerTheme(header, "BackgroundColor3", "Item")
	end

	local titleLabel = Instance.new("TextLabel", header)
	titleLabel.Text = title
	titleLabel.Size = UDim2.new(1, -40, 1, 0)
	titleLabel.Position = UDim2.new(0, 15, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Colors.TEXT
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 12
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 202

	if registerTheme then
		registerTheme(titleLabel, "TextColor3", "Text")
	end

	local closeBtn = Instance.new("TextButton", header)
	closeBtn.Size = UDim2.new(0, 35, 0, 35)
	closeBtn.Position = UDim2.new(1, -35, 0, 0)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Colors.RED
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.ZIndex = 202

	closeBtn.MouseButton1Click:Connect(function()
		window.Visible = false
	end)

	-- Dragging
	local dragging, dragInput, dragStart, startPos

	header.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPos = window.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	header.InputChanged:Connect(function(input)
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
			window.Position =
				UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	-- Content area
	local content = Instance.new("ScrollingFrame", window)
	content.Size = UDim2.new(1, 0, 1, -40)
	content.Position = UDim2.new(0, 0, 0, 40)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.ScrollBarImageColor3 = Colors.ACCENT
	content.ZIndex = 201
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y

	if registerTheme then
		registerTheme(content, "ScrollBarImageColor3", "Accent")
	end

	local layout = Instance.new("UIListLayout", content)
	layout.Padding = UDim.new(0, 5)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	return window, content
end

--[[
    ShowFeatureToast - Helper to show toast when feature is toggled
    
    @param featureName: Name of the feature
    @param isEnabled: Whether the feature is now enabled
    @param UI: UI module reference with ShowToast function
    @param L: Localization function (optional)
]]
function UIComponents.ShowFeatureToast(featureName, isEnabled, UI, L)
	if UI and UI.ShowToast then
		local status
		if L then
			status = isEnabled and L("enabled") or L("disabled")
		else
			status = isEnabled and "Enabled" or "Disabled"
		end
		local toastType = isEnabled and "success" or "info"
		UI.ShowToast(featureName, status, toastType, 2)
	end
end

return UIComponents
