-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md; docs/development/interfaces.md,
-- section 3 "5.33"): NexusTK 5.33's game screen. Its screen is 640 x 480, scaled to fit the window and letterboxed
-- (panels/screen), laid out as 5.33's MainMenuPane::InitializeMainUiGraph (0x00457530) builds it: the backdrop and the
-- thirteen border pieces, the map name, the clock, the status pane, the chat, the side panel (the items, spells, self
-- look and look pages), the icon row and the message board, each a panel of its own; the world view (one panel for
-- every interface) goes to 5.33's map view. Its pictures are 5.33's own (skin.lua). Its dialogs look is 5.33's: the
-- common dialog frame for the alerts and its NPC dialogs (dialogs/), Modern's for the others until theirs are drawn.
-- The pre-game is ours in every interface. It draws only: what is sent is the shared actions', rules' and dialog
-- model's, 7.5.2's.

--- A piece of the screen component (panels/screen): its page's switch and its place (its Layout tab and edit mode).
local function piece(id, name, category)
    return { id = id, name = name, category = category, component = "5x.screen", node = "5x." .. id, switch = "enabled",
             place = "5x." .. id, dir = "panels/screen" }
end

-- Its first profile keeps Modern's Classic Commands on, which holds the original's keys (Alt+X's quit prompt, B the
-- boards...), as 7.x's first profile does (decision 2026-10-04-5x-interim-modern-panels). Since round 3 not Modern's
-- effects panels: 5.33 lists the effects on the player in its self look's equipment view (panels/side) and has no
-- spell timers. Not the mail and parcel buttons: anchored to the window's bottom right, they would cover the status
-- pane; 5.x's own are its parcel pane (ParcelIconPane: panels/parcel, s6-interface-5x-b). Every other interface's panel
-- is off, as an interface's defaults turn them.
-- s6-interface-5x (round 12, build 46; the owner, 2026-10-05: "New and reset profiles start with only their own
-- interface's things on"): not Modern's windows any more (5.x draws every page 5.33 has; the collection, which 5.33 has
-- not, and Modern's ignore list and emotes open when the player turns those windows on). The registry turns these on in
-- a first profile (TK.Interfaces:ApplyDefaults); a profile made before has the panels that had no switch until round 12
-- (Modern's windows and its action wheel, which no player could have chosen) turned off once (MIGRATE; decision
-- 2026-10-05-first-profiles-only-their-own-panels).
-- s6-modular-g (round 18): Modern's Game Options window, whose switch came in round 18, by the same rule under a flag of
-- its own (a profile made since build 46 has windowsOff already).
local ENABLE = { "classic" }
local MIGRATE = {
    { flag = "windowsOff", off = { "character", "bag", "look", "social", "emotes", "actionwheel" } },
    { flag = "optionsWindowOff", off = { "gameoptions" } },
    -- s6-ui-core (round 60; the owner, 2026-10-06: the menu button "on it 5x and 7x"): a shared panel with a switch
    -- since round 60, off by its component's default, so a profile made before has it turned on once
    { flag = "menuButtonOn", on = { "menubutton" } },
    -- s6-ui-core (round 61; the owner, 2026-10-06: the tooltip "when you hover over mobs was enabled in the 7x
    -- interface"): the original shows none on a hovered creature, player or item, so the Tooltips page's world switch is
    -- off here (on in Modern, its component's default); a profile made before has it turned off once
    { flag = "worldTooltipsOff", set = { tooltips = { world = false } } },
}

return {
    id = "5x", name = "5.x", profileName = "5.x",
    order = 3, -- s6-interface-5x (round 11): its place among the interfaces as the player sees them (TK.Interfaces:InOrder)
    -- s6-ui-core (round 79): its button on Graphics > General's Quick Settings (core/quicksettings.lua), the mock-up's label
    quick = { text = "V 5.x", desc = "The 5.x interface (2003)." },
    -- 5.x's dialogs look (dialogs/: the common dialog frame so far, Modern's for every other dialog until theirs are);
    -- its cursors 5.33's own (s6-interface-5x-b: CURSOR01.EPF, the world view's MouseCursors; the original's without the
    -- 5.33 set)
    looks = { dialogs = "5x", cursors = "533" },
    -- the login's presentation (core/entering.lua), as 5.33's: its main menu plays the title track (MainMenuPane
    -- 0x00457250), faded over 3 s at the first map (MapPane_ChangeMap 0x00464D60), and the accepted login builds the game
    -- screen at once with no loading text (InitializeMainUiGraph 0x00457530).
    -- What is heard: 5.33's own. Its title starts its own track 999 (StartMusic(999, 100, 1) at 0x457311, push 0x3E7;
    -- track 0, none, when its configuration's flag at +0x1564 is set): 00000999.mp3 in its Mus000.dat, a recording
    -- other than 7.5.2's 999 (s6-ui-core round 86, read in 5.33's code: round 8's 231 was 0x3E7's low byte). s6-ui-core
    -- (head note 14, item 1): heard from the 5.33 set, where ntkx interface puts it; nothing without that set, and no
    -- other track stands in. Only what is heard: the audio logic still plays 7.5.2's 999, so its draws and every packet
    -- stay 7.5.2's.
    -- s6-ui-core (round 86): screens, its own login screen (5.33's title and login dialog), the XML twin's only
    -- (interfaces/xml/5x/screens/title.lua), with Experimental's Original Login Screens (core/login.lua)
    login = { titleMusic = "nexustk-5.33", loadingScreen = false, screens = "interfaces.5x.screens.title" },
    enable = ENABLE,
    migrate = MIGRATE,
    panels = {
        -- the screen itself: always there (no switch); its page holds the world view's place at the map view
        { id = "screen", name = "5.x Screen", category = "World", component = "5x.screen", node = "5x.screen",
          dir = "panels/screen" },
        piece("mapname", "Map Name", "World"),
        { id = "status", name = "Status", category = "Character", component = "5x.status", node = "5x.status",
          switch = "enabled", place = "5x.status", dir = "panels/status" },
        { id = "chat", name = "Chat", category = "Chat", component = "5x.chat", node = "5x.chat", switch = "enabled",
          place = "5x.chat", dir = "panels/chat" },
        -- round 2: the side panel's pages (items, spells, equipment) and the icon row
        { id = "side", name = "Side Panel", category = "Pages", component = "5x.side", node = "5x.side",
          switch = "enabled", place = "5x.side", dir = "panels/side" },
        { id = "icons", name = "Icons", category = "Buttons", component = "5x.icons", node = "5x.icons",
          switch = "enabled", place = "5x.icons", dir = "panels/icons" },
        -- round 3: the message board
        { id = "board", name = "Message Board", category = "Messages", component = "5x.board", node = "5x.board",
          switch = "enabled", place = "5x.board", dir = "panels/board" },
        -- s6-interface-5x-b: the parcel icons beside the clock; the options window (F10's, in place of Modern's)
        { id = "parcel", name = "Parcels", category = "Indicators", component = "5x.parcel", node = "5x.parcel",
          switch = "enabled", place = "5x.parcel", dir = "panels/parcel" },
        { id = "options", name = "Options", category = "Pages", component = "5x.options", node = "5x.options",
          switch = "enabled", dir = "panels/options" },
        piece("clock", "Clock", "Indicators"),
        piece("backdrop", "Backdrop", "Decoration"),
        piece("border", "Border", "Decoration"),
    },
    --- The first profile's own defaults, after the panels' switches (TK.Interfaces:ApplyDefaults): the world view at the
    --- map view and its band beyond the 17 x 15 drawn as any tile (the interim Modern panels are ENABLE's).
    defaults = function()
        local screen = TK.GetComponent("5x.screen")
        if screen then
            screen:DB().mapPane = true
            screen:DB().placed = nil
        end
        local view = TK.GetComponent("worldview")
        if view then view:DB().outerDim, view:DB().outerSaturation = 0, 1 end
    end,
}
