-- s6-interface-7x-b (round 7): 7.x's look of the window of a dialog without one of its own (components/dialogs/generic.lua:
-- the classes no renderer draws yet). 4a has no such window: each of those classes has its own, not drawn here. This is
-- 4a's standard dialog in their stead, as the alerts draw it (alerts.lua): the standard window (X.DIALOG_FRAME), its
-- texts in font 0, colour 0x80, from (24, 24), and its buttons 4a's 74 x 20 text buttons along the bottom from (W - 98,
-- H - 44), the last control rightmost, 86 pixels apart. Drawing only, but for where each button's press lands: the
-- buttons, their indexes and what is sent are the renderer's and the model's.
-- s6-ui-core (round 85): the XML twin's; the window's size, text and buttons' places are generic.xml's (core/xml.md).

local S = require("interfaces.7x.skin")
local entry = require("interfaces.xml.entry")
local D = TK.Xml.Data("generic.xml")

return function(L, X)
    local G = D.Generic
    local T, B = G.text, G.buttons

    L.Generic = entry(G, {
        place = function(win)
            S.Text(win.text, S.TEXT)
            win.text:SetWordWrap(true)
        end,
        --- as tall as its texts (12-pixel lines) and the buttons' row, at least 140
        fit = function(win)
            local w = G.width
            X.Text(win.text, win, T.left, T.top, w - T.right, T.top)
            local h = math.max(G.height, math.floor(win.text:GetStringHeight() + 0.5) + G.below)
            X.Size(win, w, h)
            X.Frame(win, w, h, X.DIALOG_FRAME.file, X.DIALOG_FRAME.palette, X.DIALOG_FRAME.tile)
            for i, b in ipairs(win.buttons) do
                local r = w - B.right - (i - 1) * B.step
                X.TextButton(win, b, r - G.button, h - B.top, r, h - B.bottom)
            end
        end,
    })
end
