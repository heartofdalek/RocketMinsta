
void W_ThrowSecondary();

void W_GiveWeapon (entity e, float wep, string name)
{
	entity oldself;

	if (!wep)
		return;

    var wb = W_WeaponBit(wep);

    if(g_weaponarena_secondary && !(wb & g_weaponarena) && wep != e.w_secondary) {
        using(self = e)
            W_ThrowSecondary();
        W_SetSecondary(e, wep);
    } else {
        e.weapons |= wb;
    }

	oldself = self;
	self = e;

	if not(g_minstagib)
	if (other.classname == "player")
	{
		sprint (other, "You got the ^2");
		sprint (other, name);
		sprint (other, "\n");
	}

	self = oldself;
}

float FireRailgunBullet_trace_deathtype;
void FireRailgunBullet_trace_callback(vector from, vector end, vector to) {
    vector dir;
    float length;
    vector beampos;
    float f;
    string snd;
    length = vlen(to - from);
    dir = normalize(to - from);
    entity pseudoprojectile;
    // Find all non-hit players the beam passed close by
    if(FireRailgunBullet_trace_deathtype == WEP_MINSTANEX || DEATH_ISWEAPON(FireRailgunBullet_trace_deathtype, WEP_NEX)) {
        FOR_EACH_REALCLIENT(msg_entity)  // we use realclient, so spectators can hear the whoosh too
        if(msg_entity.clientcamera != self)
        if(!msg_entity.tracerail_hit) {
            // nearest point on the beam
            beampos = from + dir * bound(0, (msg_entity.origin - from) * dir, length);

            f = bound(0, 1 - vlen(beampos - msg_entity.origin) / 512, 1);
            if(f <= 0)
                continue;

            snd = strcat("weapons/nexwhoosh", ftos(floor(random() * 3) + 1), ".wav");

            if(!pseudoprojectile)
                pseudoprojectile = spawn(); // we need this so the sound uses the "entchannel4" volume
            soundtoat(MSG_ONE, pseudoprojectile, beampos, CHAN_PROJECTILE, snd, VOL_BASE * f, ATTN_NONE);
        }

        if(pseudoprojectile)
            remove(pseudoprojectile);
    }

}

void FireRailgunBullet(vector start, vector end, float bdamage, float bforce, float mindist, float maxdist, float halflifedist, float forcehalflifedist, float deathtype) {
    vector hitloc, endpoint;
    entity ent, endent;
    float endq3surfaceflags;
    entity hitents;
    float f;

    entity oldself = self;
    self = Akimbo_Owner(self);

    railgun_start = start;
    railgun_end = end;

    // go a little bit into the wall because we need to hit this wall later
    //end = end + dir;

    FireRailgunBullet_trace_deathtype = deathtype;
    hitents = tracerail_antilag(self, start, end, FALSE, self, FireRailgunBullet_trace_callback);

    endpoint = trace_endpos;
    endent = trace_ent;
    endq3surfaceflags = trace_dphitq3surfaceflags;

    W_Accuracy_RegisterShot(self, self.weapon);

    // find all the entities the railgun hit and hurt them
    for(ent = hitents; ent; ent = ent.tracerail_next) {
        W_Accuracy_RegisterHit(self, ent, self.weapon);

        hitloc = ent.tracerail_endpos;

        float tdamage = bdamage;
        vector tforce = bforce * ent.tracerail_dir;

        float dst = vlen(end - start) * ent.tracerail_fraction;

        tdamage = tdamage * ExponentialFalloff(mindist, maxdist, halflifedist, dst);
        tforce = tforce * ExponentialFalloff(mindist, maxdist, forcehalflifedist, dst);

        if(DEATH_ISWEAPON(deathtype, WEP_NEX)) {
            float maxdst;

            if(deathtype & HITTYPE_SECONDARY)
                maxdst = CVAR(g_balance_nex_secondary_damagefalloff_linear_maxdist);
            else
                maxdst = CVAR(g_balance_nex_damagefalloff_linear_maxdist);

            if(maxdst) {
                float steps, mindmgfactor, minfrcfactor, flr;

                if(deathtype & HITTYPE_SECONDARY) {
                    steps = CVAR(g_balance_nex_secondary_damagefalloff_linear_steps) - 1;
                    mindmgfactor = CVAR(g_balance_nex_secondary_damagefalloff_linear_mindamagefactor);
                    minfrcfactor = CVAR(g_balance_nex_secondary_damagefalloff_linear_minforcefactor);
                    flr = CVAR(g_balance_nex_secondary_damagefalloff_linear_floor);
                } else {
                    steps = CVAR(g_balance_nex_damagefalloff_linear_steps) - 1;
                    mindmgfactor = CVAR(g_balance_nex_damagefalloff_linear_mindamagefactor);
                    minfrcfactor = CVAR(g_balance_nex_damagefalloff_linear_minforcefactor);
                    flr = CVAR(g_balance_nex_damagefalloff_linear_floor);
                }

                f = min(dst, maxdst) / maxdst;

                if(steps > 0)
                    f = floor(steps * f) / steps;

                tdamage = tdamage * mindmgfactor + tdamage * (1 - mindmgfactor) * f;
                tforce = tforce * minfrcfactor + tforce * (1 - minfrcfactor) * f;

                if(flr)
                    tdamage = floor(tdamage);
            }
        }

        // apply the damage
        if(ent.takedamage)
            Damage(ent, self, self, tdamage, deathtype, hitloc, tforce);
    }

    tracerail_finalize(hitents);

    trace_endpos = endpoint;
    trace_ent = endent;
    trace_dphitq3surfaceflags = endq3surfaceflags;

    self = oldself;
}

.float dmg_edge;
.float dmg_force;
.float dmg_radius;

void W_BallisticBullet_Hit (void)
{
	float f, fd;
	f = pow(bound(0, vlen(self.velocity) / vlen(self.oldvelocity), 1), 2); // energy multiplier
    
    if(CVAR(g_ballistics_constantdamage))
        fd = 1;
    else
        fd = f;

	if(other.solid == SOLID_BSP)
        Damage_DamageInfo(self.origin, self.dmg * fd, 0, 0, max(1, self.dmg_force) * normalize(self.velocity) * f, self.projectiledeathtype, self);

	if(other && other != self.enemy)
	{
		endzcurveparticles();

		headshot = 0;
		yoda = 0;
		damage_headshotbonus = self.dmg_edge;
		railgun_start = self.origin - 2 * frametime * self.velocity;
		railgun_end = self.origin + 2 * frametime * self.velocity;

		Damage(other, self, self.owner, self.dmg * fd, self.projectiledeathtype, self.origin, self.dmg_force * normalize(self.velocity) * f);
		damage_headshotbonus = 0;

		if(self.dmg_edge != 0)
            CSQCMessage_Praise2(self.owner, headshot, yoda, 0, 0, 0);

        W_Accuracy_RegisterHit(self.owner, other, self.owner.weapon);
	}

	self.enemy = other; // don't hit the same player twice with the same bullet
}

.void(void) W_BallisticBullet_LeaveSolid_think_save;
.float W_BallisticBullet_LeaveSolid_nextthink_save;
.vector W_BallisticBullet_LeaveSolid_origin;
.vector W_BallisticBullet_LeaveSolid_velocity;

void W_BallisticBullet_LeaveSolid_think()
{
	setorigin(self, self.W_BallisticBullet_LeaveSolid_origin);
	self.velocity = self.W_BallisticBullet_LeaveSolid_velocity;

	self.think = self.W_BallisticBullet_LeaveSolid_think_save;
	self.nextthink = max(time, self.W_BallisticBullet_LeaveSolid_nextthink_save);
	self.W_BallisticBullet_LeaveSolid_think_save = SUB_Null;

	self.flags &~= FL_ONGROUND;

	if(self.enemy.solid == SOLID_BSP)
	{
		float f;
		f = pow(bound(0, vlen(self.velocity) / vlen(self.oldvelocity), 1), 2); // energy multiplier
		Damage_DamageInfo(self.origin, 0, 0, 0, max(1, self.dmg_force) * normalize(self.velocity) * -f, self.projectiledeathtype, self);
	}

	UpdateCSQCProjectile(self);
}

float W_BallisticBullet_LeaveSolid(entity e, vector vel, float constant)
{
	// move the entity along its velocity until it's out of solid, then let it resume

	float dt, dst, velfactor, v0, vs;
	float maxdist;
	float E0_m, Es_m;
	
	// outside the world? forget it
	if(self.origin_x > world.maxs_x || self.origin_y > world.maxs_y || self.origin_z > world.maxs_z || self.origin_x < world.mins_x || self.origin_y < world.mins_y || self.origin_z < world.mins_z)
		return 0;

	// E(s) = E0 - constant * s, constant = area of bullet circle * material constant / mass
	v0 = vlen(vel);

	E0_m = 0.5 * v0 * v0;
	maxdist = E0_m / constant;
	// maxdist = 0.5 * v0 * v0 / constant
	// dprint("max dist = ", ftos(maxdist), "\n");

	if(maxdist <= CVAR(g_ballistics_mindistance))
		return 0;
    
	traceline_inverted (self.origin, self.origin + normalize(vel) * maxdist, MOVE_NORMAL, self);
    
	if(!CVAR(g_ballistics_gothroughsolid) && (!trace_ent || trace_ent.solid == SOLID_BSP && (trace_dphitcontents & DPCONTENTS_OPAQUE || trace_dphittexturename == "textures/common/weapclip")))
		return 0;

	if(trace_fraction == 1) // 1: we never got out of solid
		return 0;

	self.W_BallisticBullet_LeaveSolid_origin = trace_endpos;

	dst = vlen(trace_endpos - self.origin);
	// E(s) = E0 - constant * s, constant = area of bullet circle * material constant / mass
	Es_m = E0_m - constant * dst;
	if(Es_m <= 0)
	{
		// roundoff errors got us
		return 0;
	}
	vs = sqrt(2 * Es_m);
	velfactor = vs / v0;

	dt = dst / (0.5 * (v0 + vs));
	// this is not correct, but the differential equations have no analytic
	// solution - and these times are very small anyway
	//print("dt = ", ftos(dt), "\n");

	self.W_BallisticBullet_LeaveSolid_think_save = self.think;
	self.W_BallisticBullet_LeaveSolid_nextthink_save = self.nextthink;
	self.think = W_BallisticBullet_LeaveSolid_think;
	self.nextthink = time + dt;

	vel = vel * velfactor;

	self.velocity = '0 0 0';
	self.flags |= FL_ONGROUND; // prevent moving
	self.W_BallisticBullet_LeaveSolid_velocity = vel;

	return 1;
}

void W_BallisticBullet_Touch (void)
{
	if(self.think == W_BallisticBullet_LeaveSolid_think) // skip this!
		return;
	PROJECTILE_TOUCH;
	W_BallisticBullet_Hit ();

	// go through solid!
	if(!W_BallisticBullet_LeaveSolid(self, self.velocity, self.dmg_radius))
	{
		remove(self);
		return;
	}
	
	self.projectiledeathtype |= HITTYPE_BOUNCE;
}

void endFireBallisticBullet()
{
	endzcurveparticles();
}

void fireHitscanBullet(vector start, vector dir, float spread, float damage, float headshotbonus, float force, float dtype, float tracereffects) {
    vector end;
    float eff;
    entity oldself = self;
    self = Akimbo_Owner(self);

    dir = normalize(dir + randomvec() * spread);
    end = start + dir * MAX_SHOT_DISTANCE;
    
    damage_headshotbonus = headshotbonus;
    headshot = yoda = 0;
    FireRailgunBullet(start, end, damage, force, 0, 0, 0, 0, dtype);
    damage_headshotbonus = 0;
    end =  trace_endpos;
    vector end_visual = end;
    if (WarpZone_trace_transform) {
        vector of = v_forward, or = v_right, ou = v_up;
        end_visual = WarpZone_UnTransformOrigin(WarpZone_trace_transform, end_visual);
        v_forward = of; v_right = or; v_up = ou;
    }

    CSQCMessage_Praise2(self, headshot, yoda, 0, 0, 0);

    if(tracereffects & EF_RED)
        eff = particleeffectnum("tr_rifle");
    else
        eff = particleeffectnum("tr_bullet");

    W_SetHitscanVisuals(oldself, end_visual);
    WarpZone_TrailParticles(world, eff, w_shotorg, w_shotorg_visual, end_visual);

    if(Buffs_Present(self, BUFF_MEDIC))
        WarpZone_TrailParticles(world, particleeffectnum("RM_HEAL_TRAIL"), w_shotorg, w_shotorg_visual, end_visual);

    Damage_DamageInfo(end, damage, 0, 0, WarpZone_trace_dir * max(1, force), dtype, self);
    self = oldself;
}

entity fireBallisticBullet_trace_callback_ent;
float fireBallisticBullet_trace_callback_eff;
void fireBallisticBullet_trace_callback(vector start, vector hit, vector end)
{
	if(vlen(trace_endpos - fireBallisticBullet_trace_callback_ent.origin) > 16)
		zcurveparticles_from_tracetoss(fireBallisticBullet_trace_callback_eff, fireBallisticBullet_trace_callback_ent.origin, trace_endpos, fireBallisticBullet_trace_callback_ent.velocity);
}

void fireBallisticBullet(vector start, vector dir, float spread, float pSpeed, float lifetime, float damage, float headshotbonus, float force, float dtype, float tracereffects, float gravityfactor, float bulletconstant)
{
	float lag, dt, savetime;
	entity pl, oldself;
    
    if(CVAR(g_ballistics_simplehitscan)) {
        fireHitscanBullet(start, dir, spread, damage, headshotbonus, force, dtype, tracereffects);
        return;
    }

    entity oldself_akimbo = self;
    self = Akimbo_Owner(self);

    // used only for muzzleflashes later
    W_SetHitscanVisuals(self, w_shotorg + dir);

	entity proj;
	proj = spawn();
	proj.classname = "bullet";
	proj.owner = self;
	PROJECTILE_MAKETRIGGER(proj);
	if(gravityfactor > 0)
	{
		proj.movetype = MOVETYPE_TOSS;
		proj.gravity = gravityfactor;
	}
	else
		proj.movetype = MOVETYPE_FLY;
	proj.think = SUB_Remove;
	proj.nextthink = time + lifetime; // min(pLifetime, vlen(world.maxs - world.mins) / pSpeed);
	proj.velocity = (dir + randomvec() * spread) * pSpeed;
	W_SetupProjectileVelocity(proj);
	proj.angles = vectoangles(proj.velocity);
	proj.dmg_radius = CVAR(g_ballistics_materialconstant) / bulletconstant;
	// so: bulletconstant = bullet mass / area of bullet circle
	setorigin(proj, start);
	proj.flags = FL_PROJECTILE;

	proj.touch = W_BallisticBullet_Touch;
	proj.dmg = damage;
	proj.dmg_edge = headshotbonus;
	proj.dmg_force = force;
	proj.projectiledeathtype = dtype;
    
	proj.oldvelocity = proj.velocity;
    
    W_Accuracy_RegisterShot(self, self.weapon);

	if(CVAR(g_antilag_bullets))
	if(pSpeed >= CVAR(g_antilag_bullets))
	{
		float eff;
        ExactHitscan_Begin();

		if(tracereffects & EF_RED)
			eff = particleeffectnum("tr_rifle");
		else
			eff = particleeffectnum("tr_bullet");

		// NOTE: this may severely throw off weapon balance
		lag = ANTILAG_LATENCY(self);
		if(lag < 0.001)
			lag = 0;
		if(clienttype(self) != CLIENTTYPE_REAL)
			lag = 0;
		if(CVAR(g_antilag) == 0)
			lag = 0; // only do hitscan, but no antilag

		if(lag)
			FOR_EACH_PLAYER(pl)
				antilag_takeback(pl, time - lag);

		oldself = self;
		self = proj;

		savetime = frametime;
		frametime = 0.05;
        
		for(;;)
		{
			fireBallisticBullet_trace_callback_ent = self;
			fireBallisticBullet_trace_callback_eff = eff;
			WarpZone_TraceToss_ThroughZone(self, oldself, 0.125 * 0.05, 200, world, fireBallisticBullet_trace_callback);

			if(trace_fraction == 1)
				break;
				// won't hit anything anytime soon (DP's
				// tracetoss does 200 tics of, here,
				// 0.05*0.125s, that is, 1.25 seconds

			other = trace_ent;
			dt = vlen(trace_endpos - self.origin) / vlen(self.velocity); // this is only approximate!
			setorigin(self, trace_endpos);
			self.velocity = WarpZone_tracetoss_velocity;
            
			if(!SUB_OwnerCheck())
			{
				if(SUB_NoImpactCheck())
					break;

				// hit the player
				W_BallisticBullet_Hit ();
			}

			// go through solid!
			if(!W_BallisticBullet_LeaveSolid(self, self.velocity, self.dmg_radius))
				break;

			W_BallisticBullet_LeaveSolid_think();
		}
		frametime = savetime;
		self = oldself;

		if(lag)
			FOR_EACH_PLAYER(pl)
				antilag_restore(pl);

		remove(proj);

        ExactHitscan_End();
        self = oldself_akimbo;
		return;
	}

	if(tracereffects & EF_RED)
		CSQCProjectile(proj, TRUE, PROJECTILE_BULLET_GLOWING, TRUE);
	else
		CSQCProjectile(proj, TRUE, PROJECTILE_BULLET, TRUE);

    self = oldself_akimbo;
}


void W_PrepareExplosionByDamage(entity attacker, void() explode)
{
	self.takedamage = DAMAGE_NO;
	self.event_damage = SUB_Null;
	self.owner = attacker;

	// do not explode NOW but in the NEXT FRAME!
	// because recursive calls to RadiusDamage are not allowed
	self.nextthink = time;
	self.think = explode;
}
