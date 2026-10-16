-- The Library's Maps page (s6-library rounds 2-12's lines; rebuilt by s6-library-pages round 2, the owner, 2026-10-04:
-- "maps should list each map, sorted by SIZE of map and then alphabetically by default. Each should let you view the map
-- by clicking view. It basically opens the worldmap like ingame."). The list is every map the Library knows, the largest
-- first, then by name, after one row for the world maps (0x2E) and their places. A map's page has its size and when it
-- was seen, View (the map window on that map, from the server's map cache, the login screen too: TK.MapWindow:OpenOn,
-- s6-library round 19), its exits (a random
-- teleport with every place it was seen leading to: round 3, from s6-library round 13's warp_others), the world maps'
-- places (waypoints) that lead to it, its NPCs and its creatures. Read only: nothing is sent; View only draws.

local W = TK.UI
local L = TK.Library
local X = L.Lines

local DIM = { 0.62, 0.62, 0.66 }

local page = { id = "maps", title = "Maps", order = 60, list = true, search = "Search maps (name or id)",
    empty = "None recorded yet." }

--- The map window on the map, its middle in view. FOR s6-library-pages (s6-library round 19, the owner: "why the view for
--- the maps don't work at all"): View works everywhere, the login screen too, from the Library's server's map cache
--- (TK.MapWindow:OpenOn), in front of this window; a map the cache has nothing of says so.
local function view(m)
    TK.MapWindow:OpenOn(L.server, m.id, math.floor(m.width / 2), math.floor(m.height / 2), m.name ~= "" and m.name or ("Map " .. m.id))
    local known, _, here = __tk:GetLocation()
    local live = TK.MapWindow.viewer == nil and known and here == m.id -- the player's own map, drawn as it is now
    if not live and not __tk:LibraryMapCached(L.server, m.id) then TK.MapWindow:Say("Not explored yet.") end
end

function page:build(area)
    self.name = W.Label(area, "", 18, W.gold, "LEFT")
    self.name:SetPoint("TOPLEFT", area, "TOPLEFT", 4, -4)
    self.info = W.Label(area, "", 12, W.white, "LEFT")
    self.info:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -6)
    -- Clear Map Data (as in the settings: every map tracker), and View beside it.
    self.clear = X.ClearButton(area, 150)
    self.clear:SetPoint("TOPRIGHT", area, "TOPRIGHT", -8, -2)
    self.view = W.Button(area, "View", 90, 24, nil, function() if self.shown then view(self.shown) end end)
    self.view:SetPoint("RIGHT", self.clear, "LEFT", -8, 0)
    self.detail = TK.LibraryDetail(area, 78)
end

--- Off notes for the map trackers whose switch is off (what was recorded stays and shows).
local function offNotes(d)
    local on = L.data and L.data.on
    if not on then return end
    for _, t in ipairs({ { "map_names", "Map names" }, { "warps", "Warp links" }, { "world_map", "World maps" },
        { "map_npcs", "NPCs" }, { "map_creatures", "Creatures per map" } }) do
        if on[t[1]] == false then d:Text(t[2] .. ": " .. X.OFF, "note") end
    end
end

--- The world maps' row: each world map with its places and where each leads.
local function showWorld(self, d, e)
    self.shown = nil
    self.view:Hide()
    L:Say(self.name, "World maps")
    L:Say(self.info, "World maps: " .. #e.worldMaps) -- s6-library round 18: label and value
    for _, wm in ipairs(e.worldMaps) do
        d:Header(wm.name)
        d:Text(X.stamp(wm.seen), "dim")
        for _, n in ipairs(wm.nodes) do d:Text(n.name .. "  to " .. n.destination .. " at " .. n.x .. ", " .. n.y, "text", 8) end
    end
end

function page:show(_, m)
    X.SetClear(self.clear, "maps", X.groupIds("Maps"), nil, "Clear Map Data")
    local d = self.detail
    d:Begin(L.entryKey)
    if m == nil or m.missing or m.loading then
        self.shown = nil
        self.view:Hide()
        L:Say(self.name, m and m.loading and "Reading the Library..." or "")
        self.info:SetText("")
        -- Nothing chosen, or the chosen map is gone (Clear Map Data).
        if not m or m.missing then d:Text(L.filters.maps and L.filters.maps ~= "" and "No map by that name." or "None recorded yet.", "dim") end
        d:End()
        return
    end
    offNotes(d)
    if m.world then
        showWorld(self, d, m)
        d:End()
        return
    end
    self.shown = m
    self.view:Show() -- s6-library round 19: everywhere, from the server's map cache (view above)
    L:Say(self.name, m.name ~= "" and m.name or ("Map " .. m.id))
    L:Say(self.info, m.label .. (m.width > 0 and ("  -  " .. m.width .. " x " .. m.height) or "  -  size not known") .. "  -  " .. X.stamp(m.seen))
    -- FOR s6-library-pages (s6-library round 19, cross-links): a place's map, an NPC and a monster open their own pages.
    d:Header("Exits")
    if #m.exits == 0 then d:Text("None recorded.", "dim") end
    for _, w in ipairs(m.exits) do
        local go = L.LinkTo("maps", w.toKnown and w.toMap or nil)
        -- s6-library round 3: an exit is a cell the player walked onto; a record of the old rule waits, uncertain, until seen again.
        if w.certain and #w.others > 0 then
            -- Round 3 (s6-library round 13's warp_others): a random teleport, every place it was seen leading to, the latest first.
            d:Text("Random teleport at " .. w.x .. ", " .. w.y .. ": " .. (#w.others + 1) .. " places known", "text", 8)
            d:Text("to " .. w.to .. " at " .. w.toX .. ", " .. w.toY .. X.rowStamp(w.seen, "last taken"), "text", 24, go)
            for _, o in ipairs(w.others) do
                d:Text("to " .. o.to .. " at " .. o.x .. ", " .. o.y .. X.rowStamp(o.seen, "last taken"), "dim", 24, L.LinkTo("maps", o.map))
            end
        elseif w.certain then
            d:Text("Exit at " .. w.x .. ", " .. w.y .. " to " .. w.to .. " at " .. w.toX .. ", " .. w.toY .. X.rowStamp(w.seen, "last taken"), "text", 8, go)
        else
            d:Text("Uncertain: " .. w.x .. ", " .. w.y .. " to " .. w.to .. " at " .. w.toX .. ", " .. w.toY, "dim", 8, go)
        end
    end
    d:Header("Waypoints here")
    if #m.waypoints == 0 then d:Text("None seen.", "dim") end
    for _, p in ipairs(m.waypoints) do d:Text(p.world .. ": " .. p.name .. "  arrives at " .. p.x .. ", " .. p.y, "text", 8) end
    d:Header("NPCs")
    if #m.npcs == 0 then d:Text("None recorded.", "dim") end
    for _, n in ipairs(m.npcs) do
        -- s6-library round 7: an NPC whose name no look has taught yet (the server names none).
        d:Text((n.name ~= "" and n.name or "Unnamed NPC") .. " at " .. n.x .. ", " .. n.y .. X.rowStamp(n.seen), "text", 8,
            L.LinkTo("npcs", n.key))
    end
    d:Header("Creatures")
    if #m.creatures == 0 then d:Text("None recorded.", "dim") end
    for _, c in ipairs(m.creatures) do
        d:Text((c.name ~= "" and c.name or "Creature") .. " at " .. c.x .. ", " .. c.y .. X.rowStamp(c.seen), "dim", 8,
            L.LinkTo("monsters", c.look))
    end
    d:End()
end

L:AddPage(page)
