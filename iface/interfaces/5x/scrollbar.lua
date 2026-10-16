-- s6-interface-5x-b (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md): 5.33's vertical scroll bar,
-- the ScrollPane a ScrollablePane keeps at its right (ScrollPane.cpp's unit in 5.33, 0x0049A9C0-0x0049BAB0; 4a's
-- ui/ScrollPane.cpp keeps the same classic code, ScrollPane::OnPaint's second branch, with names). For the 5.x panes that
-- scroll: the side panel's text boxes (skin 0), the chat (skin 1) and the message board (skin 2).
--
-- Its parts (GetScrollPartRect 0x0049B320), by skin a bar w wide with arrows e long (w: 13, 12, 12, word_52BF64; e: 13,
-- 10, 10, kClassicScrollPanePartExtentBySkin 0x0052BF70): 0 the up arrow at the top, 4 the down arrow at the bottom, and
-- while the pane scrolls (its range above 0) the thumb 2, e long, at e + pos (h - 3 e) / range from the top, with the
-- track above it (1) and below it (3); while it does not, the track between the arrows is all part 2.
-- Its paint (sub_49AE00): SCRL001.EPF in SCRL001.PAL, 12 frames a skin: the arrows 3 and 2 (7 and 6 pressed), the track
-- 11 (10 pressed) tiled, the thumb 8 (9 pressed) over 10; a bar that does not scroll is 10 tiled with its two arrows,
-- all under a wash of 0x8F (draw mode 2).
-- Its press (HandlePointerOrMouseEvent 0x0049ABC0, ProcessActivePart 0x0049B7B0, UpdatePositionFromCursor 0x0049B980):
-- only while the pane scrolls; a left press on a part makes it the active one and acts at once, then again 200 ms later
-- and every 30 ms after while the button is held: an arrow a line, the track the pane's page, each only while the
-- pointer is still on that part; the thumb follows the pointer, the range times the thumb's travel over the track's;
-- the release ends it. The wheel stays the pane's own.
-- Drawing and the panes' own views only: nothing here is sent (5.33's and 7.5.2's scroll bars send nothing).
-- s6-modular-g (round 21, the owner's research on presses reaching the wrong place): the bar takes only what 4a's takes
-- (ScrollPane::HandlePointerOrMouseEvent 0x0055C400's classic branch, ScrollPane.cpp:144-172, the code 5.33's keeps):
-- the left button's single press while the pane scrolls (Frame:SetClaimButtons, SetPassesDoubles), which captures the
-- input until its release (CaptureMouse, ScrollPane.cpp:158; Frame:SetCapturesPress). Every other press, a double
-- press's second and a press while it cannot scroll go on to what is under it, as 7.x's bars (interfaces/7x/hud.lua
-- Hud.Lines). WIRE: while the capture holds, EventDispatcher hands it every key (EventDispatcher.cpp:279), so holding
-- the bar, m sends no 7C; it did before. Changing this changes what the server sees.

local S = require("interfaces.5x.skin")

local Bar = {}
Bar.__index = Bar

local WIDTH = { [0] = 13, 12, 12 }
local ARROW = { [0] = 13, 10, 10 }

--- A bar's width for a skin (the pane's text keeps clear of it).
function Bar.Width(skin) return WIDTH[skin or 0] end

--- A new bar at (l, t)-(l + its width, b) of parent, for skin 0-2, over a pane's view: view.Range() gives the pane's
--- range, its position and its page (in lines: 0 at the top), view.Set(pos) scrolls it there.
function Bar.New(parent, l, t, b, skin, view)
    local self = setmetatable({ skin = skin or 0, view = view, pool = {}, used = 0 }, Bar)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", l, -t)
    f:SetSize(WIDTH[self.skin], b - t)
    f:SetFrameLevel(parent:GetFrameLevel() + 2)
    f:SetPassesDoubles(true) -- s6-modular-g (round 21): the left press only while it scrolls, which captures (above)
    f:SetCapturesPress(true)
    self.frame = f
    self.wash = S.Fill(f:CreateTexture(nil, "OVERLAY"), S.WHITE, 0.5)
    self.wash:SetAllPoints(f)
    f:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then self:Press() end end)
    f:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then self:Release() end end)
    f:SetScript("OnHide", function() self:Release() end)
    f:SetScript("OnUpdate", function(_, elapsed)
        if not self.active then return end
        self.wait = self.wait - (elapsed or 0)
        if self.wait > 0 then return end
        self.wait = 0.03 -- ScrollPane::OnTimer: again every 30 ms
        self:Process()
    end)
    self:Refresh()
    return self
end

--- The range, position and page now (the range 0 or more, the position within it).
function Bar:Range()
    local range, pos, page = self.view.Range()
    range = math.max(0, math.floor(range or 0))
    return range, math.max(0, math.min(range, math.floor(pos or 0))), math.floor(page or 1)
end

--- Part n's rectangle in the bar (l, t, r, b), or nil for an empty one.
function Bar:Part(n)
    local w, h, e = WIDTH[self.skin], math.floor(self.frame:GetHeight() + 0.5), ARROW[self.skin]
    if n == 0 then return 0, 0, w, e end
    if n == 4 then return 0, h - e, w, h end
    local range, pos = self:Range()
    if range <= 0 then
        if n == 2 then return 0, e, w, h - e end
        return nil
    end
    -- C's integer division (the values are not negative)
    local top = e + math.floor(pos * (h - 3 * e) / range)
    if n == 2 then return 0, top, w, top + e end
    if n == 1 then return 0, e, w, top end
    return 0, top + e, w, h - e
end

--- The part under (x, y) of the bar, the first of 0-4 that holds it (HitTestPart 0x0049B2C0), or nil.
function Bar:Hit(x, y)
    for n = 0, 4 do
        local l, t, r, b = self:Part(n)
        if l and x >= l and x < r and y >= t and y < b then return n end
    end
end

--- The pointer in the bar, in its pixels from its top left.
function Bar:Pointer()
    local f = self.frame
    local l, b, w, h = TK.Util.RootRect(f)
    if not l or w <= 0 then return -1, -1 end
    local x, y = TK.Util.CursorRoot()
    local k = f:GetWidth() / w
    return (x - l) * k, (b + h - y) * k
end

--- A left press: the part under the pointer becomes the active one and acts, then 200 ms later and every 30 ms while
--- held (ScrollPane::HandlePointerOrMouseEvent's case 1). Nothing while the pane does not scroll.
function Bar:Press()
    if self:Range() <= 0 then return end
    local x, y = self:Pointer()
    local part = self:Hit(x, y)
    if not part then return end
    self.active, self.lit = part, part
    if part == 2 then
        local _, t = self:Part(2)
        self.grab = y - t
    end
    self:Process()
    self.wait = 0.2
end

function Bar:Release()
    if not self.active then return end
    self.active, self.lit = nil, nil
    self:Refresh()
end

--- The active part acts (ProcessActivePart): the thumb follows the pointer; an arrow or the track steps while the pointer
--- is on it, and is unlit while it is not.
function Bar:Process()
    local range, pos, page = self:Range()
    local x, y = self:Pointer()
    local to = pos
    if self.active == 2 then
        local _, _, _, top = self:Part(0)
        local _, bottom = self:Part(4)
        local e = ARROW[self.skin]
        local at = math.max(top, math.min(bottom - e, y - self.grab))
        local travel = bottom - e - top
        if travel > 0 then to = math.floor(range * (at - top) / travel) end
    else
        local part = self:Hit(x, y)
        if part == self.active then
            self.lit = part
            if part == 0 then to = pos - 1
            elseif part == 1 then to = pos - page
            elseif part == 3 then to = pos + page
            elseif part == 4 then to = pos + 1 end
        else
            self.lit = nil
        end
    end
    to = math.max(0, math.min(range, to))
    if to ~= pos then self.view.Set(to) end
    self:Refresh()
end

--- A texture of the pool for this drawing, on a layer: the tiles on BORDER, the arrows and the thumb over them.
function Bar:Texture(layer)
    self.used = self.used + 1
    local t = self.pool[self.used]
    if not t then
        t = self.frame:CreateTexture(nil, "ARTWORK")
        self.pool[self.used] = t
    end
    t:SetDrawLayer(layer or "ARTWORK", 0)
    return t
end

--- SCRL001.EPF's frame n at (l, t) of the bar, cut at (r, b).
function Bar:Draw(n, l, t, r, b, layer)
    local key, w, h = S.Image("SCRL001.EPF", 12 * self.skin + n, "SCRL001.PAL")
    if not key then return end
    local ox, oy = TK.Art.Origin(key)
    local cw, ch = math.min(w, r - l - ox), math.min(h, b - t - oy)
    if cw <= 0 or ch <= 0 then return end
    local tex = self:Texture(layer)
    tex:SetTexture(key)
    tex:SetTexCoord(0, cw / w, 0, ch / h)
    tex:SetSize(cw, ch)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", self.frame, "TOPLEFT", l + ox, -(t + oy))
    tex:Show()
end

--- Frame n tiled over (l, t)-(r, b) from its top left (GrafPort::DrawTiledBackground).
function Bar:Tile(n, l, t, r, b)
    local _, w, h = S.Image("SCRL001.EPF", 12 * self.skin + n, "SCRL001.PAL")
    if not w or w <= 0 or h <= 0 then return end
    for y = t, b - 1, h do
        for x = l, r - 1, w do self:Draw(n, x, y, r, b, "BORDER") end
    end
end

--- Draws the bar for the pane's view now (after it scrolls or its content changes).
function Bar:Refresh()
    for i = 1, self.used do self.pool[i]:Hide() end
    self.used = 0
    local range = self:Range()
    local lit = self.lit
    -- s6-modular-g (round 21): its press area follows whether it scrolls (the header's wire note)
    if range > 0 then self.frame:SetClaimButtons("LeftButton") else self.frame:SetClaimButtons() end
    if range > 0 then
        local l, t, r, b = self:Part(0)
        self:Draw(lit == 0 and 7 or 3, l, t, r, b)
        l, t, r, b = self:Part(4)
        self:Draw(lit == 4 and 6 or 2, l, t, r, b)
        for _, n in ipairs({ 1, 3 }) do
            l, t, r, b = self:Part(n)
            if l then self:Tile(lit == n and 10 or 11, l, t, r, b) end
        end
        l, t, r, b = self:Part(2)
        self:Tile(10, l, t, r, b)
        self:Draw(lit == 2 and 9 or 8, l, t, r, b)
        self.wash:Hide()
    else
        local w, h = WIDTH[self.skin], math.floor(self.frame:GetHeight() + 0.5)
        self:Tile(10, 0, 0, w, h)
        local l, t, r, b = self:Part(0)
        self:Draw(3, l, t, r, b)
        l, t, r, b = self:Part(4)
        self:Draw(2, l, t, r, b)
        self.wash:SetShown(S.Image("SCRL001.EPF", 0, "SCRL001.PAL") ~= nil)
    end
end

return Bar
