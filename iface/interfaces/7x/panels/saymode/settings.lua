-- s6-interface-7x (round 1): 7.x's say-mode button (main.lua): its switch (off by default, as another interface's panels
-- are; 7.x's first profile turns it on) and its Layout tab (scale and place; its reset is the original's place on the
-- scaled screen).

local C = TK.GetComponent("7x.saymode")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "7x.saymode", title = "Say-Mode Button", sub = 0,
            about = "The original's say-mode button left of the chat bar (10, 727): it shows the say mode and opens the say-mode menu (Talk, Shout, Whisper, Group, Clan, -Color-)." }),
    }
end
