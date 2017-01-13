
void HG_Bait_Body_Damage(entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force) {
    PlayerDamage(inflictor, attacker, damage, deathtype, hitloc, force * Freeze_CVar(frozen_force));
}

void HG_Bait_Body_Remove(entity body) {
    if(body.freeze_waypoint)
        WaypointSprite_Disown(body.freeze_waypoint, 0.5);

    HG_Waypoint_Remove(body.hg_waypoint);

    if(body.iceblock)
        remove(body.iceblock);

    if(body.exteriorweaponentity)
        remove(body.exteriorweaponentity);

    if(body.entcs)
        remove(body.entcs);

    remove(body);
}

float HG_Bait_Iceblock_Customize(void) {
    if(other.iscreature && other.team == self.owner.realowner.team)
        self.colormod = '0 2 0';
    else
        self.colormod = '1 1 1';

    return TRUE;
}

void HG_Bait_Body_Think(void) {
    Freeze_Hook_PlayerPreThink();
    SV_PlayerPhysics();

    if(time > self.hg_deathtime || self.realowner.team != self.hg_state) {
        HG_Bait_Body_Remove(self);
        return;
    }

    // freeze sound doesn't work properly if this is not delayed
    if(!self.iceblock) {
        Freeze_SpawnIceBlock(self);

        if(Freeze_CVar(iceblocks_teamcolored))
            self.iceblock.skin = TeamColorSkin(self.team);

        if(teams_matter)
            self.iceblock.customizeentityforclient = HG_Bait_Iceblock_Customize;
    }

    if(time > self.hg_nextsnd)
    if(self.revprogress > 0.85) {
        self.hg_nextsnd = time + 0.1;
        sound(self, CHAN_PROJECTILE, "weapons/rm_nadebeep.wav", VOL_BASE * 0.5, ATTN_NORM * 2);
    }

    HG_Waypoint();
    self.nextthink = time;
}

void HG_Bait_Body_Boom(entity body) {
    using(self = body) {
        body.owner = body.realowner;
        HG_GenericProjectile_RadiusDamage();
        HG_Bait_Body_Remove(body);
    }
}

entity HG_Bait_Create(entity ref) {
    entity oldself = self;
    self = ref;

    entity body = CopyBody(FALSE);
    body.classname = "bait_body";
    body.team = ref.team;
    body.health = Freeze_CVar(frozen_health);
    body.armorvalue = Freeze_CVar(frozen_armor);
    body.think = HG_Bait_Body_Think;
    body.event_damage = HG_Bait_Body_Damage;
    body.reset = HG_Bait_Body_Remove;
    body.nextthink = time;
    body.frozen = TRUE;
    body.realowner = oldself;
    body.hg_type = body.projectiledeathtype = HG_BAIT;
    body.hg_deathtime = time + GRENVAR(HG_BAIT, "lifetime");
    body.aiment = body.bait_ref = ref;
    body.hg_state = oldself.team;
    body.colormod = ref.colormod;
    setorigin(body, oldself.origin);

    entity w = spawn();
    w.classname = "exteriorweaponentity";
    w.solid = SOLID_NOT;
    w.owner = body;
    setorigin(w, '0 0 0');
    w.angles = '0 0 0';
    w.effects = body.effects | EF_LOWPRECISION;
    w.effects = w.effects & EFMASK_CHEAP;
    w.colormap = ref.exteriorweaponentity.colormap;
    setmodel(w, ref.exteriorweaponentity.model);

    float tag_found;
    if((tag_found = gettagindex(w.owner, "tag_weapon"))) {
        w.tag_index = tag_found;
        w.tag_entity = w.owner;
    } else
        setattachment(w, w.owner, "bip01 r hand");

    body.exteriorweaponentity = w;

    self = body;
    attach_entcs();
    self = oldself;

    return body;
}

entity HG_Bait_PickRef(void) {
    entity plr;

    RandomSelection_Init();
    FOR_EACH_PLAYER(plr) if(plr.team != self.team)
        RandomSelection_Add(plr, 0, NULL, 1, 1);

    return RandomSelection_chosen_ent;
}

HG_HOOKFUNCTION(bait, Attack) {
    entity ref = HG_Bait_PickRef();

    if(!ref) {
        bigprint_spec(self, "No enemies!", "", 1);
        return HG_ATTACK_FAIL_COOLDOWN;
    }

    HG_Bait_Create(ref);
    return HG_ATTACK_OK;
}

HG_EMPTY_INITFUNC(bait)
