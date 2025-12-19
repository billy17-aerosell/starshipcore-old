local HttpService = game:GetService("HttpService")
local VERCEL_URL = "https://starship-core.my.id"
local ENCRYPTION_KEY = "StarshipSecretKey2025"
local FOLDER_NAME = "StarshipCore"
local MODULES_FOLDER = FOLDER_NAME .. "/Modules"
local TABS_FOLDER = MODULES_FOLDER .. "/Tabs"
local MODULES = { "Config.lua", "UI.lua", "Intro.lua", "Animations.lua" }
local TABS = { "Dashboard.lua", "Tools.lua", "Warp.lua", "Helper.lua", "Fun.lua", "Emotes.lua", "ConfigTab.lua" }

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

-- Download module via secure API (encrypted in production)
local function downloadModule(moduleName, savePath, userId)
    local url = VERCEL_URL .. "/api/get-module?name=" .. moduleName .. "&user=" .. userId

    -- Debug: Log URL being called
    -- warn("[Starship] Downloading: " .. url)

    local success, response = pcall(function()
        return game:HttpGet(url)
    end)

    if not success or not response or response == "" then
        warn("[Starship] Failed to download module: " .. moduleName)
        if response then
            warn("[Starship] Response: " .. tostring(response):sub(1, 200))
        end
        return false
    end

    -- Debug: Log response preview
    -- warn("[Starship] Response preview: " .. response:sub(1, 100))

    -- Check if response is JSON error
    if response:find('"error"') then
        warn("[Starship] Module error: " .. moduleName .. " - " .. response)
        return false
    end

    -- Try to parse as JSON (encrypted module)
    local data = nil
    local parseSuccess, parseError = pcall(function()
        data = HttpService:JSONDecode(response)
    end)

    if not parseSuccess then
        warn("[Starship] JSON parse failed for " .. moduleName .. ": " .. tostring(parseError))
        warn("[Starship] Raw response: " .. response:sub(1, 300))

        -- Check if it's actually a Lua script (starts with comment or local/return)
        local trimmed = response:match("^%s*(.-)%s*$") or response
        if trimmed:match("^%-%-") or trimmed:match("^local%s") or trimmed:match("^return%s") then
            warn("[Starship] Response looks like Lua, saving directly: " .. moduleName)
            writefile(savePath, response)
            return true
        end

        return false
    end

    if data and data.status == "success" and data.key and data.blob then
        -- Decrypt the module
        local encryptedString = base64Decode(data.blob)
        local decryptedContent = xorEncrypt(encryptedString, data.key)

        -- Remove BOM if present
        if #decryptedContent >= 3 and string.byte(decryptedContent, 1) == 239 and string.byte(decryptedContent, 2) == 187 and string.byte(decryptedContent, 3) == 191 then
            decryptedContent = string.sub(decryptedContent, 4)
        end

        -- Validate decrypted content looks like Lua
        local trimmed = decryptedContent:match("^%s*(.-)%s*$") or decryptedContent
        if not (trimmed:match("^%-%-") or trimmed:match("^local%s") or trimmed:match("^return%s") or trimmed:match("^function%s")) then
            warn("[Starship] Decrypted content doesn't look like Lua for " .. moduleName)
            warn("[Starship] First 200 chars: " .. decryptedContent:sub(1, 200))
            return false
        end

        writefile(savePath, decryptedContent)
        return true
    elseif data and data.status == "denied" then
        warn("[Starship] Access denied for module: " .. moduleName)
        return false
    elseif data and data.error then
        warn("[Starship] API error for " .. moduleName .. ": " .. tostring(data.error))
        return false
    else
        warn("[Starship] Unknown response format for " .. moduleName)
        warn("[Starship] Data: " .. tostring(data and HttpService:JSONEncode(data) or "nil"))
        return false
    end
end

local function downloadModules(statusCallback)
    local userId = tostring(game:GetService("Players").LocalPlayer.UserId)
    local totalFiles = #MODULES + #TABS
    local downloaded = 0

    -- Download main modules via secure API
    for _, moduleName in ipairs(MODULES) do
        local savePath = MODULES_FOLDER .. "/" .. moduleName
        if downloadModule(moduleName, savePath, userId) then
            downloaded = downloaded + 1
            if statusCallback then
                statusCallback("Downloading: " .. moduleName, downloaded / totalFiles)
            end
        end
    end

    -- Download tab modules via secure API
    for _, tabName in ipairs(TABS) do
        local savePath = TABS_FOLDER .. "/" .. tabName
        -- API expects "Tabs/Dashboard.lua" format
        if downloadModule("Tabs/" .. tabName, savePath, userId) then
            downloaded = downloaded + 1
            if statusCallback then
                statusCallback("Downloading: Tabs/" .. tabName, downloaded / totalFiles)
            end
        end
    end

    return downloaded == totalFiles
end

-- Legacy Firebase authentication removed
-- Now using secure API endpoint /api/load for all authentication

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

    -- Create Floating Particles (using Frames instead of broken unicode)
    task.spawn(function()
        for i = 1, 40 do
            if not LoaderGui or not LoaderGui.Parent then
                break
            end

            -- Random particle type: circle or diamond shape
            local particleType = math.random(1, 3)
            local particle = Instance.new("Frame", ParticleContainer)

            local baseSize = math.random(3, 8)
            particle.Size = UDim2.new(0, baseSize, 0, baseSize)
            particle.Position = UDim2.new(math.random(), 0, math.random(), 0)
            particle.BackgroundColor3 = Color3.fromRGB(90, 110, 245)
            particle.BackgroundTransparency = math.random() * 0.4 + 0.3
            particle.BorderSizePixel = 0

            -- Add corner radius for different shapes
            local corner = Instance.new("UICorner", particle)
            if particleType == 1 then
                -- Circle
                corner.CornerRadius = UDim.new(1, 0)
            elseif particleType == 2 then
                -- Rounded square
                corner.CornerRadius = UDim.new(0, 2)
            else
                -- Diamond (rotated square)
                corner.CornerRadius = UDim.new(0, 1)
                particle.Rotation = 45
            end

            -- Add subtle glow effect
            local glow = Instance.new("UIStroke", particle)
            glow.Color = Color3.fromRGB(90, 110, 245)
            glow.Thickness = 1
            glow.Transparency = 0.7

            -- Animate floating upward with gentle sway
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

                    -- Gentle horizontal sway
                    local sway = math.sin(os.clock() * swaySpeed + swayOffset) * 0.02
                    particle.Position = UDim2.new(startX + sway, 0, newY, 0)

                    -- Pulsing transparency
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

    -- Logo Icon (Animated "S")
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
    Logo.TextTransparency = 0 -- Visible immediately

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
    Sub.Text = "INITIALIZING..."
    Sub.Size = UDim2.new(1, 0, 0, 25)
    Sub.Position = UDim2.new(0, 0, 0.55, 0)
    Sub.BackgroundTransparency = 1
    Sub.TextColor3 = Color3.fromRGB(180, 180, 180)
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
    ProgressFill.BackgroundColor3 = Color3.fromRGB(90, 110, 245)
    Instance.new("UICorner", ProgressFill).CornerRadius = UDim.new(1, 0)

    -- Progress Percentage
    local ProgressText = Instance.new("TextLabel", MainFrame)
    ProgressText.Text = "0%"
    ProgressText.Size = UDim2.new(1, 0, 0, 20)
    ProgressText.Position = UDim2.new(0, 0, 0.63, 0)
    ProgressText.BackgroundTransparency = 1
    ProgressText.TextColor3 = Color3.fromRGB(90, 110, 245)
    ProgressText.Font = Enum.Font.GothamBold
    ProgressText.TextSize = 12
    ProgressText.TextTransparency = 0

    -- Welcome Message
    local WelcomeMsg = Instance.new("TextLabel", MainFrame)
    WelcomeMsg.Text = "Welcome back, " .. game:GetService("Players").LocalPlayer.Name .. "!"
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
            -- Obfuscate specific module names
            if string.find(text, "Downloading:") then
                text = "Downloading Asset #" .. math.random(1000, 9999)
            elseif string.find(text, "Updating modules") then
                text = "Updating Assets..."
            end

            Sub.Text = text
            TweenService:Create(ProgressFill, TweenInfo.new(0.3), { Size = UDim2.new(progress, 0, 1, 0) }):Play()
            ProgressText.Text = math.floor(progress * 100) .. "%"
        end
end

local function showError(message)
    local CoreGui = game:GetService("CoreGui")
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")

    -- Detect error type from message
    local errorType = "denied" -- default
    local titleText = "🚫 ACCESS DENIED"
    local titleColor = Color3.fromRGB(255, 80, 80)
    local frameColor = Color3.fromRGB(30, 30, 35)
    local accentColor = Color3.fromRGB(255, 80, 80)

    if message:lower():find("not whitelisted") or message:lower():find("authentication required") then
        errorType = "auth_required"
        titleText = "🔒 AUTHENTICATION REQUIRED"
        titleColor = Color3.fromRGB(255, 165, 0) -- Orange
        accentColor = Color3.fromRGB(255, 165, 0)
        message =
            "⚠️ Your account is not authorized to use Starship.\n\n💎 To get VIP access, contact the administrator.\n\n📌 Your User ID: "
            .. tostring(Players.LocalPlayer.UserId)
    elseif message:lower():find("suspended") or message:lower():find("banned") then
        errorType = "banned"
        titleText = "🚫 ACCOUNT SUSPENDED"
        titleColor = Color3.fromRGB(200, 0, 0) -- Dark Red
        accentColor = Color3.fromRGB(200, 0, 0)
        message =
            "❌ Your VIP access has been suspended.\n\n📧 Contact administrator for more information.\n\n📌 Your User ID: "
            .. tostring(Players.LocalPlayer.UserId)
    elseif message:lower():find("expired") then
        errorType = "expired"
        titleText = "⏰ VIP ACCESS EXPIRED"
        titleColor = Color3.fromRGB(255, 200, 0) -- Yellow
        accentColor = Color3.fromRGB(255, 200, 0)
        message =
            "⌛ Your VIP subscription has expired.\n\n🔄 Renew your access to continue using Starship.\n\n📌 Your User ID: "
            .. tostring(Players.LocalPlayer.UserId)
    elseif message:lower():find("connection") or message:lower():find("unreachable") then
        errorType = "connection"
        titleText = "📡 CONNECTION ERROR"
        titleColor = Color3.fromRGB(100, 100, 255) -- Blue
        accentColor = Color3.fromRGB(100, 100, 255)
        message = "🌐 Cannot connect to Starship server.\n\n🔄 Please check your internet connection and try again."
    end

    -- Create enhanced error UI
    local ErrorGui = Instance.new("ScreenGui")
    ErrorGui.Name = "StarshipError"
    ErrorGui.Parent = CoreGui
    ErrorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Background blur effect
    local BlurFrame = Instance.new("Frame", ErrorGui)
    BlurFrame.Size = UDim2.new(1, 0, 1, 0)
    BlurFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    BlurFrame.BackgroundTransparency = 0.5
    BlurFrame.BorderSizePixel = 0

    -- Main Frame
    local Frame = Instance.new("Frame", ErrorGui)
    Frame.Size = UDim2.new(0, 380, 0, 180)
    Frame.Position = UDim2.new(0.5, -190, 0.5, -90)
    Frame.BackgroundColor3 = frameColor
    Frame.BorderSizePixel = 0

    local Corner = Instance.new("UICorner", Frame)
    Corner.CornerRadius = UDim.new(0, 12)

    -- Accent bar at top
    local AccentBar = Instance.new("Frame", Frame)
    AccentBar.Size = UDim2.new(1, 0, 0, 4)
    AccentBar.BackgroundColor3 = accentColor
    AccentBar.BorderSizePixel = 0
    local AccentCorner = Instance.new("UICorner", AccentBar)
    AccentCorner.CornerRadius = UDim.new(0, 12)

    -- Shadow effect
    local Shadow = Instance.new("Frame", Frame)
    Shadow.Size = UDim2.new(1, 20, 1, 20)
    Shadow.Position = UDim2.new(0, -10, 0, -10)
    Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.BackgroundTransparency = 0.7
    Shadow.ZIndex = 0
    local ShadowCorner = Instance.new("UICorner", Shadow)
    ShadowCorner.CornerRadius = UDim.new(0, 12)

    -- Title
    local Title = Instance.new("TextLabel", Frame)
    Title.Text = titleText
    Title.Size = UDim2.new(1, -20, 0, 35)
    Title.Position = UDim2.new(0, 10, 0, 15)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = titleColor
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left

    -- Message
    local Msg = Instance.new("TextLabel", Frame)
    Msg.Text = message
    Msg.Size = UDim2.new(1, -30, 0, 100)
    Msg.Position = UDim2.new(0, 15, 0, 55)
    Msg.BackgroundTransparency = 1
    Msg.TextColor3 = Color3.fromRGB(220, 220, 220)
    Msg.Font = Enum.Font.Gotham
    Msg.TextSize = 13
    Msg.TextWrapped = true
    Msg.TextYAlignment = Enum.TextYAlignment.Top
    Msg.TextXAlignment = Enum.TextXAlignment.Left

    -- Close button
    local CloseButton = Instance.new("TextButton", Frame)
    CloseButton.Size = UDim2.new(0, 100, 0, 30)
    CloseButton.Position = UDim2.new(0.5, -50, 1, -40)
    CloseButton.BackgroundColor3 = accentColor
    CloseButton.Text = "Close"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextSize = 14
    CloseButton.BorderSizePixel = 0
    local ButtonCorner = Instance.new("UICorner", CloseButton)
    ButtonCorner.CornerRadius = UDim.new(0, 6)

    -- Entrance animation
    Frame.Position = UDim2.new(0.5, -190, -0.5, -90)
    TweenService:Create(Frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -190, 0.5, -90),
    }):Play()

    -- Close button functionality
    CloseButton.MouseButton1Click:Connect(function()
        TweenService:Create(Frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -190, 1.5, -90),
        }):Play()
        TweenService:Create(BlurFrame, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {
            BackgroundTransparency = 1,
        }):Play()
        task.wait(0.3)
        ErrorGui:Destroy()
    end)

    -- Auto-close after 10 seconds
    task.spawn(function()
        task.wait(10)
        if ErrorGui and ErrorGui.Parent then
            TweenService:Create(Frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -190, 1.5, -90),
            }):Play()
            TweenService:Create(BlurFrame, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {
                BackgroundTransparency = 1,
            }):Play()
            task.wait(0.3)
            ErrorGui:Destroy()
        end
    end)
end

local SECURE_API_URL = "https://starship-core.my.id"

local function main()
    local loaderGui, updateStatus = createLoadingUI()

    -- 1. Setup Environment
    updateStatus("Setting up environment...", 0.1)
    setupFolders()
    task.wait(0.2)

    -- 2. Download Modules (Tetap dari host lama atau bisa dipindah nanti)
    updateStatus("Updating modules...", 0.2)
    downloadModules(function(text, progress)
        updateStatus(text, 0.2 + (progress * 0.3))
    end)

    -- 3. Secure Login & Download Script
    -- 🔒 Auto-detect User ID (cannot be hardcoded by users!)
    updateStatus("Authenticating with Secure Server...", 0.6)
    task.wait(0.5)

    -- Auto-detect userId from current logged-in player
    local userId = tostring(game:GetService("Players").LocalPlayer.UserId)

    -- STEP 1: Call get-loader for authentication & webhook notification
    local authUrl = SECURE_API_URL .. "/api/get-loader?userId=" .. userId
    local authSuccess, authResponse = pcall(function()
        return game:HttpGet(authUrl)
    end)

    if not authSuccess then
        if loaderGui then
            loaderGui:Destroy()
        end
        showError("Connection Failed: Server Unreachable")
        return
    end

    -- Check if authentication was successful (should return loader.lua script or error)
    if authResponse:find("error%(") or authResponse:find("ERROR:") then
        if loaderGui then
            loaderGui:Destroy()
        end
        -- Extract error message from Lua error string
        local errorMsg = authResponse:match('error%("(.-)"%)')
        showError(errorMsg or "Authentication Failed")
        return
    end

    -- STEP 2: Now call /api/load to get the encrypted script
    local targetUrl = SECURE_API_URL .. "/api/load?user=" .. userId

    local success, response = pcall(function()
        return game:HttpGet(targetUrl)
    end)

    if not success then
        if loaderGui then
            loaderGui:Destroy()
        end
        showError("Connection Failed: Server Unreachable")
        return
    end

    -- 4. Handle Response
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

    -- 5. Decrypt Dynamic Payload
    updateStatus("Decrypting Secure Payload...", 0.8)

    local dynamicKey = data.key
    local encryptedBlob = data.blob

    if not dynamicKey or not encryptedBlob then
        if loaderGui then
            loaderGui:Destroy()
        end
        showError("Security Error: Missing Key/Blob")
        return
    end

    -- Proses Dekripsi: Base64 -> XOR (pakai key dinamis dari server)
    local encryptedString = base64Decode(encryptedBlob)
    local decryptedCode = xorEncrypt(encryptedString, dynamicKey)

    -- Hapus BOM character jika ada (U+feff) agar loadstring tidak error
    if string.byte(decryptedCode, 1, 3) == "\239\187\191" then
        decryptedCode = string.sub(decryptedCode, 4)
    end

    -- Pass Session Data to Main Script
    getgenv().StarshipSession = {
        Role = data.role or "VIP",
        Duration = data.duration or "LIFETIME",
        Expiry = data.expiry, -- Timestamp expiry (bisa nil jika LIFETIME)
    }

    -- 6. Execute with Smooth Transition
    updateStatus("Launching Starship...", 1.0)
    task.wait(0.3)

    local func, err = loadstring(decryptedCode)
    if not func then
        if loaderGui then
            loaderGui:Destroy()
        end
        showError("Execution Error: " .. tostring(err))
        return
    end

    -- Smooth Exit Animation
    if loaderGui then
        local TweenService = game:GetService("TweenService")
        local MainFrame = loaderGui:FindFirstChild("Frame")

        -- Fade out all elements smoothly
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

        -- Main frame fade to black then transparent
        if MainFrame then
            TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 1,
            }):Play()
        end

        task.wait(0.5)

        -- Signal to main script that intro is done (for smooth Main UI entrance)
        getgenv().StarshipIntroComplete = true

        loaderGui:Destroy()
    end

    func()
end

main()
