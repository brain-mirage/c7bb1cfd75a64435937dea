-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md): 5.33's chat, its ChattingPane
-- (constructor 0x00412000) at (14, 390)-(434, 455) on the 640 x 480 screen and, under it, where every LineInputPane is
-- drawn, the line being typed at (14, 456)-(422, 468) (LineInputPane's constructor 0x00452890).
--
-- The log (ChattingPane::OnPaint 0x00412830): the pane filled white (0x8F), its messages from the oldest, each laid out
-- 408 pixels wide in 13-pixel lines (ColorStringChattingMessage::MeasureLines 0x00412DF0), newest at the bottom; a
-- message's lines on CHATBACK.EPF in NPAL7.PAL by its background colour (frame 0 for white, 1 for red, 2 for blue, none
-- for any other) and its text in its colour (ColorStringChattingMessage's Draw 0x00412E50). It starts with five empty
-- messages and keeps 100 (AddIncomingMessage 0x00412380). The colours are 5.33's (HandleServerSayPacket 0x00412A20,
-- HandleChatPacketType10 0x00412AE0): a say black on white, a speaker's shout red on white, a whisper and a group line
-- blue on white, the server's shout white on red, a system line white on blue, a clan line green on white. 7.5.2's
-- lines 5.33's chat pane has no colour for are black on white: the client's own lines, and the notices and the rules'
-- lines while 5.x's message board is off (they are the board's while it shows: panels/board); a line in the packet's
-- own colours (7.5.2's 0x0A kind 18 and 0x0D kind 4) keeps its text colour.
--
-- The line: the chat rules' or a prompt's (the keys that open, edit and send it are the rules', in every interface; this
-- only draws it), its prompt and text in black on white with the caret, while one is open: every prompt (s6-interface-5x-b
-- round 7, Y3), so Classic Commands' prompt display draws none (TK.Game.Prompts). s6-interface-5x (round 12, separation
-- step 3; W3): offline (the mock world) the game layer's line opens here, its prompt and a box after it
-- (TK.Game.Chat.ProvideLine); it opened in Modern's chat frame before, which 5.x's profile has off.
-- The log's scroll bar (s6-interface-5x-b): ScrollablePane's skin 1 at its right 12 pixels (SetSkinIndex(1) in the
-- constructor; interfaces/5x/scrollbar.lua), its arrows a line, its track 4 lines (the pane's page, sub_412570), its
-- thumb dragged; the wheel scrolls the log too, and so do the chat's scroll keys (Shift+Up and Shift+Down a line,
-- Shift+PgUp and Shift+PgDn a page: the pane's 4 lines, as 7.5.2's page is the lines shown less one) while it shows
-- (TK.Game.Chat.ProvideLog; s6-interface-5x round 12, Astra's s6-interface-5x-self-12-2).
-- It draws only; nothing here is sent, and only its bar takes a press.
-- s6-ui-core (round 85): the XML twin's scripts; the log, its clip, bar and line and their places are main.xml's
-- (core/xml.md).

local C = TK.GetComponent("5x.chat")
local H = __tk
local S = require("interfaces.5x.skin")
local Screen = require("interfaces.screen")
local E = require("interfaces.5x.elements")

local L = TK.Xml.Data("main.xml")
local LOG = L.LOG
local LOG_H, TEXT_W, LINE_H = LOG.height, LOG.text, LOG.line

-- The background colour's frame of CHATBACK.EPF (none for any other colour).
local BANDS = { [S.WHITE] = L.BANDS.WHITE, [S.RED] = L.BANDS.RED, [S.BLUE] = L.BANDS.BLUE }

--- A line's text and background colours as 5.33's chat pane gives them, by the client's channel (TK_CHAT_MESSAGE) and
--- speaker (only 0x0D's lines carry one); nil for a line it does not show.
function C.Colours(channel, speaker)
    if channel == "say" then return S.TEXT, S.WHITE end
    if channel == "shout" then
        if speaker and speaker ~= 0 then return S.RED, S.WHITE end
        return S.WHITE, S.RED
    end
    if channel == "whisper" or channel == "group" then return S.BLUE, S.WHITE end
    if channel == "system" then return S.WHITE, S.BLUE end
    if channel == "clan" then return S.GREEN, S.WHITE end
    if channel == "popup" or channel == "banner" then return nil end -- the chat frame's notice box and message pane
    return S.TEXT, S.WHITE
end

--- The log as 5.33's starts it: five empty messages, black on white.
function C:Clear()
    self.messages, self.offset = {}, 0
    for i = 1, LOG.start do self.messages[i] = { text = "", fg = S.TEXT, bg = S.WHITE } end
    self:Draw()
end

--- Adds a message (newest at the bottom; the oldest go past 100) and shows the newest lines, unless Shift is held, as
--- the original's chat pane keeps the view then: the lines being read stay where they are, the view moved back by the
--- new message's lines. show (the screenshot's notice) shows the newest even then.
function C:Add(text, fg, bg, rgb, show)
    local m = self.messages
    m[#m + 1] = { text = text, fg = fg, bg = bg, rgb = rgb }
    if #m > LOG.keep then table.remove(m, 1) end
    -- s6-interface-5x (round 13's hotfix, a marked edit): the game screen's lines given at a late start are drawn once
    -- after them (TK_CHAT_REPLAYED, OnEnable)
    if TK.Game.Chat.replaying then return end
    if IsShiftKeyDown() and not show then
        self.offset = self:Clamp(self.offset + self:Lines(m[#m]))
    else
        self.offset = 0
    end
    self:Draw()
end

--- A message's row: its bands and its text, made once and kept.
local function row(f, i)
    local r = f.rows[i]
    if r then return r end
    r = { bands = {}, text = S.Text(f.content:CreateFontString(nil, "ARTWORK"), S.TEXT) }
    r.text:SetSpacing(-1) -- 13-pixel lines, the message's line height here (12 for the font's own lines elsewhere)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(true)
    r.text:SetWidth(TEXT_W)
    f.rows[i] = r
    return r
end

--- How many 13-pixel lines a message takes at 408 pixels (at least one), measured once in the layout that draws it.
function C:Lines(m)
    if not m.n then
        local measure = self.frame.measure
        measure:SetText(m.text ~= "" and m.text or " ")
        m.n = math.max(1, math.floor((measure:GetStringHeight() or LINE_H) / LINE_H + 0.5))
    end
    return m.n
end

--- The lines the log can scroll back (its scroll range: the messages' lines less the five showing, sub_412470).
function C:Range()
    local total = 0
    for _, m in ipairs(self.messages or {}) do total = total + self:Lines(m) end
    return math.max(0, total - LOG_H / LINE_H)
end

--- A view offset kept between the newest lines (0) and the oldest five at the top of the log.
function C:Clamp(offset)
    return math.max(0, math.min(offset, self:Range()))
end

--- Lays out the newest messages from the bottom of the log, the view offset lines back, each over its lines' bands.
function C:Draw()
    local f = self.frame
    if not f then return end
    for _, r in ipairs(f.rows) do
        r.text:Hide()
        for _, b in ipairs(r.bands) do b:Hide() end
    end
    local y, used = LOG_H + self.offset * LINE_H, 0
    for i = #self.messages, 1, -1 do
        if y <= 0 then break end
        local m = self.messages[i]
        used = used + 1
        local r = row(f, used)
        r.text:SetText(m.text ~= "" and m.text or " ")
        local n = self:Lines(m)
        y = y - n * LINE_H
        if m.rgb then r.text:SetTextColor(m.rgb[1], m.rgb[2], m.rgb[3]) else r.text:SetTextColor(S.Colour(m.fg)) end
        r.text:ClearAllPoints()
        r.text:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -(y + 1))
        r.text:SetShown(y + n * LINE_H > 0 and y < LOG_H)
        local band = BANDS[m.bg]
        for k = 1, n do
            if band then
                r.bands[k] = S.Picture(f.content, r.bands[k], L.BANDS.file, band, L.BANDS.palette, 0, y + (k - 1) * LINE_H, "BORDER")
            end
        end
    end
    if f.bar then f.bar:Refresh() end
end

--- Scrolls the view n lines back (older), up to the oldest, or forward for a negative n, down to the newest.
function C:Scroll(n)
    self.offset = self:Clamp(self.offset + n)
    self:Draw()
end

--- The chat rules' line or a prompt's, drawn in the prompt area with its caret while one is open (the original's
--- LineInputPane: its prompt and text in 0x80 on 0x8F); the rules own it, its keys and what it sends. s6-interface-5x-b
--- (round 7, s6-interface-5x's Y3): every prompt, the one-key ones too ("Eat what?", the take-off, the cast, F9's, the
--- emote letter), as 5.33 draws all its LineInputPanes here (components/classic draws none of them while this shows).
function C:DrawLine()
    local f = self.frame
    if not H:IsLiveInput() then
        -- offline: the game layer's line, while it is open here (its prompt in lineText, the box after it)
        local o = TK.Game.Chat.offline
        f.line:SetShown(o ~= nil and o.line == self.offlineLine)
        f.lineVersion = nil
        return
    end
    local owner = H:GetLineOwner()
    local open = owner == "Chat" or owner == "Prompt"
    f.line:SetShown(open)
    if not open then
        f.lineVersion = nil
        return
    end
    local line = H:GetLine()
    if line.Version == f.lineVersion then return end
    f.lineVersion = line.Version
    f.lineText:SetText(line.Label .. TK.Util.WithCaret(line.Text, line.SelectionEnd))
end

-- the scripts main.xml names
local scripts = {}

function scripts.Wheel(_, delta) C:Scroll(delta > 0 and 1 or -1) end

-- s6-interface-5x-b: the log's bar; 5.33's position counts lines from the oldest, this view's offset from the newest
function scripts.BarRange() return C:Range(), C:Range() - (C.offset or 0), 4 end
function scripts.BarSet(_, pos) C:Scroll(C:Range() - pos - C.offset) end

--- The offline line's box: 5.33's font, black, no insets (the game layer drives it).
function scripts.Box(box)
    H:SetFontFace(box.__h, S.FACE)
    local r, g, b = S.Colour(S.TEXT)
    H:SetTextColor(box.__h, r, g, b, 1)
    H:SetTextInsets(box.__h, 0, 0, 0, 0)
end

function scripts.DrawLine() C:DrawLine() end

function C:OnEnable()
    local f = TK.Xml.Load("main.xml", { scripts = scripts, elements = E }).frame
    f.content, f.lineText, f.box = f.clip.content, f.line.lineText, f.line.box
    f.measure = f.content.measure
    f.rows = {}
    self.offlineLine = {
        shown = function() return f:IsVisible() end,
        box = f.box,
        prompt = function(text)
            if text ~= "" then f.line:Show() end -- shown before its box takes the keyboard (DrawLine keeps it)
            f.lineText:SetText(text)
            local x = (S.TextWidth(text) or f.lineText:GetStringWidth()) + 1
            f.box:ClearAllPoints()
            f.box:SetPoint("TOPLEFT", f.line, "TOPLEFT", x, 0)
            f.box:SetSize(TEXT_W - x, 12)
        end,
    }
    TK.Game.Chat.ProvideLine("5x.chat", self.offlineLine)
    TK.Game.Prompts.ProvideHost("5x.chat", function() return f:IsVisible() end, true) -- every prompt (Y3)
    TK.Game.Chat.ProvideLog("5x.chat", { shown = function() return f:IsVisible() end,
                                         scroll = function(n) C:Scroll(n) end, page = function(dir) C:Scroll(dir * 4) end })
    self:Own(f)
    self.frame = f
    self.entry = Screen.Register(f, "5x.chat", "5.x Chat", function() return self:DB().enabled == true end)
    self:Clear()

    -- 5.x's message board takes the notices and the rules' lines while it shows (5.33's chat pane has none of them)
    local function board()
        local b = TK.GetComponent("5x.board")
        -- s6-interface-5x (round 13, a marked edit; the separation's step 11): the board's code only while it is loaded
        return b and b:Loaded() and b:IsShowing()
    end
    TK.On("TK_CHAT_MESSAGE", function(_, channel, text, colour, _, speaker)
        if channel == "notice" and board() then return end
        local fg, bg = C.Colours(channel, speaker)
        if fg then C:Add(text, fg, bg, channel == "colored" and TK.Chat.Packed(colour) or nil) end
    end)
    -- the rules' own system lines (7.5.2's SystemMessagePane: 5.33's message board)
    TK.On("TK_RULES_MESSAGE", function(_, text) if not board() then C:Add(text, S.TEXT, S.WHITE) end end)
    -- the client's own lines (the screenshot's notice, the Classic Commands help, the options' notices), black on white
    TK.On("TK_CLIENT_MESSAGE", function(_, text, _, _, show) C:Add(text, S.TEXT, S.WHITE, nil, show) end)
    TK.On("TK_CHAT_REPLAYED", function()
        C.offset = 0
        C:Draw()
    end)
    -- a new game screen starts a new chat pane (InitializeMainUiGraph at the login's accepted 02, as the chat frame's)
    TK.On("TK_SESSION_STATE", function(_, state) if state == "Accepted" then C:Clear() end end)
    TK.On("PLAYER_ENTERING_WORLD", function() if not H:IsOnline() then C:Clear() end end)
end

--- At 5.33's place on the scaled 5.x screen unless moved, at the screen's scale times its own; in the game only.
function C:ApplySettings() Screen.PlacePanel(self, S.WIDTH, S.HEIGHT, L.PLACE[1], L.PLACE[2]) end

Screen.Follow(C, "ApplySettings")
