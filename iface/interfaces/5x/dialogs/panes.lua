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

local S = require("interfaces.5x.skin")
local Screen = require("interfaces.screen")

return function(L, X)
    L.Timer = {
        --- at (133, 10) of the 5.x screen, at its scale
        open = function(win)
            local s, left, top = Screen.Fit(S.WIDTH, S.HEIGHT)
            win:SetScale(s)
            win:ClearAllPoints()
            win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (left + 133 * s) / s, -(top + 10 * s) / s)
        end,
        place = function(win) win:SetSize(5 * 35, 70) end,
        fit = function(win, n) win:SetWidth(n * 35) end,
        --- glyph g (0-9, 10 the colon) in cell i: 5.33's picture centred in its 35 x 70 cell; false without it
        glyph = function(win, cell, i, g)
            local key = S.Image("NUMBER.EPF", g)
            if not key then return false end
            local ok, fw, fh = __tk:GetArtFrameSize(key)
            if not ok then return false end
            S.Picture(win, cell, "NUMBER.EPF", g, nil, (i - 1) * 35 + math.floor((35 - fw) / 2), math.floor((70 - fh) / 2))
            return true
        end,
    }
end
