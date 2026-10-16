-- s6-interface-7x-b: 7.x's messages pane, the original's NewSystemMessagePane (ui/SystemMessagePane.cpp), the lower page of
-- the side at (832, 376)-(1021, 641) on the 7.x screen, in the base layer. From the divider's top H (the saved
-- Config::m_systemMessageHeight, settings.toml chat.system_message_height, 70 by default; OnActivate 0x00588800):
--   - the spell list (SpelledPane) at (3, 22)-(183, H + 7): the effects of 0x3A in their order, then, when there are any,
--     a line of 24 dashes and the aethers of 0x3F; each "name" and its seconds as string 222 "%s %3ds" (a negative value:
--     the name alone), counted down each second (OnFrameUpdate 0x0056C300), a line gone at 0; 12-pixel lines, 0x80;
--   - the divider (NewSystemMessageModifyHeightPane) at (3, H)-(166, H + 16): dragged with the left button between 70 and
--     175 (HandlePointerOrMouseEvent 0x005882F0), saved and the page laid out again on its release; its picture (SYSBAR.EPF
--     in INVENBUT.PAL) is the 7.x screen's Messages Divider piece, a Decoration panel of its own, which this moves
--     (7x.screen's ShowDivider);
--   - the system messages (SystemMessagePane) at (3, 244 - 12 n)-(183, 244), n = (229 - H) / 12 whole lines: one 12-pixel
--     row a message in 0x84 (ColorStringSystemMessage::Draw 0x00587B60), the newest at the bottom, at most 200 kept
--     (AppendMessage 0x00585580), each new one scrolled into view (ScrollToLatest 0x00585360); a text longer than 160
--     pixels made several messages at a tab or at 4a's break (AddWrappedText 0x00586B00). A new pane starts with n blank
--     rows, and OnActivate makes a new pane (n blank rows) and gives it the old one's messages: so the game screen's first
--     showing leaves 2 n blank rows, and each drop of the divider puts n more in front (the capture of the original 7.5.2:
--     its empty pane's bar can scroll).
-- Each list scrolls by whole lines with the wheel and its 4a scroll bar along it (the capture: the messages' bar runs
-- from the list's top); the spell list over the messages, as 4a adds them. Its place follows the scaled screen until the
-- player moves it (edit mode, its Layout tab). In a window under 1024 x 768 the rows are spaced by the drawn line, so
-- fewer show (Hud.Lines, round 7).
--
-- s6-ui-core (round 85): the XML twin's scripts; its frames and the page's places are main.xml's (core/xml.md).
--
-- What goes in: the session's 0x0A kinds 2 and 3 (TK_CHAT_MESSAGE "notice", already split at tabs) and the rules' own
-- system lines (TK_RULES_MESSAGE: the item notices, the arrows' warning...); the effects and aethers as the logic keeps
-- them (__tk:GetEffect, GetAether). Drawing only: none of these panes sends anything (Source-5: the four panes' handlers
-- send no packet), and the page declines every press (it is beside the map view, not over it).

local C = TK.GetComponent("7x.messages")
local H = __tk
local S = require("interfaces.7x.skin")
local Hud = require("interfaces.7x.hud")
local Screen = require("interfaces.screen")
local Wrap = require("interfaces.original.wrap")

local L = TK.Xml.Data("main.xml")
local LOW, HIGH = L.DIVIDER.low, L.DIVIDER.high -- the divider's range
local KEEP = L.MESSAGES.keep                    -- messages kept
local WRAP = L.MESSAGES.wrap                    -- a message's width
local ROW = L.ROW                               -- font 0's line

-- ----- the system messages -----

-- the messages, oldest first ("" a blank row)
C.messages = {}

--- AddWrappedText (0x00586B00): text cut into messages of at most 160 pixels: a tab ends one; otherwise a message ends
--- when the next character would pass 160 pixels, after the last character on it that is not a letter or digit (none:
--- before the character that passed), and a space or a mark that passes stays on its message. s6-interface-7x-b (round
--- 8, the separation's step 5): the original client's wrap (interfaces/original/wrap.lua: Wrap.Lines, 4a's
--- SystemMessagePane.cpp:556-646 line by line), which this file read on its own before; toward 4a, an empty text and
--- what follows a text's last tab make no message (this made an empty one). Drawing only.
function C.Wrap(text) return Wrap.Lines(text, WRAP, S.TextWidth) end

--- A text into the messages (each piece a row), the oldest dropped past 200, and the list scrolled to the newest.
function C:Add(text)
    for _, piece in ipairs(C.Wrap(text or "")) do
        local list = C.messages
        list[#list + 1] = piece
        if #list > KEEP then table.remove(list, 1) end
    end
    if self.list then
        self.list:SetCount(#C.messages)
        self.list:End()
    end
end

--- n blank rows in front of the messages (a new SystemMessagePane's, which OnActivate gives the old messages to), the
--- oldest dropped past 200, and the list at the newest.
function C:Pad(n)
    local list = {}
    for i = 1, n do list[i] = "" end
    for _, m in ipairs(C.messages) do list[#list + 1] = m end
    while #list > KEEP do table.remove(list, 1) end
    C.messages = list
    if self.list then
        self.list:SetCount(#C.messages)
        self.list:End()
    end
end

--- A new game screen's pane: the constructor's n blank rows and the first OnActivate's n, so the first message comes in at
--- the bottom.
function C:Reset()
    C.messages = {}
    self:Pad(2 * self:Rows())
end

-- ----- the spell list -----

--- The spell list's lines now: the effects, then a line of 24 dashes and the aethers when there are any (RebuildDisplayText
--- 0x0056BEA0), each "name" and its whole seconds left, rounded up, as string 222 "%s %3ds"; a negative value the name
--- alone; a time run out is no line.
function C.SpellLines(now)
    local lines = {}
    local function entry(name, left)
        if left == nil then
            lines[#lines + 1] = name
        elseif left > 0 then
            lines[#lines + 1] = string.format("%s %3ds", name, left)
        end
    end
    for i = 1, H:GetNumEffects() do
        local ok, name, expires = H:GetEffect(i)
        if ok and name then entry(name, expires >= 0 and math.ceil(expires - now) or nil) end
    end
    local aethers = {}
    for i = 1, H:GetNumAethers() do
        local ok, kind, slot, start, duration = H:GetAether(i)
        local name = ok and TK.ActionInfo({ kind = kind, slot = slot })
        if name and math.ceil(start + duration - now) > 0 then aethers[#aethers + 1] = { name, math.ceil(start + duration - now) } end
    end
    if #aethers > 0 then
        lines[#lines + 1] = string.rep("-", L.SPELLS.dashes)
        for _, a in ipairs(aethers) do entry(a[1], a[2]) end
    end
    return lines
end

-- ----- the page -----

--- The divider's top H, from the saved height (4a takes the saved value as it is; one outside 70..175 is kept to it).
function C:Top()
    local h = self.dragTop or tonumber(H:ClientSettingInt("chat", "system_message_height")) or LOW
    return math.max(LOW, math.min(HIGH, h))
end

--- The message rows for the divider's top: n = (229 - H) / 12 whole lines.
function C:Rows(top)
    return math.floor((L.MESSAGES.rowsFrom - (top or self:Top())) / ROW)
end

--- A row's font string on a list's text, row k (0-based) with its top at top (Hud.Lines' spacing; its pen at the row's
--- bottom), in colour index; made at its first use, placed again when the spacing changes.
local function rowString(rows, list, k, top, colour)
    local fs = rows[k]
    if not fs then
        fs = list.text:CreateFontString(nil, "OVERLAY")
        rows[k] = fs
    end
    if fs.top ~= top then
        fs.top = top
        S.PenText(fs, list.text, "", 0, top + ROW, colour)
    end
    return fs
end

-- the scripts main.xml names
local scripts = {}

function scripts.Own(f)
    C.frame = f
    C:Own(f)
end

-- the divider's drag: from a left press on it, its top follows the pointer's moves (the grab kept), 70 to 175; the
-- release saves it and lays the page out again
function scripts.DividerDown(_, button)
    if button ~= "LeftButton" then return end
    local _, y = Hud.HelpLine.PointIn(C.frame)
    C.grab = y - C:Top()
    C.dragTop = C:Top()
end

function scripts.DividerUp(_, button)
    if button ~= "LeftButton" or not C.dragTop then return end
    local top = C:Top()
    C.dragTop, C.grab = nil, nil
    H:ClientSettingSetInt("chat", "system_message_height", top)
    H:ClientSettingsSave()
    C:Pad(C:Rows(top)) -- OnActivate's new pane
    C:Arrange()
end

-- s6-modular-g r26: discard only the temporary visual drag when the host lets go without OnMouseUp.
-- WIRE: ItemHelpPane::HandlePointerOrMouseEvent 0x004CCC40 owns a swallowed release. Do not run the
-- NewSystemMessageModifyHeightPane release/commit (0x005882F0), pad/scroll the lists, or save here;
-- turning this cancellation into an underlying input changes what the server sees.
function scripts.DividerCancelled(_, button)
    if button ~= "LeftButton" or not C.dragTop then return end
    C.dragTop, C.grab = nil, nil
    C:PlaceDivider(C:Top())
end

function scripts.DividerUpdate()
    if not C.dragTop then return end
    local _, y = Hud.HelpLine.PointIn(C.frame)
    local top = math.max(LOW, math.min(HIGH, math.floor(y - C.grab + 0.5)))
    if top ~= C.dragTop then
        C.dragTop = top
        C:PlaceDivider(top)
    end
end

function scripts.MessageList(listFrame)
    local messageRows = {}
    C.list = Hud.Lines(listFrame, ROW, function(k, i, top)
        local fs = rowString(messageRows, C.list, k, top, L.MESSAGES.colour)
        fs:SetText(i and C.messages[i] or "")
    end)
end

function scripts.SpellList(spellFrame)
    local spellRows = {}
    C.spellText = {}
    C.spells = Hud.Lines(spellFrame, ROW, function(k, i, top)
        local fs = rowString(spellRows, C.spells, k, top, S.TEXT)
        fs:SetText(i and C.spellText[i] or "")
    end)
end

-- the countdown: the lines again each second (and at once when the effects or aethers change); a removal scrolls the
-- list to its top (RemoveEntry 0x0056BE20), a new line keeps its place (AddOrUpdateEntry 0x0056BCA0)
local wait
function scripts.Tick(_, elapsed)
    wait = wait - (elapsed or 0)
    if wait > 0 and not C.spellsChanged then return end
    wait, C.spellsChanged = 1, false
    C:RefreshSpells()
end

function scripts.Register(f)
    C.entry = Screen.Register(f, "7x.messages", "7.x Messages", function() return C:DB().enabled == true end)
end

function C:OnEnable()
    wait = 0
    TK.Xml.Load("main.xml", { scripts = scripts })
    self.divider = self.frame.divider
    self:Reset()
    self:Arrange()
end

--- The spell list's lines, drawn when they changed.
function C:RefreshSpells()
    local lines = C.SpellLines(GetTime())
    local old = self.spellText
    local same = #lines == #old
    for i = 1, #lines do if lines[i] ~= old[i] then same = false end end
    if same then return end
    local shorter = #lines < #old
    self.spellText = lines
    self.spells:SetCount(#lines + 1) -- the text ends with a line break: its height is a line more
    if shorter then self.spells:SetPos(0) else self.spells:Redraw() end
end

--- The divider at its top H, (3, H): its press area here and its picture, the screen's piece (7x.screen's ShowDivider).
--- s6-optimize R62: the drag, its cancel and the layout each placed both themselves before.
function C:PlaceDivider(top)
    self.divider:ClearAllPoints()
    self.divider:SetPoint("TOPLEFT", self.frame, "TOPLEFT", L.DIVIDER.x, -top)
    local screen = TK.GetComponent("7x.screen")
    if screen and screen.ShowDivider then screen:ShowDivider(top) end
end

--- The page laid out from the divider's top (OnActivate): the divider at (3, H), the messages' n rows above 244, the spell
--- list from 22 to H + 7; the messages scrolled to the newest, the spells to the top.
function C:Arrange()
    local f = self.frame
    if not f then return end
    local top = self:Top()
    self:PlaceDivider(top)
    local n = self:Rows(top)
    local m, sp = L.MESSAGES, L.SPELLS
    local listTop = m.bottom - ROW * n
    self.list:SetArea(m.left, listTop, m.right, m.bottom)
    self.list:End()
    self.spells:SetArea(sp.left, sp.top, sp.right, top + sp.below)
    self.spells:SetPos(0)
end

function C:Layout()
    local f = self.frame
    if not f then return end
    Screen.Place(self.entry, 1024, 768, L.PLACE[1], L.PLACE[2], self:DB().scale)
    self:Arrange() -- the rows' spacing follows the scale (Hud.Lines)
    TK.EditMode:UpdateMovers()
    f:SetShown(TK.GameState:InWorld() and self:DB().enabled == true)
end

function C:ApplySettings() self:Layout() end

Screen.Follow(C, "Layout")
-- the session's system lines (0x0A kinds 2 and 3) and the rules' own (item notices, the arrows' warning); whether the pane
-- shows or not, as 4a's pane takes them from the game screen's start
TK.On("TK_CHAT_MESSAGE", function(_, channel, text)
    if channel == "notice" then C:Add(text) end
end)
TK.On("TK_RULES_MESSAGE", function(_, text) C:Add(text) end)
-- a new game screen (the login's accepted 02, where 4a builds its panes) starts a new pane, as the chat log is cleared then
TK.On("TK_SESSION_STATE", function(_, state)
    if state == "Accepted" then C:Reset() end
end)
TK.On("UNIT_AURA", function() C.spellsChanged = true end)
TK.On("ACTIONBAR_UPDATE_COOLDOWN", function() C.spellsChanged = true end)
