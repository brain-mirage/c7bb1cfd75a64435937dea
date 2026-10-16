-- Modern's bag: its view settings (settings.lua) and the window (window.lua, TK.Bag, which reads them; s6-modular-g
-- round 16, separation step 7: moved here with this component from core/bag.lua and components/bag). The window's
-- slots and buttons are the game layer's controls (TK.Game.Inventory), so it draws and sends nothing of its own.

local C = TK.GetComponent("bag")

require("interfaces.modern.panels.bag.window")

function C:ApplySettings()
    TK.Game.Views.CloseOff() -- the window turned off closes (its switch, enabled)
    TK.Bag:Refresh()
end
