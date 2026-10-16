-- s6-interface-7x-b: 7.x's messages pane (main.lua): its switch (off by default, as another interface's panels are; 7.x's
-- first profile turns it on) and its Layout tab (scale and place; its reset is the original's place on the scaled screen).
-- The divider's height is the client's own setting (settings.toml chat.system_message_height), moved by dragging it.

local C = TK.GetComponent("7x.messages")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "7x.messages", title = "Messages", sub = 0,
            about = "The original's lower side page (832, 376): the spells and effects in effect with their seconds, a divider to drag, and the system messages below it." }),
    }
end
