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
-- s6-ui-core (round 85): the XML twin's; the windows' pictures, rows, texts and parts are options.xml's (core/xml.md).

local S = require("interfaces.7x.skin")
local unpack = table.unpack
local entry = require("interfaces.original.entry")
local D = TK.Xml.Data("options.xml")

return function(L, X)
    --- A row's text of TargetOptionEditControlPane::OnPaint, bold, made once under key: from x of the row at (l, t) of
    --- the window, on the row's line 14 ((top + bottom + 8) / 2 of its 20 pixels).
    local function rowText(win, key, text, x, l, t, line)
        local fs = win[key]
        if not fs then
            fs = win:CreateFontString(nil, "OVERLAY")
            win[key] = fs
        end
        X.Bold(win, fs, l + x, t + line, S.TEXT)
        fs:SetText(text)
    end

    local T = D.Target
    L.Target = entry(T, {
        place = function(win)
            X.Art(win, unpack(T.art))
            X.Image(win, win.ok, unpack(T.ok))
            local rows = T.rows
            for row = 1, #T.keys do
                local l, t = rows.x, rows.y + rows.step * (row - 1)
                local keys = T.keys[row]
                rowText(win, "x7keys" .. row, keys.text, keys.x, l, t, rows.line)
                rowText(win, "x7user" .. row, T.user.text, T.user.x, l, t, rows.line)
                rowText(win, "x7monster" .. row, T.monster.text, T.monster.x, l, t, rows.line)
                -- Input routing: a switch takes a press only on its 20 x 20 part, as 4a's HitTestPoint (0x00499870) walks
                -- GetPartRect's two rectangles (a press on its caption does nothing). The switches choose what the arrow
                -- keys step through while a spell's target is picked (SpellWhoInputPane), so which target a cast names:
                -- moving a part (options.xml's parts) changes which press toggles one.
                for part = 0, 1 do
                    local b = win.switches[row][part]
                    local pl = l + T.parts[part + 1]
                    X.Rect(b, win, pl, t, pl + T.switch, t + T.switch)
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
            local o = T.onoff
            for row = 1, #T.keys do
                for part = 0, 1 do
                    local b = win.switches[row][part]
                    local on = rows[row] and rows[row][part + 1]
                    local key, w, h = TK.Art.Image(o.file, on and 1 or 0, o.palette)
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
    })

    local P = D.Profile
    L.Profile = entry(P, {
        place = function(win)
            X.Art(win, unpack(P.art))
            X.EditBar(win.edit, win, unpack(P.edit)) -- round 2: with its bar (10 lines show of 16)
            X.Image(win, win.ok, unpack(P.ok))
        end,
    })
end
