-- Original Commands (plan D19, coverage-matrix.md "Key bindings"): the original's key commands that no other
-- component reaches, each a bindable command that runs one action through the rules (TK.Actions), with the original's
-- key as its default where that key is free here. Classic commands (opt-in) are a second route and never count.
--
-- What each sends is the rules' (UserPane::HandleKeyOrTextEvent 0x005A5BD0; s6-rules-items' KeyCommandRules and
-- ItemRules, s6-rules-dialogs' DialogRules):
--   Look Toggle, Equipment Toggle              E, G: 1B 01 08 / 02 00, by the self-look pane's senders while its view
--                                              shows (below)
--   Show Helmet, Show Necklace                 no key in 4a (the self look's slots 5 and 6): 1B 01 0E / 0F, three bytes,
--                                              not while the bow is drawn (s6-interface-5x-b, round 7, Y7)
--   Clan Whisper (option 10; live 2026-10-01, C6) F: 1B 01 0A 00
--   Fixed Movement, Hear Whispers, Hear Shouts F4, F5, F6: 1B 01 07 / 01 / 03 00
--   Fast Walk                                  F12: 1B 01 09 (three bytes), the movement-status option turned over
--   Power                                      P: 4C 01 with the stored thresholds (GM accounts only)
--   Take Off                                   T: the take-off prompt (A everything: fourteen 1F; ? the 1-byte 2D)
--   Mixing, Friends, Fitting Room              I, F3, Shift+F9: the dialog model's MixItemDialog, FriendListDialog,
--                                              FittingRoomDialog
--   (none)                                     F1: the original opens help.nexustk.com/wiki in a BrowserDialog
--                                              (UserPane.cpp:1659-1676); the client never contacts Nexon's web
--                                              services (the head, 2026-10-01), so F1 opens nothing here
--   Original Macro Setup                       F11 in 4a: IntegrateMacroDialog; no key here, and listed only while
--                                              the macro window's setting shows it (s6-macros, the head's note 6:
--                                              F11 is the macro window's)
--   Sound On/Off                               F7: the sound effects and the music off or on together, here only
--   Music                                      F8: the Sound page, the music dialog's 1B 01 00 (below)
-- E, G, F, P, T and I are the original's capitals, Shift with the letter, as here. The keypad's digits are the action
-- bar's 1-0, as the original's keypad typed its digits (ToAscii).
--
-- The look and equipment keys (UserPane.cpp:1584-1614): with the side panel's tab 0 (SelfLookPane) active, E and G
-- call the pane's SendToggleLook / SendToggleEquip, which share a one-second stamp; with another tab active UserPane
-- sends 1B 01 08 / 02 00 itself, unlimited. Our tab 0 is the game layer's active tab (core/game/selflook.lua), whatever
-- the interface draws. A key binding carries no entry path, so these two keys run a control of this component's (never
-- drawn or clicked) whose path is "selflook" exactly while tab 0 is active; the rules pick the sender by it
-- (KeyCommandRules.Option).

local C = TK.GetComponent("originalkeys")

-- s6-rules-dialogs' DialogActions.Separator, between a dialog's class and its arguments.
local SEP = "\31"

local function option(n) return { kind = "option", amount = n } end
local function dialog(name, ...) return { kind = "dialog:open", text = table.concat({ name, ... }, SEP) } end

-- command, text, action, default key, the original's key and what it sends (for the settings page).
C.list = {
    { "LOOKTOGGLE", "Look Toggle", option(8), "SHIFT-E", "E: 1B 01 08 00" },
    { "EQUIPTOGGLE", "Equipment Toggle", option(2), "SHIFT-G", "G: 1B 01 02 00" },
    -- s6-interface-5x-b (round 7, s6-interface-5x's Y7; decision 2026-10-05-5x-route-to-752-only-windows): 7.5.2's
    -- Show Helmet and Show Necklace switches (the self look's slots 5 and 6), which 5.33's self look, and so 5.x's, has
    -- not, as commands with no default key. Each key runs a control on the "selflook" path (OnEnable), whose rule runs
    -- the pane's press (KeyCommandRules.Option: the bow gate, then 1B 01 0E / 0F). Wire: the option and the path are
    -- what the rules send by.
    { "SHOWHELMET", "Show Helmet On/Off", option(14), nil, "self look's Helmet switch" },
    { "SHOWNECKLACE", "Show Necklace On/Off", option(15), nil, "self look's Necklace switch" },
    { "OPTION10", "Clan Whisper On/Off", option(10), "SHIFT-F", "F: 1B 01 0A 00" }, -- the server says "Clan whisper :ON/OFF"
    { "FIXEDMOVEMENT", "Fixed Movement On/Off", option(7), "F4", "F4: 1B 01 07 00" },
    { "HEARWHISPERS", "Hear Whispers On/Off", option(1), "F5", "F5: 1B 01 01 00" },
    { "HEARSHOUTS", "Hear Shouts On/Off", option(3), "F6", "F6: 1B 01 03 00" },
    { "FASTWALK", "Fast Walk", option(9), "F12", "F12: 1B 01 09" },
    { "POWER", "Power (GM)", { kind = "power" }, "SHIFT-P", "P: 4C 01" },
    { "TAKEOFF", "Take Off...", { kind = "takeoff" }, "SHIFT-T", "T: the take-off prompt" },
    { "MIXING", "Mixing", dialog("MixItemDialog"), "SHIFT-I", "I: the mixing dialog" },
    { "FRIENDS", "Friends", dialog("FriendListDialog"), "F3", "F3: the friend list" },
    { "FITTINGROOM", "Fitting Room", dialog("FittingRoomDialog"), "SHIFT-F9", "Shift+F9: the fitting room" },
    { "MACROS", "Original Macro Setup", dialog("IntegrateMacroDialog"), nil, "F11: its Macro Setup" }, -- s6-macros: no default key
    -- s6-interface-5x (round 12, gap G6; decision 2026-10-05-5x-route-to-752-only-windows): the 7.5.2 windows opened only
    -- from its Menu popup or its say-mode menu, which 5.33 (and so 5.x) has not, as commands with no default key. Each is
    -- the dialog model's opener the Menu's row runs (DialogRules.OpenByPlayer: one at a time; MenuVarietySelectPane's rows,
    -- PaneDialogs.cs:239-244: the web board's mode 0, and mode 4 with the account's name for Userlook), so each window
    -- sends its own requests as when 7.5.2's row opens it. Wire: the action (class, mode, arguments) is what the rules run.
    { "RANKINGS", "Rankings", dialog("RankingDialog"), nil, "Menu, Ranking: the rankings" },
    { "WEBBOARD", "Web Board", dialog("WebBoardDialog"), nil, "Menu, Board: the web board" },
    { "USERLOOK", "Userlook", { kind = "dialog:open", amount = 4, text = "WebBoardDialog" }, nil,
      "Menu, Userlook: your own web page" },
    { "TARGETOPTIONS", "Target Options", dialog("TargetOptionDialog"), nil, "Menu, Target: the target options" },
    { "CHATCOLOUR", "Chat Colour", dialog("ChattingColorPane"), nil, "Say-mode menu, -Color-: the chat colours" },
}

local labels = TK.Actions.labels
labels.option = labels.option or "Option"
labels.power = labels.power or "Power"
labels["dialog:open"] = labels["dialog:open"] or "Open"

-- Each command's action goes with its key (the key layer "bindings"), so the key press freezes it (plan 5.9).
for _, c in ipairs(C.list) do
    TK.Bindings:RegisterCommand(c[1], c[2], function() TK.Actions:RunFrozen() end, c[3])
    if c[4] then TK.DB.defaultBindings[c[4]] = c[1] end -- s6-macros: MACROS has no default key
end

-- s6-interface-5x (round 12, G6): Userlook carries the account's name, as the Menu's row 0 (Session.Account): the
-- session's, set at each world entry, and the key layer pushed again so the key freezes it. Wire: the name is what the
-- web board asks for.
TK.On("PLAYER_ENTERING_WORLD", function()
    TK.Bindings.commands.USERLOOK.action = { kind = "dialog:open", amount = 4,
        text = "WebBoardDialog" .. SEP .. (__tk:GetSessionAccount() or "") }
    TK.Bindings:PushKeys()
end)

-- The keypad's digits: the original's hotkeys 1-9 and 0 (Event.cpp's table gives them the digits' codes). s6-modular-g
-- (round 19, the separation's step 8): bound to the game layer's carriers of slots 1-10 (TK.Game.Hotkeys), CLICK bindings
-- that keep a click's input path, as the digits'. Wire: changing what they name changes what the server sees.
for i = 0, 9 do
    TK.DB.defaultBindings["NUMPAD" .. i] = TK.Game.Hotkeys.Command(i == 0 and 10 or i)
end

-- ----- the look and equipment keys: the self-look pane's senders while its view shows -----

-- Two controls per key, whose paths never change: "selflook" for tab 0, none for any other. While 4a's tab 0 is the
-- active tab, the key runs the first; otherwise the second. The switch is made in the input or packet notice that changed
-- the tab (TK_SIDE_PANEL_TAB: the game layer keeps 4a's one active tab, switched by the packets and by the pages'
-- openers in every interface, core/game/sidepanel.lua) and pushes the key layer again (TK.Bindings:PushKeys): the input
-- host rebuilds its routes when a layer changes, and reuses them while each control's action and visibility stay (review
-- r2, finding 1); a key routed before a packet's switch waits for it (InputHost.GameKey). Hosts without entry paths (main
-- before the UI's input round) have no SetPath; nothing is sent there.
-- s6-interface-5x (round 11, W1): this followed Modern's window alone, so in 7.x and 5.x, with their own self look the
-- active tab, E and G skipped SelfLookPane's one-second stamp (SelfLookPane.cpp:513-549), and in Modern a closed window
-- or the login's 0x39 left them unlimited where 4a's tab 0 limits them. Wire: which control a key runs decides whether the
-- stamp applies; changing it changes what the server sees.

local function keyControl(name, option, path)
    local b = C:Own(CreateFrame("Button", name, UIParent))
    b:SetSize(1, 1)
    b:SetAlpha(0)
    b:EnableMouse(false)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    TK.Actions:Set(b, "option", nil, option)
    if path and TK.Actions.SetPath then TK.Actions:SetPath(b, path) end
    return b
end

--- The original's tab 0 is the active tab (the game layer's, core/game/selflook.lua).
function C:SelfLookShows() return TK.Game.SelfLook.Showing() end

--- Points the two commands at the controls for 4a's active tab now (no push).
function C:PointKeys()
    local shows = self:SelfLookShows()
    self.selfLook = shows
    TK.Bindings.commands.LOOKTOGGLE.action = shows and self.keys.lookTab or self.keys.look
    TK.Bindings.commands.EQUIPTOGGLE.action = shows and self.keys.equipTab or self.keys.equip
end

--- Points the two keys at the controls for the tab active now, and pushes the key layer again when that changed.
function C:SyncKeys()
    if not self.keys then return end -- a tab switched before this component's controls are made
    if self:SelfLookShows() == self.selfLook then return end
    self:PointKeys()
    TK.Bindings:PushKeys()
end

function C:OnEnable()
    self.keys = {
        look = keyControl("TKOriginalKeysLook", 8), equip = keyControl("TKOriginalKeysEquip", 2),
        lookTab = keyControl("TKOriginalKeysLookTab", 8, "selflook"),
        equipTab = keyControl("TKOriginalKeysEquipTab", 2, "selflook"),
    }
    -- TK.Bindings:PushKeys (at PLAYER_LOGIN) puts a command's frame in the key layer, so the key runs that control's
    -- action and path. From the tab active now: none at the client's start, the session's after a UI reload (round 12;
    -- the head's review of round 11, P1: the self look's stamp kept across a reload). Wire: as SyncKeys.
    self:PointKeys()
    -- Show Helmet and Show Necklace (s6-interface-5x-b, Y7): always the self look's press
    TK.Bindings.commands.SHOWHELMET.action = keyControl("TKOriginalKeysHelmet", 14, "selflook")
    TK.Bindings.commands.SHOWNECKLACE.action = keyControl("TKOriginalKeysNecklace", 15, "selflook")
end

TK.On("TK_SIDE_PANEL_TAB", function() C:SyncKeys() end)

-- ----- F7: the sound effects and the music off or on together (UserPane.cpp:1714-1722) -----

-- The audio logic's (AudioLogic.ToggleSoundAndMusic), as input in its order: its direction is the effects' state, and
-- the music mutes logically (the MIDI player off, no stream opened), as SoundManager::MuteMusic. No packet.
function C:ToggleSound()
    CS.TK.Unity.Audio.AudioHost.ToggleSoundAndMusic()
end

-- s6-modular-b round 32c: the key also carries the mute key's mark, which the rules read at each of its key-downs, a
-- held key's repeats too (KeyCommandRules.Input); the function above still runs on a first press only, as before. WIRE:
-- 5.33's key handler turns its sound manager's flag over at every F7 key-down, a repeat included (0x4D5090, its case
-- 0x8B at 0x4D5C26-0x4D5C64), and its next entry tells the server by that flag (1B 0D, 0x4D8685). Taking the mark off
-- this command, or moving the flag into the function, changes what a 5.33 server sees. Nothing is sent for it and
-- nothing reads the flag under 7.5.2.
TK.Bindings:RegisterCommand("SOUNDTOGGLE", "Sound On/Off", function() C:ToggleSound() end, { kind = "soundmute" })
TK.DB.defaultBindings["F7"] = "SOUNDTOGGLE"

-- ----- F8: the music dialog (UserPane.cpp:1723-1725) -----

-- s6-input (round 48): the original's F8 out of the box, as Classic Commands' F8 (CLASSICMUSIC) in its preset. The key
-- freezes the music dialog's request (plan D20), which runs when a marker carrying it shows in the key's input: in the
-- world, the dialog's own window opens (s6-ui-core round 80), elsewhere the Sound page (TK.Settings:OpenMusic, its
-- comment). WIRE: 4a's F8 (UserPane::HandleKeyOrTextEvent 0x005A5BD0, case 0x8c, behind UserPane's gates) makes a
-- MusicControlDialog, whose constructor (0x00528E60) sends 1B 01 00; the rules' dialog model does the same with the
-- request, in the key's place (DialogRules.Input). Changing the request or how it runs changes when the server sees
-- 1B 01 00.
TK.Bindings:RegisterCommand("MUSIC", "Music", function() TK.Settings:OpenMusic() end, { kind = "open:music" })
TK.DB.defaultBindings["F8"] = "MUSIC"
table.insert(TK.DB.NEWER_COMMANDS, "MUSIC") -- s6-input (round 49): given only to profiles from round 48 on (core/db.lua)
