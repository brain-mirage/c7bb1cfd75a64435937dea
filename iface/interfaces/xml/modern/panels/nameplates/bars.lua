-- s6-ui-core (round 82; the owner, 2026-10-09, docs/user-related/requests/2026-10-09-health-mana-bars-and-target-info.md):
-- health bars over others, a part of the Nameplates pane. Creatures and other players in the world view's active 17 x 15
-- area get one under the name, each kind as its page says (Players, NPCs: for whom, the numbers, the damage taken). It
-- shows what the client knows: a group member's health and mana in points (the group list, 0x63); anyone else's health
-- as the percentage its last hit reported (0x13: WorldSnapshot.Hits, __tk:GetUnitHit), full until a hit is seen. While
-- the original's group bars are on, a group member has those instead (main.lua). A hovered spell's healing or damage, as
-- the Library learned it, shows on the target's bar where its health is in points. Local display only: nothing is sent.
-- s6-ui-core (round 85): the XML twin's scripts; a unit's bars are bars.xml's (core/xml.md).

local C = TK.GetComponent("nameplates")
local H = __tk
local V = require("interfaces.modern.vitals")

local ui = TK.Xml.Load("bars.xml", { elements = require("interfaces.modern.elements") }) -- its template only
local SIZES = ui.SIZES
local HP_H, HP_NUMBERS_H, MP_H, GAP = SIZES.hp, SIZES.hpNumbers, SIZES.mp, SIZES.gap
local COLOURS = { player = { 0.15, 0.75, 0.15 }, creature = { 0.8, 0.18, 0.12 } }

C.unitBars = {}   -- the bars shown, by object id
local spare, made = {}, 0

local function newBar()
    made = made + 1
    return ui:New("UnitBar", C.frame, "TKNameplateBar" .. made)
end

--- Draws unit id's bar with its top at (px, py) from the view's centre (kind: "player" or "creature"; prefix: its
--- settings' "player" or "npc"; unit: its group unit, or nil). Returns the room it takes under the name.
function C:DrawBar(id, kind, prefix, unit, view, px, py, target)
    local db = self:DB()
    local f = self.unitBars[id]
    if not f then
        f = table.remove(spare) or newBar()
        V.Reset(f.hp)
        V.Reset(f.mp)
        f.px = nil
        self.unitBars[id] = f
    end
    local c = COLOURS[kind]
    f.hp:SetStatusBarColor(c[1], c[2], c[3], 1)
    f.hp.lossColour = kind == "creature" and V.LOSS_ON_RED or nil -- the damage taken against a red fill
    local form = db[prefix .. "Numbers"] ~= "none" and db[prefix .. "Numbers"] or nil
    local loss, mana = db[prefix .. "Damage"], false
    local preview = id == target and self.preview
    if unit then
        local _, hp, hpMax, mp, mpMax = H:GetUnitVitals(unit)
        V.Set(f.hp, hp, hpMax, loss)
        V.Numbers(f.hp, hp, hpMax, form)
        V.Preview(f.hp, preview and preview.amount, preview and preview.kind)
        mana = prefix == "player" and db.playerMana and mpMax > 0
        if mana then V.Set(f.mp, mp, mpMax, loss) end
    else
        local hit, percent = H:GetUnitHit(id)
        percent = hit and percent or 100
        V.Set(f.hp, percent, 100, loss)
        V.Numbers(f.hp, percent, nil, form)
        V.Preview(f.hp, nil) -- a percentage only: no points to place a heal or a hit by
    end
    f.mp:SetShown(mana)
    local hpH = V.Height(f.hp, form and HP_NUMBERS_H or HP_H)
    f.hp:SetHeight(hpH)
    local height = hpH + (mana and GAP + MP_H or 0)
    f:SetHeight(height)
    if f.px ~= px or f.py ~= py then
        f:ClearAllPoints()
        f:SetPoint("TOP", view.frame, "CENTER", px, py)
        f.px, f.py = px, py
    end
    f:Show()
    return height + 2
end

--- The bars this frame (C:Refresh): view nil while the world view does not show (none then); else its tile scale, its
--- size in screen units, the hovered figure's and the target's ids, and the group members' units by object id
--- (C:Members()): their bars show points, or the original's group bars replace them while those are on.
function C:RefreshBars(view, scale, w, h, hover, target, group)
    local db = self:DB()
    local keep, space = {}, {}
    if view and (db.playerBars ~= "off" or db.npcBars ~= "off") then
        local self_ = H:GetPlayerObjectId()
        local ox, oy = H:GetTileOrigin()
        for i = 1, H:GetNumObjects() do
            local _, id, kind, x, y = H:GetObjectInfo(i)
            local prefix = kind == "player" and "player" or kind == "creature" and "npc" or nil
            local vx, vy = x - ox, y - oy
            if prefix and id ~= self_ and vx >= 0 and vx < 17 and vy >= 0 and vy < 15
                and not (group[id] and db.groupBars) and self.Shows(db[prefix .. "Bars"], id, target, hover) then
                local ok, ax, nameY = H:GetUnitAnchor(id)
                local px, py
                if ok then
                    px, py = ax * scale, -nameY * scale - 1
                else
                    -- Not drawn by the object layer (a view without figures): at its cell, where the effect icons go
                    -- then (enemyicons' Place)
                    local cx, cy, t = view:CellCentre(x, y)
                    px, py = cx, cy + t * 0.9
                end
                if math.abs(px) <= w / 2 and math.abs(py) <= h / 2 then
                    keep[id] = true
                    space[id] = self:DrawBar(id, kind, prefix, group[id], view, px, py, target)
                end
            end
        end
    end
    for id, f in pairs(self.unitBars) do
        if not keep[id] then
            f:Hide()
            self.unitBars[id] = nil
            spare[#spare + 1] = f
        end
    end
    self.barSpace = space
end

-- The hovered spell (TK.ManaPreview, core/tooltip.lua: its name, nil on leaving): what it would heal or take (V.SpellEffect)
TK.On("TK_MANA_PREVIEW", function(_, _, name)
    local amount, kind = V.SpellEffect(name)
    C.preview = amount and { amount = amount, kind = kind } or nil
end)
