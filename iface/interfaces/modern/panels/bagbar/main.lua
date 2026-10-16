-- The bag bar: one bag button (Nexus has one inventory of 52 lettered slots) showing how many slots are free.
-- It opens the bag window (panels/bag, window.lua).

local C = TK.GetComponent("bagbar")
local H = __tk
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin

local SLOTS = 52

-- The B key (TOGGLEBAG) opens the bag too: the game layer's (core/game/views.lua).

local function freeSlots()
    local used = 0
    for i = 1, SLOTS do
        if H:GetItemSlot(i) then used = used + 1 end
    end
    return SLOTS - used
end

function C:OnEnable()
    local f = CreateFrame("Frame", "TKBagBar", UIParent)
    f:SetSize(40, 40)
    local b = CreateFrame("Button", "TKBagButton", f)
    b:SetSize(38, 38)
    b:SetPoint("CENTER", f, "CENTER", 0, 0)
    -- s6-ui-core (round 62): the shared slot's picture, an action button's edge, the light
    b.icon = select(2, W.SlotArt(b, { edge = W.slotActionEdge, inset = 3 }))
    -- s6-ui-settings (the owner, 2026-10-03): the brown backpack, the Micro Menu's bag button's icon too.
    b.icon:SetTexture("tk:backpack")
    b.free = W.Label(b, "", 11, W.white)
    b.free:SetFont(11, "OUTLINE")
    b.free:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.free:SetJustifyH("RIGHT")

    b:SetScript("OnClick", function() TK.Game.Views.Toggle("bag") end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Bag", 1, 1, 1)
        GameTooltip:AddLine(freeSlots() .. " of " .. SLOTS .. " slots free", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f:RegisterEvent("BAG_UPDATE")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function() self:Update() end)
    self.frame, self.button = f, b
    TK.Visibility:Attach(f, function() return self:DB() end)
    TK.EditMode:Register(f, "bagbar", "Bag Bar", C.defaultPosition, "bagbar")
end

function C:Update()
    self.button.free:SetText(self:DB().showFree and tostring(freeSlots()) or "")
end

function C:ApplySettings()
    self:Update()
    TK.Visibility:Apply(self.frame)
end
