local UIS = game:GetService("UserInputService")
local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Player = game.Players.LocalPlayer
local PlaceId = game.PlaceId

-- ==========================================
-- ⚙️ CONFIGURATION & STATE
-- ==========================================
local IsActive = true -- Flag untuk mematikan script saat Exit
local CurrentSettings = {
    Target = "Phone",
    Platform = Enum.Platform.Android,
    Emoji = "📱",
    Touch = true,
    Viewport = Vector2.new(480, 270)
}

local GameDatabase = {
    [84918151469196] = { Remote = "ReportDeviceType", Type = "Invoke", Folder = "DeviceInfo", Refresh = "RefreshOverhead", AltTarget = "Mobile", PCTarget = "Desktop" },
    [101422882971972] = { Remote = "RegisterDevice", Type = "NilArg", Folder = "Remotes", Refresh = "RefreshOverhead", AltTarget = "Phone", PCTarget = "PC" },
    [94364101720799] = { Remote = "ReportDeviceType", Type = "Direct", Refresh = "DeviceChanged", PCTarget = "PC" },
    
    -- Game 4 Fix (Kunci ke "PC")
    [82151108222533] = { 
        Remote = "ReportDeviceType", Type = "Direct", Refresh = "DeviceChanged", 
        Extra = "donationboard@public.Signals.Refresh", AltTarget = "Phone", PCTarget = "PC" 
    },
    
    [80803949890816] = { Remote = "ReportDeviceType", Type = "Direct", Refresh = "DeviceChanged", Extra = "ShowDonationGUI", PCTarget = "PC" }
}

local GameData = GameDatabase[PlaceId]

-- ==========================================
-- 🛠️ CORE HOOKS
-- ==========================================
local oldIndex
oldIndex = hookmetamethod(game, "__index", function(self, key)
    if IsActive and not checkcaller() and self == UIS then
        if key == "GetPlatform" then return function() return CurrentSettings.Platform end
        elseif key == "TouchEnabled" or key == "TouchAvailable" then return CurrentSettings.Touch
        elseif key == "ViewportSize" then return CurrentSettings.Viewport end
    end
    return oldIndex(self, key)
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if IsActive and GameData and self.Name == GameData.Remote and (method == "FireServer" or method == "InvokeServer") then
        local final = (CurrentSettings.Target == "Phone" and GameData.AltTarget) or (CurrentSettings.Target == "PC" and GameData.PCTarget) or CurrentSettings.Target
        return oldNamecall(self, GameData.Type == "NilArg" and nil or final, GameData.Type == "NilArg" and final or nil)
    end
    return oldNamecall(self, ...)
end)

-- ==========================================
-- 🖥️ GUI CREATION
-- ==========================================
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 220, 0, 310); MainFrame.Position = UDim2.new(0.5, -110, 0.4, 0); MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15); MainFrame.Active = true; MainFrame.Draggable = true
Instance.new("UICorner", MainFrame)

local CloseBtn = Instance.new("TextButton", MainFrame)
CloseBtn.Size = UDim2.new(0, 30, 0, 30); CloseBtn.Position = UDim2.new(1, -35, 0, 5); CloseBtn.Text = "×"; CloseBtn.TextColor3 = Color3.new(1,0,0); CloseBtn.BackgroundTransparency = 1; CloseBtn.TextSize = 30; CloseBtn.Font = Enum.Font.GothamBold

local function CreateBtn(text, pos, color)
    local b = Instance.new("TextButton", MainFrame)
    b.Size = UDim2.new(0.9, 0, 0, 35); b.Position = UDim2.new(0.05, 0, 0, pos)
    b.Text = text; b.BackgroundColor3 = color; b.TextColor3 = Color3.new(1, 1, 1); b.Font = Enum.Font.Gotham; Instance.new("UICorner", b); return b
end

local PhoneBtn = CreateBtn("MODE: PHONE 📱", 70, Color3.fromRGB(0, 100, 200))
local PCBtn = CreateBtn("MODE: WINDOWS 💻", 115, Color3.fromRGB(50, 50, 50))
local ResetBtn = CreateBtn("FORCE PC RESET 🔄", 160, Color3.fromRGB(200, 50, 50))
local ActivateBtn = CreateBtn("ACTIVATE & SYNC", 220, Color3.fromRGB(0, 150, 0))
ActivateBtn.Size = UDim2.new(0.9, 0, 0, 50); ActivateBtn.Font = Enum.Font.GothamBold

-- ==========================================
-- ⚡ LOGIC
-- ==========================================
local HeartbeatConn

local function ForceSync(targetStr)
    if not GameData then return end
    local remote = RepStorage:FindFirstChild(GameData.Remote, true)
    if remote then
        if remote:IsA("RemoteFunction") then
            pcall(function() remote:InvokeServer(targetStr) end)
        else
            local arg1 = GameData.Type == "NilArg" and nil or targetStr
            local arg2 = GameData.Type == "NilArg" and targetStr or nil
            remote:FireServer(arg1, arg2)
        end
        task.wait(0.2)
        local refresh = RepStorage:FindFirstChild(GameData.Refresh or "", true)
        if refresh then pcall(function() if refresh:IsA("BindableEvent") then refresh:Fire() else refresh:FireServer() end end) end
        
        -- Sinyal Extra untuk Game 4 & 5
        if GameData.Extra then
            local extra = RepStorage:FindFirstChild("Refresh", true)
            if extra then pcall(function() extra:FireServer() end) end
        end
    end
end

PhoneBtn.MouseButton1Click:Connect(function()
    CurrentSettings.Target = "Phone"; CurrentSettings.Platform = Enum.Platform.Android; CurrentSettings.Emoji = "📱"; CurrentSettings.Touch = true; CurrentSettings.Viewport = Vector2.new(480, 270)
    PhoneBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 200); PCBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
end)

PCBtn.MouseButton1Click:Connect(function()
    CurrentSettings.Target = "PC"; CurrentSettings.Platform = Enum.Platform.Windows; CurrentSettings.Emoji = "💻"; CurrentSettings.Touch = false; CurrentSettings.Viewport = Vector2.new(1920, 1080)
    PCBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 200); PhoneBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
end)

ResetBtn.MouseButton1Click:Connect(function()
    CurrentSettings.Target = "PC"; CurrentSettings.Platform = Enum.Platform.Windows; CurrentSettings.Emoji = ""; CurrentSettings.Touch = false; CurrentSettings.Viewport = Vector2.new(1920, 1080)
    
    -- Nuclear Reset Strike
    local PCRestoreList = {"PC", "Windows", "Desktop", "Computer"}
    for _, str in pairs(PCRestoreList) do
        ForceSync(str)
        task.wait(0.1)
    end
    
    ResetBtn.Text = "FORCE RESET SENT!"; task.wait(1.5); ResetBtn.Text = "FORCE PC RESET 🔄"
end)

ActivateBtn.MouseButton1Click:Connect(function()
    local t = (CurrentSettings.Target == "Phone" and GameData.AltTarget) or (CurrentSettings.Target == "PC" and GameData.PCTarget) or CurrentSettings.Target
    ForceSync(t)
    ActivateBtn.Text = "SYNCED!"; task.wait(1); ActivateBtn.Text = "ACTIVATE & SYNC"
end)

CloseBtn.MouseButton1Click:Connect(function()
    IsActive = false
    if HeartbeatConn then HeartbeatConn:Disconnect() end
    ScreenGui:Destroy()
end)

-- Visual Locker
HeartbeatConn = RunService.Heartbeat:Connect(function()
    if not IsActive then return end
    pcall(function()
        local char = Player.Character
        local billboard = char and char.Head:FindFirstChildOfClass("BillboardGui")
        if billboard then
            for _, obj in pairs(billboard:GetDescendants()) do
                if (obj:IsA("TextLabel") or obj:IsA("ImageLabel")) and (obj.Name == "Emote" or obj.Name == "Icon" or obj.Name == "Device") then
                    if CurrentSettings.Emoji ~= "" then
                        if obj:IsA("TextLabel") then obj.Text = CurrentSettings.Emoji
                        else obj.Image = ""; local fix = obj:FindFirstChild("EmojiFix") or Instance.new("TextLabel", obj); fix.Text = CurrentSettings.Emoji; fix.Size = UDim2.new(1,0,1,0); fix.BackgroundTransparency = 1; fix.TextScaled = true end
                    else
                        local fix = obj:FindFirstChild("EmojiFix"); if fix then fix:Destroy() end
                    end
                end
            end
        end
    end)
end)

print("✅ Master Spoofer v5.0 Loaded! Game 4 PC Fix + Exit + Nuclear Reset Active.")
