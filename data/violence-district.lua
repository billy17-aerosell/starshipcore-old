-- [[ STARSPACE OFFLINE LOADER - WORKSPACE MODE ]] --
-- Script ini akan membaca file langsung dari folder 'starspace' di workspace Anda.

-- Dynamic Path Detection
local BasePath = ""
local possiblePaths = {"", "starspace-violence-district/"}

for _, p in ipairs(possiblePaths) do
	if isfile(p .. "starspace/library.lua") then
		BasePath = p
		break
	end
end

local function loadOffline(name)
	local mapping = {
	["library.lua"] = "starspace/library.lua",
	["addons/ThemeManager.lua"] = "starspace/ThemeManager.lua",
	["addons/SaveManager.lua"] = "starspace/SaveManager.lua"
	}

	local relativePath = mapping[name] or name
	local fullPath = BasePath .. relativePath

	if isfile(fullPath) then
		local content = readfile(fullPath)
		local success, result = pcall(function()
		return loadstring(content)()
	end)

	if success then
		return result
	else
		warn("[starspace] Error loading " .. fullPath .. ": " .. tostring(result))
	end
else
	warn("[starspace] File not found: " .. fullPath)
end
return nil
end

local function loadFromRepo(path) return loadOffline(path) end

-- [[ ROBUST CACHED LOADER SYSTEM ]]
local function AttemptLoad(url, fileName)
    local folder = "StarshipCore/Libraries"
    local localPath = fileName and (folder .. "/" .. fileName) or nil
    
    -- Try loading from LOCAL CACHE first
    if localPath and isfile and isfile(localPath) then
        local success, content = pcall(readfile, localPath)
        if success and content and #content > 100 then
            local func, err = loadstring(content)
            if func then
                local ok, result = pcall(func)
                if ok and result then 
                    warn("[STARSHIP] 📂 Loaded library from cache: " .. fileName)
                    return result 
                end
            end
        end
    end

    -- Download if not in cache or cache load failed
    local success, content = pcall(game.HttpGet, game, url)
    if success and content and #content > 100 then
        -- Save to cache for next time
        if localPath and makefolder and writefile then
            pcall(function()
                if not isfolder("StarshipCore") then makefolder("StarshipCore") end
                if not isfolder(folder) then makefolder(folder) end
                writefile(localPath, content)
                warn("[STARSHIP] 📥 Library saved to cache: " .. fileName)
            end)
        end

        local func, err = loadstring(content)
        if func then
            local ok, result = pcall(func)
            return ok and result or nil
        end
    end
    return nil
end


	-- [[ PREMIUM BYPASS BY ANTIGRAVITY ]]
	local _OriginalWarn = warn
	warn = function(...)
	local args = {...}
	local msg = tostring(args[1])
	if msg:find("security:") or msg:find("tampering") or msg:find("loader warning") then
		return
	end
	return _OriginalWarn(...)
end

local _OriginalPrint = print
print = function(...)
local args = {...}
local msg = tostring(args[1])
if msg:find("get good get starship") or msg:find("starship security") then
	return
end
return _OriginalPrint(...)
end

local function forceAdmin()
	local flags = {
	"STARSHIP_IS_PREMIUM", "STARSHIP_LOADED", "STARSHIP_KEY_TYPE",
	"STARSHIP_LOADER_SIGNATURE", "STARSHIP_PREMIUM_TOKEN",
	"STARSHIP_KEY", "STARSHIP_HWID"
	}
	local values = {
	STARSHIP_IS_PREMIUM = true,
	STARSHIP_LOADED = true,
	STARSHIP_KEY_TYPE = "admin",
	STARSHIP_LOADER_SIGNATURE = "STR_LOADER_v2.6.0",
	STARSHIP_PREMIUM_TOKEN = "BYPASS_TOKEN_LUA_ADMIN_9999",
	STARSHIP_KEY = "BYPASS_KEY_ADMIN_9999",
	STARSHIP_HWID = "OFFLINE_BYPASS_HWID"
	}
	for _, name in ipairs(flags) do
		_G[name] = values[name]
		if getgenv then getgenv()[name] = values[name] end
	end
end

forceAdmin()

-- [[ ACCOUNT STATUS HELPERS (PORTED FROM MOBILEUI) ]]
local function FormatRole(role)
    if not role then return "USER" end
    return string.upper(role:gsub("_", " "))
end

local function ParseVIPExpiry(durationStr)
    if not durationStr or durationStr == "Lifetime" or durationStr == "lifetime" then
        return nil
    end
    local days = tonumber(durationStr:match("(%d+)%s*day"))
    local hours = tonumber(durationStr:match("(%d+)%s*hour"))
    if days then
        return os.time() + (days * 24 * 60 * 60)
    elseif hours then
        return os.time() + (hours * 60 * 60)
    end
    return nil
end

local function FormatTimeRemaining(seconds)
    if seconds <= 0 then return "Expired" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    if days > 0 then return string.format("%dd %dh %dm %ds", days, hours, mins, secs)
    elseif hours > 0 then return string.format("%dh %dm %ds", hours, mins, secs)
    elseif mins > 0 then return string.format("%dm %ds", mins, secs)
    else return string.format("%ds", secs) end
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

if not _G.sessionData then
    _G.sessionData = (getgenv and getgenv().StarshipSession) or { 
        Role = "VIP Mobile", 
        Duration = "30 days",
        UserId = LocalPlayer.UserId,
        Username = LocalPlayer.Name
    }
end
local sessionData = _G.sessionData

task.spawn(function()
while _G.StarshipActive and task.wait(5) do
	forceAdmin()
end
end)

-- Try multiple sources for WindUI Boreal
WindUI = AttemptLoad('https://raw.githubusercontent.com/billy17-netizen/StarshipCore/main/data/WindUI%20Boreal', "WindUI_Boreal.lua")

if not WindUI then
    WindUI = AttemptLoad('https://raw.githubusercontent.com/orialdev/WindUI-Boreal/main/WindUI%20Boreal', "WindUI_Boreal.lua")
end

if not WindUI then
    -- Last fallback to standard WindUI
    WindUI = AttemptLoad('https://github.com/Footagesus/WindUI/releases/latest/download/main.lua', "WindUI_Standard.lua")
end

if not WindUI then
    warn("[STARSHIP] ❌ ERROR: Failed to load UI library. Please check your internet.")
    return
end


_G.StarshipActive = true
Library = {
    Options = {},
    Toggles = {},
    Flags = {},
    Connections = {},
    UnloadCallbacks = {},
    Drawings = {},
    IsWindUI = true,
    Scheme = {
        MainColor = Color3.fromRGB(20, 20, 20),
        BackgroundColor = Color3.fromRGB(15, 15, 15),
        OutlineColor = Color3.fromRGB(40, 40, 40),
        AccentColor = Color3.fromRGB(220, 38, 38),
        FontColor = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.Code
    },
    WatermarkVisible = true,
    ShowCustomCursor = true,
    Registry = {},
    Connections = {},
    ConfigFolder = "Starship_ViolenceDistrict"
}



Options = Library.Options
Toggles = Library.Toggles
_G.StarshipOptions = Options
_G.StarshipToggles = Toggles


function Library:AddToRegistry(obj, properties)
    table.insert(self.Registry, { Instance = obj, Properties = properties })
end



-- [[ NUCLEAR CLEANUP FUNCTIONS ]]
local function ClearDrawings()
    pcall(function()
        if getdrawings then
            for _, v in ipairs(getdrawings()) do
                pcall(function() v:Remove() end)
            end
        end
        if cleardrawings then pcall(cleardrawings) end
    end)
    
    -- Tracked drawings
    if Library and Library.Drawings then
        for _, d in ipairs(Library.Drawings) do
            pcall(function() pcall(function() d:Remove() end) end)
        end
        Library.Drawings = {}
    end
end

-- [[ GLOBAL TRACKERS FOR DRAWINGS ]]
local _OriginalDrawingNew = Drawing and Drawing.new
if _OriginalDrawingNew then
    pcall(function()
        Drawing.new = function(kind)
            local obj = _OriginalDrawingNew(kind)
            if obj then
                table.insert(Library.Drawings, obj)
            end
            return obj
        end
    end)
end

function Library:SafeConnect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(self.Connections, conn)
    return conn
end

function Library:Notify(text, duration)
    if _G.GameFeatureState and _G.GameFeatureState.HideNotification then return end
    local title = "Starship"
    local content = ""
    local icon = "bell"
    if type(text) == "table" then
        title = text.Title or "Starship"
        content = text.Description or text.Content or ""
        duration = text.Time or text.Duration or 5
        icon = text.Icon or "bell"
    else
        content = tostring(text)
    end
    WindUI:Notify({
        Title = title,
        Content = content,
        Duration = duration or 3,
        Icon = icon or "bell"
    })
end

function _safeCall(fn, name)
    if type(fn) == 'function' then
        local ok, err = pcall(fn)
        if not ok then
            warn("[Starship] " .. tostring(name) .. " failed: " .. tostring(err))
            if Library and Library.Notify then
                Library:Notify({
                    Title = tostring(name) .. " Error",
                    Content = "See console for details",
                    Time = 5
                })
            end
        end
    end
end

function SafeInit(fn, name)
    _safeCall(fn, name)
end

function Library:SetWatermarkVisibility(state)
    self.WatermarkVisible = state
    if self.Window then
        if self.Window.SetWatermarkVisibility then
            self.Window:SetWatermarkVisibility(state)
        end
        -- Fallback: Force hide internal watermark frame
        pcall(function()
            local internal = self.Window.Internal or self.Window.Instance
            local wm = internal and internal:FindFirstChild("Watermark", true)
            if wm then wm.Visible = state end
        end)
    end
end

function Library:SetWatermark(text)
    if not self.WatermarkVisible then return end
    if self.Window and self.Window.Watermark then
        pcall(function() self.Window.Watermark:SetTitle(text) end)
    end
end

function Library:OnUnload(fn)
    table.insert(self.UnloadCallbacks, fn)
    return self
end

function Library:Unload()
    if not _G.StarshipActive then return end
    print("[starship] Unloading script...")
    _G.StarshipActive = false
    
    -- Run registered callbacks
    for _, callback in ipairs(self.UnloadCallbacks) do
        pcall(callback)
    end
    
    -- Disconnect all connections
    for _, conn in ipairs(self.Connections) do
        pcall(function()
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end)
    end
    self.Connections = {}

    -- Destroy UI
    if self.Window then
        pcall(function()
            local gui = self.Window.Instance or self.Window.ScreenGui
            if gui then gui:Destroy() end
            if self.Window.Destroy then self.Window:Destroy() end
            if self.Window.DestroyGUI then self.Window:DestroyGUI() end
        end)
    end
    
    -- Set all toggles to false to trigger their cleanup logic
    for flag, toggle in pairs(self.Toggles) do
        if toggle.Value then
            pcall(function() toggle:SetValue(false) end)
        end
    end

    -- Cleanup World/CoreGui Objects
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local objects = { "StarshipMaskInfo", "StarshipSpectatorList", "StarshipMoonwalk", "ESP", "Highlights", "Starship_FX", "WindUI", "WindUI Boreal" }
        for _, name in ipairs(objects) do
            local found = CoreGui:FindFirstChild(name)
            if found then pcall(function() found:Destroy() end) end
        end
        
        -- Individual player cleanup
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            if p.Character then
                for _, v in ipairs(p.Character:GetChildren()) do
                    if v.Name:find("Starship") then
                        pcall(function() v:Destroy() end)
                    end
                end
            end
        end
    end)

    -- Nuclear Drawing Cleanup
    ClearDrawings()

    print("[starship] Successfully cleaned up all features and connections.")
end

function Library:GetConfigs()
    if not isfolder(self.ConfigFolder) then makefolder(self.ConfigFolder) end
    local configs = {}
    local files = listfiles(self.ConfigFolder)
    
    for _, file in ipairs(files) do
        if file:sub(-5) == ".json" then
            local name = file:match("([^/\\]+)%.json$")
            if name then
                table.insert(configs, name)
            end
        end
    end
    
    return configs
end

function Library:SaveConfig(name)
    if not name or name == "" then return end
    if not isfolder(self.ConfigFolder) then makefolder(self.ConfigFolder) end
    
    local data = { Toggles = {}, Options = {} }
    
    for flag, toggle in pairs(self.Toggles) do
        data.Toggles[flag] = toggle.Value
    end
    
    for flag, option in pairs(self.Options) do
        if option.Type == "Keybind" then
            data.Options[flag] = tostring(option.Value)
        else
            data.Options[flag] = option.Value
        end
    end
    
    local success, encoded = pcall(function() return game:GetService("HttpService"):JSONEncode(data) end)
    if success then
        writefile(self.ConfigFolder .. "/" .. name .. ".json", encoded)
        self:Notify("Config saved: " .. name, 3)
    else
        self:Notify("Failed to save config: " .. tostring(encoded), 3)
    end
end

function Library:LoadConfig(name)
    local path = self.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then 
        self:Notify("Config file not found: " .. name, 3)
        return 
    end
    
    local content = readfile(path)
    local success, data = pcall(function() return game:GetService("HttpService"):JSONDecode(content) end)
    
    if success then
        -- Silently load to avoid notification spam
        local gfs = _G.GameFeatureState
        local originalHide = gfs and gfs.HideNotification or false
        if gfs then gfs.HideNotification = true end

        if data.Toggles then
            for flag, value in pairs(data.Toggles) do
                -- Skip camera-altering toggles during load to prevent displacement
                if flag ~= "Freecam" and flag ~= "Desync" and flag ~= "ThirdPersonKiller" then
                    if self.Toggles[flag] and self.Toggles[flag].SetValue then
                        pcall(function() self.Toggles[flag]:SetValue(value) end)
                    end
                end
            end
        end
        if data.Options then
            for flag, value in pairs(data.Options) do
                if self.Options[flag] and self.Options[flag].SetValue then
                    if self.Options[flag].Type == "Keybind" then
                        pcall(function()
                            local keyStr = tostring(value):gsub("Enum.KeyCode.", "")
                            self.Options[flag]:SetValue(Enum.KeyCode[keyStr])
                        end)
                    else
                        pcall(function() self.Options[flag]:SetValue(value) end)
                    end
                end
            end
        end
        
        -- Force Camera Reset after load to prevent 'Zoom into Body' bug
        pcall(function()
            local cam = workspace.CurrentCamera
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if cam and hum then
                cam.CameraSubject = hum
                cam.CameraType = Enum.CameraType.Custom
                cam.FieldOfView = 70
            end
        end)
        
        -- Restore notification state
        if gfs then gfs.HideNotification = originalHide end
        
        self:Notify("Config loaded: " .. name .. " successfully!", 3)
    else
        self:Notify("Failed to load config: Corrupt file", 3)
    end
end

function Library:DeleteConfig(name)
    if not name or name == "" then return end
    if not isfolder(self.ConfigFolder) then return end
    
    local found = false
    local files = listfiles(self.ConfigFolder)
    for _, file in ipairs(files) do
        local fileName = file:match("([^/\\]+)%.json$")
        if fileName == name then
            local success, err = pcall(function() delfile(file) end)
            if success then
                found = true
                self:Notify("Config deleted: " .. name, 3)
            else
                self:Notify("Delete error: " .. tostring(err), 3)
            end
            break
        end
    end
    
    if not found then
        -- Fallback attempt with direct path
        local path = self.ConfigFolder .. "/" .. name .. ".json"
        if isfile(path) then
            pcall(function() delfile(path) end)
            self:Notify("Config deleted (fallback): " .. name, 2)
        end
    end
end

local function wrappedSetDisabled(obj, state)
    obj._disabled = state
end

local function wrappedSetText(obj, text)
    if obj.Element and obj.Element.SetTitle then obj.Element:SetTitle(text) end
end

local function wrappedSetTooltip(obj, text)
    if obj.Element and obj.Element.SetDesc then obj.Element:SetDesc(text) end
end

local function createLinoriaObject(windElement, flag, default, text, parentSection)
    local obj = {
        Value = default,
        Text = text or "",
        Element = windElement,
        ParentSection = parentSection,
        OnChanged = function(self, fn)
            self._callback = fn
            return self
        end,
        SetDisabled = wrappedSetDisabled,
        SetText = function(self, txt)
            self.Text = txt
            if self.Element and self.Element.SetTitle then self.Element:SetTitle(txt) end
        end,
        SetTooltip = wrappedSetTooltip,
        SetValue = function(self, v)
            self.Value = v
            if self.Element and self.Element.Set then self.Element:Set(v) end
            if self._callback then self._callback(v) end
        end,
        OnUnload = function(self, fn) return self end,
        Display = function(self) return self end,
        Refresh = function(self) return self end,
        SetValues = function(self, v)
            if not self.Element then return end
            
            local updated = false
            
            -- Method 1: SetValues
            if self.Element.SetValues then
                local ok = pcall(function() self.Element:SetValues(v) end)
                if ok then updated = true end
            end
            
            -- Method 2: SetOptions
            if not updated and self.Element.SetOptions then
                local ok = pcall(function() self.Element:SetOptions(v) end)
                if ok then updated = true end
            end
            
            -- Method 3: Clear and Re-add (Native WindUI Boreal style)
            if not updated and self.Element.Clear and (self.Element.Option or self.Element.AddOption) then
                pcall(function()
                    self.Element:Clear()
                    for _, val in ipairs(v) do
                        local optMethod = self.Element.Option or self.Element.AddOption
                        optMethod(self.Element, {
                            Title = tostring(val),
                            Callback = function(selected)
                                self:SetValue(selected)
                            end
                        })
                    end
                    updated = true
                end)
            end
            
            -- Method 4: Internal Table Update + Refresh
            if not updated or true then -- Always try this as safety fallback
                if self.Element.Values then
                    self.Element.Values = v
                    if self.Element.Refresh then pcall(function() self.Element:Refresh() end) end
                elseif self.Element.Options and type(self.Element.Options) == "table" then
                    self.Element.Options = v
                    if self.Element.Refresh then pcall(function() self.Element:Refresh() end) end
                end
            end
        end
    }
    
    function obj:AddKeyPicker(flag2, config2)
        if not self.ParentSection then return obj end
        local key = self.ParentSection:Keybind({
            Title = config2.Text or flag2,
            Value = config2.Default or Enum.KeyCode.None,
            Callback = function(v)
                if config2.SyncToggleState then
                    obj:SetValue(not obj.Value)
                end
                if config2.Callback then config2.Callback(v) end
            end
        })
        local linObj = createLinoriaObject(key, flag2, config2.Default, config2.Text or flag2, self.ParentSection)
        linObj.Type = "Keybind"
        Library.Options[flag2] = linObj
        return Library.Options[flag2]
    end
    
    function obj:AddColorPicker(flag2, config2)
        if not self.ParentSection then return obj end
        local cp = self.ParentSection:Colorpicker({
            Title = config2.Title or flag2,
            Default = config2.Default or Color3.new(1,1,1),
            Callback = function(color)
                Library.Options[flag2].Value = color
                if config2.Callback then config2.Callback(color) end
            end
        })
        Library.Options[flag2] = createLinoriaObject(cp, flag2, config2.Default, config2.Title or flag2, self.ParentSection)
        return Library.Options[flag2]
    end
    
    return obj
end

local GroupboxShim = {}
GroupboxShim.__index = GroupboxShim

function GroupboxShim:AddToggle(flag, config)
    local title = config.Text or flag
    local toggle = self.Section:Toggle({
        Title = title,
        Desc = config.Tooltip or "",
        Value = config.Default or false,
        Callback = function(v)
            if Library.Toggles[flag] then
                Library.Toggles[flag].Value = v
            end
            if config.Callback then config.Callback(v) end
            if Library.Toggles[flag] and Library.Toggles[flag]._callback then 
                Library.Toggles[flag]._callback(v) 
            end
        end
    })
    
    local linObj = createLinoriaObject(toggle, flag, config.Default or false, title, self.Section)
    Library.Toggles[flag] = linObj
    return linObj
end

GroupboxShim.AddCheckbox = GroupboxShim.AddToggle

function GroupboxShim:AddSlider(flag, config)
    local title = config.Text or flag
    local slider = self.Section:Slider({
        Title = title,
        Value = {
            Min = config.Min or 0,
            Max = config.Max or 100,
            Default = config.Default or 50,
        },
        Step = config.Rounding or 1,
        Callback = function(v)
            if Library.Options[flag] then
                Library.Options[flag].Value = v
            end
            if config.Callback then config.Callback(v) end
        end
    })
    local linObj = createLinoriaObject(slider, flag, config.Default, title, self.Section)
    Library.Options[flag] = linObj
    return linObj
end

function GroupboxShim:AddDropdown(flag, config)
    local title = config.Text or flag
    local dropdown = self.Section:Dropdown({
        Title = title,
        Multi = config.Multi or false,
        Values = config.Values or config.Options or {},
        Value = config.Default or "",
        Callback = function(v)
            if Library.Options[flag] then
                Library.Options[flag].Value = v
            end
            if config.Callback then config.Callback(v) end
        end
    })
    local linObj = createLinoriaObject(dropdown, flag, config.Default, title, self.Section)
    Library.Options[flag] = linObj
    return linObj
end

function GroupboxShim:AddInput(flag, config)
    local title = config.Text or flag
    local input = self.Section:Input({
        Title = title,
        Placeholder = config.Placeholder or "",
        Value = config.Default or "",
        Callback = function(v)
            if Library.Options[flag] then
                Library.Options[flag].Value = v
            end
            if config.Callback then config.Callback(v) end
        end
    })
    local linObj = createLinoriaObject(input, flag, config.Default, title, self.Section)
    Library.Options[flag] = linObj
    return linObj
end

function GroupboxShim:AddButton(config)
    self.Section:Button({
        Title = config.Text or "Button",
        Desc = config.Tooltip or "",
        Callback = config.Func
    })
    return self -- Support chaining
end

function GroupboxShim:AddLabel(text)
    local ok = pcall(function() self.Section:Label({ Title = text or "" }) end)
    if not ok then
        pcall(function() self.Section:Paragraph({ Title = text or "" }) end)
    end
    return self
end

function GroupboxShim:AddDivider()
    pcall(function() self.Section:Divider() end)
    return self
end

function GroupboxShim:AddParagraph(config)
    local p = self.Section:Paragraph(config)
    return p
end

function GroupboxShim:AddColorPicker(flag, config)
    local cp = self.Section:Colorpicker({
        Title = config.Title or flag,
        Default = config.Default or Color3.new(1,1,1),
        Callback = function(color)
            if Library.Options[flag] then
                Library.Options[flag].Value = color
            end
            if config.Callback then config.Callback(color) end
        end
    })
    Library.Options[flag] = createLinoriaObject(cp, flag, config.Default, config.Title or flag, self.Section)
    return Library.Options[flag]
end

function GroupboxShim:AddKeyPicker(flag, config)
    local key = self.Section:Keybind({
        Title = config.Text or flag,
        Value = config.Default or Enum.KeyCode.None,
        Callback = function(v)
            if Library.Options[flag] then
                Library.Options[flag].Value = v
            end
            if config.Callback then config.Callback(v) end
        end
    })
    local linObj = createLinoriaObject(key, flag, config.Default or Enum.KeyCode.None, config.Text or flag, self.Section)
    linObj.Type = "Keybind"
    Library.Options[flag] = linObj
    return linObj
end

local TabShim = {}
TabShim.__index = TabShim

local MultiSectionShim = {}
MultiSectionShim.__index = MultiSectionShim

local StarshipIconMap = {
    ["book-marked"] = "book",
    ["hat-glasses"] = "swords",
    ["users"] = "users",
    ["navigation-2-off"] = "map",
    ["palette"] = "palette",
    ["cloud-off"] = "cloud-off",
    ["circle-ellipsis"] = "more-horizontal",
    ["rectangle-ellipsis"] = "more-horizontal",
    ["settings"] = "settings",
    ["shield-alert"] = "shield",
    ["swords"] = "swords",
    ["rabbit"] = "bolt",
    ["arrow-big-up-dash"] = "tuning",
    ["drama"] = "masks",
    ["camera"] = "camera",
    ["menu"] = "menu",
    ["layout-grid"] = "house",
    ["zap"] = "zap",
    ["eye"] = "view",
    ["mountain"] = "mountain",
    ["info"] = "info",
    ["star"] = "star",
    ["user"] = "user",
    ["user-circle"] = "user-id",
    ["user-round"] = "user-check",
    ["layout"] = "layout",
    ["swatch-book"] = "book",
    ["pickaxe"] = "hammer",
    ["crosshair"] = "target",
    ["laugh"] = "smile",
    ["eye-off"] = "view",
    ["dollar-sign"] = "dollar",
	["utility-pole"] = "tuning",
    ["badge-cent"] = "dollar",
    ["text-wrap"] = "more-horizontal",
}

function MultiSectionShim:AddTab(tabName, icon)
    -- Create the sub-tab inside the MultiSection
    local subTab = self.MultiSection:Tab({ 
        Title = tabName, 
        Icon = StarshipIconMap[icon] or icon or "circle",
        IconThemed = true
    })
    
    -- Sub-tab visualization removed to match sawah-indo.lua (clean look)
    
    -- Direct return of subTab to ensure all elements use the main scrolling container.
    -- This fixes the clipping bug permanently.
    return setmetatable({ Section = subTab, Tab = self.Tab }, GroupboxShim)
end

function TabShim:AddLeftGroupbox(name, icon)
    -- Initialize a shared MultiSection for this specific Sidebar Tab if it doesn't exist
    -- We store it on the Tab object itself to survive shim re-creation
    if not self.Tab.SharedMulti then
        self.Tab.SharedMulti = self.Tab:MultiSection({
            Title = "Module Configuration",
            Icon = "layout-grid",
            Box = true,
            BoxBorder = true,
            Opened = true
        })
    end
    self.SharedMulti = self.Tab.SharedMulti
        
        -- Fast Staggered Tab-Cycling (Inspired by MobileUI.lua)
        task.spawn(function()
            local intervals = { 2.5, 5.5, 10.5 }
            for _, waitTime in ipairs(intervals) do
                task.wait(waitTime == 2.5 and 2.5 or 3.0)
                pcall(function()
                    if self.SharedMulti and self.SharedMulti.SelectTab then
                        local totalTabs = self.SharedMulti._StarshipTabCount or 1
                        local current = self.SharedMulti.SelectedTab
                        
                        -- Instant cycle through tabs to trigger Roblox AutomaticSize
                        for i = 1, totalTabs do
                            self.SharedMulti:SelectTab(i, true)
                        end
                        
                        -- Back to previous/first tab
                        self.SharedMulti:SelectTab(current or 1, true)
                        
                        -- Visual pulse for the main frame
                        self.SharedMulti:Set(false)
                        task.wait(0.1)
                        self.SharedMulti:Set(true)
                    end
                end)
            end
        end)
    
    local shim = setmetatable({ MultiSection = self.SharedMulti, Tab = self.Tab }, MultiSectionShim)
    return shim:AddTab(name, icon)
end
TabShim.AddRightGroupbox = TabShim.AddLeftGroupbox

function TabShim:AddLeftTabbox(name)
    -- Tabboxes translate perfectly to MultiSections
    local ms = self.Tab:MultiSection({ 
        Title = name,
        Desc = "Tabbed category",
        Icon = "layers",
        Box = true,
        BoxBorder = true,
        Opened = true
    })
    return setmetatable({ MultiSection = ms, Tab = self.Tab }, MultiSectionShim)
end
TabShim.AddRightTabbox = TabShim.AddLeftTabbox

function TabShim:AddSection(name, icon)
    return self:AddLeftGroupbox(name, icon)
end

function TabShim:OnUnload(fn) return self end

local WindowShim = {}
WindowShim.__index = WindowShim

function WindowShim:AddTab(name, icon)
    local rawTab = self.Window:Tab({ Title = name, Icon = StarshipIconMap[icon] or icon or "circle" })
    return setmetatable({ Tab = rawTab }, TabShim)
end

function Library:CreateWindow(config)
    local title = tostring(config.Title or "Starship"):gsub("|", "-"):gsub("┃", "-")
    self.Window = WindUI:CreateWindow({
        Title = title,
        Size = UDim2.fromOffset(750, 560),
        Icon = "rbxassetid://85930777472774", 
        IconSize = 45, 
        ModernLayout = true,
        Author = config.Author or "Premium Edition | StarshipCore",
        Watermark = { Enabled = true, Text = config.Footer or "STARSHIP PREMIUM┃VIOLENCE DISTRICT" },
        Transparent = true,
        BackgroundImageTransparency = 0.92,
        Background = "rbxassetid://132820581372516",
        BottomDragBarEnabled = true,
        TransparentNav = false,
        Theme = "Crimson",
        User = {
            Enabled = true,
            Anonymous = true,
            Callback = function()
                WindUI:Notify({
                    Title = "👤 Starship User",
                    Content = "Welcome to Starship Premium Edition!",
                    Duration = 5,
                })
            end,
        },
        OpenButton = {
            Title = "STARSHIP ✨",
            Icon = "rbxassetid://85930777472774",
            IconSize = 22,
            IconThemed = false,
            Size = UDim2.fromOffset(155, 48), 
            CornerRadius = UDim.new(0.5, 0),
            StrokeThickness = 1.5,
            Enabled = true,
            Draggable = true,
            OnlyMobile = false,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 15)),
                ColorSequenceKeypoint.new(0.6, Color3.fromRGB(45, 10, 10)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 38, 38)), -- Crimson Red
            }),
        },
    })

    -- [UI TOGGLE KEY]
    self.Window:SetToggleKey(Enum.KeyCode.End)
    
    -- [CLEANUP TRIGGER: WINDOW DESTROYED]
    if self.Window then
        pcall(function()
            -- We skip OnClose here because it might trigger on minimize in some WindUI versions
            -- Native OnDestroy: Triggered when window is actually destroyed/removed
            if self.Window.OnDestroy then
                self.Window:OnDestroy(function()
                    Library:Unload()
                end)
            end
        end)
    end
    
    -- Logo Scale Fix
    pcall(function()
        local bgFrame = self.Window.Internal.Background
        local img = bgFrame:FindFirstChildOfClass("ImageLabel")
        if img then
            img.ScaleType = Enum.ScaleType.Fit
        end
    end)
    
    -- Manual Logo Fix & PC Cursor Fix
    task.spawn(function()
        task.wait(1.5)
        pcall(function()
            local openBtn = self.Window.OpenButtonMain
            if openBtn and openBtn.Button then
                for _, icon in ipairs(openBtn.Button:GetDescendants()) do
                    if icon:IsA("ImageLabel") and (icon.Image:find("85930777472774") or icon.Image:find("132820581372516")) then
                        icon.AnchorPoint = Vector2.new(0.5, 0.5)
                        icon.Position = UDim2.new(0.5, 5, 0.5, 0)
                        icon.Size = UDim2.new(0, 32, 0, 32)
                        icon.ImageColor3 = Color3.new(1, 1, 1)
                        icon.ImageTransparency = 0
                        if icon.Parent:IsA("Frame") then icon.Parent.Size = UDim2.new(0, 32, 0, 32) end
                    end
                end
                local openGui = openBtn:FindFirstAncestorOfClass("ScreenGui")
                if openGui then openGui.DisplayOrder = 10001 end
            end
            
            -- Stronger PC Cursor Unlock (Modal)
            local mainGui = self.Window.Instance or self.Window.ScreenGui
            if mainGui then
                mainGui.DisplayOrder = 10000
                -- Create a persistent transparent modal button at the ROOT
                local forceMouse = Instance.new("TextButton")
                forceMouse.Name = "StarshipForceMouse"
                forceMouse.Size = UDim2.new(0, 5, 0, 5)
                forceMouse.Position = UDim2.new(0, 0, 0, 0)
                forceMouse.BackgroundTransparency = 1
                forceMouse.Text = ""
                forceMouse.Modal = true 
                forceMouse.Parent = mainGui
                
                -- Watcher for Visibility
                task.spawn(function()
                    while _G.StarshipActive do
                        task.wait(0.2)
                        local isVisible = false
                        for _, v in ipairs(mainGui:GetChildren()) do
                            if v:IsA("Frame") and v.Visible and not v.Name:find("OpenButton") and v.Name ~= "Tags" then
                                isVisible = true break
                            end
                        end
                        forceMouse.Visible = isVisible
                        if isVisible and Library.ShowCustomCursor ~= false then
                            UserInputService.MouseIconEnabled = true
                            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                        end
                    end
                end)
            end
        end)
    end)
    
    -- Global PC Mouse Enforcer (PREMIUM BYPASS MODE)
    task.spawn(function()
        local RunService = game:GetService("RunService")
        local UIS = game:GetService("UserInputService")
        local GUI = game:GetService("GuiService")
        
        _G.StarshipMenuVisible = false
        
        -- Meta-Method Hook (The ultimate bypass for PC)
        if typeof(hookmetamethod) == "function" then
            local oldIdx; oldIdx = hookmetamethod(UIS, "__newindex", function(self, key, value)
                if not checkcaller() and _G.StarshipMenuVisible then
                    if key == "MouseBehavior" then
                        return oldIdx(self, key, Enum.MouseBehavior.Default)
                    elseif key == "MouseIconEnabled" then
                        return oldIdx(self, key, true)
                    end
                end
                return oldIdx(self, key, value)
            end)
        end

        local function SyncMenuState()
            local gui = self.Window.Instance or self.Window.ScreenGui
            if not gui then return end
            
            local main = gui:FindFirstChild("Main") or gui:FindFirstChild("Container") or gui:FindFirstChild("Internal") or gui:FindFirstChild("Content") or gui:FindFirstChild("Shadow")
            local isVisible = false
            if main and main.Visible and main.BackgroundTransparency < 1 then
                isVisible = true
            end
            _G.StarshipMenuVisible = isVisible
            
            local shield = gui:FindFirstChild("StarshipMouseShield")
            if not shield then
                shield = Instance.new("TextButton")
                shield.Name = "StarshipMouseShield"
                shield.Size = UDim2.new(10, 0, 10, 0)
                shield.Position = UDim2.new(-2, 0, -2, 0)
                shield.BackgroundTransparency = 1
                shield.Text = ""
                shield.ZIndex = -1
                shield.Modal = true
                shield.Parent = gui
            end
            shield.Visible = isVisible
            shield.Modal = isVisible
            
            if isVisible then
                if Library.ShowCustomCursor ~= false then
                    UIS.MouseIconEnabled = true
                    UIS.MouseBehavior = Enum.MouseBehavior.Default
                end
                if LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then
                    LocalPlayer.CameraMode = Enum.CameraMode.Classic
                end
                local mouse = LocalPlayer:GetMouse()
                if mouse then mouse.Icon = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png" end
                
                -- Removed aggressive focus steal as it blocks keybind processing
                -- pcall(function() GUI.SelectedObject = shield end)
            end
        end

        -- Perpetual Watchdog
        RunService.Heartbeat:Connect(function()
            if not _G.StarshipActive then return end
            SyncMenuState()
        end)
    end) -- Closes task.spawn from line 726
    
    
    -- Add Role, FPS and Ping Tags
    local RoleTag = self.Window:Tag({
        Title = FormatRole(sessionData.Role),
        Color = Color3.fromRGB(255, 170, 0),
    })

    local FpsTag = self.Window:Tag({
        Title = "FPS: 0",
        Icon = "zap",
        Color = Color3.fromRGB(80, 255, 150)
    })
    
    local PingTag = self.Window:Tag({
        Title = "Ping: 0",
        Icon = "signal",
        Color = Color3.fromRGB(80, 200, 255)
    })
    
    task.spawn(function()
        local lastTick = tick()
        local frameCount = 0
        local fps = 60
        
        local connection
        connection = Library:SafeConnect(game:GetService("RunService").RenderStepped, function()
            frameCount = frameCount + 1
            if tick() - lastTick >= 1 then
                fps = frameCount
                frameCount = 0
                lastTick = tick()
                
                local ping = "0"
                pcall(function()
                    ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
                end)
                
                pcall(function() FpsTag:SetTitle("FPS: " .. fps) end)
                pcall(function() PingTag:SetTitle("Ping: " .. ping .. "ms") end)
            end
        end)
    end)

    -- Removed non-functional native config call

    return setmetatable({ Window = self.Window }, WindowShim)
end

function WindowShim:SetUserProfile(config)
    -- Dummy
end

function Library:SetWatermark(text)
    -- Dummy
end

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)
local InputHelper = {}
InputHelper.IsMobile = IsMobile
InputHelper.HasVIM = VIM ~= nil
function InputHelper.SendKey(keyCode, isDown, gamepad)
	if VIM then
		local success = pcall(function()
		VIM:SendKeyEvent(isDown, keyCode, false, gamepad or game)
	end)
	if success then return true end
end
pcall(function()
if isDown then
	VirtualUser:SetKeyDown(keyCode)
else
	VirtualUser:SetKeyUp(keyCode)
end
end)
return false
end
function InputHelper.PressKey(keyCode, duration)
	duration = duration or 0.1
	InputHelper.SendKey(keyCode, true)
	task.delay(duration, function()
	InputHelper.SendKey(keyCode, false)
end)
end
function InputHelper.HoldKey(keyCode)
	InputHelper.SendKey(keyCode, true)
end
function InputHelper.ReleaseKey(keyCode)
	InputHelper.SendKey(keyCode, false)
end
function InputHelper.SimulateTouch(position, inputState)
	if not UserInputService.TouchEnabled then return false end
	pcall(function()
	if VIM then
		VIM:SendTouchEvent(position, inputState or Enum.UserInputState.Begin, 0, game)
	end
end)
return true
end
function InputHelper.Click(position)
	local pos = position or Vector2.new(0, 0)
	if VIM then
		local success = pcall(function()
		VIM:SendMouseButtonEvent(pos.X or 0, pos.Y or 0, 0, true, game, 1)
		task.wait(0.05)
		VIM:SendMouseButtonEvent(pos.X or 0, pos.Y or 0, 0, false, game, 1)
	end)
	if success then return true end
end
if IsMobile or UserInputService.TouchEnabled then
	pcall(function()
	if VIM then
		VIM:SendTouchEvent(pos, Enum.UserInputState.Begin, 0, game)
		task.wait(0.05)
		VIM:SendTouchEvent(pos, Enum.UserInputState.End, 0, game)
	end
end)
end
return false
end
function InputHelper.IsDoingAction()
	local char = Players.LocalPlayer.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local hasTag = false
	pcall(function()
	hasTag = game:GetService("CollectionService"):HasTag(hrp, "doing action")
end)
if hasTag then return true end
if char:GetAttribute("IsCarried") or char:GetAttribute("IsHooked") then
	return true
end
local check = char:FindFirstChild("CheckInterractable")
if check then
	for _, attr in ipairs({ "isVaulting", "isSliding", "isDroppingPallet", "isRepairing", "isHealing", "isUnhooking", "isExiting" }) do
		if check:GetAttribute(attr) then
			return true
		end
	end
end
return false
end
function InputHelper.CancelAction()
	pcall(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local mechanics = remotes:FindFirstChild("Mechanics")
		if mechanics then
			local cancel = mechanics:FindFirstChild("cancelaction")
			if cancel then
				cancel:FireServer()
			end
		end
	end
end)
pcall(function()
local char = Players.LocalPlayer.Character
if char then
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		game:GetService("CollectionService"):RemoveTag(hrp, "doing action")
	end
end
end)
end
function InputHelper.TweenCooldownBar(duration)
	pcall(function()
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end
	local gradients = {}
	for _, guiName in ipairs({ "Survivor", "Survivor-con" }) do
		local gui = playerGui:FindFirstChild(guiName)
		if gui then
			local gen = gui:FindFirstChild("Gen")
			if gen then
				local itemFrame = gen:FindFirstChild("ItemFrame")
				local guiBtn = itemFrame and itemFrame:FindFirstChild("Gui")
				if guiBtn then
					local bar = guiBtn:FindFirstChild("Bar")
					local grad = bar and bar:FindFirstChildOfClass("UIGradient")
					if grad then table.insert(gradients, grad) end
				end
			end
		end
	end
	local mob = playerGui:FindFirstChild("Survivor-mob")
	if mob then
		local controls = mob:FindFirstChild("Controls")
		if controls then
			local btn = controls:FindFirstChild("Gui-mob")
			if btn then
				local bar = btn:FindFirstChild("Bar")
				local grad = bar and bar:FindFirstChildOfClass("UIGradient")
				if grad then table.insert(gradients, grad) end
			end
		end
	end
	local ts = game:GetService("TweenService")
	for _, grad in ipairs(gradients) do
		grad.Offset = Vector2.new(0, 0.75)
		local tween = ts:Create(grad, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Offset = Vector2.new(0, 0.25)
		})
		tween:Play()
	end
	local greyColor = Color3.fromRGB(77, 77, 77)
	local whiteColor = Color3.fromRGB(255, 255, 255)
	for _, grad in ipairs(gradients) do
		local icon = grad.Parent and grad.Parent.Parent and grad.Parent.Parent:FindFirstChild("icon")
		if icon then icon.ImageColor3 = greyColor end
		local guiBtn = grad.Parent and grad.Parent.Parent and grad.Parent.Parent.Parent and
		grad.Parent.Parent.Parent:FindFirstChild("Gui")
		if guiBtn and guiBtn:IsA("ImageButton") then guiBtn.ImageColor3 = greyColor end
	end
	task.delay(duration, function()
	for _, grad in ipairs(gradients) do
		local icon = grad.Parent and grad.Parent.Parent and grad.Parent.Parent:FindFirstChild("icon")
		if icon then icon.ImageColor3 = whiteColor end
		local guiBtn = grad.Parent and grad.Parent.Parent and grad.Parent.Parent.Parent and
		grad.Parent.Parent.Parent:FindFirstChild("Gui")
		if guiBtn and guiBtn:IsA("ImageButton") then guiBtn.ImageColor3 = whiteColor end
	end
end)
end)
end
local function pressSpecialButton(args)
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then return 0 end
	local survivor = pg:FindFirstChild("Survivor-mob")
	if not survivor then return 0 end
	local controls = survivor:FindFirstChild("Controls")
	if not controls then return 0 end
	local button = controls:FindFirstChild(args)
	if not button or not (button:IsA("TextButton") or button:IsA("ImageButton")) then return 0 end
	local fired = 0
	for _, ev in ipairs({ "MouseButton1Down", "MouseButton1Up", "MouseButton1Click" }) do
		if button[ev] then
			local ok, conns = pcall(getconnections, button[ev])
			if ok and conns then
				for _, sig in pairs(conns) do
					if sig and sig.Function then
						pcall(sig.Function)
						fired = fired + 1
					end
				end
			end
		end
	end
	return fired
end
function InputHelper.TriggerParry()
	if InputHelper.IsDoingAction() then
		InputHelper.CancelAction()
	end
	local mode = (_G.GameFeatureState and _G.GameFeatureState.AutoParryMode) or "Animation"
	if mode == "No Animation" then
		pcall(function()
		game.ReplicatedStorage.Remotes.Items["Parrying Dagger"].parry:FireServer()
	end)
	if not IsMobile then
		if VIM then
			local Pos = UserInputService:GetMouseLocation()
			VIM:SendMouseButtonEvent(Pos.X, Pos.Y, 1, true, game, 1)
			VIM:SendMouseButtonEvent(Pos.X, Pos.Y, 1, false, game, 1)
		end
	end
	task.defer(function()
	pcall(function()
	local char = Players.LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return end
	for _, track in pairs(animator:GetPlayingAnimationTracks()) do
		if not track.Looped and track.TimePosition < 0.5 then
			track:Stop(0)
		end
	end
end)
task.delay(0.05, function()
pcall(function()
local char = Players.LocalPlayer.Character
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid")
if not hum then return end
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then return end
for _, track in pairs(animator:GetPlayingAnimationTracks()) do
	if not track.Looped and track.TimePosition < 0.15 then
		track:Stop(0)
	end
end
end)
end)
end)
else
	pcall(function()
	local remotes = game.ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end
	local emotes = remotes:FindFirstChild("Emotes")
	if emotes then
		local stopEmote = emotes:FindFirstChild("StopEmote")
		if stopEmote then stopEmote:FireServer() end
	end
end)
pcall(function()
local items = game.ReplicatedStorage.Remotes.Items
local dagger = items and items:FindFirstChild("Parrying Dagger")
local parry = dagger and dagger:FindFirstChild("parry")
if parry then parry:FireServer() end
end)
if IsMobile then
	local fired = pressSpecialButton("Gui-mob")
	if fired == 0 then
		task.defer(function()
		pressSpecialButton("Gui-mob")
	end)
end
else
	if VIM then
		local Pos = UserInputService:GetMouseLocation()
		VIM:SendMouseButtonEvent(Pos.X, Pos.Y, 1, true, game, 1)
		VIM:SendMouseButtonEvent(Pos.X, Pos.Y, 1, false, game, 1)
	end
end
end
local now = tick()
GFS.DaggerCooldownEnd = now + (GFS.ParryCooldownDuration or 1.5)
GFS.LastParryTime = now
_G.LastParryExecuted = now
InputHelper.TweenCooldownBar(GFS.ParryCooldownDuration or 1.5)
return true
end
function InputHelper.FakeParry()
	pcall(function()
	local char = Players.LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local animator = hum:FindFirstChild("Animator")
	if not animator then return end
	local lookVector = workspace.CurrentCamera.CFrame.LookVector
	local flatDir = Vector3.new(lookVector.X, 0, lookVector.Z)
	if flatDir.Magnitude > 0 then
		hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flatDir.Unit)
	end
	hum.AutoRotate = false
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://127096285501517"
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	track:Play()
	pcall(function()
	local slowEvent = ReplicatedStorage.Remotes.Mechanics:FindFirstChild("Slow")
	if slowEvent and slowEvent:IsA("BindableEvent") then
		slowEvent:Fire(0, 1, 0)
	end
end)
track.Stopped:Connect(function()
hum.AutoRotate = true
end)
task.delay(1.0, function()
pcall(function()
if track.IsPlaying then track:Stop() end
hum.AutoRotate = true
end)
end)
end)
end
_G.InputHelper = InputHelper
if not task then
	task = {
	wait = function(...) return wait(...) end,
	spawn = function(fn) return coroutine.wrap(fn)() end,
	defer = function(fn)
	return coroutine.wrap(function()
	wait(); fn()
end)()
end,
delay = function(t, fn)
return coroutine.wrap(function()
wait(t); fn()
end)()
end
}
end
local function verifyPremiumToken() return true, "admin" end
	Init = {}
	local StoredKey = _G.STARSHIP_KEY
	local StoredHwid = _G.STARSHIP_HWID
	local StoredToken = _G.STARSHIP_PREMIUM_TOKEN
	local StoredKeyType = _G.STARSHIP_KEY_TYPE
	if StoredKey == nil and getgenv then StoredKey = getgenv().STARSHIP_KEY end
	if StoredHwid == nil and getgenv then StoredHwid = getgenv().STARSHIP_HWID end
	if StoredToken == nil and getgenv then StoredToken = getgenv().STARSHIP_PREMIUM_TOKEN end
	if StoredKeyType == nil and getgenv then StoredKeyType = getgenv().STARSHIP_KEY_TYPE end
	local IsPremium = true
	local VerifiedKeyType = "admin"

	local LoaderSignature = _G.STARSHIP_LOADER_SIGNATURE
	if LoaderSignature == nil and getgenv then
		LoaderSignature = getgenv().STARSHIP_LOADER_SIGNATURE
	end
	local LoadedThroughOfficialLoader = true
	local function detectPremiumTampering() return false end

		task.spawn(function()
		while true do
			task.wait(60)
			_G.STARSHIP_IS_PREMIUM = true
			IsPremium = true
		end
	end)

	local OriginalPremiumState = true
	local PremiumTamperChecks = 0
	local MaxTamperAttempts = 999999

	local PremiumElements = {}
	local LastAccentColor = nil
	local PremiumColorsInitialized = false
	local function GetAccentColorRGB()
		local r, g, b = 139, 255, 85
		pcall(function()
		if Library and Library.Scheme and Library.Scheme.AccentColor then
			local c = Library.Scheme.AccentColor
			r = math.floor(c.R * 255)
			g = math.floor(c.G * 255)
			b = math.floor(c.B * 255)
		end
	end)
	return r, g, b
end
local function UpdatePremiumElementColor(element, baseText)
	if not element then return end
	local r, g, b = GetAccentColorRGB()
	local premiumTag = string.format('<font color="rgb(%d,%d,%d)"> *</font>', r, g, b)
	pcall(function()
	if element.SetText then
		element:SetText(baseText .. premiumTag)
	end
end)
end
local function UpdateAllPremiumColors()
	for _, data in ipairs(PremiumElements) do
		pcall(function()
		UpdatePremiumElementColor(data.element, data.baseText)
	end)
end
end
local function PremiumOnly(element, keyPicker)
	if not IsPremium then
		if element then
			if element.SetDisabled then
				element:SetDisabled(true)
			end
			local currentText = ""
			pcall(function()
			currentText = element.Text or ""
		end)
		table.insert(PremiumElements, { element = element, baseText = currentText })
		if PremiumColorsInitialized then
			UpdatePremiumElementColor(element, currentText)
		else
			pcall(function()
			if element.SetText then
				element:SetText(currentText .. " *")
			end
		end)
	end
	pcall(function()
	if element.SetTooltip then
		element:SetTooltip(
		"⭐ PREMIUM ONLY\nThis feature requires a Premium key.\nGet Premium from our Discord!")
	end
end)
end
if keyPicker then
	pcall(function()
	if keyPicker.SetDisabled then
		keyPicker:SetDisabled(true)
	end
	if keyPicker.Disabled ~= nil then
		keyPicker.Disabled = true
	end
end)
end
end
return element
end
task.spawn(function()
task.wait(1.5)
PremiumColorsInitialized = true
pcall(function()
if Library and Library.Scheme and Library.Scheme.AccentColor then
	LastAccentColor = Color3.new(
	Library.Scheme.AccentColor.R,
	Library.Scheme.AccentColor.G,
	Library.Scheme.AccentColor.B
	)
end
end)
UpdateAllPremiumColors()
while _G.StarshipActive and task.wait(1) do
	pcall(function()
	if Library and Library.Scheme and Library.Scheme.AccentColor then
		local c = Library.Scheme.AccentColor
		if LastAccentColor == nil or
		math.abs(c.R - LastAccentColor.R) > 0.001 or
		math.abs(c.G - LastAccentColor.G) > 0.001 or
		math.abs(c.B - LastAccentColor.B) > 0.001 then
			LastAccentColor = Color3.new(c.R, c.G, c.B)
			UpdateAllPremiumColors()
		end
	end
end)
end
end)
local ESPEnabled = false
local ChamsEnabled = false
local ESPConnections = {}
local ChamsConnections = {}
_G.ESPObjects = _G.ESPObjects or {}
local ESPObjects = _G.ESPObjects
local ChamsObjects = {}
local DynamicESPConnection = nil
local ChamsObjectConnection = nil
local ESP_Storage = {
ExitGate = { Objects = {}, Enabled = false, Connection = nil, AddedConnection = nil },
Vault = { Objects = {}, Enabled = false, Connection = nil, AddedConnection = nil }
}
local ESP_Logic = {}
_G.GateHelpers = {}
local GateHelpers = _G.GateHelpers
GateHelpers.Cache = {}
GateHelpers.Connection = nil
function GateHelpers.IsGateObject(obj)
	if not obj then return false end
	if obj:GetAttribute("GateProgress") ~= nil then return true end
	if obj:IsA("Model") or obj:IsA("BasePart") then
		local name = obj.Name:lower()
		if name:find("exit") and (name:find("gate") or name:find("door")) then return true end
		if name:find("lever") and obj.Parent and obj.Parent.Name:lower():find("exit") then return true end
	end
	return false
end
function GateHelpers.RefreshCache()
	GateHelpers.Cache = {}
	task.spawn(function()
	local descendants = workspace:GetDescendants()
	for i, obj in ipairs(descendants) do
		if i % 1000 == 0 then task.wait() end
		if GateHelpers.IsGateObject(obj) then
			table.insert(GateHelpers.Cache, obj)
		end
	end
end)
end
function GateHelpers.SetupRealtimeDetection()
	if not GateHelpers.Connection then
		GateHelpers.Connection = workspace.DescendantAdded:Connect(function(obj)
		if GateHelpers.IsGateObject(obj) then
			table.insert(GateHelpers.Cache, obj)
		end
	end)
end
end
function GateHelpers.HandleBypass(Value)
	if Value then
		local role = "Survivor"
		if DetectMyRole then role = DetectMyRole() end
		if role ~= "Survivor" then
			Library:Notify("Bypass Gate: Waiting for Survivor role...", 3)
		else
			Library:Notify('Bypass Gate: Enabled', 2)
		end
		GateHelpers.RefreshCache()
		GateHelpers.SetupRealtimeDetection()
		for _, child in ipairs(game.CoreGui:GetChildren()) do
			if child.Name == "ExitGateBypassGUI" then child:Destroy() end
		end
		task.spawn(function()
		local isHolding = false
		local currentGate = nil
		local ProcessedPositions = {}
		local triggeredNotification = false
		local waitingForRole = false
		while Toggles.BypassGate and Toggles.BypassGate.Value do
			local currentRole = "Survivor"
			if DetectMyRole then currentRole = DetectMyRole() end
			if currentRole ~= "Survivor" then
				if not waitingForRole then
					waitingForRole = true
					isHolding = false
					currentGate = nil
					triggeredNotification = false
					Library:Notify("Bypass Gate: Paused (Not Survivor)", 2)
				end
				task.wait(1)
			else
				if waitingForRole then
					waitingForRole = false
					Library:Notify("Bypass Gate: Resumed (Survivor)", 2)
					GateHelpers.RefreshCache()
				end
				local char = LocalPlayer.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChild("Humanoid")
				if root and hum and hum.Health > 0 then
					local foundGate = nil
					local foundGatePos = nil
					local minDist = 4
					for _, obj in ipairs(GateHelpers.Cache) do
						if obj and obj.Parent then
							local leverPart = obj
							if obj:IsA("Model") then
								leverPart = obj:FindFirstChild("Lever") or obj:FindFirstChild("Handle") or
								obj.PrimaryPart or obj
							end
							if leverPart and leverPart:IsA("BasePart") and leverPart.Position.Magnitude > 5 then
								local isProcessed = false
								for _, pPos in ipairs(ProcessedPositions) do
									if (leverPart.Position - pPos).Magnitude < 10 then
										isProcessed = true
										break
									end
								end
								if not isProcessed then
									local dist = (leverPart.Position - root.Position).Magnitude
									if dist < minDist then
										local gateProgress = obj:GetAttribute("GateProgress") or 0
										local gateOpen = obj:GetAttribute("GateOpen") or false
										if GateHelpers.IsGateObject(obj) and not (gateProgress >= 100 or gateOpen) then
											foundGate = obj
											foundGatePos = leverPart.Position
											minDist = dist
										end
									end
								end
							end
						end
					end
					currentGate = foundGate
					if not currentGate then
						triggeredNotification = false
						isHolding = false
					end
					if currentGate and foundGatePos then
						local gateProgress = currentGate:GetAttribute("GateProgress") or 0
						local gateOpen = currentGate:GetAttribute("GateOpen") or false
						if gateProgress >= 100 or gateOpen then
							table.insert(ProcessedPositions, foundGatePos)
							isHolding = false
							triggeredNotification = false
						else
							if not isHolding then
								if not triggeredNotification then
									Library:Notify("Bypassing Exit Gate...", 2)
									triggeredNotification = true
								end
								isHolding = true
								task.spawn(function()
								local targetGate = currentGate
								local targetPos = foundGatePos
								local exitRemotes = ReplicatedStorage:FindFirstChild("Remotes")
								and ReplicatedStorage.Remotes:FindFirstChild("Exit")
								if exitRemotes and exitRemotes:FindFirstChild("LeverEvent") then
									if Toggles.BypassGate.Value then
										exitRemotes.LeverEvent:FireServer(targetGate, true)
										task.wait(0.1)
										exitRemotes.LeverEvent:FireServer(targetGate, false)
									end
									table.insert(ProcessedPositions, targetPos)
									Library:Notify("Bypass Exit Gate: Success", 3)
								end
								isHolding = false
							end)
						end
					end
				end
			end
		end
		task.wait(0.1)
	end
end)
else
	for _, child in ipairs(game.CoreGui:GetChildren()) do
		if child.Name == "ExitGateBypassGUI" then child:Destroy() end
	end
	Library:Notify('Bypass Gate: Disabled', 2)
end
end
local PerkCache = {}
local ItemCache = {}
_G.StarshipDesyncState = _G.StarshipDesyncState or {}
local DesyncState = _G.StarshipDesyncState
_G.AimbotState = _G.AimbotState or {
silentAimEnabled = false,
aimlockEnabled = false,
aimTarget = nil,
aimFOV = 100,
aimSmoothing = 5,
aimPart = "Head",
aimTeamCheck = true,
aimVisCheck = false,
fovCircle = nil,
targetIndicator = nil,
aimLine = nil,
aimVisualConnection = nil,
}
local AimbotState = _G.AimbotState
_G.GameFeatureState = _G.GameFeatureState or {
AutoParryEnabled = false,
AutoParryDistance = 16,
AutoParryMode = "Animation",
LastParryTime = 0,
AutoParryHoldTime = 0.12,
RecentAttacks = {},
AttackDetectionWindow = 1.0,
AutoWiggleEnabled = false,
LastWiggleTime = 0,
AntiBlindEnabled = false,
AntiBlindSetup = false,
NoSlowdownEnabled = false,
NoSlowdownSetup = false,
AutoAttackEnabled = false,
AutoAttackRange = 12,
LastAutoAttackTime = 0,
AutoAttackDelay = 0.5,
AutoAttackHitCount = 1,
AutoAttackInstant = false,
AutoAttackAnimationFix = false,
MuteHitSoundEnabled = false,
MuteHookInstalled = false,
DoubleTapEnabled = false,
LastDoubleTapTime = 0,
AutoBreakEnabled = false,
NoPalletStunEnabled = false,
NoPalletStunSetup = false,
SpearAimbotEnabled = false,
SpearGravity = 98,
SpearSpeed = 100,
_lastSpearSpeed = nil,
SpearSnaplineEnabled = true,
SpearThruWallEnabled = false,
RadarEnabled = false,
RadarSize = 120,
RadarRange = 150,
RadarCircle = false,
LastRadarUpdate = 0,
RadarUpdateInterval = 0.1,
RadarCachedGens = {},
RadarCachedPallets = {},
LastRadarCacheUpdate = 0,
RadarCacheInterval = 2,
VaultAutoScheduled = false,
PalletAutoScheduled = false,
playerTeamCache = {},
lastChamsRefresh = 0,
HideNotification = false,
AutoDropPalletEnabled = false,
AutoDropPalletLastFire = 0,
AutoDropPalletMode = "Opposite Side",
SkipCutsceneEnabled = false,
}
local GFS = _G.GameFeatureState
local PerkIcons = {
["medic"] = "🩺",
["firstaid"] = "🩺",
["adrenaline"] = "⚡",
["counterattack"] = "⚔️",
["tracker"] = "👣",
["healingspeed"] = "💖",
["highkarma"] = "✨",
["secondwind"] = "🔄",
["onmyown"] = "🚶",
["headsup"] = "👀",
["laststand"] = "🛡️",
["greatcollapse"] = "💥",
["onscreenfear"] = "😱",
["intenseworkout"] = "💪",
["absoluteconfidence"] = "💯",
["callmeback"] = "📞",
["hearingaid"] = "👂",
["grabmyhand"] = "🤝",
["borninblood"] = "🩸",
["leftbehind"] = "👥",
["perfectlanding"] = "🎯",
["quickrecovery"] = "⚕️",
["snakestep"] = "🐍",
["werestrongertogether"] = "💪",
["againstallodds"] = "🎲",
["enhancedtouch"] = "✋",
["expensedecor"] = "💎",
["nobodyleftbehind"] = "🤝",
["pacifist"] = "☮️",
["eyesofheaven"] = "👁️",
["desperate"] = "😰",
["flowstate"] = "🌊",
["groupproject"] = "👥",
["irontranquility"] = "🧘",
}
local PerkImageAssets = {
["highkarma"] = "rbxassetid://98309957404000",
["secondwind"] = "rbxassetid://92659956504940",
["secondwindalt"] = "rbxassetid://75463041942615",
["onmyown"] = "rbxassetid://88851380697714",
["headsup"] = "rbxassetid://84899437064683",
["laststand"] = "rbxassetid://88710023333695",
["greatcollapse"] = "rbxassetid://77361124046809",
["onscreenfear"] = "rbxassetid://95290352058993",
["intenseworkout"] = "rbxassetid://88186532607284",
["absoluteconfidence"] = "rbxassetid://106504717583306",
["callmeback"] = "rbxassetid://77963950720588",
["hearingaid"] = "rbxassetid://120769877589211",
["grabmyhand"] = "rbxassetid://97776397664911",
["borninblood"] = "rbxassetid://102922075720380",
["leftbehind"] = "rbxassetid://80147897612294",
["perfectlanding"] = "rbxassetid://101561368907239",
["quickrecovery"] = "rbxassetid://111002700426073",
["snakestep"] = "rbxassetid://121230220736335",
["werestrongertogether"] = "rbxassetid://75416017747011",
["againstallodds"] = "rbxassetid://77498498698669",
["enhancedtouch"] = "rbxassetid://80800557905871",
["expensedecor"] = "rbxassetid://140122236984192",
["nobodyleftbehind"] = "rbxassetid://104761494654322",
["pacifist"] = "rbxassetid://82998398636487",
["eyesofheaven"] = "rbxassetid://93651121614948",
["desperate"] = "rbxassetid://102616310798703",
["flowstate"] = "rbxassetid://83778618402833",
["groupproject"] = "rbxassetid://97594968089143",
["irontranquility"] = "rbxassetid://118289893089705",
}
local ItemImageAssets = {
["flashlight"] = "rbxassetid://103299939715311",
["frozenlight"] = "rbxassetid://103299939715311",
["bandage"] = "rbxassetid://97791520639443",
["hotchocolate"] = "rbxassetid://97791520639443",
["shadowclone"] = "rbxassetid://134088840518889",
["twistoffate"] = "rbxassetid://98397448432071",
["parryingdagger"] = "rbxassetid://76822757630703",
["dagger"] = "rbxassetid://76822757630703",
["adrenalineshot"] = "rbxassetid://135388781922226",
["waxboundcandle"] = "rbxassetid://110413686590821",
["candle"] = "rbxassetid://110413686590821",
["motiontracker"] = "rbxassetid://92303584765773",
["tracker"] = "rbxassetid://92303584765773",
["gate"] = "rbxassetid://131249244284700",
["bloodshield"] = "rbxassetid://123801171615428",
["shield"] = "rbxassetid://123801171615428",
["enten"] = "rbxassetid://73255252744706",
["feedbacker"] = "rbxassetid://137370559437980",
["awp"] = "rbxassetid://92099126728275",
["previewitemmaster"] = "rbxassetid://76822757630703",
}
local function NormalizeKeyVal(val)
	if not val then return "" end
	if type(val) == 'string' then return tostring(val):lower() end
	if type(val) == 'table' then
		local k = val.Name or val.name or val.id or val.Id or val.perkId or val.PerkId or
		val.itemId or val.ItemId or val.perkName or val.PerkName or val.itemName or val.ItemName
		if k and tostring(k) ~= '' then return tostring(k):lower() end
		for key, value in pairs(val) do
			if type(value) ~= 'table' and tostring(value) ~= '' then
				return tostring(value):lower()
			end
		end
	end
	local ok, n = pcall(function() return val and val.Name end)
	if ok and n and tostring(n) ~= '' then return tostring(n):lower() end
	local str = tostring(val)
	if not str:match("^table: 0x") then
		return str:lower()
	end
	return ""
end
local function GetPerkDisplay(perkId)
	if not perkId then return "" end
	if type(perkId) == 'table' then
		local name = perkId.Name or perkId.name or perkId.perkName or perkId.PerkName
		local id = perkId.id or perkId.Id or perkId.perkId or perkId.PerkId
		if name and tostring(name) ~= '' then
			perkId = tostring(name)
		elseif id and tostring(id) ~= '' then
			perkId = tostring(id)
		else
			local firstVal = next(perkId)
			if firstVal then
				perkId = tostring(perkId[firstVal])
			else
				return ""
			end
		end
	end
	local key = NormalizeKeyVal(perkId)
	if key == "" then return "" end
	if PerkIcons[key] then return PerkIcons[key] end
	local short = (key:gsub("%W+", "") or key)
	return "[" .. (string.sub(short, 1, 8) or short) .. "]"
end
local function GetItemDisplay(itemVal)
	if not itemVal then return "" end
	if type(itemVal) == 'table' then
		local n = itemVal.Name or itemVal.name or itemVal.itemName or itemVal.ItemName or
		itemVal.id or itemVal.Id or itemVal.itemId or itemVal.ItemId
		if n and tostring(n) ~= '' then return tostring(n) end
		local firstKey = next(itemVal)
		if firstKey then
			local firstVal = itemVal[firstKey]
			if type(firstVal) ~= 'table' then
				return tostring(firstVal)
			end
		end
		local normalized = NormalizeKeyVal(itemVal)
		if normalized and normalized ~= '' then return normalized end
		return "[item]"
	end
	return tostring(itemVal)
end
local function NormalizedLookupAsset(assetTable, val)
	if type(assetTable) ~= 'table' then return nil end
	local key = NormalizeKeyVal(val)
	if key == "" then return nil end
	if assetTable[key] then return assetTable[key] end
	local compact = key:gsub("%W+", "")
	if assetTable[compact] then return assetTable[compact] end
	for k, v in pairs(assetTable) do
		local lk = tostring(k):lower()
		if lk:find(key, 1, true) or lk:find(compact, 1, true) then return v end
	end
	local aid = key:match("(%d+)")
	if aid then return "rbxassetid://" .. aid end
	return nil
end
local function ParseLocalAssetFile(content)
	local out = {}
	for line in string.gmatch(content, "[^\r\n]+") do
		local name, id = line:match("^%s*(.-)%s*,%s*(.-)%s*$")
		if name and id then
			local aid = id:match("(%d+)")
			if aid then
				local nk = tostring(name):lower()
				out[nk] = "rbxassetid://" .. aid
				out[nk:gsub("%W+", " ")] = "rbxassetid://" .. aid
				out[nk:gsub("%W+", "")] = "rbxassetid://" .. aid
			end
		end
	end
	return out
end
-- SafeInit is now defined globally at the top
VDHelpers = VDHelpers or {}
VDHelpers.isPlayerKiller = VDHelpers.isPlayerKiller or function(player)
player = player or LocalPlayer
local teamName = nil
if player and player.Team and player.Team.Name then
	teamName = tostring(player.Team.Name)
end
if not teamName or teamName == "" then return false end
return teamName:lower():find("killer", 1, true) ~= nil
end
VDHelpers.isLineInGoalSweetSpot = VDHelpers.isLineInGoalSweetSpot or function(lineRot, goalRot)
local lr = lineRot % 360
local gr = goalRot % 360
local goalStart = (gr + 104) % 360
local goalEnd = (gr + 114) % 360
if goalStart > goalEnd then
	return lr >= goalStart or lr <= goalEnd
else
	return lr >= goalStart and lr <= goalEnd
end
end
VDSurvivorState = VDSurvivorState or {}
VDSurvivorState.pressSpaceForSkillcheck = VDSurvivorState.pressSpaceForSkillcheck or function()
local UIS = game:GetService("UserInputService")
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
if isMobile then
	pcall(function()
	local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then return end
	local survivor = pg:FindFirstChild("Survivor-mob")
	if not survivor then return end
	local controls = survivor:FindFirstChild("Controls")
	if not controls then return end
	local actionBtn = controls:FindFirstChild("action")
	if not actionBtn or not (actionBtn:IsA("TextButton") or actionBtn:IsA("ImageButton")) then return end
	for _, ev in ipairs({ "MouseButton1Down", "MouseButton1Up", "MouseButton1Click" }) do
		if actionBtn[ev] then
			for _, sig in pairs(getconnections(actionBtn[ev])) do
				if sig.Function then
					sig.Function()
				end
			end
		end
	end
end)
elseif _G.InputHelper then
	_G.InputHelper.PressKey(Enum.KeyCode.Space, 0.01)
else
	pcall(function()
	local vim = game:GetService("VirtualInputManager")
	vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
	task.wait(0.01)
	vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
end)
end
end
VDSurvivorState.setupSkillcheckWatcher = function(checkGui)
if not checkGui then return end
local check = checkGui:FindFirstChild("Check")
if not check then return end
local line = check:FindFirstChild("Line")
local goal = check:FindFirstChild("Goal")
if not line or not goal then return end
table.insert(VDSurvivorState.perfectSkillcheckConns, check:GetPropertyChangedSignal("Visible"):Connect(function()
if not VDSurvivorState.alwaysPerfectEnabled then return end
if LocalPlayer.Team and LocalPlayer.Team.Name ~= "Survivors" then return end
if check.Visible then
	table.insert(VDSurvivorState.perfectSkillcheckConns, RunService.Heartbeat:Connect(function()
	local currentCheck = checkGui and checkGui:FindFirstChild("Check")
	if not VDSurvivorState.alwaysPerfectEnabled or not (currentCheck and currentCheck.Visible) then
		local last = VDSurvivorState.perfectSkillcheckConns[#VDSurvivorState.perfectSkillcheckConns]
		if last and type(last.Disconnect) ~= "nil" then
			pcall(function() last:Disconnect() end)
		end
		return
	end
	local l = currentCheck and currentCheck:FindFirstChild("Line")
	local g = currentCheck and currentCheck:FindFirstChild("Goal")
	if l and g and VDHelpers.isLineInGoalSweetSpot(l.Rotation, g.Rotation) then
		VDSurvivorState.pressSpaceForSkillcheck()
		if Toggles.SkillCheckSpam and Toggles.SkillCheckSpam.Value then
			local amount = Options.SpamAmount and Options.SpamAmount.Value or 1
			task.spawn(function()
			if VDSurvivorState.CurrentRepair and VDSurvivorState.CurrentRepair.Point and VDSurvivorState.CurrentRepair.Gen then
				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
				local genSkill = remotes and remotes:FindFirstChild("Generator") and
				remotes.Generator:FindFirstChild("SkillCheckResultEvent")
				if genSkill then
					for i = 1, amount do
						genSkill:FireServer("success", 2, VDSurvivorState.CurrentRepair.Gen,
						VDSurvivorState.CurrentRepair.Point)
						task.wait(0.05)
					end
				end
			end
		end)
	end
	local last = VDSurvivorState.perfectSkillcheckConns[#VDSurvivorState.perfectSkillcheckConns]
	if last and type(last.Disconnect) ~= "nil" then
		pcall(function() last:Disconnect() end)
	end
end
end))
end
end))
end
pcall(function()
if readfile then
	local ok, pcont = pcall(function() return readfile("perks.txt") end)
	if ok and pcont and pcont ~= "" then
		local parsed = ParseLocalAssetFile(pcont)
		for k, v in pairs(parsed) do PerkImageAssets[k] = v end
	end
	local ok2, icont = pcall(function() return readfile("item.txt") end)
	if ok2 and icont and icont ~= "" then
		local parsed = ParseLocalAssetFile(icont)
		for k, v in pairs(parsed) do ItemImageAssets[k] = v end
	end
end
end)
local ESPSettings = {
ShowName = true,
ShowDistance = true,
ShowHealth = true,
ShowBox = true,
BoxESP = false,
SkeletonESP = false,
ChamsESP = false,
TracerESP = false,
FilledBox = false,
MaxDistance = 1000,
TeamCheck = false,
NameColor = Color3.fromRGB(255, 255, 255),
BoxColor = Color3.fromRGB(255, 0, 0),
FilledBoxColor = Color3.fromRGB(255, 0, 0),
HealthBarColor = Color3.fromRGB(0, 255, 0),
SkeletonColor = Color3.fromRGB(255, 255, 255),
DistanceColor = Color3.fromRGB(180, 180, 180),
TracerColor = Color3.fromRGB(255, 255, 255),
KillerTracerColor = Color3.fromRGB(255, 80, 80),
SurvivorTracerColor = Color3.fromRGB(80, 220, 120),
LineColor = Color3.fromRGB(255, 255, 255),
ChamsColor = Color3.fromRGB(255, 120, 0),
ChamsTransparency = 0.3,
ChamsVisibleOnly = false,
ChamsOutline = true,
ChamsOutlineColor = Color3.fromRGB(0, 0, 0),
ChamsOutlineTransparency = 0.5,
ChamsMaxDistance = 2000,
FilledBoxTransparency = 0.2,
ShowExitGateESP = false,
ExitGateESPMaxDistance = 800,
ExitGateESPBoxColor = Color3.fromRGB(0, 230, 120),
ExitGateESPOutlineColor = Color3.fromRGB(0, 0, 0),
ExitGateESPNameColor = Color3.fromRGB(255, 255, 255),
ShowPerks = true,
ShowItems = true,
ShowItemImage = true,
RevealOtherPerks = false,
RevealOtherItems = false,
HeadTrajectoryESP = false,
HeadTrajectoryColor = Color3.fromRGB(255, 200, 50),
}
local VDSettings = {
KillerNames = {
["abysswalker"] = true,
["hidden"] = true,
["jason"] = true,
["jeff"] = true,
["masked"] = true,
["myers"] = true,
["ghostface"] = true,
["pighead"] = true,
["leatherface"] = true,
["pennywise"] = true,
["stalker"] = true,
["slender"] = true,
["slenderman"] = true,
["freddy"] = true,
["chucky"] = true,
["nightmare"] = true,
["monster"] = true,
["beast"] = true,
["entity"] = true,
["demon"] = true,
["hunter"] = true,
["predator"] = true,
["wraith"] = true,
["reaper"] = true,
["executioner"] = true,
["butcher"] = true,
["clown"] = true,
["killer"] = true
},
KillerColor = Color3.fromRGB(255, 0, 0),
SurvivorColor = Color3.fromRGB(0, 150, 255),
GeneratorColor = Color3.fromRGB(255, 200, 0),
HookColor = Color3.fromRGB(255, 255, 0),
KillerTransparency = 0.3,
SurvivorTransparency = 0.3,
GeneratorTransparency = 0.5,
HookTransparency = 0.5,
KillerOutlineColor = Color3.fromRGB(255, 255, 255),
SurvivorOutlineColor = Color3.fromRGB(255, 255, 255),
KillerOutlineEnabled = true,
SurvivorOutlineEnabled = true,
KillerOutlineTransparency = 0,
SurvivorOutlineTransparency = 0,
GeneratorOutlineColor = Color3.fromRGB(255, 255, 255),
GeneratorOutlineEnabled = true,
GeneratorOutlineTransparency = 0,
HookOutlineColor = Color3.fromRGB(255, 255, 255),
HookOutlineEnabled = true,
HookOutlineTransparency = 0,
GeneratorNames = {
["generator"] = true,
["generator_old"] = true,
},
GeneratorPrefix = "generator",
HookNames = {
["hookpoint"] = true,
["hook"] = true,
["hookmeat"] = true
},
HookPrefix = "ho",
ExitGateColor = Color3.fromRGB(0, 255, 0),
ExitGateTransparency = 0.5,
ExitGateOutlineColor = Color3.fromRGB(255, 255, 255),
ExitGateOutlineEnabled = true,
ExitGateOutlineTransparency = 0,
ExitGateNames = {
["exitgate"] = true,
["exitdoor"] = true,
["exitlever"] = true,
["escapegate"] = true,
["escapedoor"] = true,
["gatelever"] = true,
["exitswitch"] = true
},
ExitGatePrefix = "eg",
ExitGateBlacklist = {
["furniture"] = true,
["kitchen"] = true,
["cabinet"] = true,
["interior"] = true,
["chair"] = true,
["knob"] = true,
["plate"] = true,
["shed"] = true,
["wall"] = true,
["floor"] = true,
["window"] = true,
["roof"] = true,
["frame"] = true,
["button"] = true,
["ui"] = true,
["gui"] = true,
["screen"] = true,
["text"] = true,
["label"] = true,
["image"] = true,
["decal"] = true,
["double"] = true,
["front"] = true,
["back"] = true,
["column"] = true,
["pillar"] = true,
["stone"] = true,
["post"] = true,
["support"] = true,
["fence"] = true
},
PalletNames = {
["pallet"] = true,
["palletwrong"] = true,
["palletright"] = true,
["palletdown"] = true,
["palletup"] = true
},
PalletPrefix = "pa",
PalletColor = Color3.fromRGB(220, 180, 100),
PalletTransparency = 0.3,
PalletOutlineColor = Color3.fromRGB(255, 255, 255),
PalletOutlineEnabled = true,
PalletOutlineTransparency = 0,
VaultNames = {
["window"] = true,
["vault"] = true,
["warehousewindow"] = true
},
VaultPrefix = "va",
VaultColor = Color3.fromRGB(0, 255, 255),
VaultTransparency = 0.5,
VaultOutlineColor = Color3.fromRGB(255, 255, 255),
VaultOutlineEnabled = true,
VaultOutlineTransparency = 0,
ShowGenerators = false,
ShowHooks = false,
ShowExitGates = false,
ShowPallets = false,
ShowVaults = false,
ShowVaultsESP = false,
GeneratorMaxDistance = 500,
HookMaxDistance = 500,
ExitGateMaxDistance = 500,
VaultMaxDistance = 500,
ShowGeneratorProgress = true,
ShowRoleText = true,
ShowStatus = true,
UseRoleChams = true,
ShowKillerName = false,
AntiDamage = false,
SmartHitbox = false,
AntiStun = false,
FastCooldown = false,
GodMode = false,
InfiniteStamina = false,
FastRepair = false,
AntiGrab = false,
TPGeneratorEnabled = false,
TPHookEnabled = false,
ShowDebugInfo = false,
CurrentRole = "Unknown",
LastDetectedRole = "Unknown",
NearbyGenerators = 0,
NearbyHooks = 0,
KillerDistance = 0,
KillerName = "Unknown",
KillerAlertDistance = 50,
PlayerStatuses = {},
RemoteStatuses = {},
LastRepairUpdate = {}
}
task.spawn(function()
local function UpdateStatus(target, status)
	if not target then return end
	local statusStr = ""
	if status then
		statusStr = tostring(status)
	end
	if statusStr == "nil" then statusStr = "" end
	if typeof(target) == "Instance" and target:IsA("Player") then
		VDSettings.PlayerStatuses[target] = statusStr
		return
	end
	if typeof(target) == "Instance" and target:IsA("Model") then
		local player = Players:GetPlayerFromCharacter(target)
		if player then
			VDSettings.PlayerStatuses[player] = statusStr
		else
		end
		return
	end
	if typeof(target) == "string" then
		local player = Players:FindFirstChild(target)
		if player then
			VDSettings.PlayerStatuses[player] = statusStr
		else
		end
		return
	end
end
local function GetPlayer(arg)
	if typeof(arg) == "Instance" then
		if arg:IsA("Player") then return arg end
		if arg:IsA("Model") then return Players:GetPlayerFromCharacter(arg) end
		if arg:FindFirstChild("Humanoid") then return Players:GetPlayerFromCharacter(arg) end
	end
	return nil
end
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then return end
pcall(RefreshPerkData)
pcall(RefreshItemData)
if ESPEnabled then pcall(UpdateESP) end
local StatusRemote = Remotes:FindFirstChild("StatusUpdateEvent")
if StatusRemote then
	StatusRemote.OnClientEvent:Connect(function(arg1, arg2)
	local targetPlayer = nil
	local statusMsg = ""
	if typeof(arg1) == "Instance" and arg1:IsA("Player") then
		targetPlayer = arg1
		statusMsg = arg2
	elseif typeof(arg1) == "string" then
		if arg1 ~= "IntermissionStarting" and arg1 ~= "RoundEnding" and arg1 ~= "GameStarting" then
			local p = Players:FindFirstChild(arg1)
			if p then
				targetPlayer = p
				statusMsg = arg2
			end
		end
	end
	if not targetPlayer then
		if typeof(arg2) == "Instance" and arg2:IsA("Player") then
			targetPlayer = arg2
			statusMsg = arg1
		elseif typeof(arg2) == "string" then
			if arg2 ~= "IntermissionStarting" and arg2 ~= "RoundEnding" and arg2 ~= "GameStarting" then
				local p = Players:FindFirstChild(arg2)
				if p then
					targetPlayer = p
					statusMsg = arg1
				end
			end
		end
	end
	if targetPlayer then
		if typeof(statusMsg) ~= "number" then
			UpdateStatus(targetPlayer, statusMsg)
		end
	end
end)
else
end
local GeneratorRemotes = Remotes:FindFirstChild("Generator")
if GeneratorRemotes then
	local RepairAnim = GeneratorRemotes:FindFirstChild("RepairAnim")
	if RepairAnim then
		RepairAnim.OnClientEvent:Connect(function(arg1, arg2, arg3)
		local target = nil
		local active = false
		local p1 = GetPlayer(arg1)
		local p2 = GetPlayer(arg2)
		if p1 then
			target = p1
			if typeof(arg2) == "boolean" then
				active = arg2
			elseif typeof(arg3) == "boolean" then
				active = arg3
			end
		elseif p2 then
			target = p2
			if typeof(arg1) == "boolean" then
				active = arg1
			elseif typeof(arg3) == "boolean" then
				active = arg3
			end
		end
		if target then
			if active then
				VDSettings.RemoteStatuses[target] = "Repairing"
				VDSettings.LastRepairUpdate[target] = tick()
				UpdateStatus(target, "Repairing")
			else
				if VDSettings.RemoteStatuses[target] == "Repairing" then
					VDSettings.RemoteStatuses[target] = nil
				end
				local char = target.Character
				local humanoid = char and char:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health < humanoid.MaxHealth and humanoid.Health > 0 then
					UpdateStatus(target, "Injured")
				else
					UpdateStatus(target, "")
				end
			end
		end
	end)
end
local RepairEvent = GeneratorRemotes:FindFirstChild("RepairEvent")
if RepairEvent then
	RepairEvent.OnClientEvent:Connect(function(arg1, arg2)
	local target = nil
	local active = true
	local p1 = GetPlayer(arg1)
	local p2 = GetPlayer(arg2)
	if p1 then
		target = p1
		if typeof(arg2) == "boolean" then active = arg2 end
	elseif p2 then
		target = p2
		if typeof(arg1) == "boolean" then active = arg1 end
	end
	if target then
		if active then
			VDSettings.RemoteStatuses[target] = "Repairing"
			VDSettings.LastRepairUpdate[target] = tick()
			UpdateStatus(target, "Repairing")
		else
			if VDSettings.RemoteStatuses[target] == "Repairing" then
				VDSettings.RemoteStatuses[target] = nil
			end
			UpdateStatus(target, "")
		end
	end
end)
end
end
local HealingRemotes = Remotes:FindFirstChild("Healing")
if HealingRemotes then
	local function handleHealingEvent(arg)
		local target = GetPlayer(arg) or arg
		if target then
			VDSettings.RemoteStatuses[target] = "Healing"
			UpdateStatus(target, "Healing")
			task.delay(2, function()
			if VDSettings.RemoteStatuses[target] == "Healing" then VDSettings.RemoteStatuses[target] = nil end
		end)
	end
end
if HealingRemotes:FindFirstChild("HealEvent") and HealingRemotes.HealEvent:IsA("RemoteEvent") then
	HealingRemotes.HealEvent.OnClientEvent:Connect(handleHealingEvent)
end
if HealingRemotes:FindFirstChild("HealAnim") and HealingRemotes.HealAnim:IsA("RemoteEvent") then
	HealingRemotes.HealAnim.OnClientEvent:Connect(handleHealingEvent)
end
if HealingRemotes:FindFirstChild("Stophealing") and HealingRemotes.Stophealing:IsA("RemoteEvent") then
	HealingRemotes.Stophealing.OnClientEvent:Connect(function(arg)
	local target = GetPlayer(arg) or arg
	if target and VDSettings.RemoteStatuses[target] == "Healing" then
		VDSettings.RemoteStatuses[target] = nil
		UpdateStatus(target, "")
	end
end)
end
end
local ProgressRemotes = Remotes:FindFirstChild("Progress")
if ProgressRemotes then
	local ProgressUpdateEvent = ProgressRemotes:FindFirstChild("ProgressUpdateEvent")
	if ProgressUpdateEvent then
		ProgressUpdateEvent.OnClientEvent:Connect(function(arg1, arg2)
		local target = GetPlayer(arg1) or GetPlayer(arg2)
		if target then
			VDSettings.RemoteStatuses[target] = "Repairing"
			VDSettings.LastRepairUpdate[target] = tick()
			UpdateStatus(target, "Repairing")
		end
	end)
end
end
local Mechanics = Remotes:FindFirstChild("Mechanics")
if Mechanics then
	local StatusFolder = Mechanics:FindFirstChild("Status")
	if StatusFolder then
		local DisplayStatus = StatusFolder:FindFirstChild("Displaystatus")
		if DisplayStatus then
			DisplayStatus.OnClientEvent:Connect(function(arg1, arg2)
			local targetPlayer = nil
			local statusMsg = ""
			if typeof(arg1) == "Instance" and arg1:IsA("Player") then
				targetPlayer = arg1
				statusMsg = arg2
			elseif typeof(arg1) == "string" then
				if arg1 ~= "IntermissionStarting" then
					local p = Players:FindFirstChild(arg1)
					if p then
						targetPlayer = p
						statusMsg = arg2
					end
				end
			end
			if not targetPlayer then
				if typeof(arg2) == "Instance" and arg2:IsA("Player") then
					targetPlayer = arg2
					statusMsg = arg1
				elseif typeof(arg2) == "string" then
					if arg2 ~= "IntermissionStarting" then
						local p = Players:FindFirstChild(arg2)
						if p then
							targetPlayer = p
							statusMsg = arg1
						end
					end
				end
			end
			if targetPlayer then
				if statusMsg and statusMsg ~= "" then
					VDSettings.RemoteStatuses[targetPlayer] = statusMsg
				else
					VDSettings.RemoteStatuses[targetPlayer] = nil
				end
				UpdateStatus(targetPlayer, statusMsg)
			end
		end)
	else
	end
end
end
local function MonitorCharacterHealth(player, character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end
	local animator = humanoid:WaitForChild("Animator", 5) or humanoid:FindFirstChildOfClass("Animator")
	task.spawn(function()
	while character and character.Parent and humanoid and humanoid.Parent do
		if humanoid.Health <= 0 then
			if VDSettings.PlayerStatuses[player] ~= "Dead" then
				UpdateStatus(player, "Dead")
			end
			break
		end
		local newStatus = ""
		local health = humanoid.Health
		local maxHealth = humanoid.MaxHealth
		local isRepairing = false
		local isHealing = false
		local isCarried = false
		local isHooked = false
		local isKnocked = false
		if VDSettings.RemoteStatuses[player] == "Repairing" and VDSettings.LastRepairUpdate[player] then
			if tick() - VDSettings.LastRepairUpdate[player] > 1.5 then
				VDSettings.RemoteStatuses[player] = nil
			end
		end
		if VDSettings.RemoteStatuses[player] then
			local remoteStatus = VDSettings.RemoteStatuses[player]
			if remoteStatus == "Hooked" then isHooked = true end
			if remoteStatus == "Carried" then isCarried = true end
			if remoteStatus == "Repairing" then isRepairing = true end
			if remoteStatus == "Healing" then isHealing = true end
		end
		if character:GetAttribute("Hooked") or character:GetAttribute("IsHooked") then isHooked = true end
		if character:GetAttribute("Carried") or character:GetAttribute("IsCarried") or character:GetAttribute("BeingCarried") then isCarried = true end
		if character:GetAttribute("Knocked") or character:GetAttribute("Downed") or character:GetAttribute("IsDowned") then isKnocked = true end
		if character:GetAttribute("Repairing") then isRepairing = true end
		if character:GetAttribute("Healing") then isHealing = true end
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track.IsPlaying then
					local name = string.lower(track.Animation.Name)
					if string.find(name, "repair") or string.find(name, "fix") or string.find(name, "gen") or string.find(name, "kneel") or string.find(name, "interact") or string.find(name, "tinker") then
						isRepairing = true
					end
					if string.find(name, "heal") or string.find(name, "bandage") or string.find(name, "patch") or string.find(name, "apply") or string.find(name, "med") then
						isHealing = true
					end
					if string.find(name, "wiggle") or string.find(name, "carry") or string.find(name, "grab") or string.find(name, "hold") then
						isCarried = true
					end
					if string.find(name, "struggle") or string.find(name, "hook") or string.find(name, "hang") then
						isHooked = true
					end
					if string.find(name, "crawl") or string.find(name, "down") or string.find(name, "incap") then
						isKnocked = true
					end
				end
			end
		end
		if health <= 5 and health > 0 then isKnocked = true end
		if isHooked then
			newStatus = "Hooked"
		elseif isCarried then
			newStatus = "Carried"
		elseif isKnocked then
			newStatus = "Knocked"
		elseif isRepairing then
			newStatus = "Repairing"
		elseif isHealing then
			newStatus = "Healing"
		elseif health < maxHealth then
			newStatus = "Injured"
		else
			newStatus = "Healthy"
		end
		if VDSettings.PlayerStatuses[player] ~= newStatus then
			UpdateStatus(player, newStatus)
		end
		task.wait(0.25)
	end
end)
end
Players.PlayerAdded:Connect(function(player)
player.CharacterAdded:Connect(function(char)
MonitorCharacterHealth(player, char)
VDSettings.PlayerStatuses[player] = ""
end)
task.delay(0.1, function()
pcall(RefreshPerkData)
pcall(RefreshItemData)
end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then
		MonitorCharacterHealth(p, p.Character)
	end
	p.CharacterAdded:Connect(function(char)
	MonitorCharacterHealth(p, char)
	VDSettings.PlayerStatuses[p] = ""
end)
end
local Carry = Remotes:FindFirstChild("Carry")
if Carry then
	local HookEvent = Carry:FindFirstChild("HookEvent")
	if HookEvent then
		HookEvent.OnClientEvent:Connect(function(arg1, arg2)
		local survivor = GetPlayer(arg2)
		if not survivor then
			local p1 = GetPlayer(arg1)
			if p1 and p1 ~= LocalPlayer then survivor = p1 end
		end
		if survivor then
			VDSettings.RemoteStatuses[survivor] = "Hooked"
			UpdateStatus(survivor, "Hooked")
		end
	end)
end
local UnHookEvent = Carry:FindFirstChild("UnHookEvent")
if UnHookEvent then
	UnHookEvent.OnClientEvent:Connect(function(arg1, arg2)
	local survivor = GetPlayer(arg2) or GetPlayer(arg1)
	if survivor then
		VDSettings.RemoteStatuses[survivor] = nil
		UpdateStatus(survivor, "Injured")
	end
end)
end
local SelfUnHookEvent = Carry:FindFirstChild("SelfUnHookEvent")
if SelfUnHookEvent then
	SelfUnHookEvent.OnClientEvent:Connect(function(arg1)
	local survivor = GetPlayer(arg1)
	if survivor then
		VDSettings.RemoteStatuses[survivor] = nil
		UpdateStatus(survivor, "Injured")
	end
end)
end
local CarrySurvivorEvent = Carry:FindFirstChild("CarrySurvivorEvent")
if CarrySurvivorEvent then
	CarrySurvivorEvent.OnClientEvent:Connect(function(arg1, arg2)
	local survivor = GetPlayer(arg2)
	if not survivor then
		local p1 = GetPlayer(arg1)
		if p1 and p1 ~= LocalPlayer then survivor = p1 end
	end
	if survivor then
		VDSettings.RemoteStatuses[survivor] = "Carried"
		UpdateStatus(survivor, "Carried")
	end
end)
end
local DropSurvivorEvent = Carry:FindFirstChild("DropSurvivorEvent")
if DropSurvivorEvent then
	DropSurvivorEvent.OnClientEvent:Connect(function(arg1, arg2)
	local survivor = GetPlayer(arg2) or GetPlayer(arg1)
	if survivor then
		VDSettings.RemoteStatuses[survivor] = nil
	end
end)
end
end
end)
local VDESPObjects = {
Generators = {},
Hooks = {},
ExitGates = {},
Pallets = {},
Vaults = {}
}
local UpdateObjectESP
local UpdateGeneratorProgress
local GetGeneratorProgress
local IsKiller
local CreateObjectESP
local RemoveObjectESP
local UpdateObjectESPColor
local UpdateObjectESPTransparency
local Camera = {
FreecamEnabled = false,
FreecamConnection = nil,
FreecamSpeed = 1,
OriginalCameraType = nil,
OriginalFieldOfView = nil,
FOVConnection = nil,
AspectRatioFrame = nil,
AspectRatioConnection = nil
}
local OriginalLighting = {
Ambient = Lighting.Ambient,
Brightness = Lighting.Brightness,
FogEnd = Lighting.FogEnd,
FogStart = Lighting.FogStart,
ClockTime = Lighting.ClockTime,
GlobalShadows = Lighting.GlobalShadows,
OutdoorAmbient = Lighting.OutdoorAmbient,
AtmosphereDensity = (Lighting:FindFirstChild("Atmosphere") and Lighting.Atmosphere.Density) or 0.5,
}
local function GetPlayerHealth(player)
	if not player.Character then return 100 end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return math.floor((humanoid.Health / humanoid.MaxHealth) * 100)
	end
	return 100
end
local VDDebug = {
Enabled = false,
LastPrint = 0,
PrintInterval = 2,
}
local function DebugPrint(...)
	if VDDebug.Enabled then
		print("[VD Debug]", ...)
	end
end
local function DebugPrintPlayers()
	if not VDDebug.Enabled then return end
	local now = tick()
	if now - VDDebug.LastPrint < VDDebug.PrintInterval then return end
	VDDebug.LastPrint = now
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local charName = player.Character and player.Character.Name or "NO_CHARACTER"
			local playerTeam = player.Team and player.Team.Name or "NO_TEAM"
			local isKillerResult = false
			local detectionReason = "none (same team = Survivor)"
			if player.Team and LocalPlayer.Team then
				if player.Team ~= LocalPlayer.Team then
					isKillerResult = true
					detectionReason = "Different Team (we: " .. myTeam .. ", they: " .. playerTeam .. ")"
				end
			else
				local playerNameLower = string.lower(player.Name or "")
				if VDSettings.KillerNames[playerNameLower] then
					isKillerResult = true
					detectionReason = "player.Name in KillerNames"
				elseif string.find(playerNameLower, "killer") then
					isKillerResult = true
					detectionReason = "player.Name contains 'killer'"
				end
				if not isKillerResult and player.Character then
					local charNameLower = string.lower(charName)
					if VDSettings.KillerNames[charNameLower] then
						isKillerResult = true
						detectionReason = "Character.Name in KillerNames"
					elseif string.find(charNameLower, "killer") then
						isKillerResult = true
						detectionReason = "Character.Name contains 'killer'"
					end
				end
			end
		end
	end
end
local function DebugGameInfo()
	return
end
IsKiller = function(player)
if not player then return false end
if player.Team then
	local teamName = string.lower(player.Team.Name or "")
	if string.find(teamName, "killer") or string.find(teamName, "murder") or string.find(teamName, "hunter") then
		DebugPrint(player.Name .. " detected as Killer via Team Name: " .. teamName)
		return true
	end
	if string.find(teamName, "survivor") or string.find(teamName, "victim") or string.find(teamName, "runner") then
		return false
	end
end
local playerName = string.lower(player.Name or "")
if VDSettings.KillerNames[playerName] then
	DebugPrint(player.Name .. " detected as Killer via player.Name in KillerNames")
	return true
end
if string.find(playerName, "killer") then
	DebugPrint(player.Name .. " detected as Killer via player.Name contains 'killer'")
	return true
end
if player.Character then
	local charName = string.lower(player.Character.Name or "")
	if VDSettings.KillerNames[charName] then
		DebugPrint(player.Name ..
		" detected as Killer via Character.Name (" .. player.Character.Name .. ") in KillerNames")
		return true
	end
	if string.find(charName, "killer") then
		DebugPrint(player.Name .. " detected as Killer via Character.Name contains 'killer'")
		return true
	end
	local character = player.Character
	if character:FindFirstChild("KillerTag") or character:FindFirstChild("IsKiller") then
		DebugPrint(player.Name .. " detected as Killer via KillerTag/IsKiller attribute")
		return true
	end
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		if humanoid.WalkSpeed > 18 then
			DebugPrint(player.Name .. " detected as Killer via High WalkSpeed: " .. humanoid.WalkSpeed)
			return true
		end
	end
end
return false
end
local function GetKillerType(player)
	if not player then return nil end
	local pAttr = player:GetAttribute("SelectedKiller") or player:GetAttribute("KillerName") or
	player:GetAttribute("KillerType") or player:GetAttribute("CharacterName")
	if pAttr then return tostring(pAttr) end
	if not player.Character then return nil end
	local char = player.Character
	local knownKillers = {
	"Jason", "Stalker", "Masked", "Hidden", "Abysswalker", "Veil",
	"Freddy", "Myers", "Ghostface", "Pighead", "Leatherface", "Pennywise", "Chucky"
	}
	for _, name in ipairs(knownKillers) do
		if char.Name == name then return name end
	end
	for _, name in ipairs(knownKillers) do
		if char:FindFirstChild(name) then return name end
	end
	local attrName = char:GetAttribute("KillerName") or char:GetAttribute("CharacterName")
	if attrName then return tostring(attrName) end
	return nil
end
local function GetRoleColor(player)
	if IsKiller(player) then
		return VDSettings.KillerColor
	else
		return VDSettings.SurvivorColor
	end
end
local function GetRoleName(player)
	if IsKiller(player) then
		return "Killer"
	else
		return "Survivor"
	end
end
local function IsGenerator(obj)
	if not obj then return false end
	if not obj:IsA("BasePart") and not obj:IsA("Model") then return false end
	local objName = obj.Name:lower()
	if VDSettings.GeneratorNames[objName] then
		return true
	end
	if string.find(objName, "generator") then
		return true
	end
	if obj:GetAttribute("RepairProgress") ~= nil then
		return true
	end
	return false
end
local function IsHook(obj)
	if not obj then return false end
	if not obj:IsA("BasePart") and not obj:IsA("Model") then return false end
	local objName = obj.Name:lower()
	if VDSettings.HookNames[objName] then
		return true
	end
	if string.find(objName, "hook") then
		return true
	end
	if string.sub(objName, 1, 2) == VDSettings.HookPrefix then
		return true
	end
	return false
end
GetGeneratorProgress = function(generator)
if not generator then return 0 end
local repairProgress = generator:GetAttribute("RepairProgress")
if repairProgress and typeof(repairProgress) == "number" then
	DebugPrint("[GenProgress] " .. generator.Name .. " RepairProgress = " .. tostring(repairProgress))
	return repairProgress
end
local progressNames = { "Progress", "progress", "Charge", "charge", "Power", "power", "Percentage", "percentage",
"Value", "value", "RepairProgress" }
for _, name in ipairs(progressNames) do
	local val = generator:FindFirstChild(name)
	if val and (val:IsA("NumberValue") or val:IsA("IntValue")) then
		local progress = val.Value
		if progress > 1 and progress <= 100 then
			return progress
		elseif progress >= 0 and progress <= 1 then
			return progress * 100
		end
	end
end
for _, name in ipairs(progressNames) do
	local attr = generator:GetAttribute(name)
	if attr and typeof(attr) == "number" then
		if attr > 1 and attr <= 100 then
			return attr
		elseif attr >= 0 and attr <= 1 then
			return attr * 100
		end
	end
end
for _, child in ipairs(generator:GetDescendants()) do
	if child:IsA("NumberValue") or child:IsA("IntValue") then
		local nameLower = child.Name:lower()
		if nameLower:find("progress") or nameLower:find("charge") or nameLower:find("power") then
			local progress = child.Value
			if progress > 1 and progress <= 100 then
				return progress
			elseif progress >= 0 and progress <= 1 then
				return progress * 100
			end
		end
	end
end
local surfaceGui = generator:FindFirstChildWhichIsA("SurfaceGui", true)
if surfaceGui then
	local progressBar = surfaceGui:FindFirstChild("Progress", true) or surfaceGui:FindFirstChild("ProgressBar", true)
	if progressBar and progressBar:IsA("Frame") then
		local size = progressBar.Size
		if size.X.Scale > 0 then
			return size.X.Scale * 100
		end
	end
end
local attrProgress = generator:GetAttribute("Progress") or generator:GetAttribute("RepairProgress")
if attrProgress then
	return attrProgress * (attrProgress <= 1 and 100 or 1)
end
local valProgress = generator:FindFirstChild("Progress") or generator:FindFirstChild("RepairProgress")
if valProgress and (valProgress:IsA("NumberValue") or valProgress:IsA("IntValue")) then
	local p = valProgress.Value
	return p * (p <= 1 and 100 or 1)
end
return 0
end
local function FindImmediateParentModel(obj)
	if not obj then return nil end
	if obj:IsA("Model") then
		return obj
	end
	local parent = obj.Parent
	if parent and parent:IsA("Model") and parent ~= workspace then
		local parentNameLower = string.lower(parent.Name)
		local containerNames = {
		"generators", "hooks", "map", "workspace", "objects", "world",
		"parts", "props", "environment", "terrain", "folder", "assets"
		}
		local isContainer = false
		for _, containerName in ipairs(containerNames) do
			if parentNameLower == containerName or string.find(parentNameLower, containerName) then
				isContainer = true
				break
			end
		end
		if not isContainer then
			return parent
		end
	end
	return nil
end
local function GetBestHighlightTarget(obj)
	if not obj then return nil end
	if obj:IsA("Model") then
		return obj
	end
	local parentModel = FindImmediateParentModel(obj)
	if parentModel then
		return parentModel
	end
	if obj:IsA("BasePart") or obj:IsA("MeshPart") then
		return obj
	end
	return nil
end
local function GetHighlightTarget(obj)
	if not obj then return nil end
	if obj:IsA("Model") then
		return obj
	end
	if obj:IsA("BasePart") or obj:IsA("MeshPart") then
		return obj
	end
	return nil
end
local function CollectGenerators()
	local generators = {}
	local seenModels = {}
	local seenParts = {}
	DebugPrint("[CollectGenerators] Starting scan...")
	local descs = workspace:GetDescendants()
	for i, obj in ipairs(descs) do
		if i % 1500 == 0 then task.wait() end
		local isMatch = false
		local matchReason = ""
		if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Model") then
			local nameLower = string.lower(obj.Name)
			if VDSettings.GeneratorNames[nameLower] then
				isMatch = true
				matchReason = "exact name"
			elseif string.find(nameLower, "generator") then
				isMatch = true
				matchReason = "contains 'generator'"
			end
			if not isMatch then
				local repairProgress = obj:GetAttribute("RepairProgress")
				if repairProgress ~= nil then
					isMatch = true
					matchReason = "has RepairProgress attribute"
				end
			end
		end
		if isMatch and obj.Parent then
			local target = GetBestHighlightTarget(obj)
			if target then
				if target:IsA("Model") then
					if not seenModels[target] then
						seenModels[target] = true
						table.insert(generators, target)
						DebugPrint("[CollectGenerators] Added Model: " .. target.Name .. " (" .. matchReason .. ")")
					end
				else
					if not seenParts[target] then
						seenParts[target] = true
						table.insert(generators, target)
						DebugPrint("[CollectGenerators] Added Part: " .. target.Name .. " (" .. matchReason .. ")")
					end
				end
			end
		end
	end
	VDSettings.NearbyGenerators = #generators
	DebugPrint("[CollectGenerators] Total found: " .. #generators .. " generators")
	return generators
end
local function CollectHooks()
	local hooks = {}
	local seenModels = {}
	local seenParts = {}
	DebugPrint("[CollectHooks] Starting scan...")
	local descs = workspace:GetDescendants()
	for i, obj in ipairs(descs) do
		if i % 1500 == 0 then task.wait() end
		local isMatch = false
		local matchReason = ""
		if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Model") then
			local nameLower = string.lower(obj.Name)
			if VDSettings.HookNames[nameLower] then
				isMatch = true
				matchReason = "exact name"
			elseif string.find(nameLower, "meat_hook") or string.find(nameLower, "meathook") then
				isMatch = true
				matchReason = "meathook match"
			elseif nameLower == "hook" then
				isMatch = true
				matchReason = "exact hook match"
			end
			if not isMatch then
				local isHookAttr = obj:GetAttribute("IsHook") or obj:GetAttribute("HookPoint")
				if isHookAttr == true then
					isMatch = true
					matchReason = "has hook attribute"
				end
			end
			if not isMatch and obj:IsA("Model") then
				if obj:FindFirstChild("HookEvent", true) or obj:FindFirstChild("Hook", true) then
					if not obj:FindFirstChild("Humanoid") then
						isMatch = true
						matchReason = "has hook event child"
					end
				end
			end
		end
		if isMatch and obj.Parent then
			local target = GetBestHighlightTarget(obj)
			if target then
				if target:IsA("Model") then
					if not seenModels[target] then
						seenModels[target] = true
						table.insert(hooks, target)
						DebugPrint("[CollectHooks] Added Model: " .. target.Name .. " (" .. matchReason .. ")")
					end
				else
					if not seenParts[target] then
						seenParts[target] = true
						table.insert(hooks, target)
						DebugPrint("[CollectHooks] Added Part: " .. target.Name .. " (" .. matchReason .. ")")
					end
				end
			end
		end
	end
	VDSettings.NearbyHooks = #hooks
	DebugPrint("[CollectHooks] Total found: " .. #hooks .. " hooks")
	return hooks
end
local function CollectExitGates()
	local exits = {}
	local seenModels = {}
	local seenParts = {}
	DebugPrint("[CollectExitGates] Starting scan...")
	local descs = workspace:GetDescendants()
	for i, obj in ipairs(descs) do
		if i % 1500 == 0 then task.wait() end
		local isMatch = false
		local matchReason = ""
		if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Model") then
			local nameLower = string.lower(obj.Name)
			local isBlacklisted = false
			for blackword, _ in pairs(VDSettings.ExitGateBlacklist) do
				if string.find(nameLower, blackword) then
					isBlacklisted = true
					break
				end
			end
			if not isBlacklisted then
				if VDSettings.ExitGateNames[nameLower] then
					isMatch = true
					matchReason = "exact name: " .. nameLower
				elseif string.find(nameLower, "exit") and string.find(nameLower, "gate") and not string.match(nameLower, "^exit$") and not string.match(nameLower, "^gate$") then
					isMatch = true
					matchReason = "exitgate combo: " .. nameLower
				elseif string.find(nameLower, "exit") and string.find(nameLower, "lever") and not string.match(nameLower, "^exit$") and not string.match(nameLower, "^lever$") then
					isMatch = true
					matchReason = "exitlever combo: " .. nameLower
				elseif string.find(nameLower, "exit") and string.find(nameLower, "door") and not string.match(nameLower, "^exit$") and not string.match(nameLower, "^door$") then
					isMatch = true
					matchReason = "exitdoor combo: " .. nameLower
				elseif string.sub(nameLower, 1, #VDSettings.ExitGatePrefix) == VDSettings.ExitGatePrefix and #nameLower > #VDSettings.ExitGatePrefix then
					isMatch = true
					matchReason = "prefix eg: " .. nameLower
				end
				if not isMatch then
					local exitAttr = obj:GetAttribute("IsExit") or obj:GetAttribute("ExitGate") or
					obj:GetAttribute("IsExitGate")
					if exitAttr ~= nil then
						isMatch = true
						matchReason = "attribute: " .. nameLower
					end
				end
			end
		end
		if isMatch and obj.Parent then
			local target = GetBestHighlightTarget(obj)
			if target then
				if target:IsA("Model") then
					if not seenModels[target] then
						seenModels[target] = true
						table.insert(exits, target)
						DebugPrint("[CollectExitGates] Added Model: " .. target.Name .. " (" .. matchReason .. ")")
					end
				else
					if not seenParts[target] then
						seenParts[target] = true
						table.insert(exits, target)
						DebugPrint("[CollectExitGates] Added Part: " .. target.Name .. " (" .. matchReason .. ")")
					end
				end
			end
		end
	end
	VDSettings.NearbyExitGates = #exits
	DebugPrint("[CollectExitGates] Total found: " .. #exits .. " exit gates")
	return exits
end
local function CollectPallets()
	local pallets = {}
	local seenModels = {}
	DebugPrint("[CollectPallets] Starting STRICT scan...")
	local descs = workspace:GetDescendants()
	for i, obj in ipairs(descs) do
		if i % 1500 == 0 then task.wait() end
		if obj:IsA("Model") then
			local nameLower = string.lower(obj.Name)
			local isMatch = false
			local matchReason = ""
			if VDSettings.PalletNames[nameLower] then
				isMatch = true
				matchReason = "exact name"
			elseif nameLower == "palletwrong" then
				isMatch = true
				matchReason = "palletwrong model"
			end
			if isMatch and obj.Parent then
				local parent = obj.Parent
				local parentName = parent and string.lower(parent.Name) or ""
				local hasParts = false
				for _, child in ipairs(obj:GetChildren()) do
					if child:IsA("BasePart") or child:IsA("MeshPart") then
						hasParts = true
						break
					end
				end
				if hasParts and (parentName == "map" or parentName == "pallet" or parentName == "pallets") then
					if not seenModels[obj] then
						seenModels[obj] = true
						table.insert(pallets, obj)
						DebugPrint("[CollectPallets] ✅ Added Model: " ..
						obj.Name .. " (" .. matchReason .. ", " .. #obj:GetChildren() .. " children)")
					end
				else
					DebugPrint("[CollectPallets] ❌ Skipped: " ..
					obj.Name .. " (hasParts=" .. tostring(hasParts) .. ", parent=" .. parentName .. ")")
				end
			end
		end
	end
	DebugPrint("[CollectPallets] Total found: " .. #pallets .. " pallets")
	return pallets
end
local function CollectVaults()
	local vaults = {}
	local seenModels = {}
	local function isValidVaultObject(obj)
		if not obj then return false end
		local path = string.lower(obj:GetFullName())
		if string.find(path, "lobby") or string.find(path, "waiting") or string.find(path, "intermission") then
			return false
		end
		return true
	end
	local descs = workspace:GetDescendants()
	for i, obj in ipairs(descs) do
		if i % 1500 == 0 then task.wait() end
		if obj:IsA("BasePart") or obj:IsA("MeshPart") then
			local name = string.lower(obj.Name)
			if string.find(name, "vaulttrigger") or (string.find(name, "trigger") and string.find(name, "window")) then
				local parent = obj.Parent
				if parent then
					local pName = string.lower(parent.Name)
					if string.find(pName, "window") or string.find(pName, "vault") then
						if isValidVaultObject(parent) and not seenModels[parent] then
							seenModels[parent] = true
							table.insert(vaults, parent)
						end
					end
				end
			end
		end
	end
	VDSettings.NearbyVaults = #vaults
	return vaults
end
local function RefreshPerkData()
	for _, player in ipairs(Players:GetPlayers()) do
		local perks = {}
		pcall(function()
		for i = 1, 4 do
			local attrName = "EquippedPerk" .. i
			local perkId = player:GetAttribute(attrName)
			if perkId and perkId ~= "" and perkId ~= "0" then
				table.insert(perks, perkId)
			end
		end
		if #perks == 0 and player.Character then
			for name, value in pairs(player.Character:GetAttributes()) do
				if type(name) == "string" and (name:find("Perk") or name:find("Skill")) and value == true then
					table.insert(perks, name)
				end
			end
		end
	end)
	if #perks > 0 then
		PerkCache[player] = perks
	else
		PerkCache[player] = {}
	end
end
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then return end
local shop = remotes:FindFirstChild("Shop")
if shop then
	local getPerks = shop:FindFirstChild("GetEquippedKillerPerks")
	if getPerks and getPerks:IsA("RemoteFunction") then
		local ok, res = pcall(function() return getPerks:InvokeServer() end)
		if not ok then
		end
		if ok and type(res) == "table" then
			for _, player in ipairs(Players:GetPlayers()) do
				local key = tostring(player.UserId)
				local perks = nil
				if res[player.Name] then perks = res[player.Name] end
				if res[key] then perks = res[key] end
				if perks and type(perks) == "table" then
					PerkCache[player] = perks
				end
			end
		end
	end
end
if shop then
	local getEquippedPerks = shop:FindFirstChild("GetEquippedPerks")
	if getEquippedPerks and getEquippedPerks:IsA("RemoteFunction") then
		local ok, res = pcall(function() return getEquippedPerks:InvokeServer() end)
		if ok and res and type(res) == "table" then
			if not PerkCache[LocalPlayer] or #PerkCache[LocalPlayer] == 0 then
				PerkCache[LocalPlayer] = res
			end
			if #res > 0 and not _G.VDPerkStructureLogged then
				_G.VDPerkStructureLogged = true
				pcall(function()
				print("[Starship] get good get starship")
				for i, perk in ipairs(res) do
					print("  Perk #" .. i .. ":", type(perk))
					if type(perk) == 'table' then
						for k, v in pairs(perk) do
							print("    [" .. tostring(k) .. "] = " .. tostring(v))
						end
					else
						print("    Value:", tostring(perk))
					end
					if i >= 2 then break end
				end
			end)
		end
	end
end
end
if ESPSettings.RevealOtherPerks then
	local candidates = {
	{ "Shop",  "GetPlayerPerks",    true },
	{ "Perks", "GetPerksForPlayer", true },
	{ "Perks", "GetPlayerPerks",    true },
	{ "Shop",  "GetPerks",          true },
	}
	for _, cand in ipairs(candidates) do
		local grp = remotes:FindFirstChild(cand[1])
		if grp then
			local rf = grp:FindFirstChild(cand[2])
			if rf and rf:IsA("RemoteFunction") then
				for _, player in ipairs(Players:GetPlayers()) do
					if player ~= LocalPlayer and (not PerkCache[player] or #PerkCache[player] == 0) then
						local ok, res
						if cand[3] then
							ok, res = pcall(function() return rf:InvokeServer(player.Name) end)
						else
							ok, res = pcall(function() return rf:InvokeServer() end)
						end
						if ok and res then
							if type(res) == "table" then
								if res[player.Name] then
									PerkCache[player] = res[player.Name]
								elseif res[tostring(player.UserId)] then
									PerkCache[player] = res[tostring(player.UserId)]
								else
									if #res > 0 then PerkCache[player] = res end
								end
							elseif type(res) == "string" then
								PerkCache[player] = { res }
							end
						end
					end
				end
			end
		end
	end
end
local missingPerkPlayers = {}
for _, player in ipairs(Players:GetPlayers()) do
	if not PerkCache[player] or #PerkCache[player] == 0 then
		local current = {}
		local found = false
		local pFolder = player:FindFirstChild("Perks") or
		(player.Character and player.Character:FindFirstChild("Perks"))
		if pFolder and pFolder:IsA("Folder") then
			for _, v in ipairs(pFolder:GetChildren()) do
				if v.Name then
					table.insert(current, v.Name); found = true
				end
			end
		end
		local attr = player:GetAttribute("Perks")
		if attr and type(attr) == "table" then
			for _, v in ipairs(attr) do
				table.insert(current, v); found = true
			end
		elseif attr and type(attr) == "string" then
			table.insert(current, attr); found = true
		end
		if found then
			PerkCache[player] = current
		else
			table.insert(missingPerkPlayers, player.Name)
		end
	end
end
end
local function RefreshItemData()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	for _, player in ipairs(Players:GetPlayers()) do
		local held = ""
		local equippedAttr = player:GetAttribute("EquippedItem")
		if equippedAttr and type(equippedAttr) == "string" and equippedAttr ~= "" then
			held = equippedAttr
		end
		if held == "" then
			local char = player.Character
			if char then
				for _, c in ipairs(char:GetChildren()) do
					if c:IsA("Tool") then
						held = c.Name
						break
					end
				end
				if held == "" then
					local attr = char:GetAttribute("HeldItem") or char:GetAttribute("CurrentItem") or
					char:GetAttribute("EquippedItem")
					if attr and type(attr) == "string" then held = attr end
				end
			end
		end
		if held == "" and ESPSettings.RevealOtherItems and remotes then
			local candidates = {
			{ "Shop",      "GetPlayerItem",    true },
			{ "Items",     "GetHeldItem",      true },
			{ "Shop",      "GetHeldItems",     false },
			{ "Inventory", "GetPlayerItem",    true },
			{ "Shop",      "GetItemForPlayer", true }
			}
			for _, cand in ipairs(candidates) do
				local grp = remotes:FindFirstChild(cand[1])
				if grp then
					local rf = grp:FindFirstChild(cand[2])
					if rf and rf:IsA("RemoteFunction") then
						local ok, res
						if cand[3] then
							ok, res = pcall(function() return rf:InvokeServer(player.Name) end)
						else
							ok, res = pcall(function() return rf:InvokeServer() end)
						end
						if ok and res then
							if type(res) == "table" and #res > 0 then
								held = tostring(res[1])
								break
							elseif type(res) == "string" then
								held = res
								break
							end
						end
					end
				end
			end
		end
		ItemCache[player] = held
	end
end
pcall(RefreshPerkData)
pcall(RefreshItemData)
task.spawn(function()
while true do
	pcall(RefreshPerkData)
	pcall(RefreshItemData)
	if ESPEnabled then
		pcall(UpdateESP)
	end
	task.wait(3)
end
end)
local function GetKillerDistance()
	if not LocalPlayer.Character then return 0 end
	local myHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not myHRP then return 0 end
	local nearestDist = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and IsKiller(player) then
			if player.Character then
				local hrp = player.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local dist = (myHRP.Position - hrp.Position).Magnitude
					if dist < nearestDist then
						nearestDist = dist
					end
				end
			end
		end
	end
	VDSettings.KillerDistance = nearestDist == math.huge and 0 or math.floor(nearestDist)
	return VDSettings.KillerDistance
end
local function DetectMyRole()
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		VDSettings.CurrentRole = "Spectator"
		return VDSettings.CurrentRole
	end
	local team = LocalPlayer.Team
	if not team then
		VDSettings.CurrentRole = "Spectator"
		return VDSettings.CurrentRole
	end
	local teamName = team.Name:lower()
	if teamName:find("spectator") or teamName:find("lobby") or teamName:find("waiting") then
		VDSettings.CurrentRole = "Spectator"
		return VDSettings.CurrentRole
	end
	if IsKiller(LocalPlayer) then
		VDSettings.CurrentRole = "Killer"
	else
		if teamName:find("survivor") or teamName:find("player") then
			VDSettings.CurrentRole = "Survivor"
		else
			VDSettings.CurrentRole = "Survivor"
		end
	end
	return VDSettings.CurrentRole
end
local function TeleportToRandomGenerator()
	local gens = CollectGenerators()
	if #gens > 0 then
		local randomGen = gens[math.random(1, #gens)]
		local targetPos
		if randomGen:IsA("Model") then
			local primary = randomGen.PrimaryPart or randomGen:FindFirstChildWhichIsA("BasePart")
			if primary then targetPos = primary.Position + Vector3.new(0, 5, 0) end
		else
			targetPos = randomGen.Position + Vector3.new(0, 5, 0)
		end
		if targetPos and LocalPlayer.Character then
			local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.CFrame = CFrame.new(targetPos)
				Library:Notify('Teleported to Generator!', 2)
			end
		end
	else
		Library:Notify('No generators found!', 2)
	end
end
local function TeleportToRandomHook()
	local hooks = CollectHooks()
	if #hooks > 0 then
		local randomHook = hooks[math.random(1, #hooks)]
		local targetPos
		if randomHook:IsA("Model") then
			local primary = randomHook.PrimaryPart or randomHook:FindFirstChildWhichIsA("BasePart")
			if primary then targetPos = primary.Position + Vector3.new(0, 5, 0) end
		else
			targetPos = randomHook.Position + Vector3.new(0, 5, 0)
		end
		if targetPos and LocalPlayer.Character then
			local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.CFrame = CFrame.new(targetPos)
				Library:Notify('Teleported to Hook!', 2)
			end
		end
	else
		Library:Notify('No hooks found!', 2)
	end
end
local function CalculateBox(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil, nil, false end
	local camera = workspace.CurrentCamera
	local pos, onScreen = camera:WorldToViewportPoint(hrp.Position)
	if not onScreen then return nil, nil, false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hipHeight = humanoid and humanoid.HipHeight or 2
	local top = camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3 + hipHeight, 0))
	local bottom = camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
	local height = math.abs(top.Y - bottom.Y)
	local width = height / 2
	local boxPosition = Vector2.new(pos.X - width / 2, top.Y)
	local boxSize = Vector2.new(width, height)
	return boxPosition, boxSize, true
end
local DrawingAvailable, DrawingConstructor = pcall(function()
return Drawing and Drawing.new
end)
if DrawingAvailable and type(DrawingConstructor) == "function" then
	DrawingAvailable = true
else
	DrawingAvailable = false
	warn("[Starship] Drawing API not available - ESP may not work")
end
local ContentProvider = game:GetService("ContentProvider")
local PreloadedAssets = {}
local function PreloadAsset(assetUrl)
	if PreloadedAssets[assetUrl] then return true end
	local success = pcall(function()
	ContentProvider:PreloadAsync({ assetUrl })
end)
if success then
	PreloadedAssets[assetUrl] = true
	print("[Preload] Successfully preloaded: " .. assetUrl)
else
	print("[Preload] Failed to preload: " .. assetUrl)
end
return success
end
local function SafeDrawingNew(kind)
	if not DrawingAvailable then return nil end
	local success, result = pcall(function()
	return Drawing.new(kind)
end)
if success and result then
	return result
end
return nil
end
local function CreateESP(player)
	if not DrawingAvailable then return end
	if player == LocalPlayer then return end
	if ESPObjects[player] then return end
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local success, result = pcall(function()
	local espObj = {}
	espObj.Name = Drawing.new("Text")
	espObj.Name.Visible = false
	espObj.Name.Center = true
	espObj.Name.Outline = true
	espObj.Name.Size = 14
	espObj.Name.Font = 2
	espObj.Name.Color = ESPSettings.NameColor
	espObj.Distance = Drawing.new("Text")
	espObj.Distance.Visible = false
	espObj.Distance.Center = true
	espObj.Distance.Outline = true
	espObj.Distance.Size = 13
	espObj.Distance.Font = 2
	espObj.Distance.Color = ESPSettings.DistanceColor
	espObj.BoxOutline = Drawing.new("Square")
	espObj.BoxOutline.Visible = false
	espObj.BoxOutline.Filled = false
	espObj.BoxOutline.Thickness = 3
	espObj.BoxOutline.Color = Color3.new(0, 0, 0)
	espObj.Box = Drawing.new("Square")
	espObj.Box.Visible = false
	espObj.Box.Filled = false
	espObj.Box.Thickness = 1
	espObj.Box.Color = ESPSettings.BoxColor
	espObj.BoxFilled = Drawing.new("Square")
	espObj.BoxFilled.Visible = false
	espObj.BoxFilled.Filled = true
	espObj.BoxFilled.Thickness = 1
	espObj.BoxFilled.Color = ESPSettings.FilledBoxColor
	espObj.BoxFilled.Transparency = 0.8
	espObj.HealthBarBG = Drawing.new("Square")
	espObj.HealthBarBG.Visible = false
	espObj.HealthBarBG.Filled = true
	espObj.HealthBarBG.Color = Color3.new(0, 0, 0)
	espObj.HealthBar = Drawing.new("Square")
	espObj.HealthBar.Visible = false
	espObj.HealthBar.Filled = true
	espObj.HealthBar.Color = ESPSettings.HealthBarColor
	espObj.Tracer = Drawing.new("Line")
	espObj.Tracer.Visible = false
	espObj.Tracer.Thickness = 1
	espObj.Tracer.Color = ESPSettings.TracerColor
	espObj.HeadTrajectory = Drawing.new("Line")
	espObj.HeadTrajectory.Visible = false
	espObj.HeadTrajectory.Thickness = 2
	espObj.HeadTrajectory.Color = ESPSettings.HeadTrajectoryColor
	espObj.RoleText = Drawing.new("Text")
	espObj.RoleText.Visible = false
	espObj.RoleText.Center = false
	espObj.RoleText.Outline = true
	espObj.RoleText.Size = 13
	espObj.RoleText.Font = 2
	espObj.RoleText.Color = Color3.fromRGB(255, 255, 255)
	espObj.PerkText = Drawing.new("Text")
	espObj.PerkText.Visible = false
	espObj.PerkText.Center = true
	espObj.PerkText.Outline = true
	espObj.PerkText.Size = 11
	espObj.PerkText.Font = 2
	espObj.PerkText.Color = ESPSettings.NameColor
	espObj.ItemText = Drawing.new("Text")
	espObj.ItemText.Visible = false
	espObj.ItemText.Center = false
	espObj.ItemText.Outline = true
	espObj.ItemText.Size = 12
	espObj.ItemText.Font = 2
	espObj.ItemText.Color = Color3.fromRGB(200, 200, 200)
	espObj.HeadDotOutline = Drawing.new("Circle")
	espObj.HeadDotOutline.Visible = false
	espObj.HeadDotOutline.Thickness = 3
	espObj.HeadDotOutline.NumSides = 30
	espObj.HeadDotOutline.Color = Color3.new(0, 0, 0)
	espObj.HeadDotOutline.Transparency = 1
	espObj.HeadDotOutline.Filled = false
	espObj.HeadDot = Drawing.new("Circle")
	espObj.HeadDot.Visible = false
	espObj.HeadDot.Thickness = 1
	espObj.HeadDot.NumSides = 30
	espObj.HeadDot.Color = ESPSettings.SkeletonColor
	espObj.HeadDot.Transparency = 1
	espObj.HeadDot.Filled = false
	espObj.Skeleton = {}
	for i = 1, 6 do
		local line = Drawing.new("Line")
		line.Visible = false
		line.Thickness = 1
		line.Color = ESPSettings.SkeletonColor
		line.Transparency = 1
		table.insert(espObj.Skeleton, line)
	end
	espObj.CachedCharacter = character
	espObj.CachedHRP = hrp
	espObj.CachedHumanoid = character:FindFirstChildOfClass("Humanoid")
	espObj.RenderCache = {
	IsKiller = false,
	RoleName = "Player",
	RoleColor = Color3.new(1, 1, 1),
	ItemName = "",
	StatusText = "",
	IsAlly = false,
	HeldItemAssetId = nil
	}
	pcall(function()
	espObj.PerkImage = SafeDrawingNew("Image")
	if espObj.PerkImage then
		espObj.PerkImage.Visible = false
		espObj.PerkImage.Position = Vector2.new(0, 0)
		espObj.PerkImage.Size = Vector2.new(32, 32)
		espObj.PerkImage.Transparency = 1
	end
end)
pcall(function()
if not _G.VDImageOverlay then
	_G.VDImageOverlay = Instance.new("ScreenGui")
	_G.VDImageOverlay.Name = "VDImageOverlay"
	_G.VDImageOverlay.ResetOnSpawn = false
	_G.VDImageOverlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	_G.VDImageOverlay.DisplayOrder = 999999
	_G.VDImageOverlay.IgnoreGuiInset = true
	_G.VDImageOverlay.Parent = game:GetService("CoreGui")
end
espObj.ItemImage = Instance.new("ImageLabel", _G.VDImageOverlay)
espObj.ItemImage.Name = "ItemImage_" .. player.Name
espObj.ItemImage.Size = UDim2.new(0, 32, 0, 32)
espObj.ItemImage.Position = UDim2.new(0, 0, 0, 0)
espObj.ItemImage.AnchorPoint = Vector2.new(0.5, 0.5)
espObj.ItemImage.BackgroundTransparency = 1
espObj.ItemImage.Visible = false
espObj.ItemImage.ZIndex = 10000
end)
espObj.Skeleton = {}
for i = 1, 10 do
	local line = Drawing.new("Line")
	line.Visible = false
	line.Thickness = 1
	line.Color = ESPSettings.SkeletonColor
	espObj.Skeleton[i] = line
end
return espObj
end)
if success and result then
	ESPObjects[player] = result
else
	warn("[Starship] Failed to create ESP for: " .. player.Name .. " Error: " .. tostring(result))
end
end
local function RemoveESP(player)
	local espObj = ESPObjects[player]
	if not espObj then return end
	pcall(function()
	if espObj.Name then espObj.Name:Remove() end
	if espObj.PerkText then espObj.PerkText:Remove() end
	if espObj.ItemText then espObj.ItemText:Remove() end
	if espObj.PerkImage then espObj.PerkImage:Remove() end
	if espObj.ItemImage then
		pcall(function() espObj.ItemImage:Destroy() end)
	end
	if espObj.Distance then espObj.Distance:Remove() end
	if espObj.Box then espObj.Box:Remove() end
	if espObj.BoxOutline then espObj.BoxOutline:Remove() end
	if espObj.BoxFilled then espObj.BoxFilled:Remove() end
	if espObj.HealthBar then espObj.HealthBar:Remove() end
	if espObj.HealthBarBG then espObj.HealthBarBG:Remove() end
	if espObj.Tracer then espObj.Tracer:Remove() end
	if espObj.HeadTrajectory then espObj.HeadTrajectory:Remove() end
	if espObj.RoleText then espObj.RoleText:Remove() end
	if espObj.HeadDotOutline then espObj.HeadDotOutline:Remove() end
	if espObj.HeadDot then espObj.HeadDot:Remove() end
	if espObj.Skeleton then
		for _, line in pairs(espObj.Skeleton) do
			line:Remove()
		end
	end
end)
ESPObjects[player] = nil
end
local function RefreshESPCacheValues()
	for player, espObj in pairs(ESPObjects) do
		local shouldProceed = true
		if not player or not player.Parent then
			if espObj.RenderCache then espObj.RenderCache.Valid = false end
			shouldProceed = false
		end
		if shouldProceed then
			if not espObj.RenderCache then
				espObj.RenderCache = {
				IsKiller = false,
				RoleName = "Player",
				RoleColor = Color3.new(1, 1, 1),
				ItemName = "",
				StatusText = "",
				ShowName = true,
				Valid = false
				}
			end
			local character = player.Character
			if character and character ~= espObj.CachedCharacter then
				espObj.CachedCharacter = character
				espObj.CachedHRP = character:FindFirstChild("HumanoidRootPart")
				espObj.CachedHumanoid = character:FindFirstChildOfClass("Humanoid")
			end
			if not espObj.CachedHRP or not espObj.CachedHumanoid or espObj.CachedHumanoid.Health <= 0 then
				espObj.RenderCache.Valid = false
				shouldProceed = false
			else
				espObj.RenderCache.Valid = true
			end
		end
		if shouldProceed then
			local cache = espObj.RenderCache
			local isKiller = IsKiller(player)
			cache.IsKiller = isKiller
			cache.RoleName = GetRoleName(player)
			cache.RoleColor = GetRoleColor(player)
			cache.StatusText = VDSettings.PlayerStatuses[player] or ""
			if VDSettings.ShowKillerName and cache.RoleName == "Killer" then
				local kName = GetKillerType(player)
				if not kName then
					kName = _G.HideUsernameEnabled and "Starship" or (player.Character and player.Character.Name or player.DisplayName)
				end
				cache.KillerName = kName
			else
				cache.KillerName = nil
			end
			local held = ItemCache[player] or ""
			cache.ItemName = held
			if held ~= "" then
				cache.ItemDisplay = GetItemDisplay(held)
				local asset = NormalizedLookupAsset(ItemImageAssets, held)
				if asset then
					cache.HeldItemAssetId = asset:match("(%d+)")
				else
					cache.HeldItemAssetId = nil
				end
			else
				cache.ItemDisplay = ""
				cache.HeldItemAssetId = nil
			end
		end
	end
end
GFS._htRayParams = RaycastParams.new()
GFS._htRayParams.FilterType = Enum.RaycastFilterType.Exclude
GFS._htRayParams.FilterDescendantsInstances = {}
local function UpdateESP()
	local Settings = {
	MaxDistance = ESPSettings.MaxDistance,
	TeamCheck = ESPSettings.TeamCheck,
	ShowName = ESPSettings.ShowName,
	NameColor = ESPSettings.NameColor,
	ShowItemImage = ESPSettings.ShowItemImage,
	ShowDistance = ESPSettings.ShowDistance,
	DistanceColor = ESPSettings.DistanceColor,
	BoxESP = ESPSettings.BoxESP,
	BoxColor = ESPSettings.BoxColor,
	FilledBox = ESPSettings.FilledBox,
	FilledBoxColor = ESPSettings.FilledBoxColor,
	FilledBoxTransparency = ESPSettings.FilledBoxTransparency,
	ShowHealth = ESPSettings.ShowHealth,
	ShowRoleText = VDSettings.ShowRoleText,
	ShowStatus = VDSettings.ShowStatus,
	ShowItems = ESPSettings.ShowItems,
	TracerESP = ESPSettings.TracerESP,
	TracerColor = ESPSettings.TracerColor,
	KillerTracerColor = ESPSettings.KillerTracerColor or Color3.fromRGB(255, 80, 80),
	SurvivorTracerColor = ESPSettings.SurvivorTracerColor or Color3.fromRGB(80, 220, 120),
	HeadTrajectoryESP = ESPSettings.HeadTrajectoryESP,
	HeadTrajectoryColor = ESPSettings.HeadTrajectoryColor,
	SkeletonESP = ESPSettings.SkeletonESP,
	SkeletonColor = ESPSettings.SkeletonColor
	}
	local camera = workspace.CurrentCamera
	local viewportSize = camera.ViewportSize
	local myPos = Camera.CFrame and Camera.CFrame.Position or camera.CFrame.Position
	for player, espObj in pairs(ESPObjects) do
		local cache = espObj.RenderCache
		if not cache or not cache.Valid or not espObj.CachedHRP or not espObj.CachedHumanoid then
			if espObj.Name.Visible then espObj.Name.Visible = false end
			if espObj.Box.Visible then espObj.Box.Visible = false end
			if espObj.BoxOutline.Visible then espObj.BoxOutline.Visible = false end
			if espObj.BoxFilled.Visible then espObj.BoxFilled.Visible = false end
			if espObj.Distance.Visible then espObj.Distance.Visible = false end
			if espObj.HealthBar.Visible then espObj.HealthBar.Visible = false end
			if espObj.HealthBarBG.Visible then espObj.HealthBarBG.Visible = false end
			if espObj.Tracer.Visible then espObj.Tracer.Visible = false end
			if espObj.RoleText.Visible then espObj.RoleText.Visible = false end
			if espObj.ItemText.Visible then espObj.ItemText.Visible = false end
			if espObj.ItemImage and espObj.ItemImage.Visible then espObj.ItemImage.Visible = false end
		else
			local hrp = espObj.CachedHRP or (player.Character and player.Character:FindFirstChild("HumanoidRootPart"))
			if hrp then
				local pos, onScreen = camera:WorldToViewportPoint(hrp.Position)
				local distance = (hrp.Position - myPos).Magnitude
				local shouldShow = false
				if onScreen and distance <= Settings.MaxDistance then
					if Settings.TeamCheck then
						if cache.IsKiller then shouldShow = true else shouldShow = false end
					else
						shouldShow = true
					end
				end
				if shouldShow then
					local hipHeight = espObj.CachedHumanoid and espObj.CachedHumanoid.HipHeight or 2
					local worldPos = hrp.Position
					local topY = worldPos.Y + 3 + hipHeight
					local bottomY = worldPos.Y - 3
					local topVec, _ = camera:WorldToViewportPoint(Vector3.new(worldPos.X, topY, worldPos.Z))
					local bottomVec, _ = camera:WorldToViewportPoint(Vector3.new(worldPos.X, bottomY, worldPos.Z))
					local height = math.abs(topVec.Y - bottomVec.Y)
					local width = height * 0.5
					local boxPos = Vector2.new(pos.X - width / 2, topVec.Y)
					local boxSize = Vector2.new(width, height)
					if Settings.BoxESP then
						espObj.BoxOutline.Visible = true
						espObj.BoxOutline.Position = boxPos
						espObj.BoxOutline.Size = boxSize
						espObj.Box.Visible = true
						espObj.Box.Position = boxPos
						espObj.Box.Size = boxSize
						espObj.Box.Color = Settings.BoxColor
						if Settings.FilledBox then
							espObj.BoxFilled.Visible = true
							espObj.BoxFilled.Position = boxPos
							espObj.BoxFilled.Size = boxSize
							espObj.BoxFilled.Color = Settings.FilledBoxColor
							espObj.BoxFilled.Transparency = Settings.FilledBoxTransparency
						else
							espObj.BoxFilled.Visible = false
						end
					else
						espObj.BoxOutline.Visible = false
						espObj.Box.Visible = false
						espObj.BoxFilled.Visible = false
					end
					if Settings.ShowName then
						espObj.Name.Visible = true
						espObj.Name.Position = Vector2.new(boxPos.X + width / 2, boxPos.Y - 16)
						if _G.HideUsernameEnabled then
							espObj.Name.Text = "Starship"
							if player == LocalPlayer then
								espObj.Name.Color = Color3.fromRGB(0, 255, 100)
							else
								espObj.Name.Color = Settings.NameColor
							end
						else
							espObj.Name.Text = player.DisplayName
							espObj.Name.Color = Settings.NameColor
						end
					else
						espObj.Name.Visible = false
					end
					if Settings.ShowDistance then
						espObj.Distance.Visible = true
						espObj.Distance.Position = Vector2.new(boxPos.X + width / 2, boxPos.Y + height + 2)
						espObj.Distance.Text = math.floor(distance) .. "m"
						espObj.Distance.Color = Settings.DistanceColor
					else
						espObj.Distance.Visible = false
					end
					if Settings.ShowHealth then
						local hum = espObj.CachedHumanoid
						if not hum or not hum.Parent then
							hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
							espObj.CachedHumanoid = hum
						end
						local health, maxHealth = 0, 100
						if hum then
							local ok, h, mh = pcall(function() return hum.Health, hum.MaxHealth end)
							if ok then
								health = h or 0
								maxHealth = mh or 100
							end
						end
						if not maxHealth or maxHealth <= 0 or maxHealth ~= maxHealth then maxHealth = 100 end
						if not health or health ~= health then health = 0 end
						local healthPercent = math.clamp(health / maxHealth, 0, 1)
						local barHeight = math.max(1, height * healthPercent)
						espObj.HealthBarBG.Visible = true
						espObj.HealthBarBG.Position = Vector2.new(boxPos.X - 6, boxPos.Y)
						espObj.HealthBarBG.Size = Vector2.new(4, height)
						espObj.HealthBar.Visible = true
						espObj.HealthBar.Position = Vector2.new(boxPos.X - 5, boxPos.Y + (height - barHeight))
						espObj.HealthBar.Size = Vector2.new(2, barHeight)
						espObj.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
					else
						espObj.HealthBarBG.Visible = false
						espObj.HealthBar.Visible = false
					end
					if Settings.ShowRoleText then
						espObj.RoleText.Visible = true
						espObj.RoleText.Position = Vector2.new(boxPos.X + width + 4, boxPos.Y)
						local text = cache.RoleName
						if Settings.ShowStatus and cache.StatusText ~= "" then
							text = text .. "\n[" .. cache.StatusText .. "]"
						end
						if cache.KillerName then
							text = text .. "\n" .. cache.KillerName
						end
						espObj.RoleText.Text = text
						espObj.RoleText.Color = cache.RoleColor
					else
						espObj.RoleText.Visible = false
					end
					if Settings.ShowItems and cache.ItemDisplay ~= "" then
						espObj.ItemText.Visible = true
						local offsetY = 0
						if Settings.ShowRoleText then
							local _, count = string.gsub(espObj.RoleText.Text or "", "\n", "")
							offsetY = (count + 1) * 14
						end
						espObj.ItemText.Position = Vector2.new(boxPos.X + width + 4, boxPos.Y + offsetY)
						espObj.ItemText.Text = cache.ItemDisplay
					else
						espObj.ItemText.Visible = false
					end
					if Settings.ShowItemImage and cache.HeldItemAssetId and espObj.ItemImage then
						local imgSize = 32
						if distance > 50 then
							local scale = math.clamp(1 - ((distance - 50) / 150), 0.6, 1)
							imgSize = 32 * scale
						end
						local centerX = boxPos.X + width / 2
						local baseY = boxPos.Y + height + 2
						local imageY
						if Settings.ShowDistance then
							imageY = baseY + 15 + (imgSize / 2)
						else
							imageY = baseY + (imgSize / 2)
						end
						espObj.ItemImage.Visible = true
						espObj.ItemImage.Image = "rbxassetid://" .. cache.HeldItemAssetId
						espObj.ItemImage.Size = UDim2.new(0, imgSize, 0, imgSize)
						espObj.ItemImage.Position = UDim2.new(0, centerX, 0, imageY)
					elseif espObj.ItemImage then
						espObj.ItemImage.Visible = false
					end
					if Settings.TracerESP then
						espObj.Tracer.Visible = true
						espObj.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
						espObj.Tracer.To = Vector2.new(boxPos.X + width / 2, boxPos.Y + height)
						espObj.Tracer.Color = cache.IsKiller and Settings.KillerTracerColor or Settings.SurvivorTracerColor
					else
						espObj.Tracer.Visible = false
					end
					do
						if Settings.HeadTrajectoryESP and cache.IsKiller and espObj.HeadTrajectory then
							local htHead = espObj.CachedCharacter and espObj.CachedCharacter:FindFirstChild("Head")
							if htHead then
								GFS._htRayParams.FilterDescendantsInstances = {espObj.CachedCharacter}
								local htHit = workspace:Raycast(htHead.Position, htHead.CFrame.LookVector * 200, GFS._htRayParams)
								local ep = htHit and htHit.Position or (htHead.Position + htHead.CFrame.LookVector * 200)
								local s, sV = camera:WorldToViewportPoint(htHead.Position)
								local e, eV = camera:WorldToViewportPoint(ep)
								if sV or eV then
									espObj.HeadTrajectory.From = Vector2.new(s.X, s.Y)
									espObj.HeadTrajectory.To = Vector2.new(e.X, e.Y)
									espObj.HeadTrajectory.Color = Settings.HeadTrajectoryColor
									espObj.HeadTrajectory.Visible = true
								else
									espObj.HeadTrajectory.Visible = false
								end
							else
								espObj.HeadTrajectory.Visible = false
							end
						elseif espObj.HeadTrajectory then
							espObj.HeadTrajectory.Visible = false
						end
					end
					local char = espObj.CachedCharacter
					local head = char and char:FindFirstChild("Head")
					if Settings.SkeletonESP and head then
						local headPos, headOnScreen = camera:WorldToViewportPoint(head.Position)
						if headOnScreen then
							local headTop = camera:WorldToViewportPoint((head.CFrame * CFrame.new(0, head.Size.Y / 2, 0))
							.Position)
							local headBottom = camera:WorldToViewportPoint((head.CFrame * CFrame.new(0, -head.Size.Y / 2, 0))
							.Position)
							local headRadius = math.abs((headTop - headBottom).Y) / 2
							espObj.HeadDotOutline.Visible = true
							espObj.HeadDotOutline.Position = Vector2.new(headPos.X, headPos.Y)
							espObj.HeadDotOutline.Radius = headRadius
							espObj.HeadDot.Visible = true
							espObj.HeadDot.Position = Vector2.new(headPos.X, headPos.Y)
							espObj.HeadDot.Radius = headRadius
							espObj.HeadDot.Color = Settings.SkeletonColor
						else
							espObj.HeadDotOutline.Visible = false
							espObj.HeadDot.Visible = false
						end
					else
						if espObj.HeadDotOutline then espObj.HeadDotOutline.Visible = false end
						if espObj.HeadDot then espObj.HeadDot.Visible = false end
					end
					if Settings.SkeletonESP and char then
						local torso = char:FindFirstChild('UpperTorso') or char:FindFirstChild('Torso')
						local leftArm = char:FindFirstChild('LeftUpperArm') or char:FindFirstChild('Left Arm')
						local rightArm = char:FindFirstChild('RightUpperArm') or char:FindFirstChild('Right Arm')
						local leftLeg = char:FindFirstChild('LeftUpperLeg') or char:FindFirstChild('Left Leg')
						local rightLeg = char:FindFirstChild('RightUpperLeg') or char:FindFirstChild('Right Leg')
						local parts = { head, torso, leftArm, rightArm, leftLeg, rightLeg }
						local validParts = true
						for _, part in pairs(parts) do
							if not part then
								validParts = false
								break
							end
						end
						if validParts then
							local connections = {
							{ head,    torso },
							{ torso,   leftArm },
							{ torso,   rightArm },
							{ torso,   leftLeg },
							{ torso,   rightLeg },
							{ leftLeg, rightLeg }
							}
							for i = 1, 6 do
								local from, to = connections[i][1], connections[i][2]
								local fromPos, fromOnScreen = camera:WorldToViewportPoint(from.Position)
								local toPos, toOnScreen = camera:WorldToViewportPoint(to.Position)
								if fromOnScreen and toOnScreen then
									espObj.Skeleton[i].Visible = true
									espObj.Skeleton[i].From = Vector2.new(fromPos.X, fromPos.Y)
									espObj.Skeleton[i].To = Vector2.new(toPos.X, toPos.Y)
									espObj.Skeleton[i].Color = Settings.SkeletonColor
								else
									espObj.Skeleton[i].Visible = false
								end
							end
						else
							for i = 1, 6 do
								if espObj.Skeleton[i] then espObj.Skeleton[i].Visible = false end
							end
						end
					else
						if espObj.Skeleton then
							for i = 1, 6 do
								if espObj.Skeleton[i] then espObj.Skeleton[i].Visible = false end
							end
						end
					end
				else
					if espObj.Name.Visible then espObj.Name.Visible = false end
					if espObj.Box.Visible then espObj.Box.Visible = false end
					if espObj.BoxOutline.Visible then espObj.BoxOutline.Visible = false end
					if espObj.BoxFilled.Visible then espObj.BoxFilled.Visible = false end
					if espObj.Distance.Visible then espObj.Distance.Visible = false end
					if espObj.HealthBar.Visible then espObj.HealthBar.Visible = false end
					if espObj.HealthBarBG.Visible then espObj.HealthBarBG.Visible = false end
					if espObj.Tracer.Visible then espObj.Tracer.Visible = false end
					if espObj.HeadTrajectory and espObj.HeadTrajectory.Visible then espObj.HeadTrajectory.Visible = false end
					if espObj.RoleText.Visible then espObj.RoleText.Visible = false end
					if espObj.ItemText.Visible then espObj.ItemText.Visible = false end
					if espObj.ItemImage and espObj.ItemImage.Visible then espObj.ItemImage.Visible = false end
					if espObj.HeadDotOutline and espObj.HeadDotOutline.Visible then espObj.HeadDotOutline.Visible = false end
					if espObj.HeadDot and espObj.HeadDot.Visible then espObj.HeadDot.Visible = false end
					if espObj.Skeleton then
						for _, line in pairs(espObj.Skeleton) do
							if line.Visible then line.Visible = false end
						end
					end
				end
			end
		end
	end
end
ESP_Logic.RemoveExitGateESPEntry = function(key)
local data = ESP_Storage.ExitGate.Objects[key]
if not data then return end
pcall(function()
if data.Billboard then
	data.Billboard:Destroy()
end
if data.Name then data.Name:Remove() end
if data.Distance then data.Distance:Remove() end
end)
ESP_Storage.ExitGate.Objects[key] = nil
end
ESP_Logic.ClearExitGateESP = function()
for key, _ in pairs(ESP_Storage.ExitGate.Objects) do
	ESP_Logic.RemoveExitGateESPEntry(key)
end
ESP_Storage.ExitGate.Enabled = false
end
local function GetUniqueObjectKey(obj, objType)
	local uniqueId
	if obj.GetDebugId then
		pcall(function()
		uniqueId = obj:GetDebugId()
	end)
end
if not uniqueId then
	uniqueId = obj:GetFullName()
end
return objType .. "_" .. uniqueId
end
ESP_Logic.UpdateExitGateESPColors = function()
for _, data in pairs(ESP_Storage.ExitGate.Objects) do
	if data.NameLabel then
		data.NameLabel.TextColor3 = ESPSettings.ExitGateESPNameColor or Color3.fromRGB(0, 255, 0)
	end
	if data.DistanceLabel then
		data.DistanceLabel.TextColor3 = ESPSettings.DistanceColor or Color3.fromRGB(180, 180, 180)
	end
	if data.Name then
		data.Name.Color = ESPSettings.ExitGateESPNameColor or Color3.fromRGB(0, 255, 0)
	end
	if data.Distance then
		data.Distance.Color = ESPSettings.DistanceColor or Color3.fromRGB(180, 180, 180)
	end
end
end
ESP_Logic.CreateExitGateESPVisual = function(obj)
if not obj then return end
local key = GetUniqueObjectKey(obj, "ExitGateESP")
if ESP_Storage.ExitGate.Objects[key] then return end
local function findAdornee(o)
	if not o then return nil end
	if o:IsA("BasePart") or o:IsA("MeshPart") then
		return o
	end
	if o:IsA("Model") then
		if o.PrimaryPart then return o.PrimaryPart end
		local part = o:FindFirstChildWhichIsA("BasePart", true)
		if part then return part end
		local mesh = o:FindFirstChildWhichIsA("MeshPart", true)
		if mesh then return mesh end
	end
	local anyPart = o:FindFirstChildWhichIsA("BasePart", true) or o:FindFirstChildWhichIsA("MeshPart", true)
	return anyPart
end
local adornee = findAdornee(obj)
if not adornee then
	return
end
local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
if not playerGui then
	return
end
local entry = { Object = obj, Adornee = adornee }
local bb = Instance.new("BillboardGui")
bb.Name = "Starship_ExitBillboard"
bb.Adornee = adornee
bb.Size = UDim2.new(0, 120, 0, 30)
bb.AlwaysOnTop = true
bb.StudsOffset = Vector3.new(0, 0.45, 0)
bb.Parent = playerGui
bb.Enabled = true
local nameLabel = Instance.new("TextLabel")
nameLabel.BackgroundTransparency = 1
nameLabel.Size = UDim2.new(1, 0, 0.65, 0)
nameLabel.Position = UDim2.new(0, 0, 0, 0)
nameLabel.Font = Enum.Font.SourceSans
nameLabel.TextSize = 14
nameLabel.TextStrokeTransparency = 0
nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
nameLabel.Text = "[exit]"
nameLabel.TextColor3 = ESPSettings.ExitGateESPNameColor or Color3.fromRGB(0, 255, 0)
nameLabel.TextXAlignment = Enum.TextXAlignment.Center
nameLabel.Parent = bb
local distLabel = Instance.new("TextLabel")
distLabel.BackgroundTransparency = 1
distLabel.Size = UDim2.new(1, 0, 0.35, 0)
distLabel.Position = UDim2.new(0, 0, 0.65, 0)
distLabel.Font = Enum.Font.SourceSans
distLabel.TextSize = 12
distLabel.TextStrokeTransparency = 0
distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
distLabel.Text = ""
distLabel.TextColor3 = ESPSettings.DistanceColor or Color3.fromRGB(180, 180, 180)
distLabel.TextXAlignment = Enum.TextXAlignment.Center
distLabel.Parent = bb
entry.Billboard = bb
entry.NameLabel = nameLabel
entry.DistanceLabel = distLabel
ESP_Storage.ExitGate.Objects[key] = entry
end
ESP_Logic.UpdateExitGateESP = function()
if not ESP_Storage.ExitGate.Enabled or not ESPSettings.ShowExitGateESP then
	return
end
local camera = workspace.CurrentCamera
if not camera then return end
local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
for key, data in pairs(ESP_Storage.ExitGate.Objects) do
	local obj = data.Object
	local adornee = data.Adornee
	if not obj or not obj.Parent or not adornee or not adornee.Parent then
		ESP_Logic.RemoveExitGateESPEntry(key)
	else
		local distance = 0
		if hrp and adornee then
			distance = (adornee.Position - hrp.Position).Magnitude
		end
		local inRange = distance <= (ESPSettings.ExitGateESPMaxDistance or 800)
		if data.Billboard and data.NameLabel and data.DistanceLabel then
			if inRange then
				data.Billboard.Enabled = true
				data.NameLabel.TextColor3 = ESPSettings.ExitGateESPNameColor or Color3.fromRGB(0, 255, 0)
				data.DistanceLabel.Text = math.floor(distance) .. "m"
				data.DistanceLabel.TextColor3 = ESPSettings.DistanceColor or Color3.fromRGB(180, 180, 180)
			else
				data.Billboard.Enabled = false
			end
		end
	end
end
end
ESP_Logic.HandleExitGateAdded = function(obj)
if not ESP_Storage.ExitGate.Enabled then return end
if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Model") then
	local nameLower = string.lower(obj.Name)
	local isBlacklisted = false
	if VDSettings.ExitGateBlacklist then
		for blackword, _ in pairs(VDSettings.ExitGateBlacklist) do
			if string.find(nameLower, blackword) then
				isBlacklisted = true
				break
			end
		end
	end
	if not isBlacklisted then
		local isMatch = false
		if VDSettings.ExitGateNames and VDSettings.ExitGateNames[nameLower] then
			isMatch = true
		elseif string.find(nameLower, "exit") and string.find(nameLower, "gate") then
			isMatch = true
		elseif string.find(nameLower, "exit") and string.find(nameLower, "lever") then
			isMatch = true
		elseif string.find(nameLower, "exit") and string.find(nameLower, "door") then
			isMatch = true
		end
		if isMatch then
			local target = GetBestHighlightTarget(obj)
			if target then
				ESP_Logic.CreateExitGateESPVisual(target)
			end
		end
	end
end
end
ESP_Logic.StartExitGateESPLoop = function()
if ESP_Storage.ExitGate.Connection then return end
local lastUpdate = 0
local updateInterval = 0.05
ESP_Storage.ExitGate.Connection = RunService.RenderStepped:Connect(function()
local now = tick()
if (now - lastUpdate) >= updateInterval then
	lastUpdate = now
	if type(ESP_Logic.UpdateExitGateESP) == "function" then
		pcall(ESP_Logic.UpdateExitGateESP)
	end
end
end)
task.spawn(function()
local descs = workspace:GetDescendants()
for _, obj in ipairs(descs) do
	ESP_Logic.HandleExitGateAdded(obj)
end
end)
if ESP_Storage.ExitGate.AddedConnection then ESP_Storage.ExitGate.AddedConnection:Disconnect() end
ESP_Storage.ExitGate.AddedConnection = workspace.DescendantAdded:Connect(function(obj)
task.defer(function() ESP_Logic.HandleExitGateAdded(obj) end)
end)
end
ESP_Logic.StopExitGateESPLoop = function()
if ESP_Storage.ExitGate.Connection then
	ESP_Storage.ExitGate.Connection:Disconnect()
	ESP_Storage.ExitGate.Connection = nil
end
if ESP_Storage.ExitGate.AddedConnection then
	ESP_Storage.ExitGate.AddedConnection:Disconnect()
	ESP_Storage.ExitGate.AddedConnection = nil
end
end
ESP_Logic.GetExitGateScreenBounds = function(obj, camera)
if not obj or not camera then return nil end
local cframe, size
if obj:IsA("Model") then
	local ok
	ok, cframe, size = pcall(function()
	return obj:GetBoundingBox()
end)
if not ok or not cframe or not size then
	return nil
end
elseif obj:IsA("BasePart") or obj:IsA("MeshPart") then
	cframe = obj.CFrame
	size = obj.Size
elseif obj:IsA("Folder") then
	local model = obj:FindFirstChildWhichIsA("Model")
	if model then
		local ok
		ok, cframe, size = pcall(function() return model:GetBoundingBox() end)
		if not ok then cframe = nil end
	end
	if not cframe then
		local part = obj:FindFirstChildWhichIsA("MeshPart", true) or obj:FindFirstChildWhichIsA("BasePart", true)
		if part then
			cframe = part.CFrame
			size = part.Size
		else
			return nil
		end
	end
else
	return nil
end
size = Vector3.new(math.max(size.X, 0.5), math.max(size.Y, 0.5), math.max(size.Z, 0.5))
local half = size * 0.5
local minX, minY, maxX, maxY
local visible = false
for _, offset in ipairs({
Vector3.new(-half.X, -half.Y, -half.Z),
Vector3.new(-half.X, -half.Y, half.Z),
Vector3.new(-half.X, half.Y, -half.Z),
Vector3.new(-half.X, half.Y, half.Z),
Vector3.new(half.X, -half.Y, -half.Z),
Vector3.new(half.X, -half.Y, half.Z),
Vector3.new(half.X, half.Y, -half.Z),
Vector3.new(half.X, half.Y, half.Z)
}) do
	local worldPoint = cframe * offset
	local screenPoint = camera:WorldToViewportPoint(worldPoint)
	if screenPoint.Z > 0 then
		visible = true
		minX = minX and math.min(minX, screenPoint.X) or screenPoint.X
		minY = minY and math.min(minY, screenPoint.Y) or screenPoint.Y
		maxX = maxX and math.max(maxX, screenPoint.X) or screenPoint.X
		maxY = maxY and math.max(maxY, screenPoint.Y) or screenPoint.Y
	end
end
if not visible or not minX then return nil end
return {
MinX = minX,
MinY = minY,
MaxX = maxX,
MaxY = maxY,
Position = cframe.Position,
Visible = visible
}
end
ESP_Logic.RefreshExitGateESP = function()
ESP_Logic.ClearExitGateESP()
if not ESPSettings.ShowExitGateESP then
	return
end
local exits = CollectExitGates()
for _, exit in ipairs(exits) do
	ESP_Logic.CreateExitGateESPVisual(exit)
end
ESP_Storage.ExitGate.Enabled = true
end
ESP_Logic.RemoveVaultESPEntry = function(key)
local data = ESP_Storage.Vault.Objects[key]
if not data then
	return
end
pcall(function()
if data.Billboard then
	data.Billboard:Destroy()
end
if data.Name then
	data.Name:Remove()
end
if data.Distance then
	data.Distance:Remove()
end
end)
ESP_Storage.Vault.Objects[key] = nil
end
ESP_Logic.ClearVaultESP = function()
for key, _ in pairs(ESP_Storage.Vault.Objects) do
	ESP_Logic.RemoveVaultESPEntry(key)
end
ESP_Storage.Vault.Enabled = false
end
ESP_Logic.GetVaultScreenBounds = function(obj, camera)
if not obj or not camera then return nil end
local cframe, size
if obj:IsA("Model") then
	local ok
	ok, cframe, size = pcall(function()
	return obj:GetBoundingBox()
end)
if not ok or not cframe or not size then
	return nil
end
elseif obj:IsA("BasePart") or obj:IsA("MeshPart") then
	cframe = obj.CFrame
	size = obj.Size
else
	return nil
end
size = Vector3.new(math.max(size.X, 0.5), math.max(size.Y, 0.5), math.max(size.Z, 0.5))
local half = size * 0.5
local minX, minY, maxX, maxY
local visible = false
for _, offset in ipairs({
Vector3.new(-half.X, -half.Y, -half.Z),
Vector3.new(-half.X, -half.Y, half.Z),
Vector3.new(-half.X, half.Y, -half.Z),
Vector3.new(-half.X, half.Y, half.Z),
Vector3.new(half.X, -half.Y, -half.Z),
Vector3.new(half.X, -half.Y, half.Z),
Vector3.new(half.X, half.Y, -half.Z),
Vector3.new(half.X, half.Y, half.Z)
}) do
	local worldPoint = cframe * offset
	local screenPoint = camera:WorldToViewportPoint(worldPoint)
	if screenPoint.Z > 0 then
		visible = true
		minX = minX and math.min(minX, screenPoint.X) or screenPoint.X
		minY = minY and math.min(minY, screenPoint.Y) or screenPoint.Y
		maxX = maxX and math.max(maxX, screenPoint.X) or screenPoint.X
		maxY = maxY and math.max(maxY, screenPoint.Y) or screenPoint.Y
	end
end
if not visible or not minX then return nil end
return {
MinX = minX,
MinY = minY,
MaxX = maxX,
MaxY = maxY,
Position = cframe.Position,
Visible = visible
}
end
ESP_Logic.CreateVaultESPVisual = function(obj)
if not obj then return end
local key = GetUniqueObjectKey(obj, "VaultESP")
if ESP_Storage.Vault.Objects[key] then return end
local entry = { Object = obj }
local function findAdornee(o)
	local target = GetHighlightTarget(o)
	if target and target:IsA("BasePart") then return target end
	if target and target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	return o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart", true)
end
local adornee = findAdornee(obj)
local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
if playerGui and adornee then
	local bb = Instance.new("BillboardGui")
	bb.Name = "Starship_VaultBillboard"
	bb.Adornee = adornee
	bb.Size = UDim2.new(0, 120, 0, 30)
	bb.AlwaysOnTop = true
	bb.StudsOffset = Vector3.new(0, 0.45, 0)
	bb.Parent = playerGui
	bb.Enabled = false
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0.65, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.Font = Enum.Font.SourceSans
	nameLabel.TextSize = 14
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.Text = "[vault]"
	nameLabel.TextColor3 = VDSettings.VaultColor or Color3.fromRGB(0, 255, 255)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.Parent = bb
	local distLabel = Instance.new("TextLabel")
	distLabel.BackgroundTransparency = 1
	distLabel.Size = UDim2.new(1, 0, 0.35, 0)
	distLabel.Position = UDim2.new(0, 0, 0.65, 0)
	distLabel.Font = Enum.Font.SourceSans
	distLabel.TextSize = 12
	distLabel.TextStrokeTransparency = 0
	distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	distLabel.Text = ""
	distLabel.TextColor3 = ESPSettings.DistanceColor or Color3.fromRGB(180, 180, 180)
	distLabel.TextXAlignment = Enum.TextXAlignment.Center
	distLabel.Parent = bb
	entry.Billboard = bb
	entry.NameLabel = nameLabel
	entry.DistanceLabel = distLabel
	entry.Adornee = adornee
else
	if not DrawingAvailable then return end
	local nameText = SafeDrawingNew("Text")
	if not nameText then return end
	local distanceText = SafeDrawingNew("Text")
	entry.Name = nameText
	entry.Distance = distanceText
	entry.Name.Center = true
	entry.Name.Outline = true
	entry.Name.Size = 14
	entry.Name.Font = 2
	entry.Name.Color = VDSettings.VaultColor
	entry.Name.Text = "Vault"
	entry.Name.Visible = false
	if entry.Distance then
		entry.Distance.Center = true
		entry.Distance.Outline = true
		entry.Distance.Size = 13
		entry.Distance.Font = 2
		entry.Distance.Color = VDSettings.VaultColor
		entry.Distance.Visible = false
	end
end
ESP_Storage.Vault.Objects[key] = entry
end
ESP_Logic.UpdateVaultESP = function()
if not ESP_Storage.Vault.Enabled or not VDSettings.ShowVaultsESP then
	return
end
local camera = workspace.CurrentCamera
if not camera then return end
local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
for key, data in pairs(ESP_Storage.Vault.Objects) do
	local obj = data.Object
	if not obj or not obj.Parent then
		ESP_Logic.RemoveVaultESPEntry(key)
	else
		local bounds = ESP_Logic.GetVaultScreenBounds(obj, camera)
		if not bounds then
			if data.Name then data.Name.Visible = false end
			if data.Distance then data.Distance.Visible = false end
		else
			local distance = math.huge
			if hrp then
				distance = (bounds.Position - hrp.Position).Magnitude
			end
			local inRange = distance <= VDSettings.VaultMaxDistance
			local visible = bounds.Visible and inRange
			if visible then
				if data.Billboard and data.NameLabel and data.DistanceLabel then
					data.Billboard.Enabled = true
					data.Billboard.StudsOffset = Vector3.new(0, 0.45, 0)
					data.NameLabel.Font = Enum.Font.SourceSans
					data.NameLabel.TextSize = 14
					data.NameLabel.TextStrokeTransparency = 0
					data.NameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
					data.NameLabel.Text = "[vault]"
					data.NameLabel.TextColor3 = VDSettings.VaultColor or Color3.fromRGB(0, 255, 255)
					data.NameLabel.TextXAlignment = Enum.TextXAlignment.Center
					data.DistanceLabel.Font = Enum.Font.SourceSans
					data.DistanceLabel.TextSize = 12
					data.DistanceLabel.TextStrokeTransparency = 0
					data.DistanceLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
					data.DistanceLabel.Text = math.floor(distance) .. "m"
					data.DistanceLabel.TextColor3 = ESPSettings.DistanceColor or Color3.fromRGB(180, 180, 180)
					data.DistanceLabel.TextXAlignment = Enum.TextXAlignment.Center
				else
					local centerX = (bounds.MinX + bounds.MaxX) / 2
					local centerY = (bounds.MinY + bounds.MaxY) / 2
					if data.Name then
						data.Name.Position = Vector2.new(centerX, centerY - 14)
						data.Name.Text = "[vault]"
						data.Name.Color = VDSettings.VaultColor or Color3.fromRGB(0, 255, 255)
						data.Name.Visible = true
					end
					if data.Distance then
						data.Distance.Position = Vector2.new(centerX, centerY + 6)
						data.Distance.Text = math.floor(distance) .. "m"
						data.Distance.Color = ESPSettings.DistanceColor or Color3.fromRGB(180, 180, 180)
						data.Distance.Visible = true
					end
				end
			else
				if data.Billboard then
					data.Billboard.Enabled = false
				end
				if data.Name then data.Name.Visible = false end
				if data.Distance then data.Distance.Visible = false end
			end
		end
	end
end
end
ESP_Logic.RefreshVaultESP = function()
ESP_Logic.ClearVaultESP()
if not DrawingAvailable or not VDSettings.ShowVaultsESP then
	return
end
local vaults = CollectVaults()
for _, vault in ipairs(vaults) do
	ESP_Logic.CreateVaultESPVisual(vault)
end
ESP_Storage.Vault.Enabled = true
end
ESP_Logic.HandleVaultAdded = function(obj)
if not ESP_Storage.Vault.Enabled then return end
if obj:IsA("BasePart") or obj:IsA("MeshPart") then
	local n = string.lower(obj.Name)
	if string.find(n, "vaulttrigger") or (string.find(n, "trigger") and string.find(n, "window")) then
		local parent = obj.Parent
		if parent then
			local pn = string.lower(parent.Name)
			if string.find(pn, "window") or string.find(pn, "vault") then
				local function isValidVault(o)
					if not o then return false end
					local p = string.lower(o:GetFullName())
					if string.find(p, "lobby") or string.find(p, "waiting") or string.find(p, "intermission") then return false end
					return true
				end
				if isValidVault(parent) then
					ESP_Logic.CreateVaultESPVisual(parent)
				end
			end
		end
	end
end
end
ESP_Logic.StartVaultESPLoop = function()
if ESP_Storage.Vault.Connection then return end
local lastUpdate = 0
local updateInterval = 0.05
ESP_Storage.Vault.Connection = RunService.RenderStepped:Connect(function()
local now = tick()
if (now - lastUpdate) >= updateInterval then
	lastUpdate = now
	if type(ESP_Logic.UpdateVaultESP) == "function" then
		pcall(ESP_Logic.UpdateVaultESP)
	end
end
end)
task.spawn(function()
local descs = workspace:GetDescendants()
for _, obj in ipairs(descs) do
	ESP_Logic.HandleVaultAdded(obj)
end
end)
if ESP_Storage.Vault.AddedConnection then ESP_Storage.Vault.AddedConnection:Disconnect() end
ESP_Storage.Vault.AddedConnection = workspace.DescendantAdded:Connect(function(obj)
task.defer(function() ESP_Logic.HandleVaultAdded(obj) end)
end)
end
ESP_Logic.StopVaultESPLoop = function()
if ESP_Storage.Vault.Connection then
	ESP_Storage.Vault.Connection:Disconnect()
	ESP_Storage.Vault.Connection = nil
end
if ESP_Storage.Vault.AddedConnection then
	ESP_Storage.Vault.AddedConnection:Disconnect()
	ESP_Storage.Vault.AddedConnection = nil
end
end
local VaultAutoAddedConn, VaultAutoRemovedConn
local VaultAutoScheduled = false
local PalletAutoAddedConn, PalletAutoRemovedConn
local PalletAutoScheduled = false
local function StopPalletAutoWatcher()
	if PalletAutoAddedConn then
		PalletAutoAddedConn:Disconnect(); PalletAutoAddedConn = nil
	end
	if PalletAutoRemovedConn then
		PalletAutoRemovedConn:Disconnect(); PalletAutoRemovedConn = nil
	end
	PalletAutoScheduled = false
	DebugPrint('[PalletAutoWatcher] Stopped')
end
local function StartPalletAutoWatcher()
	if PalletAutoAddedConn then return end
	local function isPalletObject(obj)
		if not obj then return false end
		if not (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart")) then return false end
		local nameLower = string.lower(obj.Name)
		if VDSettings.PalletNames[nameLower] then return true end
		if string.find(nameLower, "pallet") then return true end
		return false
	end
	PalletAutoAddedConn = workspace.DescendantAdded:Connect(function(desc)
	if not (ChamsEnabled and VDSettings.ShowPallets) then return end
	if not isPalletObject(desc) then return end
	task.delay(0.1, function()
	if ChamsEnabled and VDSettings.ShowPallets then
		local target = GetBestHighlightTarget(desc)
		if target then
			local key = GetUniqueObjectKey(target, "Pallet")
			local storage = VDESPObjects["Pallets"]
			if storage and not storage[key] then
				CreateObjectESP(target, "Pallet", VDSettings.PalletColor)
			end
		end
	end
end)
end)
PalletAutoRemovedConn = workspace.DescendantRemoving:Connect(function(desc)
if not (ChamsEnabled and VDSettings.ShowPallets) then return end
if not isPalletObject(desc) then return end
local target = GetBestHighlightTarget(desc)
if target then
	local key = GetUniqueObjectKey(target, "Pallet")
	local storage = VDESPObjects["Pallets"]
	if storage and storage[key] then
		local data = storage[key]
		if data.Highlight then
			pcall(function() data.Highlight:Destroy() end)
		end
		storage[key] = nil
	end
end
end)
DebugPrint('[PalletAutoWatcher] Started (optimized)')
end
local function StopVaultAutoWatcher()
	if VaultAutoAddedConn then
		VaultAutoAddedConn:Disconnect(); VaultAutoAddedConn = nil
	end
	if VaultAutoRemovedConn then
		VaultAutoRemovedConn:Disconnect(); VaultAutoRemovedConn = nil
	end
	VaultAutoScheduled = false
	DebugPrint('[VaultAutoWatcher] Stopped')
end
local function StartVaultAutoWatcher()
	DebugPrint('[VaultAutoWatcher] Disabled for performance')
end
local function ToggleESP(enabled)
	ESPEnabled = enabled
	if enabled then
		pcall(RefreshPerkData)
		pcall(RefreshItemData)
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				CreateESP(player)
			end
		end
		if not DynamicESPConnection then
			local lastPerkRefresh = 0
			local lastItemRefresh = 0
			local lastCacheRefresh = 0
			local lastPlayerScan = 0
			local playerScanInterval = 1
			local cacheRefreshInterval = 0.5
			DynamicESPConnection = RunService.RenderStepped:Connect(function()
			if ESPEnabled then
				local now = tick()
				if (now - lastPlayerScan) >= playerScanInterval then
					lastPlayerScan = now
					for _, player in ipairs(Players:GetPlayers()) do
						if player ~= LocalPlayer then
							if not ESPObjects[player] and player.Character then
								CreateESP(player)
							end
						end
					end
				end
				if (now - lastCacheRefresh) >= cacheRefreshInterval then
					lastCacheRefresh = now
					pcall(RefreshESPCacheValues)
				end
				if ESPSettings.ShowPerks and (now - lastPerkRefresh) >= 3 then
					lastPerkRefresh = now
					pcall(RefreshPerkData)
				end
				if ESPSettings.ShowItems and (now - lastItemRefresh) >= 3 then
					lastItemRefresh = now
					pcall(RefreshItemData)
				end
				UpdateESP()
			end
		end)
	end
	ESP_Logic.RefreshExitGateESP()
	if ESPSettings.ShowExitGateESP then
		ESP_Logic.StartExitGateESPLoop()
	end
	if VDSettings.ShowVaultsESP then
		ESP_Logic.RefreshVaultESP()
		ESP_Logic.StartVaultESPLoop()
		StartVaultAutoWatcher()
	else
		ESP_Logic.StopVaultESPLoop()
	end
	Library:Notify("ESP: Enabled", 2)
else
	for player, _ in pairs(ESPObjects) do
		RemoveESP(player)
	end
	if DynamicESPConnection then
		DynamicESPConnection:Disconnect()
		DynamicESPConnection = nil
	end
	ESP_Logic.StopVaultESPLoop()
	ESP_Logic.StopExitGateESPLoop()
	ESP_Logic.ClearExitGateESP()
	Library:Notify("ESP: Disabled", 2)
end
end
local function IsPlayerVisible(player)
	local character = player.Character
	if not character then return false end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local direction = (hrp.Position - origin)
	local distance = direction.Magnitude
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { LocalPlayer.Character, character }
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	local result = workspace:Raycast(origin, direction, rayParams)
	return result == nil or result.Distance >= distance - 1
end
local function RemoveChams(player)
	local highlight = ChamsObjects[player]
	if highlight then
		highlight:Destroy()
		ChamsObjects[player] = nil
	end
end
local function CreateChams(player, forceRefresh)
	if player == LocalPlayer then return end
	if forceRefresh and ChamsObjects[player] then
		if type(RemoveChams) == "function" then
			RemoveChams(player)
		else
			local oldHl = ChamsObjects[player]
			if oldHl then oldHl:Destroy() end
			ChamsObjects[player] = nil
		end
	end
	if ChamsObjects[player] then return end
	local character = player.Character
	if not character then return end
	local isKiller = IsKiller(player)
	local teamName = player.Team and player.Team.Name or "NO_TEAM"
	DebugPrint("Creating Chams for " .. player.Name .. " | Team: " .. teamName .. " | IsKiller: " .. tostring(isKiller))
	local roleColor, transparency, outlineColor, outlineEnabled
	if VDSettings.UseRoleChams then
		if isKiller then
			roleColor = VDSettings.KillerColor
			transparency = VDSettings.KillerTransparency
			outlineColor = VDSettings.KillerOutlineColor
			outlineEnabled = VDSettings.KillerOutlineEnabled
		else
			roleColor = VDSettings.SurvivorColor
			transparency = VDSettings.SurvivorTransparency
			outlineColor = VDSettings.SurvivorOutlineColor
			outlineEnabled = VDSettings.SurvivorOutlineEnabled
		end
	else
		roleColor = ESPSettings.ChamsColor
		transparency = ESPSettings.ChamsTransparency
		outlineColor = ESPSettings.ChamsOutlineColor
		outlineEnabled = ESPSettings.ChamsOutline
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "Starship_Chams"
	highlight.FillColor = roleColor
	highlight.FillTransparency = transparency
	highlight.OutlineColor = outlineColor
	highlight.OutlineTransparency = outlineEnabled and 0 or 1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = character
	ChamsObjects[player] = highlight
end
local function UpdateChams()
	local maxDist = ESPSettings.ChamsMaxDistance
	local useRoleChams = VDSettings.UseRoleChams
	local killerColor = VDSettings.KillerColor
	local killerTrans = VDSettings.KillerTransparency
	local killerOutColor = VDSettings.KillerOutlineColor
	local killerOutEnabled = VDSettings.KillerOutlineEnabled
	local killerOutTrans = VDSettings.KillerOutlineTransparency
	local survColor = VDSettings.SurvivorColor
	local survTrans = VDSettings.SurvivorTransparency
	local survOutColor = VDSettings.SurvivorOutlineColor
	local survOutEnabled = VDSettings.SurvivorOutlineEnabled
	local survOutTrans = VDSettings.SurvivorOutlineTransparency
	local defColor = ESPSettings.ChamsColor
	local defTrans = ESPSettings.ChamsTransparency
	local defOutColor = ESPSettings.ChamsOutlineColor
	local defOutEnabled = ESPSettings.ChamsOutline
	local camera = workspace.CurrentCamera
	local camPos = camera.CFrame.Position
	for player, highlight in pairs(ChamsObjects) do
		if highlight and highlight.Parent then
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local distance = (hrp.Position - camPos).Magnitude
				local inRange = distance <= maxDist
				local isKiller = IsKiller(player)
				local roleEnabled = true
				if useRoleChams then
					if isKiller then
						roleEnabled = killerOutEnabled
					else
						roleEnabled = survOutEnabled
					end
				end
				local shouldBeEnabled = inRange and roleEnabled
				if highlight.Enabled ~= shouldBeEnabled then
					highlight.Enabled = shouldBeEnabled
				end
				if shouldBeEnabled then
					local tColor, tTrans, tOutColor, tOutTrans, tDepth
					if useRoleChams then
						if isKiller then
							tColor = killerColor
							tTrans = killerTrans
							tOutColor = killerOutColor
							tOutTrans = killerOutTrans or 0
						else
							tColor = survColor
							tTrans = survTrans
							tOutColor = survOutColor
							tOutTrans = survOutTrans or 0
						end
					else
						tColor = defColor
						tTrans = defTrans
						tOutColor = defOutColor
						tOutTrans = defOutEnabled and 0 or 1
					end
					tDepth = ESPSettings.ChamsVisibleOnly and Enum.HighlightDepthMode.Occluded or
					Enum.HighlightDepthMode.AlwaysOnTop
					if highlight.FillColor ~= tColor then highlight.FillColor = tColor end
					if highlight.FillTransparency ~= tTrans then highlight.FillTransparency = tTrans end
					if highlight.OutlineColor ~= tOutColor then highlight.OutlineColor = tOutColor end
					if highlight.OutlineTransparency ~= tOutTrans then highlight.OutlineTransparency = tOutTrans end
					if highlight.DepthMode ~= tDepth then highlight.DepthMode = tDepth end
				end
			elseif highlight.Enabled then
				highlight.Enabled = false
			end
		else
			ChamsObjects[player] = nil
		end
	end
end
local ObjectChamsConnection = nil
local ObjectChamsAddedConn = nil
local ObjectChamsRemovedConn = nil
local ObjectChamsInitialized = false
local function GetObjectType(obj)
	if not obj or not obj.Parent then return nil end
	local nameLower = string.lower(obj.Name)
	if VDSettings.GeneratorNames[nameLower] or string.find(nameLower, "generator") then
		return "Generator"
	end
	if obj:GetAttribute("RepairProgress") ~= nil then
		return "Generator"
	end
	if VDSettings.HookNames[nameLower] or string.find(nameLower, "meat_hook") or string.find(nameLower, "meathook") or nameLower == "hook" then
		return "Hook"
	end
	if obj:GetAttribute("IsHook") or obj:GetAttribute("HookPoint") then
		return "Hook"
	end
	local isBlacklisted = false
	for blackword, _ in pairs(VDSettings.ExitGateBlacklist or {}) do
		if string.find(nameLower, blackword) then
			isBlacklisted = true
			break
		end
	end
	if not isBlacklisted then
		if VDSettings.ExitGateNames[nameLower] then
			return "ExitGate"
		end
		if (string.find(nameLower, "exit") and string.find(nameLower, "gate")) or
		(string.find(nameLower, "exit") and string.find(nameLower, "lever")) or
		(string.find(nameLower, "exit") and string.find(nameLower, "door")) then
			return "ExitGate"
		end
		if obj:GetAttribute("IsExit") or obj:GetAttribute("ExitGate") or obj:GetAttribute("IsExitGate") then
			return "ExitGate"
		end
	end
	if obj:IsA("Model") then
		if VDSettings.PalletNames[nameLower] or nameLower == "palletwrong" then
			local parent = obj.Parent
			local parentName = parent and string.lower(parent.Name) or ""
			if parentName == "map" or parentName == "pallet" or parentName == "pallets" then
				return "Pallet"
			end
		end
	end
	if string.find(nameLower, "vaulttrigger") or (string.find(nameLower, "trigger") and string.find(nameLower, "window")) then
		local parent = obj.Parent
		if parent then
			local pName = string.lower(parent.Name)
			if string.find(pName, "window") or string.find(pName, "vault") then
				return "Vault"
			end
		end
	end
	return nil
end
local function HandleObjectAdded(obj)
	if not ChamsEnabled then return end
	if not (obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Model")) then return end
	local objType = GetObjectType(obj)
	if not objType then return end
	local typeEnabled = false
	if objType == "Generator" and VDSettings.ShowGenerators then
		typeEnabled = true
	elseif objType == "Hook" and VDSettings.ShowHooks then
		typeEnabled = true
	elseif objType == "ExitGate" and VDSettings.ShowExitGates then
		typeEnabled = true
	elseif objType == "Pallet" and VDSettings.ShowPallets then
		typeEnabled = true
	elseif objType == "Vault" and VDSettings.ShowVaults then
		typeEnabled = true
	end
	if not typeEnabled then return end
	local target = GetBestHighlightTarget(obj)
	if not target then return end
	local key = GetUniqueObjectKey(target, objType)
	local storageKey = objType .. "s"
	if objType == "ExitGate" then storageKey = "ExitGates" end
	local storage = VDESPObjects[storageKey]
	if storage and not storage[key] then
		local color = VDSettings[objType .. "Color"] or Color3.new(1, 1, 1)
		CreateObjectESP(target, objType, color)
	end
end
local function HandleObjectRemoved(obj)
	if not (obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Model")) then return end
	for _, storageKey in ipairs({ "Generators", "Hooks", "ExitGates", "Pallets", "Vaults" }) do
		local storage = VDESPObjects[storageKey]
		if storage then
			for key, data in pairs(storage) do
				if data.Object == obj or (data.Object and data.Object.Parent == nil) then
					if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
					if data.BillboardGui then pcall(function() data.BillboardGui:Destroy() end) end
					storage[key] = nil
				end
			end
		end
	end
end
local function DoInitialObjectScan()
	if ObjectChamsInitialized then return end
	ObjectChamsInitialized = true
	task.spawn(function()
	local descs = workspace:GetDescendants()
	for i, obj in ipairs(descs) do
		if i % 1500 == 0 then task.wait() end
		if not ChamsEnabled then break end
		HandleObjectAdded(obj)
	end
end)
end
local function StartObjectChamsLoop()
	if ObjectChamsConnection then return end
	local lastVisualUpdate = 0
	local visualUpdateInterval = 0.1
	DoInitialObjectScan()
	ObjectChamsAddedConn = workspace.DescendantAdded:Connect(function(obj)
	task.defer(function()
	HandleObjectAdded(obj)
end)
end)
ObjectChamsRemovedConn = workspace.DescendantRemoving:Connect(function(obj)
task.defer(function()
HandleObjectRemoved(obj)
end)
end)
ObjectChamsConnection = RunService.RenderStepped:Connect(function()
if not ChamsEnabled then return end
local anyObjectEnabled = VDSettings.ShowGenerators or VDSettings.ShowHooks or VDSettings.ShowExitGates or
VDSettings.ShowPallets or VDSettings.ShowVaults or VDSettings.ShowVaultsESP
if not anyObjectEnabled then return end
local now = tick()
if (now - lastVisualUpdate) >= visualUpdateInterval then
	lastVisualUpdate = now
	UpdateObjectESP()
	if VDSettings.ShowGenerators and VDSettings.ShowGeneratorProgress then
		UpdateGeneratorProgress()
	end
end
end)
end
local function StopObjectChamsLoop()
	if ObjectChamsConnection then
		ObjectChamsConnection:Disconnect()
		ObjectChamsConnection = nil
	end
	if ObjectChamsAddedConn then
		ObjectChamsAddedConn:Disconnect()
		ObjectChamsAddedConn = nil
	end
	if ObjectChamsRemovedConn then
		ObjectChamsRemovedConn:Disconnect()
		ObjectChamsRemovedConn = nil
	end
	ObjectChamsInitialized = false
end
task.spawn(function()
task.wait(1)
StartObjectChamsLoop()
end)
local function StartChamsObjectLoop()
	if ChamsObjectConnection then return end
	local lastCreationScan = 0
	local lastVisualUpdate = 0
	local creationInterval = 0.5
	local visualInterval = 0.06
	ChamsObjectConnection = RunService.RenderStepped:Connect(function()
	if not ChamsEnabled then return end
	local now = tick()
	if (now - lastCreationScan) >= creationInterval then
		lastCreationScan = now
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				if not ChamsObjects[player] and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					CreateChams(player)
				elseif ChamsObjects[player] then
					local hl = ChamsObjects[player]
					if not hl.Parent or hl.Adornee ~= player.Character then
						CreateChams(player, true)
					end
				end
			end
		end
	end
	if (now - lastVisualUpdate) >= visualInterval then
		lastVisualUpdate = now
		UpdateChams()
	end
end)
end
local function StopChamsObjectLoop()
	if ChamsObjectConnection then
		ChamsObjectConnection:Disconnect()
		ChamsObjectConnection = nil
	end
end
local function ToggleChams(enabled)
	ChamsEnabled = enabled
	if enabled then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				CreateChams(player)
			end
		end
		Library:Notify("Chams: Enabled", 2)
		StartChamsObjectLoop()
	else
		for player, _ in pairs(ChamsObjects) do
			RemoveChams(player)
		end
		StopChamsObjectLoop()
		Library:Notify("Chams: Disabled", 2)
	end
end
CreateObjectESP = function(obj, objType, color)
if not obj then
	DebugPrint("[CreateObjectESP] obj is nil")
	return
end
local key = GetUniqueObjectKey(obj, objType)
local storageKey = objType .. "s"
if not VDESPObjects[storageKey] then VDESPObjects[storageKey] = {} end
if VDESPObjects[storageKey][key] then
	DebugPrint("[CreateObjectESP] Already exists: " .. key)
	return
end
local targetPart = obj
local adornee = obj
local function FindBestVisual(container)
	local bestPart = nil
	local bestScore = 0
	for _, child in ipairs(container:GetDescendants()) do
		local score = 0
		if child:IsA("MeshPart") or child:IsA("UnionOperation") then
			score = 100
		elseif child:IsA("BasePart") then
			if child.Transparency < 1 and child.Name ~= "HumanoidRootPart" and not string.find(string.lower(child.Name), "trigger") then
				score = 50
			else
				score = 1
			end
		elseif child:IsA("Model") then
			score = 10
		end
		if score > bestScore then
			bestScore = score
			bestPart = child
		end
	end
	return bestPart
end
if obj:IsA("Model") then
	adornee = obj
	if obj.PrimaryPart then
		targetPart = obj.PrimaryPart
	else
		targetPart = FindBestVisual(obj) or obj:FindFirstChildWhichIsA("BasePart", true)
	end
elseif obj:IsA("Folder") then
	local model = obj:FindFirstChildWhichIsA("Model")
	if model then
		adornee = model
		targetPart = model.PrimaryPart or FindBestVisual(model) or model:FindFirstChildWhichIsA("BasePart", true)
	else
		local mesh = obj:FindFirstChildWhichIsA("MeshPart", true)
		if mesh then
			adornee = mesh
			targetPart = mesh
		else
			local best = FindBestVisual(obj)
			if best then
				targetPart = best
				adornee = best
			end
		end
	end
elseif obj:IsA("BasePart") then
	if obj.Transparency >= 1 or string.find(string.lower(obj.Name), "trigger") then
		if obj.Parent then
			if obj.Parent:IsA("Model") then
				adornee = obj.Parent
				targetPart = obj.Parent.PrimaryPart or FindBestVisual(obj.Parent) or obj
			else
				local sibling = FindBestVisual(obj.Parent)
				if sibling and sibling ~= obj then
					targetPart = sibling
					adornee = sibling
				end
			end
		end
	else
		targetPart = obj
		adornee = obj
	end
end
if not adornee then
	DebugPrint("[CreateObjectESP] No adornee for: " .. obj:GetFullName())
	return
end
DebugPrint("[CreateObjectESP] Creating for: " .. obj:GetFullName() .. " (" .. objType .. ")")
local transparency = 0.5
local outlineColor = color
local outlineTransparency = 0
local outlineEnabled = true
if objType == "Generator" then
	transparency = VDSettings.GeneratorTransparency
	outlineColor = VDSettings.GeneratorOutlineColor
	outlineTransparency = VDSettings.GeneratorOutlineTransparency
	outlineEnabled = VDSettings.GeneratorOutlineEnabled
elseif objType == "Hook" then
	transparency = VDSettings.HookTransparency
	outlineColor = VDSettings.HookOutlineColor
	outlineTransparency = VDSettings.HookOutlineTransparency
	outlineEnabled = VDSettings.HookOutlineEnabled
elseif objType == "ExitGate" then
	transparency = VDSettings.ExitGateTransparency
	outlineColor = VDSettings.ExitGateOutlineColor
	outlineTransparency = VDSettings.ExitGateOutlineTransparency
	outlineEnabled = VDSettings.ExitGateOutlineEnabled
elseif objType == "Vault" then
	transparency = VDSettings.VaultTransparency
	outlineColor = VDSettings.VaultOutlineColor
	outlineTransparency = VDSettings.VaultOutlineTransparency
	outlineEnabled = VDSettings.VaultOutlineEnabled
end
local highlight = Instance.new("Highlight")
highlight.Name = "Starship_" .. objType .. "Chams"
highlight.FillColor = color
highlight.FillTransparency = transparency
highlight.OutlineColor = outlineColor
highlight.OutlineTransparency = outlineEnabled and outlineTransparency or 1
if ESPSettings.ChamsVisibleOnly then
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
else
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end
highlight.Adornee = adornee
if adornee and adornee:IsDescendantOf(workspace) then
	highlight.Parent = adornee
else
	highlight.Parent = workspace
end
if objType == "Vault" then
	highlight.Enabled = (ChamsEnabled and VDSettings.ShowVaults)
elseif objType == "Generator" then
	highlight.Enabled = (ChamsEnabled and VDSettings.ShowGenerators)
elseif objType == "Hook" then
	highlight.Enabled = (ChamsEnabled and VDSettings.ShowHooks)
elseif objType == "Pallet" then
	highlight.Enabled = (ChamsEnabled and VDSettings.ShowPallets)
elseif objType == "ExitGate" then
	highlight.Enabled = (ChamsEnabled and VDSettings.ShowExitGates)
else
	highlight.Enabled = ChamsEnabled
end
DebugPrint("[CreateObjectESP] Highlight created for: " .. adornee:GetFullName())
if objType == "Vault" then
	DebugPrint("[CreateObjectESP] Vault highlight parent: " ..
	(highlight.Parent and highlight.Parent:GetFullName() or "nil") ..
	" | Adornee: " ..
	(adornee and (adornee:GetFullName() or "") or "nil") .. " | Enabled: " .. tostring(highlight.Enabled))
end
local billboard, progressBar, progressFill, progressText
if objType == "Generator" and VDSettings.ShowGeneratorProgress and targetPart then
	billboard = Instance.new("BillboardGui")
	billboard.Name = "Starship_GeneratorProgress"
	billboard.Size = UDim2.new(4, 0, 0.8, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = targetPart
	billboard.Adornee = targetPart
	progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(1, 0, 0.4, 0)
	progressBar.Position = UDim2.new(0, 0, 0.3, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	progressBar.BorderSizePixel = 1
	progressBar.BorderColor3 = Color3.fromRGB(0, 0, 0)
	progressBar.Parent = billboard
	progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBar
	progressText = Instance.new("TextLabel")
	progressText.Name = "ProgressText"
	progressText.Size = UDim2.new(1, 0, 0.5, 0)
	progressText.Position = UDim2.new(0, 0, 0.7, 0)
	progressText.BackgroundTransparency = 1
	progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
	progressText.TextStrokeTransparency = 0
	progressText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	progressText.Font = Enum.Font.GothamBold
	progressText.TextScaled = true
	progressText.Text = "0%"
	progressText.Parent = billboard
end
if not VDESPObjects[objType .. "s"] then
	VDESPObjects[objType .. "s"] = {}
end
VDESPObjects[objType .. "s"][key] = {
Object = obj,
Highlight = highlight,
Billboard = billboard,
ProgressBar = progressBar,
ProgressFill = progressFill,
ProgressText = progressText
}
end
RemoveObjectESP = function(objType)
local storage = VDESPObjects[objType .. "s"]
if not storage then return end
for key, data in pairs(storage) do
	if data.Highlight and data.Highlight.Parent then
		data.Highlight:Destroy()
	end
	if data.Billboard and data.Billboard.Parent then
		data.Billboard:Destroy()
	end
end
VDESPObjects[objType .. "s"] = {}
end
UpdateObjectESPColor = function(objType, color)
local storage = VDESPObjects[objType .. "s"]
if not storage then return end
for key, data in pairs(storage) do
	if data.Highlight and data.Highlight.Parent then
		data.Highlight.FillColor = color
		data.Highlight.OutlineColor = color
	end
end
end
UpdateObjectESPTransparency = function(objType, transparency)
local storage = VDESPObjects[objType .. "s"]
if not storage then return end
for key, data in pairs(storage) do
	if data.Highlight and data.Highlight.Parent then
		data.Highlight.FillTransparency = transparency
	end
end
end
local function UpdateObjectESPOutlineEnabled(objType, enabled)
	local storage = VDESPObjects[objType .. "s"]
	if not storage then return end
	local transparency = enabled and 0 or 1
	if objType == "Generator" then
		transparency = enabled and VDSettings.GeneratorOutlineTransparency or 1
	elseif objType == "Hook" then
		transparency = enabled and VDSettings.HookOutlineTransparency or 1
	elseif objType == "ExitGate" then
		transparency = enabled and VDSettings.ExitGateOutlineTransparency or 1
	elseif objType == "Vault" then
		transparency = enabled and VDSettings.VaultOutlineTransparency or 1
	end
	for key, data in pairs(storage) do
		if data.Highlight and data.Highlight.Parent then
			data.Highlight.OutlineTransparency = transparency
		end
	end
end
local function UpdateObjectESPOutlineColor(objType, color)
	local storage = VDESPObjects[objType .. "s"]
	if not storage then return end
	for key, data in pairs(storage) do
		if data.Highlight and data.Highlight.Parent then
			data.Highlight.OutlineColor = color
		end
	end
end
local function UpdateObjectESPOutlineTransparency(objType, transparency)
	local storage = VDESPObjects[objType .. "s"]
	if not storage then return end
	for key, data in pairs(storage) do
		if data.Highlight and data.Highlight.Parent then
			data.Highlight.OutlineTransparency = transparency
		end
	end
end
local function UpdateObjectESPOutlineEnabled(objType, enabled)
	local storage = VDESPObjects[objType .. "s"]
	if not storage then return end
	local transparency = enabled and 0 or 1
	if objType == "Generator" then
		transparency = enabled and VDSettings.GeneratorOutlineTransparency or 1
	elseif objType == "Hook" then
		transparency = enabled and VDSettings.HookOutlineTransparency or 1
	end
	for key, data in pairs(storage) do
		if data.Highlight and data.Highlight.Parent then
			data.Highlight.OutlineTransparency = transparency
		end
	end
end
UpdateGeneratorProgress = function()
local storage = VDESPObjects.Generators
if not storage then
	DebugPrint("[GenProgress] No storage found")
	return
end
if not LocalPlayer.Character then return end
local myHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
if not myHRP then return end
local count = 0
for key, data in pairs(storage) do
	count = count + 1
	if data.Object and data.Object.Parent then
		local objPos
		if data.Object:IsA("Model") then
			local primary = data.Object.PrimaryPart or data.Object:FindFirstChildWhichIsA("BasePart")
			if primary then objPos = primary.Position end
		elseif data.Object:IsA("Folder") then
			local part = data.Object:FindFirstChildWhichIsA("BasePart", true) or
			data.Object:FindFirstChildWhichIsA("MeshPart", true)
			if part then objPos = part.Position end
		else
			objPos = data.Object.Position
		end
		if objPos then
			local distance = (myHRP.Position - objPos).Magnitude
			local inRange = distance <= VDSettings.GeneratorMaxDistance
			if inRange then
				local progress = GetGeneratorProgress(data.Object)
				if data.Highlight then
					if progress >= 100 then
						if data.Highlight.FillColor ~= VDSettings.GeneratorFinishedColor then
							data.Highlight.FillColor = VDSettings.GeneratorFinishedColor or Color3.fromRGB(0, 255, 0)
						end
					else
						if data.Highlight.FillColor ~= VDSettings.GeneratorColor then
							data.Highlight.FillColor = VDSettings.GeneratorColor
						end
					end
				end
				if data.Billboard and data.Billboard.Enabled then
					DebugPrint("[GenProgress] " .. key .. " = " .. tostring(progress) .. "%")
					if data.ProgressFill and data.ProgressText then
						data.ProgressFill.Size = UDim2.new(progress / 100, 0, 1, 0)
						local fillColor
						if progress < 50 then
							fillColor = Color3.fromRGB(255, math.floor(progress * 5.1), 0)
						else
							fillColor = Color3.fromRGB(math.floor(255 - (progress - 50) * 5.1), 255, 0)
						end
						data.ProgressFill.BackgroundColor3 = fillColor
						data.ProgressText.Text = math.floor(progress) .. "%"
					else
						DebugPrint("[GenProgress] " .. key .. " missing ProgressFill or ProgressText")
					end
				end
			end
		end
	end
end
if count == 0 then
	DebugPrint("[GenProgress] Storage empty - no generators tracked")
end
end
UpdateObjectESP = function()
local Settings = {
ChamsEnabled = ChamsEnabled,
ShowGenerators = VDSettings.ShowGenerators,
GeneratorMaxDistance = VDSettings.GeneratorMaxDistance,
ShowGeneratorProgress = VDSettings.ShowGeneratorProgress,
ShowHooks = VDSettings.ShowHooks,
HookMaxDistance = VDSettings.HookMaxDistance,
ShowExitGates = VDSettings.ShowExitGates,
ExitGateMaxDistance = VDSettings.ExitGateMaxDistance,
ShowPallets = VDSettings.ShowPallets,
PalletMaxDistance = 500,
ShowVaults = VDSettings.ShowVaults,
VaultMaxDistance = VDSettings.VaultMaxDistance,
ShowVaultsESP = VDSettings.ShowVaultsESP,
Limit = 100
}
if not Settings.ChamsEnabled then
	for _, storageKey in ipairs({ "Generators", "Hooks", "ExitGates", "Pallets", "Vaults" }) do
		local storage = VDESPObjects[storageKey]
		if storage then
			for _, data in pairs(storage) do
				if data.Highlight and data.Highlight.Enabled then data.Highlight.Enabled = false end
				if data.Billboard and data.Billboard.Enabled then data.Billboard.Enabled = false end
			end
		end
	end
	return
end
if not LocalPlayer.Character then return end
local myHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
if not myHRP then return end
local myPos = myHRP.Position
local activeHighlights = 0
local function ProcessStorage(storage, maxDist, showProgress)
	if not storage or activeHighlights >= Settings.Limit then return end
	for key, data in pairs(storage) do
		if activeHighlights >= Settings.Limit then break end
		if data.Object and data.Object.Parent then
			local objPos = nil
			if data.Object:IsA("Model") then
				local primary = data.Object.PrimaryPart or data.Object:FindFirstChildWhichIsA("BasePart")
				if primary then objPos = primary.Position end
			elseif data.Object:IsA("Folder") then
				local part = data.Object:FindFirstChildWhichIsA("BasePart", true) or
				data.Object:FindFirstChildWhichIsA("MeshPart", true)
				if part then objPos = part.Position end
			elseif data.Object:IsA("BasePart") then
				objPos = data.Object.Position
			end
			if objPos then
				local distance = (myPos - objPos).Magnitude
				local inRange = distance <= maxDist
				if inRange and activeHighlights < Settings.Limit then
					if data.Highlight then
						if not data.Highlight.Enabled then data.Highlight.Enabled = true end
						if data.Highlight.Adornee ~= data.Object and not data.Object:IsA("Folder") then
							data.Highlight.Adornee = data.Object
						end
						activeHighlights = activeHighlights + 1
					end
					if data.Billboard then
						if showProgress then
							if not data.Billboard.Enabled then data.Billboard.Enabled = true end
						else
							if data.Billboard.Enabled then data.Billboard.Enabled = false end
						end
					end
				else
					if data.Highlight and data.Highlight.Enabled then data.Highlight.Enabled = false end
					if data.Billboard and data.Billboard.Enabled then data.Billboard.Enabled = false end
				end
			end
		else
			if data.Highlight then data.Highlight:Destroy() end
			if data.Billboard then data.Billboard:Destroy() end
			storage[key] = nil
		end
	end
end
if Settings.ShowGenerators then
	ProcessStorage(VDESPObjects.Generators, Settings.GeneratorMaxDistance,
	Settings.ShowGeneratorProgress)
end
if Settings.ShowHooks then ProcessStorage(VDESPObjects.Hooks, Settings.HookMaxDistance, false) end
if Settings.ShowExitGates then ProcessStorage(VDESPObjects.ExitGates, Settings.ExitGateMaxDistance, false) end
if Settings.ShowPallets then ProcessStorage(VDESPObjects.Pallets, Settings.PalletMaxDistance, false) end
if (Settings.ShowVaults or Settings.ShowVaultsESP) then
	ProcessStorage(VDESPObjects.Vaults, Settings
	.VaultMaxDistance, false)
end
end
GFS._lastESPRefreshTime = 0
local function RefreshESPOnRoleChange()
	local now = tick()
	if now - GFS._lastESPRefreshTime < 2.0 then return end
	GFS._lastESPRefreshTime = now
	print("[ESP/CHAMS] Role changed! Refreshing all ESP and Chams...")
	if ChamsEnabled then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and player.Character then
				CreateChams(player, true)
			end
		end
		UpdateChams()
		print("[CHAMS] Refreshed player Chams")
	end
	if ESPEnabled then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				RemoveESP(player)
				CreateESP(player)
			end
		end
	end
	if VDSettings.ShowGenerators or VDSettings.ShowHooks or VDSettings.ShowExitGates or
	VDSettings.ShowPallets or VDSettings.ShowVaults or VDSettings.ShowVaultsESP then
		task.defer(function()
		UpdateObjectESP()
	end)
end
if VDSettings.ShowGenerators and VDSettings.ShowGeneratorProgress then
	task.defer(function()
	UpdateGeneratorProgress()
end)
end
if VDSettings.ShowVaultsESP then
	task.defer(function()
	ESP_Logic.RefreshVaultESP()
	print("[VAULT ESP] Refreshed vault ESP")
end)
end
if ESPSettings.ShowExitGateESP then
	task.defer(function()
	ESP_Logic.RefreshExitGateESP()
	print("[EXIT GATE ESP] Refreshed exit gate ESP")
end)
end
print("[ESP/CHAMS] Refresh complete!")
end
_G.Radar = _G.Radar or {
bg = nil,
circleBg = nil,
border = nil,
circleBorder = nil,
cross1 = nil,
cross2 = nil,
center = nil,
dots = {},
objectDots = {},
palletSquares = {}
}
local Radar = _G.Radar
local function InitializeRadar()
	if not DrawingAvailable then return end
	pcall(function()
	Radar.bg = Drawing.new("Square")
	Radar.circleBg = Drawing.new("Circle")
	Radar.border = Drawing.new("Square")
	Radar.circleBorder = Drawing.new("Circle")
	Radar.cross1 = Drawing.new("Line")
	Radar.cross2 = Drawing.new("Line")
	Radar.center = Drawing.new("Triangle")
	Radar.bg.Filled = true
	Radar.bg.Color = Color3.fromRGB(20, 20, 20)
	Radar.bg.Transparency = 0.8
	Radar.circleBg.Filled = true
	Radar.circleBg.Color = Color3.fromRGB(20, 20, 20)
	Radar.circleBg.Transparency = 0.8
	Radar.circleBg.NumSides = 64
	Radar.border.Filled = false
	Radar.border.Color = Color3.fromRGB(255, 65, 65)
	Radar.border.Thickness = 2
	Radar.circleBorder.Filled = false
	Radar.circleBorder.Color = Color3.fromRGB(255, 65, 65)
	Radar.circleBorder.Thickness = 2
	Radar.circleBorder.NumSides = 64
	Radar.cross1.Color = Color3.fromRGB(40, 40, 40)
	Radar.cross1.Thickness = 1
	Radar.cross2.Color = Color3.fromRGB(40, 40, 40)
	Radar.cross2.Thickness = 1
	Radar.center.Filled = true
	Radar.center.Color = Color3.fromRGB(0, 255, 0)
	for i = 1, 100 do
		local d = Drawing.new("Triangle")
		d.Filled = true
		d.Visible = false
		Radar.dots[i] = d
	end
	for i = 1, 100 do
		local d = Drawing.new("Circle")
		d.Filled = true
		d.Visible = false
		d.NumSides = 16
		Radar.objectDots[i] = d
	end
	for i = 1, 100 do
		local d = Drawing.new("Square")
		d.Filled = true
		d.Visible = false
		Radar.palletSquares[i] = d
	end
end)
end
local function HideRadar()
	if not DrawingAvailable then return end
	pcall(function()
	if Radar.bg then Radar.bg.Visible = false end
	if Radar.circleBg then Radar.circleBg.Visible = false end
	if Radar.border then Radar.border.Visible = false end
	if Radar.circleBorder then Radar.circleBorder.Visible = false end
	if Radar.center then Radar.center.Visible = false end
	if Radar.cross1 then Radar.cross1.Visible = false end
	if Radar.cross2 then Radar.cross2.Visible = false end
	for _, d in pairs(Radar.dots) do d.Visible = false end
	for _, d in pairs(Radar.objectDots) do d.Visible = false end
	for _, d in pairs(Radar.palletSquares) do d.Visible = false end
end)
end
local function UpdateRadar()
	if not GFS.RadarEnabled or not DrawingAvailable then
		HideRadar()
		return
	end
	local now = tick()
	if now - GFS.LastRadarUpdate < GFS.RadarUpdateInterval then
		return
	end
	GFS.LastRadarUpdate = now
	if now - GFS.LastRadarCacheUpdate > GFS.RadarCacheInterval then
		pcall(function()
		GFS.RadarCachedGens = CollectGenerators()
		GFS.RadarCachedPallets = CollectPallets()
		GFS.LastRadarCacheUpdate = now
	end)
end
pcall(function()
local cam = workspace.CurrentCamera
if not cam then
	HideRadar()
	return
end
local screenSize = cam.ViewportSize
local size = GFS.RadarSize
local pos = Vector2.new(screenSize.X - size - 20, 20)
local center = pos + Vector2.new(size / 2, size / 2)
if GFS.RadarCircle then
	Radar.bg.Visible = false
	Radar.border.Visible = false
	Radar.circleBg.Position = center
	Radar.circleBg.Radius = size / 2
	Radar.circleBg.Visible = true
	Radar.circleBorder.Position = center
	Radar.circleBorder.Radius = size / 2
	Radar.circleBorder.Visible = true
else
	Radar.circleBg.Visible = false
	Radar.circleBorder.Visible = false
	Radar.bg.Position = pos
	Radar.bg.Size = Vector2.new(size, size)
	Radar.bg.Visible = true
	Radar.border.Position = pos
	Radar.border.Size = Vector2.new(size, size)
	Radar.border.Visible = true
end
Radar.cross1.From = Vector2.new(center.X, pos.Y + 10)
Radar.cross1.To = Vector2.new(center.X, pos.Y + size - 10)
Radar.cross1.Visible = true
Radar.cross2.From = Vector2.new(pos.X + 10, center.Y)
Radar.cross2.To = Vector2.new(pos.X + size - 10, center.Y)
Radar.cross2.Visible = true
local myChar = LocalPlayer.Character
local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
local myLook = cam.CFrame.LookVector
if not myRoot then
	Radar.center.Visible = false
	for _, d in pairs(Radar.dots) do d.Visible = false end
	for _, d in pairs(Radar.objectDots) do d.Visible = false end
	for _, d in pairs(Radar.palletSquares) do d.Visible = false end
	return
end
local myAngle = math.atan2(-myLook.X, -myLook.Z)
local cosA, sinA = math.cos(myAngle), math.sin(myAngle)
local scale = (size / 2 - 10) / GFS.RadarRange
local fwd = Vector2.new(0, -8)
local rotated = Vector2.new(
fwd.X * cosA - fwd.Y * sinA,
fwd.X * sinA + fwd.Y * cosA
)
Radar.center.PointA = center + rotated
Radar.center.PointB = center + Vector2.new(-4, 4)
Radar.center.PointC = center + Vector2.new(4, 4)
Radar.center.Visible = true
for _, d in pairs(Radar.dots) do d.Visible = false end
for _, d in pairs(Radar.objectDots) do d.Visible = false end
for _, d in pairs(Radar.palletSquares) do d.Visible = false end
local idx = 1
local objIdx = 1
local palletIdx = 1
local maxPlayers = 20
local maxObjects = 15
local maxPallets = 10
for _, player in ipairs(Players:GetPlayers()) do
	if idx > maxPlayers then break end
	if player ~= LocalPlayer and player.Character then
		local otherRoot = player.Character:FindFirstChild("HumanoidRootPart")
		if otherRoot and idx <= #Radar.dots then
			local rx = otherRoot.Position.X - myRoot.Position.X
			local rz = otherRoot.Position.Z - myRoot.Position.Z
			local dist = math.sqrt(rx * rx + rz * rz)
			if dist <= RadarRange then
				local lx = rx * cosA + rz * sinA
				local ly = -rx * sinA + rz * cosA
				local sx = center.X + lx * scale
				local sy = center.Y + ly * scale
				local isKiller = IsKiller(player)
				local col = isKiller and Color3.fromRGB(255, 65, 65) or Color3.fromRGB(65, 220, 130)
				local arrowSize = 8
				local dot = Radar.dots[idx]
				local dotAngle = math.atan2(-myLook.X, -myLook.Z)
				local dotFwd = Vector2.new(0, -arrowSize)
				local dotRotated = Vector2.new(
				dotFwd.X * math.cos(dotAngle) - dotFwd.Y * math.sin(dotAngle),
				dotFwd.X * math.sin(dotAngle) + dotFwd.Y * math.cos(dotAngle)
				)
				dot.PointA = Vector2.new(sx, sy) + dotRotated
				dot.PointB = Vector2.new(sx - 4, sy + 4)
				dot.PointC = Vector2.new(sx + 4, sy + 4)
				dot.Color = col
				dot.Visible = true
				idx = idx + 1
			end
		end
	end
end
for _, gen in ipairs(GFS.RadarCachedGens) do
	if objIdx > maxObjects or objIdx > #Radar.objectDots then break end
	pcall(function()
	local genPos
	if gen:IsA("Model") then
		local primary = gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart")
		if primary then genPos = primary.Position end
	else
		genPos = gen.Position
	end
	if genPos then
		local rx = genPos.X - myRoot.Position.X
		local rz = genPos.Z - myRoot.Position.Z
		local dist = math.sqrt(rx * rx + rz * rz)
		if dist <= GFS.RadarRange then
			local lx = rx * cosA + rz * sinA
			local ly = -rx * sinA + rz * cosA
			local sx = center.X + lx * scale
			local sy = center.Y + ly * scale
			local dot = Radar.objectDots[objIdx]
			dot.Position = Vector2.new(sx, sy)
			dot.Radius = 5
			dot.Color = Color3.fromRGB(255, 180, 50)
			dot.Visible = true
			objIdx = objIdx + 1
		end
	end
end)
end
for _, pallet in ipairs(GFS.RadarCachedPallets) do
	if palletIdx > maxPallets or palletIdx > #Radar.palletSquares then break end
	pcall(function()
	local palletPos
	if pallet:IsA("Model") then
		local primary = pallet.PrimaryPart or pallet:FindFirstChildWhichIsA("BasePart")
		if primary then palletPos = primary.Position end
	else
		palletPos = pallet.Position
	end
	if palletPos then
		local rx = palletPos.X - myRoot.Position.X
		local rz = palletPos.Z - myRoot.Position.Z
		local dist = math.sqrt(rx * rx + rz * rz)
		if dist <= GFS.RadarRange then
			local lx = rx * cosA + rz * sinA
			local ly = -rx * sinA + rz * cosA
			local sx = center.X + lx * scale
			local sy = center.Y + ly * scale
			local square = Radar.palletSquares[palletIdx]
			square.Position = Vector2.new(sx - 3, sy - 3)
			square.Size = Vector2.new(6, 6)
			square.Color = Color3.fromRGB(220, 180, 100)
			square.Visible = true
			palletIdx = palletIdx + 1
		end
	end
end)
end
end)
end
Players.PlayerAdded:Connect(function(player)
player.CharacterAdded:Connect(function(character)
task.wait(1)
if ESPEnabled then
	CreateESP(player)
end
if ChamsEnabled then
	RemoveChams(player)
	task.wait(0.1)
	CreateChams(player)
end
end)
local lastTeam = player.Team
GFS.playerTeamCache[player] = lastTeam
player:GetPropertyChangedSignal("Team"):Connect(function()
local newTeam = player.Team
if newTeam ~= lastTeam then
	lastTeam = newTeam
	GFS.playerTeamCache[player] = newTeam
	if ChamsEnabled then
		task.wait(0.1)
		RemoveChams(player)
		task.wait(0.1)
		CreateChams(player)
		local teamName = newTeam and newTeam.Name or "NO_TEAM"
		local isKiller = IsKiller(player)
	end
end
end)
end)
Players.PlayerRemoving:Connect(function(player)
RemoveESP(player)
RemoveChams(player)
GFS.playerTeamCache[player] = nil
PerkCache[player] = nil
ItemCache[player] = nil
end)
GFS.lastChamsRefresh = tick()
GFS.lastRoleCheck = tick()
GFS.lastKnownRole = nil
GFS._lastRoleNotifyTime = 0
GFS._pendingRole = nil
GFS._pendingRoleSince = 0
GFS._ROLE_CONFIRM_TIME = 3
RunService.Heartbeat:Connect(function()
local now = tick()
if now - GFS.lastRoleCheck > 1 then
	GFS.lastRoleCheck = now
	local currentRole = DetectMyRole()
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		GFS._pendingRole = nil
		GFS._pendingRoleSince = 0
	elseif GFS.lastKnownRole == nil then
		GFS.lastKnownRole = currentRole
		GFS._pendingRole = nil
		GFS._pendingRoleSince = 0
	elseif currentRole == GFS.lastKnownRole then
		GFS._pendingRole = nil
		GFS._pendingRoleSince = 0
	else
		if GFS._pendingRole ~= currentRole then
			GFS._pendingRole = currentRole
			GFS._pendingRoleSince = now
		elseif (now - GFS._pendingRoleSince) >= GFS._ROLE_CONFIRM_TIME then
			GFS._pendingRole = nil
			GFS._pendingRoleSince = 0
			GFS.lastKnownRole = currentRole
			local isMorphing = GFS._MorphReapplyDebounce == true
			local canNotify = (not isMorphing) and (now - (GFS._lastRoleNotifyTime or 0)) > 8
			if canNotify then
				GFS._lastRoleNotifyTime = now
				Library:Notify("Your role is " .. currentRole .. "!", 2)
			end
			if not isMorphing then
				task.defer(function()
				RefreshESPOnRoleChange()
			end)
			if GFS.AutoGenEnabled and currentRole ~= "Survivor" and not GFS.AutoGenWaitingForRole then
				GFS.AutoGenWaitingForRole = true
				GFS.AutoGenPaused = true
				if GFS.AutoGenMode == "Legit" then
					pcall(function()
					if GFS.AutoGenRemotes and GFS.AutoGenRemotes.repair then
						local char2 = LocalPlayer.Character
						local myRoot = char2 and char2:FindFirstChild("HumanoidRootPart")
						if myRoot then
							GFS.AutoGenRemotes.repair:FireServer(myRoot.Position, false)
							GFS.AutoGenRemotes.repair:FireServer(false)
						end
					end
					local char2 = LocalPlayer.Character
					if char2 then
						local humanoid = char2:FindFirstChildOfClass("Humanoid")
						if humanoid then
							humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
						end
					end
				end)
			end
		end
		if GFS.RefreshVisualSettings then
			pcall(GFS.RefreshVisualSettings)
		end
	end
	if GFS.MorphAvatar and GFS.MorphAvatar._morphedUserId then
		_MorphReapplyAvatar("role_changed")
		task.spawn(function()
		local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		_SetupMorphDescWatcher(character)
	end)
end
end
end
end
if ChamsEnabled and now - GFS.lastChamsRefresh > 2 then
	GFS.lastChamsRefresh = now
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local currentTeam = player.Team
			local cachedTeam = GFS.playerTeamCache[player]
			if currentTeam ~= cachedTeam then
				GFS.playerTeamCache[player] = currentTeam
				task.defer(function()
				pcall(function()
				RemoveChams(player)
				if ESPEnabled then RemoveESP(player) end
				CreateChams(player)
				if ESPEnabled then CreateESP(player) end
			end)
		end)
	elseif not ChamsObjects[player] then
		CreateChams(player)
	end
	if ESPEnabled and not ESPObjects[player] then
		CreateESP(player)
	end
end
end
end
end)
GFS._MorphReapplyDebounce = false
GFS._MorphDescWatcherConn = nil
local function _MorphReapplyAvatar(reason)
	if not GFS.MorphAvatar or not GFS.MorphAvatar._morphedUserId then return end
	if GFS._MorphReapplyDebounce then return end
	GFS._MorphReapplyDebounce = true
	task.spawn(function()
	local userId = GFS.MorphAvatar._morphedUserId
	local morphName = GFS.MorphAvatar._morphedName or "Unknown"
	local MAX_RETRIES = 4
	local DELAYS = { 2.0, 3.5, 5.0, 7.0 }
	for attempt = 1, MAX_RETRIES do
		if not GFS.MorphAvatar or not GFS.MorphAvatar._morphedUserId then break end
		if GFS.MorphAvatar._morphedUserId ~= userId then break end
		task.wait(DELAYS[attempt] or 3.0)
		local character = LocalPlayer.Character
		if not character then break end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then break end
		local alreadyMorphed = false
		pcall(function()
		local currentDesc = humanoid:GetAppliedDescription()
		if currentDesc then
			local targetDesc = Players:GetHumanoidDescriptionFromUserId(userId)
			if targetDesc and currentDesc.Shirt == targetDesc.Shirt and currentDesc.Pants == targetDesc.Pants then
				alreadyMorphed = true
			end
		end
	end)
	if alreadyMorphed then break end
	local success, desc = pcall(function()
	return Players:GetHumanoidDescriptionFromUserId(userId)
end)
if success and desc then
	pcall(function()
	for _, obj in ipairs(character:GetChildren()) do
		if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or
		obj:IsA("Accessory") or obj:IsA("BodyColors") then
			pcall(function() obj:Destroy() end)
		end
	end
	local head = character:FindFirstChild("Head")
	if head then
		for _, decal in ipairs(head:GetChildren()) do
			if decal:IsA("Decal") then pcall(function() decal:Destroy() end) end
		end
	end
end)
local applyOk = pcall(function()
humanoid:ApplyDescriptionClientServer(desc)
end)
if applyOk then
	break
end
end
end
GFS._MorphReapplyDebounce = false
end)
end
local function _SetupMorphDescWatcher(character)
	if GFS._MorphDescWatcherConn then
		pcall(function() GFS._MorphDescWatcherConn:Disconnect() end)
		GFS._MorphDescWatcherConn = nil
	end
	if not GFS.MorphAvatar or not GFS.MorphAvatar._morphedUserId then return end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	GFS._MorphDescWatcherConn = humanoid.ChildAdded:Connect(function(child)
	if not GFS.MorphAvatar or not GFS.MorphAvatar._morphedUserId then return end
	if child:IsA("HumanoidDescription") then
		task.delay(1.0, function()
		if GFS.MorphAvatar and GFS.MorphAvatar._morphedUserId then
			_MorphReapplyAvatar("desc_changed")
		end
	end)
end
end)
end
LocalPlayer.CharacterAdded:Connect(function(character)
if GFS.MorphAvatar and GFS.MorphAvatar._morphedUserId then
	_MorphReapplyAvatar("character_added")
	task.spawn(function()
	_SetupMorphDescWatcher(character)
end)
end
end)
local function HasParryingDagger()
	local char = LocalPlayer.Character
	if not char then return false end
	for _, tool in pairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			local toolName = tool.Name:lower()
			if toolName:find("parry") or toolName:find("dagger") then
				return true
			end
		end
	end
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local toolName = tool.Name:lower()
				if toolName:find("parry") or toolName:find("dagger") then
					return true
				end
			end
		end
	end
	local status = char:FindFirstChild("Status")
	if status then
		local item = status:FindFirstChild("Item")
		if item and item.Value then
			local itemName = tostring(item.Value):lower()
			if itemName:find("parry") or itemName:find("dagger") then
				return true
			end
		end
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local items = remotes:FindFirstChild("Items")
		if items then
			local dagger = items:FindFirstChild("Parrying Dagger")
			if dagger and dagger:FindFirstChild("parry") then
				return true
			end
		end
	end
	return false
end
local function IsKillerAttacking(killerChar)
	if not killerChar then return false end
	local humanoid = killerChar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in pairs(animator:GetPlayingAnimationTracks()) do
				local animName = track.Name:lower()
				if animName:find("attack") or animName:find("swing") or animName:find("slash") or animName:find("hit") then
					return true
				end
			end
		end
	end
	local status = killerChar:FindFirstChild("Status")
	if status then
		local action = status:FindFirstChild("Action")
		if action then
			local actionVal = tostring(action.Value):lower()
			if actionVal:find("attack") or actionVal:find("swing") or actionVal == "attacking" then
				return true
			end
		end
	end
	return false
end
do
	local _attackHooksSetup = false
	function SetupAttackRemoteHooks()
		if _attackHooksSetup then return end
		_attackHooksSetup = true
		local hookCount = 0
		local function GetPlayerName(val)
			if not val then return nil end
			if typeof(val) == "Instance" then
				if val:IsA("Player") then
					return val.Name
				elseif val:IsA("Model") then
					local p = Players:GetPlayerFromCharacter(val)
					if p then return p.Name end
					return val.Name
				end
			elseif typeof(val) == "string" then
				return val
			end
			return nil
		end
		local function RegisterAttack(playerName, source)
			if not playerName then return end
			GFS.RecentAttacks[playerName] = tick()
		end
		pcall(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if not remotes then
			return
		end
		local attackEvent = remotes:FindFirstChild("AttackEvent")
		if attackEvent and attackEvent:IsA("RemoteEvent") then
			attackEvent.OnClientEvent:Connect(function(...)
			local args = { ... }
			for _, arg in ipairs(args) do
				local playerName = GetPlayerName(arg)
				if playerName then
					RegisterAttack(playerName, "AttackEvent")
					break
				end
			end
		end)
		hookCount = hookCount + 1
	end
	local attacks = remotes:FindFirstChild("Attacks")
	if attacks then
		local basicAttack = attacks:FindFirstChild("BasicAttack")
		if basicAttack and basicAttack:IsA("RemoteEvent") then
			basicAttack.OnClientEvent:Connect(function(...)
			local args = { ... }
			for _, arg in ipairs(args) do
				local playerName = GetPlayerName(arg)
				if playerName then
					RegisterAttack(playerName, "BasicAttack")
					break
				end
			end
		end)
		hookCount = hookCount + 1
	end
	local hit = attacks:FindFirstChild("hit")
	if hit and hit:IsA("RemoteEvent") then
		hit.OnClientEvent:Connect(function(...)
		local args = { ... }
		for _, arg in ipairs(args) do
			local playerName = GetPlayerName(arg)
			if playerName then
				RegisterAttack(playerName, "hit")
				break
			end
		end
	end)
	hookCount = hookCount + 1
	end
	local afterAttack = attacks:FindFirstChild("AfterAttack")
	if afterAttack and afterAttack:IsA("RemoteEvent") then
		afterAttack.OnClientEvent:Connect(function(...)
		local args = { ... }
		for _, arg in ipairs(args) do
			local playerName = GetPlayerName(arg)
			if playerName then
				RegisterAttack(playerName, "AfterAttack")
				break
			end
		end
	end)
	hookCount = hookCount + 1
	end
	local trailEvent = attacks:FindFirstChild("TrailEvent")
	if trailEvent and trailEvent:IsA("RemoteEvent") then
		trailEvent.OnClientEvent:Connect(function(...)
		local args = { ... }
		for _, arg in ipairs(args) do
			local playerName = GetPlayerName(arg)
			if playerName then
				RegisterAttack(playerName, "TrailEvent")
				break
			end
		end
	end)
	hookCount = hookCount + 1
	end
	end
	local killers = remotes:FindFirstChild("Killers")
	if killers then
		local setAction = killers:FindFirstChild("SetAction")
		if setAction and setAction:IsA("RemoteEvent") then
			setAction.OnClientEvent:Connect(function(player, action, ...)
			local playerName = GetPlayerName(player)
			local actionStr = tostring(action or ""):lower()
			if actionStr:find("attack") or actionStr:find("swing") or
			actionStr:find("m1") or actionStr:find("hit") or
			actionStr:find("slash") or actionStr:find("lunge") then
				RegisterAttack(playerName, "SetAction:" .. actionStr)
			end
		end)
		hookCount = hookCount + 1
	end
	local instinct = killers:FindFirstChild("Instinct")
	if instinct and instinct:IsA("RemoteEvent") then
		instinct.OnClientEvent:Connect(function(...)
		local args = { ... }
		for _, arg in ipairs(args) do
			local playerName = GetPlayerName(arg)
			if playerName then
				RegisterAttack(playerName, "Instinct")
				break
			end
		end
	end)
	hookCount = hookCount + 1
	end
	local killer = killers:FindFirstChild("Killer")
	if killer then
		local frenzyHit = killer:FindFirstChild("FrenzyHitEvent")
		if frenzyHit and frenzyHit:IsA("RemoteEvent") then
			frenzyHit.OnClientEvent:Connect(function(...)
			local args = { ... }
			for _, arg in ipairs(args) do
				local playerName = GetPlayerName(arg)
				if playerName then
					RegisterAttack(playerName, "FrenzyHitEvent")
					break
				end
			end
		end)
		hookCount = hookCount + 1
	end
	local activatePower = killer:FindFirstChild("ActivatePower")
	if activatePower and activatePower:IsA("RemoteEvent") then
		activatePower.OnClientEvent:Connect(function(...)
		local args = { ... }
		for _, arg in ipairs(args) do
			local playerName = GetPlayerName(arg)
			if playerName then
				RegisterAttack(playerName, "ActivatePower")
				break
			end
		end
	end)
	hookCount = hookCount + 1
	end
	end
	local masked = killers:FindFirstChild("Masked")
	if masked then
		local alexattack = masked:FindFirstChild("alexattack")
		if alexattack and alexattack:IsA("RemoteEvent") then
			alexattack.OnClientEvent:Connect(function(...)
			local args = { ... }
			for _, arg in ipairs(args) do
				local playerName = GetPlayerName(arg)
				if playerName then
					RegisterAttack(playerName, "MaskedAttack")
					break
				end
			end
		end)
		hookCount = hookCount + 1
	end
	local activatepower = masked:FindFirstChild("Activatepower")
	if activatepower and activatepower:IsA("RemoteEvent") then
		activatepower.OnClientEvent:Connect(function(...)
		local args = { ... }
		for _, arg in ipairs(args) do
			local playerName = GetPlayerName(arg)
			if playerName then
				RegisterAttack(playerName, "MaskedPower")
				break
			end
		end
	end)
	hookCount = hookCount + 1
	end
	end
	local stalker = killers:FindFirstChild("Stalker")
	if stalker then
		local grab = stalker:FindFirstChild("grab")
		if grab and grab:IsA("RemoteEvent") then
			grab.OnClientEvent:Connect(function(...)
			local args = { ... }
			for _, arg in ipairs(args) do
				local playerName = GetPlayerName(arg)
				if playerName then
					RegisterAttack(playerName, "StalkerGrab")
					break
				end
			end
		end)
		hookCount = hookCount + 1
	end
	local startGrab = stalker:FindFirstChild("StartGrabHitbox")
	if startGrab and startGrab:IsA("RemoteEvent") then
		startGrab.OnClientEvent:Connect(function(...)
		local args = { ... }
		for _, arg in ipairs(args) do
			local playerName = GetPlayerName(arg)
			if playerName then
				RegisterAttack(playerName, "StalkerStartGrab")
				break
			end
		end
	end)
	hookCount = hookCount + 1
	end
	local grabResult = stalker:FindFirstChild("GrabHitResult")
	if grabResult and grabResult:IsA("RemoteEvent") then
		grabResult.OnClientEvent:Connect(function(...)
		local args = { ... }
		for _, arg in ipairs(args) do
			local playerName = GetPlayerName(arg)
			if playerName then
				RegisterAttack(playerName, "StalkerGrabHit")
				break
			end
		end
	end)
	hookCount = hookCount + 1
	end
	end
	local hidden = killers:FindFirstChild("Hidden")
	if hidden then
		local m2 = hidden:FindFirstChild("M2")
		if m2 and m2:IsA("RemoteEvent") then
			m2.OnClientEvent:Connect(function(...)
			local args = { ... }
			for _, arg in ipairs(args) do
				local playerName = GetPlayerName(arg)
				if playerName then
					RegisterAttack(playerName, "HiddenM2")
					break
				end
			end
		end)
		hookCount = hookCount + 1
	end
	end
	local veil = killers:FindFirstChild("Veil")
	if veil then
		local spearthrow = veil:FindFirstChild("Spearthrow")
		if spearthrow and spearthrow:IsA("RemoteEvent") then
			spearthrow.OnClientEvent:Connect(function(...)
			local args = { ... }
			for _, arg in ipairs(args) do
				local playerName = GetPlayerName(arg)
				if playerName then
					RegisterAttack(playerName, "VeilSpear")
					break
				end
			end
		end)
		hookCount = hookCount + 1
	end
	end
	end
	local mechanics = remotes:FindFirstChild("Mechanics")
	if mechanics then
		local parriedclient = mechanics:FindFirstChild("parriedclient")
		if parriedclient and parriedclient:IsA("RemoteEvent") then
			parriedclient.OnClientEvent:Connect(function(...)
			local args = { ... }
			for _, arg in ipairs(args) do
				local playerName = GetPlayerName(arg)
				if playerName then
					RegisterAttack(playerName, "ParriedClient")
					break
				end
			end
		end)
		hookCount = hookCount + 1
	end
	end
	local chase = remotes:FindFirstChild("Chase")
	if chase then
		local runevent = chase:FindFirstChild("Runevent")
		if runevent and runevent:IsA("RemoteEvent") then
			runevent.OnClientEvent:Connect(function(...)
		end)
		hookCount = hookCount + 1
	end
	end
	local killerPerks = remotes:FindFirstChild("KillerPerks")
	if killerPerks then
		local abyssal = killerPerks:FindFirstChild("Abyssal Covenant")
		if abyssal then
			local trigger = abyssal:FindFirstChild("trigger")
			if trigger and trigger:IsA("RemoteEvent") then
				trigger.OnClientEvent:Connect(function(...)
				local args = { ... }
				for _, arg in ipairs(args) do
					local playerName = GetPlayerName(arg)
					if playerName then
						RegisterAttack(playerName, "AbyssalTrigger")
						break
					end
				end
			end)
			hookCount = hookCount + 1
		end
	end
	end
	local animHandler = remotes:FindFirstChild("AnimationHandler")
	if animHandler and animHandler:IsA("RemoteEvent") then
		animHandler.OnClientEvent:Connect(function(player, animName, ...)
		if player and animName then
			local playerName = GetPlayerName(player)
			local animStr = tostring(animName):lower()
			if animStr:find("attack") or animStr:find("swing") or
			animStr:find("slash") or animStr:find("m1") or
			animStr:find("lunge") or animStr:find("hit") then
				RegisterAttack(playerName, "AnimHandler:" .. animStr)
			end
		end
	end)
	hookCount = hookCount + 1
	end
	local soundPlayer = remotes:FindFirstChild("SoundPlayer")
	if soundPlayer and soundPlayer:IsA("RemoteEvent") then
		soundPlayer.OnClientEvent:Connect(function(...)
		local args = { ... }
		for _, arg in ipairs(args) do
			if typeof(arg) == "string" then
				local s = arg:lower()
				if s:find("swing") or s:find("attack") or s:find("slash") or s:find("whoosh") then
					for _, arg2 in ipairs(args) do
						local playerName = GetPlayerName(arg2)
						if playerName then
							RegisterAttack(playerName, "AttackSound:" .. s)
							break
						end
					end
					break
				end
			end
		end
	end)
	hookCount = hookCount + 1
	end
	end)
	pcall(function()
	local function SetupCharacterAttributeListeners(char, playerName)
		if not char or not playerName then return end
		char:GetAttributeChangedSignal("Attacking"):Connect(function()
		local val = char:GetAttribute("Attacking")
		if val == true then
			GFS.RecentAttacks[playerName] = tick()
		end
	end)
	char:GetAttributeChangedSignal("Action"):Connect(function()
	local val = char:GetAttribute("Action")
	if val then
		local s = tostring(val):lower()
		if s:find("attack") or s:find("swing") or s:find("m1") then
			GFS.RecentAttacks[playerName] = tick()
		end
	end
	end)
	local status = char:FindFirstChild("Status")
	if status then
		local action = status:FindFirstChild("Action")
		if action and action:IsA("StringValue") then
			action.Changed:Connect(function(newVal)
			local s = newVal:lower()
			if s:find("attack") or s:find("swing") or s:find("m1") or
			s:find("slash") or s:find("lunge") or s:find("frenzy") then
				GFS.RecentAttacks[playerName] = tick()
			end
		end)
	end
	end
	end
	hookCount = hookCount + 1
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and IsKiller(player) and player.Character then
			SetupCharacterAttributeListeners(player.Character, player.Name)
		end
	end
	Players.PlayerAdded:Connect(function(player)
	task.delay(2, function()
	if player and IsKiller(player) and player.Character then
		SetupCharacterAttributeListeners(player.Character, player.Name)
	end
	end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(char)
		task.delay(1, function()
		if player and char and IsKiller(player) then
			SetupCharacterAttributeListeners(char, player.Name)
		end
	end)
	end)
	end
end
end
local function IsKillerRecentlyAttacked(killerName)
	local lastAttack = GFS.RecentAttacks[killerName]
	if not lastAttack then return false end
	local timeSince = tick() - lastAttack
	local isRecent = timeSince <= GFS.AttackDetectionWindow
	return isRecent
end
local _cachedParryRemote = nil
local _cachedParryLookup = 0
local function GetParryRemote(forceRefresh)
	if not forceRefresh and _cachedParryRemote and tick() - _cachedParryLookup < 5 then
		return _cachedParryRemote
	end
	_cachedParryRemote = nil
	_cachedParryLookup = tick()
	pcall(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local items = remotes:FindFirstChild("Items")
		if items then
			local dagger = items:FindFirstChild("Parrying Dagger")
			if dagger then
				local parry = dagger:FindFirstChild("parry")
				if parry then
					_cachedParryRemote = parry
				end
			end
		end
	end
end)
if not _cachedParryRemote then
	pcall(function()
	local items = ReplicatedStorage:FindFirstChild("Remotes") and
	ReplicatedStorage.Remotes:FindFirstChild("Items")
	if items then
		for _, toolRemoteFolder in ipairs(items:GetChildren()) do
			local name = toolRemoteFolder.Name:lower()
			if name:find("dagger") or name:find("parry") then
				local parry = toolRemoteFolder:FindFirstChild("parry")
				if parry and parry:IsA("RemoteEvent") then
					_cachedParryRemote = parry
					break
				end
			end
		end
	end
	if not _cachedParryRemote then
		for _, child in pairs(ReplicatedStorage:GetDescendants()) do
			if child.Name == "parry" and child:IsA("RemoteEvent") then
				local parent = child.Parent
				if parent and (parent.Name:lower():find("dagger") or parent.Name:lower():find("weapon")) then
					_cachedParryRemote = child
					break
				end
			end
		end
	end
end)
end
return _cachedParryRemote
end
_G.ParryUICache = {
Icon = nil,
Bar = nil,
Gradient = nil,
LastCheck = 0
}
local function SetupParryUIListener()
	if _G.ParryUIConnection then _G.ParryUIConnection:Disconnect() end
	local function validateIcon(instance)
		if instance:IsA("ImageLabel") and instance.Image == "rbxassetid://76822757630703" then
			_G.ParryUICache.Icon = instance
			_G.ParryUICache.Bar = instance:FindFirstChild("Bar")
			if _G.ParryUICache.Bar then
				_G.ParryUICache.Gradient = _G.ParryUICache.Bar:FindFirstChild("UIGradient")
			end
			instance.ChildAdded:Connect(function(child)
			if child.Name == "Bar" then
				_G.ParryUICache.Bar = child
				_G.ParryUICache.Gradient = child:FindFirstChild("UIGradient")
			end
		end)
		return true
	end
	if IsMobile and instance.Name == "Gui-mob" and instance:IsA("GuiButton") then
		local bar = instance:FindFirstChild("Bar")
		if bar then
			local grad = bar:FindFirstChildOfClass("UIGradient")
			if grad then
				_G.ParryUICache.Icon = instance
				_G.ParryUICache.Bar = bar
				_G.ParryUICache.Gradient = grad
				bar.ChildAdded:Connect(function(child)
				if child:IsA("UIGradient") then
					_G.ParryUICache.Gradient = child
				end
			end)
			return true
		end
	end
	instance.ChildAdded:Connect(function(child)
	if child.Name == "Bar" then
		_G.ParryUICache.Bar = child
		_G.ParryUICache.Gradient = child:FindFirstChildOfClass("UIGradient")
	end
end)
end
return false
end
if LocalPlayer.PlayerGui then
	for _, v in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
		validateIcon(v)
	end
	_G.ParryUIConnection = LocalPlayer.PlayerGui.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ImageLabel") or (descendant:IsA("GuiButton") and descendant.Name == "Gui-mob") then
		validateIcon(descendant)
	end
end)
end
end
task.spawn(SetupParryUIListener)
if _G.ParryRespawnConnection then _G.ParryRespawnConnection:Disconnect() end
_G.ParryRespawnConnection = LocalPlayer.CharacterAdded:Connect(function()
GFS.DaggerCooldownEnd = 0
GFS.LastParryTime = 0
_G.LastParryExecuted = 0
_G.CachedHasDagger = nil
_G.NextParryItemCheck = 0
_G.ParryKillerStates = {}
if GFS._killerLungeState then
	for k in pairs(GFS._killerLungeState) do
		GFS._killerLungeState[k] = nil
	end
end
_cachedParryRemote = nil
_cachedParryLookup = 0
if GFS._DisconnectAllKillerAnims then
	pcall(GFS._DisconnectAllKillerAnims)
end
if _G.ParryUICache then
	_G.ParryUICache.Icon = nil
	_G.ParryUICache.Bar = nil
	_G.ParryUICache.Gradient = nil
end
task.delay(2, function()
pcall(SetupParryUIListener)
end)
end)
_G.ParryKillerStates = _G.ParryKillerStates or {}
_G.LastParryExecuted = 0
local function GetLocalHeldItem()
	local held = ""
	local player = LocalPlayer
	local equippedAttr = player:GetAttribute("EquippedItem")
	if equippedAttr and type(equippedAttr) == "string" and equippedAttr ~= "" then
		held = equippedAttr
	end
	if held == "" then
		local char = player.Character
		if char then
			for _, c in ipairs(char:GetChildren()) do
				if c:IsA("Tool") then
					held = c.Name
					break
				end
			end
			if held == "" then
				local attr = char:GetAttribute("HeldItem") or char:GetAttribute("CurrentItem") or
				char:GetAttribute("EquippedItem")
				if attr and type(attr) == "string" then held = attr end
			end
		end
	end
	return held
end
do
	local _Config = {
		IgnorePatterns = {
			"idle", "walk", "run", "jog", "locomotion", "movement", "vaulting",
			"stand", "breathe", "loop", "pose", "core", "tool",
			"equip", "hold", "carry", "carrying", "grab", "jump", "fall",
			"hook", "hooking", "pickup", "lift", "throw", "place", "interact",
			"unhook", "unhooking", "exit", "exiting", "healing",
			"shoulder", "gendong", "pickup_survivor",
			"carryanim", "carry%-idle", "carry idle",
			"killercarry", "killercarryidle", "survivorcarry", "survivorcarryidle",
			"vault", "climb", "repair", "repairing",
			"pallet", "gen", "generator",
			"breaking", "breakgen", "breakpallet",
			"stun", "^clean$", "clean%-m", "jacket clean", "snake clean", "tony clean",
			"mask", "change", "swap", "hang", "sacrifice",
			"recover", "wipe", "taunt", "emote", "morph", "transform",
			"pain", "hurt", "stagger", "flinch", "impact", "blind", "reaction",
			"drop", "dropping", "searching", "looting", "opening", "closing",
			"locker", "barrel", "closet", "window",
			"reloading", "cooldown", "blood", "clean", "breathing",
			"sniff", "detect", "scan", "roar", "scream", "laugh",
			"stumble", "trip", "land", "slide", "sliding", "crouch",
			"inspect", "check", "weapon_check", "view", "idle_alt", "fidget",
			"unequip", "reload", "feint", "cancel",
			"sheathe", "holster", "checkweapon", "bloodwipe",
			"mori", "execution", "execute", "finish",
			"activate", "deactivate", "channel",
			"stalking", "stealth", "invisible", "invis",
			"evolve", "consume", "devour",
			"teleport", "blink", "warp", "phase",
			"frenzyidle", "frenzywalk", "frenzyend", "cleanfrenzy",
			"trap", "setup", "prepare",
			"mask equip", "maskequip",
			"sprint pic", "handup", "^hitbox$", "^test$",
			"alex idle", "alex run", "alex run legs",
			"snake idle", "tony idle", "jacket idle",
			"jason idle", "jeffidle", "jeffwalk",
		},
		IgnoreAnimIDs = {
			["130585295123651"] = true, ["102489115945356"] = true, ["128241974219045"] = true,
			["88658129956295"] = true, ["112772470739971"] = true, ["70489912882728"] = true,
			["119596435929738"] = true, ["84678759985652"] = true, ["125750702"] = true,
			["180436148"] = true, ["180436334"] = true, ["178130996"] = true,
			["180435571"] = true, ["180435792"] = true, ["182393478"] = true,
			["136962284480779"] = true, ["111354281712103"] = true, ["132353867344883"] = true,
			["107600098059627"] = true, ["81486769001455"] = true, ["112166042383605"] = true,
			["79965656177566"] = true, ["83873880822918"] = true, ["126081405469607"] = true,
			["95866729029878"] = true, ["126751859125353"] = true, ["71705121963639"] = true,
			["118019257172845"] = true, ["90019569445276"] = true, ["134008802601598"] = true,
			["130204431712716"] = true, ["95496519823325"] = true, ["90081592895693"] = true,
			["94178333159202"] = true, ["106198561585840"] = true, ["127223165212977"] = true,
			["108779263502039"] = true, ["78719043959654"] = true, ["126526181422628"] = true,
			["102273972677703"] = true, ["100367586546968"] = true, ["135388781922226"] = true,
			["123801171615428"] = true, ["134088840518889"] = true, ["137370559437980"] = true,
			["92303584765773"] = true, ["92099126728275"] = true, ["103299939715311"] = true,
			["97791520639443"] = true, ["110413686590821"] = true, ["98397448432071"] = true,
			["73255252744706"] = true, ["76822757630703"] = true, ["131249244284700"] = true,
			["182435998"] = true, ["182491037"] = true, ["182491065"] = true,
			["182436842"] = true, ["182491248"] = true, ["182491277"] = true,
			["182491368"] = true, ["182491423"] = true, ["182436935"] = true,
			["129423030"] = true, ["128777973"] = true, ["128853357"] = true,
			["129423131"] = true, ["129967390"] = true, ["129967478"] = true,
			["96930867285168"] = true, ["77483048584074"] = true, ["110392490296814"] = true,
			["108276889954601"] = true, ["114470049776971"] = true, ["110466971021611"] = true,
			["111223305405046"] = true, ["102055678391920"] = true, ["137846825408335"] = true,
			["119227871808602"] = true, ["88848807662765"] = true, ["109928123357793"] = true,
			["73681849513551"] = true, ["91021650846272"] = true, ["117070354890871"] = true,
			["136365031119137"] = true, ["110360975271091"] = true, ["92125118598365"] = true,
			["111229698330816"] = true, ["135029251763856"] = true, ["75762828906633"] = true,
			["92431623965655"] = true, ["123809268724645"] = true, ["135598697094633"] = true,
			["88454826739191"] = true, ["92098503722633"] = true, ["93136435416899"] = true,
			["84093948968516"] = true, ["86266790353635"] = true, ["138045669415653"] = true,
		},
		SkillAnimIDs = {
			["84093948968516"] = true, ["93136435416899"] = true, ["75258958842388"] = true,
			["134595759785108"] = true, ["72742711718023"] = true, ["80411309607666"] = true,
			["134758728973154"] = true, ["77477445889320"] = true, ["76744850905644"] = true,
			["74532620598483"] = true,
		},
		KnownAttackAnimIDs = {
			["78935059863801"]  = true, ["111920872708571"] = true, ["74968262036854"]  = true,
			["132817836308238"] = true, ["78432063483146"]  = true, ["133963973694098"] = true,
			["95934119190708"]  = true, ["139369275981139"] = true, ["117042998468241"] = true,
			["129918027564423"] = true, ["122812055447896"] = true, ["105374834496520"] = true,
			["113255068724446"] = true, ["129784271201071"] = true, ["118907603246885"] = true,
			["110355011987939"] = true, ["98163597193511"]  = true, ["82666958311998"]  = true,
			["80411309607666"]  = true, ["125224839697689"] = true, ["106871536134254"] = true,
			["109402730355822"] = true, ["138720291317243"] = true,
		},
		KillerSkillPatterns = {
			Veil = { "spear", "throw", "pierce", "reverie", "echo", "void", "between" },
			Masked = { "dash", "chainsaw", "sprint", "rushing" },
			Stalker = { "stalk", "consume", "evolve", "devour" },
			Hidden = { "secondary", "special", "m2" },
			Abysswalker = { "corrupt", "abyss", "darkness" },
			Killer = { "rage", "berserk", "fury" },
			Slasher = { "ability", "slam", "morph", "transition", "jason ability" },
		}
	}
	local function IsSkillAnimation(animName, killerType)
		if killerType == "Unknown" or not _Config.KillerSkillPatterns[killerType] then
			return false
		end
		local lowerName = animName:lower()
		for _, pattern in ipairs(_Config.KillerSkillPatterns[killerType]) do
			if lowerName:find(pattern) then return true end
		end
		return false
	end
	local ExtractAnimID
	do
		function ExtractAnimID(animIdStr)
			if not animIdStr then return nil end
			return tostring(animIdStr):match("%d+")
		end
	end
	local DetectKillerType
	do
		function DetectKillerType(killerChar)
			if not killerChar then return "Unknown" end
			local ok, result = pcall(function()
			if killerChar:GetAttribute("spearmode") ~= nil or killerChar:GetAttribute("Spears") ~= nil
			or killerChar:GetAttribute("BloodBetweenWorlds") ~= nil then
				return "Veil"
			end
			if killerChar:GetAttribute("Mask") ~= nil or killerChar:GetAttribute("Wep") ~= nil
			or killerChar:GetAttribute("oneshot") ~= nil then
				return "Masked"
			end
			if killerChar:GetAttribute("Hidden") ~= nil then
				if killerChar:GetAttribute("IsStunned") ~= nil and killerChar:GetAttribute("isMoving") ~= nil then
					local name = killerChar.Name:lower()
					if name:find("stalk") then return "Stalker" end
					return "Hidden"
				end
				return "Stalker"
			end
			local name = killerChar.Name:lower()
			if name:find("abyss") then return "Abysswalker" end
			if name:find("veil") then return "Veil" end
			if name:find("mask") then return "Masked" end
			if name:find("hidden") then return "Hidden" end
			if name:find("stalk") then return "Stalker" end
			if name:find("jason") or name:find("slasher") then return "Slasher" end
			if name:find("jeff") then return "Killer" end
			if name:find("mayer") then return "Mayers" end
			local player = game:GetService("Players"):GetPlayerFromCharacter(killerChar)
			if player then
				local sel = (player:GetAttribute("SelectedKiller") or ""):lower()
				if sel:find("jason") or sel:find("slasher") then return "Slasher" end
				if sel:find("jeff") or sel == "killer" then return "Killer" end
				if sel:find("veil") then return "Veil" end
				if sel:find("mask") then return "Masked" end
				if sel:find("stalk") then return "Stalker" end
				if sel:find("hidden") then return "Hidden" end
				if sel:find("abyss") then return "Abysswalker" end
				if sel:find("mayer") then return "Mayers" end
			end
			return "Unknown"
		end)
		return ok and result or "Unknown"
		end
	end
GFS._interactableCache = {}
GFS._interactableCacheTime = 0
local function UpdateInteractableCache()
	if tick() - GFS._interactableCacheTime < 3 then return end
	GFS._interactableCacheTime = tick()
	GFS._interactableCache = {}
	pcall(function()
	for _, obj in ipairs(workspace:GetDescendants()) do
		local n = obj.Name
		if n == "Pallet" or n == "Generator" or n == "Generator_Old"
		or n == "Vault" or n == "Window" or n == "VaultSpot" then
			local mainPart = obj:FindFirstChild("Main")
			if mainPart and mainPart:IsA("BasePart") then
				table.insert(GFS._interactableCache, mainPart)
			elseif obj:IsA("BasePart") then
				table.insert(GFS._interactableCache, obj)
			elseif obj:IsA("Model") and obj.PrimaryPart then
				table.insert(GFS._interactableCache, obj.PrimaryPart)
			end
		end
	end
end)
end
local function IsKillerNearInteractable(killerRoot)
	if not killerRoot then return false end
	UpdateInteractableCache()
	local killerPos = killerRoot.Position
	local killerLook = killerRoot.CFrame.LookVector
	for _, part in ipairs(GFS._interactableCache) do
		if part and part.Parent then
			local dist = (part.Position - killerPos).Magnitude
			if dist < 5 then
				local toObj = (part.Position - killerPos).Unit
				local dot = killerLook:Dot(toObj)
				if dot > 0.6 then
					return true
				end
			end
		end
	end
	return false
end
GFS._CrouchDodgeAnimIDs = {
["80411309607666"] = true,
}
	local ServerCrouch, IsDaggerReady
	do
		function ServerCrouch(state)
			pcall(function()
			local char = LocalPlayer.Character
			if char then
				char:SetAttribute("Crouching", state)
				char:SetAttribute("Crouchingserver", state)
			end
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			if not remotes then return end
			if state then
				local emoteHandler = remotes:FindFirstChild("EmoteHandler")
				if emoteHandler then
					emoteHandler:FireServer("StopEmote")
				end
			end
			local mechanics = remotes:FindFirstChild("Mechanics")
			if mechanics then
				local changeAttr = mechanics:FindFirstChild("ChangeAttribute")
				if changeAttr then
					changeAttr:FireServer("Crouchingserver", state)
				end
			end
		end)
		end
		function IsDaggerReady()
			if GFS.DaggerCooldownEnd then
				if tick() < GFS.DaggerCooldownEnd then return false end
				return true
			end
			if _G.ParryUICache and _G.ParryUICache.Gradient then
				local ok, result = pcall(function()
				local bar = _G.ParryUICache.Bar
				if bar and bar.ImageTransparency > 0.5 then return true end
				local y = _G.ParryUICache.Gradient.Offset.Y
				local progress = (GFS.DAGGER_GRAD_START - y) / GFS.DAGGER_GRAD_RANGE
				return math.clamp(progress, 0, 1) >= GFS.GRADIENT_READY_THRESHOLD
			end)
			if ok then return result end
			_G.ParryUICache.Gradient = nil
		end
		return true
		end
	end
local function AutoParry()
	if not GFS.AutoParryEnabled then return end
	local DaggerAssetID = "rbxassetid://76822757630703"
	if not _G.NextParryItemCheck or tick() >= _G.NextParryItemCheck then
		_G.NextParryItemCheck = tick() + 0.5
		local heldName = GetLocalHeldItem()
		local asset = NormalizedLookupAsset(ItemImageAssets, heldName)
		_G.CachedHasDagger = (asset == DaggerAssetID)
	end
	local hasDagger = _G.CachedHasDagger
	if hasDagger == nil then hasDagger = true end
	if not hasDagger then
		return
	end
	if not IsDaggerReady() then return end
	local globalCooldown = tick() - (_G.LastParryExecuted or 0)
	if globalCooldown < 0.1 then return end
	if tick() - GFS.LastParryTime < 0.1 then return end
	local myRole = DetectMyRole()
	if myRole ~= "Survivor" then return end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and IsKiller(player) and player.Character then
			local killerChar = player.Character
			local killerRoot = killerChar:FindFirstChild("HumanoidRootPart")
			local killerHumanoid = killerChar:FindFirstChildOfClass("Humanoid")
			if killerRoot and killerHumanoid then
				local dist = (killerRoot.Position - root.Position).Magnitude
				local effectiveDist = GFS.AutoParryDistance
				local _lt = GFS._killerLungeState[player.Name]
				if _lt and (tick() - _lt) < 1.5 then
					effectiveDist = GFS.AutoParryDistance + GFS._LUNGE_EXTRA_RANGE
				end
				if dist <= effectiveDist then
					local killerKey = player.Name
					if not _G.ParryKillerStates[killerKey] then
						_G.ParryKillerStates[killerKey] = {
						lastAnimId = nil,
						lastParryTime = 0,
						attackCount = 0
						}
					end
					local killerState = _G.ParryKillerStates[killerKey]
					local shouldParry = false
					local detectedAnimId = nil
					local killerType = DetectKillerType(killerChar)
					local nearInteractable = IsKillerNearInteractable(killerRoot)
					if not nearInteractable then
						pcall(function()
						local animator = killerHumanoid:FindFirstChildOfClass("Animator")
						if animator then
							local tracks = animator:GetPlayingAnimationTracks()
							for _, track in pairs(tracks) do
								if track.IsPlaying and track.Animation then
									local animName = (track.Name or ""):lower()
									local animId = tostring(track.Animation.AnimationId or "")
									local numericId = ExtractAnimID(animId)
									if numericId and GFS._LungeHoldAnimIDs[numericId] then
										GFS._killerLungeState[killerKey] = tick()
									end
									local shouldIgnore = false
									if numericId and _AutoParryIgnoreAnimIDs[numericId] then
										shouldIgnore = true
									end
									if not shouldIgnore and numericId and _SkillAnimIDs[numericId] then
										if GFS.IgnoredKillerSkills and GFS.IgnoredKillerSkills[killerType] then
											shouldIgnore = true
										end
									end
									local isKnownAttack = false
									if not shouldIgnore and numericId then
										isKnownAttack = _KnownAttackAnimIDs[numericId] or false
									end
									if not shouldIgnore and not isKnownAttack and animName ~= "animation" then
										for _, pattern in ipairs(_AutoParryIgnorePatterns) do
											if animName:find(pattern) then
												shouldIgnore = true
												break
											end
										end
										if not shouldIgnore then
											if GFS.IgnoredKillerSkills and GFS.IgnoredKillerSkills[killerType] then
												if IsSkillAnimation(track.Name or "", killerType) then
													shouldIgnore = true
												end
											end
										end
									end
									if not shouldIgnore and not isKnownAttack then
										if track.Looped then
											shouldIgnore = true
										end
										if not shouldIgnore and (track.Length > 3.0 or track.Length < 0.08) then
											shouldIgnore = true
										end
									end
									if not shouldIgnore then
										local isDuplicate = (animId == killerState.lastAnimId) and
										(tick() - killerState.lastParryTime < 0.2)
										if not isDuplicate then
											if GFS._IsKillerFacingPlayer(killerRoot, root, player.Name) then
												if not HasLineOfSight(root, killerRoot, char, killerChar) then
													break
												end
												shouldParry = true
												detectedAnimId = animId
												break
											end
										end
									end
								end
							end
						end
					end)
				end
				if shouldParry and detectedAnimId then
					pcall(function()
					if not (GFS.DaggerCooldownEnd and tick() >= GFS.DaggerCooldownEnd) then
						local _gradReady = true
						if _G.ParryUICache and _G.ParryUICache.Gradient then
							local _gOk, _gRes = pcall(function()
							local y = _G.ParryUICache.Gradient.Offset.Y
							local progress = (GFS.DAGGER_GRAD_START - y) / GFS.DAGGER_GRAD_RANGE
							return math.clamp(progress, 0, 1) >= GFS.GRADIENT_READY_THRESHOLD
						end)
						if _gOk then _gradReady = _gRes end
						if not _gOk then _G.ParryUICache.Gradient = nil end
					end
					if not _gradReady then return end
				end
				killerState.lastAnimId = detectedAnimId
				killerState.lastParryTime = tick()
				killerState.attackCount = killerState.attackCount + 1
				if _G.InputHelper and _G.InputHelper.TriggerParry then
					_G.InputHelper.TriggerParry()
				else
					local remote = GetParryRemote(false)
					if remote and remote:IsA("RemoteEvent") then
						remote:FireServer()
					end
				end
				GFS.LastParryTime = tick()
				_G.LastParryExecuted = tick()
				GFS.DaggerCooldownEnd = tick() + (GFS.ParryCooldownDuration or 1.5)
				if GFS.AutoParryDebug then
					local now = tick()
					if not _G.LastParrySuccessNotify or (now - _G.LastParrySuccessNotify > 1.0) then
						_G.LastParrySuccessNotify = now
						Library:Notify("Parried Attack! (" .. killerKey .. ")", 2)
					end
				end
			end)
			return
		end
	end
end
end
end
end
GFS._killerAnimConns = GFS._killerAnimConns or {}
GFS._lastEventParry = GFS._lastEventParry or 0
GFS._lastConnManage = GFS._lastConnManage or 0
GFS._LungeHoldAnimIDs = {
["117042998468241"] = true,
["129918027564423"] = true,
["122812055447896"] = true,
["105374834496520"] = true,
["113255068724446"] = true,
["129784271201071"] = true,
["118907603246885"] = true,
["110355011987939"] = true,
}
GFS._killerLungeState = {}
GFS._LUNGE_EXTRA_RANGE = 12
GFS._cachedKillerData = GFS._cachedKillerData or {}
GFS._cachedMyRoot = nil
GFS._cachedIsSurvivor = false
GFS._cachedHasDagger = true
GFS._wallCheckParams = GFS._wallCheckParams or RaycastParams.new()
GFS._wallCheckParams.FilterType = Enum.RaycastFilterType.Exclude
GFS._wallCheckParams.FilterDescendantsInstances = {}
local function HasLineOfSight(fromRoot, toRoot, fromChar, toChar)
	local origin = fromRoot.Position
	local direction = toRoot.Position - origin
	GFS._wallCheckParams.FilterDescendantsInstances = { fromChar, toChar }
	local result = workspace:Raycast(origin, direction, GFS._wallCheckParams)
	return result == nil
end
GFS._IsKillerFacingPlayer = function(kRoot, myRoot, killerName)
local toSurvivor = myRoot.Position - kRoot.Position
local killerLook = kRoot.CFrame.LookVector
if GFS.TrajectoryParryCheck then
	local along = toSurvivor:Dot(killerLook)
	if along <= 0 then return false end
	local perpDistSq = toSurvivor:Dot(toSurvivor) - along * along
	if perpDistSq < 0 then perpDistSq = 0 end
	local maxPerp = 4 - (GFS.TrajectoryHitRadius or 3)
	if killerName and GFS._killerLungeState[killerName] then
		if (tick() - GFS._killerLungeState[killerName]) < 1.5 then
			maxPerp = maxPerp + 4
		end
	end
	return perpDistSq <= maxPerp * maxPerp
else
	return killerLook:Dot(toSurvivor.Unit) >= (GFS.FaceKillerSensitivity or 0.1)
end
end
local function UpdateParryCache()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	GFS._cachedMyRoot = root
	GFS._cachedIsSurvivor = (DetectMyRole() == "Survivor")
	GFS._cachedHasDagger = (_G.CachedHasDagger == nil) and true or _G.CachedHasDagger
	if not root or not GFS._cachedIsSurvivor then
		GFS._cachedKillerData = {}
		return
	end
	local newCache = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and IsKiller(player) and player.Character then
			local kChar = player.Character
			local kRoot = kChar:FindFirstChild("HumanoidRootPart")
			local kHum = kChar:FindFirstChildOfClass("Humanoid")
			if kRoot and kHum then
				local dist = (kRoot.Position - root.Position).Magnitude
				local inRange = dist <= GFS.AutoParryDistance
				local nearInteractable = inRange and IsKillerNearInteractable(kRoot) or false
				local facingMe = false
				local lineOfSight = false
				if inRange and not nearInteractable then
					facingMe = GFS._IsKillerFacingPlayer(kRoot, root, player.Name)
					if facingMe then
						lineOfSight = HasLineOfSight(root, kRoot, char, kChar)
					end
				end
				newCache[player.Name] = {
				root = kRoot,
				char = kChar,
				hum = kHum,
				animator = kHum:FindFirstChildOfClass("Animator"),
				killerType = DetectKillerType(kChar),
				inRange = inRange,
				nearInteractable = nearInteractable,
				facingMe = facingMe,
				hasLineOfSight = lineOfSight,
				dist = dist,
				player = player,
				}
			end
		end
	end
	GFS._cachedKillerData = newCache
end
	local EventParryCheck, ConnectKillerAnim, DisconnectKillerAnim, DisconnectAllKillerAnims, ManageKillerAnimConnections, AutoParryWithEvents
	do
		function EventParryCheck(track, killerChar, player)
			if tick() - GFS._lastEventParry < 0.03 then return end
			if not GFS.AutoParryEnabled then return end
			local cached = GFS._cachedKillerData[player.Name]
			if not GFS._cachedIsSurvivor then return end
			local myChar = Players.LocalPlayer.Character
			if not myChar then return end
			local myRoot = myChar:FindFirstChild("HumanoidRootPart")
			if not myRoot then return end
			local kRoot = killerChar:FindFirstChild("HumanoidRootPart")
			if not kRoot then return end
			local _earlyNumericId = nil
			if track.Animation then
				_earlyNumericId = ExtractAnimID(tostring(track.Animation.AnimationId or ""))
			end
			if _earlyNumericId and GFS._LungeHoldAnimIDs[_earlyNumericId] then
				GFS._killerLungeState[player.Name] = tick()
			end
			local effectiveDist = GFS.AutoParryDistance
			local _lungeT = GFS._killerLungeState[player.Name]
			if _lungeT and (tick() - _lungeT) < 1.5 then
				effectiveDist = GFS.AutoParryDistance + GFS._LUNGE_EXTRA_RANGE
			end
			local dist = (kRoot.Position - myRoot.Position).Magnitude
			if dist > effectiveDist then return end
			if cached and cached.nearInteractable then return end
			if not cached then
				if IsKillerNearInteractable(kRoot) then return end
			end
			do
				if not GFS._IsKillerFacingPlayer(kRoot, myRoot, player.Name) then return end
			end
			if not HasLineOfSight(myRoot, kRoot, myChar, killerChar) then return end
			local now = tick()
			if GFS.DaggerCooldownEnd and now < GFS.DaggerCooldownEnd then return end
			if now - (_G.LastParryExecuted or 0) < 0.1 then return end
			if now - GFS.LastParryTime < 0.1 then return end
			if not track.Animation then return end
			local animId = tostring(track.Animation.AnimationId or "")
			local numericId = ExtractAnimID(animId)
			local killerType = (cached and cached.killerType) or DetectKillerType(killerChar)
			local animName = (track.Name or ""):lower()
			if numericId and _Config.IgnoreAnimIDs[numericId] then return end
			if numericId and _Config.SkillAnimIDs[numericId] then
				if GFS.IgnoredKillerSkills and GFS.IgnoredKillerSkills[killerType] then
					return
				end
			end
			local isKnownAttack = numericId and (_Config.KnownAttackAnimIDs[numericId] or false)
			if not isKnownAttack and animName ~= "animation" then
				for _, pattern in ipairs(_Config.IgnorePatterns) do
					if animName:find(pattern) then return end
				end
				if GFS.IgnoredKillerSkills and GFS.IgnoredKillerSkills[killerType] then
					if IsSkillAnimation(track.Name or "", killerType) then return end
				end
			end
			if not isKnownAttack then
				if track.Looped then return end
				if track.Length > 3.0 or track.Length < 0.08 then return end
				local s = 1
				pcall(function() s = track.Speed end)
				if s <= 0 then return end
			end
			local killerKey = player.Name
			if not _G.ParryKillerStates[killerKey] then
				_G.ParryKillerStates[killerKey] = { lastAnimId = nil, lastParryTime = 0, attackCount = 0 }
			end
			local ks = _G.ParryKillerStates[killerKey]
			if animId == ks.lastAnimId and tick() - ks.lastParryTime < 0.2 then return end
			if not (GFS.DaggerCooldownEnd and now >= GFS.DaggerCooldownEnd) then
				local _gradReady = true
				if _G.ParryUICache and _G.ParryUICache.Gradient then
					local _gOk, _gRes = pcall(function()
					local y = _G.ParryUICache.Gradient.Offset.Y
					local progress = (GFS.DAGGER_GRAD_START - y) / GFS.DAGGER_GRAD_RANGE
					return math.clamp(progress, 0, 1) >= GFS.GRADIENT_READY_THRESHOLD
				end)
				if _gOk then _gradReady = _gRes end
				if not _gOk then _G.ParryUICache.Gradient = nil end
			end
			if not _gradReady then return end
		end
		GFS._lastEventParry = tick()
		ks.lastAnimId = animId
		ks.lastParryTime = tick()
		ks.attackCount = ks.attackCount + 1
		if _G.InputHelper and _G.InputHelper.TriggerParry then
			_G.InputHelper.TriggerParry()
		else
			local remote = GetParryRemote(false)
			if remote and remote:IsA("RemoteEvent") then
				remote:FireServer()
			end
		end
		GFS.LastParryTime = tick()
		_G.LastParryExecuted = tick()
		GFS.DaggerCooldownEnd = tick() + (GFS.ParryCooldownDuration or 1.5)
		if GFS.AutoParryDebug then
			local now = tick()
			if not _G.LastParrySuccessNotify or (now - _G.LastParrySuccessNotify > 1.0) then
				_G.LastParrySuccessNotify = now
				Library:Notify("[EVENT] Parried! (" .. killerKey .. ")", 2)
			end
		end
		end
		function ConnectKillerAnim(player)
			local name = player.Name
			if GFS._killerAnimConns[name] then return end
			local killerChar = player.Character
			if not killerChar then return end
			local hum = killerChar:FindFirstChildOfClass("Humanoid")
			if not hum then return end
			local animator = hum:FindFirstChildOfClass("Animator")
			if not animator then return end
			local conn = animator.AnimationPlayed:Connect(function(track)
			pcall(function()
			EventParryCheck(track, killerChar, player)
		end)
		end)
		GFS._killerAnimConns[name] = { conn = conn, char = killerChar }
		end
		function DisconnectKillerAnim(name)
			local entry = GFS._killerAnimConns[name]
			if entry then
				pcall(function() entry.conn:Disconnect() end)
				GFS._killerAnimConns[name] = nil
			end
		end
		function DisconnectAllKillerAnims()
			local names = {}
			for name in pairs(GFS._killerAnimConns) do
				table.insert(names, name)
			end
			for _, name in ipairs(names) do
				DisconnectKillerAnim(name)
			end
		end
		function ManageKillerAnimConnections()
			if not GFS.AutoParryEnabled then
				DisconnectAllKillerAnims()
				return
			end
			local char = LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root then
				DisconnectAllKillerAnims()
				return
			end
			if DetectMyRole() ~= "Survivor" then
				DisconnectAllKillerAnims()
				return
			end
			local inRange = {}
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and IsKiller(player) and player.Character then
					local kr = player.Character:FindFirstChild("HumanoidRootPart")
					if kr and (kr.Position - root.Position).Magnitude <= GFS.AutoParryDistance + GFS._LUNGE_EXTRA_RANGE + 10 then
						inRange[player.Name] = true
					end
				end
			end
			local toRemove = {}
			for name, entry in pairs(GFS._killerAnimConns) do
				if not inRange[name] then
					table.insert(toRemove, name)
				else
					local p = Players:FindFirstChild(name)
					if p and entry.char ~= p.Character then
						table.insert(toRemove, name)
					end
				end
			end
			for _, name in ipairs(toRemove) do
				DisconnectKillerAnim(name)
			end
			local connectedNew = false
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and IsKiller(player) and inRange[player.Name] then
					if not GFS._killerAnimConns[player.Name] then
						ConnectKillerAnim(player)
						connectedNew = true
					end
				end
			end
			if GFS.AutoParryDebug and connectedNew then
				local count = 0
				for _ in pairs(GFS._killerAnimConns) do count = count + 1 end
				Library:Notify("[EVENT] Connected to " .. count .. " killer animator(s)", 2)
			end
		end
		function AutoParryWithEvents()
			pcall(UpdateParryCache)
			if tick() - GFS._lastConnManage >= 0.3 then
				GFS._lastConnManage = tick()
				pcall(ManageKillerAnimConnections)
			end
			if tick() - GFS._lastEventParry < 0.03 then return end
			pcall(AutoParry)
		end
	end
	GFS.AutoParryFn = AutoParryWithEvents
	GFS.ServerCrouch = ServerCrouch
	GFS._ExtractAnimID = ExtractAnimID
	GFS._AutoParryIgnoreAnimIDs = _Config.IgnoreAnimIDs
	GFS._SkillAnimIDs = _Config.SkillAnimIDs
	GFS._KnownAttackAnimIDs = _Config.KnownAttackAnimIDs
	GFS._DetectKillerType = DetectKillerType
	GFS._IsKillerNearInteractable = IsKillerNearInteractable
	GFS._DisconnectAllKillerAnims = DisconnectAllKillerAnims
	GFS._UpdateParryCacheRef = UpdateParryCache
end
do
	local function AutoWiggle()
		if not GFS.AutoWiggleEnabled then return end
		if tick() - GFS.LastWiggleTime < 0.1 then return end
		local myRole = DetectMyRole()
		if myRole ~= "Survivor" then return end
		local char = LocalPlayer.Character
		if not char then return end
		if char:GetAttribute("Hooked") then return end
		local isCarried = false
		if LocalPlayer.Character then
			isCarried = LocalPlayer.Character:GetAttribute("Carried") or
			LocalPlayer.Character:GetAttribute("IsCarried") or
			LocalPlayer.Character:GetAttribute("BeingCarried")
			local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum:GetState() == Enum.HumanoidStateType.Physics then
				isCarried = true
			end
		end
		if not isCarried then return end
		pcall(function()
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		if remotes then
			local wiggled = false
			local carry = remotes:FindFirstChild("Carry")
			if carry then
				local drop = carry:FindFirstChild("DropSurvivorEvent")
				if drop and drop:IsA("RemoteEvent") then
					drop:FireServer()
				end
			end
			if carry then
				local selfUnhook = carry:FindFirstChild("SelfUnHookEvent") or
				carry:FindFirstChild("Wiggle") or
				carry:FindFirstChild("Struggle")
				if selfUnhook and selfUnhook:IsA("RemoteEvent") then
					selfUnhook:FireServer()
					GFS.LastWiggleTime = tick()
					wiggled = true
				end
			end
			if not wiggled then
				local wiggleEvent = remotes:FindFirstChild("Wiggle") or
				remotes:FindFirstChild("Struggle")
				if wiggleEvent and wiggleEvent:IsA("RemoteEvent") then
					wiggleEvent:FireServer()
					GFS.LastWiggleTime = tick()
				end
			end
		end
	end)
end
local function SetupAntiBlind()
	if GFS.AntiBlindSetup then return end
	pcall(function()
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	if not remotes then return end
	local items = remotes:FindFirstChild("Items")
	if not items then return end
	local flashlight = items:FindFirstChild("Flashlight")
	if not flashlight then return end
	local gotBlinded = flashlight:FindFirstChild("GotBlinded")
	if gotBlinded and gotBlinded:IsA("RemoteEvent") then
		local oldFire = gotBlinded.FireServer
		gotBlinded.FireServer = function(self, ...)
		if GFS.AntiBlindEnabled and DetectMyRole() == "Killer" then
			return nil
		end
		return oldFire(self, ...)
	end
	GFS.AntiBlindSetup = true
	Library:Notify("Anti Blind: Setup complete", 2)
end
end)
end
local function SetupNoSlowdown()
	if GFS.NoSlowdownSetup then return end
	pcall(function()
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	if remotes then
		local mechanics = remotes:FindFirstChild("Mechanics")
		if mechanics then
			local slow = mechanics:FindFirstChild("Slowserver")
			if slow and slow:IsA("RemoteEvent") then
				local oldFire = slow.FireServer
				slow.FireServer = function(self, ...)
				if GFS.NoSlowdownEnabled and DetectMyRole() == "Killer" then
					return nil
				end
				return oldFire(self, ...)
			end
			GFS.NoSlowdownSetup = true
			Library:Notify("No Slowdown: Hooked!", 2)
		end
	end
end
end)
end
local function SetupMuteHook()
	if GFS.MuteHookInstalled then return end
	pcall(function()
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	if remotes then
		local mechanics = remotes:FindFirstChild("Mechanics")
		if mechanics then
			local sfx = mechanics:FindFirstChild("PlaySFX")
			if sfx and sfx:IsA("RemoteEvent") then
				local oldFire = sfx.FireServer
				sfx.FireServer = function(self, ...)
				if GFS.MuteHitSoundEnabled and DetectMyRole() == "Killer" then
					return nil
				end
				return oldFire(self, ...)
			end
		end
	end
end
end)
local function checkAndMute(instance)
	if not GFS.MuteHitSoundEnabled then return end
	if instance:IsA("Sound") then
		local soundName = instance.Name:lower()
		if soundName:find("hit") or soundName:find("swing") or soundName:find("attack") or
		soundName:find("flesh") or soundName:find("impact") or soundName:find("slash") or
		soundName:find("blade") or soundName:find("weapon") or soundName:find("sfx") or
		soundName:find("scream") or soundName:find("grunt") then
			if instance.Playing or instance.Volume > 0 then
				instance.Volume = 0
				instance.Playing = false
			end
			if not instance:GetAttribute("StarshipMuted") then
				instance:SetAttribute("StarshipMuted", true)
				instance:GetPropertyChangedSignal("Playing"):Connect(function()
				if GFS.MuteHitSoundEnabled and instance.Playing then
					instance.Playing = false
					instance.Volume = 0
				end
			end)
		end
	end
end
end
local function monitorFolder(folder)
	if not folder then return end
	folder.ChildAdded:Connect(checkAndMute)
	for _, child in ipairs(folder:GetChildren()) do
		checkAndMute(child)
	end
end
if LocalPlayer.Character then
	LocalPlayer.Character.DescendantAdded:Connect(checkAndMute)
	for _, desc in ipairs(LocalPlayer.Character:GetDescendants()) do
		checkAndMute(desc)
	end
end
LocalPlayer.CharacterAdded:Connect(function(char)
char.DescendantAdded:Connect(checkAndMute)
end)
monitorFolder(game:GetService("SoundService"))
task.spawn(function()
while true do
	if GFS.MuteHitSoundEnabled then
		local soundService = game:GetService("SoundService")
		if soundService then
			for _, s in ipairs(soundService:GetDescendants()) do
				checkAndMute(s)
			end
		end
		if LocalPlayer.Character then
			for _, s in ipairs(LocalPlayer.Character:GetDescendants()) do
				if s:IsA("Sound") and s.Playing then
					checkAndMute(s)
				end
			end
		end
	end
	task.wait(0.2)
end
end)
GFS.MuteHookInstalled = true
Library:Notify("Silent Hit: Setup complete", 2)
end
local function AutoAttack()
	if not GFS.AutoAttackEnabled then return end
	if DetectMyRole() ~= "Killer" then return end
	SetupMuteHook()
	if not GFS.AutoAttackInstant and tick() - GFS.LastAutoAttackTime < GFS.AutoAttackDelay then return end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			local name = track.Animation.Name:lower()
			if name:find("attack") or name:find("swing") or name:find("hit") or name:find("slash") then
				track:AdjustSpeed(0)
				track:Stop()
			end
		end
	end
	hum:ChangeState(Enum.HumanoidStateType.Running)
	if hum.WalkSpeed < 16 then
		hum.WalkSpeed = 16
	end
	if GFS.AutoAttackAnimationFix then
		local cam = workspace.CurrentCamera
		local moveDir = Vector3.zero
		local isMoving = false
		local uis = game:GetService("UserInputService")
		if uis:IsKeyDown(Enum.KeyCode.W) then
			moveDir = moveDir + cam.CFrame.LookVector
			isMoving = true
		end
		if uis:IsKeyDown(Enum.KeyCode.S) then
			moveDir = moveDir - cam.CFrame.LookVector
			isMoving = true
		end
		if uis:IsKeyDown(Enum.KeyCode.A) then
			moveDir = moveDir - cam.CFrame.RightVector
			isMoving = true
		end
		if uis:IsKeyDown(Enum.KeyCode.D) then
			moveDir = moveDir + cam.CFrame.RightVector
			isMoving = true
		end
		if isMoving then
			moveDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
			local speed = hum.WalkSpeed
			if speed < 16 then speed = 16 end
			local bv = root:FindFirstChild("KillAuraFixVel") or Instance.new("BodyVelocity")
			bv.Name = "KillAuraFixVel"
			bv.MaxForce = Vector3.new(100000, 0, 100000)
			bv.Velocity = moveDir * speed
			bv.Parent = root
			game:GetService("Debris"):AddItem(bv, 0.1)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and not IsKiller(player) and player.Character then
			local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local dist = (targetRoot.Position - root.Position).Magnitude
				if dist <= GFS.AutoAttackRange then
					if GFS.AutoAttackMode == 'Teleport' and root and targetRoot then
						local oldCF = root.CFrame
						root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 2)
						task.wait(0.05)
					end
					pcall(function()
					local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
					if remotes then
						local attacks = remotes:FindFirstChild("Attacks")
						if attacks then
							local basicAttack = attacks:FindFirstChild("BasicAttack")
							if basicAttack and basicAttack:IsA("RemoteEvent") then
								for i = 1, GFS.AutoAttackHitCount do
									basicAttack:FireServer(false)
								end
								GFS.LastAutoAttackTime = tick()
							end
							local hitRemote = attacks:FindFirstChild("hit")
							if hitRemote and hitRemote:IsA("RemoteEvent") then
								hitRemote:FireServer(player.Character)
							end
						end
					end
				end)
				if GFS.AutoAttackMode == 'Teleport' and root then
					root.CFrame = CFrame.new(root.Position, targetRoot.Position)
				end
				if not GFS.AutoAttackInstant then
					break
				end
			end
		end
	end
end
end
local function DoubleTapAttack()
	if not GFS.DoubleTapEnabled then return end
	if DetectMyRole() ~= "Killer" then return end
	if tick() - GFS.LastDoubleTapTime < 0.5 then return end
	local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and not IsKiller(player) and player.Character then
			local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local dist = (targetRoot.Position - root.Position).Magnitude
				if dist <= GFS.AutoAttackRange then
					pcall(function()
					local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
					if remotes then
						local attacks = remotes:FindFirstChild("Attacks")
						if attacks then
							local basicAttack = attacks:FindFirstChild("BasicAttack")
							if basicAttack and basicAttack:IsA("RemoteEvent") then
								basicAttack:FireServer(false)
								task.wait(0.05)
								basicAttack:FireServer(false)
								GFS.LastDoubleTapTime = tick()
							end
						end
					end
				end)
				break
			end
		end
	end
end
end
local function InstantEscape()
	if DetectMyRole() ~= "Survivor" then return end
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	if not remotes then return end
	local gameRemote = remotes:FindFirstChild("Game")
	if not gameRemote then return end
	local escape = gameRemote:FindFirstChild("Escape")
	if escape and escape:IsA("RemoteEvent") then
		escape:FireServer()
		Library:Notify("Instant Escape!", 3)
	else
		local escapeZone = workspace:FindFirstChild("EscapeZone")
		if escapeZone then
			if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
				LocalPlayer.Character.HumanoidRootPart.CFrame = escapeZone.CFrame
			end
		end
	end
end
local function AutoBreakLoop()
	while GFS.AutoBreakEnabled do
		if DetectMyRole() == "Killer" and LocalPlayer.Character then
			local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if root then
				for _, pallet in ipairs(workspace:GetDescendants()) do
					if pallet.Name == "Pallet" and pallet:FindFirstChild("Main") then
						local dist = (pallet.Main.Position - root.Position).Magnitude
						if dist < 10 then
							local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
							if remotes and remotes.Mechanics and remotes.Mechanics.Interact then
								remotes.Mechanics.Interact:FireServer(pallet, "Break")
							end
						end
					end
				end
				for _, gen in ipairs(workspace:GetDescendants()) do
					if (gen.Name == "Generator" or gen.Name == "Generator_Old") and gen:FindFirstChild("Main") then
						local dist = (gen.Main.Position - root.Position).Magnitude
						if dist < 10 then
							local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
							if remotes and remotes.Mechanics and remotes.Mechanics.Interact then
								remotes.Mechanics.Interact:FireServer(gen, "Damage")
							end
						end
					end
				end
			end
		end
		task.wait(0.5)
	end
end
GFS._cachedSpearTarget = nil
GFS._cachedSpearAimDir = nil
GFS._cachedSpearRemote = nil
GFS.Veil_HookInstalled = false
GFS._spearCacheFrame   = 0
function GFS.GetSpearRemote()
	if GFS._cachedSpearRemote then return GFS._cachedSpearRemote end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return nil end
	local items = remotes:FindFirstChild("Items")
	if items then
		local veil = items:FindFirstChild("Veil")
		if veil then
			local st = veil:FindFirstChild("Spearthrow")
			if st and st:IsA("RemoteEvent") then
				GFS._cachedSpearRemote = st; return st
			end
		end
	end
	local killers = remotes:FindFirstChild("Killers")
	if killers then
		local veil = killers:FindFirstChild("Veil")
		if veil then
			local st = veil:FindFirstChild("Spearthrow")
			if st and st:IsA("RemoteEvent") then
				GFS._cachedSpearRemote = st; return st
			end
		end
	end
	return nil
end
local function UpdateSpearAimCache()
	if not GFS.SpearAimbotEnabled then
		GFS._cachedSpearTarget = nil
		GFS._cachedSpearAimDir = nil
		return
	end
	GFS._spearCacheFrame = (GFS._spearCacheFrame or 0) + 1
	if GFS._spearCacheFrame < 2 then return end
	GFS._spearCacheFrame = 0
	if DetectMyRole() ~= "Killer" then
		GFS._cachedSpearTarget = nil
		GFS._cachedSpearAimDir = nil
		return
	end
	local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		GFS._cachedSpearTarget = nil; GFS._cachedSpearAimDir = nil; return
	end
	local closest, closestDist = nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and not IsKiller(player) and player.Character then
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
				if targetRoot then
					local dist = (targetRoot.Position - root.Position).Magnitude
					local canTarget = true
					if not GFS.SpearThruWallEnabled then
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						local excludeList = { LocalPlayer.Character, player.Character }
						params.FilterDescendantsInstances = excludeList
						local ray = workspace:Raycast(root.Position, (targetRoot.Position - root.Position), params)
						if ray then canTarget = false end
					end
					if canTarget and dist < closestDist then
						closestDist = dist
						closest = player
					end
				end
			end
		end
	end
	if closest and closest.Character then
		local targetRoot = closest.Character:FindFirstChild("HumanoidRootPart")
		local targetHum = closest.Character:FindFirstChildOfClass("Humanoid")
		if targetRoot then
			GFS._cachedSpearTarget = closest
			local startPos = root.Position + Vector3.new(0, 2, 0)
			local targetPos = targetRoot.Position + Vector3.new(0, -0.5, 0)
			local speed = GFS._lastSpearSpeed or GFS.SpearSpeed
			local moveVelocity = Vector3.zero
			if targetRoot.AssemblyLinearVelocity.Magnitude > 1 then
				local vel = targetRoot.AssemblyLinearVelocity
				moveVelocity = Vector3.new(vel.X, 0, vel.Z)
			elseif targetHum and targetHum.MoveDirection.Magnitude > 0.1 then
				local targetSpeed = targetHum.WalkSpeed or 16
				moveVelocity = targetHum.MoveDirection.Unit * targetSpeed
			end
			local aimPos = targetPos
			for _ = 1, 3 do
				local dist = (aimPos - startPos).Magnitude
				local t = dist / speed
				local predicted = targetPos + moveVelocity * t
				local gDrop = 0.5 * GFS.SpearGravity * t * t
				aimPos = predicted + Vector3.new(0, gDrop, 0)
			end
			GFS._cachedSpearAimDir = (aimPos - startPos).Unit
		else
			GFS._cachedSpearTarget = nil
			GFS._cachedSpearAimDir = nil
		end
	else
		GFS._cachedSpearTarget = nil
		GFS._cachedSpearAimDir = nil
	end
end
GFS.AutoWiggleFn = AutoWiggle
GFS.SetupAntiBlindFn = SetupAntiBlind
GFS.AutoAttackFn = AutoAttack
GFS.DoubleTapAttackFn = DoubleTapAttack
GFS.AutoBreakLoopFn = AutoBreakLoop
GFS.UpdateSpearAimCacheFn = UpdateSpearAimCache
end
do
	local snapLine = Drawing.new("Line")
	snapLine.Color = Color3.fromRGB(138, 43, 226)
	snapLine.Thickness = 1.5
	snapLine.Transparency = 0.7
	snapLine.Visible = false
	GFS._veilSnapLine = snapLine
	local dot = Drawing.new("Circle")
	dot.Color = Color3.fromRGB(138, 43, 226)
	dot.Thickness = 0
	dot.Filled = true
	dot.Radius = 5
	dot.Visible = false
	GFS._veilTargetDot = dot
	local outline = Drawing.new("Circle")
	outline.Color = Color3.fromRGB(255, 255, 255)
	outline.Thickness = 1.5
	outline.Filled = false
	outline.Radius = 7
	outline.Visible = false
	GFS._veilTargetOutline = outline
end
local function UpdateVeilVisuals()
	local sl = GFS._veilSnapLine
	local td = GFS._veilTargetDot
	local to = GFS._veilTargetOutline
	if not sl then return end
	if GFS.SpearAimbotEnabled and GFS._cachedSpearTarget then
		local char = GFS._cachedSpearTarget.Character
		if char then
			local targetRoot = char:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local cam = workspace.CurrentCamera
				local sp, onScreen = cam:WorldToViewportPoint(targetRoot.Position)
				if onScreen then
					local sp2d = Vector2.new(sp.X, sp.Y)
					if GFS.SpearSnaplineEnabled then
						sl.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
						sl.To = sp2d
						sl.Visible = true
					else
						sl.Visible = false
					end
					td.Position = sp2d
					td.Visible = true
					to.Position = sp2d
					to.Visible = true
					return
				end
			end
		end
	end
	sl.Visible = false
	td.Visible = false
	to.Visible = false
end
local GameFeaturesConnection = RunService.RenderStepped:Connect(function()
	_safeCall(GFS.AutoParryFn, 'AutoParry')
	if GFS._UpdateParryRadius then pcall(GFS._UpdateParryRadius) end
	_safeCall(GFS.AutoWiggleFn, 'AutoWiggle')
	_safeCall(GFS.UpdateSpearAimCacheFn, 'UpdateSpearAimCache')
	pcall(UpdateVeilVisuals)
	_safeCall(GFS.AutoAttackFn, 'AutoAttack')
	_safeCall(GFS.DoubleTapAttackFn, 'DoubleTapAttack')
	_safeCall(UpdateRadar, 'UpdateRadar')
end)
task.spawn(function()
RunService.RenderStepped:Connect(function()
if GFS.NoSlowdownEnabled and not GFS.FakeKnockEnabled and LocalPlayer.Character then
	local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
	if hum and hum.WalkSpeed < 16 then
		hum.WalkSpeed = 16
	end
end
end)
end)
task.spawn(function()
task.wait(1)
if DrawingAvailable then
	SafeInit(InitializeRadar, 'InitializeRadar')
end
end)
local Window = Library:CreateWindow({
    Title = "STARSHIP┃dsc.gg-starshipcore",
    Icon = "rbxassetid://85930777472774",
    IconSize = 45, 
    Author = "Premium Edition | StarshipCore",
    Center = true,
    AutoShow = true,
    Theme = "Crimson",
})

_G.Window = Window

if Window.SetUserProfile then
	Window:SetUserProfile({
	Name = LocalPlayer.DisplayName,
	UserId = LocalPlayer.UserId,
	Status = IsPremium and "Premium" or "Free",
	OnLogout = function()
        -- WindUI Unload is complex, just notify
        Library:Notify("Logout not supported in Boreal shim yet.", 3)
	end
    })
end

local Tabs = {
    Dashboard = Window:AddTab('Dashboard', 'layout-grid'),
    Account = Window:AddTab('Account', 'user'),
    Global = Window:AddTab('Elite', 'star'),
    Killer = Window:AddTab('Killer', 'swords'),
    Survivor = Window:AddTab('Survivor', 'shield'),
    AntiAim = Window:AddTab('Movement', 'navigation-2-off'),
    AutoTP = Window:AddTab('Auto TP', 'zap'),
    PlayerTP = Window:AddTab('Player TP', 'user'),
    ESP = Window:AddTab('ESP', 'eye'),
    Chams = Window:AddTab('Chams', 'users'),
    World = Window:AddTab('World', 'mountain'),
    Misc = Window:AddTab('Misc', 'chart-no-axes-gantt'),
    Settings = Window:AddTab('Config', 'settings'),
}

local InitKillerAlertScope
local InitSurvivorScripts
local function InitDashboardTab()
    local DashboardMain = Tabs.Dashboard:AddSection('Main Dashboard', 'house')
    
    -- Pro-style Welcome Card
    DashboardMain:AddParagraph({ 
        Title = '👤 Welcome back, ' .. (LocalPlayer.DisplayName or LocalPlayer.Name) .. '!',
        Desc = 'Starship Premium is fully active. All security protocols bypassed.'
    })

    DashboardMain:AddDivider()

    -- Subscription & Status Labels
    local roleDesc = IsPremium and "✨ PREMIUM EDITION" or "🆓 FREE EDITION"
    DashboardMain:AddLabel("Account: " .. roleDesc)
    DashboardMain:AddLabel("Status: 🟢 CONNECTED")
    DashboardMain:AddLabel("Build: " .. "v2.6.0 [STABLE]")
    
    DashboardMain:AddDivider()

    -- Performance Monitor (Update Real-time)
    local perfMonitor = DashboardMain:AddParagraph({
        Title = '📊 Live Performance',
        Desc = 'FPS: Calculating...\nPing: Calculating...\nSession Uptime: 00:00:00'
    })

    -- System Info (Hardware & Executor)
    local executor = (identifyexecutor and identifyexecutor()) or "Standard Executor"
    DashboardMain:AddParagraph({
        Title = '🛠️ System Details',
        Desc = string.format("Executor: %s\nPlatform: %s\nRegion: Global", 
            executor, UserInputService:GetPlatform().Name)
    })

    -- Task khusus untuk update statistik setiap detik
    local startTime = tick()
    task.spawn(function()
        while _G.StarshipActive do
            local waitOk, _ = pcall(function() RunService.RenderStepped:Wait() end)
            if not waitOk then task.wait(0.1) end
            
            -- Hitung FPS, Ping, dan Uptime
            local fps = math.floor(1 / (RunService.RenderStepped:Wait() or 0.016))
            local ping = 0
            pcall(function() 
                ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) 
            end)
            
            local uptime = math.floor(tick() - startTime)
            local h, m, s = math.floor(uptime/3600), math.floor((uptime%3600)/60), uptime%60
            
            -- Update teks di UI secara dinamis
            pcall(function()
                if perfMonitor and perfMonitor.SetDesc then
                    perfMonitor:SetDesc(string.format("FPS: %d | Ping: %d ms\nSession Uptime: %02d:%02d:%02d", 
                        fps, ping, h, m, s))
                end
            end)
            task.wait(1)
        end
    end)

    -- Section Aksi Cepat
    local DashboardActions = Tabs.Dashboard:AddSection('Quick Interactions', 'zap')
    
    DashboardActions:AddButton({
        Text = '📋 Copy Community Discord',
        Func = function()
            if setclipboard then
                setclipboard("https://dsc.gg/starshipcore")
                Library:Notify("Discord link copied to clipboard!")
            end
        end
    })

    DashboardActions:AddButton({
        Text = '🔄 Rejoin Server',
        Func = function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end
    })

    DashboardActions:AddDivider()
    
    DashboardActions:AddButton({
        Text = '⚠️ Unload Starship',
        Func = function()
            Library:Unload()
        end
    })

    pcall(function() Tabs.Dashboard.Tab:Select() end)
end

local function InitAccountTab()
    local VIPSection = Tabs.Account:AddSection('VIP Status', 'star')
    
    local vipExpiryTime = nil
    if sessionData.Expiry then
        vipExpiryTime = tonumber(sessionData.Expiry)
    else
        vipExpiryTime = ParseVIPExpiry(sessionData.Duration)
        sessionData.Expiry = vipExpiryTime -- Persist it globally!
    end

    local function GetVIPStatusDesc()
        local timeRemaining = "Lifetime"
        if vipExpiryTime then
            local remaining = vipExpiryTime - os.time()
            timeRemaining = FormatTimeRemaining(remaining)
        end
        return "Role: " .. FormatRole(sessionData.Role) .. "\n" ..
               "Time Remaining: " .. timeRemaining .. "\n" ..
               "Status: Active"
    end

    local vipPara = VIPSection:AddParagraph({
        Title = 'Subscription Information',
        Desc = GetVIPStatusDesc()
    })

    if vipExpiryTime then
        task.spawn(function()
            while _G.StarshipActive do
                task.wait(1)
                pcall(function()
                    if vipPara then
                        vipPara:SetDesc(GetVIPStatusDesc())
                    end
                end)
                if (vipExpiryTime - os.time()) <= 0 then break end
            end
        end)
    end

    local ProfileSection = Tabs.Account:AddSection('User Profile', 'user-round')
    ProfileSection:AddParagraph({
        Title = LocalPlayer.DisplayName,
        Desc = 'Username: ' .. LocalPlayer.Name .. '\n' ..
               'User ID: ' .. LocalPlayer.UserId .. '\n' ..
               'Account Age: ' .. LocalPlayer.AccountAge .. ' days'
    })
end

local function InitGlobalTab()
	local GlobalMainBox = Tabs.Global:AddLeftGroupbox('Exploits', 'shield-alert')
	GFS.UndergroundInvisEnabled = false
	GFS.UndergroundInvisLoop = nil
	GFS.UndergroundInvisVisuals = nil
	local NAN = 0 / 0
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LookRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Game"):WaitForChild("UpdateCharacterLook")
	local function ApplyUndergroundInvis()
		if not LocalPlayer.Character then return end
		local VoidCFrame = CFrame.new(0, -500, 0, NAN, NAN, NAN, NAN, NAN, NAN, NAN, NAN, NAN)
		pcall(function()
		LookRemote:FireServer(VoidCFrame, VoidCFrame, VoidCFrame)
	end)
end
local function UpdateVisuals()
	local char = LocalPlayer.Character
	if not char then return end
	local cam = workspace.CurrentCamera
	local head = char:FindFirstChild("Head")
	local isFirstPerson = false
	if LocalPlayer:GetAttribute("Role") == "Killer" then
		isFirstPerson = true
	end
	if not isFirstPerson and head and cam and (cam.CFrame.Position - head.Position).Magnitude < 4.0 then
		isFirstPerson = true
	end
	for _, v in pairs(char:GetDescendants()) do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			local distToCam = (cam.CFrame.Position - v.Position).Magnitude
			local isObstructing = (distToCam < 2.5)
			if v.Name:lower():find("arm") or v.Name:lower():find("hand") or v.Name:lower():find("weapon") then
				isObstructing = false
			end
			local isFace = (v.Name == "Head" or v.Name == "Mask" or v.Name == "Face" or v.Parent:IsA("Accessory") or v.Parent:IsA("Hat"))
			if (isFirstPerson and isFace) or isObstructing then
				v.LocalTransparencyModifier = 1
			else
				v.LocalTransparencyModifier = 0.5
			end
		end
	end
	local hl = char:FindFirstChild("Starship_Final_FX")
	if not hl then
		hl = Instance.new("Highlight")
		hl.Name = "Starship_Final_FX"
		hl.Parent = char
		hl.FillTransparency = 0.5
		hl.OutlineTransparency = 0
	end
	if isFirstPerson then
		hl.Enabled = false
	else
		hl.Enabled = true
		if Options.InvisFillColor then
			hl.FillColor = Options.InvisFillColor.Value
			hl.FillTransparency = Options.InvisFillColor.Transparency
		else
			hl.FillColor = Color3.fromRGB(0, 170, 255)
			hl.FillTransparency = 0.5
		end
		if Options.InvisOutlineColor then
			hl.OutlineColor = Options.InvisOutlineColor.Value
			hl.OutlineTransparency = Options.InvisOutlineColor.Transparency
		else
			hl.OutlineColor = Color3.fromRGB(255, 255, 255)
			hl.OutlineTransparency = 0
		end
	end
end
local function CleanupVisuals()
	local char = LocalPlayer.Character
	if char then
		local hl = char:FindFirstChild("Starship_Final_FX")
		if hl then hl:Destroy() end
		local oldHl = char:FindFirstChild("Starship_Visual")
		if oldHl then oldHl:Destroy() end
		local cam = workspace.CurrentCamera
		local head = char:FindFirstChild("Head")
		local isFirstPerson = false
		if LocalPlayer:GetAttribute("Role") == "Killer" then
			isFirstPerson = true
		end
		if not isFirstPerson and head and cam and (cam.CFrame.Position - head.Position).Magnitude < 4.0 then
			isFirstPerson = true
		end
		for _, v in pairs(char:GetDescendants()) do
			if v:IsA("BasePart") then
				local distToCam = (cam.CFrame.Position - v.Position).Magnitude
				local isObstructing = (distToCam < 2.5)
				if v.Name:lower():find("arm") or v.Name:lower():find("hand") or v.Name:lower():find("weapon") then
					isObstructing = false
				end
				local isFace = (v.Name == "Head" or v.Name == "Mask" or v.Name == "Face" or v.Parent:IsA("Accessory") or v.Parent:IsA("Hat"))
				if (isFirstPerson and isFace) or isObstructing then
					v.LocalTransparencyModifier = 1
				else
					v.LocalTransparencyModifier = 0
				end
			end
		end
	end
end
_G.EnableInvisibilityForAntiCamp = function()
if GFS.UndergroundInvisEnabled then return end
GFS.UndergroundInvisEnabled = true
GFS.InvisEnabledByAntiCamp = true
task.spawn(function()
while GFS.UndergroundInvisEnabled and GFS.InvisEnabledByAntiCamp do
	ApplyUndergroundInvis()
	task.wait()
end
end)
if GFS.UndergroundInvisVisuals then GFS.UndergroundInvisVisuals:Disconnect() end
GFS.UndergroundInvisVisuals = RunService.RenderStepped:Connect(function()
if not GFS.UndergroundInvisEnabled then return end
UpdateVisuals()
end)
end
_G.DisableInvisibilityForAntiCamp = function()
if not GFS.InvisEnabledByAntiCamp then return end
GFS.InvisEnabledByAntiCamp = false
GFS.UndergroundInvisEnabled = false
if GFS.UndergroundInvisVisuals then
	GFS.UndergroundInvisVisuals:Disconnect()
	GFS.UndergroundInvisVisuals = nil
end
CleanupVisuals()
end
local InvisToggle = GlobalMainBox:AddToggle('UndergroundInvisToggle', {
Text = 'Invisibility',
Default = false,
Tooltip = IsPremium and 'Makes you completely invisible to other players from their perspective.',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.UndergroundInvisEnabled = Value
if Value then
	task.spawn(function()
	while GFS.UndergroundInvisEnabled do
		ApplyUndergroundInvis()
		task.wait()
	end
end)
if GFS.UndergroundInvisVisuals then GFS.UndergroundInvisVisuals:Disconnect() end
GFS.UndergroundInvisVisuals = RunService.RenderStepped:Connect(function()
if not GFS.UndergroundInvisEnabled then return end
UpdateVisuals()
end)
Library:Notify("Invisibility: Enabled", 2)
else
	if GFS.UndergroundInvisVisuals then
		GFS.UndergroundInvisVisuals:Disconnect()
		GFS.UndergroundInvisVisuals = nil
	end
	CleanupVisuals()
	Library:Notify("Invisibility: Disabled", 2)
end
end
})
InvisToggle:AddColorPicker('InvisFillColor', {
Default = Color3.fromRGB(0, 170, 255),
Title = 'Visual Fill Color',
Transparency = 0.5,
})
InvisToggle:AddColorPicker('InvisOutlineColor', {
Default = Color3.fromRGB(255, 255, 255),
Title = 'Visual Outline Color',
Transparency = 0,
})
InvisToggle:AddKeyPicker('UndergroundInvisKey', {
Default = 'None',
SyncToggleState = true,
Mode = 'Toggle',
Text = 'Invisibility',
NoUI = false,
})
PremiumOnly(InvisToggle)
GFS.SpeedMultiplierEnforceConn = nil
GlobalMainBox:AddToggle('SpeedMultiplierToggle', {
Text = 'Speed Multiplier',
Default = false,
Tooltip = 'Multiplies your walk speed (works for Survivor & Killer, mobile-friendly)',
Callback = function(Value)
if Value then
	if LocalPlayer.Character then
		LocalPlayer.Character:SetAttribute("speedboost", Options.SpeedMultiplierSlider.Value)
	end
	if GFS.SpeedMultiplierEnforceConn then
		GFS.SpeedMultiplierEnforceConn:Disconnect()
	end
	GFS.SpeedMultiplierEnforceConn = RunService.Heartbeat:Connect(function()
	if not Toggles.SpeedMultiplierToggle or not Toggles.SpeedMultiplierToggle.Value then
		return
	end
	local char = LocalPlayer.Character
	if char then
		local currentBoost = char:GetAttribute("speedboost")
		local desiredBoost = Options.SpeedMultiplierSlider and Options.SpeedMultiplierSlider.Value or 1
		if currentBoost ~= desiredBoost then
			char:SetAttribute("speedboost", desiredBoost)
		end
	end
end)
Library:Notify('Speed Multiplier: Enabled (persistent)', 2)
else
	if GFS.SpeedMultiplierEnforceConn then
		GFS.SpeedMultiplierEnforceConn:Disconnect()
		GFS.SpeedMultiplierEnforceConn = nil
	end
	if LocalPlayer.Character then
		LocalPlayer.Character:SetAttribute("speedboost", 1)
	end
	Library:Notify('Speed Multiplier: Disabled', 2)
end
end
}):AddKeyPicker('SpeedMultiplierKey', {
Default = 'None',
Text = 'Speed Multiplier',
Mode = 'Toggle',
SyncToggleState = true
})
GlobalMainBox:AddSlider('SpeedMultiplierSlider', {
Text = 'Multiplier Amount',
Default = 1,
Min = 1,
Max = 5,
Rounding = 1,
Compact = true,
Callback = function(Value)
if Toggles.SpeedMultiplierToggle and Toggles.SpeedMultiplierToggle.Value and LocalPlayer.Character then
	LocalPlayer.Character:SetAttribute("speedboost", Value)
end
end
})
LocalPlayer.CharacterAdded:Connect(function(char)
task.wait(1)
if Toggles.SpeedMultiplierToggle and Toggles.SpeedMultiplierToggle.Value then
	char:SetAttribute("speedboost", Options.SpeedMultiplierSlider and Options.SpeedMultiplierSlider.Value or 1)
end
end)
GFS.InfiniteZoomEnabled = false
GlobalMainBox:AddToggle('InfiniteZoomToggle', {
Text = 'Infinite Zoom Out',
Default = false,
Tooltip = 'Allows you to zoom out infinitely past the normal camera limit.',
Callback = function(Value)
GFS.InfiniteZoomEnabled = Value
if Value then
	task.spawn(function()
	while GFS.InfiniteZoomEnabled do
		LocalPlayer.CameraMaxZoomDistance = 100000
		task.wait(1)
	end
	LocalPlayer.CameraMaxZoomDistance = 12.5
end)
Library:Notify('Infinite Zoom Out: Enabled', 2)
else
	LocalPlayer.CameraMaxZoomDistance = 12.5
	Library:Notify('Infinite Zoom Out: Disabled', 2)
end
end
})
end
InitDashboardTab()
InitAccountTab()
InitGlobalTab()
VDSurvivorState = VDSurvivorState or {}
InitSurvivorScripts = function()
local AbilityBox = Tabs.Survivor:AddLeftGroupbox('Ability', 'swords')
local AgilityBox = Tabs.Survivor:AddLeftGroupbox('Agility', 'rabbit')
local UtilityBox = Tabs.Survivor:AddLeftGroupbox('Utility', 'tool-case')
local antiChaseConnection = nil	
local antiChaseSoundConns = {}
local _chaseSoundIds = {
["rbxassetid://137561084283306"] = true,
["rbxassetid://130897230567008"] = true,
["rbxassetid://135525099756571"] = true,
}
local _chaseSoundNames = {
["hidden chase"] = true,
["veilchaseloop"] = true,
["heartbeat"] = true,
}
local function IsChaseSound(sound)
	if not sound or not sound:IsA("Sound") then return false end
	local id = tostring(sound.SoundId or ""):lower()
	if _chaseSoundIds[id] then return true end
	local name = (sound.Name or ""):lower()
	if _chaseSoundNames[name] then return true end
	if name:find("chase") then return true end
	return false
end
local function MuteChaseSound(sound)
	if IsChaseSound(sound) then
		sound.Volume = 0
		sound.Playing = false
		pcall(function() sound:Stop() end)
	end
end
local function ScanAndMuteAllChaseSounds()
	for _, obj in ipairs(workspace:GetDescendants()) do
		pcall(function() MuteChaseSound(obj) end)
	end
	pcall(function()
	local soundService = game:GetService("SoundService")
	for _, obj in ipairs(soundService:GetDescendants()) do
		pcall(function() MuteChaseSound(obj) end)
	end
end)
if LocalPlayer.Character then
	for _, obj in ipairs(LocalPlayer.Character:GetDescendants()) do
		pcall(function() MuteChaseSound(obj) end)
	end
end
end
AgilityBox:AddCheckbox('AntiChase', {
Text = 'Anti-Chase',
Default = false,
Tooltip = 'Blocks chase detection, chase music, and all chase sounds (jedag-jedug sound)',
Callback = function(Value)
if Value then
	ScanAndMuteAllChaseSounds()
	antiChaseConnection = RunService.Heartbeat:Connect(function()
	local char = LocalPlayer.Character
	if not char then return end
	if char:GetAttribute("IsChased") ~= false then
		pcall(function() char:SetAttribute("IsChased", false) end)
	end
	if char:GetAttribute("Chasemusic") ~= nil then
		pcall(function() char:SetAttribute("Chasemusic", 0) end)
	end
	for _, obj in ipairs(char:GetChildren()) do
		pcall(function() MuteChaseSound(obj) end)
	end
end)
local conn1 = workspace.DescendantAdded:Connect(function(obj)
task.defer(function() MuteChaseSound(obj) end)
end)
local conn2
pcall(function()
conn2 = game:GetService("SoundService").DescendantAdded:Connect(function(obj)
task.defer(function() MuteChaseSound(obj) end)
end)
end)
pcall(function()
for _, obj in ipairs(game:GetService("SoundService"):GetDescendants()) do
	MuteChaseSound(obj)
end
local cm = game:GetService("SoundService"):FindFirstChild("chase")
if cm and cm:IsA("Sound") then
	cm.Volume = 0
	pcall(function() cm:Stop() end)
end
end)
local conn3 = LocalPlayer.CharacterAdded:Connect(function(char)
task.wait(0.5)
for _, obj in ipairs(char:GetDescendants()) do
	pcall(function() MuteChaseSound(obj) end)
end
char.DescendantAdded:Connect(function(obj)
task.defer(function() MuteChaseSound(obj) end)
end)
end)
if LocalPlayer.Character then
	local conn4 = LocalPlayer.Character.DescendantAdded:Connect(function(obj)
	task.defer(function() MuteChaseSound(obj) end)
end)
table.insert(antiChaseSoundConns, conn4)
end
table.insert(antiChaseSoundConns, conn1)
if conn2 then table.insert(antiChaseSoundConns, conn2) end
table.insert(antiChaseSoundConns, conn3)
Library:Notify('Anti-Chase: ON', 2)
else
	if antiChaseConnection then
		antiChaseConnection:Disconnect()
		antiChaseConnection = nil
	end
	for _, conn in ipairs(antiChaseSoundConns) do
		pcall(function() conn:Disconnect() end)
	end
	antiChaseSoundConns = {}
	Library:Notify('Anti-Chase: OFF', 2)
end
end
})
local crouchAAEnabled = false
local crouchAAConn = nil
AgilityBox:AddCheckbox('CrouchAA', {
Text = 'Crouch Spam',
Default = false,
Tooltip = 'Rapidly crouch and uncrouch',
Callback = function(Value)
crouchAAEnabled = Value
if Value then
	crouchAAConn = RunService.Heartbeat:Connect(function()
	if not crouchAAEnabled then return end
	if LocalPlayer.Character then
		local crouching = LocalPlayer.Character:GetAttribute("Crouching") or false
		LocalPlayer.Character:SetAttribute("Crouching", not crouching)
	end
end)
Library:Notify('Crouch AA: ON', 2)
else
	if crouchAAConn then
		crouchAAConn:Disconnect(); crouchAAConn = nil
	end
	Library:Notify('Crouch AA: OFF', 2)
end
end
})
VDSurvivorState.noSkillcheckEnabled = VDSurvivorState.noSkillcheckEnabled or false
VDSurvivorState.hookSkillInstalled = VDSurvivorState.hookSkillInstalled or false
VDSurvivorState.noSkillConnections = VDSurvivorState.noSkillConnections or {}
VDSurvivorState.charSkillConns = VDSurvivorState.charSkillConns or {}
local guiWhitelist = {
LinoriaLib = true,
Rayfield = true,
DevConsoleMaster = true,
RobloxGui = true,
PlayerList = true,
Chat = true,
BubbleChat = true,
Backpack = true
}
local skillExactNames = {
SkillCheckPromptGui = true,
["SkillCheckPromptGui-con"] = true,
SkillCheckEvent = true,
SkillCheckFailEvent = true,
SkillCheckResultEvent = true
}
local function isSkillcheckInstance(inst)
	if not inst or not inst.Name then return false end
	if skillExactNames[inst.Name] then return true end
	return inst.Name:lower():find("skillcheck", 1, true) ~= nil
end
local function softHideSkillcheck(obj)
	pcall(function()
	if obj:IsA("ProximityPrompt") then
		obj.Enabled = false
		obj.HoldDuration = 0
	elseif obj:IsA("GuiObject") then
		obj.Visible = false
		obj.Position = UDim2.new(10, 0, 10, 0)
	elseif obj:IsA("ScreenGui") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
		if obj:IsA("ScreenGui") and guiWhitelist[obj.Name] then return end
		obj.Enabled = false
	end
end)
end
local function nukeAllSkillchecks()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		for _, gui in ipairs(playerGui:GetChildren()) do
			if isSkillcheckInstance(gui) then softHideSkillcheck(gui) end
		end
	end
	local sg = game:GetService("StarterGui")
	if sg then
		pcall(function()
		for _, gui in ipairs(sg:GetChildren()) do
			if isSkillcheckInstance(gui) then softHideSkillcheck(gui) end
		end
	end)
end
end
local function installSkillcheckHook()
	if VDSurvivorState.hookSkillInstalled then return end
	if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
		local method = getnamecallmethod()
		if VDSurvivorState.noSkillcheckEnabled and typeof(self) == "Instance" and isSkillcheckInstance(self) then
			if method == "FireServer" or method == "InvokeServer" then
				local parent = self.Parent
				if parent and parent.Name == "Healing" then
				else
					return nil
				end
			end
		end
		return oldNamecall(self, ...)
	end)
	VDSurvivorState.hookSkillInstalled = true
end
end
local function startNoSkillcheck()
	installSkillcheckHook()
	nukeAllSkillchecks()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		VDSurvivorState.noSkillConnections.pgAdd = playerGui.ChildAdded:Connect(function(child)
		if VDSurvivorState.noSkillcheckEnabled and isSkillcheckInstance(child) then
			task.wait()
			softHideSkillcheck(child)
		end
	end)
	VDSurvivorState.noSkillConnections.pgDesc = playerGui.DescendantAdded:Connect(function(desc)
	if VDSurvivorState.noSkillcheckEnabled and isSkillcheckInstance(desc) then
		task.wait()
		softHideSkillcheck(desc)
	end
end)
end
end
local function stopNoSkillcheck()
	for _, conn in pairs(VDSurvivorState.noSkillConnections) do if conn then conn:Disconnect() end end
	VDSurvivorState.noSkillConnections = {}
end
local isPlayerKiller = VDHelpers.isPlayerKiller
VDSurvivorState.noSkillUserToggle = VDSurvivorState.noSkillUserToggle or false
local function evalNoSkillcheck()
	if VDSurvivorState.noSkillUserToggle and not isPlayerKiller() then
		if not VDSurvivorState.noSkillcheckEnabled then
			VDSurvivorState.noSkillcheckEnabled = true; startNoSkillcheck()
		end
	else
		if VDSurvivorState.noSkillcheckEnabled then
			VDSurvivorState.noSkillcheckEnabled = false; stopNoSkillcheck()
		end
	end
end
LocalPlayer:GetPropertyChangedSignal("Team"):Connect(evalNoSkillcheck)
AbilityBox:AddCheckbox('NoSkillcheck', {
Text = 'No Skillcheck',
Default = false,
Tooltip = 'Completely removes skillchecks from the game',
Callback = function(Value)
VDSurvivorState.noSkillUserToggle = Value
evalNoSkillcheck()
Library:Notify(Value and 'No Skillcheck: ON' or 'No Skillcheck: OFF', 2)
end
})
VDSurvivorState.alwaysPerfectEnabled = VDSurvivorState.alwaysPerfectEnabled or false
VDSurvivorState.alwaysPerfectConn = VDSurvivorState.alwaysPerfectConn or nil
VDSurvivorState.perfectSkillcheckConns = VDSurvivorState.perfectSkillcheckConns or {}
local function isLineInGoalSweetSpot(lineRot, goalRot)
	local lr = lineRot % 360
	local gr = goalRot % 360
	local goalStart = (gr + 104) % 360
	local goalEnd = (gr + 114) % 360
	if goalStart > goalEnd then
		return lr >= goalStart or lr <= goalEnd
	else
		return lr >= goalStart and lr <= goalEnd
	end
end
AbilityBox:AddCheckbox('AlwaysPerfectSkillcheck', {
Text = 'Always Perfect Skillcheck',
Default = false,
Tooltip = 'Auto-hit skillchecks at perfect timing using correct sweet spot detection',
Callback = function(Value)
VDSurvivorState.alwaysPerfectEnabled = Value
if Value then
	for _, conn in pairs(VDSurvivorState.perfectSkillcheckConns) do
		if conn then pcall(function() conn:Disconnect() end) end
	end
	VDSurvivorState.perfectSkillcheckConns = {}
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		local gui1 = playerGui:FindFirstChild("SkillCheckPromptGui")
		local gui2 = playerGui:FindFirstChild("SkillCheckPromptGui-con")
		if gui1 then VDSurvivorState.setupSkillcheckWatcher(gui1) end
		if gui2 then VDSurvivorState.setupSkillcheckWatcher(gui2) end
		local childAddedConn = playerGui.ChildAdded:Connect(function(child)
		if child.Name == "SkillCheckPromptGui" or child.Name == "SkillCheckPromptGui-con" then
			task.wait(0.1)
			VDSurvivorState.setupSkillcheckWatcher(child)
		end
	end)
	table.insert(VDSurvivorState.perfectSkillcheckConns, childAddedConn)
end
Library:Notify('Always Perfect: Enabled', 2)
else
	for _, conn in pairs(VDSurvivorState.perfectSkillcheckConns) do
		if conn then pcall(function() conn:Disconnect() end) end
	end
	VDSurvivorState.perfectSkillcheckConns = {}
	Library:Notify('Always Perfect: Disabled', 2)
end
end
})
VDSurvivorState.clientGodModeConn2 = VDSurvivorState.clientGodModeConn2 or nil
UtilityBox:AddCheckbox('SurvivorGodMode', {
Text = 'Anti-Knockeddown',
Default = false,
Tooltip = 'Anti knocked down, anti-dead, and instantly heals',
Callback = function(Value)
if Value then
	VDSurvivorState.clientGodModeConn2 = RunService.Heartbeat:Connect(function()
	if LocalPlayer.Character then
		local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = hum.MaxHealth
		end
		pcall(function()
		local gameRemotes = ReplicatedStorage:FindFirstChild("Remotes")
		if gameRemotes then
			local gameFolder = gameRemotes:FindFirstChild("Game")
			if gameFolder then
				local spectate = gameFolder:FindFirstChild("SpectateEvent")
				if spectate then
					spectate:FireServer(true)
				end
			end
		end
	end)
end
end)
Library:Notify('God Mode: Enabled', 2)
else
	if VDSurvivorState.clientGodModeConn2 then
		VDSurvivorState.clientGodModeConn2:Disconnect()
		VDSurvivorState.clientGodModeConn2 = nil
	end
	pcall(function()
	local gameRemotes = ReplicatedStorage:FindFirstChild("Remotes")
	if gameRemotes then
		local gameFolder = gameRemotes:FindFirstChild("Game")
		if gameFolder then
			local spectate = gameFolder:FindFirstChild("SpectateEvent")
			if spectate then
				spectate:FireServer(false)
			end
		end
	end
end)
Library:Notify('God Mode: Disabled', 2)
end
end
})
GFS.FakeKnockEnabled = false
GFS._fakeKnockIdleTrack = nil
GFS._fakeKnockWalkTrack = nil
GFS._fakeKnockConn = nil
GFS._fakeKnockOrigSpeed = nil
local FAKE_KNOCK_SPEED = 4
UtilityBox:AddCheckbox('FakeKnock', {
Text = 'Fake Knock',
Default = false,
Tooltip = 'Fake knock to bait killers',
Callback = function(Value)
GFS.FakeKnockEnabled = Value
if Value then
	local myRole = DetectMyRole()
	if myRole ~= "Survivor" then
		Library:Notify("Fake Knock: You must be a Survivor!", 2)
		task.spawn(function()
		if Toggles.FakeKnock then Toggles.FakeKnock:SetValue(false) end
	end)
	return
end
pcall(function()
local char = LocalPlayer.Character
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid")
if not hum then return end
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then return end
GFS._fakeKnockOrigSpeed = hum.WalkSpeed
hum.WalkSpeed = FAKE_KNOCK_SPEED
local idleAnim = Instance.new("Animation")
idleAnim.AnimationId = "rbxassetid://126526181422628"
GFS._fakeKnockIdleTrack = animator:LoadAnimation(idleAnim)
GFS._fakeKnockIdleTrack.Priority = Enum.AnimationPriority.Action4
GFS._fakeKnockIdleTrack.Looped = true
local walkAnim = Instance.new("Animation")
walkAnim.AnimationId = "rbxassetid://78719043959654"
GFS._fakeKnockWalkTrack = animator:LoadAnimation(walkAnim)
GFS._fakeKnockWalkTrack.Priority = Enum.AnimationPriority.Action4
GFS._fakeKnockWalkTrack.Looped = true
GFS._fakeKnockIdleTrack:Play(0.2)
GFS._fakeKnockConn = RunService.Heartbeat:Connect(function()
if not GFS.FakeKnockEnabled then return end
pcall(function()
local c = LocalPlayer.Character
if not c then return end
local h = c:FindFirstChildOfClass("Humanoid")
if not h then return end
if h.WalkSpeed ~= FAKE_KNOCK_SPEED then
	h.WalkSpeed = FAKE_KNOCK_SPEED
end
local isMoving = h.MoveDirection.Magnitude > 0.1
if isMoving then
	if not GFS._fakeKnockWalkTrack.IsPlaying then
		GFS._fakeKnockWalkTrack:Play(0.2)
	end
	if GFS._fakeKnockIdleTrack.IsPlaying then
		GFS._fakeKnockIdleTrack:Stop(0.2)
	end
else
	if not GFS._fakeKnockIdleTrack.IsPlaying then
		GFS._fakeKnockIdleTrack:Play(0.2)
	end
	if GFS._fakeKnockWalkTrack.IsPlaying then
		GFS._fakeKnockWalkTrack:Stop(0.2)
	end
end
end)
end)
end)
Library:Notify('Fake Knock: ON (crawling)', 2)
else
	pcall(function()
	if GFS._fakeKnockIdleTrack then
		GFS._fakeKnockIdleTrack:Stop(0.2)
		GFS._fakeKnockIdleTrack = nil
	end
	if GFS._fakeKnockWalkTrack then
		GFS._fakeKnockWalkTrack:Stop(0.2)
		GFS._fakeKnockWalkTrack = nil
	end
	if GFS._fakeKnockConn then
		GFS._fakeKnockConn:Disconnect()
		GFS._fakeKnockConn = nil
	end
	local char = LocalPlayer.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and GFS._fakeKnockOrigSpeed then
			hum.WalkSpeed = GFS._fakeKnockOrigSpeed
		end
	end
	GFS._fakeKnockOrigSpeed = nil
end)
Library:Notify('Fake Knock: OFF', 2)
end
end
}):AddKeyPicker('FakeKnockKey', {
Default = 'None',
Text = 'Fake Knock',
Mode = 'Toggle',
SyncToggleState = true
})
local fastVaultConnection = nil
local function ApplyFastVault(prompt)
	if not prompt:IsA("ProximityPrompt") then return end
	local name = prompt.Name:lower()
	if name:find("vault") or name:find("window") or name:find("climb") then
		prompt.HoldDuration = 0
	end
end
AbilityBox:AddCheckbox('FastVaultToggle', {
Text = 'Fast Vault',
Default = false,
Tooltip = 'Makes vaulting window faster',
Callback = function(Value)
if Value then
	task.spawn(function()
	while Toggles.FastVaultToggle and Toggles.FastVaultToggle.Value do
		pcall(function()
		LocalPlayer:SetAttribute("EquippedPerk1", "flowstate")
		LocalPlayer:SetAttribute("EquippedPerk2", "flowstate")
		LocalPlayer:SetAttribute("EquippedPerk3", "flowstate")
		LocalPlayer:SetAttribute("EquippedPerk4", "flowstate")
	end)
	local char = LocalPlayer.Character
	if char then
		pcall(function()
		char:SetAttribute("flowstate", true)
		char:SetAttribute("Flowstate", true)
		char:SetAttribute("FlowState", true)
		char:SetAttribute("FlowstateCooldown", 0)
		char:SetAttribute("flowstateCooldown", 0)
	end)
end
local fvRemote = ReplicatedStorage:FindFirstChild("Remotes")
and ReplicatedStorage.Remotes:FindFirstChild("Window")
and ReplicatedStorage.Remotes.Window:FindFirstChild("fastvault")
if fvRemote then
	fvRemote:FireServer(LocalPlayer)
end
task.wait(0.3)
end
end)
Library:Notify('Fast Vault: Enabled', 3)
else
	pcall(function()
	local char = LocalPlayer.Character
	if char then
		char:SetAttribute("flowstate", false)
		char:SetAttribute("Flowstate", false)
		char:SetAttribute("FlowState", false)
	end
end)
Library:Notify('Fast Vault: Disabled', 2)
end
end
})
VDSurvivorState.guiVaultConns = VDSurvivorState.guiVaultConns or {}
for _, c in ipairs(VDSurvivorState.guiVaultConns) do
	pcall(function() c:Disconnect() end)
end
VDSurvivorState.guiVaultConns = {}
local GlobalVaultDebounce = 0
local function TriggerVaultAction(prompt)
	if Toggles.AutoVaultGUI and not Toggles.AutoVaultGUI.Value then return end
	if os.clock() - GlobalVaultDebounce < 0.5 then return end
	GlobalVaultDebounce = os.clock()
	local char = LocalPlayer.Character
	if char then
		if _G.InputHelper then
			_G.InputHelper.HoldKey(Enum.KeyCode.LeftShift)
		else
			pcall(function()
			local vim = game:GetService("VirtualInputManager")
			vim:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
		end)
	end
	char:SetAttribute("IsSprinting", true)
	char:SetAttribute("Sprinting", true)
	task.wait(0.15)
end
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
	local window = remotes:FindFirstChild("Window")
	local pallet = remotes:FindFirstChild("Pallet")
	if window then
		if window:FindFirstChild("fastvault") then
			pcall(function() window.fastvault:FireServer(LocalPlayer) end)
		end
		if window:FindFirstChild("VaultAnim") then
			pcall(function() window.VaultAnim:FireServer("Fast", true) end)
		end
	end
	if pallet then
		if pallet:FindFirstChild("PalletSlideAnim") then
			pcall(function() pallet.PalletSlideAnim:FireServer("Fast", true) end)
		end
		if pallet:FindFirstChild("PalletSlideEvent") then
			pcall(function() pallet.PalletSlideEvent:FireServer(true) end)
		end
	end
end
if char then
	if _G.InputHelper then
		_G.InputHelper.PressKey(Enum.KeyCode.Space, 0.1)
	else
		pcall(function()
		local vim = game:GetService("VirtualInputManager")
		vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
		task.wait(0.1)
		vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
	end)
end
end
end
local function CheckGUI(gui)
	if not gui then return end
	if not gui:IsA("GuiObject") then return end
	local name = gui.Name:lower()
	local text = ""
	if gui:IsA("TextLabel") or gui:IsA("TextButton") then
		text = gui.Text:lower()
	end
	if name:find("vault") or text:find("vault") or (gui:IsA("ImageLabel") and name:find("space"))
	or name:find("slide") or text:find("slide") then
		local success, _ = pcall(function() return gui.Visible end)
		if not success then return end
		local conn = gui:GetPropertyChangedSignal("Visible"):Connect(function()
		if gui.Visible and Toggles.AutoVaultGUI and Toggles.AutoVaultGUI.Value then
			TriggerVaultAction()
		end
	end)
	table.insert(VDSurvivorState.guiVaultConns, conn)
	if gui.Visible then
		TriggerVaultAction()
	end
end
end
AbilityBox:AddCheckbox('AutoVaultGUI', {
Text = 'Auto Vault',
Default = false,
Tooltip = 'Automatically vaults when vault needed (experimental)',
Callback = function(Value)
if Value then
	for _, c in ipairs(VDSurvivorState.guiVaultConns) do
		pcall(function() c:Disconnect() end)
	end
	VDSurvivorState.guiVaultConns = {}
	local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
	if playerGui then
		for _, desc in ipairs(playerGui:GetDescendants()) do
			CheckGUI(desc)
		end
		local addedConn = playerGui.DescendantAdded:Connect(function(desc)
		if Toggles.AutoVaultGUI and Toggles.AutoVaultGUI.Value then
			CheckGUI(desc)
		end
	end)
	table.insert(VDSurvivorState.guiVaultConns, addedConn)
end
Library:Notify('Auto Vault: Enabled', 2)
else
	for _, c in ipairs(VDSurvivorState.guiVaultConns) do
		pcall(function() c:Disconnect() end)
	end
	VDSurvivorState.guiVaultConns = {}
	if _G.InputHelper then
		_G.InputHelper.ReleaseKey(Enum.KeyCode.Space)
		_G.InputHelper.ReleaseKey(Enum.KeyCode.LeftShift)
	else
		pcall(function()
		local vim = game:GetService("VirtualInputManager")
		vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
		vim:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
	end)
end
Library:Notify('Auto Vault: Disabled', 2)
end
end
})
AbilityBox:AddCheckbox('BypassGate', {
Text = 'Bypass Exit Gate',
Default = false,
Tooltip = 'Bypass exit gate requirement to open',
Callback = function(Value)
if _G.GateHelpers and _G.GateHelpers.HandleBypass then
	_G.GateHelpers.HandleBypass(Value)
end
end
})
local function HandleBypassGate(Value)
	if Value then
		RefreshGateCache()
		for _, child in ipairs(game.CoreGui:GetChildren()) do
			if child.Name == "ExitGateBypassGUI" then child:Destroy() end
		end
		task.spawn(function()
		local UserInputService = game:GetService("UserInputService")
		local RunService = game:GetService("RunService")
		local isHolding = false
		local interactStartTime = 0
		local currentGate = nil
		local lastCacheRefresh = 0
		local ignoreGate = nil
		local lastTriggerAttempt = 0
		local detectedGateTime = 0
		while Toggles.BypassGate and Toggles.BypassGate.Value do
			local clock = os.clock()
			if clock - lastCacheRefresh > 3 then
				RefreshGateCache()
				lastCacheRefresh = clock
			end
			local char = LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChild("Humanoid")
			if root and hum and hum.Health > 0 then
				local foundGate = nil
				local minDist = 25
				for _, obj in ipairs(GateObjectsCache) do
					if obj and obj.Parent then
						local leverPart = obj:IsA("Model") and obj:FindFirstChild("Lever") or obj
						if not leverPart then leverPart = obj:FindFirstChild("Handle") or obj end
						if leverPart and leverPart:IsA("BasePart") then
							local dist = (leverPart.Position - root.Position).Magnitude
							if dist < minDist then
								local gateProgress = obj:GetAttribute("GateProgress") or 0
								local gateOpen = obj:GetAttribute("GateOpen") or false
								if not (gateProgress >= 100 or gateOpen) then
									foundGate = obj
									minDist = dist
								end
							end
						end
					end
				end
				currentGate = foundGate
				if currentGate then
					local gateProgress = currentGate:GetAttribute("GateProgress") or 0
					local gateOpen = currentGate:GetAttribute("GateOpen") or false
					if gateProgress >= 100 or gateOpen then
						if isHolding then
							isHolding = false
							local exitRemotes = ReplicatedStorage:FindFirstChild("Remotes")
							and ReplicatedStorage.Remotes:FindFirstChild("Exit")
							if exitRemotes and exitRemotes:FindFirstChild("LeverEvent") then
								exitRemotes.LeverEvent:FireServer(currentGate, false)
							end
							char:SetAttribute("Interacting", false)
							char:SetAttribute("Action", "")
							hum.PlatformStand = false
						end
						ignoreGate = currentGate
					else
						if ignoreGate and ignoreGate ~= currentGate then
							ignoreGate = nil
							detectedGateTime = clock
							isHolding = false
						end
						if ignoreGate ~= currentGate then
							if detectedGateTime == 0 then detectedGateTime = clock end
							if not isHolding then
								if clock - detectedGateTime > 0.1 then
									isHolding = true
									interactStartTime = clock
									lastTriggerAttempt = clock
									task.spawn(function()
									local exitRemotes = ReplicatedStorage:FindFirstChild("Remotes")
									and ReplicatedStorage.Remotes:FindFirstChild("Exit")
									if exitRemotes and exitRemotes:FindFirstChild("LeverEvent") then
										for i = 1, 3 do
											if not Toggles.BypassGate.Value or not currentGate or ignoreGate == currentGate then break end
											exitRemotes.LeverEvent:FireServer(currentGate, true)
											task.wait(0.05)
										end
										task.wait(0.1)
										if Toggles.BypassGate.Value and currentGate and ignoreGate ~= currentGate then
											exitRemotes.LeverEvent:FireServer(currentGate, false)
										end
									end
								end)
							end
						else
							if hum.MoveDirection.Magnitude > 0.1 then
								isHolding = false
								ignoreGate = currentGate
								detectedGateTime = 0
								local exitRemotes = ReplicatedStorage:FindFirstChild("Remotes")
								and ReplicatedStorage.Remotes:FindFirstChild("Exit")
								if exitRemotes and exitRemotes:FindFirstChild("LeverEvent") then
									exitRemotes.LeverEvent:FireServer(currentGate, false)
								end
								char:SetAttribute("Interacting", false)
								char:SetAttribute("Action", "")
								hum.PlatformStand = false
							end
						end
					end
				end
			else
				ignoreGate = nil
				detectedGateTime = 0
				isHolding = false
				if char then
					char:SetAttribute("Interacting", false)
					char:SetAttribute("Action", "")
					if hum then hum.PlatformStand = false end
				end
			end
		end
		task.wait(0.1)
	end
end)
Library:Notify('Bypass Gate: Enabled', 2)
else
	for _, child in ipairs(game.CoreGui:GetChildren()) do
		if child.Name == "ExitGateBypassGUI" then child:Destroy() end
	end
	Library:Notify('Bypass Gate: Disabled', 2)
end
end
AbilityBox:AddCheckbox('NoSlowdown', {
Text = 'No Slowdown',
Default = false,
Tooltip = 'Removes speed penalties from various effects',
Callback = function(Value)
if Value then
	task.spawn(function()
	while Toggles.NoSlowdown and Toggles.NoSlowdown.Value do
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChild("Humanoid")
		if char and hum then
			char:SetAttribute("Hindered", false)
			char:SetAttribute("Exhausted", false)
			char:SetAttribute("Slowed", false)
			char:SetAttribute("Stunned", false)
			char:SetAttribute("IsSlowed", false)
			char:SetAttribute("SpeedPenalty", 0)
			if not GFS.FakeKnockEnabled then
				if hum.WalkSpeed < 16 then
					hum.WalkSpeed = 16
				end
			end
			local speedMulti = char:GetAttribute("SpeedMultiplier")
			if speedMulti and speedMulti < 1 then
				char:SetAttribute("SpeedMultiplier", 1)
			end
		end
		task.wait(0.1)
	end
end)
Library:Notify('No Slowdown: Enabled', 2)
else
	Library:Notify('No Slowdown: Disabled', 2)
end
end
})
GFS.InstantSelfHealEnabled = false
GFS.InstantSelfHealConns = {}
GFS.SelfHealHoldingClick = false
local function GetHealingRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return nil end
	return remotes:FindFirstChild("Healing")
end
local function IsLocalKnocked()
	local char = LocalPlayer.Character
	if not char then return false end
	if char:GetAttribute("Knocked") then return true end
	if char:GetAttribute("Downed") then return true end
	if char:GetAttribute("IsDowned") then return true end
	if char:FindFirstChild("Knocked") then return true end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and hum.Health <= 5 then return true end
	return false
end
local function IsLocalInjured()
	local char = LocalPlayer.Character
	if not char then return false end
	if IsLocalKnocked() then return true end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health < hum.MaxHealth and hum.Health > 0 then return true end
	return false
end
local function IsFindHelpVisible()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return false end
	local progressGui = playerGui:FindFirstChild("ProgressPromptGui")
	if not progressGui then return false end
	for _, desc in ipairs(progressGui:GetDescendants()) do
		if desc.Name == "Help" and desc:IsA("TextLabel") and desc.Visible then
			return true
		end
	end
	return false
end
local function FireAdrenalineSelfRevive()
	pcall(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end
	local items = remotes:FindFirstChild("Items")
	if not items then return end
	local adrenaline = items:FindFirstChild("Adrenaline Shot")
	if not adrenaline then return end
	local knocked = adrenaline:FindFirstChild("Knocked")
	if knocked then knocked:FireServer(LocalPlayer) end
	local healthy = adrenaline:FindFirstChild("Healthy")
	if healthy then healthy:FireServer(LocalPlayer) end
end)
end
local function FireHealComplete()
	pcall(function()
	local healRemotes = GetHealingRemotes()
	if not healRemotes then return end
	local healAnimRec = healRemotes:FindFirstChild("HealAnimRec")
	if healAnimRec then
		healAnimRec:FireServer(LocalPlayer)
		healAnimRec:FireServer(LocalPlayer.Character)
	end
end)
end
local function FireEnableScript()
	pcall(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end
	local gameRemotes = remotes:FindFirstChild("Game")
	if not gameRemotes then return end
	local enableScript = gameRemotes:FindFirstChild("EnableScript")
	if enableScript and LocalPlayer.Character then
		local sound = LocalPlayer.Character:FindFirstChild("Sound")
		if sound then enableScript:FireServer(sound) end
	end
end)
end
local function FireHealTick()
	pcall(function()
	local char = LocalPlayer.Character
	if not char then return end
	local healRemotes = GetHealingRemotes()
	if not healRemotes then return end
	local healAnim = healRemotes:FindFirstChild("HealAnim")
	if healAnim then healAnim:FireServer(false) end
	local healEvent = healRemotes:FindFirstChild("HealEvent")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if healEvent and hrp then healEvent:FireServer(hrp, true) end
	local scResult = healRemotes:FindFirstChild("SkillCheckResultEvent")
	if scResult then scResult:FireServer("success", 1, char) end
	FireEnableScript()
end)
end
local function FireHealClientSignals()
	pcall(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end
	local healRemotes = remotes:FindFirstChild("Healing")
	if healRemotes then
		local healAnim = healRemotes:FindFirstChild("HealAnim")
		if healAnim then firesignal(healAnim.OnClientEvent, false) end
	end
	local roundRemote = remotes:FindFirstChild("Round")
	if roundRemote then firesignal(roundRemote.OnClientEvent, true) end
	local gameRemotes = remotes:FindFirstChild("Game")
	if gameRemotes then
		local deleteSpec = gameRemotes:FindFirstChild("deletespectatorgui")
		if deleteSpec then firesignal(deleteSpec.OnClientEvent) end
	end
	local spectateRemotes = remotes:FindFirstChild("Spectate")
	if spectateRemotes then
		local specEnabler = spectateRemotes:FindFirstChild("Spectateenabler")
		if specEnabler then firesignal(specEnabler.OnClientEvent) end
	end
end)
end
local function FireProgressSpeed()
	pcall(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end
	local progress = remotes:FindFirstChild("Progress")
	if progress then
		local progressUpdate = progress:FindFirstChild("ProgressUpdateEvent")
		if progressUpdate then
			progressUpdate:FireServer(LocalPlayer, 1)
			progressUpdate:FireServer(LocalPlayer, 100)
			progressUpdate:FireServer(LocalPlayer.Character, 1)
		end
	end
end)
end
local function TryGUIHealSelf()
	pcall(function()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end
	for _, gui in ipairs(playerGui:GetChildren()) do
		local gName = gui.Name
		if gName:find("Spectatot") or gName == "pcprompts" or gName == "consoleprompts" then
			for _, desc in ipairs(gui:GetDescendants()) do
				if (desc:IsA("TextButton") or desc:IsA("ImageButton")) then
					local dName = desc.Name:lower()
					if dName == "healyourself" or dName == "playerheal" then
						pcall(function() firesignal(desc.Activated) end)
						pcall(function() firesignal(desc.MouseButton1Click) end)
					end
				end
			end
		end
	end
end)
end
local InstantSelfHealToggle = AbilityBox:AddCheckbox('InstantSelfHeal', {
Text = 'Instant Self Heal',
Default = false,
Tooltip = IsPremium and 'Automatically recovers when knocked and heals when injured',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.InstantSelfHealEnabled = Value
if Value then
	for _, c in ipairs(GFS.InstantSelfHealConns) do pcall(function() c:Disconnect() end) end
	GFS.InstantSelfHealConns = {}
	GFS.SelfHealWasKnocked = false
	GFS.SelfHealWasInjured = false
	GFS.SelfHealLastFindHelp = 0
	local isMobile = (game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled)
	local function GetMobileActionButton()
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if not playerGui then return nil end
		local survivorMob = playerGui:FindFirstChild("Survivor-mob")
		if not survivorMob then return nil end
		local controls = survivorMob:FindFirstChild("Controls")
		if not controls then return nil end
		return controls:FindFirstChild("action")
	end
	if isMobile then
		local mobileLastBtn = 0
		local mobileLastFindHelp = 0
		local VIM = game:GetService("VirtualInputManager")
		local function TapMobileButton()
			pcall(function()
			local btn = GetMobileActionButton()
			if not btn then return end
			local pos = btn.AbsolutePosition
			local size = btn.AbsoluteSize
			local cx = pos.X + size.X / 2
			local cy = pos.Y + size.Y / 2
			VIM:SendTouchEvent(cx, cy, 0, Enum.UserInputState.Begin, game)
			task.defer(function()
			pcall(function()
			VIM:SendTouchEvent(cx, cy, 0, Enum.UserInputState.End, game)
		end)
	end)
end)
end
local mobileConn = RunService.Heartbeat:Connect(function()
if not GFS.InstantSelfHealEnabled then return end
if VDSurvivorState.ForceAntiCampEnabled and VDSurvivorState.ForceAntiCampPhase ~= "IDLE" then return end
local knocked = IsLocalKnocked()
local injured = IsLocalInjured()
local needsHeal = knocked or injured
if needsHeal then
	if knocked then GFS.SelfHealWasKnocked = true end
	if injured then GFS.SelfHealWasInjured = true end
	local now = tick()
	if (now - mobileLastBtn) >= 1.0 then
		mobileLastBtn = now
		TapMobileButton()
	end
	FireHealTick()
	if knocked then
		FireProgressSpeed()
	end
	pcall(function()
	local char = LocalPlayer.Character
	if char then
		char:SetAttribute("healboost", 999)
		char:SetAttribute("HealingPaused", false)
		char:SetAttribute("IsBeingHealed", true)
		if injured then
			char:SetAttribute("HealProgress", 100)
		end
	end
end)
if knocked then
	if (now - mobileLastFindHelp) >= 0.5 then
		mobileLastFindHelp = now
		FireAdrenalineSelfRevive()
		FireHealComplete()
	end
end
else
	if GFS.SelfHealWasKnocked or GFS.SelfHealWasInjured then
		GFS.SelfHealWasKnocked = false
		GFS.SelfHealWasInjured = false
		pcall(function()
		local char = LocalPlayer.Character
		if char then
			char:SetAttribute("healboost", 1)
			char:SetAttribute("HealProgress", nil)
			char:SetAttribute("HealingPaused", nil)
			char:SetAttribute("IsBeingHealed", false)
			char:SetAttribute("Healing", false)
		end
	end)
	pcall(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local healRemotes = remotes:FindFirstChild("Healing")
		if healRemotes then
			local stopHeal = healRemotes:FindFirstChild("Stophealing")
			if stopHeal then pcall(function() stopHeal:FireServer() end) end
			local healAnim = healRemotes:FindFirstChild("HealAnim")
			if healAnim then pcall(function() healAnim:FireServer(false) end) end
		end
	end
end)
end
end
end)
table.insert(GFS.InstantSelfHealConns, mobileConn)
else
	local holdConn = RunService.Heartbeat:Connect(function()
	if not GFS.InstantSelfHealEnabled then return end
	if VDSurvivorState.ForceAntiCampEnabled and VDSurvivorState.ForceAntiCampPhase ~= "IDLE" then return end
	if IsLocalKnocked() then
		if not GFS.SelfHealHoldingClick then
			pcall(function()
			local vim = game:GetService("VirtualInputManager")
			vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
		end)
		GFS.SelfHealHoldingClick = true
	end
else
	if GFS.SelfHealHoldingClick then
		pcall(function()
		local vim = game:GetService("VirtualInputManager")
		vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
	end)
	GFS.SelfHealHoldingClick = false
end
end
end)
table.insert(GFS.InstantSelfHealConns, holdConn)
end
if not isMobile then
	local healConn = RunService.Heartbeat:Connect(function()
	if not GFS.InstantSelfHealEnabled then return end
	if VDSurvivorState.ForceAntiCampEnabled and VDSurvivorState.ForceAntiCampPhase ~= "IDLE" then return end
	if IsLocalKnocked() then
		GFS.SelfHealWasKnocked = true
		FireProgressSpeed()
		FireHealTick()
		pcall(function()
		local char = LocalPlayer.Character
		if char then
			char:SetAttribute("healboost", 999)
			char:SetAttribute("HealingPaused", false)
			char:SetAttribute("IsBeingHealed", true)
		end
	end)
elseif IsLocalInjured() then
	GFS.SelfHealWasInjured = true
	FireHealTick()
	pcall(function()
	local char = LocalPlayer.Character
	if char then
		char:SetAttribute("healboost", 999)
		char:SetAttribute("HealProgress", 100)
	end
end)
else
	if GFS.SelfHealWasKnocked or GFS.SelfHealWasInjured then
		GFS.SelfHealWasKnocked = false
		GFS.SelfHealWasInjured = false
		pcall(function()
		local char = LocalPlayer.Character
		if char then
			char:SetAttribute("healboost", 1)
			char:SetAttribute("HealProgress", nil)
			char:SetAttribute("HealingPaused", nil)
			char:SetAttribute("IsBeingHealed", false)
			char:SetAttribute("Healing", false)
		end
	end)
	pcall(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local progress = remotes:FindFirstChild("Progress")
		if progress then
			local progressEvt = progress:FindFirstChild("ProgressUpdateEvent")
			if progressEvt then
				firesignal(progressEvt.OnClientEvent, 0, "HEAL", false)
			end
		end
		local healRemotes = remotes:FindFirstChild("Healing")
		if healRemotes then
			local healAnim = healRemotes:FindFirstChild("HealAnim")
			if healAnim then firesignal(healAnim.OnClientEvent, false) end
		end
	end
end)
end
end
end)
table.insert(GFS.InstantSelfHealConns, healConn)
local findHelpConn = RunService.Heartbeat:Connect(function()
if not GFS.InstantSelfHealEnabled then return end
if VDSurvivorState.ForceAntiCampEnabled and VDSurvivorState.ForceAntiCampPhase ~= "IDLE" then return end
if not IsLocalKnocked() then return end
if (tick() - GFS.SelfHealLastFindHelp) < 0.3 then return end
GFS.SelfHealLastFindHelp = tick()
FireAdrenalineSelfRevive()
FireHealComplete()
FireHealClientSignals()
if IsFindHelpVisible() then
	TryGUIHealSelf()
end
end)
table.insert(GFS.InstantSelfHealConns, findHelpConn)
end
Library:Notify('Instant Self Heal: Enabled', 2)
else
	for _, c in ipairs(GFS.InstantSelfHealConns) do pcall(function() c:Disconnect() end) end
	GFS.InstantSelfHealConns = {}
	if GFS.SelfHealHoldingClick then
		pcall(function()
		local vim = game:GetService("VirtualInputManager")
		vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
	end)
	GFS.SelfHealHoldingClick = false
end
pcall(function()
if LocalPlayer.Character then
	LocalPlayer.Character:SetAttribute("healboost", 1)
	LocalPlayer.Character:SetAttribute("HealProgress", nil)
	LocalPlayer.Character:SetAttribute("IsBeingHealed", false)
end
end)
Library:Notify('Instant Self Heal: Disabled', 2)
end
end
})
PremiumOnly(InstantSelfHealToggle)
GFS.InstantHealOthersEnabled = false
GFS.InstantHealOthersConn = nil
GFS.HealOthersLastPositions = {}
GFS.HealOthersLastHealTick = 0
GFS.HealOthersFrameSkip = 0
GFS.HealAuraTickRate = 1
GFS._healPlayerCooldowns = {}
GFS._healPerPlayerCD = 0.08
GFS._healLastCleanup = 0
GFS._healCleanupInterval = 1
local function KillLocalHealAnims()
	pcall(function()
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.IsPlaying then
			local ok2, name = pcall(function() return track.Animation.Name:lower() end)
			if ok2 and (name:find("heal") or name:find("bandage") or name:find("patch") or name:find("apply") or name:find("med") or name:find("revive") or name:find("repair")) then
				track:AdjustSpeed(0)
				track:Stop(0)
			end
		end
	end
end)
end
local function ForceLocalRunning()
	pcall(function()
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum:ChangeState(Enum.HumanoidStateType.Running)
	if GFS.FakeKnockEnabled then
		if hum.WalkSpeed ~= 4 then hum.WalkSpeed = 4 end
	else
		if hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
	end
end)
end
local function FireLocalHealCancel()
	pcall(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end
	if not IsMobile then
		local progressRemotes = remotes:FindFirstChild("Progress")
		if progressRemotes then
			local progressEvt = progressRemotes:FindFirstChild("ProgressUpdateEvent")
			if progressEvt then
				pcall(function() firesignal(progressEvt.OnClientEvent, 0, "HEAL", false) end)
			end
		end
		local healRemotes = remotes:FindFirstChild("Healing")
		if healRemotes then
			local healAnim = healRemotes:FindFirstChild("HealAnim")
			if healAnim then
				pcall(function() firesignal(healAnim.OnClientEvent, false) end)
			end
		end
	end
	local healRemotes = remotes:FindFirstChild("Healing")
	if healRemotes then
		local stopHeal = healRemotes:FindFirstChild("Stophealing")
		if stopHeal then pcall(function() stopHeal:FireServer() end) end
		local healAnim = healRemotes:FindFirstChild("HealAnim")
		if healAnim then pcall(function() healAnim:FireServer(false) end) end
	end
end)
end
local function SilentHealTarget(targetPlayer)
	local tChar = targetPlayer.Character
	if not tChar then return end
	local healRemotes = GetHealingRemotes()
	if not healRemotes then return end
	local hrp = tChar:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	KillLocalHealAnims()
	FireLocalHealCancel()
	ForceLocalRunning()
	local healEvent = healRemotes:FindFirstChild("HealEvent")
	if healEvent then healEvent:FireServer(hrp, true) end
	local healAnim = healRemotes:FindFirstChild("HealAnim")
	if healAnim then
		healAnim:FireServer(false)
	end
	local scResult = healRemotes:FindFirstChild("SkillCheckResultEvent")
	if scResult then scResult:FireServer("success", 1, tChar) end
	FireEnableScript()
	if healEvent then healEvent:FireServer(hrp, false) end
	FireLocalHealCancel()
	KillLocalHealAnims()
	ForceLocalRunning()
	if not IsMobile then
		task.delay(0.1, function()
		KillLocalHealAnims()
		FireLocalHealCancel()
		ForceLocalRunning()
	end)
end
end
local function NeutralizeHealBody()
	pcall(function()
	local healRemotes = GetHealingRemotes()
	if not healRemotes then return end
	local stopHeal = healRemotes:FindFirstChild("Stophealing")
	if stopHeal then stopHeal:FireServer() end
	local healAnim = healRemotes:FindFirstChild("HealAnim")
	if healAnim then
		healAnim:FireServer(false)
		healAnim:FireServer(nil)
	end
	local healEvent = healRemotes:FindFirstChild("HealEvent")
	if healEvent then
		healEvent:FireServer(false)
		healEvent:FireServer(nil)
	end
	local scResult = healRemotes:FindFirstChild("SkillCheckResultEvent")
	if scResult then
		scResult:FireServer("cancel")
		scResult:FireServer(false)
		scResult:FireServer(nil)
	end
end)
FireLocalHealCancel()
KillLocalHealAnims()
pcall(function()
local char = LocalPlayer.Character
if not char then return end
char:SetAttribute("Healing", false)
char:SetAttribute("IsBeingHealed", false)
char:SetAttribute("IsHealing", false)
char:SetAttribute("HealingTarget", nil)
if not GFS.FakeKnockEnabled then
	char:SetAttribute("Crouchingserver", false)
end
end)
ForceLocalRunning()
end
local function IsPlayerHealable(player)
	if not VDSettings or not VDSettings.PlayerStatuses then return false end
	local status = VDSettings.PlayerStatuses[player]
	if not status or status == "" then return false end
	if status == "Knocked" or status == "Injured" or status == "Healing" then
		local char = player.Character
		if not char then return false end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return false end
		return true
	end
	return false
end
local function GetInjuredPlayersFromStatus()
	local injured = {}
	if not VDSettings or not VDSettings.PlayerStatuses then return injured end
	for player, status in pairs(VDSettings.PlayerStatuses) do
		if player ~= LocalPlayer and typeof(player) == "Instance" and player:IsA("Player") then
			if (status == "Knocked" or status == "Injured" or status == "Healing") then
				if player.Character then
					local hum = player.Character:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						table.insert(injured, player)
					end
				end
			end
		end
	end
	return injured
end
local InstantHealOthersToggle = AbilityBox:AddCheckbox('InstantHealOthers', {
Text = 'Heal Aura',
Default = false,
Tooltip = IsPremium and 'Silent instant heal — heals knocked/injured survivors without animation',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.InstantHealOthersEnabled = Value
if Value then
	if GFS.InstantHealOthersConn then
		pcall(function() GFS.InstantHealOthersConn:Disconnect() end)
		GFS.InstantHealOthersConn = nil
	end
	GFS.HealOthersLastPositions = {}
	GFS.HealOthersLastHealTick = 0
	GFS.HealOthersFrameSkip = 0
	GFS._healLastCleanup = 0
	GFS._healAuraMobileIdx = 0
	GFS.InstantHealOthersConn = RunService.Heartbeat:Connect(function()
	if not GFS.InstantHealOthersEnabled then
		if GFS.InstantHealOthersConn then
			pcall(function() GFS.InstantHealOthersConn:Disconnect() end)
			GFS.InstantHealOthersConn = nil
		end
		NeutralizeHealBody()
		return
	end
	if VDSettings and VDSettings.PlayerStatuses then
		local myStatus = VDSettings.PlayerStatuses[LocalPlayer]
		if myStatus == "Hooked" or myStatus == "Carried" or myStatus == "Knocked" or myStatus == "Dead" then
			return
		end
	end
	GFS.HealOthersFrameSkip = GFS.HealOthersFrameSkip + 1
	if GFS.HealOthersFrameSkip < GFS.HealAuraTickRate then return end
	GFS.HealOthersFrameSkip = 0
	local injured = GetInjuredPlayersFromStatus()
	if #injured == 0 then
		if GFS.HealOthersLastHealTick > 0 then
			KillLocalHealAnims()
			FireLocalHealCancel()
			ForceLocalRunning()
			GFS.HealOthersLastHealTick = 0
		end
		return
	end
	table.sort(injured, function(a, b)
	local aChar, bChar = a.Character, b.Character
	if not aChar then return false end
	if not bChar then return true end
	local aKnocked = aChar:GetAttribute("Knocked") or aChar:GetAttribute("Downed") or false
	local bKnocked = bChar:GetAttribute("Knocked") or bChar:GetAttribute("Downed") or false
	if aKnocked ~= bKnocked then return aKnocked end
	local aHum = aChar:FindFirstChildOfClass("Humanoid")
	local bHum = bChar:FindFirstChildOfClass("Humanoid")
	local aHP = aHum and (aHum.Health / math.max(aHum.MaxHealth, 1)) or 1
	local bHP = bHum and (bHum.Health / math.max(bHum.MaxHealth, 1)) or 1
	return aHP < bHP
end)
if IsMobile then
	GFS._healAuraMobileIdx = GFS._healAuraMobileIdx + 1
	if GFS._healAuraMobileIdx > #injured then
		GFS._healAuraMobileIdx = 1
	end
	local player = injured[GFS._healAuraMobileIdx]
	if player then
		pcall(function()
		SilentHealTarget(player)
		GFS.HealOthersLastHealTick = tick()
	end)
end
else
	for _, player in ipairs(injured) do
		pcall(function()
		SilentHealTarget(player)
		GFS.HealOthersLastHealTick = tick()
	end)
end
end
if GFS.HealOthersLastHealTick > 0 and (tick() - GFS.HealOthersLastHealTick) < 0.5 then
	KillLocalHealAnims()
	FireLocalHealCancel()
end
end)
local injured = GetInjuredPlayersFromStatus()
local names = {}
for _, p in ipairs(injured) do table.insert(names, p.Name) end
local nameStr = #names > 0 and table.concat(names, ", ") or "watching..."
Library:Notify('Silent Heal Others: ON (' .. #injured .. ' targets: ' .. nameStr .. ')', 3)
else
	if GFS.InstantHealOthersConn then
		pcall(function() GFS.InstantHealOthersConn:Disconnect() end)
		GFS.InstantHealOthersConn = nil
	end
	GFS.InstantHealOthersEnabled = false
	NeutralizeHealBody()
	GFS.HealOthersLastPositions = {}
	Library:Notify('Instant Heal Others: Disabled', 2)
end
end
})
local HealAuraSpeedSlider = AbilityBox:AddSlider('HealAuraSpeed', {
Text = 'Heal Aura Delay',
Default = 1,
Min = 1,
Max = 10,
Rounding = 0,
Tooltip = IsPremium and 'Lower is faster, 3 is balanced',
DisabledTooltip = 'Unlock this with premium',
Compact = true,
Callback = function(Value)
GFS.HealAuraTickRate = Value
end
})
PremiumOnly(InstantHealOthersToggle)
PremiumOnly(HealAuraSpeedSlider)
GFS.AutoCrouchDodgeEnabled = false
local _cdStandalone = {
RADIUS = 20,
active = false,
endTick = 0,
conn = nil,
}
AbilityBox:AddCheckbox('AutoCrouchDodge', {
Text = 'Auto Crouch Dodge',
Default = false,
Tooltip = 'Auto crouch to dodge Abysswalker skill',
Callback = function(Value)
GFS.AutoCrouchDodgeEnabled = Value
if Value then
	if _cdStandalone.conn then
		_cdStandalone.conn:Disconnect()
		_cdStandalone.conn = nil
	end
	_cdStandalone.active = false
	_cdStandalone.endTick = 0
	_cdStandalone.conn = RunService.Heartbeat:Connect(function()
	if not GFS.AutoCrouchDodgeEnabled then return end
	if _cdStandalone.active then
		if tick() >= _cdStandalone.endTick then
			_cdStandalone.active = false
			pcall(function() GFS.ServerCrouch(false) end)
		end
		return
	end
	if DetectMyRole() ~= "Survivor" then return end
	local myChar = LocalPlayer.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and IsKiller(player) and player.Character then
			local kChar = player.Character
			local kRoot = kChar:FindFirstChild("HumanoidRootPart")
			local kHum = kChar:FindFirstChildOfClass("Humanoid")
			if kRoot and kHum then
				local dist = (kRoot.Position - myRoot.Position).Magnitude
				if dist <= _cdStandalone.RADIUS then
					pcall(function()
					local animator = kHum:FindFirstChildOfClass("Animator")
					if not animator then return end
					local killerType = GFS._DetectKillerType and GFS._DetectKillerType(kChar) or "Unknown"
					if not (GFS.IgnoredKillerSkills and GFS.IgnoredKillerSkills[killerType]) then return end
					local tracks = animator:GetPlayingAnimationTracks()
					for _, track in pairs(tracks) do
						if track.IsPlaying and track.Animation then
							local numId = GFS._ExtractAnimID(tostring(track.Animation.AnimationId or ""))
							if numId and GFS._CrouchDodgeAnimIDs and GFS._CrouchDodgeAnimIDs[numId] then
								if not _cdStandalone.active and track.TimePosition < 0.8 then
									_cdStandalone.active = true
									_cdStandalone.endTick = tick() + math.min(track.Length or 2.0, 2.5)
									GFS.ServerCrouch(true)
								end
							end
						end
					end
				end)
			end
		end
	end
end
end)
Library:Notify('Auto Crouch Dodge: ON (20 stud radius)', 2)
else
	if _cdStandalone.conn then
		_cdStandalone.conn:Disconnect()
		_cdStandalone.conn = nil
	end
	if _cdStandalone.active then
		_cdStandalone.active = false
		pcall(function()
		if GFS.ServerCrouch then
			GFS.ServerCrouch(false)
		end
	end)
end
Library:Notify('Auto Crouch Dodge: OFF', 2)
end
end
})
VDSurvivorState.autoRunConn = VDSurvivorState.autoRunConn or nil
AgilityBox:AddCheckbox('AutoRun', {
Text = 'Auto Run (Sprint)',
Default = false,
Tooltip = 'Automatically holds Shift to sprint when moving',
Callback = function(Value)
if Value then
	VDSurvivorState.autoRunConn = RunService.RenderStepped:Connect(function()
	if LocalPlayer.Character then
		local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.MoveDirection.Magnitude > 0 then
			if _G.InputHelper then
				_G.InputHelper.HoldKey(Enum.KeyCode.LeftShift)
			else
				pcall(function()
				local vim = game:GetService("VirtualInputManager")
				vim:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
			end)
		end
	else
		if _G.InputHelper then
			_G.InputHelper.ReleaseKey(Enum.KeyCode.LeftShift)
		else
			pcall(function()
			local vim = game:GetService("VirtualInputManager")
			vim:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
		end)
	end
end
end
end)
Library:Notify('Auto Sprint: Enabled', 2)
else
	if VDSurvivorState.autoRunConn then
		VDSurvivorState.autoRunConn:Disconnect()
		VDSurvivorState.autoRunConn = nil
		if _G.InputHelper then
			_G.InputHelper.ReleaseKey(Enum.KeyCode.LeftShift)
		else
			pcall(function()
			local vim = game:GetService("VirtualInputManager")
			vim:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
		end)
	end
end
Library:Notify('Auto Sprint: Disabled', 2)
end
end
})
VDSurvivorState.unlockJumpConn = VDSurvivorState.unlockJumpConn or nil
AgilityBox:AddCheckbox('UnlockJump', {
Text = 'Unlock Jump',
Default = false,
Tooltip = 'Enables jumping',
Callback = function(Value)
if Value then
	VDSurvivorState.unlockJumpConn = RunService.Heartbeat:Connect(function()
	if LocalPlayer.Character then
		local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			if hum.UseJumpPower then
				if hum.JumpPower <= 0 then hum.JumpPower = 51 end
			else
				if hum.JumpHeight <= 0 then hum.JumpHeight = 7.3 end
			end
			hum.JumpPower = 51
			hum.JumpHeight = 7.3
		end
	end
end)
Library:Notify('Unlock Jump: Enabled', 2)
else
	if VDSurvivorState.unlockJumpConn then
		VDSurvivorState.unlockJumpConn:Disconnect()
		VDSurvivorState.unlockJumpConn = nil
	end
	if LocalPlayer.Character then
		local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			if hum.UseJumpPower then
				hum.JumpPower = 0
			else
				hum.JumpHeight = 0
			end
		end
	end
	Library:Notify('Unlock Jump: Disabled', 2)
end
end
})
GFS.LastParryTime = GFS.LastParryTime or 0
GFS.ParryCooldownDuration = 1.5
GFS.ParryDaggerBarCache = nil
GFS.ParryDaggerCacheTime = 0
GFS.FaceKillerSensitivity = 0.1
GFS.TrajectoryParryCheck = true
GFS.TrajectoryHitRadius = 3
local function FindParryDaggerBar()
	if GFS.ParryDaggerBarCache and GFS.ParryDaggerBarCache.Parent then
		return GFS.ParryDaggerBarCache
	end
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return nil end
	for _, gui in ipairs(playerGui:GetDescendants()) do
		if gui:IsA("ImageLabel") then
			local img = gui.Image or ""
			if img:find("76822757630703") then
				local bar = gui:FindFirstChild("Bar")
				if bar and bar:IsA("ImageLabel") then
					GFS.ParryDaggerBarCache = bar
					return bar
				end
			end
		end
	end
	return nil
end
local function IsParryOnCooldown()
	if GFS.DaggerCooldownEnd then
		if tick() < GFS.DaggerCooldownEnd then return true end
		return false
	end
	local timeSinceLastParry = tick() - (GFS.LastParryTime or 0)
	if timeSinceLastParry < (GFS.ParryCooldownDuration or 1.5) then
		return true
	end
	if _G.ParryUICache and _G.ParryUICache.Gradient then
		local ok, result = pcall(function()
		local bar = _G.ParryUICache.Bar
		if bar and bar.ImageTransparency > 0.5 then return false end
		local y = _G.ParryUICache.Gradient.Offset.Y
		local progress = (0.75 - y) / 0.50
		return progress < 0.95
	end)
	if ok then return result end
end
return false
end
local function TryParry()
	if IsParryOnCooldown() then
		return false
	end
	return true
end
local function SetupAutoParryRemotes()
	if _G.AutoParryRemoteConnection then
		pcall(function() _G.AutoParryRemoteConnection:Disconnect() end)
		_G.AutoParryRemoteConnection = nil
	end
	local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 5)
	if not remotes then return end
	local attackRemoteNames = {
	"BasicAttack",
	"alexattack",
	"Spearthrow",
	"M2",
	"FrenzyHitEvent",
	"hit",
	"Pursuit",
	"corrupt",
	"visualize",
	"grab",
	"StartGrabHitbox",
	}
	local function IsAttackRemote(remoteName)
		for _, name in ipairs(attackRemoteNames) do
			if remoteName == name then return true end
		end
		return false
	end
	local IsKiller = VDHelpers.isPlayerKiller
	local function GetParryRemote(refresh)
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		if remotes then
			local items = remotes:FindFirstChild("Items")
			if items then
				local dagger = items:FindFirstChild("Parrying Dagger")
				if dagger then
					return dagger:FindFirstChild("parry")
				end
			end
		end
		return nil
	end
	local function ConnectRemote(remote)
		if remote:IsA("RemoteEvent") and IsAttackRemote(remote.Name) then
			remote.OnClientEvent:Connect(function(...)
			if not GFS.AutoParryEnabled then return end
			local success, err = pcall(function()
			local cachedData = GFS._cachedKillerData
			if not cachedData then return end
			if GFS._cachedIsSurvivor == false then return end
			local foundValidKiller = false
			for killerName, cached in pairs(cachedData) do
				if cached.inRange and cached.facingMe and not cached.nearInteractable and cached.hasLineOfSight then
					local shouldSkipAnim = false
					if cached.animator then
						pcall(function()
						local tracks = cached.animator:GetPlayingAnimationTracks()
						local killerType = cached.killerType or "Unknown"
						local hasAttackAnim = false
						local allIgnored = true
						for _, track in pairs(tracks) do
							if track.IsPlaying and track.Animation then
								local numId = GFS._ExtractAnimID(tostring(track.Animation.AnimationId or ""))
								if numId then
									if GFS._AutoParryIgnoreAnimIDs[numId] then
									elseif GFS._SkillAnimIDs and GFS._SkillAnimIDs[numId] then
										if GFS.IgnoredKillerSkills and GFS.IgnoredKillerSkills[killerType] then
										else
											hasAttackAnim = true
											allIgnored = false
										end
									elseif GFS._KnownAttackAnimIDs and GFS._KnownAttackAnimIDs[numId] then
										hasAttackAnim = true
										allIgnored = false
									elseif track.Looped then
									elseif track.Length > 3.0 or track.Length < 0.2 then
									else
										hasAttackAnim = true
										allIgnored = false
									end
								end
							end
						end
						if not hasAttackAnim and allIgnored then
							shouldSkipAnim = true
						end
					end)
				end
				if not shouldSkipAnim then
					foundValidKiller = true
					break
				end
			end
		end
		if foundValidKiller then
			if not TryParry() then
				return
			end
			pcall(function()
			if _G.InputHelper and _G.InputHelper.TriggerParry then
				_G.InputHelper.TriggerParry()
			else
				local parryRemote = GetParryRemote(false)
				if parryRemote and parryRemote:IsA("RemoteEvent") then
					parryRemote:FireServer()
				end
			end
		end)
		GFS.LastParryTime = tick()
		_G.LastParryExecuted = tick()
		GFS.DaggerCooldownEnd = tick() + (GFS.ParryCooldownDuration or 1.5)
		if GFS.AutoParryDebug then
			task.defer(function()
			Library:Notify("[REMOTE] Parried Attack!", 1.5)
		end)
	end
end
end)
end)
end
end
for _, child in ipairs(remotes:GetDescendants()) do
	ConnectRemote(child)
end
_G.AutoParryRemoteConnection = remotes.DescendantAdded:Connect(ConnectRemote)
end
local CreateParryRadiusVisual, DestroyParryRadiusVisual
AbilityBox:AddCheckbox('AutoParry', {
Text = 'Auto Parry',
Default = false,
Tooltip =
'Automatically parry killer attacks when in range\n(Requires: Parrying Dagger + Survivor role)\nRadius only shows when Survivor',
Callback = function(Value)
GFS.AutoParryEnabled = Value
if Value then
	local parryExists = false
	pcall(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local items = remotes:FindFirstChild("Items")
		if items then
			local dagger = items:FindFirstChild("Parrying Dagger")
			if dagger and dagger:FindFirstChild("parry") then
				parryExists = true
			end
		end
	end
end)
CreateParryRadiusVisual()
if parryExists then
	Library:Notify('Auto Parry: Enabled', 2)
else
	Library:Notify('Warning: Parrying Dagger may not be equipped', 3)
end
SetupAutoParryRemotes()
else
	DestroyParryRadiusVisual()
	if _G.AutoParryConnection then
		_G.AutoParryConnection:Disconnect()
		_G.AutoParryConnection = nil
	end
	Library:Notify('Auto Parry: Disabled', 2)
end
end
}):AddColorPicker('ParryRadiusFillColor', {
Default = Color3.fromRGB(0, 170, 255),
Title = 'Radius Fill Color',
Transparency = 0,
Callback = function(Value)
GFS.ParryRadiusFillColor = Value
end
}):AddColorPicker('ParryRadiusOutlineColor', {
Default = Color3.fromRGB(255, 255, 255),
Title = 'Radius Outline Color',
Transparency = 0,
Callback = function(Value)
GFS.ParryRadiusOutlineColor = Value
end
})
AbilityBox:AddCheckbox('ParryRadiusFillEnabled', {
Text = 'Show Radius Fill',
Default = true,
Tooltip = 'Show the colored fill area inside the parry radius. Turn off to keep only the outline ring.',
Callback = function(Value)
GFS.ParryRadiusFillEnabled = Value
end
})
GFS.IgnoredKillerSkills = {
Veil = true,
Masked = true,
Stalker = true,
Hidden = true,
Abysswalker = true,
Killer = true,
Slasher = true,
Mayers = true,
}
AbilityBox:AddDropdown('IgnoreKillerSkills', {
Values = { 'Veil', 'Masked', 'Stalker', 'Hidden', 'Abysswalker', 'Killer', 'Slasher', 'Mayers' },
Default = { 'Veil', 'Masked', 'Stalker', 'Hidden', 'Abysswalker', 'Killer', 'Slasher', 'Mayers' },
Multi = true,
Text = 'Ignore Killer Skills',
Tooltip =
'Select which killers\' skills should be ignored (skills CANNOT be parried)',
Callback = function(Value)
GFS.IgnoredKillerSkills = Value
local selected = {}
for k, v in pairs(Value) do
	if v then table.insert(selected, k) end
end
-- Library:Notify('Ignore Skills: ' .. (#selected > 0 and table.concat(selected, ', ') or 'NONE'), 2)
end
})
AbilityBox:AddDropdown('AutoParryMode', {
Values = { 'Animation', 'No Animation' },
Default = GFS.AutoParryMode or 'Animation',
Multi = false,
Tooltip = 'Animation = (shows animation). No Animation = (no animation, instant).',
Callback = function(Value)
GFS.AutoParryMode = Value
-- Library:Notify('Parry Mode: ' .. Value, 2)
end
})
GFS.FakeParryEnabled = false
GFS.ParryRadiusFillEnabled = true
GFS.ParryRadiusFillColor = Color3.fromRGB(0, 170, 255)
GFS.ParryRadiusOutlineColor = Color3.fromRGB(255, 255, 255)
GFS.ParryRadiusFillTransparency = 0
GFS.ParryRadiusOutlineTransparency = 0
GFS.ParryRadiusFillPart = nil
GFS.ParryRadiusOutlineRing = {}
AbilityBox:AddSlider('FaceKillerSensitivity', {
Text = 'Face Killer Sensitivity',
Default = 0.1,
Min = -1.0,
Max = 1.0,
Compact = true,
Rounding = 2,
Tooltip =
'Higher value = Must look more directly at killer\n0.1 = Standard (~85 degrees)\n-1.0 = 360 degrees (All directions valid)\n(Only used when Trajectory Check is OFF)',
Callback = function(Value)
GFS.FaceKillerSensitivity = Value
end
})
AbilityBox:AddToggle('TrajectoryParryCheck', {
Text = 'Aim Prediction',
Default = true,
Tooltip = 'Predicts if the killer attack will actually hit you before parrying.\nMore accurate than simple angle check.\nWhen OFF, falls back to Face Killer Sensitivity.',
Callback = function(Value)
GFS.TrajectoryParryCheck = Value
if Options.TrajectoryHitRadius then
	Options.TrajectoryHitRadius:SetDisabled(not Value)
end
end
})
AbilityBox:AddSlider('TrajectoryHitRadius', {
Text = 'Aim Strictness',
Default = 3,
Min = 1,
Max = 3,
Rounding = 1,
Compact = true,
Tooltip = 'How accurately the killer must aim at you to trigger parry.\nHigher = only parry when attack is aimed directly at you\nLower = parry even if slightly off-target',
Callback = function(Value)
GFS.TrajectoryHitRadius = Value
end
})
Options.TrajectoryHitRadius:SetDisabled(not GFS.TrajectoryParryCheck)
AbilityBox:AddSlider('AutoParryDistance', {
Text = 'Parry Detection Range',
Default = 15,
Min = 5,
Max = 30,
Rounding = 0,
Compact = true,
Suffix = ' studs',
Tooltip = 'Max distance to detect killer attacks',
Callback = function(Value)
GFS.AutoParryDistance = Value
end
})
AbilityBox:AddSlider('AutoParryDelay', {
Text = 'Auto Parry Delay (s)',
Default = 0,
Min = 0,
Max = 0.5,
Rounding = 2,
Compact = true,
Tooltip = 'Delay before parrying after detection (For ping/timing adjustment)',
Callback = function(Value)
GFS.AutoParryDelay = Value
end
})
local OUTLINE_SEGMENTS = 32
local OUTLINE_THICKNESS = 0.12
CreateParryRadiusVisual = function()
if GFS.ParryRadiusFillPart then return end
local radius = GFS.AutoParryDistance or 15
local fill = Instance.new('Part')
fill.Name = 'Starship_ParryFill'
fill.Shape = Enum.PartType.Cylinder
fill.Anchored = true
fill.CanCollide = false
fill.CanTouch = false
fill.CanQuery = false
fill.CastShadow = false
fill.Material = Enum.Material.Neon
fill.Color = GFS.ParryRadiusFillColor
fill.Transparency = GFS.ParryRadiusFillTransparency
fill.Size = Vector3.new(0.05, radius * 2, radius * 2)
fill.Parent = workspace
GFS.ParryRadiusFillPart = fill
GFS.ParryRadiusOutlineRing = {}
local segmentArc = (2 * math.pi) / OUTLINE_SEGMENTS
local segmentLength = (2 * math.pi * radius) / OUTLINE_SEGMENTS * 1.05
for i = 1, OUTLINE_SEGMENTS do
	local angle = (i - 1) * segmentArc
	local part = Instance.new('Part')
	part.Name = 'Starship_ParryRing_' .. i
	part.Shape = Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = GFS.ParryRadiusOutlineColor
	part.Transparency = GFS.ParryRadiusOutlineTransparency
	part.Size = Vector3.new(segmentLength, 0.06, OUTLINE_THICKNESS)
	part.Parent = workspace
	table.insert(GFS.ParryRadiusOutlineRing, part)
end
end
DestroyParryRadiusVisual = function()
if GFS.ParryRadiusFillPart then
	pcall(function() GFS.ParryRadiusFillPart:Destroy() end)
	GFS.ParryRadiusFillPart = nil
end
if GFS.ParryRadiusOutlineRing then
	for _, part in ipairs(GFS.ParryRadiusOutlineRing) do
		pcall(function() part:Destroy() end)
	end
	GFS.ParryRadiusOutlineRing = {}
end
end
local function UpdateParryRadius()
	if not GFS.AutoParryEnabled then
		DestroyParryRadiusVisual()
		return
	end
	local myRole = DetectMyRole()
	if myRole ~= "Survivor" then
		DestroyParryRadiusVisual()
		return
	end
	if not GFS.ParryRadiusFillPart then CreateParryRadiusVisual() end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild('HumanoidRootPart')
	if not root then return end
	local rayParams = RaycastParams.new()
	local filterList = { char, GFS.ParryRadiusFillPart }
	for _, p in ipairs(GFS.ParryRadiusOutlineRing or {}) do table.insert(filterList, p) end
	rayParams.FilterDescendantsInstances = filterList
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local rayResult = workspace:Raycast(root.Position, Vector3.new(0, -20, 0), rayParams)
	local groundY = rayResult and rayResult.Position.Y or (root.Position.Y - 3)
	local radius = GFS.AutoParryDistance or 15
	local cx, cz = root.Position.X, root.Position.Z
	if GFS.ParryRadiusFillPart then
		local flatRotation = CFrame.Angles(0, 0, math.rad(90))
		GFS.ParryRadiusFillPart.Size = Vector3.new(0.05, radius * 2, radius * 2)
		GFS.ParryRadiusFillPart.CFrame = CFrame.new(cx, groundY + 0.04, cz) * flatRotation
		GFS.ParryRadiusFillPart.Color = GFS.ParryRadiusFillColor
		-- Kalau toggle Show Radius Fill di-off, paksa transparency = 1 (invisible) tapi part tetep ada
		if GFS.ParryRadiusFillEnabled == false then
			GFS.ParryRadiusFillPart.Transparency = 1
		else
			GFS.ParryRadiusFillPart.Transparency = GFS.ParryRadiusFillTransparency
		end
	end
	local segmentArc = (2 * math.pi) / OUTLINE_SEGMENTS
	local segmentLength = (2 * math.pi * radius) / OUTLINE_SEGMENTS * 1.05
	for i, part in ipairs(GFS.ParryRadiusOutlineRing or {}) do
		local angle = (i - 1) * segmentArc
		local px = cx + math.cos(angle) * radius
		local pz = cz + math.sin(angle) * radius
		part.Size = Vector3.new(segmentLength, 0.06, OUTLINE_THICKNESS)
		part.CFrame = CFrame.new(px, groundY + 0.05, pz) * CFrame.Angles(0, -angle + math.rad(90), 0)
		part.Color = GFS.ParryRadiusOutlineColor
		part.Transparency = GFS.ParryRadiusOutlineTransparency
	end
end
GFS._UpdateParryRadius = UpdateParryRadius
Options.ParryRadiusFillColor:OnChanged(function()
GFS.ParryRadiusFillTransparency = Options.ParryRadiusFillColor.Transparency
end)
Options.ParryRadiusOutlineColor:OnChanged(function()
GFS.ParryRadiusOutlineTransparency = Options.ParryRadiusOutlineColor.Transparency
end)
AbilityBox:AddCheckbox('FakeParry', {
Text = 'Fake Parry',
Default = false,
Tooltip = 'Enable Fake Parry, press keybind to trigger fake parry\n(Killer thinks you parried but you didn\'t)',
Callback = function(Value)
GFS.FakeParryEnabled = Value
if Value then
	Library:Notify('Fake Parry: ON (Press keybind to trigger)', 2)
else
	Library:Notify('Fake Parry: OFF', 2)
end
end
}):AddKeyPicker('FakeParryKey', {
Default = 'None',
SyncToggleState = false,
Mode = 'Toggle',
Text = 'Fake Parry',
NoUI = false,
Callback = function(Value)
if GFS.FakeParryEnabled and Value then
	if _G.InputHelper and _G.InputHelper.FakeParry then
		_G.InputHelper.FakeParry()
	end
end
end
})
AgilityBox:AddCheckbox('NoFall', {
Text = 'No Fall Damage',
Default = false,
Tooltip = 'Prevents fall damage/animation',
Callback = function(Value)
if Value then
	Library:Notify("No Fall Damage Enabled", 3)
	pcall(function()
	local mt = getrawmetatable(game)
	if mt then
		local old = mt.__namecall
		setreadonly(mt, false)
		mt.__namecall = newcclosure(function(self, ...)
		local args = { ... }
		local method = getnamecallmethod()
		if method == "FireServer" and self.Name == "Fall" and Toggles.NoFall.Value then
			return nil
		end
		return old(self, unpack(args))
	end)
	setreadonly(mt, true)
end
end)
end
end
})
do
	local MoonwalkState = {
	Enabled = false,
	Mode = nil,
	Connection = nil,
	GUI = nil,
	KeySource = nil,
	}
	local _mwBackBtn, _mwFwdBtn
	local _mwCurrentYaw = nil
	local _mwCurrentWobble = 0
	local function StopMoonwalk()
		local was = MoonwalkState.Mode
		MoonwalkState.Mode = nil
		MoonwalkState.KeySource = nil
		_mwCurrentYaw = nil
		_mwCurrentWobble = 0
		pcall(function()
		local ch = Players.LocalPlayer.Character
		if ch then
			local h = ch:FindFirstChildOfClass("Humanoid")
			if h then h.AutoRotate = true end
		end
	end)
	return was ~= nil
end
local function StartMode(mode, source)
	if not MoonwalkState.Enabled then return end
	MoonwalkState.Mode = mode
	MoonwalkState.KeySource = source or "btn"
end
local function UpdateBtnVisual(btn, active)
	if not btn then return end
	if active then
		btn.ImageColor3 = Color3.fromRGB(255, 255, 255)
		btn.ImageTransparency = 0
	else
		btn.ImageColor3 = Color3.fromRGB(170, 170, 170)
		btn.ImageTransparency = 0.25
	end
end
local function UpdateAllBtnVisuals()
	UpdateBtnVisual(_mwBackBtn, MoonwalkState.Mode == "backward")
	UpdateBtnVisual(_mwFwdBtn, MoonwalkState.Mode == "forward")
end
local MW_WOBBLE_MAX  = 0.65
local MW_WOBBLE_LERP = 3.5
local MW_YAW_LERP    = 6
local function _readKeyHeld(opt)
	-- Shim WindUI Boreal gak punya :GetState() & gak update opt.Value pas user re-bind.
	-- Key actual ada di opt.Element.Value (string nama keycode dari WindUI Boreal Keybind).
	if not opt then return false end
	local ok, held = pcall(function()
		if type(opt.GetState) == "function" then return opt:GetState() end
		-- Coba beberapa source value: Element.Value (paling akurat utk WindUI Boreal), trus opt.Value
		local candidates = { opt.Element and opt.Element.Value, opt.Value }
		for _, v in ipairs(candidates) do
			if typeof(v) == "EnumItem" and v ~= Enum.KeyCode.None and v ~= Enum.KeyCode.Unknown then
				return UserInputService:IsKeyDown(v)
			end
			if type(v) == "string" and v ~= "" and v ~= "None" then
				if v == "MouseLeft" then
					return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
				elseif v == "MouseRight" then
					return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
				end
				local kc = Enum.KeyCode[v]
				if kc then return UserInputService:IsKeyDown(kc) end
			end
		end
		return false
	end)
	return ok and held or false
end
local function MoonwalkTick()
	if not MoonwalkState.Enabled then return end
	if not IsMobile then
		local fwdHeld  = _readKeyHeld(Options.MoonwalkFwdKey)
		local backHeld = _readKeyHeld(Options.MoonwalkBackKey)
		if fwdHeld and (MoonwalkState.Mode ~= "forward" or MoonwalkState.KeySource ~= "key") and MoonwalkState.KeySource ~= "btn" then
			StartMode("forward", "key"); UpdateAllBtnVisuals()
		elseif backHeld and (MoonwalkState.Mode ~= "backward" or MoonwalkState.KeySource ~= "key") and MoonwalkState.KeySource ~= "btn" then
			StartMode("backward", "key"); UpdateAllBtnVisuals()
		end
		if MoonwalkState.KeySource == "key" then
			if MoonwalkState.Mode == "forward" and not fwdHeld then
				StopMoonwalk(); UpdateAllBtnVisuals(); return
			elseif MoonwalkState.Mode == "backward" and not backHeld then
				StopMoonwalk(); UpdateAllBtnVisuals(); return
			end
		end
	end
	if not MoonwalkState.Mode then return end
	local ch = Players.LocalPlayer.Character
	if not ch then StopMoonwalk(); UpdateAllBtnVisuals(); return end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then StopMoonwalk(); UpdateAllBtnVisuals(); return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then return end
	local camFwd = flat.Unit
	local targetYaw
	if MoonwalkState.Mode == "backward" then
		targetYaw = math.atan2(camFwd.X, camFwd.Z)
	else
		targetYaw = math.atan2(-camFwd.X, -camFwd.Z)
	end
	if _mwCurrentYaw == nil then
		local hrpLook = hrp.CFrame.LookVector
		_mwCurrentYaw = math.atan2(hrpLook.X, hrpLook.Z)
	end
	local yawDiff = math.atan2(math.sin(targetYaw - _mwCurrentYaw), math.cos(targetYaw - _mwCurrentYaw))
	local yawAlpha = math.min(1, MW_YAW_LERP * (1/60))
	_mwCurrentYaw = _mwCurrentYaw + yawDiff * yawAlpha
	local targetWobble = 0
	local moveDir = hum.MoveDirection
	if moveDir.Magnitude > 0.05 then
		local flatMove = Vector3.new(moveDir.X, 0, moveDir.Z)
		if flatMove.Magnitude > 0.01 then
			local curDir = Vector3.new(math.sin(_mwCurrentYaw), 0, math.cos(_mwCurrentYaw))
			local cross = curDir:Cross(flatMove.Unit)
			local lateralRaw = cross.Y
			local moveStrength = math.clamp(flatMove.Magnitude, 0, 1)
			targetWobble = math.clamp(lateralRaw, -1, 1) * MW_WOBBLE_MAX * moveStrength
		end
	end
	local wobbleDiff = targetWobble - _mwCurrentWobble
	local wobbleAlpha = math.min(1, MW_WOBBLE_LERP * (1/60))
	_mwCurrentWobble = _mwCurrentWobble + wobbleDiff * wobbleAlpha
	local finalYaw = _mwCurrentYaw + _mwCurrentWobble
	local finalDir = Vector3.new(math.sin(finalYaw), 0, math.cos(finalYaw))
	hum.AutoRotate = false
	hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + finalDir)
end
local function CreateMoonwalkButtons()
	if MoonwalkState.GUI then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "StarshipMoonwalk"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	pcall(function() gui.Parent = game:GetService("CoreGui") end)
	if not gui.Parent then gui.Parent = Players.LocalPlayer:FindFirstChild("PlayerGui") end
	MoonwalkState.GUI = gui
	local ARROW_IMG = "rbxassetid://125598796341580"
	local BTN_SIZE  = 42
	local GAP       = 8
	local container = Instance.new("Frame")
	container.Name = "MoonwalkBtns"
	container.Parent = gui
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(1, 1)
	container.Position = UDim2.new(1, -18, 1, -170)
	container.Size = UDim2.new(0, BTN_SIZE + 4, 0, BTN_SIZE * 2 + GAP + 4)
	container.ClipsDescendants = false
	local function MakeBtn(name, arrowRot, yOff)
		local btn = Instance.new("ImageButton")
		btn.Name = name
		btn.Parent = container
		btn.AnchorPoint = Vector2.new(0.5, 0)
		btn.Position = UDim2.new(0.5, 0, 0, yOff)
		btn.Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Image = ARROW_IMG
		btn.ImageColor3 = Color3.fromRGB(170, 170, 170)
		btn.ImageTransparency = 0.25
		btn.Rotation = arrowRot
		btn.ScaleType = Enum.ScaleType.Fit
		return btn
	end
	_mwFwdBtn  = MakeBtn("Forward",  -90, 0)
	_mwBackBtn = MakeBtn("Backward",  90, BTN_SIZE + GAP)
	UpdateAllBtnVisuals()
	local function HookHoldBtn(btn, mode)
		local activeTouch = nil
		btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			activeTouch = (input.UserInputType == Enum.UserInputType.Touch) and input or nil
			StartMode(mode, "btn")
			UpdateAllBtnVisuals()
		end
	end)
	btn.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		activeTouch = nil
		if MoonwalkState.Mode == mode and MoonwalkState.KeySource == "btn" then
			StopMoonwalk()
			UpdateAllBtnVisuals()
		end
	end
end)
if IsMobile then
	UserInputService.TouchEnded:Connect(function(input)
	if activeTouch and input == activeTouch then
		activeTouch = nil
		if MoonwalkState.Mode == mode and MoonwalkState.KeySource == "btn" then
			StopMoonwalk()
			UpdateAllBtnVisuals()
		end
	end
end)
end
end
HookHoldBtn(_mwFwdBtn, "forward")
HookHoldBtn(_mwBackBtn, "backward")
end
local function DestroyMoonwalkButtons()
	_mwBackBtn = nil
	_mwFwdBtn = nil
	if MoonwalkState.GUI then
		MoonwalkState.GUI:Destroy()
		MoonwalkState.GUI = nil
	end
end
AgilityBox:AddCheckbox('MoonwalkToggle', {
Text = 'Moonwalk',
Default = false,
Tooltip = 'Fly me to the moon',
Callback = function(Value)
MoonwalkState.Enabled = Value
if Value then
	CreateMoonwalkButtons()
	if not MoonwalkState.Connection then
		MoonwalkState.Connection = RunService.RenderStepped:Connect(function()
		pcall(MoonwalkTick)
	end)
end
Library:Notify('Moonwalk: Enabled', 2)
else
	StopMoonwalk()
	DestroyMoonwalkButtons()
	if MoonwalkState.Connection then
		MoonwalkState.Connection:Disconnect()
		MoonwalkState.Connection = nil
	end
	Library:Notify('Moonwalk: Disabled', 2)
end
end
}):AddKeyPicker('MoonwalkFwdKey', {
Default = 'None',
Text = 'MW Forward',
Mode = 'Hold',
SyncToggleState = false,
NoUI = false,
}):AddKeyPicker('MoonwalkBackKey', {
Default = 'None',
Text = 'MW Backward',
Mode = 'Hold',
SyncToggleState = false,
NoUI = false,
})
Library:OnUnload(function()
StopMoonwalk()
DestroyMoonwalkButtons()
if MoonwalkState.Connection then
	MoonwalkState.Connection:Disconnect()
	MoonwalkState.Connection = nil
end
end)
end
if not VDSurvivorState.ForceAntiCampInitialized then
	VDSurvivorState.ForceAntiCampInitialized = true
	VDSurvivorState.ForceAntiCampEnabled = false
	VDSurvivorState.ForceAntiCampConnection = nil
	VDSurvivorState.ForceAntiCampDebug = false
	VDSurvivorState.ForceAntiCampStickDistance = 15
	VDSurvivorState.ForceAntiCampVisualMode = true
	VDSurvivorState.ForceAntiCampStealthMode = true
end
VDSurvivorState.ForceAntiCampPhase = "IDLE"
VDSurvivorState.ForceAntiCampSavedHookPos = nil
VDSurvivorState.ForceAntiCampSavedHookCFrame = nil
VDSurvivorState.ForceAntiCampTargetKiller = nil
VDSurvivorState.ForceAntiCampBodyUnlocked = false
VDSurvivorState.ForceAntiCampReadyNotified = false
VDSurvivorState.ForceAntiCampStickStartTime = 0
VDSurvivorState.ForceAntiCampLastLogTime = 0
VDSurvivorState.ForceAntiCampHookWaitStart = 0
VDSurvivorState.ForceAntiCampHookObject = nil
VDSurvivorState.ForceAntiCampFakeBody = nil
VDSurvivorState.ForceAntiCampOriginalTransparencies = {}
VDSurvivorState.ForceAntiCampCameraLocked = false
VDSurvivorState.ForceAntiCampOriginalCameraSubject = nil
VDSurvivorState.ForceAntiCampWasHooked = false
VDSurvivorState.ForceAntiCampHookTransitionDetected = false
VDSurvivorState.ForceAntiCampCurrentGen = nil
VDSurvivorState.ForceAntiCampRepairStartTime = 0
VDSurvivorState.ForceAntiCampRepairWaitStart = 0
VDSurvivorState.ForceAntiCampDesyncActive = false
VDSurvivorState.ForceAntiCampDesyncServerPos = nil
VDSurvivorState.ForceAntiCampDesyncConnection = nil
VDSurvivorState.ForceAntiCampDesyncCameraAnchor = nil
VDSurvivorState.ForceAntiCampDesyncCameraConnection = nil
local function AntiCampDebug(msg, forceShow)
	if VDSurvivorState.ForceAntiCampDebug or forceShow then
	end
end
local AntiCampDesyncStorage = {
ServerPosition = nil,
ClientPosition = nil,
Distance = 0,
IsActive = false
}
local function ResetAntiCampState()
	VDSurvivorState.ForceAntiCampSavedHookPos = nil
	VDSurvivorState.ForceAntiCampSavedHookCFrame = nil
	VDSurvivorState.ForceAntiCampTargetKiller = nil
	VDSurvivorState.ForceAntiCampBodyUnlocked = false
	VDSurvivorState.ForceAntiCampReadyNotified = false
	VDSurvivorState.ForceAntiCampStickStartTime = 0
	VDSurvivorState.ForceAntiCampLastLogTime = 0
	VDSurvivorState.ForceAntiCampHookWaitStart = 0
	VDSurvivorState.ForceAntiCampHookObject = nil
	VDSurvivorState.ForceAntiCampHookTransitionDetected = false
	VDSurvivorState.ForceAntiCampCurrentGen = nil
	VDSurvivorState.ForceAntiCampRepairStartTime = 0
	VDSurvivorState.ForceAntiCampRepairWaitStart = 0
	VDSurvivorState.ForceAntiCampRepairAttempts = 0
	VDSurvivorState.ForceAntiCampDesyncActive = false
	VDSurvivorState.ForceAntiCampDesyncServerPos = nil
	AntiCampDesyncStorage.ServerPosition = nil
	AntiCampDesyncStorage.ClientPosition = nil
	AntiCampDesyncStorage.Distance = 0
	AntiCampDesyncStorage.IsActive = false
	AntiCampDebug("State RESET: BodyUnlocked = " .. tostring(VDSurvivorState.ForceAntiCampBodyUnlocked), true)
end
local function CreateDesyncCameraAnchor()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local anchor = Instance.new("Part")
	anchor.Name = "AntiCampDesyncAnchor"
	anchor.Size = Vector3.new(2, 2, 2)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Anchored = true
	anchor.CFrame = hrp.CFrame
	anchor.Parent = workspace
	return anchor
end
local function StartStealthDesync()
	if not VDSurvivorState.ForceAntiCampStealthMode then return end
	if VDSurvivorState.ForceAntiCampDesyncActive then return end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		AntiCampDebug("Cannot start desync - no HRP/Humanoid", true)
		return
	end
	local hookCFrame = VDSurvivorState.ForceAntiCampSavedHookCFrame or hrp.CFrame
	VDSurvivorState.ForceAntiCampDesyncServerPos = hookCFrame
	VDSurvivorState.ForceAntiCampDesyncActive = true
	AntiCampDesyncStorage.ServerPosition = hookCFrame
	AntiCampDesyncStorage.ClientPosition = hrp.CFrame
	AntiCampDesyncStorage.IsActive = true
	AntiCampDebug("══════════════════════════════════════", true)
	AntiCampDebug("🔮 STEALTH DESYNC ACTIVATED!", true)
	AntiCampDebug("Server frozen at: " .. tostring(hookCFrame.Position), true)
	AntiCampDebug("Others see you on hook! You move freely!", true)
	AntiCampDebug("══════════════════════════════════════", true)
	local cam = workspace.CurrentCamera
	if cam then
		VDSurvivorState.ForceAntiCampOriginalCameraSubject = cam.CameraSubject
		VDSurvivorState.ForceAntiCampOriginalCameraType = cam.CameraType
	end
	local orbitDistance = 10
	local orbitYaw = 0
	local orbitPitch = 0.3
	local mouseSensitivity = 0.003
	local mouseConnection = nil
	local UserInputService = game:GetService("UserInputService")
	mouseConnection = UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if not VDSurvivorState.ForceAntiCampDesyncActive then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		orbitYaw = orbitYaw - input.Delta.X * mouseSensitivity
		orbitPitch = math.clamp(orbitPitch + input.Delta.Y * mouseSensitivity, -1.2, 1.2)
	end
end)
VDSurvivorState.ForceAntiCampMouseConnection = mouseConnection
VDSurvivorState.ForceAntiCampDesyncCameraConnection = RunService.RenderStepped:Connect(function()
if VDSurvivorState.ForceAntiCampDesyncActive then
	local cam = workspace.CurrentCamera
	if not cam then return end
	local fakeHRP = nil
	if VDSurvivorState.ForceAntiCampFakeBody then
		fakeHRP = VDSurvivorState.ForceAntiCampFakeBody:FindFirstChild("HumanoidRootPart")
	end
	local targetPosition = nil
	if fakeHRP and fakeHRP.Anchored then
		targetPosition = fakeHRP.Position
	elseif VDSurvivorState.ForceAntiCampSavedHookCFrame then
		targetPosition = VDSurvivorState.ForceAntiCampSavedHookCFrame.Position
	else
		return
	end
	local lookAtPosition = targetPosition + Vector3.new(0, 2, 0)
	local horizontalDist = orbitDistance * math.cos(orbitPitch)
	local verticalOffset = orbitDistance * math.sin(orbitPitch)
	local cameraOffset = Vector3.new(
	horizontalDist * math.sin(orbitYaw),
	verticalOffset + 2,
	horizontalDist * math.cos(orbitYaw)
	)
	local cameraPosition = targetPosition + cameraOffset
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.new(cameraPosition, lookAtPosition)
	cam.Focus = CFrame.new(targetPosition)
end
end)
VDSurvivorState.ForceAntiCampDesyncCameraAnchor = CreateDesyncCameraAnchor()
if VDSurvivorState.ForceAntiCampDesyncCameraAnchor then
	VDSurvivorState.ForceAntiCampDesyncCameraAnchor.CFrame = hookCFrame
end
VDSurvivorState.ForceAntiCampDesyncConnection = RunService.Heartbeat:Connect(function()
if not VDSurvivorState.ForceAntiCampDesyncActive then return end
if not VDSurvivorState.ForceAntiCampEnabled then return end
local char = LocalPlayer.Character
local hrp = char and char:FindFirstChild("HumanoidRootPart")
if not hrp then return end
local realCFrame = hrp.CFrame
local realVelocity = hrp.AssemblyLinearVelocity
AntiCampDesyncStorage.ClientPosition = realCFrame
AntiCampDesyncStorage.Distance = (realCFrame.Position - VDSurvivorState.ForceAntiCampDesyncServerPos.Position)
.Magnitude
hrp.CFrame = VDSurvivorState.ForceAntiCampDesyncServerPos
hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
RunService.RenderStepped:Wait()
if hrp and VDSurvivorState.ForceAntiCampDesyncActive then
	hrp.CFrame = realCFrame
	hrp.AssemblyLinearVelocity = realVelocity
end
end)
end
local function StopStealthDesync()
	if not VDSurvivorState.ForceAntiCampDesyncActive then return end
	AntiCampDebug("══════════════════════════════════════", true)
	AntiCampDebug("🔮 STEALTH DESYNC DEACTIVATED", true)
	AntiCampDebug("Resyncing to hook position...", true)
	AntiCampDebug("══════════════════════════════════════", true)
	if VDSurvivorState.ForceAntiCampDesyncConnection then
		pcall(function() VDSurvivorState.ForceAntiCampDesyncConnection:Disconnect() end)
		VDSurvivorState.ForceAntiCampDesyncConnection = nil
	end
	if VDSurvivorState.ForceAntiCampDesyncCameraConnection then
		pcall(function() VDSurvivorState.ForceAntiCampDesyncCameraConnection:Disconnect() end)
		VDSurvivorState.ForceAntiCampDesyncCameraConnection = nil
	end
	if VDSurvivorState.ForceAntiCampMouseConnection then
		pcall(function() VDSurvivorState.ForceAntiCampMouseConnection:Disconnect() end)
		VDSurvivorState.ForceAntiCampMouseConnection = nil
	end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and VDSurvivorState.ForceAntiCampDesyncServerPos then
		hrp.CFrame = VDSurvivorState.ForceAntiCampDesyncServerPos
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end
	local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		if humanoid then
			cam.CameraSubject = humanoid
		end
	end
	if VDSurvivorState.ForceAntiCampDesyncCameraAnchor then
		pcall(function() VDSurvivorState.ForceAntiCampDesyncCameraAnchor:Destroy() end)
		VDSurvivorState.ForceAntiCampDesyncCameraAnchor = nil
	end
	VDSurvivorState.ForceAntiCampDesyncActive = false
	VDSurvivorState.ForceAntiCampDesyncServerPos = nil
	AntiCampDesyncStorage.ServerPosition = nil
	AntiCampDesyncStorage.ClientPosition = nil
	AntiCampDesyncStorage.Distance = 0
	AntiCampDesyncStorage.IsActive = false
end
local function IsLocalPlayerHooked()
	local char = LocalPlayer.Character
	if not char then return false end
	if char:GetAttribute("Hooked") or char:GetAttribute("IsHooked") then
		return true
	end
	if VDSettings.RemoteStatuses and VDSettings.RemoteStatuses[LocalPlayer] == "Hooked" then
		return true
	end
	if VDSettings.PlayerStatuses and VDSettings.PlayerStatuses[LocalPlayer] == "Hooked" then
		return true
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track.IsPlaying then
					local name = string.lower(track.Animation.Name)
					if name:find("struggle") or name:find("hook") or name:find("hang") then
						return true
					end
				end
			end
		end
	end
	return false
end
local function FindPlayerHookObject()
	local char = LocalPlayer.Character
	if not char then return nil end
	local myRoot = char:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end
	local myPos = myRoot.Position
	local nearestHook = nil
	local nearestDist = 20
	pcall(function()
	local searchIn = workspace:FindFirstChild("Map") or workspace
	for _, obj in ipairs(searchIn:GetDescendants()) do
		if obj:IsA("Model") and (obj.Name:lower():find("hook") or obj.Name:lower():find("meat")) then
			local hookPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			if hookPart then
				local dist = (hookPart.Position - myPos).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestHook = obj
				end
			end
		end
	end
end)
return nearestHook
end
local function GetHookPosition(hookObj)
	if not hookObj then return nil end
	local hookPart = nil
	pcall(function()
	hookPart = hookObj:FindFirstChild("HookPoint")
	or hookObj:FindFirstChild("Point")
	or hookObj:FindFirstChild("SurvivorPoint")
	or hookObj.PrimaryPart
	or hookObj:FindFirstChildWhichIsA("BasePart")
end)
if hookPart then
	return hookPart.CFrame
end
return nil
end
local function IsAntiCamp100()
	local char = LocalPlayer.Character
	if not char then return false end
	local antiCampProgress = char:GetAttribute("AntiCampProgress")
	or char:GetAttribute("AntiCamp")
	or char:GetAttribute("CampProgress")
	or char:GetAttribute("SelfUnhookChance")
	if antiCampProgress and antiCampProgress >= 100 then
		return true
	end
	if char:GetAttribute("CanSelfUnhook") == true then
		return true
	end
	local status = char:FindFirstChild("Status")
	if status then
		local selfUnhook = status:FindFirstChild("SelfUnhook") or status:FindFirstChild("CanSelfUnhook")
		if selfUnhook then
			if selfUnhook:IsA("BoolValue") and selfUnhook.Value == true then
				return true
			elseif selfUnhook:IsA("NumberValue") and selfUnhook.Value >= 100 then
				return true
			end
		end
		local antiCamp = status:FindFirstChild("AntiCamp") or status:FindFirstChild("AntiCampProgress")
		if antiCamp and antiCamp:IsA("NumberValue") and antiCamp.Value >= 100 then
			return true
		end
	end
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		for _, gui in ipairs(playerGui:GetDescendants()) do
			if gui:IsA("TextLabel") or gui:IsA("TextButton") then
				local text = gui.Text:upper()
				if text:find("TAKE A CHANCE") or text:find("FREE YOURSELF") then
					if text:find("100") then
						return true
					end
				end
			end
		end
	end
	return false
end
local function GetNearestKillerPlayer()
	local char = LocalPlayer.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end
	local nearestPlayer = nil
	local nearestDist = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and IsKiller(player) and player.Character then
			local kRoot = player.Character:FindFirstChild("HumanoidRootPart")
			if kRoot then
				local dist = (kRoot.Position - myRoot.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestPlayer = player
				end
			end
		end
	end
	return nearestPlayer
end
local function FindNearestGenerator()
	local char = LocalPlayer.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	local refPos = myRoot and myRoot.Position or Vector3.new(0, 0, 0)
	local nearest = nil
	local nearestDist = math.huge
	pcall(function()
	local searchIn = workspace:FindFirstChild("Map") or workspace
	for _, obj in ipairs(searchIn:GetDescendants()) do
		if obj:IsA("Model") and obj.Name == "Generator" then
			local genPt = nil
			local genPos = nil
			for _, child in ipairs(obj:GetChildren()) do
				if child.Name:match("GeneratorPoint") and child:IsA("BasePart") then
					genPt = child
					genPos = child.Position
					break
				end
			end
			if not genPos and obj.PrimaryPart then
				genPos = obj.PrimaryPart.Position
			end
			if genPos then
				local dist = (genPos - refPos).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearest = {
					model = obj,
					point = genPt,
					position = genPos
					}
				end
			end
		end
	end
end)
return nearest, nearestDist
end
local function FireRepairToUnlockBlocking(genData)
	local success = false
	local repairCount = 0
	local char = LocalPlayer.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not myRoot then
		AntiCampDebug("✗ No HumanoidRootPart!", true)
		return false, 0
	end
	pcall(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		AntiCampDebug("✗ Remotes folder not found!", true)
		return
	end
	local genRemotes = remotes:FindFirstChild("Generator")
	if not genRemotes then
		AntiCampDebug("✗ Generator folder not found!", true)
		return
	end
	local repairEvent = genRemotes:FindFirstChild("RepairEvent")
	if repairEvent then
		AntiCampDebug("Found RepairEvent! Using SILENT method...", true)
		if genData and genData.point then
			for i = 1, 10 do
				repairEvent:FireServer(genData.point, true)
				repairEvent:FireServer(genData.point)
				repairCount = repairCount + 2
			end
			AntiCampDebug("Fired gen.point x20", true)
		end
		for i = 1, 30 do
			repairEvent:FireServer(myRoot.Position, false)
			repairEvent:FireServer(myRoot.Position)
			repairCount = repairCount + 2
		end
		AntiCampDebug("Fired myRoot.Position x60 (RAW REPAIR)", true)
		if genData and genData.position then
			for i = 1, 10 do
				repairEvent:FireServer(genData.position, true)
				repairCount = repairCount + 1
			end
			AntiCampDebug("Fired gen.position x10", true)
		end
		success = true
		AntiCampDebug("✓ TOTAL: Fired repair x" .. repairCount .. " to unlock body!", true)
	else
		AntiCampDebug("✗ RepairEvent not found!", true)
	end
end)
return success, repairCount
end
local function CreateFakeBodyAtHook()
	if not VDSurvivorState.ForceAntiCampVisualMode then return end
	if VDSurvivorState.ForceAntiCampFakeBody then
		pcall(function() VDSurvivorState.ForceAntiCampFakeBody:Destroy() end)
		VDSurvivorState.ForceAntiCampFakeBody = nil
	end
	local char = LocalPlayer.Character
	if not char then return end
	pcall(function()
	local fakeBody = char:Clone()
	fakeBody.Name = "AntiCampFakeBody"
	for _, child in ipairs(fakeBody:GetDescendants()) do
		if child:IsA("Script") or child:IsA("LocalScript") then
			child:Destroy()
		end
	end
	local fakeHumanoid = fakeBody:FindFirstChildOfClass("Humanoid")
	if fakeHumanoid then
		local animator = fakeHumanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0)
			end
		end
		fakeHumanoid:Destroy()
	end
	for _, child in ipairs(fakeBody:GetDescendants()) do
		if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
			child:Destroy()
		elseif child:IsA("Animator") or child:IsA("AnimationController") then
			child:Destroy()
		end
	end
	local animateScript = fakeBody:FindFirstChild("Animate")
	if animateScript then
		animateScript:Destroy()
	end
	local fakeRoot = fakeBody:FindFirstChild("HumanoidRootPart")
	if fakeRoot and VDSurvivorState.ForceAntiCampSavedHookCFrame then
		fakeRoot.CFrame = VDSurvivorState.ForceAntiCampSavedHookCFrame
		fakeRoot.Anchored = true
		fakeRoot.CanCollide = false
		fakeRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		fakeRoot.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end
	for _, part in ipairs(fakeBody:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
	end
	fakeBody.Parent = workspace
	VDSurvivorState.ForceAntiCampFakeBody = fakeBody
	AntiCampDebug("Created FROZEN fake body at hook position")
end)
end
local function MakeRealCharacterInvisible()
	if not VDSurvivorState.ForceAntiCampVisualMode then return end
	local char = LocalPlayer.Character
	if not char then return end
	VDSurvivorState.ForceAntiCampOriginalTransparencies = {}
	pcall(function()
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			VDSurvivorState.ForceAntiCampOriginalTransparencies[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		elseif part:IsA("Decal") or part:IsA("Texture") then
			VDSurvivorState.ForceAntiCampOriginalTransparencies[part] = part.Transparency
			part.Transparency = 1
		end
	end
	AntiCampDebug("Made real character invisible")
end)
end
local function RestoreRealCharacterVisibility()
	local char = LocalPlayer.Character
	if not char then return end
	pcall(function()
	for part, originalValue in pairs(VDSurvivorState.ForceAntiCampOriginalTransparencies) do
		if part and part.Parent then
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = originalValue or 0
			elseif part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = originalValue or 0
			end
		end
	end
	VDSurvivorState.ForceAntiCampOriginalTransparencies = {}
	AntiCampDebug("Restored real character visibility")
end)
end
local function DestroyFakeBody()
	if VDSurvivorState.ForceAntiCampFakeBody then
		pcall(function() VDSurvivorState.ForceAntiCampFakeBody:Destroy() end)
		VDSurvivorState.ForceAntiCampFakeBody = nil
		AntiCampDebug("Destroyed fake body")
	end
end
local function LockCameraToHook()
	if not VDSurvivorState.ForceAntiCampVisualMode then return end
	if VDSurvivorState.ForceAntiCampCameraLocked then return end
	pcall(function()
	local cam = workspace.CurrentCamera
	if cam and VDSurvivorState.ForceAntiCampFakeBody then
		local fakeHumanoid = VDSurvivorState.ForceAntiCampFakeBody:FindFirstChildOfClass("Humanoid")
		if fakeHumanoid then
			VDSurvivorState.ForceAntiCampOriginalCameraSubject = cam.CameraSubject
			cam.CameraSubject = fakeHumanoid
			VDSurvivorState.ForceAntiCampCameraLocked = true
			AntiCampDebug("Camera locked to fake body at hook")
		end
	end
end)
end
local function UnlockCamera()
	pcall(function()
	local cam = workspace.CurrentCamera
	if cam and VDSurvivorState.ForceAntiCampOriginalCameraSubject then
		cam.CameraSubject = VDSurvivorState.ForceAntiCampOriginalCameraSubject
		VDSurvivorState.ForceAntiCampOriginalCameraSubject = nil
	end
	VDSurvivorState.ForceAntiCampCameraLocked = false
	AntiCampDebug("Camera unlocked")
end)
end
local function CleanupVisualTricks()
	RestoreRealCharacterVisibility()
	DestroyFakeBody()
	UnlockCamera()
	StopStealthDesync()
end
local function ProcessAntiCampPhaseV13()
	if not VDSurvivorState.ForceAntiCampEnabled then return end
	local char = LocalPlayer.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not myRoot then return end
	local phase = VDSurvivorState.ForceAntiCampPhase
	local activePhases = { UNLOCKING = true, REPAIRING = true, WAIT_REPAIR = true, STICKING = true }
	local shouldBeInvisible = activePhases[phase] == true
	if shouldBeInvisible and not GFS.InvisEnabledByAntiCamp then
		if _G.EnableInvisibilityForAntiCamp then
			_G.EnableInvisibilityForAntiCamp()
			AntiCampDebug("🔹 Invisibility AUTO-ON (Phase: " .. phase .. ")", true)
		end
	elseif not shouldBeInvisible and GFS.InvisEnabledByAntiCamp then
		if _G.DisableInvisibilityForAntiCamp then
			_G.DisableInvisibilityForAntiCamp()
			AntiCampDebug("🔹 Invisibility AUTO-OFF (Phase: " .. phase .. ")", true)
		end
	end
	local isCurrentlyHooked = IsLocalPlayerHooked()
	local wasHooked = VDSurvivorState.ForceAntiCampWasHooked
	if isCurrentlyHooked and not wasHooked then
		AntiCampDebug("══════════════════════════════════════", true)
		AntiCampDebug("🔴 HOOK TRANSITION DETECTED!", true)
		AntiCampDebug("WasHooked: " .. tostring(wasHooked) .. " → IsHooked: " .. tostring(isCurrentlyHooked), true)
		AntiCampDebug("This is a NEW HOOK - forcing full reset!", true)
		AntiCampDebug("══════════════════════════════════════", true)
		CleanupVisualTricks()
		ResetAntiCampState()
		VDSurvivorState.ForceAntiCampBodyUnlocked = false
		VDSurvivorState.ForceAntiCampHookTransitionDetected = true
		VDSurvivorState.ForceAntiCampPhase = "IDLE"
	end
	VDSurvivorState.ForceAntiCampWasHooked = isCurrentlyHooked
	local phase = VDSurvivorState.ForceAntiCampPhase
	if phase == "IDLE" then
		if VDSurvivorState.ForceAntiCampHookTransitionDetected and isCurrentlyHooked then
			AntiCampDebug("Processing hook transition...", true)
			AntiCampDebug(
			"BodyUnlocked = " .. tostring(VDSurvivorState.ForceAntiCampBodyUnlocked) .. " (should be FALSE!)",
			true)
			VDSurvivorState.ForceAntiCampHookTransitionDetected = false
			VDSurvivorState.ForceAntiCampHookWaitStart = tick()
			VDSurvivorState.ForceAntiCampPhase = "WAIT_HOOK"
		end
	elseif phase == "WAIT_HOOK" then
		if not IsLocalPlayerHooked() then
			AntiCampDebug("No longer hooked during wait", true)
			VDSurvivorState.ForceAntiCampPhase = "IDLE"
			return
		end
		local waitTime = tick() - VDSurvivorState.ForceAntiCampHookWaitStart
		if waitTime < 2.0 then
			if math.floor(waitTime * 2) > math.floor((waitTime - 0.05) * 2) then
				AntiCampDebug("Waiting for hook to stabilize... " .. string.format("%.1f", waitTime) .. "s / 2.0s",
				true)
			end
			return
		end
		AntiCampDebug("Hook stabilized after " .. string.format("%.2f", waitTime) .. "s", true)
		VDSurvivorState.ForceAntiCampSavedHookPos = myRoot.Position
		VDSurvivorState.ForceAntiCampSavedHookCFrame = myRoot.CFrame
		local hookObj = FindPlayerHookObject()
		if hookObj then
			VDSurvivorState.ForceAntiCampHookObject = hookObj
			local hookCFrame = GetHookPosition(hookObj)
			if hookCFrame then
				VDSurvivorState.ForceAntiCampSavedHookCFrame = hookCFrame
				VDSurvivorState.ForceAntiCampSavedHookPos = hookCFrame.Position
				AntiCampDebug("Found hook object: " .. hookObj.Name, true)
			end
		end
		AntiCampDebug("Saved hook position: " .. tostring(VDSurvivorState.ForceAntiCampSavedHookPos), true)
		CreateFakeBodyAtHook()
		StartStealthDesync()
		AntiCampDebug("Transitioning WAIT_HOOK → UNLOCKING", true)
		AntiCampDebug("BodyUnlocked at transition = " .. tostring(VDSurvivorState.ForceAntiCampBodyUnlocked), true)
		VDSurvivorState.ForceAntiCampPhase = "UNLOCKING"
	elseif phase == "UNLOCKING" then
		AntiCampDebug(
		"UNLOCKING phase entered! BodyUnlocked = " .. tostring(VDSurvivorState.ForceAntiCampBodyUnlocked), true)
		if not IsLocalPlayerHooked() then
			AntiCampDebug("No longer hooked, cleaning up...", true)
			CleanupVisualTricks()
			VDSurvivorState.ForceAntiCampPhase = "IDLE"
			return
		end
		if VDSurvivorState.ForceAntiCampBodyUnlocked then
			AntiCampDebug("⚠️ Body already unlocked! This should NOT happen!", true)
			AntiCampDebug("Moving to STICKING...", true)
			VDSurvivorState.ForceAntiCampPhase = "STICKING"
			return
		end
		AntiCampDebug("✓ BodyUnlocked is FALSE - proceeding with unlock!", true)
		local gen, genDist = FindNearestGenerator()
		if gen then
			local tpPos = gen.position + Vector3.new(0, 2, 0)
			myRoot.CFrame = CFrame.new(tpPos)
			AntiCampDebug("TP'd to generator! Distance: " .. math.floor(genDist), true)
			VDSurvivorState.ForceAntiCampCurrentGen = gen
			VDSurvivorState.ForceAntiCampPhase = "REPAIRING"
			VDSurvivorState.ForceAntiCampRepairStartTime = tick()
			Library:Notify("Anti-Camp Repairing...", 1)
		else
			AntiCampDebug("No generator found! Skipping repair...", true)
			VDSurvivorState.ForceAntiCampTargetKiller = GetNearestKillerPlayer()
			VDSurvivorState.ForceAntiCampStickStartTime = tick()
			VDSurvivorState.ForceAntiCampLastLogTime = tick()
			VDSurvivorState.ForceAntiCampBodyUnlocked = true
			VDSurvivorState.ForceAntiCampPhase = "STICKING"
		end
	elseif phase == "REPAIRING" then
		if not IsLocalPlayerHooked() then
			AntiCampDebug("No longer hooked during repair, cleaning up...", true)
			CleanupVisualTricks()
			VDSurvivorState.ForceAntiCampPhase = "IDLE"
			return
		end
		local gen = VDSurvivorState.ForceAntiCampCurrentGen
		if gen then
			AntiCampDebug("══════════════════════════════════════", true)
			AntiCampDebug(">>> FIRING REPAIR EVENTS <<<", true)
			AntiCampDebug("Generator: " .. tostring(gen), true)
			local success, count = FireRepairToUnlockBlocking(gen)
			if success then
				AntiCampDebug("✓ Repair events fired: " .. tostring(count), true)
				AntiCampDebug("══════════════════════════════════════", true)
				if not VDSurvivorState.ForceAntiCampRepairAttempts then
					VDSurvivorState.ForceAntiCampRepairAttempts = 0
				end
				VDSurvivorState.ForceAntiCampRepairWaitStart = tick()
				VDSurvivorState.ForceAntiCampPhase = "WAIT_REPAIR"
				AntiCampDebug("Waiting 0.5s for server to process repair...", true)
			else
				AntiCampDebug("✗ Repair FAILED! Retrying...", true)
			end
		else
			AntiCampDebug("No generator data! Skipping to STICKING...", true)
			VDSurvivorState.ForceAntiCampBodyUnlocked = true
			VDSurvivorState.ForceAntiCampPhase = "STICKING"
		end
	elseif phase == "WAIT_REPAIR" then
		if not IsLocalPlayerHooked() then
			AntiCampDebug("No longer hooked during wait, cleaning up...", true)
			CleanupVisualTricks()
			VDSurvivorState.ForceAntiCampPhase = "IDLE"
			return
		end
		local waitTime = tick() - VDSurvivorState.ForceAntiCampRepairWaitStart
		if waitTime < 0.8 then
			return
		end
		AntiCampDebug("══════════════════════════════════════", true)
		AntiCampDebug("✓✓✓ REPAIR COMPLETE - PROCEEDING ✓✓✓", true)
		AntiCampDebug("Wait time: " .. string.format("%.2f", waitTime) .. "s", true)
		AntiCampDebug("══════════════════════════════════════", true)
		VDSurvivorState.ForceAntiCampBodyUnlocked = true
		VDSurvivorState.ForceAntiCampCurrentGen = nil
		VDSurvivorState.ForceAntiCampRepairAttempts = 0
		VDSurvivorState.ForceAntiCampTargetKiller = GetNearestKillerPlayer()
		VDSurvivorState.ForceAntiCampStickStartTime = tick()
		VDSurvivorState.ForceAntiCampLastLogTime = tick()
		VDSurvivorState.ForceAntiCampPhase = "STICKING"
	elseif phase == "STICKING" then
		if not IsLocalPlayerHooked() then
			AntiCampDebug("══════════════════════════════════════", true)
			AntiCampDebug("NO LONGER HOOKED!", true)
			AntiCampDebug("══════════════════════════════════════", true)
			CleanupVisualTricks()
			VDSurvivorState.ForceAntiCampPhase = "IDLE"
			return
		end
		if IsAntiCamp100() then
			AntiCampDebug("══════════════════════════════════════", true)
			AntiCampDebug("100% ANTI-CAMP DETECTED!", true)
			AntiCampDebug("TP back to hook for self-unhook!", true)
			AntiCampDebug("══════════════════════════════════════", true)
			VDSurvivorState.ForceAntiCampPhase = "READY_UNHOOK"
			return
		end
		local killer = VDSurvivorState.ForceAntiCampTargetKiller
		if not killer or not killer.Character then
			killer = GetNearestKillerPlayer()
			VDSurvivorState.ForceAntiCampTargetKiller = killer
		end
		if killer and killer.Character then
			local targetHRP = killer.Character:FindFirstChild("HumanoidRootPart")
			if targetHRP then
				local stickDist = 15
				local behindOffset = targetHRP.CFrame.LookVector * -stickDist
				local downOffset = Vector3.new(0, -10, 0)
				myRoot.CFrame = CFrame.new(targetHRP.Position + behindOffset + downOffset)
			end
		end
		if tick() - VDSurvivorState.ForceAntiCampLastLogTime >= 5 then
			local stickDuration = tick() - VDSurvivorState.ForceAntiCampStickStartTime
			local killerName = killer and killer.Name or "Unknown"
			AntiCampDebug("STICKING to " .. killerName .. ": " .. string.format("%.0f", stickDuration) .. "s", true)
			VDSurvivorState.ForceAntiCampLastLogTime = tick()
		end
	elseif phase == "READY_UNHOOK" then
		if not IsLocalPlayerHooked() then
			AntiCampDebug("Unhooked! Returning to IDLE", true)
			CleanupVisualTricks()
			VDSurvivorState.ForceAntiCampPhase = "IDLE"
			return
		end
		CleanupVisualTricks()
		if VDSurvivorState.ForceAntiCampSavedHookCFrame then
			myRoot.CFrame = VDSurvivorState.ForceAntiCampSavedHookCFrame
		end
		if not VDSurvivorState.ForceAntiCampReadyNotified then
			VDSurvivorState.ForceAntiCampReadyNotified = true
			Library:Notify("Anti-Camp progress done", 5)
			AntiCampDebug("At hook position - ready for self-unhook!", true)
		end
	end
end
local function StartForceAntiCamp()
	if VDSurvivorState.ForceAntiCampConnection then
		pcall(function() VDSurvivorState.ForceAntiCampConnection:Disconnect() end)
	end
	ResetAntiCampState()
	VDSurvivorState.ForceAntiCampPhase = "IDLE"
	CleanupVisualTricks()
	VDSurvivorState.ForceAntiCampWasHooked = false
	VDSurvivorState.ForceAntiCampHookTransitionDetected = false
	local char = LocalPlayer.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if IsLocalPlayerHooked() and myRoot then
		AntiCampDebug("══════════════════════════════════════", true)
		AntiCampDebug("⚡ ALREADY HOOKED - INSTANT START!", true)
		AntiCampDebug("Skipping wait phase - starting immediately", true)
		AntiCampDebug("══════════════════════════════════════", true)
		VDSurvivorState.ForceAntiCampSavedHookPos = myRoot.Position
		VDSurvivorState.ForceAntiCampSavedHookCFrame = myRoot.CFrame
		local hookObj = FindPlayerHookObject()
		if hookObj then
			local hookCFrame = GetHookPosition(hookObj)
			if hookCFrame then
				VDSurvivorState.ForceAntiCampSavedHookCFrame = hookCFrame
				VDSurvivorState.ForceAntiCampSavedHookPos = hookCFrame.Position
				AntiCampDebug("Using hook object position", true)
			end
		end
		AntiCampDebug("Saved hook position: " .. tostring(VDSurvivorState.ForceAntiCampSavedHookPos), true)
		CreateFakeBodyAtHook()
		StartStealthDesync()
		VDSurvivorState.ForceAntiCampBodyUnlocked = false
		VDSurvivorState.ForceAntiCampPhase = "UNLOCKING"
		AntiCampDebug("Set phase to UNLOCKING - ready to repair!", true)
	end
	VDSurvivorState.ForceAntiCampConnection = RunService.Heartbeat:Connect(function()
	ProcessAntiCampPhaseV13()
end)
AntiCampDebug("══════════════════════════════════════", true)
AntiCampDebug("Force Anti-Camp V14 STARTED", true)
AntiCampDebug("- STEALTH DESYNC (LURKOUT METHOD)", true)
AntiCampDebug("- RAW REPAIR method (myRoot.Position)", true)
AntiCampDebug("- Others see you on hook!", true)
AntiCampDebug("══════════════════════════════════════", true)
end
local function StopForceAntiCamp()
	if VDSurvivorState.ForceAntiCampConnection then
		pcall(function() VDSurvivorState.ForceAntiCampConnection:Disconnect() end)
		VDSurvivorState.ForceAntiCampConnection = nil
	end
	CleanupVisualTricks()
	StopStealthDesync()
	if _G.DisableInvisibilityForAntiCamp then
		_G.DisableInvisibilityForAntiCamp()
		AntiCampDebug("Invisibility AUTO-Disabled by Force Anti-Camp", true)
	end
	VDSurvivorState.ForceAntiCampPhase = "IDLE"
	VDSurvivorState.ForceAntiCampWasHooked = false
	AntiCampDebug("Force Anti-Camp V14 STOPPED", true)
end
UtilityBox:AddCheckbox('ForceAntiCamp', {
Text = 'Force Anti-Camp',
Default = false,
Tooltip = 'Will force anti-camp progress when hooked',
Callback = function(Value)
VDSurvivorState.ForceAntiCampEnabled = Value
if Value then
	StartForceAntiCamp()
	Library:Notify('Force Anti-Camp : Enabled', 3)
else
	StopForceAntiCamp()
	Library:Notify('Force Anti-Camp : Disabled', 2)
end
end
})
UtilityBox:AddButton({
Text = 'Instant Escape',
Tooltip = 'Attempt to instantly escape the match',
Func = _G.HandleInstantEscape
})
end
_G.InstantEscapeEnabled = false
_G.HandleInstantEscape = function()
local function IsSurvivorOnly()
	if not LocalPlayer then return false end
	if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	if LocalPlayer.Team then
		local teamName = string.lower(LocalPlayer.Team.Name or "")
		if teamName:find("survivor") then
			return true
		end
		if teamName:find("killer") or teamName:find("murder") or teamName:find("hunter") then
			return false
		end
		if teamName:find("spectator") or teamName:find("dead") or teamName:find("lobby") or teamName:find("waiting") then
			return false
		end
	end
	if IsKiller(LocalPlayer) then
		return false
	end
	local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return false
	end
	return true
end
if IsSurvivorOnly() then
	local myChar = LocalPlayer.Character
	if myChar and myChar:FindFirstChild("HumanoidRootPart") then
		local finishLineFound = false
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj.Name == "Fininshline" or obj.Name == "FinishLine" or obj.Name == "Finish" then
				if obj:IsA("BasePart") then
					myChar.HumanoidRootPart.CFrame = obj.CFrame
					finishLineFound = true
					Library:Notify('Success Escape', 2)
				elseif obj:IsA("Model") and obj.PrimaryPart then
					myChar.HumanoidRootPart.CFrame = obj.PrimaryPart.CFrame
					finishLineFound = true
					Library:Notify('Success Escape', 2)
				end
				break
			end
		end
		if not finishLineFound then
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:FindFirstChild("TouchInterest") and (obj.Parent.Name:find("Exit") or obj.Parent.Name:find("Finish") or obj.Parent.Name:find("Escape")) then
					myChar.HumanoidRootPart.CFrame = obj.CFrame
					Library:Notify('Teleported to escape trigger zone!', 2)
					finishLineFound = true
					break
				end
			end
		end
		local Remote = ReplicatedStorage:FindFirstChild("Remotes")
		if Remote then
			local ExitRemote = Remote:FindFirstChild("Exit")
			if ExitRemote and ExitRemote:FindFirstChild("LeverEvent") then
				for _, gate in ipairs(workspace:GetDescendants()) do
					if gate.Name:find("Exit") or gate.Name:find("Lever") then
						ExitRemote.LeverEvent:FireServer(gate, true)
					end
				end
			end
			task.wait(0.2)
			local GenRemote = Remote:FindFirstChild("Generator")
			if GenRemote and GenRemote:FindFirstChild("Escapetime") then
				GenRemote.Escapetime:FireServer()
			end
			local RoundRemote = Remote:FindFirstChild("Round")
			if RoundRemote then
				RoundRemote:FireServer()
			end
		end
		if finishLineFound then
			Library:Notify('You should escape in 2 seconds!', 3)
		else
			Library:Notify('Escape failed', 2)
		end
	end
else
	local reason = "Unknown"
	if IsKiller(LocalPlayer) then
		reason = "You are Killer"
	elseif not LocalPlayer.Character then
		reason = "No character (Spectator/Dead?)"
	elseif LocalPlayer.Team then
		reason = "Team: " .. LocalPlayer.Team.Name
	end
	Library:Notify("Survivors only!, buy you are now " .. reason .. "", 3)
end
end
local InitStreamerMode = function()
local StreamerBox = Tabs.Global:AddRightGroupbox('Streamer Mode', 'eye-off')
local StreamerConnections = {}
local function DisconnectStreamer()
	for _, conn in pairs(StreamerConnections) do
		if conn then pcall(function() conn:Disconnect() end) end
	end
	StreamerConnections = {}
end
_G._originalDisplayNames = _G._originalDisplayNames or {}
_G._originalGuiTexts = _G._originalGuiTexts or {}
StreamerBox:AddToggle('HideUsername', {
Text = 'Hide Username',
Default = false,
Tooltip = 'Hide ALL player names to "Starship" (in-game + ESP). Own name shown in green.',
Callback = function(Value)
_G.HideUsernameEnabled = Value
if Value then
	DisconnectStreamer()
	_G._originalGuiTexts = {}
	local function spoofPlayer(player)
		pcall(function()
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		if not _G._originalDisplayNames[player] then
			_G._originalDisplayNames[player] = hum.DisplayName
		end
		hum.DisplayName = "Starship"
	end)
end
local function watchPlayerChar(player)
	spoofPlayer(player)
	table.insert(StreamerConnections, player.CharacterAdded:Connect(function()
	task.wait(0.5)
	spoofPlayer(player)
end))
end
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayerChar(player)
end
table.insert(StreamerConnections, Players.PlayerAdded:Connect(function(player)
watchPlayerChar(player)
end))
local lp = LocalPlayer
local function spoofText(obj)
	if not obj then return end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		local function check()
			if not _G.HideUsernameEnabled then return end
			local txt = obj.Text
			local changed = false
			for _, p in ipairs(Players:GetPlayers()) do
				local origName = _G._originalDisplayNames[p] or p.DisplayName
				if txt:find(p.Name, 1, true) then
					txt = txt:gsub(p.Name, "Starship")
					changed = true
				end
				if origName ~= p.Name and txt:find(origName, 1, true) then
					txt = txt:gsub(origName, "Starship")
					changed = true
				end
			end
			if changed and obj.Text ~= txt then
				if not _G._originalGuiTexts[obj] then
					_G._originalGuiTexts[obj] = obj.Text
				end
				obj.Text = txt
			end
		end
		check()
		table.insert(StreamerConnections, obj:GetPropertyChangedSignal("Text"):Connect(check))
	end
end
local function scanGui(gui)
	for _, desc in pairs(gui:GetDescendants()) do
		spoofText(desc)
	end
	table.insert(StreamerConnections, gui.DescendantAdded:Connect(spoofText))
end
if lp.PlayerGui then
	for _, gui in pairs(lp.PlayerGui:GetChildren()) do
		scanGui(gui)
	end
	table.insert(StreamerConnections, lp.PlayerGui.ChildAdded:Connect(scanGui))
end
Library:Notify("Hide Username: Enabled (all players)", 2)
else
	DisconnectStreamer()
	for player, origName in pairs(_G._originalDisplayNames) do
		pcall(function()
		if player and player.Parent and player.Character then
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.DisplayName = origName end
		end
	end)
end
_G._originalDisplayNames = {}
for obj, origText in pairs(_G._originalGuiTexts) do
	pcall(function()
	if obj and obj.Parent then
		obj.Text = origText
	end
end)
end
_G._originalGuiTexts = {}
Library:Notify("Hide Username: Disabled", 2)
end
end
})
_G.HideAvatarIconEnabled = false
_G._originalAvatarImages = _G._originalAvatarImages or {}
local _hideAvatarConns = {}
local REPLACEMENT_ICON = "rbxassetid://90192840093542"
local function IsAvatarHeadshot(img)
	if not img or type(img) ~= "string" then return false end
	return img:find("rbxthumb://type=AvatarHeadShot") ~= nil
end
local function SpoofAvatarIcon(obj)
	if not obj or not obj:IsA("ImageLabel") and not obj:IsA("ImageButton") then return end
	pcall(function()
	local img = obj.Image
	if IsAvatarHeadshot(img) then
		if not _G._originalAvatarImages[obj] then
			_G._originalAvatarImages[obj] = img
		end
		obj.Image = REPLACEMENT_ICON
	end
end)
end
local function RestoreAvatarIcon(obj)
	pcall(function()
	if _G._originalAvatarImages[obj] then
		obj.Image = _G._originalAvatarImages[obj]
		_G._originalAvatarImages[obj] = nil
	end
end)
end
local function ScanAndSpoofAllAvatars()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end
	for _, desc in ipairs(playerGui:GetDescendants()) do
		if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
			SpoofAvatarIcon(desc)
		end
	end
end
local function WatchAvatarChanges(obj)
	if not obj:IsA("ImageLabel") and not obj:IsA("ImageButton") then return end
	local conn = obj:GetPropertyChangedSignal("Image"):Connect(function()
	if not _G.HideAvatarIconEnabled then return end
	task.defer(function()
	SpoofAvatarIcon(obj)
end)
end)
table.insert(_hideAvatarConns, conn)
SpoofAvatarIcon(obj)
end
StreamerBox:AddToggle('HideAvatarIcon', {
Text = 'Hide Avatar Icon',
Default = false,
Tooltip = 'Replace all player avatar headshots with a custom icon',
Callback = function(Value)
_G.HideAvatarIconEnabled = Value
if Value then
	for _, conn in ipairs(_hideAvatarConns) do
		pcall(function() conn:Disconnect() end)
	end
	_hideAvatarConns = {}
	ScanAndSpoofAllAvatars()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		for _, desc in ipairs(playerGui:GetDescendants()) do
			if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
				WatchAvatarChanges(desc)
			end
		end
		local descConn = playerGui.DescendantAdded:Connect(function(desc)
		if not _G.HideAvatarIconEnabled then return end
		task.defer(function()
		if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
			WatchAvatarChanges(desc)
		end
	end)
end)
table.insert(_hideAvatarConns, descConn)
end
Library:Notify("Hide Avatar Icon: Enabled", 2)
else
	for _, conn in ipairs(_hideAvatarConns) do
		pcall(function() conn:Disconnect() end)
	end
	_hideAvatarConns = {}
	for obj, origImg in pairs(_G._originalAvatarImages) do
		pcall(function()
		if obj and obj.Parent then
			obj.Image = origImg
		end
	end)
end
_G._originalAvatarImages = {}
Library:Notify("Hide Avatar Icon: Disabled", 2)
end
end
})
end
_G.HookSpamEnabled = false
_G.HookSpamAmount = 10
_G.SilentHookEnabled = false
_G.ForceDestroyPalletsEnabled = false
_G.DoubleTapEnabled = false
_G.HookSpamConnection = nil
_G.HookEventConnection = nil
_G.DoubleTapConnection = nil
_G.OriginalNamecall = nil
_G.HookSpamInstalled = false
_G.LastHookSpamTime = 0
_G.LastHookedSurvivor = nil
_G.HookSpamSpeedLockActive = false
_G.HookSpamSpeedLockConnection = nil
_G.HookSpamLockedSpeed = 18
_G.HookSpamPermanentLock = false
_G.ExecuteHookSpam = function(targetSurvivor)
if not _G.HookSpamEnabled then return end
local now = tick()
if (now - _G.LastHookSpamTime) < 1.0 then return end
_G.LastHookSpamTime = now
local spamCount = _G.HookSpamAmount or 10
local silentMode = _G.SilentHookEnabled
local player = game.Players.LocalPlayer
if not player or not player.Character then return end
local hum = player.Character:FindFirstChildOfClass("Humanoid")
if not hum then return end
pcall(function()
Library:Notify("Hook spam executed " .. spamCount .. " times", 1)
end)
for i = 1, spamCount do
	task.spawn(function()
	pcall(function()
	if _G.VD_HookEvent then
		_G.VD_HookEvent:FireServer(targetSurvivor)
	end
	if _G.VD_HookPhase then
		_G.VD_HookPhase:FireServer(targetSurvivor)
	end
	if not silentMode then
		if _G.VD_ProgressUpdate then
			_G.VD_ProgressUpdate:FireServer(100)
		end
	end
end)
end)
end
task.delay(0.5, function()
pcall(function()
Library:Notify("Succesfully hooked", 2)
end)
end)
end
_G.HandleHookSpam = function(Value)
_G.HookSpamEnabled = Value
if Value then
	if _G.HookSpamConnection then
		_G.HookSpamConnection:Disconnect()
		_G.HookSpamConnection = nil
	end
	local player = game.Players.LocalPlayer
	if player and player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			local currentSpeed = hum.WalkSpeed
			if currentSpeed > 20 then
				_G.HookSpamLockedSpeed = 18
			else
				_G.HookSpamLockedSpeed = currentSpeed
			end
		end
	end
	if _G.HookSpamSpeedLockConnection then
		pcall(function()
		_G.HookSpamSpeedLockConnection:Disconnect()
	end)
	_G.HookSpamSpeedLockConnection = nil
end
_G.HookSpamPermanentLock = true
_G.HookSpamSpeedLockConnection = game:GetService("RunService").RenderStepped:Connect(function()
if not _G.HookSpamPermanentLock then return end
if not _G.HookSpamEnabled then return end
pcall(function()
local p = game.Players.LocalPlayer
if p and p.Character then
	local h = p.Character:FindFirstChildOfClass("Humanoid")
	if h then
		h.WalkSpeed = _G.HookSpamLockedSpeed
	end
end
end)
end)
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local carryFolder = remotes and remotes:FindFirstChild("Carry")
local progressFolder = remotes and remotes:FindFirstChild("Progress")
if not carryFolder then
	Library:Notify("Carry folder not found!", 3)
	return
end
_G.VD_HookEvent = carryFolder:FindFirstChild("HookEvent")
_G.VD_UnhookEvent = carryFolder:FindFirstChild("UnHookEvent")
_G.VD_HookPhase = carryFolder:FindFirstChild("HookPhase")
_G.VD_CarryAnim = carryFolder:FindFirstChild("CarryAnim")
_G.VD_GetCarriedAnim = carryFolder:FindFirstChild("GetCarriedAnim")
_G.VD_PlayAnimation = carryFolder:FindFirstChild("PlayAnimation")
_G.VD_ProgressUpdate = progressFolder and progressFolder:FindFirstChild("ProgressUpdateEvent")
_G.VD_AnimHandler = remotes:FindFirstChild("AnimationHandler")
if not _G.HookSpamInstalled then
	local hookSuccess = pcall(function()
	local mt = getrawmetatable(game)
	if mt and getnamecallmethod then
		local oldNamecall = mt.__namecall
		_G.OriginalNamecall = oldNamecall
		setreadonly(mt, false)
		mt.__namecall = newcclosure(function(self, ...)
		local method = getnamecallmethod()
		local args = { ... }
		if _G.HookSpamEnabled and method == "FireServer" then
			if self and self.Name and self.Name == "HookEvent" then
				local targetSurvivor = args[1]
				task.spawn(function()
				_G.ExecuteHookSpam(targetSurvivor)
			end)
		end
	end
	return oldNamecall(self, ...)
end)
setreadonly(mt, true)
_G.HookSpamInstalled = true
end
end)
end
_G.LastHookedSurvivor = nil
local trackedSurvivors = {}
_G.HookSpamConnection = game:GetService("RunService").Heartbeat:Connect(function()
if not _G.HookSpamEnabled then return end
local player = game.Players.LocalPlayer
if not player then return end
local myTeam = player.Team
if not myTeam or myTeam.Name ~= "Killers" then return end
for _, p in pairs(game.Players:GetPlayers()) do
	if p ~= player then
		local isKiller = p.Team and p.Team.Name == "Killers"
		if not isKiller and p.Character then
			local status = p.Character:FindFirstChild("Status")
			if status then
				local action = status:FindFirstChild("Action")
				if action then
					local actionVal = tostring(action.Value)
					local wasHooked = trackedSurvivors[p.Name]
					local isHooked = actionVal == "Hooked"
					if isHooked and not wasHooked then
						trackedSurvivors[p.Name] = true
						task.spawn(function()
						_G.ExecuteHookSpam(p)
					end)
				elseif not isHooked and wasHooked then
					trackedSurvivors[p.Name] = false
				end
			end
		end
	end
end
end
end)
Library:Notify("Hook Spam: Enabled", 3)
else
	if _G.HookSpamConnection then
		_G.HookSpamConnection:Disconnect()
		_G.HookSpamConnection = nil
	end
	_G.HookSpamPermanentLock = false
	if _G.HookSpamSpeedLockConnection then
		pcall(function()
		_G.HookSpamSpeedLockConnection:Disconnect()
	end)
	_G.HookSpamSpeedLockConnection = nil
end
_G.LastHookSpamTime = 0
_G.LastHookedSurvivor = nil
Library:Notify("Hook Spam: Disabled", 2)
end
end
_G.HandleHookAmount = function(Value)
_G.HookSpamAmount = Value
end
_G.HandleSilentHook = function(Value)
_G.SilentHookEnabled = Value
end
_G.KillAllSurvivorsEnabled = false
_G.KillAllSpamAmount = 100
_G.HandleKillAllSurvivors = function()
if DetectMyRole() ~= "Killer" then
	Library:Notify("You must be Killer to use this!", 3)
	return
end
local player = game.Players.LocalPlayer
if not player or not player.Character then return end
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
if not remotes then
	Library:Notify("Failed", 3)
	return
end
local carryFolder = remotes:FindFirstChild("Carry")
local progressFolder = remotes:FindFirstChild("Progress")
if not carryFolder then
	Library:Notify("Failed", 3)
	return
end
local hookEvent = carryFolder:FindFirstChild("HookEvent")
local hookPhase = carryFolder:FindFirstChild("HookPhase")
local carrySurvivorEvent = carryFolder:FindFirstChild("CarrySurvivorEvent")
local progressUpdate = progressFolder and progressFolder:FindFirstChild("ProgressUpdateEvent")
if not hookEvent then
	Library:Notify("Failed", 3)
	return
end
local survivors = {}
for _, p in pairs(game.Players:GetPlayers()) do
	if p ~= player then
		local isKiller = false
		if p.Team and p.Team.Name then
			isKiller = p.Team.Name:lower():find("killer") ~= nil
		end
		if not isKiller and p.Character then
			table.insert(survivors, p)
		end
	end
end
if #survivors == 0 then
	Library:Notify("No survivors found!", 2)
	return
end
local spamCount = _G.KillAllSpamAmount or 100
local totalSpams = #survivors * spamCount
Library:Notify("Force kill carried players", 2)
for _, targetSurvivor in ipairs(survivors) do
	local targetChar = targetSurvivor.Character
	task.spawn(function()
	for i = 1, spamCount do
		pcall(function()
		if carrySurvivorEvent then
			carrySurvivorEvent:FireServer(targetSurvivor)
			carrySurvivorEvent:FireServer(targetChar)
		end
		if hookEvent then
			hookEvent:FireServer(targetSurvivor)
			hookEvent:FireServer(targetChar)
		end
		if hookPhase then
			hookPhase:FireServer(targetSurvivor)
			hookPhase:FireServer(targetSurvivor, 2)
			hookPhase:FireServer(targetSurvivor, 3)
		end
		if progressUpdate then
			progressUpdate:FireServer(100)
		end
	end)
	if i % 50 == 0 then
		task.wait(0.01)
	end
end
end)
end
task.delay(1, function()
Library:Notify("Force kill carried players complete!", 3)
end)
end
_G.HandleKillAllAmount = function(Value)
_G.KillAllSpamAmount = Value
end
_G.HandleDestroyPallets = function(Value)
_G.ForceDestroyPalletsEnabled = Value
if Value then
	local destroyedCount = 0
	local RS = game:GetService("ReplicatedStorage")
	local palletRemotes = {}
	pcall(function()
	local remotes = RS:FindFirstChild("Remotes")
	if remotes then
		local palletFolder = remotes:FindFirstChild("Pallet")
		if palletFolder then
			for _, folder in pairs(palletFolder:GetChildren()) do
				if folder:IsA("Folder") then
					local destroy = folder:FindFirstChild("Destroy")
					local destroyGlobal = folder:FindFirstChild("Destroy-Global")
					if destroy then table.insert(palletRemotes, { remote = destroy, type = "single" }) end
					if destroyGlobal then table.insert(palletRemotes, { remote = destroyGlobal, type = "global" }) end
				end
			end
			local directDestroy = palletFolder:FindFirstChild("Destroy")
			local directGlobal = palletFolder:FindFirstChild("Destroy-Global")
			if directDestroy then table.insert(palletRemotes, { remote = directDestroy, type = "single" }) end
			if directGlobal then table.insert(palletRemotes, { remote = directGlobal, type = "global" }) end
		end
	end
end)
for _, data in pairs(palletRemotes) do
	if data.type == "global" then
		pcall(function()
		data.remote:FireServer()
	end)
end
end
task.wait(0.1)
local palletObjects = {}
for _, obj in pairs(game.Workspace:GetDescendants()) do
	local name = obj.Name:lower()
	if name:find("pallet") or name:find("plank") or name:find("board") then
		if obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("MeshPart") then
			table.insert(palletObjects, obj)
		end
	end
end
for _, data in pairs(palletRemotes) do
	if data.type == "single" then
		for _, pallet in pairs(palletObjects) do
			pcall(function()
			data.remote:FireServer(pallet)
			destroyedCount = destroyedCount + 1
		end)
	end
end
end
for _, pallet in pairs(palletObjects) do
	pcall(function()
	if pallet:IsA("Model") then
		pallet:BreakJoints()
		for _, part in pairs(pallet:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Anchored = false
				part.Transparency = 1
			end
		end
		local primaryPart = pallet.PrimaryPart or pallet:FindFirstChildOfClass("BasePart")
		if primaryPart then
			primaryPart.CFrame = CFrame.new(0, -500, 0)
		end
	elseif pallet:IsA("BasePart") then
		pallet.CanCollide = false
		pallet.Anchored = false
		pallet.Transparency = 1
		pallet.CFrame = CFrame.new(0, -500, 0)
	end
	pallet:Destroy()
	destroyedCount = destroyedCount + 1
end)
end
pcall(function()
for _, obj in pairs(game.Workspace:GetDescendants()) do
	if obj:IsA("ProximityPrompt") and obj.Name:lower():find("pallet") then
		obj.Enabled = false
		obj:Destroy()
	end
end
end)
Library:Notify("Destroyed " .. destroyedCount .. " pallets!", 2)
_G.ForceDestroyPalletsEnabled = false
if Options.ForceDestroyPallets then
	Options.ForceDestroyPallets:SetValue(false)
end
end
end
_G.HandleDoubleTap = function(Value)
_G.DoubleTapEnabled = Value
if Value then
	if _G.DoubleTapConnection then
		_G.DoubleTapConnection:Disconnect()
	end
	_G.VD_LastAttackTime = 0
	_G.DoubleTapConnection = game:GetService("RunService").Heartbeat:Connect(function()
	if not _G.DoubleTapEnabled then return end
	_G.VD_DTPlayer = game.Players.LocalPlayer
	if not _G.VD_DTPlayer or not _G.VD_DTPlayer.Character then return end
	_G.VD_DTHumanoid = _G.VD_DTPlayer.Character:FindFirstChildOfClass("Humanoid")
	if _G.VD_DTHumanoid then
		_G.VD_Animator = _G.VD_DTHumanoid:FindFirstChildOfClass("Animator")
		if _G.VD_Animator then
			for _, track in pairs(_G.VD_Animator:GetPlayingAnimationTracks()) do
				if (track.Name:lower():find("attack") or track.Name:lower():find("swing")) and (tick() - _G.VD_LastAttackTime) > 0.5 then
					_G.VD_AttackRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
					if _G.VD_AttackRemote then
						_G.VD_AttackRemote = _G.VD_AttackRemote:FindFirstChild("Attacks")
						if _G.VD_AttackRemote then
							_G.VD_BasicAttack = _G.VD_AttackRemote:FindFirstChild("BasicAttack")
							_G.VD_HitAttack = _G.VD_AttackRemote:FindFirstChild("hit")
							if _G.VD_BasicAttack then
								_G.VD_BasicAttack:FireServer()
								_G.VD_BasicAttack:FireServer()
							end
							if _G.VD_HitAttack then
								_G.VD_HitAttack:FireServer()
								_G.VD_HitAttack:FireServer()
							end
							_G.VD_LastAttackTime = tick()
							break
						end
					end
				end
			end
		end
	end
end)
Library:Notify("Double Tap: Enabled (2x Attack)", 2)
else
	if _G.DoubleTapConnection then
		_G.DoubleTapConnection:Disconnect()
		_G.DoubleTapConnection = nil
	end
	Library:Notify("Double Tap: Disabled", 2)
end
end
Init.KillerScriptBox = function()
local function SetupNoPalletStun()
	if GFS.NoPalletStunSetup then return end
	GFS.NoPalletStunSetup = true
	task.spawn(function()
	local RS = game:GetService("ReplicatedStorage")
	local remotes = RS:FindFirstChild("RemoteEvents")
	if not remotes then remotes = RS:FindFirstChild("Remotes") end
	if not remotes then return end
	local palletFolder = remotes:FindFirstChild("Pallet")
	local jasonFolder = palletFolder and palletFolder:FindFirstChild("Jason")
	if jasonFolder then
		local stunOver = jasonFolder:FindFirstChild("Stunover")
		local stunAbility = jasonFolder:FindFirstChild("StunAbility")
		if stunOver and stunOver:IsA("RemoteEvent") then
			if stunAbility and stunAbility:IsA("RemoteEvent") then
				stunAbility.OnClientEvent:Connect(function()
				if GFS.NoPalletStunEnabled then
					stunOver:FireServer()
					Library:Notify("No Pallet Stun: Stun Cancelled!", 1)
				end
			end)
		end
		task.spawn(function()
		while true do
			if GFS.NoPalletStunEnabled and LocalPlayer.Character then
				local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
				if hum and hum.WalkSpeed == 0 then
					stunOver:FireServer()
				end
			end
			task.wait(0.5)
		end
	end)
end
end
end)
end
local KillerAbilityBox = Tabs.Killer:AddLeftGroupbox('Ability', 'swords')
local KillerAgilityBox = Tabs.Killer:AddLeftGroupbox('Agility', 'rabbit')
local KillerUtilityBox = Tabs.Killer:AddLeftGroupbox('Utility', 'tool-case')
local KillerAimbotBox = Tabs.Killer:AddRightGroupbox('Aimbot (Veil)', 'crosshair')
KillerAimbotBox:AddToggle('SpearAimbotToggle', {
Text = 'Spear Silent Aim',
Default = false,
Tooltip =
'Silent aim for Veil Spearthrow - auto-aims at nearest survivor',
Callback = function(Value)
GFS.SpearAimbotEnabled = Value
if Value then
	local myRole = DetectMyRole()
	local isVeil = false
	pcall(function()
	local sel = LocalPlayer:GetAttribute("SelectedKiller") or ""
	if sel:lower():find("veil") then
		isVeil = true
	end
	if not isVeil and LocalPlayer.Character then
		local char = LocalPlayer.Character
		if char:GetAttribute("spearmode") ~= nil or char:GetAttribute("Spears") ~= nil
		or char:GetAttribute("BloodBetweenWorlds") ~= nil then
			isVeil = true
		end
	end
	if not isVeil and LocalPlayer.Character then
		local charName = LocalPlayer.Character.Name:lower()
		if charName:find("veil") then isVeil = true end
	end
	if not isVeil and LocalPlayer.Team then
		local teamName = LocalPlayer.Team.Name:lower()
		if teamName:find("veil") then isVeil = true end
	end
end)
if myRole ~= "Killer" or not isVeil then
	Library:Notify('Veil Silent Aim: You must be Veil killer!', 3)
	GFS.SpearAimbotEnabled = false
	task.spawn(function()
	if Toggles.SpearAimbotToggle then Toggles.SpearAimbotToggle:SetValue(false) end
end)
return
end
task.spawn(function()
local waited = 0
while not GFS.InstallSilentAimHook and waited < 5 do
	task.wait(0.5)
	waited = waited + 0.5
end
if GFS.InstallSilentAimHook then
	local ok = GFS.InstallSilentAimHook("veil")
	if ok then
		Library:Notify('Veil Silent Aim: Enabled (hook installed)', 2)
	else
		Library:Notify('Veil Silent Aim: Enabled (hook pending)', 3)
	end
else
	Library:Notify('Veil Silent Aim: Enabled (hook unavailable)', 3)
end
end)
else
	Library:Notify('Veil Silent Aim: Disabled', 2)
end
end
}):AddKeyPicker('SpearAimbotKey', {
Default = 'None',
Text = 'Veil Silent Aim',
Mode = 'Toggle',
SyncToggleState = true
})
local SpearGravitySlider = KillerAimbotBox:AddSlider('SpearGravity', {
Text = 'Spear Gravity',
Default = 98,
Min = 0,
Max = 500,
Rounding = 1,
Suffix = '',
Tooltip = IsPremium and 'Gravity compensation for trajectory prediction.\nDefault 98 matches game gravity (196.2/2).\nHigher = more upward compensation.',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.SpearGravity = Value
end
})
local SpearSpeedSlider = KillerAimbotBox:AddSlider('SpearSpeed', {
Text = 'Spear Speed',
Default = 100,
Min = 1,
Max = 500,
Rounding = 1,
Suffix = '',
Tooltip = IsPremium and 'Projectile speed for trajectory prediction.\nAuto-calibrates from actual throws.\nAdjust if spear consistently over/undershoots.',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.SpearSpeed = Value
GFS._lastSpearSpeed = nil
end
})
PremiumOnly(SpearGravitySlider)
PremiumOnly(SpearSpeedSlider)
KillerAimbotBox:AddCheckbox('SpearSnapline', {
Text = 'Snapline',
Default = true,
Tooltip = 'Show aim line from crosshair to target',
Callback = function(Value)
GFS.SpearSnaplineEnabled = Value
if not Value and GFS._veilSnapLine then
	GFS._veilSnapLine.Visible = false
end
end
})
KillerAimbotBox:AddCheckbox('SpearThruWall', {
Text = 'Through the Veil',
Default = false,
Tooltip =
'Allows aiming at survivors behind walls (no LOS check).\nDoes NOT force skill activation — you must activate Through the Veil skill yourself.',
Callback = function(Value)
GFS.SpearThruWallEnabled = Value
Library:Notify(Value and 'Through the Veil: ON (aim thru walls)' or 'Through the Veil: OFF', 2)
end
})
KillerAgilityBox:AddCheckbox('NoSlowdown', {
Text = 'No Slowdown',
Default = false,
Tooltip = 'Remove killer movement slowdown effects',
Callback = function(Value)
GFS.NoSlowdownEnabled = Value
if Value then
	task.spawn(function()
	while Toggles.NoSlowdown and Toggles.NoSlowdown.Value do
		pcall(function()
		if LocalPlayer.Character then
			local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
			if hum and hum.WalkSpeed < 16 then
				hum.WalkSpeed = 16
			end
		end
	end)
	task.wait(0.1)
end
end)
end
Library:Notify(Value and 'No Slowdown: Enabled' or 'No Slowdown: Disabled', 2)
end
})
KillerAgilityBox:AddCheckbox('DoubleTap', {
Text = 'Double Tap',
Default = false,
Tooltip = 'Fast attack speed (reduced cooldown)',
Callback = _G.HandleDoubleTap
})
local HookSpamToggle = KillerAbilityBox:AddCheckbox('HookSpam', {
Text = 'Hook Spam',
Default = false,
Tooltip = IsPremium and 'Spam hook countlessly to instantly hook survivors' or
'PREMIUM ONLY - This feature requires a Premium key',
DisabledTooltip = 'Unlock this with premium',
Callback = _G.HandleHookSpam
})
PremiumOnly(HookSpamToggle)
local HookAmountSlider = KillerAbilityBox:AddSlider('HookAmount', {
Text = 'Hook Amount',
Default = 67,
Min = 1,
Max = 1000,
Rounding = 0,
Compact = true,
Tooltip = IsPremium and nil or 'PREMIUM ONLY - This feature requires a Premium key',
DisabledTooltip = 'Unlock this with premium',
Callback = _G.HandleHookAmount
})
PremiumOnly(HookAmountSlider)
local SilentHookToggle = KillerAbilityBox:AddCheckbox('SilentHook', {
Text = 'Silent Hook',
Default = false,
Tooltip = 'Hook without animation (faster but less visible)',
DisabledTooltip = 'Unlock this with premium',
Callback = _G.HandleSilentHook
})
PremiumOnly(SilentHookToggle)
KillerAbilityBox:AddCheckbox('AutoBreak', {
Text = 'Auto Break Pallet/Gen',
Default = false,
Tooltip = 'Automatically breaks nearby pallets and generators',
Callback = function(Value)
GFS.AutoBreakEnabled = Value
if Value then
	task.spawn(GFS.AutoBreakLoopFn)
end
Library:Notify(Value and 'Auto Break: Enabled' or 'Auto Break: Disabled', 2)
end
})
local ForceKillToggle = KillerAbilityBox:AddCheckbox('ForceKillCarried', {
Text = 'Force Kill Carried',
Default = false,
Tooltip = 'When carrying a survivor, instant kill',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
_G.ForceKillCarriedEnabled = Value
if Value then
	Library:Notify("Force Kill Carried: Enabled", 3)
	if _G.ForceKillCarriedConn then
		pcall(function() _G.ForceKillCarriedConn:Disconnect() end)
	end
	_G.ForceKillCarriedKilledPlayers = {}
	_G.ForceKillCarriedConn = RunService.Heartbeat:Connect(function()
	if not _G.ForceKillCarriedEnabled then return end
	if DetectMyRole() ~= "Killer" then return end
	if _G.HookSpamEnabled and _G.LastHookedSurvivor then return end
	local myChar = LocalPlayer.Character
	if not myChar then return end
	local isCarrying = myChar:GetAttribute("Carrying") or myChar:GetAttribute("IsCarrying") or
	myChar:GetAttribute("HoldingSurvivor")
	local carriedSurvivor = nil
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local pChar = player.Character
			local carried = pChar:GetAttribute("Carried") or pChar:GetAttribute("IsCarried") or
			pChar:GetAttribute("BeingCarried")
			if carried then
				if not (_G.HookSpamEnabled and _G.LastHookedSurvivor == player) then
					carriedSurvivor = player
					break
				end
			end
		end
	end
	if not carriedSurvivor and isCarrying then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and not IsKiller(player) and player.Character then
				local pHrp = player.Character:FindFirstChild("HumanoidRootPart")
				if pHrp then
					local myHrp = myChar:FindFirstChild("HumanoidRootPart")
					if myHrp and (pHrp.Position - myHrp.Position).Magnitude < 5 then
						carriedSurvivor = player
						break
					end
				end
			end
		end
	end
	if carriedSurvivor and carriedSurvivor.Character then
		if _G.ForceKillCarriedKilledPlayers[carriedSurvivor.UserId] then
			return
		end
		_G.ForceKillCarriedKilledPlayers[carriedSurvivor.UserId] = true
		local spamCount = _G.HookSpamAmount or 100
		Library:Notify("💀 Force killing " .. carriedSurvivor.Name .. "!", 2)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local carryFolder = remotes and remotes:FindFirstChild("Carry")
		local progressFolder = remotes and remotes:FindFirstChild("Progress")
		local hookEvent = carryFolder and carryFolder:FindFirstChild("HookEvent")
		local hookPhase = carryFolder and carryFolder:FindFirstChild("HookPhase")
		local carrySurvivorEvent = carryFolder and carryFolder:FindFirstChild("CarrySurvivorEvent")
		local progressUpdate = progressFolder and progressFolder:FindFirstChild("ProgressUpdateEvent")
		if not hookEvent then return end
		local targetChar = carriedSurvivor.Character
		task.spawn(function()
		for i = 1, spamCount do
			pcall(function()
			if carrySurvivorEvent then
				carrySurvivorEvent:FireServer(carriedSurvivor)
				carrySurvivorEvent:FireServer(targetChar)
			end
			if hookEvent then
				hookEvent:FireServer(carriedSurvivor)
				hookEvent:FireServer(targetChar)
			end
			if hookPhase then
				hookPhase:FireServer(carriedSurvivor)
				hookPhase:FireServer(carriedSurvivor, 2)
				hookPhase:FireServer(carriedSurvivor, 3)
			end
			if progressUpdate then
				progressUpdate:FireServer(carriedSurvivor, "sacrifice", 100)
			end
		end)
	end
end)
end
end)
else
	if _G.ForceKillCarriedConn then
		pcall(function() _G.ForceKillCarriedConn:Disconnect() end)
		_G.ForceKillCarriedConn = nil
	end
	_G.ForceKillCarriedKilledPlayers = {}
	Library:Notify("Force Kill Carried: Disabled", 2)
end
end
})
PremiumOnly(ForceKillToggle)
KillerUtilityBox:AddCheckbox('NoPalletStun', {
Text = 'No Pallet Stun',
Default = false,
Tooltip = 'Prevent pallet stuns ',
Callback = function(Value)
GFS.NoPalletStunEnabled = Value
if Value then
	SetupNoPalletStun()
end
Library:Notify(Value and 'No Pallet Stun: Enabled' or 'No Pallet Stun: Disabled', 2)
end
})
KillerUtilityBox:AddCheckbox('AntiBlind', {
Text = 'Anti Blind',
Default = false,
Tooltip = 'Prevent flashlight blinds',
Callback = function(Value)
GFS.AntiBlindEnabled = Value
if Value then
	GFS.SetupAntiBlindFn()
end
Library:Notify(Value and 'Anti Blind: Enabled' or 'Anti Blind: Disabled', 2)
end
})
KillerUtilityBox:AddCheckbox('InfiniteLunge', {
Text = 'Infinite Lunge',
Default = false,
Tooltip = 'Hold lunge indefinitely (Killer Only)',
Callback = function(Value)
GFS.InfiniteLungeEnabled = Value
if Value then
	task.spawn(function()
	while GFS.InfiniteLungeEnabled do
		local char = LocalPlayer.Character
		if char then
			char:SetAttribute("lungeboost", 999)
		end
		task.wait(1)
	end
end)
else
	local char = LocalPlayer.Character
	if char then
		char:SetAttribute("lungeboost", nil)
	end
end
end
})
KillerUtilityBox:AddCheckbox('FullGenBreak', {
Text = 'Full Generator Break',
Default = false,
Tooltip = 'Resets generator progress to 0% when kicking',
Callback = function(Value)
GFS.FullGenBreakEnabled = Value
if Value then
	if not GFS.FullGenBreakHooked then
		GFS.FullGenBreakHooked = true
		local mt = getrawmetatable(game)
		local oldNamecall = mt.__namecall
		setreadonly(mt, false)
		mt.__namecall = newcclosure(function(self, ...)
		local method = getnamecallmethod()
		local args = { ... }
		if method == "FireServer" or method == "InvokeServer" then
			local success, name = pcall(function() return self.Name end)
			if success and (name == "BreakGenEvent" or (name == "Interact" and args[2] == "Damage")) then
				if GFS.FullGenBreakEnabled and not GFS.IsSpammingGen then
					task.spawn(function()
					GFS.IsSpammingGen = true
					local status, err = pcall(function()
					local remotes = game:GetService("ReplicatedStorage"):FindFirstChild(
					"Remotes")
					local breakGen = nil
					if remotes and remotes:FindFirstChild("Generator") then
						breakGen = remotes.Generator:FindFirstChild("BreakGenEvent")
					end
					local spamCount = 10
					local spamDelay = 0.1
					if breakGen and breakGen:IsA("RemoteEvent") then
						for i = 1, spamCount do
							if not GFS.FullGenBreakEnabled then break end
							breakGen:FireServer(table.unpack(args))
							task.wait(spamDelay)
						end
						pcall(function() Library:Notify("Full Break: Generator Reset!", 2) end)
					elseif name == "BreakGenEvent" then
						for i = 1, spamCount do
							if not GFS.FullGenBreakEnabled then break end
							if method == "InvokeServer" then
								self:InvokeServer(table.unpack(args))
							else
								self:FireServer(table.unpack(args))
							end
							task.wait(spamDelay)
						end
						pcall(function() Library:Notify("Full Break: Spamming Event...", 2) end)
					else
						for i = 1, spamCount do
							if not GFS.FullGenBreakEnabled then break end
							if method == "InvokeServer" then
								self:InvokeServer(table.unpack(args))
							else
								self:FireServer(table.unpack(args))
							end
							task.wait(spamDelay)
						end
						pcall(function() Library:Notify("Full Break: Spamming Damage...", 2) end)
					end
				end)
				if not status then
					warn("[FullGenBreak] Error: " .. tostring(err))
				end
				GFS.IsSpammingGen = false
			end)
		end
	end
end
return oldNamecall(self, ...)
end)
setreadonly(mt, true)
end
end
end
})
KillerUtilityBox:AddButton({
Text = 'Destroy All Pallets',
Tooltip = 'Force destroy all pallets on map',
Func = function()
_G.HandleDestroyPallets(true)
end
})
local ForceKillCarriedBtn = KillerUtilityBox:AddButton({
Text = 'Force Kill Carried Survivors',
Tooltip = 'Force kill all carried survivors (you must be Killer)',
DisabledTooltip = 'Unlock this with premium',
Func = _G.HandleKillAllSurvivors
})
PremiumOnly(ForceKillCarriedBtn)
GFS.ThirdPersonKillerEnabled = false
GFS.ThirdPersonKillerConn = nil
GFS.ThirdPersonOriginalMinZoom = nil
GFS.ThirdPersonOriginalMaxZoom = nil
GFS.ThirdPersonOriginalCameraMode = nil
GFS.ThirdPersonLastRoleCheck = 0
GFS.ThirdPersonCachedRole = nil
local function RestoreKillerCamera()
	if GFS.ThirdPersonKillerConn then
		GFS.ThirdPersonKillerConn:Disconnect()
		GFS.ThirdPersonKillerConn = nil
	end
	pcall(function()
	LocalPlayer.CameraMinZoomDistance = GFS.ThirdPersonOriginalMinZoom or 0.5
	LocalPlayer.CameraMaxZoomDistance = GFS.ThirdPersonOriginalMaxZoom or 0.5
	LocalPlayer.CameraMode = GFS.ThirdPersonOriginalCameraMode or Enum.CameraMode.LockFirstPerson
end)
end
local function ApplyThirdPersonKiller()
	if not GFS.ThirdPersonKillerEnabled then return end
	local currentRole = DetectMyRole()
	GFS.ThirdPersonCachedRole = currentRole
	GFS.ThirdPersonLastRoleCheck = tick()
	if currentRole ~= "Killer" then
		RestoreKillerCamera()
		return
	end
	if not GFS.ThirdPersonOriginalMinZoom then
		GFS.ThirdPersonOriginalMinZoom = LocalPlayer.CameraMinZoomDistance
		GFS.ThirdPersonOriginalMaxZoom = LocalPlayer.CameraMaxZoomDistance
		GFS.ThirdPersonOriginalCameraMode = LocalPlayer.CameraMode
	end
	LocalPlayer.CameraMinZoomDistance = 10
	LocalPlayer.CameraMaxZoomDistance = 20
	LocalPlayer.CameraMode = Enum.CameraMode.Classic
	pcall(function()
	local cam = workspace.CurrentCamera
	if cam then
		local char = LocalPlayer.Character
		local head = char and char:FindFirstChild("Head")
		if head then
			cam.CFrame = CFrame.new(head.Position - cam.CFrame.LookVector * 12, head.Position)
		end
	end
end)
if not GFS.ThirdPersonKillerConn then
	GFS.ThirdPersonKillerConn = RunService.RenderStepped:Connect(function()
	if not GFS.ThirdPersonKillerEnabled then
		RestoreKillerCamera()
		return
	end
	local now = tick()
	if now - GFS.ThirdPersonLastRoleCheck > 0.5 then
		GFS.ThirdPersonCachedRole = DetectMyRole()
		GFS.ThirdPersonLastRoleCheck = now
	end
	if GFS.ThirdPersonCachedRole ~= "Killer" then
		GFS.ThirdPersonKillerEnabled = false
		RestoreKillerCamera()
		GFS.ThirdPersonOriginalMinZoom = nil
		GFS.ThirdPersonOriginalMaxZoom = nil
		GFS.ThirdPersonOriginalCameraMode = nil
		pcall(function()
		GFS._ThirdPersonSettingLock = true
		if Toggles and Toggles.ThirdPersonKiller then
			Toggles.ThirdPersonKiller:SetValue(false)
		end
		GFS._ThirdPersonSettingLock = false
	end)
	Library:Notify('Third Person: Auto-disabled (no longer Killer)', 2)
	return
end
if LocalPlayer.CameraMinZoomDistance < 10 then
	LocalPlayer.CameraMinZoomDistance = 10
end
if GFS.InfiniteZoomEnabled then
	if LocalPlayer.CameraMaxZoomDistance < 100000 then
		LocalPlayer.CameraMaxZoomDistance = 100000
	end
else
	if LocalPlayer.CameraMaxZoomDistance < 20 then
		LocalPlayer.CameraMaxZoomDistance = 20
	end
end
if LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then
	LocalPlayer.CameraMode = Enum.CameraMode.Classic
end
end)
end
end
GFS._ThirdPersonSettingLock = false
KillerUtilityBox:AddToggle('ThirdPersonKiller', {
Text = 'Third Person',
Default = false,
Tooltip = 'Force third person camera (Killer role only). Free-look mouse, scroll to zoom.',
Callback = function(Value)
if GFS._ThirdPersonSettingLock then return end
if Value then
	local currentRole = DetectMyRole()
	if currentRole ~= "Killer" then
		GFS._ThirdPersonSettingLock = true
		GFS.ThirdPersonKillerEnabled = false
		pcall(function()
		if Toggles and Toggles.ThirdPersonKiller then
			Toggles.ThirdPersonKiller:SetValue(false)
		end
	end)
	GFS._ThirdPersonSettingLock = false
	Library:Notify('Third Person: Only works as Killer!', 3)
	return
end
GFS.ThirdPersonKillerEnabled = true
ApplyThirdPersonKiller()
Library:Notify('Third Person: Enabled (Killer only)', 3)
else
	GFS.ThirdPersonKillerEnabled = false
	RestoreKillerCamera()
	GFS.ThirdPersonOriginalMinZoom = nil
	GFS.ThirdPersonOriginalMaxZoom = nil
	GFS.ThirdPersonOriginalCameraMode = nil
	Library:Notify('Third Person: Disabled', 2)
end
end
}):AddKeyPicker('ThirdPersonKillerKey', {
Default = 'None',
SyncToggleState = true,
Mode = 'Toggle',
Text = 'Third Person',
NoUI = false,
})
do
	local ExploitsGroup = Tabs.Killer:AddRightGroupbox('Exploits', 'skull')
	local MaskList = { "Alex", "Brandon", "Cobra", "Rabbit", "Richter", "Tony" }
	ExploitsGroup:AddDropdown('MaskSelect', {
	Values = MaskList,
	Default = 'Alex',
	Multi = false,
	Text = 'Mask Select (Masked)',
	Tooltip = 'Select mask for Masked Killer',
	Callback = function(Value)
end
})
local ActivateMaskBtn = ExploitsGroup:AddButton({
Text = 'Activate Mask',
Tooltip = 'Use this to activate mask without cooldown',
DisabledTooltip = 'You must be Masked Killer (The Masked)',
Func = function()
local selected = Options.MaskSelect.Value
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
if remotes and remotes:FindFirstChild("Killers") and remotes.Killers:FindFirstChild("Masked") then
	remotes.Killers.Masked.Activatepower:FireServer(selected)
	Library:Notify("Activated Mask: " .. tostring(selected), 2)
end
end
})
local DeactivateMaskBtn = ExploitsGroup:AddButton({
Text = 'Deactivate Mask',
Tooltip = 'Use this to deactivate mask without cooldown',
DisabledTooltip = 'You must be Masked Killer (The Masked)',
Func = function()
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
if remotes and remotes:FindFirstChild("Killers") and remotes.Killers:FindFirstChild("Masked") then
	remotes.Killers.Masked.Deactivatepower:FireServer()
	Library:Notify("Deactivated Mask", 2)
end
end
})
task.spawn(function()
while true do
	pcall(function()
	local isMaskedKiller = false
	local role = DetectMyRole()
	if role == "Killer" and LocalPlayer.Character then
		local selectedKiller = LocalPlayer:GetAttribute("SelectedKiller")
		if selectedKiller == "The Masked" or selectedKiller == "Masked" then
			isMaskedKiller = true
		end
		if not isMaskedKiller then
			local kType = GetKillerType(LocalPlayer)
			if kType == "Masked" or kType == "The Masked" then
				isMaskedKiller = true
			end
		end
	end
	if ActivateMaskBtn.SetDisabled then
		ActivateMaskBtn:SetDisabled(not isMaskedKiller)
	end
	if DeactivateMaskBtn.SetDisabled then
		DeactivateMaskBtn:SetDisabled(not isMaskedKiller)
	end
	if isMaskedKiller then
		ActivateMaskBtn:SetTooltip("Equip selected mask (Masked Killer)")
		DeactivateMaskBtn:SetTooltip("Unequip mask (Masked Killer)")
	else
		ActivateMaskBtn:SetTooltip("You must be Masked Killer (The Masked)")
		DeactivateMaskBtn:SetTooltip("You must be Masked Killer (The Masked)")
	end
end)
task.wait(1)
end
end)
end
end
SafeInit(Init.KillerScriptBox, 'InitKillerScriptBox')
function InitKillAuraScope()
	local KillAuraBox = Tabs.Killer:AddRightGroupbox('Kill Aura', 'swords')
	local KA_Toggle = KillAuraBox:AddToggle('AutoAttack', {
	Text = 'Kill Aura',
	Default = false,
	Tooltip = 'Automatically attack survivors in range',
	Callback = function(Value)
	GFS.AutoAttackEnabled = Value
	GFS.MuteHitSoundEnabled = Value
	GFS.AutoAttackAnimationFix = Value
	if Value then
		if _G.KillAuraConnection then
			_G.KillAuraConnection:Disconnect()
		end
		_G.KillAuraConnection = game:GetService("RunService").Heartbeat:Connect(function()
		if GFS.AutoAttackEnabled then
			GFS.AutoAttackFn()
		end
	end)
else
	if _G.KillAuraConnection then
		_G.KillAuraConnection:Disconnect()
		_G.KillAuraConnection = nil
	end
end
Library:Notify(Value and 'Kill Aura: Enabled' or 'Kill Aura: Disabled', 2)
end
}):AddKeyPicker('KillAuraKey', {
Default = 'None',
Text = 'Kill Aura',
Mode = 'Toggle',
SyncToggleState = true
})
local KA_KeyPicker = Options.KillAuraKey
PremiumOnly(KA_Toggle, KA_KeyPicker)
local KA_Mode = KillAuraBox:AddDropdown('KillAuraMode', {
Values = { 'Legit', 'Teleport' },
Default = 'Legit',
Multi = false,
Text = 'Attack Mode',
Tooltip = 'Legit: Normal Range',
Callback = function(Value)
if Value == nil or Value == '' then return end
GFS.AutoAttackMode = Value
end
})
PremiumOnly(KA_Mode)
local KA_Range = KillAuraBox:AddSlider('AutoAttackRange', {
Text = 'Attack Range',
Default = 12,
Min = 5,
Max = 25,
Rounding = 0,
Suffix = ' studs',
Tooltip = IsPremium and nil or 'PREMIUM ONLY - This feature requires a Premium key',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.AutoAttackRange = Value
end
})
PremiumOnly(KA_Range)
local KA_Delay = KillAuraBox:AddSlider('KillAuraDelay', {
Text = 'Hit Delay (Speed)',
Default = 0.5,
Min = 0,
Max = 1.0,
Rounding = 2,
Suffix = 's',
Tooltip = IsPremium and '0 = No Delay (Brutal). 0.5 = Normal Speed' or
'PREMIUM ONLY - This feature requires a Premium key',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.AutoAttackDelay = Value
end
})
PremiumOnly(KA_Delay)
local KA_HitCount = KillAuraBox:AddSlider('KillAuraHitCount', {
Text = 'Spam Hit Count',
Default = 1,
Min = 1,
Max = 5,
Rounding = 0,
Tooltip = IsPremium and 'Hits per swing. Use High Count + 0.5s Delay for OP damage without stutter!' or
'PREMIUM ONLY - This feature requires a Premium key',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.AutoAttackHitCount = Value
end
})
PremiumOnly(KA_HitCount)
local KA_Instant = KillAuraBox:AddCheckbox('KillAuraInstant', {
Text = 'Instant Cooldown',
Default = false,
Tooltip = IsPremium and 'Ignore hit delay (rip server xd)' or
'PREMIUM ONLY - This feature requires a Premium key',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.AutoAttackInstant = Value
Library:Notify(Value and 'Instant Hit: Enabled (RIP Server)' or 'Instant Hit: Disabled', 2)
end
})
PremiumOnly(KA_Instant)
end
task.spawn(function()
task.wait(0.5)
SafeInit(InitKillAuraScope, 'InitKillAuraScope')
end)
function InitAutoGeneratorScope()
	local AutoGenBox = Tabs.Survivor:AddRightGroupbox('Auto Generator', 'pickaxe')
	GFS.AutoGenEnabled = false
	GFS.AutoGenConnection = nil
	GFS.AutoGenPoints = {}
	GFS.AutoGenRemotes = {}
	GFS.AutoGenLastFire = 0
	GFS.AutoGenFireRate = 0.15
	GFS.AutoGenLastScan = 0
	GFS.AutoGenMode = "Legit"
	GFS.AutoGenDebug = false
	GFS.AutoGenInstantEscape = false
	GFS.AutoGenTPKillerEnabled = false
	GFS.AutoGenKillerTolerance = 30
	GFS.AutoGenLastTP = 0
	GFS.AutoGenCurrentGenData = nil
	GFS.AutoGenCurrentGenModel = nil
	GFS.AutoGenLastGenSwitch = 0
	GFS.AutoGenPaused = false
	GFS.AutoGenTPLocked = false
	GFS.AutoGenEscapeTriggered = false
	GFS.AutoGenStopping = false
	GFS.AutoGenIsRepairing = false
	GFS.AutoGenCutsceneEnded = false
	GFS.AutoGenFirstActivation = false
	local function DebugLog(msg)
		if GFS.AutoGenDebug then
		end
	end
	local GUICheckCache = {
	lastCheck = 0,
	cooldown = 1.0,
	lastValue = nil
	}
	local function GetGensLeftFromGUI()
		local now = tick()
		if now - GUICheckCache.lastCheck < GUICheckCache.cooldown then
			return GUICheckCache.lastValue
		end
		GUICheckCache.lastCheck = now
		local gensLeft = nil
		local success = pcall(function()
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if not playerGui then return end
		local survivorGui = playerGui:FindFirstChild("Survivor")
		if survivorGui then
			local genFrame = survivorGui:FindFirstChild("Gen")
			if genFrame then
				local gencount = genFrame:FindFirstChild("Gencount")
				if gencount and gencount:IsA("TextLabel") then
					local num = tonumber(gencount.Text:match("^%s*(%d)%s*$"))
					if num and num >= 0 and num <= 7 then
						gensLeft = num
						DebugLog("GUI EXACT: Gencount = " .. num)
						return
					end
				end
			end
		end
		if not gensLeft then
			for _, gui in ipairs(playerGui:GetDescendants()) do
				if gui:IsA("TextLabel") and gui.Name == "Gencount" and gui.Visible then
					local num = tonumber(gui.Text:match("^%s*(%d)%s*$"))
					if num and num >= 0 and num <= 7 then
						gensLeft = num
						DebugLog("GUI FALLBACK: Gencount = " .. num)
						return
					end
				end
			end
		end
		if not gensLeft then
			for _, gui in ipairs(playerGui:GetDescendants()) do
				if gui:IsA("Frame") and gui.Name == "Gen" then
					for _, child in ipairs(gui:GetDescendants()) do
						if child:IsA("TextLabel") and child.Visible then
							local num = tonumber(child.Text:match("^%s*(%d)%s*$"))
							if num and num >= 0 and num <= 7 then
								gensLeft = num
								DebugLog("GUI FRAME: Gen child = " .. num)
								return
							end
						end
					end
				end
			end
		end
	end)
	if gensLeft ~= nil then
		DebugLog("GUI detected: " .. gensLeft .. " gens left")
	end
	GUICheckCache.lastValue = gensLeft
	return gensLeft
end
local function ScanGenerators()
	local points = {}
	pcall(function()
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, obj in ipairs(map:GetDescendants()) do
			if obj:IsA("Model") and obj.Name == "Generator" then
				for _, child in ipairs(obj:GetChildren()) do
					if child.Name:match("GeneratorPoint") then
						table.insert(points, { gen = obj, pt = child })
						break
					end
				end
			end
		end
	end
end)
GFS.AutoGenPoints = points
GFS.AutoGenLastScan = tick()
return #points
end
local function GetGenProgressRealTime(gen)
	if not gen or not gen.Parent then return 100 end
	local progress = 0
	pcall(function()
	local rp = gen:GetAttribute("RepairProgress")
	if rp and typeof(rp) == "number" then
		progress = rp
		return
	end
	for _, child in ipairs(gen:GetChildren()) do
		if child:IsA("NumberValue") or child:IsA("IntValue") then
			local nameLower = child.Name:lower()
			if nameLower:find("progress") or nameLower:find("repair") or nameLower:find("charge") then
				local val = child.Value
				if val >= 0 and val <= 1 then
					progress = val * 100
				else
					progress = val
				end
				return
			end
		end
	end
	progress = GetGeneratorProgress(gen) or 0
end)
return progress
end
local function CountCompletedRealTime()
	local completed = 0
	local total = 0
	local incomplete = 0
	for _, data in ipairs(GFS.AutoGenPoints) do
		if data.gen and data.gen.Parent then
			total = total + 1
			local progress = GetGenProgressRealTime(data.gen)
			if progress >= 100 then
				completed = completed + 1
			else
				incomplete = incomplete + 1
			end
		end
	end
	return completed, total, incomplete
end
local function GetIncompleteGens(myPos)
	local gens = {}
	for _, data in ipairs(GFS.AutoGenPoints) do
		if data.gen and data.gen.Parent then
			local progress = GetGenProgressRealTime(data.gen)
			if progress < 100 then
				local genPos
				pcall(function()
				if data.pt and data.pt:IsA("BasePart") then
					genPos = data.pt.Position
				elseif data.gen.PrimaryPart then
					genPos = data.gen.PrimaryPart.Position
				end
			end)
			if genPos then
				local dist = myPos and (genPos - myPos).Magnitude or 0
				table.insert(gens, { data = data, pos = genPos, dist = dist, progress = progress })
			end
		end
	end
end
if myPos then
	table.sort(gens, function(a, b) return a.dist < b.dist end)
end
return gens
end
local function GetSafeGen(avoidPos, minDist, excludeGen)
	local safeGens = {}
	for _, data in ipairs(GFS.AutoGenPoints) do
		if data.gen and data.gen.Parent then
			local shouldSkip = excludeGen and data.gen == excludeGen
			if not shouldSkip then
				local progress = GetGenProgressRealTime(data.gen)
				if progress < 100 then
					local genPos
					pcall(function()
					if data.pt and data.pt:IsA("BasePart") then
						genPos = data.pt.Position
					elseif data.gen.PrimaryPart then
						genPos = data.gen.PrimaryPart.Position
					end
				end)
				if genPos then
					local dist = (genPos - avoidPos).Magnitude
					if dist > minDist then
						table.insert(safeGens, { data = data, pos = genPos, dist = dist })
					end
				end
			end
		end
	end
end
table.sort(safeGens, function(a, b) return a.dist > b.dist end)
if #safeGens > 0 then
	return safeGens[1]
end
return nil
end
local function GetNearestKillerDist(myPos)
	local nearestDist = math.huge
	local nearestPos = nil
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and IsKiller(player) and player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dist = (hrp.Position - myPos).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestPos = hrp.Position
				end
			end
		end
	end
	return nearestDist, nearestPos
end
local function NeutralizeBody()
	local originalMode = GFS.AutoGenMode
	GFS.AutoGenMode = "Silent"
	local gen = GFS.AutoGenCurrentGenData and GFS.AutoGenCurrentGenData.gen
	local pt = GFS.AutoGenCurrentGenData and GFS.AutoGenCurrentGenData.pt
	local char = LocalPlayer.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	GFS.AutoGenIsRepairing = false
	pcall(function()
	if GFS.AutoGenRemotes.repair then
		if pt then
			GFS.AutoGenRemotes.repair:FireServer(pt, false)
		end
		if myRoot then
			GFS.AutoGenRemotes.repair:FireServer(myRoot.Position, false)
			GFS.AutoGenRemotes.repair:FireServer(myRoot.Position)
		end
		GFS.AutoGenRemotes.repair:FireServer(false)
		GFS.AutoGenRemotes.repair:FireServer(nil)
	else
	end
	if GFS.AutoGenRemotes.repairAnim then
		GFS.AutoGenRemotes.repairAnim:FireServer(nil)
		if pt then
			GFS.AutoGenRemotes.repairAnim:FireServer(pt, false)
		end
	end
	if GFS.AutoGenRemotes.skill then
		GFS.AutoGenRemotes.skill:FireServer("cancel")
		GFS.AutoGenRemotes.skill:FireServer(false)
		GFS.AutoGenRemotes.skill:FireServer(nil)
	end
end)
pcall(function()
if char then
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		task.delay(0.05, function()
		if humanoid and humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
	end)
end
end
end)
GFS.AutoGenMode = originalMode
end
local function TPToGen(genEntry, myRoot)
	if not genEntry or not myRoot then return false end
	if GFS.AutoGenTPLocked then return false end
	GFS.AutoGenTPLocked = true
	GFS.AutoGenPaused = true
	DebugLog("TPToGen: FORCE Silent neutralization before TP...")
	NeutralizeBody()
	task.wait(0.2)
	local oldGenModel = GFS.AutoGenCurrentGenModel
	GFS.AutoGenCurrentGenData = nil
	GFS.AutoGenCurrentGenModel = nil
	GFS.AutoGenLastFire = tick() + 1
	task.wait(0.1)
	pcall(function()
	myRoot.CFrame = CFrame.new(genEntry.pos + Vector3.new(0, 2, 0))
end)
task.wait(0.3)
GFS.AutoGenCurrentGenData = genEntry.data
GFS.AutoGenCurrentGenModel = genEntry.data.gen
task.delay(0.3, function()
GFS.AutoGenPaused = false
GFS.AutoGenTPLocked = false
end)
DebugLog("TP complete")
return true
end
local function DoInstantEscape()
	local myChar = LocalPlayer.Character
	if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then
		Library:Notify("No character for escape!", 2)
		return
	end
	local myRoot = myChar.HumanoidRootPart
	local finishLineFound = false
	pcall(function()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "Fininshline" or obj.Name == "FinishLine" or obj.Name == "Finish" or obj.Name == "EscapeZone" then
			if obj:IsA("BasePart") then
				myRoot.CFrame = obj.CFrame
				finishLineFound = true
			elseif obj:IsA("Model") and obj.PrimaryPart then
				myRoot.CFrame = obj.PrimaryPart.CFrame
				finishLineFound = true
			end
			break
		end
	end
end)
if not finishLineFound then
	pcall(function()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:FindFirstChild("TouchInterest") then
			local parentName = obj.Parent and obj.Parent.Name or ""
			if parentName:find("Exit") or parentName:find("Finish") or parentName:find("Escape") then
				myRoot.CFrame = obj.CFrame
				finishLineFound = true
				break
			end
		end
	end
end)
end
pcall(function()
local Remote = ReplicatedStorage:FindFirstChild("Remotes")
if Remote then
	local ExitRemote = Remote:FindFirstChild("Exit")
	if ExitRemote and ExitRemote:FindFirstChild("LeverEvent") then
		local fired = false
		for _, gate in ipairs(workspace:GetDescendants()) do
			if not fired and (gate.Name:find("Exit") or gate.Name:find("Lever")) then
				ExitRemote.LeverEvent:FireServer(gate, true)
				fired = true
			end
		end
		pcall(function() ExitRemote.LeverEvent:FireServer() end)
	end
	task.wait(0.15)
	local GenRemote = Remote:FindFirstChild("Generator")
	if GenRemote and GenRemote:FindFirstChild("Escapetime") then
		GenRemote.Escapetime:FireServer()
	end
	local RoundRemote = Remote:FindFirstChild("Round")
	if RoundRemote then
		RoundRemote:FireServer()
	end
	local GameRemote = Remote:FindFirstChild("Game")
	if GameRemote then
		local escapeEvent = GameRemote:FindFirstChild("Escape")
		if escapeEvent and escapeEvent:IsA("RemoteEvent") then
			escapeEvent:FireServer()
		end
	end
end
end)
Library:Notify("Escape triggered!", 2)
end
local function StopAutoGen()
	if GFS.AutoGenStopping then
		return
	end
	GFS.AutoGenStopping = true
	GFS.AutoGenEnabled = false
	GFS.AutoGenPaused = true
	GFS.AutoGenIsRepairing = false
	if GFS.AutoGenConnection then
		pcall(function() GFS.AutoGenConnection:Disconnect() end)
		GFS.AutoGenConnection = nil
	end
	task.wait(0.15)
	local originalMode = GFS.AutoGenMode
	GFS.AutoGenMode = "Silent"
	NeutralizeBody()
	GFS.AutoGenMode = originalMode
	task.wait(0.2)
	GFS.AutoGenCurrentGenData = nil
	GFS.AutoGenCurrentGenModel = nil
	GFS.AutoGenPaused = false
	GFS.AutoGenTPLocked = false
	GFS.AutoGenStopping = false
	GFS.AutoGenCutsceneEnded = false
	GFS.AutoGenWaitingForRole = false
end
GFS.AutoGenScanGenerators = ScanGenerators
GFS.AutoGenGetIncompleteGens = GetIncompleteGens
GFS.AutoGenTPToGen = TPToGen
GFS.AutoGenNeutralizeBody = NeutralizeBody
local function StartAutoGen()
	GFS.AutoGenEscapeTriggered = false
	GFS.AutoGenPaused = false
	GFS.AutoGenTPLocked = false
	GFS.AutoGenWaitingForRole = false
	if GFS.AutoGenConnection then
		pcall(function() GFS.AutoGenConnection:Disconnect() end)
		GFS.AutoGenConnection = nil
	end
	pcall(function()
	local r = ReplicatedStorage:FindFirstChild("Remotes")
	local g = r and r:FindFirstChild("Generator")
	if g then
		GFS.AutoGenRemotes.repair = g:FindFirstChild("RepairEvent") or g:FindFirstChild("Repair")
		GFS.AutoGenRemotes.repairAnim = g:FindFirstChild("RepairAnim") or g:FindFirstChild("RepairAnimation")
		GFS.AutoGenRemotes.skill = g:FindFirstChild("SkillCheckResultEvent") or
		g:FindFirstChild("SkillCheckResult")
		GFS.AutoGenRemotes.skillCheck = g:FindFirstChild("SkillCheckEvent") or g:FindFirstChild("SkillCheck")
		GFS.AutoGenRemotes.progress = r:FindFirstChild("Progress") and
		r.Progress:FindFirstChild("ProgressUpdateEvent")
	end
	DebugLog("Remotes: repair=" ..
	tostring(GFS.AutoGenRemotes.repair ~= nil) .. ", skill=" .. tostring(GFS.AutoGenRemotes.skill ~= nil))
end)
local currentRole = DetectMyRole()
if currentRole == "Survivor" then
	GFS.AutoGenWaitingForRole = false
	GFS.AutoGenCutsceneEnded = false
	GFS.AutoGenPaused = true
	GFS.AutoGenIsRepairing = false
	local genCount = ScanGenerators()
	local guiGensLeft = GetGensLeftFromGUI()
	if guiGensLeft == nil or guiGensLeft == 0 then
		GFS.AutoGenEscapeTriggered = true
		local reason = guiGensLeft == nil and "All survivors dead!" or "All gens already done!"
		Library:Notify(reason, 3)
		if GFS.AutoGenInstantEscape then DoInstantEscape() end
		StopAutoGen()
		return
	end
	task.spawn(function()
	local maxWaitTime = 30
	local startTime = tick()
	Library:Notify("Auto Gen: Preparing..", 2)
	local minWait = 4
	task.wait(minWait)
	if not GFS.AutoGenEnabled or GFS.AutoGenStopping then
		return
	end
	local consecutiveDetections = 0
	local requiredDetections = 3
	local lastValue = nil
	while (tick() - startTime) < maxWaitTime do
		if not GFS.AutoGenEnabled or GFS.AutoGenStopping then
			return
		end
		local guiGensLeft = GetGensLeftFromGUI()
		if guiGensLeft ~= nil then
			if guiGensLeft == lastValue then
				consecutiveDetections = consecutiveDetections + 1
				if consecutiveDetections >= requiredDetections then
					if guiGensLeft == 0 then
						GFS.AutoGenEscapeTriggered = true
						Library:Notify("All gens already done!", 3)
						if GFS.AutoGenInstantEscape then DoInstantEscape() end
						StopAutoGen()
						return
					end
					GFS.AutoGenCutsceneEnded = true
					GFS.AutoGenPaused = false
					Library:Notify("Auto Gen: Started! " .. guiGensLeft .. " gens", 2)
					ScanGenerators()
					local char = LocalPlayer.Character
					local myRoot = char and char:FindFirstChild("HumanoidRootPart")
					if myRoot then
						local incompleteList = GetIncompleteGens(myRoot.Position)
						if #incompleteList > 0 then
							TPToGen(incompleteList[1], myRoot)
						else
						end
					end
					return
				end
			else
				lastValue = guiGensLeft
				consecutiveDetections = 1
			end
		else
			consecutiveDetections = 0
			lastValue = nil
		end
		task.wait(0.5)
	end
	Library:Notify("Auto Gen: Timeout! Will retry...", 3)
end)
else
	GFS.AutoGenWaitingForRole = true
	GFS.AutoGenPaused = true
	GFS.AutoGenCutsceneEnded = false
	GFS.AutoGenIsRepairing = false
	Library:Notify("Auto Gen: ON (waiting for Survivor role...)", 2)
end
GFS.AutoGenConnection = RunService.Heartbeat:Connect(function()
if not GFS.AutoGenEnabled or GFS.AutoGenStopping then
	return
end
local currentRole = DetectMyRole()
if currentRole ~= "Survivor" then
	if not GFS.AutoGenWaitingForRole then
		task.defer(RefreshESPOnRoleChange)
		GFS.AutoGenWaitingForRole = true
		GFS.AutoGenPaused = true
		GFS.AutoGenCutsceneEnded = false
		GFS.AutoGenIsRepairing = false
	end
	return
end
if GFS.AutoGenWaitingForRole then
	task.defer(RefreshESPOnRoleChange)
	GFS.AutoGenWaitingForRole = false
	GFS.AutoGenPaused = true
	Library:Notify("Auto Gen: Survivor detected, waiting for game...", 2)
	task.spawn(function()
	local minWait = 4
	task.wait(minWait)
	local consecutiveDetections = 0
	local requiredDetections = 3
	local lastGensLeft = nil
	local maxWaitTime = 30
	local startTime = tick()
	while (tick() - startTime) < maxWaitTime do
		if not GFS.AutoGenEnabled or GFS.AutoGenStopping then
			return
		end
		local guiGensLeft = GetGensLeftFromGUI()
		if guiGensLeft ~= nil then
			if guiGensLeft == lastGensLeft then
				consecutiveDetections = consecutiveDetections + 1
			else
				consecutiveDetections = 1
			end
			lastGensLeft = guiGensLeft
			if consecutiveDetections >= requiredDetections then
				if guiGensLeft == 0 then
					GFS.AutoGenEscapeTriggered = true
					Library:Notify("All gens already done!", 3)
					if GFS.AutoGenInstantEscape then DoInstantEscape() end
					StopAutoGen()
					return
				end
				GFS.AutoGenCutsceneEnded = true
				GFS.AutoGenPaused = false
				Library:Notify("Auto Gen: Started! " .. guiGensLeft .. " gens left", 2)
				break
			end
		else
			consecutiveDetections = 0
			lastGensLeft = nil
		end
		task.wait(0.5)
	end
	if (tick() - startTime) >= maxWaitTime then
		Library:Notify("Auto Gen: Timeout! Will retry...", 3)
		return
	end
	ScanGenerators()
	local char = LocalPlayer.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if myRoot then
		local incompleteList = GetIncompleteGens(myRoot.Position)
		if #incompleteList > 0 then
			TPToGen(incompleteList[1], myRoot)
		end
	end
end)
return
end
if not GFS.AutoGenCutsceneEnded then return end
local char = LocalPlayer.Character
local myRoot = char and char:FindFirstChild("HumanoidRootPart")
if not myRoot then return end
local now = tick()
if now - GFS.AutoGenLastScan > 1 then
	ScanGenerators()
end
if GFS.AutoGenInstantEscape and not GFS.AutoGenEscapeTriggered then
	local guiGensLeft = GetGensLeftFromGUI()
	if guiGensLeft == nil or guiGensLeft == 0 then
		GFS.AutoGenEscapeTriggered = true
		local reason = guiGensLeft == nil and "All survivors dead! Escaping..." or
		"All gens done! Escaping..."
		Library:Notify(reason, 3)
		GFS.AutoGenPaused = true
		task.defer(function()
		task.wait(0.2)
		DoInstantEscape()
	end)
	StopAutoGen()
	return
end
end
if GFS.AutoGenTPLocked then return end
local needNewGen = false
if GFS.AutoGenCurrentGenData then
	local currentProgress = GetGenProgressRealTime(GFS.AutoGenCurrentGenData.gen)
	if currentProgress >= 100 and now - GFS.AutoGenLastGenSwitch > 1 then
		needNewGen = true
	end
else
	if now - GFS.AutoGenLastGenSwitch > 1 then
		needNewGen = true
	end
end
if needNewGen then
	GFS.AutoGenLastGenSwitch = now
	local incompleteList = GetIncompleteGens(myRoot.Position)
	if #incompleteList > 0 then
		task.spawn(function()
		TPToGen(incompleteList[1], myRoot)
	end)
else
	ScanGenerators()
end
end
if GFS.AutoGenTPKillerEnabled and not GFS.AutoGenTPLocked then
	local killerDist, killerPos = GetNearestKillerDist(myRoot.Position)
	if killerDist <= GFS.AutoGenKillerTolerance and now - GFS.AutoGenLastTP > 3 then
		local safeGen = GetSafeGen(killerPos, GFS.AutoGenKillerTolerance * 2, GFS.AutoGenCurrentGenModel)
		if safeGen then
			GFS.AutoGenLastTP = now
			task.spawn(function()
			TPToGen(safeGen, myRoot)
			Library:Notify("Killer near, teleport to safe gen", 2)
		end)
	end
end
end
if GFS.AutoGenPaused or GFS.AutoGenTPLocked then return end
if not GFS.AutoGenEnabled or GFS.AutoGenStopping or GFS.AutoGenPaused then
	return
end
if now - GFS.AutoGenLastFire < GFS.AutoGenFireRate then return end
if GFS.AutoGenCurrentGenData then
	local currentData = GFS.AutoGenCurrentGenData
	if currentData.gen and currentData.gen.Parent then
		local progress = GetGenProgressRealTime(currentData.gen)
		if progress < 100 then
			if not GFS.AutoGenEnabled or GFS.AutoGenStopping then
				return
			end
			GFS.AutoGenLastFire = now
			local gen = currentData.gen
			local pt = currentData.pt
			local myRoot = char:FindFirstChild("HumanoidRootPart")
			GFS.AutoGenIsRepairing = true
			pcall(function()
			if not GFS.AutoGenEnabled or GFS.AutoGenStopping then return end
			if GFS.AutoGenMode == "Legit" then
				if GFS.AutoGenRemotes.repairAnim then
					GFS.AutoGenRemotes.repairAnim:FireServer(pt)
				end
				if GFS.AutoGenRemotes.repair then
					GFS.AutoGenRemotes.repair:FireServer(pt, true)
					GFS.AutoGenRemotes.repair:FireServer(gen, pt)
				end
				if GFS.AutoGenRemotes.skill then
					GFS.AutoGenRemotes.skill:FireServer("success", 1, gen, pt)
				end
				DebugLog("Legit fired (IsRepairing=true)")
			elseif GFS.AutoGenMode == "Silent" then
				if GFS.AutoGenRemotes.repair then
					GFS.AutoGenRemotes.repair:FireServer(pt, true)
					GFS.AutoGenRemotes.repair:FireServer(pt)
					GFS.AutoGenRemotes.repair:FireServer(gen, pt)
				end
				if GFS.AutoGenRemotes.skill then
					GFS.AutoGenRemotes.skill:FireServer("success", 1, gen, pt)
				end
				DebugLog("Silent fired (IsRepairing=true)")
			end
		end)
	end
end
end
end)
end
local AG_Toggle = AutoGenBox:AddToggle('AutoGenRepair', {
Text = 'Auto Generator',
Default = false,
Tooltip = IsPremium and 'Auto TP to generators & repair. Works when you are Survivor (can enable anytime).' or
'PREMIUM ONLY - This feature requires a Premium key',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
if Value then
	GFS.AutoGenEnabled = true
	pcall(function()
	StartAutoGen()
end)
else
	StopAutoGen()
end
end
}):AddKeyPicker('AutoGenToggleKey', {
Default = 'None',
Mode = 'Toggle',
Text = 'Toggle',
SyncToggleState = true
})
local AG_KeyPicker = Options.AutoGenToggleKey
PremiumOnly(AG_Toggle, AG_KeyPicker)
local AG_InstantEscape = AutoGenBox:AddCheckbox('AutoGenInstantEscape', {
Text = 'Instant Escape When Done',
Default = false,
Tooltip = IsPremium and 'Auto escape when all generators are complete or all survivors are dead' or
'PREMIUM ONLY - This feature requires a Premium key',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.AutoGenInstantEscape = Value
end
})
PremiumOnly(AG_InstantEscape)
local AG_Method = AutoGenBox:AddDropdown('AutoGenMethod', {
Text = 'Repair Method',
Default = 'Legit',
Values = { 'Legit', 'Silent' },
Tooltip = IsPremium and 'Legit = Full animation (counts for reward) | Silent = No animation' or
'PREMIUM ONLY - This feature requires a Premium key',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
if Value == nil or Value == '' then return end
GFS.AutoGenMode = Value
end
})
PremiumOnly(AG_Method)
local AG_Speed = AutoGenBox:AddSlider('AutoGenSpeed', {
Text = 'Speed (Silent)',
Default = 7,
Min = 1,
Max = 20,
Rounding = 0,
Tooltip = IsPremium and 'How fast to repair generators in Silent mode' or
'PREMIUM ONLY - This feature requires a Premium key',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.AutoGenFireRate = 1 / Value
end
})
PremiumOnly(AG_Speed)
local AG_TPKiller = AutoGenBox:AddCheckbox('AutoGenTPKiller', {
Text = 'TP When Killer Near',
Default = false,
Tooltip = IsPremium and 'Teleport to safe generator when killer approaches' or
'PREMIUM ONLY - This feature requires a Premium key',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.AutoGenTPKillerEnabled = Value
end
})
PremiumOnly(AG_TPKiller)
local AG_KillerDist = AutoGenBox:AddSlider('AutoGenKillerDist', {
Text = 'Killer Distance',
Default = 30,
Min = 10,
Max = 100,
Rounding = 0,
Suffix = ' studs',
Tooltip = IsPremium and 'Distance at which to teleport away from killer' or
'PREMIUM ONLY - This feature requires a Premium key',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.AutoGenKillerTolerance = Value
end
})
PremiumOnly(AG_KillerDist)
LocalPlayer.CharacterAdded:Connect(function(char)
task.delay(1, function()
local toggleState = Toggles.AutoGenRepair and Toggles.AutoGenRepair.Value
if toggleState and (not GFS.AutoGenEnabled or not GFS.AutoGenConnection) then
	GFS.AutoGenStopping = false
	GFS.AutoGenEnabled = true
	StartAutoGen()
	Library:Notify("Auto Gen: Restarted for new game!", 2)
end
end)
end)
end
task.spawn(function()
task.wait(0.6)
SafeInit(InitAutoGeneratorScope, 'InitAutoGeneratorScope')
end)
function InitAimbotScope()
	local AimbotBox = Tabs.Global:AddLeftGroupbox('Aimbot', 'crosshair')
	AimbotState.silentAimEnabled = AimbotState.silentAimEnabled or false
	AimbotState.aimlockEnabled = AimbotState.aimlockEnabled or false
	AimbotState.aimTarget = AimbotState.aimTarget or nil
	AimbotState.aimFOV = AimbotState.aimFOV or 100
	AimbotState.aimSmoothing = AimbotState.aimSmoothing or 5
	AimbotState.aimPart = AimbotState.aimPart or "Head"
	AimbotState.aimTeamCheck = AimbotState.aimTeamCheck == nil and true or AimbotState.aimTeamCheck
	AimbotState.aimVisCheck = AimbotState.aimVisCheck or false
	AimbotState.createAimVisuals = function()
	if not DrawingAvailable then return end
	pcall(function()
	if not AimbotState.fovCircle then
		AimbotState.fovCircle = Drawing.new("Circle")
		AimbotState.fovCircle.Visible = false
		AimbotState.fovCircle.Radius = AimbotState.aimFOV or 100
		AimbotState.fovCircle.Thickness = 1
		AimbotState.fovCircle.Color = Color3.fromRGB(255, 255, 255)
		AimbotState.fovCircle.Transparency = 1
		AimbotState.fovCircle.Filled = false
		AimbotState.fovCircle.NumSides = 64
	end
	if not AimbotState.targetIndicator then
		AimbotState.targetIndicator = Drawing.new("Circle")
		AimbotState.targetIndicator.Visible = false
		AimbotState.targetIndicator.Radius = 5
		AimbotState.targetIndicator.Thickness = 2
		AimbotState.targetIndicator.Color = Color3.fromRGB(255, 0, 0)
		AimbotState.targetIndicator.Transparency = 1
		AimbotState.targetIndicator.Filled = true
	end
	if not AimbotState.aimLine then
		AimbotState.aimLine = Drawing.new("Line")
		AimbotState.aimLine.Visible = false
		AimbotState.aimLine.Thickness = 1
		AimbotState.aimLine.Color = Color3.fromRGB(255, 0, 0)
		AimbotState.aimLine.Transparency = 1
	end
end)
end
AimbotState.getClosestPlayerInFOV = function()
local camera = workspace.CurrentCamera
if not camera then return nil end
local mousePos = UserInputService:GetMouseLocation()
local closest = nil
local closestDist = AimbotState.aimFOV
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then
		local shouldSkip = false
		if AimbotState.aimTeamCheck and player.Team == LocalPlayer.Team then
			shouldSkip = true
		end
		if not shouldSkip then
			local character = player.Character
			if not character then shouldSkip = true end
			if not shouldSkip then
				local targetPart = character:FindFirstChild(AimbotState.aimPart) or
				character:FindFirstChild("HumanoidRootPart")
				if not targetPart then shouldSkip = true end
				if not shouldSkip then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if not humanoid or humanoid.Health <= 0 then shouldSkip = true end
					if not shouldSkip then
						if AimbotState.aimVisCheck then
							local rayParams = RaycastParams.new()
							rayParams.FilterType = Enum.RaycastFilterType.Blacklist
							rayParams.FilterDescendantsInstances = { LocalPlayer.Character }
							local origin = camera.CFrame.Position
							local direction = (targetPart.Position - origin).Unit * 500
							local result = workspace:Raycast(origin, direction, rayParams)
							if result and result.Instance then
								if not result.Instance:IsDescendantOf(character) then
									shouldSkip = true
								end
							end
						end
						if not shouldSkip then
							local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
							if onScreen then
								local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
								if dist < closestDist then
									closestDist = dist
									closest = player
								end
							end
						end
					end
				end
			end
		end
	end
end
return closest
end
AimbotState.updateAimVisuals = function()
if not DrawingAvailable then return end
local camera = workspace.CurrentCamera
if not camera then return end
local mousePos = UserInputService:GetMouseLocation()
if AimbotState.fovCircle then
	AimbotState.fovCircle.Position = mousePos
	AimbotState.fovCircle.Radius = AimbotState.aimFOV
	AimbotState.fovCircle.Visible = Toggles.ShowFOV and Toggles.ShowFOV.Value
end
if AimbotState.targetIndicator and AimbotState.aimLine then
	if AimbotState.aimTarget and AimbotState.aimTarget.Character then
		local targetPart = AimbotState.aimTarget.Character:FindFirstChild(AimbotState.aimPart) or
		AimbotState.aimTarget.Character:FindFirstChild("HumanoidRootPart")
		if targetPart then
			local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
			if onScreen then
				AimbotState.targetIndicator.Position = Vector2.new(screenPos.X, screenPos.Y)
				AimbotState.targetIndicator.Visible = Toggles.ShowTarget and Toggles.ShowTarget.Value
				AimbotState.aimLine.From = mousePos
				AimbotState.aimLine.To = Vector2.new(screenPos.X, screenPos.Y)
				AimbotState.aimLine.Visible = Toggles.ShowAimLine and Toggles.ShowAimLine.Value
			else
				AimbotState.targetIndicator.Visible = false
				AimbotState.aimLine.Visible = false
			end
		else
			AimbotState.targetIndicator.Visible = false
			AimbotState.aimLine.Visible = false
		end
	else
		AimbotState.targetIndicator.Visible = false
		AimbotState.aimLine.Visible = false
	end
end
end
AimbotState.manageAimLoop = function()
local shouldRun = false
if AimbotState.silentAimEnabled or AimbotState.aimlockEnabled then shouldRun = true end
if Toggles.ShowFOV and Toggles.ShowFOV.Value then shouldRun = true end
if Toggles.ShowTarget and Toggles.ShowTarget.Value then shouldRun = true end
if Toggles.ShowAimLine and Toggles.ShowAimLine.Value then shouldRun = true end
if shouldRun then
	AimbotState.createAimVisuals()
	if not AimbotState.aimVisualConnection then
		AimbotState.aimVisualConnection = Library:SafeConnect(RunService.RenderStepped, function()
		if AimbotState.silentAimEnabled or AimbotState.aimlockEnabled then
			AimbotState.aimTarget = AimbotState.getClosestPlayerInFOV()
		else
			AimbotState.aimTarget = nil
		end
		AimbotState.updateAimVisuals()
		if AimbotState.aimlockEnabled and AimbotState.aimTarget and AimbotState.aimTarget.Character then
			local camera = workspace.CurrentCamera
			local targetPart = AimbotState.aimTarget.Character:FindFirstChild(AimbotState.aimPart) or
			AimbotState.aimTarget.Character:FindFirstChild("HumanoidRootPart")
			if targetPart and camera then
				local targetPos = targetPart.Position
				local camPos = camera.CFrame.Position
				local direction = (targetPos - camPos).Unit
				local currentLook = camera.CFrame.LookVector
				local smoothedDirection = currentLook:Lerp(direction, 1 / AimbotState.aimSmoothing)
				camera.CFrame = CFrame.lookAt(camPos, camPos + smoothedDirection)
			end
		end
	end)
end
else
	if AimbotState.aimVisualConnection then
		AimbotState.aimVisualConnection:Disconnect()
		AimbotState.aimVisualConnection = nil
	end
	if AimbotState.fovCircle then AimbotState.fovCircle.Visible = false end
	if AimbotState.targetIndicator then AimbotState.targetIndicator.Visible = false end
	if AimbotState.aimLine then AimbotState.aimLine.Visible = false end
    
    -- Ensure everything is hidden if no toggles are on
    local fovOn = Toggles.ShowFOV and Toggles.ShowFOV.Value or false
    if AimbotState.fovCircle then AimbotState.fovCircle.Visible = fovOn end
end
end
AimbotBox:AddToggle('Aimlock', {
Text = 'Aimlock',
Default = false,
Tooltip = 'Locks camera onto target (Hold Key)',
Callback = function(Value)
AimbotState.aimlockEnabled = Value
AimbotState.manageAimLoop()
if Value then
	Library:Notify('Aimlock: Enabled', 1)
else
	Library:Notify('Aimlock: Disabled', 1)
end
end
}):AddKeyPicker('AimlockKey', {
Default = 'None',
Text = 'Aimlock',
Mode = 'Hold',
SyncToggleState = true,
})
Toggles.Aimlock:OnChanged(function()
AimbotState.aimlockEnabled = Toggles.Aimlock.Value
AimbotState.manageAimLoop()
end)
AimbotBox:AddSlider('AimFOV', {
Text = 'Aim FOV',
Default = 100,
Min = 10,
Max = 500,
Rounding = 0,
Suffix = ' px',
Callback = function(Value)
AimbotState.aimFOV = Value
if AimbotState.fovCircle then
	AimbotState.fovCircle.Radius = Value
end
end
})
Options.AimFOV:OnChanged(function()
AimbotState.aimFOV = Options.AimFOV.Value
if AimbotState.fovCircle then
	AimbotState.fovCircle.Radius = Options.AimFOV.Value
end
end)
AimbotBox:AddSlider('AimSmoothing', {
Text = 'Smoothing',
Default = 5,
Min = 1,
Max = 20,
Rounding = 1,
Tooltip = 'Higher = Smoother but slower',
Callback = function(Value)
AimbotState.aimSmoothing = Value
end
})
Options.AimSmoothing:OnChanged(function()
AimbotState.aimSmoothing = Options.AimSmoothing.Value
end)
AimbotBox:AddDropdown('AimPart', {
Text = 'Target Part',
Default = 'Head',
Values = { 'Head', 'HumanoidRootPart', 'UpperTorso', 'LowerTorso' },
Callback = function(Value)
if Value == nil or Value == '' then return end
AimbotState.aimPart = Value
end
})
Options.AimPart:OnChanged(function()
AimbotState.aimPart = Options.AimPart.Value
end)
AimbotBox:AddCheckbox('AimTeamCheck', {
Text = 'Team Check',
Default = true,
Callback = function(Value)
AimbotState.aimTeamCheck = Value
end
})
Toggles.AimTeamCheck:OnChanged(function()
AimbotState.aimTeamCheck = Toggles.AimTeamCheck.Value
end)
AimbotBox:AddCheckbox('AimVisCheck', {
Text = 'Visibility Check',
Default = false,
Tooltip = 'Only aim at visible targets',
Callback = function(Value)
AimbotState.aimVisCheck = Value
end
})
Toggles.AimVisCheck:OnChanged(function()
AimbotState.aimVisCheck = Toggles.AimVisCheck.Value
end)
AimbotBox:AddCheckbox('ShowFOV', {
Text = 'Show FOV Circle',
Default = false,
Callback = function(Value)
AimbotState.manageAimLoop()
end
}):AddColorPicker('FOVColor', {
Title = 'FOV Color',
Default = Color3.fromRGB(255, 255, 255),
Callback = function(Value)
if AimbotState.fovCircle then
	AimbotState.fovCircle.Color = Value
end
end
})
Toggles.ShowFOV:OnChanged(function()
AimbotState.manageAimLoop()
end)
Options.FOVColor:OnChanged(function()
if AimbotState.fovCircle then
	AimbotState.fovCircle.Color = Options.FOVColor.Value
end
end)
AimbotBox:AddCheckbox('ShowTarget', {
Text = 'Show Target Indicator',
Default = false,
Callback = function(Value)
AimbotState.manageAimLoop()
end
}):AddColorPicker('TargetColor', {
Title = 'Target Color',
Default = Color3.fromRGB(255, 0, 0),
Callback = function(Value)
if AimbotState.targetIndicator then
	AimbotState.targetIndicator.Color = Value
end
end
})
Toggles.ShowTarget:OnChanged(function()
AimbotState.manageAimLoop()
end)
Options.TargetColor:OnChanged(function()
if AimbotState.targetIndicator then
	AimbotState.targetIndicator.Color = Options.TargetColor.Value
end
end)
AimbotBox:AddCheckbox('ShowAimLine', {
Text = 'Show Aim Line',
Default = false,
Callback = function(Value)
AimbotState.manageAimLoop()
end
}):AddColorPicker('AimLineColor', {
Title = 'Line Color',
Default = Color3.fromRGB(255, 0, 0),
Callback = function(Value)
if AimbotState.aimLine then
	AimbotState.aimLine.Color = Value
end
end
})
Toggles.ShowAimLine:OnChanged(function()
AimbotState.manageAimLoop()
end)
Options.AimLineColor:OnChanged(function()
if AimbotState.aimLine then
	AimbotState.aimLine.Color = Options.AimLineColor.Value
end
end)
end
function InitEmoteScope()
	local EmoteDatabase = {
	["California Girls"] = { Anim = "rbxassetid://123552803041504", Audio = "rbxassetid://87899327891544" },
	["Static"] = { Anim = "rbxassetid://95096724457263", Audio = "rbxassetid://70950516511572" },
	["Kyoufuu"] = { Anim = "rbxassetid://137322894494527", Audio = "rbxassetid://129064643026442" },
	["Arm Swing"] = { Anim = "rbxassetid://80552139463944", Audio = "rbxassetid://74216458932348" },
	["Tor Monitor Ketua"] = { Anim = "rbxassetid://81792358514569", Audio = "rbxassetid://72665050838808" },
	["Quick Combo"] = { Anim = "rbxassetid://105592621576604", Audio = "rbxassetid://88505795419631" },
	["Mannrobics"] = { Anim = "rbxassetid://134677515695156", Audio = "rbxassetid://109596159930017" },
	["Schadenfreude"] = { Anim = "rbxassetid://138303785534052", Audio = "rbxassetid://92070710839040" },
	["Applause"] = { Anim = "rbxassetid://96328361165090", Audio = "rbxassetid://115490787020749" },
	["Griddy"] = { Anim = "rbxassetid://75586690784894", Audio = nil },
	["The Dab"] = { Anim = "rbxassetid://93350677984372", Audio = nil },
	["Wave"] = { Anim = "rbxassetid://99670106766588", Audio = nil },
	["24 Hour Cinderella"] = { Anim = "rbxassetid://137195203725366", Audio = nil },
	["Christmas Spirit"] = { Anim = "rbxassetid://137859761110514", Audio = nil },
	["Floating Rest"] = { Anim = "rbxassetid://114593021219597", Audio = nil },
	["g0on"] = { Type = "Special" }
	}
	local EmoteNames = {}
	for name, _ in pairs(EmoteDatabase) do
		table.insert(EmoteNames, name)
	end
	table.sort(EmoteNames)
	local currentTrack = nil
	local currentSound = nil
	local GoonState = {
	Active = false,
	SpeedMult = 1,
	CurSpeed = 1,
	Inc = false,
	Dec = false,
	Conns = {},
	Tracks = {}
	}
	local function StopGoon()
		GoonState.Active = false
		for _, conn in pairs(GoonState.Conns) do
			conn:Disconnect()
		end
		GoonState.Conns = {}
		for _, track in pairs(GoonState.Tracks) do
			track:Stop()
		end
		GoonState.Tracks = {}
		GoonState.Inc = false
		GoonState.Dec = false
		GoonState.CurSpeed = 1
	end
	local function StopAll()
		if currentTrack then
			currentTrack:Stop(); currentTrack = nil
		end
		if currentSound then
			currentSound:Stop(); currentSound:Destroy(); currentSound = nil
		end
		StopGoon()
	end
	local function PlayGoon()
		local LocalPlayer = game:GetService("Players").LocalPlayer
		local Char = LocalPlayer.Character
		if not Char then return end
		local Humanoid = Char:FindFirstChild("Humanoid")
		local Animator = Humanoid and Humanoid:FindFirstChild("Animator")
		if not Animator then return end
		StopAll()
		GoonState.Active = true
		GoonState.SpeedMult = 1
		GoonState.CurSpeed = 1
		local anim1 = Instance.new("Animation")
		anim1.AnimationId = "rbxassetid://168268306"
		local track1 = Animator:LoadAnimation(anim1)
		local anim2 = Instance.new("Animation")
		anim2.AnimationId = "rbxassetid://72042024"
		local track2 = Animator:LoadAnimation(anim2)
		table.insert(GoonState.Tracks, track1)
		table.insert(GoonState.Tracks, track2)
		track1:Play()
		track2:Play()
		track1.TimePosition = 0.69
		track2.TimePosition = 0.2
		task.spawn(function()
		while GoonState.Active do
			track1.TimePosition = 0.69
			track2.TimePosition = 0.2
			track1:AdjustSpeed(GoonState.SpeedMult)
			track2:AdjustSpeed(GoonState.CurSpeed)
			task.wait(0.62 / math.max(GoonState.SpeedMult, GoonState.CurSpeed))
		end
	end)
	local UIS = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local inputBegan = UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.E then
			GoonState.Inc = true
		elseif input.KeyCode == Enum.KeyCode.Q then
			GoonState.Dec = true
		end
	end
end)
table.insert(GoonState.Conns, inputBegan)
local inputEnded = UIS.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.Keyboard then
	if input.KeyCode == Enum.KeyCode.E then
		GoonState.Inc = false
	elseif input.KeyCode == Enum.KeyCode.Q then
		GoonState.Dec = false
	end
end
end)
table.insert(GoonState.Conns, inputEnded)
local heartbeat = RunService.Heartbeat:Connect(function()
if GoonState.Inc then
	GoonState.CurSpeed = math.min(GoonState.CurSpeed + 0.1, 5)
elseif GoonState.Dec then
	GoonState.CurSpeed = math.max(GoonState.CurSpeed - 0.1, 0.1)
end
end)
table.insert(GoonState.Conns, heartbeat)
end
local function PlayEmote(name)
	local data = EmoteDatabase[name]
	if not data then return end
	StopAll()
	if name == "g0on" then
		PlayGoon()
		return
	end
	local LocalPlayer = game:GetService("Players").LocalPlayer
	local Char = LocalPlayer.Character
	if not Char then return end
	local Humanoid = Char:FindFirstChild("Humanoid")
	local HRP = Char:FindFirstChild("HumanoidRootPart")
	if not Humanoid or not HRP then return end
	local Animator = Humanoid:FindFirstChild("Animator")
	if not Animator then Animator = Instance.new("Animator", Humanoid) end
	local Anim = Instance.new("Animation")
	Anim.AnimationId = data.Anim
	local track = Animator:LoadAnimation(Anim)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play()
	currentTrack = track
	if data.Audio then
		local sound = Instance.new("Sound")
		sound.Name = "EmoteMusic"
		sound.SoundId = data.Audio
		sound.Parent = HRP
		sound.Looped = true
		sound.Volume = 0.8
		sound.RollOffMaxDistance = 80
		sound.RollOffMinDistance = 10
		sound.RollOffMode = Enum.RollOffMode.Inverse
		sound:Play()
		currentSound = sound
	end
end
; (getgenv and getgenv() or _G).EmotePlayerGroup = Tabs.Global:AddLeftGroupbox('Emote Player', 'laugh')
; (getgenv and getgenv() or _G).EmotePlayerGroup:AddDropdown('SelectedEmote', {
Values = EmoteNames,
Default = 1,
Multi = false,
Text = 'Select Emote',
Tooltip = 'Choose an emote to play'
})
; (getgenv and getgenv() or _G).EmotePlayerGroup:AddToggle('EmoteToggle', {
Text = 'Play Emote',
Default = false,
Tooltip = 'Toggle to start/stop dancing',
Callback = function(Value)
if Value then
	PlayEmote(Options.SelectedEmote.Value)
else
	StopAll()
end
end
}):AddKeyPicker('EmoteKey', {
Default = 'V',
Text = 'Emote Key',
Mode = 'Toggle',
SyncToggleState = true
})
Options.SelectedEmote:OnChanged(function()
if Toggles.EmoteToggle.Value then
	PlayEmote(Options.SelectedEmote.Value)
end
end)
end
task.spawn(function()
task.wait(0.5)
SafeInit(InitAimbotScope, 'InitAimbotScope')
SafeInit(InitEmoteScope, 'InitEmoteScope')
end)
InitKillerAlertScope = function()
local KillerWarning = {
Enabled = false,
Distance = 50,
LastWarning = 0,
Connection = nil
}
local RadarBox = Tabs.Global:AddRightGroupbox('Radar', 'map')
RadarBox:AddCheckbox('RadarEnabled', {
Text = 'Enable Radar',
Default = false,
Tooltip = 'Show minimap radar with players and objects',
Callback = function(Value)
GFS.RadarEnabled = Value
if Value then
	InitializeRadar()
	Library:Notify('Radar: Enabled', 2)
else
	HideRadar()
	Library:Notify('Radar: Disabled', 2)
end
end
})
RadarBox:AddCheckbox('RadarCircle', {
Text = 'Circle Radar',
Default = false,
Tooltip = 'Use circular radar instead of square',
Callback = function(Value)
GFS.RadarCircle = Value
end
})
RadarBox:AddSlider('RadarSize', {
Text = 'Radar Size',
Default = 120,
Min = 80,
Max = 250,
Rounding = 0,
Suffix = ' px',
Callback = function(Value)
GFS.RadarSize = Value
end
})
RadarBox:AddSlider('RadarRange', {
Text = 'Radar Range',
Default = 150,
Min = 50,
Max = 500,
Rounding = 0,
Suffix = ' studs',
Callback = function(Value)
GFS.RadarRange = Value
end
})
if DrawingAvailable then
	local CrosshairBox = Tabs.Global:AddRightGroupbox('Crosshair', 'crosshair')
	GFS.CrosshairEnabled = false
	GFS.CrosshairSize = 12
	GFS.CrosshairGap = 4
	GFS.CrosshairThickness = 1.5
	GFS.CrosshairColor = Color3.fromRGB(0, 255, 0)
	GFS.CrosshairDot = true
	GFS.CrosshairOutline = true
	local crosshairLines = {}
	for i = 1, 4 do
		local l = Drawing.new("Line")
		l.Thickness = 1.5
		l.Color = Color3.fromRGB(0, 255, 0)
		l.Visible = false
		l.Transparency = 1
		crosshairLines[i] = l
	end
	local crosshairOutlines = {}
	for i = 1, 4 do
		local l = Drawing.new("Line")
		l.Thickness = 3.5
		l.Color = Color3.fromRGB(0, 0, 0)
		l.Visible = false
		l.Transparency = 1
		crosshairOutlines[i] = l
	end
	local crosshairDot = Drawing.new("Circle")
	crosshairDot.Radius = 2
	crosshairDot.Thickness = 0
	crosshairDot.Color = Color3.fromRGB(0, 255, 0)
	crosshairDot.Filled = true
	crosshairDot.Visible = false
	crosshairDot.Transparency = 1
	crosshairDot.NumSides = 16
	local crosshairDotOutline = Drawing.new("Circle")
	crosshairDotOutline.Radius = 3
	crosshairDotOutline.Thickness = 1
	crosshairDotOutline.Color = Color3.fromRGB(0, 0, 0)
	crosshairDotOutline.Filled = false
	crosshairDotOutline.Visible = false
	crosshairDotOutline.Transparency = 1
	crosshairDotOutline.NumSides = 16
	local crosshairConn = nil
	local function UpdateCrosshair()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local viewSize = cam.ViewportSize
		local cx = viewSize.X / 2
		local cy = viewSize.Y / 2
		local size = GFS.CrosshairSize
		local gap = GFS.CrosshairGap
		local color = GFS.CrosshairColor
		local thick = GFS.CrosshairThickness
		local showOutline = GFS.CrosshairOutline
		crosshairLines[1].From = Vector2.new(cx, cy - gap)
		crosshairLines[1].To = Vector2.new(cx, cy - gap - size)
		crosshairLines[2].From = Vector2.new(cx, cy + gap)
		crosshairLines[2].To = Vector2.new(cx, cy + gap + size)
		crosshairLines[3].From = Vector2.new(cx - gap, cy)
		crosshairLines[3].To = Vector2.new(cx - gap - size, cy)
		crosshairLines[4].From = Vector2.new(cx + gap, cy)
		crosshairLines[4].To = Vector2.new(cx + gap + size, cy)
		for i = 1, 4 do
			crosshairLines[i].Color = color
			crosshairLines[i].Thickness = thick
			crosshairLines[i].Visible = true
			crosshairOutlines[i].From = crosshairLines[i].From
			crosshairOutlines[i].To = crosshairLines[i].To
			crosshairOutlines[i].Thickness = thick + 2
			crosshairOutlines[i].Visible = showOutline
		end
		crosshairDot.Position = Vector2.new(cx, cy)
		crosshairDot.Color = color
		crosshairDot.Visible = GFS.CrosshairDot
		crosshairDotOutline.Position = Vector2.new(cx, cy)
		crosshairDotOutline.Visible = GFS.CrosshairDot and showOutline
	end
	local function StartCrosshair()
		if crosshairConn then return end
		crosshairConn = Library:SafeConnect(RunService.RenderStepped, function()
		if GFS.CrosshairEnabled then
			UpdateCrosshair()
		end
	end)
end
local function StopCrosshair()
	if crosshairConn then
		crosshairConn:Disconnect(); crosshairConn = nil
	end
	for i = 1, 4 do
		crosshairLines[i].Visible = false
		crosshairOutlines[i].Visible = false
	end
	crosshairDot.Visible = false
	crosshairDotOutline.Visible = false
end
CrosshairBox:AddToggle('CrosshairToggle', {
Text = 'Crosshair',
Default = false,
Tooltip = 'Show crosshair overlay at screen center',
Callback = function(Value)
GFS.CrosshairEnabled = Value
if Value then
	StartCrosshair()
	Library:Notify('Crosshair: Enabled', 1)
else
	StopCrosshair()
	Library:Notify('Crosshair: Disabled', 1)
end
end
}):AddColorPicker('CrosshairColor', {
Default = Color3.fromRGB(0, 255, 0),
Title = 'Crosshair Color',
Callback = function(Value)
GFS.CrosshairColor = Value
end
})
CrosshairBox:AddSlider('CrosshairSize', {
Text = 'Size',
Default = 12,
Min = 2,
Max = 40,
Rounding = 0,
Compact = true,
Callback = function(Value)
GFS.CrosshairSize = Value
end
})
CrosshairBox:AddSlider('CrosshairGap', {
Text = 'Gap',
Default = 4,
Min = 0,
Max = 20,
Rounding = 0,
Compact = true,
Callback = function(Value)
GFS.CrosshairGap = Value
end
})
CrosshairBox:AddSlider('CrosshairThickness', {
Text = 'Thickness',
Default = 1.5,
Min = 0.5,
Max = 5,
Rounding = 1,
Compact = true,
Callback = function(Value)
GFS.CrosshairThickness = Value
end
})
CrosshairBox:AddCheckbox('CrosshairDot', {
Text = 'Center Dot',
Default = true,
Callback = function(Value)
GFS.CrosshairDot = Value
end
})
CrosshairBox:AddCheckbox('CrosshairOutline', {
Text = 'Outline',
Default = true,
Tooltip = 'Black outline around crosshair lines for visibility',
Callback = function(Value)
GFS.CrosshairOutline = Value
end
})
end
local VDStatsBox = Tabs.Global:AddRightGroupbox('Fun', 'user-star')
VDStatsBox:AddInput('LevelInput', {
Text = 'Set Level',
Default = '',
Placeholder = 'Enter level...',
Numeric = true,
Finished = true,
Tooltip = 'Set your custom level (Client Side)',
Callback = function(Value)
local val = tonumber(Value)
if val then
	LocalPlayer:SetAttribute("Level", val)
	Library:Notify('Level set to ' .. val, 2)
end
end
})
VDStatsBox:AddInput('ScrewsInput', {
Text = 'Set Screws',
Default = '',
Placeholder = 'Enter screws amount...',
Numeric = true,
Finished = true,
Tooltip = 'Set your custom screws (Client Side)',
Callback = function(Value)
local val = tonumber(Value)
if val then
	LocalPlayer:SetAttribute("Screws", val)
	Library:Notify('Screws set to ' .. val, 2)
end
end
})
VDStatsBox:AddInput('GearsInput', {
Text = 'Set Gears',
Default = '',
Placeholder = 'Enter gears amount...',
Numeric = true,
Finished = true,
Tooltip = 'Set your custom gears (Client Side)',
Callback = function(Value)
local val = tonumber(Value)
if val then
	LocalPlayer:SetAttribute("Gears", val)
	Library:Notify('Gears set to ' .. val, 2)
end
end
})
do
	local ToFBox               = Tabs.Survivor:AddRightGroupbox('Silent Aim', 'crosshair')
	GFS.ToF_SilentAim          = false
	GFS.ToF_Target             = "Killer"
	GFS.ToF_AimPart            = "HumanoidRootPart"
	GFS.ToF_FOV                = 30
	GFS.ToF_Prediction         = 0
	GFS.ToF_SnapLine           = false
	GFS.ToF_BulletTracer       = true
	GFS.ToF_TracerColor        = Color3.fromRGB(255, 50, 50)
	GFS.ToF_TargetIndicator    = true
	GFS.ToF_HookInstalled      = false
	local snapLine             = Drawing.new("Line")
	snapLine.Color             = Color3.fromRGB(0, 255, 150)
	snapLine.Thickness         = 1.5
	snapLine.Transparency      = 0.5
	snapLine.Visible           = false
	local targetDot            = Drawing.new("Circle")
	targetDot.Color            = Color3.fromRGB(255, 0, 0)
	targetDot.Thickness        = 2
	targetDot.NumSides         = 24
	targetDot.Radius           = 6
	targetDot.Filled           = true
	targetDot.Transparency     = 0.4
	targetDot.Visible          = false
	local targetOutline        = Drawing.new("Circle")
	targetOutline.Color        = Color3.fromRGB(255, 255, 255)
	targetOutline.Thickness    = 1
	targetOutline.NumSides     = 24
	targetOutline.Radius       = 8
	targetOutline.Filled       = false
	targetOutline.Transparency = 0.5
	targetOutline.Visible      = false
	local tracerLines          = {}
	local TRACER_POOL          = 8
	local TRACER_LIFETIME      = 0.5
	for i = 1, TRACER_POOL do
		local l        = Drawing.new("Line")
		l.Color        = GFS.ToF_TracerColor
		l.Thickness    = 2.5
		l.Transparency = 0
		l.Visible      = false
		tracerLines[i] = {
		line      = l,
		startTime = 0,
	endTime   = 0,
	fromWorld = Vector3.new(0, 0, 0),
	toWorld   = Vector3.new(0, 0, 0),
	active    = false
	}
end
local cam = workspace.CurrentCamera
local function WorldToScreen(pos)
	local c = workspace.CurrentCamera
	if not c then return Vector2.new(0, 0), false, 0 end
	local vec, onScreen = c:WorldToViewportPoint(pos)
	return Vector2.new(vec.X, vec.Y), onScreen, vec.Z
end
local function IsTargetValid(player)
	if not player or player == LocalPlayer then return false end
	if not player.Character then return false end
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	local part = player.Character:FindFirstChild(GFS.ToF_AimPart)
	or player.Character:FindFirstChild("HumanoidRootPart")
	if not part then return false end
	return true
end
local function MatchesTargetFilter(player)
	local filter = GFS.ToF_Target
	if filter == "All" then return true end
	local killer = IsKiller(player)
	if filter == "Killer" and killer then return true end
	if filter == "Survivor" and not killer then return true end
	return false
end
local function GetAimPosition(player)
	if not player.Character then return nil end
	local part = player.Character:FindFirstChild(GFS.ToF_AimPart)
	or player.Character:FindFirstChild("HumanoidRootPart")
	if not part then return nil end
	local pos = part.Position
	if GFS.ToF_Prediction > 0 then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local vel = hrp.AssemblyLinearVelocity or hrp.Velocity
			if vel and vel.Magnitude > 1 then
				pos = pos + vel.Unit * GFS.ToF_Prediction
			end
		end
	end
	return pos
end
local function IsInFOV(worldPos)
	local c           = workspace.CurrentCamera
	local camCF       = c.CFrame
	local dirToTarget = (worldPos - camCF.Position).Unit
	local camForward  = camCF.LookVector
	local dot         = camForward:Dot(dirToTarget)
	local angleDeg    = math.deg(math.acos(math.clamp(dot, -1, 1)))
	return angleDeg <= GFS.ToF_FOV
end
local function GetBestTarget()
	local camPos = workspace.CurrentCamera.CFrame.Position
	local bestPlayer, bestDist = nil, math.huge
	local bestPos = nil
	for _, player in ipairs(Players:GetPlayers()) do
		if IsTargetValid(player) and MatchesTargetFilter(player) then
			local aimPos = GetAimPosition(player)
			if aimPos and IsInFOV(aimPos) then
				local dist = (aimPos - camPos).Magnitude
				if dist < bestDist then
					bestDist   = dist
					bestPlayer = player
					bestPos    = aimPos
				end
			end
		end
	end
	return bestPlayer, bestPos
end
local function SpawnTracer(fromPos, toPos)
	if not GFS.ToF_BulletTracer then return end
	for i = 1, TRACER_POOL do
		local t = tracerLines[i]
		if not t.active then
			local now           = tick()
			t.startTime         = now
			t.endTime           = now + TRACER_LIFETIME
			t.fromWorld         = fromPos
			t.toWorld           = toPos
			t.active            = true
			t.line.Color        = GFS.ToF_TracerColor
			t.line.Thickness    = 2.5
			t.line.Transparency = 1
			t.line.Visible      = true
			break
		end
	end
end
GFS._cachedBestPlayer = nil
GFS._cachedBestPos    = nil
GFS._cachedOrigin     = nil
GFS._tofJustFired     = false
local visualConn      = nil
local function StartVisuals()
	if visualConn then return end
	visualConn = RunService.RenderStepped:Connect(function()
	cam = workspace.CurrentCamera
	local bestPlayer, bestPos = nil, nil
	if GFS.ToF_SilentAim and DetectMyRole() == "Survivor" then
		bestPlayer, bestPos   = GetBestTarget()
		GFS._cachedBestPlayer = bestPlayer
		GFS._cachedBestPos    = bestPos
		local myChar          = LocalPlayer.Character
		local myRoot          = myChar and myChar:FindFirstChild("HumanoidRootPart")
		GFS._cachedOrigin     = myRoot and (myRoot.Position + Vector3.new(0, 1.5, 0)) or nil
	else
		GFS._cachedBestPlayer = nil
		GFS._cachedBestPos    = nil
		GFS._cachedOrigin     = nil
	end
	if GFS._tofJustFired then
		GFS._tofJustFired = false
		if GFS._cachedOrigin and GFS._cachedBestPos then
			SpawnTracer(GFS._cachedOrigin, GFS._cachedBestPos)
		end
	end
	if bestPos and GFS.ToF_TargetIndicator then
		local sp, onScreen = WorldToScreen(bestPos)
		if onScreen then
			targetDot.Position     = sp
			targetDot.Visible      = true
			targetOutline.Position = sp
			targetOutline.Visible  = true
		else
			targetDot.Visible     = false
			targetOutline.Visible = false
		end
	else
		targetDot.Visible     = false
		targetOutline.Visible = false
	end
	if bestPos and GFS.ToF_SnapLine then
		local sp, onScreen = WorldToScreen(bestPos)
		if onScreen then
			snapLine.From    = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
			snapLine.To      = sp
			snapLine.Visible = true
		else
			snapLine.Visible = false
		end
	else
		snapLine.Visible = false
	end
	local now = tick()
	for i = 1, TRACER_POOL do
		local t = tracerLines[i]
		if t.active then
			if now >= t.endTime then
				t.active = false
				t.line.Visible = false
			else
				local progress = (now - t.startTime) / TRACER_LIFETIME
				local sp1, on1 = WorldToScreen(t.fromWorld)
				local sp2, on2 = WorldToScreen(t.toWorld)
				if on1 or on2 then
					t.line.From         = sp1
					t.line.To           = sp2
					t.line.Color        = GFS.ToF_TracerColor
					t.line.Thickness    = math.max(1, 2.5 * (1 - progress * 0.6))
					t.line.Transparency = math.clamp(1 - progress, 0, 1)
					t.line.Visible      = true
				else
					t.line.Visible = false
				end
			end
		end
	end
end)
end
local function StopVisuals()
	if visualConn then
		visualConn:Disconnect(); visualConn = nil
	end
	GFS._cachedBestPlayer = nil
	GFS._cachedBestPos    = nil
	GFS._cachedOrigin     = nil
	GFS._tofJustFired     = false
	snapLine.Visible      = false
	targetDot.Visible     = false
	targetOutline.Visible = false
	for i = 1, TRACER_POOL do
		tracerLines[i].line.Visible = false; tracerLines[i].active = false
	end
end
local oldToFNamecall = nil
local tofFireRemote  = nil
local function GetToFFireRemote()
	if tofFireRemote then return tofFireRemote end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return nil end
	local items = remotes:FindFirstChild("Items")
	if not items then return nil end
	local tof = items:FindFirstChild("Twist of Fate")
	if not tof then return nil end
	local fire = tof:FindFirstChild("Fire")
	if fire then tofFireRemote = fire end
	return tofFireRemote
end
local function InstallSilentAimHook(source)
	if GFS.ToF_HookInstalled then return true end
	local fireRemote = GetToFFireRemote()
	if source == "tof" and not fireRemote then
		Library:Notify("Silent Aim: Twist of Fate remote not found (equip item first!)", 4)
		return false
	end
	if typeof(hookmetamethod) ~= "function" or typeof(getnamecallmethod) ~= "function" then
		Library:Notify("Silent Aim: hookmetamethod not available", 4)
		return false
	end
	local spearRemote = GFS.GetSpearRemote()
	oldToFNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
	local method = getnamecallmethod()
	if method == "FireServer" then
		if not fireRemote then fireRemote = GetToFFireRemote() end
		if GFS.ToF_SilentAim and fireRemote and self == fireRemote then
			local bestPos = GFS._cachedBestPos
			local origin  = GFS._cachedOrigin
			if bestPos and origin then
				GFS._tofJustFired = true
				local dir = (bestPos - origin).Unit
				local args = { ... }
				for i = 1, #args do
					if typeof(args[i]) == "CFrame" then
						args[i] = CFrame.new(bestPos, bestPos + dir)
					elseif typeof(args[i]) == "Vector3" then
						args[i] = dir
					end
				end
				if #args >= 1 then
					return oldToFNamecall(self, unpack(args))
				else
					return oldToFNamecall(self, CFrame.new(bestPos, bestPos + dir))
				end
			end
		end
		if not spearRemote then spearRemote = GFS.GetSpearRemote() end
		if GFS.SpearAimbotEnabled and spearRemote and self == spearRemote then
			local aimDir = GFS._cachedSpearAimDir
			if aimDir then
				local args = { ... }
				if #args >= 2 then
					return oldToFNamecall(self, aimDir, args[2])
				elseif #args >= 1 then
					return oldToFNamecall(self, aimDir)
				end
			end
		end
	end
	return oldToFNamecall(self, ...)
end))
GFS.ToF_HookInstalled = true
GFS.Veil_HookInstalled = true
return true
end
GFS.InstallSilentAimHook = InstallSilentAimHook
local ToF_SilentAimToggle = ToFBox:AddCheckbox('ToF_SilentAim', {
Text     = 'Silent Aim',
Default  = false,
Tooltip  = IsPremium and 'Automatically silent aim at the closest target within FOV',
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.ToF_SilentAim = Value
if Value then
	local myRole = DetectMyRole()
	if myRole ~= "Survivor" then
		Library:Notify('Silent Aim: Waiting for Survivor role...', 3)
	end
	local ok = InstallSilentAimHook("tof")
	if ok then
		StartVisuals()
		Library:Notify('Silent Aim: Enabled', 2)
	else
		GFS.ToF_SilentAim = false
		task.delay(2, function()
		if GetToFFireRemote() then
			Library:Notify("Silent Aim: Remote found! Try enabling again.", 3)
		end
	end)
end
else
	StopVisuals()
	Library:Notify('Silent Aim: Disabled', 2)
end
end
})
local ToF_TargetDropdown = ToFBox:AddDropdown('ToF_TargetMode', {
Text     = 'Target',
Tooltip  = 'Choose who to aim at',
Values   = { "Killer", "Survivor", "All" },
Default  = 1,
Callback = function(Value)
GFS.ToF_Target = Value
end
})
local ToF_AimPartDropdown = ToFBox:AddDropdown('ToF_AimPart', {
Text     = 'Aim Part',
Tooltip  = 'Which body part to aim at',
Values   = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" },
Default  = 2,
Callback = function(Value)
GFS.ToF_AimPart = Value
end
})
local ToF_FOVSlider = ToFBox:AddSlider('ToF_FOVDeg', {
Text     = 'FOV',
Default  = 30,
Min      = 1,
Max      = 180,
Rounding = 0,
Suffix   = '°',
Tooltip  = 'Aim cone in degrees (180 = full hemisphere)',
Callback = function(Value)
GFS.ToF_FOV = Value
end
})
ToFBox:AddDivider()
local ToF_SnapLineToggle = ToFBox:AddCheckbox('ToF_SnapLine', {
Text     = 'Snap Line',
Default  = false,
Tooltip  = 'Draw a line from bottom of screen to the current target',
Callback = function(Value)
GFS.ToF_SnapLine = Value
end
})
local ToF_BulletTracerToggle = ToFBox:AddCheckbox('ToF_BulletTracer', {
Text     = 'Bullet Tracer',
Default  = true,
Tooltip  = 'CS:GO style animated tracer when the bullet is redirected',
Callback = function(Value)
GFS.ToF_BulletTracer = Value
end
}):AddColorPicker('ToF_TracerColor', {
Default  = Color3.fromRGB(255, 50, 50),
Title    = 'Tracer Color',
Callback = function(Value)
GFS.ToF_TracerColor = Value
end
})
local ToF_TargetIndicatorToggle = ToFBox:AddCheckbox('ToF_TargetIndicator', {
Text     = 'Target Indicator',
Default  = true,
Tooltip  = 'Show a red dot on the current aim target',
Callback = function(Value)
GFS.ToF_TargetIndicator = Value
end
})
PremiumOnly(ToF_SilentAimToggle)
PremiumOnly(ToF_TargetDropdown)
PremiumOnly(ToF_AimPartDropdown)
PremiumOnly(ToF_FOVSlider)
PremiumOnly(ToF_SnapLineToggle)
PremiumOnly(ToF_BulletTracerToggle)
PremiumOnly(ToF_TargetIndicatorToggle)
-- Library:Notify("Silent Aim module loaded", 2)
end
end
SafeInit(InitSurvivorScripts, 'InitSurvivorScripts')
SafeInit(InitStreamerMode, 'InitStreamerMode')
SafeInit(function()
if not Tabs or not Tabs.Global then return end
local SpectatorBox = Tabs.Global:AddRightGroupbox('Spectator List', 'eye')
local SpecState = {
Enabled = false,
GUI = nil,
DragInput = nil,
DragStart = nil,
StartPos = nil,
Dragging = false,
Labels = {},
MaxDisplay = 10
}
local function GetSpectators()
	local spectators = {}
	local myUserId = LocalPlayer.UserId
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local isWatchingMe = false
			pcall(function()
			local watchingId = p:GetAttribute("spectatingplayer")
			if watchingId == myUserId then
				isWatchingMe = true
				return
			end
			if watchingId == nil then
				local attr = p:GetAttribute("isspectating")
				if attr == true then
					isWatchingMe = true
					return
				end
				local team = p.Team
				if team then
					local tn = team.Name:lower()
					if tn:find("dead") or tn:find("died")
					or tn:find("spectator") or tn:find("spectate") then
						isWatchingMe = true
						return
					end
				end
			end
		end)
		if isWatchingMe then
			table.insert(spectators, p)
		end
	end
end
return spectators
end
SpectatorBox:AddToggle('SpectatorListToggle', {
Text = 'Spectator List',
Default = false,
Tooltip = 'Shows players who are currently spectating YOU specifically (uses spectatingplayer attribute)',
Callback = function(Value)
SpecState.Enabled = Value
if Value then
	if not SpecState.GUI then
		local ScreenGui = Instance.new("ScreenGui")
		ScreenGui.Name = "StarshipSpectatorList"
		ScreenGui.Parent = game:GetService("CoreGui")
		ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		local Scheme = {
		MainColor = Color3.fromRGB(25, 25, 25),
		BackgroundColor = Color3.fromRGB(15, 15, 15),
		OutlineColor = Color3.fromRGB(40, 40, 40),
		AccentColor = Color3.fromRGB(125, 85, 255),
		FontColor = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.Code
		}
		if Library and Library.Scheme then
			if Library.Scheme.MainColor then Scheme.MainColor = Library.Scheme.MainColor end
			if Library.Scheme.BackgroundColor then Scheme.BackgroundColor = Library.Scheme.BackgroundColor end
			if Library.Scheme.OutlineColor then Scheme.OutlineColor = Library.Scheme.OutlineColor end
			if Library.Scheme.AccentColor then Scheme.AccentColor = Library.Scheme.AccentColor end
			if Library.Scheme.FontColor then Scheme.FontColor = Library.Scheme.FontColor end
		end
		local MainFrame = Instance.new("Frame")
		MainFrame.Name = "MainFrame"
		MainFrame.Parent = ScreenGui
		MainFrame.BackgroundColor3 = Scheme.MainColor
		MainFrame.BorderColor3 = Scheme.OutlineColor
		MainFrame.BorderSizePixel = 1
		MainFrame.Position = UDim2.new(0.05, 0, 0.35, 0)
		MainFrame.Size = UDim2.new(0, 210, 0, 30)
		MainFrame.Active = true
		MainFrame.ClipsDescendants = true
		local TitleBar = Instance.new("Frame")
		TitleBar.Name = "TitleBar"
		TitleBar.Parent = MainFrame
		TitleBar.BackgroundColor3 = Scheme.MainColor
		TitleBar.BorderSizePixel = 0
		TitleBar.Size = UDim2.new(1, 0, 0, 20)
		TitleBar.ZIndex = 2
		local AccentStrip = Instance.new("Frame")
		AccentStrip.Name = "AccentStrip"
		AccentStrip.Parent = TitleBar
		AccentStrip.BackgroundColor3 = Scheme.AccentColor
		AccentStrip.BorderSizePixel = 0
		AccentStrip.Size = UDim2.new(1, 0, 0, 1)
		AccentStrip.ZIndex = 3
		task.spawn(function()
		if Library.Registry then
			table.insert(Library.Registry, AccentStrip)
			if Options.AccentColor then
				Options.AccentColor:OnChanged(function()
				AccentStrip.BackgroundColor3 = Options.AccentColor.Value
			end)
		end
	end
end)
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = TitleBar
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 6, 0, 0)
Title.Size = UDim2.new(1, -12, 1, 0)
Title.Font = Scheme.Font
Title.Text = "Spectator [0]"
Title.TextColor3 = Scheme.FontColor
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 4
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Parent = MainFrame
Content.BackgroundColor3 = Scheme.BackgroundColor
Content.BorderColor3 = Scheme.OutlineColor
Content.BorderSizePixel = 1
Content.Position = UDim2.new(0, 6, 0, 26)
Content.Size = UDim2.new(1, -12, 0, 0)
Content.ZIndex = 2
Content.ClipsDescendants = true
local ListLayout = Instance.new("UIListLayout")
ListLayout.Parent = Content
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 0)
local EmptyLabel = Instance.new("TextLabel")
EmptyLabel.Name = "EmptyLabel"
EmptyLabel.Parent = Content
EmptyLabel.BackgroundTransparency = 1
EmptyLabel.Size = UDim2.new(1, 0, 0, 18)
EmptyLabel.Font = Scheme.Font
EmptyLabel.Text = "  No spectators"
EmptyLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
EmptyLabel.TextSize = 12
EmptyLabel.TextXAlignment = Enum.TextXAlignment.Left
EmptyLabel.ZIndex = 3
EmptyLabel.LayoutOrder = 999
SpecState.GUI = ScreenGui
local function updateInput(input)
	local delta = input.Position - SpecState.DragStart
	MainFrame.Position = UDim2.new(SpecState.StartPos.X.Scale, SpecState.StartPos.X.Offset + delta.X,
	SpecState.StartPos.Y.Scale, SpecState.StartPos.Y.Offset + delta.Y)
end
TitleBar.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
	SpecState.Dragging = true
	SpecState.DragStart = input.Position
	SpecState.StartPos = MainFrame.Position
	input.Changed:Connect(function()
	if input.UserInputState == Enum.UserInputState.End then
		SpecState.Dragging = false
	end
end)
end
end)
TitleBar.InputChanged:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
	SpecState.DragInput = input
end
end)
game:GetService("UserInputService").InputChanged:Connect(function(input)
if input == SpecState.DragInput and SpecState.Dragging then
	updateInput(input)
end
end)
end
SpecState.GUI.Enabled = true
else
	if SpecState.GUI then
		SpecState.GUI.Enabled = false
	end
end
end
}):AddKeyPicker('SpectatorListKey', {
Default = 'None',
Text = 'Spectator List',
Mode = 'Toggle',
SyncToggleState = true
})
task.spawn(function()
local Scheme = { Font = Enum.Font.Code, FontColor = Color3.fromRGB(255, 255, 255) }
if Library and Library.Scheme then
	if Library.Scheme.FontColor then Scheme.FontColor = Library.Scheme.FontColor end
end
while _G.StarshipActive and task.wait(1) do
	if SpecState.Enabled and SpecState.GUI and SpecState.GUI.Enabled then
		pcall(function()
		local spectators = GetSpectators()
		local mf = SpecState.GUI:FindFirstChild("MainFrame")
		if not mf then return end
		local ct = mf:FindFirstChild("Content")
		local titleLabel = mf:FindFirstChild("TitleBar") and mf.TitleBar:FindFirstChild("Title")
		if not ct then return end
		if titleLabel then
			titleLabel.Text = "Spectator [" .. #spectators .. "]"
		end
		for _, label in pairs(SpecState.Labels) do
			if label and label.Parent then label:Destroy() end
		end
		SpecState.Labels = {}
		local emptyLabel = ct:FindFirstChild("EmptyLabel")
		if #spectators == 0 then
			if emptyLabel then emptyLabel.Visible = true end
			ct.Size = UDim2.new(1, -12, 0, 18)
			mf.Size = UDim2.new(0, 210, 0, 30 + 24)
		else
			if emptyLabel then emptyLabel.Visible = false end
			local count = math.min(#spectators, SpecState.MaxDisplay)
			for i = 1, count do
				local p = spectators[i]
				local nameLabel = Instance.new("TextLabel")
				nameLabel.Name = "Spec_" .. i
				nameLabel.Parent = ct
				nameLabel.BackgroundTransparency = (i % 2 == 0) and 0.92 or 1
				nameLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
				nameLabel.Size = UDim2.new(1, 0, 0, 18)
				nameLabel.Font = Scheme.Font
				local displayName = (_G.HideUsernameEnabled and "Starship") or p.DisplayName
				nameLabel.Text = "  " .. displayName
				nameLabel.TextColor3 = Scheme.FontColor
				nameLabel.TextSize = 12
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
				nameLabel.ZIndex = 3
				nameLabel.LayoutOrder = i
				table.insert(SpecState.Labels, nameLabel)
			end
			if #spectators > SpecState.MaxDisplay then
				local moreLabel = Instance.new("TextLabel")
				moreLabel.Name = "Spec_More"
				moreLabel.Parent = ct
				moreLabel.BackgroundTransparency = 1
				moreLabel.Size = UDim2.new(1, 0, 0, 18)
				moreLabel.Font = Scheme.Font
				moreLabel.Text = "  +" .. (#spectators - SpecState.MaxDisplay) .. " more..."
				moreLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
				moreLabel.TextSize = 12
				moreLabel.TextXAlignment = Enum.TextXAlignment.Left
				moreLabel.ZIndex = 3
				moreLabel.LayoutOrder = SpecState.MaxDisplay + 1
				table.insert(SpecState.Labels, moreLabel)
				count = count + 1
			end
			local contentH = count * 18
			ct.Size = UDim2.new(1, -12, 0, contentH)
			mf.Size = UDim2.new(0, 210, 0, 30 + contentH + 6)
		end
	end)
end
end
end)
Library:OnUnload(function()
if SpecState.GUI then
	pcall(function() SpecState.GUI:Destroy() end)
	SpecState.GUI = nil
end
end)
end, 'InitSpectatorList')
SafeInit(function()
if not Tabs or not Tabs.Survivor then return end
local PalletBox = Tabs.Survivor:AddRightGroupbox('Auto Pallet (Beta)', 'swatch-book')
local DROP_KILLER_RANGE  = 14
local DROP_SURVIVOR_RANGE = 15
local DROP_COOLDOWN       = 5
local SCAN_INTERVAL       = 2
local TICK_INTERVAL       = 0.1
local PalletDropRemote = nil
pcall(function()
PalletDropRemote = game:GetService("ReplicatedStorage").Remotes.Pallet.PalletDropEvent
end)
local _droppedPallets = {}
local _cachedPallets = {}
local _lastPalletScan = 0
pcall(function()
local Remotes = game:GetService("ReplicatedStorage").Remotes
local dropAnim = Remotes.Pallet:FindFirstChild("PalletDropAnim")
if dropAnim then
	dropAnim.OnClientEvent:Connect(function()
	_lastPalletScan = 0
end)
end
local destroyGlobal = Remotes.Pallet:FindFirstChild("Jason")
and Remotes.Pallet.Jason:FindFirstChild("Destroy-Global")
if destroyGlobal then
	destroyGlobal.OnClientEvent:Connect(function()
	_lastPalletScan = 0
end)
end
local stunRemote = Remotes.Pallet:FindFirstChild("Jason")
and Remotes.Pallet.Jason:FindFirstChild("Stun")
if stunRemote then
	stunRemote.OnClientEvent:Connect(function()
	_lastPalletScan = 0
end)
end
local slideComplete = Remotes.Pallet:FindFirstChild("PalletSlideCompleteEvent")
if slideComplete then
	slideComplete.OnClientEvent:Connect(function()
	_lastPalletScan = 0
end)
end
end)
local function IsPalletDroppedOrBroken(obj)
	if not obj or not obj.Parent then return true end
	if _droppedPallets[obj] then return true end
	local minY, maxY = math.huge, -math.huge
	local partCount = 0
	local anyVisible = false
	for _, child in ipairs(obj:GetChildren()) do
		if child:IsA("BasePart") then
			local n = child.Name
			if n ~= "PalletPointSlide" and n ~= "PalletPoint" then
				local y = child.Position.Y
				if y < minY then minY = y end
				if y > maxY then maxY = y end
				partCount = partCount + 1
				if child.Transparency < 0.8 and n ~= "inviswall" then
					anyVisible = true
				end
			end
		end
	end
	if partCount > 0 and not anyVisible then
		_droppedPallets[obj] = true
		return true
	end
	if partCount >= 2 and (maxY - minY) < 1.5 then
		_droppedPallets[obj] = true
		return true
	end
	local ok2, hasAttr = pcall(function()
	local a = obj.GetAttribute
	return a(obj, "PalletDropped") or a(obj, "Dropped") or a(obj, "IsDropped")
	or a(obj, "IsBroken") or a(obj, "Fallen") or a(obj, "Broken")
	or a(obj, "destroyed") or a(obj, "Destroyed")
end)
if ok2 and hasAttr then
	_droppedPallets[obj] = true
	return true
end
for _, child in ipairs(obj:GetChildren()) do
	if child:IsA("BoolValue") then
		local cn = child.Name
		if (cn == "Dropped" or cn == "PalletDropped" or cn == "IsBroken"
		or cn == "Broken" or cn == "Fallen") and child.Value then
			_droppedPallets[obj] = true
			return true
		end
	end
end
return false
end
local function GetCachedPallets()
	local now = os.clock()
	if now - _lastPalletScan < SCAN_INTERVAL then return _cachedPallets end
	_lastPalletScan = now
	local list = {}
	local map = workspace:FindFirstChild("Map")
	if map then
		local ok, descs = pcall(function() return map:GetDescendants() end)
		if ok then
			for _, obj in ipairs(descs) do
				if obj:IsA("Model") then
					local nl = obj.Name:lower()
					if nl == "pallet" or nl == "palletright"
					or nl == "palletwrong" or nl == "palletup" then
						if not IsPalletDroppedOrBroken(obj) then
							local pp = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
							if pp then
								table.insert(list, {model = obj, part = pp})
							end
						end
					end
				end
			end
		end
	end
	_cachedPallets = list
	return list
end
local function GetKillerCharacter()
	local ok, tagged = pcall(function()
	return game:GetService("CollectionService"):GetTagged("Killer")
end)
if ok and tagged then
	for _, char in ipairs(tagged) do
		if typeof(char) == "Instance" and char:IsA("Model") and char.Parent == workspace then
			return char
		end
	end
end
for _, p in ipairs(Players:GetPlayers()) do
	if p ~= LocalPlayer and p.Team then
		local tn = p.Team.Name:lower()
		if tn:find("killer") then return p.Character end
	end
end
return nil
end
local _cachedKillerChar = nil
local _killerCacheTime  = 0
local KILLER_CACHE_INTERVAL = 0.5
local function GetKillerCharacterCached()
	local now = os.clock()
	if _cachedKillerChar and (now - _killerCacheTime) < KILLER_CACHE_INTERVAL then
		if _cachedKillerChar.Parent then
			return _cachedKillerChar
		end
	end
	_cachedKillerChar = GetKillerCharacter()
	_killerCacheTime  = now
	return _cachedKillerChar
end
local _autoDropRunning = false
local function StartAutoDropLoop()
	if _autoDropRunning then return end
	_autoDropRunning = true
	task.spawn(function()
	while _autoDropRunning and GFS.AutoDropPalletEnabled do
		task.wait(TICK_INTERVAL)
		repeat
			local char = LocalPlayer.Character
			if not char then break end
			local myHRP = char:FindFirstChild("HumanoidRootPart")
			if not myHRP then break end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health <= 0 then break end
			if char:GetAttribute("IsHooked") or char:GetAttribute("IsCarried") then break end
			local now = os.clock()
			if now - GFS.AutoDropPalletLastFire < DROP_COOLDOWN then break end
			local killerChar = GetKillerCharacterCached()
			if not killerChar then break end
			local killerHRP = killerChar:FindFirstChild("HumanoidRootPart")
			if not killerHRP then break end
			local myPos    = myHRP.Position
			local killerPos = killerHRP.Position
			local bestEntry, bestDist = nil, DROP_SURVIVOR_RANGE
			for _, entry in ipairs(GetCachedPallets()) do
				local pp = entry.part
				if pp and pp.Parent then
					local d = (pp.Position - myPos).Magnitude
					if d < bestDist then
						bestEntry = entry
						bestDist  = d
					end
				end
			end
			if not bestEntry then break end
			if IsPalletDroppedOrBroken(bestEntry.model) then break end
			local palletPos = bestEntry.part.Position
			if (killerPos - palletPos).Magnitude > DROP_KILLER_RANGE then break end
			local mode = GFS.AutoDropPalletMode or "Opposite Side"
			if mode == "Opposite Side" then
				local fromPalletToMe     = (myPos - palletPos)
				local fromPalletToKiller = (killerPos - palletPos)
				if fromPalletToMe.Magnitude > 0.1 and fromPalletToKiller.Magnitude > 0.1 then
					local dot = fromPalletToMe.Unit:Dot(fromPalletToKiller.Unit)
					if dot > -0.2 then break end
				end
			end
			GFS.AutoDropPalletLastFire = now
			local palletArg = nil
			do
				local closestDist = math.huge
				for _, child in ipairs(bestEntry.model:GetChildren()) do
					if child.Name == "PalletPointSlide" or child.Name == "PalletPoint" then
						local childPos
						if child:IsA("BasePart") or child:IsA("MeshPart") or child:IsA("UnionOperation") then
							childPos = child.Position
						elseif child:IsA("Attachment") then
							childPos = child.WorldPosition
						elseif child:IsA("Model") then
							local pp2 = child.PrimaryPart or child:FindFirstChildOfClass("BasePart")
							if pp2 then childPos = pp2.Position end
						end
						if childPos then
							local d = (childPos - myPos).Magnitude
							if d < closestDist then
								closestDist = d
								palletArg = child
							end
						end
					end
				end
				if not palletArg then
					palletArg = bestEntry.model:FindFirstChild("PalletPointSlide")
					or bestEntry.model.PrimaryPart
					or bestEntry.model
				end
			end
			local _ = palletArg
			_droppedPallets[bestEntry.model] = true
			pcall(function()
			if not PalletDropRemote then
				PalletDropRemote = game:GetService("ReplicatedStorage").Remotes.Pallet.PalletDropEvent
			end
			PalletDropRemote:FireServer(palletArg)
		end)
		if IsMobile then
			task.spawn(function()
			pressSpecialButton("action")
		end)
	else
		if VIM then
			pcall(function()
			VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
			task.defer(function()
			VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
		end)
	end)
end
end
_lastPalletScan = 0
Library:Notify("Pallet dropped!", 1.5)
until true
end
_autoDropRunning = false
end)
end
local function StopAutoDropLoop()
	_autoDropRunning = false
	GFS.AutoDropPalletEnabled = false
end
PalletBox:AddCheckbox('AutoDropPallet', {
Text = 'Auto Drop Pallet',
Default = false,
Tooltip = 'Drops nearest standing pallet when the killer enters stun range (experimental beta)',
Callback = function(Value)
GFS.AutoDropPalletEnabled = Value
if Value then
	if not PalletDropRemote then
		pcall(function()
		PalletDropRemote = game:GetService("ReplicatedStorage").Remotes.Pallet.PalletDropEvent
	end)
end
StartAutoDropLoop()
Library:Notify("Auto Drop Pallet ON (" .. (GFS.AutoDropPalletMode or "Opposite Side") .. ")", 2)
else
	StopAutoDropLoop()
	Library:Notify("Auto Drop Pallet OFF", 1)
end
end
})
PalletBox:AddDropdown('AutoDropPalletMode', {
Text = 'Drop Mode',
Tooltip = 'Opposite Side = only drop when you and killer are on different sides of the pallet.\nAny Direction = drop whenever killer is near the pallet regardless of position.',
Values = { "Opposite Side", "Any Direction" },
Default = 1,
Callback = function(Value)
GFS.AutoDropPalletMode = Value
if GFS.AutoDropPalletEnabled then
	Library:Notify("Pallet mode: " .. Value, 1.5)
end
end
})
Library:OnUnload(function()
StopAutoDropLoop()
end)
end, 'InitAutoDropPallet')
SafeInit(function()
if not Tabs or not Tabs.Global then return end
local CutsceneBox = Tabs.Global:AddRightGroupbox('Cutscene', 'film')
local skipConn = nil
local skipBindConn = nil
local function EnableSkipCutscene()
	pcall(function()
	local be = game:GetService("ReplicatedStorage").Remotes.Game:WaitForChild("cutscene", 5)
	if be and be:IsA("BindableEvent") then
		skipBindConn = be.Event:Connect(function()
		task.defer(function()
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end)
end)
end
end)
skipConn = RunService.Heartbeat:Connect(function()
if not GFS.SkipCutsceneEnabled then return end
if workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end
end)
end
local function DisableSkipCutscene()
	if skipConn then skipConn:Disconnect(); skipConn = nil end
	if skipBindConn then skipBindConn:Disconnect(); skipBindConn = nil end
end
CutsceneBox:AddToggle('SkipCutscene', {
Text = 'Skip Cutscene',
Default = false,
Tooltip = 'Instantly restores camera when any cutscene tries to lock it. Works for round-start pans and end-game mori cutscenes.',
Callback = function(Value)
GFS.SkipCutsceneEnabled = Value
if Value then
	EnableSkipCutscene()
	Library:Notify('Skip Cutscene: ON', 2)
else
	DisableSkipCutscene()
	Library:Notify('Skip Cutscene: OFF', 1)
end
end
})
Library:OnUnload(function()
DisableSkipCutscene()
GFS.SkipCutsceneEnabled = false
end)
end, 'InitSkipCutscene')
SafeInit(InitKillerAlertScope, 'InitKillerAlertScope')
InitInvisibleScope = function()
end
SafeInit(InitInvisibleScope, 'InitInvisibleScope')
Init.TeleportTab = function()
local TPGeneratorBox = Tabs.AutoTP:AddLeftGroupbox('Generator Teleport', 'settings')
TPGeneratorBox:AddButton({
Text = 'Nearest',
Tooltip = 'Teleport to the closest generator',
Func = function()
local gens = CollectGenerators()
if #gens == 0 then
	Library:Notify('No generators found!', 2)
	return
end
local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
if not myHRP then return end
local nearest = nil
local nearestDist = math.huge
for _, gen in ipairs(gens) do
	local pos = gen:IsA("Model") and
	(gen.PrimaryPart and gen.PrimaryPart.Position or gen:FindFirstChildWhichIsA("BasePart").Position) or
	gen.Position
	local dist = (myHRP.Position - pos).Magnitude
	if dist < nearestDist then
		nearest = gen
		nearestDist = dist
	end
end
if nearest then
	local pos = nearest:IsA("Model") and
	(nearest.PrimaryPart and nearest.PrimaryPart.Position or nearest:FindFirstChildWhichIsA("BasePart").Position) or
	nearest.Position
	myHRP.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
	Library:Notify('Teleported to nearest generator! (' .. math.floor(nearestDist) .. ' studs)', 2)
end
end
}):AddButton({
Text = 'Random',
Tooltip = 'Teleport to a random generator',
Func = function()
TeleportToRandomGenerator()
end
})
local TPGen = TPGeneratorBox:AddToggle('TPGeneratorKey', {
Text = 'TP Generator Keybind',
Default = false,
Tooltip = 'Press G to teleport to random generator',
Callback = function(Value)
VDSettings.TPGeneratorEnabled = Value
end
}):AddKeyPicker('TPGeneratorKeyPicker', {
Default = 'None',
Text = 'TP Generator',
Mode = 'Hold',
Callback = function(isPressed)
if isPressed and VDSettings.TPGeneratorEnabled then
	TeleportToRandomGenerator()
end
end
})
PremiumOnly(TPGen)
local TPHookBox = Tabs.AutoTP:AddRightGroupbox('Hook Teleport', 'anchor')
TPHookBox:AddButton({
Text = 'Nearest',
Tooltip = 'Teleport to the closest hook',
Func = function()
local hooks = CollectHooks()
if #hooks == 0 then
	Library:Notify('No hooks found!', 2)
	return
end
local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
if not myHRP then return end
local nearest = nil
local nearestDist = math.huge
for _, hook in ipairs(hooks) do
	local pos = hook:IsA("Model") and
	(hook.PrimaryPart and hook.PrimaryPart.Position or hook:FindFirstChildWhichIsA("BasePart").Position) or
	hook.Position
	local dist = (myHRP.Position - pos).Magnitude
	if dist < nearestDist then
		nearest = hook
		nearestDist = dist
	end
end
if nearest then
	local pos = nearest:IsA("Model") and
	(nearest.PrimaryPart and nearest.PrimaryPart.Position or nearest:FindFirstChildWhichIsA("BasePart").Position) or
	nearest.Position
	myHRP.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
	Library:Notify('Teleported to nearest hook! (' .. math.floor(nearestDist) .. ' studs)', 2)
end
end
}):AddButton({
Text = 'Random',
Tooltip = 'Teleport to a random hook',
Func = function()
TeleportToRandomHook()
end
})
local TPPlayerBox = Tabs.PlayerTP:AddLeftGroupbox('Quick Teleport', 'user')
TPPlayerBox:AddButton({
Text = 'Hooked Player',
Tooltip = 'Teleport to a player who is currently hooked',
Func = function()
local found = false
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer and player.Character then
		local status = VDSettings.PlayerStatuses[player]
		if status == "Hooked" then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
					LocalPlayer.Character.HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(0, 0, 5)
					Library:Notify('Teleported to Hooked Player: ' .. player.Name, 2)
					found = true
					break
				end
			end
		end
	end
end
if not found then
	Library:Notify('No Hooked players found!', 2)
end
end
}):AddButton({
Text = 'Carried Player',
Tooltip = 'Teleport to a player who is being carried',
Func = function()
local found = false
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer and player.Character then
		local status = VDSettings.PlayerStatuses[player]
		if status == "Carried" then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
					LocalPlayer.Character.HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(0, 0, 5)
					Library:Notify('Teleported to Carried Player: ' .. player.Name, 2)
					found = true
					break
				end
			end
		end
	end
end
if not found then
	Library:Notify('No Carried players found!', 2)
end
end
})
TPPlayerBox:AddButton({
Text = 'Injured/Knocked',
Tooltip = 'Teleport to nearest injured or knocked player',
Func = function()
local nearest = nil
local nearestDist = math.huge
local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
if not myHRP then return end
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer and player.Character then
		local status = VDSettings.PlayerStatuses[player]
		if status == "Injured" or status == "Knocked" then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dist = (myHRP.Position - hrp.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearest = player
				end
			end
		end
	end
end
if nearest and nearest.Character then
	local hrp = nearest.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		myHRP.CFrame = hrp.CFrame * CFrame.new(0, 0, 3)
		Library:Notify('Teleported to ' .. nearest.Name, 2)
	end
else
	Library:Notify('No Injured/Knocked players found!', 2)
end
end
}):AddButton({
Text = 'Killer',
Tooltip = 'Teleport to the Killer',
Func = function()
local killer = nil
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer and IsKiller(player) then
		killer = player
		break
	end
end
if killer and killer.Character then
	local hrp = killer.Character:FindFirstChild("HumanoidRootPart")
	if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
		local killerCF = hrp.CFrame
		local behindPos = killerCF * CFrame.new(
		math.random(-3, 3),
		-5,
		-12
		)
		LocalPlayer.Character.HumanoidRootPart.CFrame = behindPos
		Library:Notify('Teleported behind Killer: ' .. killer.Name, 2)
	end
else
	Library:Notify('No Killer found!', 2)
end
end
})
TPHookBox:AddToggle('TPHookKey', {
Text = 'TP Hook Keybind',
Default = false,
Tooltip = 'Press H to teleport to random hook',
Callback = function(Value)
VDSettings.TPHookEnabled = Value
end
}):AddKeyPicker('TPHookKeyPicker', {
Default = 'None',
Text = 'TP Hook',
Mode = 'Hold',
Callback = function(isPressed)
if isPressed and VDSettings.TPHookEnabled then
	TeleportToRandomHook()
end
end
})
local function InitTPPlayerBox()
	local TPPlayerBox = Tabs.PlayerTP:AddRightGroupbox('Player TP & Interaction', 'users')
	local TPState = {
	tpTargetPlayer = nil,
	spectating = false,
	originalCameraSubject = nil,
	block = { enabled = false, connection = nil },
	orbit = { enabled = false, connection = nil, angle = 0 }
	}
	TPPlayerBox:AddDropdown('TPPlayerDropdown', {
	Values = {},
	Default = 1,
	Multi = false,
	Text = 'Select Player',
	Tooltip = 'Choose a player to teleport to',
	Callback = function(Value)
	if Value == nil or Value == '' then return end
	TPState.tpTargetPlayer = Players:FindFirstChild(Value)
	if TPState.tpTargetPlayer then
		Library:Notify('Target: ' .. TPState.tpTargetPlayer.Name, 2)
	end
end
})
TPPlayerBox:AddButton({
Text = 'Refresh',
Tooltip = 'Update the player dropdown',
Func = function()
local playerNames = {}
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then
		table.insert(playerNames, player.Name)
	end
end
if Options.TPPlayerDropdown then
	Options.TPPlayerDropdown:SetValues(playerNames)
	Library:Notify('Player list refreshed! (' .. #playerNames .. ' players)', 2)
end
end
}):AddButton({
Text = 'Player',
Tooltip = 'Teleport directly to the selected player',
Func = function()
if not TPState.tpTargetPlayer then
	Library:Notify('No player selected!', 2)
	return
end
local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
if not myHRP then return end
if TPState.tpTargetPlayer.Character then
	local targetHRP = TPState.tpTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if targetHRP then
		myHRP.CFrame = CFrame.new(targetHRP.Position + Vector3.new(0, 3, 3))
		Library:Notify('Teleported to ' .. TPState.tpTargetPlayer.Name, 2)
	else
		Library:Notify('Target has no HumanoidRootPart!', 2)
	end
else
	Library:Notify('Target has no character!', 2)
end
end
})
TPPlayerBox:AddButton({
Text = 'TP Behind Player',
Tooltip = 'Teleport behind the selected player (stealth)',
Func = function()
if not TPState.tpTargetPlayer then
	Library:Notify('No player selected!', 2)
	return
end
local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
if not myHRP then return end
if TPState.tpTargetPlayer.Character then
	local targetHRP = TPState.tpTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if targetHRP then
		local behindOffset = targetHRP.CFrame.LookVector * -5
		myHRP.CFrame = CFrame.new(targetHRP.Position + behindOffset)
		Library:Notify('Teleported behind ' .. TPState.tpTargetPlayer.Name, 2)
	end
end
end
})
TPPlayerBox:AddDivider()
TPPlayerBox:AddToggle('BlockPlayerToggle', {
Text = 'Block Player (Stick)',
Default = false,
Tooltip = 'Your character sticks to the selected player',
Callback = function(Value)
TPState.block.enabled = Value
if Value then
	if not TPState.tpTargetPlayer then
		Library:Notify('Select a player first!', 2)
		if Toggles.BlockPlayerToggle then
			Toggles.BlockPlayerToggle:SetValue(false)
		end
		return
	end
	local blockDist = Options.BlockDistance and Options.BlockDistance.Value or 2
	TPState.block.connection = RunService.Heartbeat:Connect(function()
	if not TPState.block.enabled then return end
	if not LocalPlayer.Character then return end
	if not TPState.tpTargetPlayer or not TPState.tpTargetPlayer.Character then return end
	local myHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local targetHRP = TPState.tpTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if myHRP and targetHRP then
		local frontOffset = targetHRP.CFrame.LookVector * blockDist
		myHRP.CFrame = CFrame.new(targetHRP.Position + frontOffset)
	end
end)
Library:Notify('Blocking ' .. TPState.tpTargetPlayer.Name .. '!', 2)
else
	if TPState.block.connection then
		TPState.block.connection:Disconnect()
		TPState.block.connection = nil
	end
	Library:Notify('Block Player: Disabled', 2)
end
end
})
TPPlayerBox:AddSlider('BlockDistance', {
Text = 'Block Distance',
Default = 2,
Min = 0,
Max = 5,
Rounding = 1,
Suffix = ' studs'
})
TPPlayerBox:AddToggle('OrbitPlayerToggle', {
Text = 'Orbit Player',
Default = false,
Tooltip = 'Circle around the selected player',
Callback = function(Value)
TPState.orbit.enabled = Value
if Value then
	if not TPState.tpTargetPlayer then
		Library:Notify('Select a player first!', 2)
		if Toggles.OrbitPlayerToggle then
			Toggles.OrbitPlayerToggle:SetValue(false)
		end
		return
	end
	TPState.orbit.angle = 0
	TPState.orbit.connection = RunService.Heartbeat:Connect(function()
	if not TPState.orbit.enabled then return end
	if not LocalPlayer.Character then return end
	if not TPState.tpTargetPlayer or not TPState.tpTargetPlayer.Character then return end
	local myHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local targetHRP = TPState.tpTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if myHRP and targetHRP then
		local radius = Options.OrbitRadius and Options.OrbitRadius.Value or 8
		local speed = Options.OrbitSpeed and Options.OrbitSpeed.Value or 2
		TPState.orbit.angle = TPState.orbit.angle + (speed * 0.02)
		local x = math.cos(TPState.orbit.angle) * radius
		local z = math.sin(TPState.orbit.angle) * radius
		myHRP.CFrame = CFrame.new(targetHRP.Position + Vector3.new(x, 0, z))
	end
end)
Library:Notify('Orbiting ' .. TPState.tpTargetPlayer.Name, 2)
else
	if TPState.orbit.connection then
		TPState.orbit.connection:Disconnect()
		TPState.orbit.connection = nil
	end
	Library:Notify('Orbit: Disabled', 2)
end
end
})
TPPlayerBox:AddSlider('OrbitRadius', {
Text = 'Orbit Radius',
Default = 8,
Min = 3,
Max = 20,
Rounding = 0,
Suffix = ' studs'
})
TPPlayerBox:AddSlider('OrbitSpeed', {
Text = 'Orbit Speed',
Default = 2,
Min = 1,
Max = 10,
Rounding = 1
})
TPPlayerBox:AddToggle('SpectateToggle', {
Text = 'Spectate Player',
Default = false,
Tooltip = 'Follow player with camera',
Callback = function(Value)
TPState.spectating = Value
if Value then
	if not TPState.tpTargetPlayer then
		Library:Notify('Select a player first!', 2)
		if Toggles.SpectateToggle then
			Toggles.SpectateToggle:SetValue(false)
		end
		return
	end
	if TPState.tpTargetPlayer.Character and TPState.tpTargetPlayer.Character:FindFirstChild('Humanoid') then
		TPState.originalCameraSubject = workspace.CurrentCamera and
		workspace.CurrentCamera.CameraSubject
		if workspace.CurrentCamera then
			workspace.CurrentCamera.CameraSubject = TPState.tpTargetPlayer.Character:FindFirstChild(
			'Humanoid')
		end
		Library:Notify('Spectating ' .. TPState.tpTargetPlayer.Name, 2)
	else
		Library:Notify('Target has no humanoid to spectate!', 2)
		if Toggles.SpectateToggle then Toggles.SpectateToggle:SetValue(false) end
	end
else
	if workspace.CurrentCamera then
		workspace.CurrentCamera.CameraSubject = TPState.originalCameraSubject
	end
	Library:Notify('Spectate: Disabled', 2)
end
end
})
end
SafeInit(InitTPPlayerBox, 'InitTPPlayerBox')
end
SafeInit(Init.TeleportTab, 'InitTeleportTab')
Init.VisualTab = function()
local function CollectPalletsFixed()
	local list = {}
	local map = workspace:FindFirstChild("Map")
	local allowedNames = {
	["pallet"] = true,
	["palletwrong"] = true,
	["palletright"] = true,
	["palletdown"] = true,
	["palletup"] = true
	}
	if map then
		for _, v in ipairs(map:GetDescendants()) do
			if v:IsA("Model") and allowedNames[v.Name:lower()] then
				table.insert(list, v)
			end
		end
	end
	return list
end
local function CollectVaultsFixed()
	local list = {}
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, v in ipairs(map:GetDescendants()) do
			if v:IsA("Model") and v.Name == "Window" then
				if v:FindFirstChild("Bottom") then
					table.insert(list, v)
				end
			end
		end
	end
	return list
end
local ChamsLoopRunning = false
local function StartChamsLoop()
	if ChamsLoopRunning then return end
	ChamsLoopRunning = true
	task.spawn(function()
	while ChamsLoopRunning and Toggles.ChamsESP.Value do
		if VDSettings.ShowVaults then
			local vaults = CollectVaultsFixed()
			for _, v in ipairs(vaults) do
				if v:FindFirstChild("Bottom") then
					v.Bottom.Transparency = 0
					if not (VDESPObjects.Vaults and VDESPObjects.Vaults[v]) then
						CreateObjectESP(v, "Vault", VDSettings.VaultColor)
					end
				end
			end
		end
		if VDSettings.ShowPallets then
			local pallets = CollectPalletsFixed()
			for _, p in ipairs(pallets) do
				if not (VDESPObjects.Pallets and VDESPObjects.Pallets[p]) then
					CreateObjectESP(p, "Pallet", VDSettings.PalletColor)
				end
			end
		end
		task.wait(1.5)
	end
	ChamsLoopRunning = false
end)
end
local ESPTab = Tabs.ESP:AddLeftGroupbox('Player Tracking', 'eye')
local ObjectESPBox = Tabs.ESP:AddRightGroupbox('Object Tracking', 'box')
local ChamsTab = Tabs.Chams:AddLeftGroupbox('Player Chams', 'users')
local ObjectChamsBox = Tabs.Chams:AddRightGroupbox('Object Chams', 'package')
ESPTab:AddToggle('EnableESP', {
Text = 'Enable ESP',
Default = false,
Callback = function(Value)
ToggleESP(Value)
if not Value then
	ESP_Logic.StopExitGateESPLoop(); ESP_Logic.ClearExitGateESP()
	ESP_Logic.StopVaultESPLoop(); StopVaultAutoWatcher(); ESP_Logic.ClearVaultESP()
else
	if VDSettings.ShowVaultsESP then
		ESP_Logic.RefreshVaultESP(); ESP_Logic.StartVaultESPLoop(); StartVaultAutoWatcher()
	end
	if ESPSettings.ShowExitGateESP then
		ESP_Logic.RefreshExitGateESP(); ESP_Logic.StartExitGateESPLoop()
	end
end
end
}):AddKeyPicker('ESPKey', {
Default = 'None',
Text = 'ESP',
Mode = 'Toggle',
SyncToggleState = true,
})
ESPTab:AddCheckbox('TeamCheck', {
Text = 'Team Check',
Default = false,
Callback = function(Value)
ESPSettings.TeamCheck = Value
if ESPEnabled then UpdateESP() end
end
})
ESPTab:AddSlider('MaxDistance', {
Text = 'Max Distance',
Default = 1000,
Min = 100,
Max = 5000,
Rounding = 0,
Suffix = ' studs',
Callback = function(Value)
ESPSettings.MaxDistance = Value
end
})
ESPTab:AddCheckbox('ShowName', {
Text = 'Show Names',
Default = true,
Callback = function(Value)
ESPSettings.ShowName = Value
if not ESPEnabled then
	return
end
UpdateESP()
end
}):AddColorPicker('NameColor', {
Default = Color3.fromRGB(255, 255, 255),
Title = 'Name Color',
Transparency = 0,
Callback = function(Value)
ESPSettings.NameColor = Value
if ESPEnabled then UpdateESP() end
end
})
ESPTab:AddCheckbox('ShowKillerName', {
Text = 'Show Killer Name',
Default = false,
Callback = function(Value)
VDSettings.ShowKillerName = Value
if ESPEnabled then
	RefreshESPCacheValues()
	UpdateESP()
end
end
})
ESPTab:AddCheckbox('ShowDistance', {
Text = 'Show Distance',
Default = true,
Callback = function(Value)
ESPSettings.ShowDistance = Value
if ESPEnabled then UpdateESP() end
end
})
ESPTab:AddCheckbox('ShowHealth', {
Text = 'Show Health',
Default = true,
Callback = function(Value)
ESPSettings.ShowHealth = Value
if ESPEnabled then UpdateESP() end
end
})
ESPTab:AddCheckbox('BoxESP', {
Text = 'Box ESP',
Default = false,
Callback = function(Value)
ESPSettings.BoxESP = Value
if ESPEnabled then UpdateESP() end
end
}):AddColorPicker('BoxColor', {
Default = Color3.fromRGB(255, 0, 0),
Title = 'Box Outline',
Transparency = 0,
Callback = function(Value)
ESPSettings.BoxColor = Value
end
}):AddColorPicker('FilledBoxColor', {
Default = Color3.fromRGB(255, 0, 0),
Title = 'Box Fill',
Transparency = 0.8,
Callback = function(Value)
ESPSettings.FilledBoxColor = Value
local trans = Options.FilledBoxColor and Options.FilledBoxColor.Transparency or 0.8
ESPSettings.FilledBoxTransparency = 1 - trans
ESPSettings.FilledBox = trans < 1
end
})
ESPTab:AddCheckbox('TracerESP', {
Text = 'Tracer Lines',
Default = false,
Callback = function(Value)
ESPSettings.TracerESP = Value
if ESPEnabled then UpdateESP() end
end
}):AddColorPicker('KillerTracerColor', {
Default = Color3.fromRGB(255, 80, 80),
Title = 'Killer Line Color',
Transparency = 0,
Callback = function(Value)
ESPSettings.KillerTracerColor = Value
end
}):AddColorPicker('SurvivorTracerColor', {
Default = Color3.fromRGB(80, 220, 120),
Title = 'Survivor Line Color',
Transparency = 0,
Callback = function(Value)
ESPSettings.SurvivorTracerColor = Value
end
})
ESPTab:AddCheckbox('SkeletonESP', {
Text = 'Skeleton ESP',
Default = false,
Callback = function(Value)
ESPSettings.SkeletonESP = Value
if ESPEnabled then UpdateESP() end
end
}):AddColorPicker('SkeletonColor', {
Default = Color3.fromRGB(255, 255, 255),
Title = 'Skeleton Color',
Transparency = 0,
Callback = function(Value)
ESPSettings.SkeletonColor = Value
end
})
ESPTab:AddCheckbox('HeadTrajectoryESP', {
Text = 'Head Trajectory Line',
Default = false,
Tooltip = 'Shows a line from killer head in the direction they are facing',
Callback = function(Value)
ESPSettings.HeadTrajectoryESP = Value
if ESPEnabled then UpdateESP() end
end
}):AddColorPicker('HeadTrajectoryColor', {
Default = Color3.fromRGB(255, 200, 50),
Title = 'Trajectory Color',
Transparency = 0,
Callback = function(Value)
ESPSettings.HeadTrajectoryColor = Value
end
})
local function UpdateVaultESPColors()
	for _, data in pairs(ESP_Storage.Vault.Objects) do
		if data.Name then data.Name.Color = VDSettings.VaultColor end
		if data.Distance then data.Distance.Color = ESPSettings.DistanceColor or Color3.fromRGB(180, 180, 180) end
		if data.NameLabel then data.NameLabel.TextColor3 = VDSettings.VaultColor end
		if data.DistanceLabel then
			data.DistanceLabel.TextColor3 = ESPSettings.DistanceColor or
			Color3.fromRGB(180, 180, 180)
		end
	end
end
ObjectESPBox:AddCheckbox('ExitGateESP', {
Text = 'Exit Gate ESP',
Default = false,
Tooltip = 'Show exit gate text + distance',
Callback = function(Value)
ESPSettings.ShowExitGateESP = Value
if Value then
	ESP_Logic.RefreshExitGateESP()
	ESP_Logic.StartExitGateESPLoop()
else
	ESP_Logic.StopExitGateESPLoop()
	ESP_Logic.ClearExitGateESP()
end
end
}):AddColorPicker('ExitGateNameColor', {
Default = ESPSettings.ExitGateESPNameColor,
Title = 'Exit Text',
Transparency = 0,
Callback = function(Value)
ESPSettings.ExitGateESPNameColor = Value
if ESP_Logic.UpdateExitGateESPColors then ESP_Logic.UpdateExitGateESPColors() end
end
})
ObjectESPBox:AddSlider('ExitGateESPMaxDist', {
Text = 'Exit Gate Max Distance',
Default = ESPSettings.ExitGateESPMaxDistance,
Min = 100,
Max = 2000,
Rounding = 0,
Suffix = ' studs',
Callback = function(Value)
ESPSettings.ExitGateESPMaxDistance = Value
if ESP_Logic.UpdateExitGateESP then ESP_Logic.UpdateExitGateESP() end
end
})
ObjectESPBox:AddCheckbox('VaultESP', {
Text = 'Vault/Window ESP',
Default = false,
Tooltip = 'Show text above vaults/windows (requires ESP enabled)',
Callback = function(Value)
VDSettings.ShowVaultsESP = Value
if Value and ESPEnabled then
	ESP_Logic.RefreshVaultESP()
	ESP_Logic.StartVaultESPLoop()
	if StartVaultAutoWatcher then StartVaultAutoWatcher() end
else
	ESP_Logic.StopVaultESPLoop()
	if StopVaultAutoWatcher then StopVaultAutoWatcher() end
	ESP_Logic.ClearVaultESP()
end
end
}):AddColorPicker('VaultESPColor', {
Default = Color3.fromRGB(0, 255, 255),
Title = 'Vault Text',
Transparency = 0,
Callback = function(Value)
VDSettings.VaultColor = Value
UpdateVaultESPColors()
end
})
ESPTab:AddCheckbox('ShowRole', {
Text = 'Show Role Info',
Default = true,
Tooltip = 'Display Killer/Survivor text on right side of player box',
Callback = function(Value)
VDSettings.ShowRoleText = Value
if ESPEnabled then UpdateESP() end
end
})
ESPTab:AddCheckbox('ShowStatus', {
Text = 'Show Status Info',
Default = true,
Tooltip = 'Display Status (Hooked/Injured) below Role Info',
Callback = function(Value)
VDSettings.ShowStatus = Value
if ESPEnabled then UpdateESP() end
end
})
ESPTab:AddCheckbox('ShowItemImage', {
Text = 'Show Item Image',
Default = true,
Tooltip = 'Display item image above player name',
Callback = function(Value)
ESPSettings.ShowItemImage = Value
if Value then
	pcall(RefreshItemData)
end
if ESPEnabled then UpdateESP() end
end
})
ESPTab:AddCheckbox('ShowItems', {
Text = 'Show Item Text',
Default = true,
Tooltip = 'Display held item name as text (right side)',
Callback = function(Value)
ESPSettings.ShowItems = Value
if Value then
	pcall(RefreshItemData)
end
if ESPEnabled then UpdateESP() end
end
})
ChamsTab:AddToggle('ChamsESP', {
Text = 'Enable Chams',
Default = false,
Tooltip = 'PARENT toggle for ALL Chams (Player + Object). When OFF, all chams are hidden.',
Callback = function(Value)
ToggleChams(Value)
ChamsEnabled = Value
if Value then
	StartChamsLoop()
	if VDSettings.ShowGenerators then
		local generators = CollectGenerators()
		for _, gen in ipairs(generators) do
			CreateObjectESP(gen, "Generator", VDSettings.GeneratorColor)
		end
	end
	if VDSettings.ShowHooks then
		local hooks = CollectHooks()
		for _, hook in ipairs(hooks) do
			CreateObjectESP(hook, "Hook", VDSettings.HookColor)
		end
	end
	if VDSettings.ShowExitGates then
		local exits = CollectExitGates()
		for _, e in ipairs(exits) do
			CreateObjectESP(e, "ExitGate", VDSettings.ExitGateColor)
		end
	end
	if VDSettings.ShowPallets then
		local pallets = CollectPalletsFixed()
		for _, p in ipairs(pallets) do CreateObjectESP(p, "Pallet", VDSettings.PalletColor) end
	end
	if VDSettings.ShowVaults then
		local vaults = CollectVaultsFixed()
		for _, v in ipairs(vaults) do
			if v:FindFirstChild("Bottom") then v.Bottom.Transparency = 0 end
			CreateObjectESP(v, "Vault", VDSettings.VaultColor)
		end
	end
else
	ChamsLoopRunning = false
	RemoveObjectESP("Generator")
	RemoveObjectESP("Hook")
	RemoveObjectESP("ExitGate")
	RemoveObjectESP("Pallet")
	RemoveObjectESP("Vault")
	local vaults = CollectVaultsFixed()
	for _, v in ipairs(vaults) do
		if v:FindFirstChild("Bottom") then v.Bottom.Transparency = 1 end
	end
end
end
}):AddKeyPicker('ChamsKey', {
Default = 'None',
Text = 'Chams',
Mode = 'Toggle',
SyncToggleState = true,
})
ChamsTab:AddCheckbox('ChamsVisibleOnly', {
Text = 'Visible Only',
Default = false,
Callback = function(Value)
ESPSettings.ChamsVisibleOnly = Value
if ChamsEnabled then UpdateChams() end
local objectTypes = { "Generators", "Hooks", "ExitGates", "Pallets", "Vaults" }
for _, objType in ipairs(objectTypes) do
	local storage = VDESPObjects[objType]
	if storage then
		for key, data in pairs(storage) do
			if data.Highlight and data.Highlight.Parent then
				if Value then
					data.Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
				else
					data.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				end
			end
		end
	end
end
end
})
ChamsTab:AddSlider('ChamsMaxDistance', {
Text = 'Max Distance',
Default = 2000,
Min = 100,
Max = 5000,
Rounding = 0,
Suffix = ' studs',
Callback = function(Value)
ESPSettings.ChamsMaxDistance = Value
UpdateChams()
end
})
ChamsTab:AddCheckbox('KillerOutlineToggle', {
Text = 'Killer Chams',
Default = true,
Callback = function(Value)
VDSettings.KillerOutlineEnabled = Value
if ChamsEnabled then UpdateChams() end
end
}):AddColorPicker('KillerChamsColor', {
Default = Color3.fromRGB(255, 0, 0),
Title = 'Killer Fill',
Transparency = 0.3,
Callback = function(Value)
VDSettings.KillerColor = Value
if Options.KillerChamsColor then
	VDSettings.KillerTransparency = Options.KillerChamsColor.Transparency
end
UpdateChams()
end
}):AddColorPicker('KillerOutlineColor', {
Default = Color3.fromRGB(255, 255, 255),
Title = 'Killer Outline',
Transparency = 0,
Callback = function(Value)
VDSettings.KillerOutlineColor = Value
if Options.KillerOutlineColor then
	VDSettings.KillerOutlineTransparency = Options.KillerOutlineColor.Transparency
end
UpdateChams()
end
})
ChamsTab:AddCheckbox('SurvivorOutlineToggle', {
Text = 'Survivor Chams',
Default = true,
Callback = function(Value)
VDSettings.SurvivorOutlineEnabled = Value
if ChamsEnabled then UpdateChams() end
end
}):AddColorPicker('SurvivorChamsColor', {
Default = Color3.fromRGB(0, 150, 255),
Title = 'Survivor Fill',
Transparency = 0.3,
Callback = function(Value)
VDSettings.SurvivorColor = Value
if Options.SurvivorChamsColor then
	VDSettings.SurvivorTransparency = Options.SurvivorChamsColor.Transparency
end
UpdateChams()
end
}):AddColorPicker('SurvivorOutlineColor', {
Default = Color3.fromRGB(255, 255, 255),
Title = 'Survivor Outline',
Transparency = 0,
Callback = function(Value)
VDSettings.SurvivorOutlineColor = Value
if Options.SurvivorOutlineColor then
	VDSettings.SurvivorOutlineTransparency = Options.SurvivorOutlineColor.Transparency
end
UpdateChams()
end
})
ObjectChamsBox:AddCheckbox('GeneratorChams', {
Text = 'Generator Chams',
Default = false,
Callback = function(Value)
VDSettings.ShowGenerators = Value
if Value and ChamsEnabled then
	RemoveObjectESP("Generator")
	local generators = CollectGenerators()
	for _, gen in ipairs(generators) do
		CreateObjectESP(gen, "Generator", VDSettings.GeneratorColor)
	end
else
	RemoveObjectESP("Generator")
end
end
}):AddColorPicker('GeneratorChamsColor', {
Default = Color3.fromRGB(255, 200, 0),
Title = 'Gen Progress Fill',
Transparency = 0.5,
Callback = function(Value)
VDSettings.GeneratorColor = Value
if Options.GeneratorChamsColor then
	VDSettings.GeneratorTransparency = Options.GeneratorChamsColor.Transparency
	UpdateObjectESPTransparency("Generator", VDSettings.GeneratorTransparency)
end
UpdateObjectESPColor("Generator", Value)
end
}):AddColorPicker('GeneratorFinishedColor', {
Default = Color3.fromRGB(0, 255, 0),
Title = 'Gen Finished Fill',
Transparency = 0.5,
Callback = function(Value)
VDSettings.GeneratorFinishedColor = Value
end
}):AddColorPicker('GeneratorOutlineColor', {
Default = Color3.fromRGB(255, 255, 255),
Title = 'Generator Outline',
Transparency = 0,
Callback = function(Value)
VDSettings.GeneratorOutlineColor = Value
if Options.GeneratorOutlineColor then
	VDSettings.GeneratorOutlineTransparency = Options.GeneratorOutlineColor.Transparency
end
UpdateObjectESPOutlineColor("Generator", Value)
UpdateObjectESPOutlineTransparency("Generator", VDSettings.GeneratorOutlineTransparency)
end
})
ObjectChamsBox:AddCheckbox('ShowGeneratorProgress', {
Text = 'Show Generator Progress',
Default = true,
Tooltip = 'Display progress bar above generators',
Callback = function(Value)
if Value and (not Toggles.ChamsESP or not Toggles.ChamsESP.Value) then
	if Toggles.ShowGeneratorProgress and Toggles.ShowGeneratorProgress.SetValue then
		Toggles
		.ShowGeneratorProgress:SetValue(false)
	end
	Library:Notify('Enable Chams first!', 2)
	return
end
VDSettings.ShowGeneratorProgress = Value
if VDSettings.ShowGenerators then
	RemoveObjectESP("Generator")
	local generators = CollectGenerators()
	for _, gen in ipairs(generators) do
		CreateObjectESP(gen, "Generator", VDSettings.GeneratorColor)
	end
end
end
})
ObjectChamsBox:AddSlider('GeneratorMaxDist', {
Text = 'Generator Max Distance',
Default = 500,
Min = 50,
Max = 2000,
Rounding = 0,
Suffix = ' studs',
Callback = function(Value)
VDSettings.GeneratorMaxDistance = Value
end
})
ObjectChamsBox:AddCheckbox('HookChams', {
Text = 'Hook Chams',
Default = false,
Callback = function(Value)
VDSettings.ShowHooks = Value
if Value and ChamsEnabled then
	RemoveObjectESP("Hook")
	local hooks = CollectHooks()
	for _, hook in ipairs(hooks) do
		CreateObjectESP(hook, "Hook", VDSettings.HookColor)
	end
else
	RemoveObjectESP("Hook")
end
end
}):AddColorPicker('HookChamsColor', {
Default = Color3.fromRGB(255, 255, 0),
Title = 'Hook Fill',
Transparency = 0.5,
Callback = function(Value)
VDSettings.HookColor = Value
if Options.HookChamsColor then
	VDSettings.HookTransparency = Options.HookChamsColor.Transparency
	UpdateObjectESPTransparency("Hook", VDSettings.HookTransparency)
end
UpdateObjectESPColor("Hook", Value)
end
}):AddColorPicker('HookOutlineColor', {
Default = Color3.fromRGB(255, 255, 255),
Title = 'Hook Outline',
Transparency = 0,
Callback = function(Value)
VDSettings.HookOutlineColor = Value
if Options.HookOutlineColor then
	VDSettings.HookOutlineTransparency = Options.HookOutlineColor.Transparency
end
UpdateObjectESPOutlineColor("Hook", Value)
UpdateObjectESPOutlineTransparency("Hook", VDSettings.HookOutlineTransparency)
end
})
ObjectChamsBox:AddCheckbox('ExitGateChams', {
Text = 'Exit Gate Chams',
Default = false,
Callback = function(Value)
VDSettings.ShowExitGates = Value
if Value and ChamsEnabled then
	RemoveObjectESP("ExitGate")
	local exits = CollectExitGates()
	for _, e in ipairs(exits) do
		CreateObjectESP(e, "ExitGate", VDSettings.ExitGateColor)
	end
else
	RemoveObjectESP("ExitGate")
end
end
}):AddColorPicker('ExitGateChamsColor', {
Default = Color3.fromRGB(0, 255, 0),
Title = 'Exit Fill',
Transparency = 0.5,
Callback = function(Value)
VDSettings.ExitGateColor = Value
if Options.ExitGateChamsColor then
	VDSettings.ExitGateTransparency = Options.ExitGateChamsColor.Transparency
	UpdateObjectESPTransparency("ExitGate", VDSettings.ExitGateTransparency)
end
UpdateObjectESPColor("ExitGate", Value)
end
}):AddColorPicker('ExitGateOutlineColor', {
Default = Color3.fromRGB(255, 255, 255),
Title = 'Exit Outline',
Transparency = 0,
Callback = function(Value)
VDSettings.ExitGateOutlineColor = Value
if Options.ExitGateOutlineColor then
	VDSettings.ExitGateOutlineTransparency = Options.ExitGateOutlineColor.Transparency
end
UpdateObjectESPOutlineColor("ExitGate", Value)
UpdateObjectESPOutlineTransparency("ExitGate", VDSettings.ExitGateOutlineTransparency)
end
})
ObjectChamsBox:AddSlider('ExitGateMaxDist', {
Text = 'Exit Gate Max Distance',
Default = 500,
Min = 50,
Max = 2000,
Rounding = 0,
Suffix = ' studs',
Callback = function(Value)
VDSettings.ExitGateMaxDistance = Value
end
})
ObjectChamsBox:AddSlider('HookMaxDist', {
Text = 'Hook Max Distance',
Default = 500,
Min = 50,
Max = 2000,
Rounding = 0,
Suffix = ' studs',
Callback = function(Value)
VDSettings.HookMaxDistance = Value
end
})
local PalletChamsToggle = ObjectChamsBox:AddCheckbox('ShowPalletChams', {
Text = 'Pallet Chams',
Default = false,
Tooltip = 'Highlight pallets through walls',
Callback = function(Value)
VDSettings.ShowPallets = Value
if Value and ChamsEnabled then
	local pallets = CollectPalletsFixed()
	for _, obj in ipairs(pallets) do
		CreateObjectESP(obj, "Pallet", VDSettings.PalletColor)
	end
	StartChamsLoop()
elseif not Value then
	RemoveObjectESP("Pallet")
end
end
}):AddColorPicker('PalletChamsColor', {
Default = Color3.fromRGB(220, 180, 100),
Title = 'Pallet Fill',
Transparency = 0.3,
Callback = function(Value)
VDSettings.PalletColor = Value
if Options.PalletChamsColor then
	VDSettings.PalletTransparency = Options.PalletChamsColor.Transparency
	UpdateObjectESPTransparency("Pallet", VDSettings.PalletTransparency)
end
UpdateObjectESPColor("Pallet", Value)
end
}):AddColorPicker('PalletOutlineColor', {
Default = Color3.fromRGB(255, 255, 255),
Title = 'Pallet Outline',
Transparency = 0,
Callback = function(Value)
VDSettings.PalletOutlineColor = Value
if Options.PalletOutlineColor then
	VDSettings.PalletOutlineTransparency = Options.PalletOutlineColor.Transparency
end
UpdateObjectESPOutlineColor("Pallet", Value)
UpdateObjectESPOutlineTransparency("Pallet", VDSettings.PalletOutlineTransparency)
end
})
local VaultChamsToggle = ObjectChamsBox:AddCheckbox('ShowVaultChams', {
Text = 'Vault/Window Chams',
Default = false,
Tooltip = 'Highlight vaults/windows through walls',
Callback = function(Value)
VDSettings.ShowVaults = Value
if Value and ChamsEnabled then
	local vaults = CollectVaultsFixed()
	for _, obj in ipairs(vaults) do
		if obj:FindFirstChild("Bottom") then obj.Bottom.Transparency = 0 end
		CreateObjectESP(obj, "Vault", VDSettings.VaultColor)
	end
	StartChamsLoop()
elseif not Value then
	RemoveObjectESP("Vault")
	local vaults = CollectVaultsFixed()
	for _, v in ipairs(vaults) do
		if v:FindFirstChild("Bottom") then v.Bottom.Transparency = 1 end
	end
end
end
}):AddColorPicker('VaultChamsColor', {
Default = Color3.fromRGB(0, 255, 255),
Title = 'Vault Fill',
Transparency = 0.5,
Callback = function(Value)
VDSettings.VaultColor = Value
if Options.VaultChamsColor then
	VDSettings.VaultTransparency = Options.VaultChamsColor.Transparency
	UpdateObjectESPTransparency("Vault", VDSettings.VaultTransparency)
end
UpdateObjectESPColor("Vault", Value)
end
}):AddColorPicker('VaultOutlineColor', {
Default = Color3.fromRGB(255, 255, 255),
Title = 'Vault Outline',
Transparency = 0,
Callback = function(Value)
VDSettings.VaultOutlineColor = Value
if Options.VaultOutlineColor then
	VDSettings.VaultOutlineTransparency = Options.VaultOutlineColor.Transparency
end
UpdateObjectESPOutlineColor("Vault", Value)
UpdateObjectESPOutlineTransparency("Vault", VDSettings.VaultOutlineTransparency)
end
})
local WorldBox = Tabs.World:AddLeftGroupbox('World Effects', 'sun')
WorldBox:AddCheckbox('Fullbright', {
Text = 'Fullbright',
Default = false,
Callback = function(Value)
if Value then
	Lighting.Ambient = Color3.fromRGB(255, 255, 255)
	Lighting.Brightness = 2
	Lighting.GlobalShadows = false
	Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
else
	Lighting.Ambient = OriginalLighting.Ambient
	Lighting.Brightness = OriginalLighting.Brightness
	Lighting.GlobalShadows = OriginalLighting.GlobalShadows
	Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
end
end
})
WorldBox:AddCheckbox('NoFog', {
Text = 'No Fog',
Default = false,
Callback = function(Value)
if Value then
	Lighting.FogEnd = 100000
	Lighting.FogStart = 100000
	if Lighting:FindFirstChild("Atmosphere") then
		Lighting.Atmosphere.Density = 0
	end
else
	Lighting.FogEnd = OriginalLighting.FogEnd
	Lighting.FogStart = OriginalLighting.FogStart
	if Lighting:FindFirstChild("Atmosphere") then
		Lighting.Atmosphere.Density = OriginalLighting.AtmosphereDensity
	end
end
end
})
WorldBox:AddCheckbox('NightMode', {
Text = 'Night Mode',
Default = false,
Callback = function(Value)
if Value then
	Lighting.ClockTime = 0
	Lighting.Ambient = Color3.fromRGB(50, 50, 80)
else
	Lighting.ClockTime = OriginalLighting.ClockTime
	Lighting.Ambient = OriginalLighting.Ambient
end
end
})
WorldBox:AddSlider('TimeOfDay', {
Text = 'Time of Day',
Default = 14,
Min = 0,
Max = 24,
Rounding = 1,
Suffix = 'h',
Callback = function(Value)
Lighting.ClockTime = Value
end
})
WorldBox:AddCheckbox('RemoveEffects', {
Text = 'Remove Post Effects',
Default = false,
Callback = function(Value)
for _, effect in ipairs(Lighting:GetChildren()) do
	if effect:IsA("BlurEffect") or effect:IsA("BloomEffect") or
	effect:IsA("DepthOfFieldEffect") or effect:IsA("SunRaysEffect") or
	effect:IsA("ColorCorrectionEffect") then
		effect.Enabled = not Value
	end
end
end
})
WorldBox:AddCheckbox('Xray', {
Text = 'X-Ray (See Through)',
Default = false,
Callback = function(Value)
for _, obj in ipairs(workspace:GetDescendants()) do
	if obj:IsA("BasePart") and not obj:IsDescendantOf(LocalPlayer.Character or {}) then
		if obj.Name ~= "HumanoidRootPart" and obj.Name ~= "Head" then
			if Value then
				if not obj:GetAttribute("OriginalTransparency") then
					obj:SetAttribute("OriginalTransparency", obj.Transparency)
				end
				if obj.Transparency < 0.7 then
					obj.Transparency = 0.7
				end
			else
				local orig = obj:GetAttribute("OriginalTransparency")
				if orig then
					obj.Transparency = orig
				end
			end
		end
	end
end
end
})
WorldBox:AddCheckbox('NoBloodToggle', {
Text = 'Disable Blood',
Default = false,
Tooltip = 'Turn off blood effects',
Callback = function(Value)
LocalPlayer:SetAttribute("enableblood", not Value)
end
})
WorldBox:AddCheckbox('NoShadowsToggle', {
Text = 'No Shadows',
Default = false,
Tooltip = 'Disable shadows for better FPS',
Callback = function(Value)
LocalPlayer:SetAttribute("noshadows", Value)
Lighting.GlobalShadows = not Value
end
})
WorldBox:AddCheckbox('LowGraphicsToggle', {
Text = 'Low Graphics Mode',
Default = false,
Tooltip = 'Enable low graphics for better performance',
Callback = function(Value)
LocalPlayer:SetAttribute("lowGraphics", Value)
if Value then
	settings().Rendering.QualityLevel = 1
else
	settings().Rendering.QualityLevel = 10
end
end
})
local BodyModifierBox = Tabs.World:AddRightGroupbox('Body Modifier', 'user')
local ValidBodyParts = {
["Head"] = true,
["Torso"] = true,
["Left Arm"] = true,
["Right Arm"] = true,
["Left Leg"] = true,
["Right Leg"] = true,
["UpperTorso"] = true,
["LowerTorso"] = true,
["LeftUpperArm"] = true,
["LeftLowerArm"] = true,
["RightUpperArm"] = true,
["RightLowerArm"] = true,
["LeftUpperLeg"] = true,
["LeftLowerLeg"] = true,
["RightUpperLeg"] = true,
["RightLowerLeg"] = true,
["LeftHand"] = true,
["RightHand"] = true,
["LeftFoot"] = true,
["RightFoot"] = true
}
local function RestoreBodyModifier()
	local char = LocalPlayer.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and ValidBodyParts[part.Name] then
			local origMat = part:GetAttribute("OriginalMaterial")
			if origMat then
				part.Material = Enum.Material[origMat]
				part:SetAttribute("OriginalMaterial", nil)
			end
			local origCol = part:GetAttribute("OriginalColor")
			if origCol then
				part.Color = origCol
				part:SetAttribute("OriginalColor", nil)
			end
		end
	end
end
local function ApplyBodyModifier()
	if not (Toggles.BodyMaterial and Toggles.BodyMaterial.Value) then
		RestoreBodyModifier()
		return
	end
	local char = LocalPlayer.Character
	if not char then return end
	local matName = Options.BodyMaterialDropdown and Options.BodyMaterialDropdown.Value
	if not matName then return end
	local mat = Enum.Material[matName]
	local col = Options.BodyColor and Options.BodyColor.Value or Color3.fromRGB(255, 255, 255)
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and ValidBodyParts[part.Name] and not part.Parent:IsA("Accessory") then
			if not part:GetAttribute("OriginalMaterial") then
				part:SetAttribute("OriginalMaterial", part.Material.Name)
			end
			if not part:GetAttribute("OriginalColor") then
				part:SetAttribute("OriginalColor", part.Color)
			end
			part.Material = mat
			part.Color = col
		end
	end
end
BodyModifierBox:AddCheckbox('BodyMaterial', {
Text = 'Enable Body Modifier',
Default = false,
Tooltip = 'Enable custom body material and color',
Callback = function(Value)
ApplyBodyModifier()
end
}):AddColorPicker('BodyColor', {
Default = Color3.fromRGB(255, 255, 255),
Title = 'Body Color',
Transparency = 0,
Callback = function()
if Toggles.BodyMaterial and Toggles.BodyMaterial.Value then
	ApplyBodyModifier()
end
end
})
BodyModifierBox:AddDropdown('BodyMaterialDropdown', {
Values = { 'ForceField', 'SmoothPlastic', 'Neon', 'Foil', 'Glass' },
Default = 1,
Multi = false,
Text = 'Material',
Tooltip = 'Select body material',
Callback = function()
if Toggles.BodyMaterial and Toggles.BodyMaterial.Value then
	ApplyBodyModifier()
end
end
})
LocalPlayer.CharacterAdded:Connect(function(char)
task.wait(1)
if Toggles.BodyMaterial and Toggles.BodyMaterial.Value then
	ApplyBodyModifier()
end
end)
local SkyboxBox = Tabs.World:AddLeftGroupbox('Skybox Changer', 'cloud')
GFS.SkyboxPresets = {
["Elegant Morning"] = "rbxassetid://1547610926",
["Fade Blue"] = "rbxassetid://252926271",
["Morning Glow"] = "rbxassetid://1546639786",
["Neptune"] = "rbxassetid://159454286",
["Night Sky"] = "rbxassetid://1547611102",
["Pink Daylight"] = "rbxassetid://1546640171",
["Purple Nebula"] = "rbxassetid://159454299",
["Redshift"] = "rbxassetid://1547585945",
["Setting Sun"] = "rbxassetid://1546639623"
}
GFS.CustomSky = nil
GFS.OriginalSky = nil
SkyboxBox:AddCheckbox('SkyboxChangerToggle', {
Text = 'Enable Skybox',
Default = false,
Callback = function(Value)
pcall(function()
if Value then
	local existingCustom = Lighting:FindFirstChild("Starship_CustomSky")
	if existingCustom then existingCustom:Destroy() end
	local originalSky = Lighting:FindFirstChildOfClass("Sky")
	if originalSky and originalSky.Name ~= "Starship_CustomSky" then
		GFS.OriginalSkyName = originalSky.Name
		originalSky.Name = "OriginalSky_Hidden"
		originalSky.Parent = ReplicatedStorage
	end
	GFS.CustomSky = Instance.new("Sky")
	GFS.CustomSky.Name = "Starship_CustomSky"
	GFS.CustomSky.CelestialBodiesShown = false
	GFS.CustomSky.Parent = Lighting
	local preset = Options.SkyboxDropdown and Options.SkyboxDropdown.Value or "Redshift"
	local textureId = GFS.SkyboxPresets[preset] or GFS.SkyboxPresets["Redshift"]
	GFS.CustomSky.SkyboxBk = textureId
	GFS.CustomSky.SkyboxDn = textureId
	GFS.CustomSky.SkyboxFt = textureId
	GFS.CustomSky.SkyboxLf = textureId
	GFS.CustomSky.SkyboxRt = textureId
	GFS.CustomSky.SkyboxUp = textureId
else
	local customSky = Lighting:FindFirstChild("Starship_CustomSky")
	if customSky then customSky:Destroy() end
	GFS.CustomSky = nil
	local hiddenSky = ReplicatedStorage:FindFirstChild("OriginalSky_Hidden")
	if hiddenSky then
		hiddenSky.Name = GFS.OriginalSkyName or "Sky"
		hiddenSky.Parent = Lighting
	end
end
end)
end
})
SkyboxBox:AddDropdown('SkyboxDropdown', {
Text = 'Preset',
Default = 'Redshift',
Values = { "Elegant Morning", "Fade Blue", "Morning Glow", "Neptune", "Night Sky", "Pink Daylight", "Purple Nebula", "Redshift", "Setting Sun" },
Callback = function(Value)
if Value == nil or Value == '' then return end
if Toggles.SkyboxChangerToggle and Toggles.SkyboxChangerToggle.Value and GFS.CustomSky then
	local textureId = GFS.SkyboxPresets[Value] or GFS.SkyboxPresets["Redshift"]
	GFS.CustomSky.SkyboxBk = textureId
	GFS.CustomSky.SkyboxDn = textureId
	GFS.CustomSky.SkyboxFt = textureId
	GFS.CustomSky.SkyboxLf = textureId
	GFS.CustomSky.SkyboxRt = textureId
	GFS.CustomSky.SkyboxUp = textureId
end
end
})
local AmbienceBox = Tabs.World:AddRightGroupbox('Ambience', 'palette')
GFS.OriginalAmbient = Lighting.Ambient
GFS.OriginalOutdoorAmbient = Lighting.OutdoorAmbient
AmbienceBox:AddCheckbox('AmbienceToggle', {
Text = 'Custom Ambience',
Default = false,
Callback = function(Value)
if Value then
	local insideColor = Options.InsideAmbienceColor and Options.InsideAmbienceColor.Value or
	Color3.fromRGB(117, 76, 236)
	local outsideColor = Options.OutsideAmbienceColor and Options.OutsideAmbienceColor.Value or
	Color3.fromRGB(117, 76, 236)
	Lighting.Ambient = insideColor
	Lighting.OutdoorAmbient = outsideColor
else
	Lighting.Ambient = GFS.OriginalAmbient
	Lighting.OutdoorAmbient = GFS.OriginalOutdoorAmbient
end
end
}):AddColorPicker('InsideAmbienceColor', {
Default = Color3.fromRGB(117, 76, 236),
Title = 'Indoor',
Transparency = 0,
Callback = function(Value)
if Toggles.AmbienceToggle and Toggles.AmbienceToggle.Value then
	Lighting.Ambient = Value
end
end
}):AddColorPicker('OutsideAmbienceColor', {
Default = Color3.fromRGB(117, 76, 236),
Title = 'Outdoor',
Transparency = 0,
Callback = function(Value)
if Toggles.AmbienceToggle and Toggles.AmbienceToggle.Value then
	Lighting.OutdoorAmbient = Value
end
end
})
local CameraSettingsBox = Tabs.World:AddRightGroupbox('Resolution Settings', 'ratio')
local CameraObj = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
CameraObj = workspace.CurrentCamera
end)
local fovBound = false
local aspectBound = false
local currentFovValue = 70
local currentAspectModifier = CFrame.new()
CameraSettingsBox:AddSlider('FOVChanger', {
Text = 'Field of View',
Default = 70,
Min = 40,
Max = 120,
Rounding = 1,
Suffix = '°',
Callback = function(Value)
    currentFovValue = Value
    if math.abs(Value - 70) < 0.1 then
        pcall(function() RunService:UnbindFromRenderStep("StarshipFOV") end)
        fovBound = false
        if CameraObj then 
            pcall(function() CameraObj.FieldOfView = 70 end)
        end
    else
        if not fovBound then
            if not Camera.OriginalFieldOfView and CameraObj then
                Camera.OriginalFieldOfView = CameraObj.FieldOfView
            end
            pcall(function() RunService:UnbindFromRenderStep("StarshipFOV") end)
            RunService:BindToRenderStep("StarshipFOV", Enum.RenderPriority.Camera.Value + 1, function()
                if CameraObj then
                    CameraObj.FieldOfView = currentFovValue
                end
            end)
            fovBound = true
        end
    end
end
})
CameraSettingsBox:AddSlider('AspectRatioSlider', {
Text = 'Aspect Ratio',
Default = 1,
Min = 0.5,
Max = 1,
Rounding = 2,
Tooltip = 'Default = 1 | Lower = Wider (Stretched) | Higher = Taller',
Callback = function(Value)
    local transformValue = Value
    currentAspectModifier = CFrame.new(0, 0, 0, 1, 0, 0, 0, transformValue, 0, 0, 0, 1)
    if math.abs(Value - 1) < 0.01 then
        pcall(function() RunService:UnbindFromRenderStep("StarshipAspectRatio") end)
        aspectBound = false
        if CameraObj then
            -- Note: We can't easily 'reset' CFrame from here as it's modified in RenderStep
            -- Unbinding should stop the modification
        end
    else
        if not aspectBound then
            pcall(function() RunService:UnbindFromRenderStep("StarshipAspectRatio") end)
            RunService:BindToRenderStep("StarshipAspectRatio", Enum.RenderPriority.Camera.Value + 1, function()
                if CameraObj then
                    CameraObj.CFrame = CameraObj.CFrame * currentAspectModifier
                end
            end)
            aspectBound = true
        end
    end
end
})

CameraSettingsBox:AddButton({
    Text = 'Reset Camera',
    Func = function()
        Options.FOVChanger:SetValue(70)
        Options.AspectRatioSlider:SetValue(1)
        pcall(function()
            RunService:UnbindFromRenderStep("StarshipFOV")
            RunService:UnbindFromRenderStep("StarshipAspectRatio")
            if CameraObj then
                CameraObj.FieldOfView = 70
            end
        end)
        Library:Notify("Camera settings reset!", 2)
    end
})
LocalPlayer.CharacterAdded:Connect(function()
task.wait(1)
if DesyncState and DesyncState.chamsEnabled then
	pcall(function()
	if type(createDesyncGhost) == "function" then createDesyncGhost() end
end)
end
if GFS.RefreshVisualSettings then
	pcall(GFS.RefreshVisualSettings)
end
end)
GFS.LastVisualRefresh = 0
GFS.RefreshVisualSettings = function()
if Toggles.Fullbright and Toggles.Fullbright.Value then
	local targetAmbient = Color3.fromRGB(255, 255, 255)
	if Lighting.Ambient ~= targetAmbient then Lighting.Ambient = targetAmbient end
	if Lighting.Brightness ~= 2 then Lighting.Brightness = 2 end
	if Lighting.GlobalShadows ~= false then Lighting.GlobalShadows = false end
	if Lighting.OutdoorAmbient ~= targetAmbient then Lighting.OutdoorAmbient = targetAmbient end
end
if Toggles.NoFog and Toggles.NoFog.Value then
	if Lighting.FogEnd ~= 100000 then Lighting.FogEnd = 100000 end
	if Lighting.FogStart ~= 100000 then Lighting.FogStart = 100000 end
	if Lighting:FindFirstChild("Atmosphere") then
		if Lighting.Atmosphere.Density ~= 0 then
			Lighting.Atmosphere.Density = 0
		end
	end
end
if Toggles.NightMode and Toggles.NightMode.Value then
	if Lighting.ClockTime ~= 0 then Lighting.ClockTime = 0 end
	local nightAmbient = Color3.fromRGB(50, 50, 80)
	if Lighting.Ambient ~= nightAmbient then Lighting.Ambient = nightAmbient end
end
if Toggles.SkyboxChangerToggle and Toggles.SkyboxChangerToggle.Value then
	local customSky = Lighting:FindFirstChild("Starship_CustomSky")
	if not customSky and GFS.CustomSky then
		pcall(function()
		local newSky = Instance.new("Sky")
		newSky.Name = "Starship_CustomSky"
		newSky.CelestialBodiesShown = false
		local preset = Options.SkyboxDropdown and Options.SkyboxDropdown.Value or "Redshift"
		local textureId = GFS.SkyboxPresets[preset] or GFS.SkyboxPresets["Redshift"]
		newSky.SkyboxBk = textureId
		newSky.SkyboxDn = textureId
		newSky.SkyboxFt = textureId
		newSky.SkyboxLf = textureId
		newSky.SkyboxRt = textureId
		newSky.SkyboxUp = textureId
		newSky.Parent = Lighting
		GFS.CustomSky = newSky
	end)
end
end
if Toggles.AmbienceToggle and Toggles.AmbienceToggle.Value then
	local insideColor = Options.InsideAmbienceColor and Options.InsideAmbienceColor.Value or
	Color3.fromRGB(117, 76, 236)
	local outsideColor = Options.OutsideAmbienceColor and Options.OutsideAmbienceColor.Value or
	Color3.fromRGB(117, 76, 236)
	if Lighting.Ambient ~= insideColor then Lighting.Ambient = insideColor end
	if Lighting.OutdoorAmbient ~= outsideColor then Lighting.OutdoorAmbient = outsideColor end
end
end
RunService.Heartbeat:Connect(function()
local now = tick()
if now - GFS.LastVisualRefresh < 2 then return end
GFS.LastVisualRefresh = now
pcall(GFS.RefreshVisualSettings)
end)
end
SafeInit(Init.VisualTab, 'InitVisualTab')
Init.AntiAimTab = function()
local function InitDesyncBox()
	local DesyncBox = Tabs.AntiAim:AddLeftGroupbox('Desync (Experimental)', 'book-copy')
	task.spawn(function()
	local StatusRemote = ReplicatedStorage.Remotes:FindFirstChild("StatusUpdateEvent")
	if StatusRemote then
		StatusRemote.OnClientEvent:Connect(function(player, status)
		if Toggles.StatusESP and Toggles.StatusESP.Value then
			local playerName = "Unknown"
			if typeof(player) == "Instance" then
				playerName = player.Name
			elseif typeof(player) == "string" then
				playerName = player
			end
			Library:Notify(tostring(playerName) .. ": " .. tostring(status), 5)
		end
	end)
end
end)
DesyncState.enabled = DesyncState.enabled or false
DesyncState.mainConnection = DesyncState.mainConnection or nil
DesyncState.cameraConnection = DesyncState.cameraConnection or nil
DesyncState.serverPosition = DesyncState.serverPosition or nil
DesyncState.cameraAnchor = DesyncState.cameraAnchor or nil
DesyncState.serverPosLabel = DesyncState.serverPosLabel or nil
DesyncState.clientPosLabel = DesyncState.clientPosLabel or nil
local DesyncStorage = _G.StarshipDesyncStorage
if not DesyncStorage then
	DesyncStorage = {
	ServerPosition = nil,
	ClientPosition = nil,
	Distance = 0,
	IsActive = false
	}
	_G.StarshipDesyncStorage = DesyncStorage
end
local desyncDebugEnabled = false
local desyncDebugCounter = 0
local function updateDesyncLabels()
	if DesyncState.serverPosLabel then
		if DesyncState.serverPosition then
			local pos = DesyncState.serverPosition.Position
			DesyncState.serverPosLabel:SetText(string.format('Server (A): %.1f, %.1f, %.1f', pos.X, pos.Y,
			pos.Z))
		else
			DesyncState.serverPosLabel:SetText('Server (A): -')
		end
	end
	if DesyncState.clientPosLabel then
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local pos = hrp.Position
			DesyncState.clientPosLabel:SetText(string.format('Client (B): %.1f, %.1f, %.1f', pos.X, pos.Y,
			pos.Z))
		else
			DesyncState.clientPosLabel:SetText('Client (B): -')
		end
	end
end
local desyncDistLabel = DesyncBox:AddLabel('Distance: 0 studs')
task.spawn(function()
while true do
	task.wait(0.3)
	pcall(function()
	if DesyncState.enabled and DesyncStorage.Distance then
		desyncDistLabel:SetText('Distance: ' ..
		string.format("%.1f", DesyncStorage.Distance) .. ' studs')
	else
		desyncDistLabel:SetText('Distance: 0 studs')
	end
end)
end
end)
local function createCameraAnchor()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local anchor = Instance.new("Part")
	anchor.Name = "StarshipDesyncAnchor"
	anchor.Size = Vector3.new(2, 2, 2)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Anchored = true
	anchor.CFrame = hrp.CFrame
	anchor.Parent = workspace
	return anchor
end
local function startTrueDesync()
	if not LocalPlayer.Character then
		return
	end
	local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		return
	end
	DesyncState.serverPosition = hrp.CFrame
	DesyncStorage.ServerPosition = DesyncState.serverPosition
	DesyncStorage.IsActive = true
	DesyncState.cameraAnchor = createCameraAnchor()
	if DesyncState.cameraAnchor then
		workspace.CurrentCamera.CameraSubject = DesyncState.cameraAnchor
	end
	updateDesyncLabels()
	DesyncState.cameraConnection = RunService.RenderStepped:Connect(function()
	if DesyncState.cameraAnchor and DesyncState.enabled then
		local cameraPos = DesyncStorage.ClientPosition
		if cameraPos then
			DesyncState.cameraAnchor.CFrame = cameraPos
		end
		if workspace.CurrentCamera.CameraSubject ~= DesyncState.cameraAnchor then
			workspace.CurrentCamera.CameraSubject = DesyncState.cameraAnchor
		end
	end
end)
DesyncState.mainConnection = RunService.Heartbeat:Connect(function()
if not DesyncState.enabled then return end
if not LocalPlayer.Character then return end
local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return end
local realCFrame = hrp.CFrame
local realVelocity = hrp.AssemblyLinearVelocity
DesyncStorage.ClientPosition = realCFrame
DesyncStorage.Distance = (realCFrame.Position - DesyncState.serverPosition.Position).Magnitude
if desyncInteractHeld then
	DesyncState.serverPosition = realCFrame
	DesyncStorage.ServerPosition = DesyncState.serverPosition
end
hrp.CFrame = DesyncState.serverPosition
hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
RunService.RenderStepped:Wait()
if hrp and DesyncState.enabled then
	hrp.CFrame = realCFrame
	hrp.AssemblyLinearVelocity = realVelocity
end
updateDesyncLabels()
end)
Library:Notify('Desync: Enabled', 3)
end
local function stopTrueDesync()
	if DesyncState.mainConnection then
		DesyncState.mainConnection:Disconnect()
		DesyncState.mainConnection = nil
	end
	if DesyncState.cameraConnection then
		DesyncState.cameraConnection:Disconnect()
		DesyncState.cameraConnection = nil
	end
	local char = LocalPlayer.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and DesyncStorage.ClientPosition then
			hrp.CFrame = DesyncStorage.ClientPosition
			hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
	end
	local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		workspace.CurrentCamera.CameraSubject = humanoid
	end
	if DesyncState.cameraAnchor then
		DesyncState.cameraAnchor:Destroy()
		DesyncState.cameraAnchor = nil
	end
	DesyncState.serverPosition = nil
	DesyncStorage.ServerPosition = nil
	DesyncStorage.ClientPosition = nil
	DesyncStorage.Distance = 0
	DesyncStorage.IsActive = false
	desyncDebugCounter = 0
	updateDesyncLabels()
	Library:Notify('DESYNC: Disabled', 2)
end
DesyncState.serverPosLabel = DesyncBox:AddLabel('Server (A): -')
DesyncState.clientPosLabel = DesyncBox:AddLabel('Client (B): -')
DesyncState.chamsEnabled = DesyncState.chamsEnabled or false
DesyncState.ghostModel = DesyncState.ghostModel or nil
DesyncState.chamsColor = DesyncState.chamsColor or Color3.fromRGB(0, 255, 255)
DesyncState.chamsOpacity = DesyncState.chamsOpacity or 0.3
DesyncState.ghostConnection = DesyncState.ghostConnection or nil
DesyncState.rotationAngle = DesyncState.rotationAngle or 0
local function createDesyncGhost()
	if not LocalPlayer.Character then
		return nil
	end
	if DesyncState.ghostModel then
		pcall(function() DesyncState.ghostModel:Destroy() end)
		DesyncState.ghostModel = nil
	end
	local char = LocalPlayer.Character
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local startCFrame = hrp.CFrame
	DesyncState.ghostModel = Instance.new("Model")
	DesyncState.ghostModel.Name = "StarshipDesyncServerModel"
	local basePlate = Instance.new("Part")
	basePlate.Name = "BasePlate"
	basePlate.Size = Vector3.new(4, 0.2, 4)
	basePlate.CFrame = startCFrame * CFrame.new(0, -3, 0)
	basePlate.Anchored = true
	basePlate.CanCollide = false
	basePlate.Transparency = DesyncState.chamsOpacity
	basePlate.Material = Enum.Material.Neon
	basePlate.Color = DesyncState.chamsColor
	basePlate.CastShadow = false
	basePlate.Parent = DesyncState.ghostModel
	Instance.new("CylinderMesh").Parent = basePlate
	local verticalBeam = Instance.new("Part")
	verticalBeam.Name = "VerticalBeam"
	verticalBeam.Size = Vector3.new(0.3, 50, 0.3)
	verticalBeam.CFrame = startCFrame * CFrame.new(0, 25, 0)
	verticalBeam.Anchored = true
	verticalBeam.CanCollide = false
	verticalBeam.Transparency = math.min(DesyncState.chamsOpacity + 0.2, 0.9)
	verticalBeam.Material = Enum.Material.Neon
	verticalBeam.Color = DesyncState.chamsColor
	verticalBeam.CastShadow = false
	verticalBeam.Parent = DesyncState.ghostModel
	DesyncState.ghostModel.Parent = workspace
	DesyncState.rotationAngle = 0
	return DesyncState.ghostModel
end
local function updateDesyncGhost()
	if not DesyncState.ghostModel then return end
	if not LocalPlayer.Character then return end
	local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local isDesyncActive = _G.StarshipDesyncStorage and _G.StarshipDesyncStorage.IsActive and
	_G.StarshipDesyncStorage.ServerPosition
	local serverCFrame = nil
	if isDesyncActive then
		serverCFrame = _G.StarshipDesyncStorage.ServerPosition
	else
		serverCFrame = hrp.CFrame
	end
	DesyncState.rotationAngle = DesyncState.rotationAngle + 2
	local basePlate = DesyncState.ghostModel and DesyncState.ghostModel:FindFirstChild("BasePlate")
	local verticalBeam = DesyncState.ghostModel and DesyncState.ghostModel:FindFirstChild("VerticalBeam")
	local showOpacity = isDesyncActive and DesyncState.chamsOpacity or 1
	local beamOpacity = isDesyncActive and math.min(DesyncState.chamsOpacity + 0.2, 0.9) or 1
	if basePlate then
		basePlate.CFrame = serverCFrame * CFrame.new(0, -3, 0) *
		CFrame.Angles(0, math.rad(DesyncState.rotationAngle), 0)
		basePlate.Color = DesyncState.chamsColor
		basePlate.Transparency = showOpacity
	end
	if verticalBeam then
		verticalBeam.CFrame = serverCFrame * CFrame.new(0, 25, 0)
		verticalBeam.Color = DesyncState.chamsColor
		verticalBeam.Transparency = beamOpacity
	end
end
DesyncBox:AddToggle('DesyncToggle', {
Text = 'Desync',
Default = false,
Tooltip = 'Server sees frozen position, you move freely',
Callback = function(Value)
DesyncState.enabled = Value
DesyncState.chamsEnabled = Value
if Value then
	if not Toggles.DesyncToggle.Value then
		DesyncState.enabled = false
		DesyncState.chamsEnabled = false
		return
	end
	startTrueDesync()
	local ghost = createDesyncGhost()
	if ghost then
		DesyncState.ghostConnection = RunService.Heartbeat:Connect(function()
		if not Toggles.DesyncToggle.Value then
			if DesyncState.ghostConnection then DesyncState.ghostConnection:Disconnect() end
			DesyncState.ghostConnection = nil
			return
		end
		if DesyncState.chamsEnabled and DesyncState.ghostModel and LocalPlayer.Character then
			pcall(function()
			updateDesyncGhost()
		end)
	end
end)
end
else
	stopTrueDesync()
	if DesyncState.ghostConnection then
		DesyncState.ghostConnection:Disconnect()
		DesyncState.ghostConnection = nil
	end
	if DesyncState.ghostModel then
		DesyncState.ghostModel:Destroy()
		DesyncState.ghostModel = nil
	end
end
end
}):AddColorPicker('DesyncChamsColor', {
Default = Color3.fromRGB(0, 255, 255),
Title = 'Ghost Color',
Transparency = 0.3,
Callback = function(Value)
DesyncState.chamsColor = Value
if Options.DesyncChamsColor then
	DesyncState.chamsOpacity = Options.DesyncChamsColor.Transparency
end
if DesyncState.chamsEnabled and DesyncState.ghostModel then
	updateDesyncGhost()
end
end
}):AddKeyPicker('DesyncKey', {
Default = 'None',
Text = 'Desync',
Mode = 'Hold',
SyncToggleState = true,
})
LocalPlayer.CharacterAdded:Connect(function()
if DesyncState.chamsEnabled then
	task.wait(1)
	createDesyncGhost()
end
end)
end
SafeInit(InitDesyncBox, 'InitDesyncBox')
local function InitLagSwitch()
	local LagSwitchBox = Tabs.AntiAim:AddLeftGroupbox('Lag Switch', 'rat')
	_G.StarshipLagSwitch = _G.StarshipLagSwitch or {}
	local LagSwitch = _G.StarshipLagSwitch
	LagSwitch.active = LagSwitch.active or false
	LagSwitch.held = LagSwitch.held or false
	LagSwitch.storedPosition = LagSwitch.storedPosition or nil
	LagSwitch.storedVelocity = LagSwitch.storedVelocity or nil
	LagSwitch.chamsEnabled = LagSwitch.chamsEnabled or false
	LagSwitch.ghostModel = LagSwitch.ghostModel or nil
	LagSwitch.chamsColor = LagSwitch.chamsColor or Color3.fromRGB(255, 0, 255)
	LagSwitch.chamsOpacity = LagSwitch.chamsOpacity or 0.3
	LagSwitch.ghostConnection = LagSwitch.ghostConnection or nil
	LagSwitch.rotationAngle = LagSwitch.rotationAngle or 0
	local LagSw = LagSwitchBox:AddToggle('LagSwitch', {
	Text = 'Lag Switch',
	Default = false,
	Tooltip = 'Hold key to freeze, release to snap back',
	Callback = function(Value)
	if Value then
		if not Toggles.LagSwitch.Value then
			return
		end
		LagSwitch.active = true
		LagSwitch.chamsEnabled = true
		LagSwitch.held = true
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
			LagSwitch.storedPosition = LocalPlayer.Character.HumanoidRootPart.CFrame
			LagSwitch.storedVelocity = LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity
		end
		local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local ghost = nil
		if hrp then
			LagSwitch.ghostModel = _G.StarshipGhostHelpers.CreateLagSwitchGhostModel(hrp.CFrame,
			LagSwitch.chamsColor, LagSwitch.chamsOpacity)
			LagSwitch.rotationAngle = 0
			ghost = LagSwitch.ghostModel
		end
		if ghost then
			LagSwitch.ghostConnection = RunService.Heartbeat:Connect(function()
			if not Toggles.LagSwitch.Value then
				if LagSwitch.ghostConnection then LagSwitch.ghostConnection:Disconnect() end
				LagSwitch.ghostConnection = nil
				return
			end
			if LagSwitch.chamsEnabled and LagSwitch.ghostModel and LocalPlayer.Character then
				pcall(function()
				local target = LagSwitch.storedPosition or
				(LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.CFrame)
				LagSwitch.rotationAngle = _G.StarshipGhostHelpers.UpdateLagSwitchGhostModel(
				LagSwitch.ghostModel, LagSwitch.rotationAngle, target, LagSwitch.held,
				LagSwitch.chamsColor, LagSwitch.chamsOpacity)
			end)
		end
	end)
end
else
	LagSwitch.active = false
	LagSwitch.chamsEnabled = false
	if LagSwitch.held then
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LagSwitch.storedPosition then
			LocalPlayer.Character.HumanoidRootPart.CFrame = LagSwitch.storedPosition
		end
		LagSwitch.held = false
		LagSwitch.storedPosition = nil
	end
	if LagSwitch.ghostConnection then
		LagSwitch.ghostConnection:Disconnect()
		LagSwitch.ghostConnection = nil
	end
	if LagSwitch.ghostModel then
		LagSwitch.ghostModel:Destroy()
		LagSwitch.ghostModel = nil
	end
end
end
}):AddColorPicker('LagSwitchChamsColor', {
Default = Color3.fromRGB(255, 0, 255),
Title = 'Ghost Color',
Transparency = 0.3,
Callback = function(Value)
LagSwitch.chamsColor = Value
if Options.LagSwitchChamsColor then
	LagSwitch.chamsOpacity = Options.LagSwitchChamsColor.Transparency
end
if LagSwitch.chamsEnabled and LagSwitch.ghostModel then
	local target = LagSwitch.storedPosition or
	(LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.CFrame)
	LagSwitch.rotationAngle = _G.StarshipGhostHelpers.UpdateLagSwitchGhostModel(LagSwitch.ghostModel,
	LagSwitch.rotationAngle, target, LagSwitch.held, LagSwitch.chamsColor, LagSwitch
	.chamsOpacity)
end
end
}):AddKeyPicker('LagSwitchKey', {
Default = 'None',
Text = 'Lag Switch',
Mode = 'Hold',
SyncToggleState = true,
})
PremiumOnly(LagSw)
LagSwitchBox:AddSlider('BlinkDistance', {
Text = 'Blink Distance',
Default = 10,
Min = 5,
Max = 50,
Rounding = 0,
Suffix = ' studs',
})
LagSwitchBox:AddButton({
Text = 'Blink Forward',
Tooltip = 'Instant teleport forward',
Func = function()
if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
	local hrp = LocalPlayer.Character.HumanoidRootPart
	local dist = Options.BlinkDistance and Options.BlinkDistance.Value or 10
	hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * dist
	Library:Notify('Blinked ' .. dist .. ' studs!', 1)
end
end
})
LagSwitchBox:AddToggle('BlinkKeybindToggle', {
Text = 'Blink Keybind',
Default = false,
Tooltip = 'Enable keybind for quick blink',
}):AddKeyPicker('BlinkKey', {
Default = 'None',
Text = 'Blink',
Mode = 'Hold',
Callback = function(Value)
if Value and Toggles.BlinkKeybindToggle and Toggles.BlinkKeybindToggle.Value then
	if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
		local hrp = LocalPlayer.Character.HumanoidRootPart
		local dist = Options.BlinkDistance and Options.BlinkDistance.Value or 10
		hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * dist
		Library:Notify('Blinked ' .. dist .. ' studs!', 1)
	end
end
end
})
LocalPlayer.CharacterAdded:Connect(function()
task.wait(1)
if LagSwitch.chamsEnabled then
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		if LagSwitch.ghostModel then pcall(function() LagSwitch.ghostModel:Destroy() end) end
		LagSwitch.ghostModel = _G.StarshipGhostHelpers.CreateLagSwitchGhostModel(hrp.CFrame,
		LagSwitch.chamsColor, LagSwitch.chamsOpacity)
		LagSwitch.rotationAngle = 0
	end
end
end)
end
SafeInit(InitLagSwitch, 'InitLagSwitch')
_G.StarshipGhostHelpers = _G.StarshipGhostHelpers or {}
_G.StarshipGhostHelpers.BuildGhostModel = function(modelName, startCFrame, color, transparency)
local model = Instance.new("Model")
model.Name = modelName
local function makePart(parent, name, size, cf, colorVal, transp, meshType)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = transp
	p.Material = Enum.Material.Neon
	p.Color = colorVal
	p.CastShadow = false
	p.Parent = parent
	if meshType == "cylinder" then
		Instance.new("CylinderMesh").Parent = p
	end
	return p
end
makePart(model, "BasePlate", Vector3.new(4, 0.2, 4), startCFrame * CFrame.new(0, -3, 0), color, transparency,
"cylinder")
makePart(model, "VerticalBeam", Vector3.new(0.3, 50, 0.3), startCFrame * CFrame.new(0, 25, 0), color,
transparency)
model.Parent = workspace
return model
end
_G.StarshipGhostHelpers.CreateLagSwitchGhostModel = function(startCFrame, color, opacity)
return _G.StarshipGhostHelpers.BuildGhostModel("StarshipLagSwitchServerModel", startCFrame,
color or Color3.fromRGB(255, 0, 255), opacity or 0.3)
end
_G.StarshipGhostHelpers.UpdateLagSwitchGhostModel = function(model, rotationAngle, targetCFrame, isHolding, color,
opacity)
if not model or not targetCFrame then return rotationAngle end
rotationAngle = (rotationAngle or 0) + 2
local showOpacity = isHolding and (opacity or 0.3) or 1
local beamOpacity = isHolding and math.min((opacity or 0.3) + 0.2, 0.9) or 1
local basePlate = model:FindFirstChild("BasePlate")
local verticalBeam = model:FindFirstChild("VerticalBeam")
if basePlate then
	basePlate.CFrame = targetCFrame * CFrame.new(0, -3, 0) * CFrame.Angles(0, math.rad(rotationAngle), 0)
	basePlate.Color = color or basePlate.Color
	basePlate.Transparency = showOpacity
end
if verticalBeam then
	verticalBeam.CFrame = targetCFrame * CFrame.new(0, 25, 0)
	verticalBeam.Color = color or verticalBeam.Color
	verticalBeam.Transparency = beamOpacity
end
return rotationAngle
end
_G.StarshipGhostHelpers.CreateFakeLagGhostModel = function(startCFrame, color, opacity)
return _G.StarshipGhostHelpers.BuildGhostModel("StarshipFakeLagServerModel", startCFrame,
color or Color3.fromRGB(0, 255, 0), opacity or 0.3)
end
_G.StarshipGhostHelpers.UpdateFakeLagGhostModel = function(model, rotationAngle, targetCFrame, isActive, color,
opacity)
if not model or not targetCFrame then return rotationAngle end
rotationAngle = (rotationAngle or 0) + 2
local showOpacity = isActive and (opacity or 0.3) or 1
local beamOpacity = isActive and math.min((opacity or 0.3) + 0.2, 0.9) or 1
local basePlate = model:FindFirstChild("BasePlate")
local verticalBeam = model:FindFirstChild("VerticalBeam")
if basePlate then
	basePlate.CFrame = targetCFrame * CFrame.new(0, -3, 0) * CFrame.Angles(0, math.rad(rotationAngle), 0)
	basePlate.Color = color or basePlate.Color
	basePlate.Transparency = showOpacity
end
if verticalBeam then
	verticalBeam.CFrame = targetCFrame * CFrame.new(0, 25, 0)
	verticalBeam.Color = color or verticalBeam.Color
	verticalBeam.Transparency = beamOpacity
end
return rotationAngle
end
_G.StarshipGhostHelpers.RunSimpleFakeLag = function(state)
if not state then return end
state.active = true
while state.active and state.enabled do
	pcall(function()
	if not LocalPlayer.Character then return end
	local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	state.storage.ServerPosition = hrp.CFrame
	state.storage.IsAnchored = true
	hrp.Anchored = true
	local freezeTime = state.duration / 1000
	task.wait(freezeTime)
	hrp.Anchored = false
	state.storage.IsAnchored = false
	state.storage.ServerPosition = nil
end)
local waitTime = (state.interval / 1000) * (state.intensity / 5)
task.wait(math.max(0.03, waitTime))
end
state.active = false
pcall(function()
if LocalPlayer.Character then
	local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.Anchored = false end
end
end)
end
do
	local FakeLagBox = Tabs.AntiAim:AddRightGroupbox('Fake Lag', 'zap-off')
	local FakeLag = {
	enabled = false,
	active = false,
	intensity = 5,
	duration = 50,
	interval = 100,
	chamsEnabled = false,
	ghostModel = nil,
	chamsColor = Color3.fromRGB(0, 255, 0),
	chamsOpacity = 0.3,
	ghostConnection = nil,
	rotationAngle = 0,
	storage = {
	ServerPosition = nil,
	IsAnchored = false
	}
	}
	_G.StarshipFakeLagStorage = FakeLag.storage
	FakeLagBox:AddToggle('FakeLag', {
	Text = 'Fake Lag',
	Default = false,
	Tooltip = 'Makes you stutter/freeze periodically on server',
	Callback = function(Value)
	FakeLag.enabled = Value
	FakeLag.chamsEnabled = Value
	if Value then
		if not Toggles.FakeLag.Value then
			FakeLag.enabled = false
			FakeLag.chamsEnabled = false
			return
		end
		if not FakeLag.active then
			task.spawn(function() _G.StarshipGhostHelpers.RunSimpleFakeLag(FakeLag) end)
		end
		local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local ghost = nil
		if hrp then
			FakeLag.ghostModel = _G.StarshipGhostHelpers.CreateFakeLagGhostModel(hrp.CFrame,
			FakeLag.chamsColor, 1)
			FakeLag.rotationAngle = 0
			ghost = FakeLag.ghostModel
		end
		if ghost then
			FakeLag.ghostConnection = RunService.Heartbeat:Connect(function()
			if not Toggles.FakeLag.Value then
				if FakeLag.ghostConnection then FakeLag.ghostConnection:Disconnect() end
				FakeLag.ghostConnection = nil
				return
			end
			if FakeLag.chamsEnabled and FakeLag.ghostModel and LocalPlayer.Character then
				pcall(function()
				local isActive = FakeLag.storage.IsAnchored and FakeLag.storage.ServerPosition
				local target = FakeLag.storage.ServerPosition or
				(LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.CFrame)
				FakeLag.rotationAngle = _G.StarshipGhostHelpers.UpdateFakeLagGhostModel(
				FakeLag.ghostModel, FakeLag.rotationAngle, target, isActive,
				FakeLag.chamsColor,
				FakeLag.chamsOpacity)
			end)
		end
	end)
end
Library:Notify('Fake Lag: ON (Intensity ' .. FakeLag.intensity .. ')', 2)
else
	FakeLag.active = false
	pcall(function()
	if LocalPlayer.Character then
		local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored = false end
	end
end)
if FakeLag.ghostConnection then
	FakeLag.ghostConnection:Disconnect()
	FakeLag.ghostConnection = nil
end
if FakeLag.ghostModel then
	FakeLag.ghostModel:Destroy()
	FakeLag.ghostModel = nil
end
Library:Notify('Fake Lag: OFF', 2)
end
end
}):AddColorPicker('FakeLagChamsColor', {
Default = Color3.fromRGB(0, 255, 0),
Title = 'Ghost Color',
Transparency = 0.3,
Callback = function(Value)
FakeLag.chamsColor = Value
if Options.FakeLagChamsColor then
	FakeLag.chamsOpacity = Options.FakeLagChamsColor.Transparency
end
if FakeLag.chamsEnabled and FakeLag.ghostModel then
	local isActive = FakeLag.storage.IsAnchored and FakeLag.storage.ServerPosition
	local target = FakeLag.storage.ServerPosition or
	(LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.CFrame)
	FakeLag.rotationAngle = _G.StarshipGhostHelpers.UpdateFakeLagGhostModel(FakeLag.ghostModel,
	FakeLag.rotationAngle, target, isActive, FakeLag.chamsColor, FakeLag.chamsOpacity)
end
end
}):AddKeyPicker('FakeLagKey', {
Default = 'None',
Text = 'Fake Lag',
Mode = 'Hold',
SyncToggleState = true,
})
FakeLagBox:AddSlider('FakeLagIntensity', {
Text = 'Intensity',
Default = 5,
Min = 1,
Max = 15,
Rounding = 0,
Tooltip = 'Lower = More frequent stutter, Higher = Subtler',
Callback = function(Value)
FakeLag.intensity = Value
if FakeLag.enabled then
	Library:Notify('Fake Lag Intensity: ' .. Value, 1)
end
end
})
FakeLagBox:AddSlider('FakeLagDuration', {
Text = 'Freeze Duration',
Default = 50,
Min = 20,
Max = 200,
Rounding = 0,
Suffix = 'ms',
Tooltip = 'How long to freeze each time',
Callback = function(Value)
FakeLag.duration = Value
end
})
FakeLagBox:AddSlider('FakeLagInterval', {
Text = 'Freeze Interval',
Default = 100,
Min = 50,
Max = 500,
Rounding = 0,
Suffix = 'ms',
Tooltip = 'Time between freezes',
Callback = function(Value)
FakeLag.interval = Value
end
})
LocalPlayer.CharacterAdded:Connect(function()
task.wait(1)
if FakeLag.chamsEnabled then
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		if FakeLag.ghostModel then pcall(function() FakeLag.ghostModel:Destroy() end) end
		FakeLag.ghostModel = _G.StarshipGhostHelpers.CreateFakeLagGhostModel(hrp.CFrame,
		FakeLag.chamsColor, 1)
		FakeLag.rotationAngle = 0
	end
end
end)
end
local function InitAntiAimBoxScope()
	local AntiAimBox = Tabs.AntiAim:AddRightGroupbox('Anti-Aim', 'navigation-2-off')
	local AntiAimState = {
	enabled = false,
	conn = nil,
	mode = "spin",
	yaw = 0,
	pitch = 0,
	speed = 1000
	}
	AntiAimBox:AddToggle('AntiAim', {
	Text = 'Anti-Aim',
	Default = false,
	Tooltip = 'Manipulate your character angle to confuse aimers',
	Callback = function(Value)
	AntiAimState.enabled = Value
	if Value then
		if AntiAimState.conn then AntiAimState.conn:Disconnect() end
		AntiAimState.conn = RunService.RenderStepped:Connect(function()
		if not Toggles.AntiAim.Value then
			if AntiAimState.conn then AntiAimState.conn:Disconnect() end
			AntiAimState.conn = nil
			return
		end
		if not LocalPlayer.Character then return end
		local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local currentCF = hrp.CFrame
		local pos = currentCF.Position
		if AntiAimState.mode == "spin" then
			AntiAimState.yaw = (AntiAimState.yaw + AntiAimState.speed) % 360
			hrp.CFrame = CFrame.new(pos) *
			CFrame.Angles(math.rad(AntiAimState.pitch), math.rad(AntiAimState.yaw), 0)
		elseif AntiAimState.mode == "jitter" then
			AntiAimState.yaw = AntiAimState.yaw +
			(math.random() > 0.5 and AntiAimState.speed or -AntiAimState.speed)
			hrp.CFrame = CFrame.new(pos) *
			CFrame.Angles(math.rad(AntiAimState.pitch), math.rad(AntiAimState.yaw), 0)
		elseif AntiAimState.mode == "random" then
			local randYaw = math.random(0, 360)
			hrp.CFrame = CFrame.new(pos) *
			CFrame.Angles(math.rad(AntiAimState.pitch), math.rad(randYaw), 0)
		elseif AntiAimState.mode == "static" then
			hrp.CFrame = CFrame.new(pos) *
			CFrame.Angles(math.rad(AntiAimState.pitch), math.rad(AntiAimState.yaw), 0)
		end
	end)
	Library:Notify('Anti-Aim: ON (' .. AntiAimState.mode .. ')', 2)
else
	if AntiAimState.conn then
		AntiAimState.conn:Disconnect(); AntiAimState.conn = nil
	end
	Library:Notify('Anti-Aim: OFF', 2)
end
end
}):AddKeyPicker('AntiAimKey', {
Default = 'None',
Text = 'Anti-Aim',
Mode = 'Hold',
SyncToggleState = true,
})
AntiAimBox:AddToggle('RapidAAChange', {
Text = 'Rapid AA Mode Switch',
Default = false,
Tooltip = 'Rapidly switch between anti-aim modes',
Callback = function(Value)
if Value then
	task.spawn(function()
	local modes = { 'spin', 'jitter', 'random' }
	while Toggles.RapidAAChange and Toggles.RapidAAChange.Value do
		AntiAimState.mode = modes[math.random(1, #modes)]
		task.wait(0.5)
	end
end)
Library:Notify('Rapid AA Change: ON', 2)
else
	Library:Notify('Rapid AA Change: OFF', 2)
end
end
})
AntiAimBox:AddDropdown('AntiAimMode', {
Default = 'Spin',
Values = { 'Spin', 'Jitter', 'Random', 'Static' },
Tooltip = 'Spin = Continuous, Jitter = Back/forth, Random = Chaotic, Static = Fixed angle',
Callback = function(Value)
if Value == nil or Value == '' then return end
AntiAimState.mode = Value:lower()
-- Library:Notify('Anti-Aim Mode: ' .. Value, 2)
end
})
AntiAimBox:AddSlider('AntiAimSpeed', {
Text = 'Speed (Spin/Jitter)',
Default = 1000,
Min = 100,
Max = 5000,
Rounding = 0,
Suffix = ' deg/frame',
Callback = function(Value)
AntiAimState.speed = Value
end
})
AntiAimBox:AddDropdown('PitchPreset', {
Text = 'Pitch Preset',
Default = 'None',
Values = { 'None', 'Up (90°)', 'Down (-90°)', 'Fake Up (45°)', 'Fake Down (-45°)' },
Tooltip = 'Quick pitch angle presets',
Callback = function(Value)
if Value == nil or Value == '' then return end
if Value == 'None' then
	AntiAimState.pitch = 0
elseif Value == 'Up (90°)' then
	AntiAimState.pitch = 90
elseif Value == 'Down (-90°)' then
	AntiAimState.pitch = -90
elseif Value == 'Fake Up (45°)' then
	AntiAimState.pitch = 45
elseif Value == 'Fake Down (-45°)' then
	AntiAimState.pitch = -45
end
if Options.PitchSlider then
	Options.PitchSlider:SetValue(AntiAimState.pitch)
end
end
})
AntiAimBox:AddSlider('PitchSlider', {
Text = 'Custom Pitch',
Default = 0,
Min = -90,
Max = 90,
Rounding = 0,
Suffix = '°',
Tooltip = 'Look angle: Negative = Down, Positive = Up',
Callback = function(Value)
AntiAimState.pitch = Value
end
})
AntiAimBox:AddSlider('YawSlider', {
Text = 'Static Yaw (for Static mode)',
Default = 0,
Min = 0,
Max = 360,
Rounding = 0,
Suffix = '°',
Tooltip = 'Fixed yaw angle when using Static mode',
Callback = function(Value)
if AntiAimState.mode == "static" then
	AntiAimState.yaw = Value
end
end
})
end
SafeInit(InitAntiAimBoxScope, 'InitAntiAimBoxScope')
end
SafeInit(Init.AntiAimTab, 'InitAntiAimTab')
Init.MiscTab = function()
local MovementBox = Tabs.Misc:AddLeftGroupbox('Movement', 'move')
MovementBox:AddSlider('MiscJumpPower', {
Text = 'Jump Power',
Default = 50,
Min = 0,
Max = 200,
Rounding = 0,
Callback = function(Value)
if LocalPlayer.Character then
	local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.JumpPower = Value
	end
end
end
})
MovementBox:AddSlider('Gravity', {
Text = 'Gravity',
Default = 196.2,
Min = 0,
Max = 500,
Rounding = 1,
Callback = function(Value)
workspace.Gravity = Value
end
})
local _noclipSavedCollision = {}
local NoclipToggle = MovementBox:AddToggle('MiscNoclip', {
Text = 'Noclip',
Default = false,
Tooltip = 'Walk through walls',
Callback = function(Value)
if Value then
	_noclipSavedCollision = {}
	if LocalPlayer.Character then
		for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
			if part:IsA("BasePart") then
				_noclipSavedCollision[part] = part.CanCollide
			end
		end
	end
	local noclipConn
	noclipConn = RunService.Stepped:Connect(function()
	if not Toggles.MiscNoclip or not Toggles.MiscNoclip.Value then
		noclipConn:Disconnect()
		if LocalPlayer.Character then
			for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
				if part:IsA("BasePart") then
					local saved = _noclipSavedCollision[part]
					part.CanCollide = (saved ~= nil) and saved or part.CanCollide
				end
			end
		end
		_noclipSavedCollision = {}
		return
	end
	if LocalPlayer.Character then
		for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end
end)
Library:Notify('Noclip: Enabled', 2)
else
	Library:Notify('Noclip: Disabled', 2)
end
end
}):AddKeyPicker('MiscNoclipKey', {
Default = 'None',
Text = 'Noclip',
Mode = 'Toggle',
SyncToggleState = true,
})
local FlyToggle = MovementBox:AddToggle('MiscFly', {
Text = 'Fly',
Default = false,
Tooltip = 'Fly around the map',
Callback = function(Value)
local flySpeed = (Options.MiscFlySpeed and Options.MiscFlySpeed.Value) or 50
local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local hrp = char:WaitForChild('HumanoidRootPart')
if Value then
	local bg = hrp:FindFirstChild('StarshipFlyGyro') or Instance.new('BodyGyro')
	bg.Name = 'StarshipFlyGyro'
	bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bg.P = 100000
	bg.Parent = hrp
	local bv = hrp:FindFirstChild('StarshipFlyVelocity') or Instance.new('BodyVelocity')
	bv.Name = 'StarshipFlyVelocity'
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity = Vector3.new()
	bv.Parent = hrp
	local flyConnection
	flyConnection = RunService.RenderStepped:Connect(function()
	if not Toggles.MiscFly or not Toggles.MiscFly.Value then
		flyConnection:Disconnect()
		return
	end
	local cam = workspace.CurrentCamera
	local speed = (Options.MiscFlySpeed and Options.MiscFlySpeed.Value) or 50
	local velocity = Vector3.new()
	bg.CFrame = cam.CFrame
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		velocity = velocity + cam.CFrame.LookVector * speed
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		velocity = velocity - cam.CFrame.LookVector * speed
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		velocity = velocity - cam.CFrame.RightVector * speed
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		velocity = velocity + cam.CFrame.RightVector * speed
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		velocity = velocity + Vector3.new(0, speed, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		velocity = velocity - Vector3.new(0, speed, 0)
	end
	bv.Velocity = velocity
end)
Library:Notify('Fly: Enabled', 2)
else
	local bv = hrp:FindFirstChild('StarshipFlyVelocity')
	local bg = hrp:FindFirstChild('StarshipFlyGyro')
	if bv then bv:Destroy() end
	if bg then bg:Destroy() end
	Library:Notify('Fly: Disabled', 2)
end
end
}):AddKeyPicker('MiscFlyKey', {
Default = 'None',
Text = 'Fly',
Mode = 'Toggle',
SyncToggleState = true,
})
MovementBox:AddSlider('MiscFlySpeed', {
Text = 'Fly Speed',
Default = 50,
Min = 10,
Max = 300,
Rounding = 0,
})
MovementBox:AddToggle('MiscInfJump', {
Text = 'Infinite Jump',
Default = false,
Tooltip = 'Jump infinitely in the air',
}):AddKeyPicker('MiscInfJumpKey', {
Default = 'None',
Text = 'Infinite Jump',
Mode = 'Toggle',
SyncToggleState = true,
})
UserInputService.JumpRequest:Connect(function()
if Toggles.MiscInfJump and Toggles.MiscInfJump.Value then
	if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
		LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end
end)
GFS.MorphAvatar = GFS.MorphAvatar or {}
GFS.MorphAvatar.TargetUsername = ""
GFS.MorphAvatar.ApplyEffect = function(character)
local rootPart = character:FindFirstChild("HumanoidRootPart")
if not rootPart then return end
pcall(function()
local particleEmitter = Instance.new("ParticleEmitter")
particleEmitter.Texture = "rbxassetid://243098098"
particleEmitter.Rate = 50
particleEmitter.Speed = NumberRange.new(5, 10)
particleEmitter.Lifetime = NumberRange.new(0.5, 1)
particleEmitter.SpreadAngle = Vector2.new(360, 360)
particleEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 50, 50))
particleEmitter.Parent = rootPart
local explosion = Instance.new("Explosion")
explosion.BlastRadius = 5
explosion.BlastPressure = 0
explosion.Position = rootPart.Position
explosion.Visible = true
explosion.Parent = workspace
explosion.ExplosionType = Enum.ExplosionType.NoCraters
task.spawn(function()
task.wait(2)
particleEmitter.Enabled = false
task.wait(1)
pcall(function() particleEmitter:Destroy() end)
pcall(function() explosion:Destroy() end)
end)
end)
end
GFS.MorphAvatar.FindPlayer = function(partialName)
if not partialName or partialName == "" then return nil end
local searchName = partialName:lower()
local foundPlayer = nil
for _, v in ipairs(Players:GetPlayers()) do
	local nameLower = v.Name:lower()
	local dNameLower = v.DisplayName:lower()
	if nameLower == searchName or dNameLower == searchName then
		return v
	end
	if nameLower:sub(1, #searchName) == searchName or dNameLower:sub(1, #searchName) == searchName then
		foundPlayer = v
	end
end
if not foundPlayer then
	local success, userId = pcall(function()
	return Players:GetUserIdFromNameAsync(searchName)
end)
if success and userId then
	return { UserId = userId, Name = searchName }
end
end
return foundPlayer
end
GFS.MorphAvatar.DoMorph = function(targetName)
local target = GFS.MorphAvatar.FindPlayer(targetName)
if not target then
	Library:Notify("Morph Avatar: Player not found!", 3)
	return
end
local userId = target.UserId or (type(target) == "number" and target or target.UserId)
local targetNameStr = target.Name or "Unknown"
if userId == LocalPlayer.UserId then
	Library:Notify("Morph Avatar: Cannot morph to yourself!", 3)
	return
end
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid", 10)
if not humanoid then
	Library:Notify("Morph Avatar: Failed to find humanoid!", 3)
	return
end
local success, desc = pcall(function()
return Players:GetHumanoidDescriptionFromUserId(userId)
end)
if not success or not desc then
	Library:Notify("Morph Avatar: Failed to load avatar data!", 3)
	return
end
for _, obj in ipairs(character:GetChildren()) do
	if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or
	obj:IsA("Accessory") or obj:IsA("BodyColors") then
		pcall(function() obj:Destroy() end)
	end
end
local head = character:FindFirstChild("Head")
if head then
	for _, decal in ipairs(head:GetChildren()) do
		if decal:IsA("Decal") then pcall(function() decal:Destroy() end) end
	end
end
local applySuccess = pcall(function()
humanoid:ApplyDescriptionClientServer(desc)
end)
if applySuccess then
	GFS.MorphAvatar._morphedUserId = userId
	GFS.MorphAvatar._morphedName = targetNameStr
	GFS.MorphAvatar.ApplyEffect(character)
	task.spawn(function()
	_SetupMorphDescWatcher(character)
end)
Library:Notify("Morph Avatar: Successfully morphed to " .. targetNameStr .. "!", 3)
else
	Library:Notify("Morph Avatar: Failed to apply morph!", 3)
end
end
local MorphBox = Tabs.Misc:AddRightGroupbox('Morph Avatar', 'user-round')
MorphBox:AddInput('MorphUsernameInput', {
Default = '',
Placeholder = 'Enter Username',
Numeric = false,
Finished = true,
Callback = function(Value)
GFS.MorphAvatar.TargetUsername = Value
end
})
MorphBox:AddButton({
Text = 'Morph to Player',
Func = function()
local target = GFS.MorphAvatar.TargetUsername
if not target or target == "" then
	if Options.MorphUsernameInput and Options.MorphUsernameInput.Value then
		target = Options.MorphUsernameInput.Value
	end
end
if not target or target == "" then
	Library:Notify("Morph Avatar: Please enter a username!", 3)
	return
end
GFS.MorphAvatar.DoMorph(target)
end,
DoubleClick = false,
Tooltip = 'Transform your avatar to look like another player'
})
MorphBox:AddButton({
Text = 'Reset Avatar',
Func = function()
local character = LocalPlayer.Character
if not character then return end
local humanoid = character:FindFirstChild("Humanoid")
if humanoid then
	local success, desc = pcall(function()
	return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
end)
if success and desc then
	pcall(function() humanoid:ApplyDescriptionClientServer(desc) end)
	GFS.MorphAvatar._morphedUserId = nil
	GFS.MorphAvatar._morphedName = nil
	if GFS._MorphDescWatcherConn then
		pcall(function() GFS._MorphDescWatcherConn:Disconnect() end)
		GFS._MorphDescWatcherConn = nil
	end
	Library:Notify("Morph Avatar: Reset to original!", 3)
end
end
end,
DoubleClick = false,
Tooltip = 'Reset your avatar to your original appearance'
})
local ExploitsBox = Tabs.Misc:AddLeftGroupbox('Exploits', 'zap')
ExploitsBox:AddToggle('AntiAFK', {
Text = 'Anti-AFK',
Default = true,
Callback = function(Value)
if Value then
	LocalPlayer.Idled:Connect(function()
	if Toggles.AntiAFK and Toggles.AntiAFK.Value then
		VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
		task.wait(1)
		VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	end
end)
end
end
})
ExploitsBox:AddButton({
Text = 'Rejoin Server',
DoubleClick = true,
Func = function()
TeleportService:Teleport(game.PlaceId, LocalPlayer)
end
})
ExploitsBox:AddButton({
Text = 'Server Hop',
DoubleClick = true,
Func = function()
local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" ..
game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"))
if servers and servers.data then
	for _, server in ipairs(servers.data) do
		if server.id ~= game.JobId and server.playing < server.maxPlayers then
			TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
			return
		end
	end
end
warn("[Starship] No available servers found")
end
})
ExploitsBox:AddButton({
Text = 'Copy Game Link',
Func = function()
if setclipboard then
	setclipboard("https://www.roblox.com/games/" .. game.PlaceId)
	Library:Notify('Game link copied to clipboard!')
else
	warn("[Starship] Clipboard not supported")
end
end
})
ExploitsBox:AddButton({
Text = 'Reset Character',
Func = function()
if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
	LocalPlayer.Character.Humanoid.Health = 0
end
end
})
local CameraBox = Tabs.Misc:AddRightGroupbox('Camera', 'camera')
CameraBox:AddToggle('Freecam', {
Text = 'Freecam',
Default = false,
Tooltip = 'Full freecam with WASD + mouse look (PC) and thumbstick + touch drag (Mobile)',
Callback = function(Value)
Camera.FreecamEnabled = Value
local camera = workspace.CurrentCamera
local player = Players.LocalPlayer
if Value then
	Camera.OriginalCameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	Camera._freecamOrigPos = camera.CFrame
	local touchLook = {
	active = false,
	startPos = nil,
	lastPos = nil,
	touchId = nil,
	sensitivity = 0.004
	}
	local screenSize = camera.ViewportSize
	local function isRightHalf(pos)
		return pos.X > screenSize.X * 0.4
	end
	local touchConns = {}
	table.insert(touchConns, UserInputService.TouchStarted:Connect(function(input, processed)
	if not Camera.FreecamEnabled then return end
	if processed then return end
	if not touchLook.active and isRightHalf(input.Position) then
		touchLook.active = true
		touchLook.touchId = input
		touchLook.startPos = Vector2.new(input.Position.X, input.Position.Y)
		touchLook.lastPos = touchLook.startPos
	end
end))
table.insert(touchConns, UserInputService.TouchMoved:Connect(function(input, processed)
if not Camera.FreecamEnabled then return end
if touchLook.active and input == touchLook.touchId then
	local currentPos = Vector2.new(input.Position.X, input.Position.Y)
	local delta = currentPos - touchLook.lastPos
	touchLook.lastPos = currentPos
	local cam = workspace.CurrentCamera
	if cam then
		local rx, ry, rz = cam.CFrame:ToEulerAnglesYXZ()
		local newRx = math.clamp(rx - delta.Y * touchLook.sensitivity, -math.rad(89), math.rad(89))
		local newRy = ry - delta.X * touchLook.sensitivity
		cam.CFrame = CFrame.new(cam.CFrame.Position)
		* CFrame.Angles(0, newRy, 0)
		* CFrame.Angles(newRx, 0, 0)
	end
end
end))
table.insert(touchConns, UserInputService.TouchEnded:Connect(function(input)
if touchLook.active and input == touchLook.touchId then
	touchLook.active = false
	touchLook.touchId = nil
end
end))
Camera._freecamTouchConns = touchConns
local mouseLook = {
active = false,
sensitivity = 0.003
}
local mouseConns = {}
table.insert(mouseConns, UserInputService.InputBegan:Connect(function(input, processed)
if not Camera.FreecamEnabled then return end
if processed then return end
if input.UserInputType == Enum.UserInputType.MouseButton2 then
	mouseLook.active = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
end
end))
table.insert(mouseConns, UserInputService.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton2 then
	mouseLook.active = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end
end))
table.insert(mouseConns, UserInputService.InputChanged:Connect(function(input)
if not Camera.FreecamEnabled then return end
if input.UserInputType == Enum.UserInputType.MouseMovement and mouseLook.active then
	local delta = input.Delta
	local cam = workspace.CurrentCamera
	if cam then
		local rx, ry, rz = cam.CFrame:ToEulerAnglesYXZ()
		local newRx = math.clamp(rx - delta.Y * mouseLook.sensitivity, -math.rad(89), math.rad(89))
		local newRy = ry - delta.X * mouseLook.sensitivity
		cam.CFrame = CFrame.new(cam.CFrame.Position)
		* CFrame.Angles(0, newRy, 0)
		* CFrame.Angles(newRx, 0, 0)
	end
end
end))
Camera._freecamMouseConns = mouseConns
if Camera.FreecamConnection then Camera.FreecamConnection:Disconnect() end
Camera.FreecamConnection = RunService.RenderStepped:Connect(function(dt)
if not Camera.FreecamEnabled then return end
local cam = workspace.CurrentCamera
if not cam then return end
local baseSpeed = (Options.FreecamSpeed and Options.FreecamSpeed.Value or 1) * 50
local speedMult = 1
if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
	speedMult = 2.5
end
local speed = baseSpeed * speedMult * dt
local moveDir = Vector3.new(0, 0, 0)
if UserInputService:IsKeyDown(Enum.KeyCode.W) then
	moveDir = moveDir + cam.CFrame.LookVector
end
if UserInputService:IsKeyDown(Enum.KeyCode.S) then
	moveDir = moveDir - cam.CFrame.LookVector
end
if UserInputService:IsKeyDown(Enum.KeyCode.A) then
	moveDir = moveDir - cam.CFrame.RightVector
end
if UserInputService:IsKeyDown(Enum.KeyCode.D) then
	moveDir = moveDir + cam.CFrame.RightVector
end
if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
	moveDir = moveDir + Vector3.new(0, 1, 0)
end
if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
	moveDir = moveDir - Vector3.new(0, 1, 0)
end
if moveDir.Magnitude < 0.01 then
	pcall(function()
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.MoveDirection.Magnitude > 0.1 then
			local md = hum.MoveDirection
			local camLook = cam.CFrame.LookVector
			local camRight = cam.CFrame.RightVector
			local flatLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
			local flatRight = Vector3.new(camRight.X, 0, camRight.Z).Unit
			local forwardDot = md:Dot(Vector3.new(0, 0, -1))
			local rightDot = md:Dot(Vector3.new(1, 0, 0))
			moveDir = (cam.CFrame.LookVector * -forwardDot + cam.CFrame.RightVector * rightDot)
			* md.Magnitude
		end
	end
end)
end
if moveDir.Magnitude > 0.001 then
	cam.CFrame = cam.CFrame + (moveDir.Unit * speed)
end
if touchLook.active and touchLook.touchId then
end
end)
else
	if Camera.FreecamConnection then
		Camera.FreecamConnection:Disconnect()
		Camera.FreecamConnection = nil
	end
	if Camera._freecamTouchConns then
		for _, conn in pairs(Camera._freecamTouchConns) do
			pcall(function() conn:Disconnect() end)
		end
		Camera._freecamTouchConns = nil
	end
	if Camera._freecamMouseConns then
		for _, conn in pairs(Camera._freecamMouseConns) do
			pcall(function() conn:Disconnect() end)
		end
		Camera._freecamMouseConns = nil
	end
	pcall(function()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end)
camera.CameraType = Camera.OriginalCameraType or Enum.CameraType.Custom
camera.CameraSubject = player.Character and player.Character:FindFirstChild("Humanoid")
end
end
}):AddKeyPicker('FreecamKey', {
Default = 'None',
Text = 'Freecam',
Mode = 'Toggle',
SyncToggleState = true,
})
CameraBox:AddSlider('FreecamSpeed', {
Text = 'Speed',
Default = 1,
Min = 0.1,
Max = 5,
Rounding = 1,
})
end
SafeInit(Init.MiscTab, 'InitMiscTab')
Init.SettingsTab = function()
local MenuBox = Tabs.Settings:AddLeftGroupbox('Menu', 'menu')

MenuBox:AddToggle('ShowCustomCursor', {
Text = 'Custom Cursor',
Default = true,
Callback = function(Value)
Library.ShowCustomCursor = Value
end
})
MenuBox:AddKeyPicker('MenuKeybind', {
Default = 'End',
NoUI = true,
Text = 'Menu keybind',
Callback = function(Value)
    local key = Value
    if type(key) == "string" then
        pcall(function() key = Enum.KeyCode[key] end)
    end
    if Library.Window and Library.Window.SetToggleKey and typeof(key) == "EnumItem" then
        Library.Window:SetToggleKey(key)
        Library:Notify("Menu keybind updated to: " .. tostring(key.Name), 2)
    end
end
})
local HideNotifToggle = MenuBox:AddToggle('HideNotification', {
Text = 'Hide Notification',
Default = false,
Tooltip = IsPremium and 'Hide all notifications from Starship' or nil,
DisabledTooltip = 'Unlock this with premium',
Callback = function(Value)
GFS.HideNotification = Value
end
})
Library.ToggleKeybind = Options.MenuKeybind

-- Manual Config Management (in MenuBox)
MenuBox:AddDivider()
MenuBox:AddLabel('--- Configurations ---')

MenuBox:AddInput('ConfigName', {
    Text = 'New Name',
    Placeholder = 'Config name...',
    Default = ""
})

local ConfigList = MenuBox:AddDropdown('ConfigList', {
    Text = 'Saved Configs',
    Values = Library:GetConfigs(),
    Default = ""
})

MenuBox:AddButton({
    Text = 'Save Settings',
    Func = function()
        local name = (Options.ConfigName.Value ~= "") and Options.ConfigName.Value or Options.ConfigList.Value
        if name and name ~= "" then
            Library:SaveConfig(name)
            task.wait(0.2) -- File system delay
            local configs = Library:GetConfigs()
            ConfigList:SetValues(configs)
            ConfigList:SetValue(name)
            Library:Notify("Config saved & selected: " .. name, 2)
        else
            Library:Notify("Please specify a name!", 3)
        end
    end
})

MenuBox:AddButton({
    Text = 'Load Settings',
    Func = function()
        local name = Options.ConfigList.Value
        if name and name ~= "" then
            Library:LoadConfig(name)
        else
            Library:Notify("Please select a config!", 3)
        end
    end
})

MenuBox:AddButton({
    Text = 'Delete Config',
    Func = function()
        local name = Options.ConfigList.Value
        if name and name ~= "" then
            Library:DeleteConfig(name)
            task.wait(0.2)
            local configs = Library:GetConfigs()
            ConfigList:SetValues(configs)
            if #configs == 0 then
                ConfigList:SetValue("")
            else
                ConfigList:SetValue(configs[#configs] or "")
            end
            Library:Notify("Config deleted and list updated!", 2)
        end
    end
})

MenuBox:AddButton({
    Text = 'Refresh List',
    Func = function()
        task.wait(0.1)
        local configs = Library:GetConfigs()
        ConfigList:SetValues(configs)
        Options.ConfigName:SetValue("")
        Library:Notify("Configs refreshed: " .. tostring(#configs) .. " found", 2)
    end
})

end
SafeInit(Init.SettingsTab, 'InitSettingsTab')
task.spawn(function()
local function MonitorPlayer(player)
	if not player then return end
	player:GetPropertyChangedSignal("Team"):Connect(function()
	pcall(function()
	local teamName = player.Team and player.Team.Name or "None"
	local role = GetRoleName(player)
	if VDSettings.PlayerStatuses[player] then
	end
end)
end)
player.CharacterAdded:Connect(function(char)
task.wait(1)
pcall(function()
local role = GetRoleName(player)
char.ChildAdded:Connect(function(child)
if child.Name == "KillerTag" or child.Name == "IsKiller" then
end
end)
end)
end)
end
for _, p in ipairs(Players:GetPlayers()) do
	MonitorPlayer(p)
end
Players.PlayerAdded:Connect(MonitorPlayer)
end)
task.spawn(function()
while _G.StarshipActive and task.wait(0.5) do
	if Toggles.AutoMori and Toggles.AutoMori.Value then
		local StartMori = ReplicatedStorage.Remotes.Killers:FindFirstChild("Startmori")
		if StartMori then
			local range = 15
			local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if myRoot then
				for _, plr in pairs(Players:GetPlayers()) do
					if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
						local hum = plr.Character:FindFirstChild("Humanoid")
						local isKnocked = (hum and hum.Health < 5 and hum.Health > 0) or
						plr.Character:GetAttribute("Knocked") or plr.Character:GetAttribute("Downed")
						if isKnocked then
							local dist = (plr.Character.HumanoidRootPart.Position - myRoot.Position).Magnitude
							if dist <= range then
								StartMori:FireServer(plr.Character)
								local FireMoriCam = ReplicatedStorage.Remotes.Mechanics:FindFirstChild("Firemoricam")
								if FireMoriCam then FireMoriCam:FireServer(plr.Character) end
							end
						end
					end
				end
			end
		end
	end
end
end)
Library:SetWatermarkVisibility(true)
Library.Watermark = {
FrameTimer = tick(),
FrameCounter = 0,
FPS = 60,
Connection = nil
}
Library.Watermark.Connection = RunService.RenderStepped:Connect(function()
if not Library.WatermarkVisible then return end
Library.Watermark.FrameCounter = Library.Watermark.FrameCounter + 1
if (tick() - Library.Watermark.FrameTimer) >= 1 then
	Library.Watermark.FPS = Library.Watermark.FrameCounter
	Library.Watermark.FrameTimer = tick()
	Library.Watermark.FrameCounter = 0
end
Library:SetWatermark(('Starship | %s fps | %s ms'):format(
math.floor(Library.Watermark.FPS),
math.floor(Stats.Network.ServerStatsItem['Data Ping']:GetValue())
))
end)
pcall(function() Library.KeybindFrame.Visible = false end)
Library:OnUnload(function()
if Library.Watermark.Connection then Library.Watermark.Connection:Disconnect() end
end)
if SaveManager then SaveManager:LoadAutoloadConfig() end
local function InitMaskedDetection_Legacy()
	if not Tabs or not Tabs.Survivor then return end
	local MaskBox = Tabs.Survivor:AddRightGroupbox('The Masked Detection', 'hat-glasses')
	local MaskState = {
	Enabled = false,
	GUI = nil,
	DragInput = nil,
	DragStart = nil,
	StartPos = nil,
	Dragging = false
	}
	MaskBox:AddCheckbox('DetectMask', {
	Text = 'The Masked Indicator',
	Default = false,
	Tooltip = 'Opens a separate window showing The Masked killer info',
	Callback = function(Value)
	MaskState.Enabled = Value
	if Value then
		if not MaskState.GUI then
			local ScreenGui = Instance.new("ScreenGui")
			ScreenGui.Name = "StarshipMaskInfo"
			ScreenGui.Parent = game:GetService("CoreGui")
			ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			local Scheme = {
			MainColor = Color3.fromRGB(25, 25, 25),
			BackgroundColor = Color3.fromRGB(15, 15, 15),
			OutlineColor = Color3.fromRGB(40, 40, 40),
			AccentColor = Color3.fromRGB(125, 85, 255),
			FontColor = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.Code
			}
			if Library and Library.Scheme then
				for k, v in pairs(Library.Scheme) do
					Scheme[k] = v
				end
			end
			local MainFrame = Instance.new("Frame")
			MainFrame.Name = "MainFrame"
			MainFrame.Parent = ScreenGui
			MainFrame.BackgroundColor3 = Scheme.MainColor
			MainFrame.BorderColor3 = Scheme.OutlineColor
			MainFrame.BorderSizePixel = 1
			MainFrame.Position = UDim2.new(0.05, 0, 0.5, 0)
			MainFrame.Size = UDim2.new(0, 210, 0, 75)
			MainFrame.Active = true
			local TitleBar = Instance.new("Frame")
			TitleBar.Name = "TitleBar"
			TitleBar.Parent = MainFrame
			TitleBar.BackgroundColor3 = Scheme.MainColor
			TitleBar.BorderSizePixel = 0
			TitleBar.Size = UDim2.new(1, 0, 0, 20)
			TitleBar.ZIndex = 2
			local AccentStrip = Instance.new("Frame")
			AccentStrip.Name = "AccentStrip"
			AccentStrip.Parent = TitleBar
			AccentStrip.BackgroundColor3 = Scheme.AccentColor
			AccentStrip.BorderSizePixel = 0
			AccentStrip.Size = UDim2.new(1, 0, 0, 1)
			AccentStrip.ZIndex = 3
			task.spawn(function()
			if Library.Registry then
				table.insert(Library.Registry, AccentStrip)
				if Options.AccentColor then
					Options.AccentColor:OnChanged(function()
					AccentStrip.BackgroundColor3 = Options.AccentColor.Value
				end)
			end
		end
	end)
	local Title = Instance.new("TextLabel")
	Title.Name = "Title"
	Title.Parent = TitleBar
	Title.BackgroundTransparency = 1
	Title.Position = UDim2.new(0, 6, 0, 0)
	Title.Size = UDim2.new(1, -12, 1, 0)
	Title.Font = Scheme.Font
	Title.Text = "Killer Info"
	Title.TextColor3 = Scheme.FontColor
	Title.TextSize = 14
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.ZIndex = 4
	local Content = Instance.new("Frame")
	Content.Name = "Content"
	Content.Parent = MainFrame
	Content.BackgroundColor3 = Scheme.BackgroundColor
	Content.BorderColor3 = Scheme.OutlineColor
	Content.BorderSizePixel = 1
	Content.Position = UDim2.new(0, 6, 0, 26)
	Content.Size = UDim2.new(1, -12, 1, -32)
	Content.ZIndex = 2
	local StatusLabel = Instance.new("TextLabel")
	StatusLabel.Name = "StatusLabel"
	StatusLabel.Parent = Content
	StatusLabel.BackgroundTransparency = 1
	StatusLabel.Position = UDim2.new(0, 5, 0, 5)
	StatusLabel.Size = UDim2.new(1, -10, 0, 15)
	StatusLabel.Font = Scheme.Font
	StatusLabel.Text = "Status: Idle"
	StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	StatusLabel.TextSize = 13
	StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
	StatusLabel.ZIndex = 3
	local MaskLabel = Instance.new("TextLabel")
	MaskLabel.Name = "MaskLabel"
	MaskLabel.Parent = Content
	MaskLabel.BackgroundTransparency = 1
	MaskLabel.Position = UDim2.new(0, 5, 0, 20)
	MaskLabel.Size = UDim2.new(1, -10, 0, 15)
	MaskLabel.Font = Scheme.Font
	MaskLabel.Text = "-"
	MaskLabel.TextColor3 = Scheme.FontColor
	MaskLabel.TextSize = 13
	MaskLabel.TextXAlignment = Enum.TextXAlignment.Left
	MaskLabel.ZIndex = 3
	MaskState.GUI = ScreenGui
	local function updateInput(input)
		local delta = input.Position - MaskState.DragStart
		MainFrame.Position = UDim2.new(MaskState.StartPos.X.Scale, MaskState.StartPos.X.Offset + delta.X,
		MaskState.StartPos.Y.Scale, MaskState.StartPos.Y.Offset + delta.Y)
	end
	TitleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		MaskState.Dragging = true
		MaskState.DragStart = input.Position
		MaskState.StartPos = MainFrame.Position
		input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			MaskState.Dragging = false
		end
	end)
end
end)
TitleBar.InputChanged:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
	MaskState.DragInput = input
end
end)
game:GetService("UserInputService").InputChanged:Connect(function(input)
if input == MaskState.DragInput and MaskState.Dragging then
	updateInput(input)
end
end)
end
MaskState.GUI.Enabled = true
else
	if MaskState.GUI then
		MaskState.GUI.Enabled = false
	end
end
end
})
task.spawn(function()
while _G.StarshipActive and task.wait(0.5) do
	if MaskState.Enabled and MaskState.GUI and MaskState.GUI.Enabled then
		local killer = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and IsKiller(p) then
				killer = p
				break
			end
		end
		local mf = MaskState.GUI:FindFirstChild("MainFrame")
		local ct = mf and mf:FindFirstChild("Content")
		local sLabel = ct and ct:FindFirstChild("StatusLabel")
		local mLabel = ct and ct:FindFirstChild("MaskLabel")
		if killer then
			local isMaskedKiller = false
			local maskName = "None"
			if killer.Character then
				local char = killer.Character
				local attr = char:GetAttribute("Mask") or char:GetAttribute("CurrentMask") or
				char:GetAttribute("EquippedMask") or char:GetAttribute("MaskID")
				if attr then
					isMaskedKiller = true
					maskName = tostring(attr)
				else
					local head = char:FindFirstChild("Head")
					if head then
						for _, child in ipairs(head:GetChildren()) do
							local n = child.Name:lower()
							if n:find("mask") or (child:IsA("Accessory") and n:find("face")) then
								isMaskedKiller = true
								maskName = child.Name
								break
							end
						end
					end
				end
			end
			if isMaskedKiller or (killer.Team and killer.Team.Name == "The Masked") then
				if sLabel then
					sLabel.Text = "[ The Masked ]"
					sLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
				end
				if mLabel then
					mLabel.Text = "Mask: " .. maskName
				end
			else
				if sLabel then
					sLabel.Text = "[ " .. killer.Name .. " ]"
					sLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
				end
				if mLabel then
					mLabel.Text = "No mask detected"
				end
			end
		else
			if sLabel then
				sLabel.Text = "Status: Idle"
				sLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
			end
			if mLabel then mLabel.Text = "-" end
		end
	end
end
end)
end
if false then
	MaskBox:AddToggle('DetectMask', {
	Text = 'Show Mask Info',
	Default = false,
	Tooltip = 'Opens a separate window showing The Masked killer info',
	Callback = function(Value)
	MaskState.Enabled = Value
	if Value then
		if not MaskState.GUI then
			local ScreenGui = Instance.new("ScreenGui")
			ScreenGui.Name = "StarshipMaskInfo"
			ScreenGui.Parent = game:GetService("CoreGui")
			ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			local MainFrame = Instance.new("Frame")
			MainFrame.Name = "MainFrame"
			MainFrame.Parent = ScreenGui
			MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
			MainFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
			MainFrame.BorderSizePixel = 1
			MainFrame.Position = UDim2.new(0.05, 0, 0.5, 0)
			MainFrame.Size = UDim2.new(0, 200, 0, 100)
			MainFrame.Active = true
			local OuterBorder = Instance.new("UIStroke")
			OuterBorder.Parent = MainFrame
			OuterBorder.Color = Color3.fromRGB(0, 0, 0)
			OuterBorder.Thickness = 1
			local TopBar = Instance.new("Frame")
			TopBar.Name = "TopBar"
			TopBar.Parent = MainFrame
			TopBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			TopBar.BorderSizePixel = 0
			TopBar.Size = UDim2.new(1, 0, 0, 25)
			local Gradient = Instance.new("UIGradient")
			Gradient.Rotation = 90
			Gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 20))
			})
			Gradient.Parent = TopBar
			local Title = Instance.new("TextLabel")
			Title.Name = "Title"
			Title.Parent = TopBar
			Title.BackgroundTransparency = 1
			Title.Position = UDim2.new(0, 8, 0, 0)
			Title.Size = UDim2.new(1, -8, 1, 0)
			Title.Font = Enum.Font.Code
			Title.Text = "Killer Info"
			Title.TextColor3 = Color3.fromRGB(255, 255, 255)
			Title.TextSize = 13
			Title.TextXAlignment = Enum.TextXAlignment.Left
			local Content = Instance.new("Frame")
			Content.Parent = MainFrame
			Content.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			Content.BackgroundTransparency = 1
			Content.Position = UDim2.new(0, 5, 0, 30)
			Content.Size = UDim2.new(1, -10, 1, -35)
			local InfoLabel = Instance.new("TextLabel")
			InfoLabel.Name = "InfoLabel"
			InfoLabel.Parent = Content
			InfoLabel.BackgroundTransparency = 1
			InfoLabel.Size = UDim2.new(1, 0, 1, 0)
			InfoLabel.Font = Enum.Font.Code
			InfoLabel.Text = "Waiting for data..."
			InfoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			InfoLabel.TextSize = 13
			InfoLabel.TextWrapped = true
			InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
			InfoLabel.TextYAlignment = Enum.TextYAlignment.Top
			MaskState.GUI = ScreenGui
			local function updateInput(input)
				local delta = input.Position - MaskState.DragStart
				MainFrame.Position = UDim2.new(MaskState.StartPos.X.Scale, MaskState.StartPos.X.Offset + delta.X,
				MaskState.StartPos.Y.Scale, MaskState.StartPos.Y.Offset + delta.Y)
			end
			TopBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				MaskState.Dragging = true
				MaskState.DragStart = input.Position
				MaskState.StartPos = MainFrame.Position
				input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					MaskState.Dragging = false
				end
			end)
		end
	end)
	TopBar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		MaskState.DragInput = input
	end
end)
game:GetService("UserInputService").InputChanged:Connect(function(input)
if input == MaskState.DragInput and MaskState.Dragging then
	updateInput(input)
end
end)
end
MaskState.GUI.Enabled = true
else
	if MaskState.GUI then
		MaskState.GUI.Enabled = false
	end
end
end
})
task.spawn(function()
while _G.StarshipActive and task.wait(0.5) do
	if MaskState.Enabled and MaskState.GUI and MaskState.GUI.Enabled then
		local killer = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and IsKiller(p) then
				killer = p
				break
			end
		end
		local InfoText = ""
		local label = nil
		local mf = MaskState.GUI:FindFirstChild("MainFrame")
		if mf then
			local ct = mf:FindFirstChild("Frame")
			if ct then
				label = ct:FindFirstChild("InfoLabel")
			end
		end
		if killer then
			InfoText = "- Killer -\n" .. killer.Name .. "\n"
			local isMaskedKiller = false
			local maskName = "None"
			if killer.Character then
				local char = killer.Character
				local attr = char:GetAttribute("Mask") or char:GetAttribute("CurrentMask") or
				char:GetAttribute("EquippedMask") or char:GetAttribute("MaskID")
				if attr then
					isMaskedKiller = true
					maskName = tostring(attr)
				else
					local head = char:FindFirstChild("Head")
					if head then
						for _, child in ipairs(head:GetChildren()) do
							local n = child.Name:lower()
							if n:find("mask") or (child:IsA("Accessory") and n:find("face")) then
								isMaskedKiller = true
								maskName = child.Name
								break
							end
						end
					end
				end
			end
			if isMaskedKiller or (killer.Team and killer.Team.Name == "The Masked") then
				InfoText = InfoText .. "\n[ The Masked ]\n"
				InfoText = InfoText .. "Mask: " .. maskName
				if label then label.TextColor3 = Color3.fromRGB(255, 80, 80) end
			else
				InfoText = InfoText .. "\n[ Other Killer ]\n"
				InfoText = InfoText .. "No mask detected."
				if label then label.TextColor3 = Color3.fromRGB(180, 180, 180) end
			end
		else
			InfoText = "Status: No Killer Detected"
			if label then label.TextColor3 = Color3.fromRGB(120, 120, 120) end
		end
		if label then
			label.Text = InfoText
		end
	end
end
end)
end
local function InitMaskedDetection()
	if not Tabs or not Tabs.Survivor then return end
	local MaskBox = Tabs.Survivor:AddRightGroupbox('The Masked Detection', 'hat-glasses')
	local MaskState = {
	Enabled = false,
	GUI = nil
	}
	local function MakeDraggable(topbarobject, object)
		local Dragging = nil
		local DragInput = nil
		local DragStart = nil
		local StartPosition = nil
		local function Update(input)
			local Delta = input.Position - DragStart
			object.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale,
			StartPosition.Y.Offset + Delta.Y)
		end
		topbarobject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Dragging = true
			DragStart = input.Position
			StartPosition = object.Position
			input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				Dragging = false
			end
		end)
	end
end)
topbarobject.InputChanged:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
	DragInput = input
end
end)
game:GetService("UserInputService").InputChanged:Connect(function(input)
if input == DragInput and Dragging then
	Update(input)
end
end)
end
MaskBox:AddCheckbox('DetectMask', {
Text = 'Show Mask Info',
Default = false,
Tooltip = 'Opens a separate window showing The Masked killer info',
Callback = function(Value)
MaskState.Enabled = Value
if Value then
	if game.CoreGui:FindFirstChild("StarshipMaskInfo") then
		game.CoreGui.StarshipMaskInfo:Destroy()
	end
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "StarshipMaskInfo"
	ScreenGui.Parent = game:GetService("CoreGui")
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local Scheme = {
	MainColor = Color3.fromRGB(25, 25, 25),
	BackgroundColor = Color3.fromRGB(15, 15, 15),
	OutlineColor = Color3.fromRGB(50, 50, 50),
	AccentColor = Color3.fromRGB(0, 255, 127),
	FontColor = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.Code
	}
	if Library and Library.Scheme then
		if Library.Scheme.MainColor then Scheme.MainColor = Library.Scheme.MainColor end
		if Library.Scheme.BackgroundColor then Scheme.BackgroundColor = Library.Scheme.BackgroundColor end
		if Library.Scheme.OutlineColor then Scheme.OutlineColor = Library.Scheme.OutlineColor end
		if Library.Scheme.AccentColor then Scheme.AccentColor = Library.Scheme.AccentColor end
		if Library.Scheme.FontColor then Scheme.FontColor = Library.Scheme.FontColor end
		if Library.Scheme.Font then Scheme.Font = Library.Scheme.Font end
	end
	local MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Parent = ScreenGui
	MainFrame.BackgroundColor3 = Scheme.MainColor
	MainFrame.BorderColor3 = Scheme.OutlineColor
	MainFrame.BorderSizePixel = 1
	MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
	MainFrame.Size = UDim2.new(0, 210, 0, 80)
	MainFrame.Active = true
	local TitleBar = Instance.new("Frame")
	TitleBar.Name = "TitleBar"
	TitleBar.Parent = MainFrame
	TitleBar.BackgroundColor3 = Scheme.MainColor
	TitleBar.BorderSizePixel = 0
	TitleBar.Size = UDim2.new(1, 0, 0, 22)
	TitleBar.ZIndex = 2
	local AccentStrip = Instance.new("Frame")
	AccentStrip.Name = "AccentStrip"
	AccentStrip.Parent = TitleBar
	AccentStrip.BackgroundColor3 = Scheme.AccentColor
	AccentStrip.BorderSizePixel = 0
	AccentStrip.Size = UDim2.new(1, 0, 0, 1)
	AccentStrip.ZIndex = 3
	task.spawn(function()
	if Library and Library.AddToRegistry then
		Library:AddToRegistry(AccentStrip, { BackgroundColor3 = "AccentColor" })
	end
	if Options and Options.AccentColor then
		Options.AccentColor:OnChanged(function()
		AccentStrip.BackgroundColor3 = Options.AccentColor.Value
	end)
end
end)
local Title = Instance.new("TextLabel")
Title.Name = "TitleLabel"
Title.Parent = TitleBar
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 6, 0, 0)
Title.Size = UDim2.new(1, -12, 1, 0)
if typeof(Scheme.Font) == "Font" then
	Title.FontFace = Scheme.Font
else
	Title.Font = Scheme.Font or Enum.Font.Code
end
Title.Text = "Killer Info"
Title.TextColor3 = Scheme.FontColor
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 4
Title.Active = false
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Parent = MainFrame
Content.BackgroundColor3 = Scheme.BackgroundColor
Content.BorderColor3 = Scheme.OutlineColor
Content.BorderSizePixel = 1
Content.Position = UDim2.new(0, 6, 0, 28)
Content.Size = UDim2.new(1, -12, 1, -34)
Content.ZIndex = 2
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = Content
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0, 5, 0, 5)
StatusLabel.Size = UDim2.new(1, -10, 0, 15)
if typeof(Scheme.Font) == "Font" then
	StatusLabel.FontFace = Scheme.Font
else
	StatusLabel.Font = Scheme.Font or Enum.Font.Code
end
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
StatusLabel.TextSize = 13
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 5
local MaskLabel = Instance.new("TextLabel")
MaskLabel.Name = "MaskLabel"
MaskLabel.Parent = Content
MaskLabel.BackgroundTransparency = 1
MaskLabel.Position = UDim2.new(0, 5, 0, 22)
MaskLabel.Size = UDim2.new(1, -10, 0, 15)
if typeof(Scheme.Font) == "Font" then
	MaskLabel.FontFace = Scheme.Font
else
	MaskLabel.Font = Scheme.Font or Enum.Font.Code
end
MaskLabel.Text = "No data"
MaskLabel.TextColor3 = Scheme.FontColor
MaskLabel.TextSize = 13
MaskLabel.TextXAlignment = Enum.TextXAlignment.Left
MaskLabel.ZIndex = 5
MakeDraggable(TitleBar, MainFrame)
MaskState.GUI = ScreenGui
else
	if MaskState.GUI then
		MaskState.GUI:Destroy()
		MaskState.GUI = nil
	end
    local CoreGui = game:GetService("CoreGui")
	if CoreGui:FindFirstChild("StarshipMaskInfo") then
		CoreGui.StarshipMaskInfo:Destroy()
	end
end
end
})
task.spawn(function()
while _G.StarshipActive and task.wait(0.5) do
    pcall(function()
        
        if MaskState.Enabled then
            local killer = nil
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and IsKiller and IsKiller(p) then
                    killer = p
                    break
                end
            end
            if MaskState.GUI and MaskState.GUI:FindFirstChild("MainFrame") then
                local mf = MaskState.GUI.MainFrame
                local ct = mf:FindFirstChild("Content")
                local sLabel = ct and ct:FindFirstChild("StatusLabel")
                local mLabel = ct and ct:FindFirstChild("MaskLabel")
                if sLabel and mLabel then
                    if killer then
                        local isMaskedKiller = false
                        local maskName = "None"
                        if killer.Character then
                            local char = killer.Character
                            local attr = char:GetAttribute("Mask") or char:GetAttribute("CurrentMask") or
                            char:GetAttribute("EquippedMask") or char:GetAttribute("MaskID")
                            if attr then
                                isMaskedKiller = true
                                maskName = tostring(attr)
                            else
                                local head = char:FindFirstChild("Head")
                                if head then
                                    for _, child in ipairs(head:GetChildren()) do
                                        local n = child.Name:lower()
                                        if n:find("mask") or (child:IsA("Accessory") and n:find("face")) then
                                            isMaskedKiller = true
                                            maskName = child.Name
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        if isMaskedKiller or (killer.Team and killer.Team.Name == "The Masked") then
                            sLabel.Text = "[ The Masked ]"
                            sLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                            mLabel.Text = "Mask: " .. maskName
                        else
                            sLabel.Text = "[ " .. killer.Name .. " ]"
                            sLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                            mLabel.Text = "No mask detected"
                        end
                    else
                        sLabel.Text = "Status: Idle"
                        sLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                        mLabel.Text = "Waiting for killer..."
                    end
                end
            end
        end
    end)
end
end)
end
SafeInit(InitMaskedDetection, 'InitMaskedDetection')
Library:Notify("Loaded successfully!", 3)
