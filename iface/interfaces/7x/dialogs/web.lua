-- s6-modular-g (interfaces, round 13): 7.x's look of the web board and the browser dialog (components/dialogs/web.lua),
-- from Source-5's class pages. Drawing only: the close, the 73 request and the 62 page are the renderer's and the
-- model's.
--
-- Both are the web board's frame (X.WebFrame: WEBBOARD.EPF's pieces round WBOARDBK.EPF), centred on the screen, sliding
-- open. The web board (WebBoardDialog 0x0046D050) by its mode: the board (0) 700 x 500, CLOSE (0, image 30) at (318, 468),
-- the browser's area (11, 42)-(689, 460); a player's page (4) 418 x 566, CLOSE at (318, 468) (inside the browser's area,
-- as 4a's), the area (11, 42)-(407, 526); mode 6 800 x 600, CLOSE at (368, 568), the area (11, 42)-(789, 560). The
-- browser dialog (BrowserDialog 0x0046AA40): 662 x 562 for a server's page (4a's default: HandleOpenBrowserPacket passes
-- 0 x 0), 900 x 650 for the help key's (UserPane::HandleKeyOrTextEvent; the model's contents.help, s6-interface-7x round
-- 2), OK (0, image 14) at ((w - 63) / 2, h - 32), the area (11, 42) w - 22 by h - 82 (ComputeControlRect). 4a shows a
-- browser in the area; ours shows the page's text, its address and Open in browser there (plan 5.11, D10: the system
-- browser).

local S = require("interfaces.7x.skin")

return function(L, X)
    -- the web board's modes: the window's size, CLOSE's place and the browser's area
    local MODES = {
        [0] = { 700, 500, 318, 468, { 11, 42, 689, 460 } },
        [4] = { 418, 566, 318, 468, { 11, 42, 407, 526 } },
        [6] = { 800, 600, 368, 568, { 11, 42, 789, 560 } },
    }

    --- The window at w x h on the web board's frame, its button (image) at (bx, by), the page's text, address and Open in
    --- browser in the browser's area (l, t)-(r, b); it slides open when it has just opened.
    local function lay(win, w, h, button, image, bx, by, area)
        local opened = win.opened
        X.Size(win, w, h)
        X.WebFrame(win, w, h)
        X.Image(win, button, image, bx, by, bx + 63, by + 24)
        local l, t, r, b = area[1], area[2], area[3], area[4]
        X.Text(win.text, win, l + 10, t + 10, r - 10, b - 40)
        win.text:SetWordWrap(true)
        X.Text(win.url, win, l + 10, t + 50, r - 10, t + 62, S.LIST)
        win.open:ClearAllPoints()
        win.open:SetPoint("BOTTOMLEFT", win, "TOPLEFT", l + 10, -(b - 10))
        if opened then X.SlideOpen(win) end
    end

    L.WebBoard = {
        width = 700, height = 500, button = 63, openButton = 140, buttonHeight = 24,
        place = function(win) end,
        -- the mode's window (Board.update, after its texts)
        fill = function(win, c)
            local m = MODES[c.mode or 0] or MODES[0]
            lay(win, m[1], m[2], win.close, 30, m[3], m[4], m[5])
        end,
    }

    L.Browser = {
        width = 662, height = 562, button = 63, openButton = 140, buttonHeight = 24,
        place = function(win) end,
        fill = function(win, c)
            local w, h = 662, 562
            if c and c.help then w, h = 900, 650 end
            lay(win, w, h, win.ok, 14, math.floor((w - 63) / 2), h - 32, { 11, 42, w - 11, h - 40 })
        end,
    }
end
