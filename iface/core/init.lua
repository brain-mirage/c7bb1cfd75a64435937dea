-- The trusted Lua state's entry point. C# runs require('core.init'), then calls __tk_boot with the list of
-- components found under lua/components and lua/interfaces/<id>/panels (one table per manifest.json, sorted by its
-- "order").
--
-- C# talks to Lua only through the __tk_* functions defined here. Every call into component code goes
-- through TK.SafeCall, so an error is logged with its traceback and never breaks the caller.

TK = TK or {}

local H = __tk

local function traceback(err)
    return debug.traceback(tostring(err), 2)
end

-- xpcall's results passed straight on, every one (nils included), with no table made for them (s6-optimize: every
-- script and event dispatch comes through here, about 25 times a frame).
local function finish(ok, ...)
    if not ok then
        H:LogError((...))
        return
    end
    return ...
end

--- Calls fn(...) and logs any error with its traceback. Returns fn's results, or nothing on error.
function TK.SafeCall(fn, ...)
    return finish(xpcall(fn, traceback, ...))
end

function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    H:Log(table.concat(parts, " "))
end

require("core.util")
require("core.frame")
require("core.xml") -- s6-ui-core (round 85): TK.Xml, the UI's XML layout files (core/xml.md); the XML interfaces
require("core.gamestate")
require("core.escape")
require("core.widgets")
require("core.widgets.character") -- s6-modular-g (round 16, separation step 7): a character's drawing helpers (TK.UI.Character)
require("core.await") -- s6-ui-core (after build 41): TK.Await, waiting for work done off the UI (the Library's, the profile picture's)
require("core.viewer") -- s6-spell-icons: the picture viewer (the spell icon editor's, reusable)
require("core.artsource") -- s6-spell-icons: the viewer's sources for the packs' pictures (effects, creatures, tiles, icons)
require("core.actions")
require("core.game.command") -- s6-gateway r5: advisory questions and availability events; execution bindings stay as they are.
require("core.art")
require("core.tooltip")
require("core.effecticons") -- s6-ui-core (round 43): the effect icon group (effects on others, the target frame's row)
require("core.validate")
require("core.store")
require("core.machine")
require("core.db")
require("core.components")
require("core.panels") -- s6-modular-g (interfaces, phase 1): the panel registry
require("core.interfaces") -- s6-modular-g (interfaces, phase 2): the interface registry, a profile per interface
require("core.visibility")
require("core.characters")
require("core.cursor")
require("core.bindings")
require("core.editmode")
require("core.settings")
require("core.dragselect") -- s6-input: the casters' drag-select box
require("core.localserver") -- s6-play-modes: the Local Server page
require("core.gamemenu")
require("core.library") -- s6-library round 2: the Library window, its map markers, export and import
-- s6-modular-g round 15 (from components/minimap): the map markers and the M map window with its traversal, every
-- interface's; Modern's minimap draws the markers too (interfaces/modern/panels/minimap)
require("core.mapmarkers")
require("core.mapwindow")
require("core.game.minimap") -- s6-input (round 49, separation step 4b): the minimap button's one press (5.10)
require("core.chat") -- s6-modular-g round 15: the chat's colours, every interface's
require("core.spellinfo") -- s6-spellbook-data: TK.SpellInfo, the Spell Book table's numbers
require("core.screenshot")
require("core.game.sidepanel") -- s6-interface-5x (round 12, step 1): 4a's one side panel tab (interface-separation.md, 5.2)
require("core.game.views") -- s6-interface-5x (round 12, step 1): the pages' providers (interface-separation.md, 5.1)
require("core.game.itemhelp") -- the local item help's catcher and close rules (4a 0x004CCC40/80)
require("core.game.selflook") -- s6-interface-5x (round 11, W1): the game layer's self look (interface-separation.md, 5.5)
require("core.game.tips") -- s6-gateway-research (round 37, P3): the panes' help tip on a right press (WIRE there)
-- s6-interface-5x (round 12, step 2): the game layer's inventory, spells, look, social and emotes (5.3, 5.4, 5.6)
require("core.game.inventory")
require("core.game.spells")
require("core.game.look")
require("core.game.social")
require("core.game.emotes")
-- s6-modular-g (round 19, the separation's step 8; 5.9): the action slots' presses and the original's 30 hotkeys' carriers;
-- after core.cursor (TK.FollowSpells runs first on the same events) and core.bindings (the carriers are bindable)
require("core.game.hotkeys")
-- s6-modular-g (round 16, separation step 7): Modern's character (with its spell book), look, Social and emotes windows
-- and its bag are Modern's panels (interfaces/modern/panels/windows and bag), loaded with the panels
require("core.spelliconeditor") -- s6-spell-icons: the spell book's right click
require("core.profilepicture") -- s6-ui-core (build 41): the player's own profile picture, imported and cropped
require("core.commands")
-- s6-interface-5x (round 12, step 3): the chat's game layer (interface-separation.md, 5.7); after the commands, so the
-- chat keys keep their place in the Key Bindings page's Other rows
require("core.game.chat")
require("core.game.prompts")
-- s6-play-modes (round 8, step 4): Game Options and the sound (interface-separation.md, 5.8 and 5.11); after the views
-- (the panels' PgUp and PgDn) and the chat, so Display Names keeps its place in the Key Bindings page's Other rows
require("core.game.options")
require("core.game.sound")
require("core.terminal") -- s6-ui-core (round 52): the GM Terminal's shared part (TK.Terminal); an interface's chat shows it
require("core.login")
require("core.entering") -- s6-ui-login: the login's presentation per interface (title music, the loading screen)
require("core.preview")
require("core.gatecontrols") -- UI head note 51: the gate's named controls (gate mode only)
require("core.startup") -- launch-only interface presets and existing settings, before the login screen

-- ----- C# entry points -----

function __tk_script(h, script, a1, a2)
    TK.DispatchScript(h, script, a1, a2)
end

function __tk_update(h, elapsed)
    TK.DispatchScript(h, "OnUpdate", elapsed)
end

function __tk_event(event, ...)
    TK.DispatchEvent(event, ...)
end

function __tk_key(key, down)
    -- The screenshot keys are the original's fixed keys, before any binding (head note 28).
    if TK.SafeCall(TK.Screenshot.OnKey, TK.Screenshot, key, down) then return true end
    local handled = TK.SafeCall(TK.Bindings.OnKey, TK.Bindings, key, down)
    return handled and true or false
end

--- Before a reload: every pending change must be on disk, or the reload does not happen (review F10).
function __tk_before_reload()
    local ok = TK.SafeCall(TK.FlushAll)
    if ok ~= true then
        TK.Popup("The UI was not reloaded because settings could not be saved. Saving will be tried again.",
            "Reload cancelled")
        return false
    end
    return true
end

function __tk_boot(components)
    TK.SafeCall(TK.Components.Boot, TK.Components, components)
end

--- s6-interface-5x (round 13, the separation's step 11): a panel turned on in the game, started with the UI loading
--- (LuaHost.StartPanel; core/components.lua's Start). Returns whether the component is the registry's.
function __tk_start_panel(component, panel)
    return TK.SafeCall(TK.Components.Start, TK.Components, component, panel ~= "" and panel or nil) == true
end
