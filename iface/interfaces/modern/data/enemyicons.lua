-- The enemy icons table (plan 5.11): a name for an effect animation running on a creature when nothing else names it
-- (no name and no candidate spells): its row on the creature takes the name given here (Modern's Effects on Others,
-- panels/enemyicons, rowsOf; s6-modular-g round 16, separation step 7: moved here from data/), and with it that name's
-- icon when data/effects.lua beside this file gives the name one. For creatures the client receives only
-- animation ids, never names: the effect lists of 0x07 (each entry's u16 effect id) and 0x29. Edit it freely: it is
-- plain data, read when the UI loads (Ctrl+Shift+R reloads it).
--
--   [id] = { name = "what it is" }
--
-- No source names the ids yet (docs/research: only 0x86, a map flash, and 0xA0-0xA2, drawn in front, are known), so
-- the table starts empty; an effect nothing names is drawn as a "?" square (effecticons.lua's Show). s6-optimize (round
-- 16): the icon fields this table once had (unknownIcon, an entry's icon) were read by nothing and are gone.

return {
    effects = {
        -- [0x0B] = { name = "Stunned" },
    },
}
