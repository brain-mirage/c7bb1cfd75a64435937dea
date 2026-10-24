-- The bag (goal 8, plan D19): the 52 lettered inventory slots (a-z, then A-Z) as the server sends them (0x0F, 0x10),
-- with the gold, in the original's two views (NewInventoryPane: RebuildInventoryList 0x004EB6C0, OnPaint 0x004EBB20):
--
--   Grid, List           the items' icons, or a row per slot with its letter, name and count
--   Expand / Compact     every slot (an empty one with its letter), or only the slots that hold an item; the view and
--                        this are the bag component's settings (settings.lua beside this file)
--   the wheel            scrolls a view that has more than it shows (HandlePointerOrMouseEvent 0x004ECB50, case 7)
--   Mix                  the mixing dialog, as the original's button 5 and Shift+I (UserPane::OpenMixItemDialog)
--
--   the slots            each a slot control of the game layer's (TK.Game.Inventory, core/game/inventory.lua: 4a's
--                        press, drag, double press and Simple Click), with the item menu and the tooltip
--   Drop Gold, Give Gold the gold commands, with the amount asked first
--
-- Each command is an action attached to its control (TK.Actions); the rules decide what is sent.
--
-- s6-ui-core (round 85): the XML twin's scripts; the window, its cells and rows are window.xml's (core/xml.md).

local H = __tk
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin

local Bag = {}
TK.Bag = Bag

-- the scripts window.xml names, and its build (its templates: the window, a cell, a row)
local scripts = {}
local ui = TK.Xml.Load("window.xml", { scripts = scripts, elements = require("interfaces.modern.elements") })

local B = ui.BAG -- the slots, the grid's columns, a cell's side and gap, a row's step, the window's width (window.xml's)
local SLOTS, COLS, SIZE, GAP, ROW, WIDTH = B.slots, B.cols, B.size, B.gap, B.row, B.width

--- The lines a view shows at once, compact or expanded (window.xml's LINES).
local function linesOf(view, expanded) return ui.LINES[view][expanded and "expanded" or "compact"] end

local window

local Inv = TK.Game.Inventory
local itemAt = Inv.ItemAt

--- The view ("grid" or "list") and whether it shows every slot, from the bag component's settings.
local function viewSettings()
    local c = TK.GetComponent("bag")
    local db = c and c:DB() or {}
    return db.view == "list" and "list" or "grid", db.expanded ~= false
end

--- The window's view buttons change the bag component's settings, as its settings page does.
local function setView(key, value)
    local c = TK.GetComponent("bag")
    if not c then return end
    c:DB()[key] = value
    c:Changed(nil, key, value)
    if TK.Settings:IsOpen() then TK.Settings:RefreshPage() end
end

--- A control shows its real slot: the icon (or the empty slot's letter alone), and in a row the name.
local function show(b, slot)
    local name, count = itemAt(slot)
    local action = { kind = "item", slot = slot }
    b.letter:SetText(H:SlotLetter(slot))
    if b.name then
        W.ActionIcon(b.icon, b.glyph, b.iconBox, action, 18, 1)
        b.name:SetText(name or "")
    else
        W.ActionIcon(b.icon, b.glyph, b, action, SIZE, 3)
    end
    b.count:SetText(count and count > 1 and tostring(count) or "")
end

-- ----- window.xml's scripts -----

local making -- the index of the cell or row being made (scripts.Slots), for its scripts

function scripts.Own(w) TK.GetComponent("bag"):Own(w) end

-- Wire: a slot's input path is the game layer's slot control (TK.Game.Inventory.SlotControl, 4a's
-- NewInventoryPane::HandlePointerOrMouseEvent 0x004ECB50 whole: the press, the drag, the double press, Simple Click's
-- release); changing it changes what the server sees.
function scripts.SlotControl(b) Inv.SlotControl(b) end

-- a cell's place in the grid, then its input path (wire: SlotControl above)
function scripts.Cell(b)
    local col, line = (making - 1) % COLS, math.floor((making - 1) / COLS)
    b:SetPoint("TOPLEFT", b:GetParent(), "TOPLEFT", 16 + col * (SIZE + GAP), -42 - line * (SIZE + GAP))
    Inv.SlotControl(b)
end

function scripts.RowPlace(b)
    b:SetSize(WIDTH - 32, ROW - 2)
    b:SetPoint("TOPLEFT", b:GetParent(), "TOPLEFT", 16, -42 - (making - 1) * ROW)
end

function scripts.RowShade(bg) bg:SetColorTexture(1, 1, 1, making % 2 == 0 and 0.03 or 0.07) end

-- Every slot's cell, then the expanded list's rows. Wire: their actions follow the carry (TK.Game.Inventory.Track).
function scripts.Slots(w, build)
    for i = 1, SLOTS do
        making = i
        w.cells[i] = build:New("Cell", w, "TKBagSlot" .. i)
    end
    for i = 1, linesOf("list", true) do
        making = i
        w.rows[i] = build:New("Row", w, "TKBagRow" .. i)
    end
    making = nil
    Inv.Track(w.cells)
    Inv.Track(w.rows)
end

function scripts.DropGold() Inv.GoldPrompt("dropgold", "Drop Gold") end

function scripts.GiveGold() Inv.GoldPrompt("givegold", "Give Gold") end

-- Wire: the Mix button's action and its path are the game layer's (TK.Game.Inventory.MixControl and Mix, 4a's
-- UserPane::OpenMixItemDialog), its click the game layer's own function; changing them changes what the server sees.
scripts.Mix = Inv.Mix

function scripts.MixControl(b) Inv.MixControl(b) end

function scripts.ToggleExpanded()
    local _, expanded = viewSettings()
    setView("expanded", not expanded)
end

function scripts.ListView() setView("view", "list") end

function scripts.GridView() setView("view", "grid") end

function scripts.Wheel(_, delta) Bag:Scroll(-delta) end

function scripts.Refresh() Bag:Refresh() end

function scripts.EndCarryOnHide(w) Inv.EndCarryOnHide(w) end

function scripts.Changed()
    if window:IsShown() then Bag:Refresh() end
end

local function build() window = ui:New("Window") end

--- The window's size and buttons for a view; the other view's controls hide.
local function layout(view, expanded)
    local lines = linesOf(view, expanded)
    window:SetSize(WIDTH, (view == "grid" and lines * (SIZE + GAP) or lines * ROW) + 112)
    for _, b in ipairs(view == "grid" and window.rows or window.cells) do
        b.slot = nil
        b:Hide()
    end
    window.expand:SetText(expanded and "Compact" or "Expand")
    if view == "grid" then window.grid:Disable() else window.grid:Enable() end
    if view == "list" then window.list:Disable() else window.list:Enable() end
end

--- Shows the view: the slots it lists (every slot expanded, else those holding an item), from its scroll position.
function Bag:Refresh()
    if not window then return end
    local view, expanded = viewSettings()
    local mode = view .. tostring(expanded)
    if mode ~= window.mode then
        -- As the original's buttons and ToggleExpandedMode (0x004EE5A0): a new view starts at the top.
        window.mode, window.offset = mode, 0
        layout(view, expanded)
    end
    local per = view == "grid" and COLS or 1
    local lines = linesOf(view, expanded)
    local slots = {}
    for slot = 1, SLOTS do
        if expanded or itemAt(slot) then slots[#slots + 1] = slot end
    end
    window.maxOffset = math.max(0, math.ceil(#slots / per) - lines)
    window.offset = math.max(0, math.min(window.offset, window.maxOffset))
    local first = window.offset * per
    for i, b in ipairs(view == "grid" and window.cells or window.rows) do
        local slot = i <= lines * per and slots[first + i] or nil
        b.slot = slot
        b:SetShown(slot ~= nil)
        if slot then show(b, slot) end
    end
    window.range:SetText(window.maxOffset > 0
        and string.format("%d-%d of %d", first + 1, math.min(first + lines * per, #slots), #slots) or "")
    window.gold:SetText("Gold  " .. TK.Util.FormatNumber(H:GetMoney()))
    Inv.UpdateActions()
end

--- The wheel: lines down (positive) or up, within the view, as the original's case 7 moves its scroll position.
function Bag:Scroll(lines)
    if not window or not window.maxOffset then return end
    local offset = math.max(0, math.min(window.offset + lines, window.maxOffset))
    if offset == window.offset then return end
    window.offset = offset
    self:Refresh()
end

--- Builds the window, hidden, the first time: its first opening, or the world's loading (TK.Game.Views.BuildAhead below,
--- s6-optimize round 6), which spares the opening the hitch of making its controls.
function Bag:Build()
    if not window then build() end
end

function Bag:IsOpen() return window ~= nil and window:IsShown() end

--- PgUp and PgDn (K-097): a page of the view back or on, as 4a's 0x93 and 0x94 page its list and grid by the rows they
--- show (NewInventoryPane::HandleKeyOrTextEvent 0x004EC920), from the top to the last page; nothing is sent. True when
--- the bag is open.
function Bag:Page(delta)
    if not self:IsOpen() then return false end
    local view, expanded = viewSettings()
    self:Scroll(delta * linesOf(view, expanded))
    return true
end

-- s6-interface-5x (round 12, step 1): the window of the game layer's "bag" view (TK.Game.Views), which the bag key
-- (TOGGLEBAG), the bag bar, the micro menu and the server's item tab open when no interface's page takes the view. PgUp
-- and PgDn page it after the look and character windows (pageOrder). Built first while the world loads (about 90 ms of
-- its first opening on the VM).
TK.Game.Views.SetWindow("bag", {
    panel = { component = "bag", node = "bag", switch = "enabled" }, -- its switch (Modern's panel; step 1)
    pageOrder = 3,
    Open = function()
        Bag:Build()
        window:Show()
    end,
    Close = function() if window then window:Hide() end end,
    IsOpen = function() return Bag:IsOpen() end,
    Page = function(delta) return Bag:Page(delta) end,
})
TK.Game.Views.BuildAhead(10, function() Bag:Build() end)
