-- s6-interface-7x-b: 7.x's parcel and letter buttons (main.lua), two panels over the one pane: each its switch (off by
-- default, as another interface's panels are; 7.x's first profile turns them on) and its Layout tab (scale and place; its
-- reset is the original's place on the scaled screen).

local C = TK.GetComponent("7x.parcel")
local Screen = require("interfaces.screen")

C.defaults = { parcel = { enabled = false, scale = 1 }, letter = { enabled = false, scale = 1 } }

-- the two pages: the panel id (interface.lua), its settings' key, title and what it is
C.PAGES = {
    { key = "parcel", title = "Parcel Button",
      about = "The original's parcel button at the bottom (630, 726): it blinks while parcels wait; a click asks for them." },
    { key = "letter", title = "Letter Button",
      about = "The original's letter button beside the parcel button (661, 726): it blinks while letters wait; a click opens the mail." },
}

function C:SettingsNodes()
    local nodes = {}
    for i, p in ipairs(C.PAGES) do
        nodes[i] = Screen.Page(C, { id = "7x." .. p.key, key = p.key, title = p.title, sub = i - 1, about = p.about })
    end
    return nodes
end
