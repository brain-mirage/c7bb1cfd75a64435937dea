-- s6-modular-g (interfaces): the default look of the trade and mixing (components/dialogs/exchange.lua).

return function(L, P, W) -- W: the skin the look is drawn with (init.lua's Build)

    -- D-18: the player's side on the left (its list, its coins), the partner's on the right, who is ready at the bottom
    -- left, Accept, Add and Cancel from the bottom right.
    L.Trade = {
        width = 520, height = 330, button = 80, listWidth = 230, listHeight = 170, moneyWidth = 150, editHeight = 24,
        place = function(win)
            P.At(W.Label(win, "You", 13, W.gold, "LEFT"), win, 20, -38)
            P.At(win.theirLabel, win, 270, -38)
            P.At(win.mine.sf, win, 20, -58)
            P.At(win.theirs.sf, win, 270, -58)
            local m = W.Label(win, "Coins", 13, W.gold, "LEFT")
            P.At(m, win, 20, -240)
            win.money:SetPoint("LEFT", m, "LEFT", 50, 0)
            P.At(win.theirMoney, win, 270, -244)
            win.ready:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 20, 20)
            P.Row(win, { win.cancel, win.add, win.accept }, 16, 14, 8)
        end,
    }

    -- D-19, D-23, D-26: the item pickers, opening right of the trade window.
    L.Picker = {
        width = 300, height = 320, button = 80, listWidth = 260, listHeight = 220, x = 280,
        place = function(win)
            P.At(win.list.sf, win, 20, -38)
            P.Row(win, { win.cancel, win.ok }, 16, 14, 8)
        end,
    }

    -- D-20, D-24: the count, in the input window (L.Input), opening right of the trade window.
    L.Count = { x = 280 }

    -- D-22: the mix's rows, ADD, DELETE, OK and CANCEL from the bottom right.
    L.Mix = {
        width = 360, height = 320, button = 76, listWidth = 320, listHeight = 200,
        place = function(win)
            P.At(win.list.sf, win, 20, -38)
            P.Row(win, { win.cancel, win.ok, win.delete, win.add }, 14, 14, 6)
        end,
    }
end
