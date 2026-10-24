-- s6-modular-g (interfaces, round 12): 7.x's look of the popups (components/dialogs/panes.lua), from Source-5's class
-- pages: the player menu (RightButtonMenuPane: OnPaint 0x00554FC0, DrawBorder 0x00555370, GetRightButtonMenuItemRect
-- 0x005556A0) and the Menu popup (MenuVarietySelectPane: OnPaint 0x005BD3C0, DrawFrame 0x005BD630, GetItemRect
-- 0x005BD960). Each is a 79-pixel framed popup (SUBWIN.EPF in SUBWIN.PAL, 7-pixel tiles) whose texts are drawn twice a
-- pixel apart (bold) in 0x80, x 39 - 24 from its left; the row under the pointer has an outline from x 5 to 74 round its
-- rectangle, 0x8F on its left and top and 0x80 on its right and bottom (sunken, the other way round, while pressed).
--
-- The player menu: 79 x 126 at (x - 50, y - 50) of the press in the map pane, which starts at (-48, -48) on the screen;
-- the target's name centred by 6 pixels a character on a 0x80 bar (4, 9)-(75, 22), in 0x8F; Look, Trade, Whisper,
-- Group and Info on the lines 37, 53, 69, 85 and 117. The Menu popup: 79 x 172 at (735, 555); its ten rows on the lines
-- 21 + 16 n.
--
-- Input routing: each row's control takes the press on 4a's rectangle for it (the player menu's (0, 22 + 16 n)-(79,
-- 38 + 16 n) for n 0-4, so Info's is the empty line above its text and a press on the text is the menu's; the Menu
-- popup's (0, 6 + 16 n)-(79, 22 + 16 n)), as HitTestRightButtonMenuItem and MenuVarietySelectPane::HitTest walk them;
-- the controls' indexes and what they post are the renderer's. Changing a rectangle changes which control a press reaches,
-- so what the client sends.
-- s6-ui-core (round 85): the XML twin's; the popups' sizes, rows, lines and places are panes.xml's (core/xml.md).

local S = require("interfaces.7x.skin")
local unpack = table.unpack
local D = TK.Xml.Data("panes.xml")

return function(L, X)
    local P = D.POPUP

    --- A popup's window: w x h, its SUBWIN frame (made once).
    local function popup(w, h)
        local win = CreateFrame("Frame", nil, UIParent)
        win:SetSize(w, h)
        X.Frame(win, w, h, P.file, P.palette, P.tile)
        return win
    end

    -- the bold texts and the row outline are the look's helpers (X.Bold, X.Outline: s6-interface-7x moved them to
    -- init.lua, for the say-mode menu too); this popup's outline runs from x 5 to 74
    local function bold(win, fs, x, baseline, colour) X.Bold(win, fs, x, baseline, colour) end
    local function outline(r) X.Outline(r, P.outlineLeft, P.outlineRight, P.outlineHeight) end

    --- Row i's rectangle: 79 wide, from the rows' top, step apart and step high (WIRE: where its press lands, above).
    local function rowRect(win, r, rows, w, i)
        local t = rows.top + rows.step * (i - 1)
        X.Rect(r, win, 0, t, w, t + rows.step)
    end

    local PM = D.PlayerMenu
    L.PlayerMenu = {
        panel = function()
            local win = popup(unpack(PM.size))
            win.x7bar = win:CreateTexture(nil, "ARTWORK")
            S.Fill(win.x7bar, S.TEXT)
            X.Rect(win.x7bar, win, unpack(PM.bar))
            return win
        end,
        -- the name: centred by 6 pixels a byte of the game's code page (39 - 3 * its length: a Hangul character two
        -- bytes there), on the line 21, in 0x8F
        place = function(win)
            local n = PM.name
            bold(win, win.name, n.x, n.line, n.colour)
            win.name.onBoldText = function(text)
                local bytes = 0
                for _, c in utf8.codes(text or "") do bytes = bytes + (c < 0x80 and 1 or 2) end
                win.name:ClearAllPoints()
                win.name:SetPoint("TOPLEFT", win, "TOPLEFT", n.x - n.half * bytes, -(n.line - 12 + 1))
            end
        end,
        row = function(win, r, i)
            rowRect(win, r, PM.rows, PM.size[1], i)
            bold(win, r.label, P.label, PM.lines[i] or 0, S.TEXT)
            outline(r)
        end,
        -- at (x - 2, y - 2) of the press on the screen: (x - 50, y - 50) in the map pane at (-48, -48)
        open = function(win)
            local px, py = __tk:GetPressPosition()
            local u = TK.UIScale()
            local x, y = X.ScreenPoint(px / u, py / u)
            X.PlaceAt(win, math.floor(x) + PM.open[1], math.floor(y) + PM.open[2])
        end,
    }

    local MP = D.MenuPopup
    L.MenuPopup = {
        -- the popup, telling 7.x's MENU button (panels/menu) when it opens and closes: its picture follows (frame 2 open)
        panel = function(rows)
            local win = popup(unpack(MP.size))
            local function tell(open)
                local menu = TK.GetComponent("7x.menu")
                if menu and menu.SetOpen then menu:SetOpen(open) end
            end
            win:HookScript("OnShow", function() tell(true) end)
            win:HookScript("OnHide", function() tell(false) end)
            return win
        end,
        row = function(win, r, i)
            rowRect(win, r, MP.rows, MP.size[1], i)
            bold(win, r.label, P.label, MP.rows.line + MP.rows.step * (i - 1), S.TEXT)
            outline(r)
        end,
        open = function(win) X.PlaceAt(win, unpack(MP.open)) end,
    }

    -- D-71 (s6-interface-7x-b, round 7): the server's timer (TimerPane, TimerPane.cpp:14-137; MapPane.cpp:5544-5548 makes
    -- it at (325, 15)): 35 pixels a glyph (5 for MM:SS, 8 for HH:MM:SS) by 70, filled with colour 0, which its pane (mode
    -- 1) shows through. DrawDigit draws NUMBER.EPF's frame (10 the colon, BARAM.PAL) at its own frame rectangle moved by
    -- (35 k, 15): the pane's own y (m_positionY) again, inside the pane, so the digits sit 15 pixels below its top. The
    -- frames' rectangles' left and top are 7.5.2's NUMBER.EPF's (panes.xml's digits); the packs give each texture's crop
    -- in its frame (TK.Art.Origin). It takes no input.
    local T = D.Timer
    L.Timer = {
        open = function(win) X.PlaceAt(win, unpack(T.at)) end,
        place = function(win)
            win:SetSize(T.glyphs * T.glyph, T.height)
            win.text:SetPoint("TOP", win, "TOP", 0, -T.top)
        end,
        fit = function(win, n) win:SetWidth(n * T.glyph) end,
        --- glyph g (0-9, 10 the colon) in cell i, where DrawDigit puts it; false without its picture
        glyph = function(win, cell, i, g)
            local key, w, h = TK.Art.Image(T.file, g, T.palette)
            if not key then return false end
            local ox, oy = TK.Art.Origin(key)
            local at = T.digits[g + 1]
            cell:SetTexture(key)
            cell:SetSize(w, h)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", win, "TOPLEFT", (i - 1) * T.glyph + at.x + ox, -(T.top + at.y + oy))
            return true
        end,
    }

    -- D-75 (s6-interface-7x-b, round 7): the transfer's animation (TransferServerDialogPane, TransferServerDialogPane.cpp:
    -- 14-48 and its OnPaint): a pane the size of TRANSSVR.EPF's frames' union, (30, 44)-(282, 282), moved by ((W - 144) / 2
    -- - 100, (H - 144) / 2 - 100) of the map pane ((-48, -48)-(864, 768)) in the world, so at (314, 280); without the map
    -- (the login's, and the menu's 5E: s6-rules-dialogs round 38) by ((1024 - 144) / 2, (768 - 144) / 2), so at
    -- (470, 356). Each frame's rectangle is drawn at the pane's top left (OnPaint moves it to 0, 0): its texture at its
    -- crop's place in it (frame). It takes no input.
    local TR = D.Transfer
    L.Transfer = {
        open = function(win)
            if TK.GameState:InWorld() then X.PlaceAt(win, unpack(TR.world)) else X.PlaceAt(win, unpack(TR.login)) end
        end,
        place = function(win)
            win:SetSize(unpack(TR.size))
            win.text:SetPoint("CENTER", win, "CENTER", 0, 0)
        end,
        frame = function(win, key)
            local ox, oy = TK.Art.Origin(key)
            win.tex:ClearAllPoints()
            win.tex:SetPoint("TOPLEFT", win, "TOPLEFT", ox, -oy)
        end,
    }
end
