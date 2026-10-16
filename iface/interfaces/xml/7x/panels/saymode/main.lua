-- s6-interface-7x (round 1): 7.x's say-mode button and its menu, the original's ChattingVarietyPane (the button, made
-- by MainMenuPane::InitializeMainUiGraph) and ChattingVarietySelectPane (the menu), from Source-5's class pages:
-- - the button: (10, 727)-(72, 751) on the 7.x screen, CHATVAR.EPF in CHATVAR.PAL, frame 0 while its menu is closed and
--   1 while it is open; the say mode's name (Talk, Shout, Whisper, Group, Clan) in 0x80, drawn twice a pixel apart, its
--   pen at x = 31 - 3 x length - 2 (6 pixels a character) on the line 18 (ChattingVarietyPane::OnPaint 0x00480E80);
-- - the menu: 67 x 110 at (7, 617), SUBWIN.EPF's 7-pixel frame in SUBWIN.PAL (SetupBackground 0x004816D0, DrawBorder
--   0x00481750); its six labels drawn twice a pixel apart in the port's colour (0x80) from x 15 (-Color- from 9) on the
--   lines 21 + 16 n (OnPaint 0x00481490); the row under the pointer outlined from x 4 to 62 round its 16-pixel
--   rectangle, raised (0x8F left and top, 0x80 right and bottom), sunken while pressed.
-- Its place follows the scaled screen (interfaces/screen.lua's Screen.Place) until the player moves it (edit mode, its
-- Layout tab).
-- s6-ui-core (round 85): the XML twin's scripts; the button, the menu, its rows and their places are main.xml's
-- (core/xml.md).
--
-- Input: a left press on the button opens the menu, or closes the open one (HandlePointerOrMouseEvent 0x00480CD0). The
-- menu's own (ChattingVarietySelectPane::HandlePointerOrMouseEvent 0x004811C0, round 2): a left press anywhere in it
-- chooses nothing, it only marks the menu pressed (the row under the pointer drawn sunken, following it from row to row);
-- the left release then chooses the row under it, or leaves the menu open when it is in the menu but on no row, or
-- closes it when it is outside; a left press outside closes it and goes on; the right button and the wheel leave it
-- open. Any key closes it and goes on (HandleKeyOrTextEvent 0x00481470), Escape too. A row's rectangle is 4a's,
-- (0, 6 + 16 n)-(67, 22 + 16 n) (GetItemRect 0x00481A80, HitTest 0x00481AD0); its choice is the game layer's menu row
-- (TK.Game.Chat.MenuAction and MenuChosen, core/game/chat.lua, as Modern's chat frame's menu: the rules' chat:mode sets
-- UserPane::m_currentSayMode and opens the mode's line, -Color- opens the ChattingColorPane dialog), so nothing here is
-- sent: the lines it opens send what the player types. No sound (ChattingPane.cpp plays none).

local C = TK.GetComponent("7x.saymode")
local S = require("interfaces.7x.skin")
local Screen = require("interfaces.screen")
-- 7.x's drawing helpers (X.Frame, X.Rect, X.Bold, X.Outline; s6-interface-7x-b round 8, the separation's step 5:
-- interfaces/7x/draw.lua, the dialogs look's file's before)
local X = require("interfaces.7x.draw")
-- s6-modular-g r27: use the published original-pane kit, after step 9 removed Hud's forwarders.
-- WIRE: ChattingVarietySelectPane 0x004811C0 / MapPane 0x00507150 rely on the same frame-local
-- point for row choice and outside pass-through. Changing these coordinates changes what the server sees.
local Help = require("interfaces.7x.hud").HelpLine
local E = require("interfaces.7x.elements")

local L = TK.Xml.Data("main.xml")
local ROWS = L.ROWS

--- The say mode (0-4) the button shows: the rules' live, the offline line's offline (the game layer's).
local function sayMode() return TK.Game.Chat.SayMode() end

-- ----- the menu -----

--- The row under the pointer (its index), or nil. WIRE: 4a's HitTest (above).
local function rowUnder(m)
    local x, y = Help.PointIn(m)
    if x >= ROWS.left and x < ROWS.right and y >= ROWS.top and y < ROWS.bottom then
        return math.floor((y - ROWS.top) / ROWS.height) + 1
    end
end

--- Whether the pointer is in the menu's 67 x 110.
local function inMenu(m)
    local x, y = Help.PointIn(m)
    return x >= 0 and x < ROWS.width and y >= 0 and y < ROWS.menuHeight
end

-- WIRE: ChattingVarietySelectPane 0x004811C0, case 3, takes a release only after its own press
-- (field_F8). Keep cross-row picking while pressed; an idle release passes on to the map.
-- Changing this changes which action or object-info request the server sees.
local function takeReleases(m, on)
    m:SetTakesEveryRelease(on)
    for _, row in ipairs(m.rows) do row:SetTakesEveryRelease(on) end
end

--- A left press anywhere in the menu: it is pressed, nothing is chosen yet (the outline drawn sunken).
local function press(m, button)
    if button ~= "LeftButton" then return end
    m.pressed = true
    takeReleases(m, true)
    for _, paint in ipairs(m.paints) do paint(true) end
end

--- The left release after a press in the menu: the row under it chooses, else in the menu it stays open, outside it
--- closes. The chosen row's action is the one the host froze for this release: the menu picks on its release
--- (SetPicksOnRelease), so the host freezes the action of the row under the release, at the release's own position,
--- wherever in the menu the press was and however little the pointer moved (round 3, Astra's review of round 2: a
--- short release across a row's edge had frozen none); the game layer's MenuChosen (TK.Game.Chat) runs it.
--- Wire: this is 4a's ChattingVarietySelectPane::HandlePointerOrMouseEvent (0x004811C0), which hit-tests the release
--- and chooses its row; the row chosen is the say mode and the line it opens (the game layer's MenuAction), so changing
--- which release chooses which row changes the chat packets that follow.
local function release(m, button)
    if button ~= "LeftButton" or not m.pressed then return end
    m.pressed = false
    takeReleases(m, false)
    for _, paint in ipairs(m.paints) do paint(false) end
    local i = rowUnder(m)
    if i then
        m:Hide()
        TK.Game.Chat.MenuChosen(i)
    elseif not inMenu(m) then
        m:Hide()
    end
end

-- the scripts main.xml names
local scripts = {}

function scripts.Press(m, button) press(m, button) end

function scripts.Release(m, button) release(m, button) end

function scripts.RowPress(row, button) press(row:GetParent(), button) end

function scripts.RowRelease(row, button) release(row:GetParent(), button) end

function scripts.RowUpdate(row)
    local m = row:GetParent()
    m.paints[row.index](m.pressed, rowUnder(m) == row.index)
end

--- A row's action (the game layer's menu row: WIRE, above), and its place in the menu's lists.
function scripts.Row(row)
    local m, i = row:GetParent(), row.index
    TK.Actions:SetTable(row, TK.Game.Chat.MenuAction(i))
    m.paints[i] = row.paint
    m.rows[i] = row
end

-- any key closes it and goes on: the menu watches the keys (SetWatchesKeys) and hears each key-down, its repeats too,
-- in its place among the inputs (GLOBAL_KEY_DOWN; live, the logic's KeySeen verdict), so a release after the key
-- finds it closed (round 3, Astra's review of round 2: a counter read after the frame's input missed both).
-- Wire: 4a's HandleKeyOrTextEvent (0x00481470) hides the menu and returns false, so the key still reaches the game and
-- sends what it sends without the menu, and a release after it chooses no row; taking the key here would drop it.
function scripts.WatchKeys(m)
    TK.On("GLOBAL_KEY_DOWN", function()
        if m:IsShown() then m:Hide() end
    end)
end

function scripts.MenuShow() C:Paint() end

function scripts.MenuHide(m)
    m.pressed = false
    takeReleases(m, false)
    for _, paint in ipairs(m.paints) do paint(false) end
    C:Paint()
end

-- a left press anywhere else closes it, and goes on (the say-mode button's own press toggles it). Wire: 4a's
-- ChattingVarietySelectPane::HandlePointerOrMouseEvent (0x004811C0) closes the menu on a press outside it and returns
-- false, so the press still reaches what is under it (the map: a walk, a target); this only watches. Taking the press,
-- or closing the menu on other presses, changes what the server sees (that walk or target, the row a release picks).
function scripts.WatchPresses(m)
    TK.On("GLOBAL_MOUSE_DOWN", function(_, button)
        if not m:IsShown() or button ~= "LeftButton" then return end
        if not inMenu(m) and not TK.Util.MouseWithin(C.frame) then m:Hide() end
    end)
end

function scripts.Own(f) C:Own(f) end

-- ----- the button -----

function scripts.ButtonDown(_, button)
    if button ~= "LeftButton" then return end
    C.menu:SetShown(not C.menu:IsShown())
end

-- the mode is the rules' (or the chat frame's offline): shown as it changes, as 4a's Refresh repaints it
function scripts.ButtonUpdate(f)
    if sayMode() ~= f.shownMode then C:Paint() end
end

function scripts.OwnButton(f)
    C.frame = f
    C:Own(f)
end

function C:OnEnable()
    self.menu = TK.Xml.Load("main.xml", { scripts = scripts, elements = E }).menu
    self.entry = Screen.Register(self.frame, "7x.saymode", "7.x Say-Mode Button", function() return self:DB().enabled == true end)
    self:Paint()
end

--- The button's picture (frame 1 while the menu is open) and the mode's name, bold, at 4a's pen.
function C:Paint()
    local f = self.frame
    if not f then return end
    local open = self.menu ~= nil and self.menu:IsShown()
    local a = L.ART
    S.Picture(f, f.art, a.file, open and a.open or a.closed, a.palette, 0, 0) -- none without the picture
    local mode = sayMode()
    f.shownMode = mode
    local text = L.LABELS[mode + 1] or L.LABELS[1]
    local pen = L.PEN
    X.Bold(f, f.label, pen.x - pen.half * #text - pen.less, pen.baseline, S.TEXT)
    f.label:SetText(text)
end

--- The button at the original's place on the scaled screen (unless moved), at the screen's scale times its own, and the
--- menu above it at its own place; in the game only.
function C:Layout()
    local f = self.frame
    if not f then return end
    local shown = Screen.PlacePanel(self, 1024, 768, L.PLACE[1], L.PLACE[2])
    -- the menu at (7, 617), 3 left of and 110 above the button: kept beside the button wherever the player put it
    local m = self.menu
    m:SetScale(f:GetScale())
    m:ClearAllPoints()
    m:SetPoint("BOTTOMLEFT", f, "TOPLEFT", L.MENU[1] - L.PLACE[1], 0)
    -- closed with the button out of the game or turned off: by what the layout asked for, not f:IsShown(), so a menu
    -- open while a plugin replaces the component comes back with it (round 64)
    if not shown then m:Hide() end
end

function C:ApplySettings() self:Layout() end

Screen.Follow(C, "Layout")
