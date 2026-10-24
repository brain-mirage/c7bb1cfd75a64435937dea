-- Nameplates (plan 5.11; K-076, O-07, O-22, O-23): the names over the figures the world view draws, from the drawing
-- (__tk:GetNameplate), as the original's ObjectInfoObjectPane draws them (ObjectPane.cpp:1142-1170): outlined in the
-- back colour one pixel around; with the carnage dye in the status's two colours with a bordered box under the name;
-- none while the figure's balloon shows. With Display names off only the figures whose name follows the pointer (info
-- types 1-3) show anything: a small down arrow, or the name once the pointer is on a human's figure (MapPane.cpp:1706),
-- 20 pixels lower and in the normal colours. N (none, Ctrl or Alt; not Shift, MapPane.cpp:1420) turns the names on or
-- off: Display names is the game layer's global setting (TK.Game.Options.ShowNames, core/game/options.lua; s6-play-modes
-- round 8, W6), which the drawing's own names follow too. Group members get their HP and MP bars from what the server
-- sends (0x63), speaking or not, at the bars' own place over the figure (not the name's); the drawing leaves their
-- ordinary hit bars out meanwhile, as the original. Local display only: nothing is sent.
-- s6-ui-core (round 82; the owner, 2026-10-09): the Nameplates pane is what is drawn over others; its health bars over
-- players and NPCs are bars.lua's.
-- s6-ui-core (round 85): the XML twin's scripts; the layer and the plates are main.xml's (core/xml.md).

local C = TK.GetComponent("nameplates")
local H = __tk
local U = TK.Util
require("interfaces.modern.panels.nameplates.bars") -- s6-ui-core (round 82): C:RefreshBars

C.pool = {}

-- DrawOutlinedTextAt: the text in the back colour one pixel up, down, left and right, then in the text colour.
local AROUND = { { 0, 1 }, { 0, -1 }, { -1, 0 }, { 1, 0 } }

-- The font's 0x1F (BARAM00.EFT): a down arrow, 5, 3 and 1 pixels wide, three rows each (from its top); a plate has
-- 5 x 3 rectangles for it (main.xml's Plate).
local ARROW = { { -2, 5 }, { -1, 3 }, { 0, 1 } }

local function rgb(c)
    return math.floor(c / 65536) % 256 / 255, math.floor(c / 256) % 256 / 255, c % 256 / 255
end

local ui -- main.xml's build (C:OnEnable)

local function plate(i)
    local p = C.pool[i]
    if p then return p end
    p = ui:New("Plate", C.frame, "TKNameplate" .. i)
    C.pool[i] = p
    C:Style(p)
    return p
end

--- The text size (the original's font is drawn one to one at 12).
function C:Style(p)
    local size = self:DB().size
    for _, fs in ipairs(p.back) do fs:SetFont("classic", size, "") end
    p.name:SetFont("classic", size, "")
    p.shown = nil
end

function C:SetName(p, text, colour, outline)
    local k = self:DB().size / 12
    if p.shown ~= text then
        p.name:SetText(text)
        for _, fs in ipairs(p.back) do fs:SetText(text) end
        p.shown = text
    end
    if p.k ~= k then
        p.name:ClearAllPoints()
        p.name:SetPoint("BOTTOM", p, "BOTTOM", 0, 0)
        for j, fs in ipairs(p.back) do
            fs:ClearAllPoints()
            fs:SetPoint("BOTTOM", p, "BOTTOM", AROUND[j][1] * k, AROUND[j][2] * k)
        end
        p.k = k
    end
    if p.colour ~= colour or p.outline ~= outline then
        p.name:SetTextColor(rgb(colour))
        local r, g, b = rgb(outline)
        for _, fs in ipairs(p.back) do fs:SetTextColor(r, g, b) end
        p.colour, p.outline = colour, outline
    end
end

-- A plate is this component's own: it keeps what it shows (nameOn, boxOn, arrowOn, barsOn, visible and where it is
-- anchored), so a frame where nothing changed sets nothing again.

function C:ShowName(p, on)
    if p.nameOn == on then return end
    p.nameOn = on
    p.name:SetShown(on)
    for _, fs in ipairs(p.back) do fs:SetShown(on) end
end

function C:SetBoxShown(p, on)
    if p.boxOn == on then return end
    p.boxOn = on
    p.box:SetShown(on)
    p.boxInside:SetShown(on)
end

--- ObjectPane.cpp:1142: the box under the name, (middle - 5, 2 pixels below the text) to (middle + 7, 12 below).
function C:ShowBox(p, fill, inside)
    local k = self:DB().size / 12
    p.box:ClearAllPoints()
    p.box:SetSize(12 * k, 10 * k)
    p.box:SetPoint("TOP", p, "BOTTOM", k, -2 * k)
    p.box:SetColorTexture(rgb(fill))
    p.boxInside:ClearAllPoints()
    p.boxInside:SetSize(10 * k, 8 * k)
    p.boxInside:SetPoint("CENTER", p.box, "CENTER", 0, 0)
    p.boxInside:SetColorTexture(rgb(inside))
end

--- The font's 0x1F at the text's place, in the text colour on the back colour.
function C:ShowArrow(p, on, colour, outline)
    local k = self:DB().size / 12
    if p.arrowOn == on and (not on or p.arrowK == k and p.arrowColour == colour and p.arrowOutline == outline) then return end
    p.arrowOn, p.arrowK, p.arrowColour, p.arrowOutline = on, k, colour, outline
    local n = #ARROW
    for j = 1, 5 do
        local dx, dy = 0, 0
        if j <= 4 then dx, dy = AROUND[j][1], AROUND[j][2] end
        for row, r in ipairs(ARROW) do
            local t = p.arrow[(j - 1) * n + row]
            t:SetShown(on)
            if on then
                t:ClearAllPoints()
                t:SetSize(r[2] * k, 3 * k)
                -- rows from the top: the glyph's bottom 2 pixels above the text's bottom
                t:SetPoint("BOTTOM", p, "BOTTOM", dx * k, (2 + 3 * (n - row) + dy) * k)
                t:SetColorTexture(rgb(j <= 4 and outline or colour))
            end
        end
    end
end

--- The figure under the mouse (the drawing's pick), or 0.
function C:Hovered(view)
    local x, y = view:CentrePoint() -- s6-world-view (round 31): the logic's map point
    return x and H:GetFigureAt(x, y) or 0
end

--- With the names on, whose name shows: everyone, the one under the mouse or the target.
function C:Wanted(id, hover, target)
    local show = self:DB().show
    if show == "hover" then return id == hover end
    if show == "target" then return id == target end
    return true
end

--- The group members' units by object id ("party1".."partyN", 0x63's numbers), and their ids in the group list's order.
--- s6-optimize (round 10): a member's HP and MP are read where its bars are drawn (PlaceBars), not every member's every
--- frame; a member is a unit with an id (GetUnitId is 0 exactly when GetUnitVitals has no unit). s6-ui-core (round 83;
--- the head's review of round 82): one list a frame, for the group bars (C:Party) and the bars over heads (RefreshBars).
function C:Members()
    local units, ids = {}, {}
    for i = 1, H:GetNumPartyMembers() do
        local unit = "party" .. i
        local id = H:GetUnitId(unit)
        if id ~= 0 then
            units[id] = unit
            ids[#ids + 1] = string.format("%d", id)
        end
    end
    return units, ids
end

--- The members who have the group bars (C:Members()'s, none while the bars are off); tells the drawing who they are.
function C:Party(units, ids)
    if not self:DB().groupBars then units, ids = {}, {} end
    self:SetGroupBarMembers(table.concat(ids, ","))
    return units
end

function C:SetGroupBarMembers(ids)
    if ids ~= self.groupIds then
        H:SetGroupBarMembers(ids)
        self.groupIds = ids
    end
end

--- MapPane::ApplyHitBarObjectPane: a percentage (large values divide by the maximum's hundredth).
local function percent(value, maximum)
    if maximum <= 0 then return 0 end
    if value >= 10000000 then return math.floor(value / math.max(1, math.floor(maximum / 100))) end
    return math.floor(value * 100 / maximum)
end

--- HitBarObjectPane::RenderFrame's fill: 58 pixels at 100.
local function filled(value, maximum)
    return math.max(0, math.min(58, math.floor(58 * percent(value, maximum) / 100)))
end

--- A rectangle of the world picture (pixels from its centre, y down) cut to the view (half size hw x hh), as the map
--- draws a pane that meets the exposed area clipped to it (MapPane.cpp:2268, :3411). False when nothing is left.
function C:Piece(t, view, x, y, w, h, scale, hw, hh)
    local left, right = math.max(x, -hw), math.min(x + w, hw)
    local top, bottom = math.max(y, -hh), math.min(y + h, hh)
    if right <= left or bottom <= top then
        t:Hide()
        return false
    end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", view.frame, "CENTER", left * scale, -top * scale)
    t:SetSize((right - left) * scale, (bottom - top) * scale)
    t:Show()
    return true
end

--- A palette entry's colour, once.
local palette = {}
local function paletteColour(index)
    if not palette[index] then palette[index] = H:GetPaletteColour(index) end
    return palette[index]
end

--- s6-modular-d (Retro rule 17, rounds 8-9): the bars' 60 x 19 box with its top left at (x, y) at the interface's size
--- whatever the world's scale (view.scale), the box's centre where the scaled figure puts it, as the 2026 client shrinks a
--- box about its centre: its top left and one of its pixels, in picture pixels (at 1x the box itself).
local function barBox(view, x, y)
    local k = 1 / (view.scale or 1)
    return x + 30 - 30 * k, y + 9.5 - 9.5 * k, k
end

--- The bars with their top left at (x, y): the box, the HP fill (1, 1) and the MP fill (1, 10), 8 high. The map draws
--- them in its draw mode 2, half over what is below (FillRgb565RectCallback, the port's alpha 0.5): the box in colour
--- 0x80, the HP fill in 248 below 15 pixels, 251 below 29 and 10 from there, the MP fill in 9. unit: the member's (C:Party).
function C:PlaceBars(p, view, x, y, scale, hw, hh, outline, unit)
    local _, health, maxHealth, mana, maxMana = H:GetUnitVitals(unit)
    local hp, mp = filled(health, maxHealth), filled(mana, maxMana)
    local r, g, b = rgb(outline)
    p.bars:SetColorTexture(r, g, b, 0.5)
    p.hpIndex = hp < 15 and 248 or hp < 29 and 251 or 10
    r, g, b = rgb(paletteColour(p.hpIndex))
    p.hp:SetColorTexture(r, g, b, 0.5)
    r, g, b = rgb(paletteColour(9))
    p.mp:SetColorTexture(r, g, b, 0.5)
    local left, top, k = barBox(view, x, y) -- s6-modular-d (rule 17)
    self:Piece(p.bars, view, left, top, 60 * k, 19 * k, scale, hw, hh)
    self:Piece(p.hp, view, left + k, top + k, hp * k, 8 * k, scale, hw, hh)
    self:Piece(p.mp, view, left + k, top + 10 * k, mp * k, 8 * k, scale, hw, hh)
    p.barsOn = true
end

function C:HideBars(p)
    if p.barsOn == false then return end
    p.barsOn = false
    p.bars:Hide()
    p.hp:Hide()
    p.mp:Hide()
end

--- Shows or hides a whole plate.
local function showPlate(p, on)
    if p.visible == on then return end
    p.visible = on
    p:SetShown(on)
end

function C:Refresh()
    local db, view = self:DB(), TK.GetComponent("worldview")
    local live = db.enabled and view ~= nil and view.frame ~= nil and view.frame:IsVisible()
    H:SetNamesShownElsewhere(live)
    -- s6-ui-core (round 82): which floating numbers the drawing draws (Players' and NPCs' pages; both with the pane off),
    -- under the original's Show Damage; every frame, as the drawing's own switch may come and go with the world view
    H:SetDamageNumbersShown(not db.enabled or db.playerFloating ~= false, not db.enabled or db.npcFloating ~= false)
    local used = 0
    if live then
        local scale = view:TileSize() / 48
        local _, _, w, h = U.RootRect(view.frame)
        local members, memberIds = self:Members() -- s6-ui-core (round 83)
        local hover, target, party = self:Hovered(view), H:GetTargetId(), self:Party(members, memberIds) -- s6-world-view (round 31)
        local showNames = TK.Game.Options.ShowNames()
        for i = 1, H:GetNumNameplates() do
            local _, id, name, x, y, colour, outline, carnage, carnageOutline, offY, speaking, tracks, human, barX, barY =
                H:GetNameplate(i)
            local member = party[id]
            local text, arrow, box, ty, fg, bg = nil, false, false, y, colour, outline
            if speaking then
                -- ObjectInfoObjectPane::RenderFrame draws nothing under a balloon; the bars stay.
            elseif showNames then
                if name ~= "" and self:Wanted(id, hover, target) then
                    text = name
                    if db.carnage and carnage >= 0 then fg, bg, box = carnage, carnageOutline, true end
                end
            elseif tracks then
                ty = offY
                if id == hover and human then text = name else arrow = true end
            end
            -- The name by its place; the bars by their own 60 x 19 rectangle meeting the view, cut to it.
            local hw, hh = w / 2 / scale, h / 2 / scale
            local nameIn = (text ~= nil or arrow) and math.abs(x) <= hw and math.abs(ty) <= hh
            local bl, bt, bk = barBox(view, barX, barY) -- s6-modular-d (rule 17): the box as PlaceBars draws it
            local barsIn = member ~= nil and bl < hw and bl + 60 * bk > -hw and bt < hh and bt + 19 * bk > -hh
            if nameIn or barsIn then
                used = used + 1
                local p = plate(used)
                local px, py = x * scale, -ty * scale
                if p.anchor ~= view.frame or p.px ~= px or p.py ~= py then
                    p:ClearAllPoints()
                    p:SetPoint("BOTTOM", view.frame, "CENTER", px, py)
                    p.anchor, p.px, p.py = view.frame, px, py
                end
                p.id = id
                if not nameIn then text, arrow, box = nil, false, false end
                if text then self:SetName(p, text, fg, bg) end
                self:ShowName(p, text ~= nil)
                self:SetBoxShown(p, box)
                if box then self:ShowBox(p, carnageOutline, carnage) end
                self:ShowArrow(p, arrow, colour, outline)
                if barsIn then
                    self:PlaceBars(p, view, barX, barY, scale, hw, hh, outline, member)
                else
                    self:HideBars(p)
                end
                showPlate(p, true)
            end
        end
        self:RefreshBars(view, scale, w, h, hover, target, members) -- s6-ui-core (round 82; round 83: the same members)
    else
        self:SetGroupBarMembers("")
        self:RefreshBars(nil)
    end
    for i = used + 1, #self.pool do showPlate(self.pool[i], false) end
end

-- the scripts main.xml names
local scripts = {}

function scripts.Refresh() TK.SafeCall(C.Refresh, C) end

function C:OnEnable()
    ui = TK.Xml.Load("main.xml", { scripts = scripts, elements = require("interfaces.modern.elements") })
    self.frame = ui.frame
    TK.Visibility:Attach(self.frame, function() return self:DB() end)
end

function C:ApplySettings()
    local db = self:DB()
    for _, p in ipairs(self.pool) do self:Style(p) end
    -- Hidden, the component shows nothing: the drawing draws its own names and hit bars again.
    if not db.enabled then
        H:SetNamesShownElsewhere(false)
        self:SetGroupBarMembers("")
        H:SetDamageNumbersShown(true, true) -- s6-ui-core (round 82): every floating number again, as the original
    end
    TK.Visibility:Apply(self.frame)
end
