-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md, "The dialogs look"): 5.x's look of
-- the trade and the mixing (components/dialogs/exchange.lua), from 5.33's own constructors. Every window is in
-- NPAL8.PAL, at placement slot 8 (centred on (320, 240): L.Place), sliding open as 5.33's (the trade when it is filled,
-- the pickers and the mixing through their entry: X.SlideOpen); its buttons are 5.33's image buttons, 72 x 16 (X.Image); its texts and edits 5.33's, in 0x80; its control
-- indexes 7.5.2's, so the renderer is unchanged.
-- - The trade (ExchangeDialog 0x0042B300): 506 x 322 on DLGEXC1; OK (Accept, 14) (42, 272), ADD (36) (217, 272),
--   CANCEL (22) (392, 272); the player's name alone (51, 71)-(235, 84) (the status pane's name: no "(%s)" line, no level:
--   5.33 has neither number); the player's items (36, 89)-(251, 232); the money (79, 237)-(204, 250), plain digits as
--   typed; the partner's name (271, 71)-(454, 84), items (255, 89)-(470, 232) and money (298, 237)-(454, 250) as "%u"
--   (ExchangeDialog_RawMoneyUpdate 0x0042C3A0: no commas). The item lists' rows (ExchangeItemListPane 0x0042C970):
--   156 x 24 cells, the item's picture at full size centred on x 25, its whole name from 50 in 0x25, no selection bar.
-- - The item pickers (AddItemDialog 0x0042CA90, AddMixingItemDialog 0x0042DE00; the hired merchant's, which 5.33 has
--   not, as these: decision 2026-10-04-5x-merchant-trade-board-windows): 287 x 277 on DLGEXC2; ADD (36) (69, 225),
--   CANCEL (22) (146, 225); the player's items (36, 61)-(251, 205), 205 x 24 cells (MyItemListPane 0x0042CFE0: the
--   picture at full size on x 25, the name from 50 fitted to 155, the picked rows on a 0x25 bar the cell wide, 0x80).
-- - The mixing (MixItemDialog 0x0042D610): 446 x 274 on MIXITEM; ADD (36) (72, 224), DELETE (21) (149, 224), OK (14)
--   (226, 224), CANCEL (22) (303, 224); its rows (113, 71)-(332, 203), the pickers' rows.
-- - The trade's count and the mix's quantity are the DLGEXC3 windows (merchant.lua's L.Input).
-- Each draws DialogPane's Enter frames round its default button (X.Default: Accept, ADD, OK). Drawing only: the
-- indexes, the money field's digits and what is sent are the renderer's and the model's.

local S = require("interfaces.5x.skin")
local K = TK.GetComponent("dialogs").kit

return function(L, X)
    local P = "NPAL8.PAL"

    L.Trade = {
        width = 506, height = 322, button = 72, listWidth = 202, listHeight = 143, moneyWidth = 125, editHeight = 13,
        place = function(win)
            X.Size(win, 506, 322)
            X.Art(win, "DLGEXC1.EPF", P)
            X.Image(win, win.accept, 14, 42, 272, 114, 288)
            X.Image(win, win.add, 36, 217, 272, 289, 288)
            X.Image(win, win.cancel, 22, 392, 272, 464, 288)
            X.StaticText(win, "x5myName", 51, 71, 235, 84)
            X.List(win, win.mine, 36, 89, 251, 232, 156, 24)
            X.Edit(win.money, win, 79, 237, 204, 250) -- its own text, "0" at first (the model's, as 5.33's field)
            X.Text(win.theirLabel, win, 271, 71, 454, 84)
            win.theirLabel:SetWordWrap(false)
            X.List(win, win.theirs, 255, 89, 470, 232, 156, 24)
            X.StaticText(win, "x5theirMoney", 298, 237, 454, 250)
            -- the renderer's own texts 5.33 has not (the money with " coins", the ready line)
            win.theirMoney:Hide()
            win.ready:Hide()
            X.RowColours(win.mine, false)
            X.RowColours(win.theirs, false)
        end,
        -- the player's name (the status pane's), the partner's money as "%u", the rows' pictures
        fill = function(win, c)
            local _, name = __tk:GetUnitInfo("player")
            win.x5myName:SetText(name or "")
            win.x5theirMoney:SetText(string.format("%d", tonumber(c.theirMoney) or 0))
            for _, list in ipairs({ win.mine, win.theirs }) do
                for i, it in ipairs(list.items) do
                    X.ItemRow(list, list.rows[i], { item = it[2], colour = it[3], name = K.Text(it[4]) }, 25, 50)
                end
            end
            X.Default(win, win.accept)
            -- ExchangeDialog 0x0042B300 slides open as it is built (0x004208F0): the picture once it has its rows
            if win.opened then X.SlideOpen(win) end
        end,
    }

    L.Picker = {
        width = 287, height = 277, button = 72, listWidth = 202, listHeight = 144, slide = true,
        place = function(win)
            X.Art(win, "DLGEXC2.EPF", P)
            X.Image(win, win.ok, 36, 69, 225, 141, 241)
            X.Image(win, win.cancel, 22, 146, 225, 218, 241)
            X.List(win, win.list, 36, 61, 251, 205, 205, 24)
            X.RowColours(win.list)
            X.Default(win, win.ok)
        end,
        row = function(win, row, it) X.ItemRow(win.list, row, it, 25, 50, 155) end,
    }

    L.Mix = {
        width = 446, height = 274, button = 72, listWidth = 206, listHeight = 132, slide = true,
        place = function(win)
            X.Art(win, "MIXITEM.EPF", P)
            X.Image(win, win.add, 36, 72, 224, 144, 240)
            X.Image(win, win.delete, 21, 149, 224, 221, 240)
            X.Image(win, win.ok, 14, 226, 224, 298, 240)
            X.Image(win, win.cancel, 22, 303, 224, 375, 240)
            X.List(win, win.list, 113, 71, 332, 203, 205, 24)
            X.RowColours(win.list)
            X.Default(win, win.ok)
        end,
        -- a row ({ slot, quantity }): the slot's item
        row = function(win, row, r)
            local _, name, _, _, icon, colour = __tk:GetItemSlot(r[1])
            X.ItemRow(win.list, row, { icon = icon, colour = colour, name = name or "" }, 25, 50, 155)
        end,
    }

    -- The trade's counts and the mix's quantity: merchant.lua's L.Input draws them, by class.
    L.Count = {}
end
