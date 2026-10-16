-- s6-interface-5x: 5.x's icon row (main.lua). Its switch (off by default: another interface's panels are off in a
-- profile until turned on there; 5.x's first profile turns it on) and its Layout tab, whose default place is 5.33's,
-- (263, 374) on the scaled 5.x screen.

local C = TK.GetComponent("5x.icons")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1, allIcons = true } -- allIcons: s6-interface-5x-b, the options' ACTION ICONS

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "5x.icons", title = "Icons",
            about = "5.33's icon row under the map: Items, Spells, Info, Users, Board, Talk, Help and Quit." }),
    }
end
