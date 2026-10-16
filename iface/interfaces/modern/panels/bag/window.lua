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

local H = __tk
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin

local Bag = {}
TK.Bag = Bag

local SLOTS, COLS, SIZE, GAP, ROW = 52, 13, 38, 4, 22
local WIDTH = COLS * (SIZE + GAP) - GAP + 32
-- The lines a view shows at once, compact and expanded: the original's list has 13 rows, 26 expanded
-- (RebuildInventoryList); the grid keeps our 13 columns, 2 lines compact and all 4 expanded.
local LINES = { grid = { [false] = 2, [true] = 4 }, list = { [false] = 13, [true] = 26 } }

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

local function makeCell(parent, i)
    local b = CreateFrame("Button", "TKBagSlot" .. i, parent)
    b:SetSize(SIZE, SIZE)
    b.bg, b.icon, b.edge = W.SlotArt(b) -- s6-ui-core (round 62): the shared slot's picture, an item's edge, the light
    b.glyph = W.Label(b, "", 18, W.white)
    b.glyph:SetFont(18, "OUTLINE")
    b.glyph:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.letter = W.Label(b, "", 10, { 0.85, 0.85, 0.85 }, "LEFT")
    b.letter:SetFont(10, "OUTLINE")
    b.letter:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -2)
    b.count = W.Label(b, "", 11, W.white, "RIGHT")
    b.count:SetFont(11, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    local col, line = (i - 1) % COLS, math.floor((i - 1) / COLS)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 16 + col * (SIZE + GAP), -42 - line * (SIZE + GAP))
    Inv.SlotControl(b)
    return b
end

local function makeRow(parent, i)
    local b = CreateFrame("Button", "TKBagRow" .. i, parent)
    b:SetSize(WIDTH - 32, ROW - 2)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -42 - (i - 1) * ROW)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0.07)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture("tk:button-hl")
    hl:SetVertexColor(1, 1, 1, 0.35)
    b.letter = W.Label(b, "", 12, { 0.85, 0.85, 0.85 }, "LEFT")
    b.letter:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.iconBox = CreateFrame("Frame", nil, b)
    b.iconBox:SetSize(18, 18)
    b.iconBox:SetPoint("LEFT", b, "LEFT", 24, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.glyph = W.Label(b.iconBox, "", 12, W.white)
    b.glyph:SetPoint("CENTER", b.iconBox, "CENTER", 0, 0)
    b.name = W.Label(b, "", 12, W.white, "LEFT")
    b.name:SetPoint("LEFT", b, "LEFT", 50, 0)
    b.count = W.Label(b, "", 12, W.white, "RIGHT")
    b.count:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    Inv.SlotControl(b)
    return b
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

local function build()
    window = W.Window("TKBagWindow", "Bag", WIDTH, LINES.grid[true] * (SIZE + GAP) + 112)
    -- s6-interface-5x (round 14; Astra's review of round 13, P2): the shared widgets make it on UIParent, which makes it
    -- no panel's until owned, so it goes with the bag when it is unloaded
    TK.GetComponent("bag"):Own(window)
    window:SetPoint("CENTER", UIParent, "CENTER", 260, 40)
    window.offset = 0
    window.cells, window.rows = {}, {}
    for i = 1, SLOTS do window.cells[i] = makeCell(window, i) end
    for i = 1, LINES.list[true] do window.rows[i] = makeRow(window, i) end
    Inv.Track(window.cells)
    Inv.Track(window.rows)
    window.range = W.Label(window, "", 11, { 0.6, 0.6, 0.6 }, "LEFT")
    window.range:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -16)
    window.gold = W.Label(window, "", 13, W.gold, "LEFT")
    window.gold:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 18, 50)
    local drop = W.Button(window, "Drop Gold", 110, 24, nil, function() Inv.GoldPrompt("dropgold", "Drop Gold") end)
    drop:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 16, 14)
    local give = W.Button(window, "Give Gold", 110, 24, nil, function() Inv.GoldPrompt("givegold", "Give Gold") end)
    give:SetPoint("LEFT", drop, "RIGHT", 8, 0)
    window.dropGold, window.giveGold = drop, give
    -- The original's four buttons (GetButtonRect 2-5): List, Grid, Expand and Mix. Mix runs the dialog model's opener,
    -- the action Shift+I runs (components/originalkeys), through the game layer's (TK.Game.Inventory.MixControl).
    window.mix = W.Button(window, "Mix", 56, 24, nil, Inv.Mix)
    window.mix:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 14)
    Inv.MixControl(window.mix)
    window.expand = W.Button(window, "Compact", 76, 24, nil, function()
        local _, expanded = viewSettings()
        setView("expanded", not expanded)
    end)
    window.expand:SetPoint("RIGHT", window.mix, "LEFT", -6, 0)
    window.list = W.Button(window, "List", 56, 24, nil, function() setView("view", "list") end)
    window.list:SetPoint("RIGHT", window.expand, "LEFT", -6, 0)
    window.grid = W.Button(window, "Grid", 56, 24, nil, function() setView("view", "grid") end)
    window.grid:SetPoint("RIGHT", window.list, "LEFT", -6, 0)
    window.hint = W.Label(window, "Right-click an item for its commands.", 11, { 0.6, 0.6, 0.6 }, "RIGHT")
    window.hint:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -18, 50)
    window:EnableMouseWheel(true)
    window:SetScript("OnMouseWheel", function(_, delta) Bag:Scroll(-delta) end)
    window:SetScript("OnShow", function() Bag:Refresh() end)
    Inv.EndCarryOnHide(window) -- review r1: no carry outlives it

    local events = CreateFrame("Frame", nil, window)
    events:RegisterEvent("BAG_UPDATE")
    events:RegisterEvent("PLAYER_MONEY")
    events:RegisterEvent("TK_WORLD_SOURCE")
    events:SetScript("OnEvent", function()
        if window:IsShown() then Bag:Refresh() end
    end)
end

--- The window's size and buttons for a view; the other view's controls hide.
local function layout(view, expanded)
    local lines = LINES[view][expanded]
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
    local lines = LINES[view][expanded]
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
    self:Scroll(delta * LINES[view][expanded])
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
