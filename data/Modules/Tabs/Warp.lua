local function SetupWarpUI(PageWarp, UI, Connections, Config, LocalPlayer, UIHandlers, ShowConfirm, RegisterTheme)
	local HttpService = game:GetService("HttpService")
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")

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

	local WARP_FOLDER = "StarshipCore/StarshipWarps"
	if not isfolder(WARP_FOLDER) then
		makefolder(WARP_FOLDER)
	end

	local function CFToTbl(cf)
		return { cf:GetComponents() }
	end
	local function TblToCF(t)
		return CFrame.new(unpack(t))
	end

	-- Ensure RegisterTheme exists (backwards compatibility)
	if not RegisterTheme then
		RegisterTheme = function() end
	end

	-- Clear existing children for reactive refresh support
	PageWarp:ClearAllChildren()

	local WarpPoints = {}
	local isWarpLoop = false
	local currentWarpConfig = nil

	-- Header
	local WarpHeader = Instance.new("TextLabel", PageWarp)
	WarpHeader.Text = L("warp_points")
	WarpHeader.Size = UDim2.new(0.7, 0, 0, 20)
	WarpHeader.BackgroundTransparency = 1
	WarpHeader.TextColor3 = C_TEXT_DIM
	WarpHeader.Font = Enum.Font.GothamBold
	WarpHeader.TextXAlignment = Enum.TextXAlignment.Left

	local WRefresh = Instance.new("TextButton", PageWarp)
	WRefresh.Text = L("refresh")
	WRefresh.Size = UDim2.new(0.2, 0, 0, 24)
	WRefresh.Position = UDim2.new(0.8, 0, 0, -2)
	WRefresh.BackgroundColor3 = C_ITEM
	WRefresh.TextColor3 = C_TEXT
	WRefresh.Font = Enum.Font.GothamBold
	WRefresh.TextSize = 10
	Instance.new("UICorner", WRefresh).CornerRadius = UDim.new(0, 4)
	RegisterTheme(WRefresh, "BackgroundColor3", "Item")
	RegisterTheme(WRefresh, "TextColor3", "Text")

	-- Main Container (Split View)
	local Container = Instance.new("Frame", PageWarp)
	Container.Size = UDim2.new(1, 0, 0.55, 0)
	Container.Position = UDim2.new(0, 0, 0, 25)
	Container.BackgroundTransparency = 1

	local WarpScroll = Instance.new("ScrollingFrame", Container)
	WarpScroll.Size = UDim2.new(0.6, -5, 1, 0)
	WarpScroll.BackgroundColor3 = C_ITEM
	WarpScroll.BorderSizePixel = 0
	WarpScroll.ScrollBarThickness = 4
	WarpScroll.ScrollBarImageColor3 = C_ACCENT
	Instance.new("UICorner", WarpScroll).CornerRadius = UDim.new(0, 8)
	local WarpListLayout = Instance.new("UIListLayout", WarpScroll)
	WarpListLayout.Padding = UDim.new(0, 4)
	WarpListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	RegisterTheme(WarpScroll, "BackgroundColor3", "Item")
	RegisterTheme(WarpScroll, "ScrollBarImageColor3", "Accent")

	local SavedScroll = Instance.new("ScrollingFrame", Container)
	SavedScroll.Size = UDim2.new(0.4, -5, 1, 0)
	SavedScroll.Position = UDim2.new(0.6, 5, 0, 0)
	SavedScroll.BackgroundColor3 = C_SIDE -- Slightly distinct
	SavedScroll.BorderSizePixel = 0
	SavedScroll.ScrollBarThickness = 4
	SavedScroll.ScrollBarImageColor3 = C_ACCENT
	Instance.new("UICorner", SavedScroll).CornerRadius = UDim.new(0, 8)
	Instance.new("UIListLayout", SavedScroll).Padding = UDim.new(0, 4)
	RegisterTheme(SavedScroll, "BackgroundColor3", "Side")
	RegisterTheme(SavedScroll, "ScrollBarImageColor3", "Accent")

	-- Controls Area
	local WarpCtrl = Instance.new("Frame", PageWarp)
	WarpCtrl.Size = UDim2.new(1, 0, 0.38, 0)
	WarpCtrl.Position = UDim2.new(0, 0, 0.62, 0)
	WarpCtrl.BackgroundColor3 = C_ITEM
	Instance.new("UICorner", WarpCtrl).CornerRadius = UDim.new(0, 12)
	local CtrlStroke = Instance.new("UIStroke", WarpCtrl)
	CtrlStroke.Color = C_ACCENT
	CtrlStroke.Transparency = 0.8
	CtrlStroke.Thickness = 1
	RegisterTheme(WarpCtrl, "BackgroundColor3", "Item")
	RegisterTheme(CtrlStroke, "Color", "Accent")

	-- Buttons
	local function StyleBtn(btn, col)
		btn.BackgroundColor3 = C_ITEM
		btn.TextColor3 = col
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		local s = Instance.new("UIStroke", btn)
		s.Color = col
		s.Transparency = 0.8
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		RegisterTheme(btn, "BackgroundColor3", "Item")
	end

	local BtnAddWp = Instance.new("TextButton", WarpCtrl)
	BtnAddWp.Text = L("add_point")
	BtnAddWp.Size = UDim2.new(0.3, 0, 0, 35)
	BtnAddWp.Position = UDim2.new(0, 10, 0, 10)
	StyleBtn(BtnAddWp, C_GREEN)
	local BtnClrWp = Instance.new("TextButton", WarpCtrl)
	BtnClrWp.Text = L("clear")
	BtnClrWp.Size = UDim2.new(0.3, 0, 0, 35)
	BtnClrWp.Position = UDim2.new(0.32, 0, 0, 10)
	StyleBtn(BtnClrWp, C_RED)

	local InpDelay = Instance.new("TextBox", WarpCtrl)
	InpDelay.PlaceholderText = L("delay")
	InpDelay.Text = "1"
	InpDelay.Size = UDim2.new(0.14, 0, 0, 35)
	InpDelay.Position = UDim2.new(0, 10, 0, 55)
	InpDelay.BackgroundColor3 = C_SIDE
	InpDelay.TextColor3 = C_TEXT
	InpDelay.Font = Enum.Font.Gotham
	InpDelay.TextSize = 12
	Instance.new("UICorner", InpDelay).CornerRadius = UDim.new(0, 6)

	local BtnSetTotal = Instance.new("TextButton", WarpCtrl)
	BtnSetTotal.Text = L("auto")
	BtnSetTotal.Size = UDim2.new(0.14, 0, 0, 35)
	BtnSetTotal.Position = UDim2.new(0.16, 0, 0, 55)
	StyleBtn(BtnSetTotal, C_ACCENT)

	local EstTime = Instance.new("TextLabel", WarpCtrl)
	EstTime.Text = "Total: 0s"
	EstTime.Size = UDim2.new(0.3, 0, 0, 35)
	EstTime.Position = UDim2.new(0.32, 0, 0, 55)
	EstTime.BackgroundTransparency = 1
	EstTime.TextColor3 = C_TEXT_DIM
	EstTime.Font = Enum.Font.Gotham
	EstTime.TextSize = 11
	EstTime.TextXAlignment = Enum.TextXAlignment.Left

	local InpWarpName = Instance.new("TextBox", WarpCtrl)
	InpWarpName.PlaceholderText = L("config_name")
	InpWarpName.Size = UDim2.new(0.4, 0, 0, 35)
	InpWarpName.Position = UDim2.new(0, 10, 0, 100)
	InpWarpName.BackgroundColor3 = C_SIDE
	InpWarpName.TextColor3 = C_TEXT
	InpWarpName.Font = Enum.Font.Gotham
	InpWarpName.TextSize = 12
	Instance.new("UICorner", InpWarpName).CornerRadius = UDim.new(0, 6)

	local BtnSaveWarp = Instance.new("TextButton", WarpCtrl)
	BtnSaveWarp.Text = L("save_config")
	BtnSaveWarp.Size = UDim2.new(0.2, 0, 0, 35)
	BtnSaveWarp.Position = UDim2.new(0.42, 0, 0, 100)
	BtnSaveWarp.BackgroundColor3 = C_ACCENT
	BtnSaveWarp.TextColor3 = Color3.new(0, 0, 0)
	BtnSaveWarp.Font = Enum.Font.GothamBold
	BtnSaveWarp.TextSize = 10
	Instance.new("UICorner", BtnSaveWarp).CornerRadius = UDim.new(0, 6)

	local BtnRunWarp = Instance.new("TextButton", WarpCtrl)
	BtnRunWarp.Text = L("start_loop")
	BtnRunWarp.Size = UDim2.new(0.35, -20, 1, -20)
	BtnRunWarp.Position = UDim2.new(0.65, 10, 0, 10)
	BtnRunWarp.BackgroundColor3 = C_GREEN
	BtnRunWarp.TextColor3 = Color3.new(0, 0, 0)
	BtnRunWarp.Font = Enum.Font.GothamBlack
	BtnRunWarp.TextSize = 16
	Instance.new("UICorner", BtnRunWarp).CornerRadius = UDim.new(0, 8)

	-- Logic (Kept mostly same, just UI tweaks)
	local function FormatTime(s)
		s = math.floor(s + 0.5)
		if s < 60 then
			return s .. "s"
		end
		if s < 3600 then
			return string.format("%dm %ds", math.floor(s / 60), s % 60)
		end
		return string.format("%dh %dm %ds", math.floor(s / 3600), math.floor((s % 3600) / 60), s % 60)
	end
	local function UpdateEstTime()
		local d = tonumber(InpDelay.Text) or 0
		local count = math.max(1, #WarpPoints - 1)
		local total = count * d
		EstTime.Text = L("run_time") .. ": " .. FormatTime(total)
	end
	InpDelay:GetPropertyChangedSignal("Text"):Connect(UpdateEstTime)

	local function RefreshWarp()
		for _, c in pairs(WarpScroll:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end

		-- Sort WarpPoints by number in name (low to high)
		if #WarpPoints > 1 then
			table.sort(WarpPoints, function(a, b)
				-- Extract all numbers from name and use the last one (or first if only one)
				local numA = 0
				local numB = 0
				for num in string.gmatch(a.Name, "%d+") do
					numA = tonumber(num)
				end
				for num in string.gmatch(b.Name, "%d+") do
					numB = tonumber(num)
				end

				if numA ~= 0 and numB ~= 0 then
					return numA < numB
				elseif numA ~= 0 then
					return true
				elseif numB ~= 0 then
					return false
				end
				return a.Name < b.Name
			end)
		end

		WarpScroll.CanvasSize = UDim2.new(0, 0, 0, #WarpPoints * 36)
		UpdateEstTime()
		for i, wp in ipairs(WarpPoints) do
			local r = Instance.new("Frame", WarpScroll)
			r.Name = tostring(i)
			r.Size = UDim2.new(1, -6, 0, 32)
			r.BackgroundColor3 = C_SIDE
			r.LayoutOrder = i
			Instance.new("UICorner", r).CornerRadius = UDim.new(0, 6)
			RegisterTheme(r, "BackgroundColor3", "Side")

			local idx = Instance.new("TextLabel", r)
			idx.Text = i
			idx.Size = UDim2.new(0, 25, 1, 0)
			idx.BackgroundTransparency = 1
			idx.TextColor3 = C_ACCENT
			idx.Font = Enum.Font.GothamBold
			idx.TextSize = 14
			RegisterTheme(idx, "TextColor3", "Accent")

			local btn = Instance.new("TextButton", r)
			btn.Text = wp.Name
			btn.Size = UDim2.new(0.5, 0, 1, 0)
			btn.Position = UDim2.new(0, 30, 0, 0)
			btn.BackgroundTransparency = 1
			btn.TextColor3 = C_TEXT
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.Font = Enum.Font.GothamSemibold
			btn.TextSize = 12
			btn.MouseButton1Click:Connect(function()
				local c = LocalPlayer.Character
				if c then
					c:PivotTo(wp.CF)
				end
			end)
			RegisterTheme(btn, "TextColor3", "Text")

			local ctrls = Instance.new("Frame", r)
			ctrls.Size = UDim2.new(0, 110, 1, 0)
			ctrls.Position = UDim2.new(1, -110, 0, 0)
			ctrls.BackgroundTransparency = 1
			local function MkBtn(txt, pos, col, fn)
				local b = Instance.new("TextButton", ctrls)
				b.Text = txt
				b.Size = UDim2.new(0, 22, 0, 22)
				b.Position = UDim2.new(0, pos, 0.5, -11)
				b.BackgroundColor3 = C_MAIN
				b.TextColor3 = col
				b.Font = Enum.Font.GothamBold
				b.TextSize = 12
				Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
				b.MouseButton1Click:Connect(fn)
				RegisterTheme(b, "BackgroundColor3", "Main")
				-- Color registration for buttons not done here as they vary (Yellow, Red, etc)
			end
			if i > 1 then
				MkBtn("▲", 0, C_TEXT_DIM, function()
					local item = table.remove(WarpPoints, i)
					table.insert(WarpPoints, i - 1, item)
					RefreshWarp()
				end)
			end
			if i < #WarpPoints then
				MkBtn("▼", 25, C_TEXT_DIM, function()
					local item = table.remove(WarpPoints, i)
					table.insert(WarpPoints, i + 1, item)
					RefreshWarp()
				end)
			end
			MkBtn("E", 55, C_YELLOW, function()
				if r:FindFirstChild("Ren") then
					r.Ren:Destroy()
					return
				end
				local tb = Instance.new("TextBox", r)
				tb.Name = "Ren"
				tb.Size = UDim2.new(0.5, 0, 0.8, 0)
				tb.Position = UDim2.new(0, 30, 0.1, 0)
				tb.BackgroundColor3 = C_MAIN
				tb.TextColor3 = C_TEXT
				tb.Text = wp.Name
				tb.Font = Enum.Font.Gotham
				tb.TextSize = 12
				Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 4)
				tb.FocusLost:Connect(function(enter)
					if enter and tb.Text ~= "" then
						wp.Name = tb.Text
						RefreshWarp()
					end
					tb:Destroy()
				end)
				tb:CaptureFocus()
			end)
			MkBtn("X", 80, C_RED, function()
				table.remove(WarpPoints, i)
				RefreshWarp()
			end)
		end
	end
	local function RefreshSavedWarps()
		for _, c in pairs(SavedScroll:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		if isfolder(WARP_FOLDER) then
			local files = listfiles(WARP_FOLDER)

			-- Sort files by number (low to high)
			table.sort(files, function(a, b)
				local nameA = string.match(a, "[^/\\]+$"):gsub(".json", "")
				local nameB = string.match(b, "[^/\\]+$"):gsub(".json", "")
				-- Extract numbers from names
				local numA = tonumber(string.match(nameA, "%d+")) or 0
				local numB = tonumber(string.match(nameB, "%d+")) or 0
				-- If both have numbers, sort by number
				if numA ~= 0 and numB ~= 0 then
					return numA < numB
				end
				-- Otherwise sort alphabetically
				return nameA < nameB
			end)

			SavedScroll.CanvasSize = UDim2.new(0, 0, 0, #files * 28)
			for _, f in ipairs(files) do
				local n = string.match(f, "[^/\\]+$"):gsub(".json", "")
				local r = Instance.new("Frame", SavedScroll)
				r.Size = UDim2.new(1, -4, 0, 24)
				r.BackgroundColor3 = C_ITEM
				Instance.new("UICorner", r).CornerRadius = UDim.new(0, 4)
				local isSel = (currentWarpConfig == n)
				if isSel then
					r.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
				end
				RegisterTheme(r, "BackgroundColor3", "Item")

				local b = Instance.new("TextButton", r)
				b.Text = " " .. n
				b.Size = UDim2.new(0.65, 0, 1, 0)
				b.BackgroundTransparency = 1
				b.TextColor3 = isSel and C_ACCENT or C_TEXT
				b.TextXAlignment = Enum.TextXAlignment.Left
				b.Font = isSel and Enum.Font.GothamBold or Enum.Font.Gotham
				b.TextSize = 11
				RegisterTheme(b, "TextColor3", isSel and "Accent" or "Text")

				local ren = Instance.new("TextButton", r)
				ren.Text = "E"
				ren.Size = UDim2.new(0.15, 0, 1, 0)
				ren.Position = UDim2.new(0.65, 0, 0, 0)
				ren.BackgroundTransparency = 1
				ren.TextColor3 = C_YELLOW
				ren.TextSize = 10
				ren.Font = Enum.Font.GothamBold
				local del = Instance.new("TextButton", r)
				del.Text = "X"
				del.Size = UDim2.new(0.15, 0, 1, 0)
				del.Position = UDim2.new(0.8, 0, 0, 0)
				del.BackgroundTransparency = 1
				del.TextColor3 = C_RED
				del.TextSize = 10
				del.Font = Enum.Font.GothamBold

				b.MouseButton1Click:Connect(function()
					if currentWarpConfig == n then
						currentWarpConfig = nil
						WarpPoints = {}
						RefreshWarp()
						RefreshSavedWarps()
						return
					end
					local s, j = pcall(readfile, f)
					if s then
						local d = HttpService:JSONDecode(j)
						if d.Points then
							currentWarpConfig = n
							WarpPoints = {}
							for _, p in ipairs(d.Points) do
								table.insert(WarpPoints, { Name = p.Name, CF = TblToCF(p.CF) })
							end
							InpDelay.Text = tostring(d.Delay or 1)
							RefreshWarp()
							RefreshSavedWarps()
						end
					end
				end)
				ren.MouseButton1Click:Connect(function()
					if r:FindFirstChild("Ren") then
						r.Ren:Destroy()
						return
					end
					local tb = Instance.new("TextBox", r)
					tb.Name = "Ren"
					tb.Size = UDim2.new(0.6, 0, 0.9, 0)
					tb.Position = UDim2.new(0, 5, 0.05, 0)
					tb.BackgroundColor3 = C_MAIN
					tb.TextColor3 = C_TEXT
					tb.Text = n
					tb.Font = Enum.Font.Gotham
					tb.TextSize = 10
					Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 4)
					tb.FocusLost:Connect(function(enter)
						if enter and tb.Text ~= "" and tb.Text ~= n then
							local content = readfile(f)
							writefile(WARP_FOLDER .. "/" .. tb.Text .. ".json", content)
							delfile(f)
							if currentWarpConfig == n then
								currentWarpConfig = tb.Text
							end
							RefreshSavedWarps()
						end
						tb:Destroy()
					end)
					tb:CaptureFocus()
				end)
				del.MouseButton1Click:Connect(function()
					if ShowConfirm then
						ShowConfirm("DELETE CONFIG", "Delete config '" .. n .. "'?", function()
							delfile(f)
							if currentWarpConfig == n then
								currentWarpConfig = nil
							end
							RefreshSavedWarps()
						end)
					else
						delfile(f)
						if currentWarpConfig == n then
							currentWarpConfig = nil
						end
						RefreshSavedWarps()
					end
				end)
			end
		end
	end
	BtnClrWp.MouseButton1Click:Connect(function()
		if #WarpPoints > 0 then
			if ShowConfirm then
				ShowConfirm("CLEAR POINTS", "Clear all " .. #WarpPoints .. " warp points?", function()
					WarpPoints = {}
					RefreshWarp()
				end)
			else
				WarpPoints = {}
				RefreshWarp()
			end
		end
	end)
	BtnSetTotal.MouseButton1Click:Connect(function()
		if #WarpPoints == 0 then
			return
		end
		if WarpCtrl:FindFirstChild("TotalInput") then
			WarpCtrl.TotalInput:Destroy()
			return
		end
		local ti = Instance.new("TextBox", WarpCtrl)
		ti.Name = "TotalInput"
		ti.Size = UDim2.new(0.3, 0, 1, 0)
		ti.Position = UDim2.new(0.35, 0, 0, 0)
		ti.BackgroundColor3 = C_MAIN
		ti.TextColor3 = C_TEXT
		ti.PlaceholderText = "Run Time (s)"
		ti.Text = ""
		ti.ZIndex = 20
		Instance.new("UICorner", ti)
		ti.FocusLost:Connect(function(enter)
			if enter then
				local total = tonumber(ti.Text)
				if total and total > 0 then
					local div = math.max(1, #WarpPoints - 1)
					local d = math.floor((total / div) * 1000) / 1000
					InpDelay.Text = tostring(d)
				end
			end
			ti:Destroy()
		end)
		ti:CaptureFocus()
	end)
	BtnSaveWarp.MouseButton1Click:Connect(function()
		local n = InpWarpName.Text
		if n == "" or #WarpPoints == 0 then
			return
		end
		local data = {
			Delay = tonumber(InpDelay.Text) or 1,
			Points = {},
		}
		for _, wp in ipairs(WarpPoints) do
			table.insert(data.Points, { Name = wp.Name, CF = CFToTbl(wp.CF) })
		end
		writefile(WARP_FOLDER .. "/" .. n .. ".json", HttpService:JSONEncode(data))
		InpWarpName.Text = ""
		currentWarpConfig = n
		RefreshSavedWarps()
	end)
	BtnAddWp.MouseButton1Click:Connect(function()
		local c = LocalPlayer.Character
		if c then
			table.insert(WarpPoints, { Name = "Spawn " .. (#WarpPoints + 1), CF = c:GetPivot() })
			RefreshWarp()
		end
	end)
	BtnRunWarp.MouseButton1Click:Connect(function()
		isWarpLoop = not isWarpLoop
		BtnRunWarp.Text = isWarpLoop and "STOP\nLOOP" or "START\nLOOP"
		BtnRunWarp.TextColor3 = isWarpLoop and C_RED or Color3.new(0, 0, 0)
		BtnRunWarp.BackgroundColor3 = isWarpLoop and C_ITEM or C_GREEN
		if isWarpLoop then
			task.spawn(function()
				while isWarpLoop and #WarpPoints > 0 do
					for i, wp in ipairs(WarpPoints) do
						if not isWarpLoop then
							break
						end
						local c = LocalPlayer.Character
						if c then
							c:PivotTo(wp.CF)
						end
						local d = tonumber(InpDelay.Text) or 1

						-- Countdown Logic
						local frame = WarpScroll:FindFirstChild(tostring(i))
						local btn = frame and frame:FindFirstChildOfClass("TextButton")
						local oldText = btn and btn.Text or ""

						local startTime = os.clock()
						while os.clock() - startTime < d do
							if not isWarpLoop then
								break
							end
							local remaining = math.max(0, d - (os.clock() - startTime))
							if btn then
								btn.Text = oldText .. string.format(" (%.1fs)", remaining)
							end
							task.wait(0.1)
						end
						if btn then
							btn.Text = oldText
						end
					end
				end
				if #WarpPoints == 0 then
					isWarpLoop = false
					BtnRunWarp.Text = "START\nLOOP"
					BtnRunWarp.TextColor3 = Color3.new(0, 0, 0)
					BtnRunWarp.BackgroundColor3 = C_GREEN
				end
			end)
		end
	end)
	WRefresh.MouseButton1Click:Connect(RefreshSavedWarps)
	RefreshSavedWarps()
end

return SetupWarpUI
