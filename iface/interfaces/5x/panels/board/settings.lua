-- s6-interface-5x: 5.x's message board (main.lua). Its switch (off by default: another interface's panels are off in a
-- profile until turned on there; 5.x's first profile turns it on) and its Layout tab, whose default place is 5.33's,
-- (441, 304) on the scaled 5.x screen.

local C = TK.GetComponent("5x.board")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "5x.board", title = "Message Board",
            about = "5.33's message board: the server's notices and the item notices. While it is on, they show here and not in the chat." }),
    }
end
