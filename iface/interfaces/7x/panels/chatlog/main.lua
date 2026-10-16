-- s6-interface-7x-b: 7.x's chat log, the original's chat area over the bottom of the map view (MainMenuPane::
-- InitializeMainUiGraph, the frame layer): with r the log's rows (settings.toml chat.lines, 4 to 50, 8 by default):
--   - the log (ChattingPane) at (23, 710 - 13 r)-(806, 710) (SetVisibleRowCount 0x0047FBD0): one 13-pixel row a line, no
--     wrap (MeasureLines 0x00483630: a line past the text's 770 pixels is cut), each outlined a pixel left, right, up and
--     down in its outline colour, then drawn (ColorStringChattingMessage::Draw 0x004836A0, DrawOutlinedText 0x004BAFA0),
--     its pen at the row's top + 12; 50 blank lines at the start (the constructor 0x0047EFB0), at most 1000 kept
--     (AddIncomingMessage 0x0047F370); a new line scrolls to the newest unless Shift is held or the bar is held; the
--     wheel over the text a line a notch; 4a's bar along its right edge (13 pixels, from 793);
--   - the backdrop (ChattingBackPane) at (9, 700 - 13 r)-(816, 720), by its mode (the chat bar's backdrop button turns it,
--     settings.toml chat.mode): the 7.x screen's Chat Backdrop piece, a Decoration panel of its own, which this sizes and
--     shades (7x.screen's ShowChatBackdrop);
--   - the height handle (ChattingModifyHeightPane) at (792, 693 - 13 r)-(807, 708 - 13 r): CHATSC.EPF in INVENBUT.PAL
--     (OnPaint 0x00480BB0); dragged with the left button (HandlePointerOrMouseEvent 0x00480890), it follows the pointer
--     (y 50 to 650) and on its release the log takes max(4, (710 - y) / 13) rows, saved.
-- With the chat switched off (the chat bar's switch, settings.toml chat.secondary) the log, its bar, the backdrop and the
-- handle are gone; lines still come in. The lines are the game layer's (TK_CHAT_LINE, core/game/chat.lua: its colours
-- worked out as 4a's: Config::m_chatColorPairs, the packets' own colours) but the system lines 4a puts in the messages
-- pane (0x0A kinds 2 and 3, the rules' notices: panels/messages) and the server's message pane (0x58). Its place follows the scaled screen until the player moves it (edit
-- mode, its Layout tab); the area is the backdrop's at 8 rows, and the log grows upwards from its bottom.
--
-- Wire: nothing is sent. A press on the log's text, or on the backdrop, goes on to the map view under it (ChattingPane
-- keeps ScrollablePane::OnMouseEvent, which declines it; ChattingBackPane has no handler): a step, a target, a look, as
-- anywhere on the map. So the text takes the wheel only, the backdrop (the screen's) no mouse, the handle claims the left
-- button only while the chat is on (Frame:SetClaimButtons), its single presses only (SetPassesDoubles: its handler acts on
-- event type 1 and lets a double click's second press fall through to the map; s6-interface-7x-b round 2, Astra's review
-- of round 1), and the bar the left button only while it can scroll (Hud.Lines).
-- Shift with Up, Down, Page Up or Page Down scrolls it (ChattingPane::HandleKeyOrTextEvent 0x0047F6F0: the rules take
-- those keys before the game, chat:scroll; the game layer's bindings hand them here while this log shows). Changing which
-- presses these frames take changes what the server sees.

local C = TK.GetComponent("7x.chatlog")
local H = __tk
local S = require("interfaces.7x.skin")
local Hud = require("interfaces.7x.hud")
local Screen = require("interfaces.screen")

-- the panel's area: the backdrop's at 8 rows, (9, 596)-(816, 720); everything placed from its bottom (720 on the screen)
local RECT = { 9, 596, 816, 720 }
local ROW = 13
local KEEP, BLANKS = 1000, 50
local MIN_ROWS, MAX_ROWS = 4, 50

-- GrafPort::DrawOutlinedText (0x004BAFA0): the text in the outline colour a pixel left, right, up and down, then the text
local OUTLINE = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

-- one of 4a's 50 blank lines (" ")
local BLANK = { text = " " }

-- the lines, oldest first: the game layer's entries ({ text, rgb, outline, channel }) and blanks
C.lines = {}

--- The rows (4-50), the backdrop's mode (0-2) and whether the chat is on, as settings.toml keeps them.
function C.Settings()
    local rows = tonumber(H:ClientSettingInt("chat", "lines")) or 8
    rows = math.max(MIN_ROWS, math.min(MAX_ROWS, rows))
    return rows, TK.Game.Chat.BackdropMode(), TK.Game.Chat.LogEnabled()
end

--- A y on the 7.x screen as the panel's own y (from its top).
local function own(y) return y - RECT[2] end

--- A new game screen's log: its 50 blank lines.
function C:Reset()
    C.lines = {}
    for i = 1, BLANKS do C.lines[i] = BLANK end
    if self.list then
        self.list:SetCount(#C.lines)
        self.list:End()
    end
end

--- A line of the chat frame's into the log, the oldest dropped past 1000; to the newest unless Shift is held (show: the
--- screenshot's line, which always comes into view) or the bar is held.
function C:Add(entry, show)
    -- the messages pane's (SystemMessagePane::HandleServerTextPacket), and the message pane's (0x58)
    if entry.channel == "notice" or entry.channel == "banner" then return end
    local list = C.lines
    list[#list + 1] = entry
    if #list > KEEP then table.remove(list, 1) end
    local L = self.list
    -- s6-interface-5x (round 13's hotfix, a marked edit): the game screen's lines given at a late start are drawn once
    -- after them (TK_CHAT_REPLAYED, OnEnable)
    if not L or TK.Game.Chat.replaying then return end
    L:SetCount(#list)
    if (show or not IsShiftKeyDown()) and not L.dragging then L:End() else L:Redraw() end
end

--- Scrolls n lines towards the older (negative: the newer), or a page (dir 1 older, -1 newer: the rows less one), as
--- Shift with Up, Down, Page Up and Page Down do.
function C:Scroll(n) if self.list then self.list:SetPos(self.list.pos - n) end end
function C:Page(dir) self:Scroll(dir * math.max(1, (self.rows or 8) - 1)) end

--- A row's five font strings (four outline copies under the text), made at its first use, its pen at the row's top + 12
--- (top: Hud.Lines' spacing), placed again when the spacing changes.
local function row(rows, text, k, top)
    local r = rows[k]
    if not r then
        r = { outline = {} }
        for i in ipairs(OUTLINE) do r.outline[i] = text:CreateFontString(nil, "ARTWORK") end
        r.text = text:CreateFontString(nil, "OVERLAY")
        rows[k] = r
    end
    if r.top ~= top then
        r.top = top
        for i, o in ipairs(OUTLINE) do S.PenText(r.outline[i], text, "", o[1], top + 12 + o[2]) end
        S.PenText(r.text, text, "", 0, top + 12)
    end
    return r
end

function C:OnEnable()
    local f = CreateFrame("Frame", "TK7xChatLog", UIParent)
    f:SetFrameStrata("LOW")
    f:SetFrameLevel(6) -- the frame layer: over the map view, under the chat bar and the strip's buttons
    f:SetSize(RECT[3] - RECT[1], RECT[4] - RECT[2])
    f:Hide()
    self.frame = f
    self:Own(f)
    -- the log
    local logFrame = CreateFrame("Frame", nil, f)
    logFrame:SetAllPoints(f)
    logFrame:SetFrameLevel(f:GetFrameLevel() + 1)
    local rows = {}
    self.list = Hud.Lines(logFrame, ROW, function(k, i, top)
        local r = row(rows, self.list.text, k, top)
        local entry = i and C.lines[i]
        local text = entry and entry.text or ""
        r.text:SetText(text)
        if entry and entry.rgb then r.text:SetTextColor(entry.rgb[1], entry.rgb[2], entry.rgb[3], 1) end
        for _, o in ipairs(r.outline) do
            local outline = entry and entry.outline
            o:SetText(outline and text or "")
            if outline then o:SetTextColor(outline[1], outline[2], outline[3], 1) end
        end
    end)
    self.logFrame = logFrame
    -- the height handle: dragged with the left button while the chat is on
    local handle = CreateFrame("Frame", "TK7xChatHandle", f)
    handle:SetFrameLevel(f:GetFrameLevel() + 2)
    handle:SetSize(807 - 792, 15)
    handle.art = S.Picture(handle, nil, "CHATSC.EPF", 0, "INVENBUT.PAL", 0, 0, "ARTWORK")
    handle:SetPassesDoubles(true)
    handle:SetScript("OnMouseDown", function(_, button, double)
        if button ~= "LeftButton" or double then return end
        local _, y = Hud.HelpLine.PointIn(handle)
        self.grab = y
    end)
    handle:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not self.grab then return end
        self.grab = nil
        local _, y = Hud.HelpLine.PointIn(f)
        y = math.max(50, math.min(650, y + RECT[2]))
        local rowsNow = math.min(MAX_ROWS, math.max(MIN_ROWS, math.floor((710 - y) / ROW)))
        H:ClientSettingSetInt("chat", "lines", rowsNow)
        H:ClientSettingsSave()
        self:Arrange(true)
    end)
    -- s6-modular-g r26: discard only the temporary visual drag when no OnMouseUp is delivered.
    -- WIRE: ItemHelpPane::HandlePointerOrMouseEvent 0x004CCC40 owns a swallowed release. Do not invoke
    -- ChattingModifyHeightPane's release/commit (0x00480890), resize/scroll the log, or save here;
    -- turning this cancellation into an underlying input changes what the server sees.
    handle:SetScript("OnPressCancelled", function(_, button)
        if button ~= "LeftButton" or not self.grab then return end
        self.grab = nil
        local rows = C.Settings()
        handle:ClearAllPoints()
        handle:SetPoint("TOPLEFT", f, "TOPLEFT", 792 - RECT[1], -own(693 - ROW * rows))
    end)
    -- while held, the handle alone follows the pointer (its top at the pointer's y less the grab, y 50 to 650)
    handle:SetScript("OnUpdate", function()
        if not self.grab then return end
        local _, y = Hud.HelpLine.PointIn(f)
        y = math.max(50, math.min(650, y + RECT[2]))
        handle:ClearAllPoints()
        handle:SetPoint("TOPLEFT", f, "TOPLEFT", 792 - RECT[1], -(own(y) - self.grab))
    end)
    self.handle = handle
    -- the chat bar's buttons change the mode and the switch (settings.toml): followed as they change
    f:SetScript("OnUpdate", function()
        local rowsNow, mode, on = C.Settings()
        if rowsNow ~= self.rows or mode ~= self.mode or on ~= self.on then self:Arrange(rowsNow ~= self.rows) end
    end)
    self.entry = Screen.Register(f, "7x.chatlog", "7.x Chat Log", function() return self:DB().enabled == true end)
    -- the chat's lines, and its scroll keys while this log shows (the game layer's; s6-interface-5x round 12: they were
    -- Modern's chat frame's hooks before)
    TK.On("TK_CHAT_LINE", function(_, entry, show) self:Add(entry, show) end)
    TK.On("TK_CHAT_REPLAYED", function()
        self.list:SetCount(#C.lines)
        self.list:End()
    end)
    TK.Game.Chat.ProvideLog("7x.chatlog", { shown = function() return self:Shown() end,
                                            scroll = function(n) self:Scroll(n) end, page = function(dir) self:Page(dir) end })
    self:Reset()
    self:Arrange(true)
end

--- The parts for the rows, the mode and the switch now: the backdrop (9, 700 - 13 r)-(816, 720) by its mode (the screen's
--- piece), the log (23, 710 - 13 r)-(806, 710) and its bar, the handle (792, 693 - 13 r); none of them while the chat is
--- off. A change of rows scrolls the log to the newest (SetVisibleRowCount).
function C:Arrange(newRows)
    local f = self.frame
    if not f then return end
    local rows, mode, on = C.Settings()
    self.rows, self.mode, self.on = rows, mode, on
    local screen = TK.GetComponent("7x.screen")
    if screen and screen.ShowChatBackdrop then screen:ShowChatBackdrop(rows, mode, on) end
    self.list:SetArea(23 - RECT[1], own(710 - ROW * rows), 793 - RECT[1], own(710))
    if newRows then self.list:End() end
    self.logFrame:SetShown(on)
    local handle = self.handle
    handle:ClearAllPoints()
    handle:SetPoint("TOPLEFT", f, "TOPLEFT", 792 - RECT[1], -own(693 - ROW * rows))
    handle:SetShown(on)
    if on then handle:SetClaimButtons("LeftButton") else handle:SetClaimButtons() end
end

function C:Layout()
    local f = self.frame
    if not f then return end
    Screen.Place(self.entry, 1024, 768, RECT[1], RECT[2], self:DB().scale)
    self:Arrange(false) -- the rows' spacing follows the scale (Hud.Lines)
    TK.EditMode:UpdateMovers()
    f:SetShown(TK.GameState:InWorld() and self:DB().enabled == true)
end

--- Whether the log shows (the scroll keys come here then).
function C:Shown() return self.frame ~= nil and self.frame:IsShown() end

function C:ApplySettings() self:Layout() end

Screen.Follow(C, "Layout")
-- ChattingHandlePane invalidates these parts on either presentation button's release. Reuse the same arranger.
TK.On("TK_CHAT_SETTINGS", function() C:Arrange(false) end)
-- a new game screen (the login's accepted 02) starts a new log, as the chat frame clears its own then
TK.On("TK_SESSION_STATE", function(_, state)
    if state == "Accepted" then C:Reset() end
end)
