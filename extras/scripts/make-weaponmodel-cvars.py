#!/usr/bin/env python3

import re

from pathlib import Path


defaults = {
    "laser"             :   "laser",
    "shotgun"           :   "rm_shotgun",
    "uzi"               :   "uzi",
    "grenadelauncher"   :   "gl",
    "electro"           :   "electro",
    "crylink"           :   "crylink",
    "nex"               :   "rtznex",
    "hagar"             :   "hagar",
    "rocketlauncher"    :   "rl",
    "porto"             :   "porto",
    "minstanex"         :   "rtznex",
    "hook"              :   "hookgun",
    "hlac"              :   "hlac",
    "tuba"              :   "tuba",
    "campingrifle"      :   "rtzrifle",
    "fireball"          :   "fireball",
    "zapper"            :   "rtzapper",
    "flak"              :   "rtzflak",
    "pryaxe"            :   "pryaxe2",

    "nex_ofs"           :   "-2 0 1",
    "minstanex_ofs"     :   "-2 0 1",
    "zapper_ofs"        :   "0 0 1",
    "flak_ofs"          :   "6.5 0 4",
    "campingrifle_ofs"  :   "-3.5 -1 3",
    "pryaxe_ofs"        :   "0 4 5",

    "flak_left"         :   "1",
    "pryaxe_left"       :   "1",
}


weapon_regexp = re.compile(
    r'\s*register_weapon\((?:.*?,){8}\s*"(?P<sname>.*?)"\s*,\s*"(?P<wname>.*?)"\s*,.*?,.*?\)\s*'
)


def main():
    with (Path(__file__).absolute().parent.parent.parent / "qcsrc/common/items.qc").open() as f:
        for line in f:
            m = weapon_regexp.match(line)
            if m:
                fargs = {g: m.group(g) for g in ("wname", "sname")}
                fargs["default"] = defaults.get(fargs["sname"], fargs["sname"])
                fargs["default_ofs"] = defaults.get(fargs["sname"] + "_ofs", "0 0 0")
                fargs["default_left"] = defaults.get(fargs["sname"] + "_left", "0")

                print('set sv_weaponmodel_%(sname)s "%(default)s" "Weapon model replacement for the %(wname)s"\n'
                      'set sv_weaponmodel_%(sname)s_offset "%(default_ofs)s" "Weapon model offset for the %(wname)s"\n'
                      'set sv_weaponmodel_%(sname)s_left_hand_animations "%(default_left)s" "Weapon model has left-handed animations"\n' % fargs)


if __name__ == '__main__':
    main()
