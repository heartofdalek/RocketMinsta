//Camping rifle Primary mode: manually operated bolt*, Secondary: full automatic**
//* Manually operating the bolt means that all the power of the gas is used to propell the bullet. In this mode the bolt is prevented from moving backwards in response to the firing of the bullet.
//** In fully automatic mode some of the gas is used to extract and reload the next cartrige, thus there is less power and range.

.float campingrifle_accumulator;
.float campingrifle_streak;
.float campingrifle_lastburst;

var .float campingrifle_varfield_hitstreak;
var .float campingrifle_varfield_hitstreak_expiretime;

void W_CampingRifle_SetClipContext(void) {
    W_Clip_SetWeaponContext(
        WEP_CAMPINGRIFLE,
        CVAR(g_balance_campingrifle_magazinecapacity),
        CVAR(g_balance_campingrifle_magazineregen),
        CVAR(g_balance_campingrifle_reloadtime),
        ammo_nails,
        min(
            CVAR(g_balance_campingrifle_primary_ammo),
            CVAR(g_balance_campingrifle_secondary_ammo)
        )
    );
}

void W_CampingRifle_SetHitstreakFields(float deathtype) {
    //set the campingrifle_varfield_* globals to point to fields appropriate for the current firing mode

    if((deathtype & HITTYPE_SECONDARY) || CVAR(g_balance_campingrifle_hitstreaks_shared)) {
        campingrifle_varfield_hitstreak = campingrifle_hitstreak2;
        campingrifle_varfield_hitstreak_expiretime = campingrifle_hitstreak2_expiretime;
    } else {
        campingrifle_varfield_hitstreak = campingrifle_hitstreak1;
        campingrifle_varfield_hitstreak_expiretime = campingrifle_hitstreak1_expiretime;
    }
}

void W_CampingRifle_ResetHitstreaksIfNeeded(float deathtype) {
	//reset the streak if no hit has been made with either mode if both are enabled or just each fire mode individually

    W_CampingRifle_SetHitstreakFields(deathtype);
    if(time > self.campingrifle_varfield_hitstreak_expiretime)
        self.campingrifle_varfield_hitstreak = 0;
}

float W_CampingRifle_GetHitstreakBonus(float deathtype) {
	//return the bonus for whatever mode was fired, regardless of which mode built up the streak
	//if both modes can build up a streak, use secondary's value as a shared pool

    W_CampingRifle_SetHitstreakFields(deathtype);
    float streak = bound(0, self.campingrifle_varfield_hitstreak, self.w_clip_limit_stat);

    if(streak) {
        return streak * cvar(if(deathtype & HITTYPE_SECONDARY)
                                "g_balance_campingrifle_secondary_hitstreakbonus"
                             else
                                "g_balance_campingrifle_primary_hitstreakbonus");
    }

    return 0;
}

void W_CampingRifle_RegisterHitForHitstreak(entity attacker, float deathtype) {
    if(!DEATH_ISWEAPON(deathtype, WEP_CAMPINGRIFLE))
        return;

    if(deathtype & HITTYPE_SECONDARY) {
        if(!CVAR(g_balance_campingrifle_secondary_hitstreaks))
            return;
    } else if(!CVAR(g_balance_campingrifle_primary_hitstreaks))
        return;

    W_CampingRifle_SetHitstreakFields(deathtype);

    attacker.campingrifle_varfield_hitstreak += 1;
    attacker.campingrifle_varfield_hitstreak_expiretime = max(
        attacker.campingrifle_varfield_hitstreak_expiretime, 
        time + cvar(if(deathtype & HITTYPE_SECONDARY)
                        "g_balance_campingrifle_secondary_hitstreak_resettime"
                    else
                        "g_balance_campingrifle_primary_hitstreak_resettime")
    );
}

void W_CampingRifle_FireBullet(float pSpread, float pDamage, float pHeadshotAddedDamage, float pForce, float pSpeed, float pLifetime, float pAmmo, float deathtype, float pBulletConstant, float cost)
{

    if(!W_Clip_Consume(cost))
        return;

	float dmgbonus;
	if(CVAR(g_balance_campingrifle_hitstreaks)){
		W_CampingRifle_ResetHitstreaksIfNeeded(deathtype);
		dmgbonus = W_CampingRifle_GetHitstreakBonus(deathtype);
	}

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_nails -= pAmmo;

	if(deathtype & HITTYPE_SECONDARY)
		W_SetupShot_HitMask(self, CVAR(g_antilag_bullets) && pSpeed >= CVAR(g_antilag_bullets), CVAR(g_balance_campingrifle_secondary_recoilamount), "weapons/campingrifle_fire2.wav", CVAR(g_balance_campingrifle_secondary_damage), DPCONTENTS_BODY | DPCONTENTS_CORPSE);
	else
		W_SetupShot_HitMask(self, CVAR(g_antilag_bullets) && pSpeed >= CVAR(g_antilag_bullets), CVAR(g_balance_campingrifle_primary_recoilamount), "weapons/campingrifle_fire.wav", CVAR(g_balance_campingrifle_primary_damage), DPCONTENTS_BODY | DPCONTENTS_CORPSE);

	if(self.BUTTON_ZOOM) // if zoomed, shoot from the eye
	{
		w_shotdir = v_forward;
		w_shotorg = self.origin + self.view_ofs + ((w_shotorg - self.origin - self.view_ofs) * v_forward) * v_forward;
	}

	fireBallisticBullet(w_shotorg, w_shotdir, pSpread, pSpeed, pLifetime, pDamage + dmgbonus, pHeadshotAddedDamage / pDamage, pForce, deathtype, EF_RED, 1, pBulletConstant);
	endFireBallisticBullet();

    pointparticles(particleeffectnum("shotgun_muzzleflash"), w_shotorg_visual, w_shotdir_visual * 2000, 1);

	if (CVAR(g_casings) >= 2)
		SpawnCasing (((random () * 50 + 50) * v_right) - (v_forward * (random () * 25 + 25)) - ((random () * 5 - 70) * v_up), 2, vectoangles(v_forward),'0 250 0', 100, 3, self);
}

void W_CampingRifle_Attack()
{
    var pts = Buffs_MEODP_Hitscan_Begin(self);
	W_CampingRifle_FireBullet(
        CVAR(g_balance_campingrifle_primary_spread),
        CVAR(g_balance_campingrifle_primary_damage),
        CVAR(g_balance_campingrifle_primary_headshotaddeddamage),
        CVAR(g_balance_campingrifle_primary_force),
        CVAR(g_balance_campingrifle_primary_speed),
        CVAR(g_balance_campingrifle_primary_lifetime),
        CVAR(g_balance_campingrifle_primary_ammo),
        WEP_CAMPINGRIFLE,
        CVAR(g_balance_campingrifle_primary_bulletconstant),
        CVAR(g_balance_campingrifle_primary_bulletcost)
    );
    Buffs_MEODP_Hitscan_End(pts);
}

void W_CampingRifle_Attack2()
{
    float sprd;
    float add;
	
    sprd = CVAR(g_balance_campingrifle_secondary_spread);
    add  = CVAR(g_balance_campingrifle_secondary_spread_addedperbullet);
	
    if(add) {
        if(time - self.campingrifle_lastburst > CVAR(g_balance_campingrifle_secondary_spread_resettime))
            self.campingrifle_streak = 0;
        sprd = sprd + add * self.campingrifle_streak;
        self.campingrifle_streak += 1;
        self.campingrifle_lastburst = time;
    }
	
	W_CampingRifle_FireBullet(sprd, CVAR(g_balance_campingrifle_secondary_damage), CVAR(g_balance_campingrifle_secondary_headshotaddeddamage), CVAR(g_balance_campingrifle_secondary_force), CVAR(g_balance_campingrifle_secondary_speed), CVAR(g_balance_campingrifle_secondary_lifetime), CVAR(g_balance_campingrifle_secondary_ammo), WEP_CAMPINGRIFLE | HITTYPE_SECONDARY, CVAR(g_balance_campingrifle_secondary_bulletconstant), CVAR(g_balance_campingrifle_secondary_bulletcost));
}

void spawnfunc_weapon_campingrifle (void)
{
	weapon_defaultspawnfunc(WEP_CAMPINGRIFLE);
}

.float bot_secondary_campingriflemooth;

float w_campingrifle(float req)
{
    W_SetButtonFields(self, CVAR(g_balance_campingrifle_swapshotmodes));
    W_CampingRifle_SetClipContext();

	if (req == WR_AIM)
	{
		self.w_button_primary=FALSE;
		self.w_button_secondary=FALSE;
		if(vlen(self.origin-self.enemy.origin) > 1000)
			self.bot_secondary_campingriflemooth = 0;
		if(self.bot_secondary_campingriflemooth == 0)
		{
			if(bot_aim(CVAR(g_balance_campingrifle_primary_speed), 0, CVAR(g_balance_campingrifle_primary_lifetime), TRUE))
			{
				self.w_button_primary = TRUE;
				if(random() < 0.01) self.bot_secondary_campingriflemooth = 1;
			}
		}
		else
		{
			if(bot_aim(CVAR(g_balance_campingrifle_secondary_speed), 0, CVAR(g_balance_campingrifle_secondary_lifetime), TRUE))
			{
				self.w_button_secondary = TRUE;
				if(random() < 0.03) self.bot_secondary_campingriflemooth = 0;
			}
		}
	}
	else if (req == WR_THINK)
	{
		if(W_Clip_TryWeaponAction()) {
			self.campingrifle_accumulator = bound(time - CVAR(g_balance_campingrifle_bursttime), self.campingrifle_accumulator, time);

			if(self.w_button_primary)
			if(time >= self.campingrifle_accumulator + CVAR(g_balance_campingrifle_primary_burstcost))
			if(weapon_prepareattack(0, CVAR(g_balance_campingrifle_primary_refire))) {
                if(W_Clip_TryAttackOrReload()) {
                    W_CampingRifle_Attack();
                    weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_campingrifle_primary_animtime), W_Clip_CheckReloadAndReady);
                    self.campingrifle_accumulator += CVAR(g_balance_campingrifle_primary_burstcost);
                }
			}

			if(self.w_button_secondary)
			if(time >= self.campingrifle_accumulator + CVAR(g_balance_campingrifle_secondary_burstcost))
			if(weapon_prepareattack(1, CVAR(g_balance_campingrifle_secondary_refire))) {
                if(W_Clip_TryAttackOrReload()) {
                    W_CampingRifle_Attack2();
                    weapon_thinkf(WFRAME_FIRE2, CVAR(g_balance_campingrifle_secondary_animtime), W_Clip_CheckReloadAndReady);
                    self.campingrifle_accumulator += CVAR(g_balance_campingrifle_secondary_burstcost);
                }
			}

            W_Clip_FinishWeaponAction();
		}
	}
	else if (req == WR_PRECACHE)
	{
		precache_sound ("weapons/campingrifle_fire.wav");
		precache_sound ("weapons/campingrifle_fire2.wav");
	}
	else if (req == WR_SETUP)
	{
		weapon_setup(WEP_CAMPINGRIFLE);
	}
	else if (req == WR_CHECKAMMO1)
		return self.ammo_nails >= CVAR(g_balance_campingrifle_primary_ammo);
	else if (req == WR_CHECKAMMO2)
		return self.ammo_nails >= CVAR(g_balance_campingrifle_secondary_ammo);
	else if (req == WR_RESETPLAYER)
	{
		self.campingrifle_accumulator = time - CVAR(g_balance_campingrifle_bursttime);
	}

    W_Clip_WeaponRequestHook(req);
	return TRUE;
};
