-- s6-modular-g (interfaces): the default look of the merchant menus (components/dialogs/merchant.lua).

return function(L, P)
    --- The menus' frame: the prompt across the top, CLOSE, UP and OK from the bottom right; no description line (the
    --- server's items: 7.x's).
    local function frame(win)
        P.Across(win.prompt, win, 20, 20, -36)
        P.Row(win, { win.close, win.up, win.ok }, 16, 14, 8)
        if win.description then win.description:Hide() end
    end

    --- The prompt right of the portrait (x: how far right the text starts; ph: its height), the widget under both (gap
    --- further for an edit); the prompt's height or the portrait's, whichever is more.
    local function belowPrompt(win, widget, x, ph, gap)
        P.Across(win.prompt, win, 20 + x, 20, -36, true)
        local th = math.max(win.prompt:GetStringHeight(), ph)
        widget:ClearAllPoints()
        P.At(widget, win, 26, -44 - th - (gap or 0))
        return th
    end

    -- D-09, D-11 to D-15: the list menus and the argumented buy menu: the list under the prompt, the window round both.
    L.MerchantList = {
        width = 460, height = 340, button = 80, listWidth = 400, listHeight = 190,
        place = frame,
        fit = function(win, x, ph) win:SetHeight(belowPrompt(win, win.list.sf, x, ph) + 190 + 100) end,
    }

    -- D-09 (TextMenuDialog) and the spell menus, D-11 (the server's items), D-12 (the player's), D-15 (the goods): the
    -- list menu's (look entries of their own for 7.x's windows).
    L.TextMenu = L.MerchantList
    L.ItemMenu = L.MerchantList
    L.SellMenu = L.MerchantList
    L.GoodsMenu = L.MerchantList

    -- D-10: the text input: the edit under the prompt.
    L.MerchantInput = {
        width = 440, height = 200, button = 80, editWidth = 380, editHeight = 24,
        place = frame,
        fit = function(win, x, ph) win:SetHeight(belowPrompt(win, win.edit, x, ph, 4) + 130) end,
    }

    -- D-16, D-17 (and the trade's counts, the hired merchant's quantity): a line of text, the edit under it, OK and
    -- CANCEL side by side at the bottom.
    L.Input = {
        width = 340, height = 160, button = 90, editWidth = 160, editHeight = 24,
        place = function(win)
            P.Across(win.text, win, 18, 18, -30)
            P.Bottom(win.cancel, win, 50, 14)
            P.Bottom(win.ok, win, -50, 14)
        end,
        -- The edit under the text, the window as tall as both.
        fit = function(win)
            win.edit:ClearAllPoints()
            win.edit:SetPoint("TOP", win.text, "BOTTOM", 0, -10)
            win:SetHeight(win.text:GetStringHeight() + 110)
        end,
    }
end
