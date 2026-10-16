-- s6-interface-5x (round 12; docs/development/interface-separation.md, step 1 and section 5.2): the game layer's side
-- panel, 4a's one GeneralPurposePanel (constructor 0x004B83D0) and UserPane's tab rules, whatever an interface draws.
-- 4a keeps seven tab panes, one active at a time: 0 the self look, 1 another player's look, 2 the items, 3 the spells,
-- 4 the group, 5 the collection, 6 the options. There is one active tab for the session, kept here; every interface's
-- pages follow it (7.x's side panel shows the active tab's page, 5.x's its own page for it, Modern's windows stand in),
-- and nothing of an interface's is asked to decide it. It was 7.x's own state and the game layer's apart before (round 11,
-- core/game/selflook.lua's tab), which let them part (Astra's reviews of round 11).
--
-- It is switched:
--   * by the packets, in the logic's order (the rules' notices, taken by the UI before any input after their packet:
--     GameConnection.CatchUp; a key routed before them waits: InputHost.GameKey): a 0x39 to 0 (SwitchPanelTab0WithClick
--     0x005139B0, the login's too), a 0x34 to 1 (SwitchPanelTab1WithClickAndStopTimer 0x005119B0), a collection page list
--     to 5 (HandleCollectionDialogPacket 0x00514480), the server's 0x3E 0 and 2 to 2 and 3 (HandleUIPanelSwitchPacket
--     0x005ABDA0), a spell prompt's ? to 3 and an item prompt's ? to 2 (their HandleKeyOrTextEvent);
--   * by the player's openers, as 4a's keys, icons and tab buttons switch (SwitchActiveTab 0x004B8650): the items 2, the
--     spells 3, the group 4, the collection 5 once its list has come, the options 6 (TK.Game.Views' openers, 7.x's tab
--     strip); the self look and another player's look are only asked for (2D 00, a click): their packets switch;
--   * Macro Setup's opening to 3 (IntegrateMacroDialog 0x00541B30, the rules' notice).
-- SwitchActiveTab refuses a switch to the tab already active, but the self look's and the look's (each new 0x39 or 0x34
-- reaches them). A refused switch is no new activation: the group's page is not shown again, so a second Group press
-- sends no 2D 01 (NewGroupPane::OnActivate 0x0056CB80). The active tab decides E's and G's sender (tab 0: SelfLookPane's,
-- with its one-second stamp, UserPane.cpp:1584-1614) and whether S is the self look's (SelfLookPane.cpp:1067) or
-- UserPane's 2D 00 (UserPane.cpp:1546). A new game screen starts with no tab (-1). A UI reload keeps the session's tab: it
-- is kept on the host (__tk:PanelTab, which outlives the Lua state) and read back when the UI starts.
-- Wire: changing when this switches, or what it refuses, changes what the server sees.

TK.Game = TK.Game or {}
local SP = {}
TK.Game.SidePanel = SP

-- 4a's tab indexes (GeneralPurposePanel's child panes, in tab order) and their names.
SP.TABS = { [0] = "self", "look", "items", "spells", "group", "collection", "options" }
SP.INDEX = {}
for i = 0, 6 do SP.INDEX[SP.TABS[i]] = i end

local active = __tk:PanelTab() -- -1 at the client's start; the session's tab after a UI reload

--- The active tab's index (-1: none yet).
function SP.Active() return active end

--- Whether the active tab is tab (an index or a name).
function SP.Is(tab) return active == (SP.INDEX[tab] or tab) end

--- SwitchActiveTab: tab (an index or a name) becomes the active one, unless it already is (the self look's and the look's
--- excepted). True when it switched; TK_SIDE_PANEL_TAB (index, view) then fires at once, in the input or the notice that
--- switched it, so the interfaces' pages and the keys' routes follow before the next key. view: a 0x39's self-look view
--- (s6-interface-7x-b round 5: RuleNotice.PanelView, SelfLookPane::OnActivate 0x00565890), else nil.
function SP.Switch(tab, view)
    local i = SP.INDEX[tab] or tab
    if type(i) ~= "number" or not SP.TABS[i] then return false end
    if active == i and i > 1 then return false end
    active = i
    __tk:SetPanelTab(i)
    TK.FireEvent("TK_SIDE_PANEL_TAB", i, view)
    return true
end

--- A new game screen (the login's accepted 02): no tab, as GeneralPurposePanel's constructor leaves it.
function SP.Reset()
    active = -1
    __tk:SetPanelTab(-1)
    TK.FireEvent("TK_SIDE_PANEL_TAB", -1)
end

-- ----- the requests UserPane sends without switching -----

-- An invisible frame per request, carrying the open action the press or key froze (as a page carries its own): shown in
-- the input, it sends it (plan 5.9, D20). Attached while the UI loads.
local carriers = {}
for kind, action in pairs({ self = "open:character", collection = "open:collection" }) do
    local f = CreateFrame("Frame", nil, UIParent)
    f:Hide()
    carriers[kind] = f
    TK.On("PLAYER_LOGIN", function() TK.Actions:SetOpen(f, action) end)
end

--- s6-interface-5x (round 12, from 7.x's side panel; Astra's s6-interface-5x-self-12-1): the requests 4a's UserPane
--- sends without switching the tab: "self", RequestLocalPlayerStatus (0x005A4F70; the self tab's button and the S key):
--- 2D 00; "collection", SwitchToCollectionTab while the collection's list has not come (0x005A4EA0; its button and key):
--- 27 00 00, then it returns. Wire: neither switches; the server's answer does (the 0x39: SwitchPanelTab0WithClick; the
--- page list: HandleCollectionDialogPacket 0x00514480; both TK_RULES_PANEL_TAB), so a second press before that answer
--- asks again (Group, Collection, Group then sends no second 2D 01). Only in the input that froze the request's kind.
--- Changing this changes what the server sees.
function SP.Request(kind)
    local carrier = carriers[kind]
    carrier:Hide()
    carrier:Show()
end

--- The collection tab's button or key (UserPane::SwitchToCollectionTab 0x005A4EA0): its request while the list has not
--- come (SP.Request), else the switch (SwitchActiveTab(5): refused while it is the active tab). Wire, as both.
function SP.CollectionTab()
    if __tk:IsCollectionLoaded() then
        SP.Switch(5)
    else
        SP.Request("collection")
    end
end

TK.On("TK_RULES_PANEL_TAB", function(_, tab, view) SP.Switch(tab, view) end)
TK.On("TK_RULES_SPELL_TAB", function() SP.Switch(3) end)
TK.On("TK_RULES_ITEM_TAB", function() SP.Switch(2) end)
TK.On("TK_SESSION_STATE", function(_, state) if state == "Accepted" then SP.Reset() end end)

return SP
