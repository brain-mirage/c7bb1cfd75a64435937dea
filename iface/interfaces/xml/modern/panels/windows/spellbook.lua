-- The character window's Spell Book tab (Modern) as one table (s6-spellbook; the owner's request of 2026-10-04 for build
-- 40, docs/user-related/requests/2026-10-04-spellbook-table.md, narrowed the same day to "learnable info only"): the
-- spells of the 52 slots (0x17, 0x18), a row a spell, with what the character's own casts showed of each in columns: its
-- mana and health costs, its cooldown in seconds, its healing, its damage (two lines: to the enemy in green, to the
-- caster in red) and the auras it put on the player (green a buff, red a debuff, plain when nothing says which: their
-- names when they fit, else a mark each, with the names in the row's tooltip). There is no level column: nothing the
-- client receives says a spell's required level.
--
-- The values are TK.SpellInfo's (core/spellinfo.lua, s6-spellbook-data): numbers, the newest seen, nil (shown ???) while
-- unknown. Where the values seen differed, the row's tooltip gives their range ("seen 100 to 130"). They redraw on
-- TK_SPELLINFO_CHANGED and whenever the spell list changes.
--
-- Sorting is a spreadsheet's: a header's click sorts by its column, a second click reverses it, and an arrow on the
-- header shows which; ??? stays last either way, and ties keep the slots' order. The default is the slots' order, which
-- the Server Order button brings back. The choice is kept per character (its spellbook.json, CharacterStore.SpellBook).
--
-- The rest is the book as it was (head note 38, s6-spell-icons): each spell's icon (animated by
-- TK.SpellIconAnimators.spellbook), the aether's clock on it, the slot letters with the Classic preset, a right click's
-- icon editor, the wheel, the scroll bar and PgUp / PgDn (a screenful each), and, in the slots' order, every slot while a
-- book spell is on the cursor, the empty ones too, so a spell can be moved to one.
--
-- Wire: each row is its slot's for good (b.slot, set once in spellRow) and takes the book cell's input path whole
-- (the game layer's TK.Game.Spells.CellControl and SetCellAction): its cast and its swap carry that slot, never the
-- row's place in the table, whatever the sort or the
-- scroll (4a's NewSpellInventoryPane::ResolveVisibleSpellSlot 0x0057E8D0 turns the place shown into the slot it shows).
-- Moving a spell (30 01) is offered in the slots' order only: sorted, the rows hold no action while a book spell is on
-- the cursor, so a drop on one sends nothing. Changing what a row's action carries changes the 0F and 30 01 the server
-- gets. The table, its values and its sort are drawing only: nothing is sent or asked for to fill them.
--
-- s6-ui-core (round 85): the XML twin's scripts; the page, its header, rows and cells are spellbook.xml's (core/xml.md).

local H = __tk
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local Mark = require("interfaces.modern.slotmark") -- s6-ui-core (round 83): the red edge, as the action bars'
local CW = TK.CharacterWindow

-- the scripts spellbook.xml names, and its build (its templates: the page, a sort button, a row, a cell's line, a mark)
local scripts = {}
local ui = TK.Xml.Load("spellbook.xml", { scripts = scripts, elements = require("interfaces.modern.elements") })

-- a row's height, the icon's side, the list's width, the aura marks a cell shows at most (spellbook.xml's)
local ROW_H, ICON, LIST_W, MARKS = ui.SIZES.row, ui.SIZES.icon, ui.SIZES.list, ui.SIZES.marks

local UNKNOWN = { 0.5, 0.5, 0.5 }
local RANGE = { 0.55, 0.7, 1 }
local GOOD, BAD = { 0.35, 0.85, 0.35 }, { 1, 0.35, 0.35 } -- green: to the enemy, a buff; red: to you, a debuff
local PLAIN_MARK = { 0.8, 0.8, 0.8 } -- an aura nothing calls a buff or a debuff

--- The columns, left to right: each shows TK.SpellInfo's field of its key, and field2 as a second line (the damage to
--- the caster); unit follows a number. The spell's column takes the width the others leave. x and w are set below, and
--- justify (its title's: the spell's at the left, over the names; the others centred).
local COLUMNS = {
    { key = "name", title = "Spell", tip = "The spells by name." },
    { key = "mana", title = "Mana", width = 56, tip = "Its mana cost." },
    { key = "health", title = "Health", width = 48, tip = "Its health cost." },
    { key = "cooldown", title = "Cooldown", width = 60, unit = " s", tip = "Seconds before it can be cast again." },
    { key = "healing", title = "Healing", width = 54, tip = "What it heals." },
    { key = "damage", title = "Damage", width = 56, field2 = "self_damage", title2 = "Damage to you",
      tip = "Its damage: green to the enemy, red to you." },
    { key = "auras", title = "Auras", width = 60, tip = "What it put on you: green a buff, red a debuff." },
}
local BY_KEY = {}
do
    local fixed, x = 0, 0
    for _, c in ipairs(COLUMNS) do fixed = fixed + (c.width or 0) end
    for _, c in ipairs(COLUMNS) do
        BY_KEY[c.key] = c
        c.x, c.w = x, c.width or LIST_W - fixed
        c.justify = c.key == "name" and "LEFT" or "CENTER"
        x = x + c.w
    end
end

-- ----- the values -----

local function number(v)
    if v == math.floor(v) then return TK.Util.FormatNumber(v) end
    return string.format("%.1f", v)
end

--- A value's text and colour in its cell: a number plain (with its unit), unknown as ???. colour, when given, is the
--- line's own (the damage's green and red).
local function shown(v, unit, colour)
    if v == nil then return "???", UNKNOWN end
    return number(v) .. (unit or ""), colour or W.white
end

--- An aura's colour: green a buff, red a debuff, or plain when nothing classifies its name (good nil: the server never
--- says, TK.EffectIcons' lists may).
local function auraColour(a, plain)
    if a.good == true then return GOOD end
    if a.good == false then return BAD end
    return plain
end

--- The tooltip's lines for what a row shows only in part: the range of each value whose values seen differed, and each
--- aura by name in its colour.
local function addDetails(info)
    local function range(title, field, unit)
        local r = info.range and info.range[field]
        if r then
            GameTooltip:AddDoubleLine(title, "seen " .. number(r.low) .. (unit or "") .. " to " .. number(r.high) .. (unit or ""),
                0.7, 0.7, 0.7, RANGE[1], RANGE[2], RANGE[3])
        end
    end
    for _, c in ipairs(COLUMNS) do
        if c.key ~= "name" and c.key ~= "auras" then
            range(c.title, c.key, c.unit)
            if c.field2 then range(c.title2, c.field2, c.unit) end
        end
    end
    for _, a in ipairs(info.auras or {}) do
        local colour = auraColour(a, W.white)
        local kind = a.good == true and " (buff)" or a.good == false and " (debuff)" or ""
        GameTooltip:AddLine(a.name .. kind, colour[1], colour[2], colour[3])
    end
end

-- ----- the sort -----

--- What a row sorts by in a column, in order (n of them, any nil when unknown): the name, the auras' names, or the
--- column's value and its second line's (the damage to the enemy, then to the caster).
local function sortKeys(key, name, info)
    if key == "name" then return { n = 1, name } end
    if key == "auras" then
        if not info.auras or #info.auras == 0 then return { n = 1 } end
        local names = {}
        for _, a in ipairs(info.auras) do names[#names + 1] = a.name end
        return { n = 1, table.concat(names, ", ") }
    end
    local field2 = BY_KEY[key].field2
    return { n = 2, info[key], field2 and info[field2] }
end

--- -1, 0 or 1 for two known values of a column: numbers in their order, or names (the spells', the auras') in theirs,
--- not minding case.
local function compare(a, b)
    if type(a) == "string" then a, b = a:lower(), b:lower() end
    if a == b then return 0 end
    return a < b and -1 or 1
end

--- Whether entry x comes before entry y: by each of their keys in turn, unknown (???) after any known value whichever
--- the direction, the known values reversed when descending; ties in the slots' order.
local function before(x, y, descending)
    for i = 1, x.keys.n do
        local a, b = x.keys[i], y.keys[i]
        if a == nil and b ~= nil then return false end
        if b == nil and a ~= nil then return true end
        if a ~= nil then
            local c = compare(a, b)
            if c ~= 0 then
                if descending then return c > 0 end
                return c < 0
            end
        end
    end
    return x.slot < y.slot
end

--- The character's sort (page.sort, a column's key or nil for the slots' order, and page.descending), read from its
--- spellbook.json when the book first shows for it. Offline, with no character, it lasts the session.
local function loadSort(page)
    local ref = TK.Characters.ref or false
    if page.sortFor == ref then return end
    page.sortFor = ref
    local saved = ref and H:CharacterLoad(ref, "spellbook")
    page.sort = saved and BY_KEY[saved.sort] and saved.sort or nil
    page.descending = saved and saved.descending == true or false
end

local refresh

--- Sorts by a column (key; nil for the slots' order): its first click ascending, the next reversing it. Saved for the
--- character at once.
local function sortBy(page, key)
    if key and page.sort == key then
        page.descending = not page.descending
    else
        page.sort, page.descending = key, false
    end
    local ref = TK.Characters.ref
    if ref then H:CharacterSave(ref, "spellbook", { version = 1, sort = page.sort, descending = page.descending }) end
    page.scroll:ScrollToTop()
    refresh(page)
end

-- ----- the table -----

--- s6-ui-core (round 83; the owner, 2026-10-09: the red edge "on spells, not only the bars"): a row's icon edged in red
--- while its spell cannot be cast now (in its aether, or costing more than the mana), each part a switch of the Character
--- Window's page (windows/settings.lua; interfaces/modern/slotmark.lua). Drawing only.
local function markRow(row, cooling)
    row.cooling = cooling
    Mark.Draw(row, row.edge, Mark.Unusable("spell", row.slot, cooling, TK.GetComponent("windows"):DB().character), W.slotEdge)
end

local bookPage -- the page, once built

--- The shown rows' red edges again: the mana changed, or the page's switches (windows/main.lua's ApplySettings).
local function markShown()
    if not (bookPage and bookPage:IsVisible()) then return end
    for _, b in ipairs(bookPage.shown) do markRow(b, b.cooling) end
end

--- A cell's one value, or two as two lines (t2: the damage to the caster under the enemy's), centred in its column.
local function setLines(row, cell, c, t1, c1, t2, c2)
    local x = c.x + c.w / 2
    cell.a:ClearAllPoints()
    cell.a:SetPoint("CENTER", row, "LEFT", x, t2 and 7 or 0)
    cell.a:SetWidth(c.w - 4)
    cell.a:SetText(t1)
    W.Color(cell.a, c1)
    cell.a:Show()
    cell.b:SetShown(t2 ~= nil)
    if t2 then
        cell.b:ClearAllPoints()
        cell.b:SetPoint("CENTER", row, "LEFT", x, -7)
        cell.b:SetWidth(c.w - 4)
        cell.b:SetText(t2)
        W.Color(cell.b, c2)
    end
end

--- The damage's cell: to the enemy in green over to the caster in red, the one known alone, or ??? for neither.
local function fillDamage(row, cell, c, toEnemy, toSelf)
    if toEnemy == nil and toSelf == nil then return setLines(row, cell, c, "???", UNKNOWN) end
    if toEnemy ~= nil and toSelf ~= nil then
        local t1, c1 = shown(toEnemy, nil, GOOD)
        local t2, c2 = shown(toSelf, nil, BAD)
        return setLines(row, cell, c, t1, c1, t2, c2)
    end
    local t, colour = shown(toEnemy ~= nil and toEnemy or toSelf, nil, toEnemy ~= nil and GOOD or BAD)
    setLines(row, cell, c, t, colour)
end

local measure -- a label that measures a name at the cells' size (made with the page)

--- The auras' cell: ??? while none was seen, their names in their colours when one or two fit, else a mark each in its
--- colour (at most MARKS).
local function fillAuras(row, cell, c, auras)
    for _, m in ipairs(cell.marks) do m:Hide() end
    if not auras or #auras == 0 then return setLines(row, cell, c, "???", UNKNOWN) end
    local fit = #auras <= 2
    for _, a in ipairs(auras) do
        if fit then
            measure:SetText(a.name)
            fit = measure:GetStringWidth() <= c.w - 6
        end
    end
    if fit then
        local x, y = auras[1], auras[2]
        return setLines(row, cell, c, x.name, auraColour(x, W.white), y and y.name, y and auraColour(y, W.white))
    end
    cell.a:Hide()
    cell.b:Hide()
    local n = math.min(#auras, MARKS)
    for k = 1, n do
        local m, colour = cell.marks[k], auraColour(auras[k], PLAIN_MARK)
        m:SetVertexColor(colour[1], colour[2], colour[3], 1)
        m:ClearAllPoints()
        m:SetPoint("CENTER", row, "LEFT", c.x + c.w / 2 + (k - (n + 1) / 2) * 10, 0)
        m:Show()
    end
end

--- A row's spell (name nil: an empty slot, shown while a book spell is moved) and its values in the columns shown.
local function fillRow(row, name, info, classic)
    local ok = name ~= nil
    row.name:SetText(ok and name or "Empty")
    W.Color(row.name, ok and W.white or UNKNOWN)
    W.ActionIcon(row.icon, row.glyph, row.box, ok and row.spell or nil, ICON, 2)
    row.letter:SetShown(classic and true or false)
    local cd, start, duration = H:GetSlotCooldown("spell", row.slot)
    if ok and cd then row.cooldown:SetCooldown(start, duration) else row.cooldown:Clear() end
    markRow(row, ok and cd or false)
    for _, c in ipairs(COLUMNS) do
        local cell = row.cells[c.key] -- none for the spell's own column, drawn above
        if cell then
            if not ok then
                cell.a:Hide()
                cell.b:Hide()
                for _, m in ipairs(cell.marks) do m:Hide() end
            elseif c.key == "auras" then
                fillAuras(row, cell, c, info.auras)
            elseif c.field2 then
                fillDamage(row, cell, c, info[c.key], info[c.field2])
            else
                setLines(row, cell, c, shown(info[c.key], c.unit))
            end
        end
    end
end

--- The rows' actions for the cursor's carry now (the book cell's, TK.Game.Spells.SetCellAction). Sorted, a book spell on the cursor
--- leaves them none: moving a spell (30 01) is offered in the slots' order only, so a drop on a sorted row sends nothing.
local function updateRowActions(page, moving)
    local held = TK.Cursor:Get()
    for _, b in ipairs(page.rows) do
        if moving and page.sort then TK.Actions:Clear(b) else TK.Game.Spells.SetCellAction(b, held) end
    end
end

function refresh(page)
    loadSort(page)
    local held = TK.Cursor:Get()
    local moving = held and held.kind == "spell" and held.from == "book" or false
    -- The spells, with every empty slot too while a book spell is moved in the slots' order.
    local entries = {}
    for i = 1, 52 do
        local ok, name = H:GetSpellSlot(i)
        if ok or (moving and not page.sort) then
            entries[#entries + 1] = { slot = i, name = ok and name or nil, info = ok and TK.SpellInfo:Get(name) or {} }
        end
    end
    if page.sort then
        for _, e in ipairs(entries) do e.keys = sortKeys(page.sort, e.name, e.info) end
        local descending = page.descending
        table.sort(entries, function(x, y) return before(x, y, descending) end)
    end
    local classic = TK.GetComponent("classic") and TK.GetComponent("classic"):DB().enabled
    for _, b in ipairs(page.rows) do b:Hide() end
    page.shown = {}
    page.list:SetHeight(math.max(10, #entries * ROW_H))
    for n, e in ipairs(entries) do
        local b = page.rows[e.slot]
        page.shown[n] = b
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", page.list, "TOPLEFT", 0, -(n - 1) * ROW_H)
        b.stripe:SetShown(n % 2 == 0)
        fillRow(b, e.name, e.info, classic)
        b:Show()
    end
    for _, c in ipairs(COLUMNS) do
        local hb = page.header.buttons[c.key]
        local sorted = page.sort == c.key
        W.Color(hb.label, sorted and W.gold or W.buttonText)
        hb.arrow:SetShown(sorted)
        if sorted then hb.arrow:SetTexture(page.descending and "tk:arrow-down" or "tk:arrow-up") end
    end
    page.serverOrder:SetShown(page.sort ~= nil)
    -- The scroll stays where it was, within the list's new length.
    local sf = page.scroll
    sf:SetVerticalScroll(math.max(0, math.min(sf:GetVerticalScrollRange(), sf:GetVerticalScroll())))
    sf.Refresh()
    page.hint:SetShown(#entries > 0)
    page.empty:SetText(#entries == 0 and "No spells yet: the server sends them as the character learns them." or "")
    updateRowActions(page, moving)
end

-- ----- spellbook.xml's scripts -----

function scripts.Band(bg)
    local band = W.titleBand.color
    bg:SetColorTexture(band[1], band[2], band[3], 1)
end

function scripts.Rule(rule) rule:SetColorTexture(W.headerRule[1], W.headerRule[2], W.headerRule[3], 1) end

function scripts.SortButtons(h, build)
    for _, c in ipairs(COLUMNS) do h.buttons[c.key] = build:New("SortButton", h, "TKSpellBookSort" .. c.key, nil, c) end
end

function scripts.Column(b, _, c) b.column = c end

function scripts.SortLabel(b)
    if b.column.key == "name" then
        b.label:SetPoint("LEFT", b, "LEFT", ICON + 6, 0) -- over the names
    else
        b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    end
end

function scripts.Gold(arrow) arrow:SetVertexColor(W.gold[1], W.gold[2], W.gold[3], 1) end

function scripts.Sort(b)
    TK.Game.Sound.PlayClick()
    sortBy(b:GetParent():GetParent(), b.column.key)
end

function scripts.SortTip(self)
    local c = self.column
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(c.title, 1, 1, 1)
    GameTooltip:AddLine(c.tip, 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Click to sort by it; click again to reverse it.", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

function scripts.Untip() GameTooltip:Hide() end

-- a notch of the wheel is a row; the 52 slots' rows, in the table's scrolling content
function scripts.List(page, build)
    page.scroll.wheelStep = ROW_H
    page.list:SetWidth(LIST_W)
    local nameWidth = BY_KEY.name.w - ICON - 10
    for i = 1, 52 do
        page.rows[i] = build:New("Row", page.list, "TKSpellBookSlot" .. i, nil,
            { slot = i, cooldown = "TKSpellBookSlot" .. i .. "Cooldown", letter = H:SlotLetter(i), nameWidth = nameWidth })
    end
end

--- Wire: b.slot is fixed here and is what its cast and swap send; its input path is the book cell's
--- (TK.Game.Spells.CellControl; the file's comment: 4a's NewSpellInventoryPane::ResolveVisibleSpellSlot 0x0057E8D0).
--- Changing what a row's action carries changes the 0F and 30 01 the server gets.
function scripts.RowSlot(b, _, with)
    TK.Actions:SetPath(b, "spellbook")
    b.slot = with.slot
    b.spell = { kind = "spell", slot = with.slot } -- the action its icon shows (s6-optimize round 11: one table, not one a draw)
end

function scripts.OverBox(cooldown) cooldown:SetFrameLevel(cooldown:GetParent():GetFrameLevel() + 1) end

function scripts.AetherEnd(cooldown) markRow(cooldown:GetParent():GetParent(), false) end

function scripts.BoxParts(b)
    local box = b.box
    b.icon, b.edge, b.glyph, b.cooldown, b.letter = box.icon, box.edge, box.glyph, box.cooldown, box.letter
end

function scripts.Cells(b, build)
    b.cells = {}
    for _, c in ipairs(COLUMNS) do
        if c.key ~= "name" then
            local cell = { a = build:New("CellLine", b), b = build:New("CellLine", b), marks = {} }
            cell.a:SetWordWrap(true)
            if c.key == "auras" then
                for k = 1, MARKS do cell.marks[k] = build:New("AuraMark", b) end
            end
            b.cells[c.key] = cell
        end
    end
end

-- Wire: the row takes the book cell's input path whole (TK.Game.Spells.CellControl); changing it changes what the server
-- sees.
function scripts.CellControl(b) TK.Game.Spells.CellControl(b) end

function scripts.RowTip(self)
    local ok, name = H:GetSpellSlot(self.slot)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if ok then
        GameTooltip:AddLine(name, 1, 1, 1)
        TK.AddSpellCostLine(name)
        addDetails(TK.SpellInfo:Get(name))
        GameTooltip:AddLine((TK.Game.Spells.DoubleClickMode() and "Double-click" or "Click") .. " to cast it; drag it to an action bar or the action wheel.",
            0.5, 0.5, 0.5)
        GameTooltip:AddLine("Right-click to change its icon.", 0.5, 0.5, 0.5) -- s6-spell-icons
        TK.ManaPreview.Show(name)
    else
        GameTooltip:AddLine("An empty place: drop a spell here to move it.", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

function scripts.RowLeave()
    GameTooltip:Hide()
    TK.ManaPreview.Hide()
end

function scripts.Measure(fs) measure = fs end

function scripts.Turn(page)
    page.turn = function(delta)
        local sf = page.scroll
        sf:SetVerticalScroll(math.max(0, math.min(sf:GetVerticalScrollRange(), sf:GetVerticalScroll() + delta * sf:GetHeight())))
        sf.Refresh()
    end
end

function scripts.ServerOrder(b) sortBy(b:GetParent(), nil) end

function scripts.ServerOrderTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Server Order", 1, 1, 1)
    GameTooltip:AddLine("The spells in their slots' order, where one is moved by dropping it on another.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function scripts.BookPage(page) bookPage = page end

function scripts.PowerChanged(_, _, unit) if unit == "player" then markShown() end end

function scripts.Changed(f)
    local page = f:GetParent()
    if page:IsVisible() then TK.SafeCall(CW:Tab("spellbook").refresh, page) end
end

-- s6-optimize (round 11): the rows the page shows are the ones refresh last showed (page.shown; nothing else shows or hides
-- them), so none is asked whether it shows. Registered by name (TK.SetSpellIconAnimator: s6-modular-g round 16).
function scripts.Animator(page)
    TK.SetSpellIconAnimator("spellbook", function()
        if not page:IsVisible() then return end
        for _, b in ipairs(page.shown) do
            if H:GetSpellSlot(b.slot) then W.ActionIcon(b.icon, b.glyph, b.box, b.spell, ICON, 2) end
        end
    end)
end

CW:AddTab({ id = "spellbook", title = "Spell Book", icon = "emoji:1f4d6", order = 20, key = "TOGGLESPELLBOOK",
    build = function(page) ui:New("BookPage", page) end,
    refresh = refresh })

return { MarkShown = markShown } -- s6-ui-core (round 83): windows/main.lua
