--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║              STARSHIP MOBILE LOADER                           ║
    ║              Secure Whitelist Authentication                  ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Configuration
local SECURE_API_URL = "https://starship-core.my.id"
local MOBILE_UI_API = SECURE_API_URL .. "/api/get-mobile-ui?userId="
local MOBILE_AUTH_API = SECURE_API_URL .. "/api/mobile-load"

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

-- Create Loading UI
local function createLoadingUI()
    -- Remove existing UI if any
    local existingGui = LocalPlayer:FindFirstChild("PlayerGui") and
        LocalPlayer.PlayerGui:FindFirstChild("StarshipMobileLoader")
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
        ColorSequenceKeypoint.new(1, Color3.fromHex("#0a0a0f"))
    })
    gradient.Rotation = 45
    gradient.Parent = background

    -- Main Container
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 320, 0, 200)
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

    -- Logo/Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -40, 0, 40)
    title.Position = UDim2.new(0.5, 0, 0, 30)
    title.AnchorPoint = Vector2.new(0.5, 0)
    title.BackgroundTransparency = 1
    title.Text = "⭐ STARSHIP MOBILE"
    title.TextColor3 = Color3.fromHex("#ffffff")
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.Parent = container

    -- Status Text
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, -40, 0, 25)
    statusLabel.Position = UDim2.new(0.5, 0, 0, 85)
    statusLabel.AnchorPoint = Vector2.new(0.5, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Initializing..."
    statusLabel.TextColor3 = Color3.fromHex("#a1a1aa")
    statusLabel.TextSize = 14
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = container

    -- Progress Bar Background
    local progressBg = Instance.new("Frame")
    progressBg.Name = "ProgressBg"
    progressBg.Size = UDim2.new(1, -60, 0, 8)
    progressBg.Position = UDim2.new(0.5, 0, 0, 130)
    progressBg.AnchorPoint = Vector2.new(0.5, 0)
    progressBg.BackgroundColor3 = Color3.fromHex("#2a2a3e")
    progressBg.BorderSizePixel = 0
    progressBg.Parent = container

    local progressBgCorner = Instance.new("UICorner")
    progressBgCorner.CornerRadius = UDim.new(1, 0)
    progressBgCorner.Parent = progressBg

    -- Progress Bar Fill
    local progressFill = Instance.new("Frame")
    progressFill.Name = "Fill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromHex("#6366f1")
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg

    local progressFillCorner = Instance.new("UICorner")
    progressFillCorner.CornerRadius = UDim.new(1, 0)
    progressFillCorner.Parent = progressFill

    local progressGradient = Instance.new("UIGradient")
    progressGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHex("#6366f1")),
        ColorSequenceKeypoint.new(1, Color3.fromHex("#8b5cf6"))
    })
    progressGradient.Parent = progressFill

    -- Version label
    local versionLabel = Instance.new("TextLabel")
    versionLabel.Name = "Version"
    versionLabel.Size = UDim2.new(1, 0, 0, 20)
    versionLabel.Position = UDim2.new(0.5, 0, 1, -25)
    versionLabel.AnchorPoint = Vector2.new(0.5, 0)
    versionLabel.BackgroundTransparency = 1
    versionLabel.Text = "v1.0.0-mobile"
    versionLabel.TextColor3 = Color3.fromHex("#4a4a5e")
    versionLabel.TextSize = 11
    versionLabel.Font = Enum.Font.Gotham
    versionLabel.Parent = container

    -- Update function
    local function updateStatus(text, progress)
        statusLabel.Text = text
        TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(progress, 0, 1, 0)
        }):Play()
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

-- Main Authentication Function
local function main()
    local loaderGui, updateStatus = createLoadingUI()

    -- Step 1: Initialize
    updateStatus("Initializing...", 0.1)
    task.wait(0.3)

    -- Step 2: Get User ID
    updateStatus("Detecting user...", 0.2)
    local userId = tostring(LocalPlayer.UserId)
    task.wait(0.2)

    -- Step 3: Authenticate with MOBILE-SPECIFIC Server (Separate from PC)
    updateStatus("Authenticating...", 0.4)

    -- Call mobile-load API (separate whitelist from PC)
    local authUrl = MOBILE_AUTH_API .. "?userId=" .. userId
    local authSuccess, authResponse = pcall(function()
        return game:HttpGet(authUrl)
    end)

    if not authSuccess then
        if loaderGui then loaderGui:Destroy() end
        showError("Connection Failed\nServer Unreachable")
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
        if loaderGui then loaderGui:Destroy() end
        showError("Server Error\nInvalid Response")
        return
    end

    -- Check status
    if data.status == "denied" then
        if loaderGui then loaderGui:Destroy() end
        local errorMsg = data.message or "Not Whitelisted for Mobile"
        if data.hint then
            errorMsg = errorMsg .. "\n\n" .. data.hint
        end
        showError(errorMsg)
        return
    elseif data.status ~= "success" then
        if loaderGui then loaderGui:Destroy() end
        showError("Error: " .. tostring(data.error or "Unknown"))
        return
    end

    updateStatus("Access granted!", 0.7)
    task.wait(0.2)

    -- Step 4: Store session data for main script
    getgenv().StarshipSession = {
        Role = data.role or "MOBILE VIP",
        Duration = data.duration or "LIFETIME",
        Expiry = data.expiry,
        RemainingDays = data.remainingDays,
        ActivatedAt = data.activatedAt,
        Platform = "mobile",
        DeviceCount = data.deviceCount,
        MaxDevices = data.maxDevices,
        Username = data.username,
    }

    updateStatus("Loading Starship Mobile...", 0.85)
    task.wait(0.3)

    -- Step 6: Load Mobile UI Script (from protected API)
    local userId = tostring(LocalPlayer.UserId)
    local mobileScriptSuccess, mobileScript = pcall(function()
        return game:HttpGet(MOBILE_UI_API .. userId)
    end)

    if not mobileScriptSuccess then
        if loaderGui then loaderGui:Destroy() end
        showError("Failed to load Mobile UI\n\nConnection Error")
        return
    end

    if not mobileScript or mobileScript == "" then
        if loaderGui then loaderGui:Destroy() end
        showError("Failed to load Mobile UI\n\nEmpty Response")
        return
    end

    -- Check if response is an error message
    if mobileScript:find("error%(") then
        if loaderGui then loaderGui:Destroy() end
        local errorMsg = mobileScript:match('error%("(.-)"%)')
        showError(errorMsg or "Mobile UI Access Denied")
        return
    end

    updateStatus("Launching...", 1.0)
    task.wait(0.4)

    -- Step 7: Execute Mobile Script
    local func, err = loadstring(mobileScript)
    if not func then
        if loaderGui then loaderGui:Destroy() end
        showError("Execution Error:\n" .. tostring(err))
        return
    end

    -- Smooth exit animation
    if loaderGui then
        local MainFrame = loaderGui:FindFirstChild("Background")
        if MainFrame then
            local Container = MainFrame:FindFirstChild("Container")
            if Container then
                TweenService:Create(Container, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(0.5, 0, 0.6, 0),
                    BackgroundTransparency = 1
                }):Play()
            end

            TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 1
            }):Play()
        end

        task.wait(0.5)
        loaderGui:Destroy()
    end

    -- Run the mobile script
    func()
end

-- Execute
main()
