-- s6-optimize (round 52; R51.3, moved from interfaces/7x/dialogs/boards.lua and interfaces/5x/dialogs/boards.lua, which
-- had them the same): the original client's boards and mail windows (components/dialogs/bulletin.lua) as 7.x's and 5.x's
-- dialogs looks both draw them: which window slides open, the heading and the header texts, the read-only body, the
-- lists' rows and their colours, the predefined form's entries by 4a's cursor and the new letter's "keep a copy" box.
-- Each look keeps its own pictures, buttons and rectangles (7.5.2's numbers or 5.33's) and calls these with them:
-- require("interfaces.original.boards")(X), X the look's helpers (interfaces/original/dialogkit.lua, with its skin).
-- Drawing only: the indexes, the keys, the 3B requests and the replies are the renderer's and the model's.

return function(X)
    local S = X.skin
    local B = {}

    -- the bulletin classes (one session's windows)
    local BULLETIN = { BoardListDialog = true, ArticleListDialog = true, ArticleDialog = true, NewArticleDialog = true,
        NewPredefinedFormArticleDialog = true, MailListDialog = true, MailDialog = true, NewMailDialog = true }

    --- Whether the dialog opening is its session's first (DialogSession::PushDialog slides only that one open): no other
    --- board or mail dialog is open (the ones below a pushed one stay open, hidden).
    function B.First(win, view)
        for _, other in ipairs(TK.Dialogs.Views()) do
            if BULLETIN[other.name] and other.serial ~= view.serial then return false end
        end
        return true
    end

    --- The window's title as its heading text (DialogPane draws no title; these windows show it as a static text), one
    --- line in 0x25.
    function B.Heading(win, l, t, r, b)
        X.Text(win.title, win, l, t, r, b, S.LIST)
        win.title:SetWordWrap(false)
        win.title:Show()
    end

    --- A read-only body (ScrollableControlPane over a TextEditPane: the text in 0x8F wrapped at wrap pixels, the bar at
    --- the rectangle's right edge, no background of its own: the picture's field shows).
    function B.Body(win, l, t, r, b, wrap)
        local sf = win.body
        X.Rect(sf, win, l, t, r - 13, b)
        if sf.bg then sf.bg:Hide() end
        if sf.text then
            S.Text(sf.text, 0x8F)
            sf.text:ClearAllPoints()
            sf.text:SetPoint("TOPLEFT", sf.content, "TOPLEFT", 0, -1)
            sf.text:SetWidth(wrap)
        end
        X.Bar(sf, 12)
    end

    --- The board list's and the article and mail lists' row colours: 0x8F, 0x80 on the selected row's bar; 0x0E for a row
    --- whose status (unread) byte is set (row.x7status), on the bar or not.
    function B.Colours(list)
        list.rowPainter = function(row, selected)
            local c = row.x7status and 0x0E or (selected and S.TEXT or 0x8F)
            for _, key in ipairs({ "text", "x7id", "x7who", "x7date", "x7subject" }) do
                if row[key] then row[key]:SetTextColor(S.Colour(c)) end
            end
        end
    end

    --- An article list's or the mail list's row (the model's { status, id, author or sender, month, day, subject }) at the
    --- look's columns (ArticleListPane's and MailListPane's DrawListEntry): "%5d" the id from 0, from who the author (the
    --- sender) fitted to 80 pixels with "...", from date "%2d/%2d" the date, from subject the subject fitted to width.
    function B.Row(row, r, who, date, subject, width)
        row.text:Hide()
        row.x7status = (r[1] or 0) ~= 0
        X.PaddedRowText(row, "x7id", 0, string.format("%5d", r[2] or 0))
        X.RowText(row, "x7who", who):SetText(X.Fit(TK.Dialogs.Text(r[3]), 80))
        X.PaddedRowText(row, "x7date", date, string.format("%2d/%2d", r[4] or 0, r[5] or 0))
        X.RowText(row, "x7subject", subject):SetText(X.Fit(TK.Dialogs.Text(r[6]), width))
    end

    --- The header texts of an article or a letter (an entry's fill): its writer (the content's field: "author" or
    --- "sender"), its date "%2d/%2d" and its subject, in the window's own texts the look placed (win.x7author, x7date,
    --- x7subject).
    function B.Fill(field)
        return function(win, c)
            win.x7author:SetText(TK.Dialogs.Text(c[field]))
            win.x7date:SetText(string.format("%2d/%2d", c.month or 0, c.day or 0))
            win.x7subject:SetText(TK.Dialogs.Text(c.subject))
        end
    end

    -- ----- the predefined form (NewPredefinedFormArticleDialog) -----

    --- An entry's kind (the renderer's: its lines, block or inline, and the entry with its row advance).
    function B.EntrySize(entry, multi, lines, e)
        entry.x7lines, entry.x7block = lines, multi
        entry.x7advance = e ~= nil and (e[5] == 1 or e[5] == true)
    end

    --- y counts the entries (the look's firstEntry, 0).
    function B.NextEntry(entry, y) return y + 1 end

    --- The form's entries laid out by the original's cursor (an entry's entryAt), the first at (36, top) with no row yet
    --- (win.x7cursor): a label as wide as its text in 0x25, then an inline value as wide as its label (4a's own
    --- rectangle), the next from 6 x lines + 5 further or, ending its row, 21 lower at 36; a block value 21 lower at
    --- (36, y)-(400, y + 16 lines), the next 21 x (16 lines / 21 + 1) lower. The cursor counts the rows they take
    --- (B.FormRows). The look draws the values: inline(win, edit, l, t, r, b) and block(win, edit, l, t, r, b).
    function B.EntryAt(top, inline, block)
        return function(win, entry, y)
            if y == 0 then win.x7cursor = { x = 36, y = top, rows = 0 } end
            local c = win.x7cursor
            local width = S.TextWidth(entry.label:GetText() or "") or 0
            X.Text(entry.label, win, c.x, c.y, c.x + width, c.y + 16, S.LIST)
            entry.label:SetWordWrap(false)
            c.x = c.x + width
            local lines = entry.x7lines or 1
            if not entry.x7block then
                inline(win, entry.edit, c.x, c.y, c.x + width, c.y + 16)
                if entry.x7advance then c.x, c.y = 36, c.y + 21 else c.x = c.x + 6 * lines + 5 end
            else
                c.y = c.y + 21
                block(win, entry.edit, 36, c.y, 400, c.y + 16 * lines)
                c.y = c.y + 21 * (math.floor(16 * lines / 21) + 1)
                c.x = 36
                c.rows = c.rows + math.floor(16 * lines / 21) + 1
            end
            if entry.x7advance then c.rows = c.rows + 1 end
        end
    end

    --- The form's visible rows (DeserializePredefinedFormArticleEntries' count, in a byte): the rows its entries took
    --- (B.EntryAt), none without entries, 5 for the free form (free).
    function B.FormRows(win, free, count)
        return free and 5 or ((count or 0) > 0 and win.x7cursor.rows or 0) % 256
    end

    --- The new letter's "keep a copy" (CheckBoxControlPane on ONOFFBUT.EPF in BUTTON.PAL, frame 0, frame 1 checked; the
    --- base set's) at box = { l, t, r, b }, its caption a control of its own at label = { l, t, r, b } in colour (0x80 by
    --- default).
    function B.KeepCopy(win, box, label, colour)
        local keep = win.keep
        X.Rect(keep, win, box[1], box[2], box[3], box[4])
        local off, on = TK.Art.Image("ONOFFBUT.EPF", 0, "BUTTON.PAL"), TK.Art.Image("ONOFFBUT.EPF", 1, "BUTTON.PAL")
        keep.box:ClearAllPoints()
        keep.box:SetAllPoints(keep)
        if off then keep.box:SetTexture(off) end
        keep.check:ClearAllPoints()
        keep.check:SetAllPoints(keep)
        if on then keep.check:SetTexture(on) end
        keep.hl:SetAlpha(0)
        keep.label:SetText("Keep a copy")
        X.Text(keep.label, win, label[1], label[2], label[3], label[4], colour)
    end

    return B
end
