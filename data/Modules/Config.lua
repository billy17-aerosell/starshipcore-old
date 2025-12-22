return {
    Themes = {
        Default = { Main = Color3.fromRGB(10, 10, 14), Side = Color3.fromRGB(15, 15, 20), Accent = Color3.fromRGB(90, 110, 245), Item = Color3.fromRGB(20, 20, 28), Text = Color3.fromRGB(240, 240, 250) },
        Dark = { Main = Color3.fromRGB(15, 15, 15), Side = Color3.fromRGB(10, 10, 10), Accent = Color3.fromRGB(100, 100, 100), Item = Color3.fromRGB(25, 25, 25), Text = Color3.fromRGB(200, 200, 200) },
        Light = { Main = Color3.fromRGB(240, 240, 240), Side = Color3.fromRGB(220, 220, 220), Accent = Color3.fromRGB(0, 150, 255), Item = Color3.fromRGB(255, 255, 255), Text = Color3.fromRGB(20, 20, 20) },
        Midnight = { Main = Color3.fromRGB(10, 10, 14), Side = Color3.fromRGB(15, 15, 20), Accent = Color3.fromRGB(90, 110, 245), Item = Color3.fromRGB(20, 20, 28), Text = Color3.fromRGB(240, 240, 250) },
        Forest = { Main = Color3.fromRGB(20, 30, 20), Side = Color3.fromRGB(15, 20, 15), Accent = Color3.fromRGB(50, 200, 50), Item = Color3.fromRGB(30, 40, 30), Text = Color3.fromRGB(220, 255, 220) },
        Crimson = { Main = Color3.fromRGB(30, 10, 10), Side = Color3.fromRGB(20, 5, 5), Accent = Color3.fromRGB(255, 50, 50), Item = Color3.fromRGB(40, 20, 20), Text = Color3.fromRGB(255, 220, 220) }
    },
    DefaultConfig = {
        Theme = "Default",
        AccentColor = { R = 90, G = 110, B = 245 },
        QuickBoostPower = 10,
        Keybinds = {
            StartRecording = Enum.KeyCode.F5,
            PauseRecording = Enum.KeyCode.F6,
            TogglePath = Enum.KeyCode.F8,
            PlayPlayback = Enum.KeyCode.Z,
            StopPlayback = Enum.KeyCode.X,
            FollowPlayer = Enum.KeyCode.G,
            ToggleMinimize = Enum.KeyCode.RightControl,
            ToggleShiftLock = Enum.KeyCode.LeftShift,
            ToggleAntiSlip = nil,
            ToggleAutoJump = nil,
            ToggleQuickBoost = nil,
            ToggleRealESP = nil
        }
    }
}
