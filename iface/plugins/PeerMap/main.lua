-- Peer Map: the base plugin of the remote protocol (s6-peer round 12; the owner, 2026-10-04: "add a overlay to the map of
-- your connected peers as a list", "clicking it moves to their map and position and shows their marker and centers it,
-- right click option -> remote view on their name to start it", "show the remote view in the map? and you can right
-- click to exit the view"). It is written only against the plugin API, as a WoW addon is: the map window's frame
-- (C_MapWindow), the remote protocol (C_Remote), a mark (C_Minimap) and a world drawn from data (C_WorldView).
--
--   * The list: your connected peers, on the left of the map window's map while it is open.
--   * A click on a name asks that player's place (Location, on change) and moves the map window there, centred on their
--     marker (and again when they change maps). Their place only: nothing of their view. It is asked only while their
--     map is what the window shows (round 13: Centre, another click, the remote view or closing the window end it).
--   * A right-click asks once whether they share their view (view-players) and offers "Remote view" if they do: their
--     surroundings drawn in the map window, from their view categories, asked only while the view shows. Leaving it (a
--     right-click on it, Escape or anything that closes the map window, a click on a name, or anything that needs you:
--     your health drops, you die, a dialog opens) releases those requests: they are tied to the view's frame.
--   * Round 17 (the owner, 2026-10-06: "it should pull their cache data if we dont have it"): the view's map is what this
--     client has of the 50 x 50 grid round them (C_MapCache.Check: its own map cache), and what it lacks is pulled from
--     their client (view-map asked once with the missing cells): when the view opens and when they move or change maps,
--     one pull at a time; cells they had not got are asked again only after they move. The client keeps what comes (in
--     its map cache when they are on its server), so a grid already had is not asked for again. On the map you stand on
--     (or may: the same map, their server not proven) nothing is pulled: your own map is drawn (when proven), with their
--     view-map on change as before (drawn only).
--
-- Every request is tied to what shows its answers (s6-peer round 13, the owner's "only request when needed"): the place to
-- the peer's map being the one shown, the host's list and address identities to the peer list, the view to the view.
-- Whether a view is shared is asked once and ends with its answer.
--
-- It ships with the client (the build's iface/plugins: AppPaths.BasePlugins) and is enabled or disabled like any other
-- plugin on the Plugins page.
--
-- It sends nothing on the game connection. While you view someone else your own session goes on unchanged in the main
-- view: the view is a picture in a window, and nothing you click in it is sent anywhere. Its calls are unsafe calls
-- ("Enable unsafe plugins"), and the protocol runs only while its own switch is on (Plugins, Global, Remote-Protocol);
-- the other player shares each view category on their Remote View page and must count you as a connection.

local MARK = "peer"     -- the followed peer's mark
local GRID = 50         -- round 17: the grid round the watched player (RemoteView.Grid: their client answers inside it)
local LIST_WIDTH = 104
local ROWS = 20         -- Visible rows, reused while scrolling; not a limit on the connected peers.

local area              -- the map window's frame for plugins (C_MapWindow.GetFrame)
local list, rows, menu  -- the peer list, its rows, the right-click menu
local listOffset = 0    -- The first displayed peer, zero-based; clamp after the connection list changes.
local viewFrame, world, banner
local following         -- { target, name, handle }: the peer whose place the map shows
local viewing           -- { target, name, head, answers, x, y, pulling, pulledAt, push }: the peer whose view shows (round 17: the
                        -- map's last head and their cell, the pull in flight and where it was made, the view-map on change)
local listed, listHandle = {}, nil -- the host's player list (name entries are reached through it)
local names = {}        -- an address's current player name and Online subscription, while the list shows
local health

local function say(text) DEFAULT_CHAT_FRAME:AddMessage("Peer Map: " .. text, 1, 0.85, 0.3) end

--- Stops following a peer's place: the request is released and the mark goes.
local function unfollow()
    if not following then return end
    local f = following
    following = nil
    C_Remote.Cancel(f.handle)
    C_Minimap.ClearMark(MARK)
end

local function label(parent, size, justify)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont(size)
    t:SetJustifyH(justify or "LEFT")
    return t
end

-- ----- the remote view -----

--- A scene belongs to one watched character/server and map, not just a numeric map id. Categories arrive separately.
local function sameScene(a, b)
    return a and b and a.server == b.server and a.login == b.login and a.name == b.name
        and a.map == b.map and a.width == b.width and a.height == b.height
end

--- Leaves the view: its frame hides, which releases every request tied to it (their handlers hear "released").
local function leave(why)
    if not viewing then return end
    viewing = nil
    viewFrame:Hide()
    if why then say(why) end
end

--- Round 17: the view's map round the watched player: what this client has of the grid, drawn, and what it lacks pulled,
--- once per place of theirs. On your own map nothing is pulled; their view-map on change is drawn instead.
local function mapAround(v)
    local t = C_MapCache.Check(v.head, v.x - GRID / 2, v.y - GRID / 2, GRID, GRID)
    if not t or not t.map then return end
    world:SetCells(t)
    if t.own then
        v.push = v.push or C_Remote.Request(v.target, "view-map", { on = "change", frame = viewFrame }, function(a, _, ended)
            if viewing ~= v then return end
            if ended then
                v.push = nil
                if ended ~= "released" then leave(v.name .. "'s view ended (view-map: " .. ended .. ")") end
            elseif type(a) == "table" and sameScene(v.head, a) then
                world:SetCells(a)
            end
        end) or nil
        return
    end
    if v.push then
        C_Remote.Cancel(v.push)
        v.push = nil
    end
    local at = t.map .. " " .. v.x .. " " .. v.y
    if #t.missing == 0 or v.pulling or v.pulledAt == at then return end
    v.pulledAt = at
    v.pulling = C_Remote.Request(v.target, "view-map", { arg = { map = t.map, need = t.missing }, frame = viewFrame },
        function(_, _, ended)
            if viewing ~= v then return end
            v.pulling = nil
            if ended then
                if ended ~= "released" then leave(v.name .. "'s view ended (view-map: " .. ended .. ")") end
                return
            end
            mapAround(v) -- the cells the client kept, drawn; and what their place now lacks, if they moved meanwhile
        end) or nil
end

--- Round 17 (the live check): the view frame's OnUpdate, once, at the next UI update after the watched player's place
--- changed. The first view's first calls are slow in the built client (tens of ms each: the world view's, then the map
--- cache's), and the opening, its answers and the first map check in one frame passed the plugins' 100 ms frame budget,
--- which switched the plugin off. The next UI update is never in the opening click's frame: when the UI updates before
--- the peer service (as seen), it is the next frame; otherwise the answers themselves came a frame after the click.
local function mapLater(self)
    self:SetScript("OnUpdate", nil)
    if viewing and viewing.head then mapAround(viewing) end
end

-- What each view category's answer gives the drawing (the answers' shapes: TK-Core/Peer/RemoteView.cs).
local VIEW = {
    ["view-players"] = function(a)
        world:SetObjects("players", a.players or {}, "player")
        for _, p in ipairs(a.players or {}) do
            if p.self then
                world:SetCentre(p.x, p.y)
                local v = viewing
                if v.x ~= p.x or v.y ~= p.y or not v.head or v.head.map ~= a.map then
                    v.head, v.x, v.y = a, p.x, p.y
                    v.pulledAt = nil -- a new place: what they lacked may be asked again, even back where it was
                    viewFrame:SetScript("OnUpdate", mapLater) -- round 17: the view opened, they moved or changed maps
                end
            end
        end
    end,
    ["view-creatures"] = function(a) world:SetObjects("creatures", a.creatures or {}, "creature") end,
    ["view-items"] = function(a) world:SetObjects("items", a.items or {}, "item") end,
    ["view-effects"] = function(a) world:SetEffects(a.effects or {}) end,
}

--- Keep the latest category answer until the player's head identifies its scene. A throttled old-scene answer must
--- not put old figures/effects on a new map; an early new-scene answer is applied when that player's head arrives.
local function takeView(v, cat, a)
    v.answers[cat] = a
    if cat == "view-players" then
        if not sameScene(v.head, a) then
            world:Clear()
            v.head, v.x, v.y, v.pulledAt = a, nil, nil, nil
            if v.push then C_Remote.Cancel(v.push) v.push = nil end
            for name, take in pairs(VIEW) do
                local saved = v.answers[name]
                if sameScene(saved, a) then take(saved) end
            end
        else
            VIEW[cat](a)
        end
    elseif sameScene(v.head, a) then
        VIEW[cat](a)
    end
end

local function startView(p)
    leave()
    unfollow() -- the view covers the map: the place is no longer shown
    -- Made when a view is first offered (offer), not as the plugin loads: a world view is a renderer of its own (round 14),
    -- made when it is first drawn.
    world = world or C_WorldView.Create(viewFrame)
    if not world then
        say("the remote view cannot be drawn here")
        return
    end
    world:SetAllPoints(viewFrame)
    local v = { target = p.target, name = p.name, answers = {} }
    viewing = v
    world:Clear() -- another opening must not show the previous watched scene while its answers are pending
    banner:SetText("Viewing " .. p.name .. "'s surroundings. Right-click to leave.")
    viewFrame:SetWidth(area:GetHeight() * 17 / 15) -- the world view's proportions, the map's height
    viewFrame:Show()
    health = UnitHealth("player")
    for cat in pairs(VIEW) do
        local h, why = C_Remote.Request(p.target, cat, { on = "change", frame = viewFrame }, function(answer, _, ended)
            if viewing ~= v then return end
            if ended then
                leave(p.name .. "'s view ended (" .. cat .. ": " .. ended .. ")")
            elseif type(answer) == "table" then
                takeView(v, cat, answer)
            end
        end)
        if not h then
            leave(p.name .. "'s view is not available (" .. cat .. ": " .. tostring(why) .. ")")
            return
        end
    end
end

-- ----- following a peer's place -----

local function follow(p)
    leave()
    unfollow()
    local f = { target = p.target, name = p.name }
    local h, why = C_Remote.Request(p.target, "location", { on = "change", frame = area }, function(place, _, ended)
        if following ~= f then return end
        if ended then
            following = nil
            C_Minimap.ClearMark(MARK)
            if ended ~= "released" then say(p.name .. "'s place is not available (" .. ended .. ")") end
            return
        end
        if type(place) == "table" and place.map then
            C_Minimap.SetMark(MARK, place.map, place.x, place.y, p.name, 1, 0.85, 0.3)
            -- The view moves at the click, and when they change maps (the mark would leave the map shown); on the same
            -- map only the mark follows them, so the player may look around.
            if f.map ~= place.map then
                f.map = place.map
                C_MapWindow.ShowMark(MARK, place.zone)
            end
        end
    end)
    if not h then
        say(p.name .. "'s place is not available (" .. tostring(why) .. ")")
        return
    end
    f.handle = h
    following = f
end

-- ----- the right-click menu -----

local function closeMenu()
    menu.offer = nil
    menu.offered = nil
    menu.row = nil
    if menu.handle then C_Remote.Cancel(menu.handle) menu.handle = nil end
    menu:Hide()
end

--- Offers "Remote view" on row's peer, if they share their view: one view-players asked once, to see.
local function offer(p, row)
    closeMenu()
    local owner = {}
    menu.offer = owner -- a delayed answer belongs only to the offer that asked for it
    menu.offered = p
    menu.row = row -- a refresh or scroll may reuse this row for a different peer
    menu.peer = nil
    menu.text:SetText("Asking " .. p.name .. "...")
    menu.text:SetTextColor(0.7, 0.7, 0.7)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", row, "TOPRIGHT", 4, 0)
    menu:Show()
    local function answer(shared)
        if menu.offer ~= owner or not menu:IsVisible() then return end
        menu.handle = nil
        menu.peer = shared and p or nil
        -- Round 17 (the live check): the drawing's picture is made here, not in the click that opens the view: made there,
        -- the first view's opening passed the plugins' frame budget with its answers (see mapLater).
        if shared then world = world or C_WorldView.Create(viewFrame) end
        menu.text:SetText(shared and "Remote view" or "Remote view: not shared")
        if shared then menu.text:SetTextColor(1, 1, 1) else menu.text:SetTextColor(0.6, 0.6, 0.6) end
    end
    local h = C_Remote.Request(p.target, "view-players", { frame = menu },
        function(a, _, ended) answer(not ended and type(a) == "table") end)
    menu.handle = h or nil
    if not h then answer(false) end
end

-- ----- the list -----

--- An address is a client, not a character. Where the connection carries no "me", watch Online for character changes
--- while its row is needed. The list's frame releases the request on hide; a new link or opening asks afresh.
local function nameOf(c)
    if c.name ~= "" then return c.name end
    local identity = names[c.id]
    if not identity then
        identity = {}
        names[c.id] = identity
        identity.handle = C_Remote.Request(c.id, "online", { on = "change", frame = list }, function(who, _, ended)
            if names[c.id] ~= identity then return end
            if ended then
                names[c.id] = nil
            else
                identity.name = type(who) == "table" and who.name ~= "" and who.name or nil
            end
        end) or nil
    end
    return identity.name or c.label or c.id
end

--- The peers to list: the connected ones, and the name connections the host lists (reached through it); each player
--- once (one that dialled in as well as being added shows as the one added).
local function peers()
    local out, named, unnamed, current = {}, {}, {}, {}
    for _, added in ipairs({ true, false }) do
        for _, c in ipairs(C_Remote.GetConnections()) do
            if c.added == added and not c.ignored and not c.activeHost and c.kind ~= "host"
                and (c.connected or c.byName and listed[c.name]) then
                if not c.byName and c.name == "" then unnamed[c.id] = true end
                local name = c.byName and c.name or nameOf(c)
                current[c.id] = name -- retain every usable route even when another route supplies the one visible row
                if not named[name] then
                    named[name] = true
                    out[#out + 1] = { target = c.id, name = name }
                end
            end
        end
    end
    -- A removed/ignored address, or one now named by "me", no longer needs its Online subscription.
    for target, identity in pairs(names) do
        if not unnamed[target] then
            names[target] = nil
            if identity.handle then C_Remote.Cancel(identity.handle) end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out, current
end

--- The host's list, while the peer list shows (name connections are online when it lists them).
local function watchList(hostUp)
    if not hostUp or listHandle then
        if not hostUp then listed = {} end
        return
    end
    listHandle = C_Remote.Request("host", "players", { on = "change", frame = list }, function(names, _, ended)
        if ended then
            listHandle, listed = nil, {}
            return
        end
        listed = {}
        for _, n in ipairs(type(names) == "table" and names or {}) do listed[n.name] = true end
    end) or nil
end

local function refresh()
    if not area:IsVisible() then return end
    if not C_Remote.IsEnabled() then
        list.title:SetText("Peers: off")
        list:EnableMouseWheel(false)
        for _, r in ipairs(rows) do r:Hide() end
        return
    end
    local hostUp = false
    for _, c in ipairs(C_Remote.GetConnections()) do hostUp = hostUp or c.activeHost end
    watchList(hostUp)
    local shown, current = peers()
    -- A selection belongs to the character the player picked. Reusing the address for another character must not
    -- leave that former character's mark, view banner or pending offer attached to the new one.
    if following and current[following.target] ~= following.name then unfollow() end
    if viewing and current[viewing.target] ~= viewing.name then leave(viewing.name .. "'s connection or character changed") end
    if menu.offered and current[menu.offered.target] ~= menu.offered.name then closeMenu() end
    listOffset = math.max(0, math.min(listOffset, #shown - ROWS))
    list:EnableMouseWheel(#shown > ROWS)
    list.title:SetText(#shown > ROWS and "Peers (scroll)" or #shown > 0 and "Peers" or "No peers")
    for i, r in ipairs(rows) do
        local p = shown[i + listOffset]
        -- The offer is anchored to this visible row. Reordering or paging must not place one peer's view beside another.
        if menu.row == r and (not p or p.target ~= menu.offered.target or p.name ~= menu.offered.name) then closeMenu() end
        r.peer = p
        if p then
            r.text:SetText(p.name)
            local on = following and following.target == p.target or viewing and viewing.target == p.target
            if on then r.text:SetTextColor(1, 0.85, 0.3) else r.text:SetTextColor(0.85, 0.95, 1) end
            r:Show()
        else
            r:Hide()
        end
    end
end

local function build()
    area = C_MapWindow.GetFrame()
    if not area then return false end

    -- The view: the picture at the world view's proportions (17 x 15 cells), on the right of the map; the list beside it.
    viewFrame = CreateFrame("Frame", nil, area)
    viewFrame:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, 0)
    viewFrame:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 0, 0)
    viewFrame:EnableMouse(true)
    local bg = viewFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(viewFrame)
    bg:SetColorTexture(0, 0, 0, 1)
    local strip = viewFrame:CreateTexture(nil, "OVERLAY", -1) -- under the banner's text, over the picture
    strip:SetPoint("TOPLEFT", viewFrame, "TOPLEFT", 0, 0)
    strip:SetPoint("TOPRIGHT", viewFrame, "TOPRIGHT", 0, 0)
    strip:SetHeight(22)
    strip:SetColorTexture(0.35, 0.05, 0.05, 0.85)
    banner = label(viewFrame, 12, "CENTER")
    banner:SetPoint("TOP", viewFrame, "TOP", 0, -5)
    viewFrame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then leave() end
    end)
    viewFrame:Hide()

    list = CreateFrame("Frame", nil, area)
    list:SetPoint("TOPLEFT", area, "TOPLEFT", 2, -2)
    list:SetSize(LIST_WIDTH, 22 + ROWS * 18)
    local back = list:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(list)
    back:SetColorTexture(0, 0, 0, 0.6)
    list.title = label(list, 12)
    list.title:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -5)
    list.title:SetTextColor(1, 0.82, 0)
    -- Only overflow enables the wheel, leaving the map's usual wheel target alone for a short or disabled list.
    list:SetScript("OnMouseWheel", function(_, delta)
        listOffset = listOffset - delta
        refresh()
    end)
    rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, list)
        r:SetSize(LIST_WIDTH - 4, 18)
        r:SetPoint("TOPLEFT", list, "TOPLEFT", 2, -4 - i * 18)
        r:EnableMouse(true)
        local hl = r:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints(r)
        hl:SetColorTexture(1, 1, 1, 0.12)
        hl:Hide()
        r.text = label(r, 11)
        r.text:SetPoint("LEFT", r, "LEFT", 4, 0)
        r:SetScript("OnEnter", function() hl:Show() end)
        r:SetScript("OnLeave", function() hl:Hide() end)
        r:SetScript("OnMouseUp", function(self, button)
            if not self.peer then return end
            if button == "RightButton" then
                offer(self.peer, self)
            else
                closeMenu()
                follow(self.peer)
            end
            refresh()
        end)
        r:Hide()
        rows[i] = r
    end

    menu = CreateFrame("Frame", nil, list)
    menu:SetSize(170, 22)
    menu:EnableMouse(true)
    local mb = menu:CreateTexture(nil, "BACKGROUND")
    mb:SetAllPoints(menu)
    mb:SetColorTexture(0.1, 0.1, 0.15, 0.95)
    menu.text = label(menu, 11)
    menu.text:SetPoint("LEFT", menu, "LEFT", 8, 0)
    menu:SetScript("OnMouseUp", function()
        local p = menu.peer
        closeMenu()
        if p then
            startView(p)
            refresh()
        end
    end)
    menu:Hide()

    area:SetScript("OnShow", refresh)
    area:SetScript("OnHide", function()
        -- The window closed: its requests went with it (tied to it and to the view); the menu and the mark go too.
        closeMenu()
        names = {}
        viewing, following = nil, nil
        viewFrame:Hide()
        C_Minimap.ClearMark(MARK)
    end)
    return true
end

-- Anything that needs you leaves the view at once: your health drops (attacked; a death is the drop to 0), a dialog opens
-- (TK_DIALOG_SHOW, with the dialog's name).
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UNIT_HEALTH")
events:RegisterEvent("TK_DIALOG_SHOW")
events:RegisterEvent("TK_MAP_WINDOW_MAP")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "TK_MAP_WINDOW_MAP" then
        -- The window shows another map than the followed peer's (Centre, or the window closed): their place is no
        -- longer shown, so it is no longer asked. Before their first answer nothing was moved yet.
        if following and following.map and unit ~= following.map then unfollow() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not area then build() end
    elseif event == "UNIT_HEALTH" and unit == "player" then
        local now = UnitHealth("player")
        if viewing and health and now and now < health then leave(now <= 0 and "you died" or "you were hurt") end
        health = now
    elseif event == "TK_DIALOG_SHOW" and unit ~= "MiniMapDialog" then -- not the map window's own (the server's 70)
        leave("a dialog opened")
    end
end)

build()
C_Timer.NewTicker(1, function()
    if area or build() then refresh() end
end)
