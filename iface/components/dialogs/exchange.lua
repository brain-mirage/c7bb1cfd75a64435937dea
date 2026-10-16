-- s6-rules-dialogs: the trade and mixing (behaviour.md D-18 to D-24). The trade window shows both sides' items and
-- money; the player's money field goes to the model with every digit typed (it sends 4A 03 then). The item pickers
-- list the player's inventory; the mixing window keeps its rows in the model.
--
-- s6-modular-g (interfaces): the windows' sizes and where their parts sit are the look's (C.look.Trade, Picker,
-- Count, Mix); this file keeps what each dialog does.

local C = TK.GetComponent("dialogs")
local K = C.kit
local W = TK.UI
local H = __tk

local function itemName(slot)
    local ok, name, count = H:GetItemSlot(slot)
    if not ok or not name then return "", 0 end
    return name, count or 1
end

-- D-18: Accept (1), Add (2), Cancel (3), the lists (5 mine, 8 theirs), the money field (6). Field 0: the money.
-- Wire: ExchangeDialog::OnControlCommand 0x004AD0B0 by these indexes, and HandleKeyOrTextEvent 0x004AD7D0 for the money
-- field, which goes to the model with each digit typed (K.Edit); changing an index, the field or when it goes changes
-- what the server sees.
local Trade = { look = "Trade" }

function Trade.build()
    local L = C.look.Trade
    local win = K.Window(L.width, L.height, "Trade")
    win.theirLabel = W.Label(win, "", 13, W.gold, "LEFT")
    win.mine = K.List(win, 5, L.listWidth, L.listHeight)
    win.theirs = K.List(win, 8, L.listWidth, L.listHeight)
    win.money = K.Edit(win, 6, L.moneyWidth, L.editHeight)
    win.money:SetNumeric(true)
    -- Round 37. Wire: 4a's ExchangeMoneyEditControlPane (ExchangeDialog.cpp:1116-1144), not an ordinary edit: the focus
    -- selects nothing (Activate 0x004B0B40), only a digit is typed and always after the text (HandleKeyOrTextEvent
    -- 0x004B0B60; Home, Backspace and the rest edit nothing), and the pointer moves no caret (HandlePointerOrMouseEvent
    -- 0x004B0BA0). So the "0" stays first and only nine digits count in what 4A 03 sends (ReadText(text, 10)); the keys still
    -- reach the dialog as before (Tab, Enter, Escape, and each digit's 4A 03). Changing it changes the amount the server sees.
    win.money:SetAppendDigitsOnly(true)
    win.theirMoney = W.Label(win, "", 13, W.white, "LEFT")
    win.ready = W.Label(win, "", 12, { 0.4, 1, 0.4 }, "LEFT")
    win.cancel = K.Button(win, 3, "Cancel", L.button)
    win.add = K.Button(win, 2, "Add", L.button)
    win.accept = K.Button(win, 1, "Accept", L.button)
    function win:Values() return { self.money:GetText() } end
    L.place(win)
    return win
end

local function rows(list, items)
    list:SetItems(items or {}, function(row, it)
        row.text:SetText(K.Text(it[4]))
    end, true)
end

function Trade.update(win, view)
    local c = view.contents
    win.theirLabel:SetText(K.Text(c.partner))
    rows(win.mine, c.mine)
    rows(win.theirs, c.theirs)
    win.theirMoney:SetText((c.theirMoney or "0") .. " coins")
    if win.opened or win.moneySet ~= c.myMoneySet then
        -- The server's own amount (S 42 03 for the player) replaces the field.
        win.moneySet = c.myMoneySet
        K.SetEdit(win.money, c.myMoney or "")
    end
    local ready = {}
    if c.localReady then ready[#ready + 1] = "You are ready." end
    if c.remoteReady then ready[#ready + 1] = K.Text(c.partner) .. " is ready." end
    win.ready:SetText(table.concat(ready, "  "))
    -- s6-modular-g (interfaces, phase 4): what a look draws of its own (7.x's: the player's name and level, the partner's
    -- level, the money with commas, the items' pictures); drawing only
    if C.look.Trade.fill then C.look.Trade.fill(win, c) end
end

C.renderers.ExchangeDialog = Trade

-- D-19 (and the employee's D-26): the player's items, OK (1), Cancel (2), the list (3). Field 0: the chosen slots.
-- D-23: the same, of the items not in the mix; field 0 as slot:stack.
-- stacked: the values as slot:stack; single: one choice.
-- Wire: AddItemDialog::OnControlCommand 0x004AE930, AddEmployeeItemDialog's 0x004A4B20, AddMixingItemDialog's
-- 0x004B0120, by these indexes with field 0 as Values() writes it; changing either changes what the server sees.
local function picker(name, mixing, stacked, single)
    local R = { look = "Picker" }
    function R.build()
        local L = C.look.Picker
        local win = K.Window(L.width, L.height, mixing and "Add to the mix" or "Add")
        win.list = K.List(win, 3, L.listWidth, L.listHeight, not single)
        win.cancel = K.Button(win, 2, "Cancel", L.button)
        win.ok = K.Button(win, 1, "OK", L.button)
        function win:Values()
            local out = {}
            for _, i in ipairs(self.list:All()) do
                local it = self.list.items[i]
                out[#out + 1] = stacked and (it.slot .. ":" .. it.count) or tostring(it.slot)
            end
            return { table.concat(out, ",") }
        end
        L.place(win)
        return win
    end
    function R.update(win)
        if not win.opened then return end
        local inMix = {}
        if mixing then
            local mix = C:Find("MixItemDialog")
            for _, r in ipairs(mix and mix.view.contents.rows or {}) do inMix[r[1]] = true end
        end
        local items = {}
        for _, it in ipairs(K.Inventory()) do
            if not inMix[it.slot] then items[#items + 1] = it end
        end
        win.list:SetItems(items, function(row, it)
            row.text:SetText(K.SlotLetter(it.slot) .. ")  " .. it.name .. (it.count > 1 and (" x" .. it.count) or ""))
            -- s6-modular-g (interfaces, round 12): a look's own rows (7.x's: the item's picture and its name)
            if C.look.Picker.row then C.look.Picker.row(win, row, it) end
        end)
    end
    function R.key(win, key)
        if win.view and win.view.focus == 3 then return win.list:Key(key) end
    end
    C.renderers[name] = R
end

picker("AddItemDialog", false, false, false)
picker("AddEmployeeItemDialog", false, true, true)
picker("AddMixingItemDialog", true, true, false)

-- D-20: string 158 with the item's name, the count (4), OK (1), Cancel (2). D-24: string 218, 1 to the stack.
-- Wire: AddItemWithCountDialog::OnControlCommand 0x004AF380, NumberInputDialog's 0x00530B40, by the input window's
-- indexes (merchant.lua's Input) with the count as field 0; changing either changes what the server sees.
local Count = { look = "Count" }

function Count.build()
    local win = C.inputRenderer.build()
    return win
end

function Count.update(win, view)
    local c = view.contents
    local name = c.slot and itemName(c.slot) or ""
    local text = K.String(c.stringId, "How many?")
    -- s6-modular-g (round 12, the capture against the original): string 158 is a format, "How many %ss will you add?",
    -- that AddItemWithCountDialog (0x004AF040) fills with the item's display name; a prompt without one keeps the name
    -- on a line of its own
    if name ~= "" and text:find("%%s") then
        text = text:gsub("%%s", function() return name end, 1)
    elseif name ~= "" then
        text = text .. "\n" .. name
    end
    if c.max then text = text .. "  (1 - " .. c.max .. ")" end
    win.text:SetText(text)
    C.look.Input.fit(win)
    if win.opened then
        K.SetEdit(win.edit, "")
        win.edit:SetFocus()
    end
end

C.renderers.AddItemWithCountDialog = Count
C.renderers.NumberInputDialog = Count

-- D-22: ADD (1), DELETE (2), OK (3), CANCEL (4), the rows (5: slot, quantity). Field 0: the row (0-based).
-- Wire: MixItemDialog::OnControlCommand 0x004AF8B0 by these indexes, field 0 the row; changing either changes what the
-- server sees.
local Mix = { look = "Mix" }

function Mix.build()
    local L = C.look.Mix
    local win = K.Window(L.width, L.height, "Mix")
    win.list = K.List(win, 5, L.listWidth, L.listHeight)
    win.cancel = K.Button(win, 4, "CANCEL", L.button)
    win.ok = K.Button(win, 3, "OK", L.button)
    win.delete = K.Button(win, 2, "DELETE", L.button)
    win.add = K.Button(win, 1, "ADD", L.button)
    function win:Values()
        local i = self.list:First()
        return { i and tostring(i - 1) or "" }
    end
    L.place(win)
    return win
end

function Mix.update(win, view)
    local rowsNow = view.contents.rows or {}
    win.list:SetItems(rowsNow, function(row, r)
        local name = itemName(r[1])
        row.text:SetText(K.SlotLetter(r[1]) .. ")  " .. name .. "  x" .. tostring(r[2]))
        -- s6-modular-g (interfaces, round 12): a look's own rows (7.x's: the item's picture and its name)
        if C.look.Mix.row then C.look.Mix.row(win, row, r) end
    end, #rowsNow == #win.list.items)
end

function Mix.key(win, key)
    if win.view and win.view.focus == 5 then return win.list:Key(key) end
end

C.renderers.MixItemDialog = Mix
