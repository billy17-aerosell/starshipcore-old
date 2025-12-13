local MobileUI = {}

function MobileUI.Init(callbacks)
	-- Load Starlight Library
	local Starlight = loadstring(
		game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Starlight-Interface-Suite/main/Source.lua")
	)()
	local NebulaIcons = loadstring(
		game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/nebula-icon-library-loader/main/Source.lua")
	)()

	-- Create Window
	local Window = Starlight:CreateWindow({
		Name = "Starship Core",
		Subtitle = "Mobile Edition",
		Icon = NebulaIcons:GetIcon("rocket", "Lucide"),
		LoadingSettings = {
			Title = "Starship Core",
			Subtitle = "Loading Mobile Interface...",
		},
		FileSettings = {
			ConfigFolder = "StarshipCore_Mobile",
		},
	})

	-- --- TAB: LIST MAP ---
	local MapTab = Window:CreateTab({
		Name = "List Map",
		Icon = NebulaIcons:GetIcon("map", "Lucide"),
	})

	local MapSection = MapTab:CreateSection("Map Selection")

	-- File Dropdown
	local FileDropdown = MapSection:CreateDropdown({
		Name = "Select Map",
		Items = {}, -- Populated dynamically
		MultiSelect = false,
		Callback = function(selected)
			if callbacks.OnMapSelected then
				callbacks.OnMapSelected(selected)
			end
		end,
	}, "MapDropdown")

	-- Refresh Button
	MapSection:CreateButton({
		Name = "Refresh List",
		Icon = NebulaIcons:GetIcon("refresh-cw", "Lucide"),
		Callback = function()
			if callbacks.GetMapList then
				local files = callbacks.GetMapList()
				FileDropdown:Set(files) -- Update dropdown items
			end
		end,
	}, "RefreshBtn")

	local PlaybackSection = MapTab:CreateSection("Playback Controls")

	-- Play/Stop Buttons
	PlaybackSection:CreateButton({
		Name = "Play Recording",
		Icon = NebulaIcons:GetIcon("play", "Lucide"),
		Callback = function()
			if callbacks.PlayRecording then
				callbacks.PlayRecording()
			end
		end,
	}, "PlayBtn")

	PlaybackSection:CreateButton({
		Name = "Stop Playback",
		Icon = NebulaIcons:GetIcon("square", "Lucide"),
		Callback = function()
			if callbacks.StopPlayback then
				callbacks.StopPlayback()
			end
		end,
	}, "StopBtn")

	-- Playback Options
	local OptionsSection = MapTab:CreateSection("Options")

	OptionsSection:CreateToggle({
		Name = "Loop Playback",
		CurrentValue = false,
		Callback = function(val)
			if callbacks.SetLoop then
				callbacks.SetLoop(val)
			end
		end,
	}, "LoopToggle")

	OptionsSection:CreateToggle({
		Name = "Reverse Mode",
		CurrentValue = false,
		Callback = function(val)
			if callbacks.SetReverse then
				callbacks.SetReverse(val)
			end
		end,
	}, "ReverseToggle")

	OptionsSection:CreateToggle({
		Name = "God Mode",
		CurrentValue = false,
		Callback = function(val)
			if callbacks.SetGodMode then
				callbacks.SetGodMode(val)
			end
		end,
	}, "GodToggle")

	OptionsSection:CreateSlider({
		Name = "Playback Speed",
		Range = { 0.25, 4 },
		Increment = 0.25,
		Suffix = "x",
		CurrentValue = 1,
		Callback = function(val)
			if callbacks.SetSpeed then
				callbacks.SetSpeed(val)
			end
		end,
	}, "SpeedSlider")

	-- Initial Refresh
	if callbacks.GetMapList then
		local files = callbacks.GetMapList()
		FileDropdown:Set(files)
	end

	-- --- OTHER TABS (Placeholders for now) ---
	local DashboardTab =
		Window:CreateTab({ Name = "Dashboard", Icon = NebulaIcons:GetIcon("layout-dashboard", "Lucide") })
	DashboardTab:CreateSection("Coming Soon"):CreateLabel("Dashboard features will be ported soon.")

	local ToolsTab = Window:CreateTab({ Name = "Tools", Icon = NebulaIcons:GetIcon("wrench", "Lucide") })
	ToolsTab:CreateSection("Coming Soon"):CreateLabel("Tools features will be ported soon.")

	local WarpTab = Window:CreateTab({ Name = "Warp", Icon = NebulaIcons:GetIcon("zap", "Lucide") })
	WarpTab:CreateSection("Coming Soon"):CreateLabel("Warp features will be ported soon.")

	local HelperTab = Window:CreateTab({ Name = "Helper", Icon = NebulaIcons:GetIcon("help-circle", "Lucide") })
	HelperTab:CreateSection("Coming Soon"):CreateLabel("Helper features will be ported soon.")

	local FunTab = Window:CreateTab({ Name = "Fun", Icon = NebulaIcons:GetIcon("smile", "Lucide") })
	FunTab:CreateSection("Coming Soon"):CreateLabel("Fun features will be ported soon.")

	local EmotesTab = Window:CreateTab({ Name = "Emotes", Icon = NebulaIcons:GetIcon("smile-plus", "Lucide") })
	EmotesTab:CreateSection("Coming Soon"):CreateLabel("Emotes features will be ported soon.")

	-- Notify user
	Starlight:Notify({
		Title = "Mobile Mode",
		Content = "Loaded Mobile Interface",
		Duration = 5,
	})
end

return MobileUI
