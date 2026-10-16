-- The Library's own layer of map markers (s6-library round 2, head note 3; moved out of library.lua by
-- s6-library-pages): its NPCs and exits on the map window and the minimap, gone when their tracker is off for the
-- server. Read only: nothing is sent.

local H = __tk

local markers = { key = nil, list = {} }

-- The map markers (core/mapmarkers.lua) load after this file and take this table as their layers.
-- Round 4 (review r2 finding 6): the markers are kept for one key (the session, its server, the map, what it recorded,
-- a switch or a Clear) and forgotten outside the world, so another session never shows this one's.
TK.MapMarkerLayers = TK.MapMarkerLayers or {}
TK.MapMarkerLayers.library = function(map, server)
    -- Round 19: the playing session's map only; another server's cached maps (the map window's View) are the traversal
    -- layer's (core/maptraversal.lua).
    if server then return nil end
    if not TK.GameState:InWorld() then
        markers.key, markers.list = nil, {}
        return nil
    end
    local key = H:LibraryMarkersKey()
    if key ~= markers.key then
        markers.key = key
        markers.list = {}
        -- s6-library round 13 (the map window's traversal): an exit keeps its places, and a random teleport has its colour.
        -- s6-optimize (round 64): the rows styled as the traversal's own (core/maptraversal.lua, loaded with the core).
        for _, r in ipairs(H:GetLibraryMarkers()) do markers.list[#markers.list + 1] = TK.MapTraversal.Style(r) end
    end
    local out = {}
    for _, m in ipairs(markers.list) do
        if m.map == map then out[#out + 1] = m end
    end
    return out
end
