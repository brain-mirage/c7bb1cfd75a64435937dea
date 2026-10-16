-- s6-modular-g (interfaces): the default look of the window of a dialog without one of its own
-- (components/dialogs/generic.lua).

return function(L, P)
    -- Its texts across the top, its buttons along the bottom from the right (the last control rightmost).
    L.Generic = {
        width = 380, height = 200, button = 56,
        place = function(win)
            P.Across(win.text, win, 20, 20, -36)
            for i, b in ipairs(win.buttons) do b:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -14 - (i - 1) * 60, 14) end
        end,
        -- As tall as its texts, at least 140.
        fit = function(win) win:SetHeight(math.max(140, win.text:GetStringHeight() + 96)) end,
    }
end
