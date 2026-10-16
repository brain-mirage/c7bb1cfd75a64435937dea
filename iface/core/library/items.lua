-- The Library's Items page (s6-library-pages; the owner, 2026-10-04: "Items is a plain list of items, a image, if it was
-- seen in a shop and what npc had it, if a character has it etc" and "In items you can search for an item and use it to
-- tell you who sells it"). The list is every item the Library knows (its name learned from the inventory, or seen in a
-- shop, dropped, or held by a character), with its picture; the search narrows it by name. The page shows the item, the
-- shops that list it with their NPC, map and price, the monsters seen dropping it (and, s6-library round 15, those whose
-- drop table in the server's files lists it), and which characters hold it. Read only: nothing is sent.

local W = TK.UI
local L = TK.Library
local X = L.Lines
local P = TK.LibraryPictures

local DIM = { 0.62, 0.62, 0.66 }
local BOX = 84

local page = { id = "items", title = "Items", order = 30, list = true, search = "Search items (who sells it?)",
    empty = "None recorded yet." }

function page.image(row) return P.Picture("item", row.picture, row.colour) end

function page:build(area)
    self.box = TK.LibraryPictureBox(area, BOX)
    self.box:SetPoint("TOPLEFT", area, "TOPLEFT", 4, -4)
    self.name = W.Label(area, "", 18, W.gold, "LEFT")
    self.name:SetPoint("TOPLEFT", self.box, "TOPRIGHT", 14, -4)
    self.look = W.Label(area, "", 11, DIM, "LEFT")
    self.look:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -4)
    self.summary = W.Label(area, "", 12, W.white, "LEFT")
    self.summary:SetPoint("TOPLEFT", self.look, "BOTTOMLEFT", 0, -8)
    self.clear = X.ClearButton(area, 130)
    self.clear:SetPoint("TOPRIGHT", area, "TOPRIGHT", -8, -2)
    self.detail = TK.LibraryDetail(area, BOX + 14)
end

local WHERE = { equipped = "equipped", bag = "in the bag", bank = "in the bank" }

function page:show(_, it)
    X.SetClear(self.clear, "items", { "item_names" }, nil, "Clear Names")
    local d = self.detail
    d:Begin(L.entryKey)
    if it == nil or it.missing or it.loading then
        self.box:SetPicture(nil)
        L:Say(self.name, it and it.loading and "Reading the Library..." or "")
        self.look:SetText("")
        self.summary:SetText("")
        if it == nil then d:Text(L.filters.items and L.filters.items ~= "" and "No item by that name." or "None recorded yet.", "dim") end
        d:End()
        return
    end
    self.box:SetPicture("item", it.picture, it.colour)
    L:Say(self.name, it.name)
    L:Say(self.look, "Picture " .. (it.picture % 0x4000) .. ", colour " .. it.colour)
    -- s6-library round 22 (QA's next41 note): the shops, each once (it.shops), not the seller rows: a shop listing the
    -- item twice counted twice ("Shops: 19" beside the list's "Sold in 18 shops").
    local sold = #it.sellers
    L:Say(self.summary, "Shops: " .. (it.shops == 0 and "none seen" or it.shops)) -- s6-library round 18: label and value
    if L.data and L.data.on and not L.data.on.item_names then d:Text("Item names: " .. X.OFF, "note") end
    -- s6-library round 24 (the owner): what the server's tables say of it, formatted as the tooltips are (L.ItemStats);
    -- while they are read, the page is shown again when they are.
    local item = tonumber(L.entryKey)
    local stats, reading = L.ItemStats(it.name, item)
    d:Header("Stats")
    if reading then
        d:Text("Reading...", "dim")
        L.Await(function() if not select(2, L.ItemStats(it.name, item)) then return true end end, function() L:Refresh() end)
    elseif not stats then
        d:Text("Unknown", "dim")
    else
        if stats.description ~= "" then d:Text(stats.description, "dim") end
        for _, line in ipairs(stats.lines) do d:Text(line, "text", 8) end
    end
    d:Header("Sold by")
    if L.data and L.data.on and not L.data.on.shops then d:Text("Shops: " .. X.OFF, "note") end
    if sold == 0 then d:Text("None seen.", "dim") end
    -- FOR s6-library-pages (s6-library round 19, cross-links): a seller, a monster and a character open their own pages.
    for _, s in ipairs(it.sellers) do
        d:Row({ s.npc, s.map, X.thousands(s.price) .. " gold", s.title ~= "" and s.title or "", s.seen == X.FROM_FILES and "" or X.stamp(s.seen) },
            { 0, 170, 360, 450, 520 }, nil, L.LinkTo("npcs", s.key))
    end
    d:Header("Dropped by")
    if #it.droppers == 0 then d:Text("None seen.", "dim") end
    for _, m in ipairs(it.droppers) do
        d:Row({ m.monster, m.chance, m.piles .. " of " .. X.thousands(m.kills) .. " kills" }, { 0, 260, 340 }, nil,
            L.LinkTo("monsters", m.look))
    end
    -- s6-library round 15 (FOR s6-library-pages): the monsters whose drop table in the server's files lists it (read by
    -- tools/library-seed), shown apart from those seen dropping it above; a row for each of a table's rows of it.
    if #it.serverDroppers > 0 then
        d:Header("Dropped by (the server's files)")
        d:Row({ "Monster", "Chance", "Amount" }, { 0, 260, 340 })
        for _, m in ipairs(it.serverDroppers) do
            d:Row({ m.monster, m.chance, X.range(m.least, m.most) .. (m.rare and "  (rare)" or "") }, { 0, 260, 340 }, nil,
                L.LinkTo("monsters", m.look))
        end
    end
    d:Header("Your characters")
    if #it.holders == 0 then d:Text("None.", "dim") end
    for _, h in ipairs(it.holders) do
        d:Row({ h.character, "x" .. X.thousands(h.count), WHERE[h.where] or h.where, "seen " .. h.seen }, { 0, 170, 240, 360 }, nil,
            L.LinkTo("characters", h.character))
    end
    d:End()
end

L:AddPage(page)
