--[[
    ╔══════════════════════════════════════════════════════════╗
    ║          SAMBUNG KATA - AUTO ANSWER BOT v7               ║
    ║   HTTP API Word List + Remote-Based Submit               ║
    ║   UI POWERED BY WINDUI                                   ║
    ╚══════════════════════════════════════════════════════════╝
]]

-- === STARSHIP MINIMALIST INITIALIZATION (STEALTH) ===
-- Semua bypass agresif dihapus untuk menghindari deteksi metamethod.
pcall(function()
    local StarterGui = game:GetService("StarterGui")
    StarterGui:SetCore("SendNotification", {
        Title = "STARSHIP V8",
        Text = "Stealth Mode Active",
        Duration = 5
    })
end)


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TeleportService = game:GetService("TeleportService")
local Stats = game:GetService("Stats")

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


-- === IDENTITY & LIFECYCLE ===
local refreshUI, log, onMyTurn, autoJoinTable, cleanupBot, notify
local BillboardUpdate, TypeSound
local isRunning = true
local scriptId = HttpService:GenerateGUID(false)
_G.SK_BOT_ID = scriptId

local connections = {}
local matchRoundCount = 1 -- Melacak ronde saat ini
local prefixCache = {} -- Cache untuk menghemat CPU agar tidak lag
local keyboardCache = {} -- Cache tombol keyboard UI agar tidak lag
local function safeConnect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(connections, conn)
    return conn
end

-- === KONFIGURASI ===
local CONFIG = {
    Enabled = true,
    AutoSubmit = true,
    ShowNotif = true,
    DebugMode = false,
    UseRandomDelay = true,
    MinDelay = 1.0,
    MaxDelay = 2.0,
    SimulateTyping = true,
    TypeCharDelay = 0.12,
    AvoidRepeat = true,
    AutoRetry = true,
    AutoJoinTable = false,
    InteractionMode = "Bot",   -- "Bot", "Human"
    TypingSpeedMin = 0.2,      -- Detik per huruf (Minimal)
    TypingSpeedMax = 0.5,      -- Detik per huruf (Maksimal)

    -- Word list URLs
    WordListURLs = {
        "https://raw.githubusercontent.com/geovedi/indonesian-wordlist/master/00-indonesian-wordlist.lst",
        "https://raw.githubusercontent.com/damzaky/kumpulan-kata-bahasa-indonesia-KBBI/refs/heads/master/list_1.0.0.txt",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/dictionary_JSON.json",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-1-10000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-10001-30000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-30001-90000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-90001-100000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-100001-105000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-105001-110000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-110001-160000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-160001-210000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-210001-219861.sql"
    },

    -- Filter kata
    MinWordLength = 3,
    MaxWordLength = 14,

    -- Auto Join
    AutoJoinDelay = 3,
    KillerMode = true, -- PRIORITASKAN KATA SULIT DARI SERVER
    -- [OPIMIZED] Cache untuk memproses URL
    LoadedURLs = {},
    FastCollection = false, -- PRIORITASKAN KATA BARU UNTUK INDEX
    AutoClaim = true, -- OTOMATIS AMBIL HADIAH KOIN
    IndexBlacklist = false, -- BLACKLIST KATA YANG SUDAH DI-INDEX
    Transparency = 0.92, -- TRANSPARANSI BACKGROUND UI (0 = Terang, 1 = Gelap/Hidden)
    Theme = "Crimson", -- TEMA DEFAULT
    AutoSuggest = false, -- Tampilkan saran kata saat giliran kamu
    AutoSuggestMax = 50, -- Maksimal kata yang ditampilkan di suggester
    AutoVote = true, -- Vote saat server kirim GameModeVote (bukan scan UI)
    VoteTarget = "Normal", -- Target vote: "Santai", "Normal", "Brutal"

    -- Streaming Mode (Spoofing)
    StreamingMode = false,
    SpoofName = "StarshipPlayer",

    -- Misc / Security
    DetectAdmin = true,
    AutoLeaveAdmin = false,
}

-- Huruf/Akhiran sulit (Bisa 1, 2, atau 3 huruf)
local HARD_ENDING_SCORE = {
    -- 1 Huruf
    x = 100, q = 100, z = 90, v = 80, f = 70, j = 60, y = 50, w = 40,
    o = 10, e = 10,

    -- 2 Huruf (Sangat Mematikan)
    ["kh"] = 100, -- Contoh: Tarikh (Lawan harus jawab KH...)
    ["sy"] = 100, -- Contoh: Arasy (Lawan harus jawab SY...)
    ["ps"] = 100, -- Contoh: Korps (Lawan harus jawab PS...)
    ["eo"] = 150, -- Contoh: Video (Lawan harus jawab EO...)
    ["oe"] = 150, -- Contoh: Aloe (Lawan harus jawab OE...)
    ["cy"] = 150, -- Contoh: Policy (Lawan harus jawab Y...)
    ["ly"] = 150, -- Contoh: Family (Lawan harus jawab Y...)
    ["gy"] = 150, -- Contoh: Energy (Lawan harus jawab Y...)
    ["ty"] = 150, -- Contoh: Party (Lawan harus jawab Y...)
    ["ny"] = 70,  -- Contoh: Nyanyi
    ["ng"] = 40,  -- Contoh: Pisang
    ["th"] = 60,  -- Contoh: Hadist
    ["sh"] = 80,  -- Contoh: Mushaf
    ["st"] = 50,  -- Contoh: Smash (jika serapan)
    ["ks"] = 200, -- Contoh: Teks, Indeks, Kompleks (SANGAT MEMATIKAN)
    ["ox"] = 200, -- Contoh: Xerox, Paradox, Detox (SANGAT MEMATIKAN)
}

local LocalPlayer = Players.LocalPlayer

-- === SESSION & AUTHENTICATION ===
local sessionData = (getgenv and getgenv().StarshipSession) or _G.sessionData or { 
    Role = "VIP Mobile", 
    Duration = "Lifetime",
    UserId = LocalPlayer.UserId,
    Username = LocalPlayer.Name
}
_G.sessionData = sessionData

local Window = nil



function cleanupBot(isFromUI)
    if not isRunning then return end
    isRunning = false
    
    local serial = scriptId:sub(1,4)
    if CONFIG.DebugMode then
        print("[SK-Bot-" .. serial .. "] 🛑 Stopping bot and cleaning up resources...")
    end
    
    if _G.SK_BOT_ID == scriptId then
        _G.SK_BOT_ID = nil 
    end
    
    -- Disconnect all tracked connections
    for _, conn in ipairs(connections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(connections)
    
    -- Disconnect WordServerFrame watchers
    if _G.__SK_WSF_WATCHER then
        pcall(function()
            if type(_G.__SK_WSF_WATCHER) == "table" then
                for _, c in ipairs(_G.__SK_WSF_WATCHER) do
                    if c and c.Connected then c:Disconnect() end
                end
            elseif _G.__SK_WSF_WATCHER.Disconnect then
                _G.__SK_WSF_WATCHER:Disconnect()
            end
        end)
        _G.__SK_WSF_WATCHER = nil
    end
    
    -- Clear server-side billboard visual
    if BillboardUpdate then 
        pcall(function() BillboardUpdate:FireServer("") end) 
    end
    
    -- Aggressive HUD cleanup (Search all possible locations)
    local function cleanHUD(parent)
        for _, v in ipairs(parent:GetChildren()) do
            if v.Name == "SK_Overlay" then
                pcall(function() v:Destroy() end)
            elseif v:IsA("Model") or v:IsA("Folder") then
                -- Shallow recursive for characters
                for _, sub in ipairs(v:GetChildren()) do
                    if sub.Name == "SK_Overlay" then pcall(function() sub:Destroy() end) end
                end
            end
        end
    end
    
    cleanHUD(workspace)
    pcall(function() cleanHUD(Players.LocalPlayer:WaitForChild("PlayerGui", 2)) end)
    
    -- Final sweep for orphan SK_Overlays in workspace
    for _, player in ipairs(Players:GetPlayers()) do
        pcall(function()
            local char = player.Character
            if char then
                for _, item in ipairs(char:GetDescendants()) do
                    if item.Name == "SK_Overlay" then item:Destroy() end
                end
            end
        end)
    end
    
    -- Destroy window LAST, only if we weren't triggered BY the UI closing already
    if Window and not isFromUI then
        local selfWindow = Window
        Window = nil
        task.spawn(function()
            pcall(function() 
                if selfWindow and selfWindow.Destroy then 
                    selfWindow:Destroy() 
                end 
            end)
        end)
    end
    
    -- print("[SK-Bot-" .. serial .. "] ✅ Cleanup complete.")
end


-- === VERSION MONITOR (DISABLED TO PREVENT AUTO-CLOSE) ===
-- Sistem ini dimatikan sementara agar window tidak menutup sendiri.
task.spawn(function()
    while isRunning do
        -- Kita hanya akan memantau status, tidak mematikan paksa.
        task.wait(10)
    end
end)

-- === LOAD WINDUI (BOREAL SOURCE FIRST, FALLBACK TO STANDARD) ===
_G.WindUIIsBoreal = false

-- Primary: Boreal (Your GitHub first)
WindUI = AttemptLoad('https://raw.githubusercontent.com/billy17-netizen/StarshipCore/main/data/WindUI%20Boreal', "WindUI_Boreal.lua")

if WindUI then 
    _G.WindUIIsBoreal = true 
else
    -- Fallback 1: Original Boreal
    WindUI = AttemptLoad('https://raw.githubusercontent.com/orialdev/WindUI-Boreal/main/WindUI%20Boreal', "WindUI_Boreal.lua")
    if WindUI then _G.WindUIIsBoreal = true end
end

if not WindUI then
    -- Fallback 2: Standard WindUI
    WindUI = AttemptLoad('https://github.com/Footagesus/WindUI/releases/latest/download/main.lua', "WindUI_Standard.lua")
end

if not WindUI then
    warn("[STARSHIP] ❌ ERROR: Failed to load UI library. Please check your internet.")
    return 
end


-- === SAFE REMOTE FETCHING ===
local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
    local errMsg = "❌ CRITICAL: Folder 'Remotes' tidak ditemukan! Pastikan Anda berada di meja atau game sudah dimuat sempurna."
    pcall(function()
        if WindUI and WindUI.Notify then
            WindUI:Notify({Title = "Error", Content = errMsg, Duration = 10})
        end
    end)
    return
end

-- === LOGGING: konsol hanya jika CONFIG.DebugMode ===
function log(msg)
    if UI_LOG_MSG then
        pcall(function() UI_LOG_MSG(tostring(msg)) end)
    end
    if CONFIG.DebugMode then
        print("[SK-Bot-" .. scriptId:sub(1,4) .. "] " .. tostring(msg))
    end
end

function notify(title, text)
    if CONFIG.ShowNotif then
        pcall(function()
            if WindUI and WindUI.Notify then
                WindUI:Notify({ Title = title, Content = text, Duration = 3 })
            end
        end)
    end
end

-- === STEALTH MODE: REMOVING DIAGNOSTIC MAPPER ===
-- Diagnostic mapper removed to prevent detection via remote connection tracking.
-- Bot will now rely solely on its static heuristic prefixes.


local assignedRemotes = {} -- Track remote yang sudah di-assign agar tidak duplikat

local function getRemote(name, optional)
    local remote = nil
    local knownNames = {
        "SubmitWord", "MatchUI", "JoinTable", "LeaveTable", "ResultUI", 
        "UsedWordWarn", "UpdatePromptVisibility", "GameModeVote", 
        "MatchTimerUpdate", "BillboardUpdate", "PlayerCorrect", "TypeSound", 
        "PlayerHit", "WordUpdate", "UpdateWordIndex", "RequestWordIndex", 
        "ClaimIndexReward", "IndexRewardStatus", "TurnCamera"
    }
    
    local function isAlreadyAssigned(v)
        for _, assigned in pairs(assignedRemotes) do
            if assigned == v then return true end
        end
        return false
    end
    
    -- Heuristic 1: Exact Name Match
    for _, v in ipairs(Remotes:GetDescendants()) do
        if v.Name:lower() == name:lower() and v:IsA("RemoteEvent") then
            remote = v
            break
        end
    end
    
    -- Heuristic 2: Known obfuscated prefixes (V12 TARGETED)
    if not remote then
        local mapper = {
            SubmitWord = {"Zwlgeg", "BruJsk", "sqrNhd", "mAAJrQ", "kusmvy", "kfidld"},
            MatchUI = {"sqrNhd", "BruJsk", "Zwlgeg", "mAAJrQ", "kusmvy", "kfidld"},
            UsedWordWarn = {"sqrNhd", "Used", "BruJsk", "mAAJrQ", "kusmvy", "kfidld"},
        }
        
        local prefixes = mapper[name]
        if prefixes then
            for _, v in ipairs(Remotes:GetDescendants()) do
                if v:IsA("RemoteEvent") and not isAlreadyAssigned(v) then
                    for _, pref in ipairs(prefixes) do
                        if v.Name:find("^" .. pref) or (v.Parent and v.Parent.Name:find("^" .. pref)) then
                            remote = v
                            break
                        end
                    end
                end
                if remote then break end
            end
        end
    end

    -- Heuristic 3: Brute Force (Folder Obfuscation - Multi-Index)
    if not remote and (name == "SubmitWord" or name == "MatchUI" or name == "UsedWordWarn") then
        local foundInFolder = {}
        for _, v in ipairs(Remotes:GetDescendants()) do
            if v:IsA("RemoteEvent") and not isAlreadyAssigned(v) then
                local isKnown = false
                for _, kn in ipairs(knownNames) do if v.Name == kn then isKnown = true break end end
                
                if not isKnown and v.Parent and #v.Parent.Name > 15 and v.Parent ~= Remotes then
                    table.insert(foundInFolder, v)
                end
            end
        end
        
        -- Urutan biasanya: 1. SubmitWord, 2. MatchUI, 3. UsedWordWarn
        if #foundInFolder > 0 then
            if name == "SubmitWord" then remote = foundInFolder[1]
            elseif name == "MatchUI" then remote = foundInFolder[2] or foundInFolder[1]
            elseif name == "UsedWordWarn" then remote = foundInFolder[3] or foundInFolder[1]
            end
        end
    end
    
    if not remote and not optional then
        log("❌ Gagal menemukan Remote: " .. name)
    elseif remote then
        assignedRemotes[name] = remote
        log("🔗 Linked: " .. name .. " -> " .. remote.Name .. " (Parent: " .. tostring(remote.Parent and remote.Parent.Name or "nil") .. ")")
    end
    return remote
end

local SubmitWord = getRemote("SubmitWord")
_G.SK_SUBMIT_REMOTE = SubmitWord 
local MatchUI = getRemote("MatchUI")
local JoinTable = getRemote("JoinTable")
local ResultUI = getRemote("ResultUI")
local TurnCamera = getRemote("TurnCamera") or getRemote("UpdateCamera", true)
local UsedWordWarn = getRemote("UsedWordWarn")
local UpdatePromptVisibility = getRemote("UpdatePromptVisibility", true)
local GameModeVote = getRemote("GameModeVote", true)
local MatchTimerUpdate = getRemote("MatchTimerUpdate", true)
local MatchStatusUpdate = getRemote("MatchStatusUpdate", true)

-- DIRECT SERVER REMOTES (path langsung dari Dex Explorer, bukan heuristik)
local UpdateCurrentWord = Remotes:FindFirstChild("UpdateCurrentWord") or Remotes:WaitForChild("UpdateCurrentWord", 5)
local WordUpdate = Remotes:FindFirstChild("WordUpdate") or Remotes:WaitForChild("WordUpdate", 5)
local PlayerCorrect = Remotes:FindFirstChild("PlayerCorrect") or Remotes:WaitForChild("PlayerCorrect", 5)
local EndTurnRemote = Remotes:FindFirstChild("EndTurn") or Remotes:WaitForChild("EndTurn", 5)

local tableHiddenStatus = {} -- Penampung data meja yang sedang penuh/tidak aktif

BillboardUpdate = getRemote("BillboardUpdate", true)
-- === AGGRESSIVE REMOTE HUNT (TypeSound Fix) ===
TypeSound = getRemote("TypeSound", true)
if not TypeSound then
    -- Ekstra scan jika tidak ketemu di folder Remotes (Recursive)
    TypeSound = ReplicatedStorage:FindFirstChild("TypeSound", true)
end

-- Fallback jika masih tidak ketemu (Scan Manual Descendants)
if not TypeSound then
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and (v.Name == "TypeSound" or v.Name:match("TypeSound")) then
            TypeSound = v
            break
        end
    end
end

task.spawn(function()
    task.wait(4)
    if TypeSound then
        pcall(function()
            if log then log("🔊 TypeSound Linked: " .. TypeSound.Name) end
        end)
    end
end)

local function fireTypeSound()
    if not isRunning or _G.SK_BOT_ID ~= scriptId or not TypeSound then return end
    if firesignal then
        firesignal(TypeSound.OnClientEvent, nil)
    else
        pcall(function() TypeSound:FireServer() end)
    end
end
local PlayerHit = getRemote("PlayerHit", true) or getRemote("Hit", true)
local PlayerCorrect = getRemote("PlayerCorrect", true) or getRemote("Correct", true)
local UpdateWordIndex = getRemote("UpdateWordIndex", true)
local RequestWordIndex = getRemote("RequestWordIndex", true)
local IndexRewardStatus = getRemote("IndexRewardStatus", true)
local ClaimIndexReward = getRemote("ClaimIndexReward", true)
local WordUpdate = getRemote("WordUpdate", true)

-- (Hook moved to the end of script for stability)



local UIElements = {}
local STATS = {
    wordsCorrect = 0,
    wordsFailed = 0,
    retries = 0,
    matchesWon = 0,
    matchesPlayed = 0,
    totalCoinsEarned = 0,
    currentStreak = 0,
    bestStreak = 0,
    playersAtTable = 0,
    tablesJoined = 0
}

-- === STATS TRACKER ===

-- === COMMON WORDS SET ===
local COMMON_WORDS = {}
local function buildCommonWordsSet()
    local commonData = {
        "apel","awan","angin","api","air","alam","anak","ayam","asap","akar","angsa","arus","arah","adik","abang","ampun","andal","asli","awas","acara","agung","ajaib","akrab","alat","amal","antar","arif","aktif","alur","amis","atap","awal","aksi","ambil","angkat","antik","asing","aset","awam","aksara","album","akhir","akur","alamat","alasan","aliran","amanah","amarah","ambang","arsip","artis","aturan","aurora","avokad",
        "buku","batu","bulan","bumi","burung","bola","bunga","besar","baik","baru","biru","berani","bintang","bosan","buah","bakso","bambu","banjir","batas","bayar","beban","bedak","belut","benang","berita","besok","bocor","boleh","bubur","bulat","buruk","busuk","bebas","bekal","benci","beras","berkah","betul","bijak","bocah","boneka","bukit","bumbu","bunyi","badak","balok","bangku","barang","benda","bersih",
        "cinta","cuaca","cahaya","cantik","cepat","cukup","cari","catat","cemas","cerdas","cerah","cerita","cicak","coklat","contoh","cubit","cuka","culik","cumi","cangkir","capek","celana","cemara","cendol","cermin","cincin","cocok","cukur","curang","cabai","cakar","cambuk","capung","catur","celah","cipta","cium","cuci","cacat","cagar","campur","canda","candu","canggih","cetak","citra","copet",
        "danau","daun","desa","dunia","dekat","dalam","daging","dahan","damai","datang","debu","deras","dingin","domba","dosen","dua","duit","duku","duri","dusta","dahulu","dampak","dapat","dasar","datar","dendam","depan","detik","diam","didik","dinas","dodol","dongeng","dorong","duduk","dukun","duren","daerah","daftar","darat","daya","debat","delima","delta","demam","desain","dewasa","dialog",
        "elang","emas","enak","emosi","embun","ekor","empat","era","esok","elastis","elok","empuk","endap","energi","entah","erosi","eskrim","etika","ekonomi","ekstra","elegan","efek","efektif","ego","ejaan","elemen","elite","ember","enam","enggan",
        "foto","fakta","fokus","favorit","festival","final","flora","fungsi","fajar","fantasi","fauna","figur","film","fisik","fondasi","formal","fosil","futsal","fitur","formula","forum","farmasi","fatal","fiksi","filter","firasat","firman","flu","format",
        "gajah","gunung","garam","gitar","gelap","gembira","guru","gagal","galak","garang","gatal","gedung","gelang","gema","gempa","gerak","gila","goreng","gosip","gadis","ganda","ganggu","garasi","gaul","gawat","genap","gerbang","gigit","gagasan","gaji","galeri","gambar","ganti","garpu","gas","gaya",
        "hari","hujan","hutan","hitam","hijau","habis","hadiah","halus","hantu","harap","harga","hasil","hebat","hemat","hewan","hidup","hilang","hitung","hobi","hormat","hotel","hukum","huruf","harus","hidung","hadir","hafal","hakim","halal","halaman","hamil","hampir","hancur","hangat","hapus","harta","harum","hati","haus","heboh","helm","hening","heran",
        "ikan","indah","istana","ikat","ilmu","intan","isi","ide","ingin","iris","istri","idola","iklan","impian","induk","ingat","inovasi","ibu","ikut","imam","imun","imut","industri","info","irigasi","ikrar","isarat","ijazah","iklim","ikat","ikon","infus","intip","intens", 
        "jalan","jeruk","jatuh","jarak","jelas","jendela","jernih","jiwa","jual","jubah","jujur","jumpa","jahat","jamin","jamu","jangan","jawab","jemput","jadi","jadwal","jaga","jagat","jago","jagung","jahit","jjalur","jam","jambu","janji","jantung","jaring","jarum","jati","jauh","jaya",
        "kucing","kuda","kapal","kunci","kain","kabar","kacang","kadal","kaget","kalung","kamar","kamus","kanan","kapas","kapur","karang","kartu","kasur","kayu","kecil","kedai","kejar","kelam","kemah","kenal","keran","kilat","kipas","kolam","kompas","kotak","kulit","kumis","kupas","kursi","kabut","kagum","kakak","kalah","kabel","kaca","kacau","kafe","kali","kambing","kantor",
        "laut","langit","lebar","lemah","lihat","lucu","ladang","lalat","lampu","lapar","lari","latih","lauk","lawan","layar","lebah","leher","lemari","lemon","lengkap","lepas","lewat","liar","lilin","lomba","lunak","lurus","luka","laci","lagu","lahir","lain","laku","lama","lambat","lancar","langkah","langsung","lantai","lapor",
        "makan","malam","manis","merah","muda","musim","mandi","mangga","marah","masjid","masuk","mekar","melati","melon","mentah","merdu","mesra","mimpi","minyak","mirip","miskin","monyet","mulia","mulut","mundur","murah","murni","musik","musuh","mahal","mahir","malu","mampu","macam","macet","madu","magnet","main","maju","makna","manusia","mantap",
        "nasi","nama","naik","negeri","nyaman","nafas","naga","nakal","nalar","nanti","nasib","natal","nekat","neraka","nikmat","nilai","niat","noda","normal","nota","novel","nuansa","nyala","nyata","nyeri","nabi","nanas","nangka","napas","narasi","nasional","negara","nelayan","nenek",
        "orang","obat","oleh","ombak","opini","otak","obor","olah","omong","organ","oval","obeng","ojek","olahraga","oles","oli","ongkos","operasi","optimal","optimis","orbit","organik","organisasi",
        "pagi","pasir","panas","perak","pintu","pohon","pagar","pajak","pakai","paket","paman","pandai","panen","pantai","papan","parkir","pasar","pasang","patah","pecah","pelan","penuh","perut","pesona","pisau","pokok","potong","puasa","puisi","pukul","pulang","puncak","pupuk","putar","putih","putus","palsu","pamit","panah","panik","pasti","padang","palu","panjang",
        "raja","rumah","rasa","ringan","rusak","racun","rajin","rambut","rantai","rapuh","rata","rawat","rebus","rela","rendah","resah","ribu","rimbun","rindu","robek","ruang","rubah","rujak","rumit","runtuh","rupiah","rutin","raba","radar","radio","raga","ragam","ragu","rahasia",
        "satu","siang","salju","sabar","sabun","sakit","salah","sampah","santai","sapi","sapu","saran","saudara","sawah","sedih","segar","sehat","semen","sendok","seram","serius","sikat","simpan","siram","sisir","suara","subur","sudah","suhu","sukses","sumber","sungai","suntik","supir","surat","surga","sadar","saksi","sakti",
        "tangan","teman","timur","tanah","tanam","tanda","tangga","tangis","tanya","tari","taruh","tawar","tebal","tegak","tegas","tekad","telur","tembak","tenang","tengah","tepat","terang","tertib","tetap","tiang","tidur","tikus","tinta","tolong","tongkat","topeng","tugas","tuhan","tujuh","tulang","tulus","tumbuh","tumis","turun","tusuk",
        "ular","udara","ubah","ucap","udang","ujian","ukir","ukur","ulang","ulat","umpan","unik","untung","upah","upaya","usaha","utama","utang","utuh","ubur","uji","umum","undang","ungu","unsur","untuk","urus","usia","usul","utara",
        "vaksin","variasi","vokal","volume","vital","visi","visa","video","viral","virtual","virus","vitamin","vonis",
        "waktu","warna","wajah","wajar","wangi","warga","warung","wasit","wilayah","wisata","wujud","wanita","waras","wadah","wajib","wakil","warisan","watak","wayang",
        "yakin","yang","yatim","yoga","yayasan",
        "zaman","zat","zebra","zona","zodiak","zaitun","zamrud","ziarah"
    }
    for _, word in ipairs(commonData) do
        COMMON_WORDS[word] = true
    end
end
buildCommonWordsSet()

-- === STATE ===
local loadingStatus = "⏳ Memuat..."
local totalWordsLoaded = 0
local wordListLoaded = false

_G.SK_ANSWER_LOCK = false 
_G.SK_LAST_LETTER = "" 
_G.__SK_REMOTE_LETTER = "" -- Huruf dari server (prioritas tertinggi untuk letter detection)
_G.__SK_WSF_WATCHER = nil -- WordServerFrame text watcher connection
_G.__SK_REMOTE_TURN = false -- true/false — hasil TurnStart dari remote (false = default, menunggu sinyal)
_G.__SK_TURN_TIMESTAMP = 0 -- tick() saat TurnStart(true) diterima
_G.__SK_AWAITING_LETTER = false -- true HANYA setelah TurnStart(true), false setelah letter diterima/turn berakhir

local usedWords = {}
local gameUsedWords = {}
-- isRunning moved to top
local currentLetter = ""
local isMyTurn = false
local matchActive = false
local matchTimer = 0
local lastAnswer = ""
local lastSubmittedWord = ""
local retryingWord = false
local typingID = 0 -- Tracker UID untuk pembatalan pengetikan (Anti-stacking)
local sessionUsedWords = {} -- Tracker kata unik yang dikirim bot selama sesi ini (untuk hindari duplikat)
local lastRewardCount = 0 -- Jumlah hadiah yang sudah AVAILABLE sebelumnya
local sessionNewWordsDiscovered = 0 -- Berapa banyak kata 'baru' (index) yang berhasil bot temukan
local playerTypingStatus = {} -- tracker kata yang sedang diketik pemain lain [player] = "kata"
local playerMistakes = {} -- tracker jumlah kesalahan [userId] = count
local initialIndexCount = nil -- Jumlah kata di koleksi saat bot pertama jalan
local currentIndexCount = 0 -- Jumlah kata di koleksi saat ini
local totalIndexPossible = 0 -- Total seluruh kata yang ada di database game
local sessionClaimedRewards = {} -- Riwayat hadiah yang diamankan sesi ini
local GLOBAL_INDEX_BLACKLIST = {} -- Daftar kata yang SUDAH ada di index game (untuk di-blacklist)

-- === DATABASE PENGETAHUAN SERVER (AUTO-LEARN) ===
local SERVER_KNOWN_WORDS = {} 
-- Mengisi database dari data yang pernah lolos di server
local function learnFromServer(word)
    local w = tostring(word or ""):lower()
    if #w < 2 then return end
    local first = w:sub(1,1)
    if not SERVER_KNOWN_WORDS[first] then SERVER_KNOWN_WORDS[first] = {} end
    if not table.find(SERVER_KNOWN_WORDS[first], w) then
        table.insert(SERVER_KNOWN_WORDS[first], w)
    end
end

-- Track Sumber Kata
local WORDS_SOURCE_DB = {} -- true jika dari URL, nil jika dari fallback

-- Pre-load fallback agar bot tidak kosong saat baru start
local KATA_DB = {
    a={"apel","awan","angin","api","air","alam","anak","ayam","asap","akar","angsa","arus","arah","adik","abang","ampun","andal","asli","awas","acara","agung","ajaib","akrab","alat","amal","antar","arif","aktif","alur","amis","atap","awal","aksi","ambil","angkat","antik","asing","aset","awam","aksara","album","akhir","akur","alamat","alasan","aliran","amanah","amarah","ambang","arsip","artis","aturan","aurora","avokad","aloe"},
    b={"buku","batu","bulan","bumi","burung","bola","bunga","besar","baik","baru","biru","berani","bintang","bosan","buah","bakso","bambu","banjir","batas","bayar","beban","bedak","belut","benang","berita","besok","bocor","boleh","bubur","bulat","buruk","busuk","bebas","bekal","benci","beras","berkah","betul","bijak","bocah","boneka","bukit","bumbu","bunyi","badak","balok","bangku","barang","benda","bersih","beo","baileo","boe"},
    c={"cinta","cuaca","cahaya","cantik","cepat","cukup","cari","catat","cemas","cerdas","cerah","cerita","cicak","coklat","contoh","cubit","cuka","culik","cumi","cangkir","capek","celana","cemara","cendol","cermin","cincin","cocok","cukur","curang","cabai","cakar","cambuk","capung","catur","celah","cipta","cium","cuci","cacat","cagar","campur","canda","candu","canggih","cetak","citra","copet","cyber","cyborg","cyan","cameo","currency"},
    d={"danau","daun","desa","dunia","dekat","dalam","daging","dahan","damai","datang","debu","deras","dingin","domba","dosen","dua","duit","duku","duri","dusta","dahulu","dampak","dapat","dasar","datar","dendam","depan","detik","diam","didik","dinas","dodol","dongeng","dorong","duduk","dukun","duren","daerah","daftar","darat","daya","debat","delima","delta","demam","desain","dewasa","dialog","daily","democracy","duty"},
    e={"elang","emas","enak","emosi","embun","ekor","empat","era","esok","elastis","elok","empuk","endap","energi","entah","erosi","eskrim","etika","ekonomi","ekstra","elegan","efek","efektif","ego","ejaan","elemen","elite","ember","enam","enggan","enzim","epidemi","episode","erupsi","esai","estetika","etis","euforia","evaluasi","evolusi","emergency","energy","efficiency","efficacy","eon","eosin","eosen","eolit"},
    f={"foto","fakta","fokus","favorit","festival","final","flamingo","flora","fungsi","fajar","fantasi","fauna","figur","film","fisik","fondasi","formal","fosil","futsal","fasilitas","fenomena","fitur","formula","forum","fabel","fakultas","farmasi","fatal","fiksi","filosof","filter","finansial","firasat","firman","flu","fobia","forensik","format","family","fancy","fly"},
    g={"gajah","gunung","garam","gitar","gelap","gembira","guru","gagal","galak","garang","garuk","gatal","gedung","gelang","gema","gempa","gerak","getah","gila","goreng","gosip","gulai","guntur","gadis","galang","ganda","ganggu","garasi","gaul","gawat","gelombang","genap","gerbang","gigit","gabus","gadai","gagasan","gaib","gairah","gaji","galeri","gambar","gampang","ganti","gantung","garpu","gas","gaya","gym","gyro","geologi","geology","gypsum"},
    h={"hari","hujan","hutan","hitam","hijau","habis","hadiah","halus","hantu","harap","harga","hasil","hebat","hemat","hewan","hidup","hilang","hitung","hobi","hormat","hotel","hubung","hukum","huruf","harus","hidung","hadir","hafal","haji","hakim","halal","halaman","hamil","hampir","hancur","hangat","hapus","harta","harum","hati","haus","hayat","heboh","helm","hening","heran","herbal","hero"},
    i={"ikan","indah","istana","ikat","ilmu","intan","isi","ide","imbang","ingin","iris","isap","istri","iblis","idola","iklan","impian","inap","induk","ingat","injak","inovasi","insaf","intai","iseng","itik","iuran","ibu","identitas","ikut","ilalang","ilustrasi","imam","impor","imun","imut","indera","individu","industri","infeksi","inflasi","info","inisiatif","input","inspeksi","indeks","ideks"},
    j={"jalan","jeruk","jatuh","jarak","jelas","jendela","jernih","jiwa","jual","jubah","judi","jujur","jumpa","jurus","jahat","jamin","jamu","jangan","jangkar","jawab","jemput","jerat","jerit","jabat","jadi","jadwal","jaga","jagat","jago","jagung","jahit","jajan","jaksa","jalur","jam","jambu","janda","janji","jantung","jaring","jarum","jati","jauh","jawa","jaya","jebak","joe"},
    k={"kucing","kuda","kapal","kunci","kain","kabar","kacang","kadal","kaget","kalung","kamar","kamus","kanan","kapas","kapur","karang","kartu","kasur","kayu","kecil","kedai","kejar","kelam","kemah","kenal","keran","keris","kilat","kipas","kolam","kompas","kotak","kulit","kuman","kumis","kupas","kursi","kabut","kagum","kakak","kalah","kabel","kaca","kacau","kafe","kail","kaji","kali","kambing","kantor","kameo","keseleo"},
    l={"laut","langit","lebar","lemah","lihat","lucu","ladang","lalat","lampu","lapar","lapis","lari","latih","lauk","lawan","layar","lebah","lehar","lemari","lemon","lengkap","lepas","lewat","liar","lilin","limbah","lincah","lomba","loyal","lunak","lurus","luka","lumut","lacak","laci","lagu","lahar","lahan","lahir","lain","laku","lama","lamar","lambat","lancar","langkah","langsung","lantai","lapor","laras","leo","legacy","lobby","lyric","lyra"},
    m={"makan","minum","mata","malam","mobil","meja","merah","masak","maju","malu","mandi","manis","marah","masuk","mati","menang","merdu","mimpi","miskin","muda","mulut","murid","musik","musuh","macan","madu","mahasiswa","main","majelis","makna","maksimal","maksud","mampu","mana","mandi","mangga","mangkok","mantan","manusia","mapalus","maritim","martabat","masa","masalah","masyarakat","materi","mazmur","medali","media","medis","museo","maleo","membeo","mercy"},
    n={"nama","nasi","nafas","naga","naik","nakal","namun","nanti","nasib","negara","nelayan","nenek","neraka","ngantuk","niat","nilai","nonton","nomor","nujum","nyala","nyaman","nyanyi","nyata","nyawa","nyeri","nabati","noda","nominal","norma","nostalgi","notaris","novel","nuansa","nuklir","nutrisi","napas","narkoba","narasi","nasional","natural","navigasi","negatif","negeri","nekat","netral","niaga","nikah","nikmat","nipas","nista","neo"},
    o={"orang","obat","olahraga","oleh","ombak","onak","opini","otak","otot","obeng","objek","obral","obrol","oksigen","oknum","olah","olimpiade","olokan","omong","omzet","oper","operasi","operator","opname","opsi","optik","optimis","oral","orbit","order","organ","organik","orientasi","orisinil","orkestra","ormas","ornamen","otonom","otopsi","output","oval","ovulasi","oksidasi","oreo"},
    p={"pagi","pasir","panas","pohon","pasar","pintu","pulang","pasir","padi","pagar","pahat","pajak","pakai","paksa","paling","paman","panen","panggang","pangkat","pantai","papan","parah","parkir","paruh","pasang","pasti","pasukan","patuh","payung","pecah","pedas","pegang","pelan","pelari","pilih","pindah","pinjam","piring","pisang","pohon","potong","pukul","pulau","punya","pusat","putih","putri","paleo","pemeo","prodeo","perdeo","party","property","policy","paradox"},
    q={"qari","quran","qasar","qada","qadar","qamat","qanun","qurban"},
    r={"rumah","raja","rambut","ramai","rantai","rapat","rasa","rata","rawat","raya","rebah","rebut","reda","redup","rejeki","rekam","relawan","remang","renang","rendah","rendam","renovasi","rentang","repot","resah","resmi","restu","retak","ribu","ribut","ringan","raba","rabu","racun","radang","radio","ragu","rahang","rahasia","rahim","rahmat","rakyat","ramah","ramalan","rambu","rampok","ramuan","ranjang","ranjau","ransel","romeo","rodeo","rely"},
    s={"siang","satu","sepatu","sungai","surat","sabar","sajak","sakit","salah","sama","sampah","sampai","sana","sandal","sandar","sangat","sanggup","santan","santun","sapa","sapu","saran","sarapan","sarung","satu","saudara","sayang","sayap","sayur","sebab","sebar","sebut","sedang","sedih","sedikit","sehat","sejak","selamat","selasa","selatan","selesai","selimut","selokan","seluruh","semangat","sembilan","semoga","sempat","senang","sendiri","stereo","seleo","strategy","safety","sintaks","seks"},
    t={"tangan","teman","timur","tanah","tanam","tanda","tangga","tangis","tanya","tari","taruh","tawar","tebal","tegak","tegas","tekad","telur","tembak","tempo","tenang","tengah","tepat","terang","terjun","tertib","tetap","tiang","tidur","tikus","timba","tinta","tirai","tolong","tongkat","topeng","tugas","tuhan","tujuh","tulang","tulus","tumbuh","tumis","tumpah","tunduk","tuntas","turun","tusuk","tabrak","tabu","type","typhus","teologi"},
    u={"ular","udara","ubah","ucap","udang","ujian","ukir","ukur","ulang","ulat","umpan","umpat","undur","unggas","unik","unjuk","untung","upah","upaya","urai","usaha","usai","usap","utama","utang","utuh","utusan","ubur","uji","ukuran","ulah","ulet","ulung","umbi","umum","undang","unduh","ungkap","ungu","universitas","unsur","untuk","urus","urut","usang","usia","usir","usul","utara"},
    v={"vaksin","variasi","viola","vokal","volume","vital","visi","visa","vulkan","valid","validasi","vanili","vapor","vas","vegetasi","vendor","ventilasi","verbal","verifikasi","vertikal","veteran","veto","video","vila","viral","virtual","virus","vitamin","vokalis","volt","vonis"},
    w={"waktu","warna","wajah","wajar","walet","wangi","warga","warung","wasit","wawasan","wilayah","wisata","wujud","wudhu","wahyu","walau","wali","wanita","waras","wartawan","wadah","waduk","wafat","wahana","wajib","wakaf","wakil","warisan","warta","watak","wawancara","wayang"},
    x={"xenon","xilofon","xerox"},
    y={"yakin","yang","yatim","yoga","yuran","yoyo","yayasan","yodium","yunani","yunior","yurisdiksi"},
    z={"zaman","zat","zebra","zona","zodiak","zaitun","zamrud","ziarah","zalim","zenit","zigzag","zirah","zombi","zuhur","zuriat"},
    ks={"ksantofil","ksenon","ksilofon","ksilem"},
    ox={"oxford","oxygen","oxytocin"}
}


-- === STATS TRACKER ===
-- (STATS ditangani di deklarasi forward di atas)

-- === UI ELEMENTS HANDLES ===
UIElements = {
    StatusParagraph = nil,
    StatsParagraph = nil,
    LogParagraph = nil
}

-- ╔════════════════════════════════════════════════════════════╗
-- ║     WORD LIST LOADER (HTTP)                               ║
-- ╚════════════════════════════════════════════════════════════╝

local function parseWordList(rawText)
    local db = {}
    local count = 0
    local processed = 0
    
    local function yieldCheck()
        processed = processed + 1
        if processed % 500 == 0 then task.wait() end
    end
    
    -- Auto-detect JSON
    local isJSON = rawText:match("^%s*[%{%[]")
    if isJSON then
        log("📦 JSON Wordlist terdeteksi! Mengekstrak kata...")
        local success, data = pcall(function() return HttpService:JSONDecode(rawText) end)
        if success then
            local function extractWords(node)
                if type(node) == "string" then
                    yieldCheck()
                    local word = node:lower():gsub("^%s+", ""):gsub("%s+$", "")
                    if word:match("^[a-z]+$") and not word:find("%s") and not word:find("-") then
                        if #word >= CONFIG.MinWordLength and #word <= CONFIG.MaxWordLength then
                            local first = word:sub(1, 1)
                            if not db[first] then db[first] = {} end
                            if not table.find(db[first], word) then
                                table.insert(db[first], word)
                                WORDS_SOURCE_DB[word] = true
                                count = count + 1
                            end
                        end
                    end
                elseif type(node) == "table" then
                    for _, v in pairs(node) do extractWords(v) end
                end
            end
            extractWords(data)
            if count > 0 then return db, count end
        end
    end

    -- Auto-detect SQL (INSERT INTO pattern)
    if rawText:find("INSERT INTO") then
        log("🗄 SQL Wordlist terdeteksi! Mengekstrak data...")
        for val in rawText:gmatch("%('%s*([^']-)%s*'%s*,") do
            yieldCheck()
            local word = val:lower():gsub("^%s+", ""):gsub("%s+$", "")
            if word:match("^[a-z]+$") and not word:find("%s") and not word:find("-") then
                if #word >= CONFIG.MinWordLength and #word <= CONFIG.MaxWordLength then
                    local first = word:sub(1, 1)
                    if not db[first] then db[first] = {} end
                    if not table.find(db[first], word) then
                        table.insert(db[first], word)
                        WORDS_SOURCE_DB[word] = true
                        count = count + 1
                    end
                end
            end
        end
        if count > 0 then return db, count end
    end

    -- Fallback to line-based parsing (TXT/LST)
    for line in rawText:gmatch("[^\r\n]+") do
        yieldCheck()
        local word = line:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if word:match("^[a-z]+$") and #word >= CONFIG.MinWordLength and #word <= CONFIG.MaxWordLength then
            local firstChar = word:sub(1, 1)
            if not db[firstChar] then db[firstChar] = {} end
            if not table.find(db[firstChar], word) then
                table.insert(db[firstChar], word)
                WORDS_SOURCE_DB[word] = true
                count = count + 1
            end
        end
    end
    return db, count
end

local function httpGet(url)
    local success, result
    success, result = pcall(function() return game:HttpGet(url) end)
    if success and type(result) == "string" and #result > 100 then return result end
    return nil
end

local function loadWordListFromURL()
    loadingStatus = "Memuat..."
    local anySuccess = false
    
    -- Gunakan SET GLOBAL untuk percepatan cek duplikat (O(1) vs table.find O(n))
    local GLOBAL_UNIQUE_SET = {}
    for char, words in pairs(KATA_DB) do
        for _, w in ipairs(words) do
            GLOBAL_UNIQUE_SET[w] = true
        end
    end
    
    for i, url in ipairs(CONFIG.WordListURLs) do
        -- Skip jika URL sudah pernah dimuat sukses di sesi ini
        if not CONFIG.LoadedURLs[url] then
            loadingStatus = string.format("Mencoba sumber %d/%d...", i, #CONFIG.WordListURLs)
            local rawText = httpGet(url)
            if rawText and #rawText > 100 then
                local db, count = parseWordList(rawText)
                if count > 0 then
                    -- MERGE FAST (O(1) checks)
                    for char, words in pairs(db) do
                        if not KATA_DB[char] then KATA_DB[char] = {} end
                        for _, w in ipairs(words) do
                            if not GLOBAL_UNIQUE_SET[w] then
                                table.insert(KATA_DB[char], w)
                                GLOBAL_UNIQUE_SET[w] = true
                                WORDS_SOURCE_DB[w] = true
                            end
                        end
                        task.wait() -- YIELD saat merge agar FPS tidak drop
                    end
                    anySuccess = true
                    wordListLoaded = true
                    CONFIG.LoadedURLs[url] = true
                end
            end
            task.wait(0.2)
        end
    end
    
    if anySuccess then
        local totalUnik = 0
        for _, words in pairs(KATA_DB) do
            totalUnik = totalUnik + #words
        end
        totalWordsLoaded = totalUnik
        loadingStatus = "✅ Berhasil Memuat (" .. totalWordsLoaded .. " kata)"
        table.clear(GLOBAL_UNIQUE_SET) -- Cleanup memory
        return true
    end
    
    loadingStatus = "⚠ Semua sumber gagal, menggunakan fallback"
    return false
end

local function loadFallbackDB()
    KATA_DB = {
        a={"apel","awan","angin","api","air","alam","anak","ayam","asap","akar","angsa","arus","arah","adik","abang","ampun","andal","asli","awas","acara","agung","ajaib","akrab","alat","amal","antar","arif","aktif","alur","amis","atap","awal","aksi","ambil","angkat","antik","asing","aset","awam","aksara","album","akhir","akur","alamat","alasan","aliran","amanah","amarah","ambang","arsip","artis","aturan","aurora","avokad","aloe"},
        b={"buku","batu","bulan","bumi","burung","bola","bunga","besar","baik","baru","biru","berani","bintang","bosan","buah","bakso","bambu","banjir","batas","bayar","beban","bedak","belut","benang","berita","besok","bocor","boleh","bubur","bulat","buruk","busuk","bebas","bekal","benci","beras","berkah","betul","bijak","bocah","boneka","bukit","bumbu","bunyi","badak","balok","bangku","barang","benda","bersih","beo","baileo","boe"},
        c={"cinta","cuaca","cahaya","cantik","cepat","cukup","cari","catat","cemas","cerdas","cerah","cerita","cicak","coklat","contoh","cubit","cuka","culik","cumi","cangkir","capek","celana","cemara","cendol","cermin","cincin","cocok","cukur","curang","cabai","cakar","cambuk","capung","catur","celah","cipta","cium","cuci","cacat","cagar","campur","canda","candu","canggih","cetak","citra","copet","cyber","cyborg","cyan","cameo","currency"},
        d={"danau","daun","desa","dunia","dekat","dalam","daging","dahan","damai","datang","debu","deras","dingin","domba","dosen","dua","duit","duku","duri","dusta","dahulu","dampak","dapat","dasar","datar","dendam","depan","detik","diam","didik","dinas","dodol","dongeng","dorong","duduk","dukun","duren","daerah","daftar","darat","daya","debat","delima","delta","demam","desain","dewasa","dialog","daily","democracy","duty"},
        e={"elang","emas","enak","emosi","embun","ekor","empat","era","esok","elastis","elok","empuk","endap","energi","entah","erosi","eskrim","etika","ekonomi","ekstra","elegan","efek","efektif","ego","ejaan","elemen","elite","ember","enam","enggan","enzim","epidemi","episode","erupsi","esai","estetika","etis","euforia","evaluasi","evolusi","emergency","energy","efficiency","efficacy","eon","eosin","eosen","eolit"},
        f={"foto","fakta","fokus","favorit","festival","final","flamingo","flora","fungsi","fajar","fantasi","fauna","figur","film","fisik","fondasi","formal","fosil","futsal","fasilitas","fenomena","fitur","formula","forum","fabel","fakultas","farmasi","fatal","fiksi","filosof","filter","finansial","firasat","firman","flu","fobia","forensik","format","family","fancy","fly","fox"},
        g={"gajah","gunung","garam","gitar","gelap","gembira","guru","gagal","galak","garang","garuk","gatal","gedung","gelang","gema","gempa","gerak","getah","gila","goreng","gosip","gulai","guntur","gadis","galang","ganda","ganggu","garasi","gaul","gawat","gelombang","genap","gerbang","gigit","gabus","gadai","gagasan","gaib","gairah","gaji","galeri","gambar","gampang","ganti","gantung","garpu","gas","gaya","gym","gyro","geologi","geology","gypsum"},
        h={"hari","hujan","hutan","hitam","hijau","habis","hadiah","halus","hantu","harap","harga","hasil","hebat","hemat","hewan","hidup","hilang","hitung","hobi","hormat","hotel","hubung","hukum","huruf","harus","hidung","hadir","hafal","haji","hakim","halal","halaman","hamil","hampir","hancur","hangat","hapus","harta","harum","hati","haus","hayat","heboh","helm","hening","heran","herbal","hero"},
         i={"ikan","indah","istana","ikat","ilmu","intan","isi","ide","imbang","ingin","iris","isap","istri","iblis","idola","iklan","impian","inap","induk","ingat","injak","inovasi","insaf","intai","iseng","itik","iuran","ibu","identitas","ikut","ilalang","ilustrasi","imam","impor","imun","imut","indera","individu","industri","infeksi","inflasi","info","inisiatif","input","inspeksi","idaman","igauan","ihwal","ijazah","ijil","ijok","ikal","ikatan","ikhlas","ikhtiar","ikhtisar","iklim","ikrar","ikon","ilusi","imajinasi","imbalan","imigrasi","implikasi","impuls","indekos","indeks","indikasi","infra","infus","ingatan","inheren","inisial","injeksi","inklusif","inkubasi","insentif","insiden","insinyur","insomnia","insting","institusi","instruksi","instrumen","intelek","intens","interaksi","internal","interpretasi","interupsi","inti","intimidasi","intip","intrik","introduksi","intuisi","invasi","inventaris","investasi","invitasi","ironi","irigasi","isarat","isolasi","istilah","istirahat","isunya","isyarat","isbat","isoman","isotonik","isozim","istana","istiadat","istikharah","istimewa","istinja","istira","itibak","itidal","itikad","itit","iuran","iya","izafah","izin"},
        j={"jalan","jeruk","jatuh","jarak","jelas","jendela","jernih","jiwa","jual","jubah","judi","jujur","jumpa","jurus","jahat","jamin","jamu","jangan","jangkar","jawab","jemput","jerat","jerit","jabat","jadi","jadwal","jaga","jagat","jago","jagung","jahit","jajan","jaksa","jalur","jam","jambu","janda","janji","jantung","jaring","jarum","jati","jauh","jawa","jaya","jebak","joe"},
        k={"kucing","kuda","kapal","kunci","kain","kabar","kacang","kadal","kaget","kalung","kamar","kamus","kanan","kapas","kapur","karang","kartu","kasur","kayu","kecil","kedai","kejar","kelam","kemah","kenal","keran","keris","kilat","kipas","kolam","kompas","kotak","kulit","kuman","kumis","kupas","kursi","kabut","kagum","kakak","kalah","kabel","kaca","kacau","kafe","kail","kaji","kali","kambing","kantor","kameo","keseleo"},
        l={"laut","langit","lebar","lemah","lihat","lucu","ladang","lalat","lampu","lapar","lapis","lari","latih","lauk","lawan","layar","lebah","lehar","lemari","lemon","lengkap","lepas","lewat","liar","lilin","limbah","lincah","lomba","loyal","lunak","lurus","luka","lumut","lacak","laci","lagu","lahar","lahan","lahir","lain","laku","lama","lamar","lambat","lancar","langkah","langsung","lantai","lapor","laras","leo","legacy","lobby","lyric","lyra"},
        m={"makan","minum","mata","malam","mobil","meja","merah","masak","maju","malu","mandi","manis","marah","masuk","mati","menang","merdu","mimpi","miskin","muda","mulut","murid","musik","musuh","macan","madu","mahasiswa","main","majelis","makna","maksimal","maksud","mampu","mana","mandi","mangga","mangkok","mantan","manusia","mapalus","maritim","martabat","masa","masalah","masyarakat","materi","mazmur","medali","media","medis","museo","maleo","membeo","mercy"},
        n={"nama","nasi","nafas","naga","naik","nakal","namun","nanti","nasib","negara","nelayan","nenek","neraka","ngantuk","niat","nilai","nonton","nomor","nujum","nyala","nyaman","nyanyi","nyata","nyawa","nyeri","nabati","noda","nominal","norma","nostalgi","notaris","novel","nuansa","nuklir","nutrisi","napas","narkoba","narasi","nasional","natural","navigasi","negatif","negeri","nekat","netral","niaga","nikah","nikmat","nipas","nista","neo"},
        o={"orang","obat","oleh","ombak","ondel","opini","otak","obor","odol","oknum","olah","olimpiade","omong","oncom","order","organ","ornamen","oval","oase","obeng","obral","obsesi","ogah","ojek","olahraga","oles","oli","ompol","ongkos","operasi","optimal","optimis","oranye","orasi","orbit","orde","organik","organisasi","orientasi","origami","orkestra","oreo"},
        p={"pagi","pasir","panas","perak","pintu","pohon","pagar","pahat","pajak","pakai","paksa","paling","paman","pandai","panen","pangkal","pantai","papan","parkir","pasar","pasang","patah","pecah","pelan","penuh","perut","pesona","pisau","pokok","potong","puasa","pucat","pucuk","puisi","pukul","pulang","punah","puncak","pupuk","putar","putih","putus","pakan","palsu","pamit","panah","panik","pasti","padang","palu","panjang","paleo","pemeo","prodeo","perdeo","party","property","policy"},
        q={"quran"},
        r={"raja","rumah","rasa","ringan","rusak","racun","raih","rajin","rambut","rampas","rancang","rangka","ranjang","rantai","rapuh","rata","rawat","rebah","rebus","redam","rela","remah","rendah","renung","resah","ribu","rilis","rimbun","rindu","riwayat","robek","rontok","ruang","rubah","rujak","rumit","rumpun","runtuh","rupiah","rusuh","rutin","ruwet","raba","racik","radar","radio","raga","ragam","ragu","rahang","rahasia","rahim","rahmat","rakyat","ramah","ramalan","rambu","rampok","ramuan","ranjang","ranjau","ransel","romeo","rodeo","rely"},
        s={"satu","siang","salju","sabar","sabun","sakit","salah","sama","sampah","sandar","santai","sapi","sapu","saran","saudara","sawah","sedih","segar","sehat","semen","sendok","sepak","seram","serbu","serikat","serius","sikat","silau","simpan","siram","sisir","sorak","suara","subur","sudah","suhu","sujud","sukses","sulap","sumber","sumpah","sungai","suntik","supir","surat","surga","sadar","sadis","saksi","sakti","stereo","seleo","strategy","safety"},
        t={"tangan","teman","timur","tanah","tanam","tanda","tangga","tangis","tanya","tapak","tari","taruh","tawar","tebal","tegak","tegas","tekad","telur","tembak","tempo","tenang","tengah","tepat","terang","terjun","tertib","tetap","tiang","tidur","tikus","timba","tinta","tirai","tolong","tongkat","topeng","tugas","tuhan","tujuh","tulang","tulus","tumbuh","tumis","tumpah","tunduk","tuntas","turun","tusuk","tabrak","tabu","type","typhus","teologi"},
        u={"ular","udara","ubah","ucap","udang","ujian","ukir","ukur","ulang","ulat","umpan","umpat","undur","unggas","unik","unjuk","untung","upah","upaya","urai","usaha","usai","usap","utama","utang","utuh","utusan","ubur","uji","ukuran","ulah","ulet","ulung","umbi","umum","undang","unduh","ungkap","ungu","universitas","unsur","untuk","urus","urut","usang","usia","usir","usul","utara"},
        v={"vaksin","variasi","viola","vokal","volume","vital","visi","visa","vulkan","valid","validasi","vanili","vapor","vas","vegetasi","vendor","ventilasi","verbal","verifikasi","vertikal","veteran","veto","video","vila","viral","virtual","virus","vitamin","vokalis","volt","vonis"},
        w={"waktu","warna","wajah","wajar","walet","wangi","warga","warung","wasit","wawasan","wilayah","wisata","wujud","wudhu","wahyu","walau","wali","wanita","waras","wartawan","wadah","waduk","wafat","wahana","wajib","wakaf","wakil","warisan","warta","watak","wawancara","wayang"},
        x={"xenon","xilofon","xerox"},
        y={"yakin","yang","yatim","yoga","yuran","yoyo","yayasan","yodium","yunani","yunior","yurisdiksi"},
        z={"zaman","zat","zebra","zona","zodiak","zaitun","zamrud","ziarah","zalim","zenit","zigzag","zirah","zombi","zuhur","zuriat"},
        ks={"ksantofil","ksenon","ksilofon","ksilem"},
        ox={"oxford","oxygen","oxytocin"}
    }
    totalWordsLoaded = 0
    for _, words in pairs(KATA_DB) do
        totalWordsLoaded = totalWordsLoaded + #words
    end
    loadingStatus = "⚠ Fallback: " .. totalWordsLoaded .. " kata"
end

-- ╔════════════════════════════════════════════════════════════╗
-- ║     WORD FINDER                                           ║
-- ╚════════════════════════════════════════════════════════════╝

local function findWord(prefix, excludeWord, tempExclusions, silent)
    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
    prefix = string.lower(tostring(prefix or "")):gsub("%s+", "")
    if prefix == "" then return nil end
    
    local firstChar = prefix:sub(1, 1)
    local wordList = KATA_DB[firstChar]
    if not wordList or #wordList == 0 then return nil end

    -- === KUMPULKAN KATA YANG VALID ===
    local function isWordValid(v, ignoreBlacklist)
        v = tostring(v or ""):lower()
        if #v < 2 then return false end
        if v:sub(1, #prefix) ~= prefix then return false end
        if v == excludeWord then return false end
        if tempExclusions and tempExclusions[v] then return false end
        if gameUsedWords[v] or usedWords[v] then return false end
        
        -- Blacklist Check (Hanya jika tidak sedang di-ignore)
        if not ignoreBlacklist and CONFIG.IndexBlacklist and GLOBAL_INDEX_BLACKLIST[v] then 
            return false 
        end
        
        -- SARINGAN ANTI-SAMPAH
        if not v:match("[aeiou]") then return false end
        
        return true
    end

    if CONFIG.DebugMode and not silent then log("🔍 Mencari kata awalan: '" .. prefix .. "'") end

    local function getMatchedWords(ignoreBlacklist)
        local results = {}
        for _, v in ipairs(wordList) do
            if isWordValid(v, ignoreBlacklist) then table.insert(results, v) end
        end
        if SERVER_KNOWN_WORDS[firstChar] then
            for _, v in ipairs(SERVER_KNOWN_WORDS[firstChar]) do
                if isWordValid(v, ignoreBlacklist) then
                    if not table.find(results, v) then table.insert(results, v) end
                end
            end
        end
        return results
    end

    local matched = getMatchedWords(false)
    
    if #matched == 0 and CONFIG.IndexBlacklist then
        if CONFIG.DebugMode then log("⚠️ Kata baru habis/ter-blacklist! Mencari kata lama...") end
        matched = getMatchedWords(true)
    end

    if #matched == 0 then 
        if not silent then log("❌ GAGAL: Tidak menemukan kata untuk '" .. prefix:upper() .. "'") end
        return nil 
    end

    if CONFIG.KillerMode then
        -- Tabel Bobot Resmi Server (Berdasar WordService.lua)
        local SERVER_WEIGHTS = {
            {max = 6,  w = {70, 30, 0}},  -- Ronde 1-6: 3 huruf (0%)
            {max = 12, w = {55, 45, 5}},  -- Ronde 7-12: 3 huruf (5%)
            {max = 18, w = {35, 50, 15}}, -- Ronde 13-18: 3 huruf (15%)
            {max = 24, w = {20, 45, 35}}, -- Ronde 19-24: 3 huruf (35%)
            {max = 999,w = {10, 35, 55}}  -- Ronde 25+: 3 huruf (55%)
        }

        local function getPrefixAvailability(prefix)
            if prefixCache[prefix] then return prefixCache[prefix] end
            local first = prefix:sub(1,1):lower()
            local count = 0
            pcall(function()
                if KATA_DB[first] then
                    for _, w in ipairs(KATA_DB[first]) do
                        if w:sub(1, #prefix) == prefix then 
                            count = count + 1 
                            if count >= 3 then break end 
                        end
                    end
                end
                if count < 3 and SERVER_KNOWN_WORDS[first] then
                    for _, w in ipairs(SERVER_KNOWN_WORDS[first]) do
                        if w:sub(1, #prefix) == prefix then 
                            count = count + 1 
                            if count >= 3 then break end
                        end
                    end
                end
            end)
            prefixCache[prefix] = count
            return count
        end

        local function getSuffixScore(word)
            local s3 = word:sub(-3)
            local s2 = word:sub(-2)
            local s1 = word:sub(-1)
            
            local avail3 = getPrefixAvailability(s3) >= 3
            local avail2 = getPrefixAvailability(s2) >= 3
            
            local currentW = {100, 0, 0}
            for _, v in ipairs(SERVER_WEIGHTS) do
                if matchRoundCount <= v.max then
                    currentW = v.w
                    break
                end
            end

            local ev = 0
            if avail3 and currentW[3] > 0 then
                ev = ev + (currentW[3] * (HARD_ENDING_SCORE[s3] or 200)) / 100
            end
            if avail2 and currentW[2] > 0 then
                ev = ev + (currentW[2] * (HARD_ENDING_SCORE[s2] or 150)) / 100
            end
            if currentW[1] > 0 then
                ev = ev + (currentW[1] * (HARD_ENDING_SCORE[s1] or 0)) / 100
            end
            return ev
        end

        local wordScores = {}
        for i, w in ipairs(matched) do
            wordScores[w] = getSuffixScore(w)
            if i % 100 == 0 then task.wait() end
        end

        table.sort(matched, function(a, b)
            local scoreA = wordScores[a]
            local scoreB = wordScores[b]
            if scoreA ~= scoreB then return scoreA > scoreB end
            return #a > #b
        end)

        -- Log Prediksi Target yang REALISTIS (Probabilitas Lengkap)
        local best = matched[1]
        local s1, s2, s3 = best:sub(-1), best:sub(-2), best:sub(-3)
        
        local weightInfo = {w={100,0,0}}
        for _, v in ipairs(SERVER_WEIGHTS) do if matchRoundCount <= v.max then weightInfo = v break end end
        
        local possibilities = {}
        -- 1 Huruf
        if weightInfo.w[1] > 0 then
            table.insert(possibilities, s1:upper() .. " (" .. weightInfo.w[1] .. "%)")
        end
        -- 2 Huruf
        if weightInfo.w[2] > 0 and getPrefixAvailability(s2) >= 3 then
            table.insert(possibilities, s2:upper() .. " (" .. weightInfo.w[2] .. "%)")
        end
        -- 3 Huruf
        if weightInfo.w[3] > 0 and getPrefixAvailability(s3) >= 3 then
            table.insert(possibilities, s3:upper() .. " (" .. weightInfo.w[3] .. "%)")
        end
        
        if not silent and #possibilities > 0 then
            log("🔒 Luck Factor: " .. table.concat(possibilities, " | "))
        end
    end

    -- 2. Strategi Index Hunter (Jika FastCollection ON)
    if CONFIG.FastCollection then
        local uniqueMatched = {}
        for _, w in ipairs(matched) do
            if not sessionUsedWords[w] then table.insert(uniqueMatched, w) end
        end
        
        if #uniqueMatched > 0 then
            -- Tetap jaga 'Locking' jika KillerMode aktif
            if CONFIG.KillerMode then
                table.sort(uniqueMatched, function(a, b)
                    return (HARD_ENDING_SCORE[a:sub(-1)] or 0) > (HARD_ENDING_SCORE[b:sub(-1)] or 0)
                end)
            end
            return uniqueMatched[1]
        end
    end

    if not CONFIG.KillerMode then
        return matched[math.random(1, #matched)]
    end

    return matched[1]
end

-- === FIND ALL MATCHING WORDS (UNTUK AUTO SUGGESTER) ===
local function findAllWords(prefix, maxResults)
    if not prefix or prefix == "" then return {} end
    prefix = string.lower(tostring(prefix)):gsub("%s+", "")
    if prefix == "" then return {} end
    maxResults = maxResults or CONFIG.AutoSuggestMax or 50
    
    local firstChar = prefix:sub(1, 1)
    local wordList = KATA_DB[firstChar]
    if not wordList or #wordList == 0 then return {} end
    
    local results = {}
    local seen = {}
    
    -- Dari KATA_DB
    for _, v in ipairs(wordList) do
        v = tostring(v or ""):lower()
        if #v >= 2 and v:sub(1, #prefix) == prefix and not seen[v] then
            if not gameUsedWords[v] and not usedWords[v] then
                if v:match("[aeiou]") then -- Anti-sampah
                    table.insert(results, v)
                    seen[v] = true
                    if #results >= maxResults then break end
                end
            end
        end
    end
    
    -- Dari SERVER_KNOWN_WORDS
    if #results < maxResults and SERVER_KNOWN_WORDS[firstChar] then
        for _, v in ipairs(SERVER_KNOWN_WORDS[firstChar]) do
            v = tostring(v or ""):lower()
            if #v >= 2 and v:sub(1, #prefix) == prefix and not seen[v] then
                if not gameUsedWords[v] and not usedWords[v] then
                    if v:match("[aeiou]") then
                        table.insert(results, v)
                        seen[v] = true
                        if #results >= maxResults then break end
                    end
                end
            end
        end
    end
    
    -- Sort: kata pendek dulu (lebih mudah dipilih), lalu abjad
    table.sort(results, function(a, b)
        if #a ~= #b then return #a < #b end
        return a < b
    end)
    
    return results
end

local function animateMobileKeys(char)
    pcall(function()
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        local matchUI = gui and gui:FindFirstChild("MatchUI")
        local bottomUI = matchUI and matchUI:FindFirstChild("BottomUI")
        if not bottomUI then return end

        char = string.upper(tostring(char or ""))
        
        -- 1. Animasi Tombol Keyboard (Optimized with Cache)
        local keyboard = bottomUI:FindFirstChild("Keyboard")
        if keyboard and char ~= "" then
            local btn = keyboardCache[char]
            if not btn or btn.Parent == nil then
                btn = keyboard:FindFirstChild(char, true)
                keyboardCache[char] = btn
            end
            
            if btn and btn:IsA("GuiObject") then
                local uiScale = btn:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", btn)
                local prop = btn:IsA("TextButton") and "BackgroundColor3" or "ImageColor3"
                local originalColor = btn[prop]
                
                uiScale.Scale = 0.85
                btn[prop] = Color3.fromRGB(200, 200, 200)
                task.delay(0.1, function() 
                    if btn and btn.Parent then
                        uiScale.Scale = 1 
                        btn[prop] = originalColor
                    end
                end)
            end
        end

        -- 2. Update Kotak Huruf (WordSubmit)
        local topUI = bottomUI:FindFirstChild("TopUI")
        local wordSubmit = topUI and topUI:FindFirstChild("WordSubmit")
        local template = topUI and topUI:FindFirstChild("Templates") and topUI.Templates:FindFirstChild("Word")
        
        if wordSubmit and template then
            local currentWord = (_G.SK_CURRENT_PARTIAL or ""):upper()
            
            -- Sembunyikan semua kotak lama
            for _, v in ipairs(wordSubmit:GetChildren()) do
                if v:IsA("TextLabel") then v.Visible = false end
            end
            
            -- Tampilkan label sesuai panjang kata
            for i = 1, #currentWord do
                local charAt = currentWord:sub(i,i)
                local label = wordSubmit:FindFirstChild("L" .. i)
                if not label then
                    label = template:Clone()
                    label.Name = "L" .. i
                end
                if i == #currentWord then
                    local scale = label:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", label)
                    scale.Scale = 0.6
                    game:GetService("TweenService"):Create(scale, TweenInfo.new(0.1), {Scale = 1}):Play()
                end
            end
        end
    end)
end

local function isCameraFocusedOnMe()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    
    local cam = workspace.CurrentCamera
    local isFocus = (cam.CameraSubject == hum or cam.CameraSubject == root or (cam.CameraSubject and cam.CameraSubject:IsDescendantOf(char)))
    if not isFocus then
        local dist = (cam.CFrame.p - root.Position).Magnitude
        if dist < 15 then isFocus = true end
    end
    return isFocus
end

local function isBotGuiInstance(inst)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local anc = inst
    while anc and anc ~= pg do
        local n = anc.Name:lower()
        if n == "sk_overlay" or n:find("windui") or n:find("starship") then return true end
        anc = anc.Parent
    end
    return false
end

local function collectMatchInputTextBoxes()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return {} end
    local list, seen = {}, {}
    for _, v in ipairs(pGui:GetDescendants()) do
        if v.Name == "WordServerFrame" then
            local sg = v
            while sg and not sg:IsA("ScreenGui") do sg = sg.Parent end
            if sg then
                for _, d in ipairs(sg:GetDescendants()) do
                    if d:IsA("TextBox") and d.Visible and d.Transparency < 1
                        and d.Name ~= "WindUI_Input" and not isBotGuiInstance(d) then
                        if not seen[d] then seen[d] = true; table.insert(list, d) end
                    end
                end
            end
            if #list > 0 then return list end
        end
    end
    return list
end

local function findGameTextBox()
    local list = collectMatchInputTextBoxes()
    if #list > 0 then return list[1] end
    local pGui = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
    local best, bestScore = nil, -1
    for _, v in ipairs(pGui:GetDescendants()) do
        if v:IsA("TextBox") and v.Visible and v.Transparency < 1 and v.Name ~= "WindUI_Input" and not isBotGuiInstance(v) then
            local score = 0
            local anc = v.Parent
            local d = 0
            while anc and anc ~= pGui and d < 18 do
                local ln = anc.Name:lower()
                if ln:find("word") then score = score + 6 end
                if ln:find("input") or ln:find("answer") or ln:find("type") then score = score + 4 end
                if ln:find("match") or ln:find("server") or ln:find("game") then score = score + 2 end
                anc = anc.Parent
                d = d + 1
            end
            pcall(function() if v:IsFocused() then score = score + 12 end end)
            if score > bestScore then bestScore, best = score, v end
        end
    end
    return best
end

local function clearSingleTextBox(targetTextBox, minBackspaces)
    minBackspaces = math.max(48, minBackspaces or 0)
    pcall(function()
        targetTextBox:CaptureFocus()
        task.wait(0.04)
        local VIM = game:GetService("VirtualInputManager")
        local oldLen = #(targetTextBox.Text or "")
        minBackspaces = math.max(minBackspaces, oldLen + 24)
        
        VIM:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
        task.wait(0.02)
        VIM:SendKeyEvent(true, Enum.KeyCode.A, false, game)
        task.wait(0.02)
        VIM:SendKeyEvent(false, Enum.KeyCode.A, false, game)
        VIM:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
        task.wait(0.02)
        VIM:SendKeyEvent(true, Enum.KeyCode.Delete, false, game)
        task.wait(0.02)
        VIM:SendKeyEvent(false, Enum.KeyCode.Delete, false, game)
        VIM:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
        task.wait(0.02)
        VIM:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
        task.wait(0.02)
        
        targetTextBox.Text = ""
        
        VIM:SendKeyEvent(true, Enum.KeyCode.End, false, game)
        task.wait(0.02)
        VIM:SendKeyEvent(false, Enum.KeyCode.End, false, game)
        task.wait(0.02)
        for i = 1, minBackspaces do
            VIM:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
            task.wait(0.007)
            VIM:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
        end
        task.wait(0.04)
        targetTextBox.Text = ""
    end)
end

local function clearInput(extraCharsHint)
    local hint = tonumber(extraCharsHint) or 0
    local boxes = collectMatchInputTextBoxes()
    if #boxes == 0 then
        local tb = findGameTextBox()
        if tb then boxes = { tb } end
    end
    if #boxes == 0 then return end
    local minBs = math.max(48, hint + 20)
    for _, tb in ipairs(boxes) do
        clearSingleTextBox(tb, minBs)
    end
end

function submitWordViaRemote(letter, word)
    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
    
    typingID = typingID + 1
    local myID = typingID
    
    local suffixToSubmit = string.sub(word, #letter + 1):lower():gsub("[^a-z]", "")
    log("📤 Menyiapkan: " .. suffixToSubmit:upper() .. " (ID: " .. myID .. ")")
    
    -- Tunggu ID Rahasia dari MatchUI (Jangan scan manual karena bahaya)
    if not _G.SK_SECRET_ID or _G.SK_SECRET_ID == "0" then
        -- Jika belum ada ID, biarkan ID: 0 (Server akan menolak, tapi lebih baik daripada salah kunci)
    end

    local hint = #suffixToSubmit + #(letter or "") + 20
    clearInput(hint)
    task.wait(0.18)
    
    local function anyTextLeft()
        for _, tb in ipairs(collectMatchInputTextBoxes()) do
            local r = (tb.Text or ""):gsub("%s+", "")
            if #r > 0 then return true, r end
        end
        local tb = findGameTextBox()
        if tb then
            local r = (tb.Text or ""):gsub("%s+", "")
            if #r > 0 then return true, r end
        end
        return false, ""
    end
    local dirty, left = anyTextLeft()
    if dirty then
        log("⚠️ [Submit] Masih ada teks ('" .. left .. "'), clear ulang...")
        clearInput(math.max(hint, #left + 24))
        task.wait(0.18)
    end

    -- Simulasi pengetikan FISIK (VirtualInputManager) dengan Humanization
    local VIM = game:GetService("VirtualInputManager")
    
    -- Speed Scaler untuk Mode Brutal
    local speedMultiplier = 1.0
    if _G.SK_CURRENT_MODE == "Brutal" then
        speedMultiplier = 0.65 -- 35% Lebih Cepat jika Brutal
    end
    
    local typeDelay = (CONFIG.TypeCharDelay or 0.12) * speedMultiplier
    
    -- Jeda awal (Waktu berpikir sebelum mulai ngetik)
    task.wait(math.random(8, 25) * 0.1 * speedMultiplier)

    for i = 1, #suffixToSubmit do
        if typingID ~= myID or not isRunning or not isMyTurn then 
            log("🛑 Pengetikan " .. myID .. " dibatalkan/dihentikan.")
            return 
        end
        
        -- 1. Peluang TYPO (Simulasi kesalahan ketik) - 3% chance
        if math.random(1, 100) <= 3 and i < #suffixToSubmit then
            local wrongChars = "qwertyuiopasdfghjklzxcvbnm"
            local randomIdx = math.random(1, #wrongChars)
            local wrongChar = wrongChars:sub(randomIdx, randomIdx)
            local wrongKey = Enum.KeyCode[wrongChar:upper()]
            
            if wrongKey then
                VIM:SendKeyEvent(true, wrongKey, false, game)
                task.wait(math.random(5, 10) * 0.01)
                VIM:SendKeyEvent(false, wrongKey, false, game)
                task.wait(math.random(15, 30) * 0.01) -- Jeda sadar salah ketik
                
                -- Hapus (Backspace)
                VIM:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
                task.wait(math.random(20, 40) * 0.01) -- Jeda sebelum ngetik ulang
            end
        end

        -- 2. Ketik Karakter Asli
        local char = suffixToSubmit:sub(i,i)
        local key = Enum.KeyCode[char:upper()]
        if key then
            local holdTime = math.random(30, 70) * 0.001 -- Durasi tekan tombol
            VIM:SendKeyEvent(true, key, false, game)
            task.wait(holdTime)
            VIM:SendKeyEvent(false, key, false, game)
        end
        
        -- 3. Jeda Antar Karakter (Rhythm)
        local baseDelay = typeDelay * math.random(8, 14) * 0.1
        
        -- Hesitasi (Peluang berhenti sejenak) - 5% chance
        if math.random(1, 100) <= 5 then
            baseDelay = baseDelay + math.random(5, 12) * 0.1
        end
        
        task.wait(baseDelay)
    end
    
    task.wait(0.2)
    
    -- SAFETY: Cek ulang apakah masih giliran kita sebelum submit
    if not isMyTurn or _G.__SK_REMOTE_TURN == false then
        log("🛑 [ABORT] Submit dibatalkan — bukan giliran kita lagi")
        return
    end
    
    -- [CRITICAL] Submit Final
    if typingID == myID and SubmitWord then 
        local secretID = _G.SK_SECRET_ID or "0"
        log("🔥 [FIRE] Menembak: " .. suffixToSubmit:upper() .. " | ID: " .. tostring(secretID):sub(1,10))
        SubmitWord:FireServer(suffixToSubmit, secretID) 
        
        -- Simulasi Tekan ENTER
        pcall(function()
            local VIM = game:GetService("VirtualInputManager")
            VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.05)
            VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        end)
    elseif typingID ~= myID then
        log("⚠️ [SKIP] ID Mismatch di Submit Final (" .. myID .. " vs " .. typingID .. ")")
    else
        log("⚠️ [ERROR] SubmitWord Remote TIDAK TERDETEKSI!")
    end
    
    lastSubmittedWord = word
    _G.SK_CURRENT_PARTIAL = ""
    animateMobileKeys("")
end

local isRetrying = false
local function triggerRetry(rejectedWord)
    if not CONFIG.AutoRetry or not CONFIG.Enabled or not isMyTurn or not matchActive or isRetrying then return end
    isRetrying = true
    
    typingID = typingID + 1 
    log("🔄 Retry — membatalkan pengetikan lama (typingID: " .. typingID .. ")")
    
    local wordStr = tostring(rejectedWord or lastSubmittedWord or ""):lower()
    if wordStr ~= "" then
        gameUsedWords[wordStr] = true
        usedWords[wordStr] = true
        learnFromServer(wordStr)
    end

    _G.SK_LAST_LETTER = ""
    _G.SK_ANSWER_LOCK = false
    
    local badLen = math.max(#wordStr, #(tostring(lastSubmittedWord or "")))
    clearInput(badLen + 24)
    task.wait(0.35)
    clearInput(badLen + 24)
    task.wait(0.25)
    
    local newWord = findWord(currentLetter, wordStr or "")
    if newWord then
        lastAnswer = newWord
        usedWords[newWord] = true
        log("🔄 Kata baru: " .. newWord .. " (huruf=" .. tostring(currentLetter):upper() .. ")")
        
        local retryDelay = (CONFIG.InteractionMode == "Human" and math.random(3, 8) * 0.1 or 0.1)
        task.wait(retryDelay)
        
        if isRunning and _G.SK_BOT_ID == scriptId and isMyTurn and matchActive then
            isRetrying = false
            submitWordViaRemote(currentLetter, newWord)
        end
    else
        log("⚠️ [Retry] Tidak ada kata alternatif untuk huruf: " .. tostring(currentLetter):upper())
    end
    isRetrying = false
end

-- === FUNGSI: Deteksi huruf via anchor "Hurufnya adalah:" ===
-- Strategi: cari label "Hurufnya adalah:" lalu ambil huruf dari badge sibling/child
local function findLetterViaAnchor(rootGui)
    if not rootGui then return nil end
    local result = nil
    pcall(function()
        local anchor = nil
        for _, desc in ipairs(rootGui:GetDescendants()) do
            pcall(function()
                if not anchor and (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
                    local txt = desc.Text or ""
                    if txt:lower():find("hurufnya") or txt:lower():find("adalah") then
                        anchor = desc
                        local inlineLetter = txt:match("[Hh]urufnya%s+adalah%s*:?%s*(%a+)")
                        if inlineLetter and #inlineLetter >= 1 and #inlineLetter <= 3 then
                            result = inlineLetter:lower()
                        end
                    end
                end
            end)
            if result then break end
        end
        
        if result then return end
        if not anchor then return end
        
        local searchRoot = anchor.Parent
        if not searchRoot then return end
        
        local bestLetter, bestSize = nil, 0
        for depth = 1, 3 do
            if not searchRoot then break end
            for _, child in ipairs(searchRoot:GetDescendants()) do
                pcall(function()
                    if child ~= anchor and (child:IsA("TextLabel") or child:IsA("TextButton")) and child.Visible then
                        local t = (child.Text or ""):gsub("%s+", "")
                        if #t >= 1 and #t <= 3 and t:match("^%a+$") then
                            if not t:lower():find("huruf") and not t:lower():find("adalah")
                               and not t:lower():find("waktu") and not t:lower():find("top") then
                                local fs = child.TextSize or 0
                                if child.TextScaled then
                                    local ok2, absY = pcall(function() return child.AbsoluteSize.Y end)
                                    if ok2 and absY > fs then fs = absY end
                                end
                                if fs > bestSize then
                                    bestLetter = t:lower()
                                    bestSize = fs
                                end
                            end
                        end
                    end
                end)
            end
            if bestLetter then break end
            searchRoot = searchRoot.Parent
        end
        if bestLetter then result = bestLetter end
    end)
    return result
end

-- === FUNGSI: Fallback broad scan (tanpa anchor) ===
local function findLetterBroadScan(rootGui, doDebug)
    if not rootGui then return nil end
    local best, bestFs = nil, 0
    for _, desc in ipairs(rootGui:GetDescendants()) do
        pcall(function()
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Visible then
                local t = (desc.Text or ""):gsub("%s+", "")
                local isScaled = desc.TextScaled
                local fs = desc.TextSize or 0
                local effectiveFs = fs
                if isScaled then
                    local ok2, absY = pcall(function() return desc.AbsoluteSize.Y end)
                    if ok2 and absY > effectiveFs then effectiveFs = absY end
                end
                local sizeOk = isScaled or fs >= 18
                local lenOk = #t >= 1 and #t <= 3
                local alphaOk = t:match("^%a+$") ~= nil
                
                if doDebug and #t >= 1 and #t <= 10 and alphaOk then
                    log("🔍 [UI-Debug] '" .. t .. "' scaled=" .. tostring(isScaled) .. " fs=" .. fs .. " efs=" .. effectiveFs .. " class=" .. desc.ClassName .. " parent=" .. (desc.Parent and desc.Parent.Name or "?"))
                end
                
                if sizeOk and lenOk and alphaOk then
                    if not t:lower():find("huruf") and not t:lower():find("adalah")
                       and not t:lower():find("waktu") and not t:lower():find("top") 
                       and not t:lower():find("ok") then
                        local isBotUI = false
                        local anc = desc.Parent
                        local d = 0
                        while anc and anc ~= rootGui and d < 8 do
                            local n = anc.Name
                            if n == "SK_Overlay" or n:find("WindUI") or n:find("Starship") then
                                isBotUI = true; break
                            end
                            anc = anc.Parent; d = d + 1
                        end
                        if not isBotUI and effectiveFs > bestFs then
                            best = t:lower()
                            bestFs = effectiveFs
                        end
                    end
                end
            end
        end)
    end
    return best, bestFs
end

local _onMyTurnRunning = false

function onMyTurn(force)
    if not isRunning or _G.SK_BOT_ID ~= scriptId or not CONFIG.Enabled then return end
    if not isMyTurn or _G.__SK_REMOTE_TURN == false then return end
    
    if _onMyTurnRunning then
        if force then
            log("⚡ [onMyTurn] Sudah berjalan, skip panggilan duplikat")
        end
        return
    end
    _onMyTurnRunning = true
    
    log("▶️ [onMyTurn] Mulai (force=" .. tostring(force) .. " letter=" .. tostring(currentLetter) .. " lock=" .. tostring(_G.SK_ANSWER_LOCK) .. ")")
    
    if currentLetter == "" or currentLetter == "-" then
        local waitStart = tick()
        log("⏳ Menunggu huruf dari server...")
        local scanAttempt = 0
        while (currentLetter == "" or currentLetter == "-") and (tick() - waitStart) < 8 do
            if scanAttempt > 0 then
                task.wait(0.15)
            end
            if not isRunning or not isMyTurn or _G.SK_BOT_ID ~= scriptId or _G.__SK_REMOTE_TURN == false then _onMyTurnRunning = false; return end
            
            scanAttempt = scanAttempt + 1
            if scanAttempt == 1 or scanAttempt % 3 == 0 then
                pcall(function()
                    if (_G.__SK_REMOTE_LETTER or "") ~= "" then
                        currentLetter = _G.__SK_REMOTE_LETTER
                        return
                    end
                    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                    if not pGui then return end
                    
                    for _, sg in ipairs(pGui:GetChildren()) do
                        if sg:IsA("ScreenGui") and sg.Enabled then
                            local letter = findLetterViaAnchor(sg)
                            if letter then
                                currentLetter = letter
                                _G.__SK_REMOTE_LETTER = letter
                                log("📡 [Anchor-Scan] Huruf: " .. letter:upper())
                                return
                            end
                        end
                    end
                    
                    local doDebug = (scanAttempt == 5)
                    for _, sg in ipairs(pGui:GetChildren()) do
                        if sg:IsA("ScreenGui") and sg.Enabled then
                            local letter = findLetterBroadScan(sg, doDebug)
                            if letter then
                                currentLetter = letter
                                _G.__SK_REMOTE_LETTER = letter
                                log("📡 [Broad-Scan] Huruf: " .. letter:upper())
                                return
                            end
                        end
                    end
                end)
            end
        end
        if currentLetter == "" or currentLetter == "-" then
            log("⚠️ [onMyTurn] Timeout 8s menunggu huruf — skip turn")
            _onMyTurnRunning = false
            return 
        end
        log("✅ Huruf diterima: " .. currentLetter:upper())
    end
    
    if not force then
        if _G.SK_ANSWER_LOCK then
            log("🚫 [onMyTurn] BLOCKED oleh SK_ANSWER_LOCK (letter=" .. tostring(currentLetter) .. ") — force unlock")
            _G.SK_ANSWER_LOCK = false
        end
        if currentLetter == _G.SK_LAST_LETTER and currentLetter ~= "" then
            log("⚠️ [onMyTurn] Huruf sama dgn sebelumnya (" .. tostring(currentLetter) .. ") — lanjut karena turn baru")
        end
    end
    
    -- === STEALTH: Tunggu Kamera Fokus ===
    if not force then
        local camWait = tick()
        local logged = false
        while isRunning and isMyTurn and not isCameraFocusedOnMe() do
            if not logged then
                log("🎥 [Stealth] Menunggu kamera fokus ke karakter...")
                logged = true
            end
            if tick() - camWait > 2.5 then 
                log("🎥 [Stealth] Kamera tidak fokus, lanjut mengetik untuk menghindari timeout.")
                break 
            end
            task.wait(0.2)
        end
        task.wait(math.random(4, 9) / 10) -- Jeda reaksi manusia
    end

    if not isMyTurn and not force then _onMyTurnRunning = false; return end
    _G.SK_ANSWER_LOCK = true
    _G.SK_LAST_LETTER = currentLetter
    
    local targetWord = findWord(currentLetter)
    if not targetWord then
        notify("Data Error", "Kosakata tidak ditemukan!")
        _G.SK_ANSWER_LOCK = false
        _onMyTurnRunning = false
        return
    end


    local delay = CONFIG.MinDelay
    if CONFIG.UseRandomDelay then
        delay = CONFIG.MinDelay + math.random() * (CONFIG.MaxDelay - CONFIG.MinDelay)
    end
    
    if delay > 0 then task.wait(delay) end
    if not isRunning or _G.SK_BOT_ID ~= scriptId then _onMyTurnRunning = false; return end

    if matchActive and isMyTurn then
        lastAnswer = targetWord
        if CONFIG.AvoidRepeat then usedWords[targetWord] = true end
        log("✏️ [onMyTurn] Mengetik: " .. targetWord .. " (huruf=" .. currentLetter:upper() .. ")")
        submitWordViaRemote(currentLetter, targetWord)
    end
    _G.SK_ANSWER_LOCK = false
    _onMyTurnRunning = false
end


Window = WindUI:CreateWindow({
    Title = "STARSHIP┃dsc.gg-starshipcore",
    Icon = "rbxassetid://85930777472774", 
    IconSize = 45, 
    Author = "Premium Edition | StarshipCore",
 	Size = UDim2.fromOffset(630, 350),
	SideBarWidth = 180,
    Transparent = true,
    BackgroundImageTransparency = 0.92,
    Background = "rbxassetid://132820581372516",
    Theme = "Crimson",
    ModernLayout = true, 
    BottomDragBarEnabled = true, 
    TransparentNav = false, 
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
    Topbar = {
        Height = 48,
        ButtonsType = "Default",
    },
    OpenButton = {
        Title = "STARSHIP ✨",
        Icon = "rbxassetid://85930777472774",
        IconSize = 22, -- Base size (will be overridden by manual fix below)
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

-- === LOADER INTEGRATION ===
getgenv().StarshipWindow = Window
getgenv().StarshipWindUI = WindUI

-- === MANUAL LOGO FIX (FORCED FROM MOBILEUI) ===
-- Karena WindUI Boreal sering mengecilkan logo secara paksa, kita pakai metode 'Forced Override'
task.spawn(function()
    task.wait(1.5) -- Tunggu UI benar-benar render
    pcall(function()
        local openBtn = Window.OpenButtonMain
        if openBtn and openBtn.Button then
            for _, icon in ipairs(openBtn.Button:GetDescendants()) do
                -- Cari ImageLabel dengan ID Starship kita
                if icon:IsA("ImageLabel") and (icon.Image:find("85930777472774") or icon.Image:find("132820581372516")) then
                    icon.AnchorPoint = Vector2.new(0.5, 0.5)
                    icon.Position = UDim2.new(0.5, 5, 0.5, 0) -- Beri sedikit offset kanan agar pas di samping teks
                    icon.Size = UDim2.new(0, 32, 0, 32) -- Paksa ukuran besar (32px)
                    icon.ImageColor3 = Color3.new(1, 1, 1)
                    icon.ImageTransparency = 0
                    
                    if icon.Parent:IsA("Frame") then
                        icon.Parent.Size = UDim2.new(0, 32, 0, 32)
                    end
                end
            end
        end
    end)
end)

-- === PREMIUM OVERLAYS & TAGS ===

-- 1. Watermark
Window:Watermark({
    Text = "STARSHIP PREMIUM┃SAMBUNG KATA",
    Position = "bottom-right",
    Opacity = 0.45,
    Size = 12,
})

-- 2. Performance Tags (FPS & PING)
local FPSTag = Window:Tag({
    Title = "⚡ FPS: --",
    Color = Color3.fromRGB(68, 216, 114),
})

local PingTag = Window:Tag({
    Title = "📶 PING: --ms",
    Color = Color3.fromRGB(75, 155, 255),
})

-- 3. Live Stats Loop
task.spawn(function()
    local RunService = game:GetService("RunService")
    local frameCount = 0
    local lastUpdate = tick()
    
    safeConnect(RunService.Heartbeat, function() frameCount = frameCount + 1 end)
    
    while isRunning and _G.SK_BOT_ID == scriptId do
        task.wait(1)
        local now = tick()
        local elapsed = now - lastUpdate
        local fps = math.floor(frameCount / elapsed)
        local ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        
        pcall(function()
            FPSTag:SetTitle("⚡ FPS: " .. fps)
            PingTag:SetTitle("📶 PING: " .. ping .. "ms")
        end)
        
        frameCount = 0
        lastUpdate = now
    end
end)

-- 4. Logo Scale Fix (Dokumentasi Starship)
pcall(function()
    local bgFrame = Window.Internal.Background
    local img = bgFrame:FindFirstChildOfClass("ImageLabel")
    if img then
        img.ScaleType = Enum.ScaleType.Fit
    end
end)


-- Tombol keyboard untuk Buka/Tutup GUI (ShortCut: CTRL Kiri)
Window:SetToggleKey(Enum.KeyCode.LeftControl)
notify("⌨️ Shortcut", "Tekan 'Left Control' untuk buka/tutup GUI")

local DashboardTab = Window:Tab({ Title = "Dashboard", Icon = "layout-grid" })
local MainTab = Window:Tab({ Title = "Utama", Icon = "house" })
local AutoTab = Window:Tab({ Title = "Otomatis", Icon = "bot" })
local VisualTab = Window:Tab({ Title = "Visual", Icon = "eye" })
local MiscTab = Window:Tab({ Title = "Misc", Icon = "ellipsis" })

-- === DASHBOARD MULTISECTION ===
local DashMulti = DashboardTab:MultiSection({
    Title = "Dashboard Hub",
    Icon = "layout-grid",
    Box = true,
    BoxBorder = true,
    Opened = true
})

local overviewSubTab = DashMulti:Tab({ Title = "Overview", Icon = "info" })
local accountSubTab = DashMulti:Tab({ Title = "Account", Icon = "user" })

-- Build Dashboard content (Overview)
overviewSubTab:Section({ Title = "Main Dashboard" })

overviewSubTab:Paragraph({ 
    Title = "👤 Welcome back, " .. (LocalPlayer.DisplayName or LocalPlayer.Name) .. "!",
    Content = "Starship Premium is fully active. All security protocols bypassed."
})

local roleDesc = "✨ PREMIUM EDITION"
overviewSubTab:Paragraph({
    Title = "Account Information",
    Content = "Account: " .. roleDesc .. "\nStatus: 🟢 CONNECTED\nBuild: v2.6.0 [STABLE]"
})

local dashPerfMonitor = overviewSubTab:Paragraph({
    Title = "📊 Live Performance",
    Content = "FPS: Calculating...\nPing: Calculating...\nSession Uptime: 00:00:00"
})

local executor = (identifyexecutor and identifyexecutor()) or "Standard Executor"
local platformName = "Windows"
pcall(function() platformName = UserInputService:GetPlatform().Name end)
overviewSubTab:Paragraph({
    Title = "🛠️ System Details",
    Content = string.format("Executor: %s\nPlatform: %s\nRegion: Global", executor, platformName)
})

local dashStartTime = tick()
task.spawn(function()
    local RunService = game:GetService("RunService")
    while isRunning and _G.SK_BOT_ID == scriptId do
        local waitOk, _ = pcall(function() RunService.RenderStepped:Wait() end)
        if not waitOk then task.wait(0.1) end
        
        local fps = math.floor(1 / (RunService.RenderStepped:Wait() or 0.016))
        local ping = 0
        pcall(function() 
            ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) 
        end)
        
        local uptime = math.floor(tick() - dashStartTime)
        local h, m, s = math.floor(uptime/3600), math.floor((uptime%3600)/60), uptime%60
        local uptimeStr = string.format("FPS: %d | Ping: %d ms\nSession Uptime: %02d:%02d:%02d", fps, ping, h, m, s)
        
        pcall(function()
            if dashPerfMonitor.SetDesc then dashPerfMonitor:SetDesc(uptimeStr)
            elseif dashPerfMonitor.SetContent then dashPerfMonitor:SetContent(uptimeStr)
            elseif dashPerfMonitor.SetDescription then dashPerfMonitor:SetDescription(uptimeStr)
            end
        end)
        task.wait(1)
    end
end)

overviewSubTab:Section({ Title = "Quick Interactions" })

overviewSubTab:Button({
    Title = "📋 Copy Community Discord",
    Desc = "Join our Discord for updates and support",
    Callback = function()
        if setclipboard then
            setclipboard("https://dsc.gg/starshipcore")
            notify("Discord", "Discord link copied to clipboard!")
        end
    end
})

-- === ACCOUNT SUB-TAB (DASHBOARD) ===
do
    local VIPSection = accountSubTab:Section({ Title = "VIP Status", Icon = "star" })
    
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

    local vipPara = VIPSection:Paragraph({
        Title = "Subscription Information",
        Content = GetVIPStatusDesc()
    })

    if vipExpiryTime then
        task.spawn(function()
            while isRunning and _G.SK_BOT_ID == scriptId do
                task.wait(1)
                pcall(function()
                    if vipPara then
                        local desc = GetVIPStatusDesc()
                        if vipPara.SetDesc then vipPara:SetDesc(desc)
                        elseif vipPara.SetContent then vipPara:SetContent(desc)
                        elseif vipPara.SetDescription then vipPara:SetDescription(desc)
                        end
                    end
                end)
                if (vipExpiryTime - os.time()) <= 0 then break end
            end
        end)
    end

    local ProfileSection = accountSubTab:Section({ Title = "User Profile", Icon = "user-round" })
    ProfileSection:Paragraph({
        Title = LocalPlayer.DisplayName,
        Content = 'Username: ' .. LocalPlayer.Name .. '\n' ..
               'User ID: ' .. LocalPlayer.UserId .. '\n' ..
               'Account Age: ' .. LocalPlayer.AccountAge .. ' days'
    })
end

-- Official WindUI Cleanup Hook & Failsafe Watcher
pcall(function()
    -- Method 1: OnDestroy (Official)
    Window:OnDestroy(function()
        cleanupBot(true) -- Pass true to indicate it came from UI destruction
    end)
    
    -- Method 2: Ancestry Watcher (Instant Fallback)
    if Window.Instance then
        safeConnect(Window.Instance.AncestryChanged, function()
            if not Window.Instance or not Window.Instance:IsDescendantOf(game) then
                cleanupBot(true)
            end
        end)
    end
end)


-- Method 3-4 (Disabled Redundant Watchers to prevent early closure)
-- Window keaktifan sekarang hanya dipantau lewat OnDestroy resmi.

-- --- MAIN TAB (PREMIUM MULTISECTION) ---
local MainMulti = MainTab:MultiSection({
    Title = "Bot Configuration",
    Icon = "settings",
    Box = true,
    BoxBorder = true,
    Opened = true
})

local configSubTab = MainMulti:Tab({ Title = "Kontrol", Icon = "mouse-pointer" })
local strategySubTab = MainMulti:Tab({ Title = "Strategi", Icon = "crosshair" })
local systemSubTab = MainMulti:Tab({ Title = "Sistem", Icon = "cpu" })

configSubTab:Section({ Title = "Primary Controls" })
configSubTab:Toggle({
    Title = "Auto Answer",
    Desc = "Otomatis menjawab saat giliran kamu",
    Value = CONFIG.Enabled,
    Callback = function(v) 
        CONFIG.Enabled = v
        CONFIG.AutoSubmit = v 
        refreshUI()
    end
})

configSubTab:Dropdown({
    Title = "Mode Interaksi",
    Desc = "Human: Pause awal/tengah, typo, kelebihan huruf",
    Values = {"Bot", "Human"},
    Value = "Bot",
    Callback = function(v) 
        CONFIG.InteractionMode = v 
        log("🎭 Mode diatur ke: " .. v)
        refreshUI()
    end
})


configSubTab:Toggle({
    Title = "Auto Suggester 💡",
    Desc = "Tampilkan panel saran kata saat giliran kamu (Pilih kata → bot ketik otomatis) pastikan auto answer off",
    Value = CONFIG.AutoSuggest,
    Callback = function(v) 
        CONFIG.AutoSuggest = v 
        if v then
            notify("💡 Suggester ON", "Panel saran kata akan muncul saat giliranmu!")
        else
            notify("💡 Suggester OFF", "Panel saran kata dimatikan")
        end
        -- Show/hide panel
        pcall(function()
            if suggestScreenGui then
                suggestScreenGui.Enabled = v and isMyTurn and currentLetter ~= ""
                if v and isMyTurn then task.spawn(updateSuggestions) end
            end
        end)
    end
})

configSubTab:Section({ Title = "Voting & Match Mode" })
configSubTab:Toggle({
    Title = "Auto Vote",
    Desc = "Hanya saat server kirim GameModeVote (tanpa scan UI — anti false positive)",
    Value = CONFIG.AutoVote,
    Callback = function(v) CONFIG.AutoVote = v end
})

configSubTab:Dropdown({
    Title = "Target Vote",
    Desc = "Mode yang akan otomatis dipilih bot",
    Values = {"Santai", "Normal", "Brutal"},
    Value = CONFIG.VoteTarget,
    Callback = function(v) CONFIG.VoteTarget = v end
})


configSubTab:Dropdown({
    Title = "Kecepatan",
    Desc = "Kecepatan bot menjawab",
    Multi = false,
    Values = {"Slow", "Normal", "Fast", "Instant"},
    Value = "Normal",
    Callback = function(v)
        if v == "Slow" then 
            CONFIG.MinDelay=5.0; CONFIG.MaxDelay=8.0; CONFIG.TypeCharDelay=0.8; CONFIG.SimulateTyping=true
        elseif v == "Normal" then 
            CONFIG.MinDelay=2.5; CONFIG.MaxDelay=4.0; CONFIG.TypeCharDelay=0.35; CONFIG.SimulateTyping=true
        elseif v == "Fast" then 
            CONFIG.MinDelay=1.0; CONFIG.MaxDelay=2.0; CONFIG.TypeCharDelay=0.15; CONFIG.SimulateTyping=true
        elseif v == "Instant" then 
            CONFIG.MinDelay=0.01; CONFIG.MaxDelay=0.02; CONFIG.TypeCharDelay=0; CONFIG.SimulateTyping=false
        end
        log("🐢 Speed: " .. v .. " | Delay: " .. CONFIG.TypeCharDelay .. "s/char")
        refreshUI()
    end
})

-- 2. Tab Strategi
strategySubTab:Section({ Title = "Word Selection Strategy" })
strategySubTab:Toggle({
    Title = "Killer Mode",
    Desc = "Prioritaskan kata 'curian' server dengan akhiran sulit",
    Value = CONFIG.KillerMode,
    Callback = function(v) CONFIG.KillerMode = v end
})

strategySubTab:Toggle({
    Title = "Fast Collection",
    Desc = "Prioritaskan kata baru agar cepat dapat koin/hadiah",
    Value = CONFIG.FastCollection,
    Callback = function(v) CONFIG.FastCollection = v end
})

strategySubTab:Toggle({
    Title = "Auto Claim Rewards",
    Desc = "Otomatis ambil hadiah koin dari koleksi kata",
    Value = CONFIG.AutoClaim,
    Callback = function(v) CONFIG.AutoClaim = v end
})

strategySubTab:Toggle({
    Title = "Blacklist Collection",
    Desc = "Blokir kata yang sudah ada di koleksimu (Wajib ON untuk koin)",
    Value = CONFIG.IndexBlacklist,
    Callback = function(v) CONFIG.IndexBlacklist = v end
})


-- 3. Tab Sistem
systemSubTab:Section({ Title = "System Management" })
systemSubTab:Button({
    Title = "Stop Bot & Cleanup",
    Desc = "Hapus semua koneksi dan matikan bot sepenuhnya",
    Callback = function() 
        cleanupBot()
        WindUI:Notify({
            Title = "Bot Terminated",
            Content = "Semua koneksi berhasil dibersihkan.",
            Duration = 3
        })
    end
})

UIElements.StatusParagraph = systemSubTab:Paragraph({
    Title = "Current Status",
    Content = "Menunggu data..."
})

systemSubTab:Input({
    Title = "Add Custom Wordlist URL",
    Desc = "Masukkan URL (JSON/TXT) untuk menambah kosakata bot",
    Value = "",
    Placeholder = "https://...",
    Callback = function(v)
        if v:match("^http") then
            if table.find(CONFIG.WordListURLs, v) then
                notify("⚠ URL Exist", "URL ini sudah ada di daftar sumber!")
                return
            end
            table.insert(CONFIG.WordListURLs, v)
            task.spawn(function()
                loadWordListFromURL() -- Reload
                notify("📥 Data Loaded", "Sumber kata baru berhasil ditambahkan!")
            end)
        end
    end
})

-- --- AUTO TAB ---
local AutoMulti = AutoTab:MultiSection({
    Title = "Automation Hub",
    Icon = "bot",
    Box = true,
    BoxBorder = true,
    Opened = true
})

local generalAutoSubTab = AutoMulti:Tab({ Title = "General", Icon = "zap" })

generalAutoSubTab:Section({ Title = "Otomatisasi Meja & AFK" })

generalAutoSubTab:Toggle({
    Title = "Auto Retry",
    Desc = "Coba kata lain jika kata ditolak game",
    Value = CONFIG.AutoRetry,
    Callback = function(v) CONFIG.AutoRetry = v; refreshUI() end
})

generalAutoSubTab:Button({
    Title = "🔥 PAKSA JAWAB (MANUAL)",
    Desc = "Klik jika bot diam saja padahal sudah giliranmu",
    Callback = function()
        if currentLetter == "" or currentLetter == "-" then
            notify("⚠️ Error", "Huruf belum terdeteksi (Cek layar!)")
            return
        end
        log("🚀 [Manual] Memaksa bot untuk menjawab huruf: " .. currentLetter:upper())
        task.spawn(onMyTurn, true)
    end
})

generalAutoSubTab:Toggle({
    Title = "Auto Join Table",
    Desc = "Otomatis cari & masuk meja setelah match",
    Value = CONFIG.AutoJoinTable,
    Callback = function(v) 
        CONFIG.AutoJoinTable = v 
        if v then autoJoinTable() end
        refreshUI()
    end
})



-- ╔════════════════════════════════════════════════════════════╗
-- ║     CUSTOM SCREENGUI - AUTO SUGGESTER PANEL               ║
-- ╚════════════════════════════════════════════════════════════╝

local TweenService = game:GetService("TweenService")
suggestScreenGui = Instance.new("ScreenGui")
suggestScreenGui.Name = "SK_AutoSuggester"
suggestScreenGui.ResetOnSpawn = false
suggestScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
suggestScreenGui.DisplayOrder = 999
suggestScreenGui.Enabled = false
suggestScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Main Container (Draggable)
local suggestMainFrame = Instance.new("Frame")
suggestMainFrame.Name = "MainFrame"
suggestMainFrame.Size = UDim2.new(0, 220, 0, 350)
suggestMainFrame.Position = UDim2.new(1, -240, 0.5, -175)
suggestMainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
suggestMainFrame.BackgroundTransparency = 0.08
suggestMainFrame.BorderSizePixel = 0
suggestMainFrame.Active = true
suggestMainFrame.Draggable = true
suggestMainFrame.Parent = suggestScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = suggestMainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(220, 38, 38)
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.3
mainStroke.Parent = suggestMainFrame

-- Glow Effect
local glowGradient = Instance.new("UIGradient")
glowGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 38, 38)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 100)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 38, 38)),
})
glowGradient.Parent = mainStroke

-- Header
local headerFrame = Instance.new("Frame")
headerFrame.Name = "Header"
headerFrame.Size = UDim2.new(1, 0, 0, 48)
headerFrame.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
headerFrame.BackgroundTransparency = 0.15
headerFrame.BorderSizePixel = 0
headerFrame.Parent = suggestMainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = headerFrame

-- Fix bottom corners of header
local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 12)
headerFix.Position = UDim2.new(0, 0, 1, -12)
headerFix.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
headerFix.BackgroundTransparency = 0.15
headerFix.BorderSizePixel = 0
headerFix.Parent = headerFrame

local headerTitle = Instance.new("TextLabel")
headerTitle.Name = "Title"
headerTitle.Size = UDim2.new(1, -10, 0, 24)
headerTitle.Position = UDim2.new(0, 10, 0, 4)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "💡 AUTO SUGGESTER"
headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextSize = 14
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Parent = headerFrame

local headerStatus = Instance.new("TextLabel")
headerStatus.Name = "Status"
headerStatus.Size = UDim2.new(1, -10, 0, 16)
headerStatus.Position = UDim2.new(0, 10, 0, 28)
headerStatus.BackgroundTransparency = 1
headerStatus.Text = "⏳ Menunggu..."
headerStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
headerStatus.Font = Enum.Font.Gotham
headerStatus.TextSize = 11
headerStatus.TextXAlignment = Enum.TextXAlignment.Left
headerStatus.Parent = headerFrame

-- Letter Badge
local letterBadge = Instance.new("TextLabel")
letterBadge.Name = "LetterBadge"
letterBadge.Size = UDim2.new(0, 40, 0, 40)
letterBadge.Position = UDim2.new(1, -48, 0, 4)
letterBadge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
letterBadge.BackgroundTransparency = 0.85
letterBadge.Text = "-"
letterBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
letterBadge.Font = Enum.Font.GothamBlack
letterBadge.TextSize = 20
letterBadge.Parent = headerFrame

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 8)
badgeCorner.Parent = letterBadge

-- Scrolling Word List
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "WordList"
scrollFrame.Size = UDim2.new(1, -12, 1, -58)
scrollFrame.Position = UDim2.new(0, 6, 0, 52)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(220, 38, 38)
scrollFrame.BorderSizePixel = 0
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = suggestMainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = scrollFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 4)
listPadding.PaddingBottom = UDim.new(0, 4)
listPadding.Parent = scrollFrame

-- === FUNGSI MEMBUAT TOMBOL KATA ===
local function createWordButton(word, index)
    local isCommon = COMMON_WORDS[word] and true or false
    local isServerWord = SERVER_KNOWN_WORDS[word:sub(1,1)] and table.find(SERVER_KNOWN_WORDS[word:sub(1,1)], word) and true or false
    local isCloudWord = WORDS_SOURCE_DB[word] and true or false
    
    local btn = Instance.new("TextButton")
    btn.Name = "Word_" .. index
    btn.Size = UDim2.new(1, -4, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    btn.BackgroundTransparency = 0.15
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.LayoutOrder = index
    btn.Text = ""
    btn.Parent = scrollFrame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn
    
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(60, 60, 80)
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.5
    btnStroke.Parent = btn
    
    -- Word Label
    local wordLabel = Instance.new("TextLabel")
    wordLabel.Name = "WordText"
    wordLabel.Size = UDim2.new(0.7, -8, 1, 0)
    wordLabel.Position = UDim2.new(0, 8, 0, 0)
    wordLabel.BackgroundTransparency = 1
    wordLabel.Text = word:upper()
    wordLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    wordLabel.Font = Enum.Font.GothamBold
    wordLabel.TextSize = 13
    wordLabel.TextXAlignment = Enum.TextXAlignment.Left
    wordLabel.Parent = btn
    
    -- Info badges
    local badges = ""
    if isCommon then badges = badges .. "⭐" end
    if isServerWord then badges = badges .. "🌐" end
    if isCloudWord then badges = badges .. "☁️" else badges = badges .. "💾" end
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "Info"
    infoLabel.Size = UDim2.new(0.3, -4, 1, 0)
    infoLabel.Position = UDim2.new(0.7, 0, 0, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = #word .. "h " .. badges
    infoLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 10
    infoLabel.TextXAlignment = Enum.TextXAlignment.Right
    infoLabel.Parent = btn
    
    -- Hover Effects
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(220, 38, 38),
            BackgroundTransparency = 0.25
        }):Play()
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {
            Color = Color3.fromRGB(255, 100, 100),
            Transparency = 0
        }):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(30, 30, 40),
            BackgroundTransparency = 0.15
        }):Play()
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {
            Color = Color3.fromRGB(60, 60, 80),
            Transparency = 0.5
        }):Play()
    end)
    
    -- CLICK HANDLER (Ini yang penting!)
    btn.MouseButton1Click:Connect(function()
        if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
        if not isMyTurn or not matchActive then
            notify("⚠️ Bukan Giliran", "Tunggu giliranmu dulu!")
            return
        end
        
        -- Visual feedback: flash hijau
        TweenService:Create(btn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(0, 200, 80)
        }):Play()
        
        log("💡 [Suggester] Dipilih: " .. word:upper())
        notify("✅ Mengirim", word:upper())
        
        -- Mark as used
        lastAnswer = word
        if CONFIG.AvoidRepeat then usedWords[word] = true end
        
        -- Kirim kata
        task.spawn(function()
            submitWordViaRemote(currentLetter, word)
        end)
        
        -- Refresh suggestions after sending
        task.delay(1.5, function()
            if isMyTurn then updateSuggestions() end
        end)
    end)
    
    return btn
end

-- === FUNGSI UPDATE SUGGESTIONS (CUSTOM GUI VERSION) ===
function updateSuggestions()
    pcall(function()
        -- Jika fitur mati, sembunyikan panel
        if not CONFIG.AutoSuggest then
            suggestScreenGui.Enabled = false
            return
        end
        
        -- Jika bukan giliran, sembunyikan panel dan clear
        if not isMyTurn or currentLetter == "" or currentLetter == "-" then
            suggestScreenGui.Enabled = false
            -- Clear existing buttons
            for _, child in ipairs(scrollFrame:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            headerStatus.Text = "⏳ Menunggu giliran..."
            letterBadge.Text = "-"
            return
        end
        
        -- Tampilkan panel
        suggestScreenGui.Enabled = true
        
        local prefix = currentLetter:lower()
        local words = findAllWords(prefix, CONFIG.AutoSuggestMax)
        
        -- Update header
        letterBadge.Text = prefix:upper()
        headerStatus.Text = "📊 " .. #words .. " kata | Klik untuk kirim!"
        
        -- Clear daftar lama
        for _, child in ipairs(scrollFrame:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        -- Buat tombol baru untuk setiap kata
        for i, word in ipairs(words) do
            createWordButton(word, i)
            -- Yield setiap 20 tombol agar tidak lag
            if i % 20 == 0 then task.wait() end
        end
        
        -- Animasi muncul
        suggestMainFrame.Position = UDim2.new(1, -10, 0.5, -175)
        suggestMainFrame.BackgroundTransparency = 1
        TweenService:Create(suggestMainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
            Position = UDim2.new(1, -240, 0.5, -175),
            BackgroundTransparency = 0.08
        }):Play()
    end)
end

-- Cleanup: tambahkan ke connections agar dibersihkan saat bot mati
table.insert(connections, {Disconnect = function()
    pcall(function()
        if suggestScreenGui then suggestScreenGui:Destroy() end
    end)
end})



-- === MISC FUNCTIONS ===
local function rejoinServer()
    pcall(function()
        notify("🔄 Rejoin", "Sedang masuk kembali ke server...")
        task.wait(0.5)
        local TPS = game:GetService("TeleportService")
        TPS:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local function serverHop()
    pcall(function()
        notify("🌐 Server Hop", "Mencari server lain...")
        task.wait(0.5)
        local TPS = game:GetService("TeleportService")
        local HttpService = game:GetService("HttpService")
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local ok, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        if ok and result and result.data then
            for _, server in ipairs(result.data) do
                if server.playing and server.playing < server.maxPlayers and server.id ~= game.JobId then
                    TPS:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                    return
                end
            end
        end
        notify("⚠️ Server Hop", "Tidak ada server lain yang tersedia, rejoin...")
        TPS:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local function respawnPlayer()
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.Health = 0
                notify("💀 Respawn", "Karakter di-respawn.")
            end
        end
    end)
end

-- === ADMIN DETECTION ===
local GAME_CREATOR_ID = nil
pcall(function()
    if game.CreatorType == Enum.CreatorType.User then
        GAME_CREATOR_ID = game.CreatorId
    elseif game.CreatorType == Enum.CreatorType.Group then
        local groupInfo = game:GetService("GroupService"):GetGroupInfoAsync(game.CreatorId)
        if groupInfo and groupInfo.Owner then
            GAME_CREATOR_ID = groupInfo.Owner.Id
        end
    end
end)

local function isAdmin(player)
    if not player then return false end
    if GAME_CREATOR_ID and player.UserId == GAME_CREATOR_ID then return true end
    local adminIds = {1} -- Roblox default
    for _, id in ipairs(adminIds) do
        if player.UserId == id then return true end
    end
    return false
end

local function checkAdminPresence(player)
    if not CONFIG.DetectAdmin then return end
    if isAdmin(player) then
        log("🚨 [ADMIN] Admin/Creator terdeteksi: " .. player.Name .. " (ID: " .. player.UserId .. ")")
        notify("🚨 ADMIN DETECTED!", player.Name .. " (Creator/Admin) bergabung ke server!", 10)
        if CONFIG.AutoLeaveAdmin then
            log("🏃 [ADMIN] Auto Leave — pindah server...")
            notify("🏃 Auto Leave", "Admin terdeteksi, pindah server dalam 3 detik...")
            task.wait(3)
            serverHop()
        end
    end
end

game:GetService("Players").PlayerAdded:Connect(function(player)
    checkAdminPresence(player)
end)

for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
    if player ~= LocalPlayer then
        checkAdminPresence(player)
    end
end

-- --- VISUAL TAB ---
VisualTab:Section({ Title = "Streaming Mode (Visual Spoofing)" })

VisualTab:Toggle({
    Title = "Streaming Mode",
    Desc = "Aktifkan spoofing nama & data (Visual Saja)",
    Value = CONFIG.StreamingMode,
    Callback = function(v) 
        CONFIG.StreamingMode = v 
        if v then
            notify("🎥 Streaming HUD", "Mode streaming diaktifkan.")
        end
    end
})

VisualTab:Input({
    Title = "Spoof Name",
    Desc = "Ganti nama player yang muncul di UI game",
    Value = CONFIG.SpoofName,
    Placeholder = "Ketik nama palsu...",
    Callback = function(v) CONFIG.SpoofName = v end
})

-- --- TROLL TAB ---

-- --- MISC TAB ---
MiscTab:Section({ Title = "Server Management" })

MiscTab:Button({
    Title = "Rejoin Server",
    Desc = "Segarkan koneksi dengan masuk kembali ke server ini",
    Callback = rejoinServer
})

MiscTab:Button({
    Title = "Server Hop (Pindah Server)",
    Desc = "Cari server publik lain dan pindah otomatis",
    Callback = serverHop
})

MiscTab:Section({ Title = "Character Utilities" })

MiscTab:Button({
    Title = "Respawn Char",
    Desc = "Reset karakter kamu jika stuck",
    Callback = respawnPlayer
})

MiscTab:Section({ Title = "Security & Admin (Anti-Banned)" })

MiscTab:Toggle({
    Title = "Detect Admin",
    Desc = "Beritahu jika ada admin/pencipta game masuk server",
    Value = CONFIG.DetectAdmin,
    Callback = function(v) CONFIG.DetectAdmin = v end
})

MiscTab:Toggle({
    Title = "Auto Leave Admin",
    Desc = "Otomatis pindah server jika admin terdeteksi",
    Value = CONFIG.AutoLeaveAdmin,
    Callback = function(v) CONFIG.AutoLeaveAdmin = v end
})

DashboardTab:Select()


-- === UI REFRESHER ===
function refreshUI()
    -- Wrap each part in its own pcall to prevent one failure from stopping all updates
    pcall(function()
        if UIElements.StatusParagraph then
            local turn = isMyTurn and "🟢 GILIRAN KAMU" or "⏳ Menunggu"
            local timerText = matchTimer > 0 and string.format("\n⏱️ Waktu: %ds", matchTimer) or ""
            local statusText = string.format(
                "Database: %s\nIndex Hunter: %s / %s (%s Baru)%s\nStatus: %s\nGiliran: %s\nHuruf: %s → %s",
                tostring(loadingStatus or "Memuat..."),
                tostring(currentIndexCount or 0),
                tostring(totalIndexPossible or 0),
                tostring(sessionNewWordsDiscovered or 0),
                timerText,
                matchActive and "🎮 Match Aktif" or "💤 Idle",
                turn,
                (currentLetter ~= "" and tostring(currentLetter):upper() or "-"),
                (lastAnswer ~= "" and tostring(lastAnswer) or "-")
            )
            -- Multi-method support for WindUI Paragraphs
            local p = UIElements.StatusParagraph
            if p.SetDesc then p:SetDesc(statusText)
            elseif p.SetContent then p:SetContent(statusText)
            elseif p.SetDescription then p:SetDescription(statusText)
            end
        end
    end)
end

-- (UI Refresh is now handled by the main loop at the bottom)

local lastTrackedTable = nil -- State locker untuk tracker meja
local lastScrapedLetter = ""
local function scanGameState()
    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
    local success, err = pcall(function()
        local pGui = LocalPlayer:WaitForChild("PlayerGui")
        
        -- 1. Tracker Meja & Pemain
        local currentTable = LocalPlayer:GetAttribute("CurrentTable") or LocalPlayer:GetAttribute("TableID") or LocalPlayer:GetAttribute("Sitting")
        local hasTable = (currentTable ~= nil and currentTable ~= "")
        local hasRemoteConfirmation = (_G.__SK_MATCH_CONFIRMED or false)
        matchActive = hasTable or hasRemoteConfirmation
        
        -- 2. MASTER TURN DETECTION (3-Tier Logic)
        local isActuallyMyTurn = false
        
        -- Tier A: Attribute Watcher (Stealth Turn Detection)
        local attrTurn = LocalPlayer:GetAttribute("MyTurn") or LocalPlayer:GetAttribute("Turn") or LocalPlayer:GetAttribute("IsPlaying") or LocalPlayer:GetAttribute("IsTurn")
        if attrTurn == true then
            isActuallyMyTurn = true
        end

        -- Tier B: UI Component Watcher (Visual Detection)
        -- SKIP jika remote sudah pernah memberi sinyal (true/false) — percaya remote
        if not isActuallyMyTurn and _G.__SK_REMOTE_TURN == nil then
            for _, v in ipairs(pGui:GetDescendants()) do
                if v:IsA("TextBox") and v.Visible and v.Name ~= "WindUI_Input" then
                    local isBotUI = false
                    pcall(function()
                        local anc = v.Parent
                        local depth = 0
                        while anc and anc ~= pGui and depth < 8 do
                            local n = anc.Name
                            if n == "SK_Overlay" or n:find("WindUI") or n:find("wind_ui") or n:find("Starship") then
                                isBotUI = true
                                break
                            end
                            anc = anc.Parent
                            depth = depth + 1
                        end
                    end)
                    if not isBotUI then
                        isActuallyMyTurn = true
                        break
                    end
                end
            end
        end
        
        -- 3. DYNAMIC LETTER SCRAPER (IMPROVED v2 - Anti False Positive)
        -- Prioritas: remoteLetter > "Hurufnya adalah" > Kontext-Aware Scrape
        
        -- === LETTER DETECTION: Watcher + Remote (NO full UI scan) ===
        local foundLetter = ""
        
        -- Source 1: Remote event letter (paling akurat)
        local remoteLetter = _G.__SK_REMOTE_LETTER or ""
        if remoteLetter ~= "" then
            foundLetter = remoteLetter:lower()
        end
        
        -- Source 2: WordServerFrame watcher — cari letter badge di ScreenGui yang sama
        if not _G.__SK_WSF_WATCHER then
            pcall(function()
                for _, sg in ipairs(pGui:GetChildren()) do
                    if sg:IsA("ScreenGui") then
                        local wsf = nil
                        for _, desc in ipairs(sg:GetDescendants()) do
                            if desc.Name == "WordServerFrame" then wsf = desc; break end
                        end
                        if wsf then
                            -- Cari ScreenGui parent yang memuat WordServerFrame
                            local gameGui = sg
                            local watchConns = {}
                            
                            local function extractLetterFromGameGui()
                                local letter = findLetterViaAnchor(gameGui)
                                if letter then return letter, 99 end
                                local broad, fs = findLetterBroadScan(gameGui, false)
                                return broad, fs or 0
                            end
                            
                            -- Pasang watcher di SEMUA TextLabel/TextButton di gameGui
                            -- (karena letter badge bisa di mana saja dalam ScreenGui)
                            local function onTextChanged()
                                pcall(function()
                                    local letter, fs = extractLetterFromGameGui()
                                    if letter and letter ~= (currentLetter or "") then
                                        currentLetter = letter
                                        _G.__SK_REMOTE_LETTER = letter
                                        log("📡 [Watcher] Huruf: " .. letter:upper() .. " (fs=" .. fs .. ")")
                                        if isMyTurn and CONFIG.AutoSubmit then task.spawn(onMyTurn, true) end
                                        if isMyTurn and CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
                                    end
                                end)
                            end
                            
                            for _, el in ipairs(gameGui:GetDescendants()) do
                                if el:IsA("TextLabel") or el:IsA("TextButton") then
                                    local c = el:GetPropertyChangedSignal("Text"):Connect(onTextChanged)
                                    table.insert(watchConns, c)
                                end
                            end
                            
                            -- Juga watch elemen baru yang muncul nanti
                            local addConn = gameGui.DescendantAdded:Connect(function(desc)
                                if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                                    local c = desc:GetPropertyChangedSignal("Text"):Connect(onTextChanged)
                                    table.insert(watchConns, c)
                                    task.delay(0.1, onTextChanged)
                                end
                            end)
                            table.insert(watchConns, addConn)
                            
                            _G.__SK_WSF_WATCHER = watchConns
                            log("✅ [Watcher] Terpasang di " .. gameGui.Name .. " (" .. #watchConns .. " koneksi, auto-detect huruf)")
                            
                            -- Baca langsung huruf saat ini
                            local initLetter, initFs = extractLetterFromGameGui()
                            if initLetter then
                                foundLetter = initLetter
                                currentLetter = foundLetter
                                _G.__SK_REMOTE_LETTER = foundLetter
                                log("📡 [Watcher] Huruf awal: " .. foundLetter:upper() .. " (fs=" .. initFs .. ")")
                            end
                            return
                        end
                    end
                end
            end)
        end
        
        -- Source 3: currentLetter sudah di-set oleh watcher/remote
        if foundLetter == "" and currentLetter ~= "" and currentLetter ~= "-" then
            foundLetter = currentLetter
        end

        -- 4. STATE SYNC & TRIGGER (hanya saat match aktif)
        if foundLetter ~= "" and foundLetter ~= currentLetter and matchActive then
            currentLetter = foundLetter 
            if isMyTurn and CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
        end

        -- HARD BLOCK: Remote punya otoritas tertinggi untuk turn detection
        if _G.__SK_REMOTE_TURN == false then
            if isMyTurn then
                isMyTurn = false
                _G.SK_ANSWER_LOCK = false
            end
        elseif _G.__SK_REMOTE_TURN == true then
            if not isMyTurn then
                isMyTurn = true
                _G.__SK_TURN_TIMESTAMP = tick()
                _G.__SK_AWAITING_LETTER = true
                if foundLetter ~= "" then
                    currentLetter = foundLetter
                    _G.__SK_AWAITING_LETTER = false
                else
                    currentLetter = ""
                    _G.__SK_REMOTE_LETTER = ""
                end
                _G.SK_ANSWER_LOCK = false
                log("🎯 [Turn-Detected] Remote=true, mulai otomatis (letter=" .. tostring(currentLetter):upper() .. ")")
                if CONFIG.AutoSubmit then task.spawn(onMyTurn, true) end
                if CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
            end
        elseif _G.__SK_REMOTE_TURN == nil and isActuallyMyTurn and matchActive then
            if not isMyTurn then
                isMyTurn = true
                _G.__SK_REMOTE_TURN = true
                _G.__SK_TURN_TIMESTAMP = tick()
                _G.__SK_AWAITING_LETTER = true
                if foundLetter ~= "" then
                    currentLetter = foundLetter
                    _G.__SK_AWAITING_LETTER = false
                else
                    currentLetter = ""
                    _G.__SK_REMOTE_LETTER = ""
                end
                _G.SK_ANSWER_LOCK = false
                log("🎯 [Turn-Detected] UI fallback (remote=nil), mulai otomatis (letter=" .. tostring(currentLetter):upper() .. ")")
                if CONFIG.AutoSubmit then task.spawn(onMyTurn, true) end
                if CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
            end
        else
            if isMyTurn and not isActuallyMyTurn then
                isMyTurn = false
                if CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
            end
        end
    end)
end


-- === STREAMING MODE HANDLER (OPTIMIZED WITH CACHE) ===
local nameLabelsCache = {}
local lastScanTime = 0

local function handleStreamingMode()
    if not CONFIG.StreamingMode then 
        if #nameLabelsCache > 0 then table.clear(nameLabelsCache) end
        return 
    end
    
    local now = tick()
    local name = LocalPlayer.Name
    local disp = LocalPlayer.DisplayName

    -- 1. Full Scan Ringan (Hanya setiap 5 detik untuk mencari elemen UI baru)
    if now - lastScanTime > 5 then
        table.clear(nameLabelsCache)
        
        -- Cari di UI
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, v in ipairs(pg:GetDescendants()) do
                if (v:IsA("TextLabel") or v:IsA("TextBox") or v:IsA("TextButton")) then
                    local success, containsName = pcall(function() 
                        return v.Text:find(name) or v.Text:find(disp) 
                    end)
                    if success and containsName then
                        table.insert(nameLabelsCache, v)
                    end
                end
            end
        end
        
        -- Cari di Billboard Karakter
        local char = LocalPlayer.Character
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("TextLabel") then
                    local success, containsName = pcall(function() 
                        return v.Text:find(name) or v.Text:find(disp) 
                    end)
                    if success and containsName then
                        table.insert(nameLabelsCache, v)
                    end
                end
            end
        end
        lastScanTime = now
    end

    -- 2. Update Instan (Hanya untuk elemen yang sudah ditemukan/di-cache)
    for i = #nameLabelsCache, 1, -1 do
        local v = nameLabelsCache[i]
        if v and v.Parent then
            pcall(function()
                local rawText = v.Text
                if rawText:find(name) or rawText:find(disp) then
                    v.Text = rawText:gsub(name, CONFIG.SpoofName):gsub(disp, CONFIG.SpoofName)
                end
            end)
        else
            table.remove(nameLabelsCache, i) -- Hapus dari cache jika UI sudah hilang
        end
    end
end

-- Startup logic moved to the end of script

-- ╔════════════════════════════════════════════════════════════╗
-- ║           EVENT LISTENERS (LATE BINDING)                  ║
-- ╚════════════════════════════════════════════════════════════╝

local isJoiningTable = false -- Flag debounce agar tidak spam join
function autoJoinTable()
    if isJoiningTable or not isRunning or not CONFIG.AutoJoinTable or matchActive or LocalPlayer:GetAttribute("CurrentTable") then return end
    
    local tables = workspace:FindFirstChild("Tables")
    if not tables then return end
    
    isJoiningTable = true 
    task.wait(CONFIG.AutoJoinDelay)
    
    if not isRunning or _G.SK_BOT_ID ~= scriptId or matchActive or LocalPlayer:GetAttribute("CurrentTable") then 
        isJoiningTable = false
        return 
    end
    
    local joinableTables = {}
    
    local function getPlayerCount(tbl)
        local count = 0
        pcall(function()
            for _, obj in ipairs(tbl:GetDescendants()) do
                if (obj:IsA("Seat") or obj:IsA("VehicleSeat")) and obj.Occupant then
                    count = count + 1
                end
            end
            if count == 0 then
                for _, p in ipairs(game.Players:GetPlayers()) do
                    if p:GetAttribute("CurrentTable") == tbl.Name then
                        count = count + 1
                    end
                end
            end
        end)
        return count
    end

    for _, tbl in ipairs(tables:GetChildren()) do
        if tbl:IsA("Model") and tbl:IsDescendantOf(workspace) then
            local state = tbl:GetAttribute("TableState")
            local isHidden = tableHiddenStatus[tbl.Name]
            
            if (not state or state == "" or state == "Waiting") and not isHidden then
                local pCount = getPlayerCount(tbl)
                if pCount < 6 then
                    table.insert(joinableTables, {Instance = tbl, Players = pCount})
                end
            end
        end
    end
    
    if #joinableTables == 0 then 
        isJoiningTable = false
        return 
    end
    
    table.sort(joinableTables, function(a, b) return a.Players > b.Players end)
    
    local targetTable = joinableTables[1].Instance
    
    if targetTable and targetTable:IsDescendantOf(workspace) then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if root then
            local tcf = targetTable:GetModelCFrame()
            root.CFrame = CFrame.new(tcf.p + Vector3.new(0, 3, 0))
            task.wait(0.2)
        end

        pcall(function() JoinTable:FireServer(targetTable.Name) end)
        STATS.tablesJoined = (STATS.tablesJoined or 0) + 1
        log("🚀 Auto Join: Bergabung ke " .. targetTable.Name)
        notify("🪑 Auto Join", "Bergabung ke " .. targetTable.Name)
        
        task.wait(5)
    end
    
    isJoiningTable = false
end

-- === BILLBOARD UPDATE LISTENER (Monitor only — ini untuk update teks billboard pemain, BUKAN huruf game) ===
if BillboardUpdate then
    safeConnect(BillboardUpdate.OnClientEvent, function(value, extra)
        if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
        if CONFIG.DebugMode then
            log("📨 [BillboardUpdate] value=" .. tostring(value) .. " (" .. type(value) .. ") extra=" .. tostring(extra or "nil") .. " (" .. type(extra or "nil") .. ")")
        end
    end)
end

-- === NEW REMOTE LISTENERS (V8 UPDATE) ===

if GameModeVote then
    safeConnect(GameModeVote.OnClientEvent, function(modes)
        if _G.SK_BOT_ID ~= scriptId or not CONFIG.AutoVote then return end
        
        task.wait(math.random(20, 45) * 0.1)
        
        local targetMode = CONFIG.VoteTarget or "Normal"
        local fixedMode = targetMode:sub(1,1):upper() .. targetMode:sub(2):lower()
        log("🗳️ [Auto-Vote] Server buka vote — memilih: " .. fixedMode .. " | payload=" .. tostring(typeof(modes)))

        pcall(function()
            GameModeVote:FireServer(fixedMode)
        end)
    end)
end

if MatchTimerUpdate then
    safeConnect(MatchTimerUpdate.OnClientEvent, function(timeLeft)
        matchTimer = tonumber(timeLeft) or 0
        if matchTimer % 5 == 0 or matchTimer < 5 then
            refreshUI()
        end
    end)
end

if MatchStatusUpdate then
    safeConnect(MatchStatusUpdate.OnClientEvent, function(status)
        local rawStatus = tostring(status or "")
        log("📢 Status Match: " .. rawStatus)
        
        -- Deteksi Mode dari Status
        if rawStatus:find("Brutal") then
            _G.SK_CURRENT_MODE = "Brutal"
        elseif rawStatus:find("Normal") then
            _G.SK_CURRENT_MODE = "Normal"
        elseif rawStatus:find("Santai") then
            _G.SK_CURRENT_MODE = "Santai"
        end
    end)
end

if PlayerCorrect then
    safeConnect(PlayerCorrect.OnClientEvent, function(player)
        -- [COBALT VERIFIED] Format: PlayerCorrect hanya kirim player, TANPA kata
        if player then
            local name = "?"
            pcall(function() name = player.DisplayName or player.Name end)
            
            if player == LocalPlayer then
                log("✅ Jawaban BENAR! (" .. name .. ")")
                STATS.wordsCorrect = STATS.wordsCorrect + 1
            else
                log("🎯 " .. name .. " menjawab benar")
            end
        end
    end)
end

if UsedWordWarn then
    local retryConn = safeConnect(UsedWordWarn.OnClientEvent, function(rejectedWord)
        if _G.SK_BOT_ID ~= scriptId then 
            if retryConn then retryConn:Disconnect() end
            return 
        end
        local w = tostring(rejectedWord or "")
        local wLower = w:lower()
        if wLower == "init" or wLower == "turnstart" or wLower == "startturn" 
            or wLower == "endturn" or wLower == "updatetimer" or wLower == "mistake"
            or type(rejectedWord) == "boolean" or type(rejectedWord) == "table" then
            return
        end
        task.spawn(triggerRetry, rejectedWord)
    end)
end

if IndexRewardStatus then
    local rewardConn = safeConnect(IndexRewardStatus.OnClientEvent, function(data)
        if _G.SK_BOT_ID ~= scriptId then 
            if rewardConn then rewardConn:Disconnect() end
            return 
        end

        if type(data) == "table" then
            _G.SK_LAST_REWARD_DATA = data -- Simpan data secara global untuk UI

        
        if CONFIG.AutoClaim then
            local currentAvailable = 0
            
            for id, status in pairs(data) do
                if status == "AVAILABLE" then
                    currentAvailable = currentAvailable + 1
                    
                    -- Logika Ambil Hadiah
                    log("💰 Hadiah " .. id .. " tersedia! Mengambil secara otomatis...")
                    ClaimIndexReward:FireServer(id)
                    sessionClaimedRewards[id] = true -- Catat riwayat
                    task.wait(0.3) -- Jeda anti-spam
                end
            end
            
            -- Deteksi jika ada reward baru yang terbuka
            if currentAvailable > lastRewardCount then
                local diff = currentAvailable - lastRewardCount
                sessionNewWordsDiscovered = sessionNewWordsDiscovered + (diff or 0)
                notify("🎊 Reward Terbuka!", "Bot berhasil menemukan " .. diff .. " index baru!")
            end
            lastRewardCount = currentAvailable
        end
    end
end)
end

local matchConn = safeConnect(MatchUI.OnClientEvent, function(eventName, value, extra)
    -- CLEANUP: Jika saya bukan script terbaru, putus koneksi saya!
    if _G.SK_BOT_ID ~= scriptId then 
        if matchConn then matchConn:Disconnect() end
        return 
    end
    
    -- SELALU log semua event (penting untuk debugging letter source)
    log("📨 [MatchUI] " .. tostring(eventName) .. " | v=" .. tostring(value) .. "(" .. type(value) .. ") e=" .. tostring(extra or "-") .. "(" .. type(extra or "nil") .. ")")
    
    -- GREEDY TOKEN CATCH: Tangkap ID rahasia dari value ATAU extra (cek keduanya)
    for _, possibleParam in ipairs({extra, value}) do
        local possibleToken = tostring(possibleParam or "")
        if #possibleToken > 10 and not possibleToken:find("[a-zA-Z]") and possibleToken:find("%d") then
            _G.SK_SECRET_ID = possibleToken
            log("🔑 [Security] Secret ID Captured: " .. possibleToken:sub(1,12) .. "...")
            break
        end
    end
    
    -- UNIVERSAL LETTER SNIFFER: HANYA string, BUKAN number (number = timer/score)
    local function tryExtractLetter(val)
        if type(val) == "string" then
            local clean = val:lower():gsub("%s+", "")
            if #clean >= 1 and #clean <= 3 and clean:match("^%a+$") then
                return clean
            end
        elseif type(val) == "table" then
            for _, key in ipairs({"letter", "Letter", "prefix", "Prefix", "huruf", "Huruf", "char", "Char"}) do
                if val[key] and type(val[key]) == "string" then
                    local clean = val[key]:lower():gsub("%s+", "")
                    if #clean >= 1 and #clean <= 3 and clean:match("^%a+$") then
                        return clean
                    end
                end
            end
            if val[1] and type(val[1]) == "string" then
                local clean = val[1]:lower():gsub("%s+", "")
                if #clean >= 1 and #clean <= 3 and clean:match("^%a+$") then
                    return clean
                end
            end
        end
        return nil
    end
    
    -- Exclude noise events dari letter sniffer
    local enLower = tostring(eventName or ""):lower()
    local isMatchUINoiseEvent = enLower:find("timer") or eventName == "ShowMatchUI" or eventName == "HideMatchUI" 
        or eventName == "EndTurn" or eventName == "Mistake" or eventName == "Init"
        or enLower:find("camera") or enLower:find("sound") or enLower:find("hit") or enLower:find("correct")
    
    -- Sniffer hanya aktif saat giliran kita (hindari huruf stale dari giliran lain)
    if not isMatchUINoiseEvent and isMyTurn and _G.__SK_REMOTE_TURN == true then
        local sniffedLetter = tryExtractLetter(extra) or tryExtractLetter(value)
        if sniffedLetter then
            local firstChar = sniffedLetter:sub(1,1)
            if KATA_DB[firstChar] or KATA_DB[sniffedLetter] then
                if sniffedLetter ~= (_G.__SK_REMOTE_LETTER or "") then
                    _G.__SK_REMOTE_LETTER = sniffedLetter
                    currentLetter = sniffedLetter
                    log("📡 [Sniffer] Letter from '" .. tostring(eventName) .. "': " .. sniffedLetter:upper())
                end
            end
        end
    end

    -- Normalize event names (game uses different names than expected)
    local eventAliases = {
        Init = "ShowMatchUI", Initialize = "ShowMatchUI",
        TurnStart = "StartTurn", MyTurn = "StartTurn", BeginTurn = "StartTurn",
        TurnEnd = "EndTurn", StopTurn = "EndTurn",
        LetterUpdate = "UpdateServerLetter", SetLetter = "UpdateServerLetter", UpdateLetter = "UpdateServerLetter",
        Lose = "Eliminated", Lost = "Eliminated", Dead = "Eliminated",
        Win = "Victory", Won = "Victory",
        HideUI = "HideMatchUI", End = "HideMatchUI", MatchEnd = "HideMatchUI",
    }
    local normalizedEvent = eventAliases[eventName] or eventName
    
    if eventName == "ShowMatchUI" or normalizedEvent == "ShowMatchUI" then
        -- SELALU reset state saat Init/ShowMatchUI (match baru)
        isMyTurn = false
        currentLetter = ""
        _G.__SK_REMOTE_LETTER = ""
        _G.__SK_REMOTE_TURN = false
        _G.__SK_TURN_TIMESTAMP = 0
        _G.__SK_AWAITING_LETTER = false
        _G.SK_ANSWER_LOCK = false
        
        if value == false then
            log("📋 [Remote] " .. eventName .. " v=false — state reset (spectating)")
        else
            matchActive = true
            _G.__SK_MATCH_CONFIRMED = true
            matchRoundCount = 0 
            gameUsedWords = {}
            playerMistakes = {}
            STATS.matchesPlayed = STATS.matchesPlayed + 1
            _G.SK_LAST_LETTER = ""
            _G.__SK_REMOTE_LETTER = ""
            log("🎮 [Remote] Match Started (" .. eventName .. ")")
        end
    elseif eventName == "HideMatchUI" or normalizedEvent == "HideMatchUI" 
        or eventName == "Eliminated" or normalizedEvent == "Eliminated"
        or eventName == "Victory" or normalizedEvent == "Victory" 
        or eventName == "Winner" then
        matchActive, isMyTurn, currentLetter = false, false, ""
        _G.__SK_MATCH_CONFIRMED = false
        _G.__SK_REMOTE_TURN = false
        matchRoundCount = 1
        playerMistakes = {}
        _G.SK_ANSWER_LOCK = false
        _G.SK_LAST_LETTER = ""
        _G.__SK_REMOTE_LETTER = ""
        if eventName == "Eliminated" or normalizedEvent == "Eliminated" then STATS.currentStreak = 0 end
        if eventName == "Victory" or normalizedEvent == "Victory" or eventName == "Winner" then STATS.matchesWon = STATS.matchesWon + 1 end
        if CONFIG.AutoJoinTable then task.delay(CONFIG.AutoJoinDelay, autoJoinTable) end
        log("🎮 [Remote] Match Ended (" .. eventName .. ")")
    elseif eventName == "UpdateServerLetter" or normalizedEvent == "UpdateServerLetter" then
        -- USL number data BUKAN letter index! Huruf asli hanya dari UI scan.
        -- Hanya terima string huruf jika ada
        local newLetter = ""
        if type(value) == "string" then
            local clean = value:lower():gsub("%s+", "")
            if #clean >= 1 and #clean <= 3 and clean:match("^%a+$") then
                newLetter = clean
            end
        end
        
        if newLetter ~= "" and _G.__SK_AWAITING_LETTER then
            currentLetter = newLetter
            _G.__SK_REMOTE_LETTER = newLetter
            _G.__SK_AWAITING_LETTER = false
            log("📡 [Remote] Server Letter Updated: " .. newLetter:upper())
            if CONFIG.AutoSubmit then task.spawn(onMyTurn, true) end
            if CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
        elseif _G.__SK_AWAITING_LETTER and isMyTurn then
            task.spawn(function()
                task.wait(0.3)
                if not _G.__SK_AWAITING_LETTER or not isMyTurn then return end
                if currentLetter ~= "" and currentLetter ~= "-" then return end
                pcall(function()
                    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                    if not pGui then return end
                    for _, sg in ipairs(pGui:GetChildren()) do
                        if sg:IsA("ScreenGui") and sg.Enabled then
                            local letter = findLetterViaAnchor(sg)
                            if not letter then letter = findLetterBroadScan(sg, false) end
                            if letter then
                                currentLetter = letter
                                _G.__SK_REMOTE_LETTER = letter
                                _G.__SK_AWAITING_LETTER = false
                                log("📡 [MatchUI-Letter] Huruf: " .. letter:upper() .. " (dari UI anchor)")
                                if CONFIG.AutoSubmit then task.spawn(onMyTurn, true) end
                                if CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
                                return
                            end
                        end
                    end
                end)
            end)
        end
    elseif eventName == "StartTurn" or normalizedEvent == "StartTurn" then
        -- Clear stale letter data setiap kali ada pergantian giliran
        _G.__SK_REMOTE_LETTER = ""
        _G.SK_LAST_LETTER = ""
        currentLetter = ""
        
        _G.__SK_AWAITING_LETTER = false
        
        if type(value) == "boolean" then
            local myTurn = not value
            _G.__SK_REMOTE_TURN = myTurn
            if myTurn then
                _G.__SK_MATCH_CONFIRMED = true
                matchActive = true
                isMyTurn = true
                _G.SK_ANSWER_LOCK = false
                _G.__SK_TURN_TIMESTAMP = tick()
                _G.__SK_AWAITING_LETTER = true
                log("🎯 [Remote] Giliran saya! (" .. eventName .. " raw=" .. tostring(value) .. " → myTurn) — menunggu huruf...")
                task.spawn(function()
                    task.wait(0.5)
                    if not _G.__SK_AWAITING_LETTER or not isMyTurn then return end
                    if currentLetter ~= "" and currentLetter ~= "-" then return end
                    pcall(function()
                        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                        if not pGui then return end
                        for _, sg in ipairs(pGui:GetChildren()) do
                            if sg:IsA("ScreenGui") and sg.Enabled then
                                local letter = findLetterViaAnchor(sg)
                                if not letter then letter = findLetterBroadScan(sg, false) end
                                if letter then
                                    currentLetter = letter
                                    _G.__SK_REMOTE_LETTER = letter
                                    _G.__SK_AWAITING_LETTER = false
                                    log("📡 [TurnStart-Scan] Huruf: " .. letter:upper() .. " (dari UI setelah TurnStart)")
                                    if CONFIG.AutoSubmit then task.spawn(onMyTurn, true) end
                                    if CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
                                    return
                                end
                            end
                        end
                    end)
                end)
            else
                isMyTurn = false
                _G.__SK_REMOTE_TURN = false
                _G.__SK_TURN_TIMESTAMP = 0
                log("👤 [Remote] Giliran orang lain (" .. eventName .. " raw=" .. tostring(value) .. ")")
            end
        elseif type(value) == "number" then
            matchActive = true
            _G.__SK_MATCH_CONFIRMED = true
            if value > 1 then matchTimer = value end
            log("📋 [Remote] StartTurn timer=" .. value .. "s (tunggu TurnStart boolean)")
        end
        
        -- Tangkap Secret ID dari extra
        if type(extra) == "string" and #extra > 5 then
            _G.SK_SECRET_ID = extra
            log("🔑 [" .. eventName .. "] Secret ID: " .. extra:sub(1,12) .. "...")
        end
        
        if isMyTurn then
            matchRoundCount = matchRoundCount + 1
            if CONFIG.AutoSubmit then task.spawn(onMyTurn, true) end
            if CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
        end
    elseif eventName == "EndTurn" or normalizedEvent == "EndTurn" then
        isMyTurn = false
        _G.__SK_REMOTE_TURN = false
        _G.SK_ANSWER_LOCK = false 
        _G.SK_LAST_LETTER = "" 
        _G.__SK_REMOTE_LETTER = ""
        -- Clear suggester saat giliran selesai
        if CONFIG.AutoSuggest then
            task.spawn(updateSuggestions)
        end
        if lastSubmittedWord ~= "" then
            STATS.wordsCorrect = STATS.wordsCorrect + 1
            lastSubmittedWord = ""
        end
        STATS.currentStreak = STATS.currentStreak + 1
        if STATS.currentStreak > STATS.bestStreak then STATS.bestStreak = STATS.currentStreak end
    elseif eventName == "UpdateWordIndex" or eventName == "IndexStatus" then
        if type(value) == "table" then
            processIndexData(value)
        end
    elseif eventName == "Mistake" then
        local mistakeUserId = nil
        local mistakeCount = nil
        
        if type(value) == "table" then
            mistakeUserId = value.userId or value.UserId or value.userid or value[1]
            mistakeCount = value.count or value.Count or value[2]
            
            local parts = {}
            for k, v in pairs(value) do
                table.insert(parts, tostring(k) .. "=" .. tostring(v) .. "(" .. type(v) .. ")")
            end
            log("📋 [Mistake] Data: {" .. table.concat(parts, ", ") .. "}")
        end
        
        if mistakeUserId then
            playerMistakes[mistakeUserId] = mistakeCount or ((playerMistakes[mistakeUserId] or 0) + 1)
            task.spawn(updateOverlays)
        end
        
        local isMyMistake = false
        if mistakeUserId then
            isMyMistake = (mistakeUserId == LocalPlayer.UserId)
        else
            isMyMistake = isMyTurn
        end
        
        if isMyMistake and CONFIG.Enabled and CONFIG.AutoRetry and isMyTurn then
            log("⚠ Kata Salah/Sudah Digunakan (Mistake)! Mencoba lagi...")
            STATS.retries = STATS.retries + 1
            _onMyTurnRunning = false
            _G.SK_ANSWER_LOCK = false
            task.spawn(triggerRetry, lastAnswer)
        end
    end
end)

-- === USED WORD WARNING (RETRY TRIGGER) ===
if UsedWordWarn then
    safeConnect(UsedWordWarn.OnClientEvent, function(word)
        local w = tostring(word or "")
        local wLower = w:lower()
        local isGameEvent = wLower == "init" or wLower == "turnstart" or wLower == "startturn" 
            or wLower == "endturn" or wLower == "showmatchui" or wLower == "hidematchui"
            or wLower == "updateserverletter" or wLower == "mistake" or wLower == "eliminated"
            or wLower == "victory" or wLower == "winner" or wLower == "updatetimer"
            or type(word) == "boolean" or type(word) == "table"
        
        if isGameEvent then
            log("📋 [UsedWordWarn] Ignored game event: " .. w .. " (bukan rejected word)")
            return
        end
        
        if CONFIG.Enabled and CONFIG.AutoRetry and isMyTurn then
            log("⚠ Kata '" .. w .. "' Sudah Digunakan! Mencoba lagi...")
            STATS.retries = STATS.retries + 1
            task.spawn(triggerRetry, word)
        end
    end)
end

-- === TURNCAMERA TRIGGER (BACKUP DETECTION) ===
if TurnCamera then
    safeConnect(TurnCamera.OnClientEvent, function(...)
        if CONFIG.Enabled and CONFIG.AutoSubmit then
            -- Trigger scan tambahan saat kamera bergerak
            task.spawn(function()
                task.wait(0.1) -- Jeda sinkronisasi kecil
                if isMyTurn then
                    onMyTurn() -- Panggil logic pengetikan
                end
            end)
        end
    end)
end

-- === INDEX DATA PROCESSOR ===
function processIndexData(data)
    if not data or type(data) ~= "table" then return end
    
    -- 📥 Auto-Learn kata
    if data.AllWords then
        local isGlobalDB = (data.Total and data.Total > 5000)
        for word, _ in pairs(data.AllWords) do
            local w = tostring(word):lower()
            if isGlobalDB then GLOBAL_INDEX_BLACKLIST[w] = true end
            learnFromServer(w)
        end
    end
    
    -- 📊 Update Stats
    if data.Count then
        if not initialIndexCount then initialIndexCount = data.Count end
        currentIndexCount = data.Count
        sessionNewWordsDiscovered = currentIndexCount - (initialIndexCount or currentIndexCount)
    end
    
    if data.Total then
        totalIndexPossible = data.Total
    end
    
    if data.Count then
        log("📡 Index Data Received: " .. data.Count .. " / " .. (data.Total or "?"))
    end
    
    refreshUI()
end

-- === INDEX HUNTER SINKRONISASI (SEPARATE REMOTE) ===
if UpdateWordIndex then
    local sniffConn = safeConnect(UpdateWordIndex.OnClientEvent, function(data)
        if _G.SK_BOT_ID ~= scriptId then 
            if sniffConn then sniffConn:Disconnect() end
            return 
        end
        processIndexData(data)
    end)
end

-- (Redundant retry listener removed, handled by retryConn above)

if PlayerHit then
    safeConnect(PlayerHit.OnClientEvent, function(p)
        if p == LocalPlayer and CONFIG.Enabled and CONFIG.AutoRetry and isMyTurn then
            log("❌ Ronde Macet / All Player Hit! Mencoba Refresh...")
            STATS.retries = STATS.retries + 1
            task.spawn(triggerRetry)
        end
    end)
end

-- === TYPING TRACKER (NEW FEATURE) ===
if WordUpdate then
    safeConnect(WordUpdate.OnClientEvent, function(player, currentWord)
        if player and player ~= LocalPlayer then
            playerTypingStatus[player] = tostring(currentWord or "")
            -- Sering di-refresh agar HUD langsung update
            task.spawn(updateOverlays)
        end
    end)
end

-- Reset typing status saat turn ganti
safeConnect(MatchUI.OnClientEvent, function(eventName)
    if eventName == "StartTurn" or eventName == "EndTurn" then
        playerTypingStatus = {}
    end
end)

-- ╔════════════════════════════════════════════════════════════╗
-- ║   DIRECT SERVER LETTER DETECTION (dari Dex Explorer)      ║
-- ╚════════════════════════════════════════════════════════════╝

-- Re-resolve remotes langsung (pastikan ditemukan sekarang, game sudah fully loaded)
if not UpdateCurrentWord then
    UpdateCurrentWord = Remotes:FindFirstChild("UpdateCurrentWord")
    if UpdateCurrentWord then log("🔗 Late-found: UpdateCurrentWord") end
end
if not WordUpdate then
    WordUpdate = Remotes:FindFirstChild("WordUpdate")
    if WordUpdate then log("🔗 Late-found: WordUpdate") end
end
if not EndTurnRemote then
    EndTurnRemote = Remotes:FindFirstChild("EndTurn")
    if EndTurnRemote then log("🔗 Late-found: EndTurn") end
end
if not PlayerCorrect then
    PlayerCorrect = Remotes:FindFirstChild("PlayerCorrect")
    if PlayerCorrect then log("🔗 Late-found: PlayerCorrect") end
end

-- Debug: log semua remote yang ada di folder Remotes
do
    local remoteList = {}
    for _, v in ipairs(Remotes:GetChildren()) do
        if v:IsA("RemoteEvent") then
            table.insert(remoteList, v.Name)
        elseif v:IsA("Folder") then
            local subCount = 0
            for _, sub in ipairs(v:GetChildren()) do
                if sub:IsA("RemoteEvent") then subCount = subCount + 1 end
            end
            table.insert(remoteList, v.Name .. "/(" .. subCount .. " remotes)")
        end
    end
    log("📋 [Remotes] Semua remote: " .. table.concat(remoteList, ", "))
end

log("📋 [Status] UCW=" .. tostring(UpdateCurrentWord ~= nil) .. " WU=" .. tostring(WordUpdate ~= nil) .. " ET=" .. tostring(EndTurnRemote ~= nil) .. " PC=" .. tostring(PlayerCorrect ~= nil))

-- ╔════════════════════════════════════════════════════════════╗
-- ║  HOOK SEMUA REMOTE OBFUSCATED (tangkap semua event game)  ║
-- ╚════════════════════════════════════════════════════════════╝
do
    local obfuscatedCount = 0
    for _, child in ipairs(Remotes:GetChildren()) do
        if child:IsA("Folder") then
            for _, remote in ipairs(child:GetChildren()) do
                if remote:IsA("RemoteEvent") then
                    obfuscatedCount = obfuscatedCount + 1
                    local remoteName = remote.Name
                    safeConnect(remote.OnClientEvent, function(eventName, value, extra)
                        -- Log SEMUA event (gunakan tostring langsung, BUKAN `value or "-"` karena false jadi "-")
                        local vStr = (value == nil) and "nil" or tostring(value)
                        if #vStr > 30 then vStr = vStr:sub(1,30) .. "..." end
                        local eStr = (extra == nil) and "nil" or tostring(extra)
                        if #eStr > 30 then eStr = eStr:sub(1,30) .. "..." end
                        log("📨 [OBF:" .. remoteName:sub(1,8) .. "] " .. tostring(eventName) .. " | v=" .. vStr .. "(" .. type(value) .. ") e=" .. eStr .. "(" .. type(extra) .. ")")
                        
                        local en = tostring(eventName or ""):lower()
                        
                        -- Extract huruf HANYA dari string (number BUKAN letter index!)
                        local function extractLetterString(val)
                            if type(val) == "string" then
                                local c = val:lower():gsub("%s+", "")
                                if #c >= 1 and #c <= 3 and c:match("^%a+$") then return c end
                            elseif type(val) == "table" then
                                for _, key in ipairs({"letter", "Letter", "prefix", "Prefix", "huruf", "Huruf", "char", "Char", 1}) do
                                    if val[key] and type(val[key]) == "string" then
                                        local c = val[key]:lower():gsub("%s+", "")
                                        if #c >= 1 and #c <= 3 and c:match("^%a+$") then return c end
                                    end
                                end
                            end
                            return nil
                        end
                        
                        -- === INIT EVENT: RESET semua state (match baru/spectate) ===
                        if en == "init" or en == "showmatchui" or en == "matchseed" then
                            isMyTurn = false
                            currentLetter = ""
                            _G.__SK_REMOTE_LETTER = ""
                            _G.__SK_REMOTE_TURN = false
                            _G.__SK_TURN_TIMESTAMP = 0
                            _G.__SK_AWAITING_LETTER = false
                            _G.SK_ANSWER_LOCK = false
                            if value ~= false and (en == "init" or en == "showmatchui") then
                                matchActive = true
                                _G.__SK_MATCH_CONFIRMED = true
                                log("🎮 [OBF] Match Started (" .. tostring(eventName) .. ")")
                            else
                                log("📋 [OBF] State reset (" .. tostring(eventName) .. " v=" .. tostring(value) .. ")")
                            end
                        end
                        
                        -- === TURN DETECTION ===
                        if en:find("turn") and en:find("start") or en == "startturn" or en == "turnstart" or en == "myturn" then
                            if type(value) == "boolean" then
                                local myTurn = not value
                                _G.__SK_REMOTE_TURN = myTurn
                                if myTurn then
                                    _G.__SK_MATCH_CONFIRMED = true
                                    matchActive = true
                                    isMyTurn = true
                                    _G.SK_ANSWER_LOCK = false
                                    currentLetter = ""
                                    _G.__SK_REMOTE_LETTER = ""
                                    _G.__SK_TURN_TIMESTAMP = tick()
                                    _G.__SK_AWAITING_LETTER = true
                                    log("🎯 [OBF] Giliran saya! (" .. tostring(eventName) .. " raw=" .. tostring(value) .. " → myTurn) — menunggu huruf...")
                                else
                                    isMyTurn = false
                                    currentLetter = ""
                                    _G.__SK_REMOTE_LETTER = ""
                                    _G.SK_ANSWER_LOCK = false
                                    _G.__SK_TURN_TIMESTAMP = 0
                                    _G.__SK_AWAITING_LETTER = false
                                    log("👤 [OBF] Giliran orang lain (" .. tostring(eventName) .. " raw=" .. tostring(value) .. ")")
                                end
                            end
                            
                            if type(extra) == "string" and #extra > 5 then
                                _G.SK_SECRET_ID = extra
                                log("🔑 [OBF] Secret ID: " .. extra:sub(1, 20) .. "...")
                            end
                        end
                        
                        -- === UPDATESERVERLETTER: Log saja, BUKAN sumber huruf ===
                        -- Angka di USL ({1=N}) bukan letter index! Huruf asli hanya dari UI.
                        if en == "updateserverletter" then
                            if type(value) == "table" then
                                local parts = {}
                                for k, v in pairs(value) do
                                    table.insert(parts, tostring(k) .. "=" .. tostring(v) .. "(" .. type(v) .. ")")
                                end
                                log("📋 [USL] Data: {" .. table.concat(parts, ", ") .. "} (bukan letter, perlu UI scan)")
                            end
                            
                            -- Cek apakah ada STRING huruf di USL (bukan number)
                            local letter = extractLetterString(value) or extractLetterString(extra)
                            if letter and _G.__SK_AWAITING_LETTER then
                                currentLetter = letter
                                _G.__SK_REMOTE_LETTER = letter
                                _G.__SK_AWAITING_LETTER = false
                                log("📡 [OBF-LETTER] Huruf: " .. letter:upper() .. " (string dari USL)")
                                if CONFIG.AutoSubmit then task.spawn(onMyTurn, true) end
                                if CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
                            end
                            
                            -- Jika masih menunggu huruf, picu UI scan via anchor
                            if _G.__SK_AWAITING_LETTER and isMyTurn then
                                task.spawn(function()
                                    task.wait(0.3)
                                    if _G.__SK_AWAITING_LETTER and isMyTurn and (currentLetter == "" or currentLetter == "-") then
                                        pcall(function()
                                            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                                            if not pGui then return end
                                            for _, sg in ipairs(pGui:GetChildren()) do
                                                if sg:IsA("ScreenGui") and sg.Enabled then
                                                    local letter = findLetterViaAnchor(sg)
                                                    if not letter then
                                                        letter = findLetterBroadScan(sg, false)
                                                    end
                                                    if letter then
                                                        currentLetter = letter
                                                        _G.__SK_REMOTE_LETTER = letter
                                                        _G.__SK_AWAITING_LETTER = false
                                                        log("📡 [UI-LETTER] Huruf: " .. letter:upper() .. " (dari UI anchor/broad)")
                                                        if CONFIG.AutoSubmit then task.spawn(onMyTurn, true) end
                                                        if CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
                                                        return
                                                    end
                                                end
                                            end
                                        end)
                                    end
                                end)
                            end
                        end
                        
                        -- === MISTAKE → AUTO RETRY ===
                        if en == "mistake" and isMyTurn and CONFIG.Enabled and CONFIG.AutoRetry then
                            log("⚠ [OBF] Mistake detected! Mencoba kata lain...")
                            STATS.retries = STATS.retries + 1
                            _onMyTurnRunning = false
                            _G.SK_ANSWER_LOCK = false
                            task.spawn(triggerRetry, lastAnswer)
                        end
                        
                        -- === END/ELIMINATE/VICTORY ===
                        if en == "endturn" then
                            isMyTurn = false
                            _G.__SK_REMOTE_TURN = false
                            _G.SK_ANSWER_LOCK = false
                            _G.__SK_AWAITING_LETTER = false
                        elseif en == "hidematchui" or en == "eliminated" or en == "victory" or en == "winner" then
                            matchActive = false
                            isMyTurn = false
                            _G.__SK_MATCH_CONFIRMED = false
                            _G.__SK_REMOTE_TURN = false
                            _G.__SK_AWAITING_LETTER = false
                            currentLetter = ""
                            _G.__SK_REMOTE_LETTER = ""
                        end
                        
                        -- Tangkap Secret ID dari parameter apapun
                        for _, p in ipairs({extra, value}) do
                            if type(p) == "string" and #p > 10 and p:find("%d") and not p:find("[a-zA-Z]") then
                                _G.SK_SECRET_ID = p
                            end
                        end
                    end)
                end
            end
        end
    end
    log("✅ [OBF] Hooked " .. obfuscatedCount .. " obfuscated remotes (tangkap semua event game)")
end

-- UpdateCurrentWord: Server kirim huruf/prefix aktif ke client
if UpdateCurrentWord then
    safeConnect(UpdateCurrentWord.OnClientEvent, function(value, extra)
        log("📨 [UpdateCurrentWord] v=" .. tostring(value) .. "(" .. type(value) .. ") e=" .. tostring(extra or "-") .. "(" .. type(extra or "nil") .. ")")
        
        local newLetter = ""
        if type(value) == "string" then
            local clean = value:lower():gsub("%s+", "")
            if #clean >= 1 and #clean <= 3 and clean:match("^%a+$") then
                newLetter = clean
            end
        elseif type(value) == "table" then
            for _, key in ipairs({"letter", "Letter", "prefix", "Prefix", "huruf", "Huruf", "char", "Char", 1}) do
                if value[key] and type(value[key]) == "string" then
                    local clean = value[key]:lower():gsub("%s+", "")
                    if #clean >= 1 and #clean <= 3 and clean:match("^%a+$") then
                        newLetter = clean
                        break
                    end
                end
            end
        end
        
        if newLetter ~= "" then
            currentLetter = newLetter
            _G.__SK_REMOTE_LETTER = newLetter
            log("📡 [SERVER] Huruf diterima: " .. newLetter:upper() .. " (dari UpdateCurrentWord)")
            if isMyTurn and CONFIG.AutoSubmit then task.spawn(onMyTurn, true) end
            if isMyTurn and CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
        else
            log("📋 [UpdateCurrentWord] Tidak ada huruf string — v=" .. tostring(value) .. " (mungkin bukan letter event)")
        end
    end)
    log("✅ [Direct] UpdateCurrentWord listener aktif")
else
    log("⚠️ UpdateCurrentWord remote tidak ditemukan")
end

-- WordUpdate: Kemungkinan update kata/huruf tambahan
if WordUpdate then
    safeConnect(WordUpdate.OnClientEvent, function(value, extra)
        log("📨 [WordUpdate] v=" .. tostring(value) .. "(" .. type(value) .. ") e=" .. tostring(extra or "-") .. "(" .. type(extra or "nil") .. ")")
        
        local newLetter = ""
        if type(value) == "string" then
            local clean = value:lower():gsub("%s+", "")
            if #clean >= 1 and #clean <= 3 and clean:match("^%a+$") then
                newLetter = clean
            end
        elseif type(value) == "table" then
            for _, key in ipairs({"letter", "Letter", "prefix", "Prefix", "huruf", "Huruf", "char", "Char", 1}) do
                if value[key] and type(value[key]) == "string" then
                    local clean = value[key]:lower():gsub("%s+", "")
                    if #clean >= 1 and #clean <= 3 and clean:match("^%a+$") then
                        newLetter = clean
                        break
                    end
                end
            end
        end
        
        if newLetter ~= "" then
            currentLetter = newLetter
            _G.__SK_REMOTE_LETTER = newLetter
            log("📡 [SERVER] Huruf diterima: " .. newLetter:upper() .. " (dari WordUpdate)")
            if isMyTurn and CONFIG.AutoSubmit then task.spawn(onMyTurn, true) end
            if isMyTurn and CONFIG.AutoSuggest then task.spawn(updateSuggestions) end
        end
    end)
    log("✅ [Direct] WordUpdate listener aktif")
end

-- EndTurn (named remote): Giliran selesai
if EndTurnRemote then
    safeConnect(EndTurnRemote.OnClientEvent, function(value, extra)
        log("📨 [EndTurn-Direct] v=" .. tostring(value) .. " e=" .. tostring(extra or "-"))
        isMyTurn = false
        _G.__SK_REMOTE_TURN = false
        _G.SK_ANSWER_LOCK = false
        playerTypingStatus = {}
    end)
    log("✅ [Direct] EndTurn listener aktif")
end

-- PlayerCorrect: Pemain menjawab benar (bisa tangkap huruf baru)
if PlayerCorrect then
    safeConnect(PlayerCorrect.OnClientEvent, function(value, extra)
        log("📨 [PlayerCorrect] v=" .. tostring(value) .. "(" .. type(value) .. ") e=" .. tostring(extra or "-") .. "(" .. type(extra or "nil") .. ")")
    end)
end

-- === TABLE VISIBILITY TRACKER (AUTO JOIN ACCURACY) ===
if UpdatePromptVisibility then
    safeConnect(UpdatePromptVisibility.OnClientEvent, function(hiddenDict)
        tableHiddenStatus = hiddenDict or {}
        -- Jika AutoJoin aktif, coba scan ulang saat ada perubahan visibilitas meja
        if CONFIG.AutoJoinTable and not matchActive and not LocalPlayer:GetAttribute("CurrentTable") then
            task.spawn(autoJoinTable)
        end
    end)
end

local resultConn = safeConnect(ResultUI.OnClientEvent, function(data)
    if _G.SK_BOT_ID ~= scriptId then 
        if resultConn then resultConn:Disconnect() end
        return 
    end

    if type(data) == "table" then
        local earned = 0
        if data.AnswerMoney then earned = earned + tonumber(data.AnswerMoney) end
        if data.WinMoney then earned = earned + tonumber(data.WinMoney) end
        
        if earned > 0 then
            STATS.totalCoinsEarned = STATS.totalCoinsEarned + earned
            log("💰 Sesi Ini: Mendapatkan +" .. earned .. " Koin! (Total: " .. STATS.totalCoinsEarned .. ")")
            refreshUI()
        end
    end
end)

-- === STARTUP ===
isRunning = true

task.spawn(function()
    log("🛡️ Starship Bypass AntiCheat")
    if not loadWordListFromURL() then loadFallbackDB() end
    refreshUI()
    
    -- Removed immediate server poke for stealth
    -- if MatchUI then pcall(function() MatchUI:FireServer("GetIndex") end) end
end)


-- Main Loop: Terus scan kondisi game dan update UI & Overlay (OPTIMIZED)
-- Auto-vote: HANYA via GameModeVote.OnClientEvent (scan UI dihapus — ModeUI dll sering false positive)
task.spawn(function()
    local lastUIRefresh = 0
    while isRunning and _G.SK_BOT_ID == scriptId do
        pcall(function()
            scanGameState()
            
            -- UI Update (Throttled 2 detik untuk menghemat FPS)
            local now = tick()
            if now - lastUIRefresh > 1.8 then
                refreshUI()
                handleStreamingMode()
                lastUIRefresh = now
            end
        end)
        task.wait(0.3) -- Loop responsif
    end
end)

-- === FORCE STARTUP ===

-- === FORCE STARTUP ===
_G.SK_BOT_ID = scriptId 
isRunning = true