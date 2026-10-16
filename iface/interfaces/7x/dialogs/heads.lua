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

return function(L, X)
    L.Heads = {
        width = 374, height = 316, button = 63, head = { 41, 54 }, page = 63,
        place = function(win)
            if TK.Art.Image("DLGMSGH.EPF", 0, "NPAL8.PAL") then
                X.Art(win, "DLGMSGH.EPF", "NPAL8.PAL")
            else
                local frame = X.DIALOG_FRAME
                X.Frame(win, 374, 316, frame.file, frame.palette, frame.tile)
            end
            X.Image(win, win.ok, 14, 40, 266, 103, 290)
            X.Image(win, win.left, 18, 114, 266, 177, 290)
            X.Image(win, win.right, 19, 188, 266, 251, 290)
            X.Image(win, win.close, 15, 262, 266, 325, 290)
            X.Rect(win.preview, win, 36, 40, 73, 95)
            X.Text(win.text, win, 86, 29, 336, 92)
            win.text:SetWordWrap(true)
            local capsule, cw, ch = TK.Art.Image("CAPSULE.EPF", 0, "NPAL3.PAL")
            local ox, oy = 0, 0
            if capsule then ox, oy = TK.Art.Origin(capsule) end
            for i = 0, 9 do
                local b = win.heads[i]
                local l, t = 58 + i % 5 * 54, 113 + math.floor(i / 5) * 64
                X.Rect(b, win, l, t, l + 41, t + 54)
                b.capsule = b.capsule or b:CreateTexture(nil, "BORDER")
                if capsule then
                    b.capsule:SetTexture(capsule)
                    b.capsule:SetSize(cw, ch)
                    b.capsule:ClearAllPoints()
                    b.capsule:SetPoint("TOPLEFT", b, "TOPLEFT", 3 + ox, -(1 + oy))
                end
                X.Bare(b) -- 4a's head button draws the head alone: no chrome, no caption, no click sound
            end
        end,
    }
end
