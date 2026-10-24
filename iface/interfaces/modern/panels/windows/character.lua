-- The character window (goal 10, head note 5): one window with its sections as tabs down its right side, as in
-- current WoW: Character (gear and stats), Spell Book, Legend and Collection. More tabs are added with
-- TK.CharacterWindow:AddTab.
--
-- Opening a tab sends what opening the original's equivalent sent (plan D20), and only then: the Character and
-- Legend tabs are the original's own-status tab (2D 00, answered by 0x39), the Collection tab its collection tab
-- (27 00 00 until the page list has arrived). Offline nothing is sent.
--
-- It is the window of the game layer's views "character", "spellbook", "legend", "collection" and any tab added later
-- (TK.Game.Views, s6-interface-5x round 12, step 1): their keys (TOGGLECHARACTER, C; TOGGLESPELLBOOK, P;
-- TOGGLECOLLECTION), the micro menu's buttons, the server's and the map's openings (an S 0x3E 4, 7 or 8, a right press on
-- oneself) and PgUp/PgDn are the views', which open this window when no interface's page takes the view.
--
-- s6-ui-core (round 85): the XML twin's scripts; the window, its side tabs, its pages and the Character, Legend and
-- Collection tabs' contents are character.xml's (core/xml.md). A tab another file adds (spell book, a plugin's) builds
-- its own page as before.

local H = __tk
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin

local CW = { tabs = {}, current = nil }
TK.CharacterWindow = CW

-- the scripts character.xml names (below, after the helpers they use), and its build (its templates)
local scripts = {}
local ui = TK.Xml.Load("character.xml", { scripts = scripts, elements = require("interfaces.modern.elements") })

local WIDTH, TAB = ui.SIZES.width, ui.SIZES.tab -- the window's width, a side tab's side (character.xml's)

local frame

--- Adds a side tab: { id, title, icon = texture key, order, request = action kind, build = function(page) end,
--- refresh = function(page) end }. build fills the tab's page (a frame covering the window's content area) the first
--- time the tab is shown; request is the D20 action run each time the player opens the tab. The tab's id is a view of the
--- game layer's (TK.Game.Views), whose window this is.
function CW:AddTab(def)
    TK.Game.Views.SetWindow(def.id, CW.window)
    def.order = def.order or (#self.tabs + 1) * 10
    self.tabs[#self.tabs + 1] = def
    table.sort(self.tabs, function(a, b) return a.order < b.order end)
    if frame then self:LayoutTabs() end
end

function CW:Tab(id)
    for _, t in ipairs(self.tabs) do
        if t.id == id then return t end
    end
end

-- the window (frame: its Own script), hidden
local function build() ui:New("Window") end

--- Places the side tabs down the window's right edge, outside it, in their order.
function CW:LayoutTabs()
    for _, b in pairs(frame.tabButtons) do b:Hide() end
    for i, def in ipairs(self.tabs) do
        local b = frame.tabButtons[def.id]
        if not b then
            -- s6-ui-core (round 61): the shared tab (core/widgets.lua), an icon side tab (character.xml's SideTab)
            b = ui:New("SideTab", frame, "TKCharacterTab" .. def.id, nil, { def = def, icon = def.icon or "tk:circle" })
            frame.tabButtons[def.id] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2, -40 - (i - 1) * (TAB + 6))
        b:SetSelected(def.id == self.current)
        b:Show()
    end
end

--- A tab's page, empty and hidden; its contents are built when it first shows. D20: the original's request for the tab
--- goes with its page, which asks when it becomes visible by the player's hand.
local function makePage(def)
    def.page = ui:New("Page", frame.content, nil, nil, def)
end

--- A tab's page with its contents, made once: when the tab first shows, or earlier by CW:Build.
local function ensurePage(def)
    if not def.page then makePage(def) end
    if not def.built then
        def.built = true
        if def.build then TK.SafeCall(def.build, def.page) end
    end
end

--- s6-optimize (round 6): builds a tab's page ahead, hidden, as its first opening would; the world's loading builds the
--- heavy ones (core/gamestate.lua), which spares their first opening the hitch.
function CW:Build(id)
    if not frame then build() end
    ensurePage(self:Tab(id))
end

--- The window's own opening on a tab (the views' window: TK.Game.Views has switched the tab and asked the interfaces'
--- pages first). Opening sends nothing here: a request is the opening input's action (the key's, the button's), run by
--- the page as it becomes visible in that input.
local function openWindow(id)
    if not frame then build() end
    local def = CW:Tab(id) or CW.tabs[1]
    for _, t in ipairs(CW.tabs) do
        if t.page then t.page:SetShown(t == def) end
    end
    ensurePage(def)
    def.page:Show()
    if def.refresh then TK.SafeCall(def.refresh, def.page) end
    if def.page.figureBox then CW.ShowFigure(def.page) end -- s6-ui-core (round 33): asked for as the page opens
    CW.current = def.id
    frame.title:SetText(def.title)
    CW:LayoutTabs()
    frame:Show()
    -- Always all on the screen (head note 7.3): shrunk to fit, the side tabs included.
    TK.FitToScreen(frame, 10, 0, TAB)
end

function CW:Close()
    if frame then frame:Hide() end
end

function CW:IsOpen() return frame ~= nil and frame:IsShown() end

TK.On("PLAYER_LEAVING_WORLD", function() CW:Close() end)

-- A window's request can be attached only while the UI loads (plan 5.9), so the pages that send one are made now. Wire:
-- without its page the tab's 2D 00 or 27 00 00 (the tab button's comment above) would never go; changing this changes
-- what the server sees.
TK.On("PLAYER_LOGIN", function()
    if not frame then build() end
    for _, def in ipairs(CW.tabs) do
        if def.request and not def.page then makePage(def) end
    end
end)

-- s6-optimize (round 6): the heavy tabs built ahead while the world loads (TK.Game.Views.BuildAhead), the spell book's
-- (about 115-130 ms of its first opening on the VM) before the character's (about 30 ms), after the bag's.
TK.Game.Views.BuildAhead(20, function() CW:Build("spellbook") end)
TK.Game.Views.BuildAhead(30, function() CW:Build("character") end)

--- The views' window for its tabs (TK.Game.Views.SetWindow, by CW:AddTab): it opens on a tab when no interface's page
--- takes the view. PgUp and PgDn (s6-ui-character, K-098, K-097; nothing sent) page it as the original's keys page the
--- side-panel tab that shows: the self look's views (SelfLookPane::HandleKeyOrTextEvent: equipment, status, legend; here
--- the Character tab, which holds the first two, and the Legend tab) and the spell list (NewSpellInventoryPane: 13 rows;
--- here a screenful of the book's list). With several of ours open, the look window pages first, then this one, then the
--- bag, then the Social window's group page (pageOrder).
CW.window = {
    panel = { component = "windows", node = "character", switch = "enabled" }, -- its switch (Modern's panel; step 1)
    pageOrder = 2,
    Open = function(view) openWindow(view) end,
    Close = function() CW:Close() end,
    IsOpen = function(view) return CW:IsOpen() and (view == nil or CW.current == view) end,
    Page = function(delta)
        if not CW:IsOpen() then return false end
        if CW.current == "character" and delta > 0 then openWindow("legend")
        elseif CW.current == "legend" and delta < 0 then openWindow("character")
        elseif CW.current == "spellbook" then
            local page = CW:Tab("spellbook").page
            if page and page.turn then page.turn(delta) end
        end
        return true
    end,
}

-- ----- helpers -----

local function note(page, text, y)
    local fs = W.Label(page, text, 12, { 0.7, 0.7, 0.7 })
    fs:SetWordWrap(true)
    fs:SetWidth(WIDTH - 90)
    fs:SetPoint("TOP", page, "TOP", 0, y)
    return fs
end

--- Refreshes a tab's page on these events while it is shown.
local function refreshOn(page, events, id)
    local f = CreateFrame("Frame", nil, page)
    for _, e in ipairs(events) do f:RegisterEvent(e) end
    f:SetScript("OnEvent", function() if page:IsVisible() then TK.SafeCall(CW:Tab(id).refresh, page) end end)
end

-- A character's drawing helpers (the gear slot, the figure box, the stat lines, the legend list) are the global widgets'
-- (TK.UI.Character, core/widgets/character.lua), as the Library draws with them too.
local CH = W.Character

-- ----- the self-look pane's switches (SelfLookPane::HandlePointerOrMouseEvent 0x00568CB0) -----
--
-- Each a switch control of the game layer's (TK.Game.SelfLook.SwitchControl: the option on the "selflook" path, run on
-- the left press; core/game/selflook.lua says what each sends). Their names: the original's keys for 8 and 2 are E and
-- G, and the servers name the four options Exchange, Group, Show Helmet and Show Necklace.

local SelfLook = TK.Game.SelfLook

local SWITCHES = ui.SWITCHES -- their ids, options, names and tips (character.xml's)

--- A switch's state: 1 on, 0 off; anything else (0xFF before the server's 0x39, -1 offline) not known.
local function stateText(v)
    if v == 1 then return "On" elseif v == 0 then return "Off" end
    return "-"
end

--- The switches' states as the rules and the server's options hold them (0xFF or -1: not known yet).
function CW.UpdateSwitches(page)
    if not page.switches then return end
    local s = SelfLook.States()
    for _, def in ipairs(SWITCHES) do
        page.switches[def.id]:SetText(def.label .. ": " .. stateText(s[def.id]))
    end
end

-- ----- Character: the 14 equipment records of 0x39 (and 0x37 / 0x38), the identity lines and the stats -----

--- The Character tab's figure: the player's look (GetFigureOn "player") on the figure box's colour, scaled by whole
--- steps to fit its box; the emoji while there is none (offline, before the first look). The picture changes only when
--- the key does.
function CW.ShowFigure(page)
    local c = CH.FIGURE_BG
    local key, w, h = __tk:GetFigureOn("player", 0, c[1] * 65536 + c[2] * 256 + c[3])
    if key == page.figureKey then return end
    page.figureKey = key
    CH.PlaceFigure(page.figure, key, w, h)
end

-- ----- character.xml's scripts -----

-- the window (its tabs' layout reads it while it is built), the windows' own
function scripts.Own(f)
    frame = f
    TK.GetComponent("windows"):Own(f)
end

function scripts.DragStart(self) self:StartMoving() end

function scripts.DragStop(self) self:StopMovingOrSizing() end

function scripts.Close() CW:Close() end

function scripts.LayoutTabs() CW:LayoutTabs() end

function scripts.Escape(f) TK.Escape:AddWindow(f, function() CW:Close() end) end

function scripts.OpenTab(b) TK.Game.Views.Open(b.def.id, "input") end

-- D20: the tab carries its page's request, which the page runs when it becomes visible (plan 5.9). Wire: the self look's
-- and the legend's 2D 00 (4a's UserPane::RequestLocalPlayerStatus 0x005A4F70), the collection's 27 00 00
-- (UserPane::SwitchToCollectionTab 0x005A4EA0, until its list has come); changing which control carries a request
-- changes what the server sees.
function scripts.SideTab(b, _, with)
    b.def = with.def
    if b.def.request then TK.Actions:Set(b, b.def.request) end
end

function scripts.SideTabTip(self)
    local def = self.def
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(def.title, 1, 1, 1)
    if def.key then GameTooltip:AddLine("Key: " .. (GetBindingKey(def.key) or "not bound"), 0.5, 0.8, 1) end
    GameTooltip:Show()
end

function scripts.Untip() GameTooltip:Hide() end

-- Wire: the page runs its tab's request when it becomes visible (the side tab's comment above); changing it changes what
-- the server sees.
function scripts.PageRequest(page, _, def)
    if def.request then TK.Actions:SetOpen(page, def.request) end
end

-- a tab's page drawn again on its events while it shows (the events frame's tab)
function scripts.RefreshTab(f)
    local page = f:GetParent()
    if page:IsVisible() then TK.SafeCall(CW:Tab(f.tab).refresh, page) end
end

-- the Character tab's gear slots, half down the left and half down the right
function scripts.GearSlots(page, build)
    local n = H:GetNumEquipmentSlots()
    local half = math.ceil(n / 2)
    for i = 1, n do
        local left = i <= half
        local row = left and i - 1 or i - half - 1
        page.slots[i] = build:New("GearSlot", page, "TKCharacterSlot" .. i, nil,
            { index = i, x = left and 12 or -12, y = -12 - row * 46, point = left and "TOPLEFT" or "TOPRIGHT" })
    end
end

function scripts.GearSlot(s, _, with) s.index = with.index end

function scripts.GearTip(self)
    local _, _, _, name, _, description = H:GetEquipment(self.index)
    if name == "" then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(name, 1, 1, 1)
    if description ~= "" then GameTooltip:AddLine(description, 0.8, 0.8, 0.8) end
    GameTooltip:AddLine("Click to take it off.", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

-- Wire: a press takes the item off, as on the original's gear slot (1F with the slot's code, set by refresh: 4a's
-- SendTakeOffPacket 0x005B27C0), on the left button down: the game layer's worn item control; changing it changes what
-- the server sees.
function scripts.WornControl(s) SelfLook.WornControl(s) end

function scripts.Figure(box) box:GetParent().figure = box.figure end

function scripts.SwitchTicker(box)
    local page = box:GetParent()
    box:SetScript("OnUpdate", TK.Util.Throttled(0.25, function() CW.UpdateSwitches(page) end))
end

function scripts.PortraitChanged(box, _, unit)
    local page = box:GetParent()
    if unit == "player" and page:IsVisible() then CW.ShowFigure(page) end
end

function scripts.ShowFigure(box) CW.ShowFigure(box:GetParent()) end

-- Wire: Bare Hands (12 00) and Take Off All (fourteen 1F) are the game layer's actions (TK.Game.SelfLook), run as frozen
-- on the press (4a's SelfLookPane::HandlePointerOrMouseEvent 0x00568CB0); changing them changes what the server sees.
function scripts.RunFrozen() TK.Actions:RunFrozen() end

function scripts.BareHandsAction(b) SelfLook.BareHandsAction(b) end

function scripts.TakeOffAllControl(b) SelfLook.TakeOffAllControl(b) end

-- the self-look pane's four switches, two by two at the right
function scripts.Switches(page, build)
    for i, def in ipairs(SWITCHES) do
        local b = build:New("Switch", page, nil, nil, def)
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        b:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12 - (1 - col) * 130, -330 - row * 28)
        page.switches[def.id] = b
    end
end

-- Wire: a switch is the game layer's switch control (TK.Game.SelfLook.SwitchControl: its option on the "selflook" path,
-- run on the left press; SelfLookPane::HandlePointerOrMouseEvent 0x00568CB0); changing it changes what the server sees.
function scripts.SwitchControl(b, _, def)
    b.def = def
    SelfLook.SwitchControl(b, def.option)
end

function scripts.SwitchTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.def.label, 1, 1, 1)
    GameTooltip:AddLine(self.def.tip, 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function scripts.UpdateSwitches(page) CW.UpdateSwitches(page) end

function scripts.LegendPlace(page) page.list.sf:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -12) end

function scripts.CollectionRevision(page)
    if H:GetCollectionRevision() ~= page.revision then TK.SafeCall(CW:Tab("collection").refresh, page) end
end

function scripts.VolumePlace(row, _, with)
    row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 12, -14 - (with.index - 1) * 42)
    row.volume = with.index - 1
end

-- Wire: a volume's press goes to the dialog model with the page's index (CollectionPane::HandlePointerOrMouseEvent;
-- DialogRules: the first opening asks the server for the volume, 27 00 01, later ones open the album); changing it
-- changes what the server sees.
function scripts.VolumePress(row, button)
    if button == "LeftButton" and TK.Dialogs then TK.Dialogs.Open("CollectionDialogPane", 0, tostring(row.volume)) end
end

CW:AddTab({ id = "character", title = "Character", icon = "emoji:1f9cd", order = 10, key = "TOGGLECHARACTER",
    request = "open:character",
    build = function(page) ui:New("CharacterPage", page) end,
    refresh = function(page)
        local _, name, level, path = H:GetUnitInfo("player")
        local _, hp, hpMax, mp, mpMax = H:GetUnitVitals("player")
        local might, will, grace = H:GetPlayerStats()
        local hasSheet, sheetName, line2, statusA, statusB = H:GetSheet()
        page.name:SetText(hasSheet and sheetName ~= "" and sheetName or name or "")
        local info = "Level " .. tostring(level or "")
        if (path or "") ~= "" then info = info .. " " .. path end
        if hasSheet and line2 ~= "" then info = info .. "   " .. line2 end
        page.info:SetText(info)
        local lines = {}
        if hasSheet and statusA ~= "" then lines[#lines + 1] = statusA end
        if hasSheet and statusB ~= "" then lines[#lines + 1] = statusB end
        page.lines:SetText(table.concat(lines, "\n"))
        page.stats:SetText(CH.StatsText(hp, hpMax, mp, mpMax, H:GetExperience(), H:GetMoney()))
        page.stats2:SetText(CH.StatsText2(might, will, grace))
        for i, s in ipairs(page.slots) do
            local _, slotName, code, itemName, iconId = H:GetEquipment(i)
            CH.FillGearSlot(s, slotName, itemName, iconId)
            -- s6-modular-g (round 16, the head's note; s6-optimize's FOR item 1): Wire: every slot takes off with its
            -- code, empty or not, as 4a's gear slot sends SendTakeOffPacket 0x005B27C0 with no item test
            -- (SelfLookPane.cpp:1220-1265; 7.x's self look the same). Changing this changes what the server sees.
            SelfLook.TakeOff(s, code)
        end
        CW.UpdateSwitches(page)
        local text = ""
        if not H:IsOnline() then
            text = "Offline: the gear and the legend come from the server."
        elseif not hasSheet then
            text = "Waiting for the server's character sheet..."
        end
        page.note:SetText(text)
    end })

-- ----- Spell Book -----
-- The Spell Book tab itself, Modern's table of the slots' spells, is spellbook.lua beside this file (s6-spellbook); its
-- cells are the game layer's (TK.Game.Spells, core/game/spells.lua: head note 38's input path).

-- s6-spellbook: for the Spell Book tab (spellbook.lua): the page helpers. (s6-interface-5x round 15, the separation's
-- step 9: the book cell's input path, its action and the click mode are the game layer's, TK.Game.Spells, which the tab
-- calls itself.)
CW.Note, CW.RefreshOn = note, refreshOn

-- ----- Legend: the marks at the end of 0x39 (the original's own-status tab, so it asks with 2D 00 too) -----

CW:AddTab({ id = "legend", title = "Legend", icon = "emoji:1f4dc", order = 30, request = "open:character",
    build = function(page) ui:New("LegendPage", page) end,
    refresh = function(page)
        page.list:Fill(H:GetNumLegend(), function(i)
            local _, text, symbol, colour = H:GetLegend(i)
            return text, symbol, colour
        end, H:IsOnline() and "No marks yet." or "Offline: the legend comes from the server.")
    end })

-- ----- Collection: the volumes of 0x12 00 -----
-- s6-rules-dialogs (round 31): each volume as 4a's CollectionPane draws it (OnPaint 0x0056EDC0): its name from the
-- GroupNames table, "N %" (100 * collected / total, truncated) and "collected/total", a complete volume highlighted. An
-- empty list draws no text, as 4a's. Without a GroupNames row 4a draws a Korean placeholder, which our fonts cannot
-- (plan D14: English only): this tab says "Volume N" there.

CW:AddTab({ id = "collection", title = "Collection", icon = "emoji:1f3c6", order = 40, request = "open:collection",
    build = function(page) ui:New("CollectionPage", page) end,
    refresh = function(page)
        -- One copy of the collection, its revision with it (review r6 finding 4).
        local pages, revision = H:GetCollection()
        page.revision = revision
        local n = #pages
        for i = 1, math.max(n, #page.rows) do
            local row = page.rows[i]
            if not row and i <= n then
                -- Named TKCollectionVolume1, 2... for the gate's driver (s6-gate round 37, H-18: the double click on a
                -- volume row); gate mode logs a named control's place while it shows (core/gatecontrols.lua).
                row = ui:New("Volume", page, "TKCollectionVolume" .. i, nil, { index = i })
                page.rows[i] = row
            end
            if row then
                if i <= n then
                    local collected, total = pages[i][2], pages[i][3]
                    local percent = total > 0 and math.floor(100 * collected / total) or 0
                    row.complete = percent == 100
                    local c = row.complete and W.gold or W.white
                    row.name:SetText(pages[i][4] ~= "" and pages[i][4] or ("Volume " .. pages[i][1]))
                    row.percent:SetText(percent .. " %")
                    row.count:SetText(collected .. "/" .. total)
                    for _, label in ipairs({ row.name, row.percent, row.count }) do label:SetTextColor(c[1], c[2], c[3]) end
                end
                row:SetShown(i <= n)
            end
        end
        page.text:SetText((n == 0 and not H:IsOnline()) and "Offline: the collection comes from the server." or "")
    end })
