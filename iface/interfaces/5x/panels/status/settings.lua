-- s6-interface-5x: 5.x's status pane (main.lua). Its switch (off by default: another interface's panels are off in a
-- profile until turned on there; 5.x's first profile turns it on) and its Layout tab, whose default place is 5.33's,
-- (433, 372) on the scaled 5.x screen.

local C = TK.GetComponent("5x.status")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "5x.status", title = "Status",
            about = "5.33's status pane: your name, totem, nation, path and level, might, will and grace, vita and mana with their bars, experience, gold and place on the map." }),
    }
end
