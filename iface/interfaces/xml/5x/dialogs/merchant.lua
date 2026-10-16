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
--
-- s6-ui-core (round 85): the XML twin's; the windows' sizes, pictures and the parts' places are merchant.xml's
-- (core/xml.md).

local S = require("interfaces.5x.skin")
local unpack = table.unpack
local entry = require("interfaces.xml.entry")
local D = TK.Xml.Data("merchant.xml")

return function(L, X)
    local P = "NPAL8.PAL"
    local B, M1, M3 = D.BUTTONS, D.MERC1, D.MERC3

    --- OK, TOP and QUIT along y (left x, then BUTTONS' step apart), BUTTONS' size.
    local function buttons(win, x, y)
        local w, h, step, image = B.width, B.height, B.step, B.images
        X.Image(win, win.ok, image[1], x, y, x + w, y + h)
        X.Image(win, win.up, image[2], x + step, y, x + step + w, y + h)
        X.Image(win, win.close, image[3], x + 2 * step, y, x + 2 * step + w, y + h)
    end

    --- The menus on DLGMERC1: the picture, the buttons, the portrait, the prompt and the list (rows high).
    local function merc1(win, rows)
        X.Art(win, M1.file, P)
        buttons(win, unpack(M1.buttons))
        X.Portrait(win, unpack(M1.portrait))
        X.Text(win.prompt, win, unpack(M1.prompt))
        local l, t, r, b, cell = unpack(M1.list)
        X.List(win, win.list, l, t, r, b, cell, rows)
    end

    --- The menus on DLGMERC3: the picture, the buttons, the portrait, the prompt and the list; the description line.
    local function merc3(win)
        X.Art(win, M3.file, P)
        buttons(win, unpack(M3.buttons))
        X.Portrait(win, unpack(M3.portrait))
        X.Text(win.prompt, win, unpack(M3.prompt))
        X.List(win, win.list, unpack(M3.list))
        X.RowColours(win.list)
        if win.description then
            X.Text(win.description, win, unpack(M3.description))
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
    local TM = D.TextMenu
    L.TextMenu = entry(TM, {
        place = function(win)
            merc1(win, TM.list.rows)
            local style = win.list.styleRow
            win.list.styleRow = function(row)
                style(row)
                row.text:SetWordWrap(false)
            end
        end,
        fit = function(win)
            X.Size(win, M1.width, M1.height)
            X.Default(win, win.ok, win.className ~= "TextMenuDialog")
        end,
    })

    local SM = D.SellMenu
    L.SellMenu = entry(SM, {
        place = function(win)
            merc1(win, SM.list.rows)
            X.RowColours(win.list)
        end,
        fit = function(win)
            X.Size(win, M1.width, M1.height)
            X.Default(win, win.ok)
        end,
        row = function(win, row, it) X.ItemRow(win.list, row, it, unpack(SM.row)) end,
    })

    local IM = D.ItemMenu
    L.ItemMenu = entry(IM, {
        place = merc3,
        fit = function(win)
            X.Size(win, M3.width, M3.height)
            X.Default(win, win.ok)
        end,
        row = function(win, row, it)
            X.ItemRow(win.list, row, it, unpack(IM.row))
            -- "%10u" left-aligned from the cell's right - 62 (0x004708F0): the digits after the spaces that pad them to
            -- ten characters, by font 0's advances
            local digits = string.format("%d", it.price or 0)
            local pad = (S.TextWidth(string.format("%10s", digits)) or 0) - (S.TextWidth(digits) or 0)
            X.RowText(row, "x7price", IM.price[1] - IM.price[2] + pad):SetText(digits)
            if row.x7count then row.x7count:Hide() end
        end,
    })

    -- The goods on the server items' window (the decision): the name, the count ending at its end, the price grouped by
    -- commas ("1gold " before it for more than one, as 7.5.2's) ending at the price box's right.
    local GM = D.GoodsMenu
    L.GoodsMenu = entry(GM, {
        place = merc3,
        fit = function(win)
            X.Size(win, M3.width, M3.height)
            X.Default(win, win.ok)
        end,
        row = function(win, row, it)
            X.ItemRow(win.list, row, it, unpack(GM.row))
            rightText(row, "x7count", GM.ends.count, tostring(it.count or 0))
            local price = TK.Util.FormatNumber(it.price or 0)
            rightText(row, "x7price", GM.ends.price, (it.count or 0) > 1 and ("1gold " .. price) or price)
        end,
    })

    local MI = D.MerchantInput
    L.MerchantInput = entry(MI, {
        place = function(win)
            X.Art(win, unpack(MI.art))
            buttons(win, unpack(MI.buttons))
            X.Portrait(win, unpack(MI.portrait))
            X.Text(win.prompt, win, unpack(MI.prompt))
            X.Edit(win.edit, win, unpack(MI.edit))
        end,
        fit = function(win)
            X.Size(win, MI.width, MI.height)
            X.Default(win, win.ok)
        end,
    })

    -- The windows on DLGEXC3, by class: the first button's picture (the trade's count ADD, else OK).
    local IN = D.Input
    L.Input = entry(IN, {
        default = { EmployeeQuantityInputDialogPane = true },
        place = function(win)
            if not win.x5 then return X.Fallback.Input.place(win) end -- the hired merchant's quantity: the default window
            X.Art(win, unpack(IN.art))
            X.Image(win, win.cancel, unpack(IN.cancel))
            X.Edit(win.edit, win, unpack(IN.edit))
        end,
        fit = function(win)
            if not win.x5 then return X.Fallback.Input.fit(win) end
            X.Image(win, win.ok, win.className == "AddItemWithCountDialog" and IN.images.count or IN.images.ok, unpack(IN.first))
            X.Text(win.text, win, unpack(IN.text))
            -- the mix's quantity shows the prompt alone (NumberInputDialog: the string, no item, no range), as 7.x's
            if win.className == "NumberInputDialog" and win.view then
                win.text:SetText(TK.GetComponent("dialogs").kit.String(win.view.contents.stringId, ""))
            end
            local opened = win.opened
            X.Size(win, IN.width, IN.height)
            X.Default(win, win.ok)
            if opened then X.SlideOpen(win) end
        end,
    })
end
