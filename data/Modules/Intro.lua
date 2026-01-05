local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local Intro = {}

local C_MAIN = Color3.fromRGB(25, 25, 30)
local C_SIDE = Color3.fromRGB(20, 20, 25)
local C_ACCENT = Color3.fromRGB(0, 200, 255)
local C_TEXT = Color3.fromRGB(240, 240, 240)
local C_TEXT_DIM = Color3.fromRGB(150, 150, 150)
local C_ITEM = Color3.fromRGB(40, 40, 45)
local C_RED = Color3.fromRGB(255, 60, 60)
local C_YELLOW = Color3.fromRGB(255, 200, 0)
local C_GREEN = Color3.fromRGB(0, 255, 150)

function Intro.StartLoader(Main, TargetMainHeight)
	local success, err = pcall(function()
		-- 1. Setup GUI & Effects
		local LoaderGui = Instance.new("ScreenGui")
		LoaderGui.Name = "StarshipIntro"
		LoaderGui.Parent = CoreGui
		LoaderGui.IgnoreGuiInset = true
		LoaderGui.DisplayOrder = 10000

		local Blur = Instance.new("BlurEffect", game:GetService("Lighting"))
		Blur.Size = 0

		local MainFrame = Instance.new("Frame", LoaderGui)
		MainFrame.Size = UDim2.new(1, 0, 1, 0)
		MainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
		MainFrame.BackgroundTransparency = 1

		-- Particle Emitter (Visual Flair)
		local ParticleContainer = Instance.new("Frame", MainFrame)
		ParticleContainer.Size = UDim2.new(1, 0, 1, 0)
		ParticleContainer.BackgroundTransparency = 1

		-- Title Text
		local Title = Instance.new("TextLabel", MainFrame)
		Title.Text = "STARSHIP v0.9 Beta"
		Title.Size = UDim2.new(1, 0, 0, 100)
		Title.Position = UDim2.new(0, 0, 0.45, 0)
		Title.BackgroundTransparency = 1
		Title.TextColor3 = C_ACCENT
		Title.Font = Enum.Font.GothamBlack
		Title.TextSize = 60
		Title.TextTransparency = 1

		local Sub = Instance.new("TextLabel", MainFrame)
		Sub.Text = "INITIALIZING SYSTEM..."
		Sub.Size = UDim2.new(1, 0, 0, 30)
		Sub.Position = UDim2.new(0, 0, 0.55, 0)
		Sub.BackgroundTransparency = 1
		Sub.TextColor3 = Color3.fromRGB(200, 200, 200)
		Sub.Font = Enum.Font.Gotham
		Sub.TextSize = 16
		Sub.TextTransparency = 1

		-- Glitch Effect Helper
		local function GlitchText(label, originalText)
			local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
			for i = 1, 15 do
				local newText = ""
				for j = 1, #originalText do
					if math.random() > 0.5 then
						newText = newText .. originalText:sub(j, j)
					else
						local r = math.random(1, #chars)
						newText = newText .. chars:sub(r, r)
					end
				end
				label.Text = newText
				label.TextColor3 = (i % 2 == 0) and C_ACCENT or Color3.new(1, 1, 1)
				task.wait(0.03)
			end
			label.Text = originalText
			label.TextColor3 = C_ACCENT
		end

		-- === SEQUENCE START ===

		-- 1. Blur In & Darken
		TweenService:Create(Blur, TweenInfo.new(1), { Size = 24 }):Play()
		TweenService:Create(MainFrame, TweenInfo.new(0.5), { BackgroundTransparency = 0.3 }):Play()
		task.wait(0.5)

		-- 2. Title Appear
		TweenService:Create(Title, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
		GlitchText(Title, "STARSHIP") -- Glitch Effect First
		Title.RichText = true

		-- Live Gradient/Rainbow Animation
		task.spawn(function()
			local t = 0
			while Title and Title.Parent do
				t = t + 0.01
				local c = Color3.fromHSV(t % 1, 0.8, 1)
				local r, g, b = math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)
				Title.Text = string.format('<font color="rgb(%d,%d,%d)">STARSHIP</font>', r, g, b)
				task.wait(0.03)
			end
		end)

		-- 3. Subtitle Slide Up
		TweenService:Create(
			Sub,
			TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ TextTransparency = 0, Position = UDim2.new(0, 0, 0.52, 0) }
		):Play()
		task.wait(1.5)

		-- 4. Loading Finished - Clean Up
		Sub.Text = "READY"
		Sub.TextColor3 = Color3.fromRGB(0, 255, 100)
		task.wait(0.5)

		-- 5. Exit Animation
		TweenService:Create(Title, TweenInfo.new(0.5), { TextTransparency = 1, Position = UDim2.new(0, 0, 0.4, 0) })
			:Play()
		TweenService:Create(Sub, TweenInfo.new(0.5), { TextTransparency = 1, Position = UDim2.new(0, 0, 0.6, 0) })
			:Play()
		TweenService:Create(MainFrame, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(Blur, TweenInfo.new(0.8), { Size = 0 }):Play()

		task.wait(0.6)
		if Main then
			Main.Visible = true
		end

		-- 6. Cyber Unfold Main UI
		if Main then
			Main.Visible = true
			Main.ClipsDescendants = true
			local targetSize = UDim2.new(0, 550, 0, TargetMainHeight)
			Main.Size = UDim2.new(0, 550, 0, 0) -- Start as horizontal line

			-- Unfold Animation
			Main.ClipsDescendants = false -- Show blur immediately

			-- Enable Blur
			if Main:FindFirstChild("MainBlur") then
				TweenService:Create(Main.MainBlur, TweenInfo.new(1.0), { Size = 24 }):Play()
			end

			local tw = TweenService:Create(
				Main,
				TweenInfo.new(1.0, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
				{ Size = targetSize }
			)
			tw:Play()
		end

		task.wait(1)
		LoaderGui:Destroy()
		Blur:Destroy()
	end)

	if not success then
		if _G.StarshipDevMode then
			warn("Intro Failed: " .. tostring(err))
		end
		if game:GetService("Lighting"):FindFirstChild("BlurEffect") then
			game:GetService("Lighting").BlurEffect:Destroy()
		end
		if Main then
			Main.Visible = true
		end
	end
end

return Intro
