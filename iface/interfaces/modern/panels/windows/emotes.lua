-- The emote menu (plan D19): the original's sixteen expressions, which it offers only through a one-key prompt
-- (":" then a-p): the game layer's (TK.Game.Emotes, core/game/emotes.lua, with each one's 1D byte). Each button carries
-- its action (TK.Actions).
--
-- It is the window of the game layer's "emotes" view (TK.Game.Views, s6-interface-5x round 12, step 1), whose key is
-- TOGGLEEMOTES (Shift+;, which types the original's ":").

local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin

local E = {}
TK.Emotes = E

local window

local function build()
    window = W.Window("TKEmoteMenu", "Emotes", 300, 290)
    TK.GetComponent("windows"):Own(window) -- (as the character window: made by the shared widgets, it goes with the windows)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    for i, e in ipairs(TK.Game.Emotes.list) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local b = W.Button(window, e[2], 128, 24, nil, function() TK.Actions:RunFrozen() end)
        TK.Game.Emotes.Action(b, e[3])
        b:SetPoint("TOPLEFT", window, "TOPLEFT", 16 + col * 140, -40 - row * 29)
        window["emote" .. e[1]] = b
    end
end

function E:IsOpen() return window ~= nil and window:IsShown() end

TK.Game.Views.SetWindow("emotes", {
    panel = { component = "windows", node = "emotes", switch = "enabled" }, -- its switch (Modern's panel; step 1)
    Open = function()
        if not window then build() end
        window:Show()
    end,
    Close = function() if window then window:Hide() end end,
    IsOpen = function() return E:IsOpen() end,
})

