-- s6-interface-5x (round 12; docs/development/interface-separation.md, step 2 and section 5.6): the game layer's look at
-- another player (S 0x34), whatever an interface draws: Modern's look window, 5.x's side panel look page (7.x's tab 1 is
-- its gap X1). The new look's driver, which opens the look view, is TK.Game.Views'.

TK.Game = TK.Game or {}
local L = {}
TK.Game.Look = L

--- A look page's action button: Trade ("look:trade": 4A 00 and the player's id) or Group ("look:group": 2E and the name),
--- the original's buttons 0 and 1, run on the left press (UserLookPane::HandlePointerOrMouseEvent, type 1; the release
--- sends nothing). Their rule (TK-Core LookRules) sends them, and refuses both while the look's gate byte is 0xFF, when
--- the original shows no buttons. Wire: the action and the press are what the server sees.
function L.ActionButton(b, kind)
    TK.Actions:Set(b, kind)
    TK.Game.SelfLook.PressControl(b)
end

return L
