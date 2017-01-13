
.entity nex_charge_effect;
.float nex_charge_readytime;
.float nex_charge_expiretime;
.float nex_burst_counter;
.float nex_burst_hitstreak;
.float nex_last_refire_delay;

void SendCSQCNexBeamParticle(float theteam, float secondary) {
	vector v;
	v = WarpZone_UnTransformOrigin(WarpZone_trace_transform, trace_endpos);

	WriteByte(MSG_BROADCAST, SVC_TEMPENTITY);
	WriteByte(MSG_BROADCAST, TE_CSQC_NEXGUNBEAMPARTICLE);

	WriteCoord(MSG_BROADCAST, w_shotorg_visual_x);
	WriteCoord(MSG_BROADCAST, w_shotorg_visual_y);
	WriteCoord(MSG_BROADCAST, w_shotorg_visual_z);
	WriteCoord(MSG_BROADCAST, w_shotorg_x);
	WriteCoord(MSG_BROADCAST, w_shotorg_y);
	WriteCoord(MSG_BROADCAST, w_shotorg_z);
	WriteCoord(MSG_BROADCAST, v_x);
	WriteCoord(MSG_BROADCAST, v_y);
	WriteCoord(MSG_BROADCAST, v_z);
    WriteByte(MSG_BROADCAST, theteam);
    WriteByte(MSG_BROADCAST, secondary);
}

void W_Nex_Attack (void)
{
    float cost = CVAR(g_balance_nex_ammo);
    if(!W_Clip_Consume(cost))
        return;

	float flying;
	flying = IsFlying(self); // do this BEFORE to make the trace values from FireRailgunBullet last

	W_SetupShot(self, TRUE, 5, "weapons/nexfire.wav", CVAR(g_balance_nex_damage));

	yoda = 0;

    var pts = Buffs_MEODP_Hitscan_Begin(self);
	FireRailgunBullet(w_shotorg, w_shotorg + w_shotdir * MAX_SHOT_DISTANCE,
        CVAR(g_balance_nex_damage),
        CVAR(g_balance_nex_force),
        CVAR(g_balance_nex_damagefalloff_mindist),
        CVAR(g_balance_nex_damagefalloff_maxdist),
        CVAR(g_balance_nex_damagefalloff_halflife),
        CVAR(g_balance_nex_damagefalloff_forcehalflife),
        WEP_NEX
    );
    Buffs_MEODP_Hitscan_End(pts);

	if(yoda && flying)
        CSQCMessage_Praise(self, CSQCMSG_PRAISEFLAG_AMAZING);

    W_SetHitscanVisuals(self, trace_endpos);

	//beam and muzzle flash done on client
	SendCSQCNexBeamParticle(self.team, FALSE);

    if(Buffs_Present(self, BUFF_MEDIC))
        WarpZone_TrailParticles(world, particleeffectnum("RM_HEAL_TRAIL"), w_shotorg, w_shotorg_visual, trace_endpos);

	// flash and burn the wall
	if (trace_ent.solid == SOLID_BSP && !(trace_dphitq3surfaceflags & Q3SURFACEFLAG_NOIMPACT))
		Damage_DamageInfo(trace_endpos, cvar("g_balance_nex_damage"), 0, 0, CVAR(g_balance_nex_force) * WarpZone_trace_dir, WEP_NEX, self);

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_cells = self.ammo_cells - cost;

    self.w_inring_fulltime = ATTACK_FINISHED(self);
    self.w_inring_cycle = self.w_inring_fulltime - time;
    self.nex_last_refire_delay = self.w_inring_cycle;
}

void W_Nex_Attack2(void) {
    float cost = CVAR(g_balance_nex_secondary_ammo);
    if(!W_Clip_Consume(cost))
        return;

    float flying;
    flying = IsFlying(self); // do this BEFORE to make the trace values from FireRailgunBullet last

    var damage = CVAR(g_balance_nex_secondary_damage) + CVAR(g_balance_nex_secondary_damage_burst_hitstreakbonus) * self.nex_burst_hitstreak;

    W_SetupShot(self, TRUE, 5, "weapons/rm_minsta.wav", damage);

    yoda = 0;

    var pts = Buffs_MEODP_Hitscan_Begin(self);
    FireRailgunBullet(w_shotorg, w_shotorg + w_shotdir * MAX_SHOT_DISTANCE,
        damage,
        CVAR(g_balance_nex_secondary_force),
        CVAR(g_balance_nex_secondary_damagefalloff_mindist),
        CVAR(g_balance_nex_secondary_damagefalloff_maxdist),
        CVAR(g_balance_nex_secondary_damagefalloff_halflife),
        CVAR(g_balance_nex_secondary_damagefalloff_forcehalflife),
        WEP_NEX | HITTYPE_SECONDARY
        );

    Buffs_MEODP_Hitscan_End(pts);

    if(yoda && flying)
        CSQCMessage_Praise(self, CSQCMSG_PRAISEFLAG_AMAZING);

    W_SetHitscanVisuals(self, trace_endpos);

    //beam and muzzle flash done on client
    SendCSQCNexBeamParticle(self.team, TRUE);

    if(Buffs_Present(self, BUFF_MEDIC))
        WarpZone_TrailParticles(world, particleeffectnum("RM_HEAL_TRAIL"), w_shotorg, w_shotorg_visual, trace_endpos);

    // flash and burn the wall
    if (trace_ent.solid == SOLID_BSP && !(trace_dphitq3surfaceflags & Q3SURFACEFLAG_NOIMPACT))
        Damage_DamageInfo(trace_endpos, damage, 0, 0, CVAR(g_balance_nex_secondary_force) * w_shotdir, WEP_NEX, self);

    if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
        self.ammo_cells = self.ammo_cells - cost;
}

void W_Nex_ChargeEffect_Think(void) {
    if(!Akimbo_Owner(self.owner).iscreature || !PlayerMayFire(Akimbo_Owner(self.owner))) {
        if(self == self.owner.nex_charge_effect)
            self.owner.nex_charge_effect = world;

        stopsound(self, CHAN_PROJECTILE);
        remove(self);
        return;
    }

    if(self.enemy.cnt < 0) {
        stopsound(self, CHAN_PROJECTILE);

        if(self.enemy.cnt < -1) {
            self.scale = approach(self.scale, 0, frametime * 5);
            self.alpha = approach(self.alpha, 0, frametime * 5);

            if(self.scale <= 0)
                remove(self);
            else
                self.nextthink = time;
        } else {
            self.scale = approach(self.scale, 10, frametime * 50);
            self.alpha = 1 - self.scale / 10;
            self.alpha *= self.alpha;

            if(self.scale >= 10)
                remove(self);
            else
                self.nextthink = time;
        }

        return;
    }

    self.scale = approach(self.scale, 1, (1 / self.cnt) * frametime);

    self.light_lev = self.scale * 200;
    self.nextthink = time;
}

void W_Nex_ChargeEffect_Spawn(float ct) {
    if(self.nex_charge_effect)
        self.nex_charge_effect.cnt = -1;

    entity e = spawn();
    setmodel(e, "models/nexcharge.iqm");
    // setmodel(e, "models/ebomb.mdl");
    e.skin = 2;
    e.cnt = ct;
    e.think = W_Nex_ChargeEffect_Think;
    e.nextthink = time;
    e.scale = 0.01;
    e.enemy = e;
    e.pflags = PFLAGS_FULLDYNAMIC;
    e.owner = self;
    e.color = '0.3 0.3 0.3' + 0.7 * TeamColor(if(self.team > 0) self.team else COLOR_TEAM2);
    e.colormap = self.colormap;
    W_AttachToShotorg(e, '-10 0 2');

    // needs to be done AFTER W_AttachToShotorg
    e.customizeentityforclient = CL_Weaponentity_CustomizeEntityForClient;

    sound(e, CHAN_PROJECTILE, "weapons/electro_fly.wav", VOL_BASE, ATTN_NORM);
    self.nex_charge_effect = e;
}

void W_Nex_RegisterHitForHitstreak(entity attacker, float deathtype) {
    if(deathtype & HITTYPE_SECONDARY)
        attacker.nex_burst_hitstreak += 1;
}

void W_Nex_Attack2_Burst(void) {
    W_Nex_Attack2();
    ATTACK_FINISHED(self) = time + CVAR(g_balance_nex_secondary_refire) * W_WeaponRateFactor();

    self.nex_burst_counter -= 1;

    if(self.nex_burst_counter && PlayerMayFire(self))
        weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_nex_secondary_burst_refire), W_Nex_Attack2_Burst);
    else
        weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_nex_secondary_animtime), w_ready);
}

void W_Nex_Attack2_Wait(void) {
    var rate = W_WeaponRateFactor();
    var ccnt = -1;

    W_SetButtonFields(self, CVAR(g_balance_nex_swapshotmodes));

    if(time >= self.nex_charge_readytime && self.w_inring_cycle > 0) {
        self.w_inring_fulltime = self.nex_charge_expiretime;
        self.w_inring_cycle = time - self.w_inring_fulltime;
    }

    if(self.w_button_secondary && time < self.nex_charge_expiretime)
        return;


    if(PlayerMayFire(self) && time >= self.nex_charge_readytime) {
        self.nex_burst_counter = CVAR(g_balance_nex_secondary_burst_amount);
        self.nex_burst_hitstreak = 0;
        W_Nex_Attack2_Burst();
        self.w_inring_fulltime = ATTACK_FINISHED(self);
        self.w_inring_cycle = self.w_inring_fulltime - time;
        self.nex_last_refire_delay = self.w_inring_cycle;
    } else {
        ccnt = -2;
        stopsound(self, CHAN_WEAPON);
        ATTACK_FINISHED(self) = time + CVAR(g_balance_nex_secondary_cancel_refire) * rate;
        weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_nex_secondary_animtime), w_ready);
        self.w_inring_fulltime = -1;
    }

    if(self.nex_charge_effect) {
        self.nex_charge_effect.cnt = ccnt;
        self.nex_charge_effect = world;
    }
}

void W_Nex_SetClipContext(void) {
    W_Clip_SetWeaponContext(
        WEP_NEX,
        CVAR(g_balance_nex_magazinecapacity),
        CVAR(g_balance_nex_magazineregen),
        CVAR(g_balance_nex_reloadtime),
        ammo_cells,
        1
    );
}

void spawnfunc_weapon_nex (void); // defined in t_items.qc

float w_nex(float req)
{
    W_SetButtonFields(self, CVAR(g_balance_nex_swapshotmodes));
    W_Nex_SetClipContext();

	if (req == WR_AIM)
		self.w_button_primary = bot_aim(1000000, 0, 1, FALSE);
	else if (req == WR_THINK)
	{
        if(W_Clip_TryWeaponAction()) {
            if(self.w_button_primary)
            if(W_Clip_TryAttackOrReload()) {
                if (weapon_prepareattack(0, CVAR(g_balance_nex_refire)))
                {
                    W_Nex_Attack();
                    weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_nex_animtime), w_ready);
                }
            }
            if(self.w_button_secondary && CVAR(g_balance_nex_secondary))
            if(W_Clip_TryAttackOrReload()) {
                if(weapon_prepareattack(1, CVAR(g_balance_nex_secondary_refire))) {
                    var rate = W_WeaponRateFactor();
                    var ct = CVAR(g_balance_nex_secondary_chargetime);
                    var cr = CVAR(g_balance_nex_secondary_chargeholdtime_required) * rate;

                    weapon_thinkf(WFRAME_FIRE2, ct, W_Nex_Attack2_Wait);
                    ct *= rate;
                    cr = max(cr, ct);

                    self.nex_charge_readytime  = time + cr;
                    self.nex_charge_expiretime = time + ct + CVAR(g_balance_nex_secondary_chargeholdtime);

                    sound(self, CHAN_WEAPON, "weapons/nex_charge.wav", VOL_BASE, ATTN_NORM);
                    W_Nex_ChargeEffect_Spawn(cr);

                    self.w_inring_fulltime = self.nex_charge_readytime;
                    self.w_inring_cycle = self.w_inring_fulltime - time;
                }
            }
            W_Clip_FinishWeaponAction();

            if(self.weaponentity.wframe == WFRAME_IDLE && !self.w_inring_fulltime) {
                var af = ATTACK_FINISHED(self);

                if(af > time) {
                    self.w_inring_fulltime = af;
                    self.w_inring_cycle = self.nex_last_refire_delay;
                }
            }
        }
	}
	else if (req == WR_PRECACHE)
	{
		precache_model("models/nexflash.md3");
        precache_model("models/nexcharge.iqm");
		precache_sound("weapons/nexfire.wav");
		precache_sound("weapons/nexwhoosh1.wav");
		precache_sound("weapons/nexwhoosh2.wav");
		precache_sound("weapons/nexwhoosh3.wav");
        precache_sound("weapons/rm_minsta.wav");
        precache_sound("weapons/nex_charge.wav");
        precache_sound("weapons/electro_fly.wav");
	}
	else if (req == WR_SETUP)
		weapon_setup(WEP_NEX);
	else if (req == WR_CHECKAMMO1)
		return self.ammo_cells >= CVAR(g_balance_nex_ammo);
	else if (req == WR_CHECKAMMO2)
		return self.ammo_cells >= CVAR(g_balance_nex_secondary_ammo);
    W_Clip_WeaponRequestHook(req);
	return TRUE;
};
