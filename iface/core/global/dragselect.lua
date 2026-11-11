-- s6-input: the casters' drag-select box (the owner's request of 2026-10-04, docs/user-related/requests/
-- 2026-10-04-multiselect-drag-select.md). While a left drag on the map's empty ground selects creatures for the spell sweep
-- (the logic's InputHost.DragSelect), a thin box shows where it reaches, cut to the active area. It draws the logic's own
-- box (__tk:GetDragBox) and never takes the mouse, so the drag's events reach the world as they would without it. Display
-- only: nothing is sent. The selected creatures' corner markers are the world drawing's (WorldObjects.Mark).

TK.DragSelect = {}
local D = TK.DragSelect
local H = __tk

-- The box's look: a 1-pixel white outline over a faint white fill.
local EDGE, FILL = { 1, 1, 1, 0.9 }, { 1, 1, 1, 0.08 }

local function texture(parent, layer, colour)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(colour[1], colour[2], colour[3], colour[4])
    return t
end

function D:Build()
    -- A container over the whole screen that never takes the mouse, shown always, so its OnUpdate runs every frame.
    local root = CreateFrame("Frame", "TKDragSelect", UIParent)
    root:SetAllPoints(UIParent)
    root:SetFrameStrata("LOW")
    local box = CreateFrame("Frame", "TKDragSelectBox", root)
    texture(box, "BACKGROUND", FILL):SetAllPoints(box)
    local top, bottom, left, right =
        texture(box, "OVERLAY", EDGE), texture(box, "OVERLAY", EDGE), texture(box, "OVERLAY", EDGE), texture(box, "OVERLAY", EDGE)
    top:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
    top:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)
    left:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)
    right:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)
    box:Hide()
    self.root, self.box = root, box
    root:SetScript("OnUpdate", function() TK.SafeCall(D.Refresh, D) end)
end

--- Each frame: the box where the logic has it (the root's units from its bottom left), or hidden.
function D:Refresh()
    local shown, x, y, w, h = H:GetDragBox()
    local box = self.box
    if not shown or w <= 0 or h <= 0 then
        if box:IsShown() then box:Hide() end
        return
    end
    box:ClearAllPoints()
    box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    box:SetSize(w, h)
    if not box:IsShown() then box:Show() end
end

D:Build()
