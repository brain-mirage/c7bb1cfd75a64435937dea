-- s6-modular-g (interfaces): the default look of the fitting room (components/dialogs/fitting.lua).

return function(L, P)
    local K = TK.GetComponent("dialogs").kit
    local CELL_W, CELL_H = 88, 96

    -- D-34: the preview (192 square on black) at the left with its turn buttons and Basic and Current under it; the ten
    -- category buttons in two rows of five at the top right, the chosen one marked; the item grid under them (each cell
    -- its icon, 40 high, and its name), its "no catalogue" line in its middle; Close at the bottom right.
    L.Room = {
        width = 820, height = 500, button = 90, turn = 40, category = 106, categoryHeight = 22, icon = 40,
        previewSize = 192,
        --- The preview: a black square with the figure (preview.figure) in its middle.
        preview = function(win)
            local preview = CreateFrame("Frame", nil, win)
            preview:SetSize(192, 192)
            P.At(preview, win, 24, -60)
            local bg = preview:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(preview)
            bg:SetColorTexture(0, 0, 0, 1)
            preview.figure = preview:CreateTexture(nil, "ARTWORK")
            preview.figure:SetPoint("CENTER", preview, "CENTER", 0, 0)
            return preview
        end,
        --- Cell i of the grid (cols across): its background, its worn mark (cell.on), its icon and its name.
        cell = function(grid, i, cols)
            local cell = CreateFrame("Button", nil, grid)
            cell:SetSize(CELL_W - 4, CELL_H - 4)
            cell:SetPoint("TOPLEFT", grid, "TOPLEFT", (i - 1) % cols * CELL_W, -math.floor((i - 1) / cols) * CELL_H)
            local cbg = cell:CreateTexture(nil, "BACKGROUND")
            cbg:SetAllPoints(cell)
            cbg:SetColorTexture(0, 0, 0, 0.35)
            cell.on = cell:CreateTexture(nil, "BORDER")
            cell.on:SetAllPoints(cell)
            cell.on:SetColorTexture(1, 0.85, 0.3, 0.3)
            cell.icon = cell:CreateTexture(nil, "ARTWORK")
            cell.icon:SetPoint("TOP", cell, "TOP", 0, -6)
            cell.name = K.Block(cell, 10, "CENTER")
            cell.name:SetPoint("TOP", cell, "TOP", 0, -50)
            cell.name:SetWidth(CELL_W - 8)
            return cell
        end,
        place = function(win, cols, rows)
            win.left:SetPoint("TOPLEFT", win.preview, "BOTTOMLEFT", 0, -8)
            win.right:SetPoint("TOPRIGHT", win.preview, "BOTTOMRIGHT", 0, -8)
            win.basic:SetPoint("TOPLEFT", win.preview, "BOTTOMLEFT", 0, -40)
            win.current:SetPoint("TOPRIGHT", win.preview, "BOTTOMRIGHT", 0, -40)
            for i, b in ipairs(win.categories) do
                P.At(b, win, 236 + (i - 1) % 5 * 112, -40 - math.floor((i - 1) / 5) * 26)
                b.mark = b:CreateTexture(nil, "OVERLAY")
                b.mark:SetAllPoints(b)
                b.mark:SetColorTexture(1, 0.85, 0.3, 0.25)
            end
            win.grid:SetSize(cols * CELL_W, rows * CELL_H)
            P.At(win.grid, win, 236, -100)
            win.empty:SetPoint("CENTER", win.grid, "CENTER", 0, 0)
            win.close:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -18, 14)
        end,
    }
end
