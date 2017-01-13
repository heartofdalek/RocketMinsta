
entity players;
entity teams;

void restartAnnouncer_Think() {
	float countdown_rounded, countdown;
	countdown = getstatf(STAT_GAMESTARTTIME) - time;
	countdown_rounded = floor(0.5 + countdown);
	if(countdown <= 0) {
		//if (!spectatee_status) //do cprint only for players
		//	centerprint("\x01^1Begin!");
		
		//gamestart_status = -1;
		//gamestart_fadetime = time + 1;
		
		bigprint("^xFB0Begin!", "It's time to kick some ass!", 1);

		sound(self, CHAN_VOICE, "announcer/robotic/begin.wav", VOL_BASEVOICE, ATTN_NONE);
		//reset maptime announcers now as well
		announcer_5min = announcer_1min = FALSE;

		remove(self);
		return;
	}
	else {
		//if (!spectatee_status) //do cprint only for players
		//{
		//	//centerprint(strcat("\x01^1Game starts in ", ftos(countdown_rounded), " seconds"));
		//	gamestart_status = countdown_rounded;
		//}

		//gamestart_status = countdown_rounded;
		//gamestart_fadetime = time + 0.5;
		//bigprint(strcat("Game starts in ", ftos(countdown_rounded)), "", 0.5);
		bigprint(" ", "", 1);
		bigprint(strcat(strcat(gametype_ID_to_LongName(gametype)), " starts in: ", ftos(countdown_rounded)), "", 1);

		if(countdown_rounded <= 3 && countdown_rounded >= 1) {
			sound(self, CHAN_VOICE, strcat("announcer/robotic/", ftos(countdown_rounded), ".wav"), VOL_BASEVOICE, ATTN_NONE);
		}

		self.nextthink = getstatf(STAT_GAMESTARTTIME) - (countdown - 1);
	}
}

/**
 * Plays the 1minute or 5 minutes (of maptime) remaining sound, if client wants it
 */
void maptimeAnnouncer() {
    float timelimit;
    timelimit = getstatf(STAT_TIMELIMIT);
    float timeleft;
    timeleft = max(0, timelimit * 60 + getstatf(STAT_GAMESTARTTIME) - time);

    //5 minute check
    if (CVAR(cl_sound_maptime_warning) >= 2) {
        //make sure that after connect (and e.g. 4 minutes left) we will not get a wrong sound
        if(announcer_5min)
        {
			if(timeleft > 300)
				announcer_5min = FALSE;
        }
        else if (timelimit > 0 && timeleft < 300 && timeleft > 299) {
			announcer_5min = TRUE;
			//dprint("i will play the sound, I promise!\n");
			sound(self, CHAN_VOICE, "announcer/robotic/5minutesremain.wav", VOL_BASEVOICE, ATTN_NONE);
		}
    }

    //1 minute check
    if (CVAR(cl_sound_maptime_warning) == 1 || CVAR(cl_sound_maptime_warning) == 3) {
    	if (announcer_1min)
    	{
			if(timeleft > 60)
				announcer_1min = FALSE;
    	}
    	else if (timelimit > 0 && timeleft < 60) {
			announcer_1min = TRUE;
			sound(self, CHAN_VOICE, "announcer/robotic/1minuteremains.wav", VOL_BASEVOICE, ATTN_NONE);
    	}
	}
}

/**
 * Add all future announcer sounds precaches here.
 * TODO: make all announcer sound() calls client-side in the end, to allow queues etc.
 */
void Announcer_Precache () {
    precache_sound("announcer/male/headshot.wav");
    precache_sound("announcer/male/awesome.wav");
    precache_sound("announcer/male/impressive.wav");
    precache_sound("announcer/male/amazing.wav");
    precache_sound("announcer/male/airshot.wav");
    precache_sound("announcer/robotic/1minuteremains.wav");
    precache_sound("announcer/robotic/1minuteremains.wav");
	precache_sound("announcer/robotic/5minutesremain.wav");
    precache_sound("porto/fire.wav");
}

void AuditLists()
{
	entity e;
	entity prev;

	prev = players;
	for(e = prev.sort_next; e; prev = e, e = e.sort_next)
	{
		if(prev != e.sort_prev)
			error(strcat("sort list chain error\nplease submit the output of 'prvm_edicts client' to the developers"));
	}

	prev = teams;
	for(e = prev.sort_next; e; prev = e, e = e.sort_next)
	{
		if(prev != e.sort_prev)
			error(strcat("sort list chain error\nplease submit the output of 'prvm_edicts client' to the developers"));
	}
}


float RegisterPlayer(entity player)
{
	entity pl;
	AuditLists();
	for(pl = players.sort_next; pl; pl = pl.sort_next)
		if(pl == player)
			error("Player already registered!");
	player.sort_next = players.sort_next;
	player.sort_prev = players;
	if(players.sort_next)
		players.sort_next.sort_prev = player;
	players.sort_next = player;
	AuditLists();
	return true;
}

void RemovePlayer(entity player)
{
	entity pl, parent;
	AuditLists();
	parent = players;
	for(pl = players.sort_next; pl && pl != player; pl = pl.sort_next)
		parent = pl;

	if(!pl)
	{
		error("Trying to remove a player which is not in the playerlist!");
		return;
	}
	parent.sort_next = player.sort_next;
	if(player.sort_next)
		player.sort_next.sort_prev = parent;
	AuditLists();
}

void MoveToLast(entity e)
{
	AuditLists();
	other = e.sort_next;
	while(other)
	{
		SORT_SWAP(other, e);
		other = e.sort_next;
	}
	AuditLists();
}

float RegisterTeam(entity Team)
{
	entity tm;
	AuditLists();
	for(tm = teams.sort_next; tm; tm = tm.sort_next)
		if(tm == Team)
			error("Team already registered!");
	Team.sort_next = teams.sort_next;
	Team.sort_prev = teams;
	if(teams.sort_next)
		teams.sort_next.sort_prev = Team;
	teams.sort_next = Team;
	AuditLists();
	return true;
}

void RemoveTeam(entity Team)
{
	entity tm, parent;
	AuditLists();
	parent = teams;
	for(tm = teams.sort_next; tm && tm != Team; tm = tm.sort_next)
		parent = tm;

	if(!tm)
	{
		print("Trying to remove a team which is not in the teamlist!");
		return;
	}
	parent.sort_next = Team.sort_next;
	if(Team.sort_next)
		Team.sort_next.sort_prev = parent;
	AuditLists();
}

entity GetTeam(float Team, float add)
{
	float num;
	entity tm;
	num = if(Team == COLOR_SPECTATOR) 16 else Team;
	if(teamslots[num])
		return teamslots[num];
	if not(add)
		return NULL;
	tm = spawn();
	tm.team = Team;
	teamslots[num] = tm;
	RegisterTeam(tm);
	return tm;
}

void SetupFonts()
{
	sbar_font = FONT_USER+1;
	sbar_bigfont = FONT_USER+2;
	sbar_rmbigfont = FONT_USER+4;
	sbar_madokafont = FONT_USER+3;
}

vector Sbar_GetFontsize(string cvarname)
{
	vector v;
	v = stov(cvar_string(cvarname));
	if(v_x == 0)
		v = '8 8 0';
	if(v_y == 0)
		v_y = v_x;
	v_z = 0;
	return v;
}

float Sbar_GetWidth(float teamcolumnwidth)
{
	#ifdef WE_DONT_NEED_TO_GO_WIDER
	float f;
	f = CVAR(sbar_width);
	if(f == 0)
		f = 640;
	if(f < 320)
		f = 320;
	if(f > vid_conwidth - 2 * teamcolumnwidth)
		f = vid_conwidth - 2 * teamcolumnwidth;
	return f;
	#else
	return vid_conwidth - 2 * teamcolumnwidth;
	#endif
}

float PreviewExists(string name)
{
	float f;
	string file;

	if(CVAR(cl_readpicture_force))
		return false;

	file = strcat(name, ".tga");
	f = fopen(file, FILE_READ);
	if(f >= 0)
	{
		fclose(f);
		return true;
	}
	file = strcat(name, ".png");
	f = fopen(file, FILE_READ);
	if(f >= 0)
	{
		fclose(f);
		return true;
	}
	file = strcat(name, ".jpg");
	f = fopen(file, FILE_READ);
	if(f >= 0)
	{
		fclose(f);
		return true;
	}
	file = strcat(name, ".pcx");
	f = fopen(file, FILE_READ);
	if(f >= 0)
	{
		fclose(f);
		return true;
	}
	return false;
}

float PI      = 3.14159265359;
float DEG2RAD = 0.01745329252;
vector rotate(vector v, float a)
{
	vector w;
	// FTEQCC SUCKS AGAIN
	w_x =      v_x * cos(a) + v_y * sin(a);
	w_y = -1 * v_x * sin(a) + v_y * cos(a);
	return w;
}

float ColorTranslateMode;

string ColorTranslateRGB(string s)
{
	if(ColorTranslateMode & 1)
		return strdecolorize(s);
	else
		return s;
}

float cvar_or(string cv, float v)
{
	string s;
	s = cvar_string(cv);
	if(s == "")
		return v;
	else
		return stof(s);
}

vector project_3d_to_2d(vector vec)
{
	vec = cs_project(vec);
	if(cs_project_is_b0rked > 0)
	{
		vec_x *= vid_conwidth / vid_width;
		vec_y *= vid_conheight / vid_height;
	}
	return vec;
}

void dummyfunction(float a1, float a2, float a3, float a4, float a5, float a6, float a7, float a8)
{
}

float expandingbox_sizefactor_from_fadelerp(float fadelerp)
{
	return 1.2 / (1.2 - fadelerp);
}

vector expandingbox_resize_centered_box_offset(float sz, vector boxsize, float boxxsizefactor)
{
	boxsize_x *= boxxsizefactor; // easier interface for text
	return boxsize * (0.5 * (1 - sz));
}

void drawborderlines(float thickness, vector pos, vector dim, vector color, float alpha, float drawflag)
{
	vector line_dim;

	// left and right lines
	pos_x -= thickness;
	line_dim_x = thickness;
	line_dim_y = dim_y;
	drawfill(pos, line_dim, color, alpha, drawflag);
	drawfill(pos + (dim_x + thickness) * '1 0 0', line_dim, color, alpha, drawflag);

	// upper and lower lines
	pos_y -= thickness;
	line_dim_x = dim_x + thickness * 2; // make upper and lower lines longer
	line_dim_y = thickness;
	drawfill(pos, line_dim, color, alpha, drawflag);
	drawfill(pos + (dim_y + thickness) * '0 1 0', line_dim, color, alpha, drawflag);
}

void drawpic_tiled(vector pos, string pic, vector sz, vector area, vector color, float alpha, float drawflag, vector src_pos)
{
	vector current_pos, end_pos, new_size, ratio;
	end_pos = pos + area;

	current_pos_y = pos_y;
	while (current_pos_y < end_pos_y)
	{
		current_pos_x = pos_x;
		while (current_pos_x < end_pos_x)
		{
			new_size_x = min(sz_x, end_pos_x - current_pos_x);
			new_size_y = min(sz_y, end_pos_y - current_pos_y);
			ratio_x = new_size_x / sz_x;
			ratio_y = new_size_y / sz_y;
			drawsubpic(current_pos, new_size, pic, src_pos, ratio,
			           color, alpha, drawflag);
			current_pos_x += sz_x;
		}
		current_pos_y += sz_y;
	}
}

void drawpic_expanding(vector position, string pic, vector scale, vector rgb, float alpha, float flag, float fadelerp)
{
	float sz;
	sz = expandingbox_sizefactor_from_fadelerp(fadelerp);

	drawpic(position + expandingbox_resize_centered_box_offset(sz, scale, 1), pic, scale * sz, rgb, alpha * (1 - fadelerp), flag);
}

void drawpic_expanding_two(vector position, string pic, vector scale, vector rgb, float alpha, float flag, float fadelerp)
{
	drawpic_expanding(position, pic, scale, rgb, alpha, flag, fadelerp);
	drawpic(position, pic, scale, rgb, alpha * fadelerp, flag);
}

void drawstring_expanding(vector position, string text, vector scale, vector rgb, float alpha, float flag, float fadelerp)
{
	float sz;
	sz = expandingbox_sizefactor_from_fadelerp(fadelerp);
    scale = scale * sz;

	dummyfunction(0, 0, 0, 0, 0, 0, 0, 0);
	drawstring(position + expandingbox_resize_centered_box_offset(sz, [stringwidth(text, FALSE, scale), scale_y], 1), text, scale, rgb, alpha * (1 - fadelerp), flag);
}

void drawcolorcodedstring_expanding(vector position, string text, vector scale, float alpha, float flag, float fadelerp)
{
	float sz;
	sz = expandingbox_sizefactor_from_fadelerp(fadelerp);
    scale = scale * sz;

	dummyfunction(0, 0, 0, 0, 0, 0, 0, 0);
	drawcolorcodedstring(position + expandingbox_resize_centered_box_offset(sz, [stringwidth(text, TRUE, scale), scale_y], 1), text, scale, alpha * (1 - fadelerp), flag);
}

void drawrotpic(vector org, float rot, string pic, vector sz, vector hotspot, vector rgb, float a, float f);       

void drawpic_rotated(vector position, string pic, vector sz, vector rgb, float angle, float alpha, float flag) {
	drawrotpic(position + sz * 0.5, angle, pic, sz, sz * 0.5, rgb, alpha, flag);
}

void drawpic_rotated_ex(vector position, string pic, vector sz, vector rgb, float angle, vector hotspot, float alpha, float flag) {
	drawrotpic(position + hotspot, angle, pic, sz, hotspot, rgb, alpha, flag);
}

void loadfont(string slot, string font)
{
	/*if(CVAR(rm_dontmesswithfonts))
	{
		print("Warning: attempted a font change [", slot, " -> ", font, "], denied\n");
		return;
	}*/
	
	localcmd("loadfont ", slot, " gfx/", font, "\n");
}

void URI_Get_Callback(float id, float status, string data)
{
	if(id == URI_GET_IP2C)
	{
		IP2C_URI_Get_Callback(id, status, data);
		return;
	}
}

#define SET_POS_AND_SZ_Y_ASPECT(allow_colors) float textaspect, oldsz; textaspect = stringwidth(text, allow_colors, '1 1 1' * sz_y) / sz_y;	if(sz_x/sz_y > textaspect) { oldsz = sz_x; sz_x = sz_y * textaspect; pos_x += (oldsz - sz_x) * 0.5; } else { oldsz = sz_y; sz_y = sz_x / textaspect; pos_y += (oldsz - sz_y) * 0.5; }

// drawstring wrapper to draw a string as large as possible with preserved aspect ratio into a box
void drawstring_aspect(vector pos, string text, vector sz, vector color, float alpha, float drawflag) {
	SET_POS_AND_SZ_Y_ASPECT(FALSE)
	drawstring(pos, text, '1 1 0' * sz_y, color, alpha, drawflag);
}

// drawstring wrapper to draw a colorcodedstring as large as possible with preserved aspect ratio into a box
void drawcolorcodedstring_aspect(vector pos, string text, vector sz, float alpha, float drawflag) {
	SET_POS_AND_SZ_Y_ASPECT(TRUE)
	drawcolorcodedstring(pos, text, '1 1 0' * sz_y, alpha, drawflag);
}

vector healthcolor(float x) {
    vector c;
    c_z = 0;
    
    x = 200 * (x / sv_nicehealth);
    
    if(x > 600) {
        c_x = 0;
        c_y = 1;
        c_z = 1;
    } else if(x > 200) {
        c_x = 0;
        c_y = 1;
        c_z = (x-200)*0.0025;
    } else if(x > 150) {
        c_x = 0.4 - (x-150)*0.02 * 0.4;
        c_y = 0.9 + (x-150)*0.02 * 0.1;
    } else if(x > 100) {
        c_x = 1 - (x-100)*0.02 * 0.6;
        c_y = 1 - (x-100)*0.02 * 0.1;
        c_z = 1 - (x-100)*0.02;
    } else if(x > 50) {
        c_x = 1;
        c_y = 1;
        c_z = 0.2 + (x-50)*0.02 * 0.8;  
    } else if(x > 20) {
        c_x = 1;
        c_y = (x-20)*90/27/100;
        c_z = (x-20)*90/27/100 * 0.2;
    } else {
        c_x = 1;
        c_y = 0;
    }
    
    return c;
}

float TeamNumber(float t, float d) {
    if(!rm_teamlasers)
        return d;
    
    switch(t) {
        case COLOR_TEAM1:
            return 1;
        case COLOR_TEAM2:
            return 2;
        case COLOR_TEAM3:
            return 3;
        case COLOR_TEAM4:
            return 4;
        default:
            return d;
    }
} 

float rm_particleeffectnum(string p) {
    float n = particleeffectnum(p);
    
    if(n < 0) {
        print("ERROR: RM particle effect ", p, " missing! Will try to use a fallback. Try restarting the game to fix this problem.\n");
        
        switch(p) {
            case "RM_HG_PLASMA_TEAM1":
            case "RM_HG_PLASMA_TEAM2":
            case "RM_HG_PLASMA_TEAM3":
            case "RM_HG_PLASMA_TEAM4":
                return particleeffectnum("TR_NEXUIZPLASMA");
                
            case "RM_HG_PLASMA_SHARD_EXPLODE_TEAM1":
            case "RM_HG_PLASMA_SHARD_EXPLODE_TEAM2":
            case "RM_HG_PLASMA_SHARD_EXPLODE_TEAM3":
            case "RM_HG_PLASMA_SHARD_EXPLODE_TEAM4":
                return particleeffectnum("electro_ballexplode");
            
            case "RM_HG_PLASMA_EXPLODE_TEAM1":
            case "RM_HG_PLASMA_EXPLODE_TEAM2":
            case "RM_HG_PLASMA_EXPLODE_TEAM3":
            case "RM_HG_PLASMA_EXPLODE_TEAM4":
                return particleeffectnum("hookbomb_explode");
            
            case "RM_HG_NAPALM_FIRE_TEAM1":
            case "RM_HG_NAPALM_FIRE_TEAM2":
            case "RM_HG_NAPALM_FIRE_TEAM3":
            case "RM_HG_NAPALM_FIRE_TEAM4":
                return particleeffectnum("fire_big");
            
            case "RM_HG_NAPALM_TRAIL_TEAM1":
            case "RM_HG_NAPALM_TRAIL_TEAM2":
            case "RM_HG_NAPALM_TRAIL_TEAM3":
            case "RM_HG_NAPALM_TRAIL_TEAM4":
                return particleeffectnum("firemine");
            
            case "RM_HEAL":
                return particleeffectnum("electro_impact");
            
            case "RM_EXPLOSION":
            case "RM_MEODP":
                return particleeffectnum("rocket_explode");

            case "RM_ZAPPER_TEAM1":
            case "RM_ZAPPER_TEAM2":
            case "RM_ZAPPER_TEAM3":
            case "RM_ZAPPER_TEAM4":
                return particleeffectnum("TR_NEXUIZPLASMA");

            case "RM_LIGHTNING_TEAM1":
            case "RM_LIGHTNING_TEAM2":
            case "RM_LIGHTNING_TEAM3":
            case "RM_LIGHTNING_TEAM4":
                return -1;

            case "RM_ZAPPER_MUZZLEFLASH_TEAM1":
            case "RM_ZAPPER_MUZZLEFLASH_TEAM2":
            case "RM_ZAPPER_MUZZLEFLASH_TEAM3":
            case "RM_ZAPPER_MUZZLEFLASH_TEAM4":
                return particleeffectnum("electro_muzzleflash");

            case "RM_CRYLINK_TEAM1":
            case "RM_CRYLINK_TEAM2":
            case "RM_CRYLINK_TEAM3":
            case "RM_CRYLINK_TEAM4":
                return particleeffectnum("TR_CRYLINKPLASMA");

            case "RM_CRYLINK_IMPACT_TEAM1":
            case "RM_CRYLINK_IMPACT_TEAM2":
            case "RM_CRYLINK_IMPACT_TEAM3":
            case "RM_CRYLINK_IMPACT_TEAM4":
                return particleeffectnum("crylink_impact");

            case "RM_CRYLINK_IMPACT_BIG_TEAM1":
            case "RM_CRYLINK_IMPACT_BIG_TEAM2":
            case "RM_CRYLINK_IMPACT_BIG_TEAM3":
            case "RM_CRYLINK_IMPACT_BIG_TEAM4":
                return particleeffectnum("crylink_impactbig");

            case "RM_ELECTRO_TEAM1":
            case "RM_ELECTRO_TEAM2":
            case "RM_ELECTRO_TEAM3":
            case "RM_ELECTRO_TEAM4":
                return particleeffectnum("TR_NEXUIZPLASMA");

            case "RM_ELECTRO_IMPACT_TEAM1":
            case "RM_ELECTRO_IMPACT_TEAM2":
            case "RM_ELECTRO_IMPACT_TEAM3":
            case "RM_ELECTRO_IMPACT_TEAM4":
                return particleeffectnum("electro_impact");

            case "RM_ELECTRO_COMBO_TEAM1":
            case "RM_ELECTRO_COMBO_TEAM2":
            case "RM_ELECTRO_COMBO_TEAM3":
            case "RM_ELECTRO_COMBO_TEAM4":
                return particleeffectnum("electro_combo");
        }
    }
    
    return n;
}

#define rm_particleeffectnum_team(p,t,d) rm_particleeffectnum(strcat(p "_TEAM", ftos(TeamNumber(t, d))))

void announce(string v) {
    sound(self, CHAN_VOICE, v, VOL_BASEVOICE, ATTN_NONE);
}

float spiralparticles(entity ent, float effectnum, vector start, vector end, float dist, float phase, float freq, float steplen) {
    vector diff = end - start;
    vector dir = normalize(diff);
    vector o = start;

    vector step = dir * steplen;
    float maxlen = vlen(diff);
    float i, x;

    vectorvectors(dir);

    vector prev = o + dist * (v_up * sin(phase) + v_right * cos(phase));

    for(i = 0; i < maxlen; i += steplen, o += step) {
        x = freq * (i + steplen) + phase;
        vector n = o + dist * (v_up * sin(x) + v_right * cos(x));
        trailparticles(ent, effectnum, prev, n);
        prev = n;
    }

    return x;
}

void ImpactSound(entity e, string sound_path) {
    WarpZone_Sound(e, CHAN_PROJECTILE, sound_path, VOL_BASE, ATTN_NORM);
}

typedef .vector vectorfield;
.void(void) draw2d_real;
.float(void) draw2d_pre;
.vectorfield draw2d_origin_fld;

float draw2d_warpstage;

void Draw2d_ThroughWarpZones(void) {
    var fwd = '0 0 0';
    var drawn = FALSE;
    var org_fld = self.draw2d_origin_fld;

    if(self.draw2d_pre && !self.draw2d_pre())
        return;

    var o = self.org_fld;

    if(!warpzone_chain_begin)
        goto skip;

    for(var wz = warpzone_chain_begin; wz; wz = wz.warpzone_chain) {
        if(fwd == '0 0 0') {
            makevectors(view_angles);
            fwd = v_forward;
        }

        var wo = WarpZone_UnTransformOrigin(wz, o);

        if(fwd * normalize(wo - view_origin) < 0.3) {
            continue;
        }

        WarpZone_TraceLine(view_origin, wo, MOVE_NOMONSTERS, world);

        if(vlen(trace_endpos - o) < 1) {
            self.org_fld = wo;
            draw2d_warpstage = TRUE;
            self.draw2d_real();
            drawn = TRUE;
        }
    }

    self.org_fld = o;
    WarpZone_TraceLine(view_origin, o, MOVE_NOMONSTERS, world);

    if(WarpZone_trace_warpcount)
        return;

    if(drawn && vlen(trace_endpos - o) > 1)
        return;

:skip
    draw2d_warpstage = FALSE;
    self.draw2d_real();
}

vector DrawPlayerStatusIcons(vector pos, float height, float a, float b, float pstat) {
    var scale = [height, height];

    // 1st byte: nadgets
    if(g_nadgets) {
        var nadgets = HG_DecompressDualType(pstat & 0xFF);

        drawpic(pos, HG_TypeToIcon(nadgets_x, FALSE, FALSE), scale, HG_TypeToColor(nadgets_x) * b, a, DRAWFLAG_NORMAL);
        pos_x += scale_x;

        if(g_nadgets_double) {
            drawpic(pos, HG_TypeToIcon(nadgets_y, FALSE, FALSE), scale, HG_TypeToColor(nadgets_y) * b, a, DRAWFLAG_NORMAL);
            pos_x += scale_x;
        }
    }

    // 2nd byte: secondary weapon (with akimbo bit)
    if(g_weaponarena_secondary & (g_weaponarena_secondary - 1)) {
        var wep = (pstat & 0xFF00) / 0x100;
        var akimbo = wep & 0x80;
        wep = wep & 0x7F;

        var winfo = get_weaponinfo(wep);
        var clr = winfo.w_color * b;

        using(drawfont = sbar_rmbigfont)
            drawstring_aspect(pos, winfo.message2, scale, clr, a, DRAWFLAG_NORMAL);

        drawpic(pos,
            if(akimbo)
                "gfx/hud/weapon_icon_border_akimbo"
            else
                "gfx/hud/weapon_icon_border",
            scale, clr, a * 0.8, DRAWFLAG_NORMAL);

        pos_x += scale_x;
    }

    return pos;
}

float GetPlayerStatusIconsWidth(float height) {
    var width = 0;

    // 1st byte: nadgets
    if(g_nadgets) {
        width += height;

        if(g_nadgets_double)
            width += height;
    }

    // 2nd byte: secondary weapon
    if(g_weaponarena_secondary)
        width += height;

    return width;
}

// Shamelessly stolen from xonotic
void DrawCircleClippedPic(vector centre, float radius, string pic, float f, vector rgb, float a, float drawflag)
{
    float x, y, q, d;
    vector ringsize, v, t;
    ringsize = radius * '1 1 0';

    x = cos(f * 2 * M_PI);
    y = sin(f * 2 * M_PI);
    q = fabs(x) + fabs(y);
    x /= q;
    y /= q;

    if(f >= 1)
    {
        // draw full rectangle
        R_BeginPolygon(pic, drawflag);
            v = centre;         t = '0.5 0.5 0';
            v_x += 0.5 * ringsize_x;    t += '0.5 0.5 0';
            R_PolygonVertex(v, t, rgb, a);

            v = centre;         t = '0.5 0.5 0';
            v_y += 0.5 * ringsize_y;    t += '0.5 -0.5 0';
            R_PolygonVertex(v, t, rgb, a);

            v = centre;         t = '0.5 0.5 0';
            v_x -= 0.5 * ringsize_x;    t -= '0.5 0.5 0';
            R_PolygonVertex(v, t, rgb, a);

            v = centre;         t = '0.5 0.5 0';
            v_y -= 0.5 * ringsize_y;    t -= '0.5 -0.5 0';
            R_PolygonVertex(v, t, rgb, a);
        R_EndPolygon();

        d = q - 1;
        if(d > 0)
        {
            R_BeginPolygon(pic, drawflag);
                v = centre;         t = '0.5 0.5 0';
                R_PolygonVertex(v, t, rgb, a);

                v = centre;         t = '0.5 0.5 0';
                v_x += 0.5 * ringsize_x;    t += '0.5 0.5 0';
                R_PolygonVertex(v, t, rgb, a);
        }
    }
    else if(f > 0.75)
    {
        // draw upper and first triangle
        R_BeginPolygon(pic, drawflag);
            v = centre;         t = '0.5 0.5 0';
            v_x += 0.5 * ringsize_x;    t += '0.5 0.5 0';
            R_PolygonVertex(v, t, rgb, a);

            v = centre;         t = '0.5 0.5 0';
            v_y += 0.5 * ringsize_y;    t += '0.5 -0.5 0';
            R_PolygonVertex(v, t, rgb, a);

            v = centre;         t = '0.5 0.5 0';
            v_x -= 0.5 * ringsize_x;    t -= '0.5 0.5 0';
            R_PolygonVertex(v, t, rgb, a);
        R_EndPolygon();
        R_BeginPolygon(pic, drawflag);
            v = centre;         t = '0.5 0.5 0';
            R_PolygonVertex(v, t, rgb, a);

            v = centre;         t = '0.5 0.5 0';
            v_x -= 0.5 * ringsize_x;    t -= '0.5 0.5 0';
            R_PolygonVertex(v, t, rgb, a);

            v = centre;         t = '0.5 0.5 0';
            v_y -= 0.5 * ringsize_y;    t -= '0.5 -0.5 0';
            R_PolygonVertex(v, t, rgb, a);

        d = q - 0.75;
        if(d <= 0)
            R_EndPolygon();
    }
    else if(f > 0.5)
    {
        // draw upper triangle
        R_BeginPolygon(pic, drawflag);
            v = centre;         t = '0.5 0.5 0';
            v_x += 0.5 * ringsize_x;    t += '0.5 0.5 0';
            R_PolygonVertex(v, t, rgb, a);

            v = centre;         t = '0.5 0.5 0';
            v_y += 0.5 * ringsize_y;    t += '0.5 -0.5 0';
            R_PolygonVertex(v, t, rgb, a);

            v = centre;         t = '0.5 0.5 0';
            v_x -= 0.5 * ringsize_x;    t -= '0.5 0.5 0';
            R_PolygonVertex(v, t, rgb, a);
        R_EndPolygon();

        d = q - 0.5;
        if(d > 0)
        {
            R_BeginPolygon(pic, drawflag);
                v = centre;         t = '0.5 0.5 0';
                R_PolygonVertex(v, t, rgb, a);

                v = centre;         t = '0.5 0.5 0';
                v_x -= 0.5 * ringsize_x;    t -= '0.5 0.5 0';
                R_PolygonVertex(v, t, rgb, a);
        }
    }
    else if(f > 0.25)
    {
        // draw first triangle
        R_BeginPolygon(pic, drawflag);
            v = centre;         t = '0.5 0.5 0';
            R_PolygonVertex(v, t, rgb, a);

            v = centre;         t = '0.5 0.5 0';
            v_x += 0.5 * ringsize_x;    t += '0.5 0.5 0';
            R_PolygonVertex(v, t, rgb, a);

            v = centre;         t = '0.5 0.5 0';
            v_y += 0.5 * ringsize_y;    t += '0.5 -0.5 0';
            R_PolygonVertex(v, t, rgb, a);

        d = q - 0.25;
        if(d <= 0)
            R_EndPolygon();
    }
    else
    {
        d = q;
        if(d > 0)
        {
            R_BeginPolygon(pic, drawflag);
                v = centre;         t = '0.5 0.5 0';
                R_PolygonVertex(v, t, rgb, a);

                v = centre;         t = '0.5 0.5 0';
                v_x += 0.5 * ringsize_x;    t += '0.5 0.5 0';
                R_PolygonVertex(v, t, rgb, a);
        }
    }

    if(d > 0)
    {
            v = centre;         t = '0.5 0.5 0';
            v_x += x * 0.5 * ringsize_x;    t += x * '0.5 0.5 0';
            v_y += y * 0.5 * ringsize_y;    t += y * '0.5 -0.5 0';
            R_PolygonVertex(v, t, rgb, a);
        R_EndPolygon();
    }
}

vector ReadShotOriginStat(float stat) {
    var shotorg = decompressShotOrigin(getstati(stat));

    if(shotorg_x > 0)
        shotorg_y = -shotorg_y;
    else
        shotorg = '0 0 0';

    return shotorg;
}
