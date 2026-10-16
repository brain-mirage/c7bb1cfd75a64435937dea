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
-- s6-ui-core (round 85): the XML twin's; the windows' sizes, buttons and areas are web.xml's (core/xml.md).

local S = require("interfaces.7x.skin")
local unpack = table.unpack
local entry = require("interfaces.xml.entry")
local D = TK.Xml.Data("web.xml")

return function(L, X)
    local A = D.AREA

    -- the web board's modes (web.xml's): the window's size, CLOSE's place and the browser's area
    local MODES = {}
    for _, m in ipairs(D.WebBoard.modes) do MODES[m.mode] = m end

    --- The window at w x h on the web board's frame, its button (image) at (bx, by), the page's text, address and Open in
    --- browser in the browser's area (l, t)-(r, b); it slides open when it has just opened.
    local function lay(win, w, h, button, image, bx, by, area)
        local opened = win.opened
        X.Size(win, w, h)
        X.WebFrame(win, w, h)
        X.Image(win, button, image, bx, by, bx + 63, by + 24)
        local l, t, r, b = area[1], area[2], area[3], area[4]
        local i = A.inset
        X.Text(win.text, win, l + i, t + i, r - i, b - A.textBottom)
        win.text:SetWordWrap(true)
        X.Text(win.url, win, l + i, t + A.address, r - i, t + A.address + 12, S.LIST)
        win.open:ClearAllPoints()
        win.open:SetPoint("BOTTOMLEFT", win, "TOPLEFT", l + i, -(b - i))
        if opened then X.SlideOpen(win) end
    end

    local W = D.WebBoard
    L.WebBoard = entry(W, {
        place = function(win) end,
        -- the mode's window (Board.update, after its texts)
        fill = function(win, c)
            local m = MODES[c.mode or 0] or MODES[0]
            local w, h = unpack(m.size)
            local bx, by = unpack(m.close)
            lay(win, w, h, win.close, W.image, bx, by, m.area)
        end,
    })

    local B = D.Browser
    L.Browser = entry(B, {
        place = function(win) end,
        fill = function(win, c)
            local w, h = B.width, B.height
            if c and c.help then w, h = unpack(B.help) end
            local a = B.area
            lay(win, w, h, win.ok, B.image, math.floor((w - B.button) / 2), h - B.okUp, { a.left, a.top, w - a.right, h - a.bottom })
        end,
    })
end
