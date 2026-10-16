-- s6-modular-g (interfaces); step 6 of the interface separation (s6-characters, round 46): Modern's dialogs look. It is
-- the default look as it is (components/dialogs/look/, today's Modern numbers), drawn with Modern's skin (s6-devtools,
-- step 5; built by the default's With, s6-characters round 47), with only what names Modern's own frames here: the Menu
-- popup opens above its micro menu. A look only sizes and places: nothing here reaches the model or the server.

local L = require("components.dialogs.look").With(require("interfaces.modern.skin").UI)

-- D-55: the Menu popup above Modern's micro menu (the default's corner while the micro menu is off).
local popup = L.MenuPopup
L.MenuPopup = setmetatable({
    open = function(win)
        local anchor = _G.TKMicroMenu
        if anchor then win:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 4)
        else popup.open(win) end
    end,
}, { __index = popup })

return L
