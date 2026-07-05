--[[
    SambungKata Auto-Player (Auto-Discovery Edition)
    -------------------------------------------------
    Cara Pake:
      1. Join game Sambung Kata
      2. Execute script ini
      3. Script auto-scan ReplicatedStorage cari remote dengan keyword
         (sambung/kata/submit/word/dll). Liat console buat top 5 kandidat.
      4. Kalau auto-pick tepat → langsung toggle "Auto Play" di GUI
      5. Kalau salah → buka console, override manual:
            getgenv().SambungKata.SetRemote(N)   -- N = nomor kandidat (1-5)

    Anti-detect: gak pake __namecall hook (anti-cheat detect itu).
                 Cuma scan Instances + fire remote langsung.

    Tested executor: Wave / Solara / Swift / Fluxus / dll
                     (yg punya HttpGet doang udah cukup)
--]]

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local CONFIG = {
    -- WAJIB: token kamu (arg #2 saat fire submit remote).
    -- Cara dapet: pake RSpy → submit kata 1x manual → liat arg #2.
    -- Token ini persistent per-session, bisa di-reuse banyak kali.
    -- Kalau kamu join server baru / restart game, token bisa beda.
    SUBMIT_TOKEN   = "6204312197.2816544580273",

    -- Wordlist URL (PRIORITAS — pool besar ~250k kata).
    -- Anti-kick safety udah aktif: bot auto-pause kalau Mistake ≥ 3 (avoid Error 267).
    -- Blacklist self-learning otomatis filter kata polluted seiring waktu.
    WORDLIST_URLS = {
        -- ⭐ PRIORITY: curated khusus sambung kata (verssache) — no loanword junk
        "https://raw.githubusercontent.com/verssache/sambung-kata/main/words.json",
        "https://raw.githubusercontent.com/geovedi/indonesian-wordlist/master/00-indonesian-wordlist.lst",
        "https://raw.githubusercontent.com/Wikidepia/indonesian_datasets/master/dictionary/wordlist/data/wordlist.txt",
        "https://raw.githubusercontent.com/damzaky/kumpulan-kata-bahasa-indonesia-KBBI/master/list_1.0.0.txt",
        "https://raw.githubusercontent.com/damzaky/kumpulan-kata-bahasa-indonesia-KBBI/master/list_0.5.1.txt",
        "https://raw.githubusercontent.com/damzaky/kumpulan-kata-bahasa-indonesia-KBBI/master/legacy/indonesian-words.txt",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/dictionary_JSON.json",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-1-10000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-10001-30000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-30001-90000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-90001-100000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-100001-105000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-105001-110000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-110001-160000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-160001-210000.sql",
        "https://raw.githubusercontent.com/dyazincahya/KBBI-SQL-database/main/data-raw/kbbi-210001-219861.sql",
    },

    -- Delay sebelum mulai ngetik (turn timer sambung kata pendek, jangan kelamaan)
    MIN_DELAY      = 1.5,   -- delay min
    MAX_DELAY      = 3.0,   -- delay max
    PREFER_SHORT   = true,  -- pilih kata pendek
    MIN_WORD_LEN   = 4,
    MAX_WORD_LEN   = 6,
    TYPE_MIN_MS    = 180,
    TYPE_MAX_MS    = 380,
    TYPO_CHANCE    = 0.04,
    HESITATE_CHANCE = 0.08,
    BACKSPACE_FIX_CHANCE = 0.05,  -- chance per-char ngetik salah → hapus → benerin (5% = ~33% per kata 8 huruf)

    -- INTERACTION MODE: "bot" = perfect, gak ada typo/hesitate/long-think/skip/break
    --                   "human" = full anti-pattern (typo, hesitate, break, dll)
    -- Speed (cepat/lambat ngetik) tetap dikontrol oleh PRESET (speedrun/casual/stealth).
    INTERACTION_MODE = "human",

    -- ANTI-PATTERN: bikin bot keliatan kayak manusia (pendek, gak ngeganggu)
    SKIP_TURN_CHANCE = 0,           -- disabled
    LONG_THINK_CHANCE = 0.15,
    MAX_CONSECUTIVE_SUBMITS = 15,   -- naikin biar jarang break
    BREAK_DURATION_MIN = 0.5,
    BREAK_DURATION_MAX = 1.2,

    -- SABOTAGE: pilih kata yang ending dgn huruf langka (Q/X/Z/F/V/Y)
    -- biar opponent kena giliran susah sambung
    SABOTAGE_MODE  = true,

    -- AUTO VOTE: pas voting phase, otomatis fire GameModeVote remote.
    -- Pilihan: "off" | "Santai" | "Normal" | "Brutal"
    AUTO_VOTE_MODE = "off",

    -- AUTO CLAIM: tiap reward AVAILABLE (dari milestone Index) auto-claim
    AUTO_CLAIM_REWARDS = true,
    -- PRIORITIZE NEW: bot prefer kata yang BELUM di-collect ke index (grow rewards)
    PRIORITIZE_NEW_WORDS = true,
    -- ALWAYS NEW ONLY: SKIP TOTAL kata yang udah di-collect (force new only).
    -- Risk: kalo prefix susah & semua kata udah ke-collect → bot gak nemu jawaban.
    ALWAYS_NEW_ONLY = false,

    -- AUTO COIN RAIN: auto-collect koin pas event CoinRain.
    -- DISABLED — masih experimental, takut ke-detect player lain (rebutan visible).
    -- Listener tetep nyala (logging event), tapi gak auto-walk. Manual collect saja.
    -- Set ke true kalo mau aktifin lagi. Code & API (ForceCoinRain) tetep tersedia.
    AUTO_COIN_RAIN = false,

    -- INPUT_MODE: cara bot ngetik kata.
    --   "suggest"  = HUD suggester only, user ketik manual (0% kick)
    --   "kbinput"  = VIM mouse click ke TextBox + SendKeyEvent per char (natural simulation, recommended)
    --   "click"    = VIM mouse click on virtual keyboard buttons (cuma kalau ada on-screen keyboard)
    --   "remote"   = direct FireServer (DETECTABLE oleh Adonis — KICK!)
    INPUT_MODE     = "kbinput",

    -- (legacy) STEALTH_MODE: deprecated, INPUT_MODE replace ini
    STEALTH_MODE   = true,
    DEBUG          = false,  -- PRODUCTION: silence semua log() output
    -- Skip kata yang mengandung 2+ konsonan beruntun di awal (kayak "kniso", "stress", dll)
    -- Atau kata yang punya cluster konsonan jarang di Indonesia
    FILTER_RARE    = true,
}

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------
local Players       = game:GetService("Players")
local HttpService   = game:GetService("HttpService")
local RunService    = game:GetService("RunService")
local UserInputSvc  = game:GetService("UserInputService")
local LP            = Players.LocalPlayer
local PlayerGui     = LP:WaitForChild("PlayerGui")

-- Reset shutdown flag dari run sebelumnya (re-execute clean state).
_G.__SK_DEAD = false

-- ════════════════════ PRODUCTION SILENCE ════════════════════
-- CONFIG.DEBUG = false udah silence sebagian besar log().
-- Sisa print/warn langsung di code → kita cuma silence yg dari script kita aja
-- (warn2 wrapper). JANGAN override global print/warn — bisa break library
-- (WindUI/loader) yg expect output bekerja normal.
local PRODUCTION_SILENT = true

-- ─── Account Status Helpers (ported dari SambungKata-lama / MobileUI) ───
local function FormatRole(role)
    if not role then return "USER" end
    return string.upper(tostring(role):gsub("_", " "))
end

local function ParseVIPExpiry(durationStr)
    if not durationStr or durationStr == "Lifetime" or durationStr == "lifetime" then
        return nil
    end
    local days = tonumber(tostring(durationStr):match("(%d+)%s*day"))
    local hours = tonumber(tostring(durationStr):match("(%d+)%s*hour"))
    if days then return os.time() + (days * 86400) end
    if hours then return os.time() + (hours * 3600) end
    return nil
end

local function FormatTimeRemaining(seconds)
    if seconds <= 0 then return "Expired" end
    local days  = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins  = math.floor((seconds % 3600) / 60)
    local secs  = math.floor(seconds % 60)
    if days  > 0 then return string.format("%dd %dh %dm %ds", days, hours, mins, secs) end
    if hours > 0 then return string.format("%dh %dm %ds", hours, mins, secs) end
    if mins  > 0 then return string.format("%dm %ds", mins, secs) end
    return string.format("%ds", secs)
end

-- Session data (default Lifetime VIP — bisa di-override loader external lewat getgenv().StarshipSession)
local sessionData = (getgenv and getgenv().StarshipSession) or _G.sessionData or {
    Role     = "VIP Mobile",
    Duration = "Lifetime",
    UserId   = LP.UserId,
    Username = LP.Name,
}
_G.sessionData = sessionData

local function log(...)
    -- Silent kalau script udah di-shutdown (state.alive = false).
    -- state mungkin belum exist saat log pertama kali dipanggil — defensive check.
    if _G.__SK_DEAD then return end
    if CONFIG.DEBUG then print("[SambungKata]", ...) end
end

-- Helper: return 0 untuk anti-pattern chance kalau lagi BOT mode (perfect, gak ada error)
-- Di HUMAN mode, return value asli dari CONFIG.
local function humanChance(key)
    if CONFIG.INTERACTION_MODE == "bot" then return 0 end
    return CONFIG[key] or 0
end

-- AUTO-ADAPT MODE: detect game mode dari prefix length (= prefix yg ditunjuk WordServer).
-- Santai = prefix 1 huruf, no X/Q/F. Normal = prefix 1-3. Brutal = prefix 2-5 + waktu cepat.
-- Bot adapt: kalo Brutal → speed up delay+typing (turn timer pendek).
local detectedMode = "Normal"           -- "Santai" | "Normal" | "Brutal"
local modeFromVote = false              -- true = mode di-set via GameModeVote.Result (authoritative)
-- Mode rules per game:
--   Santai: prefix 1 huruf, exclude X/Q/F (server reject ending itu)
--   Normal: prefix 1-3 huruf
--   Brutal: prefix 2-5 huruf, turn timer cepet
-- Prefix length saja tidak cukup distinguish Santai/Normal/Brutal yg overlap (e.g. prefix=2 bisa Normal/Brutal).
-- Authoritative source: GameModeVote.Result event yg fire pas voting selesai (handler di section 6.6).
-- Heuristic ini cuma fallback kalau Result event belum di-receive.
local function detectMode(prefix)
    -- Kalau mode udah di-set via vote result, JANGAN override pake heuristic.
    if modeFromVote then return detectedMode end
    if not prefix or #prefix == 0 then return detectedMode end
    local plen = #prefix
    local firstChar = prefix:sub(1,1):lower()
    local newMode

    if plen >= 4 then
        -- Definitely Brutal (Santai max 1, Normal max 3, Brutal max 5)
        newMode = "Brutal"
    elseif plen == 1 then
        -- Santai atau Normal. X/Q/F → pasti Normal (Santai exclude itu).
        if firstChar == "x" or firstChar == "q" or firstChar == "f" then
            newMode = "Normal"
        elseif CONFIG.AUTO_VOTE_MODE == "Santai" then
            newMode = "Santai"
        elseif detectedMode == "Brutal" then
            newMode = "Normal"  -- transition keluar dari Brutal
        else
            newMode = detectedMode  -- keep current (sticky)
        end
    else
        -- plen 2-3: ambiguous (Normal 1-3 vs Brutal 2-5).
        -- Pakai AUTO_VOTE_MODE preference + sticky behavior:
        if CONFIG.AUTO_VOTE_MODE == "Brutal" then
            newMode = "Brutal"
        elseif CONFIG.AUTO_VOTE_MODE == "Normal" then
            newMode = "Normal"
        elseif detectedMode == "Brutal" or detectedMode == "Normal" then
            newMode = detectedMode  -- sticky kalau udah ke-set sebelumnya
        else
            -- Tiebreaker: prefix len 3 → lean Brutal (rare di Normal), len 2 → Normal
            newMode = (plen == 3) and "Brutal" or "Normal"
        end
    end

    if newMode ~= detectedMode then
        detectedMode = newMode
        if CONFIG.DEBUG then
            print(("[SambungKata] 🎮 Mode heuristic: %s (prefix='%s' len=%d)"):format(newMode, prefix, plen))
        end
    end
    return newMode
end

-- Get effective typing/delay based on detected mode.
-- Brutal: force fastest (turn timer pendek, kalo gak ngebut → kalah).
-- Normal/Santai: pakai value preset (CONFIG asli).
local function effectiveDelay()
    if detectedMode == "Brutal" then
        return 0.3, 0.8  -- min, max sec
    end
    return CONFIG.MIN_DELAY, CONFIG.MAX_DELAY
end
local function effectiveTypeMs()
    if detectedMode == "Brutal" then
        return 50, 120  -- min, max ms
    end
    return CONFIG.TYPE_MIN_MS, CONFIG.TYPE_MAX_MS
end

local function warn2(...)
    if PRODUCTION_SILENT then return end  -- silenced di production
    warn("[SambungKata]", ...)
end

------------------------------------------------------------
-- 1. LOAD WORDLIST
------------------------------------------------------------
-- words[letter] = { "apel", "anggur", ... }
local words = {}
local wordExists = {}  -- set buat dedupe (multi-source merge bisa duplicate)
local totalWords = 0

-- prefixCounts[suffix] = jumlah kata di pool yang START dengan string itu.
-- Dipake buat sabotage scoring multi-letter (Normal/Brutal mode).
-- Misal "xy" = 2 kata mulai dari "xy" → suffix langka → great sabotage.
local prefixCounts = {}
local function buildPrefixCounts()
    prefixCounts = {}
    local cnt = 0
    for _, pool in pairs(words) do
        for _, w in ipairs(pool) do
            local maxN = math.min(5, #w)
            for n = 1, maxN do
                local p = w:sub(1, n):lower()
                prefixCounts[p] = (prefixCounts[p] or 0) + 1
            end
            cnt = cnt + 1
        end
    end
    if CONFIG.DEBUG then
        print("[SambungKata] 🧮 Built prefix counts dari", cnt, "kata")
    end
end

-- Bahasa Indonesia jarang banget pake cluster konsonan beruntun di posisi awal.
-- Kata kayak "kniso", "stres" (loanword) sering gak ada di kamus game.
local function hasRareConsonantCluster(w)
    -- Cek 2 huruf awal: kalau dua-duanya konsonan, kemungkinan kata aneh/loanword
    local c1 = w:sub(1,1)
    local c2 = w:sub(2,2)
    local vowels = "aeiou"
    if not vowels:find(c1, 1, true) and not vowels:find(c2, 1, true) then
        -- exception: "ny", "ng" valid
        local pair = c1 .. c2
        if pair == "ny" or pair == "ng" then return false end
        return true  -- konsonan ganda di awal = jarang/asing
    end
    return false
end

-- Cek juga 3+ konsonan beruntun di mana saja (jarang di Indonesia)
local function hasTripleConsonant(w)
    local vowels = "aeiou"
    local count = 0
    for i = 1, #w do
        local c = w:sub(i, i)
        if vowels:find(c, 1, true) then
            count = 0
        else
            count = count + 1
            if count >= 3 then return true end
        end
    end
    return false
end

-- Indonesia native jarang punya double vowel (aa, ee, ii, oo, uu)
-- "keerlingan", "boomerang", dll adalah loanword yang sering rejected game
local function hasDoubleVowel(w)
    return w:find("aa") or w:find("ee") or w:find("ii")
        or w:find("oo") or w:find("uu") or false
end

local function indexWord(w)
    w = w:lower():gsub("%s+", "")
    if #w < CONFIG.MIN_WORD_LEN or #w > CONFIG.MAX_WORD_LEN then return end
    if not w:match("^[a-z]+$") then return end
    if CONFIG.FILTER_RARE then
        if hasRareConsonantCluster(w) then return end
        if hasTripleConsonant(w) then return end
        if hasDoubleVowel(w) then return end
    end
    -- DEDUPE: skip kalau kata udah pernah di-load (multi-source bisa duplicate)
    if wordExists[w] then return end
    wordExists[w] = true
    local first = w:sub(1, 1)
    words[first] = words[first] or {}
    table.insert(words[first], w)
    totalWords = totalWords + 1
end

local function loadWordlistFromURL(url)
    -- coba beberapa method karena executor beda-beda implementasinya
    local body
    local attempts = {
        function() return game:HttpGet(url, true) end,
        function() return game:HttpGetAsync(url) end,
        function() return (request or http_request or syn and syn.request)({Url = url, Method = "GET"}).Body end,
    }
    for _, fn in ipairs(attempts) do
        local ok, res = pcall(fn)
        if ok and type(res) == "string" and #res >= 1000 then
            body = res
            break
        end
    end
    if type(body) ~= "string" then return false end

    local addedBefore = totalWords
    local processed = 0
    local function yieldCheck()
        processed = processed + 1
        if processed % 1000 == 0 then task.wait() end
    end

    -- Auto-detect JSON
    local isJSON = body:match("^%s*[%{%[]")
    if isJSON then
        local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
        if ok then
            local function extract(node)
                if type(node) == "string" then
                    yieldCheck()
                    indexWord(node)
                elseif type(node) == "table" then
                    for _, v in pairs(node) do extract(v) end
                end
            end
            extract(data)
            log("📦 JSON loaded:", totalWords - addedBefore, "kata baru dari", url:match("[^/]+$"))
            return true
        end
    end

    -- Auto-detect SQL (INSERT INTO pattern)
    if body:find("INSERT INTO", 1, true) then
        for val in body:gmatch("%('%s*([^']-)%s*'%s*,") do
            yieldCheck()
            indexWord(val)
        end
        log("🗄 SQL loaded:", totalWords - addedBefore, "kata baru dari", url:match("[^/]+$"))
        return true
    end

    -- Fallback: line-based (TXT/LST)
    for line in body:gmatch("[^\r\n]+") do
        yieldCheck()
        indexWord(line)
    end
    log("📄 TXT loaded:", totalWords - addedBefore, "kata baru dari", url:match("[^/]+$"))
    return true
end

-- CURATED KATA_DB: ~1300 kata umum Indonesia, hand-picked dari script lama yang proven kerja.
-- Kualitas > kuantitas: lebih kecil tapi 99% valid di kamus game.
local KATA_DB = {
    a={"apel","awan","angin","api","air","alam","anak","ayam","asap","akar","angsa","arus","arah","adik","abang","ampun","andal","asli","awas","acara","agung","ajaib","akrab","alat","amal","antar","arif","aktif","alur","amis","atap","awal","aksi","ambil","angkat","antik","asing","aset","awam","aksara","album","akhir","akur","alamat","alasan","aliran","amanah","amarah","ambang","arsip","artis","aturan"},
    b={"buku","batu","bulan","bumi","burung","bola","bunga","besar","baik","baru","biru","berani","bintang","bosan","buah","bakso","bambu","banjir","batas","bayar","beban","bedak","belut","benang","berita","besok","bocor","boleh","bubur","bulat","buruk","busuk","bebas","bekal","benci","beras","berkah","betul","bijak","bocah","boneka","bukit","bumbu","bunyi","badak","balok","bangku","barang","benda","bersih"},
    c={"cinta","cuaca","cahaya","cantik","cepat","cukup","cari","catat","cemas","cerdas","cerah","cerita","cicak","coklat","contoh","cubit","cuka","culik","cumi","cangkir","capek","celana","cemara","cendol","cermin","cincin","cocok","cukur","curang","cabai","cakar","cambuk","capung","catur","celah","cipta","cium","cuci","cacat","cagar","campur","canda","candu","canggih","cetak","citra","copet"},
    d={"danau","daun","desa","dunia","dekat","dalam","daging","dahan","damai","datang","debu","deras","dingin","domba","dosen","duit","duku","duri","dusta","dahulu","dampak","dapat","dasar","datar","dendam","depan","detik","diam","didik","dinas","dodol","dongeng","dorong","duduk","dukun","duren","daerah","daftar","darat","daya","debat","delima","delta","demam","desain","dewasa","dialog"},
    e={"elang","emas","enak","emosi","embun","ekor","empat","era","esok","elastis","elok","empuk","endap","energi","entah","erosi","eskrim","etika","ekonomi","ekstra","elegan","efek","efektif","ego","ejaan","elemen","elite","ember","enam","enggan","enzim","epidemi","episode","erupsi","esai","estetika","etis","euforia","evaluasi","evolusi"},
    f={"foto","fakta","fokus","favorit","festival","final","flora","fungsi","fajar","fantasi","fauna","figur","film","fisik","fondasi","formal","fosil","futsal","fasilitas","fenomena","fitur","formula","forum","fabel","fakultas","farmasi","fatal","fiksi","filter","finansial","firasat","firman","fobia","forensik","format"},
    g={"gajah","gunung","garam","gitar","gelap","gembira","guru","gagal","galak","garang","garuk","gatal","gedung","gelang","gema","gempa","gerak","getah","gila","goreng","gosip","gulai","guntur","gadis","galang","ganda","ganggu","garasi","gaul","gawat","gelombang","genap","gerbang","gigit","gabus","gadai","gagasan","gairah","gaji","galeri","gambar","gampang","ganti","gantung","garpu","gaya"},
    h={"hari","hujan","hutan","hitam","hijau","habis","hadiah","halus","hantu","harap","harga","hasil","hebat","hemat","hewan","hidup","hilang","hitung","hobi","hormat","hotel","hubung","hukum","huruf","harus","hidung","hadir","hafal","haji","hakim","halal","halaman","hamil","hampir","hancur","hangat","hapus","harta","harum","hati","haus","hayat","heboh","helm","hening","heran","herbal","hero"},
    i={"ikan","indah","istana","ikat","ilmu","intan","ide","imbang","ingin","iris","isap","istri","iblis","idola","iklan","impian","inap","induk","ingat","injak","inovasi","insaf","intai","iseng","itik","iuran","ibu","identitas","ikut","ilalang","ilustrasi","imam","impor","imun","imut","indera","individu","industri","infeksi","inflasi","inisiatif","input","inspeksi","indeks"},
    j={"jalan","jeruk","jatuh","jarak","jelas","jendela","jernih","jiwa","jual","jubah","judi","jujur","jumpa","jurus","jahat","jamin","jamu","jangkar","jawab","jemput","jerat","jerit","jabat","jadwal","jaga","jagat","jago","jagung","jahit","jajan","jaksa","jalur","jambu","janda","janji","jantung","jaring","jarum","jati","jauh","jawa","jaya","jebak"},
    k={"kucing","kuda","kapal","kunci","kain","kabar","kacang","kadal","kaget","kalung","kamar","kamus","kanan","kapas","kapur","karang","kartu","kasur","kayu","kecil","kedai","kejar","kelam","kemah","kenal","keran","keris","kilat","kipas","kolam","kompas","kotak","kulit","kuman","kumis","kupas","kursi","kabut","kagum","kakak","kalah","kabel","kaca","kacau","kafe","kail","kaji","kambing","kantor"},
    l={"laut","langit","lebar","lemah","lihat","lucu","ladang","lalat","lampu","lapar","lapis","lari","latih","lauk","lawan","layar","lebah","lemari","lemon","lengkap","lepas","lewat","liar","lilin","limbah","lincah","lomba","loyal","lunak","lurus","luka","lumut","lacak","laci","lagu","lahar","lahan","lahir","lain","laku","lama","lamar","lambat","lancar","langkah","langsung","lantai","lapor","laras"},
    m={"makan","minum","mata","malam","mobil","meja","merah","masak","maju","malu","mandi","manis","marah","masuk","mati","menang","merdu","mimpi","miskin","muda","mulut","murid","musik","musuh","macan","madu","main","majelis","makna","maksimal","maksud","mampu","mana","mangga","mangkok","mantan","manusia","maritim","martabat","masa","masalah","masyarakat","materi","medali","media","medis"},
    n={"nama","nasi","nafas","naga","naik","nakal","namun","nanti","nasib","negara","nelayan","nenek","neraka","ngantuk","niat","nilai","nonton","nomor","nujum","nyala","nyaman","nyanyi","nyata","nyawa","nyeri","nabati","noda","nominal","norma","notaris","novel","nuansa","nuklir","nutrisi","napas","narkoba","narasi","nasional","natural","navigasi","negatif","negeri","nekat","netral","niaga","nikah","nikmat","nista"},
    o={"orang","obat","olahraga","ombak","onak","opini","otak","otot","obeng","objek","obral","obrol","oksigen","oknum","olah","olimpiade","omong","omzet","oper","operasi","operator","opname","opsi","optik","optimis","oral","orbit","order","organ","organik","orientasi","orkestra","ormas","ornamen","otonom","otopsi","output","oval","ovulasi","oksidasi"},
    p={"pagi","pasir","panas","pohon","pasar","pintu","pulang","padi","pagar","pahat","pajak","pakai","paksa","paling","paman","panen","panggang","pangkat","pantai","papan","parah","parkir","paruh","pasang","pasti","pasukan","patuh","payung","pecah","pedas","pegang","pelan","pelari","pilih","pindah","pinjam","piring","pisang","potong","pukul","pulau","punya","pusat","putih","putri"},
    q={"quran","qasar","qadar","qamat","qanun","qurban"},
    r={"rumah","raja","rambut","ramai","rantai","rapat","rasa","rata","rawat","raya","rebah","rebut","reda","redup","rejeki","rekam","relawan","remang","renang","rendah","rendam","renovasi","rentang","repot","resah","resmi","restu","retak","ribu","ribut","ringan","raba","racun","radang","radio","ragu","rahang","rahasia","rahim","rahmat","rakyat","ramah","ramalan","rambu","rampok","ramuan","ranjang","ranjau","ransel"},
    s={"siang","satu","sepatu","sungai","surat","sabar","sajak","sakit","salah","sama","sampah","sampai","sandal","sandar","sangat","sanggup","santan","santun","sapa","sapu","saran","sarapan","sarung","saudara","sayang","sayap","sayur","sebab","sebar","sebut","sedang","sedih","sedikit","sehat","sejak","selamat","selasa","selatan","selesai","selimut","selokan","seluruh","semangat","sembilan","semoga","sempat","senang","sendiri"},
    t={"tangan","teman","timur","tanah","tanam","tanda","tangga","tangis","tanya","tari","taruh","tawar","tebal","tegak","tegas","tekad","telur","tembak","tenang","tengah","tepat","terang","terjun","tertib","tetap","tiang","tidur","tikus","timba","tinta","tirai","tolong","tongkat","topeng","tugas","tuhan","tujuh","tulang","tulus","tumbuh","tumis","tumpah","tunduk","tuntas","turun","tusuk","tabu"},
    u={"ular","udara","ubah","ucap","udang","ujian","ukir","ukur","ulang","ulat","umpan","umpat","undur","unggas","unik","unjuk","untung","upah","upaya","urai","usaha","usai","usap","utama","utang","utuh","utusan","ubur","uji","ukuran","ulah","ulet","ulung","umbi","umum","undang","unduh","ungkap","ungu","universitas","unsur","untuk","urus","urut","usang","usia","usir","usul","utara"},
    v={"vaksin","variasi","viola","vokal","volume","vital","visi","visa","vulkan","valid","validasi","vanili","vapor","vegetasi","vendor","ventilasi","verbal","verifikasi","vertikal","veteran","veto","video","vila","viral","virtual","virus","vitamin","vokalis","volt","vonis"},
    w={"waktu","warna","wajah","wajar","walet","wangi","warga","warung","wasit","wawasan","wilayah","wisata","wujud","wudhu","wahyu","walau","wali","wanita","waras","wartawan","wadah","waduk","wafat","wahana","wajib","wakaf","wakil","warisan","warta","watak","wawancara","wayang"},
    x={"xenon","xilofon","xerox"},
    y={"yakin","yang","yatim","yoga","yuran","yayasan","yodium","yunani","yunior","yurisdiksi"},
    z={"zaman","zebra","zona","zodiak","zaitun","zamrud","ziarah","zalim","zenit","zigzag","zirah","zombi","zuhur","zuriat"},
}

local function buildIndex()
    -- PRIMARY: URL wordlist (pool besar ~250k kata).
    local successCount = 0
    if #CONFIG.WORDLIST_URLS > 0 then
        log("Memuat "..#CONFIG.WORDLIST_URLS.." URL wordlist (TXT/JSON/SQL)...")
        for i, url in ipairs(CONFIG.WORDLIST_URLS) do
            log(("[%d/%d] Loading: %s"):format(i, #CONFIG.WORDLIST_URLS, url:match("[^/]+$")))
            if loadWordlistFromURL(url) then successCount = successCount + 1
            else warn2("Gagal load:", url) end
            task.wait(0.1)
        end
        log(("✅ Loaded %d/%d URL sources, total: %d kata"):format(successCount, #CONFIG.WORDLIST_URLS, totalWords))
    end

    -- FALLBACK: KATA_DB curated kalau URL gagal/sedikit.
    if successCount == 0 or totalWords < 500 then
        warn2("URL gagal/sedikit — fallback ke KATA_DB curated")
        for _, list in pairs(KATA_DB) do
            for _, w in ipairs(list) do
                indexWord(w)
            end
        end
        log("KATA_DB loaded, total now:", totalWords, "kata")
    end

    -- Build prefix counts buat sabotage multi-letter scoring (Normal/Brutal mode)
    buildPrefixCounts()

    -- Reminder safety
    log("🛡️ Auto-pause DISABLED — bot lanjut main sampe kalah natural")
end

task.spawn(buildIndex)

------------------------------------------------------------
-- 2. USED-WORDS TRACKER & BLACKLIST
------------------------------------------------------------
-- Forward-declare index state biar pickWord (di bawah) bisa reference.
-- Diisi nanti di section 2.5 lewat OnClientEvent listener.
local indexState = { count = 0, total = 0, allWords = {} }
local function isCollected(w)
    return indexState.allWords[(w or ""):lower()] == true
end
local usedWords = {}            -- kata yang udah dipake match ini
-- Blacklist DIPISAH per mode (Santai/Normal/Brutal). Game mungkin punya
-- dict sedikit berbeda per mode (e.g. Santai lebih lenient). Kata salah
-- di Normal belum tentu salah di Santai.
local wordBlacklist = { Santai = {}, Normal = {}, Brutal = {} }
local BLACKLIST_FILE = "SambungKata_Blacklist.txt"
local lastSubmittedWord = nil
local lastSubmittedAt = 0
local mistakeValueAtSubmit = 0  -- value Mistake attribute saat submit lastSubmittedWord
local modeAtSubmit = "Normal"   -- mode game saat submit (buat blacklist scope yg benar)
local gotUsedWordWarn = false  -- flag: UsedWordWarn fired setelah submit terakhir
local sessionMistakes = 0       -- count invalid Mistake (info only, gak auto-pause)
local needsClearOnNextType = false  -- true = pas next typeWord, hapus dulu sisa Mistake
local MAX_SESSION_MISTAKES = math.huge  -- DISABLED — bot lanjut main sampe kalah natural

-- Load blacklist dari file. Format sectioned:
--   [Santai]
--   word1
--   word2
--   [Normal]
--   ...
-- Backward-compat: kalau file lama (no sections), all diparse ke "Normal"
pcall(function()
    if isfile and isfile(BLACKLIST_FILE) then
        local content = readfile(BLACKLIST_FILE)
        local currentMode = "Normal"  -- default kalo file lama (no header)
        local hasAnySection = content:find("%[") ~= nil
        if not hasAnySection then
            -- Migrate file lama: semua ke "Normal" sebagai safe default
            for w in content:gmatch("[^\r\n]+") do
                local trimmed = w:match("^%s*(.-)%s*$")
                if trimmed ~= "" then
                    wordBlacklist.Normal[trimmed:lower()] = true
                end
            end
        else
            for line in content:gmatch("[^\r\n]+") do
                local section = line:match("^%[(%w+)%]$")
                if section then
                    currentMode = section
                    if not wordBlacklist[currentMode] then
                        wordBlacklist[currentMode] = {}
                    end
                else
                    local trimmed = line:match("^%s*(.-)%s*$")
                    if trimmed ~= "" and not trimmed:match("^#") then
                        wordBlacklist[currentMode][trimmed:lower()] = true
                    end
                end
            end
        end
    end
end)

local function saveBlacklist()
    pcall(function()
        if not writefile then return end
        local lines = {}
        for _, mode in ipairs({"Santai", "Normal", "Brutal"}) do
            local set = wordBlacklist[mode]
            if set and next(set) then
                table.insert(lines, "["..mode.."]")
                local words = {}
                for w, _ in pairs(set) do table.insert(words, w) end
                table.sort(words)
                for _, w in ipairs(words) do table.insert(lines, w) end
                table.insert(lines, "")  -- blank line between sections
            end
        end
        writefile(BLACKLIST_FILE, table.concat(lines, "\n"))
    end)
end

-- Cek apakah kata di-blacklist DI MODE tertentu (default = current detectedMode).
local function isBlacklisted(w, mode)
    if type(w) ~= "string" then return false end
    mode = mode or detectedMode
    local set = wordBlacklist[mode]
    return set and set[w:lower()] == true
end

local function blacklistWord(w, mode)
    if type(w) ~= "string" then return end
    mode = mode or detectedMode
    local lw = w:lower()
    if not wordBlacklist[mode] then wordBlacklist[mode] = {} end
    if not wordBlacklist[mode][lw] then
        wordBlacklist[mode][lw] = true
        saveBlacklist()
        warn(("[SambungKata] 🚫 Blacklisted [%s] (rejected by game): %s"):format(mode, lw))
    end
end

local function markUsed(w)
    if type(w) ~= "string" then return end
    usedWords[w:lower()] = true
end

-- Log prefix yg bot gak nemu kata-nya ke file (buat manual review & tambah kosakata)
-- Format: SambungKata_missing_prefixes.txt → "prefix | count | last_seen_iso"
local MISSING_PREFIX_FILE = "SambungKata_missing_prefixes.txt"
local missingPrefixes = {}  -- {[prefix] = count}

-- Load existing missing list (biar count akumulatif antar-session)
pcall(function()
    if isfile and isfile(MISSING_PREFIX_FILE) then
        local content = readfile(MISSING_PREFIX_FILE)
        for line in content:gmatch("[^\r\n]+") do
            local pfx, cnt = line:match("^([^|]+)%s*|%s*(%d+)")
            if pfx then
                pfx = pfx:gsub("^%s+", ""):gsub("%s+$", "")
                missingPrefixes[pfx] = tonumber(cnt) or 1
            end
        end
    end
end)

local function logMissingPrefix(prefix)
    if type(prefix) ~= "string" or #prefix == 0 then return end
    local pfx = prefix:lower()
    missingPrefixes[pfx] = (missingPrefixes[pfx] or 0) + 1
    -- Persist ke file (sorted by count desc biar prefix paling sering muncul di atas)
    pcall(function()
        if not writefile then return end
        local arr = {}
        for p, c in pairs(missingPrefixes) do
            table.insert(arr, {prefix = p, count = c})
        end
        table.sort(arr, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.prefix < b.prefix
        end)
        local lines = {"# Prefix yg bot gak nemu kata-nya. Format: prefix | count | last_seen"}
        local now = os.date("%Y-%m-%d %H:%M:%S")
        for _, entry in ipairs(arr) do
            table.insert(lines, ("%s | %d | %s"):format(entry.prefix, entry.count, now))
        end
        writefile(MISSING_PREFIX_FILE, table.concat(lines, "\n"))
    end)
end

-- prefix bisa 1-3 huruf (e.g., "k", "za", "pri")
-- Match kata yang dimulai dengan prefix-nya
local function pickWord(prefix)
    prefix = prefix:lower()
    -- Pool ke-index by huruf pertama, jadi kita cari di pool[prefix[1]]
    local firstChar = prefix:sub(1,1)
    local pool = words[firstChar]
    if not pool or #pool == 0 then
        warn2("Gak ada kata mulai dari prefix:", prefix)
        logMissingPrefix(prefix)
        return nil
    end

    -- Filter pool: kata yang prefix-nya match
    local filtered = {}
    if #prefix == 1 then
        filtered = pool  -- semua match
    else
        for _, w in ipairs(pool) do
            if w:sub(1, #prefix) == prefix then
                table.insert(filtered, w)
            end
        end
        if #filtered == 0 then
            warn2("Gak ada kata yang mulai dengan prefix:", prefix)
            logMissingPrefix(prefix)
            return nil
        end
    end

    -- SABOTAGE STRATEGY: prefer kata yang ending dgn huruf langka di Indo
    -- (Q,X,Z,F,V,Y) — bikin opponent susah sambung.
    -- IMPORTANT: di mode SANTAI, X/Q/F gak boleh jadi prefix → kalau bot ending
    -- X/Q/F, server REJECT kata kita (Mistake). Jadi exclude X/Q/F di Santai.
    local LAST_LETTER_RARITY = {
        q=100, x=100, z=95, f=80, v=80, y=60,
        w=40, c=30, h=25, j=20, o=15, e=15, u=15,
        n=10, m=10, k=8, t=8, p=8, b=8, d=8, g=8,
        l=5, r=5, s=5, i=3, a=2,
    }
    -- Forbidden ending letters per mode (kalau ending huruf ini → server reject)
    local forbiddenEnding = {}
    if detectedMode == "Santai" then
        forbiddenEnding = {x = true, q = true, f = true}
    end

    -- SABOTAGE SCORING (mode-aware, multi-letter):
    -- Santai (1-letter prefix): score base on letter rarity terakhir.
    -- Normal (1-3 huruf): score base on rarity suffix 3 huruf — makin sedikit
    --   kata yg start dgn suffix itu, makin tinggi score (opponent stuck).
    -- Brutal (2-5 huruf): score base on suffix 5 huruf — paling brutal,
    --   ending kata seperti "...syah" gampang, "...lzif" mustahil dilanjut.
    local function lastLetterScore(w)
        local last = w:sub(-1):lower()
        if forbiddenEnding[last] then return -1 end

        local suffixLen
        if detectedMode == "Brutal" then
            suffixLen = 5
        elseif detectedMode == "Normal" then
            suffixLen = 3
        else
            -- Santai or unknown: pake huruf rarity klasik
            return LAST_LETTER_RARITY[last] or 5
        end

        -- Multi-letter scoring: rarer suffix combo = higher score
        suffixLen = math.min(suffixLen, #w)
        local suffix = w:sub(-suffixLen):lower()
        local count = prefixCounts[suffix] or 0
        -- count rendah = sabotage tinggi. Pakai 10000/(count+1) biar score
        -- besar (1+ kata = 5000, 5 kata = 1666, 100 kata = 99, 1000 kata = 9.9).
        local rarityScore = 10000 / (count + 1)
        -- Tambah letter rarity (kalo ending huruf jarang seperti Z/Y → bonus)
        local letterBonus = LAST_LETTER_RARITY[last] or 5
        return rarityScore + letterBonus
    end

    -- Sort indices by strategy
    local indices = {}
    for i = 1, #filtered do indices[i] = i end

    -- Sort priority hierarchy:
    --   1. Uncollected words (PRIORITIZE_NEW_WORDS) — biar grow index
    --   2. Sabotage rarity (kalau SABOTAGE_MODE)
    --   3. Word length (PREFER_SHORT)
    if CONFIG.SABOTAGE_MODE then
        table.sort(indices, function(a, b)
            local wa, wb = filtered[a], filtered[b]
            if CONFIG.PRIORITIZE_NEW_WORDS then
                local ca, cb = isCollected(wa), isCollected(wb)
                if ca ~= cb then return not ca end  -- uncollected first
            end
            local sa, sb = lastLetterScore(wa), lastLetterScore(wb)
            if sa ~= sb then return sa > sb end
            return #wa < #wb
        end)
    elseif CONFIG.PREFER_SHORT then
        table.sort(indices, function(a, b)
            local wa, wb = filtered[a], filtered[b]
            if CONFIG.PRIORITIZE_NEW_WORDS then
                local ca, cb = isCollected(wa), isCollected(wb)
                if ca ~= cb then return not ca end
            end
            return #wa < #wb
        end)
    else
        for i = #indices, 2, -1 do
            local j = math.random(1, i)
            indices[i], indices[j] = indices[j], indices[i]
        end
        -- Even in random mode, push uncollected to top
        if CONFIG.PRIORITIZE_NEW_WORDS then
            table.sort(indices, function(a, b)
                local ca, cb = isCollected(filtered[a]), isCollected(filtered[b])
                if ca ~= cb then return not ca end
                return false
            end)
        end
    end

    local skippedCollected = 0
    for _, idx in ipairs(indices) do
        local w = filtered[idx]
        if not usedWords[w] and not isBlacklisted(w) then
            local lastChar = w:sub(-1):lower()
            -- Hard skip ending yg forbidden di mode current
            if forbiddenEnding[lastChar] then
                -- skip — di Santai, X/Q/F endings = server reject
            elseif CONFIG.ALWAYS_NEW_ONLY and isCollected(w) then
                -- SKIP TOTAL: kata ini udah ke-collect, mode ALWAYS_NEW_ONLY aktif
                skippedCollected = skippedCollected + 1
            else
                if CONFIG.SABOTAGE_MODE then
                    log(("🎯 [sabotage] '%s' ending '%s' (rarity:%d)"):format(w, lastChar:upper(), lastLetterScore(w)))
                end
                if CONFIG.ALWAYS_NEW_ONLY and not isCollected(w) then
                    log(("✨ [new-only] Pick FRESH word: '%s'"):format(w))
                end
                return w
            end
        end
    end
    if CONFIG.ALWAYS_NEW_ONLY and skippedCollected > 0 then
        warn2(("⚠️ [new-only] %d kata di-skip (udah collected). Gak nemu kata fresh untuk prefix '%s'"):format(skippedCollected, prefix))
    end
    return nil
end

-- pickTopWords: return TOP N candidates dengan urutan & filter sama persis spt pickWord.
-- Dipake oleh Suggester UI buat tampilin 10 kata terbaik.
-- Mengabaikan ALWAYS_NEW_ONLY supaya user dapat semua opsi (bot main filter sendiri).
local function pickTopWords(prefix, n)
    n = n or 10
    if not prefix or prefix == "" then return {} end
    prefix = prefix:lower()
    local firstChar = prefix:sub(1,1)
    local pool = words[firstChar]
    if not pool or #pool == 0 then return {} end

    local filtered = {}
    if #prefix == 1 then
        for _, w in ipairs(pool) do table.insert(filtered, w) end
    else
        for _, w in ipairs(pool) do
            if w:sub(1, #prefix) == prefix then
                table.insert(filtered, w)
            end
        end
    end
    if #filtered == 0 then return {} end

    local LAST_LETTER_RARITY = {
        q=100, x=100, z=95, f=80, v=80, y=60,
        w=40, c=30, h=25, j=20, o=15, e=15, u=15,
        n=10, m=10, k=8, t=8, p=8, b=8, d=8, g=8,
        l=5, r=5, s=5, i=3, a=2,
    }
    local forbiddenEnding = {}
    if detectedMode == "Santai" then
        forbiddenEnding = {x = true, q = true, f = true}
    end
    local function scoreOf(w)
        local last = w:sub(-1):lower()
        if forbiddenEnding[last] then return -1 end
        local suffixLen
        if detectedMode == "Brutal" then suffixLen = 5
        elseif detectedMode == "Normal" then suffixLen = 3
        else return LAST_LETTER_RARITY[last] or 5 end
        suffixLen = math.min(suffixLen, #w)
        local suffix = w:sub(-suffixLen):lower()
        local count = prefixCounts[suffix] or 0
        return 10000 / (count + 1) + (LAST_LETTER_RARITY[last] or 5)
    end

    table.sort(filtered, function(a, b)
        if CONFIG.SABOTAGE_MODE then
            local sa, sb = scoreOf(a), scoreOf(b)
            if sa ~= sb then return sa > sb end
        end
        return #a < #b
    end)

    local results = {}
    for _, w in ipairs(filtered) do
        if #results >= n then break end
        if not usedWords[w] and not isBlacklisted(w)
           and not forbiddenEnding[w:sub(-1):lower()] then
            table.insert(results, {
                word = w,
                score = scoreOf(w),
                collected = isCollected(w),
                lastChar = w:sub(-1):upper(),
            })
        end
    end
    return results
end

------------------------------------------------------------
-- 2.5 WORD INDEX TRACKER + AUTO-CLAIM REWARDS
------------------------------------------------------------
-- Game ini track kata-kata yang udah lo collect (Index). Tiap kata baru = +1 ke Count.
-- Reward unlock pas hit milestone Count tertentu. Kita:
--   1. Listen UpdateWordIndex untuk maintain set `collectedWords` (kata yg udah punya)
--   2. pickWord prefer kata YANG BELUM ke-collect (biar tiap submit = +1 index)
--   3. Listen IndexRewardStatus → auto-claim yang AVAILABLE
-- (indexState & isCollected udah forward-declared di section 2)
local availableRewards = {}  -- set: [rewardName] = true

task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:WaitForChild("Remotes", 15)
    if not remotes then
        warn2("[index] Remotes folder gak ketemu, skip index tracker")
        return
    end

    local updateRem  = remotes:WaitForChild("UpdateWordIndex",  10)
    local requestRem = remotes:WaitForChild("RequestWordIndex", 10)
    local statusRem  = remotes:WaitForChild("IndexRewardStatus", 10)
    local claimRem   = remotes:WaitForChild("ClaimIndexReward",  10)

    -- Listener: server kirim full state atau single new word
    if updateRem then
        updateRem.OnClientEvent:Connect(function(data)
            if typeof(data) ~= "table" then return end
            if typeof(data.Count) == "number" then indexState.count = data.Count end
            if typeof(data.Total) == "number" then indexState.total = data.Total end
            if typeof(data.AllWords) == "table" then
                -- Full sync
                indexState.allWords = {}
                for w, _ in pairs(data.AllWords) do
                    if type(w) == "string" then
                        indexState.allWords[w:lower()] = true
                    end
                end
                log(("📚 [index] Loaded %d/%d collected words"):format(indexState.count, indexState.total))
            elseif typeof(data.NewWord) == "string" and #data.NewWord > 0 then
                indexState.allWords[data.NewWord:lower()] = true
                log(("📚 [index] +1 '%s' (%d/%d)"):format(data.NewWord, indexState.count, indexState.total))
            end
        end)
    end

    -- Listener: status reward (LOCKED/AVAILABLE/CLAIMED) + auto-claim
    if statusRem then
        statusRem.OnClientEvent:Connect(function(statuses, moneyValue)
            if typeof(statuses) ~= "table" then return end
            for name, status in pairs(statuses) do
                if status == "AVAILABLE" then
                    availableRewards[name] = true
                else
                    availableRewards[name] = nil
                end
            end
            -- Auto-claim semua AVAILABLE (delay antar claim biar respect server cooldown 1s)
            if claimRem and CONFIG.AUTO_CLAIM_REWARDS then
                task.spawn(function()
                    for name in pairs(availableRewards) do
                        task.wait(1.3 + math.random() * 0.4)
                        pcall(function() claimRem:FireServer(name) end)
                        log("🎁 [auto-claim] Claimed:", name)
                        availableRewards[name] = nil  -- mark, server bakal push CLAIMED status
                    end
                end)
            end
        end)
    end

    -- Initial fetch state
    if requestRem then
        task.wait(1)
        pcall(function() requestRem:FireServer() end)
        log("📨 [index] Requested initial index from server")
    end
end)

------------------------------------------------------------
-- 3. AUTO-DISCOVERY: HOOK __namecall
------------------------------------------------------------
local detected = {
    remote     = nil,    -- Instance
    method     = nil,    -- "FireServer" / "InvokeServer"
    argIndex   = 1,      -- index argumen tempat kata
    argFormat  = "raw",  -- "raw" (string langsung) / "table" (dalam tabel)
    tableKey   = nil,    -- kalo argFormat="table", key-nya apa
}

-- FORWARD DECLARATION: state diisi nanti di Section 6.
-- Lua butuh local di-declare sebelum closure bisa nge-reference sebagai upvalue.
-- Tanpa ini, closure capture _G.state (nil) → sniffer early-return!
local state = {
    alive   = true,
    enabled = false,
    busy    = false,
    consecutiveSubmits = 0,  -- counter untuk anti-pattern (mandatory break)
    lastLetter = nil,
    lastFireAt = 0,
}

-- Live game state — diisi dari MatchUI events
local gameState = {
    isMyTurn = false,        -- updated dari LP attribute "IsTurn"
    currentLetter = nil,     -- updated dari UpdateServerLetter event
    matchSeed = nil,         -- updated dari MatchSeed event
}

local function tryDetectFromArgs(remote, method, args)
    -- heuristik: cari arg yang berupa string huruf-only panjang 2..30
    for i, v in ipairs(args) do
        if type(v) == "string" and #v >= 2 and #v <= 30
           and v:match("^[%a]+$") then
            detected.remote    = remote
            detected.method    = method
            detected.argIndex  = i
            detected.argFormat = "raw"
            log("Detect remote:", remote:GetFullName(), "| method:", method, "| argIndex:", i, "| sample:", v)
            markUsed(v)
            return true
        elseif type(v) == "table" then
            for k, vv in pairs(v) do
                if type(vv) == "string" and #vv >= 2 and #vv <= 30
                   and vv:match("^[%a]+$") then
                    detected.remote    = remote
                    detected.method    = method
                    detected.argIndex  = i
                    detected.argFormat = "table"
                    detected.tableKey  = k
                    log("Detect remote:", remote:GetFullName(), "| method:", method, "| arg["..i.."]["..tostring(k).."] sample:", vv)
                    markUsed(vv)
                    return true
                end
            end
        end
    end
    return false
end

------------------------------------------------------------
-- 3. RESOLVE SUBMIT REMOTE + TOKEN SNIFFER
------------------------------------------------------------
-- Path obfuscation game BERUBAH per-update.
-- Cara cari path baru:
--   1. Pake RSpy (BlatantSpy) → pause bot → manual submit 1 kata
--   2. Liat remote yang baru fire dgn 2 string args (suffix + token)
--   3. Update SUBMIT_PATH di bawah
-- Kalau gak diupdate, auto-detection akan handle (best effort).
local SUBMIT_PATH = {
    "Remotes",
    "N9KlLyimVNlmE3x8Fcd1",      -- folder obfuscated (cek di RSpy kalau berubah)
    "MzeB3NxuMXOp8RkJIolY",      -- SubmitWord remote (low call count, kirim suffix+token)
}

-- Pattern token: angka_panjang.angka_panjang (contoh "6204312197.2816544580273")
-- HARUS minimal 5 digit di kiri titik (biar gak match floats kayak "0.85", "1.04")
local TOKEN_PATTERN = "^[%d][%d][%d][%d][%d]+%.[%d]+$"

-- Live token yang udah di-sniff dari server
local liveToken = nil
local lastTokenAt = 0
local lastTokenSource = nil

local function resolveSubmitRemote()
    local cur = game:GetService("ReplicatedStorage")
    for _, seg in ipairs(SUBMIT_PATH) do
        cur = cur:FindFirstChild(seg)
        if not cur then return nil end
    end
    return cur
end

task.spawn(function()
    -- Hardcoded path mungkin udah out-of-date karena game ngubah obfuscation.
    -- Coba dulu, kalau gak nemu — auto-detection (priority scanner) bakal handle.
    local r = resolveSubmitRemote()
    if r then
        detected.remote    = r
        detected.method    = "FireServer"
        detected.argIndex  = 1
        detected.argFormat = "raw"
        log("✓ Submit remote resolved (hardcoded path):", r:GetFullName())
    else
        log("ℹ️ Hardcoded path gak nemu — fallback ke auto-detection (normal kalo game update)")
    end
end)

-- TOKEN SNIFFER: passive listener
-- Sniff dari berbagai sumber: OnClientEvent, Attributes, ValueObjects
local SNIFFER_DEBUG = true  -- set true buat liat SEMUA event (debug)

local function checkValueForToken(v, source)
    if type(v) ~= "string" then return end
    if v:match(TOKEN_PATTERN) and #v >= 15 then
        liveToken = v
        lastTokenAt = tick()
        lastTokenSource = source
        log("✓ Token sniffed:", v, "from:", source)
    end
end

local function deepScan(t, source, depth)
    depth = depth or 0
    if depth > 3 then return end
    if type(t) == "string" then
        checkValueForToken(t, source)
    elseif type(t) == "table" then
        for k, v in pairs(t) do
            deepScan(v, source .. "." .. tostring(k), depth + 1)
        end
    end
end

-- Pattern token RELAXED: HARUS punya format X.Y dengan digit panjang di kedua sisi
local function isLikelyToken(s)
    if type(s) ~= "string" then return false end
    if #s < 15 or #s > 40 then return false end
    if s:find("[a-zA-Z]") then return false end
    -- Harus ada `.` dengan minimal 5 digit di kiri DAN 5 digit di kanan
    local left, right = s:match("^([%d]+)%.([%d]+)$")
    if not left or not right then return false end
    if #left < 5 or #right < 5 then return false end
    return true
end

-- Override checkValueForToken with relaxed logic for MatchUI specifically
local function checkValueForTokenRelaxed(v, source, isPriority)
    if type(v) ~= "string" then return end
    -- Strict pattern (XXX.YYY) — high confidence
    if v:match(TOKEN_PATTERN) and #v >= 15 then
        liveToken = v
        lastTokenAt = tick()
        lastTokenSource = source
        log("✓ Token sniffed (strict):", v, "from:", source)
        return
    end
    -- Relaxed pattern, only if from priority source (MatchUI/obf folder)
    if isPriority and isLikelyToken(v) then
        liveToken = v
        lastTokenAt = tick()
        lastTokenSource = source
        log("✓ Token sniffed (relaxed):", v, "from:", source)
    end
end

-- Track event activity per remote — buat identify MatchUI vs SubmitWord
-- MatchUI = sering fire (StartTurn, UpdateTimer, Mistake)
-- SubmitWord = jarang/pernah fire (cuma client→server)
local remoteActivity = {}  -- [remote] = {count = N, hasMatchUIEvent = bool}

local function setupTokenSniffer()
    local rs = game:GetService("ReplicatedStorage")

    -- Identify "priority" remotes — yang ada di obfuscated folder atau parent panjang
    -- Token paling mungkin datang dari sini
    local function isPriorityRemote(r)
        local p = r.Parent
        if p and #p.Name >= 15 and p ~= rs and p.Name ~= "Remotes" then
            return true  -- inside obfuscated folder
        end
        return false
    end

    -- Auto-pick SubmitWord remote: di obfuscated folder yang sama dgn MatchUI,
    -- tapi BUKAN MatchUI itu sendiri (yang sering fire StartTurn/Timer/Mistake).
    local function autoDetectSubmitRemote()
        -- Cari remote yang udah confirmed MatchUI (fire StartTurn/Mistake event)
        local matchUIRemote = nil
        for r, info in pairs(remoteActivity) do
            if info.hasMatchUIEvent then
                matchUIRemote = r
                break
            end
        end
        if not matchUIRemote then return nil end

        -- Cari sibling remote (parent yang sama) yang BUKAN MatchUI
        local folder = matchUIRemote.Parent
        if not folder then return nil end
        for _, sibling in ipairs(folder:GetChildren()) do
            if (sibling:IsA("RemoteEvent") or sibling:IsA("UnreliableRemoteEvent"))
               and sibling ~= matchUIRemote then
                local info = remoteActivity[sibling]
                -- Sibling yang gak pernah fire MatchUI event = SubmitWord candidate
                if not info or not info.hasMatchUIEvent then
                    log("🎯 Auto-detect SubmitWord:", sibling:GetFullName())
                    log("   (sibling dari MatchUI:", matchUIRemote:GetFullName()..")")
                    return sibling
                end
            end
        end
        return nil
    end

    -- Periodic check — kalau hardcoded path fail, pake auto-detect
    task.spawn(function()
        while state and state.alive do
            task.wait(2)
            if not detected.remote then
                local r = autoDetectSubmitRemote()
                if r then
                    detected.remote    = r
                    detected.method    = "FireServer"
                    detected.argIndex  = 1
                    detected.argFormat = "raw"
                    log("✅ SubmitWord auto-resolved via heuristic")
                    break
                end
            else
                -- Already resolved, exit loop
                break
            end
        end
    end)

    -- (1) Listen ke SEMUA RemoteEvent + UnreliableRemoteEvent OnClientEvent
    local listenedRE = 0
    local listenedURE = 0
    local priorityCount = 0
    for _, r in ipairs(rs:GetDescendants()) do
        local isRE = r:IsA("RemoteEvent")
        local isURE = r:IsA("UnreliableRemoteEvent")
        if isRE or isURE then
            local priority = isPriorityRemote(r)
            if priority then priorityCount = priorityCount + 1 end
            local prefix = isURE and "URE" or "RE"
            pcall(function()
                r.OnClientEvent:Connect(function(...)
                    if not state or not state.alive then return end
                    local args = {...}
                    if SNIFFER_DEBUG then
                        local preview = {}
                        for i, v in ipairs(args) do
                            local s = tostring(v)
                            if #s > 40 then s = s:sub(1, 40) .. "..." end
                            preview[i] = type(v) .. ":" .. s
                        end
                        local tag = priority and ("["..prefix.."-RX⭐]") or ("["..prefix.."-RX]")
                        log(tag, r.Name, "args:", table.concat(preview, " | "))
                    end
                    -- Apply relaxed check ke SEMUA (bukan cuma priority)
                    for i, v in ipairs(args) do
                        checkValueForTokenRelaxed(v, r:GetFullName().." arg["..i.."]", true)
                        if type(v) == "table" then
                            deepScan(v, r:GetFullName() .. " arg["..i.."]")
                        end
                    end

                    -- TRACK ACTIVITY — buat auto-detect SubmitWord vs MatchUI
                    if priority then
                        local info = remoteActivity[r] or {count = 0, hasMatchUIEvent = false}
                        info.count = info.count + 1
                        if type(args[1]) == "string" then
                            local ev = args[1]
                            if ev == "StartTurn" or ev == "Mistake" or ev == "UpdateTimer"
                               or ev == "MatchSeed" or ev == "UpdateServerLetter" then
                                info.hasMatchUIEvent = true
                            end
                        end
                        remoteActivity[r] = info
                    end

                    -- EVENT-SPECIFIC HANDLERS untuk MatchUI-style remote
                    -- Format: :FireClient(eventName, value, extra)
                    if priority and type(args[1]) == "string" then
                        local eventName = args[1]
                        local value = args[2]
                        local extra = args[3]

                        if eventName == "StartTurn" then
                            -- arg[3] = TOKEN! arg[2] = isMyTurn (probably bool)
                            if type(extra) == "string" and #extra >= 5 then
                                liveToken = extra
                                lastTokenAt = tick()
                                lastTokenSource = "StartTurn arg[3]"
                                log("🔑 [StartTurn] Token captured:", extra)
                            end
                            -- arg[2] could indicate whose turn — let attribute handle this
                        elseif eventName == "UpdateServerLetter" then
                            -- table = encoded letter indices (XOR/shuffle pake MatchSeed).
                            -- Gak bisa di-decode tanpa reverse Luraph. Pake UI scan aja.
                            if type(value) == "table" then
                                local nums = {}
                                for _, v in pairs(value) do
                                    if type(v) == "number" then table.insert(nums, v) end
                                end
                                if #nums > 0 then
                                    log("📝 [UpdateServerLetter] encoded: {"..table.concat(nums,",").."} — pake UI scan")
                                else
                                    log("📝 [UpdateServerLetter] kosong (giliran lawan)")
                                end
                            end
                        elseif eventName == "MatchSeed" then
                            if type(value) == "number" then
                                gameState.matchSeed = value
                                log("🎲 [MatchSeed]", value)
                            end
                        end
                    end

                    -- HANDLE non-priority remote: PlayerCorrect
                    -- Saat lawan submit kata yg valid, mark sebagai used biar gak duplicate
                    if r.Name == "PlayerCorrect" then
                        for _, v in ipairs(args) do
                            if type(v) == "string" and #v >= 2 and #v <= 30
                               and v:match("^[%a]+$") then
                                markUsed(v)
                                log("✓ [PlayerCorrect] kata lawan ditandai used:", v)
                            end
                        end
                    end

                    -- HANDLE: UsedWordWarn — word udah dipake (bukan invalid!)
                    -- Mark recently submitted word as "duplicate" (gak permanent blacklist)
                    if r.Name:lower():find("used") and r.Name:lower():find("warn") then
                        gotUsedWordWarn = true
                        if lastSubmittedWord then
                            markUsed(lastSubmittedWord)
                            log("⚠️ [UsedWordWarn] '"..lastSubmittedWord.."' udah dipake → RETRY kata lain")
                        end
                        -- FAST RETRY: bypass cooldown supaya loop langsung pick kata baru
                        if state then
                            state.lastFireAt = 0
                            state.busy = false
                        end
                    end
                end)
                if isRE then listenedRE = listenedRE + 1
                else listenedURE = listenedURE + 1 end
            end)
        end
    end
    log("Priority remotes (obfuscated folder):", priorityCount)
    log("Listening: RE="..listenedRE.." URE="..listenedURE)

    -- (2) Hook RemoteFunction.OnClientInvoke kalau ada (passive)
    -- (server bisa juga nginvoke client, kadang dipake buat kirim token)
    local listenedRF = 0
    for _, r in ipairs(rs:GetDescendants()) do
        if r:IsA("RemoteFunction") then
            pcall(function()
                if not r.OnClientInvoke then
                    r.OnClientInvoke = function(...)
                        local args = {...}
                        if SNIFFER_DEBUG then
                            log("[RF-INVOKE]", r.Name, "args:", #args)
                        end
                        for i, v in ipairs(args) do
                            deepScan(v, r:GetFullName() .. " (RF) arg["..i.."]")
                        end
                    end
                    listenedRF = listenedRF + 1
                end
            end)
        end
    end

    -- (3) Scan Attributes di BANYAK tempat
    -- Game ini pake attribute-based replication, jadi token mungkin di attribute lain
    local function watchAttributes(inst, label)
        if not inst then return end
        pcall(function()
            -- Dump attribute existing pakai relaxed check
            for k, v in pairs(inst:GetAttributes()) do
                checkValueForTokenRelaxed(v, label..".Attr["..k.."]", true)
                if SNIFFER_DEBUG and type(v) == "string" and #v >= 5 then
                    log("[ATTR-INIT]", label, k, "=", v)
                end
            end
            -- Listen perubahan
            inst.AttributeChanged:Connect(function(name)
                local v = inst:GetAttribute(name)
                checkValueForTokenRelaxed(v, label..".Attr["..name.."]", true)
                if SNIFFER_DEBUG then
                    local sval = tostring(v)
                    if #sval > 40 then sval = sval:sub(1,40).."..." end
                    log("[ATTR-"..label.."]", name, "=", sval)
                end
            end)
        end)
    end

    -- LP & Character
    watchAttributes(LP, "LP")
    if LP.Character then watchAttributes(LP.Character, "Char") end
    LP.CharacterAdded:Connect(function(c) watchAttributes(c, "Char") end)

    -- Special handler: IsTurn change → update gameState
    LP:GetAttributeChangedSignal("IsTurn"):Connect(function()
        local v = LP:GetAttribute("IsTurn")
        gameState.isMyTurn = (v == true)
        if v == false then
            -- clear letter pas giliran berakhir biar fresh next turn
            gameState.currentLetter = nil
            log("⏸ IsTurn=false, clear letter")
        elseif v == true then
            log("⚡ IsTurn=true, ready for letter+token")
        end
    end)

    -- Special handler: Mistake attribute change
    -- Kalau Mistake naik dalam 4 detik setelah kita submit, berarti kata kita di-reject.
    -- BUT: kalau juga ada UsedWordWarn, berarti reject karena duplicate, BUKAN invalid.
    -- → Cuma markUsed (match ini), JANGAN permanent blacklist.
    pcall(function()
        LP:GetAttributeChangedSignal("Mistake"):Connect(function()
            local now = tick()
            local currentMistake = LP:GetAttribute("Mistake") or 0
            -- VALIDATE: Mistake harus benar2 NAIK dari saat submit (bukan duplicate fire).
            -- Tanpa check ini, race condition: submit-A reject, submit-B accept,
            -- submit-C reject → handler kena trigger 2x, blacklist B sebagai bonus.
            if currentMistake <= mistakeValueAtSubmit then
                return  -- attribute fired but value sama / lebih kecil = bukan our fresh mistake
            end
            if lastSubmittedWord and (now - lastSubmittedAt) < 4 then
                if gotUsedWordWarn then
                    -- Already marked used by UsedWordWarn handler. Don't blacklist.
                    log("ℹ️ Mistake karena duplicate, kata tetap valid:", lastSubmittedWord)
                else
                    -- Pure invalid → permanent blacklist + fast retry (per-mode scope)
                    blacklistWord(lastSubmittedWord, modeAtSubmit)
                    log(("🔁 [retry] '%s' invalid di mode [%s] → pick kata lain"):format(lastSubmittedWord, modeAtSubmit))
                    -- Set flag biar typeWord clear sisa huruf di pre-type step.
                    -- Gak clear sekarang (race condition: game mungkin masih render label).
                    needsClearOnNextType = true
                    if state then
                        state.lastFireAt = 0
                        state.busy = false
                    end
                    -- ANTI-KICK SAFETY: count invalid mistakes
                    sessionMistakes = (sessionMistakes or 0) + 1
                    if sessionMistakes >= MAX_SESSION_MISTAKES then
                        warn2(("🛑 Mistake count = %d! AUTO-PAUSE bot biar gak ke-kick anti-cheat (Error 267)."):format(sessionMistakes))
                        warn2("   Reset manual: getgenv().SambungKata.ResetMistakes()")
                        if state then state.enabled = false end
                    elseif sessionMistakes >= 2 then
                        warn2(("⚠️ Mistake = %d/%d — hati-hati, sebentar lagi auto-pause"):format(sessionMistakes, MAX_SESSION_MISTAKES))
                    end
                end
                lastSubmittedWord = nil  -- prevent double-handling
                gotUsedWordWarn = false  -- reset flag
            end
        end)
    end)

    -- Workspace + descendants (RECURSIVE — aggressive)
    pcall(function()
        watchAttributes(workspace, "WS")
        for _, d in ipairs(workspace:GetDescendants()) do
            -- only watch Models, Folders, BaseParts (skip noise)
            if d:IsA("Model") or d:IsA("Folder") or d:IsA("BasePart") then
                local n = d.Name:lower()
                -- prioritize game-related objects
                if n:find("table") or n:find("match") or n:find("game") or n:find("round") then
                    watchAttributes(d, "WS."..d.Name)
                end
            end
        end
        -- Listen new descendants
        workspace.DescendantAdded:Connect(function(d)
            if d:IsA("Model") or d:IsA("Folder") then
                local n = d.Name:lower()
                if n:find("table") or n:find("match") or n:find("game") then
                    watchAttributes(d, "WS."..d.Name)
                end
            end
        end)
    end)

    -- ReplicatedStorage
    pcall(function()
        watchAttributes(rs, "RS")
        for _, d in ipairs(rs:GetChildren()) do
            if d:IsA("Folder") or d:IsA("Configuration") then
                watchAttributes(d, "RS."..d.Name)
            end
        end
    end)

    -- (4) Scan StringValue/IntValue di Player & ReplicatedStorage
    local function scanValueObjects(parent, label)
        for _, c in ipairs(parent:GetDescendants()) do
            if c:IsA("StringValue") or c:IsA("NumberValue") then
                pcall(function()
                    checkValueForToken(tostring(c.Value), label.."."..c:GetFullName())
                    c:GetPropertyChangedSignal("Value"):Connect(function()
                        local val = tostring(c.Value)
                        checkValueForToken(val, label.."."..c:GetFullName())
                        if SNIFFER_DEBUG then log("[VAL]", c:GetFullName(), "=", val) end
                    end)
                end)
            end
        end
    end
    pcall(function() scanValueObjects(LP, "LP") end)
    pcall(function() scanValueObjects(rs, "RS") end)

    log(string.format("Sniffer aktif: RE=%d, RF=%d", listenedRE, listenedRF))

    -- (5) Scan PlayerGui + Workspace juga
    pcall(function() scanValueObjects(PlayerGui, "PG") end)
    pcall(function() scanValueObjects(workspace, "WS") end)
end

task.spawn(setupTokenSniffer)

-- (legacy scanner masih ada di bawah buat fallback / debug)
-- PASSIVE REMOTE SCANNER (no hooks = no anti-cheat detection)
-- Scan semua RemoteEvent/RemoteFunction di ReplicatedStorage & tempat umum lainnya.
-- Score by name keyword. Yang scorenya tinggi otomatis dipilih.
local KEYWORDS = {
    -- TURN-related (paling kuat — game word chain biasanya pake "EndTurn")
    {kw = "endturn", score = 80},
    {kw = "end_turn",score = 80},
    -- bahasa indonesia
    {kw = "sambung", score = 50},
    {kw = "kata",    score = 30},
    {kw = "jawab",   score = 35},
    {kw = "kirim",   score = 25},
    -- english
    {kw = "submit",  score = 45},
    {kw = "answer",  score = 40},
    {kw = "word",    score = 25},
    {kw = "send",    score = 20},
    {kw = "guess",   score = 30},
    {kw = "play",    score = 15},
    {kw = "input",   score = 15},
}

-- Penalty untuk remote yang KEMUNGKINAN bukan submit
local NEG_KEYWORDS = {
    {kw = "current",    score = -30},  -- UpdateCurrentWord = live typing
    {kw = "billboard",  score = -50},  -- UI
    {kw = "announce",   score = -50},  -- broadcast
    {kw = "ui",         score = -30},
    {kw = "sound",      score = -50},
    {kw = "type",       score = -10},  -- TypeSound
    {kw = "claim",      score = -30},  -- reward
    {kw = "buy",        score = -50},
    {kw = "weapon",     score = -50},
    {kw = "reward",     score = -40},
    {kw = "coin",       score = -40},
    {kw = "money",      score = -40},
    {kw = "streak",     score = -30},
    {kw = "result",     score = -30},
    {kw = "vip",        score = -50},
    {kw = "join",       score = -30},
    {kw = "leave",      score = -30},
    {kw = "camera",     score = -50},
    {kw = "blink",      score = -50},
    {kw = "mistake",    score = -50},
    {kw = "request",    score = -10},  -- RequestX biasanya client→server fetch
    {kw = "update",     score = -5},   -- generic, bisa apa aja
    {kw = "visibility", score = -50},
    {kw = "owned",      score = -40},
    {kw = "index",      score = -20},  -- WordIndex = kamus, bukan submit
    {kw = "timer",      score = -50},
    {kw = "fire",       score = -30},  -- FireBG
}

local function scoreRemote(remote)
    local name = remote.Name:lower()
    local full = remote:GetFullName():lower()
    local s = 0
    for _, k in ipairs(KEYWORDS) do
        if name:find(k.kw, 1, true) then s = s + k.score end
    end
    for _, k in ipairs(NEG_KEYWORDS) do
        if name:find(k.kw, 1, true) then s = s + k.score end
    end
    -- Bonus: nama yang gak punya keyword kenal & looks random/hashed
    -- (obfuscated remotes — biasanya gameplay penting yg disembunyiin)
    if #name >= 16 and name:match("^[%w_]+$") and not name:find("_") then
        local upper = 0
        for c in name:gmatch("[A-Z]") do upper = upper + 1 end
        for c in remote.Name:gmatch("[A-Z]") do upper = upper + 1 end
        if upper >= 3 then s = s + 15 end  -- nama campur huruf besar/kecil random
    end
    return s
end

local remoteCandidates = {}  -- { {remote=, score=}, ... }

local function scanRemotes()
    remoteCandidates = {}
    local searchRoots = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
    }
    for _, root in ipairs(searchRoots) do
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction")
               or d:IsA("UnreliableRemoteEvent") then
                local s = scoreRemote(d)
                table.insert(remoteCandidates, {remote = d, score = s})
            end
        end
    end
    table.sort(remoteCandidates, function(a, b) return a.score > b.score end)

    log("Total remote ditemukan:", #remoteCandidates)
    for i = 1, math.min(5, #remoteCandidates) do
        local c = remoteCandidates[i]
        log(string.format("  [%d] score=%d  %s", i, c.score, c.remote:GetFullName()))
    end

    -- Skip auto-pick kalau remote udah ke-resolve dari path hardcoded (Section 3)
    if detected.remote then
        log("Submit remote udah ke-resolve, skip auto-pick legacy scanner")
        return
    end

    -- auto-pick top candidate kalau score tinggi (>=40)
    local top = remoteCandidates[1]
    if top and top.score >= 40 then
        detected.remote = top.remote
        detected.method = top.remote:IsA("RemoteFunction") and "InvokeServer" or "FireServer"
        detected.argIndex = 1
        detected.argFormat = "raw"
        log("Auto-pick remote:", top.remote:GetFullName(), "(score "..top.score..")")
    else
        warn2("Tidak ada remote yang skornya tinggi. Pilih manual via GUI dropdown.")
    end
end

task.spawn(scanRemotes)

------------------------------------------------------------
-- 4. TURN & LETTER DETECTION (PlayerGui scanner)
------------------------------------------------------------
-- Cari TextLabel/TextBox di PlayerGui yang nampilin huruf giliran
-- Pattern umum: "huruf X", "mulai dari X", atau label 1 huruf besar
-- HARDCODED PATH: huruf giliran ada di TextLabel "WordServer" di MatchUI
-- Path: PlayerGui.MatchUI.BottomUI.TopUI.WordServerFrame.WordServer
-- (Confirmed via DumpUI: text="K"/"M"/etc sesuai huruf giliran)
local function findCurrentLetter()
    local matchUI = PlayerGui:FindFirstChild("MatchUI")
    if matchUI then
        -- Path lengkap (tahan terhadap layout berubah dikit)
        local wordServer = nil
        pcall(function()
            wordServer = matchUI.BottomUI.TopUI.WordServerFrame.WordServer
        end)
        if wordServer and wordServer:IsA("TextLabel") and wordServer.Visible then
            local txt = wordServer.Text
            if txt and #txt >= 1 and #txt <= 5 then
                local trimmed = txt:gsub("^%s+", ""):gsub("%s+$", "")
                if trimmed:match("^[A-Za-z]+$") then
                    return trimmed:lower()
                end
            end
        end
    end

    -- Fallback: cari TextLabel berdasarkan nama "WordServer" (kalo path berubah)
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj.Name == "WordServer" and obj:IsA("TextLabel") and obj.Visible then
            local txt = obj.Text
            if txt and #txt >= 1 and #txt <= 5 then
                local trimmed = txt:gsub("^%s+", ""):gsub("%s+$", "")
                if trimmed:match("^[A-Za-z]+$") then
                    return trimmed:lower()
                end
            end
        end
    end

    return nil
end

-- Deteksi "giliran kamu" — heuristik:
--   1. Ada TextBox yang Active/Focused & TextEditable=true & Visible
--   2. Atau ada TextLabel berisi nama LP / "giliran"+nama LP
local function isMyTurn()
    -- PRIORITY: pake LP attribute "IsTurn" (most reliable di game ini)
    local ok, attr = pcall(function() return LP:GetAttribute("IsTurn") end)
    if ok and type(attr) == "boolean" then
        return attr
    end
    -- Fallback: scan UI (lambat & gak akurat di game ini)
    -- (1) cari TextBox yang aktif & visible
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextBox") and obj.Visible
           and obj.TextEditable and obj.AbsoluteSize.X > 0 then
            -- pastikan ancestor frame visible
            local p = obj.Parent
            local visible = true
            while p and p:IsA("GuiObject") do
                if not p.Visible then visible = false break end
                p = p.Parent
            end
            if visible then return true, obj end
        end
    end

    -- (2) cari label "giliran"+nama
    local myName = (LP.DisplayName or ""):lower()
    local myUser = LP.Name:lower()
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local ok, txt = pcall(function() return obj.Text end)
            if ok and txt then
                local low = txt:lower()
                if (low:find("giliran") or low:find("turn"))
                   and (low:find(myName, 1, true) or low:find(myUser, 1, true)) then
                    return true
                end
            end
        end
    end
    return false
end

------------------------------------------------------------
-- 5. SUBMIT WORD (multi-mode: remote / click / suggest)
------------------------------------------------------------

-- HUD Suggester — disabled (user prefer no UI clutter, log only)
local function showSuggestion(word, prefix)
    -- no-op; suggestion ditampilkan di console log saja
end

-- Find virtual keyboard buttons di PlayerGui.
-- Match: TextButton dengan text = letter (1 char). Tanpa filter posisi (terlalu strict).
local function findKeyboardButton(letter)
    letter = letter:upper()
    local candidates = {}
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextButton") then
            local txt = (obj.Text or ""):gsub("%s+", "")
            if txt:upper() == letter and obj.Visible and obj.AbsoluteSize.X > 5 then
                table.insert(candidates, obj)
            end
        elseif obj:IsA("ImageButton") then
            -- ImageButton bisa punya child TextLabel/Frame yang berisi letter
            for _, child in ipairs(obj:GetChildren()) do
                if child:IsA("TextLabel") and (child.Text or ""):gsub("%s+", ""):upper() == letter
                   and obj.Visible and obj.AbsoluteSize.X > 5 then
                    table.insert(candidates, obj)
                    break
                end
            end
            -- Atau Name button-nya match (e.g. "KeyA")
            local n = (obj.Name or ""):upper()
            if (n == letter or n == "KEY"..letter or n == "KEYBOARD"..letter
                or n:match("^"..letter.."$"))
               and obj.Visible and obj.AbsoluteSize.X > 5 then
                table.insert(candidates, obj)
            end
        end
    end
    -- Pilih yang paling besar (asumsi tombol keyboard ukuran wajar)
    if #candidates > 0 then
        table.sort(candidates, function(a, b) return a.AbsoluteSize.X > b.AbsoluteSize.X end)
        return candidates[1]
    end
    return nil
end

-- DEBUG: dump semua kandidat button
local function dumpKeyboardButtons()
    print("=== KEYBOARD BUTTON DUMP ===")
    local count = 0
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextButton") then
            local txt = (obj.Text or ""):gsub("%s+", "")
            if #txt == 1 and txt:match("[%a]") and obj.Visible then
                count = count + 1
                print(string.format("[%d] %s='%s' size=%dx%d pos=(%.0f,%.0f) | %s",
                    count, obj.ClassName, obj.Text,
                    obj.AbsoluteSize.X, obj.AbsoluteSize.Y,
                    obj.AbsolutePosition.X, obj.AbsolutePosition.Y,
                    obj:GetFullName()))
                if count >= 30 then break end
            end
        end
    end
    if count == 0 then
        warn("[SambungKata] Gak ada TextButton 1-char ketemu di PlayerGui")
        warn("[SambungKata] Game ini mungkin gak punya virtual keyboard, atau butuh dibuka dulu")
    end
end

-- Click button via VIM mouse — natural input flow
local function clickButton(button)
    if not button or not button.Parent then return false end
    local pos = button.AbsolutePosition
    local size = button.AbsoluteSize
    local cx = pos.X + size.X / 2 + (math.random() - 0.5) * 4  -- random offset (manusia gak click center exactly)
    local cy = pos.Y + size.Y / 2 + (math.random() - 0.5) * 4
    local VIM = game:GetService("VirtualInputManager")
    pcall(function()
        VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
        task.wait(0.04 + math.random() * 0.04)
        VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
    end)
    return true
end

-- Find Submit/Enter button (biasanya yang gede merah/hijau di pojok keyboard)
local function findSubmitButton()
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
            local n = (obj.Name or ""):lower()
            local txt = obj:IsA("TextButton") and (obj.Text or ""):lower() or ""
            if (n:find("submit") or n:find("enter") or n:find("send")
                or txt:find("enter") or txt:find("submit") or txt:find("ok"))
               and obj.Visible then
                return obj
            end
        end
    end
    return nil
end

local function fireSubmit(word)
    -- Dispatch berdasarkan INPUT_MODE
    local mode = CONFIG.INPUT_MODE or "remote"
    local prefix = findCurrentLetter() or ""
    local prefixLen = #prefix
    if prefixLen == 0 or word:sub(1, prefixLen):lower() ~= prefix:lower() then
        prefixLen = 1
    end
    local suffix = word:sub(prefixLen + 1)

    -- Always show suggestion (helpful for any mode)
    showSuggestion(word, prefix)
    log(("📋 Suggest: %s ➜ %s (suffix: %s)"):format(prefix:upper(), word:upper(), suffix:upper()))

    if mode == "suggest" then
        -- Cuma tampilin di HUD, user ketik manual
        markUsed(word)
        return true
    end

    if mode == "kbinput" then
        -- Strategy: NO remote fire, NO property writes. Cuma mouse click + key events.
        -- Game's local script handle TextBox input → fire SubmitWord internally.
        log("⌨️ Keyboard input mode — VIM mouse focus + send keys")
        local VIM = game:GetService("VirtualInputManager")

        -- ─── READING DELAY (anti-pattern: bot gak langsung ngetik) ───
        -- Manusia: liat prefix → mikir → baru ketik. Scaled by word complexity.
        -- Skip kalau Brutal mode (timer pendek) atau bot mode (perfect speed).
        if CONFIG.INTERACTION_MODE == "human" and detectedMode ~= "Brutal" then
            -- Base 0.4-1.2s + 60ms per char (longer word = lebih lama mikir)
            local readBase = 0.4 + math.random() * 0.8
            local readPerChar = 0.06 * #word
            local readDelay = readBase + readPerChar * (0.7 + math.random() * 0.6)
            log(("👀 [reading] Pause %.2fs sebelum ngetik (anti-instant)"):format(readDelay))
            task.wait(readDelay)
        elseif CONFIG.INTERACTION_MODE == "human" and detectedMode == "Brutal" then
            -- Brutal: minimal reading delay biar gak kalah timer, tapi tetep ada
            task.wait(0.15 + math.random() * 0.25)
        end

        -- (1) Cari WordSubmit Frame (game nampung typed letters di sini sbg TextLabel).
        -- HARDCODED: PlayerGui.MatchUI.BottomUI.TopUI.WordSubmit (Frame).
        -- Tiap huruf yg diketik = 1 TextLabel anak WordSubmit (Name="Word").
        -- Setelah Mistake, label2 ini gak auto-cleared → bot harus kirim Backspace
        -- sejumlah child label biar visual + state game ke-reset.
        local wordSubmit = nil
        pcall(function()
            wordSubmit = PlayerGui.MatchUI.BottomUI.TopUI.WordSubmit
        end)
        local function countTypedLetters()
            if not wordSubmit then return 0 end
            local n = 0
            for _, c in ipairs(wordSubmit:GetChildren()) do
                if c:IsA("TextLabel") and c.Name == "Word"
                   and c.Visible and c.Text ~= nil and c.Text ~= "" then
                    n = n + 1
                end
            end
            return n
        end

        -- (1.5) Cari TextBox SUBMIT (legacy fallback — biasanya gak ada di game ini).
        -- Helper: cek apakah TextBox ada di Index/Menu/Search context (bukan game submit)
        local function isExcludedTextBox(obj)
            local p = obj
            while p and p.Parent do
                local n = p.Name:lower()
                if n:find("search") or n:find("index") or n:find("menu")
                   or n:find("chat") or n:find("settings") or n:find("shop") then
                    return true
                end
                p = p.Parent
                if p:IsA("ScreenGui") then break end
            end
            return false
        end

        local tb
        -- Strategy A: WordServerFrame (game's main submit area)
        for _, v in ipairs(PlayerGui:GetDescendants()) do
            if v.Name == "WordServerFrame" and not isExcludedTextBox(v) then
                local sg = v
                while sg and not sg:IsA("ScreenGui") do sg = sg.Parent end
                if sg then
                    for _, d in ipairs(sg:GetDescendants()) do
                        if d:IsA("TextBox") and d.Visible and d.Transparency < 1
                           and not isExcludedTextBox(d) then
                            tb = d
                            break
                        end
                    end
                end
                if tb then break end
            end
        end
        -- Strategy B: any visible editable TextBox in PlayerGui, excluding Menu/Index/Search
        if not tb then
            for _, obj in ipairs(PlayerGui:GetDescendants()) do
                if obj:IsA("TextBox") and obj.Visible and obj.TextEditable
                   and obj.AbsoluteSize.X > 50 and obj.AbsoluteSize.Y > 15
                   and not isExcludedTextBox(obj) then
                    tb = obj
                    log("ℹ️ TextBox fallback ketemu:", obj:GetFullName())
                    break
                end
            end
        end

        if tb then
            local pos = tb.AbsolutePosition
            local size = tb.AbsoluteSize
            local cx = pos.X + size.X / 2 + (math.random() - 0.5) * 8
            local cy = pos.Y + size.Y / 2 + (math.random() - 0.5) * 4
            pcall(function()
                VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                task.wait(0.04 + math.random() * 0.03)
                VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            end)
            task.wait(0.15 + math.random() * 0.1)
        else
            -- Game ini gak punya submit TextBox di MatchUI (visual via BillboardUpdate).
            -- Skip visual typing simulation, langsung lanjut ke FireServer di fireSubmit().
            log("ℹ️ [info] No submit TextBox di game ini — pakai BillboardUpdate + FireServer (no visual typing)")
        end

        -- (1.6) SMART CLEAR: hapus huruf2 yg salah dari Mistake sebelumnya.
        -- Game pake WordSubmit Frame, tiap huruf = 1 TextLabel "Word".
        -- Kirim Backspace key sejumlah label biar game's local script ngapus.
        local typedCount = countTypedLetters()
        -- DIAGNOSTIC: print konten label biar bisa identify slots vs typed letters
        if wordSubmit and CONFIG.DEBUG then
            local previewParts = {}
            for _, c in ipairs(wordSubmit:GetChildren()) do
                if c:IsA("TextLabel") and c.Name == "Word" then
                    table.insert(previewParts, "'"..(c.Text or "").."'")
                end
            end
            log(("🔬 [diag] WordSubmit labels (%d total): [%s]"):format(
                #previewParts, table.concat(previewParts, ",")))
        end
        -- Clear cuma kalo flag dari Mistake handler diset (avoid clearing prefix hint dari game).
        if needsClearOnNextType and typedCount > 0 then
            log(("🧹 [clear] Hapus %d huruf di WordSubmit (sisa Mistake) — fast backspace"):format(typedCount))
            -- FAST Backspace key events — 30ms cycle (game register key, ngapus 1 char per press).
            -- Game's local script handle Backspace utk maintain word state.
            -- Property write doang gak cukup karena game lanjut append ke state internal.
            for _ = 1, typedCount + 1 do  -- +1 safety margin
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                end)
                task.wait(0.04 + math.random() * 0.02)  -- 40-60ms hold
                pcall(function()
                    VIM:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
                end)
                task.wait(0.05 + math.random() * 0.03)  -- 50-80ms gap antar press
            end
            -- Belt + suspender: also property write biar visual sync instant
            pcall(function()
                for _, c in ipairs(wordSubmit:GetChildren()) do
                    if c:IsA("TextLabel") and c.Name == "Word"
                       and c.Text ~= nil and c.Text ~= "" then
                        c.Text = ""
                    end
                end
            end)
            needsClearOnNextType = false
        end
        -- Legacy: textbox-based clear (gak relevan di game ini, tapi safe to keep)
        if tb then
            local current = tb.Text or ""
            if #current > 0 then
                for _ = 1, #current do
                    pcall(function()
                        VIM:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                        task.wait(0.05)
                        VIM:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
                    end)
                    task.wait(0.06)
                end
            end
        end

        -- (2) Type SUFFIX (game lock prefix di textbox, bot tinggal append).
        local toType = suffix
        log(("⌨️ Typing suffix '%s' (full word='%s')"):format(toType, word))

        local QWERTY_NEIGHBORS = {
            a="sq", b="vn", c="xv", d="sf", e="wr", f="dg", g="fh", h="gj",
            i="uo", j="hk", k="jl", l="k", m="n", n="bm", o="ip", p="o",
            q="aw", r="et", s="ad", t="ry", u="yi", v="cb", w="qe", x="zc",
            y="tu", z="x"
        }
        for i = 1, #toType do
            -- Stop kalau script di-shutdown atau giliran udah lewat.
            -- Sengaja gak cek state.enabled biar manual submit dari Suggester tetep jalan
            -- meski Auto Play OFF.
            if not state.alive or not isMyTurn() then break end
            local lowerChar = toType:sub(i, i):lower()
            local upperChar = lowerChar:upper()
            local key = Enum.KeyCode[upperChar]

            -- Backspace-fix typo: ketik salah → hapus → ketik benar
            -- Cuma kata panjang (>=7 huruf), skip char pertama (typo cluster di tengah)
            if #word >= 7 and i > 1 and math.random() < humanChance("BACKSPACE_FIX_CHANCE") then
                local neighbors = QWERTY_NEIGHBORS[lowerChar] or "qwerty"
                local idx = math.random(1, #neighbors)
                local wrongChar = neighbors:sub(idx, idx)
                local wrongKey = wrongChar ~= "" and Enum.KeyCode[wrongChar:upper()] or nil
                if wrongKey then
                    log(("✏️ [typo-fix] '%s' (mau ngetik '%s')"):format(wrongChar:upper(), upperChar))
                    pcall(function()
                        VIM:SendKeyEvent(true, wrongKey, false, game)
                        task.wait(0.05 + math.random() * 0.06)  -- 50-110ms hold
                        VIM:SendKeyEvent(false, wrongKey, false, game)
                    end)
                    task.wait(0.25 + math.random() * 0.35)  -- "sadar" salah (250-600ms)
                    pcall(function()
                        VIM:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                        task.wait(0.08 + math.random() * 0.07)  -- 80-150ms hold (slower)
                        VIM:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
                    end)
                    task.wait(0.18 + math.random() * 0.22)  -- 180-400ms post-backspace
                end
            end

            if key then
                pcall(function()
                    VIM:SendKeyEvent(true, key, false, game)
                    task.wait(0.04 + math.random() * 0.04)
                    VIM:SendKeyEvent(false, key, false, game)
                end)
            end
            local tmin, tmax = effectiveTypeMs()
            local delay = (tmin + math.random() * (tmax - tmin)) / 1000
            if math.random() < humanChance("HESITATE_CHANCE") then
                delay = delay + 0.2 + math.random() * 0.4
            end
            task.wait(delay)
        end

        -- (3) Press Enter (game's TextBox.FocusLost will fire SubmitWord internally)
        task.wait(0.2 + math.random() * 0.3)
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.04)
            VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        end)

        markUsed(word)
        lastSubmittedWord = word:lower()
        lastSubmittedAt = tick()
        mistakeValueAtSubmit = LP:GetAttribute("Mistake") or 0
        modeAtSubmit = detectedMode
        log("✓ kbinput sent for:", word)
        return true
    end

    if mode == "click" then
        -- Click setiap huruf di virtual keyboard
        log("🖱️ Click mode — typing via virtual keyboard buttons")
        for i = 1, #suffix do
            if not state.alive or not isMyTurn() then break end
            local char = suffix:sub(i, i)
            local btn = findKeyboardButton(char)
            if btn then
                clickButton(btn)
                local tmin, tmax = effectiveTypeMs()
                local delay = (tmin + math.random() * (tmax - tmin)) / 1000
                if math.random() < humanChance("HESITATE_CHANCE") then
                    delay = delay + 0.2 + math.random() * 0.4
                end
                task.wait(delay)
            else
                warn2("Keyboard button gak ketemu untuk:", char, "— mode: click")
                return false
            end
        end
        -- Click submit/enter button
        task.wait(0.3 + math.random() * 0.4)
        local submitBtn = findSubmitButton()
        if submitBtn then
            clickButton(submitBtn)
            log("✓ Submit button clicked")
        else
            warn2("Submit button gak ketemu — kata mungkin gak ke-submit")
        end
        markUsed(word)
        lastSubmittedWord = word:lower()
        lastSubmittedAt = tick()
        mistakeValueAtSubmit = LP:GetAttribute("Mistake") or 0
        modeAtSubmit = detectedMode
        return true
    end

    -- mode == "remote" (default fallback)
    if not detected.remote then
        warn2("Submit remote belum resolved")
        return false
    end
    -- Pake live token (sniffed dari server) > fallback ke CONFIG.SUBMIT_TOKEN
    local token = liveToken or CONFIG.SUBMIT_TOKEN
    if not token or token == "" then
        warn2("Belum ada token — sniffer belum nangkep, atau set CONFIG.SUBMIT_TOKEN manual")
        return false
    end
    -- Token kadaluarsa? Warning kalau lebih dari 30 detik
    if liveToken and (tick() - lastTokenAt) > 30 then
        warn2("Token udah lebih dari 30s, mungkin udah expired:", token)
    end

    -- Simulate progressive typing — fire BillboardUpdate per prefix
    -- Game otomatis prepend huruf giliran, jadi kita cuma type SUFFIX-nya.
    -- Contoh: huruf giliran "K" → word "KUCING" → type "UCING"
    --         huruf giliran "KE" → word "KELUAR" → type "LUAR"
    -- BUG FIX: prefix bisa 1-3 huruf (mode normal) atau 2-5 (mode brutal),
    -- jadi gak boleh hardcode skip 1 char.
    local prefix = findCurrentLetter() or ""
    local prefixLen = #prefix
    if prefixLen == 0 or word:sub(1, prefixLen):lower() ~= prefix:lower() then
        -- safety: kalau word gak match prefix, fallback ke skip 1 char
        prefixLen = 1
    end
    local suffix = word:sub(prefixLen + 1)
    log("Typing: prefix='"..prefix.."' word='"..word.."' suffix='"..suffix.."'")

    if CONFIG.STEALTH_MODE then
        -- STEALTH: progressive BillboardUpdate fire (3D billboard above character).
        -- Aman karena per-char dengan delay manusia (~250ms = 4 calls/sec, gak rate-limited).
        log("🥷 Stealth typing via BillboardUpdate")

        local bu = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("BillboardUpdate")
        if bu and #suffix > 0 then
            for i = 1, #suffix do
                pcall(function() bu:FireServer(suffix:sub(1, i)) end)
                local delay = (CONFIG.TYPE_MIN_MS + math.random() * (CONFIG.TYPE_MAX_MS - CONFIG.TYPE_MIN_MS)) / 1000
                task.wait(delay)
            end
        else
            task.wait(#suffix * 0.28)
        end
        task.wait(0.3 + math.random() * 0.5)
    else
        -- VISIBLE typing mode (RISKY — anti-cheat detect VIM)
        local function findInputTextBox()
            for _, v in ipairs(PlayerGui:GetDescendants()) do
                if v.Name == "WordServerFrame" then
                    local sg = v
                    while sg and not sg:IsA("ScreenGui") do sg = sg.Parent end
                    if sg then
                        for _, d in ipairs(sg:GetDescendants()) do
                            if d:IsA("TextBox") and d.Visible and d.Transparency < 1 then
                                return d
                            end
                        end
                    end
                end
            end
            return nil
        end

        local VIM = game:GetService("VirtualInputManager")
        local tb = findInputTextBox()
        if tb then
            pcall(function()
                tb:CaptureFocus()
                tb.Text = ""
            end)
            task.wait(0.1)
        end

        if #suffix > 0 then
            local QWERTY_NEIGHBORS = {
                a="sq", b="vn", c="xv", d="sf", e="wr", f="dg", g="fh", h="gj",
                i="uo", j="hk", k="jl", l="k", m="n", n="bm", o="ip", p="o",
                q="aw", r="et", s="ad", t="ry", u="yi", v="cb", w="qe", x="zc",
                y="tu", z="x"
            }
            for i = 1, #suffix do
                local char = suffix:sub(i, i):lower()
                local key = Enum.KeyCode[char:upper()]

                -- Cuma kata panjang (>=7), skip char pertama & terakhir (typo cluster di tengah)
                if #word >= 7 and i > 1 and i < #suffix and math.random() < humanChance("TYPO_CHANCE") then
                    local neighbors = QWERTY_NEIGHBORS[char] or "qwerty"
                    local idx = math.random(1, #neighbors)
                    local wrongChar = neighbors:sub(idx, idx)
                    local wrongKey = wrongChar ~= "" and Enum.KeyCode[wrongChar:upper()] or nil
                    if wrongKey then
                        pcall(function()
                            VIM:SendKeyEvent(true, wrongKey, false, game)
                            task.wait(0.05 + math.random() * 0.06)  -- 50-110ms hold
                            VIM:SendKeyEvent(false, wrongKey, false, game)
                        end)
                        task.wait(0.25 + math.random() * 0.35)  -- 250-600ms "sadar salah"
                        pcall(function()
                            VIM:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                            task.wait(0.08 + math.random() * 0.07)  -- 80-150ms hold (slower)
                            VIM:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
                        end)
                        task.wait(0.18 + math.random() * 0.22)  -- 180-400ms post-backspace
                    end
                end

                if key then
                    pcall(function()
                        VIM:SendKeyEvent(true, key, false, game)
                        task.wait(0.04 + math.random() * 0.05)
                        VIM:SendKeyEvent(false, key, false, game)
                    end)
                end

                local tmin, tmax = effectiveTypeMs()
                local baseDelay = (tmin + math.random() * (tmax - tmin)) / 1000
                if math.random() < humanChance("HESITATE_CHANCE") then
                    baseDelay = baseDelay + 0.2 + math.random() * 0.4
                end
                task.wait(baseDelay)
            end
        end
        task.wait(0.4 + math.random() * 0.6)
    end

    -- Submit kata final (= equivalen pencet Enter)
    -- Re-fetch token (mungkin udah berubah selama typing animation)
    token = liveToken or token
    -- CRITICAL: Server expects SUFFIX (kata setelah prefix), bukan full word!
    -- Server validate: prefix + arg1 = expected_word.
    -- Kalau kita kirim full word, server interpret jadi "prefix+word" = invalid.
    -- (Confirmed dari script lama: SubmitWord:FireServer(suffixToSubmit, secretID))
    local submitSuffix = suffix  -- udah dihitung di atas dgn prefix-aware logic
    log("🔥 Submit: suffix='"..submitSuffix.."' (full word: '"..word.."')")
    -- (1) Fire SubmitWord remote langsung (bypass)
    local ok, err = pcall(function()
        detected.remote:FireServer(submitSuffix, token)
    end)
    -- (2) Optional: Enter key via VIM — cuma kalau VISIBLE mode (resiko detect)
    if not CONFIG.STEALTH_MODE then
        local VIM = game:GetService("VirtualInputManager")
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.04)
            VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        end)
    end
    -- JANGAN invalidate token — kalau word di-reject (Mistake), token mungkin
    -- masih valid buat retry dgn kata lain. Token bakal di-overwrite next StartTurn.
    if not ok then
        warn2("Gagal fire remote:", err)
        return false
    end
    markUsed(word)
    lastSubmittedWord = word:lower()
    lastSubmittedAt = tick()
    mistakeValueAtSubmit = LP:GetAttribute("Mistake") or 0
    modeAtSubmit = detectedMode
    log("Kirim kata:", word)
    return true
end

-- Set teks WordSubmit (display only). Skip kalau stealth mode (property write detectable).
local function simulateTextBox(word, prefix)
    if CONFIG.STEALTH_MODE then return end  -- skip property writes
    pcall(function()
        local matchUI = PlayerGui:FindFirstChild("MatchUI")
        if matchUI then
            local wordSubmit = matchUI.BottomUI.TopUI.WordSubmit.Word
            if wordSubmit then
                local suffix = word:sub((#(prefix or "") + 1))
                wordSubmit.Text = suffix:upper()
            end
        end
    end)
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextBox") and obj.Visible and obj.TextEditable then
            pcall(function() obj.Text = word end)
            break
        end
    end
end

------------------------------------------------------------
-- 6. MAIN AUTO-PLAY LOOP
------------------------------------------------------------
-- state udah di-forward-declare di top file, di sini tinggal pake

task.spawn(function()
    while state.alive do
        task.wait(0.4)
        if not state.alive then break end
        if not state.enabled then continue end
        if state.busy then continue end
        if not detected.remote then continue end
        if totalWords == 0 then continue end

        local myTurn = isMyTurn()
        if not myTurn then continue end

        local letter = findCurrentLetter()
        if not letter then
            -- gak ketemu huruf, skip cycle
            log("⏳ [auto-play] giliran kamu tapi huruf belum ketemu, retry...")
            continue
        end
        detectMode(letter)  -- update mode flag (Santai/Normal/Brutal)
        log("🎯 [auto-play] giliran kamu, huruf:", letter:upper(), "| mode:", detectedMode)

        -- cooldown biar gak spam (effective: lebih cepat di Brutal)
        local effMin = effectiveDelay()
        if tick() - state.lastFireAt < effMin then continue end

        state.busy = true

        -- ANTI-PATTERN #1: Mandatory break setelah N consecutive submits.
        -- Break terjadi DI LUAR turn (gak makan turn timer) — skip turn ini, istirahat.
        -- Skip break di Santai (turn pendek, gak perlu istirahat — server validate cepat).
        if CONFIG.INTERACTION_MODE ~= "bot"
           and detectedMode ~= "Santai"
           and state.consecutiveSubmits >= CONFIG.MAX_CONSECUTIVE_SUBMITS then
            local breakTime = CONFIG.BREAK_DURATION_MIN + math.random() * (CONFIG.BREAK_DURATION_MAX - CONFIG.BREAK_DURATION_MIN)
            log(("☕ [break] Setelah %d submit beruntun, istirahat %.1fs"):format(state.consecutiveSubmits, breakTime))
            state.consecutiveSubmits = 0
            -- Wait dalam chunks kecil, exit kalau giliran lewat (jangan kelewat turn timer)
            local endAt = tick() + breakTime
            while tick() < endAt do
                task.wait(0.5)
                if not isMyTurn() then
                    log("[break] Giliran udah lewat, lanjut")
                    break
                end
            end
            state.busy = false
            continue
        end

        -- ANTI-PATTERN #2: Random skip turn (12% chance) — sengaja kalah biar gak terlalu sempurna
        if math.random() < humanChance("SKIP_TURN_CHANCE") then
            log("😴 [skip] Random skip turn (anti-pattern, mirip manusia bingung/lupa)")
            -- Tunggu sampe turn selesai (timeout)
            local skipUntil = tick() + 8
            while tick() < skipUntil and isMyTurn() do task.wait(0.5) end
            state.busy = false
            continue
        end

        local word = pickWord(letter)
        if word then
            -- ANTI-PATTERN #3: Variable delay — kadang cepet, kadang lama mikir
            local delay
            local emin, emax = effectiveDelay()
            if math.random() < humanChance("LONG_THINK_CHANCE")
               and detectedMode ~= "Brutal" and detectedMode ~= "Santai" then
                delay = 2.5 + math.random() * 1.5  -- 2.5-4s "long think" (skip di Brutal/Santai — turn timer pendek)
                log(("🤔 [long-think] Bot pura-pura mikir lama: %.1fs"):format(delay))
            else
                delay = emin + math.random() * (emax - emin)
            end
            task.wait(delay)

            -- re-check still my turn
            if state.enabled and isMyTurn() then
                simulateTextBox(word, letter)
                if fireSubmit(word) then
                    state.lastFireAt = tick()
                    state.consecutiveSubmits = (state.consecutiveSubmits or 0) + 1
                end
            end
        else
            warn2("Gak nemu kata buat huruf:", letter)
            task.wait(1)
        end
        state.busy = false
    end
end)

------------------------------------------------------------
-- 6.5 AUTO-JOIN EMPTY TABLE
------------------------------------------------------------
-- Game ini punya Tables di workspace dengan attribute TableState ("Waiting"/"Playing")
-- Strategy:
--   1. Scan workspace untuk Table_* dengan TableState == "Waiting"
--   2. Teleport HRP ke table (atau Seat child)
--   3. Fire ProximityPrompt kalau ada / Sit ke Seat
-- Jalan di background loop terpisah, cuma aktif kalo AUTO_JOIN_TABLE = true
-- Cari table yang kurang 1 player (bakal start match begitu kita masuk).
-- Logic:
--   1. Parse capacity dari nama (Table_2P_X = 2 slot, Table_4P_X = 4 slot)
--   2. Hitung seat occupied
--   3. Pilih yang (capacity - occupied) == 1
-- Fallback: kalau gak ada yang kurang 1, return list of all "Waiting" tables
local function countOccupiedSeats(tableObj)
    local occupied = 0
    local total = 0
    for _, d in ipairs(tableObj:GetDescendants()) do
        if d:IsA("Seat") or d:IsA("VehicleSeat") then
            total = total + 1
            if d.Occupant then occupied = occupied + 1 end
        end
    end
    return occupied, total
end

local function findEmptyTable()
    local nearFull = {}    -- kurang 1 player (priority TINGGI)
    local empty = {}       -- table kosong total
    local partial = {}     -- ada player tapi gak kurang 1

    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("Folder")) and obj.Name:match("^Table_") then
            local ok, tableState = pcall(function() return obj:GetAttribute("TableState") end)
            if ok and tableState == "Waiting" then
                -- Parse capacity dari nama: Table_2P_5 → 2, Table_4P_3 → 4
                local cap = tonumber(obj.Name:match("Table_(%d+)P")) or 0
                local occupied, totalSeats = countOccupiedSeats(obj)
                -- Priority: capacity from name > seat count
                local capacity = cap > 0 and cap or totalSeats

                if capacity > 0 then
                    local slotsLeft = capacity - occupied
                    if slotsLeft == 1 then
                        table.insert(nearFull, obj)
                    elseif occupied == 0 then
                        table.insert(empty, obj)
                    elseif slotsLeft >= 1 then
                        table.insert(partial, obj)
                    end
                end
            end
        end
    end
    -- Return tier-by-tier: nearFull > partial > empty
    if #nearFull > 0 then
        log(("🔥 [auto-join] %d table KURANG 1 player (priority)"):format(#nearFull))
        return nearFull
    end
    if #partial > 0 then
        log(("⏳ [auto-join] %d table partial (gak kurang 1, fallback)"):format(#partial))
        return partial
    end
    return empty
end

-- Fire ProximityPrompt dengan multiple strategy (executor support beda-beda)
local function firePrompt(prompt)
    local fired = false
    -- Strategy 1: native fireproximityprompt (most executors)
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
            fired = true
        end
    end)
    -- Strategy 2: manually invoke holdDuration timer + Triggered event
    if not fired then
        pcall(function()
            local origHold = prompt.HoldDuration
            prompt.HoldDuration = 0
            -- Simulate input: press & release E key
            local VIM = game:GetService("VirtualInputManager")
            VIM:SendKeyEvent(true, prompt.KeyboardKeyCode, false, game)
            task.wait(0.1)
            VIM:SendKeyEvent(false, prompt.KeyboardKeyCode, false, game)
            task.wait(0.1)
            prompt.HoldDuration = origHold
            fired = true
        end)
    end
    return fired
end

-- Find SEMUA prompt nearby HRP (radius 25 studs)
local function findNearbyPrompts(hrp)
    local found = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local part = obj.Parent
            if part and part:IsA("BasePart") then
                local dist = (part.Position - hrp.Position).Magnitude
                if dist <= 25 then
                    table.insert(found, {prompt = obj, dist = dist})
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.dist < b.dist end)
    return found
end

local function joinTable(tableObj)
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp then return false end

    -- Strategy A: ada Seat kosong di table → teleport + sit langsung
    local seat
    for _, d in ipairs(tableObj:GetDescendants()) do
        if (d:IsA("Seat") or d:IsA("VehicleSeat")) and not d.Occupant then
            seat = d
            break
        end
    end

    if seat then
        log("🪑 [auto-join] Sitting at seat in", tableObj.Name)
        pcall(function()
            hrp.CFrame = seat.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.3)
            seat:Sit(hum)
        end)
        task.wait(0.5)
        -- After sit, scan & fire any nearby prompt (table mungkin punya "Join" prompt)
        for _, p in ipairs(findNearbyPrompts(hrp)) do
            if firePrompt(p.prompt) then
                log("✓ [auto-join] Fired prompt:", p.prompt.Name, "@", math.floor(p.dist), "studs")
            end
        end
        return true
    end

    -- Strategy B: teleport ke center, lalu fire prompt yang muncul
    local center
    pcall(function()
        if tableObj:IsA("Model") and tableObj.PrimaryPart then
            center = tableObj.PrimaryPart.CFrame
        else
            center = CFrame.new(tableObj:GetPivot().Position)
        end
    end)
    if center then
        log("📍 [auto-join] Teleport ke", tableObj.Name)
        pcall(function() hrp.CFrame = center + Vector3.new(0, 3, 0) end)
        task.wait(0.6)  -- waktu buat ProximityPrompt aktif

        local prompts = findNearbyPrompts(hrp)
        log(("🔍 [auto-join] %d ProximityPrompt nearby"):format(#prompts))
        local firedAny = false
        for _, p in ipairs(prompts) do
            if firePrompt(p.prompt) then
                log("✓ [auto-join] Fired prompt:", p.prompt.Name, "@", math.floor(p.dist), "studs")
                firedAny = true
                task.wait(0.3)  -- delay between prompts
            end
        end
        return firedAny
    end
    return false
end

-- Auto-join loop
state.autoJoinEnabled = false
local lastJoinAttempt = 0

-- Cek apakah player udah di dalam match (banyak indicator, gak cuma timer).
-- Strategy:
--   1. MatchUI ScreenGui Enabled? → in match
--   2. Player attribute MatchTimer ada / WordServer letter ada? → in match
--   3. Ada Table_* TableState=="Playing" dimana player.Character deket banget (≤15 studs)
local function isInMatch()
    -- Check 1: MatchUI Enabled
    local matchUI = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("MatchUI")
    if matchUI and matchUI.Enabled then return true end

    -- Check 2: WordServer letter visible (giliran lagi jalan)
    if findCurrentLetter() then return true end

    -- Check 3: deket Table yang Playing
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if (obj:IsA("Model") or obj:IsA("Folder")) and obj.Name:match("^Table_") then
                local ok, st = pcall(function() return obj:GetAttribute("TableState") end)
                if ok and st == "Playing" then
                    -- Cek jarak HRP ke salah satu BasePart child table
                    for _, part in ipairs(obj:GetDescendants()) do
                        if part:IsA("BasePart") then
                            if (part.Position - hrp.Position).Magnitude < 20 then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

task.spawn(function()
    while state.alive do
        task.wait(3)
        if not state.autoJoinEnabled then continue end

        -- Skip kalau udah di dalam match (multi-indicator check)
        if isInMatch() then
            continue
        end

        -- Throttle
        if tick() - lastJoinAttempt < 8 then continue end
        lastJoinAttempt = tick()

        local empty = findEmptyTable()
        if #empty > 0 then
            local target = empty[math.random(1, #empty)]
            log(("🎲 [auto-join] %d table waiting, pilih: %s"):format(#empty, target.Name))
            joinTable(target)
        end
    end
end)

------------------------------------------------------------
-- 6.54 AUTO COIN-RAIN COLLECTOR
------------------------------------------------------------
-- Pas event CoinRain (server fire CoinRainNotify), koin spawn di workspace root
-- sebagai MeshPart dengan nama random/obfuscated + 2 Decals (head/tail).
-- Server validate physical contact (Touched event server-side, BUKAN client-fired remote),
-- jadi firetouchinterest gak work. Approach: MAGNET — CFrame koin ke posisi HRP tiap frame
-- biar overlap → server detect Touched → auto collect.
local function getHRP()
    local char = LP.Character or LP.CharacterAdded:Wait()
    return char:FindFirstChild("HumanoidRootPart")
end

-- Identify coin: BasePart parent langsung ke workspace, punya >=2 Decals (head/tail)
-- Nama biasanya random/obfuscated (e.g. "HRGYGHRUSDYR"), beda per-server
local function isCoinPart(d)
    if not d:IsA("BasePart") then return false end
    if d.Parent ~= workspace then return false end
    if d.Name == "Baseplate" or d.Name == "MainSpawn" then return false end
    local decals = 0
    for _, c in ipairs(d:GetChildren()) do
        if c:IsA("Decal") then
            decals = decals + 1
            if decals >= 2 then return true end
        end
    end
    return false
end

-- Cek apakah koin udah landed (gak lagi jatuh dari atas).
-- Anchored koin = static (langsung landed). Unanchored = cek velocity Y.
local function isCoinLanded(part)
    if part.Anchored then return true end
    local vel
    pcall(function() vel = part.AssemblyLinearVelocity end)
    if not vel then return true end  -- gak bisa baca velocity, asume landed
    -- Y velocity ≈ 0 (kalo masih jatuh, biasanya -20 sampe -50 stud/s)
    return math.abs(vel.Y) < 3
end

local coinRainActive = false
local coinRainEndsAt = 0
local tpConnection = nil
local originalCFrame = nil

-- TP loop: HRP teleport ke tiap koin satu-satu (client→server replicates).
-- Setelah event abis, balik ke posisi awal.
local RunService = game:GetService("RunService")

-- WALK COLLECT: Humanoid:MoveTo + Noclip stealth, walk speed NORMAL (16).
-- Player lain liat lo gerak persis kayak player biasa, cuma kebetulan tembus
-- tembok (jarang ketauan). Gak trigger CR-02 (no speed boost).

local function getHumanoid()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local noclipConn = nil
local function startNoclip()
    if noclipConn then return end
    noclipConn = RunService.Stepped:Connect(function()
        local char = LP.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end)
end

local function stopNoclip()
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
end

local function startCoinTP()
    if tpConnection then return end
    log("🚶 [coin-rain] Walk START (MoveTo + stealth noclip, ws normal)")
    startNoclip()

    tpConnection = task.spawn(function()
        while coinRainActive do
            local h = getHRP()
            local hu = getHumanoid()
            if not (h and hu) then task.wait(0.2) continue end

            -- Cari koin terdekat yg UDAH LANDED (gak yg masih jatuh dari atas).
            -- Strategi rebutan: prioritas yg terdekat & udah di tanah biar gak kalah cepet.
            local nearest, nearestDist
            for _, part in ipairs(workspace:GetChildren()) do
                if isCoinPart(part) and isCoinLanded(part) then
                    local d = (part.Position - h.Position).Magnitude
                    if not nearestDist or d < nearestDist then
                        nearest = part
                        nearestDist = d
                    end
                end
            end

            if not nearest then
                task.wait(0.3)
                continue
            end

            pcall(function() hu:MoveTo(nearest.Position) end)
            local reached = false
            local conn = hu.MoveToFinished:Connect(function() reached = true end)
            local startT = tick()
            while coinRainActive and not reached and (tick() - startT) < 2 do
                task.wait(0.05)
                if not nearest.Parent then break end  -- coin collected
            end
            if conn then conn:Disconnect() end
        end
    end)
end

local function stopCoinTP()
    tpConnection = nil
    stopNoclip()
    -- Stop movement
    local hum = getHumanoid()
    if hum then
        pcall(function() hum:MoveTo(getHRP() and getHRP().Position or Vector3.new()) end)
    end
    log("🚶 [coin-rain] Walk STOP")
end

task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:WaitForChild("Remotes", 15)
    if not remotes then return end
    local notifyRem = remotes:WaitForChild("CoinRainNotify", 10)
    if not notifyRem then
        warn2("[coin-rain] CoinRainNotify remote gak ketemu")
        return
    end
    log("✓ [coin-rain] Hooked CoinRainNotify")
    notifyRem.OnClientEvent:Connect(function(text, duration, soundId)
        local dur = tonumber(duration) or 60
        if not CONFIG.AUTO_COIN_RAIN then
            log(("💰 [coin-rain] Event detected (%ds) — auto-collect OFF, manual saja"):format(dur))
            return
        end
        coinRainActive = true
        coinRainEndsAt = tick() + dur
        log(("💰 [coin-rain] Event START — duration: %ds, walking to coins..."):format(dur))
        startCoinTP()
    end)
end)

-- Expose ke getgenv() buat manual trigger / test
getgenv().SambungKata = getgenv().SambungKata or {}
getgenv().SambungKata.ForceCoinRain = function(duration)
    coinRainActive = true
    coinRainEndsAt = tick() + (duration or 30)
    log(("⚡ [coin-rain] FORCED START — duration: %ds"):format(duration or 30))
    startCoinTP()
end
getgenv().SambungKata.StopCoinRain = function()
    coinRainActive = false
    stopCoinTP()
end
getgenv().SambungKata.DebugCoins = function()
    local hrp = getHRP()
    print("HRP:", hrp and hrp:GetFullName() or "nil")
    print("HRP Anchored:", hrp and hrp.Anchored)
    print("HRP CanCollide:", hrp and hrp.CanCollide)
    local count = 0
    for _, part in ipairs(workspace:GetChildren()) do
        if isCoinPart(part) then
            count = count + 1
            if count <= 3 then
                print(("Coin #%d: %s @ %s | dist=%.1f"):format(count, part.Name, tostring(part.Position),
                    hrp and (part.Position - hrp.Position).Magnitude or -1))
            end
        end
    end
    print("Total coins detected:", count)
end

-- Stop pas event abis
task.spawn(function()
    while state.alive do
        task.wait(0.5)
        if coinRainActive and tick() > coinRainEndsAt then
            coinRainActive = false
            stopCoinTP()
            log("💰 [coin-rain] Event END")
        end
    end
end)

------------------------------------------------------------
-- 6.545 LOCAL NAME SPOOF
------------------------------------------------------------
-- Override nama yang ditampilkan di SISI CLIENT KITA aja:
--   - Nametag karakter (Humanoid.DisplayName)
--   - Semua TextLabel/TextButton di PlayerGui yang nyebut nama asli
-- Player lain tetep liat nama asli (server-side gak ke-ubah).
-- 100% local, gak detect oleh anticheat.
local spoofedName = ""    -- target name string (dari Input)
local spoofEnabled = false -- toggle on/off (override total)
-- Effective spoof active = spoofEnabled AND spoofedName ~= ""

local function applySpoofToLabel(lbl)
    if not spoofEnabled or spoofedName == "" or not lbl then return end
    if not (lbl:IsA("TextLabel") or lbl:IsA("TextButton") or lbl:IsA("TextBox")) then return end
    local txt = lbl.Text or ""
    if txt == "" then return end
    local realName = LP.Name
    local realDisp = LP.DisplayName
    local newTxt = txt
    if realName and realName ~= spoofedName then
        newTxt = newTxt:gsub(realName, spoofedName)
    end
    if realDisp and realDisp ~= "" and realDisp ~= spoofedName and realDisp ~= realName then
        newTxt = newTxt:gsub(realDisp, spoofedName)
    end
    if newTxt ~= txt then
        pcall(function() lbl.Text = newTxt end)
    end
end

local function applyAllSpoof()
    if not spoofEnabled or spoofedName == "" then return end
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.DisplayName = spoofedName end) end
        -- CUSTOM NAMETAG: scan BillboardGui labels di character (game pake custom)
        for _, d in ipairs(char:GetDescendants()) do
            applySpoofToLabel(d)
        end
    end
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        applySpoofToLabel(d)
    end
    -- Scan workspace.Players (kalo ada folder yg simpan nametag custom)
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP and p.Character then
            for _, d in ipairs(p.Character:GetDescendants()) do
                applySpoofToLabel(d)
            end
        end
    end
end

-- Hook new GUI elements
PlayerGui.DescendantAdded:Connect(function(d)
    task.wait(0.05)
    applySpoofToLabel(d)
end)

-- Hook character respawn — re-apply ke nametag baru
local function hookCharacter(char)
    -- Apply ke existing children
    for _, d in ipairs(char:GetDescendants()) do
        applySpoofToLabel(d)
    end
    -- Listen new descendants (nametag bisa di-add belakangan)
    char.DescendantAdded:Connect(function(d)
        task.wait(0.1)  -- wait text ke-populate
        applySpoofToLabel(d)
    end)
    task.wait(0.5)
    if spoofEnabled and spoofedName ~= "" then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.DisplayName = spoofedName end) end
        applyAllSpoof()
    end
end
if LP.Character then hookCharacter(LP.Character) end
LP.CharacterAdded:Connect(hookCharacter)

-- Periodic re-apply (safety net buat dynamic text yg di-update game)
task.spawn(function()
    while state.alive do
        task.wait(2)
        if spoofEnabled and spoofedName ~= "" then
            applyAllSpoof()
        end
    end
end)

------------------------------------------------------------
-- 6.546 STEAL SKIN FROM PLAYER (color + effects in one)
------------------------------------------------------------
-- Approach: pilih player lain, clone color Ruas/Batang + semua effects mereka.
-- Sederhana: gak perlu pick skin preset, tinggal copy paket lengkap.
-- Spoof skin senjata bambu di sisi client kita aja. Game cuma ganti
-- COLOR pada part `Ruas` & `Batang` di BackWeapon — kita override di local.
-- Server validate ownership, jadi gak bisa equip skin gak punya server-side.
-- Tapi sisi LOKAL kita bebas ganti warna apapun.
local SKIN_COLORS = {
    BambuHijau     = {ruas=Color3.fromRGB(75,151,75),    batang=Color3.fromRGB(52,142,64)},
    BambuHitam     = {ruas=Color3.fromRGB(40,40,40),     batang=Color3.fromRGB(20,20,20)},
    BambuMerah     = {ruas=Color3.fromRGB(210,55,55),    batang=Color3.fromRGB(160,30,30)},
    BambuBiru      = {ruas=Color3.fromRGB(55,110,210),   batang=Color3.fromRGB(30,70,160)},
    BambuKuning    = {ruas=Color3.fromRGB(240,220,80),   batang=Color3.fromRGB(200,180,40)},
    BambuUngu      = {ruas=Color3.fromRGB(150,80,210),   batang=Color3.fromRGB(110,50,170)},
    BambuPink      = {ruas=Color3.fromRGB(255,150,200),  batang=Color3.fromRGB(220,100,170)},
    BambuPutih     = {ruas=Color3.fromRGB(245,245,245),  batang=Color3.fromRGB(210,210,210)},
    BambuMetalik   = {ruas=Color3.fromRGB(190,195,210),  batang=Color3.fromRGB(130,135,155)},
    BambuEs        = {ruas=Color3.fromRGB(180,230,255),  batang=Color3.fromRGB(130,200,240)},
    BambuApi       = {ruas=Color3.fromRGB(255,100,30),   batang=Color3.fromRGB(220,55,20)},
    BambuMerahPutih= {ruas=Color3.fromRGB(220,50,50),    batang=Color3.fromRGB(245,245,245)},
    BambuPelangi   = {special="rainbow"},
    BambuHati      = {ruas=Color3.fromRGB(255,90,130),   batang=Color3.fromRGB(220,40,90)},
    BambuAwan      = {ruas=Color3.fromRGB(225,235,250),  batang=Color3.fromRGB(180,200,235)},
    BambuBayang    = {ruas=Color3.fromRGB(70,70,90),     batang=Color3.fromRGB(35,35,55)},
    BambuLava      = {ruas=Color3.fromRGB(255,80,25),    batang=Color3.fromRGB(150,30,15)},
    BambuEmas      = {ruas=Color3.fromRGB(255,215,80),   batang=Color3.fromRGB(220,170,40)},
    BambuApiV2     = {ruas=Color3.fromRGB(255,160,40),   batang=Color3.fromRGB(255,70,15)},
    BambuPetir     = {ruas=Color3.fromRGB(255,255,150),  batang=Color3.fromRGB(220,200,60)},
    BambuSalju     = {ruas=Color3.fromRGB(248,250,255),  batang=Color3.fromRGB(220,225,245)},
    BambuLavender  = {ruas=Color3.fromRGB(200,180,235),  batang=Color3.fromRGB(160,140,210)},
    ["Bambu1x1x1x1"]={ruas=Color3.fromRGB(255,255,255),  batang=Color3.fromRGB(255,255,255)},
    BambuDaun      = {ruas=Color3.fromRGB(120,200,90),   batang=Color3.fromRGB(70,150,55)},
    BambuKemarau   = {ruas=Color3.fromRGB(190,160,80),   batang=Color3.fromRGB(140,110,50)},
    BambuPrismatik = {special="prismatic"},
    BambuRobux     = {ruas=Color3.fromRGB(60,200,90),    batang=Color3.fromRGB(0,160,50)},
    BambuJuara     = {ruas=Color3.fromRGB(255,215,0),    batang=Color3.fromRGB(200,170,30)},
}

local spoofedSkin = ""

local function getBackWeapon()
    local char = LP.Character
    if not char then return nil end
    return char:FindFirstChild("BackWeapon")
end

local applyingSpoof = false  -- guard biar gak infinite loop dari Changed signal

local function applySkinSpoof()
    if spoofedSkin == "" or applyingSpoof then return end
    local skin = SKIN_COLORS[spoofedSkin]
    if not skin then return end
    local bw = getBackWeapon()
    if not bw then return end
    local ruasColor = skin.ruas
    local batangColor = skin.batang
    if skin.special == "rainbow" then
        local hue = (tick() * 0.3) % 1
        ruasColor = Color3.fromHSV(hue, 1, 1)
        batangColor = Color3.fromHSV((hue + 0.5) % 1, 1, 0.85)
    elseif skin.special == "prismatic" then
        local hue = (tick() * 0.15) % 1
        ruasColor = Color3.fromHSV(hue, 0.6, 1)
        batangColor = Color3.fromHSV((hue + 0.3) % 1, 0.7, 0.9)
    end
    applyingSpoof = true
    for _, p in ipairs(bw:GetDescendants()) do
        if p:IsA("BasePart") or p:IsA("UnionOperation") then
            local target
            if p.Name == "Ruas" then target = ruasColor
            elseif p.Name == "Batang" then target = batangColor end
            if target then
                pcall(function()
                    -- UnionOperation: harus UsePartColor=true biar .Color kelihatan
                    if p:IsA("UnionOperation") then
                        p.UsePartColor = true
                    end
                    p.Color = target
                    -- Material override: hindari clear/glass yg bikin visual aneh
                    if p.Material == Enum.Material.Glass or p.Material == Enum.Material.ForceField then
                        p.Material = Enum.Material.Plastic
                    end
                end)
            end
        end
    end
    applyingSpoof = false
end

-- Hook character + BackWeapon untuk auto re-apply pas respawn / re-equip
local hookedParts = {}  -- track parts yang udah ke-hook

local function hookPart(p)
    if hookedParts[p] then return end
    if not (p:IsA("BasePart") or p:IsA("UnionOperation")) then return end
    if p.Name ~= "Ruas" and p.Name ~= "Batang" then return end
    hookedParts[p] = true
    -- Listen color change → instant re-apply (lawan server replicate)
    p:GetPropertyChangedSignal("Color"):Connect(function()
        if spoofedSkin ~= "" then applySkinSpoof() end
    end)
end

local function hookBackWeapon(bw)
    if bw.Name ~= "BackWeapon" then return end
    task.wait(0.1)
    -- Hook all existing Ruas/Batang
    for _, d in ipairs(bw:GetDescendants()) do hookPart(d) end
    applySkinSpoof()
    -- Future descendants
    bw.DescendantAdded:Connect(function(d)
        task.wait(0.05)
        hookPart(d)
        applySkinSpoof()
    end)
end

local function hookCharForSkin(char)
    local bw = char:FindFirstChild("BackWeapon")
    if bw then hookBackWeapon(bw) end
    char.ChildAdded:Connect(function(c)
        if c.Name == "BackWeapon" then hookBackWeapon(c) end
    end)
end
if LP.Character then hookCharForSkin(LP.Character) end
LP.CharacterAdded:Connect(hookCharForSkin)

-- Periodic re-apply (juga handle special animated skins)
task.spawn(function()
    while state.alive do
        local skin = SKIN_COLORS[spoofedSkin]
        local interval = (skin and skin.special) and 0.05 or 1.5
        task.wait(interval)
        if spoofedSkin ~= "" then applySkinSpoof() end
    end
end)

-- ─── Effect Cloning (steal effects dari player lain) ───
local clonedEffects = {}  -- track buat cleanup
local effectsEnabled = false

local function listEffectSources()
    -- Return array of {player, batang, effectCount} sorted by effect count (less = cleaner)
    local sources = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local bw = p.Character:FindFirstChild("BackWeapon")
            local batang = bw and bw:FindFirstChild("Batang")
            if batang then
                local count = 0
                for _, c in ipairs(batang:GetChildren()) do
                    if c:IsA("ParticleEmitter") or c:IsA("Beam") or c:IsA("PointLight")
                       or c:IsA("Trail") or (c:IsA("Model") and c.Name == "start") then
                        count = count + 1
                    end
                end
                if count > 0 then
                    table.insert(sources, {player=p, batang=batang, count=count})
                end
            end
        end
    end
    table.sort(sources, function(a, b) return a.count < b.count end)  -- simpler first
    return sources
end

local sourceCycleIdx = 0
local function findEffectSource()
    local sources = listEffectSources()
    if #sources == 0 then return nil, nil end
    sourceCycleIdx = (sourceCycleIdx % #sources) + 1
    local s = sources[sourceCycleIdx]
    return s.batang, s.player.Name
end

local function clearClonedEffects()
    for _, e in ipairs(clonedEffects) do pcall(function() e:Destroy() end) end
    clonedEffects = {}
end

local function cloneEffectsToOurWeapon()
    clearClonedEffects()
    local src, srcName = findEffectSource()
    if not src then
        warn2("[skin-spoof] Gak nemu player lain dgn effects untuk di-clone")
        return false, nil
    end
    local ourBw = getBackWeapon()
    local ourBatang = ourBw and ourBw:FindFirstChild("Batang")
    if not ourBatang then
        warn2("[skin-spoof] BackWeapon.Batang kita gak ketemu")
        return false, nil
    end
    local count = 0
    for _, e in ipairs(src:GetChildren()) do
        local cloneable = e:IsA("ParticleEmitter") or e:IsA("PointLight")
            or e:IsA("Trail") or e:IsA("Attachment")
        -- SKIP top-level Beams (attachments biasanya gak match → visual ngaco)
        -- "start" model contains Beams with internal attachments (safer to clone)
        if e:IsA("Model") and e.Name == "start" then cloneable = true end
        if cloneable then
            local ok, cl = pcall(function() return e:Clone() end)
            if ok and cl then
                cl.Parent = ourBatang
                table.insert(clonedEffects, cl)
                count = count + 1
            end
        end
    end
    log(("✨ [skin-spoof] Cloned %d effects from %s"):format(count, srcName or "?"))
    return true, srcName
end

-- Re-clone effects pas character respawn (effects ke-destroy bareng old char)
LP.CharacterAdded:Connect(function()
    task.wait(2)
    if effectsEnabled and spoofedSkin ~= "" then
        cloneEffectsToOurWeapon()
    end
end)

-- ═══════════════════════════════════════════════════════════
-- UNIFIED STEAL: clone color + effects dari satu source player
-- ═══════════════════════════════════════════════════════════
local stolenFromPlayer = ""  -- nama player source aktif
local stolenColors = nil     -- {ruas=Color3, batang=Color3}
local stolenEffects = {}     -- list cloned effects
local originalColors = nil   -- backup color asli buat restore pas clear

local function captureOriginalColors()
    if originalColors then return end  -- already captured, jangan timpa
    local bw = LP.Character and LP.Character:FindFirstChild("BackWeapon")
    if not bw then return end
    local ruas = bw:FindFirstChild("Ruas")
    local batang = bw:FindFirstChild("Batang")
    if ruas and batang then
        originalColors = {ruas = ruas.Color, batang = batang.Color}
        log(("📸 [steal-skin] Captured original: Ruas=%s Batang=%s"):format(
            tostring(originalColors.ruas), tostring(originalColors.batang)))
    end
end

local function clearStolenEffects()
    for _, e in ipairs(stolenEffects) do pcall(function() e:Destroy() end) end
    stolenEffects = {}
end

local function applyStolenColors()
    if not stolenColors then return end
    local bw = getBackWeapon()
    if not bw then return end
    applyingSpoof = true
    for _, p in ipairs(bw:GetDescendants()) do
        if p:IsA("BasePart") or p:IsA("UnionOperation") then
            local target
            if p.Name == "Ruas" then target = stolenColors.ruas
            elseif p.Name == "Batang" then target = stolenColors.batang end
            if target then
                pcall(function()
                    if p:IsA("UnionOperation") then p.UsePartColor = true end
                    p.Color = target
                end)
            end
        end
    end
    applyingSpoof = false
end

-- Match colors → cari nama skin terdekat dari SKIN_COLORS preset
local function colorDistance(c1, c2)
    local dr = c1.R - c2.R
    local dg = c1.G - c2.G
    local db = c1.B - c2.B
    return dr*dr + dg*dg + db*db
end

local function identifySkinByColor(ruasC, batangC)
    local bestName = nil
    local bestDist = math.huge
    for name, data in pairs(SKIN_COLORS) do
        if data.ruas and data.batang then
            -- Normalize SKIN_COLORS to 0-1 range (they were RGB 0-255)
            local dist = colorDistance(ruasC, data.ruas) + colorDistance(batangC, data.batang)
            if dist < bestDist then
                bestDist = dist
                bestName = name
            end
        end
    end
    return bestName, bestDist
end

local stolenSkinName = ""  -- nama skin yg ke-detect

local function stealFromPlayer(srcPlayer)
    -- Capture original sebelum modify (cuma 1x, idempotent)
    captureOriginalColors()
    -- Clear previous
    clearStolenEffects()
    stolenColors = nil
    stolenFromPlayer = ""
    stolenSkinName = ""

    if not srcPlayer or not srcPlayer.Character then return false, "no character" end
    local srcBw = srcPlayer.Character:FindFirstChild("BackWeapon")
    if not srcBw then return false, "no BackWeapon" end
    local srcBatang = srcBw:FindFirstChild("Batang")
    local srcRuas = srcBw:FindFirstChild("Ruas")
    if not (srcBatang and srcRuas) then return false, "missing parts" end

    -- Capture colors
    stolenColors = {ruas = srcRuas.Color, batang = srcBatang.Color}

    -- Identify skin name dari color signature
    local guessedName = identifySkinByColor(stolenColors.ruas, stolenColors.batang)
    stolenSkinName = guessedName or "Unknown"

    -- Apply colors
    applyStolenColors()

    -- Clone effects (skip semua Beam — attachments-nya selalu broken setelah clone)
    local ourBw = getBackWeapon()
    local ourBatang = ourBw and ourBw:FindFirstChild("Batang")
    local fxCount = 0
    if ourBatang then
        for _, e in ipairs(srcBatang:GetChildren()) do
            local cloneable = e:IsA("ParticleEmitter") or e:IsA("PointLight")
                or e:IsA("Trail") or e:IsA("Attachment")
                or (e:IsA("Model") and e.Name == "start")
            if cloneable then
                local ok, cl = pcall(function() return e:Clone() end)
                if ok and cl then
                    -- Strip semua Beam dari clone (recursive) — attachments cross-tree broken
                    for _, d in ipairs(cl:GetDescendants()) do
                        if d:IsA("Beam") then
                            pcall(function() d:Destroy() end)
                        end
                    end
                    if cl:IsA("Beam") then
                        pcall(function() cl:Destroy() end)
                    else
                        cl.Parent = ourBatang
                        table.insert(stolenEffects, cl)
                        fxCount = fxCount + 1
                    end
                end
            end
        end
    end

    stolenFromPlayer = srcPlayer.Name
    log(("👤 [steal-skin] Stolen %s from %s | %d effects"):format(stolenSkinName, srcPlayer.Name, fxCount))
    return true, stolenSkinName
end

local function clearStealSkin()
    clearStolenEffects()
    -- Restore original colors (kalo ada backup)
    if originalColors then
        stolenColors = originalColors  -- pakai struktur yg sama biar applyStolenColors work
        applyStolenColors()
    end
    stolenColors = nil
    stolenFromPlayer = ""
    stolenSkinName = ""
    log("👤 [steal-skin] Cleared — restored original skin")
end

-- Cycle through other players (skip default green skin)
local DEFAULT_RUAS = Color3.fromRGB(75, 151, 75)  -- BambuHijau approx
local function isDefaultGreen(c)
    return c.G > c.R and c.G > c.B and c.G > 0.4 and c.R < 0.45 and c.B < 0.45
end

local stealCycleIdx = 0
local function stealNextPlayer()
    local candidates = {}  -- semua kandidat
    local interesting = {}  -- yang skin-nya beda dari default
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local bw = p.Character:FindFirstChild("BackWeapon")
            if bw then
                table.insert(candidates, p)
                local ruas = bw:FindFirstChild("Ruas")
                local batang = bw:FindFirstChild("Batang")
                local hasFx = false
                if batang then
                    for _, c in ipairs(batang:GetChildren()) do
                        if c:IsA("ParticleEmitter") or c:IsA("PointLight")
                           or c:IsA("Trail") or (c:IsA("Model") and c.Name == "start") then
                            hasFx = true; break
                        end
                    end
                end
                local nonDefault = (ruas and not isDefaultGreen(ruas.Color)) or hasFx
                if nonDefault then
                    table.insert(interesting, p)
                end
            end
        end
    end
    -- Prefer interesting players; fallback ke semua kalo gak ada
    local pool = #interesting > 0 and interesting or candidates
    if #pool == 0 then return false, nil end
    stealCycleIdx = (stealCycleIdx % #pool) + 1
    local p = pool[stealCycleIdx]
    local ok, skinName = stealFromPlayer(p)
    return ok, p.Name, skinName
end

-- Re-apply pas character respawn
LP.CharacterAdded:Connect(function()
    task.wait(2)
    -- Reset original capture (skin server-side mungkin udah berubah pas respawn)
    originalColors = nil
    captureOriginalColors()
    if stolenFromPlayer ~= "" then
        local p = Players:FindFirstChild(stolenFromPlayer)
        if p then stealFromPlayer(p) end
    end
end)
-- Initial capture pas script load (kalo character udah ada)
task.spawn(function()
    task.wait(1)
    captureOriginalColors()
end)

-- Periodic re-apply colors (lawan server replicate)
task.spawn(function()
    while state.alive do
        task.wait(1.5)
        if stolenColors then applyStolenColors() end
    end
end)

------------------------------------------------------------
-- 6.55 ANTI-AFK
------------------------------------------------------------
-- Roblox auto-kick player setelah 20 menit idle. Hook Player.Idled event
-- (fire ~60 detik sebelum kick) → simulate input biar reset timer.
-- Plus: periodic VIM keypress (Space) tiap 4 menit sebagai backup.
LP.Idled:Connect(function(idleTime)
    log(("⚡ [anti-afk] Idled %ds, jiggle input biar gak ke-kick"):format(math.floor(idleTime)))
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        -- Press & release Space (gak bakal ngeganggu typing karena bot udah handle TextBox)
        VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
    -- Optional: unseat & re-seat untuk reset character idle (kalo lagi duduk di table)
    pcall(function()
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Sit then
            hum.Jump = true  -- mini jump, gak perlu unseat manual
        end
    end)
end)

-- Backup: periodic invisible keypress tiap 4 menit (jaga-jaga kalau Idled gak fire)
task.spawn(function()
    while state.alive do
        task.wait(240)  -- 4 menit
        if not state.alive then break end
        pcall(function()
            local VIM = game:GetService("VirtualInputManager")
            -- Pakai LeftAlt (gak konflik sama input game)
            VIM:SendKeyEvent(true, Enum.KeyCode.LeftAlt, false, game)
            task.wait(0.04)
            VIM:SendKeyEvent(false, Enum.KeyCode.LeftAlt, false, game)
        end)
        log("⏰ [anti-afk] periodic jiggle (every 4min)")
    end
end)

------------------------------------------------------------
-- 6.6 AUTO-VOTE GAME MODE
------------------------------------------------------------
-- Pas voting phase (ModeUI muncul), otomatis fire GameModeVote remote.
-- Detection: ModeUI.Enabled atau Visible jadi true.
-- Throttle: cuma fire 1x per voting cycle (track via lastVoteAt).
local votedThisCycle = false
local function isVotingActive()
    local modeUI = PlayerGui:FindFirstChild("ModeUI")
    if not modeUI then return false end
    -- Cek visible/enabled
    if modeUI:IsA("ScreenGui") and modeUI.Enabled then return true end
    -- Cek any visible voting frame inside
    for _, d in ipairs(modeUI:GetDescendants()) do
        if d:IsA("Frame") and d.Visible and (d.Name:lower():find("vot") or d.Name:lower():find("mode")) then
            return true
        end
    end
    return false
end

-- Cari button vote di ModeUI yang text/name-nya match modeName
local function findVoteButton(modeName)
    local modeUI = PlayerGui:FindFirstChild("ModeUI")
    if not modeUI then return nil end
    local target = modeName:lower()
    for _, obj in ipairs(modeUI:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("TextLabel"))
           and obj.Visible and obj.AbsoluteSize.X > 20 then
            local txt = (obj:IsA("TextLabel") or obj:IsA("TextButton")) and (obj.Text or ""):lower() or ""
            local nm = (obj.Name or ""):lower()
            if txt:find(target) or nm:find(target) then
                -- Cari ancestor TextButton/ImageButton kalo ini cuma TextLabel
                local clickable = obj
                if obj:IsA("TextLabel") then
                    local p = obj.Parent
                    while p and p ~= modeUI do
                        if p:IsA("TextButton") or p:IsA("ImageButton") then
                            clickable = p
                            break
                        end
                        p = p.Parent
                    end
                end
                return clickable
            end
        end
    end
    return nil
end

local function fireVote(modeName)
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:FindFirstChild("Remotes")
    if not remotes then return false end
    local voteRemote = remotes:FindFirstChild("GameModeVote")
    if not voteRemote then
        warn2("[auto-vote] GameModeVote remote gak ketemu")
        return false
    end

    -- Strategy A: simulate REAL CLICK on vote button (paling legit, lolos anticheat)
    local btn = findVoteButton(modeName)
    if btn and (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local cx = pos.X + size.X / 2 + (math.random() - 0.5) * 6
        local cy = pos.Y + size.Y / 2 + (math.random() - 0.5) * 4
        local VIM = game:GetService("VirtualInputManager")
        pcall(function()
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.05 + math.random() * 0.05)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        end)
        log(("🗳️ [auto-vote] CLICK button: %s @ (%d,%d)"):format(modeName, cx, cy))
        return true
    end

    -- Strategy B: fallback ke direct FireServer (bisa di-detect anticheat)
    local ok, err = pcall(function()
        voteRemote:FireServer(modeName)
    end)
    if ok then
        log(("🗳️ [auto-vote] Fired remote: %s (button gak ketemu)"):format(modeName))
        return true
    else
        warn2("[auto-vote] Gagal fire:", err)
        return false
    end
end

-- Hook GameModeVote.OnClientEvent — server fire "Start" pas voting mulai,
-- "Result" pas selesai. Detection 100% reliable, gak perlu polling UI.
-- Flag `votedThisCycle` cuma di-reset pas Start event (BUKAN Result),
-- biar gak double-fire vote setelah voting selesai.
local primaryHookOk = false
task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs:WaitForChild("Remotes", 10)
    if not remotes then return end
    local gmVote = remotes:WaitForChild("GameModeVote", 10)
    if not gmVote then
        warn2("[auto-vote] GameModeVote remote gak ketemu di Remotes folder")
        return
    end
    primaryHookOk = true
    log("✓ [auto-vote] Hooked GameModeVote.OnClientEvent")
    gmVote.OnClientEvent:Connect(function(eventName, data)
        if eventName == "Start" then
            votedThisCycle = false  -- new cycle, ready to vote
            modeFromVote = false    -- unlock biar Result event next bisa update mode
            if CONFIG.AUTO_VOTE_MODE == "off" then return end
            -- IMPORTANT: set flag SEKARANG (sebelum task.wait) biar fallback
            -- loop gak ikutan fire double.
            votedThisCycle = true
            task.wait(0.3 + math.random() * 0.5)
            fireVote(CONFIG.AUTO_VOTE_MODE)
        elseif eventName == "Result" then
            log("[auto-vote] Result:", tostring(data))
            -- AUTHORITATIVE MODE DETECTION: server kasih tau mode mana yg menang.
            -- Lebih reliable daripada heuristic prefix length.
            -- Format `data` bisa string ("Santai"/"Normal"/"Brutal") atau table.
            local winMode
            if type(data) == "string" then
                winMode = data
            elseif type(data) == "table" then
                winMode = data.Mode or data.mode or data.Winner or data[1]
            end
            if type(winMode) == "string" then
                for _, m in ipairs({"Santai", "Normal", "Brutal"}) do
                    if winMode:lower():find(m:lower()) then
                        detectedMode = m
                        modeFromVote = true  -- LOCK: heuristic gak boleh override
                        log("🎮 Mode SET via vote result:", m, "(authoritative)")
                        break
                    end
                end
            end
            -- JANGAN reset votedThisCycle di sini (biar fallback gak fire ulang
            -- saat ModeUI masih sempet keliatan briefly setelah Result).
        end
    end)
end)

-- Fallback: polling ModeUI — cuma jalan kalo Strategy 1 GAGAL hook
task.spawn(function()
    task.wait(3)  -- kasih waktu Strategy 1 hook dulu
    if primaryHookOk then return end
    log("⚠️ [auto-vote] Pakai UI polling fallback (primary hook gagal)")
    while state.alive do
        task.wait(0.5)
        if CONFIG.AUTO_VOTE_MODE == "off" then continue end
        if not isVotingActive() then
            votedThisCycle = false
            continue
        end
        if votedThisCycle then continue end
        votedThisCycle = true  -- set dulu sebelum delay
        task.wait(0.2 + math.random() * 0.3)
        if isVotingActive() then
            fireVote(CONFIG.AUTO_VOTE_MODE)
        end
    end
end)

------------------------------------------------------------
-- 7. GUI (WindUI Boreal)
------------------------------------------------------------
-- Loader: load WindUI Boreal w/ caching, fallback ke standard kalau gagal.
local function attemptLoadLib(url, fileName)
    local folder = "SambungKata/Libraries"
    local localPath = fileName and (folder .. "/" .. fileName) or nil
    -- Try cache dulu
    if localPath and isfile and isfile(localPath) then
        local ok, content = pcall(readfile, localPath)
        if ok and content and #content > 100 then
            local fn, _ = loadstring(content)
            if fn then
                local s, r = pcall(fn)
                if s and r then return r end
            end
        end
    end
    -- Download
    local ok, content = pcall(game.HttpGet, game, url)
    if ok and content and #content > 100 then
        if localPath and makefolder and writefile then
            pcall(function()
                if not isfolder("SambungKata") then makefolder("SambungKata") end
                if not isfolder(folder) then makefolder(folder) end
                writefile(localPath, content)
            end)
        end
        local fn = loadstring(content)
        if fn then
            local s, r = pcall(fn)
            return s and r or nil
        end
    end
    return nil
end

-- BOREAL ONLY — gak fallback ke Standard karena MultiSection API cuma ada di Boreal.
-- Verify via test window: kalo Tab gak punya :MultiSection, berarti bukan Boreal → invalidate cache.
local function isBoreal(lib)
    if type(lib) ~= "table" or type(lib.CreateWindow) ~= "function" then
        return false
    end
    -- Boreal-specific signature: WindowConfig.SideBarWidth, MultiSection method
    -- Quick test: bikin dummy window + tab, cek :MultiSection ada gak
    local ok, hasMulti = pcall(function()
        -- Beberapa Boreal version expose method di window directly via metatable.
        -- Cara aman: cek via dummy createwindow & test tab.
        if rawget(lib, "_isBoreal") or _G.WindUIIsBoreal then return true end
        return nil
    end)
    if ok and hasMulti then return true end
    return nil  -- unknown, assume valid sampai test in-place
end

local function clearCacheAndRetry()
    pcall(function()
        if delfile and isfile and isfile("SambungKata/Libraries/WindUI_Boreal.lua") then
            delfile("SambungKata/Libraries/WindUI_Boreal.lua")
            warn2("🧹 Cache WindUI cleared, retry download...")
        end
    end)
end

local WindUI
local sources = {
    "https://raw.githubusercontent.com/billy17-netizen/windUIBoreal/refs/heads/main/WindUI_Boreal.lua",
    "https://raw.githubusercontent.com/orialdev/WindUI-Boreal/main/WindUI%20Boreal",
}
for _, url in ipairs(sources) do
    WindUI = attemptLoadLib(url, "WindUI_Boreal.lua")
    if WindUI then break end
end

if not WindUI then
    warn2("❌ Gagal load WindUI Boreal — cek koneksi atau hapus manual SambungKata/Libraries/WindUI_Boreal.lua")
    return
end

state.suggesterEnabled = false  -- forward-declare biar suggester section bisa pake

local Window = WindUI:CreateWindow({
    Title = "STARSHIP┃dsc.gg-starshipcore",
    Icon = "rbxassetid://85930777472774", 
    IconSize = 45, 
    Author = "Premium Edition | StarshipCore",
 	Size = UDim2.fromOffset(650, 350),
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
    
    RunService.Heartbeat:Connect(function() frameCount = frameCount + 1 end)
    
    while state.alive do
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
pcall(function() Window:SetToggleKey(Enum.KeyCode.LeftControl) end)
pcall(function()
    WindUI:Notify({ Title = "⌨️ Shortcut", Content = "Tekan 'Left Control' untuk buka/tutup GUI", Duration = 3 })
end)

-- Hook WindUI close (X button bawaan) → full shutdown bot biar gak jalan di background.
-- Tanpa hook ini, user close window tapi semua loop tetep jalan = waste CPU + log spam.
local function fullShutdown()
    if not state.alive then return end  -- prevent double-shutdown
    state.enabled = false
    state.alive = false
    -- Set global flag biar log() & semua signal callback langsung silent.
    _G.__SK_DEAD = true
    if getgenv and getgenv().SambungKata then
        getgenv().SambungKata = nil
    end
    -- Destroy suggester GUI juga (separate ScreenGui)
    pcall(function()
        if sugGui then sugGui:Destroy() end
    end)
    -- log udah silent karena __SK_DEAD true. Print konfirmasi cuma di non-production.
    if not PRODUCTION_SILENT then
        print("[SambungKata] ✓ Bot fully terminated (semua loop & log dimatiin)")
    end
end
-- ─── WindUI Close/Destroy Hooks ───
-- IMPORTANT: X button di Boreal = MINIMIZE (window hidden, OpenButton muncul → klik restore).
-- Kita TIDAK trigger shutdown pas OnClose — biar minimize/restore flow bekerja normal.
-- Shutdown CUMA pas OnDestroy fire (Window:Destroy() dipanggil eksplisit, biasanya dari API).
local hookFired = false

pcall(function()
    Window:OnClose(function()
        -- Minimize event — JANGAN shutdown, biar OpenButton bisa restore.
        log("[WindUI] OnClose fired (minimize) — OpenButton aktif")
    end)
end)
pcall(function()
    Window:OnDestroy(function()
        if hookFired then return end
        hookFired = true
        log("[WindUI] OnDestroy fired → shutdown bot")
        fullShutdown()
    end)
end)

-- Failsafe poll: kalo OnClose/OnDestroy hooks gak fire (API beda),
-- detect via Window.Instance ancestry. Khusus Boreal: cek juga internal frame visibility.
task.spawn(function()
    task.wait(3)
    while state.alive do
        task.wait(1.5)
        if hookFired then break end  -- udah ditrigger via official hook
        local stillExists = false
        pcall(function()
            if Window then
                -- Cek 1: Window.Instance ada di game tree
                if Window.Instance and Window.Instance:IsDescendantOf(game) then
                    stillExists = true
                end
                -- Cek 2: Internal background frame
                if not stillExists and Window.Internal and Window.Internal.Background
                   and Window.Internal.Background.Parent then
                    stillExists = true
                end
                -- Cek 3: ScreenGui WindUI (Boreal sometimes parent ke CoreGui)
                if not stillExists then
                    local coreGui = (gethui and gethui()) or game:GetService("CoreGui")
                    for _, sg in ipairs(coreGui:GetChildren()) do
                        if sg:IsA("ScreenGui") and (sg.Name:find("Wind") or sg.Name:find("wind")) then
                            stillExists = true
                            break
                        end
                    end
                end
            end
        end)
        if not stillExists then
            log("👁️ [watchdog] WindUI window udah ditutup → auto shutdown")
            fullShutdown()
            break
        end
    end
end)

-- Forward declare yg perlu di-akses dari luar (suggester section).
local suggesterToggle

-- Wrap semua tab/section/element creation di IIFE biar register pool main chunk gak meledak.
-- Lua 5.1 limit 200 locals per function — tanpa wrap ini, suggester section di line 4380 crash
-- "Out of local registers". IIFE bikin scope baru, locals gak counted ke main chunk.
local function _buildMainGUI()

-- Tabs (tiap tab pake MultiSection biar grouping rapi pake sub-tabs)
local DashboardTab= Window:Tab({ Title = "Dashboard",Icon = "layout-grid" })
local StrategyTab = Window:Tab({ Title = "Strategy", Icon = "crosshair" })
local AutoTab     = Window:Tab({ Title = "Otomasi",  Icon = "bot" })
local VisualTab   = Window:Tab({ Title = "Visual",   Icon = "eye" })
local MiscTab     = Window:Tab({ Title = "Misc",     Icon = "ellipsis" })

-- ─── Compatibility wrapper buat MultiSection ───
-- Boreal punya :MultiSection() yg create container dgn sub-tabs.
-- Standard WindUI gak punya — kita fallback: return wrapper yg bikin Section sebagai
-- visual divider gantinya sub-tab. Semua call sub:Section/Toggle/Button forward ke Tab asli.
local function safeMultiSection(tab, opts)
    if tab.MultiSection then
        return tab:MultiSection(opts)
    end
    -- Fallback wrapper
    local wrapper = {}
    function wrapper:Tab(subOpts)
        -- Add Section as visual separator pake title sub-tab
        if subOpts and subOpts.Title then
            pcall(function()
                tab:Section({ Title = "▶ " .. subOpts.Title, Icon = subOpts.Icon })
            end)
        end
        return tab  -- semua call (sub:Toggle, sub:Button) langsung ke tab
    end
    return wrapper
end

-- ════════════════════ DASHBOARD TAB ════════════════════
-- Content: Information (welcome/script info) + Account (VIP + user profile)
local DashMulti = safeMultiSection(DashboardTab, {
    Title = "Dashboard Hub",
    Icon = "layout-grid",
    Box = true,
    BoxBorder = true,
    Opened = true,
})
local infoSub    = DashMulti:Tab({ Title = "Information", Icon = "info" })
local accountSub = DashMulti:Tab({ Title = "Account",     Icon = "user" })

-- ─── Information Sub-Tab ───
infoSub:Section({ Title = "Welcome" })
infoSub:Paragraph({
    Title = ("👋 Hello, %s!"):format(LP.DisplayName or LP.Name),
    Content = "Selamat datang di SambungKata Premium Bot.\n"
           .. "Pilih tab Strategy buat aktifin Auto Play & atur preset.",
})

infoSub:Section({ Title = "Script Information" })
local executor2 = (identifyexecutor and identifyexecutor()) or "Unknown"
local platformName = "Windows"
pcall(function() platformName = UserInputSvc:GetPlatform().Name end)
infoSub:Paragraph({
    Title = "🛠️ Environment",
    Content = ("Executor: %s\nPlatform: %s\nWords loaded: %d\nBuild: SambungKata v8.0"):format(
        executor2, platformName, totalWords
    ),
})

-- ─── Account Sub-Tab (VIP info + user profile) ───
accountSub:Section({ Title = "VIP Status", Icon = "star" })

-- Hitung expiry sekali (lifetime = nil, durasi → unix timestamp)
local vipExpiryTime = nil
if sessionData.Expiry then
    vipExpiryTime = tonumber(sessionData.Expiry)
else
    vipExpiryTime = ParseVIPExpiry(sessionData.Duration)
    sessionData.Expiry = vipExpiryTime  -- persist (avoid recompute)
end

local function GetVIPStatusDesc()
    local timeRemaining = "Lifetime"
    if vipExpiryTime then
        timeRemaining = FormatTimeRemaining(vipExpiryTime - os.time())
    end
    return ("Role: %s\nTime Remaining: %s\nStatus: 🟢 Active"):format(
        FormatRole(sessionData.Role), timeRemaining
    )
end

local vipPara = accountSub:Paragraph({
    Title = "Subscription Information",
    Content = GetVIPStatusDesc(),
})

-- Live countdown updater (cuma jalan kalo VIP punya expiry, bukan Lifetime)
if vipExpiryTime then
    task.spawn(function()
        while state.alive and not _G.__SK_DEAD do
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

accountSub:Section({ Title = "User Profile", Icon = "user-round" })
accountSub:Paragraph({
    Title = LP.DisplayName or LP.Name,
    Content = ("Username: @%s\nUser ID: %d\nDisplay: %s\nMembership: %s\nAccount Age: %d days"):format(
        LP.Name,
        LP.UserId,
        LP.DisplayName or LP.Name,
        tostring(LP.MembershipType):gsub("Enum.MembershipType.", ""),
        LP.AccountAge or 0
    ),
})

-- ════════════════════ STRATEGY TAB ════════════════════
-- Content: Controls (Auto Play, Suggester) + Modes + Selection + Presets
-- Force kbinput permanent (paling aman + anti-detect, gak butuh user pilih)
CONFIG.INPUT_MODE = "kbinput"

local StrategyMulti = safeMultiSection(StrategyTab, {
    Title = "Word Strategy",
    Icon = "crosshair",
    Box = true,
    BoxBorder = true,
    Opened = true,
})
local controlSub = StrategyMulti:Tab({ Title = "Controls",  Icon = "mouse-pointer" })
local modeSub    = StrategyMulti:Tab({ Title = "Modes",     Icon = "settings" })
local pickSub    = StrategyMulti:Tab({ Title = "Selection", Icon = "list-filter" })
local presetSub  = StrategyMulti:Tab({ Title = "Presets",   Icon = "zap" })

-- ─── Controls Sub-Tab ───
controlSub:Section({ Title = "Primary Toggles" })
local autoPlayToggle = controlSub:Toggle({
    Title = "Auto Play",
    Desc = "Bot otomatis ngetik & submit kata pas giliran kamu",
    Value = false,
    Callback = function(v) state.enabled = v end,
})

-- Assign ke outer forward-declared var biar suggester section bisa akses.
suggesterToggle = controlSub:Toggle({
    Title = "💡 Suggester",
    Desc = "Tampilin 10 saran kata pas giliran kamu (cuma di match)",
    Value = false,
    Callback = function(v)
        state.suggesterEnabled = v
        log("Suggester:", v and "ON (cuma muncul saat in match)" or "OFF")
    end,
})

-- ─── Modes Sub-Tab ───
modeSub:Section({ Title = "Interaction Style" })
modeSub:Dropdown({
    Title = "Interaction Mode",
    Desc = "human=natural (typo+hesitate+break), bot=perfect speed",
    Values = {"human", "bot"},
    Value = CONFIG.INTERACTION_MODE or "human",
    Callback = function(v)
        CONFIG.INTERACTION_MODE = v
        log("Interaction:", v)
    end,
})

pickSub:Section({ Title = "Word Selection Strategy" })
pickSub:Toggle({
    Title = "Sabotage Mode",
    Desc = "Prioritas kata dgn ending huruf langka (Q/X/Z/F) biar opponent stuck",
    Value = CONFIG.SABOTAGE_MODE or false,
    Callback = function(v) CONFIG.SABOTAGE_MODE = v end,
})
pickSub:Toggle({
    Title = "Always Get New Index",
    Desc = "Skip kata yg udah collected — force pilih kata fresh aja (grow Index cepet)",
    Value = CONFIG.ALWAYS_NEW_ONLY or false,
    Callback = function(v) CONFIG.ALWAYS_NEW_ONLY = v end,
})

presetSub:Section({ Title = "Quick Configuration" })
local function applyPreset(name)
    if getgenv().SambungKata and getgenv().SambungKata.SetPreset then
        getgenv().SambungKata.SetPreset(name)
        log("Preset applied:", name)
    end
end
presetSub:Button({
    Title = "⚡ Speedrun Preset",
    Desc = "Maximum speed, no human delays — risiko detection tinggi",
    Callback = function() applyPreset("speedrun") end,
})
presetSub:Button({
    Title = "🎮 Casual Preset",
    Desc = "Balanced — anti-detect human-like (recommended)",
    Callback = function() applyPreset("casual") end,
})
presetSub:Button({
    Title = "🥷 Stealth Preset",
    Desc = "Maximum stealth — slowest, paling natural",
    Callback = function() applyPreset("stealth") end,
})

-- ════════════════════ OTOMASI TAB ════════════════════
local AutoMulti = safeMultiSection(AutoTab, {
    Title = "Automation Hub",
    Icon = "bot",
    Box = true,
    BoxBorder = true,
    Opened = true,
})
local lobbySub = AutoMulti:Tab({ Title = "Lobby", Icon = "users" })
local resetSub = AutoMulti:Tab({ Title = "Reset", Icon = "refresh-cw" })

lobbySub:Section({ Title = "Lobby Automation" })
lobbySub:Toggle({
    Title = "Auto Join Empty Table",
    Desc = "Otomatis cari & teleport ke table kosong setelah match selesai",
    Value = false,
    Callback = function(v) state.autoJoinEnabled = v end,
})
lobbySub:Dropdown({
    Title = "Auto Vote Mode",
    Desc = "Auto-pilih mode pas voting fase. 'off' = disabled",
    Values = {"off", "Santai", "Normal", "Brutal"},
    Value = CONFIG.AUTO_VOTE_MODE or "off",
    Callback = function(v) CONFIG.AUTO_VOTE_MODE = v end,
})

resetSub:Section({ Title = "Reset Actions" })
resetSub:Button({
    Title = "Reset Used Words",
    Desc = "Clear daftar kata yg udah dipake match ini",
    Callback = function()
        usedWords = {}
        log("Used words direset")
    end,
})
resetSub:Button({
    Title = "Reset Mistakes Counter",
    Desc = "Reset counter mistake (resume bot kalo auto-pause)",
    Callback = function()
        sessionMistakes = 0
        log("Mistake counter di-reset")
    end,
})

-- ════════════════════ VISUAL TAB ════════════════════
local VisualMulti = safeMultiSection(VisualTab, {
    Title = "Visual Spoofing",
    Icon = "eye",
    Box = true,
    BoxBorder = true,
    Opened = true,
})
local nameSub = VisualMulti:Tab({ Title = "Name",  Icon = "user" })
local skinSub = VisualMulti:Tab({ Title = "Skin",  Icon = "palette" })

nameSub:Section({ Title = "Name Spoof (local only)" })

-- Helper: revert all spoofed text di PlayerGui & character ke nama asli
local function revertSpoofedText(oldSpoof)
    if not oldSpoof or oldSpoof == "" then return end
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.DisplayName = LP.DisplayName end) end
    end
    local function reverse(root)
        for _, d in ipairs(root:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text then
                if d.Text:find(oldSpoof, 1, true) then
                    pcall(function() d.Text = d.Text:gsub(oldSpoof, LP.Name) end)
                end
            end
        end
    end
    pcall(function() reverse(PlayerGui) end)
    if char then pcall(function() reverse(char) end) end
end

nameSub:Toggle({
    Title = "Enable Name Spoof",
    Desc = "Aktifin/matiin spoof. Kalo OFF → revert ke nama asli langsung.",
    Value = false,
    Callback = function(v)
        spoofEnabled = v
        if v then
            if spoofedName ~= "" then
                applyAllSpoof()
                log("🎭 [spoof] Enabled:", spoofedName)
            else
                log("🎭 [spoof] Enabled — set Spoof Name di Input dulu")
            end
        else
            revertSpoofedText(spoofedName)
            log("🎭 [spoof] Disabled (reverted)")
        end
    end,
})

nameSub:Input({
    Title = "Spoof Name",
    Desc = "Ganti nama yg muncul di UI game (visual aja, server tetep nama asli)",
    Value = "",
    Placeholder = "ex: NinjaPro",
    Callback = function(val)
        local v = (val or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local oldSpoof = spoofedName
        spoofedName = v
        -- Kalo nama lama berbeda → revert dulu (clear residue)
        if oldSpoof ~= "" and oldSpoof ~= v then
            revertSpoofedText(oldSpoof)
        end
        if v == "" then
            log("🎭 [spoof] Name cleared")
        elseif spoofEnabled then
            applyAllSpoof()
            log("🎭 [spoof] Active:", v)
        else
            log("🎭 [spoof] Name set, tapi toggle masih OFF")
        end
    end,
})

skinSub:Section({ Title = "Skin Stealer" })
skinSub:Button({
    Title = "👤 Steal Next Player Skin",
    Desc = "Cycle ke player lain di server, copy color + effects-nya",
    Callback = function()
        local ok, srcName, skinName = stealNextPlayer()
        if ok then
            log(("👤 Stole from %s (%s)"):format(srcName, skinName or "?"))
        else
            log("👤 No other players in server")
        end
    end,
})
skinSub:Button({
    Title = "Clear Stolen Skin",
    Desc = "Restore skin asli kamu",
    Callback = function()
        clearStealSkin()
        log("👤 Skin cleared")
    end,
})

-- (System tab removed — info udah ada di Dashboard, terminate via X button)

-- ════════════════════ MISC TAB ════════════════════
local MiscMulti = safeMultiSection(MiscTab, {
    Title = "Misc Tools",
    Icon = "ellipsis",
    Box = true,
    BoxBorder = true,
    Opened = true,
})
local serverSub = MiscMulti:Tab({ Title = "Server",   Icon = "server" })
local playerSub = MiscMulti:Tab({ Title = "Player",   Icon = "user-round" })
local detectSub = MiscMulti:Tab({ Title = "Security", Icon = "shield" })

-- ─── Server Sub-Tab ───
serverSub:Section({ Title = "Server Management" })
local TeleportService = game:GetService("TeleportService")
local PlaceId = game.PlaceId

serverSub:Button({
    Title = "🔄 Rejoin Server",
    Desc = "Teleport balik ke server yang sama (refresh koneksi)",
    Callback = function()
        WindUI:Notify({ Title = "Rejoin", Content = "Rejoining server...", Duration = 2 })
        task.wait(0.5)
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PlaceId, game.JobId, LP)
        end)
    end,
})

serverSub:Button({
    Title = "🌐 Server Hop (random)",
    Desc = "Cari server lain (low population) dan teleport ke sana",
    Callback = function()
        WindUI:Notify({ Title = "Server Hop", Content = "Cari server lain...", Duration = 2 })
        task.spawn(function()
            local HttpSvc = game:GetService("HttpService")
            local cursor = ""
            local picked = nil
            -- Loop max 5 page biar cepet, cari server yg gak full + bukan server kita
            for page = 1, 5 do
                local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(PlaceId)
                if cursor ~= "" then url = url .. "&cursor=" .. cursor end
                local ok, body = pcall(game.HttpGet, game, url)
                if not ok or not body then break end
                local data = HttpSvc:JSONDecode(body)
                if data and data.data then
                    -- Shuffle biar random
                    local servers = data.data
                    for i = #servers, 2, -1 do
                        local j = math.random(i)
                        servers[i], servers[j] = servers[j], servers[i]
                    end
                    for _, srv in ipairs(servers) do
                        if srv.id ~= game.JobId
                           and srv.playing and srv.maxPlayers
                           and srv.playing < srv.maxPlayers then
                            picked = srv.id
                            break
                        end
                    end
                end
                if picked then break end
                cursor = (data and data.nextPageCursor) or ""
                if cursor == "" or cursor == nil then break end
            end
            if picked then
                pcall(function() TeleportService:TeleportToPlaceInstance(PlaceId, picked, LP) end)
            else
                WindUI:Notify({ Title = "Server Hop", Content = "Gak nemu server lain :(", Duration = 3 })
            end
        end)
    end,
})

-- ─── Player Sub-Tab ───
playerSub:Section({ Title = "Character Control" })
playerSub:Button({
    Title = "💀 Respawn Character",
    Desc = "Reset character (BreakJoints) — useful kalo stuck",
    Callback = function()
        local char = LP.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Health = 0
            else
                pcall(function() char:BreakJoints() end)
            end
            WindUI:Notify({ Title = "Respawn", Content = "Character di-reset", Duration = 2 })
        end
    end,
})

-- ─── Security / Detect Sub-Tab ───
detectSub:Section({ Title = "Anti-Admin Detection" })
local detectAdminEnabled = false
local notifiedAdmins = {}  -- Set: userId yg udah di-notif (avoid spam)

-- Heuristic admin detection: cek beberapa indicator
--   1. Username contains "admin"/"mod"/"dev"/"staff"/"owner"
--   2. IsInGroup dengan rank tinggi (kalo game punya group — best-effort)
--   3. Account age < 30 hari + no display name custom = bot/alt (skip ini)
local function looksLikeAdmin(plr)
    if not plr or plr == LP then return false, nil end
    local name = (plr.Name or ""):lower()
    local disp = (plr.DisplayName or ""):lower()
    local keywords = {"admin", "moder", "staff", "owner", "developer", "[mod]", "[admin]", "[staff]"}
    for _, kw in ipairs(keywords) do
        if name:find(kw, 1, true) or disp:find(kw, 1, true) then
            return true, "username/displayname keyword: "..kw
        end
    end
    -- Cek MembershipType (Premium gak indicate admin sih, tapi bisa hint)
    -- Skip biar gak false positive
    return false, nil
end

local function scanForAdmins()
    if not detectAdminEnabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if not notifiedAdmins[plr.UserId] then
            local isAdmin, reason = looksLikeAdmin(plr)
            if isAdmin then
                notifiedAdmins[plr.UserId] = true
                local msg = ("⚠️ ADMIN DETECTED: %s (@%s)\nReason: %s"):format(plr.DisplayName, plr.Name, reason or "?")
                log(msg)
                pcall(function()
                    WindUI:Notify({
                        Title = "🚨 Admin Alert",
                        Content = msg,
                        Duration = 8,
                    })
                end)
            end
        end
    end
end

detectSub:Toggle({
    Title = "Detect Admin",
    Desc = "Notify kalo player dengan keyword admin/mod/staff/owner di username masuk server",
    Value = false,
    Callback = function(v)
        detectAdminEnabled = v
        if v then
            notifiedAdmins = {}
            scanForAdmins()  -- scan player yg udah ada
            log("🛡️ Detect Admin: ON")
        else
            log("🛡️ Detect Admin: OFF")
        end
    end,
})

detectSub:Button({
    Title = "🚪 Auto Leave on Admin (Server Hop)",
    Desc = "Kalo admin terdetect → auto server-hop ke server lain",
    Callback = function()
        if not detectAdminEnabled then
            WindUI:Notify({ Title = "Anti-Admin", Content = "Aktifin Detect Admin dulu", Duration = 3 })
            return
        end
        local foundAdmin = false
        for _, plr in ipairs(Players:GetPlayers()) do
            if looksLikeAdmin(plr) then foundAdmin = true; break end
        end
        if foundAdmin then
            log("🚪 Admin detected → server hopping")
            -- Trigger server hop (reuse logic)
            task.spawn(function()
                local HttpSvc = game:GetService("HttpService")
                local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=50"):format(PlaceId)
                local ok, body = pcall(game.HttpGet, game, url)
                if ok and body then
                    local data = HttpSvc:JSONDecode(body)
                    if data and data.data then
                        for _, srv in ipairs(data.data) do
                            if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
                                pcall(function() TeleportService:TeleportToPlaceInstance(PlaceId, srv.id, LP) end)
                                return
                            end
                        end
                    end
                end
            end)
        else
            WindUI:Notify({ Title = "Anti-Admin", Content = "No admin detected di server", Duration = 3 })
        end
    end,
})

-- Periodic scan + auto-trigger on player join
Players.PlayerAdded:Connect(function(plr)
    if _G.__SK_DEAD then return end
    task.wait(1)  -- kasih waktu DisplayName terload
    if detectAdminEnabled then scanForAdmins() end
end)

task.spawn(function()
    while state.alive do
        task.wait(5)
        if detectAdminEnabled then scanForAdmins() end
    end
end)

-- (Status live updater dihapus — Status sub-tab udah diganti jadi Account)

-- Auto-select Dashboard tab pas pertama kali UI muncul (default landing page).
pcall(function()
    if DashboardTab.Select then DashboardTab:Select()
    elseif DashboardTab.Open then DashboardTab:Open() end
end)

end  -- ← end of _buildMainGUI() IIFE
_buildMainGUI()  -- jalankan sekarang (semua locals di dalem dirilis setelah selesai)

------------------------------------------------------------
-- 7.5 SUGGESTER UI (terpisah dari main panel)
------------------------------------------------------------
-- Tampilin top 10 suggested words berdasarkan prefix giliran.
-- Mode: "display" (cuma liat, ketik manual) | "autotype" (klik → bot ketik)
local sugGui = Instance.new("ScreenGui")
sugGui.Name = "SambungKataSuggester"
sugGui.ResetOnSpawn = false
sugGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sugGui.Enabled = false  -- start hidden, controlled by state.suggesterEnabled + isInMatch()
sugGui.Parent = LP:WaitForChild("PlayerGui")

local sugFrame = Instance.new("Frame")
sugFrame.Size = UDim2.new(0, 240, 0, 360)
sugFrame.Position = UDim2.new(0, 20, 0.5, -180)
sugFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
sugFrame.BackgroundTransparency = 0.05
sugFrame.BorderSizePixel = 0
sugFrame.Active = true
sugFrame.Draggable = true
sugFrame.Parent = sugGui
local sugCorner = Instance.new("UICorner", sugFrame)
sugCorner.CornerRadius = UDim.new(0, 8)
local sugStroke = Instance.new("UIStroke", sugFrame)
sugStroke.Color = Color3.fromRGB(80, 100, 160)
sugStroke.Thickness = 1.5

local sugTitle = Instance.new("TextLabel", sugFrame)
sugTitle.Size = UDim2.new(1, -10, 0, 26)
sugTitle.Position = UDim2.new(0, 5, 0, 4)
sugTitle.BackgroundTransparency = 1
sugTitle.Text = "💡 Suggester (huruf: ?)"
sugTitle.TextColor3 = Color3.fromRGB(180, 220, 255)
sugTitle.TextXAlignment = Enum.TextXAlignment.Left
sugTitle.Font = Enum.Font.GothamBold
sugTitle.TextSize = 13

local sugMode = Instance.new("TextButton", sugFrame)
sugMode.Size = UDim2.new(1, -10, 0, 22)
sugMode.Position = UDim2.new(0, 5, 0, 32)
sugMode.BackgroundColor3 = Color3.fromRGB(50, 60, 90)
sugMode.Text = "Mode: Display Only (klik untuk toggle)"
sugMode.TextColor3 = Color3.fromRGB(220, 220, 220)
sugMode.Font = Enum.Font.Gotham
sugMode.TextSize = 11
Instance.new("UICorner", sugMode).CornerRadius = UDim.new(0, 5)
local sugAutoType = false
sugMode.MouseButton1Click:Connect(function()
    sugAutoType = not sugAutoType
    sugMode.Text = sugAutoType
        and "Mode: Auto-Type (klik = bot ketik)"
        or  "Mode: Display Only (klik untuk toggle)"
    sugMode.BackgroundColor3 = sugAutoType
        and Color3.fromRGB(60, 130, 80)
        or  Color3.fromRGB(50, 60, 90)
end)

local sugClose = Instance.new("TextButton", sugFrame)
sugClose.Size = UDim2.new(0, 22, 0, 22)
sugClose.Position = UDim2.new(1, -26, 0, 4)
sugClose.BackgroundColor3 = Color3.fromRGB(120, 50, 50)
sugClose.Text = "X"
sugClose.TextColor3 = Color3.fromRGB(255, 255, 255)
sugClose.Font = Enum.Font.GothamBold
sugClose.TextSize = 12
Instance.new("UICorner", sugClose).CornerRadius = UDim.new(0, 4)
sugClose.MouseButton1Click:Connect(function()
    -- Klik X = matiin suggester (sync ke WindUI toggle).
    state.suggesterEnabled = false
    sugGui.Enabled = false
    -- Try sync WindUI toggle UI state via available method (API beda-beda per versi).
    pcall(function()
        if suggesterToggle then
            if suggesterToggle.SetValue then suggesterToggle:SetValue(false)
            elseif suggesterToggle.Set then suggesterToggle:Set(false)
            elseif suggesterToggle.Toggle then suggesterToggle:Toggle(false) end
        end
    end)
end)

local sugList = Instance.new("Frame", sugFrame)
sugList.Size = UDim2.new(1, -10, 1, -64)
sugList.Position = UDim2.new(0, 5, 0, 60)
sugList.BackgroundTransparency = 1
local sugLayout = Instance.new("UIListLayout", sugList)
sugLayout.Padding = UDim.new(0, 3)
sugLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Build 10 suggestion buttons (re-used, content updated on refresh)
local sugButtons = {}
for i = 1, 10 do
    local btn = Instance.new("TextButton", sugList)
    btn.Size = UDim2.new(1, 0, 0, 26)
    btn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    btn.Text = "—"
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.Code
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = true
    btn.LayoutOrder = i
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    -- Padding kiri
    local pad = Instance.new("UIPadding", btn)
    pad.PaddingLeft = UDim.new(0, 8)
    sugButtons[i] = { btn = btn, word = nil }

    btn.MouseButton1Click:Connect(function()
        local entry = sugButtons[i]
        if not entry.word then return end
        if sugAutoType then
            -- Bot fire submit langsung
            log("💡 [suggester] Auto-type:", entry.word)
            task.spawn(function()
                pcall(function() fireSubmit(entry.word) end)
            end)
        else
            -- Display mode: copy ke clipboard biar user bisa paste
            pcall(function()
                if setclipboard then setclipboard(entry.word) end
            end)
            log("📋 [suggester] Copied to clipboard:", entry.word)
            -- Visual feedback: highlight sebentar
            local origColor = btn.BackgroundColor3
            btn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
            task.delay(0.4, function()
                if btn.Parent then btn.BackgroundColor3 = origColor end
            end)
        end
    end)
end

-- Auto-reset usedWords pas match selesai (transition isInMatch true → false).
task.spawn(function()
    local wasInMatch = false
    while state.alive do
        task.wait(1)
        local now = isInMatch()
        if wasInMatch and not now then
            -- Match selesai → fresh start next match
            usedWords = {}
            if CONFIG.DEBUG then
                log("🔄 [match-end] usedWords auto-reset")
            end
        end
        wasInMatch = now
    end
end)

-- Passive tracker: scan MatchUI TextLabels yg isinya kata valid (length 4-10, all alpha).
-- Mark sebagai used biar Suggester gak nampilin kata yg udah disubmit (kita atau opponent).
task.spawn(function()
    while state.alive do
        task.wait(1.5)
        if not isInMatch() then continue end
        pcall(function()
            local matchUI = LP.PlayerGui:FindFirstChild("MatchUI")
            if not matchUI then return end
            for _, lbl in ipairs(matchUI:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Text and #lbl.Text >= 4 and #lbl.Text <= 12 then
                    local txt = lbl.Text:lower():gsub("%s+", "")
                    if txt:match("^[a-z]+$") and wordExists[txt] and not usedWords[txt] then
                        usedWords[txt] = true
                        if CONFIG.DEBUG then
                            log(("👁️ [chain-scan] Detected used word: %s"):format(txt))
                        end
                    end
                end
            end
        end)
    end
end)

-- Refresh loop: update suggestions tiap kali prefix berubah.
-- Visibility: ON cuma kalau (state.suggesterEnabled == true) DAN (isInMatch() == true).
task.spawn(function()
    local lastPrefix = nil
    while state.alive do
        task.wait(0.4)

        -- Auto show/hide: ON cuma kalau toggle ON, di match, DAN giliran kita.
        local shouldShow = state.suggesterEnabled and isInMatch() and isMyTurn()
        if sugGui.Enabled ~= shouldShow then
            sugGui.Enabled = shouldShow
            if not shouldShow then
                -- Reset lastPrefix biar pas turn berikutnya regenerate fresh
                lastPrefix = nil
            end
        end
        if not shouldShow then continue end

        local prefix = findCurrentLetter()
        if prefix == lastPrefix then continue end
        lastPrefix = prefix

        if not prefix or prefix == "" then
            sugTitle.Text = "💡 Suggester (giliran: -)"
            for i = 1, 10 do
                sugButtons[i].word = nil
                sugButtons[i].btn.Text = "—"
                sugButtons[i].btn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
            end
        else
            sugTitle.Text = string.format("💡 Suggester [%s] huruf: %s", detectedMode, prefix:upper())
            local results = pickTopWords(prefix, 10)
            for i = 1, 10 do
                local entry = sugButtons[i]
                local r = results[i]
                if r then
                    entry.word = r.word
                    local marker = r.collected and "✓" or "✨"
                    entry.btn.Text = string.format("%s %s  (.%s, score:%d)",
                        marker, r.word, r.lastChar, math.floor(r.score))
                    entry.btn.BackgroundColor3 = r.collected
                        and Color3.fromRGB(35, 40, 55)
                        or  Color3.fromRGB(40, 55, 70)  -- highlight uncollected
                else
                    entry.word = nil
                    entry.btn.Text = "—"
                    entry.btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
                end
            end
        end
    end
end)

------------------------------------------------------------
-- 8. PUBLIC API (override manual via console)
------------------------------------------------------------
if getgenv then
    getgenv().SambungKata = {
        -- Set remote by candidate index (1..N) atau full path string
        SetRemote = function(idOrPath, method, argFormat, tableKey)
            local r
            if type(idOrPath) == "number" then
                local c = remoteCandidates[idOrPath]
                if not c then warn2("Index gak ada:", idOrPath) return end
                r = c.remote
            elseif type(idOrPath) == "string" then
                -- resolve dotted path: "ReplicatedStorage.Remotes.Submit"
                local cur = game
                for seg in idOrPath:gmatch("[^%.]+") do
                    cur = cur:FindFirstChild(seg) or cur:GetService(seg)
                    if not cur then warn2("Gak ketemu segmen:", seg) return end
                end
                r = cur
            elseif typeof(idOrPath) == "Instance" then
                r = idOrPath
            end
            if not r then warn2("Remote invalid") return end

            detected.remote    = r
            detected.method    = method or (r:IsA("RemoteFunction") and "InvokeServer" or "FireServer")
            detected.argIndex  = 1
            detected.argFormat = argFormat or "raw"
            detected.tableKey  = tableKey
            log("Manual set remote:", r:GetFullName(), "method:", detected.method)
        end,
        ListCandidates = function()
            for i, c in ipairs(remoteCandidates) do
                print(string.format("[%d] score=%d  %s", i, c.score, c.remote:GetFullName()))
                if i >= 15 then break end
            end
        end,
        Rescan = scanRemotes,
        ResetUsed = function() usedWords = {} end,
        ResetMistakes = function()
            sessionMistakes = 0
            log("✓ Mistake counter di-reset, bot bisa di-enable lagi")
        end,
        -- Preset system: quick switch antara speedrun/casual/stealth
        SetPreset = function(name)
            local PRESETS = {
                speedrun = {
                    desc = "Cepet maksimal — mirip pro player",
                    MIN_DELAY = 0.4, MAX_DELAY = 1.0,
                    TYPE_MIN_MS = 60, TYPE_MAX_MS = 140,
                    LONG_THINK_CHANCE = 0.05,
                    MAX_CONSECUTIVE_SUBMITS = 20,
                    BREAK_DURATION_MIN = 1, BREAK_DURATION_MAX = 2,
                    HESITATE_CHANCE = 0.02, TYPO_CHANCE = 0.01,
                },
                casual = {
                    desc = "Normal, kayak manusia biasa",
                    MIN_DELAY = 1.5, MAX_DELAY = 3.0,
                    TYPE_MIN_MS = 180, TYPE_MAX_MS = 380,
                    LONG_THINK_CHANCE = 0.15,
                    MAX_CONSECUTIVE_SUBMITS = 15,
                    BREAK_DURATION_MIN = 0.5, BREAK_DURATION_MAX = 1.2,
                    HESITATE_CHANCE = 0.08, TYPO_CHANCE = 0.04,
                },
                stealth = {
                    desc = "Stealth — manusia santai (tetap respek turn timer)",
                    MIN_DELAY = 2.5, MAX_DELAY = 4.5,
                    TYPE_MIN_MS = 200, TYPE_MAX_MS = 400,
                    LONG_THINK_CHANCE = 0.20,
                    MAX_CONSECUTIVE_SUBMITS = 12,
                    BREAK_DURATION_MIN = 1, BREAK_DURATION_MAX = 2,
                    HESITATE_CHANCE = 0.12, TYPO_CHANCE = 0.06,
                },
            }
            local p = PRESETS[name]
            if not p then
                warn("[SambungKata] Preset invalid. Pilih: 'speedrun', 'casual', atau 'stealth'")
                return
            end
            for k, v in pairs(p) do
                if k ~= "desc" then CONFIG[k] = v end
            end
            log(("✓ Preset '%s' aktif — %s"):format(name, p.desc))
        end,
        SetSabotage = function(enabled)
            CONFIG.SABOTAGE_MODE = enabled and true or false
            log("✓ SABOTAGE_MODE:", CONFIG.SABOTAGE_MODE and "ON (target huruf langka)" or "OFF")
        end,
        SetMode = function(mode)
            if mode == "remote" or mode == "click" or mode == "suggest" or mode == "kbinput" then
                CONFIG.INPUT_MODE = mode
                log("✓ INPUT_MODE diubah ke:", mode)
            else
                warn("[SambungKata] Mode invalid. Pilih: 'remote', 'click', atau 'suggest'")
            end
        end,
        DumpKeyboard = dumpKeyboardButtons,
        TestFire = function(word) fireSubmit(word or "test") end,
        State = state,
        Detected = detected,
        -- Dump SEMUA TextLabel/TextButton di PlayerGui yang text-nya 1-3 huruf
        -- Buat debug detect huruf giliran
        DumpUI = function()
            print("=== DUMP UI: Semua TextLabel candidate huruf giliran ===")
            local count = 0
            for _, obj in ipairs(PlayerGui:GetDescendants()) do
                if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Visible then
                    local ok, txt = pcall(function() return obj.Text end)
                    if ok and txt and #txt > 0 and #txt < 80 then
                        local trimmed = txt:gsub("^%s+", ""):gsub("%s+$", "")
                        local low = trimmed:lower()
                        local hasKw = low:find("huruf") or low:find("adalah") or low:find("mulai dari")
                        local isShort = #trimmed >= 1 and #trimmed <= 3 and trimmed:match("^[A-Za-z]+$")
                        if hasKw or isShort then
                            local size = obj.AbsoluteSize
                            print(string.format("  [%s] size=%dx%d | text=%q | path=%s",
                                obj.ClassName,
                                math.floor(size.X), math.floor(size.Y),
                                trimmed,
                                obj:GetFullName()))
                            count = count + 1
                        end
                    end
                end
            end
            print("=== Total candidates:", count, "===")
        end,
    }
    log("API tersedia di getgenv().SambungKata")
end

-- Inject coin-rain functions ke API table SETELAH API block (gak ke-overwrite).
-- Ini fix urutan: line 3540 bikin table baru → wipe assignment dari line 2337.
if getgenv and getgenv().SambungKata then
    getgenv().SambungKata.ForceCoinRain = function(duration)
        coinRainActive = true
        coinRainEndsAt = tick() + (duration or 30)
        log(("⚡ [coin-rain] FORCED START — duration: %ds"):format(duration or 30))
        startCoinTP()
    end
    getgenv().SambungKata.StopCoinRain = function()
        coinRainActive = false
        stopCoinTP()
    end
    getgenv().SambungKata.DebugCoins = function()
        local hrp = getHRP()
        print("HRP:", hrp and hrp:GetFullName() or "nil")
        print("HRP Anchored:", hrp and hrp.Anchored)
        print("Humanoid:", getHumanoid() and "OK" or "nil")
        local count = 0
        for _, part in ipairs(workspace:GetChildren()) do
            if isCoinPart(part) then
                count = count + 1
                if count <= 3 then
                    print(("Coin #%d: %s | dist=%.1f"):format(count, part.Name,
                        hrp and (part.Position - hrp.Position).Magnitude or -1))
                end
            end
        end
        print("Total coins detected:", count)
    end
    log("✓ Coin-rain API exposed: ForceCoinRain, StopCoinRain, DebugCoins")
end

log("Loaded. Cek console buat liat remote yang ke-detect, terus toggle Auto Play.")
