#define PRYAXE_SKINS_COUNT 2

.float pryaxe_attackdone;
.float pryaxe_hit;
.float pryaxe_oldsolid;
.float pryaxe_count;
.float pryaxe_skin;

.entity pryaxe_thrown;

void spawnfunc_weapon_pryaxe(void) {
    weapon_defaultspawnfunc(WEP_PRYAXE);
}

void W_Pryaxe_Throw(float);
void W_Pryaxe_Melee(float);

void W_Pryaxe_SwitchWeapon(entity e, float w) {
    var g = Akimbo_Ghost(e);
    var o;

    if(g == e)
        g = world;

    if(g)
        o = g.switchweapon;

    W_SwitchWeapon_Force(e, w);

    if(g)
        g.switchweapon = o;
}

void W_Pryaxe_Melee_Damage(float isprim) {
    const boxsize = 32;
    var fract, targ, endpos, hitcreature;

    var damage = WEP_CVAR_BOTH(pryaxe, isprim, damage);
    var theforce = WEP_CVAR_BOTH(pryaxe, isprim, force);

    makevectors(self.v_angle);
    W_SetupShot(self, FALSE, 0, "", 0);
    W_Accuracy_RegisterShot(self, WEP_PRYAXE);

    var pts = Buffs_MEODP_Hitscan_Begin(self);

    traceline_antilag(self, w_shotorg - (w_shotdir * 20), w_shotorg + w_shotdir * WEP_CVAR_BOTH(pryaxe, isprim, range), MOVE_NORMAL, self);
    fract = trace_fraction;
    endpos = trace_endpos;

    while(TRUE) {
        tracebox_antilag(self, trace_endpos, '-1 -1 -1' * boxsize, '1 1 1' * boxsize, trace_endpos, MOVE_NORMAL, self, TRUE);

        if(!trace_ent)
            break;

        trace_ent.pryaxe_oldsolid = trace_ent.solid;
        trace_ent.solid = SOLID_NOT;
        trace_ent.pryaxe_hit = TRUE;
    }

    while((targ = findfloat(targ, pryaxe_hit, TRUE))) {
        targ.solid = targ.pryaxe_oldsolid;
        targ.pryaxe_oldsolid = 0;
        targ.pryaxe_hit = FALSE;

        if(targ.takedamage) {
            if(targ.iscreature)
                hitcreature = TRUE;

            W_Accuracy_RegisterHit(self, targ, WEP_PRYAXE);
            Damage(targ, self, self, damage,
                    WEP_PRYAXE | (if (isprim) 0 else HITTYPE_SECONDARY), endpos, w_shotdir * theforce);
        }
    }

    Buffs_MEODP_Hitscan_End(pts);

    if(!hitcreature && fract < 1)
        Damage_DamageInfo(endpos, damage, damage, 0, w_shotdir * theforce, WEP_PRYAXE, self);
}

void W_Pryaxe_Melee(float isprim) {
    if(!self.pryaxe_attackdone) {
        self.pryaxe_attackdone = TRUE;

        using(self = Akimbo_Owner(self))
            W_Pryaxe_Melee_Damage(isprim);
    }

    weapon_thinkf(WFRAME_DONTCHANGE, WEP_CVAR_BOTH(pryaxe, isprim, animtime), inline void(void) {
        self.pryaxe_attackdone = FALSE;
        weapon_thinkf(WFRAME_IDLE, frametime, w_ready);
    });
}

void W_Pryaxe_Attack(float isprim) {
    var throw = WEP_CVAR_BOTH(pryaxe, isprim, throw);

    if(throw) {
        if(throw & 2) {
            W_SetButtonFields(self, CVAR(g_balance_pryaxe_swapshotmodes));
            if(self.(if(isprim) w_button_primary else w_button_secondary)) {
                if(throw & 1)
                    W_Pryaxe_Melee(isprim);
                else
                    W_Pryaxe_Throw(isprim);
            } else {
                if(throw & 1)
                    W_Pryaxe_Throw(isprim);
                else
                    W_Pryaxe_Melee(isprim);
            }
        } else
            W_Pryaxe_Throw(isprim);
    } else {
        W_Pryaxe_Melee(isprim);
    }
}

void W_Pryaxe_Return() {
    if(clienttype(self.owner) != CLIENTTYPE_NOTACLIENT) {
        //Return pryaxe to owner
        self.enemy.pryaxe_thrown = world;

        if(self.owner.iscreature) {
            self.enemy.pryaxe_count = bound(0, self.enemy.pryaxe_count + 1, CVAR(g_balance_pryaxe_throw_count));
            if (!self.enemy.weapon)
                W_Pryaxe_SwitchWeapon(self.enemy, WEP_PRYAXE);
            sound(self.owner, CHAN_AUTO, "weapons/weaponpickup.wav", VOL_BASE, ATTN_NORM);
            if (self.enemy.weapon != WEP_PRYAXE)
                self.enemy.pryaxe_skin = self.skin;
        }
    }

    remove(self);
}

void W_Pryaxe_Flyback_Think() {
    var isprim = !(self.projectiledeathtype & HITTYPE_SECONDARY);
    vector owner_path = self.owner.origin - self.origin;

    if(time > self.cnt || vlen(owner_path) < 100) { //close enough
        W_Pryaxe_Return();
        return;
    }

    vector owner_dir = normalize(owner_path);
    self.velocity = WEP_CVAR_BOTH(pryaxe, isprim, throw_speed) * owner_dir;
    UpdateCSQCProjectile(self);
    self.nextthink = time;
}

void W_Pryaxe_Flyback() {
    self.movetype = MOVETYPE_NOCLIP;
    self.solid = SOLID_NOT;
    self.think = W_Pryaxe_Flyback_Think;
    self.nextthink = time;
    self.cnt = time + WEP_CVAR_BOTH(pryaxe, !(self.projectiledeathtype & HITTYPE_SECONDARY), throw_lifetime);
}

void W_Pryaxe_Touch() {
    var dir, isprim = !(self.projectiledeathtype & HITTYPE_SECONDARY);
    PROJECTILE_SKIPNONSOLID

    if(SUB_OwnerCheck()) {
        return;
    }

    if(SUB_NoImpactCheck()) {
        self.use();
        return;
    }

    if(trace_ent && trace_ent.solid > SOLID_TRIGGER)
         UpdateCSQCProjectileNextFrame(self);

    if (other.takedamage) {
        var hloc = NearestPointOnBox(other, trace_endpos);
        W_Accuracy_RegisterHit(self.owner, other, WEP_PRYAXE);

        if(WEP_CVAR_BOTH(pryaxe, isprim, throw_pull_to_owner))
            dir = self.owner.origin + self.owner.view_ofs - hloc;
        else
            dir = self.velocity;
        dir = normalize(dir);

        Damage(other, self.owner, self.owner, WEP_CVAR_BOTH(pryaxe, isprim, throw_damage),
               self.projectiledeathtype, hloc,
               dir * WEP_CVAR_BOTH(pryaxe, isprim, throw_force));

        if (other.classname == "player")
        if (IsDifferentTeam(self.owner, other))
        if (other.deadflag == DEAD_NO)
        if (IsFlying(other))
            CSQCMessage_Praise(self.owner, CSQCMSG_PRAISEFLAG_AIRSHOT);

    }

    if(!other.iscreature) {
        dir = normalize(self.velocity);
        traceline(trace_endpos, trace_endpos + dir * 24, MOVE_NORMAL, self);
        Damage_DamageInfo(trace_endpos, WEP_CVAR_BOTH(pryaxe, isprim, throw_damage), WEP_CVAR_BOTH(pryaxe, isprim, throw_damage), 0, dir * WEP_CVAR_BOTH(pryaxe, isprim, throw_force), WEP_PRYAXE, self);
    }

    self.use();
}

void W_Pryaxe_Switch_Hack() {
    if not(self.owner.weapon)
        W_Pryaxe_SwitchWeapon(self.owner, WEP_PRYAXE);
    remove(self);
}

void W_Pryaxe_Throw(float isprim) {
    entity proj = spawn();

    const pr_min = '-16 -16 -4';
    const pr_max = ' 16  16  4';

    var real_plr = Akimbo_Owner(self);

    W_SetupShot_ProjectileSize (self, pr_min, pr_max, FALSE, 4, "", 0);

    tracebox(w_shotorg, pr_min, pr_max, w_shotorg, MOVE_NOMONSTERS, real_plr);

    if(trace_startsolid) {
        W_Pryaxe_Melee(FALSE);
        return;
    }

    W_Accuracy_RegisterShot(real_plr, WEP_PRYAXE);
    proj.owner = real_plr;    // real player
    proj.enemy = self;        // real player or akimbo ghost
    proj.classname = "pryaxe";
    proj.movetype = MOVETYPE_FLY;
    PROJECTILE_MAKETRIGGER(proj);
    proj.projectiledeathtype = WEP_PRYAXE | (if(isprim) 0 else HITTYPE_SECONDARY) | HITTYPE_BOUNCE;
    proj.touch = W_Pryaxe_Touch;
    proj.velocity = WEP_CVAR_BOTH(pryaxe, isprim, throw_speed) * w_shotdir;
    proj.use = (if (WEP_CVAR_BOTH(pryaxe, isprim, throw_flyback)) W_Pryaxe_Flyback else W_Pryaxe_Return);
    proj.think = adaptor_think2use;
    proj.nextthink = time + WEP_CVAR_BOTH(pryaxe, isprim, throw_lifetime);
    proj.colormap = self.colormap;
    setsize(proj, pr_min, pr_max);
    setorigin(proj, w_shotorg);
    W_SetupProjectileVelocity(proj);
    proj.angles = vectoangles (proj.velocity);
    proj.flags = FL_PROJECTILE;
    proj.reset = W_Pryaxe_Return;
    proj.clipgroup = CLIPGROUP_PLAYERMASK(real_plr) | WEP_PRYAXE;

    if (self.weaponentity.weaponentity)
        proj.skin = self.weaponentity.weaponentity.skin;

    proj.csqcprojectile_extradata = proj.skin;
    CSQCProjectile(proj, TRUE, PROJECTILE_PRYAXE, TRUE);

    //Throw out pryaxe
    self.pryaxe_thrown = proj;
    self.pryaxe_count = bound(0, self.pryaxe_count - 1, CVAR(g_balance_pryaxe_throw_count));
    self.pryaxe_skin = mod(self.pryaxe_skin + 1, min(PRYAXE_SKINS_COUNT, CVAR(g_balance_pryaxe_throw_count)));
    self.weaponentity.state = WS_CLEAR;
    W_Pryaxe_SwitchWeapon(self, 0);
    weapon_thinkf(WFRAME_IDLE, 0, w_ready);
    ATTACK_FINISHED(self) = time;
    if (self.pryaxe_count > 0) {
        entity e = spawn();
        e.nextthink = time;
        e.owner = self;
        e.think = W_Pryaxe_Switch_Hack;
    }
}

void W_Pryaxe_Attack1(void) {
    W_Pryaxe_Attack(TRUE);
}

void W_Pryaxe_Attack2(void) {
    W_Pryaxe_Attack(FALSE);
}

void W_Pryaxe_Attack_Sound(void) {
    sound(Akimbo_Owner(self), CHAN_WEAPON, "weapons/swing.wav", VOL_BASE, ATTN_NORM);
}

float W_Pryaxe_CheckThrown() {
    if(self.pryaxe_thrown.classname == "pryaxe" && self.pryaxe_thrown.enemy == self && self.pryaxe_count <= 0) {
        return TRUE;
    }

    self.pryaxe_thrown = world;
    return FALSE;
}

void W_Pryaxe_DoAttack1(void) {
    W_Pryaxe_Attack_Sound();
    weapon_thinkf(WFRAME_FIRE1, WEP_CVAR_PRI(pryaxe, delay), W_Pryaxe_Attack1);
}

void W_Pryaxe_DoAttack2(void) {
    W_Pryaxe_Attack_Sound();
    weapon_thinkf(WFRAME_FIRE1, WEP_CVAR_SEC(pryaxe, delay), W_Pryaxe_Attack2);
}

float w_pryaxe(float req) {
    W_SetButtonFields(self, CVAR(g_balance_pryaxe_swapshotmodes));

    if(req == WR_AIM) {
        self.w_button_primary = bot_aim(100000, 0, 0.01, FALSE);
    } else if(req == WR_THINK) {
        if (self.weaponentity.weaponentity)
            self.weaponentity.weaponentity.skin = self.weaponentity.skin = self.pryaxe_skin;
        if (self.exteriorweaponentity)
            self.exteriorweaponentity.skin = self.pryaxe_skin;

        if(self.w_button_primary)
        if(weapon_prepareattack(0, CVAR(g_balance_pryaxe_primary_refire))) {
            if(Akimbo_Active(self) == 2) {
                defer(0.1, W_Pryaxe_DoAttack1);
            } else {
                W_Pryaxe_DoAttack1();
            }
        }

        if(self.w_button_secondary && CVAR(g_balance_pryaxe_secondary))
        if(weapon_prepareattack(0, CVAR(g_balance_pryaxe_secondary_refire))) {
            if(Akimbo_Active(self) == 2) {
                defer(0.1, W_Pryaxe_DoAttack2);
            } else {
                W_Pryaxe_DoAttack2();
            }
        }
    }
    else if(req == WR_PRECACHE) {
        precache_sound("weapons/swing.wav");
    } else if(req == WR_SETUP) {
        if(W_Pryaxe_CheckThrown()) {
            self.weaponentity.state = WS_CLEAR;
            W_Pryaxe_SwitchWeapon(self, 0);
            return FALSE;
        }

        weapon_setup(WEP_PRYAXE);
    } else if(req == WR_CHECKAMMO1)
        return !W_Pryaxe_CheckThrown();
    else if(req == WR_CHECKAMMO2)
        return !W_Pryaxe_CheckThrown();
    else if(req == WR_RESETPLAYER) {
        self.pryaxe_count = CVAR(g_balance_pryaxe_throw_count);
    }

    return TRUE;
}
