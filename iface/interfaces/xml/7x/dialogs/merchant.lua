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
-- s6-ui-core (round 85): the XML twin's; the windows' sizes, pictures and the parts' places are merchant.xml's
-- (core/xml.md).

local S = require("interfaces.7x.skin")
local unpack = table.unpack
local entry = require("interfaces.xml.entry")
local D = TK.Xml.Data("merchant.xml")

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

    --- The menus on DLGMERC1 or DLGMERC3 (merchant.xml's MERC1, MERC3): the window, its buttons, the portrait, the prompt
    --- and (MERC3's) the description line.
    local function merc(win, m)
        X.Portrait(win, unpack(m.portrait))
        X.Art(win, unpack(m.art))
        X.Image(win, win.ok, unpack(m.ok))
        X.Image(win, win.up, unpack(m.up))
        X.Image(win, win.close, unpack(m.close))
        X.Text(win.prompt, win, unpack(m.prompt))
        if m.description and win.description then
            X.Text(win.description, win, unpack(m.description))
            win.description:SetWordWrap(false)
            win.description:Show()
        end
    end

    local T = D.TextMenu
    L.TextMenu = entry(T, {
        place = function(win)
            merc(win, D.MERC1)
            X.List(win, win.list, unpack(T.list))
        end,
        fit = function(win) X.Size(win, T.width, T.height) end,
    })

    -- The sell menu (ClientItemMenuItemList: 228 x 24 cells, the name to the cell's right).
    local SM = D.SellMenu
    L.SellMenu = entry(SM, {
        place = function(win)
            merc(win, D.MERC1)
            X.List(win, win.list, unpack(SM.list))
            paint(win.list, SM.cut)
        end,
        fit = function(win) X.Size(win, SM.width, SM.height) end,
        row = function(win, row, it)
            X.ItemRow(win.list, row, it, SM.row.icon, SM.row.name, SM.row.width)
        end,
    })

    -- The server's items (ServerItemMenuItemList: 348 x 24 cells; the price "%10u" in the cell's right - 90 to - 30).
    local IM = D.ItemMenu
    L.ItemMenu = entry(IM, {
        place = function(win)
            merc(win, D.MERC3)
            X.List(win, win.list, unpack(IM.list))
            paint(win.list, IM.cut)
        end,
        fit = function(win) X.Size(win, IM.width, IM.height) end,
        row = function(win, row, it)
            local r = IM.row
            X.ItemRow(win.list, row, it, r.icon, r.name, r.width)
            -- "%10u" from the cell's right - 90: the digits after the spaces that pad them to ten characters, by font 0's
            -- advances (the spaces drawn as 4a measures them)
            local digits = string.format("%d", it.price or 0)
            local pad = (S.TextWidth(string.format("%10s", digits)) or 0) - (S.TextWidth(digits) or 0)
            X.RowText(row, "x7price", r.price + pad):SetText(digits)
            if row.x7count then row.x7count:Hide() end
        end,
    })

    -- The goods (ArgumentedMenuMenuItemList: 362 x 24 cells; the name in 30-186, the count ending at 217, the price
    -- grouped by commas from the cell's right - 25 back 6 pixels a character and two more, 36 more with "1gold ").
    local GM = D.GoodsMenu
    L.GoodsMenu = entry(GM, {
        place = function(win)
            merc(win, D.MERC3)
            X.List(win, win.list, unpack(GM.list))
            paint(win.list, GM.cut)
        end,
        fit = function(win) X.Size(win, GM.width, GM.height) end,
        row = function(win, row, it)
            local r = GM.row
            X.ItemRow(win.list, row, it, r.icon, r.name, r.width)
            local count = tostring(it.count or 0)
            X.RowText(row, "x7count", r.count - 6 * #count):SetText(count)
            local grouped = TK.Util.FormatNumber(it.price or 0)
            local x = r.price - 6 * (#grouped + 2)
            local text = grouped
            if (it.count or 0) > 1 then
                text = "1gold " .. grouped
                x = x - r.gold
            end
            X.RowText(row, "x7price", x):SetText(text)
        end,
    })

    local MI = D.MerchantInput
    L.MerchantInput = entry(MI, {
        place = function(win)
            X.Portrait(win, unpack(MI.portrait))
            X.Art(win, unpack(MI.art))
            X.Image(win, win.ok, unpack(MI.ok))
            X.Image(win, win.up, unpack(MI.up))
            X.Image(win, win.close, unpack(MI.close))
            X.Text(win.prompt, win, unpack(MI.prompt))
            X.Edit(win.edit, win, unpack(MI.edit))
        end,
        fit = function(win) X.Size(win, MI.width, MI.height) end,
    })

    -- The windows on DLGEXC3 by class (merchant.xml's kinds): the first button's picture, the text's rectangle and the
    -- edit's colour.
    local I = D.Input
    L.Input = entry(I, {
        place = function(win)
            X.Art(win, unpack(I.art))
            X.Image(win, win.cancel, unpack(I.cancel))
        end,
        fit = function(win)
            local kind = I.kinds[win.className] or I.kinds.ArgumentedItemConfirmInputDialogPane
            X.Image(win, win.ok, kind.image, unpack(I.ok))
            local e = I.edit
            X.Edit(win.edit, win, e[1], e[2], e[3], e[4], kind.edit)
            X.Text(win.text, win, unpack(kind.text))
            -- the stack's number shows 4a's prompt alone (NumberInputDialog: string 218, no item, no range: round 13's
            -- capture against the original); the renderer's text adds them for Modern's
            if win.className == "NumberInputDialog" and win.view then
                win.text:SetText(TK.Dialogs.String(win.view.contents.stringId, ""))
            end
            win.text:SetJustifyH("LEFT")
            local opened = win.opened
            X.Size(win, I.width, I.height)
            if opened then X.SlideOpen(win) end
        end,
    })
end
