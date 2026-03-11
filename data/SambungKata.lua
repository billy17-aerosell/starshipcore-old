--[[
    ╔══════════════════════════════════════════════════════════╗
    ║          SAMBUNG KATA - AUTO ANSWER BOT v7               ║
    ║   HTTP API Word List + Remote-Based Submit               ║
    ║   UI POWERED BY WINDUI                                   ║
    ╚══════════════════════════════════════════════════════════╝
]]

-- === STARSHIP BYPASS ANTI-CHEAT (LAG-FREE) ===
pcall(function()
    -- 1. Load External Bypass (Sync to ensure safety BEFORE our hooks)
    pcall(function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/Pixeluted/adoniscries/main/Source.lua'))()
    end)

    local StarterGui = game:GetService("StarterGui")

    -- Fungsi Inti untuk Rebranding
    local function applyRebrand(name, data)
        if name == "SendNotification" and type(data) == "table" then
            local title = tostring(data.Title or "")
            local text = tostring(data.Text or "")
            -- Perluas filter ke 'anti' dan 'detect'
            if title:lower():find("anti") or title:lower():find("anti") or title:lower():find("adonis") or text:lower():find("pixel") or text:lower():find("detect") then
                data.Title = "STARSHIP SYSTEM"
                data.Text = "Anti-Cheat Bypassed Successfully!"
                data.Icon = ""
                data.Duration = 5
                return true
            end
        end
        return false
    end

    -- LAYER 1: Hook Fungsi Langsung (Fast & Reliable)
    local oldSetCore
    oldSetCore = hookfunction(StarterGui.SetCore, function(self, name, data)
        if not checkcaller() then applyRebrand(name, data) end
        return oldSetCore(self, name, data)
    end)

    -- LAYER 2: Hook Namecall (KONSOLIDASI UNTUK STEALTH)
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if checkcaller() then return oldNamecall(self, ...) end

        local method = getnamecallmethod()

        -- A. Rebrand logic
        if (method == "SetCore" or method == "setCore") and self == StarterGui then
            local args = {...}
            if applyRebrand(args[1], args[2]) then
                return oldNamecall(self, unpack(args))
            end
        end

        -- B. Ghost Mode logic (Semi-Auto Submit)
        -- Kita hanya memproses remote 'SubmitWord'
        if _G.SK_PENDING_WORD and _G.SK_PENDING_WORD ~= "" then
            if (method == "FireServer" or method == "fireServer") then
                -- Cek via assignment global atau fallback nama
                if (_G.SK_SUBMIT_REMOTE and self == _G.SK_SUBMIT_REMOTE) or (not _G.SK_SUBMIT_REMOTE and tostring(self.Name) == "SubmitWord") then
                    local args = {...}
                    args[1] = _G.SK_PENDING_WORD
                    _G.SK_PENDING_WORD = nil
                    return oldNamecall(self, unpack(args))
                end
            end
        end

        return oldNamecall(self, ...)
    end))
end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

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
    DebugMode = true,
    UseRandomDelay = true,
    MinDelay = 1.0,
    MaxDelay = 2.0,
    SimulateTyping = true,
    TypeCharDelay = 0.12,
    AvoidRepeat = true,
    HardMode = false,
    AutoRetry = true,
    AutoJoinTable = false,
    WordLengthMode = "Any",   -- "Any", "Short", "Long"
    WordFilter = "Campuran",   -- "Semua", "Umum", "Campuran"
    InteractionMode = "Bot",   -- "Bot", "Human"

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
    HighScoreMode = false, -- PRIORITASKAN KATA PANJANG UNTUK POIN MAKSIMAL

    -- Auto Join
    AutoJoinDelay = 3,
    KillerMode = true, -- PRIORITASKAN KATA SULIT DARI SERVER
    FastCollection = false, -- PRIORITASKAN KATA BARU UNTUK INDEX
    AutoClaim = true, -- OTOMATIS AMBIL HADIAH KOIN
    IndexBlacklist = false, -- BLACKLIST KATA YANG SUDAH DI-INDEX
    ShowOverlays = true, -- TAMPILKAN OVERLAY DI ATAS KEPALA PEMAIN
    ShowSelfHUD = true, -- PREVIEW JAWABAN DI ATAS KEPALA SENDIRI
    Transparency = 0.92, -- TRANSPARANSI BACKGROUND UI (0 = Terang, 1 = Gelap/Hidden)
    Theme = "Crimson", -- TEMA DEFAULT
    TrollMode = false, -- Aktifkan Prank/Troll
    TrollText = "Wlee kmu Cupu!", -- Teks yang muncul di atas kepala
    SemiAuto = false, -- Mode ngetik manual tapi bot yang benerin pas enter
    AutoSuggest = false, -- Tampilkan saran kata saat giliran kamu
    AutoSuggestMax = 50, -- Maksimal kata yang ditampilkan di suggester

    -- Streaming Mode (Spoofing)
    StreamingMode = false,
    SpoofName = "StarshipPlayer",
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
local Window = nil



function cleanupBot(isFromUI)
    if not isRunning then return end
    isRunning = false

    local serial = scriptId:sub(1,4)
    print("[SK-Bot-" .. serial .. "] 🛑 Stopping bot and cleaning up resources...")

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

-- === WINDUI LIBRARY (BOREAL VERSION) ===
local success, result = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/orialdev/WindUI-Boreal/main/WindUI%20Boreal"))()
end)

local WindUI
if success and result then
    WindUI = result
    _G.WindUIIsBoreal = true
else
    -- Fallback ke versi lama jika Boreal gagal (Mungkin lambat/down)
    warn("⚠️ WindUI Boreal gagal dimuat, menggunakan versi standar...")
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    _G.WindUIIsBoreal = false
end


-- === SAFE REMOTE FETCHING ===
local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
    local errMsg = "❌ CRITICAL: Folder 'Remotes' tidak ditemukan! Pastikan Anda berada di meja atau game sudah dimuat sempurna."
    warn(errMsg)
    pcall(function()
        if WindUI and WindUI.Notify then
            WindUI:Notify({Title = "Error", Content = errMsg, Duration = 10})
        end
    end)
    return
end

local function getRemote(name, optional)
    local remote = Remotes:FindFirstChild(name)
    if not remote and not optional then
        remote = Remotes:WaitForChild(name, 5)
    end

    if not remote and not optional then
        warn("⚠️ Remote Krusial '" .. name .. "' tidak ditemukan!")
    end
    return remote
end


-- [[ ACCOUNT STATUS HELPERS (PORTED FROM MOBILEUI) ]]
local function FormatRole(role)
    if not role then return "FREE" end
    return tostring(role):gsub("_", " "):upper()
end

local function ParseVIPExpiry(durationStr)
    if not durationStr or durationStr == "Lifetime" or durationStr == "lifetime" then return nil end
    local days = tonumber(durationStr:match("(%d+)%s*day"))
    local hours = tonumber(durationStr:match("(%d+)%s*hour"))
    if days then return os.time() + (days * 24 * 60 * 60)
    elseif hours then return os.time() + (hours * 60 * 60) end
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

if not _G.sessionData then
    _G.sessionData = (getgenv and getgenv().StarshipSession) or {
        Role = "VIP MOBILE",
        Duration = "30 days",
        UserId = LocalPlayer.UserId,
        Username = LocalPlayer.Name,
    }
end
local sessionData = _G.sessionData

local vipExpiryTime = nil
if sessionData.Expiry and type(sessionData.Expiry) == "number" then
    vipExpiryTime = sessionData.Expiry
elseif sessionData.Expiry and type(sessionData.Expiry) == "string" and tonumber(sessionData.Expiry) then
    vipExpiryTime = tonumber(sessionData.Expiry)
else
    vipExpiryTime = ParseVIPExpiry(sessionData.Duration)
    sessionData.Expiry = vipExpiryTime -- SAVE FOR SYNC
end

local function GetVIPStatusDesc()
    local timeRemaining = "Lifetime"
    if vipExpiryTime then
        local remaining = vipExpiryTime - os.time()
        timeRemaining = FormatTimeRemaining(remaining)
    end
    return '<font size="16">Role: ' .. FormatRole(sessionData.Role) .. "\nTime Remaining: " .. timeRemaining .. "\nStatus: Active</font>"
end

-- ... (Implementasi fungsi forward akan menyusul di bawah)
log = function(msg)
    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
    local taggedMsg = "[SK-Bot-" .. scriptId:sub(1,4) .. "] " .. tostring(msg)
    if UI_LOG_MSG then UI_LOG_MSG(msg) end -- UI logs don't need tag
    print(taggedMsg)
end
notify = function(title, content)
    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
    if WindUI then WindUI:Notify({Title = title, Content = content, Duration = 3}) end
end

local SubmitWord = getRemote("SubmitWord")
_G.SK_SUBMIT_REMOTE = SubmitWord -- Daftarkan ke hook namecall agar akurat
local MatchUI = getRemote("MatchUI")
local JoinTable = getRemote("JoinTable")
local LeaveTable = getRemote("LeaveTable", true)
local ResultUI = getRemote("ResultUI")
local TurnCamera = getRemote("TurnCamera") or getRemote("UpdateCamera", true)
local UsedWordWarn = getRemote("UsedWordWarn")
local UpdatePromptVisibility = getRemote("UpdatePromptVisibility", true)
local tableHiddenStatus = {} -- Penampung data meja yang sedang penuh/tidak aktif

BillboardUpdate = Remotes:FindFirstChild("BillboardUpdate") or getRemote("BillboardUpdate", true)
-- === AGGRESSIVE REMOTE HUNT (TypeSound Fix) ===
TypeSound = Remotes:FindFirstChild("TypeSound")
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
        local path = TypeSound:GetFullName()
        print("[SK-Bot] ✅ TypeSound Found at: " .. path)
        pcall(function()
            if log then log("🔊 [SK-Bot] TypeSound Linked: " .. path) end
        end)
    else
        warn("⚠️ [SK-Bot] TypeSound Remote TIDAK ditemukan bahkan dengan scan mendalam!")
        if log then log("❌ [SK-Bot] TypeSound Remote NOT FOUND") end
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
local GiveWeaponReward = getRemote("GiveWeaponReward", true)
local UpdatePromptVisibility = getRemote("UpdatePromptVisibility", true)
local UpdateCurrentWord = getRemote("UpdateCurrentWord", true)
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
        "jalan","jeruk","jatuh","jarak","jelas","jendela","jernih","jiwa","jual","jubah","jujur","jumpa","jahat","jamin","jamu","jangan","jawab","jemput","jadi","jadwal","jaga","jagat","jago","jagung","jahit","jalur","jam","jambu","janji","jantung","jaring","jarum","jati","jauh","jaya",
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
    print("[SK-Bot] 📋 Common words set: " .. #commonData .. " kata umum")
end
buildCommonWordsSet()

-- === STATE ===
local loadingStatus = "⏳ Memuat..."
local totalWordsLoaded = 0
local wordListLoaded = false

_G.SK_ANSWER_LOCK = false
_G.SK_LAST_LETTER = ""

local usedWords = {}
local gameUsedWords = {}
-- isRunning moved to top
local currentLetter = ""
local isMyTurn = false
local matchActive = false
local lastAnswer = ""
local lastSubmittedWord = ""
local retryingWord = false
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
    t={"tangan","teman","timur","tanah","tanam","tanda","tangga","tangis","tanya","tari","taruh","tawar","tebal","tegak","tegas","tekad","telur","tembak","tenang","tengah","tepat","terang","terjun","tertib","tetap","tiang","tidur","tikus","tinta","tolong","tongkat","topeng","tugas","tuhan","tujuh","tulang","tulus","tumbuh","tumis","turun","tusuk","tabrak","tabu","type","typhus","teologi","teks"},
    u={"ular","udara","ubah","ucap","udang","ujian","ukir","ukur","ulang","ulat","umpan","unik","untung","upah","upaya","urai","usaha","usai","usap","utama","utang","utuh","utusan","ubur","uji","ukuran","ulah","ulet","ulung","umbi","umum","undang","unduh","ungkap","ungu","universitas","unsur","untuk","urus","urut","usang","usia","usir","usul","utara"},
    v={"vaksin","variasi","vokal","volume","vital","visi","visa","video","viral","virtual","virus","vitamin","vonis"},
    w={"waktu","warna","wajah","wajar","wangi","warga","warung","wasit","wilayah","wisata","wujud","wanita","waras","wadah","wajib","wakil","warisan","watak","wayang"},
    x={"xenon","xilofon","xerox"},
    y={"yakin","yang","yatim","yoga","yayasan","yuran","yoyo","yayasan","yodium","yunani","yunior","yurisdiksi"},
    z={"zaman","zat","zebra","zona","zodiak","zaitun","zamrud","ziarah"},
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

-- === UTILITY ===
function log(msg)
    if CONFIG.DebugMode then
        print("[SK-Bot] " .. tostring(msg))
    end
    if UI_LOG_MSG then
        UI_LOG_MSG(tostring(msg))
    end
end

function notify(title, text)
    if CONFIG.ShowNotif then
        pcall(function()
            WindUI:Notify({
                Title = title,
                Content = text,
                Duration = 3
            })
        end)
    end
end

-- ╔════════════════════════════════════════════════════════════╗
-- ║     WORD LIST LOADER (HTTP)                               ║
-- ╚════════════════════════════════════════════════════════════╝

local function parseWordList(rawText)
    local db = {}
    local count = 0

    -- Auto-detect JSON
    local isJSON = rawText:match("^%s*[%{%[]")
    if isJSON then
        log("📦 JSON Wordlist terdeteksi! Mencoba decode...")
        local success, data = pcall(function() return HttpService:JSONDecode(rawText) end)
        if success then
            log("✅ JSON Berhasil di-parse. Mengekstrak kata...")
            local function extractWords(node)
                if type(node) == "string" then
                    local word = node:lower():gsub("^%s+", ""):gsub("%s+$", "") -- Trim saja
                    -- SYARAT KETAT: Harus satu kata utuh, TIDAK BOLEH ada spasi atau tanda hubung
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
        -- Pola: ('kata ', 'arti', type)
        for val in rawText:gmatch("%('%s*([^']-)%s*'%s*,") do
            local word = val:lower():gsub("^%s+", ""):gsub("%s+$", "") -- Trim saja

            -- SYARAT KETAT: Harus satu kata utuh, TIDAK BOLEH ada spasi atau tanda hubung
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

    -- Kita tidak me-reset totalWordsLoaded di sini agar bisa terus bertambah dari berbagai sumber
    -- Tapi kita akan menghitung ulang TOTAL AKHIR agar akurat (mencegah duplikat hitung)

    for i, url in ipairs(CONFIG.WordListURLs) do
        loadingStatus = string.format("Mencoba sumber %d/%d...", i, #CONFIG.WordListURLs)
        local rawText = httpGet(url)
        if rawText and #rawText > 100 then
            local db, count = parseWordList(rawText)
            if count > 0 then
                -- MERGE instead of replace to keep fallback words
                for char, words in pairs(db) do
                    if not KATA_DB[char] then KATA_DB[char] = {} end
                    for _, w in ipairs(words) do
                        if not table.find(KATA_DB[char], w) then
                            table.insert(KATA_DB[char], w)
                        end
                    end
                end
                anySuccess = true
                wordListLoaded = true
            end
        end
        task.wait(0.1) -- Jeda kecil antar request
    end

    if anySuccess then
        -- HITUNG ULANG TOTAL KOSAKATA UNIK SECARA AKURAT
        local totalUnik = 0
        for _, words in pairs(KATA_DB) do
            totalUnik = totalUnik + #words
        end
        totalWordsLoaded = totalUnik
        loadingStatus = "✅ DB Merged (" .. totalWordsLoaded .. " kata unik)"
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

        -- WORD FILTER LOGIC (Umum vs Semua)
        if CONFIG.WordFilter == "Umum" and not COMMON_WORDS[v] then return false end
        if CONFIG.WordFilter == "Campuran" and not COMMON_WORDS[v] and math.random(1,100) > 40 then
            return false
        end

        -- SARINGAN ANTI-SAMPAH
        if not v:match("[aeiou]") then return false end

        if CONFIG.WordLengthMode == "Short" and #v > 5 then return false end
        if CONFIG.WordLengthMode == "Long" and #v < 7 then return false end
        if CONFIG.HighScoreMode and #v < 8 then return false end -- Filter ekstra untuk High Score
        return true
    end

    if CONFIG.DebugMode and not silent then log("🔍 Mencari kata awalan: '" .. prefix .. "'") end

    local function getMatchedWords(ignoreBlacklist, ignoreFilter)
        local results = {}
        -- Simpan sementara filter asli
        local originalFilter = CONFIG.WordFilter
        if ignoreFilter then CONFIG.WordFilter = "Semua" end

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

        -- Kembalikan filter (jika berubah)
        CONFIG.WordFilter = originalFilter
        return results
    end

    -- LEVEL 1: Cari kata baru dengan filter aktif
    local matched = getMatchedWords(false, false)

    -- LEVEL 2: Jika kata baru habis, cari kata lama (Abaikan Blacklist)
    if #matched == 0 and CONFIG.IndexBlacklist then
        if CONFIG.DebugMode then log("⚠️ Kata baru habis/ter-blacklist! Mencari kata lama...") end
        matched = getMatchedWords(true, false)
    end

    -- LEVEL 3: Jika filter 'Umum' atau 'Campuran' terlalu pelit, abaikan filter (Pakai 'Semua')
    if #matched == 0 and CONFIG.WordFilter ~= "Semua" then
        if CONFIG.DebugMode then log("⚠️ Filter terlalu ketat! Mengalihkan ke mode Semua Kata...") end
        matched = getMatchedWords(true, true) -- Abaikan blacklist JIKA benar-benar terpaksa
    end

    if #matched == 0 then
        if not silent then log("❌ GAGAL: Tidak menemukan kata untuk '" .. prefix:upper() .. "'") end
        return nil
    end

        -- 1. Strategi Opponent Locking (Jika KillerMode ON atau HardMode ON)
    if CONFIG.KillerMode or CONFIG.HardMode then
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
            if CONFIG.HardMode and not CONFIG.HighScoreMode then
                if scoreA ~= scoreB then return scoreA > scoreB end
                return #a > #b
            end
            if CONFIG.HighScoreMode then
                if #a ~= #b then return #a > #b end
                return scoreA > scoreB
            end
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

    -- 3. Default: Ambil yang terbaik dari hasil sort (atau random jika bukan killer)
    if not CONFIG.KillerMode and not CONFIG.HardMode then
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
                    label.Parent = wordSubmit
                end
                label.Text = charAt
                label.LayoutOrder = i
                label.Visible = true

                if i == #currentWord then
                    local scale = label:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", label)
                    scale.Scale = 0.6
                    game:GetService("TweenService"):Create(scale, TweenInfo.new(0.1), {Scale = 1}):Play()
                end
            end
        end
    end)
end

local function submitWordViaRemote(letter, word, deleteWord)
    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end

    -- === SIMULASI BACKSPACE (Jika ada kata yang harus dihapus dulu) ===
    if deleteWord and #deleteWord > 0 then
        local currentText = deleteWord:lower()
        -- Simulasi hapus satu-satu (Backspace)
        for i = #currentText-1, 0, -1 do
            if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
            local partial = currentText:sub(1, i)
            _G.SK_CURRENT_PARTIAL = partial

            -- [UPDATE] BillboardUpdate hanya menerima suffix
            if BillboardUpdate then
                local suffixPart = partial:sub(#letter + 1)
                pcall(function() BillboardUpdate:FireServer(suffixPart) end)
            end

            animateMobileKeys("") -- Clear keyboard highlight
            fireTypeSound()
            task.wait(math.random(6, 12) * 0.01) -- Kecepatan hapus humanis
        end
        task.wait(math.random(3, 6) * 0.1) -- Jeda sebentar sebelum ngetik ulang
    end

    -- === PROSES PENGETIKAN ===
    if CONFIG.TrollMode then
        -- Menghapus spasi karena billboard game biasanya memotong teks setelah spasi pertama
        local trollText = CONFIG.TrollText:gsub("%s+", "")

        -- Simulasi pengetikan teks prank
        for i = 1, #trollText do
            local partialTroll = trollText:sub(1, i)
            _G.SK_CURRENT_PARTIAL = partialTroll

            -- [UPDATE] Hanya kirim partial troll ke Billboard
            if BillboardUpdate then
                pcall(function() BillboardUpdate:FireServer(partialTroll) end)
            end

            fireTypeSound()
            task.wait(CONFIG.TypeCharDelay)
            if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
        end

        task.wait(0.5)
        if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
    else
        -- LOGIKA NORMAL
        local typedPart = string.sub(word, #letter + 1)

        if CONFIG.SimulateTyping and #typedPart > 0 then
            local isHuman = (CONFIG.InteractionMode == "Human")

            -- ╔════════════════════════════════════════════════════════════╗
            -- ║  HUMAN MODE: 4 EFEK SIMULASI MANUSIA                     ║
            -- ║  1. Pause di awal kata (hesitasi sebelum ngetik)          ║
            -- ║  2. Pause di tengah kata (berhenti mikir)                 ║
            -- ║  3. Kelebihan huruf + hapus (ngetik kebablasan)           ║
            -- ║  4. Typo 1 huruf + hapus (salah pencet)                  ║
            -- ╚════════════════════════════════════════════════════════════╝

            -- === [EFEK 1] PAUSE DI AWAL KATA (Human Only) ===
            -- Simulasi ragu-ragu/mikir sebelum mulai mengetik
            if isHuman and math.random(1, 100) <= 40 then -- 40% chance
                local hesitateTime = math.random(8, 25) * 0.1 -- 0.8s - 2.5s
                if CONFIG.DebugMode then log("🤔 [Human] Hesitasi awal: " .. string.format("%.1f", hesitateTime) .. "s") end
                task.wait(hesitateTime)
                if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
            end

            -- === SIMULASI GANTI PIKIRAN (Human Only) ===
            -- Ngetik kata lain dulu, terus ganti ke kata yang bener
            if isHuman and math.random(1, 100) <= 15 then -- 15% Peluang
                local firstChar = letter:sub(1,1):lower()
                local fakes = KATA_DB[firstChar]
                if fakes and #fakes > 1 then
                    local fakeWord = fakes[math.random(1, #fakes)]
                    if fakeWord ~= word then
                        local fakePart = fakeWord:sub(#letter + 1, #letter + math.random(2, 4))
                        for j = 1, #fakePart do
                            if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
                            if BillboardUpdate then pcall(function() BillboardUpdate:FireServer(letter .. fakePart:sub(1, j)) end) end
                            fireTypeSound()
                            task.wait(math.random(15, 30) * 0.01)
                        end
                        if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
                        task.wait(math.random(6, 12) * 0.1) -- Jeda "eh salah/ganti deh"
                        if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
                        -- Hapus satu-satu (Backspace)
                        for j = #fakePart-1, 0, -1 do
                            if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
                            if BillboardUpdate then pcall(function() BillboardUpdate:FireServer(letter .. fakePart:sub(1, j)) end) end
                            fireTypeSound()
                            task.wait(math.random(8, 15) * 0.01)
                        end
                        if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
                        task.wait(math.random(3, 6) * 0.1) -- Jeda sebelum ngetik ulang
                        if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
                    end
                end
            end

            -- === SETUP EFEK PER-KARAKTER ===
            local hasTypo = isHuman and (math.random(1, 100) <= 20) -- [EFEK 4] 20% chance typo
            local typoPoint = hasTypo and math.random(1, #typedPart) or 0

            local hasExtraChar = isHuman and (math.random(1, 100) <= 18) -- [EFEK 3] 18% chance kelebihan huruf
            local extraCharPoint = hasExtraChar and math.random(2, math.max(2, #typedPart)) or 0
            -- Pastikan tidak bentrok dengan typo
            if hasExtraChar and extraCharPoint == typoPoint then
                extraCharPoint = math.min(#typedPart, extraCharPoint + 1)
            end

            local hasMidPause = isHuman and (math.random(1, 100) <= 35) -- [EFEK 2] 35% chance pause tengah
            local midPausePoint = hasMidPause and math.random(2, math.max(2, #typedPart - 1)) or 0

            for i = 1, #typedPart do
                if not isRunning or _G.SK_BOT_ID ~= scriptId then break end
                local skipNormalType = false

                -- === [EFEK 2] PAUSE DI TENGAH KATA ===
                -- Simulasi berhenti mikir di tengah ngetik
                if hasMidPause and i == midPausePoint then
                    local pauseTime = math.random(5, 15) * 0.1 -- 0.5s - 1.5s
                    if CONFIG.DebugMode then log("⏸️ [Human] Pause tengah kata di huruf ke-" .. i .. " (" .. string.format("%.1f", pauseTime) .. "s)") end
                    task.wait(pauseTime)
                    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
                    hasMidPause = false
                end

                -- === [EFEK 3] KELEBIHAN HURUF + HAPUS ===
                -- Ngetik satu huruf tambahan (kebablasan) terus hapus
                if hasExtraChar and i == extraCharPoint then
                    -- Tulis huruf saat ini dulu
                    local partialNow = typedPart:sub(1, i)
                    _G.SK_CURRENT_PARTIAL = letter .. partialNow
                    if BillboardUpdate then pcall(function() BillboardUpdate:FireServer(partialNow) end) end
                    animateMobileKeys(typedPart:sub(i,i))
                    fireTypeSound()
                    task.wait(CONFIG.TypeCharDelay * (math.random(9, 13) * 0.1))
                    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end

                    -- Ngetik huruf EXTRA (kebablasan)
                    local nextCharIdx = i + 1
                    local extraCh
                    if nextCharIdx <= #typedPart then
                        extraCh = typedPart:sub(nextCharIdx, nextCharIdx)
                    else
                        local chars = "abcdefghijklmnopqrstuvwxyz"
                        local rIdx = math.random(1, #chars)
                        extraCh = chars:sub(rIdx, rIdx)
                    end
                    local partialExtra = partialNow .. extraCh
                    _G.SK_CURRENT_PARTIAL = letter .. partialExtra
                    if BillboardUpdate then pcall(function() BillboardUpdate:FireServer(partialExtra) end) end
                    animateMobileKeys(extraCh)
                    fireTypeSound()
                    if CONFIG.DebugMode then log("⌨️ [Human] Kelebihan huruf '" .. extraCh .. "' di posisi " .. i) end

                    -- Jeda sadar kebablasan
                    task.wait(math.random(3, 7) * 0.1) -- 0.3s - 0.7s
                    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end

                    -- Hapus huruf extra (Backspace)
                    _G.SK_CURRENT_PARTIAL = letter .. partialNow
                    if BillboardUpdate then pcall(function() BillboardUpdate:FireServer(partialNow) end) end
                    fireTypeSound()
                    task.wait(0.15)
                    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
                    hasExtraChar = false
                    skipNormalType = true -- Huruf ini sudah ditulis, skip penulisan normal
                end

                if not skipNormalType then
                    -- === [EFEK 4] TYPO 1 HURUF + HAPUS ===
                    -- Salah pencet satu huruf, sadar, lalu hapus dan ganti
                    if hasTypo and i == typoPoint then
                        local chars = "abcdefghijklmnopqrstuvwxyz"
                        local correctChar = typedPart:sub(i, i)
                        local wrongChar
                        repeat
                            local rIdx = math.random(1, #chars)
                            wrongChar = chars:sub(rIdx, rIdx)
                        until wrongChar ~= correctChar -- Pastikan beda dari huruf yang benar

                        if BillboardUpdate then pcall(function() BillboardUpdate:FireServer(typedPart:sub(1, i-1) .. wrongChar) end) end
                        animateMobileKeys(wrongChar)
                        fireTypeSound()
                        if CONFIG.DebugMode then log("❌ [Human] Typo '" .. wrongChar .. "' seharusnya '" .. correctChar .. "'") end

                        task.wait(math.random(4, 8) * 0.1) -- Pause sadar typo
                        if not isRunning or _G.SK_BOT_ID ~= scriptId then return end

                        -- Hapus typo (visual delay)
                        if BillboardUpdate then pcall(function() BillboardUpdate:FireServer(typedPart:sub(1, i-1)) end) end
                        fireTypeSound()
                        task.wait(0.2)
                        if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
                        hasTypo = false
                    end

                    -- === KETIK HURUF NORMAL ===
                    local partialSuffix = string.sub(typedPart, 1, i)
                    _G.SK_CURRENT_PARTIAL = letter .. partialSuffix
                    animateMobileKeys(typedPart:sub(i,i))

                    -- [UPDATE] BillboardUpdate sekarang HANYA menerima suffix (apa yang sedang diketik)
                    if BillboardUpdate then
                        pcall(function() BillboardUpdate:FireServer(partialSuffix) end)
                    end
                    fireTypeSound()

                    -- Variasi Kecepatan Ketik (Ritme Manusia)
                    local charDelay = CONFIG.TypeCharDelay
                    if isHuman then
                        charDelay = charDelay * (math.random(9, 13) * 0.1)
                        if i % 3 == 0 then task.wait(math.random(1, 3) * 0.1) end
                        if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
                    end
                    task.wait(charDelay)
                    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
                end
            end
        else
            -- INSTANT MODE
            local finalSuffix = string.sub(word, #letter + 1)
            _G.SK_CURRENT_PARTIAL = word
            animateMobileKeys(word:sub(-1))

            -- [UPDATE] Hanya kirim suffix ke Billboard
            if BillboardUpdate then
                pcall(function() BillboardUpdate:FireServer(finalSuffix) end)
            end
            fireTypeSound()
        end
    end

    -- === KIRIM KE SERVER ===
    local suffixToSubmit = string.sub(word, #letter + 1):lower():gsub("[^a-z]", "")
    log("📤 Mengetik Suffix: " .. suffixToSubmit:upper() .. " (Full: " .. word:upper() .. ")")

    task.wait(0.3)
    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end

    -- [CRITICAL UPDATE] SubmitWord sekarang HANYA menerima suffix (kata setelah awalan)
    if SubmitWord then
        pcall(function() SubmitWord:FireServer(suffixToSubmit) end)
    end

    lastSubmittedWord = word

    -- === BERSIHKAN LAYAR & UNLOCK ===
    _G.SK_CURRENT_PARTIAL = ""
    animateMobileKeys("")
    _G.SK_ANSWER_LOCK = false
end

local isRetrying = false
local function triggerRetry(rejectedWord)
    if not CONFIG.AutoRetry or not CONFIG.Enabled or not isMyTurn or not matchActive or isRetrying then return end
    isRetrying = true

    local wordStr = tostring(rejectedWord or lastSubmittedWord or ""):lower()
    if wordStr ~= "" then
        gameUsedWords[wordStr] = true
        usedWords[wordStr] = true
        learnFromServer(wordStr)
        log("⚠️ Retry: Mengabaikan '" .. wordStr .. "' dan mencari kata lain...")
    end

    _G.SK_LAST_LETTER = ""
    _G.SK_ANSWER_LOCK = false

    local newWord = findWord(currentLetter, wordStr)
    if newWord then
        lastAnswer = newWord
        usedWords[newWord] = true
        log("🔄 Retry: " .. newWord)

        local isHuman = (CONFIG.InteractionMode == "Human")
        local retryDelay = isHuman and (math.random(15, 30) * 0.1) or (CONFIG.MinDelay * 0.5)

        task.wait(retryDelay)
        if isRunning and _G.SK_BOT_ID == scriptId and isMyTurn and matchActive then
            submitWordViaRemote(currentLetter, newWord, wordStr)
        end
    else
        notify("Retry Error", "Tidak ada kata alternatif!")
    end

    isRetrying = false
end

function onMyTurn(force)
    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
    -- Cek identitas script (Kunci utama agar hanya bot terbaru yang jalan)
    if _G.SK_BOT_ID ~= scriptId then return end

    -- Pengaman Global: Cek apakah sedang proses menjawab atau huruf sudah dijawab
    if not CONFIG.Enabled or not isMyTurn or currentLetter == "" then return end

    -- Jika force adalah true (Retry), abaikan pengecekan huruf terakhir
    if not force and (_G.SK_ANSWER_LOCK or currentLetter == _G.SK_LAST_LETTER) then return end

    _G.SK_ANSWER_LOCK = true
    _G.SK_LAST_LETTER = currentLetter

    local prefixLen = #currentLetter

    -- Cari kata pertama
    local firstWord = findWord(currentLetter)
    if not firstWord then
        notify("Error", "Tidak ada kata untuk '" .. string.upper(currentLetter) .. "'!")
        STATS.wordsFailed = STATS.wordsFailed + 1
        _G.SK_ANSWER_LOCK = false
        return
    end

    -- JIKA SEMI-AUTO: Siapkan kata SEGERA tanpa delay
    if CONFIG.SemiAuto then
        -- [UPDATE] Simpan SUFFIX saja untuk Ghost Mode agar sesuai protokol baru
        local suffixOnly = firstWord:sub(#currentLetter + 1):lower():gsub("[^a-z]", "")
        _G.SK_PENDING_WORD = suffixOnly

        _G.SK_ANSWER_LOCK = false -- Buka agar user bisa interaksi
        return
    end

    -- Delay awal (Hanya untuk Auto Bot)
    local delay = CONFIG.MinDelay
    if CONFIG.UseRandomDelay then
        delay = CONFIG.MinDelay + math.random() * (CONFIG.MaxDelay - CONFIG.MinDelay)
    end

    if delay > 0 then task.wait(delay) end
    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end

    -- EKSEKUSI PENGIRIMAN (Full Bot)
    if matchActive and isMyTurn then
        lastAnswer = firstWord
        if CONFIG.AvoidRepeat then usedWords[firstWord] = true end

        local sourceIcon = WORDS_SOURCE_DB[firstWord:lower()] and "🌐 [Cloud]" or "💾 [Local]"
        log(string.upper(currentLetter) .. " → " .. firstWord .. " " .. sourceIcon)
        submitWordViaRemote(currentLetter, firstWord)
    end

    -- Buka kunci untuk turn berikutnya
    _G.SK_ANSWER_LOCK = false
end



-- ╔════════════════════════════════════════════════════════════╗
-- ║     WIND UI IMPLEMENTATION                                ║
-- ╚════════════════════════════════════════════════════════════╝

Window = WindUI:CreateWindow({
    Title = "STARSHIP┃dsc.gg-starshipcore",
    Icon = "rbxassetid://85930777472774",
    IconSize = 45,
    Author = "Premium Edition | StarshipCore",
    Size = UDim2.fromOffset(750, 450),
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
                Title = "👤 Welcome, " .. LocalPlayer.DisplayName .. "!",
                Content = "Config: Premium • Version v7.0.2",
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
local roleColor = Color3.fromRGB(168, 85, 247)
if sessionData.Role == "OWNER" then
    roleColor = Color3.fromRGB(245, 158, 11)
elseif sessionData.Role == "VIP" or sessionData.Role == "MOBILE_VIP" or sessionData.Role == "MOBILE VIP" or sessionData.Role == "VIP Mobile" then
    roleColor = Color3.fromRGB(168, 85, 247)
end

local RoleTag = Window:Tag({
    Title = '<font size="11">' .. FormatRole(sessionData.Role) .. "</font>",
    Color = roleColor,
})

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

local MainTab = Window:Tab({ Title = "Utama", Icon = "house" })
local AccountTab = Window:Tab({ Title = "Account", Icon = "user-check" })
local AutoTab = Window:Tab({ Title = "Otomatis", Icon = "bot" })
local StatsTab = Window:Tab({ Title = "Statistik", Icon = "chart-line" })
local VisualTab = Window:Tab({ Title = "Visual", Icon = "eye" })
local TrollTab = Window:Tab({ Title = "Troll", Icon = "ghost" })
MainTab:Select()

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

-- --- ACCOUNT TAB CONTENT ---
AccountTab:Section({ Title = "Subscription & Profile", Desc = "Manage your Starship access" })
local vipParagraph = AccountTab:Paragraph({
    Title = "Subscription Status",
    Desc = GetVIPStatusDesc(),
    Icon = "star"
})

-- Update VIP timer every second
if vipExpiryTime then
    task.spawn(function()
        while isRunning and task.wait(1) do
            if _G.SK_BOT_ID ~= scriptId then break end
            local remaining = vipExpiryTime - os.time()
            if remaining <= 0 then
                pcall(function()
                    if vipParagraph then
                        vipParagraph:SetDesc('<font size="16">Role: '
                            .. FormatRole(sessionData.Role)
                            .. "\n"
                            .. "Time Remaining: Expired\n"
                            .. "Status: Inactive</font>")
                    end
                end)
                break
            else
                pcall(function()
                    if vipParagraph then
                        vipParagraph:SetDesc(GetVIPStatusDesc())
                    end
                end)
            end
        end
    end)
end

AccountTab:Paragraph({
    Title = "Profile Info",
    Desc = '<font size="16">Display Name: ' .. LocalPlayer.DisplayName .. "\n" ..
           "Username: @" .. LocalPlayer.Name .. "\n" ..
           "User ID: " .. LocalPlayer.UserId .. "\n" ..
           "Account Age: " .. LocalPlayer.AccountAge .. " days</font>",
    Icon = "user"
})

-- 1. Tab Kontrol
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
    Title = "Semi-Auto (Manual Type)",
    Desc = "Ketik Sembarang → Akan Selalu Benar",
    Value = CONFIG.SemiAuto,
    Callback = function(v)
        CONFIG.SemiAuto = v
        if v then
            notify("⌨️ Semi-Auto Aktif", "Kamu bisa ngetik ejekan, bot bakal benerin pas di Enter!")
        end
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
            end
        end)
    end
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

configSubTab:Toggle({
    Title = "High Score Mode",
    Desc = "Prioritaskan kata panjang untuk mendapatkan koin/hadiah maksimal",
    Value = CONFIG.HighScoreMode,
    Callback = function(v)
        CONFIG.HighScoreMode = v
        if v then
            notify("💰 High Score Active", "Bot akan mencari kata yang lebih panjang!")
        end
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

strategySubTab:Dropdown({
    Title = "Filter Kata",
    Desc = "Prioritas jenis kata",
    Values = {"Semua", "Umum", "Campuran"},
    Value = "Campuran",
    Callback = function(v) CONFIG.WordFilter = v; refreshUI() end
})

strategySubTab:Dropdown({
    Title = "Panjang Kata",
    Desc = "Strategi panjang kata",
    Values = {"Any", "Short", "Long"},
    Value = "Any",
    Callback = function(v) CONFIG.WordLengthMode = v; refreshUI() end
})

strategySubTab:Toggle({
    Title = "Hard Mode",
    Desc = "Prioritaskan akhiran huruf sulit (x, q, z, dll)",
    Value = CONFIG.HardMode,
    Callback = function(v) CONFIG.HardMode = v; refreshUI() end
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

-- --- STATS TAB (PREMIUM MULTISECTION) ---
local StatsMulti = StatsTab:MultiSection({
    Title = "Session Analytics",
    Icon = "bar-chart",
    Box = true,
    BoxBorder = true,
    Opened = true
})

local perfSubTab = StatsMulti:Tab({ Title = "Performance", Icon = "trending-up" })
local rewardSubTab = StatsMulti:Tab({ Title = "Rewards", Icon = "gift" })
local logSubTab = StatsMulti:Tab({ Title = "Logs", Icon = "list" })

-- 1. Performance Sub-Tab
perfSubTab:Section({ Title = "Statistik Sesi Ini" })
UIElements.StatsParagraph = perfSubTab:Paragraph({
    Title = "Performa & Index Hunter",
    Content = "Mencatat statistik..."
})

-- 2. Rewards Sub-Tab
rewardSubTab:Section({ Title = "Progress Hadiah (Reward Tracker)" })
UIElements.RewardParagraph = rewardSubTab:Paragraph({
    Title = "Status Hadiah",
    Content = "Menunggu data server..."
})

-- 3. Logs Sub-Tab
logSubTab:Section({ Title = "Log Aktivitas" })
UIElements.LogParagraph = logSubTab:Paragraph({
    Title = "Bot Log",
    Content = "Log dimulai..."
})

-- --- VISUAL TAB ---
VisualTab:Section({ Title = "Interface & Themes (Customization)" })

VisualTab:Toggle({
    Title = "Opponent HUD",
    Desc = "Tampilkan status & statistik lawan di atas kepala mereka",
    Value = CONFIG.ShowOverlays,
    Callback = function(v)
        CONFIG.ShowOverlays = v
        if not v then
            -- Cleanup opponent overlays immediately
            for _, p in ipairs(game.Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local char = p.Character
                    local overlay = char and char:FindFirstChild("SK_Overlay") or char and char.Head:FindFirstChild("SK_Overlay")
                    if overlay then overlay:Destroy() end
                end
            end
        end
    end
})

VisualTab:Toggle({
    Title = "Self Word Preview",
    Desc = "Tampilkan prediksi jawaban di atas kepalamu sendiri",
    Value = CONFIG.ShowSelfHUD,
    Callback = function(v) CONFIG.ShowSelfHUD = v end
})
VisualTab:Dropdown({
    Title = "Theme Switcher",
    Desc = "Ganti warna tema UI secara instan",
    Values = {"Dark", "Light", "Midnight", "Rose", "Emerald", "Plant", "Red", "Indigo", "Sky", "Violet", "Amber", "Crimson", "Rainbow"},
    Value = CONFIG.Theme,
    Callback = function(v)
        CONFIG.Theme = v
        pcall(function()
            WindUI:SetTheme(v)
        end)
    end
})

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
TrollTab:Section({ Title = "Prank & Troll Settings" })

TrollTab:Toggle({
    Title = "Troll Mode",
    Desc = "Kirim teks palsu ke billboard kepala, tapi kata asli ke server",
    Value = CONFIG.TrollMode,
    Callback = function(v)
        CONFIG.TrollMode = v
        if v then
            notify("👻 Troll Mode ON", "Pemain lain akan melihat teks palsumu!")
        end
    end
})

TrollTab:Input({
    Title = "Teks Troll",
    Desc = "Teks yang akan muncul di atas kepalamu saat giliran",
    Value = CONFIG.TrollText,
    Placeholder = "Ketik teks prank disini...",
    Callback = function(v)
        CONFIG.TrollText = v
        log("👻 Troll Text updated: " .. v)
    end
})

TrollTab:Section({ Title = "Preset Prank" })
local presets = {
    "Wlee kmu Cupu!",
    "Lagi mikir bentar...",
    "Cheat? Enggak kok :)",
    "Gampang banget sih",
    "Loading 99%...",
    "Error: Brain not found",
    "Zzzzzzz....",
    "Lagi nunggu apa hayo?"
}

for _, preset in ipairs(presets) do
    TrollTab:Button({
        Title = preset,
        Callback = function()
            CONFIG.TrollText = preset
            notify("👻 Preset Chosen", "Troll text set to: " .. preset)
        end
    })
end


-- === UI REFRESHER ===
function refreshUI()
    -- Wrap each part in its own pcall to prevent one failure from stopping all updates
    pcall(function()
        if UIElements.StatusParagraph then
            local turn = isMyTurn and "🟢 GILIRAN KAMU" or "⏳ Menunggu"
            local statusText = string.format(
                "Database: %s\nIndex Hunter: %d / %d (%d Baru)\nStatus: %s\nGiliran: %s\nHuruf: %s → %s",
                tostring(loadingStatus or "Memuat..."),
                tonumber(currentIndexCount or 0),
                tonumber(totalIndexPossible or 0),
                tonumber(sessionNewWordsDiscovered or 0),
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

    pcall(function()
        if UIElements.StatsParagraph then
            local statsText = string.format(
                "✅ Benar: %d\n❌ Gagal: %d\n🔄 Retry: %d\n🏆 Menang: %d / %d\n🔥 Streak: %d (Best: %d)\n👥 Pemain di Meja: %d\n💰 Total Koin: %d",
                tonumber(STATS.wordsCorrect or 0),
                tonumber(STATS.wordsFailed or 0),
                tonumber(STATS.retries or 0),
                tonumber(STATS.matchesWon or 0),
                tonumber(STATS.matchesPlayed or 0),
                tonumber(STATS.currentStreak or 0),
                tonumber(STATS.bestStreak or 0),
                tonumber(STATS.playersAtTable or 0),
                tonumber(STATS.totalCoinsEarned or 0)
            )
            local p = UIElements.StatsParagraph
            if p.SetDesc then p:SetDesc(statsText)
            elseif p.SetContent then p:SetContent(statsText)
            end
        end
    end)

    pcall(function()
        if UIElements.RewardParagraph and _G.SK_LAST_REWARD_DATA then
            local rewardText = ""
            local count = 0
            for i = 1, 100 do
                local id = "Reward" .. i
                local status = _G.SK_LAST_REWARD_DATA[id]

                if status == "AVAILABLE" then
                    rewardText = rewardText .. "✅ " .. id .. " : SIAP DIAMBIL\n"
                    count = count + 1
                elseif sessionClaimedRewards[id] then
                    rewardText = rewardText .. "💰 " .. id .. " : TELAH DIAMANKAN\n"
                    count = count + 1
                end
            end
            if count == 0 then rewardText = "Belum ada hadiah baru yang terdeteksi..." end

            if UIElements.RewardParagraph.SetDesc then
                UIElements.RewardParagraph:SetDesc(rewardText)
            elseif UIElements.RewardParagraph.SetContent then
                UIElements.RewardParagraph:SetContent(rewardText)
            end
        end
    end)
end

local botLogs = {}
UI_LOG_MSG = function(msg)
    table.insert(botLogs, 1, "[" .. os.date("%X") .. "] " .. msg)
    if #botLogs > 10 then table.remove(botLogs) end
    if UIElements.LogParagraph then
        UIElements.LogParagraph:SetDesc(table.concat(botLogs, "\n"))
    end
end

-- (UI Refresh is now handled by the main loop at the bottom)

local lastTrackedTable = nil -- State locker untuk tracker meja
local function scanGameState()
    if not isRunning or _G.SK_BOT_ID ~= scriptId then return end
    pcall(function()
        local pGui = LocalPlayer:WaitForChild("PlayerGui")
        local mainMatchUI = pGui:FindFirstChild("MatchUI")
        -- 1. Tracker Meja & Pemain (Metode Advanced: Radar + Seat Scan)
        if currentTable and currentTable ~= "" then
            if currentTable ~= lastTrackedTable then
                lastTrackedTable = currentTable
            end

            local playerCount = 0
            local tblModel = workspace:FindFirstChild("Tables") and workspace.Tables:FindFirstChild(currentTable)

            -- CARA A: Scan Kursi (Paling Akurat di Roblox)
            if tblModel then
                pcall(function()
                    for _, obj in ipairs(tblModel:GetDescendants()) do
                        if (obj:IsA("Seat") or obj:IsA("VehicleSeat")) and obj.Occupant then
                            playerCount = playerCount + 1
                        end
                    end
                end)
            end

            -- CARA B: Scan Radar Proximity (Jika kursi tidak terdeteksi)
            if playerCount <= 1 and tblModel then
                pcall(function()
                    local tablePos = tblModel:IsA("Model") and tblModel:GetModelCFrame().p or tblModel.PrimaryPart and tblModel.PrimaryPart.Position or tblModel:FindFirstChildWhichIsA("BasePart").Position
                    local count = 0
                    for _, p in ipairs(game.Players:GetPlayers()) do
                        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                            if (p.Character.HumanoidRootPart.Position - tablePos).Magnitude < 18 then
                                count = count + 1
                            end
                        end
                    end
                    playerCount = math.max(playerCount, count)
                end)
            end

            -- CARA C: Atribut Global (Fallback terakhir)
            if playerCount <= 1 then
                local count = 0
                for _, p in ipairs(game.Players:GetPlayers()) do
                    if p:GetAttribute("CurrentTable") == currentTable then
                        count = count + 1
                    end
                end
                playerCount = math.max(playerCount, count)
            end

            STATS.playersAtTable = playerCount
        else
            lastTrackedTable = nil
            STATS.playersAtTable = 0
        end

        -- 2. Deteksi apakah sedang dalam Match
        if currentTable or (mainMatchUI and mainMatchUI:IsA("ScreenGui") and mainMatchUI.Enabled) then
            if not matchActive then
                matchActive = true
            end
        else
            if matchActive then
                matchActive = false
                isMyTurn = false
            end
        end

        -- 2. Ambil Huruf (Failsafe jika remote terlewat)
        if matchActive and (currentLetter == "" or currentLetter == "-") then
            -- Cek di UI Utama Game
            if mainMatchUI and mainMatchUI:FindFirstChild("Main") and mainMatchUI.Main:FindFirstChild("Letter") then
                local uiLetter = mainMatchUI.Main.Letter.Text:match("%a+")
                if uiLetter then
                    currentLetter = uiLetter:lower()
                end
            end
        end

        -- 3. Deteksi Giliran (Jika remote terlewat, baca UI input)
        if matchActive then
            local bottomUI = pGui:FindFirstChild("BottomUI")
            if bottomUI and bottomUI:FindFirstChild("WordSubmit") and bottomUI.WordSubmit.Visible then
                if not isMyTurn then
                    isMyTurn = true
                    log("⚡ Deteksi Layar: Giliran kamu! Mencari jawaban...")
                    if CONFIG.AutoSubmit then task.spawn(onMyTurn) end
                end
            end
        end
    end)
end

-- === OVERLAY SYSTEM (OPPONENT HUD) ===
local currentPlayerTurn = nil
safeConnect(TurnCamera.OnClientEvent, function(targetPlayer)
    currentPlayerTurn = targetPlayer
end)

local function getPlayerStats(player)
    local stats = {wins = 0, losses = 0, winRate = 0}
    pcall(function()
        -- Try attributes
        stats.wins = player:GetAttribute("Wins") or player:GetAttribute("Victory") or 0
        stats.losses = player:GetAttribute("Losses") or player:GetAttribute("Defeats") or 0

        -- Try leaderstats
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local w = ls:FindFirstChild("Wins") or ls:FindFirstChild("Winning") or ls:FindFirstChild("Menang")
            local l = ls:FindFirstChild("Losses") or ls:FindFirstChild("Loss") or ls:FindFirstChild("Kalah")
            if w then stats.wins = w.Value end
            if l then stats.losses = l.Value end
        end

        -- Hitung Win Rate
        local totalMatch = stats.wins + stats.losses
        if totalMatch > 0 then
            stats.winRate = math.floor((stats.wins / totalMatch) * 100)
        end
    end)
    return stats
end

local function updateOverlays()
    -- Jika fitur mati, sedang tidak dalam match, atau ID script tidak valid, bersihkan HUD
    if not isRunning or _G.SK_BOT_ID ~= scriptId or not CONFIG.ShowOverlays or not matchActive then
        for _, player in ipairs(game.Players:GetPlayers()) do
            pcall(function()
                local char = player.Character
                local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
                local overlay = char and char:FindFirstChild("SK_Overlay") or head and head:FindFirstChild("SK_Overlay")
                if overlay then overlay:Destroy() end
            end)
        end
        return
    end

    for _, player in ipairs(game.Players:GetPlayers()) do
        pcall(function()
            -- Mode HUD: Lawan atau Diri Sendiri
            local isMe = (player == LocalPlayer)

            if isMe then
                if not CONFIG.ShowSelfHUD then
                    local char = player.Character
                    local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
                    local overlay = char and char:FindFirstChild("SK_Overlay") or head and head:FindFirstChild("SK_Overlay")
                    if overlay then overlay:Destroy() end
                    return
                end
            else
                -- Check if Opponent HUD is enabled
                if not CONFIG.ShowOverlays then
                    local char = player.Character
                    local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
                    local overlay = char and char:FindFirstChild("SK_Overlay") or head and head:FindFirstChild("SK_Overlay")
                    if overlay then overlay:Destroy() end
                    playerTypingStatus[player] = nil
                    return
                end

                local myTable = LocalPlayer:GetAttribute("CurrentTable")
                local targetTable = player:GetAttribute("CurrentTable")
                local inMyTable = (myTable and myTable ~= "")
                local inTargetTable = (targetTable and targetTable ~= "")

                if not inMyTable or not inTargetTable or targetTable ~= myTable then
                    local char = player.Character
                    local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
                    local overlay = char and char:FindFirstChild("SK_Overlay") or head and head:FindFirstChild("SK_Overlay")
                    if overlay then overlay:Destroy() end
                    playerTypingStatus[player] = nil
                    return
                end
            end

            local typingWord = playerTypingStatus[player] or ""
            local typingDisplay = (typingWord ~= "") and ("\n⌨️ Mengetik: " .. typingWord:upper()) or ""

            local char = player.Character
            if not char then return end
            local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
            if not head then return end

            local overlay = char:FindFirstChild("SK_Overlay") or head:FindFirstChild("SK_Overlay")
            if not overlay then
                overlay = Instance.new("BillboardGui")
                overlay.Name = "SK_Overlay"
                overlay.Size = UDim2.new(0, 250, 0, 100)
                overlay.AlwaysOnTop = true
                overlay.StudsOffset = Vector3.new(0, 4.5, 0) -- Lebih tinggi agar tidak tumpang tindih
                overlay.Adornee = head
                overlay.Parent = head -- Parent ke Head lebih aman

                local frame = Instance.new("Frame")
                frame.Size = UDim2.new(1, 0, 1, 0)
                frame.BackgroundTransparency = 1
                frame.Parent = overlay

                local content = Instance.new("TextLabel")
                content.Name = "Content"
                content.Size = UDim2.new(1, 0, 1, 0)
                content.BackgroundTransparency = 1
                content.TextColor3 = Color3.fromRGB(255, 255, 255)
                content.TextStrokeTransparency = 0.2
                content.Font = Enum.Font.GothamBold
                content.TextSize = 15
                content.RichText = true
                content.Parent = frame
            end

            local isPlaying = (player == currentPlayerTurn)
            local stats = getPlayerStats(player)
            local currentWord = player:GetAttribute("CurrentWord") or ""
            local mistakes = playerMistakes[player.UserId] or 0

            if isMe then
                text = string.format("<font color='#00FFFF'><b>[ PREDIKSI JAWABAN ]</b></font>\n")
                if isMyTurn then
                    text = text .. "<font color='#00FF7F'>⚡ GILIRAN KAMU!</font>\n"
                end

                local previewWord = (lastAnswer ~= "") and lastAnswer or "Mencari..."
                if currentLetter == "" or currentLetter == "-" then previewWord = "Menunggu Huruf..." end

                text = text .. "🎯 Target: <font color='#FFFF00'>" .. previewWord:upper() .. "</font>\n"
                text = text .. string.format("<font color='#FF4500'>⚠️ Mistake: %d</font>", mistakes)
            else
                text = string.format("<font color='#FFA500'><b>%s</b></font>\n", player.DisplayName or player.Name)
                if isPlaying then
                    text = text .. "<font color='#00FF7F'>[ 🎮 SEDANG MAIN ]</font>\n"
                else
                    text = text .. "<font color='#AAAAAA'>[ ⏳ MENUNGGU ]</font>\n"
                end

                if currentWord ~= "" then
                    text = text .. "✍️ Word: <font color='#FFFF00'>" .. currentWord .. "</font>\n"
                end

                text = text .. string.format("<font color='#FF4500'>⚠️ Mistake: %d</font>\n", mistakes)
                text = text .. string.format("<font color='#00BFFF'>🏆 W: %d</font> | <font color='#FF4500'>❌ L: %d</font> | <font color='#FFD700'>📊 %d%%</font>", stats.wins, stats.losses, stats.winRate)
            end

            local label = overlay.Frame.Content
            label.Text = text
        end)
    end
end

-- === STREAMING MODE HANDLER (OPTIMIZED WITH CACHE) ===
local nameLabelsCache = {}
local lastScanTime = 0

local function handleStreamingMode()
    if not isRunning or not CONFIG.StreamingMode then
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

    isJoiningTable = true -- Kunci proses

    -- Jeda awal agar tidak terlalu instan (terlihat lebih natural)
    task.wait(CONFIG.AutoJoinDelay)

    -- Re-check kondisi setelah wait
    if not isRunning or _G.SK_BOT_ID ~= scriptId or matchActive or LocalPlayer:GetAttribute("CurrentTable") then
        isJoiningTable = false
        return
    end

    local joinableTables = {}

    -- Helper untuk hitung pemain di meja tertentu
    local function getPlayerCount(tbl)
        local count = 0
        pcall(function()
            -- Metode Kursi
            for _, obj in ipairs(tbl:GetDescendants()) do
                if (obj:IsA("Seat") or obj:IsA("VehicleSeat")) and obj.Occupant then
                    count = count + 1
                end
            end
            -- Metode Attribute fallback (Jika kursi tidak terdeteksi)
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
        local state = tbl:GetAttribute("TableState")
        local isHidden = tableHiddenStatus[tbl.Name] -- [NEW] Cek dari sistem visibility game

        if (not state or state == "" or state == "Waiting") and not isHidden then
            local pCount = getPlayerCount(tbl)
            table.insert(joinableTables, {Instance = tbl, Players = pCount})
        end
    end

    if #joinableTables == 0 then return end

    -- PRIORITAS 1: Cari meja yang sudah ada 1 orang (biar langsung mulai)
    local prioritizedTable = nil
    for _, data in ipairs(joinableTables) do
        if data.Players == 1 then
            prioritizedTable = data.Instance
            break
        end
    end

    -- PRIORITAS 2: Jika tidak ada yang isi 1, cari yang paling ramai tapi belum penuh (max 4-6 biasanya)
    -- Tapi untuk request user, kita cukup: "Jika ada 1 orang, ambil itu. Jika tidak, ambil sembarang."
    local targetTable = prioritizedTable or joinableTables[1].Instance

    if targetTable then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")

        if root then
            -- [CRITICAL] Teleport ke meja agar server menerima request Join (Distance Check Bypass)
            local tablePos = targetTable:GetModelCFrame().p
            root.CFrame = CFrame.new(tablePos + Vector3.new(0, 3, 0))
            task.wait(0.2) -- Jeda tipis agar physics sinkron
        end

        JoinTable:FireServer(targetTable.Name)
        STATS.tablesJoined = (STATS.tablesJoined or 0) + 1
        local msg = prioritizedTable and ("Mencari lawan di " .. targetTable.Name) or ("Bergabung ke " .. targetTable.Name)
        notify("🪑 Auto Join", msg)
        log("🚀 Auto Join: " .. msg)

        -- Tunggu 5 detik untuk memastikan status terupdate, jika gagal buka kunci lagi
        task.wait(5)
    end

    isJoiningTable = false
end

local retryConn = safeConnect(UsedWordWarn.OnClientEvent, function(rejectedWord)
    -- CLEANUP: Jika saya bukan script terbaru, putus koneksi saya!
    if _G.SK_BOT_ID ~= scriptId then
        if retryConn then retryConn:Disconnect() end
        return
    end
    task.spawn(triggerRetry, rejectedWord)
end)


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

local matchConn = safeConnect(MatchUI.OnClientEvent, function(eventName, value)
    -- CLEANUP: Jika saya bukan script terbaru, putus koneksi saya!
    if _G.SK_BOT_ID ~= scriptId then
        if matchConn then matchConn:Disconnect() end
        return
    end

    if eventName == "ShowMatchUI" then
        matchActive, isMyTurn = true, false
        matchRoundCount = 0 -- Mulai dari 0 (akan jadi 1 saat StartTurn pertama)
        gameUsedWords = {}
        playerMistakes = {} -- Reset mistakes for new match
        STATS.matchesPlayed = STATS.matchesPlayed + 1
        _G.SK_LAST_LETTER = ""
    elseif eventName == "HideMatchUI" or eventName == "Eliminated" or eventName == "Victory" or eventName == "Winner" then
        matchActive, isMyTurn, currentLetter = false, false, ""
        matchRoundCount = 1
        playerMistakes = {}
        _G.SK_ANSWER_LOCK = false
        _G.SK_LAST_LETTER = ""
        if eventName == "Eliminated" then STATS.currentStreak = 0 end
        if eventName == "Victory" or eventName == "Winner" then STATS.matchesWon = STATS.matchesWon + 1 end
        if CONFIG.AutoJoinTable then task.delay(CONFIG.AutoJoinDelay, autoJoinTable) end
    elseif eventName == "UpdateServerLetter" then
        currentLetter = tostring(value)
        task.spawn(function()
            if currentLetter ~= "" and currentLetter ~= "-" then
                local pred = findWord(currentLetter, nil, nil, true)
                if pred then lastAnswer = pred end
                -- Update Auto Suggester
                if CONFIG.AutoSuggest and isMyTurn then
                    updateSuggestions()
                end
            end
        end)
    elseif eventName == "StartTurn" then
        isMyTurn = true
        matchRoundCount = matchRoundCount + 1
        if CONFIG.AutoSubmit then task.spawn(onMyTurn) end
        -- Update Auto Suggester saat giliran dimulai
        if CONFIG.AutoSuggest then
            task.spawn(updateSuggestions)
        end
    elseif eventName == "EndTurn" then
        isMyTurn = false
        _G.SK_ANSWER_LOCK = false
        _G.SK_LAST_LETTER = ""
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
        if value and value.userId then
            playerMistakes[value.userId] = value.count or ((playerMistakes[value.userId] or 0) + 1)
            task.spawn(updateOverlays)

            -- Jika saya yang melakukan kesalahan, picu AutoRetry
            if value.userId == LocalPlayer.UserId and CONFIG.Enabled and CONFIG.AutoRetry and isMyTurn then
                log("⚠ Kata Salah/Sudah Digunakan (Mistake)! Mencoba lagi...")
                STATS.retries = STATS.retries + 1
                task.spawn(triggerRetry)
            end
        end
    end
end)

-- === USED WORD WARNING (RETRY TRIGGER) ===
if UsedWordWarn then
    safeConnect(UsedWordWarn.OnClientEvent, function(word)
        if CONFIG.Enabled and CONFIG.AutoRetry and isMyTurn then
            log("⚠ Kata '" .. tostring(word or "Unknown") .. "' Sudah Digunakan! Mencoba lagi...")
            STATS.retries = STATS.retries + 1
            task.spawn(triggerRetry, word)
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

    if data.Count and CONFIG.DebugMode then
        print("[SK-Bot] 📡 Index Data Received: " .. data.Count .. " / " .. (data.Total or "?"))
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

    -- TRICK: Pancing server menggunakan jalur RESMI (RequestWordIndex)
    task.wait(1.2)
    if RequestWordIndex then
        pcall(function() RequestWordIndex:FireServer() end)
    elseif BillboardUpdate then
        BillboardUpdate:FireServer("")
    end

    if MatchUI then pcall(function() MatchUI:FireServer("GetIndex") end) end
end)


-- Main Loop: Terus scan kondisi game dan update UI & Overlay
task.spawn(function()
    while isRunning do
        -- Pengecekan versi dipindah ke loop monitor di atas agar tidak bentrok
        pcall(function()
            scanGameState()
            refreshUI()
            updateOverlays()
            handleStreamingMode()
        end)
        task.wait(1)
    end
end)

-- === FORCE STARTUP ===

-- === FORCE STARTUP ===
_G.SK_BOT_ID = scriptId
isRunning = true
