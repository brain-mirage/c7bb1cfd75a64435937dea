-- s6-modular-g (interfaces, phase 4): 7.x's look of the merchant menus (components/dialogs/merchant.lua), from
-- Source-5's class pages (each class's EPF layout, which this build always takes). Drawing only: the indexes, the keys
-- and the 39 replies are the renderer's and the model's.
--
-- The text menu and the two spell menus (TextMenuDialog 0x00519210, ServerSpellMenuDialog, ClientSpellMenuDialog: the
-- same window), and the sell menu (ClientItemMenuDialog 0x0051B880): 315 x 353 on DLGMERC1.EPF in PAL01.PAL; OK (image
-- 14), UP (16) and CLOSE (15) along y 310-334; the NPC's portrait at (20, 20); the prompt (105, 40)-(276, 128); the list
-- (36, 144)-(294, 288) of 228-pixel cells, 12 high (24 for the sell menu's items). The text input (TextInputMenuDialog
-- 0x0051A280): 336 x 205 on DLGMERC2.EPF in PAL01.PAL; OK, UP, CLOSE along y 169-193; the portrait at (22, 8); the
-- prompt (105, 28)-(301, 112); the edit (44, 128)-(291, 140).
--
-- The item menus (ServerItemMenuDialog 0x0051A520, ArgumentedMenuMenuDialog 0x0051E9A0): 410 x 368 on DLGMERC3.EPF in
-- PAL01.PAL; OK, UP, CLOSE along y 332-356; the portrait at (26, 13); the prompt (109, 33)-(373, 121); the list
-- (36, 129)-(391, 273) of 348 x 24 cells (the goods: (26, 129)-(391, 273), 362 x 24); the selected item's description
-- (25, 291)-(363, 303). Their rows (ServerItemMenuItemList::DrawListEntry 0x0051B3E0, ClientItemMenuItemList's,
-- ArgumentedMenuMenuItemList's): the item's picture at half size centred on x 12 and on the row's middle, the name from
-- x 50 (the goods' from 30) on a 12-pixel band at the middle, shortened with "..." to fit, the price ("%10u" from the
-- cell's right - 90; the goods': the count right of 211, the price grouped by commas, "1gold " before it for a stack),
-- the selected row on a 0x25 bar (the cell less its right 28 pixels; the sell menu's the whole cell).
--
-- The windows on DLGEXC3 (the purchase's inputs, ArgumentedItemConfirmInputDialogPane 0x005200D0 and
-- ArgumentedItemQuantityInputDialogPane 0x0051FC90, the hired merchant's quantity EmployeeQuantityInputDialogPane
-- 0x004A4770, and, through the same renderer, the trade's count AddItemWithCountDialog 0x004AF040 and the stack's number
-- NumberInputDialog 0x00530640): 239 x 283, DLGEXC3.EPF in PAL01.PAL (the picture 238 x 183, nothing below it: pane mode
-- 1); OK (14, the count's ADD 36) (50, 149)-(113, 173) and CANCEL (22) (129, 149)-(192, 173); the text (30, 45)-(210, 81)
-- (the quantities' (30, 60)-(197, 72), the count's and the number's (28, 35)-(211, 107)); the edit (28, 111)-(211, 123) in
-- colour 0x8F (the count's and the number's 0x80); their placement slots (19, 9, 16: centred, as every slot but 13); they
-- slide open.

local S = require("interfaces.7x.skin")

return function(L, X)
    --- The colour of a row's own texts by its selection (0x80 on the bar, 0x25 off it); the bar cut pixels short of the
    --- cell's right (the server's items' and the goods' 28: their DrawListEntry's highlight.right -= 28).
    local function paint(list, cut)
        list.cellCut = cut
        list.rowPainter = function(row, selected)
            local c = selected and S.TEXT or S.LIST
            for _, key in ipairs({ "itemName", "x7price", "x7count" }) do
                if row[key] then row[key]:SetTextColor(S.Colour(c)) end
            end
        end
    end

    --- The menus on DLGMERC1: the window, its buttons, the portrait and the prompt.
    local function merc1(win)
        X.Portrait(win, 20, 20)
        X.Art(win, "DLGMERC1.EPF", "PAL01.PAL")
        X.Image(win, win.ok, 14, 44, 310, 107, 334)
        X.Image(win, win.up, 16, 121, 310, 184, 334)
        X.Image(win, win.close, 15, 198, 310, 261, 334)
        X.Text(win.prompt, win, 105, 40, 276, 128)
    end

    --- The menus on DLGMERC3: the window, its buttons, the portrait, the prompt and the description line.
    local function merc3(win)
        X.Portrait(win, 26, 13)
        X.Art(win, "DLGMERC3.EPF", "PAL01.PAL")
        X.Image(win, win.ok, 14, 104, 332, 167, 356)
        X.Image(win, win.up, 16, 181, 332, 244, 356)
        X.Image(win, win.close, 15, 258, 332, 321, 356)
        X.Text(win.prompt, win, 109, 33, 373, 121)
        if win.description then
            X.Text(win.description, win, 25, 291, 363, 303)
            win.description:SetWordWrap(false)
            win.description:Show()
        end
    end

    L.TextMenu = {
        width = 315, height = 353, button = 63, listWidth = 228, listHeight = 144,
        place = function(win)
            merc1(win)
            X.List(win, win.list, 36, 144, 294, 288, 228)
        end,
        fit = function(win) X.Size(win, 315, 353) end,
    }

    -- The sell menu (ClientItemMenuItemList: 228 x 24 cells, the name to the cell's right).
    L.SellMenu = {
        width = 315, height = 353, button = 63, listWidth = 228, listHeight = 144,
        place = function(win)
            merc1(win)
            X.List(win, win.list, 36, 144, 294, 288, 228, 24)
            paint(win.list, 0)
        end,
        fit = function(win) X.Size(win, 315, 353) end,
        row = function(win, row, it)
            X.ItemRow(win.list, row, it, 12, 50, 228 - 50)
        end,
    }

    -- The server's items (ServerItemMenuItemList: 348 x 24 cells; the price "%10u" in the cell's right - 90 to - 30).
    L.ItemMenu = {
        width = 410, height = 368, button = 63, listWidth = 348, listHeight = 144,
        place = function(win)
            merc3(win)
            X.List(win, win.list, 36, 129, 391, 273, 348, 24)
            paint(win.list, 28)
        end,
        fit = function(win) X.Size(win, 410, 368) end,
        row = function(win, row, it)
            X.ItemRow(win.list, row, it, 12, 50, 220)
            -- "%10u" from the cell's right - 90: the digits after the spaces that pad them to ten characters, by font 0's
            -- advances (the spaces drawn as 4a measures them)
            local digits = string.format("%d", it.price or 0)
            local pad = (S.TextWidth(string.format("%10s", digits)) or 0) - (S.TextWidth(digits) or 0)
            X.RowText(row, "x7price", 348 - 90 + pad):SetText(digits)
            if row.x7count then row.x7count:Hide() end
        end,
    }

    -- The goods (ArgumentedMenuMenuItemList: 362 x 24 cells; the name in 30-186, the count ending at 217, the price
    -- grouped by commas from the cell's right - 25 back 6 pixels a character and two more, 36 more with "1gold ").
    L.GoodsMenu = {
        width = 410, height = 368, button = 63, listWidth = 362, listHeight = 144,
        place = function(win)
            merc3(win)
            X.List(win, win.list, 26, 129, 391, 273, 362, 24)
            paint(win.list, 28)
        end,
        fit = function(win) X.Size(win, 410, 368) end,
        row = function(win, row, it)
            X.ItemRow(win.list, row, it, 12, 30, 156)
            local count = tostring(it.count or 0)
            X.RowText(row, "x7count", 211 - 6 * #count):SetText(count)
            local grouped = TK.Util.FormatNumber(it.price or 0)
            local x = 362 - 25 - 6 * (#grouped + 2)
            local text = grouped
            if (it.count or 0) > 1 then
                text = "1gold " .. grouped
                x = x - 36
            end
            X.RowText(row, "x7price", x):SetText(text)
        end,
    }

    L.MerchantInput = {
        width = 336, height = 205, button = 63, editWidth = 247, editHeight = 12,
        place = function(win)
            X.Portrait(win, 22, 8)
            X.Art(win, "DLGMERC2.EPF", "PAL01.PAL")
            X.Image(win, win.ok, 14, 60, 169, 123, 193)
            X.Image(win, win.up, 16, 137, 169, 200, 193)
            X.Image(win, win.close, 15, 214, 169, 277, 193)
            X.Text(win.prompt, win, 105, 28, 301, 112)
            X.Edit(win.edit, win, 44, 128, 291, 140)
        end,
        fit = function(win) X.Size(win, 336, 205) end,
    }

    -- The windows on DLGEXC3 by class: the first button's picture, the text's rectangle and the edit's colour (the
    -- purchase's inputs: OK, 0x8F; the trade's count: ADD; the stack's number: OK). s6-interface-7x-b (round 5): the hired
    -- merchant's quantity is the purchase quantity's layout in 4a (its constructor, ui/EmployeeDialogPane.cpp:871-901,
    -- builds the same controls at the same places, only its name differs), drawn so here too in place of Modern's window.
    local EXC3 = {
        ArgumentedItemConfirmInputDialogPane = { image = 14, text = { 30, 45, 210, 81 }, edit = 0x8F },
        ArgumentedItemQuantityInputDialogPane = { image = 14, text = { 30, 60, 197, 72 }, edit = 0x8F },
        EmployeeQuantityInputDialogPane = { image = 14, text = { 30, 60, 197, 72 }, edit = 0x8F },
        AddItemWithCountDialog = { image = 36, text = { 28, 35, 211, 107 }, edit = S.TEXT },
        NumberInputDialog = { image = 14, text = { 28, 35, 211, 107 }, edit = S.TEXT },
    }

    L.Input = {
        width = 239, height = 283, button = 63, editWidth = 183, editHeight = 12,
        place = function(win)
            X.Art(win, "DLGEXC3.EPF", "PAL01.PAL")
            X.Image(win, win.cancel, 22, 129, 149, 192, 173)
        end,
        fit = function(win)
            local kind = EXC3[win.className] or EXC3.ArgumentedItemConfirmInputDialogPane
            X.Image(win, win.ok, kind.image, 50, 149, 113, 173)
            X.Edit(win.edit, win, 28, 111, 211, 123, kind.edit)
            X.Text(win.text, win, kind.text[1], kind.text[2], kind.text[3], kind.text[4])
            -- the stack's number shows 4a's prompt alone (NumberInputDialog: string 218, no item, no range: round 13's
            -- capture against the original); the renderer's text adds them for Modern's
            if win.className == "NumberInputDialog" and win.view then
                win.text:SetText(TK.Dialogs.String(win.view.contents.stringId, ""))
            end
            win.text:SetJustifyH("LEFT")
            local opened = win.opened
            X.Size(win, 239, 283)
            if opened then X.SlideOpen(win) end
        end,
    }
end
