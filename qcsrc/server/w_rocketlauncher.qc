.float rl_release;
.float rl_detonate_later;
.entity notrealowner;

void W_Rocket_Unregister()
{
	if(self.owner && self.notrealowner.lastrocket == self)
	{
		self.notrealowner.lastrocket = world;
		// self.owner.rl_release = 1;
	}
}

void W_Rocket_Explode (void)
{
	W_Rocket_Unregister();

	if(other.takedamage == DAMAGE_AIM)
		if(other.classname == "player")
			if(IsDifferentTeam(self.owner, other))
				if(IsFlying(other))
                    CSQCMessage_Praise(self.owner, CSQCMSG_PRAISEFLAG_AIRSHOT);

	self.event_damage = SUB_Null;
	self.takedamage = DAMAGE_NO;
	RadiusDamage (self, self.owner, CVAR(g_balance_rocketlauncher_damage), CVAR(g_balance_rocketlauncher_edgedamage), CVAR(g_balance_rocketlauncher_radius), world, CVAR(g_balance_rocketlauncher_force), self.projectiledeathtype, other);

	if (self.owner.weapon == WEP_ROCKET_LAUNCHER)
	{
		if(self.owner.ammo_rockets < CVAR(g_balance_rocketlauncher_ammo))
		{
			self.owner.cnt = WEP_ROCKET_LAUNCHER;
			ATTACK_FINISHED(self.owner) = time;
			self.owner.switchweapon = w_getbestweapon(self.owner);
		}
		if(g_laserguided_missile)
			ATTACK_FINISHED(self.owner) = time + CVAR(g_balance_rocketlauncher_refire) * W_WeaponRateFactor();
	}
	remove (self);
}

entity FindLaserTarget(entity e, float dist_variance, float dot_variance)
{
	entity head, selected;
	vector dir;
	float dist, maxdist,// bestdist,
		dot,// bestdot,
		points, bestpoints;
	//bestdist = 9999;
	//bestdot = -2;
	bestpoints = 0;
	maxdist = 800;
	selected = world;

	makevectors(e.angles);

	head = find(world, classname, "laser_target");
	while(head)
	{
		points = 0;
		dir = normalize(head.origin - self.origin);
		dot = dir * v_forward;
		dist = vlen(head.origin - self.origin);
		if(dist > maxdist)
			dist = maxdist;

		// gain points for being in front
		points = points + ((dot+1)*0.5) * 500
			* (1 + crandom()*dot_variance);
		// gain points for being close away
		points = points + (1 - dist/maxdist) * 1000
			* (1 + crandom()*dot_variance);

		traceline(e.origin, head.origin, TRUE, self);
		if(trace_fraction < 1)
		{
			points = 0;
		}

		if(points > bestpoints)//random() > 0.5)//
		{
			bestpoints = points;
			selected = head;
		}

		head = find(head, classname, "laser_target");
	}

	//bprint(selected.owner.netname);
	//bprint("\n");
	return selected;
}

void W_Rocket_RemoteExplode()
{
	if(self.owner.deadflag == DEAD_NO)
	if(self.notrealowner.lastrocket) {
		if(  (if(self.spawnshieldtime >= 0)
                  time >= self.spawnshieldtime // timer
		      else
                  vlen(NearestPointOnBox(self.owner, self.origin) - self.origin) > CVAR(g_balance_rocketlauncher_radius)) // safety device
		) {
			other = world;
			self.projectiledeathtype |= HITTYPE_BOUNCE;
			W_Rocket_Explode ();
		}
	}
}

vector rocket_steerto(vector thisdir, vector goaldir, float maxturn_cos)
{
	if(thisdir * goaldir > maxturn_cos)
		return goaldir;
	float f, m2;
	vector v;
	// solve:
	//   g = normalize(thisdir + goaldir * X)
	//   thisdir * g = maxturn
	//
	//   gg = thisdir + goaldir * X
	//   (thisdir * gg)^2 = maxturn^2 * (gg * gg)
	//
	//   (1 + (thisdir * goaldir) * X)^2 = maxturn^2 * (1 + X*X + 2 * X * thisdir * goaldir)
	f = thisdir * goaldir;
	//   (1 + f * X)^2 = maxturn^2 * (1 + X*X + 2 * X * f)
	//   0 = (m^2 - f^2) * x^2 + (2 * f * (m^2 - 1)) * x + (m^2 - 1)
	m2 = maxturn_cos * maxturn_cos;
	v = solve_quadratic(m2 - f * f, 2 * f * (m2 - 1), m2 - 1);
	return normalize(thisdir + goaldir * v_y); // the larger solution!
}

void W_Rocket_Think (void)
{
	entity e;
	vector desireddir, olddir, newdir, desiredorigin, goal;
	float turnrate, velspeed, f;
	self.nextthink = time;
	if (time > self.cnt)
	{
		other = world;
		self.projectiledeathtype |= HITTYPE_BOUNCE;
		W_Rocket_Explode ();
		return;
	}

	if(g_laserguided_missile)
	{
		// accelerate
		makevectors(self.angles_x * '-1 0 0' + self.angles_y * '0 1 0');
		velspeed = CVAR(g_balance_rocketlauncher_laserguided_speed) * g_weaponspeedfactor - (self.velocity * v_forward);
		if (velspeed > 0)
			self.velocity = self.velocity + v_forward * min(CVAR(g_balance_rocketlauncher_laserguided_speedaccel) * frametime, velspeed);
	}
	else
	{
		// accelerate
		makevectors(self.angles_x * '-1 0 0' + self.angles_y * '0 1 0');
		velspeed = CVAR(g_balance_rocketlauncher_speed) * g_weaponspeedfactor - (self.velocity * v_forward);
		if (velspeed > 0)
			self.velocity = self.velocity + v_forward * min(CVAR(g_balance_rocketlauncher_speedaccel) * g_weaponspeedfactor * frametime, velspeed);
	}

	// laser guided, or remote detonation
	if (self.owner.weapon == WEP_ROCKET_LAUNCHER)
	{
		if(g_laserguided_missile)
		{
			if(self.rl_detonate_later)
				W_Rocket_RemoteExplode();

			if(CVAR(g_balance_rocketlauncher_laserguided_allow_steal))
			{
				if(self.owner.laser_on)
				{
					if(self.attack_finished_single < time)
					{
						self.attack_finished_single = time + 0.2 + random()*0.3;
						self.enemy = FindLaserTarget(self, 0.7, 0.7);
					}

					if(!self.enemy)
						self.enemy = self.owner.weaponentity.lasertarget;
				}
				else self.enemy = world;
			}
			else // don't allow stealing: always target my owner's laser (if it exists)
				self.enemy = self.owner.weaponentity.lasertarget;

			if(self.enemy != world)
			{
				//bprint("Targeting ", self.enemy.owner.netname, "'s laser\n");
				velspeed = vlen(self.velocity);
				e = self.enemy;//self.owner.weaponentity.lasertarget;
				turnrate = CVAR(g_balance_rocketlauncher_laserguided_turnrate);//0.65;						// how fast to turn
				desireddir = normalize(e.origin - self.origin);		// get direction from my position to the laser target
				olddir = normalize(self.velocity);					// get my current direction
				newdir = normalize(olddir + desireddir * turnrate);	// take the average of the 2 directions; not the best method but simple & easy
				self.velocity = newdir * velspeed;					// make me fly in the new direction at my flight speed
				self.angles = vectoangles(self.velocity);			// turn model in the new flight direction

				ATTACK_FINISHED(self.owner) = time + 0.2 * W_WeaponRateFactor();
			}
		}
		else
		{
			if(self == self.notrealowner.lastrocket)
			if(!self.owner.rl_release)
			if(CVAR(g_balance_rocketlauncher_guiderate))
			if(time > self.pushltime)
			if(self.owner.deadflag == DEAD_NO)
			{
				f = CVAR(g_balance_rocketlauncher_guideratedelay);
				if(f)
					f = bound(0, (time - self.pushltime) / f, 1);
				else
					f = 1;

				velspeed = vlen(self.velocity);

				makevectors(self.owner.v_angle);
				desireddir = v_forward;
				desiredorigin = self.owner.origin + self.owner.view_ofs;
				olddir = normalize(self.velocity);

				// now it gets tricky... we want to move like some curve to approximate the target direction
				// but we are limiting the rate at which we can turn!
				goal = desiredorigin + ((self.origin - desiredorigin) * desireddir + CVAR(g_balance_rocketlauncher_guidegoal)) * desireddir;
				newdir = rocket_steerto(olddir, normalize(goal - self.origin), cos(CVAR(g_balance_rocketlauncher_guiderate) * f * frametime * DEG2RAD));

				self.velocity = newdir * velspeed;
				self.angles = vectoangles(self.velocity);

				if(!self.count)
				{
					pointparticles(particleeffectnum("rocket_guide"), self.origin, self.velocity, 1);
					// TODO add a better sound here
					sound (self.owner, CHAN_WEAPON2, "weapons/rocket_mode.wav", VOL_BASE, ATTN_NORM);
					self.count = 1;
				}
			}

			if(self.rl_detonate_later)
				W_Rocket_RemoteExplode();
		}
	}

	if(self.csqcprojectile_clientanimate == 0)
		UpdateCSQCProjectile(self);
}

void W_Rocket_Touch (void)
{
	PROJECTILE_SKIPNONSOLID
	if(SUB_OwnerCheck())
		return;
	W_Rocket_Unregister();

	if(SUB_NoImpactCheck()) {
		remove(self);
		return;
	}

	W_Rocket_Explode ();
}

void W_Rocket_Damage (entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force)
{
	if (self.health <= 0)
		return;
	self.health = self.health - damage;
	self.angles = vectoangles(self.velocity);
	if (self.health <= 0)
		W_PrepareExplosionByDamage(attacker, W_Rocket_Explode);
}

void W_Rocket_Attack (void)
{
    float cost = CVAR(g_balance_rocketlauncher_ammo);
    if(!W_Clip_Consume(cost))
        return;

	entity missile;
	entity flash;

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_rockets = self.ammo_rockets - cost;

	W_SetupShot_ProjectileSize (self, '-3 -3 -3', '3 3 3', FALSE, 5, "weapons/rocket_fire.wav", CVAR(g_balance_rocketlauncher_damage));
	pointparticles(particleeffectnum("rocketlauncher_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);

	missile = spawn ();
	missile.owner = Akimbo_Owner(self);
	missile.notrealowner = self;
	self.lastrocket = missile;
	if(CVAR(g_balance_rocketlauncher_detonatedelay) >= 0)
		missile.spawnshieldtime = time + CVAR(g_balance_rocketlauncher_detonatedelay);
	else
		missile.spawnshieldtime = -1;
	missile.pushltime = time + CVAR(g_balance_rocketlauncher_guidedelay);
	missile.classname = "rocket";
	missile.bot_dodge = TRUE;
	missile.bot_dodgerating = CVAR(g_balance_rocketlauncher_damage) * 2; // * 2 because it can be detonated inflight which makes it even more dangerous

	missile.takedamage = DAMAGE_YES;
	missile.damageforcescale = CVAR(g_balance_rocketlauncher_damageforcescale);
	missile.health = CVAR(g_balance_rocketlauncher_health);
	missile.event_damage = W_Rocket_Damage;

	missile.movetype = MOVETYPE_FLY;
	PROJECTILE_MAKETRIGGER(missile);
	missile.projectiledeathtype = WEP_ROCKET_LAUNCHER;
	setsize (missile, '-3 -3 -3', '3 3 3'); // give it some size so it can be shot

	setorigin (missile, w_shotorg - v_forward * 3); // move it back so it hits the wall at the right point
	if(g_laserguided_missile && self.laser_on)
		missile.velocity = w_shotdir * CVAR(g_balance_rocketlauncher_laserguided_speedstart) * g_weaponspeedfactor;
	else
		missile.velocity = w_shotdir * CVAR(g_balance_rocketlauncher_speedstart) * g_weaponspeedfactor;
    if (Akimbo_Active(self) == 2)
        missile.velocity = missile.velocity * 1.5;
	W_SetupProjectileVelocity(missile);
	missile.angles = vectoangles (missile.velocity);

	missile.touch = W_Rocket_Touch;
	missile.think = W_Rocket_Think;
	missile.nextthink = time;
	missile.cnt = time + CVAR(g_balance_rocketlauncher_lifetime);
	missile.flags = FL_PROJECTILE;

	CSQCProjectile(missile, CVAR(g_balance_rocketlauncher_guiderate) == 0 && CVAR(g_balance_rocketlauncher_speedaccel) == 0 && !g_laserguided_missile, PROJECTILE_ROCKET, FALSE); // because of fly sound

	// muzzle flash for 1st person view
	flash = spawn ();
	setmodel (flash, "models/flash.md3"); // precision set below
	SUB_SetFade (flash, time, 0.1);
	flash.effects = EF_ADDITIVE | EF_FULLBRIGHT | EF_LOWPRECISION;
	W_AttachToShotorg(flash, '5 0 0');

	// common properties
}

void W_Rocket_SetClipContext(void) {
    W_Clip_SetWeaponContext(
        WEP_ROCKET_LAUNCHER,
        CVAR(g_balance_rocketlauncher_magazinecapacity),
        CVAR(g_balance_rocketlauncher_magazineregen),
        CVAR(g_balance_rocketlauncher_reloadtime),
        ammo_rockets,
        1
    );
}

void spawnfunc_weapon_rocketlauncher (void); // defined in t_items.qc

float w_rlauncher(float req)
{
    W_SetButtonFields(self, CVAR(g_balance_rocketlauncher_swapshotmodes));
    W_Rocket_SetClipContext();

	entity rock;
	float rockfound;
	if (req == WR_AIM)
	{
		// aim and decide to fire if appropriate
		self.w_button_primary = bot_aim(CVAR(g_balance_rocketlauncher_speed), 0, CVAR(g_balance_rocketlauncher_lifetime), FALSE);
		if(skill >= 2) // skill 0 and 1 bots won't detonate rockets!
		{
			// decide whether to detonate rockets
			entity missile, targetlist, targ;
			float edgedamage, coredamage, edgeradius, recipricoledgeradius, d;
			float selfdamage, teamdamage, enemydamage;
			edgedamage = CVAR(g_balance_rocketlauncher_edgedamage);
			coredamage = CVAR(g_balance_rocketlauncher_damage);
			edgeradius = CVAR(g_balance_rocketlauncher_radius);
			recipricoledgeradius = 1 / edgeradius;
			selfdamage = 0;
			teamdamage = 0;
			enemydamage = 0;
			targetlist = findchainfloat(bot_attack, TRUE);
			missile = find(world, classname, "rocket");
			while (missile)
			{
				if (missile.owner != self)
				{
					missile = find(missile, classname, "rocket");
					continue;
				}
				targ = targetlist;
				while (targ)
				{
					d = vlen(targ.origin + (targ.mins + targ.maxs) * 0.5 - missile.origin);
					d = bound(0, edgedamage + (coredamage - edgedamage) * sqrt(1 - d * recipricoledgeradius), 10000);
					// count potential damage according to type of target
					if (targ == self)
						selfdamage = selfdamage + d;
					else if (targ.team == self.team && teams_matter)
						teamdamage = teamdamage + d;
					else if (bot_shouldattack(targ))
						enemydamage = enemydamage + d;
					targ = targ.chain;
				}
				missile = find(missile, classname, "rocket");
			}
			float desirabledamage;
			desirabledamage = enemydamage;
			if (CVAR(teamplay) != 1 && time > self.invincible_finished && time > self.spawnshieldtime)
				desirabledamage = desirabledamage - selfdamage * CVAR(g_balance_selfdamagepercent);
			if (self.team && CVAR(teamplay) != 1)
				desirabledamage = desirabledamage - teamdamage;

			missile = find(world, classname, "rocket");
			while (missile)
			{
				if (missile.owner != self)
				{
					missile = find(missile, classname, "rocket");
					continue;
				}
				makevectors(missile.v_angle);
				targ = targetlist;
				if (skill > 9) // normal players only do this for the target they are tracking
				{
					targ = targetlist;
					while (targ)
					{
						if (
							(v_forward * normalize(missile.origin - targ.origin)< 0.1)
							&& desirabledamage > 0.1*coredamage
						)self.w_button_secondary = TRUE;
						targ = targ.chain;
					}
				}else{
					float distance; distance= bound(300,vlen(self.origin-self.enemy.origin),30000);
					//As the distance gets larger, a correct detonation gets near imposible
					//Bots are assumed to use the rocket spawnfunc_light to see if the rocket gets near a player
					if(v_forward * normalize(missile.origin - self.enemy.origin)< 0.1)
						if(self.enemy.classname == "player")
							if(desirabledamage >= 0.1*coredamage)
								if(random()/distance*300 > frametime*bound(0,(10-skill)*0.2,1))
									self.w_button_secondary = TRUE;
				//	dprint(ftos(random()/distance*300),">");dprint(ftos(frametime*bound(0,(10-skill)*0.2,1)),"\n");
				}

				missile = find(missile, classname, "rocket");
			}
			// if we would be doing at X percent of the core damage, detonate it
			// but don't fire a new shot at the same time!
			if (desirabledamage >= 0.75 * coredamage) //this should do group damage in rare fortunate events
				self.w_button_secondary = TRUE;
			if ((skill > 6.5) && (selfdamage > self.health))
				self.w_button_secondary = FALSE;
			//if(self.w_button_secondary == TRUE)
			//	dprint(ftos(desirabledamage),"\n");
			if (self.w_button_secondary == TRUE) self.w_button_primary = FALSE;
		}
	}
	else if (req == WR_THINK)
	{
		if(g_laserguided_missile)
		{
            if(W_Clip_TryWeaponAction()) {
                if (self.w_button_primary && self.rl_release)
                if (W_Clip_TryAttackOrReload()) {
                    rockfound = 0;
                    for(rock = world; (rock = find(rock, classname, "rocket")); ) if(rock.notrealowner == self)
                    {
                        if(!rock.rl_detonate_later)
                        {
                            rock.rl_detonate_later = TRUE;
                            rockfound = 1;
                        }
                    }
                    if(rockfound)
                        sound (self, CHAN_WEAPON2, "weapons/rocket_det.wav", VOL_BASE, ATTN_NORM);
                    else
                    {
                        if (weapon_prepareattack(0, CVAR(g_balance_rocketlauncher_refire)))
                        {
                            W_Rocket_Attack();
                            weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_rocketlauncher_animtime), w_ready);
                        }
                    }
                    self.rl_release = 0;
                }
                W_Clip_FinishWeaponAction();
            }
			if (!self.w_button_primary)
				self.rl_release = 1;
			if (self.w_button_secondary)
			if(self.exteriorweaponentity.attack_finished_single < time)
			{
				self.exteriorweaponentity.attack_finished_single = time + 0.4;
				self.laser_on = !self.laser_on;
				// UGLY WORKAROUND: play this on CHAN_WEAPON2 so it can't cut off fire sounds
				sound (self, CHAN_WEAPON2, "weapons/rocket_mode.wav", VOL_BASE, ATTN_NORM);
			}
		}
		else
		{
            if(W_Clip_TryWeaponAction()) {
                if (self.w_button_primary) {
                    if (W_Clip_TryAttackOrReload()) {
                        if(self.rl_release || CVAR(g_balance_rocketlauncher_guidestop))
                        if(weapon_prepareattack(0, CVAR(g_balance_rocketlauncher_refire)))
                        {
                            W_Rocket_Attack();
                            weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_rocketlauncher_animtime), w_ready);
                            self.rl_release = 0;
                        }
                    }
                }
                W_Clip_FinishWeaponAction();
            }
			if (!self.w_button_primary)
				self.rl_release = 1;

			if (self.w_button_secondary)
			{
				rockfound = 0;
				for(rock = world; (rock = find(rock, classname, "rocket")); ) if(rock.owner == self)
				{
					if(!rock.rl_detonate_later)
					{
						rock.rl_detonate_later = TRUE;
						rockfound = 1;
					}
				}
				if(rockfound)
					sound (self, CHAN_WEAPON2, "weapons/rocket_det.wav", VOL_BASE, ATTN_NORM);
			}
		}
	}
	else if (req == WR_PRECACHE)
	{
		precache_model ("models/flash.md3");
		precache_sound ("weapons/rocket_det.wav");
		precache_sound ("weapons/rocket_fire.wav");
		precache_sound ("weapons/rocket_mode.wav");
		if (g_laserguided_missile)
		{
			precache_model ("models/laser_dot.mdl"); // rocket launcher
		}
	}
	else if (req == WR_SETUP)
	{
		weapon_setup(WEP_ROCKET_LAUNCHER);
		self.rl_release = 1;
	}
	else if (req == WR_CHECKAMMO1)
	{
        if(!self.weapon)
            return TRUE;

		// don't switch while guiding a missile
		if ((ATTACK_FINISHED(self) <= time || self.weapon != WEP_ROCKET_LAUNCHER)
			&& self.ammo_rockets < CVAR(g_balance_rocketlauncher_ammo))
			return FALSE;
	}
	else if (req == WR_CHECKAMMO2)
		return FALSE;
	else if (req == WR_RESETPLAYER)
	{
		self.rl_release = 0;
	}
    W_Clip_WeaponRequestHook(req);
	return TRUE;
};
