float maxspawned;
float numspawned;
float arena_roundbased;
.float spawned;
.entity spawnqueue_next;
.entity spawnqueue_prev;
.float spawnqueue_in;
entity spawnqueue_first;
entity spawnqueue_last;
entity champion;
float warmup;

void PutObserverInServer();
void PutClientInServer();
void(entity e) ReturnFlag;
void dom_controlpoint_setup();
void onslaught_generator_reset();
void onslaught_controlpoint_reset();
void func_breakable_reset();
void assault_objective_reset();
void target_assault_roundend_reset();

.float redalive_stat, bluealive_stat, yellowalive_stat, pinkalive_stat;
float redspawned, bluespawned, yellowspawned, pinkspawned;
float totalspawned;
void SetPlayerTeam(entity pl, float t, float s, float noprint);
void W_SetSecondary(entity, float);

/**
 * Resets the state of all clients, items, flags, runes, keys, weapons, waypoints, ... of the map.
 * Sets the 'warmup' global variable.
 */
void reset_map(float dorespawn)
{
	entity oldself;
	oldself = self;

    JoinQ_PopMany();

	if(g_arena)
	{
		if(CVAR(g_arena_warmup))
			warmup = time + CVAR(g_arena_warmup);
	}
	else if(g_freezetag)
		warmup = time + CVAR(g_freezetag_warmup);
	else if(g_jailbreak)
		warmup = time + CVAR(g_jailbreak_warmup);
    else if(g_clanarena)
        warmup = time + CVAR(g_clanarena_warmup);

	lms_lowest_lives = 999;
	lms_next_place = player_count;

	race_ReadyRestart();
    
    if(CVAR(g_swap_teams))
        SwapTeams();
    
    Buffs_Randomize(world, FALSE);
    
	for(self = world; (self = nextent(self)); )
	if(clienttype(self) == CLIENTTYPE_NOTACLIENT)
	{
		if(self.reset)
		{
			self.reset();
			continue;
		}

		if(self.team_saved)
			self.team = self.team_saved;

		if(self.flags & FL_PROJECTILE) // remove any projectiles left
		{
			stopsound(self, CHAN_PAIN);
			remove(self);
		}
	}
    
	// Waypoints and assault start come LAST
	for(self = world; (self = nextent(self)); )
	if(clienttype(self) == CLIENTTYPE_NOTACLIENT)
	{
		if(self.reset2)
		{
			self.reset2();
			continue;
		}
	}

    if(teamcount_balancenext)
        TeamCount_BalanceTeams();
    
	// Moving the player reset code here since the player-reset depends
	// on spawnpoint entities which have to be reset first --blub
	if(dorespawn)
	FOR_EACH_CLIENT(self) {
        self.playtimeupdate = time;
		if(self.flags & FL_CLIENT && self.scorekeeper)				// reset all players
		{
            if(g_freeze)
                self.frozenrow = 0;
            
            if(g_nadgets) {
                HG_DO_IN_ALL_CONTEXTS({
                    if(self.hg_ctx_type_picked_nextround >= 0)
                        self.hg_ctx_type_picked = self.hg_ctx_type_picked_nextround;
                    self.hg_ctx_type_picked_nextround = -1;  
                })

                if(self.hg_optout_nextround >= 0)
                    self.hg_optout = self.hg_optout_nextround;

                self.hg_optout_nextround = -1;
            }

            if(g_weaponarena_secondary) {
                if(self.w_secondary_nextround) {
                    self.w_secondary_picked = self.w_secondary_nextround;
                    self.w_secondary_nextround = 0;
                }

                W_SetSecondary(self, self.w_secondary_picked);
            }

			if(g_arena)
			{
				if(self.spawned)
					PutClientInServer();
				else
					PutObserverInServer();
			}
			else if(g_freezetag || g_totaldomination || g_jailbreak || g_clanarena)
			{
				if(self.classname == "player") {
					PutClientInServer();
                    if(g_clanarena)
                        PlayerScore_UnsetFlags(self, SPFLAG_FROZEN);
                }
			}
			else
			{
				/*
				only reset players if a restart countdown is active
				this can either be due to cvar sv_ready_restart_after_countdown having set
				restart_mapalreadyrestarted to 1 after the countdown ended or when
				sv_ready_restart_after_countdown is not used and countdown is still running
				*/
				if (restart_mapalreadyrestarted || (time < game_starttime))
				{
					//NEW: changed behaviour so that it prevents that previous spectators/observers suddenly spawn as players
					if (self.classname == "player") {
						//PlayerScore_Clear(self);
						if(g_lms)
							PlayerScore_Add(self, SP_LMS_LIVES, LMS_NewPlayerLives());
						self.killcount = 0;
						//stop the player from moving so that he stands still once he gets respawned
						self.velocity = '0 0 0';
						self.avelocity = '0 0 0';
						self.movement = '0 0 0';
						PutClientInServer();
					}
				}
			}
            
            if(g_nadgets) if(self.classname == "player") {
                HG_ResetState(self, FALSE);
                self.hg_nadesused = 0;
                
                if(self.hg_alwaysask)
                    HG_ShowMenu(TRUE);
            }
		}
	}

	if(g_keyhunt)
		kh_Controller_SetThink(CVAR(g_balance_keyhunt_delay_round)+(game_starttime - time), "", kh_StartRound);

	if(g_arena)
	if(champion)
		UpdateFrags(champion, +1);

	self = oldself;
}

void Spawnqueue_Insert(entity e)
{
	if(e.spawnqueue_in)
		return;
	dprint(strcat("Into queue: ", e.netname, "\n"));
	e.spawnqueue_in = TRUE;
	e.spawnqueue_prev = spawnqueue_last;
	e.spawnqueue_next = world;
	if(spawnqueue_last)
		spawnqueue_last.spawnqueue_next = e;
	spawnqueue_last = e;
	if(!spawnqueue_first)
		spawnqueue_first = e;
}

void Spawnqueue_Remove(entity e)
{
	if(!e.spawnqueue_in)
		return;
	dprint(strcat("Out of queue: ", e.netname, "\n"));
	e.spawnqueue_in = FALSE;
	if(e == spawnqueue_first)
		spawnqueue_first = e.spawnqueue_next;
	if(e == spawnqueue_last)
		spawnqueue_last = e.spawnqueue_prev;
	if(e.spawnqueue_prev)
		e.spawnqueue_prev.spawnqueue_next = e.spawnqueue_next;
	if(e.spawnqueue_next)
		e.spawnqueue_next.spawnqueue_prev = e.spawnqueue_prev;
	e.spawnqueue_next = world;
	e.spawnqueue_prev = world;
}

void Spawnqueue_Unmark(entity e)
{
	if(!e.spawned)
		return;
	e.spawned = FALSE;
	numspawned = numspawned - 1;
}

void Spawnqueue_Mark(entity e)
{
	if(e.spawned)
		return;
	e.spawned = TRUE;
	numspawned = numspawned + 1;
}

/**
 * If roundbased arena game mode is active, it centerprints the texts for the
 * player when player is waiting for the countdown to finish.
 * Blocks the players movement while countdown is active.
 * Unblocks the player once the countdown is over.
 * 
 * Called in PlayerPostThink()
 */
void Arena_Warmup()
{
	float f;
	string msg;

	if(!g_arena || !arena_roundbased || (time < game_starttime))
		return;

	f = rint(warmup - time);

	if(time < warmup && self.spawned)
	{
		if(champion)
			msg = strcat(msg, "The Champion is ", champion.netname, "^7\n");

		if(f)
			msg = strcat(msg, "Round will start in ", ftos(f),"\n");
		else
		{
			if(self.spawned)
				msg = strcat(msg, "^1Fight!\n");
		}

		centerprint(self, msg);

		if(self.spawned)
			self.movetype = MOVETYPE_NONE;

		self.velocity = '0 0 0';
		self.avelocity = '0 0 0';
		self.movement = '0 0 0';
		//self.fixangle = TRUE;
	}
	else if(self.movetype == MOVETYPE_NONE)
	{
		self.movetype = MOVETYPE_WALK;
		centerprint(self, "\n");
	}

}

void count_spawned_players()
{
	// TODO fix "*spawned" name, it should rather be "*players" or so
	// not doing this now to prevent merge hell with Tag
	// fix after merging with Tag

	// count amount of players in each team
	totalspawned = redspawned = bluespawned = yellowspawned = pinkspawned = 0;
	FOR_EACH_PLAYER(self) {
		if (self.team == COLOR_TEAM1)
		{
			redspawned += 1;
			totalspawned += 1;
		}
		else if (self.team == COLOR_TEAM2)
		{
			bluespawned += 1;
			totalspawned += 1;
		}
		else if (self.team == COLOR_TEAM3)
		{
			yellowspawned += 1;
			totalspawned += 1;
		}
		else if (self.team == COLOR_TEAM4)
		{
			pinkspawned += 1;
			totalspawned += 1;
		}
	}
}

/**
 * This function finds out whether an arena round is over 1 player is left.
 * It determines the last player who's still alive and saves it's entity reference
 * in the global variable 'champion'. Then the new enemy/enemies are put into the server.
 * 
 * Gets called in StartFrame()
 */
void Spawnqueue_Check()
{
    if(!g_freeze)
        count_spawned_players();
	if(time < warmup + 1 || roundstate == ROUNDSTATE_GAME)
		return;

	//extend next_round if it isn't set yet and only 1 player is spawned
	
	if(g_freezetag || g_totaldomination || g_jailbreak || g_clanarena)
	{
		if((next_round && next_round < time))
		{
			if(intermission_running)
			{
				next_round = 0;
				return;
			}

			next_round = 0;
			reset_map(TRUE);
		}
	}
	else
	{
		if(!next_round)
		if(numspawned < 2)
			next_round = time + 3;

		if(!arena_roundbased || (next_round && next_round < time && player_count > 1))
		{
			next_round = 0;

			if(arena_roundbased)
			{
				champion = find(world, classname, "player");
				while(champion && champion.deadflag)
					champion = find(champion, classname, "player");
				reset_map(TRUE);
			}

			while(numspawned < maxspawned && spawnqueue_first)
			{
				self = spawnqueue_first;

				bprint ("^4", self.netname, "^4 is the next challenger\n");

				Spawnqueue_Remove(self);
				Spawnqueue_Mark(self);

				self.classname = "player";
				PutClientInServer();
			}
		}
	}
}
