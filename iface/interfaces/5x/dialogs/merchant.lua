-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md, "The dialogs look"): 5.x's look of
-- the merchant menus (components/dialogs/merchant.lua), from 5.33's own constructors (server 0x2F's kinds:
-- MerchantDialogCreator_CreateMerchantMenuDialog 0x0046DDF0). Every window is in NPAL8.PAL, opens at placement slot 1,
-- centred on (320, 240) (L.Place), and does not slide, but for the inputs, which slide open as 5.33's (NumberInputDialog
-- 0x0047CDD0 and AddItemWithCountDialog 0x0042D150 call 0x004208F0: L.Input's fit); its buttons are 5.33's image buttons, 72 x 16 (X.Image: 14 OK,
-- 16 TOP, 15 QUIT, 22 CANCEL, 36 ADD), its portrait the packet's object (ObjectImageControlPane, always added), its prompt
-- 5.33's static text in 0x80, its rows 5.33's (selected: a 0x25 bar the cell wide, texts 0x80; else 0x25).
-- - The text and spell menus (TextMenuDialog 0x0046E450, ServerSpellMenuDialog 0x00471510, ClientSpellMenuDialog
--   0x00471E50) and the sell menu (ClientItemMenuDialog 0x00470AB0): 314 x 356 on DLGMERC1; OK, TOP, QUIT along y
--   306-322; the portrait (35, 37)-(72, 92); the prompt (122, 37)-(266, 133); the list (36, 141)-(278, 285) of 228-pixel
--   cells, 12 high (the sell menu's 24: the item's picture at full size centred on x 12, its name from 50 fitted to 178).
--   5.33 draws a text menu of 6 or fewer options on its tiled window (MERTOP to MERBOT) with an answer button for each;
--   5.x draws every text menu on the list window (decision 2026-10-04-5x-merchant-trade-board-windows).
-- - The server's items (ServerItemMenuDialog 0x0046FE60): 434 x 371 on DLGMERC3; OK, TOP, QUIT along y 281-297; the
--   prompt (83, 30)-(383, 130); the list (36, 140)-(398, 260) of 348 x 24 cells (the picture at full size on x 12, the
--   name in 50-270 fitted to 220, "%10u" from the cell's right - 62); the description (50, 310)-(384, 322).
-- - The goods (7.5.2's ArgumentedMenuMenuDialog; 5.33's kind 10 is another menu): on the server items' window, the
--   count and the grouped price beside the name (the decision above).
-- - The text input (TextInputMenuDialog 0x0046F710): 314 x 197 on DLGMERC2; OK, TOP, QUIT along y 147-163; the prompt
--   (82, 35)-(262, 83); the edit (56, 113)-(257, 125) in 0x80.
-- - The windows on DLGEXC3 (AddItemWithCountDialog 0x0042D150, NumberInputDialog 0x0047CDD0; the purchase's two inputs,
--   which 5.33 has not, on the same layout: the decision above): 287 x 277; the first button (ADD 36 for the count, else
--   OK 14) (69, 225)-(141, 241), CANCEL 22 (146, 225)-(218, 241); the text (37, 36)-(249, 119); the edit (52, 129)-
--   (234, 141) in 0x80. The hired merchant's quantity (5.33 has none) keeps Modern's window.
-- Every window but the text menu draws DialogPane's Enter frames round OK (X.Default). Drawing only: the controls, their
-- indexes, the keys and the 39 and 43 replies are the renderer's and the model's, the same in every look.

local S = require("interfaces.5x.skin")

return function(L, X)
    local P = "NPAL8.PAL"

    --- OK, TOP and QUIT along y (left x, then 77 apart), 72 x 16.
    local function buttons(win, x, y)
        X.Image(win, win.ok, 14, x, y, x + 72, y + 16)
        X.Image(win, win.up, 16, x + 77, y, x + 149, y + 16)
        X.Image(win, win.close, 15, x + 154, y, x + 226, y + 16)
    end

    --- The menus on DLGMERC1: the picture, the buttons, the portrait, the prompt and the list (rows high).
    local function merc1(win, rows)
        X.Art(win, "DLGMERC1.EPF", P)
        buttons(win, 44, 306)
        X.Portrait(win, 35, 37, 72, 92)
        X.Text(win.prompt, win, 122, 37, 266, 133)
        X.List(win, win.list, 36, 141, 278, 285, 228, rows)
    end

    --- The menus on DLGMERC3: the picture, the buttons, the portrait, the prompt and the list; the description line.
    local function merc3(win)
        X.Art(win, "DLGMERC3.EPF", P)
        buttons(win, 104, 281)
        X.Portrait(win, 35, 37, 72, 92)
        X.Text(win.prompt, win, 83, 30, 383, 130)
        X.List(win, win.list, 36, 140, 398, 260, 348, 24)
        X.RowColours(win.list)
        if win.description then
            X.Text(win.description, win, 50, 310, 384, 322)
            win.description:SetWordWrap(false)
            win.description:Show()
        end
    end

    --- A text right-aligned to end at x of the row, in font 0's advances.
    local function rightText(row, key, x, text)
        X.RowText(row, key, x - (S.TextWidth(text) or 0)):SetText(text)
    end

    -- The text menu draws no Enter frames (TextMenuDialog__OnPaint 0x0046EDA0 replaces DialogPane's paint); its 12-pixel
    -- rows draw the text whole, clipped at the list's edge (TextMenuItemList__DrawListEntry 0x0046F690).
    L.TextMenu = {
        width = 314, height = 356, button = 72, listWidth = 228, listHeight = 144,
        place = function(win)
            merc1(win, 12)
            local style = win.list.styleRow
            win.list.styleRow = function(row)
                style(row)
                row.text:SetWordWrap(false)
            end
        end,
        fit = function(win)
            X.Size(win, 314, 356)
            X.Default(win, win.ok, win.className ~= "TextMenuDialog")
        end,
    }

    L.SellMenu = {
        width = 314, height = 356, button = 72, listWidth = 228, listHeight = 144,
        place = function(win)
            merc1(win, 24)
            X.RowColours(win.list)
        end,
        fit = function(win)
            X.Size(win, 314, 356)
            X.Default(win, win.ok)
        end,
        row = function(win, row, it) X.ItemRow(win.list, row, it, 12, 50, 178) end,
    }

    L.ItemMenu = {
        width = 434, height = 371, button = 72, listWidth = 348, listHeight = 120,
        place = merc3,
        fit = function(win)
            X.Size(win, 434, 371)
            X.Default(win, win.ok)
        end,
        row = function(win, row, it)
            X.ItemRow(win.list, row, it, 12, 50, 220)
            -- "%10u" left-aligned from the cell's right - 62 (0x004708F0): the digits after the spaces that pad them to
            -- ten characters, by font 0's advances
            local digits = string.format("%d", it.price or 0)
            local pad = (S.TextWidth(string.format("%10s", digits)) or 0) - (S.TextWidth(digits) or 0)
            X.RowText(row, "x7price", 348 - 62 + pad):SetText(digits)
            if row.x7count then row.x7count:Hide() end
        end,
    }

    -- The goods on the server items' window (the decision): the name in 50-200, the count ending at 270, the price
    -- grouped by commas ("1gold " before it for more than one, as 7.5.2's) ending at the price box's right, 346.
    L.GoodsMenu = {
        width = 434, height = 371, button = 72, listWidth = 348, listHeight = 120,
        place = merc3,
        fit = function(win)
            X.Size(win, 434, 371)
            X.Default(win, win.ok)
        end,
        row = function(win, row, it)
            X.ItemRow(win.list, row, it, 12, 50, 150)
            rightText(row, "x7count", 270, tostring(it.count or 0))
            local price = TK.Util.FormatNumber(it.price or 0)
            rightText(row, "x7price", 346, (it.count or 0) > 1 and ("1gold " .. price) or price)
        end,
    }

    L.MerchantInput = {
        width = 314, height = 197, button = 72, editWidth = 201, editHeight = 12,
        place = function(win)
            X.Art(win, "DLGMERC2.EPF", P)
            buttons(win, 44, 147)
            X.Portrait(win, 35, 37, 72, 92)
            X.Text(win.prompt, win, 82, 35, 262, 83)
            X.Edit(win.edit, win, 56, 113, 257, 125)
        end,
        fit = function(win)
            X.Size(win, 314, 197)
            X.Default(win, win.ok)
        end,
    }

    -- The windows on DLGEXC3, by class: the first button's picture (the trade's count ADD, else OK).
    L.Input = {
        width = 287, height = 277, button = 72, editWidth = 182, editHeight = 12,
        default = { EmployeeQuantityInputDialogPane = true },
        place = function(win)
            if not win.x5 then return X.Fallback.Input.place(win) end -- the hired merchant's quantity: the default window
            X.Art(win, "DLGEXC3.EPF", P)
            X.Image(win, win.cancel, 22, 146, 225, 218, 241)
            X.Edit(win.edit, win, 52, 129, 234, 141)
        end,
        fit = function(win)
            if not win.x5 then return X.Fallback.Input.fit(win) end
            X.Image(win, win.ok, win.className == "AddItemWithCountDialog" and 36 or 14, 69, 225, 141, 241)
            X.Text(win.text, win, 37, 36, 249, 119)
            -- the mix's quantity shows the prompt alone (NumberInputDialog: the string, no item, no range), as 7.x's
            if win.className == "NumberInputDialog" and win.view then
                win.text:SetText(TK.GetComponent("dialogs").kit.String(win.view.contents.stringId, ""))
            end
            local opened = win.opened
            X.Size(win, 287, 277)
            X.Default(win, win.ok)
            if opened then X.SlideOpen(win) end
        end,
    }
end
