-- s6-devtools (round 5; the interface separation's step 5: docs/development/interface-separation.md 4.4 and 5.15, open
-- question 49, decision 2026-10-05-original-kit-and-tool-skin): the original client's drawing of its dialogs' parts, for
-- any interface that draws 4a's windows (7.x's and 5.x's dialogs looks, 7.x's panels): rectangles, pictures, image and
-- text buttons, texts, lists and their scroll bar, the window frames, the Enter frame, edits, outlines, the slide. Moved
-- from 7.x's look (interfaces/7x/dialogs/init.lua, s6-modular-g's phase 4 and the rounds after it), whose helpers 5.x's
-- look inherited; what differed between the two (the font, its measures, the screen, where a window opens) is now the
-- caller's: each interface makes its own set with its skin and screen. The fields the helpers keep on frames have neutral
-- names (the x7 ones before: docs/development/jobs/s6-devtools/FOR-s6-interface-7x-b-and-5x-b-r5.md lists them).
--
-- A renderer (components/dialogs/) makes its window's parts with their control indexes, fills them from the dialog model
-- and passes the player's input on; these helpers only size, place and draw them. Three keep 4a's input routing and say
-- so (WIRE): the list's rows (X.List), the blocker (X.Blocker) and the slide's press passing (X.SlideOpen); step 6 moves
-- those into the dialogs kit, unchanged.

local Screen = require("interfaces.screen")

-- The slides: one clipping frame (a ScrollFrame clips what is in it) over the window's place while it slides, and one
-- frame over that place that takes the pointer meanwhile (the shield). One for the client: 4a's slides block it while
-- they run, so there is never a second.
local slideClip, slideShield

--- The helpers for one interface. ctx = {
---   skin = its skin: the palette's fields (interfaces/original/palette.lua) and Text(fs, index), TextWidth(text),
---          Picture(parent, tex, file, frame, palette, x, y, layer) and FACE (the edits' font face);
---   screen = { width, height }: its fixed game screen (7.5.2's 1024 x 768, 5.33's 640 x 480), fitted to the window as
---          interfaces/screen.lua fits it;
---   place = function(win): its look's placement of a window that has just opened (it keeps the window's top left on the
---          screen as win.screenX, win.screenY) }.
--- X.Art draws with the skin's Picture; the frames (X.Frame, X.WebFrame) and the image buttons (X.Image) are 7.5.2's,
--- from the base set's pictures (TK.Art): a look whose own set draws them another way overrides them (5.x's 5.33 frame
--- and buttons, the kit's frame its fallback without the 5.33 set).
--- Returns a new table of helpers (X), which the look may add to or override: X.DIALOG_FRAME (its standard window's
--- picture, { file, palette, tile }) and X.Fallback (the look of the windows it does not draw, for alerts.lua) are the
--- look's to set; X.CENTRE is the screen's centre.
return function(ctx)
    local S, place = ctx.skin, ctx.place
    local SW, SH = ctx.screen.width, ctx.screen.height
    local X = { skin = S, CENTRE = { SW / 2, SH / 2 } }

    --- The screen's scale, and its left and top on UIParent (its letterbox).
    local function screen() return Screen.Fit(SW, SH) end

    --- A rectangle of 4a's (left, top)-(right, bottom), right and bottom exclusive, as a region's place and size in the window.
    function X.Rect(region, win, l, t, r, b)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", win, "TOPLEFT", l, -t)
        region:SetSize(r - l, b - t)
    end

    --- The window's size (a dialog's own, by its kind), and its place on the screen when the dialog has just opened.
    function X.Size(win, w, h)
        win:SetSize(w, h)
        if win.opened then place(win) end
    end

    --- s6-optimize (round 52; moved from 7.x's and 5.x's dialogs/init.lua, the same in both): a dialog's window for an
    --- entry of the look (the dialogs component supplies it): w x h on UIParent, the entry kept (win.lookEntry: the
    --- families' files and the kit's alerts know a window of the look by it), the title kept but not drawn (DialogPane
    --- stores m_title and never draws it), and the picture's texture (X.Art's) hidden until it is drawn.
    function X.Window(w, h, title, entry)
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(w, h)
        f.lookEntry = entry
        f.title = TK.UI.Label(f, title or "", 12)
        f.title:Hide()
        f.art = f:CreateTexture(nil, "BACKGROUND")
        f.art:Hide()
        return f
    end

    --- The window's picture (control 0 of 4a's EPF dialogs: EPFImageControlPane, frame 0) at its top left, in the skin's
    --- pictures; nil keeps none.
    function X.Art(win, file, palette)
        if not file then return win.art:Hide() end
        S.Picture(win, win.art, file, 0, palette, 0, 0, "BACKGROUND")
    end

    --- A texture of a picture's frame, filling a button at its crop's place (a missing one draws nothing); clip w x h
    --- crops the picture to a rectangle smaller than it (4a draws a picture into the control's rectangle, clipped).
    --- image is the set it is read from (TK.Art.Image, the base set, when nil).
    local function frameTexture(btn, file, frame, palette, clipW, clipH, image)
        local t = btn:CreateTexture(nil, "ARTWORK")
        local key, w, h = (image or TK.Art.Image)(file, frame, palette)
        if not key then
            t:SetColorTexture(0, 0, 0, 0)
            t:SetAllPoints(btn)
            return t
        end
        local ox, oy = TK.Art.Origin(key)
        t:SetTexture(key)
        local cw, ch = w, h
        if clipW and ox + w > clipW then cw = math.max(0, clipW - ox) end
        if clipH and oy + h > clipH then ch = math.max(0, clipH - oy) end
        t:SetSize(cw, ch)
        t:SetTexCoord(0, cw / w, 0, ch / h)
        t:SetPoint("TOPLEFT", btn, "TOPLEFT", ox, -oy)
        t.key = key
        return t
    end

    --- An image button of 4a's (ImageButtonControlPane): one of the kit's buttons (its control index and its input
    --- unchanged) drawn with BUTT001.EPF's frames for the id (ids 3-54) or BUTT002.EPF's bars (ids 55-61), at its
    --- rectangle; no caption, no hover (the pictures carry the captions), and no click sound (s6-interface-7x round 2:
    --- 4a's controls play none, ui/ControlPane.cpp). The focused picture's key is btn.focusedPicture, the normal one's
    --- btn.normalPicture (the look's focus mark swaps them).
    function X.Image(win, btn, id, l, t, r, b)
        btn.noClickSound = true
        X.Rect(btn, win, l, t, r, b)
        local w, h = r - l, b - t
        if btn.imageId == id and btn.imageSize == w * 10000 + h then return end -- drawn already (a window used again)
        btn.imageId, btn.imageSize = id, w * 10000 + h
        -- the pictures it had for its states (the kit's, or another id's) give way
        for _, old in ipairs({ btn.__normal, btn.__pushed, btn.__disabled }) do old:Hide() end
        local file, palette, base = "BUTT001.EPF", "BUTT001.PAL", id * 4
        if id >= 55 then file, palette, base = "BUTT002.EPF", "NPAL8.PAL", (id - 54) * 2 end
        local normal = frameTexture(btn, file, base, palette, w, h)
        btn:SetNormalTexture(normal)
        btn:SetPushedTexture(frameTexture(btn, file, base + 1, palette, w, h))
        btn.focusedPicture = nil
        if id < 55 then
            btn:SetDisabledTexture(frameTexture(btn, file, base + 2, palette, w, h))
            -- the focused picture (offset 3) takes the normal one's place while the control has the focus (the look's
            -- focus mark); the normal texture shows it, so this one only names it
            local focused = frameTexture(btn, file, base + 3, palette, w, h)
            focused:Hide()
            btn.focusedPicture = focused.key
        else
            -- BUTT002's bars: a disabled one is the normal picture under a 0x8F wash (draw mode 2)
            local wash = btn:CreateTexture(nil, "OVERLAY")
            wash:SetAllPoints(btn)
            S.Fill(wash, S.WHITE, 0.5)
            btn:SetDisabledTexture(wash)
        end
        btn.normalPicture = normal.key
        if btn.GetHighlightTexture and btn:GetHighlightTexture() then btn:GetHighlightTexture():SetColorTexture(0, 0, 0, 0) end
        local label = btn:GetFontString()
        if label then label:Hide() end
    end

    --- s6-ui-core (round 87): a picture button of 4a's (PrettyButtonControlPane, OnPaint 0x0054B7C0): three chosen frames
    --- of an image resource in its palette, the pressed one while it is held, else the selected one while it is the
    --- chosen one of its group (X.Chosen: SetSelected 0x0054B700), else the normal one; no caption, no hover and no click
    --- sound, as X.Image's. Its pictures are the skin's own set where it has one (S.Image: 5.x's 5.33 files, round 88),
    --- else the base set's.
    function X.Pretty(win, btn, file, palette, normal, pressed, selected, l, t, r, b)
        btn.noClickSound = true
        X.Rect(btn, win, l, t, r, b)
        for _, old in ipairs({ btn.__normal, btn.__pushed, btn.__disabled }) do old:Hide() end
        local w, h = r - l, b - t
        btn.prettyNormal = frameTexture(btn, file, normal, palette, w, h, S.Image)
        btn.prettySelected = frameTexture(btn, file, selected, palette, w, h, S.Image)
        btn.prettySelected:Hide()
        btn:SetNormalTexture(btn.prettyNormal)
        btn:SetPushedTexture(frameTexture(btn, file, pressed, palette, w, h, S.Image))
        if btn.GetHighlightTexture and btn:GetHighlightTexture() then btn:GetHighlightTexture():SetColorTexture(0, 0, 0, 0) end
        local label = btn:GetFontString()
        if label then label:Hide() end
    end

    --- X.Pretty's button marked the chosen one of its group, or not: its selected frame in place of its normal one.
    function X.Chosen(btn, on)
        local now = on and btn.prettySelected or btn.prettyNormal
        if btn:GetNormalTexture() == now then return end
        btn:GetNormalTexture():Hide()
        btn:SetNormalTexture(now)
    end

    --- A text of 4a's (StaticTextControlPane): font 0 in colour 0x80 (or the given index), wrapped at its rectangle's
    --- width, from its top; one pixel lower than the rectangle's top, as font 0 puts a glyph at the line's top plus its
    --- box plus 1 (FontImageLib; the round 10 capture: our lines then land on the original's).
    function X.Text(fs, win, l, t, r, b, colour)
        S.Text(fs, colour or S.TEXT)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", win, "TOPLEFT", l, -(t + 1))
        fs:SetWidth(r - l)
        fs:SetJustifyH("LEFT")
    end

    --- The lines a text wraps to at width in font 0, by its glyphs' advances: each line's words while they fit, a word
    --- wider than the width on lines of its own (MeasureWrappedTextHeight's count; the layout's own wrapping draws it).
    local function wrappedLines(text, width)
        local space = S.TextWidth(" ") or 0
        local lines = 0
        for para in (text .. "\n"):gmatch("(.-)\n") do
            lines = lines + 1
            local x = 0
            for word in para:gmatch("%S+") do
                local w = S.TextWidth(word) or 0
                if x > 0 and x + space + w > width then
                    lines = lines + 1
                    x = 0
                end
                if w > width then
                    lines = lines + math.floor((w - 1) / width)
                    x = w % width
                else
                    x = x + (x > 0 and space or 0) + w
                end
            end
        end
        return lines
    end

    --- AlertPane's size for its message and its number of buttons (the constructor, 4a 0x0049FEB0; 5.33's 0x00421BA0
    --- has the same numbers): the message (the font string text, its text set) in font 0, colour 0x80, wrapped at its
    --- one-line width (its glyphs' advances: GrafPort::GetTextWidthNullTerminated) clamped to 160-240 with two buttons,
    --- 74-240 with one, at most 240 with none; the window that + 48 wide and its 12-pixel lines + 80 high (+ 48 without
    --- buttons), at most 800 x 600. Sets the text's look and wrap width; returns w, h. s6-ui-core (round 86): moved from
    --- interfaces/original/alerts.lua for the interfaces' own login screens' alerts (interfaces/xml/title.lua) too.
    function X.AlertSize(text, buttons)
        S.Text(text, S.TEXT)
        local message = text:GetText()
        local one = S.TextWidth(message)
        local lo = buttons == 2 and 160 or buttons == 1 and 74 or 0
        local wrap = math.floor(math.min(240, math.max(lo, one or 240)) + 0.5)
        text:SetWordWrap(true)
        text:SetWidth(wrap)
        -- 12-pixel lines (without the packs, one a line break)
        local lines = one and wrappedLines(message, wrap) or select(2, message:gsub("\n", "")) + 1
        return math.min(800, wrap + 48), math.min(600, lines * 12 + (buttons > 0 and 80 or 48))
    end

    --- s6-optimize (round 52; moved from 7.x's and 5.x's boards.lua and 5.x's exchange.lua): one of the window's own static
    --- texts (win[key], made once) at its rectangle, on one line, in 0x80 or the given colour index (X.Text's). Returns it.
    function X.StaticText(win, key, l, t, r, b, colour)
        if not win[key] then win[key] = win:CreateFontString(nil, "OVERLAY") end
        X.Text(win[key], win, l, t, r, b, colour)
        win[key]:SetWordWrap(false)
        return win[key]
    end

    --- 4a's vertical scroll bar of a list (ScrollPane in the EPF layout: ScrollPane::OnPaint 0x0055C650,
    --- GetScrollPartRect 0x0055D9E0): 13 pixels wide along the list's right edge, a pane of composition mode 1, so its
    --- colour-0 fills draw nothing: nothing at all while it cannot scroll; else the page areas' track, SLIDEBG.EPF in
    --- SLIDEBG.PAL 4 pixels in (frame 0 the top cap, frame 1's one row down to the thumb and on from it, frame 2 the bottom
    --- cap), and SCRBUTT.EPF's 38-pixel thumb (frame 1 while it is held, in BUTTON.PAL) at the position x (height - 38) /
    --- range, in rows. The kit's bar (W.ScrollArea) keeps its input: a press, a drag and the wheel do what they did.
    --- Drawing only.
    local function styleBar(list)
        local sf = list.sf
        local track, thumb = sf.track, sf.thumb
        if not track or sf.barStyle then return end
        track:ClearAllPoints()
        track:SetPoint("TOPLEFT", sf, "TOPRIGHT", 0, 0)
        track:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 0, 0)
        track:SetWidth(13)
        track.bg:Hide()
        local function art(frame, file, palette)
            local t = track:CreateTexture(nil, "ARTWORK")
            local key = TK.Art.Image(file, frame, palette)
            if key then t:SetTexture(key) else t:SetColorTexture(0, 0, 0, 0) end
            return t
        end
        -- the track above the thumb (top cap, strip) and below it (strip, bottom cap)
        local topCap, upper = art(0, "SLIDEBG.EPF", "SLIDEBG.PAL"), art(1, "SLIDEBG.EPF", "SLIDEBG.PAL")
        local lower, bottomCap = art(1, "SLIDEBG.EPF", "SLIDEBG.PAL"), art(2, "SLIDEBG.EPF", "SLIDEBG.PAL")
        local normal, held = TK.Art.Image("SCRBUTT.EPF", 0, "BUTTON.PAL"), TK.Art.Image("SCRBUTT.EPF", 1, "BUTTON.PAL")
        if normal then thumb.tex:SetTexture(normal) else thumb.tex:SetColorTexture(0, 0, 0, 0) end
        thumb.tex:SetVertexColor(1, 1, 1, 1) -- the kit's thin bar tints its thumb; 4a's picture is drawn as it is
        thumb:SetWidth(13)
        thumb:HookScript("OnMouseDown", function() if held then thumb.tex:SetTexture(held) end end)
        thumb:HookScript("OnMouseUp", function() if normal then thumb.tex:SetTexture(normal) end end)

        --- Rows y to y + n of the bar (5 wide, 4 in) drawn with t, of its picture's rows from - to (of rows in all: a
        --- cap's crop, 4a drawing into a smaller rectangle); none when empty.
        local function place(t, y, n, from, to, rows)
            t:SetShown(n > 0)
            if n <= 0 then return end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", track, "TOPLEFT", 4, -y)
            t:SetSize(5, n)
            t:SetTexCoord(0, 1, from / rows, to / rows)
        end
        sf.barStyle = function(range, h)
            local rh = list.rowHeight
            local rows = math.floor(range / rh + 0.5)
            h = math.floor(h + 0.5)
            local can = rows > 0 and h > 38
            track:Show()
            thumb:SetShown(can)
            for _, t in ipairs({ topCap, upper, lower, bottomCap }) do t:SetShown(can) end
            if not can then return end
            local pos = math.min(rows, math.max(0, math.floor(sf:GetVerticalScroll() / rh + 0.5)))
            local top = math.floor(pos * (h - 38) / rows)
            thumb:SetHeight(38)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 0, -top)
            -- part 1, rows 0 to top: frame 1's row from 3 down to the thumb, then the top cap at 0, cut at the thumb
            place(upper, 3, top - 3, 0, 1, 1)
            local cap = math.min(3, top)
            place(topCap, 0, cap, 0, cap, 3)
            -- part 3, rows top + 38 to h: frame 1's row from the thumb down to h - 3, then the bottom cap at h - 3, cut
            -- at the thumb
            local below = top + 38
            place(lower, below, h - 3 - below, 0, 1, 1)
            cap = math.min(3, h - below)
            place(bottomCap, h - cap, cap, 3 - cap, 3, 3)
        end
    end

    --- 4a's scroll bar on a scroll area of the kit's that is not a list (an article's or a letter's body): styleBar's,
    --- moving by step pixels a line.
    function X.Bar(sf, step) styleBar({ sf = sf, rowHeight = step }) end

    --- A list of 4a's (ScrollableControlPane over a ListPane): no background of its own (pane mode 1), its rows left of
    --- its scroll bar (13 pixels at the rectangle's right edge, styleBar), rowHeight high (12 by default); a row's text in
    --- colour 0x25, the selected row on a 0x25 bar with its text in 0x80 (TextMenuItemList::DrawListEntry,
    --- MenuQuestionItemList's), both the list's cell wide (ListPane's m_cellSize: cell pixels, list.cellWidth; the bar cut
    --- pixels less, list.cellCut, for the item menus'), no hover. A family's own rows (the item menus') draw over this with
    --- list.rowPainter(row, selected).
    ---
    --- WIRE (input routing): the rows take the whole width left of the bar, so a press anywhere across the list is the
    --- row's at its height, as ListPane::HitTestItem (0x004F4480) clamps a press into the cells (Astra's review of round
    --- 10); their height is the list's own, so the pointer picks the row 4a's would. Changing either changes which row a
    --- press picks, and the reply that sends it. The article and mail lists also page by their rows' height and their
    --- rectangle's (7.x's boards.lua, L.BoardList: when older rows are asked for).
    function X.List(win, list, l, t, r, b, cell, rowHeight)
        rowHeight = rowHeight or 12
        X.Rect(list.sf, win, l, t, r - 13, b)
        list:SetWidth(r - 13 - l)
        list.cellWidth = cell
        list.sf.bg:Hide()
        styleBar(list)
        list:SetRowHeight(rowHeight)
        list.styleRow = function(row)
            row:SetHeight(rowHeight)
            S.Text(row.text, S.LIST)
            S.Fill(row.sel, S.LIST)
            row.hl:SetColorTexture(0, 0, 0, 0)
        end
        list.paintRow = function(row, selected)
            -- the text on the row's 12-pixel middle band (its middle - 6), the glyphs one pixel lower as font 0's (round
            -- 12's capture: centred, it sat 2 pixels lower than the original's)
            row.text:ClearAllPoints()
            row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(math.floor(list.rowHeight / 2) - 6 + 1))
            row.text:SetWidth(list.cellWidth)
            row.sel:ClearAllPoints()
            row.sel:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            row.sel:SetSize(list.cellWidth - (list.cellCut or 0), list.rowHeight)
            row.text:SetTextColor(S.Colour(selected and S.TEXT or S.LIST))
            if list.rowPainter then list.rowPainter(row, selected) end
            -- s6-characters (round 43; Astra's review): a row whose selection changed is painted again, its items'
            -- pictures at this cycling step, as 4a's ListPane::OnItemSelected (0x004F45B0) invalidates those rows. (4a
            -- invalidates the rectangle round them, so rows between them too, and a picked row picked again: those keep
            -- their step here, a known limitation.) Drawing only.
            if row.wasSelected ~= nil and row.wasSelected ~= selected then X.Repicture(row) end
            row.wasSelected = selected
        end
        -- s6-characters (round 43): a scroll paints the rows it brings into view (their pictures at this step), while the
        -- rows that were in view keep theirs, as 4a's ScrollablePane::ApplyScrollPosition (0x0055EAE0) moves the pixels
        -- drawn and paints only the strip uncovered; watched as the list scrolls by the wheel, the bar's arrows, its
        -- track or its thumb. Drawing only.
        if not list.scrollWatched then
            list.scrollWatched = true
            local last
            list.sf:HookScript("OnUpdate", function(sf)
                local y = sf:GetVerticalScroll()
                if last ~= nil and y ~= last then
                    local rh, h = list.rowHeight, sf:GetHeight()
                    for i, row in ipairs(list.rows) do
                        local top = (i - 1) * rh
                        local wasShown = top >= last and top + rh <= last + h
                        if not wasShown and top + rh > y and top < y + h then X.Repicture(row) end
                    end
                end
                last = y
            end)
        end
        if list.sf.Refresh then list.sf.Refresh() end
    end

    --- s6-characters (round 43): an item's picture on a texture of a row's (or a window's), as a dialog draws it
    --- (TK.Art.Item: a cycling item at the step it is drawn at), remembered on its owner so X.Repicture can draw it
    --- again. The key and size, or nil.
    function X.ItemPicture(owner, tex, picture, colour)
        tex.itemPicture, tex.itemColour = picture, colour
        if not tex.itemListed then
            tex.itemListed = true
            owner.itemPictures = owner.itemPictures or {}
            table.insert(owner.itemPictures, tex)
        end
        if not picture then return nil end
        return TK.Art.Item(picture, colour)
    end

    --- s6-characters (round 43): a row's (or window's) item pictures drawn again: a cycling one's still copy at this step.
    function X.Repicture(owner)
        for _, tex in ipairs(owner.itemPictures or {}) do
            if tex.itemPicture and tex:IsShown() then
                local key = TK.Art.Item(tex.itemPicture, tex.itemColour)
                if key then tex:SetTexture(key) end
            end
        end
    end

    --- A tiler of a window's pictures (win.frameTiles, kept for its next size): tile(file, index, palette, x, y, clipW,
    --- clipH) draws a picture's frame at (x, y) of the window, its crop's place added, clipped to clipW x clipH from there.
    local function tiler(win)
        win.frameTiles = win.frameTiles or {}
        for _, t in ipairs(win.frameTiles) do t:Hide() end
        local n = 0
        return function(file, index, palette, x, y, clipW, clipH)
            n = n + 1
            local t = win.frameTiles[n]
            if not t then
                t = win:CreateTexture(nil, "BACKGROUND")
                win.frameTiles[n] = t
            end
            local key, tw, th = TK.Art.Image(file, index, palette)
            if not key then return end
            local ox, oy = TK.Art.Origin(key)
            local cw = math.max(0, math.min(tw, clipW - ox))
            local ch = math.max(0, math.min(th, clipH - oy))
            if cw == 0 or ch == 0 then return end
            t:SetTexture(key)
            t:SetTexCoord(0, cw / tw, 0, ch / th)
            t:SetSize(cw, ch)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", win, "TOPLEFT", x + ox, -(y + oy))
            t:Show()
        end
    end

    X.Tiler = tiler -- a family's own tiles (the predefined form's DLGBBS08 rows)

    --- A picture's frame tiled over (l, t)-(r, b) of the window at its own size (its frame rectangle), clipped at the
    --- edges.
    local function fill(tile, file, index, palette, l, t, r, b)
        local key, fw, fh = TK.Art.Image(file, index, palette)
        if not key then return end
        local ox, oy = TK.Art.Origin(key)
        local sx, sy = math.max(1, fw + ox), math.max(1, fh + oy)
        for y = t, b - 1, sy do
            for x = l, r - 1, sx do tile(file, index, palette, x, y, math.min(sx, r - x), math.min(sy, b - y)) end
        end
    end

    --- The standard window's frames (DLGFRAME.EPF's and SUBWIN.EPF's): the background 8, the edges 1 top, 6 bottom, 3
    --- left, 4 right, the corners 0, 2, 5, 7, the background inset by 1.
    X.FRAME_TILES = { bg = 8, top = 1, bottom = 6, left = 3, right = 4, tl = 0, tr = 2, bl = 5, br = 7, inset = 1 }

    --- A window's frame of 4a's at w x h, from a frame picture (DLGFRAME.EPF in PAL01.PAL, 14-pixel tiles: DialogPane's
    --- DrawBackground and DrawBorder; SUBWIN.EPF in SUBWIN.PAL, 7-pixel tiles: the popups'): the background frame tiled
    --- from the window's top left over it inset by tiles.inset, then its border tiles (each edge from one tile in and at
    --- least one tile, then the corners over the edges' ends). tiles: which frame is which (X.FRAME_TILES by default;
    --- s6-interface-7x-b, round 7: the paper's LINE001 numbers them otherwise and tiles its background inside 16 pixels).
    --- A picture named with its own tiles that the packs do not hold draws the look's standard window instead
    --- (X.DIALOG_FRAME).
    function X.Frame(win, w, h, file, palette, size, tiles)
        if tiles and not TK.Art.Image(file, tiles.bg, palette) then
            return X.Frame(win, w, h, X.DIALOG_FRAME.file, X.DIALOG_FRAME.palette, X.DIALOG_FRAME.tile)
        end
        local T = tiles or X.FRAME_TILES
        local tile = tiler(win)
        local i = T.inset
        fill(tile, file, T.bg, palette, i, i, w - i, h - i)
        local x = size
        repeat tile(file, T.top, palette, x, 0, size, size) tile(file, T.bottom, palette, x, h - size, size, size) x = x + size until x >= w - size
        local y = size
        repeat tile(file, T.left, palette, 0, y, size, size) tile(file, T.right, palette, w - size, y, size, size) y = y + size until y >= h - size
        tile(file, T.tl, palette, 0, 0, size, size) tile(file, T.tr, palette, w - size, 0, size, size)
        tile(file, T.bl, palette, 0, h - size, size, size) tile(file, T.br, palette, w - size, h - size, size, size)
    end

    --- The web board's frame of 4a's at w x h (WebBoardDialog::DrawBackground 0x0046DD00 and DrawBorder 0x0046DEA0, the
    --- rankings' and the fitting room's OnPaint alike): WBOARDBK.EPF frame 0 tiled inside the border (11 in at the sides,
    --- 42 at the top, 40 at the bottom), then WEBBOARD.EPF's pieces: the top edge (frame 1, 37 x 42) and the bottom edge
    --- (frame 6, 37 x 40) from x 37, the sides (frames 3 and 4, 11 x 40) from y 40, then the corners 0 and 2 (37 x 42), 5
    --- and 7 (37 x 40) over the edges' ends. dividers: x places of an inner edge pair (frame 4 at x, frame 3 at x + 10: the
    --- rankings').
    function X.WebFrame(win, w, h, dividers)
        local tile = tiler(win)
        local B, BP, F, FP = "WBOARDBK.EPF", "WBOARDBK.PAL", "WEBBOARD.EPF", "WEBBOARD.PAL"
        fill(tile, B, 0, BP, 11, 42, w - 11, h - 40)
        for x = 37, w - 38, 37 do
            tile(F, 1, FP, x, 0, math.min(37, w - 37 - x), 42)
            tile(F, 6, FP, x, h - 40, math.min(37, w - 37 - x), 40)
        end
        for y = 40, h - 41, 40 do
            local ch = math.min(40, h - 40 - y)
            tile(F, 3, FP, 0, y, 11, ch)
            tile(F, 4, FP, w - 11, y, 11, ch)
            for _, d in ipairs(dividers or {}) do
                tile(F, 4, FP, d, y, 11, ch)
                tile(F, 3, FP, d + 10, y, 11, ch)
            end
        end
        tile(F, 0, FP, 0, 0, 37, 42) tile(F, 2, FP, w - 37, 0, 37, 42)
        tile(F, 5, FP, 0, h - 40, 37, 40) tile(F, 7, FP, w - 37, h - 40, 37, 40)
    end

    --- A text shortened to max pixels with "..." after it, as 4a's FitTextAndAppendSuffix (the skin's font's advances, or
    --- the given width function's), cut between whole characters.
    function X.Fit(text, max, width)
        return TK.Util.FitText(text, max, width or S.TextWidth)
    end

    --- A list row's own text (row[key], made once) at x on the row's 12-pixel middle band (its middle - 6), the glyphs one
    --- pixel lower as font 0's (DrawTextInRect, or MoveTo and DrawWideText at the middle + 6), in 0x25.
    function X.RowText(row, key, x)
        local fs = row[key]
        if not fs then
            fs = row:CreateFontString(nil, "OVERLAY")
            row[key] = fs
        end
        S.Text(fs, S.LIST)
        fs:SetWordWrap(false)
        fs:SetJustifyH("LEFT")
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", row, "TOPLEFT", x, -(math.floor(row:GetHeight() / 2) - 6 + 1))
        fs:Show()
        return fs
    end

    --- s6-optimize (round 52; moved from 7.x's and 5.x's boards.lua): a row's own text from x (X.RowText) whose leading
    --- spaces (a "%5d"'s or a "%2d"'s padding) are drawn as the font's advances.
    function X.PaddedRowText(row, key, x, text)
        local lead = text:match("^ *")
        X.RowText(row, key, x + (S.TextWidth(lead) or 0)):SetText(text:sub(#lead + 1))
    end

    --- An item row of 4a's lists (24 high): the item's picture (it.icon, an icon number of ITEM.EPF, or it.item, the
    --- server's 0xC000-biased picture id) with its colour (it.colour, its dye: TK.Art.Item, s6-interface-7x round 2) at
    --- half size centred on x cx and on the row's middle, clipped to the row (ItemObjImageLib::DrawItemImageScaled: 12 in
    --- the merchants' lists, 25 in the trade's and the pickers'), and its name from x, fitted to width (row.itemName; the
    --- kit's text hidden).
    function X.ItemRow(list, row, it, cx, x, width)
        if not row.itemIcon then row.itemIcon = row:CreateTexture(nil, "ARTWORK") end
        local picture = it.item or (it.icon and it.icon >= 0 and (it.icon + 0xC000) % 0x10000) or nil
        local key, w, h = X.ItemPicture(row, row.itemIcon, picture, it.colour) -- s6-characters (round 43): drawn again with the row
        if key then
            local hw, hh = math.floor(w / 2), math.floor(h / 2)
            local rh = list.rowHeight
            local top = math.floor(rh / 2) - math.floor(hh / 2)
            local vis = math.min(hh, rh - math.max(0, top))
            row.itemIcon:SetTexture(key)
            row.itemIcon:ClearAllPoints()
            row.itemIcon:SetPoint("TOPLEFT", row, "TOPLEFT", cx - math.floor(hw / 2), -math.max(0, top))
            row.itemIcon:SetSize(hw, math.max(1, vis))
            row.itemIcon:SetTexCoord(0, 1, 0, vis / math.max(1, hh))
            row.itemIcon:Show()
        else
            row.itemIcon:Hide()
        end
        row.text:Hide()
        X.RowText(row, "itemName", x):SetText(X.Fit(it.name or "", width))
    end

    --- One texture of a window's (or a button's) drawn parts, in a colour index.
    function X.Solid(parent, layer, index)
        local t = parent:CreateTexture(nil, layer or "ARTWORK")
        S.Fill(t, index)
        return t
    end

    --- A one-pixel line along a side of a frame, inset by k (side: "top", "bottom", "left", "right"; out: outside it).
    function X.Line(parent, tex, side, k, out)
        tex:ClearAllPoints()
        local o = out and -k or k
        if side == "top" or side == "bottom" then
            local y = side == "top" and -o or o
            local p1, p2 = side == "top" and "TOPLEFT" or "BOTTOMLEFT", side == "top" and "TOPRIGHT" or "BOTTOMRIGHT"
            tex:SetPoint(p1, parent, p1, o, y)
            tex:SetPoint(p2, parent, p2, -o, y)
            tex:SetHeight(1)
        else
            local x = side == "left" and o or -o
            local p1, p2 = side == "left" and "TOPLEFT" or "TOPRIGHT", side == "left" and "BOTTOMLEFT" or "BOTTOMRIGHT"
            tex:SetPoint(p1, parent, p1, x, -o)
            tex:SetPoint(p2, parent, p2, x, o)
            tex:SetWidth(1)
        end
    end

    --- The Enter frame round the dialog's default button (DialogPane::OnPaint): three one-pixel frames 2, 3 and 4 pixels
    --- outside it, in 0x84 (0x86 while it is disabled); none without a default button (btn nil). The frames are the
    --- window's (win.enterFrame), kept for its next fit. Drawing only.
    function X.EnterFrame(win, btn)
        if not win.enterFrame then
            win.enterFrame = {}
            for _ = 1, 12 do win.enterFrame[#win.enterFrame + 1] = X.Solid(win, "ARTWORK", S.ENTER) end
        end
        local shown = btn ~= nil and btn:IsShown()
        for k = 0, 2 do
            for i, side in ipairs({ "top", "left", "bottom", "right" }) do
                local tex = win.enterFrame[k * 4 + i]
                tex:SetShown(shown)
                if shown then
                    X.Line(btn, tex, side, 2 + k, true)
                    S.Fill(tex, btn:IsEnabled() and S.ENTER or S.DISABLED)
                end
            end
        end
    end

    --- 4a's text button at (l, t)-(r, b) of the window: its face inside two nested one-pixel bevels (top and left lit,
    --- bottom and right dark, swapped while it is pressed), its caption in font 0, colour 0x80, centred on a 12-pixel band
    --- from (top + bottom) / 2 - 6 with integer halves, glyphs one pixel below the band's top, one pixel down and right
    --- while pressed. TextButtonControlPane::OnPaint (the alerts'): face 0xC4, lit 0xC0, dark 0xC8 (the defaults);
    --- FittingRoomTextButtonControlPane::OnPaint 0x00424080 (the fitting room's and the rankings'): 0xD4, 0xD0, 0xD8. One
    --- of the kit's buttons, restyled: its control index and its input unchanged, no click sound (as X.Image). The default
    --- button's own frame (colour 1 on its rectangle) is btn.selectedFrame, hidden until its window shows it;
    --- btn.placeCaption(w, h) places the caption again (after its text changes).
    function X.TextButton(win, btn, l, t, r, b, face, lit, dark)
        btn.noClickSound = true
        X.Rect(btn, win, l, t, r, b)
        face, lit, dark = face or 0xC4, lit or 0xC0, dark or 0xC8
        if btn.textButton then
            btn.placeCaption(r - l, b - t)
            return
        end
        btn.textButton = true
        for _, old in ipairs({ btn.__normal, btn.__pushed, btn.__disabled }) do if old then old:Hide() end end
        if btn.GetHighlightTexture and btn:GetHighlightTexture() then btn:GetHighlightTexture():SetColorTexture(0, 0, 0, 0) end
        X.Solid(btn, "BACKGROUND", face):SetAllPoints(btn)
        local bevels = {}
        for k = 0, 1 do
            for _, side in ipairs({ "top", "left", "bottom", "right" }) do
                local tex = X.Solid(btn, "BORDER", lit)
                X.Line(btn, tex, side, k)
                bevels[#bevels + 1] = { tex = tex, lit = side == "top" or side == "left" }
            end
        end
        btn.selectedFrame = {}
        for _, side in ipairs({ "top", "left", "bottom", "right" }) do
            local tex = X.Solid(btn, "ARTWORK", 1)
            X.Line(btn, tex, side, 0)
            tex:Hide()
            btn.selectedFrame[#btn.selectedFrame + 1] = tex
        end
        local label = btn:GetFontString()
        S.Text(label, S.TEXT)
        -- the button's own caption colour too, which it puts back on a press and a release (Astra's review of round 10)
        btn:SetNormalFontColor(S.Colour(S.TEXT))
        label:SetJustifyH("LEFT")
        local down, bw, bh = false, r - l, b - t
        function btn.placeCaption(w, h)
            bw, bh = w or bw, h or bh
            local tw = S.TextWidth(btn:GetText() or "") or 0
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", btn, "TOPLEFT", math.floor((bw - tw) / 2) + (down and 1 or 0),
                -(math.floor(bh / 2) - 6 + 1 + (down and 1 or 0)))
        end
        local function pressed(on)
            for _, bevel in ipairs(bevels) do S.Fill(bevel.tex, (bevel.lit ~= on) and lit or dark) end
            down = on
            btn.placeCaption()
        end
        pressed(false)
        btn:HookScript("OnMouseDown", function(_, button) if button == "LeftButton" then pressed(true) end end)
        btn:HookScript("OnMouseUp", function() pressed(false) end)
    end

    --- An edit of 4a's (TextEditControlPane in a dialog): no frame, no background (pane mode 1), the skin's font 0 in
    --- 0x80 (or the given colour index), its text from the rectangle's edge.
    function X.Edit(edit, win, l, t, r, b, colour)
        X.Rect(edit, win, l, t, r, b)
        if edit.SetBackdrop then edit:SetBackdrop(nil) end
        __tk:SetFontFace(edit.__h, S.FACE)
        local r1, g, b2 = S.Colour(colour or S.TEXT)
        __tk:SetTextColor(edit.__h, r1, g, b2, 1)
        __tk:SetTextInsets(edit.__h, 0, 0, 0, 0)
        __tk:SetLineSpacing(edit.__h, -2) -- font 0's 12-pixel lines, as the skin's texts (S.Text: the new letter's body)
    end

    --- s6-interface-7x (round 2): a multi-line edit being written, with 4a's scroll bar (TextEditControlPane with its bar:
    --- a ScrollableControlPane over the TextEditPane; a letter's and an article's body, the predefined form's free text
    --- and block entries, the profile) at (l, t)-(r, b) of the window: the edit wraps 12 pixels short of the right edge,
    --- one wider than it shows, as 4a's (the constructor 0x00498920 takes 12 for the bar), and the bar is 13 wide at the
    --- edge (ScrollablePane::UpdateRenderRegion 0x0055EC00), styleBar's: nothing while the text fits, else the track and
    --- the thumb at the text's line. The wheel over the text scrolls it a line a notch (0x0055EF50), the thumb drags it.
    --- The text follows the caret on its own (the host's field, as 4a's ScrollCaretIntoView 0x0058E890), by whole
    --- 12-pixel lines as 4a's (the host's SetScrollLineStep). The bar (edit.scrollBar) is one of the kit's scroll areas
    --- over the text that stands for the edit (its scroll is the edit's), made once and shown with the edit. Drawing and
    --- the player's own scrolling only: nothing reaches the model.
    function X.EditBar(edit, win, l, t, r, b, colour)
        X.Edit(edit, win, l, t, r - 12, b, colour)
        local sf = edit.scrollBar
        if not sf then
            edit:SetScrollLineStep(12)
            sf = TK.UI.ScrollArea(win)
            edit.scrollBar = sf
            function sf:GetVerticalScroll() return edit:GetVerticalScroll() end
            function sf:GetVerticalScrollRange() return edit:GetVerticalScrollRange() end
            function sf:SetVerticalScroll(y) edit:SetVerticalScroll(y) end
            sf.wheelStep = 12
            X.Bar(sf, 12)
            -- the text moves on its own too (typing, the caret): the bar follows it
            sf:SetScript("OnUpdate", function()
                local y, range = edit:GetVerticalScroll(), edit:GetVerticalScrollRange()
                if y ~= sf.lastY or range ~= sf.lastRange then
                    sf.lastY, sf.lastRange = y, range
                    sf.Refresh()
                end
            end)
            local function shown(on)
                sf:SetShown(on)
                sf.track:SetShown(on)
            end
            edit:HookScript("OnShow", function() shown(true) end)
            edit:HookScript("OnHide", function() shown(false) end)
        end
        X.Rect(sf, win, l, t, r - 13, b)
        sf.lastY = nil
        sf:SetShown(edit:IsShown())
        sf.track:SetShown(edit:IsShown())
    end

    --- Native paper text and its read-only viewport, shared after moving the existing 5.x adapter.
    --- Shared by native looks; the caller retains its dimensions, frame and centred-line decision.
    function X.PaperText(win, c, l, t, r, b)
        -- EditablePaperPane::BuildControlsWithText (4a 0x00545250) keeps the inactive
        -- read-only edit's scrollbar. The centred-line owner decision keeps its plain line.
        -- Wire: OnControlCommand (0x00545220) closes read-only paper silently; this body
        -- never registers an edit/control command. Changing that routing changes what the server sees.
        if not c.writable and not c.centred then
            local fresh = not win.readOnlyScroll
            local sf = win:ReadOnlyBody()
            if fresh then
                -- GetScrollOffset (0x0058ED20): wheel and thumb move whole 12-pixel lines.
                local scrollTo = sf.SetVerticalScroll
                function sf:SetVerticalScroll(y)
                    y = math.max(0, math.min(y, self:GetVerticalScrollRange()))
                    scrollTo(self, 12 * math.floor(y / 12 + 0.5))
                end
                sf.wheelStep = 12
                sf.paperLineHeight = 12
                X.Bar(sf, 12)
            end
            local width = math.max(1, r - l - 12)
            X.Rect(sf, win, l, t, r - 13, b)
            X.Text(win.text, sf.content, 0, 0, width, b - t)
            win.text:SetWordWrap(true)
            sf.content:SetWidth(width)
        else
            win:PlainPaperText()
            X.Text(win.text, win, l, t, r, b)
            win.text:SetWordWrap(true)
            win.text:SetHeight(b - t)
        end
    end

    --- The paper's frames (LINE001's, X.Frame's tiles): the background 8 tiled inside 16 pixels, the edges and the corners
    --- (DrawBorder's lookups).
    X.PAPER_TILES = { bg = 8, top = 1, bottom = 5, left = 7, right = 3, tl = 0, tr = 2, bl = 6, br = 4, inset = 16 }

    --- s6-optimize (round 52; moved from 7.x's and 5.x's misc.lua, the same in both but for the frame's picture): the paper
    --- (EditablePaperPane) by the packet's cells c (the renderer's, as the paper opens): the window (columns + 2) x
    --- (rows + 3) cells of 16 pixels, its frame from file in palette (X.PAPER_TILES), and its text's rectangle with the
    --- edit and the text there (X.EditBar, X.PaperText). Drawing only.
    function X.Paper(win, c, file, palette)
        local columns, rows = c.columns or 0, c.rows or 0
        local w, h = (columns + 2) * 16, (rows + 3) * 16
        X.Size(win, w, h)
        X.Frame(win, w, h, file, palette, 16, X.PAPER_TILES)
        local l, t, r, b
        if not c.writable and c.centred then
            -- 8 pixels a character (wcslen: the UTF-8 text's lead bytes)
            local width = 8 * select(2, TK.Dialogs.Text(c.text or ""):gsub("[^\128-\191]", ""))
            l, t = math.floor((w - width) / 2), math.floor((h - 12) / 2)
            r, b = l + width, t + 12
        else
            l, t, r, b = 16, 16, w - 16, (rows + 1) * 16
        end
        -- whole lines (BuildControlsWithText: top + (height - 1) / 12 * 12; 4a's EditablePaperPane.cpp:71), which round
        -- the centred line's 12 pixels to none, so 4a shows none of its text; that line is kept here, so its text shows
        b = math.max(t + 12 * math.floor((b - t - 1) / 12), math.min(b, t + 12))
        X.EditBar(win.edit, win, l, t, r, b)
        X.PaperText(win, c, l, t, r, b)
    end

    --- The portrait of 4a's (ObjectImageControlPane, 74 x 108): the object centred, on nothing (pane mode 1).
    function X.Portrait(win, l, t)
        win.portraitSpec = { width = 74, height = 108, left = l, top = -t, textX = 0, black = false }
    end

    --- s6-interface-7x-b (round 7): a radio option of 4a's (RadioGroupControlPane::DrawItem 0x004964E0, the EPF branch):
    --- RBUTTON.EPF in RBUTTON.PAL, frame 0 chosen and 1 not (3 and 2 while disabled: enabled false), its box from the
    --- option rectangle's left and 7 above its middle, cut to the rectangle's rows t to b (the radio pane paints into its
    --- own surface, the group's rectangle, whose height is the options'). The texture is the window's (win[key]). Drawing
    --- only: the option's press is the kit's control under it.
    function X.Radio(win, key, chosen, l, t, b, enabled)
        local tex = win[key] or win:CreateTexture(nil, "ARTWORK")
        win[key] = tex
        local frame = enabled == false and (chosen and 3 or 2) or (chosen and 0 or 1)
        local img, w, h = TK.Art.Image("RBUTTON.EPF", frame, "RBUTTON.PAL")
        if not img then return tex:Hide() end
        local ox, oy = TK.Art.Origin(img)
        local x, y = l + ox, math.floor((t + b) / 2) - 7 + oy
        local top, bottom = math.max(y, t), math.min(y + h, b)
        if bottom <= top then return tex:Hide() end
        tex:SetTexture(img)
        tex:SetTexCoord(0, 1, (top - y) / h, (bottom - y) / h)
        tex:SetSize(w, bottom - top)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", win, "TOPLEFT", x, -top)
        tex:Show()
    end

    --- s6-interface-7x-b (round 7): one of the kit's buttons drawn as nothing of its own (its pictures and caption hidden,
    --- no click sound): a control of 4a's that draws only what the look puts on it (ObjectImageButtonPane: the head
    --- choice's heads). Its index and its input are unchanged.
    function X.Bare(btn)
        for _, t in ipairs({ btn:GetNormalTexture(), btn:GetPushedTexture(), btn:GetHighlightTexture() }) do
            if t then t:SetAlpha(0) end
        end
        local label = btn:GetFontString()
        if label then label:Hide() end
        btn.noClickSound = true
    end

    --- A frame (a child of parent, over what was made before it) over a rectangle of the window that takes the pointer and
    --- does nothing with it: a control of 4a's that is hit but acts on no press (a StaticTextControlPane:
    --- DialogPane::HitTestControls 0x0049FB10 walks the controls from the last, and only SetIgnoreHitTesting takes one
    --- out), so a press there does not reach a control under it. WIRE (input routing): it keeps a press from a button 4a's
    --- would not give it to (the small TextDialog's stacked buttons), so changing it changes what a press sends.
    function X.Blocker(parent, win, l, t, r, b)
        local f = CreateFrame("Frame", nil, parent)
        f:EnableMouse(true)
        X.Rect(f, win, l, t, r, b)
        return f
    end

    --- s6-optimize (round 52; moved from 7.x's and 5.x's npc.lua, the same in both): controls stacked in 4a's control
    --- order, the last on top: each of buttons into a frame one level above the one before it (none of these frames takes
    --- a press), then one frame over them all, returned, for the controls after them (the small TextDialog's prompt and
    --- caption blockers, X.Blocker, and its edit).
    --- WIRE (input routing): 4a gives a press to the last control whose rectangle holds it (DialogPane::HitTestControls
    --- 0x0049FB10; 5.33's DialogPane_HitTestControls 0x004215F0), and our frames take a press by their level, so this
    --- order decides which control a press reaches. Changing it changes what the client sends.
    function X.Stacked(win, buttons)
        local parent = win
        for _, b in ipairs(buttons) do
            local f = CreateFrame("Frame", nil, parent)
            f:SetAllPoints(win)
            b:SetParent(f)
            parent = f
        end
        local over = CreateFrame("Frame", nil, parent)
        over:SetAllPoints(win)
        return over
    end

    --- A text drawn twice a pixel apart, as 4a's bold labels (MoveTo and DrawWideText at x, then again at x + 1: the
    --- popups', the say-mode button's), its line's pen at (x, baseline) of parent: the glyphs from baseline - 12 + 1. The
    --- second copy (fs.boldTwin, made once, on parent) follows the first's text (SetText is wrapped), and
    --- fs.onBoldText(text) runs after each text, for a text placed by its length. Drawing only.
    function X.Bold(parent, fs, x, baseline, colour)
        S.Text(fs, colour)
        fs:SetWordWrap(false)
        fs:SetJustifyH("LEFT")
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(baseline - 12 + 1))
        local twin = fs.boldTwin
        if not twin then
            twin = parent:CreateFontString(nil, "OVERLAY")
            fs.boldTwin = twin
            local set = fs.SetText
            function fs:SetText(text)
                set(self, text)
                twin:SetText(text)
                if self.onBoldText then self.onBoldText(text) end
            end
            twin:SetText(fs:GetText() or "")
        end
        S.Text(twin, colour)
        twin:SetWordWrap(false)
        twin:SetJustifyH("LEFT") -- as the first copy (centred, it lands a pixel further: round 12's capture)
        twin:ClearAllPoints()
        twin:SetPoint("TOPLEFT", fs, "TOPLEFT", 1, 0)
        fs:Show()
        twin:Show()
    end

    --- A text drawn outlined (GrafPort::DrawOutlinedTextAt: the text in 0x8F over copies in 0x80 a pixel round it), its
    --- pen at (x, line) of parent (win by default), made once under win[key], in layer (OVERLAY by default). Drawing only.
    function X.Outlined(win, key, x, line, text, parent, layer)
        local set = win[key]
        if not set then
            set = {}
            for i, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { 0, 0 } }) do
                set[i] = { fs = (parent or win):CreateFontString(nil, layer or "OVERLAY"), d = d }
            end
            win[key] = set
        end
        for i, part in ipairs(set) do
            S.Text(part.fs, i == 5 and S.WHITE or S.TEXT)
            part.fs:SetWordWrap(false)
            part.fs:SetJustifyH("LEFT")
            part.fs:ClearAllPoints()
            part.fs:SetPoint("TOPLEFT", parent or win, "TOPLEFT", x + part.d[1], -(line - 11 + part.d[2]))
            part.fs:SetText(text or "")
            part.fs:Show()
        end
    end

    --- The outline 4a's popups draw round the row under the pointer (MoveTo and LineTo: RightButtonMenuPane's,
    --- MenuVarietySelectPane's, ChattingVarietySelectPane's OnPaint), in the row's highlight layer: from x l to r (both
    --- drawn) over the row's h + 1 lines, raised (0x8F on its left and top, 0x80 on its right and bottom), sunken (the
    --- other way round) while the row is pressed. Drawing only. Returns paint(pressed); tracked: the caller paints the
    --- pressed state itself (a menu whose press is its own, not the row's: the say-mode menu's).
    function X.Outline(r, l, right, h, tracked, manualHover)
        local function line(x, t, w, ht)
            local tex = r:CreateTexture(nil, manualHover and "OVERLAY" or "HIGHLIGHT")
            tex:SetPoint("TOPLEFT", r, "TOPLEFT", x, -t)
            tex:SetSize(w, ht)
            return tex
        end
        local lit = { line(l, 0, 1, h + 1), line(l, 0, right - l + 1, 1) }
        local dark = { line(right, 0, 1, h + 1), line(l, h, right - l + 1, 1) }
        -- Claim-only rows keep their picture's hover separately from input routing.
        local function paint(pressed, hover)
            for _, t in ipairs(lit) do
                if manualHover then t:SetShown(hover == true) end
                S.Fill(t, pressed and S.TEXT or S.WHITE)
            end
            for _, t in ipairs(dark) do
                if manualHover then t:SetShown(hover == true) end
                S.Fill(t, pressed and S.WHITE or S.TEXT)
            end
        end
        paint(false)
        if not tracked then
            r:HookScript("OnMouseDown", function() paint(true) end)
            r:HookScript("OnMouseUp", function() paint(false) end)
        end
        if r.hl then r.hl:SetColorTexture(0, 0, 0, 0) end
        return paint
    end

    --- A frame at a point of the screen (the original's coordinates), at the screen's scale: a pane placed where 4a puts
    --- it (the popups). Drawing only.
    function X.PlaceAt(frame, x, y)
        local s, left, top = screen()
        frame:SetScale(s)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (left + x * s) / s, -(top + y * s) / s)
    end

    --- A point in UIParent units (from its bottom left) on the screen, in the original's coordinates.
    function X.ScreenPoint(ux, uy)
        local s, left, top = screen()
        return (ux - left) / s, (GetScreenHeight() - uy - top) / s
    end

    --- DialogPane::SlideOpenVertical (0x0049EAC0): the window drops out of its own top edge in five steps 24 ms apart,
    --- step i drawn (4 - i) x height / 5 pixels higher and shown only below its place's top, the last at its place. The
    --- client's stall for the slide (5 x Sleep(24) on 4a's main thread) is the dialog model's (Dialog.Slide's
    --- Session.Sleep(120)), the only input wait, done before the window is shown here; this is the picture of it, and it
    --- holds, delays and replays no input (Astra's review of round 11). The window's place is the look's (win.screenX,
    --- win.screenY: ctx.place); none, nothing slides.
    ---
    --- WIRE (input routing): 4a handles a press made during its slide after the slide, against the window at its place.
    --- The model's wait is that delay; so here a press on the window's place while the picture still slides (the shield
    --- over that place) goes at once, in its own physical event, to the window's control there, its release too: the
    --- kit's K.PressAt (s6-rules-dialogs: DialogPane::HitTestControls 0x0049FB10, a list's row by ListPane::HitTestItem's
    --- clamp, a press on no row the dialog's alone, a release over the pressed control its click: a check box toggles;
    --- none after a double-click's second press, which 4a does not track), given the point moved onto the frames as the
    --- slide draws them now; no hit test of the look's own. Changing this changes which control a press reaches or when,
    --- so what the client sends and when.
    function X.SlideOpen(win)
        if not win.screenX then return end
        slideClip = slideClip or CreateFrame("ScrollFrame", nil, UIParent)
        slideShield = slideShield or CreateFrame("Frame", nil, UIParent)
        local clip, shield = slideClip, slideShield
        if clip.finish then clip.finish() end -- one slide at a time (4a's block the client while they run)
        local s, left, top = screen()
        local x, y = win.screenX, win.screenY
        local w, h = math.floor(win:GetWidth() + 0.5), math.floor(win:GetHeight() + 0.5)
        local strata, level, start, step
        local pressed, ended = false, false
        --- Step i: the window (4 - i) x height / 5 higher than its place (DialogPane: (4 - i) * height / -5).
        local function at(i)
            local dy = math.floor((4 - i) * h / 5)
            win:ClearAllPoints()
            win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (left + x * s) / s, -(top + (y - dy) * s) / s)
        end
        --- A press or release on the shield, at once to the window's control at its point at its place: the point moved
        --- up by how far above its place the slide draws the window now (UIParent units), so it meets the frames as
        --- drawn. double: the host's double-press flag, passed on (WIRE: a double-click's second press tracks nothing in
        --- 4a, HandlePointerOrMouseEvent 0x0049E240, so its release clicks nothing: K.PressAt; dropping it toggled a check
        --- box twice).
        local function pass(down, button, double)
            local px, py = TK.Util.CursorRoot()
            local _, wb, _, wh = TK.Util.RootRect(win)
            local raised = wb and (wb + wh) - (GetScreenHeight() - (top + y * s)) or 0
            TK.GetComponent("dialogs").kit.PressAt(win, px, py + raised, button, down, double)
        end
        function clip.finish()
            clip.finish = nil
            clip:SetScript("OnUpdate", nil)
            if strata then
                win:SetParent(UIParent)
                win:SetFrameStrata(strata)
                win:SetFrameLevel(level)
                at(4)
            end
            clip:Hide()
            -- a press still held keeps the shield until its release, which goes the same way
            ended = true
            if not pressed then shield:Hide() end
        end
        shield:EnableMouse(true)
        shield:SetScript("OnMouseDown", function(_, button, double)
            pressed = true
            pass(true, button, double)
        end)
        shield:SetScript("OnMouseUp", function(_, button)
            pressed = false
            pass(false, button)
            if ended then shield:Hide() end
        end)
        -- s6-input (round 43; Astra's review of s6-input round 42). WIRE: the moves while the shield holds a press passed
        -- on to a list's row, EventMan's auto-scroll tick's every 20 ms included, go to that row as 4a's go to the list
        -- that tracks the press once the slide is over (ListPane::OnMouseEvent 0x004F4190 case 0: its step, then 3B 02 at
        -- a board's or the mail list's end): K.PressedMoveAt. Dropping it leaves such a list unscrolled and unpaged.
        shield:SetScript("OnPressedMove", function() TK.GetComponent("dialogs").kit.PressedMoveAt(win) end)
        -- from the next frame, once the window is shown at its strata and level (C:Refresh shows it after its update)
        clip:SetScript("OnUpdate", function()
            if not start then
                if not win:IsShown() then return clip.finish() end
                strata, level, start, step = win:GetFrameStrata(), win:GetFrameLevel(), GetTime(), 0
                for _, f in ipairs({ clip, shield }) do
                    f:SetScale(1)
                    f:ClearAllPoints()
                    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left + x * s, -(top + y * s))
                    f:SetSize(w * s, h * s)
                    f:SetFrameStrata(strata)
                    f:Show()
                end
                clip:SetFrameLevel(math.max(0, level - 1))
                shield:SetFrameLevel(level + 15)
                win:SetParent(clip)
                win:SetFrameStrata(strata)
                win:SetFrameLevel(level)
                at(0)
                return
            end
            local i = math.floor((GetTime() - start) / 0.024)
            if i >= 4 or not win:IsShown() then return clip.finish() end
            if i ~= step then
                step = i
                at(i)
            end
        end)
        clip:SetSize(1, 1)
        clip:Show()
    end

    --- Whether a window is sliding open now (the tests wait for its place: DialogPlayBase.SlidesDone).
    function X.Sliding() return slideClip ~= nil and slideClip.finish ~= nil end

    return X
end
