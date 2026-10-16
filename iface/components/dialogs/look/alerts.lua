-- s6-modular-g (interfaces): the default look of the alerts (components/dialogs/alerts.lua).

return function(L, P)
    -- The message centred under the title, the address under it, the buttons along the bottom (one centred, or two
    -- side by side); 20 higher than the other windows when it opens.
    L.Alert = {
        width = 360, height = 150, button = 120, buttonHeight = 24, y = 80,
        place = function(win)
            P.Across(win.text, win, 18, 18, -36)
            win.url:SetPoint("TOP", win.text, "BOTTOM", 0, -8)
        end,
        -- As tall as the message (and the address).
        fit = function(win, hasUrl)
            local height = math.max(20, win.text:GetStringHeight()) + (hasUrl and 22 or 0)
            win:SetHeight(height + 96)
        end,
        buttons = function(win, two)
            win.b1:ClearAllPoints()
            win.b2:ClearAllPoints()
            if two then
                P.Bottom(win.b1, win, -66, 16)
                P.Bottom(win.b2, win, 66, 16)
            else
                P.Bottom(win.b1, win, 0, 16)
            end
        end,
    }
end
