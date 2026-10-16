-- Modern's windows (s6-modular-g round 16, separation step 7; docs/development/interface-separation.md, sections 4.1
-- and 5.1): the character window with its Spell Book, Legend and Collection tabs, the look window, the Social window and
-- the emotes. Each is the window of the game layer's views (TK.Game.Views.SetWindow), asked only while its switch on
-- this panel's page is on (settings.lua); the controls inside them are the game layer's (TK.Game.SelfLook, Spells,
-- Look, Social, Emotes), so these files draw and place, and send nothing of their own. A window turned off closes here.
-- Round 17 (step 7's last part): the Game Options window (gameoptions.lua), the game layer's options fallback
-- (TK.Game.Options.SetWindow), with its own switch since round 18.

local C = TK.GetComponent("windows")

-- In the order core/ loaded them before the move: the spell book is a tab of the character window.
require("interfaces.modern.panels.windows.character")
local spellbook = require("interfaces.modern.panels.windows.spellbook")
require("interfaces.modern.panels.windows.social")
require("interfaces.modern.panels.windows.look")
require("interfaces.modern.panels.windows.emotes")
local options = require("interfaces.modern.panels.windows.gameoptions")

function C:ApplySettings()
    TK.Game.Views.CloseOff()
    options:CloseOff()
    spellbook.MarkShown() -- s6-ui-core (round 83): the Character Window's red-edge switches
end
