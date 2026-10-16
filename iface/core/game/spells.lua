-- s6-interface-5x (round 12; docs/development/interface-separation.md, step 2 and section 5.4): the game layer's spells,
-- a spell list's cell and what a press on it does, whatever an interface draws: Modern's Spell Book table, 7.x's and
-- 5.x's side panel spell pages. It was the character window's (core/character.lua, head note 38), reached by the other
-- interfaces through CW.SpellControl and CW.SetSpellAction. The slots stay the original's: a spell casts that slot, and a
-- book spell dropped on another spell swaps them (30 01, the target first).
--
-- s6-ui-character (head note 52): the cast follows the Simple Click setting as 4a's book (SpellInventoryPane.cpp:820,
-- NewSpellInventoryPane::HandlePointerOrMouseEvent): in its double-click mode (the default, options.double_click) a
-- double click casts, on its double press (type 2), and no release casts; with Simple Click a click casts on its release
-- (type 3), but a double press's release does not, so a double click casts once.
--
-- Wire (s6-spell-icons): each cell is its slot's for good (b.slot, set by the page that shows it), and the cast and the
-- swap carry that slot (Sp.SetCellAction), never the cell's place in the list: 4a's list scrolls too, and turns the place
-- shown into the slot it shows (NewSpellInventoryPane::ResolveVisibleSpellSlot 0x0057E8D0, m_scrollPosition + 1 + row),
-- so a click sends the slot under it whatever the scroll (s6-spellbook: or the table's sort). Changing what a cell's
-- action carries changes the 0F and 30 01 the server gets.

local H = __tk

TK.Game = TK.Game or {}
local Sp = {}
TK.Game.Spells = Sp

--- The spell slots that hold a spell (1-52, in order).
function Sp.HeldSlots()
    local list = {}
    for slot = 1, 52 do
        if H:GetSpellSlot(slot) then list[#list + 1] = slot end
    end
    return list
end

--- A spell from the book dropped on another slot moves there (the original's 30 01, the target first): the cell
--- carries that action while a book spell is on the cursor (Sp.SetCellAction, as its page sets it: Modern's spell book
--- table's updateRowActions, which offers the move only in the slots' order).
local function dropOnRow(row)
    local held = TK.Cursor:Get()
    if not held then return false end
    ClearCursor()
    if held.kind == "spell" and held.from == "book" and held.slot ~= row.slot then TK.Actions:RunFrozen() end
    return true
end

-- s6-interface-5x (Native28). WIRE: NewSpellInventoryPane::HandleKeyOrTextEvent 0x0057D8D0 (SpellInventoryPane.cpp:630-660)
-- sets the selection to -1 on every key-down (repeats and modifiers alone included, as the inventory's) but unmodified Page
-- Up/Page Down (0x93, 0x94) and '+' (0x2B, any modifiers), so its release (case 3, :797-829) then swaps (30 01) and casts
-- (Simple Click's 0F) nothing. While a row's press is held, such a key ends the press here, in the key's own place among
-- the inputs, if it reaches the game's panes (GAME_KEY_DOWN with 4a's code and modifier bits, as core/game/inventory.lua's
-- slots): the book spell it carries is let go, and the release casts nothing (OnClick, OnDragStart). Changing these keys or
-- this order changes what the server sees.
local cleared = false -- the held press holds no selection: a key ended it, or it came while spell input was up (Native29)
-- s6-input (2026-10-08, s6-optimize R52.1; the 5.x lane's code, touched only to share it): the watcher is the one the
-- inventory's slots use (TK.Game.Inventory.PressKeys), with this tab's own kept key and its own end.
local pressKeys = TK.Game.Inventory.PressKeys("TKSpellPressKeys",
    function(code) return code == 0x2B end, -- '+', any modifiers
    function(keys)
        cleared = true
        keys:Hide()
        local held = TK.Cursor:Get()
        if held and held.kind == "spell" and held.from == "book" then ClearCursor() end
    end)

--- Whether a row's left press still holds 4a's selection (m_selectedSpellSlot): from the press until its release or a key
--- that ends it (above). Native29: for the pages' selection paint (interfaces/original/draglabel.lua); a read only.
function Sp.PressSelected() return pressKeys:IsShown() and not cleared end

--- 4a's double-click mode (Config::m_doubleClickEnabled, settings.toml options.double_click); off is Simple Click.
function Sp.DoubleClickMode() return H:ClientSettingBool("options", "double_click") end
local doubleClickMode = Sp.DoubleClickMode

--- A cell's action for the cursor's carry (held): moving the book spell on the cursor there (a drop's release), else
--- casting its own spell. Wire: the cell's own slot, whatever the scroll (the file's comment; 4a's
--- ResolveVisibleSpellSlot 0x0057E8D0).
function Sp.SetCellAction(b, held)
    local i = b.slot
    if held and held.kind == "spell" and held.from == "book" then
        if held.slot ~= i then TK.Actions:Set(b, "swapspells", i, held.slot) else TK.Actions:Clear(b) end
    elseif H:GetSpellSlot(i) then
        TK.Actions:Set(b, "cast", i)
    else
        TK.Actions:Clear(b)
    end
end

--- A book cell's input path (b.slot its slot), for any interface's spell list: the casts, the drag and the drop as the
--- file's comment says, and the right click's icon editor (s6-spell-icons, a tool). Changing it changes what the server
--- sees.
function Sp.CellControl(b)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function(self, button)
        if TK.Cursor:ConsumeCancel(button) then return end
        -- s6-spell-icons: a right click opens the spell's icon editor. Nothing is sent: 4a's list takes no right press
        -- (HandlePointerOrMouseEvent handles types 0-3 and 7), and nothing runs this row's action.
        if button == "RightButton" then
            local ok, name = H:GetSpellSlot(self.slot)
            if ok and TK.SpellIconEditor then TK.SpellIconEditor:Open(name) end
            return
        end
        if dropOnRow(self) then return end
        -- Simple Click: the release casts, but not a double press's (4a's type 3 after a type 2 holds no spell).
        -- Native28: nor one a key ended (above); Native29: nor one made while spell input was up (OnMouseDown).
        if H:GetSpellSlot(self.slot) and not doubleClickMode() and not self.pressDouble and not cleared then TK.Actions:RunFrozen() end
    end)
    -- Double-click mode: the double press casts (4a's type 2), on the press's own record; no release does.
    b:SetScript("OnMouseDown", function(self, button, double)
        if button ~= "LeftButton" then return end
        self.pressDouble = double == true
        -- Native29. WIRE: 4a's single press selects only while no spell input is up (0x0057D9C0 case 1,
        -- SpellInventoryPane.cpp:780, !m_spellInputActive), so such a press holds nothing: its release swaps (30 01) and
        -- casts (Simple Click's 0F) nothing, whenever the input goes (:807-826). Changing it changes what the server sees.
        cleared = H:IsSpellInputActive()
        pressKeys:Show() -- Native28: the keys that end this press (above)
        if double and doubleClickMode() and H:GetSpellSlot(self.slot) and not TK.Cursor:Get() then TK.Actions:RunFrozen() end
    end)
    b:SetScript("OnDragStart", function(self)
        -- WIRE: 4a has no selection to drag after a key ended the press (Native28, above), for a press made while spell
        -- input was up (Native29, OnMouseDown), or for a double press (Native29: case 2, :830-843, selects nothing, and
        -- the first release ended the selection, :826), so dropping it on another row sends no 30 01. Changing it changes
        -- what the server sees.
        if cleared or self.pressDouble then return end
        -- s6-ui-bars (the gate's bar-cast-placed): a drag picks this spell up whatever the cursor carries, as WoW's book
        -- does; what it carried is let go, never placed where this one is dropped.
        -- s6-ui-bars (review r5 finding 2, r6 finding 2): the spell's name and record are taken now, together (as the
        -- input being handled saw the book), so a book update during the drag does not make the drop the spell then in
        -- this slot.
        local rid, name = H:GetSpellRecord(self.slot)
        if name ~= "" then
            TK.Cursor:Set({ kind = "spell", slot = self.slot, from = "book", name = name, rid = rid ~= 0 and rid or nil })
        end
    end)
    b:SetScript("OnReceiveDrag", function(self) dropOnRow(self) end)
end

return Sp
