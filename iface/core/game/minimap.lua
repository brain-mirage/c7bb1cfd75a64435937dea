-- s6-input (round 49; docs/development/interface-separation.md, step 4b and section 5.10): the original's minimap button
-- as the game layer gives it to every interface: TK.Game.Minimap. One copy of the press that Modern's minimap Map button
-- and 7.x's minimap button each made. The map window it opens (a tool), its markers and traversal are core/mapwindow.lua,
-- core/mapmarkers.lua and core/maptraversal.lua.
--
-- Wire: MiniMapButtonPane::HandlePointerOrMouseEvent 0x005036A0 runs m's action on its click (UserPane::SendOpcode7CPacket:
-- 7C, by the rules' DialogRules.MinimapKey), and its button gets no press while the model's MiniMapDialog is open (that
-- dialog is modal). The caller's frame carries the "minimap" action (TK.Actions:Set, frozen as its input begins) and calls
-- Press on its click. Changing when Press runs the action changes what the server sees.

TK.Game = TK.Game or {}
local M = {}
TK.Game.Minimap = M

--- The minimap button's click: the frozen "minimap" action (7C), unless the model's minimap dialog is open.
function M.Press()
    if not TK.MapWindow:ModelOpen() then TK.Actions:RunFrozen() end
end

--- The frame an interface draws its minimap in (Modern's minimap gives it), for what keeps clear of it (the Debug
--- page's panel); nil in an interface without one, or once that minimap's panel is turned off (round 52: its frame
--- destroyed, step 11). Drawing only.
function M.SetFrame(frame) M.frame = frame end
function M.Frame()
    if TK.IsDead(M.frame) then M.frame = nil end
    return M.frame
end

return M
