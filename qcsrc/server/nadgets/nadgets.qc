
// Nadgets mutator
// Intended for the Camping Rifle Arena mode

void HG_Init(void) {
    g_nadgets_double = CVAR(g_nadgets_double);

    addstat(STAT_HGFORCE, AS_FLOAT, hg_power);
    addstat(STAT_HGAMMO, AS_INT, hg_ammo1);
    addstat(STAT_HGREGEN, AS_FLOAT, hg_regentime1);
    addstat(STAT_HGREGENMAX, AS_FLOAT, hg_maxregentime1);
    addstat(STAT_HGREGENPAUSED, AS_INT, hg_regenpaused1);
    addstat(STAT_HGREGENRATE, AS_FLOAT, hg_regenrate1);
    addstat(STAT_HGDETONABLES, AS_INT, hg_detonables);
    addstat(STAT_HGLAUNCH, AS_FLOAT, hg_launchspeed);
    addstat(STAT_HGTYPE, AS_INT, hg_type1);
    addstat(STAT_HGBONUS, AS_INT, hg_bonus);
    addstat(STAT_HGBONUSTYPE, AS_INT, hg_bonustype);
    addstat(STAT_HGREFIRE, AS_FLOAT, hg_next1);

    if(g_nadgets_double) {
        addstat(STAT_HGTYPE2, AS_INT, hg_type2);
        addstat(STAT_HGREFIRE2, AS_FLOAT, hg_next2);
        addstat(STAT_HGAMMO2, AS_INT, hg_ammo2);
        addstat(STAT_HGREGEN2, AS_FLOAT, hg_regentime2);
        addstat(STAT_HGREGENMAX2, AS_FLOAT, hg_maxregentime2);
        addstat(STAT_HGREGENPAUSED2, AS_INT, hg_regenpaused2);
        addstat(STAT_HGREGENRATE2, AS_FLOAT, hg_regenrate2);
    }

    g_nadgets_oldhitboxes = CVAR(g_nadgets_oldhitboxes);
    g_nadgets_detonatelaunches = CVAR(g_nadgets_detonatelaunches);

    #define HGDEF(id,shortname,longname,color) HG_Hook_Init_##shortname();
    HGDEFS
    #undef HGDEF
}

void HG_Precache(void) {
    precache_sound("hk/alarm.wav");
    precache_sound("weapons/grenade_bounce1.wav");
    precache_sound("weapons/grenade_bounce2.wav");
    precache_sound("weapons/grenade_bounce3.wav");
    precache_sound("weapons/grenade_bounce4.wav");
    precache_sound("weapons/grenade_bounce5.wav");
    precache_sound("weapons/grenade_bounce6.wav");
    precache_sound("weapons/grenade_fire.wav");
    precache_sound("weapons/grenade_stick.wav");
    precache_sound("weapons/rm_nadebeep.wav");
    precache_sound("weapons/electro_bounce.wav");
    precache_sound("weapons/rocket_mode.wav");
    precache_sound("weapons/nexfire.wav");
    precache_sound("weapons/electro_fire2.wav");
    precache_sound("porto/expire.wav");
    precache_sound("porto/bounce.wav");
    precache_sound("misc/powerup_shield.wav");
    precache_sound("misc/gg.wav");
    precache_sound("misc/stealth.wav");
    precache_sound("misc/unstealth.wav");
    precache_sound("kh/capture.wav");
    precache_sound(RM_SOUND_LASER_PRIMARY);
    precache_sound(RM_SOUND_LASER_SECONDARY);
    precache_model("models/ctf/shield.md3");
    precache_model("models/rtzsentry.iqm");
}

void HG_SetContext(float isalt) {
    hg_context_isaltintended = isalt;

    if(!g_nadgets_double)
        isalt = FALSE;

    if(isalt) {
        hg_ctx_next = hg_next2;
        hg_ctx_ammo = hg_ammo2;
        hg_ctx_type = hg_type2;
        hg_ctx_type_picked = hg_type2_picked;
        hg_ctx_type_picked_nextround = hg_type2_picked_nextround;
        hg_ctx_regentime = hg_regentime2;
        hg_ctx_maxregentime = hg_maxregentime2;
        hg_ctx_regenrate = hg_regenrate2;
        hg_ctx_regenpaused = hg_regenpaused2;
    } else {
        hg_ctx_next = hg_next1;
        hg_ctx_ammo = hg_ammo1;
        hg_ctx_type = hg_type1;
        hg_ctx_type_picked = hg_type1_picked;
        hg_ctx_type_picked_nextround = hg_type1_picked_nextround;
        hg_ctx_regentime = hg_regentime1;
        hg_ctx_maxregentime = hg_maxregentime1;
        hg_ctx_regenrate = hg_regenrate1;
        hg_ctx_regenpaused = hg_regenpaused1;
    }

    hg_context_isalt = isalt;
}

void HG_GiveBonus(entity p, float hgtype, float amount, string reason, float allowOptout) {
    if(!g_nadgets || (allowOptout && p.hg_optout))
        return;

    amount *= GRENVAR(hgtype, "bonus_amount_multiplier") * Buffs_NadgetBonusMultiplier(p);

    if(amount < 1)
        return;

    if(p.hg_bonustype != hgtype)
        p.hg_bonus = 0;

	p.hg_bonus += amount;
	p.hg_bonustype = hgtype;
    p.hg_bonus_next = 0;

	string n = HG_TypeToExpandedName(hgtype);
	entity e;

	FOR_EACH_REALCLIENT(e) if(e.iscreature || e.classname == "spectator") {
        entity check = e;
        if(!e.iscreature)
            check = e.enemy;

        if(check == p)
            bigprint(e, strcat("^7You got a ^3", n, "^7 bonus!"), reason, 3);
        else if(IsDifferentTeam(check, p))
            bigprint(e, strcat("^3Enemy got a ^1", n, " ^3bonus!"), strcat("Given to ^3", p.netname, " ^7(", reason, ")"), 3);
        else
            centerprint(e, strcat("^3", p.netname, "^7 got a ^3", n, " ^7bonus (", reason, ")"));
    }

	bprint(strcat("^3", p.netname, " ^7got a ^3", n, "^7 bonus (", reason, ")\n"));
    play2all("kh/alarm.wav");
}

void HG_GiveRandomBonus(entity p, float amount, string reason, float allowOptout) {
    if(!g_nadgets || (allowOptout && p.hg_optout))
        return;

    RandomSelection_Init();

    float n;
    for(n = HG_START; n <= HG_END; ++n) {
        if(g_freeze || (n != HG_BAIT)) {
            float w = GRENVAR(n, "bonus_random_weight");
            if(w)
                RandomSelection_Add(world, n, NULL, w, 1);
        }
    }

    if(RandomSelection_chosen_float)
        HG_GiveBonus(p, RandomSelection_chosen_float, amount, reason, allowOptout);
}

float HG_RegenTime(entity e) {
    float base      = GRENVAR(e.hg_ctx_type, "regen_time");
    float exponent  = GRENVAR(e.hg_ctx_type, "regen_exponent");
    float factor    = GRENVAR(e.hg_ctx_type, "regen_factor");

    return base * (1 + pow(e.hg_ctx_ammo, exponent) * factor);
}

void HG_SetRegenTime(entity e, float t) {
    e.hg_ctx_regentime = t;
    e.hg_ctx_maxregentime = t;
}

float HG_PlayerMayDetonate(entity p) {
    if(CVAR(g_nadgets_detonate_on_death))
        return TRUE;
    return (p.health >= 1) && !(g_freeze && p.frozen);
}

void HG_RemoveAll(entity plr) {
    entity n;

    if(!g_nadgets)
        return;

    for(n = world; (n = findfilter(n, inline float(entity e) {
        var c = e.classname;
        return (c == "hg_generic_projectile")  ||
               (c == "hg_plasma")   ||
               (c == "hg_napalm")   ||
               (c == "hg_linker")   ||
               ((c == "hg_sentry") && !(CVAR(g_nadgets_sentry_disown_on_death) && roundstate == ROUNDSTATE_GAME));
    }));) {
        if((n.realowner && n.realowner == plr) || n.owner == plr)
            HG_FadeOut(n);
    }
}

float HG_PlayerNadgetType(entity e) {
    float picked = HG_NameToType(CVAR_STR(g_nadgets_type));
    float argc = tokenize_console(HG_SelectableTypes(hg_context_isalt));
    float i;

    if(argc)
        for(i = 0; i < argc; ++i)
            if(e.hg_ctx_type_picked == HG_NameToType(argv(i))) {
                picked = e.hg_ctx_type_picked;
                break;
            }


    if(picked == HG_RANDOM) {
        RandomSelection_Init();
        float n; for(i = 0; i < argc; ++i) {
            n = HG_NameToType(argv(i));
            if(n != HG_RANDOM && (!hg_context_isalt || n != e.hg_type1_picked))
                RandomSelection_Add(world, n, NULL, 1, 0);
        }
        picked = RandomSelection_chosen_float;
    }

    e.hg_ctx_type_picked = picked;
    return e.hg_ctx_type_picked;
}

void HG_SetNadgetType(entity p, float t) {
    p.hg_ctx_type = t;

    if(p.scorekeeper) {
        var s = p.scorekeeper.(scores[SP_STATUSICONS]) & 0xFFFFFF00;
        PlayerScore_Set(p, SP_STATUSICONS, s + HG_CompressDualType(p.hg_type1, p.hg_type2) & 0x000000FF);
    }
}

void HG_FadeOut_Think(void) {
    self.alpha = approach(self.alpha, 0, frametime);
    if(self.hg_linker_factor)
        self.enemy.alpha = self.alpha * 0.5;

    if(!self.alpha) {
        if(self.hg_linker_factor) {
            remove(self.enemy);
            remove(self);
        } else
            HG_GenericProjectile_Remove();
        return;
    }

    self.nextthink = time;
}

void HG_FadeOut(entity n) {
    if(n.classname == "hg_sentry") {
        entity o = self;
        self = n;
        HG_Sentry_Explode();
        self = o;
        return;
    }

    if(n.hg_waypoint)
        WaypointSprite_Disown(n.hg_waypoint, 0.5);

    if(n.hg_detonable_updated && n.owner)
        n.owner.hg_detonables -= 1;

    if(!n.alpha)
        n.alpha = 1;

    if(n.classname == "hg_linker")
        n.hg_linker_factor = TRUE;

    n.solid = SOLID_NOT;
    n.takedamage = DAMAGE_NO;
    n.hg_detonable_updated = FALSE;
    n.event_damage = NULL;
    n.use = SUB_Null;
    n.think = HG_FadeOut_Think;
    n.nextthink = time;
}

void HG_SetCooldown(.float cdfield, float gcd, float cd) {
    float cdmul = Buffs_NadgetCooldown(self);
    gcd *= cdmul;
    cd *= cdmul;

    self.hg_next1 = max(self.hg_next1, time + gcd);
    self.hg_next2 = max(self.hg_next2, time + gcd);
    self.hg_bonus_next = max(self.hg_bonus_next, time + gcd);
    self.cdfield = max(self.cdfield, time + cd);
}

float HG_Attack_CallHook(float hgtype) {
    return switch(hgtype) {
        #define HGDEF(id,shortname,longname,color) case id: HG_Hook_Attack_##shortname,
        HGDEFS
        #undef HGDEF

        default: NULL
    }();
}

void HG_Attack(void) {
    if(self.deadflag != DEAD_NO)
        return;

    float hgtype;

    hg_ammo_used = 1;
    hg_ammo_available = 0;

    float n_bonus;
    var .float cdfield;

    if(hg_context_isaltintended)
        n_bonus = 0;
    else
        n_bonus = self.hg_bonus;

    if(n_bonus) {
        hgtype = self.hg_bonustype;
        hg_ammo_available = self.hg_bonus;
        cdfield = hg_bonus_next;
    } else {
        hgtype = self.hg_ctx_type;
        hg_ammo_available = self.hg_ctx_ammo;
        cdfield = hg_ctx_next;
    }

    if(time < self.cdfield)
        return;

    if(!n_bonus && !self.hg_ctx_ammo)
        return;

    switch(HG_Attack_CallHook(hgtype)) {
        case HG_ATTACK_OK:
            break;
        case HG_ATTACK_FAIL_COOLDOWN: // fallthrough
            self.cdfield = time + 1;
        case HG_ATTACK_FAIL:
            return;
        default:
            error(HG_TypeToExpandedName(hgtype) + "'s attack function returned an invalid result\n");
            return;
    }

    HG_SetCooldown(cdfield, GRENVAR(hgtype, "global_cooldown"), GRENVAR(hgtype, "cooldown"));

    if(n_bonus) {
        self.hg_bonus -= hg_ammo_used;
    } else {
        if(CVAR(g_nadgets_regen_compensate)) {
            float oregen = HG_RegenTime(self);
            self.hg_ctx_ammo -= hg_ammo_used;
            self.hg_ctx_maxregentime = HG_RegenTime(self);
            self.hg_ctx_regentime = self.hg_ctx_regentime - oregen + self.hg_ctx_maxregentime;
        } else {
            self.hg_ctx_ammo -= hg_ammo_used;
            HG_SetRegenTime(self, HG_RegenTime(self));
        }
    }

    self.buff_stealth_time = time;
    self.hg_nadesused += hg_ammo_used;
}

void HG_UpdateDetonables(void) {
    entity nade;
    self.hg_detonables = 0;

    for(;(nade = find(nade, classname, "hg_generic_projectile"));)
        if(nade.owner == self && !nade.hg_detonatetime && nade.hg_detonable && nade.hg_detonateready <= time)
            self.hg_detonables += 1;

    for(;(nade = find(nade, classname, "hg_sentry"));)
        if(nade.realowner == self)
            self.hg_detonables += 1;
}

float HG_RegenLimit(entity plr) {
    float mx = 0;

    mx = GRENVAR(plr.hg_ctx_type, "regen_limit");

    if(mx < 1)
        return 0;

    if(Buffs_Present(plr, BUFF_ADEPT))
        mx += GRENVAR(plr.hg_ctx_type, "adept_regen_limit_extend");

    float supply = Buffs_Present(plr, BUFF_SUPPLY);
    if(supply)
        mx += CVAR(g_buffs_supply_hg_extra_regen_limit) * rint(supply);

    return mx;
}

float HG_StorageLimit(entity plr) {
    float rlim = HG_RegenLimit(plr);
    return max(rlim, rint(rlim * CVAR(g_nadgets_storage_limit_factor)));
}

void HG_AdvanceRegen(entity plr, float delta, float limit) {
    if(limit && plr.hg_ctx_ammo >= limit)
        return;

    plr.hg_ctx_regentime -= delta;

    if(plr.hg_ctx_regentime <= 0) {
        var rem = -plr.hg_ctx_regentime;
        if(almost_equals(rem, 0))
            rem = 0;

        plr.hg_ctx_ammo += 1;
        HG_SetRegenTime(plr, HG_RegenTime(plr));

        if(rem)
            HG_AdvanceRegen(plr, rem, limit);
    }
}

void HG_PlayerFrame(void) {
    if(!g_nadgets)
        return;

    if(time < game_starttime)
        return;

    if(self.hg_linker && wasfreed(self.hg_linker))
        self.hg_linker = world;

    HG_Shield_PlayerFrame();
    HG_Cloak_PlayerFrame();

    if(roundstate == ROUNDSTATE_OVER) {
        self.hg_power = 0;
        return;
    }

	float mayfire = (!g_grappling_hook || (!self.hook && !CustomHGHookButton(self))) || self.hg_power;

    if(time < self.hg_plasmalock || PlayerIsDead(self))
        mayfire = FALSE;

	float held, isalt;
	held = self.(if(g_nadgets_detonatelaunches) hg_detonatepressed else BUTTON_NADGET);

    float n_type;

    if(!held) {
        held = (self.BUTTON_NADGET2 || (!g_grappling_hook && self.BUTTON_USE));
        if(held) {
            isalt = TRUE;
        }
    }

    float charging;

    if(self.hg_altcharge || (g_nadgets_detonatelaunches && !self.hg_altstate)) {
        charging = (held || self.hg_power);

        if(self.hg_power && held && held != self.hg_state)
            charging = FALSE;
    } else {
        charging = held;
    }

    if(self.hg_power)
        isalt = self.hg_altstate;

    HG_SetContext(isalt);

    if(!isalt && self.hg_bonus) {
        hg_ctx_ammo = hg_bonus;
        hg_ctx_next = hg_bonus_next;
        n_type = self.hg_bonustype;
    } else {
        n_type = self.hg_ctx_type;
    }

    if(held && held != self.hg_state) {
        if(self.hg_ctx_type == HG_TIMEWARP && self.hg_twarp_moment) {
            HG_TimeWarper_Trigger(FALSE);
        } else if(!self.hg_ctx_ammo && self.deadflag == DEAD_NO) {
            bigprint_spec(self, strcat("Out of ", HG_TypeToExpandedName(n_type), "s!"), "", 1);
        }
    }

    if(charging && time >= self.hg_ctx_next && self.hg_ctx_ammo && mayfire) {
        float ls = GRENVAR(n_type, "launchspeed");

        self.hg_launchspeed = ls;

        if(ls)
            self.hg_power = bound(0.01, self.hg_power + frametime * ls, 1);
        else {
            self.hg_power = 0;
            HG_Attack();
        }
	} else {
		if(self.hg_power && mayfire && self.hg_launchspeed)
			HG_Attack();
		self.hg_power = 0;
	}

	if(self.hg_power == 1 && mayfire && GRENVAR(n_type, "launch_fullforce_launches_immediately"))
		HG_Attack();

	self.hg_state = held;
    self.hg_altstate = isalt;

    if(CVAR(g_nadgets_regen)) HG_DO_IN_ALL_CONTEXTS({
        float mx = HG_RegenLimit(self);
        float dpause = CVAR(g_nadgets_regen_damagepause) * Buffs_NadgetRegenDmgPause(self);

        self.hg_ctx_regenrate = GRENVAR(self.hg_ctx_type, "regen_scale");
        dpause = min(dpause, dpause / self.hg_ctx_regenrate);
        self.hg_ctx_regenpaused = (((self.hg_stealth || self.hg_stealth_saved) && self.hg_ctx_type == HG_CLOAK) || (time - self.lastdamage <= dpause));

        if(self.hg_ctx_ammo < mx || !mx) {
            if(!self.hg_ctx_regenpaused) {
                if(g_freeze && self.frozen)
                    self.hg_ctx_regenrate *= CVAR(g_nadgets_regen_frozenfactor);
                self.hg_ctx_regenrate *= Buffs_NadgetRegen(self);

                HG_AdvanceRegen(self, frametime * self.hg_ctx_regenrate, mx);
            }
        } else
            self.hg_ctx_regenrate = 0;
    })

    if(self.hg_detonatepressed)
        self.hg_detonatepressed = FALSE;
}

void HG_Trigger(void) {
    if(PlayerIsDead(self))
        return;

    if(self.hg_stealth || self.hg_stealth_saved)
        HG_Cloak_Trigger();
    else if(self.hg_shield || (self.hg_shield_stored && CVAR(g_nadgets_shield_damage_store_allow_cancel_discharge)))
        HG_Shield_Trigger();
    else {
        HG_Sentry_Trigger();

        if(!HG_GenericProjectile_DetonateAll(self, FALSE)) {
            if(self.hg_twarp_moment) {
                HG_TimeWarper_Trigger(FALSE);
                return;
            }
        }

        self.hg_detonatepressed = TRUE;

        if(Buffs_Present(self, BUFF_ADEPT)) {
            float i;
            HG_LOOP_FOR_ALL_CONTEXTS(i, {
                if(self.hg_ctx_type == HG_LASER) {
                    HG_Attack();
                    break;
                }
            })
        }
    }
}

void HG_CopyAmmoState(entity src, entity dst) {
    dst.hg_ctx_ammo = src.hg_ctx_ammo;
    dst.hg_ctx_regentime = src.hg_ctx_regentime;
    dst.hg_ctx_maxregentime = src.hg_ctx_maxregentime;
    dst.hg_ctx_regenrate = src.hg_ctx_regenrate;
    dst.hg_ctx_regenpaused = src.hg_ctx_regenpaused;
}

void HG_ResetAmmo(entity p, float clearammo) {
    p.hg_ctx_ammo = if(clearammo) 0 else CVAR(g_nadgets_ammo);

    HG_SetNadgetType(p, HG_PlayerNadgetType(p));
    HG_SetRegenTime(p, HG_RegenTime(p));

    if(!clearammo) {
        var mx = HG_StorageLimit(p);
        HG_AdvanceRegen(p, CVAR(g_nadgets_initial_regen), mx);

        if(!CVAR(g_nadgets_regen)) {
            if(p.hg_ctx_regentime / p.hg_ctx_maxregentime < 0.5)
                HG_AdvanceRegen(p, p.hg_ctx_regentime, mx);
            else
                p.hg_ctx_regentime = p.hg_ctx_maxregentime;
        }
    }
}

void HG_ResetState(entity p, float clearammo) {
    p.hg_power = 0;
    p.hg_bonus = 0;
    p.hg_bonustype = HG_NORMAL;
    p.hg_shield = 0;
    HG_DO_IN_ALL_CONTEXTS(HG_ResetAmmo(p, clearammo);)
}

void HG_PlayerSpawn(void) {
    if(self.classname != "player")
        return;

    HG_TimeWarper_Abort();

    if(CVAR(g_nadgets_resetonrespawn))
        HG_ResetState(self, PlayerIsDead(self));

    self.hg_shield = 0;
    HG_UpdateDetonables();
}

void HG_PlayerJoin(void) {
    if(self.classname != "player")
        return;

    HG_ResetState(self, PlayerIsDead(self));
    HG_UpdateDetonables();
}

void HG_ForceDetonateAll(void) {
    HG_GenericProjectile_DetonateAll(self, TRUE);

    for(var s = world; (s = find(s, classname, "hg_sentry"));) {
        if(s.realowner == self)
            HG_FadeOut(s);
    }
}

void HG_PlayerDeath(void) {
    // Called for all deaths

    if(!g_nadgets)
        return;

    HG_TimeWarper_Abort();

    if(CVAR(g_nadgets_remove_on_death) > 1)
        HG_RemoveAll(self);

    if(self.hg_power > 0 && CVAR(g_nadgets_drop_on_death)) {
        HG_SetContext(self.hg_altstate);
        self.hg_power = 0;
        HG_Attack();
    }

    if(!g_freezetag && !g_jailbreak) {
        if(CVAR(g_nadgets_resetonrespawn))
            self.hg_ammo1 = self.hg_ammo2 = 0;
    }

    if(CVAR(g_nadgets_detonate_on_death) > 1)
        HG_ForceDetonateAll();
}

void HG_PlayerTrueDeath(void) {
    // Called only for "real" deaths not intercepted by gametype rules
    // Won't be called for getting frozen, for example

    if(!g_nadgets)
        return;

    if(CVAR(g_nadgets_remove_on_death) == 1)
        HG_RemoveAll(self);

    if(CVAR(g_nadgets_detonate_on_death) == 1)
        HG_ForceDetonateAll();
}

string HG_SelectableTypes(float issecondary) {
    if(!g_nadgets_double)
        return CVAR_STR(g_nadgets_type_selectable);

    if(issecondary)
        return CVAR_STR(g_nadgets_type_selectable_secondary);

    return CVAR_STR(g_nadgets_type_selectable_primary);
}

void HG_WriteNadgetSelect(void) {
    msg_entity = self;
    WriteByte(MSG_ONE, SVC_TEMPENTITY);
    WriteByte(MSG_ONE, TE_CSQC_NADGETSELECT);
    WriteString(MSG_ONE, HG_SelectableTypes(FALSE));

    if(g_nadgets_double)
        WriteString(MSG_ONE, HG_SelectableTypes(TRUE));
}

float HG_ShowMenu(float always) {
    if((self.hg_type1_picked && self.BUTTON_CHAT) && always < 2)
        return FALSE;

    if(g_nadgets && HG_SelectableTypes(FALSE) != "" && (always || !self.hg_type1_picked || (g_nadgets_double && !self.hg_type2_picked)) && clienttype(self) == CLIENTTYPE_REAL) {
        HG_WriteNadgetSelect();
        return TRUE;
    }

    return FALSE;
}

void spawnfunc_target_bonusnadgets(void) {
    self.classname = "target_bonusnadgets";
    self.hg_type1 = HG_NameToType(self.netname);
    self.cnt = floor(max(0, self.cnt));

    if(!self.message)
        self.message = "a secret has been triggered";

    self.use = inline void(void) {
        if(!PlayerIsDead(activator))
            HG_GiveBonus(activator, self.hg_type1, self.cnt, self.message, FALSE);
    };
}
