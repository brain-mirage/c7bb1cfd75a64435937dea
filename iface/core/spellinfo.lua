-- s6-spellbook-data (the owner's Spell Book table, 2026-10-04): what the current character's own casts showed of each
-- spell, from the Library's Spell stats tracker (Session.SpellStats.cs). Only what the client learns in play.
--
-- TK.SpellInfo:Get(name) returns a table, never nil:
--   mana, health, cooldown (seconds), healing, damage (to the enemy), self_damage (to the caster): numbers, the newest
--   seen; nil when unknown (the Spell Book shows ???);
--   range: { <field> = { low, high } } for each field whose values seen differed (empty when none did);
--   auras: { { name, good } } the timers the latest cast that began any put on the player; nil when none was seen.
--     good: true for a buff, false for a debuff, by the name's classification (TK.EffectIcons.NameKind: the player's
--     buff and debuff lists, this computer's choices, data/effects.lua); nil when nothing classifies the name. Round 2
--     (Astra's P2 on round 1): nothing the server sends says whether an effect is good or bad, so it is never guessed.
-- The tracker off: an empty table. TK_SPELLINFO_CHANGED fires (no arguments) when the values change.
-- Read only: nothing here is sent.

local H = __tk

TK.SpellInfo = {}

--- The current character's record of the spell, by its name as the server's spell list gives it.
function TK.SpellInfo:Get(name)
    local info = H:GetSpellInfo(name or "")
    for _, a in ipairs(info.auras or {}) do
        local kind = TK.EffectIcons.NameKind(a.name)
        if kind == "buff" then a.good = true elseif kind == "debuff" then a.good = false end
    end
    return info
end
