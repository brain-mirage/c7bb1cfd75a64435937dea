-- s6-library round 13 (the owner, 2026-10-04: "it needs a way to traverse different maps with the M map. IE use learned
-- data like where waypoints go to add markers to the map that the user can click to go to that map and so on. There are
-- some cases where teleports going to random areas so you will need to handle that."): the map window's exits lead on.
--
-- A click on an exit's marker shows the map it leads to, around the cell it arrives at (the window's Map:ShowAt, s6-peer's:
-- the map cache's cells, fog where it has none), with that map's NPCs and exits from the Library and the arrival marked.
-- Back shows the place shown before; Centre goes back to the player and clears that history. A random teleport (an exit
-- seen in play leading to several places) lists its places on a click, as does a right-click on any exit, each place
-- clickable; an exit whose place is not known says so, and a map the cache has nothing of is fog. The exits are the
-- Library's, learned in play or filled from the server's files, and their labels say which. Drawing and navigation only:
-- nothing is sent.

local W = TK.UI
local H = __tk

local REFRESH = 2   -- seconds between reads of a shown map's markers from the Library

local T = { history = {}, arrival = nil, markers = nil }
TK.MapTraversal = T

--- A Library marker row (__tk:GetLibraryMarkers, GetLibraryMapMarkers: an NPC, or an exit with its places) made the
--- marker the map draws, in the colours the Library's markers are drawn in: NPCs gold, exits green, a random teleport
--- violet. The player's map's layer (core/library/markers.lua) and another map's (below) both draw the rows so.
--- s6-optimize (round 64): the row itself, as each layer copied it field by field before.
function T.Style(m)
    if m.kind == "npc" then
        m.icon, m.r, m.g, m.b = "tk:ring", 1, 0.82, 0.25
    elseif m.random then
        m.icon, m.r, m.g, m.b = "tk:arrow-right", 0.8, 0.5, 1
    else
        m.icon, m.r, m.g, m.b = "tk:arrow-right", 0.35, 1, 0.45
    end
    return m
end

local function here()
    local known, _, map = H:GetLocation()
    return known and map or nil
end

function T:CanGoBack() return #self.history > 0 end

--- Shows a place where an exit leads: its map around its cell (another map's from the cache, all fog where it has none;
--- the player's own map is a pan), or (nil) the player.
local function show(place)
    local Map = TK.MapWindow
    if not place then
        T.arrival = nil
        Map:Centre()
        return
    end
    local name = place.name ~= nil and place.name ~= "" and (place.name .. " (" .. place.map .. ")") or ("map " .. place.map)
    Map:ShowAt(place.map, place.x, place.y, name)
    T.arrival = place
    T.markers = nil
end

--- Goes where an exit leads. What the window shows now goes on the history (Back): the place Map:ShowAt last showed,
--- whoever asked (round 14: a map a peer or the Library's Maps page opened too, not only an exit's), or the player; and
--- the arrival marked there.
function T:Go(place)
    local shown, arrival = TK.MapWindow.shown, self.arrival
    -- Round 15 (Astra's P2 on round 14): a place shown on the player's own map is a pan the view leaves when the player
    -- changes maps; the window then shows the player's new map, and that (the player) is what Back returns to.
    if shown and shown.map ~= TK.MapWindowShownMap() then shown, arrival = nil, nil end
    self.history[#self.history + 1] = { shown = shown, arrival = arrival }
    show(place)
end

--- The place shown before (the player at the bottom of the history).
function T:Back()
    local n = #self.history
    if n == 0 then return end
    local before = self.history[n]
    self.history[n] = nil
    local s = before.shown
    if s then TK.MapWindow:ShowAt(s.map, s.x, s.y, s.name) else TK.MapWindow:Centre() end
    self.arrival, self.markers = before.arrival, nil
end

--- No history: the window opens on the player's map.
function T:Reset()
    self.history, self.arrival, self.markers = {}, nil, nil
end

--- Back to the player; the history goes.
function T:Home()
    self:Reset()
    show(nil)
end

--- A marker clicked on the map window (its pin). An exit with one place leads there; a random teleport, or a right-click
--- on an exit, lists its places beside the pin (each clickable); an exit with none says so.
function T:Clicked(m, button, pin)
    if m.kind ~= "warp" then return end
    local places = m.places or {}
    if #places == 0 then
        TK.MapWindow:Say("Where this exit leads is not known yet.")
        return
    end
    if #places == 1 and not m.random and button ~= "RightButton" then return self:Go(places[1]) end
    local entries = { { text = m.random and ("Random teleport: " .. #places .. " places known") or "This exit leads to", title = true } }
    for _, p in ipairs(places) do
        entries[#entries + 1] = { text = p.text .. "  (" .. p.seen .. ")", onClick = function() T:Go(p) end }
    end
    W.OpenMenu(entries, pin)
end

-- The markers of a map the window shows instead of the player's: its NPCs and exits from the Library (read again every
-- few seconds); and, on whichever map, the cell the exit last followed arrives at. The player's own map's NPCs and exits
-- are library.lua's layer. s6-library round 19: on a server's cached maps (the Library's View, Map:OpenOn; server is its
-- key) that server's, at the login screen too.
TK.MapMarkers:AddLayer("traversal", function(map, server)
    if not TK.GameState:InWorld() and not server then return nil end
    local out = {}
    local shown = TK.MapWindow.elsewhere
    if shown and shown.map == map and (server or map ~= here()) then
        local now = GetTime()
        if not T.markers or T.markers.map ~= map or T.markers.server ~= server or now - T.markers.at > REFRESH then
            local list = {}
            for _, r in ipairs(H:GetLibraryMapMarkers(map, server)) do list[#list + 1] = T.Style(r) end
            T.markers = { map = map, server = server, at = now, list = list }
        end
        for _, m in ipairs(T.markers.list) do out[#out + 1] = m end
    end
    local a = T.arrival
    -- s6-library round 19 (Astra's P2): the arrival is the map window's, so on another server's maps (a viewer) never on
    -- the playing session's minimap.
    if a and a.map == map and TK.MapWindow:IsShown() and server == TK.MapWindow.viewer then
        out[#out + 1] = { id = "traversal:arrival", map = a.map, x = a.x, y = a.y, label = "Where the exit arrives",
            icon = "tk:circle", r = 1, g = 1, b = 1 }
    end
    return out
end)

return T
