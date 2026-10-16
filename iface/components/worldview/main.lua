-- The world view (plan 4.4 and 5.10). The world is one object on the canvas: a WorldView frame showing
-- a render texture drawn at 1x. It sits in the BACKGROUND strata so the rest of the UI is in front of it, and it
-- moves and resizes like any other frame.
--
-- s6-input (round 49; docs/development/interface-separation.md, step 4b and section 5.12): every interface's shared panel,
-- TK.WorldView (this component): its frame, TileSize, TileCentre (s6-world-view round 39: CellCentre), MapPoint,
-- CentrePoint, TileAtCursor, SetMapEffects and SetShadows, with PlaceAt (an interface's screen putting it at its map view: one copy for 7.x's and 5.x's) and Set (one
-- of its settings changed from an interface's own options, 5.x's See-Through row).
-- s6-input (round 50): what is drawn round the view is the active interface's look (C:Dress, below), not the view's.

local C = TK.GetComponent("worldview")
TK.WorldView = C
local W = TK.UI

--- s6-input (round 50, separation step 4b; interface-separation.md 4.3 and 5.12): the frame's look, the active interface's
--- drawing round the shared view, given by its manifest's worldViewLook: a file of its own folder that builds the look on
--- the frame and returns its label and everything it drew (Modern's grey edge and map-title label). 7.x and 5.x give none:
--- their screens draw round their map view. Read by the interface's id, as the dialogs' look is.
--- s6-input (round 52): a switch in place (TK_INTERFACE_CHANGED, plan 5.16: a reader of the active interface follows it)
--- hides the old interface's look and shows the new one's, each built once. It stays on the view's own frame, not a frame
--- over it: the zone border (TK.WorldView's ZoneBorder) is the frame's last child, over its own edge and under every other
--- frame. f.look is the active interface's ({ label, parts }), or nil. Drawing only.
function C:Dress()
    local f = self.frame
    if f.look then
        for _, r in ipairs(f.look.parts) do r:Hide() end
    end
    f.look = nil
    local id = TK.Interfaces.active
    local interface = id and TK.Interfaces:Get(id)
    if not (interface and interface.worldViewLook) then return end
    local look = self.looks[id]
    if look then
        for _, r in ipairs(look.parts) do r:Show() end
    else
        local label, parts = require("interfaces." .. id .. "." .. interface.worldViewLook)(f)
        look = { label = label, parts = parts }
        self.looks[id] = look
    end
    f.look = look
end

function C:OnEnable()
    local f = CreateFrame("WorldView", "TKWorldView", UIParent)
    f:SetFrameStrata("BACKGROUND")
    self.frame, self.looks = f, {}
    self:Dress()
    TK.On("TK_INTERFACE_CHANGED", function()
        self:Dress()
        self:UpdateLabel()
    end)
    -- Head note 47: in live play without the art packs the world can't be drawn: the view says so instead of showing
    -- the placeholder world, which stays the offline mode's.
    local noArt = CreateFrame("Frame", "TKWorldViewNoArt", f)
    noArt:SetAllPoints(f)
    noArt:SetFrameLevel(f:GetFrameLevel() + 20)
    local shade = noArt:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints(noArt)
    shade:SetColorTexture(0.05, 0.05, 0.06, 1)
    noArt.text = W.Label(noArt, TK.Art.NO_PACKS_TEXT, 16, { 1, 0.7, 0.3 })
    noArt.text:SetPoint("CENTER", noArt, "CENTER", 0, 0)
    noArt:Hide()
    local function checkArt() noArt:SetShown(__tk:IsOnline() and not TK.Art.Available()) end
    TK.On("TK_GAME_STATE", checkArt)
    checkArt()
    -- An item picked up in the bag and put down on the world is dropped, as the original's drag onto the map (08).
    local function dropHeld()
        local held = TK.Cursor:Get()
        if not held or held.kind ~= "item" or held.from ~= "bag" then return end
        ClearCursor()
        -- s6-ui-bag (review r1): only a release on the map drops (InventoryPane.cpp:1174-1178); the far view's ring is
        -- not the original's map, so a release there only ends the carry.
        if __tk:InventoryDropOnMap() or self:TileAtCursor() then TK.Actions:RunFrozen() end -- round 22: interface drop rectangle
    end
    -- While an item from the bag is on the cursor, the world's action is dropping it (08).
    -- s6-ui-bag seam: on the path of the original's drag (NewInventoryPane 0x004ECB50): the click that puts it down is
    -- that drag's release over the map, 08 slot 00 for any slot without asking, and its press is no map press (no walk).
    -- s6-modular-g (round 21, the owner's research on presses reaching the wrong place): while the cursor holds any other
    -- action (a spell, a macro, an action button's) and no mouse button is down, the world takes no press: a click there
    -- is a click on nothing, which puts the action down (core/cursor.lua's GLOBAL_MOUSE_DOWN), as a click outside every
    -- frame does. It walked, talked (43 01) or looked and kept the action before. WIRE: the original has no such cursor, so
    -- with none held, and with a bag item (the drop above), the map's presses are as before; and while a button is down
    -- (the drag that picked the action up, from a spell list or a bar) the map keeps its presses and the drag's release, as
    -- 4a's spell list takes no capture for its drag (SpellInventoryPane.cpp has no CaptureMouse), so that release and a
    -- right press during the drag reach MapPane::HandlePointerOrMouseEvent 0x00507150. Changing this changes what the server
    -- sees.
    -- "A button is down" is the UI's own pressed state (__tk:AnyFramePressed), which every release clears, the ones the
    -- rules' capture takes too (they fire no GLOBAL_MOUSE_UP; Astra's self-review 21-1), and a focus loss. While such an
    -- action is held it is looked at each frame, so a release is routed (the drag's drop on the frame under it) before the
    -- world stops taking presses.
    local watch = CreateFrame("Frame", nil, UIParent)
    watch:Hide()
    watch:SetScript("OnUpdate", function() f:EnableMouse(__tk:AnyFramePressed()) end)
    local function takesPresses()
        local held = TK.Cursor:Get()
        local free = held == nil or (held.kind == "item" and held.from == "bag")
        watch:SetShown(not free)
        f:EnableMouse(free or __tk:AnyFramePressed())
    end
    TK.On("CURSOR_CHANGED", function()
        local held = TK.Cursor:Get()
        if held and held.kind == "item" and held.from == "bag" then
            TK.Actions:Set(f, "drop", held.slot)
            TK.Actions:SetPath(f, "InventoryDrag")
        else
            TK.Actions:Clear(f)
            TK.Actions:SetPath(f, "")
        end
        takesPresses()
    end)
    f:EnableMouse(true)
    f:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then dropHeld() end end)
    f:SetScript("OnReceiveDrag", dropHeld)
    f:RegisterEvent("UI_SCALE_CHANGED")
    f:SetScript("OnEvent", function() self:ApplySettings() end)
    TK.On("DISPLAY_SIZE_CHANGED", function() self:ApplySettings() end) -- s6-world-view (round 29): Auto, Stretch, Auto Extend
    -- The map picture names the map it shows (head note 13).
    f:SetScript("OnMapTitleChanged", function() self:UpdateLabel() end)
    TK.On("TK_EDIT_MODE", function() self:UpdateLabel() end)
    TK.Visibility:Attach(f, function() return self:DB() end)
    self.entry = TK.EditMode:Register(f, "worldview", "World View", C.defaultPosition, "worldview", nil, {
        minWidth = 240,
        minHeight = 200,
        set = function(w, h)
            local db = self:DB()
            db.width, db.height = w, h
            self:ApplySettings()
            TK.DB:MarkDirty()
        end,
    })
end

-- ----- s6-world-view (round 29): the scale and the outer area's size -----

local TILE, LIVE_COLS, LIVE_ROWS = 48, 17, 15
local FIXED = { ["0.5"] = 0.5, ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4 }

--- The settings before round 29 (a profile still holding scaleMode), carried over once: "1x (native)" to Auto, the
--- whole-number upscale with factor n to Fixed nx, "Smooth" to Stretch with Smooth, xBR with factor n to Fixed nx with
--- xBR. The old default darkness (0.75), which the saved profile cannot tell from a chosen 0.75, takes the new default.
function C:CarryOver(db)
    if db.scaleMode == nil then return end
    local factor = tostring(math.floor((tonumber(db.factor) or 2) + 0.5))
    if not FIXED[factor] then factor = "2" end
    if db.scaleMode == "integer" then db.worldScale, db.smoothing = factor, "none"
    elseif db.scaleMode == "xbr" then db.worldScale, db.smoothing = factor, "xbr"
    elseif db.scaleMode == "smooth" then db.worldScale, db.smoothing = "stretch", "smooth"
    else db.worldScale, db.smoothing = "auto", "none" end
    if db.outerDim == 0.75 then db.outerDim = C.defaults.outerDim end
    db.scaleMode, db.factor = nil, nil
    TK.DB:MarkDirty()
end

--- s6-modular-d (Retro rule 16): the presentation the Tiles' drawing style asks for, { cols, rows, factor }, or nil for
--- the world view's own (the default style). Retro's old version view: at least 21 x 19 (or 29 x 19) cells, smaller by
--- the factor, filtered linear. The live area and the clicks are unchanged: one scale maps the picture and the input.
function C:Presentation()
    local G = CS.TK.Modular.Draw.GraphicsStyles
    local cols, rows, factor = string.match(G.WorldPresentation(), "^(%d+);(%d+);([%d%.eE+-]+)$")
    if not cols then return nil end
    return { cols = tonumber(cols), rows = tonumber(rows), factor = tonumber(factor) }
end

--- How the world view is laid out, in screen pixels: the picture's cells, its scale, and the frame's size.
---   The space: the frame's set size, or the game window.
---   Auto: 1x while what must fit fits in the space (the live area, or with Include Outer Area the whole picture),
---         smaller when it does not; never larger. Fixed: its factor. Stretch: what must fit, filling the space.
---   Auto Extend: as many cells as cover the space at that scale (part cells at the edges); without a set size the
---         frame covers the whole window from where its centre is.
---   A presentation (s6-modular-d, Retro): the scale times its factor, and at least its cells.
function C:Fit(db, f, presentation)
    local ui = TK.UIScale()
    local px = ui * f:GetEffectiveScale()
    local screenW, screenH = GetScreenWidth() * ui, GetScreenHeight() * ui
    local setW = (db.width or 0) > 0 and db.width * px or nil
    local setH = (db.height or 0) > 0 and db.height * px or nil
    local spaceW, spaceH = setW or screenW, setH or screenH
    local band = db.expandLive and 1 or 0
    local cols, rows = db.cols, db.rows
    if band == 1 then cols, rows = math.max(cols, LIVE_COLS + 2), math.max(rows, LIVE_ROWS + 2) end
    -- s6-modular-d (Retro rule 16): at least the presentation's cells, here and after Auto Extend's cover
    local function presented(c, r)
        if not presentation then return c, r end
        return math.max(c, presentation.cols), math.max(r, presentation.rows)
    end
    cols, rows = presented(cols, rows)
    local scale = FIXED[db.worldScale]
    if not scale then
        local mustW, mustH = (LIVE_COLS + 2 * band) * TILE, (LIVE_ROWS + 2 * band) * TILE
        -- s6-optimize (round 33): as its row's needs say (Auto Extend off, Scale Auto or Stretch: Component:Applied)
        if self:Applied("includeOuter", db) then mustW, mustH = cols * TILE, rows * TILE end
        local fit = math.min(spaceW / mustW, spaceH / mustH)
        scale = db.worldScale == "stretch" and fit or math.min(1, fit)
    end
    if presentation then scale = scale * presentation.factor end -- s6-modular-d (Retro rule 16)
    local frameW, frameH = setW, setH
    if db.autoExtend then
        if not setW or not setH then
            -- Cover the window from the frame's centre wherever edit mode put it.
            local l, b, w, h = TK.Util.RootRect(f)
            local dx = l and math.abs(l + w / 2 - GetScreenWidth() / 2) * ui or 0
            local dy = l and math.abs(b + h / 2 - GetScreenHeight() / 2) * ui or 0
            frameW, frameH = setW or screenW + 2 * dx, setH or screenH + 2 * dy
        end
        local function cover(space, live)
            local n = math.ceil(space / (TILE * scale))
            return live + 2 * math.max(0, math.ceil((n - live) / 2))
        end
        cols, rows = presented(cover(frameW, LIVE_COLS), cover(frameH, LIVE_ROWS))
    end
    frameW = frameW or math.floor(cols * TILE * scale + 0.5)
    frameH = frameH or math.floor(rows * TILE * scale + 0.5)
    return cols, rows, scale, frameW, frameH, px
end

local SCALE_NAMES = { auto = "Auto", stretch = "Stretch" }

--- The look's label, where the active interface's look has one: the map's title (from the map picture); the view's
--- settings only while the frames are unlocked, for the layout (head note 35: nothing but the session's data in play).
function C:UpdateLabel()
    local db, f = self:DB(), self.frame
    local label = f.look and f.look.label
    if not label then return end
    local title = f:GetMapTitle()
    if not TK.EditMode.unlocked then return label:SetText(title) end
    local nw, nh = f:GetNaturalSize()
    -- s6-world-view (round 29): the owner's names, and the scale as worked out
    local scale = string.format("%s %.2gx", SCALE_NAMES[db.worldScale] or "Fixed", self.scale or 1)
    if db.smoothing ~= "none" and (self.scale or 1) > 1 then scale = scale .. ", " .. db.smoothing end
    label:SetText(string.format("%s  %d x %d tiles, live %s, outer area %d%% darker, %s",
        title ~= "" and title or "World View", nw / 48, nh / 48, db.expandLive and "19 x 17" or "17 x 15",
        math.floor(db.outerDim * 100 + 0.5), scale))
end

function C:ApplySettings()
    local db, f = self:DB(), self.frame
    self:CarryOver(db) -- s6-world-view (round 29)
    -- [View] OriginalColour16 and the original's graphics options are read by the map picture at each configure, so
    -- they are set first.
    f:SetOriginalColour16(db.originalColour16 ~= false)
    CS.TK.WorldView.SmoothMovement.Enabled = db.smoothMovement == true -- s6-characters (round 45): drawing only; s6-world-view (round 39): off by default
    -- s6-world-view (round 39): its Fix 2D Flicker's box; the drawing takes it only with Smooth Character Movement on and
    -- Normal drawing, the row's needs (SmoothMovement.Fixes). Drawing only.
    CS.TK.WorldView.SmoothMovement.FixFlicker = db.fix2dFlicker ~= false
    -- s6-upscale (the owner, 2026-10-08): the Upscaling rows, live; a greyed row's box is kept and not applied
    -- (Component:Applied). Drawing only.
    CS.TK.WorldView.ArtUpscaling.Apply(db.upscaleMethod or "none", C.UpscaleScale(db), self:Applied("upscaleBlend", db) == true,
        self:Applied("upscaleBlendPalette", db) == true)
    f:SetOriginalOptions(db.shadows ~= false, db.seeThrough ~= false, db.objectTransparency == true)
    -- s6-effects-c (round 8): See-Through's child, read at the next configure; s6-optimize (round 33): off while See-Through
    -- is off (its row's need: Component:Applied), its own box kept
    f:SetFadeOver(self:Applied("fadeOver", db) == true)
    f:SetMapEffects(db.mapEffects ~= false) -- s6-world-view (O-03)
    -- s6-world-view: the outer area's extras (plan 5.10)
    f:SetFarView(db.farViewObjects == true, db.farViewRememberItems == true, db.rememberConfirmMs or 2000, db.rememberMaxAgeMinutes or 10)
    -- s6-world-view (round 36): the owner's "Add Border to Zone" and its colour; round 37: its opacity (drawing only)
    f:SetZoneBorder(db.zoneBorder == true, db.zoneBorderRed, db.zoneBorderGreen, db.zoneBorderBlue, db.zoneBorderOpacity)
    -- s6-world-view (round 29): the frame's size in UI units is its screen pixels over the UI and frame scales (review
    -- F9), so a fitted frame is the picture's size on the screen whatever the UI scale.
    local presentation = self:Presentation() -- s6-modular-d (Retro rule 16)
    local cols, rows, scale, w, h, px = self:Fit(db, f, presentation)
    self.scale = scale
    f:SetWorldView(cols, rows, db.outerDim, db.outerSaturation, db.expandLive, scale, presentation and "linear" or db.smoothing)
    -- s6-modular-g round 22: the interface owns its drop rectangle; wire note in its definition.
    __tk:SetInventoryDropPane(TK.Interfaces:Active().inventoryDropPane == true)
    f:SetSize(w / px, h / px)
    self:UpdateLabel()
    TK.Visibility:Apply(f)
end

--- s6-input (round 49, separation step 4b): one of the view's settings changed from elsewhere (an interface's options,
--- the Game Options' presets), kept in the profile and shown at once. Drawing only.
function C:Set(key, value)
    self:DB()[key] = value
    TK.DB:MarkDirty()
    -- s6-optimize (round 33): applied again with everything that reads through Component:Applied (this view too), as a
    -- change on a settings page is (setArg): Global Illumination and Real Lights need the Shadows set here
    if self.frame then TK.Components:ApplyReaders() end
end

-- s6-world-view (s6-coverage's head note): the Game Options' Low and High presets switch the map's full-screen
-- effects as the original's do (NewOptionPane::SendLowHighDisplayModeOption, OptionPane.cpp:1179-1183): Low off, High
-- on, kept like the toggle. (The presets' shadows, balloon fill and 1B options are the Game Options' own.)
function C:SetMapEffects(on) self:Set("mapEffects", on and true or false) end

-- s6-ui-settings: the shadows, the same way, for the Game Options' Shadows row and Low and High (OptionPane.cpp:1182).
function C:SetShadows(on) self:Set("shadows", on and true or false) end

-- ----- an interface's screen puts the view at its map view (s6-input round 49, separation step 4b) -----

local function near(a, b) return type(a) == "number" and math.abs(a - b) < 0.01 end

--- The view at rect { left, top, width, height } (UIParent units from the window's top left: an interface's map view on
--- its scaled screen), through its own settings: its frame the rectangle's size and place; the picture's cols x rows cells
--- (7.x's and 5.x's 19 x 17: the original's pane, a cell beyond each edge), the live 17 x 15 fitting the frame by
--- Stretch, so the frame shows the middle as the original's clip does. Again whenever the window changes (the caller's
--- layout); once the player has moved or resized it (it is no longer where this last put it), it stays theirs and
--- keep.mapPane turns off. keep: the screen panel's settings (mapPane, and placed, where this last put it). Drawing only.
function C:PlaceAt(rect, cols, rows, keep)
    local v = self:DB()
    local p = TK.DB.profile.positions.worldview
    local last = keep.placed
    if last and not (near(v.width, last[3]) and near(v.height, last[4]) and type(p) == "table" and p[1] == "TOPLEFT"
                     and near(p[3], last[1]) and near(p[4], last[2])) then
        keep.mapPane, keep.placed = false, nil
        TK.DB:MarkDirty()
        return
    end
    local x, y, w, h = rect[1], -rect[2], rect[3], rect[4]
    if last and near(x, last[1]) and near(y, last[2]) and near(w, last[3]) and near(h, last[4]) then return end
    v.autoExtend, v.cols, v.rows, v.worldScale, v.includeOuter, v.expandLive = false, cols, rows, "stretch", false, false
    v.width, v.height = w, h
    TK.DB.profile.positions.worldview = { "TOPLEFT", "TOPLEFT", x, y }
    keep.placed = { x, y, w, h }
    TK.DB:MarkDirty()
    TK.SafeCall(self.ApplySettings, self)
    if self.entry then TK.EditMode:Restore(self.entry) end
end

-- ----- where the active area's cells are on the screen (the enemy icons use this) -----

--- A tile's size on the screen in UI units, and the picture's columns and rows.
function C:TileSize()
    local f = self.frame
    local nw, nh = f:GetNaturalSize()
    return 48 * (self.scale or 1) / (TK.UIScale() * f:GetEffectiveScale()), nw / 48, nh / 48 -- s6-world-view (round 29)
end

--- The centre of a cell of the active 17 x 15 area (0-16, 0-14) from the frame's centre, in UI units (the picture
--- is centred in the frame), and the tile's size. s6-world-view (round 38; the owner, 2026-10-06: every overlay of ours
--- scrolls smoothly): where the cell is drawn this frame, with the step's glide, so what is placed on it slides with the
--- world instead of hopping a cell at the step's end. Drawing only: the picks go through MapPoint.
function C:TileCentre(vx, vy)
    local t = self:TileSize()
    local gx, gy = __tk:GetViewGlide()
    return (vx - 8 + gx / 48) * t, (7 - vy - gy / 48) * t, t
end

--- s6-world-view (round 39; Astra's review 39-2): map cell (x, y)'s centre as TileCentre gives it, counted from the tile
--- origin the picture was drawn from with its glide. The session's origin (__tk:GetTileOrigin) is the logic's, which
--- can already be the next step's while this frame's glide is still the last one's, a cell off for a frame at a step's
--- end. Drawing only.
function C:CellCentre(x, y)
    local t = self:TileSize()
    local gx, gy, ox, oy = __tk:GetViewGlide()
    return (x - ox - 8 + gx / 48) * t, (7 - (y - oy) - gy / 48) * t, t
end

--- s6-world-view (round 31): the cursor's point on the map pane as the logic takes a press there (the original's pixels
--- from the live area's first cell, y down: the UI host's MapPoint, OnActiveMap's transform), or nil off the picture or
--- with another frame over it. Every path from the cursor to a map cell starts here: the drop, the map cursor, the
--- tooltips, the nameplates' and the enemy icons' hover.
function C:MapPoint()
    local f = self.frame
    if not f:IsVisible() or not f:IsMouseOver() then return nil end
    local ok, x, y = __tk:GetMapPoint()
    if not ok then return nil end
    return x, y
end

--- s6-world-view (round 31): the same point from the live area's centre (the picture's), as the drawing's picks take it
--- (GetMapCursor, GetFigureAt, GetNumCellItems), or nil.
function C:CentrePoint()
    local x, y = self:MapPoint()
    if not x then return nil end
    return x - 408, y - 360 -- the live area's centre: half of 17 x 15 cells of 48
end

--- The active area's cell under the cursor (0-16, 0-14), or nil.
function C:TileAtCursor()
    local x, y = self:MapPoint() -- s6-world-view (round 31)
    if not x then return nil end
    local vx, vy = math.floor(x / 48), math.floor(y / 48)
    if vx < 0 or vx > 16 or vy < 0 or vy > 14 then return nil end
    return vx, vy
end
