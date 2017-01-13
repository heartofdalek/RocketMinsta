.float HLAC_bulletcounter;
void W_HLAC_Touch (void)
{
	PROJECTILE_TOUCH;

	self.event_damage = SUB_Null;

    RadiusDamage (self, self.owner, CVAR(g_balance_hlac_primary_damage), CVAR(g_balance_hlac_primary_edgedamage), CVAR(g_balance_hlac_primary_radius), world, CVAR(g_balance_hlac_primary_force), self.projectiledeathtype, other);

	remove (self);
}

void W_HLAC_Touch2 (void)
{
	PROJECTILE_TOUCH;

	self.event_damage = SUB_Null;

    RadiusDamage (self, self.owner, CVAR(g_balance_hlac_secondary_damage), CVAR(g_balance_hlac_secondary_edgedamage), CVAR(g_balance_hlac_secondary_radius), world, CVAR(g_balance_hlac_secondary_force), self.projectiledeathtype, other);

	remove (self);
}

float W_HLAC_Attack (void)
{
	entity missile;
    float spread;
    float cost = CVAR(g_balance_hlac_primary_ammo);

    if(!W_Clip_Consume(cost))
        return FALSE;

    if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
        self.ammo_cells -= cost;

    spread = CVAR(g_balance_hlac_primary_spread_min) + (CVAR(g_balance_hlac_primary_spread_add) * self.HLAC_bulletcounter);
    spread = min(spread,CVAR(g_balance_hlac_primary_spread_max));
    if(self.crouch)
        spread = spread * CVAR(g_balance_hlac_primary_spread_crouchmod);

	W_SetupShot (self, FALSE, 3, "weapons/lasergun_fire.wav", CVAR(g_balance_hlac_primary_damage));
	pointparticles(particleeffectnum("laser_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);
	if (!g_norecoil)
	{
		self.punchangle_x = random () - 0.5;
		self.punchangle_y = random () - 0.5;
	}

	missile = spawn ();
	missile.owner = Akimbo_Owner(self);
	missile.classname = "hlacbolt";
	// missile.dmg = issecondary;
	missile.bot_dodge = TRUE;

    missile.bot_dodgerating = CVAR(g_balance_hlac_primary_damage);

	missile.movetype = MOVETYPE_FLY;
	PROJECTILE_MAKETRIGGER(missile);

	setorigin (missile, w_shotorg);
	setsize(missile, '0 0 0', '0 0 0');

    missile.velocity = (w_shotdir + randomvec() * spread) * CVAR(g_balance_hlac_primary_speed);

	W_SetupProjectileVelocity(missile);
	missile.angles = vectoangles (missile.velocity);

	missile.touch = W_HLAC_Touch;
	missile.think = SUB_Remove;

    missile.nextthink = time + CVAR(g_balance_hlac_primary_lifetime);

	missile.flags = FL_PROJECTILE;
	missile.projectiledeathtype = WEP_HLAC;

	CSQCProjectile(missile, TRUE, PROJECTILE_HLAC, TRUE);
    return TRUE;
}

void W_HLAC_Attack2f (void)
{
	entity missile;
    float spread;

    spread = CVAR(g_balance_hlac_secondary_spread);


    if(self.crouch)
        spread = spread * CVAR(g_balance_hlac_secondary_spread_crouchmod);

	W_SetupShot (self, FALSE, 3, "weapons/lasergun_fire.wav", CVAR(g_balance_hlac_secondary_damage));
	pointparticles(particleeffectnum("laser_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);

	missile = spawn ();
	missile.owner = Akimbo_Owner(self);
	missile.classname = "hlacbolt";
	// missile.dmg = issecondary;
	missile.bot_dodge = TRUE;

    missile.bot_dodgerating = CVAR(g_balance_hlac_secondary_damage);

	missile.movetype = MOVETYPE_FLY;
	PROJECTILE_MAKETRIGGER(missile);

	setorigin (missile, w_shotorg);
	setsize(missile, '0 0 0', '0 0 0');

    missile.velocity = (w_shotdir + randomvec() * spread) * CVAR(g_balance_hlac_secondary_speed);

	W_SetupProjectileVelocity(missile);
	missile.angles = vectoangles (missile.velocity);

	missile.touch = W_HLAC_Touch2;
	missile.think = SUB_Remove;

    missile.nextthink = time + CVAR(g_balance_hlac_secondary_lifetime);

	missile.flags = FL_PROJECTILE;
	missile.projectiledeathtype = WEP_HLAC | HITTYPE_SECONDARY;

	CSQCProjectile(missile, TRUE, PROJECTILE_HLAC, TRUE);
}

void W_HLAC_Attack2 (void)
{
    float i;
    float cost = CVAR(g_balance_hlac_secondary_ammo);

    if(!W_Clip_Consume(cost))
        return;

    if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
        self.ammo_cells -= cost;

    for(i=CVAR(g_balance_hlac_secondary_shots);i>0;--i)
        W_HLAC_Attack2f();

	if (!g_norecoil)
	{
		self.punchangle_x = random () - 0.5;
		self.punchangle_y = random () - 0.5;
	}
}


// weapon frames
void HLAC_fire1_02()
{
	if(self.weapon != self.switchweapon) // abort immediately if switching
	{
		w_ready();
		return;
	}

    W_SetButtonFields(self, CVAR(g_balance_hlac_swapshotmodes));

	if (self.w_button_primary)
	{
		if (!weapon_action(self.weapon, WR_CHECKAMMO1))
		{
			W_SwitchWeapon_OutOfAmmo(self);
			w_ready();
			return;
		}

		ATTACK_FINISHED(self) = time + CVAR(g_balance_hlac_primary_refire) * W_WeaponRateFactor();

		if(!W_HLAC_Attack())
            return;

		self.HLAC_bulletcounter = self.HLAC_bulletcounter + 1;
        weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_hlac_primary_refire), HLAC_fire1_02);
	}
	else
	{
		weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_hlac_primary_animtime), w_ready);
	}
};

void spawnfunc_weapon_hlac (void)
{
	weapon_defaultspawnfunc(WEP_HLAC);
}

void W_HLAC_SetClipContext(void) {
    W_Clip_SetWeaponContext(
        WEP_HLAC,
        CVAR(g_balance_hlac_magazinecapacity),
        CVAR(g_balance_hlac_magazineregen),
        CVAR(g_balance_hlac_reloadtime),
        ammo_cells,
        1
    );
}

float w_hlac(float req)
{
    W_SetButtonFields(self, CVAR(g_balance_hlac_swapshotmodes));
    W_HLAC_SetClipContext();

	if (req == WR_AIM)
        self.w_button_primary = bot_aim(CVAR(g_balance_hlac_primary_speed), 0, CVAR(g_balance_hlac_primary_lifetime), FALSE);
	else if (req == WR_THINK)
	{
        if(W_Clip_TryWeaponAction()) {
            if(self.w_button_primary)
            if(weapon_prepareattack(0, CVAR(g_balance_hlac_primary_refire)))
            if(W_Clip_TryAttackOrReload()) {
                self.HLAC_bulletcounter = 0;
                W_HLAC_Attack();
                weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_hlac_primary_refire), HLAC_fire1_02);
            }

            if(self.w_button_secondary)
            if(CVAR(g_balance_hlac_secondary))
            if(weapon_prepareattack(1, CVAR(g_balance_hlac_secondary_refire)))
            if(W_Clip_TryAttackOrReload()) {
                W_HLAC_Attack2();
                weapon_thinkf(WFRAME_FIRE2, CVAR(g_balance_hlac_secondary_animtime), w_ready);
            }

            W_Clip_FinishWeaponAction();
        }
	}
	else if (req == WR_PRECACHE)
	{
		precache_sound ("weapons/lasergun_fire.wav");
	}
	else if (req == WR_SETUP)
		weapon_setup(WEP_HLAC);
	else if (req == WR_CHECKAMMO1)
		return self.ammo_cells >= CVAR(g_balance_hlac_primary_ammo);
	else if (req == WR_CHECKAMMO2)
		return self.ammo_cells >= CVAR(g_balance_hlac_secondary_ammo);

    W_Clip_WeaponRequestHook(req);
	return TRUE;
};
