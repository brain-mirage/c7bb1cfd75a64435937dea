-- s6-interface-7x-b (round 7): 7.x's look of the barber's head choice (components/dialogs/npc.lua's HeadSelectDialog, D-06),
-- 4a's own window. Drawing only, but for where each control's press lands: the controls, their indexes and what is sent
-- are the renderer's and the model's (nothing chosen is sent).
--
-- HeadSelectDialog::HeadSelectDialog (PursuitMessageDialogCreator.cpp:1552-1631, the EPF branch): 374 x 316 at its slot
-- 1 (L.Place) on DLGMSGH.EPF in NPAL8.PAL; OK (1, image 14) (40, 266)-(103, 290), the page back (2, image 18) (114, 266)-
-- (177, 290), on (3, image 19) (188, 266)-(251, 290), CLOSE (4, image 15) (262, 266)-(325, 290), all 63 x 24; the
-- preview (36, 40)-(73, 95), 37 x 55 (the renderer's default); the text (86, 29)-(336, 92); the heads on the 5 x 2 grid of
-- 41 x 54 buttons from (58, 113), 54 across and 64 down, the chosen one's capsule behind it at (3, 1) of its button
-- (ObjectImageButtonPane::OnPaint, TextMenuItemList.cpp:2357-2367: 4a's CAPSULE.EPD, which 7.5.2 holds as CAPSULE.EPF,
-- in NPAL3.PAL). 7.5.2 ships neither DLGMSGH.EPF nor CAPSULE.EPD, so the original never shows this dialog
-- (docs/s5-notes/2026-10-04-head-choice-art-missing-in-7.5.2.md; open question 39): 4a's standard window stands in for
-- the background, as 5.x's look does.
-- s6-ui-core (round 85): the XML twin's; the window's picture, buttons, preview, text and grid are heads.xml's
-- (core/xml.md).

local unpack = table.unpack
local entry = require("interfaces.xml.entry")
local D = TK.Xml.Data("heads.xml")

return function(L, X)
    local H = D.Heads
    local GRID, CAPSULE = H.heads, H.capsule

    L.Heads = entry(H, {
        head = H.head,
        place = function(win)
            local file, palette = unpack(H.art)
            if TK.Art.Image(file, 0, palette) then
                X.Art(win, file, palette)
            else
                local frame = X.DIALOG_FRAME
                X.Frame(win, H.width, H.height, frame.file, frame.palette, frame.tile)
            end
            X.Image(win, win.ok, unpack(H.ok))
            X.Image(win, win.left, unpack(H.left))
            X.Image(win, win.right, unpack(H.right))
            X.Image(win, win.close, unpack(H.close))
            X.Rect(win.preview, win, unpack(H.preview))
            X.Text(win.text, win, unpack(H.text))
            win.text:SetWordWrap(true)
            local capsule, cw, ch = TK.Art.Image(CAPSULE.file, 0, CAPSULE.palette)
            local ox, oy = 0, 0
            if capsule then ox, oy = TK.Art.Origin(capsule) end
            local w, h = unpack(H.head)
            for i = 0, GRID.count - 1 do
                local b = win.heads[i]
                local l, t = GRID.x + i % GRID.columns * GRID.across, GRID.y + math.floor(i / GRID.columns) * GRID.down
                X.Rect(b, win, l, t, l + w, t + h)
                b.capsule = b.capsule or b:CreateTexture(nil, "BORDER")
                if capsule then
                    b.capsule:SetTexture(capsule)
                    b.capsule:SetSize(cw, ch)
                    b.capsule:ClearAllPoints()
                    b.capsule:SetPoint("TOPLEFT", b, "TOPLEFT", CAPSULE.x + ox, -(CAPSULE.y + oy))
                end
                X.Bare(b) -- 4a's head button draws the head alone: no chrome, no caption, no click sound
            end
        end,
    })
end
