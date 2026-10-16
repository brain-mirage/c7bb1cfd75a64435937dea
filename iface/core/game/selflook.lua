-- s6-interface-5x (round 11, W1; round 12, steps 1 and 2; docs/development/interface-separation.md, 5.5): the game
-- layer's self look. Its first part: whether 4a's tab 0 (SelfLookPane) is the active side panel tab, which decides the
-- look and equipment keys' sender: with tab 0 active, E and G go through SelfLookPane's SendToggleLook /
-- SendToggleEquip, which share a one-second stamp (SelfLookPane.cpp:26-27, 513-549); with another tab, UserPane sends
-- 1B 01 08 / 02 00 itself, unlimited (UserPane::HandleKeyOrTextEvent 0x005A5BD0, UserPane.cpp:1584-1614). The tab
-- itself is the game layer's side panel's (core/game/sidepanel.lua: one for the session, switched by the packets and
-- the openers, kept across a UI reload), whatever an interface draws. Original Commands reads Showing()
-- (components/originalkeys/main.lua). Wire: changing what this answers changes what E and G send, and when.

TK.Game = TK.Game or {}
local S = TK.Game.SelfLook or {}
TK.Game.SelfLook = S

--- Whether 4a's tab 0, the self look, is the active tab now.
function S.Showing() return TK.Game.SidePanel.Is(0) end

-- ----- the self look's controls (round 12, step 2), for any interface's self look: Modern's character page, 7.x's and
-- 5.x's side panel self pages. They were the character window's (core/character.lua's pressControl, its switch buttons
-- and gear slots), reached by the other interfaces through CW.PressControl.

--- A control of the self-look pane (or the look page): its action on the left press (the panes' type 1), as the
--- original's; a double press (type 2) does nothing (SelfLookPane.cpp:1184, UserLookPane.cpp:719 handle type 1 only), and
--- nor does any release. Wire: the press is what the server sees; acting on a release or a double press changes it.
function S.PressControl(b)
    b:HookScript("OnMouseDown", function(_, button, double)
        if button == "LeftButton" and not double then TK.Actions:RunFrozen() end
    end)
end

-- The self-look pane's switches (SelfLookPane::HandlePointerOrMouseEvent 0x00568CB0), by the option each sends: buttons 0
-- and 1 send 1B 01 08 / 02 00 through the pane's senders (SendToggleLook / SendToggleEquip: their shared one-second stamp,
-- refused while the state from 0x39 is 0xFF); buttons 5 and 6 send 1B 01 0E / 0F straight through
-- NewOptionPane::SendOpcode1BSubcode01Packet (three bytes, no stamp, no refusal; SelfLookPane.cpp:1216-1218, 1253-1255).
-- Each is a press on the "selflook" path, whose rule (KeyCommandRules.Option) sends it. Their names: the original's keys
-- for 8 and 2 are E and G, and the servers name the four options Exchange, Group, Show Helmet and Show Necklace.
S.SWITCHES = {
    { id = "exchange", option = 8 }, { id = "group", option = 2 }, { id = "helmet", option = 14 },
    { id = "necklace", option = 15 },
}

--- A switch control: option (8, 2, 14 or 15) on the self-look path, run on its left press. Wire: as S.SWITCHES says.
function S.SwitchControl(b, option)
    TK.Actions:Set(b, "option", nil, option)
    TK.Actions:SetPath(b, "selflook")
    S.PressControl(b)
end

--- The switches' states as the rules and the server's options hold them, by S.SWITCHES' ids (1 on, 0 off; 0xFF before
--- the server's 0x39, -1 offline: not known).
function S.States()
    local s = {}
    s.exchange, s.group, s.helmet, s.necklace = __tk:GetSelfLookStates()
    return s
end

--- A worn item control: on the self-look path, its action (S.TakeOff) run on the left press (the same handler,
--- SelfLookPane.cpp:1221). Wire: the press is what the server sees.
function S.WornControl(b)
    TK.Actions:SetPath(b, "selflook")
    S.PressControl(b)
end

--- A worn item control's action: taking off what slot code holds (1F and the slot's code), whether an item is worn there
--- or not. Wire: 4a's slot boxes are fixed (SelfLookPane::GetSlotRect, view 0) and a press on one sends
--- SendTakeOffPacket 0x005B27C0 with no item test (SelfLookPane.cpp:1220-1265), so an empty slot sends its 1F too
--- (s6-interface-5x round 13, s6-optimize's FOR-s6-interface-5x-r13 item 1: it sent nothing). Every interface's worn
--- control passes its slot's code, empty or not. Changing this changes what the server sees.
function S.TakeOff(b, code)
    TK.Actions:Set(b, "takeoff", nil, code)
end

--- Take Off All, the take-off prompt's A (fourteen 1F in its order; D19's default route), on the press as the pane's own
--- controls (s6-ui-character, review r1, finding 3). Wire: the fourteen 1F and their order are 4a's
--- (TakeOffInputPane::InvokeAcceptedAction 0x005B2830's "A", SendTakeOffPacket 0x005B27C0 each); changing this changes
--- what the server sees.
function S.TakeOffAllControl(b)
    TK.Actions:Set(b, "takeoffall")
    S.PressControl(b)
end

--- Bare hands: the weapon off, as the original's wield prompt's "-" (12 00; D19's default route), the control's action;
--- its interface runs it from its click (TK.Actions:RunFrozen). Wire: 12 00 is the wield prompt's packet with slot 0
--- (WieldInputPane::SendWieldPacket 0x005B6500); changing this changes what the server sees.
function S.BareHandsAction(b) TK.Actions:Set(b, "barehands") end

--- A worn place's local sheet, with its drawing supplying the record lookup (5.x record, 7.x gear code).
--- WIRE: SelfLookPane::HandlePointerOrMouseEvent 0x00568CB0 case 4 takes the single right press and shows
--- ItemHelpPane unless the bow is drawn. No packet is sent; changing it changes the next consumed game press.
function S.WornHelp(b, owner, sheet, record)
    b:HookScript("OnMouseDown", function(_, button, double)
        if button ~= "RightButton" or double or __tk:IsBowDrawing() then return end
        local ok, _, _, name, iconId, key, value, protection = record()
        if ok and iconId >= 0 and iconId ~= 0x4000 then sheet.Show(owner, key or "", name or "", value, protection) end
    end)
end

--- The worn record for an original gear code (7.x's rectangles use codes, rather than record order).
function S.EquipmentForCode(code)
    for i = 1, __tk:GetNumEquipmentSlots() do
        local ok, available, slot, name, iconId, key, value, protection = __tk:GetEquipment(i)
        if slot == code then return ok, available, slot, name, iconId, key, value, protection end
    end
    return false
end

return S
