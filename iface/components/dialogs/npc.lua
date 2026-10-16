-- s6-rules-dialogs: the NPC dialogs of server 0x30 (behaviour.md D-01 to D-08): the message pages, the question with
-- its answers, the text reply, the head choice and the Nexonclub registration. Their packets (the 3A replies, the
-- NPC filter) are the model's; these windows show the text and pass the buttons, the list and the edit on.
--
-- s6-modular-g (interfaces, phase 1): each window's size and where its parts sit are the dialogs' look (C.look: the
-- default is components/dialogs/look/npc.lua, today's Modern numbers); this file keeps what each dialog does: its parts
-- with their control indexes, what fills them from the model, and the values and keys that go back with the input.
--
-- Wire: the control indexes, Values() and the keys below are what reaches the dialog model, which sends the dialog's
-- packets (kit.lua: a press or release goes with its control's index and the window's values). They are 4a's, by the
-- class's OnControlCommand named at each; changing one changes what the server sees.

local C = TK.GetComponent("dialogs")
local K = C.kit
local W = TK.UI
local H = __tk

-- D-01, D-02: the text, Prev (1), Next (2), Close (3).
-- Wire: MessageDialog::OnControlCommand 0x0054DB40: 1 Previous, 2 Next, 3 Close (also Escape), each a 0x3A reply.
local Message = { look = "Message" }

function Message.build()
    local L = C.look.Message
    local win = K.Window(L.width, L.height, "")
    win.text = K.Block(win, 13)
    win.prev = K.Button(win, 1, "Prev", L.button)
    win.next = K.Button(win, 2, "Next", L.button)
    win.close = K.Button(win, 3, "Close", L.button)
    L.place(win)
    return win
end

function Message.update(win, view)
    local L = C.look.Message
    local c = view.contents
    local x, ph = K.ShowPicture(win, c.picture, c.status)
    L.text(win, x)
    win.text:SetText(K.Text(c.text))
    L.fit(win, ph)
end

C.renderers.MessageDialog = Message
C.renderers.MessageDialogLarger = Message

-- D-03, D-04: the prompt, the answers (5), OK (1), Prev (2), Next (3), Close (4). Field 0: the answer's number.
-- Wire: MenuQuestionDialog::OnControlCommand 0x0054F8E0: 1 OK (the chosen answer's number, field 0), 2 Previous,
-- 3 Next, 4 Close; the list's keys (Question.key) choose as 4a's ListPane does.
local Question = { look = "Question" }

function Question.build()
    local L = C.look.Question
    local win = K.Window(L.width, L.height, "")
    win.text = K.Block(win, 13)
    win.list = K.List(win, 5, L.listWidth, L.listHeight)
    win.ok = K.Button(win, 1, "OK", L.button)
    win.prev = K.Button(win, 2, "Prev", L.button)
    win.next = K.Button(win, 3, "Next", L.button)
    win.close = K.Button(win, 4, "Close", L.button)
    L.place(win)
    function win:Values()
        local i = self.list:First()
        return { i and tostring(i) or "" }
    end
    return win
end

function Question.update(win, view)
    local L = C.look.Question
    local c = view.contents
    local x, ph = K.ShowPicture(win, c.picture, c.status)
    L.text(win, x)
    win.text:SetText(K.Text(c.prompt))
    L.fit(win, ph)
    if win.opened then
        win.list:SetItems(c.rows or {}, function(row, text, i) row.text:SetText(i .. ". " .. K.Text(text)) end)
    end
end

function Question.key(win, key)
    if win.view and win.view.focus == 5 then return win.list:Key(key) end
end

C.renderers.MenuQuestionDialog = Question
C.renderers.MenuQuestionDialogLarger = Question

-- D-05: the message, the prompt, the edit (6), OK (1), Prev (2), Next (3), Close (4). Field 0: the edit's text.
-- Wire: TextDialog::OnControlCommand 0x00553180: 1 OK (the edit's text, field 0), 2 Previous, 3 Next, 4 Close; the
-- edit's masking and length are the packet's (masked, maxLength).
local TextReply = { look = "TextReply" }

function TextReply.build()
    local L = C.look.TextReply
    local win = K.Window(L.width, L.height, "")
    win.text = K.Block(win, 13)
    win.prompt = W.Label(win, "", 13, W.gold, "LEFT")
    win.edit = K.Edit(win, 6, L.editWidth, L.editHeight)
    win.caption = W.Label(win, "", 12, W.grey, "LEFT")
    win.ok = K.Button(win, 1, "OK", L.button)
    win.prev = K.Button(win, 2, "Prev", L.button)
    win.next = K.Button(win, 3, "Next", L.button)
    win.close = K.Button(win, 4, "Close", L.button)
    L.place(win)
    function win:Values() return { self.edit:GetText() } end
    return win
end

function TextReply.update(win, view)
    local L = C.look.TextReply
    local c = view.contents
    local x, ph = K.ShowPicture(win, c.picture, c.status)
    L.text(win, x)
    win.text:SetText(K.Text(c.text))
    win.prompt:SetText(K.Text(c.prompt))
    win.caption:SetText(K.Text(c.caption))
    L.fit(win, x, ph)
    if win.opened then
        win.edit:SetPassword(c.masked == true)
        win.edit:SetMaxLetters(c.maxLength and c.maxLength > 0 and c.maxLength or 0)
        K.SetEdit(win.edit, "")
        win.edit:SetFocus()
    end
end

C.renderers.TextDialog = TextReply

-- D-06: the text, OK (1), the head pages (2, 3), CLOSE (4), the preview (5), the heads (7-16). Nothing chosen is sent.
-- Round 21: HeadSelectDialog (0x00551520) on its 374 x 316 layer. The heads are s6-characters' pictures of the packet's
-- look (contents.status) with each head's number, on 4a's 5 x 2 grid of 41 x 54 buttons from (58, 113), 54 across and 64
-- down; a page past the head count has no button. The preview (37 x 55 on black at (36, 40)) shows the packet's own
-- look until a head is chosen, then that head (RebuildHeadPreview 0x00551030). Round 22 (review r21, 5): the page and
-- the chosen head are the model's (headPage, selected, chosen: a click, or Space or Enter on a focused head or page
-- button, as 4a's take them); the window posts the art's head count and first head (GetHeadSelection) as the dialog's
-- two fields, which set them up at the first input. Nothing about them is sent. Round 24: the chosen head's button has
-- the capsule behind it, centred on the button (ObjectImageButtonPane::OnPaint, TextMenuItemList.cpp:2357-2367:
-- CAPSULE.EPD frame 0 in NPAL3.PAL; 7.5.2's archives hold it as CAPSULE.EPF). Round 26: the chosen head's picture is
-- s6-characters' highlighted one, which draws head 0 from the capsule's corner as 4a does.
-- Wire: HeadSelectDialog::OnControlCommand 0x00551FA0 by these indexes, with the two fields as the model's set-up.
local Heads = { look = "Heads" }

function Heads.build()
    local L = C.look.Heads
    local win = K.Window(L.width, L.height, "")
    win.preview = CreateFrame("Frame", nil, win)
    local black = win.preview:CreateTexture(nil, "BACKGROUND")
    black:SetAllPoints(win.preview)
    black:SetColorTexture(0, 0, 0, 1)
    win.preview.tex = win.preview:CreateTexture(nil, "ARTWORK")
    win.preview.tex:SetAllPoints(win.preview)
    win.text = K.Block(win, 13)
    win.heads = {}
    for i = 0, 9 do
        local b = K.Button(win, 7 + i, "", L.head[1], L.head[2])
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints(b)
        win.heads[i] = b
    end
    win.left = K.Button(win, 2, "<", L.page)
    win.right = K.Button(win, 3, ">", L.page)
    win.close = K.Button(win, 4, "CLOSE", L.button)
    win.ok = K.Button(win, 1, "OK", L.button)
    L.place(win)
    function win:Values() return { tostring(self.count or 0), tostring(self.first or 0) } end
    return win
end

--- s6-interface-5x-b (round 6): a picture on a texture of a box: the look's (L.fit: 5.x's, the base set's at 5.33's size,
--- centred in 5.33's box), else the whole box.
local function picture(tex, box, key, w, h)
    tex:SetTexture(key or "")
    local fit = C.look.Heads.fit
    if fit then fit(tex, box, w or 0, h or 0) end
end

--- s6-interface-5x-b (round 6): the look's preview pane (L.preview: 5.x's, 4a's legacy branch's 35 x 48, with the scale its
--- base-set pictures are asked at: 5.x draws the base set at 5.33's size, so asks them that much larger), else 4a's 37 x 55.
local function previewOf(L) return L.preview or { 37, 55, 1 } end

--- s6-characters (round 46): a box of the look's (w x h) in the base set's pixels, at the look's scale.
local function asked(w, h, scale) return math.floor(w / scale + 0.5), math.floor(h / scale + 0.5) end

--- The page's heads, the chosen one's box, the preview and the page buttons' states.
function Heads.show(win)
    local L = C.look.Heads
    -- the head buttons' canvas, at the look's scale (5.x's 41 x 54 asked as 82 x 108; Modern's and 7.x's as 4a's)
    local bw, bh = asked(L.head[1], L.head[2], previewOf(L)[3])
    for i = 0, 9 do
        local b, head = win.heads[i], win.page * 10 + i
        b:SetShown(head < win.count)
        if head < win.count then
            picture(b.tex, b, H:GetHeadImage(win.status, head, true, head == win.selected, bw, bh))
            b.capsule:SetShown(head == win.selected)
        end
    end
    picture(win.preview.tex, win.preview, win.preview.key or "", win.preview.w, win.preview.h)
    win.controls[2].localEnabled = win.page >= 1
    win.controls[3].localEnabled = win.page < math.floor(win.count / 10)
    if win.view then K.ShowState(win, win.view) end
end

function Heads.update(win, view)
    local c = view.contents
    win.text:SetText(K.Text(c.text))
    if win.opened then
        win.status = c.status
        win.count, win.first = H:GetHeadSelection(win.status)
    end
    -- The model's once its first input told it the count; until then the constructor's: the first head's page.
    win.page = c.headPage or math.floor(win.first / 10)
    win.selected = c.selected or win.first
    -- the preview's canvas at the look's scale, the packet's look on opening and the chosen head's after a click (round 46:
    -- the head at the same canvas, so 5.x's preview shows the whole figure, not the 37 x 55 one cut at its foot)
    local pv = previewOf(C.look.Heads)
    local pw, ph = asked(pv[1], pv[2], pv[3])
    if c.chosen then
        win.preview.key, win.preview.w, win.preview.h = H:GetHeadImage(win.status, win.selected, false, false, pw, ph)
    else
        win.preview.key, win.preview.w, win.preview.h = H:GetObjectImage(win.status, pw, ph)
    end
    Heads.show(win)
end

C.renderers.HeadSelectDialog = Heads

-- D-07: the account (2), the password (3), OK (4), CANCEL (5), CREATE (6). Fields: account, password.
-- Wire: NexonclubRegistrationDialog::OnControlCommand 0x00530060: 4 OK, 5 Cancel, 6 register, with the two fields.
local Nexonclub = { look = "Nexonclub" }

function Nexonclub.build()
    local L = C.look.Nexonclub
    local win = K.Window(L.width, L.height, L.title)
    win.text = K.Block(win, 13)
    win.account = K.Edit(win, 2, L.editWidth, L.editHeight)
    win.password = K.Edit(win, 3, L.editWidth, L.editHeight)
    win.password:SetPassword(true)
    win.cancel = K.Button(win, 5, "CANCEL", L.button)
    win.ok = K.Button(win, 4, "OK", L.button)
    win.create = K.Button(win, 6, "CREATE", L.button)
    L.place(win)
    function win:Values() return { self.account:GetText(), self.password:GetText() } end
    return win
end

function Nexonclub.update(win, view)
    win.text:SetText(K.Text(view.contents.text))
    if win.opened then
        K.SetEdit(win.account, "")
        K.SetEdit(win.password, "")
    end
end

C.renderers.NexonclubRegistrationDialog = Nexonclub
