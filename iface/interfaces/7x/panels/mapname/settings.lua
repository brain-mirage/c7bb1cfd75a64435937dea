-- s6-interface-7x-b: 7.x's map name (main.lua): its switch (off by default, as another interface's panels are; 7.x's first
-- profile turns it on) and its Layout tab (scale and place; its reset is the original's place on the scaled screen).

local C = TK.GetComponent("7x.mapname")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "7x.mapname", title = "Map Name", sub = 0,
            about = "The original's map name plate at the top of the map view (316, 0)." }),
    }
end
