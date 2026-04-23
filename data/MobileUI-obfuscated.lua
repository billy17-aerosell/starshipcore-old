-- This file was generated with UnveilR V3.01 at discord.gg/threaded using the testing version.

local v46, v50, v72;
local fenv = getfenv();
fenv._YKb1s8 = "This file was protected with Xhider Obfuscator";
local v0 = debug and debug.getinfo;
for for_key_0, for_val_0 in pairs(_G) do
end;
local v1 = (error ~= error);
local v2 = (pairs ~= pairs);
local v3 = v1 or v2;
local v4 = (setmetatable ~= setmetatable);
local v5 = v3 or v4;
local v6 = (getmetatable ~= getmetatable);
local v7 = v5 or v6;
local v8 = v7 or false;
local v9 = (load ~= load);
local v10 = v8 or v9;
local v11 = (loadstring ~= loadstring);
local v12 = v10 or v11;
local v13 = (pcall ~= pcall);
local v14 = v12 or v13;
local v15 = (xpcall ~= xpcall);
local v16 = v14 or v15;
local v17 = (debug ~= debug);
local v18 = v16 or v17;
local v19 = (package ~= package);
local v20 = v18 or v19;
local v21 = (coroutine ~= coroutine);
local v22 = v20 or v21;
local v23 = v22 or false;
local v24 = v23 or false;
local v25 = v24 or false;
if v25 then 
end;
local v26 = (pcall ~= pcall);
local v27 = (math.random ~= math.random);
local v28 = v26 or v27;
if v28 then 
end;
local v29 = _G.os;
local v30 = (v29 ~= nil);
if v30 then 
end;
local v31 = _G.io;
local v32 = (v31 ~= nil);
if v32 then 
end;
local v33 = _G.file;
local v34 = (v33 ~= nil);
if v34 then 
end;
local v35 = _G.debug;
local v36 = (v35 ~= nil);
if v36 then 
end;
local main = fenv.main;
local v37 = _G.os;
local v38 = getmetatable(v37);
local v39 = _G.io;
local v40 = getmetatable(v39);
local v41 = _G.file;
local v42 = getmetatable(v41);
local v43 = _G.debug;
local v44 = getmetatable(v43);
local v45 = debug and debug.getinfo;
if debug.getinfo then 
    if pairs then 
        v46 = debug.getinfo(pairs, "S");
    end;
end;
local v47 = v46.what;
local v48 = (v47 ~= "C");
local v49 = v46 and v48;
if v49 then 
end;
if os.clock then 
    v50 = debug.getinfo(os.clock, "S");
end;
local v51 = v50.what;
local v52 = (v51 ~= "C");
local v53 = v50 and v52;
if v53 then 
end;
local v54 = debug.getinfo(table.insert, "S");
local v55 = debug.getinfo(1, "S");
local v56 = not v55;
if v56 then 
end;
local v57 = debug.getinfo(pairs, "S");
local v58 = debug.getinfo(function(a_0, b_0, c_0) end, "S");
local v59 = v57.what;
local v60 = (v59 == "Lua");
if v60 then 
end;
local v61 = (typeof ~= nil);
local v62 = (loadstring ~= nil);
local v63 = function(a_0, b_0, c_0, ...) end;
local v64 = v62 or v63();
if v64 then 
    local v65 = (loadstring ~= loadstring);
    if v65 then 
    end;
end;
local v66 = (load ~= nil);
local v67 = (load ~= nil);
local v68 = v66 or v67;
if v68 then 
end;
local v69 = not v61;
local v70 = debug and nil;
if v70 then 
end;
local v71 = (loadstring ~= nil);
if v71 then 
    v72 = loadstring"return 1+1";
end;
local v74 = v72();
local v75, v76 = pcall(v72);
local v77 = not v75;
local v78 = (v76 ~= 2);
local v79 = v77 or v78;
if v79 then 
end;
local v80 = (loadstring ~= nil);
local v81 = getmetatable(loadstring);
local v82 = v80 and false;
if v82 then 
end;
local v83 = (load ~= nil);
if v61 then 
    if iscclosure then 
        local v84 = (loadstring ~= nil);
        local v85 = iscclosure(loadstring);
        local v86 = not v85;
        local v87 = v84 and v86;
        if v87 then 
        end;
    end;
    local v88 = (load ~= nil);
end;
local v89 = fenv.checkclosure;
if v89 then 
    local v90 = (loadstring ~= nil);
    local v91 = fenv.checkclosure;
    local v92 = v91(loadstring);
    local v93 = not v92;
    local v94 = v90 and v93;
    if v94 then 
    end;
end;
local v95 = (load ~= nil);
fenv.n = 15;
local success_3, v128 = pcall(function(a_5, b_5, c_5, ...)
    local v96 = game.GetService;
    local v97 = game:GetService("Players");
    local v98 = fenv.getgc;
    local v99 = v98(true);
    for for_key_1, for_val_1 in pairs(v99) do
    end;
    local v100 = game.GetService;
    local v101 = game:GetService("RunService");
    local v102 = game.GetService;
    local v103 = game:GetService("UserInputService");
    local v104 = game.GetService;
    local v105 = game:GetService("TweenService");
    local v106 = game.GetService;
    local v107 = game:GetService("ContentProvider");
    local v108 = v97.LocalPlayer;
    local v109 = _G.StarshipServerURL;
    local v110 = v109 or "https://starship-core.my.id";
    local v111 = math.random(1e5, 999999);
    local v112 = tostring(v111);
    local v113 = "STARSHIP_MOBILE_GUI_" .. v112;
    local v114 = v113.find;
    local v116 = string.find(v113, "\239", 0, true);
    local v117 = task.defer(function(a_0, b_0, c_0) end);
    _G.StarshipCleanup = nil;
    _G.STARSHIP_MOBILE_ACTIVE = nil;
    _G.StarshipWindow = nil;
    _G.StarshipWindUI = nil;
    local success = pcall(function(a, b, c)
        getgenv().StarshipWindow = nil;
    end);
    local success_1 = pcall(function(a_2, b_2, c_2)
        getgenv().StarshipWindUI = nil;
    end);
    local success_2 = pcall(function(a_3, b_3, c_3)
        getgenv().STARSHIP_MOBILE_ACTIVE = nil;
    end);
    local v118 = _G.StarshipDevMode;
    local v119 = v118 or false;
    _G.WindUIIsBoreal = false;
    local v121 = isfile"StarshipCore/Libraries/WindUI_Boreal.lua";
    if v121 then 
    end;
    local v122 = game.HttpGet;
    local v124, v125 = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/billy17-netizen/windUIBoreal/refs/heads/main/WindUI_Boreal.lua");
    local v126 = #v125;
    local v127 = v126 > 100;
end);
local v129 = not success_3;
if v129 then 
    error(v128);
end;