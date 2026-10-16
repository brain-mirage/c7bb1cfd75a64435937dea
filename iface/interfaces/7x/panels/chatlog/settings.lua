-- s6-interface-7x-b: 7.x's chat log (main.lua): its switch (off by default, as another interface's panels are; 7.x's first
-- profile turns it on) and its Layout tab (scale and place; its reset is the original's place on the scaled screen). Its
-- rows, its backdrop's mode and its switch are the client's own settings (settings.toml chat.lines, mode, secondary),
-- changed by its handle and the chat bar's buttons, as the original's.

local C = TK.GetComponent("7x.chatlog")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "7x.chatlog", title = "Chat Log", sub = 0,
            about = "The original's chat log over the bottom of the map view (23, 606), with its darkened backdrop and its height handle; Shift with Up, Down, Page Up and Page Down scrolls it." }),
    }
end
