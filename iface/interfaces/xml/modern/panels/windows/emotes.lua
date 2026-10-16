-- The emote menu (plan D19): the original's sixteen expressions, which it offers only through a one-key prompt
-- (":" then a-p): the game layer's (TK.Game.Emotes, core/game/emotes.lua, with each one's 1D byte). Each button carries
-- its action (TK.Actions).
--
-- It is the window of the game layer's "emotes" view (TK.Game.Views, s6-interface-5x round 12, step 1), whose key is
-- TOGGLEEMOTES (Shift+;, which types the original's ":").
-- s6-ui-core (round 85): the XML twin's scripts; the window and its buttons' places are emotes.xml's (core/xml.md).

local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local EL = require("interfaces.modern.elements")

local E = {}
TK.Emotes = E

local window
local L = TK.Xml.Data("emotes.xml")

-- the scripts emotes.xml names
local scripts = {}

function scripts.Own(f) TK.GetComponent("windows"):Own(f) end

-- WIRE: a press runs the action its button carries (TK.Game.Emotes.Action: the expression's 1D with its byte, as 4a's
-- EmotionInputPane::SendEmotionPacket 0x005B2F70 sends it for the prompt's letter). Changing the action changes what the
-- server sees.
function scripts.Buttons(f)
    local B = L.BUTTONS
    for i, e in ipairs(TK.Game.Emotes.list) do
        local col, row = (i - 1) % B.columns, math.floor((i - 1) / B.columns)
        local b = W.Button(f, e[2], B.width, B.height, nil, function() TK.Actions:RunFrozen() end)
        TK.Game.Emotes.Action(b, e[3])
        b:SetPoint("TOPLEFT", f, "TOPLEFT", B.x + col * B.dx, B.y - row * B.dy)
        f["emote" .. e[1]] = b
    end
end

local function build()
    window = TK.Xml.Load("emotes.xml", { scripts = scripts, elements = EL }).window
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
