/*============================================

      Wazat's Nexuiz Grappling Hook

        Contact: Wazat1@gmail.com

============================================*/

.string aiment_classname;
.float aiment_deadflag;
void SetMovetypeFollow(entity ent, entity e)
{
	ent.movetype = MOVETYPE_FOLLOW; // make the hole follow
	ent.solid = SOLID_NOT; // MOVETYPE_FOLLOW is always non-solid
	ent.aiment = e; // make the hole follow bmodel
	ent.punchangle = e.angles; // the original angles of bmodel
	ent.view_ofs = ent.origin - e.origin; // relative origin
	ent.v_angle = ent.angles - e.angles; // relative angles
	ent.aiment_classname = strzone(e.classname);
	ent.aiment_deadflag = e.deadflag;
}
void UnsetMovetypeFollow(entity ent)
{
	ent.movetype = MOVETYPE_FLY;
	PROJECTILE_MAKETRIGGER(ent);
	ent.aiment = world;
}
float LostMovetypeFollow(entity ent)
{
	if(ent.aiment)
	{
		if(ent.aiment.classname != ent.aiment_classname)
			return 1;
		if(ent.aiment.deadflag != ent.aiment_deadflag)
			return 1;
	}
	return 0;
}

.float hook_length;
.float hook_switchweapon;
.float hook_length_initial;

void RemoveGrapplingHook(entity pl)
{
	if(pl.hook == world)
		return;
	remove(pl.hook);
	pl.hook = world;
	if(pl.movetype == MOVETYPE_FLY)
		pl.movetype = MOVETYPE_WALK;
}

void GrapplingHookThink();
void GrapplingHook_Stop()
{
	pointparticles(particleeffectnum("grapple_impact"), self.origin, '0 0 0', 1);
	sound (self, CHAN_PROJECTILE, "weapons/hook_impact.wav", VOL_BASE, ATTN_NORM);

	self.state = 1;
	self.think = GrapplingHookThink;
	self.nextthink = time;
	self.touch = SUB_Null;
	self.velocity = '0 0 0';
	self.movetype = MOVETYPE_NONE;
	self.hook_length = self.hook_length_initial = -1;
}

.float last_dmg;
void GrapplingHookThink()
{
	float spd, dist, minlength, pullspeed, ropestretch, ropeairfriction, rubberforce, newlength, rubberforce_overstretch, dontpull, dontpull_limit;
	vector dir, org, end, v0, v, dv, myorg;
	if(self.owner.health <= 0 || self.owner.hook != self)	// how did that happen?
	{														// well, better fix it anyway
		remove(self);
		return;
	}
	if(LostMovetypeFollow(self))
	{
		RemoveGrapplingHook(self.owner);
		return;
	}

    if(self.aiment)
        WarpZone_RefSys_AddIncrementally(self, self.aiment);

	self.nextthink = time;

	makevectors(self.owner.v_angle);
	org = self.owner.origin + self.owner.view_ofs + v_forward * hook_shotorigin_x + v_right * hook_shotorigin_y + v_up * hook_shotorigin_z;
    myorg = WarpZone_RefSys_TransformOrigin(self.owner, self, org);

	if(self.hook_length < 0)
		self.hook_length = vlen(myorg - self.origin);

	if(self.state == 1)
	{
		pullspeed = CVAR(g_balance_grapplehook_speed_pull);//2000;
		// speed the rope is pulled with

		rubberforce = CVAR(g_balance_grapplehook_force_rubber);//2000;
		// force the rope will use if it is stretched

		rubberforce_overstretch = CVAR(g_balance_grapplehook_force_rubber_overstretch);//1000;
		// force the rope will use if it is stretched

		minlength = CVAR(g_balance_grapplehook_length_min);//100;
		// minimal rope length
		// if the rope goes below this length, it isn't pulled any more

		ropestretch = CVAR(g_balance_grapplehook_stretch);//400;
		// if the rope is stretched by more than this amount, more rope is
		// given to you again

		ropeairfriction = CVAR(g_balance_grapplehook_airfriction);//0.2
		// while hanging on the rope, this friction component will help you a
		// bit to control the rope

		dontpull = CVAR(g_balance_grapplehook_dontpull);
		dontpull_limit = CVAR(g_balance_grapplehook_dontpull_limit);

		dir = self.origin - myorg;
		dist = vlen(dir);
		dir = normalize(dir);
        if(self.hook_length_initial < 0)
            self.hook_length_initial = dist;

		if(CVAR(g_grappling_hook_tarzan))
		{
			v = v0 = WarpZone_RefSys_TransformVelocity(self.owner, self, self.owner.velocity);
			
			// first pull the rope...
			if(self.owner.hook_state & HOOK_PULLING)
			{
				newlength = self.hook_length;
				newlength = max(newlength - pullspeed * frametime, minlength);

				if(newlength < dist - ropestretch) // overstretched?
				{
					newlength = dist - ropestretch;
					if(v * dir < 0) // only if not already moving in hook direction
						v = v + frametime * (if(dontpull) dir_x * '1 0 0' + dir_y * '0 1 0' else dir) * rubberforce_overstretch;
				}

				self.hook_length = newlength;
			}

			if(self.owner.hook_state & HOOK_RELEASING)
			{
				newlength = dist;
				self.hook_length = newlength;
			}
			else
			{
				// then pull the player
				spd = bound(0, (dist - self.hook_length) / ropestretch, 1);
                float pulled;
				
				if(!dontpull || (dontpull_limit && self.hook_length >= self.hook_length_initial)) {
                    pulled = TRUE;
					v = v * (1 - frametime * ropeairfriction);
					v = v + frametime * dir * spd * rubberforce;
				}

				dv = ((v - v0) * dir) * dir;
				if(CVAR(g_grappling_hook_tarzan) >= 2)
				{
					if(self.aiment.movetype == MOVETYPE_WALK)
					{
						//v = v - dv * 0.5;
						self.aiment.velocity = self.aiment.velocity - dv; //* 0.5;
						self.aiment.flags &~= FL_ONGROUND;
						self.aiment.pusher = self.owner;
						self.aiment.pushltime = time + CVAR(g_maxpushtime);
					}
				}
                
                if(pulled)
                    self.owner.flags &~= FL_ONGROUND;
			}

            self.owner.velocity = WarpZone_RefSys_TransformVelocity(self, self.owner, v);
		}
		else
		{
			end = self.origin - dir*50;
			dist = vlen(end - myorg);
			if(dist < 200)
				spd = dist * (pullspeed / 200);
			else
				spd = pullspeed;
			if(spd < 50)
				spd = 0;
			self.owner.velocity = dir*spd;
			self.owner.movetype = MOVETYPE_FLY;

			self.owner.flags &~= FL_ONGROUND;
		}
	}

    if(roundstate == ROUNDSTATE_GAME || roundstate == ROUNDSTATE_INITIAL_WARMUP)
	if(self.aiment.classname == "player") if(self.last_dmg < time)
	if not(g_freeze && self.aiment.frozen)
	if(!teams_matter || self.owner.team != self.aiment.team)
	if(CVAR(g_rocketminsta))
	{
		self.last_dmg = time + 0.1;
		self.owner.hitsound += 1;
		Damage(self.aiment, self.owner.hook, self.owner, 1, DEATH_HOOKFRAG, self.origin, '0 0 0');
		self.owner.health += 1;
	}
	
	makevectors(self.angles_x * '-1 0 0' + self.angles_y * '0 1 0');
    myorg = WarpZone_RefSys_TransformOrigin(self, self.owner, self.origin);
	te_beam(self.owner, myorg, org);
}

void GrapplingHookTouch (void)
{
	PROJECTILE_SKIPNONSOLID
	if(SUB_OwnerCheck())
		return;
	if(SUB_NoImpactCheck())
	{
		RemoveGrapplingHook(self.owner);
		return;
	}

	GrapplingHook_Stop();

	if(other) {
		if(other.movetype != MOVETYPE_NONE) {
            if(other.term_authed) {     // super evil
                RemoveGrapplingHook(self.owner);
                return;
            }
            
            if(time < other.hg_plasmalock) {
                te_csqc_lightningarc(other.origin + other.maxs_z * '0 0 0.5', self.owner.origin + self.owner.maxs_z * '0 0 0.5', TRUE, other.hg_plasmalock_owner.team);
                Damage(self.owner, other.hg_plasmalock_owner, other.hg_plasmalock_owner, CVAR(g_nadgets_plasma_projectile_frozenlock_hookdamage), HG_PLASMA, '0 0 0', '0 0 0');
                RemoveGrapplingHook(self.owner);
                return;
            }
            
            if(!other.frozen)
            if(other.classname == "player")
            if(!CVAR(g_balance_grapplehook_works_on_players)) {
                RemoveGrapplingHook(self.owner);
                return;
            }
            
            if(other.iscreature && CVAR(g_balance_grapplehook_oneperplayer)) {
                entity e; for(;(e = find(e, classname, "grapplinghook"));)
                    if(e.aiment == other)
                        RemoveGrapplingHook(e.owner);
            }
            
            SetMovetypeFollow(self, other);
            WarpZone_RefSys_BeginAddingIncrementally(self, self.aiment);
        }
    }

	//self.owner.disableclientprediction = TRUE;
}

void GrapplingHook_Damage (entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force)
{
	if(self.health > 0)
	{
		//<akari>
		if(CVAR(g_rocketminsta) || CVAR(g_rocketminsta_hook_forcerules))
		{	// If the explosive mode is activated or new hook rules are forced, use them.
		
			//If the hook is not breakable, do nothing
			if(!CVAR(g_rocketminsta_hook_breakable))
			{
				//bprint("The hook is not breakable!\n");
				return;
			}
			
			//If we shoot our own hook
			if(self.owner == attacker)
			if(!CVAR(g_rocketminsta_hook_breakable_self))
			{
				//bprint("Own hook is not breakable!\n");
				return;
			}
			
			//If we shoot a teammate's hook
			else if(self.owner.team == attacker.team)
			if(!CVAR(g_rocketminsta_hook_breakable_team))
			{
				//bprint("Team hook is not breakable!\n");
				return;
			}
			
			//Don't allow hookbreak if the hook is attached to a player
			if(self.aiment && self.aiment.classname == "player")
				return;
			
			//Die if any amount of damage is recieved
			if(damage)
				self.health = 0;
			
			//Play a hitsound
			if(attacker == self.owner || (!teams_matter && self.owner.team != attacker.team))
				attacker.typehitsound += 1;
			else
				attacker.hitsound += 1;

			//Reflect the hook damage to it's owner
			Damage(self.owner, inflictor, attacker, damage * CVAR(g_rocketminsta_hook_damagefactor), deathtype, self.owner.origin, '0 0 0');
		}
		else
		{	//Otherwise, act normally
			self.health = self.health - damage;
		}
		//</akari>
		
		if (self.health <= 0)
		{
			//if(attacker != self.owner)
			{
				self.owner.pusher = attacker;
				self.owner.pushltime = PUSHLTIME_HOOKFRAG;
			}
			RemoveGrapplingHook(self.owner);
		}
	}
}

float CustomHGHookButton(entity e) {
	if(!e.BUTTON_USE || e.soulmate || e.smhost || time < e.w_pickup_confirmation + 0.5)
		return FALSE;
	return TRUE;
}

void FireGrapplingHook (void)
{
	entity missile;
	vector org;

	if((arena_roundbased && time < warmup) || (time < game_starttime))
		return;

	if(g_freeze)
	if(self.frozen)
		return;
    
    if(time < self.hg_plasmalock)
        return;
    
	if(g_nadgets && !g_nadgets_detonatelaunches)
	//if(HG_PlayerMayFire(self) && !CustomHGHookButton(self))
    if(!CustomHGHookButton(self))
		return;
    
    if(self.hg_stealth) {
        //HG_Cloak_Trigger();
        self.hg_stealth = 0;
        self.hg_stealth_saved = 0;
    }
    
    if(time - self.hg_stealthtime < CVAR(g_nadgets_cloak_actiondelay))
        return;
    
	makevectors(self.v_angle);

	// UGLY WORKAROUND: play this on CHAN_WEAPON2 so it can't cut off fire sounds
	sound (self, CHAN_WEAPON2, "weapons/hook_fire.wav", VOL_BASE, ATTN_NORM);
	org = self.origin + self.view_ofs + v_forward * hook_shotorigin_x + v_right * hook_shotorigin_y + v_up * hook_shotorigin_z;
	pointparticles(particleeffectnum("grapple_muzzleflash"), org, '0 0 0', 1);

	missile = WarpZone_RefSys_SpawnSameRefSys(self);
	missile.owner = self;
	self.hook = missile;
	missile.classname = "grapplinghook";

	missile.movetype = if(CVAR(g_balance_grapplehook_gravity)) MOVETYPE_TOSS else MOVETYPE_FLY;
	PROJECTILE_MAKETRIGGER(missile);

	setmodel (missile, "models/hook.md3"); // precision set below
	setsize (missile, '-3 -3 -3', '3 3 3');
	setorigin (missile, org);

	missile.state = 0; // not latched onto anything

	missile.velocity = v_forward * CVAR(g_balance_grapplehook_speed_fly);
	W_SetupProjectileVelocity(missile);

	missile.angles = vectoangles (missile.velocity);
	//missile.glow_color = 250; // 244, 250
	//missile.glow_size = 120;
	missile.touch = GrapplingHookTouch;
	missile.think = GrapplingHookThink;
	missile.nextthink = time + 0.1;

	missile.effects = /*EF_FULLBRIGHT | EF_ADDITIVE |*/ EF_LOWPRECISION;

	missile.health = CVAR(g_balance_grapplehook_health);//120
	missile.event_damage = GrapplingHook_Damage;
	missile.takedamage = DAMAGE_AIM;
	missile.damageforcescale = 0;
}

void GrapplingHookFrame()
{
	if(g_grappling_hook && timeoutStatus != 2 && self.weapon != WEP_HOOK)
	{
		// offhand hook controls
		if(self.BUTTON_HOOK || CustomHGHookButton(self))
		{
			if not(self.hook || (self.hook_state & HOOK_WAITING_FOR_RELEASE))
			{
				self.hook_state |= HOOK_FIRING;
				self.hook_state |= HOOK_WAITING_FOR_RELEASE;
			}
		}
		else
		{
			self.hook_state |= HOOK_REMOVING;
			self.hook_state &~= HOOK_WAITING_FOR_RELEASE;
		}

		self.hook_state &~= HOOK_RELEASING;
		if(self.BUTTON_CROUCH && CVAR(g_balance_grapplehook_crouchslide))
		{
			self.hook_state &~= HOOK_PULLING;
			//self.hook_state |= HOOK_RELEASING;
		}
		else
		{
			self.hook_state |= HOOK_PULLING;
			//self.hook_state &~= HOOK_RELEASING;
		}
	}
	else if(!(self.items & IT_JETPACK) && !g_grappling_hook && self.switchweapon != WEP_HOOK && !g_nadgets)
	{
		if(self.BUTTON_HOOK && !self.hook_switchweapon)
			W_SwitchWeapon(WEP_HOOK);
	}
	self.hook_switchweapon = self.BUTTON_HOOK;

	if(!g_grappling_hook && self.weapon != WEP_HOOK)
	{
		self.hook_state &~= HOOK_FIRING;
		self.hook_state |= HOOK_REMOVING;
	}

	if (self.hook_state & HOOK_FIRING)
	{
		if (self.hook)
			RemoveGrapplingHook(self);
		FireGrapplingHook();
		self.hook_state &~= HOOK_FIRING;
	}
	else if(self.hook_state & HOOK_REMOVING)
	{
		if (self.hook)
			RemoveGrapplingHook(self);
		self.hook_state &~= HOOK_REMOVING;
	}
}

void GrappleHookInit()
{
	if(g_grappling_hook)
		hook_shotorigin = '8 -8 -12';
	else
		hook_shotorigin = shotorg_adjust('26.2148 9.2059 -15.9772', TRUE, FALSE, FALSE);
}

void SetGrappleHookBindings()
{
	// this function has been modified for Nexuiz
	// don't remove these lines! old server or demos coud overwrite the new aliases
	stuffcmd(self, "alias +hook +button6\n");
	stuffcmd(self, "alias -hook -button6\n");
}
