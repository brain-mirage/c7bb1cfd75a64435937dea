-- s6-modular-g (interfaces, phase 5, round 14): 7.x's side panel (main.lua): its switch (off by default, as another
-- interface's panels are; 7.x's first profile turns it on) and its Layout tab (scale and place; its reset is the
-- original's place on the scaled screen).

local C = TK.GetComponent("7x.side")

C.defaults = { enabled = false, scale = 1 }

function C:SettingsNodes()
    return {
        { id = "7x.side", title = "Side Panel", order = C.order, sub = 0,
          db = function() return C:DB() end,
          defaults = function() return C.defaults end,
          tabs = {
              { name = "General Settings", args = {
                  { type = "toggle", key = "enabled", name = "Enabled" },
                  { type = "description", name = "The original's side panel and its tabs. While it is on, the bag, spell book, character, group, collection, options and look open its tabs instead of windows." },
              } },
              { name = "Layout", args = TK.LayoutArgs(function() return "7x.side" end) },
          } },
    }
end
