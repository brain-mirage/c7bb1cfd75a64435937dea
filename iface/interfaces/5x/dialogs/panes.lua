-- s6-interface-5x-b (round 6; the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md, "The dialogs look"):
-- 5.x's look of the server's timer (components/dialogs/panes.lua, D-71), 5.33's own pane. Drawing only: the timer takes
-- no input and sends nothing.
--
-- 5.33's TimerPane (HandleTimerPanePacket 0x0046AE00, TimerPane__Constructor 0x004CAB60, its paint 0x004CAE20; 4a's
-- TimerPane.cpp, the same code, whose old-art branch puts it at (312, 10)): at (133, 10) of the 640 x 480 screen, 35
-- pixels a glyph (5 for MM:SS, 8 for HH:MM:SS) by 70, filled with colour 0, which its pane (mode 1) shows through, and
-- NUMBER.EPF's digits (10 the colon) in the screen's palette (BARAM.PAL), from 5.33's own set. 5.33's digits are centred
-- on their point (frame 0 is (-15, -22)-(14, 22)), which its paint puts at (35 k, 10) of the pane, so they would be cut
-- at the pane's top; how 5.33's loader stores such a frame was not read, so each digit is centred in its cell here (a
-- known limitation in the job's notes).
--
-- s6-ui-core (round 85): the XML twin's; its place, cells and digits are panes.xml's (core/xml.md).

local S = require("interfaces.5x.skin")
local Screen = require("interfaces.screen")
local T = TK.Xml.Data("panes.xml").Timer

return function(L, X)
    L.Timer = {
        --- at its place on the 5.x screen, at its scale
        open = function(win)
            local s, left, top = Screen.Fit(S.WIDTH, S.HEIGHT)
            win:SetScale(s)
            win:ClearAllPoints()
            win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (left + T.x * s) / s, -(top + T.y * s) / s)
        end,
        place = function(win) win:SetSize(T.glyphs * T.glyph, T.height) end,
        fit = function(win, n) win:SetWidth(n * T.glyph) end,
        --- glyph g (0-9, 10 the colon) in cell i: 5.33's picture centred in its cell; false without it
        glyph = function(win, cell, i, g)
            local key = S.Image(T.file, g)
            if not key then return false end
            local ok, fw, fh = __tk:GetArtFrameSize(key)
            if not ok then return false end
            S.Picture(win, cell, T.file, g, nil, (i - 1) * T.glyph + math.floor((T.glyph - fw) / 2), math.floor((T.height - fh) / 2))
            return true
        end,
    }
end
