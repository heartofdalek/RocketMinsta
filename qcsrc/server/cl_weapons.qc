
void W_Reload()
{
	if(self.switchweapon == self.weapon)
	if(self.weaponentity.state == WS_READY)
		weapon_action(self.weapon, WR_RELOAD);

    entity oldself = self;
    self = Akimbo_Ghost(self);
    if (self)
    if (self != oldself)
        W_Reload();
    self = oldself;
}

float W_ToggleSecondary(void) {
    if(g_weaponarena_secondary && self.w_conv_switch) {
        var w = pow(2, self.switchweapon - 1) | pow(2, self.weapon - 1);
        var hasweapon = (self.switchweapon || self.weapon);
        var secondary = W_WeaponBit(self.w_secondary);

        if(w & secondary || !hasweapon) {
            self.weapons &~= secondary;
            self.weapons |= g_weaponarena;
            W_SwitchWeapon_Force(self, log2of(g_weaponarena) + 1);
            return TRUE;
        } else if(w & g_weaponarena) {
            self.weapons &~= g_weaponarena;
            self.weapons |= secondary;
            W_SwitchWeapon_Force(self, log2of(secondary) + 1);
            return TRUE;
        }
    }

    return FALSE;
}

// switch between weapons
void W_SwitchWeapon(float imp)
{
    if(W_ToggleSecondary())
        return;

	if (self.switchweapon != imp)
	{
		if (client_hasweapon(self, imp, TRUE, TRUE))
			W_SwitchWeapon_Force(self, imp);
	}
	else
	{
		W_Reload();
	}
}

void W_SwitchWeapon_Silent(float imp) {
    if(self.switchweapon != imp) {
        if(client_hasweapon(self, imp, TRUE, FALSE))
            W_SwitchWeapon_Force(self, imp);
    }
}

.float weaponcomplainindex;
float W_GetCycleWeapon(entity pl, string weaponorder, float dir, float imp, float complain)
{
	float n, i, weaponwant, first_valid, prev_valid, switchtonext, switchtolast, c;
	n = tokenize_console(weaponorder);
	switchtonext = switchtolast = 0;
	first_valid = prev_valid = 0;

	if(dir == 0)
		switchtonext = 1;

	c = 0;

	for(i = 0; i < n; ++i)
	{
		weaponwant = stof(argv(i));
		if(imp >= 0)
			if((get_weaponinfo(weaponwant)).impulse != imp)
				continue;

		++c;

		if(client_hasweapon(pl, weaponwant, TRUE, FALSE))
		{
			if(switchtonext)
				return weaponwant;
			if(!first_valid)
				first_valid = weaponwant;
			if(weaponwant == pl.switchweapon)
			{
				if(dir >= 0)
					switchtonext = 1;
				else if(prev_valid)
					return prev_valid;
				else
					switchtolast = 1;
			}
			prev_valid = weaponwant;
		}
	}
	if(first_valid)
	{
		if(switchtolast)
			return prev_valid;
		else
			return first_valid;
	}
	// complain (but only for one weapon on the button that has been pressed)
	if(complain)
	{
		self.weaponcomplainindex += 1;
		c = mod(self.weaponcomplainindex, c) + 1;
		for(i = 0; i < n; ++i)
		{
			weaponwant = stof(argv(i));
			if(imp >= 0)
				if((get_weaponinfo(weaponwant)).impulse != imp)
					continue;

			--c;
			if(c == 0)
			{
				client_hasweapon(pl, weaponwant, TRUE, TRUE);
				break;
			}
		}
	}
	return 0;
}

void W_CycleWeapon(string weaponorder, float dir)
{
    if(W_ToggleSecondary())
        return;

	float w;
	w = W_GetCycleWeapon(self, weaponorder, dir, -1, 1);
	if(w > 0)
		W_SwitchWeapon(w);
}

void W_NextWeaponOnImpulse(float imp)
{
    if(W_ToggleSecondary())
        return;

	float w;
	w = W_GetCycleWeapon(self, self.cvar_cl_weaponpriority, +1, imp, 1);
	if(w > 0)
		W_SwitchWeapon(w);
}

// next weapon
void W_NextWeapon(float list)
{
	if(list == 0)
		W_CycleWeapon(weaponpriority_hudselector_0, -1);
	else if(list == 1)
		W_CycleWeapon(weaponpriority_hudselector_1, -1);
	else if(list == 2)
		W_CycleWeapon(self.cvar_cl_weaponpriority, -1);
}

// prev weapon
void W_PreviousWeapon(float list)
{
	if(list == 0)
		W_CycleWeapon(weaponpriority_hudselector_0, +1);
	else if(list == 1)
		W_CycleWeapon(weaponpriority_hudselector_1, +1);
	else if(list == 2)
		W_CycleWeapon(self.cvar_cl_weaponpriority, +1);
}

string W_FixWeaponOrder_AllowIncomplete(string order)
{
	return W_FixWeaponOrder(order, 0);
}

string W_FixWeaponOrder_ForceComplete(string order)
{
	if(order == "")
		order = CVAR_STR(cl_weaponpriority);
	return W_FixWeaponOrder(order, 1);
}

float w_getbestweapon(entity e)
{
	return W_GetCycleWeapon(e, e.cvar_cl_weaponpriority, 0, -1, 0);
};

// generic weapons table
// TODO should they be macros instead?
float weapon_action(float wpn, float wrequest)
{
	return (get_weaponinfo(wpn)).weapon_func(wrequest);
};

void weapon_precache(float wpn) {
	string s = get_weaponinfo(wpn).mdl, f;
    var cb = inline void(string s) { precache_model(s); };
    do_if_fexists(cb, pickfile("models/weapons/g_" + s, "iqm", "md3", NULL));
    do_if_fexists(cb, pickfile("models/weapons/v_" + s, "iqm", "md3", NULL));
    do_if_fexists(cb, pickfile("models/weapons/o_" + s, "iqm", "md3", NULL));
    do_if_fexists(cb, pickfile("models/weapons/h_" + s, "iqm", "dpm", NULL));
	(get_weaponinfo(wpn)).weapon_func(WR_PRECACHE);
};

string W_Name(float weaponid)
{
	return (get_weaponinfo(weaponid)).message;
}

float W_WeaponBit(float wpn)
{
	return (get_weaponinfo(wpn)).weapons;
}

float W_AmmoItemCode(float wpn)
{
	return (get_weaponinfo(wpn)).items;
}

void thrown_wep_think()
{
	self.solid = SOLID_TRIGGER;
	self.owner = world;

    var st = CVAR(g_thrownweapon_staytime);

    if(st > 0)
	   SUB_SetFade(self, time + st, 1);
}

// returns amount of ammo used as string, or -1 for failure, or 0 for no ammo count
string W_ThrowNewWeapon(entity own, float wpn, float doreduce, vector org, vector velo)
{
	entity oldself, wep;
	float wa, thisammo, i, j;
	string s;
	var .float ammofield;

	wep = spawn();

	setorigin(wep, org);
	wep.classname = "droppedweapon";
	wep.velocity = velo;
	wep.owner = wep.enemy = own;
	wep.flags |= FL_TOSSED;
	wep.colormap = own.colormap;

	wa = W_AmmoItemCode(wpn);
	if(wa == IT_SUPERWEAPON || wa == 0)
	{
		oldself = self;
		self = wep;
		weapon_defaultspawnfunc(wpn);
		self = oldself;
		if(startitem_failed)
			return NULL;
		wep.think = thrown_wep_think;
		wep.nextthink = time + CVAR(g_thrownweapon_pickupdelay);
		return "";
	}
	else
	{
		s = "";
		oldself = self;
		self = wep;
		weapon_defaultspawnfunc(wpn);
		self = oldself;
		if(startitem_failed)
			return NULL;
		if(doreduce)
		{
			for(i = 0, j = 1; i < 24; ++i, j *= 2)
			{
				if(wa & j)
				{
					ammofield = Item_CounterField(j);
					thisammo = min(own.ammofield, wep.ammofield);
					wep.ammofield = thisammo;
					own.ammofield -= thisammo;
					s = strcat(s, " and ", ftos(thisammo), " ", Item_CounterFieldName(j));
				}
			}
			s = substring(s, 5, -1);
		}
		wep.think = thrown_wep_think;
		wep.nextthink = time + CVAR(g_thrownweapon_pickupdelay);
		return s;
	}
}

float W_IsWeaponThrowable(float w)
{
	float wb, wa;
	wb = W_WeaponBit(w);
	if(!wb)
		return 0;
	wa = W_AmmoItemCode(w);
	if(start_weapons & wb)
	{
		if(wa == IT_SUPERWEAPON && start_items & IT_UNLIMITED_SUPERWEAPONS)
			return 0;
		if(wa != IT_SUPERWEAPON && start_items & IT_UNLIMITED_WEAPON_AMMO)
			return 0;
		// start weapons that take no ammo can't be dropped (this prevents dropping the laser, as long as it continues to use no ammo)
		if(wa == 0)
			return 0;
	}

	return 1;
}

// toss current weapon
void W_ThrowWeapon(vector velo, vector delta, float doreduce)
{
	float w, wb;
	string a;

	w = self.weapon;
	if (w == 0)
		return; // just in case
	if (g_weaponarena && !g_weaponarena_limitammo)
		return;
	if (g_lms)
		return;
	if (g_nixnex)
		return;
	if (g_nexball && w == WEP_GRENADE_LAUNCHER)
		return;
	if (!CVAR(g_pickup_items))
		return;
	if(!W_IsWeaponThrowable(w))
		return;

	wb = W_WeaponBit(w);
	if(self.weapons & wb != wb)
		return;

	self.weapons &~= wb;
	W_SwitchWeapon_Force(self, w_getbestweapon(self));
	a = W_ThrowNewWeapon(self, w, doreduce, self.origin + delta, velo);
	if not(a)
		return;
	if(self.health >= 1)
	{
		if(a == "")
			sprint(self, strcat("You dropped the ^2", W_Name(w), "\n"));
		else
			sprint(self, strcat("You dropped the ^2", W_Name(w), " with ", a, "\n"));
	}
};

void W_UpdateSecondaryWeaponStatus(entity p) {
    if(!p.scorekeeper)
        return;

    var s = p.scorekeeper.(scores[SP_STATUSICONS]) & 0xFFFF00FF;
    var w = p.w_secondary & 0x7F;

    if(Akimbo_HaveWeapon(p, w))
        w += 0x80;

    PlayerScore_Set(p, SP_STATUSICONS, s + (w * 0x100) & 0x0000FF00);
}

void W_ThrowSecondary_Once(void) {
    var org = self.origin + (self.mins + self.maxs) * 0.5;
    W_ThrowNewWeapon(self, self.w_secondary, FALSE, org, randomvec() * 125 + '0 0 200');
}

.float akimbo_weapons;

void W_ThrowSecondary(void) {
    if(!self.w_secondary)
        return;

    W_ThrowSecondary_Once();

    if(Akimbo_HaveWeapon(self, self.w_secondary)) {
        self.akimbo_weapons &~= W_WeaponBit(self.w_secondary);
        W_UpdateSecondaryWeaponStatus(self);
        W_ThrowSecondary_Once();
    }
}

.float w_instaswitch;
// Bringed back weapon frame
void W_WeaponFrame()
{
	vector fo, ri, up;

	if((arena_roundbased && time < warmup) || (time < game_starttime && !CVAR(sv_ready_restart_after_countdown)))
		return;

	if (!self.weaponentity || self.health < 1)
		return; // Dead player can't use weapons and injure impulse commands

	if(!self.switchweapon)
	{
		self.weapon = 0;
		self.weaponentity.state = WS_CLEAR;
		self.weaponname = "";
		self.items &~= IT_AMMO;
		return;
	}

	makevectors(self.v_angle);
	fo = v_forward; // save them in case the weapon think functions change it
	ri = v_right;
	up = v_up;

	// Change weapon
	if (self.weapon != self.switchweapon)
	{
        float r = CVAR(g_balance_weaponswitchdelay);
        if(self.w_instaswitch) {
            self.w_instaswitch = FALSE;
            r = 0;
        }

        if (!r) {
            if (Akimbo_Active(self) > 1)
            if not(Akimbo_HaveWeapon(self, self.switchweapon))
                return;
            weapon_action(self.weapon, WR_CLEAR);
            weapon_action(self.switchweapon, WR_SETUP);
            weapon_thinkf(WFRAME_IDLE, 0, w_ready);
            weapon_boblayer1(PLAYER_WEAPONSELECTION_SPEED, '0 0 0');
        }
		else if (self.weaponentity.state == WS_CLEAR)
		{
			setanim(self, self.anim_draw, FALSE, TRUE, TRUE);
			self.weaponentity.state = WS_RAISE;
            weapon_action(self.weapon, WR_CLEAR);
			weapon_action(self.switchweapon, WR_SETUP);
			// VorteX: add player model weapon select frame here
			// setcustomframe(PlayerWeaponRaise);
			weapon_thinkf(WFRAME_IDLE, r, w_ready);
			weapon_boblayer1(PLAYER_WEAPONSELECTION_SPEED, '0 0 0');
		}
		else if (self.weaponentity.state == WS_READY)
		{
#ifndef INDEPENDENT_ATTACK_FINISHED
			if(ATTACK_FINISHED(self) <= time + frametime * 0.5)
			{
#endif
			// UGLY WORKAROUND: play this on CHAN_WEAPON2 so it can't cut off fire sounds
			sound (self, CHAN_WEAPON2, "weapons/weapon_switch.wav", VOL_BASE, ATTN_NORM);
			self.weaponentity.state = WS_DROP;
			// set up weapon switch think in the future, and start drop anim
			weapon_thinkf(WFRAME_DONTCHANGE, CVAR(g_balance_weaponswitchdelay), w_clear);
			weapon_boblayer1(PLAYER_WEAPONSELECTION_SPEED, PLAYER_WEAPONSELECTION_RANGE);
#ifndef INDEPENDENT_ATTACK_FINISHED
			}
#endif
		}
	}

	float wb;
	wb = W_WeaponBit(self.weapon);

	// call the think code which may fire the weapon
	// and do so multiple times to resolve framerate dependency issues if the
	// server framerate is very low and the weapon fire rate very high
	float c;
	c = 0;
	while (c < 5)
	{
		c = c + 1;
		if(wb && ((self.weapons & wb) == 0))
		{
			W_SwitchWeapon_Force(self, w_getbestweapon(self));
			wb = 0;
		}
		if(wb)
		{
			v_forward = fo;
			v_right = ri;
			v_up = up;
			weapon_action(self.weapon, WR_THINK);
		}
		if (time + frametime * 0.5 >= self.weapon_nextthink)
		{
			if(self.weapon_think)
			{
				v_forward = fo;
				v_right = ri;
				v_up = up;
				self.weapon_think();
			}
			else
				bprint("\{1}^1ERROR: undefined weapon think function for ", self.netname, "\n");
		}
	}
};

float nixnex_weapon;
float nixnex_weapon_ammo;
float nixnex_nextchange;
float nixnex_nextweapon;
float nixnex_nextweapon_ammo;
.float nixnex_lastchange_id;
.float nixnex_lastinfotime;
.float nixnex_nextincr;

float NixNex_CanChooseWeapon(float wpn)
{
	entity e;
	e = get_weaponinfo(wpn);
	if(!e.weapons) // skip dummies
		return FALSE;
	if(g_weaponarena)
	{
		if not(g_weaponarena & e.weapons)
			return FALSE;
	}
	else
	{
		if(wpn == WEP_LASER && g_nixnex_with_laser)
			return FALSE;
		if not(e.spawnflags & WEPSPAWNFLAG_NORMAL)
			return FALSE;
	}
	return TRUE;
}
void Nixnex_ChooseNextWeapon()
{
	float j;
	RandomSelection_Init();
	for(j = WEP_FIRST; j <= WEP_LAST; ++j)
		if(NixNex_CanChooseWeapon(j))
			RandomSelection_Add(world, j, NULL, 1, (j != nixnex_weapon));
	nixnex_nextweapon = RandomSelection_chosen_float;
	nixnex_nextweapon_ammo = W_AmmoItemCode(nixnex_nextweapon);
}

void Nixnex_GiveCurrentWeapon()
{
	float dt;
	if(g_nixnex)
	{
		if(!nixnex_nextweapon)
			Nixnex_ChooseNextWeapon();

		dt = ceil(nixnex_nextchange - time);

		if(dt <= 0)
		{
			nixnex_weapon = nixnex_nextweapon;
			nixnex_weapon_ammo = nixnex_nextweapon_ammo;
			nixnex_nextweapon = 0;
			nixnex_nextchange = time + CVAR(g_balance_nixnex_roundtime);
			//weapon_action(nixnex_weapon, WR_PRECACHE); // forget it, too slow
		}
		
		if(nixnex_nextchange != self.nixnex_lastchange_id) // this shall only be called once per round!
		{
			self.nixnex_lastchange_id = nixnex_nextchange;
			if (self.items & IT_UNLIMITED_WEAPON_AMMO)
			{
                self.ammo_shells  = if(nixnex_weapon_ammo & IT_SHELLS)
                                        CVAR(g_pickup_shells_max)   else 0;

                self.ammo_nails   = if(nixnex_weapon_ammo & IT_NAILS)
                                        CVAR(g_pickup_nails_max)    else 0;

                self.ammo_rockets = if(nixnex_weapon_ammo & IT_ROCKETS)
                                        CVAR(g_pickup_rockets_max)  else 0;

                self.ammo_cells   = if(nixnex_weapon_ammo & IT_CELLS)
                                        CVAR(g_pickup_cells_max)    else 0;

                self.ammo_fuel    = if(nixnex_weapon_ammo & IT_FUEL)
                                        CVAR(g_pickup_fuel_max)     else 0;

			}
			else
			{
                self.ammo_shells  = if(nixnex_weapon_ammo & IT_SHELLS)
                                        CVAR(g_balance_nixnex_ammo_shells)   else 0;

                self.ammo_nails   = if(nixnex_weapon_ammo & IT_NAILS)
                                        CVAR(g_balance_nixnex_ammo_nails)    else 0;

                self.ammo_rockets = if(nixnex_weapon_ammo & IT_ROCKETS)
                                        CVAR(g_balance_nixnex_ammo_rockets)  else 0;

                self.ammo_cells   = if(nixnex_weapon_ammo & IT_CELLS)
                                        CVAR(g_balance_nixnex_ammo_cells)    else 0;

                self.ammo_fuel    = if(nixnex_weapon_ammo & IT_FUEL)
                                        CVAR(g_balance_nixnex_ammo_fuel)     else 0;
			}
			self.nixnex_nextincr = time + CVAR(g_balance_nixnex_incrtime);
			if(dt >= 1 && dt <= 5)
				self.nixnex_lastinfotime = -42;
			else
				centerprint(self, strcat("\n\n^2Active weapon: ^3", W_Name(nixnex_weapon)));
		}
		if(self.nixnex_lastinfotime != dt)
		{
			self.nixnex_lastinfotime = dt; // initial value 0 should count as "not seen"
			if(dt >= 1 && dt <= 5)
				centerprint(self, strcat("^3", ftos(dt), "^2 seconds until weapon change...\n\nNext weapon: ^3", W_Name(nixnex_nextweapon), "\n"));
		}

		if(!(self.items & IT_UNLIMITED_WEAPON_AMMO) && time > self.nixnex_nextincr)
		{
			if (nixnex_weapon_ammo & IT_SHELLS)
				self.ammo_shells = self.ammo_shells + CVAR(g_balance_nixnex_ammoincr_shells);
			else if (nixnex_weapon_ammo & IT_NAILS)
				self.ammo_nails = self.ammo_nails + CVAR(g_balance_nixnex_ammoincr_nails);
			else if (nixnex_weapon_ammo & IT_ROCKETS)
				self.ammo_rockets = self.ammo_rockets + CVAR(g_balance_nixnex_ammoincr_rockets);
			else if (nixnex_weapon_ammo & IT_CELLS)
				self.ammo_cells = self.ammo_cells + CVAR(g_balance_nixnex_ammoincr_cells);
			if (nixnex_weapon_ammo & IT_FUEL) // hook uses cells and fuel
				self.ammo_fuel = self.ammo_fuel + CVAR(g_balance_nixnex_ammoincr_fuel);
			self.nixnex_nextincr = time + CVAR(g_balance_nixnex_incrtime);
		}

		self.weapons = 0;
		if(g_nixnex_with_laser)
			self.weapons = self.weapons | WEPBIT_LASER;
		self.weapons = self.weapons | W_WeaponBit(nixnex_weapon);

		if(self.switchweapon != nixnex_weapon)
			if(!client_hasweapon(self, self.switchweapon, TRUE, FALSE))
				if(client_hasweapon(self, nixnex_weapon, TRUE, FALSE))
					W_SwitchWeapon(nixnex_weapon);
	}
}

void W_FixWeaponSet(void) {
    if(g_weaponarena && g_weaponarena_secondary && !self.w_conv_switch) {
        var w = pow(2, self.switchweapon - 1) | pow(2, self.weapon - 1);
        var hasweapon = (self.switchweapon || self.weapon);
        var secondary = W_WeaponBit(self.w_secondary);

        if(self.BUTTON_ATCK && (w & secondary || !hasweapon)) {
            self.weapons &~= secondary;
            self.weapons |= g_weaponarena;
            W_SwitchWeapon_Silent(log2of(g_weaponarena) + 1);
        } else if(self.BUTTON_ATCK2 && (w & g_weaponarena || !hasweapon)) {
            self.weapons &~= g_weaponarena;
            self.weapons |= secondary;
            W_SwitchWeapon_Silent(log2of(secondary) + 1);
        }
    }
}

void W_PlayerPreThinkHook(void) {
    W_FixWeaponSet();
    W_Clip_PlayerPreThinkHook();
}

void W_SetSecondary(entity p, float w) {
    if(!g_weaponarena_secondary)
        return;

    if(p.w_secondary) {
        var sflag = pow(2, p.w_secondary - 1);

        if(p.weapons & sflag) {
            p.weapons &~= sflag;
            sflag = pow(2, w - 1);
            p.weapons |= sflag;
        }
    }

    p.w_secondary = w;

    if(!p.weapons) {
        p.weapons |= W_WeaponBit(w);
        W_SwitchWeapon_Force(p, w);
    }

    W_UpdateSecondaryWeaponStatus(p);
}

void W_RegisterHitForHitstreak(entity attacker, float deathtype) {
    if(DEATH_ISSPECIAL(deathtype))
        return;

    switch(DEATH_WEAPONOFWEAPONDEATH(deathtype)) {
        case WEP_CAMPINGRIFLE:
            W_CampingRifle_RegisterHitForHitstreak(attacker, deathtype);
            break;

        case WEP_UZI:
            W_Uzi_RegisterHitForHitstreak(attacker, deathtype);
            break;

        case WEP_NEX:
            W_Nex_RegisterHitForHitstreak(attacker, deathtype);
            break;
    }
}

void W_WriteSecondarySelect(void) {
    msg_entity = self;
    WriteByte(MSG_ONE, SVC_TEMPENTITY);
    WriteByte(MSG_ONE, TE_CSQC_SECONDARYSELECT);
    WriteInt24_t(MSG_ONE, g_weaponarena_secondary);
}

float W_ShowMenu(float always) {
    if(!g_weaponarena_secondary_selectable)
        return FALSE;

    if(clienttype(self) != CLIENTTYPE_REAL)
        return FALSE;

    if((self.w_secondary_picked && self.BUTTON_CHAT) && always < 2)
        return FALSE;
    
    if(always || !self.w_secondary_picked) {
        W_WriteSecondarySelect();
        return TRUE;
    }
    
    return FALSE;
}
