-- s6-interface-5x: 5.x's screen and its pieces (interface.lua, main.lua). Each piece is a panel with its own page: its
-- switch (off by default: another interface's panels are off in a profile until turned on there; 5.x's first profile
-- turns them on) and its Layout tab (scale, anchor, offsets), whose default place is 5.33's on the scaled 5.x screen.
-- The screen's own page says whether the world view keeps to 5.33's map view.

local C = TK.GetComponent("5x.screen")
local Screen = require("interfaces.screen")

--- A piece's settings: its switch and its own scale (its place is the profile's positions["5x.<id>"], edit mode's).
local function piece() return { enabled = false, scale = 1 } end

C.defaults = { backdrop = piece(), border = piece(), mapName = piece(), clock = piece(), mapPane = false }

-- The pieces' pages: the panel id (interface.lua), its settings' key, title and what it is.
C.PAGES = {
    { id = "mapname", key = "mapName", title = "Map Name",
      about = "The map's name over the border's top bar, at (151, 0)-(284, 12): white on black, as 5.33 writes it." },
    { id = "clock", key = "clock", title = "Clock",
      about = "The time of day, a picture of TIME.EPF for every two hours, at (14, 375)." },
    { id = "backdrop", key = "backdrop", title = "Backdrop",
      about = "5.33's backdrop (FRAME.EPF) behind the screen's panels and the world view." },
    { id = "border", key = "border", title = "Border",
      about = "The thirteen pieces of FRMPART.EPF over the map view's edges: its corners, its top bar and its sides." },
}

function C:SettingsNodes()
    local nodes = {
        { id = "5x.screen", title = "5.x Screen", order = C.order, sub = 0,
          db = function() return C:DB() end,
          defaults = function() return C.defaults end,
          tabs = { { name = "General Settings", args = {
              { type = "description", name = "NexusTK 5.33's screen, 640 x 480, scaled to fit the window; while 5.x is the interface in use, the window's sides it does not fill are black." },
              { type = "toggle", key = "mapPane", name = "World View in the Map View" },
              { type = "description", name = "The world view where 5.33 draws its map, (14, 12)-(422, 372) on the screen: the 17 x 15 cells the server sends, following the window's size. Moving or resizing the world view turns this off." },
          } } } },
    }
    for i, p in ipairs(C.PAGES) do
        nodes[#nodes + 1] = Screen.Page(C, { id = "5x." .. p.id, key = p.key, title = p.title, sub = i, about = p.about })
    end
    return nodes
end
