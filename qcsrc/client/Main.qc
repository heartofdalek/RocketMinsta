// --------------------------------------------------------------------------
// BEGIN REQUIRED CSQC FUNCTIONS
//include "main.qh"

#define DP_CSQC_ENTITY_REMOVE_IS_B0RKED

void cvar_clientsettemp(string cv, string val)
{
	entity e;
	for(e = world; (e = find(e, classname, "saved_cvar_value")); )
		if(e.netname == cv)
			goto saved;
	e = spawn();
	e.classname = "saved_cvar_value";
	e.netname = strzone(cv);
	e.message = strzone(cvar_string(cv));
:saved
	cvar_set(cv, val);
}

void cvar_clientsettemp_restore()
{
	entity e;
	for(e = world; (e = find(e, classname, "saved_cvar_value")); )
			cvar_set(e.netname, e.message);
}

// CSQC_Init : Called every time the CSQC code is initialized (essentially at map load)
// Useful for precaching things

string TryBind(string cmds, string keys) {
    float ncmds = tokenize(cmds);
    float nkeys;
    float i, j, k;
    string cmd, kname, prefercmd, kbound;

    for(i = 0; i < ncmds; ++i) {
        cmd = argv(i);
        if(!i)
            prefercmd = cmd;

        nkeys = tokenize(findkeysforcommand(cmd));
        for(j = 0; j < nkeys; ++j) {
            k = stof(argv(j));
            if(k >= 0) {
                print("Found an acceptable binding: ", cmd, " -> ", keynumtostring(k), "\n");
                return keys;
            }
        }
        ncmds = tokenize(cmds);
    }

    print("None of ", cmds, " are bound - trying to bind\n");

    nkeys = tokenize(keys);
    for(i = 0; i < nkeys; ++i) {
        k = stringtokeynum(argv(i));

        // I'm not sure when exactly this bug got fixed...
        if(!checkextension("DP_CSQC_BINDMAPS"))
            k = fix_int_return_value(k);

        if(k <= 0) {
            print("Invalid key: ", argv(i), "\n");
            continue;
        }

        kname = keynumtostring(k);
        cmd = getkeybind(k);

        if(cmd) {
            print(kname, " is already bound to ", getkeybind(k), "\n");
        } else {
            print(ftos(k), " ", argv(i), " ", kname, " is free - binding to ", prefercmd, "\n");
            kbound = kname;
            localcmd("bind ", kname, " ", prefercmd, "\n");
            break;
        }
    }

    if(kbound) {
        keys = "";
        for(i = 0; i < nkeys; ++i) {
            kname = keynumtostring(stringtokeynum(argv(i)));
            if(kname != kbound)
                keys = strcat(keys, "'", kname, "'", " ");
        }
        return keys;
    }
    
    print("TryBind(", cmds, ", ", keys, ") failed!\n");
    return keys;
}

#ifdef USE_FTE
float __engine_check;
#endif

string forcefog;
void WaypointSprite_Load();
void CSQC_Init(void)
{
#ifdef USE_FTE
#pragma target ID
	__engine_check = checkextension("DP_SV_WRITEPICTURE");
	if(!__engine_check)
	{
		print("^3Your engine build is outdated\n^3This Server uses a newer QC VM. Please update!\n");
		localcmd("\ndisconnect\n");
		return;
	}
#pragma target FTE
#endif
	
	check_unacceptable_compiler_bugs();

	float i;
    SetupFonts();
	dprint_load();

	binddb = db_create();
	tempdb = db_create();
	compressShortVector_init();

	drawfont = 0;

	for(i = 0; i < RM_MAXCLIENTS; ++i)
		if(getplayerkey(i, "viewentity") == "")
			break;
	maxclients = i;

	registercmd("ons_map");

	registercmd("+button3");
	registercmd("-button3");
	registercmd("+button4");
	registercmd("-button4");
	registercmd("+showaccuracy");registercmd("-showaccuracy");

#ifndef CAMERATEST
	if(isdemo())
	{
#endif
		registercmd("+forward");registercmd("-forward");
		registercmd("+back");registercmd("-back");
		registercmd("+moveup");registercmd("-moveup");
		registercmd("+movedown");registercmd("-movedown");
		registercmd("+moveright");registercmd("-moveright");
		registercmd("+moveleft");registercmd("-moveleft");
		registercmd("+roll_right");registercmd("-roll_right");
		registercmd("+roll_left");registercmd("-roll_left");
#ifndef CAMERATEST
	}
#endif

    registercvar("cl_rpn_autoload", "", CVAR_SAVE);
	registercvar("sbar_usecsqc", "1");
	registercvar("sbar_columns", "default", CVAR_SAVE);
    registercvar("rm_visualdamage_fontsize", "20", CVAR_SAVE);
    registercvar("rm_visualdamage_limit", "20", CVAR_SAVE);
    registercvar("rm_visualdamage_spreadout", "1", CVAR_SAVE);
    registercvar("rm_visualdamage_nooverlap", "0", CVAR_SAVE);
    registercvar("rm_visualdamage_movespeed", "1", CVAR_SAVE);
    registercvar("rm_showplayername", "1", CVAR_SAVE);
    registercvar("rm_fps_friendly", "0", CVAR_SAVE);
    registercvar("rm_hud_healthcolor", "0", CVAR_SAVE);
    registercvar("rm_hud_crosshair_ring_size", "2", CVAR_SAVE);
    registercvar("rm_hud_crosshair_ring_alpha", "0.25", CVAR_SAVE);
    registercvar("cl_effects_lightningarc_count", "1", CVAR_SAVE);
    registercvar("g_waypointsprite_pointer_scale", "1", CVAR_SAVE);
    registercvar("g_waypointsprite_pointer_edgefadescale", "1", CVAR_SAVE);
	registercvar("cl_lowammowarnings", "1", CVAR_SAVE);
	registercvar("cl_lowammowarnings_bullets", "20", CVAR_SAVE);
	registercvar("cl_lowammowarnings_cells", "15", CVAR_SAVE);
	registercvar("cl_lowammowarnings_rockets", "10", CVAR_SAVE);
	registercvar("cl_lowammowarnings_shells", "10", CVAR_SAVE);
	registercvar("cl_lowammowarnings_cells", "10", CVAR_SAVE);
	registercvar("cl_lowammowarnings_zapper_heat", "25", CVAR_SAVE);
	registercvar("cl_lowammowarnings_size", "20", CVAR_SAVE);
	registercvar("cl_lowammowarnings_position", "30", CVAR_SAVE);
    registercvar("crosshair_zapper", "", CVAR_SAVE);
    registercvar("crosshair_zapper_size", "0.5", CVAR_SAVE);
    registercvar("crosshair_zapper_color_red", "0", CVAR_SAVE);
    registercvar("crosshair_zapper_color_green", "0.7", CVAR_SAVE);
    registercvar("crosshair_zapper_color_blue", "1", CVAR_SAVE);
    registercvar("crosshair_zapper_color_alpha", "1", CVAR_SAVE);
    registercvar("crosshair_flak", "", CVAR_SAVE);
    registercvar("crosshair_flak_size", "0.6", CVAR_SAVE);
    registercvar("crosshair_flak_color_red", "1", CVAR_SAVE);
    registercvar("crosshair_flak_color_green", "0.5", CVAR_SAVE);
    registercvar("crosshair_flak_color_blue", "0", CVAR_SAVE);
    registercvar("crosshair_flak_color_alpha", "1", CVAR_SAVE);
    registercvar("cl_truezapper", "0", CVAR_SAVE);
    registercvar("cl_frozentint", "1", CVAR_SAVE);
    registercvar("cl_message", "1", CVAR_SAVE);
    registercvar("cl_message_obituary", "1", CVAR_SAVE);
    registercvar("cl_message_obituary_log", "1", CVAR_SAVE);
    registercvar("cl_message_obituary_log_deaths", "1", CVAR_SAVE);
    registercvar("cl_message_obituary_log_streaks", "1", CVAR_SAVE);
    registercvar("cl_message_obituary_log_multikills", "1", CVAR_SAVE);
    registercvar("cl_message_obituary_frags", "1", CVAR_SAVE);
    registercvar("cl_message_obituary_frags_extended", "1", CVAR_SAVE);
    registercvar("cl_message_obituary_streaks", "1", CVAR_SAVE);
    registercvar("cl_message_obituary_multikills", "1", CVAR_SAVE);
    registercvar("cl_message_praise", "1", CVAR_SAVE);
    registercvar("cl_message_praise_show", "1", CVAR_SAVE);
    registercvar("cl_message_praise_announce", "1", CVAR_SAVE);
    registercvar("cl_warpzone_sound_transition", "0", CVAR_SAVE);

    gametype = 0;

	// sbar_fields uses strunzone on the titles!
	for(i = 0; i < MAX_SBAR_FIELDS; ++i)
		sbar_title[i] = strzone("(null)");

	postinit = false;

	calledhooks = 0;

	teams = Sort_Spawn();
	players = Sort_Spawn();

	GetTeam(COLOR_SPECTATOR, true); // add specs first

	cvar_clientsettemp("_supports_weaponpriority", "1");

	RegisterWeapons();

	WaypointSprite_Load();

	Projectile_Precache();
	GibSplash_Precache();
	Casings_Precache();
	DamageInfo_Precache();
	Announcer_Precache();

	get_mi_min_max_texcoords(1); // try the CLEVER way first
	minimapname = strcat("gfx/", mi_shortname, "_radar.tga");
	shortmapname = mi_shortname;
    whatsgoingon = ISFAGGOTMAP(shortmapname);
    
	if(precache_pic(minimapname) == "")
	{
		// but maybe we have a non-clever minimap
		minimapname = strcat("gfx/", mi_shortname, "_mini.tga");
		if(precache_pic(minimapname) == "")
			minimapname = ""; // FAIL
		else
			get_mi_min_max_texcoords(0); // load new texcoords
	}

	mi_center = (mi_min + mi_max) * 0.5;
	mi_scale = mi_max - mi_min;
	minimapname = strzone(minimapname);
	
	vote_statstring = strzone("");
	rm_watermark = RM_BUILD_NAME " " RM_BUILD_VERSION " " RM_BUILD_DATE;
	
	bigprint_string = strzone("");
	bigprint_comment = strzone("");

	print("^1", rm_watermark, "\n");

    dtrack_total = DamageTracker_CreateKeeper(world);
    dtrack_taken = DamageTracker_CreateKeeper(world);
    dtrack_total_spec = DamageTracker_CreateKeeper(world);
    dtrack_taken_spec = DamageTracker_CreateKeeper(world);
    dtrack_global = DamageTracker_CreateKeeper(world);

	IP2C_Init();
    registercvar("_g_nadgets_select_available", "0", 0);
    registercvar("_g_nadgets_select_double", "0", 0);
    registercvar("_secondary_select_available", "0", 0);
    localcmd("cl_particles_reloadeffects\n");

    cvar_clientsettemp("r_transparent_sortmaxdist", "0");

    WarpZone_Init();

    ext_DP_CSQC_QUERYRENDERENTITY = checkextension("DP_CSQC_QUERYRENDERENTITY");
}

// CSQC_Shutdown : Called every time the CSQC code is shutdown (changing maps, quitting, etc)
void CSQC_Shutdown(void)
{
#ifdef USE_FTE
#pragma TARGET id
	if(!__engine_check)
		return 0;
#pragma TARGET fte
#endif

    utf8_disable();
    WarpZone_Shutdown();

	HUDSkin_Unload();
	IP2C_Shutdown();

	remove(teams);
	remove(players);
	db_close(binddb);
	db_close(tempdb);

	cvar_clientsettemp_restore();

	if(camera_active)
		cvar_set("chase_active",ftos(chase_active_backup));

	if not(isdemo())
	{
		if not(calledhooks & HOOK_START)
			localcmd("\n_cl_hook_gamestart nop;");
		if not(calledhooks & HOOK_END)
			localcmd("\ncl_hook_gameend;");
	}
}

.float has_team;
float SetTeam(entity o, float Team)
{
	entity tm;
	if(teamplay)
	{
		switch(Team)
		{
			case -1:
			case COLOR_TEAM1:
			case COLOR_TEAM2:
			case COLOR_TEAM3:
			case COLOR_TEAM4:
				break;
			default:
				if(GetTeam(Team, false) == NULL)
				{
					print("trying to switch to unsupported team ", ftos(Team), "\n");
					Team = COLOR_SPECTATOR;
				}
				break;
		}
	}
	else
	{
		switch(Team)
		{
			case -1:
			case 0:
				break;
			default:
				if(GetTeam(Team, false) == NULL)
				{
					print("trying to switch to unsupported team ", ftos(Team), "\n");
					Team = COLOR_SPECTATOR;
				}
				break;
		}
	}
	if(Team == -1) // leave
	{
		if(o.has_team)
		{
			tm = GetTeam(o.team, false);
			tm.team_size -= 1;
			o.has_team = 0;
			return TRUE;
		}
	}
	else
	{
		if not(o.has_team)
		{
			o.team = Team;
			tm = GetTeam(Team, true);
			tm.team_size += 1;
			o.has_team = 1;
			return TRUE;
		}
		else if(Team != o.team)
		{
			tm = GetTeam(o.team, false);
			tm.team_size -= 1;
			o.team = Team;
			tm = GetTeam(Team, true);
			tm.team_size += 1;
			return TRUE;
		}
	}
	return FALSE;
}

void Playerchecker_Think()
{
	float i;
	entity e;
	for(i = 0; i < maxclients; ++i)
	{
		e = playerslots[i];
		if(GetPlayerName(i) == "")
		{
			if(e.sort_prev)
			{
				// player disconnected
				SetTeam(e, -1);
				RemovePlayer(e);
				e.sort_prev = world;
				//e.gotscores = 0;
			}
		}
		else
		{
			if not(e.sort_prev)
			{
				// player connected
				if not(e)
					playerslots[i] = e = spawn();
				e.sv_entnum = i;
				//e.gotscores = 0; // we might already have the scores...
				SetTeam(e, GetPlayerColor(i)); // will not hurt; later updates come with Sbar_UpdatePlayerTeams
				RegisterPlayer(e);
				Sbar_UpdatePlayerPos(e);
			}
		}
	}
	self.nextthink = time + 0.2;
}

void Porto_Init();
void TrueAim_Init();

#define RM_OUTDATED { print("^xFB0Detected an outdated RMconfig, initializing required cvars...\n"); rm_helptime = time + 20; }

entity tmpmadoka;

float GetBigfont() {
	return if(rm_oldbigfont || dprm_basegame == BASEGAME_VECXIS) sbar_bigfont_real else sbar_rmbigfont;
}

void SetMadokaFont(float v)
{
    if(dprm_basegame == BASEGAME_VECXIS)
        return;

	switch(v)
	{
		case MDKF_SET:
			sbar_bigfont = sbar_madokafont;
			break;
		case MDKF_UNSET:
			sbar_bigfont = GetBigfont();
			break;
		default: case MDKF_AUTO:
			if(madoka_locked)
			{
				if(CVAR(rm_specmadoka))
				{
					sbar_bigfont = if(madokalockstate) sbar_madokafont else GetBigfont();
					return;
				}
			}
			
			sbar_bigfont = if(rm_madoka) sbar_madokafont else GetBigfont();
			break;
	}
}

void Menu_ShowNagger(void) {
    if(!DPRM_VersionIsRecommended())
        localcmd("menu_cmd directmenu engineNagger\n");
}

void ReloadMenu_f()
{
	if(!self.cnt)
	{
		cvar_set("rm_loadedmenu", RM_BUILD_MENUSUM);
		localcmd("menu_restart; r_restart\n");
		self.cnt = 1;
		self.nextthink = time + 1;
	}
	else
	{
		if(rm_helptime)
			localcmd("menu_cmd directmenu RMConfig\n");
			
        Menu_ShowNagger();
		gui_reloading = 0;
		remove(self);
	}
}

void ReloadMenu()
{
	gui_reloading = 1;
	entity e = spawn();
	e.think = ReloadMenu_f;
	e.nextthink = time + 1;
}

void FPSReporter_Think() {
	localcmd("cmd fpsreport ", ftos(floor(cl_fps)), "\n");
	self.nextthink = time + sv_scoreboard_fps_column;
}

void FPSReporter_Init() {
	if not(sv_scoreboard_fps_column)
		return;
	
	entity e = spawn();
	e.think = FPSReporter_Think;
	e.nextthink = time + 1;
}

#define TARGET_RATE 70000

void UpdateClRate(void) {
    float oldrate = CVAR(_cl_rate);

    if(oldrate >= TARGET_RATE)
        return;

    // save it just in case we ever have to roll back
    localcmd("seta _rm_cl_rate_saved ", ftos(oldrate), "\n");
    localcmd("rate ", ftos(TARGET_RATE), "\n");
}

void TryBindCRAKeys(void) {
    string keyprio = "'e' 'q' 'r' 'f' 'c' 'x' 'v' 'g' 'w' 'a' 's' 'd'";

    keyprio = TryBind("'+nadget' '+hook' '+button6'", keyprio);
    keyprio = TryBind("'+nadget2' '+button9'", keyprio);
    keyprio = TryBind("'dropweapon' 'impulse 17'", keyprio);
    keyprio = TryBind("'+use'", keyprio);
}

void AddMasterServer(string addr, string alt) {
    var success = FALSE;
    var i = 1;

    while(TRUE) {
        var cv = "sv_masterextra" + i;

        if(!(cvar_type(cv) & CVAR_TYPEFLAG_ENGINE))
            break;

        if(cvar_string(cv) == addr)
            return;

        if(cvar_string(cv) == alt)
            return;

        i += 1;
    }

    i = 1;

    while(TRUE) {
        var cv = "sv_master" + i;

        if(!(cvar_type(cv) & CVAR_TYPEFLAG_ENGINE))
            break;

        if(cvar_string(cv) == addr) {
            success = TRUE;
            break;
        }

        if(cvar_string(cv) == "" || cvar_string(cv) == alt) {
            cvar_set(cv, addr);
            success = TRUE;
            break;
        }

        i += 1;
    }

    if(success) {
        i += 1;

        while(TRUE) {
            var cv = "sv_master" + i;

            if(!(cvar_type(cv) & CVAR_TYPEFLAG_ENGINE))
                break;

            if(cvar_string(cv) == addr || cvar_string(cv) == alt)
                cvar_set(cv, "");

            i += 1;
        }
    } else {
        print("^3WARNING: ^7couldn't register master server ^2", addr, "^7!\n");
    }
}

void RemoveDuplicateMasterServers(void) {
    var i = 1;

    while(TRUE) {
        var cv = "sv_master" + i;

        if(!(cvar_type(cv) & CVAR_TYPEFLAG_ENGINE))
            break;

        i += 1;

        var val = cvar_string(cv);

        if(val == "")
            continue;

        var j = i;

        while(TRUE) {
            var cv2 = "sv_master" + j;

            if(!(cvar_type(cv2) & CVAR_TYPEFLAG_ENGINE))
                break;

            if(cvar_string(cv2) == val)
                cvar_set(cv2, "");

            j += 1;
        }
    }
}

void RegisterMasterServers(void) {
    RemoveDuplicateMasterServers();
    AddMasterServer("nex.thebadasschoobs.org",  "91.121.161.160");  // Nude Dudes master server
    AddMasterServer("dpmaster.deathmask.net",   "107.161.23.68");   // dpmaster.deathmask.net
    AddMasterServer("dpmaster.vecxis.com",      "162.243.128.63");  // Vecxis master server
    AddMasterServer("ghdigital.com",            "207.55.114.154");  // LordHavoc's master server
    AddMasterServer("dpmaster.tchr.no",         "92.62.40.73");     // tChr's master server
}

void InitFonts(void) {
    SetMadokaFont(MDKF_AUTO);

    if(!utf8_supported()) {
        load_fonts();
    } else if(dprm_basegame == BASEGAME_NEXUIZ) spawn() {
        think: inline void(void) {
            if(!utf8_enabled())
                utf8_enable();
            fix_fonts();
            self.nextthink = time + 1;
        },
        nextthink: time
    };
}

void ReportHUDInfo(string hskin) {
    if(sv_showspecs_extra)
        localcmd("cmd hudinfo ", ftos(CVAR(rm_oldhud)), " ", ftos(CVAR(rm_althud)), " ", hskin, "\n");
}

float warpzone_sound_transition;

void PostInit(void)
{
	print(strcat("PostInit\n    maxclients = ", ftos(maxclients), "\n"));
	localcmd(strcat("\nsbar_columns_set ", CVAR_STR(sbar_columns), ";\n"));

	entity playerchecker;
	playerchecker = spawn();
	playerchecker.think = Playerchecker_Think;
	playerchecker.nextthink = time + 0.2;

	Porto_Init();
	TrueAim_Init();
	
    // XXX: find a better way to deal with config conflicts introduced by Axisar's server.
//#NO AUTOCVARS START
    float cfgver = cvar("rm_initialized");
    if(cfgver >= 44 && !(cvar_type("rm_radio") & CVAR_TYPEFLAG_EXISTS))
        cvar_set("rm_initialized", "42");

	switch(cvar("rm_initialized"))
//#NO AUTOCVARS END
	{
		case 0:
		case 1:
			localcmd("seta rm_showspec 1; showspec 1\n");
			localcmd("seta rm_showdamage 1; showdamage 1\n");
			localcmd("seta rm_teamlasers 1; teamlasers 1\n");
		case 2:
		case 3:
		case 4:
		case 5:
			localcmd("seta rm_nobigtext 0; nobigtext 0\n");
		case 6:
		case 7:
			localcmd("seta rm_madoka 0; madoka 0\n");
		case 8:
			localcmd("seta rm_hidebigcomments 0; hidebigcomments 0\n");
		case 9:
			localcmd("seta rm_legacyvote 0; legacyvote 0\n");
		case 10:
			localcmd("seta rm_anonspec 0; anonspec 0\n");
		case 11:
			localcmd("seta rm_hidewatermark 0; hidewatermark 0\n");
		case 12:
			//deprecated, but gets set to be friendly to servers with older RM
			localcmd("seta rm_dontmesswithfonts 0; dontmesswithfonts 0\n");
		case 13:
			localcmd("seta rm_specmadoka 1; specmadoka 1\n");
		case 14:
			localcmd("seta rm_crosshealth 0; crosshealth 0\n");
		case 15:
			localcmd("seta rm_simpleeffects 0; simpleeffects 0\n");
		case 16:
        case 17:
			localcmd("seta rm_shownames 1; shownames 1\n");
		case 18:
			localcmd("seta rm_visualscore 1; visualscore 1\n");
		case 19:
			localcmd("seta rm_oldhud 0; oldhud 0\n");
		case 20:
			//localcmd("seta rm_althud 0; althud 0\n");
		case 21:
			//localcmd("seta rm_althud 0; althud 0\n");
		case 22:
			//localcmd("alias afk \"cmd afk\"\n");
		case 23:
			localcmd("seta rm_noflags 0; noflags 0\n");
		case 24:
			localcmd("seta rm_hudskin \"default\"\n");
		case 25:	// yep, nothing here
		case 26:
		case 27:
		case 28:
		case 29:
			localcmd("seta rm_nogamemenu 0; nogamemenu 0\n");
		case 30:
			localcmd("seta rm_notimer 0; notimer 0\n");
		case 31:
			localcmd("seta rm_nokillsound 0; nokillsound 0\n");
		case 32:
			localcmd("seta rm_hidecountry 0; hidecountry 0\n");
		case 33:
			localcmd("seta rm_showrankings 1; showrankings 1\n");
        case 34:
        case 35:
			localcmd("seta rm_shownames_teamonly 0; shownames_teamonly 0\n");
		case 36:
			localcmd("seta rm_freezetag_danger 1; freezetag_danger 1\n");
			localcmd("seta rm_freezetag_danger_silent 1; freezetag_danger_silent 1\n");
		case 37:
        case 38:
            // fight evil with evil
            if(CVAR(cl_gunalign) == 3)
                localcmd("seta cl_gunalign 1; sendcvar cl_gunalign\n");
        case 39:
            cvar_set("_rm_hg_optout", "0");
        case 40:
            localcmd("seta rm_showtimer 0; showtimer 0\n");
        case 41:
            localcmd("seta rm_shownadgetregen 0; shownadgetregen 0\n");
        case 42:
            localcmd("seta cl_effects_lightningarc_count 1\n");
            localcmd("seta cl_effects_lightningarc_segmentlength 24\n");
        case 43:
            localcmd("seta rm_radio 1; radio 1\n");
        case 44:
            localcmd("seta rm_althud 0; althud 0\n");
        case 45:
        case 46:
            localcmd("seta cl_effects_lightningarc_branchfactor_add 0\n");
            localcmd("seta cl_effects_lightningarc_branchfactor_start 0.05\n");
            localcmd("seta cl_effects_lightningarc_drift_start 0.3\n");
        case 47:
            localcmd("seta rm_nododging 0; nododging 0\n");
        case 48:
        case 49:
        case 50:
            TryBindCRAKeys();
        case 51:
        case 52:
            localcmd("seta rm_altcharge 0; altcharge 0\n");
        case 53:
            if(cvar_type("cl_extendfragmessages") & CVAR_TYPEFLAG_EXISTS)
                cvar_set("cl_message_obituary_frags_extended", ftos(CVAR(cl_extendfragmessages)));
        case 54:
            localcmd("seta r_equalize_entities_fullbright 1\n");
        case 55:
            localcmd("seta rm_oldbigfont 0; oldbigfont 0\n");
        case 56:
            localcmd("seta r_font_size_snapping 1\n");
        case 57:
        case 58:
            localcmd("seta rm_convswitch 0; convswitch 0\n");
        case 59:
            localcmd("seta rm_hud_healthcolor 0\n");
        case 60:
        case 61:
            UpdateClRate();
        case 62:
            cvar_set("gl_flashblend", "0");
            cvar_archive("r_shadow_lightintensityscale", "1.0");
            cvar_archive("r_shadow_lightradiusscale", "1.0");
        case 63:
            cvar_set("cl_warpzone_sound_transition", "0");
            warpzone_sound_transition = 0;
        case 64:
            cvar_set("sv_ip2country_server", "udp://91.121.161.160:16886");
        case 65:
            localcmd("seta r_transparentdepthmasking 0\n");
            localcmd("seta scr_loadingscreen_background 1\n");

		//More to come here with each update
		localcmd("seta rm_initialized 66\n");
		RM_OUTDATED
		break;
	}
	
	localcmd("alias afk \"cmd afk\"\n");
	localcmd("alias rmcfg \"menu_cmd directmenu RMConfig\"\n");
    localcmd("alias vinvite \"cmd vote invite $*\"\n");
    localcmd("alias +nadget +button6\n");
    localcmd("alias -nadget -button6\n");
    localcmd("alias +nadget2 +button9\n");
    localcmd("alias -nadget2 -button9\n");

	rm_showspec   = CVAR(rm_showspec);
	rm_showdamage = CVAR(rm_showdamage);
	rm_teamlasers = CVAR(rm_teamlasers);
	rm_nobigtext  = CVAR(rm_nobigtext);
	rm_hidebigcomments = CVAR(rm_hidebigcomments);
	rm_legacyvote = CVAR(rm_legacyvote);
	rm_hidewatermark = CVAR(rm_hidewatermark);
	rm_madoka = CVAR(rm_madoka);
	rm_crosshealth = CVAR(rm_crosshealth);
	rm_simpleeffects = CVAR(rm_simpleeffects);
	rm_shownames = CVAR(rm_shownames);
	rm_visualscore = CVAR(rm_visualscore);
	rm_oldhud_option = CVAR(rm_oldhud);
	rm_althud_option = CVAR(rm_althud);
	rm_oldhud = rm_oldhud_option;
	rm_althud = rm_althud_option;
	rm_noflags = CVAR(rm_noflags);
	rm_showrankings = CVAR(rm_showrankings);
	rm_shownames_teamonly = CVAR(rm_shownames_teamonly);
	rm_oldbigfont = CVAR(rm_oldbigfont);
    rm_showtimer = CVAR(rm_showtimer);
    rm_shownadgetregen = CVAR(rm_shownadgetregen);
    
	registercmd("rmhelp");
	registercmd("showspec");
	registercmd("showdamage");
	registercmd("teamlasers");
	registercmd("nobigtext");
	registercmd("madoka");
	registercmd("hidebigcomments");
	registercmd("legacyvote");
	registercmd("anonspec");
	registercmd("hidewatermark");
	registercmd("dontmesswithfonts");
	registercmd("specmadoka");
	registercmd("crosshealth");
	registercmd("simpleeffects");
	registercmd("shownames");
	registercmd("visualscore");
	registercmd("oldhud");
	registercmd("althud");
	registercmd("noflags");
	registercmd("notimer");
	registercmd("nogamemenu");
	registercmd("nokillsound");
	registercmd("hidecountry");
	registercmd("showrankings");
	registercmd("shownames_teamonly");
	registercmd("oldbigfont");
	registercmd("freezetag_danger");
	registercmd("freezetag_danger_silent");
    registercmd("showtimer");
    registercmd("shownadgetregen");
    registercmd("radio");
    registercmd("nododging");
    registercmd("altcharge");
    registercmd("convswitch");
	// -- //
	registercmd("hudskin");

	if(sv_showspecs_extra)
		localcmd("cmd madoka ", ftos(CVAR(rm_madoka)), "\n");
	tmpmadoka = spawn();

    ReportHUDInfo(CVAR_STR(rm_hudskin));

	localcmd("cmd anonspec ", ftos(CVAR(rm_anonspec)), "\n");
	localcmd("cmd nokillsound ", ftos(CVAR(rm_nokillsound)), "\n");
	localcmd("cmd hidecountry ", ftos(CVAR(rm_hidecountry)), "\n");
    localcmd("cmd radio ", ftos(CVAR(rm_radio)), "\n");
    localcmd("cmd nododging ", ftos(CVAR(rm_nododging)), "\n");
    localcmd("cmd hg_altcharge ", ftos(CVAR(rm_altcharge)), "\n");
    localcmd("cmd convswitch ", ftos(CVAR(rm_convswitch)), "\n");
	
    localcmd("alias menu_shownadeselect \"cmd picknade\"\n");
    localcmd("alias menu_shownadeselect2 \"cmd picknade\"\n");

	if(CVAR(_cl_afkstate))
		localcmd("cmd afk\n");

	HUDSkin_Load(CVAR_STR(rm_hudskin));
	
	screenfade = time + 0.1;
	fovlock = -1;
	
	registercvar("rm_loadedmenu", "");

    var force_reload = (CVAR_STR(rm_loadedmenu) != RM_BUILD_MENUSUM);

    if(!DPRM_GetVersion() && (cvar_type("mod_alias_force_animated") & CVAR_TYPEFLAG_EXISTS) && !cvar("mod_alias_force_animated")) {
        // workaround for broken animations on some engines
        cvar_set("mod_alias_force_animated", "1");

        // just for the r_restart
        force_reload = TRUE;
    }

	if(force_reload)
		ReloadMenu();
	else if(rm_helptime)
		localcmd("menu_cmd directmenu RMConfig\n");
	
    defer(1, Menu_ShowNagger);
    defer(0.5, inline void(void) {
        MapInfo_Get_ByName(shortmapname, 0, 0, FALSE);
        bigprint(strcat("^2", shortmapname), if(MapInfo_Map_title != "<TITLE>") MapInfo_Map_title else "", 2);
    });

	localcmd("cmd menu_request\n"); // workaround against restarts
	FPSReporter_Init();
	DPRM_Start();
	RegisterMasterServers();
    InitFonts();

    mouse_pos = '-1 -1';

	postinit = true;
}

// CSQC_ConsoleCommand : Used to parse commands in the console that have been registered with the "registercmd" function
// Return value should be 1 if CSQC handled the command, otherwise return 0 to have the engine handle it.
float button_zoom;
void Cmd_Sbar_SetFields(float);
void Cmd_Sbar_Help(float);

void(float bufhandle, string pattern, string antipattern) buf_cvarlist = #517;

#define VALUEREQUIRED if(argc < 2) { print(strCmd, " is ", if(cvar(strcat("rm_", strCmd))) "^2ON" else "^1OFF", "\nUsage: ^2", strCmd, " 1^7 to enable, ^2", strCmd, " 0 ^7to disable.\n"); return true; }
#define RMSETTINGREPORT { print(strCmd, " is now ", if(cvar(strcat("rm_", strCmd))) "^2ON\n" else "^1OFF\n"); localcmd("menu_cmd update_rmvars\n"); }
float CSQC_ConsoleCommand(string strMessage)
{
	float argc;
	// Tokenize String
	argc = tokenize_console(strMessage);

	// Acquire Command
	string strCmd;
	strCmd = argv(0);

	if(strCmd == "+button4") { // zoom
		// return false, because the message shall be sent to the server anyway (for demos/speccing)
		if(ignore_plus_zoom)
		{
			--ignore_plus_zoom;
			return false;
		}
		button_zoom = 1;
		return true;
	} else if(strCmd == "-button4") { // zoom
		if(ignore_minus_zoom)
		{
			--ignore_minus_zoom;
			return false;
		}
		button_zoom = 0;
		return true;
	} else if(strCmd == "+button3") { // secondary
		button_attack2 = 1;
		return false;
	} else if(strCmd == "-button3") { // secondary
		button_attack2 = 0;
		return false;
	} else if(strCmd == "+showscores") {
		sb_showscores = true;
		return true;
	} else if(strCmd == "-showscores") {
		sb_showscores = false;
		return true;
	} else if(strCmd == "+showaccuracy") {
		sb_showaccuracy = true;
		return true;
	} else if(strCmd == "-showaccuracy") {
		sb_showaccuracy = false;
		return true;
	}
	else if(strCmd == "rmhelp")
	{
		print("^xFB0RocketMinsta configuration options. ^7To enable an option, type ^2optionname 1^7. To disable, ^2optionname 0^7.\n\n");
		print("^2showspec^7: If enabled, you will see who is spectating you unless the server forbids it (enabled by default)\n");
		print("^2showdamage^7: If enabled, you will see how much damage you deal or take on each hit unless the server forbids it (enabled by default)\n");
		print("^2teamlasers^7: If enabled, laser projectiles will have a team specific color unless the server forbids it (enabled by default)\n");
		print("^2nobigtext^7: If enabled, the top-center big messages (bigprints) will be redirected into the bottom centerprint area (disabled by default)\n");
		print("^2hidebigcomments^7: If enabled, comments for bigprints will not be shown (disabled by default)\n");
		print("^2legacyvote^7: If enabled, votes will be displayed in plaintext instead of a dialog (disabled by default)\n");
		print("^2anonspec^7: Anonymous spectator mode. If enabled, players will not see when you're spectating them, unless the server forbids it (disabled by default)\n");
		print("^2hidewatermark^7: If enabled, the RM build information watermark will not be drawn (disabled by default)\n");
		print("^2crosshealth^7: If enabled, the crosshair color will reflect current health (disabled by default)\n");
		print("^2dontmesswithfonts^7: Deprecated, kept for compatibility\n");
		print("^2simpleeffects^7: Enables simple fade effects for onscreen notifications instead of fancy ones (disabled by default)\n");
		print("^2shownames^7: If enabled, names of players will be shown above their heads (disabled by default)\n");
		print("^2shownames_teamonly^7: If enabled, shownames will work only for allies (disabled by default)\n");
		print("^2visualscore^7: If enabled, changes to your score will be displayed (enabled by default)\n");
		print("^2oldhud^7: If enabled, standard Nexuiz HUD will be used (disabled by default)\n");
		print("^2althud^7: If enabled, use an alternative layout for the HUD (disabled by default)\n");
		print("^2noflags^7: If enabled, plain-text country codes will be shown instead of flags (disabled by default)\n");
		print("^2nododging^7: If enabled, ingame dodging will be switched off (disabled by default)\n");
		print("^2notimer^7: If enabled, the 'time' column will not be shown in the scoreboard (disabled by default)\n");
		print("^2nogamemenu^7: If enabled, will go directly to the main menu when activating menu in-game (disabled by default)\n");
		print("^2nokillsound^7: If enabled, the kill sound will not be used (you'll hear the default hit sound instead) (disabled by default)\n");
		print("^2hidecountry^7: If enabled, your flag in the scoreboard will be replaced with a question mark sign, unless the server forbids it (disabled by default)\n");
		print("^2showrankings^7: If enabled, will show a mini-scoreboard in the HUD (enabled by default)\n");
        print("^2showtimer^7: If enabled, will always show the timer (disabled by default)\n");
        print("^2shownadgetregen^7: If enabled, will show the remaining nadget regeneration time in seconds (RM HUD only) (disabled by default)\n");
		print("^2oldbigfont^7: If enabled, will use Nexuiz's default 'bigfont' instead of the RM one\n");
		print("^2freezetag_danger^7: If enabled, you will be able to place 'danger' waypoints using the fire button while frozen (enabled by default)\n");
		print("^2freezetag_danger_silent^7: If enabled, danger waypoints placed with the fire button shortcut will not post a teamchat message (enabled by default)\n");
        print("^2radio^7: Recieve music broadcasts from the server, if provided (enabled by default)\n");
		
		print("\nIn addition, these commands are available:\n");
		print("^5afk^7: Marks you as being away\n");
		print("^5hudskin^7: Lists or switches HUD skins and displays other HUD-related information\n");
		return true;
	}
	else if(
		strCmd == "showspec" 			||
		strCmd == "showdamage" 			||
		strCmd == "teamlasers"			||
		strCmd == "nobigtext"			||
		strCmd == "hidebigcomments"		||
		strCmd == "legacyvote"			||
		strCmd == "hidewatermark"		||
		strCmd == "dontmesswithfonts"	||
		strCmd == "crosshealth"			||
		strCmd == "simpleeffects"		||
		strCmd == "shownames"			||
		strCmd == "visualscore"			||
		strCmd == "oldhud"				||
		strCmd == "althud"				||
		strCmd == "noflags"				||
		strCmd == "notimer"				||
		strCmd == "nogamemenu"			||
		strCmd == "nokillsound"			||
		strCmd == "nododging"		    ||
		strCmd == "showrankings"		||
        strCmd == "showtimer"           ||
        strCmd == "shownadgetregen"     ||
		strCmd == "shownames_teamonly"  ||
		strCmd == "oldbigfont"			||
        strCmd == "altcharge"           ||
        strCmd == "convswitch"          ||
		strCmd == "freezetag_danger"	||
		strCmd == "freezetag_danger_silent")
	{
		VALUEREQUIRED
		cvar_set(strcat("rm_", strCmd), argv(1));
		rm_showspec = CVAR(rm_showspec);
		rm_showdamage = CVAR(rm_showdamage);
		rm_teamlasers = CVAR(rm_teamlasers);
		rm_nobigtext = CVAR(rm_nobigtext);
		rm_hidebigcomments = CVAR(rm_hidebigcomments);
		rm_legacyvote = CVAR(rm_legacyvote);
		rm_hidewatermark = CVAR(rm_hidewatermark);
		rm_crosshealth = CVAR(rm_crosshealth);
		rm_simpleeffects = CVAR(rm_simpleeffects);
		rm_shownames = CVAR(rm_shownames);
		rm_visualscore = CVAR(rm_visualscore);
		rm_oldhud_option = CVAR(rm_oldhud);
		rm_althud_option = CVAR(rm_althud);

#ifdef RM_SUPPORT_PKG_o_flagicons
		rm_noflags = CVAR(rm_noflags);
#else
        rm_noflags = 0;
#endif

		rm_showrankings = CVAR(rm_showrankings);
		rm_shownames_teamonly = CVAR(rm_shownames_teamonly);
		rm_oldbigfont = CVAR(rm_oldbigfont);
        rm_showtimer = CVAR(rm_showtimer);
        rm_shownadgetregen = CVAR(rm_shownadgetregen);
        //rm_nododging = stof(CVAR_STR(rm_nododging));
		
		if(strCmd == "oldhud" || strCmd == "althud")
		{
			if(hudlocked)
				print("^1Won't change HUD while spectating\n");
			else
			{
				rm_oldhud = rm_oldhud_option;
				rm_althud = rm_althud_option;

                ReportHUDInfo(hudskin_name);
			}
		}
		else if(strCmd == "notimer")
			localcmd("cl_cmd sbar_columns_set default\n");
		else if(strCmd == "nokillsound")
			localcmd("cmd nokillsound ", ftos(CVAR(rm_nokillsound)), "\n");
		else if(strCmd == "nododging")
			localcmd("cmd nododging ", ftos(CVAR(rm_nododging)), "\n");
        else if(strCmd == "altcharge")
            localcmd("cmd hg_altcharge ", ftos(CVAR(rm_altcharge)), "\n");
        else if(strCmd == "convswitch")
            localcmd("cmd convswitch ", ftos(CVAR(rm_convswitch)), "\n");

		SetMadokaFont(MDKF_AUTO);
		RMSETTINGREPORT
		return true;
	}
	else if(strCmd == "madoka")
	{
		if(is_tmpmadoka)
		{
			print("^0Your Soul Gem darkened and turned into a Grief Seed\n");
			localcmd("disconnect\n");
			return true;
		}
		
		VALUEREQUIRED
		
		if(madoka_locked && CVAR(rm_specmadoka))
		{
			print("^1Won't change madoka while spectating\n");
			return true;
		}
		
		cvar_set(strcat("rm_", strCmd), argv(1));
		rm_madoka = CVAR(rm_madoka);
		SetMadokaFont(MDKF_AUTO);
		
		if(sv_showspecs_extra)
			localcmd("cmd madoka ", ftos(CVAR(rm_madoka)), "\n");
		RMSETTINGREPORT
		return true;
	}
	else if(strCmd == "anonspec")
	{
		VALUEREQUIRED
		cvar_set(strcat("rm_", strCmd), argv(1));
		localcmd("cmd anonspec ", ftos(CVAR(rm_anonspec)), "\n");
		RMSETTINGREPORT
		return true;
	}
	else if(strCmd == "specmadoka")
	{
		VALUEREQUIRED
		cvar_set(strcat("rm_", strCmd), argv(1));
		SetMadokaFont(MDKF_AUTO);
		
		RMSETTINGREPORT
		return true;
	}
	else if(strCmd == "hudskin")
	{
		if(argc < 2)
		{
			print("\n^xFB0The following HUD skins are available:\n");
			
			float i, seed, globsize, hsglob = search_begin("gfx/hud/skins/*/skininfo", FALSE, TRUE);
			string tmpname, displayname;
			globsize = search_getsize(hsglob);
			
			seed = floor(random() * globsize);
			for(i = 0; i < globsize; ++i)
			{
				tmpname = search_getfilename(hsglob, i);
				tmpname = substring(tmpname, strlen("gfx/hud/skins/"), strlen(tmpname));
				tmpname = substring(tmpname, 0, strlen(tmpname) - strlen("/skininfo"));
				
				if(i == seed)
					displayname = tmpname;
					
				print("^5    ", tmpname);
				
				if(tmpname == hudskin_name)
					print(" ^8(current)\n");
				else print("\n");
			}
			search_end(hsglob);
			
			print("\nTo change the HUD skin, type: ^2hudskin SKINNAME\nFor example, ^2hudskin ", displayname, "\n");
			print("\nYou can also use ^2althud 0^7 to disable the alternative HUD layout (will use a layout similar to Nexuiz default instead), or use ^2oldhud 1^7 to disable RocketMinsta HUD entriely\n");
			
			return true;
		}
		
		if(!hudlocked)
		{
			HUDSkin_Load(argv(1));
			cvar_set("rm_hudskin", hudskin_name);
			localcmd("menu_cmd update_rmvars\n");
            ReportHUDInfo(hudskin_name);
		}
		else
		{
			print("^1Can't change the HUD skin while spectating a player, please join the game or become an observer and try again\n");
			return true;
		}
		
		return true;
	}
	else if(strCmd == "hidecountry")
	{
		VALUEREQUIRED
		cvar_set("rm_hidecountry", argv(1));
		rm_hidecountry = CVAR(rm_hidecountry);
		localcmd("cmd hidecountry ", ftos(CVAR(rm_hidecountry)), "\n");
		RMSETTINGREPORT
		return true;
	}
    else if(strCmd == "radio") {
        VALUEREQUIRED
        
        if(!stof(argv(1)))
        if(find(world, classname, "radio"))
            localcmd("cd reset\n");

        cvar_set("rm_radio", argv(1));
        localcmd("cmd radio ", ftos(CVAR(rm_radio)), "\n");
        RMSETTINGREPORT
        return true;
    } 

	if(camera_active)
	if(strCmd == "+forward" || strCmd == "-back") {
		++camera_direction_x;
		return true;
	} else if(strCmd == "-forward" || strCmd == "+back") {
		--camera_direction_x;
		return true;
	} else if(strCmd == "+moveright" || strCmd == "-moveleft") {
		--camera_direction_y;
		return true;
	} else if(strCmd == "-moveright" || strCmd == "+moveleft") {
		++camera_direction_y;
		return true;
	} else if(strCmd == "+moveup" || strCmd == "-movedown") {
		++camera_direction_z;
		return true;
	} else if(strCmd == "-moveup" || strCmd == "+movedown") {
		--camera_direction_z;
		return true;
	} else if(strCmd == "+roll_right" || strCmd == "-roll_left") {
		++camera_roll;
		return true;
	} else if(strCmd == "+roll_left" || strCmd == "-roll_right") {
		--camera_roll;
		return true;
	}

	return false;
}

.vector view_ofs;
entity debug_shotorg;
void ShotOrg_Draw()
{
	self.origin = view_origin + view_forward * self.view_ofs_x + view_right * self.view_ofs_y + view_up * self.view_ofs_z;
	self.angles = view_angles;
	self.angles_x = -self.angles_x;
	if not(self.cnt)
		R_AddEntity(self);
}
void ShotOrg_Draw2D()
{
	vector coord2d_topleft, coord2d_topright, coord2d;
	string s;
	vector fs;

	s = vtos(self.view_ofs);
	s = substring(s, 1, strlen(s) - 2);
	if(tokenize_console(s) == 3)
		s = strcat(argv(0), " ", argv(1), " ", argv(2));

	coord2d_topleft = project_3d_to_2d(self.origin + view_up * 4 - view_right * 4);
	coord2d_topright = project_3d_to_2d(self.origin + view_up * 4 + view_right * 4);

	fs = '1 1 0' * ((coord2d_topright_x - coord2d_topleft_x) / stringwidth(s, FALSE, '1 1'));

	coord2d = coord2d_topleft;
	if(fs_x < 8)
	{
		coord2d_x += (coord2d_topright_x - coord2d_topleft_x) * (1 - 8 / fs_x) * 0.5;
		fs = '8 8 0';
	}
	coord2d_y -= fs_y;
	coord2d_z = 0;
	drawstring(coord2d, s, fs, '1 1 1', 1, 0);
}

void ShotOrg_Spawn()
{
	debug_shotorg = spawn();
	debug_shotorg.draw = ShotOrg_Draw;
	debug_shotorg.draw2d = ShotOrg_Draw2D;
	debug_shotorg.renderflags = RF_VIEWMODEL;
	debug_shotorg.effects = EF_FULLBRIGHT;
	precache_model("models/shotorg_adjuster.md3");
	setmodel(debug_shotorg, "models/shotorg_adjuster.md3");
	debug_shotorg.scale = 2;
	debug_shotorg.view_ofs = '25 8 -8';
}

.float oldspecmadoka;
void TmpMadoka_Think()
{
	cvar_set("rm_specmadoka", ftos(self.oldspecmadoka));
	is_tmpmadoka = 0;
	SetMadokaFont(MDKF_AUTO);
}

void madokaprint(string m, string c, float t)
{
	if(is_tmpmadoka) return;
	
	is_tmpmadoka = 1;
	
	tmpmadoka_fadetime = time + t + 1;
	tmpmadoka.think = TmpMadoka_Think;
	tmpmadoka.nextthink = tmpmadoka_fadetime;
	tmpmadoka.oldspecmadoka = CVAR(rm_specmadoka);
	cvar_set("rm_specmadoka", "0");
	SetMadokaFont(MDKF_SET);
	localcmd("play2 misc/powerup\n");
	
	if(!CVAR(rm_dontmesswithfonts))
	if(!rm_nobigtext)
	//We will either print runic text here, or won't print anything at all.
		bigprint(m, c, t);
}

void GameCommand(string msg)
{
	float argc;
	argc = tokenize_console(msg);

	if(argv(0) == "help" || argc == 0)
	{
		print("Usage: cl_cmd COMMAND..., where possible commands are:\n");
		print("  settemp cvar value\n");
		print("  radar\n");
		print("  sbar_columns_set ...\n");
		print("  sbar_columns_help\n");
		print("  bigprint text command staytime\n");
		print("  madokaprint text command staytime\n");
		GameCommand_Generic("help");
		return;
	}

	if(GameCommand_Generic(msg))
		return;

	string cmd;
	cmd = argv(0);
	if(cmd == "mv_download") {
		Cmd_MapVote_MapDownload(argc);
	}
	else if(cmd == "settemp") {
		cvar_clientsettemp(argv(1), argv(2));
	}
	else if(cmd == "radar") {
		ons_showmap = !ons_showmap;
	}
	else if(cmd == "sbar_columns_set") {
		Cmd_Sbar_SetFields(argc);
	}
	else if(cmd == "sbar_columns_help") {
		Cmd_Sbar_Help(argc);
	}
#ifdef BLURTEST
	else if(cmd == "blurtest") {
		blurtest_time0 = time;
		blurtest_time1 = time + stof(argv(1));
		blurtest_radius = stof(argv(2));
		blurtest_power = stof(argv(3));
	}
#endif
	else if(cmd == "shotorg_move") {
		if(!debug_shotorg)
			ShotOrg_Spawn();
		else
			debug_shotorg.view_ofs = debug_shotorg.view_ofs + stov(argv(1));
		localcmd("sv_cmd debug_shotorg \"", vtos(debug_shotorg.view_ofs), "\"\n");
	}
	else if(cmd == "shotorg_movez") {
		if(!debug_shotorg)
			ShotOrg_Spawn();
		else
			debug_shotorg.view_ofs = debug_shotorg.view_ofs + stof(argv(1)) * (debug_shotorg.view_ofs * (1 / debug_shotorg.view_ofs_x)); // closer/farther, same xy pos
		localcmd("sv_cmd debug_shotorg \"", vtos(debug_shotorg.view_ofs), "\"\n");
	}
	else if(cmd == "shotorg_set") {
		if(!debug_shotorg)
			ShotOrg_Spawn();
		else
			debug_shotorg.view_ofs = stov(argv(1));
		localcmd("sv_cmd debug_shotorg \"", vtos(debug_shotorg.view_ofs), "\"\n");
	}
	else if(cmd == "shotorg_setz") {
		if(!debug_shotorg)
			ShotOrg_Spawn();
		else
			debug_shotorg.view_ofs = debug_shotorg.view_ofs * (stof(argv(1)) / debug_shotorg.view_ofs_x); // closer/farther, same xy pos
		localcmd("sv_cmd debug_shotorg \"", vtos(debug_shotorg.view_ofs), "\"\n");
	}
	else if(cmd == "shotorg_toggle_hide") {
		if(debug_shotorg)
		{
			debug_shotorg.cnt = !debug_shotorg.cnt;
		}
	}
	else if(cmd == "shotorg_end") {
		if(debug_shotorg)
		{
			print(vtos(debug_shotorg.view_ofs), "\n");
			remove(debug_shotorg);
			debug_shotorg = world;
		}
		localcmd("sv_cmd debug_shotorg\n");
	}
	else if(cmd == "madokaprint")
	{
		if(argc < 3)
		{
			print("Usage: madokaprint text comment staytime\n");
			return;
		}
		
		madokaprint(argv(1), argv(2), stof(argv(3)));
	}
	else if(cmd == "bigprint")
	{
		if(argc < 3)
		{
			print("Usage: bigprint text comment staytime\n");
			return;
		}
		
		bigprint(argv(1), argv(2), stof(argv(3)));
	}
	else if(cmd == "hudflash")
	{
		if(argc < 4)
		{
			print("Usage: hudflash color time intensivity alpha\n");
			return;
		}
		
		hudflash(stov(argv(1)), stof(argv(2)), stof(argv(3)), stof(argv(4)));
	}
	else if(cmd == "hudskin")
	{
		HUDSkin_Load(argv(1));
	}
	else if(cmd == "hudskin_unload")
	{
		HUDSkin_Unload();
	}
	else if(cmd == "hudskin_eval")
	{
		HUDSkin_Eval(substring(msg, strlen(cmd) + 1, strlen(msg)));
	}
	else if(cmd == "crc16")
	{
		if(argc < 3)
			print("Usage: crc16 bool:caseinsensitive string\n");
		else
			print(ftos(crc16(stof(argv(1)), argv(2))), "\n");
	}
	else if(cmd == "danger") {
		if not(CVAR(rm_freezetag_danger))
			return;
		
		if(CVAR(rm_freezetag_danger_silent)) {
			localcmd("g_waypointsprite_team_danger_p\n");
			return;
		}
		
		// dirty dirty hacks
		// I love them
		
		string userbind = CVAR_STR(userbind7_press);
		if(strstrofs(userbind, "g_waypointsprite_team_danger_p", 0) >= 0 && strstrofs(userbind, "%p", 0) >= 0)
			localcmd("_userbind_call userbind7_press\n");
		else
			localcmd("say_team enemy seen (^4%p^7 at ^2%y^7); g_waypointsprite_team_danger_p\n");
    }
    else if(cmd == "vatest") {
        va_test("sfv", "lel derp", 42, '3 2 1');
        va_test("fvss", 44, '5 2 6', "lalala", "omgomg");
    }
	else
	{
		print("Invalid command. For a list of supported commands, try cl_cmd help.\n");
	}

	return;
}

// CSQC_InputEvent : Used to perform actions based on any key pressed, key released and mouse on the client.
// Return value should be 1 if CSQC handled the input, otherwise return 0 to have the input passed to the engine.
// All keys are in ascii.
// bInputType = 0 is key pressed, 1 is key released, 2 is mouse input.
// In the case of keyboard input, nPrimary is the ascii code, and nSecondary is 0.
// In the case of mouse input, nPrimary is xdelta, nSecondary is ydelta.
float CSQC_InputEvent(float bInputType, float nPrimary, float nSecondary)
{
	if(MapVote_InputEvent(bInputType, nPrimary, nSecondary))
		return TRUE;

    if(NS_InputEvent(bInputType, nPrimary, nSecondary))
        return TRUE;

    if(WS_InputEvent(bInputType, nPrimary, nSecondary))
        return TRUE;

	return FALSE;
}

// END REQUIRED CSQC FUNCTIONS
// --------------------------------------------------------------------------

// --------------------------------------------------------------------------
// BEGIN OPTIONAL CSQC FUNCTIONS
void Ent_ReadEntCS()
{

	self.classname = "entcs_receiver";

    float sf = ReadByte();
    
    if(sf & 1) {
        self.sv_entnum = ReadByte() - 1;
        self.sn_forcefrozen = ReadByte();
        Shownames_Init(self);
    }

    entity plr = playerslots[self.sv_entnum];

    if(sf & 2) {
        InterpolateOrigin_Undo();
        self.origin_x = ReadShort();
        self.origin_y = ReadShort();
        self.origin_z = ReadShort();
        InterpolateOrigin_Note();
    }

    // sf & 4 unused

    if(sf & 8) {
        self.angles_y = ReadByte() * 360.0 / 256;
    }

    if(sf & 16) {
        self.healthvalue = ReadShort();
        plr.healthvalue = self.healthvalue;
    }

    if(sf & 32) {
        self.armorvalue = ReadShort();
        plr.armorvalue = self.armorvalue;
    }

    self.sameteam = (sf & 64);

}

void Ent_Remove();

void Ent_RemovePlayerScore()
{
	float i;

	if(self.owner)
	{
		SetTeam(self.owner, -1);
		self.owner.gotscores = 0;
		for(i = 0; i < MAX_SCORE; ++i)
			self.owner.(scores[i]) = 0; // clear all scores
	}
}

.entity bestscore_next;
void UpdateBestScore(float teem, float sfield) {
    float best, scr, better, sflag;
    entity bestscore_head, bestscore_tail, c;

    if(sfield < 0 || sfield >= MAX_SCORE)
        return;

    sflag = pow(2, sfield);

    for(c = players.sort_next; c; c = c.sort_next) {
        if(GetPlayerColor(c.sv_entnum) != teem)
            continue;
        
        c.hasbestscore &~= sflag;
        scr = c.(scores[sfield]);

        if(!bestscore_head)
            better = TRUE;

        if(scores_flags[sfield] & SFL_LOWER_IS_BETTER)
            better = scr < best;
        else
            better = scr > best;

        if(better) {
            c.bestscore_next = world;
            best = scr;
            bestscore_head = bestscore_tail = c;
        } else if(scr == best) {
            c.bestscore_next = world;
            if(bestscore_tail)
                bestscore_tail.bestscore_next = c;
            else
                bestscore_head = c;
            bestscore_tail = c;
        }
    }

    for(c = bestscore_head; c; c = c.bestscore_next)
        c.hasbestscore |= sflag;
}

void Ent_ReadPlayerScore()
{
	float i, n;
	float isNew;
	entity o;

	// damnit -.- don't want to go change every single .sv_entnum in sbar.qc AGAIN
	// (no I've never heard of M-x replace-string, sed, or anything like that)
	isNew = !self.owner; // workaround for DP bug
	n = ReadByte()-1;

#ifdef DP_CSQC_ENTITY_REMOVE_IS_B0RKED
	if(!isNew && n != self.sv_entnum)
	{
		print("A CSQC entity changed its owner!\n");
		isNew = true;
		Ent_Remove();
		self.enttype = ENT_CLIENT_SCORES;
	}
#endif

	self.sv_entnum = n;

	if not(playerslots[self.sv_entnum])
		playerslots[self.sv_entnum] = spawn();
	o = self.owner = playerslots[self.sv_entnum];
	o.sv_entnum = self.sv_entnum;
	o.gotscores = 1;

	//if not(o.sort_prev)
	//	RegisterPlayer(o);
	//playerchecker will do this for us later, if it has not already done so

	float sf, lf;
#if MAX_SCORE <= 8
	sf = ReadByte();
	lf = ReadByte();
#elif MAX_SCORE <= 16
	sf = ReadShort();
	lf = ReadShort();
#else
	sf = ReadInt24_t();
	lf = ReadInt24_t();
#endif
	float p;

	float oldscore = o.(scores[SP_SCORE]);
	
	for(i = 0, p = 1; i < MAX_SCORE; ++i, p *= 2)
	{
		if(sf & p)
		{
            if(i == SP_STATUSICONS) {
                o.(scores[i]) = ReadShort();
            } else {
                if(lf & p)
                    o.(scores[i]) = ReadInt24_t();
                else
                    o.(scores[i]) = ReadChar();

                if(i != SP_PLAYTIME && i != SP_ACCURACY && i != SP_NOOB && i != SP_ALIVE)
                    UpdateBestScore(GetPlayerColor(o.sv_entnum), i);
            }
		}
	}

	float newscore = o.(scores[SP_SCORE]);
	
	if(self.sv_entnum == player_localentnum - 1 || self.sv_entnum == spectatee_status - 1)
	{
		if(oldscore != newscore)
		{
			score_visual(newscore - oldscore);
		}
	}

	if(o.sort_prev)
		Sbar_UpdatePlayerPos(o); // if not registered, we cannot do this yet!

	self.entremove = Ent_RemovePlayerScore;
}

void Ent_ReadTeamScore()
{
	float i;
	entity o;

	self.team = ReadByte();
	o = self.owner = GetTeam(self.team, true); // these team numbers can always be trusted

	float sf, lf;
#if MAX_TEAMSCORE <= 8
	sf = ReadByte();
	lf = ReadByte();
#else
	sf = ReadShort();
	lf = ReadShort();
#endif
	float p;
	for(i = 0, p = 1; i < MAX_TEAMSCORE; ++i, p *= 2)
		if(sf & p)
		{
			if(lf & p)
				o.(teamscores[i]) = ReadInt24_t();
			else
				o.(teamscores[i]) = ReadChar();
		}

	Sbar_UpdateTeamPos(o);
}

void Net_Reset()
{
}

void Ent_ClientData()
{
	float f;
	float newspectatee_status;

	f = ReadByte();

	sb_showscores_force = (f & 1);

	if(f & 2)
	{
		newspectatee_status = ReadByte();
		if(newspectatee_status == player_localentnum)
			newspectatee_status = -1; // observing
	}
	else
		newspectatee_status = 0;

	spectatorbutton_zoom = (f & 4);

	if(f & 8)
	{
		angles_held_status = 1;
		angles_held_x = ReadAngle();
		angles_held_y = ReadAngle();
		angles_held_z = 0;
	}
	else
		angles_held_status = 0;

	if(newspectatee_status != spectatee_status)
	{
		// clear race stuff
		race_laptime = 0;
		race_checkpointtime = 0;
	}
	spectatee_status = newspectatee_status;
}

void Ent_Nagger()
{
	float nags, i, j, b, f;

	nags = ReadByte();

	if(nags & 128)
	{
		if(vote_called_vote)
			strunzone(vote_called_vote);
		vote_called_vote = strzone(ColorTranslateRGB(ReadString()));
        if(vote_called_vote == "")
            vote_active = 0;
	}

	if(nags & 1)
	{
		for(j = 0; j < maxclients; ++j)
			if(playerslots[j])
				playerslots[j].ready = 1;
		for(i = 1; i <= maxclients; i += 8)
		{
			f = ReadByte();
			for(j = i-1, b = 1; b < 256; b *= 2, ++j)
				if not(f & b)
					if(playerslots[j])
						playerslots[j].ready = 0;
		}
	}

	ready_waiting = (nags & 1);
	ready_waiting_for_me = (nags & 2);
	vote_waiting = (nags & 4);
	vote_waiting_for_me = ((nags & 8) && !isdemo());
	warmup_stage = (nags & 16);
}

void Ent_RandomSeed()
{
	float s;
	prandom_debug();
	s = ReadShort();
	psrandom(s);
}

void Ent_SpecInfo(void) {
    var sf = ReadByte();

    if(sf & SPECINFO_LIST) {
        num_spectators = ReadByte();
        for(var i = 0; i < num_spectators; ++i) {
            var slot = ReadByte();
            if(i < MAX_SPECTATORS)
                spectatorlist[i] = slot - 1;
        }
    }

    if(sf & SPECINFO_HUD) {
        var md = ReadByte();

        if(CVAR(rm_specmadoka)) {
            madoka_locked = TRUE;
            madokalockstate = md;
            SetMadokaFont(madokalockstate);
        }

        hudlocked = TRUE;
        rm_oldhud = hudlocked_old = ReadByte();
        rm_althud = hudlocked_alt = ReadByte();

        var skn = ReadString();
        if(skn != hudskin_name)
            HUDSkin_Load(skn);

        fovlock = ReadByte();
        speczoom_speed  = ReadByte() * 0.1;
        speczoom_factor = ReadByte() * 0.1;
    }
}

void Ent_AccStats(void) {
    var hits, fired, wflags = ReadInt24_t();

    for(var w = WEP_FIRST; w <= WEP_LAST; ++w) {
        var i = get_weaponinfo(w);
        if(i.weapons & wflags) {
            switch(i.weapon_type) {
                case WEP_TYPE_SPLASH:
                    fired = ReadInt24_t();
                    hits = ReadInt24_t();
                    break;

                case WEP_TYPE_HITSCAN:
                    fired = ReadShort();
                    hits = ReadShort();
                    break;

                default:
                    error("Weapon " + w + " has invalid weapon_type = " + i.weapon_type);
                    break;
            }

            weapon_hits[w] = hits;
            weapon_fired[w] = fired;
        }
    }
}

// CSQC_Ent_Update : Called every frame that the server has indicated an update to the SSQC / CSQC entity has occured.
// The only parameter reflects if the entity is "new" to the client, meaning it just came into the client's PVS.
void Ent_RadarLink();
void Ent_Init();
void Ent_ScoresInfo();
void CSQC_Ent_Update(float bIsNewEntity)
{
	float t;
	float savetime;
	t = ReadByte();

	// set up the "time" global for received entities to be correct for interpolation purposes
	savetime = time;
	if(servertime)
	{
		time = servertime;
	}
	else
	{
		serverprevtime = time;
		serverdeltatime = getstatf(STAT_MOVEVARS_TICRATE) * getstatf(STAT_MOVEVARS_TIMESCALE);
		time = serverprevtime + serverdeltatime;
	}

#ifdef DP_CSQC_ENTITY_REMOVE_IS_B0RKED
	if(self.enttype)
		if(t != self.enttype)
		{
			print("A CSQC entity changed its type!\n");
			Ent_Remove();
			bIsNewEntity = 1;
		}
#endif

    if(cvar("_ent_debug")) {
        if(t >= _ENT_START && t <= _ENT_END)
            print("ent: ", ftos(t), " (", ftos(bIsNewEntity), ")\n");
    }

	self.enttype = t;
	switch(t)
	{
		case ENT_CLIENT: break;
		case ENT_CLIENT_ENTCS: Ent_ReadEntCS(); break;
		case ENT_CLIENT_SCORES: Ent_ReadPlayerScore(); break;
		case ENT_CLIENT_TEAMSCORES: Ent_ReadTeamScore(); break;
		case ENT_CLIENT_POINTPARTICLES: Ent_PointParticles(); break;
		case ENT_CLIENT_RAINSNOW: Ent_RainOrSnow(); break;
		case ENT_CLIENT_LASER: Ent_Laser(); break;
		case ENT_CLIENT_NAGGER: Ent_Nagger(); break;
		case ENT_CLIENT_WAYPOINT: Ent_WaypointSprite(); break;
		case ENT_CLIENT_RADARLINK: Ent_RadarLink(); break;
		case ENT_CLIENT_PROJECTILE: Ent_Projectile(); break;
		case ENT_CLIENT_GIBSPLASH: Ent_GibSplash(bIsNewEntity); break;
		case ENT_CLIENT_DAMAGEINFO: Ent_DamageInfo(bIsNewEntity); break;
		case ENT_CLIENT_CASING: Ent_Casing(bIsNewEntity); break;
		case ENT_CLIENT_INIT: Ent_Init(); break;
		case ENT_CLIENT_SCORES_INFO: Ent_ScoresInfo(); break;
		case ENT_CLIENT_MAPVOTE: Ent_MapVote(); break;
		case ENT_CLIENT_CLIENTDATA: Ent_ClientData(); break;
		case ENT_CLIENT_RANDOMSEED: Ent_RandomSeed(); break;
		case ENT_CLIENT_WALL: Ent_Wall(); break;
		case ENT_CLIENT_MODELEFFECT: Ent_ModelEffect(bIsNewEntity); break;
        case ENT_CLIENT_ZAPPER: case ENT_CLIENT_ZAPPER_SHIELD: Zapper_Read(t); break;
        case ENT_CLIENT_BUFFMODEL: Buffs_Model_Read(); break;
        case ENT_CLIENT_WARPZONE: WarpZone_Read(bIsNewEntity); break;
        case ENT_CLIENT_WARPZONE_CAMERA: WarpZone_Camera_Read(bIsNewEntity); break;
        case ENT_CLIENT_WARPZONE_TELEPORTED: WarpZone_Teleported_Read(bIsNewEntity); break;
        case ENT_CLIENT_SPECINFO: Ent_SpecInfo(); break;
        case ENT_CLIENT_ACCSTATS: Ent_AccStats(); break;
        case ENT_CLIENT_HGTWARP_INDICATOR: Ent_TimeWarperIndicator(); break;
		default:
			error(strcat("unknown entity type in CSQC_Ent_Update: ", ftos(self.enttype), "\n"));
			break;
	}

	time = savetime;
}
// Destructor, but does NOT deallocate the entity by calling remove(). Also
// used when an entity changes its type. For an entity that someone interacts
// with others, make sure it can no longer do so.
void Ent_Remove()
{
	if(self.entremove)
		self.entremove();

	self.enttype = 0;
	self.classname = "";
	self.draw = NULL;
	self.entremove = NULL;
	// TODO possibly set more stuff to defaults
}
// CSQC_Ent_Remove : Called when the server requests a SSQC / CSQC entity to be removed.  Essentially call remove(self) as well.
void CSQC_Ent_Remove()
{
	if(self.enttype)
		Ent_Remove();
	remove(self);
}

void Gamemode_Init()
{
	if(gametype == GAME_ONSLAUGHT) {
		print(strcat("Using ", minimapname, " as minimap.\n"));
		precache_pic("gfx/ons-cp-neutral.tga");
		precache_pic("gfx/ons-cp-red.tga");
		precache_pic("gfx/ons-cp-blue.tga");
		precache_pic("gfx/ons-frame.tga");
		precache_pic("gfx/ons-frame-team.tga");
	} else if(gametype == GAME_KEYHUNT) {
		precache_pic("gfx/sb_key_carrying");
		precache_pic("gfx/sb_key_carrying_outline");
	}

	if not(isdemo())
	{
		localcmd("\n_cl_hook_gamestart ", gametype_ID_to_Name(gametype), ";");
		calledhooks |= HOOK_START;
	}
}
// CSQC_Parse_StuffCmd : Provides the stuffcmd string in the first parameter that the server provided.  To execute standard behavior, simply execute localcmd with the string.
void CSQC_Parse_StuffCmd(string strMessage)
{
    dprint("stuffcmd from server: " + strMessage + "\n");
	localcmd(strMessage);
}
// CSQC_Parse_Print : Provides the print string in the first parameter that the server provided.  To execute standard behavior, simply execute print with the string.
void CSQC_Parse_Print(string strMessage)
{
	print(ColorTranslateRGB(strMessage));
}

// CSQC_Parse_CenterPrint : Provides the centerprint string in the first parameter that the server provided.
void CSQC_Parse_CenterPrint(string strMessage)
{
	centerprint(strMessage);
}

string MakeFog(vector rgb, float a) {
	return strcat(ftos(a), " ", ftos(rgb_x), " ", ftos(rgb_y), " ", ftos(rgb_z));
}

void ForceFogString(string fog) {
	localcmd(strcat("\nfog ", fog, "\nr_fog_exp2 0\nr_drawfog 1\n"));
}

void ForceFog(vector rgb, float a) {
	ForceFogString(MakeFog(rgb, a));
}

void Fog_Force()
{
	// TODO somehow thwart prvm_globalset client ...

	if(forcefog != "" || whatsgoingon) {
		
		if(forcefog == "nyan" || whatsgoingon) {
			float a = 0.5 + 0.5 * sin(0.5 * time);
			vector hsl;
			hsl_x = a * 2 * PI;
			hsl_y = 1;
			hsl_z = 0.8 - 0.2 * sin(1.11 * time) * cos(2.22 * time);
			ForceFog(hsl_to_rgb(hsl), 0.02 * (1 - 0.5 * cos(1.13 * time)));
			
			if(CVAR(r_glsl)) {
				cvar_clientsettemp("r_glsl_saturation", ftos(3 * cos(time * 0.25)));
			}
            
            cvar_clientsettemp("volume", ftos(max(0.1, CVAR(volume))));
            cvar_clientsettemp("bgmvolume", ftos(max(0.5, CVAR(bgmvolume))));
		}
		
		else ForceFogString(forcefog);
	}
}

void Gamemode_Init();
void Ent_ScoresInfo()
{
	float i;
	self.classname = "ent_client_scores_info";
	gametype = ReadByte();
	for(i = 0; i < MAX_SCORE; ++i)
	{
		scores_label[i] = strzone(ReadString());
		scores_flags[i] = ReadByte();
	}
	for(i = 0; i < MAX_TEAMSCORE; ++i)
	{
		teamscores_label[i] = strzone(ReadString());
		teamscores_flags[i] = ReadByte();
	}
	Sbar_InitScores();
	Gamemode_Init();
}

void Ent_Init()
{
	float i;
	self.classname = "ent_client_init";

	nb_pb_period = ReadByte() / 32; //Accuracy of 1/32th

	for(i = 0; i < 24; ++i)
		weaponimpulse[i] = ReadByte() - 1;
	hook_shotorigin_x = ReadCoord();
	hook_shotorigin_y = ReadCoord();
	hook_shotorigin_z = ReadCoord();

	if(forcefog)
		strunzone(forcefog);
	forcefog = strzone(ReadString());

	armorblockpercent = ReadByte() / 255.0;
	sv_showspecs_extra = ReadByte();
	sv_scoreboard_fps_column = ReadByte();
	g_nadgets = ReadByte();
    cvar_set("_g_nadgets_select_available", ftos(if(g_nadgets) ReadByte() else 0));
    cvar_set("_g_nadgets_select_double", ftos(g_nadgets_double = if(g_nadgets) ReadByte() else 0));
    g_weaponarena = ReadInt24_t();
    g_weaponarena_secondary = ReadInt24_t();
    cvar_set("_secondary_select_available", ftos(!!(g_weaponarena_secondary & (g_weaponarena_secondary - 1))));
    g_freeze = ReadByte();
    sv_scoreboard_heal_column = ReadByte();
    sv_damagestats = ReadByte();
    sv_nicehealth = ReadShort();
    sv_scoreboard_acc_column = ReadByte();
    g_buffs_enabled = ReadShort();
    g_balance_nex_secondary = ReadByte();
    sv_scoreboard_noob_column = ReadByte();
    sv_scoreboard_alive_column = ReadByte();

    Buffs_LoadModels();

	if(!postinit)
		PostInit();
}

void Net_ReadRace()
{
	float b;

	b = ReadByte();

	switch(b)
	{
		case RACE_NET_CHECKPOINT_HIT_QUALIFYING:
			race_checkpoint = ReadByte();
			race_time = ReadInt24_t();
			race_previousbesttime = ReadInt24_t();
			if(race_previousbestname)
				strunzone(race_previousbestname);
			race_previousbestname = strzone(ColorTranslateRGB(ReadString()));

			race_checkpointtime = time;

			if(race_checkpoint == 0 || race_checkpoint == 254)
			{
				race_penaltyaccumulator = 0;
				race_laptime = time; // valid
			}

			break;

		case RACE_NET_CHECKPOINT_CLEAR:
			race_laptime = 0;
			race_checkpointtime = 0;
			break;

		case RACE_NET_CHECKPOINT_NEXT_SPEC_QUALIFYING:
			race_laptime = ReadCoord();
			race_checkpointtime = -99999;
			// fall through
		case RACE_NET_CHECKPOINT_NEXT_QUALIFYING:
			race_nextcheckpoint = ReadByte();

			race_nextbesttime = ReadInt24_t();
			if(race_nextbestname)
				strunzone(race_nextbestname);
			race_nextbestname = strzone(ColorTranslateRGB(ReadString()));
			break;

		case RACE_NET_CHECKPOINT_HIT_RACE:
			race_mycheckpoint = ReadByte();
			race_mycheckpointtime = time;
			race_mycheckpointdelta = ReadInt24_t();
			race_mycheckpointlapsdelta = ReadByte();
			if(race_mycheckpointlapsdelta >= 128)
				race_mycheckpointlapsdelta -= 256;
			if(race_mycheckpointenemy)
				strunzone(race_mycheckpointenemy);
			race_mycheckpointenemy = strzone(ColorTranslateRGB(ReadString()));
			break;

		case RACE_NET_CHECKPOINT_HIT_RACE_BY_OPPONENT:
			race_othercheckpoint = ReadByte();
			race_othercheckpointtime = time;
			race_othercheckpointdelta = ReadInt24_t();
			race_othercheckpointlapsdelta = ReadByte();
			if(race_othercheckpointlapsdelta >= 128)
				race_othercheckpointlapsdelta -= 256;
			if(race_othercheckpointenemy)
				strunzone(race_othercheckpointenemy);
			race_othercheckpointenemy = strzone(ColorTranslateRGB(ReadString()));
			break;

		case RACE_NET_PENALTY_RACE:
			race_penaltyeventtime = time;
			race_penaltytime = ReadShort();
			if(race_penaltyreason)
				strunzone(race_penaltyreason);
			race_penaltyreason = strzone(ReadString());
			break;

		case RACE_NET_PENALTY_QUALIFYING:
			race_penaltyeventtime = time;
			race_penaltytime = ReadShort();
			race_penaltyaccumulator += race_penaltytime;
			if(race_penaltyreason)
				strunzone(race_penaltyreason);
			race_penaltyreason = strzone(ReadString());
			break;
	}
}

void Net_ReadSpawn()
{
	zoomin_effect = 1;
	current_viewzoom = 0.6;
}

void Net_ReadBigPrint()
{
	bigprint(ReadString(), ReadString(), ReadShort());
}

void Net_ReadMadokaPrint()
{
	madokaprint(ReadString(), ReadString(), ReadShort());
}

void Net_VoteDialog(float highlight) {
	if(highlight) {
		vote_highlighted = ReadShort();
		return;
	}

    vote_invite = 0;
	vote_yescount = ReadShort();
	vote_nocount = ReadShort();
	vote_needed = ReadShort();
	vote_active = 1;

    if(vote_statstring) {
        strunzone(vote_statstring);
        vote_statstring = NULL;
    }

    if(vote_active)
        vote_statstring = strzone(strcat("^2Yes^7: ", ftos(vote_yescount), " ^1No^7: ", ftos(vote_nocount), " (", ftos(vote_needed), " needed)"));
}

void Net_VoteDialogReset() {
	vote_active = 0;
    // vote_invite = 0;
}

void Net_ReadVoteInvite(void) {
    vote_invite = 1;
    vote_active = 1;
}

void Net_ReadMorningRescue()
{
	if(morningrescue)
		return;
	
	localcmd("play2 sound/misc/morningrescue\n");
	morningrescue = 1;
	mr_appeartime = time;
	mr_fadetime   = time + 9;
}

void Net_ReadClearBigPrint()
{
    bigprint(" ", "", 0);
}

void Net_ReadHudFlash(float teamcolor)
{
	float a, i, t;
	vector c;
	
	if(teamcolor)
		c = GetTeamRGB(myteam);
	else
	{
		c_x = ReadCoord();
		c_y = ReadCoord();
		c_z = ReadCoord();
	}
	
	t = ReadCoord();
	i = ReadCoord();
	a = ReadCoord();
	
	hudflash(c, t, i, a);
}

void Net_Camera() {
	if(!ReadByte()) {
		camera_expiretime = -1;
		return;
	}
	
	camera_origin_x = ReadShort();
	camera_origin_y = ReadShort();
	camera_origin_z = ReadShort();
	
	if(time <= camera_expiretime || camera_drawviewmodel_locked)
		dprint("Warning: Net_Camera while a camera is still active\n");
	else {
		camera_drawviewmodel_backup = CVAR(r_drawviewmodel);
		camera_drawviewmodel_locked = TRUE;
	}
	
	camera_expiretime = time + ReadShort();
    
    if(camera_expiretime < time)
        camera_expiretime = -2;
}

void Net_ServerInfo() {
    sv_hostname = strzone(ReadString());
    sv_hostname_colored = ReadByte();
    var build_name = ReadString();
    var build_version = ReadString();
    sv_rm_build_info = strzone(build_name + " " + build_version);
    sv_rm_build_date = strzone(ReadString());
    sv_motd = strzone(ReadString());
}

void Net_Heal() {
    vector o;
    o_x = ReadCoord();
    o_y = ReadCoord();
    o_z = ReadCoord();
    pointparticles(rm_particleeffectnum("RM_HEAL"), o, '0 0 0', 1);
}

entity Net_DamageTracker_KeeperFromFlags(float dtflags) {
    if(dtflags & DTFLAG_GLOBAL)
        return dtrack_global;
    else if(dtflags & DTFLAG_DONE) {
        if(dtflags & DTFLAG_SPEC)
            return dtrack_total_spec;
        else
            return dtrack_total;
    } else if(dtflags & DTFLAG_TAKEN) {
        if(dtflags & DTFLAG_SPEC)
            return dtrack_taken_spec;
        else
            return dtrack_taken;
    }
    
    return world;
}

void Net_DamageTracker() {
    float dtype, damage, dtflags, i, ecnt;
    entity k;
    
    dtflags = ReadByte();
    k = Net_DamageTracker_KeeperFromFlags(dtflags);
    
    if(!k)
        error(strcat("Got invalid damage tracker flags from server: ", ftos(dtflags)));
    
    if(dtflags & DTFLAG_OVERWRITE) {
        ecnt = ReadByte();
        
        DamageTracker_Wipe(k);
        for(i = 0; i < ecnt; ++i) {
            dtype = ReadShort();
            damage = ReadShort();
            DamageTracker_Record(k, dtype, damage);
            // assume it's sorted by the server already
        }
    } else {        
        dtype = ReadShort();
        damage = ReadShort() / 10;
        DamageTracker_Record(k, dtype, damage);
        DamageTracker_Sort(k);
    }
}

void Net_ReadUpdateSelectedPlayer() {
    sbar_selectedplayer = ReadByte();
    sbar_selectedplayer_fadetime = time + 2;
    
    if(sbar_selectedplayer_name)
        strunzone(sbar_selectedplayer_name);
    sbar_selectedplayer_name = strzone(GetPlayerName(sbar_selectedplayer - 1));
}

// CSQC_Parse_TempEntity : Handles all temporary entity network data in the CSQC layer.
// You must ALWAYS first acquire the temporary ID, which is sent as a byte.
// Return value should be 1 if CSQC handled the temporary entity, otherwise return 0 to have the engine process the event.
float CSQC_Parse_TempEntity()
{
	// Acquire TE ID
	float nTEID;
	nTEID = ReadByte();

    if(cvar("_ent_debug")) {
        if(nTEID >= _TE_CSQC_START && nTEID <= _TE_CSQC_END)
            print("temp ent: ", ftos(nTEID), "\n");
    }

	switch(nTEID)
	{
		case TE_CSQC_PICTURE:
			Net_MapVote_Picture();
			return TRUE;
		case TE_CSQC_RACE:
			Net_ReadRace();
			return TRUE;
		case 13: // TE_BEAM
			Net_GrapplingHook();
			return TRUE;
		case TE_CSQC_SPAWN:
			Net_ReadSpawn();
			return TRUE;
		case TE_CSQC_ZCURVEPARTICLES:
			Net_ReadZCurveParticles();
			return TRUE;
		case TE_CSQC_NEXGUNBEAMPARTICLE:
			Net_ReadNexgunBeamParticle();
			return TRUE;
        case TE_CSQC_LIGHTNINGARC:
            Net_ReadLightningarc();
			return TRUE;
        case TE_CSQC_BIGPRINT:
			Net_ReadBigPrint();
			return TRUE;
		case TE_CSQC_VOTE:
			Net_VoteDialog(ReadByte());
			return TRUE;
		case TE_CSQC_VOTERESET:
			Net_VoteDialogReset();
			return TRUE;
		case TE_CSQC_MADOKAPRINT:
			Net_ReadMadokaPrint();
			return TRUE;
		case TE_CSQC_MORNINGRESCUE:
			Net_ReadMorningRescue();
			return TRUE;
        case TE_CSQC_CLEARBIGPRINT:
            Net_ReadClearBigPrint();
			return TRUE;
		case TE_CSQC_HUDFLASH:
			Net_ReadHudFlash(FALSE);
			return TRUE;
		case TE_CSQC_HUDFLASH_TEAMCOLOR:
			Net_ReadHudFlash(TRUE);
			return TRUE;
		case TE_CSQC_CAMERA:
			Net_Camera();
			return TRUE;
		case TE_CSQC_SERVERINFO:
			Net_ServerInfo();
			return TRUE;
        case TE_CSQC_VISUALDAMAGE:
            Net_VisualDamage();
            return TRUE;
        case TE_CSQC_HEAL:
            Net_Heal();
            return TRUE;
        case TE_CSQC_BLAST:
            Net_ReadBlast();
            return TRUE;
        case TE_CSQC_DTRACK:
            Net_DamageTracker();
            return TRUE;
        case TE_CSQC_MEODP:
            Net_ReadMEODP();
            return TRUE;
       	case TE_CSQC_RADIO:
       		Net_ReadRadio();
       		return TRUE;
        case TE_CSQC_ZAPPERLIGHTNING:
            Zapper_ReadLightning();
            return TRUE;
        case TE_CSQC_UPDATESELECTEDPLAYER:
            Net_ReadUpdateSelectedPlayer();
            return TRUE;
        case TE_CSQC_MESSAGE:
            Message_Read();
            return TRUE;
        case TE_CSQC_VOTEINVITE:
            Net_ReadVoteInvite();
            return TRUE;
        case TE_CSQC_ELEBLAST:
            Net_ReadEleBlast();
            return TRUE;
        case TE_CSQC_NADGETSELECT:
            Net_ReadNadgetSelect();
            return TRUE;
        case TE_CSQC_SECONDARYSELECT:
            Net_ReadWeaponSelect();
            return TRUE;
    }

	// pass to the engine
	return FALSE;
}

string getcommandkey(string text, string command)
{
	string keys;
	float n, j, k, l;

	if (!sbar_showbinds)
		return text;

	keys = db_get(binddb, command);
	if (!keys)
	{
		n = tokenize(findkeysforcommand(command)); // uses '...' strings
		for(j = 0; j < n; ++j)
		{
			k = stof(argv(j));
			if(k != -1)
			{
				if ("" == keys)
					keys = keynumtostring(k);
				else
					keys = strcat(keys, ", ", keynumtostring(k));

				++l;
				if (sbar_showbinds_limit > 0 && sbar_showbinds_limit >= l) break;
			}

		}
		db_put(binddb, command, keys);
	}

	if ("" == keys) {
		if (sbar_showbinds > 1)
			return strcat(text, " (not bound)");
		else
			return text;
	}
	else if (sbar_showbinds > 1)
		return strcat(text, " (", keys, ")");
	else
		return keys;
}

//////////////////////////////

float bigprint_noold;

void bigprint_old(string bigstr, string comment, float fadeTime)
{
	if(is_tmpmadoka) return;
    
	obp_draw = 1;
	
	if(bigprint_oldstring)
		fstrunzone(bigprint_oldstring);
	
	bigprint_oldstring = strzone(bigstr);
	
	bigprint_oldfadetime = fadeTime - 0.1;
	bigprint_oldappeartime = time;
}

void bigprint(string bigstr, string comment, float staytime)
{
    float no = FALSE;
    if(staytime < 0) {
        staytime = -staytime;
        no = TRUE;
    }
    
	if(rm_nobigtext)
	{
		string s;
		s = bigstr;
		
		if(comment != "") {
			if(s == "")
				s = comment;
			else
				s = strcat(s, "\n", comment);
		}
		
		centerprint(s);
		return;
	}
	
	if(bigstr != "")
	{
		bp_draw = 1;
        
        if(!bigprint_noold)
            bigprint_old(bigprint_string, bigprint_comment, bigprint_fadetime);
		
		if(bigprint_string)
			fstrunzone(bigprint_string);
		
		bigprint_string = strzone(bigstr);
		bigprint_fadetime = time + staytime;
		bigprint_appeartime = time;
	}
	
    bigprint_noold = no;
    
	if(comment != "")
	{
		bpc_draw = 1;
		
		if(bigprint_comment)
			fstrunzone(bigprint_comment);
		
		bigprint_comment = strzone(comment);
		bigprint_commentfadetime = time + staytime;
		bigprint_commentappeartime = time;
	}
}

void score_visual(float score)
{
	string s;
	vector c;
	
	if(score < 0)
	{
		c = '1 0 0';
		s = ftos(score);
	}
	else
	{
		c = '0 1 0';
		c_z = c_x = max(0, 1 - score / SCORECOLOR_MAXSCORE);
		s = strcat("+", ftos(score));
	}
	
	if(score_strings_num >= MAX_SCORESTRINGS)
	{
		float k2;
		for(k2 = 0; k2 < MAX_SCORESTRINGS-1; ++k2)
		{
			if(score_strings[k2]) strunzone(score_strings[k2]);
			score_strings[k2] = strzone(score_strings[k2+1]);
			score_strings_fadeout[k2] = score_strings_fadeout[k2+1];
			score_strings_color[k2] = score_strings_color[k2+1];
			score_strings_appear[k2] = score_strings_appear[k2+1];
			score_strings_alphamod[k2] = score_strings_alphamod[k2+1] * 0.8;
		}
		
		strunzone(score_strings[k2]);
		score_strings_num--;
	}
	
	score_strings[score_strings_num] = strzone(s);
	score_strings_fadeout[score_strings_num] = time + 2;
	score_strings_color[score_strings_num] = c;
	score_strings_alphamod[score_strings_num] = 1.0;
	score_strings_appear[score_strings_num] = time;
	++score_strings_num;
}

void hudflash(vector colour, float staytime, float intensivity, float alph)
{
	hudflash_color = colour;
	hudflash_intensivity = intensivity;
	hudflash_alpha = alph;
	hudflash_appeartime = time;
	hudflash_fadetime = time + staytime;
	hudflash_enabled = TRUE;
}
