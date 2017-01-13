
.entity zapper_shield;
.entity zapper_accumulator;
.entity zapper_spinner;

.float zapper_range;
.float zapper_expire;
.float zapper_tracespeed;
.float zapper_lastdmg;
.float zapper_dmgdelay;
.float zapper_arc_hit;
.float zapper_heat;
.float zapper_coolofftime;
.float zapper_accumulate;
.float zapper_shieldready; // for g_balance_zapper_shield 2

.vector zapper_beam_start, zapper_beam_end;
.vector zapper_beam_real_start;

// TODO: maybe move this to common?
vector W_Zapper_BeamRGB(float t) {
    switch(t) {
        case COLOR_TEAM1:            return '5.0   1.0   0.5';
        case COLOR_TEAM2: default:   return '0.5   1.0   5.0';
        case COLOR_TEAM3:            return '4.0   2.5   0.5';
        case COLOR_TEAM4:            return '5.0   0.7   3.0';
    }
}

void W_Zapper_SpawnSpinner(void) {
    if(self.zapper_spinner)
        return;

    var o = Akimbo_Owner(self);

    var s = spawn() {
        classname: "zapper_spinner",
        model: "models/weapons/rtzapper_hyperhonker.iqm",
        owner: self,
        viewmodelforclient: o,
        colormap: self.colormap,
        color: W_Zapper_BeamRGB(if(teams_matter) self.team else COLOR_TEAM2),
        think: inline void(void) {
            if(self.owner.weapon != WEP_ZAPPER) {
                self.owner.zapper_spinner = world;
                remove(self);
                return;
            }

            if(self.owner.zapper_beam || self.owner.zapper_shield)
                self.cnt = approach(self.cnt, 3, 4 * frametime);
            else
                self.cnt = approach(self.cnt, -0.1, 2 * frametime);

            var intens = self.cnt / 3;

            if(intens <= 0) {
                self.glowmod = '-1 -1 -1';
                self.skin = 0;
            } else {
                self.skin = 1;
                self.glowmod = self.color * pow(intens, 2);
            }

            self.angles_z += frametime * self.cnt * 360;
            self.nextthink = time;
        },
        nextthink: time,
        customizeentityforclient: CL_Weaponentity_CustomizeEntityForClient
    };

    setattachment(s, self.weaponentity, "shot");

    if(!s.tag_index) {
        // Akimbo FIXME: why does this happen?
        s.tag_index = o.zapper_spinner.tag_index;
    }

    setorigin(s, '-4 0 -0.5');
    setmodel(s, s.model);

    self.zapper_spinner = s;
}

float W_Zapper_Attack1_CheckAmmo(entity p) {
    return p.ammo_cells >= CVAR(g_balance_zapper_primary_ammo);
}

float W_Zapper_Attack2_CheckAmmo(entity p) {
    if(CVAR(g_balance_zapper_secondary_shield))
        return p.ammo_cells >= 1;
    return p.ammo_cells >= CVAR(g_balance_zapper_secondary_ammo);
}

vector W_Zapper_LocalShotOrg(entity p) {
    entity o = self.owner;
    self.owner = p;
    vector v = shotorg_adjust('30 10 -18', TRUE, TRUE, Akimbo_Active(p));
    self.owner = o;
    return v;
}

float W_Zapper_Beam_Send(entity to, float sf) {
    sf &~= 8 | 16 | 32 | 128;

    if(self.sounds < 0)
        sf |= 16;

    float o = num_for_edict(self.owner);

    if(o > maxclients)
        o = 0;

    if(o) {
        if(self.owner != self.enemy) // akimbo secondary
            sf |= 128; // invert shotorg y
    } else {
        sf |= 32;
    }

    if(self.classname == "zapper_shield_beam")
        WriteByte(MSG_ENTITY, ENT_CLIENT_ZAPPER_SHIELD);
    else
        WriteByte(MSG_ENTITY, ENT_CLIENT_ZAPPER);

    WriteByte(MSG_ENTITY, sf);

    if(sf & 1) {
        if(o)
            WriteByte(MSG_ENTITY, o);
        else
            WriteByte(MSG_ENTITY, self.team);
    }

    if(sf & 2) {
        WriteCoord(MSG_ENTITY, self.zapper_beam_start_x);
        WriteCoord(MSG_ENTITY, self.zapper_beam_start_y);
        WriteCoord(MSG_ENTITY, self.zapper_beam_start_z);

        if(o) {
            WriteCoord(MSG_ENTITY, self.zapper_beam_real_start_x);
            WriteCoord(MSG_ENTITY, self.zapper_beam_real_start_y);
            WriteCoord(MSG_ENTITY, self.zapper_beam_real_start_z);
        }
    }

    if(sf & 4) {
        WriteCoord(MSG_ENTITY, self.zapper_beam_end_x);
        WriteCoord(MSG_ENTITY, self.zapper_beam_end_y);
        WriteCoord(MSG_ENTITY, self.zapper_beam_end_z);
    }

    return TRUE;
}

float W_Zapper_Beam_Expired(float secondary) {
    var o = Akimbo_Owner(self.owner);

    W_SetButtonFields(o, CVAR(g_balance_zapper_swapshotmodes));

    if(time > self.zapper_expire && ((secondary && !o.w_button_secondary) || (!secondary && !o.w_button_primary)))
        return TRUE;

    if(self.owner.zapper_heat >= 1)
        return TRUE;

    if(o.weapon != WEP_ZAPPER)
        return TRUE;

    if(!PlayerMayFire(o))
        return TRUE;

    if(secondary) {
        if(o.ammo_cells < 1)
            return TRUE;
    } else {
        if(!W_Zapper_Attack1_CheckAmmo(o))
            return TRUE;
        if(o.zapper_shield)
            return TRUE;
    }

    return FALSE;
}

void W_Zapper_Beam_Think(void) {
    if(W_Zapper_Beam_Expired(FALSE)) {
        if(self.enemy.zapper_beam == self)
            self.enemy.zapper_beam = world;
        remove(self);
        return;
    }

    makevectors(self.owner.v_angle);
    W_SetupShot(self.enemy, FALSE, 0, "", -1);

    float fract;
    entity targ;
    vector end = w_shotorg + w_shotdir * self.zapper_range;
    entity o = self.owner;

    if(self.zapper_tracespeed) {
        if(!self.origin)
            self.origin = end;
        else
            self.origin += (end - self.origin) * frametime * self.zapper_tracespeed;

        end = self.origin;
    }

    ExactHitscan_Begin();
    traceline_antilag(o, w_shotorg, end, FALSE, o);
    ExactHitscan_End();

    targ = trace_ent;
    end = trace_endpos;
    fract = trace_fraction;

    float dt = time - self.zapper_lastdmg;
    float rate = W_WeaponRateFactorFor(self.owner);
    float damageIsDps = FALSE;
    
    if(dt < frametime)
    if(almost_equals(dt, frametime))
        dt = frametime;
    
    float wantedTicrate = self.zapper_dmgdelay * rate;
    
    if(wantedTicrate <= 0) {
        wantedTicrate = dt;
        damageIsDps = TRUE;
    } else if(almost_equals(dt, wantedTicrate)) {
        dt = wantedTicrate;
    }
    
    for ( ;dt >= wantedTicrate; dt -= wantedTicrate) {
        float damage = CVAR(g_balance_zapper_primary_damage);
        float force  = CVAR(g_balance_zapper_primary_force);
        
        if(damageIsDps) {
            damage = damage * wantedTicrate;
            force = force * wantedTicrate;
        }
        
        W_Accuracy_RegisterShot(o, o.weapon);
        W_Accuracy_RegisterHit(o, targ, o.weapon);

        if(targ.takedamage) {
            float d = vlen(end - w_shotorg) * fract;

            float mindist = CVAR(g_balance_zapper_primary_damagefalloff_mindist);
            float maxdist = CVAR(g_balance_zapper_primary_damagefalloff_maxdist);
            float halflifedist = CVAR(g_balance_zapper_primary_damagefalloff_halflife);
            float forcehalflifedist = CVAR(g_balance_zapper_primary_damagefalloff_forcehalflife);

            damage *= ExponentialFalloff(mindist, maxdist, halflifedist, d);
            force  *= ExponentialFalloff(mindist, maxdist, forcehalflifedist, d);

            Damage(targ, self, self.owner, damage, WEP_ZAPPER, end, force * WarpZone_trace_dir);
        }

        if(fract < 1)
        if(targ.solid == SOLID_BSP && !(trace_dphitq3surfaceflags & Q3SURFACEFLAG_NOIMPACT))
            Damage_DamageInfo(end, damage, 0, 0, force * WarpZone_trace_dir, WEP_ZAPPER, self);

        if(!(o.items & IT_UNLIMITED_AMMO))
            o.ammo_cells -= CVAR(g_balance_zapper_primary_ammo);

        self.zapper_lastdmg += wantedTicrate;
    }

    vector org = gettaginfo(self.enemy.exteriorweaponentity, gettagindex(self.enemy.exteriorweaponentity, "_"));

    if(org)
        org = org + v_forward * self.enemy.exteriorweaponentity.maxs_x * 0.66 + v_up * self.enemy.exteriorweaponentity.maxs_z * 0.4;
    else
        org = w_shotorg;

    if(org != self.zapper_beam_start) {
        self.SendFlags |= 2;
        self.zapper_beam_start = org;
        self.zapper_beam_real_start = w_shotorg;
    }

    vector nowarp_end = WarpZone_UnTransformOrigin(WarpZone_trace_transform, end);
    if(nowarp_end != self.zapper_beam_end) {
        self.SendFlags |= 4;
        self.zapper_beam_end = nowarp_end;
    }

    if(self.enemy.zapper_heat >= 0) {
        self.enemy.zapper_heat = bound(0, self.enemy.zapper_heat + (CVAR(g_balance_zapper_primary_heatup) * frametime) / rate, 1);
        self.enemy.zapper_coolofftime = time + frametime;
    }

    if(self.enemy.weapon)
        ATTACK_FINISHED(self.enemy) = time + CVAR(g_balance_zapper_primary_refire) * rate;

    self.nextthink = time;
}

void W_Zapper_Attack1(void) {
    if(!W_Zapper_Attack1_CheckAmmo(self))
        return;

    sound(self, CHAN_WEAPON, "weapons/zapper_fire.wav", VOL_BASE, ATTN_NORM);

    var e = spawn();
    e.classname = "zapper_beam";
    e.think = W_Zapper_Beam_Think;
    e.owner = Akimbo_Owner(self);
    e.enemy = self;

    e.zapper_tracespeed = CVAR(g_balance_zapper_primary_tracespeed);
    e.zapper_range = CVAR(g_balance_zapper_primary_range);
    e.zapper_expire = time + CVAR(g_balance_zapper_primary_lifetime);
    e.zapper_dmgdelay = CVAR(g_balance_zapper_primary_ticrate);
    e.zapper_lastdmg = time - e.zapper_dmgdelay * W_WeaponRateFactorFor(self);
    
    Net_LinkEntity(e, FALSE, 0, W_Zapper_Beam_Send);

    using(self = e)
        self.think();

    self.zapper_beam = e;
}

void W_Zapper_Attack2_Effect(float ateam, vector from, vector from_real, vector to) {
    WriteByte(MSG_BROADCAST, SVC_TEMPENTITY);
    WriteByte(MSG_BROADCAST, TE_CSQC_ZAPPERLIGHTNING);
    
    WriteByte(MSG_BROADCAST, ateam-1);
    WriteCoord(MSG_BROADCAST, from_x);
    WriteCoord(MSG_BROADCAST, from_y);
    WriteCoord(MSG_BROADCAST, from_z);
    WriteCoord(MSG_BROADCAST, from_real_x);
    WriteCoord(MSG_BROADCAST, from_real_y);
    WriteCoord(MSG_BROADCAST, from_real_z);
    WriteCoord(MSG_BROADCAST, to_x);
    WriteCoord(MSG_BROADCAST, to_y);
    WriteCoord(MSG_BROADCAST, to_z);
}

void W_Zapper_Attack2_Arc(entity targ, entity attacker, float damage) {
    float arc = CVAR(g_balance_zapper_secondary_arc);

    if(arc <= 0)
        return;

    ArcDamage(targ, attacker, damage, WEP_ZAPPER | HITTYPE_SECONDARY | HITTYPE_BOUNCE,
        CVAR(g_balance_zapper_secondary_arc_range), arc,
        CVAR(g_balance_zapper_secondary_arc_force), COLOR_TEAM2, zapper_arc_hit
    );
}

void W_Zapper_Attack2(void) {
    float accum_time = CVAR(g_balance_zapper_secondary_accumulate);
    float charge_time;
    if (accum_time) {
        charge_time = CVAR(g_balance_zapper_secondary_charge_time);
        if (!charge_time)
            charge_time = accum_time;
    }

    float accum  = if(accum_time) min(1, (time - self.zapper_accumulate) * W_WeaponRateFactorFor(self.owner) / charge_time) else 1;
    float damage = CVAR(g_balance_zapper_secondary_damage) * accum;
    float force  = CVAR(g_balance_zapper_secondary_force) * accum;
    float range  = CVAR(g_balance_zapper_secondary_range) * accum;

    makevectors(self.v_angle);
    W_SetupShot(self, TRUE, 5, strcat("misc/arc", ftos(1 + (random() > 0.5)), ".wav"), damage);
    
    entity targ;
    vector end = w_shotorg + w_shotdir * range;
    entity pts = Buffs_MEODP_Hitscan_Begin(self);

    ExactHitscan_Begin();
    traceline_antilag(self, w_shotorg, end, FALSE, self);
    ExactHitscan_End();

    targ = trace_ent;
    end = trace_endpos;

    W_SetHitscanVisuals(self, end);

    vector end_visual = WarpZone_UnTransformOrigin(WarpZone_trace_transform, trace_endpos);

    if(targ.takedamage) {
        float d = vlen(end - w_shotorg) * trace_fraction;

        float mindist = CVAR(g_balance_zapper_secondary_damagefalloff_mindist);
        float maxdist = CVAR(g_balance_zapper_secondary_damagefalloff_maxdist);
        float halflifedist = CVAR(g_balance_zapper_secondary_damagefalloff_halflife);
        float forcehalflifedist = CVAR(g_balance_zapper_secondary_damagefalloff_forcehalflife);

        damage *= ExponentialFalloff(mindist, maxdist, halflifedist, d);
        force  *= ExponentialFalloff(mindist, maxdist, forcehalflifedist, d);

        if(targ.iscreature)
            W_Zapper_Attack2_Arc(targ, self, damage);

        Damage(targ, self, self, damage, WEP_ZAPPER | HITTYPE_SECONDARY, end, force * WarpZone_trace_dir);
    }

    Buffs_MEODP_Hitscan_End(pts);

    W_Accuracy_RegisterShot(self, self.weapon);
    W_Accuracy_RegisterHit(self, targ, self.weapon);

    W_Zapper_Attack2_Effect(self.team, w_shotorg_visual, w_shotorg, end_visual);

    if(targ.solid == SOLID_BSP && !(trace_dphitq3surfaceflags & Q3SURFACEFLAG_NOIMPACT))
        Damage_DamageInfo(end, damage, 0, 0, force * WarpZone_trace_dir, WEP_ZAPPER | HITTYPE_SECONDARY, self);

    if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
        self.ammo_cells = self.ammo_cells - CVAR(g_balance_zapper_secondary_ammo);
}

void W_Zapper_Shield_Beam_Think(void) {
    makevectors(self.owner.angles);
    W_SetupShot(self.owner, FALSE, 0, "", -1);

    vector end = w_shotorg + w_shotdir * 7;
    entity o = self.owner;

    traceline(w_shotorg, end, FALSE, o);

    end = trace_endpos;

    vector org = gettaginfo(self.owner.exteriorweaponentity, gettagindex(self.owner.exteriorweaponentity, "_"));

    if(org)
        org = org + v_forward * self.owner.exteriorweaponentity.maxs_x * 0.66 + v_up * self.owner.exteriorweaponentity.maxs_z * 0.4;
    else
        org = w_shotorg;

    if(org != self.zapper_beam_start) {
        self.SendFlags |= 2;
        self.zapper_beam_start = org;
    }

    if(end != self.zapper_beam_end) {
        self.SendFlags |= 4;
        self.zapper_beam_end = end;
    }

    self.nextthink = time;
}

void W_Zapper_Shield_Think(void) {
    float expired;

    // self == self.enemy --> This is the 'original' viewmodel entity
    // self != self.enemy --> This is the exterior entity attached to the weapon model, self.enemy points to original

    using(self = self.enemy)
        expired = W_Zapper_Beam_Expired(TRUE);

    if(expired) {
        self.alpha = approach(self.alpha, 0, frametime * 20);
    } else {
        self.alpha = approach(self.alpha, 1, frametime * 10);

        if(self == self.enemy) {
            if(!(self.owner.items & IT_UNLIMITED_AMMO))
                self.owner.ammo_cells = max(0, self.owner.ammo_cells - frametime * CVAR(g_balance_zapper_secondary_shield_ammo));

            if(self.owner.zapper_heat >= 0) {
                self.owner.zapper_heat = bound(0, self.owner.zapper_heat + (CVAR(g_balance_zapper_secondary_shield_heatup) * frametime), 1);
                self.owner.zapper_coolofftime = time + frametime;
            }

            ATTACK_FINISHED(self.owner) = self.owner.zapper_shieldready = time + CVAR(g_balance_zapper_secondary_shield_refire) * W_WeaponRateFactorFor(self.owner);
        }
    }

    if(!self.alpha) {
        if(self.owner.zapper_shield == self)
            self.owner.zapper_shield = world;

        if(self == self.enemy && self.zapper_beam) {
            remove(self.zapper_beam);
            self.zapper_beam = world;
        }

        remove(self);
        return;
    }

    self.nextthink = time;
}

void W_Zapper_Shield_Blocker_Push(entity p) {
    if(normalize(p.origin - self.oldorigin) * v_forward < 0.5)
        return;

    if(vlen(p.origin - self.oldorigin) <= 90) {
        float v = max(600, vlen(p.velocity));
        p.velocity = normalize(p.origin - self.oldorigin) * v;
        UpdateCSQCProjectile(p);
    }
}

.entity zapper_shield_warp_shadow;
.entity zapper_shield_warp_shadow_visual;

void W_Zapper_Shield_Blocker_Think(void) {
    if(self.owner.zapper_shield != self.zapper_shield) {
        if (self.zapper_shield_warp_shadow && self.zapper_shield_warp_shadow == self) {
            remove(self.zapper_shield_warp_shadow_visual);
        }
        remove(self);
        return;
    }

    entity e, warp;
    vector o = self.owner.origin + self.owner.view_ofs;
    vector a = self.owner.angles;
    self.oldorigin = o;

    if (self.zapper_shield_warp_shadow == self) {
        o = WarpZone_TransformOrigin(self, o);
        a = WarpZone_TransformAngles(self, a);
    } else {
        if ((warp = WarpZone_Find(self.origin - '200 200 200', self.origin + '200 200 200'))) {
            if (!self.zapper_shield_warp_shadow) {
                e = spawn();
                e.classname = "zapper_shield_blocker";
                e.owner = self.owner;
                e.think = W_Zapper_Shield_Blocker_Think;
                e.zapper_shield = self.zapper_shield;
                e.nextthink = time;
                e.solid = SOLID_BSP;
                e.alpha = -1;
                self.zapper_shield_warp_shadow = e;
                e.zapper_shield_warp_shadow = e;
                setmodel(e, "models/vhshield.md3");
                e = spawn();
                e.classname = "zapper_shield";
                setmodel(e, "models/vhshield.md3");
                e.enemy = e;
                e.alpha = self.owner.zapper_shield.alpha;
                if(teams_matter)
                    e.skin = TeamColorSkin(self.team);
                if(!e.skin)
                    e.skin = TeamColorSkin(COLOR_TEAM2);
                self.zapper_shield_warp_shadow.zapper_shield_warp_shadow_visual = e;
            }
            self.zapper_shield_warp_shadow.warpzone_transform = warp.warpzone_transform;
            self.zapper_shield_warp_shadow.warpzone_shift = warp.warpzone_shift;
        } else {
            if (self.zapper_shield_warp_shadow) {
                remove(self.zapper_shield_warp_shadow.zapper_shield_warp_shadow_visual);
                remove(self.zapper_shield_warp_shadow);
                self.zapper_shield_warp_shadow = world;
            }
        }
    }

    makevectors(a);
    self.angles = a;
    setorigin(self, o - v_forward * 85);
    if (self.zapper_shield_warp_shadow_visual) {
        self.zapper_shield_warp_shadow_visual.alpha = self.owner.zapper_shield.alpha;
        o = gettaginfo(self.owner.exteriorweaponentity, gettagindex(self.owner.exteriorweaponentity, "shot"));
        o = o - (88 * v_forward) + (5 * v_up);
        vector v_forward_save = v_forward;
        o = WarpZone_TransformOrigin(self, o);
        v_forward = v_forward_save;
        self.zapper_shield_warp_shadow_visual.angles = WarpZone_TransformAngles(self, vectoangles(v_forward));
        self.zapper_shield_warp_shadow_visual.angles_z = self.owner.zapper_shield.angles_z;
        setorigin(self.zapper_shield_warp_shadow_visual, o);
    }

    FOR_EACH_PLAYER(e) if(e != self.owner)
        W_Zapper_Shield_Blocker_Push(e);

    for(e = findchainflags(flags, FL_PROJECTILE); e; e = e.chain)
        if(e.classname != "bullet")
            W_Zapper_Shield_Blocker_Push(e);

    self.nextthink = time;
}

void W_Zapper_FixShieldBlockerOrigin(entity plr) {
    if(!plr.zapper_shield.zapper_shield)
        return;

    vector fwd = v_forward, up = v_up, right = v_right;

    makevectors(plr.angles);
    plr.zapper_shield.zapper_shield.angles = plr.angles;
    setorigin(plr.zapper_shield.zapper_shield, plr.origin + plr.view_ofs - v_forward * 85);

    v_forward = fwd;
    v_up = up;
    v_right = right;
}

void W_Zapper_Attack3(void) {
    entity e = spawn();
    e.classname = "zapper_shield";
    setmodel(e, "models/vhshield.md3");
    e.enemy = e;
    e.think = W_Zapper_Shield_Think;
    e.nextthink = time;
    e.alpha = 0.01;

    if(teams_matter)
        e.skin = TeamColorSkin(self.team);
    if(!e.skin)
        e.skin = TeamColorSkin(COLOR_TEAM2);

    // This copies the entity! e becomes a viewmodel, the copy is attached to shotorg.
    W_AttachToShotorg(e, '-120 0 0');

    // needs to be done AFTER W_AttachToShotorg
    e.customizeentityforclient = inline float(void) {
        if(self.owner != self.owner.clientcamera)
            return FALSE;

        self.viewmodelforclient = self.owner;
        if(other.clientcamera == self.owner)
            self.viewmodelforclient = other;

        return self.alpha > 0;
    };

    self.zapper_shield = e;

    sound(self, CHAN_WEAPON, "weapons/zapper_fire.wav", VOL_BASE, ATTN_NORM);

    entity b = spawn();
    b.classname = "zapper_shield_beam";
    b.think = W_Zapper_Shield_Beam_Think;
    b.nextthink = time;
    b.owner = Akimbo_Owner(self);

    Net_LinkEntity(b, FALSE, 0, W_Zapper_Beam_Send);

    e.zapper_beam = b;

    b = spawn();
    b.classname = "zapper_shield_blocker";
    b.owner = Akimbo_Owner(self);
    b.think = W_Zapper_Shield_Blocker_Think;
    b.zapper_shield = e;
    b.nextthink = time;
    b.solid = SOLID_BSP;
    b.alpha = -1;
    setmodel(b, "models/vhshield.md3");

    e.zapper_shield = b;
}

void W_Zapper_Cooloff(void) {
    if(self.zapper_heat < 0)
        return;

    float a = bound(0, (time - self.zapper_coolofftime) * CVAR(g_balance_zapper_primary_cooloff_accel), Buffs_ClipLimitMultiplier(self));

    if(!a)
        return;

    self.zapper_heat = bound(0, self.zapper_heat - CVAR(g_balance_zapper_primary_cooloff) * frametime * a, 1);

    if(Akimbo_Active(self) == 1)
        using(self = Akimbo_Ghost(self))
            W_Zapper_Cooloff();
}

float W_Zapper_PrepareFirstAttack(float sec) {
    if(self.weaponentity.state == WS_INUSE)
        self.weaponentity.state = WS_READY;

    return weapon_prepareattack(sec, 0);
}

void W_Zapper_Accumulate(void) {
    W_SetButtonFields(self.owner, CVAR(g_balance_zapper_swapshotmodes));

    setorigin(self, self.owner.origin);
    self.nextthink = time;
    self = self.owner;
    float accumulate_end = 1;
    if (PlayerMayFire(self) && self.weapon == WEP_ZAPPER) {
        if (self.zapper_accumulator.zapper_expire < time &&
               (!self.w_button_secondary
               || self.w_button_primary
               || time > self.zapper_accumulator.zapper_accumulate)) {
            W_Zapper_Attack2();
            weapon_thinkf(WFRAME_FIRE2, CVAR(g_balance_zapper_animtime), w_ready);
        } else
            accumulate_end = 0;
    }
    if (accumulate_end) {
        stopsound(self, CHAN_WEAPON2);
        remove(self.zapper_accumulator);
        self.zapper_accumulator = world;
    }
}

float w_zapper(float req) {
    W_SetButtonFields(self, CVAR(g_balance_zapper_swapshotmodes));
    float dofire;

    if (req == WR_AIM) {
        if(vlen(self.origin-self.enemy.origin) < CVAR(g_balance_zapper_primary_range))
            self.w_button_primary = bot_aim(1000000, 0, 0.001, FALSE);
        else
            self.w_button_secondary = bot_aim(1000000, 0, 0.001, FALSE);
    } else if(req == WR_THINK) {
        W_Zapper_SpawnSpinner();

        if(self.w_button_primary) {
            if (self.w_button_secondary && CVAR(g_balance_zapper_secondary_shield == 2)) {
                if(weapon_prepareattack(1, -1)) {
                    if(self.zapper_heat >= 1 && CVAR(g_balance_zapper_secondary_shield_heatup)) {
                        W_SwitchWeapon_OutOfAmmo(self);
                    } else {
                        if(self.zapper_shield) {
                            dofire = TRUE;
                            self.zapper_shield.zapper_expire = time + CVAR(g_balance_zapper_secondary_shield_lifetime);
                        } else if(time > self.zapper_shieldready) {
                            dofire = TRUE;
                            W_Zapper_Attack3();
                        }

                        if(dofire)
                            weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_zapper_animtime), w_ready);
                    }
                }
           } else if(weapon_prepareattack(0, -1)) {
                if(self.zapper_heat >= 1 && CVAR(g_balance_zapper_primary_heatup)) {
                    W_SwitchWeapon_OutOfAmmo(self);
                } else {
                    if(self.zapper_beam) {
                        dofire = TRUE;
                        self.zapper_beam.zapper_expire = time + CVAR(g_balance_zapper_primary_lifetime);
                    } else if(W_Zapper_PrepareFirstAttack(0)) {
                        dofire = TRUE;
                        W_Zapper_Attack1();
                    }

                    if(dofire)
                        weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_zapper_animtime), w_ready);
                }
            }
        } else if(self.w_button_secondary && CVAR(g_balance_zapper_secondary)) {
            if(CVAR(g_balance_zapper_secondary_shield == 1)) {
                if(weapon_prepareattack(1, -1)) {
                    if(self.zapper_heat >= 1 && CVAR(g_balance_zapper_secondary_shield_heatup)) {
                        W_SwitchWeapon_OutOfAmmo(self);
                    } else {
                        if(self.zapper_shield) {
                            dofire = TRUE;
                            self.zapper_shield.zapper_expire = time + CVAR(g_balance_zapper_secondary_shield_lifetime);
                        } else if(W_Zapper_PrepareFirstAttack(0)) {
                            dofire = TRUE;
                            W_Zapper_Attack3();
                        }

                        if(dofire)
                            weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_zapper_animtime), w_ready);
                    }
                }
            } else if(CVAR(g_balance_zapper_secondary_accumulate)) {
                if (!self.zapper_accumulator && weapon_prepareattack(1, CVAR(g_balance_zapper_secondary_refire))) {
                    self.zapper_accumulate = time; //Accumulate start time
                    self.zapper_accumulator = spawn();
                    self.zapper_accumulator.zapper_accumulate = time + CVAR(g_balance_zapper_secondary_accumulate); //Accumulate end time
                    self.zapper_accumulator.owner = self;
                    self.zapper_accumulator.think = W_Zapper_Accumulate;
                    self.zapper_accumulator.nextthink = time;
                    self.zapper_accumulator.zapper_expire = time + CVAR(g_balance_zapper_animtime);
                    sound(self, CHAN_WEAPON2, "weapons/fireball_fly2.wav", VOL_BASE, ATTN_NORM);
                    weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_zapper_animtime), w_ready);
                }
            } else if(weapon_prepareattack(1, CVAR(g_balance_zapper_secondary_refire))) {
                W_Zapper_Attack2();
                weapon_thinkf(WFRAME_FIRE1, CVAR(g_balance_zapper_animtime), w_ready);
            }
        }
    } else if(req == WR_PRECACHE) {
        precache_model("models/vhshield.md3");
        precache_model("models/weapons/rtzapper_hyperhonker.iqm");
        precache_sound("weapons/zapper_fire.wav");
        precache_sound("weapons/zapper_fly.wav");
        precache_sound("weapons/fireball_fly2.wav");
        precache_sound("misc/arc1.wav");
        precache_sound("misc/arc2.wav");
    } else if(req == WR_RESETPLAYER){
        if(CVAR(g_balance_zapper_primary_heatup) || (CVAR(g_balance_zapper_secondary_shield) && CVAR(g_balance_zapper_secondary_shield_heatup)))
            self.zapper_heat = 0;
        else
            self.zapper_heat = -1;
    } else if(req == WR_SETUP) {
        weapon_setup(WEP_ZAPPER);
    } else if(req == WR_CLEAR) {
        if(self.zapper_spinner) {
            remove(self.zapper_spinner);
            self.zapper_spinner = world;
        }

        if(self.zapper_beam) {
            remove(self.zapper_beam);
            self.zapper_beam = world;
        }
    } else if(req == WR_CHECKAMMO1)
        return W_Zapper_Attack1_CheckAmmo(self);
    else if(req == WR_CHECKAMMO2)
        return W_Zapper_Attack2_CheckAmmo(self);
    return TRUE;
};

void spawnfunc_weapon_zapper(void) {
    weapon_defaultspawnfunc(WEP_ZAPPER);
}
