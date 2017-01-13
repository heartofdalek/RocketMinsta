#ifdef INTERFACE
CLASS(NexuizRMConfigDialog) EXTENDS(NexuizRootDialog)
	METHOD(NexuizRMConfigDialog, fill, void(entity)) // to be overridden by user to fill the dialog with controls
	ATTRIB(NexuizRMConfigDialog, title, string, "RocketMinsta Configuration")
	ATTRIB(NexuizRMConfigDialog, color, vector, SKINCOLOR_DIALOG_TEAMSELECT)
	ATTRIB(NexuizRMConfigDialog, intendedWidth, float, 1.0)
	ATTRIB(NexuizRMConfigDialog, rows, float, 26)
	ATTRIB(NexuizRMConfigDialog, columns, float, 16)
	ATTRIB(NexuizRMConfigDialog, name, string, "RMConfig")
ENDCLASS(NexuizRMConfigDialog)
#endif

#ifdef IMPLEMENTATION

#define OPTDEP(o) setDependent(e, "_rm_optavail_"##o, 1, 1);

void fillNexuizRMConfigDialog(entity me)
{
	entity e, sl;
    me.setFirstColumn(me, me.firstColumn + 0.1);

    me.setFirstColumn(me, me.firstColumn - 0.1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeNexuizTextLabel(0, "General:"));
    me.setFirstColumn(me, me.firstColumn + 0.1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeRMCheckBox(0, "radio", "Enable the Radio (music broadcast from server)"));
            OPTDEP("radio")
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "showspec", "Show spectators"));
			OPTDEP("showspec")
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "showdamage", "Hit/damage indicator"));
			OPTDEP("showdamage")
	me.TR(me);
		sl = makeNexuizSlider(0.05, 1, 0.05, "cl_truezapper");
		me.TD(me, 1, 3, e = makeNexuizSliderCheckBox(0, 1, sl, "True zapper:"));
		me.TD(me, 1, 3, sl);
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "shownames", "Show player names above their heads"));
			OPTDEP("shownames")
	me.setFirstColumn(me, me.firstColumn + 0.1);
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "shownames_teamonly", "Only allies"));
			OPTDEP("shownames")
	me.setFirstColumn(me, me.firstColumn - 0.1);
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "teamlasers", "Team-colored particles"));
			//OPTDEP("teamlasers")
	me.TR(me);
		me.TD(me, 1, 4, e = makeNexuizCheckBox(0, "rm_fps_friendly", "I play on a toaster"));
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "legacyvote", "Simple voting screen"));
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(1, "simpleeffects", "Effects for textual notifications"));
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "anonspec", "Spectate anonymously"));
			OPTDEP("anonspec")
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(1, "noflags", "Country flags in scoreboard"));
#ifndef RM_SUPPORT_PKG_o_flagicons
            e.disabled = TRUE;
#endif
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "hidecountry", "Hide my country"));
			OPTDEP("hidecountry")
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(1, "notimer", "\"time\" column in scoreboard"));
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(1, "nokillsound", "Separate kill and hit sounds"));
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(1, "nogamemenu", "Enable the Game Menu"));

    me.setFirstColumn(me, me.firstColumn - 0.1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeNexuizTextLabel(0, "Game-specific:"));
    me.setFirstColumn(me, me.firstColumn + 0.1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeRMCheckBox(0, "nododging", "Disable dodging"));
            OPTDEP("dodging")
	me.TR(me);
        me.TD(me, 1, 4, e = makeRMCheckBox(0, "freezetag_danger", "Danger shortcut for freezetag"));
            OPTDEP("freezetag_danger")
    me.setFirstColumn(me, me.firstColumn + 0.1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeRMCheckBox(0, "freezetag_danger_silent", "Without teamchat notification"));
            OPTDEP("freezetag_danger")
    me.setFirstColumn(me, me.firstColumn - 0.1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeNexuizCheckBox(0, "cl_frozentint", "Tint the screen while frozen"));
    me.TR(me);
        me.TD(me, 1, 4, e = makeRMCheckBox(0, "altcharge", "Alternative nadget throwing mode"));
            OPTDEP("altcharge")
    me.TR(me);
        me.TD(me, 1, 4, e = makeRMCheckBox(0, "convswitch", "Conventional weapon controls"));
            OPTDEP("convswitch")

    me.setFirstColumn(me, me.firstColumn - 0.1);
    me.TR(me);
		me.TD(me, 1, 4, e = makeNexuizTextLabel(0, "Note: You can access these options through Multiplayer -> Player Setup"));
	me.TR(me);
		me.TD(me, 1, me.columns, e = makeNexuizButton("Ok", '0 0 0'));
			e.onClick = Dialog_Close;
			e.onClickEntity = me;
    me.setFirstColumn(me, me.firstColumn + 0.1);
	
	me.gotoRC(me, 0, 8); me.setFirstColumn(me, me.currentColumn);
		me.TD(me, 1, 4, e = makeNexuizTextLabel(0, "HUD:"));
	me.setFirstColumn(me, me.firstColumn + 0.1);
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "oldhud", "Use default Nexuiz HUD"));
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "althud", "Use an alternative HUD layout"));
            setDependent(e, "rm_oldhud", 0, 0);
    me.TR(me);
        me.TD(me, 1, 4, e = makeRMCheckBox(1, "nobigtext", "Enable big notifications"));
    me.setFirstColumn(me, me.firstColumn + 0.1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeRMCheckBox(1, "hidebigcomments", "with comments"));
            setDependent(e, "rm_nobigtext", 0, 0);
    me.setFirstColumn(me, me.firstColumn - 0.1);
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "visualscore", "Scoring notifications in the HUD"));
	me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "showrankings", "Show top players in the HUD"));
    me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "showtimer", "Always show the timer"));
    me.TR(me);
		me.TD(me, 1, 4, e = makeRMCheckBox(0, "shownadgetregen", "Show Nadget regeneration in seconds"));
            setDependentAND(e, "rm_oldhud", 0, 0, "_rm_optavail_shownadgetregen", 1, 1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeNexuizCheckBox(0, "cl_lowammowarnings", "Low ammo warnings"));
    me.TR(me);
        me.TD(me, 1, 4, e = makeNexuizCheckBox(0, "rm_hud_healthcolor", "Health-colored HUD"));
    me.TR(me);
        me.TD(me, 1, 4, e = makeRMCheckBox(1, "hidewatermark", "Show version information"));

    me.setFirstColumn(me, me.firstColumn - 0.1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeNexuizTextLabel(0, "Crosshair:"));
    me.setFirstColumn(me, me.firstColumn + 0.1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeRMCheckBox(0, "crosshealth", "Health-colored crosshair"));
    me.TR(me);
        me.TD(me, 1, 3, e = makeNexuizTextLabel(0, "Ring size:"));
        me.TD(me, 1, 3, e = makeNexuizSlider(0, 4, 0.05, "rm_hud_crosshair_ring_size"));
    me.TR(me);
        me.TD(me, 1, 3, e = makeNexuizTextLabel(0, "Ring alpha:"));
        me.TD(me, 1, 3, e = makeNexuizSlider(0, 1, 0.05, "rm_hud_crosshair_ring_alpha"));

	me.setFirstColumn(me, me.firstColumn - 0.1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeNexuizTextLabel(0, "Font:"));
    me.setFirstColumn(me, me.firstColumn + 0.1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeNexuizCheckBox(0, "rm_fonts_prefer_ttf",
            if(checkextension("DP_RM_CVAR_ALTERTYPE"))
                "Prefer TTF over legacy bitmap fonts"
            else
                "Prefer TTF over legacy bitmap fonts (restart required)"
        ));

        if(dprm_basegame == BASEGAME_VECXIS) {
            e.disabled = TRUE;
        } else {
            setDependent(e, "utf8_enable", 1, 1);
        }
    me.TR(me);
        me.TD(me, 1, 4, e = makeNexuizCheckBox(0, "r_font_size_snapping", "Try to stick to good-looking font sizes"));
            setDependent(e, "utf8_enable", 1, 1);
    me.TR(me);
        me.TD(me, 1, 4, e = makeRMCheckBox(0, "oldbigfont", "Use old-style fonts for large text"));
        if(dprm_basegame == BASEGAME_VECXIS) {
            e.disabled = TRUE;
        }

    me.setFirstColumn(me, me.firstColumn - 0.1);
	me.TR(me);
		me.TD(me, 1, 4, e = makeNexuizTextLabel(0, "HUD skin:"));
		setDependent(e, "rm_oldhud", 0, 0);
	me.TR(me);
		me.TD(me, me.rows - 22, 8, e = makeRMHudSkinList());
		setDependent(e, "rm_oldhud", 0, 0);
	//me.gotoRC(me, me.rows - 5, 8); me.setFirstColumn(me, me.currentColumn);
}
#endif

/* Click. The c-word is here so you can grep for it :-) */
