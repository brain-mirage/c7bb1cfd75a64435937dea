-- s6-interface-7x-b (round 7): 7.x's look of the music dialog and the paper (components/dialogs/misc.lua), 4a's own
-- windows. Drawing only, but for where each control's press lands (its rectangle): the controls, their indexes, the keys
-- and what is sent are the renderer's and the model's, the same in every look.
--
-- The music dialog (MusicControlDialog::MusicControlDialog 0x00528E60, MusicControlDialog.cpp:23-120): 407 x 410 at its
-- slot 3 (L.Place: centred), DLGSCNTL.EPF in PFLOOK.PAL as its picture; the effects radio (1) of two 45 x 11 options at
-- (52, 77) and (200, 77), the frequency radio (3) at (51, 139), (124, 139) and (192, 139), drawn as 4a's radios (X.Radio);
-- Browse (7, image 50) (205, 205)-(268, 229); the silent transport (11-13, images 46, 48/37 for pause, 47), enabled
-- by the model's source rule (4a UpdateActionButton), at (36, 305), (110, 305), (184,
-- 305), 63 x 24; OK (14, image 14) (110, 360)-(173, 384). 4a's other controls (the two volume sliders 2 and 4, the music
-- source 5, the folder 6, the CD drive 8, the order and repeat 9 and 10) are declared by the model, but the shared
-- renderer/commands do not wire them yet. The picture shows their captions; the Sound page keeps the settings
-- (a known limitation).
--
-- The paper (EditablePaperPane::BuildControlsWithText 0x00545250, DrawBorder 0x005459B0, DrawBackground 0x00545D50): its
-- size from the packet, (columns + 2) x (rows + 3) cells of 16 pixels, at its slot 7 (L.Place: centred on (512, 384), as
-- DialogPane::AddToLayer puts it over the (320, 240) rectangle the pane asks for); LINE001.EPD in BARAM.PAL tiled inside
-- 16 pixels (frame 8) under its border (1 top, 5 bottom, 7 left, 3 right, the corners 0, 2, 6, 4); the text (16, 16)-
-- (width - 16, 16 (rows + 1)) in whole 12-pixel lines with its scroll bar (the TextEditControlPane's vertical bar), or a
-- read-only paper's centred line. It slides open (SlideOpenVertical). LINE001.EPD's verified 7.5.2 bytes use the
-- existing EPF reader/export and named image keys; a pack with those nine tiles supplies the paper art (X.Frame).
-- s6-ui-core (round 85): the XML twin's; the windows' pictures, options, buttons and the inputs' rectangles are
-- misc.xml's (core/xml.md).

local unpack = table.unpack
local entry = require("interfaces.xml.entry")
local D = TK.Xml.Data("misc.xml")

--- The rectangles of a list of misc.xml's options.
local function rects(options)
    local out = {}
    for i, o in ipairs(options) do out[i] = o.rect end
    return out
end

return function(L, X)
    -- ----- the music dialog -----

    local M = D.Music
    -- the radios' options (left, top, right, bottom): the effects (control 1: on, off), the frequency (control 3)
    local EFFECTS = rects(M.effects)
    local FREQUENCY = rects(M.frequencies)

    L.Music = entry(M, {
        place = function(win)
            X.Art(win, unpack(M.art))
            -- the radios' options take the presses on 4a's option rectangles; their pictures are drawn by paint
            X.Rect(win.on, win, unpack(EFFECTS[1]))
            X.Rect(win.off, win, unpack(EFFECTS[2]))
            for i, b in ipairs(win.freq) do X.Rect(b, win, unpack(FREQUENCY[i])) end
            for _, b in ipairs({ win.on, win.off, win.freq[1], win.freq[2], win.freq[3] }) do b.noClickSound = true end
            X.Image(win, win.browse, unpack(M.browse))
            X.Image(win, win.prev, unpack(M.prev))
            X.Image(win, win.pause, M.pauseImages.playing, unpack(M.pause))
            X.Image(win, win.next, unpack(M.next))
            X.Image(win, win.ok, unpack(M.ok))
        end,
        -- s6-ui-core r66, X8: place the new shared input surfaces using 4a's existing rectangles.
        -- Drawing only; the original indexes/parts and all audio stay in the shared renderer/model.
        placeControls = function(win)
            local v = M.volumes
            for _, item in ipairs({ { win.effectsVolume, v.effects }, { win.musicVolume, v.music } }) do
                local f, x, y = item[1], item[2][1], item[2][2]
                X.Rect(f, win, x, y, x + v.width, y + v.height)
                f.title:Hide() f.lo:Hide() f.hi:Hide()
                X.Rect(f.slider, win, x, y, x + v.width, y + v.height)
            end
            for _, item in ipairs({ { win.source, rects(M.sources) }, { win.order, rects(M.orders) },
                { win.repeatMode, rects(M.repeats) } }) do
                item[1].title:Hide()
                local first, last = item[2][1], item[2][#item[2]]
                X.Rect(item[1], win, first[1], first[2], last[3], last[4])
                for i, b in ipairs(item[1].buttons) do X.Rect(b, win, unpack(item[2][i])) b:SetText("") end
            end
            X.Rect(win.folder, win, unpack(M.folder)) win.folder:SetBackdrop(nil)
            win.cd.title:Hide() X.Rect(win.cd.button, win, unpack(M.cd))
        end,
        --- the radios as 4a draws them (the renderer's states: effects 0 on, 1 off; the frequency's selection); the kit's
        --- buttons under them stay where they are but show nothing
        paint = function(win, effects)
            for _, b in ipairs({ win.on, win.off, win.freq[1], win.freq[2], win.freq[3] }) do b:SetAlpha(0) end
            X.Radio(win, "x7on", effects == 0, EFFECTS[1][1], EFFECTS[1][2], EFFECTS[1][4])
            X.Radio(win, "x7off", effects == 1, EFFECTS[2][1], EFFECTS[2][2], EFFECTS[2][4])
            for i, r in ipairs(FREQUENCY) do X.Radio(win, "x7freq" .. i, win.frequency == i - 1, r[1], r[2], r[4]) end
            -- r66: the source/order/repeat use the same shared one-of state and existing native radio painter.
            for _, item in ipairs({ { win.source, "source" }, { win.order, "order" }, { win.repeatMode, "repeat" } }) do
                for i, b in ipairs(item[1].buttons) do
                    b:SetAlpha(0)
                    local l, bottom, width, height = b:GetRect()
                    local wl, wb, _, wh = win:GetRect()
                    X.Radio(win, "x7" .. item[2] .. i, item[1]:GetValue() == i - 1,
                        l - wl, wh - (bottom - wb) - height, wh - (bottom - wb))
                end
            end
            -- TogglePauseState 0x0052A180: the button's picture follows the dialog's flag, not a stream retained
            -- from an earlier dialog. Drawing only; the control index and release command remain the model's.
            local images = M.pauseImages
            X.Image(win, win.pause, win.view and win.view.contents.paused and images.paused or images.playing, unpack(M.pause))
        end,
    })

    -- ----- the paper -----

    local P = D.Paper
    L.Paper = entry(P, {
        place = function() end,
        --- the window by the packet's cells (the renderer, as the paper opens): the kit's paper (X.Paper) on LINE001.EPD
        --- in BARAM.PAL; it slides open as it opens
        fit = function(win, c)
            X.Paper(win, c, unpack(P.art))
            if win.opened then X.SlideOpen(win) end
        end,
    })
end
