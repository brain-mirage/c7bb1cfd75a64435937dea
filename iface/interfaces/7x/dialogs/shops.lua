-- s6-modular-g (interfaces, round 13): 7.x's look of the hired merchant, its price window, the clan bank, the power
-- dialog and the rankings (components/dialogs/shops.lua), from Source-5's class pages. Drawing only: the indexes, the
-- slots' presses, the fields and what is sent are the renderer's and the model's.
--
-- The hired merchant (EmployeeDialogPane 0x004A1D70): 307 x 350 at placement slot 18 (centred), sliding open; 4a's
-- standard window (DLGFRAME) under SELLER.EPF frame 0 in SELLER.PAL (OnPaint 0x004A2560); ADD (0, image 36) (22, 314),
-- WITHDRAW (1, 52) (90, 314), REMOVE (2, 54) (157, 314)-(220, 340), OK (3, 14) (223, 314); the ten slots (4-13), 48 x 48
-- from (20, 109), five to a row 56 apart, the second row 84 lower: the item's picture in its 44 x 44 box, its count "%d"
-- centred under it in (30, 161)-(54, 173) moved alike; in 0x8F, each centred on its rectangle by 6 pixels a character
-- (x = (l + r) / 2 - 3 x length, the line on its bottom): the owner in (90, 59)-(162, 71), the money with commas in
-- (246, 83)-(324, 95), "%2d/%2d" (the filled slots, 10) in (78, 83)-(114, 95); the message line from (24, 285): over a
-- slot its item, count and price ("%s [ %d ] : " and the price with commas, then " 전"), else the demolition's hours
-- (secs / 3600 + 1).
-- The price window (EmployeeItemPropertyDialogPane 0x004A41C0): 307 x 124 at slot 20, sliding open; DLGFRAME under
-- SELLITEM.EPF frame 0 in SELLITEM.PAL; TAKE BACK (0, 53) (42, 90), OK (1, 14) (119, 90), CANCEL (2, 22) (196, 90); the
-- price's edit (3) (120, 47)-(283, 59) in 0x8F; the item's name (120, 25)-(180, 37) and count (259, 25)-(287, 37) in 0x8F;
-- its picture in the 44 x 44 box at (20, 21).
-- The clan bank (ClanBankPane 0x0048B1C0): 448 x 475 at (50, 50) (no placement slot), no slide; CLANBAN1.EPF in
-- CLANBAN1.PAL; CLOSE (1, 30) (190, 438), WITHDRAW (2, 53; SEND, 23, in mode 1) (340, 397); the amount (3) (300, 402)-(324,
-- 414) in 0x8F; the items (4) (15, 95)-(415, 375) of 400 x 40 rows (ClanBankItemListPane::DrawListEntry 0x0048C040: the
-- picture at its size centred on x 30 and the row's middle, the text from x 70 fitted to the row's right - 70 with "...",
-- in 0x8F; the chosen row on a 0x80 bar to the right - 13); the count (5) (328, 62)-(388, 74) in 0x8F.
-- The power dialog (PowerDialogPane 0x00549C20): the shared layout (interfaces/power.lua, s6-interface-5x-b round 7: 5.x's
-- look draws the same window with 5.33's buttons) with 7.5.2's 63 x 24 buttons at y 307.
-- The rankings (RankingDialog 0x00458610): 820 x 560 at (102, 74), sliding open; the web board's frame with an inner edge
-- at 265 (OnPaint 0x00458B50); CLOSE (0, 30) (379, 528); the categories (1) (10, 44)-(265, 514): rows 222 x 43 from
-- (8, 4), 47 apart, each SUBWIN's frame round its title in 0x8F outlined in 0x80 at (40, 26), its state's glyph in a
-- 20 x 20 box at (10, 10) (DrawRankingRecordRow 0x0045B630), the chosen row framed three pixels deep in 0x80; the table
-- (2) (290, 44)-(790, 490) (RankingUserListPane::OnPaint 0x0045F3A0): outlined texts, the title at (30, 24), "Total : %d"
-- at (380, 24), "From : ..." at (30, 50), "To : ..." at (210, 50), Rank, Name and Score at x 50, 150 and 390 on the line
-- 78, the ten rows on the lines 100 + 30 i, three lines in 0x8F at y 384-386 from x 30 to 490, the player's own row on
-- the line 412; < (3, 44) (460, 480), > (4, 45) (580, 480), RewardInfo (5) (320, 480) and GetReward (6) (700, 480) as
-- 80 x 24 flat text buttons (FittingRoomTextButtonControlPane: 0xD4, bevels 0xD0 and 0xD8).
-- The rewards (RankingRewardInfoDialog 0x0045DBA0): 620 x 500 at (202, 104), sliding open; the web board's frame; OK (0,
-- 14) (279, 468); outlined texts: the category's title at (30, 64), Rank, Reward Legend and Reward Items on the line 86
-- at x 30, 110 and 290; the tiers from the line 110, 26 apart (OnPaint 0x0045DF90).

local S = require("interfaces.7x.skin")

return function(L, X)
    local K = TK.Dialogs

    --- A text of the window's own (made once under key), its pen at (x, line): the glyphs from line - 11, in colour.
    local function pen(win, key, x, line, colour, parent)
        local fs = win[key]
        if not fs then
            fs = (parent or win):CreateFontString(nil, "OVERLAY")
            win[key] = fs
        end
        S.Text(fs, colour or 0x8F)
        fs:SetWordWrap(false)
        fs:SetJustifyH("LEFT")
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", parent or win, "TOPLEFT", x, -(line - 11))
        fs:Show()
        return fs
    end

    --- A text centred on the rectangle (l, t)-(r, b) by 6 pixels a character, its line on b (EmployeeDialogPane's).
    local function centred(win, key, text, l, r, b)
        pen(win, key, math.floor((l + r) / 2) - 3 * #text, b, 0x8F):SetText(text)
    end

    -- a text drawn outlined (DrawOutlinedTextAt): the look's helper (s6-interface-7x round 2: X.Outlined, moved there)
    local outlined = X.Outlined

    --- An item's picture at its own size, centred on (cx, cy) of a frame, clipped to it (DrawItemImage), with its colour
    --- (the dye: TK.Art.Item, s6-interface-7x round 2); hidden for nil. s6-characters (round 43): a cycling item at the
    --- step the window draws it at, drawn again with a list's row (X.ItemPicture).
    local function picture(owner, key, item, cx, cy, colour)
        local tex = owner[key]
        if not tex then
            tex = owner:CreateTexture(nil, "ARTWORK")
            owner[key] = tex
        end
        local art, w, h = X.ItemPicture(owner, tex, item, colour)
        tex:SetShown(art ~= nil)
        if not art then return end
        tex:SetTexture(art)
        tex:SetSize(w, h)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", owner, "TOPLEFT", cx - math.floor(w / 2), -(cy - math.floor(h / 2)))
    end

    --- The item icons of the renderers (the hired merchant's slots, the bank's rows) are this look's own: nothing here.
    function L.ItemIcon(r, item, size) end

    -- ----- the hired merchant -----

    --- Slot i's rectangle (EmployeeDialogPane's m_slotRects: 48 x 48 from (20, 109), 56 apart, the second row 84 lower).
    local function slotAt(i)
        local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
        return 20 + 56 * col, 109 + 84 * row
    end

    -- the demolition's hours ("철거까지 %d 시간 미만 남았습니다.": less than %d hours to demolition)
    local DEMOLITION = "\236\178\160\234\177\176\234\185\140\236\167\128 %d \236\139\156\234\176\132 \235\175\184\235\167\140 \235\130\168\236\149\152\236\138\181\235\139\136\235\139\164."

    L.HiredMerchant = {
        width = 307, height = 350, button = 63, icon = 44, slide = true,
        place = function(win)
            X.Frame(win, 307, 350, "DLGFRAME.EPF", "PAL01.PAL", 14)
            X.Art(win, "SELLER.EPF", "SELLER.PAL")
            X.Image(win, win.controls[0], 36, 22, 314, 85, 338)
            X.Image(win, win.controls[1], 52, 90, 314, 153, 338)
            X.Image(win, win.controls[2], 54, 157, 314, 220, 340)
            X.Image(win, win.controls[3], 14, 223, 314, 286, 338)
            win.owner:Hide()
            win.money:Hide()
        end,
        --- Slot i: a 48 x 48 press area (its index the renderer's); its picture and count drawn by fill.
        slot = function(win, i)
            local b = CreateFrame("Button", nil, win)
            local x, y = slotAt(i)
            X.Rect(b, win, x, y, x + 48, y + 48)
            b.text = b:CreateFontString(nil, "OVERLAY")
            b.text:Hide()
            b:HookScript("OnEnter", function() win.x7over = i L.HiredMerchant.message(win) end)
            b:HookScript("OnLeave", function() if win.x7over == i then win.x7over = nil end L.HiredMerchant.message(win) end)
            return b
        end,
        -- after the renderer's update: the texts, the slots' pictures and counts, the message line
        fill = function(win, c)
            win.x7contents = c
            centred(win, "x7owner", K.Text(c.owner), 90, 162, 71)
            centred(win, "x7money", TK.Util.FormatNumber(c.money or 0), 246, 324, 95)
            local filled = 0
            for i = 1, 10 do
                local r = c.slots and c.slots[i]
                local x, y = slotAt(i)
                picture(win, "x7pic" .. i, type(r) == "table" and r[2] or nil, x + 22, y + 22, type(r) == "table" and r[3] or nil)
                if type(r) == "table" then
                    filled = filled + 1
                    centred(win, "x7count" .. i, string.format("%d", r[5] or 0), x + 10, x + 34, y + 64)
                elseif win["x7count" .. i] then
                    win["x7count" .. i]:Hide()
                end
            end
            centred(win, "x7slots", string.format("%2d/%2d", filled, 10), 78, 114, 95)
            L.HiredMerchant.message(win)
        end,
        --- The message line (EmployeeDialogPane::OnPaint): over a filled slot its item, count and price, else the
        --- demolition's hours (unless the model hides them).
        message = function(win)
            local c = win.x7contents
            if not c then return end
            local r = win.x7over and c.slots and c.slots[win.x7over]
            local text = ""
            if type(r) == "table" then
                text = string.format("%s [ %d ] : ", K.Text(r[4]), r[5] or 0) .. TK.Util.FormatNumber(r[6] or 0) .. " \236\160\132"
            elseif c.demolitionShown ~= false then
                text = string.format(DEMOLITION, math.floor((c.seconds or 0) / 3600) + 1)
            end
            pen(win, "x7message", 24, 285, 0x8F):SetText(text)
        end,
    }

    L.Price = {
        width = 307, height = 124, button = 63, editWidth = 163, editHeight = 12, slide = true,
        place = function(win)
            X.Frame(win, 307, 124, "DLGFRAME.EPF", "PAL01.PAL", 14)
            X.Art(win, "SELLITEM.EPF", "SELLITEM.PAL")
            X.Image(win, win.controls[0], 53, 42, 90, 105, 114)
            X.Image(win, win.controls[1], 14, 119, 90, 182, 114)
            X.Image(win, win.controls[2], 22, 196, 90, 259, 114)
            X.Edit(win.edit, win, 120, 47, 283, 59, 0x8F)
            win.text:Hide()
        end,
        -- after the renderer's update: the item's name, count and picture (the record's, from the merchant's window)
        fill = function(win, c)
            local merchant = TK.Dialogs.Find("EmployeeDialogPane")
            local slots = merchant and merchant.view and merchant.view.contents.slots or {}
            local r
            for _, s in pairs(slots) do if type(s) == "table" and s[1] == c.record then r = s end end
            local name = pen(win, "x7name", 120, 37, 0x8F)
            name:SetText(r and X.Fit(K.Text(r[4]), 60) or "")
            pen(win, "x7count", 259, 37, 0x8F):SetText(string.format("%d", c.count or 0))
            picture(win, "x7pic", r and r[2] or nil, 42, 43, r and r[3] or nil)
        end,
    }

    -- ----- the clan bank -----

    L.Bank = {
        width = 448, height = 475, button = 63, listWidth = 387, listHeight = 280, amountWidth = 24, editHeight = 12,
        -- at (50, 50), where ClanBankPane's AddToLayer puts it (no placement slot), unclamped
        centre = function(win) return 50 + 224, 50 + 237, false end,
        place = function(win)
            X.Art(win, "CLANBAN1.EPF", "CLANBAN1.PAL")
            X.Image(win, win.close, 30, 190, 438, 253, 462)
            X.Edit(win.amount, win, 300, 402, 324, 414, 0x8F)
            X.List(win, win.list, 15, 95, 415, 375, 387, 40)
            win.list.rowPainter = function(row, selected)
                S.Fill(row.sel, S.TEXT)
                if row.x7name then row.x7name:SetTextColor(S.Colour(0x8F)) end
            end
            X.Text(win.count, win, 328, 62, 388, 74, 0x8F)
        end,
        --- A row: its item's picture at its size centred on x 30 and the middle; its text from x 70, fitted to 330.
        row = function(r, item)
            picture(r, "x7pic", item, 30, 20)
            r.text:Hide()
            local name = X.RowText(r, "x7name", 70)
            if not r.x7fit then
                r.x7fit = true
                local set = r.text.SetText
                r.text.SetText = function(self, text)
                    set(self, text)
                    r.x7name:SetText(X.Fit(text or "", 330))
                end
            end
            return name
        end,
        -- after the renderer's update: the action's picture by the mode (WITHDRAW 53, SEND 23)
        fill = function(win, c)
            X.Image(win, win.action, c.mode == 1 and 23 or 53, 340, 397, 403, 421)
        end,
    }

    -- ----- the power dialog -----

    -- s6-interface-5x-b (round 7): the shared layout with 7.5.2's 63 x 24 buttons at y 307 (interfaces/power.lua)
    L.Power = require("interfaces.power").Entry(X, S, { width = 63, height = 24, top = 307 })

    -- ----- the rankings and their rewards -----

    local GLYPHS = { [0] = 0xC2A6, [1] = 0xC2A9 } -- a category's state's glyph (state 2: none; others: 0xC2A9)

    --- A category row's box (made once): the row itself (category below), on SUBWIN's frame, its chosen frame three
    --- pixels deep round it in 0x80; its glyph and title are drawn on it (over its tiles).
    local function categoryBox(row)
        if row.x7box then return row.x7box end
        local box = CreateFrame("Frame", nil, row)
        box:SetAllPoints(row)
        X.Frame(box, 222, 43, "SUBWIN.EPF", "SUBWIN.PAL", 7)
        row.x7chosen = {}
        for k = 1, 3 do
            for _, side in ipairs({ "top", "left", "bottom", "right" }) do
                local t = X.Solid(box, "OVERLAY", S.TEXT)
                X.Line(box, t, side, k, true)
                row.x7chosen[#row.x7chosen + 1] = t
            end
        end
        row.x7box = box
        return box
    end

    L.Rankings = {
        width = 820, height = 560, button = 63, categoriesWidth = 222, categoriesHeight = 470, rowsWidth = 500,
        rowsHeight = 300, slide = true,
        -- at (102, 74), where RankingDialog's AddToLayer puts it (no placement slot), unclamped
        centre = function(win) return 102 + 410, 74 + 280, false end,
        place = function(win)
            X.WebFrame(win, 820, 560, { 265 })
            X.Image(win, win.controls[0], 30, 379, 528, 442, 552)
            X.Image(win, win.controls[3], 44, 460, 480, 523, 504)
            X.Image(win, win.controls[4], 45, 580, 480, 643, 504)
            X.TextButton(win, win.controls[5], 320, 480, 400, 504, 0xD4, 0xD0, 0xD8)
            X.TextButton(win, win.controls[6], 700, 480, 780, 504, 0xD4, 0xD0, 0xD8)
            X.List(win, win.categories, 10, 44, 265, 514, 222, 47)
            win.categories.rowPainter = function(row, selected)
                row.sel:SetAlpha(0)
                row.text:Hide()
                categoryBox(row)
                for _, t in ipairs(row.x7chosen) do t:SetShown(selected) end
            end
            -- the table's own parts: its headers and its separator
            outlined(win, "x7rank", 290 + 50, 44 + 78, "Rank")
            outlined(win, "x7nameHead", 290 + 150, 44 + 78, "Name")
            outlined(win, "x7score", 290 + 390, 44 + 78, "Score")
            for k = 0, 2 do
                local t = win["x7line" .. k] or X.Solid(win, "ARTWORK", 0x8F)
                win["x7line" .. k] = t
                X.Rect(t, win, 290 + 30, 44 + 384 + k, 290 + 490, 44 + 385 + k)
            end
            for _, key in ipairs({ "head", "total", "dates", "own" }) do win[key]:Hide() end
            -- the ten rows on the table's lines 100 + 30 i: each row 30 high, its line 21 down (from the table's 79)
            X.List(win, win.rows, 290, 44 + 79, 790, 44 + 379, 487, 30)
            win.rows.rowPainter = function(row) row.sel:SetAlpha(0) row.text:Hide() end
        end,
        -- a category's row: its 222 x 43 box at (8, 4) of the 47-pixel row the list placed, its glyph and its outlined
        -- title (the renderer's row.text, hidden).
        -- Input routing (wire): RankingEventListPane::HitTestRow (0x0045BD10) takes a press on a row's box only, so the
        -- row is its box: a press in the 4 pixels above a box or beside it is no row's and asks for no category's rows
        -- (7D 02), as a press below the rows of the kit's own list (in a slide, K.PressAt gives it as the list's miss).
        -- Changing the row's rectangle changes what such a press sends.
        category = function(win, row, cat)
            local _, rel, _, _, y = row:GetPoint(1)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", rel, "TOPLEFT", 8, y - 4)
            row:SetSize(222, 43)
            local box = categoryBox(row)
            local glyph = cat[3] ~= 2 and (GLYPHS[cat[3]] or GLYPHS[1]) or nil
            picture(box, "x7glyph", glyph, 10 + 10, 10 + 10)
            if box.x7glyph and glyph then
                local w, h = box.x7glyph:GetSize()
                if w > 20 or h > 20 then box.x7glyph:SetSize(math.floor(w / 2), math.floor(h / 2)) end
            end
            outlined(row, "x7title", 40, 26, K.Text(cat[2]), box)
        end,
        -- a row of the table ({ rank, name, score }): its three columns, outlined
        row = function(win, row, r)
            outlined(row, "x7c1", 50, 21, string.format("%d", r[1] or 0), row)
            outlined(row, "x7c2", 150, 21, K.Text(r[2]), row)
            outlined(row, "x7c3", 390, 21, string.format("%d", r[3] or 0), row)
        end,
        -- after the renderer's update: the chosen category's title, total and dates; the player's own row
        fill = function(win, c)
            local sel
            for _, cat in ipairs(c.categories or {}) do if cat[1] == c.selected then sel = cat end end
            local function date(d, t)
                d, t = d or 0, t or 0
                return string.format("%02d/%02d/%04d %02d:%02d:%02d", math.floor(d / 100) % 100, d % 100, math.floor(d / 10000),
                    math.floor(t / 10000), math.floor(t / 100) % 100, t % 100)
            end
            outlined(win, "x7title", 290 + 30, 44 + 24, sel and K.Text(sel[2]) or "")
            outlined(win, "x7total", 290 + 380, 44 + 24, sel and string.format("Total : %d", c.total or 0) or "")
            outlined(win, "x7from", 290 + 30, 44 + 50, sel and ("From : " .. date(sel[4], sel[5])) or "")
            outlined(win, "x7to", 290 + 210, 44 + 50, sel and ("To : " .. date(sel[6], sel[7])) or "")
            local own = c.own
            local shown = sel and type(own) == "table" and own[1] and own[1] > 0
            outlined(win, "x7own1", 290 + 50, 44 + 412, shown and string.format("%d", own[1]) or "")
            outlined(win, "x7own2", 290 + 150, 44 + 412, shown and K.Text(c.ownName) or "")
            outlined(win, "x7own3", 290 + 390, 44 + 412, shown and string.format("%d", own[2] or 0) or "")
        end,
    }

    L.Rewards = {
        width = 620, height = 500, button = 63, slide = true,
        -- at (202, 104), where RankingRewardInfoDialog's AddToLayer puts it (no placement slot), unclamped
        centre = function(win) return 202 + 310, 104 + 250, false end,
        place = function(win)
            X.WebFrame(win, 620, 500)
            X.Image(win, win.ok, 14, 279, 468, 342, 492)
            win.text:Hide()
            outlined(win, "x7rank", 30, 86, "Rank")
            outlined(win, "x7legend", 110, 86, "Reward Legend")
            outlined(win, "x7items", 290, 86, "Reward Items")
        end,
        -- after the renderer's update: the category's title and each tier's rank, legend and items on its line
        fill = function(win, c)
            local title = ""
            local rankings = TK.Dialogs.Find("RankingDialog")
            for _, cat in ipairs(rankings and rankings.view and rankings.view.contents.categories or {}) do
                if cat[1] == c.category then title = K.Text(cat[2]) end
            end
            outlined(win, "x7title", 30, 64, title)
            -- a pooled window opened again with fewer tiers: the earlier tiers' texts go first (Astra's re-review of round
            -- 13); the tiers drawn now show theirs again
            for key, set in pairs(win) do
                if type(key) == "string" and key:find("^x7tier") then
                    for _, part in ipairs(set) do part.fs:Hide() end
                end
            end
            for i, t in ipairs(c.tiers or {}) do
                local line = 110 + 26 * (i - 1)
                local rank = t[1] == t[2] and K.Text(t[1]) or (K.Text(t[1]) .. " ~ " .. K.Text(t[2]))
                outlined(win, "x7tierRank" .. i, 30, line, rank)
                outlined(win, "x7tierLegend" .. i, 110 + 20, line, K.Text(t[3]))
                local items = {}
                for _, it in ipairs(t[5] or {}) do items[#items + 1] = string.format("%s(%d)", K.Text(it[1]), it[2] or 0) end
                outlined(win, "x7tierItems" .. i, 290 + 10, line, table.concat(items, "   "))
            end
        end,
    }
end
