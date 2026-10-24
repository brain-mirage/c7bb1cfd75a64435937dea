-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md): 5.33's message board,
-- OldSystemMessagePane (constructor 0x004B8E00) at (441, 304)-(639, 369) of the 640 x 480 screen, drawn as its paint
-- (0x004B97A0) and 4a's legacy branch of SystemMessagePane (OnPaint_27, AddWrappedText; ui/SystemMessagePane.cpp) draw
-- it: its messages from the oldest, each in colour 0x84 wrapped at 184 pixels in 12-pixel lines, over the frame's
-- parchment (s6-ui-core round 86: the paint clears the pane to colour 0, 0x0000, 5.33's colour key, and the pane is
-- keyed (mode 1), so what shows under the text is FRAME.EPF's; W:/5-3-client-source/documentation/interface/
-- black-boxes.md: round 16's black was that key reaching the screen, as in a renderer that ignores it); scrolled to
-- the newest, five lines showing (its scroll range: the lines less 5, sub_4B94C0); it starts with six empty messages
-- and keeps 200 (ScrollToLatest). What it shows (SystemMessagePane__HandlePacketEvent 0x004B9700):
--   - the server's notices, 0x0A kinds 2 and 3 (the session's "notice" lines, already cut at their tabs), each cut
--     into lines as AddWrappedText cuts it (a line ends after its last character that is not a letter or a digit once
--     the advances pass 184, or at the character that passes it);
--   - the rules' notices (TK_RULES_MESSAGE: 0x0F's "slot letter: name" and 0x10's lines, HandleItemNoticePacket and
--     AddInventoryItemNotice; the client's own system lines), each a message (AddColorStringMessage), cut the same way.
-- While it shows, these lines are its and not the chat's (5.33's chat pane has none of them; panels/chat).
-- Its scroll bar (s6-interface-5x-b): ScrollablePane's skin 2 at its right 12 pixels (SetSkinIndex(2) in the
-- constructor; interfaces/5x/scrollbar.lua), its arrows a line, its track 4 lines (the pane's page, sub_4B95C0), its
-- thumb dragged; the wheel scrolls it too. It draws only: nothing here is sent, and only its bar takes a press.
-- s6-ui-core (round 85): the XML twin's scripts; its frame, lines, bar and place are main.xml's (core/xml.md).

local C = TK.GetComponent("5x.board")
local S = require("interfaces.5x.skin")
local Screen = require("interfaces.screen")
local Wrap = require("interfaces.original.wrap") -- s6-interface-5x-b (round 9, the separation's step 5)
local E = require("interfaces.5x.elements")

local L = TK.Xml.Data("main.xml")
local LINES = L.LINES

--- The board as 5.33's starts it: six empty messages, the view at the newest.
function C:Clear()
    self.messages, self.offset = {}, 0
    for i = 1, LINES.start do self.messages[i] = "" end
    self:Draw()
end

--- Adds a text's lines as messages (the oldest go past 200) and shows the newest (ScrollToLatest). The lines are
--- AddWrappedText's at the legacy branch's 184 in 5.33's font 0 (the original client's wrap, interfaces/original/wrap.lua;
--- s6-interface-5x-b, round 9: this panel's C.Cut before, moved there as it was).
function C:Add(text)
    for _, line in ipairs(Wrap.Lines(text, LINES.width, S.TextWidth)) do self.messages[#self.messages + 1] = line end
    while #self.messages > LINES.keep do table.remove(self.messages, 1) end
    self.offset = 0
    self:Draw()
end

--- Lays out the five lines showing: the newest at the bottom of the five, the view offset lines back.
function C:Draw()
    local f = self.frame
    if not f then return end
    local n = #self.messages
    local first = math.max(1, n - LINES.shown + 1 - self.offset)
    for k = 1, LINES.shown do
        local fs = f.lines[k]
        local text = self.messages[first + k - 1]
        fs:SetText(text or "")
        fs:SetShown(text ~= nil)
    end
    if f.bar then f.bar:Refresh() end
end

--- Scrolls the view n lines back (older), up to the oldest five, or forward for a negative n, down to the newest.
function C:Scroll(n)
    self.offset = math.max(0, math.min(self.offset + n, #self.messages - LINES.shown))
    self:Draw()
end

--- Whether the board shows now (the chat leaves its lines to it then).
function C:IsShowing() return self.frame ~= nil and self.frame:IsShown() end

-- the scripts main.xml names
local scripts = {}

--- The five lines, one 12-pixel line each, drawn from its top (a measured box let a new line stand 6 pixels high).
function scripts.Lines(f)
    f.lines = {}
    for k = 1, LINES.shown do
        local fs = S.Text(f:CreateFontString(nil, "ARTWORK"), LINES.ink)
        fs:SetWordWrap(false)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetSize(LINES.width, LINES.height)
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -((k - 1) * LINES.height + 1))
        f.lines[k] = fs
    end
end

function scripts.Wheel(_, delta) C:Scroll(delta > 0 and 1 or -1) end

-- s6-interface-5x-b: the bar; 5.33's position counts lines from the oldest, this view's offset from the newest
local function range() return math.max(0, #(C.messages or {}) - LINES.shown) end
function scripts.BarRange() return range(), range() - (C.offset or 0), 4 end
function scripts.BarSet(_, pos) C:Scroll(range() - pos - C.offset) end

function C:OnEnable()
    local f = TK.Xml.Load("main.xml", { scripts = scripts, elements = E }).frame
    self:Own(f)
    self.frame = f
    self.entry = Screen.Register(f, "5x.board", "5.x Message Board", function() return self:DB().enabled == true end)
    self:Clear()

    TK.On("TK_CHAT_MESSAGE", function(_, channel, text)
        if channel == "notice" and self:IsShowing() then self:Add(text) end
    end)
    TK.On("TK_RULES_MESSAGE", function(_, text) if self:IsShowing() then self:Add(text) end end)
    -- a new game screen starts a new board (InitializeMainUiGraph at the login's accepted 02)
    TK.On("TK_SESSION_STATE", function(_, state) if state == "Accepted" then self:Clear() end end)
    TK.On("PLAYER_ENTERING_WORLD", function() if not __tk:IsOnline() then self:Clear() end end)
end

--- At 5.33's place on the scaled 5.x screen unless moved, at the screen's scale times its own; in the game only.
function C:ApplySettings() Screen.PlacePanel(self, S.WIDTH, S.HEIGHT, L.PLACE[1], L.PLACE[2]) end

Screen.Follow(C, "ApplySettings")
