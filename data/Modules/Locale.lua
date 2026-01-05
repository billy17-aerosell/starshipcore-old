-- Locale.lua - Multi-language support for Starship Core
-- Supports: English (en), Indonesian (id), Japanese (ja), Korean (ko), Chinese (zh), Spanish (es), Portuguese (pt)

local Locale = {}

-- Current language (default: English)
local CurrentLanguage = "en"

-- Registered UI elements for auto-refresh
local RegisteredElements = {}

-- Language change callbacks
local OnLanguageChangeCallbacks = {}

-- All translations
local Translations = {
	-- ═══════════════════════════════════════════════════════════════════
	-- ENGLISH (Default)
	-- ═══════════════════════════════════════════════════════════════════
	en = {
		-- General
		enabled = "Enabled",
		disabled = "Disabled",
		on = "ON",
		off = "OFF",
		save = "Save",
		load = "Load",
		delete = "Delete",
		cancel = "Cancel",
		confirm = "Confirm",
		close = "Close",
		exit_starship = "EXIT STARSHIP",
		exit_confirm = "Are you sure you want to close the script completely?",
		settings = "Settings",

		-- Modal/Popup
		system_alert = "SYSTEM ALERT",
		confirm_action = "Confirm Action?",
		enter_here = "Enter here...",
		save_recording = "SAVE RECORDING",
		enter_filename = "Enter Filename...",
		save_merged_file = "SAVE MERGED FILE",
		name_required = "NAME REQUIRED!",
		delete_file = "DELETE FILE",
		new_workspace = "NEW WORKSPACE",
		workspace_exists = "Workspace already exists!",
		no_file_selected = "No File Selected",
		saving_file = "Saving File...",
		merge_complete = "Merge Complete",
		optimizing_frames = "OPTIMIZING FRAMES...",
		auto_smoothing = "AUTO SMOOTHING...",
		finding_position = "FINDING POSITION...",
		generating_path = "GENERATING PATH...",
		permanent_smoothing = "PERMANENT SMOOTHING...",
		different_map_detected = "DIFFERENT MAP DETECTED",
		continue_anyway = "Continue anyway?",

		-- Welcome Toast
		welcome = "Welcome",
		starship_ready = "Starship Core Ready",

		-- Auto-Load
		auto_loaded = "Auto-Loaded",
		profile = "Profile",
		auto_enabling = "Auto-enabling %d feature(s)...",

		-- Profile
		profile_loaded = "Profile Loaded",
		profile_saved = "Profile Saved",
		loaded = "Loaded",
		saved_to = "Saved to",

		-- Tools Tab
		automation = "AUTOMATION",
		anti_afk = "Anti-AFK",
		anti_afk_desc = "Prevents auto-kick when idle",
		emotes_menu = "EMOTES MENU",
		emotes_menu_desc = "Play custom animations",
		shift_lock = "SHIFT LOCK",
		shift_lock_desc = "Lock camera behind character (press LeftShift)",
		security = "SECURITY",
		bypass_admin = "BYPASS ADMIN",
		bypass_admin_desc = "Auto-leave if admin joins the server",
		environment = "ENVIRONMENT",
		fullbright = "FULLBRIGHT",
		fullbright_desc = "Maximum brightness, no shadows",
		speed_checker = "SPEED CHECKER",
		speed_display = "SPEED DISPLAY",
		walkspeed = "WALKSPEED",
		default_speed = "(default: 16)",

		-- Helper Tab
		jump_assist = "JUMP ASSIST",
		auto_jump = "AUTO JUMP",
		auto_jump_desc = "Automatically jump when on ground",
		air_lock = "AIR LOCK",
		air_lock_desc = "Edge boost assist for obby jumps",
		quick_boost = "QUICK BOOST",
		quick_boost_desc = "Press A/D or L2/R2 in air for extra height",
		boost_power = "BOOST",
		always_momentum = "ALWAYS MOMENTUM",
		always_momentum_desc = "Lock your speed at highest value reached",
		anti_slip = "ANTI-SLIP",
		anti_slip_desc = "Prevent sliding off edges and slopes",
		size = "SIZE",
		anti_ragdoll = "ANTI-RAGDOLL",
		anti_ragdoll_desc = "Prevent character from falling over",
		max_velocity = "MAX VELOCITY",
		real_path_esp = "REAL PATH ESP",
		real_path_esp_desc = "Highlight platforms based on safety",
		color_info = "COLOR INFO (Range: 75 studs):",
		green_safe = "● GREEN = SAFE (CanCollide ON)",
		cyan_ladder = "● CYAN = Ladder WALKABLE (CanCollide ON)",
		orange_ladder = "● ORANGE = Ladder NOT WALKABLE (CanCollide OFF)",
		red_fake = "● RED = FAKE (CanCollide OFF - Will Fall!)",
		character_fly = "CHARACTER & FLY",

		-- Config Tab
		keybinds = "KEYBINDS",
		start_recording = "Start/Pause Recording",
		pause_recording = "Pause Recording",
		toggle_path = "Toggle Path",
		play_playback = "Play/Stop Playback",
		stop_playback = "Stop Playback",
		follow_player = "Follow Player",
		toggle_shift_lock = "Toggle Shift Lock",
		toggle_anti_slip = "Toggle Anti-Slip",
		toggle_auto_jump = "Toggle Auto Jump",
		toggle_quick_boost = "Toggle Quick Boost",
		toggle_real_esp = "Toggle Real Path ESP",
		minimize_ui = "Minimize UI",
		click_to_bind = "Click to bind...",
		press_key = "Press any key...",
		duplicate_keybind = "Duplicate Keybind",
		key_already_used = "'%s' is already used by another action!",

		-- Auto Execute
		auto_execute = "AUTO EXECUTE",
		auto_execute_enabled = "Auto Execute enabled! Script will run automatically on game start.",
		auto_execute_disabled = "Auto Execute disabled.",
		save_auto_exec = "💾 SAVE AUTO EXECUTE SETTINGS",
		saved = "✅ SAVED!",
		script_created = "✅ Script created",
		could_not_create = "⚠️ Could not create auto-exec script (check folder permissions)",
		auto_exec_disabled = "🔴 Auto-exec disabled",
		detected = "🔍 Detected",
		path = "Path",
		seliware_instructions = "📝 Seliware users: Use custom path C:/Users/YOURNAME/AppData/Local/seliware-autoexec\nRestart executor after saving for changes to take effect.",

		-- Auto-Enable
		auto_enable = "AUTO-ENABLE FEATURES",
		auto_enable_saved = "Auto-Enable Saved",
		auto_enable_desc = "Settings saved! Also included when you save a profile.",
		select_features = "Select features to auto-enable when script loads",

		-- Themes
		themes = "THEMES",
		theme = "Theme",
		accent_color = "Accent Color",

		-- Language
		language = "LANGUAGE",
		select_language = "Select Language",
		language_changed = "Language changed successfully!",

		-- Recording
		-- Recording Tab
		recording = "RECORDING",
		recording_saved = "Recording Saved",
		frames_saved = "Saved %d frames to %s",
		smoothing_failed = "Smoothing Failed",
		not_enough_frames = "Not enough frames.",
		path_smoothed = "Path smoothed permanently (unsaved).",
		success = "Success",
		ready_to_record = "READY TO RECORD",
		press_start = "Press Start or F5 to begin",
		recording_in_progress = "RECORDING IN PROGRESS",
		duration = "Duration",
		recording_paused = "RECORDING PAUSED",
		rewind_mode_active = "Rewind Mode Active",
		start = "START",
		pause = "PAUSE",

		mode_strict = "MODE: STRICT",
		mode_flexible = "MODE: FLEXIBLE",
		path_on = "PATH: ON",
		path_off = "PATH: OFF",
		rewind = "REWIND",
		cut_resume = "CUT & RESUME",
		save_btn = "SAVE",
		filename = "Filename...",
		files = "FILES",
		no_files = "No files found",
		rename = "RENAME",
		select = "SELECT",

		-- Custom Animations
		custom_animations = "CUSTOM ANIMATIONS",
		status_ready = "Status: Ready",
		status = "Status",
		type = "TYPE",
		search = "Search...",
		anim_name = "Anim Name...",
		asset_id_url = "Asset ID / URL...",
		add_apply_animation = "ADD / APPLY ANIMATION",
		id_required = "ID Required!",
		invalid_id_format = "Invalid ID Format",
		added = "Added",
		reset_to_original = "RESET TO ORIGINAL",
		reset_original = "Reset to Original",
		original_not_found = "Original Not Found",
		deleted_item = "Deleted",
		set_anim = "Set",

		-- Server
		server = "SERVER",
		browser = "BROWSER",
		rejoin = "REJOIN",
		server_list = "SERVER LIST",
		fetching_servers = "Fetching Servers...",
		no_servers_found = "No servers found.",
		invalid_data = "Invalid Data.",

		-- Recording Tools
		recording_tools = "RECORDING TOOLS",
		live_smoothing_auto = "LIVE SMOOTHING (AUTO)",
		strength = "STRENGTH",
		live_smooth = "LIVE SMOOTH",
		pos_based = "POS-BASED",
		pos_based_desc = "POS-BASED: Smoother ground movement (follows path directly)",
		manual_apply = "Manual Apply (Permanent)",

		-- Privacy / Streamer Mode
		privacy_streamer = "PRIVACY (STREAMER MODE)",
		privacy_desc = "Spoof your name for streaming/screenshots (CLIENT-SIDE ONLY - only you see the fake name)",
		fake_username = "Fake Username...",
		fake_display_name = "Fake Display Name...",
		spoof = "SPOOF",
		random_name = "RANDOM NAME",

		-- Players
		players_section = "PLAYERS",
		hide_all_players = "HIDE ALL PLAYERS",

		-- Skybox Changer
		skybox_changer = "SKYBOX CHANGER",
		current = "Current",
		select_skybox = "Select Skybox",

		-- HD Shader
		hd_shader = "HD SHADER",
		preset = "Preset",
		select_preset = "Select a preset to enhance graphics",
		shader_disabled = "Shader disabled",
		shader_active = "shader active!",
		hd_natural = "HD Natural",
		cinematic = "Cinematic",
		turn_off = "TURN OFF",

		-- Fun Tab
		touch_fling = "TOUCH FLING",
		fling = "FLING",
		expand_hitbox = "EXPAND HITBOX",
		bigger_hitbox = "Bigger hitbox = easier fling!",
		invisible = "INVISIBLE",
		invisible_desc = "FE Bypass invisible mode",
		teleport_to_player = "TELEPORT TO PLAYER",
		select_player = "Select Player...",
		teleported_to = "Teleported to",
		teleporting_steps = "Teleporting in steps...",
		spectate_player = "SPECTATE PLAYER",
		spectate = "SPECTATE",
		stop_spectate = "STOP SPECTATE",
		spectating = "Spectating",
		friends_in_server = "FRIENDS IN SERVER",
		object_aura = "OBJECT AURA (TRASH THROWER)",
		start_fling = "START FLING",
		stop_fling = "STOP FLING",
		fling_stopped = "Fling stopped",
		auto_follow = "AUTO FOLLOW",
		follow = "FOLLOW",
		stop_follow = "STOP FOLLOW",
		following = "Following",
		black_hole = "Black Hole",
		invert_gravity = "Invert Gravity",
		part_destroyer = "Part Destroyer",
		part_magnet = "Part Magnet",
		magnet_radius = "Magnet Radius",
		magnet_strength = "Magnet Strength",
		orbit_ring = "Orbit Ring",
		ring_radius = "Ring Radius",
		ring_speed = "Ring Speed",

		-- Recording UI extras
		rewind_control = "REWIND CONTROL",
		resume_recording = "RESUME RECORDING",
		recordings = "RECORDINGS",
		status_idle = "Status: Idle",
		path_visualizer = "Path Visualizer",
		discard = "DISCARD",
		go = "GO!",
		ready = "Ready",
		loading = "LOADING...",
		tags = "TAGS",

		-- List Map UI
		strict_retarget = "STRICT RETARGET",
		native_anim = "NATIVE ANIM",

		-- Playback
		playback = "PLAYBACK",
		loading_playback = "Loading Playback",
		preparing = "Preparing %s...",
		file_not_found = "File not found",
		error = "Error",
		live_smoothing = "Live Smoothing",
		applied_smoothing = "Applied smoothing (Strength: %d)",
		warning_different_map = "WARNING: Different Map?",
		nearest_path_warning = "Nearest path point is %.0f studs away! This recording may be from a different game/map.",
		-- PlaceId + Distance Validation (Option B)
		info = "Info",
		path_far_same_game = "Path is %.0f studs away, but same game detected. You may need to travel to the recording location.",
		warning_different_game = "⚠️ Different Game",
		different_placeid_nearby = "Recording from PlaceId %s, current: %s. Path is nearby - may be a similar map.",
		error_wrong_game = "🛑 Wrong Game",
		wrong_game_warning = "This recording is from a different game and path is %.0f studs away!",
		wrong_game_detected = "WRONG GAME DETECTED",
		wrong_game_confirm = "Recording PlaceId: %s\nCurrent PlaceId: %s\nPath distance: %.0f studs\n\nThis recording appears to be from a different game. Continue anyway?",
		respawn = "Respawn",
		respawning_in = "Respawning in 5 seconds...",
		loop = "Loop",
		restarting_playback = "Restarting playback in 5 seconds...",
		cross_rig_playback = "Cross-Rig Playback",

		-- Merger Tab
		merger = "MERGER",
		select_files_to_merge = "SELECT FILES TO MERGE",
		search_files = "Search files...",
		selected = "Selected",
		total_files = "files",
		merge = "MERGE",
		merge_selected = "MERGE SELECTED",
		clear_selection = "CLEAR",
		select_all = "SELECT ALL",
		deselect_all = "DESELECT ALL",
		output_name = "Output name...",
		merge_success = "Merge Success",
		merged_files = "Merged %d files into %s",
		no_files_selected = "No files selected",
		select_at_least_two = "Select at least 2 files to merge",

		-- List Map Tab
		list_map = "LIST MAP",
		map_recordings = "MAP RECORDINGS",
		search_maps = "Search maps...",
		total_maps = "Total: %d maps",
		no_maps_found = "No maps found",
		play_recording = "PLAY",
		stop_recording = "STOP",
		delete_recording = "DELETE",
		rename_recording = "RENAME",
		new_name = "New name...",
		confirm_delete = "Confirm Delete",
		delete_file_confirm = "Delete file '%s' permanently?",
		file_deleted = "File Deleted",
		deleted = "Deleted %s",
		file_renamed = "File Renamed",
		renamed_to = "Renamed to %s",
		different_map_warning = "Different Map Warning",
		workspace = "Workspace",
		default_workspace = "Default",
		create_workspace = "Create Workspace",
		workspace_name = "Workspace name...",
		workspace_created = "Workspace Created",

		-- Path Visualization
		path_visualization = "Path Visualization",
		path_enabled = "Path enabled",
		path_disabled = "Path disabled",

		-- Animation
		animation_system = "Animation System",

		-- Dashboard Tab
		good_morning = "Good Morning",
		good_afternoon = "Good Afternoon",
		good_evening = "Good Evening",
		premium = "PREMIUM",
		game_detection = "GAME DETECTION",
		game_info = "GAME INFO",
		game = "Game",
		place_id = "Place ID",
		job_id = "Job ID",
		players = "Players",
		executor = "Executor",
		server_info = "SERVER INFO",
		discord = "DISCORD",
		join_discord = "Join our Discord",
		copy_link = "COPY LINK",
		link_copied = "Link copied!",
		friends_in_game = "FRIENDS IN GAME",
		no_friends = "No friends in this game",
		refresh = "REFRESH",
		join = "JOIN",
		server_age = "Server Age",
		ping = "Ping",
		fps = "FPS",
		copy = "COPY",
		copied = "COPIED!",
		ok = "OK!",
		version = "Version",
		hwid = "HWID",
		your_account = "YOUR ACCOUNT",
		username = "Username",
		display_name = "Display Name",
		user_id = "User ID",
		copy_discord = "COPY DISCORD INVITE",
		tp = "TP",
		executor_info = "EXECUTOR INFO",

		-- Initial Setup
		initial_setup = "INITIAL SETUP",
		configure_preferences = "Configure your preferences",
		anonymous_mode = "Anonymous Mode",
		anonymous_desc = "Hide identity with random name",
		show_nametags = "Show Nametags",
		nametags_desc = "Display VIP/Script tags",
		dont_show_again = "Don't show again",
		continue_btn = "CONTINUE",

		-- Warp Tab
		warp_points = "WARP POINTS & CONFIGS",
		add_point = "ADD POINT",
		clear = "CLEAR",
		delay = "Delay (s)",
		auto = "AUTO",
		total_time = "Total",
		run_time = "Run",
		config_name = "Config Name...",
		save_config = "SAVE CONFIG",
		start_loop = "START\nLOOP",
		stop_loop = "STOP\nLOOP",
		warp_stopped = "Warp Stopped",
		warp_running = "Warp Running",
		point_added = "Point Added",
		points_cleared = "Points Cleared",
		config_saved = "Config Saved",
		config_loaded = "Config Loaded",
		config_deleted = "Config Deleted",

		-- Fun Tab
		character_mods = "CHARACTER MODS",
		fly = "FLY",
		fly_desc = "Fly around the map",
		noclip = "NOCLIP",
		noclip_desc = "Walk through walls",
		speed = "SPEED",
		speed_desc = "Adjust walk speed",
		jump_power = "JUMP POWER",
		jump_power_desc = "Adjust jump height",
		gravity = "GRAVITY",
		gravity_desc = "Adjust world gravity",
		teleport = "TELEPORT",
		bring_player = "Bring Player",
		goto_position = "Go to Position",
		visual_mods = "VISUAL MODS",
		freecam = "FREECAM",
		freecam_desc = "Free camera movement",
		field_of_view = "FOV",
		third_person = "Third Person Distance",

		-- Emotes Tab
		emotes_catalog = "CATALOG",
		emotes_saved = "SAVED",
		search_emotes = "Search emotes...",
		play = "PLAY",

		save_emote = "SAVE",
		remove_emote = "REMOVE",
		emote_speed = "Speed",
		emote_looped = "Looped",
		no_saved_emotes = "No saved emotes",
		emote_saved = "Emote Saved",
		emote_removed = "Emote Removed",
		playing_emote = "Playing Emote",
		stopped_emote = "Stopped Emote",

		-- Target Recording
		target_recording = "Target Recording",
		open_target_recorder = "OPEN TARGET RECORDER",
		select_player = "Select Player",
		select_player_first = "Please select a player first",
		select_player_to_record = "Select a player to record",
		start_recording = "Start Recording",
		stop_recording = "Stop Recording",
		started_recording = "Started recording",
		stopped_recording = "Stopped recording",
		target_not_found = "Target character not found",
		target_player_left = "Target player left the game",
		no_other_players = "No other players in server",
		no_data_recorded = "No data recorded",
		no_data_to_save = "No data to save",
		recording_data_cleared = "Recording data cleared",
		recordings = "Recordings",
		no_files = "No files found",

		-- Async Loading
		loading_recording = "Loading Recording...",
		parsing_large_file = "Parsing large file...",
		processing_frames = "Processing frames...",
		recording_loaded = "Recording Loaded",
		invalid_recording_file = "Invalid recording file",

		-- Before Fall (Rewind)
		before_fall = "BEFORE FALL",
		before_fall_hint = "Drag slider or use BEFORE FALL to jump to safe position",
		before_fall_not_enough = "Not enough frames recorded",
		before_fall_set = "Set to %.1fs (before jump/fall)",
		before_fall_no_fall = "No fall detected in recording",
	},

	-- ═══════════════════════════════════════════════════════════════════
	-- INDONESIAN
	-- ═══════════════════════════════════════════════════════════════════
	id = {
		-- General
		enabled = "Aktif",
		disabled = "Nonaktif",
		on = "AKTIF",
		off = "MATI",
		save = "Simpan",
		load = "Muat",
		delete = "Hapus",
		cancel = "Batal",
		confirm = "Konfirmasi",
		close = "Tutup",
		exit_starship = "KELUAR STARSHIP",
		exit_confirm = "Apakah kamu yakin ingin menutup script sepenuhnya?",
		settings = "Pengaturan",

		-- Modal/Popup
		system_alert = "PERINGATAN SISTEM",
		confirm_action = "Konfirmasi Aksi?",
		enter_here = "Masukkan di sini...",
		save_recording = "SIMPAN REKAMAN",
		enter_filename = "Masukkan Nama File...",
		save_merged_file = "SIMPAN FILE GABUNGAN",
		name_required = "NAMA DIPERLUKAN!",
		delete_file = "HAPUS FILE",
		new_workspace = "RUANG KERJA BARU",
		workspace_exists = "Ruang kerja sudah ada!",
		no_file_selected = "Tidak Ada File Dipilih",
		saving_file = "Menyimpan File...",
		merge_complete = "Penggabungan Selesai",
		optimizing_frames = "MENGOPTIMALKAN FRAME...",
		auto_smoothing = "SMOOTHING OTOMATIS...",
		finding_position = "MENCARI POSISI...",
		generating_path = "MEMBUAT JALUR...",
		permanent_smoothing = "SMOOTHING PERMANEN...",
		different_map_detected = "MAP BERBEDA TERDETEKSI",
		continue_anyway = "Tetap lanjutkan?",

		-- Welcome Toast
		welcome = "Selamat Datang",
		starship_ready = "Starship Core Siap",

		-- Auto-Load
		auto_loaded = "Otomatis Dimuat",
		profile = "Profil",
		auto_enabling = "Mengaktifkan %d fitur...",

		-- Profile
		profile_loaded = "Profil Dimuat",
		profile_saved = "Profil Disimpan",
		loaded = "Dimuat",
		saved_to = "Disimpan ke",

		-- Tools Tab
		automation = "OTOMASI",
		anti_afk = "Anti-AFK",
		anti_afk_desc = "Mencegah kick otomatis saat idle",
		emotes_menu = "MENU EMOTE",
		emotes_menu_desc = "Putar animasi kustom",
		shift_lock = "KUNCI SHIFT",
		shift_lock_desc = "Kunci kamera di belakang karakter (tekan LeftShift)",
		security = "KEAMANAN",
		bypass_admin = "BYPASS ADMIN",
		bypass_admin_desc = "Keluar otomatis jika admin bergabung",
		environment = "LINGKUNGAN",
		fullbright = "FULLBRIGHT",
		fullbright_desc = "Kecerahan maksimum, tanpa bayangan",
		speed_checker = "CEK KECEPATAN",
		speed_display = "TAMPILAN KECEPATAN",
		walkspeed = "KECEPATAN JALAN",
		default_speed = "(default: 16)",

		-- Helper Tab
		jump_assist = "BANTUAN LOMPAT",
		auto_jump = "LOMPAT OTOMATIS",
		auto_jump_desc = "Otomatis lompat saat di tanah",
		air_lock = "KUNCI UDARA",
		air_lock_desc = "Bantuan boost tepi untuk obby",
		quick_boost = "BOOST CEPAT",
		quick_boost_desc = "Tekan A/D atau L2/R2 di udara untuk tinggi ekstra",
		boost_power = "KEKUATAN",
		always_momentum = "MOMENTUM SELALU",
		always_momentum_desc = "Kunci kecepatan di nilai tertinggi",
		anti_slip = "ANTI-SLIP",
		anti_slip_desc = "Mencegah tergelincir dari tepi dan lereng",
		size = "UKURAN",
		anti_ragdoll = "ANTI-RAGDOLL",
		anti_ragdoll_desc = "Mencegah karakter terjatuh",
		max_velocity = "KECEPATAN MAKS",
		real_path_esp = "ESP JALUR NYATA",
		real_path_esp_desc = "Sorot platform berdasarkan keamanan",
		color_info = "INFO WARNA (Jarak: 75 stud):",
		green_safe = "● HIJAU = AMAN (CanCollide AKTIF)",
		cyan_ladder = "● CYAN = Tangga BISA JALAN (CanCollide AKTIF)",
		orange_ladder = "● ORANYE = Tangga TIDAK BISA JALAN (CanCollide MATI)",
		red_fake = "● MERAH = PALSU (CanCollide MATI - Akan Jatuh!)",
		character_fly = "KARAKTER & TERBANG",

		-- Config Tab
		keybinds = "TOMBOL PINTASAN",
		start_recording = "Mulai/Jeda Rekaman",
		pause_recording = "Jeda Rekaman",
		toggle_path = "Toggle Jalur",
		play_playback = "Putar/Stop Playback",
		stop_playback = "Stop Playback",
		follow_player = "Ikuti Pemain",
		toggle_shift_lock = "Toggle Kunci Shift",
		toggle_anti_slip = "Toggle Anti-Slip",
		toggle_auto_jump = "Toggle Lompat Otomatis",
		toggle_quick_boost = "Toggle Boost Cepat",
		toggle_real_esp = "Toggle ESP Jalur Nyata",
		minimize_ui = "Minimalkan UI",
		click_to_bind = "Klik untuk bind...",
		press_key = "Tekan tombol apa saja...",
		duplicate_keybind = "Duplikat Tombol",
		key_already_used = "'%s' sudah digunakan oleh aksi lain!",

		-- Auto Execute
		auto_execute = "EKSEKUSI OTOMATIS",
		auto_execute_enabled = "Eksekusi Otomatis aktif! Script akan berjalan otomatis saat game mulai.",
		auto_execute_disabled = "Eksekusi Otomatis nonaktif.",
		save_auto_exec = "💾 SIMPAN PENGATURAN EKSEKUSI OTOMATIS",
		saved = "✅ TERSIMPAN!",
		script_created = "✅ Script dibuat",
		could_not_create = "⚠️ Tidak bisa membuat script auto-exec (periksa izin folder)",
		auto_exec_disabled = "🔴 Auto-exec nonaktif",
		detected = "🔍 Terdeteksi",
		path = "Path",
		seliware_instructions = "📝 Pengguna Seliware: Gunakan path kustom C:/Users/NAMAANDA/AppData/Local/seliware-autoexec\nRestart executor setelah menyimpan agar perubahan berlaku.",

		-- Auto-Enable
		auto_enable = "FITUR OTOMATIS AKTIF",
		auto_enable_saved = "Pengaturan Tersimpan",
		auto_enable_desc = "Pengaturan tersimpan! Juga termasuk saat Anda menyimpan profil.",
		select_features = "Pilih fitur yang otomatis aktif saat script dimuat",

		-- Themes
		themes = "TEMA",
		theme = "Tema",
		accent_color = "Warna Aksen",

		-- Language
		language = "BAHASA",
		select_language = "Pilih Bahasa",
		language_changed = "Bahasa berhasil diubah!",

		-- Recording Tab
		recording = "REKAMAN",
		recording_saved = "Rekaman Tersimpan",
		frames_saved = "%d frame disimpan ke %s",
		smoothing_failed = "Smoothing Gagal",
		not_enough_frames = "Frame tidak cukup.",
		path_smoothed = "Jalur dihaluskan secara permanen (belum disimpan).",
		success = "Sukses",
		ready_to_record = "SIAP MEREKAM",
		press_start = "Tekan Start atau F5 untuk memulai",
		recording_in_progress = "REKAMAN BERLANGSUNG",
		duration = "Durasi",
		recording_paused = "REKAMAN DIJEDA",
		rewind_mode_active = "Mode Rewind Aktif",
		start = "MULAI",
		pause = "JEDA",

		mode_strict = "MODE: KETAT",
		mode_flexible = "MODE: FLEKSIBEL",
		path_on = "JALUR: AKTIF",
		path_off = "JALUR: MATI",
		rewind = "MUNDUR",
		cut_resume = "POTONG & LANJUT",
		save_btn = "SIMPAN",
		filename = "Nama file...",
		files = "FILE",
		no_files = "Tidak ada file",
		rename = "UBAH NAMA",
		select = "PILIH",

		-- Custom Animations
		custom_animations = "ANIMASI KUSTOM",
		status_ready = "Status: Siap",
		status = "Status",
		type = "TIPE",
		search = "Cari...",
		anim_name = "Nama Animasi...",
		asset_id_url = "Asset ID / URL...",
		add_apply_animation = "TAMBAH / TERAPKAN ANIMASI",
		id_required = "ID Diperlukan!",
		invalid_id_format = "Format ID Tidak Valid",
		added = "Ditambahkan",
		reset_to_original = "RESET KE ASLI",
		reset_original = "Reset ke Asli",
		original_not_found = "Asli Tidak Ditemukan",
		deleted_item = "Dihapus",
		set_anim = "Atur",

		-- Server
		server = "SERVER",
		browser = "JELAJAHI",
		rejoin = "GABUNG ULANG",
		server_list = "DAFTAR SERVER",
		fetching_servers = "Mengambil Server...",
		no_servers_found = "Tidak ada server ditemukan.",
		invalid_data = "Data Tidak Valid.",

		-- Recording Tools
		recording_tools = "ALAT REKAMAN",
		live_smoothing_auto = "SMOOTHING LANGSUNG (OTOMATIS)",
		strength = "KEKUATAN",
		live_smooth = "SMOOTH LANGSUNG",
		pos_based = "BERBASIS POSISI",
		pos_based_desc = "BERBASIS POSISI: Gerakan tanah lebih halus (mengikuti jalur langsung)",
		manual_apply = "Terapkan Manual (Permanen)",

		-- Privacy / Streamer Mode
		privacy_streamer = "PRIVASI (MODE STREAMER)",
		privacy_desc = "Ubah nama Anda untuk streaming/screenshot (SISI KLIEN SAJA - hanya Anda yang melihat nama palsu)",
		fake_username = "Username Palsu...",
		fake_display_name = "Nama Tampilan Palsu...",
		spoof = "PALSU",
		random_name = "NAMA ACAK",

		-- Players
		players_section = "PEMAIN",
		hide_all_players = "SEMBUNYIKAN SEMUA PEMAIN",

		-- Skybox Changer
		skybox_changer = "PENGUBAH SKYBOX",
		current = "Saat Ini",
		select_skybox = "Pilih Skybox",

		-- HD Shader
		hd_shader = "SHADER HD",
		preset = "Preset",
		select_preset = "Pilih preset untuk meningkatkan grafis",
		shader_disabled = "Shader dinonaktifkan",
		shader_active = "shader aktif!",
		hd_natural = "HD Natural",
		cinematic = "Sinematik",
		turn_off = "MATIKAN",

		-- Fun Tab
		touch_fling = "SENTUH LEMPAR",
		fling = "LEMPAR",
		expand_hitbox = "PERBESAR HITBOX",
		bigger_hitbox = "Hitbox lebih besar = lebih mudah melempar!",
		invisible = "TAK TERLIHAT",
		invisible_desc = "Mode tak terlihat bypass FE",
		teleport_to_player = "TELEPORT KE PEMAIN",
		select_player = "Pilih Pemain...",
		teleported_to = "Diteleportasi ke",
		teleporting_steps = "Teleportasi bertahap...",
		spectate_player = "TONTON PEMAIN",
		spectate = "TONTON",
		stop_spectate = "STOP TONTON",
		spectating = "Menonton",
		friends_in_server = "TEMAN DI SERVER",
		object_aura = "AURA OBJEK (PELEMPAR SAMPAH)",
		start_fling = "MULAI LEMPAR",
		stop_fling = "STOP LEMPAR",
		fling_stopped = "Lempar dihentikan",
		auto_follow = "IKUTI OTOMATIS",
		follow = "IKUTI",
		stop_follow = "STOP IKUTI",
		following = "Mengikuti",
		black_hole = "Lubang Hitam",
		invert_gravity = "Balik Gravitasi",
		part_destroyer = "Penghancur Part",
		part_magnet = "Magnet Part",
		magnet_radius = "Radius Magnet",
		magnet_strength = "Kekuatan Magnet",
		orbit_ring = "Cincin Orbit",
		ring_radius = "Radius Cincin",
		ring_speed = "Kecepatan Cincin",

		-- Recording UI extras
		rewind_control = "KONTROL MUNDUR",
		resume_recording = "LANJUTKAN REKAMAN",
		recordings = "REKAMAN",
		status_idle = "Status: Siap",
		path_visualizer = "Visualisasi Jalur",
		discard = "BUANG",
		go = "MULAI!",
		ready = "Siap",
		loading = "MEMUAT...",
		tags = "TAG",

		-- List Map UI
		strict_retarget = "RETARGET KETAT",
		native_anim = "ANIMASI NATIVE",

		-- Playback
		playback = "PLAYBACK",
		loading_playback = "Memuat Playback",
		preparing = "Menyiapkan %s...",
		file_not_found = "File tidak ditemukan",
		error = "Error",
		live_smoothing = "Smoothing Langsung",
		applied_smoothing = "Smoothing diterapkan (Kekuatan: %d)",
		warning_different_map = "PERINGATAN: Map Berbeda?",
		nearest_path_warning = "Titik jalur terdekat %.0f stud jauhnya! Rekaman ini mungkin dari game/map berbeda.",
		-- PlaceId + Distance Validation (Option B)
		info = "Info",
		path_far_same_game = "Jalur %.0f stud jauhnya, tapi game sama terdeteksi. Anda mungkin perlu pergi ke lokasi rekaman.",
		warning_different_game = "⚠️ Game Berbeda",
		different_placeid_nearby = "Rekaman dari PlaceId %s, saat ini: %s. Jalur dekat - mungkin map serupa.",
		error_wrong_game = "🛑 Game Salah",
		wrong_game_warning = "Rekaman ini dari game berbeda dan jalur %.0f stud jauhnya!",
		wrong_game_detected = "GAME SALAH TERDETEKSI",
		wrong_game_confirm = "PlaceId Rekaman: %s\nPlaceId Saat Ini: %s\nJarak jalur: %.0f stud\n\nRekaman ini tampaknya dari game berbeda. Tetap lanjutkan?",
		respawn = "Respawn",
		respawning_in = "Respawn dalam 5 detik...",
		loop = "Loop",
		restarting_playback = "Memulai ulang playback dalam 5 detik...",
		cross_rig_playback = "Playback Lintas Rig",

		-- Merger Tab
		merger = "PENGGABUNGAN",
		select_files_to_merge = "PILIH FILE UNTUK DIGABUNG",
		search_files = "Cari file...",
		selected = "Dipilih",
		total_files = "file",
		merge = "GABUNG",
		merge_selected = "GABUNG YANG DIPILIH",
		clear_selection = "HAPUS PILIHAN",
		select_all = "PILIH SEMUA",
		deselect_all = "BATAL PILIH SEMUA",
		output_name = "Nama output...",
		merge_success = "Berhasil Digabung",
		merged_files = "%d file digabung menjadi %s",
		no_files_selected = "Tidak ada file dipilih",
		select_at_least_two = "Pilih minimal 2 file untuk digabung",

		-- List Map Tab
		list_map = "DAFTAR MAP",
		map_recordings = "REKAMAN MAP",
		search_maps = "Cari map...",
		total_maps = "Total: %d map",
		no_maps_found = "Tidak ada map ditemukan",
		play_recording = "PUTAR",
		stop_recording = "BERHENTI",
		delete_recording = "HAPUS",
		rename_recording = "UBAH NAMA",
		new_name = "Nama baru...",
		confirm_delete = "Konfirmasi Hapus",
		delete_file_confirm = "Hapus file '%s' secara permanen?",
		file_deleted = "File Dihapus",
		deleted = "%s dihapus",
		file_renamed = "File Diubah Nama",
		renamed_to = "Diubah menjadi %s",
		different_map_warning = "Peringatan Map Berbeda",
		workspace = "Ruang Kerja",
		default_workspace = "Default",
		create_workspace = "Buat Ruang Kerja",
		workspace_name = "Nama ruang kerja...",
		workspace_created = "Ruang Kerja Dibuat",

		-- Path Visualization
		path_visualization = "Visualisasi Jalur",
		path_enabled = "Jalur aktif",
		path_disabled = "Jalur nonaktif",

		-- Animation
		animation_system = "Sistem Animasi",

		-- Dashboard Tab
		good_morning = "Selamat Pagi",
		good_afternoon = "Selamat Siang",
		good_evening = "Selamat Malam",
		premium = "PREMIUM",
		game_detection = "DETEKSI GAME",
		game_info = "INFO GAME",
		game = "Game",
		place_id = "Place ID",
		job_id = "Job ID",
		players = "Pemain",
		executor = "Executor",
		server_info = "INFO SERVER",
		discord = "DISCORD",
		join_discord = "Bergabung ke Discord kami",
		copy_link = "SALIN LINK",
		link_copied = "Link disalin!",
		friends_in_game = "TEMAN DI GAME INI",
		no_friends = "Tidak ada teman di game ini",
		refresh = "SEGARKAN",
		join = "GABUNG",
		server_age = "Umur Server",
		ping = "Ping",
		fps = "FPS",
		copy = "SALIN",
		copied = "TERSALIN!",
		ok = "OK!",
		version = "Versi",
		hwid = "HWID",
		your_account = "AKUN ANDA",
		username = "Nama Pengguna",
		display_name = "Nama Tampilan",
		user_id = "ID Pengguna",
		copy_discord = "SALIN UNDANGAN DISCORD",
		tp = "TP",
		executor_info = "INFO EXECUTOR",

		-- Initial Setup
		initial_setup = "PENGATURAN AWAL",
		configure_preferences = "Atur preferensimu",
		anonymous_mode = "Mode Anonim",
		anonymous_desc = "Sembunyikan identitas dengan nama acak",
		show_nametags = "Tampilkan Nametag",
		nametags_desc = "Tampilkan tag VIP/Script",
		dont_show_again = "Jangan tampilkan lagi",
		continue_btn = "LANJUTKAN",

		-- Warp Tab
		warp_points = "TITIK WARP & KONFIGURASI",
		add_point = "TAMBAH TITIK",
		clear = "HAPUS",
		delay = "Jeda (d)",
		auto = "OTOMATIS",
		total_time = "Total",
		run_time = "Jalan",
		config_name = "Nama Konfigurasi...",
		save_config = "SIMPAN CONFIG",
		start_loop = "MULAI\nLOOP",
		stop_loop = "STOP\nLOOP",
		warp_stopped = "Warp Berhenti",
		warp_running = "Warp Berjalan",
		point_added = "Titik Ditambahkan",
		points_cleared = "Titik Dihapus",
		config_saved = "Konfigurasi Tersimpan",
		config_loaded = "Konfigurasi Dimuat",
		config_deleted = "Konfigurasi Dihapus",

		-- Fun Tab
		character_mods = "MODIFIKASI KARAKTER",
		fly = "TERBANG",
		fly_desc = "Terbang di sekitar peta",
		noclip = "TEMBUS",
		noclip_desc = "Jalan menembus dinding",
		speed = "KECEPATAN",
		speed_desc = "Atur kecepatan jalan",
		jump_power = "KEKUATAN LOMPAT",
		jump_power_desc = "Atur tinggi lompatan",
		gravity = "GRAVITASI",
		gravity_desc = "Atur gravitasi dunia",
		teleport = "TELEPORT",
		bring_player = "Bawa Pemain",
		goto_position = "Pergi ke Posisi",
		visual_mods = "MODIFIKASI VISUAL",
		freecam = "KAMERA BEBAS",
		freecam_desc = "Gerakan kamera bebas",
		field_of_view = "FOV",
		third_person = "Jarak Orang Ketiga",

		-- Emotes Tab
		emotes_catalog = "KATALOG",
		emotes_saved = "TERSIMPAN",
		search_emotes = "Cari emote...",
		play = "PUTAR",
		stop = "STOP",
		save_emote = "SIMPAN",
		remove_emote = "HAPUS",
		emote_speed = "Kecepatan",
		emote_looped = "Berulang",
		no_saved_emotes = "Tidak ada emote tersimpan",
		emote_saved = "Emote Tersimpan",
		emote_removed = "Emote Dihapus",
		playing_emote = "Memutar Emote",
		stopped_emote = "Emote Dihentikan",

		-- Target Recording
		target_recording = "Rekam Target",
		open_target_recorder = "BUKA PEREKAM TARGET",
		select_player = "Pilih Pemain",
		select_player_first = "Silakan pilih pemain terlebih dahulu",
		select_player_to_record = "Pilih pemain untuk direkam",
		start_recording = "Mulai Rekam",
		stop_recording = "Hentikan Rekam",
		started_recording = "Mulai merekam",
		stopped_recording = "Rekaman dihentikan",
		target_not_found = "Karakter target tidak ditemukan",
		target_player_left = "Pemain target meninggalkan game",
		no_other_players = "Tidak ada pemain lain di server",
		no_data_recorded = "Tidak ada data terekam",
		no_data_to_save = "Tidak ada data untuk disimpan",
		recording_data_cleared = "Data rekaman dihapus",
		recordings = "Rekaman",
		no_files = "Tidak ada file",

		-- Async Loading
		loading_recording = "Memuat Rekaman...",
		parsing_large_file = "Memproses file besar...",
		processing_frames = "Memproses frame...",
		recording_loaded = "Rekaman Dimuat",
		invalid_recording_file = "File rekaman tidak valid",

		-- Before Fall (Rewind)
		before_fall = "SEBELUM JATUH",
		before_fall_hint = "Seret slider atau gunakan SEBELUM JATUH untuk lompat ke posisi aman",
		before_fall_not_enough = "Frame yang direkam tidak cukup",
		before_fall_set = "Diatur ke %.1fs (sebelum lompat/jatuh)",
		before_fall_no_fall = "Tidak ada jatuhan terdeteksi di rekaman",
	},
}

-- Available languages list
local AvailableLanguages = {
	{ code = "en", name = "English", flag = "🇺🇸" },
	{ code = "id", name = "Bahasa Indonesia", flag = "🇮🇩" },
}

-- ═══════════════════════════════════════════════════════════════════
-- API FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

-- Get current language code
function Locale.GetLanguage()
	return CurrentLanguage
end

-- Set current language
function Locale.SetLanguage(langCode)
	if Translations[langCode] then
		local oldLang = CurrentLanguage
		CurrentLanguage = langCode

		-- Refresh all registered UI elements
		if oldLang ~= langCode then
			Locale.RefreshAllElements()
			-- Call all language change callbacks
			for _, callback in ipairs(OnLanguageChangeCallbacks) do
				pcall(callback, langCode, oldLang)
			end
		end

		return true
	end
	return false
end

-- Register a UI element for auto-refresh when language changes
-- element: the UI element (TextLabel, TextButton, etc.)
-- key: the translation key
-- formatArgs: optional function that returns format arguments
function Locale.RegisterElement(element, key, formatArgs)
	if element and key then
		table.insert(RegisteredElements, {
			Element = element,
			Key = key,
			FormatArgs = formatArgs,
		})
		-- Set initial text
		if formatArgs then
			local args = formatArgs()
			if args then
				element.Text = Locale.Get(key, unpack(args))
			else
				element.Text = Locale.Get(key)
			end
		else
			element.Text = Locale.Get(key)
		end
	end
end

-- Register a UI element with a custom update function
-- element: the UI element
-- updateFunc: function(element, L) that updates the element
function Locale.RegisterCustom(element, updateFunc)
	if element and updateFunc then
		table.insert(RegisteredElements, {
			Element = element,
			CustomUpdate = updateFunc,
		})
		-- Set initial state
		pcall(updateFunc, element, Locale.Get)
	end
end

-- Refresh all registered UI elements
function Locale.RefreshAllElements()
	local toRemove = {}
	for i, reg in ipairs(RegisteredElements) do
		if reg.Element and reg.Element.Parent then
			if reg.CustomUpdate then
				pcall(reg.CustomUpdate, reg.Element, Locale.Get)
			elseif reg.Key then
				if reg.FormatArgs then
					local args = reg.FormatArgs()
					if args then
						reg.Element.Text = Locale.Get(reg.Key, unpack(args))
					else
						reg.Element.Text = Locale.Get(reg.Key)
					end
				else
					reg.Element.Text = Locale.Get(reg.Key)
				end
			end
		else
			-- Element was destroyed, mark for removal
			table.insert(toRemove, i)
		end
	end
	-- Remove destroyed elements (in reverse order)
	for i = #toRemove, 1, -1 do
		table.remove(RegisteredElements, toRemove[i])
	end
end

-- Register a callback for language changes
function Locale.OnLanguageChange(callback)
	if callback and type(callback) == "function" then
		table.insert(OnLanguageChangeCallbacks, callback)
	end
end

-- Clear all registered elements (useful for cleanup)
function Locale.ClearRegisteredElements()
	RegisteredElements = {}
end

-- Get translated text by key
-- Usage: Locale.Get("welcome") or Locale.Get("frames_saved", 100, "test.json")
function Locale.Get(key, ...)
	local lang = Translations[CurrentLanguage] or Translations["en"]
	local text = lang[key]

	-- Fallback to English if key not found in current language
	if not text then
		text = Translations["en"][key]
	end

	-- If still not found, return the key itself
	if not text then
		return key
	end

	-- Handle string formatting with arguments
	local args = { ... }
	if #args > 0 then
		local success, result = pcall(string.format, text, unpack(args))
		if success then
			return result
		end
	end

	return text
end

-- Shorthand alias for Get
Locale.T = Locale.Get

-- Get list of available languages
function Locale.GetAvailableLanguages()
	return AvailableLanguages
end

-- Get language name by code
function Locale.GetLanguageName(code)
	for _, lang in ipairs(AvailableLanguages) do
		if lang.code == code then
			return lang.name
		end
	end
	return "Unknown"
end

-- Get language flag by code
function Locale.GetLanguageFlag(code)
	for _, lang in ipairs(AvailableLanguages) do
		if lang.code == code then
			return lang.flag
		end
	end
	return "🌐"
end

-- Check if a language is supported
function Locale.IsSupported(langCode)
	return Translations[langCode] ~= nil
end

-- Get all translation keys (useful for debugging)
function Locale.GetAllKeys()
	local keys = {}
	for key, _ in pairs(Translations["en"]) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

return Locale
