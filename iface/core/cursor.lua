-- The cursor's held action, as WoW's PickupAction / PlaceAction / ClearCursor. An action is
-- { kind = "spell"|"item", slot = 1..52 } (s6-ui-bars: a spell with its name, an item by its kind) or a text macro
-- { kind = "macro", id }, plus from = "bag" or "book" when it
-- was picked up there (the bag moves or drops such an item). The action slots are the character's hotbars
-- (TK.Characters). Everything is local UI state; nothing is sent anywhere.

local H = __tk
local W = TK.UI

local Cursor = { held = nil }
TK.Cursor = Cursor

-- The held icon paint and frame are shared widgets; the held action remains local cursor state.
local IconWidget = require("core.widgets.actionicon")
local icon = W.CursorIcon("TKCursorIcon")

-- s6-ui-bars (plan 5.11, the owner's WoW bars): an item on a bar is the item, not its bag slot. It is named by its kind:
-- the 0F's second text (4a's "meta key", a key naming the item's kind; the snapshot's ItemSlot.IconKey), else its name,
-- and keeps the name and picture it had when placed, for when none is left. Its count is the total over every slot
-- holding that kind; a press uses the first such slot (1C, as 4a's use of that slot), and with none left it does nothing.
-- { kind = "item", slot = n } without a kind (an older or imported bar) is still the slot's, until the bars name it.

--- An item kind's first slot holding it (nil for none) and the total count over every slot.
function TK.FindItem(kind)
    local first, total = nil, 0
    for s = 1, 52 do
        local ok, name, count, key = H:GetItemSlot(s)
        if ok and (key ~= "" and key or name) == kind then
            first = first or s
            total = total + count
        end
    end
    return first, total
end

--- The item action naming the item in a bag slot (its kind, name and picture), or nil when the slot is empty.
function TK.ItemActionAt(slot)
    local ok, name, _, key, iconId = H:GetItemSlot(slot)
    if not ok then return nil end
    -- The test server's names carry the count ("Acorn (5)"); the bar shows the count itself.
    return { kind = "item", item = key ~= "" and key or name, name = name:gsub(" %(%d+%)$", ""), icon = iconId }
end

-- s6-ui-bars (the owner, 2026-10-02): a spell on a bar is the spell, not its book slot: { kind = "spell", name, slot },
-- the slot being where it was last seen, and for this session its record (rid: the number the rules gave its slot's
-- spell, which follows the book's swaps, so two spells of one name are told apart; review r5 finding 1). It resolves to
-- the slot holding its record; while a swap moves the record, to none; else to the slot holding its name (its own
-- first, else the lowest). When the book has none of it, it stays on the bar darkened and its press sends nothing, as
-- an item at none. A press carries the record and the name, and the rules resolve them again at its dispatch
-- (Spells.CastSlot), so a cast never goes to a slot the spell left.

--- A spell slot's record this session (0 for none; always 0 offline) and its name ("" when empty), as the rules have them.
local function record(s) return H:GetSpellRecord(s) end

--- The slot holding a record, or nil (s6-optimize round 11: the first slot, found in one call, H:FindSpellRecord).
local function recordSlot(rid)
    local s = H:FindSpellRecord(rid)
    if s ~= 0 then return s end
end

--- A spell action's slot now: the slot holding its record (none while a swap moves it); else its own slot while that
--- holds its name, else the lowest slot holding the name; else nil. A spell without a name (an older bar, until
--- TK.FollowSpells names it) is its slot.
--- Wire: this selects the slot a bar's or the wheel's press casts, and none suppresses the cast (TK.ActionMissing,
--- TK.Actions:Clear: the press runs nothing); the rules resolve it the same way again at the press's dispatch (TK-Core's
--- Spells.CastSlot), and the cast is 4a's UserPane::UseCommandSlot (0x005A4530) for that slot. Changing what it finds
--- changes what the server sees.
function TK.SpellSlot(action)
    local own = action.slot
    if not action.name then return own end
    if action.rid then
        local at = recordSlot(action.rid)
        if at then return at end
        if H:SpellRecordMoving(action.rid) then return nil end
    end
    if own and select(2, record(own)) == action.name then return own end
    local s = H:FindSpellName(action.name) -- the lowest slot holding the name (s6-optimize round 11: in one call)
    if s ~= 0 then return s end
end

--- The slot an action acts on now: a spell's (by its name), an item's first slot (nil when none is left).
function TK.ActionSlot(action)
    if action and action.kind == "item" and action.item then return (TK.FindItem(action.item)) end
    if action and action.kind == "spell" then return TK.SpellSlot(action) end
    return action and action.slot
end

--- An item none of which is left, or a spell the book no longer has: shown darkened, and its press sends nothing.
function TK.ActionMissing(action)
    if not action then return false end
    if action.kind == "item" and action.item then return (select(2, TK.FindItem(action.item))) == 0 end
    if action.kind == "spell" and action.name then return TK.SpellSlot(action) == nil end
    return false
end

--- A spell action's TK.ActionInfo values, then whether the book lacks it (TK.ActionMissing's answer, from the same
--- lookup; s6-optimize round 11: the animators asked for it again each frame). animated: the icon is TK.SpellIcon's (the
--- frame showing now while spell icons animate, head note 44), the still one only when it has none, as the action icon
--- widget shows it (TK.UI's W.ActionIcon); else the still one.
local function spellInfo(action, animated)
    local slot = TK.SpellSlot(action) -- s6-ui-bars: the spell by its name
    local missing = action.name ~= nil and slot == nil
    local ok, name, key = false, nil, nil
    if slot then ok, name, key = H:GetSpellSlot(slot) end
    if not ok then
        -- s6-ui-bars: no longer in the book: shown by its name, darkened (TK.ActionMissing)
        if not action.name then return nil end
        name, key = action.name, "spell"
    end
    -- s6-characters seam: the spell's icon from its effect animation (plan 5.11), once one is known
    local art, w, h = "", nil, nil
    if animated then art, w, h = TK.SpellIcon(name) end
    if art == "" and ok then art, w, h = require("data.spell_icons").Get(name, false) end
    if art == "" then art, w, h = nil, nil, nil end
    return name, key, name:sub(1, 1):upper(), 0, art, w, h, missing
end

--- An action's name, placeholder icon key, glyph and count, and its original icon (texture key, width, height) when
--- the packs have one; nil if its slot is empty. Items have the original's icons; spells have none in the original.
function TK.ActionInfo(action)
    if not action then return nil end
    if action.kind == "spell" then
        local name, key, letter, count, art, w, h = spellInfo(action, false)
        if name then return name, key, letter, count, art, w, h end
    elseif action.kind == "item" and action.item then
        -- s6-ui-bars: the item by its kind, shown (with a count of 0) when none is left
        local slot, total = TK.FindItem(action.item)
        local name, iconId = action.name or "?", action.icon
        if slot then
            local _, n, _, _, i = H:GetItemSlot(slot)
            name, iconId = n:gsub(" %(%d+%)$", ""), i
        end
        return name, action.item, name:sub(1, 1):upper(), total, TK.Art.Icon(iconId)
    elseif action.kind == "item" then
        local ok, name, count, key, iconId = H:GetItemSlot(action.slot)
        if ok then return name, key, name:sub(1, 1):upper(), count, TK.Art.Icon(iconId) end
    elseif action.kind == "macro" then
        -- The line as the import kept it; an empty one sends nothing but 0E 00 00, and shows a placeholder.
        local text = H:GetMacroText(TK.Characters.ref or "", action.id)
        if text then return text ~= "" and text or "(empty)", "say", "\"", 0 end
    elseif action.kind == "usermacro" and TK.MacroActionInfo then
        return TK.MacroActionInfo(action) -- s6-macros: one of the player's macros (components/macros)
    end
    return nil
end

--- Head note 44: whether spell icons animate (the Interface page's "Animate Spell Icons", off by default).
function TK.SpellIconsAnimated()
    local c = TK.GetComponent("interface")
    return c ~= nil and c:DB().animateSpellIcons == true
end

--- Head note 44: a spell's icon from s6-characters' spell icons (plan 5.11): its texture key, width and height, or ""
--- when nothing is known (the plain square stays). Animated, the frame showing now, so the visible rows and slots ask
--- each frame (TK.SpellIconAnimators).
function TK.SpellIcon(name)
    local ok, art, w, h = pcall(require("data.spell_icons").Get, name, TK.SpellIconsAnimated())
    if ok and type(art) == "string" and art ~= "" then return art, w, h end
    return ""
end

--- Head note 44: what shows spell icons, a function each, called each frame while spell icons animate; each draws
--- only its visible rows or slots. s6-spell-icons: also while a spell's own choice animates whatever the option says.
TK.SpellIconAnimators = {}
-- s6-interface-5x (round 13's hotfix; the separation's step 11): a component's is keyed by its name, and goes when the
-- component is unloaded (TK.Components:Unload), as its main.lua sets it again when it loads
TK.OnWithdraw(function(name, panel)
    if name and panel == nil then TK.SpellIconAnimators[name] = nil end
end)

--- s6-modular-g (round 16, separation step 7): an interface's animator, by name (fn, or nil to remove it): an interface
--- registers here rather than writing into the global table (interface-separation.md, rule R3).
function TK.SetSpellIconAnimator(name, fn) TK.SpellIconAnimators[name] = fn end

local animator = CreateFrame("Frame", "TKSpellIconAnimator", UIParent)
animator:SetSize(1, 1)
animator:SetScript("OnUpdate", function()
    if not TK.SpellIconsAnimated() and not H:SpellIconsAnimateAny(TK.Characters.ref or "") then return end
    for _, f in pairs(TK.SpellIconAnimators) do f() end
end)

--- Resolve an icon's picture and glyph, including animated spell icons and missing-book state.
--- Shared widgets use this lookup so interfaces can draw the same action with their own skin.
--- Count is always 0 here; TK.ActionInfo supplies stack counts for labels that need them.
function TK.ActionIconInfo(action)
    local name, key, letter, art, w, h, missing, _
    if action and action.kind == "spell" then
        -- Head note 44: a spell's icon (animated with the option on), else the plain square with its letter.
        name, key, letter, _, art, w, h, missing = spellInfo(action, true)
    else
        name, key, letter, _, art, w, h = TK.ActionInfo(action)
    end
    return name, key, letter, 0, art, w, h, missing
end

local function show(action)
    -- An original-interface drag label replaces only this picture while its passive frame shows.
    -- The carried action and every slot's existing input/command path remain unchanged.
    if Cursor.preview and Cursor.preview:IsShown() then icon:Hide() return end
    -- Keep the fixed drawing box: GetWidth is pixel-rounded at some UI scales and would shrink the picture.
    if not W.ActionIcon(icon.tex, icon.glyph, icon, action, IconWidget.CURSOR_SIZE) then
        icon:Hide()
        return
    end
    icon:Show()
end

function Cursor:Get() return self.held end

--- A passive native drag label may replace the tools' held icon until it hides. Drawing only:
--- it never changes the held action, emits cursor events, or owns a press/release.
function Cursor:SetPreview(frame)
    self.preview = frame
    if self.held then show(self.held) else icon:Hide() end
end

-- A drawing style changed (s6-modular's event, once a frame): the held spell's or item's picture is asked again.
TK.On("TK_DRAWING_STYLE_CHANGED", function() if Cursor.held then show(Cursor.held) end end)
TK.On("TK_SPELL_ICONS_CHANGED", function() if Cursor.held then show(Cursor.held) end end) -- s6-spell-icons: the editor

function Cursor:Set(action)
    self.held = action
    if action then show(action) else icon:Hide() end
    TK.FireEvent("ACTIONBAR_SLOT_CHANGED")
    TK.FireEvent("CURSOR_CHANGED")
end

function GetCursorInfo()
    local a = Cursor.held
    if not a then return nil end
    return a.kind, a.slot
end

function ClearCursor()
    if Cursor.held then Cursor:Set(nil) end
end

local function key(slot) return tostring(slot) end

--- A slot's action: its kind, and its lettered slot or its macro's id (an item's: its first slot now, or nil).
function GetActionInfo(slot)
    local a = TK.Characters:Actions()[key(slot)]
    if not a then return nil end
    -- s6-ui-bars: an item's first slot now, a spell's slot now (review r5 finding 4: not a slot it has left)
    if a.kind == "spell" or (a.kind == "item" and a.item) then return a.kind, TK.ActionSlot(a) end
    return a.kind, a.slot or a.id
end

--- A slot's action table ({ kind, slot } or { kind = "macro", id }), or nil.
function TK.ActionAt(slot) return TK.Characters:Actions()[key(slot)] end

function HasAction(slot)
    local a = TK.Characters:Actions()[key(slot)]
    return a ~= nil and TK.ActionInfo(a) ~= nil
end

--- An action button keeps only what (and which slot, or which line), not where it was picked up. An item keeps the item
--- (s6-ui-bars): one picked up in the bag is named by its kind.
local function shortcut(a)
    if a and a.kind == "item" then
        if a.item then return { kind = "item", item = a.item, name = a.name, icon = a.icon } end
        return TK.ItemActionAt(a.slot) or { kind = "item", slot = a.slot }
    end
    if a and a.kind == "spell" then
        -- s6-ui-bars: a spell keeps its name and record (the book's took them at its pickup: review r5 finding 2)
        local name = a.name or select(2, record(a.slot))
        return { kind = "spell", slot = a.slot, name = name ~= "" and name or nil, rid = a.rid }
    end
    return a and { kind = a.kind, slot = a.slot, id = a.id } or nil
end

--- Picks the action in an action slot up onto the cursor. If the cursor already holds one, they swap.
function PickupAction(slot)
    local actions = TK.Characters:Actions()
    local here = actions[key(slot)]
    local held = Cursor.held
    actions[key(slot)] = shortcut(held)
    Cursor:Set(here and TK.Util.Copy(here) or nil)
    TK.Characters:MarkDirty()
end

--- Whether two actions are the same (kind, slot or item, macro).
local function same(a, b)
    return a ~= nil and b ~= nil and a.kind == b.kind and a.slot == b.slot and a.id == b.id and a.item == b.item
        and a.name == b.name and a.rid == b.rid
end

--- Puts the cursor's action into a slot; whatever was there goes onto the cursor (WoW's swap), unless it is the same
--- action (s6-ui-bars: a spell dropped onto a button already holding it leaves nothing on the cursor).
function PlaceAction(slot)
    local held = Cursor.held
    if not held then return end
    local actions = TK.Characters:Actions()
    local here = actions[key(slot)]
    local placed = shortcut(held)
    actions[key(slot)] = placed
    Cursor:Set(here and not same(here, placed) and TK.Util.Copy(here) or nil)
    TK.Characters:MarkDirty()
end

-- ----- s6-ui-bars: the spells on the bars and the action wheel follow the book (the owner, 2026-10-02) -----

--- Every spell action follows its spell. One with a record follows it (a swap moved it, however its slots' updates
--- arrived); a record the book has lost (not moving) is let go, and the spell is found by name from then on. One
--- without a record whose slot does not hold its name finds the name (a spell learnt again elsewhere; none: it stays),
--- then takes the record of the spell in its slot. A spell action without a name (a bar saved before this) takes the name
--- of the spell in its slot. Nothing is sent.
function TK.FollowSpells()
    local actions, changed = TK.Characters:Actions(), false
    for _, act in pairs(actions) do
        if act.kind == "spell" and act.slot then
            local id, name = record(act.slot)
            if not act.name and name ~= "" then
                act.name = name
                changed = true
            end
            if act.name and act.rid then
                local at = recordSlot(act.rid)
                if at and at ~= act.slot then
                    act.slot = at
                    changed = true
                elseif not at and not H:SpellRecordMoving(act.rid) then
                    act.rid = nil
                end
                id, name = record(act.slot)
            end
            if act.name and not act.rid then
                if name ~= act.name then
                    local s = TK.SpellSlot(act)
                    if s and s ~= act.slot then
                        act.slot = s
                        changed = true
                    end
                    id, name = record(act.slot)
                end
                if name == act.name and id ~= 0 then act.rid = id end
            end
        end
    end
    if changed then TK.Characters:MarkDirty() end
end

-- Before the bars and the wheel refresh on the same events (core's listeners run first). A record is this session's, so
-- a login starts from the names; a placed spell takes its record at once.
TK.On("PLAYER_ENTERING_WORLD", function()
    for _, act in pairs(TK.Characters:Actions()) do act.rid = nil end
    TK.FollowSpells()
end)
TK.On("SPELLS_CHANGED", function() if TK.Characters.name then TK.FollowSpells() end end)
TK.On("ACTIONBAR_SLOT_CHANGED", function() if TK.Characters.name then TK.FollowSpells() end end)

--- A right-click anywhere drops what the cursor holds; so does a click on nothing (outside any frame).
TK.On("GLOBAL_MOUSE_DOWN", function(_, button)
    Cursor.cancelledBy = nil
    if not Cursor.held then return end
    if button == "RightButton" or GetMouseFocus() == nil then
        ClearCursor()
        -- The same press's release must not also act on the button under the cursor (review F12).
        Cursor.cancelledBy = button
    end
end)

--- True once if the click with this mouse button is the end of a press that cancelled the cursor's action.
function Cursor:ConsumeCancel(button)
    if self.cancelledBy ~= nil and self.cancelledBy == button then
        self.cancelledBy = nil
        return true
    end
    return false
end

-- ----- the mouse cursor (s6-world-view, coverage U-02) -----
--
-- The original's cursors (Cursor\*.ani, ScreenPane::LoadCursorResources: 7 normal, 8 select, 9 view, 10 put, 11 attack),
-- drawn by the world view (MouseCursors). Over the map, the one 4a's MapPane::HandlePointerOrMouseEvent picks for what
-- is under the pointer (a character view, an NPC select, another figure attack, an item put, else normal), worked out
-- when the pointer moves, as 4a's pointer-move events do; over the UI, and over the far view's ring (beyond 4a's map
-- pane), the normal one. 4a's start shows the normal one. The profile's cursor set chooses the pictures (Cursor:ApplySet;
-- 5.x's is 5.33's own: MouseCursors).
-- s6-interface-5x-b (round 7, the owner's cursor question): an interface faithful to 7.5.2's screen (its table's
-- keepsCursorOffMap: 7.x) keeps 4a's rule off the map instead: nothing there sets a cursor (BackPane's EPF branch and the
-- other panes leave it, MapPane's move sets one only inside its rectangle), so the last one stays until a new dialog's
-- window (DialogPane's constructor, DialogPane.cpp:53, as the minimap dialog's) or the pointer entering the game window
-- (Application's WM_MOUSEMOVE, Application.cpp:1185) sets the normal one again. Drawing only.

local NORMAL = 7

--- Whether the interface in use keeps 4a's cursor off the map (7.x; Modern and 5.x show the normal one over the UI).
local function keepsOffMap()
    local active = TK.Interfaces and TK.Interfaces:Active()
    return active ~= nil and active.keepsCursorOffMap == true
end

--- The slot for the pointer over a frame: the map's pick over the world view's active area, else normal (nil: keep the
--- one shown, off 4a's map in an interface that keeps it).
function Cursor:PointerSlot(focus)
    local off = NORMAL
    if keepsOffMap() then off = nil end
    local view = TK.GetComponent("worldview")
    if not H:IsOnline() or not view or not view.frame or not focus or focus.__h ~= view.frame.__h then return off end
    if not view:TileAtCursor() then return off end
    -- s6-characters' answer is 0 off the visible cells (no drawing there): normal, as over the UI.
    local slot = H:GetMapCursor(view:CentrePoint()) -- s6-world-view (round 31): the logic's map point
    if slot == 0 then return off end
    return slot
end

function Cursor:SetPointer(slot)
    if slot == nil or slot == self.pointer then return end
    self.pointer = slot
    H:SetPointerCursor(slot)
end

--- A new dialog's window (the dialogs component): 4a's DialogPane constructor shows the normal cursor, in an interface
--- that keeps 4a's cursor off the map.
function Cursor:DialogOpened()
    if keepsOffMap() then self:SetPointer(NORMAL) end
end

--- s6-interface-5x-b: the profile's cursor set (its looks' cursors: "original", the .ANI set, or "533", 5.x's 5.33
--- cursor, which falls back to the original's without the 5.33 set). Drawing only.
function Cursor:ApplySet()
    local looks = TK.DB.profile and TK.DB.profile.looks
    H:SetPointerCursorSet(looks and looks.cursors or "original")
end
TK.On("PLAYER_LOGIN", function() Cursor:ApplySet() end)
TK.On("TK_PROFILE_CHANGED", function() Cursor:ApplySet() end)
TK.On("TK_GAME_STATE", function() Cursor:ApplySet() end)

local pointer = CreateFrame("Frame", "TKPointerCursor", UIParent)
pointer:SetSize(1, 1)
local lastX, lastY, lastFocus, inside
pointer:SetScript("OnUpdate", function()
    local x, y = GetCursorPosition()
    local focus = GetMouseFocus()
    if x == lastX and y == lastY and focus == lastFocus then return end
    lastX, lastY, lastFocus = x, y, focus
    -- the pointer entering the game window shows the normal cursor (4a's first WM_MOUSEMOVE after a WM_MOUSELEAVE)
    local w, h = GetScreenWidth() * TK.UIScale(), GetScreenHeight() * TK.UIScale()
    local now = x >= 0 and y >= 0 and x < w and y < h
    if now and not inside then Cursor:SetPointer(NORMAL) end
    inside = now
    Cursor:SetPointer(Cursor:PointerSlot(focus))
end)
Cursor:SetPointer(NORMAL)
