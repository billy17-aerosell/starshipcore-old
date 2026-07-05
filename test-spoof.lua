-- [[ UNIVERSAL DEVICE SPOOFER v24.1 - DESKTOP LOGIC ]]
local _G_ = getgenv()
local UIS = game:GetService("UserInputService")
local RepStorage = game:GetService("ReplicatedStorage")
local Player = game:GetService("Players").LocalPlayer
local Camera = workspace.CurrentCamera

-- Hex Obfuscation
local function _h(hex)
    local s = ""
    for char in hex:gmatch("..") do s = s .. string.char(tonumber(char, 16)) end
    return s
end

local K_HOOK = _h("686f6f6b6d6574616d6574686f64") -- hookmetamethod
local K_MOBILE = _h("4d6f62696c65")               -- Mobile
local K_DESKTOP = _h("4465736b746f70")            -- Desktop
local E_MOBILE = _h("f09f93b1")                  -- 📱
local E_PC = _h("f09f92bb")                      -- 💻

-- Settings (Updated for Desktop Scan)
_G.Active = false
_G.TargetStr = K_MOBILE
_G.TargetEmoji = E_MOBILE
_G.TargetOS = "IOS"
_G.VSize = Vector2.new(375, 667)
_G.GuidRem = "08c0906b-2cac-4060-a74d-fcf1c08413a1"

-- [[ ENGINE HOOK ]]
local hDepth = 0
local oldIdx
oldIdx = _G_[K_HOOK](game, "__index", function(self, key)
    if _G.Active and not checkcaller() and hDepth == 0 then
        hDepth = 1
        if self == UIS then
            if key == "KeyboardEnabled" then hDepth = 0; return (_G.TargetStr == K_DESKTOP) end
            if key == "TouchEnabled" then hDepth = 0; return (_G.TargetStr == K_MOBILE) end
        elseif self == Camera and key == "ViewportSize" then
            hDepth = 0; return _G.VSize
        end
        hDepth = 0
    end
    return oldIdx(self, key)
end)

local oldNc
oldNc = _G_[K_HOOK](game, "__namecall", function(self, ...)
    local m = getnamecallmethod()
    if _G.Active and not checkcaller() then
        if self == UIS then
            if m == "GetPlatform" or m == "getPlatform" then
                return (_G.TargetStr == K_DESKTOP and Enum.Platform.Windows or Enum.Platform.IOS)
            end
            if m == "GetLastInputType" or m == "getLastInputType" then
                return (_G.TargetStr == K_DESKTOP and Enum.UserInputType.Keyboard or Enum.UserInputType.Touch)
            end
        end
        if m == "GetAttribute" and self == Player then
            local attr = (...)
            if attr == "DeviceType" or attr == "Device" or attr == "Platform" then
                return _G.TargetStr
            end
        end
        if m == "FireServer" or m == "fireServer" then
            if self.Name == "OV_ReportDevice" then
                -- This game only takes ONE argument!
                return oldNc(self, _G.TargetStr)
            elseif self.Name == _G.GuidRem or self.Name == "DeviceDetected" then
                return oldNc(self, _G.TargetStr, _G.TargetEmoji)
            end
        end
    end
    return oldNc(self, ...)
end)

-- UI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "S" .. math.random(100,999)
ScreenGui.Parent = gethui() or game:GetService("CoreGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 200, 0, 160)
Main.Position = UDim2.new(0.5, -100, 0.4, -80)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Main.Draggable = true
Main.Active = true
Main.Parent = ScreenGui

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 25, 0, 25)
Close.Position = UDim2.new(1, -25, 0, 0)
Close.Text = "X"
Close.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
Close.TextColor3 = Color3.new(1, 1, 1)
Close.Parent = Main
Close.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local ModeBtn = Instance.new("TextButton")
ModeBtn.Size = UDim2.new(1, -20, 0, 50)
ModeBtn.Position = UDim2.new(0, 10, 0, 30)
ModeBtn.Text = "TARGET: MOBILE 📱"
ModeBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
ModeBtn.TextColor3 = Color3.new(1, 1, 1)
ModeBtn.Parent = Main
ModeBtn.MouseButton1Click:Connect(function()
    if _G.TargetStr == K_MOBILE then
        _G.TargetStr = K_DESKTOP; _G.TargetEmoji = E_PC; _G.VSize = Vector2.new(1920, 1080)
        ModeBtn.Text = "TARGET: DESKTOP 💻"; ModeBtn.BackgroundColor3 = Color3.fromRGB(100, 40, 40)
    else
        _G.TargetStr = K_MOBILE; _G.TargetEmoji = E_MOBILE; _G.VSize = Vector2.new(375, 667)
        ModeBtn.Text = "TARGET: MOBILE 📱"; ModeBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
    end
end)

local StartBtn = Instance.new("TextButton")
StartBtn.Size = UDim2.new(1, -20, 0, 60)
StartBtn.Position = UDim2.new(0, 10, 0, 90)
StartBtn.Text = "SYNC DESKTOP v24.1"
StartBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 120)
StartBtn.TextColor3 = Color3.new(1, 1, 1)
StartBtn.Parent = Main
StartBtn.MouseButton1Click:Connect(function()
    _G.Active = true
    pcall(function()
        Player:SetAttribute("DeviceType", _G.TargetStr)
        local ovRem = RepStorage:FindFirstChild("OV_ReportDevice")
        if ovRem then ovRem:FireServer(_G.TargetStr) end
        
        local gRem = RepStorage:FindFirstChild(_G.GuidRem)
        if gRem then gRem:FireServer(_G.TargetStr, _G.TargetEmoji) end
    end)
    pcall(function() Player.Character.Humanoid.Health = 0 end)
end)

-- Visual Sync
task.spawn(function()
    while task.wait(0.5) do
        if _G.Active then
            pcall(function()
                local char = Player.Character
                if char then
                    for _, v in pairs(char:GetDescendants()) do
                        if v:IsA("BillboardGui") and (v.Name == "VandraOverhead" or v.Name == "Tag") then
                            local disp = v:FindFirstChild("Display", true)
                            if disp then
                                local pc = disp:FindFirstChild("Pc") or disp:FindFirstChild("PC") or disp:FindFirstChild("Desktop")
                                local phone = disp:FindFirstChild("Phone") or disp:FindFirstChild("Mobile")
                                if pc then pc.Visible = (_G.TargetStr == K_DESKTOP) end
                                if phone then phone.Visible = (_G.TargetStr == K_MOBILE) end
                            end
                        end
                    end
                end
            end)
        end
    end
end)