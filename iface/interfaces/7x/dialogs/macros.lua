-- s6-interface-7x (round 2): 7.x's look of the original's Macro Setup (IntegrateMacroDialog 0x00541B30,
-- ui/OptionPane.cpp; Source-5's class pages), the window the macros component gives the dialog when a look has this
-- entry (components/macros/hotkeys.lua, Dialog.build), where the macro window's setting shows the original's Macro
-- Setup (the Menu's Hotkey row, its command). Drawing only: the rows, the controls and what they do are the macros
-- component's and the model's (nothing is sent).
--
-- 289 x 449 at placement slot 6 (centred), sliding open, with the open sound; DLGMAC2.EPF frame 0 in DLGMACRO.PAL, its
-- whole window (control 0, mode 1: colour 0 shows what is under it); OK (1, image 14) (118, 362), the previous page
-- (12, image 18) (30, 362), the next (13, image 19) (200, 362), 63 x 24; the ten rows (2-11) at (19, 54 + 29 i)-(268,
-- 74 + 29 i), each drawn as IntegrateMacroEditControlPane (SpellMacroEditControlPane::OnPaint 0x0057FFB0): font 0 in 0x80
-- on the row's line 16 ((top + 12 + bottom) / 2), the key "%d" from x 18, "Ctrl+%d" from 0, "Alt+%d" from 4; the kind T,
-- S or I from 40; from 50 a spell's or an item's "letter:name", or the text macro's line in its edit at (50, 4) of the
-- row; the row with the focus framed in 0x80. Under the picture, OnPaint's (0x00541E50) three help lines from x 9 on the
-- lines 413, 431 and 449, outlined (0x8F on 0x80), which show where the picture is colour 0.

local S = require("interfaces.7x.skin")

return function(L, X)
    local HELP = { "Spell : Select 'SPELLS' tab and press key.", "Item  : Select 'ITEMS' tab and press key.", "Text  : Press ';' key" }
    local KEY_X = { [0] = 18, [1] = 0, [2] = 4 } -- the key's x by the record's page (1-0, Ctrl+, Alt+)

    --- One of the row's texts, from x on the row's line 16.
    local function text(row, fs, x)
        S.Text(fs, S.TEXT)
        fs:SetWordWrap(false)
        fs:SetJustifyH("LEFT")
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", row, "TOPLEFT", x, -(16 - 12 + 1))
    end

    --- Row i (0-9) of the window: its rectangle, its edit (the line, 12 high from 4 down so its text is at 4a's), its
    --- texts and its focus frame (made once).
    local function placeRow(win, row, i)
        local t = 54 + 29 * i
        X.Rect(row, win, 19, t, 268, t + 20)
        X.Edit(row.edit, win, 69, t + 4, 288, t + 16, S.TEXT)
        if row.x7kind then return end
        row.x7kind = row:CreateFontString(nil, "OVERLAY")
        text(row, row.x7kind, 40)
        text(row, row.does, 50)
        text(row, row.key, KEY_X[0])
        -- the focused row's frame (DrawRectFrame in 0x80), as the kit's focus mark of its edit (L.FocusEdge)
        local lines = {}
        for _, side in ipairs({ "top", "left", "bottom", "right" }) do
            local tex = X.Solid(row, "OVERLAY", S.TEXT)
            X.Line(row, tex, side, 0)
            tex:Hide()
            lines[#lines + 1] = tex
        end
        row.x7frame = lines
        row.edit.x7mark = { SetShown = function(_, on) for _, tex in ipairs(lines) do tex:SetShown(on) end end }
        --- The record as 4a's row shows it (the component's refreshRow): its key at its page's x, its kind, its name.
        row.paint = function(kind, label)
            text(row, row.key, KEY_X[math.floor((row.record or 0) / 10)] or KEY_X[0])
            row.x7kind:SetText(kind or "")
            row.does:SetText(label or "")
        end
    end

    L.MacroSetup = {
        width = 289, height = 449, button = 63, editWidth = 219, editHeight = 12, slide = true,
        place = function(win)
            local p = win.panel
            X.Art(win, "DLGMAC2.EPF", "DLGMACRO.PAL")
            win.art:SetDrawLayer("ARTWORK") -- over the help lines, as 4a's picture control is over the dialog's own paint
            X.Image(win, p.ok, 14, 118, 362, 181, 386)
            X.Image(win, p.prev, 18, 30, 362, 93, 386)
            X.Image(win, p.next, 19, 200, 362, 263, 386)
            for i, line in ipairs(HELP) do X.Outlined(win, "x7help" .. i, 9, 413 + 18 * (i - 1), line, nil, "BACKGROUND") end
            for i, row in ipairs(p.rows) do placeRow(win, row, i - 1) end
        end,
    }
end
