-- The minimap (plan 5.11, UI head notes 35 and 36): a framed square with the zone name above it and the player's
-- cell below. Both come from where the player is (__tk:GetLocation): in a live session the map's name from its 0x15
-- and the player's cell; in Play Offline's mock world, the mock's stand-in place. In a live session the square shows
-- the world view's picture of the cached cells (fog of war); only the mock world draws the placeholder's grid and dot.
-- Nothing is requested for it.
--
-- The owner's revision (plan D26, 2026-10-01; s6-world-view round 17): the picture is zoomed in (8 pixels a cell at
-- first) and a map that fits the box is scaled up to fill it; + and - (and the wheel) zoom in and out, 2 to 16 pixels a
-- cell, and send nothing. M opens the map window (core/mapwindow.lua), as does the Map button (the original's minimap button: 7C).
-- The plugins' markers (core/mapmarkers.lua) are drawn over it, one off the picture at its edge, dimmed.
--
-- The border icons (the owner, 2026-10-02; border.lua): outside the box, each dragged along its border in edit mode.
-- - The time and the weather, in place of round 15's clock picture (coverage G-39): the game
--   hour of the server's 0x20, as 4a's HourPane takes it, with its minute, and a weather-report icon for day or night and
--   the weather the server last set (1F: rain, snow, swallows, or none); nothing before the first 0x20. Its tooltip says
--   both in words. s6-ui-core (round 37, the owner): in the bottom row with the mail and parcels, the time and then its
--   icon ("19:49" then the moon), no longer with the location label.
-- - Mail and parcels, side by side under the box: the bottom icons' state (4a's ParcelIconPane, the dialog model's
--   ParcelPane: the 08 tail's counts, parcels the low nibble, letters the high), each "some" or "none", hidden at none
--   with the setting on. They are that pane's two controls too: a press goes to its own, a release to the one under
--   the pointer then (either icon or a bottom button), so they send what the bottom buttons send (review r19).
-- The icons keep clear of each other and of the location label (round 21, border.lua: a dropped one slides to the
-- nearest free place). The pointer over a shown icon is over the minimap, for its fade. The icons are Twemoji 17.0.3
-- glyphs (CC-BY 4.0, THIRD-PARTY-NOTICES.md). The captions (coverage D-78, kept by the head as the map's name and the
-- player's cell) are the zone and coordinates labels, from the live session. s6-ui-core (round 37, the owner): the zone
-- name is the minimap's location label, centred above the box (where the time was), or inside it under its N where the
-- screen's top leaves no room; the Location Label setting turns it off.

local C = TK.GetComponent("minimap")
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local U = TK.Util
local H = __tk
local Markers = require("core.mapmarkers")
local Border = require("interfaces.modern.panels.minimap.border")

local MINIMAP = "live:minimap"
local MINIMAP_PIXELS = 256   -- the picture's width in texture pixels (MinimapPicture.Key)

local ICON = 24   -- the border icons' side, about the bottom mail and parcel buttons' size (30 x 25)
local ZONE_HEIGHT = 14   -- the zone name's line (12 with its outline)

-- The weather the server sets (1F, 4a's MapPane weather types) and what a weather report would say for it.
local WEATHER = { [0] = "clear", "raining", "snowing", "clear, with swallows in the air" }

--- The game time as text (the hour as the clock takes it, and its minute), or nil with no hour.
function C.TimeText(hour, minute)
    if hour < 0 then return nil end
    return string.format("%02d:%02d", hour, minute)
end

--- The weather-report icon (a Twemoji emoji key) for the weather and the time of day: rain behind a sun by day and a
--- rain cloud at night, a snow cloud, else the sun or the moon.
function C.WeatherIcon(weather, night)
    if weather == 1 then return night and "emoji:1f327" or "emoji:1f326" end
    if weather == 2 then return "emoji:1f328" end
    return night and "emoji:1f319" or "emoji:2600"
end

--- The weather in words, as the tooltip says it: "Night, raining". Night is by the hour alone (__tk:GetGameTime: the
--- original's brightness table for the hour); the darkness 4a draws also follows the map's brightness adjustments, so
--- on a map that changes it the tooltip's day or night is an approximation.
function C.WeatherText(weather, night)
    return (night and "Night" or "Day") .. ", " .. (WEATHER[weather] or WEATHER[0])
end

-- Mail (the letters, the ParcelPane's right button: control 1) and parcels (the left: control 0).
local MAIL = { control = 1, some = "emoji:1f4eb", none = "emoji:1f4ea", name = "Mail", noneText = "No mail" }
local PARCEL = { control = 0, some = "emoji:1f4e6", none = "emoji:1f4e6", name = "Parcels", noneText = "No parcels" }

--- A side's count from the bottom icons' state (0 without them): the game layer's (s6-input round 49, TK.Game.Parcels).
function C.ParcelCount(kind)
    return (TK.Game.Parcels.Count(kind.control))
end

function C:OnEnable()
    local f = CreateFrame("Frame", "TKMinimap", UIParent)
    TK.Game.Minimap.SetFrame(f) -- s6-input (round 49, separation step 4b): the interface's minimap, for the Debug page
    f:SetBackdrop({ bg = { 0.12, 0.2, 0.12, 0.9 }, edge = { 0.7, 0.62, 0.42, 1 } })
    TK.UI.HudPanel(f, C) -- s6-ui-settings (round 4): the shared panel style; s6-ui-core (round 53): or its own
    -- The mock world's placeholder: a faint grid and the player's dot, so it reads as a map.
    f.lines = {}
    for i = 1, 6 do
        local v = f:CreateTexture(nil, "ARTWORK")
        v:SetColorTexture(1, 1, 1, 0.07)
        v:SetWidth(1)
        local h = f:CreateTexture(nil, "ARTWORK")
        h:SetColorTexture(1, 1, 1, 0.07)
        h:SetHeight(1)
        f.lines[i] = { v, h }
    end
    -- s6-world-view (round 10): in a live session, the cached cells' picture (fog of war) with the player and the
    -- objects in view; drawn by the world view, updated in place.
    f.map = f:CreateTexture(nil, "ARTWORK")
    f.map:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    f.map:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    f.map:SetTexture(MINIMAP)
    f.map:Hide()
    f.dot = f:CreateTexture(nil, "OVERLAY")
    f.dot:SetSize(10, 10)
    f.dot:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.dot:SetTexture("tk:circle")
    f.dot:SetVertexColor(1, 0.85, 0.2, 1)
    local north = W.Label(f, "N", 12, W.gold)
    north:SetFont(12, "OUTLINE")
    north:SetPoint("TOP", f, "TOP", 0, -7)
    f.north = north
    f.zone = W.Label(f, "", 12, W.gold)
    f.zone:SetFont(12, "OUTLINE")
    f.zone:SetPoint("BOTTOM", f, "TOP", 0, 6)
    f.coords = W.Label(f, "", 10, W.white)
    f.coords:SetFont(10, "OUTLINE")
    f.coords:SetPoint("BOTTOM", f, "BOTTOM", 0, 5)
    -- s6-world-view (round 17): the plugins' markers, over the picture.
    f.marks = CreateFrame("Frame", nil, f)
    f.marks:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    f.marks:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    f.marks:SetFrameLevel(f:GetFrameLevel() + 2)
    f.pins = Markers.NewPins(f.marks, 9)
    -- A button's one-line tooltip, opening to the left as the minimap's others do. s6-optimize (round 64): the zoom
    -- buttons' and the Map button's, each written out before.
    local function buttonTip(b, text)
        b:SetScript("OnEnter", function(button)
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            GameTooltip:AddLine(text, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    -- The zoom (the owner, 2026-10-01: + and - zoom, and no longer open the big map); the wheel zooms too.
    local function zoomButton(text, step, tip)
        local b = W.Button(f, text, 18, 18, nil, function() C:Zoom(step) end)
        b:SetFrameLevel(f:GetFrameLevel() + 4)
        buttonTip(b, tip)
        return b
    end
    -- The original's minimap button (MiniMapButtonPane, coverage G-40 and H-24): m's action (7C, by the rules), which the
    -- map window follows (core/mapwindow.lua). Wire (s6-input round 49, separation step 4b): its click is the game
    -- layer's one minimap press, TK.Game.Minimap.Press (MiniMapButtonPane 0x005036A0: nothing while the model's minimap
    -- dialog is open); changing when it runs changes what the server sees.
    f.mapButton = W.Button(f, "Map", 34, 18, nil, function() TK.Game.Minimap.Press() end)
    f.mapButton:SetFrameLevel(f:GetFrameLevel() + 4)
    f.mapButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 3, 3)
    TK.Actions:Set(f.mapButton, "minimap")
    buttonTip(f.mapButton, "The map (M)")
    f.zoomIn = zoomButton("+", 1, "Zoom in")
    f.zoomIn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    f.zoomOut = zoomButton("-", -1, "Zoom out")
    f.zoomOut:SetPoint("BOTTOM", f.zoomIn, "TOP", 0, 2)
    -- s6-gate round 19: named, so the gate's driver can click them (core/gatecontrols.lua logs the shown TK globals)
    _G.TKMinimapMap, _G.TKMinimapZoomIn, _G.TKMinimapZoomOut = f.mapButton, f.zoomIn, f.zoomOut
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) if not f.mock then C:Zoom(delta > 0 and 1 or -1) end end)
    -- s6-world-view (round 19): the border icons.
    local function tooltip(item, lines)
        item:SetScript("OnEnter", function(i)
            GameTooltip:SetOwner(i, "ANCHOR_LEFT")
            for n, line in ipairs(lines(i)) do
                if n == 1 then GameTooltip:AddLine(line, 1, 1, 1) else GameTooltip:AddLine(line, 0.8, 0.8, 0.8) end
            end
            if TK.EditMode.unlocked then GameTooltip:AddLine("Drag it along the minimap's border.", 0.6, 0.6, 0.6) end
            GameTooltip:Show()
        end)
        item:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local db = function() return self:DB() end
    -- The time, then its weather icon on its right (s6-ui-core round 37, the owner), in the bottom row.
    f.clock = Border.New(f, "TKMinimapClock", "timeAt", C.defaults.timeAt, db)
    f.clock:SetSize(ICON + 44, ICON)
    f.clock.time = W.Label(f.clock, "", 13, W.white, "LEFT")
    f.clock.time:SetFont(13, "OUTLINE")
    f.clock.time:SetPoint("LEFT", f.clock, "LEFT", 0, 0)
    f.clock.icon = f.clock:CreateTexture(nil, "OVERLAY")
    f.clock.icon:SetSize(ICON, ICON)
    f.clock.icon:SetPoint("LEFT", f.clock.time, "RIGHT", 4, 0)
    tooltip(f.clock, function(i) return { "Time " .. (i.timeText or ""), i.weatherText or "" } end)
    f.clock:Hide()
    -- Mail and parcels: the ParcelPane's two controls (review r19). A press goes to the icon's control; its release to
    -- the pane's control under the pointer then (s6-input round 49, separation step 4b: the game layer's one press path,
    -- TK.Game.Parcels; the icons are its controls outside edit mode, where they are dragged instead). Wire: this is the
    -- input path of 4a's ParcelIconPane (ParcelPane::HandlePointerOrMouseEvent 0x00546610: control 0 the parcels, 1 the
    -- letters, as the bottom buttons'), so the press, its release and their control index are what the server sees;
    -- changing them changes what it sees. Showing or hiding an icon (its switch, hideEmptyMail) sends nothing.
    local function parcelItem(kind, name, at)
        local item = Border.New(f, name, kind == MAIL and "mailAt" or "parcelAt", at, db, function(_, down, button)
            TK.Game.Parcels.Press(kind.control, down, button)
        end)
        item.kind = kind
        TK.Game.Parcels.Control(item, kind.control)
        item:SetSize(ICON, ICON)
        item.icon = item:CreateTexture(nil, "OVERLAY")
        item.icon:SetAllPoints(item)
        tooltip(item, function(i)
            local n = C.ParcelCount(kind)
            return { n > 0 and (kind.name .. ": " .. n) or kind.noneText }
        end)
        item:Hide()
        return item
    end
    f.mail = parcelItem(MAIL, "TKMinimapMail", C.defaults.mailAt)
    f.parcel = parcelItem(PARCEL, "TKMinimapParcel", C.defaults.parcelAt)
    f.parcelItems = { f.mail, f.parcel }
    f.layout = {}   -- the parts of the last layout Refresh arranged for
    -- f.borderItems (Border.New) holds them in this order: the time keeps its place first, then the mail, the parcels.
    -- The location label's room is the box's own: the icons keep clear of it (s6-ui-core round 37).
    f.reserved = function(m)
        if not f.zone:IsShown() or f.zone:GetText() == "" then return {} end
        local half = f.zone:GetStringWidth() / 2 + 2
        local bottom = C.ZoneSpot(f, m) == "box" and m.h + 6 or m.h - 22 - ZONE_HEIGHT
        return { { m.w / 2 - half, bottom, m.w / 2 + half, bottom + ZONE_HEIGHT } }
    end
    -- The pointer over a shown border icon is over the minimap, for its fade (TK.Visibility asks the frame; review r19).
    local overBox = f.IsMouseOver
    function f:IsMouseOver()
        if overBox(self) then return true end
        for _, item in ipairs(self.borderItems) do
            if item:IsShown() and item:IsMouseOver() then return true end
        end
        return false
    end
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        GameTooltip:AddLine("Minimap", 1, 1, 1)
        local zone = frame.zone:GetText()
        if zone ~= "" then GameTooltip:AddLine(zone .. "  " .. frame.coords:GetText(), 0.8, 0.8, 0.8) end
        GameTooltip:AddLine("Wheel or + and -: zoom.  M: the map.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Where the player is, read a few times a second; the labels change only when it does.
    f:SetScript("OnUpdate", U.Throttled(0.1, function() self:Refresh() end))
    self.frame = f
    TK.Visibility:Attach(f, function() return self:DB() end)
    TK.EditMode:Register(f, "minimap", "Minimap", C.defaultPosition, "minimap")
end

--- Where the location label goes, the box measured (Border.Measure): "box", centred above it; or "inside", under its
--- N, where the screen's top leaves no room above (a minimap saved near the top, as at round 18's default place).
function C.ZoneSpot(f, m)
    local top = m.s and m.b + m.h * m.s
    return (not top or top + (6 + ZONE_HEIGHT) * m.s <= m.sh) and "box" or "inside"
end

local function placeZone(f)
    local zone = f.zone
    zone:ClearAllPoints()
    if C.ZoneSpot(f, Border.Measure(f)) == "box" then zone:SetPoint("BOTTOM", f, "TOP", 0, 6)
    else zone:SetPoint("TOP", f, "TOP", 0, -22) end
end

--- Zooms the minimap's picture in (step > 0) or out (< 0); returns its pixels a cell.
function C:Zoom(step) return H:ZoomLive(MINIMAP, step) end

-- s6-ui-core (round 39, s6-optimize's measurements): Refresh runs ten times a second and each frame method is a call
-- into C#, so it sets a shown state, a text, a colour or a texture only when its value changes. The last value is kept
-- in a field of the frame: nothing but Refresh sets these.

--- Shows or hides a region, if that changed since Refresh last set it.
local function show(region, shown)
    if region.shownSet ~= shown then
        region.shownSet = shown
        region:SetShown(shown)
    end
end

--- Whether any of the layout's parts differs from the last ones (kept in last), without building a key string.
local function moved(last, ...)
    local differs = false
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if last[i] ~= v then last[i], differs = v, true end
    end
    return differs
end

--- The zone and the cell from the location; the placeholder's grid and dot only in the mock world.
function C:Refresh()
    local f = self.frame
    local online = H:IsOnline()
    local known, zone, _, x, y = H:GetLocation()
    local zoneText = known and zone or ""
    local coords = known and (x .. ", " .. y) or ""
    if f.zoneText ~= zoneText then
        f.zoneText = zoneText
        f.zone:SetText(zoneText)
    end
    if f.coordsText ~= coords then
        f.coordsText = coords
        f.coords:SetText(coords)
    end
    -- s6-world-view (round 19): the time and the weather, from the last 0x20 and 1F. s6-interface-5x (round 13's hotfix):
    -- an icon turned off reads and draws nothing.
    local hour, minute, night, weather, timeText
    if not f.clock.off then
        hour, minute, night = H:GetGameTime()
        weather = H:GetWeather()
        timeText = C.TimeText(hour, minute)
    end
    if timeText then
        if f.clock.timeText ~= timeText then
            f.clock.timeText = timeText
            f.clock.time:SetText(timeText)
        end
        if f.clock.weather ~= weather or f.clock.night ~= night then
            f.clock.weather, f.clock.night = weather, night
            local icon = C.WeatherIcon(weather, night)
            if f.clock.iconKey ~= icon then
                f.clock.iconKey = icon
                f.clock.icon:SetTexture(icon)
            end
            f.clock.weatherText = C.WeatherText(weather, night)
        end
    end
    show(f.clock, timeText ~= nil)
    -- Mail and parcels: "some" or "none"; at none hidden with the setting on (shown in edit mode, to be placed).
    local hide = self:DB().hideEmptyMail
    local unlocked = TK.EditMode.unlocked
    for _, item in ipairs(f.parcelItems) do
        if item.off then
            show(item, false)
        else
            local n = C.ParcelCount(item.kind)
            local key = n > 0 and item.kind.some or item.kind.none
            if item.iconKey ~= key then
                item.iconKey = key
                item.icon:SetTexture(key)
            end
            -- A parcel with none is the package dimmed (Twemoji has no "no parcel").
            local dim = n == 0 and item.kind == PARCEL
            if item.dim ~= dim then
                item.dim = dim
                item.icon:SetVertexColor(dim and 0.55 or 1, dim and 0.55 or 1, dim and 0.55 or 1, dim and 0.6 or 1)
            end
            item.count = n
            show(item, online and (n > 0 or not hide or unlocked))
        end
    end
    -- Where the box is decides which icons fit outside it on the screen, and where the zone name goes; the icons keep
    -- clear of each other and of the zone name. Arranged again when the box, the screen, the time's showing, the zone
    -- name or a place changes (review r19, round 21); not during a drag.
    local l, b, w, h = U.RootRect(f)
    local dragging = f.clock.dragging or f.mail.dragging or f.parcel.dragging
    if l and not dragging then
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        if moved(f.layout, l, b, w, h, sw, sh, f.clock.shownSet, f.zoneShown, zoneText, f.clock.at, f.mail.at, f.parcel.at) then
            placeZone(f)
            Border.Arrange(f)
            -- the places Arrange chose are the last ones
            moved(f.layout, l, b, w, h, sw, sh, f.clock.shownSet, f.zoneShown, zoneText, f.clock.at, f.mail.at, f.parcel.at)
        end
    end
    local mock = not online
    if f.mock ~= mock then
        f.mock = mock
        f.dot:SetShown(mock)
        f.map:SetShown(not mock) -- s6-world-view
        f.mapButton:SetShown(not mock)
        f.zoomIn:SetShown(not mock)
        f.zoomOut:SetShown(not mock)
        f.marks:SetShown(not mock)
        for _, pair in ipairs(f.lines) do
            pair[1]:SetShown(mock)
            pair[2]:SetShown(mock)
        end
    end
    if not mock then Markers.Layout(f.pins, f.marks, MINIMAP, MINIMAP_PIXELS, 4) end
end

--- s6-ui-core (round 37, the owner): a profile from before the time moved to the bottom row (its clockAt) is carried
--- over once: a time left on the top edge's middle (its old place, where the location label is now), and mail and
--- parcels at their old defaults, take the new row; a place the player chose elsewhere stays.
function C:CarryOldLayout()
    local db = self:DB()
    if db.clockAt == nil then return end
    local old = tonumber(db.clockAt)
    if old and not (Border.Edge(old) == "top" and math.abs(old % 4 - 0.5) < 0.3) then db.timeAt = old end
    if db.mailAt == 2.59 then db.mailAt = nil end
    if db.parcelAt == 2.41 then db.parcelAt = nil end
    db.clockAt = nil
    TK.DB:MarkDirty()
end

function C:ApplySettings()
    self:CarryOldLayout()
    local db, f = self:DB(), self.frame
    f:SetSize(db.size, db.size)
    for i, pair in ipairs(f.lines) do
        local off = db.size * i / 7
        pair[1]:ClearAllPoints()
        pair[1]:SetPoint("TOP", f, "TOPLEFT", off, -3)
        pair[1]:SetPoint("BOTTOM", f, "BOTTOMLEFT", off, 3)
        pair[2]:ClearAllPoints()
        pair[2]:SetPoint("LEFT", f, "BOTTOMLEFT", 3, off)
        pair[2]:SetPoint("RIGHT", f, "BOTTOMRIGHT", -3, off)
    end
    f.zone:SetShown(db.showZone)
    f.zoneShown = db.showZone
    -- s6-modular-g (interfaces, phase 1): each icon is a panel with its own switch (settings.lua); one turned off
    -- is hidden, in edit mode too, and leaves its room on the border to the others (border.lua). Round 7 (Astra's
    -- review): and its own scale, on top of the minimap's; border.lua places it by its scaled size.
    f.clock.off, f.mail.off, f.parcel.off = not db.showClock, not db.showMail, not db.showParcels
    f.clock:SetScale(db.clockScale or 1)
    f.mail:SetScale(db.mailScale or 1)
    f.parcel:SetScale(db.parcelScale or 1)
    for _, item in ipairs(f.borderItems) do Border.Restore(item) end
    f.layout = {}
    self:Refresh()
    TK.Visibility:Apply(f)
end

-- C:ResetIconPlaces and C:ResetIconPlace are settings.lua's (s6-interface-5x round 13: the page runs them loaded or not)
