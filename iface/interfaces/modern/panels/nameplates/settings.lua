local C = TK.GetComponent("nameplates")

-- The starting options are the original's (settings.toml's [options], imported from its settings when it was installed;
-- its defaults otherwise, all on): group bars (GroupBar), carnage dye (CarnageColor). Display names (ShowUserName) is the
-- game layer's global setting (TK.Game.Options.ShowNames; s6-play-modes round 8, W6), shown here as this computer's.
--
-- s6-ui-core (round 82; the owner, 2026-10-09: "items drawn over players/enemies ... their own panes ... two subpages like
-- Players and NPC"): what Modern draws over others is one pane, Nameplates, with every setting of it: the names here; under
-- it Players and NPCs, each kind's health bars (bars.lua) and effect icons (Effect Icons' rows, kept in its own settings:
-- panels/enemyicons), and Effect Icons, the icons' look and the name lists.
local H = __tk
local V = require("interfaces.modern.vitals")

C.defaults = {
    enabled = true,
    show = "all",
    carnage = H:ClientSettingBool("options", "carnage_color"),
    groupBars = H:ClientSettingBool("options", "group_bar"),
    size = 12,
    -- s6-ui-core (round 82): the bars over others, each kind on its own page; off until turned on (the owner: "you can also
    -- toggle on health bars for enemies and players")
    playerBars = "off",
    playerMana = true,
    playerNumbers = "none",
    playerDamage = false,
    npcBars = "off",
    npcNumbers = "none",
    npcDamage = false,
    -- s6-ui-core (round 82; the owner: "you can toggle them on and off there"): the floating damage and healing numbers
    -- over each kind, on as the original draws them
    playerFloating = true,
    npcFloating = true,
}

--- s6-ui-core (round 82): for whom something over others shows (each kind's bars and effect icons): never, the target, the
--- one under the mouse, both, or everyone in view.
C.WHEN = {
    { value = "off", text = "No one" },
    { value = "target", text = "The target" },
    { value = "hover", text = "The one under the mouse" },
    { value = "targethover", text = "The target and the one under the mouse" },
    { value = "always", text = "Everyone in view" },
}

--- Whether unit id gets what a WHEN choice says, given the target's and the hovered figure's ids (0: none).
function C.Shows(when, id, target, hover)
    if when == "always" then return true end
    if when == "target" then return id == target end
    if when == "hover" then return id == hover end
    if when == "targethover" then return id == target or id == hover end
    return false
end

--- s6-ui-core (round 82): the room unit id's health bar takes under its name (0: none, or the nameplates not loaded), for
--- what goes below it there (Effect Icons' "under the name"). bars.lua keeps it (C.barSpace) as it draws them.
function C:BarSpace(id)
    return self:Loaded() and self.barSpace and self.barSpace[id] or 0
end

local NUMBERS = { { value = "none", text = "None" } }
for _, f in ipairs(V.FORMATS) do NUMBERS[#NUMBERS + 1] = f end

local on = TK.Needs("Nameplates > Enabled", function(db) return db.enabled end)
local damage = TK.Needs("Nameplates > Show Damage (Shift+F10)", function() return TK.Game.Options.Get("show_damage") end)

C.tabs = {
    { name = "General Settings", args = {
        { type = "toggle", key = "enabled", name = "Enabled" },
        { type = "toggle", name = "Display Names (N)", machine = true, width = "full",
            get = function() return TK.Game.Options.ShowNames() end,
            set = function(_, on) TK.Game.Options.SetShowNames(on) end,
            default = function() return H:ClientSettingDefaultInt("options", "show_user_name") ~= 0 end },
        -- s6-optimize (round 34): the names-on branch in main.lua uses these; the original's hovered name with
        -- names off uses neither. Display Names is the game's global option, also changed by N; its own row keeps these beneath it.
        { type = "group", requires = { TK.Needs("Display Names (N)", function() return TK.Game.Options.ShowNames() end) }, args = {
            { type = "select", key = "show", name = "Show Names For",
              values = { { value = "all", text = "Everyone" }, { value = "hover", text = "The one under the mouse" },
                         { value = "target", text = "The target only" } } },
            { type = "toggle", key = "carnage", name = "Names in Carnage Dye" },
        } },
        { type = "range", key = "size", name = "Text Size", min = 8, max = 20, step = 1 },
        -- s6-ui-core (round 82; the owner, 2026-10-09: the floating damage and healing numbers are toggled in this pane):
        -- the original's Show Damage (Config::m_showDamage: settings.toml's show_damage, also turned over by Shift+F10 and
        -- the Game Options window's row), moved here from the Game Options page; Players and NPCs choose over whom.
        { type = "header", name = "Floating Numbers" },
        { type = "toggle", name = "Show Damage (Shift+F10)", machine = true,
            get = function() return TK.Game.Options.Get("show_damage") end,
            set = function(_, on) TK.Game.Options.Set("show_damage", on) end,
            default = function() return H:ClientSettingDefaultBool("options", "show_damage") end,
            desc = "The damage and healing numbers that rise over a figure when it is hit or healed, as the original draws them (the original's switch: Shift+F10 turns it over too)." },
        { type = "description", name = "The names the server gives the figures, where the original puts them. With Display Names off only the name under the mouse shows, as in the original; N (also with Ctrl or Alt) turns them on or off. Players and NPCs, under this page, set the health bars, floating numbers and effect icons over each." },
    } },
}

--- One kind's page (s6-ui-core round 82): its health bars (prefix: the keys' "player" or "npc"; first: rows before the
--- numbers, after: rows after the bars' own), then its effect icons (Effect Icons' rows for kind, "player" or "creature":
--- its C:KindArgs), then the page's text.
local function kindArgs(prefix, kind, first, after, text)
    local bars = TK.Needs("Show Bars For", function(db) return db[prefix .. "Bars"] ~= "off" end)
    local shown = {}
    for _, a in ipairs(first) do shown[#shown + 1] = a end
    shown[#shown + 1] = { type = "select", key = prefix .. "Numbers", name = "Numbers", values = NUMBERS,
                          desc = "Numbers too wide for one line are drawn as two rows over the bar." }
    shown[#shown + 1] = { type = "toggle", key = prefix .. "Damage", name = "Show Damage Taken",
                          desc = "The health just lost turns red, then shrinks away." }
    local args = {
        { type = "header", name = "Health Bars" },
        { type = "select", key = prefix .. "Bars", name = "Show Bars For", values = C.WHEN, requires = { on } },
        { type = "group", requires = { on, bars }, args = shown },
    }
    for _, a in ipairs(after) do args[#args + 1] = a end
    args[#args + 1] = { type = "header", name = "Floating Numbers" }
    args[#args + 1] = { type = "toggle", key = prefix .. "Floating", name = "Show Floating Numbers",
                        requires = { on, damage },
                        desc = "The damage and healing numbers over them, as the original draws them. Off, they are not drawn; nothing else changes." ..
                               -- s6-ui-core (round 83; the head's review of round 82): the player's own stay with Show Damage
                               (prefix == "player" and " Your own numbers stay, with Show Damage." or "") }
    for _, a in ipairs(TK.GetComponent("enemyicons"):KindArgs(kind)) do args[#args + 1] = a end
    args[#args + 1] = { type = "description", name = text }
    return args
end

--- The kind pages' rows, made once (the settings window keeps a row's view by the row: core/settings.lua's groups):
--- Players has the original's group bars (GroupBar), drawn by main.lua.
local function kindPages()
    local players = kindArgs("player", "player", {
        { type = "toggle", key = "playerMana", name = "Show Mana Where Known",
          desc = "Your group members' mana, from the group list. Of other players only health is known." },
    }, {
        { type = "toggle", key = "groupBars", name = "The Original's Group Bars", requires = { on },
          desc = "Your group members' HP and MP as the original draws them, at their own place over the figure. While on, they take the place of the bars above for your group members." },
    }, "A group member's health is known in points, from the group list; another player's is the percentage its last hit showed, full until one is seen. Nothing is sent.")
    local npcs = kindArgs("npc", "creature", {}, {},
        "An NPC's health is the percentage its last hit showed: the server sends no more. Full until a hit is seen. Nothing is sent.")
    return { { { name = "General Settings", args = players } }, { { name = "General Settings", args = npcs } } }
end

--- The pane's pages: Nameplates (the names), and under it Players and NPCs (Effect Icons' page is the third, its own:
--- panels/enemyicons).
function C:SettingsNodes()
    local db, defaults = function() return self:DB() end, function() return self.defaults end
    self.kindTabs = self.kindTabs or kindPages()
    return {
        { id = "nameplates", title = self.title, order = self.order, tabs = self.tabs, db = db, defaults = defaults },
        { id = "nameplatesplayers", title = "Players", parent = "nameplates", order = self.order + 0.1, db = db,
          defaults = defaults, tabs = self.kindTabs[1] },
        { id = "nameplatesnpcs", title = "NPCs", parent = "nameplates", order = self.order + 0.2, db = db,
          defaults = defaults, tabs = self.kindTabs[2] },
    }
end

--- s6-play-modes (round 8, W6): a profile's Display names from before it was one global setting is carried over once,
--- from a profile whose nameplates were on (the only ones the drawing showed it by; 7.x's and 5.x's profiles have them
--- off, and their N changed nothing on screen), and dropped. True when something changed (the profile is then saved).
function C:Migrate(saved)
    if saved.names == nil then return false end
    if saved.enabled ~= false and TK.Game.Options.ShowNames() ~= (saved.names == true) then
        TK.Game.Options.SetShowNames(saved.names == true)
    end
    saved.names = nil
    return true
end
