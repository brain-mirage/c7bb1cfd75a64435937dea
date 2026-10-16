local C = TK.GetComponent("micromenu")

-- s6-ui-settings (the owner, 2026-10-02): the buttons, in their default order: an id, the name the tooltip and the
-- settings list show, the icon (the character's is its head, main.lua), the button's colour, and the commands its action
-- is bound to on the Key Bindings page (the tooltip shows the first bound key; the button has no binding of its own).
-- Mail and Parcel are off by default: the minimap's border and the Mail and Parcels panel show them already; so is Bag
-- (the owner, 2026-10-03): the bag bar's button is the bag's, this one only an option, with the same brown backpack.
C.BUTTONS = {
    { id = "character", name = "Character", tip = "The character window", hue = { 0.45, 0.32, 0.22 },
      commands = { "TOGGLECHARACTER" } },
    { id = "spellbook", name = "Spell Book", tip = "The character window's Spell Book tab", icon = "emoji:1f4d6",
      hue = { 0.25, 0.35, 0.6 }, commands = { "TOGGLESPELLBOOK" } },
    { id = "bag", name = "Bag", tip = "The bag", icon = "tk:backpack", hue = { 0.4, 0.4, 0.28 }, commands = { "TOGGLEBAG" },
      off = true },
    { id = "social", name = "Social", tip = "The group and the ignore list", icon = "tk:people", hue = { 0.28, 0.42, 0.45 },
      commands = { "TOGGLEGROUP", "TOGGLESOCIAL" } },
    { id = "emotes", name = "Emotes", tip = "The expressions", icon = "tk:smiley", hue = { 0.45, 0.35, 0.5 },
      commands = { "TOGGLEEMOTES" } },
    { id = "boards", name = "Boards", tip = "The notice boards", icon = "emoji:1f4dc", hue = { 0.5, 0.42, 0.2 },
      commands = { "BOARDS" } },
    { id = "menu", name = "Menu", tip = "The original's menu: Userlook, Board, Mail, UserList, Friends, Target, Hotkey, "
      .. "Profile, Ranking, Quit", icon = "tk:menu", hue = { 0.35, 0.3, 0.45 } },
    { id = "editmode", name = "Edit Mode", tip = "Unlock the frames to move them", icon = "emoji:1f527",
      hue = { 0.2, 0.45, 0.3 } },
    { id = "settings", name = "Settings", tip = "Open the settings", icon = "emoji:2699", hue = { 0.5, 0.12, 0.12 } },
    { id = "logout", name = "Log Out", tip = "Back to the login screen", icon = "emoji:1f6aa", hue = { 0.3, 0.3, 0.32 } },
    { id = "mail", name = "Mail", tip = "Your letters, as the minimap's mail icon", icon = "emoji:1f4ea", hue = { 0.3, 0.35, 0.45 },
      commands = { "MAIL" }, off = true },
    { id = "parcel", name = "Parcels", tip = "Your parcels, as the minimap's parcel icon", icon = "emoji:1f4e6",
      hue = { 0.42, 0.33, 0.22 }, off = true },
}

local order = {}
for _, b in ipairs(C.BUTTONS) do order[#order + 1] = { id = b.id, on = not b.off } end

C.defaults = TK.Visibility.Defaults({
    padding = 2,
    vertical = false,
    buttons = order, -- s6-ui-settings: the order the buttons are drawn in, and which are on
})

C.defaultPosition = { "BOTTOMRIGHT", "BOTTOMRIGHT", -20, 18 }

--- The buttons in the page's order, each on or off: the profile's list, with a button it does not name (a profile from
--- before, a later version's new button) added at the end by its own default.
function C:Buttons()
    local list, seen = {}, {}
    for _, e in ipairs(self:DB().buttons or {}) do
        if type(e) == "table" and not seen[e.id] then
            for _, def in ipairs(C.BUTTONS) do
                if def.id == e.id then
                    seen[e.id] = true
                    list[#list + 1] = { id = e.id, on = e.on ~= false }
                end
            end
        end
    end
    for _, def in ipairs(C.BUTTONS) do
        if not seen[def.id] then list[#list + 1] = { id = def.id, on = not def.off } end
    end
    return list
end

--- The settings list's rows: each button's name and icon (the character's head as the bar shows it). s6-interface-5x
--- (round 13, the separation's step 11): with the bar not loaded (off), each button's own icon.
local function items()
    local t = {}
    for _, b in ipairs(C.BUTTONS) do
        local icon, coords = b.icon, nil
        if C:Loaded() then icon, coords = C:Icon(b) end
        t[b.id] = { text = b.name, icon = icon, coords = coords }
    end
    return t
end

C:StandardSettings("micromenu", {
    { type = "header", name = "Buttons" },
    { type = "range", key = "padding", name = "Padding", min = -4, max = 20, step = 1 },
    { type = "toggle", key = "vertical", name = "Vertical" },
    { type = "description", name = "The buttons in the order they are drawn: tick a button to show it, drag a row (or click it, then press Up or Down) to move it. A key opens a window through its action on the Key Bindings page, whichever buttons show." },
    { type = "orderlist", key = "buttons", name = "Button list", items = items,
      get = function() return C:Buttons() end,
      set = function(_, list) C:DB().buttons = list; if C:Loaded() then C:ApplySettings() end end },
}, { sub = 12 }) -- s6-ui-settings: its own panel, a top-level row of the Interface tab (the owner)
