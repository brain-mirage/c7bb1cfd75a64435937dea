-- s6-gateway-research (round 37, P3; head note 106): the game layer's help tip on a pane's right press, for any
-- interface. It is the one copy of a rule the 7.x interface's clock, look and self look each held (the doubled rules,
-- research 2026-10-13-gateway-and-one-engine/inventory-doubled-rules.md rows 4, 8 and 11). The interface shows the tip
-- (its help line) and its text; whether a press shows one, and for how long, is decided here.
--
-- WIRE: 4a's HourPane::HandlePointerOrMouseEvent (0x004CEF30), UserLookPane's (0x005A1580) and SelfLookPane's (0x00568CB0)
-- show their help for a single right press only (event type 4), so a right double press (type 5) shows none, and
-- SelfLookPane none while the bow is drawn (its IsBowDrawing test comes first). The tip lives 5000 ms, and its catcher
-- uses up the next press (interfaces/original/helppane.lua's Help.Show). So a tip 4a does not show would take a press 4a
-- sends on (the look's Trade, 4A 00), and a tip that lives longer or shorter takes a press 4a would send on or lets one
-- through that 4a takes. Changing the press test, the bow test or the life changes what the server sees.

TK.Game = TK.Game or {}
local T = {}
TK.Game.Tips = T

--- How long a pane's help tip lives, in milliseconds (the panes' 5000).
T.LIFE = 5000

--- The tip's life when this press on a pane shows its help tip, else nil. bowFirst: the pane tests the bow first
--- (SelfLookPane), so with the bow drawn the press shows none.
function T.ForPress(button, double, bowFirst)
    if button ~= "RightButton" or double then return nil end
    if bowFirst and __tk:IsBowDrawing() then return nil end
    return T.LIFE
end

return T
