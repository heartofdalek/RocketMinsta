.float electro_count;
.float electro_secondarytime;

void W_Plasma_Explode_Combo (void);

void W_Plasma_TriggerCombo(vector org, float rad, entity own)
{
	entity e;
	e = findradius(org, rad);
	while (e)
	{
		if (e.classname == "plasma")
		{
			// see if there is line of sight to the combo ball
			traceline(org, e.origin, MOVE_NOMONSTERS, e);
			if (trace_fraction == 1 || trace_ent == e)
			{
				// change owner to whoever caused the combo explosion
				e.owner = own;
				e.takedamage = DAMAGE_NO;
				e.classname = "plasma_chain";
				e.think = W_Plasma_Explode_Combo;
				e.nextthink = time + vlen(e.origin - org) / CVAR(g_balance_electro_combo_speed); // delay combo chains, looks cooler
			}
		}
		e = e.chain;
	}
}

void W_Plasma_Explode (void)
{
	if(other.takedamage == DAMAGE_AIM)
		if(other.classname == "player")
			if(IsDifferentTeam(self.owner, other))
				if(other.deadflag == DEAD_NO)
					if(IsFlying(other))
                        CSQCMessage_Praise(self.owner, CSQCMSG_PRAISEFLAG_AWESOME);

	self.event_damage = SUB_Null;
	self.takedamage = DAMAGE_NO;
	if (self.movetype == MOVETYPE_BOUNCE)
	{
		RadiusDamage (self, self.owner, CVAR(g_balance_electro_secondary_damage), CVAR(g_balance_electro_secondary_edgedamage), CVAR(g_balance_electro_secondary_radius), world, CVAR(g_balance_electro_secondary_force), self.projectiledeathtype, other);
	}
	else
	{
		W_Plasma_TriggerCombo(self.origin, CVAR(g_balance_electro_primary_comboradius), self.owner);
		RadiusDamage (self, self.owner, CVAR(g_balance_electro_primary_damage), CVAR(g_balance_electro_primary_edgedamage), CVAR(g_balance_electro_primary_radius), world, CVAR(g_balance_electro_primary_force), self.projectiledeathtype, other);
	}

	remove (self);
}

void W_Plasma_Explode_Combo (void)
{

	W_Plasma_TriggerCombo(self.origin, CVAR(g_balance_electro_combo_comboradius), self.owner);

	self.event_damage = SUB_Null;
	RadiusDamage (self, self.owner, CVAR(g_balance_electro_combo_damage), CVAR(g_balance_electro_combo_edgedamage), CVAR(g_balance_electro_combo_radius), world, CVAR(g_balance_electro_combo_force), WEP_ELECTRO | HITTYPE_BOUNCE, world); // use THIS type for a combo because primary can't bounce
	remove (self);
}

void W_Plasma_Touch (void)
{
	PROJECTILE_TOUCH;
	if (other.takedamage == DAMAGE_AIM) {
		W_Plasma_Explode ();
	} else {
		spamsound (self, CHAN_PROJECTILE, "weapons/electro_bounce.wav", VOL_BASE, ATTN_NORM);
		self.projectiledeathtype |= HITTYPE_BOUNCE;
	}
}

void W_Plasma_TouchExplode (void)
{
	PROJECTILE_TOUCH;
	W_Plasma_Explode ();
}

void W_Plasma_Damage (entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force)
{
	if(self.health <= 0)
		return;
	// note: combos are usually triggered by W_Plasma_TriggerCombo, not damage
	self.health = self.health - damage;
	if (self.health <= 0)
	{
		self.takedamage = DAMAGE_NO;
		self.nextthink = time;
		if (inflictor.classname == "plasma_chain" || inflictor.classname == "plasma_prim")
		{
			// change owner to whoever caused the combo explosion
			self.owner = inflictor.owner;
			self.classname = "plasma_chain";
			self.think = W_Plasma_Explode_Combo;
			self.nextthink = time + vlen(self.origin - inflictor.origin) / CVAR(g_balance_electro_combo_speed); // delay combo chains, looks cooler
		}
		else
		{
			self.use = W_Plasma_Explode;
			self.think = adaptor_think2use;
		}
	}
}

void W_Electro_Attack()
{
	entity proj;
    float cost = CVAR(g_balance_electro_primary_ammo);

    if(!W_Clip_Consume(cost))
        return;

    if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
        self.ammo_cells = self.ammo_cells - cost;

	W_SetupShot_ProjectileSize (self, '0 0 -3', '0 0 -3', FALSE, 2, "weapons/electro_fire.wav", CVAR(g_balance_electro_primary_damage));

	pointparticles(particleeffectnum("electro_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);

	proj = spawn ();
	proj.classname = "plasma_prim";
	proj.owner = Akimbo_Owner(self);
	proj.bot_dodge = TRUE;
	proj.bot_dodgerating = CVAR(g_balance_electro_primary_damage);
	proj.use = W_Plasma_Explode;
	proj.think = adaptor_think2use;
	proj.nextthink = time + CVAR(g_balance_electro_primary_lifetime);
	PROJECTILE_MAKETRIGGER(proj);
	proj.projectiledeathtype = WEP_ELECTRO;
	setorigin(proj, w_shotorg);

	proj.movetype = MOVETYPE_FLY;
	proj.velocity = w_shotdir * CVAR(g_balance_electro_primary_speed);
	W_SetupProjectileVelocity(proj);
	proj.angles = vectoangles(proj.velocity);
	proj.touch = W_Plasma_TouchExplode;
	setsize(proj, '0 0 -3', '0 0 -3');
	proj.flags = FL_PROJECTILE;

	//sound (proj, CHAN_PAIN, "weapons/electro_fly.wav", VOL_BASE, ATTN_NORM);
	//sounds bad

	CSQCProjectile(proj, TRUE, PROJECTILE_ELECTRO_BEAM, TRUE);
}

void W_Electro_Attack2()
{
	entity proj;
    float cost = CVAR(g_balance_electro_secondary_ammo);

    if(!W_Clip_Consume(cost))
        return;

    if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
        self.ammo_cells = self.ammo_cells - cost;


	W_SetupShot_ProjectileSize (self, '0 0 -3', '0 0 -3', FALSE, 2, "weapons/electro_fire2.wav", CVAR(g_balance_electro_secondary_damage));
	w_shotdir = v_forward; // no TrueAim for grenades please

	pointparticles(particleeffectnum("electro_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);

	proj = spawn ();
	proj.classname = "plasma";
	proj.owner = Akimbo_Owner(self);
	proj.use = W_Plasma_Explode;
	proj.think = adaptor_think2use;
	proj.bot_dodge = TRUE;
	proj.bot_dodgerating = CVAR(g_balance_electro_secondary_damage);
	proj.nextthink = time + CVAR(g_balance_electro_secondary_lifetime);
	PROJECTILE_MAKETRIGGER(proj);
	proj.projectiledeathtype = WEP_ELECTRO | HITTYPE_SECONDARY;
	setorigin(proj, w_shotorg);

	proj.movetype = MOVETYPE_BOUNCE;
	proj.velocity = (w_shotdir + randomvec() * CVAR(g_balance_electro_secondary_spread)) * CVAR(g_balance_electro_secondary_speed) + v_up * CVAR(g_balance_electro_secondary_speed_up);
	W_SetupProjectileVelocity(proj);
	proj.touch = W_Plasma_Touch;
	setsize(proj, '0 0 -3', '0 0 -3');
	proj.takedamage = DAMAGE_YES;
	proj.damageforcescale = CVAR(g_balance_electro_secondary_damageforcescale);
	proj.health = CVAR(g_balance_electro_secondary_health);
	proj.event_damage = W_Plasma_Damage;
	proj.flags = FL_PROJECTILE;

	CSQCProjectile(proj, TRUE, PROJECTILE_ELECTRO, FALSE); // no culling, it has sound
}

void spawnfunc_weapon_electro (void)
{
	weapon_defaultspawnfunc(WEP_ELECTRO);
}

void w_electro_checkattack()
{
    W_SetButtonFields(self, CVAR(g_balance_electro_swapshotmodes));

	if(self.electro_count > 1)
	if(self.w_button_secondary)
	if(weapon_prepareattack(1, -1))
	{
		W_Electro_Attack2();
		self.electro_count -= 1;
		weapon_thinkf(WFRAME_FIRE2, CVAR(g_balance_electro_secondary_animtime), w_electro_checkattack);
		return;
	}

	w_ready();
}

void W_Electro_SetClipContext(void) {
    W_Clip_SetWeaponContext(
        WEP_ELECTRO,
        CVAR(g_balance_electro_magazinecapacity),
        CVAR(g_balance_electro_magazineregen),
        CVAR(g_balance_electro_reloadtime),
        ammo_cells,
        1
    );
}

.float bot_secondary_electromooth;
float w_electro(float req)
{
    W_SetButtonFields(self, CVAR(g_balance_electro_swapshotmodes));
    W_Electro_SetClipContext();

	if (req == WR_AIM)
	{
		self.w_button_primary=FALSE;
		self.w_button_secondary=FALSE;
		if(vlen(self.origin-self.enemy.origin) > 1000)
			self.bot_secondary_electromooth = 0;
		if(self.bot_secondary_electromooth == 0)
		{
			if(bot_aim(CVAR(g_balance_electro_primary_speed), 0, CVAR(g_balance_electro_primary_lifetime), FALSE))
			{
				self.w_button_primary = TRUE;
				if(random() < 0.01) self.bot_secondary_electromooth = 1;
			}
		}
		else
		{
			if(bot_aim(CVAR(g_balance_electro_secondary_speed), CVAR(g_balance_grenadelauncher_secondary_speed_up), CVAR(g_balance_electro_secondary_lifetime), TRUE))
			{
				self.w_button_secondary = TRUE;
				if(random() < 0.03) self.bot_secondary_electromooth = 0;
			}
		}
	}
	else if (req == WR_THINK)
	{
        if(W_Clip_TryWeaponAction()) {
            if(self.w_button_primary)
            if(weapon_prepareattack(0, CVAR(g_balance_electro_primary_refire)))
            if(W_Clip_TryAttackOrReload()) {
                W_Electro_Attack();
                weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_electro_primary_animtime), w_ready);
            }

            if(self.w_button_secondary)
            if(time >= self.electro_secondarytime)
            if(weapon_prepareattack(1, CVAR(g_balance_electro_secondary_refire)))
            if(W_Clip_TryAttackOrReload()) {
                W_Electro_Attack2();
                self.electro_count = CVAR(g_balance_electro_secondary_count);
                weapon_thinkf(WFRAME_FIRE2, CVAR(g_balance_electro_secondary_animtime), w_electro_checkattack);
                self.electro_secondarytime = time + CVAR(g_balance_electro_secondary_refire2);
            }

            W_Clip_FinishWeaponAction();
        }

	}
	else if (req == WR_PRECACHE)
	{
		precache_sound ("weapons/electro_bounce.wav");
		precache_sound ("weapons/electro_fire.wav");
		precache_sound ("weapons/electro_fire2.wav");
		precache_sound ("weapons/electro_impact.wav");
		precache_sound ("weapons/electro_impact_combo.wav");
	}
	else if (req == WR_SETUP)
		weapon_setup(WEP_ELECTRO);
	else if (req == WR_CHECKAMMO1)
		return self.ammo_cells >= CVAR(g_balance_electro_primary_ammo);
	else if (req == WR_CHECKAMMO2)
		return self.ammo_cells >= CVAR(g_balance_electro_secondary_ammo);
	else if (req == WR_RESETPLAYER)
	{
		self.electro_secondarytime = time;
	}
    else if (req == WR_TT_STORE)
    {
        TimeTravel_StoreTime(self,      tt_moment, electro_secondarytime);
    }
    else if (req == WR_TT_RESTORE)
    {
        TimeTravel_RestoreTime(self,    tt_moment, electro_secondarytime);
    }

    W_Clip_WeaponRequestHook(req);
	return TRUE;
};
