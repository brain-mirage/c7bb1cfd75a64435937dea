-- The Library's Players page (s6-library rounds 2-11's list of lines; rebuilt by s6-library-pages round 2, the owner,
-- 2026-10-04: "Players are playername then you click on them to show a character page of what they had when you seen
-- them, also have a chat history "Whispers" if they ever messaged you. And a last sceen etc"). The list is every player
-- the Library knows, by name: those seen, and those who whispered the player. The page draws them as the Character tab
-- draws a character (library/gear.lua): their figure in their look when last seen, and the items the look window showed
-- them wearing (when the player looked at them); beside it, where and when they were last seen, their whispers, newest
-- first, and their legend as the look window showed it. Read only: nothing is sent.

local W = TK.UI
local L = TK.Library
local X = L.Lines

local DIM = { 0.62, 0.62, 0.66 }
local PLACE_WIDTH = 234 -- the right column's lines (when and where seen), wrapped at this width

local page = { id = "players", title = "Players", order = 70, list = true, search = "Search players",
    empty = "None recorded yet." }

function page:build(area)
    self.gear = TK.LibraryGear(area)
    local right = CreateFrame("Frame", nil, area)
    right:SetPoint("TOPLEFT", area, "TOPLEFT", 454, 0)
    right:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 0, 0)
    self.seen = W.Label(right, "", 12, W.white, "LEFT")
    self.seen:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -2)
    self.seen:SetWidth(PLACE_WIDTH)
    self.seen:SetWordWrap(true)
    -- s6-library round 21 (links between the pages; FOR s6-library-pages): where they were seen, its own line, which opens
    -- the map's page when the Library has the map.
    self.place = W.Label(right, "", 12, W.white, "LEFT")
    self.place:SetPoint("TOPLEFT", self.seen, "BOTTOMLEFT", 0, -2)
    self.place:SetWidth(PLACE_WIDTH) -- Astra's P3: the column's width, wrapped (a long map name)
    self.place:SetWordWrap(true)
    self.placeLink = L.LinkArea(right)
    -- Each section's Clear (head note 1): the players seen (with their looks), and the whispers, for this server. Round 21:
    -- below the place, however many lines it takes.
    self.clearPlayers = X.ClearButton(right, 112)
    self.clearPlayers:SetPoint("TOPLEFT", self.place, "BOTTOMLEFT", 0, -8)
    self.clearWhispers = X.ClearButton(right, 112)
    self.clearWhispers:SetPoint("LEFT", self.clearPlayers, "RIGHT", 6, 0)
    self.detail = TK.LibraryDetail(right)
    -- Astra's P3 on round 21: the whispers start below the Clears, however many lines the place takes.
    self.detail.sf:ClearAllPoints()
    self.detail.sf:SetPoint("TOPLEFT", self.clearPlayers, "BOTTOMLEFT", 0, -8)
    self.detail.sf:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -8, 0)
    self.message = W.Label(area, "", 12, DIM, "LEFT")
    self.message:SetPoint("TOPLEFT", area, "TOPLEFT", 4, -4)
end

function page:show(area, p)
    X.SetClear(self.clearPlayers, "players", { "players" }, nil, "Clear Players")
    X.SetClear(self.clearWhispers, "whispers", { "whispers" }, nil, "Clear Whispers")
    local d = self.detail
    d:Begin(L.entryKey)
    self.message:SetText("")
    local shown = p ~= nil and not p.missing and not p.loading
    self.gear:SetShown(shown)
    self.place:SetText("")
    self.placeLink:Hide()
    if not shown then
        L:Say(self.message, p and p.loading and "Reading the Library..." or "None recorded yet.")
        self.seen:SetText("")
        d:End()
        return
    end
    local sheet = p.sheet
    local lines = {}
    if sheet then
        for _, l in ipairs({ sheet.line1, sheet.line2, sheet.line3 }) do
            if l ~= "" then lines[#lines + 1] = l end
        end
    end
    self.gear:Fill(p.name, "", table.concat(lines, "\n"), p.equipment, p.look or "",
        sheet and ("Looked at " .. sheet.seen) or "Not looked at yet.")
    if p.known then
        L:Say(self.seen, "Last seen " .. p.seen)
        L:Say(self.place, "on " .. p.map .. " at " .. p.x .. ", " .. p.y)
        W.Color(self.place, p.mapId and L.LINK or W.white)
        L.LinkOver(self.placeLink, self.place, L.LinkTo("maps", p.mapId), PLACE_WIDTH)
    else
        L:Say(self.seen, "Not seen (whispers only)") -- s6-library round 18: label and value
    end
    if L.data and L.data.on and not L.data.on.players then d:Text("Players seen: " .. X.OFF, "note") end
    if L.data and L.data.on and not L.data.on.whispers then d:Text("Whispers: " .. X.OFF, "note") end
    d:Header("Whispers")
    if #p.whispers == 0 then d:Text("None.", "dim") end
    for _, w in ipairs(p.whispers) do
        d:Text(w.seen, "dim")
        d:Text(w.text, "text", 8)
    end
    if sheet and #sheet.legend > 0 then
        d:Header("Legend")
        for _, m in ipairs(sheet.legend) do d:Text(m.text, "text", 8) end
    end
    d:End()
end

L:AddPage(page)
