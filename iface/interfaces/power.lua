-- s6-interface-5x-b (round 7, the head's review of round 6; the owner's "globally reusable interface items" at the
-- interfaces' root): the Power window's layout (components/dialogs/shops.lua's Power, D-30), shared by the dialogs looks
-- drawn from the original clients' art. 4a's PowerDialogPane (0x00549C20, one branch) and 5.33's (constructor 0x00490640,
-- paint 0x00490D30) are the same window to the pixel but for their seven buttons, so each look gives its buttons' size
-- and row and its skin (its text and colours), and its own drawing helpers (X: its art, image buttons, lists and edits);
-- the rest is here, once.
-- The window: 606 x 371 at (20, 20), sliding open; POWER.EPF frame 0 in BARAM.PAL, nothing round it (4a's OnPaint
-- 0x0054A6F0 blits it with no palette, so the current one; the packs have no POWER.PAL); REDO (0, image 43) at x 47, A-D
-- and COLOR (1-5, images 38-42) at x 120 + 73 k, CLOSE (6, image 30) at x 485; the four lists (7-10)
-- (61 + 110 i, 99)-(170 + 110 i, 219) of 96 x 12 rows (PowerListPane::DrawListEntry 0x0054B220: the level's swatch at (5, 1),
-- the name right-aligned in 0x25, the chosen row framed in 0x8F); the thresholds (11-14) at (36, 221 + 15 i)-(61, 235 + 15 i);
-- the grid's numbers "%d" in 0x8F from (62 + 110 c, 234 + 15 r) (the line).
-- Drawing only: the controls, their indexes, the lists' rows and what is sent are the renderer's and the model's.

local Power = {}

--- The Power entry of a look. X: its drawing helpers; S: its skin (Text, Colour, Fill, LIST); buttons: { width, height,
--- top }, the seven buttons' size and their row's top (7.5.2's 63 x 24 at 307, 5.33's 72 x 16 at 307).
function Power.Entry(X, S, buttons)
    local K = TK.GetComponent("dialogs").kit
    local bw, bh, top = buttons.width, buttons.height, buttons.top
    return {
        width = 606, height = 371, button = bw, listWidth = 96, listHeight = 120, thresholdWidth = 25, thresholdHeight = 14,
        slide = true,
        -- at (20, 20), where PowerDialogPane's AddToLayer puts it (no placement slot), unclamped
        centre = function(win) return 20 + 303, 20 + 185, false end,
        place = function(win)
            X.Art(win, "POWER.EPF", "BARAM.PAL")
            X.Image(win, win.controls[0], 43, 47, top, 47 + bw, top + bh)
            for k = 1, 5 do
                local x = 120 + 73 * (k - 1)
                X.Image(win, win.controls[k], 37 + k, x, top, x + bw, top + bh)
            end
            X.Image(win, win.controls[6], 30, 485, top, 485 + bw, top + bh)
            for k, list in ipairs(win.lists) do
                local l = 61 + 110 * (k - 1)
                X.List(win, list, l, 99, l + 109, 219, 96)
                -- the chosen row framed in 0x8F (DrawRectFrame), the name right-aligned in 0x25 (s6-interface-7x-b round 8,
                -- a marked edit: the original client's kit paints a row through list.rowPainter, list.x7row before)
                list.rowPainter = function(row, selected)
                    row.sel:SetAlpha(0)
                    row.text:SetJustifyH("RIGHT")
                    row.text:SetTextColor(S.Colour(S.LIST))
                    for _, side in ipairs({ "top", "left", "bottom", "right" }) do
                        local key = "x7frame" .. side
                        if not row[key] then row[key] = X.Solid(row, "BORDER", 0x8F) end
                        X.Line(row, row[key], side, 0)
                        row[key]:SetShown(selected)
                    end
                end
            end
            for r, edit in ipairs(win.thresholds) do X.Edit(edit, win, 36, 221 + 15 * (r - 1), 61, 235 + 15 * (r - 1), 0x8F) end
            for r = 1, 5 do
                for col = 1, 5 do
                    local fs = win.grid[r][col]
                    S.Text(fs, 0x8F)
                    fs:SetJustifyH("LEFT")
                    fs:ClearAllPoints()
                    fs:SetPoint("TOPLEFT", win, "TOPLEFT", 62 + 110 * (col - 1), -(234 + 15 * (r - 1) - 11))
                end
            end
        end,
        --- s6-interface-7x (round 2): a power's row (the renderer's { id, name, amount, level }) as 4a's
        --- PowerListPane::DrawListEntry (0x0054B220): the name alone (4a draws no level) and the level's swatch, a 10 x 10
        --- fill at (5, 1) of the row. The swatch's colour code is level x 8 + 52 (PowerDialogPane.cpp:104); its palette
        --- slot (code + 4) / 256 picks BARAM.PAL for 0 (SetDrawColor), else SUPER(slot - 1).PAL at code % 256
        --- (FillColorRect, GetSlotPalette(3, 0, slot)). The level is the player's dye (the server's armor_color).
        row = function(row, r)
            row.text:SetText(K.Text(r[2]))
            local swatch = row.x7swatch
            if not swatch then
                swatch = row:CreateTexture(nil, "ARTWORK")
                row.x7swatch = swatch
                X.Rect(swatch, row, 5, 1, 15, 11)
            end
            local code = (r[4] or 0) * 8 + 52
            local slot = math.floor((code + 4) / 256)
            if slot == 0 then S.Fill(swatch, code) else S.Fill(swatch, code % 256, 1, "SUPER" .. (slot - 1) .. ".PAL") end
            swatch:Show()
        end,
    }
end

return Power
