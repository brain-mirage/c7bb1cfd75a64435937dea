-- s6-modular-g (interfaces, round 13): 7.x's look of the collection album (components/dialogs/collection.lua) and the
-- chat colour dialog (components/dialogs/chatcolor.lua), from Source-5's class pages. Drawing only: the indexes, the
-- paging and what is kept are the renderers' and the model's.
--
-- The album (CollectionDialogPane 0x0048C640): 668 x 468 on DLGCLT.EPF in DLGCLT.PAL, at placement slot 17 (centred),
-- sliding open; PREVIOUS (1, image 18) (229, 409), OK (2, image 14: Enter and Escape) (304, 409), NEXT (3, image 19)
-- (379, 409); the volume's title (CLTNAME.EPF, frame the volume, in CLTNAME.PAL) at (75, 42); the progress bar
-- (CollectionBarControlPane 0x0048DC30) at (393, 72)-(593, 92), 3 pixels in at each side: CLTBAR.EPF frame 0 as wide as
-- collected / total, its 3-pixel caps (frames 1 and 2) before and after it, the label "%d/%d (%d%%)"; six cards
-- (CollectionEntryControlPane 0x0048D3A0) at (74 + 266 c, 102 + 100 r), 255 x 95, column c, row r: CLTENTRY.EPF frame 0
-- under each, the entry's picture in its 95 x 95 box, its name in (102, 6)-(248, 18), its number "%2d" in the box's last
-- 13 pixels (drawn twice, a pixel apart), its label 24 lower and right-aligned to 248, in 0x8F; its description in
-- (102, 55)-(248, 67) in 0x80 (OnPaint 0x0048D4A0).
--
-- The chat colour dialog (ChattingColorPane 0x004824E0): 330 x 397 on TXTCOLOR.EPF in TXTCOLOR.PAL, centred, no slide;
-- OK (1, image 14) (100, 363), CANCEL (2, image 22) (175, 363); the six categories (ChattingColorSelectPane: 60 x 20
-- cells, three to a row) from (77, 57): the chosen one's cell framed 2 pixels deep in 0x80 then a pixel in 0x8F, the others
-- a pixel in 0x88 two in (DrawListEntry 0x00482D60), each name in the cell inset (6, 4) in its colour, outlined in its
-- outline colour; the text colours' grid
-- from (20, 134) and the outline colours' from (20, 253) (ChattingColorListPane: 18 x 18 cells, sixteen to a row): each
-- swatch's colour three pixels in, the chosen one framed as the chosen category, colour 0 ringed in 0x88 (DrawListEntry
-- 0x004832C0).
-- s6-ui-core (round 85): the XML twin's; the windows' pictures, cards, cells and the parts' places are album.xml's
-- (core/xml.md).

local S = require("interfaces.7x.skin")
local unpack = table.unpack
local entry = require("interfaces.xml.entry")
local D = TK.Xml.Data("album.xml")

return function(L, X)
    --- Lines framing a rectangle of a frame: depth pixels deep from inset pixels in, in colour; hidden without one.
    --- s6-optimize (round 14): made and placed once under key (a cell's size never changes), and filled again only when
    --- its colour changes; the paint (each click and key while the dialog is open: 172 rings) took 32 ms placing them all.
    local function ring(f, key, w, h, inset, depth, colour)
        local lines = f[key]
        if not lines then
            lines = { colour = false } -- false: not filled yet (nil is a colour: hidden)
            local a, b = inset, inset + depth
            for i, r in ipairs({ { a, a, w - a, b }, { a, h - b, w - a, h - a }, { a, b, b, h - b }, { w - b, b, w - a, h - b } }) do
                local t = f:CreateTexture(nil, "BORDER")
                t:SetPoint("TOPLEFT", f, "TOPLEFT", r[1], -r[2])
                t:SetSize(r[3] - r[1], r[4] - r[2])
                lines[i] = t
            end
            f[key] = lines
        end
        if lines.colour == colour then return end
        lines.colour = colour
        for _, t in ipairs(lines) do
            if colour then S.Fill(t, colour) end
            t:SetShown(colour ~= nil)
        end
    end

    -- ----- the album -----

    local A = D.Album
    local CARDS = A.cards

    --- Card i's place (CollectionDialogPane's constructor): column (i - 1) / 3, row (i - 1) % 3.
    local function cardAt(i)
        return CARDS.x + CARDS.across * math.floor((i - 1) / CARDS.rows), CARDS.y + CARDS.down * ((i - 1) % CARDS.rows)
    end

    --- One of a card's texts in its rectangle (album.xml's cards) and colour.
    local function cardText(card, rect, colour)
        local fs = card:CreateFontString(nil, "OVERLAY")
        X.Text(fs, card, rect[1], rect[2], rect[3], rect[4], colour)
        return fs
    end

    L.Album = entry(A, {
        place = function(win)
            X.Art(win, unpack(A.art))
            X.Image(win, win.previous, unpack(A.previous))
            X.Image(win, win.close, unpack(A.close))
            X.Image(win, win.nextButton, unpack(A.nextButton))
            win.progress:Hide()
            win.x7bar = win.x7bar or {}
        end,
        --- Card i: its CLTENTRY picture, its picture box and its texts (the renderer fills them).
        card = function(win, i)
            local card = CreateFrame("Frame", nil, win)
            card:SetSize(CARDS.width, CARDS.height)
            local x, y = cardAt(i)
            X.Rect(card, win, x, y, x + CARDS.width, y + CARDS.height)
            card.bg = card:CreateTexture(nil, "BACKGROUND")
            local key, w, h = TK.Art.Image(CARDS.file, 0, CARDS.palette)
            if key then
                local ox, oy = TK.Art.Origin(key)
                card.bg:SetTexture(key)
                card.bg:SetSize(w, h)
                card.bg:SetPoint("TOPLEFT", card, "TOPLEFT", ox, -oy)
            end
            card.pic = card:CreateTexture(nil, "ARTWORK")
            card.pic:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
            card.name = cardText(card, CARDS.name, CARDS.colour)
            card.name:SetWordWrap(false)
            card.number = cardText(card, CARDS.number, CARDS.colour)
            card.number2 = cardText(card, CARDS.number2, CARDS.colour)
            card.label = cardText(card, CARDS.label, CARDS.colour) -- right-aligned: left = right - 6 x length - 2
            card.label:SetJustifyH("RIGHT")
            card.desc = cardText(card, CARDS.desc, S.TEXT)
            card.desc:SetWordWrap(true)
            return card
        end,
        -- after the renderer's update: the volume's title at its place, the progress bar, the numbers drawn twice
        fill = function(win, c)
            local key = win.volume:GetTexture()
            if key and key ~= "" then
                local ox, oy = TK.Art.Origin(key)
                win.volume:ClearAllPoints()
                win.volume:SetPoint("TOPLEFT", win, "TOPLEFT", A.volume[1] + (ox or 0), -(A.volume[2] + (oy or 0)))
            end
            local p = c.progress or {}
            local collected, total = p[1] or 0, p[2] or 0
            L.Album.bar(win, collected, total)
            for _, card in ipairs(win.cards) do card.number2:SetText(card.number:GetText() or "") end
        end,
        --- The progress bar (CollectionBarControlPane::OnPaint 0x0048DD60): in (396, 72)-(590, 92), CLTBAR.EPF frame 0
        --- collected / total of the width, its caps (frames 1 and 2, 3 pixels) before and after it; the label in font 0.
        bar = function(win, collected, total)
            local parts = win.x7bar
            for i = 1, 3 do parts[i] = parts[i] or win:CreateTexture(nil, "ARTWORK") end
            local b = A.bar
            local l, t, width, cap = b.left, b.top, b.width, b.cap
            local fillW = total > 0 and math.floor(width * collected / total) or 0
            local pieces = { { 1, l - cap, cap }, { 0, l, fillW }, { 2, l + fillW, cap } }
            for i, piece in ipairs(pieces) do
                local tex, key, w, h = parts[i], TK.Art.Image(b.file, piece[1], b.palette)
                tex:SetShown(key ~= nil and piece[3] > 0)
                if key then
                    tex:SetTexture(key)
                    tex:SetSize(piece[3], h)
                    tex:ClearAllPoints()
                    tex:SetPoint("TOPLEFT", win, "TOPLEFT", piece[2], -t)
                end
            end
            if not win.x7label then win.x7label = win:CreateFontString(nil, "OVERLAY") end
            local text = string.format("%d/%d (%d%%)", collected, total, total > 0 and math.floor(100 * collected / total) or 0)
            X.Text(win.x7label, win, l + math.floor((width - 6 * #text) / 2), t + b.label, l + width, t + b.label + 12, S.TEXT)
            win.x7label:SetText(text)
        end,
    })

    -- ----- the chat colour dialog -----

    local C = D.ChatColor
    local CAT, GRIDS = C.categories, C.grids

    L.ChatColor = entry(C, {
        -- its own rectangle, ((screen - 330) / 2, (screen - 397) / 2) (no placement slot): its top 185, not the centre's
        -- 186 for its odd height; unclamped
        centre = function(win) return C.centre[1], C.centre[2], false end,
        --- A category's cell, 60 x 20: its frames (painted by paint), its name in the cell inset (6, 4) (DrawListEntry's
        --- text rectangle; the round 13 capture puts the glyphs there), drawn outlined in the category's outline colour
        --- (paint).
        category = function(win, name)
            local b = CreateFrame("Button", nil, win)
            b:SetSize(CAT.width, CAT.height)
            b.bg = b:CreateTexture(nil, "BACKGROUND")
            b.bg:SetAllPoints(b)
            b.bg:Hide() -- the renderer's highlight: 7.x draws 4a's frames instead (paint)
            local r = CAT.text
            b.x7outline = {}
            for i, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
                local o = b:CreateFontString(nil, "ARTWORK")
                X.Text(o, b, r[1] + d[1], r[2] + d[2], r[3] + d[1], r[4] + d[2])
                o:SetText(name)
                b.x7outline[i] = o
            end
            b.label = b:CreateFontString(nil, "OVERLAY")
            X.Text(b.label, b, unpack(r))
            b.label:SetText(name)
            return b
        end,
        --- A swatch, 18 x 18: its colour three pixels in (s.fill); its frames painted by paint (s.edge, the renderer's, unseen).
        swatch = function(win)
            local s = CreateFrame("Button", nil, win)
            s:SetSize(GRIDS.size, GRIDS.size)
            s.edge = s:CreateTexture(nil, "BACKGROUND")
            s.edge:SetAllPoints(s)
            s.edge:Hide() -- the renderer's frame: 7.x draws 4a's (paint)
            s.fill = s:CreateTexture(nil, "ARTWORK")
            s.fill:SetPoint("TOPLEFT", s, "TOPLEFT", GRIDS.inset, -GRIDS.inset)
            s.fill:SetSize(GRIDS.size - 2 * GRIDS.inset, GRIDS.size - 2 * GRIDS.inset)
            return s
        end,
        place = function(win)
            X.Art(win, unpack(C.art))
            X.Image(win, win.ok, unpack(C.ok))
            X.Image(win, win.cancel, unpack(C.cancel))
            for i, b in ipairs(win.categories) do
                local x, y = CAT.x + (i - 1) % CAT.across * CAT.width, CAT.y + math.floor((i - 1) / CAT.across) * CAT.height
                X.Rect(b, win, x, y, x + CAT.width, y + CAT.height)
            end
            local size = GRIDS.size
            for _, g in ipairs({ { win.text, GRIDS.text }, { win.outline, GRIDS.outline } }) do
                for i, s in ipairs(g[1]) do
                    local x, y = GRIDS.x + (i - 1) % GRIDS.across * size, g[2] + math.floor((i - 1) / GRIDS.across) * size
                    X.Rect(s, win, x, y, x + size, y + size)
                end
            end
        end,
        -- after the renderer's paint: 4a's frames for the chosen category and swatches, colour 0 ringed
        paint = function(win)
            local c = win.colors or {}
            for i, b in ipairs(win.categories) do
                local chosen = i == win.category
                ring(b, "x7outer", CAT.width, CAT.height, 0, 2, chosen and S.TEXT or nil)
                ring(b, "x7inner", CAT.width, CAT.height, 2, 1, chosen and 0x8F or 0x88)
                -- the name outlined in its outline colour (none for colour 0: DrawOutlinedTextAt)
                local outline = c[i * 2] or 0
                local rgb = outline ~= 0 and TK.Chat:PaletteRGB(outline)
                for _, o in ipairs(b.x7outline) do
                    o:SetShown(rgb ~= nil and rgb ~= false)
                    if rgb then o:SetTextColor(rgb[1], rgb[2], rgb[3], 1) end
                end
            end
            local fg, outline = c[win.category * 2 - 1], c[win.category * 2]
            local size = GRIDS.size
            for _, pair in ipairs({ { win.text, fg }, { win.outline, outline } }) do
                for _, s in ipairs(pair[1]) do
                    local chosen = s.index == pair[2]
                    ring(s, "x7outer", size, size, 0, 2, chosen and S.TEXT or nil)
                    ring(s, "x7inner", size, size, 2, 1, chosen and 0x8F or (s.index == 0 and 0x88 or nil))
                end
            end
        end,
    })
end
