-- s6-interface-5x: 5.x's side panel (main.lua). Its switch (off by default: another interface's panels are off in a
-- profile until turned on there; 5.x's first profile turns it on) and its Layout tab, whose default place is 5.33's,
-- (434, 12) on the scaled 5.x screen.

local C = TK.GetComponent("5x.side")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "5x.side", title = "Side Panel",
            about = "5.33's side panel: your items, your spells and your equipment, one page at a time. While it is on, the bag, spell book and character keys show its pages." }),
    }
end
