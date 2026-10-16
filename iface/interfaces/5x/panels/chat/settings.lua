-- s6-interface-5x: 5.x's chat (main.lua). Its switch (off by default: another interface's panels are off in a profile
-- until turned on there; 5.x's first profile turns it on) and its Layout tab, whose default place is 5.33's, (14, 390)
-- on the scaled 5.x screen.

local C = TK.GetComponent("5x.chat")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "5x.chat", title = "Chat",
            about = "5.33's chat: five lines on white, each kind of line in 5.33's colours, and under them the line you type, while it is open. The keys that open and send it are the chat's own, in every interface." }),
    }
end
