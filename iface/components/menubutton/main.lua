-- s6-modular-g (interfaces, phase 2): the menu button (settings.lua): a press opens or closes the game menu, our
-- tool, which sends nothing. Shown in the game only, over the panels.

local C = TK.GetComponent("menubutton")
local W = TK.UI

function C:OnEnable()
    local b = W.Button(UIParent, "Menu", 44, 16, nil, function() TK.GameMenu:Toggle() end)
    b:SetFrameStrata("HIGH")
    b:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine("Game Menu", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    _G.TKMenuButton = b
    self.button = b
    TK.Visibility:Attach(b, function() return self:DB() end)
    TK.EditMode:Register(b, "menubutton", "Menu Button", C.defaultPosition, "menubutton")
end

function C:ApplySettings()
    TK.Visibility:Apply(self.button)
end
