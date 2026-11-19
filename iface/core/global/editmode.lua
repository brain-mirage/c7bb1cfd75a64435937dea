-- Edit mode (goal 6): a global Lock / Unlock as in Bartender. Unlocked, a mover covers every movable frame, with
-- its name and a highlight. Drag a mover to move its frame; it snaps to the screen's edges and centre, to other
-- frames, and to the grid when the grid is shown. Arrow keys nudge the selected frame (Shift: 10 pixels).
-- Right-click a mover to open that frame's settings.
--
-- Positions are saved per profile as the nearest screen anchor (by thirds of the screen) and an offset, so a
-- frame near a corner stays near it when the window or the UI scale changes.
--
-- s6-ui-core (round 124, the Global Interface's C# shell, piece 2; the owner's answer to question A): what the player
-- handles is C# (Runtime/Shell/EditMode.cs): the Edit Mode window, the movers, the grid, dragging with its snapping,
-- the resize grip and the nudge. Since round 171 (U-64 step 2) its behaviour is C# too: opening and closing it, Lock
-- and Unlock, Keybinds, the arrow keys, the state line, the grid's showing and a mover's right click; TK.EditMode's
-- methods for them only call the shell. This file keeps what is saved and what belongs to other parts: the places in
-- the profile and the interfaces' layouts, the Layout tab, whether a mover shows, the switches in TK.Machine, the
-- tooltip, the opacity, and what a lock or an unlock does on the Lua side (TK.EditMode.unlocked, key-binding mode, the
-- Visibility rules). The shell asks for them through __tk_shell (TK.ShellCalls["edit.*"]); TK.EditMode, its entries
-- with their mover and grip, TKEditModeDialog with its controls, and TKEditGrid stay, wrapping the shell's frames.

local U = TK.Util
local W = TK.UI
local H = __tk

-- selected is the shell's (the mover drawn chosen, which a drag and a click set): read and written through it.
-- unlocked mirrors the shell's, which sets it ("edit.unlocked") at each lock and unlock.
local E = setmetatable({ unlocked = false, entries = {}, list = {} }, {
    __index = function(t, k)
        if k == "selected" then
            local key = H:ShellEditSelected()
            return key and rawget(t, "entries")[key]
        end
    end,
    __newindex = function(t, k, v)
        if k == "selected" then H:ShellEditSelect(v and v.key) else rawset(t, k, v) end
    end,
})
TK.EditMode = E

-- T-36 step 3 (gateway round 91; s6-ui-core's seam, its round 133): an interface's own layout, the optional
-- interfaces/<id>/layout.lua: { [key] = { point, relativePoint, x, y, width = w, height = h } }, where the active
-- interface starts its panels (and, for a panel with a grip, their size) instead of each panel's built-in default.
-- It is read once per interface in this Lua state; a UI reload (the editor's interface page saves the file, and the
-- client's LuaWatch reloads) reads it again.
local layouts = {}
local function layoutOf(key)
    local id = TK.Interfaces.active
    if not id then return nil end
    if layouts[id] == nil then
        local name = "interfaces." .. id .. ".layout"
        package.loaded[name] = nil
        local ok, layout = pcall(require, name)
        if not ok and not tostring(layout):find("not found", 1, true) then
            H:LogWarning("interfaces/" .. id .. "/layout.lua: " .. tostring(layout))
        end
        layouts[id] = ok and type(layout) == "table" and layout or false
    end
    return layouts[id] and layouts[id][key]
end

-- The layout's place for a key, read each time the panel is placed, not kept on its entry: a frame the interfaces share
-- (World View) is not registered again on a switch, and RestoreAll (Components:ReapplyAll) then places it by the new
-- interface's layout. Kept apart from the panel's default, which 7.x's and 5.x's panels set again as the screen's scale
-- changes (shared/original/screen.lua's Screen.Place).
local function laidPlace(key)
    local laid = layoutOf(key)
    return laid and laid[1] and laid or nil
end

-- T-36 step 3: the layout's size for a panel with a grip, while the player has no saved place for it (moving or
-- resizing it in Edit Mode saves one). It is given once per size: the profile keeps the layout's size given last (its
-- width and height as the layout names them, 0 for one it leaves out), so a size changed on the panel's settings page
-- stays until the layout names another. A frame later, once the panel has its own size (a dimension the layout leaves
-- out keeps it), as the panel's set may apply its settings.
local function sizeFromLayout(entry, laid)
    if not (entry.resize and (laid.width or laid.height)) or E:HasSavedPlace(entry.key) then return end
    -- A previously applied size still has priority after an XML reload, even when its once-per-size marker matches.
    if TK.Xml then TK.Xml.ReleaseLayout(entry.frame) end
    local named = { laid.width or 0, laid.height or 0 }
    local given = TK.DB.profile.layoutSizes or {}
    local last = given[entry.key]
    if last and last[1] == named[1] and last[2] == named[2] then return end
    given[entry.key] = named
    TK.DB.profile.layoutSizes = given
    TK.DB:MarkDirty()
    TK.Await(function() return true end, function()
        entry.resize.set(laid.width or math.floor(entry.frame:GetWidth() + 0.5),
                         laid.height or math.floor(entry.frame:GetHeight() + 0.5))
    end)
end

--- Registers a movable frame.
---   key      where its position is saved, e.g. "bar1"
---   label    the mover's name, e.g. "Bar 1"
---   default  { point, relativePoint, x, y } relative to UIParent (the active interface's layout.lua may name another)
---   node     the settings node a right-click opens
---   enabled  optional function: false hides the mover (a disabled bar)
---   resize   optional { set = function(width, height), minWidth, minHeight }: a grip on the mover resizes it
function E:Register(frame, key, label, default, node, enabled, resize)
    local authoredDefault
    if TK.Xml and TK.Xml.LayoutAuthored(frame) then
        -- XML-authored panel geometry is a default. Keep the existing player/interface placement precedence.
        local point, relative, relativePoint, x, y = frame:GetPoint(1)
        if relative == UIParent then
            authoredDefault = { point, relativePoint, x, y }
        else
            local l, b, w, h = U.RootRect(frame)
            if l then
                point, x, y = U.NearestScreenPoint(l, b, w, h, frame:GetEffectiveScale())
                authoredDefault = { point, point, x, y }
            end
        end
        if self:HasSavedPlace(key) then TK.Xml.ReleaseLayout(frame) end
    end
    local entry = TK.Mark({ frame = frame, key = key, label = label, default = default, node = node,
                                       enabled = enabled, resize = resize, authoredDefault = authoredDefault })
    if not self.entries[key] then self.list[#self.list + 1] = entry end
    self.entries[key] = entry
    frame:SetMovable(true)
    -- the shell's mover over it (one per key: a panel started again keeps it), its right click's settings page, and its
    -- grip when it resizes
    entry.mover = TK.Wrap(H:ShellEditRegister(key, frame.__h, label, node, resize ~= nil,
                                              resize and resize.minWidth or 50, resize and resize.minHeight or 50))
    if resize then entry.mover.grip = TK.Wrap(H:ShellEditGrip(key)) end
    self:Restore(entry)
    if self.unlocked then self:UpdateMovers() end
    return entry
end

-- s6-interface-5x (round 13, the separation's step 11): a panel turned off takes its places' entries and movers with it
TK.OnWithdraw(function(name, panel)
    local function gone(entry) return TK.OwnedBy(entry, name, panel) or TK.IsDead(entry.frame) end
    -- the list keeps a key's first entry and entries its latest (E:Register), so each is swept; the mover is the key's
    for key, entry in pairs(E.entries) do
        if gone(entry) then
            E.entries[key] = nil
            if entry.mover then TK.DestroyFrame(entry.mover) end
            H:ShellEditRemove(key)
        end
    end
    local kept = {}
    for _, entry in ipairs(E.list) do
        if not gone(entry) then kept[#kept + 1] = entry end
    end
    E.list = kept
end)

--- Whether the player has saved a place for this key (a drag, a nudge or a resize in Edit Mode).
function E:HasSavedPlace(key)
    local p = TK.DB.profile.positions[key]
    return type(p) == "table" and p[1] ~= nil
end

--- Where the entry goes: the player's saved place, else the interface's layout (T-36 step 3), else the panel's default.
function E:SavedPosition(entry)
    if self:HasSavedPlace(entry.key) then return TK.DB.profile.positions[entry.key] end
    return laidPlace(entry.key) or entry.authoredDefault or entry.default
end

--- Places the entry's frame (E:SavedPosition) and gives it the active interface's layout size (T-36 step 3).
function E:Restore(entry)
    if self:HasSavedPlace(entry.key) and TK.Xml then TK.Xml.ReleaseLayout(entry.frame) end
    local p = self:SavedPosition(entry)
    if TK.Xml then
        TK.Xml.LayoutCall(entry.frame, "ClearAllPoints")
        TK.Xml.LayoutCall(entry.frame, "SetPoint", p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    else
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    end
    local laid = layoutOf(entry.key)
    if laid then sizeFromLayout(entry, laid) end
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
    if TK.Xml then TK.Xml.ReleaseLayout(entry.frame) end
    self:Restore(entry)
    TK.FireEvent("TK_FRAME_MOVED", entry.key)
end

--- Places an entry's frame with its bottom-left corner at (l, b) in UIParent units.
local function placeAt(entry, l, b)
    local s = entry.frame:GetEffectiveScale()
    if TK.Xml then
        TK.Xml.LayoutCall(entry.frame, "ClearAllPoints")
        TK.Xml.LayoutCall(entry.frame, "SetPoint", "BOTTOMLEFT", UIParent, "BOTTOMLEFT", l / s, b / s)
    else
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l / s, b / s)
    end
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

-- ----- the movers (the shell's) -----

function E:Select(entry) H:ShellEditSelect(entry and entry.key) end

--- Each mover shown or hidden as the state is now, and their levels by their frames' sizes (the shell's).
function E:UpdateMovers() H:ShellEditUpdateMovers() end

TK.ShellCalls = TK.ShellCalls or {}

-- Whether a mover shows: its entry's enabled, and not a replaced component's frame (TK.ReplaceComponent) nor an interface's
-- panel that is off (s6-interface-5x round 12, build 46: TK.Interfaces:Dormant; Modern's minimap or player frame in a 7.x
-- profile).
TK.ShellCalls["edit.shown"] = function(key)
    local entry = E.entries[key]
    if not entry then return false end
    local owner = rawget(entry.frame, "__component")
    return ((entry.enabled == nil or entry.enabled()) and not (owner and owner.replaced)
        and not (owner and TK.Interfaces:Dormant(owner.name))) and true or false
end

-- A drag, a nudge or a resize ended: the place saved.
TK.ShellCalls["edit.save"] = function(key)
    local entry = E.entries[key]
    if entry then E:Save(entry) end
end

-- The grip's new size, every frame of its drag, handed to the component.
TK.ShellCalls["edit.resize"] = function(key, w, h)
    local entry = E.entries[key]
    if entry and entry.resize then
        if TK.Xml then TK.Xml.ReleaseLayout(entry.frame) end
        entry.resize.set(math.floor(w + 0.5), math.floor(h + 0.5))
    end
end

-- At a drag's start: Show Grid, Snap to Frames and the grid's size.
TK.ShellCalls["edit.machine"] = function()
    local g = TK.Machine:Get()
    return g.grid and true or false, g.snap and true or false, g.gridSize or 32
end

-- A mover's or a grip's tooltip; no key hides it.
TK.ShellCalls["edit.tooltip"] = function(key, which)
    if not key then GameTooltip:Hide() return end
    local entry = E.entries[key]
    if not entry then return end
    if which == "grip" then
        GameTooltip:SetOwner(entry.mover.grip, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Drag to resize", 1, 1, 1)
    else
        GameTooltip:SetOwner(entry.mover, "ANCHOR_TOP")
        GameTooltip:AddLine(entry.label, 1, 0.82, 0)
        GameTooltip:AddLine("Drag to move. Right-click for settings.", 1, 1, 1)
        GameTooltip:AddLine("Arrow keys nudge the selected frame (Shift: 10).", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

--- Arrow keys nudge the selected frame while unlocked (the bindings' OnKey asks first); the shell decides
--- (EditMode.Key).
-- WIRE: shared/bindings.lua asks this before the game's own keys; an arrow handled here (true) is consumed and never
-- reaches 4a's UserPane::HandleKeyOrTextEvent (0x005A5BD0), where it would walk or turn the character and send that.
-- Changing when a key is handled (EditMode.Key: unlocked, a key down, a frame selected, an arrow) changes what the
-- server sees.
function E:OnKey(key, down) return H:ShellEditKey(key, down) end

-- ----- the grid (the shell's) -----

function E:UpdateGrid() H:ShellEditUpdateGrid() end

-- drawn again for the new screen while it shows
TK.On("DISPLAY_SIZE_CHANGED", function() E:UpdateGrid() end)
TK.On("UI_SCALE_CHANGED", function() E:UpdateGrid() end)

-- ----- the edit-mode dialog (the shell's) -----
-- s6-ui-core (round 54; the owner, 2026-10-05: "Add a button called Keybinds to the edit menu next to Lock. If you press
-- Keybinds it switches to that mode. Also when you open this, the button starts with Unlock: you have to click it first to
-- start dragging. Then you can click it again to lock. If you click Keybinds when it's unlocked it should automatically
-- relock, and clicking the Lock button should turn off the keybind mode (both can't be on at the same time)."): Edit Mode
-- opens locked; Unlock / Lock moves the frames or stops; Keybinds is key-binding mode (shared/bindings.lua, TK.KeyBindMode),
-- whose line and results show here. Its close box and Escape close it, locked and with key-binding mode off. Round 171
-- (U-64 step 2): all of that is the shell's (EditMode.cs); this file keeps the Lua side it asks for.

local dialog = TK.Wrap(H:ShellEditFrame())
_G.TKEditModeDialog = dialog
dialog.__name = "TKEditModeDialog"
dialog.lock = TK.WrapShellButton(H:ShellEditControl("lock"))
dialog.keybinds = TK.WrapShellButton(H:ShellEditControl("keybinds"))
for _, name in ipairs({ "closeButton", "grid", "snap", "hint", "status" }) do
    dialog[name] = TK.Wrap(H:ShellEditControl(name))
end
_G.TKEditGrid = TK.Wrap(H:ShellEditControl("gridFrame"))

-- Show Grid's and Snap to Frames' clicks, kept in TK.Machine (the shell draws the grid again after Show Grid's).
TK.ShellCalls["edit.grid"] = function(_, on)
    TK.Machine:Get().grid = on
    TK.Machine:MarkDirty()
end
TK.ShellCalls["edit.snap"] = function(_, on)
    TK.Machine:Get().snap = on
    TK.Machine:MarkDirty()
end

-- The Lua side of the shell's unlock (on) and lock, in the order E:Unlock and E:Lock had: the mirror, key-binding mode
-- off at a lock (an unlock turns it off itself, before it opens the window), and the Visibility rules, which show the
-- panels hidden while locked.
TK.ShellCalls["edit.unlocked"] = function(_, on)
    E.unlocked = on and true or false
    if not on then TK.KeyBindMode:Disable() end
    for frame in pairs(TK.Visibility.frames) do TK.Visibility:Apply(frame) end
end

-- Key-binding mode (shared/bindings.lua), for the shell's Keybinds, Lock and Unlock: on (true) or off (false) when
-- asked, and whether it is on.
TK.ShellCalls["edit.keybindmode"] = function(_, on)
    if on == true then TK.KeyBindMode:Enable() elseif on == false then TK.KeyBindMode:Disable() end
    return TK.KeyBindMode.active and true or false
end

-- The see-through finish, as the game menu's: asked at opening, pushed when it changes while the window is open.
local function alpha() return W.FramePanelAlpha(dialog) end
TK.ShellCalls["edit.alpha"] = alpha
dialog:RegisterEvent("TK_PANEL_STYLE_CHANGED")
dialog:SetScript("OnEvent", function() if E:IsOpen() then H:ShellEditAlpha(alpha()) end end)

--- Opens Edit Mode, locked (the owner: "the button starts with Unlock"); only in the world.
function E:Open() H:ShellEditOpen() end

function E:IsOpen() return H:ShellEditIsOpen() end

--- The frames movable (Edit Mode opened if it is not); key-binding mode stops, as only one is on at a time.
function E:Unlock() H:ShellEditUnlock() end

--- The frames fixed again; Edit Mode stays open (its Close closes it).
function E:Lock() H:ShellEditLock() end

--- Keybinds: key-binding mode on (the frames locked first) or off.
function E:Keybinds() H:ShellEditKeybinds() end

--- Closes Edit Mode: locked, key-binding mode off.
function E:Close() H:ShellEditClose() end

--- The micro menu's and the game menu's Edit Mode: opens it, or closes it.
function E:Toggle() H:ShellEditToggle() end

--- Key-binding mode's line for its last key (TK.KeyBindMode:Status), in its colour.
function E:SetStatus(text, r, g, b) H:ShellEditStatus(text or "", r or 0.6, g or 0.9, b or 0.6) end

-- The dialog's line and its buttons' words as key-binding mode turns on or off, from wherever it is turned.
TK.On("TK_KEYBIND_MODE", function() H:ShellEditState(TK.KeyBindMode.active and true or false) end)
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
---
--- s6-ui-core (round 149): the offsets' ends are the screen's size when the page shows them (a range's min and max may
--- be functions, core/global/settings.lua's builders.range), not read for each tab made: the panels' pages are made
--- again and again (the bars' ten at each P:IsOn), some 300 tabs and 620 screen reads in a start.
local function screenWidth() return math.floor(GetScreenWidth()) end
local function screenHeight() return math.floor(GetScreenHeight()) end
local function leftEnd() return -screenWidth() end
local function bottomEnd() return -screenHeight() end

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
    local args = {
        { type = "description", name = "Its size, and where it sits: a point of the screen and an offset from it. Dragging it in edit mode sets these too." },
        { type = "select", name = "Anchor", values = points,
          get = function() return pos()[1] end,
          set = function(_, v) E:SetAnchor(positionKey(), v) end },
        { type = "break" },
        { type = "range", name = "X Offset", min = leftEnd, max = screenWidth, step = 1,
          get = function() return pos()[3] or 0 end,
          set = function(_, v) local p = pos(); setPos(p[1], v, p[4] or 0) end },
        { type = "range", name = "Y Offset", min = bottomEnd, max = screenHeight, step = 1,
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
