-- s6-rules-dialogs: the merchant menus of server 0x2F (behaviour.md D-09 to D-17): the text menu, the server's items
-- and spells to buy, the player's items and spells to sell or give, the text input, the argumented buy menu and its
-- price and quantity inputs. OK (1), UP (2), CLOSE (3); the list or the edit is 6. The 39 and 43 sends are the model's.
--
-- s6-modular-g (interfaces): the windows' sizes and where their parts sit are the look's (C.look.TextMenu, ItemMenu,
-- SellMenu, GoodsMenu, MerchantInput, Input; Modern's list menus are all its MerchantList), and a look may draw a list's
-- rows its own way (look.row); this file keeps what each menu does.
--
-- Wire: the control indexes and Values() below are what the model's menus answer with, as 4a's OnControlCommand of each
-- class does: TextMenuDialog 0x00519210, ServerItemMenuDialog 0x0051ACB0, ClientItemMenuDialog 0x0051C310,
-- ServerSpellMenuDialog 0x0051D520, ClientSpellMenuDialog 0x0051E4E0, TextInputMenuDialog 0x0051A280,
-- ArgumentedMenuMenuDialog 0x0051F160, ArgumentedItemConfirmInputDialogPane 0x005203C0,
-- ArgumentedItemQuantityInputDialogPane 0x0051FF70 (the row 0-based, or the player's slot; the edit's text); the list's
-- keys choose as 4a's ListPane. Changing an index or a value changes what the server sees.

local C = TK.GetComponent("dialogs")
local K = C.kit
local H = __tk

--- The menus' shared parts: the title, the prompt, CLOSE (3), UP (2) and OK (1), their buttons L.button wide.
local function frame(win, title, L)
    win.title:SetText(title or "")
    win.prompt = K.Block(win, 13)
    win.close = K.Button(win, 3, "CLOSE", L.button)
    win.up = K.Button(win, 2, "UP", L.button)
    win.ok = K.Button(win, 1, "OK", L.button)
end

--- The portrait (the model's picture), for the look to place the prompt and the widget beside and under it.
local function picture(win)
    return K.ShowPicture(win, win.view and win.view.contents.picture, win.view and win.view.contents.status)
end

-- s6-modular-g (interfaces, phase 4): each list menu's look entry: the text and spell menus' (TextMenu: 4a's DLGMERC1
-- with 12-pixel rows in 7.x), the server's items (ItemMenu: DLGMERC3) and the player's (SellMenu: DLGMERC1 with 24-pixel
-- item rows).
local LIST_ENTRIES = { ServerItemMenuDialog = "ItemMenu", ClientItemMenuDialog = "SellMenu" }

-- D-09, D-11 to D-14: the list menus. Field 0: the row (0-based), or for the player's items and spells the slot.
local function listMenu(kind)
    local entry = LIST_ENTRIES[kind] or "TextMenu"
    local R = { look = entry }
    function R.build()
        local L = C.look[entry]
        local win = K.Window(L.width, L.height, "")
        frame(win, kind == "ServerItemMenuDialog" and "Buy" or kind == "ClientItemMenuDialog" and "Sell" or "", L)
        win.list = K.List(win, 6, L.listWidth, L.listHeight)
        if kind == "ServerItemMenuDialog" then
            -- s6-modular-g (interfaces, phase 4): the selected item's description (ServerItemMenuItemList::OnItemSelected
            -- 0x0051B100: control 7's text; empty with no row); a look without its line hides it. Drawing only.
            win.description = K.Block(win, 13)
            win.list.onSelect = function(i)
                local it = win.list.items[i]
                win.description:SetText(it and K.Text(it[5]) or "")
            end
        end
        function win:Values()
            local i = self.list:First()
            if not i then return { "" } end
            local item = self.list.items[i]
            if kind == "ClientItemMenuDialog" or kind == "ClientSpellMenuDialog" then return { tostring(item.slot) } end
            return { tostring(i - 1) }
        end
        L.place(win)
        return win
    end
    function R.update(win, view)
        local c = view.contents
        local look = C.look[entry]
        win.prompt:SetText(K.Text(c.prompt))
        look.fit(win, picture(win))
        if not win.opened then return end
        if win.description then win.description:SetText("") end
        if kind == "ServerItemMenuDialog" then
            -- Round 19: the name and the row's number, as 4a draws them (ServerItemMenuItemList::DrawListEntry, "%10u"):
            -- a price, or for a bank's Withdraw Item the count it holds (live 2026-10-01), so no "coins".
            win.list:SetItems(c.items or {}, function(row, it)
                row.text:SetText(K.Text(it[4]) .. "   " .. tostring(it[3]))
                -- s6-modular-g: a look's own rows (7.x's: the item's picture, its name and the number)
                -- (s6-interface-7x round 2: with the picture's colour, it[2])
                if look.row then look.row(win, row, { item = it[1], colour = it[2], price = it[3], name = K.Text(it[4]) }) end
            end)
        elseif kind == "ClientItemMenuDialog" then
            local items = {}
            for _, slot in ipairs(c.slots or {}) do
                local ok, name, _, _, icon, colour = H:GetItemSlot(slot)
                -- Round 17: only the slots that hold an item, as 4a lists them (record->active, TextMenuItemList.cpp:1099).
                -- (s6-interface-7x round 2: with the picture's colour)
                if ok then items[#items + 1] = { slot = slot, name = name or "", icon = icon, colour = colour } end
            end
            win.list:SetItems(items, function(row, it)
                row.text:SetText(K.SlotLetter(it.slot) .. ")  " .. it.name)
                if look.row then look.row(win, row, it) end -- s6-modular-g: a look's own rows (7.x's item rows)
            end)
        elseif kind == "ClientSpellMenuDialog" then
            local items = {}
            for slot = 1, 52 do
                local ok, name = H:GetSpellSlot(slot)
                if ok and name then items[#items + 1] = { slot = slot, name = name } end
            end
            win.list:SetItems(items, function(row, it) row.text:SetText(K.SlotLetter(it.slot) .. ")  " .. it.name) end)
        else
            win.list:SetItems(c.rows or {}, function(row, text) row.text:SetText(K.Text(text)) end)
        end
    end
    function R.key(win, key)
        if win.view and win.view.focus == 6 then return win.list:Key(key) end
    end
    C.renderers[kind] = R
end

for _, kind in ipairs({ "TextMenuDialog", "ServerItemMenuDialog", "ClientItemMenuDialog", "ServerSpellMenuDialog",
    "ClientSpellMenuDialog" }) do
    listMenu(kind)
end

-- D-10: the prompt and the edit (6). Field 0: its text.
local TextInput = { look = "MerchantInput" }

function TextInput.build()
    local L = C.look.MerchantInput
    local win = K.Window(L.width, L.height, "")
    frame(win, "", L)
    win.edit = K.Edit(win, 6, L.editWidth, L.editHeight)
    win.edit:SetMaxLetters(1024)
    function win:Values() return { self.edit:GetText() } end
    L.place(win)
    return win
end

function TextInput.update(win, view)
    win.prompt:SetText(K.Text(view.contents.prompt))
    C.look.MerchantInput.fit(win, picture(win))
    if win.opened then
        K.SetEdit(win.edit, "")
        win.edit:SetFocus()
    end
end

C.renderers.TextInputMenuDialog = TextInput

-- D-15: the goods (value, item, colour, price, count, name). Field 0: the row (0-based). s6-modular-g: its own look
-- entry (GoodsMenu: 4a's DLGMERC3 in 7.x).
local Argumented = { look = "GoodsMenu" }

function Argumented.build()
    local L = C.look.GoodsMenu
    local win = K.Window(L.width, L.height, "Buy")
    frame(win, "Buy", L)
    win.list = K.List(win, 6, L.listWidth, L.listHeight)
    function win:Values()
        local i = self.list:First()
        return { i and tostring(i - 1) or "" }
    end
    L.place(win)
    return win
end

function Argumented.update(win, view)
    local c = view.contents
    local look = C.look.GoodsMenu
    win.prompt:SetText(K.Text(c.prompt))
    look.fit(win, picture(win))
    if win.opened then
        -- Round 19: the name, the count and the price grouped by commas, "1gold " before it for more than one, as 4a
        -- draws them (ArgumentedMenuMenuItemList::DrawListEntry, TextMenuItemList.cpp:2098-2131).
        win.list:SetItems(c.items or {}, function(row, it)
            local count = it[5] or 0
            row.text:SetText(K.Text(it[6]) .. "   " .. tostring(count) .. "   " .. (count > 1 and "1gold " or "") .. TK.Util.FormatNumber(it[4] or 0))
            -- s6-modular-g: a look's own rows (7.x's: the item's picture, its name, the count and the price)
            -- (s6-interface-7x round 2: with the picture's colour, it[3])
            if look.row then look.row(win, row, { item = it[2], colour = it[3], price = it[4], count = count, name = K.Text(it[6]) }) end
        end)
    end
end

function Argumented.key(win, key)
    if win.view and win.view.focus == 6 then return win.list:Key(key) end
end

C.renderers.ArgumentedMenuMenuDialog = Argumented

-- D-16, D-17: a line of text (D-17: string 246), the edit (4), OK (1), CANCEL (2). Field 0: the edit's text.
local Input = { look = "Input" }

function Input.build()
    local L = C.look.Input
    local win = K.Window(L.width, L.height, "")
    win.text = K.Block(win, 13, "CENTER")
    win.edit = K.Edit(win, 4, L.editWidth, L.editHeight)
    win.cancel = K.Button(win, 2, "CANCEL", L.button)
    win.ok = K.Button(win, 1, "OK", L.button)
    function win:Values() return { self.edit:GetText() } end
    L.place(win)
    return win
end

function Input.update(win, view)
    local c = view.contents
    local text = K.Text(c.text)
    if text == "" and c.stringId then text = K.String(c.stringId, "How many?") end
    win.text:SetText(text)
    C.look.Input.fit(win)
    if win.opened then
        K.SetEdit(win.edit, "")
        win.edit:SetFocus()
    end
end

C.renderers.ArgumentedItemConfirmInputDialogPane = Input
C.renderers.ArgumentedItemQuantityInputDialogPane = Input
C.inputRenderer = Input
