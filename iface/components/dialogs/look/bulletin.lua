-- s6-modular-g (interfaces): the default look of the boards and mail (components/dialogs/bulletin.lua).

return function(L, P, W) -- W: the skin the look is drawn with (init.lua's Build)

    --- The boards' button rows: from the bottom right, 14 in, 6 apart.
    local function row(win) P.Row(win, win.row, 14, 14, 6) end

    --- A caption (a static label) at the window's top left, x across and y down.
    local function caption(win, text, x, y)
        local label = W.Label(win, text, 13, W.gold, "LEFT")
        P.At(label, win, x, y)
        return label
    end

    -- D-36: the board list.
    L.Boards = {
        width = 340, height = 340, button = 80, listWidth = 300, listHeight = 230,
        place = function(win)
            P.At(win.list.sf, win, 20, -40)
            row(win)
        end,
    }

    -- D-37, D-41: an article list or the mail list; the article list's extra button at the bottom left.
    L.BoardList = {
        width = 560, height = 400, button = 70, listWidth = 520, listHeight = 290,
        place = function(win)
            P.At(win.list.sf, win, 20, -40)
            row(win)
            if win.extra then win.extra:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 14, 14) end
        end,
    }

    -- D-38: an article: its heading line, the body under it.
    L.Reader = {
        width = 560, height = 420, button = 70, bodyWidth = 520, bodyHeight = 280,
        place = function(win)
            P.At(win.head, win, 20, -38)
            P.At(win.body, win, 20, -62)
            row(win)
        end,
    }

    -- D-42: a letter, as an article with narrower buttons (seven of them).
    L.Letter = {
        width = 560, height = 420, button = 66, bodyWidth = 520, bodyHeight = 280,
        place = L.Reader.place,
    }

    -- D-39: the editor: the subject with its caption, the body under it.
    L.Editor = {
        width = 560, height = 420, button = 70, subjectWidth = 440, editHeight = 24, bodyWidth = 520, bodyHeight = 270,
        place = function(win)
            local s = caption(win, "Subject", 20, -44)
            win.subject:SetPoint("LEFT", s, "LEFT", 70, 0)
            P.At(win.body, win, 20, -76)
            row(win)
        end,
    }

    -- D-40: the predefined form: the subject, then either one free text or each entry's caption and edit in a column
    -- (a free-text entry its lines tall); the window as tall as the entries.
    L.Form = {
        width = 560, height = 460, button = 70, subjectWidth = 440, editHeight = 24, freeWidth = 520, freeHeight = 300,
        entryWidth = 380, firstEntry = -76,
        place = function(win)
            local s = caption(win, "Subject", 20, -44)
            win.subject:SetPoint("LEFT", s, "LEFT", 70, 0)
            P.At(win.free, win, 20, -76)
            row(win)
        end,
        -- An entry's edit: its lines tall for free text (multi), else one line.
        entrySize = function(entry, multi, lines) entry.edit:SetHeight(multi and 18 * lines + 8 or 24) end,
        -- An entry at y (from the window's top): its caption, its edit beside it.
        entryAt = function(win, entry, y)
            entry.label:ClearAllPoints()
            P.At(entry.label, win, 20, y - 4)
            entry.edit:ClearAllPoints()
            P.At(entry.edit, win, 150, y)
        end,
        -- The next entry's y, under this one.
        nextEntry = function(entry, y) return y - entry.edit:GetHeight() - 6 end,
        fit = function(win, free, y) win:SetHeight(free and 460 or math.max(200, -y + 60)) end,
    }

    -- D-43: a new letter: the recipient (or the reply's fixed name in its place), the subject, the body, Keep a copy at
    -- the bottom left.
    L.NewMail = {
        width = 560, height = 440, button = 70, recipientWidth = 200, subjectWidth = 440, editHeight = 24,
        bodyWidth = 520, bodyHeight = 250,
        place = function(win)
            local r = caption(win, "To", 20, -44)
            win.recipient:SetPoint("LEFT", r, "LEFT", 70, 0)
            win.fixed:SetPoint("LEFT", r, "LEFT", 70, 0)
            local s = W.Label(win, "Subject", 13, W.gold, "LEFT")
            s:SetPoint("TOPLEFT", r, "BOTTOMLEFT", 0, -16)
            win.subject:SetPoint("LEFT", s, "LEFT", 70, 0)
            P.At(win.body, win, 20, -108)
            win.keep:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 16, 16)
            row(win)
        end,
    }
end
