-- s6-interface-5x (round 12; docs/development/interface-separation.md, step 2 and section 5.3): the game layer's
-- inventory, the 52 lettered item slots (a-z, then A-Z) as the server sends them (0x0F, 0x10) and what a press on one does,
-- whatever an interface draws: Modern's bag window, 7.x's and 5.x's side panel item pages. It was the bag window's
-- (core/bag.lua), reached by the other interfaces through Bag.ItemControl and Bag.others, and its carry watch lived only
-- because that window was built in every interface.
--
-- A slot control (I.SlotControl) is 4a's NewInventoryPane::HandlePointerOrMouseEvent (0x004ECB50) whole:
--   left-click or drag   picks the item up; on another slot it moves there, on an action button it becomes a shortcut,
--                        on the world's active cells it is dropped. Putting it down by a click is the original's drag
--                        released there (case 3): 30 00 target source on a slot, 08 slot 00 on the map for any slot,
--                        never asking. A drag nothing takes, the page's hiding (I.EndCarryOnHide), a dialog and Escape end
--                        it; none starts while a dialog is alive (case 1 tests g_activeDialogCount).
--   double-click         uses the item (1C) on the double click's press (case 2), in the original's default mode.
--                        With Simple Click on (Config's double click off, settings.toml options.double_click) a click
--                        uses it instead, on its release on the pressed slot (case 3), and only a drag moves it.
--   right-click          the item menu (D19: every command the original has for an item, through its key prompts;
--                        the original's own right press shows its item help, gap G2), and the hover tooltip: an
--                        interface may draw its own (opts.menu, opts.tooltip); by default the tools' menu and tooltip.
-- Each command is an action attached to its control (TK.Actions); the rules decide what is sent. Wire: changing a
-- control's press path, the carry or the actions changes what the server sees, from every interface.

local H = __tk
local W = TK.UI

TK.Game = TK.Game or {}
local I = {}
TK.Game.Inventory = I

local SLOTS = 52
local helpOwners = {}

--- Original-interface inventory panes register their owner for server help; a mixed-in visible pane takes priority.
function I.HelpOwner(owner, help)
    if owner then helpOwners[#helpOwners + 1] = TK.Mark({ frame = owner, help = help }) return end
    for i = #helpOwners, 1, -1 do if helpOwners[i].frame:IsVisible() then return helpOwners[i] end end
    -- WIRE: GeneralPurposePanel::SwitchActiveTab 0x004B8650 unregisters the inactive page's subtree.
    -- A 59 while inventory is hidden stays silent; showing a catcher then changes the next command the server sees.
end

-- WIRE: NewInventoryPane::ShowHelpFromPacket 0x004EDE80 shows SimpleHelpPane at the server packet,
-- before later input, even with no dialog open. CatchUp delivers the ordered rule notice before each input;
-- delaying it to OnUpdate or replaying it after a reload changes which game press the server sees.
TK.On("TK_RULES_ITEM_HELP", function(_, text, y)
    local host = I.HelpOwner()
    if host then host.help.Show(host.frame, text, 10000, { host.frame:GetWidth() / 2, y }) end
end)
TK.OnWithdraw(function(name, panel) TK.DropOwned(helpOwners, name, panel) end)

--- Show a slot's local sheet from its retained packet facts, with the painter the interface supplies.
function I.ShowHelp(sheet, owner, slot)
    local ok, name = H:GetItemSlot(slot)
    if not ok then return end
    local _, key, durability, protection, itemOwner = H:GetItemHelp(slot)
    sheet.Show(owner, key or "", name or "", durability or 0, protection or 0, itemOwner or "")
end

--- A slot's item: its name and count, or nil for an empty slot.
function I.ItemAt(slot)
    local ok, name, count = H:GetItemSlot(slot)
    if ok then return name, count end
end
local itemAt = I.ItemAt

--- The slots that hold an item (1-52, in order).
function I.HeldSlots()
    local list = {}
    for slot = 1, SLOTS do
        if H:GetItemSlot(slot) then list[#list + 1] = slot end
    end
    return list
end

--- The carry: the cursor's item when it came from a slot, else nil.
function I.Carry()
    local held = TK.Cursor:Get()
    if held and held.kind == "item" and held.from == "bag" then return held end
end
local carry = I.Carry

--- Simple Click (the original's Config double click off): a click uses the item; else a double click does.
function I.SimpleClick() return not H:ClientSettingBool("options", "double_click") end
local simpleClick = I.SimpleClick

-- The carry's watch (review r1): a dialog coming up ends a carry (4a's drag needs the button held; a dialog alive keeps
-- a new one from starting, InventoryPane.cpp:1136).
local watch = CreateFrame("Frame", "TKBagCarryWatch", UIParent)
watch:Hide()
watch:SetScript("OnUpdate", function(self)
    if carry() and H:ActiveDialogs() > 0 then ClearCursor() end
    if not carry() then self:Hide() end
end)

-- A left press on a slot (4a's selection): its slot, whether the button is still held, whether the pointer has
-- reached another slot since the press (m_draggedSincePress, set only by a move onto a different resolved slot,
-- :1026-1044), the move that starts the UI's drag included, and whether a key has ended it (cleared, below). A drag of a
-- slot's: the carry it started, and the carry its release ends if nothing takes it (a click's carry included). One for
-- every interface's slots, as 4a has one selection.
local press, drag = {}, {}

-- s6-interface-5x (Native28). WIRE: NewInventoryPane::HandleKeyOrTextEvent 0x004EC920 (InventoryPane.cpp:880-934) sets the
-- selection to -1 on every key-down (type 8: repeats, and Shift, Ctrl or Alt alone with code 0, EventMan::PostKeyDownEvent
-- 0x004A96A0) but unmodified Page Up/Page Down (0x93, 0x94) and 'i' (0x69) without Ctrl alone (modifiers 2), so its release
-- (case 3, :1163-1225) then moves, drops and uses nothing. While a slot's press is held, such a key ends the press here, in
-- the key's own place among the inputs: its carry ends, and the release picks nothing up and uses nothing (OnClick,
-- OnDragStart). Only a key that reaches the game's panes counts (GAME_KEY_DOWN, with 4a's code and modifier bits): an open
-- line's keys, a capture's or a modal pane's never reach 4a's tab (EventDispatcher::DispatchEvent 0x004A7130). Changing
-- these keys or this order changes what the server sees.
--
-- s6-input (2026-10-08, s6-optimize R52.1; the 5.x lane's code, touched only to share it): the watcher was built
-- twice, here and for the spells' rows (core/game/spells.lua). I.PressKeys is that one watcher; each tab keeps its own
-- kept key and its own end, in its own order.

--- The key watcher of a held press, 4a's two tabs' alike: a hidden frame, shown by the caller from the press, that
--- watches keys; a key-down that reaches the game's panes ends the press, and so does the left button's release.
--- WIRE (Native28, above): the keys tested and their order are 4a's HandleKeyOrTextEvent of each tab (0x004EC920,
--- 0x0057D8D0): unmodified Page Up and Page Down (0x93, 0x94) first, kept by both, then the tab's own; changing a
--- key, the order or where the handlers are registered changes which releases send.
--- @param name  the frame's name
--- @param keeps function(code, mods): true for the tab's own key that keeps the selection
--- @param ends  function(keys): what a key that ends the press does, in the tab's order; it hides keys itself
--- @return the frame
function I.PressKeys(name, keeps, ends)
    local keys = CreateFrame("Frame", name, UIParent)
    keys:SetWatchesKeys(true) -- the logic tells GAME_KEY_DOWN only while a frame watches keys
    keys:Hide()
    TK.On("GAME_KEY_DOWN", function(_, _, _, code, mods)
        if not keys:IsShown() or (code == 0x93 or code == 0x94) and mods == 0 or keeps(code, mods) then return end
        ends(keys)
    end)
    TK.On("GLOBAL_MOUSE_UP", function(_, button) if button == "LeftButton" then keys:Hide() end end)
    return keys
end

local pressKeys = I.PressKeys("TKSlotPressKeys",
    function(code, mods) return code == 0x69 and mods ~= 2 end, -- 'i' without Ctrl alone
    function(keys)
        press.cleared = true
        keys:Hide()
        if carry() then ClearCursor() end
    end)

--- Whether a slot's left press still holds 4a's selection (m_selectedInventorySlot): from the press until its release or
--- a key that ends it (above). Native29: for the pages' selection paint (interfaces/original/draglabel.lua); a read only.
function I.PressSelected() return pressKeys:IsShown() end

--- The item commands for a slot, as data (the item menu's entries; also the tests' and the classic commands' help).
function I.Commands(slot)
    local name, count = itemAt(slot)
    if not name then return {} end
    local function act(kind) return { kind = kind, slot = slot } end
    local list = {
        -- The name as the server sent it (4a keeps 0F's name verbatim, UserPane::ParseInventorySlotUpdatePacket 0x005aa710,
        -- and draws it as is, InventoryPane.cpp:719-726: a name too wide is cut to end in "...(N)" when its
        -- quantityPromptFlag is set, else "..."). Live's names carry a stack's count already ("Yellow scroll (66)",
        -- live-2026-10-01-C-M.md F4): no count added here.
        { text = name, title = true },
        { text = "Use", action = act("use") },
        { text = "Eat", action = act("eat") },
        { text = "Wield", action = act("wield") },
        { text = "Wear", action = act("wear") },
        { text = "Throw", action = act("throw") },
        { text = "Drop", action = act("drop") },
        { text = "Drop All", action = act("dropall"), disabled = count <= 1 },
        { text = "Give", action = act("give") },
        { text = "Give All", action = act("giveall"), disabled = count <= 1 },
        { text = "Post", action = act("post") },
    }
    return list
end

--- The default hover tooltip of a slot control (b.slot): the item, its letter and count.
local function showTooltip(b)
    if not b.slot then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    local name, count = itemAt(b.slot)
    local letter = H:SlotLetter(b.slot)
    if name then
        GameTooltip:AddLine(name, 1, 1, 1)
        GameTooltip:AddDoubleLine("Slot " .. letter, count > 1 and ("Count " .. count) or "", 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click for the item's commands; drag it to an action bar.", 0.5, 0.5, 0.5)
    else
        GameTooltip:AddLine("Slot " .. letter .. ": empty", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

--- The default item menu of a slot: its commands in the tools' menu.
local function openMenu(slot) W.OpenMenu(I.Commands(slot)) end

--- A click on a slot with an item on the cursor: from a slot it moves here (swap, the original's 30 00 with the target
--- first); an action button's shortcut is only dropped from the cursor.
local function placeHeld(b)
    local held = TK.Cursor:Get()
    ClearCursor()
    if held.kind == "item" and held.from == "bag" and held.slot ~= b.slot then TK.Actions:RunFrozen() end
end

-- The lists of slot controls whose actions follow the carry (I.Track): Modern's bag window's cells and rows, 7.x's and
-- 5.x's item pages.
local tracked = {}

--- Keeps a list of slot controls (made by I.SlotControl) in the slots' actions (I.UpdateActions); call I.UpdateActions
--- again after the list's slots change.
function I.Track(list) tracked[#tracked + 1] = TK.Mark(list) end

-- s6-interface-5x (round 13, the separation's step 11): a panel turned off takes its slot lists with it
TK.OnWithdraw(function(name, panel) TK.DropOwned(tracked, name, panel) end)

--- While an item from a slot is on the cursor, every other slot's action is moving it there (30 00, the target first),
--- on the path of the original's drag released on a slot, so a click that puts it down sends what that release sends.
--- Otherwise a slot's action is using its item (1C), which runs only on a double press, or with Simple Click on a
--- click's release. Wire: changing the actions or their paths changes what the server sees.
function I.UpdateActions()
    local held = carry()
    local from = held and held.slot
    for _, controls in ipairs(tracked) do
        for _, b in ipairs(controls) do
            if from and b.slot and b.slot ~= from then
                TK.Actions:Set(b, "swapitems", b.slot, from)
                TK.Actions:SetPath(b, "InventoryDrag")
            else
                if b.slot then TK.Actions:Set(b, "use", b.slot) else TK.Actions:Clear(b) end
                TK.Actions:SetPath(b, "inventory")
            end
        end
    end
end

-- The carry and the slots' actions follow the cursor, in every interface, whatever page shows (before round 12 this
-- listened inside Modern's bag window, built ahead in every interface).
local cursorEvents = CreateFrame("Frame", "TKInventoryEvents", UIParent)
cursorEvents:RegisterEvent("CURSOR_CHANGED")
cursorEvents:SetScript("OnEvent", function()
    if carry() then watch:Show() end
    I.UpdateActions()
end)

--- A slot control's input path whole (4a's NewInventoryPane::HandlePointerOrMouseEvent 0x004ECB50, the file's comment),
--- for any interface's slot: b.slot is the real slot it shows now (nil while it shows none). opts (optional) draws the
--- interface's own help: opts.help(slot, b) on the original's single right-down (no menu on its release),
--- opts.menu(slot, b) on a right click on an item, opts.tooltip(b) on the hover (and
--- opts.leave(b)); by default the tools' item menu and tooltip. Wire: the press, the drag, the double press, Simple
--- Click's release and the dialogs' block decide what the server sees; changing them changes it in every interface.
function I.SlotControl(b, opts)
    opts = opts or {}
    local menu, tooltip = opts.menu or openMenu, opts.tooltip or showTooltip
    local help = opts.help
    local leave = opts.leave or function() GameTooltip:Hide() end
    TK.Actions:SetPath(b, "inventory")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnMouseDown", function(self, button, double)
        self.acted, self.double, self.blocked = nil, double == true, H:ActiveDialogs() > 0
        -- WIRE: NewInventoryPane::HandlePointerOrMouseEvent 0x004ECB50 case 4 opens local ItemHelpPane on the
        -- single right press, not its release, and sends no 66 request. Changing this changes what the server sees.
        if button == "RightButton" and help and not double and self.slot and itemAt(self.slot) then help(self.slot, self) end
        if button == "LeftButton" then
            press.slot, press.held, press.reached, press.cleared = self.slot, true, false, false
            pressKeys:Show() -- Native28: the keys that end this press (above)
        end
        -- Case 2: in the default mode the double press uses the item, a dialog alive or not (the rules test the bow).
        if button ~= "LeftButton" or not double or simpleClick() or not self.slot or not itemAt(self.slot) then return end
        local held = carry()
        if held and held.slot ~= self.slot then return end
        if held then ClearCursor() end
        self.acted = true
        TK.Actions:RunFrozen()
    end)
    b:SetScript("OnClick", function(self, button)
        if TK.Cursor:ConsumeCancel(button) or not self.slot then return end
        if self.acted then
            self.acted = nil -- its press used the item
            return
        end
        if button == "RightButton" then
            if not help and itemAt(self.slot) then menu(self.slot, self) end
            return
        end
        if TK.Cursor:Get() then
            placeHeld(self)
        elseif itemAt(self.slot) and not self.blocked and not press.cleared then -- Native28: a key ended the press
            if not simpleClick() then
                TK.Cursor:Set({ kind = "item", slot = self.slot, from = "bag" })
            elseif not self.double and not press.reached then
                -- Simple Click (case 3): the release on the pressed slot uses it, unless the pointer reached another slot
                -- while held, a move under the drag threshold included (:1026, :1218); a double click's second does nothing.
                TK.Actions:RunFrozen()
            end
        end
    end)
    b:SetScript("OnDragStart", function(self)
        -- A double press starts no selection in either mode (case 2, :1227-1243): its drag carries nothing. Nor does a
        -- press a key ended (Native28, above): 4a's selection is gone.
        if self.double or self.acted or press.cleared then return end
        -- s6-ui-bars: an action carried from elsewhere (a bar's, the book's) is let go and this item taken up, never
        -- placed where it is dropped; the slots' own carry keeps 4a's drag (its release moves it).
        if self.slot and itemAt(self.slot) and not carry() and H:ActiveDialogs() <= 0 then
            TK.Cursor:Set({ kind = "item", slot = self.slot, from = "bag" })
            drag.started = carry()
        end
    end)
    b:SetScript("OnDragStop", function()
        -- Before any receiver: the carry this release ends if nothing takes it, the drag's own or a click's.
        drag.ending = carry()
    end)
    b:SetScript("OnReceiveDrag", function(self)
        local held = carry()
        if held and held == drag.started and self.slot == held.slot and self.slot == press.slot and not press.reached
            and simpleClick() then
            -- Simple Click: the pointer never reached another slot, so this is case 3's release on the pressed slot,
            -- which uses the item (:1218-1220); the release carries this slot's path (UIHost.Live).
            ClearCursor()
            TK.Actions:RunFrozen()
            return
        end
        if TK.Cursor:Get() then placeHeld(self) end
    end)
    b:SetScript("OnDragEnd", function()
        -- After whatever took the drag (a slot, the world, an action button), in the same release: a carry nothing
        -- took ends here (4a ends the selection with every release, :1187, :1224).
        if drag.ending and carry() == drag.ending then
            -- s6-modular-g round 22: NewInventoryPane 0x004ECB50 drops on the whole map pane,
            -- even under the chat/frame. The host froze that drop before this release; changing this changes 08.
            if __tk:InventoryDropOnMap() then TK.Actions:RunFrozen() end
            ClearCursor()
        end
        drag.started, drag.ending = nil, nil
    end)
    b:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then press.held = false end
    end)
    b:SetScript("OnEnter", function(self)
        if press.held and press.slot and self.slot and self.slot ~= press.slot then press.reached = true end
        tooltip(self)
    end)
    b:SetScript("OnLeave", function(self) leave(self) end)
end

--- No carry outlives the frame (review r1, InventoryPane.cpp:1136): a page or window of slots ends the carry when it
--- hides, as the original's selection ends with its pane.
function I.EndCarryOnHide(frame)
    frame:HookScript("OnHide", function() if carry() then ClearCursor() end end)
end

--- The gold commands' action: dropgold or givegold with the amount (a whole number above 0), or nil.
function I.GoldAction(kind, amount)
    local n = tonumber(amount)
    if n and n > 0 then return { kind = kind, amount = math.floor(n) } end
end

--- Asks for the amount, then runs the gold command (dropgold, givegold) on the prompt's OK.
function I.GoldPrompt(kind, title)
    W.Prompt({ title = title, text = "How much gold?", numeric = true, maxLetters = 10,
        action = function(value) return I.GoldAction(kind, value) end })
end

--- The Mix button (4a's inventory button and Shift+I, UserPane::OpenMixItemDialog): the dialog model's opener on the
--- inventory path, ending a carry first (the dialog would end it: review r1). The button runs it from its own press or
--- click, as its interface's pane does: call I.Mix() there. Wire: the action and its path are what the server sees.
function I.MixControl(button)
    TK.Actions:Set(button, "dialog:open", 0, 0, "MixItemDialog")
    TK.Actions:SetPath(button, "inventory")
end

--- Runs the Mix button's action (I.MixControl), ending a carry first.
function I.Mix()
    if carry() then ClearCursor() end
    TK.Actions:RunFrozen()
end

return I
