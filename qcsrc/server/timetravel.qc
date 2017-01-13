
#define TIMETRAVEL_HANDLE_ALL \
        TIMETRAVEL_HANDLE(health,                       Float)      \
        TIMETRAVEL_HANDLE(armorvalue,                   Float)      \
        TIMETRAVEL_HANDLE(pushltime,                    Time)       \
        TIMETRAVEL_HANDLE(origin,                       Origin)     \
        TIMETRAVEL_HANDLE(angles,                       Angles)     \
        TIMETRAVEL_HANDLE(velocity,                     Vector)     \
        TIMETRAVEL_HANDLE(strength_finished,            Time)       \
        TIMETRAVEL_HANDLE(invincible_finished,          Time)       \
        TIMETRAVEL_HANDLE(jump_interval,                Time)       \
        TIMETRAVEL_HANDLE(ammo_shells,                  Float)      \
        TIMETRAVEL_HANDLE(ammo_nails,                   Float)      \
        TIMETRAVEL_HANDLE(ammo_rockets,                 Float)      \
        TIMETRAVEL_HANDLE(ammo_cells,                   Float)      \
        TIMETRAVEL_HANDLE(ammo_fuel,                    Float)      \
        TIMETRAVEL_HANDLE(weapons,                      Float)      \
        TIMETRAVEL_HANDLE(items,                        Float)      \
        TIMETRAVEL_HANDLE(cnt,                          Float)      \
        TIMETRAVEL_HANDLE(spawnshieldtime,              Time)       \
        TIMETRAVEL_HANDLE(pauserotarmor_finished,       Time)       \
        TIMETRAVEL_HANDLE(pauserothealth_finished,      Time)       \
        TIMETRAVEL_HANDLE(pauserotfuel_finished,        Time)       \
        TIMETRAVEL_HANDLE(pauseregen_finished,          Time)       \
        TIMETRAVEL_HANDLE(avelocity,                    Vector)     \
        TIMETRAVEL_HANDLE(punchangle,                   Vector)     \
        TIMETRAVEL_HANDLE(punchvector,                  Vector)     \
        TIMETRAVEL_HANDLE(oldvelocity,                  Vector)     \
        TIMETRAVEL_HANDLE(crouch,                       Float)      \
        TIMETRAVEL_HANDLE(lastdamage,                   Time)       \
        TIMETRAVEL_HANDLE(last_dodging_time,            Time)       \
        TIMETRAVEL_HANDLE(wj_jumptime,                  Time)       \
        TIMETRAVEL_HANDLE(frozen,                       Float)      \
        TIMETRAVEL_HANDLE(freezetime,                   Time)       \
        TIMETRAVEL_HANDLE(jb_isprisoned,                Float)      \
        TIMETRAVEL_HANDLE(jb_prisontime,                Time)       \
        TIMETRAVEL_HANDLE(disableclientprediction,      Float)      \
        TIMETRAVEL_HANDLE(buff_vamp_ticks,              Float)      \
        TIMETRAVEL_HANDLE(buff_vamp_healthpool,         Float)      \
        TIMETRAVEL_HANDLE(buff_vamp_nexttick,           Time)       \
        TIMETRAVEL_HANDLE(hg_power,                     Float)      \
        TIMETRAVEL_HANDLE(hg_state,                     Float)      \
        TIMETRAVEL_HANDLE(hg_altstate,                  Float)      \
        TIMETRAVEL_HANDLE(hg_next1,                     Time)       \
        TIMETRAVEL_HANDLE(hg_next2,                     Time)       \
        TIMETRAVEL_HANDLE(hg_bonus_next,                Time)       \
        TIMETRAVEL_HANDLE(hg_ammo1,                     Float)      \
        TIMETRAVEL_HANDLE(hg_ammo2,                     Float)      \
        TIMETRAVEL_HANDLE(hg_bonus,                     Float)      \
        TIMETRAVEL_HANDLE(hg_bonustype,                 Float)      \
        TIMETRAVEL_HANDLE(hg_regentime1,                Float)      \
        TIMETRAVEL_HANDLE(hg_maxregentime1,             Float)      \
        TIMETRAVEL_HANDLE(hg_regentime2,                Float)      \
        TIMETRAVEL_HANDLE(hg_maxregentime2,             Float)      \
        TIMETRAVEL_HANDLE(buff_conduit_hpool,           Float)      \
        TIMETRAVEL_HANDLE(buff_conduit_apool,           Float)      \
        TIMETRAVEL_HANDLE(buff_conduit_dpool,           Float)      \
        TIMETRAVEL_HANDLE(buff_conduit_next,            Time)       \
        TIMETRAVEL_HANDLE(zapper_heat,                  Float)      \
        TIMETRAVEL_HANDLE(zapper_coolofftime,           Time)       \
        TIMETRAVEL_HANDLE(fire_damagepersec,            Float)      \
        TIMETRAVEL_HANDLE(fire_endtime,                 Time)       \
        TIMETRAVEL_HANDLE(fire_deathtype,               Float)      \
        TIMETRAVEL_HANDLE(fire_owner,                   Entity)     \
        TIMETRAVEL_HANDLE(buff_endur_dmgpool,           Float)      \
        TIMETRAVEL_HANDLE(pryaxe_attackdone,            Float)      \
        TIMETRAVEL_HANDLE(pryaxe_thrown,                Entity)     \
        TIMETRAVEL_HANDLE_SPECIAL(EnduranceState)                   \
        TIMETRAVEL_HANDLE_SPECIAL(WeaponState)                      \



void TimeTravel_StoreWeaponState(entity e, entity moment) {
    if(!e.weaponentity)
        return;

    moment.weapon = e.weapon;

    entity oldself = self;
    self = e;
    tt_moment = moment;
    float w; for(w = WEP_FIRST; w <= WEP_LAST; ++w) {
        weapon_action(w, WR_TT_STORE);
        ATTACK_FINISHED_FOR(moment, w) = ATTACK_FINISHED_FOR(e, w) - time;
    }
    self = oldself;
}

void TimeTravel_RestoreWeaponState(entity e, entity moment) {
    if(!e.weaponentity)
        return;

    e.weaponentity.state = WS_READY;
    W_SwitchWeapon_Force(e, moment.weapon);
    e.w_instaswitch = TRUE;

    entity oldself = self;
    self = e;
    tt_moment = moment;
    float w; for(w = WEP_FIRST; w <= WEP_LAST; ++w) {
        weapon_action(w, WR_TT_RESTORE);
        ATTACK_FINISHED_FOR(e, w) = ATTACK_FINISHED_FOR(moment, w) + time;
    }
    weapon_thinkf(WFRAME_IDLE, 0, w_ready);
    self = oldself;
}

.entity tt_endur_snapshot_chain;
.float tt_endur_snapshot_thinktime;

void TimeTravel_StoreEnduranceState(entity plr, entity moment) {
    // Find all Endurance DOTs ticking on the player, and create a snapshot of each
    // Chain them and attach them to the moment, to restore the DOTs from them later

    var chain_last = moment;

    for(var e = world; (e = find(e, classname, "buff_endur_dot"));) if(e.enemy == plr) {
        var s = spawn() {
            classname: "tt_endur_dot_snapshot",
            // Do not add a reset: SUB_Remove or similar here.
            // TimeTravel_EraseMoment will take care of removing these snapshots.
        };

        TimeTravel_StoreEntity(e, s, owner);
        TimeTravel_StoreEntity(e, s, enemy);
        TimeTravel_StoreFloat(e, s, buff_endur_ticks);
        TimeTravel_StoreFloat(e, s, buff_endur_dmgpool);
        TimeTravel_StoreTime(e, s, nextthink);

        // Don't let the engine try to run .think()
        s.tt_endur_snapshot_thinktime = s.nextthink;
        s.nextthink = 0;

        chain_last.tt_endur_snapshot_chain = s;
        chain_last = s;
    }
}

void TimeTravel_RestoreEnduranceState(entity plr, entity moment) {
    var e;

    // First, remove all Endurance DOTs ticking on the player right now

    for(e = world; (e = find(e, classname, "buff_endur_dot"));) if(e.enemy == plr) {
        e.think = SUB_Remove;
        e.nextthink = time;
    }

    // Now, turn our snapshotted DOTs into real Endurance DOTs, and start ticking!
    // This is efficient, but only works if the moment is restored not more than once.
    // As of now, only the Time Warper nadget uses time traveling, and it meets the above condition.

    for(e = moment.tt_endur_snapshot_chain; e; e = e.tt_endur_snapshot_chain) {
        TimeTravel_RestoreTime(e, e, tt_endur_snapshot_thinktime);

        e {
            classname: "buff_endur_dot",
            reset: SUB_Remove,
            think: Buffs_Endurance_DOT_Think,
            nextthink: e.tt_endur_snapshot_thinktime,
        };
    }

    // Detach the snapshot chain from the moment
    // They are real DOTs now, so we don't want TimeTravel_EraseMoment to remove them

    moment.tt_endur_snapshot_chain = world;
}

#define TIMETRAVEL_HANDLE(f,t) TimeTravel_Store##t(e, moment, f);
#define TIMETRAVEL_HANDLE_SPECIAL(t) TimeTravel_Store##t(e, moment);
entity TimeTravel_SaveMoment(entity e) {
    entity moment;
    
    if(!e)
        return world;
    
    moment = spawn() {
        classname     : "tt_moment",
        tt_momenttime : time,
        reset         : inline void(void) {
            TimeTravel_EraseMoment(self);
        }
    };

    TIMETRAVEL_HANDLE_ALL
    return moment;
}
#undef TIMETRAVEL_HANDLE_SPECIAL
#undef TIMETRAVEL_HANDLE

#define TIMETRAVEL_HANDLE(f,t) TimeTravel_Restore##t(e, moment, f);
#define TIMETRAVEL_HANDLE_SPECIAL(t) TimeTravel_Restore##t(e, moment);
void TimeTravel_TakeBack(entity e, entity moment) {
    if(!e || !moment)
        return;
    
    TIMETRAVEL_HANDLE_ALL
}
#undef TIMETRAVEL_HANDLE_SPECIAL
#undef TIMETRAVEL_HANDLE

void TimeTravel_EraseMoment(entity moment) {
    if(moment.classname != "tt_moment") {
        error("TimeTravel_EraseMoment: not a moment (" + moment + ")");
    }

    // Remove any leftover Endurance DOT snapshots, if any
    // Should happen only if the moment was never restored
    for(var e = moment.tt_endur_snapshot_chain; e; e = e.tt_endur_snapshot_chain) {
        e.think = SUB_Remove;
        e.nextthink = time;
    }

    remove(moment);
}

#undef TIMETRAVEL_HANDLE_ALL
#undef TIMETRAVEL_STORE_IDENTITY
#undef TIMETRAVEL_RESTORE_IDENTITY
#undef TIMETRAVEL_HANDLER

entity TimeTravel_Track(entity e, float maxtime, float accuracy) {
    if(e.tt_lastmoment && time - e.tt_lastmoment.tt_momenttime < accuracy)
        return e.tt_lastmoment;

    if(!(var moment = TimeTravel_SaveMoment(e)))
        return world;

    moment.tt_lastmoment = e.tt_lastmoment;
    e.tt_lastmoment = moment;

    var lastmoment_owner = e;
    for(var lastmoment = var m = moment; (m = m.tt_lastmoment);) {
        lastmoment_owner = lastmoment;
        lastmoment = m;
    }

    if(lastmoment && time - lastmoment.tt_momenttime > maxtime) {
        TimeTravel_EraseMoment(lastmoment);
        lastmoment_owner.tt_lastmoment = world;
    }

    return moment;
}

void TimeTravel_TakeBack_ToTracked(entity e, float mtime) {
    var moment = world;
    var mindiff = mtime;

    for(var m = e.tt_lastmoment; (m = m.tt_lastmoment);) {
        if((var d = fabs(mtime - m.tt_momenttime)) < mindiff) {
            mindiff = d;
            moment = m;
        }
    }

    if(!moment)
        return;

    TimeTravel_TakeBack(e, moment);
}
