-- The Library window (s6-library round 2; the owner's head note 2): what this client learned on a server, browsed
-- without asking the server anything. A Library button on the login screen and in the Game Menu open it; its server
-- chooser starts on the login screen's server, and it works at the login screen with no connection (it reads the
-- server's Library file; in the world, the playing session's copy). A page whose tracker is off for that server says
-- so, and shows what was recorded before.
--
-- s6-library-pages (the owner's refinement pass, 2026-10-04: "It looks very bad"): the window is the shell of its pages,
-- one file each under core/library/. A list page (Characters, Monsters, Items, NPCs) has a column on the left, a search
-- box over a list, and its page on the right; a click on a name shows it. The characters open into Overview, History,
-- Spells and Legend. The Spells, Maps and Players pages are lines (library/lines.lua). Also under core/library/: the
-- Library's map markers and the Export and Import dialogs.

local W = TK.UI
local H = __tk

local L = { page = "characters", character = nil, search = "", server = nil, data = nil, texts = {}, clears = {},
    selected = {}, filters = {}, flags = {} }
TK.Library = L

local WIDTH, HEIGHT, LEFT = 980, 640, 230

-- ----- the file jobs (round 3, review r2 finding 1) -----
-- The Library's files are read, written and chosen off the UI: a click returns at once and never holds the game's
-- input, its packets or its timers. What waits for an answer is asked again each frame until it has one (s6-ui-core,
-- after build 41: by the shared TK.Await, core/await.lua; the Library counts its own waits for L.Busy).

local waiting = 0

--- Calls done with the answer when there is one: a file job's (its number), or what ask returns once it is not nil.
function L.Await(job, done)
    local ask = type(job) == "function" and job or function() return H:LibraryJob(job) end
    waiting = waiting + 1
    TK.Await(ask, function(answer)
        waiting = waiting - 1
        done(answer)
    end)
end

--- Whether something still waits for a file, or the open window for its data (tests).
function L.Busy()
    return waiting > 0 or (L.frame ~= nil and L.frame:IsShown() and L.data ~= nil and L.data.loading == true)
end

--- The login screen's server (its Library key), or the first one a Library exists for.
--- Round 4 (review r3 finding 1): nil while the login screen's host name is looked up (in the background).
function L.DefaultServer()
    local target = TK.Login and TK.Login.Target and TK.Login.Target()
    if target then return H:LibraryServerKey(target.host, target.port) end
    local servers = H:GetLibraryServers(false)
    return servers[1] and servers[1].key or ""
end

-- ----- the pages -----

L.PAGES = {}
local PAGE = {}

--- Adds a page (each file under core/library/ adds its own): { id, title, order, and either
---  - lines(): the page as lines (library/lines.lua); or
---  - list = true: a left list of GetLibraryList's rows for the page, with search (the search box's hint), check (a
---    check box's label: the list's flag), empty (what an empty list says), rows(rows) (the rows as the list shows
---    them, default the C# rows), image(row) (a row's picture), click(row) (default: the row is selected), entry(key)
---    (the page and key whose entry shows, default this page's and the selected key), build(area) (its frame on the
---    right, made once), show(area, entry), and mode() ("lines" while the right side shows lines; then lines()). }
function L:AddPage(p)
    PAGE[p.id] = p
    self.PAGES[#self.PAGES + 1] = p
    table.sort(self.PAGES, function(a, b) return a.order < b.order end)
end

function L:Page(id) return PAGE[id] end

--- A label's text, also kept for the page's texts (tests and the screenshots read them with L:Texts()).
function L:Say(fs, text)
    fs:SetText(text or "")
    if text and text ~= "" then self.texts[#self.texts + 1] = text end
end

-- ----- the window -----

local frame

--- The left column and the right side for the page: a list page has both, a page of lines the whole width.
local function layout(page)
    frame.left:SetShown(page.list == true)
    frame.area:ClearAllPoints()
    frame.area:SetPoint("TOPLEFT", frame, "TOPLEFT", page.list and (LEFT + 30) or 16, -112)
    frame.area:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 40)
    for _, b in ipairs(frame.tabs) do
        b:SetSelected(b.page == L.page)
    end
    if page.list then
        frame.searchHint:SetText(page.search or "")
        frame.check:SetShown(page.check ~= nil)
        if page.check then
            frame.check:SetLabel(page.check)
            frame.check:SetChecked(L.flags[page.id] == true)
        end
        local text = page.id == "characters" and L.search or (L.filters[page.id] or "")
        if frame.search:GetText() ~= text then
            frame.searching = true
            frame.search:SetText(text)
            frame.searching = false
        end
        frame.list.sf:ClearAllPoints()
        frame.list.sf:SetPoint("TOPLEFT", frame.left, "TOPLEFT", 0, page.check and -74 or -48)
        frame.list.sf:SetPoint("BOTTOMRIGHT", frame.left, "BOTTOMRIGHT", -8, 0)
    end
end

--- The right side's lines (the page's, or a list page's lines mode) laid out in the scroll area.
local function showLines()
    frame.lines:Show()
    local width = frame.scroll:GetWidth()
    if width <= 0 then width = frame.area:GetWidth() - 8 end
    L.Lines.render(frame.content, frame.pool, width)
    frame.scroll.Refresh()
end

--- The page's own frame on the right, made once; the others' hidden.
local function pageFrame(page)
    if not page.frame then
        page.frame = CreateFrame("Frame", nil, frame.area)
        page.frame:SetAllPoints(frame.area)
        page:build(page.frame)
    end
    for _, p in pairs(PAGE) do
        if p.frame then p.frame:SetShown(p == page) end
    end
    return page.frame
end

local function hideFrames()
    for _, p in pairs(PAGE) do
        if p.frame then p.frame:Hide() end
    end
end

--- Reads the server's Library again and shows the page. While its file is read (or, in the world, until the session's
--- first copy comes), the window says so and asks again (round 3, review r2 finding 1).
function L:Refresh()
    if not frame then return end
    local started = os.clock()
    local page = PAGE[self.page] or PAGE.characters
    self.page = page.id
    self.clears, self.texts = {}, {}
    L.Lines.Begin()
    -- Round 4 (review r3 finding 1): while the login screen's host name is looked up, the window waits for its address.
    -- Round 12: only that page's tables; a list page's come from GetLibraryList, so it asks for the characters only.
    self.data = self.resolving and { loading = true, live = false, on = {} } or H:GetLibrary(self.server, page.list and "characters" or page.id)
    layout(page)
    local reading = self.resolving and "Looking up the server's address..." or "Reading the Library..."
    self.rows, self.entry, self.entryPage, self.entryKey = nil, nil, nil, nil
    if self.data.loading then
        frame.list:SetRows({}, nil, "")
        hideFrames()
        L.Lines.add(reading, "dim")
        showLines()
    elseif page.list then
        local rows = H:GetLibraryList(self.server, page.id, self.filters[page.id] or "", self.flags[page.id] == true)
        self.rows = rows
        local shown = rows.loading and {} or (page.rows and page:rows(rows) or rows)
        if self.selected[page.id] == nil and shown[1] then self.selected[page.id] = shown[1].key end
        local same = self.listShown == page.id .. "\n" .. (self.filters[page.id] or "")
        self.listShown = page.id .. "\n" .. (self.filters[page.id] or "")
        frame.list:SetRows(shown, self.selected[page.id], rows.loading and reading or page.empty, same, page.image)
        if rows.loading then
            hideFrames()
            L.Lines.add(reading, "dim")
            showLines()
        elseif page.mode and page:mode() == "lines" then
            hideFrames()
            page:lines()
            showLines()
        else
            frame.lines:Hide()
            local area = pageFrame(page)
            local key = self.selected[page.id]
            if key ~= nil then
                local entryPage, entryKey = page.id, key
                if page.entry then entryPage, entryKey = page:entry(key) end
                self.entryPage, self.entryKey = entryPage, entryKey
                self.entry = H:GetLibraryEntry(self.server, entryPage, entryKey)
            end
            page:show(area, self.entry)
        end
    else
        hideFrames()
        page:lines()
        showLines()
    end
    frame.live:SetText(self.data.live and "Live" or "From file") -- s6-library round 18: shorter (FOR s6-library-pages)
    -- Round 11: a Library filled from the server's files can take seconds to show (its maps page, thousands of lines);
    -- the world's refresh below then comes no sooner than 20 times that, so it never takes more than a twentieth of the
    -- UI's time. A small Library keeps the 3 seconds.
    L.every = math.max(3, (os.clock() - started) * 20)
end

--- In the world: whether the session's copy changed what the window shows (Round 12: the same copy gives the same
--- tables, so nothing is drawn again for nothing).
local function changed()
    local page = PAGE[L.page]
    if H:GetLibrary(L.server, page.list and "characters" or page.id) ~= L.data then return true end
    if not page.list then return false end
    if H:GetLibraryList(L.server, page.id, L.filters[page.id] or "", L.flags[page.id] == true) ~= L.rows then return true end
    return L.entryKey ~= nil and H:GetLibraryEntry(L.server, L.entryPage, L.entryKey) ~= L.entry
end

--- The chooser's servers, and whether more may come (round 4, review r3 finding 1: the folder is listed on the
--- Library's queue and saved host names are looked up in the background; rescan starts a new listing).
local function serverValues(rescan)
    local values = {}
    local found = false
    local servers = H:GetLibraryServers(rescan == true)
    for _, s in ipairs(servers) do
        values[#values + 1] = { value = s.key, text = s.name == s.key and s.key or (s.name .. "  (" .. s.key .. ")") }
        if s.key == L.server then found = true end
    end
    if not found and L.server and L.server ~= "" then values[#values + 1] = { value = L.server, text = L.server } end
    return values, servers.pending
end

--- Round 4: the chooser filled again once the listing and the lookups are done.
local function awaitServers()
    if L.serversAwaited then return end
    L.serversAwaited = true
    L.Await(function()
        local _, pending = serverValues(false)
        if not pending then return true end
    end, function()
        L.serversAwaited = nil
        if frame and frame:IsShown() then
            frame.server:SetValues((serverValues(false)))
            frame.server:SetValue(L.server)
        end
    end)
end

local function build()
    frame = W.Window("TKLibraryFrame", "Library", WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    L.frame = frame
    frame.server = W.Dropdown(frame, "Server", {}, 340, function(v) L:SelectServer(v) end)
    frame.server:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
    frame.live = W.Label(frame, "", 11, { 0.65, 0.65, 0.7 }, "LEFT")
    frame.live:SetPoint("LEFT", frame.server, "RIGHT", 16, -8)
    frame.tabs = {}
    local x = 16
    for _, p in ipairs(L.PAGES) do
        local b = W.Tab(frame, p.title, 104, 24, function() L:Select(p.id) end) -- s6-ui-core (round 61): the shared tab
        b.page = p.id
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -82)
        x = x + 108
        frame.tabs[#frame.tabs + 1] = b
        frame["tab_" .. p.id] = b
    end
    -- The left column: the page's search box, its check box when it has one, then its list.
    local left = CreateFrame("Frame", nil, frame)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -112)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 40)
    left:SetWidth(LEFT)
    frame.left = left
    frame.searchHint = W.Label(left, "", 11, { 0.75, 0.75, 0.8 }, "LEFT")
    frame.searchHint:SetPoint("TOPLEFT", left, "TOPLEFT", 0, 0)
    frame.search = W.EditBox(left, LEFT - 8, 22)
    frame.search:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -16)
    frame.search:SetScript("OnTextChanged", function(self) if not frame.searching then L:Search(self:GetText()) end end)
    frame.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame.check = W.Check(left, "", function(on)
        L.flags[L.page], L.selected[L.page] = on, nil
        L:Refresh()
    end)
    frame.check:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -46)
    frame.list = TK.LibraryList(left, function(row)
        local page = PAGE[L.page]
        L.pending = nil
        if page.click then page:click(row) else L.selected[page.id] = row.key end
        L:Refresh()
    end)
    -- The right side: a page's own frame, or the lines' scroll area (in a frame of its own, so its bar hides with it).
    frame.area = CreateFrame("Frame", nil, frame)
    frame.lines = CreateFrame("Frame", nil, frame.area)
    frame.lines:SetAllPoints(frame.area)
    frame.scroll, frame.content = W.ScrollArea(frame.lines)
    frame.scroll:SetPoint("TOPLEFT", frame.lines, "TOPLEFT", 0, 0)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.lines, "BOTTOMRIGHT", -8, 0)
    frame.pool = {}
    -- Round 12: a long page draws the lines in view; the scroll is looked at each frame, and only its moves redraw.
    frame.content.scroll = frame.scroll
    frame.content:SetScript("OnUpdate", function(self) if self.virtual then L.Lines.drawVisible(self) end end)
    local close = W.Button(frame, "Close", 90, 24, nil, function() frame:Hide() end)
    close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 10)
    frame.refresh = W.Button(frame, "Refresh", 90, 24, nil, function() L:Refresh() end)
    frame.refresh:SetPoint("RIGHT", close, "LEFT", -8, 0)
    -- In the world, the playing session's copy is read again every few seconds while the window shows; while the
    -- Library is being read, a few times a second (round 3). Round 12: the page is drawn again only when the session made
    -- a new copy (the C# side gives the same tables for the same copy).
    local since = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        since = since + (elapsed or 0)
        local loading = L.data ~= nil and (L.data.loading or (L.rows ~= nil and L.rows.loading) or (L.entry ~= nil and L.entry.loading))
        if since < (loading and 0.1 or L.every or 3) then return end
        since = 0
        if loading then L:Refresh()
        elseif L.data and L.data.live and L.search == "" and changed() then L:Refresh() end
    end)
end

--- Opens the window on a server (default: the login screen's), on its characters page.
function L:Open(server)
    if not frame then build() end
    self.server = server or self.DefaultServer()
    self.resolving = self.server == nil
    if self.resolving then
        -- Round 4 (review r3 finding 1): the window opens at once and turns to the login screen's server when its
        -- address is known.
        self.server = ""
        L.Await(function() return self.DefaultServer() end, function(key)
            if not self.resolving then return end
            self.resolving = false
            frame.server:SetValues((serverValues(false)))
            frame.server:SetValue(key)
            self:SelectServer(key)
        end)
    end
    self.search, self.pending = "", nil
    local values, pending = serverValues(true)
    frame.server:SetValues(values)
    frame.server:SetValue(self.server)
    if pending then awaitServers() end
    frame:Show()
    TK.FitToScreen(frame)
    self:Refresh()
end

function L:Toggle()
    if frame and frame:IsShown() then frame:Hide() else self:Open() end
end

function L:IsOpen() return frame ~= nil and frame:IsShown() end

--- Another server: its pages start again (nothing chosen, no search).
function L:SelectServer(key)
    self.server, self.character, self.search, self.pending, self.resolving = key, nil, "", nil, false
    self.selected, self.filters = {}, {}
    self:Refresh()
end

function L:Select(page)
    self.page, self.pending = page, nil
    self:Refresh()
end

--- The Characters page on a character (its Overview first).
function L:SelectCharacter(name, sub)
    self.page, self.character, self.pending, self.search = "characters", name, nil, ""
    self.selected.characters = name .. "\n" .. (sub or "overview")
    self:Refresh()
end

--- s6-library round 19 (cross-links, the owner's Library requests): another page on one of its entries (a name on one
--- page that is that page's entry: an NPC on a map, a monster's maps, an item's sellers...), its search and check box
--- (Astra's P3: "Only NPCs with a shop") cleared so the entry is in its list, and the list scrolled to it. key: the
--- page's list key (characters: the name).
function L:Go(page, key)
    if not PAGE[page] or key == nil then return end
    self.pending = nil
    if page == "characters" then return self:SelectCharacter(key) end
    self.page, self.filters[page], self.flags[page], self.selected[page] = page, nil, nil, tostring(key)
    self:Refresh()
    frame.list:ShowSelected()
end

-- ----- s6-library round 23 (s6-optimize's E3): the links between the pages, one set of helpers for every page -----

--- A link's colour: a name that opens its own entry (FOR s6-library-pages: round 19's, from detail.lua).
L.LINK = { 0.55, 0.8, 1 }

--- What a link to page's entry key runs (L:Go), or nil without a key: a link only where the entry exists (round 21).
function L.LinkTo(page, key)
    if key == nil then return nil end
    return function() L:Go(page, key) end
end

--- A link's scripts on button b: a click runs its go (L.LinkTo's); round 24: the pointer on it shows its tip (a function
--- that fills GameTooltip for b, L.ItemTip's), when it has one. A gear slot takes them too (library/gear.lua).
function L.LinkScripts(b)
    b:SetScript("OnClick", function(self) if self.go then self.go() end end)
    b:SetScript("OnEnter", function(self) if self.tip then self.tip(self) end end)
    b:SetScript("OnLeave", function(self) if self.tip then GameTooltip:Hide() end end)
end

--- A link's click area on parent: L.LinkScripts', and lit while the pointer is on it.
function L.LinkArea(parent)
    local b = CreateFrame("Button", nil, parent)
    local lit = b:CreateTexture(nil, "HIGHLIGHT")
    lit:SetAllPoints(b)
    lit:SetColorTexture(1, 1, 1, 0.08)
    L.LinkScripts(b)
    return b
end

--- Link area b placed on target's top left, width by height, above target's siblings, running go and showing tip; shown
--- only with a go or a tip (round 24: an item the Library knows nothing of has a tip and no link). text names it (the
--- tests and the live check find a link by it).
function L.PlaceLink(b, target, width, height, go, text, tip)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
    b:SetSize(math.max(1, width), math.max(1, height))
    b:SetFrameLevel(b:GetParent():GetFrameLevel() + 5)
    b.go, b.text, b.tip = go, text, tip
    b:SetShown(go ~= nil or tip ~= nil)
end

--- Link area b over label fs's text (at most maxWidth wide, a wrapped label's width), running go and showing tip.
function L.LinkOver(b, fs, go, maxWidth, tip)
    local width = fs:GetStringWidth()
    if maxWidth then width = math.min(maxWidth, width) end
    L.PlaceLink(b, fs, width, fs:GetStringHeight(), go, fs:GetText(), tip)
end

--- The search box: the characters' search across their items ("who has the tin mail?"), or the list page's filter.
function L:Search(text)
    text = text or ""
    if self.page == "characters" then
        if text == self.search then return end
        self.search = text
    else
        if text == (self.filters[self.page] or "") then return end
        self.filters[self.page] = text
        self.selected[self.page] = nil
    end
    self:Refresh()
end

--- The page's texts as shown (tests and the screenshots).
function L:Texts() return table.concat(self.texts, "\n") end

require("core.library.lines")
require("core.library.list")
require("core.library.pictures")
require("core.library.detail")
require("core.library.itemtip") -- s6-library round 24: an item's stats, for the tooltips and the Items page
require("core.library.gear")
require("core.library.characters")
require("core.library.monsters")
require("core.library.items")
require("core.library.npcs")
require("core.library.spells")
require("core.library.maps")
require("core.library.players")
require("core.library.markers")
require("core.library.exchange")
require("core.library.prebuild") -- s6-library round 16: the build's prebuilt Library (FOR s6-library-pages)
require("core.library.sameserver") -- s6-library round 22: a new address that may be a known server, asked (FOR s6-library-pages)

-- ----- the buttons that open the window -----

TK.GameMenu:AddEntry({ id = "library", text = "Library", order = 25,
    onClick = function() TK.GameMenu:Close(); L:Open() end,
    shown = function() return TK.GameState == nil or TK.GameState:InWorld() end })
