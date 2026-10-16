-- The action wheel (plan 5.11, UI head note 33, plan D25): a bound key opens a wheel of actions centred on the mouse.
-- Its segments hold actions as hotbar buttons do (action slots 121-132, dragged onto them the same way), and a pick
-- runs one on its real input: a segment is a button whose press freezes its action (plan 5.9), so the wheel sends
-- nothing itself.
--
--   Hold mode (the default): the wheel shows while its key is held; a click on a segment picks it, and closes the wheel
--   unless "Stay open after a pick" is on. With "The key's release picks", letting go of the key runs the segment under
--   the mouse (none over no segment), as that release's input (s6-input's release pick, TK.Actions:RunFrame).
--   Toggle mode: a press opens it, a click on a segment picks and closes it, and the key again closes it.
--   Multi-pick (its own binding, default Shift+X): the wheel opens as in hold mode, each click runs its segment, and
--   it stays open until the key is released; that release picks nothing.
--   A click outside the wheel cancels it, always; so does Escape.
-- s6-ui-core (round 85): the XML twin's scripts; the catcher, the wheel and its segments are main.xml's (core/xml.md).

local C = TK.GetComponent("actionwheel")
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local Mark = require("interfaces.modern.slotmark") -- s6-ui-core (round 83): the red edge, as the action bars'

-- the segments' count, circle and size (main.xml's)
local WHEEL = TK.Xml.Data("main.xml").WHEEL
C.SEGMENTS = WHEEL.segments
C.FIRST_SLOT = 121
C.RADIUS = WHEEL.radius
C.SIZE = WHEEL.size

-- Its commands' default keys (X, Shift+X) and their being newer than the profiles' note are its manifest's (commands),
-- declared before the profile loads whether this file is loaded or not (s6-interface-5x round 13, the separation's
-- step 11).

local wheel, catcher
C.segments = {}

--- How the wheel is open: nil (closed), "hold", "toggle", "multi", or "edit" (from the settings page, to fill it).
C.state = nil

--- s6-ui-core (round 83; the owner, 2026-10-09: the red edge "on spells, not only the bars"): a segment's edge red while
--- what it holds cannot be used now (the page's switches; interfaces/modern/slotmark.lua). With no Cooldown frame to say
--- when an aether ends, it keeps the end (coolEnd) for the open wheel's OnUpdate. Drawing only.
local function markSegment(b)
    local kind, slot = Mark.ShownAction(b.action)
    local cooling, ends = Mark.Cooling(kind, slot)
    b.coolEnd = ends
    Mark.Draw(b, b.edge, Mark.Unusable(kind, slot, cooling, C:DB()), W.slotActionEdge)
end

local function refreshSegment(b)
    -- s6-ui-bars: an item is the item (its first slot), a spell the spell (its slot now, its name with the press); with
    -- none left, or the spell gone from the book, the segment runs nothing. s6-modular-g (round 19, the separation's
    -- step 8): the game layer's one attach (wire: TK.Game.Hotkeys.Attach, what the slot's use sends).
    local action, missing = TK.Game.Hotkeys.Attach(b, b.action)
    local name = TK.ActionInfo(action)
    if name then
        W.ActionIcon(b.icon, b.glyph, b, action, C.SIZE - 6, 3)
        if missing then b.icon:SetVertexColor(0.3, 0.3, 0.3, 1) end -- s6-ui-bars: darkened
    else
        b.icon:SetTexture("")
        b.glyph:SetText("")
    end
    b.name = name
    markSegment(b)
end

function C:Refresh()
    for _, b in ipairs(self.segments) do refreshSegment(b) end
end

--- The segments' red edges again (an aether began, the mana changed), while the wheel is open.
local function markSegments()
    if not C.state then return end
    for _, b in ipairs(C.segments) do markSegment(b) end
end

-- Head note 44: with spell icons animating, the open wheel's spells draw their icons' frame showing now (registered by
-- name, TK.SetSpellIconAnimator: s6-modular-g round 16).
TK.SetSpellIconAnimator("actionwheel", function()
    if not (wheel and wheel:IsVisible()) then return end
    for _, b in ipairs(C.segments) do
        local action = TK.ActionAt(b.action)
        if action and action.kind == "spell" then
            local _, _, missing = W.ActionIcon(b.icon, b.glyph, b, action, C.SIZE - 6, 3)
            if missing then b.icon:SetVertexColor(0.3, 0.3, 0.3, 1) end -- s6-ui-bars (review r5 finding 3)
        end
    end
end)

-- the scripts main.xml names
local scripts = {}
local making -- the index of the segment being made (scripts.Segments), for its Segment script

function scripts.Own(f) C:Own(f) end

function scripts.Close() C:Close() end

-- the ring round the segments, 10 beyond their edges
function scripts.Fit(f)
    local size = 2 * (C.RADIUS + C.SIZE / 2 + 10)
    f:SetSize(size, size)
end

-- A segment's action slot and the path its press goes on: the hotkey path (TK.Actions), whose press freezes the slot's
-- action, so the wheel sends nothing itself. Wire: a pick runs as a hotkey's (4a's UserPane::ExecuteHotkeyAction
-- 0x005A3AE0); changing this changes what the server sees. Its size, and its place on the circle, the first at the top.
function scripts.Segment(b)
    local i = making
    local wheel = b:GetParent()
    b.action = C.FIRST_SLOT + i - 1
    TK.Actions:SetPath(b, "hotkey")
    b:SetSize(C.SIZE, C.SIZE)
    local angle = math.pi / 2 - (i - 1) * 2 * math.pi / C.SEGMENTS
    b:SetPoint("CENTER", wheel, "CENTER", C.RADIUS * math.cos(angle), C.RADIUS * math.sin(angle))
end

function scripts.Segments(f, build)
    for i = 1, C.SEGMENTS do
        making = i
        C.segments[i] = build:New("Segment", f, "TKActionWheelSegment" .. i)
    end
    making = nil
end

-- A pick: placing the cursor's action, or the segment's frozen action run on the hotkey path. Wire: TK.Actions:RunFrozen
-- (4a's UserPane::ExecuteHotkeyAction 0x005A3AE0's run); changing this changes what the server sees.
function scripts.Pick(self, button)
    if TK.Cursor:ConsumeCancel(button) then return end
    if GetCursorInfo() then
        PlaceAction(self.action)
        C:Refresh()
        return
    end
    if C.state == "edit" or not self.name then return end
    TK.Actions:RunFrozen()
    if C.state == "toggle" or (C.state == "hold" and not C:DB().stayOpen) then C:Close() end
end

function scripts.DragStart(self)
    if TK.DB:Global().buttonLock and not IsShiftKeyDown() then return end
    if not HasAction(self.action) then return end
    PickupAction(self.action)
    C:Refresh()
end

function scripts.ReceiveDrag(self)
    if not GetCursorInfo() then return end
    PlaceAction(self.action)
    C:Refresh()
end

function scripts.Enter(self)
    wheel.label:SetText(self.name or "")
    local action = TK.ActionAt(self.action)
    if self.name and action and action.kind == "spell" then TK.ManaPreview.Show(self.name) end
end

function scripts.Leave()
    wheel.label:SetText("")
    TK.ManaPreview.Hide()
end

function scripts.AethersEnd()
    local now = GetTime()
    for _, b in ipairs(C.segments) do
        if b.coolEnd and now >= b.coolEnd then markSegment(b) end
    end
end

function C:OnEnable()
    local ui = TK.Xml.Load("main.xml", { scripts = scripts, elements = require("interfaces.modern.elements") })
    catcher, wheel = ui.catcher, ui.wheel
    TK.Escape:AddCancel("actionwheel", 5, function()
        if not C.state then return false end
        C:Close()
        return true
    end)
    TK.On("PLAYER_LEAVING_WORLD", function() C:Close() end)
    -- s6-ui-bars: while the wheel is open, an item's count (darkened at 0) follows the bag, the spells follow the book,
    -- and their pictures follow a drawing style.
    -- s6-modular-g (round 21, the owner's research on presses reaching the wrong place; Astra's self-review 21-2): and a
    -- slot or the cursor changed (core/cursor.lua's Cursor:Set fires ACTIONBAR_SLOT_CHANGED on every change). While the
    -- cursor holds an action the segments carry nothing (TK.Game.Hotkeys.Attach), and they carry their actions again when
    -- it is put down. WIRE: a segment left empty after a right click cancelled the held action sent nothing for a pick
    -- that runs its action (UserPane::ExecuteHotkeyAction 0x005A3AE0's run, as a hotkey's); changing this changes what
    -- the server sees.
    for _, e in ipairs({ "BAG_UPDATE", "SPELLS_CHANGED", "TK_DRAWING_STYLE_CHANGED",
                         "TK_SPELL_ICONS_CHANGED", -- s6-spell-icons: a spell's icon chosen in its editor
                         "ACTIONBAR_SLOT_CHANGED" }) do
        TK.On(e, function() if C.state then C:Refresh() end end)
    end
    -- s6-ui-core (round 83): the red edges as an aether begins and as the player's mana changes
    TK.On("ACTIONBAR_UPDATE_COOLDOWN", markSegments)
    TK.On("UNIT_POWER", function(_, unit) if unit == "player" then markSegments() end end)
end

--- Opens the wheel: at the mouse for a key's opening, at the screen's centre to fill it from the settings page.
function C:Open(state)
    if self.state then return end
    self.state = state
    self:Refresh()
    wheel:ClearAllPoints()
    if state == "edit" then
        wheel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    else
        local x, y = TK.Util.CursorRoot()
        wheel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    end
    wheel.label:SetText("")
    wheel.done:SetShown(state == "edit")
    -- Filling it from the settings page, the spell book and the bag stay usable: no catcher then.
    catcher:SetShown(state ~= "edit")
    wheel:Show()
end

function C:Close()
    if not self.state then return end
    self.state = nil
    wheel:Hide()
    catcher:Hide()
end

function C:IsOpen() return self.state ~= nil end

-- The keys: the wheel's own and the multi-pick one. A key held down repeats: only its first press counts.
local held = {}

-- s6-modular-g round 22: losing focus cancels a hold, choosing no segment. WIRE:
-- EventMan::ResetInputState (0x004A90D0) clears the original's keys; a release pick
-- here would send an action the player did not choose. Changing this changes what the server sees.
TK.On("INPUT_FOCUS_LOST", function()
    held = {}
    if C.state == "hold" or C.state == "multi" then C:Close() end
end)

local function press(command, state)
    if held[command] then return end
    held[command] = true
    if not TK.GameState:InWorld() then return end
    if state == "multi" then
        if C.state ~= "multi" then C:Close() end
        return C:Open("multi")
    end
    local mode = C:DB().mode == "toggle" and "toggle" or "hold"
    if C.state then C:Close() else C:Open(mode) end
end

--- The segment at the pointer, or nil: hit-tested where the pointer is at the release (review r19 finding 6), not by the
--- hover the UI last refreshed, so a move onto a segment and the release in one frame pick that segment.
local function hovered()
    local x, y = TK.Util.CursorRoot()
    for _, b in ipairs(C.segments) do
        if b:IsVisible() then
            local l, bottom, w, h = TK.Util.RootRect(b)
            if x >= l and x <= l + w and y >= bottom and y <= bottom + h then return b end
        end
    end
end

local function release(command)
    held[command] = nil
    if command == "ACTIONWHEEL" and C.state == "hold" then
        local b = C:DB().releasePicks and hovered()
        if b and b.name then TK.Actions:RunFrame(b) end
        C:Close()
    elseif command == "ACTIONWHEEL_MULTI" and C.state == "multi" then
        C:Close()
    end
end

TK.Bindings:RegisterCommand("ACTIONWHEEL", "Action Wheel", function() press("ACTIONWHEEL") end, nil,
    function() release("ACTIONWHEEL") end)
TK.Bindings:RegisterCommand("ACTIONWHEEL_MULTI", "Action Wheel (multi-pick)", function() press("ACTIONWHEEL_MULTI", "multi") end,
    nil, function() release("ACTIONWHEEL_MULTI") end)

function C:ApplySettings()
    -- s6-interface-5x (round 12, build 46): turned off, an open wheel closes (its keys are inert then: TK.Bindings:Inert)
    if self:DB().enabled == false then
        if self.state then self:Close() end
        for command in pairs(held) do held[command] = nil end -- a key held then has no release that reaches it (inert)
    end
    if self.state then self:Refresh() end
end
