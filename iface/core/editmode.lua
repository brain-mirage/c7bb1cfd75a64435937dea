-- Edit mode (goal 6): a global Lock / Unlock as in Bartender. Unlocked, a mover covers every movable frame, with
-- its name and a highlight. Drag a mover to move its frame; it snaps to the screen's edges and centre, to other
-- frames, and to the grid when the grid is shown. Arrow keys nudge the selected frame (Shift: 10 pixels).
-- Right-click a mover to open that frame's settings.
--
-- Positions are saved per profile as the nearest screen anchor (by thirds of the screen) and an offset, so a
-- frame near a corner stays near it when the window or the UI scale changes.

local U = TK.Util
local W = TK.UI

local E = { unlocked = false, entries = {}, list = {}, selected = nil }
TK.EditMode = E

local SNAP = 10

--- Registers a movable frame.
---   key      where its position is saved, e.g. "bar1"
---   label    the mover's name, e.g. "Bar 1"
---   default  { point, relativePoint, x, y } relative to UIParent
---   node     the settings node a right-click opens
---   enabled  optional function: false hides the mover (a disabled bar)
---   resize   optional { set = function(width, height), minWidth, minHeight }: a grip on the mover resizes it
function E:Register(frame, key, label, default, node, enabled, resize)
    local entry = TK.Mark({ frame = frame, key = key, label = label, default = default, node = node,
                                       enabled = enabled, resize = resize })
    if not self.entries[key] then self.list[#self.list + 1] = entry end
    self.entries[key] = entry
    frame:SetMovable(true)
    self:Restore(entry)
    if self.unlocked then self:ShowMover(entry) end
    return entry
end

-- s6-interface-5x (round 13, the separation's step 11): a panel turned off takes its places' entries and movers with it
TK.OnWithdraw(function(name, panel)
    local function gone(entry)
        if not (TK.OwnedBy(entry, name, panel) or TK.IsDead(entry.frame)) then return false end
        if entry.mover then TK.DestroyFrame(entry.mover) end
        if E.selected == entry then E.selected = nil end
        return true
    end
    -- the list keeps a key's first entry and entries its latest (E:Register), so each is swept
    for key, entry in pairs(E.entries) do
        if gone(entry) then E.entries[key] = nil end
    end
    local kept = {}
    for _, entry in ipairs(E.list) do
        if not gone(entry) then kept[#kept + 1] = entry end
    end
    E.list = kept
end)

function E:SavedPosition(entry)
    local p = TK.DB.profile.positions[entry.key]
    if type(p) == "table" and p[1] then return p end
    return entry.default
end

function E:Restore(entry)
    local p = self:SavedPosition(entry)
    entry.frame:ClearAllPoints()
    entry.frame:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
end

function E:RestoreAll()
    for _, entry in ipairs(self.list) do self:Restore(entry) end
    self:UpdateMovers()
end

function E:ResetPosition(key)
    -- s6-interface-5x (round 13, step 11): a panel not loaded has no entry, and its saved place is reset all the same
    TK.DB.profile.positions[key] = nil
    TK.DB:MarkDirty()
    local entry = self.entries[key]
    if entry then self:Restore(entry) end
end

--- Saves an entry's current place as its nearest screen anchor.
function E:Save(entry)
    local l, b, w, h = U.RootRect(entry.frame)
    if not l then return end
    local point, x, y = U.NearestScreenPoint(l, b, w, h, entry.frame:GetEffectiveScale())
    x, y = U.Round(x, 0.5), U.Round(y, 0.5)
    TK.DB.profile.positions[entry.key] = { point, point, x, y }
    TK.DB:MarkDirty()
    self:Restore(entry)
    TK.FireEvent("TK_FRAME_MOVED", entry.key)
end

--- Places an entry's frame with its bottom-left corner at (l, b) in UIParent units.
local function placeAt(entry, l, b)
    local s = entry.frame:GetEffectiveScale()
    entry.frame:ClearAllPoints()
    entry.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l / s, b / s)
end

--- Changes a frame's anchor point without moving it: the offset is recomputed from where it is now.
function E:SetAnchor(key, point)
    local entry = self.entries[key]
    if not entry then return end
    local l, b, w, h = U.RootRect(entry.frame)
    if not l then return end
    local s = entry.frame:GetEffectiveScale()
    local sw, sh = GetScreenWidth(), GetScreenHeight()
    local fx, fy = 0.5, 0.5
    for i, p in ipairs(U.Points) do
        if p == point then
            fx, fy = ((i - 1) % 3) * 0.5, 1 - math.floor((i - 1) / 3) * 0.5
        end
    end
    local x = (l + fx * w - fx * sw) / s
    local y = (b + fy * h - fy * sh) / s
    TK.DB.profile.positions[key] = { point, point, U.Round(x, 0.5), U.Round(y, 0.5) }
    TK.DB:MarkDirty()
    self:Restore(entry)
end

--- Centres a frame on the screen horizontally and/or vertically.
function E:Center(key, horizontal, vertical)
    local entry = self.entries[key]
    if not entry then return end
    local l, b, w, h = U.RootRect(entry.frame)
    if not l then return end
    if horizontal then l = (GetScreenWidth() - w) / 2 end
    if vertical then b = (GetScreenHeight() - h) / 2 end
    placeAt(entry, l, b)
    self:Save(entry)
end

-- ----- movers -----

local function moverColors(mover, selected)
    if selected then
        mover:SetBackdropColor(0.15, 0.55, 0.25, 0.45)
        mover:SetBackdropBorderColor(0.4, 1, 0.5, 1)
    else
        mover:SetBackdropColor(0.1, 0.3, 0.75, 0.38)
        mover:SetBackdropBorderColor(0.35, 0.6, 1, 0.95)
    end
end

function E:Select(entry)
    local old = self.selected
    self.selected = entry
    if old and old.mover then moverColors(old.mover, false) end
    if entry and entry.mover then moverColors(entry.mover, true) end
end

local function makeMover(entry)
    local m = CreateFrame("Button", nil, UIParent)
    m:SetFrameStrata("HIGH")
    m:SetFrameLevel(50)
    m:SetAllPoints(entry.frame)
    m:SetBackdrop({ bg = { 0.1, 0.3, 0.75, 0.38 }, edge = { 0.35, 0.6, 1, 0.95 }, bgFile = "tk:white", edgeFile = "tk:edge" })
    local hl = m:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(m)
    hl:SetColorTexture(1, 1, 1, 0.12)
    local label = W.Label(m, entry.label, 13, W.white)
    label:SetFont(13, "OUTLINE")
    label:SetPoint("CENTER", m, "CENTER", 0, 0)
    m.label = label
    m:RegisterForDrag("LeftButton")
    m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    m:SetScript("OnMouseDown", function() entry.pressX, entry.pressY = U.CursorRoot() end)
    m:SetScript("OnDragStart", function() E:BeginDrag(entry) end)
    m:SetScript("OnDragStop", function() E:EndDrag(entry) end)
    m:SetScript("OnClick", function(_, button)
        E:Select(entry)
        if button == "RightButton" and entry.node then TK.Settings:Open(entry.node) end
    end)
    m:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(entry.label, 1, 0.82, 0)
        GameTooltip:AddLine("Drag to move. Right-click for settings.", 1, 1, 1)
        GameTooltip:AddLine("Arrow keys nudge the selected frame (Shift: 10).", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if entry.resize then E:AddResizeGrip(entry, m) end
    entry.mover = m
    return m
end

--- The resize grip in a resizable mover's bottom-right corner. While resizing, the frame's top-left corner
--- stays put; the new size is handed to the component and the position saved when the drag ends.
function E:AddResizeGrip(entry, m)
    local grip = CreateFrame("Button", nil, m)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(m:GetFrameLevel() + 2)
    local t = grip:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(grip)
    t:SetTexture("tk:resize")
    t:SetVertexColor(1, 0.9, 0.5, 1)
    local hl = grip:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(grip)
    hl:SetTexture("tk:glow")
    hl:SetVertexColor(1, 0.9, 0.5, 0.5)
    grip:RegisterForDrag("LeftButton")
    local start
    grip:SetScript("OnMouseDown", function() entry.gripX, entry.gripY = U.CursorRoot() end)
    grip:SetScript("OnDragStart", function()
        local l, b, w, h = U.RootRect(entry.frame)
        if not l then return end
        local s = entry.frame:GetEffectiveScale()
        -- Pin the top-left corner while the size changes.
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l / s, (b + h) / s)
        local cx, cy = entry.gripX, entry.gripY
        if not cx then cx, cy = U.CursorRoot() end
        start = { x = cx, y = cy, w = w / s, h = h / s, s = s }
        grip:SetScript("OnUpdate", function()
            local x, y = U.CursorRoot()
            local w2 = math.max(entry.resize.minWidth or 50, start.w + (x - start.x) / start.s)
            local h2 = math.max(entry.resize.minHeight or 50, start.h + (start.y - y) / start.s)
            entry.resize.set(math.floor(w2 + 0.5), math.floor(h2 + 0.5))
        end)
    end)
    grip:SetScript("OnDragStop", function()
        grip:SetScript("OnUpdate", nil)
        start = nil
        E:Save(entry)
    end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Drag to resize", 1, 1, 1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m.grip = grip
end

function E:ShowMover(entry)
    local m = entry.mover or makeMover(entry)
    -- A replaced component's frame is not shown to be moved either (TK.ReplaceComponent), nor an interface's panel that is
    -- off (s6-interface-5x round 12, build 46: TK.Interfaces:Dormant; Modern's minimap or player frame in a 7.x profile).
    local owner = rawget(entry.frame, "__component")
    local on = (entry.enabled == nil or entry.enabled()) and not (owner and owner.replaced)
        and not (owner and TK.Interfaces:Dormant(owner.name))
    m:SetShown(on)
    moverColors(m, self.selected == entry)
end

--- s6-ui-core (round 46): the movers are siblings at one strata and level, and since this round the one made later is
--- drawn on top and takes the press (WoW's order, UIFrame.CanvasOrder), so a small frame's mover under a larger one's
--- could not be taken. The shown movers get a level each by their frame's size, the largest lowest; the resize grips go
--- above them all (a large frame's grip under a smaller frame's mover could not be taken either).
local MOVER_LEVEL = 50

local function area(entry)
    local _, _, w, h = U.RootRect(entry.frame)
    return w and w * h or 0
end

function E:UpdateMovers()
    local shown = {}
    for i, entry in ipairs(self.list) do
        if self.unlocked then
            self:ShowMover(entry)
            if entry.mover:IsShown() then shown[#shown + 1] = { entry = entry, area = area(entry), i = i } end
        elseif entry.mover then entry.mover:Hide() end
    end
    table.sort(shown, function(a, b) if a.area ~= b.area then return a.area > b.area end return a.i < b.i end)
    for n, s in ipairs(shown) do s.entry.mover:SetFrameLevel(MOVER_LEVEL + n - 1) end
    for _, s in ipairs(shown) do
        if s.entry.mover.grip then s.entry.mover.grip:SetFrameLevel(MOVER_LEVEL + #shown + 1) end
    end
end

-- ----- dragging with snapping -----

local drag

local function snapAxis(pos, size, targets)
    local best, bestDist = pos, SNAP + 1
    for _, t in ipairs(targets) do
        -- t = { edge, value }: which edge of ours ("min", "max", "mid") should land on value.
        local candidate
        if t[1] == "min" then candidate = t[2]
        elseif t[1] == "max" then candidate = t[2] - size
        else candidate = t[2] - size / 2 end
        local d = math.abs(candidate - pos)
        if d < bestDist then best, bestDist = candidate, d end
    end
    return best
end

function E:BeginDrag(entry)
    local l, b, w, h = U.RootRect(entry.frame)
    if not l then return end
    -- The grip is where the button went down, not where the drag threshold was crossed.
    local cx, cy = entry.pressX, entry.pressY
    if not cx then cx, cy = U.CursorRoot() end
    drag = { entry = entry, dx = cx - l, dy = cy - b, w = w, h = h }
    self:Select(entry)
    entry.mover:SetScript("OnUpdate", function() E:UpdateDrag() end)
end

function E:UpdateDrag()
    if not drag then return end
    local cx, cy = U.CursorRoot()
    local l, b = cx - drag.dx, cy - drag.dy
    local g = TK.Machine:Get()
    local sw, sh = GetScreenWidth(), GetScreenHeight()
    if g.snap or g.grid then
        local xs, ys = {}, {}
        if g.snap then
            xs = { { "min", 0 }, { "max", sw }, { "mid", sw / 2 } }
            ys = { { "min", 0 }, { "max", sh }, { "mid", sh / 2 } }
            for _, other in ipairs(self.list) do
                if other ~= drag.entry and other.frame:IsVisible() then
                    local ol, ob, ow, oh = U.RootRect(other.frame)
                    if ol then
                        table.insert(xs, { "min", ol + ow }); table.insert(xs, { "max", ol })
                        table.insert(xs, { "min", ol }); table.insert(xs, { "max", ol + ow })
                        table.insert(ys, { "min", ob + oh }); table.insert(ys, { "max", ob })
                        table.insert(ys, { "min", ob }); table.insert(ys, { "max", ob + oh })
                    end
                end
            end
        end
        if g.grid then
            local size = g.gridSize or 32
            local gx = sw / 2 + U.Round((l - sw / 2) / size) * size
            local gy = sh / 2 + U.Round((b - sh / 2) / size) * size
            table.insert(xs, { "min", gx })
            table.insert(ys, { "min", gy })
        end
        l = snapAxis(l, drag.w, xs)
        b = snapAxis(b, drag.h, ys)
    end
    l = U.Clamp(l, 0, math.max(0, sw - drag.w))
    b = U.Clamp(b, 0, math.max(0, sh - drag.h))
    placeAt(drag.entry, l, b)
end

function E:EndDrag(entry)
    if not drag then return end
    entry.mover:SetScript("OnUpdate", nil)
    drag = nil
    self:Save(entry)
end

--- Arrow keys nudge the selected frame while unlocked.
function E:OnKey(key, down)
    if not self.unlocked or not down or not self.selected then return false end
    local bare = U.BareKey(key)
    -- In screen pixels (Shift: 10), whatever the UI scale.
    local step = (key:find("SHIFT%-") and 10 or 1) / TK.UIScale()
    local dx, dy = 0, 0
    if bare == "LEFT" then dx = -step elseif bare == "RIGHT" then dx = step
    elseif bare == "UP" then dy = step elseif bare == "DOWN" then dy = -step
    else return false end
    local entry = self.selected
    local l, b = U.RootRect(entry.frame)
    if not l then return true end
    placeAt(entry, l + dx, b + dy)
    self:Save(entry)
    return true
end

-- ----- the grid -----

local grid
local function buildGrid()
    if not grid then
        grid = CreateFrame("Frame", "TKEditGrid", UIParent)
        grid:SetFrameStrata("LOW")
        grid:SetAllPoints(UIParent)
        grid.lines = {}
    end
    for _, t in ipairs(grid.lines) do t:Hide() end
    local size = TK.Machine:Get().gridSize or 32
    local sw, sh = GetScreenWidth(), GetScreenHeight()
    local n = 0
    local function lineAt(vertical, pos, centre)
        n = n + 1
        local t = grid.lines[n]
        if not t then
            t = grid:CreateTexture(nil, "BACKGROUND")
            grid.lines[n] = t
        end
        t:ClearAllPoints()
        if vertical then
            t:SetPoint("TOPLEFT", grid, "TOPLEFT", pos, 0)
            t:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", pos, 0)
            t:SetWidth(1)
        else
            t:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", 0, pos)
            t:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", 0, pos)
            t:SetHeight(1)
        end
        if centre then t:SetColorTexture(1, 0.2, 0.2, 0.55) else t:SetColorTexture(0, 0, 0, 0.45) end
        t:Show()
    end
    local cx, cy = math.floor(sw / 2), math.floor(sh / 2)
    lineAt(true, cx, true)
    lineAt(false, cy, true)
    for x = cx + size, sw, size do lineAt(true, x) end
    for x = cx - size, 0, -size do lineAt(true, x) end
    for y = cy + size, sh, size do lineAt(false, y) end
    for y = cy - size, 0, -size do lineAt(false, y) end
end

function E:UpdateGrid()
    local show = self.unlocked and TK.Machine:Get().grid
    if show then buildGrid() end
    if grid then grid:SetShown(show) end
end

TK.On("DISPLAY_SIZE_CHANGED", function() if grid and grid:IsShown() then buildGrid() end end)
TK.On("UI_SCALE_CHANGED", function() if grid and grid:IsShown() then buildGrid() end end)

-- ----- the edit-mode dialog -----
-- s6-ui-core (round 54; the owner, 2026-10-05: "Add a button called Keybinds to the edit menu next to Lock. If you press
-- Keybinds it switches to that mode. Also when you open this, the button starts with Unlock: you have to click it first to
-- start dragging. Then you can click it again to lock. If you click Keybinds when it's unlocked it should automatically
-- relock, and clicking the Lock button should turn off the keybind mode (both can't be on at the same time)."): Edit Mode
-- opens locked; Unlock / Lock moves the frames or stops; Keybinds is key-binding mode (core/bindings.lua, TK.KeyBindMode),
-- whose line and results show here. Its close box and Escape close it, locked and with key-binding mode off.

local dialog
local HINTS = { locked = "Click Unlock to move frames.", unlocked = "Drag a frame to move it. Right-click for its settings.",
                keybinds = "Hover over a button and press a key. Escape clears it." }

--- The dialog's line, its two buttons' words and the status line, as the state is now.
local function showState()
    if not dialog then return end
    local keybinds = TK.KeyBindMode.active
    dialog.hint:SetText(keybinds and HINTS.keybinds or E.unlocked and HINTS.unlocked or HINTS.locked)
    dialog.lock:SetText(E.unlocked and "Lock" or "Unlock")
    dialog.keybinds:SetText(keybinds and "Stop Keybinds" or "Keybinds")
    if not keybinds then dialog.status:SetText("") end
end

local function makeDialog()
    dialog = W.Panel(UIParent, "TKEditModeDialog")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetSize(470, 126)
    dialog:SetPoint("TOP", UIParent, "TOP", 0, -24)
    dialog:EnableMouse(true)
    -- s6-modular-g (round 21, the owner's research on presses reaching the wrong place): a wheel turn over it is its own,
    -- as over every window (core/widgets.lua's make.Window); it scrolled what lay under it.
    -- WIRE: ArticleListPane::HandlePointerOrMouseEvent (0x00474EC0) can request older board rows
    -- on a wheel turn. Letting this turn reach it changes what the server sees.
    dialog:EnableMouseWheel(true)
    local title = W.Label(dialog, "Edit Mode", 16, W.gold)
    title:SetPoint("TOP", dialog, "TOP", 0, -10)
    dialog.hint = W.Label(dialog, "", 12, W.white)
    dialog.hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
    -- what key-binding mode did with the last key (TK.KeyBindMode:Status)
    dialog.status = W.Label(dialog, "", 12, { 0.6, 0.9, 0.6 })
    dialog.status:SetPoint("TOP", dialog.hint, "BOTTOM", 0, -4)
    dialog.closeButton = W.IconButton(dialog, "tk:close", 16, function() E:Close() end)
    dialog.closeButton:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -10, -10)
    dialog.grid = W.Check(dialog, "Show Grid", function(on)
        TK.Machine:Get().grid = on
        TK.Machine:MarkDirty()
        E:UpdateGrid()
    end)
    dialog.grid:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 14, 12)
    dialog.snap = W.Check(dialog, "Snap to Frames", function(on)
        TK.Machine:Get().snap = on
        TK.Machine:MarkDirty()
    end)
    dialog.snap:SetPoint("LEFT", dialog.grid, "RIGHT", 18, 0)
    dialog.lock = W.Button(dialog, "Unlock", 90, 24, "red", function()
        if E.unlocked then E:Lock() else E:Unlock() end
    end)
    dialog.lock:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -12, 10)
    dialog.keybinds = W.Button(dialog, "Keybinds", 110, 24, "red", function() E:Keybinds() end)
    dialog.keybinds:SetPoint("RIGHT", dialog.lock, "LEFT", -8, 0)
    -- Escape closes it when edit mode is the topmost thing open (key-binding mode's Escape is its own first).
    TK.Escape:AddWindow(dialog, function() E:Close() end)
end

--- Opens Edit Mode, locked (the owner: "the button starts with Unlock").
function E:Open()
    if not TK.GameState:InWorld() then return end
    if not dialog then makeDialog() end
    dialog.grid:SetChecked(TK.Machine:Get().grid)
    dialog.snap:SetChecked(TK.Machine:Get().snap)
    dialog:Show()
    showState()
end

function E:IsOpen() return dialog ~= nil and dialog:IsShown() end

--- The frames movable (Edit Mode opened if it is not); key-binding mode stops, as only one is on at a time.
function E:Unlock()
    if not TK.GameState:InWorld() then return end
    TK.KeyBindMode:Disable()
    if not self:IsOpen() then self:Open() end
    self.unlocked = true
    for frame in pairs(TK.Visibility.frames) do TK.Visibility:Apply(frame) end
    self:UpdateMovers()
    self:UpdateGrid()
    showState()
    TK.FireEvent("TK_EDIT_MODE", true)
end

--- The frames fixed again; Edit Mode stays open (its Close closes it).
function E:Lock()
    local was = self.unlocked
    self.unlocked = false
    self.selected = nil
    TK.KeyBindMode:Disable()
    for frame in pairs(TK.Visibility.frames) do TK.Visibility:Apply(frame) end
    self:UpdateMovers()
    self:UpdateGrid()
    showState()
    if was then TK.FireEvent("TK_EDIT_MODE", false) end
end

--- Keybinds: key-binding mode on (the frames locked first) or off.
function E:Keybinds()
    if TK.KeyBindMode.active then
        TK.KeyBindMode:Disable()
    else
        if self.unlocked then self:Lock() end
        TK.KeyBindMode:Enable()
    end
    showState()
end

--- Closes Edit Mode: locked, key-binding mode off.
function E:Close()
    self:Lock()
    if dialog then dialog:Hide() end
end

--- The micro menu's and the game menu's Edit Mode: opens it, or closes it.
function E:Toggle()
    if self:IsOpen() then self:Close() else self:Open() end
end

--- Key-binding mode's line for its last key (TK.KeyBindMode:Status), in its colour.
function E:SetStatus(text, r, g, b)
    if not dialog then return end
    dialog.status:SetTextColor(r or 0.6, g or 0.9, b or 0.6)
    dialog.status:SetText(text or "")
end

TK.On("TK_KEYBIND_MODE", function() showState() end)
TK.On("PLAYER_LEAVING_WORLD", function() if E:IsOpen() then E:Close() end end)
TK.On("TK_PROFILE_CHANGED", function() E:UpdateGrid() end)

--- The Layout tab, shared by every panel with a place on the screen: its scale, its anchor and offsets, centring and
--- reset. positionKey() names its edit-mode entry; options.noScale leaves the scale out (the world view, sized by its
--- own settings); options.extra adds controls at the end (the bars' button order).
---
--- s6-modular-g (interfaces, phase 1; docs/development/interfaces.md, "The Layout tab"): it took over the
--- Alignment tab and the Scale that was under General Settings. The values stay where they were kept before it: the
--- scale in the panel's own settings (its "scale", which TK.Visibility applies) and the place in the profile's
--- positions[key], which edit mode moves too. So a profile saved before the tab keeps every place and scale as it was.
function TK.LayoutArgs(positionKey, options)
    options = options or {}
    local E = TK.EditMode
    -- s6-interface-5x (round 13, the separation's step 11): a panel not loaded (off) has no entry; its page reads and
    -- writes the profile's place, which its start uses
    local function pos()
        local entry = E.entries[positionKey()]
        if entry then return E:SavedPosition(entry) end
        local p = TK.DB.profile.positions[positionKey()]
        return type(p) == "table" and p[1] and p or { "CENTER", "CENTER", 0, 0 }
    end
    local function setPos(point, x, y)
        TK.DB.profile.positions[positionKey()] = { point, point, x, y }
        TK.DB:MarkDirty()
        local entry = E.entries[positionKey()]
        if entry then E:Restore(entry) end
    end
    local points = {}
    for _, p in ipairs(U.Points) do points[#points + 1] = { value = p, text = p:sub(1, 1) .. p:sub(2):lower() } end
    local sw, sh = math.floor(GetScreenWidth()), math.floor(GetScreenHeight())
    local args = {
        { type = "description", name = "Its size, and where it sits: a point of the screen and an offset from it. Dragging it in edit mode sets these too." },
        { type = "select", name = "Anchor", values = points,
          get = function() return pos()[1] end,
          set = function(_, v) E:SetAnchor(positionKey(), v) end },
        { type = "break" },
        { type = "range", name = "X Offset", min = -sw, max = sw, step = 1,
          get = function() return pos()[3] or 0 end,
          set = function(_, v) local p = pos(); setPos(p[1], v, p[4] or 0) end },
        { type = "range", name = "Y Offset", min = -sh, max = sh, step = 1,
          get = function() return pos()[4] or 0 end,
          set = function(_, v) local p = pos(); setPos(p[1], p[3] or 0, v) end },
        { type = "execute", name = "Center Horizontally", func = function() E:Center(positionKey(), true, false) end },
        { type = "execute", name = "Center Vertically", func = function() E:Center(positionKey(), false, true) end },
        -- resets: the settings page's reset icon runs it too (s6-ui-settings).
        { type = "execute", name = "Reset Position", resets = true, func = function() E:ResetPosition(positionKey()) end },
    }
    if not options.noScale then
        -- after the description, on a row of its own
        table.insert(args, 2, { type = "range", key = "scale", name = "Scale", min = 0.1, max = 2, step = 0.05 })
        table.insert(args, 3, { type = "break" })
    end
    for _, a in ipairs(options.extra or {}) do args[#args + 1] = a end
    return args
end
