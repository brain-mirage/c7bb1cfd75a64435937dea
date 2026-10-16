-- Buffs, debuffs and aethers (goals 13 and 14, head note 4, plan 5.11).
--
-- The server sends the player's effects as names and seconds, buffs and debuffs mixed (0x3A). The effects table
-- (lua/data/effects.lua) splits them, and Modern's (lua/interfaces/modern/data/effects.lua, read by effecticons.lua's
-- Icon: s6-modular-g round 16) gives each an emoji icon; a name the first does not know goes to the buffs,
-- marked unclassified, and is logged once. Right-clicking an icon moves the effect to the other frame by putting its
-- name on the other of the profile's two name lists (s6-ui-core round 43: Buffs and Debuffs, on Effects on Others'
-- page, which decide first; core/effecticons.lua). Choices kept for this computer before (TK.Machine effectOverrides)
-- still count for names on neither list.
--
-- The aether list is an optional frame with the running aethers (cooldowns), shortest first. The action buttons
-- show the same aethers as their numbers and clocks.
-- s6-ui-core (round 85): the XML twin's scripts; the frames, an effect's icon and an aether's row are main.xml's
-- (core/xml.md).

local C = TK.GetComponent("auras")
local H = __tk
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local Icons = require("interfaces.modern.effecticons") -- Modern's effect pictures (s6-modular-g round 16)

C.frames, C.lists, C.logged = {}, { buffs = {}, debuffs = {} }, {}

-- ----- classification -----

--- Moves an effect to the other frame. s6-ui-core (round 43): by putting its name on the other list (the profile's
--- Buffs and Debuffs, the one set of names); an earlier choice kept for this computer is dropped for it.
function C:Reclassify(name)
    local kind = TK.EffectIcons.Classify(name)
    local new = kind == "debuff" and "buff" or "debuff"
    TK.EffectIcons.MoveToList(name, new)
    local overrides = TK.Machine:Get().effectOverrides
    if overrides[name] then
        overrides[name] = nil
        TK.Machine:MarkDirty()
    end
    H:Log("effect '" .. name .. "' is now on the " .. (new == "debuff" and "Debuffs" or "Buffs") .. " list")
    GameTooltip:Hide()
    self:Refresh()
end

-- ----- time labels -----

--- The remaining time as WoW shows it under a buff: "2h", "5m", "45s". The key changes exactly when the text does.
local function timeKey(left)
    if left >= 3600 then return math.ceil(left / 3600) * 4 + 3 end
    if left >= 60 then return math.ceil(left / 60) * 4 + 2 end
    return math.ceil(left) * 4 + 1
end

local units = { "s", "m", "h" }
function C.TimeText(left)
    local k = timeKey(left)
    return math.floor(k / 4) .. units[k % 4]
end

-- ----- icons -----

local function showTooltip(b)
    local e = b.effect
    if not e then return end
    GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine(e.name, 1, 1, 1)
    if e.unclassified then
        GameTooltip:AddLine("Unclassified: not in the effects table", 1, 0.6, 0.2)
    elseif e.kind == "debuff" then
        GameTooltip:AddLine("Debuff", 1, 0.3, 0.3)
    else
        GameTooltip:AddLine("Buff", 0.4, 0.8, 1)
    end
    if e.expires >= 0 then
        GameTooltip:AddLine(C.TimeText(math.max(0, e.expires - GetTime())) .. " left", 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("Right-click: move to " .. (e.kind == "debuff" and "Buffs" or "Debuffs"), 0.5, 0.8, 1)
    GameTooltip:Show()
end

local ui -- main.xml's build (C:OnEnable)

local function makeIcon(f, i)
    return ui:New("EffectIcon", f, f:GetName() .. "Icon" .. i)
end

local function styleIcon(b, e)
    b.effect = e
    b.icon:SetTexture(e.icon)
    b.mark:SetShown(e.unclassified)
    if e.unclassified then
        b.border:SetVertexColor(1, 0.6, 0.2, 1)
    elseif e.kind == "debuff" then
        b.border:SetVertexColor(0.85, 0.15, 0.12, 1)
    else
        b.border:SetVertexColor(0.6, 0.6, 0.62, 1)
    end
    b.timeKey = nil
    b.blinking = false
    b:SetAlpha(1)
end

--- Lays out a buff or debuff frame: icons in rows of perRow, in the chosen directions, the time under each.
function C:LayoutIcons(key)
    local db, f, list = self:DB()[key], self.frames[key], self.lists[key]
    local per = math.max(1, math.floor(db.perRow))
    local rows = math.max(1, math.ceil(#list / per))
    local cellW = db.size + db.spacing
    local cellH = db.size + (db.showTime and 14 or 0) + db.spacing
    f:SetSize(per * cellW - db.spacing, rows * cellH - db.spacing)
    for i = 1, math.max(#list, #f.icons) do
        local e = list[i]
        local b = f.icons[i]
        if e and not b then
            b = makeIcon(f, i)
            f.icons[i] = b
        end
        if e then
            local r, c = math.floor((i - 1) / per), (i - 1) % per
            if db.growH == "LEFT" then c = per - 1 - c end
            if db.growV == "UP" then r = rows - 1 - r end
            b:SetSize(db.size, db.size)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", f, "TOPLEFT", c * cellW, -r * cellH)
            styleIcon(b, e)
            b.time:SetShown(db.showTime)
            b:Show()
        elseif b then
            b:Hide()
            b.effect = nil
        end
    end
    self:TickIcons(key)
end

--- Every frame: the time labels (only when the shown text changes) and blinking in the last 10 seconds.
function C:TickIcons(key)
    local db, f, list = self:DB()[key], self.frames[key], self.lists[key]
    if #list == 0 then return end
    local now = GetTime()
    for i, e in ipairs(list) do
        local b = f.icons[i]
        local left = e.expires - now
        if left < 0 then left = 0 end
        -- An effect the server sent with a negative time (0x3A) shows its name only: no time, no blinking.
        if e.expires < 0 then
            if b.timeKey ~= -1 then
                b.timeKey = -1
                b.time:SetText("")
            end
        elseif db.showTime then
            local k = timeKey(left)
            if b.timeKey ~= k then
                b.timeKey = k
                b.time:SetText(math.floor(k / 4) .. units[k % 4])
            end
        end
        if db.blink and e.expires >= 0 and left <= 10 then
            b.blinking = true
            b:SetAlpha(0.3 + 0.7 * math.abs(math.cos(left * math.pi)))
        elseif b.blinking then
            b.blinking = false
            b:SetAlpha(1)
        end
    end
end

--- Reads the effects again and splits them into the two frames, in the order the server sent them. s6-interface-5x (round
--- 13's hotfix): only for those of the two that are on (one turned off reads and draws nothing; it reads them again when
--- it is turned on: OnSettingChanged).
function C:Refresh()
    local db = self:DB()
    if not (db.buffs.enabled or db.debuffs.enabled) then return end
    local buffs, debuffs = {}, {}
    for i = 1, H:GetNumEffects() do
        local ok, name, expires, id = H:GetEffect(i)
        if ok then
            local kind, unclassified = TK.EffectIcons.Classify(name)
            local icon = Icons.Icon(name)
            if unclassified and not self.logged[name] then
                self.logged[name] = true
                H:LogWarning("effect '" .. name .. "' is not in lua/data/effects.lua; shown with the buffs, unclassified")
            end
            local e = { name = name, expires = expires, id = id, kind = kind, icon = icon, unclassified = unclassified }
            if kind == "debuff" then debuffs[#debuffs + 1] = e else buffs[#buffs + 1] = e end
        end
    end
    self.lists.buffs, self.lists.debuffs = buffs, debuffs
    if db.buffs.enabled then self:LayoutIcons("buffs") end
    if db.debuffs.enabled then self:LayoutIcons("debuffs") end
end

-- ----- the aether list -----

local ROW = TK.Xml.Data("main.xml").SIZES.row -- main.xml's

local function makeRow(f, i)
    local r = ui:New("AetherRow", f)
    r.icon, r.glyph = r.box.icon, r.box.glyph
    return r
end

function C:RefreshAethers()
    if not self:DB().aethers.enabled then return end -- s6-interface-5x (round 13's hotfix): off, it reads nothing
    local list = {}
    for i = 1, H:GetNumAethers() do
        local ok, kind, slot, start, duration = H:GetAether(i)
        if ok then
            local name = TK.ActionInfo({ kind = kind, slot = slot })
            if name then
                list[#list + 1] = { name = name, action = { kind = kind, slot = slot }, start = start,
                                    duration = duration, ends = start + duration }
            end
        end
    end
    table.sort(list, function(a, b) return a.ends < b.ends end)
    self.aetherList = list
    self:LayoutAethers()
end

function C:LayoutAethers()
    local db, f, list = self:DB().aethers, self.frames.aethers, self.aetherList or {}
    local n = math.min(#list, db.maxRows)
    f:SetSize(db.width, math.max(n, 1) * ROW + 8)
    f:SetBackdropColor(0.04, 0.04, 0.05, n > 0 and 0.75 or 0)
    for i = 1, math.max(n, #f.rows) do
        local e, r = list[i], f.rows[i]
        if i <= n then
            if not r then
                r = makeRow(f, i)
                f.rows[i] = r
            end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4 - (i - 1) * ROW)
            r:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4 - (i - 1) * ROW)
            W.ActionIcon(r.icon, r.glyph, r.box, e.action, ROW - 4)
            r.name:SetText(e.name)
            r.bar:SetShown(db.showBars)
            r.entry, r.timeKey = e, nil
            r:Show()
        elseif r then
            r:Hide()
            r.entry = nil
        end
    end
    self:TickAethers()
end

function C:TickAethers()
    local f = self.frames.aethers
    local now -- read at the first row with an entry (s6-optimize round 10: GetTime is a slow clock read on the VM)
    for _, r in ipairs(f.rows) do
        local e = r.entry
        if e then
            now = now or GetTime()
            local left = math.max(0, e.ends - now)
            local k = timeKey(left)
            if r.timeKey ~= k then
                r.timeKey = k
                r.time:SetText(math.floor(k / 4) .. units[k % 4])
            end
            if e.duration > 0 then r.bar:SetValue(left / e.duration) end
        end
    end
end

-- ----- frames -----

-- the scripts main.xml names
local scripts = {}

function scripts.Reclassify(self, button)
    if button == "RightButton" and self.effect then C:Reclassify(self.effect.name) end
end

scripts.Tip = showTooltip

function scripts.Untip() GameTooltip:Hide() end

-- a frame's edit mode entry, its visibility by its settings (f.edit: their key and the mover's title)
function scripts.Register(f)
    local key = f.edit.id
    C.frames[key] = f
    TK.Visibility:Attach(f, function() return C:DB()[key] end)
    TK.EditMode:Register(f, key, f.edit.title, C.defaultPositions[key], key, function() return C:DB()[key].enabled end)
end

function scripts.HudPanel(f) TK.UI.HudPanel(f, function() return C:DB().aethers end) end

function scripts.TickIcons(f) C:TickIcons(f.edit.id) end

function scripts.TickAethers() C:TickAethers() end

function scripts.Changed(_, event, unit)
    if event == "UNIT_AURA" then
        if unit == "player" then C:Refresh() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C:Refresh()
        C:RefreshAethers()
    else
        C:RefreshAethers()
    end
end

function C:OnEnable()
    ui = TK.Xml.Load("main.xml", { scripts = scripts, elements = require("interfaces.modern.elements") })
end

function C:ApplySettings()
    self:Refresh()
    self:RefreshAethers()
    for _, f in pairs(self.frames) do TK.Visibility:Apply(f) end
end

function C:OnSettingChanged(node, key)
    local k = node.frameKey
    -- turned on, it reads what it left alone while off (Refresh, RefreshAethers)
    if key == "enabled" then
        if k == "aethers" then self:RefreshAethers() else self:Refresh() end
    elseif k == "aethers" then self:LayoutAethers() else self:LayoutIcons(k) end
    TK.Visibility:Apply(self.frames[k])
    if key == "enabled" then TK.EditMode:UpdateMovers() end
end

-- s6-input (round 49, separation step 4b): the effect name lists changed (core/effecticons.lua): our effects sort again.
TK.On("TK_EFFECT_LISTS_CHANGED", function()
    if C.frames and C.frames.buffs and C.frames.debuffs then TK.SafeCall(C.Refresh, C) end
end)
