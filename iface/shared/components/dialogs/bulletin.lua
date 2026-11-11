-- s6-rules-dialogs: the boards and mail (behaviour.md D-35 to D-51): the board list, an article list, an article,
-- the editors (free and predefined forms), the mail list, a letter and a new letter. Only the session's top dialog
-- shows (the model hides the others). Their 3B requests, the dimmer and the replies are the model's.
--
-- s6-modular-g (interfaces): the windows' sizes and where their parts sit are the look's (C.look.Boards,
-- BoardList, Reader, Editor, Form, NewMail); this file keeps what each dialog does. A look may draw the lists' rows
-- (BoardList.row) and the article's and letter's texts (Reader.fill, Letter.fill) its own way.
--
-- Wire: each dialog's buttons, lists and edits carry the indexes 4a's OnControlCommand takes (BoardListDialog
-- 0x00472870, ArticleListDialog 0x00473E00, ArticleDialog 0x00476410, NewArticleDialog 0x004771B0,
-- NewPredefinedFormArticleDialog 0x00478240, MailListDialog 0x0047A060, MailDialog 0x0047C500 and its keys 0x0047C730,
-- NewMailDialog 0x0047D820), and Values() the fields the model's 3B requests are built from; changing an index or a
-- value changes what the server sees.

local C = TK.GetComponent("dialogs")
local K = C.kit
local W = TK.UI

local function date(month, day) return string.format("%d/%d", month or 0, day or 0) end


--- A read-only text in a scroll area (an article's or a letter's body): control index 11, width x height (the look's).
local function bodyView(win, width, height)
    local sf = W.ScrollArea(win)
    sf:SetSize(width, height)
    local bg = sf:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(sf)
    bg:SetColorTexture(0, 0, 0, 0.35)
    local text = K.Block(sf.content, 13)
    text:SetPoint("TOPLEFT", sf.content, "TOPLEFT", 6, -6)
    text:SetWidth(width - 16)
    win.controls[11] = sf
    K.Wire(win, sf, 11)
    sf.bg, sf.text = bg, text -- s6-modular-g (interfaces, round 12): a look may restyle the body (7.x's: 4a's text pane)
    function sf:SetBody(s)
        text:SetText(K.Text(s))
        self.content:SetSize(width, text:GetStringHeight() + 12)
        self.Refresh()
        self:SetVerticalScroll(0)
    end
    return sf
end

-- D-36: the boards (3), Open (1), Close (2). Field 0: the board's id.
local Boards = { look = "Boards" }

function Boards.build()
    local L = C.look.Boards
    local win = K.Window(L.width, L.height, "Boards")
    win.list = K.List(win, 3, L.listWidth, L.listHeight)
    win.row = K.Buttons(win, { { 2, "Close" }, { 1, "Open" } }, L.button)
    function win:Values()
        local i = self.list:First()
        return { i and tostring(self.list.items[i][1]) or "" }
    end
    L.place(win)
    return win
end

function Boards.update(win, view)
    local c = view.contents
    win.title:SetText(K.Text(c.title))
    if win.opened then
        win.list:SetItems(c.boards or {}, function(row, b) row.text:SetText(K.Text(b[2])) end)
    end
end

function Boards.key(win, key)
    if win.view and win.view.focus == 3 then return win.list:Key(key) end
end

C.renderers.BoardListDialog = Boards

--- The article and mail lists' values: the anchor row's id (m_selectedIndex, which Read acts on), every selected id,
--- "1" at the list's end.
local function listValues(list)
    local first = list:Current()
    local ids = {}
    for _, i in ipairs(list:All()) do ids[#ids + 1] = tostring(list.items[i][2]) end
    return { first and tostring(list.items[first][2]) or "", table.concat(ids, ","), list:AtEnd() and "1" or "" }
end

local function keepSelection(list, rows)
    -- The rows merge by id; the selection follows the ids it had.
    local keep = {}
    for _, i in ipairs(list:All()) do keep[list.items[i][2]] = true end
    return keep
end

local function setRows(list, rows, render)
    local keep = keepSelection(list, rows)
    list:SetItems(rows, render)
    for i, r in ipairs(rows) do if keep[r[2]] then list.selected[i] = true end end
    list:Select(nil, true)
end

-- D-37: Read (1), Write (2), Back (3), Delete (4), Close (5), the list (7), the extra button (8).
local Articles = { look = "BoardList" }

function Articles.build()
    local L = C.look.BoardList
    local win = K.Window(L.width, L.height, "")
    win.list = K.List(win, 7, L.listWidth, L.listHeight, true)
    -- s6-interface-5x (round 8). Wire: the list pages (3B 02 at its end: ArticleListPane::HandlePointerOrMouseEvent
    -- 0x00474EC0), so it gives the kit 7.5.2's own view of it, whatever a look draws: ArticleListDialog's list rectangle
    -- (0x00472CA0: 25, 85 to 430, 357, 272 pixels) of ArticleListPane's 14-pixel rows (0x004748F0). Its position, end,
    -- held press and thumb are 4a's on it (the kit's list.logical); changing these numbers changes when the server gets
    -- 3B 02.
    win.list.logical = { height = 272, row = 14 }
    win.row = K.Buttons(win, { { 5, "Close" }, { 4, "Delete" }, { 3, "Back" }, { 2, "Write" }, { 1, "Read" } }, L.button)
    win.extra = K.Button(win, 8, "Mark", L.button)
    function win:Values() return listValues(self.list) end
    L.place(win)
    return win
end

function Articles.update(win, view)
    local c = view.contents
    win.title:SetText(K.Text(c.title))
    local hasExtra = false
    for _, ctl in ipairs(view.controls) do if ctl.index == 8 then hasExtra = true end end
    win.extra:SetShown(hasExtra)
    setRows(win.list, c.rows or {}, function(row, r)
        row.text:SetText(string.format("%-6s %s   %s  %s", tostring(r[2]), K.Text(r[3]), date(r[4], r[5]), K.Text(r[6])))
        -- s6-modular-g (interfaces, round 12): a look's own rows (7.x's: 4a's columns); drawing only
        if C.look.BoardList.row then C.look.BoardList.row(win, row, r) end
    end)
end

function Articles.key(win, key)
    if win.view and win.view.focus == 7 then return win.list:Key(key) end
end

C.renderers.ArticleListDialog = Articles

-- D-38: next (1), Write (2), Back (3), Delete (4), previous (5), Close (6), the body (11).
local Article = { look = "Reader" }

function Article.build()
    local L = C.look.Reader
    local win = K.Window(L.width, L.height, "")
    win.head = W.Label(win, "", 13, W.gold, "LEFT")
    win.body = bodyView(win, L.bodyWidth, L.bodyHeight)
    win.row = K.Buttons(win, { { 6, "Close" }, { 4, "Delete" }, { 3, "Back" }, { 2, "Write" }, { 1, "Next" }, { 5, "Previous" } }, L.button)
    L.place(win)
    return win
end

function Article.update(win, view)
    local c = view.contents
    win.title:SetText(K.Text(c.heading))
    win.head:SetText(string.format("%s   by %s   %s", K.Text(c.subject), K.Text(c.author), date(c.month, c.day)))
    if win.opened or win.shownId ~= c.id then
        win.shownId = c.id
        win.body:SetBody(c.body)
    end
    -- s6-modular-g (interfaces, round 12): a look's own texts (7.x's: the author, the date and the subject apart)
    if C.look.Reader.fill then C.look.Reader.fill(win, c) end
end

C.renderers.ArticleDialog = Article

-- D-39: Post (1), Cancel (2), the subject (4), the body (5). Fields: subject, body.
local Editor = { look = "Editor" }

function Editor.build()
    local L = C.look.Editor
    local win = K.Window(L.width, L.height, "")
    win.subject = K.Edit(win, 4, L.subjectWidth, L.editHeight)
    win.subject:SetMaxLetters(255)
    win.body = K.Edit(win, 5, L.bodyWidth, L.bodyHeight, true)
    win.body:SetMaxLetters(4095)
    win.row = K.Buttons(win, { { 2, "Cancel" }, { 1, "Post" } }, L.button)
    function win:Values() return { self.subject:GetText(), self.body:GetText() } end
    L.place(win)
    return win
end

function Editor.update(win, view)
    win.title:SetText(K.Text(view.contents.heading))
    if win.opened then
        K.SetEdit(win.subject, "")
        K.SetEdit(win.body, "")
        win.subject:SetFocus()
    end
end

C.renderers.NewArticleDialog = Editor

-- D-40: Post (0), Cancel (1), the subject (3), per entry its value (5, 7, ...) or one free text (4).
local Form = { look = "Form" }

function Form.build()
    local L = C.look.Form
    local win = K.Window(L.width, L.height, "")
    win.subject = K.Edit(win, 3, L.subjectWidth, L.editHeight)
    win.free = K.Edit(win, 4, L.freeWidth, L.freeHeight, true)
    win.entries = {}
    win.row = K.Buttons(win, { { 1, "Cancel" }, { 0, "Post" } }, L.button)
    function win:Values()
        local out = { self.subject:GetText() }
        if self.isFree then
            out[2] = self.free:GetText()
        else
            for i = 1, self.count or 0 do out[#out + 1] = self.entries[i].edit:GetText() end
        end
        return out
    end
    L.place(win)
    return win
end

function Form.update(win, view)
    local L = C.look.Form
    local c = view.contents
    win.title:SetText(K.Text(c.heading))
    if not win.opened then return end
    K.SetEdit(win.subject, "")
    win.isFree = c.free == true
    win.free:SetShown(win.isFree)
    K.SetEdit(win.free, "")
    local entries = c.entries or {}
    win.count = win.isFree and 0 or #entries
    local y = L.firstEntry
    for i, e in ipairs(entries) do
        local row = win.entries[i]
        if not row then
            row = { label = W.Label(win, "", 13, W.gold, "LEFT") }
            -- Entry i's value is control 5, 7, 9, ... (the model's: review r4, 7).
            row.edit = K.Edit(win, 2 * (i - 1) + 5, L.entryWidth, L.editHeight)
            win.entries[i] = row
        end
        local multi = not e[2]
        row.edit:SetMultiLine(multi)
        -- s6-modular-g (interfaces, round 13): the entry itself too, for a look that lays it out by its row advance (7.x's)
        L.entrySize(row, multi, math.max(1, e[3] or 1), e)
        row.label:SetText(K.Text(e[1]))
        L.entryAt(win, row, y)
        local default = K.Text(e[4])
        K.SetEdit(row.edit, default == "empty" and "" or default)
        local shown = not win.isFree
        row.label:SetShown(shown)
        row.edit:SetShown(shown)
        y = L.nextEntry(row, y)
    end
    for i = #entries + 1, #win.entries do
        win.entries[i].label:Hide()
        win.entries[i].edit:Hide()
    end
    L.fit(win, win.isFree, y)
    win.subject:SetFocus()
end

C.renderers.NewPredefinedFormArticleDialog = Form

-- D-41: Read (1), Write (2), Reply (3), Delete (4), Back (5), Close (6), the list (7).
local Mails = { look = "BoardList" }

function Mails.build()
    local L = C.look.BoardList
    local win = K.Window(L.width, L.height, "")
    win.list = K.List(win, 7, L.listWidth, L.listHeight, true)
    -- s6-interface-5x (round 8). Wire: the list pages (3B 02 at its end: MailListPane::HandlePointerOrMouseEvent
    -- 0x0047AD80), so it gives the kit 7.5.2's own view of it, whatever a look draws: MailListDialog's list rectangle
    -- (0x00479110: 25, 56 to 430, 336, 280 pixels, twenty rows exactly) of MailListPane's 14-pixel rows (0x0047A8A0). Its
    -- position, end, held press and thumb are 4a's on it (the kit's list.logical); changing these numbers changes when
    -- the server gets 3B 02.
    win.list.logical = { height = 280, row = 14 }
    win.row = K.Buttons(win, { { 6, "Close" }, { 5, "Back" }, { 4, "Delete" }, { 3, "Reply" }, { 2, "Write" }, { 1, "Read" } }, L.button)
    function win:Values() return listValues(self.list) end
    L.place(win)
    return win
end

function Mails.update(win, view)
    local c = view.contents
    win.title:SetText(K.Text(c.title))
    setRows(win.list, c.rows or {}, function(row, r)
        local mark = r[1] ~= 0 and "* " or "  "
        row.text:SetText(string.format("%s%-14s %s  %s", mark, K.Text(r[3]), date(r[4], r[5]), K.Text(r[6])))
        -- s6-modular-g (interfaces, round 12): a look's own rows (7.x's: 4a's columns); drawing only
        if C.look.BoardList.row then C.look.BoardList.row(win, row, r) end
    end)
end

Mails.key = Articles.key
C.renderers.MailListDialog = Mails

-- D-42: Write (1), Reply (2), Delete (3), Back (4), next (5), Close (6), previous (7), the body (11).
local Mail = { look = "Letter" }

function Mail.build()
    local L = C.look.Letter
    local win = K.Window(L.width, L.height, "Mail")
    win.head = W.Label(win, "", 13, W.gold, "LEFT")
    win.body = bodyView(win, L.bodyWidth, L.bodyHeight)
    win.row = K.Buttons(win, { { 6, "Close" }, { 4, "Back" }, { 3, "Delete" }, { 2, "Reply" }, { 1, "Write" }, { 5, "Next" }, { 7, "Previous" } }, L.button)
    L.place(win)
    return win
end

function Mail.update(win, view)
    local c = view.contents
    win.head:SetText(string.format("%s   from %s   %s", K.Text(c.subject), K.Text(c.sender), date(c.month, c.day)))
    if win.opened or win.shownId ~= c.id then
        win.shownId = c.id
        win.body:SetBody(c.body)
    end
    -- s6-modular-g (interfaces, round 12): a look's own texts (7.x's: the sender, the date and the subject apart)
    if C.look.Letter.fill then C.look.Letter.fill(win, c) end
end

C.renderers.MailDialog = Mail

-- D-43: Send (1), Cancel (2), the recipient (3), the subject (4), the body (5), keep a copy (6).
-- Fields: recipient, subject, body, keep.
local NewMail = { look = "NewMail" }

function NewMail.build()
    local L = C.look.NewMail
    local win = K.Window(L.width, L.height, "New Mail")
    win.recipient = K.Edit(win, 3, L.recipientWidth, L.editHeight)
    win.fixed = W.Label(win, "", 13, W.white, "LEFT")
    win.subject = K.Edit(win, 4, L.subjectWidth, L.editHeight)
    win.body = K.Edit(win, 5, L.bodyWidth, L.bodyHeight, true)
    win.keep = K.Check(win, 6, "Keep a copy")
    win.row = K.Buttons(win, { { 2, "Cancel" }, { 1, "Send" } }, L.button)
    function win:Values()
        return { self.recipient:GetText(), self.subject:GetText(), self.body:GetText(), self.keep:GetChecked() and "1" or "" }
    end
    L.place(win)
    return win
end

function NewMail.update(win, view)
    local c = view.contents
    if not win.opened then return end
    local reply = c.recipient ~= nil
    win.recipient:SetShown(not reply)
    win.fixed:SetShown(reply)
    win.fixed:SetText(K.Text(c.recipient))
    K.SetEdit(win.recipient, "")
    K.SetEdit(win.subject, "")
    -- A reply's body is the model's quote, laid out as 4a's edit lays it out; each CR or LF is one line break here.
    local body = (c.body or ""):gsub("\r", "\n")
    win.body:SetText(body)
    win.body.__before = body
    win.keep:SetValue(false)
    if reply then win.subject:SetFocus() else win.recipient:SetFocus() end
end

C.renderers.NewMailDialog = NewMail

-- The session itself draws nothing.
C.renderers.BulletinSession = { build = function() return K.Window(10, 10, "") end, update = function() end, hidden = true }
