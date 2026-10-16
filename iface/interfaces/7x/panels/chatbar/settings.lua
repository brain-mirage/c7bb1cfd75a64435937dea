-- s6-modular-g (interfaces, phase 5, round 14): 7.x's chat bar (main.lua): its switch (off by default, as another
-- interface's panels are; 7.x's first profile turns it on) and its Layout tab (scale and place; its reset is the
-- original's place on the scaled screen).

local C = TK.GetComponent("7x.chatbar")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "7x.chatbar", title = "Chat Bar", sub = 0,
            about = "The original's chat bar at the bottom of the screen (74, 727): Back to Talk, the typing area with the open line, and its two right-hand buttons. While it shows, the chat window leaves its own bar out." }),
    }
end
