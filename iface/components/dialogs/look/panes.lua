-- s6-modular-g (interfaces): the default look of the panes and the targeting options (components/dialogs/panes.lua).

return function(L, P, W) -- W: the skin the look is drawn with (init.lua's Build)

    -- D-71: the clock: 35-pixel cells for NUMBER.EPF's digits (4a's TimerPane), top centre as the original's (325, 15).
    L.Timer = {
        open = function(win) win:SetPoint("TOP", UIParent, "TOP", 0, -15) end,
        place = function(win)
            win:SetSize(8 * 35, 70)
            for i, t in ipairs(win.cells) do t:SetPoint("TOPLEFT", win, "TOPLEFT", (i - 1) * 35, 0) end
            win.text:SetPoint("TOP", win, "TOP", 0, -8)
        end,
        -- As wide as the glyphs shown (n).
        fit = function(win, n) win:SetWidth(n * 35) end,
    }

    -- D-76: the parcel and letter buttons, 4a's ALERTBTN pictures' sizes (30 and 31 x 25) side by side, at the bottom left
    -- of the Mail and Parcels panel.
    L.Parcel = {
        open = function(win) win:SetPoint("BOTTOMLEFT", win:GetParent(), "BOTTOMLEFT", 0, 0) end,
        place = function(win) win:SetSize(62, 25) end,
        button = function(win, b, i)
            b:SetSize(i == 0 and 30 or 31, 25)
            b:SetPoint("TOPLEFT", win, "TOPLEFT", i * 31, 0)
        end,
    }

    --- A popup's panel, rows 18 high under top (from its top), 5 in from its sides.
    local function popup(width, rows, extra)
        local win = W.Panel(UIParent, nil)
        win:SetSize(width, rows * 18 + extra)
        return win
    end

    --- A popup's row i under top: its highlight under the pointer (r.hl: U-19's test reads it) and its caption centred.
    local function popupRow(win, r, i, top)
        r:SetHeight(18)
        r:SetPoint("TOPLEFT", win, "TOPLEFT", 5, top - (i - 1) * 18)
        r:SetPoint("TOPRIGHT", win, "TOPRIGHT", -5, top - (i - 1) * 18)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(r)
        hl:SetColorTexture(0.25, 0.4, 0.8, 0.5)
        r.hl = hl
        r.label:SetPoint("CENTER", r, "CENTER", 0, 0)
    end

    -- D-55: the Menu popup, 96 wide, at the bottom right corner (Modern's opens above its micro menu:
    -- interfaces/modern/dialogs/init.lua).
    L.MenuPopup = {
        open = function(win) win:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 60) end,
        panel = function(rows) return popup(96, rows, 10) end,
        row = function(win, r, i) popupRow(win, r, i, -5) end,
    }

    -- D-56: the player menu, 100 wide, the target's name over its rows. It opens at the press that opened it as the
    -- original's does (x - 50, y - 50: RightButtonMenuPane), the same in every look.
    L.PlayerMenu = {
        open = function(win)
            local x, y = __tk:GetPressPosition()
            local s = TK.UIScale()
            win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s - 50, y / s + 50)
        end,
        panel = function(rows) return popup(100, rows, 30) end,
        place = function(win) win.name:SetPoint("TOP", win, "TOP", 0, -6) end,
        row = function(win, r, i) popupRow(win, r, i, -24) end,
    }

    -- D-75: the transfer's animation, 144 square, 40 above the centre.
    L.Transfer = {
        open = function(win) win:SetPoint("CENTER", UIParent, "CENTER", 0, 40) end,
        place = function(win)
            win:SetSize(144, 144)
            win.tex:SetPoint("CENTER", win, "CENTER", 0, 0)
            win.text:SetPoint("CENTER", win, "CENTER", 0, 0)
        end,
    }

    -- D-60: the targeting options: each row's name with its USER and MONSTER switches, OK at the bottom.
    L.Target = {
        width = 338, height = 190, button = 90, switch = 104, buttonHeight = 24,
        place = function(win)
            for row = 1, 2 do
                local y = -40 - (row - 1) * 44
                P.At(W.Label(win, row == 1 and "ARROW" or "SHIFT+ARROW", 13, W.white, "LEFT"), win, 22, y - 6)
                for part = 0, 1 do P.At(win.switches[row][part], win, 118 + part * 108, y) end
            end
            P.Bottom(win.ok, win, 0, 14)
        end,
    }
end
