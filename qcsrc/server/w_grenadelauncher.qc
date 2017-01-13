void W_Grenade_Explode (void)
{
	if(other.takedamage == DAMAGE_AIM)
		if(other.classname == "player")
			if(IsDifferentTeam(self.owner, other))
				if(other.deadflag == DEAD_NO)
					if(IsFlying(other))
                        CSQCMessage_Praise(self.owner, CSQCMSG_PRAISEFLAG_AIRSHOT);

	self.event_damage = SUB_Null;
	self.takedamage = DAMAGE_NO;
	RadiusDamage (self, self.owner, CVAR(g_balance_grenadelauncher_primary_damage), CVAR(g_balance_grenadelauncher_primary_edgedamage), CVAR(g_balance_grenadelauncher_primary_radius), world, CVAR(g_balance_grenadelauncher_primary_force), self.projectiledeathtype, other);

	remove (self);
}

void W_Grenade_Explode2 (void)
{
	if(other.takedamage == DAMAGE_AIM)
		if(other.classname == "player")
			if(IsDifferentTeam(self.owner, other))
				if(IsFlying(other))
                    CSQCMessage_Praise(self.owner, CSQCMSG_PRAISEFLAG_AIRSHOT);

	self.event_damage = SUB_Null;
	self.takedamage = DAMAGE_NO;
	RadiusDamage (self, self.owner, CVAR(g_balance_grenadelauncher_secondary_damage), CVAR(g_balance_grenadelauncher_secondary_edgedamage), CVAR(g_balance_grenadelauncher_secondary_radius), world, CVAR(g_balance_grenadelauncher_secondary_force), self.projectiledeathtype, other);

	remove (self);
}

void W_Grenade_Touch1 (void)
{
	PROJECTILE_TOUCH;
	W_Grenade_Explode ();
}

void W_Grenade_Touch2 (void)
{
	PROJECTILE_TOUCH;
	if (other.takedamage == DAMAGE_AIM)
	{
		self.use ();
	}
	else
	{
		float r;
		r = random() * 6;
		if(r < 1)
			spamsound (self, CHAN_PROJECTILE, "weapons/grenade_bounce1.wav", VOL_BASE, ATTN_NORM);
		else if(r < 2)
			spamsound (self, CHAN_PROJECTILE, "weapons/grenade_bounce2.wav", VOL_BASE, ATTN_NORM);
		else if(r < 3)
			spamsound (self, CHAN_PROJECTILE, "weapons/grenade_bounce3.wav", VOL_BASE, ATTN_NORM);
		else if(r < 4)
			spamsound (self, CHAN_PROJECTILE, "weapons/grenade_bounce4.wav", VOL_BASE, ATTN_NORM);
		else if(r < 5)
			spamsound (self, CHAN_PROJECTILE, "weapons/grenade_bounce5.wav", VOL_BASE, ATTN_NORM);
		else
			spamsound (self, CHAN_PROJECTILE, "weapons/grenade_bounce6.wav", VOL_BASE, ATTN_NORM);
		
		self.projectiledeathtype |= HITTYPE_BOUNCE;
	}
}

void W_Grenade_Damage (entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force)
{
	if (self.health <= 0)
		return;
	self.health = self.health - damage;
	if (self.health <= 0)
	{
		W_PrepareExplosionByDamage(attacker, self.think);
	}
}

void W_Grenade_Attack (void)
{
	entity gren;
    float cost = CVAR(g_balance_grenadelauncher_primary_ammo);

    if(!W_Clip_Consume(cost))
        return;

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_rockets = self.ammo_rockets - cost;

	W_SetupShot_ProjectileSize (self, '0 0 -3', '0 0 -3', FALSE, 4, "weapons/grenade_fire.wav", CVAR(g_balance_grenadelauncher_primary_damage));
	w_shotdir = v_forward; // no TrueAim for grenades please

	pointparticles(particleeffectnum("grenadelauncher_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);

	gren = spawn ();
	gren.owner = Akimbo_Owner(self);
	gren.classname = "grenade";
	gren.bot_dodge = TRUE;
	gren.bot_dodgerating = CVAR(g_balance_grenadelauncher_primary_damage);
	gren.movetype = MOVETYPE_BOUNCE;
	PROJECTILE_MAKETRIGGER(gren);
	gren.projectiledeathtype = WEP_GRENADE_LAUNCHER;
	setorigin(gren, w_shotorg);
	setsize(gren, '0 0 -3', '0 0 -3');

    gren.team = self.team;
	gren.nextthink = time + CVAR(g_balance_grenadelauncher_primary_lifetime);
	gren.think = adaptor_think2use;
	gren.use = W_Grenade_Explode;
	gren.touch = if(CVAR(g_balance_grenadelauncher_primary_bounce)) W_Grenade_Touch2 else W_Grenade_Touch1;
	gren.velocity = w_shotdir * CVAR(g_balance_grenadelauncher_primary_speed) + v_up * CVAR(g_balance_grenadelauncher_primary_speed_up);
	W_SetupProjectileVelocity(gren);

	gren.angles = vectoangles (gren.velocity);
	gren.flags = FL_PROJECTILE;

	CSQCProjectile(gren, TRUE, if(CVAR(g_balance_grenadelauncher_primary_bounce)) PROJECTILE_GRENADE_BOUNCING else PROJECTILE_GRENADE, TRUE);
}

void W_Grenade_Attack2 (void)
{
	entity gren;
    float cost = CVAR(g_balance_grenadelauncher_secondary_ammo);

    if(!W_Clip_Consume(cost))
        return;

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_rockets = self.ammo_rockets - cost;

	W_SetupShot_ProjectileSize (self, '0 0 -3', '0 0 -3', FALSE, 4, "weapons/grenade_fire.wav", CVAR(g_balance_grenadelauncher_secondary_damage));
	w_shotdir = v_forward; // no TrueAim for grenades please

	pointparticles(particleeffectnum("grenadelauncher_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);

	gren = spawn ();
	gren.owner = Akimbo_Owner(self);
	gren.classname = "grenade";
	gren.bot_dodge = TRUE;
	gren.bot_dodgerating = CVAR(g_balance_grenadelauncher_secondary_damage);
	gren.movetype = MOVETYPE_BOUNCE;
	PROJECTILE_MAKETRIGGER(gren);
	gren.projectiledeathtype = WEP_GRENADE_LAUNCHER | HITTYPE_SECONDARY;
	setsize(gren, '0 0 -3', '0 0 -3');
	setorigin(gren, w_shotorg);

    gren.team = self.team;
	gren.nextthink = time + CVAR(g_balance_grenadelauncher_secondary_lifetime);
	gren.think = adaptor_think2use;
	gren.use = W_Grenade_Explode2;
	gren.touch = W_Grenade_Touch2;
	gren.takedamage = DAMAGE_YES;
	gren.health = CVAR(g_balance_grenadelauncher_secondary_health);
	gren.damageforcescale = CVAR(g_balance_grenadelauncher_secondary_damageforcescale);
	gren.event_damage = W_Grenade_Damage;
	gren.velocity = w_shotdir * CVAR(g_balance_grenadelauncher_secondary_speed) + v_up * CVAR(g_balance_grenadelauncher_secondary_speed_up);
	W_SetupProjectileVelocity(gren);

	gren.angles = vectoangles (gren.velocity);
	gren.flags = FL_PROJECTILE;

	CSQCProjectile(gren, TRUE, PROJECTILE_GRENADE_BOUNCING, TRUE);
}

void spawnfunc_weapon_grenadelauncher (void)
{
	weapon_defaultspawnfunc(WEP_GRENADE_LAUNCHER);
}

void W_Mortar_SetClipContext(void) {
    W_Clip_SetWeaponContext(
        WEP_GRENADE_LAUNCHER,
        CVAR(g_balance_grenadelauncher_magazinecapacity),
        CVAR(g_balance_grenadelauncher_magazineregen),
        CVAR(g_balance_grenadelauncher_reloadtime),
        ammo_rockets,
        1
    );
}

.float bot_secondary_grenademooth;
float w_glauncher(float req)
{
    W_SetButtonFields(self, CVAR(g_balance_grenadelauncher_swapshotmodes));
    W_Mortar_SetClipContext();

	if (req == WR_AIM)
	{
		self.w_button_primary = FALSE;
		self.w_button_secondary = FALSE;
		if (self.bot_secondary_grenademooth == 0)
		{
			if(bot_aim(CVAR(g_balance_grenadelauncher_primary_speed), CVAR(g_balance_grenadelauncher_primary_speed_up), CVAR(g_balance_grenadelauncher_primary_lifetime), TRUE))
			{
				self.w_button_primary = TRUE;
				if(random() < 0.01) self.bot_secondary_grenademooth = 1;
			}
		}
		else
		{
			if(bot_aim(CVAR(g_balance_grenadelauncher_secondary_speed), CVAR(g_balance_grenadelauncher_secondary_speed_up), CVAR(g_balance_grenadelauncher_secondary_lifetime), TRUE))
			{
				self.w_button_secondary = TRUE;
				if(random() < 0.02) self.bot_secondary_grenademooth = 0;
			}
		}
	}
	else if (req == WR_THINK)
	{
        if(W_Clip_TryWeaponAction()) {
            if(self.w_button_primary)
            if(weapon_prepareattack(0, CVAR(g_balance_grenadelauncher_primary_refire)))
            if(W_Clip_TryAttackOrReload()) {
                W_Grenade_Attack();
                weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_grenadelauncher_primary_animtime), w_ready);
            }

            if(self.w_button_secondary)
            if(CVAR(g_balance_grenadelauncher_secondary))
            if(weapon_prepareattack(1, CVAR(g_balance_grenadelauncher_secondary_refire)))
            if(W_Clip_TryAttackOrReload()) {
                W_Grenade_Attack2();
                weapon_thinkf(WFRAME_FIRE2, CVAR(g_balance_grenadelauncher_secondary_animtime), w_ready);
            }

            W_Clip_FinishWeaponAction();
        }
	}
	else if (req == WR_PRECACHE)
	{
		precache_sound ("weapons/grenade_bounce1.wav");
		precache_sound ("weapons/grenade_bounce2.wav");
		precache_sound ("weapons/grenade_bounce3.wav");
		precache_sound ("weapons/grenade_bounce4.wav");
		precache_sound ("weapons/grenade_bounce5.wav");
		precache_sound ("weapons/grenade_bounce6.wav");
		precache_sound ("weapons/grenade_fire.wav");
	}
	else if (req == WR_SETUP)
		weapon_setup(WEP_GRENADE_LAUNCHER);
	else if (req == WR_CHECKAMMO1)
		return self.ammo_rockets >= CVAR(g_balance_grenadelauncher_primary_ammo);
	else if (req == WR_CHECKAMMO2)
		return self.ammo_rockets >= CVAR(g_balance_grenadelauncher_secondary_ammo);

    W_Clip_WeaponRequestHook(req);
	return TRUE;
};
