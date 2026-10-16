-- s6-interface-7x-b: 7.x's clock (main.lua): its switch (off by default, as another interface's panels are; 7.x's first
-- profile turns it on) and its Layout tab (scale and place; its reset is the original's place on the scaled screen).

local C = TK.GetComponent("7x.clock")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "7x.clock", title = "Clock", sub = 0,
            about = "The original's clock at the bottom right (830, 736): the game hour as one of twelve pictures, one for each two hours. A right click on it shows the hour." }),
    }
end
