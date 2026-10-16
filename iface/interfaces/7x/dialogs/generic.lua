-- s6-interface-7x-b (round 7): 7.x's look of the window of a dialog without one of its own (components/dialogs/generic.lua:
-- the classes no renderer draws yet). 4a has no such window: each of those classes has its own, not drawn here. This is
-- 4a's standard dialog in their stead, as the alerts draw it (alerts.lua): the standard window (X.DIALOG_FRAME), its
-- texts in font 0, colour 0x80, from (24, 24), and its buttons 4a's 74 x 20 text buttons along the bottom from (W - 98,
-- H - 44), the last control rightmost, 86 pixels apart. Drawing only, but for where each button's press lands: the
-- buttons, their indexes and what is sent are the renderer's and the model's.

local S = require("interfaces.7x.skin")

return function(L, X)
    local WIDTH = 380

    L.Generic = {
        width = WIDTH, height = 140, button = 74,
        place = function(win)
            S.Text(win.text, S.TEXT)
            win.text:SetWordWrap(true)
        end,
        --- as tall as its texts (12-pixel lines) and the buttons' row, at least 140
        fit = function(win)
            local w = WIDTH
            X.Text(win.text, win, 24, 24, w - 24, 24)
            local h = math.max(140, math.floor(win.text:GetStringHeight() + 0.5) + 80)
            X.Size(win, w, h)
            X.Frame(win, w, h, X.DIALOG_FRAME.file, X.DIALOG_FRAME.palette, X.DIALOG_FRAME.tile)
            for i, b in ipairs(win.buttons) do
                local r = w - 24 - (i - 1) * 86
                X.TextButton(win, b, r - 74, h - 44, r, h - 24)
            end
        end,
    }
end
