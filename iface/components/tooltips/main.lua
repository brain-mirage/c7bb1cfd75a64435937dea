-- Tooltips (plan 5.11, UI head note 40): one tooltip (core/tooltip.lua's GameTooltip) for everything hovered, where
-- the Position setting puts it. This component adds the world's own: hovering the world view names the player,
-- creature, NPC or item there. A figure stands about a tile and a half tall, so the cell below the mouse is looked at
-- first, then the mouse's own cell (as the original's hit test searches the row below first). With no figure there,
-- the items on the cell under the mouse are listed, the top one first, each with its picture as the ground draws it
-- (s6-characters' cell items). An item's name is the one this client learned from 0x0F on this server, else "Unknown
-- item". Only what the client knows; nothing is asked.

local C = TK.GetComponent("tooltips")
local H = __tk

local KIND = { player = "Player", npc = "NPC", creature = "Creature", item = "Item on the ground" }

--- The object to name at a map cell: a player or creature standing on the cell below or on it, else an item on it.
local function objectAt(x, y)
    local below, here, item
    for i = 1, H:GetNumObjects() do
        local _, id, kind, ox, oy = H:GetObjectInfo(i)
        if ox == x then
            if kind ~= "item" and oy == y + 1 then below = below or id
            elseif kind ~= "item" and oy == y then here = here or id
            elseif kind == "item" and oy == y then item = id end
        end
    end
    return below or here or item
end

--- The ground items on the cell under the mouse, the top one first: { id, name, key, w, h }.
local function cellItems(view)
    local x, y = view:CentrePoint() -- s6-world-view (round 31): the logic's map point
    local n = H:GetNumCellItems(x, y)
    local items = {}
    for i = n, 1, -1 do
        local ok, id, _, _, key, iw, ih = H:GetCellItem(i)
        if ok then
            local _, _, name = H:GetObjectTooltip(id)
            items[#items + 1] = { id = id, name = (name or "") ~= "" and name or "Unknown item", key = key, w = iw, h = ih }
        end
    end
    return items
end

--- What the items' tooltip shows: each item and its picture's texture key, so a new picture (another drawing style)
--- is shown again as a new item would be (s6-modular-c).
function C.ItemsShown(items)
    local key = "items"
    for _, it in ipairs(items) do key = key .. ":" .. it.id .. "=" .. it.key end
    return key
end

function C:OnEnable()
    local watcher = self:Own(CreateFrame("Frame", "TKTooltipsWorld", UIParent))
    local shown
    local function hide()
        local view = TK.GetComponent("worldview")
        if shown and view and GameTooltip:GetOwner() == view.frame then GameTooltip:Hide() end
        shown = nil
    end
    watcher:SetScript("OnUpdate", TK.Util.Throttled(0.1, function()
        local view = TK.GetComponent("worldview")
        if not self:DB().world or not TK.GameState:InWorld() or not (view and view.frame and view.frame:IsVisible())
            or GetMouseFocus() ~= view.frame then
            return hide()
        end
        -- s6-ui-core (round 43): an effect icon under the pointer has its own tooltip, which Effects on Others shows (its
        -- icons take no mouse, so the world view still has the focus there). s6-input (round 49, separation step 4b): it
        -- claims the world's tooltip (TK.ClaimWorldTip, core/tooltip.lua).
        if TK.WorldTipClaimed() then return hide() end
        local vx, vy = view:TileAtCursor()
        if not vx then return hide() end
        -- s6-reprojection (round 46): while a world renderer draws the figures (3D-Sen, 3D-Sen-Sphere), the figure it draws
        -- under the mouse (the drawing's pick, as the nameplates' hover), not the cells of Normal's picture; the cell items
        -- below follow its drawing too (GetNumCellItems). Nothing is asked.
        local cx, cy = view:CentrePoint()
        local figureId, followsDrawing = H:GetFigureAt(cx, cy)
        local id
        if followsDrawing then
            id = figureId ~= 0 and figureId or nil
        else
            local ox, oy = H:GetTileOrigin()
            id = objectAt(ox + vx, oy + vy)
        end
        local ok, kind, name
        if id then ok, kind, name = H:GetObjectTooltip(id) end
        if not (ok and kind ~= "item") then
            -- No figure there: the cell's items, when the drawing lists them.
            local items = cellItems(view)
            if #items > 0 then
                local key = C.ItemsShown(items)
                if key == shown and GameTooltip:GetOwner() == view.frame then return end
                shown = key
                GameTooltip:SetOwner(view.frame, "ANCHOR_CORNER")
                if #items > 1 then GameTooltip:AddLine(#items .. " items on the ground", 0.75, 0.75, 0.75) end
                for _, it in ipairs(items) do
                    GameTooltip:AddLine(it.name, 1, 0.82, 0)
                    GameTooltip:AddTexture(it.key, it.w, it.h)
                end
                if #items == 1 then GameTooltip:AddLine(KIND.item, 0.75, 0.75, 0.75) end
                GameTooltip:Show()
                return
            end
        end
        if not ok then return hide() end
        if id == shown and GameTooltip:GetOwner() == view.frame then return end
        shown = id
        GameTooltip:SetOwner(view.frame, "ANCHOR_CORNER")
        local colour = kind == "player" and { 1, 1, 1 } or kind == "npc" and { 0.4, 1, 0.4 } or kind == "item"
            and { 1, 0.82, 0 } or { 1, 0.45, 0.35 }
        -- s6-ui-core (round 28; head note 58): a monster whose name isn't known has no name line, only its kind.
        if name ~= "" or kind == "item" then
            GameTooltip:AddLine(name ~= "" and name or "Unknown item", colour[1], colour[2], colour[3])
        end
        GameTooltip:AddLine(KIND[kind] or kind, 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end))
end

--- The settings are read when a tooltip shows: nothing to apply.
function C:ApplySettings() end
