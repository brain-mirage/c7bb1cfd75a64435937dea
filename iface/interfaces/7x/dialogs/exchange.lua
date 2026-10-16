-- s6-modular-g (interfaces, phase 4): 7.x's look of the trade window (components/dialogs/exchange.lua), 4a's
-- ExchangeDialog (0x004AC8A0, Source-5's class page): 451 x 371 on DLGEXC1.EPF in DLGEXC1.PAL, at placement slot 9
-- (centred, as every slot but 13), sliding open. Its controls by their indexes: Accept (1, image 14) (84, 335)-(147, 359),
-- Add (2, image 36) (188, 335)-(251, 359), Cancel (3, image 22) (292, 335)-(355, 359); the player's name (4,
-- "%s(%s)": the name and the status pane's line B) (30, 60)-(197, 72); the player's items (5) (30, 110)-(222, 283); the
-- player's money (6) (73, 295)-(197, 307); the partner's name (7) (241, 60)-(408, 72); the partner's items (8)
-- (241, 110)-(432, 283); the partner's money (9) (284, 295)-(408, 307); both moneys drawn with a comma every three
-- digits (input mode 1); the player's number (10, UserStatusPane::m_classId: the level)
-- (82, 83)-(210, 95); the partner's (11, from the opening packet) (295, 83)-(423, 95). The item lists
-- (ExchangeItemListPane::DrawListEntry 0x004AE1C0): 156 x 24 cells, the item's picture at half size centred on x 25,
-- its name from x 50 in 0x25, no bar for the selected row. Drawing only: the indexes, the money field's digits and what
-- is sent are the renderer's and the model's.

local S = require("interfaces.7x.skin")
local K = TK.Dialogs

return function(L, X)
    --- One of the window's own texts (the player's name, the two numbers, the partner's money with commas), made once.
    local function own(win, key)
        if not win[key] then win[key] = win:CreateFontString(nil, "OVERLAY") end
        return win[key]
    end

    --- MyItemListPane's names (the pickers' and the mix's): 0x80 on the picked row's bar, else 0x25.
    local function picked(list)
        list.rowPainter = function(r, selected)
            if r.itemName then r.itemName:SetTextColor(S.Colour(selected and S.TEXT or S.LIST)) end
        end
    end

    L.Trade = {
        width = 451, height = 371, button = 63, listWidth = 156, listHeight = 173, moneyWidth = 124, editHeight = 12,
        place = function(win)
            X.Size(win, 451, 371)
            X.Art(win, "DLGEXC1.EPF", "DLGEXC1.PAL")
            X.Image(win, win.accept, 14, 84, 335, 147, 359)
            X.Image(win, win.add, 36, 188, 335, 251, 359)
            X.Image(win, win.cancel, 22, 292, 335, 355, 359)
            X.Text(own(win, "x7myName"), win, 30, 60, 197, 72)
            X.List(win, win.mine, 30, 110, 222, 283, 156, 24)
            X.Edit(win.money, win, 73, 295, 197, 307)
            -- the money field drawn as 4a's input mode 1 draws it (TextEditPane::DrawTextCharacters): its digits with a
            -- comma every three, while it is typed in too; "0" while it is empty (4a's field starts as "0"). Over the
            -- edit, whose own text and caret are clear; what goes to the model is the edit's text, unchanged
            X.Text(own(win, "x7money"), win, 73, 295, 197, 307)
            __tk:SetTextColor(win.money.__h, 0, 0, 0, 0)
            win.money:HookScript("OnTextChanged", function(self)
                win.x7money:SetText(TK.Util.FormatNumber(tonumber(self:GetText()) or 0))
            end)
            X.Text(win.theirLabel, win, 241, 60, 408, 72)
            X.List(win, win.theirs, 241, 110, 432, 283, 156, 24)
            X.Text(own(win, "x7theirMoney"), win, 284, 295, 408, 307)
            win.theirMoney:Hide()
            X.Text(own(win, "x7myNumber"), win, 82, 83, 210, 95)
            X.Text(own(win, "x7theirNumber"), win, 295, 83, 423, 95)
            win.ready:Hide()
            -- no bar for the selected row; its name always in 0x25
            for _, list in ipairs({ win.mine, win.theirs }) do
                list.rowPainter = function(r)
                    r.sel:Hide()
                    if r.itemName then r.itemName:SetTextColor(S.Colour(S.LIST)) end
                end
            end
        end,
        -- what the window shows of the model and the player (Trade.update, after its own texts): the name and the
        -- numbers, the partner's money with commas, the rows' pictures
        fill = function(win, c)
            local _, name, level = __tk:GetUnitInfo("player")
            -- 4a's "%s(%s)": the status pane's name and its line B (the path, from the 0x39 packet;
            -- UserStatusPane::CopyNameLineB 0x005B85D0), empty before one came
            local hasSheet, _, _, _, lineB = __tk:GetSheet()
            win.x7myName:SetText(string.format("%s(%s)", name or "", hasSheet and lineB or ""))
            win.x7money:SetText(TK.Util.FormatNumber(tonumber(win.money:GetText()) or 0))
            win.x7myNumber:SetText(tostring(level or 0))
            win.x7theirNumber:SetText(tostring(c.partnerNumber or 0))
            -- a comma every three digits (StaticTextControlPane's input mode 1)
            win.x7theirMoney:SetText(TK.Util.FormatNumber(tonumber(c.theirMoney) or 0))
            -- the rows: the item's picture (with its colour: s6-interface-7x round 2) centred on x 25, its name from 50
            -- (rows {slot, item, colour, name})
            for _, list in ipairs({ win.mine, win.theirs }) do
                for i, it in ipairs(list.items) do
                    X.ItemRow(list, list.rows[i], { item = it[2], colour = it[3], name = K.Text(it[4]) }, 25, 50, 156 - 50)
                end
            end
            if win.opened then X.SlideOpen(win) end
        end,
    }

    -- The item pickers (AddItemDialog 0x004AE4C0 and the two built on it, AddEmployeeItemDialog and AddMixingItemDialog):
    -- 241 x 340 on DLGEXC2.EPF in PAL01.PAL, at placement slot 9, sliding open; ADD (1, image 36) (55, 303)-(118, 327),
    -- CANCEL (2, image 22) (132, 303)-(195, 327); the player's items (3: MyItemListPane, 170 x 24 cells, several may
    -- be picked) at (30, 30)-(218, 270): the item's picture centred on x 25, its name from 50 fitted with "...", the
    -- picked rows on a 0x25 bar the cell wide.
    L.Picker = {
        width = 241, height = 340, button = 63, listWidth = 170, listHeight = 240,
        slide = true,
        place = function(win)
            X.Art(win, "DLGEXC2.EPF", "PAL01.PAL")
            X.Image(win, win.ok, 36, 55, 303, 118, 327)
            X.Image(win, win.cancel, 22, 132, 303, 195, 327)
            X.List(win, win.list, 30, 30, 218, 270, 170, 24)
            picked(win.list)
        end,
        row = function(win, row, it) X.ItemRow(win.list, row, it, 25, 50, 170 - 50) end,
    }

    -- The mixing window (MixItemDialog 0x004AF570): 292 x 309 on MIXITEM.EPF in MIXITEM.PAL, at placement slot 9, sliding
    -- open; ADD (1, image 36) (23, 273), DELETE (2, 21) (85, 273), OK (3, 14) (147, 273), CANCEL (4, 22) (209, 273); the
    -- mix's rows (5: a MyItemListPane, 170 x 24 cells) at (37, 68)-(264, 236), as the pickers' rows: the item's picture
    -- centred on x 25, its name (the slot's) from 50 fitted with "...", the selected row on a 0x25 bar the cell wide.
    L.Mix = {
        width = 292, height = 309, button = 63, listWidth = 214, listHeight = 168, slide = true,
        place = function(win)
            X.Art(win, "MIXITEM.EPF", "MIXITEM.PAL")
            X.Image(win, win.add, 36, 23, 273, 86, 297)
            X.Image(win, win.delete, 21, 85, 273, 148, 297)
            X.Image(win, win.ok, 14, 147, 273, 210, 297)
            X.Image(win, win.cancel, 22, 209, 273, 272, 297)
            X.List(win, win.list, 37, 68, 264, 236, 170, 24)
            picked(win.list)
        end,
        -- a row ({ slot, quantity }): the slot's item
        row = function(win, row, r)
            local _, name, _, _, icon, colour = __tk:GetItemSlot(r[1])
            X.ItemRow(win.list, row, { icon = icon, colour = colour, name = name or "" }, 25, 50, 170 - 50)
        end,
    }

    -- The trade's counts and the stack's number (AddItemWithCountDialog 0x004AF040, NumberInputDialog 0x00530640):
    -- built by the purchase's input renderer (merchant.lua's L.Input draws them, by class), 7.x windows by this entry.
    L.Count = {}
end
