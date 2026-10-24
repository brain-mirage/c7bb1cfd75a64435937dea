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
-- s6-ui-core (round 85): the XML twin's; the windows' pictures, buttons, slots, rows and the texts' places are
-- shops.xml's (core/xml.md).

local S = require("interfaces.7x.skin")
local unpack = table.unpack
local entry = require("interfaces.original.entry")
local D = TK.Xml.Data("shops.xml")

return function(L, X)
    local K = TK.Dialogs
    local TEXT = D.TEXT

    --- A text of the window's own (made once under key), its pen at (x, line): the glyphs from line - 11, in colour.
    local function pen(win, key, x, line, colour, parent)
        local fs = win[key]
        if not fs then
            fs = (parent or win):CreateFontString(nil, "OVERLAY")
            win[key] = fs
        end
        S.Text(fs, colour or TEXT)
        fs:SetWordWrap(false)
        fs:SetJustifyH("LEFT")
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", parent or win, "TOPLEFT", x, -(line - 11))
        fs:Show()
        return fs
    end

    --- A text centred on the rectangle (l, t)-(r, b) by 6 pixels a character, its line on b (EmployeeDialogPane's).
    local function centred(win, key, text, l, r, b)
        pen(win, key, math.floor((l + r) / 2) - 3 * #text, b, TEXT):SetText(text)
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

    --- A window placed at (x, y) of the 7.x screen where its AddToLayer puts it (no placement slot), unclamped: its
    --- centre for the look's L.Place.
    local function at(e)
        return function(win) return e.at[1] + math.floor(e.width / 2), e.at[2] + math.floor(e.height / 2), false end
    end

    --- The window's image buttons (shops.xml's buttons: { image, rect } each) on its controls from 0.
    local function buttons(win, list)
        for i, b in ipairs(list) do X.Image(win, win.controls[i - 1], b.image, unpack(b.rect)) end
    end

    --- The item icons of the renderers (the hired merchant's slots, the bank's rows) are this look's own: nothing here.
    function L.ItemIcon(r, item, size) end

    -- ----- the hired merchant -----

    local HM = D.HiredMerchant
    local SLOTS = HM.slots

    --- Slot i's rectangle (EmployeeDialogPane's m_slotRects: 48 x 48 from (20, 109), 56 apart, the second row 84 lower).
    local function slotAt(i)
        local col, row = (i - 1) % SLOTS.columns, math.floor((i - 1) / SLOTS.columns)
        return SLOTS.x + SLOTS.across * col, SLOTS.y + SLOTS.down * row
    end

    -- the demolition's hours ("철거까지 %d 시간 미만 남았습니다.": less than %d hours to demolition)
    local DEMOLITION = "\236\178\160\234\177\176\234\185\140\236\167\128 %d \236\139\156\234\176\132 \235\175\184\235\167\140 \235\130\168\236\149\152\236\138\181\235\139\136\235\139\164."

    L.HiredMerchant = entry(HM, {
        place = function(win)
            X.Frame(win, HM.width, HM.height, unpack(HM.frame))
            X.Art(win, unpack(HM.art))
            buttons(win, HM.buttons)
            win.owner:Hide()
            win.money:Hide()
        end,
        --- Slot i: a 48 x 48 press area (its index the renderer's); its picture and count drawn by fill.
        slot = function(win, i)
            local b = CreateFrame("Button", nil, win)
            local x, y = slotAt(i)
            X.Rect(b, win, x, y, x + SLOTS.size, y + SLOTS.size)
            b.text = b:CreateFontString(nil, "OVERLAY")
            b.text:Hide()
            b:HookScript("OnEnter", function() win.x7over = i L.HiredMerchant.message(win) end)
            b:HookScript("OnLeave", function() if win.x7over == i then win.x7over = nil end L.HiredMerchant.message(win) end)
            return b
        end,
        -- after the renderer's update: the texts, the slots' pictures and counts, the message line
        fill = function(win, c)
            win.x7contents = c
            local o, m, f = HM.owner, HM.money, HM.filled
            centred(win, "x7owner", K.Text(c.owner), o[1], o[2], o[3])
            centred(win, "x7money", TK.Util.FormatNumber(c.money or 0), m[1], m[2], m[3])
            local filled = 0
            for i = 1, SLOTS.count do
                local r = c.slots and c.slots[i]
                local x, y = slotAt(i)
                picture(win, "x7pic" .. i, type(r) == "table" and r[2] or nil, x + SLOTS.icon, y + SLOTS.icon, type(r) == "table" and r[3] or nil)
                if type(r) == "table" then
                    filled = filled + 1
                    centred(win, "x7count" .. i, string.format("%d", r[5] or 0), x + SLOTS.countLeft, x + SLOTS.countRight, y + SLOTS.countLine)
                elseif win["x7count" .. i] then
                    win["x7count" .. i]:Hide()
                end
            end
            centred(win, "x7slots", string.format("%2d/%2d", filled, SLOTS.count), f[1], f[2], f[3])
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
            pen(win, "x7message", HM.message[1], HM.message[2], TEXT):SetText(text)
        end,
    })

    local P = D.Price
    L.Price = entry(P, {
        place = function(win)
            X.Frame(win, P.width, P.height, unpack(P.frame))
            X.Art(win, unpack(P.art))
            buttons(win, P.buttons)
            local e = P.edit
            X.Edit(win.edit, win, e[1], e[2], e[3], e[4], TEXT)
            win.text:Hide()
        end,
        -- after the renderer's update: the item's name, count and picture (the record's, from the merchant's window)
        fill = function(win, c)
            local merchant = TK.Dialogs.Find("EmployeeDialogPane")
            local slots = merchant and merchant.view and merchant.view.contents.slots or {}
            local r
            for _, s in pairs(slots) do if type(s) == "table" and s[1] == c.record then r = s end end
            local n = P.name
            local name = pen(win, "x7name", n.x, n.line, TEXT)
            name:SetText(r and X.Fit(K.Text(r[4]), n.width) or "")
            pen(win, "x7count", P.count[1], P.count[2], TEXT):SetText(string.format("%d", c.count or 0))
            picture(win, "x7pic", r and r[2] or nil, P.picture[1], P.picture[2], r and r[3] or nil)
        end,
    })

    -- ----- the clan bank -----

    local B = D.Bank
    L.Bank = entry(B, {
        -- at (50, 50), where ClanBankPane's AddToLayer puts it (no placement slot), unclamped
        centre = at(B),
        place = function(win)
            X.Art(win, unpack(B.art))
            X.Image(win, win.close, unpack(B.close))
            local a = B.amount
            X.Edit(win.amount, win, a[1], a[2], a[3], a[4], TEXT)
            X.List(win, win.list, unpack(B.list))
            win.list.rowPainter = function(row, selected)
                S.Fill(row.sel, S.TEXT)
                if row.x7name then row.x7name:SetTextColor(S.Colour(TEXT)) end
            end
            local n = B.count
            X.Text(win.count, win, n[1], n[2], n[3], n[4], TEXT)
        end,
        --- A row: its item's picture at its size centred on x 30 and the middle; its text from x 70, fitted to 330.
        row = function(r, item)
            local rw = B.row
            picture(r, "x7pic", item, rw.picture[1], rw.picture[2])
            r.text:Hide()
            local name = X.RowText(r, "x7name", rw.text)
            if not r.x7fit then
                r.x7fit = true
                local set = r.text.SetText
                r.text.SetText = function(self, text)
                    set(self, text)
                    r.x7name:SetText(X.Fit(text or "", rw.width))
                end
            end
            return name
        end,
        -- after the renderer's update: the action's picture by the mode (WITHDRAW 53, SEND 23)
        fill = function(win, c)
            local a = B.action
            X.Image(win, win.action, c.mode == 1 and a.send or a.withdraw, unpack(a.rect))
        end,
    })

    -- ----- the power dialog -----

    -- s6-interface-5x-b (round 7): the shared layout with 7.5.2's 63 x 24 buttons at y 307 (interfaces/power.lua)
    L.Power = require("interfaces.power").Entry(X, S, D.Power)

    -- ----- the rankings and their rewards -----

    local GLYPHS = { [0] = 0xC2A6, [1] = 0xC2A9 } -- a category's state's glyph (state 2: none; others: 0xC2A9)

    local R = D.Rankings
    local BOX, TABLE = R.box, R.table

    --- A category row's box (made once): the row itself (category below), on SUBWIN's frame, its chosen frame three
    --- pixels deep round it in 0x80; its glyph and title are drawn on it (over its tiles).
    local function categoryBox(row)
        if row.x7box then return row.x7box end
        local box = CreateFrame("Frame", nil, row)
        box:SetAllPoints(row)
        X.Frame(box, BOX.width, BOX.height, BOX.file, BOX.palette, BOX.tile)
        row.x7chosen = {}
        for k = 1, BOX.depth do
            for _, side in ipairs({ "top", "left", "bottom", "right" }) do
                local t = X.Solid(box, "OVERLAY", S.TEXT)
                X.Line(box, t, side, k, true)
                row.x7chosen[#row.x7chosen + 1] = t
            end
        end
        row.x7box = box
        return box
    end

    --- A text of the table at (x, line) of it, outlined.
    local function tabled(win, key, x, line, text, parent)
        outlined(win, key, TABLE.x + x, TABLE.y + line, text, parent)
    end

    L.Rankings = entry(R, {
        -- at (102, 74), where RankingDialog's AddToLayer puts it (no placement slot), unclamped
        centre = at(R),
        place = function(win)
            X.WebFrame(win, R.width, R.height, { R.edges })
            X.Image(win, win.controls[0], unpack(R.close))
            X.Image(win, win.controls[3], unpack(R.previous))
            X.Image(win, win.controls[4], unpack(R.next))
            local i, rw, flat = R.info, R.reward, R.flat
            X.TextButton(win, win.controls[5], i[1], i[2], i[3], i[4], flat[1], flat[2], flat[3])
            X.TextButton(win, win.controls[6], rw[1], rw[2], rw[3], rw[4], flat[1], flat[2], flat[3])
            X.List(win, win.categories, unpack(R.categories))
            win.categories.rowPainter = function(row, selected)
                row.sel:SetAlpha(0)
                row.text:Hide()
                categoryBox(row)
                for _, t in ipairs(row.x7chosen) do t:SetShown(selected) end
            end
            -- the table's own parts: its headers and its separator
            local cols, names = TABLE.columns, TABLE.names
            tabled(win, "x7rank", cols[1], TABLE.heads, names[1])
            tabled(win, "x7nameHead", cols[2], TABLE.heads, names[2])
            tabled(win, "x7score", cols[3], TABLE.heads, names[3])
            local rule = TABLE.rule
            for k = 0, rule.lines - 1 do
                local t = win["x7line" .. k] or X.Solid(win, "ARTWORK", 0x8F)
                win["x7line" .. k] = t
                X.Rect(t, win, TABLE.x + rule.left, TABLE.y + rule.top + k, TABLE.x + rule.right, TABLE.y + rule.top + 1 + k)
            end
            for _, key in ipairs({ "head", "total", "dates", "own" }) do win[key]:Hide() end
            -- the ten rows on the table's lines 100 + 30 i: each row 30 high, its line 21 down (from the table's 79)
            local rows = TABLE.rows
            X.List(win, win.rows, TABLE.x + rows[1], TABLE.y + rows[2], TABLE.x + rows[3], TABLE.y + rows[4], rows[5], rows[6])
            win.rows.rowPainter = function(row) row.sel:SetAlpha(0) row.text:Hide() end
        end,
        -- a category's row: its 222 x 43 box at (8, 4) of the 47-pixel row the list placed, its glyph and its outlined
        -- title (the renderer's row.text, hidden).
        -- Input routing (wire): RankingEventListPane::HitTestRow (0x0045BD10) takes a press on a row's box only, so the
        -- row is its box: a press in the 4 pixels above a box or beside it is no row's and asks for no category's rows
        -- (7D 02), as a press below the rows of the kit's own list (in a slide, K.PressAt gives it as the list's miss).
        -- Changing the row's rectangle (shops.xml's box) changes what such a press sends.
        category = function(win, row, cat)
            local _, rel, _, _, y = row:GetPoint(1)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", rel, "TOPLEFT", BOX.x, y - BOX.y)
            row:SetSize(BOX.width, BOX.height)
            local box = categoryBox(row)
            local glyph = cat[3] ~= 2 and (GLYPHS[cat[3]] or GLYPHS[1]) or nil
            local half = BOX.glyph // 2
            picture(box, "x7glyph", glyph, BOX.glyphAt[1] + half, BOX.glyphAt[2] + half)
            if box.x7glyph and glyph then
                local w, h = box.x7glyph:GetSize()
                if w > BOX.glyph or h > BOX.glyph then box.x7glyph:SetSize(math.floor(w / 2), math.floor(h / 2)) end
            end
            outlined(row, "x7title", BOX.title[1], BOX.title[2], K.Text(cat[2]), box)
        end,
        -- a row of the table ({ rank, name, score }): its three columns, outlined
        row = function(win, row, r)
            local cols, line = TABLE.columns, TABLE.rowLine
            outlined(row, "x7c1", cols[1], line, string.format("%d", r[1] or 0), row)
            outlined(row, "x7c2", cols[2], line, K.Text(r[2]), row)
            outlined(row, "x7c3", cols[3], line, string.format("%d", r[3] or 0), row)
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
            local T = TABLE
            tabled(win, "x7title", T.title[1], T.title[2], sel and K.Text(sel[2]) or "")
            tabled(win, "x7total", T.total[1], T.total[2], sel and string.format("Total : %d", c.total or 0) or "")
            tabled(win, "x7from", T.from[1], T.from[2], sel and ("From : " .. date(sel[4], sel[5])) or "")
            tabled(win, "x7to", T.to[1], T.to[2], sel and ("To : " .. date(sel[6], sel[7])) or "")
            local own = c.own
            local shown = sel and type(own) == "table" and own[1] and own[1] > 0
            local cols = T.columns
            tabled(win, "x7own1", cols[1], T.own, shown and string.format("%d", own[1]) or "")
            tabled(win, "x7own2", cols[2], T.own, shown and K.Text(c.ownName) or "")
            tabled(win, "x7own3", cols[3], T.own, shown and string.format("%d", own[2] or 0) or "")
        end,
    })

    local RW = D.Rewards
    L.Rewards = entry(RW, {
        -- at (202, 104), where RankingRewardInfoDialog's AddToLayer puts it (no placement slot), unclamped
        centre = at(RW),
        place = function(win)
            X.WebFrame(win, RW.width, RW.height)
            X.Image(win, win.ok, unpack(RW.ok))
            win.text:Hide()
            local h, names = RW.heads, RW.headNames
            outlined(win, "x7rank", h.rank, h.line, names[1])
            outlined(win, "x7legend", h.legend, h.line, names[2])
            outlined(win, "x7items", h.items, h.line, names[3])
        end,
        -- after the renderer's update: the category's title and each tier's rank, legend and items on its line
        fill = function(win, c)
            local title = ""
            local rankings = TK.Dialogs.Find("RankingDialog")
            for _, cat in ipairs(rankings and rankings.view and rankings.view.contents.categories or {}) do
                if cat[1] == c.category then title = K.Text(cat[2]) end
            end
            outlined(win, "x7title", RW.title[1], RW.title[2], title)
            -- a pooled window opened again with fewer tiers: the earlier tiers' texts go first (Astra's re-review of round
            -- 13); the tiers drawn now show theirs again
            for key, set in pairs(win) do
                if type(key) == "string" and key:find("^x7tier") then
                    for _, part in ipairs(set) do part.fs:Hide() end
                end
            end
            local h, t = RW.heads, RW.tiers
            for i, tier in ipairs(c.tiers or {}) do
                local line = t.line + t.step * (i - 1)
                local rank = tier[1] == tier[2] and K.Text(tier[1]) or (K.Text(tier[1]) .. " ~ " .. K.Text(tier[2]))
                outlined(win, "x7tierRank" .. i, h.rank, line, rank)
                outlined(win, "x7tierLegend" .. i, h.legend + t.legend, line, K.Text(tier[3]))
                local items = {}
                for _, it in ipairs(tier[5] or {}) do items[#items + 1] = string.format("%s(%d)", K.Text(it[1]), it[2] or 0) end
                outlined(win, "x7tierItems" .. i, h.items + t.items, line, table.concat(items, "   "))
            end
        end,
    })
end
