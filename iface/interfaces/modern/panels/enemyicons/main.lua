-- Effects on others (plan 5.11's enemy icons; s6-ui-core round 43, phase 1 of docs/user-related/research/buffs-and-debuffs.md):
-- very small icons for the buffs and debuffs of the creatures and players in the world view's active 17 x 15 area, grouped
-- under each one's name (the default, as the owner remembers WoW's nameplate addons) or over its head, for the target and
-- the one under the mouse by default, or all creatures, all players, or everyone (the decision on questions 30-34; round
-- 82: each kind its own choice, on the Nameplates pane's Players and NPCs pages, the icons under a health bar there). Each
-- icon is one effect as the world knows it (__tk:GetUnitBuffs: a graphic the server gave a time, the seconds-left list it
-- sends as a player comes into view, a cast seen and the spells that may have made it, our own casts' countdowns, a peer's
-- share); its tooltip, shown when the pointer is over it, says what it is ("???" when unknown) and how long it has left
-- ("?" or nothing when unknown). The icons never take the mouse, so a click on a figure under them still reaches the world;
-- round 44: but for the right button, which opens an icon's menu to put its name on a list (a setting).
-- Filters per kind (creatures, players): all, only the listed ones, or all but the listed ones. Local display only:
-- nothing is sent.
-- s6-ui-core (round 85): the XML twin's scripts; the layer the groups are on is main.xml's (core/xml.md).

local C = TK.GetComponent("enemyicons")
local H = __tk
local U = TK.Util
local E = TK.EffectIcons
-- s6-modular-g (round 16, separation step 7): the icon group and the table below are Modern's (interfaces/modern/)
local G = require("interfaces.modern.effecticons")
local named = require("interfaces.modern.data.enemyicons") -- graphics named by hand (the old table), for "???" ones

C.groups = {}   -- the shown groups, by object id
C.wanted = {}   -- the objects shown at the last refresh: { id, kind, x, y, list }

--- Who gets icons: s6-ui-core (round 82) each kind's choice on the Nameplates pane's Players and NPCs pages (playerWho,
--- creatureWho: no one, the target, the one under the mouse, both, or everyone in view; nameplates' C.Shows).
function C:Wanted(id, kind, target, hover)
    return TK.GetComponent("nameplates").Shows(self:DB()[kind .. "Who"], id, target, hover)
end

--- The rows for an object, named from Modern's data/enemyicons.lua where the world knows nothing of an effect but its
--- graphic.
local function rowsOf(id, kind, name)
    -- Round 44: a peer's word on its own debuffs on a creature here (phase 4's start); round 46: a player's own effects.
    local rows = E.WithPeers(H:GetUnitBuffs(id), id, kind, name)
    for i = 1, #rows do
        local b = rows[i]
        local hand = b.name == "" and (b.candidates or "") == "" and (b.effect or 0) > 0 and named.effects[b.effect]
        if hand then b.name = hand.name end
    end
    return rows
end

--- s6-ui-core (round 44, Astra P2): the unit whose icons are under the pointer, or nil. The icons take no mouse input,
--- so under them the world answers with another figure or none; the unit stays "under the mouse" while the pointer is
--- anywhere on its group (the gaps between icons too), so its row does not vanish as the pointer moves onto it.
function C:UnitUnderIcons()
    local x, y = U.CursorRoot()
    if not x then return nil end
    for id, g in pairs(self.groups) do
        if g:IsVisible() then
            local l, b, w, h = U.RootRect(g)
            if l and x >= l and x <= l + w and y >= b and y <= b + h then return id end
        end
    end
    return nil
end

--- Which objects get icons and what they show; a few times a second (the countdowns are whole seconds).
function C:Collect()
    local db, view = self:DB(), TK.GetComponent("worldview")
    local wanted = {}
    if db.enabled and view and view.frame and view.frame:IsVisible() then
        local ox, oy = H:GetTileOrigin()
        local self_ = H:GetPlayerObjectId()
        local target = H:GetTargetId()
        local cx, cy = view:CentrePoint()
        local hover = self:UnitUnderIcons() or (cx and H:GetFigureAt(cx, cy)) or 0
        for i = 1, H:GetNumObjects() do
            local _, id, kind, x, y, name = H:GetObjectInfo(i)
            local vx, vy = x - ox, y - oy
            if (kind == "creature" or kind == "player") and id ~= self_ and vx >= 0 and vx < 17 and vy >= 0 and vy < 15
                and self:Wanted(id, kind, target, hover) then
                local filter = kind == "player" and "player" or "creature"
                local list = E.Arrange(rowsOf(id, kind, name), db[filter .. "Mode"], db.showUnknown)
                -- s6-world-view (round 39; Astra's round 38 review, P2): the map cell, so Place puts it where this frame
                -- draws that cell
                if #list > 0 then wanted[#wanted + 1] = { id = id, x = x, y = y, list = list } end
            end
        end
    end
    self.wanted = wanted
    local keep = {}
    for _, w in ipairs(wanted) do
        local g = self.groups[w.id]
        if not g then
            g = table.remove(self.spare) or G.NewGroup(self.frame, "TKEffectsOn" .. (#self.all + 1), false)
            G.SetListMenu(g, db.rightClick) -- round 44: a right-click on an icon (the right button only) lists its name
            if not g.counted then
                g.counted = true
                self.all[#self.all + 1] = g
            end
            self.groups[w.id] = g
        end
        g.unit = w
        G.Show(g, w.list, { size = db.size, perRow = db.perRow, max = db.max, timeText = db.timeText })
        keep[w.id] = true
    end
    for id, g in pairs(self.groups) do
        if not keep[id] then
            g:Hide()
            g.unit = nil
            self.groups[id] = nil
            self.spare[#self.spare + 1] = g
        end
    end
end

--- Each group at its unit's name or head; every frame, so the icons follow the figures' steps.
function C:Place()
    local db, view = self:DB(), TK.GetComponent("worldview")
    if not (view and view.frame) then return end
    local plates = TK.GetComponent("nameplates")
    local scale = view:TileSize() / 48
    local _, _, w, h = U.RootRect(view.frame)
    for _, g in pairs(self.groups) do
        local u = g.unit
        local ok, x, nameY, headY = H:GetUnitAnchor(u.id)
        local px, py, point
        if ok then
            px = x * scale
            -- s6-ui-core (round 82): under the name, below the unit's health bar there (nameplates' bars.lua)
            if db.place == "over" then py, point = -headY * scale + 1, "BOTTOM" else py, point = -nameY * scale - 1 - plates:BarSpace(u.id), "TOP" end
        else
            -- Not drawn by the object layer (a view without figures): over its cell, as the enemy icons were. s6-world-view
            -- (round 39; Astra's round 38 review, P2, and review 39-2): its map cell placed from the origin this frame is
            -- drawn from (CellCentre), so at a step's end, when the origin moves and the glide goes back to 0, the icons stay
            -- on the cell and do not hop back a cell. Drawing only.
            local cx, cy, t = view:CellCentre(u.x, u.y)
            if db.place == "over" then px, py, point = cx, cy + t * 1.1, "BOTTOM" else px, py, point = cx, cy + t * 0.9 - plates:BarSpace(u.id), "TOP" end
        end
        local inside = w and math.abs(px) <= w / 2 and math.abs(py) <= h / 2
        if inside then
            if g.point ~= point or g.px ~= px or g.py ~= py then
                g:ClearAllPoints()
                g:SetPoint(point, view.frame, "CENTER", px, py)
                g.point, g.px, g.py = point, px, py
            end
            g:Show()
        else
            g:Hide()
        end
    end
end

--- The tooltip of the icon under the pointer, shown by the component (the icons take no mouse).
function C:Hover()
    local x, y = U.CursorRoot()
    local over
    for _, g in pairs(self.groups) do
        over = G.IconAt(g, x, y)
        if over then break end
    end
    -- Shown again when another took the tooltip (the world's figure tooltip, before it saw this one). s6-input (round 49,
    -- separation step 4b): the icon claims the world's tooltip while it shows its own (TK.ClaimWorldTip).
    if over and (over ~= self.tipFor or over.row ~= self.tipRow or GameTooltip:GetOwner() ~= over) then
        G.ShowTooltip(over, over.row)
        self.tipFor, self.tipRow = over, over.row
        TK.ClaimWorldTip(over)
    elseif not over and self.tipFor then
        if GameTooltip:GetOwner() == self.tipFor then GameTooltip:Hide() end
        self.tipFor, self.tipRow = nil, nil
        TK.ClaimWorldTip(nil)
    end
end

function C:Refresh()
    self:Collect()
    self:Place()
end

-- the scripts main.xml names
local scripts = {}

-- the groups placed and the tooltip shown every frame, the units collected four times a second (the count its frame's own)
function scripts.Ticker(f)
    C.all, C.spare = {}, {}
    local elapsed = 1
    f:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed >= 0.25 then
            elapsed = 0
            TK.SafeCall(C.Collect, C)
        end
        TK.SafeCall(C.Place, C)
        TK.SafeCall(C.Hover, C)
    end)
end

function C:OnEnable()
    self.frame = TK.Xml.Load("main.xml", { scripts = scripts }).frame
    TK.Visibility:Attach(self.frame, function() return self:DB() end)
end

function C:ApplySettings()
    local db = self:DB()
    -- Round 45: the older forms (round 43's "Show Icons For", its text lists) are carried over as the profile loads
    -- (C:Migrate, settings.lua). The auras sort by the lists; the icons' right-click as set.
    E.ListsChanged()
    for _, g in ipairs(self.all or {}) do G.SetListMenu(g, db.rightClick) end
    TK.Visibility:Apply(self.frame)
    TK.SafeCall(C.Refresh, C)
end
