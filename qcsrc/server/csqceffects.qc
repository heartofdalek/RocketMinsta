
void te_csqc_lightningarc(vector from, vector to, float flash, float ateam)
{
    WriteByte(MSG_BROADCAST, SVC_TEMPENTITY);
    WriteByte(MSG_BROADCAST, TE_CSQC_LIGHTNINGARC);
    
    WriteByte(MSG_BROADCAST, flash);
    WriteByte(MSG_BROADCAST, ateam-1);
    WriteCoord(MSG_BROADCAST, from_x);
    WriteCoord(MSG_BROADCAST, from_y);
    WriteCoord(MSG_BROADCAST, from_z);
    WriteCoord(MSG_BROADCAST, to_x);
    WriteCoord(MSG_BROADCAST, to_y);
    WriteCoord(MSG_BROADCAST, to_z);
}

void te_heal(entity e) {
    entity c;
    vector o = e.origin + e.view_ofs;
    
    FOR_EACH_REALCLIENT(c) if(c.clientcamera != e) {
        if(c.iscreature)
        if(e.hg_stealth || Client_CalculateAlpha(e, c) < 0.15)
        if(IsDifferentTeam(c, e))
            continue;

        msg_entity = c;
        WriteByte(MSG_ONE, SVC_TEMPENTITY);
        WriteByte(MSG_ONE, TE_CSQC_HEAL);
        WriteCoord(MSG_ONE, o_x);
        WriteCoord(MSG_ONE, o_y);
        WriteCoord(MSG_ONE, o_z);
    }
}

void te_blast(vector loc) {
    WriteByte(MSG_BROADCAST, SVC_TEMPENTITY);
    WriteByte(MSG_BROADCAST, TE_CSQC_BLAST);
    
    WriteCoord(MSG_BROADCAST, loc_x);
    WriteCoord(MSG_BROADCAST, loc_y);
    WriteCoord(MSG_BROADCAST, loc_z);
}

void te_meodp(vector loc) {
    WriteByte(MSG_BROADCAST, SVC_TEMPENTITY);
    WriteByte(MSG_BROADCAST, TE_CSQC_MEODP);
    
    WriteCoord(MSG_BROADCAST, loc_x);
    WriteCoord(MSG_BROADCAST, loc_y);
    WriteCoord(MSG_BROADCAST, loc_z);
}

void te_eleblast(vector loc, float ateam) {
    WriteByte(MSG_BROADCAST, SVC_TEMPENTITY);
    WriteByte(MSG_BROADCAST, TE_CSQC_ELEBLAST);
    
    WriteByte(MSG_BROADCAST, ateam-1);
    WriteCoord(MSG_BROADCAST, loc_x);
    WriteCoord(MSG_BROADCAST, loc_y);
    WriteCoord(MSG_BROADCAST, loc_z);
}
