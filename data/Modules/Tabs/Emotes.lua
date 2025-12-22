local function SetupEmotesUI(ScreenGui, UI, Connections, Config, LocalPlayer, UIHandlers, RegisterTheme)
    local UserInputService = game:GetService("UserInputService")
    local AvatarEditorService = game:GetService("AvatarEditorService")
    local HttpService = game:GetService("HttpService")
    local RunService = game:GetService("RunService")

    -- Helper function to get localized text
    local function L(key, ...)
        if _G.StarshipLocale and _G.StarshipLocale.Get then
            return _G.StarshipLocale.Get(key, ...)
        end
        return key
    end

    -- UPDATED THEME
    local C_MAIN = Color3.fromRGB(10, 10, 14);
    local C_SIDE = Color3.fromRGB(15, 15, 20);
    local C_ACCENT = Color3.fromRGB(90, 110, 245); -- Midnight Blue
    local C_TEXT = Color3.fromRGB(240, 240, 250);
    local C_TEXT_DIM = Color3.fromRGB(140, 140, 160);
    local C_ITEM = Color3.fromRGB(20, 20, 28);
    local C_RED = Color3.fromRGB(255, 80, 80);
    local C_YELLOW = Color3.fromRGB(255, 220, 60);
    local C_GREEN = Color3.fromRGB(60, 255, 160)

    -- Ensure RegisterTheme exists
    if not RegisterTheme then RegisterTheme = function() end end

    -- Create Standalone Window
    local EmoteWindow = Instance.new("Frame", ScreenGui)
    EmoteWindow.Name = "EmoteWindow"
    EmoteWindow.Size = UDim2.new(0, 600, 0, 400)
    EmoteWindow.Position = UDim2.new(0.5, -300, 0.5, -200)
    EmoteWindow.BackgroundColor3 = C_SIDE
    EmoteWindow.Visible = false
    EmoteWindow.ZIndex = 200
    Instance.new("UICorner", EmoteWindow).CornerRadius = UDim.new(0, 12)
    RegisterTheme(EmoteWindow, "BackgroundColor3", "Side")

    local Stroke = Instance.new("UIStroke", EmoteWindow)
    Stroke.Color = C_ACCENT
    Stroke.Thickness = 1
    Stroke.Transparency = 0.6
    RegisterTheme(Stroke, "Color", "Accent")

    -- Dragging
    local dragging, dragInput, dragStart, startPos
    EmoteWindow.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = EmoteWindow.Position
        end
    end)
    EmoteWindow.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            EmoteWindow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale,
                startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    -- Header
    local Header = Instance.new("Frame", EmoteWindow)
    Header.Size = UDim2.new(1, 0, 0, 40)
    Header.BackgroundTransparency = 1
    Header.ZIndex = 201

    local Title = Instance.new("TextLabel", Header)
    Title.Text = L("emotes_menu")
    Title.Size = UDim2.new(1, -40, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = C_TEXT
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.ZIndex = 202
    RegisterTheme(Title, "TextColor3", "Text")

    local CloseBtn = Instance.new("TextButton", Header)
    CloseBtn.Text = "×"
    CloseBtn.Size = UDim2.new(0, 40, 1, 0)
    CloseBtn.Position = UDim2.new(1, -40, 0, 0)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.TextColor3 = C_RED
    CloseBtn.TextSize = 24
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.ZIndex = 202
    CloseBtn.MouseButton1Click:Connect(function() EmoteWindow.Visible = false end)

    -- Container for Content
    local EmoteContainer = Instance.new("Frame", EmoteWindow)
    EmoteContainer.Size = UDim2.new(1, -20, 1, -50)
    EmoteContainer.Position = UDim2.new(0, 10, 0, 45)
    EmoteContainer.BackgroundTransparency = 1
    EmoteContainer.ZIndex = 201

    -- Tabs for Emotes (Catalog / Saved)
    local TabFrame = Instance.new("Frame", EmoteContainer)
    TabFrame.Size = UDim2.new(1, 0, 0, 30)
    TabFrame.BackgroundTransparency = 1
    TabFrame.ZIndex = 202

    local BtnCatalog = Instance.new("TextButton", TabFrame)
    BtnCatalog.Size = UDim2.new(0.48, 0, 1, 0)
    BtnCatalog.Position = UDim2.new(0, 0, 0, 0)
    BtnCatalog.BackgroundColor3 = C_ACCENT
    BtnCatalog.Text = L("emotes_catalog")
    BtnCatalog.TextColor3 = Color3.new(0, 0, 0)
    BtnCatalog.Font = Enum.Font.GothamBold
    BtnCatalog.TextSize = 12
    BtnCatalog.ZIndex = 203
    Instance.new("UICorner", BtnCatalog).CornerRadius = UDim.new(0, 6)

    local BtnSaved = Instance.new("TextButton", TabFrame)
    BtnSaved.Size = UDim2.new(0.48, 0, 1, 0)
    BtnSaved.Position = UDim2.new(0.52, 0, 0, 0)
    BtnSaved.BackgroundColor3 = C_ITEM
    BtnSaved.Text = L("emotes_saved")
    BtnSaved.TextColor3 = C_TEXT_DIM
    BtnSaved.Font = Enum.Font.GothamBold
    BtnSaved.TextSize = 12
    BtnSaved.ZIndex = 203
    Instance.new("UICorner", BtnSaved).CornerRadius = UDim.new(0, 6)

    -- Content Areas
    local ContentCatalog = Instance.new("Frame", EmoteContainer)
    ContentCatalog.Size = UDim2.new(1, 0, 1, -40)
    ContentCatalog.Position = UDim2.new(0, 0, 0, 40)
    ContentCatalog.BackgroundTransparency = 1
    ContentCatalog.Visible = true
    ContentCatalog.ZIndex = 202

    local ContentSaved = Instance.new("Frame", EmoteContainer)
    ContentSaved.Size = UDim2.new(1, 0, 1, -40)
    ContentSaved.Position = UDim2.new(0, 0, 0, 40)
    ContentSaved.BackgroundTransparency = 1
    ContentSaved.Visible = false
    ContentSaved.ZIndex = 202

    -- Logic Variables
    local savedEmotes = {}
    local SAVE_FILE = "StarshipEmotes.json"
    local CurrentTrack = nil

    local Settings = {
        ["Speed"] = 1,
        ["Fade In"] = 0.1,
        ["Fade Out"] = 0.1,
        ["Weight"] = 1,
        ["Time Position"] = 0,
        ["Looped"] = true,
        ["Stop Emote When Moving"] = true,
        ["Stop Other Animations On Play"] = true,
        ["Allow Invisible"] = true
    }

    local function loadSavedEmotes()
        local s, d = pcall(function() return HttpService:JSONDecode(readfile(SAVE_FILE)) end)
        if s and type(d) == "table" then savedEmotes = d else savedEmotes = {} end
    end
    local function saveEmotesToData()
        pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode(savedEmotes)) end)
    end
    loadSavedEmotes()

    local function LoadTrack(id)
        local player = LocalPlayer
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        if not humanoid then return end

        if CurrentTrack then CurrentTrack:Stop(Settings["Fade Out"]) end

        local animId = "rbxassetid://" .. tostring(id)
        -- Attempt to resolve if it's a catalog ID
        local ok, result = pcall(function() return game:GetObjects(animId) end)
        if ok and result and #result > 0 and result[1]:IsA("Animation") then
            animId = result[1].AnimationId
        end

        local newAnim = Instance.new("Animation")
        newAnim.AnimationId = animId
        local newTrack = humanoid:LoadAnimation(newAnim)
        newTrack.Priority = Enum.AnimationPriority.Action4

        if Settings["Stop Other Animations On Play"] then
            for _, t in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
                if t ~= newTrack and t.Priority ~= Enum.AnimationPriority.Action4 then t:Stop() end
            end
        end

        newTrack:Play(Settings["Fade In"], math.max(0.001, Settings["Weight"]), Settings["Speed"])
        CurrentTrack = newTrack
        CurrentTrack.Looped = Settings["Looped"]
        return newTrack
    end

    -- Catalog UI
    local SearchBox = Instance.new("TextBox", ContentCatalog)
    SearchBox.Size = UDim2.new(0.65, 0, 0, 30)
    SearchBox.BackgroundColor3 = C_ITEM
    SearchBox.TextColor3 = C_TEXT
    SearchBox.PlaceholderText = "Search Emotes..."
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextSize = 12
    SearchBox.ZIndex = 203
    Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 6)
    RegisterTheme(SearchBox, "BackgroundColor3", "Item")
    RegisterTheme(SearchBox, "TextColor3", "Text")

    local BtnSearch = Instance.new("TextButton", ContentCatalog)
    BtnSearch.Size = UDim2.new(0.20, 0, 0, 30)
    BtnSearch.Position = UDim2.new(0.66, 0, 0, 0)
    BtnSearch.BackgroundColor3 = C_ACCENT
    BtnSearch.Text = "SEARCH"
    BtnSearch.TextColor3 = Color3.new(0, 0, 0)
    BtnSearch.Font = Enum.Font.GothamBold
    BtnSearch.TextSize = 10
    BtnSearch.ZIndex = 203
    Instance.new("UICorner", BtnSearch).CornerRadius = UDim.new(0, 6)
    RegisterTheme(BtnSearch, "BackgroundColor3", "Accent")

    -- Pagination Buttons
    local BtnPrev = Instance.new("TextButton", ContentCatalog)
    BtnPrev.Text = "<"
    BtnPrev.Size = UDim2.new(0.06, 0, 0, 30)
    BtnPrev.Position = UDim2.new(0.87, 0, 0, 0)
    BtnPrev.BackgroundColor3 = C_ITEM
    BtnPrev.TextColor3 = C_TEXT
    BtnPrev.Font = Enum.Font.GothamBold
    BtnPrev.TextSize = 14
    BtnPrev.ZIndex = 203
    Instance.new("UICorner", BtnPrev).CornerRadius = UDim.new(0, 6)
    RegisterTheme(BtnPrev, "BackgroundColor3", "Item")
    RegisterTheme(BtnPrev, "TextColor3", "Text")

    local BtnNext = Instance.new("TextButton", ContentCatalog)
    BtnNext.Text = ">"
    BtnNext.Size = UDim2.new(0.06, 0, 0, 30)
    BtnNext.Position = UDim2.new(0.94, 0, 0, 0)
    BtnNext.BackgroundColor3 = C_ITEM
    BtnNext.TextColor3 = C_TEXT
    BtnNext.Font = Enum.Font.GothamBold
    BtnNext.TextSize = 14
    BtnNext.ZIndex = 203
    Instance.new("UICorner", BtnNext).CornerRadius = UDim.new(0, 6)
    RegisterTheme(BtnNext, "BackgroundColor3", "Item")
    RegisterTheme(BtnNext, "TextColor3", "Text")

    local CatalogScroll = Instance.new("ScrollingFrame", ContentCatalog)
    CatalogScroll.Size = UDim2.new(1, 0, 1, -40)
    CatalogScroll.Position = UDim2.new(0, 0, 0, 40)
    CatalogScroll.BackgroundTransparency = 1
    CatalogScroll.BorderSizePixel = 0
    CatalogScroll.ScrollBarThickness = 4
    CatalogScroll.ScrollBarImageColor3 = C_ACCENT
    CatalogScroll.ZIndex = 203
    RegisterTheme(CatalogScroll, "ScrollBarImageColor3", "Accent")

    local LoadingLabel = Instance.new("TextLabel", ContentCatalog)
    LoadingLabel.Size = UDim2.new(1, 0, 1, -40)
    LoadingLabel.Position = UDim2.new(0, 0, 0, 40)
    LoadingLabel.BackgroundTransparency = 1
    LoadingLabel.Text = "Loading..."
    LoadingLabel.TextColor3 = C_TEXT_DIM
    LoadingLabel.Font = Enum.Font.GothamBold
    LoadingLabel.TextSize = 18
    LoadingLabel.Visible = false
    LoadingLabel.ZIndex = 205
    RegisterTheme(LoadingLabel, "TextColor3", "TextDim")

    local CatalogLayout = Instance.new("UIGridLayout", CatalogScroll)
    CatalogLayout.CellSize = UDim2.new(0, 100, 0, 140)
    CatalogLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    CatalogLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local function CreateEmoteCard(item, parent, isSaved)
        local card = Instance.new("Frame", parent)
        card.BackgroundColor3 = C_ITEM
        card.ZIndex = 204
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
        local cs = Instance.new("UIStroke", card); cs.Color = C_ACCENT; cs.Transparency = 0.8

        RegisterTheme(card, "BackgroundColor3", "Item")
        RegisterTheme(cs, "Color", "Accent")

        local img = Instance.new("ImageLabel", card)
        img.Size = UDim2.new(1, -10, 0, 80)
        img.Position = UDim2.new(0, 5, 0, 5)
        img.BackgroundTransparency = 1
        img.ScaleType = Enum.ScaleType.Fit
        local thumbId = item.AssetId or item.Id
        img.Image = "rbxthumb://type=Asset&id=" .. tostring(thumbId) .. "&w=150&h=150"
        img.ZIndex = 205

        local name = Instance.new("TextLabel", card)
        name.Size = UDim2.new(1, -10, 0, 20)
        name.Position = UDim2.new(0, 5, 0, 85)
        name.BackgroundTransparency = 1
        name.Text = item.Name or "Unknown"
        name.TextColor3 = C_TEXT
        name.Font = Enum.Font.GothamBold
        name.TextSize = 10
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.ZIndex = 205
        RegisterTheme(name, "TextColor3", "Text")

        local btnPlay = Instance.new("TextButton", card)
        btnPlay.Text = "PLAY"
        btnPlay.Size = UDim2.new(0.45, 0, 0, 20)
        btnPlay.Position = UDim2.new(0, 5, 1, -25)
        btnPlay.BackgroundColor3 = C_GREEN
        btnPlay.TextColor3 = Color3.new(0, 0, 0)
        btnPlay.Font = Enum.Font.GothamBold
        btnPlay.TextSize = 9
        btnPlay.ZIndex = 205
        Instance.new("UICorner", btnPlay).CornerRadius = UDim.new(0, 4)
        btnPlay.MouseButton1Click:Connect(function() LoadTrack(thumbId) end)

        local btnAction = Instance.new("TextButton", card)
        btnAction.Text = isSaved and "DEL" or "SAVE"
        btnAction.Size = UDim2.new(0.45, 0, 0, 20)
        btnAction.Position = UDim2.new(0.55, 0, 1, -25)
        btnAction.BackgroundColor3 = isSaved and C_RED or C_ACCENT
        btnAction.TextColor3 = Color3.new(0, 0, 0)
        btnAction.Font = Enum.Font.GothamBold
        btnAction.TextSize = 9
        btnAction.ZIndex = 205
        Instance.new("UICorner", btnAction).CornerRadius = UDim.new(0, 4)

        btnAction.MouseButton1Click:Connect(function()
            if isSaved then
                for i, v in ipairs(savedEmotes) do
                    if v.Id == item.Id then
                        table.remove(savedEmotes, i)
                        break
                    end
                end
                saveEmotesToData()
                card:Destroy()
            else
                local exists = false
                for _, v in ipairs(savedEmotes) do
                    if v.Id == item.Id then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(savedEmotes, { Id = item.Id, Name = item.Name, AssetId = thumbId })
                    saveEmotesToData()
                    btnAction.Text = "SAVED"
                    task.wait(1)
                    btnAction.Text = "SAVE"
                end
            end
        end)
    end

    local currentPages = nil

    local function LoadPage(items)
        for _, c in pairs(CatalogScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        if #items == 0 then
            warn("Starship: No emotes found on this page")
        end
        for _, item in ipairs(items) do
            CreateEmoteCard(item, CatalogScroll, false)
        end
        CatalogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        CatalogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    end

    local function SearchCatalog(keyword)
        LoadingLabel.Visible = true
        CatalogScroll.Visible = false
        currentPages = nil

        local params = CatalogSearchParams.new()
        params.SearchKeyword = keyword
        params.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
        params.SortType = Enum.CatalogSortType.Relevance
        params.Limit = 30
        params.IncludeOffSale = true
        params.SalesTypeFilter = Enum.SalesTypeFilter.All

        task.spawn(function()
            local s, pages = pcall(function() return AvatarEditorService:SearchCatalog(params) end)
            LoadingLabel.Visible = false
            CatalogScroll.Visible = true

            if s and pages then
                currentPages = pages
                LoadPage(currentPages:GetCurrentPage())
            else
                warn("Starship: Catalog Search Failed - " .. tostring(pages))
            end
        end)
    end

    BtnNext.MouseButton1Click:Connect(function()
        if currentPages and not currentPages.IsFinished then
            LoadingLabel.Visible = true
            CatalogScroll.Visible = false
            task.spawn(function()
                pcall(function() currentPages:AdvanceToNextPageAsync() end)
                LoadPage(currentPages:GetCurrentPage())
                LoadingLabel.Visible = false
                CatalogScroll.Visible = true
            end)
        end
    end)

    local function RefreshSaved()
        for _, c in pairs(ContentSaved:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        local SavedScroll = Instance.new("ScrollingFrame", ContentSaved)
        SavedScroll.Size = UDim2.new(1, 0, 1, 0)
        SavedScroll.BackgroundTransparency = 1
        SavedScroll.BorderSizePixel = 0
        SavedScroll.ScrollBarThickness = 4
        SavedScroll.ScrollBarImageColor3 = C_ACCENT
        SavedScroll.ZIndex = 203

        local SavedLayout = Instance.new("UIGridLayout", SavedScroll)
        SavedLayout.CellSize = UDim2.new(0, 100, 0, 140)
        SavedLayout.CellPadding = UDim2.new(0, 10, 0, 10)
        SavedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

        for _, item in ipairs(savedEmotes) do
            CreateEmoteCard(item, SavedScroll, true)
        end
        SavedScroll.CanvasSize = UDim2.new(0, 0, 0, math.ceil(#savedEmotes / 3) * 150)
    end

    BtnSearch.MouseButton1Click:Connect(function() SearchCatalog(SearchBox.Text) end)
    SearchBox.FocusLost:Connect(function(enter) if enter then SearchCatalog(SearchBox.Text) end end)

    task.defer(function() SearchCatalog("") end)

    BtnCatalog.MouseButton1Click:Connect(function()
        ContentCatalog.Visible = true; ContentSaved.Visible = false
        BtnCatalog.BackgroundColor3 = C_ACCENT; BtnCatalog.TextColor3 = Color3.new(0, 0, 0)
        BtnSaved.BackgroundColor3 = C_ITEM; BtnSaved.TextColor3 = C_TEXT_DIM
    end)

    BtnSaved.MouseButton1Click:Connect(function()
        ContentCatalog.Visible = false; ContentSaved.Visible = true
        BtnCatalog.BackgroundColor3 = C_ITEM; BtnCatalog.TextColor3 = C_TEXT_DIM
        BtnSaved.BackgroundColor3 = C_ACCENT; BtnSaved.TextColor3 = Color3.new(0, 0, 0)
        RefreshSaved()
    end)
    -- Settings Panel (Small Overlay)
    local SettingsFrame = Instance.new("Frame", EmoteContainer)
    SettingsFrame.Size = UDim2.new(1, 0, 0, 100)
    SettingsFrame.Position = UDim2.new(0, 0, 1, -100)
    SettingsFrame.BackgroundColor3 = C_SIDE
    SettingsFrame.Visible = false
    SettingsFrame.ZIndex = 210

    local BtnSettings = Instance.new("TextButton", Header)
    BtnSettings.Size = UDim2.new(0, 30, 1, 0)
    BtnSettings.Position = UDim2.new(1, -80, 0, 0)
    BtnSettings.BackgroundColor3 = C_ITEM
    BtnSettings.BackgroundTransparency = 1
    BtnSettings.Text = "⚙"
    BtnSettings.TextColor3 = C_TEXT
    BtnSettings.Font = Enum.Font.GothamBold
    BtnSettings.TextSize = 18
    BtnSettings.ZIndex = 202

    local SettingsPanel = Instance.new("ScrollingFrame", EmoteContainer)
    SettingsPanel.Size = UDim2.new(1, 0, 1, -40)
    SettingsPanel.Position = UDim2.new(0, 0, 0, 40)
    SettingsPanel.BackgroundColor3 = C_SIDE
    SettingsPanel.Visible = false
    SettingsPanel.ZIndex = 210

    BtnSettings.MouseButton1Click:Connect(function()
        SettingsPanel.Visible = not SettingsPanel.Visible
    end)

    local SLayout = Instance.new("UIListLayout", SettingsPanel)
    SLayout.Padding = UDim.new(0, 5)

    local function AddToggle(name)
        local f = Instance.new("Frame", SettingsPanel)
        f.Size = UDim2.new(1, 0, 0, 30)
        f.BackgroundTransparency = 1
        f.ZIndex = 211
        local b = Instance.new("TextButton", f)
        b.Size = UDim2.new(0.9, 0, 1, 0)
        b.Position = UDim2.new(0.05, 0, 0, 0)
        b.BackgroundColor3 = C_ITEM
        b.Text = name .. ": " .. (Settings[name] and "ON" or "OFF")
        b.TextColor3 = Settings[name] and C_GREEN or C_RED
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.ZIndex = 212
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        local ts = Instance.new("UIStroke", b); ts.Color = Settings[name] and C_GREEN or C_RED; ts.Transparency = 0.6; ts.ApplyStrokeMode =
            Enum.ApplyStrokeMode.Border

        b.MouseButton1Click:Connect(function()
            Settings[name] = not Settings[name]
            b.Text = name .. ": " .. (Settings[name] and "ON" or "OFF")
            b.TextColor3 = Settings[name] and C_GREEN or C_RED
            ts.Color = Settings[name] and C_GREEN or C_RED
            if name == "Looped" and CurrentTrack then CurrentTrack.Looped = Settings[name] end
        end)
    end

    local function AddSlider(name, min, max)
        local f = Instance.new("Frame", SettingsPanel)
        f.Size = UDim2.new(1, 0, 0, 40)
        f.BackgroundTransparency = 1
        f.ZIndex = 211
        local l = Instance.new("TextLabel", f)
        l.Text = name .. ": " .. Settings[name]
        l.Size = UDim2.new(1, -20, 0, 15)
        l.Position = UDim2.new(0, 10, 0, 0)
        l.BackgroundTransparency = 1
        l.TextColor3 = C_TEXT
        l.Font = Enum.Font.Gotham
        l.TextSize = 10
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = 212

        local s = Instance.new("TextButton", f)
        s.Text = ""
        s.Size = UDim2.new(0.9, 0, 0, 6)
        s.Position = UDim2.new(0.05, 0, 0, 25)
        s.BackgroundColor3 = C_ITEM
        s.ZIndex = 212
        Instance.new("UICorner", s)

        local fill = Instance.new("Frame", s)
        fill.Size = UDim2.new((Settings[name] - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = C_ACCENT
        fill.ZIndex = 213
        Instance.new("UICorner", fill)

        local dragging = false
        s.MouseButton1Down:Connect(function() dragging = true end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                local p = math.clamp((i.Position.X - s.AbsolutePosition.X) / s.AbsoluteSize.X, 0, 1)
                local val = min + (max - min) * p
                Settings[name] = math.floor(val * 100) / 100
                fill.Size = UDim2.new(p, 0, 1, 0)
                l.Text = name .. ": " .. Settings[name]
                if name == "Speed" and CurrentTrack then CurrentTrack:AdjustSpeed(Settings[name]) end
            end
        end)
    end

    AddSlider("Speed", 0, 5)
    AddToggle("Looped")
    AddToggle("Stop Emote When Moving")
    AddToggle("Allow Invisible")

    -- Loop for moving check
    RunService.RenderStepped:Connect(function()
        if Settings["Stop Emote When Moving"] and CurrentTrack and CurrentTrack.IsPlaying then
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("Humanoid")
            if h and (h.MoveDirection.Magnitude > 0.1 or h:GetState() == Enum.HumanoidStateType.Jumping) then
                CurrentTrack:Stop(Settings["Fade Out"])
                CurrentTrack = nil
            end
        end
    end)

    -- Export Toggle Function
    UIHandlers.ToggleEmoteWindow = function()
        EmoteWindow.Visible = not EmoteWindow.Visible
    end
end

return SetupEmotesUI
