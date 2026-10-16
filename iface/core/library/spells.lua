-- The Library's Spells page (s6-library round 2; moved out of library.lua by s6-library-pages): every spell the Library
-- knows, with the effect it plays, how long it lasts on the player, and which characters have it at what cost. Lines.
-- Read only: nothing is sent.

local L = TK.Library
local X = L.Lines

L:AddPage({ id = "spells", title = "Spells", order = 50, lines = function()
    local add = X.add
    -- s6-spellbook-data: and the Spell stats (the Spell Book's numbers, every character's here; a character's own on its page)
    X.clear(add("Spells", "header"), "spellinfo", { "spell_effects", "spell_durations", "spell_stats" })
    if not L.data.on.spell_effects then add("Spell effects: " .. X.OFF, "note") end
    if not L.data.on.spell_durations then add("Spell durations: " .. X.OFF, "note") end
    if not L.data.on.spell_stats then add("Spell stats: " .. X.OFF, "note") end
    if #L.data.spells == 0 then add("None recorded yet.", "dim") end
    for _, sp in ipairs(L.data.spells) do
        local parts = { sp.name }
        if sp.effect > 0 then parts[#parts + 1] = "effect " .. sp.effect end
        if sp.duration > 0 then parts[#parts + 1] = "lasts about " .. sp.duration .. " s" .. (sp.varied and " (varies)" or "") end
        if sp.who ~= "" then parts[#parts + 1] = sp.who end
        add(table.concat(parts, "   "))
    end
end })
