-- s6-interface-5x-b: 5.x's options window (main.lua). Its switch (off by default: another interface's panels are off in
-- a profile until turned on there; 5.x's first profile turns it on): while on, the Game Options' opener (F10) shows it
-- in place of Modern's Game Options window. It has no Layout tab: a window, placed as 5.33's dialogs are.

local C = TK.GetComponent("5x.options")

C.defaults = { enabled = false }

function C:SettingsNodes()
    return {
        { id = "5x.options", title = "Options", order = C.order,
          db = function() return C:DB() end,
          defaults = function() return C.defaults end,
          tabs = {
              { name = "General Settings", args = {
                  { type = "toggle", key = "enabled", name = "Enabled" },
                  { type = "description", name = "5.33's options window: the Game Options key (F10) opens it in place of the Game Options window. Each switch does what the same option does in the Game Options window or on the Sound page." },
              } },
          } },
    }
end
