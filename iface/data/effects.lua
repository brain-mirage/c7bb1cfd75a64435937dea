-- The effects table (head note 4, plan 5.11): what the UI knows about each effect the server names. The server
-- sends only a name and the seconds left (0x3A), buffs and debuffs mixed; this table says which one it is. Edit it
-- freely: it is plain data, read when the UI loads (Ctrl+Shift+R reloads it).
--
--   kind  "buff" or "debuff"
--
-- s6-modular-g (round 16, separation step 7): the icons Modern draws for them are Modern's art,
-- interfaces/modern/data/effects.lua (by the same names).
--
-- A name that is not listed shows among the buffs, marked "unclassified", and is logged.
-- The player's Buffs and Debuffs name lists (Effects on Others' page, in the profile) win over this table; right-clicking
-- an effect's icon in the game moves its name to the other list (s6-ui-core round 43). Choices saved for this computer
-- before (machine.json, effectOverrides) still win over this table for names on neither list.

return {
    effects = {
        ["Shield"]       = { kind = "buff" },
        ["Blessing"]     = { kind = "buff" },
        ["Valor"]        = { kind = "buff" },
        ["Haste"]        = { kind = "buff" },
        ["Regeneration"] = { kind = "buff" },
        ["Mana Well"]    = { kind = "buff" },
        ["Invisibility"] = { kind = "buff" },
        ["Meditation"]   = { kind = "buff" },

        ["Weakened"]     = { kind = "debuff" },
        ["Poison"]       = { kind = "debuff" },
        ["Burning"]      = { kind = "debuff" },
        ["Frozen"]       = { kind = "debuff" },
        ["Bleeding"]     = { kind = "debuff" },
        ["Snared"]       = { kind = "debuff" },
        ["Blinded"]      = { kind = "debuff" },
        ["Asleep"]       = { kind = "debuff" },
    },
}
