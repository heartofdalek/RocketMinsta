string sv_player_hat;
.entity hat;

void Boobs_Clear();

float MaySpectate(entity);

.entity specdelay_ent;
.float justconnected;

.entity headent;

void SetClientName(entity cl, string newname, float fixencoding, float iannounce) {
    if(fixencoding)
        newname = fix_legacy_encoding(newname);

    if(cl.netname == newname)
        iannounce = FALSE;

    // FIXME: better way to detect this needed
    if(iannounce && cl.netname != "unconnected")
        IRC_Announce_Name(cl, newname);

    if(cl.netname_strzoned) {
        strunzone(cl.netname_strzoned);
        cl.netname_strzoned = NULL;
    }

    newname = strzone(newname);
    cl.netname_strzoned = newname;
    cl.netname = newname;
}

void SpawnHeadEnt(void) {
    if(self.headent || !CVAR(r_showbboxes))
        return;

    self.headent = spawn() {
        movetype: MOVETYPE_FOLLOW,
        aiment: self,
        think: inline void(void) {
            vector headmins, headmaxs;
            var w = CVAR(g_player_hitbox_head_width_factor);
            var h = CVAR(g_player_hitbox_head_height_factor);
            var o = self.aiment;

            if(!o.iscreature)
                return;

            headmins = [o.mins_x * w, o.mins_y * w, (1 + h) * o.view_ofs_z - h * o.maxs_z];
            headmaxs = [o.maxs_x * w, o.maxs_y * w, o.maxs_z];
            setsize(self, headmins, headmaxs);

            self.nextthink = time;
        },
        nextthink: time
    };
}

float ClientData_Send(entity to, float sf)
{
	if(to != self.owner)
	{
		error("wtf");
		return FALSE;
	}

	entity e;

	e = to.clientcamera;

	sf = 0;

	if(e.race_completed)
		sf |= 1; // forced scoreboard
	if(to.spectatee_status)
		sf |= 2; // spectator ent number follows
	if(e.zoomstate)
		sf |= 4; // zoomed
	if(e.porto_v_angle_held)
		sf |= 8; // angles held

	WriteByte(MSG_ENTITY, ENT_CLIENT_CLIENTDATA);
	WriteByte(MSG_ENTITY, sf);

	if(sf & 2)
		WriteByte(MSG_ENTITY, to.spectatee_status);

	if(sf & 8)
	{
		WriteAngle(MSG_ENTITY, e.v_angle_x);
		WriteAngle(MSG_ENTITY, e.v_angle_y);
	}

	return TRUE;
}

void ClientData_Attach()
{
	Net_LinkEntity(self.clientdata = spawn(), FALSE, 0, ClientData_Send);
	self.clientdata.drawonlytoclient = self;
	self.clientdata.owner = self;
}

void ClientData_Detach()
{
	remove(self.clientdata);
	self.clientdata = world;
}

void ClientData_Touch(entity e)
{
    e.clientdata.SendFlags = 1;
    FOR_EACH_REALCLIENT(var e2) if(e2.clientcamera == e)
        e2.clientdata.SendFlags = 1;
}


#define SPAWNPOINT_SCORE frags

.string netname_previous;

void spawnpoint_teamswap(void) {
    self.team_saved = TeamCount_NextTeam(self.team_saved);
}

void spawnfunc_info_player_survivor (void)
{
	spawnfunc_info_player_deathmatch();
}

void spawnfunc_info_player_start (void)
{
	spawnfunc_info_player_deathmatch();
}

void spawnfunc_info_player_deathmatch (void)
{
    self.classname = "info_player_deathmatch";
    self.teamswap = spawnpoint_teamswap;
    relocate_spawnpoint();
}

void spawnfunc_info_player_intermission (void) {}
void spawnfunc_info_intermission (void) {}

void spawnpoint_use()
{
	if(teams_matter)
	if(have_team_spawns)
	{
		self.team = activator.team;
		some_spawn_has_been_used = 1;
	}
};

// Returns:
//   -1 if a spawn can't be used
//   otherwise, a weight of the spawnpoint
float Spawn_Score(entity spot, entity playerlist, float teamcheck)
{
	float shortest, thisdist;
	entity player;

	// filter out spots for the wrong team
	if(teamcheck)
	if(spot.team != teamcheck)
		return -1;

	if(race_spawns)
		if(spot.target == "")
			return -1;

	if(clienttype(self) == CLIENTTYPE_REAL)
	{
		if(spot.restriction == 1)
			return -1;
	}
	else
	{
		if(spot.restriction == 2)
			return -1;
	}

	// filter out spots for assault
	if(spot.target != "") {
		entity ent;
		float good, found;
		ent = find(world, targetname, spot.target);
		while(ent) {
			if(ent.classname == "target_objective")
			{
				found = 1;
				if(ent.health < 0 || ent.health >= ASSAULT_VALUE_INACTIVE)
					return -1;
				good = 1;
			}
			else if(ent.classname == "trigger_race_checkpoint")
			{
				found = 1;
				if(self.classname == "player") // spectators may spawn everywhere
				{
					if(g_race_qualifying)
					{
						// spawn at first
						if(ent.race_checkpoint != 0)
							return -1;
						if(spot.race_place != race_lowest_place_spawn)
							return -1;
					}
					else
					{
						if(ent.race_checkpoint != race_PreviousCheckpoint(self.race_checkpoint))
							return -1;
						float pl;
						pl = self.race_place;
						if(pl > race_highest_place_spawn)
							pl = 0;
						if(spot.race_place != pl)
							return -1;
					}
				}
				good = 1;
			}
			ent = find(ent, targetname, spot.target);
		}

		if(found && !good)
			return -1;
	}

	player = playerlist;
	shortest = vlen(world.maxs - world.mins);
	for(player = playerlist; player; player = player.chain)
		if (player != self)
		{
			thisdist = vlen(player.origin - spot.origin);
			if (thisdist < shortest)
				shortest = thisdist;
		}
	return shortest;
}

float spawn_allbad;
float spawn_allgood;
entity Spawn_FilterOutBadSpots(entity firstspot, entity playerlist, float mindist, float teamcheck)
{
	entity spot, spotlist, spotlistend;
	spawn_allgood = TRUE;
	spawn_allbad = TRUE;

	spotlist = world;
	spotlistend = world;

	for(spot = firstspot; spot; spot = spot.chain)
	{
		spot.SPAWNPOINT_SCORE = Spawn_Score(spot, playerlist, teamcheck);

		if(CVAR(spawn_debugview))
		{
			setmodel(spot, "models/runematch/rune.mdl");
			if(spot.SPAWNPOINT_SCORE < mindist)
			{
				spot.colormod = '1 0 0';
				spot.scale = 1;
			}
			else
			{
				spot.colormod = '0 1 0';
				spot.scale = spot.SPAWNPOINT_SCORE / mindist;
			}
		}

		if(spot.SPAWNPOINT_SCORE >= 0) // spawning allowed here
		{
			if(spot.SPAWNPOINT_SCORE < mindist)
			{
				// too short distance
				spawn_allgood = FALSE;
			}
			else
			{
				// perfect
				spawn_allbad = FALSE;

				if(spotlistend)
					spotlistend.chain = spot;
				spotlistend = spot;
				if(!spotlist)
					spotlist = spot;
			}
		}
	}
	if(spotlistend)
		spotlistend.chain = world;

	return spotlist;
}

entity Spawn_WeightedPoint_Team(entity firstspot, float lower, float upper, float exponent, float teem)
{
	// weight of a point: bound(lower, mindisttoplayer, upper)^exponent
	// multiplied by spot.cnt (useful if you distribute many spawnpoints in a small area)
	entity spot;
	float considerations;
	considerations = 0;

	RandomSelection_Init();
	for(spot = firstspot; spot; spot = spot.chain)
	{
		if(self.last_spawn_pt_1 != spot && self.last_spawn_pt_2 != spot && (teem < 0 || spot.team == teem))
			RandomSelection_Add(spot, 0, NULL, pow(bound(lower, spot.SPAWNPOINT_SCORE, upper), exponent) * spot.cnt, spot.SPAWNPOINT_SCORE >= lower);
		considerations += 1;
	}
	if(!considerations) // if we didn't like the options...
		if(self.last_spawn_pt_1 == spot && spot.chain) // if we can, try to take 2nd opt.
			RandomSelection_Add(firstspot.chain, 0, NULL, pow(bound(lower, firstspot.chain.SPAWNPOINT_SCORE, upper), exponent) * firstspot.chain.cnt, firstspot.chain.SPAWNPOINT_SCORE >= lower);
		else
			RandomSelection_Add(firstspot, 0, NULL, pow(bound(lower, firstspot.SPAWNPOINT_SCORE, upper), exponent) * firstspot.cnt, firstspot.SPAWNPOINT_SCORE >= lower);

	self.last_spawn_pt_2 = self.last_spawn_pt_1;
	self.last_spawn_pt_1 = RandomSelection_chosen_ent;
	return RandomSelection_chosen_ent;
}

entity Spawn_WeightedPoint(entity firstspot, float lower, float upper, float exponent) {
	return Spawn_WeightedPoint_Team(firstspot, lower, upper, exponent, -1);
}

/*
=============
SelectSpawnPoint

Finds a point to respawn
=============
*/

entity global_spawnpoint;
float noclosetoteam;

entity SelectSpawnPoint (float anypoint)
{
	float teamcheck, closetoteam;
	entity firstspot_new, e;
	entity spot, firstspot, playerlist;

	float randspawns, closetoteam_cvar;
	randspawns = CVAR(sv_randomspawns);
	closetoteam_cvar = CVAR(g_spawnclosetoteam);
	
	if(!global_spawnpoint)
		global_spawnpoint = spawn();

	if(randspawns == 2)
	{
		MoveToRandomMapLocation(global_spawnpoint, DPCONTENTS_SOLID | DPCONTENTS_CORPSE | DPCONTENTS_PLAYERCLIP, DPCONTENTS_SLIME | DPCONTENTS_LAVA | DPCONTENTS_SKY | DPCONTENTS_BODY | DPCONTENTS_DONOTENTER, Q3SURFACEFLAG_SKY, 10, 30, 0);
		return global_spawnpoint;
	}
	
	spot = find (world, classname, "testplayerstart");
	if (spot)
		return spot;

	teamcheck = 0;

	if(!anypoint && have_team_spawns)
		teamcheck = self.team;

	closetoteam = 1;
	if(noclosetoteam)
	{
		closetoteam = 0;
		noclosetoteam = 0;
	}
	
	if(!closetoteam_cvar)
		closetoteam = 0;
	if(closetoteam_cvar < 2)
	if(have_team_spawns)
		closetoteam = 0;

	// get the list of players
	playerlist = findchain(classname, "player");
	// get the entire list of spots
	firstspot = findchain(classname, "info_player_deathmatch");
	// filter out the bad ones
	// (note this returns the original list if none survived)
	if(anypoint)
	{
		spot = Spawn_WeightedPoint(firstspot, 1, 1, 1);
	}
	else if(teams_matter && closetoteam)
	{
		entity md_point, md_player, md_tmp_point, md_tmp_player;
		float mdst, tmplen, minlen, minenemylen, spawnfailed;
		mdst = -1;
		float i;
		
		float cvar_mindist_team = CVAR(g_spawnclosetoteam_mindist_team);
		float cvar_mindist_enemies = CVAR(g_spawnclosetoteam_mindist_enemies);

		for(i = 0; i < 2; ++i)
		{
			for(spot = firstspot; spot; spot = spot.chain) if(!teamcheck || spot.team == teamcheck)
			{
				tmplen = 0;
				md_tmp_player = md_tmp_point = world;
				minlen = minenemylen = -1;
				
				FOR_EACH_PLAYER(e) if(e.team != self.team)
				{
					tmplen = vlen(e.origin - spot.origin);
					if(minenemylen < 0 || tmplen < minenemylen)
						minenemylen = tmplen;
				}
				
				if(!i)
				if(minenemylen < cvar_mindist_enemies)
				{
					//bsprint(self, "^xA06TOO CLOSE TO ENEMY\n");
					continue;
				}
				
				FOR_EACH_PLAYER(e) if(e.team == self.team) if(e != self)
				{
					tmplen = vlen(e.origin - spot.origin);
					
					if(minlen < 0)
						minlen = tmplen;
					
					if(tmplen > minlen)
						continue;

					// try to avoid points with players spawned
					if(!i)
					{
						if(tmplen < cvar_mindist_team)
						{
							spawnfailed = TRUE;
							break;
						}
					}
					
					if(tmplen <= minlen)
					{
						minlen = tmplen;
						md_tmp_player = e;
						md_tmp_point  = spot;
					}
				}
				
				if(spawnfailed)
				{
					spawnfailed = FALSE;
					continue;
				}

				if(mdst == -1 || minlen < mdst)
				{
					mdst = minlen;
					md_player = md_tmp_player;
					md_point = md_tmp_point;

				}
			}
			
			if(!i && md_point) // if this fails, will try again without the already-spawned-players check
                break;

			minlen = -1;
		}
		
		// if even that fails, fall back to normal spawning method
		if(!md_point) {
			noclosetoteam = 1;
			return SelectSpawnPoint(anypoint);
		} else
			return md_point;
	}
	else
	{
		firstspot_new = Spawn_FilterOutBadSpots(firstspot, playerlist, 100, teamcheck);
		if(!firstspot_new)
			firstspot_new = Spawn_FilterOutBadSpots(firstspot, playerlist, -1, teamcheck);
		firstspot = firstspot_new;

		// there is 50/50 chance of choosing a random spot or the furthest spot
		// (this means that roughly every other spawn will be furthest, so you
		// usually won't get fragged at spawn twice in a row)
		if (arena_roundbased)
		{
			firstspot_new = Spawn_FilterOutBadSpots(firstspot, playerlist, 800, teamcheck);
			if(firstspot_new)
				firstspot = firstspot_new;
			spot = Spawn_WeightedPoint(firstspot, 1, 1, 1);
		}
		else if (random() > CVAR(g_spawn_furthest))
			spot = Spawn_WeightedPoint(firstspot, 1, 1, 1);
		else
			spot = Spawn_WeightedPoint(firstspot, 1, 5000, 5); // chooses a far far away spawnpoint
	}

	if(CVAR(spawn_debugview))
	{
		print("spot mindistance: ", ftos(spot.SPAWNPOINT_SCORE), "\n");

		if(teamcheck)
			for(e = firstspot; e; e = e.chain)
				if(e.team != teamcheck)
					error("invalid spawn found");
	}

	if(!spot) if(randspawns)
	{
		MoveToRandomMapLocation(global_spawnpoint, DPCONTENTS_SOLID | DPCONTENTS_CORPSE | DPCONTENTS_PLAYERCLIP, DPCONTENTS_SLIME | DPCONTENTS_LAVA | DPCONTENTS_SKY | DPCONTENTS_BODY | DPCONTENTS_DONOTENTER, Q3SURFACEFLAG_SKY, 10, 30, 0);
		spot = global_spawnpoint;
	}

	if (!spot)
	{
		if(CVAR(spawn_debug))
			GotoNextMap();
		else
		{
			if(some_spawn_has_been_used)
				return world; // team can't spawn any more, because of actions of other team
			else
			{
				//error("Cannot find a spawn point - please fix the map!");
				bprint("\x01^1* Cannot find a spawn point! ^7Forced endmatch.\n");
				end_match(1);
				return world;
			}
		}
	}

	return spot;
}

#ifdef RM_SUPPORT_GHOST_OBSERVERS
void MakeObserverGhost(void) {
    setmodel(self, "models/player/ayumi.md3");
    self.frame = 48;
    self.skinindex = 11;
    self.skin = 11;
    self.colormap = 0;
}
#endif

/*
=============
CheckPlayerModel

Checks if the argument string can be a valid playermodel.
Returns a valid one in doubt.
=============
*/
string FallbackPlayerModel = "models/player/marine.zym";
string CheckPlayerModel(string plyermodel) {
	if(strlen(plyermodel) < 4)
		return FallbackPlayerModel;
	if( substring(plyermodel,0,14) != "models/player/")
		return FallbackPlayerModel;
	else if(CVAR(sv_servermodelsonly))
	{
		if(substring(plyermodel,-4,4) != ".zym")
		if(substring(plyermodel,-4,4) != ".dpm")
		if(substring(plyermodel,-4,4) != ".md3")
		if(substring(plyermodel,-4,4) != ".psk")
			return FallbackPlayerModel;
		// forbid the LOD models
		if(substring(plyermodel, -9,5) == "_lod1")
			return FallbackPlayerModel;
		if(substring(plyermodel, -9,5) == "_lod2")
			return FallbackPlayerModel;
		if(plyermodel != strtolower(plyermodel))
			return FallbackPlayerModel;
		if(!fexists(plyermodel))
			return FallbackPlayerModel;
	}
	return plyermodel;
}

float Client_CalculateAlpha(entity plr, entity viewer) {
    plr = Akimbo_Owner(plr);

    if(!plr.iscreature) {
        if(plr.classname == "observer") {
            if(plr == viewer)
                return 1;

            if(!viewer.client_dprmversion)
                return -1;

            if(viewer.classname == "observer" || viewer.classname == "spectator" || Buffs_Present(viewer, BUFF_MEODP))
                return 1;

            return -1;
        }

        if(plr.classname == "spectator")
            return -1;
    }

    if(PlayerIsDead(plr))
        return 1;

    var sa = 1 - plr.hg_stealthalpha;
    var viewerIsPlr = (plr == viewer.clientcamera);

    if(Buffs_Present(plr, BUFF_STEALTH))
        sa *= (1 - (1 - CVAR(g_buffs_stealth_alpha)) * bound(0, (time - plr.buff_stealth_time) / CVAR(g_buffs_stealth_regaintime), 1));

    if(viewer && !viewerIsPlr) {
        if((teams_matter && viewer.team == plr.team) || 
           (viewer.hg_stealth && (!Buffs_Present(plr, BUFF_ADEPT) || Buffs_Present(viewer, BUFF_ADEPT))) ||
           !viewer.iscreature)
            sa = 0.3 + 0.7 * sa;
    }

    if(viewerIsPlr && sa < 0.01)
        sa = 0.01;
    else if(sa <= 0)
        sa = -1;

    return sa;
}

/*
=============
Client_customizeentityforclient

LOD reduction
=============
*/

void Client_uncustomizeentityforclient()
{
	if(self.modelindex == 0) // no need to uncustomize then
		return;
	self.modelindex = self.modelindex_lod0;
	self.skin = self.skinindex;
}

float Client_customizeentityforclient()
{
    entity modelsource;
    
    self.alpha = Client_CalculateAlpha(self, other) * default_player_alpha;
    
    if(self.alpha < 0)
        return FALSE;

	if(self.modelindex == 0)
		return TRUE;

	// forcemodel stuff

#ifdef PROFILING
	float t0;
	t0 = gettime(GETTIME_HIRES); // reference
#endif

	modelsource = self;

#ifdef ALLOW_FORCEMODELS
	if(other.cvar_cl_forceplayermodelsfromnexuiz)
		if not(self.modelindex_lod0_from_nexuiz)
			modelsource = other;
	if(other.cvar_cl_forceplayermodels && sv_clforceplayermodels)
		modelsource = other;
#endif

    other = other.clientcamera;
	self.skin = modelsource.skinindex;

	// self: me
	// other: the player viewing me
	float distance;
	float f;

	if(other.cvar_cl_playerdetailreduction <= 0)
	{
		if(other.cvar_cl_playerdetailreduction <= -2)
			self.modelindex = modelsource.modelindex_lod2;
		else if(other.cvar_cl_playerdetailreduction <= -1)
			self.modelindex = modelsource.modelindex_lod1;
		else
			self.modelindex = modelsource.modelindex_lod0;
	}
	else
	{
		distance = vlen(self.origin - other.origin);
		f = (distance + 100.0) * other.cvar_cl_playerdetailreduction;
		if(f > sv_loddistance2)
			self.modelindex = modelsource.modelindex_lod2;
		else if(f > sv_loddistance1)
			self.modelindex = modelsource.modelindex_lod1;
		else
			self.modelindex = modelsource.modelindex_lod0;
	}

#ifdef PROFILING
	float t1;
	t1 = gettime(GETTIME_HIRES); // reference
	client_cefc_accumulator += (t1 - t0);
#endif

    if(self.clientcamera != self && other != self)
        self.angles_y = self.pspec_oldvangle_y;

    return TRUE;
}

void UpdatePlayerSounds();
void setmodel_lod(entity e, string modelname)
{
	string s;

	if(sv_loddistance1)
	{
		// FIXME: this only supports 3-letter extensions
		s = strcat(substring(modelname, 0, strlen(modelname)-4), "_lod1", substring(modelname, -4, 4));
		if(fexists(s))
		{
			setmodel(e, s); // players have high precision
			self.modelindex_lod1 = self.modelindex;
		}
		else
			self.modelindex_lod1 = -1;

		s = strcat(substring(modelname, 0, strlen(modelname)-4), "_lod2", substring(modelname, -4, 4));
		if(fexists(s))
		{
			setmodel(e, s); // players have high precision
			self.modelindex_lod2 = self.modelindex;
		}
		else
			self.modelindex_lod2 = -1;

		precache_model(modelname);
		setmodel(e, modelname); // players have high precision
		self.modelindex_lod0 = self.modelindex;

		if(self.modelindex_lod1 < 0)
			self.modelindex_lod1 = self.modelindex;

		if(self.modelindex_lod2 < 0)
			self.modelindex_lod2 = self.modelindex;
	}
	else
	{
		precache_model(modelname);
		setmodel(e, modelname); // players have high precision
		self.modelindex_lod0 = self.modelindex;
			// save it for possible player model forcing
	}

	s = whichpack(self.model);
	self.modelindex_lod0_from_nexuiz = ((s == "") || (substring(s, 0, 4) == "data"));

	player_setupanimsformodel();
	UpdatePlayerSounds();
}

/*
=============
PutObserverInServer

putting a client as observer in the server
=============
*/
void FixPlayermodel();
void PutObserverInServer (void)
{
	entity	spot;

	race_PreSpawnObserver();

	spot = SelectSpawnPoint (TRUE);
	//if(!spot)
	//	error("No spawnpoints for observers?!?\n");
	RemoveGrapplingHook(self); // Wazat's Grappling Hook
    
    self.hg_linker = world;
    self.buffs = 0;
    
	if(clienttype(self) == CLIENTTYPE_REAL)
        self.clientcamera = self;

    if(!self.justconnected) {
        kh_Key_DropAll(self, TRUE);
        Freeze_Hook_PlayerQuits();
        HG_GenericProjectile_DetonateAll(self, TRUE);
        JB_RemovePlayer();
        Portal_ClearAll(self);
        Boobs_Clear();
    }
	
	if(self.flagcarried)
		DropFlag(self.flagcarried, world, world);
	if(self.ballcarried)
		DropBall(self.ballcarried, self.origin + self.ballcarried.origin, self.velocity);

	WaypointSprite_PlayerDead();

	if(self.killcount != -666)
	{
		if(g_lms)
		{
			if(PlayerScore_Add(self, SP_LMS_RANK, 0) > 0)
				bprint ("^4", self.netname, "^4 has no more lives left\n");
			else
				bprint ("^4", self.netname, "^4 is spectating now\n"); // TODO turn this into a proper forfeit?
		}
	}
    
    PlayerScore_Clear(self, FALSE); // clear scores when needed

    if(g_nadgets) {
        if(!self.joinqueue)
            self.hg_type1_picked = self.hg_type2_picked = 0;
        self.hg_type1 = self.hg_type2 = 0;
        self.hg_nadesused = 0;
        self.hg_shield = 0;
    }

    if(!self.joinqueue) {
        self.w_secondary = 0;
        self.w_secondary_picked = 0;
        self.w_secondary_nextround = 0;
    }

    self.frozenrow = 0;
    self.jb_unlock_progress = 0;
    self.jb_message = JBMSG_NONE;
    self.revprogress = 0;
    
    self.wasingame = FALSE;
	self.spectatortime = time;
    
	self.classname = "observer";
	self.iscreature = FALSE;
	self.health = -666;
	self.takedamage = DAMAGE_NO;
	self.solid = SOLID_NOT;
	self.flags = FL_CLIENT | FL_NOTARGET;
	self.armorvalue = 666;
	self.effects = 0;
	self.armorvalue = CVAR(g_balance_armor_start);
	self.pauserotarmor_finished = 0;
	self.pauserothealth_finished = 0;
	self.pauseregen_finished = 0;
	self.damageforcescale = 0;
	self.death_time = 0;
	self.dead_frame = 0;
	self.alpha = 0;
	self.scale = 0;
	self.fade_time = 0;
	self.pain_frame = 0;
	self.pain_finished = 0;
	self.strength_finished = 0;
	self.invincible_finished = 0;
	self.pushltime = 0;
	self.think = SUB_Null;
	self.nextthink = 0;
	self.hook_time = 0;
    self.last_spawn_pt_1 = world;
    self.last_spawn_pt_2 = world;
	self.deadflag = DEAD_NO;
	self.angles = spot.angles;
	self.angles_z = 0;
	self.fixangle = TRUE;
	self.crouch = FALSE;
    self.clipgroup = CLIPGROUP_OBSERVER;

    if(CVAR(sv_clipped_observers)) {
        self.movetype = MOVETYPE_FLY;
        self.dphitcontentsmask = DPCONTENTS_SOLID | DPCONTENTS_BODY | DPCONTENTS_PLAYERCLIP;
    } else {
        self.movetype = MOVETYPE_NOCLIP;
        self.dphitcontentsmask = 0;
    }

	self.view_ofs = PL_VIEW_OFS;
	setorigin (self, spot.origin);
	self.prevorigin = self.origin;
	self.items = 0;
	self.weapons = 0;
	self.model = "";
	FixPlayermodel();
	self.model = "";
	self.modelindex = 0;
	self.weapon = 0;
	self.weaponmodel = "";
	self.weaponentity = world;
	self.exteriorweaponentity = world;
	self.killcount = -666;
	self.velocity = '0 0 0';
	self.avelocity = '0 0 0';
	self.punchangle = '0 0 0';
	self.punchvector = '0 0 0';
	self.oldvelocity = self.velocity;
	self.fire_endtime = -1;

    Akimbo_Clear(self);

	if(sv_loddistance1)
		SetCustomizer(self, Client_customizeentityforclient, Client_uncustomizeentityforclient);

    self.team = -1;

	if(g_arena)
	{
		if(self.version_mismatch)
		{
			Spawnqueue_Unmark(self);
			Spawnqueue_Remove(self);
		}
		else
		{
			Spawnqueue_Insert(self);
		}
	}
	else if(g_lms)
	{
		// Only if the player cannot play at all
		if(PlayerScore_Add(self, SP_LMS_RANK, 0) == 666)
			self.frags = FRAGS_SPECTATOR;
		else
			self.frags = FRAGS_LMS_LOSER;
	}
	else
		self.frags = FRAGS_SPECTATOR;
    
    self.justconnected = FALSE;
    Buffs_MEODP_Point_Detach(self);
    CA_PlayerLeaves();
    HG_RemoveAll(self);

#ifdef RM_SUPPORT_GHOST_OBSERVERS
    if(CVAR(sv_ghost_observers))
        MakeObserverGhost();
#endif

    if(CVAR(sv_clipped_observers))
        setsize(self, PL_MIN, PL_MAX);
    else
        setsize(self, '0 0 0', '0 0 0');
}

float RestrictSkin(float s)
{
	if(!teams_matter)
		return s;
	if(s == 6)
		return 6;
	return mod(s, 3);
}

.string forcedmodel;
.float forcedskin;
.float forcedbrightness;

void FixPlayermodel()
{
	string defaultmodel;
	float defaultskin, chmdl, oldskin;
	vector m1, m2;

	defaultmodel = "";

    if(!self.iscreature) {
        defaultmodel = "models/player/ayumi.md3";
        defaultskin = 11;
    } else if(self.forcedmodel) {
        defaultmodel = self.forcedmodel;
        defaultskin = self.forcedskin;
    } else if(CVAR(sv_defaultcharacter) == 1) {
		defaultskin = 0;

		if(teams_matter)
		{
			defaultmodel = cvar_string(strcat("sv_defaultplayermodel_", Team_ColorNameLowerCase(self.team)));
			defaultskin = cvar(strcat("sv_defaultplayerskin_", Team_ColorNameLowerCase(self.team)));
		}

		if(defaultmodel == "")
		{
			defaultmodel = CVAR_STR(sv_defaultplayermodel);
			defaultskin = CVAR(sv_defaultplayerskin);
		}
	}

	if(self.modelindex == 0 && self.deadflag == DEAD_NO)
	{
		if(self.model != "")
			bprint("\{1}^1Player ", self.netname, "^1 has a zero modelindex, trying to fix...\n");
		self.model = ""; // force the != checks to return true
	}

	if(defaultmodel != "")
	{
		if (defaultmodel != self.model)
		{
			m1 = self.mins;
			m2 = self.maxs;
			setmodel_lod(self, defaultmodel);
			setsize(self, m1, m2);
			chmdl = TRUE;
		}

		oldskin = self.skinindex;
		self.skinindex = defaultskin;
	} else {
		if (self.playermodel != self.model)
		{
			self.playermodel = CheckPlayerModel(self.playermodel);
			m1 = self.mins;
			m2 = self.maxs;
			setmodel_lod(self, self.playermodel);
			setsize(self, m1, m2);
			chmdl = TRUE;
		}

		oldskin = self.skinindex;
		self.skinindex = RestrictSkin(stof(self.playerskin));
	}

	if(chmdl || oldskin != self.skinindex)
		self.species = player_getspecies(); // model or skin has changed

	if(!teams_matter)
		if(CVAR_STR(sv_defaultplayercolors) != "")
			if(self.clientcolors != stof(CVAR_STR(sv_defaultplayercolors)))
				setcolor(self, stof(CVAR_STR(sv_defaultplayercolors)));
}

void PlayerTouchExplode(entity p1, entity p2)
{
	vector org;
	org = (p1.origin + p2.origin) * 0.5;
	org_z += (p1.mins_z + p2.mins_z) * 0.5;

	te_explosion(org);

	entity e;
	e = spawn();
	setorigin(e, org);
	RadiusDamage(e, world, g_touchexplode_damage, g_touchexplode_edgedamage, g_touchexplode_radius, world, g_touchexplode_force, DEATH_TOUCHEXPLODE, world);
	remove(e);
}

// ======================================== //

.entity boob_left, boob_right;

#define BOOBS_SIZE 4
#define BOOBS_POS 	'6.5 0 30'
#define BOOBS_DIST 	'2 5 0'

void Boobs_DropBoob(entity boob, vector force) {
	setattachment(boob, world, "");
	setorigin(boob, boob.owner.origin + boob.oldorigin);
	boob.velocity = 100 * ('1 0 0' * crandom() + '0 1 0' * crandom() + '0 0 2' + '0 0 1' * random()) + force * 2;
	boob.movetype = MOVETYPE_BOUNCE;
	boob.avelocity = randomvec();
	boob.owner = world;
}

void Boobs_ClearFor(entity plr, vector force) {
	if(plr.boob_left)		Boobs_DropBoob(self.boob_left, force);
	if(plr.boob_right)		Boobs_DropBoob(self.boob_right, force);
	plr.boob_left = plr.boob_right = world;
	if(plr.hat) {
		plr.hat.nextthink = time + CVAR(sv_player_hat_drop_lifetime);
		plr.hat.think = plr.hat.reset = SUB_Remove;
		Boobs_DropBoob(plr.hat, force);
		plr.hat = world;
	}
}

void Boobs_Clear() {
	Boobs_ClearFor(self, '0 0 0');
}

void Boobs_DropAll(vector force) {
	Boobs_ClearFor(self, force);
}

void Boob_Think() {
	if(self.owner) {
		self.alpha = self.owner.alpha;
		if(self.owner.movement_x || self.owner.movement_y)
			setorigin(self, self.oldorigin + '0 0 1' * sin(time * 10 + self.cnt));
	} else if(self.velocity_x || self.velocity_y || self.velocity_z) {
		self.avelocity = normalize(self.avelocity) * vlen(self.velocity);
	} else {
		SUB_SetFade(self, time + 10, 2);
		return;
	}
	
	self.nextthink = time + 0.1;
}

void Boob_Damage(entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force) {
	self.velocity_z += vlen(force) * 0.7;
}

entity Boobs_SpawnBoob(entity p, float dir) {
	entity boob = spawn();
	boob.classname = "boob";
	boob.modelscale = boob.scale = BOOBS_SIZE;
	boob.model = "models/boob.mdl";
	boob.alpha = 1;
	boob.owner = p;
	boob.angles = vectoangles('0 0 -0.5');
	boob.think = Boob_Think;
	boob.nextthink = time;
	boob.cnt = dir;
	boob.effects = EF_NOSHADOW | EF_LOWPRECISION;
	boob.takedamage = DAMAGE_AIM;
	boob.solid = SOLID_CORPSE;
	boob.event_damage = Boob_Damage;
	boob.damageforcescale = 3;
	
	setattachment(boob, p, "");
	setorigin	 (boob, BOOBS_POS + BOOBS_DIST * dir);
	setmodel(boob, boob.model);
	boob.mins_z = -5;
	boob.maxs_z = +5;
	boob.mins_x = boob.mins_y = -5;
	boob.maxs_x = boob.maxs_y = +5;
	boob.oldorigin = boob.origin;
	
	return boob;
}

void Boobs_Attach() {
	if(self.boob_left)	remove(self.boob_left);
	if(self.boob_right)	remove(self.boob_right);
	
	if (CVAR(g_boobs)) {
		self.boob_left  = Boobs_SpawnBoob(self, -1);
		self.boob_right = Boobs_SpawnBoob(self, +1);
	}
	string s = CVAR(sv_player_hat);
	if (s != "") {
		if (sv_player_hat != s) {
			if (sv_player_hat != "")
				strunzone(sv_player_hat);

			sv_player_hat = strzone(s);
		}
		if not(self.hat)
			self.hat = spawn();

		setmodel(self.hat, sv_player_hat);
		self.hat.scale = CVAR(sv_player_hat_scale);
		setattachment(self.hat, self, CVAR_STR(sv_player_hat_attachment));
		self.hat.angles = CVAR_VEC(sv_player_hat_angles);
		self.hat.owner = self;
		setorigin(self.hat, CVAR_VEC(sv_player_hat_origin));
	}
}

void Boobs_DropAllAndRespawn(vector force) {
	Boobs_DropAll(force);
	Boobs_Attach();
}

// ======================================== //

void SetPlayerClipGroup(entity plr, float force_team_clip) {
    if(!teams_matter || !CVAR(g_player_dont_block_teammates))
        force_team_clip = TRUE;

    plr.clipgroup = CLIPGROUP_PLAYER;

    if(force_team_clip)
        plr.clipgroup |= CLIPGROUP_PLAYERMASK(plr);
    else
        plr.clipgroup |= CLIPGROUP_TEAMMASK(plr.team);
}

/*
=============
PutClientInServer

Called when a client spawns in the server
=============
*/

void PutClientInServer (void)
{
	if(clienttype(self) == CLIENTTYPE_BOT)
		self.classname = "player";
	else if(clienttype(self) == CLIENTTYPE_REAL)
        self.clientcamera = self;

	// player is dead and becomes observer
	// FIXME fix LMS scoring for new system
	if(g_lms)
	{
		if(PlayerScore_Add(self, SP_LMS_RANK, 0) > 0)
			self.classname = "observer";
	}

    self.clipgroup = CLIPGROUP_NONE;
    self.w_spread_indicator = -1;
    self.w_spread_indicator2 = -1;

    self.hg_plasmalock = 0;
    self.hg_wasstealth = FALSE;
    self.hg_stealth_saved = 0;
    self.hg_linker = world;
    self.buff_cdoverride = 0;
    self.goodhits = 0;
    
    self.hg_shield_stored = 0;
    self.hg_stealth = 0;
    self.hg_shieldstat = 0;

    Akimbo_Clear(self);

    self.w_pickup_confirmation_stat = 0;

    self.colormap = num_for_edict(self);

	if(g_arena)
	if(!self.spawned)
		self.classname = "observer";

	if(gameover)
		self.classname = "observer";

	if(self.classname == "player") {
		entity spot, oldself;
		float j;

		if(self.team < 0)
			JoinBestTeam(self, FALSE, TRUE);

		race_PreSpawn();

		spot = SelectSpawnPoint (FALSE);
		if(!spot)
		{
			centerprint_spec(self, "Sorry, no spawnpoints available!\nHope your team can fix it...");
			return; // spawn failed
		}
        
		RemoveGrapplingHook(self); // Wazat's Grappling Hook

		self.classname = "player";
		self.wasplayer = TRUE;
		self.iscreature = TRUE;
		self.movetype = MOVETYPE_WALK;
		self.solid = SOLID_SLIDEBOX;
		self.dphitcontentsmask = DPCONTENTS_SOLID | DPCONTENTS_BODY | DPCONTENTS_PLAYERCLIP;
		self.frags = FRAGS_PLAYER;
		if(independent_players)
			MAKE_INDEPENDENT_PLAYER(self);
		self.flags = FL_CLIENT;
		self.takedamage = DAMAGE_AIM;
		if(g_minstagib)
			self.effects = EF_FULLBRIGHT;
		else
			self.effects = 0;
		self.air_finished = time + 12;
		self.dmg = 2;

		if(inWarmupStage)
		{
			self.ammo_shells = warmup_start_ammo_shells;
			self.ammo_nails = warmup_start_ammo_nails;
			self.ammo_rockets = warmup_start_ammo_rockets;
			self.ammo_cells = warmup_start_ammo_cells;
			self.ammo_fuel = warmup_start_ammo_fuel;
			self.health = warmup_start_health;
			self.armorvalue = warmup_start_armorvalue;
			self.weapons = warmup_start_weapons;
		}
		else
		{
			self.ammo_shells = start_ammo_shells;
			self.ammo_nails = start_ammo_nails;
			self.ammo_rockets = start_ammo_rockets;
			self.ammo_cells = start_ammo_cells;
			self.ammo_fuel = start_ammo_fuel;
			self.health = start_health;
			self.armorvalue = start_armorvalue;
			self.weapons = start_weapons;
		}

		if(g_weaponarena_random)
			self.weapons = randombits(self.weapons, g_weaponarena_random, FALSE);

		self.items = start_items;
		self.switchweapon = w_getbestweapon(self);
		self.cnt = self.switchweapon;
		self.weapon = 0;
		self.jump_interval = time;

		self.spawnshieldtime = time + CVAR(g_spawnshieldtime);
		self.pauserotarmor_finished = time + CVAR(g_balance_pause_armor_rot_spawn);
		self.pauserothealth_finished = time + CVAR(g_balance_pause_health_rot_spawn);
		self.pauserotfuel_finished = time + CVAR(g_balance_pause_fuel_rot_spawn);
		self.pauseregen_finished = time + CVAR(g_balance_pause_health_regen_spawn);
		//extend the pause of rotting if client was reset at the beginning of the countdown
		if(!CVAR(sv_ready_restart_after_countdown) && time < game_starttime) { // TODO why is this cvar NOTted?
			self.spawnshieldtime += game_starttime - time;
			self.pauserotarmor_finished += game_starttime - time;
			self.pauserothealth_finished += game_starttime - time;
			self.pauseregen_finished += game_starttime - time;
		}
		self.damageforcescale = 2;
		self.death_time = 0;
		self.dead_frame = 0;
		self.alpha = 0;
		self.scale = 0;
		self.fade_time = 0;
		self.pain_frame = 0;
		self.pain_finished = 0;
		self.strength_finished = 0;
		self.invincible_finished = 0;
		self.pushltime = 0;
		// players have no think function
		self.think = SUB_Null;
		self.nextthink = 0;
		self.hook_time = 0;
		self.dmg_team = 0;

		self.metertime = 0;

		self.last_spawn_pt_1 = world;
		self.last_spawn_pt_2 = world;

		self.deadflag = DEAD_NO;

		self.angles = spot.angles;

		self.angles_z = 0; // never spawn tilted even if the spot says to
		self.fixangle = TRUE; // turn this way immediately
		self.velocity = '0 0 0';
		self.avelocity = '0 0 0';
		self.punchangle = '0 0 0';
		self.punchvector = '0 0 0';
		self.oldvelocity = self.velocity;
		self.fire_endtime = -1;

		msg_entity = self;
		WRITESPECTATABLE_MSG_ONE({
			WriteByte(MSG_ONE, SVC_TEMPENTITY);
			WriteByte(MSG_ONE, TE_CSQC_SPAWN);
		});

		if(sv_loddistance1)
			SetCustomizer(self, Client_customizeentityforclient, Client_uncustomizeentityforclient);

		self.model = "";
		FixPlayermodel();

		self.crouch = FALSE;
		self.view_ofs = PL_VIEW_OFS;
		setsize (self, PL_MIN, PL_MAX);
		self.spawnorigin = spot.origin;
		setorigin (self, spot.origin + '0 0 1' * (1 - self.mins_z - 24));
		// don't reset back to last position, even if new position is stuck in solid
		self.oldorigin = self.origin;
		self.prevorigin = self.origin;
		self.lastrocket = world; // stop rocket guiding, no revenge from the grave!

		if(g_arena)
		{
			Spawnqueue_Remove(self);
			Spawnqueue_Mark(self);
		}

		self.event_damage = PlayerDamage;

		self.bot_attack = TRUE;

		self.statdraintime = time + 5;
		self.BUTTON_ATCK = self.BUTTON_JUMP = self.BUTTON_ATCK2 = 0;

		if(self.killcount == -666) {
			PlayerScore_Clear(self, FALSE);
			self.killcount = 0;
		}

		self.cnt = WEP_LASER;
		self.nixnex_lastchange_id = -1;

		CL_SpawnWeaponentity();
		self.alpha = default_player_alpha;
		self.colormod = '1 1 1' * (if(self.forcedbrightness) self.forcedbrightness else CVAR(g_player_brightness));
		self.exteriorweaponentity.alpha = default_weapon_alpha;

		self.lms_nextcheck = time + CVAR(g_lms_campcheck_interval)*2;
		self.lms_traveled_distance = 0;
		self.speedrunning = FALSE;

        self.revrow = 0;
        self.jb_fragrow = 0;

		race_PostSpawn(spot);

        SetPlayerClipGroup(self, FALSE);

		if(CVAR(spawn_debug))
		{
			sprint(self, strcat("spawnpoint origin:  ", vtos(spot.origin), "\n"));
			remove(spot);	// usefull for checking if there are spawnpoints, that let drop through the floor
		}

		if (CVAR(g_spawnsound))
			sound (self, CHAN_TRIGGER, "misc/spawn.wav", VOL_BASE, ATTN_NORM);

		if(g_assault) {
			if(self.team == assault_attacker_team)
				centerprint_spec(self, "You are attacking!");
			else
				centerprint_spec(self, "You are defending!");
		}

		target_voicescript_clear(self);

        Akimbo_OnPlayerSpawn(self);

		// reset fields the weapons may use
        for (j = WEP_FIRST; j <= WEP_LAST; ++j)
            Akimbo_WeaponAction(j, WR_RESETPLAYER);

		oldself = self;
		self = spot;
			activator = oldself;
				SUB_UseTargets();
			activator = world;
		self = oldself;

        W_SetSecondary(self, self.w_secondary_picked);

        Freeze_Hook_PlayerSpawns();
		JB_PlayerSpawn();

        if(g_nadgets) {
            if(self.wasingame)
                HG_PlayerSpawn();
            else
                HG_PlayerJoin();
        }

        W_Clip_ResetAll(TRUE);
        Boobs_Attach();

        self.wasingame = TRUE;
        self.buffs = 0;
        self.hg_stealth = 0;
        self.buff_vamp_ticks = self.buff_vamp_healthpool = self.buff_vamp_nexttick = 0;
        self.buff_endur_ticks = self.buff_endur_dmgpool = 0;
        self.lastdamage = 0;
        self.pryaxe_thrown = world;

        self.hg_sentry_capture_progress = 0;

        Buffs_MEODP_Point_Attach(self, Buffs_MEODP_Death_Player);

        SpawnHeadEnt();

        GAMEEVENT("playerspawn", {
            GAMEEVENTARG(Entity, self)
        })
	} else if(self.classname == "observer") {
		PutObserverInServer ();
	}

	if(self.fire_burner) {
		remove(self.fire_burner);
		self.fire_burner = world;
	}

    self.justconnected = FALSE;

    CA_PlayerJoins();
    JoinQ_Pop();

    WaypointSprite_InvalidateTracking(self);
}

float ClientInit_SendEntity(entity to, float sf)
{
	float i;
	WriteByte(MSG_ENTITY, ENT_CLIENT_INIT);
	WriteByte(MSG_ENTITY, g_nexball_meter_period * 32);
	for(i = 1; i <= 24; ++i)
		WriteByte(MSG_ENTITY, (get_weaponinfo(i)).impulse + 1);
	self.owner = to;
	vector myhook_shotorigin;
	if(g_grappling_hook)
		myhook_shotorigin = '8 -8 -12';
	else
		myhook_shotorigin = shotorg_adjust('26.2148 9.2059 -15.9772', TRUE, TRUE, FALSE);
	WriteCoord(MSG_ENTITY, myhook_shotorigin_x);
	WriteCoord(MSG_ENTITY, myhook_shotorigin_y);
	WriteCoord(MSG_ENTITY, myhook_shotorigin_z);

	if(ShouldForceFog())
		WriteString(MSG_ENTITY, GetForcedFog());
	else
		WriteString(MSG_ENTITY, "");
	WriteByte(MSG_ENTITY, CVAR(g_balance_armor_blockpercent) * 255.0);
	WriteByte(MSG_ENTITY, sv_showspecs_extra);
	WriteByte(MSG_ENTITY, sv_scoreboard_fps_column);
    WriteByte(MSG_ENTITY, if(g_nadgets) (if(g_nadgets_oldhitboxes) 2 else 1) else 0);
    if(g_nadgets) {
        WriteByte(MSG_ENTITY, (HG_SelectableTypes(FALSE) != ""));
        WriteByte(MSG_ENTITY, g_nadgets_double);
    }
    WriteInt24_t(MSG_ENTITY, g_weaponarena);
    WriteInt24_t(MSG_ENTITY, g_weaponarena_secondary);
    WriteByte(MSG_ENTITY, g_freeze);
    WriteByte(MSG_ENTITY, sv_scoreboard_heal_column);
    WriteByte(MSG_ENTITY, sv_damagestats);
    WriteShort(MSG_ENTITY, sv_nicehealth);
    WriteByte(MSG_ENTITY, sv_scoreboard_acc_column);
    WriteShort(MSG_ENTITY, g_buffs_enabled);
    WriteByte(MSG_ENTITY, CVAR(g_balance_nex_secondary));
    WriteByte(MSG_ENTITY, sv_scoreboard_noob_column);
    WriteByte(MSG_ENTITY, sv_scoreboard_alive_column);
	return TRUE;
}

void ClientInit_Spawn()
{
	Net_LinkEntity(spawn(), FALSE, 0, ClientInit_SendEntity);
}

/*
=============
SetNewParms
=============
*/
void SetNewParms (void)
{
	// initialize parms for a new player
	parm1 = -(86400 * 366);
}

/*
=============
SetChangeParms
=============
*/
void SetChangeParms (void)
{
	// save parms for level change
	parm1 = self.parm_idlesince - time;
}

/*
=============
DecodeLevelParms
=============
*/
void DecodeLevelParms (void)
{
	// load parms
	self.parm_idlesince = parm1;
	if(self.parm_idlesince == -(86400 * 366))
		self.parm_idlesince = time;

	// whatever happens, allow 60 seconds of idling directly after connect for map loading
	self.parm_idlesince = max(self.parm_idlesince, time - sv_maxidle + 60);
}

/*
=============
ClientKill

Called when a client types 'kill' in the console
=============
*/

void ClientKill_Now_TeamChange()
{
	if(self.killindicator_teamchange == -1)
	{
		self.team = -1;
		JoinBestTeam( self, FALSE, FALSE );
	}
	else
		SV_ChangeTeam(self.killindicator_teamchange - 1);
}

void ClientKill_Now()
{
	if(self.killindicator_teamchange)
		ClientKill_Now_TeamChange();

	// in any case:
	Damage(self, self, self, 100000, DEATH_KILL, self.origin, '0 0 0');

	if(self.killindicator)
	{
		dprint("Cleaned up after a leaked kill indicator.\n");
		remove(self.killindicator);
		self.killindicator = world;
	}
}
void KillIndicator_Think()
{
	if (!self.owner.modelindex)
	{
		self.owner.killindicator = world;
		remove(self);
		return;
	}

	if(self.cnt <= 0)
	{
		self = self.owner;
		ClientKill_Now(); // no oldself needed
		return;
	}
	else
	{
		if(self.cnt <= 10)
			setmodel(self, strcat("models/sprites/", ftos(self.cnt), ".spr32"));
		if(clienttype(self.owner) == CLIENTTYPE_REAL)
		{
			if(self.cnt <= 10)
				announce(self.owner, strcat("announcer/robotic/", ftos(self.cnt), ".wav"));
			if(self.owner.killindicator_teamchange)
			{
				if(self.owner.killindicator_teamchange == -1)
					centerprint_spec(self.owner, strcat("Changing team in ", ftos(self.cnt), " seconds"));
				else
					centerprint_spec(self.owner, strcat("Changing to ", ColoredTeamName(self.owner.killindicator_teamchange), " in ", ftos(self.cnt), " seconds"));
			}
			else
				centerprint_spec(self.owner, strcat("^1Suicide in ", ftos(self.cnt), " seconds"));
		}
		self.nextthink = time + 1;
		self.cnt -= 1;
	}
}

void ClientKill_TeamChange (float targetteam) // 0 = don't change, -1 = auto
{
	float killtime;
	entity e;
	killtime = CVAR(g_balance_kill_delay);

	if(g_race_qualifying)
		killtime = 0;

	self.killindicator_teamchange = targetteam;

	if(!self.killindicator)
	{
		if(killtime <= 0 || !self.modelindex || self.deadflag != DEAD_NO || !self.iscreature)
		{
			ClientKill_Now();
		}
		else
		{
			self.killindicator = spawn();
			self.killindicator.owner = self;
			self.killindicator.scale = 0.5;
			setattachment(self.killindicator, self, "");
			setorigin(self.killindicator, '0 0 52');
			self.killindicator.think = KillIndicator_Think;
			self.killindicator.nextthink = time + (self.lip) * 0.05;
			self.killindicator.cnt = ceil(killtime);
			self.killindicator.count = bound(0, ceil(killtime), 10);
			sprint(self, strcat("^1You'll be dead in ", ftos(self.killindicator.cnt), " seconds\n"));

			for(e = world; (e = find(e, classname, "body")) != world; )
			{
				if(e.enemy != self)
					continue;
				e.killindicator = spawn();
				e.killindicator.owner = e;
				e.killindicator.scale = 0.5;
				setattachment(e.killindicator, e, "");
				setorigin(e.killindicator, '0 0 52');
				e.killindicator.think = KillIndicator_Think;
				e.killindicator.nextthink = time + (e.lip) * 0.05;
				e.killindicator.cnt = ceil(killtime);
			}
			self.lip = 0;
		}
	}
	if(self.killindicator)
	{
		if(targetteam)
			self.killindicator.colormod = TeamColor(targetteam);
		else
			self.killindicator.colormod = '0 0 0';
	}
}

void ClientKill (void)
{
    if(PlayerIsDead(self))
        return;
	ClientKill_TeamChange(0);
}

void DoTeamChange(float destteam)
{
	float t, c0;

	if(!teams_matter)
	{
		if(destteam >= 0)
			SetPlayerColors(self, destteam);
		return;
	}

    if(self.classname == "player" && PlayerIsDead(self)) {
        centerprint_spec(self, "You can't switch team while you're dead");
        return;
    }

	if(self.classname == "player")
	if(destteam == -1)
	{
		CheckAllowedTeams(self);
		t = FindSmallestTeam(self, TRUE);
		switch(self.team)
		{
			case COLOR_TEAM1: c0 = c1; break;
			case COLOR_TEAM2: c0 = c2; break;
			case COLOR_TEAM3: c0 = c3; break;
			case COLOR_TEAM4: c0 = c4; break;
			default:          c0 = 999;
		}
		switch(t)
		{
			case 1:
				if(c0 > c1)
					destteam = COLOR_TEAM1;
				break;
			case 2:
				if(c0 > c2)
					destteam = COLOR_TEAM2;
				break;
			case 3:
				if(c0 > c3)
					destteam = COLOR_TEAM3;
				break;
			case 4:
				if(c0 > c4)
					destteam = COLOR_TEAM4;
				break;
		}
		if(destteam == -1)
			return;
	}
	if(destteam == self.team && destteam >= 0 && !self.killindicator)
		return;
	ClientKill_TeamChange(destteam);
}

void FixClientCvars(entity e)
{
	// send prediction settings to the client
	if(g_race || g_cts)
		stuffcmd(e, "cl_cmd settemp cl_movecliptokeyboard 2\n");
}

void ServerTopic()
{
	string topicby = CVAR_STR(_sv_explosive_topicby);
	string servertopic = CVAR_STR(_sv_explosive_topic);
	
	if(servertopic) if(servertopic != "")
		sprint(self, strcat("\x01^2* ^3Current topic^7: ", servertopic, "\n"
			   "\x01^2* ^7Topic set by ^3", if(topicby && topicby != "") topicby else "<server>",
		"\n"));
}

/*
=============
ClientConnect

Called when a client connects to the server
=============
*/
string ColoredTeamName(float t);
void DecodeLevelParms (void);
void ClientConnect (void)
{
	string s;
	float t;

	if(self.flags & FL_CLIENT)
	{
		print("Warning: ClientConnect, but already connected!\n");
		return;
	}
    
    self.clientcamera = self;
    self.justconnected = TRUE;
    
	if(Ban_MaybeEnforceBan(self))
		return;

	DecodeLevelParms();

	self.classname = "player_joining";

	self.flags = FL_CLIENT;
	self.version_nagtime = time + 10 + random() * 10;

	if(player_count<0)
	{
		dprint("BUG player count is lower than zero, this cannot happen!\n");
		player_count = 0;
	}

	PlayerScore_Attach(self);
	ClientData_Attach();

	bot_clientconnect();

	race_PreSpawnObserver();

	JoinBestTeam(self, FALSE, FALSE); // if the team number is valid, keep it

	if((CVAR(sv_spectate) == 1 && !g_lms) || CVAR(g_campaign)) {
		self.classname = "observer";
	} else {
		if(teams_matter)
		{
			if(CVAR(g_balance_teams) || CVAR(g_balance_teams_force))
			{
				self.classname = "player";
				campaign_bots_may_start = 1;
			}
			else
			{
				self.classname = "observer"; // do it anyway
			}
		}
		else
		{
			self.classname = "player";
			campaign_bots_may_start = 1;
		}
	}

	self.playerid = (playerid_last = playerid_last + 1);
	if(CVAR(sv_eventlog))
	{
		if(clienttype(self) == CLIENTTYPE_REAL)
			GameLogEcho(strcat(":join:", ftos(self.playerid), ":", ftos(num_for_edict(self)), ":", self.netaddress, ":", self.netname));
		else
			GameLogEcho(strcat(":join:", ftos(self.playerid), ":", ftos(num_for_edict(self)), ":bot:", self.netname));
		s = strcat(":team:", ftos(self.playerid), ":");
		s = strcat(s, ftos(self.team));
		GameLogEcho(s);
	}
	self.netname_previous = strzone(self.netname);

	bprint ("^4",self.netname);
	bprint ("^4 connected");

	if(g_domination || g_ctf)
	{
		bprint(" and joined the ");
		bprint(ColoredTeamName(self.team));
	}

	bprint("\n");

	stuffcmd(self, strcat(clientstuff, "\n"));
	stuffcmd(self, strcat("exec maps/", mapname, ".cfg\n"));
	stuffcmd(self, "cl_particles_reloadeffects\n");

	FixClientCvars(self);

	// spawnfunc_waypoint sprites
	WaypointSprite_InitClient(self);

	// Wazat's grappling hook
	SetGrappleHookBindings();

	// get autoswitch state from player when he toggles it
	stuffcmd(self, "alias autoswitch \"set cl_autoswitch $1 ; cmd autoswitch $1\"\n"); // default.cfg-ed in 2.4.1

	// get version info from player
	stuffcmd(self, "cmd clientversion $gameversion\n");

	// get other cvars from player
	GetCvars(0);

	// set cvar for team scoreboard
	stuffcmd(self, strcat("set teamplay ", ftos(CVAR(teamplay)), "\n"));

	// notify about available teams
	if(teams_matter)
	{
		CheckAllowedTeams(self);
		t = 0; if(c1 >= 0) t |= 1; if(c2 >= 0) t |= 2; if(c3 >= 0) t |= 4; if(c4 >= 0) t |= 8;
		stuffcmd(self, strcat("set _teams_available ", ftos(t), "\n"));
	}
	else
		stuffcmd(self, "set _teams_available 0\n");

	stuffcmd(self, strcat("set gametype ", ftos(game), "\n"));

	if(g_arena)
	{
		self.classname = "observer";
		Spawnqueue_Insert(self);
	}

	attach_entcs();
	bot_relinkplayerlist();

	self.spectatortime = time;
	if(blockSpectators)
	{
		sprint(self, strcat("^7You have to become a player within the next ", ftos(CVAR(g_maxplayers_spectator_blocktime)), " seconds, otherwise you will be kicked, because spectators aren't allowed at this time!\n"));
	}

	self.jointime = time;
	self.allowedTimeouts = CVAR(sv_timeout_number);

	if(clienttype(self) == CLIENTTYPE_REAL)
	{
		if(CVAR(g_bugrigs) || g_weaponarena == WEPBIT_TUBA)
			stuffcmd(self, "cl_cmd settemp chase_active 1\n");
	}

	if(g_lms)
	{
		if(PlayerScore_Add(self, SP_LMS_LIVES, LMS_NewPlayerLives()) <= 0)
		{
			PlayerScore_Add(self, SP_LMS_RANK, 666);
			self.frags = FRAGS_SPECTATOR;
		}
	}

	SoundEntity_Attach(self);

	if(CVAR(g_hitplots) || strstrofs(strcat(" ", CVAR_STR(g_hitplots_individuals), " "), strcat(" ", self.netaddress, " "), 0) >= 0)
	{
		self.hitplotfh = fopen(strcat("hits-", matchid, "-", self.netaddress, "-", ftos(self.playerid), ".plot"), FILE_WRITE);
		fputs(self.hitplotfh, strcat("#name ", self.netname, "\n"));
	}
	else
		self.hitplotfh = -1;
	
	if(clienttype(self) == CLIENTTYPE_REAL)
		defer(5, ServerTopic);
	
	self.g_minstagib_stat = g_minstagib;

    self.hidecountry = CVAR(sv_hidecountry);
	IP2C_SetCountry(self);
	
	stuffcmd(self, strcat("seta _g_rocketminsta ", ftos(g_minstagib && CVAR(g_rocketminsta)), "\n"));
	if (clienttype(self) == CLIENTTYPE_REAL)
		SendServerInfo(self);
	
    self.hg_type1_picked_nextround = -1;
    self.hg_type2_picked_nextround = -1;
    self.hg_optout_nextround = -1;

    totalclients++;
    if(clienttype(self) == CLIENTTYPE_REAL) {
        realclients++;
        
        if(realclients == 1) {
        	defer(5, Radio_Queue_PlayFirst);
            inWarmupStage = CVAR(g_warmup);
            if(inWarmupStage) {
                game_starttime = time;
                g_warmup_limit = CVAR(g_warmup_limit);
                if(g_warmup_limit > 0)
                    g_warmup_limit += time;
            } else {
                ReadyRestart();
            }
            readyrestart_happened = FALSE;
            lockteams = FALSE;
	    }
    }
    
    if(clienttype(self) == CLIENTTYPE_REAL) {
        IRC_Announce_ClientConnect(self);
        DamageTracker_Overwrite(dtrack_global, self, DTFLAG_GLOBAL);
    }
    
    self.dtrack_total = DamageTracker_CreateKeeper(self);
    self.dtrack_total.netname = "Damage done";
    self.dtrack_taken = DamageTracker_CreateKeeper(self);
    self.dtrack_taken.netname = "Damage taken";
    
    float i, n = tokenizebyseparator(CVAR_STR(sv_vote_master_autologin), " ");
    for(i = 0; i < n; ++i) {
        if(strlen(argv(i))) if(substring(self.netaddress, 0, strlen(argv(i))) == argv(i)) {
            self.vote_mastername = strzone(CVAR_STR(sv_vote_master_autologin_name));
            self.vote_master = TRUE;
            break;
        }
    }

    Radio_ClientConnect();

    // FIXME: this is a horrible hack
    spawn() {
        owner: self,
        nextthink: time + 1,
        think: inline void(void) {
            stuffcmd(self.owner, "setinfo \"name\" \"$_cl_name\"\n");
        }
    };

    SpecInfo_Attach(self);
    W_Accuracy_Attach(self);

    self.discardabledemo = TRUE;
}

/*
=============
ClientDisconnect

Called when a client disconnects from the server
=============
*/
.entity chatbubbleentity;
.entity teambubbleentity;
void ReadyCount();
void ClientDisconnect (void)
{
    SpecInfo_Update(self, SPECINFO_LIST);

    if(self.netname_strzoned) {
        strunzone(self.netname_strzoned);
        self.netname_strzoned = NULL;
    }

	if not(self.flags & FL_CLIENT)
	{
		print("Warning: ClientDisconnect without ClientConnect\n");
		return;
	}

	if(self.hitplotfh >= 0)
	{
		fclose(self.hitplotfh);
		self.hitplotfh = -1;
	}

    Akimbo_Clear(self);

    JoinQ_Remove(self);
	bot_clientdisconnect();
    
    if(self.buff_model)
        remove(self.buff_model);
    
	if(self.entcs)
		detach_entcs();

	if(CVAR(sv_eventlog))
		GameLogEcho(strcat(":part:", ftos(self.playerid)));
	bprint ("^4",self.netname);
	bprint ("^4 disconnected\n");

	SoundEntity_Detach(self);
    
	kh_Key_DropAll(self, TRUE);
    Freeze_Hook_PlayerQuits();
    HG_GenericProjectile_DetonateAll(self, TRUE);
	JB_RemovePlayer();
	Portal_ClearAll(self);
	Boobs_Clear();

	if(self.flagcarried)
		DropFlag(self.flagcarried, world, world);
	if(self.ballcarried)
		DropBall(self.ballcarried, self.origin + self.ballcarried.origin, self.velocity);

	// Here, everything has been done that requires this player to be a client.

	self.flags &~= FL_CLIENT;

	if (self.chatbubbleentity)
		remove (self.chatbubbleentity);

	if (self.teambubbleentity)
		remove (self.teambubbleentity);

	if (self.killindicator)
		remove (self.killindicator);

	WaypointSprite_PlayerGone();

	bot_relinkplayerlist();

	// remove laserdot
	if(self.weaponentity)
		if(self.weaponentity.lasertarget)
			remove(self.weaponentity.lasertarget);

	if(g_arena)
	{
		Spawnqueue_Unmark(self);
		Spawnqueue_Remove(self);
	}

	ClientData_Detach();
	PlayerScore_Detach(self);

	if(self.netname_previous)
		strunzone(self.netname_previous);
	if(self.clientstatus)
		strunzone(self.clientstatus);
	
	if(clienttype(self) != CLIENTTYPE_BOT)
	if(self.hudskin)
		fstrunzone(self.hudskin);

	ClearPlayerSounds();

	if(self.personal)
		remove(self.personal);

	self.playerid = 0;
	ReadyCount();

    if(self.specdelay_ent)
        remove(self.specdelay_ent);

    if(self.dtrack_total)
        remove(self.dtrack_total);
    
    if(self.dtrack_taken)
        remove(self.dtrack_taken);
    
    // free cvars
    GetCvars(-1);

    totalclients--;
    if(clienttype(self) == CLIENTTYPE_REAL) {
        realclients--;
        IRC_Announce_ClientDisconnect(self);

        if(!realclients)
        	Radio_Stop();
    }
    
    Buffs_MEODP_Point_Detach(self);
    CA_PlayerLeaves();
    HG_RemoveAll(self);
    JoinQ_Pop();

    SpecInfo_Remove(self);
    W_Accuracy_Remove(self);
}

.float BUTTON_CHAT;
void ChatBubbleThink()
{
	self.nextthink = time;
	if (!self.owner.modelindex || self.owner.chatbubbleentity != self || !self.owner.iscreature)
	{
		if(self.owner) // but why can that ever be world?
			self.owner.chatbubbleentity = world;
		remove(self);
		return;
	}
	if ((self.owner.BUTTON_CHAT && !self.owner.deadflag)
#ifdef TETRIS
		|| self.owner.tetris_on
#endif
	)
		self.model = self.mdl;
	else
		self.model = "";
};

void UpdateChatBubble()
{
	if (!self.modelindex)
		return;
	// spawn a chatbubble entity if needed
	if (!self.chatbubbleentity)
	{
		self.chatbubbleentity = spawn();
		self.chatbubbleentity.owner = self;
		self.chatbubbleentity.exteriormodeltoclient = self;
		self.chatbubbleentity.think = ChatBubbleThink;
		self.chatbubbleentity.nextthink = time;
		setmodel(self.chatbubbleentity, "models/misc/chatbubble.spr"); // precision set below
		setorigin(self.chatbubbleentity, '0 0 15' + self.maxs_z * '0 0 1');
		setattachment(self.chatbubbleentity, self, "");  // sticks to moving player better, also conserves bandwidth
		self.chatbubbleentity.mdl = self.chatbubbleentity.model;
		self.chatbubbleentity.model = "";
		self.chatbubbleentity.effects = EF_LOWPRECISION;
	}
}


void TeamBubbleThink()
{
	self.nextthink = time;
	if (!self.owner.modelindex || self.owner.teambubbleentity != self || !self.owner.iscreature)
	{
		if(self.owner) // but why can that ever be world?
			self.owner.teambubbleentity = world;
		remove(self);
		return;
	}
//	setorigin(self, self.owner.origin + '0 0 15' + self.owner.maxs_z * '0 0 1');  // bandwidth hog. setattachment does this now
	if (self.owner.BUTTON_CHAT || self.owner.deadflag || self.owner.killindicator)
		self.model = "";
	else
		self.model = self.mdl;

};

float TeamBubble_customizeentityforclient()
{
	return (self.owner.smhost != other && self.owner.soulmate != other && self.owner != other && self.owner.team == other.team && other.killcount > -666);
}

void UpdateTeamBubble()
{
	if (!self.modelindex || !teams_matter)
		return;
	// spawn a teambubble entity if needed
	if (!self.teambubbleentity && teams_matter)
	{
		self.teambubbleentity = spawn();
		self.teambubbleentity.owner = self;
		self.teambubbleentity.exteriormodeltoclient = self;
		self.teambubbleentity.think = TeamBubbleThink;
		self.teambubbleentity.nextthink = time;
		setmodel(self.teambubbleentity, "models/misc/teambubble.spr"); // precision set below
		setorigin(self.teambubbleentity, '0 0 15' + self.maxs_z * '0 0 1');
		setattachment(self.teambubbleentity, self, "");  // sticks to moving player better, also conserves bandwidth
		self.teambubbleentity.mdl = self.teambubbleentity.model;
		self.teambubbleentity.model = self.teambubbleentity.mdl;
		self.teambubbleentity.customizeentityforclient = TeamBubble_customizeentityforclient;
		self.teambubbleentity.effects = EF_LOWPRECISION;
	}
}

void respawn(void)
{
	CopyBody(1);
	self.effects |= EF_NODRAW; // prevent another CopyBody
    
    if(CA_AttemptRespawn())
        return;
    
	PutClientInServer();
}

void play_countdown(float finished, string samp)
{
	if(clienttype(self) == CLIENTTYPE_REAL)
		if(floor(finished - time - frametime) != floor(finished - time))
			if(finished - time < 6)
				sound (self, CHAN_AUTO, samp, VOL_BASE, ATTN_NORM);
}

/**
 * When sv_timeout is used this function returs strings like
 * "Timeout begins in 2 seconds!\n" or "Timeout ends in 23 seconds!\n".
 * Called by centerprint functions
 * @param addOneSecond boolean, set to 1 if the welcome-message centerprint asks for the text
 */
string getTimeoutText(float addOneSecond) {
	if (!CVAR(sv_timeout) || !timeoutStatus)
		return "";

	string retStr;
	if (timeoutStatus == 1) {
		if (addOneSecond == 1) {
			retStr = strcat("Timeout begins in ", ftos(remainingLeadTime + 1), " seconds!\n");
		}
		else {
			retStr = strcat("Timeout begins in ", ftos(remainingLeadTime), " seconds!\n");
		}
		return retStr;
	}
	else if (timeoutStatus == 2) {
		if (addOneSecond) {
			retStr = strcat("Timeout ends in ", ftos(remainingTimeoutTime + 1), " seconds!\n");
			//don't show messages like "Timeout ends in 0 seconds"...
			if ((remainingTimeoutTime + 1) > 0)
				return retStr;
			else
				return "";
		}
		else {
			retStr = strcat("Timeout ends in ", ftos(remainingTimeoutTime), " seconds!\n");
			//don't show messages like "Timeout ends in 0 seconds"...
			if (remainingTimeoutTime > 0)
				return retStr;
			else
				return "";
		}
	}
	else return "";
}

void player_powerups (void)
{
	if((self.items & IT_USING_JETPACK) && !self.deadflag)
	{
		SoundEntity_StartSound(self, CHAN_PLAYER, "misc/jetpack_fly.wav", VOL_BASE, CVAR(g_jetpack_attenuation));
		self.modelflags |= MF_ROCKET;
	}
	else
	{
		SoundEntity_StopSound(self, CHAN_PLAYER);
		self.modelflags &~= MF_ROCKET;
	}

	self.effects &~= (EF_RED | EF_BLUE | EF_ADDITIVE | EF_FULLBRIGHT | EF_FLAME);
    self.glow_size = 0;
    self.glow_trail = 0;

	if(!self.modelindex || self.deadflag) // don't apply the flags if the player is gibbed
		return;
	
	Fire_ApplyDamage(self);
	Fire_ApplyEffect(self);

	if (g_minstagib)
	{
		self.effects |= EF_FULLBRIGHT;

		if (self.items & IT_STRENGTH)
		{
			play_countdown(self.strength_finished, "misc/poweroff.wav");
			if (time > self.strength_finished)
			{
				self.alpha = default_player_alpha;
				self.exteriorweaponentity.alpha = default_weapon_alpha;
				self.items &~= IT_STRENGTH;
				sprint(self, "^3Invisibility has worn off\n");
			}
		}
		else
		{
			if (time < self.strength_finished)
			{
				self.alpha = g_minstagib_invis_alpha;
				self.exteriorweaponentity.alpha = g_minstagib_invis_alpha;
				self.items |= IT_STRENGTH;
				sprint(self, "^3You are invisible\n");
			}
		}

		if (self.items & IT_INVINCIBLE)
		{
			play_countdown(self.invincible_finished, "misc/poweroff.wav");
			if (time > self.invincible_finished)
			{
				self.items = self.items - (self.items & IT_INVINCIBLE);
				sprint(self, "^3Speed has worn off\n");
			}
		}
		else
		{
			if (time < self.invincible_finished)
			{
				self.items = self.items | IT_INVINCIBLE;
				sprint(self, "^3You are on speed\n");
			}
		}
		return;
	}

	if (self.items & IT_STRENGTH)
	{
		play_countdown(self.strength_finished, "misc/poweroff.wav");
		self.effects = self.effects | (EF_BLUE | EF_ADDITIVE | EF_FULLBRIGHT);
		if (time > self.strength_finished)
		{
			self.items = self.items - (self.items & IT_STRENGTH);
			sprint(self, "^3Strength has worn off\n");
		}
	}
	else
	{
		if (time < self.strength_finished)
		{
			self.items = self.items | IT_STRENGTH;
			sprint(self, "^3Strength infuses your weapons with devastating power\n");
		}
	}
	if (self.items & IT_INVINCIBLE)
	{
		play_countdown(self.invincible_finished, "misc/poweroff.wav");
		self.effects = self.effects | (EF_RED | EF_ADDITIVE | EF_FULLBRIGHT);
		if (time > self.invincible_finished)
		{
			self.items = self.items - (self.items & IT_INVINCIBLE);
			sprint(self, "^3Shield has worn off\n");
		}
	}
	else
	{
		if (time < self.invincible_finished)
		{
			self.items = self.items | IT_INVINCIBLE;
			sprint(self, "^3Shield surrounds you\n");
		}
	}

	if (CVAR(g_fullbrightplayers))
		self.effects = self.effects | EF_FULLBRIGHT;

	// midair gamemode: damage only while in the air
	// if in midair mode, being on ground grants temporary invulnerability
	// (this is so that multishot weapon don't clear the ground flag on the
	// first damage in the frame, leaving the player vulnerable to the
	// remaining hits in the same frame)
	if (self.flags & FL_ONGROUND)
	if (g_midair)
		self.spawnshieldtime = max(self.spawnshieldtime, time + CVAR(g_midair_shieldtime));

	if (time >= game_starttime)
	if (time < self.spawnshieldtime || self.hg_shield)
		self.effects = self.effects | (EF_ADDITIVE | EF_FULLBRIGHT);
    
    if(time < self.hg_plasmalock)
        self.effects |= EF_ADDITIVE | EF_FULLBRIGHT;
}

float CalcRegen(float current, float stable, float regenfactor, float regenframetime)
{
	if(current > stable)
		return current;
	else if(current > stable - 0.25) // when close enough, "snap"
		return stable;
	else
		return min(stable, current + (stable - current) * regenfactor * regenframetime);
}

float CalcRot(float current, float stable, float rotfactor, float rotframetime)
{
	if(current < stable)
		return current;
	else if(current < stable + 0.25) // when close enough, "snap"
		return stable;
	else
		return max(stable, current + (stable - current) * rotfactor * rotframetime);
}

float CalcRotRegen(float current, float regenstable, float regenfactor, float regenlinear, float regenframetime, float rotstable, float rotfactor, float rotlinear, float rotframetime, float limit)
{
	if(current > rotstable)
	{
		if(rotframetime > 0)
		{
			current = CalcRot(current, rotstable, rotfactor, rotframetime);
			current = max(rotstable, current - rotlinear * rotframetime);
		}
	}
	else if(current < regenstable)
	{
		if(regenframetime > 0)
		{
			current = CalcRegen(current, regenstable, regenfactor, regenframetime);
			current = min(regenstable, current + regenlinear * regenframetime);
		}
	}

	if(current > limit)
		current = limit;

	return current;
}

void player_regen (void)
{
	float minh, mina, minf, maxh, maxa, maxf, limith, limita, limitf, max_mod, regen_mod, rot_mod, limit_mod, aregen, hregen;
    float rot_mod_a = 1;
    float rot_mod_h = 1;

    if(roundstate == ROUNDSTATE_OVER)
        return;

	maxh = CVAR(g_balance_health_rotstable);
	maxa = CVAR(g_balance_armor_rotstable);
	maxf = CVAR(g_balance_fuel_rotstable);
	minh = CVAR(g_balance_health_regenstable);
	mina = CVAR(g_balance_armor_regenstable);
	minf = CVAR(g_balance_fuel_regenstable);
	limith = CVAR(g_balance_health_limit);
	limita = CVAR(g_balance_armor_limit);
	limitf = CVAR(g_balance_fuel_limit);
    aregen = CVAR(g_balance_armor_regen);
    hregen = CVAR(g_balance_health_regen);
    
    if(g_clanarena && !g_clanarena_pickups)
        hregen = aregen = 0;
    
    if(!aregen)
        mina = 0;
    if(!hregen)
        minh = 0;
    
    max_mod = regen_mod = rot_mod = limit_mod = 1;

	maxh = maxh * max_mod;
	minh = minh * max_mod;
	limith = limith * limit_mod;
	limita = limita * limit_mod;
    
    if(Buffs_Present(self, BUFF_GUARD)) {
        float ghealth, garmor, ghregen, garegen;
        
        ghealth = CVAR(g_buffs_guard_health);
        garmor  = CVAR(g_buffs_guard_armor);
        ghregen = CVAR(g_buffs_guard_health_regen);
        garegen = CVAR(g_buffs_guard_armor_regen);
        
        if(g_clanarena)
            garmor = 0;
        
        mina = max(mina, garmor);
        maxa = max(mina, maxa);
        minh = max(maxh, ghealth);
        maxh = max(minh, maxh);
        
        hregen = max(ghregen, hregen);
        aregen = max(garegen, aregen);
    }
    
    if(!g_clanarena && Buffs_Present(self, BUFF_MEDIC)) {
        mina = max(mina, CVAR(g_buffs_medic_armor));
        maxa = max(mina, maxa);
        aregen = max(CVAR(g_buffs_medic_armor_regen), aregen);
    }

    if(g_lms) {
        rot_mod = 0;
    } else if(g_clanarena) {
        if(!CVAR(g_clanarena_rot)) {
            rot_mod = 0;
        } else if(CVAR(g_clanarena_rot) > 1) {
            var tidx = Team_Index(self.team);
            var camax = ceil(g_clanarena_maxteamhealths[tidx]);
            var camin = ceil(g_clanarena_minteamhealths[tidx]);
            var h = ceil(self.health);

            if(h == camin && h < camax) {
                rot_mod_h = 0;
            }
        }
    }

    if(g_clanarena) {
        float clamp = CVAR(g_clanarena_heal_limit);
        if(clamp) {
            maxh = min(maxh, clamp);
            maxa = min(maxa, clamp);
        }
    }

	if (!g_minstagib && (!g_lms || CVAR(g_lms_regenerate)))
	{
		self.armorvalue = CalcRotRegen(self.armorvalue, mina, aregen, CVAR(g_balance_armor_regenlinear), regen_mod * frametime * (time > self.pauseregen_finished), maxa, CVAR(g_balance_armor_rot), CVAR(g_balance_armor_rotlinear), rot_mod_a * rot_mod * frametime * (time > self.pauserotarmor_finished), limita);
		self.health = CalcRotRegen(self.health, minh, hregen, CVAR(g_balance_health_regenlinear), regen_mod * frametime * (time > self.pauseregen_finished), maxh, CVAR(g_balance_health_rot), CVAR(g_balance_health_rotlinear), rot_mod_h * rot_mod * frametime * (time > self.pauserothealth_finished), limith);

		// if player rotted to death...  die!
		if(self.health < 1)
			self.event_damage(self, self, 1, DEATH_ROT, self.origin, '0 0 0');
	}

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_fuel = CalcRotRegen(self.ammo_fuel, minf, CVAR(g_balance_fuel_regen), CVAR(g_balance_fuel_regenlinear), regen_mod * frametime * (time > self.pauseregen_finished) * (self.items & IT_FUEL_REGEN != 0), maxf, CVAR(g_balance_fuel_rot), CVAR(g_balance_fuel_rotlinear), rot_mod * frametime * (time > self.pauserotfuel_finished), limitf);
}

float zoomstate_set;
void SetZoomState(float z)
{
	if(z != self.zoomstate)
	{
		self.zoomstate = z;
		ClientData_Touch(self);
	}
	zoomstate_set = 1;
}

void GetPressedKeys(void) {
	dodging_GetPressedKeys();
	
	if (self.movement_x > 0) // get if movement keys are pressed
	{	// forward key pressed
		self.pressedkeys |= KEY_FORWARD;
		self.pressedkeys &~= KEY_BACKWARD;
		self.lastkeypressed = KEY_FORWARD;
	}
	else if (self.movement_x < 0)
	{	// backward key pressed
		self.pressedkeys |= KEY_BACKWARD;
		self.pressedkeys &~= KEY_FORWARD;
		self.lastkeypressed = KEY_BACKWARD;
	}
	else
	{	// no x input
		self.pressedkeys &~= KEY_FORWARD;
		self.pressedkeys &~= KEY_BACKWARD;
	}

	if (self.movement_y > 0)
	{	// right key pressed
		self.pressedkeys |= KEY_RIGHT;
		self.pressedkeys &~= KEY_LEFT;
		self.lastkeypressed = KEY_RIGHT;
	}
	else if (self.movement_y < 0)
	{	// left key pressed
		self.pressedkeys |= KEY_LEFT;
		self.pressedkeys &~= KEY_RIGHT;
		self.lastkeypressed = KEY_LEFT;
	}
	else
	{	// no y input
		self.pressedkeys &~= KEY_RIGHT;
		self.pressedkeys &~= KEY_LEFT;
	}

	if (self.BUTTON_JUMP) // get if jump and crouch keys are pressed
		self.pressedkeys |= KEY_JUMP;
	else
		self.pressedkeys &~= KEY_JUMP;
	if (self.BUTTON_CROUCH)
		self.pressedkeys |= KEY_CROUCH;
	else
		self.pressedkeys &~= KEY_CROUCH;
}

/*
======================
spectate mode routines
======================
*/

void EnterSpectatorMode() {
    if(self.flagcarried)
        DropFlag(self.flagcarried, world, world);
    if(self.ballcarried)
        DropBall(self.ballcarried, self.origin, self.velocity);
    kh_Key_DropAll(self, TRUE);
    WaypointSprite_PlayerDead();
    self.classname = "observer";
    if(blockSpectators)
        sprint(self, strcat("^7You have to become a player within the next ", ftos(CVAR(g_maxplayers_spectator_blocktime)), " seconds, otherwise you will be kicked, because spectators aren't allowed at this time!\n"));
    PutClientInServer();
}

void SpectateDelay_Think() {
    if(!self.owner || gameover || self.owner.classname != "player") {
        self.owner.specdelay_ent = world;
        remove(self);
        return;
    }
    
    if(self.cnt <= 0) {
        entity o = self;
        self = self.owner;
        EnterSpectatorMode();
        self = o;
        self.owner.specdelay_ent = world;
        remove(self);
        return;
    }
    
    bigprint_spec(self.owner, "", strcat("Spectating in ^1", ftos(self.cnt), " ^7seconds"), 1);
    self.nextthink = time + 1;
    self.cnt -= 1;
}

void EnterSpectatorModeDelayed(float dlay) {
    dlay = floor(dlay);
    
    if(dlay <= 0) {
        EnterSpectatorMode();
        return;
    }
    
    if(self.specdelay_ent)
        return;
    
    entity e = spawn();
    e.think = SpectateDelay_Think;
    e.nextthink = time;
    e.owner = self;
    e.cnt = dlay;
    
    self.specdelay_ent = e;
}

void SpectateCopy(entity spectatee) {
    self.impulse = 0;

    if(self.classname == "spectator") {
        self.effects = self.effects & EFMASK_CHEAP;
        setorigin(self, spectatee.origin);
    }

	SetZoomState(spectatee.zoomstate);
}

float SpectateUpdate() {
    if(clienttype(self) != CLIENTTYPE_REAL)
        return FALSE;
    
    if(!MaySpectate(self.enemy))
        return FALSE;

    SpectateCopy(self.enemy);
    return TRUE;
}

float MaySpectate(entity plr) {
    if(!plr)
        return FALSE;

	if(clienttype(plr) == CLIENTTYPE_NOTACLIENT)
		return FALSE;

    if(plr == self)
        return FALSE;

	if(plr.classname != "player")
		return FALSE;

    if(plr.deadflag == DEAD_PERMANENTLY)
        return FALSE;

    if(self.classname == "spectator" || self.classname == "observer")
        return TRUE;

    return !IsDifferentTeam(plr, self);
}

#define SPECTATE_YIELD_NEXT 1
#define SPECTATE_YIELD_PREV -1

entity Spectate_Yield(entity p, float dir) {
	var wrappedAround = FALSE;

	for(var n = num_for_edict(p) + dir ;; n += dir) {
		if(n <= 0 || n > maxclients) {
			if(wrappedAround)
				break;

			wrappedAround = TRUE;

			if(n <= 0)
				n = maxclients + n;
			else if(n > maxclients)
				n = n - maxclients;
		}

		var e = edict_num(n);

		if(MaySpectate(e))
			return e;
	}

	return world;
}

float SpectatePlayer(entity plr) {
    entity oldenemy = self.enemy;

    if(!MaySpectate(plr))
        return FALSE;

    UnmarkAway(self);

    self.enemy = plr;

    if(clienttype(self) == CLIENTTYPE_REAL)
        self.clientcamera = self.clientdataent = self.enemy;

    if(g_jailbreak)
    if(jb_roundover)
        JB_SetCameraWithAngles(self, jb_activecamera, JB_TORTURE_DURATION);

    if(self.classname != "player")
        self.movetype = MOVETYPE_NONE;

    if(!SpectateUpdate() && self.classname == "spectator")
        PutObserverInServer();

    DamageTracker_Overwrite(self.enemy.dtrack_total, self, DTFLAG_DONE  | DTFLAG_SPEC);
    DamageTracker_Overwrite(self.enemy.dtrack_taken, self, DTFLAG_TAKEN | DTFLAG_SPEC);

    return TRUE;
}

float SpectateNext(void) {
    return SpectatePlayer(Spectate_Yield(self.enemy, SPECTATE_YIELD_NEXT));
}

float SpectatePrev(void) {
    return SpectatePlayer(Spectate_Yield(self.enemy, SPECTATE_YIELD_PREV));
}

.float specbest_ignore;

float SpectateBest(float pos) {
    float mx;
    entity plr, pick;

    // this line is needed because our compiller has strong homosexual tendencies
    pick = world;

    FOR_EACH_PLAYER(plr) if(!plr.specbest_ignore && MaySpectate(plr)) {
        float s = PlayerScore_Get(plr, SP_SCORE);

        if(!pick || s > mx || (s == mx && (num_for_edict(plr) < num_for_edict(pick)))) {
            mx = s;
            pick = plr;
        }
    }

    if(pick) {
        --pos;

        if(pos > 0) {
            pick.specbest_ignore = TRUE;
            return SpectateBest(pos);
        }
    }

    for(plr = world; (plr = findfloat(plr, specbest_ignore, TRUE));)
        plr.specbest_ignore = FALSE;

    return SpectatePlayer(pick);
}

/*
=============
ShowRespawnCountdown()

Update a respawn countdown display.
=============
*/
void ShowRespawnCountdown()
{
	float number;
	if(self.deadflag == DEAD_NO) // just respawned?
		return;
	else
	{
		number = ceil(self.death_time - time);
		if(number <= 0)
			return;
		if(number <= self.respawn_countdown)
		{
			self.respawn_countdown = number - 1;
		}
	}
}

void LeaveSpectatorMode()
{
	if(isJoinAllowed()) {
        if(lockteams) {
            bigprint(self, "The teams are locked", "", 2);
            return;
        }
        
        if(!teams_matter || CVAR(g_campaign) || CVAR(g_balance_teams) || (self.wasplayer && CVAR(g_changeteam_banned))) {
            if(HG_ShowMenu(FALSE))
                return;
            
            if(W_ShowMenu(FALSE))
                return;

			self.classname = "player";
			if(CVAR(g_campaign) || CVAR(g_balance_teams) || CVAR(g_balance_teams_force))
				JoinBestTeam(self, FALSE, TRUE);
			if(CVAR(g_campaign))
				campaign_bots_may_start = 1;
            PutClientInServer();
			if(self.classname == "player")
				bprint ("^4", self.netname, "^4 is playing now\n");
			if(!CVAR(g_campaign))
				centerprint(self,""); // clear MOTD
			return;
		} else {
			stuffcmd(self, "menu_showteamselect\n");
			return;
		}
	}
	else {
        if(!self.joinqueue)
        if(!HG_ShowMenu(FALSE))
        if(!W_ShowMenu(FALSE))
            JoinQ_Push(self);
	}
}

float RealPlayerCount(void) {
    var c = 0;
    FOR_EACH_REALPLAYER(var e)
        ++c;
    return c;
}

/**
 * Determines whether the player is allowed to join. This depends on cvar
 * g_maxplayers, if it isn't used this function always return TRUE, otherwise
 * it checks whether the number of currently playing players exceeds g_maxplayers.
 * @return bool TRUE if the player is allowed to join, false otherwise
 */
float isJoinAllowed() {
    if(roundstate == ROUNDSTATE_GAME && g_clanarena)
        return (RealPlayerCount() < 2);

	if(!CVAR(g_maxplayers))
		return TRUE;

	if(RealPlayerCount() < CVAR(g_maxplayers))
		return TRUE;

	return FALSE;
}

/**
 * Checks whether the client is an observer or spectator, if so, he will get kicked after
 * g_maxplayers_spectator_blocktime seconds
 */
void checkSpectatorBlock() {
	if(self.classname == "spectator" || self.classname == "observer") {
		if( time > (self.spectatortime + CVAR(g_maxplayers_spectator_blocktime)) ) {
			sprint(self, "^7You were kicked from the server because you are spectator and spectators aren't allowed at the moment.\n");
			dropclient(self);
		}
	}
}

float vercmp_recursive(string v1, string v2)
{
	float dot1, dot2;
	string s1, s2;
	float r;

	dot1 = strstrofs(v1, ".", 0);
	dot2 = strstrofs(v2, ".", 0);
	if(dot1 == -1)
		s1 = v1;
	else
		s1 = substring(v1, 0, dot1);
	if(dot2 == -1)
		s2 = v2;
	else
		s2 = substring(v2, 0, dot2);

	r = stof(s1) - stof(s2);
	if(r != 0)
		return r;

	r = strcasecmp(s1, s2);
	if(r != 0)
		return r;

	if(dot1 == -1)
		if(dot2 == -1)
			return 0;
		else
			return -1;
	else
		if(dot2 == -1)
			return 1;
		else
			return vercmp_recursive(substring(v1, dot1 + 1, 999), substring(v2, dot2 + 1, 999));
}

float vercmp(string v1, string v2)
{
	if(strcasecmp(v1, v2) == 0) // early out check
		return 0;
	return vercmp_recursive(v1, v2);
}

void SpectatorImpulse(void) {
    if(self.impulse >= 1 && self.impulse <= 9)
        SpectateBest(self.impulse);
    else switch(self.impulse) {
        case 10: case 14: case 15: case 18:
            SpectateNext();
            break;

        case 12: case 16: case 19:
            SpectatePrev();
            break;

        case 13:
            SpectateBest(1);
            break;
    }

    self.impulse = 0;
}

void PlayerSpectatorStop(void) {
    if(!teams_matter || self.clientcamera == self || self.classname != "player")
        return;

    self.pspec_last_spectatee = self.enemy;
    self.clientcamera = self.clientdataent = self;
    self.pspec_leavetime = time;
    self.enemy = world;

    defer(0, inline void(void) {
        self.v_angle = self.pspec_oldvangle;
        self.angles = self.pspec_oldvangle;
        self.fixangle = TRUE;
    });
}

void PlayerSpectatorStart(void) {
    if(!teams_matter || self.clientcamera != self || self.classname != "player" || time < self.pspec_block)
        return;

    self.pspec_entertime = time;
    self.pspec_flags &~= FL_JUMPRELEASED;
    self.pspec_oldvangle = self.v_angle;

    self.enemy = self.pspec_last_spectatee;
    if(!SpectatePlayer(self.enemy))
        SpectateNext();
}

void PlayerSpectatorToggle(void) {
    if(!teams_matter)
        return;

    if(self.clientcamera == self)
        PlayerSpectatorStart();
    else if(self.deadflag != DEAD_PERMANENTLY)
        PlayerSpectatorStop();
}

void PlayerSpectatorThink(void) {
    SpectatorImpulse();

    if(self.movement != '0 0 0' && self.deadflag != DEAD_PERMANENTLY) {
        PlayerSpectatorStop();
        return;
    }

    if(self.pspec_flags & FL_JUMPRELEASED) {
        if((self.BUTTON_JUMP || self.BUTTON_ATCK2 || self.BUTTON_HOOK) && self.deadflag != DEAD_PERMANENTLY) {
            self.pspec_flags &~= FL_JUMPRELEASED;
            PlayerSpectatorStop();
        } else if(self.BUTTON_ATCK) {
            self.pspec_flags &~= FL_JUMPRELEASED;
            if(!SpectateNext())
                PlayerSpectatorStop();
        } else {
            if(!SpectateUpdate()) if(!SpectateNext())
                PlayerSpectatorStop();
        }
    } else {
        if(!(self.BUTTON_ATCK || self.BUTTON_ATCK2 || self.BUTTON_HOOK))
            self.pspec_flags |= FL_JUMPRELEASED;
    }
}

void ObserverThink()
{
#ifdef RM_SUPPORT_GHOST_OBSERVERS
    if(CVAR(sv_ghost_observers))
        setorigin(self, self.origin + [0, 0, frametime * 5 * sin(time + num_for_edict(self))]);
#endif

    if(self.flags & FL_JUMPRELEASED) {
		if(self.BUTTON_JUMP && !self.version_mismatch) {
			self.flags &~= FL_JUMPRELEASED;
			self.flags |= FL_SPAWNING;
		} else if(self.BUTTON_ATCK && !self.version_mismatch) {
			self.flags &~= FL_JUMPRELEASED;
			if(SpectateNext() == 1) {
				self.classname = "spectator";
			}
		}
	} else {
		if(!(self.BUTTON_ATCK || self.BUTTON_JUMP)) {
			self.flags |= FL_JUMPRELEASED;
			if(self.flags & FL_SPAWNING)
			{
                self.flags &~= FL_SPAWNING;
                LeaveSpectatorMode();
				return;
			}
		}
	}
}

void SpectatorThink()
{
    SpectatorImpulse();

	if (self.flags & FL_JUMPRELEASED) {
		if (self.BUTTON_JUMP && !self.version_mismatch) {
			self.flags &~= FL_JUMPRELEASED;
			self.flags |= FL_SPAWNING;
		} else if(self.BUTTON_ATCK) {
			self.flags &~= FL_JUMPRELEASED;
			if(SpectateNext() == 1) {
				self.classname = "spectator";
			} else {
				self.classname = "observer";
				PutClientInServer();
			}
		} else if(self.BUTTON_ATCK2) {
            self.BUTTON_ATCK2 = FALSE;
			self.flags &~= FL_JUMPRELEASED;
			self.classname = "observer";
			PutClientInServer();
		} else {
			if(!SpectateUpdate()) if(!SpectateNext()) {
                PutObserverInServer();
            }
		}
	} else {
		if (!(self.BUTTON_ATCK || self.BUTTON_ATCK2)) {
			self.flags |= FL_JUMPRELEASED;
			if(self.flags & FL_SPAWNING)
			{
                self.flags &~= FL_SPAWNING;
                LeaveSpectatorMode();
				return;
			}
		}
	}
	self.flags |= FL_CLIENT | FL_NOTARGET;
}

.float touchexplode_time;

/*
=============
PlayerPreThink

Called every frame for each client before the physics are run
=============
*/
void() ctf_setstatus;
void() nexball_setstatus;
.float items_added;
.float namecheck;
.float acctime;

.float jumpholdtime;
.float alivetime;
.float frozentime;

float domination_PlayerPreThink();
void PlayerPreThink (void)
{
    if(clienttype(self.clientcamera) == CLIENTTYPE_NOTACLIENT)
        self.clientcamera = self;
    self.clientdataent = self.clientcamera;

	self.stat_game_starttime = game_starttime;
	self.stat_allow_oldnexbeam = g_allow_oldnexbeam;
	self.stat_leadlimit = leadlimit;

    float isplayer, isspec, isobs;

    self.roundstate_stat = roundstate;
    
    if(self.classname == "player")
        isplayer = TRUE;
    else if(self.classname == "spectator")
        isspec = TRUE;
    else if(self.classname == "observer") {
        isobs = TRUE;
        WarpZone_HandleObserver();
    }

    if(isplayer && self.clientcamera != self && !gameover)
        PlayerSpectatorThink();

    if(isplayer)
    if(roundstate == ROUNDSTATE_GAME) {
        self.playtime += frametime;
        
        if(sv_scoreboard_noob_column || sv_scoreboard_alive_column) {
            if(!PlayerIsDead(self)) {
                self.alivetime += frametime;
                if(self.BUTTON_JUMP)
                    self.jumpholdtime += frametime;
            }
        }

        if(time > self.playtimeupdate) {
            self.playtimeupdate = time + 30;

            PlayerScore_Set(self, SP_PLAYTIME, self.playtime);
            if(sv_scoreboard_noob_column)
                PlayerScore_Set(self, SP_NOOB, rint(255 * self.jumpholdtime / self.alivetime));
            if(sv_scoreboard_alive_column)
                PlayerScore_Set(self, SP_ALIVE, rint(255 * self.alivetime / self.playtime));
        }
    }

	if(blockSpectators && frametime)
		// WORKAROUND: only use dropclient in server frames (frametime set). Never use it in cl_movement frames (frametime zero).
		checkSpectatorBlock();

	zoomstate_set = 0;
    
    if(frametime)
    if(isplayer)
    if(time < self.hg_plasmalock) {
        if(!self.hg_plasmalock_owner.iscreature) {
            self.hg_plasmalock_owner = world;
            self.hg_plasmalock = 0;
            self.hg_plasmalock_nexteffect = time + frametime;
        }
        
        if(time > self.hg_plasmalock_nexteffect) {
            float edelay = 0.35;
            self.hg_plasmalock_nexteffect = time + edelay;
            vector eorigin = self.origin + self.maxs_z * '0 0 0.5';
            
            float pdmg = CVAR(g_nadgets_plasma_projectile_frozenlock_dps) * edelay;
            if(pdmg)
                RadiusDamage(self, self.hg_plasmalock_owner, pdmg, pdmg, CVAR(g_nadgets_plasma_projectile_frozenlock_dps_radius), world, CVAR(g_nadgets_plasma_projectile_frozenlock_dps_force), self.projectiledeathtype, world);
            
            te_csqc_lightningarc(eorigin + randomvec() * 100, eorigin + randomvec() * 10, TRUE, self.hg_plasmalock_owner.team);
            sound(self, CHAN_AUTO, "sound/weapons/electro_impact.wav", 0.4, 1.5);
        }
    }
    
    if(frametime)
    if(time > self.namecheck)
	if(self.netname_previous != self.netname)
	{
		if(CVAR(sv_eventlog))
			GameLogEcho(strcat(":name:", ftos(self.playerid), ":", self.netname));
		if(self.netname_previous)
			strunzone(self.netname_previous);
		self.netname_previous = strzone(self.netname);
        self.namecheck = time + 0.5;
	}

	// GOD MODE info
	if(!(self.flags & FL_GODMODE)) if(self.max_armorvalue)
	{
		sprint(self, strcat("godmode saved you ", ftos(self.max_armorvalue), " units of damage, cheater!\n"));
		self.max_armorvalue = 0;
	}

#ifdef TETRIS
	if (TetrisPreFrame())
		return;
#endif

    Buffs_ClientFrame();
    Term_Hook_PlayerPreThink();

    float oldspectatee_status;
    oldspectatee_status = self.spectatee_status;

    self.spectatee_status = num_for_edict(self.clientcamera);

    if(!isobs && self.spectatee_status == num_for_edict(self))
        self.spectatee_status = 0;

    if(self.spectatee_status != oldspectatee_status)
    {
        ClientData_Touch(self);

        SpecInfo_Update(self, SPECINFO_LIST | SPECINFO_HUD);
        if(oldspectatee_status > 0)
            SpecInfo_Update(edict_num(oldspectatee_status), SPECINFO_LIST);

        if(g_race || g_cts)
            race_InitSpectator();
    }

	if(isplayer) {
        if(self.joinqueue)
            JoinQ_Remove(self);
        
        W_PlayerPreThinkHook();

        if(frametime) {
            if(CVAR(sv_noplayershadows) || Buffs_Present(self, BUFF_STEALTH))
                self.effects |= EF_NOSHADOW;
            else
                self.effects &~= EF_NOSHADOW;
        }

        if(sv_scoreboard_acc_column)
        if(time > self.acctime) {
            float hit = self.accstat_hits;
            float total = self.accstat_shots;
            
            if(hit < 0 || total <= 0)
                PlayerScore_Set(self, SP_ACCURACY, -1);
            else
                PlayerScore_Set(self, SP_ACCURACY, (hit / total) * 255);
            
            self.acctime = time + 5;
        }
        
        Freeze_Hook_PlayerPreThink();
        JB_PlayerPreThink();
        domination_PlayerPreThink();
        CheckRules_Player();

		if(intermission_running) {
			IntermissionThink ();	// otherwise a button could be missed between
			return;					// the think tics
		}

		if(self.teleport_time)
		if(time > self.teleport_time)
		{
			self.teleport_time = 0;
			self.effects = self.effects - (self.effects & EF_NODRAW);
		}

		Nixnex_GiveCurrentWeapon();

		if(frametime) { // don't do this in cl_movement frames, just in server ticks
			UpdateSelectedPlayer();
			player_powerups();
        }

		//don't allow the player to turn around while game is paused!
		if(timeoutStatus == 2) {
			self.v_angle = self.lastV_angle;
			self.angles = self.lastV_angle;
			self.fixangle = TRUE;
		}
        
		HG_PlayerFrame();

		if (self.deadflag != DEAD_NO)
		{
			float button_pressed, force_respawn;
			if(self.personal && g_race_qualifying)
			{
				if(time > self.death_time)
				{
					self.death_time = time + 1; // only retry once a second
					respawn();
					self.impulse = 141;
				}
			}
			else
			{
				if(frametime)
					player_anim();
				button_pressed = (self.BUTTON_ATCK || self.BUTTON_JUMP || self.BUTTON_ATCK2 || self.BUTTON_HOOK || self.BUTTON_USE);
				force_respawn = (g_freeze || g_lms || g_clanarena || g_jailbreak || CVAR(g_forced_respawn));
				
				if (jb_roundover) {
					// lol no respawn for ya
				} else if (self.deadflag == DEAD_DYING)
				{
					if(force_respawn)
						self.deadflag = DEAD_RESPAWNING;
					else if(!button_pressed)
						self.deadflag = DEAD_DEAD;
				}
				else if (self.deadflag == DEAD_DEAD)
				{
					if(button_pressed)
						self.deadflag = DEAD_RESPAWNABLE;
				}
				else if (self.deadflag == DEAD_RESPAWNABLE)
				{
					if(!button_pressed)
						self.deadflag = DEAD_RESPAWNING;
				}
				else if (self.deadflag == DEAD_RESPAWNING)
				{
					if(time > self.death_time)
					{
						self.death_time = time + 1; // only retry once a second
						respawn();
					}
				} else if(self.deadflag != DEAD_PERMANENTLY)
				    ShowRespawnCountdown();
			}
			return;
		}

		if(g_touchexplode)
		if(time > self.touchexplode_time)
		if(isplayer)
		if(self.deadflag == DEAD_NO)
		if not(IS_INDEPENDENT_PLAYER(self))
		FOR_EACH_PLAYER(other) if(self != other)
		{
			if(time > other.touchexplode_time)
			if(other.classname == "player")
			if(other.deadflag == DEAD_NO)
			if not(IS_INDEPENDENT_PLAYER(other))
			if(boxesoverlap(self.absmin, self.absmax, other.absmin, other.absmax))
			{
				PlayerTouchExplode(self, other);
				self.touchexplode_time = other.touchexplode_time = time + 0.2;
			}
		}

		if(g_lms && !self.deadflag)
        if(CVAR(g_lms_campcheck_interval))
		{
			vector dist;

			// calculate player movement (in 2 dimensions only, so jumping on one spot doesn't count as movement)
			dist = self.prevorigin - self.origin;
			dist_z = 0;
			self.lms_traveled_distance += fabs(vlen(dist));

			if((CVAR(g_campaign) && !campaign_bots_may_start) || (time < game_starttime))
			{
				self.lms_nextcheck = time + CVAR(g_lms_campcheck_interval)*2;
				self.lms_traveled_distance = 0;
			}

			if(time > self.lms_nextcheck)
			{
				//sprint(self, "distance: ", ftos(self.lms_traveled_distance), "\n");
				if(self.lms_traveled_distance < CVAR(g_lms_campcheck_distance))
				{
					centerprint(self, CVAR_STR(g_lms_campcheck_message));
					// FIXME KadaverJack: gibbing player here causes playermodel to bounce around, instead of eye.md3
					// I wasn't able to find out WHY that happens, so I put a workaround in place that shall prevent players from being gibbed :(
					Damage(self, self, self, bound(0, CVAR(g_lms_campcheck_damage), self.health + self.armorvalue * CVAR(g_balance_armor_blockpercent) + 5), DEATH_CAMP, self.origin, '0 0 0');
				}
				self.lms_nextcheck = time + CVAR(g_lms_campcheck_interval);
				self.lms_traveled_distance = 0;
			}
		}

		self.prevorigin = self.origin;

		if ((self.BUTTON_CROUCH && !self.hook.state) || self.health <= g_bloodloss || sm_IsSoulMate(self))
		{
			if (!self.crouch)
			{
				self.crouch = TRUE;
				self.view_ofs = PL_CROUCH_VIEW_OFS;
				setsize (self, PL_CROUCH_MIN, PL_CROUCH_MAX);
				setanim(self, self.anim_duck, FALSE, TRUE, TRUE);
			}
		}
		else
		{
			if (self.crouch)
			{
				tracebox(self.origin, PL_MIN, PL_MAX, self.origin, FALSE, self);
				if (!trace_startsolid || self.soulmate)
				{
					self.crouch = FALSE;
					self.view_ofs = PL_VIEW_OFS;
					setsize (self, PL_MIN, PL_MAX);
				}
			}
		}

		if(self.health <= g_bloodloss && self.deadflag == DEAD_NO)
		{
			if(self.bloodloss_timer < time)
			{
				self.event_damage(self, self, 1, DEATH_ROT, self.origin, '0 0 0');
				self.bloodloss_timer = time + 0.5 + random() * 0.5;
			}
		}

		FixPlayermodel();
		GrapplingHookFrame();

		if(frametime)
		{
			self.items &~= self.items_added;

			W_WeaponFrame();
            Akimbo_WeaponFrame();

			self.items_added = 0;
			if(self.items & IT_JETPACK)
				if(self.items & IT_FUEL_REGEN || self.ammo_fuel >= 0.01)
					self.items_added |= IT_FUEL;

			self.items |= self.items_added;
		}

		player_regen();
		if(frametime)
			player_anim();

		if (g_minstagib)
			minstagib_ammocheck();

		ctf_setstatus();
		nexball_setstatus();

		self.dmg_team = max(0, self.dmg_team - CVAR(g_teamdamage_resetspeed) * frametime);

        W_Zapper_Cooloff();

        if(time >= self.w_pickup_confirmation + frametime * 3)
            self.w_pickup_confirmation_stat = 0;
	} else {
        if(self.solid) {
            bprint("BUG: spectator/observer was solid\n");
            localcmd("prvm_edict server ", ftos(num_for_edict(self)), "\n");
            self.solid = SOLID_NOT;
        }
        
        if(gameover) {
            if(intermission_running)
                IntermissionThink ();	// otherwise a button could be missed between
            return;
        } else if(self.classname == "observer") {
            ObserverThink();
        } else if(self.classname == "spectator") {
            SpectatorThink();
        }
    }

	if(!zoomstate_set)
		SetZoomState(self.BUTTON_ZOOM || (self.BUTTON_ATCK2 && self.weapon == WEP_NEX && !CVAR(g_balance_nex_secondary)));

	if(self.teamkill_soundtime)
	if(time > self.teamkill_soundtime)
	{
		self.teamkill_soundtime = 0;

		entity oldpusher, oldself;

		oldself = self; self = self.teamkill_soundsource;
		oldpusher = self.pusher; self.pusher = oldself;

		PlayerSound(playersound_teamshoot, CHAN_VOICE, VOICETYPE_LASTATTACKER_ONLY);

		self.pusher = oldpusher;
		self = oldself;
	}

	if(self.taunt_soundtime)
	if(time > self.taunt_soundtime)
	{
		self.taunt_soundtime = 0;
		PlayerSound(playersound_taunt, CHAN_VOICE, VOICETYPE_AUTOTAUNT);
	}
    
    if(isplayer)
        target_voicescript_next(self);
}

// on dragger:
.entity dragentity;
.float draggravity;
.float dragspeed; // speed of mouse wheel action
.float dragdistance; // distance of dragentity's draglocalvector from view_ofs
.vector draglocalvector; // local attachment vector of the dragentity
.float draglocalangle;
// on draggee:
.entity draggedby;
.float dragmovetype;
void Drag_Begin(entity dragger, entity draggee, vector touchpoint)
{
	float tagscale;

	draggee.dragmovetype = draggee.movetype;
	draggee.draggravity = draggee.gravity;
	draggee.movetype = MOVETYPE_WALK;
	draggee.gravity = 0.00001;
	draggee.flags &~= FL_ONGROUND;
	draggee.draggedby = dragger;

	dragger.dragentity = draggee;

	dragger.dragdistance = vlen(touchpoint - dragger.origin - dragger.view_ofs);
	dragger.draglocalangle = draggee.angles_y - dragger.v_angle_y;
	touchpoint = touchpoint - gettaginfo(draggee, 0);
	tagscale = pow(vlen(v_forward), -2);
	dragger.draglocalvector_x = touchpoint * v_forward * tagscale;
	dragger.draglocalvector_y = touchpoint * v_right * tagscale;
	dragger.draglocalvector_z = touchpoint * v_up * tagscale;

	dragger.dragspeed = 64;
}

void Drag_Finish(entity dragger)
{
	entity draggee;
	draggee = dragger.dragentity;
	if(dragger)
		dragger.dragentity = world;
	draggee.draggedby = world;
	draggee.movetype = draggee.dragmovetype;
	draggee.gravity = draggee.draggravity;

	switch(draggee.movetype)
	{
		case MOVETYPE_TOSS:
		case MOVETYPE_WALK:
		case MOVETYPE_STEP:
		case MOVETYPE_FLYMISSILE:
		case MOVETYPE_BOUNCE:
		case MOVETYPE_BOUNCEMISSILE:
			break;
		default:
			draggee.velocity = '0 0 0';
			break;
	}

	if((draggee.flags & FL_ITEM) && (vlen(draggee.velocity) < 32))
	{
		draggee.velocity = '0 0 0';
		draggee.flags |= FL_ONGROUND; // floating items are FUN
	}
}

float Drag_IsDraggable(entity draggee)
{
	// TODO add more checks for bad stuff here
	if(draggee.classname == "func_bobbing")
		return FALSE;
	if(draggee.classname == "door") // FIXME find out why these must be excluded, or work around the problem (trying to drag these causes like 4 fps)
		return FALSE;
	if(draggee.classname == "plat")
		return FALSE;
	if(draggee.classname == "func_button")
		return FALSE;
	if(draggee.model == "")
		return FALSE;
	if(draggee.classname == "spectator")
		return FALSE;
	if(draggee.classname == "observer")
		return FALSE;
	if(draggee.classname == "exteriorweaponentity")
		return FALSE;

	return TRUE;
}

float Drag_MayChangeAngles(entity draggee)
{
	// TODO add more checks for bad stuff here
	if(substring(draggee.model, 0, 1) == "*")
		return FALSE;
	return TRUE;
}

void Drag_MoveForward(entity dragger)
{
	dragger.dragdistance += dragger.dragspeed;
}

void Drag_SetSpeed(entity dragger, float s)
{
	dragger.dragspeed = pow(2, s);
}

void Drag_MoveBackward(entity dragger)
{
	dragger.dragdistance = max(0, dragger.dragdistance - dragger.dragspeed);
}

void Drag_Update(entity dragger)
{
	vector curorigin, neworigin, goodvelocity;
	float f;
	entity draggee;

	draggee = dragger.dragentity;
	draggee.flags &~= FL_ONGROUND;

	curorigin = gettaginfo(draggee, 0);
	curorigin = curorigin + v_forward * dragger.draglocalvector_x + v_right * dragger.draglocalvector_y + v_up * dragger.draglocalvector_z;
	makevectors(dragger.v_angle);
	neworigin = dragger.origin + dragger.view_ofs + v_forward * dragger.dragdistance;
	goodvelocity = (neworigin - curorigin) * (1 / frametime);

	while(draggee.angles_y - dragger.v_angle_y - dragger.draglocalangle > 180)
		dragger.draglocalangle += 360;
	while(draggee.angles_y - dragger.v_angle_y - dragger.draglocalangle <= -180)
		dragger.draglocalangle -= 360;

	f = min(frametime * 10, 1);
	draggee.velocity = draggee.velocity * (1 - f) + goodvelocity * f;

	if(Drag_MayChangeAngles(draggee))
		draggee.angles_y = draggee.angles_y * (1 - f) + (dragger.v_angle_y + dragger.draglocalangle) * f;

	draggee.ltime = max(servertime + serverframetime, draggee.ltime); // fixes func_train breakage

	te_lightning1(dragger, dragger.origin + dragger.view_ofs, curorigin);
}

float Drag_CanDrag(entity dragger)
{
	return (dragger.deadflag == DEAD_NO) || (dragger.classname == "player");
}

float Drag_IsDragging(entity dragger)
{
	if(!dragger.dragentity)
		return FALSE;
	if(wasfreed(dragger.dragentity) || dragger.dragentity.draggedby != dragger)
	{
		dragger.dragentity = world;
		return FALSE;
	}
	if(!Drag_CanDrag(dragger) || !Drag_IsDraggable(dragger.dragentity))
	{
		Drag_Finish(dragger);
		return FALSE;
	}
	return TRUE;
}

void Drag_MoveDrag(entity from, entity to)
{
	if(from.draggedby)
	{
		to.draggedby = from.draggedby;
		to.draggedby.dragentity = to;
		from.draggedby = world;
	}
}

/*
=============
PlayerPostThink

Called every frame for each client after the physics are run
=============
*/
.float idlekick_lasttimeleft;
void PlayerPostThink (void)
{
    self.owner = world;

	// Savage: Check for nameless players
	if (strlen(self.netname) < 1) {
		self.netname = "Player";
		stuffcmd(self, "seta _cl_name Player\n");
	}

    if(self.movement)
    if(self.specdelay_ent) {
        remove(self.specdelay_ent);
        self.specdelay_ent = world;
        bigprint_spec(self, "", "^1Cancelled", 1);
    }

	if(sv_maxidle && frametime)
	{
		// WORKAROUND: only use dropclient in server frames (frametime set). Never use it in cl_movement frames (frametime zero).
		float timeleft;
		timeleft = ceil(sv_maxidle - (time - self.parm_idlesince));
		if(timeleft <= 0)
		{
			bprint("^3", self.netname, "^3 was kicked for idling.\n");
			announce(self, "announcer/robotic/terminated.wav");
			dropclient(self);
			return;
		}
		else if(timeleft <= 10)
		{
			if(timeleft != self.idlekick_lasttimeleft)
			{
				centerprint_atprio(self, CENTERPRIO_IDLEKICK, strcat("^3Stop idling!\n^3Disconnecting in ", ftos(timeleft), "..."));
				announce(self, strcat("announcer/robotic/", ftos(timeleft), ".wav"));
			}
		}
		else
		{
			centerprint_expire(self, CENTERPRIO_IDLEKICK);
		}
		self.idlekick_lasttimeleft = timeleft;
	}

#ifdef TETRIS
	if(self.impulse == 100)
		ImpulseCommands();
	if (TetrisPostFrame())
		return;
#endif

	if(sv_cheats || self.maycheat)
		if(Drag_CanDrag(self))
			if(self.BUTTON_DRAG)
				if(!self.dragentity)
					if(self.cursor_trace_ent)
						if(Drag_IsDraggable(self.cursor_trace_ent))
						{
							if(self.cursor_trace_ent.draggedby)
								Drag_Finish(self.cursor_trace_ent.draggedby);
							if(self.cursor_trace_ent.tag_entity)
								detach_sameorigin(self.cursor_trace_ent);
							Drag_Begin(self, self.cursor_trace_ent, self.cursor_trace_endpos);
						}

	if(Drag_IsDragging(self))
	{
		if(self.BUTTON_DRAG)
		{
			if(self.impulse == 10 || self.impulse == 15 || self.impulse == 18)
			{
				Drag_MoveForward(self);
				self.impulse = 0;
			}
			else if(self.impulse == 12 || self.impulse == 16 || self.impulse == 19)
			{
				Drag_MoveBackward(self);
				self.impulse = 0;
			}
			else if(self.impulse >= 1 && self.impulse <= 9)
			{
				Drag_SetSpeed(self, self.impulse - 1);
			}
			else if(self.impulse == 14)
			{
				Drag_SetSpeed(self, 9);
			}

			if(frametime)
				Drag_Update(self);
		}
		else
		{
			Drag_Finish(self);
		}
	}

	if(self.classname == "player") {
        W_Clip_Stats_Update();
		CheckRules_Player();
		UpdateChatBubble();
		UpdateTeamBubble();
		if (self.impulse)
			ImpulseCommands();
		if (intermission_running)
			return;		// intermission or finale

		GetPressedKeys();

        if(CVAR(sv_gameplayfix_outofworldboundskill) && self.deadflag == DEAD_NO) {
            if(!boxesoverlap(world.absmin, world.absmax, self.absmin, self.absmax)) {
                Damage(self, world, world, 100000, DEATH_GUARANTEED, self.origin, '0 0 0');
            }
        }
	}

	Arena_Warmup();

	if(self.waypointsprite_attachedforcarrier)
		WaypointSprite_UpdateHealth(self.waypointsprite_attachedforcarrier, '1 0 0' * healtharmor_maxdamage(self.health, self.armorvalue, CVAR(g_balance_armor_blockpercent)));
}
