local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local UI = {}
local ToastContainer = nil
local LoadingNotification = nil
local LoadingLabel = nil
local LoadingBar = nil

-- Use global StarshipColors for theme consistency
local function GetColors()
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

-- Dynamic color accessors (support theme changes)
local function C_MAIN()
	return GetColors().MAIN
end
local function C_SIDE()
	return GetColors().SIDE
end
local function C_ACCENT()
	return GetColors().ACCENT
end
local function C_TEXT()
	return GetColors().TEXT
end
local function C_TEXT_DIM()
	return GetColors().TEXT_DIM
end
local function C_ITEM()
	return GetColors().ITEM
end
local function C_RED()
	return GetColors().RED
end
local function C_YELLOW()
	return GetColors().YELLOW
end
local function C_GREEN()
	return GetColors().GREEN
end

function UI.ShowToast(title, message, type, duration)
	if not ToastContainer then
		local sg = CoreGui:FindFirstChild("StarshipToasts")
		if not sg then
			sg = Instance.new("ScreenGui")
			sg.Name = "StarshipToasts"
			sg.Parent = CoreGui
			sg.IgnoreGuiInset = true
			sg.DisplayOrder = 10005 -- Above everything
		end
		ToastContainer = Instance.new("Frame", sg)
		ToastContainer.Size = UDim2.new(0, 300, 1, -20)
		ToastContainer.Position = UDim2.new(1, -320, 0, 20)
		ToastContainer.BackgroundTransparency = 1
		ToastContainer.ClipsDescendants = true
	end

	local color = C_ACCENT()
	if type == "error" then
		color = C_RED()
	elseif type == "success" then
		color = C_GREEN()
	elseif type == "warning" then
		color = C_YELLOW()
	end

	local toast = Instance.new("Frame", ToastContainer)
	toast.Size = UDim2.new(1, 0, 0, 0) -- Start height 0
	toast.BackgroundColor3 = C_MAIN()
	toast.BackgroundTransparency = 0.1
	toast.BorderSizePixel = 0
	toast.ClipsDescendants = true

	-- Glassmorphism for Toast
	local stroke = Instance.new("UIStroke", toast)
	stroke.Color = color
	stroke.Transparency = 0.5
	stroke.Thickness = 1

	Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 6)

	local titleLbl = Instance.new("TextLabel", toast)
	titleLbl.Text = title
	titleLbl.Size = UDim2.new(1, -10, 0, 20)
	titleLbl.Position = UDim2.new(0, 10, 0, 5)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3 = color
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 14
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left

	local msgLbl = Instance.new("TextLabel", toast)
	msgLbl.Text = message
	msgLbl.Size = UDim2.new(1, -20, 0, 30)
	msgLbl.Position = UDim2.new(0, 10, 0, 25)
	msgLbl.BackgroundTransparency = 1
	msgLbl.TextColor3 = C_TEXT()
	msgLbl.Font = Enum.Font.Gotham
	msgLbl.TextSize = 12
	msgLbl.TextXAlignment = Enum.TextXAlignment.Left
	msgLbl.TextWrapped = true

	-- Animation
	local targetHeight = 60
	if #message > 30 then
		targetHeight = 80
	end

	-- Slide In & Expand
	toast.Parent = ToastContainer

	-- Push existing toasts up (with bounds check)
	for _, t in pairs(ToastContainer:GetChildren()) do
		if t ~= toast then
			local newY = t.Position.Y.Scale
			local newYOffset = t.Position.Y.Offset - (targetHeight + 10)
			-- Only push up if toast would still be partially visible (at least 20px from top)
			if newYOffset > -ToastContainer.AbsoluteSize.Y + 20 then
				TweenService:Create(
					t,
					TweenInfo.new(0.3),
					{ Position = UDim2.new(t.Position.X.Scale, t.Position.X.Offset, newY, newYOffset) }
				):Play()
			else
				-- Toast is going off screen, fade it out and destroy
				TweenService:Create(t, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
				for _, child in pairs(t:GetChildren()) do
					if child:IsA("TextLabel") then
						TweenService:Create(child, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
					elseif child:IsA("UIStroke") then
						TweenService:Create(child, TweenInfo.new(0.2), { Transparency = 1 }):Play()
					end
				end
				task.delay(0.2, function()
					if t and t.Parent then
						t:Destroy()
					end
				end)
			end
		end
	end

	toast.Position = UDim2.new(1, 0, 1, -targetHeight - 20) -- Start off screen right
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 0, targetHeight),
		Position = UDim2.new(0, 0, 1, -targetHeight - 20),
	}):Play()

	-- Sound Effect
	local sound = Instance.new("Sound", CoreGui)
	sound.SoundId = "rbxassetid://4590657391" -- Subtle notification sound
	sound.Volume = 0.5
	sound.PlayOnRemove = true
	sound:Destroy()

	task.delay(duration or 3, function()
		if toast and toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.3), { Position = UDim2.new(1.2, 0, 1, -targetHeight - 20) })
				:Play()
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

function UI.ShowLoadingModal(visible, text, progress)
	if not visible then
		if LoadingNotification then
			LoadingNotification:Destroy()
			LoadingNotification = nil
			LoadingLabel = nil
			LoadingBar = nil
		end
		return
	end

	if not LoadingNotification then
		LoadingNotification = Instance.new("ScreenGui")
		LoadingNotification.Name = "StarshipNotification"
		LoadingNotification.Parent = CoreGui
		LoadingNotification.IgnoreGuiInset = true
		LoadingNotification.DisplayOrder = 10001

		local card = Instance.new("Frame", LoadingNotification)
		card.Size = UDim2.new(0, 220, 0, 50)
		card.Position = UDim2.new(1, 0, 1, -60) -- Start off-screen
		card.BackgroundColor3 = C_MAIN()
		card.BackgroundTransparency = 0.1
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
		Instance.new("UIStroke", card).Color = C_ACCENT()

		LoadingLabel = Instance.new("TextLabel", card)
		LoadingLabel.Text = text or "LOADING..."
		LoadingLabel.Size = UDim2.new(1, -40, 1, 0) -- Full height
		LoadingLabel.Position = UDim2.new(0, 40, 0, 0)
		LoadingLabel.BackgroundTransparency = 1
		LoadingLabel.TextColor3 = C_TEXT()
		LoadingLabel.Font = Enum.Font.GothamBold
		LoadingLabel.TextSize = 12
		LoadingLabel.TextXAlignment = Enum.TextXAlignment.Left
		LoadingLabel.TextYAlignment = Enum.TextYAlignment.Center -- Center vertically

		local spinner = Instance.new("ImageLabel", card)
		spinner.Size = UDim2.new(0, 20, 0, 20)
		spinner.Position = UDim2.new(0, 10, 0.5, -10)
		spinner.BackgroundTransparency = 1
		spinner.Image = "rbxassetid://3570695787"
		spinner.ImageColor3 = C_ACCENT()

		local ts = game:GetService("TweenService")
		ts
			:Create(
				spinner,
				TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
				{ Rotation = 360 }
			)
			:Play()
		ts:Create(
			card,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(1, -230, 1, -60) }
		):Play()
	end

	if LoadingLabel then
		LoadingLabel.Text = text or "LOADING..."
	end
end

return UI
