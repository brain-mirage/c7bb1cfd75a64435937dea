-- s6-interface-7x (round 1): 7.x's look of two windows the Menu popup opens (its Target and Profile rows), 4a's
-- ui/OptionPane.cpp, from Source-5's class pages (the EPF layout): components/dialogs/panes.lua's TargetOptionDialog and
-- misc.lua's ProfileDialog. Drawing only, but for the switches' press areas (below): the indexes, the parts, the keys and
-- what OK does are the renderers' and the model's.
--
-- The target options (TargetOptionDialog 0x00542270): 338 x 190 on DLGSETUP.EPF in DLGSETUP.PAL, slot 3 (centred),
-- sliding open; OK (1, image 14) (138, 156); the rows ARROW (2) and SHIFT+ARROW (3) (TargetOptionEditControlPane) at
-- (19, 64 + 34 i)-(318, 84 + 34 i), each drawn by its OnPaint (0x00499430: font 0 in 0x80, bold, on the row's line 14):
-- its keys' name from x 18 (ARROW) or 0 (SHIFT+ARROW), "USER" from 130 and "MONSTER" from 220, and the two switches'
-- ONOFFBUT.EPF pictures in BUTTON.PAL (frame 1 on, 0 off) on their parts, (110, 0)-(130, 20) and (200, 0)-(220, 20)
-- (GetPartRect 0x00499810). Nothing in it plays a sound but its opening (DialogPane::AddToLayer's 0x198).
-- The profile (ProfileDialog 0x0053F940): 285 x 238 on DLGPROFL.EPF in DLGPROFL.PAL, slot 12 (centred), sliding open;
-- the text (1) (68, 54)-(225, 174), an edit in 0x8F with its scroll bar at the right edge (wrapping at 145, round 2);
-- OK (2, image 14) (108, 200).

local S = require("interfaces.7x.skin")

return function(L, X)
    --- A row's text of TargetOptionEditControlPane::OnPaint, bold, made once under key: from x of the row at (l, t) of
    --- the window, on the row's line 14 ((top + bottom + 8) / 2 of its 20 pixels).
    local function rowText(win, key, text, x, l, t)
        local fs = win[key]
        if not fs then
            fs = win:CreateFontString(nil, "OVERLAY")
            win[key] = fs
        end
        X.Bold(win, fs, l + x, t + 14, S.TEXT)
        fs:SetText(text)
    end

    L.Target = {
        width = 338, height = 190, button = 63, switch = 20, buttonHeight = 20, slide = true,
        place = function(win)
            X.Art(win, "DLGSETUP.EPF", "DLGSETUP.PAL")
            X.Image(win, win.ok, 14, 138, 156, 201, 180)
            for row = 1, 2 do
                local l, t = 19, 64 + 34 * (row - 1)
                rowText(win, "x7keys" .. row, row == 1 and "ARROW" or "SHIFT+ARROW", row == 1 and 18 or 0, l, t)
                rowText(win, "x7user" .. row, "USER", 130, l, t)
                rowText(win, "x7monster" .. row, "MONSTER", 220, l, t)
                -- Input routing: a switch takes a press only on its 20 x 20 part, as 4a's HitTestPoint (0x00499870) walks
                -- GetPartRect's two rectangles (a press on its caption does nothing). The switches choose what the arrow
                -- keys step through while a spell's target is picked (SpellWhoInputPane), so which target a cast names:
                -- moving a part changes which press toggles one.
                for part = 0, 1 do
                    local b = win.switches[row][part]
                    local pl = l + (part == 0 and 110 or 200)
                    X.Rect(b, win, pl, t, pl + 20, t + 20)
                    -- round 2: no click sound, as 4a's switch (TargetOptionEditControlPane::HandlePointerOrMouseEvent
                    -- 0x00499670 toggles and repaints, nothing else)
                    b.noClickSound = true
                    local label = b:GetFontString() -- the renderer's "USER ON" stays its text, not drawn
                    if label then label:Hide() end
                    if b.GetHighlightTexture and b:GetHighlightTexture() then b:GetHighlightTexture():SetAlpha(0) end
                    b.x7box = b.x7box or b:CreateTexture(nil, "ARTWORK")
                end
            end
        end,
        -- the switches' pictures by their state (the renderer's rows: { user, monster } of each), drawn on their parts
        -- at the picture's own place in its frame, as RenderTileFrame puts it
        fill = function(win, rows)
            for row = 1, 2 do
                for part = 0, 1 do
                    local b = win.switches[row][part]
                    local on = rows[row] and rows[row][part + 1]
                    local key, w, h = TK.Art.Image("ONOFFBUT.EPF", on and 1 or 0, "BUTTON.PAL")
                    b:GetNormalTexture():SetAlpha(0)
                    b:GetPushedTexture():SetAlpha(0)
                    if key then
                        local ox, oy = TK.Art.Origin(key)
                        b.x7box:SetTexture(key)
                        b.x7box:SetSize(w, h)
                        b.x7box:ClearAllPoints()
                        b.x7box:SetPoint("TOPLEFT", b, "TOPLEFT", ox, -oy)
                        b.x7box:Show()
                    else
                        b.x7box:Hide()
                    end
                end
            end
        end,
    }

    L.Profile = {
        width = 285, height = 238, button = 63, editWidth = 157, editHeight = 120, slide = true,
        place = function(win)
            X.Art(win, "DLGPROFL.EPF", "DLGPROFL.PAL")
            X.EditBar(win.edit, win, 68, 54, 225, 174, 0x8F) -- round 2: with its bar (10 lines show of 16)
            X.Image(win, win.ok, 14, 108, 200, 171, 224)
        end,
    }
end
