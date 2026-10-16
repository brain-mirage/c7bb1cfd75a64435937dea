-- s6-modular-g (interfaces): the default look of the chat colour dialog (components/dialogs/chatcolor.lua).

return function(L, P, W) -- W: the skin the look is drawn with (init.lua's Build)

    -- The six categories in two rows of three at the top, the text colours' grid and the outline colours' grid (16
    -- swatches across, 18 apart) each under its caption, OK and Cancel either side of the bottom's middle.
    L.ChatColor = {
        width = 330, height = 420, button = 80,
        --- A category's button: its background (b.bg, painted by the renderer) and its name.
        category = function(win, name)
            local b = CreateFrame("Button", nil, win)
            b:SetSize(96, 22)
            b.bg = b:CreateTexture(nil, "BACKGROUND")
            b.bg:SetAllPoints(b)
            b.label = W.Label(b, name, 13, W.white)
            b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
            return b
        end,
        --- A swatch, 17 square: its frame (s.edge) and its colour inside it (s.fill).
        swatch = function(win)
            local s = CreateFrame("Button", nil, win)
            s:SetSize(17, 17)
            s.edge = s:CreateTexture(nil, "BACKGROUND")
            s.edge:SetAllPoints(s)
            s.fill = s:CreateTexture(nil, "ARTWORK")
            s.fill:SetPoint("TOPLEFT", s, "TOPLEFT", 2, -2)
            s.fill:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -2, 2)
            return s
        end,
        place = function(win)
            for i, b in ipairs(win.categories) do
                P.At(b, win, 16 + (i - 1) % 3 * 100, -38 - math.floor((i - 1) / 3) * 26)
            end
            for _, g in ipairs({ { win.text, -114, "Text", -98 }, { win.outline, -230, "Outline", -214 } }) do
                P.At(W.Label(win, g[3], 12, W.gold, "LEFT"), win, 21, g[4])
                for i, s in ipairs(g[1]) do P.At(s, win, 21 + (i - 1) % 16 * 18, g[2] - math.floor((i - 1) / 16) * 18) end
            end
            win.ok:SetPoint("BOTTOMRIGHT", win, "BOTTOM", -6, 16)
            win.cancel:SetPoint("BOTTOMLEFT", win, "BOTTOM", 6, 16)
        end,
    }
end
