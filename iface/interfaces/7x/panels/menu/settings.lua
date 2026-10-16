-- s6-modular-g (interfaces, phase 5, round 13): 7.x's menu button (main.lua): its switch (off by default, as another
-- interface's panels are; 7.x's first profile turns it on) and its Layout tab (scale and place; its reset is the
-- original's place on the scaled screen).

local C = TK.GetComponent("7x.menu")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "7x.menu", title = "Menu Button", sub = 0,
            about = "The original's MENU button at the bottom right of the screen (744, 727): it opens the Menu popup (Userlook, Board, Mail, UserList, Friends, Target, Hotkey, Profile, Ranking, Quit)." }),
    }
end
