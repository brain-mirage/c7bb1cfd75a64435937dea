-- s6-interface-5x-b (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md): 5.33's parcel icons,
-- ParcelIconPane (constructor 0x0048CF50) and the ParcelPane it keeps at (45, 371) of the 640 x 480 screen, beside the
-- clock. The counts are 0x08's parcel byte, the parcels its low nibble and the letters its high one
-- (ParcelIconPane_UpdateParcelCounts 0x0048D260), as the dialog model's ParcelPane keeps them (7.5.2's, D-76).
--
-- Its paint (0x0048D5D0): the pane, (45, 371)-(56 + 11 n, 389) for n waiting (100 from four), filled with colour 0,
-- which shows the frame's bar under it (s6-ui-core round 86: colour 0 is 0x0000, 5.33's colour key, and the pane is keyed,
-- mode 1; W:/5-3-client-source/documentation/interface/black-boxes.md: round 16's black was that key reaching the
-- screen, so nothing is drawn for it here); a parcel's picture (PARCEL.EPF frame 1, 19 x 19) for each parcel from its
-- left, 11 pixels apart, then a letter's (MAIL.EPF frame 1, 18 x 18) for each letter, four in all at most. When the waiting grow, a parcel's or a letter's big picture
-- (frame 0, 22 x 22) flies from the map's top right to the pane first, 11 pixels left and down every 10 ms for 34 steps
-- (0x0048DA90, 0x0048DB60), and the pane shows the new count when it lands; when they shrink, at once.
--
-- Input: 5.33's pane acts on a release anywhere on it, the parcels first (0x0048D730: 41 while there are parcels, the
-- mail's BulletinSession while there are letters). 5.x is a look over 7.5.2: each icon here is the control of 7.5.2's
-- ParcelPane for its kind, through the game layer's one press path as the minimap's icons are (TK.Game.Parcels.Wire:
-- s6-input round 49, separation step 4b; a press to the icon's control, its release to the control under the pointer
-- then): a parcel's icon is 7.5.2's parcel button (0), a
-- letter's its letter button (1), so each sends what that button sends (ParcelPane::HandlePointerOrMouseEvent
-- 0x00546610, ParcelPane.cpp:207). Changing the controls' indexes or this routing changes what the server sees.

local C = TK.GetComponent("5x.parcel")
local S = require("interfaces.5x.skin")
local Screen = require("interfaces.screen")

local PLACE = { 45, 371 }
local MAX = 4
local STEPS, STEP = 34, 0.01

--- The waiting parcels and letters (the model's pane: 0 the parcels, 1 the letters; TK.Game.Parcels, s6-input round 49).
function C:Counts()
    return (TK.Game.Parcels.Count(0)), (TK.Game.Parcels.Count(1))
end

--- The pane for parcels and letters: the icons, each the control of its kind.
function C:Draw(parcels, letters)
    local f = self.frame
    local n = math.min(MAX, parcels + letters)
    for i = 1, MAX do
        local icon = f.icons[i]
        local kind
        if i <= parcels then kind = 0 elseif i <= n then kind = 1 end
        if kind then
            -- the frame's drawn rectangle at the icon's place (RenderTileFrame into (11 i, 0)-(11 i + 19, 19))
            local key, w, h = S.Image(kind == 0 and "PARCEL.EPF" or "MAIL.EPF", 1)
            if key then
                local ox, oy = TK.Art.Origin(key)
                icon.tex:SetTexture(key)
                icon.tex:SetSize(w, h)
                icon.tex:ClearAllPoints()
                icon.tex:SetPoint("TOPLEFT", icon, "TOPLEFT", ox, -oy)
                icon.tex:Show()
            else
                icon.tex:Hide()
            end
            icon:SetSize(kind == 0 and 19 or 18, kind == 0 and 19 or 18)
            TK.Game.Parcels.Control(icon, kind) -- wire: its kind is its control (OnEnable wires it)
            icon:Show()
        else
            icon:Hide()
        end
    end
    self.drawn = { parcels, letters }
end

--- A flight of the big picture (frame 0 of the parcel's or the letter's) for total waiting, from (397 + 11 total, 4), or
--- from (441, 4) beyond four, 11 left and 11 down a step (0x0048DB60's places).
function C:Fly(total, parcel)
    local f = self.frame
    local key, w, h = S.Image(parcel and "PARCEL.EPF" or "MAIL.EPF", 0)
    if not key then return false end
    f.flight = { total = total, step = 0, wait = STEP, key = key }
    f.flyer:SetTexture(key)
    f.flyer:SetSize(w, h)
    self:PlaceFlyer()
    f.flyer:Show()
    return true
end

--- The flyer at its step's place on the screen (its parent is the pane's: the pane's place subtracted).
function C:PlaceFlyer()
    local f = self.frame
    local t = f.flight
    local x, y
    if t.total <= MAX then x, y = 397 + 11 * (t.total - t.step), 4 + 11 * t.step
    else x, y = 441 - 11 * t.step, 4 + 11 * t.step end
    local ox, oy = TK.Art.Origin(t.key)
    f.flyer:ClearAllPoints()
    f.flyer:SetPoint("TOPLEFT", f, "TOPLEFT", x - PLACE[1] + ox, -(y - PLACE[2] + oy))
end

--- The counts now: more waiting fly in first (the parcels' picture when the parcels grew, the letters' otherwise); fewer
--- show at once (ParcelIconPane_UpdateParcelCounts).
function C:Update(elapsed)
    local f = self.frame
    local t = f.flight
    if t then
        t.wait = t.wait - (elapsed or 0)
        while t.wait <= 0 and f.flight do
            t.wait = t.wait + STEP
            t.step = t.step + 1
            if t.step >= STEPS then
                f.flight = nil
                f.flyer:Hide()
                self:Draw(self:Counts())
            else
                self:PlaceFlyer()
            end
        end
        return
    end
    local parcels, letters = self:Counts()
    local was = self.drawn or { 0, 0 }
    if parcels == was[1] and letters == was[2] then return end
    local total, before = parcels + letters, was[1] + was[2]
    if total >= before and (parcels > was[1] or letters > was[2]) and self:Fly(total, parcels > was[1]) then
        self.drawn = { parcels, letters } -- the pane keeps the old picture until the flight lands
        return
    end
    self:Draw(parcels, letters)
end

function C:OnEnable()
    local f = CreateFrame("Frame", "TK5xParcel", UIParent)
    f:SetFrameStrata("LOW")
    f:SetSize(55, 18)
    f.icons = {}
    for i = 1, MAX do
        local icon = CreateFrame("Frame", "TK5xParcelIcon" .. i, f)
        icon:SetPoint("TOPLEFT", f, "TOPLEFT", 11 * (i - 1), 0)
        icon:SetFrameLevel(f:GetFrameLevel() + i)
        icon:EnableMouse(true)
        icon.tex = icon:CreateTexture(nil, "ARTWORK")
        -- Wire: the icon's kind's control of 7.5.2's ParcelPane (0 parcels, 1 letters), given as it draws (C:Draw): the
        -- press to it, the release to the control under the pointer then (TK.Game.Parcels.Wire, ParcelPane::
        -- HandlePointerOrMouseEvent 0x00546610, ParcelPane.cpp:207); none before its first kind. Changing it changes what
        -- is sent.
        TK.Game.Parcels.Wire(icon, nil)
        icon:Hide()
        f.icons[i] = icon
    end
    -- the flying picture, above the screen's panes and the map view (FlyingParcelPane on a layer of its own)
    f.flight = nil
    local layer = CreateFrame("Frame", nil, f)
    layer:SetFrameStrata("MEDIUM")
    layer:SetAllPoints(f)
    f.flyer = layer:CreateTexture(nil, "OVERLAY")
    f.flyer:Hide()
    f:SetScript("OnUpdate", function(_, elapsed) self:Update(elapsed) end)
    f:Hide()
    self:Own(f)
    self.frame = f
    self.entry = Screen.Register(f, "5x.parcel", "5.x Parcels", function() return self:DB().enabled == true end)
    self:Draw(0, 0)
end

--- At 5.33's place on the scaled 5.x screen unless moved, at the screen's scale times its own; in the game only.
function C:ApplySettings() Screen.PlacePanel(self, S.WIDTH, S.HEIGHT, PLACE[1], PLACE[2]) end

Screen.Follow(C, "ApplySettings")
