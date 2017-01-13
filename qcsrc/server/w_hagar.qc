// NO bounce protection, as bounces are limited!
void W_Hagar_Explode (void)
{
	self.event_damage = SUB_Null;
	RadiusDamage (self, self.realowner, CVAR(g_balance_hagar_primary_damage), CVAR(g_balance_hagar_primary_edgedamage), CVAR(g_balance_hagar_primary_radius), world, CVAR(g_balance_hagar_primary_force), self.projectiledeathtype, other);

	remove (self);
}

void W_Hagar_Explode2 (void)
{
	self.event_damage = SUB_Null;
	RadiusDamage (self, self.realowner, CVAR(g_balance_hagar_secondary_damage), CVAR(g_balance_hagar_secondary_edgedamage), CVAR(g_balance_hagar_secondary_radius), world, CVAR(g_balance_hagar_secondary_force), self.projectiledeathtype, other);

	remove (self);
}

void W_Hagar_Touch (void)
{
	PROJECTILE_TOUCH;
	self.use ();
}

void W_Hagar_Touch2 (void)
{
	PROJECTILE_TOUCH;

	if(self.cnt > 0 || other.takedamage == DAMAGE_AIM) {
		self.use();
	} else {
		self.cnt++;
		pointparticles(particleeffectnum("hagar_bounce"), self.origin, self.velocity, 1);
		self.angles = vectoangles (self.velocity);
		self.owner = world;
		self.projectiledeathtype |= HITTYPE_BOUNCE;
	}
}

void W_Hagar_Attack (void)
{
    float cost = CVAR(g_balance_hagar_primary_ammo);
    if(!W_Clip_Consume(cost))
        return;

	entity missile;

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_rockets = self.ammo_rockets - cost;
	W_SetupShot (self, FALSE, 2, "weapons/hagar_fire.wav", CVAR(g_balance_hagar_primary_damage));

	pointparticles(particleeffectnum("hagar_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);

	missile = spawn ();
	missile.owner = missile.realowner = Akimbo_Owner(self);
	missile.classname = "missile";
	missile.bot_dodge = TRUE;
	missile.bot_dodgerating = CVAR(g_balance_hagar_primary_damage);
	missile.touch = W_Hagar_Touch;
	missile.use = W_Hagar_Explode;
	missile.think = adaptor_think2use;
	missile.nextthink = time + CVAR(g_balance_hagar_primary_lifetime);
	PROJECTILE_MAKETRIGGER(missile);
	missile.projectiledeathtype = WEP_HAGAR;
	setorigin (missile, w_shotorg);
	setsize(missile, '0 0 0', '0 0 0');

	missile.movetype = MOVETYPE_FLY;
	missile.velocity = (w_shotdir + randomvec() * CVAR(g_balance_hagar_primary_spread)) * CVAR(g_balance_hagar_primary_speed);
	W_SetupProjectileVelocity(missile);

	missile.angles = vectoangles (missile.velocity);
	missile.flags = FL_PROJECTILE;

	CSQCProjectile(missile, TRUE, PROJECTILE_HAGAR, TRUE);
}

void W_Hagar_Attack2 (void)
{
    float cost = CVAR(g_balance_hagar_secondary_ammo);
    if(!W_Clip_Consume(cost))
        return;

	entity missile;

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_rockets = self.ammo_rockets - cost;
	W_SetupShot (self, FALSE, 2, "weapons/hagar_fire.wav", CVAR(g_balance_hagar_secondary_damage));
	//W_SetupShot (self, FALSE, 2, "weapons/hagar_fire.wav"); // TODO: move model a little to the right

	pointparticles(particleeffectnum("hagar_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);

	missile = spawn ();
	missile.owner = missile.realowner = Akimbo_Owner(self);
	missile.classname = "missile";
	missile.bot_dodge = TRUE;
	missile.bot_dodgerating = CVAR(g_balance_hagar_secondary_damage);
	missile.touch = W_Hagar_Touch2;
	missile.cnt = 0;
	missile.use = W_Hagar_Explode;
	missile.think = adaptor_think2use;
	missile.nextthink = time + CVAR(g_balance_hagar_secondary_lifetime_min) + random() * CVAR(g_balance_hagar_secondary_lifetime_rand);
	PROJECTILE_MAKETRIGGER(missile);
	missile.projectiledeathtype = WEP_HAGAR | HITTYPE_SECONDARY;
	setorigin (missile, w_shotorg);
	setsize(missile, '0 0 0', '0 0 0');

	missile.movetype = MOVETYPE_BOUNCEMISSILE;
	missile.velocity = (w_shotdir + randomvec() * CVAR(g_balance_hagar_secondary_spread)) * CVAR(g_balance_hagar_secondary_speed);
	W_SetupProjectileVelocity(missile);
	missile.avelocity = '100 10 10';

	missile.angles = vectoangles (missile.velocity);
	missile.flags = FL_PROJECTILE;

	CSQCProjectile(missile, TRUE, PROJECTILE_HAGAR_BOUNCING, TRUE);
}

void W_Hagar_SetClipContext(void) {
    W_Clip_SetWeaponContext(
        WEP_HAGAR,
        CVAR(g_balance_hagar_magazinecapacity),
        CVAR(g_balance_hagar_magazineregen),
        CVAR(g_balance_hagar_reloadtime),
        ammo_rockets,
        1
    );
}

void spawnfunc_weapon_hagar (void)
{
	weapon_defaultspawnfunc(WEP_HAGAR);
}

float w_hagar(float req)
{
    W_SetButtonFields(self, CVAR(g_balance_hagar_swapshotmodes));
    W_Hagar_SetClipContext();

	if (req == WR_AIM)
		if (random()>0.15)
			self.w_button_primary = bot_aim(CVAR(g_balance_hagar_primary_speed), 0, CVAR(g_balance_hagar_primary_lifetime), FALSE);
		else
		{
			// not using secondary_speed since these are only 15% and should cause some ricochets without re-aiming
			self.w_button_secondary = bot_aim(CVAR(g_balance_hagar_primary_speed), 0, CVAR(g_balance_hagar_primary_lifetime), FALSE);
		}
	else if (req == WR_THINK)
	{
        if(W_Clip_TryWeaponAction()) {
            if (self.w_button_primary)
            if (weapon_prepareattack(0, CVAR(g_balance_hagar_primary_refire)))
            if(W_Clip_TryAttackOrReload())
            {
                W_Hagar_Attack();
                weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_hagar_primary_refire), w_ready);
            }
            if (self.w_button_secondary)
            if (weapon_prepareattack(1, CVAR(g_balance_hagar_secondary_refire)))
            if(W_Clip_TryAttackOrReload())
            {
                W_Hagar_Attack2();
                weapon_thinkf(WFRAME_FIRE2, CVAR(g_balance_hagar_secondary_refire), w_ready);
            }
            W_Clip_FinishWeaponAction();
        }
	}
	else if (req == WR_PRECACHE)
	{
		precache_sound ("weapons/hagar_fire.wav");
	}
	else if (req == WR_SETUP)
		weapon_setup(WEP_HAGAR);
	else if (req == WR_CHECKAMMO1)
		return self.ammo_rockets >= CVAR(g_balance_hagar_primary_ammo);
	else if (req == WR_CHECKAMMO2)
		return self.ammo_rockets >= CVAR(g_balance_hagar_secondary_ammo);

    W_Clip_WeaponRequestHook(req);
	return TRUE;
};
