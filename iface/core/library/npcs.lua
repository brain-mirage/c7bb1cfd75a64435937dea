-- The Library's NPCs page (s6-library-pages; the owner, 2026-10-04: "have a npc tab and you can sort it by npcs that
-- have a shop. You can search for npcs by name" and "npcs has a image of them, where they are, etc, If they have a shop
-- list the items they sell and the amount"). The list is every NPC the maps' records or the shops know, by name then
-- map (the not-yet-looked-at last); the search narrows it by name, and "Only NPCs with a shop" keeps those with a shop
-- list. The page shows the NPC's picture, where it was last seen, and its shop list with each item's price (the list's
-- u32; a shop shows no stock). Read only: nothing is sent.

local W = TK.UI
local L = TK.Library
local X = L.Lines
local P = TK.LibraryPictures

local DIM = { 0.62, 0.62, 0.66 }
local BOX = 132

local page = { id = "npcs", title = "NPCs", order = 40, list = true, search = "Search NPCs", check = "Only NPCs with a shop",
    empty = "None recorded yet." }

function page:build(area)
    self.box = TK.LibraryPictureBox(area, BOX)
    self.box:SetPoint("TOPLEFT", area, "TOPLEFT", 4, -4)
    self.name = W.Label(area, "", 18, W.gold, "LEFT")
    self.name:SetPoint("TOPLEFT", self.box, "TOPRIGHT", 14, -2)
    self.place = W.Label(area, "", 13, W.white, "LEFT")
    self.place:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -8)
    -- FOR s6-library-pages (s6-library round 19, cross-links): the NPC's map opens its page (a click on the place line).
    self.placeLink = L.LinkArea(area)
    self.seen = W.Label(area, "", 11, DIM, "LEFT")
    self.seen:SetPoint("TOPLEFT", self.place, "BOTTOMLEFT", 0, -6)
    self.look = W.Label(area, "", 11, DIM, "LEFT")
    self.look:SetPoint("TOPLEFT", self.seen, "BOTTOMLEFT", 0, -4)
    self.clear = X.ClearButton(area, 130)
    self.clear:SetPoint("TOPRIGHT", area, "TOPRIGHT", -8, -2)
    self.detail = TK.LibraryDetail(area, BOX + 14)
end

function page:show(_, n)
    X.SetClear(self.clear, "shops", { "shops" }, nil, "Clear Shops")
    local d = self.detail
    d:Begin(L.entryKey)
    if n == nil or n.missing or n.loading then
        self.box:SetPicture(nil)
        self.placeLink:Hide()
        L:Say(self.name, n and n.loading and "Reading the Library..." or "")
        for _, fs in ipairs({ self.place, self.seen, self.look }) do fs:SetText("") end
        if n == nil then d:Text(L.flags.npcs and "No NPC with a shop seen yet." or "None recorded yet.", "dim") end
        d:End()
        return
    end
    self.box:SetPicture("creature", n.picture, n.colour)
    L:Say(self.name, n.name)
    if n.hasPlace then
        L:Say(self.place, n.map .. "  at " .. n.x .. ", " .. n.y)
        L:Say(self.seen, X.stamp(n.seen))
    else
        L:Say(self.place, n.map)
        L:Say(self.seen, "Place: not recorded") -- s6-library round 18: label and value
    end
    -- s6-library round 21 (the head's P3): a link only while the Library has the map (Clear Map Data removes it).
    W.Color(self.place, n.mapId and L.LINK or W.white)
    L.LinkOver(self.placeLink, self.place, L.LinkTo("maps", n.mapId))
    L:Say(self.look, "Picture " .. n.picture .. ", colour " .. n.colour)
    if L.data and L.data.on and not L.data.on.map_npcs then d:Text("NPCs: " .. X.OFF, "note") end
    if L.data and L.data.on and not L.data.on.shops then d:Text("Shops: " .. X.OFF, "note") end
    local shop = n.shop
    d:Header(shop and ("Shop" .. (shop.title ~= "" and ("  (\"" .. shop.title .. "\")") or "") .. "  -  " .. X.stamp(shop.seen)) or "Shop")
    if not shop then
        d:Text("None seen.", "dim")
    elseif #shop.items == 0 then
        d:Text("Empty.", "dim")
    else
        d:Row({ "Item", "Price", "Description" }, { 0, 220, 320 })
        for _, it in ipairs(shop.items) do
            -- FOR s6-library-pages (s6-library round 19, cross-links): an item opens its own page.
            d:Row({ it.name, X.thousands(it.price) .. " gold", it.description }, { 0, 220, 320 },
                function() return P.Picture("item", it.picture, it.colour) end, L.LinkTo("items", it.item))
        end
    end
    d:End()
end

L:AddPage(page)
