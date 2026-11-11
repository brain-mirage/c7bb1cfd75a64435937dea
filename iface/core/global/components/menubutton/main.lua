-- s6-modular-g (interfaces, phase 2): the menu button (settings.lua): a press opens or closes the game menu, our
-- tool, which sends nothing. Shown in the game only, over the panels.
-- s6-ui-core (round 124, the Global Interface's C# shell, piece 1): the button is the shell's (Runtime/Shell/GlobalShell.cs):
-- it toggles the game menu in C#, and shows itself when our Lua fails to start. This component keeps the rest: its tooltip,
-- its Visibility rule (the Enabled switch), edit mode's place and its page.

local C = TK.GetComponent("menubutton")

function C:OnEnable()
    local b = TK.Wrap(__tk:ShellMenuToggleButton())
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
    -- GA-3 (2026-11-10, the client review's 8.10): where the button is shown (on in 7.x's and 5.x's profiles, off in
    -- Modern's, which has its own small menu), it is the way into Settings; one chat line says so, once a run, the first
    -- time the player is in the world with it shown. Shown only: nothing is sent.
    local told = false
    local function tell()
        if told or not TK.GameState:InWorld() or not b:IsShown() then return end
        told = true
        TK.FireEvent("TK_CLIENT_MESSAGE", "The Menu button opens the game menu and Settings.",
            TK.Chat:PaletteRGB(143) or TK.Chat.colours.say, TK.Chat:PaletteRGB(1), true)
    end
    TK.On("TK_GAME_STATE", tell)
    TK.On("TK_INTERFACE_CHANGED", tell)
end

function C:ApplySettings()
    TK.Visibility:Apply(self.button)
end
