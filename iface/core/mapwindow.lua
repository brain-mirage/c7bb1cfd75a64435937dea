-- The map window (plan D26's revision, the owner 2026-10-01): M opens a movable window with the map of the cells the
-- client has (the world view's live:map picture: fog of war where no cell was received), zoomed with the wheel or its
-- - and + (2 to 48 pixels a cell; from 32 the cells are the art itself, 48 being the world view's own resolution),
-- dragged to pan, and back to the player with Centre or at each opening. It shows the player and the objects in view
-- (as the minimap does), the plugins' markers (TK.MapMarkers) and the cell under the pointer. M again, its close box
-- or Escape close it. Nothing is sent for any of that.
--
-- The wire stays 4a's: M runs the minimap action as before (core/commands.lua), so the rules send 7C while the dialog
-- model has no MiniMapDialog and close it when it has one (DialogRules.MinimapKey); the server's 70 opens the model's
-- dialog as before (4a's HandleOpenMiniMapPacket reads none of 70's data). The window opens, or closes, with each 7C
-- the rules send (review r17: the original's m asks for its minimap exactly then; only in a live session, offline there
-- is no map to show), opens with the model's dialog when a 70 arrives, and closes when the model's dialog closes. That
-- dialog is modal, so while it is open every key is its (components/dialogs): M closes it, as do Enter and Escape (its
-- close button, 6); the window's close box is that button then. Nothing is sent for any of them. The model's dialog has
-- no window of its own (components/dialogs/misc.lua).
--
-- s6-peer (round 12): the window hosts plugins (the sandbox's C_MapWindow): TK.MapWindowArea() is its map area, which a
-- plugin's own container covers, shown with the window; and Map:ShowAt moves the view to a map and cell (a plugin's
-- ShowMap: the base plugin's click on a peer), until Centre or the next opening brings it back to the player.

local W = TK.UI
local H = __tk

local MAP = "live:map"
local TW, TH = 768, 576   -- the picture's size in texture pixels (MinimapPicture.MapKey)

local Map = {}
TK.MapWindow = Map

-- s6-library round 13: the traversal (core/maptraversal.lua): an exit's marker shows the map it leads to (Map:ShowAt); Back
-- shows the map shown before, and Centre clears that history.
local Traversal = require("core.maptraversal")

--- The dialog model's open MiniMapDialog's (hidden) window, or nil.
local function modelDialog()
    local win = TK.Dialogs.Find("MiniMapDialog") -- s6-characters (round 46, separation step 6)
    return win and win.view and win or nil
end

function Map:Build()
    if self.frame then return self.frame end
    local f = W.Window("TKMapWindow", "Map", TW + 24, TH + 84)
    local box = CreateFrame("Frame", "TKMapWindowMap", f)
    box:SetSize(TW, TH)
    box:SetPoint("TOP", f, "TOP", 0, -38)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(box)
    bg:SetColorTexture(0, 0, 0, 1)
    box.map = box:CreateTexture(nil, "ARTWORK")
    box.map:SetAllPoints(box)
    box.map:SetTexture(MAP)
    box:EnableMouse(true)
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(_, delta) Map:Zoom(delta > 0 and 1 or -1) end)
    -- Dragged, the map follows the pointer: the drag in UI units as the texture's pixels, y down.
    box:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then box.drag = { TK.Util.CursorRoot() } end
    end)
    box:SetScript("OnMouseUp", function() box.drag = nil end)
    box:SetScript("OnUpdate", function() Map:Update() end)
    box.pins = TK.MapMarkers.NewPins(box, 12)
    box.pins.onClick = function(m, button, pin) Traversal:Clicked(m, button, pin) end -- s6-library round 13
    f.box = box

    f.zoomOut = W.Button(f, "-", 28, 22, nil, function() Map:Zoom(-1) end)
    f.zoomOut:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
    f.zoomIn = W.Button(f, "+", 28, 22, nil, function() Map:Zoom(1) end)
    f.zoomIn:SetPoint("LEFT", f.zoomOut, "RIGHT", 4, 0)
    f.zoom = W.Label(f, "", 11, { 0.8, 0.8, 0.8 }, "LEFT")
    f.zoom:SetPoint("LEFT", f.zoomIn, "RIGHT", 8, 0)
    f.centre = W.Button(f, "Centre", 70, 22, nil, function() Traversal:Home() end) -- s6-peer (round 12): Map:Centre
    f.centre:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    f.back = W.Button(f, "Back", 60, 22, nil, function() Traversal:Back() end) -- s6-library round 13
    f.back:SetPoint("RIGHT", f.centre, "LEFT", -6, 0)
    f.cell = W.Label(f, "", 11, { 0.8, 0.8, 0.8 }, "RIGHT")
    f.cell:SetPoint("RIGHT", f.back, "LEFT", -10, 0)

    -- While the model's dialog is open, the close box is its close button (6): the press and the release go to it, as
    -- the original's button took them (they ride the click's own records), and the dialog closes, the window with it. A
    -- release off the box is a release outside the dialog's controls (-1), as K.Wire reports it (review r17). s6-input
    -- (round 51, the class of Astra's final review of round 50, P2): "off the box" is wherever the box is not the frame
    -- on top (TK.ReleaseTarget), so a frame lying over the box takes the release, as 4a's release reaches the control
    -- drawn at its point (DialogPane::HandlePointerOrMouseEvent 0x0049E240). Wire: control 6 closes the model's dialog,
    -- after which M sends 7C again (DialogRules.MinimapKey); changing which release closes it changes what the next M
    -- sends.
    -- Wire: the press and release are the model's MiniMapDialog's (D-66, 0x00450CA0) control 6, whose click schedules its
    -- close (timer 5 after 1 ms, OnTimer 0x00451C90). The close sends nothing, but while the dialog is open it takes the
    -- keys (modal), so changing the control or the release's mapping changes when the game's keys reach the server again.
    local function closePointer(button, down, control)
        local dialog = modelDialog()
        if dialog then TK.Dialogs.Pointer(dialog, control, button, down) end -- the kit's (separation step 6)
    end
    f.close:HookScript("OnMouseDown", function(_, button) closePointer(button, true, 6) end)
    f.close:HookScript("OnMouseUp", function(_, button)
        closePointer(button, false, TK.ReleaseTarget(button) == f.close and 6 or -1)
    end)

    f:HookScript("OnShow", function()
        Traversal:Reset() -- s6-library round 13: no history
        H:ShowLive(MAP, true)
        Map:Centre()   -- each opening starts at the player (s6-peer round 12: Map:Centre)
        Map:Zoom(0)
        f.centre:SetShown(Map.viewer == nil) -- s6-library round 19: a server's cached maps have no player to centre on
        local o = Map.opening -- s6-library round 19: the map Map:OpenOn asked for
        Map.opening = nil
        if o then Map:ShowAt(o.map, o.x, o.y, o.name) end
    end)
    f:HookScript("OnHide", function()
        box.drag = nil
        H:ShowLive(MAP, false)
    end)
    f.strata = f:GetFrameStrata() -- s6-library round 19: M's, put back after the Library's View (Map:Open)
    self.frame = f
    return f
end

function Map:IsShown() return self.frame ~= nil and self.frame:IsShown() end

--- The dialog model's minimap dialog is open (the server's 70 came): modal, it takes the keys and the clicks.
function Map:ModelOpen() return modelDialog() ~= nil end

function Map:Open()
    if not TK.GameState:InWorld() or not H:IsOnline() then return end
    local f = self:Build()
    -- s6-library round 19: M's window is the player's, at its own strata, whatever the Library's View left.
    if self.viewer or f:GetFrameStrata() ~= f.strata then
        f:Hide()
        self.viewer = nil
        f:SetFrameStrata(f.strata)
    end
    self.opening = nil
    f:Show()
end

--- s6-library round 19 (the owner, 2026-10-05: "why the view for the maps don't work at all"; View on the Library's Maps
--- page working everywhere, from the map cache): the window on map <map> of <server> (a Library key), its middle on (x,
--- y), titled <name>, in front of the Library window (its strata: the window was behind it before). In the world on the
--- playing session's own server it is M's window moved there (ShowAt). Anywhere else (the login screen, or another
--- server's Library) it shows that server's cached maps only (self.viewer): no player, no Centre; exits still lead on
--- (the traversal) within that server's maps, and it closes when the game screen changes. Drawing only: nothing is sent.
function Map:OpenOn(server, map, x, y, name)
    local f = self:Build()
    local playing = TK.GameState:InWorld() and H:IsOnline() and server == H.SessionServer
    -- Shown afresh, so it rises in front of the other windows of its strata (a toplevel window: core/escape.lua); its
    -- OnShow, which starts at the player, then moves it to the map asked for (self.opening).
    f:Hide()
    self.viewer, self.viewerInWorld = not playing and server or nil, TK.GameState:InWorld()
    self.opening = { map = map, x = x, y = y, name = name }
    f:SetFrameStrata("DIALOG")
    f:Show()
end

--- Hides it (a request, or the model's dialog closed).
function Map:CloseQuietly()
    if self:IsShown() then self.frame:Hide() end
end

--- A minimap request went (7C: M, or the minimap's Map button, while no minimap dialog exists): the window opens, or
--- closes. The key that closes the model's dialog sends none; that dialog's closing closes the window.
function Map:Toggle()
    if self:IsShown() then self:CloseQuietly() else self:Open() end
end

--- s6-peer (round 12): the view back on the player.
function Map:Centre()
    self.elsewhere = nil
    self.shown = nil -- s6-library round 14: on the player (what the traversal's Back returns to)
    H:CentreLive(MAP)
end

--- s6-peer (round 12): the view on map <map>, its middle on cell (x, y), titled <name> (another map's name is not known
--- here); the player's own map is a pan from the player. Until Centre, the next opening, or the player's arriving there.
function Map:ShowAt(map, x, y, name)
    self:Build()
    local known, _, here = H:GetLocation()
    -- s6-library round 19: a server's cached maps (Map:OpenOn) are always elsewhere, the player's map number or not.
    self.elsewhere = (self.viewer or not (known and here == map)) and { map = map, name = name } or nil
    -- s6-library round 14: the place shown, on whichever map and whoever asked (an exit, a peer, the Library's Maps page, a
    -- plugin), so the traversal's Back can return to it.
    self.shown = { map = map, x = x, y = y, name = name }
    H:ShowAtLive(MAP, map, x, y, self.viewer) -- round 19: from that server's map cache (nil: the session's)
end

--- s6-peer (round 12): the map area's handle, for the plugins' container over it (the window built if it was not); and
--- the plugins' ShowMap.
function TK.MapWindowArea() return Map:Build().box.__h end
function TK.MapWindowShowAt(map, x, y, name) Map:ShowAt(map, x, y, name) end

--- s6-peer (round 13): the map the window shows (the one moved to, else the player's), nil while it is closed or the
--- player's map is not known: the plugins' C_MapWindow.GetMap and TK_MAP_WINDOW_MAP.
function TK.MapWindowShownMap()
    if not Map:IsShown() then return nil end
    local known, _, here = H:GetLocation()
    if Map.elsewhere and (Map.viewer or not (known and here == Map.elsewhere.map)) then return Map.elsewhere.map end
    return known and here or nil
end

function Map:Zoom(step)
    local z = H:ZoomLive(MAP, step)
    if self.frame then
        self.frame.zoom:SetText(z .. " px a cell" .. (z >= 48 and " (full resolution)" or ""))
    end
    return z
end

--- Each frame while shown: the drag, the title, the cell under the pointer and the markers.
function Map:Update()
    local f = self.frame
    local box = f.box
    -- s6-library round 19: a server's cached maps (Map:OpenOn) close when the game screen changes (the login, the world).
    if self.viewer and TK.GameState:InWorld() ~= self.viewerInWorld then return self:CloseQuietly() end
    if box.drag then
        local x, y = TK.Util.CursorRoot()
        local dx, dy = x - box.drag[1], y - box.drag[2]
        if dx ~= 0 or dy ~= 0 then
            local k = TW / box:GetWidth()
            H:PanLive(MAP, dx * k, -dy * k)
            box.drag = { x, y }
        end
    end
    local known, zone, here = H:GetLocation()
    -- s6-peer (round 12): shown elsewhere, the title and the markers are that map's, until the player arrives there
    -- (s6-library round 19: never on a server's cached maps, where there is no player).
    local other = self.elsewhere
    if other and not self.viewer and known and here == other.map then
        self.elsewhere, other = nil, nil
    end
    local title = other and ("Map: " .. (other.name or ("map " .. other.map))) or known and ("Map: " .. zone) or "Map"
    if f.title:GetText() ~= title then f.title:SetText(title) end
    f.back:SetShown(Traversal:CanGoBack()) -- s6-library round 13
    local cell = ""
    local ok, x0, y0 = H:OffsetLive(MAP)
    if ok and box:IsMouseOver() then
        local x, y = TK.Util.CursorRoot()
        local l, b, w, h = TK.Util.RootRect(box)
        local k = w * H:ZoomLive(MAP, 0) / TW
        cell = math.floor(x0 + (x - l) / k) .. ", " .. math.floor(y0 + (b + h - y) / k)
    end
    if f.said and GetTime() < f.saidUntil then cell = f.said end -- s6-library round 13: a message for a few seconds
    if f.cell:GetText() ~= cell then f.cell:SetText(cell) end
    -- s6-peer (round 12): the map shown; s6-library round 19: of the server the Library's View shows
    TK.MapMarkers.Layout(box.pins, box, MAP, TW, nil, other and other.map, self.viewer)
end

--- s6-library round 13: a short message in the window's bottom line (where the cell under the pointer shows), for a few seconds.
function Map:Say(text)
    if not self.frame then return end
    self.frame.said, self.frame.saidUntil = text, GetTime() + 4
end

-- Each frame: the session's minimap requests (each one toggles the window; in a live session the rules take m
-- themselves, so the binding's own script does not run), then the model's dialog (the window opens with it, the
-- server's 70, and closes with it). A new session counts from 0 again. s6-ui-core (round 101, T11 step 3): called only
-- on the frames the requests changed, and on the next frame after the dialogs' windows changed (TK_DIALOGS_CHANGED, raised
-- by the dialogs' own OnUpdate, later in the frame: the next frame, as this watch saw them before).
local watch = CreateFrame("Frame", "TKMapWindowWatch", UIParent)
watch:SetSize(1, 1)
local modelOpen, asked = false, 0
watch:SetScript("OnUpdate", function()
    local n = H:GetMinimapRequests()
    for _ = asked + 1, n do Map:Toggle() end
    asked = n
    local open = modelDialog() ~= nil
    if open ~= modelOpen then
        modelOpen = open
        if open then Map:Open() else Map:CloseQuietly() end
    end
end)
watch:SetUpdateWhen("minimap")
TK.On("TK_DIALOGS_CHANGED", function() watch:SetUpdateWhen("minimap") end)

return Map
