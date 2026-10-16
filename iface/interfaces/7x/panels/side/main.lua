-- s6-modular-g (interfaces, phase 5, round 14): 7.x's side panel, the original's GeneralPurposePanel (constructor
-- 0x004B83D0) with its tab strip (TabPane, constructor at (808, 79)-(831, 365)): one tab pane at a time at (832, 79)-(1021,
-- 367) of the 7.x screen (SwitchActiveTab 0x004B8650), no tab when the game screen is built. The active tab, its rule and
-- its event are the game layer's (core/game/sidepanel.lua: one tab for the session, s6-interface-5x round 12, step 1),
-- the openers its views (core/game/views.lua); this panel shows the active tab's page and provides its pages to the
-- openers. The header over the strip is the screen's (TABS.EPF, interfaces/7x/panels/screen). Drawn from Source-5's
-- class pages:
--   items       NewInventoryPane (OnPaint 0x004EBB20): ITEMINV.EPF in ITEMINV.PAL, the list (frame 1, the default: 13 rows
--               of the slots that hold an item, 20 apart) or the grid (frame 0: 15 cells of 43 x 43, 51 apart); INVENBUT's
--               List, Grid, Mix and Expand buttons; the scroll bar (SLIDEBG, SCRBUTT) at (169, 122)-(182, 267)
--   spells      NewSpellInventoryPane (OnPaint 0x0057D430): SPELLINV.EPF, 13 rows 20 apart, the letter and the name
--   self        SelfLookPane, its three views (selflook.lua)
--   look        UserLookPane, another player's look, its four views (look.lua; s6-interface-7x-b round 5)
--   group       NewGroupPane (OnPaint 0x0056CE50): GROUP.EPF, six rows on GROUPCOL.EPF: the name, the vita and mana bars
--               (BAR.EPF) and their percentages in 9X11FONT's digits; every member of 63 02, the player's own included
--   collection  CollectionPane (OnPaint 0x0056EDC0): CLTINV.EPF, five volumes on CLTLIST.EPF: the name, the percentage
--               and the count, glowing when complete
--   options     NewOptionPane, the options page (options.lua; s6-interface-7x-b round 5)
-- s6-interface-7x-b (round 5): the items, spells and group panes' Expand (ToggleExpandedMode: items 0x004EE5A0, spells
-- 0x0057E9D0, group 0x0056E8C0) grows the pane in place to (827, 79)-(1021, 637), over the messages pane, until pressed
-- again or the tab's own key comes while it shows ('i', '+', 'f': the pane takes its key before UserPane while it is the
-- active tab); kept across tab switches, reset by a new game screen. Expanded, the pane draws everything 5 pixels right
-- of where it tests its presses (InventoryPane.cpp:856-876), so on the screen its controls lie 5 pixels left of their
-- pictures; the items list every slot up to the bag's slot count (26 rows, 27 to press), the grid 27 cells, the spells
-- every slot (26 rows), the group 12 members, each on ITEMINVE.EPF (frame 1 list, 0 grid, 2 spells, 3 group). Toggling
-- sends nothing (the group's sends no 2D 01: its page stays shown, so its request does not run).
--
-- Wire: what a press on a page sends is the game layer's controls' (s6-interface-5x round 12, step 2), the ones every
-- interface uses: the items are slot controls (TK.Game.Inventory.SlotControl and its actions; an expanded pane's empty
-- slots are controls too, so a carried item dropped there sends 30 00 as 4a's release does, the rules testing the slot
-- count), the spells book cells (TK.Game.Spells.CellControl; 30 01 onto an empty slot alike), the worn items and switches
-- the self look's (selflook.lua: TK.Game.SelfLook), the look's buttons the look's actions (look.lua: TK.Game.Look), the
-- option rows Game Options' rows (options.lua), a volume the collection dialog's opener (TK.Dialogs.Open), Mix the dialog
-- model's ("dialog:open" MixItemDialog: TK.Game.Inventory.MixControl). The pages that ask the server for their data carry
-- their requests (TK.Game.Views' notes); the strip runs 4a's TabPane on the left press (below). What the server's packets and the rules change here (the
-- tab switches of a 0x34, a 0x39 and a spell prompt's ?, as rules' notices in the logic's own order; the pages' rows)
-- comes as events, never from a poll: the host raises them before any input that came after them (UIHost.CatchUp), as
-- 4a's handlers ran in EventMan's order. The self tab's button and the S key only ask for the status
-- (TK.Game.SidePanel.Request), as the collection tab's do while its list has not come; the 0x39 and the page list show
-- them. Changing any of these changes what the server sees.

local C = TK.GetComponent("7x.side")
local H = __tk
local S = require("interfaces.7x.skin")
local Screen = require("interfaces.screen")
local SP = TK.Game.SidePanel
local ItemBox = require("interfaces.7x.itembox")
local Hud = require("interfaces.7x.hud") -- s6-interface-5x round 16: the inventory owns server help.
local Inv, Spells = TK.Game.Inventory, TK.Game.Spells
local K = require("interfaces.7x.panels.side.kit")
local Self = require("interfaces.7x.panels.side.selflook")
local Look = require("interfaces.7x.panels.side.look")
local Options = require("interfaces.7x.panels.side.options")
local DragLabel = require("interfaces.original.draglabel")

local PLACE = { 808, 79 }       -- the strip's top left; the panel is the strip and the pane beside it
local PANE_X = 832 - 808         -- the pane's left in the panel
local WIDTH, HEIGHT = 1021 - 808, 367 - 79
local EXPANDED = { 1021 - 827, 637 - 79 } -- an expanded pane's size, its left 5 pixels left of the pane's
local EXPANDED_LEVEL = 20                 -- an expanded pane's frame level: above the messages pane's (placePage)
local HEADER_ROWS = 287                   -- the tab header's rows over an expanded pane's left 5 columns (expandedBack)

local hit, text = K.Hit, K.Text

--- The slot of the item carried from a slot (the game layer's carry), or nil.
local function carried()
    local held = Inv.Carry()
    return held and held.slot
end

--- The slot a page paints as selected while a press is held and nothing is carried yet (4a's m_selectedInventorySlot or
--- m_selectedSpellSlot, set by the single left press that also makes the passive label: NewInventoryPane 0x004ECB50
--- InventoryPane.cpp:1150-1158, NewSpellInventoryPane 0x0057D9C0 SpellInventoryPane.cpp:780-792), or nil. A grid cell
--- shows from the press itself: WillBeChangedItemPane 0x004C78E0 re-activates the inventory in the icon view only
--- (HelpPane.cpp:513; NewInventoryPane::OnActivate 0x004EB550 invalidates it). A list row or spell shows from the
--- first pointer move (:983-996; :692-707) or a key the pane keeps, which repaints it (Native29: Page Up/Page Down,
--- 'i', '+'; HandleKeyOrTextEvent 0x004EC920, 0x0057D8D0). It lasts while the press holds the selection (label.held),
--- after a key has deleted the label too. Paint only: the shared slot controls keep the press, the carry and every packet.
local function pressed(p)
    local label = p.dragLabel
    if label.held and (label.kind == "grid" or label.moved) then return label.slot end
end

--- A page's place: the pane's, or expanded 5 to the left and 558 high (ToggleExpandedMode's SetBounds), its drawing 5 to
--- the right (p.dx) of its unmoved hit rectangles (the header). Resized in place, never hidden, so a page's request does
--- not run again.
local function placePage(p)
    p:ClearAllPoints()
    if p.expanded then
        p:SetPoint("TOPLEFT", p:GetParent(), "TOPLEFT", -5, 0)
        p:SetSize(EXPANDED[1], EXPANDED[2])
        -- WIRE (Astra's review of round 5): above the messages pane's frames (levels 4-9, panels/messages), as 4a appends
        -- the expanded pane to BackPane's layer last (HierList.cpp:93/103, drawn and asked after it): its rows, cells
        -- and the wheel over them are the pane's, not the messages lists' under it, so a press picks the slot 4a's would.
        -- Its empty places take no press, which goes on to the messages pane, as 4a's declined events do.
        p:SetFrameLevel(EXPANDED_LEVEL)
    else
        p:SetAllPoints(p:GetParent())
        p:SetFrameLevel(p:GetParent():GetFrameLevel() + 1)
    end
    p.dx = p.expanded and 5 or 0
    for _, b in ipairs(p.buttons or {}) do b.Draw() end
end

--- A pane's background: its compact picture at (0, 0), or expanded ITEMINVE.EPF frame n (ITEMINV.PAL) at (0, 0) but for
--- its 5 left columns down the tab header's 287 rows, which 4a's frame layer covers (AboveFrame's TABS.EPF at (808, 79),
--- over the expanded pane's x 827-831): the screen's tab header piece shows there. Drawing only.
local function paneBack(p, file, frame)
    p.backLow = p.backLow or p:CreateTexture(nil, "BACKGROUND")
    if not p.expanded then
        p.backLow:Hide()
        p.back:SetTexCoord(0, 1, 0, 1)
        S.Picture(p, p.back, file, frame, "ITEMINV.PAL", 0, 0, "BACKGROUND")
        return
    end
    local key, w, h = TK.Art.Image("ITEMINVE.EPF", frame, "ITEMINV.PAL")
    if not key then p.back:Hide() p.backLow:Hide() return end
    local ox, oy = TK.Art.Origin(key)
    --- the picture's part over the page's (l, t)-(r, b)
    local function part(tex, l, t, r, b)
        local x0, y0, x1, y1 = math.max(l, ox), math.max(t, oy), math.min(r, ox + w), math.min(b, oy + h)
        if x1 <= x0 or y1 <= y0 then tex:Hide() return end
        tex:SetTexture(key)
        tex:SetVertexColor(1, 1, 1, 1)
        tex:SetTexCoord((x0 - ox) / w, (x1 - ox) / w, (y0 - oy) / h, (y1 - oy) / h)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", p, "TOPLEFT", x0, -y0)
        tex:SetSize(x1 - x0, y1 - y0)
        tex:Show()
    end
    part(p.back, 5, 0, EXPANDED[1], HEADER_ROWS)
    part(p.backLow, 0, HEADER_ROWS, EXPANDED[1], EXPANDED[2])
end

--- ToggleExpandedMode: the pane grows or shrinks, its Expand button's picture 4 or 3 (Shrink); the items' and spells' list
--- back to its top (the group's kept); nothing sent.
local function toggleExpanded(p)
    p.expanded = not p.expanded
    if p.resetOnToggle then p.first = 0 end
    p.expand.picture = p.expanded and 3 or 4
    placePage(p)
    C:Refresh()
end

-- ----- the items (NewInventoryPane) -----

local ROWS, CELLS = 13, 15
local ROWS_EXPANDED, CELLS_EXPANDED = 26, 27

local function buildItems(f)
    local p = CreateFrame("Frame", "TK7xSideItems", f)
    p:SetAllPoints(f)
    p:EnableMouseWheel(true)
    p.first, p.grid, p.resetOnToggle = 0, false, true
    p.back = p:CreateTexture(nil, "BACKGROUND")
    p.drop = p:CreateTexture(nil, "BORDER")
    -- NewInventoryPane::OnPaint (0x004EBB20) keeps both grid fills at once.
    -- These passive regions draw behind the items; shared slot controls own input.
    p.selected = p:CreateTexture(nil, "BORDER")
    p.rows, p.cells = {}, {}
    p.dragLabel = DragLabel.New(p, S, 1)
    p.dragLabel.onChange = function() C:Refresh() end -- the press's selection paint (pressed)
    local function slotControl(name)
        local b = CreateFrame("Button", name, p)
        b.icon = p:CreateTexture(nil, "ARTWORK")
        b.letter, b.letter2, b.name = text(p), text(p), text(p)
        -- the slot's input path whole (the game layer's): a press, drag, double press or menu here sends what it sends in
        -- every interface
        Inv.SlotControl(b, { help = function(slot) Inv.ShowHelp(ItemBox, p, slot) end,
            tooltip = function() end, leave = function() end }) -- G2: original right-press help, no menu
        b:HookScript("OnEnter", function() p.over = b C:Refresh() end)
        b:HookScript("OnLeave", function() if p.over == b then p.over = nil C:Refresh() end end)
        b:Hide()
        return b
    end
    -- 27 rows and 27 cells, the compact pane using the first 13 and 15; expanded the 27th row is pressed but never drawn
    -- (the hit test runs to row 27, the paint to 26: InventoryPane.cpp:1190-1224 against :649-748)
    for n = 1, ROWS_EXPANDED + 1 do
        local b = slotControl("TK7xItemRow" .. n)
        -- the row's hit rectangle (2, 16 + 20n)-(160, 36 + 20n)
        b:SetPoint("TOPLEFT", p, "TOPLEFT", 2, -(16 + 20 * (n - 1)))
        b:SetSize(158, 20)
        -- BuildInventorySlotOrigin 0x004EE4F0: paint follows the row's pen,
        -- including the expanded pane's +5. The hit/action stays this control's.
        p.dragLabel:Attach(b, function() return "list", 15 + (p.dx or 0), 30 + 20 * (n - 1) end)
        p.rows[n] = b
    end
    for n = 1, CELLS_EXPANDED do
        local b = slotControl("TK7xItemCell" .. n)
        local c, r = (n - 1) % 3, math.floor((n - 1) / 3)
        -- the cell's hit rectangle (9 + 51c, 18 + 51r)-(57 + 51c, 66 + 51r)
        b:SetPoint("TOPLEFT", p, "TOPLEFT", 9 + 51 * c, -(18 + 51 * r))
        b:SetSize(48, 48)
        p.dragLabel:Attach(b, function() return "grid", 12 + 51 * c + (p.dx or 0), 21 + 51 * r end)
        p.cells[n] = b
    end
    -- the slots' actions reach these controls too (TK.Game.Inventory.UpdateActions)
    Inv.HelpOwner(p, Hud.HelpLine)
    Inv.Track(p.rows)
    Inv.Track(p.cells)
    -- the buttons (GetButtonRect): List, Grid, Mix and Expand
    p.buttons = {
        K.InvenButton(p, 168, 37, 185, 54, 0, function() p.grid, p.first = false, 0 C:Refresh() end),
        K.InvenButton(p, 168, 55, 185, 72, 1, function() p.grid, p.first = true, 0 C:Refresh() end),
    }
    -- Mix runs the dialog model's opener on its press (the pane's button 2; Shift+I's action)
    p.mix = K.InvenButton(p, 168, 80, 185, 97, 2, Inv.Mix)
    Inv.MixControl(p.mix)
    p.expand = K.InvenButton(p, 168, 99, 185, 116, 4, function() toggleExpanded(p) end)
    table.insert(p.buttons, p.mix)
    table.insert(p.buttons, p.expand)
    p.bar = K.ScrollBar(p, 169, 122, 267, function(pos) p.first = pos C:Refresh() end) -- s6-modular-g round 22
    -- the wheel moves the list a row (ScrollablePane: one step a notch)
    p:SetScript("OnMouseWheel", function(_, delta)
        p.first = p.first - delta
        C:Refresh()
    end)
    -- no carry outlives the page (as the bag window's closing ends one)
    Inv.EndCarryOnHide(p)
    return p
end

local function showItems(p)
    local dx = p.dx or 0
    local count = math.min(52, H:GetItemSlotCount())
    -- compact: the slots that hold an item; expanded: every slot 1..the slot count (InventoryPane.cpp:649-837)
    local list = {}
    if p.expanded then
        for slot = 1, count do list[slot] = slot end
    else
        list = Inv.HeldSlots()
    end
    local per = p.grid and (p.expanded and CELLS_EXPANDED or CELLS) or (p.expanded and ROWS_EXPANDED or ROWS)
    local step = p.grid and 3 or 1
    local range = math.max(0, math.ceil((#list - per) / step))
    if p.expanded then
        -- the list's range is the slot count less 26; the grid's (count + 2) / 3 less 9 (UpdateRenderRegion)
        range = p.grid and math.max(0, math.floor((count + 2) / 3) - 9) or math.max(0, count - ROWS_EXPANDED)
    end
    p.first = math.max(0, math.min(p.first, range))
    paneBack(p, "ITEMINV.EPF", p.grid and 0 or 1)
    local held = carried() or pressed(p) -- 4a's selection: the carry, or a held press before the drag starts
    p.drop:Hide()
    p.selected:Hide()
    -- s6-modular-g (round 14 fix, Astra P1): the other layout's controls hide; this layout's are updated in place, each
    -- shown while it holds an item. This refresh runs from a control's own OnEnter, and hiding the control under the
    -- pointer takes the pointer's focus from it (UIHost.OnFrameShownChanged), so its press reached no control: no use,
    -- carry or drag, and nothing sent where Modern's bag sends (the slot's input path, TK.Game.Inventory.SlotControl).
    local controls = p.grid and p.cells or p.rows
    for _, b in ipairs(p.grid and p.rows or p.cells) do b:Hide() b.icon:Hide() b.letter:Hide() b.letter2:Hide() b.name:Hide() end
    -- the 27th list row is pressed while expanded, never drawn
    local pressed = (p.expanded and not p.grid) and per + 1 or per
    for n = 1, #controls do
        local slot = n <= pressed and list[p.first * step + n] or nil
        local b = controls[n]
        b.slot = slot
        b:SetShown(slot ~= nil)
        b.icon:Hide() b.letter:Hide() b.letter2:Hide() b.name:Hide()
        if slot and n <= per then
            local _, name, count, _, iconId, colour, quantityPrompt = H:GetItemSlot(slot)
            local holds = name ~= nil
            local letter = H:SlotLetter(slot)
            local k = n - 1
            -- the drop target: a slot holding an item under the pointer while another is selected
            local target = held and p.over == b and slot ~= held and holds
            if p.grid then
                -- a cell at (12 + 51c, 21 + 51r), 43 x 43: the picture at its size, centred; the letter at the pen
                -- (x, y + 11) and again a pixel right, in 0x80; the drop target filled 0x8A, the selected one 0x84
                local x, y = 12 + 51 * (k % 3) + dx, 21 + 51 * math.floor(k / 3)
                if target or slot == held then
                    local fill = target and p.drop or p.selected
                    fill:ClearAllPoints()
                    fill:SetPoint("TOPLEFT", p, "TOPLEFT", x, -y)
                    fill:SetSize(43, 43)
                    S.Fill(fill, target and 0x8A or 0x84)
                    fill:Show()
                end
                -- 4a NewInventoryPane::OnPaint (0x004EBB20) gives the item renderer
                -- a 43 x 43 source area and the retained iconStyle colour; list rows
                -- and held labels keep the full item. This changes paint only.
                if holds then S.Item(b.icon, p, iconId, x + 21, y + 21, 1, 43, colour) end
                S.PenText(b.letter, p, letter, x, y + 11, S.TEXT)
                S.PenText(b.letter2, p, letter, x + 1, y + 11, S.TEXT)
            else
                -- a row from the pen (15, 30 + 20n): the half-size picture centred on (21, 24 + 20n); "%c  " in 0x80 at x 40,
                -- then in colour 1 at x 39; the name after it in 0x8F (0x8A while selected), cut to 102 pixels; the drop
                -- target's bar (51, 15 + 20n)-(153, 33 + 20n) in 0x86; an empty slot its letter alone
                local y = 30 + 20 * k
                if target then
                    p.drop:ClearAllPoints()
                    p.drop:SetPoint("TOPLEFT", p, "TOPLEFT", 51 + dx, -(15 + 20 * k))
                    p.drop:SetSize(102, 18)
                    S.Fill(p.drop, 0x86)
                    p.drop:Show()
                end
                if holds then S.Item(b.icon, p, iconId, 21 + dx, 24 + 20 * k, 0.5, nil, colour) end
                S.PenText(b.letter, p, letter .. "  ", 40 + dx, y, S.TEXT)
                local x = S.PenText(b.letter2, p, letter .. "  ", 39 + dx, y, 1)
                if holds then
                    -- 4a NewInventoryPane::OnPaint (0x004EBB20) uses ...(count) only
                    -- for a truncated prompted name; fitting names stay whole. Paint only:
                    -- ItemRules retains all drop/give input, packet and wait behavior.
                    local suffix = quantityPrompt and string.format("...(%d)", count) or "..."
                    S.PenText(b.name, p, S.Cut(name, 102, suffix), x, y, slot == held and 0x8A or 0x8F)
                end
            end
        end
    end
    if p.expanded then
        p.bar:Draw(p.first, range, 174, 122, 537)
    else
        p.bar:Draw(p.first, range)
    end
    Inv.UpdateActions()
end

-- ----- the spells (NewSpellInventoryPane) -----

local function buildSpells(f)
    local p = CreateFrame("Frame", "TK7xSideSpells", f)
    p:SetAllPoints(f)
    p:EnableMouseWheel(true)
    p.first, p.resetOnToggle = 0, true
    p.back = p:CreateTexture(nil, "BACKGROUND")
    p.drop = p:CreateTexture(nil, "BORDER")
    p.rows = {}
    p.dragLabel = DragLabel.New(p, S, 1)
    p.dragLabel.onChange = function() C:Refresh() end -- the press's selection paint (pressed)
    -- 27 rows (the compact pane uses 13); the 27th is pressed while expanded, never drawn
    for n = 1, ROWS_EXPANDED + 1 do
        -- the row's hit rectangle (2, 16 + 20n)-(170, 36 + 20n)
        local b = hit(p, 2, 16 + 20 * (n - 1), 170, 36 + 20 * (n - 1), "TK7xSpellRow" .. n)
        b.letter, b.letter2, b.name = text(p), text(p), text(p)
        TK.Actions:SetPath(b, "spellbook")
        -- the book cell's input path whole (the game layer's): its casts, drags and drops send what the book's send
        Spells.CellControl(b)
        -- BuildSpellRowOrigin 0x0057E960: the label starts at the row's native origin.
        p.dragLabel:Attach(b, function() return "spell", 12 + (p.dx or 0), 19 + 20 * (n - 1) end)
        b:HookScript("OnEnter", function() p.over = b C:Refresh() end)
        b:HookScript("OnLeave", function() if p.over == b then p.over = nil C:Refresh() end end)
        b:Hide()
        p.rows[n] = b
    end
    p.expand = K.InvenButton(p, 168, 37, 185, 54, 4, function() toggleExpanded(p) end)
    p.buttons = { p.expand }
    p.bar = K.ScrollBar(p, 169, 57, 267, function(pos) p.first = pos C:Refresh() end) -- s6-modular-g round 22
    p:SetScript("OnMouseWheel", function(_, delta)
        p.first = p.first - delta
        C:Refresh()
    end)
    return p
end

local function showSpells(p)
    local dx = p.dx or 0
    -- compact: the slots that hold a spell, 13 rows; expanded: the 52 slots, 26 rows (range 26)
    local list = {}
    if p.expanded then
        for slot = 1, 52 do list[slot] = slot end
    else
        list = Spells.HeldSlots()
    end
    local per = p.expanded and ROWS_EXPANDED or ROWS
    local range = math.max(0, #list - per)
    p.first = math.max(0, math.min(p.first, range))
    paneBack(p, "SPELLINV.EPF", p.expanded and 2 or 0)
    local held = TK.Cursor:Get()
    -- 4a's selection: the book's carry, or a held press before the drag starts
    local from = held and held.kind == "spell" and held.from == "book" and held.slot or pressed(p)
    p.drop:Hide()
    local pressed = p.expanded and per + 1 or per
    for n, b in ipairs(p.rows) do
        local slot = n <= pressed and list[p.first + n] or nil
        b.slot = slot
        b:SetShown(slot ~= nil)
        b.letter:Hide()
        b.letter2:Hide()
        b.name:Hide()
        if slot then
            local _, name = H:GetSpellSlot(slot)
            local letter = H:SlotLetter(slot)
            local k = n - 1
            if n <= per then
                -- the pen at y 31 + 20n: the letter in 0x80 at x 13, then in colour 1 at x 12; the name from x 37 in 0x80
                -- (0x8A while selected), cut to 123 pixels (expanded 118); the drop target filled 0x8A at
                -- (29, 15 + 20n)-(165, 34 + 20n) (expanded an empty slot too: SpellInventoryPane.cpp:544-626)
                if from and p.over == b and slot ~= from and (name or p.expanded) then
                    p.drop:ClearAllPoints()
                    p.drop:SetPoint("TOPLEFT", p, "TOPLEFT", 29 + dx, -(15 + 20 * k))
                    p.drop:SetSize(136, 19)
                    S.Fill(p.drop, 0x8A)
                    p.drop:Show()
                end
                S.PenText(b.letter, p, letter, 13 + dx, 31 + 20 * k, S.TEXT)
                S.PenText(b.letter2, p, letter, 12 + dx, 31 + 20 * k, 1)
                if name then
                    S.PenText(b.name, p, S.Cut(name, p.expanded and 118 or 123), 37 + dx, 31 + 20 * k,
                        slot == from and 0x8A or S.TEXT)
                end
            end
            Spells.SetCellAction(b, held)
        else
            TK.Actions:Clear(b)
        end
    end
    if p.expanded then
        p.bar:Draw(p.first, range, 174, 57, 537)
    else
        p.bar:Draw(p.first, range)
    end
end

-- ----- the group (NewGroupPane) -----

--- A member's bar: BAR.EPF's (S.Bar) right-anchored at right, MulDiv(39, cur, max) pixels long (NewGroupPane::OnPaint).
local function groupBar(p, parts, frames, right, y, cur, max)
    local w = (max and max > 0) and math.floor(39 * math.min(cur, max) / max + 0.5) or 0
    S.Bar(p, parts, frames, right, y, w)
end

--- "%d%%" right-aligned with its last cell ending at right: 9X11FONT's digits (variant 2), FONTSYMB.EPF's '%' (frame 1).
local function percent(p, row, key, right, y, value)
    local s = tostring(value)
    local x = right - 9 * (#s + 1)
    row[key] = S.Number(p, s, 2, x, y, row[key])
    -- in FONTSYMB.PAL, as NewGroupPane::DrawNumberString (0x0056E6D0) draws it (round 7: BARAM.PAL scrambled its colours)
    row[key .. "Sign"] = S.Picture(p, row[key .. "Sign"], "FONTSYMB.EPF", 1, "FONTSYMB.PAL", x + 9 * #s, y, "ARTWORK")
end

local GROUP_ROWS, GROUP_ROWS_EXPANDED = 6, 12

local function buildGroup(f)
    local p = CreateFrame("Frame", "TK7xSideGroup", f)
    p:SetAllPoints(f)
    p:EnableMouseWheel(true)
    p.first = 0
    p.back = p:CreateTexture(nil, "BACKGROUND")
    p.rows = {}
    for i = 1, GROUP_ROWS_EXPANDED do
        local row = { hp = {}, mp = {} }
        row.back = p:CreateTexture(nil, "BORDER")
        row.head = p:CreateTexture(nil, "ARTWORK") -- s6-interface-7x-b (round 7): the member's portrait
        row.name, row.name2 = text(p), text(p)
        p.rows[i] = row
    end
    p.expand = K.InvenButton(p, 168, 37, 185, 54, 4, function() toggleExpanded(p) end)
    p.buttons = { p.expand }
    p.bar = K.ScrollBar(p, 169, 60, 270, function(pos) p.first = pos C:Refresh() end) -- s6-modular-g round 22
    -- the wheel a member a notch (NewGroupPane's ScrollPane); nothing sent
    p:SetScript("OnMouseWheel", function(_, delta)
        p.first = p.first - delta
        C:Refresh()
    end)
    return p
end

local function showGroup(p)
    local dx = p.dx or 0
    -- the group panes' list (the game layer's, TK.Game.Social.GroupMembers): every member of the last 0x63 02 in its
    -- order, the player's own record included, as NewGroupPane lists them
    local members = TK.Game.Social.GroupMembers()
    local count = #members
    local per = p.expanded and GROUP_ROWS_EXPANDED or GROUP_ROWS
    local range = math.max(0, count - per)
    p.first = math.max(0, math.min(p.first, range))
    paneBack(p, "GROUP.EPF", p.expanded and 3 or 0)
    for i, row in ipairs(p.rows) do
        row.back:Hide()
        row.head:Hide()
        row.name:Hide()
        row.name2:Hide()
        for _, set in ipairs({ row.hp, row.mp }) do for _, t in pairs(set) do t:Hide() end end
        for _, key in ipairs({ "hpText", "mpText" }) do
            for _, t in ipairs(row[key] or {}) do t:Hide() end
            if row[key .. "Sign"] then row[key .. "Sign"]:Hide() end
        end
        local m = i <= per and members[p.first + i] or nil
        if m then
            local name, hp, hpMax, mp, mpMax, id, active = m.name, m.hp, m.hpMax, m.mp, m.mpMax, m.id, m.active
            local k = i - 1
            -- the member's row (6, 14 + 44i) on GROUPCOL.EPF; the name in (67, 18 + 44i)-(167, 32 + 44i), twice a pixel
            -- apart, in 12 for an active member (63 02's byte), else 0x8F
            S.Picture(p, row.back, "GROUPCOL.EPF", 0, "GROUPCOL.PAL", 6 + dx, 14 + 44 * k, "BORDER")
            local colour = active and 12 or 0x8F
            S.PenText(row.name, p, name or "", 67 + dx, 30 + 44 * k, colour)
            S.PenText(row.name2, p, name or "", 68 + dx, 30 + 44 * k, colour)
            -- s6-interface-7x-b (round 7): the portrait, painted at NewGroupPane's place on a canvas from the row's origin
            -- ("member-pane": PaneFigures.GroupHead), drawn after the row's band and unclipped; the next row's band, which
            -- 4a draws over it (mode 0, every pixel), cuts it at that band's top (58 from this row's origin)
            local key, w, h = H:GetFigure("member-pane", id or 0)
            if key ~= "" and w > 0 and h > 0 then
                local below = i < per and members[p.first + i + 1] ~= nil
                local shown = below and math.min(h, 58) or h
                row.head:SetTexture(key)
                row.head:SetTexCoord(0, 1, 0, shown / h)
                row.head:SetSize(w, shown)
                row.head:ClearAllPoints()
                row.head:SetPoint("TOPLEFT", p, "TOPLEFT", dx, -44 * k)
                row.head:Show()
            end
            -- the bars and their percentages only while the member's vita is not 0 (band y 34 + 44i): vita x 70-109,
            -- mana x 116-155, each right-anchored, MulDiv(39, cur, max); "%d%%" ending 2 left of the bar's right, at y 37
            if (hp or 0) ~= 0 then
                groupBar(p, row.hp, { 0, 1, 2 }, 109 + dx, 34 + 44 * k, hp, hpMax)
                groupBar(p, row.mp, { 3, 4, 5 }, 155 + dx, 34 + 44 * k, mp, mpMax)
                percent(p, row, "hpText", 107 + dx, 37 + 44 * k, hpMax > 0 and math.floor(100 * hp / hpMax) or 0)
                percent(p, row, "mpText", 153 + dx, 37 + 44 * k, mpMax > 0 and math.floor(100 * mp / mpMax) or 0)
            end
        end
    end
    if p.expanded then
        p.bar:Draw(p.first, range, 174, 60, 540)
    else
        p.bar:Draw(p.first, range)
    end
end

-- ----- the collection (CollectionPane) -----

local VOLUMES = 5

local function buildCollection(f)
    local p = CreateFrame("Frame", "TK7xSideCollection", f)
    p:SetAllPoints(f)
    p:EnableMouseWheel(true)
    p.first = 0
    p.back = S.Picture(p, nil, "CLTINV.EPF", 0, "ITEMINV.PAL", 0, 0, "BACKGROUND")
    p.rows = {}
    for s = 1, VOLUMES do
        local k = s - 1
        -- the volume's row (6, 14 + 50s)-(161, 62 + 50s)
        local row = hit(p, 6, 14 + 50 * k, 161, 62 + 50 * k, "TK7xCollectionVolume" .. s)
        row.back = p:CreateTexture(nil, "BORDER")
        row.glow = {}
        for g = 1, 12 do row.glow[g] = text(p) end
        row.name, row.name2, row.percent, row.percent2, row.count, row.count2 = text(p), text(p), text(p), text(p), text(p), text(p)
        -- a press opens the volume's album, or asks for it first (27 00 01): the collection dialog's opener, which applies
        -- Simple Click (the press) or the double press itself (CollectionPane::HandlePointerOrMouseEvent; DialogRules)
        row:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" and TK.Dialogs and row.index then TK.Dialogs.Open("CollectionDialogPane", 0, tostring(row.index)) end
        end)
        row:Hide()
        p.rows[s] = row
    end
    p.bar = K.ScrollBar(p, 169, 27, 267, function(pos) p.first = pos C:Refresh() end) -- s6-modular-g round 22
    p:SetScript("OnMouseWheel", function(_, delta)
        p.first = p.first - delta
        C:Refresh()
    end)
    -- the page list comes some time after its request (12 00 00), and records change the counts (12 00 02):
    -- TK_COLLECTION_UPDATE (C:OnEnable's events), in the packets' order with the input, so a press after the list came
    -- opens the volume 4a's would (round 14 fix)
    return p
end

local function showCollection(p)
    local pages = H:GetCollection()
    local range = math.max(0, #pages - VOLUMES)
    p.first = math.max(0, math.min(p.first, range))
    for s, row in ipairs(p.rows) do
        local i = p.first + s
        local v = pages[i]
        row.index = v and (i - 1) or nil
        row:SetShown(v ~= nil)
        row.back:Hide()
        for _, t in ipairs(row.glow) do t:Hide() end
        for _, key in ipairs({ "name", "name2", "percent", "percent2", "count", "count2" }) do row[key]:Hide() end
        if v then
            local k = s - 1
            local collected, total = v[2], v[3]
            local pct = total > 0 and math.floor(100 * collected / total) or 0
            local done = pct >= 100
            -- CLTLIST.EPF frame percent / 100 (1 when complete); the name in (61, 20 + 50s): glowing 0x80 round it when
            -- complete, then twice in 0x8F; "%d %%" at (61, 44 + 50s) in 0x8F (again twice in 0x0E when complete);
            -- "%d/%d" from 161 - 6 (length + 2) in 0x8F (again twice in 0x25 when complete)
            S.Picture(p, row.back, "CLTLIST.EPF", done and 1 or 0, "CLTLIST.PAL", 6, 14 + 50 * k, "BORDER")
            local name = v[4] ~= "" and v[4] or ("Volume " .. v[1])
            local y = 32 + 50 * k
            if done then
                local g = 0
                for dx = -1, 1 do
                    for dy = -1, 2 do
                        g = g + 1
                        S.PenText(row.glow[g], p, name, 61 + dx, y + dy, S.TEXT)
                    end
                end
            end
            S.PenText(row.name, p, name, 61, y, 0x8F)
            S.PenText(row.name2, p, name, 61, y, 0x8F)
            local pctText = string.format("%d %%", pct)
            S.PenText(row.percent, p, pctText, 61, 44 + 50 * k, 0x8F)
            S.PenText(row.percent2, p, pctText, 61, 44 + 50 * k, done and 0x0E or 0x8F)
            local countText = string.format("%d/%d", collected, total)
            local cx = 161 - 6 * (#countText + 2)
            S.PenText(row.count, p, countText, cx, 44 + 50 * k, 0x8F)
            S.PenText(row.count2, p, countText, cx, 44 + 50 * k, done and 0x25 or 0x8F)
        end
    end
    p.bar:Draw(p.first, range)
end

-- ----- the panel -----

local SHOW = { items = showItems, spells = showSpells, self = Self.Show, look = Look.Show, group = showGroup,
               collection = showCollection, options = Options.Show }

-- What each page does when its tab becomes the active one (4a's AddToLayer and OnActivate): the self look's and the
-- look's views, the options' first page, the group's first member (NewGroupPane::OnActivate 0x0056CB80; its 2D 01 is the
-- page's request, which runs as it shows).
local ACTIVATE = {
    self = Self.Activate, look = Look.Activate, options = Options.Activate,
    group = function(p) p.first = 0 end,
}

function C:Refresh()
    local f = self.frame
    if not (f and f:IsShown()) then return end
    local tab = SP.TABS[SP.Active()]
    local page = tab and f.pages[tab]
    if page and page:IsShown() then TK.SafeCall(SHOW[tab], page) end
end

--- An opener's or the strip's switch to tab (a name), as GeneralPurposePanel::SwitchActiveTab: the game layer's
--- (TK.Game.SidePanel.Switch), refused for the tab already active; an accepted switch shows its page at once (C:FollowTab,
--- in the input that switched it). No press switches to the self look or another player's look (their 0x39 and 0x34 do)
--- or to the collection while its list has not come (TK.Game.SidePanel.Request: its page list does). True when this
--- panel draws the tab (every tab: s6-interface-7x-b round 5). Wire: which page shows, and when one is shown again,
--- decides which requests the press sends (s6-modular-g round 14 fix, Astra P2: the tab pressed next after a look or the
--- options is an accepted switch, so the group's page shown again sends its 2D 01, NewGroupPane::OnActivate 0x0056CB80).
--- Changing it changes what the server sees.
function C:ShowTab(tab)
    SP.Switch(tab)
    return self.frame ~= nil and self.frame.pages[tab] ~= nil
end

--- The game layer's tab switched to index (TK_SIDE_PANEL_TAB; -1: a new game screen, no tab; view: a 0x39's self-look
--- view): its page shows, activated (ACTIVATE), the others hide. In the input that switched it a page's request runs (the
--- group's 2D 01: NewGroupPane::OnActivate 0x0056CB80, on each accepted switch only); outside any input (the packets'
--- switches, which the UI takes before any input after their packet: UIHost.CatchUp) none does. The self look's and the
--- look's pages are shown again on each switch to them (a new 0x39 or 0x34), as 4a's SwitchPanelTab0WithClick
--- (0x005139B0) and SwitchPanelTab1WithClickAndStopTimer (0x005119B0) reach them whatever the active tab. Wire: changing
--- which page shows on which switch changes what the server sees.
function C:FollowTab(index, view)
    local f = self.frame
    if not f then return end
    local tab = SP.TABS[index]
    local page = tab and f.pages[tab]
    for id, other in pairs(f.pages) do if id ~= tab then other:Hide() end end
    if not page then return end
    if (tab == "self" or tab == "look") and page:IsShown() then page:Hide() end
    if ACTIVATE[tab] then ACTIVATE[tab](page, view) end
    page:Show()
    self:Refresh()
end

--- The collection tab's button or opener: the game layer's SwitchToCollectionTab (TK.Game.SidePanel.CollectionTab: its
--- 27 00 00 while the list has not come, else the switch; s6-interface-5x round 12 moved it there). True: this panel
--- draws the collection. Wire: as that function.
function C:CollectionTab()
    SP.CollectionTab()
    return true
end

--- The active tab's id, or nil.
function C:Active() return SP.TABS[SP.Active()] end

-- TabPane's buttons (BuildTabActionRect 0x004CFB20: x 2-20 of the strip, right and bottom exclusive) and what each does
-- (HandlePointerOrMouseEvent 0x004CFA10, through UserPane's helpers): 0 the self look (RequestLocalPlayerStatus: 2D 00),
-- 1 the items, 2 the spells, 3 the group, 4 the collection, 5 the options; sample 0x198 after the items', spells', group's
-- and options' switch, even a refused one. again: a double click's second press (type 2) runs it too.
local STRIP = {
    { 1, 46, "self", again = true },
    { 47, 93, "items", sound = true, again = true },
    { 95, 140, "spells", sound = true, again = true },
    { 142, 187, "group", sound = true },
    { 189, 234, "collection" },
    { 236, 281, "options", sound = true, again = true },
}
-- the requests the strip's presses carry, which the pages run when they become visible (TK.Game.Views' notes)
local STRIP_REQUEST = { self = "open:character", group = "open:group", collection = "open:collection" }

local function buildStrip(f)
    for i, def in ipairs(STRIP) do
        local b = CreateFrame("Button", "TK7xSideTab" .. i, f)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -def[1])
        b:SetSize(18, def[2] - def[1])
        -- s6-modular-g round 22: TabPane 0x004CFA10 handles only left presses;
        -- the double press goes on for Group/Collection. Changing this changes map packets.
        b:EnableMouse(false)
        b:SetClaimButtons("LeftButton")
        b:SetPassesDoubles(not def.again)
        if STRIP_REQUEST[def[3]] then TK.Actions:Set(b, STRIP_REQUEST[def[3]]) end
        -- Wire: the left press (type 1) runs the button; the second press of a double click (type 2) runs it again for
        -- the self, items, spells and options buttons only; no release does anything (TabPane::HandlePointerOrMouseEvent).
        b:SetScript("OnMouseDown", function(_, button, double)
            if button ~= "LeftButton" or (double and not def.again) then return end
            if def[3] == "self" then
                SP.Request("self") -- button 0: RequestLocalPlayerStatus alone, on each press; the 0x39 switches
            elseif def[3] == "collection" then
                C:CollectionTab() -- button 4: SwitchToCollectionTab
            else
                C:ShowTab(def[3])
            end
            if def.sound then TK.Game.Sound.PlayEffect(0x198) end
        end)
    end
end

--- Whether the panel shows now (in the world, switched on), so the bag, book, character, collection, group, look and
--- options openers show its pages.
function C:IsShowing() return self.frame ~= nil and self.frame:IsShown() end

-- The tab keys of the expanded panes (the classic keys 'i', '+' and 'f': TOGGLEBAG, TOGGLESPELLBOOK, TOGGLEGROUP). While
-- the items, spells or group tab is the active one, 4a's pane has the key before UserPane (each switch makes it BackPane's
-- last child: GeneralPurposePanel.cpp:84-86) and toggles its expanded mode (NewInventoryPane::HandleKeyOrTextEvent
-- InventoryPane.cpp:926-930, SpellInventoryPane.cpp:654-656, SelfLookPane.cpp:2840-2845): no switch, no sample, nothing
-- sent. The game layer's openers tell the key from the other ways to their tab (a spell prompt's ? opens the spells as
-- a switch): the commands pass key true to the provider's Show (TK.Game.Views.Toggle; s6-interface-5x round 12, in place
-- of wrapping the commands here). Wire: the key toggles instead of a refused switch, and the group key's page stays
-- shown, so its request (2D 01) does not run, as 4a's pane sends nothing.

--- PgUp and PgDn (delta -1 or 1) on the active tab (its HandleKeyOrTextEvent's 0x93 and 0x94, taken whatever they do):
--- the items' list by the rows it shows (13, 26 expanded; the grid's 5 or 9), the spells' by 13, the group's by 6, the
--- looks' views, the options' pages. Local: nothing sent. True when the tab took the keys.
function C:Page(delta)
    local tab = self:Active()
    local page = tab and self.frame.pages[tab]
    if not (page and page:IsShown()) then return false end
    if tab == "items" then
        local rows = page.grid and (page.expanded and 9 or 5) or (page.expanded and ROWS_EXPANDED or ROWS)
        page.first = math.max(0, page.first + delta * rows)
    elseif tab == "spells" then
        page.first = math.max(0, page.first + delta * ROWS)
    elseif tab == "group" then
        page.first = math.max(0, page.first + delta * GROUP_ROWS)
    elseif tab == "self" then
        return Self.Page(page, delta)
    elseif tab == "look" then
        return Look.Page(page, delta)
    elseif tab == "options" then
        return Options.Page(page, delta)
    else
        return false
    end
    self:Refresh()
    return true
end

--- The status key (S): taken while the self look is the active tab, its views cycling (Self.StatusKey: 4a's pane takes
--- 's' before UserPane's RequestLocalPlayerStatus, so nothing is sent); false otherwise (TK.Game.Views.StatusKey).
function C:StatusKey()
    if self:Active() ~= "self" or not self.frame.pages.self:IsShown() then return false end
    Self.StatusKey(self.frame.pages.self)
    return true
end

function C:OnEnable()
    local f = CreateFrame("Frame", "TK7xSide", UIParent)
    f:SetFrameStrata("LOW")
    f:SetFrameLevel(5) -- the base layer, over the backdrop
    f:SetSize(WIDTH, HEIGHT)
    -- s6-modular-g round 22: TabPane::HandlePointerOrMouseEvent (0x004CFA10)
    -- takes only tab presses; blank strip pixels and right/release events pass to MapPane
    -- (0x00507150). Changing this changes what the server sees there.
    f:EnableMouse(false)
    f:Hide()
    self:Own(f)
    self.frame = f
    local pane = CreateFrame("Frame", "TK7xSidePane", f)
    pane:SetPoint("TOPLEFT", f, "TOPLEFT", PANE_X, 0)
    pane:SetSize(WIDTH - PANE_X, HEIGHT)
    pane:EnableMouse(true) -- round 22: the page still takes its background, outside the map
    f.pane = pane
    f.pages = { items = buildItems(pane), spells = buildSpells(pane), self = Self.Build(pane), look = Look.Build(pane),
                group = buildGroup(pane), collection = buildCollection(pane), options = Options.Build(pane) }
    for _, page in pairs(f.pages) do page:Hide() end
    buildStrip(f)
    self.entry = Screen.Register(f, "7x.side", "7.x Side Panel", function() return self:DB().enabled == true end)
    -- the openers (TK.Game.Views, while this panel shows): every view's page is drawn here (s6-interface-7x-b round 5:
    -- the look, the self look's legend view and the options too); the items' and the group's keys play sample 0x198
    -- after the switch, as UserPane's helpers do; a tab the server opens (how "server": its 0x3E, a prompt's ?, whose
    -- notice plays its own) plays none here
    TK.Game.Views.Provide("7x.side", {
        views = { bag = "items", spellbook = "spells", character = "self", legend = "self", collection = "collection",
                  group = "group", look = "look", options = "options" },
        IsShowing = function() return self:IsShowing() end,
        Page = function(delta) return self:Page(delta) end,
        StatusKey = function() return self:StatusKey() end,
        Show = function(tab, _, how, key)
            -- s6-modular-g (round 14 fix, the head's S-key note; Astra's review of round 3). Wire: the status key (S) is
            -- UserPane's (UserPane.cpp:1546: RequestLocalPlayerStatus, 2D 00, no switch); while the self look is the
            -- active tab the key is the pane's (C:StatusKey, through TK.Game.Views.StatusKey, before this). The self look
            -- is active only once a 0x39 switched to it, so S before the answer asks again. An opener outside any input
            -- (0x3E's page, a right-click on oneself, whose rule sent its 2D 00) carries no request. Changing this changes
            -- what the server sees.
            if tab == "self" then
                if not SP.Is("self") then SP.Request("self") end
                return true
            end
            -- the look: its page is the 0x34's tab switch (TK.Game.SidePanel); Modern's look window stays shut
            if tab == "look" then return true end
            -- the collection key: SwitchToCollectionTab as the button (its request while the list has not come)
            if tab == "collection" then return self:CollectionTab() end
            -- s6-interface-7x-b (round 5): the tab's own key while it is the active tab toggles its pane (the header)
            local page = self.frame.pages[tab]
            if key and self:Active() == tab and page and page.expand then
                toggleExpanded(page)
                return true
            end
            local shown = self:ShowTab(tab)
            if shown and how == "input" and (tab == "items" or tab == "group") then TK.Game.Sound.PlayEffect(0x198) end
            return shown
        end,
    })
    local events = CreateFrame("Frame", nil, f)
    -- s6-modular-g (round 14 fix): the world's events come before any input after their packets (UIHost.CatchUp), so a
    -- press reaches the rows, cells and volumes 4a's pane had then (its slot, spell or volume is what the press sends)
    for _, e in ipairs({ "BAG_UPDATE", "SPELLS_CHANGED", "CURSOR_CHANGED", "UNIT_NAME_UPDATE", "GROUP_ROSTER_UPDATE",
                         "TK_GROUP_UPDATE", "UNIT_HEALTH", "UNIT_POWER", "UNIT_STATS", "TK_CHARACTER_SHEET",
                         "TK_COLLECTION_UPDATE" }) do
        events:RegisterEvent(e)
    end
    events:SetScript("OnEvent", function() self:Refresh() end)
    f:SetScript("OnShow", function() self:Refresh() end)
end

--- s6-interface-5x (round 12, build 46; the owner: another interface's panels that are off do nothing): the pages follow
--- the game layer's tab (C:FollowTab) only while the panel is on, so in a profile where it is off its pages neither show
--- nor hide (a hidden items page would end the cursor's carry, TK.Game.Inventory.EndCarryOnHide, and the options page
--- would tell the dialog rules it shows). Turned on (and at the start, by ReapplyAll after OnEnable), its pages take the
--- tab there is, outside any input: no page's request runs, nothing is sent. The head's review of round 11, P1: after a
--- UI reload the session's active tab (kept on the host) shows its page so. Wire: a press on the tab already active is
--- then refused as 4a's SwitchActiveTab (0x004B8650) refuses it, so Group sends no second 2D 01 (NewGroupPane::OnActivate
--- 0x0056CB80); starting from no tab, or not following the tab while on, changes what the server sees.
function C:Follow()
    local was = self.following
    self.following = self.frame ~= nil and self:DB().enabled == true
    if self.following and not was then self:FollowTab(SP.Active())
    elseif was and not self.following then
        -- Astra's wrap-up review: turned off, its options page hides by itself, as hiding the panel leaves the page's own
        -- shown flag set and fires no OnHide. Wire: its OnHide tells the dialog rules no options page shows, so a server
        -- 0x21 is no longer the options tab's modal alert (NewOptionPane::HandlePacketEvent 0x00540DB0, DialogRules
        -- OptionPageShown). The other pages stay, as the cursor's carry needs (TK.Game.Inventory.EndCarryOnHide).
        local options = self.frame.pages.options
        if options and options:IsShown() then options:Hide() end
    end
end

-- The group page's request (Modern's group page's kind), attached while the UI loads (plan 5.9); the status and
-- collection requests are the game layer's (TK.Game.SidePanel.Request): their answers show those pages.
TK.On("PLAYER_LOGIN", function()
    local f = C.frame
    if not f then return end
    TK.Actions:SetOpen(f.pages.group, "open:group")
end)

-- A new game screen starts with no tab (GeneralPurposePanel's constructor: the game layer's reset hides the pages,
-- C:FollowTab(-1)), its pages new: the items, spells and group compact, the items as their list (the panes'
-- constructors: InventoryPane.cpp:475, SpellInventoryPane.cpp:390, SelfLookPane.cpp:2507).
TK.On("TK_SESSION_STATE", function(_, state)
    if state ~= "Accepted" or not C.frame then return end
    for _, page in pairs(C.frame.pages) do
        if page.expand then
            page.expanded, page.first = false, 0
            page.expand.picture = 4
            placePage(page)
        end
    end
    C.frame.pages.items.grid = false
end)

-- The game layer's tab switches (TK_SIDE_PANEL_TAB): the packets', in the logic's order before any input after them (a
-- 0x39 the self look with its view, s6-interface-7x-b round 5: RuleNotice.PanelView; a 0x34 another player's look, with
-- sample 0x198 (SwitchPanelTab1WithClickAndStopTimer 0x005119B0); a collection page list; the server's 0x3E; a prompt's
-- ?: MapPane::HandlePacketEvent's and UserPane's switches); the openers' and the strip's, in their input; a new game
-- screen's -1. The active tab's page shows (C:FollowTab). Wire: their order and the pages they show decide what the next
-- press sends: 0x39 then 0x34 leaves the look, so S asks (2D 00) and the group tab's press sends 2D 01; 0x34 then 0x39
-- leaves the self look, which takes S. Changing their order or their timing changes what the server sees.
TK.On("TK_SIDE_PANEL_TAB", function(_, index, view)
    if not C.following then return end -- off: its pages stay as they are (C:Follow)
    C:FollowTab(index, view)
    if index == 1 and C:IsShowing() then TK.Game.Sound.PlayEffect(0x198) end
end)

--- At the original's place on the scaled 7.x screen (unless moved), at the screen's scale times its own; in the game only.
function C:Layout() Screen.PlacePanel(self, 1024, 768, PLACE[1], PLACE[2]) end

function C:ApplySettings() self:Follow() self:Layout() end
function C:OnSettingChanged() self:Follow() self:Layout() end

Screen.Follow(C, "Layout")
