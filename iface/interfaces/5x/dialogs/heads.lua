-- s6-interface-5x-b (round 6; the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md, "The dialogs look"):
-- 5.x's look of the barber's head choice (components/dialogs/npc.lua's HeadSelectDialog, D-06), 5.33's own window.
-- Drawing only, but for where each control's press lands: the controls, their indexes and what is sent are the
-- renderer's and the model's (nothing chosen is sent).
--
-- 5.33's HeadSelectDialog (constructor 0x00494840), which 4a keeps as its legacy branch (PursuitMessageDialogCreator.cpp,
-- HeadSelectDialog::HeadSelectDialog, g_useEpfAssets false): 374 x 316 on DLGMSGH.EPF in NPAL8.PAL (5.33's own NInt.dat
-- has no such picture, though its code names it, and our base set has none either: 5.33's standard window, DLGFRAME.EPF's
-- tiles, is drawn behind it until one is); OK (1, image 14) (40, 266)-
-- (112, 282), the page back (2, image 18) (114, 266)-(186, 282), on (3, image 19) (188, 266)-(260, 282), CLOSE (4, image 15)
-- (262, 266)-(334, 282), all 72 x 16; the preview (36, 40)-(71, 88), 35 x 48; the text (86, 29)-(336, 92); the heads on the
-- 5 x 2 grid of 41 x 54 buttons from (58, 113), 54 across and 64 down, the chosen one's capsule (5.33's CAPSULE.EPF in
-- NPAL3.PAL) centred behind it. The base set's heads and figure are 7.5.2's art, twice 5.33's: drawn at S.GAME_ART,
-- centred in their boxes.

local S = require("interfaces.5x.skin")

return function(L, X)
    L.Heads = {
        width = 374, height = 316, button = 72, head = { 41, 54 }, page = 72,
        -- the preview's pane, and the scale its base-set picture is asked at
        preview = { 35, 48, S.GAME_ART },
        place = function(win)
            local key = TK.Art.Image("DLGMSGH.EPF", 0, "NPAL8.PAL")
            if key then
                win.art:SetTexture(key)
                X.Rect(win.art, win, 0, 0, 374, 316)
                win.art:Show()
            else
                -- neither set holds DLGMSGH.EPF (Astra's review of round 6): 5.33's standard window behind it meanwhile
                local frame = X.DIALOG_FRAME
                X.Frame(win, 374, 316, frame.file, frame.palette, frame.tile)
            end
            X.Image(win, win.ok, 14, 40, 266, 112, 282)
            X.Image(win, win.left, 18, 114, 266, 186, 282)
            X.Image(win, win.right, 19, 188, 266, 260, 282)
            X.Image(win, win.close, 15, 262, 266, 334, 282)
            X.Default(win, win.ok)
            X.Rect(win.preview, win, 36, 40, 71, 88)
            X.Text(win.text, win, 86, 29, 336, 92)
            win.text:SetWordWrap(true)
            for i = 0, 9 do
                local b = win.heads[i]
                local l, t = 58 + i % 5 * 54, 113 + math.floor(i / 5) * 64
                X.Rect(b, win, l, t, l + 41, t + 54)
                b.capsule = b.capsule or b:CreateTexture(nil, "BORDER")
                local capsule, cw, ch = S.Image("CAPSULE.EPF", 0, "NPAL3.PAL")
                if capsule then
                    b.capsule:SetTexture(capsule)
                    b.capsule:SetSize(cw, ch)
                    b.capsule:ClearAllPoints()
                    b.capsule:SetPoint("CENTER", b, "CENTER", 0, 0)
                end
                -- 5.33's head button draws the head alone (ObjectImageButtonPane): no chrome, no caption, no click sound
                X.Bare(b)
            end
        end,
        --- a base-set picture (w x h) at S.GAME_ART, centred in its box
        fit = function(tex, box, w, h)
            tex:ClearAllPoints()
            tex:SetSize(w * S.GAME_ART, h * S.GAME_ART)
            tex:SetPoint("CENTER", box, "CENTER", 0, 0)
        end,
    }
end
