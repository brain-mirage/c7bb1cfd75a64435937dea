-- s6-interface-5x (round 12, separation step 1; docs/development/interface-separation.md, section 5.1): the pages of
-- Modern's windows (character.lua, look.lua, social.lua, emotes.lua beside this file, moved from core/ in
-- s6-modular-g's round 16, step 7; the bag's switch is on the bag's own page), each with its switch; Game Options' window
-- (gameoptions.lua) has its own since round 18 (s6-modular-g). A window that is on shows the views no interface's page
-- takes (TK.Game.Views), in every interface. On in Modern's profiles; 7.x's and 5.x's first profiles leave them off, and
-- a 7.x or 5.x profile made before their switches has them turned off once (build 46: their interface.lua's migrate;
-- decision 2026-10-05-first-profiles-only-their-own-panels; Game Options' window by a second carry-over, round 18).
-- Nothing here is sent.

local C = TK.GetComponent("windows")

-- Each window's page: its node id (Modern's panel's, interfaces/modern/interface.lua), title and what it shows.
C.WINDOWS = {
    { id = "character", title = "Character Window", text = "The self look, the spell book, the legend and the collection." },
    { id = "look", title = "Look Window", text = "Another player's look." },
    { id = "social", title = "Social Window", text = "The group and the ignore list." },
    { id = "emotes", title = "Emotes", text = "The expressions." },
    -- s6-modular-g (round 18): the global Game Options page is "gameoptions", so this window's page has its own id
    { id = "gameoptionswindow", title = "Game Options Window", text = "The game's options (F10)." },
}

C.defaults = {}
for _, w in ipairs(C.WINDOWS) do C.defaults[w.id] = { enabled = true } end
-- s6-ui-core (round 83; the owner, 2026-10-09: the red edge "on spells, not only the bars"): the spell book's red edges,
-- as the action bars' (interfaces/modern/slotmark.lua), on the Character Window's page
C.defaults.character.markNoMana, C.defaults.character.markAether = true, true

function C:SettingsNodes()
    local nodes = {}
    for i, w in ipairs(C.WINDOWS) do
        nodes[i] = {
            id = w.id,
            title = w.title,
            order = C.order,
            sub = i,
            db = function() return C:DB()[w.id] end,
            defaults = function() return C.defaults[w.id] end,
            tabs = { { name = "General Settings", args = {
                { type = "toggle", key = "enabled", name = "Enabled" },
                { type = "description", name = w.text .. " Turned off, its keys and buttons show these pages only "
                    .. "where another panel draws them." },
            } } },
        }
        if w.id == "character" then -- s6-ui-core (round 83): the spell book's red edges
            require("interfaces.modern.slotmark").Args(nodes[i].tabs[1].args)
        end
    end
    return nodes
end
