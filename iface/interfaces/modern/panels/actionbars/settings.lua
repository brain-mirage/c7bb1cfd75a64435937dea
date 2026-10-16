-- Action bars: defaults and the settings schema. Every bar has Bartender's full General Settings, plus the
-- aether display options of goal 14 (aethers are the game's cooldowns), and the Visibility and Layout tabs.

local C = TK.GetComponent("actionbars")

C.MAX_BARS = 10
C.BUTTONS = 12
C.BUTTON_SIZE = 44

--- The action slot bar's button index shows: (bar - 1) x 12 + index, so bars 1-3's buttons 1-10 are the original's hotkey
--- slots (TK.Game.Hotkeys.SLOTS). Wire: the slot a press of the button or its key runs, as 4a's hotkey runs its record
--- (UserPane::ExecuteHotkeyAction 0x005A3AE0); changing it changes what the server sees.
function C.Slot(bar, index) return (bar - 1) * 12 + index end

--- The binding a bar's button binds through (hover-to-bind, its key shown, the Key Bindings rows): bars 1-3's buttons 1-10
--- show the original's 30 hotkeys' slots, whose keys are bound to the game layer's carriers (TK.Game.Hotkeys, the
--- separation's step 8: s6-modular-g round 19); the others, Modern's own, to the button.
function C.ButtonCommand(bar, index)
    if bar <= 3 and index <= 10 then return TK.Game.Hotkeys.Command(C.Slot(bar, index)) end
    return "CLICK TKActionBar" .. bar .. "Button" .. index
end

-- ----- default key bindings (part of a new profile) -----

-- Keys 1-0, - and = for bar 1, Ctrl+same for bar 2 and Alt+same for bar 3, as the original's macro keys. Never Shift: in
-- the original, Shift+digit types the symbols that start commands (! shout, " whisper). No default actions: the
-- character's spells fill bar 1 as it gets them (TK.Game.Hotkeys.PlaceNewSpells). s6-modular-g (round 19, step 8): here,
-- before the profile loads, whether the bars are loaded or not. Wire: 1-0 with Ctrl and Alt are bound to the carriers,
-- CLICK bindings that keep a click's input path (core/game/hotkeys.lua); changing what they name changes what the server
-- sees.
do
    local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
    for i = 1, 12 do
        TK.DB.defaultBindings[keys[i]] = C.ButtonCommand(1, i)
        TK.DB.defaultBindings["CTRL-" .. keys[i]] = C.ButtonCommand(2, i)
        TK.DB.defaultBindings["ALT-" .. keys[i]] = C.ButtonCommand(3, i)
    end
end

local function barDefaults(i)
    local d = TK.Visibility.Defaults({
        padding = 2,
        buttons = 12,
        rows = 1,
        buttonGrid = true, -- s6-ui-bars: the empty slots show their black background (the owner's head note)
        hideMacroText = true,
        hideHotkey = false,
        showCooldownNumbers = true,
        showCooldownClock = true,
        -- s6-ui-core (round 82; the owner, 2026-10-09): a red edge on a spell the mana is short for, and on one in its aether
        markNoMana = true,
        markAether = true,
        growH = "RIGHT",
        growV = "DOWN",
    })
    -- s6-ui-core (round 53): the bar's own transparency (its slot backgrounds), the UI's while the box is ticked
    for k, v in pairs(TK.PanelTransparencyDefaults) do d[k] = v end
    -- As WoW: one bar across the bottom; the others are turned on here (the owner, 2026-10-01).
    d.enabled = i == 1
    -- Bars 4 and 5 stand upright at the right edge, as in Bartender.
    if i == 4 or i == 5 then d.rows = 12 end
    return d
end

C.defaults = { bars = {} }
for i = 1, C.MAX_BARS do C.defaults.bars[tostring(i)] = barDefaults(i) end

-- Where each bar sits by default: 1-3 stacked at the bottom centre, 4-5 at the right edge, the rest above bar 3.
C.defaultPositions = {
    { "BOTTOM", "BOTTOM", 0, 18 },
    { "BOTTOM", "BOTTOM", 0, 66 },
    { "BOTTOM", "BOTTOM", 0, 114 },
    { "RIGHT", "RIGHT", -8, 0 },
    { "RIGHT", "RIGHT", -56, 0 },
    { "BOTTOM", "BOTTOM", 0, 162 },
    { "BOTTOM", "BOTTOM", 0, 210 },
    { "BOTTOM", "BOTTOM", 0, 258 },
    { "BOTTOM", "BOTTOM", 0, 306 },
    { "BOTTOM", "BOTTOM", 0, 354 },
}

-- s6-ui-core (round 54): what it needs to have an effect, its (!) (TK.Needs: was disabled); s6-ui-core (round 60;
-- s6-optimize's FOR r60, item 3): the Fade Out switch by its key (TK.NeedSetting), as TK.StandardGeneralArgs'
local fading = TK.NeedSetting("fadeOut")

C.generalArgs = {
    { type = "toggle", key = "enabled", name = "Enabled" },
    { type = "description", name = "A bar that is off keeps its buttons, and their keys still work while another bar is "
        .. "on. Keys 1-0, with Ctrl and Alt, always work. A new spell goes onto the first empty button of the bars that are on." },
    { type = "header", name = "Bar Style & Layout" },
    { type = "range", key = "alpha", name = "Alpha", min = 0.1, max = 1, step = 0.05 },
    -- s6-modular-g (interfaces): the Scale is the Layout tab's (TK.LayoutArgs)
    { type = "range", key = "padding", name = "Padding", min = -10, max = 20, step = 1 },
    { type = "range", key = "buttons", name = "Buttons", min = 1, max = 12, step = 1 },
    { type = "toggle", key = "buttonGrid", name = "Button Grid" },
    { type = "range", key = "rows", name = "Rows", min = 1, max = 12, step = 1 },
    { type = "header", name = "Button Look" },
    { type = "toggle", key = "hideMacroText", name = "Hide Macro Text" },
    { type = "toggle", key = "hideHotkey", name = "Hide Hotkey" },
    { type = "toggle", key = "fadeOut", name = "Fade Out" },
    { type = "break" },
    { type = "range", key = "fadeOutAlpha", name = "Fade Out Alpha", min = 0, max = 1, step = 0.05, requires = { fading } },
    { type = "range", key = "fadeOutDelay", name = "Fade Out Delay", min = 0, max = 1, step = 0.05, requires = { fading } },
}
-- s6-ui-core (round 53): the slots' own transparency
TK.PanelTransparencyArgs(C.generalArgs)
for _, a in ipairs({
    { type = "header", name = "Aethers" },
    { type = "toggle", key = "showCooldownNumbers", name = "Aether Numbers" },
    { type = "toggle", key = "showCooldownClock", name = "Aether Clock" },
}) do C.generalArgs[#C.generalArgs + 1] = a end
-- s6-ui-core (round 82; the owner, 2026-10-09): spells that cannot be cast now, edged in red (round 83: the rows the spell
-- book's and the action wheel's pages share, interfaces/modern/slotmark.lua)
require("interfaces.modern.slotmark").Args(C.generalArgs)

--- Each bar has its own saved settings and uses the shared panel controls.
function C:SettingsNodes()
    local nodes = {}
    for i = 1, C.MAX_BARS do
        local id = tostring(i)
        nodes[#nodes + 1] = {
            id = "bar" .. i,
            title = "Bar " .. i,
            parent = "Bars", -- s6-ui-settings (nested settings menus): the bars' title, was group
            order = 10,
            sub = i,
            barId = i,
            db = function() return C:DB().bars[id] end,
            defaults = function() return C.defaults.bars[id] end, -- s6-ui-settings: the page's reset
            tabs = {
                { name = "General Settings", args = C.generalArgs },
                -- s6-optimize (round 34): share the panel tab, including Always Hide's modifier need; keys stay the same.
                { name = "Visibility", args = TK.StandardVisibilityArgs },
                -- s6-modular-g (interfaces, phase 1): Layout (scale and place) took the Alignment tab's place
                { name = "Layout", args = TK.LayoutArgs(function() return "bar" .. i end, { extra = {
                    { type = "header", name = "Button Order" },
                    { type = "select", key = "growH", name = "Horizontal",
                      values = { { value = "RIGHT", text = "Left to right" }, { value = "LEFT", text = "Right to left" } } },
                    { type = "select", key = "growV", name = "Vertical",
                      values = { { value = "DOWN", text = "Top to bottom" }, { value = "UP", text = "Bottom to top" } } },
                } }) },
            },
        }
    end
    return nodes
end
