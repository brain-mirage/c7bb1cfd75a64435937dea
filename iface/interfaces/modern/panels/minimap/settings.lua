local C = TK.GetComponent("minimap")

C.defaults = TK.Visibility.Defaults({
    size = 170,
    showZone = true,   -- the location label (s6-ui-core round 37, the owner: the minimap's own, at its top)
    -- s6-world-view (round 19): the border icons' places (border.lua) and the mail and parcel icons' hiding. s6-ui-core
    -- (round 37, the owner): the time and the weather in the bottom row with the mail and parcels, in that order, the
    -- row centred under a box of the default size (timeAt replaced clockAt: an older profile's is carried over, main.lua).
    timeAt = 2.665,
    mailAt = 2.371,
    parcelAt = 2.206,
    hideEmptyMail = false,
    -- s6-modular-g (interfaces, phase 1): each border icon's own switch and (round 7, Astra's review) its own
    -- scale (its page, below)
    showClock = true,
    showMail = true,
    showParcels = true,
    clockScale = 1,
    mailScale = 1,
    parcelScale = 1,
})

-- Low enough for the zone name and the time above the box (round 19).
C.defaultPosition = { "TOPRIGHT", "TOPRIGHT", -20, -62 }

C:StandardSettings("minimap", {
    { type = "header", name = "Map" },
    { type = "range", key = "size", name = "Size", min = 100, max = 320, step = 2 },
    { type = "toggle", key = "showZone", name = "Location Label" },
}, { transparency = true, layoutExtra = { -- s6-ui-core (round 53): its own transparency (TK.PanelTransparencyArgs)
    { type = "header", name = "Border Icons" },
    { type = "description", name = "The clock and weather, mail and parcel icons sit on the minimap's border, each with its own page (its scale on top of the minimap's). Unlock the layout (edit mode) to drag them along the border." },
    { type = "execute", name = "Reset Icon Places", resets = true, func = function() C:ResetIconPlaces() end }, -- s6-ui-settings: the reset icon runs it too
} })

-- s6-modular-g (interfaces, phase 1; docs/development/interfaces.md, "A panel"): the clock and weather, the
-- mail and the parcel icons are panels of their own: each a page with its switch and a Layout tab (its scale, on top of
-- the minimap's, and its place on the minimap's border), listed under Indicators (phase 2). Their settings stay the
-- minimap's (they are drawn on its border), so the places a profile saved before them are theirs unchanged.

local EDGES = { { value = 0, text = "Top" }, { value = 1, text = "Right" }, { value = 2, text = "Bottom" },
                { value = 3, text = "Left" } }

--- A place on the border (border.lua: 0 to 4 once round the box, clockwise from its top-left corner) as its edge and how
--- far along that edge, 0 to 1: from the left on the top and bottom edges, from the top on the sides.
function C.EdgeAndAlong(at)
    at = at % 4
    local edge = math.floor(at)
    local f = at - edge
    return edge, edge >= 2 and 1 - f or f
end

--- The place on the border for an edge and how far along it (C.EdgeAndAlong's inverse), kept on that edge.
function C.PlaceOn(edge, along)
    local f = edge >= 2 and 1 - along or along
    return edge + math.max(0, math.min(f, 0.999))
end

-- s6-interface-5x (round 13, the separation's step 11): the page's changes are drawn only while the minimap is loaded
-- (on); off, the profile keeps them for its start.
local function apply()
    if C:Loaded() then C:ApplySettings() end
end

--- The border icons back at their default places (the settings' button).
function C:ResetIconPlaces()
    local db = self:DB()
    db.timeAt, db.mailAt, db.parcelAt = nil, nil, nil
    TK.DB:MarkDirty()
    apply()
end

--- s6-modular-g (interfaces, phase 1): one icon back at its default place (its page's Reset Position); key is
--- where its place is kept (timeAt, mailAt or parcelAt).
function C:ResetIconPlace(key)
    self:DB()[key] = nil
    TK.DB:MarkDirty()
    apply()
end

--- The Layout tab of the border icon kept at db[key], its scale at db[scaleKey]: its scale (from the minimap's: 1 is
--- the minimap's own), its edge, where along it, and its reset. The icon goes to the nearest free place there (border.lua
--- keeps the icons clear of each other and of the location label).
local function iconLayout(key, scaleKey)
    local function at() return tonumber(C:DB()[key]) or C.defaults[key] end
    local function place(edge, along)
        C:DB()[key] = C.PlaceOn(edge, along)
        apply()
    end
    return {
        { type = "description", name = "On the minimap's border; its scale on top of the minimap's. Unlock the layout (edit mode) to drag it along the border." },
        { type = "range", key = scaleKey, name = "Scale", min = 0.1, max = 2, step = 0.05 },
        { type = "break" },
        { type = "select", name = "Edge", values = EDGES,
          get = function() return (C.EdgeAndAlong(at())) end,
          set = function(_, edge) local _, along = C.EdgeAndAlong(at()); place(edge, along) end },
        { type = "range", name = "Along the Edge (%)", min = 0, max = 100, step = 1,
          get = function() local _, along = C.EdgeAndAlong(at()); return math.floor(along * 100 + 0.5) end,
          set = function(_, v) place((C.EdgeAndAlong(at())), v / 100) end },
        { type = "execute", name = "Reset Position", resets = true, func = function() C:ResetIconPlace(key) end },
    }
end

local function iconNode(id, title, sub, switch, key, scaleKey, about, hideEmpty)
    local general = { { type = "toggle", key = switch, name = "Enabled" }, { type = "description", name = about } }
    -- s6-optimize (round 34): one saved Hide Empty value serves both icons, but each page declares its own
    -- Enabled need. main.lua tests each icon's switch before showing it, so only the enabled icon takes the value.
    if hideEmpty then
        general[#general + 1] = { type = "group", requires = { TK.NeedSetting(switch) }, args = {
            { type = "toggle", key = "hideEmptyMail", name = "Hide the mail and parcel icons when there is none" },
        } }
    end
    return {
        id = id,
        title = title,
        -- s6-ui-core (round 83; the owner, 2026-10-09: the Minimap "is a separate pane", each pane expanding to its pages):
        -- the icons on its border are its pages, under it in the Interface list's Panes (still panels of their own)
        parent = "minimap",
        order = C.order,
        sub = sub,
        db = function() return C:DB() end,
        defaults = function() return C.defaults end,
        tabs = {
            { name = "General Settings", args = general },
            { name = "Layout", args = iconLayout(key, scaleKey) },
        },
    }
end

local baseNodes = C.SettingsNodes
function C:SettingsNodes()
    local nodes = baseNodes(self)
    nodes[#nodes + 1] = iconNode("minimapclock", "Clock and Weather", 2, "showClock", "timeAt", "clockScale",
        "The game's time from the server, and an icon for the weather and the time of day.")
    nodes[#nodes + 1] = iconNode("minimapmail", "Mail Icon", 3, "showMail", "mailAt", "mailScale",
        "Whether a letter waits. A click does what the original's letter button does.", true)
    nodes[#nodes + 1] = iconNode("minimapparcels", "Parcel Icon", 4, "showParcels", "parcelAt", "parcelScale",
        "Whether a parcel waits. A click does what the original's parcel button does.", true)
    return nodes
end
