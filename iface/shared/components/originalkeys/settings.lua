local C = TK.GetComponent("originalkeys")

C.defaults = {}

-- The page lists the commands with their keys (main.lua's C.list, loaded after this file).
function C:SettingsNodes()
    local args = {
        { type = "description", name = "The original client's commands that no window or menu here reaches, each on the original's own key (its capital letters are Shift with the letter). Each goes through the game rules, which send exactly what the original sends." },
    }
    for _, c in ipairs(self.list or {}) do
        local command = TK.Bindings.commands[c[1]] -- s6-macros: Original Macro Setup only while the macro window's setting shows it
        if not (command and command.hidden and command.hidden()) then -- s6-macros
            args[#args + 1] = { type = "binding", name = c[2] .. "  (the original's " .. c[5] .. ")", command = c[1] } -- s6-macros
        end -- s6-macros
    end
    args[#args + 1] = { type = "binding", name = "Sound On/Off  (the original's F7: the effects and the music, here only)", command = "SOUNDTOGGLE" }
    args[#args + 1] = { type = "binding", name = "Music  (the original's F8: the Sound page)", command = "MUSIC" } -- s6-input (round 48)
    args[#args + 1] = { type = "description", name = "The keypad's digits are the action bar's 1-0 keys, as the original's keypad was its digit row. While the Character window shows its Character or Legend tab, the look and equipment keys go by its own toggles, which share a one-second limit, as the original's." }
    return {
        { id = self.name, title = self.title, order = self.order, tabs = { { name = "Commands", args = args } },
          category = "general", -- s6-ui-settings (Astra's review): the commands beside Key Bindings
          db = function() return self:DB() end },
    }
end
