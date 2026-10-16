-- s6-ui-core (round 86; decision 2026-10-12-original-pregame-screens): 7.x's own title screen, 7.5.2's MainMenuPane
-- (0x004F6700) and its Login entry's LoginDialogPane (0x004FA7A0). Its layout is title.xml's; its script is the twins'
-- shared one (interfaces/xml/title.lua: the menu, the dialog, and the WIRE note on OK and the wait), made with 7.x's
-- kit. Only the XML twin has it.

local X = require("interfaces.7x.draw")

local data = TK.Xml.Data("title.xml")

return require("interfaces.xml.title")({
    data = data,
    load = function(opts)
        local ui = TK.Xml.Load("title.xml", opts) -- (not a tail call: the loader finds title.xml beside this file)
        return ui
    end,
    S = require("interfaces.7x.skin"),
    X = X,
    elements = require("interfaces.7x.elements"),
    -- OK, the dialog's focused control, shows its focused picture (BUTT001.EPF's frame 4 id + 3: X.Image)
    focus = function(button) button:GetNormalTexture():SetTexture(button.focusedPicture or button.normalPicture) end,
})
