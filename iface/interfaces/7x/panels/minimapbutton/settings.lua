-- s6-interface-7x-b: 7.x's minimap button (main.lua): its switch (off by default, as another interface's panels are; 7.x's
-- first profile turns it on) and its Layout tab (scale and place; its reset is the original's place on the scaled screen).

local C = TK.GetComponent("7x.minimapbutton")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "7x.minimapbutton", title = "Minimap Button", sub = 0,
            about = "The original's minimap button at the top left of the map view (6, 6): a click asks for the minimap, as M does." }),
    }
end
