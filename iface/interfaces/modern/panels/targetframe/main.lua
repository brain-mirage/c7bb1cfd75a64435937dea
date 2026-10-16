-- The target frame (head note 4): the target's name and level, and the health percentage its last hit reported
-- (plan 3.10). The client learns nothing else about an enemy's health.
--
-- The percentage shows as long as the original shows it (head note 11.3): each hit (packet 0x13) makes a new hit bar
-- over the creature that deletes itself 500 ms later (Source-5 developer-src, class/HitBarObjectPane: "deletes
-- itself after 500 ms", AttachedObjectPane::OnTimer). Its colour follows HitBarObjectPane::RenderFrame (0x00539030):
-- a 46-pixel gauge filled 46 * percent / 100 pixels (whole pixels), red below 12, yellow below 23, green above; at 0
-- the dead sign (DEADSIGN.EPF) instead. Between hits the frame shows the name and level only.

local C = TK.GetComponent("targetframe")
local H = __tk
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local Icons = require("interfaces.modern.effecticons") -- Modern's effect icon group (s6-modular-g round 16)
local Portrait = require("interfaces.modern.portrait") -- the portrait the player frame has too (s6-optimize round 52)

C.HIT_SECONDS = 0.5

--- The hit bar's colour in the original: from the 46-pixel gauge's whole-pixel fill.
function C.HitColor(percent)
    local fill = math.floor(46 * percent / 100)
    if fill < 12 then return "red" end
    if fill < 23 then return "yellow" end
    return "green"
end

local colours = { red = { 1, 0, 0 }, yellow = { 1, 1, 0 }, green = { 0.34, 1, 0.34 } }
local PORTRAIT = 56

function C:OnEnable()
    local f = CreateFrame("Frame", "TKTargetFrame", UIParent)
    f:SetBackdrop({ bg = { 0.05, 0.03, 0.03, 0.85 }, edge = { 0.6, 0.5, 0.45, 1 } })
    TK.UI.HudPanel(f, C) -- s6-ui-settings (round 4): the shared panel style; s6-ui-core (round 53): or its own
    self.frame = f

    -- s6-ui-core (round 32): the target's portrait on the right, as the player frame's on the left: s6-characters'
    -- GetPortrait("object", id), the figure's upper body as the map draws it; the name's letter while there is none
    -- (out of view, offline).
    f.portrait = Portrait.New(f, PORTRAIT, "TOPRIGHT", -8, -8, 0.55, 0.2, 0.15)

    f.name = W.Label(f, "", 14, W.white, "LEFT")
    f.name:SetFont("classic", 12, "")   -- names in the original's own font
    f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -9)
    local badge = CreateFrame("Frame", nil, f)
    badge:SetSize(30, 18)
    badge:SetBackdrop({ bg = { 0.1, 0.08, 0.02, 0.95 }, edge = { 0.85, 0.75, 0.45, 1 } })
    f.level = W.Label(badge, "", 11, W.gold)
    f.level:SetPoint("CENTER", badge, "CENTER", 0, 0)
    f.badge = badge

    local hit = W.VitalBar(f, 16, 0.75, 0.2, 0.15, 11, "TKTargetFrameHit")
    hit:SetMinMaxValues(0, 100)
    f.hit = hit
    -- s6-library round 2 (head note 4): what is known of the target's buffs under the frame, the Library's estimates
    -- marked as such ("~" and "est."), a peer's word as shared; read again four times a second for the countdowns.
    -- s6-ui-core (round 43, effects on others): as a row of icons (Modern's effecticons.lua, the group the icons on units
    -- share, each with its tooltip on mouse-over and its time under it), debuffs first; the line of text stays, shown when
    -- the Effects tab's "also as text" is on.
    f.effects = Icons.NewGroup(f, "TKTargetEffects", true)
    Icons.SetListMenu(f.effects, true) -- round 44: a right-click on an icon puts its name on a list
    f.effects:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 2, -3)
    f.effects:Hide()
    f.buffs = W.Label(f, "", 11, { 0.72, 0.84, 1 }, "LEFT")
    f.buffs:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 4, -3)
    -- The target's tooltip (head note 40): its name, level and the last hit, all the client knows of it.
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(frame)
        local exists, name, level = H:GetUnitInfo("target")
        if not exists then return end
        local _, percent = H:GetTargetHit()
        GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
        if name ~= "" then GameTooltip:AddLine(name, 1, 0.45, 0.35) end
        if level > 0 then GameTooltip:AddLine("Level " .. level, 1, 0.82, 0) end
        GameTooltip:AddLine(percent >= 0 and ("Last hit: " .. C.HitText(percent)) or "Not hit yet", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.hitText = W.Label(f, "", 12, W.white, "LEFT")
    f.dead = f:CreateTexture(nil, "OVERLAY")
    f.dead:SetSize(24, 24)
    f.dead:SetPoint("LEFT", hit, "LEFT", 4, 0)
    -- The original's dead sign, drawn through the map's palette (BARAM.PAL), else a skull.
    f.dead:SetTexture(TK.Art.Image("DEADSIGN.EPF", 0, "BARAM.PAL") or "emoji:2620")
    f.dead:Hide()
    -- The bar goes away 500 ms after the hit that showed it.
    f:SetScript("OnUpdate", function()
        if self.hitShown and GetTime() - self.hitAt >= C.HIT_SECONDS then self:ShowHit(false) end
    end)
    -- s6-library (round 4: hooked after the hit bar's script, which replaced it when it came first)
    local since = 0
    f:HookScript("OnUpdate", function(_, elapsed)
        since = since + (elapsed or 0)
        if since < 0.25 then return end
        since = 0
        C:UpdateBuffs()
    end)

    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("UNIT_HEALTH")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("UNIT_MODEL_CHANGED")
    f:SetScript("OnEvent", function(_, event, unit)
        if (event == "UNIT_HEALTH" or event == "UNIT_MODEL_CHANGED") and unit ~= "target" then return end
        -- s6-ui-core (round 33, the owner): the portrait is held until the target, or its look, changes; it was asked for
        -- four times a second. A hit (UNIT_HEALTH) asks for nothing.
        if event ~= "UNIT_MODEL_CHANGED" then self:Update() end
        if event ~= "UNIT_HEALTH" then self:ShowPortrait() end
    end)

    -- s6-rules-dialogs: a right-click opens the player menu on another player (D-56; the model decides).
    f:EnableMouse(true)
    f:SetScript("OnMouseDown", function(_, button)
        if button ~= "RightButton" or not TK.Dialogs then return end
        local _, name = H:GetUnitInfo("target")
        TK.Dialogs.PlayerMenu(H:GetTargetId(), name)
    end)

    self.hasTarget = H:UnitExists("target")
    TK.Visibility:Attach(f, function() return self:DB() end, function() return self.hasTarget end)
    TK.EditMode:Register(f, "targetframe", "Target Frame", C.defaultPosition, "targetframe")
end

--- The last hit as text: "72%", or that there has been none yet.
function C.HitText(percent)
    if not percent or percent < 0 then return "Not hit yet" end
    return percent .. "%"
end

--- Shows or hides the last hit: the bar (or the text when the bar is off in the settings), and the dead sign after
--- a hit to 0. All of it goes 500 ms after the hit, and on a new target (review R3.1).
function C:ShowHit(on)
    local db, f = self:DB(), self.frame
    self.hitShown = on
    f.hit:SetShown(on and db.showHitBar)
    f.hitText:SetShown(on and not db.showHitBar)
    f.dead:SetShown(on and self.hitDead == true)
end

function C:Update()
    local f = self.frame
    local exists, name, level = H:GetUnitInfo("target")
    self.hasTarget = exists
    if not exists then
        TK.Visibility:Apply(f)
        return
    end
    local _, percent, hitTime = H:GetTargetHit()
    -- UI head note 58: an ordinary monster's name is not on the wire (0x07 names NPCs only); s6-protocol learns it from a
    -- look (0x0A) and publishes it. Until then the frame shows no name, never a placeholder.
    f.name:SetText(name)
    f.level:SetText(level > 0 and tostring(level) or "")
    f.portrait.glyph:SetText(name ~= "" and name:sub(1, 1) or "?")
    if percent >= 0 and hitTime >= 0 and GetTime() - hitTime < C.HIT_SECONDS then
        self.hitAt = hitTime
        local dead = percent == 0
        local c = colours[C.HitColor(percent)]
        f.hit:SetStatusBarColor(c[1], c[2], c[3], 1)
        f.hit:SetValue(percent)
        f.hit.text:SetText(dead and "" or C.HitText(percent))
        self.hitDead = dead
        f.hitText:SetText("Last hit: " .. C.HitText(percent))
        self:ShowHit(true)
    else
        self:ShowHit(false)
    end
    TK.Visibility:Apply(f)
end

--- s6-ui-core (round 43): the target's kind, "creature" or "player", for its filter; round 46: and its name (a player's
--- shared effects are by name).
function C:TargetKind()
    local target = H:GetTargetId()
    for i = 1, H:GetNumObjects() do
        local _, id, kind, _, _, name = H:GetObjectInfo(i)
        if id == target then return kind, name end
    end
    return "creature"
end

--- s6-library round 2: the target's buffs (estimates and shared ones; empty when nothing is known). s6-ui-core (round
--- 43): as the icon row, filtered by the Effects tab's filter for the target's kind, and as the line of text ("~Poison
--- 55s (est.)", "~Poison A / Poison B 0-20s (est.)", "??? 287s"), shown when that option is on.
function C:UpdateBuffs()
    local f, db = self.frame, self:DB()
    local E = TK.EffectIcons
    local list = {}
    if self.hasTarget then
        local kind, name = self:TargetKind()
        local filter = kind == "player" and "player" or "creature"
        -- round 44: a peer's word on its own debuffs on the target creature (phase 4's start); round 46: a player's own
        list = E.Arrange(E.WithPeers(H:GetUnitBuffs("target"), H:GetTargetId(), kind, name), db[filter .. "Mode"], true)
    end
    local icons = db.showEffects and #list > 0
    if icons then
        local colW = Icons.ColumnWidth(math.max(db.effectSize, db.ownSize or 0), db.effectTime)
        Icons.Show(f.effects, list, { size = db.effectSize, perRow = math.max(1, math.floor(db.width / (colW + Icons.style.gap))),
                                  max = 24, timeText = db.effectTime, ownSize = db.ownSize }) -- round 44: our own casts larger
    end
    if not icons then Icons.Release(f.effects) end -- round 44: no stale tooltip once the row goes
    f.effects:SetShown(icons)
    local parts = {}
    for _, item in ipairs(list) do
        local b = item.row
        local t = E.Label(b)
        if b.remaining >= 0 then
            local lo = math.max(0, b.remainingMin)
            t = t .. " " .. (b.remaining - lo >= 1 and (math.ceil(lo) .. "-") or "") .. math.ceil(b.remaining) .. "s"
        end
        if b.estimate then t = "~" .. t .. " (est.)" elseif b.source == "peer" then t = t .. " (shared)" end
        parts[#parts + 1] = t
    end
    f.buffs:SetText(#parts > 0 and table.concat(parts, "   ") or "")
    f.buffs:ClearAllPoints()
    if icons then f.buffs:SetPoint("TOPLEFT", f.effects, "BOTTOMLEFT", 2, -2) else f.buffs:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 4, -3) end
    f.buffs:SetShown(db.effectsText or not db.showEffects)
end

--- s6-ui-core (round 32): the target's portrait (s6-characters' GetPortrait "object": its figure's upper body, cut to
--- the circle); the name's letter while there is none.
function C:ShowPortrait()
    local p = self.frame.portrait
    local key = self.hasTarget and self:DB().showPortrait and H:GetPortrait("object", H:GetTargetId(), true) or ""
    if key == p.key then return end
    p.key = key
    p.picture:SetShown(key ~= "")
    p.glyph:SetShown(key == "")
    if key ~= "" then p.picture:SetTexture(key) end
end

function C:ApplySettings()
    local db, f = self:DB(), self.frame
    -- The portrait on the right; the name, the level and the hit bar left of it.
    local right = db.showPortrait and (PORTRAIT + 16) or 8
    f.portrait:SetShown(db.showPortrait)
    f:SetSize(db.width, db.showPortrait and PORTRAIT + 16 or 54)
    f.badge:ClearAllPoints()
    f.badge:SetPoint("TOPRIGHT", f, "TOPRIGHT", -right, -7)
    f.hit:ClearAllPoints()
    f.hit:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -30)
    f.hit:SetPoint("TOPRIGHT", f, "TOPRIGHT", -right, -30)
    f.hitText:ClearAllPoints()
    f.hitText:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -32)
    f.portrait.key = nil
    self:Update()
    self:ShowPortrait()
end

-- s6-input (round 49, separation step 4b): the effect name lists changed (core/effecticons.lua): the row sorts again now,
-- not at its next quarter-second refresh (round 46).
TK.On("TK_EFFECT_LISTS_CHANGED", function()
    if C.frame then TK.SafeCall(C.UpdateBuffs, C) end
end)
