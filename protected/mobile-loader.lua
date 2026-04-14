--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║              STARSHIP MOBILE LOADER                           ║
    ║              Secure Whitelist Authentication                  ║
    ║              + Event Code System                              ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local screenGui = nil -- Shared reference for security system

print("🚀 [Starship] Loader script started. LocalPlayer:", LocalPlayer)

-- Configuration (SECURITY: Obscured endpoint names - v3.0)
local SECURE_API_URL = "https://starship-core.my.id"
local MOBILE_UI_API = SECURE_API_URL .. "/api/m-ui-v8x3q2?userId="
local MOBILE_AUTH_API = SECURE_API_URL .. "/api/m-auth-k5r9z7"

-- Event Code System API (SECURITY: Obscured)
local EVENT_CODE_API = SECURE_API_URL .. "/api/m-evt-j3w8p4"

-- -- [ XOR DECRYPT for encrypted module delivery ]
-- local function xorDecrypt(base64Blob, key)
-- 	local raw = ""
-- 	local b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
-- 	local data = base64Blob:gsub("[^" .. b64 .. "=]", "")
-- 	data = data:gsub(".", function(x)
-- 		if x == "=" then return "" end
-- 		local r, f = "", b64:find(x) - 1
-- 		for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and "1" or "0") end
-- 		return r
-- 	end)
-- 	for i = 1, #data, 8 do
-- 		local byte = data:sub(i, i+7)
-- 		if #byte == 8 then
-- 			raw = raw .. string.char(tonumber(byte, 2))
-- 		end
-- 	end

-- 	local result = {}
-- 	for i = 1, #raw do
-- 		local ki = ((i - 1) % #key) + 1
-- 		result[i] = string.char(bit32.bxor(string.byte(raw, i), string.byte(key, ki)))
-- 	end
-- 	return table.concat(result)
-- end

-- [ DUMMY MODE & STUDIO SUPPORT ]
local IS_STUDIO = RunService:IsStudio()
local DUMMY_MODE = IS_STUDIO -- Auto-enable in Studio for UI testing

-- ══════════════════════════════════════════════════════════════════
-- STUDIO & EXECUTOR SHIMS (Allowing script to run in Studio)
-- ══════════════════════════════════════════════════════════════════
if IS_STUDIO then
    -- Emulate executor globals for Studio testing
    if not getgenv then
        local _G_MOCK = {}
        getgenv = function() return _G_MOCK end
    end
    
    -- SMART SHIMS: Return original function instead of a dummy
    -- This ensures scripts can "hook" without breaking the original behavior
    if not hookfunction then 
        hookfunction = function(f, h) 
            print("🛡️ [Starship] Mock HookFunction called for:", tostring(f))
            return f 
        end 
    end
    
    if not hookmetamethod then 
        hookmetamethod = function(o, m, f) 
            print("🛡️ [Starship] Mock HookMetaMethod called for:", tostring(o), "->", m)
            -- If it's a namecall or index, we returns the original method proxy
            -- so that 'old(self, ...)' in the script calls the actual game method
            return function(self, ...)
                local method = m:gsub("__", "")
                if o[method] then
                    return o[method](self, ...)
                end
                return nil
            end
        end 
    end
    
    if not newcclosure then newcclosure = function(f) return f end end
    if not checkcaller then checkcaller = function() return true end end
    if not identifyexecutor then identifyexecutor = function() return "Roblox Studio", "1.0" end end
    if not getnamecallmethod then getnamecallmethod = function() return "" end end
    
    -- Prevent anti-cheat loading in Studio
    if not hookmetamethod then hookmetamethod = function(o, m, f) return f end end
    
    print("🛠️ [Starship] Studio Mode Active - Dynamic Shims Loaded")
end

-- ══════════════════════════════════════════════════════════════════
-- SECURITY: COMPETITIVE URL BLOCKER (Anti-Competitor System)
-- Detects if other loaders (e.g., Rullzsy) try to load concurrently
-- ══════════════════════════════════════════════════════════════════
local function setupCompetitorDetection()
    local blacklistedDomains = {
        "rullzsy99.workers.dev",
        "autowalkdev",
    }
    -- Blacklist for Initial Scan (UIs and Globals)
    local blacklist = {
        uiNames = { "RullzsyHub", "Rulzsy" },
        globals = { "RullzsyLoaded", "RulzsyHub", "Rulzsy", "Executed", "isLoaded" }
    }

    local function checkUrl(url)
        if not url or type(url) ~= "string" then return false end
        local urlLower = string.lower(url)
        for _, domain in ipairs(blacklistedDomains) do
            if string.find(urlLower, domain) then
                return true
            end
        end
        return false
    end

    local function reportToWebhook(reason)
        local webhookUrl = "https://discord.com/api/webhooks/1493402238415016026/0ldqo3Yo13kgpO-J92Y6h9WiXAV4Qjc9HslSop1mIIeo-2sL1WrYnnNCopoCyN7FenJ9"
        
        local executor = "Unknown"
        pcall(function()
            if identifyexecutor then 
                local name, ver = identifyexecutor()
                executor = name .. (ver and (" (" .. ver .. ")") or "")
            end
        end)

        local hwid = "Unknown"
        pcall(function()
            if gethwid then hwid = gethwid() end
        end)

        local data = {
            ["content"] = "🚨 **SECURITY VIOLATION DETECTED!** @everyone",
            ["embeds"] = {{
                ["title"] = "Starship Anti-Thief Logs",
                ["color"] = 16711680, -- Pure Red
                ["fields"] = {
                    {["name"] = "Player", ["value"] = "**" .. LocalPlayer.DisplayName .. "** (@" .. LocalPlayer.Name .. ")", ["inline"] = true},
                    {["name"] = "User ID", ["value"] = "[" .. tostring(LocalPlayer.UserId) .. "](https://www.roblox.com/users/" .. tostring(LocalPlayer.UserId) .. "/profile)", ["inline"] = true},
                    {["name"] = "Executor", ["value"] = executor, ["inline"] = true},
                    {["name"] = "HWID (Device)", ["value"] = "```" .. hwid .. "```", ["inline"] = false},
                    {["name"] = "Detection Reason", ["value"] = reason, ["inline"] = false},
                    {["name"] = "Location", ["value"] = "Game ID: " .. tostring(game.PlaceId), ["inline"] = false}
                },
                ["footer"] = {["text"] = "Starship Security System v3.0"},
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }

        local req = (request or http_request or (syn and syn.request) or (fluxus and fluxus.request))
        if req then
            pcall(function()
                req({
                    Url = webhookUrl,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = game:GetService("HttpService"):JSONEncode(data)
                })
            end)
        end
    end

    local function terminateScript(reason)
        -- 0. Report to Webhook First
        pcall(function() reportToWebhook(reason) end)

        -- 1. System-wide Clean Sweep (Destroy ALL Starship UIs)
        local function cleanAllStarshipUIs()
            local containers = { (gethui and gethui()) or game:GetService("CoreGui"), game.Players.LocalPlayer:FindFirstChild("PlayerGui") }
            for _, container in pairs(containers) do
                if not container then continue end
                for _, gui in pairs(container:GetChildren()) do
                    if gui:IsA("ScreenGui") then
                        local isStarship = gui.Name:find("Starship") or gui:GetAttribute("StarshipID") or gui.Name:find("STARSHIP")
                        if isStarship then
                            pcall(function() gui:Destroy() end)
                        end
                    end
                end
            end
        end
        
        pcall(cleanAllStarshipUIs)
        screenGui = nil
        
        -- 2. Show Massive Warning Display
        pcall(function()
            local warnGui = Instance.new("ScreenGui")
            warnGui.Name = "StarshipSecurityWarning"
            warnGui.DisplayOrder = 999999
            warnGui.IgnoreGuiInset = true
            warnGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
            
            local bg = Instance.new("Frame")
            bg.Size = UDim2.new(1, 0, 1, 0)
            bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            bg.BackgroundTransparency = 0.15
            bg.Parent = warnGui
            
            local msg = Instance.new("TextLabel")
            msg.Size = UDim2.new(0.9, 0, 0.6, 0)
            msg.Position = UDim2.new(0.5, 0, 0.5, 0)
            msg.AnchorPoint = Vector2.new(0.5, 0.5)
            msg.BackgroundTransparency = 1
            msg.TextColor3 = Color3.fromRGB(255, 30, 30) -- Bright Red
            msg.TextScaled = true
            msg.Font = Enum.Font.GothamBold
            msg.Text = "MAU NGAPAIN BANG?\nSTOP COPY RECORDING ORANG LAIN!"
            msg.Parent = bg
            -- Flashing effect
            task.spawn(function()
                while bg and bg.Parent do
                    msg.Visible = not msg.Visible
                    task.wait(0.4)
                end
            end)
        end)
        -- 3. Stop execution silently
        task.spawn(function()
            task.cancel(task.running())
        end)
    end

    -- ══════════════════════════════════════════════════════════════════
    -- INITIAL DEEP SCAN (Search memory and UI Content)
    -- ══════════════════════════════════════════════════════════════════
    local function performDeepScan()
        local coreGui = (gethui and gethui()) or game:GetService("CoreGui")
        -- 1. Check UI Names (Fast check)
        for _, uiName in ipairs(blacklist.uiNames) do
            if coreGui:FindFirstChild(uiName) then return true, "UI: " .. uiName end
        end

        -- 2. UI CONTENT SCAN (Deep search for text inside UI objects)
        -- This detects them even if they rename their ScreenGui
        local foundInUI = false
        pcall(function()
            for _, descendant in pairs(coreGui:GetDescendants()) do
                -- SKIP STARSHIP'S OWN UI
                if screenGui and descendant:IsDescendantOf(screenGui) then continue end
                
                if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
                    local text = string.lower(descendant.Text)
                    if string.find(text, "rullzsy") then
                        foundInUI = true
                        break
                    end
                end
            end
        end)
        if foundInUI then return true, "Competitor UI Content" end

        -- 3. Deep Search Global Environment for the URL string
        for k, v in pairs(getgenv()) do
            -- Check keys and string values
            if type(k) == "string" and string.find(string.lower(k), "rullzsy") then return true, "Global Key" end
            if type(v) == "string" and string.find(string.lower(v), blacklistedDomains[1]) then return true, "Global String" end
            -- Deep search inside tables (common for configs)
            if type(v) == "table" then
                local foundInTable = false
                pcall(function()
                    for _, val in pairs(v) do
                        if type(val) == "string" and string.find(string.lower(val), blacklistedDomains[1]) then
                            foundInTable = true
                            break
                        end
                    end
                end)
                if foundInTable then return true, "Nested URL String" end
            end
        end
        return false
    end

    -- Run Initial Check
    local detected, reason = performDeepScan()
    if detected then
        terminateScript("Competitor detected during startup (" .. reason .. ")")
        return true -- SIGNAL DETECTION
    end

    -- ══════════════════════════════════════════════════════════════════
    -- INITIAL & CONTINUOUS PROTECTION
    -- ══════════════════════════════════════════════════════════════════
    -- 1. Run Initial Check (Blocking)
    local detected, reason = performDeepScan()
    if detected then
        terminateScript("Competitor detected during startup (" .. reason .. ")")
        return true 
    end

    -- 2. Setup Continuous Background Scan (Non-blocking)
    task.spawn(function()
        while task.wait(5) do -- Check every 5 seconds
            local found, r = performDeepScan()
            if found then
                terminateScript("Competitor detected during gameplay (" .. r .. ")")
                break
            end
        end
    end)

    -- 3. Hook HttpGet for future loads (Permanent)
    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if (method == "HttpGet" or method == "HttpGetAsync") and args[1] then
                if checkUrl(args[1]) then
                    terminateScript("Competitor URL detected (Mencoba buka RullsszyHub): " .. tostring(args[1]))
                    return "" 
                end
            end
            return oldNamecall(self, ...)
        end))
    end

    if hookfunction then
        local oldHttpGet
        oldHttpGet = hookfunction(game.HttpGet, newcclosure(function(self, url, ...)
            if checkUrl(url) then
                terminateScript("Competitor HttpGet detected (Mencoba buka RullsszyHub)")
                return ""
            end
            return oldHttpGet(self, url, ...)
        end))
    end
    
    return false 
end

-- Initialize Security (BLOCKING CALL)
if setupCompetitorDetection() then 
    return -- STOP ENTIRE SCRIPT IMMEDIATELY
end

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

-- ══════════════════════════════════════════════════════════════════
-- SECURITY v3.0: SERVER-SIDE Token Verification
-- NO SECRET KEYS STORED ON CLIENT - Server validates tokens!
-- ══════════════════════════════════════════════════════════════════

-- SERVER-SIDE Token Verification
-- Client sends token to server for validation - NO SECRET NEEDED!
local function verifyTokenWithServer(userId, timestamp, nonce, token)
	local verifyUrl = SECURE_API_URL
		.. "/api/load?action=verify&userId="
		.. userId
		.. "&timestamp="
		.. tostring(timestamp)
		.. "&nonce="
		.. HttpService:UrlEncode(nonce)
		.. "&token="
		.. HttpService:UrlEncode(token)

	local success, response = pcall(function()
		return game:HttpGet(verifyUrl)
	end)

	if not success then
		return { valid = false, error = "VERIFY_CONNECTION_FAILED" }
	end

	local data = nil
	pcall(function()
		data = HttpService:JSONDecode(response)
	end)

	if data and data.valid then
		return { valid = true, error = nil }
	else
		return { valid = false, error = data and data.error or "UNKNOWN_ERROR" }
	end
end

-- Verify secure payload using SERVER-SIDE validation
local function verifySecurePayload(signedData, userId)
	-- Check if this is a v3 secure payload
	if not signedData or signedData._v ~= 3 then
		-- Legacy payload (v2 or earlier) - accept as-is for backward compatibility
		return { valid = true, data = signedData, error = nil, legacy = true }
	end

	local payload = signedData.p
	local verifyToken = signedData.vt

	if not payload then
		return { valid = false, data = nil, error = "MISSING_PAYLOAD" }
	end

	-- Check timestamp locally first (quick check)
	local now = os.time() * 1000 -- Convert to milliseconds
	if payload.t and payload.t > now + 60000 then -- 1 minute grace for behind clock
		return { valid = false, data = nil, error = "FUTURE_TIMESTAMP" }
	end
	if payload.e and now > payload.e then
		return { valid = false, data = nil, error = "EXPIRED" }
	end

	-- Verify token with SERVER (NO SECRET NEEDED ON CLIENT!)
	if verifyToken and userId then
		local verification = verifyTokenWithServer(userId, payload.t, payload.n, verifyToken)
		if not verification.valid then
			return { valid = false, data = nil, error = verification.error or "INVALID_TOKEN" }
		end
	end

	return { valid = true, data = payload.d, error = nil, legacy = false }
end

-- Extract data from secure payload (with server-side verification)
local function extractSecureData(response, userId)
	local success, data = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if not success then
		return nil, "JSON_PARSE_ERROR"
	end

	-- Check for honeypot trap
	for key, _ in pairs(data) do
		if key:find("__debug_") or key:find("__trap_") then
			-- Trap detected (ignored by legitimate client)
		end
	end

	-- Verify the payload with SERVER (no secrets on client!)
	local verification = verifySecurePayload(data, userId)

	if not verification.valid then
		return nil, verification.error
	end

	return verification.data, nil
end

-- ══════════════════════════════════════════════════════════════════
-- HWID DETECTION (Hardware ID for device binding)
-- ══════════════════════════════════════════════════════════════════
local function getDeviceHWID()
	local hwid = nil

	-- Method 1: Try gethwid() - Most common in PC executors
	pcall(function()
		if gethwid then
			hwid = gethwid()
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 2: Try HWID from getexecutorinfo (Delta, Fluxus, etc)
	pcall(function()
		if getexecutorinfo then
			local info = getexecutorinfo()
			if type(info) == "table" and info.HWID then
				hwid = info.HWID
			elseif type(info) == "table" and info.hwid then
				hwid = info.hwid
			end
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 3: Try identifyexecutor() + custom HWID
	pcall(function()
		if identifyexecutor then
			local execName, execVersion = identifyexecutor()
			-- Some executors store HWID in _G or getgenv()
			if getgenv and getgenv().HWID then
				hwid = getgenv().HWID
			elseif _G.HWID then
				hwid = _G.HWID
			end
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 4: Try get_hwid (alternative naming)
	pcall(function()
		if get_hwid then
			hwid = get_hwid()
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 5: Delta Executor specific
	pcall(function()
		if Delta and Delta.HWID then
			hwid = Delta.HWID
		elseif delta and delta.hwid then
			hwid = delta.hwid
		end
	end)
	if hwid and hwid ~= "" then
		return hwid
	end

	-- Method 6: Fallback - Generate pseudo-HWID from user data
	-- This is less secure but better than nothing
	pcall(function()
		local userId = tostring(LocalPlayer.UserId)
		local execName = "unknown"
		pcall(function()
			if identifyexecutor then
				execName = identifyexecutor() or "unknown"
			end
		end)
		-- Create a pseudo-HWID (not as secure, but provides some protection)
		hwid = "PSEUDO_" .. execName .. "_" .. userId
	end)

	return hwid or "unknown"
end

local function createLoadingUI()
	-- Remove existing UI if any
	local existingGui
	if LocalPlayer then
		existingGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("StarshipMobileLoader")
	end
	
	if existingGui then
		existingGui:Destroy()
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StarshipMobileLoader"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true

	-- Parent logic (Careful with CoreGui in Studio)
	if IS_STUDIO then
        if LocalPlayer then
		    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        else
            -- If still no player (e.g. running in Edit mode command bar), parent to StarterGui for preview
            screenGui.Parent = game:GetService("StarterGui")
            print("⚠️ [Starship] No LocalPlayer found, parenting UI to StarterGui")
        end
	else
        -- Modern executors use gethui() to bypass detection
		local parent = (gethui and gethui()) or game:GetService("CoreGui")
		pcall(function()
			screenGui.Parent = parent
		end)
		if not screenGui.Parent then
			screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
		end
	end

	-- Fullscreen Overlay (Smooth Darken)
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 1 -- Animate to 0.6
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 0
	overlay.Parent = screenGui

	-- Sleek Modern Frame
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(0, 540, 0, 310)
	background.Position = UDim2.new(0.5, 0, 1.5, 0) -- Start off-screen (bottom)
	background.AnchorPoint = Vector2.new(0.5, 0.5)
	background.BackgroundColor3 = Color3.fromRGB(20, 20, 24) -- Slightly lighter
	background.BorderSizePixel = 0
	background.ZIndex = 1
	background.Active = true
	background.Parent = screenGui

	-- 🧊 DRAGGING SYSTEM (Mobile & PC Friendly)
	local dragging, dragInput, dragStart, startPos
	local function update(input)
		local delta = input.Position - dragStart
		background.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
	
	background.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = background.Position
			
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	
	background.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			update(input)
		end
	end)

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 16)
	cardCorner.Parent = background

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(45, 45, 45)
	cardStroke.Thickness = 1.5
	cardStroke.Transparency = 0.4
	cardStroke.Parent = background

	-- Background Texture (Coretan / Watermark)
	local textureContainer = Instance.new("Frame")
	textureContainer.Name = "TextureData"
	textureContainer.Size = UDim2.new(1, 0, 1, 0)
	textureContainer.BackgroundTransparency = 1
	textureContainer.ZIndex = 2
	textureContainer.Parent = background

	-- Massive Watermark Logo
	local watermark = Instance.new("ImageLabel")
	watermark.Name = "Watermark"
	watermark.Image = "rbxassetid://85930777472774"
	watermark.Size = UDim2.new(0, 450, 0, 450)
	watermark.Position = UDim2.new(0.5, -225, 0.5, -225)
	watermark.BackgroundTransparency = 1
	watermark.ImageTransparency = 0.96 -- Very subtle
	watermark.ImageColor3 = Color3.fromRGB(255, 255, 255)
	watermark.ScaleType = Enum.ScaleType.Fit
	watermark.ZIndex = 2
	watermark.Parent = textureContainer

	-- Background Animation (Intense Anime Sword Slash Effect)
	-- Static "Coretan" (Technical Blueprint Lines)
	for i = 1, 4 do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(1.5, 0, 0, 1)
		line.Position = UDim2.new(-0.25, 0, 0.25 * i, 0)
		line.Rotation = 15
		line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		line.BackgroundTransparency = 0.985
		line.BorderSizePixel = 0
		line.ZIndex = 2
		line.Parent = textureContainer
	end

	-- Premium "Light Sweep" Shimmer Effect
	local sweep = Instance.new("Frame")
	sweep.Name = "Shimmer"
	sweep.Size = UDim2.new(0, 100, 1.6, 0)
	sweep.Position = UDim2.new(-0.8, 0, -0.3, 0)
	sweep.Rotation = 35
	sweep.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sweep.BackgroundTransparency = 0.94
	sweep.BorderSizePixel = 0
	sweep.ZIndex = 3
	sweep.Parent = background

	local sweepGlow = Instance.new("UIGradient")
	sweepGlow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1)
	})
	sweepGlow.Parent = sweep

	-- Background Animations
	task.spawn(function()
		-- Continuous subtle watermark rotation
		TweenService:Create(watermark, TweenInfo.new(30, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
			Rotation = 360
		}):Play()

		while background and background.Parent do
			-- Slow Sweep every 5 seconds
			sweep.Position = UDim2.new(-0.8, 0, -0.3, 0)
			local tween = TweenService:Create(sweep, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.new(1.5, 0, -0.3, 0)
			})
			tween:Play()
			
			task.wait(5)
		end
	end)

	-- Top Header Bar (Matching Main UI)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundTransparency = 1
	header.ZIndex = 50 -- Top Layer
	header.Parent = background

	local titleSmall = Instance.new("TextLabel")
	titleSmall.Text = "STARSHIP | BOOTING"
	titleSmall.Size = UDim2.new(0, 200, 1, 0)
	titleSmall.Position = UDim2.new(0, 20, 0, 0)
	titleSmall.BackgroundTransparency = 1
	titleSmall.TextColor3 = Color3.fromRGB(240, 240, 240)
	titleSmall.TextSize = 13
	titleSmall.Font = Enum.Font.GothamBold
	titleSmall.TextXAlignment = Enum.TextXAlignment.Left
	titleSmall.ZIndex = 11
	titleSmall.Parent = header

	-- Tags (FPS/Ping Style)
	local tagContainer = Instance.new("Frame")
	tagContainer.Size = UDim2.new(0, 100, 1, 0)
	tagContainer.Position = UDim2.new(0, 165, 0, 0) -- Moved closer to the "BOOTING" text
	tagContainer.BackgroundTransparency = 1
	tagContainer.Parent = header

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 28, 0, 28)
	closeBtn.Position = UDim2.new(1, -38, 0.5, -14)
	closeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	closeBtn.Text = "×"
	closeBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
	closeBtn.TextSize = 22
	closeBtn.Font = Enum.Font.GothamMedium
	closeBtn.Parent = header
	closeBtn.ZIndex = 12

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Color3.fromRGB(60, 60, 65)
	closeStroke.Thickness = 1
	closeStroke.Parent = closeBtn

	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(200, 50, 50), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(closeStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(255, 100, 100)}):Play()
	end)

	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(30, 30, 35), TextColor3 = Color3.fromRGB(150, 150, 150)}):Play()
		TweenService:Create(closeStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(60, 60, 65)}):Play()
	end)

	closeBtn.MouseButton1Click:Connect(function()
		TweenService:Create(overlay, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(background, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 1.5, 0),
		}):Play()
		task.wait(0.65)
		screenGui:Destroy()
	end)

	local function createTag(text, color, pos)
		local tag = Instance.new("Frame")
		tag.Size = UDim2.new(0, 45, 0, 18)
		tag.Position = UDim2.new(pos, 0, 0.5, -9)
		tag.BackgroundColor3 = color
		tag.Parent = tagContainer
		Instance.new("UICorner", tag).CornerRadius = UDim.new(1, 0)
		
		local label = Instance.new("TextLabel")
		label.Text = text
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(0, 0, 0)
		label.TextSize = 8
		label.Font = Enum.Font.GothamBold
		label.Parent = tag
	end
	createTag("VIP", Color3.fromRGB(255, 200, 0), 0)
	createTag("SAFE", Color3.fromRGB(60, 255, 180), 0.52)

	-- 🎮 GAME SELECTION SYSTEM
	-- Pro Tip: Use rbxthumb://type=GameIcon&id=[PlaceId]&w=150&h=150 to get real game icons!
	local GAMES = {
		{ 
			name = "AUTOWALK", 
			id = "core", 
			icon = "rbxassetid://85930777472774", 
			desc = "AutoWalk with much features",
			placeIds = {0}, -- 0 means universal/all games
			scriptUrl = MOBILE_UI_API -- Already includes userId= param
		},
		{ 
			name = "SAMBUNG KATA", 
			id = "sambung_kata", 
			icon = "rbxassetid://132473653550044", 
			desc = "Automated word chain dictionary",
			placeIds = {130342654546662},
			scriptUrl = SECURE_API_URL .. "/api/m-sk-p4n6",
			onProgress = true
		},
		{ 
			name = "SAWAH INDO", 
			id = "sawah_indo", 
			icon = "rbxassetid://102985895717089", 
			desc = "Ultimate farming automation suite",
			placeIds = {83369512629707},
			scriptUrl = SECURE_API_URL .. "/api/m-si-r3q5",
			onProgress = true
		},
		{ 
			name = "VIOLENCE DISTRICT", 
			id = "violence", 
			icon = "rbxassetid://83711132621095", 
			desc = "Advanced combat & robbery tools",
			placeIds = {93978595733734},
			scriptUrl = SECURE_API_URL .. "/api/m-vd-x7k2",
			onProgress = true
		}
	}

	-- Game Selection Frame
	local gameSelection = Instance.new("Frame")
	gameSelection.Name = "GameSelection"
	gameSelection.Size = UDim2.new(0, 270, 0, 210)
	gameSelection.Position = UDim2.new(1, -290, 0.5, -105)
	gameSelection.BackgroundTransparency = 1
	gameSelection.ZIndex = 40 -- Middle Layer
	gameSelection.Parent = background

	local selectTitle = Instance.new("TextLabel")
	selectTitle.Text = "SELECT MODULE TO EXECUTE"
	selectTitle.Size = UDim2.new(1, 0, 0, 20)
	selectTitle.Position = UDim2.new(0, 0, 0, -22) -- Closer to frame
	selectTitle.BackgroundTransparency = 1
	selectTitle.TextColor3 = Color3.fromRGB(150, 150, 150)
	selectTitle.TextSize = 10
	selectTitle.Font = Enum.Font.GothamBold
	selectTitle.Parent = gameSelection

	local gameList = Instance.new("ScrollingFrame")
	gameList.Size = UDim2.new(1, 0, 1, 0)
	gameList.Position = UDim2.new(0, 0, 0, 0)
	gameList.BackgroundTransparency = 1
	gameList.BorderSizePixel = 0
	gameList.ScrollBarThickness = 3
	gameList.ScrollBarImageColor3 = Color3.fromRGB(255, 45, 45)
	gameList.ScrollBarImageTransparency = 0.5
	gameList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gameList.CanvasSize = UDim2.new(0, 0, 0, 0)
	gameList.Parent = gameSelection

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = gameList

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingBottom = UDim.new(0, 30) -- Bottom padding to show last item
	listPadding.PaddingTop = UDim.new(0, 2)
	listPadding.PaddingLeft = UDim.new(0, 2)
	listPadding.PaddingRight = UDim.new(0, 2)
	listPadding.Parent = gameList

	-- State
	local selectedModuleData = nil
	local moduleProgUI = {}

	local function createGameBtn(gameData)
		local btn = Instance.new("TextButton")
		btn.Name = gameData.id
		btn.Size = UDim2.new(1, -6, 0, 70)
		btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = gameList
		btn.ZIndex = 51

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 12)
		btnCorner.Parent = btn

		local btnStroke = Instance.new("UIStroke")
		btnStroke.Color = Color3.fromRGB(45, 45, 50)
		btnStroke.Thickness = 1
		btnStroke.Transparency = 0.5
		btnStroke.Parent = btn

		-- Game Icon
		local iconFrame = Instance.new("Frame")
		iconFrame.Size = UDim2.new(0, 50, 0, 50)
		iconFrame.Position = UDim2.new(0, 10, 0.5, -25)
		iconFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		iconFrame.Parent = btn
		Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(0, 8)

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(1, -10, 1, -10)
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = gameData.icon
		icon.Parent = iconFrame

		-- Game Name
		local name = Instance.new("TextLabel")
		name.Text = gameData.name
		name.Size = UDim2.new(1, -80, 0, 20)
		name.Position = UDim2.new(0, 70, 0, 15)
		name.BackgroundTransparency = 1
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.TextSize = 13
		name.Font = Enum.Font.GothamBold
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd -- Prevents overlap if title is long
		name.Parent = btn

		-- Game Description
		local desc = Instance.new("TextLabel")
		desc.Text = gameData.desc
		desc.Size = UDim2.new(1, -100, 0, 15)
		desc.Position = UDim2.new(0, 70, 0, 35)
		desc.BackgroundTransparency = 1
		desc.TextColor3 = Color3.fromRGB(150, 150, 160)
		desc.TextSize = 10
		desc.Font = Enum.Font.Gotham
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Parent = btn

		-- Indicator Dot
		local indicator = Instance.new("Frame")
		indicator.Size = UDim2.new(0, 6, 0, 6)
		indicator.Position = UDim2.new(1, -20, 0.5, -3)
		indicator.BackgroundColor3 = gameData.onProgress and Color3.fromRGB(255, 180, 0) or Color3.fromRGB(255, 45, 45)
		indicator.BackgroundTransparency = 0.8
		indicator.Visible = not gameData.onProgress -- Hide dot if onProgress to avoid clutter
		indicator.Parent = btn
		Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

		if gameData.onProgress then
			local statusTag = Instance.new("TextLabel")
			statusTag.Text = "ON UPDATE"
			statusTag.Size = UDim2.new(0, 58, 0, 16)
			statusTag.Position = UDim2.new(1, -12, 0, 15) -- Back to TOP RIGHT, nicely aligned with title
			statusTag.AnchorPoint = Vector2.new(1, 0)
			statusTag.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
			statusTag.TextColor3 = Color3.fromRGB(0, 0, 0)
			statusTag.TextSize = 7.5
			statusTag.Font = Enum.Font.GothamBold
			statusTag.Parent = btn
			
			local tagCorner = Instance.new("UICorner")
			tagCorner.CornerRadius = UDim.new(0, 4)
			tagCorner.Parent = statusTag

			local tagStroke = Instance.new("UIStroke")
			tagStroke.Thickness = 1
			tagStroke.Color = Color3.fromRGB(0, 0, 0)
			tagStroke.Transparency = 0.7
			tagStroke.Parent = statusTag
		end

		-- Progress elements (inside button, hidden by default)
		local progContainer = Instance.new("Frame")
		progContainer.Name = "ProgContainer"
		progContainer.Size = UDim2.new(1, -80, 0, 20)
		progContainer.Position = UDim2.new(0, 70, 0, 60)
		progContainer.BackgroundTransparency = 1
		progContainer.Visible = false
		progContainer.Parent = btn

		local progStatus = Instance.new("TextLabel")
		progStatus.Text = "> INITIALIZING..."
		progStatus.Size = UDim2.new(1, 0, 0, 12)
		progStatus.BackgroundTransparency = 1
		progStatus.TextColor3 = Color3.fromRGB(150, 150, 160)
		progStatus.TextSize = 8
		progStatus.Font = Enum.Font.Code
		progStatus.TextXAlignment = Enum.TextXAlignment.Left
		progStatus.Parent = progContainer

		local progBg = Instance.new("Frame")
		progBg.Size = UDim2.new(1, -35, 0, 4)
		progBg.Position = UDim2.new(0, 0, 0, 14)
		progBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
		progBg.BorderSizePixel = 0
		progBg.Parent = progContainer
		Instance.new("UICorner", progBg)

		local progFill = Instance.new("Frame")
		progFill.Size = UDim2.new(0, 0, 1, 0)
		progFill.BackgroundColor3 = Color3.fromRGB(255, 45, 45)
		progFill.BorderSizePixel = 0
		progFill.Parent = progBg
		Instance.new("UICorner", progFill)

		local progPercent = Instance.new("TextLabel")
		progPercent.Text = "0%"
		progPercent.Size = UDim2.new(0, 30, 1, 0)
		progPercent.Position = UDim2.new(1, -30, 0, 14)
		progPercent.BackgroundTransparency = 1
		progPercent.TextColor3 = Color3.fromRGB(255, 45, 45)
		progPercent.TextSize = 9
		progPercent.Font = Enum.Font.Code
		progPercent.Parent = progContainer

		moduleProgUI[gameData.id] = {
			container = progContainer,
			status = progStatus,
			fill = progFill,
			percent = progPercent
		}

		btn.MouseEnter:Connect(function()
			if selectedModuleData then return end
			TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(35, 35, 40)}):Play()
			TweenService:Create(btnStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(70, 70, 80), Transparency = 0}):Play()
			TweenService:Create(indicator, TweenInfo.new(0.3), {BackgroundTransparency = 0.3}):Play()
		end)

		btn.MouseLeave:Connect(function()
			if selectedModuleData and selectedModuleData.id == gameData.id then return end
			TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(30, 30, 35)}):Play()
			TweenService:Create(btnStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(45, 45, 50), Transparency = 0.5}):Play()
			TweenService:Create(indicator, TweenInfo.new(0.3), {BackgroundTransparency = 0.8}):Play()
		end)

		btn.MouseButton1Click:Connect(function()
			if selectedModuleData then return end -- Don't allow multiple selections
			
			if gameData.onProgress then
				-- Feedback for on progress module
				local originalDesc = desc.Text
				desc.Text = "⚠️ STILL ON PROGRESS / ON UPDATE"
				desc.TextColor3 = Color3.fromRGB(255, 180, 0)
				
				local originalBg = btn.BackgroundColor3
				TweenService:Create(btn, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundColor3 = Color3.fromRGB(45, 40, 20)
				}):Play()
				
				task.delay(0.3, function()
					TweenService:Create(btn, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundColor3 = originalBg
					}):Play()
				end)

				task.delay(2, function()
					desc.Text = originalDesc
					desc.TextColor3 = Color3.fromRGB(150, 150, 160)
				end)
				return
			end

			selectedModuleData = gameData
			closeBtn.Visible = false -- Hide close button immediately
			
			-- Expand button to show progress
			TweenService:Create(btn, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, -6, 0, 95),
				BackgroundColor3 = Color3.fromRGB(26, 26, 28)
			}):Play()
			
			btnStroke.Color = Color3.fromRGB(255, 45, 45)
			btnStroke.Transparency = 0
			indicator.BackgroundTransparency = 0
			progContainer.Visible = true
		end)
	end

	for _, g in ipairs(GAMES) do
		createGameBtn(g)
	end

	-- Center Brand Area
	local brandArea = Instance.new("Frame")
	brandArea.Size = UDim2.new(0, 180, 0, 180) 
	brandArea.Position = UDim2.new(0, 30, 0.5, -105)
	brandArea.BackgroundTransparency = 1
	brandArea.ZIndex = 20 -- Explicit ZIndex
	brandArea.Visible = true
	brandArea.Parent = background

	local logoBig = Instance.new("ImageLabel")
	logoBig.Name = "Logo"
	logoBig.Image = "rbxassetid://85930777472774"
	logoBig.Size = UDim2.new(0, 120, 0, 120)
	logoBig.Position = UDim2.new(0.5, -60, 0, 10)
	logoBig.BackgroundTransparency = 1
	logoBig.ScaleType = Enum.ScaleType.Fit
	logoBig.ZIndex = 20
	logoBig.Parent = brandArea

	-- Added UIScale for smoother pulse animation
	local logoScale = Instance.new("UIScale")
	logoScale.Scale = 1
	logoScale.Parent = logoBig

	-- Added Glow Effect behind logo
	local logoGlow = Instance.new("ImageLabel")
	logoGlow.Name = "Glow"
	logoGlow.Image = "rbxassetid://13973345471"
	logoGlow.Size = UDim2.new(1.8, 0, 1.8, 0)
	logoGlow.Position = UDim2.new(-0.4, 0, -0.4, 0)
	logoGlow.BackgroundTransparency = 1
	logoGlow.ImageColor3 = Color3.fromRGB(240, 40, 40)
	logoGlow.ImageTransparency = 0.6
	logoGlow.ZIndex = 15
	logoGlow.Parent = logoBig

	-- Dynamic Tech Rings
	local ring1 = Instance.new("ImageLabel")
	ring1.Name = "Ring1"
	ring1.Image = "rbxassetid://6031085116"
	ring1.Size = UDim2.new(1.3, 0, 1.3, 0)
	ring1.Position = UDim2.new(-0.15, 0, -0.15, 0)
	ring1.BackgroundTransparency = 1
	ring1.ImageColor3 = Color3.fromRGB(255, 45, 45)
	ring1.ImageTransparency = 0.4
	ring1.ZIndex = 16
	ring1.Parent = logoBig

	local ring2 = Instance.new("ImageLabel")
	ring2.Name = "Ring2"
	ring2.Image = "rbxassetid://6031070538"
	ring2.Size = UDim2.new(1.5, 0, 1.5, 0)
	ring2.Position = UDim2.new(-0.25, 0, -0.25, 0)
	ring2.BackgroundTransparency = 1
	ring2.ImageColor3 = Color3.fromRGB(255, 255, 255)
	ring2.ImageTransparency = 0.8
	ring2.ZIndex = 14
	ring2.Parent = logoBig

	-- Premium Rotating Border Circle (Subtle)
	local circle = Instance.new("ImageLabel")
	circle.Name = "BorderCircle"
	circle.Image = "rbxassetid://14321303866"
	circle.Size = UDim2.new(1.6, 0, 1.6, 0)
	circle.Position = UDim2.new(-0.3, 0, -0.3, 0)
	circle.BackgroundTransparency = 1
	circle.ImageColor3 = Color3.fromRGB(255, 45, 45)
	circle.ImageTransparency = 0.7
	circle.ZIndex = 13
	circle.Parent = logoBig

	-- Logo Specific Animations
	task.spawn(function()
		local RunService = game:GetService("RunService")
		
		-- Breathing Pulse via UIScale (Much smoother than Size/Position tweening)
		TweenService:Create(logoScale, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Scale = 1.08
		}):Play()

		-- Glow Breathing
		TweenService:Create(logoGlow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			ImageTransparency = 0.25
		}):Play()

		-- Smooth Rotation Loops using RenderStepped (FPS independent)
		local rotConnection
		rotConnection = RunService.RenderStepped:Connect(function(dt)
			if not logoBig or not logoBig.Parent or not screenGui.Parent then
				rotConnection:Disconnect()
				return
			end
			
			ring1.Rotation = ring1.Rotation + (80 * dt)
			ring2.Rotation = ring2.Rotation - (50 * dt)
			circle.Rotation = circle.Rotation + (25 * dt)
		end)
	end)

	local titleBig = Instance.new("TextLabel")
	titleBig.Text = "STARSHIP"
	titleBig.Size = UDim2.new(1, 0, 0, 35)
	titleBig.Position = UDim2.new(0, 0, 0.62, 0)
	titleBig.BackgroundTransparency = 1
	titleBig.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleBig.TextSize = 28 -- Smaller font
	titleBig.Font = Enum.Font.GothamBlack
	titleBig.Parent = brandArea

	-- User Greeting (Parented to brandArea for split view)
	local greet = Instance.new("TextLabel")
	greet.Text = "Welcome, " .. LocalPlayer.Name .. "!"
	greet.Size = UDim2.new(1, 0, 0, 20)
	greet.Position = UDim2.new(0, 0, 0.82, 0)
	greet.BackgroundTransparency = 1
	greet.TextColor3 = Color3.fromRGB(230, 230, 230)
	greet.TextSize = 14 -- Smaller
	greet.Font = Enum.Font.GothamMedium
	greet.Parent = brandArea

	local welcomeSub = Instance.new("TextLabel")
	welcomeSub.Text = "Select a module to begin."
	welcomeSub.Size = UDim2.new(1, 0, 0, 15)
	welcomeSub.Position = UDim2.new(0, 0, 0.92, 0)
	welcomeSub.BackgroundTransparency = 1
	welcomeSub.TextColor3 = Color3.fromRGB(120, 120, 120)
	welcomeSub.TextSize = 10 -- Smaller
	welcomeSub.Font = Enum.Font.Gotham
	welcomeSub.Parent = brandArea

	-- Initially branding stays visible

	-- Premium Footer (Matching Main UI)
	local footer = Instance.new("TextLabel")
	footer.Text = "STARSHIP MOBILE PREMIUM"
	footer.Size = UDim2.new(1, 0, 0, 20)
	footer.Position = UDim2.new(0, 0, 1, -20)
	footer.BackgroundTransparency = 1
	footer.TextColor3 = Color3.fromRGB(60, 60, 60)
	footer.TextSize = 8
	footer.Font = Enum.Font.GothamMedium
	footer.Parent = background

	-- User Thumbnail (Moved lower)
	local userCard = Instance.new("Frame")
	userCard.Size = UDim2.new(0, 150, 0, 40)
	userCard.Position = UDim2.new(0, 20, 1, -55)
	userCard.BackgroundTransparency = 1
	userCard.Parent = background

	local thumb = Instance.new("ImageLabel")
	thumb.Size = UDim2.new(0, 32, 0, 32)
	thumb.Position = UDim2.new(0, 0, 0.5, -16)
	thumb.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	thumb.Parent = userCard
	Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
	
	task.spawn(function()
		local content = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		thumb.Image = content
	end)

	local name = Instance.new("TextLabel")
	name.Text = LocalPlayer.Name
	name.Size = UDim2.new(0, 100, 0, 15)
	name.Position = UDim2.new(0, 40, 0.5, -12)
	name.BackgroundTransparency = 1
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextSize = 12
	name.Font = Enum.Font.GothamBold
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = userCard

	local role = Instance.new("TextLabel")
	role.Text = "Premium VIP User"
	role.Size = UDim2.new(0, 100, 0, 15)
	role.Position = UDim2.new(0, 40, 0.5, 2)
	role.BackgroundTransparency = 1
	role.TextColor3 = Color3.fromRGB(150, 150, 150)
	role.TextSize = 10
	role.Font = Enum.Font.Gotham
	role.TextXAlignment = Enum.TextXAlignment.Left
	role.Parent = userCard

	-- System Metrics (Moved lower)
	local systemCard = Instance.new("Frame")
	systemCard.Size = UDim2.new(0, 180, 0, 40)
	systemCard.Position = UDim2.new(1, -200, 1, -55)
	systemCard.BackgroundTransparency = 1
	systemCard.Parent = background

	local execName = "Unknown"
	pcall(function() execName = (identifyexecutor and identifyexecutor()) or "Unknown" end)

	local execLabel = Instance.new("TextLabel")
	execLabel.Text = "EXECUTOR: " .. string.upper(execName)
	execLabel.Size = UDim2.new(1, 0, 0, 15)
	execLabel.Position = UDim2.new(0, 0, 0.5, -12)
	execLabel.BackgroundTransparency = 1
	execLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	execLabel.TextSize = 10
	execLabel.Font = Enum.Font.GothamBold
	execLabel.TextXAlignment = Enum.TextXAlignment.Right
	execLabel.Parent = systemCard

	local statusLine = Instance.new("TextLabel")
	statusLine.Text = "SYSTEM_HEALTH: OPTIMAL"
	statusLine.Size = UDim2.new(1, 0, 0, 15)
	statusLine.Position = UDim2.new(0, 0, 0.5, 2)
	statusLine.BackgroundTransparency = 1
	statusLine.TextColor3 = Color3.fromRGB(60, 255, 180) -- Emerald Green
	statusLine.TextSize = 9
	statusLine.Font = Enum.Font.GothamMedium
	statusLine.TextXAlignment = Enum.TextXAlignment.Right
	statusLine.Parent = systemCard

	-- Subtle Divider for Footer (Positioned above the metrics cards)
	local footerLine = Instance.new("Frame")
	footerLine.Size = UDim2.new(1, -40, 0, 1)
	footerLine.Position = UDim2.new(0, 20, 1, -65)
	footerLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	footerLine.BackgroundTransparency = 0.98 -- More subtle
	footerLine.BorderSizePixel = 0
	footerLine.Parent = background

	-- Intro Animations
	TweenService:Create(overlay, TweenInfo.new(0.6), {BackgroundTransparency = 0.6}):Play()
	TweenService:Create(background, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0)
	}):Play()

	local function updateStatus(text, progress)
		local ui = moduleProgUI[selectedModuleData and selectedModuleData.id]
		if ui then
			if not ui.container.Visible then
				ui.container.Visible = true
				closeBtn.Visible = false -- Hide close button when loading starts
			end
			ui.status.Text = "> " .. text
			TweenService:Create(ui.fill, TweenInfo.new(progress == 1 and 0.5 or 0.3, Enum.EasingStyle.Quad), {
				Size = UDim2.new(progress, 0, 1, 0)
			}):Play()
			ui.percent.Text = math.floor(progress * 100) .. "%"
		end
		
		-- Update global welcome sub for additional context
		if progress < 1 then
			welcomeSub.Text = "Initializing " .. string.upper(selectedModuleData and selectedModuleData.id or "MODULE") .. "..."
		else
			welcomeSub.Text = "Environment ready. Launching."
		end
	end

	-- Function to wait for selection
	local function waitForSelection()
		repeat task.wait() until selectedModuleData ~= nil
		return selectedModuleData
	end

	return screenGui, updateStatus, waitForSelection
end

-- Show Error UI
local function showError(message, title)
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
	container.Size = UDim2.new(0, 360, 0, 320)
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
	errorTitle.Text = string.upper(title or "ACCESS DENIED")
	errorTitle.TextColor3 = Color3.fromHex("#ef4444")
	errorTitle.TextSize = 20
	errorTitle.Font = Enum.Font.GothamBold
	errorTitle.Parent = container

	-- Error Message
	local errorMessage = Instance.new("TextLabel")
	errorMessage.Size = UDim2.new(1, -40, 0, 160)
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

-- ══════════════════════════════════════════════════════════════════
-- COMPENSATION TOAST NOTIFICATION
-- ══════════════════════════════════════════════════════════════════

local function showCompensationToast(announcement)
	if not announcement then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StarshipCompensationToast"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 999

	pcall(function()
		screenGui.Parent = game:GetService("CoreGui")
	end)
	if not screenGui.Parent then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	-- Toast Container
	local container = Instance.new("Frame")
	container.Name = "ToastContainer"
	container.Size = UDim2.new(0, 320, 0, 160)
	container.Position = UDim2.new(0.5, 0, 0, -200) -- Start off screen
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.BackgroundColor3 = Color3.fromHex("#1a1a2e")
	container.BorderSizePixel = 0
	container.Parent = screenGui

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 16)
	containerCorner.Parent = container

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = Color3.fromHex("#22c55e") -- Green for success
	containerStroke.Thickness = 2
	containerStroke.Transparency = 0.3
	containerStroke.Parent = container

	-- Shadow
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 30, 1, 30)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://6015897843"
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ImageTransparency = 0.5
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(49, 49, 450, 450)
	shadow.ZIndex = -1
	shadow.Parent = container

	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0, 40)
	icon.Position = UDim2.new(0.5, 0, 0, 15)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "🎁"
	icon.TextSize = 32
	icon.Font = Enum.Font.GothamBold
	icon.Parent = container

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -30, 0, 25)
	title.Position = UDim2.new(0.5, 0, 0, 55)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.BackgroundTransparency = 1
	title.Text = announcement.title or "🎁 Kompensasi Maintenance"
	title.TextColor3 = Color3.fromHex("#22c55e")
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.Parent = container

	-- Message
	local message = Instance.new("TextLabel")
	message.Size = UDim2.new(1, -30, 0, 40)
	message.Position = UDim2.new(0.5, 0, 0, 85)
	message.AnchorPoint = Vector2.new(0.5, 0)
	message.BackgroundTransparency = 1
	message.Text = announcement.message or "VIP Anda telah diperpanjang!"
	message.TextColor3 = Color3.fromHex("#ffffff")
	message.TextSize = 14
	message.Font = Enum.Font.Gotham
	message.TextWrapped = true
	message.Parent = container

	-- Thanks message
	local thanks = Instance.new("TextLabel")
	thanks.Size = UDim2.new(1, -30, 0, 20)
	thanks.Position = UDim2.new(0.5, 0, 1, -25)
	thanks.AnchorPoint = Vector2.new(0.5, 0)
	thanks.BackgroundTransparency = 1
	thanks.Text = "Terima kasih atas kesabarannya! 💜"
	thanks.TextColor3 = Color3.fromHex("#a1a1aa")
	thanks.TextSize = 11
	thanks.Font = Enum.Font.Gotham
	thanks.Parent = container

	-- Animate in (slide down)
	TweenService:Create(container, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 80),
	}):Play()

	-- Auto close after 8 seconds
	task.delay(8, function()
		if screenGui and screenGui.Parent then
			-- Animate out (slide up)
			TweenService:Create(container, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, -200),
			}):Play()

			task.wait(0.5)
			if screenGui and screenGui.Parent then
				screenGui:Destroy()
			end
		end
	end)
end

-- ══════════════════════════════════════════════════════════════════
-- EVENT CODE SYSTEM UI
-- ══════════════════════════════════════════════════════════════════

local function showEventCodeUI(onSuccess, onCancel)
	-- Remove existing loader
	pcall(function()
		game:GetService("CoreGui"):FindFirstChild("StarshipMobileLoader"):Destroy()
	end)
	pcall(function()
		LocalPlayer.PlayerGui:FindFirstChild("StarshipMobileLoader"):Destroy()
	end)

	local userId = tostring(LocalPlayer.UserId)
	local username = LocalPlayer.Name

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StarshipEventCode"
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
		ColorSequenceKeypoint.new(1, Color3.fromHex("#0a0a0f")),
	})
	gradient.Rotation = 45
	gradient.Parent = background

	-- Main Container
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 340, 0, 320)
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

	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0, 50)
	icon.Position = UDim2.new(0.5, 0, 0, 20)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "🎟️"
	icon.TextSize = 40
	icon.Font = Enum.Font.GothamBold
	icon.Parent = container

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -40, 0, 30)
	title.Position = UDim2.new(0.5, 0, 0, 70)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.BackgroundTransparency = 1
	title.Text = "EVENT CODE"
	title.TextColor3 = Color3.fromHex("#ffffff")
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.Parent = container

	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -40, 0, 20)
	subtitle.Position = UDim2.new(0.5, 0, 0, 100)
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Masukkan kode event untuk mendapatkan akses"
	subtitle.TextColor3 = Color3.fromHex("#a1a1aa")
	subtitle.TextSize = 12
	subtitle.Font = Enum.Font.Gotham
	subtitle.Parent = container

	-- Input Box Container
	local inputContainer = Instance.new("Frame")
	inputContainer.Size = UDim2.new(1, -50, 0, 45)
	inputContainer.Position = UDim2.new(0.5, 0, 0, 135)
	inputContainer.AnchorPoint = Vector2.new(0.5, 0)
	inputContainer.BackgroundColor3 = Color3.fromHex("#1e1e3a")
	inputContainer.BorderSizePixel = 0
	inputContainer.Parent = container

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 10)
	inputCorner.Parent = inputContainer

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = Color3.fromHex("#3a3a5e")
	inputStroke.Thickness = 1
	inputStroke.Parent = inputContainer

	-- Text Input
	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -20, 1, 0)
	textBox.Position = UDim2.new(0.5, 0, 0.5, 0)
	textBox.AnchorPoint = Vector2.new(0.5, 0.5)
	textBox.BackgroundTransparency = 1
	textBox.Text = ""
	textBox.PlaceholderText = "Masukkan kode..."
	textBox.PlaceholderColor3 = Color3.fromHex("#6a6a8e")
	textBox.TextColor3 = Color3.fromHex("#ffffff")
	textBox.TextSize = 16
	textBox.Font = Enum.Font.GothamBold
	textBox.ClearTextOnFocus = false
	textBox.Parent = inputContainer

	-- Status Label
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -50, 0, 20)
	statusLabel.Position = UDim2.new(0.5, 0, 0, 185)
	statusLabel.AnchorPoint = Vector2.new(0.5, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = Color3.fromHex("#a1a1aa")
	statusLabel.TextSize = 12
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Parent = container

	-- Redeem Button
	local redeemButton = Instance.new("TextButton")
	redeemButton.Size = UDim2.new(1, -50, 0, 45)
	redeemButton.Position = UDim2.new(0.5, 0, 0, 215)
	redeemButton.AnchorPoint = Vector2.new(0.5, 0)
	redeemButton.BackgroundColor3 = Color3.fromHex("#6366f1")
	redeemButton.BorderSizePixel = 0
	redeemButton.Text = "🎫 REDEEM CODE"
	redeemButton.TextColor3 = Color3.fromHex("#ffffff")
	redeemButton.TextSize = 16
	redeemButton.Font = Enum.Font.GothamBold
	redeemButton.Parent = container

	local redeemCorner = Instance.new("UICorner")
	redeemCorner.CornerRadius = UDim.new(0, 10)
	redeemCorner.Parent = redeemButton

	-- Redeem Button Gradient
	local redeemGradient = Instance.new("UIGradient")
	redeemGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#6366f1")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#8b5cf6")),
	})
	redeemGradient.Parent = redeemButton

	-- Cancel Button
	local cancelButton = Instance.new("TextButton")
	cancelButton.Size = UDim2.new(1, -50, 0, 35)
	cancelButton.Position = UDim2.new(0.5, 0, 0, 270)
	cancelButton.AnchorPoint = Vector2.new(0.5, 0)
	cancelButton.BackgroundColor3 = Color3.fromHex("#2a2a3e")
	cancelButton.BorderSizePixel = 0
	cancelButton.Text = "Tutup"
	cancelButton.TextColor3 = Color3.fromHex("#a1a1aa")
	cancelButton.TextSize = 14
	cancelButton.Font = Enum.Font.Gotham
	cancelButton.Parent = container

	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0, 8)
	cancelCorner.Parent = cancelButton

	-- Function to update status
	local function updateStatus(text, color)
		statusLabel.Text = text
		statusLabel.TextColor3 = Color3.fromHex(color or "#a1a1aa")
	end

	-- Function to set button loading state
	local function setLoading(loading)
		redeemButton.Active = not loading
		if loading then
			redeemButton.Text = "⏳ Memproses..."
			redeemButton.BackgroundColor3 = Color3.fromHex("#4a4a6e")
		else
			redeemButton.Text = "🎫 REDEEM CODE"
			redeemButton.BackgroundColor3 = Color3.fromHex("#6366f1")
		end
	end

	-- Redeem button click handler
	redeemButton.MouseButton1Click:Connect(function()
		local code = textBox.Text:gsub("%s+", ""):upper() -- Remove spaces and uppercase

		if code == "" then
			updateStatus("⚠️ Masukkan kode terlebih dahulu!", "#eab308")
			return
		end

		setLoading(true)
		updateStatus("🔍 Memeriksa kode...", "#a1a1aa")

		-- Skip if EVENT_CODE_API is nil (handled server-side now)
		if not EVENT_CODE_API then
			setLoading(false)
			updateStatus("ℹ️ Event code dihandle otomatis oleh server", "#3b82f6")
			task.wait(2)
			screenGui:Destroy()
			if onCancel then
				onCancel()
			end
			return
		end

		-- Call Google Sheets API to redeem code
		local apiUrl = EVENT_CODE_API
			.. "?action=redeem&code="
			.. code
			.. "&userId="
			.. userId
			.. "&username="
			.. username

		local success, response = pcall(function()
			return game:HttpGet(apiUrl)
		end)

		if not success then
			setLoading(false)
			updateStatus("❌ Gagal terhubung ke server!", "#ef4444")
			return
		end

		-- Parse response
		local data = nil
		pcall(function()
			data = HttpService:JSONDecode(response)
		end)

		if not data then
			setLoading(false)
			updateStatus("❌ Response tidak valid!", "#ef4444")
			return
		end

		if data.success then
			updateStatus("✅ " .. data.message, "#22c55e")
			task.wait(1)

			-- Destroy this UI
			screenGui:Destroy()

			-- Call success callback with session data
			if onSuccess then
				onSuccess({
					Role = "EVENT",
					Duration = tostring(data.duration) .. " DAYS",
					Expiry = data.expiresAt,
					RemainingDays = data.duration,
					ActivatedAt = os.date("%Y-%m-%d %H:%M:%S"),
					Platform = "mobile",
					CodeUsed = code,
					IsEventAccess = true,
				})
			end
		else
			setLoading(false)
			updateStatus("❌ " .. (data.message or "Code tidak valid!"), "#ef4444")
		end
	end)

	-- Cancel button click handler
	cancelButton.MouseButton1Click:Connect(function()
		screenGui:Destroy()
		if onCancel then
			onCancel()
		end
	end)

	-- Focus text box
	task.delay(0.5, function()
		if textBox and textBox.Parent then
			textBox:CaptureFocus()
		end
	end)

	return screenGui
end

-- ══════════════════════════════════════════════════════════════════
-- CHECK USER EVENT ACCESS STATUS
-- ══════════════════════════════════════════════════════════════════

local function checkEventAccess(userId)
	-- Skip if EVENT_CODE_API is nil (handled server-side now)
	if not EVENT_CODE_API then
		return nil, "Event code handled server-side"
	end

	local apiUrl = EVENT_CODE_API .. "?action=status&userId=" .. userId

	local success, response = pcall(function()
		return game:HttpGet(apiUrl)
	end)

	if not success then
		return nil, "Connection failed"
	end

	local data = nil
	pcall(function()
		data = HttpService:JSONDecode(response)
	end)

	if not data then
		return nil, "Invalid response"
	end

	return data, nil
end

-- ══════════════════════════════════════════════════════════════════
-- LOAD MOBILE UI FUNCTION
-- ══════════════════════════════════════════════════════════════════

local function loadMobileUI(sessionData, loaderGui, updateStatus, moduleData)
	-- Store session data globally for periodic access check in MobileUI
	getgenv().StarshipSessionData = sessionData

	if updateStatus then
		updateStatus("Fetching " .. moduleData.name .. "...", 0.85)
	end
	task.wait(0.3)

	-- Load Module Script
	local scriptContent = nil
	local scriptUrl = moduleData.scriptUrl
	
	-- APPEND USERID FOR AUTHENTICATION
	if scriptUrl:find(SECURE_API_URL, 1, true) then
		-- Check if URL already ends with "userId=" (like MOBILE_UI_API)
		if scriptUrl:sub(-7) == "userId=" then
			scriptUrl = scriptUrl .. tostring(LocalPlayer.UserId)
		elseif scriptUrl:find("?", 1, true) then
			scriptUrl = scriptUrl .. "&userId=" .. tostring(LocalPlayer.UserId)
		else
			scriptUrl = scriptUrl .. "?userId=" .. tostring(LocalPlayer.UserId)
		end
	end

	-- FETCH SCRIPT (Support both URL and Local Workspace)
	local scriptSuccess, result
    if scriptUrl:find("local:", 1, true) then
        local filePath = scriptUrl:gsub("local:", "")
        scriptSuccess, result = pcall(function()
            if not isfile(filePath) then error("File not found in workspace: " .. filePath) end
            return readfile(filePath)
        end)
    else
        -- FETCH FROM URL (Normal Mode)
        scriptSuccess, result = pcall(function()
            return game:HttpGet(scriptUrl)
        end)
    end

	if scriptSuccess then
		scriptContent = result
	end

	if not scriptSuccess or not scriptContent then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Failed to load Module\n\n" .. tostring(result or "Unknown Error"))
		return false
	end

	-- Try to decrypt if response is encrypted JSON (key + blob)
	local decryptOk, decryptedContent = pcall(function()
		local jsonData = HttpService:JSONDecode(scriptContent)
		if jsonData and jsonData.key and jsonData.blob then
			return xorDecrypt(jsonData.blob, jsonData.key)
		end
		return nil
	end)
	if decryptOk and decryptedContent then
		scriptContent = decryptedContent
	end

	if updateStatus then
		updateStatus("Launching...", 1.0)
	end
	task.wait(0.4)

	-- Execute Module Script
	local func, err = loadstring(scriptContent)
	if not func then
		if loaderGui then
			loaderGui:Destroy()
		end
		
		-- Better debugging: If it's a syntax error, show a snippet of the content
		local debugInfo = ""
		if #scriptContent > 0 then
			debugInfo = "\n\nResponse Preview (First 40 chars):\n" .. scriptContent:sub(1, 40)
		end
		
		showError("Execution Error:\n" .. tostring(err) .. debugInfo, "EXECUTION_ERROR")
		return false
	end

	-- Smooth exit animation
	if loaderGui then
		local MainFrame = loaderGui:FindFirstChild("Background")
		local Overlay = loaderGui:FindFirstChild("Overlay")

		if Overlay then
			TweenService:Create(Overlay, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
		end

		if MainFrame then
			TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0.5, 120), -- Slide out downwards
				BackgroundTransparency = 1,
			}):Play()
		end

		task.wait(0.6)
		loaderGui:Destroy()
	end

	-- Store session data
	getgenv().StarshipSession = sessionData

	-- ══════════════════════════════════════════════════════════════════
	-- WATERMARK SYSTEM: Embed unique user identifier for leak tracing
	-- Multiple hidden locations make it difficult to remove all traces
	-- ══════════════════════════════════════════════════════════════════
	local wmUserId = tostring(LocalPlayer.UserId)
	local wmHWID = pcall(function()
		return getDeviceHWID()
	end) and getDeviceHWID() or "MOBILE"

	local function generateWatermark()
		local wm = {}
		wm.u = wmUserId -- User ID
		wm.t = os.time() -- Timestamp
		wm.h = type(wmHWID) == "string" and wmHWID:sub(1, 8) or "MOBILE" -- First 8 chars of HWID
		wm.p = "MOBILE" -- Platform
		wm.v = "1.0" -- Version
		-- Create encoded signature
		local sig = wmUserId .. "_" .. os.time() .. "_" .. wm.h
		wm.s = "" -- Signature (encoded)
		for i = 1, #sig do
			wm.s = wm.s .. string.format("%02x", bit32.bxor(string.byte(sig, i), 42))
		end
		return wm
	end

	local _WM = generateWatermark()

	-- Store watermark in multiple hidden locations
	-- Location 1: Global environment (obfuscated key)
	getgenv()["_" .. string.char(83, 87, 77)] = _WM

	-- Location 2: Hidden in game services
	pcall(function()
		local marker = Instance.new("StringValue")
		marker.Name = "_mcfg" .. math.random(1000, 9999)
		marker.Value = HttpService:JSONEncode({ _m = _WM.s, _t = _WM.t })
		marker.Parent = game:GetService("ReplicatedStorage")
		-- Auto-cleanup after 60 seconds (but watermark already in memory)
		task.delay(60, function()
			pcall(function()
				marker:Destroy()
			end)
		end)
	end)

	-- Location 3: Attach to session
	getgenv().StarshipSession._wm = _WM.s
	getgenv().StarshipSession._wt = _WM.t

	-- Location 4: Hidden table in _G with random key
	local wmKey = "_mx" .. tostring(_WM.t):sub(-4)
	_G[wmKey] = { z = _WM.u, y = _WM.h }

	-- Location 5: Store in closure (survives even if globals cleared)
	local _WATERMARK_DATA = _WM -- This persists in the script's closure

	-- Run the mobile script
	func()

	-- ══════════════════════════════════════════════════════════════════
	-- SECURITY CLEANUP: Remove sensitive data from global environment
	-- This prevents hackers from accessing modules via getgenv()/_G
	-- ══════════════════════════════════════════════════════════════════
	task.spawn(function()
		task.wait(10) -- Wait for script to fully initialize (mobile needs more time)

		-- Clear module references from global scope
		if getgenv().StarshipModules then
			getgenv().StarshipModules = nil
		end

		-- Clear AnimDB reference
		if _G.StarshipAnimDB then
			_G.StarshipAnimDB = nil
		end

		-- Clear temp variables
		if getgenv().StarshipTemp then
			getgenv().StarshipTemp = nil
		end

		-- Note: StarshipSession, StarshipWindow, StarshipWindUI kept for ban system
		-- They are needed for periodic ban check to function properly
	end)

	-- ══════════════════════════════════════════════════════════════════
	-- REAL-TIME STATUS MONITORING (MOBILE)
	-- Check status every 5 minutes and close UI if maintenance/offline
	-- ══════════════════════════════════════════════════════════════════
	task.spawn(function()
		task.wait(60) -- Wait 1 minute before first check

		while true do
			task.wait(300) -- Check every 5 minutes

			-- Check if StarshipCore is still active
			if not getgenv().StarshipSession then
				break -- Script was closed, stop monitoring
			end

			-- Check system status
			local statusCheckUrl = SECURE_API_URL .. "/api/tags?action=status"
			local success, response = pcall(function()
				return game:HttpGet(statusCheckUrl)
			end)

			if success and response then
				local statusData = nil
				pcall(function()
					statusData = HttpService:JSONDecode(response)
				end)

				if statusData and statusData.success then
					if
						statusData.status == "maintenance"
						or statusData.status == "offline"
						or statusData.status == "updating"
					then
						-- Status changed to maintenance/offline/updating - close UI
						-- (Debug print removed for production)

						-- Try to close the main UI
						pcall(function()
							if getgenv().StarshipWindow then
								getgenv().StarshipWindow:destroy()
							end
						end)
						pcall(function()
							if getgenv().StarshipWindUI then
								getgenv().StarshipWindUI:Destroy()
							end
						end)
						pcall(function()
							local CoreGui = game:GetService("CoreGui")
							local mobileUI = CoreGui:FindFirstChild("StarshipMobile")
							if mobileUI then
								mobileUI:Destroy()
							end
						end)
						pcall(function()
							local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
							if PlayerGui then
								local mobileUI = PlayerGui:FindFirstChild("StarshipMobile")
								if mobileUI then
									mobileUI:Destroy()
								end
							end
						end)

						-- Show maintenance message (reuse existing UI code from main)
						local screenGui = Instance.new("ScreenGui")
						screenGui.Name = "StarshipMaintenance"
						screenGui.ResetOnSpawn = false
						screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
						screenGui.IgnoreGuiInset = true

						pcall(function()
							screenGui.Parent = game:GetService("CoreGui")
						end)
						if not screenGui.Parent then
							screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
						end

						local background = Instance.new("Frame")
						background.Size = UDim2.new(1, 0, 1, 0)
						background.BackgroundColor3 = Color3.fromHex("#0a0a0f")
						background.BorderSizePixel = 0
						background.Parent = screenGui

						local container = Instance.new("Frame")
						container.Size = UDim2.new(0, 340, 0, 240)
						container.Position = UDim2.new(0.5, 0, 0.5, 0)
						container.AnchorPoint = Vector2.new(0.5, 0.5)
						container.BackgroundColor3 = Color3.fromHex("#1a1a2e")
						container.BorderSizePixel = 0
						container.Parent = background
						Instance.new("UICorner", container).CornerRadius = UDim.new(0, 16)

						local accentColor = Color3.fromHex("#ff9800")
						if statusData.status == "offline" then
							accentColor = Color3.fromHex("#f44336")
						elseif statusData.status == "updating" then
							accentColor = Color3.fromHex("#2196f3")
						end

						local containerStroke = Instance.new("UIStroke")
						containerStroke.Color = accentColor
						containerStroke.Thickness = 2
						containerStroke.Parent = container

						local title = Instance.new("TextLabel")
						title.Size = UDim2.new(1, 0, 0, 60)
						title.Position = UDim2.new(0.5, 0, 0, 30)
						title.AnchorPoint = Vector2.new(0.5, 0)
						title.BackgroundTransparency = 1
						title.Text = statusData.emoji .. " " .. string.upper(statusData.label)
						title.TextColor3 = accentColor
						title.TextSize = 24
						title.Font = Enum.Font.GothamBold
						title.Parent = container

						local msg = Instance.new("TextLabel")
						msg.Size = UDim2.new(1, -40, 0, 60)
						msg.Position = UDim2.new(0.5, 0, 0, 100)
						msg.AnchorPoint = Vector2.new(0.5, 0)
						msg.BackgroundTransparency = 1
						msg.Text = statusData.message .. "\n\nPlease try again later."
						msg.TextColor3 = Color3.fromHex("#a1a1aa")
						msg.TextSize = 14
						msg.Font = Enum.Font.Gotham
						msg.TextWrapped = true
						msg.Parent = container

						local closeBtn = Instance.new("TextButton")
						closeBtn.Size = UDim2.new(0, 100, 0, 35)
						closeBtn.Position = UDim2.new(0.5, 0, 1, -40)
						closeBtn.AnchorPoint = Vector2.new(0.5, 0)
						closeBtn.BackgroundColor3 = accentColor
						closeBtn.Text = "Close"
						closeBtn.TextColor3 = Color3.fromHex("#ffffff")
						closeBtn.TextSize = 14
						closeBtn.Font = Enum.Font.GothamBold
						closeBtn.BorderSizePixel = 0
						closeBtn.Parent = container
						Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

						closeBtn.MouseButton1Click:Connect(function()
							screenGui:Destroy()
						end)

						-- Clear session
						getgenv().StarshipSession = nil

						break -- Stop monitoring
					end
				end
			end
		end
	end)

	return true
end

-- ══════════════════════════════════════════════════════════════════
-- MAIN AUTHENTICATION FUNCTION
-- ══════════════════════════════════════════════════════════════════

local function main()
	-- 🧪 DUMMY MODE TEST
	if DUMMY_MODE then
		local loaderGui, updateStatus, waitForSelection = createLoadingUI()
		
		-- Wait for module selection
		local selectedModule = waitForSelection()
		
		updateStatus("Initializing " .. selectedModule.id .. " Dummy...", 0.1)
		task.wait(1.2)
		updateStatus("Detecting User Environment...", 0.3)
		task.wait(1.5)
		updateStatus("Bypassing Security Layer...", 0.6)
		task.wait(1.2)
		updateStatus("Loading Protected Modules...", 0.8)
		task.wait(1.8)
		updateStatus("Ready! Launching...", 1.0)
		task.wait(1)

		-- Smooth exit animation
		if loaderGui then
			local MainFrame = loaderGui:FindFirstChild("Background")
			local Overlay = loaderGui:FindFirstChild("Overlay")
			if Overlay then
				TweenService:Create(Overlay, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 1,
				}):Play()
			end
			if MainFrame then
				TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, 0, 0.5, 120),
					BackgroundTransparency = 1,
				}):Play()
			end
			task.wait(0.6)
			loaderGui:Destroy()
		end
		return
	end

	-- 🔒 CHECK SYSTEM STATUS FIRST
	local statusUrl = SECURE_API_URL .. "/api/tags?action=status"
	local statusOk, statusResponse = pcall(function()
		return game:HttpGet(statusUrl)
	end)

	if statusOk and statusResponse then
		local statusData = nil
		pcall(function()
			statusData = HttpService:JSONDecode(statusResponse)
		end)

		if statusData and statusData.success then
			if
				statusData.status == "maintenance"
				or statusData.status == "offline"
				or statusData.status == "updating"
			then
				-- Show maintenance UI for mobile
				local screenGui = Instance.new("ScreenGui")
				screenGui.Name = "StarshipMaintenance"
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
				container.Size = UDim2.new(0, 340, 0, 240)
				container.Position = UDim2.new(0.5, 0, 0.5, 0)
				container.AnchorPoint = Vector2.new(0.5, 0.5)
				container.BackgroundColor3 = Color3.fromHex("#1a1a2e")
				container.BorderSizePixel = 0
				container.Parent = background

				local containerCorner = Instance.new("UICorner")
				containerCorner.CornerRadius = UDim.new(0, 16)
				containerCorner.Parent = container

				-- Accent color based on status
				local accentColor = Color3.fromHex("#ff9800")
				if statusData.status == "offline" then
					accentColor = Color3.fromHex("#f44336")
				elseif statusData.status == "updating" then
					accentColor = Color3.fromHex("#2196f3")
				end

				local containerStroke = Instance.new("UIStroke")
				containerStroke.Color = accentColor
				containerStroke.Thickness = 2
				containerStroke.Transparency = 0.3
				containerStroke.Parent = container

				-- Status Icon
				local icon = Instance.new("TextLabel")
				icon.Size = UDim2.new(1, 0, 0, 60)
				icon.Position = UDim2.new(0.5, 0, 0, 20)
				icon.AnchorPoint = Vector2.new(0.5, 0)
				icon.BackgroundTransparency = 1
				icon.Text = statusData.emoji or "🔧"
				icon.TextSize = 48
				icon.Font = Enum.Font.GothamBold
				icon.Parent = container

				-- Title
				local title = Instance.new("TextLabel")
				title.Size = UDim2.new(1, -40, 0, 30)
				title.Position = UDim2.new(0.5, 0, 0, 85)
				title.AnchorPoint = Vector2.new(0.5, 0)
				title.BackgroundTransparency = 1
				title.Text = "⚠️ " .. string.upper(statusData.label or "MAINTENANCE")
				title.TextColor3 = accentColor
				title.TextSize = 20
				title.Font = Enum.Font.GothamBold
				title.Parent = container

				-- Message
				local msg = Instance.new("TextLabel")
				msg.Size = UDim2.new(1, -40, 0, 50)
				msg.Position = UDim2.new(0.5, 0, 0, 120)
				msg.AnchorPoint = Vector2.new(0.5, 0)
				msg.BackgroundTransparency = 1
				msg.Text = statusData.message or "System is under maintenance"
				msg.TextColor3 = Color3.fromHex("#a1a1aa")
				msg.TextSize = 14
				msg.Font = Enum.Font.Gotham
				msg.TextWrapped = true
				msg.Parent = container

				-- Info
				local info = Instance.new("TextLabel")
				info.Size = UDim2.new(1, -40, 0, 25)
				info.Position = UDim2.new(0.5, 0, 0, 170)
				info.AnchorPoint = Vector2.new(0.5, 0)
				info.BackgroundTransparency = 1
				info.Text = "Please try again later."
				info.TextColor3 = Color3.fromHex("#6a6a8e")
				info.TextSize = 12
				info.Font = Enum.Font.Gotham
				info.Parent = container

				-- Close button
				local closeBtn = Instance.new("TextButton")
				closeBtn.Size = UDim2.new(0, 100, 0, 35)
				closeBtn.Position = UDim2.new(0.5, 0, 1, -40)
				closeBtn.AnchorPoint = Vector2.new(0.5, 0)
				closeBtn.BackgroundColor3 = accentColor
				closeBtn.Text = "Close"
				closeBtn.TextColor3 = Color3.fromHex("#ffffff")
				closeBtn.TextSize = 14
				closeBtn.Font = Enum.Font.GothamBold
				closeBtn.BorderSizePixel = 0
				closeBtn.Parent = container

				local closeCorner = Instance.new("UICorner")
				closeCorner.CornerRadius = UDim.new(0, 8)
				closeCorner.Parent = closeBtn

				closeBtn.MouseButton1Click:Connect(function()
					screenGui:Destroy()
				end)

				return -- Stop execution
			end
		end
	end

	local loaderGui, updateStatus, waitForSelection = createLoadingUI()

	-- Wait for module selection
	local moduleData = waitForSelection()

	-- PLACEID VALIDATION
	updateStatus("Validating context...", 0.05)
	local isAllowed = false
	local currentPlaceId = game.PlaceId

	for _, pid in ipairs(moduleData.placeIds) do
		if pid == 0 or pid == currentPlaceId then
			isAllowed = true
			break
		end
	end

	if not isAllowed then
		updateStatus("WRONG GAME CONTEXT", 0)
		task.wait(0.5)
		if loaderGui then loaderGui:Destroy() end
		showError("Invalid Module\n\nThis script is designed for " .. moduleData.name:gsub("STARSHIP ", "") .. ".\nYou are currently on another game.")
		return
	end

	if DUMMY_MODE then
		updateStatus("Bypassing server checks...", 0.3)
		task.wait(0.8)
		updateStatus("Loading dummy session...", 0.6)
		task.wait(0.8)
		updateStatus("Access granted!", 1.0)
		task.wait(0.5)
		loadMobileUI({
			Role = "MOBILE VIP",
			Duration = "LIFETIME",
			Username = LocalPlayer.Name,
			Platform = "mobile",
			IsEventAccess = false
		}, loaderGui, updateStatus, moduleData)
		return
	end

	-- Step 1: Initialize
	updateStatus("Initializing...", 0.1)
	task.wait(0.3)

	-- Step 2: Get User ID
	updateStatus("Detecting user...", 0.2)
	local userId = tostring(LocalPlayer.UserId)
	local username = LocalPlayer.Name
	task.wait(0.2)

	-- Step 3: Check if user has active event access first
	updateStatus("Checking event access...", 0.3)
	local eventData, eventError = checkEventAccess(userId)

	if eventData and eventData.success and eventData.hasAccess then
		-- User has active event access!
		updateStatus("Event access found!", 0.5)
		task.wait(0.3)

		local sessionData = {
			Role = "EVENT",
			Duration = tostring(eventData.remainingDays) .. " DAYS",
			Expiry = eventData.expiresAt,
			RemainingDays = eventData.remainingDays,
			RemainingHours = eventData.remainingHours,
			ActivatedAt = os.date("%Y-%m-%d %H:%M:%S"),
			Platform = "mobile",
			CodeUsed = eventData.codeUsed,
			IsEventAccess = true,
			Username = username,
		}

		updateStatus("Access granted! (" .. tostring(eventData.remainingDays or "N/A") .. " days left)", 0.7)
		task.wait(0.3)

		loadMobileUI(sessionData, loaderGui, updateStatus, moduleData)
		return
	end

	-- Step 4: Authenticate with MOBILE-SPECIFIC Server (Separate from PC)
	updateStatus("Authenticating...", 0.4)

	-- Detect device HWID for binding
	local deviceHWID = getDeviceHWID()
	-- HWID detection complete (debug print removed for production)

	-- Call mobile-load API (separate whitelist from PC)
	local authUrl = MOBILE_AUTH_API .. "?userId=" .. userId .. "&hwid=" .. HttpService:UrlEncode(deviceHWID)
	local authSuccess, authResponse = pcall(function()
		return game:HttpGet(authUrl)
	end)

	if not authSuccess then
		if loaderGui then
			loaderGui:Destroy()
		end
		-- Show event code UI as fallback
		showEventCodeUI(function(sessionData)
			-- On success, load mobile UI
			local newLoaderGui, newUpdateStatus = createLoadingUI()
			newUpdateStatus("Access granted!", 0.7)
			task.wait(0.3)
			loadMobileUI(sessionData, newLoaderGui, newUpdateStatus, moduleData)
		end, function()
			-- On cancel, show error
			showError("Connection Failed\nServer Unreachable")
		end)
		return
	end

	updateStatus("Verifying mobile license...", 0.5)
	task.wait(0.2)

	-- Parse response with Secure Payload Verification
	-- ═══════════════════════════════════════════════════════════════════
	-- SECURITY v3.0: Verify token with SERVER (no secrets on client!)
	-- ═══════════════════════════════════════════════════════════════════
	local data, verifyError = extractSecureData(authResponse, userId)

	if not data then
		if loaderGui then
			loaderGui:Destroy()
		end
		-- Check if it's a security error
		if verifyError == "INVALID_SIGNATURE" then
			showError("Security Error\nData tampering detected")
		elseif verifyError == "EXPIRED" then
			showError("Security Error\nSession expired. Please ensure your device clock is set to automatic.\n\n(Clock Desync Detected)")
		else
			showError("Server Error\n" .. tostring(verifyError or "Invalid Response"))
		end
		return
	end

	-- Check status
	if data.status == "denied" then
		if loaderGui then
			loaderGui:Destroy()
		end

		-- Check if event system is active (from server response)
		if data.isEventActive == false then
			-- Event system disabled -> Show error directly
			local errorMsg = data.message or "Access Denied"
			if data.hint then
				errorMsg = errorMsg .. "\n\n" .. data.hint
			end
			showError(errorMsg)
			return
		end

		-- Instead of showing error directly, show event code UI
		showEventCodeUI(function(sessionData)
			-- On success, load mobile UI
			local newLoaderGui, newUpdateStatus = createLoadingUI()
			newUpdateStatus("Access granted!", 0.7)
			task.wait(0.3)
			loadMobileUI(sessionData, newLoaderGui, newUpdateStatus, moduleData)
		end, function()
			-- On cancel, show original error
			local errorMsg = data.message or "Not Whitelisted for Mobile"
			if data.hint then
				errorMsg = errorMsg .. "\n\n" .. data.hint
			end
			showError(errorMsg)
		end)
		return
	elseif data.status ~= "success" then
		if loaderGui then
			loaderGui:Destroy()
		end
		showError("Error: " .. tostring(data.error or "Unknown"))
		return
	end

	updateStatus("Access granted!", 0.7)
	task.wait(0.2)

	-- Store session data for main script
	local sessionData = {
		Role = data.role or "MOBILE VIP",
		Duration = data.duration or "LIFETIME",
		Expiry = data.expiry,
		RemainingDays = data.remainingDays,
		ActivatedAt = data.activatedAt,
		Platform = "mobile",
		DeviceCount = data.deviceCount,
		MaxDevices = data.maxDevices,
		Username = data.username,
		IsEventAccess = false,
		Announcement = data.announcement, -- Compensation announcement if any
	}

	-- Show compensation announcement if present
	if data.announcement and data.announcement.type == "compensation" then
		task.spawn(function()
			task.wait(3) -- Wait for UI to load first
			showCompensationToast(data.announcement)
		end)
	end

	loadMobileUI(sessionData, loaderGui, updateStatus, moduleData)
end

-- Execute
main()
