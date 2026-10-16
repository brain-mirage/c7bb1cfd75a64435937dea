-- s6-interface-7x-b (round 5): what 7.x's side panel pages draw with (interfaces/7x/panels/side: main.lua's items, spells,
-- group and collection, selflook.lua, look.lua and options.lua). s6-modular-g's round 14 kept these in main.lua; they moved
-- here so each tab's pane can live in its own file. Drawing only, but for the presses each helper's comment names.

local S = require("interfaces.7x.skin")
local Hud = require("interfaces.7x.hud")

local K = {}

--- An invisible control over (l, t)-(r, b) of a page, right and bottom exclusive (4a's PointInRect).
function K.Hit(page, l, t, r, b, name)
    local btn = CreateFrame("Button", name, page)
    K.Place(btn, page, l, t, r, b)
    return btn
end

--- Puts a frame over (l, t)-(r, b) of a page.
function K.Place(frame, page, l, t, r, b)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", page, "TOPLEFT", l, -t)
    frame:SetSize(r - l, b - t)
end

--- The pointer in a frame's own pixels from its top left (the help line's: Hud.HelpLine.PointIn).
K.PointIn = Hud.HelpLine.PointIn

--- A font string of a page, hidden until drawn.
function K.Text(page)
    local fs = page:CreateFontString(nil, "OVERLAY")
    fs:Hide()
    return fs
end

--- INVENBUT.EPF's button (frame 7 x state + picture: state 0 normal, 1 under the pointer, 2 pressed) hit at (l, t)-(r, b),
--- drawn page.dx pixels right of it (4a's expanded panes draw everything 5 to the right and test their buttons where they
--- were: InventoryPane.cpp:856-876), its left press running press. The panes' buttons act on the press, event type 1:
--- a double click's second press (type 2) runs nothing (NewInventoryPane::HandlePointerOrMouseEvent 0x004ECB50; the
--- spells' 0x0057D9C0; the group's 0x0056DB00), so Mix opens once and Expand toggles once. Returns the control; set
--- btn.picture and call btn.Draw() to change its picture.
function K.InvenButton(page, l, t, r, b, picture, press)
    local btn = K.Hit(page, l, t, r, b)
    btn.picture, btn.state = picture, 0
    local function draw()
        btn.tex = S.Picture(page, btn.tex, "INVENBUT.EPF", 7 * btn.state + btn.picture, "INVENBUT.PAL", l + (page.dx or 0), t,
            "ARTWORK")
    end
    btn.Draw = draw
    btn:SetScript("OnEnter", function() btn.state = 1 draw() end)
    btn:SetScript("OnLeave", function() btn.state = 0 draw() end)
    btn:SetScript("OnMouseDown", function(_, button, double)
        if button ~= "LeftButton" or double then return end
        btn.state = 2
        draw()
        if press then press() end
    end)
    btn:SetScript("OnMouseUp", function() btn.state = btn:IsMouseOver() and 1 or 0 draw() end)
    draw()
    return btn
end

--- 4a's ScrollPane on a page: SLIDEBG.EPF's track (top cap, one-pixel tile, bottom cap) from (l, t) to bottom, SCRBUTT's
--- 38-pixel thumb at the position of first in 0..range; nothing while the list cannot scroll (range 0). bar:Draw(first,
--- range, l, t, b) draws it at the rectangle given (an expanded pane's bar is longer: K.ScrollBar's caller passes it).
-- s6-modular-g round 22: use Hud.Lines' existing track/thumb, claim and capture.
-- WIRE: ScrollInventoryPane::HandlePointerOrMouseEvent (0x00563460), ScrollPane
-- (0x0055C400) and EventDispatcher (0x004A7130) hold every key until release;
-- allowing m through sends 7C. Changing this changes what the server sees.
function K.ScrollBar(page, l, t, b, changed)
    local bar = Hud.Lines(page, b - t, function() end)
    bar.clip:Hide() -- this helper supplies only the bar; the page already draws its list
    -- WIRE: ScrollInventoryPane::BeginPartInteraction (0x005643A0), UpdatePositionFromCursor
    -- (0x00564520), OnTimer (0x00563660): an initial update, then 200 ms and 30 ms ticks.
    -- A thumb keeps the press's offset; a track press keeps its side of the thumb. The vertical
    -- position uses floor((y - offset + 1) * (range + 1) / travel), not Hud's chat-bar rounding.
    -- Changing the position or waits changes the slot subsequently chosen and what the server sees.
    local track, thumb = bar.sf.track, bar.sf.thumb
    local active, offset, nextTick = nil, 0, 0
    local pageUpdated = false
    local function thumbTop() return math.floor(bar.pos * (track:GetHeight() - 38) / bar.range) end
    local function follow()
        if bar.range <= 0 or (active ~= 'thumb' and pageUpdated) then return end
        local _, y = K.PointIn(track)
        local top = thumbTop()
        if active == 'thumb' or (active == 'before' and y < top) or (active == 'after' and y >= top + 38) then
            local travel = track:GetHeight() - 38
            if travel > 0 then bar:SetPos(math.floor(math.max(0, math.min(travel, y - offset + 1)) * (bar.range + 1) / travel)) end
        end
    end
    local function tick()
        if active and GetTime() >= nextTick then follow() nextTick = GetTime() + 0.03 end
    end
    local function begin(onThumb)
        local _, y = K.PointIn(track)
        local top = thumbTop()
        active = onThumb and 'thumb' or (y < top and 'before' or 'after')
        if onThumb then offset = y - top end
        bar.dragging = true
        pageUpdated = false
        follow()
        -- WIRE: GetPartRect (0x005640A0) uses the cursor once m_thumbDragActive is set after
        -- BeginPartInteraction. A page press is then over the thumb, so its later timers change no position.
        -- Further page scrolling would change which slot is chosen and what the server sees.
        pageUpdated = not onThumb
        nextTick = GetTime() + 0.2
        track:SetScript('OnUpdate', tick)
    end
    local function stop()
        active, bar.dragging = nil, false
        track:SetScript('OnUpdate', nil)
    end
    track:SetScript('OnMouseDown', function(_, button) if button == 'LeftButton' then begin(false) end end)
    track:SetScript('OnMouseUp', stop)
    -- Keep the existing pressed-thumb artwork hooks; replace only its generic drag behavior.
    thumb:HookScript('OnMouseDown', function(_, button) if button == 'LeftButton' then begin(true) end end)
    thumb:HookScript('OnMouseUp', stop)
    thumb:SetScript('OnDragStart', nil)
    thumb:SetScript('OnDragStop', nil)
    function bar:Redraw()
        if not self.drawing and self.pos ~= page.first then changed(self.pos) end
    end
    function bar:Draw(first, range, bl, bt, bb)
        self.drawing = true
        self:SetArea((bl or l) - 1, bt or t, bl or l, bb or b)
        self:SetCount(range + self.visible)
        self:SetPos(first)
        self.drawing = false
    end
    return bar
end

--- A look pane's page arrow (UserLookPane's and SelfLookPane's action buttons 2 and 3: GetActionButtonRect 0x005A1A70,
--- GetSlotRect 0x00569ED0): INVENBUT.EPF frame 7 x state + picture (5 back, 6 on; state 0 normal, 1 under the pointer,
--- 2 pressed, which lasts until the pointer moves on), 18 x 18 at the place arrow:Place(l, t) gives it, or none
--- (arrow:Place(nil): 4a's rectangle -1). Its left press (event type 1 only) runs step; local, nothing sent.
function K.Arrow(page, picture, step)
    local btn = CreateFrame("Button", nil, page)
    btn:SetSize(18, 18)
    btn.state = 0
    function btn:Draw()
        if not self.at then return end
        self.tex = S.Picture(page, self.tex, "INVENBUT.EPF", 7 * self.state + picture, "INVENBUT.PAL", self.at[1], self.at[2],
            "ARTWORK")
    end
    function btn:Place(l, t)
        self.at = l and { l, t } or nil
        self:SetShown(l ~= nil)
        if self.tex then self.tex:SetShown(l ~= nil) end
        if l then
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", page, "TOPLEFT", l, -t)
            self:Draw()
        end
    end
    btn:SetScript("OnEnter", function(self) self.state = 1 self:Draw() end)
    btn:SetScript("OnLeave", function(self) self.state = 0 self:Draw() end)
    -- drawn pressed from its press until the pointer moves (the capture beside the original's showed it still pressed
    -- after the release); s6-interface-7x-b round 7 (Astra's P3 of round 5): a move that stays on it draws it under the
    -- pointer again, as 4a's move does (UserLookPane::HandlePointerOrMouseEvent case 0, UserLookPane.cpp:755-775:
    -- ButtonFrame_Hover over the arrow), and leaving it draws it normal (OnLeave)
    btn:SetScript("OnMouseDown", function(self, button, double)
        if button ~= "LeftButton" or double then return end
        self.state = 2
        self.pressX, self.pressY = GetCursorPosition()
        step()
        self:Draw()
    end)
    btn:SetScript("OnUpdate", function(self)
        if self.state ~= 2 then return end
        local x, y = GetCursorPosition()
        if x ~= self.pressX or y ~= self.pressY then
            self.state = 1
            self:Draw()
        end
    end)
    return btn
end

-- ----- 4a's read-only text panes (TextEditPane: the look's more info and profile, the legends) -----

--- The longest start of text that fits width pixels of font 0, broken after a space where there is one (the space
--- dropped), else inside the word; and the rest.
local function fit(text, width)
    local w = S.TextWidth(text)
    if not w or w <= width then return text, "" end
    local n = 1
    while n < #text and (S.TextWidth(text:sub(1, n + 1)) or 0) <= width do n = n + 1 end
    local space = text:sub(1, n + 1):match("^.*() ")
    if space and space > 1 then return text:sub(1, space - 1), text:sub(space + 1) end
    return text:sub(1, n), text:sub(n + 1)
end

--- Appends text's lines to out as 4a's TextEditPane breaks them: at each line break, then wherever a line reaches width
--- pixels; each { text, colour, symbol } (symbol: a SYMBOLS.EPF frame drawn after a space before the first line, as a
--- legend entry's, EPFTextEditObject 0x005955A0: its width taken from that line's room).
function K.Wrap(out, text, width, colour, symbol)
    local indent = symbol and ((S.TextWidth(" ") or 3) + 12) or 0
    for paragraph in ((text or ""):gsub("\r\n?", "\n") .. "\n"):gmatch("(.-)\n") do
        local first, para = true, paragraph
        repeat
            local line
            line, para = fit(para, width - (first and indent or 0))
            out[#out + 1] = { text = line, colour = colour, symbol = first and symbol or nil }
            first = false
        until para == ""
    end
    return out
end

--- A TextEditPane over (l, t)-(r, b) of a page (font 0, 12-pixel lines from its top, read-only), its vertical bar the
--- right 13 pixels (4a's EPF bar, shown only while it can scroll) and the wheel a line a notch: Hud.Lines, whose press
--- routing is 4a's (the bar takes a left press while it can scroll and captures the input until the release; the text
--- takes no press). pane:Set(lines, toEnd) shows K.Wrap's lines from the top, or scrolled to the end (the legends).
function K.TextPane(page, l, t, r, b)
    local pane = { lines = {}, rows = {} }
    -- WIRE (Astra's review of round 5): the pane on a holder of its own, so pane:SetShown hides all of it, its bar's track
    -- and thumb included (they are the text frames' siblings). A pane 4a has taken off the layer in a view
    -- (UserLookPane's and SelfLookPane's views detach theirs) takes no press there; a bar left claiming the left press
    -- would lie over the look's buttons and take the press that sends 4A 00 or 2E.
    local holder = CreateFrame("Frame", nil, page)
    holder:SetAllPoints(page)
    local list
    list = Hud.Lines(holder, 12, function(k, i)
        local row = pane.rows[k]
        if not row then
            row = { text = list.text:CreateFontString(nil, "OVERLAY"), symbol = list.text:CreateTexture(nil, "ARTWORK") }
            pane.rows[k] = row
        end
        row.symbol:Hide()
        local line = i and pane.lines[i]
        if not line then
            row.text:Hide()
            return
        end
        local x = 0
        if line.symbol then
            -- the space, then the 12 x 12 symbol with its top 12 above the line's pen (EPFTextEditObject::Draw)
            x = S.TextWidth(" ") or 3
            S.Picture(list.text, row.symbol, "SYMBOLS.EPF", line.symbol, "BARAM.PAL", x, 12 * k, "ARTWORK")
            x = x + 12
        end
        S.PenText(row.text, list.text, line.text, x, 12 * k + 12, line.colour or S.TEXT)
    end)
    list:SetArea(l, t, r - 13, b)
    pane.list = list
    function pane:Set(lines, toEnd)
        self.lines = lines
        list:SetCount(#lines)
        if toEnd then list:End() else list:SetPos(0) end
    end
    function pane:SetShown(on) holder:SetShown(on) end
    return pane
end

return K
