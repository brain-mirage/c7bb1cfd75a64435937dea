-- s6-modular-g (interfaces, phases 1 and 2; docs/development/interfaces.md, "A panel", "Categories",
-- "Mixing"): the panel registry. Each installed interface (TK.Interfaces) lists its panels in its interface.lua, each one piece of the
-- screen with its category, the component whose code draws it, its settings page, its switch, its place and the keys it
-- brings. The Interface list shows the shown interface's panels under one Panes title, in their categories' order
-- (s6-ui-core round 83, the owner's request of 2026-10-09: P:GroupRoots); the other interfaces' panels are off in a profile
-- until turned on there. It draws nothing and sends nothing.

local P = {}
TK.Panels = P

-- Every interface files its panels under these, in this order: the Panes title lists them in it, and Decoration (7.x's and
-- 5.x's screen art; Modern has none) has its own title after it.
P.categories = { "World", "Character", "Pages", "Messages", "Chat", "Buttons", "Indicators", "Decoration" }
local CATEGORY = {}
for i, c in ipairs(P.categories) do CATEGORY[c] = i end

--- The active interface (TK.Interfaces, which the boot loads first: core/components.lua's Boot).
function P:Interface() return TK.Interfaces:Active() end

--- The active interface's panels, in its order.
function P:List() return self:Interface().panels end

--- Every installed interface's panels: the active interface's first, then the others' in the registry's order.
function P:All()
    local out = {}
    for _, p in ipairs(self:List()) do out[#out + 1] = p end
    for _, interface in ipairs(TK.Interfaces.list) do
        if interface ~= self:Interface() then
            for _, p in ipairs(interface.panels) do out[#out + 1] = p end
        end
    end
    return out
end

--- A panel of the active interface by its id, or nil.
function P:Get(id)
    for _, p in ipairs(self:List()) do
        if p.id == id then return p end
    end
end

--- The panel whose settings page a node is, of any installed interface, or nil.
function P:OfNode(nodeId)
    for _, p in ipairs(self:All()) do
        if p.node == nodeId then return p end
    end
end

--- The node of nodes whose id is id, or nil.
local function find(nodes, id)
    for _, node in ipairs(nodes) do
        if node.id == id then return node end
    end
end

--- Whether a panel is on: its page's switch, or always for a panel without one (a window). s6-optimize (round 14): the
--- page is looked for among its own component's pages first; making every component's (Components:AllNodes) took some
--- 5.5 ms, and the profile's save asks this for each other interface's panel (Interfaces:Unused: 40 ms a save in Modern,
--- 190 ms in 7.x). A panel whose component is not loaded or does not hold its page is looked for among them all.
function P:IsOn(id, panel)
    panel = panel or self:Get(id)
    if not panel then return false end
    if not panel.switch then return true end
    local c = panel.component and TK.GetComponent(panel.component)
    local node = c and find(c:SettingsNodes(), panel.node) or find(TK.Components:AllNodes(), panel.node)
    return node ~= nil and node.db()[panel.switch] ~= false
end

--- The panel a page is of: its own, or, for a page of none under a panel's page (s6-ui-core round 82: Nameplates' Players
--- and NPCs), its parent's.
local function panelOf(node)
    return P:OfNode(node.id) or (node.parent and P:OfNode(node.parent))
end

--- Where a page goes in the Interface list: its panel's interface (the shown one and the shared panels first: s6-ui-core
--- round 83, so a shared panel takes its category's place among the shown interface's panes), then its category, then its
--- own order. A page of no panel (Macros, Tooltips) goes after the shown interface's panels.
local function rank(node)
    local panel = panelOf(node)
    if not panel then return 1, #P.categories + 1 end
    local t = (panel.interface == P:Viewed() or panel.shared) and 1 or 2
    for i, interface in ipairs(TK.Interfaces.list) do
        if interface.id == panel.interface and t == 2 then t = 1 + i end
    end
    return t, CATEGORY[panel.category] or #P.categories + 1
end

--- The Interface list's pages in their order (core/settings.lua's CategoryNodes).
function P:SortNodes(nodes)
    local keys = {}
    for i, n in ipairs(nodes) do
        local t, c = rank(n)
        keys[n] = { t, c, n.order or 0, n.sub or 0, i }
    end
    table.sort(nodes, function(a, b)
        local x, y = keys[a], keys[b]
        for k = 1, 5 do
            if x[k] ~= y[k] then return x[k] < y[k] end
        end
        return false
    end)
    return nodes
end

--- s6-ui-core (round 83; the owner, 2026-10-09: "a Main Panes Section that has all the ... Panes under it and they also
--- all expand like they normally do. Then at the top You have the General etc"): the Interface list's titles. Every pane of
--- the shown interface, the shared ones (the world view's frame, the menu button) among them, goes under Panes; 7.x's and
--- 5.x's Decoration (their screens' art, no pane the player works with) under its own title after it.
P.PANES, P.DECORATION = "Panes", "Decoration"
local PANES_ID, DECORATION_ID = "heading:panes", "heading:decoration"

--- Where a page goes in the Interface list: its interface's id (nil for a shared panel's) and its category; nothing for a
--- page of no panel, which goes at the top.
local function placeOf(node)
    local panel = panelOf(node)
    if not panel then return nil end
    return not panel.shared and panel.interface or nil, panel.category, panel
end

--- s6-interface-5x (round 12; the owner, 2026-10-05, through the head): the interface the Interface tab shows, chosen on
--- its General page's dropdown, the active one until then. Choosing one only shows it (its panels' pages are listed, the
--- others' hidden); it never switches the interface. Kept for the client's run, not saved.
function P:Viewed() return self.viewed or self:Interface().id end

--- Shows interface id's pages in the Interface tab (the General page's dropdown).
function P:View(id)
    self.viewed = id
    if TK.Settings.BuildTree and TK.Settings.category == "interface" then TK.Settings:BuildTree() end
end

--- The title id a panel's page goes under (P.PANES's or P.DECORATION's), or nil for a page at the top.
local function headingOf(node)
    if node.listTop then return nil end
    local _, category, panel = placeOf(node)
    if not panel then return nil end
    return category == "Decoration" and DECORATION_ID or PANES_ID
end

--- The interface tab's list for the interface shown (s6-ui-core round 83): at the top the General page (listTop) and the
--- pages of no panel (Macros, Tooltips); then the Panes title with that interface's panes and the shared ones, in their
--- categories' order (P:SortNodes), each entry with its own pages under it (the bars under Bars, the minimap's icons under
--- the Minimap); then the Decoration title. Another interface's pages are not listed (a shortcut to one shows its interface
--- first: P:Reveal). The titles' ids are the same for every interface, so they keep their open state across them.
function P:GroupRoots(roots, byId)
    local viewed = self:Viewed()
    local first, top = {}, {}
    local panes = { id = PANES_ID, title = P.PANES, children = {} }
    local decoration = { id = DECORATION_ID, title = P.DECORATION, children = {} }
    byId[panes.id], byId[decoration.id] = panes, decoration
    local function pageOf(e)
        if e.node then return e.node end
        return e.children[1] and pageOf(e.children[1])
    end
    for _, e in ipairs(roots) do
        local page = pageOf(e)
        local heading = page and headingOf(page)
        if not heading then
            table.insert(page and page.listTop and first or top, e)
        else
            local id = placeOf(page)
            if id == nil or id == viewed then
                table.insert(heading == PANES_ID and panes.children or decoration.children, e)
            end
        end
    end
    for _, e in ipairs(top) do first[#first + 1] = e end
    if #panes.children > 0 then first[#first + 1] = panes end
    if #decoration.children > 0 then first[#first + 1] = decoration end
    return first
end

--- The titles above a page in the Interface list (P:GroupRoots), { id }: a shortcut to the page opens them (S:Select).
function P:HeadingsOf(node)
    local heading = headingOf(node)
    return heading and { { id = heading } } or {}
end

--- A shortcut to another interface's page shows that interface's pages first (the list holds only the shown one's).
function P:Reveal(node)
    local id = placeOf(node)
    if id and id ~= self:Viewed() then self.viewed = id end
end

--- The heading a page goes under in the Interface list, as the player reads it: P.PANES or P.DECORATION, or nil for a
--- page at the top.
function P:Heading(node)
    local heading = headingOf(node)
    if heading == nil then return nil end
    return heading == PANES_ID and P.PANES or P.DECORATION
end
