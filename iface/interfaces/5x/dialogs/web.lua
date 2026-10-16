-- s6-interface-5x-b (round 8, s6-interface-5x's Y2; the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md,
-- "The dialogs look"): 5.x's look of the browser dialog (components/dialogs/web.lua's BrowserDialog, D-53: the server's
-- page, S 0x66 kind 0, and the help key's). Drawing only: the close and what is sent are the renderer's and the model's.
--
-- 5.33's BrowserDialog (constructor 0x00406F90) is the whole 640 x 480 screen with its browser over all of it, no frame
-- and no button: the page itself is the window. Ours shows the page's text, its address and Open in browser (plan 5.11,
-- D10: the system browser), on 5.33's standard window over the screen. The model's keyboard dismissal stays;
-- no OK button is drawn, as 5.33 has none. The help key's
-- page, 900 x 650 in 7.5.2, is the same screen here: 5.x's screen is 640 x 480.

return function(L, X)
    L.Browser = {
        width = 640, height = 480, button = 72, openButton = 140, buttonHeight = 24,
        place = function(win)
            local frame = X.DIALOG_FRAME
            X.Frame(win, 640, 480, frame.file, frame.palette, frame.tile)
            X.Text(win.text, win, 40, 40, 600, 84)
            win.text:SetWordWrap(true)
            X.Text(win.url, win, 40, 90, 600, 102)
            win.open:ClearAllPoints()
            win.open:SetPoint("TOPLEFT", win, "TOPLEFT", 40, -112)
            win.ok:Hide() -- 5.33 BrowserDialog 0x00406F90 has no OK button
        end,
    }
end
