-- s6-modular-g (interfaces, round 13): 7.x's look of the fitting room (components/dialogs/fitting.lua), from Source-5's
-- class pages. Drawing only: the indexes, the cells' parts and what is sent are the renderer's and the model's.
--
-- FittingRoomDialog (0x0041BDD0): 820 x 500, centred, no slide; the web board's frame (its OnPaint 0x0041C5E0); controls
-- by GetControlBounds (0x0041D150): OK (0, image 14) (379, 468); the preview (1) 192 x 192 at (18, 50), on black; "<"
-- (3, image 44) (18, 248) and ">" (4, image 45) (149, 250); "Basic" (5) (18, 276) and "Current" (6) (120, 276), 92 x 30;
-- the ten categories (7-16) 86 x 22 at (280 + 90 (n % 5), 50 + 26 (n / 5)), n the index - 7; Basic, Current and the
-- categories 4a's flat text buttons (FittingRoomTextButtonControlPane::OnPaint 0x00424080: 0xD4, bevels 0xD0 and 0xD8,
-- sunken while chosen); the item grid (2) at (218, 92), 586 x 362 (FittingRoomListPane::OnPaint 0x0041F2B0): six
-- columns of three rows, a cell's 54 x 54 press area at (16 + 96 c, 31 + 112 r), its 50 x 50 box a pixel in (filled in
-- 0x8A for an item tried on) with the item's picture in it, its name in 0x8F centred under it on lines from 66, 16 apart.

local S = require("interfaces.7x.skin")

return function(L, X)
    --- The chosen category's sunken bevels over its button (two nested one-pixel frames, dark top and left, lit bottom
    --- and right), a frame the renderer shows (b.mark).
    local function sunken(b)
        local mark = CreateFrame("Frame", nil, b)
        mark:SetAllPoints(b)
        mark:SetFrameLevel(b:GetFrameLevel() + 1)
        for k = 0, 1 do
            for _, side in ipairs({ "top", "left", "bottom", "right" }) do
                local dark = side == "top" or side == "left"
                X.Line(mark, X.Solid(mark, "OVERLAY", dark and 0xD8 or 0xD0), side, k)
            end
        end
        mark:Hide()
        return mark
    end

    --- A name in lines as 4a's grid breaks it (FittingRoomListPane::OnPaint): at spaces, a word going on a new line when the
    --- line's length and the word's together reach 14 characters.
    local function wrap(text)
        local lines, line = {}, ""
        for word in text:gmatch("%S+") do
            if line ~= "" and #line + #word >= 14 then
                lines[#lines + 1] = line
                line = word
            else
                line = line == "" and word or (line .. " " .. word)
            end
        end
        if line ~= "" then lines[#lines + 1] = line end
        return table.concat(lines, "\n")
    end

    L.Room = {
        width = 820, height = 500, button = 63, turn = 63, category = 86, categoryHeight = 22, icon = 50, previewSize = 192,
        --- The preview: 192 x 192 at (18, 50) on black (FittingRoomUserImageControlPane fills colour 0 in its opaque pane),
        --- the figure in its middle.
        preview = function(win)
            local preview = CreateFrame("Frame", nil, win)
            X.Rect(preview, win, 18, 50, 210, 242)
            local bg = preview:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(preview)
            bg:SetColorTexture(0, 0, 0, 1)
            preview.figure = preview:CreateTexture(nil, "ARTWORK")
            preview.figure:SetPoint("CENTER", preview, "CENTER", 0, 0)
            return preview
        end,
        --- Cell i (cols across) of the grid: its 54 x 54 press area, its tried-on fill (cell.on) and its picture (cell.icon)
        --- in the 50 x 50 box a pixel in, its name under it.
        cell = function(grid, i, cols)
            local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
            local cell = CreateFrame("Button", nil, grid)
            X.Rect(cell, grid, 16 + 96 * c, 31 + 112 * r, 70 + 96 * c, 85 + 112 * r)
            cell.on = cell:CreateTexture(nil, "BORDER")
            cell.on:SetPoint("TOPLEFT", cell, "TOPLEFT", 1, 0)
            cell.on:SetSize(50, 50)
            S.Fill(cell.on, 0x8A)
            cell.icon = cell:CreateTexture(nil, "ARTWORK")
            cell.icon:SetPoint("CENTER", cell, "TOPLEFT", 26, -25)
            cell.name = cell:CreateFontString(nil, "OVERLAY")
            S.Text(cell.name, 0x8F)
            cell.name:SetSpacing(2) -- 16-pixel lines
            cell.name:SetWordWrap(false)
            cell.name:SetJustifyH("CENTER")
            cell.name:SetWidth(96)
            cell.name:SetPoint("TOP", cell, "TOPLEFT", 26, -(66 - 11))
            local set = cell.name.SetText
            function cell.name:SetText(text) set(self, wrap(text or "")) end
            return cell
        end,
        --- An item's picture (FittingRoomListPane::OnPaint, FittingRoomScrollPane.cpp:806-826): above 50 pixels at half
        --- size, else at its size, either way centred in the 50 x 50 box, its left (50 - w) / 2 in and its top
        --- (50 - h) / 2 down (DrawItemImageUnscaled's halves; DrawItemImageIn43x43Slot centres the glyph's bounds in the
        --- box too, and cuts only a glyph wider or taller than the box, which goes the half-size way here).
        --- (s6-interface-7x round 2: it was at the box's corner, 4 pixels up and left of 4a's.)
        placeIcon = function(cell, key, w, h)
            local icon = cell.icon
            icon:SetTexture(key)
            icon:ClearAllPoints()
            if w > 50 or h > 50 then w, h = math.floor(w / 2), math.floor(h / 2) end
            icon:SetSize(math.max(1, w), math.max(1, h))
            icon:SetTexCoord(0, 1, 0, 1)
            icon:SetPoint("TOPLEFT", cell, "TOPLEFT", 1 + math.floor((50 - w) / 2), -math.floor((50 - h) / 2))
        end,
        place = function(win, cols, rows)
            X.WebFrame(win, 820, 500)
            X.Image(win, win.controls[0], 14, 379, 468, 442, 492)
            X.Image(win, win.controls[3], 44, 18, 248, 81, 272)
            X.Image(win, win.controls[4], 45, 149, 250, 212, 274)
            X.TextButton(win, win.controls[5], 18, 276, 110, 306, 0xD4, 0xD0, 0xD8)
            X.TextButton(win, win.controls[6], 120, 276, 212, 306, 0xD4, 0xD0, 0xD8)
            for i, b in ipairs(win.categories) do
                local n = i - 1
                local x, y = 280 + 90 * (n % 5), 50 + 26 * math.floor(n / 5)
                X.TextButton(win, b, x, y, x + 86, y + 22, 0xD4, 0xD0, 0xD8)
                b.mark = sunken(b)
            end
            X.Rect(win.grid, win, 218, 92, 804, 454)
            X.Text(win.empty, win.grid, 0, 175, 586, 187)
            win.empty:SetJustifyH("CENTER")
        end,
    }
end
