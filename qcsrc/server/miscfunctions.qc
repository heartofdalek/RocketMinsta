var void remove(entity e);
void objerror(string s);
void droptofloor();
.vector dropped_origin;

float crandom(void);

void() spawnfunc_info_player_deathmatch; // needed for the other spawnpoints
void() spawnpoint_use;
string ColoredTeamName(float t);

void W_Accuracy_RegisterPotentialDamage(entity attacker, float w, float damage);
void W_Accuracy_RegisterActualDamage(entity attacker, float w, float damage);

float DistributeEvenly_amount;
float DistributeEvenly_totalweight;
void DistributeEvenly_Init(float amount, float totalweight)
{
    if (DistributeEvenly_amount)
    {
        dprint("DistributeEvenly_Init: UNFINISHED DISTRIBUTION (", ftos(DistributeEvenly_amount), " for ");
        dprint(ftos(DistributeEvenly_totalweight), " left!)\n");
    }
    if (totalweight == 0)
        DistributeEvenly_amount = 0;
    else
        DistributeEvenly_amount = amount;
    DistributeEvenly_totalweight = totalweight;
}
float DistributeEvenly_Get(float weight)
{
    float f;
    if (weight <= 0)
        return 0;
    f = floor(0.5 + DistributeEvenly_amount * weight / DistributeEvenly_totalweight);
    DistributeEvenly_totalweight -= weight;
    DistributeEvenly_amount -= f;
    return f;
}

void move_out_of_solid_expand(entity e, vector by, float tracetype)
{
    float eps = 0.0625;
    tracebox(e.origin, e.mins - '1 1 1' * eps, e.maxs + '1 1 1' * eps, e.origin + by, tracetype, e);
    if (trace_startsolid)
        return;
    if (trace_fraction < 1)
    {
        // hit something
        // adjust origin in the other direction...
        setorigin(e,e.origin - by * (1 - trace_fraction));
    }
}

float move_out_of_solid(entity e, float tracetype)
{
    vector o, m0, m1;

    o = e.origin;
    traceline(o, o, tracetype, e);
    if (trace_startsolid)
        return 0;

    tracebox(o, e.mins, e.maxs, o, tracetype, e);
    if (!trace_startsolid)
        return 1;

    m0 = e.mins;
    m1 = e.maxs;
    e.mins = '0 0 0';
    e.maxs = '0 0 0';
    move_out_of_solid_expand(e, '1 0 0' * m0_x, tracetype);
    e.mins_x = m0_x;
    move_out_of_solid_expand(e, '1 0 0' * m1_x, tracetype);
    e.maxs_x = m1_x;
    move_out_of_solid_expand(e, '0 1 0' * m0_y, tracetype);
    e.mins_y = m0_y;
    move_out_of_solid_expand(e, '0 1 0' * m1_y, tracetype);
    e.maxs_y = m1_y;
    move_out_of_solid_expand(e, '0 0 1' * m0_z, tracetype);
    e.mins_z = m0_z;
    move_out_of_solid_expand(e, '0 0 1' * m1_z, tracetype);
    e.maxs_z = m1_z;
    setorigin(e, e.origin);

    tracebox(e.origin, e.mins, e.maxs, e.origin, tracetype, e);
    if (trace_startsolid)
    {
        setorigin(e, o);
        return 0;
    }

    return 1;
}

void snap_to_grid(entity e, float gridsize) {
    move_out_of_solid(e, MOVE_WORLDONLY);
    var o;

    do {
        o = e.origin;
        o_x = rint(o_x / gridsize) * gridsize;
        o_y = rint(o_y / gridsize) * gridsize;
        o_z = rint(o_z / gridsize) * gridsize;

        gridsize *= 0.5;

        if(gridsize < 1)
            break;

        tracebox(o, e.mins, e.maxs, o, MOVE_WORLDONLY, world);
    } while(trace_startsolid);

    setorigin(e, o);

    if(trace_startsolid)
        move_out_of_solid(e, MOVE_WORLDONLY);
}

void snap_to_entity(entity ent, float maxdist, float(entity) filter) {
    var e = findradius(ent.origin, maxdist), n, picked, mindist = maxdist, dst;

    while(e) {
        n = e.chain;

        if((dst = vlen(e.origin - ent.origin)) >= mindist)
            goto skip;

        if(e == ent)
            goto skip;

        if(filter && !filter(e))
            goto skip;

        mindist = dst;
        picked = e;

    :skip
        e = n;
    }

    if(!picked)
        return;

    var checkpassed = FALSE;
    var bestorigin;
    mindist = maxdist * 2;

    for(var i = 0; i < 2; ++i) {
        var fld = origin_array[i];
        var d = abs(picked.fld - ent.fld);

        if(d < mindist) {
            var saveorg = ent.origin;
            ent.fld = picked.fld;
            var neworg = ent.origin;
            ent.origin = saveorg;

            tracebox(neworg, ent.mins, ent.maxs, neworg, MOVE_WORLDONLY, world);

            if(trace_startsolid) {
                if(checkpassed)
                    continue;
            } else
                checkpassed = TRUE;

            mindist = d;
            bestorigin = neworg;
        }
    }

    setorigin(ent, bestorigin);

    if(!checkpassed)
        move_out_of_solid(ent, MOVE_WORLDONLY);
}

float check_uneven_ground(entity ent, float tolerance) {
    var p1 = ent.origin + [ent.mins_x, ent.mins_y, ent.maxs_z];
    var p2 = ent.origin + [ent.mins_x, ent.maxs_y, ent.maxs_z];
    var p3 = ent.origin + [ent.maxs_x, ent.mins_y, ent.maxs_z];
    var p4 = ent.origin + [ent.maxs_x, ent.maxs_y, ent.maxs_z];
    var wantDist, dir = [0, 0, -MAX_SHOT_DISTANCE];

    traceline(p1, p1 + dir, MOVE_WORLDONLY, ent);
    wantDist = vlen(p1 - trace_endpos);

    traceline(p2, p2 + dir, MOVE_WORLDONLY, ent);
    if(abs(vlen(p2 - trace_endpos) - wantDist) > tolerance)
        return TRUE;

    traceline(p3, p3 + dir, MOVE_WORLDONLY, ent);
    if(abs(vlen(p3 - trace_endpos) - wantDist) > tolerance)
        return TRUE;

    traceline(p4, p4 + dir, MOVE_WORLDONLY, ent);
    if(abs(vlen(p4 - trace_endpos) - wantDist) > tolerance)
        return TRUE;

    return FALSE;
}

string STR_PLAYER = "player";
string STR_SPECTATOR = "spectator";
string STR_OBSERVER = "observer";

#define FOR_EACH_CLIENTSLOT(v) for(v = world; (v = nextent(v)) && (num_for_edict(v) <= maxclients); )
#define FOR_EACH_CLIENT(v) FOR_EACH_CLIENTSLOT(v) if(v.flags & FL_CLIENT)
#define FOR_EACH_REALCLIENT(v) FOR_EACH_CLIENT(v) if(clienttype(v) == CLIENTTYPE_REAL)
#define FOR_EACH_PLAYER(v) FOR_EACH_CLIENT(v) if(v.iscreature) //if(v.classname == STR_PLAYER)
#define FOR_EACH_REALPLAYER(v) FOR_EACH_REALCLIENT(v) if(v.iscreature) //if(v.classname == STR_PLAYER)
#define FOR_EACH_DEVELOPER(v) FOR_EACH_REALCLIENT(v) if(v.isdeveloper)

// copies a string to a tempstring (so one can strunzone it)
string strcat1(string s) = #115; // FRIK_FILE

float logfile_open;
float logfile;

void bcenterprint(string s)
{
    // TODO replace by MSG_ALL (would show it to spectators too, though)?
    entity head;
    FOR_EACH_PLAYER(head)
    if (clienttype(head) == CLIENTTYPE_REAL)
        centerprint(head, s);
}

void GameLogEcho(string s)
{
    string fn;
    float matches;

    if (CVAR(sv_eventlog_files))
    {
        if (!logfile_open)
        {
            logfile_open = TRUE;
            matches = CVAR(sv_eventlog_files_counter) + 1;
            cvar_set("sv_eventlog_files_counter", ftos(matches));
            fn = ftos(matches);
            if (strlen(fn) < 8)
                fn = strcat(substring("00000000", 0, 8 - strlen(fn)), fn);
            fn = strcat(CVAR_STR(sv_eventlog_files_nameprefix), fn, CVAR_STR(sv_eventlog_files_namesuffix));
            logfile = fopen(fn, FILE_APPEND);
            fputs(logfile, ":logversion:3\n");
        }
        if (logfile >= 0)
        {
            if (CVAR(sv_eventlog_files_timestamps))
                fputs(logfile, strcat(":time:", strftime(TRUE, "%Y-%m-%d %H:%M:%S", "\n", s, "\n")));
            else
                fputs(logfile, strcat(s, "\n"));
        }
    }
    if (CVAR(sv_eventlog_console))
    {
        print(s, "\n");
    }
}

void GameLogInit()
{
    logfile_open = 0;
    // will be opened later
}

void GameLogClose()
{
    if (logfile_open && logfile >= 0)
    {
        fclose(logfile);
        logfile = -1;
    }
}

float check_team_spawns(void) {
    float r, b, y, p, c;
    float tc = TeamCount_TotalTeams();
    entity e;
    
    #define HANDLETEAM(n,o,p) case o: if(tc >= n) if(!p) c++; p = 1; break;
    for(e = world; (e = find(e, classname, "info_player_deathmatch")); ) switch(e.team) {
        HANDLETEAM(1, COLOR_TEAM1, r)
        HANDLETEAM(2, COLOR_TEAM2, b)
        HANDLETEAM(3, COLOR_TEAM3, y)
        HANDLETEAM(4, COLOR_TEAM4, p)
    }
    #undef HANDLETEAM
    
    return (c >= tc);
}

void fix_team_spawns(void) {
    if(have_team_spawns)
    if(!check_team_spawns()) {
        print("Not enough team spawnpoints, not using them\n");
        have_team_spawns = 0;
    }
}

float spawnpoint_nag;
void relocate_spawnpoint()
{
    // nudge off the floor
    setorigin(self, self.origin + '0 0 1');

    tracebox(self.origin, PL_MIN, PL_MAX, self.origin, TRUE, self);
    if (trace_startsolid)
    {
        vector o;
        o = self.origin;
        self.mins = PL_MIN;
        self.maxs = PL_MAX;
        if (!move_out_of_solid(self, MOVE_WORLDONLY))
            objerror("could not get out of solid at all!");
        print("^1NOTE: this map needs FIXING. Spawnpoint at ", vtos(o - '0 0 1'));
        print(" needs to be moved out of solid, e.g. by '", ftos(self.origin_x - o_x));
        print(" ", ftos(self.origin_y - o_y));
        print(" ", ftos(self.origin_z - o_z), "'\n");
        if (CVAR(g_spawnpoints_auto_move_out_of_solid))
        {
            if (!spawnpoint_nag)
                print("\{1}^1NOTE: this map needs FIXING (it contains spawnpoints in solid, see server log)\n");
            spawnpoint_nag = 1;
        }
        else
        {
            setorigin(self, o);
            self.mins = self.maxs = '0 0 0';
            objerror("player spawn point in solid, mapper sucks!\n");
            return;
        }
    }

    if (CVAR(g_spawnpoints_autodrop))
    {
        setsize(self, PL_MIN, PL_MAX);
        droptofloor();
    }

    self.use = spawnpoint_use;
    self.team_saved = self.team;
    if (!self.cnt)
        self.cnt = 1;

    if (g_ctf || g_assault || g_onslaught || g_domination || g_nexball || g_freezetag || g_tdm || g_jailbreak || g_keyhunt || g_clanarena)
        if (self.team)
            have_team_spawns = 1;

    if (CVAR(r_showbboxes))
    {
        // show where spawnpoints point at too
        makevectors(self.angles);
        entity e;
        e = spawn();
        e.classname = "info_player_foo";
        setorigin(e, self.origin + v_forward * 24);
        setsize(e, '-8 -8 -8', '8 8 8');
        e.solid = SOLID_TRIGGER;
    }
}

#define strstr strstrofs
/*
// NOTE: DO NOT USE THIS FUNCTION TOO OFTEN.
// IT WILL MOST PROBABLY DESTROY _ALL_ OTHER TEMP
// STRINGS AND TAKE QUITE LONG. haystack and needle MUST
// BE CONSTANT OR strzoneD!
float strstr(string haystack, string needle, float offset)
{
	float len, endpos;
	string found;
	len = strlen(needle);
	endpos = strlen(haystack) - len;
	while(offset <= endpos)
	{
		found = substring(haystack, offset, len);
		if(found == needle)
			return offset;
		offset = offset + 1;
	}
	return -1;
}
*/

float NUM_NEAREST_ENTITIES = 4;
entity nearest_entity[NUM_NEAREST_ENTITIES];
float nearest_length[NUM_NEAREST_ENTITIES];
entity findnearest(vector point, .string field, string value, vector axismod)
{
    entity localhead;
    float i;
    float j;
    float len;
    vector dist;

    float num_nearest;
    num_nearest = 0;

    localhead = find(world, field, value);
    while (localhead)
    {
        if ((localhead.items == IT_KEY1 || localhead.items == IT_KEY2) && localhead.target == "###item###")
            dist = localhead.oldorigin;
        else
            dist = localhead.origin;
        dist = dist - point;
        dist = dist_x * axismod_x * '1 0 0' + dist_y * axismod_y * '0 1 0' + dist_z * axismod_z * '0 0 1';
        len = vlen(dist);

        for (i = 0; i < num_nearest; ++i)
        {
            if (len < nearest_length[i])
                break;
        }

        // now i tells us where to insert at
        //   INSERTION SORT! YOU'VE SEEN IT! RUN!
        if (i < NUM_NEAREST_ENTITIES)
        {
            for (j = NUM_NEAREST_ENTITIES - 2; j >= i; --j)
            {
                nearest_length[j + 1] = nearest_length[j];
                nearest_entity[j + 1] = nearest_entity[j];
            }
            nearest_length[i] = len;
            nearest_entity[i] = localhead;
            if (num_nearest < NUM_NEAREST_ENTITIES)
                num_nearest = num_nearest + 1;
        }

        localhead = find(localhead, field, value);
    }

    // now use the first one from our list that we can see
    for (i = 0; i < num_nearest; ++i)
    {
        traceline(point, nearest_entity[i].origin, TRUE, world);
        if (trace_fraction == 1)
        {
            if (i != 0)
            {
                dprint("Nearest point (");
                dprint(nearest_entity[0].netname);
                dprint(") is not visible, using a visible one.\n");
            }
            return nearest_entity[i];
        }
    }

    if (num_nearest == 0)
        return world;

    dprint("Not seeing any location point, using nearest as fallback.\n");
    /* DEBUGGING CODE:
    dprint("Candidates were: ");
    for(j = 0; j < num_nearest; ++j)
    {
    	if(j != 0)
    		dprint(", ");
    	dprint(nearest_entity[j].netname);
    }
    dprint("\n");
    */

    return nearest_entity[0];
}

void spawnfunc_target_location()
{
    self.classname = "target_location";
    // location name in netname
    // eventually support: count, teamgame selectors, line of sight?
};

void spawnfunc_info_location()
{
    self.classname = "target_location";
    self.message = self.netname;
};

string NearestLocation(vector p)
{
    entity loc;
    string ret;
    ret = "somewhere";
    loc = findnearest(p, classname, "target_location", '1 1 1');
    if (loc)
    {
        ret = loc.message;
    }
    else
    {
        loc = findnearest(p, target, "###item###", '1 1 4');
        if (loc)
            ret = loc.netname;
    }
    return ret;
}

#define MAXREPS 32
string reptable_src[MAXREPS];
string reptable_rep[MAXREPS];
float reptable_srclen[MAXREPS];
float reptable_replen[MAXREPS];
float reptable_matchmode[MAXREPS];
float reptable_count;
float reptable_init;
float reptable_maxsrclen;
float reptable_minsrclen;

#define MATCHMODE_NORMAL 0
#define MATCHMODE_WORD   1
#define MATCHMODE_REGEX  2

#define FOR_EACH_REPID(n) float n; for(n = 0; n < reptable_count; ++n)

string getsrc(string id) {
	string s = cvar_string(strcat("sv_chat_autoreplace_", id, "_src"));
	if(!s || s == "")	// no src defined? Assume id is the src
		return id;
	return s;
}

string getrep(string id) {
	//return strcat(rgb_to_hexcolor('1 0 0' * random() + '0 1 0' * random() + '0 0 1' * random()), getsrc(id), "^7");
	
	return cvar_string(strcat("sv_chat_autoreplace_", id, "_rep"));
}

string getrepids() {
	return CVAR_STR(sv_chat_autoreplace_order);
}

void reptable_free() {
	reptable_init = FALSE;
	float i;
	for(i = 0; i < reptable_count; ++i) {
		strunzone(reptable_src[i]);
		strunzone(reptable_rep[i]);
		reptable_srclen[i] = 0;
		reptable_replen[i] = 0;
		reptable_matchmode[i] = FALSE;
	}
	reptable_count = 0;
	reptable_maxsrclen = 0;
	reptable_minsrclen = 0;
}

void reptable_make(string replacements) {
	if(reptable_init)
		reptable_free();
	
	reptable_init = TRUE;
	reptable_count = bound(0, tokenizebyseparator(replacements, " "), MAXREPS);
	
	float i;
	for(i = 0; i < reptable_count; ++i) {
		string id = argv(i);
        
        var mm = switch(str2chr(id, 0)) {
            case '%': MATCHMODE_WORD,
            case '@': MATCHMODE_REGEX,
            default : MATCHMODE_NORMAL
        };

        reptable_matchmode[i] = mm;

        if(mm != MATCHMODE_NORMAL)
            id = substring(id, 1, strlen(id) - 1);
        
		string src = strzone(getsrc(id));
		string rep = strzone(getrep(id));
		float srclen = if(mm == MATCHMODE_REGEX) 9001 else strlen(src);
		float replen = strlen(rep);
		
		reptable_src[i] = src;
		reptable_rep[i] = rep;
		reptable_srclen[i] = srclen;
		reptable_replen[i] = replen;
		
		if(srclen > reptable_maxsrclen)
			reptable_maxsrclen = srclen;
			
		if(!reptable_minsrclen || srclen < reptable_minsrclen)
			reptable_maxsrclen = srclen;
	}
	
	print("reptable_make: ", ftos(reptable_count), " reps, longest: ", ftos(reptable_maxsrclen), ", shortest: ", ftos(reptable_minsrclen), "\n");
}

#define IS_LOWER(c) (c >= 'a' && c <= 'z')
#define IS_UPPER(c) (c >= 'A' && c <= 'Z')
#define IS_ALPHA(c) (IS_LOWER(c) || IS_UPPER(c))
#define IS_NUMERIC(c) (c >= '0' && c <= '9')
#define IS_ALNUM(c) (IS_ALPHA(c) || IS_NUMERIC(c))
#define IS_WORD_CHAR(c) IS_ALNUM(c)

#define CHR_UPR(c) (if(c > 'Z') c + 'A' - 'a' else c)
#define CHR_LWR(c) (if(c < 'a') c - 'A' + 'a' else c)

float is_escaped_caret(string msg, float idx) {
    var yep = TRUE;
    for(var i = 0, var c = str2chr(msg, idx); c == '^'; c = str2chr(msg, idx + (--i)), yep = !yep);
    if(!i)
        return FALSE;
    return yep;
}

string mimic_case(string match, string sub) {
    float lower, total, i, slen, c;
    slen = strlen(sub);

    for(i = 0, c = str2chr(match, i); c; c = str2chr(match, ++i)) {
        if(IS_LOWER(c)) {
            ++lower;
            ++total;
        } else if(IS_UPPER(c)) {
            ++total;
        }
    }

    for(i = 0, c = str2chr(sub, i); c; c = str2chr(sub, ++i)) {
        var n = c;

        if(IS_ALPHA(c)) {
            if(random() * total < lower)
                n = CHR_LWR(c);
            else
                n = CHR_UPR(c);
        }

        if(n != c) {
            sub = strcat(
                substring(sub, 0, i),
                chr2str(n),
                substring(sub, i+1, slen)
            );
        }
    }

    return sub;
}

string regex_sub_autoreplace(string match, string sub) {
    return mimic_case(match, regex_sub_expand_matches(match, sub));
}

string apply_autoreplace(string msg) {
	if not(CVAR(sv_chat_autoreplace))
		return msg;
	
	if not(reptable_init) {
		string reps = getrepids();
		if(reps == "")
			return msg;
		reptable_make(reps);
	}

	float i, len;
	len = strlen(msg);
	
	if(len < reptable_minsrclen)
		return msg;		// no point
		
	for(i = 0; i < len; ++i) {
		FOR_EACH_REPID(id) {
			float slen = reptable_srclen[id];
            float mm = reptable_matchmode[id];

            if(reptable_matchmode[id] == MATCHMODE_REGEX) {
                if(!regex_match)
                    continue;

                if(is_escaped_caret(msg, i))
                    continue;

                string p = substring(msg, i, len);
                var ofs = regex_sub_once(reptable_src[id], p, 0, RE_IGNORE_CASE, reptable_rep[id], regex_sub_autoreplace);

                if(ofs >= 0) {
                    var head = substring(msg, 0, i);
                    msg = strcat(head, regex_sub_string);
                    len = strlen(msg);
                    i += ofs - 1;
                }

                continue;
            } else {
                string p = strtolower(substring(msg, i, slen));
                if(len - i < slen)
                    continue;

                if(p != reptable_src[id])
                    continue;

                if(reptable_matchmode[id] == MATCHMODE_WORD) {
                    float c;
                    
                    if(i > 0) {
                        c = str2chr(msg, i - 1);
                        if(IS_WORD_CHAR(c))
                            continue;
                    }
                    
                    if(i + slen < len) {
                        c = str2chr(msg, i + slen);
                        if(IS_WORD_CHAR(c))
                            continue;
                    }
                }
            }

			string head = substring(msg, 0, i);
			string tail = substring(msg, i + slen, len);
			msg = strcat(head, reptable_rep[id], tail);

			float rlen = reptable_replen[id];
			i += rlen - 1; // skip over the replacement to prevent other replacements from fucking with it
			len += rlen - slen;

			break;
		}
	}
	
	return msg;
}

string apply_faggotry(string msg) {
    string result, c;
    float len, i, o;

    msg = strdecolorize(msg);

    len = strlen(msg);
    c = substring(msg, len-1, 1);
    msg = strcat(msg, switch(floor(random() * 7)) {
        default: case 0: " ( ͡° ω ͡°)",
                 case 1: " ( ͡° ͜ʖ ͡°)",
                 case 2: " ( ͡° o ͡°)",
                 case 3: " ( ͡° _ ͡°)",
                 case 4: " ( ͡°ᨎ ͡°)",
                 case 5: " ( ͡°‿‿ ͡°)",
                 case 6: " ( ͡° ͟ʖ ͡°)"
    });
    len = strlen(msg);

    for(i = 0; i < len; ++i, ++o) {
        c = substring(msg, i, 1);
        if(c == "^") {
            c = "^^";
            if(substring(msg, i+1, 1) == "^")
                i++;
        }

        result = strcat(result, rgb_to_hexcolor(hue_mi_ma_to_rgb(time + 3 * sin(o * 0.07) + 3, 0.1, 1)), c);
    }

    return result;
}

string formatmessage(string msg)
{
    float p, p1, p2;
    float n;
    string escape;
    string replacement;
    p = 0;
    n = 7;
    
    msg = apply_autoreplace(msg);
    
    while (1)
    {
        if (n < 1)
            break; // too many replacements
        n = n - 1;
        p1 = strstr(msg, "%", p); // NOTE: this destroys msg as it's a tempstring!
        p2 = strstr(msg, "\\", p); // NOTE: this destroys msg as it's a tempstring!

        if (p1 < 0)
            p1 = p2;
        if (p2 < 0)
            p2 = p1;
        p = min(p1, p2);

        if (p < 0)
            break;
        replacement = substring(msg, p, 2);
        escape = substring(msg, p + 1, 1);
        if (escape == "%")
            replacement = "%";
        else if (escape == "\\")
            replacement = "\\";
        else if (escape == "n")
            replacement = "\n";
        else if (escape == "a")
            replacement = ftos(floor(self.armorvalue));
        else if (escape == "h")
            replacement = ftos(floor(self.health));
        else if (escape == "l")
            replacement = NearestLocation(self.origin);
        else if (escape == "y")
            replacement = NearestLocation(self.cursor_trace_endpos);
        else if (escape == "d")
            replacement = NearestLocation(self.death_origin);
        else if (escape == "w")
        {
            float wep;
            wep = self.weapon;
            if (!wep)
                wep = self.switchweapon;
            if (!wep)
                wep = self.cnt;
            replacement = W_Name(wep);
        }
        else if (escape == "W")
        {
            if (self.items & IT_SHELLS) replacement = "shells";
            else if (self.items & IT_NAILS) replacement = "bullets";
            else if (self.items & IT_ROCKETS) replacement = "rockets";
            else if (self.items & IT_CELLS) replacement = "cells";
            else replacement = "batteries"; // ;)
        }
        else if (escape == "x")
        {
            replacement = self.cursor_trace_ent.netname;
            if (!replacement || !self.cursor_trace_ent)
                replacement = "nothing";
        }
        else if (escape == "p")
        {
            if (self.last_selected_player)
                replacement = self.last_selected_player.netname;
            else
                replacement = "(nobody)";
        }
        msg = strcat(substring(msg, 0, p), replacement, substring(msg, p+2, strlen(msg) - (p+2)));
        p = p + strlen(replacement);
    }
    
    if(whatsgoingon || aprilfools)
        msg = apply_faggotry(msg);
    
    return msg;
}

/*
=============
GetCvars
=============
Called with:
  0:  sends the request
  >0: receives a cvar from name=argv(f) value=argv(f+1)
*/
void GetCvars_handleString(string thisname, float f, .string field, string name)
{
	if (f < 0)
	{
		if (self.field)
			strunzone(self.field);
		self.field = NULL;
	}
	else if (f > 0)
	{
		if (thisname == name)
		{
			if (self.field)
				strunzone(self.field);
			self.field = strzone(argv(f + 1));
		}
	}
	else
		stuffcmd(self, strcat("sendcvar ", name, "\n"));
}
void GetCvars_handleString_Fixup(string thisname, float f, .string field, string name, string(string) func)
{
	GetCvars_handleString(thisname, f, field, name);
	if (f >= 0) // also initialize to the fitting value for "" when sending cvars out
		if (thisname == name)
		{
			string s;
			s = func(strcat1(self.field));
			if (s != self.field)
			{
				strunzone(self.field);
				self.field = strzone(s);
			}
		}
}
void GetCvars_handleFloat(string thisname, float f, .float field, string name)
{
	if (f < 0)
	{
	}
	else if (f > 0)
	{
		if (thisname == name)
			self.field = stof(argv(f + 1));
	}
	else
		stuffcmd(self, strcat("sendcvar ", name, "\n"));
}
void GetCvars_handleFloatOnce(string thisname, float f, .float field, string name)
{
	if (f < 0)
	{
	}
	else if (f > 0)
	{
		if (thisname == name)
		{
			if(!self.field)
			{
				self.field = stof(argv(f + 1));
				if(!self.field)
					self.field = -1;
			}
		}
	}
	else
	{
		if(!self.field)
			stuffcmd(self, strcat("sendcvar ", name, "\n"));
	}
}
string W_FixWeaponOrder_ForceComplete(string s);
string W_FixWeaponOrder_AllowIncomplete(string s);
float w_getbestweapon(entity e);
void GetCvars(float f)
{
	string s;
	if (f > 0)
		s = strcat1(argv(f));
	GetCvars_handleFloat(s, f, autoswitch, "cl_autoswitch");
	GetCvars_handleFloat(s, f, cvar_cl_playerdetailreduction, "cl_playerdetailreduction");
	GetCvars_handleFloat(s, f, cvar_scr_centertime, "scr_centertime");
	GetCvars_handleFloat(s, f, cvar_cl_shownames, "cl_shownames");
	GetCvars_handleString(s, f, cvar_g_nexuizversion, "g_nexuizversion");
	GetCvars_handleFloat(s, f, cvar_cl_handicap, "cl_handicap");
	GetCvars_handleString_Fixup(s, f, cvar_cl_weaponpriority, "cl_weaponpriority", W_FixWeaponOrder_ForceComplete);
	GetCvars_handleString_Fixup(s, f, cvar_cl_weaponpriorities[0], "cl_weaponpriority0", W_FixWeaponOrder_AllowIncomplete);
	GetCvars_handleString_Fixup(s, f, cvar_cl_weaponpriorities[1], "cl_weaponpriority1", W_FixWeaponOrder_AllowIncomplete);
	GetCvars_handleString_Fixup(s, f, cvar_cl_weaponpriorities[2], "cl_weaponpriority2", W_FixWeaponOrder_AllowIncomplete);
	GetCvars_handleString_Fixup(s, f, cvar_cl_weaponpriorities[3], "cl_weaponpriority3", W_FixWeaponOrder_AllowIncomplete);
	GetCvars_handleString_Fixup(s, f, cvar_cl_weaponpriorities[4], "cl_weaponpriority4", W_FixWeaponOrder_AllowIncomplete);
	GetCvars_handleString_Fixup(s, f, cvar_cl_weaponpriorities[5], "cl_weaponpriority5", W_FixWeaponOrder_AllowIncomplete);
	GetCvars_handleString_Fixup(s, f, cvar_cl_weaponpriorities[6], "cl_weaponpriority6", W_FixWeaponOrder_AllowIncomplete);
	GetCvars_handleString_Fixup(s, f, cvar_cl_weaponpriorities[7], "cl_weaponpriority7", W_FixWeaponOrder_AllowIncomplete);
	GetCvars_handleString_Fixup(s, f, cvar_cl_weaponpriorities[8], "cl_weaponpriority8", W_FixWeaponOrder_AllowIncomplete);
	GetCvars_handleString_Fixup(s, f, cvar_cl_weaponpriorities[9], "cl_weaponpriority9", W_FixWeaponOrder_AllowIncomplete);
	GetCvars_handleFloat(s, f, cvar_cl_autotaunt, "cl_autotaunt");
	GetCvars_handleFloat(s, f, cvar_cl_voice_directional, "cl_voice_directional");
	GetCvars_handleFloat(s, f, cvar_cl_voice_directional_taunt_attenuation, "cl_voice_directional_taunt_attenuation");
	GetCvars_handleFloat(s, f, cvar_cl_hitsound, "cl_hitsound");
#ifdef ALLOW_FORCEMODELS
	GetCvars_handleFloat(s, f, cvar_cl_forceplayermodels, "cl_forceplayermodels");
	GetCvars_handleFloat(s, f, cvar_cl_forceplayermodelsfromnexuiz, "cl_forceplayermodelsfromnexuiz");
#endif
	GetCvars_handleFloat(s, f, cvar_cl_gunalign, "cl_gunalign");
    GetCvars_handleFloat(s, f, client_dprmversion, "dprm_version");
    GetCvars_handleFloat(s, f, client_utf8, "utf8_enable");


	// fixup of switchweapon (needed for LMS or when spectating is disabled, as PutClientInServer comes too early)
	if (f > 0)
	{
		if (s == "cl_weaponpriority")
			self.switchweapon = w_getbestweapon(self);

        self.gunswitchmode = bound(0, self.cvar_cl_gunalign, 4);

        if(self.gunswitchmode > 2) {
            if(!CVAR(g_shootfromclient))
                self.gunswitchmode = 1;
            else if(!CVAR(g_shootfromeye) && !CVAR(g_shootfromcenter) && CVAR(g_shootfromclient) < 2)
                self.gunswitchmode -= 2;
        }

        if(self.gunswitchmode > 3)
            self.gunswitchmode = 3;
	}
}

void GameCommand(string);

float Team_Index(float t) {
    switch(t) {
        case COLOR_TEAM1: return 0;
        case COLOR_TEAM2: return 1;
        case COLOR_TEAM3: return 2;
        case COLOR_TEAM4: return 3;
    }
    
    return -1;
}

float Team_FromIndex(float i) {
    switch(i) {
        case 0: return COLOR_TEAM1;
        case 1: return COLOR_TEAM2;
        case 2: return COLOR_TEAM3;
        case 3: return COLOR_TEAM4;
    }
    
    return 0;
}

#define CENTERPRIO_POINT 1
#define CENTERPRIO_SPAM 2
#define CENTERPRIO_VOTE 4
#define CENTERPRIO_NORMAL 5
#define CENTERPRIO_SHIELDING 7
#define CENTERPRIO_MAPVOTE 9
#define CENTERPRIO_IDLEKICK 50
#define CENTERPRIO_ADMIN 99
.float centerprint_priority;
.float centerprint_expires;
void centerprint_atprio(entity e, float prio, string s)
{
    if (intermission_running)
        if (prio < CENTERPRIO_MAPVOTE)
            return;
    if (time > e.centerprint_expires)
        e.centerprint_priority = 0;
    if (prio >= e.centerprint_priority)
    {
        e.centerprint_priority = prio;
        if (timeoutStatus == 2)
            e.centerprint_expires = time + (e.cvar_scr_centertime * TIMEOUT_SLOWMO_VALUE);
        else
            e.centerprint_expires = time + e.cvar_scr_centertime;
        centerprint_builtin(e, s);
    }
}
void centerprint_expire(entity e, float prio)
{
    if (prio == e.centerprint_priority)
    {
        e.centerprint_priority = 0;
        centerprint_builtin(e, "");
    }
}
void centerprint(entity e, string s)
{
    centerprint_atprio(e, CENTERPRIO_NORMAL, s);
}

// decolorizes and team colors the player name when needed
string playername(entity p)
{
    string t;
    if (teams_matter && !intermission_running && p.classname == "player")
    {
        t = Team_ColorCode(p.team);
        return strcat(t, strdecolorize(p.netname));
    }
    else
        return p.netname;
}

vector randompos(vector m1, vector m2)
{
    vector v;
    m2 = m2 - m1;
    v_x = m2_x * random() + m1_x;
    v_y = m2_y * random() + m1_y;
    v_z = m2_z * random() + m1_z;
    return  v;
};

float g_pickup_shells;
float g_pickup_shells_max;
float g_pickup_nails;
float g_pickup_nails_max;
float g_pickup_rockets;
float g_pickup_rockets_max;
float g_pickup_cells;
float g_pickup_cells_max;
float g_pickup_fuel;
float g_pickup_fuel_jetpack;
float g_pickup_fuel_max;
float g_pickup_armorsmall;
float g_pickup_armorsmall_max;
float g_pickup_armormedium;
float g_pickup_armormedium_max;
float g_pickup_armorbig;
float g_pickup_armorbig_max;
float g_pickup_armorlarge;
float g_pickup_armorlarge_max;
float g_pickup_healthsmall;
float g_pickup_healthsmall_max;
float g_pickup_healthmedium;
float g_pickup_healthmedium_max;
float g_pickup_healthlarge;
float g_pickup_healthlarge_max;
float g_pickup_healthmega;
float g_pickup_healthmega_max;
float g_weaponarena;
float g_weaponarena_random;
float g_weaponarena_secondary;
string g_weaponarena_list;
float g_weaponspeedfactor;
float g_weaponratefactor;
float g_weapondamagefactor;
float g_weaponforcefactor;

#define g_weaponarena_secondary_selectable (g_weaponarena_secondary & (g_weaponarena_secondary - 1))

float start_weapons;
float start_items;
float start_ammo_shells;
float start_ammo_nails;
float start_ammo_rockets;
float start_ammo_cells;
float start_ammo_fuel;
float start_health;
float start_armorvalue;
float warmup_start_weapons;
float warmup_start_ammo_shells;
float warmup_start_ammo_nails;
float warmup_start_ammo_rockets;
float warmup_start_ammo_cells;
float warmup_start_ammo_fuel;
float warmup_start_health;
float warmup_start_armorvalue;
float g_weapon_stay;
float g_ghost_items;

entity get_weaponinfo(float w);

float NixNex_CanChooseWeapon(float wpn);

float g_weaponarena_limitammo;

void set_weaponarena(string s) {
    var i, j, e, t;

    if(s == "0")
    {
    }
    else if (s == "all")
    {
        g_weaponarena_list = "All Weapons";
        for (j = WEP_FIRST; j <= WEP_LAST; ++j)
        {
            e = get_weaponinfo(j);
            g_weaponarena |= e.weapons;
            weapon_precache(e.weapon);
        }
    }
    else if (s == "most")
    {
        g_weaponarena_list = "Most Weapons";
        for (j = WEP_FIRST; j <= WEP_LAST; ++j)
        {
            e = get_weaponinfo(j);
            if (e.spawnflags & WEPSPAWNFLAG_NORMAL)
            {
                g_weaponarena |= e.weapons;
                weapon_precache(e.weapon);
            }
        }
    }
    else if (s == "none")
    {
        g_weaponarena_list = "No Weapons";
        g_weaponarena = WEPBIT_ALL + 1; // this supports no single weapon bit!
    }
    else
    {
        t = tokenize_console(s);
        g_weaponarena_list = "";
        for (i = 0; i < t; ++i)
        {
            s = argv(i);
            for (j = WEP_FIRST; j <= WEP_LAST; ++j)
            {
                e = get_weaponinfo(j);
                if (e.netname == s)
                {
                    g_weaponarena |= e.weapons;
                    weapon_precache(e.weapon);
                    g_weaponarena_list = strcat(g_weaponarena_list, e.message, " & ");
                    break;
                }
            }
            if (j > WEP_LAST)
            {
                print("The weapon mutator list contains an unknown weapon ", s, ". Skipped.\n");
            }
        }
        g_weaponarena_list = strzone(substring(g_weaponarena_list, 0, strlen(g_weaponarena_list) - 3));
    }

}

void readplayerstartcvars()
{
    entity e;
    float i, j, t;
    string s;

    // initialize starting values for players
    start_weapons = 0;
    start_items = 0;
    start_ammo_shells = 0;
    start_ammo_nails = 0;
    start_ammo_rockets = 0;
    start_ammo_cells = 0;
    start_health = CVAR(g_balance_health_start);
    start_armorvalue = CVAR(g_balance_armor_start);

	g_weaponarena_limitammo = CVAR(g_weaponarena_limitammo);

    g_weaponarena = 0;
    g_weaponarena_secondary = 0;

    if(g_clanarena) {
        s = CVAR_STR(g_clanarena_start_weapons);
        if(s == "0")
            s = CVAR_STR(g_weaponarena);
        if(s == "0")
            s = "most";
    } else {
        s = CVAR_STR(g_weaponarena);
    }
    
    set_weaponarena(s);

	if(g_weaponarena) {
		g_weaponarena_random = CVAR(g_weaponarena_random);
	} else {
		g_weaponarena_random = 0;
        g_weaponarena_limitammo = 0;
    }

    if (g_clanarena) {
        start_health = CVAR(g_clanarena_start_health);
        start_armorvalue = CVAR(g_clanarena_start_armor);
    }

    if(g_weaponarena) {
        s = CVAR_STR(g_weaponarena_secondary);

        if(s != "" && s != "0") {
            var saved_list = g_weaponarena_list;
            var saved_warea = g_weaponarena;
            g_weaponarena = 0;
            set_weaponarena(s);
            g_weaponarena_secondary = g_weaponarena;
            g_weaponarena_list = saved_list;
            g_weaponarena = saved_warea;
        }
    }

    if (g_nixnex)
    {
        start_weapons = 0;
        // will be done later
        for (i = WEP_FIRST; i <= WEP_LAST; ++i)
            if (NixNex_CanChooseWeapon(i))
                weapon_precache(i);
        if(!CVAR(g_use_ammunition))
        	start_items |= IT_UNLIMITED_AMMO;
    }
    else if (g_weaponarena)
    {
        start_weapons = g_weaponarena;
        
        if(!g_weaponarena_limitammo)
        {
            var weps = g_weaponarena | g_weaponarena_secondary;
			if (weps & (WEPBIT_GRENADE_LAUNCHER | WEPBIT_HAGAR | WEPBIT_ROCKET_LAUNCHER | WEPBIT_FLAK))
				start_ammo_rockets = 999;
			if (weps & (WEPBIT_SHOTGUN | WEPBIT_FLAK))
				start_ammo_shells = 999;
			if (weps & (WEPBIT_ELECTRO | WEPBIT_CRYLINK | WEPBIT_NEX | WEPBIT_MINSTANEX | WEPBIT_HLAC | WEPBIT_HOOK | WEPBIT_ZAPPER))
				start_ammo_cells = 999;
			if (weps & (WEPBIT_UZI | WEPBIT_CAMPINGRIFLE))
				start_ammo_nails = 999;
			if (weps & WEPBIT_HOOK)
				start_ammo_fuel = 999;
			start_items |= IT_UNLIMITED_AMMO;
		}
        else if (g_clanarena)
        {
            start_ammo_shells = CVAR(g_clanarena_start_shells);
            start_ammo_nails = CVAR(g_clanarena_start_nails);
            start_ammo_rockets = CVAR(g_clanarena_start_rockets);
            start_ammo_cells = CVAR(g_clanarena_start_cells);
            start_ammo_fuel = CVAR(g_clanarena_start_fuel);
        }
		else
		{
			start_ammo_shells = CVAR(g_start_ammo_shells);
            start_ammo_nails = CVAR(g_start_ammo_nails);
            start_ammo_rockets = CVAR(g_start_ammo_rockets);
            start_ammo_cells = CVAR(g_start_ammo_cells);
            start_ammo_fuel = CVAR(g_start_ammo_fuel);
		}
    }
    else if (g_minstagib)
    {
        start_health = 100;
        start_armorvalue = 0;
        start_weapons = WEPBIT_MINSTANEX;
        weapon_precache(WEP_MINSTANEX);
        start_ammo_cells = CVAR(g_minstagib_ammo_start);
        g_minstagib_invis_alpha = CVAR(g_minstagib_invis_alpha);
        start_ammo_fuel = CVAR(g_start_ammo_fuel);

        if (g_minstagib_invis_alpha <= 0)
            g_minstagib_invis_alpha = -1;
    }
    else
    {
        if (g_lms)
        {
            start_ammo_shells = CVAR(g_lms_start_ammo_shells);
            start_ammo_nails = CVAR(g_lms_start_ammo_nails);
            start_ammo_rockets = CVAR(g_lms_start_ammo_rockets);
            start_ammo_cells = CVAR(g_lms_start_ammo_cells);
            start_ammo_fuel = CVAR(g_lms_start_ammo_fuel);
            start_health = CVAR(g_lms_start_health);
            start_armorvalue = CVAR(g_lms_start_armor);
        }
        else if (CVAR(g_use_ammunition))
        {
            start_ammo_shells = CVAR(g_start_ammo_shells);
            start_ammo_nails = CVAR(g_start_ammo_nails);
            start_ammo_rockets = CVAR(g_start_ammo_rockets);
            start_ammo_cells = CVAR(g_start_ammo_cells);
            start_ammo_fuel = CVAR(g_start_ammo_fuel);
        }
        else
        {
            start_ammo_shells = CVAR(g_pickup_shells_max);
            start_ammo_nails = CVAR(g_pickup_nails_max);
            start_ammo_rockets = CVAR(g_pickup_rockets_max);
            start_ammo_cells = CVAR(g_pickup_cells_max);
            start_ammo_fuel = CVAR(g_pickup_fuel_max);
            start_items |= IT_UNLIMITED_AMMO;
        }

		if(!g_weaponarena)
        for (i = WEP_FIRST; i <= WEP_LAST; ++i)
        {
            e = get_weaponinfo(i);
            if (!(e.weapon))
                continue;

            t = cvar(strcat("g_start_weapon_", e.netname));

            if (t < 0) // "default" weapon selection
            {
                if (g_lms)
                    t = (e.spawnflags & WEPSPAWNFLAG_NORMAL);
                else if (g_race || g_cts)
                    t = (i == WEP_LASER);
                else if (g_nexball)
                    t = 0; // weapon is set a few lines later
                else
                    t = (i == WEP_LASER || i == WEP_SHOTGUN);
                if (g_grappling_hook) // if possible, redirect off-hand hook to on-hand hook
                    t += (i == WEP_HOOK);
            }

            if (g_nexball && i == WEP_PORTO)
                t=1;

            if (t)
            {
                start_weapons |= e.weapons;
                weapon_precache(e.weapon);
            }
        }
    }

    if (inWarmupStage)
    {
        warmup_start_ammo_shells = start_ammo_shells;
        warmup_start_ammo_nails = start_ammo_nails;
        warmup_start_ammo_rockets = start_ammo_rockets;
        warmup_start_ammo_cells = start_ammo_cells;
        warmup_start_ammo_fuel = start_ammo_fuel;
        warmup_start_health = start_health;
        warmup_start_armorvalue = start_armorvalue;
        warmup_start_weapons = start_weapons;

        if (!g_weaponarena && !g_nixnex && !g_minstagib)
        {
            if (CVAR(g_use_ammunition))
            {
                warmup_start_ammo_shells = CVAR(g_warmup_start_ammo_shells);
                warmup_start_ammo_cells = CVAR(g_warmup_start_ammo_cells);
                warmup_start_ammo_nails = CVAR(g_warmup_start_ammo_nails);
                warmup_start_ammo_rockets = CVAR(g_warmup_start_ammo_rockets);
                warmup_start_ammo_fuel = CVAR(g_warmup_start_ammo_fuel);
            }
            warmup_start_health = CVAR(g_warmup_start_health);
            warmup_start_armorvalue = CVAR(g_warmup_start_armor);
            if (CVAR(g_warmup_allguns))
            {
                for (i = WEP_FIRST; i <= WEP_LAST; ++i)
                {
                    e = get_weaponinfo(i);
                    if (!(e.weapon))
                        continue;
                    if (e.spawnflags & WEPSPAWNFLAG_NORMAL)
                    {
                        warmup_start_weapons |= e.weapons;
                        weapon_precache(e.weapon);
                    }
                }
            }
        }
    }

    if (g_jetpack || (g_grappling_hook && (start_weapons & WEPBIT_HOOK)))
    {
        g_grappling_hook = 0; // these two can't coexist, as they use the same button
        start_items |= IT_FUEL_REGEN;
        start_ammo_fuel = max(start_ammo_fuel, CVAR(g_balance_fuel_rotstable));
        warmup_start_ammo_fuel = max(warmup_start_ammo_fuel, CVAR(g_balance_fuel_rotstable));
    }

    if (g_jetpack)
        start_items |= IT_JETPACK;

	if(g_jetpack /*|| g_grappling_hook*/)
		g_nadgets = 0;

    if (g_weapon_stay == 2)
    {
        if (!start_ammo_shells) start_ammo_shells = g_pickup_shells;
        if (!start_ammo_nails) start_ammo_nails = g_pickup_nails;
        if (!start_ammo_cells) start_ammo_cells = g_pickup_cells;
        if (!start_ammo_rockets) start_ammo_rockets = g_pickup_rockets;
        if (!start_ammo_fuel) start_ammo_fuel = g_pickup_fuel;
        if (!warmup_start_ammo_shells) warmup_start_ammo_shells = g_pickup_shells;
        if (!warmup_start_ammo_nails) warmup_start_ammo_nails = g_pickup_nails;
        if (!warmup_start_ammo_cells) warmup_start_ammo_cells = g_pickup_cells;
        if (!warmup_start_ammo_rockets) warmup_start_ammo_rockets = g_pickup_rockets;
        if (!warmup_start_ammo_fuel) warmup_start_ammo_fuel = g_pickup_fuel;
    }

    start_ammo_shells = max(0, start_ammo_shells);
    start_ammo_nails = max(0, start_ammo_nails);
    start_ammo_cells = max(0, start_ammo_cells);
    start_ammo_rockets = max(0, start_ammo_rockets);
    start_ammo_fuel = max(0, start_ammo_fuel);

    warmup_start_ammo_shells = max(0, warmup_start_ammo_shells);
    warmup_start_ammo_nails = max(0, warmup_start_ammo_nails);
    warmup_start_ammo_cells = max(0, warmup_start_ammo_cells);
    warmup_start_ammo_rockets = max(0, warmup_start_ammo_rockets);
    warmup_start_ammo_fuel = max(0, warmup_start_ammo_fuel);
}

float g_bugrigs;
float g_bugrigs_planar_movement;
float g_bugrigs_planar_movement_car_jumping;
float g_bugrigs_reverse_spinning;
float g_bugrigs_reverse_speeding;
float g_bugrigs_reverse_stopping;
float g_bugrigs_air_steering;
float g_bugrigs_angle_smoothing;
float g_bugrigs_friction_floor;
float g_bugrigs_friction_brake;
float g_bugrigs_friction_air;
float g_bugrigs_accel;
float g_bugrigs_speed_ref;
float g_bugrigs_speed_pow;
float g_bugrigs_steer;

float g_touchexplode;
float g_touchexplode_radius;
float g_touchexplode_damage;
float g_touchexplode_edgedamage;
float g_touchexplode_force;

float sv_autotaunt;
float sv_taunt;

string sv_model_healthmega;
string sv_model_healthlarge;
string sv_model_healthmedium;
string sv_model_healthsmall;

void readlevelcvars(void)
{
    g_bugrigs = CVAR(g_bugrigs);
    g_bugrigs_planar_movement = CVAR(g_bugrigs_planar_movement);
    g_bugrigs_planar_movement_car_jumping = CVAR(g_bugrigs_planar_movement_car_jumping);
    g_bugrigs_reverse_spinning = CVAR(g_bugrigs_reverse_spinning);
    g_bugrigs_reverse_speeding = CVAR(g_bugrigs_reverse_speeding);
    g_bugrigs_reverse_stopping = CVAR(g_bugrigs_reverse_stopping);
    g_bugrigs_air_steering = CVAR(g_bugrigs_air_steering);
    g_bugrigs_angle_smoothing = CVAR(g_bugrigs_angle_smoothing);
    g_bugrigs_friction_floor = CVAR(g_bugrigs_friction_floor);
    g_bugrigs_friction_brake = CVAR(g_bugrigs_friction_brake);
    g_bugrigs_friction_air = CVAR(g_bugrigs_friction_air);
    g_bugrigs_accel = CVAR(g_bugrigs_accel);
    g_bugrigs_speed_ref = CVAR(g_bugrigs_speed_ref);
    g_bugrigs_speed_pow = CVAR(g_bugrigs_speed_pow);
    g_bugrigs_steer = CVAR(g_bugrigs_steer);

    g_touchexplode = CVAR(g_touchexplode);
    g_touchexplode_radius = CVAR(g_touchexplode_radius);
    g_touchexplode_damage = CVAR(g_touchexplode_damage);
    g_touchexplode_edgedamage = CVAR(g_touchexplode_edgedamage);
    g_touchexplode_force = CVAR(g_touchexplode_force);

#ifdef ALLOW_FORCEMODELS
    sv_clforceplayermodels = CVAR(sv_clforceplayermodels);
#endif
    sv_loddistance1 = CVAR(sv_loddistance1);
    sv_loddistance2 = CVAR(sv_loddistance2);
	if(sv_loddistance2 <= sv_loddistance1)
		sv_loddistance2 = 1073741824; // enough to turn off LOD 2 reliably
    sv_clones = CVAR(sv_clones);
    sv_cheats = CVAR(sv_cheats);
    sv_gentle = CVAR(sv_gentle);
    g_cloaked = CVAR(g_cloaked);
    g_jump_grunt = CVAR(g_jump_grunt);
    g_footsteps = CVAR(g_footsteps);
    g_grappling_hook = CVAR(g_grappling_hook);
    g_jetpack = CVAR(g_jetpack);
    g_nadgets = CVAR(g_nadgets);
    g_laserguided_missile = CVAR(g_laserguided_missile);
    g_midair = CVAR(g_midair);
    g_minstagib = CVAR(g_minstagib);
    g_nixnex = CVAR(g_nixnex);
    g_nixnex_with_laser = CVAR(g_nixnex_with_laser);
    g_norecoil = CVAR(g_norecoil);
    g_vampire = CVAR(g_vampire);
    g_bloodloss = CVAR(g_bloodloss);
    sv_maxidle = CVAR(sv_maxidle);
    sv_maxidle_spectatorsareidle = CVAR(sv_maxidle_spectatorsareidle);
    sv_pogostick = CVAR(sv_pogostick);
    sv_doublejump = CVAR(sv_doublejump);
    sv_slicksurfaces = CVAR(sv_slicksurfaces);
    g_ctf_reverse = CVAR(g_ctf_reverse);
	sv_autotaunt = CVAR(sv_autotaunt);
	sv_taunt = CVAR(sv_taunt);

    inWarmupStage = CVAR(g_warmup);
    g_warmup_limit = CVAR(g_warmup_limit);
    g_warmup_allguns = CVAR(g_warmup_allguns);
    g_warmup_allow_timeout = CVAR(g_warmup_allow_timeout);

    if ((g_race && g_race_qualifying == 2) || g_arena || g_assault || CVAR(g_campaign))
        inWarmupStage = 0; // these modes cannot work together, sorry

    g_pickup_respawntime_weapon = CVAR(g_pickup_respawntime_weapon);
    g_pickup_respawntime_ammo = CVAR(g_pickup_respawntime_ammo);
    g_pickup_respawntime_powerup = CVAR(g_pickup_respawntime_powerup);
    g_pickup_respawntime_health_small = CVAR(g_pickup_respawntime_health_small);
    g_pickup_respawntime_health_medium = CVAR(g_pickup_respawntime_health_medium);
    g_pickup_respawntime_health_large = CVAR(g_pickup_respawntime_health_large);
    g_pickup_respawntime_health_mega = CVAR(g_pickup_respawntime_health_mega);
    g_pickup_respawntime_armor_small = CVAR(g_pickup_respawntime_armor_small);
    g_pickup_respawntime_armor_medium = CVAR(g_pickup_respawntime_armor_medium);
    g_pickup_respawntime_armor_big = CVAR(g_pickup_respawntime_armor_big);
    g_pickup_respawntime_armor_large = CVAR(g_pickup_respawntime_armor_large);

    g_pickup_respawntimejitter_weapon = CVAR(g_pickup_respawntimejitter_weapon);
    g_pickup_respawntimejitter_ammo = CVAR(g_pickup_respawntimejitter_ammo);
    g_pickup_respawntimejitter_powerup = CVAR(g_pickup_respawntimejitter_powerup);
    g_pickup_respawntimejitter_health_small = CVAR(g_pickup_respawntimejitter_health_small);
    g_pickup_respawntimejitter_health_medium = CVAR(g_pickup_respawntimejitter_health_medium);
    g_pickup_respawntimejitter_health_large = CVAR(g_pickup_respawntimejitter_health_large);
    g_pickup_respawntimejitter_health_mega = CVAR(g_pickup_respawntimejitter_health_mega);
    g_pickup_respawntimejitter_armor_small = CVAR(g_pickup_respawntimejitter_armor_small);
    g_pickup_respawntimejitter_armor_medium = CVAR(g_pickup_respawntimejitter_armor_medium);
    g_pickup_respawntimejitter_armor_big = CVAR(g_pickup_respawntimejitter_armor_big);
    g_pickup_respawntimejitter_armor_large = CVAR(g_pickup_respawntimejitter_armor_large);


    if (g_minstagib) g_nixnex = g_weaponarena = 0;
    if (g_nixnex) g_weaponarena = 0;
    g_weaponarena = 0;

    g_weaponspeedfactor = CVAR(g_weaponspeedfactor);
    g_weaponratefactor = CVAR(g_weaponratefactor);
    g_weapondamagefactor = CVAR(g_weapondamagefactor);
    g_weaponforcefactor = CVAR(g_weaponforcefactor);

    g_pickup_shells                    = CVAR(g_pickup_shells);
    g_pickup_shells_max                = CVAR(g_pickup_shells_max);
    g_pickup_nails                     = CVAR(g_pickup_nails);
    g_pickup_nails_max                 = CVAR(g_pickup_nails_max);
    g_pickup_rockets                   = CVAR(g_pickup_rockets);
    g_pickup_rockets_max               = CVAR(g_pickup_rockets_max);
    g_pickup_cells                     = CVAR(g_pickup_cells);
    g_pickup_cells_max                 = CVAR(g_pickup_cells_max);
    g_pickup_fuel                      = CVAR(g_pickup_fuel);
    g_pickup_fuel_jetpack              = CVAR(g_pickup_fuel_jetpack);
    g_pickup_fuel_max                  = CVAR(g_pickup_fuel_max);
    g_pickup_armorsmall                = CVAR(g_pickup_armorsmall);
    g_pickup_armorsmall_max            = CVAR(g_pickup_armorsmall_max);
    g_pickup_armormedium               = CVAR(g_pickup_armormedium);
    g_pickup_armormedium_max           = CVAR(g_pickup_armormedium_max);
    g_pickup_armorbig                  = CVAR(g_pickup_armorbig);
    g_pickup_armorbig_max              = CVAR(g_pickup_armorbig_max);
    g_pickup_armorlarge                = CVAR(g_pickup_armorlarge);
    g_pickup_armorlarge_max            = CVAR(g_pickup_armorlarge_max);
    g_pickup_healthsmall               = CVAR(g_pickup_healthsmall);
    g_pickup_healthsmall_max           = CVAR(g_pickup_healthsmall_max);
    g_pickup_healthmedium              = CVAR(g_pickup_healthmedium);
    g_pickup_healthmedium_max          = CVAR(g_pickup_healthmedium_max);
    g_pickup_healthlarge               = CVAR(g_pickup_healthlarge);
    g_pickup_healthlarge_max           = CVAR(g_pickup_healthlarge_max);
    g_pickup_healthmega                = CVAR(g_pickup_healthmega);
    g_pickup_healthmega_max            = CVAR(g_pickup_healthmega_max);

    g_pinata = CVAR(g_pinata);

    g_weapon_stay = CVAR(g_weapon_stay);
    if (!g_weapon_stay && (CVAR(deathmatch) == 2))
        g_weapon_stay = 1;
	g_ghost_items = CVAR(g_ghost_items);
	if(g_ghost_items >= 1)
		g_ghost_items = 0.13; // default alpha value

    if not(inWarmupStage)
        game_starttime                 = CVAR(g_start_delay);

    readplayerstartcvars();

	sv_model_healthmega = cvar_string("sv_model_healthmega");
	if (sv_model_healthmega == "")
		sv_model_healthmega = "models/items/g_h100.md3";
	else
		sv_model_healthmega = strzone(sv_model_healthmega);

	sv_model_healthlarge = cvar_string("sv_model_healthlarge");
	if (sv_model_healthlarge == "")
		sv_model_healthlarge = "models/items/g_h50.md3";
	else
		sv_model_healthlarge = strzone(sv_model_healthlarge);

	sv_model_healthmedium = cvar_string("sv_model_healthmedium");
	if (sv_model_healthmedium == "")
		sv_model_healthmedium = "models/items/g_h25.md3";
	else
		sv_model_healthmedium = strzone(sv_model_healthmedium);

	sv_model_healthsmall = cvar_string("sv_model_healthsmall");
	if (sv_model_healthsmall == "")
		sv_model_healthsmall = "models/items/g_h1.md3";
	else
		sv_model_healthsmall = strzone(sv_model_healthsmall);
}

string entityfieldtypestr(float fld) {
    return switch(entityfieldtype(fld)) {
        case FIELD_STRING   : "string",
        case FIELD_FLOAT    : "float",
        case FIELD_VECTOR   : "vector",
        case FIELD_ENTITY   : "entity",
        case FIELD_FUNCTION : "function",
        default             : "unknown"
    };
}

void dumpent(entity e) {
    print("----------------------------------\n");
    print("ENTITY DUMP: ", etos(e), "\n");
    print("----------------------------------\n");

    var n = numentityfields();
    for(var i = 0; i < n; ++i) {
        var val = getentityfieldstring(i, e);
        if(val != "")
            print("(", entityfieldtypestr(i), ") ", entityfieldname(i), ": ", val, "^7\n");
    }

    print("----------------------------------\n");
}

/*
// TODO sound pack system
string soundpack;

string precache_sound_builtin (string s) = #19;
void(entity e, float chan, string samp, float vol, float atten) sound_builtin = #8;
string precache_sound(string s)
{
	return precache_sound_builtin(strcat(soundpack, s));
}
void play2(entity e, string filename)
{
	stuffcmd(e, strcat("play2 ", soundpack, filename, "\n"));
}
void sound(entity e, float chan, string samp, float vol, float atten)
{
	sound_builtin(e, chan, strcat(soundpack, samp), vol, atten);
}
*/

// Sound functions
string precache_sound (string s) = #19;
void(entity e, float chan, string samp, float vol, float atten) sound_builtin = #8;
float precache_sound_index (string s) = #19;

#define SND_VOLUME      1
#define SND_ATTENUATION 2
#define SND_LARGEENTITY 8
#define SND_LARGESOUND  16

.entity realowner;
.entity WarpZone_refsys;

float sound_allowed(float dest, entity e)
{
    // sounds from world may always pass
    float iter;

    for (;;)
    {
        if (e.classname == "body")
            e = e.enemy;
        if(e.realowner && e.realowner != e)
            e = e.realowner;
        else if (e.owner && e.owner != e && e.owner != e.WarpZone_refsys)
            e = e.owner;
        else
            break;

        if(++iter == 100) {
            bprint("[FIXME] sound_allowed() got stuck in an ownership loop!\n");
            backtrace("sound_allowed() ownership loop");
            dumpent(e);
            dumpent(e.owner);
            dumpent(e.realowner);
            break;
        }
    }
    // sounds to self may always pass
    if (dest == MSG_ONE)
        if (e == msg_entity)
            return TRUE;
    // sounds by players can be removed
    if (CVAR(bot_sound_monopoly))
        if (clienttype(e) == CLIENTTYPE_REAL)
            return FALSE;
    // anything else may pass
    return TRUE;
}

void sound(entity e, float chan, string samp, float vol, float atten)
{
    if (!sound_allowed(MSG_BROADCAST, e))
        return;
    sound_builtin(e, chan, samp, vol, atten);
}
void soundtoat(float dest, entity e, vector o, float chan, string samp, float vol, float atten)
{
    float entno, idx;

    if (!sound_allowed(dest, e))
        return;

    entno = num_for_edict(e);
    idx = precache_sound_index(samp);

    float sflags;
    sflags = 0;

    atten = floor(atten * 64);
    vol = floor(vol * 255);

    if (vol != 255)
        sflags |= SND_VOLUME;
    if (atten != 64)
        sflags |= SND_ATTENUATION;
    if (entno >= 8192)
        sflags |= SND_LARGEENTITY;
    if (idx >= 256)
        sflags |= SND_LARGESOUND;

    WriteByte(dest, SVC_SOUND);
    WriteByte(dest, sflags);
    if (sflags & SND_VOLUME)
        WriteByte(dest, vol);
    if (sflags & SND_ATTENUATION)
        WriteByte(dest, atten);
    if (sflags & SND_LARGEENTITY)
    {
        WriteShort(dest, entno);
        WriteByte(dest, chan);
    }
    else
    {
        WriteShort(dest, entno * 8 + chan);
    }
    if (sflags & SND_LARGESOUND)
        WriteShort(dest, idx);
    else
        WriteByte(dest, idx);

    WriteCoord(dest, o_x);
    WriteCoord(dest, o_y);
    WriteCoord(dest, o_z);
}
void soundto(float dest, entity e, float chan, string samp, float vol, float atten)
{
    vector o;

    if (!sound_allowed(dest, e))
        return;

    o = e.origin + 0.5 * (e.mins + e.maxs);
    soundtoat(dest, e, o, chan, samp, vol, atten);
}
void soundat(entity e, vector o, float chan, string samp, float vol, float atten)
{
    soundtoat(MSG_BROADCAST, e, o, chan, samp, vol, atten);
}
void stopsoundto(float dest, entity e, float chan)
{
    float entno;

    if (!sound_allowed(dest, e))
        return;

    entno = num_for_edict(e);

    if (entno >= 8192)
    {
        float idx, sflags;
        idx = precache_sound_index("misc/null.wav");
        sflags = SND_LARGEENTITY;
        if (idx >= 256)
            sflags |= SND_LARGESOUND;
        WriteByte(dest, SVC_SOUND);
        WriteByte(dest, sflags);
        WriteShort(dest, entno);
        WriteByte(dest, chan);
        if (sflags & SND_LARGESOUND)
            WriteShort(dest, idx);
        else
            WriteByte(dest, idx);
        WriteCoord(dest, e.origin_x);
        WriteCoord(dest, e.origin_y);
        WriteCoord(dest, e.origin_z);
    }
    else
    {
        WriteByte(dest, SVC_STOPSOUND);
        WriteShort(dest, entno * 8 + chan);
    }
}
void stopsound(entity e, float chan)
{
    if (!sound_allowed(MSG_BROADCAST, e))
        return;

    stopsoundto(MSG_BROADCAST, e, chan); // unreliable, gets there fast
    stopsoundto(MSG_ALL, e, chan); // in case of packet loss
}

void play2(entity e, string filename)
{
    //stuffcmd(e, strcat("play2 ", filename, "\n"));
    msg_entity = e;
    soundtoat(MSG_ONE, world, '0 0 0', CHAN_AUTO, filename, VOL_BASE, ATTN_NONE);
}

.float announcetime;
float announce(entity player, string msg)
{
    if (time > player.announcetime)
        if (clienttype(player) == CLIENTTYPE_REAL)
        {
            player.announcetime = time + 0.8;
            play2(player, msg);
            return TRUE;
        }
    return FALSE;
}

/*
 *  announce_game_event ( float, string, string, string )
 * 
 * Used to announce in game events to players and to irc.
 * It will always bprint the announcements.
 * If the cvar (cv_name) is less than or equal to the announcement's
 * verbosity level (v), then the FIRST event will be printed to irc.
 * 
 * Consider event1 to be used for short messages and event2 for long ones.
 */
void announce_game_event(float v, string cv_name, string event1, string event2)
{
	bprint(event1, event2, "\n");
	
	if (cvar(cv_name) > v)
		return;
	
	IRC_Announce_GameEvent(event1);
}

// use this one if you might be causing spam (e.g. from touch functions that might get called more than once per frame)
float spamsound(entity e, float chan, string samp, float vol, float atten)
{
    if (!sound_allowed(MSG_BROADCAST, e))
        return FALSE;

    if (time > e.announcetime)
    {
        e.announcetime = time;
        sound(e, chan, samp, vol, atten);
        return TRUE;
    }
    return FALSE;
}

void play2team(float t, string filename)
{
    entity head;

    if (CVAR(bot_sound_monopoly))
        return;

    FOR_EACH_REALPLAYER(head)
    {
        if (head.team == t)
            play2(head, filename);
    }
}

void play2all(string samp)
{
    if (CVAR(bot_sound_monopoly))
        return;

    sound(world, CHAN_AUTO, samp, VOL_BASE, ATTN_NONE);
}

void PrecachePlayerSounds(string f);
void precache_all_models(string pattern)
{
    float globhandle, i, n;
    string f;

    globhandle = search_begin(pattern, TRUE, FALSE);
    if (globhandle < 0)
        return;
    n = search_getsize(globhandle);
    for (i = 0; i < n; ++i)
    {
		//print(search_getfilename(globhandle, i), "\n");
		f = search_getfilename(globhandle, i);
		if(sv_loddistance1)
			precache_model(f);
		if(substring(f, -9,5) == "_lod1")
			continue;
		if(substring(f, -9,5) == "_lod2")
			continue;
		if(!sv_loddistance1)
			precache_model(f);
		PrecachePlayerSounds(strcat(f, ".sounds"));
    }
    search_end(globhandle);
}

void precache()
{
    precache_sound (RM_SOUND_MORNINGRESCUE);
	precache_sound (RM_SOUND_PHOENIX);
	precache_sound (RM_SOUND_REBIRTH);
	precache_sound (RM_SOUND_RECOVERY);
    precache_sound (RM_SOUND_KILL);
    precache_sound ("misc/scream.wav");
    
    // gamemode related things
    precache_model ("models/misc/chatbubble.spr");
    precache_model ("models/misc/teambubble.spr");

#ifdef TTURRETS_ENABLED
    if (CVAR(g_turrets))
        turrets_precash();
#endif

	precache_model("models/boob.mdl");

    // Precache all player models if desired
    if (CVAR(sv_precacheplayermodels))
    {
        PrecachePlayerSounds("sound/player/default.sounds");
        precache_all_models("models/player/*.zym");
        precache_all_models("models/player/*.dpm");
        precache_all_models("models/player/*.md3");
        precache_all_models("models/player/*.psk");
        //precache_model("models/player/carni.zym");
        //precache_model("models/player/crash.zym");
        //precache_model("models/player/grunt.zym");
        //precache_model("models/player/headhunter.zym");
        //precache_model("models/player/insurrectionist.zym");
        //precache_model("models/player/jeandarc.zym");
        //precache_model("models/player/lurk.zym");
        //precache_model("models/player/lycanthrope.zym");
        //precache_model("models/player/marine.zym");
        //precache_model("models/player/nexus.zym");
        //precache_model("models/player/pyria.zym");
        //precache_model("models/player/shock.zym");
        //precache_model("models/player/skadi.zym");
        //precache_model("models/player/specop.zym");
        //precache_model("models/player/visitant.zym");
    }

    if (CVAR(sv_defaultcharacter))
    {
        string s;
        s = CVAR_STR(sv_defaultplayermodel_red);
        if (s != "")
        {
            precache_model(s);
            PrecachePlayerSounds(strcat(s, ".sounds"));
        }
        s = CVAR_STR(sv_defaultplayermodel_blue);
        if (s != "")
        {
            precache_model(s);
            PrecachePlayerSounds(strcat(s, ".sounds"));
        }
        s = CVAR_STR(sv_defaultplayermodel_yellow);
        if (s != "")
        {
            precache_model(s);
            PrecachePlayerSounds(strcat(s, ".sounds"));
        }
        s = CVAR_STR(sv_defaultplayermodel_pink);
        if (s != "")
        {
            precache_model(s);
            PrecachePlayerSounds(strcat(s, ".sounds"));
        }
        s = CVAR_STR(sv_defaultplayermodel);
        if (s != "")
        {
            precache_model(s);
            PrecachePlayerSounds(strcat(s, ".sounds"));
        }
    }

    if (g_footsteps)
    {
        PrecacheGlobalSound((globalsound_step = "misc/footstep0 6"));
        PrecacheGlobalSound((globalsound_metalstep = "misc/metalfootstep0 6"));
    }

    // gore and miscellaneous sounds
    //precache_sound ("misc/h2ohit.wav");
    precache_model ("models/hook.md3");
    precache_sound ("misc/armorimpact.wav");
    precache_sound ("misc/bodyimpact1.wav");
    precache_sound ("misc/bodyimpact2.wav");
    precache_sound ("misc/gib.wav");
    precache_sound ("misc/gib_splat01.wav");
    precache_sound ("misc/gib_splat02.wav");
    precache_sound ("misc/gib_splat03.wav");
    precache_sound ("misc/gib_splat04.wav");
    precache_sound ("misc/hit.wav");
    PrecacheGlobalSound((globalsound_fall = "misc/hitground 4"));
    PrecacheGlobalSound((globalsound_metalfall = "misc/metalhitground 4"));
    precache_sound ("misc/null.wav");
    precache_sound ("misc/spawn.wav");
    precache_sound ("misc/talk.wav");
    precache_sound ("misc/teleport.wav");
    precache_sound ("misc/poweroff.wav");
    precache_sound ("player/lava.wav");
    precache_sound ("player/slime.wav");

    if (g_jetpack)
        precache_sound ("misc/jetpack_fly.wav");

    // announcer sounds - male
    precache_sound ("announcer/male/03kills.wav");
    precache_sound ("announcer/male/05kills.wav");
    precache_sound ("announcer/male/10kills.wav");
    precache_sound ("announcer/male/15kills.wav");
    precache_sound ("announcer/male/20kills.wav");
    precache_sound ("announcer/male/25kills.wav");
    precache_sound ("announcer/male/30kills.wav");
    precache_sound ("announcer/male/botlike.wav");

    // announcer sounds - robotic
    precache_sound ("announcer/robotic/prepareforbattle.wav");
    precache_sound ("announcer/robotic/begin.wav");
    precache_sound ("announcer/robotic/timeoutcalled.wav");
    precache_sound ("announcer/robotic/1fragleft.wav");
    precache_sound ("announcer/robotic/2fragsleft.wav");
    precache_sound ("announcer/robotic/3fragsleft.wav");
    precache_sound ("announcer/robotic/terminated.wav");
    if (g_minstagib)
    {
        precache_sound ("announcer/robotic/lastsecond.wav");
        precache_sound ("announcer/robotic/narrowly.wav");
    }

    precache_model ("models/sprites/0.spr32");
    precache_model ("models/sprites/1.spr32");
    precache_model ("models/sprites/2.spr32");
    precache_model ("models/sprites/3.spr32");
    precache_model ("models/sprites/4.spr32");
    precache_model ("models/sprites/5.spr32");
    precache_model ("models/sprites/6.spr32");
    precache_model ("models/sprites/7.spr32");
    precache_model ("models/sprites/8.spr32");
    precache_model ("models/sprites/9.spr32");
    precache_model ("models/sprites/10.spr32");
    precache_sound ("announcer/robotic/1.wav");
    precache_sound ("announcer/robotic/2.wav");
    precache_sound ("announcer/robotic/3.wav");
    precache_sound ("announcer/robotic/4.wav");
    precache_sound ("announcer/robotic/5.wav");
    precache_sound ("announcer/robotic/6.wav");
    precache_sound ("announcer/robotic/7.wav");
    precache_sound ("announcer/robotic/8.wav");
    precache_sound ("announcer/robotic/9.wav");
    precache_sound ("announcer/robotic/10.wav");

    // common weapon precaches
    precache_sound ("weapons/weapon_switch.wav");
    precache_sound ("weapons/weaponpickup.wav");
    precache_sound ("weapons/unavailable.wav");
    
    if(g_grappling_hook) {
        precache_sound ("weapons/hook_fire.wav"); // hook
        precache_sound ("weapons/hook_impact.wav"); // hook
    }

    if(g_nadgets) {
        HG_Precache();
    }

    if (CVAR(sv_precacheweapons) || g_nixnex)
    {
        //precache weapon models/sounds
        float wep;
        wep = WEP_FIRST;
        while (wep <= WEP_LAST)
        {
            weapon_precache(wep);
            wep = wep + 1;
        }
    }

    precache_model("models/elaser.mdl");
    precache_model("models/laser.mdl");
    precache_model("models/ebomb.mdl");
}

// sorry, but using \ in macros breaks line numbers
#define WRITESPECTATABLE_MSG_ONE_VARNAME(varname,statement) entity varname; varname = msg_entity; FOR_EACH_REALCLIENT(msg_entity) if(msg_entity.clientcamera == varname) statement msg_entity = varname
#define WRITESPECTATABLE_MSG_ONE(statement) WRITESPECTATABLE_MSG_ONE_VARNAME(oldmsg_entity, statement)
#define WRITESPECTATABLE(msg,statement) if(msg == MSG_ONE) { WRITESPECTATABLE_MSG_ONE(statement); } else statement float WRITESPECTATABLE_workaround = 0

vector ExactTriggerHit_mins;
vector ExactTriggerHit_maxs;
float ExactTriggerHit_Recurse()
{
    float s;
    entity se;
    float f;

    tracebox('0 0 0', ExactTriggerHit_mins, ExactTriggerHit_maxs, '0 0 0', MOVE_NORMAL, other);
    if not(trace_ent)
        return 0;
    if (trace_ent == self)
        return 1;

    se = trace_ent;
    s = se.solid;
    se.solid = SOLID_NOT;
    f = ExactTriggerHit_Recurse();
    se.solid = s;

    return f;
}

float ExactTriggerHit()
{
    float f, s;

    if not(self.modelindex)
        return 1;

    s = self.solid;
    self.solid = SOLID_BSP;
    ExactTriggerHit_mins = other.absmin;
    ExactTriggerHit_maxs = other.absmax;
    f = ExactTriggerHit_Recurse();
    self.solid = s;

    return f;
}

// WARNING: this kills the trace globals
#define EXACTTRIGGER_TOUCH if not(ExactTriggerHit()) return
#define EXACTTRIGGER_INIT  InitSolidBSPTrigger(); self.solid = SOLID_TRIGGER

#define INITPRIO_FIRST              0
#define INITPRIO_GAMETYPE           0
#define INITPRIO_GAMETYPE_FALLBACK  1
#define INITPRIO_CVARS              5
#define INITPRIO_FINDTARGET        10
#define INITPRIO_DROPTOFLOOR       20
#define INITPRIO_SETLOCATION       90
#define INITPRIO_LINKDOORS         91
#define INITPRIO_LAST              99

.void(void) initialize_entity;
.float initialize_entity_order;
.entity initialize_entity_next;
entity initialize_entity_first;

void make_safe_for_remove(entity e)
{
    if (e.initialize_entity)
    {
        entity ent, prev;
        for (ent = initialize_entity_first; ent; )
        {
            if ((ent == e) || ((ent.classname == "initialize_entity") && (ent.enemy == e)))
            {
                //print("make_safe_for_remove: getting rid of initializer ", etos(ent), "\n");
                // skip it in linked list
                if (prev)
                {
                    prev.initialize_entity_next = ent.initialize_entity_next;
                    ent = prev.initialize_entity_next;
                }
                else
                {
                    initialize_entity_first = ent.initialize_entity_next;
                    ent = initialize_entity_first;
                }
            }
            else
            {
                prev = ent;
                ent = ent.initialize_entity_next;
            }
        }
    }
}

void objerror(string s)
{
    make_safe_for_remove(self);
    objerror_builtin(s);
}

void remove_unsafely(entity e)
{
    remove_builtin(e);
}

void remove_safely(entity e)
{
    make_safe_for_remove(e);
    remove_builtin(e);
}

void InitializeEntity(entity e, void(void) func, float order)
{
    entity prev, cur;

    if (!e || e.initialize_entity)
    {
        // make a proxy initializer entity
        entity e_old;
        e_old = e;
        e = spawn();
        e.classname = "initialize_entity";
        e.enemy = e_old;
    }

    e.initialize_entity = func;
    e.initialize_entity_order = order;

    cur = initialize_entity_first;
    for (;;)
    {
        if (!cur || cur.initialize_entity_order > order)
        {
            // insert between prev and cur
            if (prev)
                prev.initialize_entity_next = e;
            else
                initialize_entity_first = e;
            e.initialize_entity_next = cur;
            return;
        }
        prev = cur;
        cur = cur.initialize_entity_next;
    }
}
void InitializeEntitiesRun()
{
    entity startoflist;
    startoflist = initialize_entity_first;
    initialize_entity_first = world;
    for (self = startoflist; self; )
    {
        entity e;
        var void(void) func;
        e = self.initialize_entity_next;
        func = self.initialize_entity;
        self.initialize_entity_order = 0;
        self.initialize_entity = NULL;
        self.initialize_entity_next = world;
        if (self.classname == "initialize_entity")
        {
            entity e_old;
            e_old = self.enemy;
            remove_builtin(self);
            self = e_old;
        }
        //dprint("Delayed initialization: ", self.classname, "\n");
        func();
        self = e;
    }
}

.float uncustomizeentityforclient_set;
.void(void) uncustomizeentityforclient;
void(void) SUB_Nullpointer = #0;
void UncustomizeEntitiesRun()
{
    entity oldself;
    oldself = self;
    for (self = world; (self = findfloat(self, uncustomizeentityforclient_set, 1)); )
        self.uncustomizeentityforclient();
    self = oldself;
}
void SetCustomizer(entity e, float(void) customizer, void(void) uncustomizer)
{
    e.customizeentityforclient = customizer;
    e.uncustomizeentityforclient = uncustomizer;
    e.uncustomizeentityforclient_set = (uncustomizer != SUB_Nullpointer);
}

.float nottargeted;
#define IFTARGETED if(!self.nottargeted && self.targetname != "")

void() SUB_Remove;
void Net_LinkEntity(entity e, float docull, float dt, float(entity, float) sendfunc)
{
    vector mi, ma;

    if (e.classname == "")
        e.classname = "net_linked";

    if (e.model == "" || self.modelindex == 0)
    {
        mi = e.mins;
        ma = e.maxs;
        setmodel(e, "null");
        setsize(e, mi, ma);
    }

    e.SendEntity = sendfunc;
    e.SendFlags = 0xFFFFFF;

    if (!docull)
        e.effects |= EF_NODEPTHTEST;

    if (dt)
    {
        e.nextthink = time + dt;
        e.think = SUB_Remove;
    }
}

void adaptor_think2touch()
{
    entity o;
    o = other;
    other = world;
    self.touch();
    other = o;
}

void adaptor_think2use()
{
    entity o, a;
    o = other;
    a = activator;
    activator = world;
    other = world;
    self.use();
    other = o;
    activator = a;
}

// deferred dropping
void DropToFloor_Handler()
{
    droptofloor_builtin();
    self.dropped_origin = self.origin;
}

void droptofloor()
{
    InitializeEntity(self, DropToFloor_Handler, INITPRIO_DROPTOFLOOR);
}



float trace_hits_box_a0, trace_hits_box_a1;

float trace_hits_box_1d(float end, float thmi, float thma)
{
    if (end == 0)
    {
        // just check if x is in range
        if (0 < thmi)
            return FALSE;
        if (0 > thma)
            return FALSE;
    }
    else
    {
        // do the trace with respect to x
        // 0 -> end has to stay in thmi -> thma
        trace_hits_box_a0 = max(trace_hits_box_a0, min(thmi / end, thma / end));
        trace_hits_box_a1 = min(trace_hits_box_a1, max(thmi / end, thma / end));
        if (trace_hits_box_a0 > trace_hits_box_a1)
            return FALSE;
    }
    return TRUE;
}

float trace_hits_box(vector start, vector end, vector thmi, vector thma)
{
    end -= start;
    thmi -= start;
    thma -= start;
    // now it is a trace from 0 to end

    trace_hits_box_a0 = 0;
    trace_hits_box_a1 = 1;

    if (!trace_hits_box_1d(end_x, thmi_x, thma_x))
        return FALSE;
    if (!trace_hits_box_1d(end_y, thmi_y, thma_y))
        return FALSE;
    if (!trace_hits_box_1d(end_z, thmi_z, thma_z))
        return FALSE;

    return TRUE;
}

float tracebox_hits_box(vector start, vector mi, vector ma, vector end, vector thmi, vector thma)
{
    return trace_hits_box(start, end, thmi - ma, thma - mi);
}

float SUB_NoImpactCheck()
{
	// zero hitcontents = this is not the real impact, but either the
	// mirror-impact of something hitting the projectile instead of the
	// projectile hitting the something, or a touchareagrid one. Neither of
	// these stop the projectile from moving, so...
	if(trace_dphitcontents == 0) {
		dprint("A hit happened with zero hit contents... DEBUG THIS, this should never happen for projectiles!\n");
		checkclient();
	}

    if(trace_dphitq3surfaceflags & Q3SURFACEFLAG_NOIMPACT)
        return 1;

    return 0;
}

#define SUB_OwnerCheck() (other && (other == self.owner))

float projectile_skipnonsolid()
{
	if(!other && (trace_dphitq3surfaceflags & Q3SURFACEFLAG_NONSOLID) && !(trace_dphitcontents & self.dphitcontentsmask)) {
		//Trying correct origin
		tracebox_skipnonsolid(self.origin, self.mins, self.maxs, self.origin + (self.velocity * (1 - trace_fraction) * frametime), FALSE, self);
		if (trace_fraction == 1) // The way is clear
			setorigin(self, trace_endpos);
		else // We can't move right to trace_endpos, because we can go through solid surface.
			setorigin(self, self.origin + ((trace_endpos - self.origin) * 0.99));
		UpdateCSQCProjectileNextFrame(self);
		return TRUE;
	}
	return FALSE;
}

#define PROJECTILE_SKIPNONSOLID if (WarpZone_Projectile_Touch() || (CVAR(sv_gameplayfix_zerohitcontents) && projectile_skipnonsolid())) { return; }
#define PROJECTILE_TOUCH do { PROJECTILE_SKIPNONSOLID if(SUB_OwnerCheck()) return; if(SUB_NoImpactCheck()) { remove(self); return; } if(trace_ent && trace_ent.solid > SOLID_TRIGGER) UpdateCSQCProjectileNextFrame(self); } while(0)

float MAX_IPBAN_URIS = 16;

float URI_GET_DISCARD   = 0;
float URI_GET_IPBAN     = 1;
float URI_GET_IPBAN_END = 16;
//float URI_GET_IP2C = 17; // Moved to common/ip2c.qh
float URI_GET_RADIO = 18;

void URI_Get_Callback(float id, float status, string data)
{
    dprint("Received HTTP request data for id ", ftos(id), "; status is ", ftos(status), "\nData is:\n");
    dprint(data);
    dprint("\nEnd of data.\n");

    if (id == URI_GET_DISCARD)
    {
        // discard
    }
    else if (id >= URI_GET_IPBAN && id <= URI_GET_IPBAN_END)
    {
        // online ban list
        OnlineBanList_URI_Get_Callback(id, status, data);
    }
    else if (id == URI_GET_IP2C)
    {
        IP2C_URI_Get_Callback(id, status, data);
    }
    else if (id == URI_GET_RADIO)
    {
        Radio_URI_Get_Callback(id, status, data);
    }
    else
    {
        print("Received HTTP request data for an invalid id ", ftos(id), ".\n");
    }
}

void print_to(entity e, string s)
{
    if (e)
        sprint(e, strcat(s, "\n"));
    else
        print(s, "\n");
}

string getrecords()
{
    float rec;
    string h;
    float r;
    float i;
    string s;

    rec = 0;

    s = "";

    if (g_ctf)
    {
        for (i = 0; i < MapInfo_count; ++i)
        {
            if (MapInfo_Get_ByID(i))
            {
                r = stof(db_get(ServerProgsDB, strcat(MapInfo_Map_bspname, "/captimerecord/time")));
                if (r == 0)
                    continue;
                h = db_get(ServerProgsDB, strcat(MapInfo_Map_bspname, "/captimerecord/netname"));
                s = strcat(s, strpad(32, MapInfo_Map_bspname), " ", strpad(-6, ftos_decimals(r, 2)), " ", h, "\n");
                ++rec;
            }
        }
    }

    if (g_race)
    {
        for (i = 0; i < MapInfo_count; ++i)
        {
            if (MapInfo_Get_ByID(i))
            {
                r = stof(db_get(ServerProgsDB, strcat(MapInfo_Map_bspname, RACE_RECORD, "time")));
                if (r == 0)
                    continue;
                h = db_get(ServerProgsDB, strcat(MapInfo_Map_bspname, RACE_RECORD, "netname"));
                s = strcat(s, strpad(32, MapInfo_Map_bspname), " ", strpad(-8, TIME_ENCODED_TOSTRING(r)), " ", h, "\n");
                ++rec;
            }
        }
    }

    if (g_cts)
    {
        for (i = 0; i < MapInfo_count; ++i)
        {
            if (MapInfo_Get_ByID(i))
            {
                r = stof(db_get(ServerProgsDB, strcat(MapInfo_Map_bspname, CTS_RECORD, "time")));
                if (r == 0)
                    continue;
                h = db_get(ServerProgsDB, strcat(MapInfo_Map_bspname, CTS_RECORD, "netname"));
                s = strcat(s, strpad(32, MapInfo_Map_bspname), " ", strpad(-8, TIME_ENCODED_TOSTRING(r)), " ", h, "\n");
                ++rec;
            }
        }
    }

    MapInfo_ClearTemps();

    if (s == "")
        return "No records are available on this server.\n";
    else
        return strcat("Records on this server:\n", s);
}

float MoveToRandomMapLocation(entity e, float goodcontents, float badcontents, float badsurfaceflags, float attempts, float maxaboveground, float minviewdistance)
{
    float m, i;
    vector start, org, delta, end, enddown, mstart;
    entity sp;

    m = e.dphitcontentsmask;
    e.dphitcontentsmask = goodcontents | badcontents;

    org = world.mins;
    delta = world.maxs - world.mins;

    start = end = org;

    for (i = 0; i < attempts; ++i)
    {
        start_x = org_x + random() * delta_x;
        start_y = org_y + random() * delta_y;
        start_z = org_z + random() * delta_z;

        // rule 1: start inside world bounds, and outside
        // solid, and don't start from somewhere where you can
        // fall down to evil
        tracebox(start, e.mins, e.maxs, start - '0 0 1' * delta_z, MOVE_NORMAL, e);
        if (trace_fraction >= 1)
            continue;
        if (trace_startsolid)
            continue;
        if (trace_dphitcontents & badcontents)
            continue;
        if (trace_dphitq3surfaceflags & badsurfaceflags)
            continue;

        // rule 2: if we are too high, lower the point
        if (trace_fraction * delta_z > maxaboveground)
            start = trace_endpos + '0 0 1' * maxaboveground;
        enddown = trace_endpos;

        // rule 3: make sure we aren't outside the map. This only works
        // for somewhat well formed maps. A good rule of thumb is that
        // the map should have a convex outside hull.
        // these can be traceLINES as we already verified the starting box
        mstart = start + 0.5 * (e.mins + e.maxs);
        traceline(mstart, mstart + '1 0 0' * delta_x, MOVE_NORMAL, e);
        if (trace_fraction >= 1 || trace_dphittexturename == "common/caulk")
            continue;
        traceline(mstart, mstart - '1 0 0' * delta_x, MOVE_NORMAL, e);
        if (trace_fraction >= 1 || trace_dphittexturename == "common/caulk")
            continue;
        traceline(mstart, mstart + '0 1 0' * delta_y, MOVE_NORMAL, e);
        if (trace_fraction >= 1 || trace_dphittexturename == "common/caulk")
            continue;
        traceline(mstart, mstart - '0 1 0' * delta_y, MOVE_NORMAL, e);
        if (trace_fraction >= 1 || trace_dphittexturename == "common/caulk")
            continue;
        traceline(mstart, mstart + '0 0 1' * delta_z, MOVE_NORMAL, e);
        if (trace_fraction >= 1 || trace_dphittexturename == "common/caulk")
            continue;

	// rule 4: we must "see" some spawnpoint or item
	for(sp = world; (sp = find(sp, classname, "info_player_deathmatch")); )
		if(checkpvs(mstart, sp))
			if((traceline(mstart, sp.origin, MOVE_NORMAL, e), trace_fraction) >= 1)
				break;
	if(!sp)
	{
		for(sp = world; (sp = findflags(sp, flags, FL_ITEM)); )
			if(checkpvs(mstart, sp))
				if((traceline(mstart, sp.origin + (sp.mins + sp.maxs) * 0.5, MOVE_NORMAL, e), trace_fraction) >= 1)
					break;
		if(!sp)
			continue;
	}

        // find a random vector to "look at"
        end_x = org_x + random() * delta_x;
        end_y = org_y + random() * delta_y;
        end_z = org_z + random() * delta_z;
        end = start + normalize(end - start) * vlen(delta);

        // rule 4: start TO end must not be too short
        tracebox(start, e.mins, e.maxs, end, MOVE_NORMAL, e);
        if (trace_startsolid)
            continue;
        if (trace_fraction < minviewdistance / vlen(delta))
            continue;

        // rule 5: don't want to look at sky
        if (trace_dphitq3surfaceflags & Q3SURFACEFLAG_SKY)
            continue;

        // rule 6: we must not end up in trigger_hurt
        if (tracebox_hits_trigger_hurt(start, e.mins, e.maxs, enddown))
            continue;

        break;
    }

    e.dphitcontentsmask = m;

    if (i < attempts)
    {
        setorigin(e, start);
        e.angles = vectoangles(end - start);
        dprint("Needed ", ftos(i + 1), " attempts\n");
        return TRUE;
    }
    else
        return FALSE;
}

float zcurveparticles_effectno;
vector zcurveparticles_start;
float zcurveparticles_spd;

void endzcurveparticles()
{
	if(zcurveparticles_effectno)
	{
		// terminator
		WriteShort(MSG_BROADCAST, zcurveparticles_spd | 0x8000);
	}
	zcurveparticles_effectno = 0;
}

void zcurveparticles(float effectno, vector start, vector end, float end_dz, float spd)
{
	spd = bound(0, floor(spd / 16), 32767);
	if(effectno != zcurveparticles_effectno || start != zcurveparticles_start)
	{
		endzcurveparticles();
		WriteByte(MSG_BROADCAST, SVC_TEMPENTITY);
		WriteByte(MSG_BROADCAST, TE_CSQC_ZCURVEPARTICLES);
		WriteShort(MSG_BROADCAST, effectno);
		WriteCoord(MSG_BROADCAST, start_x);
		WriteCoord(MSG_BROADCAST, start_y);
		WriteCoord(MSG_BROADCAST, start_z);
		zcurveparticles_effectno = effectno;
		zcurveparticles_start = start;
	}
	else
		WriteShort(MSG_BROADCAST, zcurveparticles_spd);
	WriteCoord(MSG_BROADCAST, end_x);
	WriteCoord(MSG_BROADCAST, end_y);
	WriteCoord(MSG_BROADCAST, end_z);
	WriteCoord(MSG_BROADCAST, end_dz);
	zcurveparticles_spd = spd;
}

void zcurveparticles_from_tracetoss(float effectno, vector start, vector end, vector vel)
{
	float end_dz;
	vector vecxy, velxy;

	vecxy = end - start;
	vecxy_z = 0;
	velxy = vel;
	velxy_z = 0;

	if (vlen(velxy) < 0.000001 * fabs(vel_z))
	{
		endzcurveparticles();
		trailparticles(world, effectno, start, end);
		return;
	}

	end_dz = vlen(vecxy) / vlen(velxy) * vel_z - (end_z - start_z);
	zcurveparticles(effectno, start, end, end_dz, vlen(vel));
}

void write_recordmarker(entity pl, float tstart, float dt)
{
    GameLogEcho(strcat(":recordset:", ftos(pl.playerid), ":", ftos(dt)));

    // also write a marker into demo files for demotc-race-record-extractor to find
    stuffcmd(pl,
             strcat(
                 strcat("//", strconv(2, 0, 0, gametype_ID_to_Name(game)), " RECORD SET ", TIME_ENCODED_TOSTRING(TIME_ENCODE(dt))),
                 " ", ftos(tstart), " ", ftos(dt), "\n"));
}

vector shotorg_adjustfromclient(vector vecs, float y_is_right, float allowcenter)
{
	switch(self.owner.cvar_cl_gunalign)
	{
		case 1: // right
			break;

		case 2: // left
			vecs_y = -vecs_y;
			break;

		default:
		case 3:
			if(allowcenter) // 2: allow center handedness
			{
				// center
				vecs_y = 0;
				vecs_z -= 4;
			}
			else
			{
				// right
			}
			break;

		case 4:
			if(allowcenter) // 2: allow center handedness
			{
				// center
				vecs_y = 0;
				vecs_z -= 4;
			}
			else
			{
				// left
				vecs_y = -vecs_y;
			}
			break;
	}
	return vecs;
}

vector shotorg_adjust(vector vecs, float y_is_right, float visual, float akimbo_active)
{
	string s;
	vector v;

    if (akimbo_active)
    {
        if (akimbo_active == 2)
            vecs_y = -vecs_y;
        if not(visual)
        {
            if (CVAR(g_shootfromeye))
                vecs_z = 0;
            else if (CVAR(g_shootfromcenter))
                vecs_z -= 0;
            else if ((s = CVAR_STR(g_shootfromfixedorigin)) != "")
            {
                v = stov(s);
                if (v_x != 0)
                    vecs_x = v_x;
                vecs_z = v_z;
            }
        }
        vecs_y = vecs_y * 1.2;
        return vecs;
    }

	if (CVAR(g_shootfromeye))
	{
		if (visual)
		{
			vecs = shotorg_adjustfromclient(vecs, y_is_right, TRUE);
		}
		else
		{
			vecs_y = 0;
			vecs_z = 0;
		}
	}
	else if (CVAR(g_shootfromcenter))
	{
		if (visual)
		{
			vecs = shotorg_adjustfromclient(vecs, y_is_right, TRUE);
		}
		else
		{
			vecs_y = 0;
			vecs_z -= 4;
		}
	}
	else if (CVAR(g_shootfromclient))
	{
		vecs = shotorg_adjustfromclient(vecs, y_is_right, (CVAR(g_shootfromclient) >= 2));
	}
	else if ((s = CVAR_STR(g_shootfromfixedorigin)) != "")
	{
		v = stov(s);
		if (y_is_right)
			v_y = -v_y;
		if (v_x != 0)
			vecs_x = v_x;
		vecs_y = v_y;
		vecs_z = v_z;
	}
	return vecs;
}

void attach_sameorigin(entity e, entity to, string tag)
{
    vector org, t_forward, t_left, t_up, e_forward, e_up;
    vector org0, ang0;
    float tagscale;

    ang0 = e.angles;
    org0 = e.origin;

    org = e.origin - gettaginfo(to, gettagindex(to, tag));
    tagscale = pow(vlen(v_forward), -2); // undo a scale on the tag
    t_forward = v_forward * tagscale;
    t_left = v_right * -tagscale;
    t_up = v_up * tagscale;

    e.origin_x = org * t_forward;
    e.origin_y = org * t_left;
    e.origin_z = org * t_up;

    // current forward and up directions
    if (substring(e.model, 0, 1) == "*") // bmodels have their own rules
        e.angles_x = -e.angles_x;
    fixedmakevectors2(e.angles);

    // untransform forward, up!
    e_forward_x = v_forward * t_forward;
    e_forward_y = v_forward * t_left;
    e_forward_z = v_forward * t_up;
    e_up_x = v_up * t_forward;
    e_up_y = v_up * t_left;
    e_up_z = v_up * t_up;

    e.angles = fixedvectoangles2(e_forward, e_up);
    if (substring(e.model, 0, 1) == "*") // bmodels have their own rules
        e.angles_x = -e.angles_x;

    setattachment(e, to, tag);
    setorigin(e, e.origin);
}

void detach_sameorigin(entity e)
{
    vector org;
    org = gettaginfo(e, 0);
    e.angles = fixedvectoangles2(v_forward, v_up);
    if (substring(e.model, 0, 1) == "*") // bmodels have their own rules
        e.angles_x = -e.angles_x;
    setorigin(e, org);
    setattachment(e, world, "");
    setorigin(e, e.origin);
}

void follow_sameorigin(entity e, entity to)
{
    e.movetype = MOVETYPE_FOLLOW; // make the hole follow
    e.aiment = to; // make the hole follow bmodel
    e.punchangle = to.angles; // the original angles of bmodel
    e.view_ofs = e.origin - to.origin; // relative origin
    e.v_angle = e.angles - to.angles; // relative angles
}

void unfollow_sameorigin(entity e)
{
    e.movetype = MOVETYPE_NONE;
}

entity gettaginfo_relative_ent;
vector gettaginfo_relative(entity e, float tag)
{
    if (!gettaginfo_relative_ent)
    {
        gettaginfo_relative_ent = spawn();
        gettaginfo_relative_ent.effects = EF_NODRAW;
    }
    gettaginfo_relative_ent.model = e.model;
    gettaginfo_relative_ent.modelindex = e.modelindex;
    gettaginfo_relative_ent.frame = e.frame;
    return gettaginfo(gettaginfo_relative_ent, tag);
}

void SoundEntity_StartSound(entity pl, float chan, string samp, float vol, float attn)
{
    float p;
    p = pow(2, chan);
    if (pl.soundentity.cnt & p)
        return;
    soundtoat(MSG_ALL, pl.soundentity, gettaginfo(pl.soundentity, 0), chan, samp, vol, attn);
    pl.soundentity.cnt |= p;
}

void SoundEntity_StopSound(entity pl, float chan)
{
    float p;
    p = pow(2, chan);
    if (pl.soundentity.cnt & p)
    {
        stopsoundto(MSG_ALL, pl.soundentity, chan);
        pl.soundentity.cnt &~= p;
    }
}

void SoundEntity_Attach(entity pl)
{
    pl.soundentity = spawn();
    pl.soundentity.classname = "soundentity";
    pl.soundentity.owner = pl;
    setattachment(pl.soundentity, pl, "");
    setmodel(pl.soundentity, "null");
}

void SoundEntity_Detach(entity pl)
{
    float i;
    for (i = 0; i <= 7; ++i)
        SoundEntity_StopSound(pl, i);
}


float ParseCommandPlayerSlotTarget_firsttoken;
entity GetCommandPlayerSlotTargetFromTokenizedCommand(float tokens, float idx) // idx = start index
{
    string s;
    entity e, head;
    float n;

    s = NULL;

    ParseCommandPlayerSlotTarget_firsttoken = -1;

    if (tokens > idx)
    {
        if (substring(argv(idx), 0, 1) == "#")
        {
            s = substring(argv(idx), 1, -1);
            ++idx;
            if (s == "")
                if (tokens > idx)
                {
                    s = argv(idx);
                    ++idx;
                }
			ParseCommandPlayerSlotTarget_firsttoken = idx;
            if (s == ftos(stof(s)))
            {
                e = edict_num(stof(s));
                if (e.flags & FL_CLIENT)
                    return e;
            }
        }
        else
        {
            // it must be a nick name
            s = argv(idx);
            ++idx;
			ParseCommandPlayerSlotTarget_firsttoken = idx;

            n = 0;
            FOR_EACH_CLIENT(head)
            if (head.netname == s)
            {
                e = head;
                ++n;
            }
            if (n == 1)
                return e;

            s = strdecolorize(s);
            n = 0;
            FOR_EACH_CLIENT(head)
            if (strdecolorize(head.netname) == s)
            {
                e = head;
                ++n;
            }
            if (n == 1)
                return e;
        }
    }

    return world;
}

.float scale2;

float modeleffect_SendEntity(entity to, float sf)
{
	float f;
	WriteByte(MSG_ENTITY, ENT_CLIENT_MODELEFFECT);

	f = 0;
	if(self.velocity != '0 0 0')
		f |= 1;
	if(self.angles != '0 0 0')
		f |= 2;
	if(self.avelocity != '0 0 0')
		f |= 4;

	WriteByte(MSG_ENTITY, f);
	WriteShort(MSG_ENTITY, self.modelindex);
	WriteByte(MSG_ENTITY, self.skin);
	WriteByte(MSG_ENTITY, self.frame);
	WriteCoord(MSG_ENTITY, self.origin_x);
	WriteCoord(MSG_ENTITY, self.origin_y);
	WriteCoord(MSG_ENTITY, self.origin_z);
	if(f & 1)
	{
		WriteCoord(MSG_ENTITY, self.velocity_x);
		WriteCoord(MSG_ENTITY, self.velocity_y);
		WriteCoord(MSG_ENTITY, self.velocity_z);
	}
	if(f & 2)
	{
		WriteCoord(MSG_ENTITY, self.angles_x);
		WriteCoord(MSG_ENTITY, self.angles_y);
		WriteCoord(MSG_ENTITY, self.angles_z);
	}
	if(f & 4)
	{
		WriteCoord(MSG_ENTITY, self.avelocity_x);
		WriteCoord(MSG_ENTITY, self.avelocity_y);
		WriteCoord(MSG_ENTITY, self.avelocity_z);
	}
	WriteShort(MSG_ENTITY, self.scale * 256.0);
	WriteShort(MSG_ENTITY, self.scale2 * 256.0);
	WriteByte(MSG_ENTITY, self.teleport_time * 100.0);
	WriteByte(MSG_ENTITY, self.fade_time * 100.0);
	WriteByte(MSG_ENTITY, self.alpha * 255.0);

	return TRUE;
}

void modeleffect_spawn(string m, float s, float f, vector o, vector v, vector ang, vector angv, float s0, float s2, float a, float t1, float t2)
{
	entity e;
	float sz;
	e = spawn();
	e.classname = "modeleffect";
	setmodel(e, m);
	e.frame = f;
	setorigin(e, o);
	e.velocity = v;
	e.angles = ang;
	e.avelocity = angv;
	e.alpha = a;
	e.teleport_time = t1;
	e.fade_time = t2;
	e.skin = s;
	if(s0 >= 0)
		e.scale = s0 / max6(-e.mins_x, -e.mins_y, -e.mins_z, e.maxs_x, e.maxs_y, e.maxs_z);
	else
		e.scale = -s0;
	if(s2 >= 0)
		e.scale2 = s2 / max6(-e.mins_x, -e.mins_y, -e.mins_z, e.maxs_x, e.maxs_y, e.maxs_z);
	else
		e.scale2 = -s2;
	sz = max(e.scale, e.scale2);
	setsize(e, e.mins * sz, e.maxs * sz);
	Net_LinkEntity(e, FALSE, 0.1, modeleffect_SendEntity);
}

void shockwave_spawn(string m, vector org, float sz, float t1, float t2)
{
	return modeleffect_spawn(m, 0, 0, org, '0 0 0', '0 0 0', '0 0 0', 0, sz, 1, t1, t2);
}

float randombit(float bits)
{
	if not(bits & (bits-1)) // this ONLY holds for powers of two!
		return bits;

	float n, f, b, r;

	r = random();
	b = 0;
	n = 0;

	for(f = 1; f <= bits; f *= 2)
	{
		if(bits & f)
		{
			++n;
			r *= n;
			if(r <= 1)
				b = f;
			else
				r = (r - 1) / (n - 1);
		}
	}

	return b;
}

float randombits(float bits, float k, float error_return)
{
	float r;
	r = 0;
	while(k > 0 && bits != r)
	{
		r += randombit(bits - r);
		--k;
	}
	if(error_return)
		if(k > 0)
			return -1; // all
	return r;
}

void randombit_test(float bits, float iter)
{
	while(iter > 0)
	{
		print(ftos(randombit(bits)), "\n");
		--iter;
	}
}

float ExponentialFalloff(float mindist, float maxdist, float halflifedist, float d)
{
	if(halflifedist > 0)
		return pow(0.5, (bound(mindist, d, maxdist) - mindist) / halflifedist);
	else if(halflifedist < 0)
		return pow(0.5, (bound(mindist, d, maxdist) - maxdist) / halflifedist);
	else
		return 1;
}

void bigprint(entity e, string bigstring, string comment, float staytime)
{
    if(clienttype(e) != CLIENTTYPE_REAL)
        return;
    
    if(e.classname == "")
        return;
    
    msg_entity = e;
    WriteByte(MSG_ONE, SVC_TEMPENTITY);
    WriteByte(MSG_ONE, TE_CSQC_BIGPRINT);
    WriteString(MSG_ONE, bigstring);
    WriteString(MSG_ONE, comment);
    WriteShort(MSG_ONE, staytime);
}

void centerprint_spec(entity pl, string msg)
{
    FOR_EACH_REALCLIENT(var e) if(e.clientcamera == pl)
        centerprint(e, msg);
}

void bigprint_spec(entity pl, string msg, string comment, float staytime)
{
    FOR_EACH_REALCLIENT(var e) if(e.clientcamera == pl)
        bigprint(e, msg, comment, staytime);
}

void bigprint_clear(entity pl)
{
    msg_entity = pl;
    WriteByte(MSG_ONE, SVC_TEMPENTITY);
    WriteByte(MSG_ONE, TE_CSQC_CLEARBIGPRINT);
}

void bigprint_clear_spec(entity pl)
{
    FOR_EACH_REALCLIENT(var e) if(e.clientcamera == pl)
            bigprint_clear(e);
}

void madokaprint(entity e, string bigstring, string comment, float staytime)
{
    if(clienttype(e) != CLIENTTYPE_REAL)
        return;
    
    if(e.classname == "")
        return;
    
    msg_entity = e;
    WriteByte(MSG_ONE, SVC_TEMPENTITY);
    WriteByte(MSG_ONE, TE_CSQC_MADOKAPRINT);
    WriteString(MSG_ONE, bigstring);
    WriteString(MSG_ONE, comment);
    WriteShort(MSG_ONE, staytime);
}

void madokaprint_spec(entity pl, string msg, string comment, float staytime)
{
    FOR_EACH_REALCLIENT(var e) if(e.clientcamera == pl)
        madokaprint(e, msg, comment, staytime);
}

#define HF_DEFAULT_TIME 1.5
//#define HF_DEFAULT_INT 0.3
#define HF_DEFAULT_INT 0.5
#define HF_DEFAULT_ALPHA 0.4

void hudflash(entity e, vector flashcolor, float staytime, float intensivity, float alph)
{
    if(clienttype(e) != CLIENTTYPE_REAL)
        return;
    
    if(e.classname == "")
        return;
    
    if not(CVAR(sv_hudflash))
		return;
    
    msg_entity = e;
    WriteByte(MSG_ONE, SVC_TEMPENTITY);
    WriteByte(MSG_ONE, TE_CSQC_HUDFLASH);
    //WriteShort(MSG_ONE, compressShortVector(flashcolor));
    
    WriteCoord(MSG_ONE, flashcolor_x);
    WriteCoord(MSG_ONE, flashcolor_y);
    WriteCoord(MSG_ONE, flashcolor_z);
    
    WriteCoord(MSG_ONE, staytime);
    WriteCoord(MSG_ONE, intensivity);
    WriteCoord(MSG_ONE, alph);
}

void hudflash_teamcolor(entity e, float staytime, float intensivity, float alph)
{
    if(clienttype(e) != CLIENTTYPE_REAL)
        return;
    
    if(e.classname == "")
        return;
    
    if not(CVAR(sv_hudflash))
		return;
    
    msg_entity = e;
    WriteByte(MSG_ONE, SVC_TEMPENTITY);
    WriteByte(MSG_ONE, TE_CSQC_HUDFLASH_TEAMCOLOR);
    WriteCoord(MSG_ONE, staytime);
    WriteCoord(MSG_ONE, intensivity);
    WriteCoord(MSG_ONE, alph);
}

void hudflash_spec(entity pl, vector flashcolor, float staytime, float intensivity, float alph)
{
	if not(CVAR(sv_hudflash))
		return;
	
    FOR_EACH_REALCLIENT(var e) if(e.clientcamera == pl)
        hudflash(e, flashcolor, staytime, intensivity, alph);
}

void hudflash_teamcolor_spec(entity pl, float staytime, float intensivity, float alph)
{
	if not(CVAR(sv_hudflash))
		return;

    FOR_EACH_REALCLIENT(var e) if(e.clientcamera == pl)
        hudflash_teamcolor(e, staytime, intensivity, alph);
}

void hudflash_default(entity e, vector flashcolor)
{
    hudflash(e, flashcolor, HF_DEFAULT_TIME, HF_DEFAULT_INT, HF_DEFAULT_ALPHA);
}

void hudflash_default_spec(entity e, vector flashcolor)
{
    hudflash_spec(e, flashcolor, HF_DEFAULT_TIME, HF_DEFAULT_INT, HF_DEFAULT_ALPHA);
}

void hudflash_teamcolor_default(entity e)
{
    hudflash_teamcolor(e, HF_DEFAULT_TIME, HF_DEFAULT_INT, HF_DEFAULT_ALPHA);
}

void hudflash_teamcolor_default_spec(entity e)
{
    hudflash_teamcolor_spec(e, HF_DEFAULT_TIME, HF_DEFAULT_INT, HF_DEFAULT_ALPHA);
}

// universal endround for all supported gametypes
void FreezeTag_EndRound(float);
void tdom_EndRound(float);

#define ENDROUND_TIMEOUT_NORMAL 5
#define ENDROUND_TIMEOUT_IMMEDIATE 0

void EndRound(float tout)
{
    if(g_freezetag)
        FreezeTag_EndRound(tout);
    else if(g_totaldomination)
        tdom_EndRound(tout);
    else if(g_keyhunt)
        kh_FinishRound(tout);
    else if(g_jailbreak)
		JB_EndRound(tout);
    else if(g_clanarena)
        CA_EndRound(tout);
    else
        print("EndRound: gametype is not supported\n");
}

float EndRound_Allowed()
{
    return( g_freezetag
         || g_totaldomination
         || g_keyhunt
         || g_jailbreak
         || g_clanarena);
}

.float is_away;

void MarkAway(entity pl, float force)
{
    if(clienttype(pl) != CLIENTTYPE_REAL)
        return;
    
    if(pl.is_away)
        return;
    
    float idlefor = floor((time - self.parm_idlesince) / 60);
    
    if(pl.classname == "player")
        stuffcmd(pl, "cmd spectate\n");
    stuffcmd(pl, "set _cl_afkstate 1\n");
    
    if(force)
    {
        bprint(pl.netname, " ^4is AFK\n");
        centerprint(pl, "You have been set AFK");
    }
    else
    {
        bprint(pl.netname, " ^4is AFK (idle for ", ftos(idlefor), " minutes)\n");
        centerprint(pl, strcat("You have been set AFK (idle for ", ftos(idlefor), " minutes)"));
    }
    
    pl.is_away = 1;
    
    if(pl.scorekeeper)
        PlayerScore_SetFlags(pl, SPFLAG_AWAY);
    else
        bprint("^1Tried to mark ", pl.netname, "^1 AFK, but they don't have a scorekeeper!\n");

    pl.afkmarktime = time;
}

void UnmarkAway(entity pl)
{
    if(clienttype(pl) != CLIENTTYPE_REAL)
        return;
    
    if(!pl.is_away)
        return;
    
    if(time - pl.afkmarktime < 0.5)
        return;

    stuffcmd(pl, "set _cl_afkstate 0\n");
    
    bprint(pl.netname, " ^4is back\n");
    centerprint(pl, "You are no longer marked AFK");
    pl.is_away = 0;
    
    if(pl.scorekeeper)
        PlayerScore_UnsetFlags(pl, SPFLAG_AWAY);
    else
        bprint("^1Tried to unmark ", pl.netname, "^1 AFK, but they don't have a scorekeeper!\n");
    
    pl.parm_idlesince = time;
}

float CountAFKClients()
{
    entity e;
    float r;
    r = 0;
    FOR_EACH_REALCLIENT(e)
    {
        if(e.is_away)
        {
            ++r;
            //bprint(e.netname, " ^7is away\n");
        }
    }
    return r;
}

float Banning_IsNameBanned (string name)
{
	return stof (db_get (ServerProgsDB, strcat ("nickbanned/", name)));
}

float Banning_BanPlayerByName (string name, string reason)
{
	if (Banning_IsNameBanned (name))
		return 0;
	db_put (ServerProgsDB, strcat ("nickbanned/", name), "1");
	db_put (ServerProgsDB, strcat ("nickbanned_reason/", name), reason);
	return 1;
}

float Banning_UnbanPlayerByName (string name)
{
	if (! Banning_IsNameBanned (name))
		return 0;
	db_put (ServerProgsDB, strcat ("nickbanned/", name), "0");
//	db_put (ServerProgsDB, strcat ("nickbanned_reason/", name), "");
//	leave the reason so we can know why was the chap banned in the first place
	return 1;
}

string GetVoteList_VoteCommands(float ismaster, float isvdo) {
    string s = CVAR_STR(sv_vote_commands);
    if(ismaster)
        s = strcat(s, " ", CVAR_STR(sv_vote_master_commands));
    if(!isvdo)
        s = strcat(s, " ", CVAR_STR(sv_vote_only_commands));
    return s;
}

string GetVoteList_All(float ismaster, float isvdo)
{
	if(!CVAR(sv_vote_gametype_call))
		return GetVoteList_VoteCommands(ismaster, isvdo);
	
	string votes;
	float i, n = tokenizebyseparator(GetVoteList_VoteCommands(ismaster, isvdo), " ");
	
	for(i = 0; i < n; ++i)
	{
		if(NormalizeGametypeName(argv(i)) == "")
			votes = strcat(votes, argv(i), " ");
	}
	
	return strcat(votes, CVAR_STR(sv_vote_gametype_options));
}

string GetVoteList_Filtered(float ismaster, float isvdo)
{
	string votes;
	float i, n = tokenizebyseparator(GetVoteList_All(ismaster, isvdo), " ");
	
	for(i = 0; i < n; ++i)
	{
		float c = ListContains(CVAR_STR(sv_vote_secretcommands), argv(i), " ");
		
		// ListContains tokenizes
		n = tokenizebyseparator(GetVoteList_All(ismaster, isvdo), " ");
		
		if not(c)
			votes = strcat(votes, argv(i), " ");
	}
	
	return votes;
}

string GetVoteList(float ismaster, float isvdo)
{
	if(CVAR(sv_vote_secretcommands_enabled))
		return GetVoteList_All(ismaster, isvdo);
	else
		return GetVoteList_Filtered(ismaster, isvdo);
}

void GameCommand(string);
void ShuffleMaplist();

float TeamMask (float l_team) // not really needed since we're only using it for CTF at the moment, but it might be useful some time in the future... maybe
{
	switch (l_team)
	{
		case COLOR_TEAM1: return 1;
		case COLOR_TEAM2: return 2;
		case COLOR_TEAM3: return 4;
		case COLOR_TEAM4: return 8;
	}
	
	return 1; // play it safe: default to one
}

string ResolveServer(string s) {
	string r = cvar_string(strcat("sv_serveralias_", s));
	if(r != "")
		return r;
	return s;
}

string GetAllowedServers() {
	return CVAR_STR(sv_gotoserver_whitelist);
}

/// Does NOT accept server aliases
float ServerIsAllowed(string s) {
	string wl = GetAllowedServers();
	return if(wl != "") ListContainsEx(wl, s, " ", ResolveServer) else TRUE;
}

float ShouldForceFog() {
	string s = CVAR_STR(g_rocketminsta_forcefog);
	if(s != "")
		return TRUE;
	return world.fog != "";
}

string GetForcedFog() {
	string s = CVAR_STR(g_rocketminsta_forcefog);
	if(s != "")
		return s;
	return world.fog;
}

// ========================================== //

.float endround_warmuptime;
.float endround_announced;
.void() endround_think;
.void() endround_think2;
.void() endround_finalize;

void G_EndRound_Think()
{
    float timeleft = rint(self.cnt - time);
    entity e;
    
    if(intermission_running) {
        remove(self);
        return;
    }
    
    if(self.endround_think)
		self.endround_think();
    
    if(timeleft <= self.endround_warmuptime)
    {
        roundstate = ROUNDSTATE_WARMUP;
        
		if(!self.endround_announced) {
			sound(world, CHAN_VOICE, "announcer/robotic/prepareforbattle.wav", VOL_BASEVOICE, ATTN_NONE);
			self.endround_announced = TRUE;
		}
		
        if(timeleft <= 0)
        {
            roundstate = if(inWarmupStage) ROUNDSTATE_INITIAL_WARMUP else ROUNDSTATE_GAME;

            FOR_EACH_PLAYER(e)
                bigprint_spec(e, "^xFB0Begin!", "It's time to kick some ass!", -1);
            
            sound(world, CHAN_VOICE, "announcer/robotic/begin.wav", VOL_BASEVOICE, ATTN_NONE);
            if(self.endround_finalize)
                self.endround_finalize();
            remove(self);
            shooting_forbidden = FALSE;
            return;
        }
        
		if(self.endround_think2)
			self.endround_think2();
		shooting_forbidden = TRUE;
        
        FOR_EACH_PLAYER(e)
            bigprint_spec(e, strcat(gametype_ID_to_LongName(game), " starts in: ", ftos(timeleft)), "", -1);
        
        if(timeleft <= 3)
			sound(world, CHAN_VOICE, strcat("announcer/robotic/", ftos(timeleft), ".wav"), VOL_BASEVOICE, ATTN_NONE);
    }

    self.nextthink = time + 1;
}

void G_EndRound(float thedelay, float warmuptime, void() callback, void() callback2, void() callbackfin)
{
    entity e = spawn();
    e.think = G_EndRound_Think;
    e.nextthink = time + (if(thedelay > 0) 1 else 0); // FIXME?
    e.endround_think = callback;
    e.endround_think2 = callback2;
    e.endround_finalize = callbackfin;
    e.endround_warmuptime = warmuptime;
    next_round = time + thedelay;
    next_round_starttime = next_round + warmuptime;
    e.cnt = next_round_starttime;

    if(thedelay > 0)
        roundstate = ROUNDSTATE_OVER;
    else
        roundstate = ROUNDSTATE_WARMUP;
}

// ========================================== //

void SendServerInfo(entity player) {
	msg_entity = player;
	WriteByte(MSG_ONE, SVC_TEMPENTITY);
	WriteByte(MSG_ONE, TE_CSQC_SERVERINFO);

    var clrname = cvar_string("hostname_colored");
    if(clrname == "") {
        WriteString(MSG_ONE, cvar_string("hostname"));
        WriteByte(MSG_ONE, FALSE);
    } else {
        WriteString(MSG_ONE, clrname);
        WriteByte(MSG_ONE, TRUE);
    }

	WriteString(MSG_ONE, RM_BUILD_NAME);
	WriteString(MSG_ONE, RM_BUILD_VERSION);
	WriteString(MSG_ONE, RM_BUILD_DATE);
	WriteString(MSG_ONE, strreplace("\\n", "\n", CVAR_STR(sv_motd)));
}

void AloneWarning(float t, float(entity) alivecheck) {
    float alive;
    entity e;
    entity p;
    
    FOR_EACH_PLAYER(e) if(e.team == t) if(alivecheck(e)) {
        p = e;
        alive++;
        
        if(alive > 1)
            return;
    }
    
    if(p) {
        bigprint_spec(p, "Warning! You are on your own!", "", 3);
    }
}

void SetCamera(entity player, entity cam, float timeout) {
	msg_entity = player;
	WriteByte(MSG_ONE, SVC_TEMPENTITY);
	WriteByte(MSG_ONE, TE_CSQC_CAMERA);
	WriteByte(MSG_ONE, TRUE);
	WriteShort(MSG_ONE, cam.origin_x);
	WriteShort(MSG_ONE, cam.origin_y);
	WriteShort(MSG_ONE, cam.origin_z);
	WriteShort(MSG_ONE, timeout);
}

void ClearCamera(entity player) {
	msg_entity = player;
	WriteByte(MSG_ONE, SVC_TEMPENTITY);
	WriteByte(MSG_ONE, TE_CSQC_CAMERA);
	WriteByte(MSG_ONE, FALSE);
}

void JB_ClearCameraForAll() {
	entity p; FOR_EACH_REALCLIENT(p) JB_ClearCamera(p);
}

void SetCameraWithAngles(entity player, entity cam, float timeout) {
    SetCamera(player, cam, timeout);
    player.angles = cam.angles;
    player.angles_z = 0;
    player.fixangle = TRUE;
}

float               trace_allsolid_saved;
float               trace_startsolid_saved;
float               trace_fraction_saved;
vector              trace_endpos_saved;
vector              trace_plane_normal_saved;
float               trace_plane_dist_saved;
entity              trace_ent_saved;
float               trace_dpstartcontents_saved;
float               trace_dphitcontents_saved;
float               trace_dphitq3surfaceflags_saved;
string              trace_dphittexturename_saved;
vector              v_forward_saved;
vector              v_up_saved;
vector              v_right_saved;

void save_trace_globals(void) {
    trace_allsolid_saved = trace_allsolid;
    trace_startsolid_saved = trace_startsolid;
    trace_fraction_saved = trace_fraction;
    trace_endpos_saved = trace_endpos;
    trace_plane_normal_saved = trace_plane_normal;
    trace_plane_dist_saved = trace_plane_dist;
    trace_ent_saved = trace_ent;
    trace_dpstartcontents_saved = trace_dpstartcontents;
    trace_dphitcontents_saved = trace_dphitcontents;
    trace_dphitq3surfaceflags_saved = trace_dphitq3surfaceflags;
    trace_dphittexturename_saved = trace_dphittexturename;
    v_forward_saved = v_forward;
    v_up_saved = v_up;
    v_right_saved = v_right;
}

void restore_trace_globals(void) {
    trace_allsolid = trace_allsolid_saved;
    trace_startsolid = trace_startsolid_saved;
    trace_fraction = trace_fraction_saved;
    trace_endpos = trace_endpos_saved;
    trace_plane_normal = trace_plane_normal_saved;
    trace_plane_dist = trace_plane_dist_saved;
    trace_ent = trace_ent_saved;
    trace_dpstartcontents = trace_dpstartcontents_saved;
    trace_dphitcontents = trace_dphitcontents_saved;
    trace_dphitq3surfaceflags = trace_dphitq3surfaceflags_saved;
    trace_dphittexturename = trace_dphittexturename_saved;
    v_forward = v_forward_saved;
    v_up = v_up_saved;
    v_right = v_right_saved;
}

.entity realowner;

float ProjectileTeam(entity p) {
    if(!teams_matter)
        return 0;

    float t = p.team;

    if(!t)
        t = p.realowner.team;

    if(!t)
        t = p.owner.team;

    return t;
}

entity findfilter(entity e, float(entity) filter) {
    for(;(e = nextent(e));)
        if(filter(e))
            return e;

    return world;
}

string fix_legacy_encoding(string s) {
    var c, i, newstr;

    for(i = 0, c = str2chr(s, i); c; c = str2chr(s, ++i)) {
        if(c < 32)
            c += 0xE000;
        newstr = strcat(newstr, chr2str(c));
    }

    return newstr;
}

void dropentities(entity platform) {
    const nudge = '1 1 1';
    entity e;

    while((e = findflags(e, flags, FL_ONGROUND))) {
        if(boxesoverlap(platform.absmin, platform.absmax, e.absmin - nudge, e.absmax + nudge)) {
            e.flags &~= FL_ONGROUND;
            UpdateCSQCProjectileNextFrame(e);
        }
    }

    while((e = findentity(e, aiment, platform))) {
        if(e.movetype == MOVETYPE_FOLLOW) {
            e.movetype = MOVETYPE_TOSS;
            e.aiment = world;
            e.flags &~= FL_ONGROUND;
            UpdateCSQCProjectileNextFrame(e);
        }
    }
}

float do_if_fexists(void(string) callback, string fpath) {
    if(fexists(fpath)) {
        callback(fpath);
        return TRUE;
    }

    return FALSE;
}

vector RandomSpreadVector(float side, float up, float up_min, float up_min_rand) {
    return [
        crandom() * 2 * side,
        crandom() * 2 * side,
        max(
            up * random(),
            up_min + up_min_rand * crandom() * 2
        )
    ];
}

vector CircleSpreadVector(float side, float up, float sangle) {
    return  side * v_forward * cos(sangle) +
            side * v_right   * sin(sangle) +
            up   * v_up;
}

.entity heal_emitter;
.float heal_emitter_radius;

void HealParticleEmitter_Think(void) {
    if(!self.owner || wasfreed(self.owner)) {
        remove(self);
        return;
    }

    if(self.origin != self.oldorigin)
        UpdateCSQCProjectile(self);

    self.oldorigin = self.origin;
    self.nextthink = time;
}

void HealParticleEmitter(entity o) {
    if(Buffs_Present(o, BUFF_MEDIC)) {
        if(!self.heal_emitter || wasfreed(self.heal_emitter)) {
            entity e = spawn();
            e.owner = self;
            e.movetype = MOVETYPE_FOLLOW;
            e.aiment = self;
            e.think = HealParticleEmitter_Think;
            e.nextthink = time;
            e.csqcprojectile_extradata = self.heal_emitter_radius;
            
            CSQCProjectile(e, FALSE, PROJECTILE_HEAL_PARTICLE_EMITTER, TRUE);
            self.heal_emitter = e;
        }
    } else {
        if(self.heal_emitter) {
            remove(self.heal_emitter);
            self.heal_emitter = world;
        }
    }
}
