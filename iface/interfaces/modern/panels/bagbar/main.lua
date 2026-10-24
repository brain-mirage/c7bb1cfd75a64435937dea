-- The bag bar: one bag button (Nexus has one inventory of 52 lettered slots) showing how many slots are free.
-- It opens the bag window (panels/bag, window.lua).
-- s6-ui-core (round 85): the XML twin's scripts; the bar and its button are main.xml's (core/xml.md).

local C = TK.GetComponent("bagbar")
local H = __tk
local E = require("interfaces.modern.elements")

local SLOTS = 52

-- The B key (TOGGLEBAG) opens the bag too: the game layer's (core/game/views.lua).

local function freeSlots()
    local used = 0
    for i = 1, SLOTS do
        if H:GetItemSlot(i) then used = used + 1 end
    end
    return SLOTS - used
end

-- the scripts main.xml names
local scripts = {}

function scripts.Open() TK.Game.Views.Toggle("bag") end

function scripts.Tip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Bag", 1, 1, 1)
    GameTooltip:AddLine(freeSlots() .. " of " .. SLOTS .. " slots free", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function scripts.Untip() GameTooltip:Hide() end

function scripts.Changed() C:Update() end

function C:OnEnable()
    local f = TK.Xml.Load("main.xml", { scripts = scripts, elements = E }).frame
    self.frame, self.button = f, TKBagButton
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
