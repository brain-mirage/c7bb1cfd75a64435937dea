-- s6-interface-5x-b (round 6; the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md, "The dialogs look"):
-- 5.x's look of the profile, the paper and the music dialog (components/dialogs/misc.lua), 5.33's own windows by its own
-- numbers. Drawing only, but for where each control's press lands (its rectangle): the controls, their indexes, the keys
-- and what is sent are the renderers' and the model's, 7.5.2's, the same in every look.
--
-- The profile (ProfileDialog__ProfileDialog 0x00489090, 4a's legacy branch of OptionPane.cpp's ProfileDialog: the same
-- window): 314 x 246 on PROFILE.EPF in NPAL8.PAL, placed at (250, 200) (its AddToLayer, no slot); the text (36, 71)-(277,
-- 174); OK (image 14) (83, 196)-(155, 212), the default; CANCEL (image 22) (160, 196)-(232, 212), the legacy branch's
-- control 3, which the rules declare while this look is in use (DialogRules.LegacyLayouts) and which sends nothing.
--
-- The paper (EditablePaperPane, 5.33's 0x0048C6B0 and 4a's EditablePaperPane.cpp, the same code): its size from the
-- packet, (columns + 2) x (rows + 3) cells of 16 pixels, centred on (320, 240); LINE001.EPF (the screen's palette,
-- BARAM.PAL) tiled inside 16 pixels (frame 8, DrawBackground 0x0048CA50) under its border (DrawBorder 0x0048CAC0: 1 top,
-- 5 bottom, 7 left, 3 right, the corners 0, 2, 6, 4); the text (16, 16)-(width - 16, 16 (rows + 1)) in whole 12-pixel
-- lines, or a read-only paper's centred line (its last byte set): 8 pixels a character, 12 high, in the middle; its
-- right 12 pixels the text's vertical bar (round 9, s6-interface-7x-b's FOR note: both branches build their
-- TextEditControlPane with hasVerticalScrollbar, 4a's EditablePaperPane.cpp:73 and 83, 5.33's the same code).
--
-- The music dialog (MusicControlDialog__MusicControlDialog 0x00478720): 407 x 410 on DLGSCNTL.EPF in NPAL8.PAL, centred
-- (slot 3); the effects radio (1) of two options at (109, 97) and (260, 97), the three-way radio (3) at (109, 159),
-- (182, 159) and (250, 159), each 45 x 11 and drawn as 5.33's radios (X.Radio); Browse (7, image 50) (261, 232)-(333,
-- 248); the play buttons (11-13, images 46, 48, 47) (94, 314), (168, 314), (242, 314), 72 x 16; OK (14, image 14) (168,
-- 360)-(240, 376), the default. 5.33's other controls (the two volume sliders, the music source, the folder, the CD
-- drive, the order and repeat) are not the model's (its D-63 has 7.5.2's: the client's own sound settings keep them), so
-- only the picture shows their captions until ui-core's X8 seam consumes r18's native hooks below.
-- Wire: 5.33 sends 1B 00 as it opens, 7.5.2 1B 01 00; the protocol in use
-- decides, so the model's 7.5.2 bytes are kept.

return function(L, X)
    require("interfaces.5x.dialogs.folder")(L, X)

    -- ----- the profile -----

    L.Profile = {
        width = 314, height = 246, button = 72, editWidth = 241, editHeight = 103, cancel = true,
        slide = true, -- ProfileDialog 0x00489090 slides open (0x004208F0)
        -- placed by its top left at (250, 200), as its AddToLayer puts it
        centre = function() return 250 + 157, 200 + 123 end,
        place = function(win)
            X.Art(win, "PROFILE.EPF", "NPAL8.PAL")
            X.EditBar(win.edit, win, 36, 71, 277, 174) -- with its scroll bar (round 93, as the XML form)
            X.Image(win, win.ok, 14, 83, 196, 155, 212)
            if win.cancel then X.Image(win, win.cancel, 22, 160, 196, 232, 212) end
            -- OK is the default (5.33's SetFocusedControl(1), asset_callers.c:12385) with its own 1-pixel frame and no
            -- Enter frames round it, as the real 5.33 draws its profile (round 95; the XML form's misc.lua says why)
            X.Default(win, win.ok, false)
        end,
    }

    -- ----- the paper -----

    L.Paper = {
        width = 64, height = 80, editWidth = 32, editHeight = 24,
        place = function() end,
        --- the window by the packet's cells (the renderer, as the paper opens): the kit's paper (X.Paper) on LINE001.EPF
        --- in the screen's palette; it slides open as it opens, as 7.x's (5.33's EditablePaperPane 0x0048C6B0 calls
        --- 0x004208F0)
        fit = function(win, c)
            X.Paper(win, c, "LINE001.EPF", nil)
            if win.opened then X.SlideOpen(win) end
        end,
    }

    -- ----- the music dialog -----

    -- the radios' options: the effects (control 1: on, off), the three-way (control 3)
    local NativeMusic = require("interfaces.5x.dialogs.musiclayout")
    local NativeMusicArt = require("interfaces.5x.dialogs.musicart")
    local EFFECTS, THREE = NativeMusic.options[1], NativeMusic.options[3]

    L.Music = {
        width = NativeMusic.width, height = NativeMusic.height, button = 72, buttonHeight = 16, switch = 45, frequency = 45, play = 72,
        -- R18 art/rectangle contract for ui-core's shared X8 control/renderer seam.
        nativeLayout = NativeMusic,
        -- Ui-core's X8 renderer supplies these controls/states; these hooks only
        -- position shared input surfaces and paint 5.33 art. No local controls or
        -- settings are constructed here. Until X8 calls them, they are preparation.
        nativePlace = function(win, controls) NativeMusicArt.Place(X, win, controls) end,
        nativePaint = NativeMusicArt.Paint,
        place = function(win)
            X.Art(win, NativeMusic.background.file, NativeMusic.background.palette)
            -- Native rectangles place shared input surfaces. 4a OnControlCommand
            -- 0x00529790 still owns their IDs/parts; changing those bindings would
            -- change what the server sees. Their pictures are drawn by paint.
            X.Rect(win.on, win, table.unpack(EFFECTS[1]))
            X.Rect(win.off, win, table.unpack(EFFECTS[2]))
            for i, b in ipairs(win.freq) do X.Rect(b, win, table.unpack(THREE[i])) end
            for _, b in ipairs({ win.on, win.off, win.freq[1], win.freq[2], win.freq[3] }) do b.noClickSound = true end
            X.Image(win, win.browse, NativeMusic.buttons[7], table.unpack(NativeMusic.rects[7]))
            X.Image(win, win.prev, NativeMusic.buttons[11], table.unpack(NativeMusic.rects[11]))
            X.Image(win, win.pause, NativeMusic.buttons[12], table.unpack(NativeMusic.rects[12]))
            X.Image(win, win.next, NativeMusic.buttons[13], table.unpack(NativeMusic.rects[13]))
            X.Image(win, win.ok, NativeMusic.buttons[14], table.unpack(NativeMusic.rects[14]))
            X.Default(win, win.ok)
        end,
        --- the radios as 5.33 draws them (the renderer's states: effects 1 off, the three-way's selection); the kit's
        --- buttons under them stay where they are but show nothing
        paint = function(win, effects)
            for _, b in ipairs({ win.on, win.off, win.freq[1], win.freq[2], win.freq[3] }) do b:SetAlpha(0) end
            X.Radio(win, "x5on", effects ~= 1, EFFECTS[1][1], EFFECTS[1][2], EFFECTS[1][4])
            X.Radio(win, "x5off", effects == 1, EFFECTS[2][1], EFFECTS[2][2], EFFECTS[2][4])
            for i, r in ipairs(THREE) do X.Radio(win, "x5three" .. i, win.frequency == i - 1, r[1], r[2], r[4]) end
        end,
    }
end
