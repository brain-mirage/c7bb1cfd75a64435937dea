-- Buffs, debuffs and the aether list: defaults and settings, as in WoW's and Bartender's buff options.

local C = TK.GetComponent("auras")

local function iconDefaults(extra)
    local d = TK.Visibility.Defaults({
        size = 36,
        perRow = 8,
        spacing = 4,
        growH = "LEFT",
        growV = "DOWN",
        showTime = true,
        blink = true,
    })
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

C.defaults = {
    buffs = iconDefaults(),
    debuffs = iconDefaults({ size = 40 }),
    aethers = TK.Visibility.Defaults({ enabled = false, width = 220, maxRows = 8, showBars = true }),
}
-- s6-ui-core (round 53): the aether list's panel has its own transparency (TK.PanelTransparencyArgs)
for k, v in pairs(TK.PanelTransparencyDefaults) do C.defaults.aethers[k] = v end

-- Left of the minimap: buffs on top, debuffs under them; the aether list at the right edge.
C.defaultPositions = {
    buffs = { "TOPRIGHT", "TOPRIGHT", -210, -20 },
    debuffs = { "TOPRIGHT", "TOPRIGHT", -210, -130 },
    aethers = { "RIGHT", "RIGHT", -110, 120 },
}

local iconArgs = {
    { type = "toggle", key = "enabled", name = "Enabled" },
    { type = "header", name = "Icons" },
    { type = "range", key = "size", name = "Size", min = 16, max = 64, step = 1 },
    { type = "range", key = "perRow", name = "Icons per Row", min = 1, max = 20, step = 1 },
    { type = "range", key = "spacing", name = "Spacing", min = 0, max = 20, step = 1 },
    { type = "select", key = "growH", name = "Horizontal Growth",
      values = { { value = "LEFT", text = "Right to left" }, { value = "RIGHT", text = "Left to right" } } },
    { type = "select", key = "growV", name = "Vertical Growth",
      values = { { value = "DOWN", text = "Downwards" }, { value = "UP", text = "Upwards" } } },
    { type = "header", name = "Time" },
    { type = "toggle", key = "showTime", name = "Remaining Time" },
    { type = "toggle", key = "blink", name = "Blink in the Last 10 s" },
    { type = "header", name = "Style" },
    { type = "range", key = "alpha", name = "Alpha", min = 0.1, max = 1, step = 0.05 },
    { type = "description", name = "Which effects are buffs and which are debuffs comes from lua/data/effects.lua. Names it does not know show among the buffs, marked unclassified. Right-click an icon to move it to the other frame; the choice is kept for this computer." },
}

local aetherArgs = {
    { type = "toggle", key = "enabled", name = "Enabled" },
    { type = "header", name = "List" },
    { type = "range", key = "width", name = "Width", min = 140, max = 360, step = 5 },
    { type = "range", key = "maxRows", name = "Rows", min = 1, max = 20, step = 1 },
    { type = "toggle", key = "showBars", name = "Show Bars" },
    { type = "header", name = "Style" },
    { type = "range", key = "alpha", name = "Alpha", min = 0.1, max = 1, step = 0.05 },
}
TK.PanelTransparencyArgs(aetherArgs) -- s6-ui-core (round 53): the aether list's panel has its own transparency
aetherArgs[#aetherArgs + 1] = { type = "description", name = "The running aethers (the game's cooldowns), shortest first. The same aethers drive the numbers and clocks on the action buttons." }

local function node(key, title, sub, args)
    return {
        id = key,
        title = title,
        parent = "Buffs and Aethers", -- s6-ui-settings (nested settings menus): their title, was group
        order = C.order,
        sub = sub,
        frameKey = key,
        db = function() return C:DB()[key] end,
        defaults = function() return C.defaults[key] end, -- s6-ui-settings: the page's reset
        tabs = {
            { name = "General Settings", args = args },
            { name = "Visibility", args = TK.StandardVisibilityArgs },
            -- s6-modular-g (interfaces, phase 1): Layout (the Scale and the place) took the Alignment tab's place
            { name = "Layout", args = TK.LayoutArgs(function() return key end) },
        },
    }
end

function C:SettingsNodes()
    return {
        node("buffs", "Buffs", 1, iconArgs),
        node("debuffs", "Debuffs", 2, iconArgs),
        node("aethers", "Aether List", 3, aetherArgs),
    }
end
