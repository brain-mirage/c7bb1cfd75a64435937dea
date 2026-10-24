-- s6-interface-5x (round 12; docs/development/interface-separation.md, step 1 and section 5.1): the game layer's views,
-- the game's pages ("character", "spellbook", "legend", "collection", "bag", "look", "group", "ignore", "emotes") and who
-- shows them when an opener asks: an interface's page that provides the view while its panel is in use (7.x's and 5.x's
-- side panels), else the window registered for it (Modern's: the character window, the bag, the look window, the Social
-- window, the emotes). It replaces the six single-slot hooks the openers asked before (Bag.ShowOverride,
-- CW.OpenOverride, Look.ShowOverride, Social.OpenOverride, CW.PageOverride and CW.StatusKeyOverride) and the shared side
-- panel's and 5.x's registries (interfaces/sidepanel.lua, interfaces/5x/sidepanel.lua): one registry, asked only while a
-- provider's panel is in use, the latest provided first (the design's R3 and R7). It owns the openers' keys, the views
-- the server opens (their drivers) and the pages built ahead while the world loads, so no interface reaches another's
-- window for them.
--
-- A provider has no close: its pages follow the game layer's active tab (TK.Game.SidePanel), as 4a's one panel does.
-- Wire: a page that asks the server for its data carries its request (open:character 2D 00, open:group 2D 01,
-- open:collection 27 00 00), which runs when the page becomes visible during the input that froze an action of its kind
-- (plan 5.9). So which page shows for an opener decides which request goes; changing the order here (a provider in use
-- before the window) changes what the server sees.

local H = __tk

TK.Game = TK.Game or {}
local V = { providers = {}, windows = {} }
TK.Game.Views = V

-- ----- the providers (an interface's pages) and the windows -----

--- An interface's page for views, under its panel: provider.views maps a view to the provider's page for it;
--- provider.IsShowing() says whether its panel is in use now (on, in the game, showing); provider.Show(page, view, how,
--- key) shows the page and returns true, or false for one it does not draw (the window opens then; how as V.Open's; key
--- true when the opener is the view's own key, V.Toggle's);
--- provider.Page(delta) and provider.StatusKey() (optional) take PgUp and PgDn, and the original's status key. The
--- latest provided asks first.
function V.Provide(panelId, provider)
    table.insert(V.providers, 1, TK.Mark({ panel = panelId, provider = provider }))
end

--- A window for a view (a name or a list of names), used when no provider in use takes it: window.Open(view, how),
--- window.Close(), window.IsOpen(view) (open on that view), and optionally window.Page(delta) (true when it paged) with
--- window.pageOrder (the windows page in that order: the first open one takes the keys), and window.panel, the panel
--- whose switch turns it on ({ component, node, switch }, as an interface lists its panels; step 1): a window that is
--- off takes no view, as if it had none.
local windowOwners = {} -- view -> its window's owner (TK.Mark)

function V.SetWindow(views, window)
    if type(views) ~= "table" then views = { views } end
    local owner = TK.Mark({})
    for _, view in ipairs(views) do V.windows[view], windowOwners[view] = window, owner end
end

--- Whether a window is on in this profile (its panel's switch; always for a window without one).
local function on(w)
    return w.panel == nil or TK.Panels:IsOn(nil, w.panel)
end

--- The view's window while it is on, else nil.
local function windowOf(view)
    local w = V.windows[view]
    if w and on(w) then return w end
end

--- Closes the view's window when it is open on that view. Nothing is sent.
function V.Close(view)
    local w = windowOf(view)
    if w and w.IsOpen(view) then w.Close() end
end

--- s6-interface-5x (round 13's hotfix; interface-separation.md 5.16): every open window closed, each by its own Close,
--- as the player's close (an interface switch). Wire: a close sends nothing, and a page's request goes only when it
--- opens again by an input; changing this changes what the server sees.
function V.CloseWindows()
    local seen = {}
    for _, w in pairs(V.windows) do
        if not seen[w] then
            seen[w] = true
            if w.IsOpen(nil) then TK.SafeCall(w.Close) end
        end
    end
end

--- Closes every open window that is off (a window's switch turned off on its page). Nothing is sent.
function V.CloseOff()
    for _, w in pairs(V.windows) do
        if not on(w) and w.IsOpen(nil) then w.Close() end
    end
end

--- The providers in use now, in their order.
local function inUse()
    local list = {}
    for _, e in ipairs(V.providers) do
        if e.provider.IsShowing() then list[#list + 1] = e.provider end
    end
    return list
end

--- An opener's view in the provider in use that draws it: true when one showed it, so the view's window stays shut
--- (and closes if open: V.Open).
function V.Take(view, how, key, serverPage)
    for _, p in ipairs(inUse()) do
        local page = p.views[view]
        if page and p.Show(page, view, how, key, serverPage) then return true end
    end
    return false
end

--- Whether anything draws the view: a provider in use with a page for it, or its window while on. An opener with
--- nothing to show it (its window turned off and no page for it: step 1) does nothing, not even its tab switch, as an
--- unbound key; so nothing changes for the server.
local function drawn(view)
    if windowOf(view) then return true end
    for _, p in ipairs(inUse()) do
        if p.views[view] then return true end
    end
    return false
end

-- s6-modular-g (round 18; section 5.8): the same check for Game Options' opener (TK.Game.Options.Toggle), whose windows
-- are its own. Drawing only.
V.Drawn = drawn

-- ----- the openers -----

-- The tab each view's opener switches to, 4a's UserPane helpers (SwitchActiveTab 0x004B8650): the items 2
-- (SwitchToInventory), the spells 3 (SwitchToSpell), the group 4 (SwitchToGroup), the collection 5 once its list has come
-- (before, UserPane::SwitchToCollectionTab 0x005A4EA0 only asks: its list's packet switches). The self look and the legend
-- only ask (2D 00; the 0x39 switches), and a look at another player is the 0x34's. Wire: the tab decides E and G's sender
-- (UserPane.cpp:1584-1614), S's (UserPane.cpp:1546) and whether the group's next press is an accepted switch (2D 01);
-- changing this changes what the server sees.
local SWITCH = { bag = 2, spellbook = 3, group = 4 }
local function switchFor(view)
    if SWITCH[view] then TK.Game.SidePanel.Switch(SWITCH[view])
    elseif view == "collection" and H:IsCollectionLoaded() then TK.Game.SidePanel.Switch(5) end
end

--- Shows a view, the window's (or a provider's) part of an opening, the tab already switched: the provider in use that
--- draws it (the view's window, if open on any of its views, closes), else its window.
local function show(view, how, serverPage)
    local w = windowOf(view)
    if V.Take(view, how, nil, serverPage) then
        if w and w.IsOpen(nil) then w.Close() end
        return true
    end
    if w then w.Open(view, how) end
    return w ~= nil
end

--- Opens a view: its tab switch, then the provider in use that draws it, else its window. how is "input" (a key or a
--- button: the page's request runs when it becomes visible in that input, plan 5.9) or "server" (a packet or the map
--- opened it, outside any input: nothing is sent; no key's sample). True when something shows it.
function V.Open(view, how, serverPage)
    if not TK.GameState:InWorld() or not drawn(view) then return false end
    switchFor(view)
    return show(view, how or "input", serverPage)
end

--- An opener's key or button: its tab switch first, on every press (4a's keys always call their SwitchActiveTab, which
--- refuses the active tab); then a provider in use that draws the view shows it (its page follows the tab: a provider
--- has no close), else the view's window closes when it is open on that view, or opens. Closing a window is the window's
--- own (4a's panel has none): it sends nothing. key: the opener is the view's own key (the commands below), which a
--- page that is the active tab may take for itself (7.x's expanded panes: s6-interface-7x-b round 5; 4a's pane has the
--- key before UserPane, InventoryPane.cpp:926-930), sending nothing.
function V.Toggle(view, key)
    if not TK.GameState:InWorld() or not drawn(view) then return end
    -- the key is the page's only when its tab was already the active one (4a's pane has the key only while it shows,
    -- InventoryPane.cpp:926-930): a press that switches the tab only switches (s6-interface-5x round 12, Astra's
    -- wrap-up review). The switch and its request are unchanged; the pane's toggle sends nothing.
    local before = TK.Game.SidePanel.Active()
    switchFor(view)
    if TK.Game.SidePanel.Active() ~= before then key = nil end
    local w = windowOf(view)
    if V.Take(view, "input", key) then
        if w and w.IsOpen(nil) then w.Close() end
    elseif w then
        if w.IsOpen(view) then w.Close() else w.Open(view, "input") end
    end
end

--- Whether the view's window is open on it.
function V.IsOpen(view)
    local w = windowOf(view)
    return w ~= nil and w.IsOpen(view) == true
end

--- PgUp and PgDn (K-097, K-098; nothing sent): the provider in use pages its page that shows; else the first open window
--- in their page order (the look window, the character window, the bag, the Social window's group page).
function V.Page(delta)
    for _, p in ipairs(inUse()) do
        if p.Page then
            if p.Page(delta) == true then return true end
            break
        end
    end
    local seen, list = {}, {}
    for _, w in pairs(V.windows) do
        if w.Page and not seen[w] and on(w) then seen[w] = true; list[#list + 1] = w end
    end
    table.sort(list, function(a, b) return (a.pageOrder or 99) < (b.pageOrder or 99) end)
    for _, w in ipairs(list) do
        if w.Page(delta) == true then return true end
    end
    return false
end

--- The original's status key (S). Wire: while 4a's tab 0 is the active tab the self look has the key first
--- (SelfLookPane.cpp:1067: its views cycle, nothing is sent); otherwise UserPane's RequestLocalPlayerStatus sends 2D 00
--- (UserPane.cpp:1546). True when the key was taken here (nothing sent), with tab 0 active: a provider in use cycles its
--- self look's views (provider.StatusKey: 7.x's three), or, when its panel shows another
--- page (5.x's after a plain 0x39: its page does not follow the tab; Astra's s6-interface-5x-self-12-1, P1), shows its
--- self look in the next frame; with none (Modern), the character window shows or hides in the next frame. Both outside
--- the key's input, so the page's request does not run. False: the caller then opens the self look with its 2D 00.
--- Changing this changes whether the server gets 2D 00.
function V.StatusKey()
    if not TK.Game.SidePanel.Is(0) then return false end
    local p = inUse()[1]
    if p then
        if p.StatusKey and not p.StatusKey() then
            TK.Await(function() return true end, function() V.Take("character", "server") end)
        end
    else
        local w = windowOf("character")
        if w then
            TK.Await(function() return true end, function()
                if w.IsOpen("character") then w.Close() else w.Open("character", "server") end
            end)
        end
    end
    return true
end

-- ----- the pages' requests -----

--- A page that carries a window's request (kind: "open:character"): attached while the UI loads, as Modern's pages
--- attach theirs (plan 5.9); call it from a component's OnEnable. The request runs when the page becomes visible during
--- the input that froze it; V.ShowAgain makes each such press show it again. Wire: the request (2D 00, 2D 01, 27 00 00)
--- goes with the page's showing in the input; changing when it is attached or shown changes what the server sees.
function V.RequestPage(page, kind)
    TK.On("PLAYER_LOGIN", function() TK.Actions:SetOpen(page, kind) end)
end

--- Hides a request page that shows, so the next show is a new one and its request runs again: each press of an opener
--- that is not the status key on the open self look (the Info icon: 4a's IconsPane calls RequestLocalPlayerStatus on
--- each press) sends 2D 00 (decision 2026-10-04-5x-side-panel-pages, its round 5 correction).
function V.ShowAgain(page)
    if page and page:IsShown() then page:Hide() end
end

-- ----- built ahead -----

local ahead = {}

--- s6-optimize (round 6; decision 2026-10-03-windows-built-at-world-load): fn builds a window or page ahead, hidden, while
--- the world loads (core/gamestate.lua), in order; its first opening then costs what a later one does. Nothing is sent.
function V.BuildAhead(order, fn)
    ahead[#ahead + 1] = TK.Mark({ order = order, fn = fn })
    table.sort(ahead, function(a, b) return a.order < b.order end)
end

-- s6-interface-5x (round 13, the separation's step 11): a panel turned off takes its pages, windows and builds with it
TK.OnWithdraw(function(name, panel)
    TK.DropOwned(V.providers, name, panel)
    TK.DropOwned(ahead, name, panel)
    for view, owner in pairs(windowOwners) do
        if TK.OwnedBy(owner, name, panel) then V.windows[view], windowOwners[view] = nil, nil end
    end
end)

--- Builds every page registered with V.BuildAhead (each builds itself once).
function V.BuildAll()
    for _, a in ipairs(ahead) do TK.SafeCall(a.fn) end
end

-- ----- the keys -----

-- The openers' commands (names, action kinds and default keys unchanged from the windows that registered them before
-- round 12). Wire: a command's action kind goes with its key, so the press freezes the page's request (plan 5.9: C's and
-- F's, the collection's); changing a kind changes what the key sends.
TK.Bindings:RegisterCommand("TOGGLECHARACTER", "Character", function() V.Toggle("character") end, { kind = "open:character" })
TK.Bindings:RegisterCommand("TOGGLESPELLBOOK", "Spell Book", function() V.Toggle("spellbook", true) end)
TK.Bindings:RegisterCommand("TOGGLECOLLECTION", "Collection", function() V.Toggle("collection") end,
    { kind = "open:collection" })
-- The B key opens the bag, as in WoW (in the original, b opens the boards; the coverage matrix keeps every original
-- command reachable, s6-ui-bag's notes).
TK.Bindings:RegisterCommand("TOGGLEBAG", "Bag", function() V.Toggle("bag", true) end)
TK.Bindings:RegisterCommand("TOGGLESOCIAL", "Social (Ignore List)", function() V.Toggle("ignore") end)
TK.Bindings:RegisterCommand("TOGGLEGROUP", "Group", function() V.Toggle("group", true) end, { kind = "open:group" })
TK.Bindings:RegisterCommand("TOGGLEEMOTES", "Emotes", function() V.Toggle("emotes") end)
TK.DB.defaultBindings["C"] = "TOGGLECHARACTER"
TK.DB.defaultBindings["P"] = "TOGGLESPELLBOOK"
TK.DB.defaultBindings["B"] = "TOGGLEBAG"
TK.DB.defaultBindings["F9"] = "TOGGLESOCIAL"
TK.DB.defaultBindings["F"] = "TOGGLEGROUP"
TK.DB.defaultBindings["SHIFT-;"] = "TOGGLEEMOTES"

-- s6-ui-character (K-098, K-097): plain PgUp and PgDn page the original's side-panel tab that shows (its key handler's
-- 0x93 and 0x94; nothing is sent).
TK.Bindings:RegisterCommand("PANELPAGEUP", "Previous Page (panels)", function() V.Page(-1) end)
TK.Bindings:RegisterCommand("PANELPAGEDOWN", "Next Page (panels)", function() V.Page(1) end)
TK.DB.defaultBindings["PAGEUP"] = "PANELPAGEUP"
TK.DB.defaultBindings["PAGEDOWN"] = "PANELPAGEDOWN"

-- ----- the views the server and the map open -----
--
-- Each opens outside any input (the rules' notices, which the UI takes before any input after their packet:
-- GameConnection.CatchUp; or a driver's frame), so no page's request runs and nothing is sent; "server" also keeps the
-- keys' sample off.

-- s6-ui-core (round 33): a spell prompt's ? (the rules' notice): the side panel's spell tab
-- (GeneralPurposePanel::SwitchActiveTab(3, 0)) and sample 0x198; the prompt stays open.
TK.On("TK_RULES_SPELL_TAB", function()
    V.Open("spellbook", "server")
    TK.Game.Sound.PlayEffect(0x198)
end)

-- s6-interface-5x (round 12; Astra's review of the round 11 fix): an item prompt's Shift+? (the rules' notice, in the
-- logic's order: UserPane.cpp:5741-6812, SwitchActiveTab(2, 0) and sample 0x198, the prompt staying open) shows the items.
TK.On("TK_RULES_ITEM_TAB", function()
    V.Open("bag", "server")
    TK.Game.Sound.PlayEffect(0x198)
end)

-- s6-ui-character: the self look the server or the map opens (D-77, U-14): an S 0x3E 4, 7 or 8 asks the next 0x39 to show
-- the original's equipment, status or legend page (the character or legend view), and a right press on oneself with
-- click-look, whose 2D 00 the rules send as the original's map does, the character view. The session answered S 0x3E's
-- with 2D 00 itself, and the rules sent the right press's.
local pressesSeen = 0

local function selfLookAsked()
    if not TK.GameState:InWorld() then return end
    local presses = H:GetSelfLookPresses()
    if presses ~= pressesSeen then
        pressesSeen = presses
        V.Open("character", "server")
    end
end

-- A new look at another player (0x34) opens the look view.
local lookSeen = 0

--- The look view for a look not seen yet; true if the look changed.
local function newLook()
    if not TK.GameState:InWorld() then return false end
    local serial = H:GetLook()
    if serial == lookSeen then return false end
    lookSeen = serial
    if serial ~= 0 then V.Open("look", "server") end
    return true
end

-- The remaining drivers watch map self-look presses (0.1 s) and new look data (0.2 s); server self-view requests
-- are handled once per ordered notice below, without polling. s6-ui-core (round 101, T11 step 3): each is called on its
-- due frames only when the presses or the look changed, and once more when the game state changes (both wait for the
-- world).
TK.On("PLAYER_LOGIN", function()
    local driver = CreateFrame("Frame", "TKCharacterDriver", UIParent)
    driver:SetScript("OnUpdate", TK.Util.Throttled(0.1, selfLookAsked))
    driver:SetUpdateWhen("look")
    local lookDriver = CreateFrame("Frame", "TKLookDriver", UIParent)
    lookDriver:SetScript("OnUpdate", TK.Util.Throttled(0.2, newLook))
    lookDriver:SetUpdateWhen("look")
    TK.On("TK_GAME_STATE", function()
        driver:SetUpdateWhen("look")
        lookDriver:SetUpdateWhen("look")
    end)
end)

-- s6-interface-5x (rounds 11 and 12): the packets' tab switches show their view at the notice itself (the logic's order,
-- before any input after the packet), as 4a's switches show their pane with the packet, not up to a driver's period later:
-- a 0x39 the page the switch asked for (SelfLookPane::OnActivate 0x00565890), a 0x34 the look (SwitchPanelTab1WithClick-
-- AndStopTimer 0x005119B0), the server's 0x3E 0 and 2 the items and the spells with no sample (UserPane::
-- HandleUIPanelSwitchPacket 0x005ABDA0). The game layer's tab itself is switched by TK.Game.SidePanel's own handler, first.
-- WIRE: each notice carries its own request (4a SelfLookPane::OnActivate 0x00565890), so a burst of
-- 0x39/0x3E/0x39 opens each requested page in packet order. Reading the latest snapshot here loses an earlier
-- request and changes which equipment press the server sees. The 0.1 s driver above only watches map self-look presses.
TK.On("TK_RULES_PANEL_TAB", function(_, tab, view, requested)
    if tab == 0 then
        -- A map self-look press is also taken at its 39, as before; the driver catches presses between notices.
        selfLookAsked()
        if requested then V.Open(view == 2 and "legend" or "character", "server", view) end
    elseif tab == 1 then newLook()
    elseif tab == 2 then V.Open("bag", "server")
    elseif tab == 3 then V.Open("spellbook", "server") end
end)

TK.On("PLAYER_ENTERING_WORLD", function()
    -- What an earlier visit on the same connection asked for, or looked at, is not new.
    pressesSeen = H:GetSelfLookPresses()
    lookSeen = H:GetLook()
end)

return V
