
entity porto;
vector polyline[16];
float trace_dphitcontents;
float trace_networkentity;

void Porto_Draw()
{
	vector p, dir, ang, q, nextdir;
	float idx, portal_number, portal1_idx;

	if(activeweapon != WEP_PORTO || spectatee_status || gametype == GAME_NEXBALL)
		return;
	if(intermission == 1)
		return;
	if(intermission == 2)
		return;
	if (getstati(STAT_HEALTH) <= 0)
		return;

	dir = view_forward;

	if(angles_held_status)
	{
		makevectors(angles_held);
		dir = v_forward;
	}

	p = view_origin;

	polyline[0] = p;
	idx = 1;
	portal_number = 0;
	nextdir = dir;

	for(;;)
	{
		dir = nextdir;
		traceline(p, p + 65536 * dir, TRUE, porto);
		if(trace_dphitq3surfaceflags & Q3SURFACEFLAG_NOIMPACT)
			return;
		nextdir = dir - 2 * (dir * trace_plane_normal) * trace_plane_normal; // mirror dir at trace_plane_normal
		p = trace_endpos;
		polyline[idx] = p;
		++idx;
		if(idx >= 16)
			return;
		if(trace_dphitq3surfaceflags & Q3SURFACEFLAG_SLICK || trace_dphitcontents & DPCONTENTS_PLAYERCLIP)
			continue;
		++portal_number;
		ang = vectoangles2(trace_plane_normal, dir);
		ang_x = -ang_x;
		makevectors(ang);
		if(!CheckWireframeBox(porto, p - 48 * v_right - 48 * v_up + 16 * v_forward, 96 * v_right, 96 * v_up, 96 * v_forward))
			return;
		if(portal_number == 1)
			portal1_idx = idx;
		if(portal_number >= 2)
			break;
	}

	while(idx >= 2)
	{
		p = polyline[idx-2];
		q = polyline[idx-1];
		if(idx == 2)
			p = p - view_up * 16;
		if(idx-1 >= portal1_idx)
		{
			Draw_CylindricLine(p, q, 4, "", 1, 0, '0 0 1', 0.5, DRAWFLAG_NORMAL, view_origin);
		}
		else
		{
			Draw_CylindricLine(p, q, 4, "", 1, 0, '1 0 0', 0.5, DRAWFLAG_NORMAL, view_origin);
		}
		--idx;
	}
}

vector Plasma_Draw_Trace_Callback_rgb;
float Plasma_Draw_Trace_Callback_ofs;

void Plasma_Draw_Trace_Callback(vector from, vector endpos, vector to) {
    vector ofs = normalize(endpos - from) * 3;

    Draw_CylindricLine(from - ofs, endpos + ofs, 15, "particles/zapper", 0.1, Plasma_Draw_Trace_Callback_ofs, Plasma_Draw_Trace_Callback_rgb, 1, DRAWFLAG_ADDITIVE, WarpZone_TransformOrigin(WarpZone_trace_transform, view_origin));

    Plasma_Draw_Trace_Callback_ofs += 0.1 * vlen(from - endpos - ofs * 2) / 15;
}

.float plasma_drawn;

void Plasma_Draw() {
    entity e, n, p = plasma_chain;
    string tex = "particles/zapper";

    for(e = p; e; e = e.plasma_next) if(e.extradata) if(e.plasma_drawn != time) {
        vector rgb = Zapper_BeamRGB(if(rm_teamlasers) e.team else COLOR_TEAM2) * 0.5;
        
        for(n = p; n; n = n.plasma_next) if(n.plasma_drawn != time) {
            if(e != n && n.extradata == e.extradata) {
                if(warpzone_chain_begin) {
                    var nearest_origin = WarpZone_FindNearestOrigin(n.origin, e.origin, FALSE);
                    if(WarpZone_FindNearestOrigin_length < 200) {
                        Plasma_Draw_Trace_Callback_rgb = rgb;
                        Plasma_Draw_Trace_Callback_ofs = time * 5;
                        WarpZone_TraceBox_ThroughZone(n.origin, '0 0 0', '0 0 0', nearest_origin, MOVE_NORMAL, n, world, Plasma_Draw_Trace_Callback);
                    }
                } else if(vlen(n.origin - e.origin) < 200) {
                    Draw_CylindricLine(n.origin, e.origin, 15, "particles/zapper", 0.1, time * 5, rgb, 1, DRAWFLAG_ADDITIVE, view_origin);
                }
            }
        }
        
        e.plasma_drawn = time;
    }
}

/**
 * Checks whether the server initiated a map restart (stat_game_starttime changed)
 *
 * TODO: Use a better solution where a common shared entitiy is used that contains
 * timelimit, fraglimit and game_starttime! Requires engine changes (remove STAT_TIMELIMIT
 * and STAT_FRAGLIMIT to be auto-sent)
 */
void CheckForGamestartChange() {
	float startTime;
	startTime = getstatf(STAT_GAMESTARTTIME);
	if (previous_game_starttime != startTime && !warmup_stage) {
		if ((time + 5.0) < startTime) {
			//if connecting to server while restart was active don't always play prepareforbattle
			sound(self, CHAN_VOICE, "announcer/robotic/prepareforbattle.wav", VOL_BASEVOICE, ATTN_NONE);
		}
		if (time < startTime) {
			restartAnnouncer = spawn();
			restartAnnouncer.think = restartAnnouncer_Think;
			restartAnnouncer.nextthink = startTime - floor(startTime - time); //synchronize nextthink to startTime
		}
	}
	previous_game_starttime = startTime;
}

void Porto_Init()
{
	porto = spawn();
	porto.classname = "porto";
	porto.draw = Porto_Draw;
	porto.dphitcontentsmask = DPCONTENTS_SOLID | DPCONTENTS_BODY | DPCONTENTS_PLAYERCLIP;
}

float drawtime;

float tan(float x)
{
	return sin(x) / cos(x);
}
float atan2(float y, float x)
{
	vector v;
	v = '1 0 0' * x + '0 1 0' * y;
	v = vectoangles(v);
	return v_y * 0.01745329251994329576;
}

float oldzoomspeed;
float oldzoomfactor;

vector GetCurrentFov(float fov)
{
	float zoomsensitivity, zoomspeed, zoomfactor, zoomdir;

    float twarp = getstatf(STAT_HGTWARP_WARPTIME);

    if(twarp) {
        const twarp_dur = 0.75;
        twarp = 1 - bound(0, (servertime - twarp) / twarp_dur, 1);

        if(twarp)
            fov *= (1 + twarp * 0.15);
    }

	zoomsensitivity = CVAR(cl_zoomsensitivity);
	zoomfactor = CVAR(cl_zoomfactor);
	zoomspeed = CVAR(cl_zoomspeed);
	
	if(zoomspeed 	!= oldzoomspeed || 
	   zoomfactor	!= oldzoomfactor )
	{
		localcmd("cmd zoomreport ", ftos(zoomspeed), " ", ftos(zoomfactor), "\n");
		oldzoomspeed = zoomspeed;
		oldzoomfactor = zoomfactor;
	}
	
	if(fovlock > -1)
	{
		zoomfactor = speczoom_factor;
		zoomspeed = speczoom_speed;
	}
	
	if(zoomfactor < 1 || zoomfactor > 16)
		zoomfactor = 2.5;
		
	if(zoomspeed >= 0)
		if(zoomspeed < 0.5 || zoomspeed > 16)
			zoomspeed = 3.5;

	if(spectatee_status > 0 || isdemo())
	{
		if(spectatorbutton_zoom)
			//zoomdir = 0 + !zoomdir;
			// do not even THINK about removing this 0
			// _I_ know what I am doing
			// fteqcc does not
			
			/// cool story bro.
			zoomdir = 1; 
	}
	else
	{
		zoomdir = button_zoom;
		if(!g_balance_nex_secondary && getstati(STAT_ACTIVEWEAPON) == WEP_NEX) // do NOT use switchweapon here
			zoomdir += button_attack2;
	}

	if(zoomdir)
		zoomin_effect = 0;

	if(zoomin_effect || camera_active)
	{
		current_viewzoom = min(1, current_viewzoom + drawframetime);
	}
	else
	{
		if(zoomspeed < 0) // instant zoom
		{
			if(zoomdir)
				current_viewzoom = 1 / zoomfactor;
			else
				current_viewzoom = 1;
		}
		else
		{
			if(zoomdir)
				current_viewzoom = 1 / bound(1, 1 / current_viewzoom + drawframetime * zoomspeed * (zoomfactor - 1), zoomfactor);
			else
				current_viewzoom = bound(1 / zoomfactor, current_viewzoom + drawframetime * zoomspeed * (1 - 1 / zoomfactor), 1);
		}
	}

	if(almost_equals(current_viewzoom, 1))
		current_zoomfraction = 0;
	else if(almost_equals(current_viewzoom, 1/zoomfactor))
		current_zoomfraction = 1;
	else
		current_zoomfraction = (current_viewzoom - 1) / (1/zoomfactor - 1);

	if(zoomsensitivity < 1)
		setsensitivityscale(pow(current_viewzoom, 1 - zoomsensitivity));
	else
		setsensitivityscale(1);

	float frustumx, frustumy, fovx, fovy;
	frustumy = tan(fov * 0.00872664625997164788) * 0.75 * current_viewzoom;
	frustumx = frustumy * vid_width / vid_height / vid_pixelheight;
	fovx = atan2(frustumx, 1) / 0.00872664625997164788;
	fovy = atan2(frustumy, 1) / 0.00872664625997164788;

	if(whatsgoingon || forcefog == "nyan") {
		float factor = 2 * bound(1, vlen(pmove_vel) * 0.006, 6);
		float t = time * 0.3;
		fovx += factor * sin(1.11 * t) * cos(1.45 * t * 2);
		fovy += factor * cos(1.22 * t) * sin(1.32 * t * 2);
	}

	return '1 0 0' * fovx + '0 1 0' * fovy;
}

// this function must match W_SetupShot!
float zoomscript_caught;

vector wcross_origin;
entity trueaim;
entity trueaim_rifle;

#define SHOTTYPE_HITTEAM 1
#define SHOTTYPE_HITOBSTRUCTION 2
#define SHOTTYPE_HITWORLD 3
#define SHOTTYPE_HITENEMY 4

void TrueAim_Init()
{
	trueaim = spawn();
	trueaim.classname = "trueaim";
	trueaim.dphitcontentsmask = DPCONTENTS_SOLID | DPCONTENTS_BODY | DPCONTENTS_CORPSE;
	trueaim_rifle = spawn();
	trueaim_rifle.classname = "trueaim_rifle";
	trueaim_rifle.dphitcontentsmask = DPCONTENTS_BODY | DPCONTENTS_CORPSE;
}

float EnemyHitCheck()
{
	float t;
	wcross_origin = project_3d_to_2d(trace_endpos);
	wcross_origin_z = 0;
	if(trace_networkentity < 1)
		return SHOTTYPE_HITWORLD;
	if(trace_networkentity > maxclients)
		return SHOTTYPE_HITWORLD;
	t = GetPlayerColor(trace_networkentity - 1);
	if(teamplay)
	if(t == myteam)
		return SHOTTYPE_HITTEAM;
	if(t == COLOR_SPECTATOR)
		return SHOTTYPE_HITWORLD;
	return SHOTTYPE_HITENEMY;
}

float TrueAimCheck()
{
	float nudge = 1; // added to traceline target and subtracted from result
	vector vecs, trueaimpoint, w_shotorg;
	vector mi, ma, dv;
	float shottype;

	mi = ma = '0 0 0';

	switch(activeweapon)
	{
		case WEP_TUBA: // no aim
		case WEP_PORTO: // shoots from eye
		case WEP_HOOK: // no trueaim
		case WEP_GRENADE_LAUNCHER: // toss curve
			return SHOTTYPE_HITWORLD;
		case WEP_CAMPINGRIFLE:
			if(zoomscript_caught)
			{
				tracebox(view_origin, '0 0 0', '0 0 0', view_origin + view_forward * MAX_SHOT_DISTANCE, MOVE_NORMAL, trueaim);
				return EnemyHitCheck();
			}
			break;
		case WEP_ROCKET_LAUNCHER: // projectile has a size!
			mi = '-3 -3 -3';
			ma = '3 3 3';
			break;
		case WEP_FIREBALL: // projectile has a size!
			mi = '-16 -16 -16';
			ma = '16 16 16';
			break;
		case WEP_ELECTRO: // projectile has a size!
			mi = '0 0 -3';
			ma = '0 0 -3';
			break;
	}

	vecs = ReadShotOriginStat(STAT_SHOTORG);

	if(activeweapon == WEP_CAMPINGRIFLE)
		traceline(view_origin, view_origin + view_forward * MAX_SHOT_DISTANCE, MOVE_NORMAL, trueaim_rifle);
	else
		traceline(view_origin, view_origin + view_forward * MAX_SHOT_DISTANCE, MOVE_NOMONSTERS, trueaim);
	trueaimpoint = trace_endpos;

	dv = view_right * vecs_y + view_up * vecs_z;
	w_shotorg = view_origin + dv;

	// now move the vecs forward as much as requested if possible
	tracebox(w_shotorg, mi, ma, w_shotorg + view_forward * (vecs_x + nudge), MOVE_NORMAL, trueaim); // FIXME this MOVE_NORMAL part will misbehave a little in csqc
	w_shotorg = trace_endpos - view_forward * nudge;

	tracebox(w_shotorg, mi, ma, trueaimpoint, MOVE_NORMAL, trueaim);
	shottype = EnemyHitCheck();
	if(shottype != SHOTTYPE_HITWORLD)
		return shottype;

	return SHOTTYPE_HITWORLD;
}

float fps_start;
float fps_frames;

// FIXME: make it unaffected by slowmo
void FPSCounter_Update() {
	if(time - fps_start >= 1) {
		cl_fps = fps_frames;
		fps_frames = 0;
		fps_start = time;
	}
	
	fps_frames++;
}

void Sbar_Draw(void);

float oldfov;

void CSQC_kh_hud(vector);
void CSQC_ctf_hud(vector);
void PostInit(void);
void CSQC_Demo_Camera();
float Sbar_WouldDrawScoreboard ();
float view_set;
float camera_mode;
string NextFrameCommand;

float hg_nadecount;
float hg_nadecount2;
float hg_nadecount_firstframepassed;

float hg_lastgain;
float hg_totalgaintime;
float hg_gaincount;

float crosshair_ringfill;

float crosshair_inring_fill;
float crosshair_inring_alpha;
float crosshair_inring_expand;

void HG_NadeGainSound() {
    float c1 = getstati(STAT_HGAMMO);
    float c2 = getstati(STAT_HGAMMO2);
    float sndplayed = FALSE;
    
    if(hg_nadecount_firstframepassed) {
        if(c1 != hg_nadecount) {
            hgregen = 1;
            hg_nadecount_update = time;
            if(c1 > hg_nadecount) {
                localcmd("play2 misc/poweroff\n");
                sndplayed = TRUE;

                if(cvar("developer")) {
                    if(hg_lastgain) {
                        var diff = time - hg_lastgain;
                        print("Gain time: ", ftos(diff), "\n");
                        hg_gaincount++;
                        hg_totalgaintime += diff;
                        print("Avg. gain time: ", ftos(hg_totalgaintime / hg_gaincount), "\n");
                    }

                    hg_lastgain = time;
                }
            }
        }

        if(c2 != hg_nadecount2) {
            hgregen2 = 1;
            hg_nadecount2_update = time;
            if(c2 > hg_nadecount2 && !sndplayed)
                localcmd("play2 misc/poweroff\n");
        }
    }

    hg_nadecount_firstframepassed = TRUE;
    hg_nadecount = c1;
    hg_nadecount2 = c2;
}

float glines_spread[2];
float glines_alpha[2];
float glines_anim[2];

void DrawSpreadGuideLine(vector realorg, vector org, vector dir, float spread, float a, float animphase) {
    var angle = vectoangles(dir);
    fixedmakevectors2(angle + [0, spread, 0]);
    dir = v_forward;

    traceline(org, org + dir * MAX_SHOT_DISTANCE, MOVE_NOMONSTERS, world);
    var dst = trace_endpos;

    Draw_CylindricLine(org, dst, 5, "particles/guideline", 0.05, animphase, '1 1 0.35', a, DRAWFLAG_ADDITIVE, view_origin);
}

void DrawSpreadGuideLines(float statfld, float invert) {
    /*
     *  TODO:
     *
     *      -- Use the actual shot origin for the trace (currently g_shootfromeye 1 is assumed).
     *      -- Maybe interpolate the spread value for low ticrates.
     *      -- Warpzone support.
     *      -- If someone wants to improve the guideline texture I'm all for it.
     */

    var org = view_origin;
    var dir = view_forward;

    var spread = getstatf(statfld);

    var i = invert;

    if(spread < 0) {
        glines_alpha[i] = approach(glines_alpha[i], 0, drawframetime * 5);
        if(!glines_alpha[i])
            return;
    } else {
        glines_alpha[i] = approach(glines_alpha[i], 1, drawframetime * 5);
        glines_spread[i] = spread;
        glines_anim[i] = glines_anim[i] - drawframetime;
    }

    var shotorg = ReadShotOriginStat(STAT_SHOTORG_VISUAL);

    if(invert)
        shotorg_y = -shotorg_y;

    org += view_forward * shotorg_x + view_right * shotorg_y + view_up * (shotorg_z + 6);

    DrawSpreadGuideLine(view_origin, org, dir,  glines_spread[i], glines_alpha[i], glines_anim[i]);
    DrawSpreadGuideLine(view_origin, org, dir, -glines_spread[i], glines_alpha[i], glines_anim[i]);
}

void CSQC_UpdateView(float w, float h)
{
	fps_friendly = CVAR(rm_fps_friendly);
	entity e;
	float fov;
	float f, i, j;
	vector v;

    // XXX: client and menu have shared extresponses
    // doing this here will prevent menu from processing any of them...
    // ER_Update();

    HG_NadeGainSound();

	dprint_load();
	WaypointSprite_Load();

	if(spectatee_status)
		myteam = GetPlayerColor(spectatee_status - 1);
	else
		myteam = GetPlayerColor(player_localentnum - 1);

	ticrate = getstatf(STAT_MOVEVARS_TICRATE) * getstatf(STAT_MOVEVARS_TIMESCALE);

	WarpZone_FixView();

	// Render the Scene
	if(!intermission || !view_set)
	{
		if(warpzone_newstyle) {
			view_origin = getpropertyvec(VF_ORIGIN);
			view_angles = getpropertyvec(VF_ANGLES);
		} else {
			view_origin = pmove_org + '0 0 1' * getstati(STAT_VIEWHEIGHT);
			view_angles = input_angles;
		}
		makevectors(view_angles);
		view_forward = v_forward;
		view_right = v_right;
		view_up = v_up;
		view_set = 1;
	}

	vid_width = w;
	vid_height = h;

#ifdef BLURTEST
	if(time > blurtest_time0 && time < blurtest_time1)
	{
		float r, t;

		t = (time - blurtest_time0) / (blurtest_time1 - blurtest_time0);
		r = t * blurtest_radius;
		f = 1 / pow(t, blurtest_power) - 1;

		cvar_set("r_glsl_postprocess", "1");
		cvar_set("r_glsl_postprocess_uservec1", strcat(ftos(r), " ", ftos(f), " 0 0"));
	}
	else
	{
		cvar_set("r_glsl_postprocess", "0");
		cvar_set("r_glsl_postprocess_uservec1", "0 0 0 0");
	}
#endif

	Fog_Force();

	drawframetime = max(0.000001, time - drawtime);
	drawtime = time;

	// watch for gametype changes here...
	// in ParseStuffCMD the cmd isn't executed yet :/
	// might even be better to add the gametype to TE_CSQC_INIT...?
	if(!postinit)
		PostInit();

	if(intermission && !isdemo() && !(calledhooks & HOOK_END))
	if(calledhooks & HOOK_START)
	{
		localcmd("\ncl_hook_gameend;");
		calledhooks |= HOOK_END;
	}

	CheckForGamestartChange();
	maptimeAnnouncer();

	fov = CVAR(fov);
	
	if(fov != oldfov)
	{
		if(sv_showspecs_extra)
			localcmd("cmd fovreport ", ftos(fov), "\n");
		oldfov = fov;
	}
	
	if(button_zoom || fov <= 59.5)
	{
		if(!zoomscript_caught)
		{
			localcmd("+button4\n");
			zoomscript_caught = 1;
			ignore_plus_zoom += 1;
		}
	}
	else
	{
		if(zoomscript_caught)
		{
			localcmd("-button4\n");
			zoomscript_caught = 0;
			ignore_minus_zoom += 1;
		}
	}

	float m;
	m = (1 - CVAR(_menu_alpha));
	sbar_alpha_fg = CVAR(sbar_alpha_fg) /* * (1 - CVAR(_menu_alpha))*/;
	sbar_currentammo = CVAR(sbar_showcurrentammo);
	sbar_hudselector = CVAR(sbar_hudselector);
	sbar_hud_accuracy = CVAR(sbar_hud_accuracy);
	ColorTranslateMode = CVAR(cl_stripcolorcodes);
	activeweapon = getstati(STAT_SWITCHWEAPON);
	f = CVAR(teamplay);
	if(f != teamplay)
	{
		teamplay = f;
		Sbar_InitScores();
	}

	if(last_weapon != activeweapon) {
		weapontime = time;
		last_weapon = activeweapon;
	}

	// ALWAYS Clear Current Scene First
	R_ClearScene();
	setproperty(VF_ORIGIN, view_origin);
	setproperty(VF_ANGLES, view_angles);

	// Assign Standard Viewflags
	// Draw the World (and sky)
	R_SetView(VF_DRAWWORLD, 1);

	// Set the console size vars
	vid_conwidth = CVAR(vid_conwidth);
	vid_conheight = CVAR(vid_conheight);
	vid_pixelheight = CVAR(vid_pixelheight);

	if(fovlock > -1)
		R_SetView(VF_FOV, GetCurrentFov(fovlock));
	else
		R_SetView(VF_FOV, GetCurrentFov(fov));
	
	if(spectatee_status < 0)
		camera_expiretime = -1;
	
	float tempcamera = (time < camera_expiretime || camera_expiretime < -1);
    
	if(getstati(STAT_ROUNDLOST))
	if(getstati(STAT_HEALTH) > 0)
		tempcamera = FALSE;
	
	if(tempcamera) {
		if(!camera_drawviewmodel_locked) {
			camera_drawviewmodel_locked = TRUE;
			camera_drawviewmodel_backup = CVAR(r_drawviewmodel);
		}
		
		R_SetView(VF_ORIGIN, camera_origin);
		cvar_clientsettemp("r_drawviewmodel", "0");
	} else if(camera_drawviewmodel_locked) {
		camera_drawviewmodel_locked = FALSE;
		cvar_set("r_drawviewmodel", ftos(camera_drawviewmodel_backup));
	} else if(camera_active) { // Camera for demo playback
		if(CVAR(camera_enable))
			CSQC_Demo_Camera();
		else
		{
			cvar_set("chase_active", ftos(chase_active_backup));
			cvar_set("cl_demo_mousegrab", "0");
			camera_active = FALSE;
		}
	}
#ifdef CAMERATEST
	else if(CVAR(camera_enable))
#else
	else if(CVAR(camera_enable) && isdemo())
#endif
	{
		// Enable required Darkplaces cvars
		chase_active_backup = CVAR(chase_active);
		cvar_set("chase_active", "2");
		cvar_set("cl_demo_mousegrab", "1");
		camera_active = TRUE;
		camera_mode = FALSE;
	}
	
	// Draw the Crosshair
	float scoreboard_active;
	scoreboard_active = Sbar_WouldDrawScoreboard();
	R_SetView(VF_DRAWCROSSHAIR, 0); //Make sure engine crosshairs are always hidden

	// Draw the Engine Status Bar (the default Quake HUD)
	R_SetView(VF_DRAWENGINESBAR, 0);

	// fetch this one only once per frame
	sbar_showbinds = CVAR(sbar_showbinds);
	sbar_showbinds_limit = CVAR(sbar_showbinds_limit);

	e = self;
	for(self = world; (self = nextent(self)); )
		if(self.draw)
			self.draw();
	self = e;
    if (!fps_friendly)
        Plasma_Draw();

    DrawSpreadGuideLines(STAT_AIMSPREAD, FALSE);
    DrawSpreadGuideLines(STAT_AIMSPREAD2, TRUE);

	R_AddEntities(MASK_NORMAL | MASK_ENGINE | MASK_ENGINEVIEWMODELS);
	R_RenderScene();

	// now switch to 2D drawing mode by calling a 2D drawing function
	// then polygon drawing will draw as 2D stuff, and NOT get queued until the
	// next R_RenderScene call
	drawstring('0 0 0', "", '1 1 0', '1 1 1', 0, 0);

    Sbar_DrawTintEffects();

	// draw 2D entities

    VisualDamage_PreDraw();
	e = self;
	for(self = world; (self = nextent(self)); )
		if(self.draw2d)
			self.draw2d();
	self = e;

	// draw radar
    if(!tempcamera && (ons_showmap || (!scoreboard_active && CVAR(cl_teamradar) && (teamplay || CVAR(cl_teamradar) == 2))))
        teamradar_view();

	// draw sbar
 	if(CVAR(r_letterbox) == 0) {
		if (CVAR(cl_showpressedkeys)) { // draw pressed keys when spectating and playing
			if(spectatee_status > 0 || CVAR(cl_showpressedkeys) >= 2)
				Sbar_DrawPressedKeys();
		}
		
		if (CVAR(cl_showspeed))
			Sbar_ShowSpeed();
		if (CVAR(cl_showacceleration))
			Sbar_ShowAcceleration();
		if (CVAR(cl_lowammowarnings))
			Sbar_ShowLowammo();
		
 		Sbar_DrawCenterPrint(); // draw centerprint messages even if viewsize >= 120
	}

    if(!CVAR(r_letterbox))
        if(CVAR(viewsize) < 120)
            Sbar_Draw();

    // crosshair goes VERY LAST
    if not(tempcamera)
    if(spectatee_status != -1)
    if(!scoreboard_active && !ons_showmap && !camera_active) {
        // TrueAim check
        float shottype;
        float bullets;
        wcross_origin = project_3d_to_2d(view_origin + MAX_SHOT_DISTANCE * view_forward);
        wcross_origin_z = 0;
        if(CVAR(crosshair_hittest))
        {
            vector wcross_oldorigin;
            wcross_oldorigin = wcross_origin;
            shottype = TrueAimCheck();
            if(shottype == SHOTTYPE_HITWORLD)
            {
                v = wcross_origin - wcross_oldorigin;
                v_x /= vid_conwidth;
                v_y /= vid_conheight;
                if(vlen(v) > 0.01)
                    shottype = SHOTTYPE_HITOBSTRUCTION;
            }
            if(!CVAR(crosshair_hittest_showimpact))
                wcross_origin = wcross_oldorigin;
        }
        else
            shottype = SHOTTYPE_HITWORLD;

        string wcross_style;
        wcross_style = CVAR_STR(crosshair);

        if (wcross_style != "0") {
            vector wcross_color, wcross_size;
            string wcross_wep, wcross_name;
            float wcross_alpha, wcross_sizefloat;

            if(rm_crosshealth) {
                vector x = healtharmor_maxdamage(getstati(STAT_HEALTH), getstati(STAT_ARMOR), armorblockpercent);
                wcross_color = healthcolor(x_x);
            } else {
                wcross_color_x = CVAR(crosshair_color_red);
                wcross_color_y = CVAR(crosshair_color_green);
                wcross_color_z = CVAR(crosshair_color_blue);
            }
            
            wcross_alpha = CVAR(crosshair_color_alpha) * m * (1 - sbar_scoreboard_fade_alpha);
            wcross_sizefloat = CVAR(crosshair_size) * m * (1 - sbar_scoreboard_fade_alpha);
            if (CVAR(crosshair_per_weapon)) {
                e = get_weaponinfo(activeweapon);
                if (e && e.netname != "")
                {
                    wcross_wep = e.netname;
                    wcross_style = cvar_string(strcat("crosshair_", wcross_wep));
                    if(wcross_style == "")
                        wcross_style = e.netname;

                    if(!CVAR(crosshair_color_override))
                    {
                        wcross_color_x = cvar(strcat("crosshair_", wcross_wep, "_color_red"));
                        wcross_color_y = cvar(strcat("crosshair_", wcross_wep, "_color_green"));
                        wcross_color_z = cvar(strcat("crosshair_", wcross_wep, "_color_blue"));
                    }

                    wcross_alpha *= cvar(strcat("crosshair_", wcross_wep, "_color_alpha"));
                    wcross_sizefloat *= cvar(strcat("crosshair_", wcross_wep, "_size"));
                }
            }

            wcross_name = strcat("gfx/crosshair", wcross_style);

            if(shottype == SHOTTYPE_HITENEMY)
                wcross_sizefloat *= CVAR(crosshair_hittest); // is not queried if hittest is 0
            if(shottype == SHOTTYPE_HITTEAM)
                wcross_sizefloat /= CVAR(crosshair_hittest); // is not queried if hittest is 0

            wcross_size = drawgetimagesize(wcross_name);
            wcross_size_x *= wcross_sizefloat;
            wcross_size_y *= wcross_sizefloat;

            float bullet, maxbullets, distance = 14;
            maxbullets = getstati(STAT_CLIP_LIMIT);

            if(maxbullets > 0) {
                bullets = bound(0, getstatf(STAT_CLIP_LOADED), maxbullets);
            } else if(getstati(STAT_SWITCHWEAPON) == WEP_ZAPPER && (var zheat = getstatf(STAT_ZAPPER_HEAT)) >= 0) {
                maxbullets = 1;
                bullets = bound(0, (1 - zheat), 1);
            } else
                bullets = 0;

            if(bullets) {
                crosshair_inring_expand = approach(crosshair_inring_expand, 1, drawframetime * 2);
            } else {
                crosshair_inring_expand = approach(crosshair_inring_expand, 0, drawframetime * 4);
            }

            if(maxbullets > 0) {
                crosshair_ringfill += (bullets / maxbullets - crosshair_ringfill) * drawframetime * 10;
                if(crosshair_ringfill > 1)
                    crosshair_ringfill = 1;
            } else {
                crosshair_ringfill -= crosshair_ringfill * drawframetime * 10;
                if(crosshair_ringfill < 0)
                    crosshair_ringfill = 0;
            }

            var ringsize = CVAR(rm_hud_crosshair_ring_size) * 24 * wcross_sizefloat;
            var ringalpha = CVAR(rm_hud_crosshair_ring_alpha) * wcross_alpha;
            var ringexpand = 0.25; // TODO: cvar for this?

            if(ringsize > 0 && ringalpha > 0) {
                if(crosshair_ringfill) {
                    DrawCircleClippedPic(
                        wcross_origin,
                        ringsize,
                        if(maxbullets > 1 && maxbullets < 25)
                            strcat("gfx/hud/ring", ftos(maxbullets), ".tga")
                        else
                            "gfx/hud/ring1.tga",
                        crosshair_ringfill,
                        0.5 * wcross_color + '0.5 0.5 0.5',
                        ringalpha,
                        DRAWFLAG_ADDITIVE
                    );
                }

                var in_cycle = getstatf(STAT_INNERRING_CYCLE);
                var in_fulltime = getstatf(STAT_INNERRING_FULLTIME);
                var in_invert = FALSE;

                if(in_cycle < 0) {
                    in_cycle *= -1;
                    in_invert = TRUE;
                }

                if(in_fulltime > 0) {
                    crosshair_inring_fill = 1 - bound(0, (in_fulltime - servertime) / in_cycle, 1);

                    if(crosshair_inring_fill && crosshair_inring_fill < 1)
                        crosshair_inring_alpha = approach(crosshair_inring_alpha, 1, drawframetime * 14);
                    else
                        crosshair_inring_alpha = approach(crosshair_inring_alpha, 0, drawframetime * 7);
                } else
                    crosshair_inring_alpha = approach(crosshair_inring_alpha, 0, drawframetime * 7);

                if(crosshair_inring_alpha) {
                    DrawCircleClippedPic(
                        wcross_origin,
                        ringsize * (1 + ringexpand * crosshair_inring_expand * crosshair_inring_alpha),
                        "gfx/hud/ring_inner.tga",
                        if(in_invert) 1 - crosshair_inring_fill else crosshair_inring_fill,
                        0.5 * wcross_color + '0.5 0.5 0.5',
                        ringalpha * crosshair_inring_alpha,
                        DRAWFLAG_ADDITIVE
                    );
                }
            }

            if(shottype == SHOTTYPE_HITTEAM || (shottype == SHOTTYPE_HITOBSTRUCTION && CVAR(crosshair_hittest_blur) && !CVAR(chase_active))) {
                wcross_alpha *= 0.04 * 0.75;
                for(i = -2; i <= 2; ++i)
                    for(j = -2; j <= 2; ++j)
                        drawpic(wcross_origin - 0.5 * wcross_size, wcross_name, wcross_size, wcross_color, wcross_alpha, DRAWFLAG_NORMAL);
            } else {
                drawpic(wcross_origin - 0.5 * wcross_size, wcross_name, wcross_size, wcross_color, wcross_alpha, DRAWFLAG_NORMAL);
            }
        }
    }

	if(screenfade)
	{
		vector position;
		position_x = vid_conwidth;
		position_y = vid_conheight;
		
		float sf_a;
		sf_a =  bound(0, 1 - 4 * (time - screenfade), 1);
		
		if(!sf_a)
			screenfade = 0;
		else
			drawfill('0 0 0', position, '0 0 0', sf_a, DRAWFLAG_NORMAL);
	}

    NS_Draw();
    WS_Draw();
	
	if(NextFrameCommand)
	{
		localcmd("\n", NextFrameCommand, "\n");
		NextFrameCommand = NULL;
	}

    if(mouse_enabled) {
        if(mouse_pos == '-1 -1')
            mouse_pos = [vid_conwidth, vid_conheight] * 0.5;
        else {
            mouse_pos = mouse_pos + getmousepos();
            mouse_pos = [bound(0, mouse_pos_x, vid_conwidth),
                         bound(0, mouse_pos_y, vid_conheight)];
        }

        drawpic(mouse_pos, strcat("gfx/menu/", CVAR_STR(menu_rmskin), "/cursor.tga"), '32 32 0', '1 1 1', sbar_alpha_fg, DRAWFLAG_NORMAL);
    }

	// we must do this check AFTER a frame was rendered, or it won't work
	if(cs_project_is_b0rked == 0)
	{
		string w0, h0;
		w0 = ftos(CVAR(vid_conwidth));
		h0 = ftos(CVAR(vid_conheight));
		R_SetView(VF_ORIGIN, '0 0 0');
		R_SetView(VF_ANGLES, '0 0 0');
		R_SetView(VF_PERSPECTIVE, 1);
		makevectors('0 0 0');
		vector v1, v2;
		cvar_set("vid_conwidth", "800");
		cvar_set("vid_conheight", "600");
		v1 = cs_project(v_forward);
		cvar_set("vid_conwidth", "640");
		cvar_set("vid_conheight", "480");
		v2 = cs_project(v_forward);
		if(v1 == v2)
			cs_project_is_b0rked = 1;
		else
			cs_project_is_b0rked = -1;
		cvar_set("vid_conwidth", w0);
		cvar_set("vid_conheight", h0);
	}
	
	FPSCounter_Update();
    
    if(getstati(STAT_ROUNDSTATE) == ROUNDSTATE_GAME) {
        entity pl; for(pl = players.sort_next; pl; pl = pl.sort_next)
            if(GetPlayerColor(pl.sv_entnum) != COLOR_SPECTATOR)
                pl.(scores[SP_PLAYTIME]) += drawframetime;
    }
    
	// be safe against triggerbots until everyone has the fixed engine
	// this call is meant to overwrite the trace globals by something
	// unsuspicious
	traceline('0 0 0', '0 0 0', MOVE_WORLDONLY, world);
}

// following vectors must be global to allow seamless switching between camera modes
vector camera_offset, current_camera_offset, mouse_angles, current_angles, current_origin, current_position;
void CSQC_Demo_Camera()
{
	float speed, attenuation, dimensions;
	vector tmp, delta;

	if( CVAR(camera_reset) || !camera_mode )
	{
		camera_offset = '0 0 0';
		current_angles = '0 0 0';
		camera_direction = '0 0 0';
		camera_offset_z += 30;
		camera_offset_x += 30 * -cos(current_angles_y * DEG2RAD);
		camera_offset_y += 30 * -sin(current_angles_y * DEG2RAD);
		current_origin = view_origin;
		current_camera_offset  = camera_offset;
		cvar_set("camera_reset", "0");
		camera_mode = CAMERA_CHASE;
	}

	// Camera angles
	if( camera_roll )
		mouse_angles_z += camera_roll * CVAR(camera_speed_roll);

	if(CVAR(camera_look_player))
	{
		vector dir;
		float n;

		dir = normalize(view_origin - current_position);
		n = mouse_angles_z;
		mouse_angles = vectoangles(dir);
		mouse_angles_x = mouse_angles_x * -1;
		mouse_angles_z = n;
	}
	else
	{
		tmp = getmousepos() * 0.1;
		if(vlen(tmp)>CVAR(camera_mouse_treshold))
		{
			mouse_angles_x += tmp_y * cos(mouse_angles_z * DEG2RAD) + (tmp_x * sin(mouse_angles_z * DEG2RAD));
			mouse_angles_y -= tmp_x * cos(mouse_angles_z * DEG2RAD) + (tmp_y * -sin(mouse_angles_z * DEG2RAD));
		}
	}

	while (mouse_angles_x < -180) mouse_angles_x = mouse_angles_x + 360;
	while (mouse_angles_x > 180) mouse_angles_x = mouse_angles_x - 360;
	while (mouse_angles_y < -180) mouse_angles_y = mouse_angles_y + 360;
	while (mouse_angles_y > 180) mouse_angles_y = mouse_angles_y - 360;

	// Fix difference when angles don't have the same sign
	delta = '0 0 0';
	if(mouse_angles_y < -60 && current_angles_y > 60)
		delta = '0 360 0';
	if(mouse_angles_y > 60 && current_angles_y < -60)
		delta = '0 -360 0';

	if(CVAR(camera_look_player))
		attenuation = CVAR(camera_look_attenuation);
	else
		attenuation = CVAR(camera_speed_attenuation);

	attenuation = 1 / max(1, attenuation);
	current_angles += (mouse_angles - current_angles + delta) * attenuation;

	while (current_angles_x < -180) current_angles_x = current_angles_x + 360;
	while (current_angles_x > 180) current_angles_x = current_angles_x - 360;
	while (current_angles_y < -180) current_angles_y = current_angles_y + 360;
	while (current_angles_y > 180) current_angles_y = current_angles_y - 360;

	// Camera position
	tmp = '0 0 0';
	dimensions = 0;

	if( camera_direction_x )
	{
		tmp_x = camera_direction_x * cos(current_angles_y * DEG2RAD);
		tmp_y = camera_direction_x * sin(current_angles_y * DEG2RAD);
		if( CVAR(camera_forward_follows) && !CVAR(camera_look_player) )
			tmp_z = camera_direction_x * -sin(current_angles_x * DEG2RAD);
		++dimensions;
	}

	if( camera_direction_y )
	{
		tmp_x += camera_direction_y * -sin(current_angles_y * DEG2RAD);
		tmp_y += camera_direction_y * cos(current_angles_y * DEG2RAD) * cos(current_angles_z * DEG2RAD);
		tmp_z += camera_direction_y * sin(current_angles_z * DEG2RAD);
		++dimensions;
	}

	if( camera_direction_z )
	{
		tmp_z += camera_direction_z * cos(current_angles_z * DEG2RAD);
		++dimensions;
	}

	if(CVAR(camera_free))
		speed = CVAR(camera_speed_free);
	else
		speed = CVAR(camera_speed_chase);

	if(dimensions)
	{
		speed = speed * sqrt(1 / dimensions);
		camera_offset += tmp * speed;
	}

	current_camera_offset += (camera_offset - current_camera_offset) * attenuation;

	// Camera modes
	if( CVAR(camera_free) )
	{
		if ( camera_mode == CAMERA_CHASE )
		{
			current_camera_offset = current_origin + current_camera_offset;
			camera_offset = current_origin + camera_offset;
		}

		camera_mode = CAMERA_FREE;
		current_position = current_camera_offset;
	}
	else
	{
		if ( camera_mode == CAMERA_FREE )
		{
			current_origin = view_origin;
			camera_offset = camera_offset - current_origin;
			current_camera_offset = current_camera_offset - current_origin;
		}

		camera_mode = CAMERA_CHASE;

		if(CVAR(camera_chase_smoothly))
			current_origin += (view_origin - current_origin) * attenuation;
		else
			current_origin = view_origin;

		current_position = current_origin + current_camera_offset;
	}

	R_SetView(VF_ANGLES, current_angles);
	R_SetView(VF_ORIGIN, current_position);
}
