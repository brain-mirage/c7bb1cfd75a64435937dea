-- s6-interface-5x-b (round 8, s6-interface-5x's Y2; the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md,
-- "The dialogs look"): 5.x's look of the browser dialog (components/dialogs/web.lua's BrowserDialog, D-53: the server's
-- page, S 0x66 kind 0, and the help key's). Drawing only: the close and what is sent are the renderer's and the model's.
--
-- 5.33's BrowserDialog (constructor 0x00406F90) is the whole 640 x 480 screen with its browser over all of it, no frame
-- and no button: the page itself is the window. Ours shows the page's text, its address and Open in browser (plan 5.11,
-- D10: the system browser), on 5.33's standard window over the screen. The model's keyboard dismissal stays;
-- no OK button is drawn, as 5.33 has none. The help key's
-- page, 900 x 650 in 7.5.2, is the same screen here: 5.x's screen is 640 x 480.
--
-- s6-ui-core (round 85): the XML twin's; the window's size and the parts' places are web.xml's (core/xml.md).

local unpack = table.unpack
local entry = require("interfaces.original.entry")
local B = TK.Xml.Data("web.xml").Browser

return function(L, X)
    L.Browser = entry(B, {
        place = function(win)
            local frame = X.DIALOG_FRAME
            X.Frame(win, B.width, B.height, frame.file, frame.palette, frame.tile)
            X.Text(win.text, win, unpack(B.text))
            win.text:SetWordWrap(true)
            X.Text(win.url, win, unpack(B.url))
            win.open:ClearAllPoints()
            win.open:SetPoint("TOPLEFT", win, "TOPLEFT", B.open[1], -B.open[2])
            win.ok:Hide() -- 5.33 BrowserDialog 0x00406F90 has no OK button
        end,
    })
end
