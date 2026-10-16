-- Map markers (plan D26's revision, the owner 2026-10-01): a small API through which plugins put markers on the map; the
-- minimap and the map window both draw them. A marker is a cell of a map, with a label (its tooltip) and an icon (a
-- texture key: tk:circle unless given, or any art: or icon: key) in a colour. Markers belong to the server the player
-- logged in to (the login screen's server address). One a plugin asks to keep (persist) is saved in this computer's
-- settings (machine.json, mapMarkers[server][id]) and is back at the next login to that server; the others last for
-- the session.
--
--   TK.MapMarkers:Set(id, { map = , x = , y = , label = , icon = , r = , g = , b = , persist = })   adds or moves one
--   TK.MapMarkers:Remove(id)          takes one off (and forgets it if it was kept)
--   TK.MapMarkers:List([map])         this server's markers (only that map's, if given), sorted by id
--
-- s6-peer's channel and the sandboxed plugins (C_Minimap.SetMark) reach it through TK.MinimapMarks.Set.

local M = { sets = {}, version = 0 }
TK.MapMarkers = M

local function server()
    local s = TK.Login and TK.Login.server
    return s and s.address or "local"
end

--- This server's kept markers in the machine settings; made on demand.
local function kept(create)
    local m = TK.Machine:Get()
    if type(m.mapMarkers) ~= "table" then
        if not create then return nil end
        m.mapMarkers = {}
    end
    local k = server()
    if type(m.mapMarkers[k]) ~= "table" then
        if not create then return nil end
        m.mapMarkers[k] = {}
    end
    return m.mapMarkers[k]
end

local function marker(id, m, persist)
    return { id = id, map = math.floor(m.map), x = math.floor(m.x), y = math.floor(m.y), label = tostring(m.label or ""),
             icon = type(m.icon) == "string" and m.icon ~= "" and m.icon or "tk:circle",
             r = tonumber(m.r) or 0.3, g = tonumber(m.g) or 0.85, b = tonumber(m.b) or 1, persist = persist }
end

--- This server's markers, the kept ones read in at the first ask.
function M:Markers()
    local k = server()
    local set = self.sets[k]
    if set then return set end
    set = {}
    self.sets[k] = set
    for id, m in pairs(kept(false) or {}) do
        if type(id) == "string" and type(m) == "table" and tonumber(m.map) and tonumber(m.x) and tonumber(m.y) then
            set[id] = marker(id, m, true)
        end
    end
    return set
end

function M:Set(id, m)
    if type(id) ~= "string" or type(m) ~= "table" or not tonumber(m.map) or not tonumber(m.x) or not tonumber(m.y) then return end
    local set = self:Markers()
    local was = set[id]
    local new = marker(id, m, m.persist == true)
    set[id] = new
    if new.persist then
        kept(true)[id] = { map = new.map, x = new.x, y = new.y, label = new.label, icon = new.icon, r = new.r, g = new.g, b = new.b }
        TK.Machine:MarkDirty()
    elseif was and was.persist then
        kept(true)[id] = nil
        TK.Machine:MarkDirty()
    end
    self.version = self.version + 1
end

function M:Remove(id)
    local set = self:Markers()
    local was = set[id]
    if not was then return end
    set[id] = nil
    if was.persist then
        kept(true)[id] = nil
        TK.Machine:MarkDirty()
    end
    self.version = self.version + 1
end

-- s6-library round 2: other marker layers (the Library's NPCs and exits, head note 3), drawn with the plugins' markers
-- but never listed to them: TK.MapMarkers:AddLayer(name, function(map) return { markers } end).
-- The core loads before the components, so a core module's layer may already wait in TK.MapMarkerLayers.
M.layers = TK.MapMarkerLayers or {}
TK.MapMarkerLayers = M.layers

function M:AddLayer(name, fn) self.layers[name] = fn end

--- What the map draws: the plugins' markers and every layer's, on that map; and the set of the layers' (s6-world-view,
--- round 23: the minimap piles only the plugins' few at its edge). s6-library round 19: on <server>'s cached maps (the
--- map window's Library View, Map:OpenOn) only the layers that take a server (fn(map, server)) draw; the plugins'
--- markers are the playing server's.
function M:Drawn(map, server)
    local out, layered = server and {} or self:List(map), {}
    for _, fn in pairs(self.layers) do
        local ok, list = pcall(fn, map, server)
        if ok and type(list) == "table" then
            for _, m in ipairs(list) do
                out[#out + 1] = m
                layered[m] = true
            end
        end
    end
    return out, layered
end
-- end of s6-library

function M:List(map)
    local out = {}
    for _, m in pairs(self:Markers()) do
        if map == nil or m.map == map then out[#out + 1] = m end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- s6-peer's entry (its PeerDriver, for C_Minimap.SetMark and GetMarks): TK.MinimapMarks.Set(id, map, x, y, label, r, g,
-- b[, icon[, persist]]), an id alone taking the marker off; TK.MinimapMarks.List(), this server's markers.
TK.MinimapMarks = {
    Set = function(id, map, x, y, label, r, g, b, icon, persist)
        if map == nil then
            M:Remove(id)
        else
            M:Set(id, { map = map, x = x, y = y, label = label, r = r, g = g, b = b, icon = icon, persist = persist })
        end
    end,
    List = function() return M:List() end,
}

-- ----- the pins the minimap and the map window draw the markers with -----

--- A pool of pins on a frame: each the marker's icon in its colour, its label the tooltip.
function M.NewPins(parent, size)
    local pins = { parent = parent, size = size }
    function pins:Get(i)
        local p = self[i]
        if p then return p end
        p = CreateFrame("Frame", nil, self.parent)
        p:SetSize(self.size, self.size)
        p:SetFrameLevel(self.parent:GetFrameLevel() + 5)
        p.icon = p:CreateTexture(nil, "OVERLAY")
        p.icon:SetAllPoints(p)
        p:EnableMouse(true)
        p:SetScript("OnEnter", function(pin)
            GameTooltip:SetOwner(pin, "ANCHOR_LEFT")
            GameTooltip:AddLine(pin.label ~= "" and pin.label or "A marker", 1, 1, 1)
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- s6-library round 13: a click on a pin goes to the pool's owner (the map window: an exit leads on), with its
        -- marker and the pin.
        p:SetScript("OnMouseUp", function(pin, button)
            if self.onClick and pin.marker then self.onClick(pin.marker, button, pin) end
        end)
        self[i] = p
        return p
    end
    --- Puts marker m's pin number i at (dx, dy) from the frame's top left (y down), dimmed when off the view.
    --- s6-optimize (round 4): a pin is the pool's own, so it keeps where it is, its tint and whether it shows, and a
    --- refresh where it did not change sets nothing again.
    function pins:Place(i, m, dx, dy, dim)
        local p = self:Get(i)
        if p.dx ~= dx or p.dy ~= dy then
            p:ClearAllPoints()
            p:SetPoint("CENTER", self.parent, "TOPLEFT", dx, -dy)
            p.dx, p.dy = dx, dy
        end
        if p.iconKey ~= m.icon then
            p.iconKey = m.icon
            p.icon:SetTexture(m.icon)
        end
        local a = dim and 0.55 or 1
        if p.r ~= m.r or p.g ~= m.g or p.b ~= m.b or p.a ~= a then
            p.icon:SetVertexColor(m.r, m.g, m.b, a)
            p.r, p.g, p.b, p.a = m.r, m.g, m.b, a
        end
        p.label = m.label
        p.id = m.id
        p.marker = m -- s6-library round 13
        if not p.visible then
            p.visible = true
            p:Show()
        end
    end
    function pins:HideFrom(n)
        for i = n, #self do
            local p = self[i]
            if p.visible ~= false then
                p.visible = false
                p:Hide()
            end
        end
    end
    return pins
end

--- Lays out the markers on the player's map over a live picture's frame (its texture texWidth pixels across): each at
--- its cell's middle from the picture's top-left cell and zoom. Off the picture: a plugin's marker at its edge, dimmed
--- (edge > 0, the minimap), else not drawn; a layer's (the Library's NPCs and exits, many on a big map) never piled at
--- the edge (round 23). Returns how many pins show. s6-peer (round 12): onMap, the map the picture shows when it is not the
--- player's (the map window moved there by a plugin). s6-library round 19: server, the server whose cached map it shows
--- (the Library's View: M:Drawn), at the login screen too.
function M.Layout(pins, frame, key, texWidth, edge, onMap, server)
    local H = __tk
    local n = 0
    local known, _, map = H:GetLocation()
    map = onMap or map
    local ok, x0, y0 = H:OffsetLive(key)
    if (known or server) and ok then
        local w, h = frame:GetWidth(), frame:GetHeight()
        local k = w * H:ZoomLive(key, 0) / texWidth   -- UI units a cell
        local drawn, layered = M:Drawn(map, server) -- s6-library: with the other layers
        for _, m in ipairs(drawn) do
            local dx, dy = (m.x + 0.5 - x0) * k, (m.y + 0.5 - y0) * k
            local off = dx < 0 or dy < 0 or dx > w or dy > h
            local clamp = edge and off and not layered[m]
            if clamp then
                dx, dy = math.max(edge, math.min(w - edge, dx)), math.max(edge, math.min(h - edge, dy))
            end
            if clamp or not off then
                n = n + 1
                pins:Place(n, m, dx, dy, off)
            end
        end
    end
    pins:HideFrom(n + 1)
    return n
end

return M
