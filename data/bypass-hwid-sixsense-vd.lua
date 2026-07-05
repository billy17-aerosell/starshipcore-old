--[[
=====================================================================
    BYPASS BAN HWID SIXSENSE - VIOLENCE DISTRICT
=====================================================================
    Target    : sixsense.cloud/api/validate (error HWID_BANNED / E205)
    Game      : Violence District (PlaceId 93978595733734)
    Executor  : Wave / Solara / Swift / Fluxus / Seliware (UNC)
    Method    : Hook gethwid() + spoof payload (pre-encode)

    CARA PAKAI (ALL-IN-ONE):
    Tinggal execute file ini — bypass + loader Violence District
    bakal jalan otomatis berurutan.

        loadstring(game:HttpGet("URL-RAW-FILE-INI"))()

    Atau lokal:
        loadstring(readfile("bypass-hwid-sixsense-vd.lua"))()

    RESET HWID (kalau fake hwid lo ke-banned juga):
    - Jalanin: _G.SIXSENSE_BYPASS.reset()
    - Atau hapus file: sixsense_fake_hwid.txt di workspace executor

    STATUS:
    - state disimpan di getgenv().SIXSENSE_BYPASS
    - Aman kalau ke-execute 2x (anti double-hook)
=====================================================================
]]

-- Guard anti double-hook
if getgenv().SIXSENSE_BYPASS and getgenv().SIXSENSE_BYPASS.installed then
    warn("[BYPASS] Already installed. Skipping re-install.")
    print("[BYPASS] Current fake HWID:", getgenv().SIXSENSE_BYPASS.fakeHwid:sub(1, 16) .. "...")
    return
end

local CONFIG = {
    HWID_FILE          = "sixsense_fake_hwid.txt",
    DEBUG              = true,
    HOOK_REQUEST       = true,  -- juga spoof di layer HTTP (extra safety)
    LOG_SIXSENSE_CALLS = true,  -- log tiap call ke sixsense.cloud
}

local HttpService = game:GetService("HttpService")

local function log(...)
    if CONFIG.DEBUG then print("[BYPASS]", ...) end
end

-- ================================================================
-- 1. FAKE HWID GENERATION / LOAD
-- ================================================================
local function genHex(len)
    local s = ""
    for _ = 1, len do
        s = s .. string.format("%x", math.random(0, 15))
    end
    return s
end

local fakeHwid
if isfile and isfile(CONFIG.HWID_FILE) then
    local ok, content = pcall(readfile, CONFIG.HWID_FILE)
    if ok and content and #content >= 32 then
        fakeHwid = content:gsub("%s", "")
        log("Loaded saved fake HWID:", fakeHwid:sub(1, 16) .. "...")
    end
end

if not fakeHwid then
    math.randomseed(tick() * 10000 + os.time())
    fakeHwid = genHex(64)
    if writefile then
        pcall(writefile, CONFIG.HWID_FILE, fakeHwid)
    end
    log("Generated NEW fake HWID:", fakeHwid:sub(1, 16) .. "...")
end

-- ================================================================
-- 2. HOOK gethwid()
-- ================================================================
local originalGethwid = rawget(getgenv(), "gethwid") or rawget(_G, "gethwid") or gethwid

if type(originalGethwid) == "function" then
    local hookedFn = function(...)
        return fakeHwid
    end
    getgenv().gethwid = hookedFn
    _G.gethwid       = hookedFn
    -- Beberapa executor expose via alias
    if getgenv().get_hwid then getgenv().get_hwid = hookedFn end
    log("gethwid() hooked ✅")
else
    warn("[BYPASS] gethwid not found! Bypass mungkin gak work di executor ini.")
end

-- Verify
local ok, verified = pcall(gethwid)
if ok and verified == fakeHwid then
    log("Verify OK. gethwid() returns:", verified:sub(1, 20) .. "...")
else
    warn("[BYPASS] Verify FAIL. Returned:", tostring(verified):sub(1, 40))
end

-- ================================================================
-- 3. HTTP LAYER SPOOFING (safety net)
-- ================================================================
-- Kalau script SixSense dapet HWID dari sumber lain (cache, bukan gethwid),
-- kita intercept di layer HTTP request sebagai defense-in-depth.

if CONFIG.HOOK_REQUEST then
    local req = rawget(getgenv(), "request")
        or rawget(_G, "request")
        or rawget(_G, "http_request")
        or (syn and syn.request)
        or (http and http.request)

    if type(req) == "function" and hookfunction then
        local oldRequest
        oldRequest = hookfunction(req, function(opts)
            -- Log + spoof SixSense requests
            if type(opts) == "table" and opts.Url and opts.Url:lower():find("sixsense") then
                if CONFIG.LOG_SIXSENSE_CALLS then
                    log("SixSense call:", opts.Url)
                end

                -- Replace hwid di body (kalau ada)
                if opts.Body and type(opts.Body) == "string" then
                    local ok, body = pcall(HttpService.JSONDecode, HttpService, opts.Body)
                    if ok and type(body) == "table" and body.hwid then
                        -- Reverse+base64 encoding SixSense
                        -- fake hwid → sha256-like hex (fakeHwid) → base64(hex) → reverse
                        local encoded = (syn and syn.crypt and syn.crypt.base64encode)
                            or (crypt and crypt.base64 and crypt.base64.encode)
                            or (crypt and crypt.base64encode)
                            or nil
                        if encoded then
                            local ok2, b64 = pcall(encoded, fakeHwid)
                            if ok2 and b64 then
                                body.hwid = b64:reverse()
                                opts.Body = HttpService:JSONEncode(body)
                                log("Request body hwid replaced ✅")
                            end
                        end
                    end
                end
            end

            local res = oldRequest(opts)

            -- Log response
            if CONFIG.LOG_SIXSENSE_CALLS and type(opts) == "table"
               and opts.Url and opts.Url:lower():find("sixsense") then
                log("SixSense response:", res.StatusCode,
                    tostring(res.Body):sub(1, 150))
            end

            return res
        end)
        log("HTTP request hooked ✅")
    else
        log("HTTP hookfunction not available (skip HTTP layer, gethwid hook cukup)")
    end
end

-- ================================================================
-- 4. EXPOSE API
-- ================================================================
getgenv().SIXSENSE_BYPASS = {
    installed = true,
    fakeHwid  = fakeHwid,
    file      = CONFIG.HWID_FILE,

    -- Regenerate HWID baru (kalau yg lama ke-banned juga)
    reset = function()
        if delfile and isfile(CONFIG.HWID_FILE) then
            delfile(CONFIG.HWID_FILE)
        end
        local newHwid = genHex(64)
        if writefile then writefile(CONFIG.HWID_FILE, newHwid) end
        getgenv().SIXSENSE_BYPASS.fakeHwid = newHwid
        fakeHwid = newHwid
        print("[BYPASS] HWID reset. New:", newHwid:sub(1, 16) .. "...")
        print("[BYPASS] REJOIN game buat apply.")
    end,

    -- Set manual HWID (kalau lo punya HWID whitelisted)
    set = function(hwid)
        assert(type(hwid) == "string" and #hwid >= 32, "HWID harus string >= 32 char")
        fakeHwid = hwid
        getgenv().SIXSENSE_BYPASS.fakeHwid = hwid
        if writefile then writefile(CONFIG.HWID_FILE, hwid) end
        print("[BYPASS] HWID set manual:", hwid:sub(1, 16) .. "...")
    end,

    -- Info
    info = function()
        print("=== SIXSENSE BYPASS INFO ===")
        print("Installed :", getgenv().SIXSENSE_BYPASS.installed)
        print("Fake HWID :", fakeHwid)
        print("File      :", CONFIG.HWID_FILE)
        print("gethwid() :", gethwid())
    end,
}

log("Ready. Loading Violence District...")
log("API: _G.SIXSENSE_BYPASS.reset() / .set(hwid) / .info()")

-- ================================================================
-- 5. AUTO-LOAD VIOLENCE DISTRICT SCRIPT
-- ================================================================
local VD_URL = "https://sixsense.cloud/api/script/bf10d3b960442ff45c53ce9a2aa618b5"

task.wait(0.5) -- kasih jeda biar hook fully settled

local ok, err = pcall(function()
    local script_src = game:HttpGet(VD_URL)
    if not script_src or #script_src < 50 then
        error("Empty/invalid response from sixsense.cloud")
    end
    log("Script downloaded (" .. #script_src .. " bytes). Executing...")
    local fn, loadErr = loadstring(script_src)
    if not fn then error("loadstring failed: " .. tostring(loadErr)) end
    fn()
end)

if ok then
    log("Violence District loaded ✅")
else
    warn("[BYPASS] Failed to load Violence District: " .. tostring(err))
    warn("[BYPASS] Lo bisa manual: loadstring(game:HttpGet('" .. VD_URL .. "'))()")
end
