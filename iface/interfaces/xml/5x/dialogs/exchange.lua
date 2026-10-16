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
--
-- s6-ui-core (round 85): the XML twin's; the windows' sizes, pictures and the parts' places are exchange.xml's
-- (core/xml.md).

local S = require("interfaces.5x.skin")
local K = TK.GetComponent("dialogs").kit
local unpack = table.unpack
local entry = require("interfaces.xml.entry")
local D = TK.Xml.Data("exchange.xml")

return function(L, X)
    local T = D.Trade
    L.Trade = entry(T, {
        place = function(win)
            X.Size(win, T.width, T.height)
            X.Art(win, unpack(T.art))
            X.Image(win, win.accept, unpack(T.accept))
            X.Image(win, win.add, unpack(T.add))
            X.Image(win, win.cancel, unpack(T.cancel))
            X.StaticText(win, "x5myName", unpack(T.myName))
            X.List(win, win.mine, unpack(T.mine))
            X.Edit(win.money, win, unpack(T.money)) -- its own text, "0" at first (the model's, as 5.33's field)
            X.Text(win.theirLabel, win, unpack(T.theirLabel))
            win.theirLabel:SetWordWrap(false)
            X.List(win, win.theirs, unpack(T.theirs))
            X.StaticText(win, "x5theirMoney", unpack(T.theirMoney))
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
            local cx, x = unpack(T.row)
            for _, list in ipairs({ win.mine, win.theirs }) do
                for i, it in ipairs(list.items) do
                    X.ItemRow(list, list.rows[i], { item = it[2], colour = it[3], name = K.Text(it[4]) }, cx, x)
                end
            end
            X.Default(win, win.accept)
            -- ExchangeDialog 0x0042B300 slides open as it is built (0x004208F0): the picture once it has its rows
            if win.opened then X.SlideOpen(win) end
        end,
    })

    local P = D.Picker
    L.Picker = entry(P, {
        place = function(win)
            X.Art(win, unpack(P.art))
            X.Image(win, win.ok, unpack(P.ok))
            X.Image(win, win.cancel, unpack(P.cancel))
            X.List(win, win.list, unpack(P.list))
            X.RowColours(win.list)
            X.Default(win, win.ok)
        end,
        row = function(win, row, it) X.ItemRow(win.list, row, it, unpack(P.row)) end,
    })

    local M = D.Mix
    L.Mix = entry(M, {
        place = function(win)
            X.Art(win, unpack(M.art))
            X.Image(win, win.add, unpack(M.add))
            X.Image(win, win.delete, unpack(M.delete))
            X.Image(win, win.ok, unpack(M.ok))
            X.Image(win, win.cancel, unpack(M.cancel))
            X.List(win, win.list, unpack(M.list))
            X.RowColours(win.list)
            X.Default(win, win.ok)
        end,
        -- a row ({ slot, quantity }): the slot's item
        row = function(win, row, r)
            local _, name, _, _, icon, colour = __tk:GetItemSlot(r[1])
            X.ItemRow(win.list, row, { icon = icon, colour = colour, name = name or "" }, unpack(M.row))
        end,
    })

    -- The trade's counts and the mix's quantity: merchant.lua's L.Input draws them, by class.
    L.Count = {}
end
