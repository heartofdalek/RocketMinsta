/*
===========================================================================

  CLIENT WEAPONSYSTEM CODE
  Bring back W_Weaponframe

===========================================================================
*/

#define WEP_CVAR(wepname,name) CVAR(g_balance_##wepname##_##name)
#define WEP_CVAR_PRI(wepname,name) WEP_CVAR(wepname, primary_##name)
#define WEP_CVAR_SEC(wepname,name) WEP_CVAR(wepname, secondary_##name)
#define WEP_CVAR_BOTH(wepname,isprimary,name) (if(isprimary) WEP_CVAR_PRI(wepname, name) else WEP_CVAR_SEC(wepname, name))

float W_WeaponRateFactor()
{
	float t = 1.0 / g_weaponratefactor;

    if(Buffs_Present(self, BUFF_HASTE))
        t *= CVAR(g_buffs_haste_refire_rate);
    
	return t;
}

float W_WeaponRateFactorFor(entity plr) {
    entity o = self;
    self = plr;
    float r = W_WeaponRateFactor();
    self = o;
    return r;
}

void W_SwitchWeapon_Force(entity e, float w)
{
    if(e.weapon) {
        using(self = e)
            weapon_action(self.weapon, WR_LOWER);
    } else if(w) {
        sound(e, CHAN_WEAPON2, "weapons/weapon_switch.wav", VOL_BASE, ATTN_NORM);
    }

	e.cnt = e.switchweapon;
	e.switchweapon = w;
    e.w_inring_fulltime = 0;
    e.w_spread_indicator = -1;
    e.w_spread_indicator2 = -1;

    if((var g = Akimbo_Ghost(e)))
        g.switchweapon = w;
}

void W_SwitchWeapon_OutOfAmmo(entity plr) {
    float best = w_getbestweapon(plr);

    if(!best)
        best = -1;

    if(plr.switchweapon != best)
    if(client_hasweapon(plr, best, TRUE, TRUE))
        W_SwitchWeapon_Force(plr, best);
}

// VorteX: static frame globals
const WFRAME_DONTCHANGE = -1;
const WFRAME_FIRE1 = 0;
const WFRAME_FIRE2 = 1;
const WFRAME_IDLE = 2;
const WFRAME_RELOAD = 3;

.float wframe;

.vector shotorg_visual;
.vector w_viewmodel_offset;

void(float fr, float t, void() func) weapon_thinkf;

vector W_HitPlotUnnormalizedUntransform(vector screenforward, vector screenright, vector screenup, vector v)
{
	vector ret;
	ret_x = screenright * v;
	ret_y = screenup * v;
	ret_z = screenforward * v;
	return ret;
}

vector W_HitPlotNormalizedUntransform(vector org, entity targ, vector screenforward, vector screenright, vector screenup, vector v)
{
	float i, j, k;
	vector mi, ma, thisv, myv, ret;

	myv = W_HitPlotUnnormalizedUntransform(screenforward, screenright, screenup, org);

	// x = 0..1 relative to hitbox; y = 0..1 relative to hitbox; z = distance

	for(i = 0; i < 2; ++i) for(j = 0; j < 2; ++j) for(k = 0; k < 2; ++k)
	{
		thisv = targ.origin;
		if(i) thisv_x += targ.maxs_x; else thisv_x += targ.mins_x;
		if(j) thisv_y += targ.maxs_y; else thisv_y += targ.mins_y;
		if(k) thisv_z += targ.maxs_z; else thisv_z += targ.mins_z;
		thisv = W_HitPlotUnnormalizedUntransform(screenforward, screenright, screenup, thisv);
		if(i || j || k)
		{
			if(mi_x > thisv_x) mi_x = thisv_x; if(ma_x < thisv_x) ma_x = thisv_x;
			if(mi_y > thisv_y) mi_y = thisv_y; if(ma_y < thisv_y) ma_y = thisv_y;
			//if(mi_z > thisv_z) mi_z = thisv_z; if(ma_z < thisv_z) ma_y = thisv_z;
		}
		else
		{
			// first run
			mi = ma = thisv;
		}
	}

	thisv = W_HitPlotUnnormalizedUntransform(screenforward, screenright, screenup, v);
	ret_x = (thisv_x - mi_x) / (ma_x - mi_x);
	ret_y = (thisv_y - mi_y) / (ma_y - mi_y);
	ret_z = thisv_z - myv_z;
	return ret;
}

void W_HitPlotAnalysis(entity player, vector screenforward, vector screenright, vector screenup)
{
	vector hitplot;
	vector org;
	float lag;

	if(player.hitplotfh >= 0)
	{
		lag = ANTILAG_LATENCY(player);
		if(lag < 0.001)
			lag = 0;
		if(clienttype(player) != CLIENTTYPE_REAL)
			lag = 0; // only antilag for clients

		org = player.origin + player.view_ofs;
		traceline_antilag_force(player, org, org + screenforward * MAX_SHOT_DISTANCE, MOVE_NORMAL, player, lag);
		if(trace_ent.flags & FL_CLIENT)
		{
			antilag_takeback(trace_ent, time - lag);
			hitplot = W_HitPlotNormalizedUntransform(org, trace_ent, screenforward, screenright, screenup, trace_endpos);
			antilag_restore(trace_ent);
			fputs(player.hitplotfh, strcat(ftos(hitplot_x), " ", ftos(hitplot_y), " ", ftos(hitplot_z), " ", ftos(player.switchweapon), "\n"));
			//print(strcat(ftos(hitplot_x), " ", ftos(hitplot_y), " ", ftos(hitplot_z), "\n"));
		}
	}
}

vector w_shotorg;
vector w_shotdir;
vector w_shotorg_visual;
vector w_shotdir_visual;

.float strengthsound_next;

// this function calculates w_shotorg and w_shotdir based on the weapon model
// offset, trueaim and antilag, and won't put w_shotorg inside a wall.
// make sure you call makevectors first (FIXME?)
void W_SetupShot_Dir_ProjectileSize_HitMask(entity ent, vector s_forward, vector mi, vector ma, float antilag, float recoil, string snd, float maxdamage, float hitmask)
{
	float nudge = 1; // added to traceline target and subtracted from result
	float _oldsolid;
	vector vecs, dv;

    entity ent_orig = ent;
    ent = Akimbo_Owner(ent);

    if(maxdamage > 0)
        W_Accuracy_RegisterPotentialDamage(ent, ent.weapon, maxdamage);
	W_HitPlotAnalysis(ent, v_forward, v_right, v_up);

	if(ent_orig.weaponentity.movedir_x > 0)
	{
		vecs = ent_orig.weaponentity.movedir;
		vecs_y = -vecs_y;
	}
	else
		vecs = '0 0 0';

	if(debug_shotorg != '0 0 0')
		vecs = debug_shotorg;

	dv = v_right * vecs_y + v_up * vecs_z;
	w_shotorg = ent.origin + ent.view_ofs + dv;

	// now move the shotorg forward as much as requested if possible
	if(antilag)
		tracebox_antilag(ent, w_shotorg, mi, ma, w_shotorg + v_forward * (vecs_x + nudge), MOVE_NORMAL, ent, 0);
	else
		tracebox(w_shotorg, mi, ma, w_shotorg + v_forward * (vecs_x + nudge), MOVE_NORMAL, ent);
	w_shotorg = trace_endpos - v_forward * nudge;

	if (Akimbo_Active(ent))
		w_shotdir = s_forward;
	else
	{
		vector trueaimpoint;
		var oldmask = ent.dphitcontentsmask;
		ent.dphitcontentsmask = hitmask;

		if(antilag) {
			traceline_antilag(world, ent.origin + ent.view_ofs, ent.origin + ent.view_ofs + s_forward * MAX_SHOT_DISTANCE, MOVE_NORMAL, ent);
			// passing world, because we do NOT want it to touch dphitcontentsmask
		} else {
			WarpZone_TraceLine(ent.origin + ent.view_ofs, ent.origin + ent.view_ofs + s_forward * MAX_SHOT_DISTANCE, MOVE_NOMONSTERS, ent);
		}

		ent.dphitcontentsmask = hitmask | DPCONTENTS_SOLID | DPCONTENTS_BODY | DPCONTENTS_CORPSE;

		//Prevent modification by warp functions
		vector vf, vr, vu;
		vf = v_forward;
		vr = v_right;
		vu = v_up;
		trueaimpoint = WarpZone_UnTransformOrigin(WarpZone_trace_transform, trace_endpos); // warpzone support
		v_forward = vf;
		v_right = vr;
		v_up = vu;
		// calculate the shotdir from the chosen shotorg
		w_shotdir = normalize(trueaimpoint - w_shotorg);
		ent.dphitcontentsmask = oldmask;
	}

	if (antilag)
	{
		if (CVAR(g_antilag) == 1) // switch to "ghost" if not hitting original
		{
			WarpZone_TraceLine(w_shotorg, w_shotorg + w_shotdir * MAX_SHOT_DISTANCE, MOVE_NORMAL, ent);
			if (!trace_ent.takedamage)
			{
				traceline_antilag_force (ent, w_shotorg, w_shotorg + w_shotdir * MAX_SHOT_DISTANCE, MOVE_NORMAL, ent, ANTILAG_LATENCY(ent));
				if (trace_ent.takedamage && trace_ent.classname == "player")
				{
					entity e;
					e = trace_ent;
					WarpZone_TraceLine(w_shotorg, e.origin, MOVE_NORMAL, ent);
					if(trace_ent == e)
						w_shotdir = normalize(trace_ent.origin - w_shotorg);
				}
			}
		}
		else if(CVAR(g_antilag) == 3) // client side hitscan
		{
			if (ent.cursor_trace_ent)                 // client was aiming at someone
			if (ent.cursor_trace_ent != ent)         // just to make sure
			if (ent.cursor_trace_ent.takedamage)      // and that person is killable
			if (ent.cursor_trace_ent.classname == "player") // and actually a player
			{
				// verify that the shot would miss without antilag
				// (avoids an issue where guns would always shoot at their origin)
				WarpZone_TraceLine(w_shotorg, w_shotorg + w_shotdir * MAX_SHOT_DISTANCE, MOVE_NORMAL, ent);
				if (!trace_ent.takedamage)
				{
					// verify that the shot would hit if altered
					WarpZone_TraceLine(w_shotorg, ent.cursor_trace_ent.origin, MOVE_NORMAL, ent);
					if (trace_ent == ent.cursor_trace_ent)
						w_shotdir = normalize(ent.cursor_trace_ent.origin - w_shotorg);
					else
						print("antilag fail\n");
				}
			}
		}
	}

	if (!g_norecoil)
		ent.punchangle_x = recoil * -1;

    ent_orig.weaponentity.punchangle_x = recoil;

	if (snd != "")
	{
		sound (ent, CHAN_WEAPON, snd, VOL_BASE, ATTN_NORM);
	}

	if(ent.items & IT_STRENGTH)
	if(!g_minstagib)
    if(time > self.strengthsound_next) {
		sound (ent, CHAN_AUTO, "weapons/strength_fire.wav", VOL_BASE, ATTN_NORM);
        self.strengthsound_next = time + 0.09;
    }
};

void W_SetHitscanVisuals(entity p, vector end) {
    vector vecs, dv;

    w_shotorg_visual = w_shotorg;
    w_shotdir_visual = w_shotdir;

    if(p.weaponentity.shotorg_visual_x > 0)
    if(CVAR(g_fakeshotorigin)) {
        vecs = p.weaponentity.shotorg_visual;
        vecs_y = -vecs_y;

        dv = v_right * vecs_y + v_up * vecs_z;
        w_shotorg_visual = Akimbo_Owner(p).origin + Akimbo_Owner(p).view_ofs + dv;
        w_shotdir_visual = normalize(end - w_shotorg_visual);
    }
}

#define W_SetupShot_Dir_ProjectileSize(ent,s_forward,mi,ma,antilag,recoil,snd,maxdamage) W_SetupShot_Dir_ProjectileSize_HitMask(ent, s_forward, mi, ma, antilag, recoil, snd, maxdamage, DPCONTENTS_SOLID | DPCONTENTS_BODY | DPCONTENTS_CORPSE)
#define W_SetupShot_ProjectileSize(ent,mi,ma,antilag,recoil,snd,maxdamage) W_SetupShot_Dir_ProjectileSize(ent, v_forward, mi, ma, antilag, recoil, snd, maxdamage)
#define W_SetupShot_ProjectileSize_HitMask(ent,mi,ma,antilag,recoil,snd,maxdamage,hitmask) W_SetupShot_Dir_ProjectileSize_HitMask(ent, v_forward, mi, ma, antilag, recoil, snd, maxdamage, hitmask)
#define W_SetupShot_Dir(ent,s_forward,antilag,recoil,snd,maxdamage) W_SetupShot_Dir_ProjectileSize(ent, s_forward, '0 0 0', '0 0 0', antilag, recoil, snd, maxdamage)
#define W_SetupShot(ent,antilag,recoil,snd,maxdamage) W_SetupShot_ProjectileSize(ent, '0 0 0', '0 0 0', antilag, recoil, snd, maxdamage)
#define W_SetupShot_HitMask(ent,antilag,recoil,snd,maxdamage,hitmask) W_SetupShot_Dir_ProjectileSize_HitMask(ent, v_forward, '0 0 0', '0 0 0', antilag, recoil, snd, maxdamage, hitmask)

void LaserTarget_Think()
{
	entity e;
	vector offset;
	float uselaser;
	uselaser = 0;

	// list of weapons that will use the laser, and the options that enable it
	if(self.owner.laser_on && self.owner.weapon == WEP_ROCKET_LAUNCHER && g_laserguided_missile)
		uselaser = 1;
	// example
	//if(self.owner.weapon == WEP_ELECTRO && CVAR(g_laserguided_electro))
	//	uselaser = 1;



	// if a laser-enabled weapon isn't selected, delete any existing laser and quit
	if(!uselaser)
	{
		// rocket launcher isn't selected, so no laser target.
		if(self.lasertarget != world)
		{
			remove(self.lasertarget);
			self.lasertarget = world;
		}
		return;
	}

	if(!self.lasertarget)
	{
		// we don't have a lasertarget entity, so spawn one
		//bprint("create laser target\n");
		e = self.lasertarget = spawn();
		e.owner = self.owner;			// Its owner is my owner
		e.classname = "laser_target";
		e.movetype = MOVETYPE_NOCLIP;	// don't touch things
		setmodel(e, "models/laser_dot.mdl");	// what it looks like, precision set below
		e.scale = 1.25;				// make it larger
		e.alpha = 0.25;				// transparency
		e.colormod = '255 0 0' * (1/255) * 8;	// change colors
		e.effects = EF_FULLBRIGHT | EF_LOWPRECISION;
		// make it dynamically glow
		// you should avoid over-using this, as it can slow down the player's computer.
		e.glow_color = 251; // red color
		e.glow_size = 12;
	}
	else
		e = self.lasertarget;

	// move the laser dot to where the player is looking

	makevectors(self.owner.v_angle); // set v_forward etc to the direction the player is looking
	offset = '0 0 26' + v_right*3;
	traceline(self.owner.origin + offset, self.owner.origin + offset + v_forward * MAX_SHOT_DISTANCE, FALSE, self); // trace forward until you hit something, like a player or wall
	setorigin(e, trace_endpos + v_forward*8); // move me to where the traceline ended
	if(trace_plane_normal != '0 0 0')
		e.angles = vectoangles(trace_plane_normal);
	else
		e.angles = vectoangles(v_forward);
}

float CL_Weaponentity_CustomizeEntityForClient()
{
    var o = Akimbo_Owner(self.owner);

    if(o != o.clientcamera)
        return FALSE;

	self.viewmodelforclient = o;
    if(other.clientcamera == self.viewmodelforclient)
		self.viewmodelforclient = other;

    self.alpha = Client_CalculateAlpha(o, world);
	return (self.alpha > 0);
}

float CL_ExterioirWeaponentity_CustomizeEntityForClient()
{
    self.alpha = Client_CalculateAlpha(self.owner, other);
    return (self.alpha > 0);
}

.string weaponname;

/*
 * supported formats:
 *
 * 1. simple animated model, muzzle flash handling on h_ model:
 *    h_tuba.dpm, h_tuba.dpm.framegroups - invisible model controlling the animation
 *      tags:
 *        shot = muzzle end (shot origin, also used for muzzle flashes)
 *        shell = casings ejection point (must be on the right hand side of the gun)
 *        weapon = attachment for v_tuba.md3
 *    o_tuba.md3 - third person model (if present)
 *    v_tuba.md3 - first and third person model
 *    g_tuba.md3 - pickup model
 *
 * 2. fully animated model, muzzle flash handling on h_ model:
 *    h_tuba.dpm, h_tuba.dpm.framegroups - animated first person model
 *      tags:
 *        shot = muzzle end (shot origin, also used for muzzle flashes)
 *        shell = casings ejection point (must be on the right hand side of the gun)
 *        handle = corresponding to the origin of v_tuba.md3 (used for muzzle flashes)
 *    o_tuba.md3 or v_tuba.md3 - third person model
 *    g_tuba.md3 - pickup model
 *
 * 3. fully animated model, muzzle flash handling on v_ model:
 *    h_tuba.dpm, h_tuba.dpm.framegroups - animated first person model
 *      tags:
 *        shot = muzzle end (shot origin)
 *        shell = casings ejection point (must be on the right hand side of the gun)
 *    o_tuba.md3 or v_tuba.md3 - third person model
 *      tags:
 *        shot = muzzle end (for muzzle flashes)
 *    g_tuba.md3 - pickup model
 *
 *
 * .iqm models can be used in place of .dpm and .md3 ones
 */

void CL_Weaponentity_Think()
{
	float tb, v_shot_idx;
	self.nextthink = time;
	if (intermission_running)
		self.frame = self.anim_idle_x;
	if (self.owner.weaponentity != self)
	{
		if (self.weaponentity)
			remove(self.weaponentity);
		remove(self);
		return;
	}
	if (self.owner.deadflag != DEAD_NO)
	{
		self.model = "";
		if (self.weaponentity)
			self.weaponentity.model = "";
		return;
	}
	if (self.cnt != self.owner.weapon || self.dmg != self.owner.modelindex || self.deadflag != self.owner.deadflag)
	{
		self.cnt = self.owner.weapon;
		self.dmg = self.owner.modelindex;
		self.deadflag = self.owner.deadflag;

		string animfilename;
		float animfile;
		if (self.owner.weaponname != "")
		{
			// if there is a child entity, hide it until we're sure we use it
			if (self.weaponentity)
				self.weaponentity.model = "";
			setmodel(self, pickfile("models/weapons/v_" + self.owner.weaponname, "iqm", "md3", NULL)); // precision set below
			v_shot_idx = gettagindex(self, "shot"); // used later

			setmodel(self, pickfile("models/weapons/h_" + self.owner.weaponname, "iqm", "dpm", NULL)); // precision set below
			animfilename = pickfile("models/weapons/h_" + self.owner.weaponname, "iqm.animinfo", "dpm.animinfo", NULL);
			animfile = fopen(animfilename, FILE_READ);
			// preset some defaults that work great for renamed zym files (which don't need an animinfo)
			self.anim_fire1       = '0 1 0.01';
			self.anim_fire2       = '1 1 0.01';
			self.anim_idle        = '2 1 0.01';
			self.anim_reload      = '3 1 0.01';
            self.anim_fire1_left  = '4 1 0.01';
            self.anim_fire2_left  = '5 1 0.01';
            self.anim_idle_left   = '6 1 0.01';
            self.anim_reload_left = '7 1 0.01';

			if (animfile >= 0)
			{
				animparseerror = FALSE;
				self.anim_fire1       = animparseline(animfile);
				self.anim_fire2       = animparseline(animfile);
				self.anim_idle        = animparseline(animfile);
				self.anim_reload      = animparseline(animfile);
                self.anim_fire1_left  = animparseline(animfile);
                self.anim_fire2_left  = animparseline(animfile);
                self.anim_idle_left   = animparseline(animfile);
                self.anim_reload_left = animparseline(animfile);
				fclose(animfile);
				if (animparseerror)
					print("Parse error in ", animfilename, ", some player animations are broken\n");
			}

			// if we have a "weapon" tag, let's attach the v_ model to it ("invisible hand" style model)
			// if we don't, this is a "real" animated model
			if(gettagindex(self, "weapon"))
			{
				if (!self.weaponentity)
					self.weaponentity = spawn();
				setmodel(self.weaponentity, pickfile("models/weapons/v_" + self.owner.weaponname, "iqm", "md3")); // precision does not matter
				setattachment(self.weaponentity, self, "weapon");
			}
			else
			{
				if(self.weaponentity)
					remove(self.weaponentity);
				self.weaponentity = world;
			}

			setorigin(self,'0 0 0');
			self.angles = '0 0 0';
			self.frame = 0;
			self.viewmodelforclient = world;

			float idx;
			idx = gettagindex(self, "shot");
			if(idx)
			{
				self.movedir = gettaginfo(self, idx);
			}
			else
			{
				print("WARNING: weapon model ", self.model, " does not support the 'shot' tag, will display shots TOTALLY wrong\n");
				self.movedir = '0 0 0';
			}

			idx = gettagindex(self, "shell");
			if(idx)
			{
				self.spawnorigin = gettaginfo(self, idx);
			}
			else
			{
				print("WARNING: weapon model ", self.model, " does not support the 'shell' tag, will display casings wrong\n");
				self.spawnorigin = self.movedir;
			}

			if(v_shot_idx)
			{
				self.oldorigin = '0 0 0';
			}
			else
			{
				if(self.weaponentity)
					idx = gettagindex(self, "weapon");
				else
					idx = gettagindex(self, "handle");
				if(idx)
				{
					self.oldorigin = self.movedir - gettaginfo(self, idx);
				}
				else
				{
					print("WARNING: weapon model ", self.model, " does not support the 'handle' tag and neither does the v_ model support the 'shot' tag, will display muzzle flashes TOTALLY wrong\n");
					self.oldorigin = '0 0 0'; // there is no way to recover from this
				}
			}

			self.viewmodelforclient = Akimbo_Owner(self.owner);
		}
		else
		{
			self.model = "";
			if(self.weaponentity)
				remove(self.weaponentity);
			self.weaponentity = world;
			self.movedir = '0 0 0';
            self.shotorg_visual = '0 0 0';
			self.spawnorigin = '0 0 0';
			self.oldorigin = '0 0 0';
			self.anim_fire1  = '0 1 0.01';
			self.anim_fire2  = '0 1 0.01';
			self.anim_idle   = '0 1 0.01';
			self.anim_reload = '0 1 0.01';
		}

		self.view_ofs = '0 0 0';

		if(self.movedir_x >= 0)
		{
			vector v0;
			v0 = self.movedir;
            float akimbo_active = Akimbo_Active(self.owner);
			self.movedir = shotorg_adjust(v0, FALSE, FALSE, akimbo_active);
            self.shotorg_visual = shotorg_adjust(v0, FALSE, TRUE, akimbo_active);
			self.view_ofs = self.shotorg_visual - v0;
		}

		self.owner.stat_shotorg = compressShotOrigin(self.movedir);
        self.owner.stat_shotorg_visual = compressShotOrigin(self.shotorg_visual);
		self.movedir = decompressShotOrigin(self.owner.stat_shotorg); // make them match perfectly

		self.spawnorigin += self.view_ofs; // offset the casings origin by the same amount

        var gunpos = Akimbo_GunPosition(self.owner);

        var ofs = stov(cvar_string("sv_weaponmodel_" + get_weaponinfo(self.owner.weapon).netname + "_offset"));
        ofs_y *= switch(gunpos) {
            case 1: -1,
            case 2:  1,
            default: 0
        };

        self.w_viewmodel_offset = self.view_ofs + ofs;

		// reset animstate now
		self.wframe = WFRAME_IDLE;
		setanim(self, self.(if(gunpos == 2 &&
				cvar("sv_weaponmodel_" + get_weaponinfo(self.owner.weapon).netname + "_left_hand_animations"))
				anim_idle_left else anim_idle), TRUE, FALSE, TRUE);
	}

	tb = (self.effects & EF_TELEPORT_BIT);
	self.effects = self.owner.effects & EFMASK_CHEAP;
	self.effects &~= EF_LOWPRECISION;
	self.effects &~= EF_FULLBRIGHT; // can mask team color, so get rid of it
	self.effects &~= EF_TELEPORT_BIT;
	self.effects |= tb;

	if(self.owner.alpha != 0)
		self.alpha = self.owner.alpha;
	else
		self.alpha = 1;

	self.colormap = self.owner.colormap;
	if (self.weaponentity)
	{
		self.weaponentity.effects = self.effects;
		self.weaponentity.alpha = self.alpha;
		self.weaponentity.colormap = self.colormap;
	}

	self.angles = '0 0 0';

    var switchmode = Akimbo_GunPosition(self.owner);

	float f;
	f = 0;
	vector left_hand_correction = '0 0 0';
	if (self.state == WS_RAISE && !intermission_running)
	{
		f = (self.owner.weapon_nextthink - time) * g_weaponratefactor / CVAR(g_balance_weaponswitchdelay);

        if(switchmode == 1)
            self.angles_y = -90 * f * f;
        else if(switchmode == 2) {
			left_hand_correction_x = -20 * f;
            self.angles_y = 90 * f * f;
        } else
            self.angles_x = -90 * f * f;
	}
	else if (self.state == WS_DROP && !intermission_running)
	{
		f = 1 - (self.owner.weapon_nextthink - time) * g_weaponratefactor / CVAR(g_balance_weaponswitchdelay);

        if(switchmode == 1)
            self.angles_y = -90 * f * f;
        else if(switchmode == 2) {
			left_hand_correction_x = -20 * f;
            self.angles_y = 90 * f * f;
        } else
            self.angles_x = -90 * f * f;
	}
	else if (self.state == WS_CLEAR)
	{
		f = 1;
        self.angles_y = -90 * f * f;
        self.angles_x = -90 * f * f;
	}

    if(switchmode == 1)
        self.punchangle_y = self.punchangle_x * -0.25;
    else if(switchmode == 2)
        self.punchangle_y = self.punchangle_x *  0.25;

    self.angles += self.punchangle;
    self.punchangle = self.punchangle * max(0, 1 - frametime * 5);
    setorigin(self, self.w_viewmodel_offset + self.punchangle_x * '-2 0 -1' + left_hand_correction);

	// create or update the lasertarget entity
	LaserTarget_Think();
};

void CL_ExteriorWeaponentity_Think()
{
	float tag_found;
	self.nextthink = time;
	if (self.owner.exteriorweaponentity != self)
	{
		remove(self);
		return;
	}
	if (self.owner.deadflag != DEAD_NO)
	{
		self.model = "";
		return;
	}
	if (self.cnt != self.owner.weapon || self.dmg != self.owner.modelindex || self.deadflag != self.owner.deadflag)
	{
		self.cnt = self.owner.weapon;
		self.dmg = self.owner.modelindex;
		self.deadflag = self.owner.deadflag;

		if (self.owner.weaponname != "") {
            string s = pickfile("models/weapons/o_" + self.owner.weaponname, "iqm", "md3", NULL);
            if(!fexists(s))
                s = pickfile("models/weapons/v_" + self.owner.weaponname, "iqm", "md3", NULL);

			setmodel(self, s); // precision set below
        } else {
			self.model = "";
        }

		float akimbo_weapon = (Akimbo_Active(self.owner) == 2);
		if((tag_found = gettagindex(Akimbo_Owner(self.owner), "tag_weapon")))
		{
			self.tag_index = tag_found;
			self.tag_entity = self.owner;
		}
		else if (akimbo_weapon && CVAR(g_akimbo_use_left_hand)) {
			setattachment(self, Akimbo_Owner(self.owner), "bip01 l hand");
			string per_weapon_angles = cvar_string("g_akimbo_use_left_hand_rotate_" + get_weaponinfo(self.owner.weapon).netname);
			if (per_weapon_angles == "")
				self.angles = CVAR_VEC(g_akimbo_use_left_hand_rotate);
			else
				self.angles = stov(per_weapon_angles);
		} else {
			setattachment(self, Akimbo_Owner(self.owner), "bip01 r hand");
			if (akimbo_weapon)
				setorigin(self, '0 20 0');
		}

		// if that didn't find a tag, hide the exterior weapon model
		if (!self.tag_index)
			self.model = "";

	}
	self.effects = self.owner.effects | EF_LOWPRECISION;
	self.effects = self.effects & EFMASK_CHEAP; // eat performance
	if(self.owner.alpha != 0)
		self.alpha = self.owner.alpha;
	else
		self.alpha = 1;

	self.colormap = self.owner.colormap;
};

// spawning weaponentity for client
void CL_SpawnWeaponentity()
{
	self.weaponentity = spawn();
	self.weaponentity.classname = "weaponentity";
	self.weaponentity.solid = SOLID_NOT;
	self.weaponentity.owner = self;
	setmodel(self.weaponentity, ""); // precision set when changed
	setorigin(self.weaponentity, '0 0 0');
	self.weaponentity.angles = '0 0 0';
	self.weaponentity.viewmodelforclient = Akimbo_Owner(self);
	self.weaponentity.flags = 0;
	self.weaponentity.think = CL_Weaponentity_Think;
	self.weaponentity.customizeentityforclient = CL_Weaponentity_CustomizeEntityForClient;
	self.weaponentity.nextthink = time;

	self.exteriorweaponentity = spawn();
	self.exteriorweaponentity.classname = "exteriorweaponentity";
	self.exteriorweaponentity.solid = SOLID_NOT;
	self.exteriorweaponentity.exteriorweaponentity = self.exteriorweaponentity;
	self.exteriorweaponentity.owner = self;
	setorigin(self.exteriorweaponentity, '0 0 0');
	self.exteriorweaponentity.angles = '0 0 0';
	self.exteriorweaponentity.think = CL_ExteriorWeaponentity_Think;
    self.exteriorweaponentity.customizeentityforclient = CL_ExterioirWeaponentity_CustomizeEntityForClient;
	self.exteriorweaponentity.nextthink = time;

};

.float hasweapon_complain_spam;

float client_hasweapon(entity cl, float wpn, float andammo, float complain) {
    float weaponbit, f;
    entity oldself;

    if(time < cl.hasweapon_complain_spam)
        complain = 0;
    if(complain)
        cl.hasweapon_complain_spam = time + 0.2;

    if(wpn < 0) {
        if(complain) if (clienttype(cl) == CLIENTTYPE_REAL) {
            play2(cl, "weapons/unavailable.wav");
        }
        return FALSE;
    }

    if(wpn < WEP_FIRST || wpn > WEP_LAST) {
        if (complain)
            sprint(cl, "Invalid weapon\n");
        return FALSE;
    }

    weaponbit = W_WeaponBit(wpn);
    if(cl.weapons & weaponbit) {
        if(andammo) {
            if(cl.items & IT_UNLIMITED_WEAPON_AMMO && wpn != WEP_PRYAXE) {
                f = 1;
            } else {
                oldself = self;
                self = cl;
                f = weapon_action(wpn, WR_CHECKAMMO1);
                f = f + weapon_action(wpn, WR_CHECKAMMO2);
                self = oldself;
            }

            if(!f) {
                if(complain)
                if(clienttype(cl) == CLIENTTYPE_REAL) {
                    play2(cl, "weapons/unavailable.wav");
                    sprint(cl, strcat("You don't have any ammo for the ^2", W_Name(wpn), "\n"));
                }
                return FALSE;
            }
        }
        return TRUE;
    }

    if(complain) {
        // DRESK - 3/16/07
        // Report Proper Weapon Status / Modified Weapon Ownership Message
        if(weaponsInMap & weaponbit) {
            sprint(cl, strcat("You do not have the ^2", W_Name(wpn), "\n") );

            if(CVAR(g_showweaponspawns)) {
                entity e;
                string s;

                e = get_weaponinfo(wpn);
                s = e.model2;

                for(e = world; (e = findfloat(e, weapons, weaponbit)); ) {
                    if(e.classname == "droppedweapon")
                        continue;
                    if not(e.flags & FL_ITEM)
                        continue;
                    WaypointSprite_Spawn(
                        s,
                        1, 0,
                        world, e.origin,
                        self, 0,
                        world, enemy,
                        0
                    );
                }
            }
        } else
            sprint(cl, strcat("The ^2", W_Name(wpn), "^7 is ^1NOT AVAILABLE^7 in this map\n") );

        play2(cl, "weapons/unavailable.wav");
    }

    return FALSE;
};

// Weapon subs
void w_clear()
{
    if(Akimbo_Active(self) == 2)
        self.weapon = -1;

	if (self.weapon != -1)
		self.weapon = 0;
	if (self.weaponentity)
	{
		self.weaponentity.state = WS_CLEAR;
		self.weaponentity.effects = 0;
	}
};

void w_ready()
{
	if (self.weaponentity)
		self.weaponentity.state = WS_READY;
	weapon_thinkf(WFRAME_IDLE, 1000000, w_ready);
};

// Setup weapon for client (after this raise frame will be launched)
void weapon_setup(float windex)
{
	entity e;
	e = get_weaponinfo(windex);
	self.items &~= IT_AMMO;
	self.items = self.items | e.items;

	// the two weapon entities will notice this has changed and update their models
	self.weapon = windex;
	self.weaponname = e.mdl;
	self.bulletcounter = 0;
};

// perform weapon to attack (weaponstate and attack_finished check is here)
.float race_penalty;
float weapon_prepareattack(float secondary, float attacktime)
{
    if(self.hg_stealth)
        HG_Cloak_Trigger();
    
    self.buff_stealth_time = time;

    if(!PlayerMayFire(self))
        return FALSE;

    if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
    if(!weapon_action(self.weapon, WR_CHECKAMMO1 + secondary)) {
        if (Akimbo_Active(self) < 2)
            W_SwitchWeapon_OutOfAmmo(self);
        return FALSE;
    }

	if(attacktime >= 0)
	{
		// don't fire if previous attack is not finished
		if (ATTACK_FINISHED(self) > time + frametime * 0.5) 
			return FALSE;
			
		// don't fire while changing weapon
		if (self.weaponentity.state != WS_READY)
			return FALSE;
	}
	self.weaponentity.state = WS_INUSE;

    if(!CVAR(g_spawnshieldmode))
        self.spawnshieldtime = min(self.spawnshieldtime, time); // kill spawn shield when you fire

	// if the weapon hasn't been firing continuously, reset the timer
	if(attacktime >= 0)
	{
		if (ATTACK_FINISHED(self) < time - frametime * 1.5)
		{
			ATTACK_FINISHED(self) = time;
			//dprint("resetting attack finished to ", ftos(time), "\n");
		}
		ATTACK_FINISHED(self) = ATTACK_FINISHED(self) + attacktime * W_WeaponRateFactor();
	}
	self.bulletcounter += 1;
	//dprint("attack finished ", ftos(ATTACK_FINISHED(self)), "\n");
    
	return TRUE;
};

void weapon_thinkf(float fr, float t, void() func)
{
	vector a;
	vector of, or, ou;
	float restartanim;

	if(fr == WFRAME_DONTCHANGE)
	{
		fr = self.weaponentity.wframe;
		restartanim = FALSE;
	}
	else if (fr == WFRAME_IDLE)
		restartanim = FALSE;
	else
		restartanim = TRUE;

	of = v_forward;
	or = v_right;
	ou = v_up;

	if (self.weaponentity)
	{
		self.weaponentity.wframe = fr;

        var lefthand = (
            Akimbo_GunPosition(self) == 2 &&
            cvar("sv_weaponmodel_" + get_weaponinfo(self.weapon).netname + "_left_hand_animations")
        );

		if (fr == WFRAME_IDLE)
			a = self.weaponentity.(if(lefthand) anim_idle_left else anim_idle);
		else if (fr == WFRAME_FIRE1)
			a = self.weaponentity.(if(lefthand) anim_fire1_left else anim_fire1);
		else if (fr == WFRAME_FIRE2)
			a = self.weaponentity.(if(lefthand) anim_fire2_left else anim_fire2);
		else if (fr == WFRAME_RELOAD) {
			a = self.weaponentity.(if(lefthand) anim_reload_left else anim_reload);
        }

		a_z *= g_weaponratefactor;
		setanim(self.weaponentity, a, restartanim == FALSE, restartanim, restartanim);
	}

	v_forward = of;
	v_right = or;
	v_up = ou;

	if(self.weapon_think == w_ready && func != w_ready && self.weaponentity.state == WS_RAISE)
	{
		backtrace("Tried to override initial weapon think function - should this really happen?");
	}

	t *= W_WeaponRateFactor();

	// VorteX: haste can be added here
	if (self.weapon_think == w_ready)
	{
		self.weapon_nextthink = time;
		//dprint("started firing at ", ftos(time), "\n");
	}
	if (self.weapon_nextthink < time - frametime * 1.5 || self.weapon_nextthink > time + frametime * 1.5)
	{
		self.weapon_nextthink = time;
		//dprint("reset weapon animation timer at ", ftos(time), "\n");
	}
	self.weapon_nextthink = self.weapon_nextthink + t;
	self.weapon_think = func;
	//dprint("next ", ftos(self.weapon_nextthink), "\n");

	if (restartanim)
	if (t)
	if (!self.crouch) // shoot anim stands up, this looks bad
	{
		vector anim;
		if (self.weapon == WEP_PRYAXE)
			anim = self.anim_melee; // we dont have standart melee animation...
		else
			anim = self.anim_shoot;
		anim_z = anim_y / t;
		setanim(self, anim, FALSE, TRUE, TRUE);
	}
};

void weapon_boblayer1(float spd, vector org)
{
	// VorteX: haste can be added here
};

vector W_CalculateProjectileVelocity(vector pvelocity, vector mvelocity)
{
	vector mdirection;
	float mspeed;
	float outspeed;
	float nstyle;
	vector outvelocity;

	mvelocity = mvelocity * g_weaponspeedfactor;

	mdirection = normalize(mvelocity);
	mspeed = vlen(mvelocity);

	nstyle = CVAR(g_projectiles_newton_style);
	if(nstyle == 0)
	{
		// absolute velocity
		outvelocity = mvelocity;
	}
	else if(nstyle == 1)
	{
		// true Newtonian projectiles
		outvelocity = pvelocity + mvelocity;
	}
	else if(nstyle == 2)
	{
		// true Newtonian projectiles with automatic aim adjustment
		//
		// solve: |outspeed * mdirection - pvelocity| = mspeed
		// outspeed^2 - 2 * outspeed * (mdirection * pvelocity) + pvelocity^2 - mspeed^2 = 0
		// outspeed = (mdirection * pvelocity) +- sqrt((mdirection * pvelocity)^2 - pvelocity^2 + mspeed^2)
		// PLUS SIGN!
		// not defined?
		// then...
		// pvelocity^2 - (mdirection * pvelocity)^2 > mspeed^2
		// velocity without mdirection component > mspeed
		// fire at smallest possible mspeed that works?
		// |(mdirection * pvelocity) * pvelocity - pvelocity| = mspeed

		vector solution;
		solution = solve_quadratic(1, -2 * (mdirection * pvelocity), pvelocity * pvelocity - mspeed * mspeed);
		if(solution_z)
			outspeed = solution_y; // the larger one
		else
		{
			//outspeed = 0; // slowest possible shot
			outspeed = solution_x; // the real part (that is, the average!)
			//dprint("impossible shot, adjusting\n");
		}

		outspeed = bound(mspeed * CVAR(g_projectiles_newton_style_2_minfactor), outspeed, mspeed * CVAR(g_projectiles_newton_style_2_maxfactor));
		outvelocity = mdirection * outspeed;
	}
	else if(nstyle == 3)
	{
		// pseudo-Newtonian:
		outspeed = mspeed + mdirection * pvelocity;
		outspeed = bound(mspeed * 0.7, outspeed, mspeed * 5.0);
		outvelocity = mdirection * outspeed;
	}
	else if(nstyle == 4)
	{
		// tZorkian:
		outspeed = mspeed + vlen(pvelocity);
		outvelocity = mdirection * outspeed;
	}
	else
		error("g_projectiles_newton_style must be 0 (absolute), 1 (Newtonian), 2 (Newtonian + aimfix), 3 (pseudo Newtonian) or 4 (tZorkian)!");

	return outvelocity;
}

void W_SetupProjectileVelocity(entity missile)
{
    var o = missile.realowner;
    if(!o)
        o = missile.owner;
	if(!o)
		error("Unowned missile");

	missile.velocity = W_CalculateProjectileVelocity(o.velocity, missile.velocity);

    if(!missile.clipgroup && teams_matter)
    if(CVAR(g_player_dont_block_teammates))
    if(CVAR(g_player_dont_block_teammates_projectiles))
    if(!Buffs_Present(o, BUFF_MEDIC))
        missile.clipgroup = o.clipgroup;
}

void W_AttachToShotorg(entity flash, vector offset)
{
	entity xflash;
	flash.owner = self;
	flash.angles_z = random() * 360;

	setattachment(flash, self.weaponentity, "shot");
	setorigin(flash, offset);

	xflash = spawn();
	copyentity(flash, xflash);

	flash.viewmodelforclient = Akimbo_Owner(self);

	if(self.weaponentity.oldorigin_x > 0)
	{
		setattachment(xflash, self.exteriorweaponentity, "");
		setorigin(xflash, self.weaponentity.oldorigin + offset);
	}
	else
	{
		setattachment(xflash, self.exteriorweaponentity, "shot");
	}
}

void W_Reload();

float in_setbuttonfields;

void W_SetButtonFields(entity plr, float swap) {
    if(in_setbuttonfields)
        return;

    plr = Akimbo_Owner(plr);

    if(plr.clientcamera != plr) {
        w_button_primary = w_button_secondary = w_button_null;
        return;
    }

    using(in_setbuttonfields = TRUE) {
        if(g_weaponarena_secondary && plr.w_conv_switch) {
            var pwep = pow(2, plr.switchweapon - 1);

            if(pwep & g_weaponarena_secondary)
                swap = if(swap) FALSE else TRUE; // XXX: qcc miscompiles !swap

            if(swap) {
                w_button_primary = w_button_null;
                w_button_secondary = BUTTON_ATCK;
            } else {
                w_button_primary = BUTTON_ATCK;
                w_button_secondary = w_button_null;
            }

            if(self.BUTTON_ATCK2)
                W_Reload();
        } else {
            if(swap) {
                w_button_primary = BUTTON_ATCK2;
                w_button_secondary = BUTTON_ATCK;
            } else {
                w_button_primary = BUTTON_ATCK;
                w_button_secondary = BUTTON_ATCK2;
            }     
        }
    }
}
