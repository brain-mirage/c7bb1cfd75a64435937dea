-- The original's thirty macro keys (D-61, head note 1): records 0-29, keys 1 to 0, Ctrl+1 to Ctrl+0 and Alt+1 to Alt+0,
-- on bars 1-3 (record r is bar r / 10 + 1, button r % 10 + 1; UsrFile.HotbarActions). A record is a spell, an item or a
-- line of text; the spells and items are the bars' own actions (drag them there), the text macros are edited here, in
-- the macro window's Hotkeys tab, ten rows a page over three pages as 4a's IntegrateMacroDialog ("Macro Setup").
--
-- Typing a line makes the record a text macro and puts it on its key's bar button, as 4a's row binds its key. A row
-- that lets go (the keyboard leaves it, the page changes, the window closes) keeps its line's first 64 characters, typed
-- or not (4a's IntegrateMacroEditControlPane::Deactivate copies every text row back, 64 at most: a longer imported line
-- is cut, its key left as it is). A press of that key says it on the original's text-macro path (0E 00, rules-items'
-- ChatRules). The x takes it away.
--
-- Round 8 (the head's note 6): the tab and the dialog are hidden behind the macro window's setting, off by default
-- (main.lua). With it on, all of this is as it was.
--
-- The window is also the face of the dialog model's IntegrateMacroDialog (TK-Core/Rules/Macros), which opens where 4a
-- opens it (its command Original Macro Setup, 4a's F11, which the player binds; the Menu's entry 6, "Hotkey"): it is
-- modal, and its controls are 4a's: OK 1, the rows
-- 2-11, the page buttons 12 and 13. The window shows the model's page, focus (the focused row has the keyboard) and
-- enabled page buttons; its controls' presses and releases, and the rows' Enter, Escape and Tab, go to the model (Tab
-- walks the controls, Space or Enter on a page button pages, Enter on a row and Escape press OK). The window opens on
-- this tab with the dialog and closes with it. Nothing is sent either way.
--
-- s6-interface-7x (round 2): a look that draws 4a's own Macro Setup (7.x's MacroSetup entry) gives the dialog a window of
-- its own instead of this tab: the same rows and logic (panel()), drawn as 4a's (row.paint), the same controls.

local C = TK.GetComponent("macros")
local H = __tk
local W = TK.UI

local PAGES = { "Keys 1 to 0", "Ctrl+1 to Ctrl+0", "Alt+1 to Alt+0" }
local PREFIX = { "", "Ctrl+", "Alt+" }
local KEPT = 64 -- 4a's CopyWideText bound (the host's HotkeyTextLength)

local function character() return TK.Characters.ref or "" end   -- s6-layout round 4: the character on its server

--- The key of record r (0-29): its page's prefix and its digit (record 0 is 1, record 9 is 0).
function C.HotkeyLabel(r) return PREFIX[math.floor(r / 10) + 1] .. tostring((r % 10 + 1) % 10) end

--- The action slot of record r's bar button: the game layer's hotkey slots, in key order (TK.Game.Hotkeys.SLOTS). Wire:
--- the slot a text macro is put on decides what its key sends (4a's text record: UserPane::ExecuteHotkeyAction
--- 0x005A3AE0, 0E 00); changing it changes what the server sees.
function C.HotkeySlot(r) return TK.Game.Hotkeys.SLOTS[r + 1] end

--- What record r's key does now, from its bar button.
local function keyDoes(r)
    local action = TK.ActionAt(C.HotkeySlot(r))
    if not action then return "" end
    if action.kind == "macro" then return action.id == r and "text" or "" end
    local name = TK.ActionInfo(action)
    if not name then return "" end
    if action.kind == "spell" then return "spell: " .. name end
    if action.kind == "item" then return "item: " .. name end
    return "macro: " .. name
end

--- s6-interface-7x (round 2): record r as 4a's row draws it (SpellMacroEditControlPane::OnPaint 0x0057FFB0): its kind
--- letter (T a text, S a spell, I an item; nil for none) and, for a spell or an item, "%c:%s", its slot's letter and
--- the slot's name ("" for an empty slot, as 4a's "a:" for a spell slot that holds none), for a look that draws the row
--- as 4a's (7.x's Macro Setup: row.paint).
local function shownAs(r, isText)
    if isText then return "T", nil end
    local action = TK.ActionAt(C.HotkeySlot(r))
    if not action or (action.kind ~= "spell" and action.kind ~= "item") then return nil, nil end
    local slot = action.slot or (action.item and TK.FindItem(action.item))
    local name = TK.ActionInfo(action)
    return action.kind == "spell" and "S" or "I", (slot and H:SlotLetter(slot) or "?") .. ":" .. (name or "")
end

local function refreshRow(row, r, owner)
    row.record = r
    row.key:SetText(C.HotkeyLabel(r))
    local isText, text = H:HotkeyMacroGet(owner, r)
    row.loading = true
    row.edit:SetText(isText and text or "")
    row.loading = false
    row.dirty = false
    row.isText = isText
    local does = keyDoes(r)
    if isText and does ~= "text" then does = "text, not on its key" end
    row.does:SetText(does)
    if row.clear then row.clear:SetShown(isText) end -- s6-interface-7x: 7.x's Macro Setup has none (4a's row none)
    if row.paint then row.paint(shownAs(r, isText)) end -- s6-interface-7x (round 2)
end

--- s6-interface-7x (round 2): the rows the hotkeys' logic works on: the dialog's own window's while one is open (a look
--- that draws 4a's Macro Setup: Dialog.build below), else the macro window's tab.
local function panel()
    return C.dialogPanel or (C.window and C.window.hotkeys)
end

--- The tab's own page buttons, while no dialog pages it: back from the second page, on to the last.
local function pageButtons(p)
    p.prev:SetEnabled(p.page > 0)
    p.next:SetEnabled(p.page < 2)
end

--- A key of a row's edit box: the dialog's while the window is its face, else the edit's own.
local function rowKey(row, key)
    if C.dialog then
        C:DialogKey(key)
        return
    end
    row.edit:ClearFocus()
    if key == "ENTER" then C:HotkeyCommit(row) end
end

--- A row's edit's scripts: typing marks it, Enter, Escape and Tab are its key (rowKey), letting go of the keyboard
--- commits it. (s6-interface-7x round 2: shared by the tab's rows and the dialog's own window's.)
local function rowScripts(row)
    row.edit:SetScript("OnTextChanged", function(_, user) if user and not row.loading then row.dirty = true end end)
    row.edit:SetScript("OnEnterPressed", function() rowKey(row, "ENTER") end)
    row.edit:SetScript("OnEscapePressed", function() rowKey(row, "ESCAPE") end)
    row.edit:SetScript("OnTabPressed", function() rowKey(row, "TAB") end)
    row.edit:SetScript("OnEditFocusLost", function() C:HotkeyCommit(row) end)
end

--- Builds the tab's panel in the macro window (main.lua's build).
function C:BuildHotkeys(window)
    local p = CreateFrame("Frame", "TKMacroHotkeys", window)
    p:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -66)
    p:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 14)
    p:Hide()
    p.page = 0
    -- With the dialog, the model pages (its controls 12 and 13); alone, the buttons do. s6-ui-core (round 62; s6-optimize's
    -- plan step 4): the shared stepper (W.Stepper) across the top, the page's title between its arrows (p.prev, p.title,
    -- p.next as they were).
    local pages = W.Stepper(p, nil, function(step) if not C.dialog then C:HotkeyPage(p.page + step) end end,
        { size = 13, colour = W.gold })
    pages:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    pages:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
    p.prev, p.title, p.next = pages.back, pages.value, pages.forward
    p.rows = {}
    for i = 1, 10 do
        local row = CreateFrame("Frame", "TKMacroHotkeyRow" .. i, p)
        row:SetSize(330, 34)
        row:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -30 - (i - 1) * 35)
        row.key = W.Label(row, "", 12, W.gold, "LEFT")
        row.key:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4)
        row.edit = W.EditBox(row, 240, 22)
        row.edit:SetPoint("TOPLEFT", row, "TOPLEFT", 62, 0)
        row.edit:SetMaxLetters(1024) -- 4a's field takes 1024; 64 are kept
        rowScripts(row)
        row.does = W.Label(row, "", 10, W.grey, "LEFT")
        row.does:SetPoint("TOPLEFT", row.edit, "BOTTOMLEFT", 2, -1)
        row.clear = W.IconButton(row, "tk:close", 14, function() C:HotkeyClear(row) end)
        row.clear:SetPoint("LEFT", row.edit, "RIGHT", 6, 0)
        p.rows[i] = row
    end
    p.help = W.Label(p, "Type a line for a key to say it (64 characters are kept). Spells and items: drag them onto the bars.",
        11, W.grey, "LEFT")
    p.help:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 34)
    p.help:SetWidth(330)
    p.help:SetWordWrap(true) -- two lines inside the window, not one past its edge (round 10)
    p.ok = W.Button(p, "OK", 80, 24, nil, function() if not C.dialog then window:Hide() end end)
    p.ok:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
    window.hotkeys = p
end

--- Shows a page (0-2) of the rows for the character in the world; the rows on show let go first, as 4a's buttons
--- deactivate them.
function C:HotkeyPage(page)
    local p = panel()
    if not p then return end
    self:CommitHotkeys()
    p.page = math.max(0, math.min(2, page))
    p.owner = character()
    if p.title then p.title:SetText(PAGES[p.page + 1]) end -- s6-interface-7x: 4a's window draws no page title
    if not self.dialog then pageButtons(p) end
    for i, row in ipairs(p.rows) do refreshRow(row, p.page * 10 + i - 1, p.owner) end
end

--- Every row on show lets go (the window closes, the page or the tab changes).
function C:CommitHotkeys()
    local p = panel()
    if not p then return end
    for _, row in ipairs(p.rows) do self:HotkeyCommit(row) end
end

--- A row lets go: a typed line becomes its record's text macro, on its key's bar button; a text macro not typed in keeps
--- its first 64 characters and its key as they are. The record is its owner's, the character the page was shown for
--- (a logout may come first: then the line is kept and the bars, another's by then, are left alone).
function C:HotkeyCommit(row)
    local p = panel()
    if not p or not row.record then return end
    local owner, r = p.owner or character(), row.record
    local text = row.edit:GetText()
    if not row.dirty then
        if row.isText and #text > KEPT and H:HotkeyMacroSave(owner, r, text) then
            refreshRow(row, r, owner)
            -- The buttons holding it carry a copy of its text: they take the cut one (review r3, 2), bound as they are.
            TK.FireEvent("ACTIONBAR_SLOT_CHANGED")
        end
        return
    end
    row.dirty = false
    if text == "" and not row.isText then return end
    if not H:HotkeyMacroSave(owner, r, text) then
        UIErrorsFrame:AddMessage("The macro could not be saved.", 1, 0.3, 0.3)
        return
    end
    if owner == character() then
        local actions = TK.Characters:Actions()
        local key = tostring(self.HotkeySlot(r))
        local a = actions[key]
        if not (a and a.kind == "macro" and a.id == r) then
            actions[key] = { kind = "macro", id = r }
            TK.Characters:MarkDirty()
        end
    end
    refreshRow(row, r, owner)
    TK.FireEvent("ACTIONBAR_SLOT_CHANGED")
end

--- The row's record is no text macro any more, and its key's bar button lets go of it.
function C:HotkeyClear(row)
    local r = row.record
    if not r or not H:HotkeyMacroDelete(character(), r) then return end
    local actions = TK.Characters:Actions()
    local key = tostring(self.HotkeySlot(r))
    local a = actions[key]
    if a and a.kind == "macro" and a.id == r then
        actions[key] = nil
        TK.Characters:MarkDirty()
    end
    refreshRow(row, r, character())
    TK.FireEvent("ACTIONBAR_SLOT_CHANGED")
end

-- ----- the dialog model's IntegrateMacroDialog (D-61) -----

--- The window of the dialog: a stand-in the dialogs component shows and hides with the model's dialog, which opens and
--- closes the macro window on its Hotkeys tab. Its controls are the macro window's (the kit marks their focus and
--- enabled state, and gives the focused row the keyboard).
--- s6-interface-7x (round 2): a look that draws 4a's own Macro Setup (its MacroSetup entry: 7.x's) gets the dialog's
--- own window instead (buildOwn), the same rows and logic; Modern's has none, so it keeps the stand-in.
local Dialog = { look = "MacroSetup" }

--- The dialog's controls as the macro window shows them, and what their presses go to (the kit posts their real press
--- and release to the model; with no dialog, nothing).
C.face = { controls = {} }

--- s6-interface-7x (round 2): the dialog's own window, drawn and placed by the look's MacroSetup entry: its controls are
--- the dialog's (OK 1, the rows' edits 2-11, the page buttons 12 and 13, as 4a's IntegrateMacroDialog 0x00541B30), wired
--- to the model as the tab's are (presses and releases; a row's Enter, Escape and Tab its keys), its rows the tab's
--- (key, does, edit; no x: 4a's has none). It opens and closes with the model's dialog, without the macro window.
local function buildOwn(L)
    local K = TK.GetComponent("dialogs").kit
    local win = K.Window(L.width, L.height, "Macro Setup")
    local p = { page = 0, rows = {} }
    win.panel = p
    p.ok = K.Button(win, 1, "OK", L.button)
    p.prev = K.Button(win, 12, "<", L.button)
    p.next = K.Button(win, 13, ">", L.button)
    for i = 1, 10 do
        local row = CreateFrame("Frame", nil, win)
        row.key = row:CreateFontString(nil, "OVERLAY")
        row.does = row:CreateFontString(nil, "OVERLAY")
        -- a press anywhere on the row is its control's, as 4a's row pane takes it (the model's focus then gives the
        -- row's edit the keyboard); the edit over it (its child) takes its own
        row:EnableMouse(true)
        K.Wire(win, row, i + 1)
        row.edit = W.EditBox(row, L.editWidth, L.editHeight)
        row.edit:SetMaxLetters(1024) -- 4a's field takes 1024; 64 are kept
        rowScripts(row)
        win.controls[i + 1] = row.edit
        K.Wire(win, row.edit, i + 1)
        p.rows[i] = row
    end
    win:HookScript("OnShow", function(self) C:OpenDialog(self) end)
    win:HookScript("OnHide", function(self) C:DialogClosed(self) end)
    L.place(win)
    return win
end

--- entry: the look's MacroSetup entry, which the dialogs component gives the build (s6-characters round 46, separation
--- step 6; nil in the default look).
function Dialog.build(_, entry)
    if entry then return buildOwn(entry) end -- s6-interface-7x (round 2)
    local stub = CreateFrame("Frame", "TKMacroDialogStub", UIParent)
    stub:SetSize(1, 1)
    stub.controls = C.face.controls
    stub:Hide()
    stub:SetScript("OnShow", function(self) C:OpenDialog(self) end)
    stub:SetScript("OnHide", function(self) C:DialogClosed(self) end)
    return stub
end

--- The model's page (its buttons 12 and 13 moved it): the rows on show let go, then show it.
function Dialog.update(stub, view)
    local p = panel()
    local page = view.contents and view.contents.page
    if p and C.dialog == stub and page and page ~= p.page then C:HotkeyPage(page) end
end

--- The dialog opened (F11, the Menu's Hotkey): the window shows its Hotkeys tab, page 1, the other tabs unavailable.
--- s6-interface-7x (round 2): the dialog's own window (stub.panel) shows its first page itself.
function C:OpenDialog(stub)
    self.dialog = stub
    self.face.serial = stub.serial
    if stub.panel then
        self.dialogPanel = stub.panel
        self:HotkeyPage(0)
        return
    end
    self:Open("hotkeys")
end

--- The model closed the dialog (OK, Enter, Escape): so does the window.
--- s6-interface-7x (round 2): the dialog's own window's rows let go first, as 4a's Deactivate copies them back; the
--- macro window is not its face then, so it stays as it is.
function C:DialogClosed(stub)
    if self.dialog ~= stub then return end
    local own = stub.panel ~= nil
    if own then self:CommitHotkeys() end
    self.dialog = nil
    self.dialogPanel = nil
    self.face.serial = nil
    if own then return end
    if self.window and self.window:IsShown() then self.window:Hide() end
    if self.window then pageButtons(self.window.hotkeys) end
end

--- A key for the dialog (a row's Enter, Escape, Tab): the model's (s6-interface-7x: by the dialog's own window, when it
--- has one, whose fields the kit reads).
function C:DialogKey(key)
    local K = TK.GetComponent("dialogs") and TK.GetComponent("dialogs").kit
    local face = self.dialogPanel and self.dialog or self.face
    if K and self.face.serial then K.Key(face, key) end
end

--- Makes the window's controls the dialog's: OK and the close box 1, the rows 2-11, the page buttons 12 and 13
--- (main.lua's build).
function C:WireDialog(window)
    local K = TK.GetComponent("dialogs") and TK.GetComponent("dialogs").kit
    if not K then return end
    local p, controls = window.hotkeys, self.face.controls
    controls[1], controls[12], controls[13] = p.ok, p.prev, p.next
    for i, row in ipairs(p.rows) do controls[i + 1] = row.edit end
    for index, frame in pairs(controls) do K.Wire(self.face, frame, index) end
    if window.close then
        K.Wire(self.face, window.close, 1)
        window.close:SetScript("OnClick", function() if not C.dialog then window:Hide() end end)
    end
end

--- Registers the window as the model's IntegrateMacroDialog (main.lua's OnEnable).
function C:AttachDialog()
    TK.Dialogs.RegisterRenderer("IntegrateMacroDialog", Dialog) -- s6-characters (round 46, separation step 6)
end
