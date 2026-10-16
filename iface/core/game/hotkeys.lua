-- s6-modular-g (round 19, the separation's step 8; docs/development/interface-separation.md 5.9): the action slots' presses
-- and the original's 30 hotkeys, as the game layer gives them to every interface: TK.Game.Hotkeys.
--
-- The original's hotkeys are keys 1-0, Ctrl+1-0 and Alt+1-0 (4a's 0-9 hotkeys and their Ctrl and Alt pages). They are the
-- action slots 1-10, 13-22 and 25-34: bar b's button i shows slot (b - 1) x 12 + i (Modern's bars). Each has a hidden,
-- non-drawing button here, its carrier TKHotkey<slot>, and the keys are bound to it ("CLICK TKHotkey<slot>", the defaults
-- of Modern's bars, Original Commands' keypad and Classic's preset). Being global, a carrier is never inert: the hotkeys
-- act in every interface whether Modern's bars are on or not. An interface's buttons draw over the same slots (Modern's
-- bars), carry their own action for a click (K.Attach) and bind through the carrier's command (hover-to-bind, their
-- tooltip's key, the Key Bindings rows).
--
-- Wire: a carrier is a CLICK binding's frame, not a named command, so its key keeps a click's input path: the frame's
-- path ("hotkey"), its action frozen at the key-down by the input host, and a press while it is hidden (K.MakeHotkey;
-- core/bindings.lua runCommand). A named command would go as keyboard input instead (EntryPath.Keyboard). 4a's hotkeys
-- read the slot at the key-down (UserPane::HandleKeyOrTextEvent 0x005A5BD0) and run its record
-- (UserPane::ExecuteHotkeyAction 0x005A3AE0: a text said, a spell cast by UserPane::UseCommandSlot 0x005A4530, an item
-- used by UserPane::UseInventorySlot 0x005A3E30): K.Attach is what that run sends. Changing the carriers' kind, path,
-- what they carry or when it is attached changes what the server sees.

local H = __tk

TK.Game = TK.Game or {}
local K = {}
TK.Game.Hotkeys = K

--- The original's hotkey slots, in key order: 1-0, Ctrl+1-0, Alt+1-0.
K.SLOTS = {}
for b = 1, 3 do
    for i = 1, 10 do K.SLOTS[#K.SLOTS + 1] = (b - 1) * 12 + i end
end

--- A slot's carrier command, the binding its keys hold.
function K.Command(slot) return "CLICK TKHotkey" .. slot end

--- Makes a frame carry what a press of the slot runs, as the press freezes it (plan 5.9): nothing (an empty slot, an item
--- none of which is left, a spell the book has lost), a text macro (0E), a user macro, a cast from the spell's slot now
--- (with its record and name, so the rules cast it from the slot holding it at the dispatch), or the use of an item's
--- first slot (1C). Returns the slot's action and whether it runs nothing although it holds one (drawn darkened).
--- Wire: UserPane::ExecuteHotkeyAction 0x005A3AE0's run of the slot; the one copy for every button and segment that carries a
--- slot (Modern's bars and action wheel, the carriers). Changing it changes what the server sees.
--- s6-modular-g (round 21, the owner's research on presses reaching the wrong place): while the cursor holds an action it
--- carries nothing, so a key on the slot places that action (K.Press, nothing sent) instead of running the slot's: the input
--- host ran a key's carried action before its binding, so 1 cast slot 1's spell (0F) and kept the held one. Every change of
--- the cursor fires ACTIONBAR_SLOT_CHANGED (core/cursor.lua Cursor:Set), which attaches again. WIRE: with nothing held a key
--- runs its slot as 4a's hotkey does (4a has no held action); changing this changes what the server sees.
function K.Attach(frame, slot)
    local action = TK.ActionAt(slot)
    local name = TK.ActionInfo(action)
    local none = name ~= nil and TK.ActionMissing(action)
    if not name or none or GetCursorInfo() then TK.Actions:Clear(frame)
    elseif action.kind == "macro" then TK.Actions:SetMacro(frame, action.id) -- the host's descriptor of the character's macro
    elseif action.kind == "usermacro" then TK.Actions:SetUserMacro(frame, action.id) -- s6-macros
    elseif action.kind == "spell" then TK.Actions:Set(frame, "cast", TK.ActionSlot(action), action.rid or 0, action.name)
    else TK.Actions:Set(frame, "use", TK.ActionSlot(action)) end
    return action, none
end

--- Makes a frame a hotkey: its presses go on the hotkey path (s6-rules-core's EntryPath.Hotkey, 4a's
--- UserPane::ExecuteHotkeyAction 0x005A3AE0), and a key bound to it runs while it is hidden (a bar that is off keeps its
--- keys: the owner, 2026-10-03). Wire: the path the rules tell a hotkey's use by; changing it changes what the server sees.
function K.MakeHotkey(frame)
    TK.Actions:SetPath(frame, "hotkey")
    TK.Actions:SetKeyWhileHidden(frame, true)
end

--- A press of a frame showing slot frame.action, by a click or by its key (runCommand clicks it): nothing in key-binding
--- mode or after a right-click that dropped the cursor's action (review F12); with an action on the cursor, that action
--- placed on the slot (nothing sent), "placed" returned; else the slot's action as the press froze it (K.Attach), when the
--- slot has one. Wire: the run of 4a's UserPane::ExecuteHotkeyAction 0x005A3AE0; a press that places sends nothing, as
--- before. Changing this changes what the server sees.
function K.Press(frame, button)
    if TK.KeyBindMode.active then return end
    if TK.Cursor:ConsumeCancel(button) then return end
    if GetCursorInfo() then
        PlaceAction(frame.action)
        return "placed"
    end
    if GetActionInfo(frame.action) then TK.Actions:RunFrozen() end
end

-- ----- the carriers -----

K.carriers = {}

--- The button an interface draws a hotkey's slot with (Modern's bar button), which shows the key's pushed look while the
--- key is down, as when the key pressed that button. Drawing only.
local faces = {}
function K.SetFace(slot, button) faces[slot] = button end

for n, slot in ipairs(K.SLOTS) do
    local c = CreateFrame("Button", "TKHotkey" .. slot, UIParent)
    c:Hide()
    c.action = slot
    K.MakeHotkey(c)
    c:SetScript("OnClick", function(self, button) K.Press(self, button) end)
    local push = c.SetButtonState
    function c:SetButtonState(state)
        push(self, state)
        local face = faces[slot]
        if face and not TK.IsDead(face) then face:SetButtonState(state) end
    end
    -- The name Modern's button had, in the Key Bindings lines and the "Function is Now Unbound" message (CommandText).
    TK.Bindings:RegisterBindable(c, K.Command(slot), "Bar " .. math.ceil(n / 10) .. " Button " .. ((n - 1) % 10 + 1))
    K.carriers[slot] = c
end

-- ----- what goes onto the slots by itself -----

--- An item a slot holds by its bag slot (an older bar, or the original's macro keys) is named by the item in that slot
--- once it has one, and from then on follows the item. Wire: what a hotkey's use then names (the item's first slot).
function K.NameItems()
    local actions, changed = TK.Characters:Actions(), false
    for k, a in pairs(actions) do
        if a.kind == "item" and not a.item then
            local named = TK.ItemActionAt(a.slot)
            if named then
                actions[k] = named
                changed = true
            end
        end
    end
    if changed then TK.Characters:MarkDirty() end
end

--- Where a spell the character has not had before goes: placer() gives the first empty slot of an interface's buttons
--- (Modern's bars that are on), or nil. Without one, a new spell goes nowhere and is only noted as known.
local placer, placerOwner
function K.SetPlacer(fn) placer, placerOwner = fn, TK.Mark({}) end

-- the step 11 withdrawal: the placer goes with its component when that is unloaded (every one of Modern's bars off)
TK.OnWithdraw(function(name, panel)
    if placerOwner and TK.OwnedBy(placerOwner, name, panel) then placer, placerOwner = nil, nil end
end)

--- A spell the character has not had before goes onto the first empty slot the placer gives, unless a slot already holds
--- it; items never do. With no empty slot it goes nowhere, and stays known. Nothing is sent. Wire: a spell placed on a
--- hotkey slot is what that key casts from then on.
function K.PlaceNewSpells()
    local known = TK.Characters:KnownSpells()
    if not known then return false end
    local had, onSlots = {}, {}
    for _, n in ipairs(known) do had[n] = true end
    local actions = TK.Characters:Actions()
    for _, a in pairs(actions) do
        if a.kind == "spell" then
            local ok, n = H:GetSpellSlot(a.slot)
            n = a.name or (ok and n)
            if n then onSlots[n] = true end
        end
    end
    local changed = false
    for s = 1, 52 do
        local ok, name = H:GetSpellSlot(s)
        if ok and not had[name] then
            had[name] = true
            known[#known + 1] = name
            changed = true
            local free = not onSlots[name] and placer and placer()
            if free then
                local rid = H:GetSpellRecord(s)
                actions[tostring(free)] = { kind = "spell", slot = s, name = name, rid = rid ~= 0 and rid or nil }
                onSlots[name] = true
            end
        end
    end
    if changed then TK.Characters:MarkDirty() end
    return changed
end

-- What the carriers carry follows the slots, in every interface, after core/cursor.lua's TK.FollowSpells and before an
-- interface's buttons are drawn (TK.On listeners run before the event frames): the events that changed what Modern's bar
-- buttons carry before step 8. Wire: a carried action left stale would use another slot or cast another spell than the
-- key's (4a's hotkeys read the slot at the key-down, UserPane::HandleKeyOrTextEvent 0x005A5BD0); changing this changes
-- what the server sees.
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE", "SPELLS_CHANGED", "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS" }) do
    TK.On(e, function()
        if e == "PLAYER_ENTERING_WORLD" or e == "BAG_UPDATE" then K.NameItems() end
        if e == "PLAYER_ENTERING_WORLD" or e == "SPELLS_CHANGED" then K.PlaceNewSpells() end
        for slot, c in pairs(K.carriers) do K.Attach(c, slot) end
    end)
end

return K
