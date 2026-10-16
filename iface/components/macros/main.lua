-- The macro window (plan D27), as WoW's (round 8, the owner, 2026-10-02; WoW's window read for its behaviour only:
-- docs/research/wow-macro-behaviour.md, section 9). Two sets, the account's macros ("account:1" to "account:120",
-- shared by every character in this user folder) and the character's own ("char:1" to "char:18"), each a pool of
-- icons with names. New asks for a name (16 characters) and an icon (popup.lua); a click selects a macro to edit its
-- text (255 characters); a macro is dragged from the pool (or the selected macro's big icon) onto an action bar button
-- or the action wheel, and that button's key or click runs it. The window binds no keys. The button carries the
-- macro's text (TK.Actions:SetUserMacro) and the game rules run its commands (C#: MacroRules), each as the original's
-- own action, so every packet is the original's.
--
-- The book is the host's (C#: MacroBook), written at each save and when the window closes. "#showtooltip" (or the
-- question-mark icon) makes a button show the spell or item the macro would use now, with its count and aether.
--
-- Keys bound to a macro before round 8 ("MACRO <reference>") still run it; the Key Bindings page lists them under
-- Macros, by name, to change or clear (TK.MacroBindingRows).
--
-- The original's hotkey setup (hotkeys.lua: its thirty text hotkeys and 4a's Macro Setup dialog, D-61) is hidden
-- behind this component's setting, off by default (the owner, 2026-10-02; the head's note 6): on, the window has its
-- Hotkeys tab, and 4a's dialog opens from its own command (Original Macro Setup, originalkeys) and the Menu's entry 6;
-- off, the Menu's entry 6 opens this window (MacroRules.OriginalDialog, TK_MACRO_WINDOW). The text hotkeys already on
-- the bars say their lines either way.
--
-- Command (bindable): TOGGLEMACROS, on F11 (4a's F11 opened its Macro Setup: a declared deviation by the owner's
-- decision, which the setting and a binding undo); the game menu has a Macros entry.

local C = TK.GetComponent("macros")
local H = __tk
local W = TK.UI

-- The vendored Twemoji set (assets/emoji/twemoji, pinned in vendor.lock.json), the chooser's first icons after the
-- question mark, which makes a macro show what it would do. The chooser adds the game's own pictures (popup.lua).
C.ICONS = {
    "2753", "1f525", "26a1", "1f4a7", "1f9ca", "2728", "1f4ab", "1f6e1", "1f4aa", "2620", "1f578", "1f49a", "1fa78",
    "1f4a4", "1f47b", "1f648", "1f9d8", "1f9cd", "1f392", "1f4d6", "1f4dc", "1f3c6", "1f6aa", "1f527", "2699",
}
C.COLUMNS = 8
C.CELL = 38         -- a pool cell's width
C.CELL_HEIGHT = 50  -- its icon and its name under it
C.ROWS = 3          -- the rows the pool shows; it scrolls
C.MAX_BODY = 255
C.MAX_NAME = 16
C.DRAG_HINT = "Drag a macro onto an action bar button; that button's key runs it."

-- The window's help (its "?" button), WoW's macros as this game has them (the job's API.md has the full list). {p} is
-- the client's command prefix (// by default; s6-sandbox round 14, the owner, 2026-10-03), put in when it is shown.
C.HELP = {
    "New: a name and an icon. Then drag the macro onto an action bar button or the action wheel: its key runs it.",
    "One command a line, 255 characters in all ({p} counts as one). This client's commands start with {p} (Settings,",
    "  Macros); any other line is said to the server as written. A server command (a / line) is typed in the chat's Terminal.",
    "{p}cast and {p}use: a spell or item by name. Options as in WoW: {p}cast [mod:shift] Heal; [@mouseover,harm] Bolt; Zap",
    "{p}castsequence reset=5/target/combat/shift A, B, C: one a press, as WoW's: a step that does not go off stays.",
    "{p}next splits the macro into steps, one a press, the first again after the last; a line #reset=target/5 starts the",
    "  steps again as {p}castsequence's reset= does.",
    "{p}target (a name, player, focus, party1...), {p}targetenemy and {p}targetfriend (nearest first, then the next; 1: back),",
    "  {p}targetparty, {p}targetlasttarget, {p}targetexact, {p}cleartarget, {p}focus, {p}clearfocus: free.",
    -- s6-input (round 41): the casters' multi-selection, as the drag makes it
    "{p}select (or {p}select enemies): every hostile creature in view, for a held spell's sweep; {p}select kind: those of",
    "  the target's kind; {p}select add, {p}select remove: the target in or out; {p}clearselection: none. Free.",
    "{p}startattack, {p}stopattack, {p}stopcasting, {p}equip, {p}eat, {p}wield, {p}wear, {p}pickup, {p}look, {p}open, {p}ride,",
    "  the emotes ({p}dance), {p}say, {p}yell, {p}whisper, {p}party, {p}clan, and plugins' commands.",
    "#showtooltip: the button shows what the macro would use now.",
    "Keys: the bar button's key runs its macro. Every key is in Settings, Key Bindings (the list); Macros there has",
    "  this window's key, Original Macro Setup and keys bound to macros before. Settings, Macros has a button to it.",
    -- s6-macros (round 11): the player's guide every build ships (docs/player/macros.md, copied by build-ui-preview.ps1)
    "The whole guide, every command with examples: docs\\Macros.md in the game's folder.",
}

local function character() return TK.Characters.ref or "" end   -- s6-layout round 4: the character on its server
local function isAccount(ref) return ref ~= nil and ref:sub(1, 8) == "account:" end
-- The macros a set holds (C#: MacroBook.AccountCount, CharacterCount).
local function capacity(set) return set == "account" and 120 or 18 end

require("components.macros.popup")
require("components.macros.hotkeys")

--- The setting: the original's hotkey setup (the Hotkeys tab, 4a's Macro Setup dialog) shown. Off by default.
function C:OriginalSetup() return self:DB().originalSetup == true end

-- ----- what a macro's button shows (core/cursor.lua and the action bars call these) -----

--- What the macro would do now (#showtooltip or the question mark): "spell" or "item" and its slot; nil otherwise.
function TK.MacroShownAction(ref)
    local shown, kind, slot = H:MacroShown(character(), ref)
    if shown then return kind, slot end
    return nil, nil
end

--- TK.ActionInfo for one of the player's macros: its name, and the icon of what it would do or its own.
function TK.MacroActionInfo(action)
    local ok, name, icon = H:MacroGet(character(), action.id)
    if not ok then return nil end
    local kind, slot = TK.MacroShownAction(action.id)
    if kind then
        local shownName, key, glyph, count, art, w, h = TK.ActionInfo({ kind = kind, slot = slot })
        if shownName then return name ~= "" and name or shownName, key, glyph, count, art, w, h end
    end
    local art, w, h = C.IconArt(icon) -- the packs not here: the question mark (popup.lua)
    return name ~= "" and name or "Macro", "macro", "", 0, art, w, h
end

--- A macro button's tooltip: what it would do with #showtooltip, else its name and lines; hint: its last line (a bar
--- button's by default).
function TK.MacroTooltip(action, key, hint)
    local ok, name, _, body = H:MacroGet(character(), action.id)
    if not ok then return end
    local shown, kind, slot, tooltip = H:MacroShown(character(), action.id)
    local shownName, _, _, count = TK.ActionInfo(shown and { kind = kind, slot = slot } or nil)
    if tooltip and shownName then
        GameTooltip:AddLine(shownName, 1, 1, 1)
        GameTooltip:AddDoubleLine(kind == "spell" and "Spell" or "Item", "Slot " .. (H:SlotLetter(slot) or "?"),
            0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        if kind == "item" then GameTooltip:AddLine("Count: " .. count, 0.8, 0.8, 0.8) end
        GameTooltip:AddLine("Macro: " .. name, 0.6, 0.8, 1)
    else
        GameTooltip:AddLine(name ~= "" and name or "Macro", 1, 1, 1)
        local n = 0
        for line in body:gmatch("[^\n]+") do
            n = n + 1
            if n > 8 then break end
            GameTooltip:AddLine(line, 0.8, 0.8, 0.8)
        end
    end
    if key then GameTooltip:AddLine("Key: " .. key, 0.5, 0.8, 1) end
    GameTooltip:AddLine(hint or "Drag to move it to another button.", 0.5, 0.5, 0.5)
end

-- ----- keys bound to macros before round 8 (the Key Bindings page shows them) -----

--- The macro a "MACRO <reference>" binding runs: its reference; nil for other commands.
local function boundMacro(command) return type(command) == "string" and command:match("^MACRO (.+)$") or nil end

--- A macro binding's name on the Key Bindings page: "Macro: " and the macro's name (its reference without one).
local function bindingName(ref)
    local ok, name = H:MacroGet(character(), ref)
    return "Macro: " .. ((ok and name ~= "") and name or ref)
end

--- A "MACRO <reference>" binding's name on the Key Bindings page; nil for other commands.
function TK.MacroBindingText(command)
    local ref = boundMacro(command)
    return ref and bindingName(ref)
end

--- The Key Bindings page's rows for the macros that have keys, in their references' order.
function TK.MacroBindingRows()
    local refs, seen = {}, {}
    for _, command in pairs(TK.Bindings:Map()) do
        local ref = boundMacro(command)
        if ref and not seen[ref] then
            seen[ref] = true
            refs[#refs + 1] = ref
        end
    end
    table.sort(refs)
    local rows = {}
    for _, ref in ipairs(refs) do
        rows[#rows + 1] = { type = "binding", name = bindingName(ref), command = "MACRO " .. ref }
    end
    return rows
end

-- ----- the window -----

local window
C.set = "account"   -- the tab: "account", "char" or "hotkeys"
C.selected = nil    -- the selected macro's reference
C.owner = nil       -- the character whose macro the fields hold (a logout may come before they are saved)
C.dirty = false

--- The buttons and the keys attach and draw macros again (a text or an icon changed).
local function changed()
    TK.FireEvent("ACTIONBAR_SLOT_CHANGED")
    TK.FireEvent("UPDATE_BINDINGS")
end

--- s6-sandbox (rounds 16-17): the counter, from the store's one function (C#: MacroBook.Measure, through H:MacroLength):
--- 255 characters, each command's prefix counted as one. The box itself has no letter limit (round 17, Astra's review:
--- a limit in the box cut a paste mid-line, //look into a / that would be said); a text over 255 stays whole in the box,
--- the counter says it is too long, and Save refuses it whole. Run at every change of the text, every load and save.
local function updateCounter()
    local text = window.body:GetText()
    local used = H:MacroLength(text)
    window.counter:SetText(used .. "/" .. C.MAX_BODY .. " characters" .. (used > C.MAX_BODY and ": too long to save" or ""))
    -- s6-sandbox (round 14): this client's own commands take the prefix. s6-play-modes (round 4): a / line is a server
    -- command, which a macro does not send (the chat's Terminal does).
    local said = H:MacroUnknownCommands(text)
    window.hint:SetText(said ~= "" and ("Not sent from a macro: " .. said .. " (this client's commands start with "
        .. H:CommandPrefix() .. ")") or "")
end

--- A pool cell's name, cut to the cell's width as WoW's macro buttons cut theirs (the whole name is in its tooltip).
local function fitName(label, name)
    label:SetText(name)
    for n = #name - 1, 1, -1 do
        if label:GetStringWidth() <= C.CELL - 2 then return end
        label:SetText(name:sub(1, n) .. "...")
    end
end

--- Fills the selected macro's part (none: empty and disabled).
local function load()
    local ok, name, icon, body = false, "", C.ICONS[1], ""
    if C.selected then ok, name, icon, body = H:MacroGet(character(), C.selected) end
    if not ok then C.selected, name, icon, body = nil, "", C.ICONS[1], "" end
    C.owner = character()
    window.loading = true
    window.body:SetText(body)
    window.loading = false
    window.name:SetText(ok and name or "")
    window.icon = icon
    C.ShowIcon(window.bigIcon.tex, icon, window.bigIcon, 40)
    C.dirty = false
    updateCounter()
    C:WindowState()
end

local function makeCell(i, content)
    local b = CreateFrame("Button", "TKMacroCell" .. i, content)
    b:SetSize(C.CELL - 4, C.CELL_HEIGHT - 4)
    b.box = CreateFrame("Frame", nil, b)
    b.box:SetSize(C.CELL - 4, C.CELL - 4)
    b.box:SetPoint("TOP", b, "TOP", 0, 0)
    -- s6-ui-core (round 62): the shared slot's picture over the box, its edge the chosen mark (gold), the light
    b.bg, b.tex, b.sel = W.SlotArt(b, { box = b.box, edge = W.gold })
    b.label = W.Label(b, "", 9, W.white)
    b.label:SetPoint("TOP", b.box, "BOTTOM", 0, -1)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function(self, button)
        if TK.Cursor:ConsumeCancel(button) then return end
        if GetCursorInfo() then ClearCursor() return end
        C:Select(self.ref)
    end)
    b:SetScript("OnDragStart", function(self) C:PickUp(self.ref) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        TK.MacroTooltip({ kind = "usermacro", id = self.ref }, nil, "Drag it onto an action bar button to use it.")
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

--- The pool: the tab's macros in their numbers' order.
local function refreshGrid()
    local list = H:MacroList(character(), C.set == "account")
    local content = window.scroll.content
    for i, ref in ipairs(list) do
        local b = window.cells[i]
        if not b then
            b = makeCell(i, content)
            window.cells[i] = b
        end
        local _, name, icon = H:MacroGet(character(), ref)
        b.ref = ref
        C.ShowIcon(b.tex, icon, b.box, C.CELL - 10)
        fitName(b.label, name)
        b.sel:SetShown(ref == C.selected)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", content, "TOPLEFT", ((i - 1) % C.COLUMNS) * C.CELL + 2,
            -math.floor((i - 1) / C.COLUMNS) * C.CELL_HEIGHT - 2)
        b:Show()
    end
    for i = #list + 1, #window.cells do window.cells[i]:Hide() end
    content:SetSize(C.COLUMNS * C.CELL, math.max(1, math.ceil(#list / C.COLUMNS)) * C.CELL_HEIGHT + 4)
    window.scroll.Refresh()
    window.count:SetText(#list .. " of " .. capacity(C.set))
    window.empty:SetShown(#list == 0)
end

--- What can be used now: nothing but the name and icon popup while it is open (its text box hidden for New, as WoW's, so
--- nothing typed there goes to the macro selected before: review r8, 1); New while the set has room; the selected
--- macro's buttons while one is selected; while the window is 4a's dialog only its tab.
function C:WindowState()
    if not window then return end
    local popup = self:PopupOpen()
    local creating = popup and window.popup.mode == "new"
    local ok = self.selected ~= nil
    local count = #H:MacroList(character(), self.set == "account")
    local room = count < capacity(self.set) and (self.set == "account" or character() ~= "")
    window.tabAccount:SetEnabled(not popup and self.dialog == nil)
    window.tabCharacter:SetEnabled(not popup and self.dialog == nil)
    window.tabHotkeys:SetEnabled(not popup)
    window.new:SetEnabled(not popup and room)
    window.delete:SetEnabled(ok and not popup)
    window.change:SetEnabled(ok and not popup)
    window.change:SetShown(ok)
    window.save:SetEnabled(ok and not popup)
    window.body:SetEnabled(ok and not popup)
    window.body:SetShown(not creating)
    window.bigIcon:SetShown(ok)
end

--- The tabs: the one shown chosen; the Hotkeys tab only with the setting on; while the window is the dialog's face only
--- that tab.
local function refreshTabs()
    window.tabAccount:SetSelected(C.set == "account")
    window.tabCharacter:SetSelected(C.set == "char")
    window.tabHotkeys:SetSelected(C.set == "hotkeys")
    window.tabHotkeys:SetShown(C:OriginalSetup() or C.set == "hotkeys")
    window.tabCharacter:SetText(TK.Characters.name and (TK.Characters.name .. "'s") or "Character")
    window.title:SetText(C.dialog and "Macro Setup" or "Macros")
end

local function build()
    local poolHeight = C.ROWS * C.CELL_HEIGHT + 10
    window = W.Window("TKMacroFrame", "Macros", C.COLUMNS * C.CELL + 60, 548)
    C:Own(window)
    C.window = window
    window.cells = {}

    -- s6-ui-core (round 61): the shared tab (core/widgets.lua)
    window.tabAccount = W.Tab(window, "General", 106, 22, function() C:ShowSet("account") end)
    window.tabAccount:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -38)
    window.tabCharacter = W.Tab(window, "Character", 106, 22, function() C:ShowSet("char") end)
    window.tabCharacter:SetPoint("LEFT", window.tabAccount, "RIGHT", 7, 0)
    window.tabHotkeys = W.Tab(window, "Hotkeys", 106, 22, function() C:ShowSet("hotkeys") end)
    window.tabHotkeys:SetPoint("LEFT", window.tabCharacter, "RIGHT", 7, 0)

    window.dragHint = W.Label(window, C.DRAG_HINT, 11, W.gold, "LEFT")
    window.dragHint:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -68)

    -- The pool.
    local inner = W.Panel(window, nil, true)
    inner:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -86)
    inner:SetSize(C.COLUMNS * C.CELL + 12, poolHeight)
    window.scroll = W.ScrollArea(inner)
    window.scroll:SetPoint("TOPLEFT", inner, "TOPLEFT", 4, -4)
    window.scroll:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -10, 4)
    window.empty = W.Label(inner, "No macros here yet: New makes one.", 11, W.grey)
    window.empty:SetPoint("CENTER", inner, "CENTER", 0, 0)
    window.count = W.Label(window, "", 11, W.grey)
    window.count:SetPoint("TOPRIGHT", inner, "BOTTOMRIGHT", 0, -4)

    -- The selected macro: its big icon (a click or a drag picks it up, as WoW's), its name, and its text.
    local y = -86 - poolHeight - 24
    window.bigIcon = CreateFrame("Button", "TKMacroIcon", window)
    window.bigIcon:SetSize(44, 44)
    window.bigIcon:SetPoint("TOPLEFT", window, "TOPLEFT", 16, y)
    -- s6-ui-core (round 62): the shared slot's picture, without an edge or a light
    window.bigIcon.tex = select(2, W.SlotArt(window.bigIcon, { edge = false, light = false }))
    window.bigIcon:RegisterForDrag("LeftButton")
    window.bigIcon:SetScript("OnClick", function(_, button)
        if TK.Cursor:ConsumeCancel(button) then return end
        if C.selected then C:PickUp(C.selected) end
    end)
    window.bigIcon:SetScript("OnDragStart", function() if C.selected then C:PickUp(C.selected) end end)

    window.name = W.Label(window, "", 14, W.white, "LEFT")
    window.name:SetPoint("TOPLEFT", window.bigIcon, "TOPRIGHT", 10, -2)
    window.change = W.Button(window, "Change Name/Icon", 140, 22, nil, function() C:Change() end)
    window.change:SetPoint("BOTTOMLEFT", window.bigIcon, "BOTTOMRIGHT", 10, 0)

    window.help = W.Button(window, "?", 22, 22)
    window.help:SetPoint("TOPRIGHT", window, "TOPRIGHT", -16, y)
    window.help:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Macros", 1, 1, 1)
        local p = H:CommandPrefix()
        for _, line in ipairs(C.HELP) do GameTooltip:AddLine((line:gsub("{p}", function() return p end)), 0.8, 0.8, 0.8) end
        GameTooltip:Show()
    end)
    window.help:SetScript("OnLeave", function() GameTooltip:Hide() end)

    window.bodyLabel = W.Label(window, "Enter macro commands:", 11, W.gold, "LEFT")
    window.bodyLabel:SetPoint("TOPLEFT", window, "TOPLEFT", 16, y - 54)
    window.body = W.EditBox(window, C.COLUMNS * C.CELL + 12, 120)
    window.body:SetPoint("TOPLEFT", window, "TOPLEFT", 16, y - 70)
    window.body:SetMultiLine(true)
    -- s6-sandbox (round 17): no letter limit on the text (0: none). A limit here cuts what is typed or pasted wherever it
    -- falls, a command line included; the 255 are the counter's and Save's, which refuse a longer text whole.
    window.body:SetMaxLetters(0)
    window.body:SetScript("OnTextChanged", function(_, user)
        if user and not window.loading then C.dirty = true end
        updateCounter()
    end)
    window.counter = W.Label(window, "", 11, W.grey)
    window.counter:SetPoint("TOPRIGHT", window.body, "BOTTOMRIGHT", 0, -4)
    window.hint = W.Label(window, "", 11, { 1, 0.6, 0.2 }, "LEFT")
    window.hint:SetPoint("TOPLEFT", window.body, "BOTTOMLEFT", 0, -4)
    window.hint:SetWidth(220)

    window.new = W.Button(window, "New", 80, 24, nil, function() C:New() end)
    window.new:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 16, 14)
    window.delete = W.Button(window, "Delete", 80, 24, nil, function() C:Delete() end)
    window.delete:SetPoint("LEFT", window.new, "RIGHT", 6, 0)
    window.save = W.Button(window, "Save", 80, 24, nil, function() C:Save() end)
    window.save:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 14)

    -- The macro book's parts, which the Hotkeys tab hides.
    window.bookParts = { window.dragHint, inner, window.count, window.bigIcon, window.name, window.change, window.help,
        window.bodyLabel, window.body, window.counter, window.hint, window.new, window.delete, window.save }
    C:BuildHotkeys(window)
    C:WireDialog(window)

    -- Closing keeps what was typed, as WoW's window does.
    window:HookScript("OnHide", function()
        C:ClosePopup()
        if C.dirty then C:Save() end
        C:CommitHotkeys()
    end)
end

--- Opens the window on a tab ("account", "char", or "hotkeys" with the setting on); nil: the last macro tab.
function C:Open(set)
    if not TK.GameState:InWorld() then return end
    if not window then build() end
    window:Show()
    if set == "hotkeys" and not self:OriginalSetup() then set = nil end
    self:ShowSet(set or (self.set ~= "hotkeys" and self.set) or "account")
end

function C:Toggle()
    if window and window:IsShown() then window:Hide() else self:Open() end
end

function C:IsOpen() return window ~= nil and window:IsShown() end

--- s6-sandbox (round 14): the Macros page's "Client command prefix" (the owner, 2026-10-03): "" when text is now the
--- prefix, else why not. The window's unsaved text is saved first, in the old prefix, which the book then moves to the new
--- one (C#: MacroBook.UsePrefix); the fields and the buttons holding macros take the moved text.
function C:SetCommandPrefix(text)
    if text == H:CommandPrefix() then return "" end
    if window and self.dirty then self:Save() end
    local why = H:SetCommandPrefix(text)
    if why == "" then
        if window and window:IsShown() and self.set ~= "hotkeys" then load() end
        changed()
    end
    return why
end

function C:ShowSet(set)
    if self.dirty then self:Save() end
    self:ClosePopup()
    -- Another character since the fields were loaded: its own set has nothing selected yet.
    if self.owner ~= character() and not isAccount(self.selected) then self.selected = nil end
    if self.dialog then set = "hotkeys" end
    self.set = set
    local hotkeys = set == "hotkeys"
    for _, f in ipairs(window.bookParts) do f:SetShown(not hotkeys) end
    window.hotkeys:SetShown(hotkeys)
    refreshTabs()
    if hotkeys then
        self:HotkeyPage(self.dialog and 0 or window.hotkeys.page)
        return
    end
    self:CommitHotkeys()
    if isAccount(self.selected) ~= (set == "account") or not self.selected then
        self.selected = H:MacroList(character(), set == "account")[1]
    end
    refreshGrid()
    load()
end

--- A click in the pool: the last macro's text kept, this one's shown (the popup closes, as WoW's).
function C:Select(ref)
    if self.dirty then self:Save() end
    self:ClosePopup()
    self.selected = ref
    refreshGrid()
    load()
end

--- New: the name and icon popup; its OK makes the macro (CreateMacro).
function C:New()
    if self.dirty then self:Save() end
    self:OpenPopup("new")
end

--- Change Name/Icon: the popup with the selected macro's name and icon.
function C:Change()
    if not self.selected then return end
    self:OpenPopup("edit", window.name:GetText(), window.icon)
end

--- Makes a macro in the tab's set with a name and an icon and no text yet, and selects it; false when the set is full.
function C:CreateMacro(name, icon)
    if self.dirty then self:Save() end
    local ref = H:MacroSave(character(), "", self.set == "account", name, icon, "")
    if ref == "" then
        UIErrorsFrame:AddMessage("No room for another macro here.", 1, 0.6, 0.2)
        return false
    end
    self.selected = ref
    refreshGrid()
    load()
    return true
end

--- The selected macro's new name and icon, with its text as it is in the box.
function C:Rename(name, icon)
    if not self.selected then return end
    window.name:SetText(name)
    window.icon = icon
    C.ShowIcon(window.bigIcon.tex, icon, window.bigIcon, 40)
    self.dirty = true
    self:Save()
end

--- Saves the selected macro into its owner's book (the character it was loaded for, though another may be in the
--- world by now); the keys go back to the game (the text box lets go of the keyboard).
function C:Save()
    if not self.selected or not window then return end
    window.body:ClearFocus()
    local text = window.body:GetText()
    -- s6-sandbox (round 16): a text over the limit is refused, never cut (a cut could leave half a command line, which
    -- would be said). s6-protocol (round 62, for s6-sandbox): the box has no limit (SetMaxLetters(0)), so a text typed or
    -- pasted past it reaches here and is refused; the counter below the box only reports how long it is.
    local used = H:MacroLength(text)
    if used > C.MAX_BODY then
        UIErrorsFrame:AddMessage("The macro is " .. used .. " characters, " .. C.MAX_BODY .. " at most: it was not saved.", 1, 0.3, 0.3)
        return
    end
    local ref = H:MacroSave(self.owner or character(), self.selected, isAccount(self.selected), window.name:GetText(),
        window.icon or C.ICONS[1], text)
    if ref == "" then UIErrorsFrame:AddMessage("The macro could not be saved.", 1, 0.3, 0.3) return end
    self.dirty = false
    updateCounter() -- s6-sandbox (round 16): the counter reports the saved text's length, as the store counts it (s6-protocol round 62: it limits nothing)
    refreshGrid()
    changed()
end

--- Delete asks first, as WoW's (round 10, from the UI job's look at next26): Yes deletes the macro, No or Escape keeps
--- it (the client's confirm dialog, TKConfirm).
function C:Delete()
    local ref = self.selected
    if not ref then return end
    local _, name = H:MacroGet(character(), ref)
    W.Confirm("Delete the macro \"" .. name .. "\"? It also leaves every action bar button it is on.",
        function() self:DeleteNow(ref) end)
end

--- Deletes a macro, takes it off this character's bars (as WoW's), and off any key bound to it before round 8.
function C:DeleteNow(ref)
    if not H:MacroDelete(character(), ref) then return end
    local actions = TK.Characters:Actions()
    for slot, a in pairs(actions) do
        if a.kind == "usermacro" and a.id == ref then actions[slot] = nil end
    end
    TK.Characters:MarkDirty()
    for key, command in pairs(TK.Bindings:Map()) do
        if command == "MACRO " .. ref then SetBinding(key, nil) end
    end
    if self.selected == ref then
        self.selected = nil
        self.dirty = false
    end
    if window and window:IsShown() then self:ShowSet(self.set) end
    changed()
end

--- The Key Bindings list (the settings tree's Key Bindings page), scrolled to its Macros group.
function C:ShowBindingsList()
    TK.Settings:Open("keybindings", "General")
    local header = TK.Settings:Widget("Macros")
    if header then TK.Settings:ScrollTo(header) end
end

--- Puts a macro on the cursor, to drop on an action button (PlaceAction) or the action wheel.
function C:PickUp(ref)
    if self.dirty then self:Save() end
    TK.Cursor:Set({ kind = "usermacro", id = ref })
end

-- ----- #showtooltip: buttons follow what their macros would do -----

-- What each macro on the bars shows; when one changes (a modifier, the target, a slot), the bars draw again.
local shownNow = {}
local elapsed = 0
local ticker = CreateFrame("Frame", nil, UIParent)
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + (dt or 0)
    if elapsed < 0.2 or not TK.GameState:InWorld() then return end
    elapsed = 0
    local differ = false
    local seen = {}
    for _, a in pairs(TK.Characters:Actions()) do
        if a.kind == "usermacro" and not seen[a.id] then
            seen[a.id] = true
            local kind, slot = TK.MacroShownAction(a.id)
            local now = kind and (kind .. slot) or ""
            if shownNow[a.id] ~= now then
                shownNow[a.id] = now
                differ = true
            end
        end
    end
    if differ then TK.FireEvent("ACTIONBAR_SLOT_CHANGED") end
end)

-- ----- the setting -----

--- The setting into the game rules (4a's dialog opens or not; the Menu's Hotkey) and the window's tabs; and, once
--- for a profile made before F11 was this window's, its F11 moved from Original Macro Setup to this window.
function C:ApplySettings()
    local db = self:DB()
    if not db.f11Moved then
        db.f11Moved = true
        if not self:OriginalSetup() and TK.Bindings:Map()["F11"] == "MACROS" then SetBinding("F11", "TOGGLEMACROS") end
    end
    H:MacroOriginalSetup(self:OriginalSetup())
    if window and window:IsShown() then
        if self.set == "hotkeys" and not self:OriginalSetup() and not self.dialog then self:ShowSet("account") else refreshTabs() end
    end
end

function C:OnEnable()
    self:AttachDialog()
    -- Original Macro Setup is on the Key Bindings page only with the setting on.
    local original = TK.Bindings.commands.MACROS
    if original then original.hidden = function() return not C:OriginalSetup() end end
end

-- A key bound to a macro freezes its text when the key layer is made; the character's set is another one's after a
-- login, so the layer is made again (review r1, 5). The session's rules are new: they take the setting.
TK.On("PLAYER_ENTERING_WORLD", function()
    TK.Bindings:PushKeys()
    H:MacroOriginalSetup(C:OriginalSetup())
end)

-- The Menu's entry 6 ("Hotkey") with the original's setup hidden (MacroRules.WindowAsked).
TK.On("TK_MACRO_WINDOW", function() C:Open() end)

TK.Bindings:RegisterCommand("TOGGLEMACROS", "Macros", function() C:Toggle() end)
TK.DB.defaultBindings["F11"] = "TOGGLEMACROS"
TK.GameMenu:AddEntry({ id = "macros", text = "Macros", order = 35,
    onClick = function() TK.GameMenu:Close(); C:Open() end,
    shown = function() return TK.GameState:InWorld() end })
