-- s6-interface-7x-b: what 7.x's HUD panels share (interfaces/7x/panels/*; their places are the interfaces' root's
-- interfaces/screen.lua): the pointer in a pane's own pixels, 4a's scrolling text lists (the messages pane's, the chat
-- log), and the original's plain tooltip (SimpleHelpPane: the original client's help line since the separation's step
-- 5, interfaces/original/helppane.lua). Drawing only: nothing here is sent (the lists' press routing is wire:
-- Hud.Lines; so is the tooltip's, which uses up the next press: the help line's).

local S = require("interfaces.7x.skin")

-- the original client's help line (SimpleHelpPane), on 7.x's skin and its 1024 x 768 screen
local Help = require("interfaces.original.helppane")({ skin = S, screen = { width = S.WIDTH, height = S.HEIGHT } })

local Hud = {}

--- The original client's help line on 7.x's skin and screen, for 7.x's panels: PointIn(f) (the pointer in a frame's own
--- units from its top left, x right, y down, as 4a's panes take a press's point), PlaceBox(box, owner, w, h) (a help box
--- placed as 4a's SimpleHelpPane and ItemHelpPane place theirs: the item box) and Show(owner, text, ms) (4a's
--- SimpleHelpPane for owner's press at the pointer, for ms milliseconds). WIRE: while a tip shows, the next press
--- anywhere only closes it, and a move, a key-down, a release or a wheel turn closes it and goes on (4a's
--- SimpleHelpPane::HandlePointerOrMouseEvent 0x004C7450, HandleKeyOrTextEvent 0x004C74A0); a tip shown where 4a shows
--- none takes a press 4a sends on, so changing when the panels call Show changes what the server sees.
--- s6-interface-5x (round 15, the separation's step 9): Hud.PointIn, Hud.PlaceBox and Hud.Help, the forwarders to it
--- since step 5, went.
Hud.HelpLine = Help

--- A list of text lines as 4a's ScrollablePane kind draws one (the messages pane's two lists, the chat log): rows
--- rowHeight apart, a position in whole lines (0: the first line at the top; range = the lines - the rows in view), only
--- the rows in view drawn (paint(k, i, top): row k from the top, 0-based, shows line i, or nothing for nil; the caller's
--- rows go on L.text at (0, -top), which cuts them at the text's rectangle as 4a's pane clips), and 4a's vertical
--- scroll bar, 13 pixels right of the text (7.x's X.Bar, interfaces/7x/draw.lua, over the kit's scroll area: the track,
--- the 38-pixel thumb and its drag; nothing while it cannot scroll). The wheel over the text moves it a line a notch. The
--- text takes no press (wheel only).
---
--- Input routing (the chat log lies over the map view): 4a's bar (ScrollPane::HandlePointerOrMouseEvent 0x0055C400)
--- takes a left press anywhere on it while it can scroll (its thumb then follows the pointer until the release) and
--- declines every other press (the right button, a double click's second press), which goes on to the pane under it, the
--- map; a press on the text goes on to the map too (ChattingPane keeps ScrollablePane::OnMouseEvent, which declines it).
--- So the bar's track and thumb claim the left button only, and only while the bar can scroll, and the text takes the
--- wheel alone: changing that turns map presses there into none, which the server would see. s6-interface-7x-b (round 2,
--- Astra's review of round 1): the claim covers single presses only (Frame:SetPassesDoubles: 4a's bar acts on event
--- type 1 and lets a double click's second press, type 2, fall through to the map), and an accepted press takes the
--- input's capture until its release (Frame:SetCapturesPress: ScrollPane.cpp:125 captures the mouse, and
--- EventDispatcher.cpp:258-279 hands every key and other press to the capture alone), so holding the bar, m sends no 7C
--- and a right press no look. Changing either changes what the server sees.
---
--- s6-interface-7x-b (round 10): 7.x's skin scales its font with its fixed artwork, so each row keeps 4a's layout height
--- (SystemMessagePane's 12, the chat log's 13) even in smaller windows. Drawing only; the capture, double-press and
--- key paths above still match EventDispatcher.cpp:258-279. Changing those paths changes what the server sees.
function Hud.Lines(parent, rowHeight, paint)
    local X = require("interfaces.7x.draw")
    local L = { count = 0, pos = 0, visible = 0, range = 0, row = rowHeight }
    local sf = TK.UI.ScrollArea(parent)
    sf:EnableMouse(false)
    sf:EnableMouseWheel(false) -- the wheel is the text's (below)
    X.Bar(sf, rowHeight)
    local style = sf.barStyle
    local track, thumb = sf.track, sf.thumb
    thumb:EnableMouse(false)
    for _, part in ipairs({ track, thumb }) do
        part:SetPassesDoubles(true)
        part:SetCapturesPress(true)
    end
    -- the bar's own changes (the thumb dragged) move the position; its press areas follow whether it can scroll
    sf.barStyle = function(range, h)
        style(range, h)
        local can = L.range > 0 and h > 38
        if can then
            track:SetClaimButtons("LeftButton")
            thumb:SetClaimButtons("LeftButton")
        else
            track:SetClaimButtons()
            thumb:SetClaimButtons()
        end
        local pos = math.floor(sf:GetVerticalScroll() / rowHeight + 0.5)
        if pos ~= L.pos then
            L.pos = math.max(0, math.min(L.range, pos))
            L:Redraw()
        end
    end
    -- a left press on the track: the thumb's middle follows the pointer until the release (4a's EPF bar)
    local function follow()
        local _, y = Help.PointIn(track)
        local h = track:GetHeight()
        if h > 38 and L.range > 0 then L:SetPos(math.floor((y - 19) * L.range / (h - 38) + 0.5)) end
    end
    track:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        L.dragging = true
        follow()
        track:SetScript("OnUpdate", follow)
    end)
    track:SetScript("OnMouseUp", function()
        L.dragging = false
        track:SetScript("OnUpdate", nil)
    end)
    thumb:HookScript("OnMouseDown", function() L.dragging = true end)
    thumb:HookScript("OnMouseUp", function() L.dragging = false end)
    -- the text: a scroll frame that never scrolls, so the rows are cut at its rectangle; it takes the wheel, no press
    local clip = CreateFrame("ScrollFrame", nil, parent)
    local text = CreateFrame("Frame", nil, clip)
    clip:SetScrollChild(text)
    clip:EnableMouse(false)
    clip:EnableMouseWheel(true)
    clip:SetScript("OnMouseWheel", function(_, delta) L:SetPos(L.pos - delta) end)
    L.sf, L.clip, L.text = sf, clip, text

    --- The text's rectangle (l, t)-(r, b) in parent's units, its bar along it at r..r + 13; the rows in view are those
    --- that fit whole, and one more that the text area cuts. Text and scroll bar count the same original row height;
    --- scaling changes their screen pixels together.
    function L:SetArea(l, t, r, b)
        self.area = { l, t, r, b }
        self.visible = math.floor((b - t) / self.row)
        sf:ClearAllPoints()
        sf:SetPoint("TOPLEFT", parent, "TOPLEFT", l, -t)
        sf:SetSize(r - l, b - t)
        clip:ClearAllPoints()
        clip:SetPoint("TOPLEFT", parent, "TOPLEFT", l, -t)
        clip:SetSize(r - l, b - t)
        text:SetSize(r - l, b - t)
        self:SetCount(self.count)
    end

    --- n lines; the position kept where it can be.
    function L:SetCount(n)
        self.count = n
        self.range = math.max(0, n - self.visible)
        sf.content:SetSize(1, sf:GetHeight() + self.range * rowHeight)
        self:SetPos(self.pos)
    end

    --- The position (clamped to 0..range), the bar and the rows.
    function L:SetPos(p)
        self.pos = math.max(0, math.min(self.range, p))
        sf:SetVerticalScroll(self.pos * rowHeight)
        sf.Refresh()
        self:Redraw()
    end

    function L:End() self:SetPos(self.range) end

    function L:Redraw()
        local area = self.area
        if not area then return end
        local rows = math.ceil((area[4] - area[2]) / self.row)
        for k = 0, rows - 1 do
            local i = self.pos + k + 1
            paint(k, i <= self.count and i or nil, k * self.row)
        end
        -- Empty previously painted rows that a smaller text area no longer reaches.
        for k = rows, (self.painted or 0) - 1 do paint(k, nil, k * self.row) end
        self.painted = rows
    end

    return L
end

return Hud
