/**
 * The point of these entities is to avoid the problems
 * with clientprediction.
 * If you add SendEntity to players, the engine will not
 * do any prediction anymore, and you'd have to write the whole
 * prediction code in CSQC, you want that? :P
 * Data can depend on gamemode. For now, it serves as GPS entities
 * in onslaught... YAY ;)
 */

// Beware: do not redefine those in other files
// and NO, you cannot use ".version", which already exists (at least
// it did when I added this) But you have to use .Version
// Capital V

.entity entcs;

void entcs_init(void) {
    print("Initializing ClientSide information entities\n");
}

#define entcs_culled per_client_data

float entcs_cull(entity what, entity forwhom) {
    if(what.owner == forwhom.clientcamera)
        return TRUE;

    if(what.owner.deadflag != DEAD_NO)
        return TRUE;

    if(what.owner.classname != "player") if(what.owner.bait_ref.classname != "player")
        return TRUE;

    if(!forwhom.iscreature)
        return FALSE;

    forwhom = forwhom.clientcamera;

    if(IsDifferentTeam(what.owner, forwhom)) {
        if(!sv_shownames || what.owner.hg_stealth || Client_CalculateAlpha(what.owner, forwhom) < 0.15)
            return TRUE;

        if(vlen(what.owner.origin - forwhom.origin) > SHOWNAMES_MAXDISTANCE)
            return TRUE;

        vector viewee = what.owner.origin + what.owner.view_ofs;
        vector viewer = forwhom.origin + forwhom.view_ofs;

        if(!warpzone_chain_begin && CVAR(sv_cullentities_pvs)) {
            if(!checkpvs(viewee, forwhom))
                return TRUE;
        }

        if(CVAR(sv_cullentities_trace)) {
            save_trace_globals();
            makevectors(forwhom.v_angle);
            var los = WarpZone_FindLineOfSight(v_forward, viewer, viewee, MOVE_NOMONSTERS, forwhom);
            restore_trace_globals();

            if(los == '0 0 0')
                return TRUE;
        }
    }

    return FALSE;
}

float entcs_customize(void) {
    return !(self.(entcs_culled[num_for_edict(other)-1]));
}

//
//  sendflags:
//
//  id           1
//  origin_xy    2
//  <unused>     4
//  angles_y     8
//  health       16
//  armor        32
//  sameteam     64
//

float entcs_send(entity to, float sf) {
    entity o;
    o = self.owner;

    sf = sf & 255;

    entity check = to.clientcamera;

    if(!IsDifferentTeam(check, o) || (sv_shownames && check.hg_stealth && !o.hg_stealth) || sv_cheats) {
        sf |= 64;
    } else {
        sf &~= (8 | 16 | 32 | 64);
        if(!sv_shownames)
            sf &~= (2 | 4); // never send enemy origins in case the cull failed for some reason (e.g. early send)
    }
    
    if(entcs_cull(self, check)) {
        // this is for team mates. Enemy cull is done in entcs_customize.
        sf &~= (4 | 16 | 32);
    }

    WriteByte(MSG_ENTITY, ENT_CLIENT_ENTCS);
    WriteByte(MSG_ENTITY, sf);

    if(sf & 1) {
        WriteByte(MSG_ENTITY, num_for_edict(if(o.bait_ref) o.bait_ref else o));
        WriteByte(MSG_ENTITY, self.owner.bait_ref && self.owner.frozen);
    }

    if(sf & 2) {
        WriteShort(MSG_ENTITY, o.origin_x);
        WriteShort(MSG_ENTITY, o.origin_y);
        WriteShort(MSG_ENTITY, o.origin_z);
    }

    // sf & 4 unused

    if(sf & 8) {
        WriteByte(MSG_ENTITY, o.angles_y * 256.0 / 360);
    }

    if(sf & 16) {
        WriteShort(MSG_ENTITY, self.health);
    }

    if(sf & 32) {
        WriteShort(MSG_ENTITY, self.armorvalue);
    }
    
    return TRUE;
}

void entcs_think(void) {
    self.nextthink = time + CVAR(sv_shownames_update);
    
    entity o;
    o = self.owner;

    if(o.origin != self.origin) {
        setorigin(self, o.origin);
        self.SendFlags |= 2;
    }

    if(o.angles_y != self.angles_y) {
        self.angles = o.angles;
        self.SendFlags |= 8;
    }

    if(sv_shownames) {
        float h = max(0, floor(self.owner.health));
        float a = max(0, floor(self.owner.armorvalue));

        if(self.health != h) {
            self.health = h;
            self.SendFlags |= 16;
        }

        if(self.armorvalue != a) {
            self.armorvalue = a;
            self.SendFlags |= 32;
        }
    }

    float i; for(i = 1; i <= maxclients; ++i) {
        entity c = edict_num(i);

        if(clienttype(c) == CLIENTTYPE_REAL) {
            self.(entcs_culled[i-1]) = entcs_cull(self, c);
        }
    }
}

entity attach_entcs(void) {
    entity ent;
    
    ent = spawn();
    ent.classname = "entcs_sender_v2";
    ent.owner = self;
    ent.think = entcs_think;
    ent.nextthink = time;

    Net_LinkEntity(ent, FALSE, 0, entcs_send);
    ent.customizeentityforclient = entcs_customize;

    self.entcs = ent;

    return ent;
}

void detach_entcs(void) {
    remove(self.entcs);
    self.entcs = world;
}
