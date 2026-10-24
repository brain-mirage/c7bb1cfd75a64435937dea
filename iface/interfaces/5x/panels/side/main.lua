-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md): 5.33's side panel,
-- GeneralPurposePanel (constructor 0x004355F0): one page at a time at (434, 12)-(626, 300) of the 640 x 480 screen
-- (SwitchActiveTab 0x00435790). Its pages, each drawn as 5.33's paint draws it:
--   items   NewInventoryPane (paint 0x0044FF00): ITEMINV.EPF; 15 items a page, of the slots that hold one, as a list
--           (the default: a half-size picture, "%c: " in colour 9 and the name in 0x25, 13-pixel rows from (30, 46)) or
--           as pictures (three a row, 45 x 41 apart from (40, 40)); the buttons under them: the page back and on, the
--           list and the pictures (SPELLBUT.EPF's frames over ITEMINV's own buttons mark the first and last page and
--           the view)
--   spells  NewSpellInventoryPane (paint 0x004A9A80): SPELLINV.EPF; 13 spells a page, "%c: %s" in 0x80, 13-pixel rows
--           from (22, 51); the page back and on
--   self    SelfLookPane (paint 0x0049D590), three views paged by its arrows (34, 254) and (137, 254) (cases 2 and 3 of
--           HandlePointerOrMouseEvent 0x0049E150; local, nothing sent):
--             0 the equipment (SELFLOOK.EPF's frame for the totem): 0x39's first three strings right-aligned at x 174
--               (CLAN, C.T., TITLE), its fifth and the player's name on the fourth row, the figure, the worn helm,
--               hands and sub-hands (slot codes 4, 7, 8, 20, 21), the exchange and group switches (LOOKBTN.EPF), and
--               the effects on the player in the box (17, 192)-(174, 251) (SpelledPane: 0x3A's names, a line each);
--               a press on a worn place takes off what its slot holds, an item or none, 7.5.2's gear slot (5.33's
--               pane has no such press)
--             1 the status (SELFLOK2.EPF): the group's text in the group list box (17, 36)-(174, 131)
--               (GroupListPane: 0x39's fourth string in 5.33; written from 7.5.2's roster, groupText), and
--               right-aligned at x 172 on y 155-250 the vita and mana maxima, 0x39's three summary bytes and its u32
--               (VITA, MANA, AC, DAM, HIT, NEXTLEV)
--             2 the legend (SELFLOK3.EPF): 0x39's marks in the box (17, 36)-(174, 251) (LegendPane), each its symbol
--               (SYMBOLS.EPF) and its text in its colour
--   look    UserLookPane (paint 0x004D22F0), the look at another player (S 0x34), the same three views: the equipment
--           (SELFLOOK.EPF at the frame 0x34's byte after its legend gives, as 5.33 from version 531; 0x34's first five
--           strings where the self look draws 0x39's, its more-info text in the bottom box, the trade and group
--           buttons), the profile (PFLOOK.EPF: the face at (72, 46)-(120, 102), the profile text in (17, 143)-(174, 251))
--           and the legend (SELFLOK3.EPF)
-- 4a keeps the first two panes' paints byte for byte (InventoryPane::OnPaint 0x004EA2A0, SpellInventoryPane::OnPaint),
-- so their numbers are read there as well.
--
-- Wire: what a press on them sends is the game layer's controls', 7.5.2's in every interface (s6-interface-5x round 12,
-- step 2: TK.Game.Inventory's slots, TK.Game.Spells' cells, TK.Game.SelfLook's switches and worn items,
-- TK.Game.Look's trade and group; the self page's 2D 00, TK.Game.Views.RequestPage); this draws 5.33's look over them.
-- Changing which control a page's button is changes what the server sees. The pages' own buttons only turn the page or change the view, as 5.33's do: nothing is sent;
-- PgUp and PgDn do the same for the page that shows (C:Page).
--
-- Which page shows: the items when the game screen starts; the bag key and the Items icon the items, the spell book
-- key, the Spells icon and a spell prompt's ? the spells, the character key, the Info icon and the server's 0x3E (D-77)
-- the self look (on the view 0x3E asked for), a look at another player (0x34) the look page; the group key and button
-- (7.5.2's tab 4, its 2D 01) the self look's status view with the group list (round 7, Y1: C:Show("group")).
--
-- s6-ui-core (round 85): the XML twin's scripts; the panel's frames, the pages' pictures, buttons, texts and boxes and
-- their places are main.xml's (core/xml.md), and so are the numbers the pages draw by (the rows, the cells, the worn
-- places, the lines).

local C = TK.GetComponent("5x.side")
local H = __tk
local S = require("interfaces.5x.skin")
local Screen = require("interfaces.screen")
local Inv, Spells, SelfLook = TK.Game.Inventory, TK.Game.Spells, TK.Game.SelfLook
local Bar = require("interfaces.5x.scrollbar") -- s6-interface-5x-b
local Help = require("interfaces.5x.help") -- s6-interface-5x-b
local ItemBox = require("interfaces.5x.itembox")
local Effects = require("interfaces.5x.sideeffects")
local DragLabel = require("interfaces.original.draglabel")
local E = require("interfaces.5x.elements")

local L = TK.Xml.Data("main.xml")
local ITEMS, SPELLS = L.ITEMS, L.SPELLS

-- the scripts main.xml names
local scripts = {}

-- ----- drawing helpers -----

--- A rectangle (l, t)-(r, b) of the page: a frame's place and size.
local function rect(frame, page, l, t, r, b)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", page, "TOPLEFT", l, -t)
    frame:SetSize(r - l, b - t)
end

--- A text drawn as 5.33's MoveTo(x, y) and DrawWideText draw it: the pen 12 below its line's top (font 0's line), the
--- string at the line's top + 1 (S.Text's convention). Returns the pen's x after it (5.33's text advances it).
local function textAt(fs, page, text, x, y, colour)
    S.Text(fs, colour)
    fs:SetWordWrap(false)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", page, "TOPLEFT", x, -(y - 12 + 1))
    fs:Show()
    return x + (S.TextWidth(text) or fs:GetStringWidth())
end

--- A text whose right end is at x (5.33's MoveTo(x - GetTextWidth(text), y)).
local function textRight(fs, page, text, x, y, colour)
    textAt(fs, page, text, x - (S.TextWidth(text) or fs:GetStringWidth()), y, colour)
end

--- An item's picture (ITEM.EPF frame iconId, the base set's) in a texture of the page, its whole frame's top left at
--- (x, y) at the given scale of the base set's picture (S.GAME_ART for 5.33's full size, half that for the list's
--- half-size pictures: the base set's art is twice 5.33's); hidden without it.
--- Retained item/equipment colours use the shared renderer and active panel's palette cycle.
local function itemPicture(tex, page, iconId, x, y, scale, colour)
    local key, w, h = TK.Art.Icon(iconId, colour)
    if not key then return tex:Hide() end
    local ox, oy = TK.Art.Origin(key)
    tex:SetTexture(key)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:SetSize(math.max(1, math.floor(w * scale)), math.max(1, math.floor(h * scale)))
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", page, "TOPLEFT", x + math.floor(ox * scale), -(y + math.floor(oy * scale)))
    tex:Show()
end

--- An item picture's whole frame as 5.33 measures its own art (GetItemGlyphBounds' width and height: the frame before
--- the texture's crop, the base set's at S.GAME_ART).
local function frameSize(iconId)
    local key = TK.Art.Icon(iconId)
    if not key then return 0, 0 end
    local ok, w, h = H:GetArtFrameSize(key)
    if ok then return math.floor(w * S.GAME_ART), math.floor(h * S.GAME_ART) end
    return 0, 0
end

--- SPELLBUT.EPF's frame over a button of the page (its markAt in main.xml: a button's first-page, last-page or chosen
--- view mark), or hidden.
local function mark(page, key, on)
    local at = page.markAt[key]
    if on then
        page.marks[key] = S.Picture(page, page.marks[key], "SPELLBUT.EPF", at.frame, "NPAL6.PAL", at.x, at.y, "BORDER")
    elseif page.marks[key] then
        page.marks[key]:Hide()
    end
end

--- A box of 5.33's text panes (TextEditPane at 145 pixels: SpelledPane, GroupListPane, LegendPane and the look's
--- texts): font 0 in 0x80, 12-pixel lines from its top, wrapped at 145; the box's right 13 pixels are its scroll bar,
--- ScrollablePane's skin 0 (s6-interface-5x-b: interfaces/5x/scrollbar.lua, over the page's picture of it): its arrows a
--- line, its track a page (TextEditPane__GetPageSize 0x004BEC40: the lines showing less one), its thumb dragged. The
--- wheel scrolls it a line at a time. box:Lines(list) shows one entry a line (each { text, colour, symbol }: a symbol of
--- SYMBOLS.EPF after a space, the text after it, as the legend's entries).
local function textBox(page, l, t, r, b)
    local clip = CreateFrame("ScrollFrame", nil, page)
    rect(clip, page, l, t, l + 145, b)
    local content = CreateFrame("Frame", nil, clip)
    content:SetSize(145, b - t)
    clip:SetScrollChild(content)
    local box = { clip = clip, content = content, height = b - t, rows = {}, offset = 0, total = 0 }
    local function row(i)
        local r0 = box.rows[i]
        if r0 then return r0 end
        r0 = { text = S.Text(content:CreateFontString(nil, "ARTWORK"), S.TEXT),
               symbol = content:CreateTexture(nil, "ARTWORK") }
        r0.text:SetWordWrap(true)
        r0.text:SetJustifyH("LEFT")
        box.rows[i] = r0
        return r0
    end
    --- Shows the entries from the top, the view kept within them.
    function box:Lines(list)
        local y = 0
        for _, r0 in ipairs(self.rows) do
            r0.text:Hide()
            r0.symbol:Hide()
        end
        for i, e in ipairs(list) do
            local r0 = row(i)
            local x = 0
            if e.symbol then
                -- " " and the 12 x 12 symbol (EPFTextEditObject 0x004C6F80: SYMBOLS.EPF's frame), then the text
                x = S.TextWidth(" ") or 3
                local key = TK.Art.Image("SYMBOLS.EPF", e.symbol, "BARAM.PAL")
                if key then
                    r0.symbol:SetTexture(key)
                    r0.symbol:SetSize(12, 12)
                    r0.symbol:ClearAllPoints()
                    r0.symbol:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
                    r0.symbol:Show()
                end
                x = x + 12
            end
            S.Text(r0.text, e.colour or S.TEXT)
            r0.text:SetWidth(145 - x)
            r0.text:SetText(e.text ~= "" and e.text or " ")
            r0.text:ClearAllPoints()
            r0.text:SetPoint("TOPLEFT", content, "TOPLEFT", x, -(y + 1))
            r0.text:Show()
            y = y + math.max(1, math.floor((r0.text:GetStringHeight() or 12) / 12 + 0.5)) * 12
        end
        self.total = y
        content:SetHeight(math.max(self.height, y))
        self:Scroll(0)
    end
    --- The lines it can scroll down (TextEditPane__GetScrollRange 0x004BEB30).
    function box:Range() return math.max(0, math.ceil((self.total - self.height) / 12)) end
    --- Scrolls n lines down (negative: up), within the entries.
    function box:Scroll(n)
        self.offset = math.max(0, math.min(self:Range(), self.offset + n))
        clip:SetVerticalScroll(self.offset * 12)
        if self.bar then self.bar:Refresh() end
    end
    -- s6-interface-5x-b: the bar, drawn and pressed as 5.33's (local: nothing sent)
    box.bar = Bar.New(page, r - Bar.Width(0), t, b, 0, {
        Range = function() return box:Range(), box.offset, math.floor(box.height / 12) - 1 end,
        Set = function(pos) box:Scroll(pos - box.offset) end,
    })
    function box:SetShown(on)
        clip:SetShown(on)
        self.bar.frame:SetShown(on)
    end
    clip:EnableMouseWheel(true)
    clip:SetScript("OnMouseWheel", function(_, delta) box:Scroll(delta > 0 and -1 or 1) end)
    return box
end

-- main.xml's elements: 5.x's (interfaces/5x/elements.lua) and the pages' text boxes, <textbox l t r b/> (textBox)
local elements = setmetatable({}, { __index = E })
function elements.textbox(page, a) return textBox(page, a.l, a.t, a.r, a.b) end

--- A text's lines (split at its line breaks, as 5.33's panes take a tab or a CR), one entry each.
local function linesOf(text)
    local list = {}
    for line in ((text or ""):gsub("\r\n?", "\n"):gsub("\t", "\n") .. "\n"):gmatch("(.-)\n") do
        list[#list + 1] = { text = line }
    end
    if #list > 1 and list[#list].text == "" then list[#list] = nil end
    return list
end

--- The group as 5.33's group list shows it (s6-interface-5x-b, round 8; decision 2026-10-05-5x-group-list-text): 5.33's
--- GroupListPane shows the server's text, 0x39's fourth string, which 5.33's server writes as "LEADER Group's [n/max]", a
--- rule, then a member a line ("NAME (W)"; the 5.33 server code, OSTK's clif_mystaytus). 7.5.2's server sends the group
--- as the 63 02 roster instead (its 0x39's fourth string is the partner line), so this writes 5.33's form from the roster:
--- the leader (the record whose flag is set, which the RTK server sets for the leader; else the first), the count, the
--- names in the roster's order. The roster carries no path and the client knows no maximum: no "(W)", no "/max". Nil with
--- no roster. Drawing only.
local function groupText()
    local n = H:GetNumGroupMembers()
    if n == 0 then return nil end
    local names, leader = {}, nil
    for i = 1, n do
        local _, name, _, _, _, _, _, active = H:GetGroupMember(i)
        names[i] = name or ""
        if active and not leader then leader = names[i] end
    end
    return string.format("%s Group's [%d]\n----------------------------\n%s", leader or names[1], n, table.concat(names, "\n"))
end

-- ----- the items (NewInventoryPane) -----

--- The drag label and the slots (ITEMS.page of them, main.xml's ITEMS), then their help and their actions.
function scripts.ItemSlots(p)
    local list, grid = ITEMS.list, ITEMS.grid
    p.dragLabel = DragLabel.New(p, S, S.GAME_ART, 0x25) -- this inventory's native list-name colour on black
    for i = 1, ITEMS.page do
        local b = CreateFrame("Button", "TK5xItemSlot" .. i, p)
        Inv.SlotControl(b, { help = function(slot) Inv.ShowHelp(ItemBox, p, slot) end,
            tooltip = function() end, leave = function() end }) -- G2: the single right press's local sheet
        -- Native paint follows this page's list pen or picture cell; shared 7.5.2
        -- selection/carry/drop handlers still decide every server-visible action.
        p.dragLabel:Attach(b, function()
            local k = i - 1
            if p.icons then
                return "grid", grid.x + grid.dx * (k % grid.columns), grid.y + grid.dy * math.floor(k / grid.columns)
            end
            return "list", list.x, list.y + list.step * k
        end)
        b:Hide()
        b.icon = p:CreateTexture(nil, "ARTWORK")
        b.letter = p:CreateFontString(nil, "OVERLAY")
        b.name = p:CreateFontString(nil, "OVERLAY")
        p.slots[i] = b
    end
    Inv.HelpOwner(p, Help)
    Inv.Track(p.slots) -- the slots' actions (TK.Game.Inventory.UpdateActions)
end

--- The items' and the spells' buttons back and on (main.xml's <press>, 5.33's case 1): the page turned, within the
--- pages; local, nothing sent.
function scripts.Back(p) if p.number > 0 then p.number = p.number - 1 C:Refresh() end end
function scripts.On(p) if not p.last then p.number = p.number + 1 C:Refresh() end end

--- The items' list and pictures buttons.
function scripts.ListView(p) p.icons = false C:Refresh() end
function scripts.PictureView(p) p.icons = true C:Refresh() end

--- No carry outlives the page (as the bag window's closing ends one).
function scripts.EndCarryOnHide(p) Inv.EndCarryOnHide(p) end

local function showItems(p)
    local list, n, LIST, GRID = Inv.HeldSlots(), ITEMS.page, ITEMS.list, ITEMS.grid
    local pages = math.max(1, math.ceil(#list / n))
    p.number = math.max(0, math.min(p.number, pages - 1))
    p.last = (p.number + 1) * n >= #list
    for i, b in ipairs(p.slots) do
        local slot = list[p.number * n + i]
        b.slot = slot
        b:SetShown(slot ~= nil)
        b.icon:Hide()
        b.letter:Hide()
        b.name:Hide()
        if slot then
            local _, name, _, _, iconId, colour = H:GetItemSlot(slot)
            local fw, fh = frameSize(iconId)
            local k = i - 1
            if p.icons then
                -- the pictures (GRID): three a row, each at pen.x - w / 2 + 6, pen.y - h / 2 - 6 of its cell's pen; its
                -- button the cell
                local cx, cy = GRID.x + GRID.dx * (k % GRID.columns), GRID.y + GRID.dy * math.floor(k / GRID.columns)
                local py = cy + GRID.pen
                itemPicture(b.icon, p, iconId, cx - math.floor(fw / 2) + 6, py - math.floor(fh / 2) - 6, S.GAME_ART, colour)
                rect(b, p, cx, cy, cx + GRID.size, cy + GRID.size)
            else
                -- the list (LIST): the pen down a row at a time; the half-size picture centred on (pen.x + 6,
                -- pen.y - 6), the letter and the name after it; its button (pen.x, pen.y - 12)-(right, pen.y + 1)
                local py = LIST.y + LIST.step * k
                local sx, sy = math.floor(fw / 2), math.floor(fh / 2)
                itemPicture(b.icon, p, iconId, LIST.x + 6 - math.floor(sx / 2), py - 6 - math.floor(sy / 2), S.GAME_ART / 2, colour)
                local x = textAt(b.letter, p, H:SlotLetter(slot) .. ": ", LIST.letter, py, LIST.letterColour)
                textAt(b.name, p, name, x, py, LIST.nameColour)
                rect(b, p, LIST.x, py - 12, LIST.right, py + 1)
            end
        end
    end
    mark(p, "back", p.number == 0)
    mark(p, "on", p.last)
    mark(p, "list", not p.icons)
    mark(p, "pictures", p.icons)
    Inv.UpdateActions()
end

-- ----- the spells (NewSpellInventoryPane) -----

--- The drag label and the rows (SPELLS.page of them, main.xml's SPELLS).
function scripts.SpellRows(p)
    p.dragLabel = DragLabel.New(p, S, S.GAME_ART)
    for i = 1, SPELLS.page do
        local b = CreateFrame("Button", "TK5xSpellRow" .. i, p)
        TK.Actions:SetPath(b, "spellbook")
        Spells.CellControl(b) -- the book cell's input path whole (the game layer's)
        local t = SPELLS.t + SPELLS.step * (i - 1)
        p.dragLabel:Attach(b, function() return "spell", SPELLS.penX, t end)
        b:Hide()
        rect(b, p, SPELLS.l, t, SPELLS.r, t + SPELLS.step)
        b.text = p:CreateFontString(nil, "OVERLAY")
        p.rows[i] = b
    end
end

local function showSpells(p)
    local list, n = Spells.HeldSlots(), SPELLS.page
    local pages = math.max(1, math.ceil(#list / n))
    p.number = math.max(0, math.min(p.number, pages - 1))
    p.last = (p.number + 1) * n >= #list
    for i, b in ipairs(p.rows) do
        local slot = list[p.number * n + i]
        b.slot = slot
        b:SetShown(slot ~= nil)
        if slot then
            local _, name = H:GetSpellSlot(slot)
            textAt(b.text, p, H:SlotLetter(slot) .. ": " .. name, SPELLS.penX, SPELLS.penY + SPELLS.step * (i - 1), S.TEXT)
        else
            b.text:Hide()
        end
    end
    mark(p, "back", p.number == 0)
    mark(p, "on", p.last)
    local held = TK.Cursor:Get()
    for _, b in ipairs(p.rows) do
        if b.slot then Spells.SetCellAction(b, held) else TK.Actions:Clear(b) end
    end
end

-- ----- the self look and the look (SelfLookPane, UserLookPane): three views each -----

-- The worn items both equipment views draw (main.xml's WORN, by their record in 7.5.2's order), each place also the self
-- look's take-off control; the two buttons by the figure (main.xml's BUTTONS).
local WORN, BUTTONS = L.WORN, L.BUTTONS

--- The two buttons' faces and places (BUTTONS), made after the equipment view's own parts (main.xml).
function scripts.ButtonFaces(p)
    for _, b in ipairs(p.buttons) do
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints(b)
    end
    for i, def in ipairs(BUTTONS) do rect(p.buttons[i], p, def.rect[1], def.rect[2], def.rect[3], def.rect[4]) end
end

--- The views' arrows (main.xml's <press>), as 5.33's cases 2 and 3: view 0 -> 1 -> 2 and back; local, nothing sent.
function scripts.ViewBack(p) if p.view > 0 then p.view = p.view - 1 C:Refresh() end end
function scripts.ViewOn(p) if p.view < 2 then p.view = p.view + 1 C:Refresh() end end

--- The figure and the buttons' states change with the look and the logic thread: a look four times a second (a throttle
--- of its own for each page).
function scripts.Ticker(p) p:SetScript("OnUpdate", TK.Util.Throttled(0.25, function() C:Refresh() end)) end

--- An equipment view: the lines right-aligned at main.xml's LINES, the figure (figure key) centred on FIGURE, the worn
--- items by record (worn(i): the icon of record i, nil for none, and its
--- slot code), the buttons by their states. A page with take-off controls (p.takeOff) puts each over its place. The
--- figure and the items are the base set's pictures at S.GAME_ART, the size 5.33's own art has in its pane.
local function showEquipment(p, lines, figureKind, worn, states)
    for i, at in ipairs(L.LINES) do textRight(p.lines[i], p, lines[i] or "", at.x, at.y, S.TEXT) end
    local key, w, h = H:GetFigure(figureKind, 0)
    if key ~= "" and w > 0 then
        -- 5.33 centres the figure's box on FIGURE (main.xml's note)
        local bw, bh, at = math.floor(w * S.GAME_ART), math.floor(h * S.GAME_ART), L.FIGURE
        p.figure:SetTexture(key)
        p.figure:SetSize(w * S.GAME_ART, h * S.GAME_ART)
        p.figure:ClearAllPoints()
        p.figure:SetPoint("TOPLEFT", p, "TOPLEFT", at.x - math.floor(bw / 2), -(at.y - math.floor(bh / 2)))
        p.figure:Show()
    else
        p.figure:Hide()
    end
    -- the worn items: centred on their place by their whole frame (GetItemGlyphBounds); an empty place's control by
    -- WORN's empty box
    for i, def in ipairs(WORN) do
        local iconId, code, colour = worn(def.record)
        local b = p.takeOff and p.takeOff[i]
        local drawn = iconId and iconId >= 0
        local fw, fh = WORN.empty, WORN.empty
        if drawn then fw, fh = frameSize(iconId) end
        local left, top = def.x - math.floor(fw / 2), def.top and def.y or def.y - math.floor(fh / 2)
        if drawn then itemPicture(p.worn[i], p, iconId, left, top, S.GAME_ART, colour) else p.worn[i]:Hide() end
        if b then
            rect(b, p, left, top, left + fw, top + fh)
            -- s6-interface-5x (round 13, KNOWN J3): Wire: an empty place takes off too, its slot's 1F, as 4a's fixed
            -- slot box with no item test (S.TakeOff, SendTakeOffPacket 0x005B27C0). Changing this changes what the
            -- server sees.
            SelfLook.TakeOff(b, code)
            b:Show()
        end
    end
    for i, def in ipairs(BUTTONS) do
        local b, v = p.buttons[i], states[i]
        if v == 0 or v == 1 then
            b.tex:SetTexture(S.Image("LOOKBTN.EPF", v == 1 and def.on or def.off, "NPAL6.PAL") or "")
            b.tex:SetVertexColor(1, 1, 1, 1)
        else
            S.Fill(b.tex, S.WHITE)
        end
    end
end

--- What shows in a view and what not: the equipment view's parts in view 0, the boxes in theirs.
local function showView(p, parts)
    local equip = p.view == 0
    for _, fs in ipairs(p.lines) do fs:SetShown(equip and fs:IsShown()) end
    p.figure:SetShown(equip and p.figure:IsShown())
    for _, t in ipairs(p.worn) do t:SetShown(equip and t:IsShown()) end
    for _, b in ipairs(p.takeOff or {}) do b:SetShown(equip and b:IsShown()) end
    for _, b in ipairs(p.buttons) do b:SetShown(equip) end
    for view, list in pairs(parts) do
        for _, part in ipairs(list) do part:SetShown(view == p.view) end
    end
    for _, fs in ipairs(p.numbers or {}) do fs:SetShown(p.view == 1) end
    mark(p, "back", p.view == 0)
    mark(p, "on", p.view == 2)
end

--- The legend's entries (0x39's or 0x34's marks), each its symbol and its text in its colour (BARAM.PAL's index).
local function legendEntries(n, get)
    local list = {}
    for i = 1, n do
        local _, text, symbol, colour = get(i)
        list[#list + 1] = { text = text, symbol = symbol, colour = colour }
    end
    return list
end

-- ----- the self look -----

--- A switch of the self look: the option it sends (its def's: 8 the exchange, 2 the group). Wire: what its press sends
--- is TK.Game.SelfLook.SwitchControl's (7.5.2's option switch); changing the option changes what the server sees.
function scripts.Switch(b) SelfLook.SwitchControl(b, b.def.option) end

--- A button of the look: its action (look:trade, look:group). Wire: what its press sends is TK.Game.Look.ActionButton's
--- (7.5.2's look buttons); changing the action changes what the server sees.
function scripts.LookButton(b) TK.Game.Look.ActionButton(b, b.def.action) end

--- A look page's buttons' help lines, using each button's existing frame and text (interfaces/5x/help.lua).
-- WIRE: 7.5.2's UserLookPane 0x005A1580 creates help on a single-right press; SelfLookPane 0x00568CB0 also tests the
-- bow first. The interface supplies the frame and text, while shared Tips.ForPress decides the trigger; changing that
-- condition can change which next game press the catcher consumes and what the server sees.
local function buttonHelp(p, bowFirst)
    for _, b in ipairs(p.buttons) do Help.OnRightPress(p, function() return Help.String(b.def.help) end, b, bowFirst) end
end

-- XML <run> supplies build context after the frame, so public callbacks must not interpret that context as bowFirst.
function scripts.ButtonHelp(p) buttonHelp(p) end

function scripts.SelfButtonHelp(p) buttonHelp(p, true) end

--- The self look's take-off controls, one over each worn place (WORN), with their item's sheet on a right press. Wire:
--- each is 7.5.2's gear slot (TK.Game.SelfLook.WornControl; what it takes off: showEquipment's S.TakeOff); changing
--- them changes what the server sees.
function scripts.TakeOff(p)
    p.takeOff = {}
    for i, def in ipairs(WORN) do
        p.takeOff[i] = CreateFrame("Button", "TK5xSelfWorn" .. i, p)
        SelfLook.WornControl(p.takeOff[i])
        local record = def.record
        SelfLook.WornHelp(p.takeOff[i], p, ItemBox, function() return H:GetEquipment(record) end)
    end
end

--- Modern's character page's request (open:character, 2D 00) on the self page: it runs when the page becomes visible
--- during the input that froze it (C:Show). Wire: changing when the page shows changes when the server gets 2D 00.
function scripts.CharacterRequest(p) TK.Game.Views.RequestPage(p, "open:character") end

--- The group's request page (main.xml's note; open:group, 2D 01: NewGroupPane::OnActivate 0x0056CB80). Wire: changing
--- when it shows changes when the server gets 2D 01.
function scripts.GroupRequest(r) TK.Game.Views.RequestPage(r, "open:group") end

--- The self look's view now (looked at four times a second while it shows, and on its events).
local function showSelf(p)
    local _, totem = H:GetPlayerOrigin()
    -- view 0's frame is the totem's (OldUserStatusPane's byte 265, sub_4E0D50), the other views' frame 0
    local frame = p.view == 0 and ((totem and totem >= 0 and totem <= 3) and totem or 0) or 0
    S.Picture(p, p.back, L.SELF_FILES[p.view + 1], frame, "NPAL6.PAL", 0, 0, "BACKGROUND")
    local has, clan, clanTitle, title, fifth = H:GetSheet()
    local _, name = H:GetUnitInfo("player")
    if not has then clan, clanTitle, title, fifth = "", "", "", "" end
    if p.view == 0 then
        -- 0x39's strings by their place (5.33's own parse, 0x0049CDD0; 7.5.2's 0x39 starts the same)
        local states = {}
        states[1], states[2] = H:GetSelfLookStates()
        showEquipment(p, { clan, clanTitle, title, fifth, name or "" }, "player", function(i)
            local _, _, code, itemName, iconId = H:GetEquipment(i)
            if itemName == "" then return nil, code end -- no picture; the place keeps its slot's take-off
            return iconId, code, H:GetEquipmentColour(i)
        end, states)
        -- the effects on the player, a name a line (SpelledPane__RebuildDisplayText 0x0049F5A0)
        local list = {}
        for i = 1, H:GetNumEffects() do
            local ok, effect = H:GetEffect(i)
            if ok then list[#list + 1] = { text = effect } end
        end
        p.effects:Lines(list)
    elseif p.view == 1 then
        -- the group list: 5.33's group text written from the roster 7.5.2's server gives (groupText), else 0x39's fourth
        -- string as 5.33 shows it; the numbers right-aligned (NUMBERS)
        p.group:Lines(linesOf(groupText() or H:GetSheetAuxiliary()))
        local _, _, hpMax, _, mpMax = H:GetUnitVitals("player")
        local ok, ac, dam, hit, nextLevel = H:GetSheetSummary()
        if not ok then ac, dam, hit, nextLevel = 0, 0, 0, 0 end
        local values = { string.format("%d", hpMax or 0), string.format("%d", mpMax or 0), string.format("%d", ac),
                         string.format("%d", dam), string.format("%d", hit), string.format("%d", nextLevel) }
        local at = L.NUMBERS
        for i, v in ipairs(values) do textRight(p.numbers[i], p, v, at.x, at.y + at.step * (i - 1), S.TEXT) end
    else
        p.legend:Lines(legendEntries(H:GetNumLegend(), function(i) return H:GetLegend(i) end))
    end
    showView(p, { [0] = { p.effects }, [1] = { p.group }, [2] = { p.legend } })
end

-- ----- the look at another player -----

local function showLook(p)
    -- view 0 on SELFLOOK.EPF at 0x34's byte after the legend (5.33 from version 531: UserLookPane_OnActivate 0x004D19C0;
    -- before it, USERLOOK.EPF), a totem's frame as the self look's (0-3)
    local frame = p.view == 0 and H:GetLookTrailingState() or 0
    if frame > 3 then frame = 0 end
    S.Picture(p, p.back, L.LOOK_FILES[p.view + 1], frame, "NPAL6.PAL", 0, 0, "BACKGROUND")
    local _, name, header, line1, line2, line3 = H:GetLook()
    local _, moreInfo, profile, groupState, tradeState, _, portrait = H:GetLookDetail()
    p.face:Hide()
    if p.view == 0 then
        -- 0x34's first five strings where 5.33 puts them (UserLookPane_OnActivate 0x004D19C0: the second at y 48, the
        -- third at 65, the first at 82, then the fourth and the fifth on the fourth row; 7.5.2's 0x34 starts the same)
        showEquipment(p, { line2, line3, line1, header, name }, "look", function(i)
            local _, _, iconId, itemName = H:GetLookItem(i)
            return itemName ~= "" and iconId or nil, nil, H:GetLookItemColour(i)
        end, { tradeState, groupState })
        p.moreInfo:Lines(linesOf(moreInfo))
    elseif p.view == 1 then
        -- the face (FACE): the portrait the packet carries, else FACE.EPF's frame for the look's kind
        local key = portrait ~= "" and portrait or TK.Art.Image("FACE.EPF", H:GetLookFaceFrame(), "PFLOOK.PAL")
        if key then
            p.face:SetTexture(key)
            local at = L.FACE
            rect(p.face, p, at[1], at[2], at[3], at[4])
            p.face:Show()
        end
        p.profile:Lines(linesOf(profile))
    else
        p.legend:Lines(legendEntries(H:GetNumLookLegend(), function(i) return H:GetLookLegend(i) end))
    end
    showView(p, { [0] = { p.moreInfo }, [1] = { p.profile }, [2] = { p.legend } })
end

-- ----- the panel -----

-- 4a's side panel tabs this panel draws a page for (0 the self look, 1 another player's look, 2 the items, 3 the spells;
-- the group, tab 4, in the self look's status view, as 5.33 shows it).
local KEPT_PAGE = { [0] = "self", [1] = "look", [2] = "items", [3] = "spells" }

--- s6-interface-5x-b (round 7, Y1; Astra's review); s6-interface-5x (round 12): an accepted switch of the game layer's
--- tab (TK_SIDE_PANEL_TAB: 4a's GeneralPurposePanel::SwitchActiveTab 0x004B8650, refused for the tab already active but
--- the self look and the look). It takes the totem's picture away (round 6: totemFrame; the tab of the page that shows
--- asked again keeps it, but the self look and the look, which always switch), and a switch away from the group, to any
--- tab (the options and the collection too), the group's request page, so the next switch to tab 4 shows it again and
--- sends 2D 01 (NewGroupPane::OnActivate 0x0056CB80: on each accepted switch); a switch to tab 4 lets the group's opener
--- show it (C:Show("group")). Wire: changing when the request page goes or shows changes when the server gets 2D 01.
function C:FollowTab(index)
    local f = self.frame
    if not f or index < 0 then return end
    if index ~= self.shownTab or index <= 1 then f.totem:Hide() end
    self.shownTab = index
    -- Presentation follows the shared accepted switch. Never switch a tab or own input here:
    -- 4a SwitchActiveTab 0x004B8650 decides activation; changing that changes what the server sees.
    self.effects:Trigger(index)
    if index ~= 4 then f.pages.self.groupRequest:Hide() end
    self.groupSwitch = index == 4
end

--- Shows a page ("items", "spells", "self", "legend", "look" or "group"), as GeneralPurposePanel::SwitchActiveTab. The self page
--- carries Modern's character page's request (open:character, 2D 00), run when it becomes visible during the input that
--- froze it; it is shown again when it already shows, so each such press sends it (the Info icon's, as 4a's IconsPane
--- requests on each press; the status key on the open self look never gets here: C:StatusKey). Changing that changes
--- what the server sees. The self look opens on its equipment view; "legend" opens it on its legend view;
--- a view the server asked for (S 0x3E, D-77: 0 the equipment, 1 the status, 2 the legend) is shown once, at the open
--- its 0x39 brought, as 4a's SelfLookPane::OnActivate takes m_serverRequestedViewMode and sets it back to 0. The look opens
--- on its first view.
function C:Show(id, requestedView)
    local f = self.frame
    if not f then return end
    -- s6-interface-5x-b (round 7, Y1): the group is tab 4, which 5.33 shows in the self look's status view; asked again
    -- while it is the active tab, the game layer's switch is refused (C:FollowTab did not run) and nothing more happens
    -- (no second 2D 01). Wire: the tab decides whether the group's next press sends 2D 01 and whether S is the self
    -- look's (C:StatusKey); changing it changes what the server sees.
    local group = id == "group"
    if group and not self.groupSwitch then return end
    self.groupSwitch = false
    local view = 0
    if id == "legend" then id, view = "self", 2 end
    if group then id, view = "self", 1 end
    local p = f.pages[id]
    if id == "self" then
        -- WIRE: the ordered 0x39 notice supplies its own page (SelfLookPane::OnActivate 0x00565890).
        -- Polling the newest request loses pages in a packet burst and changes the equipment input the server sees.
        if not group and requestedView ~= nil then view = requestedView end
        p.view = view
        if self.page == id and not group then TK.Game.Views.ShowAgain(p) end
        if group then p.groupRequest:Show() end
    elseif id == "look" then
        p.view = 0
    end
    self.page = id
    self:Refresh()
end

--- s6-interface-5x-b (round 6; s6-interface-5x's Y8): 5.33's TotemFrame (constructor 0x004CB380, paint 0x004CB480; 4a's
--- TotemFrame.cpp), the totem's picture over the side panel: made when the status's totem changes (4a's legacy branch of
--- the status packet, UserStatusPane.cpp:722-732, the totem starting at -1, so the first status after a login shows it),
--- in front of the pages (SetPaneOrder(0, BackPane)) at (435, 11)-(627, 299) of the screen, one pixel right of and above
--- them: TOTFRAME.EPF's frame for the totem in NPAL7.PAL (none for -1); gone at the next page switch
--- (GeneralPurposePanel::SwitchActiveTab, which keeps it when the same page is asked again, but for its tabs 0 and 1, the
--- self look and the look: C:Show). It takes no press (TotemFrame has no handler of its own). Drawing only.
local function totemFrame(self, f)
    local _, totem = H:GetPlayerOrigin()
    if totem == nil or totem == self.totemSeen then return end
    self.totemSeen = totem
    if totem < 0 or totem > 3 then return f.totem:Hide() end
    f.totem.tex = S.Picture(f.totem, f.totem.tex, "TOTFRAME.EPF", totem, "NPAL7.PAL", 0, 0, "ARTWORK")
    f.totem:Show()
end

--- s6-ui-core (round 105, T11 step 9): whether event e changes nothing the page shows: the group's (each change of a
--- member's vitals, the player's own among them) is drawn by the self look alone (its status view's group list), so the
--- items and the spells, which are drawn again whole at each Refresh, are not. Drawing only: nothing is sent.
function C.NotShown(page, e)
    return (e == "TK_GROUP_UPDATE" or e == "GROUP_ROSTER_UPDATE") and (page == "items" or page == "spells")
end

function C:Refresh()
    local f = self.frame
    if not f then return end
    for id, p in pairs(f.pages) do p:SetShown(id == self.page) end
    local p = f.pages[self.page]
    if self.page == "items" then showItems(p)
    elseif self.page == "spells" then showSpells(p)
    elseif self.page == "self" then showSelf(p)
    else showLook(p) end
end

--- The original's status key while the panel shows (TK.Game.Views.StatusKey, with 4a's tab 0 active). Wire: with the
--- self look the page that shows, its views cycle (the equipment, the status, the legend, then the equipment:
--- SelfLookPane::HandleKeyOrTextEvent's 's', SelfLookPane.cpp:1067, HideLegendPane, ShowLegendPane, ResetAndRefresh)
--- and the key is taken: the page stays shown, so its request does not run and nothing is sent, as 4a's self look keeps
--- the key from UserPane's RequestLocalPlayerStatus. True when it took the key; false otherwise (the key then opens the
--- self look with its one 2D 00). Changing it changes whether the server gets 2D 00.
function C:StatusKey()
    local f = self.frame
    -- s6-interface-5x (round 12; Astra's review of the round 11 fix, P1): only while 4a's tab 0 is the active tab (the game
    -- layer's, core/game/selflook.lua), not while this page merely still shows it: after F (the group, tab 4, in Modern's
    -- window) 4a's self pane no longer has the key, so UserPane's S sends 2D 00 (UserPane.cpp:1546).
    if not f or self.page ~= "self" or not TK.Game.SelfLook.Showing() then return false end
    local p = f.pages.self
    p.view = (p.view + 1) % 3
    self:Refresh()
    return true
end

--- PgUp and PgDn (delta -1 or 1, core/character.lua's paging keys): the items' and spells' pages back or on as their
--- buttons, the looks' views as their arrows; local, nothing sent. True: the panel took the keys.
function C:Page(delta)
    local f = self.frame
    if not f then return false end
    local p = f.pages[self.page]
    if self.page == "items" or self.page == "spells" then
        if delta < 0 and p.number > 0 then p.number = p.number - 1
        elseif delta > 0 and not p.last then p.number = p.number + 1 end
    else
        p.view = math.max(0, math.min(2, p.view + delta))
    end
    self:Refresh()
    return true
end

--- Whether the panel shows now (in the world, switched on), so the bag, book, character and look openers show its
--- pages.
function C:IsShowing() return self.frame ~= nil and self.frame:IsShown() end

--- The component's root (Astra's review of round 1): a replaced component keeps it hidden (TK.ReplaceComponent).
function scripts.Own(f)
    C:Own(f)
    C.frame = f
end

--- The pages by id (C:Show's and C:Refresh's), 5.33's InterfaceEfxMgr's animations (interfaces/5x/sideeffects.lua) and
--- the page it starts on.
function scripts.Pages(f)
    f.pages = { items = f.items, spells = f.spells, self = f.selfPage, look = f.lookPage }
    C.effects = Effects(f)
    -- s6-interface-5x (round 12; the head's review of round 11): after a UI reload, the page of the session's active tab
    -- (the game layer's, kept on the host); at the client's start (no tab) the items. Drawing only: nothing is sent.
    C.page = KEPT_PAGE[TK.Game.SidePanel.Active()] or "items"
    C.shownTab = KEPT_PAGE[TK.Game.SidePanel.Active()] and TK.Game.SidePanel.Active() or 2 -- C:FollowTab
end

--- The totem's frame in front of the pages (totemFrame).
function scripts.InFront(t) t:SetFrameLevel(t:GetParent():GetFrameLevel() + 50) end

--- s6-ui-core (round 84): made again in the world by a live switch to 5.x, the totem the status has now is the one seen,
--- so its picture shows only when the totem changes, as 5.33's; it showed again over the page at each switch to 5.x
--- until a page switch. (A UI reload starts at the login state, so it still shows the picture once.) Drawing only.
function scripts.TotemSeen()
    if TK.GameState:InWorld() then C.totemSeen = select(2, H:GetPlayerOrigin()) end
end

--- s6-interface-5x-b (round 6): the totem's picture looked at four times a second (totemFrame).
function scripts.TotemTicker(f) f:SetScript("OnUpdate", TK.Util.Throttled(0.25, function() totemFrame(C, f) end)) end

function scripts.Register(f)
    C.entry = Screen.Register(f, "5x.side", "5.x Side Panel", function() return C:DB().enabled == true end)
end

function scripts.RegisterEvents(events)
    for _, e in ipairs(events.events) do events:RegisterEvent(e) end
end

function scripts.Changed(_, e) if C.frame:IsShown() and not C.NotShown(C.page, e) then C:Refresh() end end

function scripts.Refresh() C:Refresh() end

--- The openers, the game layer's tab switches and the session's state.
function scripts.Provide(f)
    -- the openers (TK.Game.Views, s6-interface-5x round 12, step 1): the bag key, the spell book key, the character key
    -- (and the server's page switches), a look at another player and the group key and button (s6-interface-5x-b round 7,
    -- Y1: the group in the self look's status view) show this panel's pages while it shows; the options and the
    -- collection, which it does not draw, switch the game layer's tab (F10's SwitchToOptionTab, Z's collection tab) and
    -- their windows stand in
    TK.Game.Views.Provide("5x.side", {
        views = { bag = "items", spellbook = "spells", character = "self", legend = "legend", look = "look",
                  group = "group" },
        IsShowing = function() return C:IsShowing() end,
        Show = function(page, _, how, key, view) C:Show(page, view) return true end,
        Page = function(delta) return C:Page(delta) end,
        StatusKey = function() return C:StatusKey() end,
    })
    -- the game layer's accepted tab switches (C:FollowTab)
    TK.On("TK_SIDE_PANEL_TAB", function(_, index) C:FollowTab(index) end)
    -- s6-ui-core (round 93): a 0x39 the player did not ask for (the one at the world's entry) shows the self page too, as
    -- 5.33's 0x39 switches its panel to tab 0 and that pane shows (dispatchers.c:523-524, GeneralPurposePanel__SwitchActive-
    -- Tab; the real 5.33 client's capture shows its self page after the entry's 0x39, sending no 2D); an asked-for one
    -- shows it through TK.Game.Views (views.lua). Drawing only: the page becomes visible in the packet's notice, not in a
    -- physical input, so its 2D 00 does not run (A:SetOpen), and the keys go by the game layer's tab, not the page.
    TK.On("TK_RULES_PANEL_TAB", function(_, tab, view, requested)
        if tab == 0 and not requested then C:Show("self", view) end
    end)
    -- a new game screen starts on the items (MainMenuPane's graph at the login's accepted 02): the page that shows, as
    -- if its tab were the active one (asked again it keeps the totem; the game layer's tab is none, -1, which sends
    -- nothing different: only tabs 0 and 4 change what a key sends)
    -- (and its status pane starts again, its totem at -1: the next status shows the totem's picture, totemFrame)
    TK.On("TK_SESSION_STATE", function(_, state)
        if state == "Accepted" then
            C.page, C.shownTab, C.groupSwitch = "items", 2, false
            C.totemSeen = -1
            f.totem:Hide()
            f.pages.self.groupRequest:Hide()
        end
    end)
end

function C:OnEnable()
    TK.Xml.Load("main.xml", { scripts = scripts, elements = elements })
end

--- At 5.33's place on the scaled 5.x screen unless moved, at the screen's scale times its own; in the game only.
function C:ApplySettings() Screen.PlacePanel(self, S.WIDTH, S.HEIGHT, L.PLACE[1], L.PLACE[2]) end

Screen.Follow(C, "ApplySettings")
