.float akimbo_weapons;
.entity akimbo_ghost;
.entity akimbo_ghost_persistent;
float g_akimbo_weapons;
float weapons_with_akimbo_support;

void Akimbo_GhostRemove(entity e)
{
    if(!e.akimbo_ghost)
        return;

    using(self = e.akimbo_ghost) {
        weapon_action(self.weapon, WR_CLEAR);
    }

    if(e.akimbo_ghost.weaponentity.weaponentity) {
        remove(e.akimbo_ghost.weaponentity.weaponentity);
        e.akimbo_ghost.weaponentity.weaponentity = world;
    }

    if(e.akimbo_ghost.weaponentity) {
       remove(e.akimbo_ghost.weaponentity);
       e.akimbo_ghost.weaponentity = world;
    }

    if(e.akimbo_ghost.exteriorweaponentity) {
       remove(e.akimbo_ghost.exteriorweaponentity);
       e.akimbo_ghost.exteriorweaponentity = world;
    }

    using(self = self.akimbo_ghost) {
        self.weapon = self.cnt = self.switchweapon = self.effects = 0;
    }

    e.akimbo_ghost_persistent = e.akimbo_ghost;
    e.akimbo_ghost = world;

    if(e.weaponentity) {
        e.weaponentity.cnt = 0;
    }
}

entity Akimbo_NewGhost(void) {
    if(self.akimbo_ghost_persistent)
        return self.akimbo_ghost_persistent;
    return spawn() {
        classname: "akimbo_ghost"
    };
}

void Akimbo_WeaponFrame()
{
	// if (self.akimbo_ghost && self.akimbo_ghost.weapon != self.weapon)
		// Akimbo_GhostRemove(self);

    if(!CVAR(g_akimbo))
        return;

	if (g_nexball)
	if (self.ballcarried)
	{
		Akimbo_GhostRemove(self);
        return;
	}
	// if not(self.weapon)
		// return;
	if (Akimbo_HaveWeapon(self, self.weapon) || (self.akimbo_ghost && !self.weapon))
	{
        var spawn_went = FALSE;

        if(!self.akimbo_ghost.weaponentity || !self.akimbo_ghost.exteriorweaponentity)
            Akimbo_GhostRemove(self);

        if(!self.akimbo_ghost) {
            self.akimbo_ghost = Akimbo_NewGhost();
            spawn_went = TRUE;
        }

		if(self.weapon != self.akimbo_ghost.weapon && self.weapon && (self.akimbo_ghost.weapon || spawn_went || self.weapon != self.switchweapon))
		{
			self.akimbo_ghost.weapon = self.weapon;
			self.akimbo_ghost.switchweapon = self.weapon;
			self.akimbo_ghost.modelindex = self.modelindex;
			self.akimbo_ghost.weapons = self.weapons;
			self.akimbo_ghost.owner = self;

            using(self = self.akimbo_ghost) {
                if(spawn_went)
                    CL_SpawnWeaponentity();
                self.weaponentity.state = WS_RAISE;
                weapon_action(self.weapon, WR_SETUP);
                weapon_thinkf(WFRAME_IDLE, CVAR(g_balance_weaponswitchdelay), w_ready);
                weapon_boblayer1(PLAYER_WEAPONSELECTION_SPEED, '0 0 0');
                // W_SwitchWeapon_Force(self, self.weapon);
            }

			self.weaponentity.cnt = 0;
		}

        self.akimbo_ghost.items = self.items;
		self.akimbo_ghost.ammo_shells = self.ammo_shells;
		self.akimbo_ghost.ammo_cells = self.ammo_cells;
		self.akimbo_ghost.ammo_nails = self.ammo_nails;
		self.akimbo_ghost.ammo_rockets = self.ammo_rockets;
		self.akimbo_ghost.weapons = self.weapons;
		self.akimbo_ghost.BUTTON_ATCK = self.BUTTON_ATCK;
		self.akimbo_ghost.BUTTON_ATCK2 = self.BUTTON_ATCK2;
		self.akimbo_ghost.deadflag = self.deadflag;
		self.akimbo_ghost.colormap = self.colormap;
		self.akimbo_ghost.effects = self.effects;
		self.akimbo_ghost.alpha = self.alpha;
		self.akimbo_ghost.health = self.health;
		// self.akimbo_ghost.switchweapon = self.switchweapon;
		self.akimbo_ghost.v_angle = self.v_angle;
		self.akimbo_ghost.origin = self.origin;
        self.akimbo_ghost.team = self.team;
        self.akimbo_ghost.colormap = self.colormap;

        using(self = self.akimbo_ghost)
            W_WeaponFrame();

		self.ammo_shells = self.akimbo_ghost.ammo_shells;
		self.ammo_cells = self.akimbo_ghost.ammo_cells;
		self.ammo_nails = self.akimbo_ghost.ammo_nails;
		self.ammo_rockets = self.akimbo_ghost.ammo_rockets;
	}
	else
	{
		Akimbo_GhostRemove(self);
	}
}

void Akimbo_Init()
{
    if(!CVAR(g_akimbo))
        return;

	float i, j, n;
	string s = CVAR_STR(g_akimbo_weapons);
	weapons_with_akimbo_support =
			WEPBIT_LASER |
			WEPBIT_SHOTGUN |
			WEPBIT_UZI |
			WEPBIT_CAMPINGRIFLE |
			WEPBIT_GRENADE_LAUNCHER |
			WEPBIT_ELECTRO |
			WEPBIT_CRYLINK |
			WEPBIT_HLAC |
			WEPBIT_NEX |
			WEPBIT_HAGAR |
			WEPBIT_ROCKET_LAUNCHER | 
            WEPBIT_ZAPPER |
            WEPBIT_FLAK |
            WEPBIT_PRYAXE;

	if (s == "all")
		g_akimbo_weapons = weapons_with_akimbo_support;
	else {
		n = tokenize_console(s);
		for (i = 0; i < n; i++)
			for (j = WEP_FIRST; j <= WEP_LAST; j++)
				if (argv(i) == get_weaponinfo(j).netname)
				{
					g_akimbo_weapons |= W_WeaponBit(j);
					break;
				}
	}
	g_akimbo_weapons = g_akimbo_weapons & weapons_with_akimbo_support;
	g_powerup_strength_akimbo = CVAR(g_powerup_strength_akimbo);

    addstat(STAT_AKIMBO_WEAPONS, AS_INT, akimbo_weapons);
}

entity Akimbo_Owner(entity e)
{
	if (e.owner)
	if (e.owner.akimbo_ghost == e)
		return e.owner;

	return e;
}

entity Akimbo_Ghost(entity e)
{
	if (e.owner)
	if (e.owner.akimbo_ghost == e)
		return e;

	return e.akimbo_ghost;
}

entity Akimbo_PGhost(entity e) {
    if (e.owner)
    if (e.owner.akimbo_ghost_persistent == e)
        return e;

    return e.akimbo_ghost_persistent;
}

float Akimbo_GiveWeapon(entity p, float wpn, string name)
{
	float wpnbit = W_WeaponBit(wpn);
	if (wpnbit & p.akimbo_weapons)
		return FALSE;

	if (g_akimbo_weapons & wpnbit)
	{
		p.akimbo_weapons |= wpnbit;
		sprint(p, "You got another ^2" + name + "\n");
        W_UpdateSecondaryWeaponStatus(p);
		return TRUE;
	}
	return FALSE;
}

float Akimbo_DropWeapon(entity p, float wpn, string name)
{
	float wpnbit = W_WeaponBit(wpn);
	if not(g_akimbo_weapons & wpnbit)
		return FALSE;

	if not(wpnbit & p.akimbo_weapons)
		return FALSE;

	p.akimbo_weapons &~= wpnbit;
	sprint(p, "You dropped ^4Akimbo ^2");
	sprint(p, name);
	sprint(p, "\n");
	return TRUE;
}

float Akimbo_Active(entity e)
{
	if (e.akimbo_ghost)
		return 1;
	if (Akimbo_Owner(e) != e)
		return 2;

	return 0;
}

void Akimbo_Clear(entity e)
{
	Akimbo_GhostRemove(e);

    if(e.akimbo_ghost_persistent) {
        remove(e.akimbo_ghost_persistent);
        e.akimbo_ghost_persistent = world;
    }

	e.akimbo_weapons = 0;
}

float Akimbo_HaveWeapon(entity e, float wpn)
{
    if(cvar("g_akimbo_test"))
        return TRUE;

	float wpnbit = W_WeaponBit(wpn);
	if ((e.akimbo_weapons & wpnbit) ||
			(g_powerup_strength_akimbo && e.strength_finished > time &&
			(wpnbit & weapons_with_akimbo_support)))
		return TRUE;
	return FALSE;
}

float Akimbo_GunPosition(entity e) {
    return switch(Akimbo_Active(e)) {
        case    1 : 1,
        case    2 : 2,
        default   : e.gunswitchmode
    };
}

void Akimbo_SyncSpreadIndicator(entity e) {
    if(Akimbo_Active(e) == 2)
        Akimbo_Owner(e).w_spread_indicator2 = e.w_spread_indicator;
}

float Akimbo_Possible(float wpn) {
    if(W_WeaponBit(wpn) & g_akimbo_weapons)
        return TRUE;
    return FALSE;
}

void Akimbo_WeaponAction(float wpn, float req) {
    var old_ghost = self.akimbo_ghost;
    self.akimbo_ghost = self.akimbo_ghost_persistent;

    var player = Akimbo_Owner(self);
    var ghost  = Akimbo_Ghost(player);

    if(player) using(self = player)
        weapon_action(wpn, req);

    if(ghost)  using(self = ghost)
        weapon_action(wpn, req);

    self.akimbo_ghost = old_ghost;
}

void Akimbo_OnPlayerSpawn(entity e) {
    e.akimbo_ghost_persistent = Akimbo_NewGhost();
}
