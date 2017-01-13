
.float flak_group_counter;

void W_Flak_Projectile_Touch(void) {
    PROJECTILE_TOUCH;

    if(other.takedamage) {
        float damage, bnc, frc;

        if(other != self.enemy && (other != self.realowner || self.projectiledeathtype & HITTYPE_BOUNCE)) {
            if(self.projectiledeathtype & HITTYPE_SECONDARY) {
                bnc = pow(CVAR(g_balance_flak_secondary_damage_bouncefactor), self.cnt);
                damage = CVAR(g_balance_flak_secondary_damage) * bnc;
                frc = CVAR(g_balance_flak_secondary_force) * bnc;
            } else {
                bnc = pow(CVAR(g_balance_flak_primary_damage_bouncefactor), self.cnt);
                damage = CVAR(g_balance_flak_primary_damage) * bnc;
                frc = CVAR(g_balance_flak_primary_force) * bnc;
            }

            vector force = normalize(NearestPointOnBox(other, self.origin) - self.origin + self.velocity) * frc;

            self.owner = self.realowner;
            Damage(other, self, self.realowner, damage, self.projectiledeathtype, self.origin, force);

            if(W_Accuracy_IsGoodHit(self.realowner, other))
                W_Accuracy_RegisterActualDamage(self.realowner, WEP_FLAK, damage);
        }

        pointparticles(particleeffectnum("hagar_bounce"), self.origin, self.velocity, 1);

        float passThrough;
        if(self.projectiledeathtype & HITTYPE_SECONDARY)
            passThrough = CVAR(g_balance_flak_secondary_passthrough);
        else
            passThrough = CVAR(g_balance_flak_primary_passthrough);

        if(passThrough <= 0) {
            remove(self);
            return;
        }

        // semi-fix for "melee" hits
        if(other == self.realowner && !(self.projectiledeathtype & HITTYPE_BOUNCE))
            self.velocity = self.velocity * -1;

        // pass through - we don't want to bounce here, overwrite velocity later
        self.oldvelocity = self.velocity * passThrough;

        // we don't want to hit the same entity again right away
        self.owner = other;
        if(other.iscreature)
            self.enemy = other;
    } else if(other.solid == SOLID_BSP) {
        spamsound(self, CHAN_PROJECTILE, strcat("weapons/casings", ftos(floor(random() * 3) + 1), ".wav"), VOL_BASE * 0.7, ATTN_NORM);

        if(other) {
            // brushmodel - client won't register this hit, so we have to spawn the particle here.
            // For world collisions, the same is done client-side.
            pointparticles(particleeffectnum("hagar_bounce"), self.origin, self.velocity, 1);
        }

        self.owner = world;
        self.projectiledeathtype |= HITTYPE_BOUNCE;
        self.cnt += 1;

        // ensure that flak projectiles from the same batch never collide with each other
        if(self.clipgroup != CLIPGROUP_FLAK) {
            for(var e = world; (e = findfloat(e, flak_group_counter, self.flak_group_counter));) {
                if(e.realowner == self.realowner && e.classname == "flak_proj")
                    e.clipgroup = CLIPGROUP_FLAK;
            }
        }
    }
}

void W_Flak_Projectile_Think(void) {
    if(time > self.spawnshieldtime) {
        remove(self);
        return;
    }

    if(self.oldvelocity) {
        self.velocity = self.oldvelocity;
        self.oldvelocity = '0 0 0';
        UpdateCSQCProjectile(self);
    }

    self.nextthink = time;
}

entity W_Flak_Projectile(entity o, float damage, float grav, float lt, float spd, float upspd, float bnc, float deathtype) {
    entity e = spawn();
    e.owner = e.realowner = Akimbo_Owner(o);
    e.classname = "flak_proj";
    e.bot_dodge = TRUE;
    e.bot_dodgerating = damage;
    e.movetype = MOVETYPE_BOUNCE;
    PROJECTILE_MAKETRIGGER(e);
    e.projectiledeathtype = deathtype;
    e.gravity = grav;
    e.bouncefactor = bnc;
    setorigin(e, w_shotorg);
    setsize(e, '-4 -4 -4', '4 4 4');

    e.spawnshieldtime = time + lt;
    e.nextthink = time;
    e.think = W_Flak_Projectile_Think;
    e.touch = W_Flak_Projectile_Touch;
    e.velocity = v_forward * spd + v_up * upspd;
    W_SetupProjectileVelocity(e);

    if(!e.clipgroup)
        e.clipgroup = CLIPGROUP_FLAK;

    e.angles = vectoangles(e.velocity);
    e.flags = FL_PROJECTILE;

    e.flak_group_counter = o.flak_group_counter;

    CSQCProjectile(e, TRUE, PROJECTILE_FLAK, TRUE);   
    return e;
}

void W_Flak_Attack(float isprim, float spreadmod) {
    float cost = WEP_CVAR_BOTH(flak, isprim, ammo);
    if(!W_Clip_Consume(cost))
        return;

    float pcount = WEP_CVAR_BOTH(flak, isprim, projectiles), i;

    if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
        self.ammo_shells -= cost;

    W_SetupShot_ProjectileSize(self, '-4 -4 -4', '4 4 4', FALSE, 4,
        if(isprim) "weapons/flak_fire.wav" else "weapons/flak_fire2.wav",
        WEP_CVAR_BOTH(flak, isprim, damage) * pcount
    );

    w_shotdir = v_forward;

    self.flak_group_counter += 1;

    for(i = 0; i < pcount; ++i) {
        vector a = vectoangles(w_shotdir);

        var m_up = WEP_CVAR_BOTH(flak, isprim, charge_spreadmod_up)   * spreadmod;
        var m_sd = WEP_CVAR_BOTH(flak, isprim, charge_spreadmod_side) * spreadmod;

        fixedmakevectors2(a + '1 0 0' *  random() * (m_up + WEP_CVAR_BOTH(flak, isprim, spread_up))
                            + '0 1 0' * crandom() * (m_sd + WEP_CVAR_BOTH(flak, isprim, spread_side)));

        W_Flak_Projectile(self,
                          WEP_CVAR_BOTH(flak, isprim, damage),
                          WEP_CVAR_BOTH(flak, isprim, gravity),
                          WEP_CVAR_BOTH(flak, isprim, lifetime),
                          WEP_CVAR_BOTH(flak, isprim, speed),
                          WEP_CVAR_BOTH(flak, isprim, speed_up),
                          WEP_CVAR_BOTH(flak, isprim, bouncefactor),
                          WEP_FLAK);
    }

    entity flash = spawn();
    setmodel(flash, "models/uziflash.md3");
    flash.think = SUB_Remove;
    flash.nextthink = time + 0.06;
    flash.effects = EF_ADDITIVE | EF_FULLBRIGHT | EF_LOWPRECISION;
    W_AttachToShotorg(flash, '5 0 0');
}

void W_Flak_Bomb_Explode(void) {
    vector dir = normalize(self.velocity);
    dir = dir - 2 * (dir * trace_plane_normal) * trace_plane_normal; 

    if(other.takedamage == DAMAGE_AIM)
        if(other.classname == "player")
            if(IsDifferentTeam(self.owner, other))
                if(IsFlying(other))
                    CSQCMessage_Praise(self.owner, CSQCMSG_PRAISEFLAG_AIRSHOT);

    self.event_damage = SUB_Null;
    self.takedamage = DAMAGE_NO;
    RadiusDamage(self, self.owner, CVAR(g_balance_flak_secondary_bomb_damage), CVAR(g_balance_flak_secondary_bomb_edgedamage), CVAR(g_balance_flak_secondary_bomb_radius), world, CVAR(g_balance_flak_secondary_bomb_force), self.projectiledeathtype, other);

    float i, c = CVAR(g_balance_flak_secondary_projectiles);
    w_shotorg = self.origin;

    float spread_up, spread_side;

    if(other.takedamage == DAMAGE_AIM && other.iscreature) {
        spread_side = 360;
        spread_up = 360;
    } else {
        spread_side = CVAR(g_balance_flak_secondary_spread_side);
        spread_up = CVAR(g_balance_flak_secondary_spread_up);
    }

    self.owner.flak_group_counter += 1;

    for(i = 0; i < c; ++i) {
        vector a = vectoangles(dir);

        fixedmakevectors2(a + '1 0 0' * crandom() * spread_up
                            + '0 1 0' * crandom() * spread_side);

        entity p = W_Flak_Projectile(self.owner,
                          CVAR(g_balance_flak_secondary_damage),
                          CVAR(g_balance_flak_secondary_gravity),
                          CVAR(g_balance_flak_secondary_lifetime),
                          CVAR(g_balance_flak_secondary_speed),
                          CVAR(g_balance_flak_secondary_speed_up),
                          CVAR(g_balance_flak_secondary_bouncefactor),
                          WEP_FLAK | HITTYPE_SECONDARY | HITTYPE_BOUNCE);

        // do not hit the direct hit entity with shrapnel right away (causes very inconsistent behavior)
        p.owner = other;
    }

    remove (self);
}

void W_Flak_Bomb_Touch(void) {
    PROJECTILE_TOUCH;
    self.use();
}

void W_Flak_Bomb_Damage(entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force) {
    W_Grenade_Damage(inflictor, attacker, damage, deathtype, hitloc, force);
}

void W_Flak_Attack_Bomb(void) {
    float cost = CVAR(g_balance_flak_secondary_ammo);
    if(!W_Clip_Consume(cost))
        return;

    if not(self.items & IT_UNLIMITED_WEAPON_AMMO) {
        self.ammo_shells = self.ammo_shells - cost;
        self.ammo_rockets = self.ammo_rockets - CVAR(g_balance_flak_secondary_ammo_rockets);
    }

    W_SetupShot_ProjectileSize (self, '0 0 -3', '0 0 -3', FALSE, 4, "weapons/flak_fire3.wav", CVAR(g_balance_flak_secondary_bomb_damage));
    w_shotdir = v_forward;

    entity e = spawn();
    e.owner = Akimbo_Owner(self);
    e.classname = "flak_bomb";
    e.bot_dodge = TRUE;
    e.bot_dodgerating = CVAR(g_balance_flak_secondary_bomb_damage);
    e.movetype = MOVETYPE_BOUNCE;
    PROJECTILE_MAKETRIGGER(e);
    e.projectiledeathtype = WEP_FLAK | HITTYPE_SECONDARY;
    setsize(e, '0 0 -3', '0 0 -3');
    setorigin(e, w_shotorg);

    e.nextthink = time + CVAR(g_balance_flak_secondary_bomb_lifetime);
    e.think = adaptor_think2use;
    e.use = W_Flak_Bomb_Explode;
    e.touch = W_Flak_Bomb_Touch;
    e.takedamage = DAMAGE_YES;
    e.health = CVAR(g_balance_flak_secondary_bomb_health);
    e.damageforcescale = CVAR(g_balance_flak_secondary_bomb_damageforcescale);
    e.event_damage = W_Flak_Bomb_Damage;
    e.velocity = w_shotdir * CVAR(g_balance_flak_secondary_bomb_speed) + v_up * CVAR(g_balance_flak_secondary_bomb_speed_up);
    W_SetupProjectileVelocity(e);

    e.angles = vectoangles(e.velocity);
    e.flags = FL_PROJECTILE;

    CSQCProjectile(e, TRUE, PROJECTILE_FLAK_BOMB, TRUE);
}

void W_Flak_SetClipContext(void) {
    W_Clip_SetWeaponContext(
        WEP_FLAK,
        CVAR(g_balance_flak_magazinecapacity),
        CVAR(g_balance_flak_magazineregen),
        CVAR(g_balance_flak_reloadtime),
        ammo_shells,
        1
    );
}

void spawnfunc_weapon_flak(void) {
    weapon_defaultspawnfunc(WEP_FLAK);
}

void W_Flak_Charge(float isprim) {
    W_SetButtonFields(self, CVAR(g_balance_flak_swapshotmodes));

    var held = self.(if(isprim) w_button_primary else w_button_secondary);
    var smod = 1 - (self.w_inring_fulltime - time) / self.w_inring_cycle;

    self.w_spread_indicator = fabs(
        WEP_CVAR_BOTH(flak, isprim, charge_spreadmod_side) * smod + WEP_CVAR_BOTH(flak, isprim, spread_side)
    );

    Akimbo_SyncSpreadIndicator(self);

    if(held && time < self.w_inring_fulltime)
        return;

    W_Flak_Attack(isprim, smod);
    weapon_thinkf(WFRAME_FIRE2 - isprim, WEP_CVAR_BOTH(flak, isprim, animtime), w_ready);

    self.w_spread_indicator = -1;
    self.w_inring_fulltime = -1;

    Akimbo_SyncSpreadIndicator(self);
}

float w_flak(float req) {
    W_SetButtonFields(self, CVAR(g_balance_flak_swapshotmodes));
    W_Flak_SetClipContext();

    if(req == WR_AIM) {
        if(random() < 0.35 && CVAR(g_balance_flak_secondary_bomb) && self.ammo_rockets >= CVAR(g_balance_flak_secondary_ammo_rockets))
            self.w_button_secondary = bot_aim(CVAR(g_balance_flak_secondary_bomb_speed), CVAR(g_balance_flak_secondary_bomb_speed_up), CVAR(g_balance_flak_secondary_bomb_lifetime), TRUE);
        else
            self.w_button_primary = bot_aim(CVAR(g_balance_flak_primary_speed), CVAR(g_balance_flak_primary_speed_up), CVAR(g_balance_flak_primary_lifetime), TRUE);
    } else if(req == WR_THINK) {
        if(W_Clip_TryWeaponAction()) {
            if(self.w_button_primary)
            if(weapon_prepareattack(0, CVAR(g_balance_flak_primary_refire)))
            if(W_Clip_TryAttackOrReload()) {
                if(WEP_CVAR_PRI(flak, charge)) {
                    weapon_thinkf(WFRAME_FIRE1, 0, inline void(void) { W_Flak_Charge(TRUE); });
                    self.w_inring_cycle = WEP_CVAR_PRI(flak, charge) * W_WeaponRateFactor();
                    self.w_inring_fulltime = time + self.w_inring_cycle;
                } else {
                    W_Flak_Attack(TRUE, 0);
                    weapon_thinkf(WFRAME_FIRE1, WEP_CVAR_PRI(flak, animtime), w_ready);
                }
            }

            if(self.w_button_secondary)
            if(weapon_prepareattack(1, CVAR(g_balance_flak_secondary_refire)))
            if(W_Clip_TryAttackOrReload()) {
                if(CVAR(g_balance_flak_secondary_bomb)) {
                    W_Flak_Attack_Bomb();
                    weapon_thinkf(WFRAME_FIRE2, WEP_CVAR_SEC(flak, animtime), w_ready);
                } else if(WEP_CVAR_SEC(flak, charge)) {
                    weapon_thinkf(WFRAME_FIRE2, 0, inline void(void) { W_Flak_Charge(FALSE); });
                    self.w_inring_cycle = WEP_CVAR_SEC(flak, charge) * W_WeaponRateFactor();
                    self.w_inring_fulltime = time + self.w_inring_cycle;
                } else {
                    W_Flak_Attack(FALSE, 0);
                    weapon_thinkf(WFRAME_FIRE2, WEP_CVAR_SEC(flak, animtime), w_ready);
                }
            }

            W_Clip_FinishWeaponAction();
        }
    } else if(req == WR_PRECACHE) {
        precache_sound("weapons/flak_fire.wav");
        precache_sound("weapons/flak_fire2.wav");
        precache_sound("weapons/flak_fire3.wav");
        precache_sound("weapons/casings1.wav");
        precache_sound("weapons/casings2.wav");
        precache_sound("weapons/casings3.wav");
    } else if(req == WR_SETUP)
        weapon_setup(WEP_FLAK);
    else if(req == WR_CHECKAMMO1)
        return self.ammo_shells >= CVAR(g_balance_flak_primary_ammo);
    else if(req == WR_CHECKAMMO2)
        return self.ammo_shells >= CVAR(g_balance_flak_secondary_ammo) && self.ammo_rockets >= CVAR(g_balance_flak_secondary_ammo_rockets);

    W_Clip_WeaponRequestHook(req);
    return TRUE;
}
