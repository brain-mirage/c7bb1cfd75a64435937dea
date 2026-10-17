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

local S = { selected = nil, tabIndex = 1, focused = false } -- focused: S:HasFocus's
TK.Settings = S

local WIDTH, HEIGHT = 810, 600
local TREE_W = 226

-- The list's tabs, in their order; a node's category names one.
S.categories = {
    { id = "general", title = "General" },
    { id = "interface", title = "Interface" },
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
-- (components/menubutton: a shared panel since this round), so it has no place in this list any more.
GENERAL_ORDER.localserver = 1.5 -- s6-play-modes: the Local Server page (core/localserver.lua), right after Servers

local function categoryOf(node) return node.category or "interface" end

-- s6-ui-settings: a node with tabs is a page; one without is a title only (the header's "nested settings menus").
local function isPage(node) return node ~= nil and node.tabs ~= nil end

--- The first page among a tree's entries (S:Tree) and under them, depth first: what a tab or a title opens on.
local function firstPage(entries)
    for _, e in ipairs(entries) do
        if isPage(e.node) then return e.node end
        local page = firstPage(e.children)
        if page then return page end
    end
end

local frame, treeScroll, treeContent, categoryBar, tabBar, pageScroll, pageContent, status, lockCheck, buttonLockCheck
local bindingRows -- the binding rows' own frame (placeBindingRows)
local resetButton, resetAsk
local requestMarker
local keyMarker -- s6-ui-core (round 80): F8's music request outside the window (S:OpenMusic)
local build

--- s6-ui-bars: the status line's text, grey, or red for an error (the Key Bindings page's "Function is Now Unbound!").
local function setStatus(text, err)
    if err then status:SetTextColor(1, 0.25, 0.25) else status:SetTextColor(0.75, 0.75, 0.75) end
    status:SetText(text)
end
local musicBlocker, musicOpen, musicWanted, musicSeen, musicPart, musicLevel
local musicOk   -- the music dialog's window whose OK a control leaving the Sound page pressed (S:LeavesMusic)

-- ----- widget pools (frames are never destroyed, so page widgets are reused) -----

local pools = { oneof = {}, toggle = {}, range = {}, select = {}, execute = {}, header = {}, input = {}, description = {},
                binding = {}, bindingHeading = {}, orderlist = {}, namelist = {}, stylechoice = {} } -- s6-ui-core (round 54)
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
                if not same(argValue(node, a), d) then setArg(node, a, d) end
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
    if not resetAsk then
        resetAsk = W.PopupPanel(W.Panel(UIParent, "TKSettingsResetAsk")) -- s6-ui-core (round 56; the head's note): solid, a popup
        resetAsk:SetFrameStrata("FULLSCREEN_DIALOG")
        resetAsk:SetSize(420, 116)
        resetAsk:EnableMouse(true)
        resetAsk.title = W.Label(resetAsk, "Reset to defaults", 15, W.gold)
        resetAsk.title:SetPoint("TOP", resetAsk, "TOP", 0, -14)
        resetAsk.text = W.Label(resetAsk, "", 12, W.white)
        resetAsk.text:SetWidth(390)
        resetAsk.text:SetWordWrap(true)
        resetAsk.text:SetPoint("TOP", resetAsk.title, "BOTTOM", 0, -8)
        local function button(name, text, x, onClick)
            local b = W.Button(resetAsk, text, 120, 24, nil, function()
                resetAsk:Hide()
                onClick()
            end)
            b:SetPoint("BOTTOM", resetAsk, "BOTTOM", x, 14)
            _G[name] = b
            return b
        end
        resetAsk.tab = button("TKSettingsResetTab", "This tab", -130, function()
            S:Reset(resetAsk.node, { resetAsk.node.tabs[resetAsk.tabIndex] })
        end)
        resetAsk.page = button("TKSettingsResetPage", "The whole page", 0, function() S:Reset(resetAsk.node, resetAsk.node.tabs) end)
        resetAsk.cancel = button("TKSettingsResetCancel", "Cancel", 130, function() end)
        TK.Escape:AddWindow(resetAsk, function() resetAsk:Hide() end)
    end
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
    local m = CreateFrame("Button", nil, owner)
    m.label = W.Label(m, text, 12, colour)
    m.label:SetPoint("LEFT", m, "LEFT", 0, 0)
    m:SetSize(m.label:GetStringWidth() + 2, 16)
    m:EnableMouse(true)
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

local TEXT_COLOUR = { 0.85, 0.85, 0.85 } -- a line of text's (builders.description)

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

local INDENT = 20 -- a sub-feature's step in (indent)

local builders = {}

function builders.header(node, arg, width)
    local h = acquire("header", function() return W.Header(pageContent, "", width) end)
    h:SetWidth(width)
    h.label:SetText(arg.name)
    return h, 30
end

function builders.toggle(node, arg)
    local c = acquire("toggle", function()
        local box = W.Check(pageContent, "")
        -- s6-ui-core: a box that stands for one of a dialog's controls (the music dialog's effects radio) hands its press
        -- and release to that dialog (arg.pointer), as the original's control took them.
        box:HookScript("OnMouseDown", function(_, button) if box.pointer then box.pointer(true, button, box) end end)
        box:HookScript("OnMouseUp", function(_, button) if box.pointer then box.pointer(false, button, box) end end)
        return box
    end)
    c.pointer = arg.pointer
    c:SetLabel(arg.name)
    -- An option the original also sends (arg.action, an action kind) is attached to the box, and a change in the world
    -- runs it (plan 5.9).
    TK.Actions:SetTable(c, arg.action and { kind = arg.action } or nil)
    c.onChange = function(on)
        setArg(node, arg, on)
        if arg.action and TK.GameState:InWorld() then TK.Actions:RunFrozen() end
    end
    return c, 34
end

-- s6-ui-core (round 60): every range is the one slider (W.Slider); one with handles has a value a handle, each set as an
-- arg of its own (a handle moved pushes others: each that changed), and its handles' check boxes their own keys.
-- s6-ui-core (round 62; the head's note view-distance-row): a check box's tooltip is its arg's desc; the arg's
-- togglesBeside puts the boxes right of the track, and its stop may have onlyWithout (the slider's options, W.Slider).
function builders.range(node, arg, width)
    local s = acquire("range", function() return W.Slider(pageContent, "", 0, 1, 0, width) end)
    s:SetWidth(width)
    local opts, set = { gap = arg.gap, stop = arg.stop, togglesBeside = arg.togglesBeside,
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
    s:Configure(arg.name, arg.min, arg.max, arg.step, set, opts)
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

function builders.select(node, arg, width)
    local d = acquire("select", function() return W.Dropdown(pageContent, "", {}, width) end)
    d:SetWidth(width)
    d:Configure(arg.name, resolveValues(node, arg), function(v) setArg(node, arg, v) end)
    return d, 56
end

--- A setting offered as mutually exclusive buttons, with the same get/set/reset and needs as other rows.
function builders.oneof(node, arg, width)
    local f = acquire("oneof", function() return W.OneOf(pageContent, "", width) end)
    f:SetWidth(width)
    f:Configure(arg.name, resolveValues(node, arg), function(v) setArg(node, arg, v) end)
    return f, 54
end

-- s6-ui-core (round 54; the owner, 2026-10-05, Asset Styles: "Choosing Custom shows two dropdowns side by side right under
-- that setting, each as wide as its longest word ... Switching back to Modern or Retro hides them"): a select whose value
-- arg.extrasWhen shows small selects under it, side by side (arg.extras: { key, values }, in the same settings table),
-- each as wide as its longest choice; one that would pass the column's edge starts a new line (Astra's pass 3: the
-- head's Fallback made three, wider than a column). The page is laid out again when they show or hide (S:RefreshPage).
local probe
local function fitWidth(values)
    probe = probe or W.Label(pageContent, "", 12, W.white)
    probe:Hide()
    local most = 0
    for _, v in ipairs(values) do
        probe:SetText(v.text)
        most = math.max(most, probe:GetStringWidth())
    end
    return math.floor(most + 36) -- the field's padding and its arrow
end

function builders.stylechoice(node, arg, width)
    local f = acquire("stylechoice", function()
        local f = CreateFrame("Frame", nil, pageContent)
        f.main = W.Dropdown(f, "", {}, width)
        f.main:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.title = f.main.title -- the page's title (its (!), S:Widget's callers)
        f.extras = {}
        return f
    end)
    f:SetWidth(width)
    f.main:SetWidth(width)
    f.main:Configure(arg.name, resolveValues(node, arg), function(v) setArg(node, arg, v) end)
    local open = argValue(node, arg) == arg.extrasWhen
    local x, line = 0, 0
    for i, e in ipairs(arg.extras or {}) do
        local d = f.extras[i]
        if not d then
            d = W.Dropdown(f, "", {}, 80)
            f.extras[i] = d
        end
        local w = fitWidth(e.values)
        if x > 0 and x + w > width then x, line = 0, line + 1 end
        d:SetWidth(w)
        d:Configure("", e.values, function(v) setArg(node, { key = e.key }, v) end)
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", f, "TOPLEFT", x, -26 - line * 28)
        d:SetShown(open)
        x = x + w + 6
    end
    for i = #(arg.extras or {}) + 1, #f.extras do f.extras[i]:Hide() end
    f.open = open
    local lines = open and #(arg.extras or {}) > 0 and line + 1 or 0
    f:SetHeight(46 + lines * 28)
    return f, 56 + lines * 26
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
    local row = CreateFrame("Button", nil, f)
    row:SetHeight(ROW_H - 2)
    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetAllPoints(row)
    row.sel:SetColorTexture(0.25, 0.45, 0.9, 0.45)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetColorTexture(1, 1, 1, 0.08)
    row.box = W.Check(row, "")
    row.box:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", row, "LEFT", 34, 0)
    row.text = W.Label(row, "", 13, W.white, "LEFT")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.grip = W.Label(row, "=", 14, { 0.6, 0.6, 0.6 }, "RIGHT")
    row.grip:SetPoint("RIGHT", row, "RIGHT", -8, 0)
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
        local f = CreateFrame("Frame", nil, pageContent)
        f.rows = {}
        f.line = f:CreateTexture(nil, "OVERLAY")   -- where a dragged row would go
        f.line:SetColorTexture(1, 0.82, 0, 0.9)
        f.line:SetHeight(2)
        f.line:Hide()
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

--- The Up and Down keys move the list's chosen row while the window shows it (core/bindings.lua asks, after a dialog that
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
    local row = CreateFrame("Frame", nil, f)
    row:SetHeight(NAME_ROW - 4)
    row.box = W.EditBox(row, 200, 22)
    row.box:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.remove = W.Button(row, "Remove", 80, 22)
    row.remove:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    f.rows[i] = row
    return row
end

function builders.namelist(node, arg, width)
    local f = acquire("namelist", function()
        local f = CreateFrame("Frame", nil, pageContent)
        f.rows = {}
        f.title = W.Label(f, "", 13, W.gold, "LEFT")
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.none = W.Label(f, "None yet.", 12, { 0.6, 0.6, 0.6 }, "LEFT")
        f.add = W.EditBox(f, 200, 22)
        f.addButton = W.Button(f, "Add", 80, 22)
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
        f.add:SetScript("OnEnterPressed", function() f:AddName() end)
        f.addButton:SetScript("OnClick", function() f:AddName() end)
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
                row.box:SetScript("OnEnterPressed", function(box) box:ClearFocus() commit() end)
                row.box:SetScript("OnEditFocusLost", function() commit() end)
                row.remove:SetScript("OnClick", function() self:Change(function(l) table.remove(l, i) end) end)
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

function builders.execute(node, arg)
    local b = acquire("execute", function() return W.Button(pageContent, "", 200, 24) end)
    b:SetText(arg.name)
    b:SetWidth(math.max(160, b:GetFontString():GetStringWidth() + 30))
    b:SetScript("OnClick", function()
        TK.SafeCall(arg.func, node)
        S:RefreshPage()
    end)
    return b, 34
end

function builders.input(node, arg, width)
    local f = acquire("input", function()
        local f = CreateFrame("Frame", nil, pageContent)
        f:SetSize(width, 46)
        f.title = W.Label(f, "", 13, W.gold)
        f.title:SetPoint("TOP", f, "TOP", 0, 0)
        f.box = W.EditBox(f, width, 22)
        f.box:SetPoint("TOP", f, "TOP", 0, -18)
        return f
    end)
    f:SetWidth(width)
    f.box:SetWidth(width)
    f.title:SetText(arg.name)
    if arg.live then
        -- Keeps its text, set as it is typed (a form's field: Tab moves on, a button takes them all).
        f.box:SetText(arg.get and tostring(arg.get(node) or "") or "")
        f.box:SetScript("OnTextChanged", function(self, user) if user then setArg(node, arg, self:GetText()) end end)
        f.box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        return f, 50
    end
    f.box:SetText("")
    f.box:SetScript("OnTextChanged", nil)
    f.box:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        self:ClearFocus()
        if text ~= "" then setArg(node, arg, text) end
        self:SetText("")
    end)
    return f, 50
end

function builders.description(node, arg, width)
    local f = acquire("description", function()
        local f = CreateFrame("Frame", nil, pageContent)
        f.text = W.Label(f, "", 12, TEXT_COLOUR, "LEFT")
        f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.text:SetWordWrap(true)
        return f
    end)
    f.text:SetWidth(width)
    local text = type(arg.name) == "function" and arg.name(node) or arg.name
    f.text:SetText(text)
    local h = f.text:GetStringHeight()
    f:SetSize(width, h)
    -- s6-ui-core (round 54; the owner: a line "ends with a ? that shows a short tooltip on hover"): a one-line help
    if arg.help then
        if not f.help then f.help = titleMark(f, "?", W.gold) end
        f.help:ClearAllPoints()
        f.help:SetPoint("TOPLEFT", f, "TOPLEFT", math.min(f.text:GetStringWidth(), width - 16) + 6, 1)
        f.help.lines = { arg.help }
        f.help:Show()
    elseif f.help then
        f.help:Hide()
    end
    return f, h + 8
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
    local f = CreateFrame("Frame", nil, bindingRows)
    f:SetHeight(26)
    f.label = W.Label(f, "", 12, W.white, "LEFT")
    f.label:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.keys = {}
    -- The owner's hotfix (2026-10-06): "a checkbox to the right of all keybinds", Global (its heading over the column,
    -- not by each one): the command keeps these keys in every interface (TK.Bindings:SetGlobal).
    f.global = W.Check(f, "", function(on)
        TK.Bindings:SetGlobal(f.arg.command, on, function() S:RefreshPage() end)
        S:RefreshPage()
    end)
    f.global:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.global:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Global: the same keys in every interface.", 1, 1, 1)
        GameTooltip:Show()
    end)
    f.global:HookScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
    for slot = 1, 2 do
        local b = W.Button(f, "", 124, 22)
        b:GetFontString():SetFont(11, "")
        b:SetPoint("RIGHT", f, "RIGHT", slot == 1 and -160 or -30, 0)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")
        b:EnableMouseWheel(true)
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
        local f = CreateFrame("Frame", nil, pageContent)
        f:SetHeight(18)
        f.command = W.Label(f, "Command", 12, W.gold, "LEFT")
        f.command:SetPoint("LEFT", f, "LEFT", 0, 0)
        f.key1 = W.Label(f, "Key 1", 12, W.gold)
        f.key1:SetPoint("CENTER", f, "RIGHT", -222, 0)
        f.key2 = W.Label(f, "Key 2", 12, W.gold)
        f.key2:SetPoint("CENTER", f, "RIGHT", -92, 0)
        f.global = W.Label(f, "Global", 12, W.gold) -- the owner's hotfix (2026-10-06): the Global column
        f.global:SetPoint("CENTER", f, "RIGHT", -12, 0)
        return f
    end)
    f:SetWidth(width)
    return f, 22
end

--- Updates every widget's value and enabled state from the db (after any change).
function S:RefreshPage()
    local node = self.selected
    if not node then return end
    local relayout = false -- s6-ui-core (round 44): a name list's rows changed
    local keys -- every command's keys, taken once for the page's binding rows (s6-optimize round 9)
    for _, pw in ipairs(pageWidgets) do
        local w, arg = pw[1], pw[2]
        local disabled = argDisabled(node, arg)
        if arg.type == "toggle" then
            w:SetChecked(argValue(node, arg) and true or false)
            w:SetLabelEnabled(not disabled)
            showNeeds(node, w, arg, disabled) -- s6-ui-core (round 54): its (!)
        elseif arg.type == "range" or arg.type == "dualrange" then -- s6-ui-core (round 60): the one slider
            -- the handles shown first (round 62: a stop that goes with a handle off places the values)
            for i, h in ipairs(arg.handles or {}) do
                if h.toggle then w:SetHandleShown(i, argValue(node, h.toggle) and true or false) end
            end
            w:SetValue(rangeValues(node, arg))
            w:SetEnabled(not disabled)
            showNeeds(node, w, arg, disabled)
        elseif arg.type == "oneof" then
            w:SetValue(argValue(node, arg))
            w:SetEnabled(not disabled)
            showNeeds(node, w, arg, disabled)
            w:SetGreyed(w.needsGreyed or disabled)
        elseif arg.type == "select" then
            w:SetValues(resolveValues(node, arg))
            w:SetValue(argValue(node, arg))
            w:SetEnabled(not disabled)
            showNeeds(node, w, arg, disabled)
        elseif arg.type == "input" then
            w.box:SetEnabled(not disabled) -- s6-ui-core (round 60): a need that disables
            local c = disabled and W.grey or W.gold
            w.title:SetTextColor(c[1], c[2], c[3], 1)
            showNeeds(node, w, arg, disabled)
        elseif arg.type == "header" or arg.type == "description" then
            -- s6-ui-core (round 60): a header or a line of text greyed by a need that disables it, or its (!)
            if arg.type == "description" and type(arg.name) == "function" then w.text:SetText(arg.name(node)) end
            local c = disabled and W.grey or titleColour(arg)
            titleOf(w, arg):SetTextColor(c[1], c[2], c[3], 1)
            showNeeds(node, w, arg, disabled)
        elseif arg.type == "stylechoice" then
            -- s6-ui-core (round 54): its small choices shown or hidden: the page laid out again
            w.main:SetValues(resolveValues(node, arg))
            w.main:SetValue(argValue(node, arg))
            for i, e in ipairs(arg.extras or {}) do w.extras[i]:SetValue(nodeDB(node)[e.key]) end
            if (argValue(node, arg) == arg.extrasWhen) ~= w.open then relayout = true end
        elseif arg.type == "execute" then
            w:SetEnabled(not disabled)
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
    if relayout then return self:BuildPage(true) end
    lockCheck:SetChecked(not TK.EditMode.unlocked)
    buttonLockCheck:SetChecked(TK.DB:Global().buttonLock and true or false)
    -- Edit mode needs the world; on the login screen it is greyed out. The Key Bindings list is there at the login too.
    local inWorld = TK.GameState:InWorld()
    lockCheck:SetLabelEnabled(inWorld)
end

--- s6-library round 18 (the owner: an explanation a player needs goes "in a hover tooltip, not on the page"): an
--- option's desc shows as its control's tooltip (W.Tip: s6-ui-core round 57; a pooled control's is cleared by nil).
local optionTip = W.Tip

--- keepScroll (s6-ui-core, round 44): the same page laid out again, where it was scrolled to (a name list's rows changed).
function S:BuildPage(keepScroll)
    local scrolled = keepScroll and pageScroll:GetVerticalScroll() or nil
    -- A key box waiting for a key belongs to the page being replaced (review R2.3).
    TK.KeyBindMode:CancelCapture()
    releaseAll()
    U.Wipe(pageWidgets)
    U.Wipe(pageHides)
    local node = self.selected
    if not node then return end
    local tabs = node.tabs or {}
    local tab = tabs[self.tabIndex] or tabs[1]
    if not tab then return end

    local pad = 16
    local total = pageScroll:GetWidth() - pad * 2
    local colW = math.floor((total - pad) / 2)
    local x, y, col, rowH = pad, -12, 0, 0

    local function newRow()
        if col > 0 then
            y = y - rowH
            col, rowH = 0, 0
        end
    end

    -- s6-ui-core (round 60): whether an arg is left off, noted for RefreshPage when it could change
    local function hides(a, db)
        local hidden = argHidden(node, a, db)
        if a.hidden or a.requires then pageHides[#pageHides + 1] = { a, hidden } end
        return hidden
    end

    local rows = {} -- s6-ui-core (round 60): the groups opened, each grouped row as its view
    walk(tab.args, function(a) rows[#rows + 1] = a end)
    for _, arg in ipairs(rows) do
        local db = nodeDB(node)
        if arg.type == "break" then
            newRow()
        elseif arg.type == "row" then
            -- s6-interface-5x (round 12): controls side by side on one row, each its own width (arg.args; a control's
            -- rowWidth, else a column's), the check boxes and buttons level with a dropdown's box below its title
            newRow()
            local rx, rh = pad + (arg.indent or 0) * INDENT, 0 -- s6-ui-core (round 60): in a group, its steps in
            for _, a in ipairs(arg.args) do
                if not hides(a, db) and builders[a.type] then
                    local cw = a.rowWidth or colW
                    local w, h = builders[a.type](node, a, cw)
                    optionTip(w, a.desc)
                    w:SetPoint("TOPLEFT", pageContent, "TOPLEFT", rx, y - (a.type == "select" and 0 or 22))
                    pageWidgets[#pageWidgets + 1] = { w, a }
                    rx = rx + (a.rowWidth or (a.type == "select" and cw) or w:GetWidth()) + pad
                    rh = math.max(rh, h + (a.type == "select" and 0 or 22))
                end
            end
            y = y - rh
        elseif not hides(arg, db) then
            local full = arg.type == "header" or arg.type == "description" or arg.type == "binding"
                or arg.type == "bindingHeading" or arg.type == "orderlist" or arg.type == "namelist" or arg.width == "full"
            -- s6-ui-core (round 60): an indented control is on a row of its own, its steps in
            local own, inset = arg.indent ~= nil, (arg.indent or 0) * INDENT
            if full or own then newRow() end
            local width = full and (total - inset) or colW
            local build = builders[arg.type]
            if build then
                local w, h = build(node, arg, width)
                -- s6-library round 18. s6-ui-core (round 52; Astra's review): an input's box takes the pointer, not its
                -- frame (a hover does not reach the parent), so the box carries the tip.
                optionTip(arg.type == "input" and w.box or w, arg.desc)
                local wx = (full or own) and (pad + inset) or (pad + col * (colW + pad))
                -- Check boxes sit at the left of their column; everything else fills it.
                w:SetPoint("TOPLEFT", pageContent, "TOPLEFT", wx, y - (arg.type == "toggle" and 6 or 0))
                pageWidgets[#pageWidgets + 1] = { w, arg }
                if full or own then
                    y = y - h
                else
                    rowH = math.max(rowH, h)
                    col = col + 1
                    if col >= 2 then newRow() end
                end
            end
        end
    end
    newRow()
    placeBindingRows(#pools.binding < bindingRowsMade) -- out of the window unless a row is in use (s6-optimize round 10)
    pageContent:SetSize(pageScroll:GetWidth(), -y + 12)
    pageScroll:ScrollToTop()
    if scrolled then pageScroll:SetVerticalScroll(scrolled) end
    self:RefreshPage()
end

--- The widget showing an option on the open page, by the option's name (for tests); s6-sandbox (round 11): or its id,
--- for an option whose name is a function.
function S:Widget(name)
    for _, pw in ipairs(pageWidgets) do
        if pw[2].name == name or pw[2].id == name then return pw[1] end
    end
end

--- The status line's text (what the last change did).
function S:StatusText() return status and status:GetText() or "" end

--- Scrolls the page so a widget is at its top (the Key Bindings page is long; tests and scripts).
function S:ScrollTo(widget)
    local _, _, _, _, y = widget:GetPoint(1)
    pageScroll:SetVerticalScroll(math.max(0, -(y or 0) - 8))
end

--- Sets an option exactly as its widget would (used by tests and scripts): finds the node's arg by key or name.
function S:SetOption(nodeId, keyOrName, value)
    local node = self:FindNode(nodeId)
    if not node then return false end
    for _, tab in ipairs(node.tabs or {}) do
        -- s6-interface-5x (round 12): a row's controls are found by their own names (BuildPage's "row")
        for _, a in ipairs(controls(tab)) do
            if a.key == keyOrName or a.name == keyOrName then
                if not status then build() end
                setArg(node, a, value)
                return true
            end
        end
    end
    return false
end

-- ----- tabs -----

local tabButtons = {}

function S:BuildTabs()
    for _, b in ipairs(tabButtons) do b:Hide() end
    local node = self.selected
    if resetButton then resetButton:SetShown(self:CanReset(node)) end
    if not node then return end
    local x = 10
    for i, tab in ipairs(node.tabs or {}) do
        local b = tabButtons[i]
        if not b then
            b = W.Tab(tabBar, "", 24, 24) -- s6-ui-core (round 61): the shared tab (core/widgets.lua)
            tabButtons[i] = b
        end
        b:SetText(tab.name)
        local w = b:GetFontString():GetStringWidth() + 34
        b:SetSize(w, 24)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMLEFT", x, 0)
        x = x + w + 4
        b:SetSelected(i == self.tabIndex)
        b:SetScript("OnClick", function()
            self.tabIndex = i
            self:BuildTabs()
            self:BuildPage()
        end)
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

local categoryButtons = {}

--- The list's tabs, small, above its first row: one per category with a page here (the gate's names are
--- TKSettingsTab:<category>). A category with none, at the login screen, is hidden.
function S:BuildCategoryTabs(all)
    all = all or self:Nodes()
    local shownTabs = {}
    for i, c in ipairs(self.categories) do
        local b = categoryButtons[i]
        if not b then
            b = W.Tab(categoryBar, c.title, nil, nil, function() S:ShowCategory(c.id) end,
                { name = "TKSettingsTab:" .. c.id, size = 11 }) -- s6-ui-core (round 61): the shared tab
            self:LeavesMusic(b, function() return S:LeavesMusicFor(S:CategoryTarget(c.id)) end)
            categoryButtons[i] = b
        end
        local target = self:CategoryTarget(c.id, all)
        -- The page the click shows carries its request on the tab too (D20, as its row; Astra's review): Sound reopened
        -- through General asks as its row does.
        TK.Actions:Set(b, target and target.request)
        local shown = target ~= nil
        b:SetShown(shown)
        if shown then
            shownTabs[#shownTabs + 1] = b
            b:SetSelected(c.id == self.category)
        end
    end
    if #shownTabs == 0 then return end
    -- s6-modular (round 16): the tabs fit the list's width (four in the game with the Experimental tab): their padding
    -- shrinks from 20 to 6, then their text from 11 to 9.
    local room = TREE_W - 10 - 3 * (#shownTabs - 1)
    local size, pad = 11, 20
    while true do
        local text = 0
        for _, b in ipairs(shownTabs) do
            b:GetFontString():SetFont(size, "")
            text = text + b:GetFontString():GetStringWidth()
        end
        pad = math.min(20, math.floor((room - text) / #shownTabs))
        if pad >= 6 or size <= 9 then break end
        size = size - 1
    end
    local x = 2
    for _, b in ipairs(shownTabs) do
        local w = b:GetFontString():GetStringWidth() + math.max(pad, 6)
        b:SetSize(w, 20)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", categoryBar, "BOTTOMLEFT", x, 0)
        x = x + w + 3
    end
end

--- The page a list tab's click shows: the row last open there (kept in the profile), else its first page; nil when the
--- tab has none here (from all, the pages here, when the caller has them).
function S:CategoryTarget(category, all)
    local kept = TK.DB:Global().settingsRows[category]
    for _, n in ipairs(self:CategoryNodes(category, all)) do
        if n.id == kept and isPage(n) then return n end
    end
    return firstPage(self:Tree(category, all))
end

function S:ShowCategory(category)
    local node = self:CategoryTarget(category)
    if node then self:Select(node.id, nil, true) end   -- the tab's row last open: the closed entries stay closed
end

-- ----- the tree -----

local treeButtons = {}
S.treeButtons = treeButtons -- tests: the tree's rows (and S.treeScroll, set when the window is built)

function S:Nodes()
    local all, inWorld = TK.Components:AllNodes(), TK.GameState:InWorld()
    TK.KeyBindingsNode.tabs = TK.KeyBindingTabs()
    -- s6-optimize (round 7's note): the login-only pages' tabs only at the login screen, where they are listed.
    if not inWorld then TK.ServersNode.tabs = TK.ServerTabs() end
    if not TK.LibraryPage.built and not inWorld then TK.LibraryNode.tabs = TK.LibraryTabs() end -- s6-library
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
    local nodes = {}
    for _, n in ipairs(all) do
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

--- The page an entry opens on (S:Select): a shown page itself; a shown title's first page (a title with one page: that
--- page); for an entry not shown, or a shown title with no shown page under it, the nearest entry above it that has
--- one, the same way (Astra's review of round 17). nil if none.
local function pageFor(e, byId)
    while e do
        local page = e.visible and (isPage(e.node) and e.node or firstPage(e.children))
        if page then return page end
        e = e.node and byId[e.node.parent]
    end
end

--- The page a title's click shows: its first page (s6-ui-core round 54; the owner, 2026-10-05: "clicking the header for
--- an item with subpages automatically selects the top-level subpage under it"; before, a title with one child only).
local function titlePage(e) return firstPage(e.children) end

--- Opens or closes an entry's children (its + / - button). The closed ones are kept in the profile with the tab and the
--- rows last open, so the list looks the same at the next opening.
function S:SetExpanded(id, open)
    local closed = TK.DB:Global().settingsCollapsed
    if (closed[id] == true) ~= open then return end
    closed[id] = (not open) or nil
    TK.DB:MarkDirty()
end

local ROW_STEP, INDENT = 19, 12

--- A list row, recycled: its selection band, its + / - button and its text. BuildTree sets its entry and its target (the
--- page its click shows) each time.
local function newRow(i)
    local b = CreateFrame("Button", nil, treeContent)
    b:SetHeight(ROW_STEP)
    -- Wire: a press that leaves the Sound page (a row showing another page) is the music dialog's control 14, its OK,
    -- which 4a's MusicControlDialog::OnControlCommand (0x00529790) answers with CloseDialog. The close sends nothing,
    -- but it is what lets the Sound page's next opening build the dialog again (MusicControlDialog::MusicControlDialog,
    -- 0x00528E60), which sends 1B 01 00. Changing which rows press it changes the 1B the server sees, and when.
    S:LeavesMusic(b, function() return S:LeavesMusicFor(b.target) end)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints(b)
    b.sel:SetTexture("tk:gradient-h")
    b.sel:SetTexCoord(1, 0, 0, 1)
    b.sel:SetVertexColor(0.25, 0.45, 0.9, 0.85)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetColorTexture(1, 1, 1, 0.1)
    b.text = W.Label(b, "", 12, W.white, "LEFT")
    -- The + / - button: a button of its own on the row, so its click opens or closes the entry and shows no page.
    b.expander = CreateFrame("Button", nil, b)
    b.expander:SetSize(14, 14)
    b.expander.label = W.Label(b.expander, "-", 14, W.gold)
    b.expander.label:SetPoint("CENTER", b.expander, "CENTER", 0, 1)
    local eh = b.expander:CreateTexture(nil, "HIGHLIGHT")
    eh:SetAllPoints(b.expander)
    eh:SetColorTexture(1, 1, 1, 0.15)
    b.expander:SetScript("OnClick", function()
        S:SetExpanded(b.entry.id, TK.DB:Global().settingsCollapsed[b.entry.id] == true)
        S:BuildTree()
    end)
    b:SetScript("OnClick", function() if b.target then S:Select(b.target.id) end end)
    treeButtons[i] = b
    return b
end

--- all: the pages here when the caller has them (S:Select lists them once per page change: s6-optimize's note).
function S:BuildTree(all)
    for _, b in ipairs(treeButtons) do b:Hide() end
    local closed = TK.DB:Global().settingsCollapsed
    local rows = {}
    local function add(entries, depth)
        for _, e in ipairs(entries) do
            rows[#rows + 1] = { entry = e, depth = depth }
            if not closed[e.id] then add(e.children, depth + 1) end
        end
    end
    add(self:Tree(self.category, all), 0)

    local y = -6
    for i, row in ipairs(rows) do
        local b = treeButtons[i] or newRow(i)
        local e, depth = row.entry, row.depth
        local page = isPage(e.node)
        b.entry = e
        b.target = page and e.node or titlePage(e)
        b.nodeId = page and e.node.id or nil   -- the gate's name for the row (gatecontrols.lua): the rows are recycled
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", treeContent, "TOPLEFT", 4, y)
        b:SetPoint("TOPRIGHT", treeContent, "TOPRIGHT", -4, y)
        local x = 2 + depth * INDENT
        b.expander:ClearAllPoints()
        b.expander:SetPoint("LEFT", b, "LEFT", x, 0)
        b.expander:SetShown(#e.children > 0)
        b.expander.label:SetText(closed[e.id] and "+" or "-")
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", b, "LEFT", x + 16, 0)
        b.text:SetText(e.title)
        W.Color(b.text, (depth == 0 or not page) and W.gold or W.white)
        b.sel:SetShown(page and self.selected ~= nil and self.selected.id == e.node.id)
        -- Wire (D20): the row's press carries the request of the page its click shows; C# freezes it at the press, and
        -- the page's marker runs it when the page shows. Only the Sound pages have one, open:music: in the world the
        -- page is the original's MusicControlDialog, and opening it builds the dialog, whose constructor (4a's
        -- MusicControlDialog::MusicControlDialog, 0x00528E60) sends 1B 01 00 (S:SetMusicDialog). A row that shows no
        -- page carries none. Changing which rows carry it changes when the server sees 1B 01 00.
        TK.Actions:Set(b, b.target and b.target.request)
        b:Show()
        y = y - ROW_STEP
    end
    treeContent:SetSize(TREE_W - 12, -y + 6)
    treeScroll.Refresh()
    self:BuildCategoryTabs(all)
end

function S:FindNode(id)
    for _, node in ipairs(self:Nodes()) do
        if node.id == id then return node end
    end
end

--- The first page of a list tab here, or of the first tab that has one.
function S:FirstNode(category, all)
    local node = firstPage(self:Tree(category, all))
    if node then return node end
    for _, c in ipairs(self.categories) do
        node = firstPage(self:Tree(c.id, all))
        if node then return node end
    end
end

--- Shows the page an entry's id names (any tab's entry: a page, a title node, or a title the tree made for a parent,
--- through pageFor), else the current tab's first page. restoring: the row last open is shown again (the window's
--- opening, a list tab's click, a profile or game state change), so the entries the player closed stay closed; any
--- other call is a shortcut to the page, and every entry above it opens so its row shows (Astra's round 16 review).
function S:Select(id, tabName, restoring)
    local all, node = self:Nodes(), nil
    -- s6-interface-5x (round 12): a shortcut to another interface's page shows that interface's list first, so the page's
    -- row is in the tree (the list holds only the shown interface's pages). Only the Interface tab's pages: a General page
    -- that is a panel's (Classic Commands) leaves the shown interface alone (Astra's s6-interface-5x-self-12-3).
    if not restoring then
        for _, n in ipairs(all) do
            if n.id == id then
                if categoryOf(n) == "interface" then TK.Panels:Reveal(n) end
                break
            end
        end
    end
    for _, c in ipairs(self.categories) do
        local _, byId = self:Tree(c.id, all)
        if byId[id] then
            node = pageFor(byId[id], byId)
            break
        end
    end
    node = node or self:FirstNode(self.category or TK.DB:Global().settingsTab, all)
    local changed = self.selected == nil or self.selected.id ~= node.id
    if changed then dismissReset() end
    self.selected = node
    -- The page's list tab shows, and the profile keeps it and its row for the next opening.
    self.category = categoryOf(node)
    -- s6-interface-5x (round 12): the Interface tab lists one interface's pages; a page of another shows that one first
    if self.category == "interface" then TK.Panels:Reveal(node) end
    local g = TK.DB:Global()
    if g.settingsTab ~= self.category or g.settingsRows[self.category] ~= node.id then
        g.settingsTab = self.category
        g.settingsRows[self.category] = node.id
        TK.DB:MarkDirty()
    end
    if tabName then
        for i, t in ipairs(node.tabs or {}) do
            if t.name == tabName then self.tabIndex = i end
        end
    elseif changed then
        -- Keep the same tab when moving between similar nodes (Bar 1 to Bar 2), as Bartender does.
        local tabs = node.tabs or {}
        if self.tabIndex > #tabs then self.tabIndex = 1 end
    end
    if not restoring then
        -- A shortcut to the page: its row shows, every entry above it opening.
        local _, byId = self:Tree(self.category, all)
        local p = node.parent
        while byId[p] do
            self:SetExpanded(p, true)
            p = byId[p].node and byId[p].node.parent
        end
        -- s6-interface-5x (round 11): and the Interface list's title above it (Panes or Decoration, core/panels.lua)
        if self.category == "interface" then
            for _, h in ipairs(TK.Panels:HeadingsOf(node)) do self:SetExpanded(h.id, true) end
        end
    end
    -- D20: a page that stands for one of the original's dialogs asks as that dialog did, each time the player opens it
    -- in the world: its marker frame carries the request and becomes visible with the page (and with the window).
    local music = node.request == "open:music" and TK.GameState:InWorld()
    if requestMarker then requestMarker:SetShown(music) end
    self:SetMusicDialog(music and frame ~= nil and frame:IsShown())
    self:BuildTree(all)
    if changed then self:RevealSelected() end -- s6-sandbox (round 10): the Plugins pages are at the tree's end
    self:BuildTabs()
    self:BuildPage()
end

--- s6-ui-settings (s6-peer's note): the list drawn again after a page changed which entries are shown (a node's
--- shown()); a selected page no longer shown gives way to the nearest shown entry above it.
function S:RefreshTree()
    if not self:IsOpen() then return end
    local _, byId = self:Tree(self.category)
    local e = self.selected and byId[self.selected.id]
    if e and e.visible then self:BuildTree() else self:Select(self.selected and self.selected.id, nil, true) end
end

--- s6-sandbox (round 10): scrolls the tree so the selected page's row shows (a page opened directly, deep in the tree).
function S:RevealSelected()
    for _, b in ipairs(treeButtons) do
        if b:IsShown() and b.sel:IsShown() then
            local _, _, _, _, y = b:GetPoint(1)
            local top, view = treeScroll:GetVerticalScroll(), treeScroll:GetHeight()
            if -y < top or -y + 19 > top + view then
                treeScroll:SetVerticalScroll(math.min(math.max(0, -y - view / 2), treeScroll:GetVerticalScrollRange()))
                treeScroll.Refresh()
            end
            return
        end
    end
end

-- ----- the window -----

function build()
    frame = W.Panel(UIParent, "TKSettingsFrame")
    -- s6-modular-g round 22: a wheel on Settings belongs to this window. Passing it to
    -- ArticleListPane::HandlePointerOrMouseEvent (0x00474EC0) below could send 3B 02;
    -- changing this changes what the server sees. Lists within Settings still receive theirs first.
    frame:EnableMouseWheel(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    -- An invisible child that carries the Sound page's request (D20, 1B 01 00): it becomes visible with that page, or
    -- with the window when it opens on that page.
    requestMarker = CreateFrame("Frame", "TKSettingsRequest", frame)
    requestMarker:Hide()
    TK.Actions:SetOpen(requestMarker, "open:music")
    -- s6-ui-core (round 80): the same request's marker outside the window, for F8 in the world (S:OpenMusic).
    keyMarker = CreateFrame("Frame", "TKMusicKeyRequest", UIParent)
    keyMarker:Hide()
    TK.Actions:SetOpen(keyMarker, "open:music")

    -- The title plate, dragged to move the window.
    local plate = W.Panel(frame, nil)
    plate:SetSize(220, 30)
    plate:SetPoint("CENTER", frame, "TOP", 0, 0)
    -- s6-ui-core (round 49; Astra's item 3): a little lighter than the window under it, as a window's title band.
    plate:SetBackdropColor(W.titleBand.color[1], W.titleBand.color[2], W.titleBand.color[3], 1)
    W.HudPanel(plate) -- s6-ui-core (round 53): with the window, at the UI transparency
    -- s6-ui-core (round 83; the owner, 2026-10-09: "The shared window is called Settings"): was "Nexus Interface"
    local title = W.Label(plate, "Settings", 15, W.white)
    title:SetPoint("CENTER", plate, "CENTER", 0, 0)
    plate:EnableMouse(true)
    plate:RegisterForDrag("LeftButton")
    plate:SetScript("OnDragStart", function() frame:StartMoving() end)
    plate:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    lockCheck = W.Check(frame, "Lock", function(on)
        if on then TK.EditMode:Lock() else TK.EditMode:Unlock() end
        S:RefreshPage()
    end)
    lockCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -26)

    buttonLockCheck = W.Check(frame, "Button Lock", function(on)
        TK.DB:Global().buttonLock = on
        TK.DB:MarkDirty()
        TK.FireEvent("TK_BUTTON_LOCK", on)
    end)
    buttonLockCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", TREE_W + 22, -26)

    -- s6-ui-core (round 31): the key-bindings list, as WoW's Key Bindings button opens it (round 54: the hover binding
    -- is Edit Mode's Keybinds).
    local keys = W.Button(frame, "Key Bindings", 190, 24, "red", function() S:Select("keybindings", "General") end)
    S:LeavesMusic(keys, function() return S.selected == nil or S.selected.id ~= "keybindings" end)
    keys:SetPoint("TOPLEFT", frame, "TOPLEFT", TREE_W + 190, -26)
    frame.keysButton = keys

    local tree = W.Panel(frame, nil, true)
    tree:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -58)
    tree:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 44)
    tree:SetWidth(TREE_W)
    -- The list's tabs (s6-ui-settings), above its first row, as the page's tabs sit above the page.
    categoryBar = CreateFrame("Frame", nil, tree)
    categoryBar:SetPoint("TOPLEFT", tree, "TOPLEFT", 4, -4)
    categoryBar:SetPoint("TOPRIGHT", tree, "TOPRIGHT", -4, -4)
    categoryBar:SetHeight(20)
    treeScroll, treeContent = W.ScrollArea(tree)
    S.treeScroll = treeScroll
    treeScroll:SetPoint("TOPLEFT", tree, "TOPLEFT", 3, -26)
    treeScroll:SetPoint("BOTTOMRIGHT", tree, "BOTTOMRIGHT", -9, 3)

    local right = W.Panel(frame, nil, true)
    right:SetPoint("TOPLEFT", frame, "TOPLEFT", TREE_W + 18, -58)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 44)

    tabBar = CreateFrame("Frame", nil, right)
    tabBar:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -6)
    tabBar:SetPoint("TOPRIGHT", right, "TOPRIGHT", -4, -6)
    tabBar:SetHeight(26)

    -- s6-ui-settings: the page's reset icon, at the top right on the tabs' line (S:AskReset).
    resetButton = CreateFrame("Button", "TKSettingsReset", right)
    resetButton:SetSize(20, 20)
    resetButton:SetPoint("TOPRIGHT", right, "TOPRIGHT", -10, -9)
    local icon = resetButton:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(resetButton)
    icon:SetTexture("tk:reset")
    icon:SetVertexColor(1, 0.82, 0, 1)
    local glow = resetButton:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(resetButton)
    glow:SetTexture("tk:reset")
    glow:SetVertexColor(1, 1, 1, 0.6)
    resetButton:SetHighlightTexture(glow)
    resetButton:SetScript("OnClick", function() S:AskReset() end)
    resetButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Reset to defaults", 1, 1, 1)
        GameTooltip:Show()
    end)
    resetButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    resetButton:Hide()

    local page = W.Panel(right, nil, true)
    page:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -32)
    page:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -8, 8)
    pageScroll, pageContent = W.ScrollArea(page)
    pageScroll:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -2)
    pageScroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -10, 2)
    -- The binding rows' frame starts out of the window (placeBindingRows); laid out over the page wherever it is.
    bindingRows = CreateFrame("Frame", nil, UIParent)
    bindingRows:SetAllPoints(pageContent)
    bindingRows:Hide()

    local bar = W.Panel(frame, nil, true)
    bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -130, 12)
    bar:SetHeight(24)
    status = W.Label(bar, "", 11, { 0.75, 0.75, 0.75 }, "LEFT")
    status:SetPoint("LEFT", bar, "LEFT", 8, 0)

    local close = W.Button(frame, "Close", 104, 24, "red", function()
        -- The music dialog's OK is its control 14: the model closes the dialog, and the page goes with it.
        if not (musicOpen and S:MusicWindow()) then S:Close() end
    end)
    S:LeavesMusic(close, function() return true end)   -- its press and release are the dialog's OK's
    close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame.closeButton = close
    frame.plate = plate
    TK.Escape:AddWindow(frame, function() S:Close() end)

    -- The music dialog's modality (S:SetMusicDialog): a blocker over the whole screen under the window.
    musicBlocker = CreateFrame("Frame", "TKMusicBlocker", UIParent)
    musicBlocker:SetFrameStrata("FULLSCREEN")
    musicBlocker:SetFrameLevel(1)
    musicBlocker:SetAllPoints(UIParent)
    musicBlocker:EnableMouse(true)
    musicBlocker:EnableMouseWheel(true)
    musicBlocker:Hide()
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
    frame:HookScript("OnHide", function() S.focused = false end) -- s6-input: closed, the game has the keys (S:HasFocus)
end

function S:Open(nodeId, tabName)
    if not frame then build() end
    -- Each opening of the window is a new one: the page's request goes when Select shows its marker (review r1
    -- finding 5); a window already open only changes page.
    if not frame:IsShown() then
        requestMarker:Hide()
        TK.LibraryPageReset() -- s6-library: the login screen's server, the Library read again
    end
    frame:Show()
    S.focused = true -- s6-input: an opened window has the focus (S:HasFocus)
    -- Always all on the screen, at any UI scale (review F5): shrunk if needed, and back on screen if it was off.
    TK.FitToScreen(frame, 10, 16)
    setStatus("Profile: " .. TK.DB.name)
    local g = TK.DB:Global()
    self:Select(nodeId or g.settingsRows[g.settingsTab], tabName, nodeId == nil)   -- no page named: the row last open
end

function S:Close()
    TK.KeyBindMode:CancelCapture()
    dismissReset()
    self:SetMusicDialog(false)
    if frame then frame:Hide() end
    W.CloseDropdowns()
end

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
--- part (components/dialogs/misc.lua's comment); a release off the page's control is -1, which clicks nothing. Changing the
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
--- it opens the Sound page, as before; at the login screen no game key acts (core/bindings.lua, atLogin), so F8 does
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

function S:Toggle()
    if frame and frame:IsShown() then self:Close() else self:Open() end
end

function S:IsOpen() return frame ~= nil and frame:IsShown() end

--- s6-input (the head's note of 2026-10-06; the owner: "when you are interacating with the settings page or things in it
--- directly, IE you clicked on the window (focused etc basically) it shouldnt be sending background commands"): whether
--- the window has the focus. It takes it when it opens and at a press on it or on what opened from it (its binding rows,
--- a drop-down list, the reset question, a panel switch's clash question, a notice, a confirmation); a press anywhere
--- else (the game world, another window) or its closing gives it back. While it has it every key is the window's: the
--- logic routes the keys and side buttons to the UI (C#'s InputRouting.UiFocus, read from S.focused) and the bindings
--- run none (core/bindings.lua B:OnKey). WIRE: this decides whether a key may reach the game's keys (4a's
--- UserPane::HandleKeyOrTextEvent 0x005A5BD0) and send; changing it changes what the server sees.
-- s6-modular-g r23: the Sound page renders MusicControlDialog; the model owns its keys, not ordinary Settings
-- focus. Its close can precede this frame's page update. WIRE: after DialogPane's Escape (0x0049E6E0), the next
-- Q must reach UserPane (0x005A5BD0) and OpenQuitPrompt (0x005A94B0). Keeping the page's focus changes what the
-- server sees. The model's closing stall/slide and the closing key's ownership stay with the model.
function S:HasFocus() return self.focused and self:IsOpen() and not musicOpen or false end

local function onWindow(f)
    while f do
        if f == frame or f == resetAsk or f == W.choose or f == W.confirm or f == _G.TKPopup then return true end
        f = f.dropdown or f:GetParent() -- a drop-down's list goes by its drop-down
    end
    return false
end

TK.On("GLOBAL_MOUSE_DOWN", function()
    if S:IsOpen() then S.focused = onWindow(GetMouseFocus()) end
end)

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
    { "Classic Prompts", { "CLASSICDROP", "CLASSICDROPALL", "CLASSICEAT", "CLASSICUSE", "CLASSICWIELD", "CLASSICWEAR",
        "CLASSICTHROW", "CLASSICGIVE", "CLASSICGIVEALL", "CLASSICCAST", "CLASSICINVITE", "CLASSICEMOTE",
        "CLASSICWHISPER", "CLASSICSHOUT", "CLASSICSAY", "CLASSICIGNORE", "CLASSICSTATUS", "CLASSICCOLLECTION",
        "CLASSICHELP" } },
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
        -- text"): the hover binding is Edit Mode's Keybinds now (core/editmode.lua), and the slots say how they bind in
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
local quickRows = require("core.quicksettings"):Rows()
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
    local args = {
        { type = "description", name = "Connect uses the enabled Internet server. Accounts are saved per server." },
        { type = "select", name = "Enabled Server", width = "full",
          values = function()
              local values = {}
              for _, s in ipairs(TK.Login.Servers()) do
                  values[#values + 1] = { value = s.id, text = s.name .. " (" .. s.host .. ":" .. math.floor(s.port) .. ")" }
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
          desc = "Other addresses of this server, comma separated: host or host:port (its own port when none).",
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
    for _, s in ipairs(TK.Login.Servers()) do
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
    end
    -- s6-play-modes (round 8, interface-separation step 4, W8; moved from components/graphicsstyles): each saved server's
    -- protocol version (s6-modular, DESIGN.md section 3), set by hand, 7.5.2 until set. The versions offered are 7.5.2 and
    -- the installed protocol modules'; the login screen's connection loads the one that serves the server's version, and
    -- says so when none does. Kept in modules.json beside the server list (so the server form and settings.toml stay as
    -- they are).
    local P = CS.TK.Modular.ProtocolHost
    args[#args + 1] = { type = "header", name = "Protocol Versions" }
    args[#args + 1] = { type = "description", name = "The version each server speaks: its protocol module is loaded when the login screen connects. A version with no module installed is said on the login screen, and nothing connects." }
    -- s6-optimize (round 7): the versions are read (a scan of the Modules folder's manifests, about 3.6 ms on the VM) when
    -- the page first shows its selects, once for all of them, not each time the settings window lists its pages (three or
    -- four times an opening, in the world too, where this login-only page never shows).
    local list
    local function versions()
        if not list then
            list = {}
            for v in string.gmatch(P.Versions(), "[^;]+") do list[#list + 1] = { value = v, text = v } end
        end
        return list
    end
    for _, s in ipairs(TK.Login.Servers()) do
        local host, port = s.host, math.floor(s.port)
        args[#args + 1] = { type = "select", name = s.name .. " (" .. host .. ":" .. port .. ")", values = versions,
            get = function() return P.VersionOf(host, port) end,
            set = function(_, v)
                P.SetVersion(host, port, v)
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
            TK.Library.Await(__tk:FillLibraryFromServerFiles(server), function(problem)
                library.filling = nil
                __tk:LibraryFileChanged(server)
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
