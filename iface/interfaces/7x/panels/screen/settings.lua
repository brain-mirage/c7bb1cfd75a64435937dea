-- s6-modular-g (interfaces, phase 3): 7.x's screen and its Decoration (interface.lua, main.lua). Each decoration piece
-- is a panel with its own page: its switch (off by default: another interface's panels are off in a profile until turned on
-- there; 7.x's first profile turns them on) and its Layout tab (scale, anchor, offsets: Astra's review of round 9),
-- whose default place is the original's on the scaled 7.x screen. The screen's own page says whether the world view
-- keeps to the original's map view.

local C = TK.GetComponent("7x.screen")
local Screen = require("interfaces.screen")

--- A piece's settings: its switch and its own scale (its place is the profile's positions["7x.<id>"], edit mode's).
local function piece() return { enabled = false, scale = 1 } end

C.defaults = { backdrop = piece(), border = piece(), tabHeader = piece(), divider = piece(), chatBackdrop = piece(),
               mapPane = false }

-- The pieces' pages: the panel id (interface.lua), its settings' key, title and order in the Decoration list.
C.PAGES = {
    { id = "backdrop", key = "backdrop", title = "Backdrop",
      about = "The original's backdrop (FRAME.EPF) behind the screen's panels and the world view." },
    { id = "border", key = "border", title = "Border",
      about = "The frame's border over the world view: its top bar and its left and right strips (FRMPART.EPF 0-2)." },
    { id = "tabheader", key = "tabHeader", title = "Tab Header",
      about = "The side panel's tab header (TABS.EPF), at (808, 79)." },
    { id = "divider", key = "divider", title = "Messages Divider",
      about = "The bar between the spells' list and the system messages (SYSBAR.EPF)." },
    { id = "chatbackdrop", key = "chatBackdrop", title = "Chat Backdrop",
      about = "The darkened band behind the chat, (9, 596)-(816, 720): black over 70 % of the scene." },
}

function C:SettingsNodes()
    local nodes = {
        { id = "7x.screen", title = "7.x Screen", order = C.order, sub = 0,
          db = function() return C:DB() end,
          defaults = function() return C.defaults end,
          tabs = { { name = "General Settings", args = {
              { type = "description", name = "7.5.2's screen, 1024 x 768, scaled to fit the window; while 7.x is the interface in use, the window's sides it does not fill are black." },
              { type = "toggle", key = "mapPane", name = "World View in the Map Pane" },
              { type = "description", name = "The world view where the original draws its map, (0, 0)-(816, 720) on the screen, following the window's size. Moving or resizing the world view turns this off." },
          } } } },
    }
    for i, p in ipairs(C.PAGES) do
        nodes[#nodes + 1] = Screen.Page(C, { id = "7x." .. p.id, key = p.key, title = p.title, sub = i, about = p.about })
    end
    return nodes
end
