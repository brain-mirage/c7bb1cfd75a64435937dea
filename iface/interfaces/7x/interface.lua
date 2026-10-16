-- s6-modular-g (interfaces, phase 3; docs/development/interfaces.md, section 3 "7.x"): 7.5.2's game screen.
-- Its screen is 1024 x 768, scaled to fit the window and letterboxed (panels/screen); its Decoration is the original's
-- backdrop, border, tab header, messages divider and chat backdrop, each a panel of its own; the world view (one panel
-- for every interface) goes to the original's map pane. 7.x's own panels come in phase 5 (round 13: the MENU button,
-- panels/menu; round 14: the side panel with its tab strip, panels/side, the name plate and the vitals, panels/status, and
-- the chat bar, panels/chatbar) and its dialogs look in phase 4; the pre-game is ours in every interface (s6-ui-core round
-- 86: but its own title and login dialog, its XML twin's, with Original Login Screens: login.screens below). The screen
-- draws only: nothing is sent.

--- A decoration piece: its page's switch and its place (its Layout tab and edit mode: Astra's review of round 9).
local function decoration(id, name)
    return { id = id, name = name, category = "Decoration", component = "7x.screen", node = "7x." .. id, switch = "enabled",
             place = "7x." .. id, dir = "panels/screen" }
end

-- Until 7.x's own panels are built (phase 5), its first profile keeps Modern's for the jobs the original's screen has
-- and 7.x's panels do not do yet (none now: see below), at their Modern places, and Classic Commands, which holds the
-- original's keys (Alt+X's quit prompt, B the boards...: round 12, as the owner's answer gives 7.x the original's keys);
-- Modern's for jobs it has not (the action bars, the target and party frames, the micro menu...) are off, as the
-- interface's defaults turn every other interface's panel off (decision 2026-10-03-7x-interim-modern-panels).
-- s6-modular-g round 14: 7.x's name plate and vitals took over from Modern's player frame, and its chat bar steps in
-- for Modern's. s6-interface-7x-b: the minimap with its clock, mail and parcel icons, and the buffs, debuffs and aethers
-- left the list with 7.x's minimap button, clock, parcel and letter buttons and messages pane; round 4: Modern's chat
-- frame left it too, as 7.x's chat log and chat bar are the chat now (the original shows one log; a 7.x profile made
-- before has it turned off once: MIGRATE's chatframeOff). Only Classic Commands stays.
-- s6-interface-5x (round 12, build 46; the owner, 2026-10-05: "New and reset profiles start with only their own
-- interface's things on"): not Modern's windows any more (7.x's side panel draws every tab since s6-interface-7x-b's
-- round 5; the ignore list and the emotes, Modern's extras, open when the player turns those windows on). The registry
-- turns these on in a first profile (TK.Interfaces:ApplyDefaults); a profile made before has the panels that had no
-- switch until round 12 (Modern's windows and its action wheel, which no player could have chosen) turned off once
-- (MIGRATE; decision 2026-10-05-first-profiles-only-their-own-panels).
-- s6-modular-g (round 18): Modern's Game Options window, whose switch came in round 18, by the same rule under a flag of
-- its own (a profile made since build 46 has windowsOff already).
-- s6-interface-5x (round 15, the separation's step 9): round 4's carry-over of Modern's chat frame (a 7.x profile made
-- before build 40 had it on and showed two logs), which the chat log did by code as a profile loaded, marking
-- chatframeOff in its own values; a profile it marked counts as carried over (oldFlag), so a player who turned the chat
-- frame on again keeps it. Drawing only: nothing is sent.
local ENABLE = { "classic" }
local MIGRATE = {
    { flag = "windowsOff", off = { "character", "bag", "look", "social", "emotes", "actionwheel" } },
    { flag = "optionsWindowOff", off = { "gameoptions" } },
    { flag = "chatframeOff", off = { "chatframe" }, oldFlag = { "7x.chatlog", "chatframeOff" } },
    -- s6-ui-core (round 60; the owner, 2026-10-06: the menu button "on it 5x and 7x"): a shared panel with a switch
    -- since round 60, off by its component's default, so a profile made before has it turned on once
    { flag = "menuButtonOn", on = { "menubutton" } },
    -- s6-ui-core (round 61; the owner, 2026-10-06: the tooltip "when you hover over mobs was enabled in the 7x
    -- interface"): the original shows none on a hovered creature, player or item, so the Tooltips page's world switch is
    -- off here (on in Modern, its component's default); a profile made before has it turned off once
    { flag = "worldTooltipsOff", set = { tooltips = { world = false } } },
}

return {
    id = "7x", name = "7.x", profileName = "7.x",
    order = 2, -- s6-interface-5x (round 11): its place among the interfaces as the player sees them (TK.Interfaces:InOrder)
    -- s6-ui-core (round 79): its button on Graphics > General's Quick Settings (core/quicksettings.lua), the mock-up's label
    quick = { text = "V 7.x", desc = "The 7.x interface (2013)." },
    -- 7.x's dialogs look (interfaces/7x/dialogs/, phase 4: the dialogs drawn so far; the others Modern's until theirs are)
    looks = { dialogs = "7x", cursors = "original" },
    -- s6-interface-5x-b (round 7): 4a's cursor rule off the map (core/cursor.lua): the last cursor stays over the frame and
    -- the panes, a new dialog shows the normal one
    keepsCursorOffMap = true,
    -- s6-modular-g round 22: NewInventoryPane 0x004ECB50 drops on its whole 19x17 map pane.
    -- The shared world/inventory seam reads this; changing it changes the server's 08 packets.
    inventoryDropPane = true,
    -- s6-ui-login: the login's presentation (core/entering.lua): the original's title music, and the login screen until
    -- the world, with no loading screen (4a draws no loading text: MapPane::RenderMapView only skips the map's objects
    -- while it waits for the player's status, MapPane.cpp:2062).
    -- s6-ui-core (round 86): screens, its own login screen (7.5.2's title and login dialog), the XML twin's only
    -- (interfaces/xml/7x/screens/title.lua), with Experimental's Original Login Screens (core/login.lua)
    login = { titleMusic = true, loadingScreen = false, screens = "interfaces.7x.screens.title" },
    enable = ENABLE,
    migrate = MIGRATE,
    panels = {
        -- the screen itself: always there (no switch); its page holds the world view's place at the map pane
        { id = "screen", name = "7.x Screen", category = "World", component = "7x.screen", node = "7x.screen",
          dir = "panels/screen" },
        decoration("backdrop", "Backdrop"),
        decoration("border", "Border"),
        decoration("tabheader", "Tab Header"),
        decoration("divider", "Messages Divider"),
        decoration("chatbackdrop", "Chat Backdrop"),
        -- phase 5 (round 13): the original's MENU button, which opens the Menu popup
        { id = "menu", name = "Menu Button", category = "Buttons", component = "7x.menu", node = "7x.menu", switch = "enabled",
          place = "7x.menu", dir = "panels/menu" },
        -- phase 5 (round 14): the side panel with its tab strip, the name plate and the vitals, the chat bar
        { id = "side", name = "Side Panel", category = "Pages", component = "7x.side", node = "7x.side", switch = "enabled",
          place = "7x.side", dir = "panels/side" },
        { id = "nameplate", name = "Name Plate", category = "Character", component = "7x.status", node = "7x.nameplate",
          switch = "enabled", place = "7x.nameplate", dir = "panels/status" },
        { id = "vitals", name = "Vitals", category = "Character", component = "7x.status", node = "7x.vitals",
          switch = "enabled", place = "7x.vitals", dir = "panels/status" },
        { id = "chatbar", name = "Chat Bar", category = "Chat", component = "7x.chatbar", node = "7x.chatbar",
          switch = "enabled", place = "7x.chatbar", dir = "panels/chatbar" },
        -- s6-interface-7x (round 1): the original's say-mode button left of the chat bar, which opens the say-mode menu
        { id = "saymode", name = "Say-Mode Button", category = "Buttons", component = "7x.saymode", node = "7x.saymode",
          switch = "enabled", place = "7x.saymode", dir = "panels/saymode" },
        -- s6-interface-7x-b: phase 5's HUD panels (each its own switch, Layout tab and edit-mode place)
        { id = "mapname", name = "Map Name", category = "World", component = "7x.mapname", node = "7x.mapname",
          switch = "enabled", place = "7x.mapname", dir = "panels/mapname" },
        { id = "minimapbutton", name = "Minimap Button", category = "World", component = "7x.minimapbutton",
          node = "7x.minimapbutton", switch = "enabled", place = "7x.minimapbutton", dir = "panels/minimapbutton" },
        { id = "clock", name = "Clock", category = "Indicators", component = "7x.clock", node = "7x.clock", switch = "enabled",
          place = "7x.clock", dir = "panels/clock" },
        -- the parcel and letter buttons: two panels over 4a's one ParcelPane
        { id = "parcel", name = "Parcel Button", category = "Indicators", component = "7x.parcel", node = "7x.parcel",
          switch = "enabled", place = "7x.parcel", dir = "panels/parcel" },
        { id = "letter", name = "Letter Button", category = "Indicators", component = "7x.parcel", node = "7x.letter",
          switch = "enabled", place = "7x.letter", dir = "panels/parcel" },
        { id = "messages", name = "Messages", category = "Messages", component = "7x.messages", node = "7x.messages",
          switch = "enabled", place = "7x.messages", dir = "panels/messages" },
        { id = "chatlog", name = "Chat Log", category = "Chat", component = "7x.chatlog", node = "7x.chatlog",
          switch = "enabled", place = "7x.chatlog", dir = "panels/chatlog" },
    },
    --- The first profile's own defaults, after the panels' switches (TK.Interfaces:ApplyDefaults): the world view at the map
    --- view, its band beyond the 17 x 15 drawn as any tile (the original draws its whole pane alike); the interim Modern
    --- panels are ENABLE's. (Merge of main: round 14's places for the interim minimap, aether list and chat
    --- log went with them: 7.x's own minimap button, messages pane and chat log, s6-interface-7x-b's, draw those now.)
    defaults = function()
        local screen = TK.GetComponent("7x.screen")
        if screen then
            screen:DB().mapPane = true
            screen:DB().placed = nil
        end
        local view = TK.GetComponent("worldview")
        if view then view:DB().outerDim, view:DB().outerSaturation = 0, 1 end
    end,
}
