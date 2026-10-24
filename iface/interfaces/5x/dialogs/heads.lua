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
--
-- s6-ui-core (round 85): the XML twin's; the window's picture, buttons, preview, text and grid are heads.xml's
-- (core/xml.md).

local S = require("interfaces.5x.skin")
local unpack = table.unpack
local entry = require("interfaces.original.entry")
local D = TK.Xml.Data("heads.xml")

return function(L, X)
    local H = D.Heads
    local GRID, CAPSULE = H.heads, H.capsule

    L.Heads = entry(H, {
        head = H.head,
        -- the preview's pane, and the scale its base-set picture is asked at
        preview = { H.previewSize[1], H.previewSize[2], S.GAME_ART },
        place = function(win)
            local file, palette = unpack(H.art)
            local key = TK.Art.Image(file, 0, palette)
            if key then
                win.art:SetTexture(key)
                X.Rect(win.art, win, 0, 0, H.width, H.height)
                win.art:Show()
            else
                -- neither set holds DLGMSGH.EPF (Astra's review of round 6): 5.33's standard window behind it meanwhile
                local frame = X.DIALOG_FRAME
                X.Frame(win, H.width, H.height, frame.file, frame.palette, frame.tile)
            end
            X.Image(win, win.ok, unpack(H.ok))
            X.Image(win, win.left, unpack(H.left))
            X.Image(win, win.right, unpack(H.right))
            X.Image(win, win.close, unpack(H.close))
            X.Default(win, win.ok)
            X.Rect(win.preview, win, unpack(H.previewRect))
            X.Text(win.text, win, unpack(H.text))
            win.text:SetWordWrap(true)
            local w, h = unpack(H.head)
            for i = 0, GRID.count - 1 do
                local b = win.heads[i]
                local l, t = GRID.x + i % GRID.columns * GRID.across, GRID.y + math.floor(i / GRID.columns) * GRID.down
                X.Rect(b, win, l, t, l + w, t + h)
                b.capsule = b.capsule or b:CreateTexture(nil, "BORDER")
                local capsule, cw, ch = S.Image(CAPSULE.file, 0, CAPSULE.palette)
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
    })
end
