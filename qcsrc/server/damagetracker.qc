
void DamageTracker_Print(entity keeper, entity to) {
    float i, j;
    
    DamageTracker_Sort(keeper);
    sprint(to, "\n------------------------------------------------------------\n");
    sprint(to, strcat("^5", keeper.netname, "^6 stats for ^7", keeper.owner.netname, "^6:\n"));
    sprint(to, "------------------------------------------------------------\n");
    
    FOR_DTRACK_ENTRIES(keeper, i) {
        float damage = keeper.(dtrack_damage[i]);
        string ratio = ftos((damage / keeper.dtrack_totaldamage) * 100);
        ratio = substring(ratio, 0, strstrofs(ratio, ".", 0) + 3);
        string srcname = DamageTracker_DamageSourceName(keeper.(dtrack_type[i]), TRUE);
        sprint(to, strcat(ftos(i+1), ". ^2", srcname));
        float spaces = max(1, 45 - strlen(srcname));
        for(j = 0; j < spaces; ++j)
            sprint(to, " ");
        sprint(to, strcat("^3", FormatDamage(damage), "^7 (", ratio, "%)\n"));
    }
    
    sprint(to, "------------------------------------------------------------\n\n");
}

float DamageTracker_SetSecondaryFlipped(float dtype) {
    // Set the HITTYPE_VISUAL_FLIPSECONDARY bit if this attack is HITTYPE_SECONDARY but should be represented as if it isn't, or vise-versa.
    // Otherwise, unset it.

    dtype &~= HITTYPE_VISUAL_FLIPSECONDARY;

    var wep = DEATH_WEAPONOFWEAPONDEATH(dtype);
    if(WEP_VALID(wep)) {

        if(cvar("g_balance_" + get_weaponinfo(wep).netname + "_swapshotmodes")) {
            BITXOR_ASSIGN(dtype, HITTYPE_VISUAL_FLIPSECONDARY);
        }

        if(W_WeaponBit(wep) & g_weaponarena_secondary) {
            BITXOR_ASSIGN(dtype, HITTYPE_VISUAL_FLIPSECONDARY);
        }
    }

    return dtype;
}

void DamageTracker_Overwrite(entity keeper, entity client, float dtflags) {
    float ecnt, i;
    
    if(!sv_damagestats)
        return;
    
    if(clienttype(client) != CLIENTTYPE_REAL)
        return;
    
    dtflags |= DTFLAG_OVERWRITE;

    ecnt = DamageTracker_Sort(keeper);
    
    msg_entity = client;
    WriteByte(MSG_ONE, SVC_TEMPENTITY);
    WriteByte(MSG_ONE, TE_CSQC_DTRACK);
    WriteByte(MSG_ONE, dtflags);
    WriteByte(MSG_ONE, ecnt);
    
    FOR_DTRACK_ENTRIES(keeper, i) {
        WriteShort(MSG_ONE, keeper.(dtrack_type[i]));
        WriteShort(MSG_ONE, keeper.(dtrack_damage[i]));
    }
}

void DamageTracker_Send(float msg, float dtype, float damage, float dtflags) {
    WriteByte(msg, SVC_TEMPENTITY);
    WriteByte(msg, TE_CSQC_DTRACK);
    WriteByte(msg, dtflags);
    WriteShort(msg, dtype);
    WriteShort(msg, damage * 10);
}

void DamageTracker_RecordAndSend(entity keeper, float dtype, float damage, float dtflags) {
    if(!sv_damagestats || inWarmupStage)
        return;

    if(!keeper.owner.iscreature && !(dtflags & DTFLAG_GLOBAL))
        return;

    if(damage <= 0)
        return;

    dtype = DamageTracker_SetSecondaryFlipped(dtype);
    DamageTracker_Record(keeper, dtype, damage);

    dtflags &~= DTFLAG_OVERWRITE;
    dtflags &~= DTFLAG_SPEC;

    if(dtflags & DTFLAG_GLOBAL) {
        DamageTracker_Send(MSG_ALL, dtype, damage, dtflags);
        return;
    }

    FOR_EACH_REALCLIENT(var e) {
        if(e.clientcamera == keeper.owner) {
            msg_entity = e;
            DamageTracker_Send(MSG_ONE, dtype, damage, dtflags | (if(e == keeper.owner) 0 else DTFLAG_SPEC));
        }
    }
}

