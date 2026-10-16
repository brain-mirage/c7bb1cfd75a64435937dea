-- s6-interface-5x-b: 5.x's parcel icons (main.lua). Its switch (off by default: another interface's panels are off in a
-- profile until turned on there; 5.x's first profile turns it on) and its Layout tab, whose default place is 5.33's,
-- (45, 371) on the scaled 5.x screen.

local C = TK.GetComponent("5x.parcel")
local Screen = require("interfaces.screen")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        Screen.Page(C, { id = "5x.parcel", title = "Parcels",
            about = "5.33's parcel and letter icons beside the clock, one for each waiting (four at most): a press on a parcel receives the parcels, on a letter opens the mail." }),
    }
end
