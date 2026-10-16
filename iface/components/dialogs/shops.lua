-- s6-rules-dialogs: the hired merchant (D-25, its quantity D-27 and price D-28), the clan bank (D-29), the power
-- dialog (D-30) and the rankings (D-31, D-32). Their packets are the model's; these windows show its contents and pass
-- the buttons, lists and edits on.
--
-- s6-modular-g (interfaces): the windows' sizes, where their parts sit and the item icons' places are the look's
-- (C.look.HiredMerchant, Price, Bank, Power, Rankings, Rewards, ItemIcon), with a look's own rows and texts (their row,
-- category and fill entries); this file keeps what each dialog does.

local C = TK.GetComponent("dialogs")
local K = C.kit
local W = TK.UI

-- D-25: ADD (0), WITHDRAW (1), REMOVE (2), OK (3), the ten slots (4-13), each a record { id, item, colour, name, count,
-- price } or empty. Its sends are the model's timers.
-- Wire: EmployeeDialogPane::OnControlCommand 0x004A3240 and HandlePointerOrMouseEvent 0x004A2A60 by these indexes (a
-- slot's press and release); changing an index changes what the server sees.
local Merchant = { look = "HiredMerchant" }

function Merchant.build()
    local L = C.look.HiredMerchant
    local win = K.Window(L.width, L.height, "Hired Merchant")
    win.owner = W.Label(win, "", 13, W.gold, "LEFT")
    win.money = W.Label(win, "", 12, W.white, "LEFT")
    win.slots = {}
    for i = 1, 10 do
        local b = L.slot(win, i)
        win.controls[3 + i] = b
        K.Wire(win, b, 3 + i)
        win.slots[i] = b
    end
    win.row = K.Buttons(win, { { 3, "OK" }, { 2, "REMOVE" }, { 1, "WITHDRAW" }, { 0, "ADD" } }, L.button)
    L.place(win)
    return win
end

function Merchant.update(win, view)
    local c = view.contents
    win.owner:SetText(K.Text(c.owner) ~= "" and K.Text(c.owner) or "Hired Merchant")
    local hours = math.floor((c.seconds or 0) / 3600)
    win.money:SetText(string.format("Money: %d     Time left: %dh %02dm", c.money or 0, hours, math.floor((c.seconds or 0) % 3600 / 60)))
    for i = 1, 10 do
        local r = c.slots and c.slots[i]
        local b = win.slots[i]
        if type(r) == "table" then
            C.look.ItemIcon(b, r[2], C.look.HiredMerchant.icon)
            b.text:SetText(string.format("%s  x%d   %d coins", K.Text(r[4]), r[5] or 0, r[6] or 0))
        else
            C.look.ItemIcon(b, nil, C.look.HiredMerchant.icon)
            b.text:SetText("(empty)")
        end
    end
    -- s6-modular-g (interfaces, round 13): what a look draws of its own (7.x's: 4a's texts, pictures and counts); drawing only
    if C.look.HiredMerchant.fill then C.look.HiredMerchant.fill(win, c) end
end

C.renderers.EmployeeDialogPane = Merchant

-- D-27: the quantity (string 245 or 247): the merchant menus' input window.
-- Wire: EmployeeQuantityInputDialogPane::OnControlCommand 0x004A4A30 by the input window's indexes (merchant.lua).
C.renderers.EmployeeQuantityInputDialogPane = C.inputRenderer

-- D-28: Take back (0), OK (1), Cancel (2), the price (3). Field 0: the price.
-- Wire: EmployeeItemPropertyDialogPane::OnControlCommand 0x004A4660 by these indexes, field 0 the price; changing either
-- changes what the server sees.
local Price = { look = "Price" }

function Price.build()
    local L = C.look.Price
    local win = K.Window(L.width, L.height, "Price")
    win.text = K.Block(win, 13, "CENTER")
    win.edit = K.Edit(win, 3, L.editWidth, L.editHeight)
    win.row = K.Buttons(win, { { 2, "Cancel" }, { 1, "OK" }, { 0, "Take back" } }, L.button)
    function win:Values() return { self.edit:GetText() } end
    L.place(win)
    return win
end

function Price.update(win, view)
    local c = view.contents
    win.text:SetText(string.format("%d in stock, now %d coins each. The new price:", c.count or 0, c.price or 0))
    if win.opened then
        -- s6-modular-g (round 14, its round 13 finding 1). Wire: the field starts with the record's price, as
        -- EmployeeItemPropertyDialogPane's constructor (0x004A41C0) builds control 3 from it ("%u"); the focus selects it
        -- (K.Edit), so a typed price replaces it, and OK (OnControlCommand 0x004A4660, swscanf "%d") reads what the field
        -- holds, the record's price when untouched. Changing the starting text changes what OK sends after an edit
        -- that keeps part of it.
        K.SetEdit(win.edit, string.format("%d", math.max(0, c.price or 0)))
        win.edit:SetFocus()
    end
    -- s6-modular-g (interfaces, round 13): what a look draws of its own (7.x's: the item's name, count and picture); drawing only
    if C.look.Price.fill then C.look.Price.fill(win, c) end
end

C.renderers.EmployeeItemPropertyDialogPane = Price

-- D-29: CLOSE (1), WITHDRAW or SEND (2), the amount (3), the list (4) of { slot, item, name, amount }. Fields: the
-- selected row's slot, the amount.
-- Wire: ClanBankPane::OnControlCommand 0x0048B630 by these indexes with the two fields; changing them changes what the
-- server sees.
local Bank = { look = "Bank" }

function Bank.build()
    local L = C.look.Bank
    local win = K.Window(L.width, L.height, "Clan Bank")
    win.count = W.Label(win, "", 12, W.grey, "RIGHT")
    win.list = K.List(win, 4, L.listWidth, L.listHeight)
    win.amount = K.Edit(win, 3, L.amountWidth, L.editHeight)
    win.action = K.Button(win, 2, "WITHDRAW", L.button)
    win.close = K.Button(win, 1, "CLOSE", L.button)
    function win:Values()
        local i = self.list:First()
        return { i and tostring(self.list.items[i][1]) or "", self.amount:GetText() }
    end
    L.place(win)
    return win
end

function Bank.update(win, view)
    local c = view.contents
    local rows = c.rows or {}
    win.action:SetText(c.mode == 1 and "SEND" or "WITHDRAW")
    -- ClanBankPane's count: "%d / %d" in mode 0 (the rows, 255), the rows alone in mode 1.
    win.count:SetText(c.mode == 1 and tostring(#rows) or string.format("%d / %d", #rows, 255))
    if win.opened then
        win.list:SetItems(rows, function(row, r)
            C.look.Bank.row(row, r[2])
            local amount = r[4] or 0
            row.text:SetText(amount > 1 and string.format("%s (%d)", K.Text(r[3]), amount) or K.Text(r[3]))
        end)
        K.SetEdit(win.amount, "1")
    end
    -- s6-modular-g (interfaces, round 13): what a look draws of its own (7.x's: the action's picture by the mode); drawing only
    if C.look.Bank.fill then C.look.Bank.fill(win, c) end
end

function Bank.key(win, key)
    if win.view and win.view.focus == 4 then return win.list:Key(key) end
end

C.renderers.ClanBankPane = Bank

-- D-30: REDO (0, Apply), A-D and COLOR (1-5: the selected power to a level), CLOSE (6), the four lists (7-10) of
-- { id, name, amount, level } (one selection among them all), the four thresholds (11-14), and the 5 x 5 grid.
-- Fields: each list's selected power id, then the thresholds' texts.
-- Wire: PowerDialogPane::OnControlCommand 0x0054A4C0 by these indexes with the eight fields; changing them changes what
-- the server sees.
local Power = { look = "Power" }

function Power.build()
    local L = C.look.Power
    local win = K.Window(L.width, L.height, "Power")
    win.lists = {}
    for k = 1, 4 do
        local l = K.List(win, 6 + k, L.listWidth, L.listHeight)
        l.onSelect = function()
            for j = 1, 4 do if j ~= k then win.lists[j]:Select(nil) end end
        end
        win.lists[k] = l
    end
    win.thresholds = {}
    win.grid = {}
    for r = 1, 5 do
        if r <= 4 then win.thresholds[r] = K.Edit(win, 10 + r, L.thresholdWidth, L.thresholdHeight) end
        win.grid[r] = {}
        for col = 1, 5 do win.grid[r][col] = W.Label(win, "", 12, W.white, "RIGHT") end
    end
    win.row = K.Buttons(win, { { 6, "CLOSE" }, { 5, "COLOR" }, { 4, "D" }, { 3, "C" }, { 2, "B" }, { 1, "A" }, { 0, "REDO" } }, L.button)
    function win:Values()
        local out = {}
        for k = 1, 4 do
            local l = self.lists[k]
            local i = l:First()
            out[k] = i and tostring(l.items[i][1]) or ""
        end
        for r = 1, 4 do out[4 + r] = self.thresholds[r]:GetText() end
        return out
    end
    L.place(win)
    return win
end

function Power.update(win, view)
    local c = view.contents
    -- A server's S 46 rebuilds the lists and drops their selections (RefreshPowerEntriesFromPacket); an ordinary refresh
    -- keeps them (review r5, 2). A new dialog starts with none, even in a reused window (its constructor makes fresh
    -- lists, PowerDialogPane.cpp:65; review r7, 3).
    local rebuilt = win.opened or c.rebuilds ~= win.rebuilds
    win.rebuilds = c.rebuilds
    for k = 1, 4 do
        win.lists[k]:SetItems((c.lists or {})[k] or {}, function(row, r)
            row.text:SetText(string.format("%s  L%d", K.Text(r[2]), r[4] or 0))
            -- s6-interface-7x (round 2): what a look draws of a row of its own (7.x's: the level's swatch and the name
            -- alone, as 4a's PowerListPane); drawing only
            if C.look.Power.row then C.look.Power.row(row, r) end
        end, not rebuilt)
        if rebuilt then win.lists[k]:Select(nil) end
    end
    for r = 1, 5 do
        for col = 1, 5 do
            local v = c.grid and c.grid[r] and c.grid[r][col] or 0
            win.grid[r][col]:SetText(tostring(v))
        end
    end
    if win.opened then
        for r = 1, 4 do K.SetEdit(win.thresholds[r], tostring((c.thresholds or {})[r] or 0)) end
    end
end

--- The focused list takes the arrows (ListPane::OnKeyEvent, ListPane.cpp:289; review r5, 4); one selection among the four.
function Power.key(win, key)
    local f = win.view and win.view.focus
    local k = f and f >= 7 and f <= 10 and f - 6
    if not k or not win.lists[k]:Key(key) then return false end
    for j = 1, 4 do if j ~= k then win.lists[j]:Select(nil) end end
    return true
end

C.renderers.PowerDialogPane = Power

-- D-31: CLOSE (0), the categories (1), the rows (2), < (3), > (4), RewardInfo (5), GetReward (6). Field 0: the clicked
-- category's id.
-- Wire: RankingDialog::OnControlCommand 0x00458A10 by these indexes, field 0 the category; changing either changes what
-- the server sees.
local Rankings = { look = "Rankings" }

local function date(d, t)
    d, t = d or 0, t or 0
    return string.format("%02d/%02d/%04d %02d:%02d:%02d", math.floor(d / 100) % 100, d % 100, math.floor(d / 10000),
        math.floor(t / 10000), math.floor(t / 100) % 100, t % 100)
end

function Rankings.build()
    local L = C.look.Rankings
    local win = K.Window(L.width, L.height, "Rankings")
    -- s6-rules-dialogs (round 34): 4a's own panes (RankingEventListPane, RankingUserListPane), whose HitTestRow does not
    -- clamp a press below the rows into the last one as a ListPane's does: own lists (the kit's K.List).
    win.categories = K.List(win, 1, L.categoriesWidth, L.categoriesHeight, false, true)
    win.head = W.Label(win, "", 14, W.gold, "LEFT")
    win.total = W.Label(win, "", 12, W.white, "RIGHT")
    win.dates = W.Label(win, "", 12, W.grey, "LEFT")
    win.rows = K.List(win, 2, L.rowsWidth, L.rowsHeight, false, true)
    win.own = W.Label(win, "", 13, W.gold, "LEFT")
    win.row = K.Buttons(win, { { 0, "CLOSE" }, { 6, "GetReward" }, { 4, ">" }, { 3, "<" }, { 5, "RewardInfo" } }, L.button)
    function win:Values()
        local i = self.categories:First()
        return { i and tostring(self.categories.items[i][1]) or "" }
    end
    L.place(win)
    return win
end

function Rankings.update(win, view)
    local c = view.contents
    local cats = c.categories or {}
    win.categories:SetItems(cats, function(row, cat)
        local mark = cat[3] == 0 and "[!] " or cat[3] == 2 and "" or "[v] "
        row.text:SetText(mark .. K.Text(cat[2]))
        -- s6-modular-g (interfaces, round 13): a look's own rows (7.x's: the state's glyph, the outlined title)
        if C.look.Rankings.category then C.look.Rankings.category(win, row, cat) end
    end, true)
    -- The model's selection shows when it changes (a released click, a server's list): a press alone refreshes the
    -- view too, and must not undo the row it picked before its release (review r5, 1).
    local applied = tostring(c.selected) .. ":" .. #cats
    local sel
    for i, cat in ipairs(cats) do
        if cat[1] == c.selected then
            sel = cat
            if applied ~= win.applied then win.categories:Select(i) end
        end
    end
    win.applied = applied
    if sel then
        win.head:SetText(K.Text(sel[2]))
        win.total:SetText(string.format("Total : %d", c.total or 0))
        win.dates:SetText("From : " .. date(sel[4], sel[5]) .. "     To : " .. date(sel[6], sel[7]))
        win.rows:SetItems(c.rows or {}, function(row, r)
            row.text:SetText(string.format("%-6d %-24s %d", r[1] or 0, K.Text(r[2]), r[3] or 0))
            -- s6-modular-g (interfaces, round 13): a look's own rows (7.x's: three outlined columns)
            if C.look.Rankings.row then C.look.Rankings.row(win, row, r) end
        end)
        local own = c.own
        win.own:SetText(type(own) == "table" and own[1] and own[1] > 0
            and string.format("%-6d %-24s %d", own[1], K.Text(c.ownName), own[2] or 0) or "")
    else
        win.head:SetText("")
        win.total:SetText("")
        win.dates:SetText("")
        win.rows:SetItems({}, function() end)
        win.own:SetText("")
    end
    -- s6-modular-g (interfaces, round 13): what a look draws of its own (7.x's: the title, total, dates and own row apart); drawing only
    if C.look.Rankings.fill then C.look.Rankings.fill(win, c) end
end

function Rankings.key(win, key)
    if win.view and win.view.focus == 1 then return win.categories:Key(key) end
end

C.renderers.RankingDialog = Rankings

-- D-32: OK (0); the tiers { start, end, legend, symbol, items { name, count, item, colour } }, appended.
-- Wire: RankingRewardInfoDialog::OnControlCommand 0x0045DDA0: OK (0); changing it changes what the server sees.
local Rewards = { look = "Rewards" }

function Rewards.build()
    local L = C.look.Rewards
    local win = K.Window(L.width, L.height, "Rewards")
    win.text = K.Block(win, 12)
    win.ok = K.Button(win, 0, "OK", L.button)
    L.place(win)
    return win
end

function Rewards.update(win, view)
    local lines = {}
    for _, t in ipairs(view.contents.tiers or {}) do
        local rank = t[1] == t[2] and K.Text(t[1]) or (K.Text(t[1]) .. " ~ " .. K.Text(t[2]))
        local items = {}
        for _, it in ipairs(t[5] or {}) do items[#items + 1] = string.format("%s(%d)", K.Text(it[1]), it[2] or 0) end
        lines[#lines + 1] = string.format("%-11s %-26s %s", rank, K.Text(t[3]), table.concat(items, ", "))
    end
    win.text:SetText(table.concat(lines, "\n"))
    -- s6-modular-g (interfaces, round 13): what a look draws of its own (7.x's: each tier on its line); drawing only
    if C.look.Rewards.fill then C.look.Rewards.fill(win, view.contents) end
end

C.renderers.RankingRewardInfoDialog = Rewards
