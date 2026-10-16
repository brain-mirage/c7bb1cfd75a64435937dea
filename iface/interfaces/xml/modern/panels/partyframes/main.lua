-- Party frames (goal 7, head note 4): one small plate per party member, with name, level, health and mana, stacked
-- in the chosen direction. The plates sit in one container frame, so edit mode moves them as a group. The roster
-- comes from GROUP_ROSTER_UPDATE (members joining or leaving, including the party becoming empty), the bars from
-- UNIT_HEALTH and UNIT_POWER for party1..n. s6-ui-core (round 82; the owner, 2026-10-09): the health bars are Modern's
-- vital bars (vitals.lua): the numbers in the player frame's forms, in two rows when one line does not fit; and a
-- hovered spell's healing or damage, as the Library learned it, previewed on the targeted member's bar.
-- s6-ui-core (round 85): the XML twin's scripts; the container and the plates are main.xml's (core/xml.md).

local C = TK.GetComponent("partyframes")
local H = __tk
local U = TK.Util
local E = require("interfaces.modern.elements")
local V = require("interfaces.modern.vitals") -- s6-ui-core (round 82)

-- a plate's sizes (main.xml's)
local SIZES = TK.Xml.Data("main.xml").SIZES
local HEIGHT = SIZES.height
local PORTRAIT = SIZES.portrait
local NAME_TOP, BARS_TOP = SIZES.nameTop, SIZES.barsTop   -- s6-ui-font: below the plate's top
local HP_HEIGHT = SIZES.hp

-- the scripts main.xml names
local scripts = {}

function scripts.HudPanel(p) TK.UI.HudPanel(p, C) end

-- the mana bar's numbers are not shown
function scripts.NoText(mp) mp.text:Hide() end

function scripts.Tip(self)
    if not self.unit then return end
    local ok, name, level, path = H:GetUnitInfo(self.unit)
    if not ok then return end
    local _, hp, hpMax, mp, mpMax = H:GetUnitVitals(self.unit)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(name, 1, 1, 1)
    if (level or 0) > 0 or (path or "") ~= "" then GameTooltip:AddLine(("Level " .. level .. " " .. path):gsub("%s+$", ""), 1, 0.82, 0) end
    GameTooltip:AddLine("Vita " .. U.FormatNumber(hp) .. " / " .. U.FormatNumber(hpMax), 0.4, 1, 0.4)
    GameTooltip:AddLine("Mana " .. U.FormatNumber(mp) .. " / " .. U.FormatNumber(mpMax), 0.5, 0.65, 1)
    GameTooltip:Show()
end

function scripts.Untip() GameTooltip:Hide() end

function scripts.PlayerMenu(p, button)
    if button ~= "RightButton" or not p.unit or p.unit == "player" or not TK.Dialogs then return end
    local _, name = H:GetUnitInfo(p.unit)
    TK.Dialogs.PlayerMenu(H:GetUnitId(p.unit), name)
end

-- the plates, one per member the party can have
function scripts.Plates(f, build)
    C.plates = {}
    for i = 1, C.MAX do
        local p = build:New("Plate", f, "TKPartyMember" .. i)
        p.portrait = p.portraitBox.portrait
        C.plates[i] = p
    end
end

function scripts.PortraitTicker(f)
    f:SetScript("OnUpdate", U.Throttled(0.5, function()
        for unit, p in pairs(C.byUnit or {}) do C:ShowPortrait(p, unit) end
    end))
end

function scripts.Changed(_, event, unit)
    if event == "UNIT_HEALTH" or event == "UNIT_POWER" or event == "UNIT_NAME_UPDATE" then
        local p = C.byUnit and C.byUnit[unit]
        if p then
            C:UpdatePlate(p, unit)
            C:FitRows() -- s6-ui-core (round 82)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        C:ShowPreviews()
    else
        C:Layout()
    end
end

function C:OnEnable()
    local f = TK.Xml.Load("main.xml", { scripts = scripts, elements = E }).frame
    self.frame = f
    TK.Visibility:Attach(f, function() return self:DB() end)
    TK.EditMode:Register(f, "partyframes", "Party Frames", C.defaultPosition, "partyframes")
end

--- The units shown, in order: the player first if chosen, then party1..n, up to Members Shown.
function C:Units()
    local db = self:DB()
    local units = {}
    if db.showPlayer then units[1] = "player" end
    for i = 1, H:GetNumPartyMembers() do units[#units + 1] = "party" .. i end
    while #units > db.maxShown do table.remove(units) end
    return units
end

function C:Layout()
    local db, f = self:DB(), self.frame
    local units = self:Units()
    -- In edit mode an empty party still shows one plate's outline, so the group can be moved.
    local slots = math.max(#units, 1)
    local w, gap = db.width, db.spacing
    -- s6-ui-font: the bars go under the name as measured. Below one screen pixel per font pixel (UI scale 0.9 with
    -- Party Frame Scale 0.5) the classic name is drawn one to one, so it is taller in the plate's units; the bars and
    -- the plate's bottom move down by as much (review r1, P2). At the usual scales the name fits above 21.
    local barsTop = math.max(BARS_TOP, NAME_TOP + self.plates[1].name:GetStringHeight() + 1)
    -- s6-ui-core (round 82): the health bars as tall as two rows of numbers while a member's take two (C:FitRows)
    local hpH = self.hpHeight or HP_HEIGHT
    local plateH = HEIGHT + barsTop - BARS_TOP + hpH - HP_HEIGHT
    local horizontal = db.growth == "RIGHT" or db.growth == "LEFT"
    if horizontal then
        f:SetSize(slots * w + (slots - 1) * gap, plateH)
    else
        f:SetSize(w, slots * plateH + (slots - 1) * gap)
    end
    self.byUnit = {}
    for i, p in ipairs(self.plates) do
        local unit = units[i]
        p.unit = unit -- s6-rules-dialogs: the player menu's member
        p:ClearAllPoints()
        p.hp:SetPoint("TOPLEFT", p, "TOPLEFT", PORTRAIT + 7, -barsTop)   -- s6-ui-font: barsTop
        p.hp:SetPoint("TOPRIGHT", p, "TOPRIGHT", -5, -barsTop)
        p.hp:SetHeight(hpH)
        if unit then
            p:SetSize(w, plateH)
            local k = i - 1
            if db.growth == "DOWN" then p:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -k * (plateH + gap))
            elseif db.growth == "UP" then p:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, k * (plateH + gap))
            elseif db.growth == "RIGHT" then p:SetPoint("TOPLEFT", f, "TOPLEFT", k * (w + gap), 0)
            else p:SetPoint("TOPRIGHT", f, "TOPRIGHT", -k * (w + gap), 0) end
            self.byUnit[unit] = p
            self:UpdatePlate(p, unit)
            p:Show()
        else
            p:Hide()
        end
    end
    self:FitRows()
end

--- s6-ui-core (round 82): the health bars' height for the numbers shown (two rows over the bar when one line does not
--- fit: V.Height), the tallest member's for all; the plates are laid out again when it changes.
function C:FitRows()
    local h = HP_HEIGHT
    for _, p in pairs(self.byUnit or {}) do h = math.max(h, V.Height(p.hp, HP_HEIGHT)) end
    if h ~= (self.hpHeight or HP_HEIGHT) then
        self.hpHeight = h
        self:Layout()
    end
end

function C:UpdatePlate(p, unit)
    local db = self:DB()
    local ok, name, level, path = H:GetUnitInfo(unit)
    if not ok then return end
    p.unit = unit
    local _, hp, hpMax, mp, mpMax = H:GetUnitVitals(unit)
    p.name:SetText(name)
    p.info:SetText(level .. " " .. path)
    V.Set(p.hp, hp, hpMax)
    p.mp:SetMinMaxValues(0, mpMax)
    p.mp:SetValue(mp)
    V.Numbers(p.hp, hp, hpMax, db.showNumbers and db.numberFormat)
    self:ShowPreview(p, unit)
    self:ShowPortrait(p, unit)
end

--- s6-ui-core (round 82; the owner, 2026-10-09): a hovered spell's healing or damage (the Library's, from the player's
--- own casts: V.SpellEffect) on the targeted member's health bar; none on the others. Drawing only.
function C:ShowPreview(p, unit)
    local target = H:GetTargetId()
    local on = self.preview and target ~= 0 and H:GetUnitId(unit) == target
    V.Preview(p.hp, on and self.preview.amount, on and self.preview.kind)
end

--- Every plate's preview again (the hovered spell or the target changed).
function C:ShowPreviews()
    for unit, p in pairs(self.byUnit or {}) do self:ShowPreview(p, unit) end
end

-- s6-ui-core (round 82): the hovered spell (TK.ManaPreview, core/tooltip.lua: its name, nil on leaving)
TK.On("TK_MANA_PREVIEW", function(_, _, name)
    if not C.frame then return end
    local amount, kind = V.SpellEffect(name)
    C.preview = amount and { amount = amount, kind = kind } or nil
    C:ShowPreviews()
end)

--- The member's portrait: its head from the group list (0x63), whole if it fits, else halved; none offline.
function C:ShowPortrait(p, unit)
    local key, w, h = H:GetFigure("member", H:GetUnitId(unit))
    if key == p.portraitKey then return end
    p.portraitKey = key
    p.portrait:SetShown(key ~= "")
    if key == "" then return end
    local scale = (w > PORTRAIT or h > PORTRAIT) and 0.5 or 1
    p.portrait:SetTexture(key)
    p.portrait:SetSize(w * scale, h * scale)
end

function C:ApplySettings()
    -- s6-ui-font: the scale first; the plates' layout measures the name at it (review r1, P2).
    TK.Visibility:Apply(self.frame)
    self:Layout()
end
