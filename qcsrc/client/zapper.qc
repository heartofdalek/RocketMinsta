
.vector zapper_start;
.vector zapper_real_start;
.vector zapper_end;
.vector zapper_offs;
.float zapper_inverted_shotorg;

vector Zapper_BeamRGB(float t) {
    switch(t) {
        case COLOR_TEAM1:            return '5.0   1.0   0.5';
        case COLOR_TEAM2: default:   return '0.5   1.0   5.0';
        case COLOR_TEAM3:            return '4.0   2.5   0.5';
        case COLOR_TEAM4:            return '5.0   0.7   3.0';
    }
}

float plane_sign(vector plane_point, vector plane_norm, vector point) {
	float sign = (plane_norm_x * (point_x - plane_point_x)) +
		(plane_norm_y * (point_y - plane_point_y)) + (plane_norm_z * (point_z - plane_point_z));
	return (if (sign > 0) 1 else (if (sign < 0) -1 else 0));
}

float zapper_beam_width;
vector zapper_particles_trace_callback_origin;
float zapper_particles_trace_callback_beamoffs;
vector zapper_curve_beam_prev_point1;
vector zapper_curve_beam_prev_point2;
float zapper_curve_beam_point_num1;
float zapper_curve_beam_point_num2;
float zapper_curve_beam_offset1;
float zapper_curve_beam_offset2;

void zapper_particles_trace_callback(vector from, vector endpos, vector to) {
    vector o = WarpZone_TransformOrigin(WarpZone_trace_transform, zapper_particles_trace_callback_origin);
    vector rgb = Zapper_BeamRGB(self.team);
    vector end2 = to + self.zapper_offs * 70;
    string tex = "particles/zapper";
    vector d = end2 - o;
    float maxlen = vlen(to - o);
    float t = self.cnt + time;

    if(vlen(d) > maxlen)
        end2 = from + normalize(d) * maxlen;

    vector v = WarpZone_TransformOrigin(WarpZone_trace_transform, view_origin);

    var _alpha = self.alpha;
    rgb *= _alpha;

    Draw_CylindricLine(from, endpos, zapper_beam_width, tex, 0.03, zapper_particles_trace_callback_beamoffs, rgb, _alpha, DRAWFLAG_ADDITIVE, v);
    zapper_particles_trace_callback_beamoffs += 0.03 * vlen(from - endpos) / zapper_beam_width;

    if(self.sv_entnum && !fps_friendly) {
        zapper_curve_beam_prev_point1 = WarpZone_TransformOrigin(WarpZone_trace_transform, zapper_curve_beam_prev_point1);
        zapper_curve_beam_prev_point2 = WarpZone_TransformOrigin(WarpZone_trace_transform, zapper_curve_beam_prev_point2);
        vectorvectors(normalize(d));
        vector rgb2 = GetTeamRGB(self.team) * _alpha;
        vector o1 = v_right *  15 * sin(t * 4.0) + v_up * 15 * cos(t * 4.2);
        vector o2 = v_right * -15 * cos(t * 4.1) + v_up * 15 * sin(t * 4.0);

        vector next_point, warp_normal = '0 0 0';
        float curve_fract, start_warp_sign;
        if (to != endpos) {
            if (trace_fraction < 1 && trace_ent) {
                 warp_normal = trace_ent.warpzone_forward;
                 start_warp_sign = plane_sign(endpos, warp_normal, from);
            }
        }
        float before_warp;
        float curve_parts = 32;
        for (before_warp = 1; zapper_curve_beam_point_num1 <= curve_parts && before_warp; zapper_curve_beam_point_num1++) {
            curve_fract = (1 / curve_parts) * zapper_curve_beam_point_num1;
            next_point = normalize(to - o) * maxlen * curve_fract + (o1 * sin(PI * curve_fract)) + o;
            if (warp_normal != '0 0 0') {
                if (plane_sign(endpos, warp_normal, next_point) != start_warp_sign) {
                    next_point = WarpZoneLib_PlaneAndLineCross(trace_endpos, warp_normal, zapper_curve_beam_prev_point1, next_point - zapper_curve_beam_prev_point1);
                    before_warp = 0;
                }
            }
            Draw_CylindricLine(zapper_curve_beam_prev_point1, next_point, zapper_beam_width, tex, 0.03, zapper_curve_beam_offset1, rgb2, self.alpha, DRAWFLAG_ADDITIVE, v);
            zapper_curve_beam_offset1 += 0.03 * (vlen(zapper_curve_beam_prev_point1 - next_point)) / zapper_beam_width;
            zapper_curve_beam_prev_point1 = next_point;
        }
        for (before_warp = 1; zapper_curve_beam_point_num2 <= curve_parts && before_warp; zapper_curve_beam_point_num2++) {
            curve_fract = (1 / curve_parts) * zapper_curve_beam_point_num2;
            next_point = normalize(to - o) * maxlen * curve_fract + (o2 * sin(PI * curve_fract)) + o;
            if (warp_normal != '0 0 0') {
                if (plane_sign(endpos, warp_normal, next_point) != start_warp_sign) {
                    next_point = WarpZoneLib_PlaneAndLineCross(trace_endpos, warp_normal, zapper_curve_beam_prev_point2, next_point - zapper_curve_beam_prev_point2);
                    before_warp = 0;
                }
            }
            Draw_CylindricLine(zapper_curve_beam_prev_point2, next_point, zapper_beam_width, tex, 0.03, zapper_curve_beam_offset2, rgb2, self.alpha, DRAWFLAG_ADDITIVE, v);
            zapper_curve_beam_offset2 += 0.03 * (vlen(zapper_curve_beam_prev_point2 - next_point)) / zapper_beam_width;
            zapper_curve_beam_prev_point2 = next_point;
        }
        zapper_curve_beam_prev_point1 = WarpZone_UnTransformOrigin(WarpZone_trace_transform, zapper_curve_beam_prev_point1);
        zapper_curve_beam_prev_point2 = WarpZone_UnTransformOrigin(WarpZone_trace_transform, zapper_curve_beam_prev_point2);
    }
}

vector Zapper_GetShotOrigin(void) {
    var org = ReadShotOriginStat(STAT_SHOTORG_VISUAL);

    if(self.zapper_inverted_shotorg)
        org_y = -org_y;

    return org - '5 0 0';
}

void Zapper_Draw(void) {
    vector start, muzzleorg;

    float me = ID_ME;
    float truezapper;

    var first_person = FALSE;

    if(!(time - WarpZone_FixView_lasttime < 0.2 && self.sv_entnum == me && !cvar("chase_active")))
        InterpolateOrigin_Do(); //do interpolation for our beam only if not in warpzone
    self.zapper_end = self.origin;

    zapper_beam_width = 12;
    start = muzzleorg = self.zapper_start;
    vector end1;
    if(self.sv_entnum == me && (truezapper = CVAR(cl_truezapper)) > 0) {
        end1 = (view_origin + view_forward * (vlen(self.zapper_start - self.zapper_end))) * truezapper + (1 - truezapper) * self.zapper_end;
    } else
        end1 = self.zapper_end;
    vector real_start = self.zapper_real_start;

    if(self.sv_entnum == me) if(!CVAR(chase_active)) {
        var zapper_shotorigin = Zapper_GetShotOrigin();
        start = view_origin + view_forward * (zapper_shotorigin_x - 1) + view_right * zapper_shotorigin_y + view_up * zapper_shotorigin_z;
        muzzleorg = view_origin + view_forward * zapper_shotorigin_x + view_right * zapper_shotorigin_y + view_up * zapper_shotorigin_z;
        self.zapper_start = start;
        if (WarpZone_FixView_lastwarp) {
            end1 = self.zapper_end = WarpZone_TransformOrigin(WarpZone_FixView_lastwarp, self.origin);
            real_start = WarpZone_TransformOrigin(WarpZone_FixView_lastwarp, self.zapper_real_start);
        }

        zapper_beam_width = 8;
        first_person = TRUE;
    }

    self.zapper_offs += (randomvec() - self.zapper_offs) * drawframetime * 10;

    zapper_particles_trace_callback_beamoffs = -time * 5;
    zapper_particles_trace_callback_origin = start;
    zapper_curve_beam_prev_point1 = zapper_curve_beam_prev_point2 = self.zapper_start;
    zapper_curve_beam_point_num1 = zapper_curve_beam_point_num2 = 1;
    zapper_curve_beam_offset1 = time * 5;
    zapper_curve_beam_offset2 = time * 5;
    
    var dynlight_org = self.zapper_start;

    if(first_person) using(fps_friendly = TRUE) {
        var s = start + view_forward;
        dynlight_org = s;
        zapper_particles_trace_callback(view_origin + view_right * zapper_shotorigin_y + view_up * zapper_shotorigin_z, s, s);
    }

    R_AddDynamicLight(dynlight_org, 50 * self.alpha, Zapper_BeamRGB(self.team));

    end1 -= normalize(end1 - self.zapper_start);

    WarpZone_TraceTriangle(real_start, self.zapper_start, end1, MOVE_NOMONSTERS, world, zapper_particles_trace_callback);

    pointparticles(rm_particleeffectnum_team("RM_ZAPPER_MUZZLEFLASH", self.team, 2), muzzleorg, end1 - start, frametime * 300);
    if(self.alpha > 0.9)
        pointparticles(rm_particleeffectnum_team("RM_ZAPPER", self.team, 2), trace_endpos, '0 0 0', frametime * 300);
}

void Zapper_Draw_Shield(void) {
    InterpolateOrigin_Do();
    self.zapper_end = self.origin;

    float me = ID_ME;

    if(self.sv_entnum == me && !CVAR(chase_active)) {
        var zapper_shotorigin = Zapper_GetShotOrigin();
        self.zapper_start = view_origin + view_forward * (zapper_shotorigin_x - 1) + view_right * zapper_shotorigin_y + view_up * zapper_shotorigin_z;
        self.zapper_end = self.zapper_start + view_forward * 30;
    }
    
    vector start = self.zapper_start;
    vector end = self.zapper_end;

    string tex = "particles/zapper";
    vector rgb = Zapper_BeamRGB(self.team) * 0.5;

    Draw_CylindricLine(end, start,  12, tex, 0.03, 5 * time, rgb, self.alpha, DRAWFLAG_ADDITIVE, view_origin);

    if(self.alpha < 1)
        return;

    float eff_zap = rm_particleeffectnum_team("RM_ZAPPER", self.team, 2);
    float eff_muz = rm_particleeffectnum_team("RM_ZAPPER_MUZZLEFLASH", self.team, 2);
    float pcount = frametime * 300;

    pointparticles(eff_zap, end, '0 0 0', pcount);
    pointparticles(eff_muz, start, end - start, pcount);
}

void Zapper_Fader_Think(void) {
    self.alpha = approach(self.alpha, 0, frametime * 10);

    if(!self.alpha) {
        remove(self);
        return;
    }

    self.nextthink = time;
}

void Zapper_Fader_Spawn(entity ref) {
    entity e = spawn();
    e.draw = ref.draw;
    e.sv_entnum = ref.sv_entnum;
    e.team = ref.team;
    e.zapper_start = ref.zapper_start;
    e.zapper_real_start = ref.zapper_real_start;
    e.zapper_end = ref.zapper_end;
    e.origin = ref.origin;
    e.cnt = ref.cnt;
    e.alpha = 1;
    e.think = Zapper_Fader_Think;
    e.nextthink = time;
    e.zapper_inverted_shotorg = ref.zapper_inverted_shotorg;
}

.float snd_looping;
void Zapper_Remove(void) {
    Zapper_Fader_Spawn(self);
    sound(self, CHAN_PROJECTILE, "misc/null.wav", VOL_BASE, ATTN_NORM);
}

void Zapper_Read(float t) {
    float sf = ReadByte();

    if(sf & 1) {
        float vol, attn;

        if(sf & 16) {
            vol = 0.2;
            attn = 1.5;
        } else {
            vol = VOL_BASE;
            attn = ATTN_NORM;
        }

        if(t == ENT_CLIENT_ZAPPER_SHIELD) {
            self.draw = Zapper_Draw_Shield;
            sound(self, CHAN_PROJECTILE, "weapons/zapper_shield_loop.wav", 1, attn);
        } else {
            self.draw = Zapper_Draw;
            sound(self, CHAN_PROJECTILE, "weapons/zapper_fly.wav", vol, attn);
        }

        self.entremove = Zapper_Remove;

        if(sf & 32) {
            self.sv_entnum = 0;
            self.team = ReadByte() - 1;
        } else {
            self.sv_entnum = ReadByte();
            self.team = GetPlayerColor(self.sv_entnum - 1);
        }

        self.alpha = 1;
        self.cnt = random() * 1000;

        if(!rm_teamlasers || !self.team)
            self.team = COLOR_TEAM2;

        if(sf & 128)
            self.zapper_inverted_shotorg = TRUE;
    }

    if(sf & 2) {
        self.zapper_start_x = ReadCoord();
        self.zapper_start_y = ReadCoord();
        self.zapper_start_z = ReadCoord();

        if(sf & 32) {
            self.zapper_real_start = self.zapper_start;
        } else {
            self.zapper_real_start_x = ReadCoord();
            self.zapper_real_start_y = ReadCoord();
            self.zapper_real_start_z = ReadCoord();
        }
    }

    if(sf & 4) {
        self.zapper_end_x = ReadCoord();
        self.zapper_end_y = ReadCoord();
        self.zapper_end_z = ReadCoord();
        setorigin(self, self.zapper_end);
        InterpolateOrigin_Note();
    }

    if(sf & 16) {
        InterpolateOrigin_Note();
    }
}


float zapper_lightning_ateam;
void zapper_lightning_trace_callback(vector from, vector endpos, vector to) {
    if(!rm_teamlasers)
        zapper_lightning_ateam = COLOR_TEAM2;

    pointparticles(rm_particleeffectnum_team("RM_HG_PLASMA_SHARD_EXPLODE", zapper_lightning_ateam, 2), to, '0 0 0', 1);
    if(fps_friendly) {
        LightingArc_Segment(from, to, zapper_lightning_ateam);
    } else {
        float seglength, drifts, drifte, branchfactor, branchfactor_add, lcount;

        seglength        = 24;
        drifts           = 0.1;
        drifte           = 0.25;
        branchfactor     = 0;
        branchfactor_add = 0;
        lcount           = CVAR(cl_effects_lightningarc_count);
        
        for(; lcount; --lcount)
            LightingArc_Full(from, to, seglength, drifts, drifte, branchfactor, branchfactor_add, zapper_lightning_ateam);
    }

    pointparticles(particleeffectnum("electro_muzzleflash"), from, normalize(to - from) * 1000, 1);
}

void Zapper_ReadLightning(void) {
    vector from, real_from, to;
    
    zapper_lightning_ateam  = ReadByte();
    from_x = ReadCoord(); from_y = ReadCoord(); from_z = ReadCoord();
    real_from_x = ReadCoord(); real_from_y = ReadCoord(); real_from_z = ReadCoord();
    to_x   = ReadCoord(); to_y   = ReadCoord(); to_z   = ReadCoord();

	WarpZone_TraceTriangle(real_from, from, to, MOVE_NOMONSTERS, world, zapper_lightning_trace_callback);

}
