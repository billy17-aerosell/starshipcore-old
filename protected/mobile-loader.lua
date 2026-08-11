--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║              STARSHIP MOBILE LOADER                           ║
    ║              Secure Whitelist Authentication                  ║
    ║              + Event Code System                              ║
    ╚═══════════════════════════════════════════════════════════════╝
]]
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")


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
local SECURITY_REPORT_API = SECURE_API_URL .. "/api/m-sec-r7q2"

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


-- ══════════════════════════════════════════════════════════════════
-- SECURITY: COMPETITIVE URL BLOCKER (Anti-Competitor System)
-- SECURITY: COMPETITIVE URL BLOCKER (Anti-Competitor System)
-- Detects if other loaders (e.g., Rullzsy) try to load concurrently
-- ══════════════════════════════════════════════════════════════════
local function setupCompetitorDetection()
    local blacklistedDomains = {
        "rullzsy99.workers.dev",
        "motioncore.web.id",
        "vip.motioncore.web.id",
        "autowalkdev",
    }

    -- Distinctive competitor identifiers. Avoid generic names such as
    -- "Executed" or "isLoaded" because many unrelated scripts use them.
    local blacklist = {
        uiNames = { "RullzsyHub", "Rulzsy", "Motion Core", "MotionCore", "Motion", "AutoWalkDev" },
        textPatterns = { "rullzsy", "rulzsy", "motion core", "motioncore", "autowalkdev" },
        globals = { "RullzsyLoaded", "RulzsyHub", "Rullzsy", "Rulzsy", "MotionCoreLoaded", "MotionCore", "AutoWalkDev" }
    }

    local securityTerminated = false

    local function findPlain(text, needle)
        return string.find(string.lower(text), string.lower(needle), 1, true) ~= nil
    end

    local function checkUrl(url)
        if type(url) ~= "string" then return false end

        for _, domain in ipairs(blacklistedDomains) do
            if findPlain(url, domain) then
                return true, domain
            end
        end
        return false
    end

    local function checkText(text)
        if type(text) ~= "string" then return false end

        for _, pattern in ipairs(blacklist.textPatterns) do
            if findPlain(text, pattern) then
                return true, pattern
            end
        end
        return false
    end

    local function checkGlobalName(name)
        if type(name) ~= "string" then return false end

        for _, identifier in ipairs(blacklist.globals) do
            if findPlain(name, identifier) then
                return true, identifier
            end
        end
        return false
    end

    -- Discord credentials stay server-side. A short-lived challenge binds each
    -- report to this user and source IP before the relay accepts it.
    local function reportSecurityViolation(reason)
        local req = request
            or http_request
            or (syn and syn.request)
            or (fluxus and fluxus.request)
            or (http and http.request)
            or (krnl and krnl.request)
        if type(req) ~= "function" then
            error("executor request API is unavailable")
        end

        local function getResponseBody(response)
            if type(response) == "string" then return response end
            if type(response) ~= "table" then return nil end
            return response.Body or response.body or response.ResponseBody or response.responseBody
        end

        local function getResponseStatus(response)
            if type(response) ~= "table" then return nil end
            return tonumber(response.StatusCode or response.Status or response.status_code or response.status)
        end

        local executor = "Unknown"
        pcall(function()
            if identifyexecutor then
                local name, version = identifyexecutor()
                executor = tostring(name) .. (version and (" (" .. tostring(version) .. ")") or "")
            end
        end)

        local hwid = "Unknown"
        pcall(function()
            if gethwid then hwid = tostring(gethwid()) end
        end)

        local userId = tostring(LocalPlayer.UserId)
        local challengeResponse = req({
            Url = SECURITY_REPORT_API .. "?action=challenge&userId=" .. HttpService:UrlEncode(userId),
            Method = "GET",
            Headers = { ["Accept"] = "application/json" }
        })
        local challengeStatus = getResponseStatus(challengeResponse)
        if challengeStatus and challengeStatus >= 400 then
            error("challenge endpoint returned HTTP " .. tostring(challengeStatus))
        end

        local challengeBody = getResponseBody(challengeResponse)
        if type(challengeBody) ~= "string" then
            error("challenge response body is unavailable")
        end

        local decoded, challengeData = pcall(function()
            return HttpService:JSONDecode(challengeBody)
        end)
        if not decoded or type(challengeData) ~= "table" or type(challengeData.challenge) ~= "string" then
            error("challenge response is invalid")
        end

        local reportBody = HttpService:JSONEncode({
            challenge = challengeData.challenge,
            userId = userId,
            username = tostring(LocalPlayer.Name),
            displayName = tostring(LocalPlayer.DisplayName),
            executor = executor,
            hwid = hwid, -- Converted to an irreversible fingerprint by the server.
            reason = tostring(reason),
            placeId = tostring(game.PlaceId or 0)
        })

        local reportResponse = req({
            Url = SECURITY_REPORT_API,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["Accept"] = "application/json"
            },
            Body = reportBody
        })
        local reportStatus = getResponseStatus(reportResponse)
        if reportStatus and reportStatus >= 400 then
            error("report endpoint returned HTTP " .. tostring(reportStatus))
        end
    end

    local function terminateScript(reason)
        if securityTerminated then return end
        securityTerminated = true

        -- 0. Submit from a fresh coroutine. Executor HTTP calls may yield, which
        -- is not allowed inside some hookfunction/newcclosure callbacks.
        task.spawn(function()
            local delivered, deliveryError = pcall(reportSecurityViolation, reason)
            if not delivered then
                warn("[Starship Security] Report delivery failed:", tostring(deliveryError))
            end
        end)

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
        -- The caller that detected the violation is responsible for returning
        -- or supplying an empty HTTP response. Cancelling task.running() from
        -- a newly spawned task only cancels that new task itself.
    end

    -- ══════════════════════════════════════════════════════════════════
    -- INITIAL DEEP SCAN (Search memory and UI Content)
    -- ══════════════════════════════════════════════════════════════════
    local function performDeepScan()
        local containers = {}
        local seenContainers = {}

        local function addContainer(container)
            if container and not seenContainers[container] then
                seenContainers[container] = true
                table.insert(containers, container)
            end
        end

        -- Scan hidden UI, CoreGui, and PlayerGui. Different executors/libraries
        -- may parent their interface in different containers.
        local gotHui, hui = pcall(function()
            return gethui and gethui() or nil
        end)
        if gotHui then addContainer(hui) end
        addContainer(game:GetService("CoreGui"))
        addContainer(LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui"))

        -- 1. Check ScreenGui names case-insensitively.
        for _, container in ipairs(containers) do
            local objects = { container }
            for _, descendant in ipairs(container:GetDescendants()) do
                table.insert(objects, descendant)
            end

            for _, object in ipairs(objects) do
                if object:IsA("ScreenGui") then
                    for _, uiName in ipairs(blacklist.uiNames) do
                        if string.lower(object.Name) == string.lower(uiName) then
                            return true, "UI: " .. object.Name
                        end
                    end
                end
            end
        end

        -- 2. Search visible UI text using every configured competitor pattern.
        for _, container in ipairs(containers) do
            local foundInUI = false
            pcall(function()
                for _, descendant in ipairs(container:GetDescendants()) do
                    -- Skip Starship's own interface.
                    if screenGui and descendant:IsDescendantOf(screenGui) then continue end

                    if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
                        local matched, pattern = checkText(descendant.Text)
                        if matched then
                            local uiParent = descendant:FindFirstAncestorOfClass("ScreenGui")
                            local uiName = uiParent and uiParent.Name or "Unknown"
                            foundInUI = "Text: '" .. descendant.Text .. "' in " .. descendant.Name
                                .. " (UI: " .. uiName .. ", match: " .. pattern .. ")"
                            break
                        end
                    end
                end
            end)

            if foundInUI then
                return true, "Competitor UI (" .. foundInUI .. ")"
            end
        end

        -- 3. Search global strings and nested config tables. The old scan used
        -- blacklistedDomains[1], so newly added domains were never checked.
        local function scanTable(tbl, visited, depth)
            if type(tbl) ~= "table" or visited[tbl] or depth > 3 then return nil end
            visited[tbl] = true

            local scanned = 0
            for key, value in pairs(tbl) do
                scanned = scanned + 1
                if scanned > 500 then break end

                if type(key) == "string" then
                    local keyDomain, domain = checkUrl(key)
                    if keyDomain then return "Global key URL: " .. domain end

                    local keyIdentifier, identifier = checkGlobalName(key)
                    if keyIdentifier then return "Global key: " .. identifier end
                end

                if type(value) == "string" then
                    local valueDomain, domain = checkUrl(value)
                    if valueDomain then return "Global string URL: " .. domain end

                    local valueText, pattern = checkText(value)
                    if valueText then return "Global string: " .. pattern end
                elseif type(value) == "table" then
                    local nestedReason = scanTable(value, visited, depth + 1)
                    if nestedReason then return nestedReason end
                end
            end
            return nil
        end

        local globalEnvironment = _G
        pcall(function()
            if getgenv then globalEnvironment = getgenv() end
        end)

        local globalReason = nil
        pcall(function()
            globalReason = scanTable(globalEnvironment, {}, 0)
        end)
        if globalReason then return true, globalReason end

        return false
    end

    -- ══════════════════════════════════════════════════════════════════
    -- INITIAL & CONTINUOUS PROTECTION
    -- ══════════════════════════════════════════════════════════════════
    -- Run the initial check once (blocking).
    local detected, reason = performDeepScan()
    if detected then
        terminateScript("Competitor detected during startup (" .. reason .. ")")
        return true -- Signal the caller to stop the entire loader.
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

    -- Hook game HTTP methods as well as common executor request functions.
    -- Blocking the response prevents loadstring from receiving competitor code.
    if hookfunction then
        local wrapClosure = newcclosure or function(callback) return callback end

        local function hookGameHttpMethod(httpMethod, methodName)
            if type(httpMethod) ~= "function" then return end

            local oldMethod
            pcall(function()
                oldMethod = hookfunction(httpMethod, wrapClosure(function(self, url, ...)
                    local blocked, matchedDomain = checkUrl(url)
                    if blocked then
                        terminateScript("Competitor " .. methodName .. " detected (" .. matchedDomain .. ")")
                        return ""
                    end
                    return oldMethod(self, url, ...)
                end))
            end)
        end

        local function tryHookGameHttpMethod(methodName)
            local available, httpMethod = pcall(function()
                return game[methodName]
            end)
            if available then
                hookGameHttpMethod(httpMethod, methodName)
            end
        end

        tryHookGameHttpMethod("HttpGet")
        tryHookGameHttpMethod("HttpGetAsync")

        local hookedRequestFunctions = {}
        local function hookExecutorRequest(requestFunction, requestName)
            if type(requestFunction) ~= "function" or hookedRequestFunctions[requestFunction] then return end
            hookedRequestFunctions[requestFunction] = true

            local oldRequest
            local installed = pcall(function()
                oldRequest = hookfunction(requestFunction, wrapClosure(function(options, ...)
                    local url = nil
                    if type(options) == "table" then
                        url = options.Url or options.URL or options.url
                    elseif type(options) == "string" then
                        url = options
                    end

                    local blocked, matchedDomain = checkUrl(url)
                    if blocked then
                        terminateScript("Competitor " .. requestName .. " detected (" .. matchedDomain .. ")")
                        return {
                            Success = false,
                            StatusCode = 403,
                            StatusMessage = "Blocked by Starship security",
                            Body = "",
                            Headers = {}
                        }
                    end
                    return oldRequest(options, ...)
                end))
            end)

            if not installed or type(oldRequest) ~= "function" then
                hookedRequestFunctions[requestFunction] = nil
            end
        end

        hookExecutorRequest(request, "request")
        hookExecutorRequest(http_request, "http_request")
        hookExecutorRequest(syn and syn.request, "syn.request")
        hookExecutorRequest(fluxus and fluxus.request, "fluxus.request")
        hookExecutorRequest(http and http.request, "http.request")
        hookExecutorRequest(krnl and krnl.request, "krnl.request")
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

	-- Massive Ghost Watermark (Restored as requested)
	local watermark = Instance.new("ImageLabel")
	watermark.Name = "Watermark"
	watermark.Image = "rbxassetid://85930777472774"
	watermark.Size = UDim2.new(0, 480, 0, 480)
	watermark.Position = UDim2.new(0.5, -240, 0.5, -240)
	watermark.BackgroundTransparency = 1
	watermark.ImageTransparency = 0.97 -- Very ghost-like
	watermark.ImageColor3 = Color3.fromRGB(255, 255, 255)
	watermark.ScaleType = Enum.ScaleType.Fit
	watermark.ZIndex = 2
	watermark.Parent = textureContainer

	-- Static Background (Animations restored for watermark)
	task.spawn(function()
		-- Subtle continuous rotation
		while background and background.Parent do
			watermark.Rotation = watermark.Rotation + 1
			task.wait(0.05)
		end
	end)

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

	-- Static Background (Animations removed as requested)
	task.spawn(function()
		-- Background logic remains static
	end)

	-- Top Header Bar (Matching Main UI)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundTransparency = 1
	header.ZIndex = 50 -- Top Layer
	header.Parent = background

	-- Removed legacy labels and tags to fix overlap
	
	-- Close Button

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
			onProgress = false
		},
		{ 
			name = "PANTAI VOICE", 
			id = "pantai_voice", 
			icon = "rbxassetid://102601684887390", 
			desc = "Ocean-side fishing automation suite",
			placeIds = {126463495082631},
			scriptUrl = SECURE_API_URL .. "/api/m-pv-q8z3",
			onProgress = false
		},
		{ 
			name = "DANAU INDO", 
			id = "danau_indo", 
			icon = "rbxassetid://125329520492541", 
			desc = "Lake-side fishing & mining suite",
			placeIds = {85695526103771},
			scriptUrl = SECURE_API_URL .. "/api/m-di-x2p1",
			onProgress = false
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
			onProgress = false
		}
	}

	-- Game Selection Frame
	-- 🧩 HEADER (Top - Full Width)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, -40, 0, 40)
	header.Position = UDim2.new(0, 20, 0, 10)
	header.BackgroundTransparency = 1
	header.Parent = background

	-- 🚀 STARSHIP LOGO (Header)
	local logoHeader = Instance.new("ImageLabel")
	logoHeader.Name = "LogoHeader"
	logoHeader.Image = "rbxassetid://85930777472774"
	logoHeader.Size = UDim2.new(0, 22, 0, 22)
	logoHeader.Position = UDim2.new(0, 0, 0.5, -11)
	logoHeader.BackgroundTransparency = 1
	logoHeader.ImageColor3 = Color3.fromRGB(255, 45, 90) -- Matching accent color
	logoHeader.Parent = header

	local loaderTitle = Instance.new("TextLabel")
	loaderTitle.Text = "STARSHIP LOADER"
	loaderTitle.Size = UDim2.new(0, 130, 1, 0)
	loaderTitle.Position = UDim2.new(0, 28, 0, 0)
	loaderTitle.BackgroundTransparency = 1
	loaderTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
	loaderTitle.TextSize = 14
	loaderTitle.Font = Enum.Font.GothamBold
	loaderTitle.TextXAlignment = Enum.TextXAlignment.Left
	loaderTitle.Parent = header

	-- 🏷️ STATUS BADGES (Rightmost in group)
	local tagFrame = Instance.new("Frame")
	tagFrame.Size = UDim2.new(0, 110, 0, 18)
	tagFrame.Position = UDim2.new(1, -50, 0, 4) -- Rightmost position (before Close)
	tagFrame.AnchorPoint = Vector2.new(1, 0)
	tagFrame.BackgroundTransparency = 1
	tagFrame.Parent = header

	local function createBadge(name, color, pos)
		local b = Instance.new("Frame")
		b.Size = UDim2.new(0, 42, 1, 0)
		b.Position = pos
		b.BackgroundColor3 = color
		b.Parent = tagFrame
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		
		local l = Instance.new("TextLabel")
		l.Text = name
		l.Size = UDim2.new(1, 0, 1, 0)
		l.BackgroundTransparency = 1
		l.TextColor3 = Color3.fromRGB(0, 0, 0)
		l.TextSize = 8
		l.Font = Enum.Font.GothamBold
		l.Parent = b
	end

	createBadge("VIP", Color3.fromRGB(255, 200, 0), UDim2.new(1, -42, 0, 0)) -- Aligned right in frame
	createBadge("SAFE", Color3.fromRGB(60, 255, 180), UDim2.new(1, -88, 0, 0))

	local profileName = Instance.new("TextLabel")
	profileName.Text = string.upper(LocalPlayer.Name)
	profileName.Size = UDim2.new(0, 150, 0, 18)
	profileName.Position = UDim2.new(1, -145, 0, 4) -- Positioned left of the badges
	profileName.AnchorPoint = Vector2.new(1, 0)
	profileName.BackgroundTransparency = 1
	profileName.TextColor3 = Color3.fromRGB(255, 255, 255)
	profileName.TextSize = 12
	profileName.Font = Enum.Font.GothamBold
	profileName.TextXAlignment = Enum.TextXAlignment.Right
	profileName.Parent = header

	local infoHeader = Instance.new("TextLabel")
	infoHeader.Size = UDim2.new(0, 250, 0, 15)
	infoHeader.Position = UDim2.new(1, -50, 0, 22) -- Aligned with name
	infoHeader.AnchorPoint = Vector2.new(1, 0)
	infoHeader.BackgroundTransparency = 1
	infoHeader.TextColor3 = Color3.fromRGB(120, 120, 130)
	infoHeader.TextSize = 9
	infoHeader.Font = Enum.Font.Code
	infoHeader.TextXAlignment = Enum.TextXAlignment.Right
	infoHeader.Parent = header

	-- Live Header Info Update
	task.spawn(function()
		local execName = "Unknown"
		pcall(function() execName = (identifyexecutor and identifyexecutor()) or "Unknown" end)
		
		while header and header.Parent do
			local timeStr = os.date("%H:%M:%S")
			infoHeader.Text = "TIME: " .. timeStr .. " | STATUS: ONLINE | EXEC: " .. string.upper(execName)
			task.wait(1)
		end
	end)

	-- 🧩 CONTENT AREA (Full Width Grid - Positioned higher to reduce space)
	local gameSelection = Instance.new("Frame")
	gameSelection.Name = "GameSelection"
	gameSelection.Size = UDim2.new(1, -40, 1, -75) -- More height
	gameSelection.Position = UDim2.new(0, 20, 0, 55) -- Higher up
	gameSelection.BackgroundTransparency = 1
	gameSelection.ZIndex = 40
	gameSelection.Parent = background

	-- CONTENT AREA (Selection Title removed for cleaner look)
	local gameList = Instance.new("ScrollingFrame")
	gameList.Size = UDim2.new(1, 0, 1, 0)
	gameList.BackgroundTransparency = 1
	gameList.BorderSizePixel = 0
	gameList.ScrollBarThickness = 0 -- Hidden for cleaner look
	gameList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gameList.CanvasSize = UDim2.new(0, 0, 0, 0)
	gameList.Parent = gameSelection

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.33, -8, 0, 120) -- 3 Columns for perfect aspect ratio
	gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = gameList

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingBottom = UDim.new(0, 30)
	listPadding.PaddingTop = UDim.new(0, 5)
	listPadding.PaddingLeft = UDim.new(0, 2)
	listPadding.PaddingRight = UDim.new(0, 2)
	listPadding.Parent = gameList

	-- State
	local selectedModuleData = nil
	local moduleProgUI = {}

	local function createGameBtn(gameData)
		local btn = Instance.new("TextButton")
		btn.Name = gameData.id
		btn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = gameList
		btn.ZIndex = 51

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 14)
		btnCorner.Parent = btn

		-- 🖼️ BANNER IMAGE (Background)
		local banner = Instance.new("ImageLabel")
		banner.Name = "Banner"
		banner.Size = UDim2.new(1, 0, 1, 0)
		banner.Image = gameData.icon
		banner.ScaleType = Enum.ScaleType.Crop
		banner.ImageTransparency = 0.3 -- Much clearer now
		banner.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		banner.Parent = btn
		Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 14)

		local bannerGradient = Instance.new("UIGradient")
		bannerGradient.Rotation = 90
		bannerGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.2, 0.2, 0.2))
		bannerGradient.Parent = banner

		-- Play button and icon removed for ultra-minimalist layout
		
		-- 🏷️ STATUS BADGE (Top Right)
		local statusTag = Instance.new("TextLabel")
		statusTag.Text = gameData.onProgress and "Updating" or "Secure Access"
		statusTag.Size = UDim2.new(0, 80, 0, 20)
		statusTag.Position = UDim2.new(1, -10, 0, 10)
		statusTag.AnchorPoint = Vector2.new(1, 0)
		statusTag.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		statusTag.BackgroundTransparency = 0.4
		statusTag.TextColor3 = Color3.fromRGB(240, 240, 240)
		statusTag.TextSize = 8
		statusTag.Font = Enum.Font.GothamBold
		statusTag.Parent = btn
		Instance.new("UICorner", statusTag).CornerRadius = UDim.new(0, 6)

		-- ✍️ NAME & DESC Overlay
		local infoFrame = Instance.new("Frame")
		infoFrame.Size = UDim2.new(1, -20, 0, 50)
		infoFrame.Position = UDim2.new(0, 15, 0.5, -10) -- Centered for smaller card
		infoFrame.BackgroundTransparency = 1
		infoFrame.Parent = btn

		local name = Instance.new("TextLabel")
		name.Text = gameData.name
		name.Size = UDim2.new(1, 0, 0, 20)
		name.BackgroundTransparency = 1
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.TextSize = 14
		name.Font = Enum.Font.GothamBold
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Parent = infoFrame

		local desc = Instance.new("TextLabel")
		desc.Text = gameData.desc
		desc.Size = UDim2.new(1, -40, 0, 25)
		desc.Position = UDim2.new(0, 0, 0, 22)
		desc.BackgroundTransparency = 1
		desc.TextColor3 = Color3.fromRGB(180, 180, 180)
		desc.TextSize = 8
		desc.Font = Enum.Font.Gotham
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextWrapped = true
		desc.Parent = infoFrame

		-- Duplicate play button removed for clean layout
		

		-- Progress elements (Hidden initially)
		local progContainer = Instance.new("Frame")
		progContainer.Name = "ProgContainer"
		progContainer.Size = UDim2.new(1, -30, 0, 4)
		progContainer.Position = UDim2.new(0, 15, 1, -10)
		progContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
		progContainer.Visible = false
		progContainer.Parent = btn
		Instance.new("UICorner", progContainer)

		local progFill = Instance.new("Frame")
		progFill.Size = UDim2.new(0, 0, 1, 0)
		progFill.BackgroundColor3 = Color3.fromRGB(255, 45, 90)
		progFill.Parent = progContainer
		Instance.new("UICorner", progFill)

		local progPercent = Instance.new("TextLabel")
		progPercent.Text = "0%"
		progPercent.Size = UDim2.new(0, 30, 0, 12)
		progPercent.Position = UDim2.new(1, 0, 0.5, 0)
		progPercent.AnchorPoint = Vector2.new(1, 0.5)
		progPercent.BackgroundTransparency = 1
		progPercent.TextColor3 = Color3.fromRGB(255, 255, 255)
		progPercent.TextSize = 8
		progPercent.Font = Enum.Font.Code
		progPercent.Visible = false
		progPercent.Parent = btn

		moduleProgUI[gameData.id] = {
			container = progContainer,
			fill = progFill,
			percent = progPercent
		}

		btn.MouseEnter:Connect(function()
			if selectedModuleData then return end
			TweenService:Create(banner, TweenInfo.new(0.4), {ImageTransparency = 0.2}):Play()
		end)

		btn.MouseLeave:Connect(function()
			if selectedModuleData and selectedModuleData.id == gameData.id then return end
			TweenService:Create(banner, TweenInfo.new(0.4), {ImageTransparency = 0.3}):Play()
		end)

		btn.MouseButton1Click:Connect(function()
			if selectedModuleData then return end
			
			if gameData.onProgress then
				-- Feedback for updating
				return
			end

			selectedModuleData = gameData
			closeBtn.Visible = false
			progContainer.Visible = true
			progPercent.Visible = true
			
			TweenService:Create(banner, TweenInfo.new(0.5), {ImageTransparency = 0.1}):Play()
		end)
	end

	for _, g in ipairs(GAMES) do
		createGameBtn(g)
	end

	-- Old branding elements removed to prevent overlapping with new Cylone layout. 
	
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
	-- Legacy bottom elements (User Card, System Metrics, Footer) removed for Cylone layout.
	

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
				if closeBtn then closeBtn.Visible = false end -- Hide close button when loading starts
			end
			-- status.Text line removed to prevent nil error in Grid Mode
			TweenService:Create(ui.fill, TweenInfo.new(progress == 1 and 0.5 or 0.3, Enum.EasingStyle.Quad), {
				Size = UDim2.new(progress, 0, 1, 0)
			}):Play()
			ui.percent.Text = math.floor(progress * 100) .. "%"
		end
		
		-- Global welcome sub update removed to fix nil error
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
	-- placeId dikirim biar webhook log tau game/tempat user lagi jalanin script
	local placeId = tostring(game.PlaceId or 0)
	local authUrl = MOBILE_AUTH_API .. "?userId=" .. userId
		.. "&hwid=" .. HttpService:UrlEncode(deviceHWID)
		.. "&placeId=" .. placeId
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
