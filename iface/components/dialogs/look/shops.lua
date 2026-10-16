-- s6-modular-g (interfaces): the default look of the hired merchant, the price, the clan bank, the power dialog and
-- the rankings (components/dialogs/shops.lua).

return function(L, P, W) -- W: the skin the look is drawn with (init.lua's Build)

    --- The shops' button rows: from the bottom right, 14 in, 6 apart.
    local function row(win) P.Row(win, win.row, 14, 14, 6) end

    --- An item's icon (ItemObjImageLib: the server's picture id, 0xC000-biased) at the left of a row, size high; none for
    --- nil.
    function L.ItemIcon(r, item, size)
        if not r.icon then
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
        end
        local key, w, h
        if item then key, w, h = TK.Art.Icon((item + 0x4000) % 0x10000) end
        if key then
            TK.Art.Place(r.icon, r, key, w, h, size)
            r.icon:ClearAllPoints()
            r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
            r.icon:Show()
        else
            r.icon:Hide()
        end
    end

    -- D-25: the owner and the money at the top, the ten slots in a column (each a row with its item's icon), the buttons
    -- from the bottom right.
    L.HiredMerchant = {
        width = 420, height = 470, button = 80, icon = 26,
        place = function(win)
            P.At(win.owner, win, 20, -38)
            win.money:SetPoint("TOPLEFT", win.owner, "BOTTOMLEFT", 0, -6)
            row(win)
        end,
        --- Slot i: a row 380 x 30 under the money, its text right of the icon.
        slot = function(win, i)
            local b = CreateFrame("Button", nil, win)
            b:SetSize(380, 30)
            P.At(b, win, 20, -80 - (i - 1) * 32)
            local bg = b:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(b)
            bg:SetColorTexture(0, 0, 0, 0.35)
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(b)
            hl:SetColorTexture(1, 1, 1, 0.08)
            b.text = W.Label(b, "", 13, W.white, "LEFT")
            b.text:SetPoint("LEFT", b, "LEFT", 36, 0)
            return b
        end,
    }

    -- D-28: the question across the top, the price under it, the buttons from the bottom right.
    L.Price = {
        width = 340, height = 170, button = 90, editWidth = 160, editHeight = 24,
        place = function(win)
            P.Across(win.text, win, 18, 18, -34)
            win.edit:SetPoint("TOP", win, "TOP", 0, -76)
            row(win)
        end,
    }

    -- D-29: the count at the top right, the list, the amount with its caption and the action under it, CLOSE at the
    -- bottom.
    L.Bank = {
        width = 448, height = 470, button = 90, listWidth = 400, listHeight = 320, amountWidth = 70, editHeight = 24,
        place = function(win)
            win.count:SetPoint("TOPRIGHT", win, "TOPRIGHT", -24, -38)
            P.At(win.list.sf, win, 24, -58)
            local a = W.Label(win, "Amount", 13, W.gold, "LEFT")
            a:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 24, 52)
            win.amount:SetPoint("LEFT", a, "RIGHT", 10, 0)
            win.action:SetPoint("LEFT", win.amount, "RIGHT", 12, 0)
            P.Bottom(win.close, win, 0, 14)
        end,
        --- A row of the list: its item's icon, 18 high, and its text right of it.
        row = function(r, item)
            L.ItemIcon(r, item, 18)
            r.text:ClearAllPoints()
            r.text:SetPoint("LEFT", r, "LEFT", 28, 0)
        end,
    }

    -- D-30: the four lists side by side, under them the five rows (A to D with their thresholds, COLOR) and the 5 x 5
    -- grid right of them, the buttons from the bottom right.
    L.Power = {
        width = 606, height = 400, button = 70, listWidth = 132, listHeight = 130, thresholdWidth = 40, thresholdHeight = 18,
        place = function(win)
            for k, l in ipairs(win.lists) do P.At(l.sf, win, 20 + (k - 1) * 142, -40) end
            local labels = { "A", "B", "C", "D", "COLOR" }
            for r = 1, 5 do
                local y = -184 - (r - 1) * 20
                P.At(W.Label(win, labels[r], 12, W.gold, "LEFT"), win, 20, y)
                if win.thresholds[r] then P.At(win.thresholds[r], win, 70, y + 2) end
                for col = 1, 5 do win.grid[r][col]:SetPoint("TOPRIGHT", win, "TOPLEFT", 180 + col * 80, y) end
            end
            row(win)
        end,
    }

    -- D-31: the categories on the left; right of them the chosen one's heading, total and dates, its rows and the
    -- player's own row under them; the buttons from the bottom right.
    L.Rankings = {
        width = 760, height = 520, button = 86, categoriesWidth = 230, categoriesHeight = 420, rowsWidth = 466,
        rowsHeight = 250,
        place = function(win)
            P.At(win.categories.sf, win, 20, -40)
            P.At(win.head, win, 270, -44)
            win.total:SetPoint("TOPRIGHT", win, "TOPRIGHT", -24, -44)
            win.dates:SetPoint("TOPLEFT", win.head, "BOTTOMLEFT", 0, -6)
            P.At(win.rows.sf, win, 270, -96)
            win.own:SetPoint("TOPLEFT", win.rows.sf, "BOTTOMLEFT", 6, -10)
            row(win)
        end,
    }

    -- D-32: the columns' heading, the tiers under it, OK at the bottom.
    L.Rewards = {
        width = 620, height = 440, button = 90,
        place = function(win)
            P.At(W.Label(win, "Rank        Reward Legend               Reward Items", 12, W.gold, "LEFT"), win, 24, -40)
            P.Across(win.text, win, 24, 24, -62)
            P.Bottom(win.ok, win, 0, 14)
        end,
    }
end
