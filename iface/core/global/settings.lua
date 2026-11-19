-- The settings window, laid out like Bartender4's: a title plate; Lock, Button Lock and Key Bindings along the
-- top; a tree of components on the left; tabs on the right; a Close button at the bottom.
--
-- Pages are generated from each component's settings schema (declared in its settings.lua). A node has tabs; a
-- tab has args, each one of:
--
--   { type = "header", name = "Bar Style & Layout" }
--   { type = "toggle", key = "enabled", name = "Enabled" }
--   { type = "range",  key = "alpha", name = "Alpha", min = 0.1, max = 1, step = 0.05 }
--   { type = "range",  name = "View", min = 64, max = 1024, step = 8, gap = 16, stop = { text = "Off", value = 0 },
--       handles = { { key = "near" }, { key = "far", relative = 1, toggle = { key = "fade", name = "Fade Out" } } } }
--       s6-ui-core (round 60; the owner's "single one where you can enable multiple sliders"): one slider (W.Slider) with
--       a handle for each value, each under its own key (or get and set, as an arg's), shown from another handle
--       (relative), turned on and off by a check box (toggle, its own key), gap apart and pushing; stop, an end stop past
--       the maximum (its value a number, as stored; a single range may have one too)
--       s6-ui-core (round 62): a toggle's desc is its box's tooltip; togglesBeside = true puts the boxes right of the
--       track; stop.onlyWithout = i keeps the stop only while handle i is off
--       s6-ui-core (round 149): a single range's min and max may be functions of the node, read as its page shows (the
--       Layout tab's offsets: the screen's size then)
--   { type = "dualrange", key = "wind_speed", ... }   s6-effects (round 11): two handles, their pair { low, high } under one key
--   { type = "select", key = "anchor", name = "Anchor", values = { {value=..., text=...}, ... } or function }
--   { type = "execute", name = "Reset Position", func = function(node) ... end }
--   { type = "input",  name = "New Profile", set = function(node, text) ... end }   set on Enter, then cleared
--   { type = "input",  name = "Host", live = true, get = ..., set = ... }   keeps its text, set as it is typed
--   { type = "description", name = "Some text" }
--   { type = "binding", name = "Character", command = "TOGGLECHARACTER" }   click, then press a key to bind it
--   { type = "break" }   ends the current row
--   { type = "group", requires = { ... }, indent = 1, args = { ... } }   s6-ui-core (round 60; the owner, 2026-10-06: "You
--       can make a "group" put a checkbox some text etc and set the group to depend on setting z"): rows of any type, other
--       groups too, each on a line of its own, indent steps in from the group's place (1 when left out: a feature's
--       sub-features under it; 0: a page's body under its master switch); the group's needs are each inner row's too
--   { type = "row", args = { ... } }   s6-interface-5x (round 12): its controls side by side on a row of their own, each
--       its rowWidth wide (else a column's), the check boxes and buttons level with a dropdown's box; the page's reset,
--       S:SetOption and the lookups treat each as a control of the tab (s6-ui-core round 57: controls)
--   { type = "orderlist", key = "buttons", name = "Buttons", items = function(node) ... end }   s6-ui-settings: a list
--       of switches in order, { { id, on }, ... }: a row per item with a box, its icon and its name (items(node)[id] =
--       { text, icon, coords }), dragged up or down (or, once clicked, moved with the Up and Down keys) to reorder
--   { type = "namelist", key = "buffNames", name = "Buffs" }   s6-ui-core (round 44, the owner: "an editable list"): a
--       list of names, { "Haste", "#84" }: a row per name (its text, edited in place, and a Remove button), then a box
--       and an Add button for a new one; the page is laid out again when the rows change
--
-- Optional on any arg: get(node) / set(node, value) instead of the key, disabled(db, node), hidden(db, node),
-- width = "full", requires = { TK.Needs(...) or TK.NeedSetting(...) } (s6-ui-core round 54: the (!) rule, argNeeds; round
-- 60: or, by the need's result, hidden or disabled while it is unmet, on any row type; s6-optimize round 33: and the game
-- reads the row as off meanwhile, through Component:Applied), changed(node, value)
-- (s6-ui-core round 56: run after each change and reset of the arg, for what the arg's row affects beyond its
-- component), indent = n (s6-ui-core round 60: the control on a row of its own, n steps in, so a feature's sub-features
-- sit under it; 0 at the left). Values are written to the node's db and applied live through the component.
--
-- s6-ui-settings: the page's reset icon (the owner, 2026-10-02) puts a tab's or the whole page's settings back to their
-- defaults, each as a click would: an arg with a key takes its value in a first profile of the active interface
-- (s6-interface-5x, round 11: firstValues), else node.defaults()[key] (the component's C.defaults); an arg
-- with its own get and set takes default = value or function(node), read from where the value is defined; an input
-- only with its own default (an input is otherwise an action: New Profile); an execute with resets = true (Reset
-- Position) runs; a binding's command gets its default keys back. An arg that only reads (get without set) is never
-- changed. A node with noReset (the player's data) has no icon.
--
-- A node with machine = true keeps its values in the machine settings (TK.Machine) instead of the profile. Pages by
-- context, as WoW's (head note 27): at the login screen only the nodes with atLogin = true (Interface, Key Bindings,
-- Graphics, Sound) and the login-only ones (loginOnly = true: Servers, Local Server, Library) are listed; in the game
-- every node but the login-only ones.
--
-- s6-ui-settings: the list is in three tabs (the owner, 2026-10-02): General (the settings that are not about one piece
-- of the interface), Interface (the components) and Plugins (Global, then each plugin by its name). A node's
-- category field says which ("general", "interface" or "plugins"; a component's default is "interface"). A tab with no
-- page here (at the login screen) is hidden. The window reopens on the tab and row last open, kept in the profile.
--
-- s6-ui-settings: each tab's list is a tree of any depth (the owner, 2026-10-03, "nested settings menus"). An entry is
-- a page (a node with tabs) or a title only (a node without tabs). A node goes under the entry its parent field names:
--
--   { id = "remote", title = "Remote-Protocol", category = "plugins", parent = "plugins", tabs = { ... } }   a page
--   { id = "remoteplugins", title = "Plugins", category = "plugins", parent = "remote" }                     a title
--
-- (a child names its own category, as its parent's). A parent that no node of the tab names is a title made for it, with
-- the parent's text (parent = "Bars": the bars' title). An entry with children has a + / - button; the entries closed
-- with it are kept in the profile with the tab and rows. A click on a page shows it; on a title, its first page
-- (s6-ui-core round 54; the owner: Graphics opens General).
--
-- Optional on a node (s6-peer's remote protocol pages): shown = function() return bool end; false leaves the node and
-- everything under it out of the list, until TK.Settings:RefreshTree() draws it again (a page calls it when its switch
-- changes). A page that is not shown gives way to the nearest shown entry above it. Opening an entry by its id (a
-- shortcut, TK.Settings:Open or Select) opens the entries above it; a title, generated ones too, shows its first page.
-- Where a node is listed: listTop = true (s6-interface-5x round 12: its General page) first on the Interface tab, whose
-- list TK.Panels:GroupRoots makes (s6-ui-core round 83: General and the pages of no pane at the top, then the Panes title
-- with the shown interface's panes and the shared ones, then 7.x's and 5.x's Decoration); last = true (s6-devtools round
-- 3: the Debug page) last in its tab.

local U = TK.Util
local W = TK.UI

local S = { selected = nil, tabIndex = 1 }
TK.Settings = S

local WIDTH, HEIGHT = 810, 600

-- The list's tabs, in their order; a node's category names one.
S.categories = {
    { id = "general", title = "General" },
    { id = "interface", title = "Interface" },
    -- s6-reprojection-cloud-3 (run 21; the owner, head note 67: an "Aids" section beside the others): components/aids
    { id = "aids", title = "Aids" },
    { id = "plugins", title = "Plugins" },
    { id = "experimental", title = "Experimental" }, -- s6-modular (round 13; the owner): the world renderers (components/worldrenderer)
}
-- The General list's order (the brief's); the other lists go by their nodes' order.
local GENERAL_ORDER = { servers = 1, library = 2, profiles = 3, graphics = 4, sound = 5, keybindings = 6, originalkeys = 7,
                        classic = 8, casting = 9, gameoptions = 10, interface = 11 }
GENERAL_ORDER.graphicsstyles = 4.5 -- s6-modular: the Graphics Styles page (s6-ui-core round 54: Graphics' Asset Styles)
-- s6-ui-core (round 83; the owner, 2026-10-09): Graphics' World View, how the game world is drawn (components/worldview's
-- second page), after its General
GENERAL_ORDER.worldviewgraphics = 4.4
-- s6-ui-core (round 54): Sound's subpages after its General (components/audio); Graphics' Advanced after Asset Styles
GENERAL_ORDER.soundplayer, GENERAL_ORDER.soundmidi, GENERAL_ORDER.soundadvanced = 5.1, 5.2, 5.3
GENERAL_ORDER.graphicsadvanced, GENERAL_ORDER.graphicsadvancedgeneral, GENERAL_ORDER.interpolation = 4.55, 4.551, 4.552
-- s6-ui-core (round 60; the owner, 2026-10-06): Lighting and Weather right after Motion
GENERAL_ORDER.advancedlighting, GENERAL_ORDER.advancedweather = 4.553, 4.554

-- s6-ui-core (round 54; the owner, 2026-10-05: "Most of the experimental settings are getting moved out, so there will be
-- more subpages"): where a page is listed, by its id, over its own node's category, parent and title. Moving a page (out
-- of the Experimental tab, under another entry) is a line here; its keys, and so the saved values, stay its component's.
-- Round 60 (the owner, 2026-10-06: "Move Lighting and waether from experimental to their own subpages"): s6-effects'
-- two pages; each page's own file names it (Motion, Lighting, Weather), so its tab says the same.
S.places = {
    interpolation = { category = "general", parent = "graphicsadvanced" }, -- s6-interp's page, Motion
    advancedlighting = { category = "general", parent = "graphicsadvanced" }, -- s6-effects' (components/advancedeffects)
    advancedweather = { category = "general", parent = "graphicsadvanced" },
    -- s6-ui-core (round 60; the owner, 2026-10-06: "create a new Control Subpage and hhave the keybinding subpage nested
    -- under it. It will Need a general page as well ... but I need to figure out what to put on it first"): Key Bindings
    -- under a Controls title, where it was in the list; the title opens its first page. Its General, when the owner has
    -- chosen what is on it (open question 75), is a node with parent = "Controls" ordered before Key Bindings (5.9).
    keybindings = { parent = "Controls" },
}
-- s6-ui-core (round 60; the owner, 2026-10-06): the menu button's page is the Interface tab's, under Panes since round 83
-- (core/global/components/menubutton: a shared panel since this round), so it has no place in this list any more.
GENERAL_ORDER.localserver = 1.5 -- s6-play-modes: the Local Server page (core/global/localserver.lua), right after Servers

local function categoryOf(node) return node.category or "interface" end

-- s6-ui-settings: a node with tabs is a page; one without is a title only (the header's "nested settings menus").
local function isPage(node) return node ~= nil and node.tabs ~= nil end

local frame, treeScroll, tabBar, pageScroll, pageContent
local bindingRows -- the binding rows' own frame (placeBindingRows)
local resetButton, resetAsk
local requestMarker
local keyMarker -- s6-ui-core (round 80): F8's music request outside the window (S:OpenMusic)
local build

--- s6-ui-bars: the status line's text, grey, or red for an error (the Key Bindings page's "Function is Now Unbound!").
--- The line is the shell's (SettingsWindow.SetStatus, round 172).
local function setStatus(text, err) __tk:ShellSettingsStatus(text, err == true) end
local musicBlocker, musicOpen, musicWanted, musicSeen, musicPart, musicLevel
local musicOk   -- the music dialog's window whose OK a control leaving the Sound page pressed (S:LeavesMusic)

-- ----- widget pools (frames are never destroyed, so page widgets are reused) -----

-- s6-ui-core (round 172, U-64 step 4 parts b and c): the plain controls' pools, the one-of's and the style choice's
-- among them, are the shell's (SettingsWindow.PageControls.cs).
local pools = { range = {}, binding = {}, bindingHeading = {}, orderlist = {}, namelist = {} }
local used = {}

local function acquire(kind, make)
    local pool = pools[kind]
    local w = table.remove(pool)
    if not w then w = make() end
    w.__kind = kind
    used[#used + 1] = w
    w:ClearAllPoints()
    w:Show()
    return w
end

local function releaseAll()
    for _, w in ipairs(used) do
        w:Hide()
        table.insert(pools[w.__kind], w)
    end
    U.Wipe(used)
end

-- ----- the page -----

local function nodeDB(node) return node.db and node.db() or {} end

local function argValue(node, arg)
    if arg.get then return arg.get(node) end
    return nodeDB(node)[arg.key]
end

local function setArg(node, arg, value)
    -- the owner's hotfix (2026-10-06): a panel switch whose keys clash with keys in use asks first, and changes nothing
    -- until the player chooses (TK.Interfaces:Blocks)
    if TK.Interfaces:Blocks(node, arg.key, value) then return S:RefreshPage() end
    if arg.set then
        arg.set(node, value)
    else
        nodeDB(node)[arg.key] = value
        if node.component then node.component:Changed(node, arg.key, value) end
        if node.onChange then node.onChange(arg.key, value) end
        TK.Interfaces:SettingChanged(node, arg.key, value) -- s6-modular-g (interfaces, phase 2): a panel's keys
    end
    if arg.changed then arg.changed(node, value) end -- s6-ui-core (round 56)
    -- s6-optimize (round 33): what reads its settings as the game takes them, a sub-setting's needs met
    -- (Component:Applied), follows at once, a need on another page too.
    TK.Components:ApplyReaders()
    -- s6-ui-core (round 63): a profile row on a machine page can explicitly override its save/status scope.
    local machine = arg.machine
    if machine == nil then machine = node.machine end
    if machine then
        TK.Machine:MarkDirty()
        setStatus("Saved to this computer's settings")
    else
        TK.DB:MarkDirty()
        setStatus("Saved to profile '" .. TK.DB.name .. "'")
    end
    S:RefreshPage()
end

-- ----- the page's reset (s6-ui-settings) -----

local RESET_TYPES = { oneof = true, toggle = true, range = true, select = true, orderlist = true, namelist = true,
                      stylechoice = true, -- s6-ui-core (round 54)
                      dualrange = true } -- s6-effects (round 11)

local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

--- The default an arg is reset to, or nil when it has none (see the header).
local function defaultOf(node, arg)
    local d = arg.default
    if type(d) == "function" then d = d(node) end
    if d == nil and arg.key and node.defaults then d = (node.defaults() or {})[arg.key] end
    return d
end

local function resettable(node, arg)
    if arg.type == "binding" or arg.resets then return true end
    if arg.get and not arg.set then return false end
    if not (RESET_TYPES[arg.type] or (arg.type == "input" and arg.default ~= nil)) then return false end
    return defaultOf(node, arg) ~= nil
end

-- ----- s6-ui-core (round 60): groups (the header's "group") -----
-- A grouped row is shown through a view of it: its needs with its groups', its indent from its group's. The views are
-- kept (weakly, by group and row), so a row has the same view each time: the page's reset finds a value it read before
-- (firstValues) by the row.
local views = setmetatable({}, { __mode = "k" })

local function view(g, a, needs, depth)
    local byRow = views[g]
    if not byRow then
        byRow = setmetatable({}, { __mode = "k" })
        views[g] = byRow
    end
    local v = byRow[a]
    if v then return v end
    local all = {}
    for _, need in ipairs(needs) do all[#all + 1] = need end
    for _, need in ipairs(a.requires or {}) do all[#all + 1] = need end
    v = setmetatable({ requires = all, indent = depth + (a.indent or 0) }, { __index = a })
    if a.type == "row" then -- a row's controls carry the group's needs and the row's own (round 61) too
        v.args = {}
        for i, r in ipairs(a.args) do v.args[i] = view(g, r, all, depth) end
    end
    byRow[a] = v
    return v
end

--- Calls each(row) for every row of args, the groups opened (a grouped row as its view), in order.
local function walk(args, each, g, needs, depth)
    for _, a in ipairs(args or {}) do
        if a.type == "group" then
            local inner = {}
            for _, need in ipairs(needs or {}) do inner[#inner + 1] = need end
            for _, need in ipairs(a.requires or {}) do inner[#inner + 1] = need end
            walk(a.args, each, a, inner, (depth or 0) + (a.indent or 1))
        elseif g then
            each(view(g, a, needs, depth))
        elseif a.type == "row" and a.requires then
            -- s6-ui-core (round 61; Astra's review of round 60, P3): a row's own needs reach its controls, as a group's
            each(view(a, a, {}, 0))
        else
            each(a)
        end
    end
end

--- s6-ui-core (round 60): a slider's handles and their check boxes (a range with handles, the header's), each as a
--- control of its own (a range or a toggle, read and set as an arg), for the page's reset, S:SetOption and the profile's
--- value rules. Kept by the slider's arg, as the views.
local parts = setmetatable({}, { __mode = "k" })

local function sliderParts(a)
    if parts[a] then return parts[a] end
    local out = {}
    for _, h in ipairs(a.handles) do
        out[#out + 1] = setmetatable({ type = "range", name = h.name or a.name, min = a.min, max = a.max, step = a.step,
                                       stop = a.stop }, { __index = h })
        if h.toggle then out[#out + 1] = setmetatable({ type = "toggle" }, { __index = h.toggle }) end
    end
    parts[a] = out
    return out
end

--- s6-ui-core (round 57; s6-interface-5x's row control, FOR-s6-ui-core-r12-what-the-interface-tab-needs.md): a tab's
--- controls, each of a row's in the row's place, so the page's reset and S:SetOption reach a control in a row as one on
--- its own. s6-ui-core (round 60): a group's in the group's place, and a slider's handles and their boxes.
local function addControl(out, a)
    if a.type == "range" and a.handles then
        for _, p in ipairs(sliderParts(a)) do out[#out + 1] = p end
    else
        out[#out + 1] = a
    end
end

local function controls(tab)
    local out = {}
    walk(tab.args, function(a)
        if a.type == "row" then
            for _, r in ipairs(a.args) do addControl(out, r) end -- Astra's r60-2 review: a slider in a row too
        else
            addControl(out, a)
        end
    end)
    return out
end
S.Controls = controls

--- s6-ui-core (round 149): a range's ends as numbers: its min and max, or, where they are functions, what they give for
--- the node now (the Layout tab's offsets: the screen's size; TK.LayoutArgs in core/global/editmode.lua). For the page
--- (builders.range) and a start's named options (core/startup.lua).
function S.RangeEnds(node, arg)
    local min, max = arg.min, arg.max
    if type(min) == "function" then min = min(node) end
    if type(max) == "function" then max = max(node) end
    return min, max
end

local function tabResettable(node, tab)
    for _, a in ipairs(controls(tab)) do
        if resettable(node, a) then return true end
    end
    return false
end

--- s6-interface-5x (round 11, W12; interface-separation.md, 5.17): the values the rows over the profile take back, read
--- in a first profile of the active interface (TK.DB:InFirstProfile, made as Reset Profile makes one): a keyed row with no
--- getter of its own, whose node's table there is another table than the live one (it reads the profile). So a 7.x
--- panel's switch, the screen's map-pane place or the world view's dim come back as a first start in that interface sets
--- them. Every other row (a machine node's, one with its own getter) keeps its own default (defaultOf). Before, each row
--- took its component's default, Modern's view: in 7.x a 7.x panel's page reset turned the panel off.
local function firstValues(node, tabs)
    local out = {}
    if not node.db then return out end
    local live = node.db()
    TK.DB:InFirstProfile(function()
        local first = node.db()
        if first == live then return end
        for _, tab in ipairs(tabs) do
            for _, a in ipairs(controls(tab)) do
                if a.key and not a.get and first[a.key] ~= nil then out[a] = first[a.key] end
            end
        end
    end)
    return out
end

--- Puts the given tabs of the node back to their defaults, each value as its control would set it.
function S:Reset(node, tabs)
    local first = firstValues(node, tabs) -- s6-interface-5x (round 11, W12)
    local commands = {}
    for _, tab in ipairs(tabs) do
        for _, a in ipairs(controls(tab)) do
            if a.type == "binding" then commands[a.command] = true end
        end
    end
    for _, tab in ipairs(tabs) do
        for _, a in ipairs(controls(tab)) do
            if a.type == "binding" then
                -- the tabs' keys go back together, after this loop (TK.Bindings:ResetKeys)
            elseif a.resets then
                a.func(node)
            elseif resettable(node, a) then
                local d = first[a]
                if d == nil then d = defaultOf(node, a) end
                if type(d) == "table" then d = U.Copy(d) end
                if not same(argValue(node, a), d) then
                    setArg(node, a, d)
                    -- Commit changed rows while Reset owns the click. Music's options toggle (4a 0x00541120) can
                    -- draw from the shared RNG; moving that commit outside input changes what the server sees.
                    if a.commit then a.commit(node, argValue(node, a)) end
                end
                -- s6-ui-core (round 54): a style choice's small choices under it (builders.stylechoice) go back too
                for _, e in ipairs(a.extras or {}) do
                    local ed = node.defaults and (node.defaults() or {})[e.key]
                    if ed ~= nil and nodeDB(node)[e.key] ~= ed then setArg(node, { key = e.key }, ed) end
                end
            end
        end
    end
    if next(commands) then
        TK.Bindings:ResetKeys(commands) -- one group, keeping to TK.Bindings:GlobalRefusal; a global's keys follow it
        TK.DB:MarkDirty()
        TK.FireEvent("UPDATE_BINDINGS")
    end
    self:RefreshPage()
    setStatus("Reset to defaults: " .. node.title .. (#tabs == 1 and (", " .. tabs[1].name) or ""))
end

--- The page has the icon: not the player's data, and something on it has a default.
function S:CanReset(node)
    if not node or node.noReset then return false end
    for _, tab in ipairs(node.tabs or {}) do
        if tabResettable(node, tab) then return true end
    end
    return false
end

--- The icon's question: this tab, the whole page (every tab of the row), or nothing.
function S:AskReset()
    local node = self.selected
    if not self:CanReset(node) then return end
    local tab = (node.tabs or {})[self.tabIndex]
    resetAsk.node, resetAsk.tabIndex = node, self.tabIndex
    resetAsk.text:SetText("Put " .. node.title .. "'s settings back to their defaults: this tab (" .. (tab and tab.name or "")
        .. ") or every tab of the page?")
    resetAsk.tab:SetEnabled(tab ~= nil and tabResettable(node, tab))
    resetAsk:ClearAllPoints()
    resetAsk:SetPoint("CENTER", frame, "CENTER", 0, 40)
    resetAsk:Show()
end

--- The question goes with its page: when the window closes, or the page or the profile changes (Astra's review).
local function dismissReset()
    if resetAsk then resetAsk:Hide() end
end

--- s6-ui-core (round 60): whether a need of the arg whose result is result ("hide" or "disable"; TK.Needs) is unmet now.
local function needsUnmet(node, arg, result, db)
    for _, need in ipairs(arg.requires or {}) do
        if need.result == result and not need.met(db or nodeDB(node), node) then return true end
    end
    return false
end

local function argDisabled(node, arg)
    if arg.disabled ~= nil and arg.disabled(nodeDB(node), node) then return true end
    return needsUnmet(node, arg, "disable") -- s6-ui-core (round 60)
end

-- ----- s6-ui-core (round 54): what a setting needs, and its (!) -----
-- The owner (2026-10-05): a setting that has no effect because another setting is off "should remain checked but the
-- text should turn a lighter grey", with "a ! symbol that appears next to the title (not the description) ... that has
-- the tooltip on hover that lists the required settings"; "They can still toggle it on and off in this state but it
-- doesn't do anything. In that case it shows grey, but if they click it off the ! should disappear and the text should
-- return to normal colour." An arg names what it needs (requires = { TK.Needs(...), ... }); it stays usable and keeps its
-- value, and while it is on (a switch) or set (any other control) with a need unmet, its title is grey with a (!). A need
-- is TK.Needs' (core/components.lua, with the other schema helpers).

local NEEDS_GREY = { 0.62, 0.62, 0.62 }

--- The name of the setting key on the node's page (its key when no control there has it).
local function settingName(node, key)
    for _, tab in ipairs(node.tabs or {}) do
        for _, a in ipairs(controls(tab)) do
            if a.key == key and type(a.name) == "string" then return a.name end
        end
    end
    return key
end

--- s6-ui-core (round 60): a need's label, its own or (TK.NeedSetting) its setting's name on the page, with the state.
local function needLabel(node, need)
    if need.label then return need.label end
    local name = settingName(node, need.key)
    if need.state == false then return name .. " off" end
    if need.state ~= nil and need.state ~= true then return name .. ": " .. tostring(need.state) end
    return name
end

--- The needs of an arg that are not met now and grey it (the (!): every need but one that hides or disables), or nil.
local function unmetNeeds(node, arg)
    if not arg.requires then return nil end
    local db, out = nodeDB(node), nil
    for _, need in ipairs(arg.requires) do
        if (need.result or "grey") == "grey" and not need.met(db, node) then
            out = out or {}
            out[#out + 1] = needLabel(node, need)
        end
    end
    return out
end

--- A small mark after a title ("(!)", or the "?" of a description's help) whose hover shows its tooltip lines.
local function titleMark(owner, text, colour)
    local m = TK.Wrap(__tk:ShellSettingsControl("mark", owner.__h, 0)) -- s6-ui-core (round 125, piece 4b): the shell's
    m.label = TK.Wrap(__tk:ShellSettingsSub(m.__h, "label"))
    m.label:SetText(text)
    m.label:SetTextColor(colour[1], colour[2], colour[3], 1)
    m:SetSize(m.label:GetStringWidth() + 2, 16)
    m:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for _, line in ipairs(self.lines or {}) do GameTooltip:AddLine(line, 1, 1, 1) end
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
    return m
end

--- The title a page control shows its name in (a switch's label, the others' title; s6-ui-core round 60: a header's
--- label, a line of text's text).
local function titleOf(w, arg)
    if arg.type == "toggle" or arg.type == "header" then return w.label end
    if arg.type == "description" then return w.text end
    return w.title
end

local TEXT_COLOUR = { 0.85, 0.85, 0.85 } -- a line of text's (SettingsControls.TextColour)

--- A title's own colour: a switch's white, a line of text's light grey, the others' gold.
local function titleColour(arg)
    if arg.type == "toggle" then return W.white end
    if arg.type == "description" then return TEXT_COLOUR end
    return W.gold
end

--- The (!) of a control whose need is unmet while it is on, else its normal title (every refresh: the page's widgets are
--- reused by other args, so a control without needs hides its mark). s6-ui-core (round 60): a header or a line of text
--- whenever its need is unmet; a header's rule then starts after the (!).
local function showNeeds(node, w, arg, disabled)
    local title = titleOf(w, arg)
    local unmet = title and unmetNeeds(node, arg)
    if unmet and (arg.type ~= "toggle" or argValue(node, arg)) then
        title:SetTextColor(NEEDS_GREY[1], NEEDS_GREY[2], NEEDS_GREY[3], 1)
        if not w.needsMark then w.needsMark = titleMark(w, "(!)", { 1, 0.6, 0.2 }) end
        w.needsMark:ClearAllPoints()
        w.needsMark:SetPoint("LEFT", title, "LEFT", math.min(title:GetStringWidth(), w:GetWidth() - 16) + 4, 0)
        w.needsMark.lines = { "Needs: " .. table.concat(unmet, ", ") }
        w.needsMark:Show()
        if w.right then w.right:SetPoint("LEFT", w.needsMark, "RIGHT", 4, 0) end
        w.needsGreyed = true
        return
    end
    if w.needsMark then w.needsMark:Hide() end
    if w.right then w.right:SetPoint("LEFT", title, "RIGHT", 8, 0) end
    if w.needsGreyed then
        w.needsGreyed = nil
        if title and not disabled then
            local c = titleColour(arg)
            title:SetTextColor(c[1], c[2], c[3], 1)
        end
    end
end

local function resolveValues(node, arg)
    if type(arg.values) == "function" then return arg.values(node) end
    return arg.values or {}
end

local pageWidgets = {}   -- { widget, arg } for refresh
S.pageWidgets = pageWidgets -- s6-modular (round 16): the gate's named controls (gatecontrols.lua)

-- s6-ui-core (round 60; the owner, 2026-10-06: "When Enable advanced lighting is disable hide all the options that require
-- it. Clicking it shows the options."): an arg is left off the page while its hidden(db, node) says so or a need of it
-- that hides (a master switch's, TK.Needs' result "hide") is unmet; its other needs grey or disable it. The page's args
-- that could come or go, with whether each was hidden when it was laid out, so a change lays the page out again at once.
local pageHides = {}   -- { arg, hidden }

local function argHidden(node, arg, db)
    if arg.hidden and arg.hidden(db, node) then return true end
    return needsUnmet(node, arg, "hide", db)
end

-- s6-ui-core (round 125, piece 4a of the Global Interface's plan): the plain controls are the shell's
-- (Runtime/Shell/SettingsControls.cs). A builder takes one from its pool, wraps its parts under the names the page code
-- and the tests use, and sets w.ops: what the player's input on it does. The shell calls an op inside the input's own
-- dispatch (the click, Enter), where the Lua control called its function.
local function shellControl(kind, width, parent)
    return TK.Wrap(__tk:ShellSettingsControl(kind, (parent or pageContent).__h, width or 0))
end
local function sub(w, name) return TK.Wrap(__tk:ShellSettingsSub(w.__h, name)) end

TK.ShellCalls["settings.op"] = function(id, op, value)
    local w = TK.Wrap(tonumber(id))
    local f = w and w.ops and w.ops[op]
    if f then f(value) end
end

--- s6-ui-core (round 125, piece 4b): a tab of the window's bars (make.Tab's look, the shell's): SetSelected draws it as
--- the chosen one; its click runs b.ops.run. name: its global name (the gate's TKSettingsTab:<category>).
local function newTab(bar, name, size)
    local b = TK.WrapShellButton(__tk:ShellSettingsTab(bar.__h, name or "", size))
    if name then _G[name] = b end
    function b:SetSelected(on)
        self.selected = on and true or false
        __tk:ShellSettingsSelected(self.__h, self.selected)
    end
    return b
end

-- s6-ui-core (round 172, U-64 step 4 parts b and c): the plain kinds (a header, a switch, a button, a line of text, a
-- drop-down, a text field, a one-of, a style choice) are built, filled and drawn by the shell
-- (Runtime/Shell/SettingsWindow.PageControls.cs); this side gives their data ("settings.data", "settings.values",
-- "settings.entries"), keeps their views (shellView) and sets their options ("settings.set", "settings.run"). builders
-- has the kinds still drawn here.
local PLAIN = { header = true, toggle = true, execute = true, description = true, select = true, input = true,
    oneof = true, stylechoice = true }

local builders = {}

--- The Lua view of a plain control the shell built (TK.Wrap of its frame: TK.Settings:Widget's, pageWidgets'), with its
--- parts under the names the page code and the tests use. A frame is always one kind (the shell pools them by kind), so
--- its parts and hooks are set once.
local function shellView(kind, h)
    if kind == "execute" then return TK.WrapShellButton(h) end
    local w = TK.Wrap(h)
    if w.viewKind then return w end
    w.viewKind = kind
    if kind == "header" then
        w.label, w.right = sub(w, "label"), sub(w, "right")
    elseif kind == "toggle" then
        w.label, w.box = sub(w, "label"), sub(w, "box")
        -- WIRE (s6-ui-core): a box that stands for one of a dialog's controls (the music dialog's effects radio, 4a's
        -- MusicControlDialog 0x00528E60) hands its press and release to that dialog (arg.pointer), as the original's
        -- control took them; changing when they are handed on changes what the server sees.
        w:HookScript("OnMouseDown", function(_, button) if w.pointer then w.pointer(true, button, w) end end)
        w:HookScript("OnMouseUp", function(_, button) if w.pointer then w.pointer(false, button, w) end end)
    elseif kind == "description" then
        w.text = sub(w, "text")
    elseif kind == "select" then
        w.title, w.button, w.text, w.list = sub(w, "title"), sub(w, "button"), sub(w, "text"), sub(w, "list")
        -- the list's entries, as make.Dropdown's list.items (the shell makes them as the list first needs them)
        w.list.items = setmetatable({}, { __index = function(_, k)
            local item = type(k) == "number" and __tk:ShellSettingsSub(w.__h, "item" .. k)
            return item and item > 0 and TK.Wrap(item) or nil -- nil past the last (ipairs stops)
        end })
        function w:GetValue() return self.current end -- the value shown (the last refresh's)
    elseif kind == "oneof" then
        w.title = sub(w, "title")
        function w:GetValue() return self.value end -- the chosen one's (the last refresh's, or the click's)
    elseif kind == "stylechoice" then
        w.main = shellView("select", __tk:ShellSettingsSub(h, "main"))
        w.title = w.main.title -- the page's title (S:Widget's callers)
    else -- input
        w.title, w.box = sub(w, "title"), sub(w, "box")
    end
    return w
end

-- s6-ui-core (round 60): every range is the one slider (W.Slider); one with handles has a value a handle, each set as an
-- arg of its own (a handle moved pushes others: each that changed), and its handles' check boxes their own keys.
-- s6-ui-core (round 62; the head's note view-distance-row): a check box's tooltip is its arg's desc; the arg's
-- togglesBeside puts the boxes right of the track, and its stop may have onlyWithout (the slider's options, W.Slider).
function builders.range(node, arg, width)
    local s = acquire("range", function() return W.Slider(pageContent, "", 0, 1, 0, width) end)
    s:SetWidth(width)
    local opts, set = { gap = arg.gap, stop = arg.stop, togglesBeside = arg.togglesBeside,
        onCommit = arg.commit and function(...) arg.commit(node, ...) end or nil,
        sections = type(arg.sections) == "function" and arg.sections(node) or arg.sections }, function(v) setArg(node, arg, v) end
    if arg.handles then
        opts.handles = {}
        for i, h in ipairs(arg.handles) do
            opts.handles[i] = { relative = h.relative, toggle = h.toggle and h.toggle.name, toggleTip = h.toggle and h.toggle.desc }
        end
        opts.onToggle = function(i, on) setArg(node, arg.handles[i].toggle, on) end
        set = function(...)
            for i, h in ipairs(arg.handles) do
                local v = select(i, ...)
                if argValue(node, h) ~= v then setArg(node, h, v) end
            end
        end
    end
    local min, max = S.RangeEnds(node, arg) -- s6-ui-core (round 149): read as the page shows
    s:Configure(arg.name, min, max, arg.step, set, opts)
    return s, s:GetHeight() + 16
end

-- s6-effects (round 11; a marked addition to s6-ui-core's settings, FOR-s6-ui-core-r11.md): a range with two handles,
-- its value a pair { low, high } under one key. s6-ui-core (round 60): the one slider's two-handle use.
function builders.dualrange(node, arg, width)
    local s = acquire("range", function() return W.Slider(pageContent, "", 0, 1, 0, width) end)
    s:SetWidth(width)
    s:Configure(arg.name, arg.min, arg.max, arg.step, function(low, high) setArg(node, arg, { low, high }) end,
        { handles = { {}, {} } })
    return s, 66
end

--- The values a slider shows (one a handle; the widget takes a number, or the stop's value).
local function rangeValues(node, arg)
    if arg.type == "dualrange" then -- s6-effects (round 11): a pair { low, high }
        local v = argValue(node, arg)
        return type(v) == "table" and tonumber(v[1]) or arg.min, type(v) == "table" and tonumber(v[2]) or arg.max
    end
    if not arg.handles then return argValue(node, arg) end
    local out = {}
    for i, h in ipairs(arg.handles) do out[i] = argValue(node, h) end
    return table.unpack(out, 1, #arg.handles)
end

-- ----- s6-ui-settings: the ordered list of switches (the owner, 2026-10-02) -----

local ROW_H = 24
local chosenRow   -- { list, index } of the row last clicked: the Up and Down keys move it while the window is open

local function moveEntry(list, from, to)
    local copy = U.Copy(list)
    table.insert(copy, to, table.remove(copy, from))
    return copy
end

local function orderRow(f, i)
    local row = shellControl("orderrow", 0, f) -- s6-ui-core (round 125, piece 4b): the shell's row and switch
    row:SetHeight(ROW_H - 2)
    row.sel, row.icon, row.text, row.grip = sub(row, "sel"), sub(row, "icon"), sub(row, "text"), sub(row, "grip")
    row.box = sub(row, "box")
    row.box.ops = { set = function(on) if row.box.onChange then row.box.onChange(on) end end }
    -- A press on the row (not its box) chooses it and starts a drag; the release puts it where the pointer is.
    row:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        chosenRow = { f = f, index = i, node = f.node }
        f.dragFrom = i
        f:Fill(f.node, f.arg)
    end)
    row:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not f.dragFrom then return end
        local to = f:IndexAtPointer()
        local from = f.dragFrom
        f.dragFrom = nil
        f.line:Hide()
        if to ~= from then f:Move(from, to) end
    end)
    f.rows[i] = row
    return row
end

function builders.orderlist(node, arg, width)
    local f = acquire("orderlist", function()
        local f = shellControl("orderlist")
        f.rows = {}
        f.line = sub(f, "line")   -- where a dragged row would go
        --- The row under the pointer (1 to the list's length).
        function f:IndexAtPointer()
            local _, b, _, h = U.RootRect(self)
            local _, cy = GetCursorPosition()
            local i = math.floor((b + h - cy / TK.UIScale()) / ROW_H) + 1
            return math.max(1, math.min(#self.list, i))
        end
        function f:Move(from, to)
            if chosenRow and chosenRow.f == self then chosenRow.index = to end
            setArg(self.node, self.arg, moveEntry(self.list, from, to))
        end
        function f:Fill(node, arg)
            self.node, self.arg = node, arg
            self.list = argValue(node, arg) or {}
            local items = arg.items(node)
            self:SetHeight(#self.list * ROW_H + 4)
            for i, entry in ipairs(self.list) do
                local row = self.rows[i] or orderRow(self, i)
                local item = items[entry.id] or { text = entry.id }
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -2 - (i - 1) * ROW_H)
                row:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -2 - (i - 1) * ROW_H)
                row.text:SetText(item.text)
                row.icon:SetTexture(item.icon or "tk:white")
                local c = item.coords or { 0, 1, 0, 1 }
                row.icon:SetTexCoord(c[1], c[2], c[3], c[4])
                row.box:SetChecked(entry.on and true or false)
                row.box.onChange = function(on)
                    local copy = U.Copy(self.list)
                    copy[i].on = on and true or false
                    setArg(self.node, self.arg, copy)
                end
                row.sel:SetShown(chosenRow ~= nil and chosenRow.f == self and chosenRow.index == i)
                row:Show()
            end
            for i = #self.list + 1, #self.rows do self.rows[i]:Hide() end
        end
        f:SetScript("OnUpdate", function(self)
            if not self.dragFrom then return end
            local to = self:IndexAtPointer()
            self.line:ClearAllPoints()
            local y = -2 - (to - 1) * ROW_H + (to > self.dragFrom and -ROW_H + 1 or 1)
            self.line:SetPoint("TOPLEFT", self, "TOPLEFT", 0, y)
            self.line:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, y)
            self.line:SetShown(to ~= self.dragFrom)
        end)
        return f
    end)
    f:SetWidth(width)
    if chosenRow and chosenRow.f == f and chosenRow.node ~= node then chosenRow = nil end
    f:Fill(node, arg)
    return f, #f.list * ROW_H + 12
end

--- The Up and Down keys move the list's chosen row while the window shows it (shared/bindings.lua asks, after a dialog that
--- has the keys).
TK.SettingsKeyHook = function(key)
    if not (chosenRow and chosenRow.f:IsVisible() and frame and frame:IsShown()) then return false end
    local f, i = chosenRow.f, chosenRow.index
    local to = key == "UP" and i - 1 or key == "DOWN" and i + 1 or nil
    if not to then return false end
    if to >= 1 and to <= #f.list then f:Move(i, to) end
    return true
end

local listKeys   -- the settings key layer holds Up and Down

--- Live, Lua hears a key only when a key layer routes it (Astra's review): while the window shows a chosen row, the
--- settings layer takes Up and Down, ahead of Classic's walk on the arrows. The rules' capture, a modal pane or the
--- input blocker still keeps them, as for any bound key (InputHost.GameKey).
local function syncListKeys()
    local on = chosenRow ~= nil and frame ~= nil and frame:IsShown() and chosenRow.f:IsVisible()
    if on == (listKeys or false) then return end
    listKeys = on
    TK.Actions:SetKeyLayer("settings", on and { UP = false, DOWN = false } or {})
end

-- ----- s6-ui-core (round 44): a list of names (the owner, 2026-10-03: "an editable list of buff and debuff names") -----

local NAME_ROW = 26
local refocus      -- { node, key }: the list whose add box keeps the keyboard once the page is laid out again

local function trimmed(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function hasName(list, name, except)
    for i, n in ipairs(list) do
        if i ~= except and n:lower() == name:lower() then return true end
    end
    return false
end

local function nameRow(f, i)
    local row = shellControl("namerow", 0, f) -- s6-ui-core (round 125, piece 4b): the shell's field and Remove
    row:SetHeight(NAME_ROW - 4)
    row.box, row.remove = sub(row, "box"), sub(row, "remove")
    f.rows[i] = row
    return row
end

function builders.namelist(node, arg, width)
    local f = acquire("namelist", function()
        local f = shellControl("namelist")
        f.rows = {}
        f.title, f.none, f.add, f.addButton = sub(f, "title"), sub(f, "none"), sub(f, "add"), sub(f, "addButton")
        --- A copy of the list, changed by fn, set as the value (never the stored table itself: a default may be shared).
        function f:Change(fn)
            local copy = U.Copy(self.list)
            fn(copy)
            setArg(self.node, self.arg, copy)
        end
        function f:AddName()
            local name = trimmed(self.add:GetText())
            self.add:SetText("")
            if name == "" or hasName(self.list, name) then return end
            refocus = { node = self.node, key = self.arg.key }
            self:Change(function(l) l[#l + 1] = name end)
        end
        f.ops = { enter = function() f:AddName() end, add = function() f:AddName() end }
        function f:Fill(node, arg)
            self.node, self.arg = node, arg
            self.list = argValue(node, arg) or {}
            local w = self:GetWidth()
            for i, name in ipairs(self.list) do
                local row = self.rows[i] or nameRow(self, i)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -20 - (i - 1) * NAME_ROW)
                row:SetWidth(w)
                row.box:SetWidth(w - 90)
                if not row.box:HasFocus() then row.box:SetText(name) end
                -- Edited in place: Enter or leaving the box keeps it; emptied, it goes. Against the list as it is now, so
                -- Enter and the focus leaving after it change it once.
                local function commit()
                    local current = self.list[i]
                    local text = trimmed(row.box:GetText())
                    if current == nil or text == current then return end
                    if text == "" then
                        self:Change(function(l) table.remove(l, i) end)
                    elseif not hasName(self.list, text, i) then
                        self:Change(function(l) l[i] = text end)
                    else
                        row.box:SetText(current)
                    end
                end
                row.ops = {
                    enter = function() row.box:ClearFocus() commit() end,
                    blur = commit,
                    remove = function() self:Change(function(l) table.remove(l, i) end) end,
                }
                row:Show()
            end
            for i = #self.list + 1, #self.rows do self.rows[i]:Hide() end
            self.count = #self.list
            local y = -20 - #self.list * NAME_ROW
            self.none:ClearAllPoints()
            self.none:SetPoint("TOPLEFT", self, "TOPLEFT", 0, y)
            self.none:SetShown(#self.list == 0)
            if #self.list == 0 then y = y - 20 end
            self.add:ClearAllPoints()
            self.add:SetPoint("TOPLEFT", self, "TOPLEFT", 0, y)
            self.add:SetWidth(w - 90)
            self.addButton:ClearAllPoints()
            self.addButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, y)
            self:SetHeight(-y + 26)
        end
        return f
    end)
    f:SetWidth(width)
    f.title:SetText(arg.name)
    f:Fill(node, arg)
    if refocus and refocus.node == node and refocus.key == arg.key then
        refocus = nil
        f.add:SetFocus()
    end
    return f, f:GetHeight() + 8
end

--- Shows a slot's binding on its button, or, as WoW's Key Bindings frame, "Not Bound" in gold, dimmed (s6-ui-bars). keys is
--- the command's keys in B:Keys's order (s6-optimize round 9: the page takes every command's in one pass, B:KeysByCommand).
local function showSlot(b, keys, slot)
    local key = keys and keys[slot]
    b:SetText(key and TK.Bindings.KeyText(key) or TK.Bindings.NOT_BOUND)
    if key then b:SetNormalFontColor(1, 1, 1, 1) else b:SetNormalFontColor(1, 0.82, 0, 0.8) end
end

--- What a slot's capture ends with: the status line says what WoW's frame says, and the page shows the keys again.
local function bindingDone(binding, was, unbound, refused)
    if refused then
        setStatus(refused, true) -- the owner's hotfix (2026-10-06): another interface's global key
    elseif not binding then
        setStatus("")
    else
        setStatus(TK.Bindings:BindingResult(was, unbound))
    end
    S:RefreshPage()
end

local bindingRowsMade = 0

--- s6-optimize (round 10): the binding rows live in one frame of their own, in the page while it shows binding rows and
--- hidden on UIParent, out of the window, otherwise. Unity walks every canvas renderer under each canvas it turns on or
--- off, hidden ones too, so the window's opening and closing paid for the page's 129 pooled rows (about 1,400 renderers,
--- five canvases deep) whether the page showed them or not: the window's Show and Hide took about 7-9 ms more each on
--- the VM (notes.md, round 10). Moving the frame costs about 5 ms, once on entering such a page and once on leaving it.
local bindingRowsInPage = false
local function placeBindingRows(inPage)
    if bindingRowsInPage == inPage then return end
    bindingRowsInPage = inPage
    bindingRows:SetParent(inPage and pageContent or UIParent)
    bindingRows:SetShown(inPage)
end

--- A binding row (head note 37): the command and its two slots, the primary and the secondary key (s6-ui-bars, as WoW's).
--- A click on a slot captures the next key (with its modifiers), chord (a key pressed while another is held), or a mouse
--- button or wheel turn on the slot itself; Escape clears the slot (WoW's Unbind Key). The status line says what WoW's
--- frame says: "Press Key to Bind to Command -> <command>", then "Key Bound Successfully", or in red "<command> Function
--- is Now Unbound!" when the key was another command's only one; a cleared slot empties it. s6-input (the owner's
--- hotfix, 2026-10-06: "The default should never be fucking changed however"): the second press of a double click on a
--- slot is not a binding. The first click starts the capture, so a double click used to bind the left button there,
--- taking it from Map: Select and Act behind the player's back. The slot keeps waiting. A single press of a mouse button
--- on the waiting slot still binds it, the left and right buttons too (plan D24: "YOU CAN ... REBIND IT IF YOU WANT").
--- s6-optimize (round 9): made once, with its handlers, which read the command the page last gave the row (f.arg); a
--- page's build sets the label, and its refresh the slots.
local function makeBindingRow()
    -- s6-ui-core (round 125, piece 4b): the shell draws the row (SettingsControls.BindingRow); its slots' scripts stay here
    local f = shellControl("bindingrow", 0, bindingRows)
    f.label = sub(f, "label")
    f.keys = {}
    -- The owner's hotfix (2026-10-06): "a checkbox to the right of all keybinds", Global (its heading over the column,
    -- not by each one): the command keeps these keys in every interface (TK.Bindings:SetGlobal).
    f.global = sub(f, "global")
    f.ops = { global = function(on)
        TK.Bindings:SetGlobal(f.arg.command, on, function() S:RefreshPage() end)
        S:RefreshPage()
    end }
    f.global:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Global: the same keys in every interface.", 1, 1, 1)
        GameTooltip:Show()
    end)
    f.global:HookScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
    for slot = 1, 2 do
        local b = TK.WrapShellButton(__tk:ShellSettingsSub(f.__h, "key" .. slot))
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")
        local function capturing()
            local c = TK.KeyBindMode.capture
            return c and c.command == f.arg.command and c.slot == slot
        end
        b:SetScript("OnClick", function(self, button)
            -- Review r18 finding 2: the release of the press that completed a mouse capture starts nothing.
            if self.captured == button then
                self.captured = nil
                return
            end
            if capturing() then return end
            if button ~= "LeftButton" then return end
            self:SetText("Press a key...")
            self:SetNormalFontColor(1, 1, 1, 1)
            setStatus(string.format(TK.Bindings.BIND_KEY_TO_COMMAND, f.arg.name))
            TK.KeyBindMode:Capture(f.arg.command, f.arg.name, bindingDone, slot)
        end)
        -- While this slot captures, a mouse button or the wheel over it is the binding; not a double click's second press
        -- (the owner's hotfix above), which leaves the slot waiting.
        b:SetScript("OnMouseDown", function(self, button, double)
            self.captured = nil
            if capturing() and not double and TK.KeyBindMode:CaptureMouse(button) then self.captured = button end
        end)
        b:SetScript("OnMouseWheel", function(_, delta) if capturing() then TK.KeyBindMode:CaptureWheel(delta) end end)
        -- s6-ui-core (round 54; the owner: the page's paragraphs go, a short tooltip where a player needs one)
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Click, then press a key, a chord or a mouse button.", 1, 1, 1)
            GameTooltip:AddLine("Escape clears it.", 1, 1, 1)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
        f.keys[slot] = b
    end
    f.key = f.keys[1]
    bindingRowsMade = bindingRowsMade + 1
    return f
end

function builders.binding(node, arg, width)
    placeBindingRows(true)
    local f = acquire("binding", makeBindingRow)
    f.arg = arg
    f:SetWidth(width)
    -- s6-interface-5x (round 13, a marked edit; the separation's step 11): a command inert while its panel is off is
    -- greyed, "(off: <panel>)", its keys shown and still editable (5.18); every build sets the colour (the rows are reused)
    f.label:SetText(arg.off and (arg.name .. " (off: " .. arg.off .. ")") or arg.name)
    local c = arg.off and NEEDS_GREY or W.white
    f.label:SetTextColor(c[1], c[2], c[3], 1)
    return f, 28 -- its slots are shown by the page's refresh, which ends every build
end

--- s6-optimize (round 9; the decision docs/user-related/decisions/2026-10-03-windows-built-at-world-load.md): the Key
--- Bindings page's rows made ahead, hidden, into the pool its build takes them from, as many as its largest tab lists,
--- so its first selection costs close to what a later one does (core/gamestate.lua calls it while the world loads; other
--- first-use costs remain). It builds no page and selects nothing: no remembered row moves and no page's request goes.
function S:BuildBindingRows()
    if not bindingRows then return end
    local most = 0
    for _, tab in ipairs(TK.KeyBindingTabs()) do
        local n = 0
        for _, arg in ipairs(tab.args or {}) do
            if arg.type == "binding" then n = n + 1 end
        end
        most = math.max(most, n)
    end
    while bindingRowsMade < most do
        local f = makeBindingRow()
        f:Hide()
        table.insert(pools.binding, f)
    end
end

--- The binding rows' column headings, as WoW's Key Bindings frame has them (s6-ui-bars): Command, Key 1, Key 2.
function builders.bindingHeading(node, arg, width)
    local f = acquire("bindingHeading", function()
        -- s6-ui-core (round 125, piece 4b): the shell's (SettingsControls.BindingHeading); the owner's hotfix
        -- (2026-10-06) added the Global column
        local f = shellControl("bindingheading")
        f.command, f.key1, f.key2, f.global = sub(f, "command"), sub(f, "key1"), sub(f, "key2"), sub(f, "global")
        return f
    end)
    f:SetWidth(width)
    return f, 22
end

--- Updates every widget's value and enabled state from the db (after any change). s6-ui-core (round 172, U-64 step 4
--- part b): the shell's (SettingsWindow.RefreshPage): it draws the plain controls' values and greys from
--- "settings.values", then asks "settings.marks" for the (!) marks and the controls drawn here.
function S:RefreshPage() __tk:ShellSettingsRefreshPage() end

-- "settings.values"' separators (SettingsWindow.RefreshPage splits them)
local RECORD, FIELD = "\30", "\31"

--- The text a drop-down shows for the value v: its entry's, else the value (make.Dropdown's SetValue).
local function shownText(values, v)
    for _, x in ipairs(values) do
        if x.value == v then return x.text end
    end
    return tostring(v)
end

--- The plain controls' state for the shell to draw, one record a control (SettingsWindow.RefreshPage reads them): its
--- row, "1" when disabled (kept for "settings.marks"), then a switch's "1" when on; a line's text when its name is a
--- function; a drop-down's text shown; a one-of's chosen button's number; a style choice's drop-downs' texts. A
--- drop-down's entries are kept on its view for its list ("settings.entries") and its pick ("settings.set").
TK.ShellCalls["settings.values"] = function()
    local node = S.selected
    if not node then return nil end
    local out = {}
    for _, pw in ipairs(pageWidgets) do
        local w, arg = pw[1], pw[2]
        if PLAIN[arg.type] then
            local disabled = argDisabled(node, arg)
            pw[4] = disabled
            local rec = pw[3] .. FIELD .. (disabled and "1" or "")
            if arg.type == "toggle" then
                rec = rec .. FIELD .. (argValue(node, arg) and "1" or "")
            elseif arg.type == "description" then
                if type(arg.name) == "function" then rec = rec .. FIELD .. tostring(arg.name(node)) end
            elseif arg.type == "select" then
                w.values, w.current = resolveValues(node, arg), argValue(node, arg)
                rec = rec .. FIELD .. shownText(w.values, w.current)
            elseif arg.type == "oneof" then
                -- a value not among the choices shows the first (make.OneOf's SetValue)
                local values, v = w.values, argValue(node, arg)
                local chosen = #values > 0 and 1 or 0
                for i, x in ipairs(values) do
                    if x.value == v then chosen = i break end
                end
                w.value = values[chosen] and values[chosen].value
                rec = rec .. FIELD .. chosen
            elseif arg.type == "stylechoice" then
                local m, db = w.main, nodeDB(node)
                m.values, m.current = resolveValues(node, arg), argValue(node, arg)
                rec = rec .. FIELD .. shownText(m.values, m.current)
                for i, e in ipairs(arg.extras or {}) do
                    local d = w.extras[i]
                    d.current = db[e.key]
                    rec = rec .. FIELD .. shownText(e.values, d.current)
                end
            end
            out[#out + 1] = rec
        end
    end
    return table.concat(out, RECORD)
end

--- After the shell drew the plain controls' values: their (!) marks (s6-ui-core round 54: a title greyed by an unmet
--- need goes over the colour the values gave it), the controls drawn here, and whether the page is laid out again (a
--- row comes or goes, a list's rows changed): true, and the shell lays it out where it was scrolled to.
TK.ShellCalls["settings.marks"] = function()
    local node = S.selected
    if not node then return false end
    local relayout = false -- s6-ui-core (round 44): a name list's rows changed
    local keys -- every command's keys, taken once for the page's binding rows (s6-optimize round 9)
    for _, pw in ipairs(pageWidgets) do
        local w, arg = pw[1], pw[2]
        local disabled = pw[4] -- a plain control's, worked out for "settings.values"
        if not PLAIN[arg.type] then disabled = argDisabled(node, arg) end
        if PLAIN[arg.type] then -- drawn by the shell: only its (!) here (a button and a style choice have none)
            if arg.type ~= "execute" and arg.type ~= "stylechoice" then showNeeds(node, w, arg, disabled) end
            if arg.type == "oneof" then
                w:SetAlpha((w.needsGreyed or disabled) and 0.62 or 1) -- by an unmet need (make.OneOf's SetGreyed)
            elseif arg.type == "stylechoice" and (argValue(node, arg) == arg.extrasWhen) ~= w.open then
                relayout = true -- s6-ui-core (round 54): its small choices shown or hidden: the page laid out again
            end
        elseif arg.type == "range" or arg.type == "dualrange" then -- s6-ui-core (round 60): the one slider
            -- the handles shown first (round 62: a stop that goes with a handle off places the values)
            for i, h in ipairs(arg.handles or {}) do
                if h.toggle then w:SetHandleShown(i, argValue(node, h.toggle) and true or false) end
            end
            w:SetValue(rangeValues(node, arg))
            w:SetEnabled(not disabled)
            showNeeds(node, w, arg, disabled)
        elseif arg.type == "binding" and not TK.KeyBindMode.capture then
            keys = keys or TK.Bindings:KeysByCommand()
            for slot, b in ipairs(w.keys) do showSlot(b, keys[arg.command], slot) end
            w.global:SetChecked(TK.Bindings:IsGlobal(arg.command)) -- the owner's hotfix (2026-10-06)
        elseif arg.type == "orderlist" then
            w:Fill(node, arg)
        elseif arg.type == "namelist" then
            -- s6-ui-core (round 44): rows added or taken away change the page's layout: it is built again.
            if #(argValue(node, arg) or {}) ~= w.count then relayout = true else w:Fill(node, arg) end
            showNeeds(node, w, arg, disabled) -- s6-ui-core (round 60): its title's (!)
        end
    end
    -- s6-ui-core (round 60): a row to show or hide now (a master switch turned): the page laid out again, where it was
    local db = nodeDB(node)
    for _, h in ipairs(pageHides) do
        if argHidden(node, h[1], db) ~= h[2] then relayout = true break end
    end
    if relayout then return true end
    -- Lock and Button Lock as they are (the shell's: SettingsWindow.ShowLocks greys Lock out of the world, where edit
    -- mode cannot run; the Key Bindings list is there at the login too)
    __tk:ShellSettingsLocks(TK.DB:Global().buttonLock == true)
    return false
end

--- s6-library round 18 (the owner: an explanation a player needs goes "in a hover tooltip, not on the page"): an
--- option's desc shows as its control's tooltip (W.Tip: s6-ui-core round 57; a pooled control's is cleared by nil).
local optionTip = W.Tip

--- keepScroll (s6-ui-core, round 44): the same page laid out again, where it was scrolled to (a name list's rows changed).
--- s6-ui-core (round 172, U-64 step 4 part a): the shell lays the page out (Runtime/Shell/SettingsWindow.Page.cs): its
--- columns, rows, indents and height; this side lists the tab's rows ("settings.layout") and builds each control the
--- shell asks for ("settings.build"), then refreshes the page as before.
function S:BuildPage(keepScroll) __tk:ShellSettingsBuildPage(keepScroll == true) end

local layoutRows = {}   -- the controls listed for the shell's layout, by their number in its list ("settings.build")
local rowViews = {}     -- the plain controls' views, by the same number ("settings.view")
local rowChoices = {}   -- a one-of's choices, by the same number, worked out as it is built ("settings.data")

--- The shown tab's rows for the shell's layout, one line each (SettingsWindow.Page.cs reads them): the groups
--- opened (s6-ui-core round 60: each grouped row as its view), a row left out while it is hidden or of a type the page
--- does not draw. A row that could come or go is noted with whether it was hidden (pageHides), so RefreshPage lays the
--- page out again when that changes. The page being replaced goes first: its widgets back to their pools, and a key
--- box waiting for a key (review R2.3).
TK.ShellCalls["settings.layout"] = function()
    TK.KeyBindMode:CancelCapture()
    releaseAll()
    U.Wipe(pageWidgets)
    U.Wipe(pageHides)
    U.Wipe(layoutRows)
    U.Wipe(rowViews)
    U.Wipe(rowChoices)
    local node = S.selected
    local tabs = node and node.tabs or {}
    local tab = tabs[S.tabIndex] or tabs[1]
    if not tab then return nil end
    local out = {}
    local function listed(a, db)
        local hidden = argHidden(node, a, db)
        if a.hidden or a.requires then pageHides[#pageHides + 1] = { a, hidden } end
        if hidden or not (builders[a.type] or PLAIN[a.type]) then return nil end
        layoutRows[#layoutRows + 1] = a
        return #layoutRows
    end
    walk(tab.args, function(arg)
        local db = nodeDB(node)
        if arg.type == "break" then
            out[#out + 1] = "break"
        elseif arg.type == "row" then
            -- s6-interface-5x (round 12): controls side by side on one row, each its rowWidth wide, else a column's
            out[#out + 1] = "row\t" .. (arg.indent or 0)
            for _, a in ipairs(arg.args) do
                local i = listed(a, db)
                if i then out[#out + 1] = "in\t" .. i .. "\t" .. a.type .. "\t" .. (a.rowWidth or "") end
            end
            out[#out + 1] = "end"
        else
            -- s6-ui-core (round 60): an indented control (indent given) is on a row of its own, its steps in
            local i = listed(arg, db)
            if i then
                out[#out + 1] = "item\t" .. i .. "\t" .. arg.type .. "\t" .. (arg.indent or "") .. "\t"
                    .. (arg.width == "full" and "1" or "")
            end
        end
    end)
    return table.concat(out, "\n")
end

--- Builds the listed control i, width wide, for the shell to place: its frame, its height on the page and its width.
--- s6-library round 18: an option's desc is its control's tooltip; s6-ui-core (round 52; Astra's review): an input's
--- box takes the pointer, not its frame (a hover does not reach the parent), so the box carries the tip, in a row too.
TK.ShellCalls["settings.build"] = function(i, width)
    local a = layoutRows[tonumber(i)]
    local w, h = builders[a.type](S.selected, a, width)
    optionTip(a.type == "input" and w.box or w, a.desc)
    pageWidgets[#pageWidgets + 1] = { w, a }
    return w.__h, h, w:GetWidth()
end

--- A plain control's data for the shell to build it (SettingsWindow.BuildPlain): its name (worked out when it is a
--- function), and a live field's flag and text (a form's field keeps its text: Tab moves on, a button takes them all);
--- a style choice's: whether its small choices show (s6-ui-core round 54: while its value is arg.extrasWhen) and how
--- many there are. A one-of's choices are worked out here, once for its building (its buttons' texts, tooltips).
TK.ShellCalls["settings.data"] = function(i)
    local n = tonumber(i)
    local a, node = layoutRows[n], S.selected
    local name = a.name
    if type(name) == "function" then name = name(node) end
    name = name ~= nil and tostring(name) or ""
    if a.type == "input" and a.live then return name, true, a.get and tostring(a.get(node) or "") or "" end
    if a.type == "oneof" then
        rowChoices[n] = resolveValues(node, a)
    elseif a.type == "stylechoice" then
        return name, argValue(node, a) == a.extrasWhen, #(a.extras or {})
    end
    return name
end

--- A control's entries for the shell (SettingsWindow.Entries): a drop-down's as its list opens, a style choice's small
--- choice's as it is built (its width) and opened, a one-of's choices as it is built. The current one's number (0:
--- none), then each entry's text; a one-of's each followed by whether it is disabled. part: a style choice's small
--- choice (arg.extras), 0 its main drop-down.
TK.ShellCalls["settings.entries"] = function(i, part)
    local n, p = tonumber(i), tonumber(part) or 0
    local a, w, node = layoutRows[n], rowViews[n], S.selected
    local oneOf, values, v = a.type == "oneof"
    if oneOf then
        values, v = rowChoices[n] or {}, argValue(node, a)
    elseif a.type == "stylechoice" and p > 0 then
        local e = a.extras[p]
        values, v = e.values, nodeDB(node)[e.key]
    else -- the last refresh's (settings.values), as the pick reads them
        local d = a.type == "stylechoice" and w.main or w
        values, v = d.values or {}, d.current
    end
    local current, out = 0, {}
    for k, x in ipairs(values) do
        if current == 0 and x.value == v then current = k end
        out[#out + 1] = x.text
        if oneOf then out[#out + 1] = x.disabled == true end
    end
    return current, table.unpack(out)
end

--- The shell built the plain control i (its frame h): its view kept for the refresh and TK.Settings:Widget, its
--- tooltip, and what goes with its kind: a switch's dialog control and action, a drop-down's set by value (the tests'
--- onChange), a line's "?".
TK.ShellCalls["settings.view"] = function(i, h)
    local n = tonumber(i)
    local a, node = layoutRows[n], S.selected
    local w = shellView(a.type, h)
    if a.type == "toggle" then
        w.pointer = a.pointer
        -- An option the original also sends (arg.action, an action kind) is attached to the box, and a change in the
        -- world runs it (plan 5.9). WIRE: the action runs inside the click's dispatch (the shell's "set", through
        -- "settings.set"), as it did; moving it changes when the server sees it.
        TK.Actions:SetTable(w, a.action and { kind = a.action } or nil)
        w.onChange = function(on)
            setArg(node, a, on)
            if a.action and TK.GameState:InWorld() then TK.Actions:RunFrozen() end
        end
    elseif a.type == "select" then
        w.onChange = function(v) setArg(node, a, v) end
    elseif a.type == "oneof" then
        -- its buttons (the shell's, one a choice), each with its choice's tooltip
        w.values, w.buttons = rowChoices[n], {}
        for k, choice in ipairs(w.values) do
            local b = TK.WrapShellButton(__tk:ShellSettingsSub(h, "button" .. k))
            W.Tip(b, choice.desc)
            w.buttons[k] = b
        end
    elseif a.type == "stylechoice" then
        -- its drop-downs (the shell's): the main one sets the option, each small choice its own key (arg.extras)
        w.main.onChange = function(v) setArg(node, a, v) end
        w.extras = {}
        for k, e in ipairs(a.extras or {}) do
            local d = shellView("select", __tk:ShellSettingsSub(h, "extra" .. k))
            d.values = e.values
            d.onChange = function(v) setArg(node, { key = e.key }, v) end
            w.extras[k] = d
        end
        w.open = argValue(node, a) == a.extrasWhen -- as the shell built it ("settings.data"; "settings.marks")
    elseif a.type == "description" then
        -- s6-ui-core (round 54; the owner: a line "ends with a ? that shows a short tooltip on hover"): a one-line help
        if a.help then
            if not w.help then w.help = titleMark(w, "?", W.gold) end
            w.help:ClearAllPoints()
            w.help:SetPoint("TOPLEFT", w, "TOPLEFT", math.min(w.text:GetStringWidth(), w:GetWidth() - 16) + 6, 1)
            w.help.lines = { a.help }
            w.help:Show()
        elseif w.help then
            w.help:Hide()
        end
    end
    optionTip(a.type == "input" and w.box or w, a.desc)
    rowViews[n] = w
    pageWidgets[#pageWidgets + 1] = { w, a, i }
end

--- The player's input on the plain control i, from the shell (SettingsWindow.PageInput), inside the input's own
--- dispatch: a switch's new state, a drop-down's pick (the entry's number in its list, "settings.entries"; part: a
--- style choice's small choice, 0 its main one), a one-of's choice's number, a field's text. WIRE: a switch's runs its
--- frozen action here (its onChange, "settings.view"), inside the click, as before.
TK.ShellCalls["settings.set"] = function(i, value, part)
    local n = tonumber(i)
    local a, w = layoutRows[n], rowViews[n]
    if not (a and w) then return end
    if a.type == "toggle" then
        w.onChange(value == true)
    elseif a.type == "select" or a.type == "stylechoice" then
        local p = tonumber(part) or 0
        local d = a.type == "select" and w or p == 0 and w.main or w.extras[p]
        local v = d and d.values and d.values[tonumber(value)]
        if v then d.onChange(v.value) end
    elseif a.type == "oneof" then
        -- the choice clicked (the shell drew it chosen); clicking the chosen one sets nothing (make.OneOf's)
        local choice = w.values[tonumber(value)]
        if choice and choice.value ~= w.value then
            w.value = choice.value
            setArg(S.selected, a, choice.value)
        end
    else
        setArg(S.selected, a, value)
    end
end

--- A button's click (the plain control i), from the shell: its function, then the page's refresh.
TK.ShellCalls["settings.run"] = function(i)
    local a = layoutRows[tonumber(i)]
    if not a then return end
    TK.SafeCall(a.func, S.selected)
    S:RefreshPage()
end

TK.ShellCalls["settings.laidout"] = function()
    placeBindingRows(#pools.binding < bindingRowsMade) -- out of the window unless a row is in use (s6-optimize round 10)
end

--- The widget showing an option on the open page, by the option's name (for tests); s6-sandbox (round 11): or its id,
--- for an option whose name is a function.
function S:Widget(name)
    for _, pw in ipairs(pageWidgets) do
        if pw[2].name == name or pw[2].id == name then return pw[1] end
    end
end

--- The status line's text (what the last change did).
function S:StatusText() return __tk:ShellSettingsStatusText() end

--- Scrolls the page so a widget is at its top (the Key Bindings page is long; tests and scripts).
function S:ScrollTo(widget)
    local _, _, _, _, y = widget:GetPoint(1)
    pageScroll:SetVerticalScroll(math.max(0, -(y or 0) - 8))
end

--- Sets an option exactly as its widget would (used by tests and scripts): finds the node's arg by key or name.
function S:SetOption(nodeId, keyOrName, value, startup)
    local node = self:FindNode(nodeId, startup)
    if not node then return false end
    for _, tab in ipairs(node.tabs or {}) do
        -- s6-interface-5x (round 12): a row's controls are found by their own names (BuildPage's "row")
        for _, a in ipairs(controls(tab)) do
            if a.key == keyOrName or a.name == keyOrName then
                if not frame then build() end
                setArg(node, a, value)
                return true
            end
        end
    end
    return false
end

-- ----- tabs -----

local tabButtons = {}
S.tabButtons = tabButtons -- tests: the page's tabs (s6-ui-core round 125)

function S:BuildTabs()
    for _, b in ipairs(tabButtons) do b:Hide() end
    local node = self.selected
    if resetButton then resetButton:SetShown(self:CanReset(node)) end
    if not node then return end
    local x = 10
    for i, tab in ipairs(node.tabs or {}) do
        local b = tabButtons[i]
        if not b then
            b = newTab(tabBar, nil, 12) -- s6-ui-core (round 125, piece 4b): the shell's tab
            tabButtons[i] = b
        end
        b:SetText(tab.name)
        local w = b:GetFontString():GetStringWidth() + 34
        b:SetSize(w, 24)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMLEFT", x, 0)
        x = x + w + 4
        b:SetSelected(i == self.tabIndex)
        b.ops = { run = function()
            self.tabIndex = i
            self:BuildTabs()
            self:BuildPage()
        end }
        b:Show()
    end
end

-- ----- leaving the Sound page (s6-ui-settings: the owner's next31 report) -----

local function over(f)
    local g = GetMouseFocus()
    while g and g ~= f do g = g:GetParent() end
    return g == f
end

--- The dialogs component's own music window stays hidden while the page stands for the dialog, and while the dialog
--- the page was left by is closing (its OK on the way to the model), so it never flashes up. A dialog left open some
--- other way (a script's Select or Close) shows as its own window.
local function syncMusicRenderer()
    if musicOk and musicOk ~= S:MusicWindow() then musicOk = nil end
    TK.Dialogs.SetHidden("MusicControlDialog", musicWanted or musicOk ~= nil) -- s6-characters (round 46, separation step 6)
end

--- Whether showing target leaves the music dialog's page. s6-ui-core (round 54; the owner: Sound's General, Music Player,
--- MIDI and Advanced subpages): every Sound subpage is the dialog's page (each carries open:music), so moving between
--- them leaves nothing: the dialog stays open and no second 1B 01 00 goes (the marker stays shown), as when the one Sound
--- page was scrolled. Wire: changing this changes when the dialog's OK is pressed and when 1B 01 00 is sent again.
function S:LeavesMusicFor(target)
    return target ~= nil and self.selected ~= nil and target.id ~= self.selected.id and target.request ~= "open:music"
end

--- A control of the window that leaves the Sound page (a list row, a list tab, Key Bindings) closes the music dialog as
--- its OK does: its press and its release are the dialog's control 14, as the page's OK button's are (a dialog takes a
--- physical event's record only at that event: LuaApi.DialogPointer). So the window is never locked; the dialog stays
--- modal over the game (TKMusicBlocker), as the original's. leaves() says whether this press leaves the page.
--- Wire: control 14 is 4a's MusicControlDialog::OnControlCommand (0x00529790) case 14, CloseDialog: nothing is sent
--- at the close, and the page's next opening builds the dialog again, which sends 1B 01 00 (its constructor,
--- 0x00528E60). This hook decides which 1B the server sees and when; changing it changes what the server sees.
function S:LeavesMusic(f, leaves)
    f:HookScript("OnMouseDown", function(_, button)
        f.musicOk = musicOpen and leaves() and S:MusicWindow() or nil
        if f.musicOk then
            musicOk = f.musicOk
            TK.Dialogs.Pointer(f.musicOk, 14, button, true) -- the kit's (separation step 6)
        end
    end)
    f:HookScript("OnMouseUp", function(_, button)
        local win = f.musicOk
        if not win then return end
        f.musicOk = nil
        local inside = over(f)   -- released elsewhere: the OK is not pressed, and the control does not click
        if not inside then musicOk = nil end
        TK.Dialogs.Pointer(win, inside and 14 or -1, button, false)
    end)
end

-- ----- the list's tabs (s6-ui-settings) -----

--- A list tab's click (the gate's TKSettingsTab:<category>): the row last open there, the closed entries staying
--- closed. s6-ui-core (round 172, U-64 step 3): the tabs are the shell's (Runtime/Shell/SettingsWindow.Tree.cs draws
--- them on the window's top row, one per category with a page here).
function S:ShowCategory(category) __tk:ShellSettingsShowCategory(category) end

-- ----- the tree -----

local treeButtons = {}
S.treeButtons = treeButtons -- tests: the tree's rows (and S.treeScroll, set when the window is built)

--- All built-in pages, including ones hidden in the current game state. Startup choices use the same registry.
function S:AllNodes()
    local all = TK.Components:AllNodes()
    for _, n in ipairs({ TK.ServersNode, TK.LocalServerNode, TK.LibraryNode, TK.TargetingNode, TK.KeyBindingsNode, -- s6-play-modes
                         TK.GraphicsNode, TK.GraphicsAdvancedNode, TK.GraphicsAdvancedGeneralNode, -- s6-ui-core (round 54)
                         TK.SoundNode, TK.ProfilesNode, TK.MiscNode }) do -- s6-ui-core (build 41): Misc
        all[#all + 1] = n
    end
    -- s6-ui-core (round 54): the pages moved by S.places
    for _, n in ipairs(all) do
        local place = S.places[n.id]
        if place then for k, v in pairs(place) do n[k] = v end end
    end
    return all
end

--- The pages available to the player here (login or world).
function S:Nodes()
    local inWorld = TK.GameState:InWorld()
    TK.KeyBindingsNode.tabs = TK.KeyBindingTabs()
    -- Build menu contents when listing them, not when validating startup options. Server tabs can seed saved servers.
    if not inWorld then TK.ServersNode.tabs = TK.ServerTabs() end
    if not TK.LibraryPage.built and not inWorld then TK.LibraryNode.tabs = TK.LibraryTabs() end -- s6-library
    local nodes = {}
    for _, n in ipairs(self:AllNodes()) do
        if (inWorld and not n.loginOnly) or (not inWorld and (n.atLogin or n.loginOnly)) then nodes[#nodes + 1] = n end
    end
    return nodes
end

--- The pages one list tab shows here, in its order (from all, the pages here, when the caller has them).
function S:CategoryNodes(category, all)
    local nodes = {}
    for _, n in ipairs(all or self:Nodes()) do
        if categoryOf(n) == category then nodes[#nodes + 1] = n end
    end
    if category == "general" then
        table.sort(nodes, function(a, b)
            local ra, rb = GENERAL_ORDER[a.id] or 99, GENERAL_ORDER[b.id] or 99
            if ra ~= rb then return ra < rb end
            return (a.order or 0) < (b.order or 0)
        end)
    elseif category == "interface" then
        -- s6-modular-g (interfaces, phase 2): the panels by interface (the viewed one first, s6-ui-core round 83) and category
        TK.Panels:SortNodes(nodes)
    end
    -- s6-devtools (round 3; the owner, 2026-10-05: "a debug panel ... at the bottom"): a node marked last (the Debug page,
    -- components/debug) ends its list, after the core pages; FOR s6-ui-core
    for i = #nodes - 1, 1, -1 do
        if nodes[i].last then table.insert(nodes, table.remove(nodes, i)) end
    end
    return nodes
end

--- s6-ui-settings (nested settings menus, the header): a list tab's entries as a tree in the tab's order, and the
--- entries by id. An entry is { id, title, node (nil for a title no node names), children, visible }; a node goes under
--- the entry its parent field names, and a parent no node of the tab names becomes a title at its first child's place.
--- A node whose shown() is false is left out of the tree with everything under it; byId keeps it (visible nil), so the
--- nearest shown entry above it can be found.
function S:Tree(category, all)
    local nodes = self:CategoryNodes(category, all)
    local byId, roots = {}, {}
    for _, n in ipairs(nodes) do byId[n.id] = { id = n.id, title = n.title, node = n, children = {} } end
    for _, n in ipairs(nodes) do
        local p = n.parent
        if p == nil then
            roots[#roots + 1] = byId[n.id]
        else
            if not byId[p] then
                byId[p] = { id = p, title = p, children = {} }
                roots[#roots + 1] = byId[p]
            end
            table.insert(byId[p].children, byId[n.id])
        end
    end
    local function shownOf(list)
        local out = {}
        for _, e in ipairs(list) do
            if not (e.node and e.node.shown and not e.node.shown()) then
                e.visible = true
                e.children = shownOf(e.children)
                out[#out + 1] = e
            end
        end
        return out
    end
    -- s6-modular-g (interfaces, phase 2): the Interface list's entries under its titles (s6-ui-core round 83: Panes)
    if category == "interface" then roots = TK.Panels:GroupRoots(roots, byId) end
    return shownOf(roots), byId
end

--- Opens or closes an entry's children (its + / - button). The closed ones are kept in the profile with the tab and the
--- rows last open, so the list looks the same at the next opening. The shell's list asks for it ("settings.expand").
function S:SetExpanded(id, open)
    local closed = TK.DB:Global().settingsCollapsed
    if (closed[id] == true) ~= open then return end
    closed[id] = (not open) or nil
    TK.DB:MarkDirty()
end

function S:FindNode(id, startup)
    -- A launch override can set a page before login even when the menu hides that page there.
    for _, node in ipairs(startup and self:AllNodes() or self:Nodes()) do
        if node.id == id then return node end
    end
end

-- s6-ui-core (round 172, U-64 step 3): the list's behaviour is the shell's (Runtime/Shell/SettingsWindow.Tree.cs): it
-- draws the tree, opens and closes its entries, selects a page and keeps its row in view. What the list holds stays
-- here: the pages here (S:Nodes), each tab's tree (S:Tree; the Interface tab's grouped by TK.Panels) and the profile's
-- kept tab, rows and closed entries. The shell reads them as a catalogue and hands each choice back ("settings.show").

--- Shows the page an entry's id names (any tab's entry: a page, a title node, or a title the tree made for a parent),
--- else the shown tab's first page. restoring: the row last open is shown again, the entries the player closed staying
--- closed; any other call is a shortcut to the page, and every entry above it opens (SettingsWindow.Select).
function S:Select(id, tabName, restoring) __tk:ShellSettingsSelect(id, tabName, restoring == true) end

--- The list drawn again from what is shown now (an interface viewed: core/panels.lua's P:View).
function S:BuildTree() __tk:ShellSettingsBuildTree() end

--- s6-ui-settings (s6-peer's note): the list drawn again after a page changed which entries are shown; a selected page
--- no longer shown gives way to the nearest shown entry above it.
function S:RefreshTree() __tk:ShellSettingsRefreshTree() end

local listed -- the pages here as the shell's catalogue last listed them (S:Nodes(), once per page change: s6-optimize)
local function pages(fresh)
    if fresh or not listed then listed = S:Nodes() end
    return listed
end

--- The shell's catalogue of the list: one line a fact, its fields tab-separated. "k", the tab last open; for each tab
--- "c", its id, title and row last open, then its shown entries depth first, "e", depth, id, title, flags (n: a node,
--- p: a page, x: closed), the node's parent and an Interface page's headings (TK.Panels:HeadingsOf); then
--- its entries not shown, "h", id, flags, the node's parent (the shell finds the nearest shown entry above them).
TK.ShellCalls["settings.catalogue"] = function(_, fresh)
    local all = pages(fresh)
    local g = TK.DB:Global()
    local closed = g.settingsCollapsed
    local out = { "k\t" .. (g.settingsTab or "") }
    local function flags(e)
        return (e.node and "n" or "") .. (isPage(e.node) and "p" or "") .. (closed[e.id] and "x" or "")
    end
    for _, c in ipairs(S.categories) do
        local roots, byId = S:Tree(c.id, all)
        out[#out + 1] = table.concat({ "c", c.id, c.title, g.settingsRows[c.id] or "" }, "\t")
        local function add(entries, depth)
            for _, e in ipairs(entries) do
                local n, heads = e.node, {}
                if c.id == "interface" and isPage(n) then
                    for _, h in ipairs(TK.Panels:HeadingsOf(n)) do heads[#heads + 1] = h.id end
                end
                out[#out + 1] = table.concat({ "e", depth, e.id, e.title or e.id, flags(e), n and n.parent or "",
                    table.concat(heads, ",") }, "\t")
                add(e.children, depth + 1)
            end
        end
        add(roots, 0)
        for id, e in pairs(byId) do
            if not e.visible then
                out[#out + 1] = table.concat({ "h", id, flags(e), e.node and e.node.parent or "" }, "\t")
            end
        end
    end
    return table.concat(out, "\n")
end

--- s6-interface-5x (round 12): a shortcut to another interface's page shows that interface's list first, so the page's
--- row is in the tree (the list holds only the shown interface's pages). Only the Interface tab's pages: a General page
--- that is a panel's (Classic Commands) leaves the shown interface alone (Astra's s6-interface-5x-self-12-3).
TK.ShellCalls["settings.reveal"] = function(id)
    for _, n in ipairs(pages(true)) do
        if n.id == id then
            if categoryOf(n) == "interface" then TK.Panels:Reveal(n) end
            return
        end
    end
end

--- The shell's choice of page (SettingsWindow.Select): its node is S.selected; its list tab shows, and the profile
--- keeps it and its row for the next opening; the page's tab is chosen; and the Sound page's request goes (below).
TK.ShellCalls["settings.show"] = function(id, tabName, changed)
    local node
    for _, n in ipairs(pages()) do
        if n.id == id then node = n break end
    end
    if not node then return end
    if changed then dismissReset() end
    S.selected = node
    S.category = categoryOf(node)
    -- s6-interface-5x (round 12): the Interface tab lists one interface's pages; a page of another shows that one first
    if S.category == "interface" then TK.Panels:Reveal(node) end
    local g = TK.DB:Global()
    if g.settingsTab ~= S.category or g.settingsRows[S.category] ~= node.id then
        g.settingsTab = S.category
        g.settingsRows[S.category] = node.id
        TK.DB:MarkDirty()
    end
    if tabName then
        for i, t in ipairs(node.tabs or {}) do
            if t.name == tabName then S.tabIndex = i end
        end
    elseif changed then
        -- Keep the same tab when moving between similar nodes (Bar 1 to Bar 2), as Bartender does.
        if S.tabIndex > #(node.tabs or {}) then S.tabIndex = 1 end
    end
    -- WIRE (D20): a page that stands for one of the original's dialogs asks as that dialog did, each time the player
    -- opens it in the world: its marker frame carries the request and becomes visible with the page (and with the
    -- window). The Sound pages' open:music is 4a's MusicControlDialog constructor's 1B 01 00 (0x00528E60); changing
    -- when the marker shows changes when the server sees it.
    local music = node.request == "open:music" and TK.GameState:InWorld()
    if requestMarker then requestMarker:SetShown(music) end
    S:SetMusicDialog(music and frame ~= nil and frame:IsShown())
end

TK.ShellCalls["settings.page"] = function()
    S:BuildTabs()
    S:BuildPage()
end
TK.ShellCalls["settings.expand"] = function(id, open) S:SetExpanded(id, open == true) end

--- The shell's rows and tabs just drawn (SettingsWindow.Tree.cs's Mirror), one line each, tab-separated: "r", the row's
--- handle, its entry, its page (or ""), the page its click shows (or ""); "t", the tab's handle, its category, "1" when
--- chosen, the page its click shows. They keep their names here (TK.Settings.treeButtons with entry, nodeId and target:
--- the gate's TKSettingsNode:<id>, gatecontrols.lua; _G["TKSettingsTab:<category>"] with selected) and their presses'
--- wire.
TK.ShellCalls["settings.rows"] = function(_, text)
    local byId = {}
    for _, n in ipairs(pages()) do byId[n.id] = n end
    local i = 0
    for line in text:gmatch("[^\n]+") do
        local kind, h, id, a, target = line:match("^(%a)\t(%d+)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
        local b
        if kind == "r" then
            b = TK.Wrap(tonumber(h))
            i = i + 1
            treeButtons[i] = b
            if not b.sel then
                b.sel, b.text, b.expander = sub(b, "sel"), sub(b, "text"), sub(b, "expander")
                b.expander.label = sub(b, "expanderLabel")
                -- Wire: a press that leaves the Sound page (a row showing another page) is the music dialog's control
                -- 14, its OK, which 4a's MusicControlDialog::OnControlCommand (0x00529790) answers with CloseDialog.
                -- The close sends nothing, but it is what lets the Sound page's next opening build the dialog again
                -- (MusicControlDialog::MusicControlDialog, 0x00528E60), which sends 1B 01 00. Changing which rows press
                -- it changes the 1B the server sees, and when.
                S:LeavesMusic(b, function() return S:LeavesMusicFor(b.target) end)
            end
            b.entry = { id = id }
            b.nodeId = a ~= "" and a or nil   -- the gate's name for the row (gatecontrols.lua): the rows are recycled
        else
            b = TK.WrapShellButton(tonumber(h))
            if not b.category then
                b.category = id
                _G["TKSettingsTab:" .. id] = b
                -- the music dialog's OK, as a row's (above)
                S:LeavesMusic(b, function() return S:LeavesMusicFor(b.target) end)
            end
            b.selected = a == "1"
        end
        b.target = byId[target]
        -- Wire (D20): the press carries the request of the page its click shows; C# freezes it at the press, and the
        -- page's marker runs it when the page shows. Only the Sound pages have one, open:music: in the world the page
        -- is the original's MusicControlDialog, and opening it builds the dialog, whose constructor (4a's
        -- MusicControlDialog::MusicControlDialog, 0x00528E60) sends 1B 01 00 (S:SetMusicDialog). A row or tab that
        -- shows no page carries none (as Sound reopened through the General tab asks as its row does: Astra's review).
        -- Changing which carry it changes when the server sees 1B 01 00.
        TK.Actions:Set(b, b.target and b.target.request)
    end
end

-- ----- the window -----

--- s6-ui-core (round 125, piece 4a): the window's see-through finish, pushed to the shell (SettingsWindow:SetAlpha) when it
--- opens and when the panel style changes, as the HUD panels get theirs (W.FramePanelAlpha).
local function pushFinish()
    __tk:ShellSettingsAlpha(W.FramePanelAlpha(frame))
end

--- s6-ui-core (round 125, piece 4a of the Global Interface's plan): the window is the C# shell's
--- (Runtime/Shell/SettingsWindow.cs); this wraps its parts, keeps their names, and gives them their Lua behaviour: the
--- Sound page's request markers, the music dialog's hooks, the tooltip, Esc and the window's own updates. The shell's
--- clicks come back through __tk_shell ("settings.*", below).
function build()
    local function part(name) return TK.Wrap(__tk:ShellSettingsPart(name)) end
    frame = part("frame")
    frame.__bg = part("fill")   -- the backdrop's fill, as frame.lua's SetBackdrop names it
    -- The window's controls drawn in Lua (the page's, until piece 4b) find it as their see-through window (W.InSeeThroughWindow).
    frame.__hud = true
    W.CountAsWindow(frame) -- GA-3 (the client review's 8.13): a server dialog over it is drawn solid (W.SolidOverPanels)
    -- WIRE: the request markers carry the Sound page's request (D20, MusicControlDialog 0x00528E60's 1B 01 00): the one in
    -- the window becomes visible with that page, or with the window when it opens on that page; the other is for F8 in the
    -- world (s6-ui-core round 80, S:OpenMusic). Changing their request or when they show changes what the server sees.
    requestMarker = part("request")
    TK.Actions:SetOpen(requestMarker, "open:music")
    keyMarker = part("keyMarker")
    TK.Actions:SetOpen(keyMarker, "open:music")
    _G.TKSettingsFrame, _G.TKSettingsRequest, _G.TKMusicKeyRequest = frame, requestMarker, keyMarker

    -- s6-ui-core (round 31): the key-bindings list, as WoW's Key Bindings button opens it (round 54: the hover binding
    -- is Edit Mode's Keybinds).
    local keys = TK.WrapShellButton(__tk:ShellSettingsPart("keys"))
    S:LeavesMusic(keys, function() return S.selected == nil or S.selected.id ~= "keybindings" end)
    frame.keysButton = keys

    treeScroll = part("treeScroll")
    treeScroll.Refresh = function() __tk:ShellSettingsScroll("tree", false) end
    S.treeScroll = treeScroll
    tabBar = part("tabBar")

    -- s6-ui-settings: the page's reset icon, at the top right on the tabs' line (S:AskReset).
    resetButton = part("reset")
    resetButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Reset to defaults", 1, 1, 1)
        GameTooltip:Show()
    end)
    resetButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    _G.TKSettingsReset = resetButton
    -- The icon's question: its choices hide it and come back as "settings.reset".
    resetAsk = part("resetAsk")
    resetAsk.__bg = part("resetFill")
    resetAsk.text = part("resetText")
    resetAsk.tab = TK.WrapShellButton(__tk:ShellSettingsPart("resetTab"))
    resetAsk.page = TK.WrapShellButton(__tk:ShellSettingsPart("resetPage"))
    resetAsk.cancel = TK.WrapShellButton(__tk:ShellSettingsPart("resetCancel"))
    _G.TKSettingsResetAsk, _G.TKSettingsResetTab = resetAsk, resetAsk.tab
    _G.TKSettingsResetPage, _G.TKSettingsResetCancel = resetAsk.page, resetAsk.cancel

    pageScroll, pageContent = part("pageScroll"), part("pageContent")
    pageScroll.Refresh = function() __tk:ShellSettingsScroll("page", false) end
    function pageScroll:ScrollToTop() __tk:ShellSettingsScroll("page", true) end
    bindingRows = part("bindingRows")

    local close = TK.WrapShellButton(__tk:ShellSettingsPart("close"))
    S:LeavesMusic(close, function() return true end)   -- its press and release are the dialog's OK's
    frame.closeButton = close
    frame.plate = part("plate")
    __tk:ShellSettingsBuilt()   -- Esc closes the window, then the reset question (the shell's, round 172)

    -- The music dialog's modality (S:SetMusicDialog): the shell's blocker over the whole screen under the window.
    musicBlocker = part("musicBlocker")
    _G.TKMusicBlocker = musicBlocker
    -- The page closes when the model's music dialog does (its OK, Esc, the game's end).
    frame:HookScript("OnUpdate", function()
        syncListKeys()
        if musicOk then syncMusicRenderer() end   -- the dialog the page was left by has closed: its own window may show
        if not musicWanted then return end
        -- 4a MusicControlDialog 0x00528E60 sends only for an accepted open. The request marker already owns
        -- that request; follow its accepted model without another request or a speculative accepted flag.
        if S:MusicWindow() then S:SetMusicDialog(true) elseif musicSeen then S:Close() end
    end)
    frame:HookScript("OnHide", syncListKeys)
    frame:RegisterEvent("TK_PANEL_STYLE_CHANGED")
    frame:HookScript("OnEvent", function(_, event)
        if event == "TK_PANEL_STYLE_CHANGED" then pushFinish() end
    end)
end

-- The shell's calls (SettingsWindow.cs), each inside its click's dispatch as the Lua controls' were.
-- Button Lock is the profile's: the shell's check writes it here.
TK.ShellCalls["settings.buttonlock"] = function(_, on)
    TK.DB:Global().buttonLock = on
    TK.DB:MarkDirty()
    TK.FireEvent("TK_BUTTON_LOCK", on)
end
TK.ShellCalls["settings.refresh"] = function() S:RefreshPage() end   -- after Lock (edit mode's Lock or Unlock)
TK.ShellCalls["settings.askreset"] = function() S:AskReset() end
-- The music dialog's OK is its control 14: the model closes the dialog, and the page goes with it.
TK.ShellCalls["settings.close"] = function() if not (musicOpen and S:MusicWindow()) then S:Close() end end
TK.ShellCalls["settings.reset"] = function(_, which)
    local node = resetAsk.node
    S:Reset(node, which == "tab" and { node.tabs[resetAsk.tabIndex] } or node.tabs)
end
-- s6-ui-core (round 172, U-64 step 3): the window's opening and closing are the shell's (SettingsWindow.Open, Close);
-- these are their Lua parts. Opening a closed window: the window made if it is not yet (it is at PLAYER_LOGIN, below),
-- and the login screen's server and Library read again (s6-library).
TK.ShellCalls["settings.opening"] = function()
    if not frame then build() end
    TK.LibraryPageReset()
end
-- Opened: always all on the screen, at any UI scale (review F5: shrunk if needed, back on screen if it was off); its
-- see-through finish, the profile's name and the tab's row last open go back to the shell.
TK.ShellCalls["settings.opened"] = function()
    TK.FitToScreen(frame, 10, 16)
    local g = TK.DB:Global()
    return W.FramePanelAlpha(frame), TK.DB.name, g.settingsRows[g.settingsTab]
end
-- Closing: a key capture cancelled, the reset question gone, the Sound page's music dialog closed, the drop-downs shut.
TK.ShellCalls["settings.closing"] = function()
    TK.KeyBindMode:CancelCapture()
    dismissReset()
    S:SetMusicDialog(false)
    W.CloseDropdowns()
end

--- Opens the window on a page and tab (none: the row last open), or, open already, changes the page (the shell's).
function S:Open(nodeId, tabName) __tk:ShellSettingsOpen(nodeId, tabName) end

function S:Close() __tk:ShellSettingsClose() end

--- Head note 32: in the world the Sound page is the original's music dialog (MusicControlDialog), a modal one: the
--- page's opening asks the dialog model for it (open:music, 1B 01 00), and the model owns it from then on (round 17's
--- review, findings 2 and 3): it takes every game key while it is in front, Esc and the page's OK (its control 14) close
--- it, the effects switch is its control 1 (1B 01 0D, once), and it applies only byte 5 of 0x23 meanwhile. The page
--- stands for the dialog's window (the dialogs component's own stays hidden) and closes when the dialog does. While it
--- is open a blocker takes every click outside the window. s6-ui-settings (the owner's next31 report): the window's own
--- controls stay usable; one that leaves the page closes the dialog as its OK does (S:LeavesMusic).
function S:SetMusicDialog(open)
    open = open and true or false
    musicWanted = open
    -- An online request may be refused. Only the existing model's accepted window makes the page modal;
    -- polling the retained handoff never asks again, so 4a's constructor request/order stay server-equivalent.
    open = open and self:MusicWindow() ~= nil
    syncMusicRenderer()
    if not frame or open == (musicOpen or false) then return end
    musicOpen = open
    __tk:ShellSettingsMusic(open)   -- the dialog owns the keys while it is open (SettingsWindow.HasFocus)
    musicSeen = open
    if open then musicOk = nil end
    syncMusicRenderer()
    musicBlocker:SetShown(open)
    frame.closeButton:SetText(open and "OK" or "Close")
    frame:SetFrameStrata(open and "FULLSCREEN" or "DIALOG")
    if open then
        musicLevel = frame:GetFrameLevel()
        frame:SetFrameLevel(musicBlocker:GetFrameLevel() + 5)
    elseif musicLevel then
        -- Back over the windows it was over, as it stays open when the page is left (the owner's next31 report).
        frame:SetFrameLevel(musicLevel)
    end
end

--- The dialog model's music dialog's (hidden) window while it is open, else nil.
function S:MusicWindow()
    local win = TK.Dialogs.Find("MusicControlDialog") -- s6-characters (round 46, separation step 6)
    return win and win.serial and win or nil
end

--- A press or release on the page's control that stands for one of the music dialog's controls (the effects switch's 1),
--- as the window's. Wire: the model acts on them as MusicControlDialog::OnControlCommand (0x00529790) by the control and
--- part (shared/components/dialogs/misc.lua's comment); a release off the page's control is -1, which clicks nothing. Changing the
--- control, the part or the release's mapping changes which 1B 01 the server gets and when.
function S:MusicPointer(control, down, button, f, part)
    local win = musicOpen and self:MusicWindow()
    if not win then return end
    TK.Dialogs.Pointer(win, (down or over(f)) and control or -1, button, down, part) -- the kit's (separation step 6)
end

--- The effects switch (the audio page's box): the music dialog's control 1, on the option it moves to (on 0x40, off
--- 0x41), fixed at the press, so the press and the release on it send 1B 01 0D once.
function S:MusicSwitch(down, button, box)
    local win = musicOpen and self:MusicWindow()
    if not win then return end
    if down then musicPart = (win.view and win.view.contents.effects == 0) and 0x41 or 0x40 end
    self:MusicPointer(1, down, button, box, musicPart)
end

function S:IsMusicDialogOpen() return musicOpen == true end

--- F8, the original's music key (Original Commands' MUSIC and Classic Commands' CLASSICMUSIC). s6-ui-core (round 80;
--- s6-qa's next60 play-test: the music window's own controls, the CD drive and the frequency among them, were out of
--- every player's reach): in the world on a session it opens the music dialog's own window, which the interface's
--- dialogs look draws (7.x's, 5.x's, Modern's), as the original's F8 does. In the world with no session (Play Offline)
--- it opens the Sound page, as before; at the login screen no game key acts (shared/bindings.lua, atLogin), so F8 does
--- nothing there. Opened from this window, the Sound page still stands for the dialog.
--- WIRE: 4a's F8 (UserPane::HandleKeyOrTextEvent 0x005A5BD0, case 0x8c, behind UserPane's gates) makes a
--- MusicControlDialog, whose constructor (0x00528E60) sends 1B 01 00. The key froze open:music; its marker becomes
--- visible within the key's input, so the request runs once in the key's place (UIHost.RunOpenActions, D20), and the
--- rules' dialog model opens the dialog as it does for the page's marker. Changing the marker, the request or when it
--- shows changes when the server sees 1B 01 00.
function S:OpenMusic()
    if keyMarker and TK.GameState:InWorld() and __tk:IsOnline() then
        keyMarker:Show()
        keyMarker:Hide()
        return
    end
    self:Open("sound")
end

function S:Toggle() __tk:ShellSettingsToggle() end

function S:IsOpen() return __tk:ShellSettingsIsOpen() end

--- s6-input (the head's note of 2026-10-06): whether the window has the focus, the shell's (SettingsWindow.HasFocus and
--- Press say when it has it). WIRE: it decides whether a key may reach the game's keys (4a's
--- UserPane::HandleKeyOrTextEvent 0x005A5BD0) and send; changing it changes what the server sees.
function S:HasFocus() return __tk:ShellSettingsHasFocus() end

-- A press anywhere: the window takes the focus when the press is on it or on what opened from it, else gives it back.
TK.On("GLOBAL_MOUSE_DOWN", function() __tk:ShellSettingsPress() end)

-- The Sound page's request can be attached only while the UI loads (plan 5.9): the window is made now.
TK.On("PLAYER_LOGIN", function() if not frame then build() end end)


TK.On("TK_PROFILE_CHANGED", function()
    dismissReset()
    if S:IsOpen() then S:Select(S.selected and S.selected.id, nil, true) end
end)
TK.On("TK_EDIT_MODE", function() if S:IsOpen() then S:RefreshPage() end end)
-- s6-ui-core (round 54; Astra's review): a (!) that reads the style drawn follows the Cycle Graphics Style key
TK.On("TK_DRAWING_STYLE_CHANGED", function() if S:IsOpen() then S:RefreshPage() end end)
TK.On("TK_GAME_STATE", function()
    if S:IsOpen() then S:Select(S.selected and S.selected.id, nil, true) end
    if not TK.GameState:InWorld() then S:SetMusicDialog(false) end
end)

-- ----- Key Bindings, Graphics and Sound (also on the login screen) -----

--- The Key Bindings page: the named commands, then the buttons of every enabled bar. Each row binds by a click and
--- a key press; in the world, the Key Bindings button above binds by hovering over a button instead.
--- The commands of the Key Bindings page, in its groups (head note 37); a command no group names goes under Other.
TK.BindingGroups = {
    { "Movement", { "MOVEUP", "MOVEDOWN", "MOVELEFT", "MOVERIGHT", "VIEWUP", "VIEWDOWN", "VIEWLEFT", "VIEWRIGHT" } },
    { "Map (Mouse)", { "MOUSESELECT", "MOUSEWALK" } },
    { "Targeting", { "SELECTNEXT", "SELECTPREVIOUS", "SELECTSELF", "SELECTTOGGLE", "SELECTTOGGLEBACK", "SELECTFILTER" } },
    { "Windows", { "TOGGLECHARACTER", "TOGGLESPELLBOOK", "TOGGLECOLLECTION", "TOGGLEBAG", "TOGGLEGROUP", "TOGGLESOCIAL",
        "TOGGLEEMOTES", "OPENCHAT", "OPENCHATSLASH" } },
    { "Actions", { "ATTACK", "PICKUP", "PICKUPALL", "PICKUP3", "LOOK", "OPENOBJECT", "RIDE", "BOARDS", "MAIL", "USERLIST",
        "REFRESH", "HELPMENU", "HELPMENU2", "BAREHANDS", "MINIMAPREQUEST" } },
    { "Action Wheel", { "ACTIONWHEEL", "ACTIONWHEEL_MULTI" } },
    -- s6-ui-settings: the options tab (F10) and the original's keys for its local switches (Shift+R, Shift+F10-F12).
    { "Game Options", { "TOGGLEGAMEOPTIONS", "TOGGLECLICKLOOK", "TOGGLESHOWDAMAGE", "TOGGLETABVSWAP", "TOGGLECLICKMOVE" } },
    { "Screenshots", { "SCREENSHOT", "SCREENSHOTBMP" } },
    -- s6-ui-core (round 169, interface-separation.md's W5): 16 of the 22 commands Classic Commands registers
    -- (shared/components/classic/main.lua); its other six come under Other. Whisper, shout and say are the chat's keys
    -- (TK.Game.Chat), not Classic's.
    { "Classic Prompts", { "CLASSICDROP", "CLASSICDROPALL", "CLASSICEAT", "CLASSICUSE", "CLASSICWIELD", "CLASSICWEAR",
        "CLASSICTHROW", "CLASSICGIVE", "CLASSICGIVEALL", "CLASSICCAST", "CLASSICINVITE", "CLASSICEMOTE",
        "CLASSICIGNORE", "CLASSICSTATUS", "CLASSICCOLLECTION", "CLASSICHELP" } },
    { "Macros", { "TOGGLEMACROS", "MACROS" } }, -- s6-macros (round 10): the macro window's, Original Macro Setup, and keys bound to macros
}

--- The Key Bindings page: every bindable command in its group, with two bindings each; the Classic Keys preset at the
--- top; the hotbars' buttons and the item keys on their own tabs.
function TK.KeyBindingTabs()
    local B = TK.Bindings
    local classic = TK.GetComponent("classic")
    local general = {
        { type = "toggle", name = "Classic Keys (the original's)",
          -- s6-ui-core (round 54; the owner's short-text rule): its line is its tooltip
          desc = "Writes the original's keys into this table. Off, your own bindings come back.",
          get = function() return classic and classic:DB().enabled and true or false end,
          set = function(_, on)
              if not classic then return end
              classic:DB().enabled = on and true or false
              classic:ApplySettings()
              TK.DB:MarkDirty()
          end },
        -- s6-ui-core (round 54; the owner, 2026-10-05: "this button isn't needed here with that change, and that is a LOT of
        -- text"): the hover binding is Edit Mode's Keybinds now (core/global/editmode.lua), and the slots say how they bind in
        -- their tooltip (makeBindingRow).
        { type = "description", name = function()
              local w = B:ChordWarningText()
              return #w > 0 and ("Warning: " .. table.concat(w, "\nWarning: ")) or ""
          end },
    }
    general[#general + 1] = { type = "bindingHeading", name = "Command" }
    local listed = {}
    for _, group in ipairs(TK.BindingGroups) do
        general[#general + 1] = { type = "header", name = group[1] }
        for _, command in ipairs(group[2]) do
            listed[command] = true
            local c = B.commands[command]
            if c and c.hidden and c.hidden() then c = nil end -- s6-macros: a command hidden by its setting (Original Macro Setup)
            if c then general[#general + 1] = { type = "binding", name = c.text, command = command, off = B:OffPanel(c) } end -- s6-interface-5x (round 13): off
        end
        -- s6-macros: keys bound to the player's macros before the macro window stopped binding keys; they still run their
        -- macros, and are changed or cleared here.
        if group[1] == "Macros" and TK.MacroBindingRows then -- s6-macros
            for _, a in ipairs(TK.MacroBindingRows()) do general[#general + 1] = a end -- s6-macros
        end -- s6-macros
    end
    local other = {}
    for _, c in ipairs(B.commandList) do
        local hidden = c.hidden and c.hidden() -- s6-macros: a command hidden by its setting (Original Macro Setup)
        if not listed[c.name] and not hidden and not c.name:match("^CLASSICUSE%d") then other[#other + 1] = { type = "binding", name = c.text, command = c.name, off = B:OffPanel(c) } end -- s6-macros; s6-interface-5x (round 13): off
    end
    if #other > 0 then
        general[#general + 1] = { type = "header", name = "Other" }
        for _, a in ipairs(other) do general[#general + 1] = a end
    end
    local bars = { { type = "description", name = "The buttons of the bars that are on (turn bars on in Bars, in the list "
        .. "on the left). A bar that is off keeps its keys, and they still work; turn it on to change them here." },
        { type = "bindingHeading", name = "Command" } }
    -- s6-modular-g (round 19, the separation's step 8; interface-separation.md 5.9): each panel that is on and binds its
    -- buttons by frame (panel.clicks, their frames' name but for the number: Modern's bars), its buttons by the binding
    -- each binds through (its bindable entry: the original's hotkeys' carriers, TK.Game.Hotkeys, for bars 1-3's buttons
    -- 1-10); read from the panels and the bindable buttons, not from an interface's code
    local through = {}
    for f, b in pairs(B.bindable) do
        if not TK.IsDead(f) and f:GetName() then through[f:GetName()] = b.command end
    end
    for _, panel in ipairs(TK.Panels:All()) do
        if panel.clicks and TK.Panels:IsOn(nil, panel) then
            bars[#bars + 1] = { type = "header", name = panel.name }
            local j = 1
            while through[panel.clicks .. j] do
                bars[#bars + 1] = { type = "binding", name = "Button " .. j, command = through[panel.clicks .. j] }
                j = j + 1
            end
        end
    end
    local items = { { type = "description", name = "Each item slot's use, by itself (the Classic preset puts them on Ctrl and a letter)." },
        { type = "bindingHeading", name = "Command" } }
    for i = 1, 52 do
        local c = B.commands["CLASSICUSE" .. i]
        if c then items[#items + 1] = { type = "binding", name = c.text, command = c.name } end
    end
    return { { name = "General", args = general }, { name = "Action Bars", args = bars }, { name = "Item Keys", args = items } }
end

TK.KeyBindingsNode = { id = "keybindings", title = "Key Bindings", order = 900, category = "general", atLogin = true, tabs = {},
    db = function() return {} end }

-- ----- the Targeting page (head note 34; plan 5.9 and D25; the rules' casting options, s6-protocol's API.md) -----
-- s6-input (the owner, 2026-10-04): the Casting page became Targeting, with the drag-selection's markers and the target
-- frame's look; the casting settings keep their [casting] keys, and the page its id, so saved values and links stay.

local function casting(key, default)
    local v = __tk:ClientSettingString("casting", key)
    return v ~= "" and v or default
end

--- s6-ui-settings: a casting value's default (the page's reset), as casting() reads it before anything is set.
local function castingDefault(key, default)
    local v = __tk:ClientSettingDefaultString("casting", key)
    return v ~= "" and v or default
end

--- A change: kept in settings.toml's [casting] and handed to the session's rules at once.
local function setCasting(key, value)
    if type(value) == "number" then __tk:ClientSettingSetInt("casting", key, math.floor(value))
    elseif type(value) == "boolean" then __tk:ClientSettingSetBool("casting", key, value) -- s6-input: skip_affected
    else __tk:ClientSettingSetString("casting", key, value) end
    __tk:ClientSettingsSave()
    __tk:ApplyCasting()
end

--- s6-input: a look value (settings.toml's [targeting]), saved and handed to the drawing at once.
local function setTargeting(key, value)
    if type(value) == "boolean" then __tk:ClientSettingSetBool("targeting", key, value)
    else __tk:ClientSettingSetString("targeting", key, value) end
    __tk:ClientSettingsSave()
    __tk:ApplyTargeting()
end

local function targeting(key, default)
    local v = __tk:ClientSettingString("targeting", key)
    return v ~= "" and v or default
end

-- The colours offered for the markers and the frame ("RRGGBB").
local COLOURS = {
    { value = "ffffff", text = "White" }, { value = "ffff40", text = "Yellow" }, { value = "ffa040", text = "Orange" },
    { value = "ff4040", text = "Red" }, { value = "ff60ff", text = "Pink" }, { value = "60ff60", text = "Green" },
    { value = "60ffff", text = "Cyan" }, { value = "6090ff", text = "Blue" },
}

local function withOriginal(list)
    local out = { { value = "", text = "Original (turning blue)" } }
    for _, c in ipairs(list) do out[#out + 1] = c end
    return out
end

TK.TargetingNode = { id = "casting", title = "Targeting", order = 895, category = "general", atLogin = true, machine = true,
    db = function() return {} end,
    tabs = { { name = "Targeting", args = {
        { type = "description", name = "How a targeted spell's key picks its target. Select is the original's target line: "
            .. "the key opens it, the arrows or h j k l move it, Enter or a click casts, Esc cancels. Hover casts on the "
            .. "creature under the mouse at the key's press, once per press; with none there it opens the target line." },
        { type = "select", name = "Casting Mode",
          values = { { value = "select", text = "Select (the target line)" }, { value = "hover", text = "Hover (under the mouse)" } },
          get = function() return casting("mode", "select") end, set = function(_, v) setCasting("mode", v) end,
          default = function() return castingDefault("mode", "select") end },
        { type = "header", name = "The Sweep" },
        { type = "description", name = "What a targeted spell's key does while targets are drag-selected. Hold casts on "
            .. "each selected target in turn while the key is held; Strict casts on the next one at each press; Off "
            .. "ignores the selection." },
        { type = "select", name = "Sweep",
          values = { { value = "hold", text = "Hold" }, { value = "strict", text = "Strict" }, { value = "off", text = "Off" } },
          get = function() return casting("sweep", "hold") end, set = function(_, v) setCasting("sweep", v) end,
          default = function() return castingDefault("sweep", "hold") end },
        -- s6-optimize (round 34): page declarations only. CastingRules reads the interval only for a Hold sweep,
        -- and the skip in Hold and Strict. The casting ledger, waits and input-to-packet path are unchanged.
        { type = "group", requires = { TK.Needs("Sweep: Hold", function() return casting("sweep", "hold") == "hold" end) }, args = {
            { type = "range", name = "Sweep Interval (ms)", min = 350, max = 2000, step = 50,
              get = function() return math.max(350, __tk:ClientSettingInt("casting", "sweep_interval_ms")) end,
              set = function(_, v) setCasting("sweep_interval_ms", v) end,
              default = function() return math.max(350, __tk:ClientSettingDefaultInt("casting", "sweep_interval_ms")) end },
        } },
        { type = "group", requires = { TK.Needs("Sweep: Hold or Strict", function() return casting("sweep", "hold") ~= "off" end) }, args = {
            -- s6-input (the owner, 2026-10-04): the sweep passes over a selected target that still shows the spell's effect
            -- (docs/user-related/decisions/2026-10-04-sweep-skips-affected-targets.md).
            { type = "description", name = "With the skip on, the sweep passes over a selected creature that still shows the "
                .. "effect of the spell being cast (a freeze still on), as far as the client can tell from what it has seen and "
                .. "learned; when it cannot tell, it casts. If every one still has it, the sweep waits." },
            { type = "toggle", name = "Skip Targets That Still Have This Spell's Effect",
              get = function() return __tk:ClientSettingBool("casting", "skip_affected") end,
              set = function(_, v) setCasting("skip_affected", v and true or false) end,
              default = function() return false end },
        } },
        { type = "header", name = "Selection Markers" },
        { type = "description", name = "Drag a box over the map's empty ground to select creatures for the sweep; each "
            .. "selected one gets corner marks round it. Esc, or a drag over none, clears them. The main target keeps its "
            .. "own frame. On the ground, a creature hides the corners behind it." },
        { type = "toggle", name = "Always Fully Visible",
          get = function() return __tk:ClientSettingBool("targeting", "marker_on_top") end,
          set = function(_, v) setTargeting("marker_on_top", v and true or false) end,
          default = function() return false end },
        { type = "select", name = "Marker Colour", values = COLOURS,
          get = function() return targeting("marker_colour", "ffffff") end, set = function(_, v) setTargeting("marker_colour", v) end,
          default = function() return "ffffff" end },
        { type = "header", name = "Target Frame" },
        { type = "toggle", name = "Under the Target",
          get = function() return __tk:ClientSettingBool("targeting", "target_box_under") end,
          set = function(_, v) setTargeting("target_box_under", v and true or false) end,
          default = function() return false end },
        { type = "select", name = "Target Frame Colour", values = withOriginal(COLOURS),
          get = function() return targeting("target_box_colour", "") end, set = function(_, v) setTargeting("target_box_colour", v) end,
          default = function() return "" end },
    } } } }

-- s6-ui-core (round 54; the owner, 2026-10-05): Graphics is a title with subpages, this page its General, the drawing
-- styles its Asset Styles (components/graphicsstyles); the id stays "graphics", so shortcuts land on General.
TK.GraphicsNode = { id = "graphics", title = "General", parent = "Graphics", order = 910, category = "general", atLogin = true, machine = true,
    defaults = function() return TK.Machine.defaults.graphics end, -- s6-ui-settings: the page's reset
    db = function() return TK.Machine:Get().graphics end,
    onChange = function() TK.Machine:ApplyGraphics() end,
    tabs = { { name = "General", args = {
        { type = "select", key = "windowMode", name = "Window Mode",
          desc = "Kept for this computer. Applies to the built client, not the editor.", -- s6-ui-core (round 54): was a line
          values = { { value = "windowed", text = "Windowed" }, { value = "borderless", text = "Borderless full screen" },
                     { value = "fullscreen", text = "Full screen" } } },
        { type = "toggle", key = "vsync", name = "Vertical Sync" },
        -- s6-ui-core (round 54): no effect while Vertical Sync is on (its (!)), and still set
        -- s6-reprojection (round 58, head note 024): past 240 an "Unlimited" stop, stored as 0 (no cap)
        { type = "range", key = "frameCap", name = "Frame Rate Cap", min = 20, max = 240, step = 5,
          stop = { text = "Unlimited", value = 0 },
          requires = { TK.Needs("Vertical Sync off", function(db) return not db.vsync end) } },
    } } } }

-- The owner's round-63 mock-up precedes the existing display settings. Components are read lazily by these rows.
local quickRows = require("core.global.quicksettings"):Rows()
for i = #quickRows, 1, -1 do table.insert(TK.GraphicsNode.tabs[1].args, 1, quickRows[i]) end

-- s6-ui-core (round 54; the owner, 2026-10-05: "Under Graphics add an Advanced page as well ... Under Advanced I want a
-- General and an Interpolation page ... Maybe on Advanced add a global enable for all advanced settings that get added
-- later?"): Graphics > Advanced, a title, with its General page: Enable Advanced Graphics (on by default, kept for this
-- computer), which every advanced graphics setting needs (their (!), TK.Machine:AdvancedGraphics; s6-optimize round 33:
-- what reads it through Component:Applied follows a change at once, setArg), and the pages S.places puts under it
-- (Interpolation). s6-ui-core (round 60): Motion, Lighting and
-- Weather are under it now; only Motion's Animation Interpolation needs the switch (the others behave as on the
-- Experimental tab, the brief: "Every effect behaves as today"), so its tooltip names that one (a question to the owner).
TK.GraphicsAdvancedNode = { id = "graphicsadvanced", title = "Advanced", parent = "Graphics", category = "general", atLogin = true }
TK.GraphicsAdvancedGeneralNode = { id = "graphicsadvancedgeneral", title = "General", parent = "graphicsadvanced",
    category = "general", atLogin = true, machine = true,
    defaults = function() return TK.Machine.defaults.graphics end,
    db = function() return TK.Machine:Get().graphics end,
    tabs = { { name = "General", args = {
        { type = "toggle", key = "advanced", name = "Enable Advanced Graphics",
          desc = "Motion's Animation Interpolation. Off, it has no effect." },
    } } } }

-- The Sound page is the original's music dialog (F8): opened in the world it asks as the dialog did (1B 01 00,
-- plan D20). The audio job fills the page. s6-ui-core (round 54; the owner, 2026-10-05): Sound is a title with subpages,
-- this page its General (the id stays "sound": F8 and the shortcuts land here); the others (components/audio) carry the
-- same request, so the dialog stays open while the player moves between them (S:LeavesMusicFor).
TK.SoundNode = { id = "sound", title = "General", parent = "Sound", order = 920, category = "general", atLogin = true, machine = true, request = "open:music",
    db = function() return TK.Machine:Get().sound end,
    tabs = { { name = "Sound", args = {
        { type = "range", key = "master", name = "Master Volume", min = 0, max = 1, step = 0.05 },
        { type = "range", key = "music", name = "Music", min = 0, max = 1, step = 0.05 },
        { type = "range", key = "effects", name = "Sound Effects", min = 0, max = 1, step = 0.05 },
    } } } }

-- s6-ui-core (build 41; the owner, 2026-10-05): the Experimental tab's Misc page, at the login screen and in the game.
-- Like the Sound page it is filled by the components that own its settings: each adds a control with its own get, set
-- and default on its own settings (graphicsstyles: Wind Armor Fix; worldview: Original 16-bit Colour).
TK.MiscNode = { id = "misc", title = "Misc", category = "experimental", atLogin = true,
    db = function() return {} end,
    tabs = { { name = "Misc", args = {
        { type = "description", name = "Experimental: what is on this tab may change or go." },
    } } } }

-- ----- the Servers page (head note 27; login only) -----

-- What the form's fields hold until Add Server (or Save Server) takes them; editing is the saved server being edited.
-- FOR s6-ui-login (s6-library round 19): aliases, the "Also Known As" field's text.
local newServer = { name = "", host = "", port = "3000", aliases = "" }
local editing

local function rebuildServers()
    TK.ServersNode.tabs = TK.ServerTabs()
    S:BuildPage()
end

--- The form back to empty, editing nothing.
local function clearForm()
    editing, newServer.name, newServer.host, newServer.port, newServer.aliases = nil, "", "", "3000", ""
end

--- The saved servers (settings.toml): the enabled one, a form to add one (or change one), and each one with its Edit
--- and Remove buttons.
function TK.ServerTabs()
    local H = __tk
    -- GA-3 (the client review's 8.5): the seeded live server is listed only while Settings > Official is on (or while it
    -- is the enabled one, so the choice never shows blank).
    local function listed(s)
        return not H:IsOfficialServer(s.host) or H:ClientSettingBool("official", "enabled") or s.id == H:GetEnabledServer()
    end
    local args = {
        { type = "description", name = "Connect uses the enabled Internet server. Accounts are saved per server." },
        { type = "select", name = "Enabled Server", width = "full",
          values = function()
              local values = {}
              for _, s in ipairs(TK.Login.Servers()) do
                  if listed(s) then
                      values[#values + 1] = { value = s.id, text = s.name .. " (" .. s.host .. ":" .. math.floor(s.port) .. ")" }
                  end
              end
              return values
          end,
          get = function() return H:GetEnabledServer() end,
          set = function(_, id)
              H:SetEnabledServer(id)
              TK.Login:ServerChanged()
          end },
        { type = "header", name = editing and "Edit a Server" or "Add a Server" },
        { type = "input", name = "Name", live = true, get = function() return newServer.name end,
          set = function(_, t) newServer.name = t end },
        { type = "input", name = "Host", live = true, get = function() return newServer.host end,
          set = function(_, t) newServer.host = t end },
        { type = "input", name = "Port", live = true, get = function() return newServer.port end,
          set = function(_, t) newServer.port = t end },
        -- FOR s6-ui-login (s6-library round 19, the owner's "Also known as"): the same server's other addresses; a connection
        -- to one of them uses this server's Library, maps and settings (ServerAliases). Checked when saved.
        { type = "input", name = "Also Known As", live = true,
          desc = "Other addresses of the same server, comma separated (host or host:port). A connection to one uses this server's Library, maps and settings.",
          get = function() return newServer.aliases end, set = function(_, t) newServer.aliases = t end },
        { type = "execute", name = editing and "Save Server" or "Add Server", func = function()
              local host = (newServer.host or ""):gsub("^%s+", ""):gsub("%s+$", "")
              local port = tonumber(newServer.port)
              if TK.Login.ParseServer(host .. ":" .. tostring(port or "")) == nil then
                  return UIErrorsFrame:AddMessage("A server needs a host (a name or an address) and a port from 1 to 65535.", 1, 0.3, 0.3)
              end
              -- s6-library round 19 (the owner: "make sure they are formatted correctly"): a bad address saves nothing.
              local problem = H:ServerAliasesProblem(newServer.aliases or "")
              if problem ~= "" then return UIErrorsFrame:AddMessage("Also Known As: " .. problem .. ".", 1, 0.3, 0.3) end
              local id, ok = editing, false
              if editing then ok = H:EditServer(editing, newServer.name, host, port)
              else
                  id = H:AddServer(newServer.name, host, port)
                  ok = id ~= ""
              end
              if not ok then
                  return UIErrorsFrame:AddMessage("A server needs a host (a name or an address) and a port from 1 to 65535.", 1, 0.3, 0.3)
              end
              H:SetServerAliases(id, newServer.aliases or "")
              -- The enabled address changed: the login screen waits for Connect.
              local reconnect = editing ~= nil and editing == H:GetEnabledServer()
              clearForm()
              rebuildServers()
              if reconnect then TK.Login:ServerChanged() end
          end },
        { type = "execute", name = "Cancel", hidden = function() return editing == nil end, func = function()
              clearForm()
              rebuildServers()
          end },
        { type = "header", name = "Saved Servers" },
    }
    for _, s in ipairs(TK.Login.Servers()) do if listed(s) then
        -- FOR s6-ui-login (s6-library round 19): a server's other addresses after its own.
        local aka = (s.aliases or "") ~= "" and ("    Also: " .. s.aliases) or ""
        args[#args + 1] = { type = "description", name = s.name .. "    " .. s.host .. ":" .. math.floor(s.port) .. aka }
        args[#args + 1] = { type = "execute", name = "Edit " .. s.name, func = function()
            editing, newServer.name, newServer.host, newServer.port = s.id, s.name, s.host, tostring(math.floor(s.port))
            newServer.aliases = s.aliases or ""
            rebuildServers()
        end }
        args[#args + 1] = { type = "execute", name = "Remove " .. s.name,
            disabled = function() return #H:GetServers() < 2 end,
            func = function()
                local enabled = H:GetEnabledServer()
                H:RemoveServer(s.id)
                rebuildServers()
                if H:GetEnabledServer() ~= enabled then TK.Login:ServerChanged() end
            end }
    end end
    -- s6-play-modes (round 8, interface-separation step 4, W8; moved from components/graphicsstyles): each saved server's
    -- protocol version (s6-modular, DESIGN.md section 3), set by hand, 7.5.2 until set. The versions offered are 7.5.2 and
    -- the installed protocol modules'; the login screen's connection loads the one that serves the server's version, and
    -- says so when none does. Kept in modules.json beside the server list (so the server form and settings.toml stay as
    -- they are).
    -- s6-ui-core (round 121): the versions through __tk (LuaApi.Protocol.cs), not CS.TK.Modular.ProtocolHost
    args[#args + 1] = { type = "header", name = "Protocol Versions" }
    args[#args + 1] = { type = "description", name = "The version each server speaks: its protocol module is loaded when the login screen connects. A version with no module installed is said on the login screen, and nothing connects." }
    -- s6-optimize (round 7): the versions are read (a scan of the Modules folder's manifests, about 3.6 ms on the VM) when
    -- the page first shows its selects, once for all of them, not each time the settings window lists its pages (three or
    -- four times an opening, in the world too, where this login-only page never shows).
    local list
    local function versions()
        if not list then
            list = {}
            for v in string.gmatch(H:GetProtocolVersions(), "[^;]+") do list[#list + 1] = { value = v, text = v } end
        end
        return list
    end
    for _, s in ipairs(TK.Login.Servers()) do
        local host, port = s.host, math.floor(s.port)
        args[#args + 1] = { type = "select", name = s.name .. " (" .. host .. ":" .. port .. ")", values = versions,
            get = function() return H:GetProtocolVersion(host, port) end,
            set = function(_, v)
                H:SetLaunchProtocol(nil) -- an explicit menu choice replaces the launch's temporary protocol override
                H:SetProtocolVersion(host, port, v)
                if s.id == H:GetEnabledServer() then TK.Login:ServerChanged() end
            end }
    end
    return { { name = "Servers", args = args } }
end

TK.ServersNode = { id = "servers", title = "Servers", order = 890, category = "general", noReset = true, loginOnly = true, machine = true, tabs = {},
    db = function() return {} end }

-- ----- the Library page (s6-library; the owner, 2026-10-01; login only) -----

-- The page's state: the server whose Library it shows (per server, head note 1; it starts on the login screen's server
-- each time the window opens), the character a character section's Clear is for ("" for every one), and the Clear
-- waiting for its confirmation. built: the tabs are made once per opening (they read the Library's file).
local library = { server = nil, character = "", pending = nil, built = false }
TK.LibraryPage = library

local function rebuildLibrary()
    TK.LibraryNode.tabs = TK.LibraryTabs()
    S:BuildPage()
end

--- After a read off the UI comes back: the Library's tabs again, and its page when it is the one shown (nothing before the
--- page was first built).
local function libraryReread()
    if not library.built then return end
    TK.LibraryNode.tabs = TK.LibraryTabs()
    if S.selected == TK.LibraryNode then S:BuildPage() end
end

--- A Clear button: the first press asks for a confirmation (the button says so), the second deletes what those trackers
--- recorded for the server (a character's part for the chosen character), and nothing else. The switches stay.
local function clearButton(key, label, ids, perCharacter)
    return { type = "execute", name = library.pending == key and ("Confirm: " .. label) or label,
        func = function()
            if library.pending ~= key then
                library.pending = key
            else
                library.pending = nil
                __tk:ClearLibrary(library.server, table.concat(ids, ","), perCharacter and library.character or "")
            end
            rebuildLibrary()
        end }
end

--- The server chooser, then each group of trackers: a row per tracker with its switch and its Clear, and below it what
--- relies on it. The map group has one Clear for all its data; the characters' Clears are for the character chosen.
function TK.LibraryTabs()
    library.server = library.server or TK.Library.DefaultServer()
    if library.server == nil then library.server, library.resolving = "", true end -- round 4: its address comes later
    local first = not library.built
    library.built = true
    local servers = {}
    local list = __tk:GetLibraryServers(first)
    for _, s in ipairs(list) do
        servers[#servers + 1] = { value = s.key, text = s.name == s.key and s.key or (s.name .. " (" .. s.key .. ")") }
    end
    -- Round 4 (review r3 finding 1): the folder's listing and the saved host names' addresses come in the background; the
    -- page is built again when they are there (and turns to the login screen's server once its address is known).
    if (list.pending or library.resolving) and not library.listing then
        library.listing = true
        TK.Library.Await(function()
            if __tk:GetLibraryServers(false).pending then return nil end
            if library.resolving then
                local key = TK.Library.DefaultServer()
                if key == nil then return nil end
                library.server, library.resolving = key, nil
            end
            return true
        end, function()
            library.listing = nil
            libraryReread()
        end)
    end
    local characters = { { value = "", text = "All characters" } }
    -- Round 3 (review r2 finding 1): the characters come from the server's Library file, read off the UI; until then the
    -- chooser has "All characters" only, and the page is built again when they are there.
    local names = __tk:GetLibraryCharacters(library.server)
    if names == nil and not library.reading then
        local reading = library.server
        library.reading = reading
        TK.Library.Await(function() return __tk:GetLibraryCharacters(reading) end, function()
            library.reading = nil
            libraryReread()
        end)
    end
    for name in string.gmatch(names or "", "[^\n]+") do
        characters[#characters + 1] = { value = name, text = name }
    end
    local args = {
        -- Round 18 (the owner: label and value; explanations in tooltips): the trackers' in their switches' tooltips.
        { type = "description", name = "What this client learned on each server. Clear deletes what one tracker recorded." },
        { type = "select", name = "Server", width = "full", values = servers,
          get = function() return library.server end,
          set = function(_, v)
              library.server, library.character, library.pending, library.resolving = v, "", nil, nil
              rebuildLibrary()
          end },
    }
    local groups, order = {}, {}
    for _, t in ipairs(__tk:GetLibraryTrackers(library.server)) do
        if not groups[t.group] then
            groups[t.group] = {}
            order[#order + 1] = t.group
        end
        table.insert(groups[t.group], t)
    end
    -- s6-library round 2 (head note 5): this server's Library to a file, and a file into it.
    args[#args + 1] = { type = "header", name = "Export and Import" }
    args[#args + 1] = { type = "execute", name = "Export...", func = function() TK.LibraryExchange:OpenExport(library.server) end }
    -- Round 18 (the owner): Import is also where the build's prebuilt Library comes from (library/exchange.lua).
    args[#args + 1] = { type = "execute", name = "Import...", func = function() TK.LibraryExchange:OpenImport(library.server) end }
    -- Round 12 (the owner's button): the build's tools\rebuild_cache.exe fills this server's Library and the map cache from
    -- the server's own files, in its own window; the page and the Library window read the file again when it is done.
    args[#args + 1] = { type = "execute", name = library.filling and "Filling..." or "Fill from server files...",
        desc = "Fills the Library and the map cache from the server's files, without playing: this build's own server, "
            .. "or the folder you choose for another. What you saw in play stays.",
        disabled = function() return library.filling ~= nil end,
        func = function()
            local server = library.server
            library.filling = server
            rebuildLibrary()
            -- s6-ui-core (round 126, the mega report's MC-UI-06): the Library is read again in C# before the job answers
            TK.Library.Await(__tk:FillLibraryFromServerFiles(server), function(problem)
                library.filling = nil
                if problem == "" then setStatus("Filled " .. server .. "'s Library and the map cache from the server's files")
                else setStatus("The Library was not filled: " .. problem, true) end
                local window = TK.Library
                if window.frame and window.frame:IsShown() and window.server == server then window:Refresh() end
                libraryReread()
            end)
        end }
    for _, g in ipairs(order) do
        args[#args + 1] = { type = "header", name = g }
        if g == "Maps" then
            local ids = {}
            for _, t in ipairs(groups[g]) do ids[#ids + 1] = t.id end
            args[#args + 1] = clearButton("maps", "Clear Map Data", ids, false)
            args[#args + 1] = { type = "break" }
        elseif g == "Your characters" then
            args[#args + 1] = { type = "select", name = "Clear For", values = characters,
                get = function() return library.character end,
                set = function(_, v)
                    library.character, library.pending = v, nil
                    rebuildLibrary()
                end }
            args[#args + 1] = { type = "break" }
        end
        for _, t in ipairs(groups[g]) do
            local id = t.id
            args[#args + 1] = { type = "toggle", name = t.title, desc = t.explanation,
                get = function() return __tk:LibraryTrackerOn(library.server, id) end,
                set = function(_, v) __tk:SetLibraryTracker(library.server, id, v and true or false) end }
            if t.records then args[#args + 1] = clearButton(id, "Clear " .. t.title, { id }, t.perCharacter) end
            args[#args + 1] = { type = "break" } -- round 18: a row a tracker, its Clear beside it (or nothing)
        end
    end
    return { { name = "Library", args = args } }
end

TK.LibraryNode = { id = "library", title = "Library", order = 892, category = "general", noReset = true, loginOnly = true, machine = true, tabs = {},
    db = function() return {} end }

--- Each opening of the window starts on the login screen's server, with the Library read again.
function TK.LibraryPageReset()
    library.server, library.character, library.pending, library.built, library.resolving = nil, "", nil, false, nil
end

-- ----- the Profiles page (AceDB-style profile options) -----

local function profileValues(excludeCurrent)
    local values = {}
    for _, name in ipairs(TK.DB:List()) do
        -- s6-modular-g (interfaces, phase 2): only the active interface's profiles
        if not (excludeCurrent and name == TK.DB.name) and TK.Interfaces:IsActiveProfile(name) then
            values[#values + 1] = { value = name, text = name }
        end
    end
    return values
end

local pendingDelete

TK.ProfilesNode = {
    id = "profiles",
    title = "Profiles",
    order = 1000,
    category = "general",
    noReset = true, -- the profiles themselves are the player's data
    db = function() return {} end,
    tabs = {
        {
            name = "Profiles",
            args = {
                { type = "description", name = "Settings and frame positions are saved per profile. Choose the active profile, create a new one, copy another profile's settings into this one, or reset it to the defaults." },
                { type = "description", name = function() return "Current profile: " .. TK.DB.name end },
                { type = "select", name = "Existing Profiles", values = function() return profileValues(false) end,
                  get = function() return TK.DB.name end,
                  set = function(_, v) TK.DB:Switch(v) end },
                { type = "input", name = "New Profile",
                  set = function(_, text)
                      local ok, err = TK.DB:Create(text)
                      if not ok then UIErrorsFrame:AddMessage(err) end
                  end },
                { type = "header", name = "Copy and Reset" },
                { type = "select", name = "Copy From", values = function() return profileValues(true) end,
                  get = function() return nil end,
                  set = function(_, v) TK.DB:CopyFrom(v) end },
                { type = "execute", name = "Reset Profile", func = function() TK.DB:Reset() end },
                { type = "header", name = "Delete" },
                { type = "select", name = "Delete a Profile", values = function() return profileValues(true) end,
                  get = function() return pendingDelete end,
                  set = function(_, v) pendingDelete = v end },
                { type = "execute", name = "Delete Selected",
                  disabled = function() return pendingDelete == nil end,
                  func = function()
                      if pendingDelete then TK.DB:Delete(pendingDelete) end
                      pendingDelete = nil
                  end },
            },
        },
    },
}
