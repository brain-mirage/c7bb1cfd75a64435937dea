-- s6-modular-g (interfaces, phase 1; docs/development/interfaces.md, sections 1 and 3): Modern, today's
-- interface, as an interface. Each panel is one piece of the screen, with:
--   id, name    the panel's, unique in the interface
--   category    where the lists file it (TK.Panels.categories)
--   component   the component whose code draws it (the character, look, Social and emotes windows: panels/windows)
--   node        its settings page (none for a window without one)
--   switch      the key on its page that turns it on or off (none: always there)
--   place       the key of its place (the profile's positions[place]), which its Layout tab and edit mode move; or
--   border      true for an icon on the minimap's border, whose Layout tab places it along that border
-- Modern's panels are components: their code is under interfaces/modern/panels/<component>/ with its manifest.json
-- (s6-modular-g round 15 moved them there from components/<name>/; round 16, the separation's step 7, its windows from
-- core/ and its prompt line from Classic Commands). The world view (shared) and Classic Commands stay at the root
-- (components/), as other interfaces use them too (docs/development/interfaces.md, "Where a new file goes"); Game
-- Options stays there too (its settings page, F10 and the option keys), while its window is Modern's (panels/windows,
-- round 17).
-- This list names them all; their defaults (places and settings) are the components' own.
-- Phase 2 (core/interfaces.lua): the interface's first profile is today's default profile ("Default"); its looks are its own
-- dialogs look (interfaces/modern/dialogs/) and the original's cursors. A panel may also give:
--   on          false: off in its interface's first profile (on by default)
--   keys        { { command = ..., key = ... } }: the keys it brings, bound where free when it is turned on
--   dir         its code's folder under the interface's (a panel of an interface other than Modern: interfaces/<id>/<dir>/)
--   clicks      its buttons' frame name but for their number: the default bindings to them are the keys it brings into
--               another interface's profile, and a new profile there where it is off is made without them
--   hotkeys     s6-modular-g (round 19, the separation's step 8): the original's hotkey slots its buttons show, whose
--               default bindings name the game layer's carriers (TK.Game.Hotkeys): keys it brings as clicks' do
--   shared      true: every interface's (the world view: each interface gives it a default place), on in every first profile and
--               listed with the active interface's panels

local panels = {
    { id = "worldview", name = "World View", category = "World", component = "worldview", node = "worldview", switch = "enabled", place = "worldview", shared = true },
    { id = "minimap", name = "Minimap", category = "World", component = "minimap", node = "minimap", switch = "enabled", place = "minimap" },

    { id = "playerframe", name = "Player Frame", category = "Character", component = "playerframe", node = "playerframe", switch = "enabled", place = "playerframe" },
    { id = "xpbar", name = "XP Bar", category = "Character", component = "xpbar", node = "xpbar", switch = "enabled", place = "xpbar" },
    { id = "targetframe", name = "Target Frame", category = "Character", component = "targetframe", node = "targetframe", switch = "enabled", place = "targetframe" },
    { id = "partyframes", name = "Party Frames", category = "Character", component = "partyframes", node = "partyframes", switch = "enabled", place = "partyframes" },
    { id = "nameplates", name = "Nameplates", category = "Character", component = "nameplates", node = "nameplates", switch = "enabled" },
    -- s6-ui-core (round 43): the enemy icons became "effects on others" (creatures' and players' buffs and debuffs);
    -- round 82: Effect Icons, a page of the Nameplates pane (what is drawn over others), under it in the list.
    { id = "enemyicons", name = "Effect Icons", category = "Character", component = "enemyicons", node = "enemyicons", switch = "enabled" },

    -- s6-interface-5x (round 12, separation step 1; interface-separation.md 5.1): the windows stand for the views no
    -- interface's page takes (TK.Game.Views), in every interface while their switch is on; 7.x's and 5.x's first
    -- profiles leave them off (build 46). Game Options' window (panels/windows/gameoptions.lua since step 7, s6-modular-g
    -- round 17) is the options' fallback (TK.Game.Options.SetWindow), with its switch on the windows' page since round 18;
    -- the Game Options page itself (components/gameoptions) is global, no panel's.
    { id = "character", name = "Character Window", category = "Pages", component = "windows", node = "character", switch = "enabled" },
    { id = "bag", name = "Bag", category = "Pages", component = "bag", node = "bag", switch = "enabled" },
    { id = "look", name = "Look Window", category = "Pages", component = "windows", node = "look", switch = "enabled" },
    { id = "social", name = "Social Window", category = "Pages", component = "windows", node = "social", switch = "enabled" },
    { id = "emotes", name = "Emotes", category = "Pages", component = "windows", node = "emotes", switch = "enabled" },
    { id = "gameoptions", name = "Game Options Window", category = "Pages", component = "windows", node = "gameoptionswindow", switch = "enabled" },

    { id = "buffs", name = "Buffs", category = "Messages", component = "auras", node = "buffs", switch = "enabled", place = "buffs" },
    { id = "debuffs", name = "Debuffs", category = "Messages", component = "auras", node = "debuffs", switch = "enabled", place = "debuffs" },
    { id = "aethers", name = "Aether List", category = "Messages", component = "auras", node = "aethers", switch = "enabled", place = "aethers" },

    { id = "chatframe", name = "Chat Frame", category = "Chat", component = "chatframe", node = "chatframe", switch = "enabled", place = "chatframe" },
    { id = "classic", name = "Classic Commands", category = "Chat", component = "classic", node = "classic", switch = "enabled" },
    -- s6-modular-g (round 16, separation step 7): the line Classic Commands' prompts and the rules' are drawn on where
    -- no chat draws them (moved from components/classic); off in 7.x's and 5.x's first profiles, whose chats draw them.
    { id = "prompt", name = "Prompt Line", category = "Chat", component = "prompt", node = "prompt", switch = "enabled" },

    { id = "bar1", name = "Bar 1", category = "Buttons", component = "actionbars", node = "bar1", switch = "enabled", place = "bar1", clicks = "TKActionBar1Button", hotkeys = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } },
    { id = "bar2", name = "Bar 2", category = "Buttons", component = "actionbars", node = "bar2", switch = "enabled", place = "bar2", clicks = "TKActionBar2Button", hotkeys = { 13, 14, 15, 16, 17, 18, 19, 20, 21, 22 } },
    { id = "bar3", name = "Bar 3", category = "Buttons", component = "actionbars", node = "bar3", switch = "enabled", place = "bar3", clicks = "TKActionBar3Button", hotkeys = { 25, 26, 27, 28, 29, 30, 31, 32, 33, 34 } },
    { id = "bar4", name = "Bar 4", category = "Buttons", component = "actionbars", node = "bar4", switch = "enabled", place = "bar4", clicks = "TKActionBar4Button" },
    { id = "bar5", name = "Bar 5", category = "Buttons", component = "actionbars", node = "bar5", switch = "enabled", place = "bar5", clicks = "TKActionBar5Button" },
    { id = "bar6", name = "Bar 6", category = "Buttons", component = "actionbars", node = "bar6", switch = "enabled", place = "bar6", clicks = "TKActionBar6Button" },
    { id = "bar7", name = "Bar 7", category = "Buttons", component = "actionbars", node = "bar7", switch = "enabled", place = "bar7", clicks = "TKActionBar7Button" },
    { id = "bar8", name = "Bar 8", category = "Buttons", component = "actionbars", node = "bar8", switch = "enabled", place = "bar8", clicks = "TKActionBar8Button" },
    { id = "bar9", name = "Bar 9", category = "Buttons", component = "actionbars", node = "bar9", switch = "enabled", place = "bar9", clicks = "TKActionBar9Button" },
    { id = "bar10", name = "Bar 10", category = "Buttons", component = "actionbars", node = "bar10", switch = "enabled", place = "bar10", clicks = "TKActionBar10Button" },
    { id = "bagbar", name = "Bag Bar", category = "Buttons", component = "bagbar", node = "bagbar", switch = "enabled", place = "bagbar" },
    { id = "micromenu", name = "Micro Menu", category = "Buttons", component = "micromenu", node = "micromenu", switch = "enabled", place = "micromenu" },
    -- s6-interface-5x (round 12, build 46): its switch, so that it is off in 7.x's and 5.x's profiles, its keys with it
    -- (X and Shift+X: a new profile where it is off is made without them)
    { id = "actionwheel", name = "Action Wheel", category = "Buttons", component = "actionwheel", node = "actionwheel", switch = "enabled",
      keys = { { command = "ACTIONWHEEL", key = "X" }, { command = "ACTIONWHEEL_MULTI", key = "SHIFT-X" } } },
    -- s6-ui-core (round 60; the owner, 2026-10-06: "an interface item that is used/can be used on all interfaces so it
    -- should be under All interfaces in ui as a subpage Menu"): the menu button (components/menubutton), every
    -- interface's: on in 7.x's and 5.x's first profiles, off in Modern's (its component's default)
    { id = "menubutton", name = "Menu", category = "Buttons", component = "menubutton", node = "menubutton", switch = "enabled",
      place = "menubutton", shared = true },

    { id = "minimapclock", name = "Clock and Weather", category = "Indicators", component = "minimap", node = "minimapclock", switch = "showClock", border = true },
    { id = "minimapmail", name = "Mail Icon", category = "Indicators", component = "minimap", node = "minimapmail", switch = "showMail", border = true },
    { id = "minimapparcels", name = "Parcel Icon", category = "Indicators", component = "minimap", node = "minimapparcels", switch = "showParcels", border = true },
    { id = "mailparcels", name = "Mail and Parcels", category = "Indicators", component = "mailparcels", node = "mailparcels", switch = "enabled", place = "mailparcels" },
}

-- s6-modular-g (round 19, the separation's step 8; interface-separation.md 7.1): the original's 30 hotkeys were bindings
-- to bars 1-3's buttons 1-10 until step 8; a saved one is carried over to its carrier once (core/db.lua), old -> new.
-- The new command is the carrier's own (TK.Game.Hotkeys.Command, loaded before the interfaces: core/init.lua), so the
-- carried key keeps a click's input path (core/game/hotkeys.lua's wire note); changing it changes what the server sees.
local renamedCommands = {}
for b = 1, 3 do
    for i = 1, 10 do renamedCommands["CLICK TKActionBar" .. b .. "Button" .. i] = TK.Game.Hotkeys.Command((b - 1) * 12 + i) end
end

return { id = "modern", name = "Modern", profileName = "Default", looks = { dialogs = "modern", cursors = "original" },
         order = 1, -- s6-interface-5x (round 11): its place among the interfaces as the player sees them (TK.Interfaces:InOrder)
         -- s6-ui-core (round 79): its button on Graphics > General's Quick Settings (core/quicksettings.lua)
         quick = { text = "Modern", desc = "The Modern interface." },
         -- s6-ui-login: the login's presentation (core/entering.lua): from the accepted login a black screen under the
         -- interface with a "Loading..." popup until the world has loaded (the owner, 2026-10-04). s6-ui-core (build 41;
         -- the owner, 2026-10-05): the original's title music, heard only with the Sound page's Play Login Music on (off
         -- by default), as in every interface (it was none here before that switch).
         login = { titleMusic = true, loadingScreen = true },
         -- s6-input (round 49, separation step 4b; interface-separation.md 5.13): the default interface (TK.Interfaces:Default),
         -- and the saved values its components held that are now global: Effects on Others' name lists, the profile's
         -- effectLists since (core/db.lua's MoveSaved moves them once).
         default = true,
         movedSaved = { ["components.enemyicons.buffNames"] = "effectLists.buffNames",
                        ["components.enemyicons.debuffNames"] = "effectLists.debuffNames" },
         -- s6-input (round 50, separation step 4b; 5.12): its look of the shared world view, the grey edge and the label
         -- (interfaces/modern/worldview.lua), which the view builds while Modern is the active interface
         worldViewLook = "worldview",
         renamedCommands = renamedCommands,
         panels = panels }
