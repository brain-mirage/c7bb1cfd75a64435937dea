-- The player frame: a portrait placeholder, name, level and path, health and mana bars (numbers optional), and an
-- optional experience bar. It reads the world (the session's, or Play Offline's mock) through UnitHealth-style calls and
-- updates on events. s6-ui-core (round 82; the owner, 2026-10-09): the bars are Modern's vital bars (vitals.lua): the
-- numbers in two rows when one line does not fit, the damage taken (a switch), and a hovered spell's cost marked by a
-- small red triangle under the mana bar (under the health bar for a spell that costs health).

local C = TK.GetComponent("playerframe")
local H = __tk
local U = TK.Util
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local Portrait = require("interfaces.modern.portrait") -- the portrait the target frame has too (s6-optimize round 52)
local V = require("interfaces.modern.vitals") -- s6-ui-core (round 82)

local PORTRAIT = 56
-- s6-ui-core (round 82; the owner, 2026-10-09): the health and mana bars a little taller, filling the room the experience
-- bar left when it moved under the portrait
local HP_HEIGHT, MP_HEIGHT, XP_HEIGHT = 19, 14, 7

local function bar(parent, height, r, g, b) return V.Bar(parent, height, r, g, b, 11) end

--- s6-ui-core (round 82; the owner: "hovering the XP bar shows the experience held, what the level needs and the
--- percentage"): the experience lines of the player frame's and its experience bar's tooltips. Online the server sends
--- the experience held and the bar's percentage (0x08), not what the level needs (the xpbar panel's rule); Play Offline's
--- mock has both numbers of the level.
local function xpLines()
    local _, xp, xpMax = H:GetPlayerXP()
    local pct = xpMax > 0 and xp / xpMax * 100 or 0
    if H:IsOnline() then
        return { "Experience: " .. U.FormatNumber(H:GetExperience()), string.format("Progress: %d%%", math.floor(pct + 0.5)) }
    end
    return { "Experience: " .. U.FormatNumber(xp), "Level needs: " .. U.FormatNumber(xpMax),
             string.format("Progress: %.1f%%", pct) }
end

function C:OnEnable()
    local f = CreateFrame("Frame", "TKPlayerFrame", UIParent)
    f:SetBackdrop({ bg = { 0.04, 0.04, 0.05, 0.85 }, edge = { 0.55, 0.55, 0.58, 1 } })
    TK.UI.HudPanel(f, C) -- s6-ui-settings (round 4): the shared panel style; s6-ui-core (round 53): or its own
    self.frame = f

    -- s6-characters seam (the owner, 2026-10-01): the character's portrait over the disc, under the ring: its figure's upper
    -- body, or its profile image (ShowPortrait); the name's letter while there is neither (Modern's portrait.lua).
    local portrait = Portrait.New(f, PORTRAIT, "TOPLEFT", 8, -8, 0.25, 0.35, 0.8)
    local levelBadge = CreateFrame("Frame", nil, portrait)
    levelBadge:SetSize(26, 18)
    levelBadge:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", 6, -4)
    levelBadge:SetBackdrop({ bg = { 0.1, 0.08, 0.02, 0.95 }, edge = { 0.85, 0.75, 0.45, 1 } })
    levelBadge:SetFrameLevel(portrait:GetFrameLevel() + 2)
    f.level = W.Label(levelBadge, "", 11, W.gold)
    f.level:SetPoint("CENTER", levelBadge, "CENTER", 0, 0)
    f.portrait = portrait

    f.name = W.Label(f, "", 14, W.white, "LEFT")
    f.name:SetFont("classic", 12, "")   -- names in the original's own font
    f.path = W.Label(f, "", 11, { 0.7, 0.7, 0.75 }, "RIGHT")
    f.hp = bar(f, HP_HEIGHT, 0.15, 0.75, 0.15)
    f.mp = bar(f, MP_HEIGHT, 0.2, 0.45, 0.95)
    -- The mana-cost preview (plan 5.11): over the mana bar, yellow for the mana a hovered spell would use and red for
    -- the shortfall beyond the mana there is.
    f.mp.costYellow = f.mp:CreateTexture(nil, "OVERLAY")
    f.mp.costYellow:SetColorTexture(1, 0.85, 0.15, 0.85)
    f.mp.costRed = f.mp:CreateTexture(nil, "OVERLAY")
    f.mp.costRed:SetColorTexture(0.95, 0.15, 0.1, 0.85)
    f.mp.costYellow:Hide()
    f.mp.costRed:Hide()
    f.xp = bar(f, XP_HEIGHT, 0.6, 0.25, 0.85)
    f.xp.text:SetFont(9, "OUTLINE")
    f.xp:EnableMouse(true)
    f.xp:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
        for _, line in ipairs(xpLines()) do GameTooltip:AddLine(line, 0.8, 0.6, 1) end
        GameTooltip:Show()
    end)
    f.xp:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f:RegisterEvent("UNIT_HEALTH")
    f:RegisterEvent("UNIT_POWER")
    f:RegisterEvent("PLAYER_XP_UPDATE")
    f:RegisterEvent("UNIT_NAME_UPDATE")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("UNIT_PORTRAIT_UPDATE")   -- s6-characters' (round 36): its pictures of the player changed
    -- s6-ui-core (after build 41; s6-optimize's audit): the player chose their own picture (core/profilepicture.lua's Save)
    -- to be their portrait, so its switch goes on and the portrait shows it.
    TK.On("TK_PROFILE_PICTURE_SAVED", function()
        if not self:DB().useProfileImage then
            self:DB().useProfileImage = true
            TK.DB:MarkDirty()
        end
        self:ShowPortrait()
    end)
    f:SetScript("OnEvent", function(_, event, unit)
        if unit and unit ~= "player" then return end
        -- s6-ui-core (round 33, the owner): the portrait is held until the look or the gear changes (UNIT_PORTRAIT_UPDATE)
        -- or the character's name does; it was asked for twice a second.
        if event == "UNIT_PORTRAIT_UPDATE" then return self:ShowPortrait() end
        self:Update()
        if event == "UNIT_NAME_UPDATE" or event == "PLAYER_ENTERING_WORLD" then self:ShowPortrait() end
    end)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
        local _, name, level, path = H:GetUnitInfo("player")
        GameTooltip:AddLine(name, 1, 1, 1)
        GameTooltip:AddLine("Level " .. level .. (path ~= "" and (" " .. path) or ""), 1, 0.82, 0)
        for _, line in ipairs(xpLines()) do GameTooltip:AddLine(line, 0.8, 0.6, 1) end
        GameTooltip:AddLine("Gold " .. U.FormatNumber(H:GetMoney()), 1, 0.85, 0.3)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    TK.Visibility:Attach(f, function() return self:DB() end)
    TK.EditMode:Register(f, "playerframe", "Player Frame", C.defaultPosition, "playerframe")
end

function C:Layout()
    local db, f = self:DB(), self.frame
    local left = db.showPortrait and (PORTRAIT + 16) or 8
    f.portrait:SetShown(db.showPortrait)
    -- s6-ui-core (round 82): a bar whose numbers take two rows is as tall as they need (V.Height)
    local hpH, mpH = V.Height(f.hp, HP_HEIGHT), V.Height(f.mp, MP_HEIGHT)
    self.hpHeight, self.mpHeight = hpH, mpH -- what Update compares with (a bar's measured height snaps to whole pixels)
    f.hp:SetHeight(hpH)
    f.mp:SetHeight(mpH)
    -- s6-ui-core (round 82; the owner, 2026-10-09): the experience bar under the portrait (and its level badge, 4 below
    -- it) and the bars, from the frame's left edge right across
    local bottom = math.max(28 + hpH + 3 + mpH, db.showPortrait and (8 + PORTRAIT + 4) or 0)
    f:SetSize(db.width, bottom + (db.showXP and (2 + XP_HEIGHT + 6) or 4))

    f.name:ClearAllPoints()
    f.name:SetPoint("TOPLEFT", f, "TOPLEFT", left, -9)
    f.path:ClearAllPoints()
    f.path:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -11)

    f.hp:ClearAllPoints()
    f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", left, -28)
    f.hp:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -28)
    f.mp:ClearAllPoints()
    f.mp:SetPoint("TOPLEFT", f.hp, "BOTTOMLEFT", 0, -3)
    f.mp:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", 0, -3)
    f.xp:ClearAllPoints()
    f.xp:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(bottom + 2))
    f.xp:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -(bottom + 2))
    f.xp:SetShown(db.showXP)
end

function C:Update()
    local db, f = self:DB(), self.frame
    local _, name, level, path = H:GetUnitInfo("player")
    local _, hp, hpMax, mp, mpMax = H:GetUnitVitals("player")
    local _, xp, xpMax = H:GetPlayerXP()
    f.name:SetText(name or "")
    f.level:SetText(tostring(level or ""))
    f.path:SetText(path or "")
    f.portrait.glyph:SetText((name or "?"):sub(1, 1))
    V.Set(f.hp, hp, hpMax, db.damageTaken) -- s6-ui-core (round 82): the damage taken, when on
    V.Set(f.mp, mp, mpMax, db.damageTaken)
    f.xp:SetMinMaxValues(0, xpMax)
    f.xp:SetValue(xp)
    local form = db.showNumbers and db.numberFormat
    V.Numbers(f.hp, hp, hpMax, form)
    V.Numbers(f.mp, mp, mpMax, form)
    f.xp.text:SetText("")
    -- s6-ui-core (round 82): numbers that went to two rows, or back to one, change the bars' heights. Round 83 (the head's
    -- review of round 82): compared with the heights Layout last set, as the party frames do, not the measured ones, which
    -- snap to whole pixels and made every vitals event lay the frame out again.
    if V.Height(f.hp, HP_HEIGHT) ~= self.hpHeight or V.Height(f.mp, MP_HEIGHT) ~= self.mpHeight then self:Layout() end
    if self.cost or self.costName then self:ShowCost(self.cost, self.costName) end
end

--- s6-characters seam (the owner, 2026-10-01): the portrait: the character's profile image when the setting asks for it and
--- there is one, else its figure's upper body as the map draws it; the name's letter while there is neither (offline).
function C:ShowPortrait()
    local db, p = self:DB(), self.frame.portrait
    local _, name = H:GetUnitInfo("player")
    local key = db.useProfileImage and name and H:GetProfileImage(name, true) or ""
    if key == "" then key = H:GetPortrait("player", 0, true) end
    if key == p.key then return end
    p.key = key
    p.picture:SetShown(key ~= "")
    p.glyph:SetShown(key == "")
    if key ~= "" then p.picture:SetTexture(key) end
end

--- Marks a spell's cost on the mana bar (nil hides it): the part of the mana it would use in yellow; when the cost is
--- more than the mana, all of it in yellow and the shortfall beyond in red (up to the maximum). s6-ui-core (round 82; the
--- owner, 2026-10-09): and a small red triangle under the bar at the cost's place from its left (V.Mark); name: the
--- hovered spell's, whose learned health cost (TK.SpellInfo) is marked the same way under the health bar.
function C:ShowCost(cost, name)
    local f = self.frame
    local mp = f.mp
    self.cost, self.costName = cost, name
    local _, _, hpMax, mana, max = H:GetUnitVitals("player")
    V.Mark(f.hp, name and TK.SpellInfo:Get(name).health, hpMax)
    V.Mark(mp, cost, max)
    if not cost or cost <= 0 or not max or max <= 0 then
        mp.costYellow:Hide()
        mp.costRed:Hide()
        return
    end
    V.Span(mp.costYellow, mp, mana - cost, mana, max)
    if cost > mana then V.Span(mp.costRed, mp, mana, cost, max) else mp.costRed:Hide() end
end

function C:ApplySettings()
    self:Layout()
    self:Update()
    self:ShowPortrait()   -- the profile image switch
    TK.Visibility:Apply(self.frame)
end

-- s6-input (round 49, separation step 4b): a hovered spell's learned cost, or nil (TK.ManaPreview, core/tooltip.lua);
-- s6-ui-core (round 82): and its name, nil on leaving.
TK.On("TK_MANA_PREVIEW", function(_, cost, name)
    if C.frame then C:ShowCost(cost, name) end
end)
