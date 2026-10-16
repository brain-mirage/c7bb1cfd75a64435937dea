-- Spell icons (plan 5.11). The original has none: its spell list shows the key letter and the name. Here a spell's icon
-- is a frame of the effect animation it plays, which the client learns from the player's own casts on the server it plays
-- on (the first effect the server plays on the cast's target), shown at its middle frame (frame count / 2, rounded
-- down, from 0); or a picture, one of the packs' item icons, or the letter, chosen in the spell icon editor
-- (s6-spell-icons, core/spelliconeditor.lua).
--
-- This table is ours: curated overrides shipped with the client and replaced by each build, by the spell's name as the
-- server gives it. An entry is a spell_icons.toml entry as a table, for example
--   { icon = <the packs' item icon> }   or   { effect = <effect id>, frame = <frame, from 0; optional> }   or
--   { picture = "<a picture file, from config/>" }.
-- The player's choices win per spell (Character, then Server, then Global), then the server pack, then this table,
-- then the learned effect (TK.Core.Objects.SpellIconStore, DESIGN.md of s6-spell-icons).

local H = __tk

local M = {
    spells = {
        -- ["Fire Bolt"] = { effect = 37, frame = 4 },
    },
}

--- The character in the world ("" before it: the session's server, no character).
local function who() return TK.Characters and TK.Characters.ref or "" end

--- A spell's icon: its texture key ("" for the lettered square), its size and the animation's frame count. animate: the
--- Interface page's option (an entry's own animate also animates it). Animated, the key is the frame showing now, so ask
--- again each frame.
function M.Get(name, animate)
    return H:GetSpellIcon(name, animate == true, M.spells[name], who())
end

--- Where a spell's icon comes from now: "character", "server", "global", "pack", "ours", "learned", or "" (the letter).
function M.Source(name)
    return H:GetSpellIconSource(name, M.spells[name], who())
end

return M
