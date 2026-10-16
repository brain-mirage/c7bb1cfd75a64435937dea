-- s6-modular-g (interfaces): the default look of the user list, the party search and the friends
-- (components/dialogs/social.lua).

return function(L, P)
    -- D-57: the nation's pages at the top left with the totals beside them, the five columns side by side with their
    -- counts under them, the selected row's note under the columns, the switches and Party Search at the bottom left,
    -- Close at the bottom right.
    L.Users = {
        width = 712, height = 470, button = 80, page = 30, party = 110, columnWidth = 128, columnHeight = 270,
        place = function(win)
            P.At(win.prev, win, 16, -34)
            win.nation:SetPoint("LEFT", win.prev, "RIGHT", 6, 0)
            win.nation:SetWidth(140)
            win.next:SetPoint("LEFT", win.nation, "RIGHT", 6, 0)
            win.total:SetPoint("LEFT", win.next, "RIGHT", 16, 0)
            for c, list in ipairs(win.lists) do
                P.At(list.sf, win, 16 + (c - 1) * 138, -66)
                win.counts[c]:SetPoint("TOP", list.sf, "BOTTOM", 0, -4)
            end
            win.note:SetPoint("TOPLEFT", win.lists[1].sf, "BOTTOMLEFT", 0, -24)
            win.note:SetPoint("TOPRIGHT", win.lists[5].sf, "BOTTOMRIGHT", 0, -24)
            win.sort:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 16, 44)
            win.only:SetPoint("LEFT", win.sort, "RIGHT", 90, 0)
            win.party:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 16, 14)
            win.close:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -14, 14)
        end,
    }

    -- D-58: the switch, the note under it, OK at the bottom; opening right of the user list.
    L.PartySearch = {
        width = 320, height = 160, button = 90, editWidth = 280, editHeight = 24, x = 200,
        place = function(win)
            P.At(win.hunters, win, 18, -40)
            P.At(win.note, win, 20, -76)
            P.Bottom(win.ok, win, 0, 14)
        end,
    }

    -- D-59: the twenty names in two columns of ten, OK at the bottom.
    L.Friends = {
        width = 420, height = 330, button = 90, editWidth = 180, editHeight = 22,
        place = function(win)
            for i, e in ipairs(win.edits) do
                local col, row = (i - 1) // 10, (i - 1) % 10
                P.At(e, win, 20 + col * 196, -38 - row * 26)
            end
            P.Bottom(win.ok, win, 0, 14)
        end,
    }
end
