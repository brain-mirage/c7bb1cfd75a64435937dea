-- s6-modular-g (interfaces, phase 5, round 14): 7.x's status panes (main.lua), each a panel with its own page: its switch
-- (off by default, as another interface's panels are; 7.x's first profile turns them on) and its Layout tab (scale and
-- place; its reset is the original's place on the scaled screen).

local C = TK.GetComponent("7x.status")
local Screen = require("interfaces.screen")

local function pane() return { enabled = false, scale = 1 } end

C.defaults = { nameplate = pane(), vitals = pane() }

local PAGES = {
    { key = "nameplate", title = "Name Plate",
      about = "The original's name plate at the top right (826, 16): your name, your level, and the title and path lines of your status." },
    { key = "vitals", title = "Vitals",
      about = "The original's vitals at the bottom right (881, 659): vita, mana and experience with their bars, your gold, and your position." },
}

function C:SettingsNodes()
    local nodes = {}
    for i, p in ipairs(PAGES) do
        nodes[i] = Screen.Page(C, { id = "7x." .. p.key, key = p.key, title = p.title, sub = i - 1, about = p.about })
    end
    return nodes
end
