void(float imp) W_SwitchWeapon;

void W_Laser_Touch (void)
{
	PROJECTILE_TOUCH;

	self.event_damage = SUB_Null;
	if (self.dmg)
		RadiusDamage (self, self.owner, CVAR(g_balance_laser_secondary_damage), CVAR(g_balance_laser_secondary_edgedamage), CVAR(g_balance_laser_secondary_radius), world, CVAR(g_balance_laser_secondary_force), self.projectiledeathtype, other);
	else
		RadiusDamage (self, self.owner, CVAR(g_balance_laser_primary_damage), CVAR(g_balance_laser_primary_edgedamage), CVAR(g_balance_laser_primary_radius), world, CVAR(g_balance_laser_primary_force), self.projectiledeathtype, other);

	remove (self);
}

void W_Laser_Attack (float issecondary)
{
	entity missile;
	vector s_forward;
	float a;

	if (issecondary)
		a = CVAR(g_balance_laser_secondary_shotangle);
	else
		a = CVAR(g_balance_laser_primary_shotangle);
	s_forward = v_forward * cos(a * DEG2RAD) + v_up * sin(a * DEG2RAD);

	float lasr_recoil;
	lasr_recoil = 3;
	
	if(CVAR(g_rocketminsta_norecoil))
		lasr_recoil = 0;
	
	if(issecondary)
		W_SetupShot_Dir (self, s_forward, FALSE, lasr_recoil, "weapons/lasergun_fire.wav", CVAR(g_balance_laser_secondary_damage));
	else
		W_SetupShot_Dir (self, s_forward, FALSE, lasr_recoil, "weapons/lasergun_fire.wav", CVAR(g_balance_laser_primary_damage));
		
	pointparticles(particleeffectnum("laser_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);

	missile = spawn ();
	missile.owner = Akimbo_Owner(self);
	missile.classname = "laserbolt";
	missile.dmg = issecondary;
	missile.bot_dodge = TRUE;
	if (issecondary)
		missile.bot_dodgerating = CVAR(g_balance_laser_secondary_damage);
	else
		missile.bot_dodgerating = CVAR(g_balance_laser_primary_damage);

	missile.movetype = MOVETYPE_FLY;
	PROJECTILE_MAKETRIGGER(missile);
	missile.projectiledeathtype = WEP_LASER;
	if(issecondary)
		missile.projectiledeathtype |= HITTYPE_SECONDARY;

	setorigin (missile, w_shotorg);
	setsize(missile, '0 0 0', '0 0 0');

	if (issecondary)
		missile.velocity = w_shotdir * CVAR(g_balance_laser_secondary_speed);
	else
		missile.velocity = w_shotdir * CVAR(g_balance_laser_primary_speed);
	W_SetupProjectileVelocity(missile);
	missile.angles = vectoangles (missile.velocity);
	//missile.glow_color = 250; // 244, 250
	//missile.glow_size = 120;
	missile.touch = W_Laser_Touch;
	missile.think = SUB_Remove;
	if (issecondary)
		missile.nextthink = time + CVAR(g_balance_laser_secondary_lifetime);
	else
		missile.nextthink = time + CVAR(g_balance_laser_primary_lifetime);

	missile.flags = FL_PROJECTILE;

	CSQCProjectile(missile, TRUE, PROJECTILE_LASER, TRUE);
}

void spawnfunc_weapon_laser (void)
{
	weapon_defaultspawnfunc(WEP_LASER);
}

float w_laser(float req)
{
    W_SetButtonFields(self, CVAR(g_balance_laser_swapshotmodes));

	float r1;
	float r2;
	if (req == WR_AIM)
	{
		if(CVAR(g_balance_laser_secondary))
		{
			r1 = CVAR(g_balance_laser_primary_damage);
			r2 = CVAR(g_balance_laser_secondary_damage);
			if (random() * (r2 + r1) > r1)
				self.w_button_secondary = bot_aim(CVAR(g_balance_laser_secondary_speed), 0, CVAR(g_balance_laser_secondary_lifetime), FALSE);
			else
				self.w_button_primary = bot_aim(CVAR(g_balance_laser_primary_speed), 0, CVAR(g_balance_laser_primary_lifetime), FALSE);
		}
		else
			self.w_button_primary = bot_aim(CVAR(g_balance_laser_primary_speed), 0, CVAR(g_balance_laser_primary_lifetime), FALSE);
	}
	else if (req == WR_THINK)
	{
		if (self.w_button_primary)
		if (weapon_prepareattack(0, CVAR(g_balance_laser_primary_refire)))
		{
			W_Laser_Attack(FALSE);
			weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_laser_primary_animtime), w_ready);
		}
		if (self.w_button_secondary)
		{
			if(CVAR(g_balance_laser_secondary))
			{
				if (weapon_prepareattack(0, CVAR(g_balance_laser_secondary_refire)))
				{
					W_Laser_Attack(TRUE);
					weapon_thinkf(WFRAME_FIRE2, CVAR(g_balance_laser_secondary_animtime), w_ready);
				}
			}
			else
			{
				if(self.switchweapon == WEP_LASER) // don't do this if already switching
					W_SwitchWeapon (self.cnt);
			}
		}
	}
	else if (req == WR_PRECACHE)
	{
		precache_sound ("weapons/lasergun_fire.wav");
	}
	else if (req == WR_SETUP)
		weapon_setup(WEP_LASER);
	else if (req == WR_CHECKAMMO1)
		return TRUE;
	else if (req == WR_CHECKAMMO2)
		return TRUE;
	return TRUE;
};
