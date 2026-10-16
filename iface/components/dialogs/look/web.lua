-- s6-modular-g (interfaces): the default look of the web board and the browser dialog (components/dialogs/web.lua).

return function(L, P)
    --- The page: its text across the top, the address under it, Open in browser at the bottom left; the dialog's own
    --- button (close) at the bottom right.
    local function place(win, close)
        P.Across(win.text, win, 20, 20, -40)
        win.url:SetPoint("TOPLEFT", win.text, "BOTTOMLEFT", 0, -10)
        win.url:SetPoint("RIGHT", win, "RIGHT", -20, 0)
        win.open:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 16, 14)
        close:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -16, 14)
    end

    -- D-52: the web board.
    L.WebBoard = {
        width = 460, height = 180, button = 90, openButton = 140, buttonHeight = 24,
        place = function(win) place(win, win.close) end,
    }

    -- D-53: the browser dialog.
    L.Browser = {
        width = 460, height = 170, button = 90, openButton = 140, buttonHeight = 24,
        place = function(win) place(win, win.ok) end,
    }
end
