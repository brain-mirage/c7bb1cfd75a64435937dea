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

local PLACE = { 434, 12 }
local WIDTH, HEIGHT = 192, 288

-- ----- drawing helpers -----

--- A rectangle (l, t)-(r, b) of the page: a frame's place and size.
local function rect(frame, page, l, t, r, b)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", page, "TOPLEFT", l, -t)
    frame:SetSize(r - l, b - t)
end

--- An invisible button over (l, t)-(r, b) of the page, pressed on its left press (the panes' type 1).
local function pressButton(page, l, t, r, b, fn)
    local btn = CreateFrame("Button", nil, page)
    rect(btn, page, l, t, r, b)
    btn:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then fn() end end)
    return btn
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

--- SPELLBUT.EPF's frame n over (x, y) of the page (a button's first-page, last-page or chosen view mark), or hidden.
local function mark(page, key, on, frame, x, y)
    if on then
        page.marks[key] = S.Picture(page, page.marks[key], "SPELLBUT.EPF", frame, "NPAL6.PAL", x, y, "BORDER")
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

local ITEMS_PAGE = 15

local function buildItems(f)
    local p = CreateFrame("Frame", "TK5xSideItems", f)
    p:SetAllPoints(f)
    p.back = S.Picture(p, nil, "ITEMINV.EPF", 0, "NPAL6.PAL", 0, 0, "BACKGROUND")
    p.marks, p.number, p.icons = {}, 0, false
    p.slots = {}
    p.dragLabel = DragLabel.New(p, S, S.GAME_ART, 0x25) -- this inventory's native list-name colour on black
    for i = 1, ITEMS_PAGE do
        local b = CreateFrame("Button", "TK5xItemSlot" .. i, p)
        Inv.SlotControl(b, { help = function(slot) Inv.ShowHelp(ItemBox, p, slot) end,
            tooltip = function() end, leave = function() end }) -- G2: the single right press's local sheet
        -- Native paint follows this page's list pen or picture cell; shared 7.5.2
        -- selection/carry/drop handlers still decide every server-visible action.
        p.dragLabel:Attach(b, function()
            local k = i - 1
            if p.icons then return "grid", 40 + 45 * (k % 3), 40 + 41 * math.floor(k / 3) end
            return "list", 30, 58 + 13 * k
        end)
        b:Hide()
        b.icon = p:CreateTexture(nil, "ARTWORK")
        b.letter = p:CreateFontString(nil, "OVERLAY")
        b.name = p:CreateFontString(nil, "OVERLAY")
        p.slots[i] = b
    end
    Inv.HelpOwner(p, Help)
    Inv.Track(p.slots) -- the slots' actions (TK.Game.Inventory.UpdateActions)
    -- the buttons (GetButtonBounds: 0 back, 1 on, 2 the list, 3 the pictures), on their press as 5.33's case 1
    pressButton(p, 59, 259, 81, 277, function() if p.number > 0 then p.number = p.number - 1 C:Refresh() end end)
    pressButton(p, 112, 259, 134, 277, function() if not p.last then p.number = p.number + 1 C:Refresh() end end)
    pressButton(p, 81, 259, 103, 277, function() p.icons = false C:Refresh() end)
    pressButton(p, 104, 259, 112, 277, function() p.icons = true C:Refresh() end)
    -- no carry outlives the page (as the bag window's closing ends one)
    Inv.EndCarryOnHide(p)
    return p
end

local function showItems(p)
    local list = Inv.HeldSlots()
    local pages = math.max(1, math.ceil(#list / ITEMS_PAGE))
    p.number = math.max(0, math.min(p.number, pages - 1))
    p.last = (p.number + 1) * ITEMS_PAGE >= #list
    for i, b in ipairs(p.slots) do
        local slot = list[p.number * ITEMS_PAGE + i]
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
                -- the pictures: three a row from the pen (40, 72), each at pen.x - w / 2 + 6, pen.y - h / 2 - 6; its
                -- button (40 + 45c, 40 + 41r)-(75 + 45c, 75 + 41r)
                local px, py = 40 + 45 * (k % 3), 72 + 41 * math.floor(k / 3)
                itemPicture(b.icon, p, iconId, px - math.floor(fw / 2) + 6, py - math.floor(fh / 2) - 6, S.GAME_ART, colour)
                rect(b, p, px, py - 32, px + 35, py + 3)
            else
                -- the list: the pen (30, 58) down 13 a row; the half-size picture centred on (pen.x + 6, pen.y - 6),
                -- the letter at pen.x + 12 in 9 and the name after it in 0x25; its button (30, 46 + 13k)-(160,
                -- 59 + 13k)
                local py = 58 + 13 * k
                local sx, sy = math.floor(fw / 2), math.floor(fh / 2)
                itemPicture(b.icon, p, iconId, 30 + 6 - math.floor(sx / 2), py - 6 - math.floor(sy / 2), S.GAME_ART / 2, colour)
                local x = textAt(b.letter, p, H:SlotLetter(slot) .. ": ", 42, py, 9)
                textAt(b.name, p, name, x, py, 0x25)
                rect(b, p, 30, py - 12, 160, py + 1)
            end
        end
    end
    mark(p, "back", p.number == 0, 12, 59, 259)
    mark(p, "on", p.last, 15, 112, 259)
    mark(p, "list", not p.icons, 13, 81, 259)
    mark(p, "pictures", p.icons, 14, 104, 259)
    Inv.UpdateActions()
end

-- ----- the spells (NewSpellInventoryPane) -----

local SPELLS_PAGE = 13

local function buildSpells(f)
    local p = CreateFrame("Frame", "TK5xSideSpells", f)
    p:SetAllPoints(f)
    p.back = S.Picture(p, nil, "SPELLINV.EPF", 0, "NPAL6.PAL", 0, 0, "BACKGROUND")
    p.marks, p.number = {}, 0
    p.rows = {}
    p.dragLabel = DragLabel.New(p, S, S.GAME_ART)
    for i = 1, SPELLS_PAGE do
        local b = CreateFrame("Button", "TK5xSpellRow" .. i, p)
        TK.Actions:SetPath(b, "spellbook")
        Spells.CellControl(b) -- the book cell's input path whole (the game layer's)
        p.dragLabel:Attach(b, function() return "spell", 35, 51 + 13 * (i - 1) end)
        b:Hide()
        rect(b, p, 22, 51 + 13 * (i - 1), 170, 64 + 13 * (i - 1))
        b.text = p:CreateFontString(nil, "OVERLAY")
        p.rows[i] = b
    end
    pressButton(p, 14, 221, 36, 239, function() if p.number > 0 then p.number = p.number - 1 C:Refresh() end end)
    pressButton(p, 157, 221, 179, 239, function() if not p.last then p.number = p.number + 1 C:Refresh() end end)
    return p
end

local function showSpells(p)
    local list = Spells.HeldSlots()
    local pages = math.max(1, math.ceil(#list / SPELLS_PAGE))
    p.number = math.max(0, math.min(p.number, pages - 1))
    p.last = (p.number + 1) * SPELLS_PAGE >= #list
    for i, b in ipairs(p.rows) do
        local slot = list[p.number * SPELLS_PAGE + i]
        b.slot = slot
        b:SetShown(slot ~= nil)
        if slot then
            local _, name = H:GetSpellSlot(slot)
            textAt(b.text, p, H:SlotLetter(slot) .. ": " .. name, 35, 63 + 13 * (i - 1), S.TEXT)
        else
            b.text:Hide()
        end
    end
    mark(p, "back", p.number == 0, 6, 14, 221)
    mark(p, "on", p.last, 7, 157, 221)
    local held = TK.Cursor:Get()
    for _, b in ipairs(p.rows) do
        if b.slot then Spells.SetCellAction(b, held) else TK.Actions:Clear(b) end
    end
end

-- ----- the self look and the look (SelfLookPane, UserLookPane): three views each -----

-- The worn items both equipment views draw, by their record in 7.5.2's order (the helm, the two hands, the two
-- sub-hands: slot codes 4, 7, 8, 20, 21, SetEquipmentSlotFromPacket 0x0049EE30): each centred on (x, y) of the page,
-- or (sub-hands) centred on x with its top at y. On the self look each place is also its take-off control: over the
-- drawn item's whole frame, or, with none worn, over an EMPTY_PLACE box placed the same way.
local WORN = {
    { record = 4, x = 96, y = 120 },               -- the helm
    { record = 5, x = 122, y = 176 },              -- the left hand
    { record = 6, x = 71, y = 176 },               -- the right hand
    { record = 7, x = 34, y = 116, top = true },   -- the left sub-hand
    { record = 8, x = 34, y = 149, top = true },   -- the right sub-hand
}
-- An empty place's take-off box (s6-interface-5x round 13): 7.5.2's slot box is 48 x 48 at its pane's size
-- (SelfLookPane::GetSlotRect), and 5.x draws the items at S.GAME_ART, half of it. Drawing only; what a press sends is
-- S.TakeOff's.
local EMPTY_PLACE = 24

-- The two buttons by the figure (SelfLookPane_GetSlotRect, UserLookPane__GetActionButtonRect 0 and 1): LOOKBTN.EPF's
-- frame on or off by the state (0 or 3, 1 or 4); 0xFF or -1 before the server's: the rectangle filled 0x8F.
local BUTTONS = {
    { rect = { 149, 107, 175, 133 }, on = 0, off = 3 },
    { rect = { 149, 134, 175, 160 }, on = 1, off = 4 },
}

--- The views' arrows (rects 2 and 3: (34, 254) back, (137, 254) on), as 5.33's cases 2 and 3: view 0 -> 1 -> 2 and
--- back; the first view's back arrow and the last's on arrow are SPELLBUT's plain frames 2 and 3.
local function arrows(p)
    pressButton(p, 34, 254, 56, 272, function() if p.view > 0 then p.view = p.view - 1 C:Refresh() end end)
    pressButton(p, 137, 254, 159, 272, function() if p.view < 2 then p.view = p.view + 1 C:Refresh() end end)
end

--- What both equipment views have: five lines, the figure, the worn items, the two buttons (made by the page: their
--- actions differ) and the box under them.
local function buildEquipment(p)
    p.back = p:CreateTexture(nil, "BACKGROUND")
    p.marks, p.view = {}, 0
    p.lines = {}
    for i = 1, 5 do p.lines[i] = p:CreateFontString(nil, "OVERLAY") end
    p.figure = p:CreateTexture(nil, "BORDER")
    p.worn = {}
    for i = 1, #WORN do p.worn[i] = p:CreateTexture(nil, "ARTWORK") end
    for _, b in ipairs(p.buttons) do
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints(b)
    end
    for i, def in ipairs(BUTTONS) do rect(p.buttons[i], p, def.rect[1], def.rect[2], def.rect[3], def.rect[4]) end
    arrows(p)
    -- the figure and the buttons' states change with the look and the logic thread
    p:SetScript("OnUpdate", TK.Util.Throttled(0.25, function() C:Refresh() end))
end

--- An equipment view: lines { (174, 48), (174, 65), (174, 82), (94, 103), (174, 103) } right-aligned, the figure
--- (figure key) centred on (96, 154), the worn items by record (worn(i): the icon of record i, nil for none, and its
--- slot code), the buttons by their states. A page with take-off controls (p.takeOff) puts each over its place. The
--- figure and the items are the base set's pictures at S.GAME_ART, the size 5.33's own art has in its pane.
local function showEquipment(p, lines, figureKind, worn, states)
    local places = { { 174, 48 }, { 174, 65 }, { 174, 82 }, { 94, 103 }, { 174, 103 } }
    for i, at in ipairs(places) do textRight(p.lines[i], p, lines[i] or "", at[1], at[2], S.TEXT) end
    local key, w, h = H:GetFigure(figureKind, 0)
    if key ~= "" and w > 0 then
        -- 5.33 centres the figure's box on (96, 154) (SelfLookPane paint 0x0049D590, UserLookPane 0x004D22F0: the
        -- box of its body and head, sub_4461B0; the whole picture here, see the notes' known limitations)
        local bw, bh = math.floor(w * S.GAME_ART), math.floor(h * S.GAME_ART)
        p.figure:SetTexture(key)
        p.figure:SetSize(w * S.GAME_ART, h * S.GAME_ART)
        p.figure:ClearAllPoints()
        p.figure:SetPoint("TOPLEFT", p, "TOPLEFT", 96 - math.floor(bw / 2), -(154 - math.floor(bh / 2)))
        p.figure:Show()
    else
        p.figure:Hide()
    end
    -- the worn items: centred on their place by their whole frame (GetItemGlyphBounds); an empty place's control by
    -- an EMPTY_PLACE box
    for i, def in ipairs(WORN) do
        local iconId, code, colour = worn(def.record)
        local b = p.takeOff and p.takeOff[i]
        local drawn = iconId and iconId >= 0
        local fw, fh = EMPTY_PLACE, EMPTY_PLACE
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
    mark(p, "back", p.view == 0, 2, 34, 254)
    mark(p, "on", p.view == 2, 3, 137, 254)
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

local function buildSelf(f)
    local p = CreateFrame("Frame", "TK5xSideSelf", f)
    p:SetAllPoints(f)
    p.buttons = {}
    for i, def in ipairs({ { "exchange", 8 }, { "group", 2 } }) do
        p.buttons[i] = CreateFrame("Button", "TK5xSelfSwitch" .. def[1], p)
        SelfLook.SwitchControl(p.buttons[i], def[2])
    end
    -- s6-interface-5x-b: their help lines on a right press (SelfLookPane_HandlePointerOrMouseEvent 0x0049E150, case 4:
    -- 5.33's lines 195 and 196, 7.5.2's 197 and 198; interfaces/5x/help.lua)
    for i, b in ipairs(p.buttons) do Help.OnRightPress(p, function() return Help.String(196 + i) end, b) end
    p.takeOff = {}
    for i = 1, #WORN do
        p.takeOff[i] = CreateFrame("Button", "TK5xSelfWorn" .. i, p)
        SelfLook.WornControl(p.takeOff[i])
        local record = WORN[i].record
        SelfLook.WornHelp(p.takeOff[i], p, ItemBox, function() return H:GetEquipment(record) end)
    end
    buildEquipment(p)
    p.effects = textBox(p, 17, 192, 174, 251)  -- view 0: the SpelledPane
    p.group = textBox(p, 17, 36, 174, 131)     -- view 1: the GroupListPane
    p.legend = textBox(p, 17, 36, 174, 251)    -- view 2: the LegendPane
    p.numbers = {}
    for i = 1, 6 do p.numbers[i] = p:CreateFontString(nil, "OVERLAY") end
    TK.Game.Views.RequestPage(p, "open:character")
    -- s6-interface-5x-b (round 7, s6-interface-5x's Y1): the group's request page, shown while 4a's tab 4 is the active
    -- one (C:Show("group")): 5.33 shows the group in this view's GroupListPane, 7.5.2 in its group tab, whose activation
    -- asks for the members (open:group, 2D 01: NewGroupPane::OnActivate 0x0056CB80). Wire: it runs when this frame
    -- becomes visible during the input that froze the group's key or button, so once for each accepted switch to tab 4;
    -- changing when it shows changes when the server gets 2D 01.
    p.groupRequest = CreateFrame("Frame", "TK5xSideGroupRequest", p)
    p.groupRequest:Hide()
    TK.Game.Views.RequestPage(p.groupRequest, "open:group")
    return p
end

--- The self look's view now (looked at four times a second while it shows, and on its events).
local function showSelf(p)
    local _, totem = H:GetPlayerOrigin()
    local files = { [0] = "SELFLOOK.EPF", "SELFLOK2.EPF", "SELFLOK3.EPF" }
    -- view 0's frame is the totem's (OldUserStatusPane's byte 265, sub_4E0D50), the other views' frame 0
    local frame = p.view == 0 and ((totem and totem >= 0 and totem <= 3) and totem or 0) or 0
    S.Picture(p, p.back, files[p.view], frame, "NPAL6.PAL", 0, 0, "BACKGROUND")
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
        -- string as 5.33 shows it; the numbers right-aligned at 172
        p.group:Lines(linesOf(groupText() or H:GetSheetAuxiliary()))
        local _, _, hpMax, _, mpMax = H:GetUnitVitals("player")
        local ok, ac, dam, hit, nextLevel = H:GetSheetSummary()
        if not ok then ac, dam, hit, nextLevel = 0, 0, 0, 0 end
        local values = { string.format("%d", hpMax or 0), string.format("%d", mpMax or 0), string.format("%d", ac),
                         string.format("%d", dam), string.format("%d", hit), string.format("%d", nextLevel) }
        for i, v in ipairs(values) do textRight(p.numbers[i], p, v, 172, 155 + 19 * (i - 1), S.TEXT) end
    else
        p.legend:Lines(legendEntries(H:GetNumLegend(), function(i) return H:GetLegend(i) end))
    end
    showView(p, { [0] = { p.effects }, [1] = { p.group }, [2] = { p.legend } })
end

-- ----- the look at another player -----

local function buildLook(f)
    local p = CreateFrame("Frame", "TK5xSideLook", f)
    p:SetAllPoints(f)
    p.buttons = {}
    for i, def in ipairs({ { "Trade", "look:trade" }, { "Group", "look:group" } }) do
        p.buttons[i] = CreateFrame("Button", "TK5xLook" .. def[1], p)
        TK.Game.Look.ActionButton(p.buttons[i], def[2])
    end
    -- s6-interface-5x-b: their help lines on a right press (UserLookPane__HandlePointerOrMouseEvent 0x004D2B30, case 4:
    -- 5.33's lines 198 and 199, 7.5.2's 200 and 201; interfaces/5x/help.lua)
    for i, b in ipairs(p.buttons) do Help.OnRightPress(p, function() return Help.String(199 + i) end, b) end
    buildEquipment(p)
    p.moreInfo = textBox(p, 17, 192, 174, 251) -- view 0
    p.profile = textBox(p, 17, 143, 174, 251)  -- view 1
    p.legend = textBox(p, 17, 36, 174, 251)    -- view 2
    p.face = p:CreateTexture(nil, "ARTWORK")
    return p
end

local function showLook(p)
    -- view 0 on SELFLOOK.EPF at 0x34's byte after the legend (5.33 from version 531: UserLookPane_OnActivate 0x004D19C0;
    -- before it, USERLOOK.EPF), a totem's frame as the self look's (0-3)
    local files = { [0] = "SELFLOOK.EPF", "PFLOOK.EPF", "SELFLOK3.EPF" }
    local frame = p.view == 0 and H:GetLookTrailingState() or 0
    if frame > 3 then frame = 0 end
    S.Picture(p, p.back, files[p.view], frame, "NPAL6.PAL", 0, 0, "BACKGROUND")
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
        -- the face (72, 46)-(120, 102): the portrait the packet carries, else FACE.EPF's frame for the look's kind
        local key = portrait ~= "" and portrait or TK.Art.Image("FACE.EPF", H:GetLookFaceFrame(), "PFLOOK.PAL")
        if key then
            p.face:SetTexture(key)
            rect(p.face, p, 72, 46, 120, 102)
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

function C:OnEnable()
    local f = CreateFrame("Frame", "TK5xSide", UIParent)
    f:SetFrameStrata("LOW")
    f:SetSize(WIDTH, HEIGHT)
    f:EnableMouse(true)
    f:Hide()
    self:Own(f)
    self.frame = f
    f.pages = { items = buildItems(f), spells = buildSpells(f), self = buildSelf(f), look = buildLook(f) }
    self.effects = Effects(f)
    -- s6-interface-5x (round 12; the head's review of round 11): after a UI reload, the page of the session's active tab
    -- (the game layer's, kept on the host); at the client's start (no tab) the items. Drawing only: nothing is sent.
    self.page = KEPT_PAGE[TK.Game.SidePanel.Active()] or "items"
    self.shownTab = KEPT_PAGE[TK.Game.SidePanel.Active()] and TK.Game.SidePanel.Active() or 2 -- C:FollowTab
    -- s6-interface-5x-b (round 6): the totem's picture in front of the pages (totemFrame), looked at four times a second
    f.totem = CreateFrame("Frame", nil, f)
    f.totem:SetFrameLevel(f:GetFrameLevel() + 50)
    f.totem:SetPoint("TOPLEFT", f, "TOPLEFT", 1, 1)
    f.totem:SetSize(WIDTH, HEIGHT)
    f.totem:EnableMouse(false)
    f.totem:Hide()
    -- s6-ui-core (round 84): made again in the world by a live switch to 5.x, the totem the status has now is the one seen,
    -- so its picture shows only when the totem changes, as 5.33's; it showed again over the page at each switch to 5.x
    -- until a page switch. (A UI reload starts at the login state, so it still shows the picture once.) Drawing only.
    if TK.GameState:InWorld() then self.totemSeen = select(2, H:GetPlayerOrigin()) end
    f:SetScript("OnUpdate", TK.Util.Throttled(0.25, function() totemFrame(self, f) end))
    self.entry = Screen.Register(f, "5x.side", "5.x Side Panel", function() return self:DB().enabled == true end)
    local events = CreateFrame("Frame", nil, f)
    for _, e in ipairs({ "BAG_UPDATE", "SPELLS_CHANGED", "CURSOR_CHANGED", "TK_CHARACTER_SHEET", "UNIT_NAME_UPDATE",
                         "UNIT_AURA", "GROUP_ROSTER_UPDATE", "TK_GROUP_UPDATE" }) do
        events:RegisterEvent(e)
    end
    events:SetScript("OnEvent", function() if f:IsShown() then self:Refresh() end end)
    f:SetScript("OnShow", function() self:Refresh() end)
    -- the openers (TK.Game.Views, s6-interface-5x round 12, step 1): the bag key, the spell book key, the character key
    -- (and the server's page switches), a look at another player and the group key and button (s6-interface-5x-b round 7,
    -- Y1: the group in the self look's status view) show this panel's pages while it shows; the options and the
    -- collection, which it does not draw, switch the game layer's tab (F10's SwitchToOptionTab, Z's collection tab) and
    -- their windows stand in
    TK.Game.Views.Provide("5x.side", {
        views = { bag = "items", spellbook = "spells", character = "self", legend = "legend", look = "look",
                  group = "group" },
        IsShowing = function() return self:IsShowing() end,
        Show = function(page, _, how, key, view) self:Show(page, view) return true end,
        Page = function(delta) return self:Page(delta) end,
        StatusKey = function() return self:StatusKey() end,
    })
    -- the game layer's accepted tab switches (C:FollowTab)
    TK.On("TK_SIDE_PANEL_TAB", function(_, index) self:FollowTab(index) end)
    -- s6-ui-core (round 93): a 0x39 the player did not ask for (the one at the world's entry) shows the self page too, as
    -- 5.33's 0x39 switches its panel to tab 0 and that pane shows (dispatchers.c:523-524, GeneralPurposePanel__SwitchActive-
    -- Tab; the real 5.33 client's capture shows its self page after the entry's 0x39, sending no 2D); an asked-for one
    -- shows it through TK.Game.Views (views.lua). Drawing only: the page becomes visible in the packet's notice, not in a
    -- physical input, so its 2D 00 does not run (A:SetOpen), and the keys go by the game layer's tab, not the page.
    TK.On("TK_RULES_PANEL_TAB", function(_, tab, view, requested)
        if tab == 0 and not requested then self:Show("self", view) end
    end)
    -- a new game screen starts on the items (MainMenuPane's graph at the login's accepted 02): the page that shows, as
    -- if its tab were the active one (asked again it keeps the totem; the game layer's tab is none, -1, which sends
    -- nothing different: only tabs 0 and 4 change what a key sends)
    -- (and its status pane starts again, its totem at -1: the next status shows the totem's picture, totemFrame)
    TK.On("TK_SESSION_STATE", function(_, state)
        if state == "Accepted" then
            self.page, self.shownTab, self.groupSwitch = "items", 2, false
            self.totemSeen = -1
            f.totem:Hide()
            f.pages.self.groupRequest:Hide()
        end
    end)
end

--- At 5.33's place on the scaled 5.x screen unless moved, at the screen's scale times its own; in the game only.
function C:ApplySettings() Screen.PlacePanel(self, S.WIDTH, S.HEIGHT, PLACE[1], PLACE[2]) end

Screen.Follow(C, "ApplySettings")
