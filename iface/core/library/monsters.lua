-- The Library's Monsters page (s6-library-pages; the owner, 2026-10-04: "A left list menu on the left with monsters name
-- aphabetically. When you click the name (no dropdown for this you just click the name) The page should display a
-- static graphic of the mob, its id etc. The history. ... a "Drops" section on this page. It will show the item, or
-- items and the % chance that changes over time ... Also show the number of times you killed it ... Maybe xp from it?").
-- The list is every monster kind the Library knows (named by a look, seen on a map, or seen dying), alphabetical; the
-- page shows its picture and look, its kills and experience (the drops tracker: approximate, a group shares experience),
-- its drops with each item's chance (piles seen per kill seen) and the amounts picked up, the server's own drop table
-- when tools/library-seed read it (round 2) and its experience a kill there (s6-library round 15), and the maps it was
-- seen on. Read only: nothing is sent.

local W = TK.UI
local L = TK.Library
local X = L.Lines
local P = TK.LibraryPictures

local DIM = { 0.62, 0.62, 0.66 }
local BOX = 132

local page = { id = "monsters", title = "Monsters", order = 20, list = true, search = "Search monsters",
    empty = "None recorded yet." }

function page:build(area)
    self.box = TK.LibraryPictureBox(area, BOX)
    self.box:SetPoint("TOPLEFT", area, "TOPLEFT", 4, -4)
    self.name = W.Label(area, "", 18, W.gold, "LEFT")
    self.name:SetPoint("TOPLEFT", self.box, "TOPRIGHT", 14, -2)
    self.look = W.Label(area, "", 11, DIM, "LEFT")
    self.look:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -4)
    self.kills = W.Label(area, "", 13, W.white, "LEFT")
    self.kills:SetPoint("TOPLEFT", self.look, "BOTTOMLEFT", 0, -10)
    self.xp = W.Label(area, "", 12, W.white, "LEFT")
    self.xp:SetPoint("TOPLEFT", self.kills, "BOTTOMLEFT", 0, -6)
    self.xp:SetWidth(520)
    self.xp:SetWordWrap(true)
    self.seen = W.Label(area, "", 11, DIM, "LEFT")
    self.seen:SetPoint("TOPLEFT", self.xp, "BOTTOMLEFT", 0, -6)
    -- Each section's Clear (head note 1): the monsters' names, and the drops and kills, for this server.
    self.clearDrops = X.ClearButton(area, 130)
    self.clearDrops:SetPoint("TOPRIGHT", area, "TOPRIGHT", -8, -2)
    self.clearNames = X.ClearButton(area, 130)
    self.clearNames:SetPoint("TOPRIGHT", self.clearDrops, "BOTTOMRIGHT", 0, -4)
    self.detail = TK.LibraryDetail(area, BOX + 14)
end

--- A drop's amounts as picked up: "1-3 (4 picked up)", or "not picked up yet".
local function amounts(d)
    if (d.amounts or 0) == 0 then return "not picked up yet" end
    return X.range(d.least, d.most) .. "  (" .. d.amounts .. " picked up)" -- s6-library round 15: X.range
end

function page:show(_, m)
    X.SetClear(self.clearNames, "monsters", { "creature_names" }, nil, "Clear Names")
    X.SetClear(self.clearDrops, "drops", { "drops" }, nil, "Clear Drops")
    local d = self.detail
    d:Begin(L.entryKey)
    if m == nil or m.missing or m.loading then
        self.box:SetPicture(nil)
        L:Say(self.name, m and m.loading and "Reading the Library..." or "")
        for _, fs in ipairs({ self.look, self.kills, self.xp, self.seen }) do fs:SetText("") end
        if m == nil then d:Text("None recorded yet.", "dim") end
        d:End()
        return
    end
    self.box:SetPicture("creature", m.picture, m.colour)
    L:Say(self.name, m.name)
    -- s6-library round 18 (the owner, on the monster page's wordy lines: "just the number"): label and value.
    L:Say(self.look, "Picture " .. m.picture .. ", colour " .. m.colour)
    if m.hasDrops then
        L:Say(self.kills, "Kills: " .. X.thousands(m.kills) .. "    With XP: " .. X.thousands(m.yours)) -- group kills too
        L:Say(self.xp, m.yours > 0 and ("Experience: ~" .. X.thousands(m.xp)
            .. (m.xpLeast ~= m.xpMost and (" (" .. X.range(m.xpLeast, m.xpMost) .. ")") or "")) or "Experience: none seen")
        L:Say(self.seen, "Last kill: " .. m.seen)
    else
        L:Say(self.kills, "Kills: none seen")
        self.xp:SetText("")
        self.seen:SetText("")
    end
    if L.data and L.data.on and not L.data.on.drops then d:Text("Drops and kills: " .. X.OFF, "note") end
    d:Header("Drops")
    if not m.hasDrops or #m.drops == 0 then
        d:Text("None seen.", "dim")
    else
        d:Row({ "Item", "Chance", "Seen", "Amount" }, { 0, 240, 320, 440 })
        -- FOR s6-library-pages (s6-library round 19, cross-links): an item, and a map below, open their own pages.
        for _, x in ipairs(m.drops) do
            d:Row({ x.name, x.chance, x.piles .. " of " .. X.thousands(m.kills) .. " kills", amounts(x) }, { 0, 240, 320, 440 },
                function() return P.Picture("item", x.picture, x.colour) end, L.LinkTo("items", x.item))
        end
    end
    -- Round 2 (the owner's prefill) and s6-library round 15: what the server's own files say of it (tools/library-seed),
    -- apart from what play saw above: its experience a kill (Mobs) and its drop table. s6-library round 18: one section,
    -- label and value ("Experience: 480,000", the owner).
    if (m.serverXp or 0) > 0 or #m.server > 0 then
        d:Header("From the server's files")
        if (m.serverXp or 0) > 0 then d:Text("Experience: " .. X.thousands(m.serverXp), "text") end
        if #m.server > 0 then
            d:Row({ "Item", "Chance", "Amount" }, { 0, 240, 320 })
            for _, x in ipairs(m.server) do
                d:Row({ x.name, x.chance, X.range(x.least, x.most) .. (x.rare and "  (rare)" or "") }, { 0, 240, 320 },
                    function() return P.Picture("item", x.picture, x.colour) end, L.LinkTo("items", x.item))
            end
        end
    end
    d:Header("Seen on")
    if L.data and L.data.on and not L.data.on.map_creatures then d:Text("Creatures per map: " .. X.OFF, "note") end
    if #m.maps == 0 then d:Text("No map recorded.", "dim") end
    for _, map in ipairs(m.maps) do
        d:Text(map.name .. "  at " .. map.x .. ", " .. map.y .. X.rowStamp(map.seen), "text", 8, L.LinkTo("maps", map.map))
    end
    d:End()
end

L:AddPage(page)
