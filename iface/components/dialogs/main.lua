-- s6-rules-dialogs: the original's dialog windows (plan 5.11), drawn from the dialog model (plan 5.7,
-- TK.Core.Rules.DialogRules) through __tk:GetDialogs(). One window per open dialog, by its serial, made by its class's
-- renderer (the other files here) and kept for reuse when it closes. The windows follow the model: they open, change
-- and close with its views, in its order (the newest on top). Their input goes back as input records (kit.lua); while
-- a dialog takes the keys (a modal one, a dimmer, the world map, a photo) every key-down is the model's
-- (TK.DialogKeyHook, called first by TK.Bindings:OnKey). The host that runs the rules attaches them
-- (TK.Unity.Dialogs.DialogBridge); until then no window shows.
--
-- A renderer: { build(view) -> window, update(window, view), key(window, key) -> true when the UI handled it first
-- (a list's arrows), look = the name of its entry in the dialogs' look, which sizes and places it and says where it
-- opens (near the centre, or its open(window, view) for a pane with a place of its own) }. A renderer left whole (the
-- world map, the photo: misc.lua) has its own place(window, view). A window's Values() gives its fields in the view's
-- order.
--
-- While the rules are modal with no dialog in front (the refresh and bulletin dimmers, ScreenDimmer: D-84, D-35b) the
-- screen is dimmed and takes every click.

local C = TK.GetComponent("dialogs")
local H = __tk
local K = require("components.dialogs.kit")
C.kit = K
-- s6-modular-g (interfaces): the dialogs' look, each window's size and where its parts sit; the renderers keep what the
-- dialogs do and send. Step 6 of the interface separation (s6-characters, round 46): the default look is the component's
-- own (components/dialogs/look/: today's numbers, drawn with interfaces/defaultskin.lua; Modern builds its own
-- capsule with With and replaces its skin, interfaces/modern/skin.lua, when restyled), and the profile's look
-- (ApplySettings) is resolved over it, so an entry a look lacks is the default's (resolve, below).
local D = require("components.dialogs.look")
C.look = D
C.lookModule = D -- the profile's look as its interface gives it (C.look is it resolved)
C.renderers = {}
C.windows = {}
C.pool = {}

require("components.dialogs.alerts")
require("components.dialogs.npc")
require("components.dialogs.merchant")
require("components.dialogs.exchange")
require("components.dialogs.bulletin")
require("components.dialogs.social")
require("components.dialogs.misc")
require("components.dialogs.shops")
require("components.dialogs.web")
require("components.dialogs.parcels") -- s6-input (round 49, separation step 4b): TK.Game.Parcels, before the panes' renderer
require("components.dialogs.panes")
require("components.dialogs.collection")
require("components.dialogs.fitting")
require("components.dialogs.generic")
require("components.dialogs.chatcolor") -- s6-ui-chat: the chat colour dialog's window

-- The panes that take every key without being modal (behaviour.md 1.2): the world map at the root, a photo.
local KEY_TAKERS = { WorldMapPane = true, PhotoPane = true }

local revision = -1

-- s6-characters (round 46, step 6; the plan's 5.14): a look resolved over the default look, one table a look (the pooling
-- in Refresh compares a window's look with the one in use): an entry the look lacks is the default's. A look no longer
-- falls back through a metatable of its own. Drawing only: a look sizes, places and draws.
local resolved = setmetatable({}, { __mode = "k" })
local function resolve(look)
    if look == D then return D end
    local r = resolved[look]
    if not r then
        r = setmetatable({}, { __index = function(_, key)
            local v = look[key]
            if v == nil then v = D[key] end
            return v
        end })
        resolved[look] = r
    end
    return r
end

--- s6-characters (round 46, step 6): the look that makes a renderer's window, says where it opens and marks its focus
--- (its Window, Open and FocusEdge), and its entry: the profile's look when it has an entry of its own for the renderer,
--- else the default (a renderer left whole, with no entry, too). An entry may leave some of its renderer's classes to the
--- default (entry.default[class]: a class 4a draws another way). The parts' entries are read through C.look either way,
--- as before (the profile's own, else the default's). Drawing only.
local function drawnBy(r, class)
    local own = r.look and C.lookModule[r.look]
    if own ~= nil and own ~= D[r.look] then
        if own.default and own.default[class] then return D, own end
        return C.look, own
    end
    return D, r.look and D[r.look]
end

local function takeWindow(view)
    local r = C.renderers[view.name] or C.renderers.Generic
    local pool = C.pool[view.name]
    local win = pool and table.remove(pool)
    if win then
        -- s6-ui-core (round 20's live purchase): a window back from the pool draws a new dialog, whose lists start with
        -- no row picked and no anchor, as a new ListPane's m_selectedIndex. It kept the last dialog's, so Down on
        -- Yunsil's "Deal?" after her Buy menu picked the second row (No) and nothing was bought. A new list starts at its
        -- top as well (review r20 P3: a new ScrollPane's position is 0, ScrollPane.cpp:22).
        for _, c in pairs(win.controls or {}) do
            if c.list then
                c.list.selected, c.list.anchor = {}, nil
                if c.ScrollToTop then c:ScrollToTop() end
            end
        end
    end
    if not win then
        -- s6-characters (round 46, step 6): the kit's K.Window gives the drawing look its entry and class (C.drawing);
        -- the renderer's build gets its entry too. (s6-interface-5x round 15, step 9: C.building and C.buildingClass, the
        -- old names the looks read before step 6, went.)
        local by, entry = drawnBy(r, view.name)
        C.drawing = { look = by, entry = entry, class = view.name }
        win = r.build(view, C.look[r.look or ""])
        C.drawing = nil
        win.drawnBy = by
        win.renderer = r
        win.className = view.name
        win.look = C.look -- s6-modular-g (Astra's r8 review, 5): the look it was built with
        win.builtStrata = win:GetFrameStrata() -- s6-sandbox (round 12): Refresh may raise it while a trade is open
        C:Own(win)
    end
    return win
end

--- Follows the model: new windows for new dialogs, the others updated, the closed ones hidden and kept.
function C:Refresh()
    revision = H:DialogRevision()
    local views = H:GetDialogs() or {}
    local seen = {}
    self.views = views
    local raised = false -- s6-sandbox (round 12): the trade window or a window above it in the stack
    for i, view in ipairs(views) do
        local win = self.windows[view.serial]
        if not win then
            win = takeWindow(view)
            TK.Cursor:DialogOpened() -- s6-interface-5x-b (round 7): 4a's DialogPane constructor's normal cursor (core/cursor.lua)
            win.serial = view.serial
            win.opened = true
            self.windows[view.serial] = win
            win:ClearAllPoints()
            -- s6-modular-g (interfaces): where it opens is the look's; a renderer left whole places itself.
            if win.renderer.place then
                win.renderer.place(win, view)
            else
                (win.drawnBy or C.look).Open(win, view, i, C.look[win.renderer.look] or {}) -- round 46: the drawing look's
            end
        end
        seen[view.serial] = true
        win.view = view
        win.updating = true
        -- s6-modular-g (Astra's review of round 10): a window is drawn by the look it was built with, also when the look
        -- changed while it was open: the look its renderer and the kit read (C.look) is the window's own while it updates
        local inUse = self.look
        self.look = win.look or inUse
        local ok, err = pcall(win.renderer.update, win, view)
        if not ok then __tk:LogError("dialog window " .. view.name .. ": " .. tostring(err)) end
        win.updating = false
        win.opened = false
        -- s6-sandbox (round 12): from the trade window up, the stack is on the client's own layer (FULLSCREEN_DIALOG, which
        -- no plugin frame reaches), in the same order: no plugin can draw over the offer or take a click on Accept, and
        -- its pickers and anything opened over it stay over it. The other windows keep the strata they were built with.
        if view.name == "ExchangeDialog" then raised = true end
        if (TK.LOST_CONNECTION_DIALOGS or {})[view.name] then raised = true end -- s6-ui-core (round 33, review r32 P2 1): over the cover
        win:SetFrameStrata(raised and "FULLSCREEN_DIALOG" or win.builtStrata or "DIALOG")
        win:SetFrameLevel(10 + i * 20)
        win:SetShown(view.visible and not win.renderer.hidden)
        K.ShowState(win, view)
        self.look = inUse
    end
    for serial, win in pairs(self.windows) do
        if not seen[serial] then
            win:Hide()
            win.serial, win.view = nil, nil
            self.windows[serial] = nil
            -- s6-modular-g (Astra's r8 review, 5): a window built with another look (open when the look changed) is
            -- not reused; the next dialog of its class gets a window of the look in use
            if win.look == self.look then
                local pool = self.pool[win.className] or {}
                pool[#pool + 1] = win
                self.pool[win.className] = pool
            end
        end
    end
    self:ShowCovers(views)
end

--- The dimmer: the rules modal with no dialog in front.
function C:ShowCovers(views)
    local front = false
    for _, view in ipairs(views) do
        if view.front then front = true end
    end
    if self.dim then self.dim:SetShown(H:DialogModal() and not front) end
end

--- The window whose dialog takes the keys now: the front modal one, else a pane that takes every key.
function C:KeyWindow()
    local views = self.views or {}
    for i = #views, 1, -1 do
        if views[i].front then return self.windows[views[i].serial] end
    end
    for i = #views, 1, -1 do
        if KEY_TAKERS[views[i].name] then return self.windows[views[i].serial] end
    end
    return nil
end

local POPUPS = { "MenuVarietySelectPane", "RightButtonMenuPane" }

--- The popups (the Menu popup, the player menu) see every press before what is under it, as 4a's handler tree offers
--- it to them first: the record the control under the pointer posts carries the press to them, and each decides
--- (the Menu popup takes a left press outside it and lets a right press by; the player menu lets a left press go on
--- and takes a right press). A press on our own UI posts nothing, so it asks the bridge to post it at the end of its
--- event, if nothing else did (reviews r7, 5 and r8, 2: no catcher, one record a press).
TK.On("GLOBAL_MOUSE_DOWN", function(_, button)
    if H:DialogModal() then return end
    local open = false
    local f = GetMouseFocus()
    for _, name in ipairs(POPUPS) do
        local menu = C:Find(name)
        if menu and menu.view then
            open = true
            local g = f
            while g do
                if g == menu then return end
                g = g:GetParent()
            end
        end
    end
    if not open then return end
    local x, y = GetCursorPosition()
    H:DialogDismissOnPress(button or "LeftButton", math.floor(x), math.floor(y))
end)

--- A dialog the player opens with a press, through the model's opener (the micro menu's Menu button: the original
--- opens its popup on the left press, D-55).
TK.Dialogs = {
    Open = function(name, mode, args)
        local x, y = GetCursorPosition()
        return H:DialogOpen(name, mode or 0, args, math.floor(x), math.floor(y))
    end,
    --- s6-play-modes (round 8, interface-separation step 4, 5.10): a Menu button's press, every interface's (Modern's
    --- micro menu, 7.x's MENU). Wire: MenuVarietyPane::HandlePointerOrMouseEvent (0x005BC690) opens the popup
    --- (MenuVarietySelectPane) on the left press, or closes the open one; the press goes to the dialogs' model in its own
    --- event (one record a press), so the popup, its rows and what they open or send are the model's. Changing which
    --- press opens it, or when, changes what the client does with it.
    MenuPress = function(button)
        if button == "LeftButton" then TK.Dialogs.Open("MenuVarietySelectPane") end
    end,
    --- The player menu (D-56) for a player by object id and name, on a right-click (the target and party frames; the
    --- head's routes, round 8): the model opens it, or not (the original's gates), and sends what its rows send.
    PlayerMenu = function(id, name)
        if not id or id == 0 then return end
        local x, y = GetCursorPosition()
        return H:DialogOpen("RightButtonMenuPane", 0, string.format("%d", id) .. string.char(31) .. (name or ""),
            math.floor(x), math.floor(y))
    end,
}

-- s6-characters (round 46, step 6 of the interface separation; the plan's 5.14): the component's public face, in place of
-- the internals the looks and other components read (its windows, renderers and kit, the kit's private frame fields).
-- They are the kit's and the component's own functions, unchanged: what each posts, and when, is as before (the kit's
-- wire comments).

--- The window of the newest open dialog of a class, or nil.
function TK.Dialogs.Find(class) return C:Find(class) end

--- The model's dialogs as the windows follow them, oldest first ({ name, serial, contents, ... }).
function TK.Dialogs.Views() return C.views or {} end

--- The open windows, by their dialog's serial.
function TK.Dialogs.Windows() return C.windows end

--- The shared default drawing, for a look's plain panes that keep its opening and focus placement.
function TK.Dialogs.DefaultLook() return D end

--- The kit's input path (wire: the kit's comments): Pointer(win, control, button, down, part), a press or release on a
--- window's control; PressAt(win, x, y, button, down, double), one given to the control at a point (a look's slide
--- shield), and PressedMoveAt(win), a held move after it; Control(frame, win, index, part), a frame outside the window
--- (an interface's own button for one of the dialog's controls) made its control for the release's lookup.
TK.Dialogs.Pointer = K.Pointer
TK.Dialogs.PressAt = K.PressAt
TK.Dialogs.PressedMoveAt = K.PressedMoveAt
TK.Dialogs.Control = K.Control

--- Whether this frame belongs to a dialog: the parcel strip leaves that dialog its release (4a ParcelPane's
--- 0x00546610). Moved from the interfaces' private-field check; changing it changes what the server sees.
function TK.Dialogs.IsControl(frame) return frame ~= nil and frame.__dialogWin ~= nil end

--- The frame's logical parent for the parcel release lookup (4a ParcelPane 0x00546610). Moving this walk into
--- the kit keeps private dialog ancestry here; changing the walk changes which release the server sees.
function TK.Dialogs.Parent(frame) return frame.__dialogParent or frame:GetParent() end

--- The parcel window's parent, for the panel that draws the parcel and letter buttons (panes.lua).
function TK.Dialogs.ParcelParent() return C:ParcelParent() end

--- A renderer of a class from outside the component (the macros' Macro Setup): see the renderer's shape at the top.
function TK.Dialogs.RegisterRenderer(class, r) C.renderers[class] = r end

--- A class's windows kept hidden while its dialog is open (settings' music page stands for the music dialog).
function TK.Dialogs.SetHidden(class, on)
    local r = C.renderers[class]
    if r then r.hidden = on and true or false end
end

--- The original's string by its id, or the fallback; and text from the model with the original's line breaks.
TK.Dialogs.String = K.String
TK.Dialogs.Text = K.Text

--- The kit's input routing for a look that draws the original's windows (moved there from 7.x's look, unchanged; their
--- wire comments are the kit's): a list's rows on 4a's geometry, a frame that takes a press and does nothing, a slide's
--- shield that passes its presses on.
TK.Dialogs.ListRows = K.ListRows
TK.Dialogs.Blocker = K.Blocker
TK.Dialogs.SlideShield = K.SlideShield

--- The key hook (bindings.lua): true when the key was the dialogs'.
function TK.DialogKeyHook(key)
    if H:DialogRevision() ~= revision then C:Refresh() end
    local win = C:KeyWindow()
    if win then
        if win.renderer.key then win.renderer.key(win, key) end
        K.Key(win, key)
        return true
    end
    if H:DialogModal() then
        -- A dimmer: the rules take the key and do nothing with it.
        H:DialogKey(key, 0, nil)
        return true
    end
    -- The Menu popup and the player menu: any key closes them (MenuVarietySelectPane::HandleKeyOrTextEvent,
    -- RightButtonMenuPane's 0x00554F90) and goes on to the game; Escape stops there, so the UI's own Escape does not
    -- open its game menu as well.
    for _, name in ipairs(POPUPS) do
        local menu = C:Find(name)
        if menu and menu.view then
            K.Key(menu, key)
            return key == "ESCAPE"
        end
    end
    return false
end

--- s6-input (round 18, review r12 finding 2): the windows as the rules' state is now (the state a pointer barrier
--- published), before a click is hit-tested and run: 4a's RawMoneyUpdate wrote the edit before SetHoverControl read it.
function TK.DialogSync()
    if H:DialogRevision() ~= revision then C:Refresh() end
    local win = C:KeyWindow()
    if win and win.view and win.view.front and win:IsVisible() then K.SyncFocus(win, win.view, revision) end
end

--- s6-input (round 19, review of UI round 21 finding 2): the handle of the front modal dialog's window, which takes the
--- keys; its own fields type while the rules hold the keys from the rest. 0 for none.
function TK.DialogKeyWindow()
    if H:DialogRevision() ~= revision then C:Refresh() end
    local win = C:KeyWindow()
    if win and win.view and win.view.front and win:IsVisible() then return win.__h end
    return 0
end

--- s6-input (round 58): each open dialog's window handle and its dialog's serial, as pairs of values (TK.Dialogs.Windows
--- for the host: plain numbers, no table to read from its side). The host finds by them the dialog whose window holds the
--- box with the keyboard and names it in its routing (InputRouting.TextDialog).
--- Wire: a closed dialog's window is hidden only at the next C:Refresh, a frame after the rules closed the dialog; until
--- then the logic must tell that field from one of the UI's own boxes, or the key pressed right behind the closing key is
--- typed into it and never reaches the game (4a's reaches UserPane 0x005A5BD0). Changing this changes what the server sees.
function TK.DialogWindowSerials()
    local out = {}
    for serial, win in pairs(C.windows) do
        out[#out + 1] = win.__h
        out[#out + 1] = serial
    end
    return table.unpack(out)
end

-- s6-modular-c (the Experimental build): a drawing style chosen while a dialog shows a picture (a character's, a creature's,
-- an item's, the head choice's heads) draws it again in the new style, as a change of the model does.
TK.On("TK_DRAWING_STYLE_CHANGED", function()
    if next(C.windows) then C:Refresh() end
end)

function C:OnEnable()
    local driver = CreateFrame("Frame", "TKDialogs", UIParent)
    driver:SetSize(1, 1)
    driver:SetScript("OnUpdate", function() TK.DialogSync() end) -- s6-input: the same sync, each frame
    self.driver = driver
    -- ScreenDimmer's grey (ScreenDimmer.cpp): the whole screen, over the game and the HUD, taking every click.
    local dim = CreateFrame("Frame", "TKDialogDimmer", UIParent)
    dim:SetFrameStrata("FULLSCREEN")
    dim:SetAllPoints(UIParent)
    dim:EnableMouse(true)
    local grey = dim:CreateTexture(nil, "BACKGROUND")
    grey:SetAllPoints(dim)
    grey:SetColorTexture(0, 0, 0, 0.45)
    dim:Hide()
    self.dim = dim
end

--- s6-modular-g (interfaces, phase 2): the profile's dialogs look (the Interfaces page's choice; Modern's
--- unless another installed interface's is chosen). Windows made from now on take it: the pooled ones are dropped, the open
--- ones keep theirs until they close. A look only sizes and places, so changing it sends nothing.
function C:ApplySettings()
    local module = TK.Interfaces:DialogsLook()
    local look = resolve(module) -- s6-characters (round 46, step 6): over the default
    if look ~= self.look then
        self.look, self.lookModule = look, module
        self.pool = {}
    end
    -- s6-interface-5x-b (round 6): a look drawn from the old art (L.LegacyLayouts: 5.x's) has the rules open 4a's legacy
    -- branch of a dialog whose controls differ there (DialogRules.LegacyLayouts: the profile's CANCEL, which sends
    -- nothing). The one way a look reaches the rules; what any control sends is unchanged.
    H:SetDialogLegacyLayouts(look.LegacyLayouts == true)
end

--- The window of the newest open dialog of a class (tests, previews).
function C:Find(name)
    local views = self.views or {}
    for i = #views, 1, -1 do
        if views[i].name == name then return self.windows[views[i].serial] end
    end
    return nil
end
