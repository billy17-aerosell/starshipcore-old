local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- UPDATED THEME
local C_MAIN=Color3.fromRGB(10, 10, 14); 
local C_SIDE=Color3.fromRGB(15, 15, 20); 
local C_ACCENT=Color3.fromRGB(90, 110, 245); -- Midnight Blue
local C_TEXT=Color3.fromRGB(240, 240, 250); 
local C_TEXT_DIM=Color3.fromRGB(140, 140, 160); 
local C_ITEM=Color3.fromRGB(20, 20, 28); 
local C_RED=Color3.fromRGB(255, 80, 80); 
local C_YELLOW=Color3.fromRGB(255, 220, 60); 
local C_GREEN=Color3.fromRGB(60, 255, 160)

local CONFIG_FOLDER = "StarshipCore/StarshipConfigs"
local PROFILE_FOLDER = "StarshipCore/StarshipProfiles"
if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
if not isfolder(PROFILE_FOLDER) then makefolder(PROFILE_FOLDER) end

-- Feature State Tracking
local FeatureStates = {}
local AutoEnableList = {}

-- Forward declaration for RunAutoEnable
local RunAutoEnable

local function SaveConfig(name, Config, UI)
    if writefile then
        local kbData = {}
        if Config.Keybinds then
            for k, v in pairs(Config.Keybinds) do kbData[k] = v.Name end
        end
        
        local data = HttpService:JSONEncode({
            Theme = Config.Theme,
            AccentColor = Config.AccentColor,
            LongJumpPower = Config.LongJumpPower,
            Keybinds = kbData
        })
        
        local fileName = name or "Default"
        if not fileName:match("%.json$") then fileName = fileName .. ".json" end
        writefile(CONFIG_FOLDER .. "/" .. fileName, data)
        if UI and UI.ShowToast then
            UI.ShowToast("Configuration Saved", "Saved config to " .. fileName, "success", 2)
        end
    end
end

local function SaveProfile(name, Config, UI, UIHandlers)
    if writefile then
        local kbData = {}
        if Config.Keybinds then
            for k, v in pairs(Config.Keybinds) do kbData[k] = v.Name end
        end
        
        local data = HttpService:JSONEncode({
            Theme = Config.Theme,
            AccentColor = Config.AccentColor,
            LongJumpPower = Config.LongJumpPower,
            Keybinds = kbData,
            AutoEnable = AutoEnableList
        })
        
        local fileName = name or "Default"
        if not fileName:match("%.json$") then fileName = fileName .. ".json" end
        writefile(PROFILE_FOLDER .. "/" .. fileName, data)
        if UI and UI.ShowToast then
            UI.ShowToast("Profile Saved", "Saved to " .. fileName, "success", 2)
        end
    end
end

local function LoadProfile(name, Config, Themes, UI, UIHandlers)
    local fileName = name or "Default"
    if not fileName:match("%.json$") then fileName = fileName .. ".json" end
    local path = PROFILE_FOLDER .. "/" .. fileName
    
    if isfile and isfile(path) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if success and result then
            if result.Theme and Themes[result.Theme] then Config.Theme = result.Theme end
            if result.AccentColor then Config.AccentColor = result.AccentColor end
            if result.LongJumpPower then Config.LongJumpPower = result.LongJumpPower end
            if result.Keybinds then
                if not Config.Keybinds then Config.Keybinds = {} end
                for k, v in pairs(result.Keybinds) do
                    if Enum.KeyCode[v] then Config.Keybinds[k] = Enum.KeyCode[v] end
                end
            end
            
            -- Load Auto-Enable List
            local hasAutoEnable = false
            if result.AutoEnable and #result.AutoEnable > 0 then
                AutoEnableList = result.AutoEnable
                hasAutoEnable = true
                
                -- Immediately run auto-enable features
                if RunAutoEnable and UIHandlers then
                    task.spawn(function()
                        task.wait(0.3) -- Small delay to ensure UI is ready
                        RunAutoEnable(UIHandlers)
                    end)
                end
            end
            
            if UI and UI.ShowToast then
                local msg = hasAutoEnable 
                    and "Loaded: " .. fileName .. "\nAuto-enabling " .. #AutoEnableList .. " feature(s)..."
                    or "Loaded: " .. fileName
                UI.ShowToast("Profile Loaded", msg, "success", 3)
            end
            return true, result
        end
    end
    return false, nil
end

local function LoadConfig(name, Config, Themes)
    local fileName = name or "Default"
    if not fileName:match("%.json$") then fileName = fileName .. ".json" end
    local path = CONFIG_FOLDER .. "/" .. fileName
    
    if isfile and isfile(path) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if success and result then
            if result.Theme and Themes[result.Theme] then Config.Theme = result.Theme end
            if result.AccentColor then Config.AccentColor = result.AccentColor end
            if result.LongJumpPower then Config.LongJumpPower = result.LongJumpPower end
            if result.Keybinds then
                if not Config.Keybinds then Config.Keybinds = {} end
                for k, v in pairs(result.Keybinds) do
                    if Enum.KeyCode[v] then Config.Keybinds[k] = Enum.KeyCode[v] end
                end
            end
        end
    end
    
    if not Config.Keybinds then
        Config.Keybinds = {
            StartRecording = Enum.KeyCode.F5,
            PauseRecording = Enum.KeyCode.F6,
            TogglePath = Enum.KeyCode.F8,
            PlayPlayback = Enum.KeyCode.Z,
            StopPlayback = Enum.KeyCode.X,
            FollowPlayer = Enum.KeyCode.G,
            ToggleMinimize = Enum.KeyCode.RightControl,
            ToggleShiftLock = Enum.KeyCode.LeftShift
        }
    end
end

RunAutoEnable = function(UIHandlers)
    for _, id in ipairs(AutoEnableList) do
        local handlerName = "Toggle" .. id
        if UIHandlers and UIHandlers[handlerName] then
            task.spawn(function()
                task.wait(0.5)
                UIHandlers[handlerName](true)
            end)
        end
    end
end

local function SetFeatureState(id, enabled)
    FeatureStates[id] = enabled
end

local function GetFeatureState(id)
    return FeatureStates[id] or false
end

local function SetupConfigUI(PageConfig, UI, Connections, Config, LocalPlayer, UIHandlers, Themes, ThemeObjects, Main)
    local function RegisterTheme(obj, prop, type) 
        table.insert(ThemeObjects, {Object=obj, Property=prop, Type=type}) 
    end

    PageConfig:ClearAllChildren()
    local ConfigScroll = Instance.new("ScrollingFrame", PageConfig)
    ConfigScroll.Size = UDim2.new(1, 0, 1, 0)
    ConfigScroll.BackgroundTransparency = 1
    ConfigScroll.BorderSizePixel = 0
    ConfigScroll.ScrollBarThickness = 4
    ConfigScroll.ScrollBarImageColor3 = C_ACCENT
    ConfigScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ConfigScroll.CanvasSize = UDim2.new(0,0,0,0)
    RegisterTheme(ConfigScroll, "ScrollBarImageColor3")
    
    local ConfigLayout = Instance.new("UIListLayout", ConfigScroll)
    ConfigLayout.Padding = UDim.new(0, 15)
    ConfigLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ConfigLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local function CreateCard(t, h, o)
        local c = Instance.new("Frame", ConfigScroll)
        c.Size = UDim2.new(0.96, 0, 0, h)
        c.BackgroundColor3 = C_ITEM
        c.LayoutOrder = o
        Instance.new("UICorner", c).CornerRadius = UDim.new(0, 12)
        local s = Instance.new("UIStroke", c)
        s.Color = C_ACCENT
        s.Transparency = 0.8
        s.Thickness = 1
        local l = Instance.new("TextLabel", c)
        l.Text = t
        l.Size = UDim2.new(1, -20, 0, 30)
        l.Position = UDim2.new(0, 15, 0, 0)
        l.BackgroundTransparency = 1
        l.TextColor3 = C_TEXT_DIM
        l.Font = Enum.Font.GothamBold
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        
        RegisterTheme(c, "BackgroundColor3", "Item")
        RegisterTheme(s, "Color", "Accent")
        RegisterTheme(l, "TextColor3", "TextDim")
        return c
    end

    local function StyleBtn(btn, col)
        btn.BackgroundColor3 = C_SIDE
        btn.TextColor3 = col
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local s = Instance.new("UIStroke", btn); s.Color = col; s.Transparency = 0.7; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        
        RegisterTheme(btn, "BackgroundColor3", "Side")
        -- Note: TextColor3 and Stroke Color here are variable (col), so we can't easily register them to a single theme type unless we know 'col' is always one of the theme colors. 
        -- For ConfigTab, they are usually C_TEXT or C_ACCENT.
        if col == C_ACCENT then 
            RegisterTheme(btn, "TextColor3", "Accent")
            RegisterTheme(s, "Color", "Accent")
        elseif col == C_TEXT then
            RegisterTheme(btn, "TextColor3", "Text")
            RegisterTheme(s, "Color", "Text")
        end
    end
    
    -- KEYBIND SETTINGS CARD
    local KBCard = CreateCard("KEYBIND SETTINGS", 0, 1)
    KBCard.AutomaticSize = Enum.AutomaticSize.Y
    
    local KBList = Instance.new("Frame", KBCard)
    KBList.Size = UDim2.new(1, 0, 0, 0)
    KBList.Position = UDim2.new(0, 0, 0, 45)
    KBList.BackgroundTransparency = 1
    KBList.AutomaticSize = Enum.AutomaticSize.Y
    
    local KBLayout = Instance.new("UIListLayout", KBList)
    KBLayout.Padding = UDim.new(0, 5)
    KBLayout.SortOrder = Enum.SortOrder.LayoutOrder
    KBLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local isBinding = false
    
    local function CreateBindRow(keyKey, labelText)
        local row = Instance.new("Frame", KBList)
        row.Size = UDim2.new(0.95, 0, 0, 30)
        row.BackgroundColor3 = C_SIDE
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        RegisterTheme(row, "BackgroundColor3", "Side")
        
        local lbl = Instance.new("TextLabel", row)
        lbl.Text = labelText
        lbl.Size = UDim2.new(0.6, 0, 1, 0)
        lbl.Position = UDim2.new(0.05, 0, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = C_TEXT
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        RegisterTheme(lbl, "TextColor3", "Text")

        local btn = Instance.new("TextButton", row)
        local keyName = "None"
        if Config.Keybinds and Config.Keybinds[keyKey] then
            keyName = Config.Keybinds[keyKey].Name
        end
        btn.Text = keyName
        btn.Size = UDim2.new(0.35, 0, 1, 0)
        btn.Position = UDim2.new(0.65, 0, 0, 0)
        btn.BackgroundColor3 = C_ITEM
        btn.TextColor3 = C_ACCENT
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        RegisterTheme(btn, "BackgroundColor3", "Item")
        RegisterTheme(btn, "TextColor3", "Accent")
        
        btn.MouseButton1Click:Connect(function()
            if isBinding then return end
            isBinding = true
            btn.Text = "..."
            btn.TextColor3 = C_YELLOW
            
            local con
            con = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType.Name:find("Gamepad") then
                    if input.KeyCode ~= Enum.KeyCode.Unknown then
                        Config.Keybinds[keyKey] = input.KeyCode
                        btn.Text = input.KeyCode.Name
                        btn.TextColor3 = C_ACCENT
                        isBinding = false
                        con:Disconnect()
                        SaveConfig(nil, Config, UI)
                    end
                end
            end)
        end)
    end
    
    CreateBindRow("StartRecording", "Start/Stop Recording")
    CreateBindRow("PauseRecording", "Pause Recording")
    CreateBindRow("TogglePath", "Toggle Path")
    CreateBindRow("PlayPlayback", "Play Playback")
    CreateBindRow("StopPlayback", "Stop Playback")
    CreateBindRow("FollowPlayer", "Follow Player")
    CreateBindRow("ToggleShiftLock", "Toggle Shift Lock")
    CreateBindRow("ToggleSpeed", "Toggle Speed")
    CreateBindRow("ToggleJump", "Toggle Jump Power")
    CreateBindRow("ToggleInfJump", "Toggle Infinite Jump")
    CreateBindRow("ToggleFly", "Toggle Fly")
    CreateBindRow("ToggleMomentum", "Toggle Always Momentum")
    CreateBindRow("ToggleAntiSlip", "Toggle Anti-Slip")
    CreateBindRow("ToggleAutoJump", "Toggle Auto Jump")
    CreateBindRow("ToggleLongJump", "Toggle Long Jump")
    CreateBindRow("ToggleAirLock", "Toggle Air Lock")
    CreateBindRow("ToggleRealESP", "Toggle Real Path ESP")
    CreateBindRow("ToggleFullbright", "Toggle Fullbright")
    CreateBindRow("ToggleMinimize", "Minimize UI")

    -- THEME CARD
    local ThemeCard = CreateCard("THEME SETTINGS", 0, 2)
    ThemeCard.AutomaticSize = Enum.AutomaticSize.Y
    
    local ThemeContainer = Instance.new("Frame", ThemeCard)
    ThemeContainer.Size = UDim2.new(0.9, 0, 0, 0)
    ThemeContainer.Position = UDim2.new(0.05, 0, 0, 35)
    ThemeContainer.BackgroundTransparency = 1
    ThemeContainer.AutomaticSize = Enum.AutomaticSize.Y
    
    local ThemeLayout = Instance.new("UIGridLayout", ThemeContainer)
    ThemeLayout.CellSize = UDim2.new(0.48, 0, 0, 35)
    ThemeLayout.CellPadding = UDim2.new(0.02, 0, 0, 5)
    ThemeLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ThemeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local function ApplyTheme(name)
        if not Themes[name] then return end
        Config.Theme = name
        local t = Themes[name]
        
        -- Update Global Colors (Locals in this scope)
        C_MAIN = t.Main
        C_SIDE = t.Side
        C_ACCENT = t.Accent
        C_ITEM = t.Item
        C_TEXT = t.Text
        C_TEXT_DIM = t.TextDim or Color3.fromRGB(140, 140, 160)
        
        if Config.AccentColor then
            C_ACCENT = Color3.fromRGB(Config.AccentColor.R, Config.AccentColor.G, Config.AccentColor.B)
        end
        
        -- Update global StarshipColors for dynamic access
        if _G.StarshipColors then
            _G.StarshipColors.MAIN = C_MAIN
            _G.StarshipColors.SIDE = C_SIDE
            _G.StarshipColors.ACCENT = C_ACCENT
            _G.StarshipColors.ITEM = C_ITEM
            _G.StarshipColors.TEXT = C_TEXT
            _G.StarshipColors.TEXT_DIM = C_TEXT_DIM
        end
        
        -- Update Registered Objects
        for _, item in ipairs(ThemeObjects) do
            local obj, prop, type = item.Object, item.Property, item.Type
            if obj and obj.Parent then
                if prop == "BackgroundColor3" then
                    if type == "Main" then obj.BackgroundColor3 = C_MAIN
                    elseif type == "Side" then obj.BackgroundColor3 = C_SIDE
                    elseif type == "Item" then obj.BackgroundColor3 = C_ITEM
                    elseif type == "Accent" then obj.BackgroundColor3 = C_ACCENT
                    -- Legacy/Fallback Logic
                    elseif obj == Main then obj.BackgroundColor3 = C_MAIN
                    elseif obj.Name == "Sidebar" then obj.BackgroundColor3 = C_SIDE
                    else obj.BackgroundColor3 = C_ACCENT end
                elseif prop == "TextColor3" then
                    if type == "Text" then obj.TextColor3 = C_TEXT
                    elseif type == "TextDim" then obj.TextColor3 = C_TEXT_DIM
                    elseif type == "Accent" then obj.TextColor3 = C_ACCENT
                    else obj.TextColor3 = C_TEXT end
                elseif prop == "ScrollBarImageColor3" then
                    obj.ScrollBarImageColor3 = C_ACCENT
                elseif prop == "ImageColor3" then
                    obj.ImageColor3 = C_ACCENT
                elseif prop == "Color" then -- For UIStroke
                    if type == "Accent" then obj.Color = C_ACCENT
                    elseif type == "Text" then obj.Color = C_TEXT
                    elseif type == "TextDim" then obj.Color = C_TEXT_DIM
                    else obj.Color = C_ACCENT end
                end
            end
        end
    end
    
    for name, themeData in pairs(Themes) do
        local btn = Instance.new("TextButton", ThemeContainer)
        btn.Text = name
        btn.BackgroundColor3 = C_SIDE
        btn.TextColor3 = themeData.Accent
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = themeData.Accent
        stroke.Transparency = 0.5
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        
        btn.MouseButton1Click:Connect(function()
            local t = Themes[name]
            Config.AccentColor = {R=math.floor(t.Accent.R*255), G=math.floor(t.Accent.G*255), B=math.floor(t.Accent.B*255)}
            ApplyTheme(name)
            -- Refresh Merger List to apply new theme colors
            if UIHandlers and UIHandlers.RefreshMergerList then
                UIHandlers.RefreshMergerList()
            end
            btn.Text = "APPLIED!"
            task.wait(0.5)
            btn.Text = name
        end)
    end
    
    -- PROFILE SYSTEM CARD
    local ProfileCard = CreateCard("PROFILE SYSTEM", 250, 4)
    
    local ProfileInfo = Instance.new("TextLabel", ProfileCard)
    ProfileInfo.Text = "Profiles save ALL settings + enabled features"
    ProfileInfo.Size = UDim2.new(0.9, 0, 0, 15)
    ProfileInfo.Position = UDim2.new(0.05, 0, 0, 30)
    ProfileInfo.BackgroundTransparency = 1
    ProfileInfo.TextColor3 = C_TEXT_DIM
    ProfileInfo.Font = Enum.Font.Gotham
    ProfileInfo.TextSize = 9
    ProfileInfo.TextXAlignment = Enum.TextXAlignment.Left
    
    local ProfileInput = Instance.new("TextBox", ProfileCard)
    ProfileInput.PlaceholderText = "Profile Name"
    ProfileInput.Size = UDim2.new(0.65, 0, 0, 35)
    ProfileInput.Position = UDim2.new(0.05, 0, 0, 50)
    ProfileInput.BackgroundColor3 = C_SIDE
    ProfileInput.TextColor3 = C_TEXT
    ProfileInput.PlaceholderColor3 = C_TEXT_DIM
    ProfileInput.Font = Enum.Font.Gotham
    ProfileInput.TextSize = 11
    Instance.new("UICorner", ProfileInput).CornerRadius = UDim.new(0, 6)
    RegisterTheme(ProfileInput, "BackgroundColor3", "Side")
    RegisterTheme(ProfileInput, "TextColor3", "Text")
    
    local BtnRefreshProfile = Instance.new("TextButton", ProfileCard)
    BtnRefreshProfile.Text = "REFRESH"
    BtnRefreshProfile.Size = UDim2.new(0.25, 0, 0, 35)
    BtnRefreshProfile.Position = UDim2.new(0.72, 0, 0, 50)
    StyleBtn(BtnRefreshProfile, C_TEXT)
    
    local ProfileList = Instance.new("ScrollingFrame", ProfileCard)
    ProfileList.Size = UDim2.new(0.9, 0, 0, 80)
    ProfileList.Position = UDim2.new(0.05, 0, 0, 90)
    ProfileList.BackgroundColor3 = C_SIDE
    ProfileList.BorderSizePixel = 0
    ProfileList.ScrollBarThickness = 4
    ProfileList.ScrollBarImageColor3 = C_ACCENT
    Instance.new("UICorner", ProfileList).CornerRadius = UDim.new(0, 6)
    RegisterTheme(ProfileList, "BackgroundColor3", "Side")
    RegisterTheme(ProfileList, "ScrollBarImageColor3", "Accent")
    
    local ProfileLayout = Instance.new("UIListLayout", ProfileList)
    ProfileLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ProfileLayout.Padding = UDim.new(0, 2)
    
    local function RefreshProfiles()
        for _, c in pairs(ProfileList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        if isfolder(PROFILE_FOLDER) then
            for _, file in pairs(listfiles(PROFILE_FOLDER)) do
                if file:match("%.json$") then
                    local name = file:match("([^/\\]+)%.json$")
                    local btn = Instance.new("TextButton", ProfileList)
                    btn.Text = name
                    btn.Size = UDim2.new(1, -5, 0, 25)
                    btn.BackgroundColor3 = C_SIDE
                    btn.TextColor3 = C_TEXT_DIM
                    btn.Font = Enum.Font.Gotham
                    btn.TextSize = 10
                    btn.TextXAlignment = Enum.TextXAlignment.Left
                    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                    RegisterTheme(btn, "BackgroundColor3", "Side")
                    RegisterTheme(btn, "TextColor3", "TextDim")
                    
                    btn.MouseButton1Click:Connect(function()
                        ProfileInput.Text = name
                    end)
                end
            end
            ProfileList.CanvasSize = UDim2.new(0, 0, 0, #ProfileList:GetChildren() * 27)
        end
    end
    
    BtnRefreshProfile.MouseButton1Click:Connect(RefreshProfiles)
    RefreshProfiles()
    
    local BtnSaveProfile = Instance.new("TextButton", ProfileCard)
    BtnSaveProfile.Text = "SAVE PROFILE"
    BtnSaveProfile.Size = UDim2.new(0.4, 0, 0, 35)
    BtnSaveProfile.Position = UDim2.new(0.05, 0, 0, 175)
    StyleBtn(BtnSaveProfile, C_GREEN)
    
    local BtnLoadProfile = Instance.new("TextButton", ProfileCard)
    BtnLoadProfile.Text = "LOAD PROFILE"
    BtnLoadProfile.Size = UDim2.new(0.4, 0, 0, 35)
    BtnLoadProfile.Position = UDim2.new(0.55, 0, 0, 175)
    StyleBtn(BtnLoadProfile, C_ACCENT)
    
    BtnSaveProfile.MouseButton1Click:Connect(function()
        local name = ProfileInput.Text
        if name == "" then name = "Default" end
        SaveProfile(name, Config, UI, UIHandlers)
        BtnSaveProfile.Text = "SAVED!"
        RefreshProfiles()
        task.wait(1)
        BtnSaveProfile.Text = "SAVE PROFILE"
    end)
    
    BtnLoadProfile.MouseButton1Click:Connect(function()
        local name = ProfileInput.Text
        if name == "" then name = "Default" end
        local success = LoadProfile(name, Config, Themes, UI, UIHandlers)
        if success then
            -- Re-setup entire UI to refresh keybinds
            SetupConfigUI(PageConfig, UI, Connections, Config, LocalPlayer, UIHandlers, Themes, ThemeObjects, Main)
        end
    end)
    
    -- AUTO-ENABLE CARD
    local AutoCard = CreateCard("AUTO-ENABLE ON STARTUP", 0, 5)
    AutoCard.AutomaticSize = Enum.AutomaticSize.Y
    
    local AutoInfo = Instance.new("TextLabel", AutoCard)
    AutoInfo.Text = "Select features to auto-enable when script loads"
    AutoInfo.Size = UDim2.new(0.9, 0, 0, 15)
    AutoInfo.Position = UDim2.new(0.05, 0, 0, 30)
    AutoInfo.BackgroundTransparency = 1
    AutoInfo.TextColor3 = C_TEXT_DIM
    AutoInfo.Font = Enum.Font.Gotham
    AutoInfo.TextSize = 9
    AutoInfo.TextXAlignment = Enum.TextXAlignment.Left
    
    local AutoList = Instance.new("Frame", AutoCard)
    AutoList.Size = UDim2.new(1, 0, 0, 0)
    AutoList.Position = UDim2.new(0, 0, 0, 50)
    AutoList.BackgroundTransparency = 1
    AutoList.AutomaticSize = Enum.AutomaticSize.Y
    
    local AutoLayout = Instance.new("UIListLayout", AutoList)
    AutoLayout.Padding = UDim.new(0, 3)
    AutoLayout.SortOrder = Enum.SortOrder.LayoutOrder
    AutoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    -- List of features for auto-enable
    local autoFeatures = {
        {id = "AntiAFK", name = "Anti-AFK"},
        {id = "ShiftLock", name = "Shift Lock"},
        {id = "Speed", name = "Speed Modifier"},
        {id = "Jump", name = "Jump Modifier"},
        {id = "InfJump", name = "Infinite Jump"},
        {id = "Fly", name = "Fly"},
        {id = "Momentum", name = "Always Momentum"},
        {id = "AntiSlip", name = "Anti-Slip"},
        {id = "AutoJump", name = "Auto Jump"},
        {id = "LongJump", name = "Long Jump"},
        {id = "AirLock", name = "Air Lock"},
        {id = "RealESP", name = "Real Path ESP"},
        {id = "Fullbright", name = "Fullbright"},
        {id = "BypassAdmin", name = "Bypass Admin"}
    }
    
    local function IsInAutoEnable(id)
        for _, v in ipairs(AutoEnableList) do
            if v == id then return true end
        end
        return false
    end
    
    local function ToggleAutoEnable(id)
        if IsInAutoEnable(id) then
            for i, v in ipairs(AutoEnableList) do
                if v == id then table.remove(AutoEnableList, i) break end
            end
        else
            table.insert(AutoEnableList, id)
        end
    end
    
    for _, feat in ipairs(autoFeatures) do
        local row = Instance.new("Frame", AutoList)
        row.Size = UDim2.new(0.95, 0, 0, 28)
        row.BackgroundColor3 = C_SIDE
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        RegisterTheme(row, "BackgroundColor3", "Side")
        
        local lbl = Instance.new("TextLabel", row)
        lbl.Text = feat.name
        lbl.Size = UDim2.new(0.7, 0, 1, 0)
        lbl.Position = UDim2.new(0.05, 0, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = C_TEXT
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        RegisterTheme(lbl, "TextColor3", "Text")
        
        local toggle = Instance.new("TextButton", row)
        toggle.Size = UDim2.new(0, 50, 0, 20)
        toggle.Position = UDim2.new(0.78, 0, 0.5, -10)
        toggle.BackgroundColor3 = IsInAutoEnable(feat.id) and C_GREEN or C_ITEM
        toggle.Text = IsInAutoEnable(feat.id) and "ON" or "OFF"
        toggle.TextColor3 = C_TEXT
        toggle.Font = Enum.Font.GothamBold
        toggle.TextSize = 9
        Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)
        RegisterTheme(toggle, "TextColor3", "Text")
        -- Note: BackgroundColor3 is dynamic (green/item based on state), can't directly register
        
        toggle.MouseButton1Click:Connect(function()
            ToggleAutoEnable(feat.id)
            local isOn = IsInAutoEnable(feat.id)
            toggle.BackgroundColor3 = isOn and C_GREEN or C_ITEM
            toggle.Text = isOn and "ON" or "OFF"
        end)
    end
    
    local BtnSaveAuto = Instance.new("TextButton", AutoCard)
    BtnSaveAuto.Text = "SAVE AUTO-ENABLE SETTINGS"
    BtnSaveAuto.Size = UDim2.new(0.9, 0, 0, 30)
    BtnSaveAuto.Position = UDim2.new(0.05, 0, 0, 50 + (#autoFeatures * 31) + 10)
    StyleBtn(BtnSaveAuto, C_ACCENT)
    
    BtnSaveAuto.MouseButton1Click:Connect(function()
        -- Save to a special auto-enable file
        writefile(CONFIG_FOLDER .. "/AutoEnable.json", HttpService:JSONEncode(AutoEnableList))
        if UI and UI.ShowToast then
            UI.ShowToast("Auto-Enable Saved", "Settings saved! Also included when you save a profile.", "success", 2)
        end
        BtnSaveAuto.Text = "SAVED!"
        task.wait(1)
        BtnSaveAuto.Text = "SAVE AUTO-ENABLE SETTINGS"
    end)
    
    -- Load existing auto-enable on UI setup
    if isfile(CONFIG_FOLDER .. "/AutoEnable.json") then
        local s, r = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FOLDER .. "/AutoEnable.json"))
        end)
        if s and r then
            AutoEnableList = r
            -- Refresh toggle states
            for _, child in pairs(AutoList:GetChildren()) do
                if child:IsA("Frame") then
                    local toggle = child:FindFirstChildOfClass("TextButton")
                    local lbl = child:FindFirstChildOfClass("TextLabel")
                    if toggle and lbl then
                        for _, feat in ipairs(autoFeatures) do
                            if feat.name == lbl.Text then
                                local isOn = IsInAutoEnable(feat.id)
                                toggle.BackgroundColor3 = isOn and C_GREEN or C_ITEM
                                toggle.Text = isOn and "ON" or "OFF"
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    UIHandlers.SaveConfig = SaveConfig
    UIHandlers.LoadConfig = LoadConfig
    UIHandlers.SaveProfile = function(name) SaveProfile(name, Config, UI, UIHandlers) end
    UIHandlers.LoadProfile = function(name) LoadProfile(name, Config, Themes, UI, UIHandlers) end
    UIHandlers.SetFeatureState = SetFeatureState
    UIHandlers.GetFeatureState = GetFeatureState
    UIHandlers.FeatureStates = FeatureStates
    UIHandlers.AutoEnableList = AutoEnableList
    UIHandlers.RunAutoEnable = function() RunAutoEnable(UIHandlers) end
    
    -- Initial Theme Application
    if Config.Theme then ApplyTheme(Config.Theme) end
end

return {
    SetupUI = SetupConfigUI,
    SaveConfig = SaveConfig,
    LoadConfig = LoadConfig,
    SaveProfile = SaveProfile,
    LoadProfile = LoadProfile,
    SetFeatureState = SetFeatureState,
    GetFeatureState = GetFeatureState,
    FeatureStates = FeatureStates,
    RunAutoEnable = RunAutoEnable
}
