-- The minimap's border icons (the owner, 2026-10-02): small icons on the outside of the minimap's box, each at a place
-- on its border, dragged along the border while the layout is unlocked (edit mode) and staying on it, as an addon's
-- minimap buttons move round a minimap. A place is a number going once round the box: 0 to 1 the top edge from left to
-- right, 1 to 2 the right edge downwards, 2 to 3 the bottom edge from right to left, 3 to 4 the left edge upwards. It is
-- saved with the minimap's settings in the profile (the layout), so a profile reset puts the icons back. Where the
-- outside of an edge is off the screen (a box saved against the screen's edge), the icon sits just inside that edge.
--
-- The icons keep clear of each other (round 21): they are placed in their order, each at its place or, where that
-- overlaps one placed before it or is not wholly on the screen, at the nearest free place along the border that is
-- (round 22: an overlap only where no free place is on the screen). A dropped icon alone is placed again, among the
-- others where they are. An icon has one place: one a load had to move is saved where it went.

local U = TK.Util

local B = {}

local GAP = 3     -- between the box and an icon
local SPACE = 2   -- kept between two icons
B.GAP = GAP

--- Where a place puts an item's centre, from the box's bottom-left corner (w x h): on the edge, outside it (or inside).
function B.Point(at, w, h, iw, ih, inside)
    at = at % 4
    local edge, f = math.floor(at), at - math.floor(at)
    local d = inside and -1 or 1
    if edge == 0 then return f * w, h + d * (GAP + ih / 2) end
    if edge == 1 then return w + d * (GAP + iw / 2), h - f * h end
    if edge == 2 then return w - f * w, -d * (GAP + ih / 2) end
    return -d * (GAP + iw / 2), f * h
end

--- The place on the border nearest a point (from the box's bottom-left corner): the edge it is furthest out towards.
function B.Nearest(x, y, w, h)
    local dx, dy = x / w - 0.5, y / h - 0.5
    local clampX, clampY = math.max(0, math.min(1, x / w)), math.max(0, math.min(1, y / h))
    if math.abs(dx) > math.abs(dy) then
        if dx > 0 then return 1 + (1 - clampY) end
        return 3 + clampY
    end
    if dy > 0 then return clampX end
    return 2 + (1 - clampX)
end

--- The edge a place is on: "top", "right", "bottom" or "left".
function B.Edge(at)
    return ({ "top", "right", "bottom", "left" })[math.floor(at % 4) + 1]
end

--- The box's measures for placing its items: its size, and (once laid out) its place on the screen in UIParent units
--- (l, b) with s UIParent units to one of its own, and the screen's size.
function B.Measure(box)
    local w, h = box:GetWidth(), box:GetHeight()
    local l, b, rw = U.RootRect(box)
    return { w = w, h = h, l = l, b = b, s = l and w > 0 and rw / w or nil, sw = GetScreenWidth(), sh = GetScreenHeight() }
end

--- An item's size in its box's units: its own size at its own scale (s6-modular-g, interfaces: each border icon
--- is a panel with its own Scale, 1 by default).
local function size(item)
    local k = item:GetScale()
    return item:GetWidth() * k, item:GetHeight() * k
end

--- Whether an item centred at (cx, cy), half its size (hw, hh), all in UIParent units, crosses the screen's edge
--- beyond the box's edge.
local function offScreen(edge, cx, cy, hw, hh, m)
    if edge == "top" then return cy + hh > m.sh end
    if edge == "right" then return cx + hw > m.sw end
    if edge == "bottom" then return cy - hh < 0 end
    return cx - hw < 0
end

--- Where an item sits at a place: its centre from the box's bottom-left corner, outside the edge or just inside it
--- where outside would be off the screen, and whether it is inside.
local function spot(item, at, m)
    local iw, ih = size(item)
    local x, y = B.Point(at, m.w, m.h, iw, ih)
    if m.s and offScreen(B.Edge(at), m.l + x * m.s, m.b + y * m.s, iw * m.s / 2, ih * m.s / 2, m) then
        x, y = B.Point(at, m.w, m.h, iw, ih, true)
        return x, y, true
    end
    return x, y, false
end

--- The room an item takes at a place: { left, bottom, right, top } in the box's units, with what it keeps beside it
--- (item.footprint: the time's zone name).
local function room(item, at, m)
    local x, y, inside = spot(item, at, m)
    local iw, ih = size(item)
    local hw, hh = iw / 2, ih / 2
    local l, b, r, t = x - hw, y - hh, x + hw, y + hh
    if item.footprint then l, b, r, t = item.footprint(at, inside, l, b, r, t, m) end
    return { l, b, r, t }
end

local function overlaps(p, q)
    return p[1] < q[3] + SPACE and q[1] < p[3] + SPACE and p[2] < q[4] + SPACE and q[2] < p[4] + SPACE
end

--- Whether an item at a place is wholly on the screen (yes before the box is laid out).
local function onScreen(item, at, m)
    if not m.s then return true end
    local x, y = spot(item, at, m)
    local iw, ih = size(item)
    local cx, cy, hw, hh = m.l + x * m.s, m.b + y * m.s, iw * m.s / 2, ih * m.s / 2
    return cx - hw >= 0 and cy - hh >= 0 and cx + hw <= m.sw and cy + hh <= m.sh
end

--- The place nearest a wanted one along the border (in steps of about one unit of the box) that is on the screen and
--- clear of the rooms taken; else the nearest on the screen; else the wanted one.
local function nearestFree(item, want, taken, m)
    local step = 1 / math.max(m.w, m.h, 1)
    local visible
    for i = 0, math.ceil(2 / step) do
        for sign = 1, i == 0 and 1 or 2 do
            local at = (want + (sign == 1 and i or -i) * step) % 4
            if onScreen(item, at, m) then
                visible = visible or at
                local r, free = room(item, at, m), true
                for _, t in ipairs(taken) do
                    if overlaps(r, t) then free = false break end
                end
                if free then return at end
            end
        end
    end
    return visible or want % 4
end

-- Unlocked, every frame's mover covers it (the world view's the whole screen): the item goes above them, to be dragged
-- (the one being dragged above the other icons).
local function raise(item, up)
    item.raised = up
    local box = item:GetParent()
    if up then
        item:SetFrameStrata("HIGH")
        item:SetFrameLevel(60)
    else
        item:SetFrameStrata(box:GetFrameStrata())
        item:SetFrameLevel(box:GetFrameLevel() + 6)
    end
end

--- Makes an item on the box frame (box.borderItems keeps them in their order): a frame of its own that keeps its place
--- in db[key] (default def) and is dragged along the border in edit mode. onPointer(item, down, button) gets the
--- presses and releases outside edit mode.
function B.New(box, name, key, def, db, onPointer)
    local item = CreateFrame("Frame", name, box)
    item.key, item.default, item.db = key, def, db
    box.borderItems = box.borderItems or {}
    box.borderItems[#box.borderItems + 1] = item
    item:SetFrameLevel(box:GetFrameLevel() + 6)
    item:EnableMouse(true)
    item:SetScript("OnMouseDown", function(self, button)
        if TK.EditMode.unlocked then
            if button == "LeftButton" then
                self.dragging = true
                self:SetFrameLevel(61)
            end
        elseif onPointer then
            onPointer(self, true, button)
        end
    end)
    item:SetScript("OnMouseUp", function(self, button)
        if self.dragging then
            self.dragging = false
            self:SetFrameLevel(60)
            -- Dropped: placed again among the others where they are; the free place it gets is saved.
            B.Arrange(box, self)
        elseif onPointer then
            onPointer(self, false, button)
        end
    end)
    item:SetScript("OnUpdate", function(self)
        if self.raised ~= TK.EditMode.unlocked then raise(self, TK.EditMode.unlocked) end
        if not self.dragging then return end
        local x, y = U.CursorRoot()
        local l, b, w, h = U.RootRect(box)
        if l then B.Place(self, B.Nearest(x - l, y - b, w, h)) end
    end)
    return item
end

--- Puts an item at a place on its box's border: outside it, or just inside where outside would be off the screen. Its
--- offset is in its own units, so at its own scale it is divided by that scale.
function B.Place(item, at, m)
    m = m or B.Measure(item:GetParent())
    item.at = at % 4
    local x, y, inside = spot(item, item.at, m)
    item.inside = inside
    item:ClearAllPoints()
    local k = item:GetScale()
    item:SetPoint("CENTER", item:GetParent(), "BOTTOMLEFT", x / k, y / k)
end

--- Places a box's items in their order, each at its place or the nearest free one on the screen; or, with dropped, only
--- that one among the others where they are. A place that moved is saved: an icon has one place. The rooms the box keeps
--- for itself (box.reserved(m): the minimap's location label, s6-ui-core round 37) are taken first. An item turned off
--- (item.off: s6-modular-g, interfaces: its panel's switch) takes no room and keeps its saved place.
function B.Arrange(box, dropped)
    local m = B.Measure(box)
    local taken = box.reserved and box.reserved(m) or {}
    for _, item in ipairs(box.borderItems or {}) do
        if item ~= dropped and not item.off then
            if not dropped then B.Place(item, nearestFree(item, item.at or item.default, taken, m), m) end
            taken[#taken + 1] = room(item, item.at, m)
        end
    end
    if dropped then B.Place(dropped, nearestFree(dropped, dropped.at, taken, m), m) end
    for _, item in ipairs(box.borderItems or {}) do
        local d = item.db()
        if not item.off and (tonumber(d[item.key]) or item.default) ~= item.at then
            d[item.key] = item.at
            TK.DB:MarkDirty()
        end
    end
end

--- An item's place from the saved layout (or its default); B.Arrange puts it there, or beside where taken.
function B.Restore(item)
    item.at = tonumber(item.db()[item.key]) or item.default
end

return B
