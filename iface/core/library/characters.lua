-- The Library's Characters page (s6-library-pages; the owner, 2026-10-04: "when you click a character it should have
-- dropdown pages with the top back selected which is Overview. It should show the character page like it would ingame
-- with his equipment. Then scrollable list on the right side with any inventory items. Also display gold, hp etc on this
-- page. The current info should be its own History subpage. And then Have a spell Page that lists spells. Legend subpage
-- for legends."). The list holds the player's characters on the server; the chosen one opens into its sub-pages.
-- Overview draws the in-game Character tab's gear slots and figure box (TK.UI.Character's, the global widgets) from the
-- Library's records; Legend is the Legend tab's list. The search box searches every character's items (s6-library's
-- "who has the tin mail?"). Read only: nothing is sent.

local W = TK.UI
local H = __tk
local L = TK.Library
local X = L.Lines

local SUBS = {
    { id = "overview", title = "Overview" },
    { id = "history", title = "History" },
    { id = "spells", title = "Spells" },
    { id = "legend", title = "Legend" },
}

local DIM = { 0.62, 0.62, 0.66 }

--- The selected character and sub-page ("name\nsub").
local function chosen()
    local key = L.selected.characters or ""
    local name, sub = key:match("^(.-)\n(.*)$")
    return name or key, sub or "overview"
end

local page = { id = "characters", title = "Characters", order = 10, list = true, search = "Search all characters",
    empty = "No characters recorded yet." } -- s6-library round 18: shorter

--- The characters, the chosen one followed by its sub-pages.
function page:rows(rows)
    local name = chosen()
    if name == "" and rows[1] then
        name = rows[1].key
        L.selected.characters = name .. "\noverview"
    end
    L.character = name
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { key = r.key, name = r.name, sub = r.sub }
        if r.key == name then
            for _, s in ipairs(SUBS) do out[#out + 1] = { key = r.key .. "\n" .. s.id, name = s.title, indent = 16 } end
        end
    end
    return out
end

--- A character opens on its Overview; a sub-page is chosen as it is. Either ends a search.
function page:click(row)
    L.search = ""
    L.selected.characters = row.indent and row.key or (row.key .. "\noverview")
end

function page:mode()
    local _, sub = chosen()
    return (L.search ~= "" or sub == "history" or sub == "spells") and "lines" or "frame"
end

function page:entry() return "characters", (chosen()) end

-- ----- History, Spells and the search: lines -----

--- The character's row of GetLibrary's characters (its parts, each with when it was last seen).
local function record(name)
    for _, c in ipairs(L.data.characters or {}) do
        if c.name == name then return c end
    end
end

--- History: what the window showed before the owner's pass (s6-library rounds 2-11), each part with its Clear.
local function historyLines(c)
    local add, clear, offNote, seenText, itemLine, thousands = X.add, X.clear, X.offNote, X.seenText, X.itemLine, X.thousands
    add(c.name, "header")
    add("Last seen " .. c.seen, "dim")
    -- The bank first (the owner: what each character's bank holds, from another character or offline).
    clear(add("Bank  -  " .. seenText(c.hasBank, c.bankSeen, "last opened"), "sub"), "bank:" .. c.name, { "bank" }, c.name)
    offNote("bank")
    -- s6-library round 24 (the owner): each item's stats on hover (L.ItemTip), and a click opens its page.
    local function item(text, it) add(text, "text", 12, L.LinkTo("items", it.item), L.ItemTip(it.name, nil, it.item)) end
    if c.hasBank then
        if #c.bank == 0 then add("Empty.", "dim", 12) end
        for _, it in ipairs(c.bank) do item(itemLine(it), it) end
    end
    clear(add("Inventory  -  " .. seenText(c.hasInventory, c.inventorySeen), "sub"), "inventory:" .. c.name, { "inventory" }, c.name)
    offNote("inventory")
    if #c.inventory == 0 then add(c.hasInventory and "Empty." or "Nothing recorded.", "dim", 12) end
    for _, it in ipairs(c.inventory) do item(itemLine(it), it) end
    clear(add("Equipment  -  " .. seenText(c.hasEquipment, c.equipmentSeen), "sub"), "equipment:" .. c.name, { "equipment" }, c.name)
    offNote("equipment")
    if #c.equipment == 0 then add(c.hasEquipment and "Nothing worn." or "Nothing recorded.", "dim", 12) end
    for _, it in ipairs(c.equipment) do item(it.name, it) end
    clear(add("Gold and stats  -  " .. seenText(c.hasStats, c.statsSeen), "sub"), "stats:" .. c.name, { "stats" }, c.name)
    offNote("stats")
    local s = c.stats
    if c.hasStats then
        local parts = {}
        local function part(label, v, w) if v ~= nil then parts[#parts + 1] = label .. " " .. (w and (thousands(v) .. "/" .. thousands(w)) or thousands(v)) end end
        part("Gold", s.gold)
        part("Level", s.level)
        part("HP", s.hp, s.maxHp)
        part("MP", s.mp, s.maxMp)
        part("Might", s.statA)
        part("Will", s.statC)
        part("Grace", s.statB)
        part("Experience", s.experience)
        add(#parts > 0 and table.concat(parts, "   ") or "Nothing recorded.", "text", 12)
    else
        add("Nothing recorded.", "dim", 12)
    end
    -- The section shows the spells with their costs: its Clear clears those trackers' records for this character
    -- (s6-spellbook-data: and its spell stats).
    clear(add("Spells  -  " .. seenText(c.hasSpells, c.spellsSeen), "sub"), "spells:" .. c.name, { "spells", "spell_costs", "spell_stats" }, c.name)
    offNote("spells")
    if #c.spells == 0 then add("Nothing recorded.", "dim", 12) end
    for _, sp in ipairs(c.spells) do
        add(sp.name .. ((tonumber(sp.cost) or -1) >= 0 and ("  (" .. thousands(sp.cost) .. " mana)") or ""), "text", 12)
    end
end

--- Spells: the character's spells by slot, with the mana each cost when last cast.
local function spellLines(c)
    local add = X.add
    X.clear(add(c.name .. "'s spells  -  " .. X.seenText(c.hasSpells, c.spellsSeen), "header"), "spells:" .. c.name,
        { "spells", "spell_costs", "spell_stats" }, c.name) -- s6-spellbook-data: and its spell stats
    X.offNote("spells")
    if #c.spells == 0 then add("Nothing recorded.", "dim") end
    for _, sp in ipairs(c.spells) do
        local cost = tonumber(sp.cost) or -1
        add(H:SlotLetter(sp.slot) .. "   " .. sp.name .. (cost >= 0 and ("   -   " .. X.thousands(cost) .. " mana") or ""), "text", 4)
    end
end

--- The search across every character's items.
local function searchLines()
    local hits = H:SearchLibrary(L.server, L.search)
    X.add("Search: \"" .. L.search .. "\"", "header")
    if #hits == 0 then X.add("None of your characters holds it.", "dim") end
    local WHERE = { equipped = "equipped", bag = "in the bag", bank = "in the bank" }
    for _, h in ipairs(hits) do
        -- s6-library round 21: a hit opens the character holding it.
        X.add(h.character .. ": " .. h.item .. "  x" .. X.thousands(h.count) .. "  " .. (WHERE[h.where] or h.where) .. "  (seen " .. h.seen .. ")",
            "text", 0, L.LinkTo("characters", h.character), L.ItemTip(h.item, nil, h.key, true)) -- round 24: the item's stats on hover
    end
end

function page:lines()
    if L.search ~= "" then return searchLines() end
    local name, sub = chosen()
    local c = record(name)
    if not c then
        X.add("No characters recorded yet.", "dim")
    elseif sub == "spells" then
        spellLines(c)
    else
        historyLines(c)
    end
end

-- ----- Overview and Legend: the Character window's drawing -----

--- The Overview: the Character tab's gear slots and figure box on the left (library/gear.lua), the stats and the inventory
--- on the right.
local function buildOverview(area)
    local o = CreateFrame("Frame", nil, area)
    o:SetAllPoints(area)
    o.gear = TK.LibraryGear(o)
    o.figureBox = o.gear.figureBox
    -- The right: the gold and stats, then the inventory's scrolling list.
    local right = CreateFrame("Frame", nil, o)
    right:SetPoint("TOPLEFT", o, "TOPLEFT", 454, 0)
    right:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 0, 0)
    o.statsHead = W.Label(right, "Gold and stats", 13, { 0.9, 0.78, 0.45 }, "LEFT")
    o.statsHead:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -2)
    o.statsSeen = W.Label(right, "", 11, DIM, "LEFT")
    o.statsSeen:SetPoint("TOPLEFT", o.statsHead, "BOTTOMLEFT", 0, -2)
    o.stats = W.Label(right, "", 12, W.white, "LEFT")
    o.stats:SetPoint("TOPLEFT", o.statsSeen, "BOTTOMLEFT", 0, -6)
    o.stats2 = W.Label(right, "", 12, W.white, "LEFT")
    o.stats2:SetPoint("TOPLEFT", o.stats, "TOPRIGHT", 24, 0)
    o.bagHead = W.Label(right, "Inventory", 13, { 0.9, 0.78, 0.45 }, "LEFT")
    o.bagHead:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -122)
    o.bagSeen = W.Label(right, "", 11, DIM, "LEFT")
    o.bagSeen:SetPoint("TOPLEFT", o.bagHead, "BOTTOMLEFT", 0, -2)
    o.bag, o.bagContent = W.ScrollArea(right)
    o.bag:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -156)
    o.bag:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -8, 0)
    o.bag.wheelStep = 48
    local bg = right:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", o.bag, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", o.bag, "BOTTOMRIGHT", 0, 0)
    bg:SetColorTexture(0, 0, 0, 0.35)
    o.bagRows = {}
    return o
end

--- An inventory row: the item's picture (as the ground draws it), its name and how many.
local function bagRow(o, i)
    local r = o.bagRows[i]
    if r then return r end
    r = L.LinkArea(o.bagContent) -- s6-library round 21: a click opens the item's page (when it has one; round 23: r.go)
    r:SetHeight(26)
    r:SetPoint("TOPLEFT", o.bagContent, "TOPLEFT", 0, -4 - (i - 1) * 26)
    r:SetPoint("TOPRIGHT", o.bagContent, "TOPRIGHT", 0, -4 - (i - 1) * 26)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.text = W.Label(r, "", 12, W.white, "LEFT")
    r.text:SetPoint("LEFT", r, "LEFT", 32, 0)
    o.bagRows[i] = r
    return r
end

local function showOverview(o, e)
    local CH = TK.UI.Character -- s6-modular-g (round 16, separation step 7): the character window's helpers, now global
    local s = e.stats or {}
    local info = {}
    if s.level then info[#info + 1] = "Level " .. s.level end
    if e.legend and e.legend.line2 ~= "" then info[#info + 1] = e.legend.line2 end
    local lines = {}
    if e.legend and e.legend.statusA ~= "" then lines[#lines + 1] = e.legend.statusA end
    if e.legend and e.legend.statusB ~= "" then lines[#lines + 1] = e.legend.statusB end
    o.gear:Fill(e.name, table.concat(info, "   "), table.concat(lines, "\n"), e.equipment, e.look,
        "Equipment " .. X.seenText(e.hasEquipment, e.equipmentSeen) ..
        (e.look == "" and "\nNo look seen yet." or ""))
    L:Say(o.statsSeen, X.seenText(e.hasStats, e.statsSeen))
    if e.hasStats then
        L:Say(o.stats, CH.StatsText(s.hp, s.maxHp, s.mp, s.maxMp, s.experience, s.gold))
        L:Say(o.stats2, CH.StatsText2(s.statA, s.statC, s.statB))
    else
        L:Say(o.stats, "Nothing recorded.")
        o.stats2:SetText("")
    end
    L:Say(o.bagSeen, X.seenText(e.hasInventory, e.inventorySeen))
    local n = #e.inventory
    for i = 1, math.max(n, #o.bagRows) do
        if i <= n then
            local it, r = e.inventory[i], bagRow(o, i)
            TK.LibraryPictures.Show(r.icon, r, 24, "item", it.icon, it.colour or 0)
            r.icon:ClearAllPoints()
            r.icon:SetPoint("CENTER", r, "LEFT", 16, 0)
            L:Say(r.text, X.itemLine(it))
            r.go = L.LinkTo("items", it.item) -- s6-library round 21
            r.tip = L.ItemTip(it.name, nil, it.item) -- round 24 (the owner): its stats on hover
            W.Color(r.text, it.item and L.LINK or W.white)
            r:Show()
        elseif o.bagRows[i] then
            o.bagRows[i]:Hide()
        end
    end
    if n == 0 then
        local r = bagRow(o, 1)
        r.icon:Hide()
        r.go, r.tip = nil, nil
        W.Color(r.text, W.white)
        L:Say(r.text, e.hasInventory and "Empty." or "Nothing recorded.")
        r:Show()
    end
    o.bagContent:SetSize(math.max(1, o.bag:GetWidth()), math.max(1, math.max(n, 1) * 26 + 8))
    o.bag.Refresh()
end

--- The Legend: the Legend tab's list (each mark's symbol and colour, on its parchment), with its Clear.
local function buildLegend(area)
    local g = CreateFrame("Frame", nil, area)
    g:SetAllPoints(area)
    g.head = W.Label(g, "", 14, W.gold, "LEFT")
    g.head:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -4)
    g.clear = X.ClearButton(g)
    g.clear:SetPoint("TOPRIGHT", g, "TOPRIGHT", -8, -2)
    g.list = TK.UI.Character.LegendList(g, 660, 440)
    g.list.sf:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -32)
    return g
end

local function showLegend(g, e)
    L:Say(g.head, e.name .. "'s legend  -  " .. X.seenText(e.legend ~= nil, e.legend and e.legend.seen))
    X.SetClear(g.clear, "legend:" .. e.name, { "legend" }, e.name)
    if L.data and L.data.on and not L.data.on.legend then L.texts[#L.texts + 1] = X.OFF end
    local marks = e.legend and e.legend.marks or {}
    local texts = {}
    for _, m in ipairs(marks) do texts[#texts + 1] = m.text end
    L.texts[#L.texts + 1] = table.concat(texts, "\n")
    -- The list is filled again only when its marks or its character changed: a fill scrolls it to its end (the Legend
    -- tab's way), which the window's refresh in play would otherwise do every few seconds (Astra's P2 on round 1).
    local filled = e.name .. "\n" .. (e.legend and e.legend.seen or "") .. "\n" .. table.concat(texts, "\n")
    if filled == g.filled then return end
    g.filled = filled
    g.list:Fill(#marks, function(i)
        local m = marks[i]
        return m.text, m.symbol, m.colour
    end, e.legend and "No marks." or "Not recorded yet.")
end

function page:build(area)
    self.overview = buildOverview(area)
    self.legend = buildLegend(area)
    self.message = W.Label(area, "", 12, DIM, "LEFT")
    self.message:SetPoint("TOPLEFT", area, "TOPLEFT", 4, -4)
end

function page:show(_, e)
    local _, sub = chosen()
    self.overview:Hide()
    self.legend:Hide()
    self.message:SetText("")
    if e == nil or e.missing then
        L:Say(self.message, "No characters recorded yet.")
    elseif e.loading then
        L:Say(self.message, "Reading the Library...")
    elseif sub == "legend" then
        self.legend:Show()
        showLegend(self.legend, e)
    else
        self.overview:Show()
        showOverview(self.overview, e)
    end
end

L:AddPage(page)
