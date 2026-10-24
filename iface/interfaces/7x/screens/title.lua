-- s6-ui-core (round 86; decision 2026-10-12-original-pregame-screens): 7.x's own title screen, 7.5.2's MainMenuPane
-- (0x004F6700) and its Login entry's LoginDialogPane (0x004FA7A0). Its layout is title.xml's; its script is the twins'
-- shared one (interfaces/original/title.lua: the menu, the dialog, and the WIRE note on OK and the wait), made with 7.x's
-- kit. Only the XML twin has it.

local X = require("interfaces.7x.draw")

local data = TK.Xml.Data("title.xml")

return require("interfaces.original.title")({
    data = data,
    load = function(opts)
        local ui = TK.Xml.Load("title.xml", opts) -- (not a tail call: the loader finds title.xml beside this file)
        return ui
    end,
    S = require("interfaces.7x.skin"),
    X = X,
    elements = require("interfaces.7x.elements"),
    -- s6-ui-core (round 97, 4a and the live 7.5.2 beside ours, r97-pictures): an image button shows its active picture
    -- (BUTT001.EPF's frame 4 id + 3) only while it is the active control, the stop Tab moved to (ControlPane.cpp:638-671;
    -- the account field is active as the dialog opens, SetHoverControl(3)); OK, the default control, keeps its normal
    -- picture until then, with no Enter frame round it (the dialog's own picture covers DialogPane's: the live 7.5.2's
    -- filled dialog). Drawing only.
    focus = function(button, on)
        button:GetNormalTexture():SetTexture(on and button.focusedPicture or button.normalPicture)
    end,
})
