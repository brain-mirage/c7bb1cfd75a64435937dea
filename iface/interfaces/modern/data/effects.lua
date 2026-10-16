-- Modern's effect pictures (s6-modular-g round 16, separation step 7; interface-separation.md 4.2): the icon Modern
-- draws for each effect the server names (its buffs and debuffs, panels/auras; the icons on units and the target
-- frame's row, effecticons.lua), by the name data/effects.lua gives its kind. Edit it freely: it is plain data, read
-- when the UI loads (Ctrl+Shift+R reloads it).
--
--   [name] = a Twemoji code point: assets/emoji/twemoji/72x72/<icon>.png, pinned with its SHA-256 in vendor.lock.json
--
-- A name with no picture is drawn as a small square with its first letter (the icons on units) or with unknownIcon
-- (the buffs and debuffs).

return {
    unknownIcon = "2753",

    icons = {
        ["Shield"]       = "1f6e1",
        ["Blessing"]     = "2728",
        ["Valor"]        = "1f4aa",
        ["Haste"]        = "26a1",
        ["Regeneration"] = "1f49a",
        ["Mana Well"]    = "1f4a7",
        ["Invisibility"] = "1f47b",
        ["Meditation"]   = "1f9d8",

        ["Weakened"]     = "1f4ab",
        ["Poison"]       = "2620",
        ["Burning"]      = "1f525",
        ["Frozen"]       = "1f9ca",
        ["Bleeding"]     = "1fa78",
        ["Snared"]       = "1f578",
        ["Blinded"]      = "1f648",
        ["Asleep"]       = "1f4a4",
    },
}
